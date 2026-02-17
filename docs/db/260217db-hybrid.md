# 하이브리드 Analytics: Supabase 추가 구현 계획

## Context

현재 TelemetryDeck 기반 Analytics가 완전히 구현·운용 중. Claude Code에서 데이터를 조회할 때 TQL(비표준 쿼리 언어) + 3단계 비동기 API가 복잡하고 느림. Supabase를 보조 데이터 저장소로 추가하여, Claude가 표준 REST API로 즉시 조회·분석할 수 있게 한다.

**원칙**: TelemetryDeck은 그대로 유지 (대시보드, 리텐션, 프라이버시). Supabase는 Claude용 원시 데이터 저장소.

---

## Phase 1: Supabase 프로젝트 셋업 (수동, 코드 아님)

주인님이 직접 수행:

1. **supabase.com에서 프로젝트 생성** (리전: Northeast Asia)

> **참고**: 무료 티어는 일정 기간 비활성 시 프로젝트가 자동 일시정지될 수 있음 (공식 문서 기준 약 1주).
> 개발 중 장기 미사용 시 Dashboard에서 수동으로 Resume 필요. pause 중에는 pg_cron 등 모든 백그라운드 작업도 중단됨.

2. **SQL Editor에서 테이블 + 인덱스 생성**:

```sql
CREATE TABLE events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_name TEXT NOT NULL,
    params JSONB NOT NULL DEFAULT '{}',
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    photo_bucket TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_events_name ON events(event_name);
CREATE INDEX idx_events_created ON events(created_at);
CREATE INDEX idx_events_name_created ON events(event_name, created_at);
```

3. **RLS 정책**: anon key는 INSERT만 허용

```sql
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
CREATE POLICY "anon_insert" ON events FOR INSERT TO anon
    WITH CHECK (
        event_name IN (
            'session.photoViewing',
            'session.deleteRestore',
            'session.trashViewer',
            'session.similarAnalysis',
            'session.errors',
            'similar.groupClosed',
            'cleanup.completed',
            'cleanup.previewCompleted'
        )
    );
```

> **보안**: service_role key는 RLS를 우회하므로 **스크립트 전용 (.env에만 보관)**. 절대 앱 코드에 포함 금지.

4. **RPC 분석 함수 3개** (Claude 조회용):

```sql
-- 일별 이벤트 요약
CREATE OR REPLACE FUNCTION daily_summary(p_days INT DEFAULT 7)
RETURNS TABLE(day DATE, event_name TEXT, cnt BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT created_at::date AS day, event_name, count(*) AS cnt
    FROM events
    WHERE created_at >= now() - (p_days || ' days')::interval
    GROUP BY day, event_name
    ORDER BY day DESC, cnt DESC;
$$;

-- 삭제/복원 상세 분석
CREATE OR REPLACE FUNCTION delete_restore_summary(p_days INT DEFAULT 30)
RETURNS TABLE(day DATE, param_key TEXT, total_value BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT
        created_at::date AS day,
        kv.key AS param_key,
        sum((kv.value)::bigint) AS total_value
    FROM events, jsonb_each_text(params) AS kv
    WHERE event_name = 'session.deleteRestore'
      AND created_at >= now() - (p_days || ' days')::interval
      AND kv.value ~ '^\d+$'
    GROUP BY day, param_key
    ORDER BY day DESC, param_key;
$$;

-- 90일 이전 데이터 삭제 (비용 관리)
CREATE OR REPLACE FUNCTION purge_old_events(p_retention_days INT DEFAULT 90)
RETURNS BIGINT
LANGUAGE plpgsql AS $$
DECLARE
    deleted_count BIGINT;
BEGIN
    DELETE FROM events
    WHERE created_at < now() - (p_retention_days || ' days')::interval;
    GET DIAGNOSTICS deleted_count = ROW_COUNT;
    RETURN deleted_count;
END;
$$;
```

5. **90일 보존 자동화** (Supabase Dashboard > Integrations > Cron에서 설정, 내부적으로 pg_cron 사용):

```sql
SELECT cron.schedule(
    'purge-old-events',
    '0 3 * * 0',  -- 매주 일요일 03:00 UTC
    $$SELECT purge_old_events(90)$$
);
```

6. **.env에 credentials 추가**: SUPABASE_URL, SUPABASE_ANON_KEY, SUPABASE_SERVICE_KEY

---

## Phase 2: SupabaseProvider 구현

**신규 파일**: `PickPhoto/PickPhoto/Shared/Analytics/SupabaseProvider.swift` (~120줄)

- URLSession 기반 HTTP POST (외부 의존성 0, supabase-swift SDK 미사용)
- **배치 전송 지원**: `sendBatch(events:)` — 여러 이벤트를 단일 POST로 전송
  - PostgREST는 배열 JSON body로 bulk INSERT 지원: `POST /rest/v1/events` + `[{...}, {...}]`
  - `flushCounters()`에서 최대 6개 이벤트를 **1회 HTTP 요청**으로 전송
  - **구현 주의**: 배열 내 모든 JSON 객체는 동일한 키 셋을 가져야 함 (값이 없으면 `null`). HTTP 헤더에 `Prefer: missing=default` 추가 권장
- `send(eventName:parameters:photoBucket:)` — 즉시 전송용 (단건)
- 디바이스 메타데이터 자동 첨부 (device_model, os_version, app_version)
- 오프라인 큐 없음 (TD가 주 데이터, 유실 허용)
- `#if DEBUG`에서만 응답 로깅

### 백그라운드 플러시 안전성

`handleSessionEnd()` → `flushCounters()` 경로는 앱 백그라운드 진입 시 호출됨 (SceneDelegate:290).
iOS가 ~5초 내에 앱을 suspend할 수 있으므로:

1. `sendBatch()`로 **1회 POST**에 모든 세션 이벤트 전송 (6개 개별 POST → 1개 배치)
2. **SceneDelegate.sceneDidEnterBackground에 `beginBackgroundTask` 추가** (현재 미사용):
   - `handleSessionEnd()` 호출 전에 `UIApplication.shared.beginBackgroundTask` 시작
   - Supabase POST 완료(또는 timeout) 후 `endBackgroundTask` 호출
   - 만료 핸들러에서도 `endBackgroundTask` 호출 (시스템 강제 종료 방지)
   - TelemetryDeck SDK는 자체 백그라운드 처리가 있으므로 별도 보호 불필요

---

## Phase 3: AnalyticsService 수정

### 3-1. `AnalyticsService.swift` 수정 (~30줄 추가)

- `supabaseProvider: SupabaseProvider?` 프로퍼티 추가
- `supabaseExcluded: Set<String>` 제외 목록 상수
- `configureSupabase()` — Bundle.main에서 URL/Key 로드, 없으면 비활성 (nil provider)
- `sendEvent(_:parameters:)` 내부 헬퍼 — TD 전송 + 제외 목록 체크 + Supabase 전송
- `sendEventBatch(_:)` 내부 헬퍼 — TD 개별 전송 + Supabase 배치 전송 (flushCounters용)

**호출 위치**: `configure(appID:)` 내부 마지막에 `configureSupabase()` 호출
(AppDelegate.swift 50줄 `configure()` 내부에서 자동 실행, 별도 호출 불필요)

### 3-2. TelemetryDeck.signal() → sendEvent() 교체 (11곳, 4개 파일)

| 파일 | 교체 수 | Supabase 전송 여부 |
|------|:---:|---|
| `+Lifecycle.swift` | 2곳 | X (app.launched, permission.result 제외) |
| `+Session.swift` (flushCounters 내부) | 6곳 → sendEventBatch() 1회 | 5개 O, 1개 X (gridPerformance 제외) |
| `+Similar.swift` | 1곳 | O |
| `+Cleanup.swift` | 2곳 | O |

교체 후 이 4개 파일에서 `import TelemetryDeck` 제거 가능 (SDK 의존성이 본체 1개 파일로 집중)

**flushCounters() 변경 상세**: 기존 6개 개별 `TelemetryDeck.signal()` 호출을 이벤트 배열 구성 후 `sendEventBatch()`로 교체. TD 전송은 내부에서 개별 호출, Supabase는 배치 1회.

### 3-3. Supabase에 보내지 않을 이벤트 (3종, 비용 절감)

| 이벤트 | 제외 이유 |
|--------|----------|
| `app.launched` | 가장 빈번, TD가 DAU/리텐션 자동 계산 |
| `permission.result` | 극소량, TD에서 충분 |
| `session.gridPerformance` | 카운트만, 드릴다운 가치 낮음 |

### 3-4. Credentials 전달

- `Supabase.xcconfig` (git-ignored) → Info.plist에 `$(SUPABASE_URL)`, `$(SUPABASE_ANON_KEY)` 참조
- anon key는 클라이언트용이라 노출되어도 RLS가 INSERT만 허용
- **Xcode 프로젝트 설정 필요**: Project > Info > Configurations에서 Debug/Release 모두 `Supabase.xcconfig` 지정
  (또는 기존 xcconfig가 있다면 `#include "Supabase.xcconfig"` 추가)

### 3-5. photo_bucket 처리

현재 코드의 `bucketString(for:)` 반환값(`"0-1k"`, `"1k-5k"` 등)을 그대로 TEXT 컬럼에 저장.
별도 매핑 함수 불필요 — 기존 `photoLibraryBucket` 문자열을 그대로 전달.

### 볼륨 추정 (DAU 1,000 기준)

- 제외 후: ~4-5 signals/session → 240K rows/month → ~120MB/month
- 90일 보존 (pg_cron 자동 삭제): ~360MB → 500MB 무료 한도 내

---

## Phase 4: 쿼리 스크립트

**신규 파일 2개** (`scripts/analytics/` 내):

| 파일 | 용도 | 예상 줄 |
|------|------|:---:|
| `sb-query.sh` | PostgREST 조회 + RPC 호출 | ~80줄 |
| `sb-report.sh` | 리포트 생성 (daily_summary 등 일괄) | ~40줄 |

**sb-query.sh는 service_role key 사용** (.env의 SUPABASE_SERVICE_KEY) — RLS를 우회하여 SELECT 가능.

**사용 예시**:
```bash
./sb-query.sh --rpc daily_summary '{"p_days": 30}'
./sb-query.sh --table events --filter "event_name=eq.session.errors" --limit 20
./sb-report.sh --days 7
```

**기존 파일 확장**: `scripts/analytics/.env.example` (TD 변수 3개 이미 존재, Supabase 변수 추가)
```
# TelemetryDeck (기존)
TELEMETRYDECK_EMAIL=
TELEMETRYDECK_PASSWORD=
TELEMETRYDECK_APP_ID=

# Supabase (추가)
SUPABASE_URL=
SUPABASE_ANON_KEY=
SUPABASE_SERVICE_KEY=
```

---

## Phase 5: 검증

1. Xcode Console에서 `[Supabase] OK batch 5 events` 로그 확인
2. Supabase Dashboard Table Editor에서 행 도착 확인
3. 제외 이벤트(`app.launched` 등)에 `[Supabase]` 로그 없음 확인
4. `sb-query.sh --table events --limit 5` 로 데이터 조회 확인
5. `sb-query.sh --rpc daily_summary '{"p_days": 7}'` 정상 실행 확인
6. 기존 `td-report.sh --days 1` 정상 작동 확인 (TD 미영향)
7. 앱 백그라운드 진입 후 Supabase에 세션 이벤트 도착 확인

---

## 파일 변경 요약

| 구분 | 파일 | 변경 |
|------|------|------|
| **신규** | `Shared/Analytics/SupabaseProvider.swift` | ~120줄 (배치 전송 포함) |
| **신규** | `Config/Supabase.xcconfig` | credentials (git-ignored) |
| **신규** | `scripts/analytics/sb-query.sh` | ~80줄 |
| **신규** | `scripts/analytics/sb-report.sh` | ~40줄 |
| **확장** | `scripts/analytics/.env.example` | Supabase 변수 3개 추가 |
| **수정** | `AnalyticsService.swift` | +30줄 (provider, sendEvent, sendEventBatch, configureSupabase) |
| **수정** | `+Lifecycle.swift` | 2줄 변경, import 제거 |
| **수정** | `+Session.swift` | flushCounters 리팩토링 (배치), import 제거 |
| **수정** | `+Similar.swift` | 1줄 변경, import 제거 |
| **수정** | `+Cleanup.swift` | 2줄 변경, import 제거 |
| **수정** | `Info.plist` | +2 키 (SUPABASE_URL, SUPABASE_ANON_KEY) |
| **수정** | `.gitignore` | +1줄 (Supabase.xcconfig) |
| **프로젝트** | `PickPhoto.xcodeproj` | Configurations에 Supabase.xcconfig 지정 |

**총 신규 4개 / 확장 1개 / 수정 7개 / 프로젝트 설정 1개**

---

## 검토 기록

**2026-02-17 1차 점검 (자체):**
1. ~~개별 POST 6회~~ → 배치 POST 1회 (백그라운드 suspend 대비)
2. ~~photo_bucket SMALLINT~~ → TEXT (기존 bucketString 그대로 사용, 매핑 함수 불필요)
3. RPC 함수 SQL 정의 추가 (daily_summary, delete_restore_summary, purge_old_events)
4. pg_cron 90일 자동 삭제 스케줄 추가
5. xcconfig → Xcode 프로젝트 연결 단계 명시
6. configureSupabase() 호출 위치 명시 (configure 내부)
7. service_role key 보안 경고 추가
8. Supabase 무료 티어 7일 자동 pause 주의사항 추가
9. .env.example "수정" → "신규" 변경

**2026-02-17 2차 점검 (GPT Codex 교차 리뷰 → 타당성 검증):**
- GPT 7개 이슈 중 5개 반영, 1개 부분 반영, 1개 기각 (publishable/secret 키 — GPT 사실 오류)
10. RLS `WITH CHECK (true)` → 이벤트명 화이트리스트 CHECK 추가 (무단 INSERT 방지)
11. 배치 insert 시 `Prefer: missing=default` 헤더 + 동일 키 강제 주의사항 추가
12. 백그라운드 전송: "필요시 추가" → `beginBackgroundTask` / `endBackgroundTask` / 만료 핸들러 구체 명시
13. pause 문구 완화: "7일간 API 호출 없으면" → "일정 기간 비활성 시" + pause 시 cron 중단 주의
14. pg_cron 경로: "Database > Extensions" → "Integrations > Cron (내부 pg_cron)"
15. .env.example: "신규 생성" → "기존 scripts/analytics/.env.example 확장"

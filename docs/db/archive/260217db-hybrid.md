# 하이브리드 Analytics: Supabase 추가 구현 계획

> **상태: ✅ 구현 완료** (2026-02-25)
> - Phase 1 (Supabase 셋업): ✅ 완료 (주인님 수동)
> - Phase 2 (SupabaseProvider): ✅ 완료 (166줄)
> - Phase 3 (AnalyticsService 통합): ✅ 완료
> - Phase 4 (쿼리 스크립트): ✅ 완료 (sb-query.sh, sb-report.sh)
> - Phase 5 (검증): 시뮬레이터 실측 테스트 미완료
>
> 이 문서는 archive로 이동됨. 통합 문서: `260225db-Spec.md`, `260225db-Archi.md`, `260225db-API.md`

## Context

현재 TelemetryDeck 기반 Analytics가 완전히 구현·운용 중. Claude Code에서 데이터를 조회할 때 TQL(비표준 쿼리 언어) + 3단계 비동기 API가 복잡하고 느림. Supabase를 보조 데이터 저장소로 추가하여, Claude가 표준 REST API로 즉시 조회·분석할 수 있게 한다.

**원칙**: TelemetryDeck은 그대로 유지 (대시보드, 리텐션, 프라이버시). Supabase는 Claude용 원시 데이터 저장소.

---

## 구현 전 체크리스트 (Phase 1 — 주인님 수동 작업)

Phase 1은 코드 작업이 아님. Supabase 웹 콘솔에서 직접 수행 후, Phase 2부터 코드 구현 진행.

- [x] **1. supabase.com 프로젝트 생성** (리전: Northeast Asia) ✅
- [x] **2. SQL Editor에서 실행** (아래 Phase 1 상세의 SQL 순서대로): ✅
  - [x] 테이블 + 인덱스 생성 (CREATE TABLE events ...)
  - [x] RLS 활성화 + INSERT 정책 (이벤트명 화이트리스트 9종)
  - [x] RPC 함수 3개 (daily_summary, delete_restore_summary, purge_old_events)
  - [ ] pg_cron 90일 자동 삭제 스케줄 (초기 불필요 — DAU 1,000+ 이후 설정)
- [x] **3. Credentials 확보 → 로컬 파일에 기록**: ✅
  - [x] Project URL, anon key, service_role key → `scripts/analytics/.env`에 추가
  - [x] Project URL, anon key → `PickPhoto/PickPhoto/Config/Supabase.xcconfig` 생성
- [x] **4. 검증**: Dashboard > Table Editor에서 events 테이블 + RLS 정책 확인 ✅

~~완료 후 Claude에게 "Phase 2 진행" 요청.~~

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
            'app.launched',
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

5. **90일 보존 자동화** (pg_cron — 나중에 설정):

> **초기에는 불필요**: DAU 10명 기준 월 2,700행 → 300MB까지 수년 소요.
> DAU 1,000명 이상으로 늘어난 뒤 설정해도 충분함.
> 설정 방법: Database > Extensions > pg_cron 활성화 후 아래 SQL 실행.

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

### 클래스 설계

```swift
/// Supabase PostgREST에 이벤트를 전송하는 경량 HTTP 클라이언트
/// - 외부 의존성 0 (supabase-swift SDK 미사용, URLSession만 사용)
/// - 오프라인 큐 없음 (TD가 주 데이터, 유실 허용)
final class SupabaseProvider {

    // MARK: - Properties

    private let endpointURL: URL     // {baseURL}/rest/v1/events
    private let anonKey: String
    private let deviceModel: String  // 한번 캐싱 (UIDevice 또는 sysctlbyname)
    private let osVersion: String    // UIDevice.current.systemVersion
    private let appVersion: String   // Bundle.main CFBundleShortVersionString

    // MARK: - Init

    /// Info.plist에서 읽은 URL/Key로 초기화. URL이 잘못되면 nil 반환
    init?(baseURL: String, anonKey: String) {
        guard let url = URL(string: baseURL + "/rest/v1/events") else { return nil }
        self.endpointURL = url
        self.anonKey = anonKey
        self.deviceModel = Self.resolveDeviceModel()  // "iPhone16,1" 등
        self.osVersion = UIDevice.current.systemVersion
        self.appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
    }

    // MARK: - Public API

    /// 단건 즉시 전송 (trackAppLaunched, trackSimilarGroupClosed 등)
    func send(eventName: String, params: [String: String], photoBucket: String)

    /// 배치 전송 (flushCounters → sendEventBatch에서 호출)
    /// - PostgREST bulk INSERT: POST /rest/v1/events + JSON 배열
    /// - completion: URLSession 응답 후 호출 (beginBackgroundTask 종료용)
    func sendBatch(events: [EventPayload], completion: (() -> Void)? = nil)

    // MARK: - EventPayload (전송 단위)

    struct EventPayload {
        let eventName: String
        let params: [String: String]
        let photoBucket: String
    }
}
```

### HTTP 요청 상세

```
POST {baseURL}/rest/v1/events
Headers:
  Content-Type: application/json
  apikey: {anonKey}                    ← API 게이트웨이 통과용
  Authorization: Bearer {anonKey}      ← PostgREST RLS 평가용 (같은 키)
  Prefer: return=minimal               ← 응답에 삽입된 행 미반환 (트래픽 절감)

Body (배치): JSON 배열 — 모든 객체의 키 셋 동일
[
  {
    "event_name": "session.photoViewing",
    "params": {"total": "5", "fromLibrary": "3", "fromAlbum": "1", "fromTrash": "1"},
    "device_model": "iPhone16,1",
    "os_version": "18.3",
    "app_version": "1.0.0",
    "photo_bucket": "1K-5K"
  },
  { ... }
]

Body (단건): 같은 형태의 단일 객체 (배열 아님)
{ "event_name": "app.launched", "params": {}, ... }

응답:
  201 Created — 성공 (return=minimal이므로 body 비어있음)
  403 Forbidden — RLS 정책 위반 (화이트리스트에 없는 event_name)
  400 Bad Request — JSON 형식 오류 또는 키 불일치
```

> **키 동일 제약**: `id`(IDENTITY)와 `created_at`(DEFAULT now())은 전송하지 않음.
> 전송하는 6개 키(`event_name`, `params`, `device_model`, `os_version`, `app_version`, `photo_bucket`)는
> 모든 이벤트에서 항상 동일하므로 키 불일치 문제 없음.

### 에러 처리

- 네트워크 실패, 4xx, 5xx 모두 **무시** (TD가 주 데이터)
- `#if DEBUG`에서만 상태코드 + 에러 로깅: `Log.print("[Supabase] OK batch 5 events")` 또는 `Log.print("[Supabase] Error 403: ...")`
- 재시도 없음, 큐잉 없음

### 백그라운드 플러시 안전성

`handleSessionEnd()` → `flushCounters()` 경로는 앱 백그라운드 진입 시 호출됨 (SceneDelegate:290).
iOS가 ~5초 내에 앱을 suspend할 수 있으므로:

1. `sendBatch()`로 **1회 POST**에 모든 세션 이벤트 전송 (6개 개별 POST → 1개 배치)
2. **SceneDelegate.sceneDidEnterBackground에 `beginBackgroundTask` 추가** (현재 미사용):
   ```swift
   // SceneDelegate.swift — sceneDidEnterBackground (현재 L290)
   func sceneDidEnterBackground(_ scene: UIScene) {
       AppStateStore.shared.handleBackgroundTransition()

       // Supabase POST 완료를 위한 백그라운드 시간 확보 (~30초)
       var bgTaskID: UIBackgroundTaskIdentifier = .invalid

       // 스레드 안전한 종료 헬퍼 (만료 핸들러와 completion이 동시 호출되는 경합 방지)
       let endTask = {
           DispatchQueue.main.async {
               guard bgTaskID != .invalid else { return }  // 이미 종료됨
               UIApplication.shared.endBackgroundTask(bgTaskID)
               bgTaskID = .invalid
           }
       }

       bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "AnalyticsFlush") {
           // 만료 핸들러: 시간 초과 시 즉시 종료
           endTask()
       }

       // Supabase POST 완료 콜백에서 endBackgroundTask 호출
       // ⚠️ handleSessionEnd 내부 동기 경로에서 호출될 수 있으므로 반드시 먼저 설정
       AnalyticsService.shared.onFlushComplete = {
           endTask()
       }

       // [Analytics] 세션 종료 — TD 전송(동기) + Supabase POST(비동기)
       AnalyticsService.shared.handleSessionEnd()

       // 코치마크 C: 백그라운드 진입 시 대기 상태 리셋
       // ... (기존 코드 유지)
   }
   ```
   - TelemetryDeck SDK는 자체 백그라운드 처리가 있으므로 별도 보호 불필요
   - `onFlushComplete`는 AnalyticsService에 추가할 옵셔널 클로저 프로퍼티 (`var onFlushComplete: (() -> Void)?`)

---

## Phase 3: AnalyticsService 수정

### 3-1. `AnalyticsService.swift` 수정 (~50줄 추가)

**추가할 프로퍼티** (Properties 섹션, L104 이후):

```swift
/// Supabase 이벤트 전송 프로바이더 (credentials 없으면 nil → 비활성)
private var supabaseProvider: SupabaseProvider?

/// Supabase에 보내지 않을 이벤트 목록 (비용 절감)
private static let supabaseExcluded: Set<String> = [
    "permission.result",       // 극소량, TD에서 충분
    "session.gridPerformance", // 카운트만, 드릴다운 가치 낮음
]

/// 백그라운드 플러시 완료 콜백 (SceneDelegate의 endBackgroundTask용)
var onFlushComplete: (() -> Void)?
```

**추가할 메서드 — configureSupabase()** (configure() 마지막에서 호출):

```swift
/// Supabase 프로바이더 초기화
/// - Info.plist에서 SUPABASE_URL, SUPABASE_ANON_KEY 읽기
/// - 키가 없으면 (xcconfig 미설정) 비활성 → TD만 동작
private func configureSupabase() {
    guard let url = Bundle.main.infoDictionary?["SUPABASE_URL"] as? String,
          let key = Bundle.main.infoDictionary?["SUPABASE_ANON_KEY"] as? String,
          !url.isEmpty, !key.isEmpty else {
        Log.print("[Supabase] credentials 없음 — 비활성")
        return
    }
    supabaseProvider = SupabaseProvider(baseURL: url, anonKey: key)
    Log.print("[Supabase] 초기화 완료 (url: \(url.prefix(30))...)")
}
```

**configure() 수정** (L143 `isConfigured = true` 이후에 1줄 추가):

```swift
func configure(appID: String) {
    // ... (기존 코드 그대로)
    TelemetryDeck.initialize(config: config)
    isConfigured = true
    configureSupabase()  // ← 추가
    Log.print("[Analytics] SDK 초기화 완료 ...")
}
```

**추가할 메서드 — sendEvent()** (Guard Helper 섹션 이후):

```swift
// MARK: - Dual Send Helpers

/// TD + Supabase 이중 전송 (즉시 전송형 이벤트용)
/// - TelemetryDeck: 항상 전송 (SDK가 "PickPhoto." prefix 자동 추가)
/// - Supabase: supabaseExcluded에 없을 때만 전송
func sendEvent(_ name: String, parameters: [String: String] = [:]) {
    TelemetryDeck.signal(name, parameters: parameters)

    guard !Self.supabaseExcluded.contains(name) else { return }
    let bucket = queue.sync { photoLibraryBucket }
    supabaseProvider?.send(
        eventName: name,
        params: parameters,
        photoBucket: bucket
    )
}

/// TD 개별 전송 + Supabase 배치 전송 (flushCounters용)
/// - TD: 이벤트 개별 signal (기존 동작 유지)
/// - Supabase: 제외 필터링 후 남은 이벤트를 1회 배치 POST
func sendEventBatch(_ events: [(name: String, parameters: [String: String])]) {
    // 1) TD 개별 전송
    for event in events {
        TelemetryDeck.signal(event.name, parameters: event.parameters)
    }

    // 2) Supabase 배치 전송 (제외 목록 필터링)
    let bucket = queue.sync { photoLibraryBucket }
    let payloads = events
        .filter { !Self.supabaseExcluded.contains($0.name) }
        .map { SupabaseProvider.EventPayload(
            eventName: $0.name,
            params: $0.parameters,
            photoBucket: bucket
        )}

    // supabaseProvider가 nil(xcconfig 미설정)이면 completion 누락 방지를 위해 guard let 사용
    if let provider = supabaseProvider, !payloads.isEmpty {
        provider.sendBatch(events: payloads) { [weak self] in
            self?.onFlushComplete?()
            self?.onFlushComplete = nil
        }
    } else {
        // provider nil 또는 Supabase 대상 이벤트 없음 → 즉시 완료
        onFlushComplete?()
        onFlushComplete = nil
    }
}
```

> **시그널 이름 규칙**: `sendEvent("app.launched")` → TD SDK가 `"PickPhoto.app.launched"`로 전송.
> Supabase에는 `"app.launched"` 그대로 저장 (RLS 화이트리스트와 일치).

### 3-2. TelemetryDeck.signal() → sendEvent() 교체 (11곳, 4개 파일)

| 파일 | 교체 수 | Supabase 전송 여부 |
|------|:---:|---|
| `+Lifecycle.swift` | 2곳 | 1개 O (app.launched), 1개 X (permission.result 제외) |
| `+Session.swift` (flushCounters 내부) | 6곳 → sendEventBatch() 1회 | 5개 O, 1개 X (gridPerformance 제외) |
| `+Similar.swift` | 1곳 | O |
| `+Cleanup.swift` | 2곳 | O |

교체 후 이 4개 파일에서 `import TelemetryDeck` 제거 가능 (SDK 의존성이 본체 1개 파일로 집중)

#### +Lifecycle.swift 변경 (L23, L34)

```swift
// Before:
TelemetryDeck.signal("app.launched")
TelemetryDeck.signal("permission.result", parameters: [...])

// After:
sendEvent("app.launched")
sendEvent("permission.result", parameters: [...])
// → sendEvent 내부에서 supabaseExcluded 체크하므로 호출부 변경 없음
```

#### +Similar.swift 변경 (L42)

```swift
// Before:
TelemetryDeck.signal("similar.groupClosed", parameters: [...])

// After:
sendEvent("similar.groupClosed", parameters: [...])
```

#### +Cleanup.swift 변경 (L40, L50)

```swift
// Before:
TelemetryDeck.signal("cleanup.completed", parameters: params)
TelemetryDeck.signal("cleanup.previewCompleted", parameters: [...])

// After:
sendEvent("cleanup.completed", parameters: params)
sendEvent("cleanup.previewCompleted", parameters: [...])
```

#### +Session.swift handleSessionEnd() 수정 (shouldSkip 경로 보강)

```swift
// Before:
func handleSessionEnd() {
    guard !shouldSkip() else { return }  // ← shouldSkip이면 flushCounters 미호출
    // ...
}

// After:
func handleSessionEnd() {
    guard !shouldSkip() else {
        // shouldSkip이어도 onFlushComplete 호출 필요 (SceneDelegate의 endBackgroundTask 해제)
        onFlushComplete?()
        onFlushComplete = nil
        return
    }
    // ... (기존 코드 그대로)
}
```

#### +Session.swift flushCounters() 리팩토링 (가장 큰 변경)

```swift
// ═══ Before (현재 코드, L116~184) ═══
private func flushCounters(_ c: SessionCounters) {
    var sentCount = 0

    if !c.photoViewing.isZero {
        TelemetryDeck.signal("session.photoViewing", parameters: [
            "total":       String(c.photoViewing.total),
            "fromLibrary": String(c.photoViewing.fromLibrary),
            "fromAlbum":   String(c.photoViewing.fromAlbum),
            "fromTrash":   String(c.photoViewing.fromTrash),
        ])
        sentCount += 1
    }
    // ... (deleteRestore, trashViewer, similarAnalysis, errors, gridPerformance 각각 동일 패턴)
    Log.print("[Analytics] 플러시 완료 — \(sentCount)건 시그널 전송")
}

// ═══ After (변경 후) ═══
private func flushCounters(_ c: SessionCounters) {
    var events: [(name: String, parameters: [String: String])] = []

    // ── 이벤트 3: 사진 열람 ──
    if !c.photoViewing.isZero {
        events.append(("session.photoViewing", [
            "total":       String(c.photoViewing.total),
            "fromLibrary": String(c.photoViewing.fromLibrary),
            "fromAlbum":   String(c.photoViewing.fromAlbum),
            "fromTrash":   String(c.photoViewing.fromTrash),
        ]))
    }

    // ── 이벤트 4-1: 보관함/앨범 삭제·복구 ──
    if !c.deleteRestore.isZero {
        events.append(("session.deleteRestore", [
            "gridSwipeDelete":     String(c.deleteRestore.gridSwipeDelete),
            "gridSwipeRestore":    String(c.deleteRestore.gridSwipeRestore),
            "viewerSwipeDelete":   String(c.deleteRestore.viewerSwipeDelete),
            "viewerTrashButton":   String(c.deleteRestore.viewerTrashButton),
            "viewerRestoreButton": String(c.deleteRestore.viewerRestoreButton),
            "fromLibrary":         String(c.deleteRestore.fromLibrary),
            "fromAlbum":           String(c.deleteRestore.fromAlbum),
        ]))
    }

    // ── 이벤트 4-2: 휴지통 뷰어 행동 ──
    if !c.trashViewer.isZero {
        events.append(("session.trashViewer", [
            "permanentDelete": String(c.trashViewer.permanentDelete),
            "restore":         String(c.trashViewer.restore),
        ]))
    }

    // ── 이벤트 5-1: 유사 사진 분석 ──
    if !c.similarAnalysis.isZero {
        events.append(("session.similarAnalysis", [
            "completedCount":  String(c.similarAnalysis.completedCount),
            "cancelledCount":  String(c.similarAnalysis.cancelledCount),
            "totalGroups":     String(c.similarAnalysis.totalGroups),
            "avgDurationSec":  String(format: "%.1f", c.similarAnalysis.averageDuration),
        ]))
    }

    // ── 이벤트 6: 앱 오류 ──
    if !c.errors.isEmpty {
        let params = c.errors.compactMapValues { $0 > 0 ? String($0) : nil }
        if !params.isEmpty {
            events.append(("session.errors", params))
        }
    }

    // ── 이벤트 8: 그리드 성능 ──
    if !c.gridPerformance.isZero {
        events.append(("session.gridPerformance", [
            "grayShown": String(c.gridPerformance.grayShown),
        ]))
    }

    // ── 이중 전송 (TD 개별 + Supabase 배치) ──
    guard !events.isEmpty else {
        onFlushComplete?()
        onFlushComplete = nil
        return
    }
    sendEventBatch(events)
    Log.print("[Analytics] 플러시 완료 — \(events.count)건 시그널 전송")
}
```

> **변경 핵심**: 6개 `TelemetryDeck.signal()` 직접 호출 → 배열 구성 + `sendEventBatch()` 1회.
> 이벤트 구성 로직(isZero 체크, 파라미터 조립)은 **그대로 유지**, 전송부만 교체.

### 3-3. Supabase에 보내지 않을 이벤트 (2종, 비용 절감)

| 이벤트 | 제외 이유 |
|--------|----------|
| `permission.result` | 극소량 (첫 실행/설정변경 시만), TD에서 충분 |
| `session.gridPerformance` | 카운트만, 드릴다운 가치 낮음 |

> `app.launched`는 포함: Supabase 단독 분석 시 세션 수(분모) 역할 필수. DAU 1,000 기준 +30K rows/월로 비용 영향 미미.

### 3-4. Credentials 전달

- `Supabase.xcconfig` (git-ignored) → Info.plist에 `$(SUPABASE_URL)`, `$(SUPABASE_ANON_KEY)` 참조
- anon key는 JWT 기반 클라이언트용 키로, 노출되어도 RLS가 INSERT만 허용 (INSERT 전용 + 화이트리스트, SELECT/UPDATE/DELETE 정책 없음)
- **Xcode 프로젝트 설정 필요**: Project > Info > Configurations에서 Debug/Release 모두 `Supabase.xcconfig` 지정
  (현재 xcconfig 없음, baseConfigurationReference 미설정 상태)
- **xcconfig URL 이스케이프**: `//`가 xcconfig에서 주석으로 해석되므로 반드시 이스케이프
  ```xcconfig
  // ❌ https://xxx.supabase.co  → // 이후가 주석 처리됨
  // ✅ https:/$()/xxx.supabase.co  → 정상 동작
  SUPABASE_URL = https:/$()/xxx.supabase.co
  SUPABASE_ANON_KEY = eyJ...
  ```

### 3-5. photo_bucket 처리

현재 코드의 `bucketString(for:)` 반환값을 그대로 TEXT 컬럼에 저장.
별도 매핑 함수 불필요 — 기존 `photoLibraryBucket` 문자열을 그대로 전달.

실제 반환값 (AnalyticsService.swift:162~173):
`"0"`, `"1-100"`, `"101-500"`, `"501-1K"`, `"1K-5K"`, `"5K-10K"`, `"10K-50K"`, `"50K-100K"`, `"100K+"` (9단계)

### 볼륨 추정 (DAU 1,000 기준)

- 제외 후: ~5-6 signals/session → 270K rows/month → ~135MB/month
- 90일 보존 (pg_cron 자동 삭제): ~405MB → 500MB 무료 한도 내

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
3. 제외 이벤트(`permission.result`, `gridPerformance`)에 `[Supabase]` 로그 없음 확인
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
| **수정** | `AnalyticsService.swift` | +50줄 (provider, sendEvent, sendEventBatch, configureSupabase, onFlushComplete) |
| **수정** | `+Lifecycle.swift` | 2줄 변경, import 제거 |
| **수정** | `+Session.swift` | flushCounters 리팩토링 (배치), import 제거 |
| **수정** | `+Similar.swift` | 1줄 변경, import 제거 |
| **수정** | `+Cleanup.swift` | 2줄 변경, import 제거 |
| **수정** | `SceneDelegate.swift` | beginBackgroundTask 래핑 추가 (L290 sceneDidEnterBackground) |
| **수정** | `Info.plist` | +2 키 (SUPABASE_URL, SUPABASE_ANON_KEY) |
| **수정** | `.gitignore` | +1줄 (Supabase.xcconfig) |
| **프로젝트** | `PickPhoto.xcodeproj` | Configurations에 Supabase.xcconfig 지정 (현재 baseConfigurationReference 없음) |

**총 신규 4개 / 확장 1개 / 수정 8개 / 프로젝트 설정 1개**

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
11. 배치 insert 시 동일 키 강제 주의사항 추가 (`Prefer: missing=default`는 동일 키 설계이므로 불필요, 미적용)
12. 백그라운드 전송: "필요시 추가" → `beginBackgroundTask` / `endBackgroundTask` / 만료 핸들러 구체 명시
13. pause 문구 완화: "7일간 API 호출 없으면" → "일정 기간 비활성 시" + pause 시 cron 중단 주의
14. pg_cron 경로: "Database > Extensions" → "Integrations > Cron (내부 pg_cron)"
15. .env.example: "신규 생성" → "기존 scripts/analytics/.env.example 확장"

**2026-02-17 3차 점검 (코드 대조 검증):**
- 실제 코드와 계획 대조 완료: TelemetryDeck.signal() 11곳, import 5개 파일, flushCounters 6개 시그널 — 모두 일치
16. ~~제외 3종~~ → 2종 (`app.launched` 포함 변경 — Supabase 단독 분석 시 분모 필요)
17. RLS 화이트리스트에 `app.launched` 추가 (9종)
18. 볼륨 재추정: ~5-6 signals/session → 270K rows/월 → 405MB/90일 (500MB 내)
19. xcconfig URL 이스케이프 주의사항 추가 (`//` → `/$()/`)
20. Phase 5 검증항목: 제외 이벤트 목록을 `permission.result`, `gridPerformance`으로 수정
21. 파일 변경 요약: SceneDelegate.swift 누락 → 추가, 총 수정 7개 → 8개
22. 상단에 Phase 1 체크리스트 추가 (주인님 수동 작업 가이드)
23. xcconfig 현재 상태 명시: baseConfigurationReference 없음, 신규 연결 필요

**2026-02-17 4차 점검 (실행 흐름 추적 검증):**
- SceneDelegate → handleSessionEnd → flushCounters → sendEventBatch 전체 경로 추적
24. **(Critical)** onFlushComplete 설정 순서: handleSessionEnd() 후 설정 → **전으로 이동** (동기 경로에서 nil 호출 방지)
25. **(Critical)** supabaseProvider nil 시 completion 누락: `supabaseProvider?.sendBatch()` → **`guard let provider`로 변경** (else에서 onFlushComplete 호출)
26. sendBatch 시그니처: `func sendBatch(events:)` → **`func sendBatch(events:completion:)` 추가**
27. photo_bucket 예시값: `"0-1k"` 등 → 실제 코드 9단계 값으로 수정
28. AnalyticsService 수정 줄수: ~35줄 → ~50줄

**2026-02-17 5차 점검 (GPT Codex 교차 리뷰 #2 → 타당성 검증):**
- GPT 6개 이슈 중 4개 반영, 2개 기각
29. **(High)** handleSessionEnd `shouldSkip()` 조기 리턴 시 `onFlushComplete?()` 미호출 → 호출 추가
30. **(High)** SceneDelegate endBackgroundTask 경합 방지: 만료 핸들러/completion 동시 호출 대비 `endTask()` 헬퍼 추출 + `.invalid` 가드 + `DispatchQueue.main.async`
31. Credentials 섹션에 "JWT 기반 anon key" 명시
32. 검토 기록 11번 정정: `Prefer: missing=default` 추가 → 동일 키 설계이므로 불필요, 미적용
- 기각: RLS params 크기 제한 (1인 개발 앱, 과도), 응답코드 범위 (이미 커버됨)

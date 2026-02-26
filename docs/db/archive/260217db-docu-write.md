# Analytics 문서 재편 계획

## 상태: Supabase 구현 완료 → 문서 재편 진행 가능

### 구현 완료 확인 (2026-02-25)

| 구현 단계 | 상태 |
|---|---|
| Supabase 프로젝트 생성 + 테이블/RLS/RPC | ✅ 완료 |
| SupabaseProvider.swift 구현 | ✅ 완료 (166줄) |
| AnalyticsService 수정 (sendEvent/sendEventBatch) | ✅ 완료 |
| 4개 Extension TelemetryDeck.signal → sendEvent 교체 | ✅ 완료 |
| SceneDelegate beginBackgroundTask 래핑 | ✅ 완료 |
| 쿼리 스크립트 (sb-query.sh, sb-report.sh) | ✅ 완료 |
| 실데이터 검증 (HTTP 201, Dashboard 확인) | ✅ 완료 |

### DBplan1.md 처리

DBplan1은 기획 문서로서 이미 역할 완료:
- §3(솔루션), §4(이벤트), §7(비용) → Spec.md에서 정제됨
- §5(아키텍처) → Archi.md에서 재설계됨
- §6(삽입 지점), §10(로드맵) → Impl.md에서 대체됨
- §1(전략 프레임워크), §2(경쟁사 분석), §8(프라이버시), §9(데이터 활용), 참고자료 → 미흡수이나, 앱 전략/운용 가이드 성격으로 Analytics 기술 문서에 포함할 필요 없음. archive에서 필요 시 참조

→ DBplan1은 문서 재편 시 **통째로 archive**. 신규 문서에서 참조하지 않음.

---

## 아래는 구현 완료 후 참조할 재편 계획

---

## 목표

기존 소스 문서 7개 + 이 계획서 1개 = **총 8개를 영구 참조 문서 3개로 재편**한다.
TD(TelemetryDeck) + Supabase 하이브리드 체계를 하나의 통합된 문서 세트로 정리한다.

> **전제 조건**: Supabase 구현 완료 후 진행

---

## 문서 분류 기준

| 성격 | 수명 | 해당 문서 |
|------|------|----------|
| **Spec** — 무엇을, 왜 수집하는가 | 영구 (이벤트 추가/변경 시 갱신) | Spec |
| **Archi** — 어떻게 설계했는가 | 영구 (구조 변경/확장 시 갱신) | Archi |
| **API** — 어떻게 조회하는가 | 영구 (데이터 분석할 때마다 참조) | API |
| **Impl** — 어떻게 구현하는가 | 일회성 (구현 끝나면 archive) | 작성 안 함 |

Impl은 신규 작성하지 않는다. 기존 Impl.md(TD 구현 완료)와 hybrid.md(Supabase 구현 완료)는 그대로 archive.

---

## 파일명

### 신규 문서 (3개)

| 파일명 | 역할 |
|--------|------|
| `docs/db/260225db-Spec.md` | 이벤트 정의, 솔루션, 비용, 프라이버시 |
| `docs/db/260225db-Archi.md` | SDK 구조, 세션 관리, Provider 계층, Supabase 인프라 |
| `docs/db/260225db-API.md` | TD 쿼리 + Supabase 쿼리 스크립트, 실측 메모 |

### 기존 문서 → archive (8개)

| 기존 파일 | 처리 |
|----------|------|
| `260211DBplan1.md` | `archive/` 이동 (통째로, 신규 문서에서 미참조) |
| `260212db-Spec.md` | `archive/` 이동 |
| `260212db-Archi.md` | `archive/` 이동 |
| `260212db-Impl.md` | `archive/` 이동 |
| `260213db-API-Query.md` | `archive/` 이동 |
| `260213db-API-impl.md` | `archive/` 이동 |
| `260217db-hybrid.md` | `archive/` 이동 |
| `260217db-docu-write.md` | `archive/` 이동 (이 문서) |

---

## 목차

### 1. Spec (무엇을, 왜)

```
1. 솔루션 선정
   - TelemetryDeck: 확정 (프라이버시 대시보드)
   - Supabase: 확정 (Claude용 원시 데이터)
   - 하이브리드 원칙: TD 유지, Supabase 보조
   - (← Spec §1 수정 + hybrid Context 흡수)

2. 비용
   - TD: 세션 요약 기준 MAU 80건, 무료 한도
   - Supabase: 제외 이벤트 2종, 월 270K rows, 90일 보존 (pg_cron은 DAU 1,000+ 이후 설정)
   - (← Spec §2 + hybrid 볼륨 추정 통합)

3. 이벤트 정의
   3.1 총괄표
   3.2 세션 정의 (시작/종료/플러시)
   3.3 사진 규모 구간
   3.4 이벤트 1~8 상세
   3.5 Supabase 전송 여부 (이벤트별 O/X)
   - (← Spec §3~6 그대로 + hybrid 제외 목록)

4. 프라이버시
   - 공통 자동 수집 데이터
   - 절대 수집 금지 항목
   - (← Spec §7~8 그대로)

5. 변경 이력
```

### 2. Archi (어떻게 설계했는가)

```
1. TelemetryDeck SDK
   - 핵심 API, 세션 관리, Config, Privacy Manifest
   - (← Archi §2 그대로)

2. 래퍼 계층
   - 방안 C (프로토콜 분리), Backend 없는 단순 구조
   - SupabaseProvider 추가 (URLSession, 배치 POST)
   - (← Archi §3 수정 + hybrid Phase 2)

3. 세션 관리
   - SessionCounters, 스레드 안전성 (barrier sync)
   - 플러시: 배치 전송, beginBackgroundTask + endTask() 헬퍼 (스레드 안전)
   - onFlushComplete 콜백 패턴, shouldSkip 조기 리턴 시 완료 처리
   - (← Archi §4 수정 + hybrid 백그라운드 안전성 + 5차 검토 반영)

4. 이벤트 수집기
   - 시그널 이름 총괄, Enum 13종
   - sendEvent / sendEventBatch 헬퍼
   - 프로토콜 최종 확정 (§5.6)
   - (← Archi §5 수정 + hybrid Phase 3)

5. Supabase 인프라
   - 테이블 스키마 (events)
   - RLS 정책 (이벤트 화이트리스트 9종)
   - RPC 함수 3개 (SQL 포함)
   - pg_cron 90일 자동 삭제 (DAU 1,000+ 이후 설정)
   - Credentials 전달 (xcconfig → Info.plist, URL 이스케이프 주의)
   - Xcode Project Configurations 연결 절차
   - Supabase 무료 티어 pause 주의사항
   - Supabase UI 키 명칭: anon key = "Publishable Key", service_role = "Secret Key"
   - (← hybrid Phase 1 + Phase 3 credentials + 구현 실측)

6. 파일 구조
   - 기존 12개 + 신규 4개 (SupabaseProvider, xcconfig, sb-*.sh)
   - 의존성 그래프
   - (← Archi §6 수정)
```

### 3. API (어떻게 조회하는가)

```
1. TelemetryDeck Query API
   1.1 인증 흐름, 3단계 비동기 실행
   1.2 실측 메모 (dataSource, eventCount vs count, isTestMode 등)
   1.3 삽질 기록
   - (← Archi §7 + API-Query 전체 통합)

2. TD 스크립트
   2.1 파일 구조 (.env, td-auth, td-query, td-report)
   2.2 쿼리 템플릿 10개
   2.3 사용 예시
   - (← API-impl §2~5, §7)

3. Supabase Query
   3.1 PostgREST REST API + RPC 호출
   3.2 sb-query.sh / sb-report.sh
   3.3 .env에 Supabase 변수 3개 (sb-query는 service_role key 사용)
   3.4 service_role key 보안 주의
   3.5 사용 예시
   - (← hybrid Phase 4 + 구현 실측)

4. Claude 분석 워크플로우
   - TD 리포트 → Supabase 드릴다운 시나리오
   - (← Archi §7 Claude 워크플로우 + 신규)

5. 주의사항
   - TD API 유료 전환 예고, longSum 미검증, Supabase 비활성 시 자동 pause
   - (← API-impl §8 + hybrid 주의사항)
```

---

## 기존 문서 섹션 매핑

### DBplan1.md (762줄) → 통째로 archive

이미 Spec/Archi/Impl에서 정제·대체 완료. 신규 문서에서 참조하지 않음.
미흡수 섹션(§1 전략, §2 경쟁사 분석, §8 프라이버시 전략, §9 데이터 활용, 참고자료)은 Analytics 기술 문서 범위 밖.

### Spec.md (506줄)

| 섹션 | 줄 | → | 처리 |
|------|:---:|---|------|
| 1. 솔루션 선정 | ~58 | **Spec §1** | 수정 (Supabase 확정) |
| 2. 비용 시뮬레이션 | ~53 | **Spec §2** | 수정 (Supabase 비용 추가) |
| 3. 이벤트 총괄표 | ~18 | **Spec §3.1** | 그대로 |
| 4. 세션 정의 | ~11 | **Spec §3.2** | 그대로 |
| 5. 사진 규모 구간 | ~23 | **Spec §3.3** | 그대로 |
| 6. 이벤트 상세 | ~255 | **Spec §3.4** | 그대로 (SSOT) |
| 7. 공통 자동 수집 | ~15 | **Spec §4** | 그대로 |
| 8. 수집 안 함 | ~13 | **Spec §4** | 그대로 |
| 9. 변경 이력 | ~37 | **Spec §5** | 그대로 |

### Archi.md (1,474줄)

| 섹션 | 줄 | → | 처리 |
|------|:---:|---|------|
| 1. 설계 계획 | ~18 | archive | 완료 |
| 2. TD SDK API | ~125 | **Archi §1** | 그대로 |
| 3. 래퍼 계층 설계 | ~111 | **Archi §2** | 수정 (Supabase provider) |
| 4. 세션 관리 설계 | ~339 | **Archi §3** | 수정 (배치, backgroundTask) |
| 5. 이벤트 수집기 | ~451 | **Archi §4** | 수정 (sendEvent/Batch) |
| 6. 파일 구조 | ~210 | **Archi §6** | 수정 (신규 파일 추가) |
| 7. 데이터 접근 경로 | ~199 | **API §1/§4/§5** | 분해: TD Query→§1, Claude 워크플로우→§4, 주의사항→§5 |

### Impl.md (744줄)

| 전체 | 744 | archive | TD 구현 완료, 그대로 이동 |

### API-Query.md (149줄)

| 전체 | 149 | **API §1** | 그대로 (TD 실측 메모) |

### API-impl.md (422줄)

| §2~5 (파일 구조, credentials, 스크립트) | ~350 | **API §2** | 그대로 (TD 스크립트) |
| §7 (사용 시나리오) | ~29 | **API §2** | 그대로 |
| §8 (주의사항) | ~24 | **API §5** | 그대로 |
| §1, §6 (목표, 구현 순서) | ~25 | archive | 구현 완료, 불필요 |

### hybrid.md (703줄, 구현 중 대폭 확장됨)

| 섹션 | → | 처리 |
|------|---|------|
| Context (하이브리드 원칙) | **Spec §1** | 솔루션 선정에 흡수 |
| 구현 전 체크리스트 | archive | 구현 완료, Archi §5에 절차 반영 |
| Phase 1 (Supabase 셋업 SQL) | **Archi §5** | 스키마/RLS/RPC SQL만 |
| Phase 2 (SupabaseProvider 클래스 설계) | **Archi §2** | 시그니처/구조만, 구체 코드는 archive에서 참조 |
| Phase 3 (AnalyticsService 수정 설계) | **Archi §4** | 시그니처/흐름만, 구체 코드는 archive에서 참조 |
| Phase 3-3 (제외 이벤트 목록) | **Spec §3.5** | Supabase 전송 여부 표에 흡수 |
| Phase 3-4 (Credentials 전달) | **Archi §5** | xcconfig/URL 이스케이프 포함 |
| Phase 3-5 (photo_bucket 처리) | **Archi §4** | 기존 bucketString 설명에 흡수 |
| Phase 3 볼륨 추정 | **Spec §2** | 비용 섹션에 흡수 |
| Phase 3 (구체 코드: flushCounters before/after 등) | archive | Impl 성격 — archive의 hybrid.md에서 필요시 참조 |
| Phase 4 (쿼리 스크립트) | **API §3** | 그대로 |
| Phase 5 (검증) | archive | 구현 완료 |
| 파일 변경 요약 | **Archi §6** | 파일 구조에 흡수 |
| 검토 기록 (5차, 32항목) | archive | 흡수 완료 후 불필요 |

---

## 작업 순서

> **전제**: Supabase 구현 완료 후 진행

### Step 1: Spec 작성

- 기존 Spec.md + hybrid 제외 목록 통합
- "그대로" 섹션은 복사, "수정" 섹션은 Supabase 반영
- 예상: ~450줄

### Step 2: Archi 작성

- 기존 Archi.md §2~6 + hybrid Phase 1~3 설계 부분 통합
- 가장 수정 분량이 많음 (Supabase provider, 배치 전송, 인프라)
- 예상: ~1,350줄

### Step 3: API 작성

- Archi §7(골격) + API-Query(실측 보강) + API-impl §2~5,§7~8 + hybrid Phase 4 통합
- TD/Supabase 양쪽 조회 방법을 하나로
- Archi §7과 API-Query의 겹침(인증 흐름, 쿼리 예시)은 API-Query의 실측 기준으로 통합
- 예상: ~890줄

### Step 4: 정리

- 기존 8개(소스 7개 + 이 계획서) → `docs/db/archive/` 이동

---

## 작업 규칙

- 각 Step 시작 전 주인님 확인
- 문서 작성 시 원본 섹션을 Read → 필요 부분 가져오기 → 수정
- 기존 문서는 작성 완료 전까지 삭제/이동하지 않음 (참조용 유지)

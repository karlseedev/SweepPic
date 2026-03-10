# Supabase 메인 DB 승격 — 전 이벤트 수집 + is_test + 오프라인 큐

## Context

TD가 불편하고, 유저 증가 시 비용 문제로 못 쓸 수 있으므로 Supabase를 메인 Analytics DB로 승격한다. TD 없이도 데이터 손실 없이 운영 가능하도록 오프라인 큐/재시도를 추가한다. TD는 당분간 백업으로 유지.

---

## Phase 1: 전 이벤트 수집 + is_test (코드 변경 최소)

### 1-1. `supabaseExcluded` 비우기

**파일:** `PickPhoto/PickPhoto/Shared/Analytics/AnalyticsService.swift:118-121`

```swift
// before
private static let supabaseExcluded: Set<String> = [
    "permission.result",
    "session.gridPerformance",
]
// after
private static let supabaseExcluded: Set<String> = []
```

`sendEvent()`과 `sendEventBatch()`의 필터 로직은 그대로 유지 (빈 Set → 전부 통과).

### 1-2. `is_test` 필드 추가

**파일:** `PickPhoto/PickPhoto/Shared/Analytics/SupabaseProvider.swift:141-150`

```swift
// before: return 딕셔너리 리터럴
// after: var + #if DEBUG
private func makeBody(...) -> [String: Any] {
    var body: [String: Any] = [
        "event_name": eventName,
        "params": params,
        "device_model": deviceModel,
        "os_version": osVersion,
        "app_version": appVersion,
        "photo_bucket": photoBucket,
    ]
    #if DEBUG
    body["is_test"] = true
    #else
    body["is_test"] = false
    #endif
    return body
}
```

> Swift Bool → JSONSerialization → JSON `true`/`false` → Postgres BOOLEAN 정상 매핑.

### 1-3. Supabase DB 변경 (Dashboard SQL Editor에서 수동 실행)

```sql
-- 1) is_test 컬럼 추가 (기존 행은 전부 디버그 데이터이므로 DEFAULT true)
ALTER TABLE events ADD COLUMN is_test BOOLEAN NOT NULL DEFAULT true;

-- 2) RLS 정책: 이벤트 2종 추가 → 11종 전체
DROP POLICY IF EXISTS "anon_insert" ON events;
CREATE POLICY "anon_insert" ON events FOR INSERT TO anon
    WITH CHECK (
        event_name IN (
            'app.launched',
            'permission.result',
            'session.photoViewing',
            'session.deleteRestore',
            'session.trashViewer',
            'session.similarAnalysis',
            'session.errors',
            'similar.groupClosed',
            'cleanup.completed',
            'cleanup.previewCompleted',
            'session.gridPerformance'
        )
    );
```

> RLS는 event_name 화이트리스트만. is_test 필드에 별도 제약 불필요 (anon key는 INSERT만 가능).

### 1-4. `makeRequest()`에 `missing=default` 헤더 추가

**파일:** `PickPhoto/PickPhoto/Shared/Analytics/SupabaseProvider.swift:125-136`

```swift
// Prefer 헤더에 missing=default 추가
request.setValue("return=minimal, missing=default", forHTTPHeaderField: "Prefer")
```

> PostgREST `missing=default`: body에 누락된 NOT NULL DEFAULT 컬럼에 DB 기본값 자동 적용.
> 구버전 클라이언트가 `is_test` 미전송 시에도 DEFAULT true가 적용되어 INSERT 실패 방지.

---

## Phase 2: 오프라인 큐 + 재시도

### 2-1. SupabaseProvider에 큐 기능 추가

**파일:** `PickPhoto/PickPhoto/Shared/Analytics/SupabaseProvider.swift`

추가할 프로퍼티 (init에서 초기화):

```swift
private let fileQueue = DispatchQueue(label: "com.pickphoto.supabase.pending")
private let pendingFileURL: URL   // Application Support/supabase_pending.json
private let maxPendingCount = 200
```

> **저장 경로**: `Caches`가 아닌 `Application Support` 사용. Caches는 OS가 디스크 부족 시 삭제 가능하여 유실 방지 목표에 부합하지 않음. `isExcludedFromBackup = true` 설정으로 iCloud 백업에서 제외.

init에서 pendingFileURL 초기화:

```swift
// Application Support 디렉토리에 큐 파일 생성
let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
let dir = appSupport.appendingPathComponent("analytics", isDirectory: true)
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
var fileURL = dir.appendingPathComponent("supabase_pending.json")
var values = URLResourceValues()
values.isExcludedFromBackup = true
try? fileURL.setResourceValues(values)
self.pendingFileURL = fileURL
```

추가할 메서드:

```swift
/// HTTP 상태 코드 기반 재시도 판단
/// - 네트워크 에러(error != nil), 429, 5xx → 재시도 대상
/// - 4xx(400/401/403/404) → 영구 실패, 재시도 불가 (RLS/스키마 오류)
private func shouldRetry(response: URLResponse?, error: Error?) -> Bool {
    if error != nil { return true }  // 네트워크 에러/타임아웃
    guard let http = response as? HTTPURLResponse else { return true }
    if (200...299).contains(http.statusCode) { return false }  // 성공
    if http.statusCode == 429 { return true }  // Rate limit
    if http.statusCode >= 500 { return true }  // 서버 오류
    return false  // 4xx → 클라이언트 오류, 재시도 무의미
}

/// 실패한 이벤트를 파일에 저장 (atomic write)
private func enqueueForRetry(_ bodies: [[String: Any]]) {
    fileQueue.async {
        var queue = self.loadPendingQueue()
        queue.append(contentsOf: bodies)
        if queue.count > self.maxPendingCount {
            queue = Array(queue.suffix(self.maxPendingCount))
        }
        self.savePendingQueue(queue)  // .atomic 쓰기
    }
}

/// 파일에서 큐 로드
private func loadPendingQueue() -> [[String: Any]] { ... }

/// 큐를 파일에 atomic 저장
private func savePendingQueue(_ queue: [[String: Any]]) {
    guard let data = try? JSONSerialization.data(withJSONObject: queue) else { return }
    try? data.write(to: pendingFileURL, options: .atomic)
}

/// 보류 중인 이벤트 재전송 (포그라운드 진입 시 호출)
/// - 원자적 dequeue: 로드한 스냅샷만 전송, 성공 시 해당 항목만 제거
func flushPendingQueue() {
    fileQueue.async {
        let snapshot = self.loadPendingQueue()
        guard !snapshot.isEmpty else { return }
        let snapshotCount = snapshot.count

        // HTTP 전송 (동기 대기 — fileQueue 시리얼이므로 안전)
        // 성공 시: 현재 파일에서 앞쪽 snapshotCount개만 제거 (flush 중 추가된 항목 보존)
        // 실패 시: 파일 그대로 유지
        guard let jsonData = try? JSONSerialization.data(withJSONObject: snapshot) else { return }
        var request = self.makeRequest()
        request.httpBody = jsonData

        let semaphore = DispatchSemaphore(value: 0)
        var success = false

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
                success = true
            }
            semaphore.signal()
        }.resume()

        semaphore.wait()

        if success {
            // 전송 성공 → 전송한 항목만 제거 (flush 중 새로 추가된 항목은 보존)
            var current = self.loadPendingQueue()
            if current.count >= snapshotCount {
                current.removeFirst(snapshotCount)
            } else {
                current.removeAll()
            }
            self.savePendingQueue(current)
        }
    }
}
```

> `fileQueue` (시리얼)로 모든 파일 I/O를 직렬화하여 race condition 방지.
> URLSession completion handler(백그라운드 스레드)에서 호출해도 안전.
> **원자적 dequeue**: flush 중 새로 enqueue된 이벤트는 파일 뒤쪽에 추가되므로, 성공 시 앞쪽 스냅샷 개수만 제거하면 새 이벤트는 보존됨.

### 2-2. send() 실패 시 큐 저장

**파일:** `SupabaseProvider.swift` send() 메서드 (68-86줄)

```swift
func send(eventName:params:photoBucket:) {
    let body = makeBody(...)
    guard let jsonData = ... else { return }
    // ...
    URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            Logger.analytics.debug(...)
        } else {
            Logger.analytics.error(...)
            // 재시도 가능한 실패만 큐에 저장 (4xx 클라이언트 오류는 드롭)
            if self?.shouldRetry(response: response, error: error) == true {
                self?.enqueueForRetry([body])
            }
        }
    }.resume()
}
```

> `body`는 값 타입(`[String: Any]`), 클로저에서 복사 캡처되므로 안전.
> 4xx(400 RLS 위반, 403 권한 오류 등)는 재시도해도 영원히 실패하므로 드롭. 5xx/네트워크 에러/429만 큐에 저장.

### 2-3. sendBatch() 실패 시 큐 저장

**파일:** `SupabaseProvider.swift` sendBatch() 메서드 (93-120줄)

```swift
func sendBatch(events:completion:) {
    let bodyArray = events.map { makeBody(...) }
    // ...
    URLSession.shared.dataTask(with: request) { [weak self] _, response, error in
        if let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) {
            Logger.analytics.debug(...)
        } else {
            Logger.analytics.error(...)
            // 재시도 가능한 실패만 큐에 저장 (4xx 클라이언트 오류는 드롭)
            if self?.shouldRetry(response: response, error: error) == true {
                self?.enqueueForRetry(bodyArray)
            }
        }
        completion?()  // ← background task 종료는 성공/실패 모두 보장
    }.resume()
}
```

> `completion?()`은 항상 호출. SceneDelegate의 `endTask`는 이미 `DispatchQueue.main.async`로 보호됨 (343-347줄) → 스레드 안전성 확인 완료.
> 4xx(400 RLS 위반, 403 권한 오류 등)는 재시도해도 영원히 실패하므로 드롭.

### 2-4. 포그라운드 진입 시 큐 재전송

**파일:** `AnalyticsService.swift`

```swift
func flushPendingSupabaseEvents() {
    supabaseProvider?.flushPendingQueue()
}
```

> `supabaseProvider`는 private이므로 AnalyticsService 내부에서만 접근. 이 래퍼 메서드가 외부 인터페이스.

**파일:** `SceneDelegate.swift` sceneWillEnterForeground() (275-281줄)

```swift
AnalyticsService.shared.refreshPhotoLibraryBucket()
AnalyticsService.shared.trackAppLaunched()
AnalyticsService.shared.flushPendingSupabaseEvents()  // ← 추가
```

> 포그라운드 진입 시 네트워크가 복구되었을 가능성이 높으므로 이 시점이 적절.

---

## Phase 3: 테스트 스크립트 + 문서 업데이트

### 3-1. 검증 스크립트 수정

**파일:** `scripts/analytics/verify-test-inject.sh:124-127`

```bash
# before: 음성 테스트
check_absent "permission.result"
check_absent "session.gridPerformance"

# after: 양성 테스트
echo "[추가 이벤트 확인]"
check_exists "permission.result"
check "session.gridPerformance" "grayShown" "42"
```

검증 항목: 40개 유지 (구성만 변경)

### 3-2. 테스트 주입기 수정

**파일:** `PickPhoto/PickPhoto/Debug/AnalyticsTestInjector.swift`

`triggerImmediateEvents()`에서 `permission.result`이 Supabase에도 도달하므로 기존 코드 변경 불필요 (supabaseExcluded가 비었으므로 자동 통과).

### 3-3. 문서 업데이트

**`docs/db/260225db-Archi.md`:**
- §2.4 supabaseExcluded → 빈 Set 반영
- §2.5 SupabaseProvider → 오프라인 큐 설명 추가
- §5.1 테이블 스키마 → is_test 컬럼 추가
- §5.2 RLS 정책 → 11종 화이트리스트

**`docs/db/260226testA.md`:**
- §1.3 제외 검증 → 양성 테스트로 변경
- §6 검증 항목 총괄 → 반영

---

## 파일 변경 요약

| 구분 | 파일 | 변경 내용 | 변경량 |
|------|------|----------|:------:|
| 코드 | `AnalyticsService.swift` | supabaseExcluded 비우기 + flushPending 메서드 | ~5줄 |
| 코드 | `SupabaseProvider.swift` | is_test + missing=default 헤더 + 오프라인 큐 (enqueue/load/savePending/flush/shouldRetry) + send/sendBatch 선별적 재시도 | ~100줄 |
| 코드 | `SceneDelegate.swift` | flushPendingSupabaseEvents() 호출 | ~1줄 |
| DB | Supabase Dashboard | is_test 컬럼 + RLS 정책 | SQL 2문 |
| 스크립트 | `verify-test-inject.sh` | check_absent → check/check_exists | ~4줄 |
| 문서 | `260225db-Archi.md` | 아키텍처 반영 | ~20줄 |
| 문서 | `260226testA.md` | 테스트 계획 반영 | ~15줄 |

---

## 검증

1. **DB**: Supabase Dashboard에서 SQL 실행 → is_test 컬럼, RLS 11종 확인
2. **빌드**: Xcode 빌드 성공 확인
3. **실기기 테스트**: `run-test-inject-device.sh` → 40개 전체 PASS
4. **Supabase 확인**: permission.result, session.gridPerformance 행 존재 + is_test=true 확인
5. **오프라인 큐**: 비행기 모드 → 앱 사용 → 백그라운드 → 네트워크 복구 → 포그라운드 → 큐 데이터 전송 확인
6. **큐 파일 위치**: Application Support/analytics/supabase_pending.json 존재 확인 + isExcludedFromBackup 확인
7. **4xx 드롭**: 의도적 잘못된 event_name으로 400 유발 → 큐에 저장되지 않는지 확인

# PickPhoto Analytics 아키텍처

> **작성일:** 2026-02-25
> **상태:** 설계 완료 + 구현 완료 (TD + Supabase 하이브리드)
> **이전 문서:** 260212db-Archi.md (TD 단독) + 260217db-hybrid.md (Supabase 계획) → 이 문서로 통합
> **목적:** 어떻게 설계했는가 — 아키텍처 결정의 단일 참조 문서

---

## 목차

1. [TelemetryDeck SDK](#1-telemetrydeck-sdk)
2. [래퍼 계층](#2-래퍼-계층)
3. [세션 관리](#3-세션-관리)
4. [이벤트 수집기](#4-이벤트-수집기)
5. [Supabase 인프라](#5-supabase-인프라)
6. [파일 구조](#6-파일-구조)

---

## 1. TelemetryDeck SDK

### 1.1 기본 정보

| 항목 | 값 |
|------|-----|
| SPM URL | `https://github.com/TelemetryDeck/SwiftSDK` |
| 최신 버전 | 2.11.0 (2025-12) |
| 최소 iOS | 12.0 (우리 앱 iOS 16+ → 호환) |
| Swift Tools | 5.9 |
| Privacy Manifest | 내장 (`PrivacyInfo.xcprivacy`) |

### 1.2 핵심 API

**초기화:**
```swift
// AppDelegate.didFinishLaunchingWithOptions에서
let config = TelemetryDeck.Config(appID: "APP-ID")
TelemetryDeck.initialize(config: config)
```

**시그널 전송:**
```swift
TelemetryDeck.signal(
    _ signalName: String,
    parameters: [String: String] = [:],  // 값은 반드시 String
    floatValue: Double? = nil,
    customUserID: String? = nil
)
```

**Duration 추적 (내장):**
```swift
TelemetryDeck.startDurationSignal("cleanup.analysis")
// ... 작업 수행 ...
TelemetryDeck.stopAndSendDurationSignal("cleanup.analysis",
    parameters: ["result": "success"])
// → TelemetryDeck.Signal.durationInSeconds 자동 포함
```

**네비게이션 추적 (내장):**
```swift
TelemetryDeck.navigationPathChanged(from: "grid", to: "viewer")
```

### 1.3 세션 관리 — SDK 자동 처리

| 항목 | SDK 동작 |
|------|---------|
| 세션 ID 생성 | **백그라운드 5분 이상 경과 후** 포그라운드 복귀 시 자동 갱신 |
| 세션 시작 시그널 | `TelemetryDeck.Session.started` 자동 전송 (config `sendNewSessionBeganSignal`) |
| 최초 설치 감지 | `TelemetryDeck.Acquisition.newInstallDetected` 자동 전송 (1회) |
| 백그라운드 처리 | `didEnterBackgroundNotification` → 전송 타이머 중지 + 캐시 디스크 백업 (Background Task 사용) |
| 포그라운드 복귀 | `willEnterForegroundNotification` → 디스크 캐시 복원 + 전송 타이머 재시작 |
| 배치 전송 | `DispatchSource` 타이머, 10초 간격, 1회 최대 100건, 오프라인 큐 + 재시도 내장 *(v2.11.0 기준)* |

> **중요:** SDK의 세션(5분 타임아웃)과 우리의 세션(매 백그라운드 진입)은 **정의가 다르다.**
> SDK 세션은 리텐션/코호트용이고, 우리의 세션 요약은 별도로 관리해야 한다.

### 1.4 Config 주요 옵션

| 옵션 | 타입 | 기본값 | 우리 활용 |
|------|------|--------|----------|
| `defaultParameters` | `@Sendable () -> [String: String]` | `{ [:] }` | 사진 규모 구간 자동 첨부 |
| `sendNewSessionBeganSignal` | `Bool` | `true` | 기본 유지 |
| `salt` | `String` (let, init시 설정) | `""` | 선택적 추가 |
| `defaultSignalPrefix` | `String?` | `nil` | `"PickPhoto."` 사용 |
| `analyticsDisabled` | `Bool` | `false` | 사용자 옵트아웃 시 활용 |
| `testMode` | `Bool` | DEBUG면 `true` | 자동 처리됨 |
| `metadataEnrichers` | `[SignalEnricher]` | `[]` | 커스텀 메타데이터 확장 가능 |
| `sessionStatsEnabled` | `Bool` | `true` | 리텐션 자동 추적 |

### 1.5 SDK 자동 수집 메타데이터

| 카테고리 | 포함 항목 |
|---------|----------|
| 앱 | version, buildNumber |
| 기기 | modelName, architecture, operatingSystem, screenResolution, orientation, timeZone |
| OS | systemVersion, systemMajorVersion |
| 실행 컨텍스트 | isAppStore, isDebug, isSimulator, isTestFlight, language, locale |
| 사용자 설정 | colorScheme (Dark/Light), layoutDirection, region |
| 접근성 | reduceMotion, boldText, invertColors, reduceTransparency, preferredContentSizeCategory |
| 세션 통계 | firstSessionDate, averageSessionSeconds, distinctDaysUsed, totalSessionsCount |
| 캘린더 | dayOfWeek, hourOfDay, isWeekend, monthOfYear, quarterOfYear |

### 1.6 Duration / Navigation API 상세

```swift
// Duration — @MainActor, 백그라운드 시간 자동 제외
TelemetryDeck.startDurationSignal("cleanup", parameters: ["method": "auto"])
TelemetryDeck.stopAndSendDurationSignal("cleanup", parameters: ["result": "done"])
TelemetryDeck.cancelDurationSignal("cleanup")  // 전송 없이 취소

// Navigation — @MainActor
TelemetryDeck.navigationPathChanged(from: "grid", to: "viewer")
TelemetryDeck.navigationPathChanged(to: "viewer")  // 이전 destination이 자동으로 source
```

### 1.7 Privacy Manifest 선언 내용

```
NSPrivacyTracking: false
NSPrivacyAccessedAPITypes: UserDefaults (CA92.1)
NSPrivacyCollectedDataTypes:
  - ProductInteraction → Linked: false, Tracking: false, Purpose: Analytics
  - DeviceID → Linked: false, Tracking: false, Purpose: Analytics
```

### 1.8 아키텍처 설계에 미치는 영향

| 발견 | 설계 영향 |
|------|----------|
| SDK 세션 ≠ 우리 세션 (5분 vs 매 백그라운드) | **우리만의 세션 누적 카운터 + 백그라운드 전송 로직 필수** |
| SDK가 이미 `didEnterBackground` 감시 | 우리 옵저버와 충돌 없음 (각자 독립 동작) |
| Duration 추적 내장 (`@MainActor`) | **사용하지 않음** — 별도 시그널이 발생하여 세션 요약과 불일치. 자체 측정(`Date()` 차이)으로 통일 |
| `defaultParameters` 클로저 (매 전송 시 평가) | 사진 규모 구간을 넣되, **매번 PHAsset 조회하면 성능 문제** → 앱 실행 시 1회 계산 후 캐싱 |
| 파라미터 값 String만 가능 | 숫자→문자열 변환 필요 |
| 외부 의존성 0개 → 1개 추가 | Xcode 프로젝트에서만 의존 (AppCore 영향 없음) |

---

## 2. 래퍼 계층

### 2.1 설계 배경

| 항목 | 현황 |
|------|------|
| 아키텍처 | UIKit 기반 (`@main AppDelegate` + `SceneDelegate`) |
| 서비스 패턴 | `protocol XxxProtocol` + `final class Xxx: Singleton (.shared)` |
| 외부 의존성 | **0개** (AppCore는 순수 Apple 프레임워크만 사용) |
| 라이프사이클 훅 | `SceneDelegate`에 foreground/background 처리 존재 |
| 로그 시스템 | `Log.print("[Category] 메시지")` — 카테고리 기반 ON/OFF |

### 2.2 의존성 배치: 방안 C (프로토콜 분리) 확정

| | 방안 A: AppCore에 추가 | 방안 B: PickPhoto에만 추가 | **방안 C: 프로토콜 분리** |
|--|----------------------|-------------------------|---------------------|
| SDK 위치 | Package.swift → AppCore | Xcode → PickPhoto | Xcode → PickPhoto |
| 프로토콜 위치 | AppCore | PickPhoto | **AppCore** (경량, SDK 없음) |
| 구현체 위치 | AppCore | PickPhoto | **PickPhoto** |
| AppCore 외부 의존성 | **추가됨** | 없음 | **없음** |
| AppCore 내부 오류 추적 | 직접 호출 | 불가 | **가능** (프로토콜 경유) |

### 2.3 서비스 구조

```
┌─────────────────────────────────────────────┐
│  PickPhoto 코드 (VC, Feature 서비스)         │
│  AnalyticsService.shared.trackXxx()         │
│  AnalyticsService.shared.countXxx()         │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  AnalyticsService (Singleton, PickPhoto)     │
│  - sendEvent() → TD signal + Supabase send  │
│  - sendEventBatch() → TD signal + Sb batch  │
│  - 세션 누적 카운터 관리                      │
│  - 백그라운드 진입 시 요약 전송               │
│  - 소요시간은 자체 측정 (Date() 차이)         │
│  - 사진 규모 구간은 캐싱 (앱 실행 시 1회)     │
│                                             │
│  ┌─────────────────────────────────────┐    │
│  │ SupabaseProvider (옵셔널)           │    │
│  │ - URLSession 기반 HTTP POST         │    │
│  │ - 배치/단건 전송 + 오프라인 큐      │    │
│  │ - 선별적 재시도 (4xx 드롭)          │    │
│  │ - credentials 없으면 nil → 비활성   │    │
│  └─────────────────────────────────────┘    │
└─────────────────────────────────────────────┘
         │ (방안 C)
┌────────▼────────────────────────────────────┐
│  Analytics.reporter (AppCore, 옵셔널)        │
│  - AppCore 내부 오류 추적용 경량 프로토콜     │
│  - PickPhoto에서 앱 시작 시 주입             │
└─────────────────────────────────────────────┘
```

### 2.4 Dual Send 헬퍼

TelemetryDeck + Supabase 이중 전송을 위한 내부 헬퍼:

```swift
/// TD + Supabase 이중 전송 (즉시 전송형 이벤트용)
/// - TelemetryDeck: 항상 전송 (SDK가 "PickPhoto." prefix 자동 추가)
/// - Supabase: 전 이벤트 수집 (supabaseExcluded = 빈 Set)
func sendEvent(_ name: String, parameters: [String: String] = [:]) {
    TelemetryDeck.signal(name, parameters: parameters)
    guard !Self.supabaseExcluded.contains(name) else { return }
    let bucket = queue.sync { photoLibraryBucket }
    supabaseProvider?.send(eventName: name, params: parameters, photoBucket: bucket)
}

/// TD 개별 전송 + Supabase 배치 전송 (flushCounters용)
func sendEventBatch(_ events: [(name: String, parameters: [String: String])]) {
    // 1) TD 개별 전송
    for event in events { TelemetryDeck.signal(event.name, parameters: event.parameters) }
    // 2) Supabase 배치 전송 (제외 목록 필터링)
    // provider nil 시 onFlushComplete 직접 호출 (completion 누락 방지)
}
```

> **시그널 이름 규칙**: `sendEvent("app.launched")` → TD는 `"PickPhoto.app.launched"`로 전송, Supabase에는 `"app.launched"` 그대로 저장.

### 2.5 SupabaseProvider 클래스

```swift
/// Supabase PostgREST에 이벤트를 전송하는 경량 HTTP 클라이언트
/// - URLSession 기반 (외부 의존성 0)
/// - 오프라인 큐: Application Support/analytics/supabase_pending.json (최대 200건)
/// - 선별적 재시도: 네트워크 에러/429/5xx만 큐 저장, 4xx는 드롭
final class SupabaseProvider {
    struct EventPayload {
        let eventName: String
        let params: [String: String]
        let photoBucket: String
    }

    /// 구독 tier 제공 클로저 (lazy 평가 — makeBody 시점에 호출)
    private let subscriptionTierProvider: (() -> String)?

    /// IDFV (identifierForVendor) — 앱 시작 시 1회 캐싱
    /// - 유저 단위 퍼널 분석용 (게이트→구독 전환율, DAU 등)
    private let deviceID: String

    init?(baseURL: String, anonKey: String,
          subscriptionTierProvider: (() -> String)? = nil)  // URL이 잘못되면 nil

    func send(eventName:params:photoBucket:)           // 단건 즉시 전송 (실패 시 큐 저장)
    func sendBatch(events:completion:)                  // 배치 전송 + completion (실패 시 큐 저장)
    func flushPendingQueue()                            // 보류 큐 재전송 (포그라운드 진입 시)
}
```

**HTTP 요청 상세:**

```
POST {baseURL}/rest/v1/events
Headers:
  Content-Type: application/json
  apikey: {anonKey}                    ← API 게이트웨이 통과용
  Authorization: Bearer {anonKey}      ← PostgREST RLS 평가용 (같은 키)
  Prefer: return=minimal, missing=default  ← 응답 미반환 + 누락 컬럼 DB 기본값 적용

Body (배치): JSON 배열 (9개 키)
[
  {
    "event_name": "session.photoViewing",
    "params": {"total": "5", "fromLibrary": "3"},
    "device_model": "iPhone16,1",
    "os_version": "18.3",
    "app_version": "1.0.0",
    "photo_bucket": "1K-5K",
    "subscription_tier": "free",
    "device_id": "C8735166-FF88-467C-9945-58428C2919DD",
    "is_test": true
  },
  { ... }
]

Body (단건): 같은 형태의 단일 객체 (배열 아님)

응답:
  201 Created — 성공 (return=minimal이므로 body 비어있음)
  403 Forbidden — RLS 정책 위반 (화이트리스트에 없는 event_name)
  400 Bad Request — JSON 형식 오류 또는 키 불일치
```

**에러 처리 (선별적 재시도):**
- 성공 (2xx): 정상 완료
- 재시도 대상 (큐 저장): 네트워크 에러, 429 Rate Limit, 5xx 서버 오류
- 드롭 (재시도 안함): 4xx 클라이언트 오류 (400 RLS 위반, 403 권한 등 — 재시도해도 영구 실패)
- 큐 재전송: 포그라운드 진입 시 `flushPendingQueue()` 호출

### 2.6 설계 원칙

| 원칙 | 설명 |
|------|------|
| **Duration API 미사용** | SDK Duration API는 별도 시그널을 생성하여 세션 요약과 불일치. 모든 소요시간은 `Date()` 차이로 자체 측정 |
| **사진 규모 구간 캐싱** | `defaultParameters` 클로저 내에서 `PHAsset.fetchAssets()` 매번 호출 금지. 포그라운드 진입 시 1회 계산 후 캐싱 |
| **실행 횟수: SDK 값 활용** | SDK가 `totalSessionsCount`를 자동 수집하므로 별도 카운터 불필요 |
| **강제종료 시 데이터 유실 수용** | 크래시 시 `sceneDidEnterBackground` 미호출 → 세션 누적 데이터 유실. 세션 요약의 본질적 한계 |
| **Thread Safety** | concurrent queue + barrier write로 보호. 오류 카운팅 등 백그라운드 큐 호출 대비 |
| **파라미터 값은 enum 정의** | 문자열 파라미터는 enum으로 정의하여 오타/cardinality 폭증 방지 |
| **사용자 옵트아웃** | UserDefaults에 저장. 래퍼 레벨에서 `shouldSkip()` guard. SDK `analyticsDisabled`로 이중 차단 |

### 2.7 초기화 흐름

```
AppDelegate.didFinishLaunchingWithOptions
  └→ AnalyticsService.shared.configure(appID:)
       └→ TelemetryDeck.initialize(config:)
       └→ configureSupabase()  ← Info.plist에서 URL/Key 로드, 없으면 비활성
       └→ 사진 규모 구간 캐싱

SceneDelegate.sceneWillEnterForeground
  └→ AnalyticsService.shared.refreshPhotoLibraryBucket()
  └→ AnalyticsService.shared.trackAppLaunched()
  └→ AnalyticsService.shared.flushPendingSupabaseEvents()  ← 오프라인 큐 재전송

SceneDelegate.sceneDidEnterBackground
  └→ beginBackgroundTask (Supabase POST 완료 대기)
  └→ onFlushComplete 설정 (endTask 연결)
  └→ AnalyticsService.shared.handleSessionEnd()
       └→ flushCounters → sendEventBatch (TD + Supabase)
```

---

## 3. 세션 관리

### 3.1 세션 정의 (기술 관점)

| 항목 | 정의 | 구현 위치 |
|------|------|----------|
| **세션 시작** | `sceneWillEnterForeground` 호출 시점 | SceneDelegate |
| **세션 종료** | `sceneDidEnterBackground` 호출 시점 | SceneDelegate |
| **세션 요약 전송** | 종료 시 누적 카운터를 시그널로 변환 → 전송 → 리셋 | AnalyticsService |
| **미전송 조건** | 이벤트 그룹의 **모든 값이 0**이면 해당 그룹 시그널 스킵 | AnalyticsService |

### 3.2 누적 카운터 구조

```swift
/// 세션 동안 누적되는 모든 카운터
/// - 세션 종료 시 시그널로 변환 후 초기값으로 리셋
struct SessionCounters {

    // ── 이벤트 3: 사진 열람 ──
    struct PhotoViewing {
        var total: Int = 0
        var fromLibrary: Int = 0
        var fromAlbum: Int = 0
        var fromTrash: Int = 0
        var isZero: Bool { total == 0 }
    }

    // ── 이벤트 4-1: 보관함/앨범 삭제·복구 ──
    struct DeleteRestore {
        var gridSwipeDelete: Int = 0
        var gridSwipeRestore: Int = 0
        var viewerSwipeDelete: Int = 0
        var viewerTrashButton: Int = 0
        var viewerRestoreButton: Int = 0
        var fromLibrary: Int = 0
        var fromAlbum: Int = 0
        var isZero: Bool {
            gridSwipeDelete == 0 && gridSwipeRestore == 0
            && viewerSwipeDelete == 0 && viewerTrashButton == 0
            && viewerRestoreButton == 0
        }
    }

    // ── 이벤트 4-2: 삭제대기함 뷰어 행동 ──
    struct TrashViewer {
        var permanentDelete: Int = 0
        var restore: Int = 0
        var isZero: Bool { permanentDelete == 0 && restore == 0 }
    }

    // ── 이벤트 5-1: 유사 사진 분석 ──
    struct SimilarAnalysis {
        var completedCount: Int = 0
        var cancelledCount: Int = 0
        var totalGroups: Int = 0
        var totalDuration: TimeInterval = 0
        var isZero: Bool { completedCount == 0 && cancelledCount == 0 }
        var averageDuration: TimeInterval {
            completedCount > 0 ? totalDuration / Double(completedCount) : 0
        }
    }

    // ── 이벤트 6: 앱 오류 ──
    /// 키: "category.item" (예: "photoLoad.gridThumbnail"), 값: 발생 횟수
    var errors: [String: Int] = [:]

    // ── 이벤트 8: 그리드 성능 ──
    struct GridPerformance {
        var grayShown: Int = 0
        var isZero: Bool { grayShown == 0 }
    }

    var photoViewing = PhotoViewing()
    var deleteRestore = DeleteRestore()
    var trashViewer = TrashViewer()
    var similarAnalysis = SimilarAnalysis()
    var gridPerformance = GridPerformance()
}
```

**오류 키 규칙:**

| 카테고리 | 항목 | 키 |
|---------|------|-----|
| 사진 로딩 | 그리드 썸네일 | `photoLoad.gridThumbnail` |
| 사진 로딩 | 뷰어 원본 | `photoLoad.viewerOriginal` |
| 사진 로딩 | iCloud 다운로드 | `photoLoad.iCloudDownload` |
| 얼굴 감지 | 감지 실패 | `face.detection` |
| 얼굴 감지 | 임베딩 실패 | `face.embedding` |
| 정리 | 시작 불가 | `cleanup.startFail` |
| 정리 | 이미지 로드 | `cleanup.imageLoad` |
| 정리 | 삭제대기함 이동 | `cleanup.trashMove` |
| 동영상 | 프레임 추출 | `video.frameExtract` |
| 동영상 | iCloud 스킵 | `video.iCloudSkip` |
| 캐시/저장 | 디스크 부족 | `storage.diskSpace` |
| 캐시/저장 | 썸네일 캐시 | `storage.thumbnailCache` |
| 캐시/저장 | 삭제대기함 데이터 | `storage.trashData` |

### 3.3 스레드 안전성

```swift
final class AnalyticsService {
    /// 누적 카운터 보호용 concurrent queue
    /// - 읽기: queue.sync { ... }       (동시 허용)
    /// - 쓰기: queue.async(flags: .barrier) { ... } (독점)
    let queue = DispatchQueue(label: "com.pickphoto.analytics", attributes: .concurrent)
    var counters = SessionCounters()
}
```

**호출 패턴:**

```swift
// ── 카운터 증가 (비동기 barrier write) ──
func countPhotoViewed(from source: ScreenSource) {
    queue.async(flags: .barrier) {
        self.counters.photoViewing.total += 1
        switch source {
        case .library: self.counters.photoViewing.fromLibrary += 1
        case .album:   self.counters.photoViewing.fromAlbum += 1
        case .trash:   self.counters.photoViewing.fromTrash += 1
        }
    }
}

// ── 플러시 (동기 barrier — 스냅샷 + 리셋 원자적 수행) ──
func handleSessionEnd() {
    guard !shouldSkip() else {
        // shouldSkip이어도 onFlushComplete 호출 (SceneDelegate의 endBackgroundTask 해제)
        onFlushComplete?()
        onFlushComplete = nil
        return
    }
    let snapshot = queue.sync(flags: .barrier) { () -> SessionCounters in
        let current = self.counters
        self.counters = SessionCounters()
        return current
    }
    flushCounters(snapshot)
}
```

> **왜 `barrier sync`인가?**
> 진행 중인 모든 barrier write가 완료될 때까지 대기한 후, 스냅샷을 찍고 리셋한다. 메인 스레드를 잠시 블로킹하지만, 정수 복사+리셋이므로 마이크로초 수준.

### 3.4 플러시 로직

```swift
private func flushCounters(_ c: SessionCounters) {
    var events: [(name: String, parameters: [String: String])] = []

    if !c.photoViewing.isZero {
        events.append(("session.photoViewing", [
            "total":       String(c.photoViewing.total),
            "fromLibrary": String(c.photoViewing.fromLibrary),
            "fromAlbum":   String(c.photoViewing.fromAlbum),
            "fromTrash":   String(c.photoViewing.fromTrash),
        ]))
    }

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

    if !c.trashViewer.isZero {
        events.append(("session.trashViewer", [
            "permanentDelete": String(c.trashViewer.permanentDelete),
            "restore":         String(c.trashViewer.restore),
        ]))
    }

    if !c.similarAnalysis.isZero {
        events.append(("session.similarAnalysis", [
            "completedCount":  String(c.similarAnalysis.completedCount),
            "cancelledCount":  String(c.similarAnalysis.cancelledCount),
            "totalGroups":     String(c.similarAnalysis.totalGroups),
            "avgDurationSec":  String(format: "%.1f", c.similarAnalysis.averageDuration),
        ]))
    }

    if !c.errors.isEmpty {
        let params = c.errors.compactMapValues { $0 > 0 ? String($0) : nil }
        if !params.isEmpty {
            events.append(("session.errors", params))
        }
    }

    if !c.gridPerformance.isZero {
        events.append(("session.gridPerformance", [
            "grayShown": String(c.gridPerformance.grayShown),
        ]))
    }

    guard !events.isEmpty else {
        onFlushComplete?()
        onFlushComplete = nil
        return
    }
    sendEventBatch(events)
}
```

### 3.5 백그라운드 플러시 안전성

`handleSessionEnd()` → `flushCounters()` → `sendEventBatch()` 경로는 앱 백그라운드 진입 시 호출됨.
iOS가 ~5초 내에 앱을 suspend할 수 있으므로:

1. `sendBatch()`로 **1회 POST**에 모든 세션 이벤트 전송 (개별 POST 아닌 배치)
2. SceneDelegate에서 `beginBackgroundTask` 래핑:

```swift
func sceneDidEnterBackground(_ scene: UIScene) {
    AppStateStore.shared.handleBackgroundTransition()

    var bgTaskID: UIBackgroundTaskIdentifier = .invalid

    // 스레드 안전한 종료 헬퍼 (만료 핸들러와 completion 동시 호출 경합 방지)
    let endTask = {
        DispatchQueue.main.async {
            guard bgTaskID != .invalid else { return }  // 이미 종료됨
            UIApplication.shared.endBackgroundTask(bgTaskID)
            bgTaskID = .invalid
        }
    }

    bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "AnalyticsFlush") {
        endTask()  // 만료 핸들러: 시간 초과 시 즉시 종료
    }

    // ⚠️ onFlushComplete는 handleSessionEnd 전에 설정 (동기 경로에서 nil 호출 방지)
    AnalyticsService.shared.onFlushComplete = { endTask() }
    AnalyticsService.shared.handleSessionEnd()
}
```

**`onFlushComplete` 콜백 흐름:**
- 정상 경로: `handleSessionEnd()` → `flushCounters()` → `sendEventBatch()` → Supabase `sendBatch(completion:)` → `onFlushComplete()` → `endTask()`
- shouldSkip 경로: `handleSessionEnd()` → `shouldSkip() == true` → `onFlushComplete()` → `endTask()`
- 이벤트 없음: `flushCounters()` → `events.isEmpty` → `onFlushComplete()` → `endTask()`
- provider nil: `sendEventBatch()` → `provider == nil` → `onFlushComplete()` → `endTask()`

### 3.6 진입 경로 추적 (이벤트 4-1)

```swift
// 호출 예: GridViewController(보관함)에서 스와이프 삭제
AnalyticsService.shared.countGridSwipeDelete(source: .library)

// 내부 구현 — DeleteSource enum (2개 case: .library, .album)
func countGridSwipeDelete(source: DeleteSource) {
    queue.async(flags: .barrier) {
        self.counters.deleteRestore.gridSwipeDelete += 1
        switch source {
        case .library: self.counters.deleteRestore.fromLibrary += 1
        case .album:   self.counters.deleteRestore.fromAlbum += 1
        }
    }
}
```

> `DeleteSource`(2 case)와 `ScreenSource`(3 case)를 분리한 이유: 삭제·복구 switch에서 `.trash`가 불필요한데, Swift 컴파일러가 exhaustive check를 요구하므로 타입 레벨에서 방지.

### 3.7 데이터 흐름도

```
사용자 행동
    │
    ▼
AnalyticsService.countXxx()
    │ queue.async(flags: .barrier)
    ▼
SessionCounters 누적
    │
    │ ← sceneDidEnterBackground 발생
    ▼
handleSessionEnd()
    │ queue.sync(flags: .barrier)
    ├─ 스냅샷 복사
    ├─ 카운터 리셋
    ▼
flushCounters(snapshot)
    │ 그룹별 isZero 확인
    ▼
sendEventBatch(events)
    ├─ TD: 개별 signal (SDK 내부 배치 큐 10초)
    └─ Supabase: 1회 배치 POST (completion → endTask)
```

---

## 4. 이벤트 수집기

### 4.1 시그널 이름 총괄표

| # | 이벤트 | 시그널 이름 | 전송 방식 | 파라미터 수 |
|---|--------|-----------|----------|-----------|
| 1 | 앱 실행 | `app.launched` | 즉시 | 0 (자동 첨부) |
| 2 | 사진 접근 권한 | `permission.result` | 즉시 | 2 |
| 3 | 사진 열람 | `session.photoViewing` | 세션 요약 | 4 |
| 4-1 | 삭제·복구 | `session.deleteRestore` | 세션 요약 | 7 |
| 4-2 | 삭제대기함 뷰어 | `session.trashViewer` | 세션 요약 | 2 |
| 5-1 | 유사 분석 | `session.similarAnalysis` | 세션 요약 | 4 |
| 5-2 | 유사 그룹 행동 | `similar.groupClosed` | 즉시 (그룹별) | 2 |
| 6 | 앱 오류 | `session.errors` | 세션 요약 | 0~13 |
| 7-1 | 기존 정리 | `cleanup.completed` | 즉시 (종료 시) | 8 |
| 7-2 | 미리보기 정리 | `cleanup.previewCompleted` | 즉시 (종료 시) | 9 |
| 8 | 그리드 성능 | `session.gridPerformance` | 세션 요약 | 1 |
| **BM 수익화 이벤트** | | | | |
| 12 | 게이트 노출 | `bm.gateShown` | 즉시 | 2 |
| 13 | 게이트 선택 | `bm.gateSelection` | 즉시 | 1 |
| 14 | 광고 시청 | `bm.adWatched` | 즉시 | 2 |
| 15 | 페이월 노출 | `bm.paywallShown` | 즉시 | 1 |
| 16 | 구독 완료 | `bm.subscriptionCompleted` | 즉시 | 1 |
| 17 | 삭제 완료 | `bm.deletionCompleted` | 즉시 | 1 |
| 18 | Grace Period 종료 | `bm.gracePeriodEnded` | 즉시 | 0 |
| 19 | ATT 결과 | `bm.attResult` | 즉시 | 1 |
| 20 | 해지 사유 | `bm.cancelReason` | 즉시 | 1~2 |

> `defaultSignalPrefix`를 `"PickPhoto."`로 설정했으므로 실제 전송 이름은 `PickPhoto.app.launched` 등.

### 4.2 공통 Enum 정의

```swift
// ── 화면 소스 (사진 열람: 이벤트 3) ──
enum ScreenSource: String {
    case library = "library"
    case album   = "album"
    case trash   = "trash"
}

// ── 삭제·복구 진입 경로 (이벤트 4-1) ──
enum DeleteSource: String {
    case library = "library"
    case album   = "album"
    // 삭제대기함은 이벤트 4-2로 별도 추적 → .trash 불필요
}

// ── 권한 결과 / 시점 ──
enum PermissionResultType: String {
    case fullAccess    = "fullAccess"
    case limitedAccess = "limitedAccess"
    case denied        = "denied"
}
enum PermissionTiming: String {
    case firstRequest   = "firstRequest"
    case settingsChange = "settingsChange"
}

// ── 오류 카테고리.항목 (enum화) ──
enum AnalyticsError {
    enum PhotoLoad: String {
        case gridThumbnail  = "photoLoad.gridThumbnail"
        case viewerOriginal = "photoLoad.viewerOriginal"
        case iCloudDownload = "photoLoad.iCloudDownload"
    }
    enum Face: String {
        case detection = "face.detection"
        case embedding = "face.embedding"
    }
    enum Cleanup: String {
        case startFail  = "cleanup.startFail"
        case imageLoad  = "cleanup.imageLoad"
        case trashMove  = "cleanup.trashMove"
    }
    enum Video: String {
        case frameExtract = "video.frameExtract"
        case iCloudSkip   = "video.iCloudSkip"
    }
    enum Storage: String {
        case diskSpace      = "storage.diskSpace"
        case thumbnailCache = "storage.thumbnailCache"
        case trashData      = "storage.trashData"
    }
}

// ── BM 수익화 enum ──
enum GateChoice: String {
    case ad      = "ad"       // 광고 시청
    case plus    = "plus"     // Plus 업그레이드
    case dismiss = "dismiss"  // 닫기
}
enum AdType: String {
    case rewarded     = "rewarded"      // 리워드 광고
    case interstitial = "interstitial"  // 전면 광고
    case banner       = "banner"        // 배너 광고
}
enum PaywallSource: String {
    case gate   = "gate"    // 게이트 팝업에서 Plus 선택
    case menu   = "menu"    // 프리미엄 메뉴에서 구독 관리
    case banner = "banner"  // Grace Period 배너 탭
    case gauge  = "gauge"   // 게이지 상세 팝업
}
enum CancelReason: String {
    case price       = "price"        // 가격이 부담돼요
    case enoughFree  = "enough_free"  // 삭제 한도가 충분해요
    case done        = "done"         // 사진 정리를 다 했어요
    case competitor  = "competitor"   // 다른 앱을 사용해요
    case other       = "other"        // 기타
}

// ── 정리 관련 enum (이벤트 7-1) ──
enum CleanupReachedStage: String {
    case buttonTapped, trashWarningExit, methodSelected, cleanupDone, resultAction
}
enum CleanupMethodType: String {
    case fromLatest, continueFromLast, byYear
}
enum AnalyticsCleanupResult: String {
    case completed, noneFound, cancelled
}
enum CleanupResultAction: String {
    case confirm, viewTrash
}

// ── 미리보기 관련 enum (이벤트 7-2) ──
enum PreviewReachedStage: String {
    case analyzed, gridShown, finalAction
}
enum PreviewFinalAction: String {
    case moveToTrash, close
}
enum PreviewMaxStage: String {
    case light, standard, deep
}
```

### 4.3 즉시 전송형 이벤트

```swift
// 이벤트 1: 앱 실행
func trackAppLaunched() {
    sendEvent("app.launched")
}

// 이벤트 2: 사진 접근 권한
func trackPermissionResult(result: PermissionResultType, timing: PermissionTiming) {
    sendEvent("permission.result", parameters: [
        "result": result.rawValue,
        "timing": timing.rawValue,
    ])
}

// 이벤트 5-2: 유사 사진 그룹 행동
func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int) {
    sendEvent("similar.groupClosed", parameters: [
        "totalCount":   String(totalCount),
        "deletedCount": String(deletedCount),
    ])
}

// ── BM 수익화 이벤트 (AnalyticsService+Monetization.swift) ──

// 이벤트 12: 게이트 노출
func trackGateShown(trashCount: Int, remainingLimit: Int)

// 이벤트 13: 게이트 선택
func trackGateSelection(choice: GateChoice)

// 이벤트 14: 광고 시청 (리워드/전면/배너)
func trackAdWatched(type: AdType, source: String)

// 이벤트 15: 페이월 노출
func trackPaywallShown(source: PaywallSource)

// 이벤트 16: 구독 완료
func trackSubscriptionCompleted(productID: String)

// 이벤트 17: 삭제 완료
func trackDeletionCompleted(count: Int)

// 이벤트 18: Grace Period 종료
func trackGracePeriodEnded()

// 이벤트 19: ATT 결과
func trackATTResult(authorized: Bool)

// 이벤트 20: 해지 사유 (Exit Survey)
func trackCancelReason(reason: CancelReason, text: String? = nil)
```

### 4.4 세션 요약형 이벤트 — 카운터 증가 메서드

```swift
// 이벤트 3
func countPhotoViewed(from source: ScreenSource)

// 이벤트 4-1 (source로 진입 경로 동시 추적)
func countGridSwipeDelete(source: DeleteSource)
func countGridSwipeRestore(source: DeleteSource)
func countViewerSwipeDelete(source: DeleteSource?)
func countViewerTrashButton(source: DeleteSource?)
func countViewerRestoreButton(source: DeleteSource?)

// 이벤트 4-2
func countTrashPermanentDelete()
func countTrashRestore()

// 이벤트 5-1
func countSimilarAnalysisCompleted(groups: Int, duration: TimeInterval)
func countSimilarAnalysisCancelled()

// 이벤트 6 (카테고리별 오버로드)
func countError(_ error: AnalyticsError.PhotoLoad)
func countError(_ error: AnalyticsError.Face)
func countError(_ error: AnalyticsError.Cleanup)
func countError(_ error: AnalyticsError.Video)
func countError(_ error: AnalyticsError.Storage)

// 이벤트 8
func countGrayShown()
```

### 4.5 정리 이벤트 데이터 모델

#### 이벤트 7-1: 기존 정리 — CleanupEventData

```swift
struct CleanupEventData {
    let reachedStage: CleanupReachedStage
    let trashWarningShown: Bool
    let method: CleanupMethodType?
    let result: AnalyticsCleanupResult?
    let foundCount: Int
    let durationSec: Double
    let cancelProgress: Float?
    let resultAction: CleanupResultAction?
}
```

#### 이벤트 7-2: 미리보기 정리 — PreviewCleanupEventData

```swift
struct PreviewCleanupEventData {
    let reachedStage: PreviewReachedStage
    let foundCount: Int
    let durationSec: Double
    let maxStageReached: PreviewMaxStage
    let expandCount: Int
    let excludeCount: Int
    let viewerOpenCount: Int
    let finalAction: PreviewFinalAction
    let movedCount: Int
}
```

### 4.6 프로토콜 최종 확정

```swift
protocol AnalyticsServiceProtocol: AnyObject {
    // 즉시 전송형
    func trackAppLaunched()
    func trackPermissionResult(result: PermissionResultType, timing: PermissionTiming)

    // 세션 누적형
    func countPhotoViewed(from source: ScreenSource)
    func countGridSwipeDelete(source: DeleteSource)
    func countGridSwipeRestore(source: DeleteSource)
    func countViewerSwipeDelete(source: DeleteSource?)
    func countViewerTrashButton(source: DeleteSource?)
    func countViewerRestoreButton(source: DeleteSource?)
    func countTrashPermanentDelete()
    func countTrashRestore()
    func countSimilarAnalysisCompleted(groups: Int, duration: TimeInterval)
    func countSimilarAnalysisCancelled()
    func countError(_ error: AnalyticsError.PhotoLoad)
    func countError(_ error: AnalyticsError.Face)
    func countError(_ error: AnalyticsError.Cleanup)
    func countError(_ error: AnalyticsError.Video)
    func countError(_ error: AnalyticsError.Storage)
    func countGrayShown()

    // 그룹별 즉시 전송
    func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int)

    // 정리 기능
    func trackCleanupCompleted(data: CleanupEventData)
    func trackPreviewCleanupCompleted(data: PreviewCleanupEventData)

    // 라이프사이클
    func handleSessionEnd()
}
```

### 4.7 AppCore용 경량 프로토콜 (방안 C)

```swift
// ── AppCore/Services/AnalyticsReporting.swift ──

public protocol AnalyticsReporting: AnyObject {
    func reportError(key: String)
}

public enum Analytics {
    public static weak var reporter: AnalyticsReporting?
}
```

AppCore 내부 호출: `Analytics.reporter?.reportError(key: "photoLoad.gridThumbnail")`
PickPhoto에서 브릿지: `extension AnalyticsService: AnalyticsReporting { ... }`

---

## 5. Supabase 인프라

### 5.1 테이블 스키마

```sql
CREATE TABLE events (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    event_name TEXT NOT NULL,
    params JSONB NOT NULL DEFAULT '{}',
    device_model TEXT,
    os_version TEXT,
    app_version TEXT,
    photo_bucket TEXT,
    subscription_tier TEXT,              -- "free" 또는 "plus" (BM 추가)
    device_id TEXT,                      -- IDFV UUID (유저 단위 분석용)
    is_test BOOLEAN NOT NULL DEFAULT true,
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_events_name ON events(event_name);
CREATE INDEX idx_events_created ON events(created_at);
CREATE INDEX idx_events_name_created ON events(event_name, created_at);
CREATE INDEX idx_events_tier ON events(subscription_tier);
CREATE INDEX idx_events_device_id ON events(device_id);
```

### 5.2 RLS 정책

```sql
ALTER TABLE events ENABLE ROW LEVEL SECURITY;
DROP POLICY IF EXISTS "anon_insert" ON events;
CREATE POLICY "anon_insert" ON events FOR INSERT TO anon
    WITH CHECK (
        event_name IN (
            -- 기존 11종
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
            'session.gridPerformance',
            -- BM 9종
            'bm.gateShown',
            'bm.gateSelection',
            'bm.adWatched',
            'bm.paywallShown',
            'bm.subscriptionCompleted',
            'bm.deletionCompleted',
            'bm.gracePeriodEnded',
            'bm.attResult',
            'bm.cancelReason'
        )
    );

```

> INSERT만 허용, SELECT/UPDATE/DELETE 정책 없음. 이벤트명 화이트리스트(20종)로 무단 INSERT 방지.
> 조회는 service_role key(RLS 우회)로만 가능. anon key로는 INSERT만 허용.

### 5.3 RPC 함수

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

-- 게이트 퍼널 일별 요약 (BM)
CREATE OR REPLACE FUNCTION gate_funnel_summary(p_days INT DEFAULT 30)
RETURNS TABLE(day DATE, event_name TEXT, choice TEXT, cnt BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT created_at::date AS day, event_name,
           params->>'choice' AS choice, count(*) AS cnt
    FROM events
    WHERE event_name IN ('bm.gateShown', 'bm.gateSelection')
      AND created_at >= now() - (p_days || ' days')::interval
      AND is_test = false
    GROUP BY day, event_name, choice
    ORDER BY day DESC, event_name, cnt DESC;
$$;

-- tier별 이벤트 요약 (BM)
CREATE OR REPLACE FUNCTION tier_summary(p_days INT DEFAULT 30)
RETURNS TABLE(tier TEXT, event_name TEXT, cnt BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT COALESCE(subscription_tier, 'unknown') AS tier,
           event_name, count(*) AS cnt
    FROM events
    WHERE created_at >= now() - (p_days || ' days')::interval
      AND is_test = false
    GROUP BY tier, event_name
    ORDER BY tier, cnt DESC;
$$;

-- 유저 단위 게이트→구독 전환율 (device_id 기반)
CREATE OR REPLACE FUNCTION gate_conversion_rate(p_days INT DEFAULT 90)
RETURNS TABLE(gate_users BIGINT, subscribed_users BIGINT, conversion_pct NUMERIC)
LANGUAGE sql STABLE AS $$
    WITH gate_users AS (
        SELECT DISTINCT device_id FROM events
        WHERE event_name = 'bm.gateShown'
          AND device_id IS NOT NULL AND device_id != 'unknown'
          AND created_at >= now() - (p_days || ' days')::interval
          AND is_test = false
    ),
    sub_users AS (
        SELECT DISTINCT device_id FROM events
        WHERE event_name = 'bm.subscriptionCompleted'
          AND device_id IS NOT NULL AND device_id != 'unknown'
          AND created_at >= now() - (p_days || ' days')::interval
          AND is_test = false
    )
    SELECT
        (SELECT count(*) FROM gate_users) AS gate_users,
        (SELECT count(*) FROM sub_users WHERE device_id IN (SELECT device_id FROM gate_users)) AS subscribed_users,
        ROUND(
            (SELECT count(*) FROM sub_users WHERE device_id IN (SELECT device_id FROM gate_users))::numeric
            / NULLIF((SELECT count(*) FROM gate_users), 0) * 100, 1
        ) AS conversion_pct;
$$;

-- DAU (일별 고유 device_id 수)
CREATE OR REPLACE FUNCTION daily_active_users(p_days INT DEFAULT 30)
RETURNS TABLE(day DATE, dau BIGINT)
LANGUAGE sql STABLE AS $$
    SELECT created_at::date AS day,
           count(DISTINCT device_id) AS dau
    FROM events
    WHERE device_id IS NOT NULL AND device_id != 'unknown'
      AND created_at >= now() - (p_days || ' days')::interval
      AND is_test = false
    GROUP BY day
    ORDER BY day DESC;
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

### 5.4 pg_cron 90일 자동 삭제

> **초기에는 불필요**: DAU 10명 기준 월 2,700행 → 300MB까지 수년 소요.
> DAU 1,000명 이상으로 늘어난 뒤 설정해도 충분함.

설정 방법: Database > Extensions > pg_cron 활성화 후:

```sql
SELECT cron.schedule(
    'purge-old-events',
    '0 3 * * 0',  -- 매주 일요일 03:00 UTC
    $$SELECT purge_old_events(90)$$
);
```

> **주의**: Supabase 무료 티어는 일정 기간 비활성 시 프로젝트 자동 일시정지. pause 중에는 pg_cron 등 모든 백그라운드 작업도 중단됨. Dashboard에서 수동 Resume 필요.

### 5.5 Credentials 전달

**xcconfig → Info.plist 경로:**

`PickPhoto/PickPhoto/Config/Supabase.xcconfig` (git-ignored):
```xcconfig
// ⚠️ //가 xcconfig에서 주석으로 해석되므로 이스케이프 필수
SUPABASE_URL = https:/$()/xxx.supabase.co
SUPABASE_ANON_KEY = sb_publishable_xxx
```

Info.plist에서 참조:
```xml
<key>SUPABASE_URL</key>
<string>$(SUPABASE_URL)</string>
<key>SUPABASE_ANON_KEY</key>
<string>$(SUPABASE_ANON_KEY)</string>
```

**Xcode 프로젝트 설정:**
- Project > Info > Configurations에서 Debug/Release 모두 `Supabase.xcconfig` 지정

**보안:**
- anon key는 JWT 기반 클라이언트용 키. 노출되어도 RLS가 INSERT만 허용
- service_role key는 RLS 우회 — 스크립트 전용 (`.env`에만 보관). 절대 앱 코드에 포함 금지

**Supabase UI 키 명칭:**
| 코드/문서 명칭 | Supabase Dashboard 명칭 |
|--------------|----------------------|
| anon key | Publishable Key |
| service_role key | Secret Key |

### 5.6 photo_bucket 처리

현재 코드의 `bucketString(for:)` 반환값을 그대로 TEXT 컬럼에 저장.
별도 매핑 함수 불필요 — 기존 `photoLibraryBucket` 문자열을 그대로 전달.

실제 반환값 (AnalyticsService.swift):
`"0"`, `"1-100"`, `"101-500"`, `"501-1K"`, `"1K-5K"`, `"5K-10K"`, `"10K-50K"`, `"50K-100K"`, `"100K+"` (9단계)

---

## 6. 파일 구조

### 6.1 파일 배치도

```
Sources/AppCore/Services/
└── AnalyticsReporting.swift              ← 경량 프로토콜 + Analytics.reporter

PickPhoto/PickPhoto/Shared/Analytics/
├── AnalyticsService.swift                ← 본체: 싱글톤, configure, queue, counters
│                                            + supabaseProvider, sendEvent, sendEventBatch
│                                            + configureSupabase, onFlushComplete
├── SupabaseProvider.swift                ← Supabase HTTP POST (배치 전송)
├── AnalyticsService+Session.swift        ← SessionCounters, handleSessionEnd, flush
├── AnalyticsService+Lifecycle.swift      ← trackAppLaunched, trackPermission
├── AnalyticsService+Viewing.swift        ← countPhotoViewed
├── AnalyticsService+DeleteRestore.swift  ← countGridSwipeDelete 등 + trashViewer
├── AnalyticsService+Similar.swift        ← countSimilarAnalysis, trackGroupClosed
├── AnalyticsService+Cleanup.swift        ← trackCleanupCompleted, trackPreviewCompleted
├── AnalyticsService+Errors.swift         ← countError 오버로드 5개 + AnalyticsReporting 브릿지
├── AnalyticsService+Monetization.swift   ← BM 수익화 이벤트 9종 + enum 4개
├── Models/
│   ├── AnalyticsEnums.swift              ← ScreenSource, PermissionResultType 등
│   ├── AnalyticsError.swift              ← AnalyticsError 중첩 enum (13항목)
│   ├── CleanupEventData.swift            ← CleanupEventData + 관련 enum
│   └── PreviewCleanupEventData.swift     ← PreviewCleanupEventData + 관련 enum

PickPhoto/PickPhoto/Config/
└── Supabase.xcconfig                     ← Credentials (git-ignored)

scripts/analytics/
├── .env                                  ← TD + Supabase credentials (git-ignored)
├── .env.example                          ← 템플릿 (git 추적)
├── td-auth.sh                            ← TD 토큰 발급 + 캐싱
├── td-query.sh                           ← TD 비동기 3단계 쿼리
├── td-report.sh                          ← TD 주간 리포트
├── sb-query.sh                           ← Supabase PostgREST 조회 + RPC
├── sb-report.sh                          ← Supabase 리포트
└── queries/                              ← TD TQL 쿼리 템플릿 10개
```

### 6.2 각 파일 책임

#### AppCore (1개)

| 파일 | 내용 | 줄 수 |
|------|------|-------|
| `AnalyticsReporting.swift` | `AnalyticsReporting` 프로토콜 + `Analytics` enum | ~20줄 |

#### PickPhoto — 서비스 (2개)

| 파일 | 내용 | 줄 수 |
|------|------|-------|
| `AnalyticsService.swift` | 싱글톤, configure, queue, sendEvent/sendEventBatch, supabaseProvider, onFlushComplete | ~170줄 |
| `SupabaseProvider.swift` | URLSession HTTP POST, 배치/단건 전송, 오프라인 큐, 선별적 재시도 | ~305줄 |

#### PickPhoto — Extension (7개)

| 파일 | 담당 이벤트 | 줄 수 |
|------|-----------|-------|
| `+Session.swift` | SessionCounters, handleSessionEnd, flushCounters | ~150줄 |
| `+Lifecycle.swift` | 1, 2 (앱 실행, 권한) | ~30줄 |
| `+Viewing.swift` | 3 (사진 열람) | ~25줄 |
| `+DeleteRestore.swift` | 4-1, 4-2 (삭제·복구, 삭제대기함) | ~70줄 |
| `+Similar.swift` | 5-1, 5-2 (유사 분석, 그룹 행동) | ~40줄 |
| `+Cleanup.swift` | 7-1, 7-2 (정리, 미리보기 정리) | ~60줄 |
| `+Errors.swift` | 6 (오류) + AnalyticsReporting 브릿지 | ~50줄 |
| `+Monetization.swift` | 12~20 (BM 수익화 9종) + enum 4개 | ~150줄 |

#### PickPhoto — Models (4개)

| 파일 | 내용 | 줄 수 |
|------|------|-------|
| `AnalyticsEnums.swift` | ScreenSource, DeleteSource, PermissionResultType, PermissionTiming | ~30줄 |
| `AnalyticsError.swift` | AnalyticsError 중첩 enum (5카테고리 13항목) | ~40줄 |
| `CleanupEventData.swift` | CleanupEventData + 관련 enum | ~50줄 |
| `PreviewCleanupEventData.swift` | PreviewCleanupEventData + 관련 enum | ~40줄 |

### 6.3 의존성 그래프

```
                    ┌──────────────────┐
                    │    AppCore       │
                    │                  │
                    │  AnalyticsRe-    │
                    │  porting.swift   │  ← SDK 의존성 없음
                    │  (protocol +     │
                    │   Analytics      │
                    │   .reporter)     │
                    └───────▲──────────┘
                            │ 주입
    ┌───────────────────────┼────────────────────────────┐
    │                 PickPhoto                           │
    │                                                    │
    │  AnalyticsService.swift (본체)                      │
    │       │                                            │
    │       ├── SupabaseProvider.swift                    │
    │       ├── +Session.swift                            │
    │       ├── +Lifecycle.swift                          │
    │       ├── +Viewing.swift                            │
    │       ├── +DeleteRestore.swift                      │
    │       ├── +Similar.swift                            │
    │       ├── +Cleanup.swift                            │
    │       ├── +Errors.swift ─── AnalyticsReporting 채택 │
    │       └── +Monetization.swift ── BM 수익화 9종     │
    │                                                    │
    │  Models/                                           │
    │       ├── AnalyticsEnums.swift                      │
    │       ├── AnalyticsError.swift                      │
    │       ├── CleanupEventData.swift                    │
    │       └── PreviewCleanupEventData.swift             │
    │                                                    │
    │       ↓ 호출                                       │
    │  TelemetryDeck SDK + SupabaseProvider              │
    └────────────────────────────────────────────────────┘
```

### 6.4 확장 패턴 — 새 이벤트 그룹 추가

```
1. Models/ 에 데이터 모델 파일 추가
2. Extension 파일 추가 (+Business.swift 등)
3. (세션 누적형이면) SessionCounters에 그룹 추가 + flushCounters에 전송 로직 추가
4. AnalyticsServiceProtocol에 메서드 추가
5. 호출 지점에서 메서드 호출
```

| 추가 유형 | 새 파일 | 수정 파일 |
|----------|--------|----------|
| 즉시 전송만 | Model + Extension (2개) | Protocol (1개) |
| 세션 누적 포함 | Model + Extension (2개) | Protocol + Session (2개) |

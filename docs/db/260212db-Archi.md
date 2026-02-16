# Analytics 구현 아키텍처 설계

> **작성일:** 2026-02-12
> **상태:** 설계 완료
> **기반 문서:** 260212db-Spec.md (이벤트·솔루션·비용 확정)
> **목적:** TelemetryDeck SDK 통합을 위한 구현 아키텍처 설계

---

## 목차

1. [설계 계획](#1-설계-계획)
2. [TelemetryDeck SDK API 파악](#2-telemetrydeck-sdk-api-파악)
3. [래퍼 계층 설계](#3-래퍼-계층-설계)
4. [세션 관리 설계](#4-세션-관리-설계)
5. [이벤트 수집기 설계](#5-이벤트-수집기-설계)
6. [파일 구조](#6-파일-구조)
7. [데이터 접근 경로](#7-데이터-접근-경로)

---

## 1. 설계 계획

| 단계 | 내용 | 산출물 | 상태 |
|------|------|--------|------|
| **1** | TelemetryDeck SDK API 파악 | SDK 기능/제약 정리 | **완료** |
| **2** | 래퍼 계층 설계 | 프로토콜 + 구현 클래스 구조 | **완료** |
| **3** | 세션 관리 설계 | SessionManager 구조 | **완료** |
| **4** | 이벤트 수집기 설계 | 7개 이벤트 데이터 모델 | **완료** |
| **5** | 파일 구조 결정 | 폴더/파일 배치도 | **완료** |
| **6** | 데이터 접근 경로 | Query API 활용 설계 | **완료** |

**설계 원칙:**
- 각 단계별로 주인님과 확인 후 다음 단계 진행
- TelemetryDeck 종속성을 래퍼로 격리 (향후 교체 대비)
- 세션 요약형 / 즉시 전송형 이벤트 구분 처리

---

## 2. TelemetryDeck SDK API 파악

> **상태: 완료**

### 2.1 기본 정보

| 항목 | 값 |
|------|-----|
| SPM URL | `https://github.com/TelemetryDeck/SwiftSDK` |
| 최신 버전 | 2.11.0 (2025-12) |
| 최소 iOS | 12.0 (우리 앱 iOS 16+ → 호환) |
| Swift Tools | 5.9 |
| Privacy Manifest | 내장 (`PrivacyInfo.xcprivacy`) |

### 2.2 핵심 API

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

### 2.3 세션 관리 — SDK 자동 처리

| 항목 | SDK 동작 |
|------|---------|
| 세션 ID 생성 | **백그라운드 5분 이상 경과 후** 포그라운드 복귀 시 자동 갱신 |
| 세션 시작 시그널 | `TelemetryDeck.Session.started` 자동 전송 (config `sendNewSessionBeganSignal`) |
| 최초 설치 감지 | `TelemetryDeck.Acquisition.newInstallDetected` 자동 전송 (1회) |
| 백그라운드 처리 | `didEnterBackgroundNotification` → 전송 타이머 중지 + 캐시 디스크 백업 (Background Task 사용) |
| 포그라운드 복귀 | `willEnterForegroundNotification` → 디스크 캐시 복원 + 전송 타이머 재시작 |
| 배치 전송 | `DispatchSource` 타이머, 10초 간격, 1회 최대 100건, 오프라인 큐 + 재시도 내장 *(v2.11.0 기준, SDK 업데이트 시 변경 가능)* |

> **중요:** SDK의 세션(5분 타임아웃)과 우리의 세션(매 백그라운드 진입)은 **정의가 다르다.**
> SDK 세션은 리텐션/코호트용이고, 우리의 세션 요약은 별도로 관리해야 한다.

### 2.4 Config 주요 옵션

| 옵션 | 타입 | 기본값 | 우리 활용 |
|------|------|--------|----------|
| `defaultParameters` | `@Sendable () -> [String: String]` | `{ [:] }` | 사진 규모 구간 자동 첨부 |
| `sendNewSessionBeganSignal` | `Bool` | `true` | 기본 유지 |
| `salt` | `String` (let, init시 설정) | `""` | 선택적 추가 |
| `defaultSignalPrefix` | `String?` | `nil` | `"PickPhoto."` 검토 |
| `analyticsDisabled` | `Bool` | `false` | 사용자 옵트아웃 시 활용 |
| `testMode` | `Bool` | DEBUG면 `true` | 자동 처리됨 |
| `metadataEnrichers` | `[SignalEnricher]` | `[]` | 커스텀 메타데이터 확장 가능 |
| `sessionStatsEnabled` | `Bool` | `true` | 리텐션 자동 추적 |

### 2.5 SDK 자동 수집 메타데이터 (코딩 불필요)

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

### 2.6 Duration / Navigation API 상세

```swift
// Duration — @MainActor, 백그라운드 시간 자동 제외
TelemetryDeck.startDurationSignal("cleanup", parameters: ["method": "auto"])
TelemetryDeck.stopAndSendDurationSignal("cleanup", parameters: ["result": "done"])
TelemetryDeck.cancelDurationSignal("cleanup")  // 전송 없이 취소

// Navigation — @MainActor
TelemetryDeck.navigationPathChanged(from: "grid", to: "viewer")
TelemetryDeck.navigationPathChanged(to: "viewer")  // 이전 destination이 자동으로 source
```

### 2.7 Privacy Manifest 선언 내용

```
NSPrivacyTracking: false
NSPrivacyAccessedAPITypes: UserDefaults (CA92.1)
NSPrivacyCollectedDataTypes:
  - ProductInteraction → Linked: false, Tracking: false, Purpose: Analytics
  - DeviceID → Linked: false, Tracking: false, Purpose: Analytics
```

### 2.8 아키텍처 설계에 미치는 영향

| 발견 | 설계 영향 |
|------|----------|
| SDK 세션 ≠ 우리 세션 (5분 vs 매 백그라운드) | **우리만의 세션 누적 카운터 + 백그라운드 전송 로직 필수** |
| SDK가 이미 `didEnterBackground` 감시 | 우리 옵저버와 충돌 없음 (각자 독립 동작) |
| Duration 추적 내장 (`@MainActor`) | **사용하지 않음** — 별도 시그널이 발생하여 세션 요약과 불일치. 자체 측정(`Date()` 차이)으로 통일 |
| `defaultParameters` 클로저 (매 전송 시 평가) | 사진 규모 구간을 넣되, **매번 PHAsset 조회하면 성능 문제** → 앱 실행 시 1회 계산 후 캐싱 |
| `SignalEnricher` 프로토콜 | 동적 메타데이터 추가의 대안 (defaultParameters보다 유연) |
| 파라미터 값 String만 가능 | 숫자→문자열 변환 필요 |
| `floatValue: Double?` 지원 | 단일 숫자값 전용 |
| 외부 의존성 0개 → 1개 추가 | Package.swift 수정 또는 Xcode 프로젝트에서만 의존 |

---

## 3. 래퍼 계층 설계

> **상태: 완료**

### 3.1 설계 배경

현재 앱 아키텍처 조사 결과:

| 항목 | 현황 |
|------|------|
| 아키텍처 | UIKit 기반 (`@main AppDelegate` + `SceneDelegate`) |
| 서비스 패턴 | `protocol XxxProtocol` + `final class Xxx: Singleton (.shared)` |
| 외부 의존성 | **0개** (AppCore는 순수 Apple 프레임워크만 사용) |
| 라이프사이클 훅 | `SceneDelegate`에 foreground/background 처리 존재 |
| 로그 시스템 | `Log.print("[Category] 메시지")` — 카테고리 기반 ON/OFF |

### 3.2 의존성 배치 선택지

> **확정: 방안 C (프로토콜 분리)**

TelemetryDeck SDK를 어디에 연결할지 3가지 방안 검토 후 C로 확정:

| | 방안 A: AppCore에 추가 | 방안 B: PickPhoto에만 추가 | 방안 C: 프로토콜 분리 |
|--|----------------------|-------------------------|---------------------|
| SDK 위치 | Package.swift → AppCore | Xcode 프로젝트 → PickPhoto | Xcode 프로젝트 → PickPhoto |
| 프로토콜 위치 | AppCore/Services/ | PickPhoto/Shared/Analytics/ | **AppCore** (경량, SDK 없음) |
| 구현체 위치 | AppCore/Services/ | PickPhoto/Shared/Analytics/ | **PickPhoto**/Shared/Analytics/ |
| AppCore 외부 의존성 | **추가됨** (TelemetryDeck) | 없음 | **없음** |
| AppCore 내부 오류 추적 | 직접 호출 | 불가 (호출자가 대신) | **가능** (프로토콜 경유) |
| 호출 방식 | `AnalyticsService.shared.xxx()` | `AnalyticsService.shared.xxx()` | AppCore: `Analytics.reporter?.xxx()` / PickPhoto: `AnalyticsService.shared.xxx()` |

**호출 지점 분석 결과:** 이벤트 7개 중 호출 지점의 **90% 이상이 PickPhoto**에 위치. AppCore에서 직접 호출이 필요한 건 이벤트 6(오류)의 내부 실패 추적 일부.

| AppCore 서비스 | 오류 상황 | 방안 B로 커버 가능? |
|---------------|---------|-------------------|
| ImagePipeline | 내부 재시도 후 성공한 실패 | **불가** — 호출자에게 안 보임 |
| ThumbnailCache | 디스크 쓰기 실패 | **불가** — 내부 조용히 처리 |
| 그 외 로딩 실패 | 호출자가 에러 콜백 받음 | 가능 |

### 3.3 래퍼 구조

> 검토 결과 AnalyticsBackend 별도 레이어는 과설계로 판단 → **단일 서비스 구조**로 단순화

```
┌─────────────────────────────────────────────┐
│  PickPhoto 코드 (VC, Feature 서비스)         │
│  AnalyticsService.shared.trackXxx()         │
│  AnalyticsService.shared.countXxx()         │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  AnalyticsService (Singleton, PickPhoto)     │
│  - TelemetryDeck SDK 직접 호출               │
│  - 세션 누적 카운터 관리                      │
│  - 백그라운드 진입 시 요약 전송               │
│  - 소요시간은 자체 측정 (Date() 차이)         │
│  - 사진 규모 구간은 캐싱 (앱 실행 시 1회)     │
└─────────────────────────────────────────────┘
         │ (방안 C인 경우)
┌────────▼────────────────────────────────────┐
│  Analytics.reporter (AppCore, 옵셔널)        │
│  - AppCore 내부 오류 추적용 경량 프로토콜     │
│  - PickPhoto에서 앱 시작 시 주입             │
└─────────────────────────────────────────────┘
```

**단순화 근거:**
- 1인 개발 프로젝트에서 Backend 추상화 레이어는 YAGNI
- SDK 교체 시 AnalyticsService 내부만 수정하면 충분
- Duration API도 사용하지 않으므로 Backend에 위임할 메서드가 단순 `send()`뿐

### 3.4 AnalyticsService 프로토콜

> **참고:** 아래는 초기 설계 초안. **최종 확정 프로토콜은 [5.6 프로토콜 최종 확정](#56-프로토콜-최종-확정)** 을 참조.
> 주요 변경: `String` 파라미터 → enum, `source:` 파라미터 추가, `countError` 오버로드 5개로 변경.

### 3.5 설계 원칙 (검토 반영)

| 원칙 | 설명 |
|------|------|
| **Duration API 미사용** | SDK Duration API는 별도 시그널을 생성하여 세션 요약과 불일치. 모든 소요시간은 `Date()` 차이로 자체 측정하여 파라미터에 포함. |
| **사진 규모 구간 캐싱** | `defaultParameters` 클로저 내에서 `PHAsset.fetchAssets()` 매번 호출 금지. 앱 실행(포그라운드 진입) 시 1회 계산 후 캐싱. |
| **실행 횟수: SDK 값 활용** | SDK가 `totalSessionsCount`를 자동 수집하므로 별도 카운터 불필요. 중복 방지. |
| **강제종료 시 데이터 유실 수용** | 앱이 강제종료/크래시되면 `sceneDidEnterBackground` 미호출 → 세션 누적 데이터 유실. 세션 요약의 본질적 한계로 수용. |
| **Thread Safety** | 누적 카운터는 `DispatchQueue(label: "analytics", attributes: .concurrent)` + barrier write로 보호. 오류 카운팅 등 백그라운드 큐 호출 대비. |
| **파라미터 값은 enum 정의** | `screen`, `category`, `item`, `source` 등 문자열 파라미터는 enum으로 정의하여 오타/cardinality 폭증 방지. rawValue로 String 변환. |
| **미주입 보호 (DEBUG)** | `Analytics.reporter`가 nil인 상태에서 AppCore 내부 호출 시, DEBUG 빌드에서 `assertionFailure`로 감지. Release에서는 `?.` 옵셔널 체이닝으로 조용히 무시. |
| **사용자 옵트아웃** | 옵트아웃 설정은 `UserDefaults`에 저장. **래퍼 레벨에서 UserDefaults 체크 후 조기 리턴이 주 메커니즘** (`countXxx()` / `trackXxx()` 진입부에서 `guard`). `TelemetryDeck.Config.analyticsDisabled`는 초기화 시 1회 설정하여 SDK 레벨 이중 차단. |

### 3.6 초기화 흐름

```
AppDelegate.didFinishLaunchingWithOptions
  └→ AnalyticsService.shared.configure()
       └→ TelemetryDeck.initialize(config:)
       └→ 사진 규모 구간 캐싱

SceneDelegate.sceneWillEnterForeground
  └→ AnalyticsService.shared.refreshPhotoLibraryBucket()
       └→ 사진 규모 구간 재계산 (포그라운드 복귀마다)
  └→ AnalyticsService.shared.trackAppLaunched()
       └→ 이벤트 1 시그널 전송 (세션당 1건)

SceneDelegate.sceneDidEnterBackground
  └→ AnalyticsService.shared.handleSessionEnd()
       └→ 누적 카운터 확인 → 값이 0이 아닌 이벤트만 시그널 전송
       └→ 카운터 리셋
```

---

## 4. 세션 관리 설계

> **상태: 완료**

### 4.1 세션 정의 (기술 관점)

| 항목 | 정의 | 구현 위치 |
|------|------|----------|
| **세션 시작** | `sceneWillEnterForeground` 호출 시점 | SceneDelegate |
| **세션 종료** | `sceneDidEnterBackground` 호출 시점 | SceneDelegate |
| **세션 요약 전송** | 종료 시 누적 카운터를 시그널로 변환 → 전송 → 리셋 | AnalyticsService |
| **미전송 조건** | 이벤트 그룹의 **모든 값이 0**이면 해당 그룹 시그널 스킵 | AnalyticsService |

> **SDK 세션과의 관계:** SDK는 백그라운드 5분 이상 후 복귀 시에만 새 세션을 시작한다. 우리의 세션은 매 백그라운드 진입마다 종료된다. 두 세션은 독립적으로 동작하며 서로 간섭하지 않는다.

### 4.2 누적 카운터 구조

세션 요약 대상 이벤트 5개 그룹의 카운터를 하나의 구조체로 관리한다.

```swift
/// 세션 동안 누적되는 모든 카운터
/// - 세션 종료 시 시그널로 변환 후 초기값으로 리셋
struct SessionCounters {

    // ── 이벤트 3: 사진 열람 ──
    struct PhotoViewing {
        var total: Int = 0          // 전체 열람 수
        var fromLibrary: Int = 0    // 보관함에서 열람
        var fromAlbum: Int = 0      // 앨범에서 열람
        var fromTrash: Int = 0      // 휴지통에서 열람

        var isZero: Bool { total == 0 }
    }

    // ── 이벤트 4-1: 보관함/앨범 삭제·복구 ──
    struct DeleteRestore {
        var gridSwipeDelete: Int = 0     // 그리드 스와이프 삭제
        var gridSwipeRestore: Int = 0    // 그리드 스와이프 복구
        var viewerSwipeDelete: Int = 0   // 뷰어 스와이프 삭제
        var viewerTrashButton: Int = 0   // 뷰어 휴지통 버튼
        var viewerRestoreButton: Int = 0 // 뷰어 복구 버튼
        var fromLibrary: Int = 0         // 보관함 경유 합계
        var fromAlbum: Int = 0           // 앨범 경유 합계

        var isZero: Bool {
            gridSwipeDelete == 0 && gridSwipeRestore == 0
            && viewerSwipeDelete == 0 && viewerTrashButton == 0
            && viewerRestoreButton == 0
        }
    }

    // ── 이벤트 4-2: 휴지통 뷰어 행동 ──
    struct TrashViewer {
        var permanentDelete: Int = 0   // 완전삭제
        var restore: Int = 0           // 보관함 복귀

        var isZero: Bool { permanentDelete == 0 && restore == 0 }
    }

    // ── 이벤트 5-1: 유사 사진 분석 ──
    struct SimilarAnalysis {
        var completedCount: Int = 0        // 분석 완료 횟수
        var cancelledCount: Int = 0        // 분석 취소 횟수
        var totalGroups: Int = 0           // 발견된 총 그룹 수 (완료 건의 합산)
        var totalDuration: TimeInterval = 0 // 총 소요시간 (완료 건의 합산, 평균 계산용)

        var isZero: Bool { completedCount == 0 && cancelledCount == 0 }

        /// 평균 소요시간 (초) — completedCount가 0이면 0
        var averageDuration: TimeInterval {
            completedCount > 0 ? totalDuration / Double(completedCount) : 0
        }
    }

    // ── 이벤트 6: 앱 오류 ──
    /// 키: "category.item" (예: "photoLoad.gridThumbnail")
    /// 값: 발생 횟수
    var errors: [String: Int] = [:]

    // ── 이벤트 8: 그리드 성능 ──
    struct GridPerformance {
        var grayShown: Int = 0       // 회색 셀 노출 횟수

        var isZero: Bool { grayShown == 0 }
    }

    // ── 그룹 인스턴스 ──
    var photoViewing = PhotoViewing()
    var deleteRestore = DeleteRestore()
    var trashViewer = TrashViewer()
    var similarAnalysis = SimilarAnalysis()
    var gridPerformance = GridPerformance()
}
```

**오류 키 규칙:**

| 카테고리 | 항목 | 키 | 구현 상태 |
|---------|------|-----|----------|
| 사진 로딩 | 그리드 썸네일 | `photoLoad.gridThumbnail` | **미연결** — ImagePipeline에서 PHImageErrorKey 체크 후 연결 필요 |
| 사진 로딩 | 뷰어 원본 | `photoLoad.viewerOriginal` | 연결됨 |
| 사진 로딩 | iCloud 다운로드 | `photoLoad.iCloudDownload` | **해당없음** — MVP에서 iCloud 다운로드 비활성화 (`isNetworkAccessAllowed = false`) |
| 얼굴 감지 | 감지 실패 | `face.detection` |
| 얼굴 감지 | 임베딩 실패 | `face.embedding` |
| 정리 | 시작 불가 | `cleanup.startFail` |
| 정리 | 이미지 로드 | `cleanup.imageLoad` |
| 정리 | 휴지통 이동 | `cleanup.trashMove` |
| 동영상 | 프레임 추출 | `video.frameExtract` |
| 동영상 | iCloud 스킵 | `video.iCloudSkip` |
| 캐시/저장 | 디스크 부족 | `storage.diskSpace` |
| 캐시/저장 | 썸네일 캐시 | `storage.thumbnailCache` |
| 캐시/저장 | 휴지통 데이터 | `storage.trashData` |

> 이 키들은 `ErrorCategory` enum + `ErrorItem` enum으로 구현하여 오타 방지 (3.5 설계 원칙 참조)

### 4.3 스레드 안전성

```swift
final class AnalyticsService {
    /// 누적 카운터 보호용 concurrent queue
    /// - 읽기: queue.sync { ... }       (동시 허용)
    /// - 쓰기: queue.async(flags: .barrier) { ... } (독점)
    private let queue = DispatchQueue(label: "com.pickphoto.analytics", attributes: .concurrent)

    /// 현재 세션의 누적 카운터 (queue 보호 하에 접근)
    private var counters = SessionCounters()
}
```

**호출 패턴:**

```swift
// ── 카운터 증가 (비동기 barrier write) ──
// 호출 스레드: 어디서든 안전 (메인/백그라운드)
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
// 호출 스레드: 메인 (sceneDidEnterBackground에서)
func handleSessionEnd() {
    // 데드락 방지: queue 자체에서 호출되지 않는지 확인
    dispatchPrecondition(condition: .notOnQueue(queue))

    let snapshot = queue.sync(flags: .barrier) { () -> SessionCounters in
        let current = self.counters
        self.counters = SessionCounters()  // 리셋
        return current
    }
    flushCounters(snapshot)
}
```

> **왜 `barrier sync`인가?**
> `handleSessionEnd()` 시점에 진행 중인 모든 barrier write가 완료될 때까지 대기한 후, 스냅샷을 찍고 리셋한다. 메인 스레드를 잠시 블로킹하지만, 정수 복사+리셋이므로 마이크로초 수준.

> **Swift 6 대응 참고:** 현재 concurrent queue + barrier 패턴은 Swift 5.9에서 정상 동작하지만, Swift 6의 strict concurrency 하에서는 `@Sendable` 클로저 또는 `actor` 전환이 필요할 수 있다. Swift 6 마이그레이션 시점에 재검토.

### 4.4 플러시 로직

```swift
/// 세션 카운터 스냅샷을 시그널로 변환하여 전송
/// - 각 그룹별로 isZero 확인 → 0이면 해당 시그널 스킵
private func flushCounters(_ c: SessionCounters) {

    // ── 이벤트 3: 사진 열람 ──
    if !c.photoViewing.isZero {
        TelemetryDeck.signal("session.photoViewing", parameters: [
            "total":       String(c.photoViewing.total),
            "fromLibrary": String(c.photoViewing.fromLibrary),
            "fromAlbum":   String(c.photoViewing.fromAlbum),
            "fromTrash":   String(c.photoViewing.fromTrash),
        ])
    }

    // ── 이벤트 4-1: 보관함/앨범 삭제·복구 ──
    if !c.deleteRestore.isZero {
        TelemetryDeck.signal("session.deleteRestore", parameters: [
            "gridSwipeDelete":     String(c.deleteRestore.gridSwipeDelete),
            "gridSwipeRestore":    String(c.deleteRestore.gridSwipeRestore),
            "viewerSwipeDelete":   String(c.deleteRestore.viewerSwipeDelete),
            "viewerTrashButton":   String(c.deleteRestore.viewerTrashButton),
            "viewerRestoreButton": String(c.deleteRestore.viewerRestoreButton),
            "fromLibrary":         String(c.deleteRestore.fromLibrary),
            "fromAlbum":           String(c.deleteRestore.fromAlbum),
        ])
    }

    // ── 이벤트 4-2: 휴지통 뷰어 행동 ──
    if !c.trashViewer.isZero {
        TelemetryDeck.signal("session.trashViewer", parameters: [
            "permanentDelete": String(c.trashViewer.permanentDelete),
            "restore":         String(c.trashViewer.restore),
        ])
    }

    // ── 이벤트 5-1: 유사 사진 분석 ──
    if !c.similarAnalysis.isZero {
        TelemetryDeck.signal("session.similarAnalysis", parameters: [
            "completedCount":  String(c.similarAnalysis.completedCount),
            "cancelledCount":  String(c.similarAnalysis.cancelledCount),
            "totalGroups":     String(c.similarAnalysis.totalGroups),
            "avgDurationSec":  String(format: "%.1f", c.similarAnalysis.averageDuration),
        ])
    }

    // ── 이벤트 6: 앱 오류 (비어있으면 스킵) ──
    if !c.errors.isEmpty {
        // 0이 아닌 항목만 파라미터에 포함
        let params = c.errors.compactMapValues { $0 > 0 ? String($0) : nil }
        if !params.isEmpty {
            TelemetryDeck.signal("session.errors", parameters: params)
        }
    }

    // ── 이벤트 8: 그리드 성능 ──
    if !c.gridPerformance.isZero {
        TelemetryDeck.signal("session.gridPerformance", parameters: [
            "grayShown": String(c.gridPerformance.grayShown),
        ])
    }
}
```

**시그널 이름 규칙:**

| 시그널 이름 | 이벤트 | 최대 빈도 |
|-----------|--------|----------|
| `session.photoViewing` | 3 | 세션당 0~1건 |
| `session.deleteRestore` | 4-1 | 세션당 0~1건 |
| `session.trashViewer` | 4-2 | 세션당 0~1건 |
| `session.similarAnalysis` | 5-1 | 세션당 0~1건 |
| `session.errors` | 6 | 세션당 0~1건 |
| `session.gridPerformance` | 8 | 세션당 0~1건 |

> `defaultSignalPrefix`를 `"PickPhoto."`로 설정하면 실제 전송되는 이름은 `PickPhoto.session.photoViewing` 등이 된다.

### 4.5 진입 경로 추적 (이벤트 4-1)

Spec에서 요구하는 "진입 경로 — 보관함/앨범" 카운트는 삭제·복구 행동의 **진입 경로별 합계**다. 이를 위해 삭제·복구 카운터 증가 시 진입 경로도 함께 증가시킨다.

```swift
// 호출 예: GridViewController(보관함)에서 스와이프 삭제
AnalyticsService.shared.countGridSwipeDelete(source: .library)

// 내부 구현 — DeleteSource enum 사용 (2개 case만, switch 완전)
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

> **`DeleteSource` vs `ScreenSource` 분리:**
> - `ScreenSource` (3개 case: `.library`, `.album`, `.trash`) — 사진 열람(이벤트 3) 전용
> - `DeleteSource` (2개 case: `.library`, `.album`) — 삭제·복구(이벤트 4-1) 전용
> - 분리 이유: 삭제·복구 switch에서 `.trash`가 불필요한데, Swift 컴파일러가 exhaustive check를 요구하므로 타입 레벨에서 방지.

> **뷰어에서 source 전달:**
> 현재 `ViewerCoordinator`에는 source 정보가 없다. 구현 시 `ViewerCoordinator` 생성자에 `source: DeleteSource` 파라미터를 추가하여, 뷰어 내 삭제·복구 시 진입 경로를 전달해야 한다.
> ```swift
> // GridViewController에서
> let coordinator = ViewerCoordinator(
>     fetchResult: fetchResult, trashStore: trashStore,
>     viewerMode: .normal, source: .library  // ← 추가
> )
> // AlbumGridViewController에서
> let coordinator = ViewerCoordinator(
>     fetchResult: fetchResult, trashStore: trashStore,
>     viewerMode: .normal, source: .album   // ← 추가
> )
> ```

### 4.6 SceneDelegate 통합 지점

```swift
// SceneDelegate.swift에 추가될 코드 (기존 코드에 3줄 추가)

func sceneWillEnterForeground(_ scene: UIScene) {
    AppStateStore.shared.handleForegroundTransition()
    PermissionStore.shared.checkAndNotifyIfChanged()
    cleanupInvalidTrashedAssets()

    // ── [추가] Analytics: 사진 규모 구간 갱신 ──
    AnalyticsService.shared.refreshPhotoLibraryBucket()

    // ── [추가] Analytics: 이벤트 1 — 앱 실행 시그널 전송 ──
    AnalyticsService.shared.trackAppLaunched()
}

func sceneDidEnterBackground(_ scene: UIScene) {
    AppStateStore.shared.handleBackgroundTransition()

    // ── [추가] Analytics: 세션 요약 전송 ──
    AnalyticsService.shared.handleSessionEnd()
}
```

### 4.7 설계 요약 — 데이터 흐름도

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
    ├─ 카운터 리셋 (= SessionCounters())
    │
    ▼
flushCounters(snapshot)
    │ 그룹별 isZero 확인
    ├─ 0 아님 → TelemetryDeck.signal() 호출
    └─ 전부 0 → 스킵 (시그널 미전송)
         │
         ▼
    SDK 내부 배치 큐 (10초 간격 전송)
```

---

## 5. 이벤트 수집기 설계

> **상태: 완료**

### 5.1 시그널 이름 총괄표

| # | 이벤트 | 시그널 이름 | 전송 방식 | 파라미터 수 |
|---|--------|-----------|----------|-----------|
| 1 | 앱 실행 | `app.launched` | 즉시 | 0 (자동 첨부) |
| 2 | 사진 접근 권한 | `permission.result` | 즉시 | 2 |
| 3 | 사진 열람 | `session.photoViewing` | 세션 요약 | 4 |
| 4-1 | 삭제·복구 | `session.deleteRestore` | 세션 요약 | 7 |
| 4-2 | 휴지통 뷰어 | `session.trashViewer` | 세션 요약 | 2 |
| 5-1 | 유사 분석 | `session.similarAnalysis` | 세션 요약 | 4 |
| 5-2 | 유사 그룹 행동 | `similar.groupClosed` | 즉시 (그룹별) | 2 |
| 6 | 앱 오류 | `session.errors` | 세션 요약 | 0~13 |
| 7-1 | 기존 정리 | `cleanup.completed` | 즉시 (종료 시) | 8 |
| 7-2 | 미리보기 정리 | `cleanup.previewCompleted` | 즉시 (종료 시) | 9 |
| 8 | 그리드 성능 | `session.gridPerformance` | 세션 요약 | 1 |

> `defaultSignalPrefix`를 `"PickPhoto."`로 설정 시 실제 전송 이름은 `PickPhoto.app.launched` 등이 된다.

### 5.2 공통 Enum 정의

```swift
// ── 화면 소스 (사진 열람: 이벤트 3) ──
enum ScreenSource: String {
    case library = "library"   // 보관함
    case album   = "album"     // 앨범
    case trash   = "trash"     // 휴지통
}

// ── 삭제·복구 진입 경로 (이벤트 4-1) ──
enum DeleteSource: String {
    case library = "library"   // 보관함
    case album   = "album"     // 앨범
    // 휴지통은 이벤트 4-2로 별도 추적 → .trash 불필요
}

// ── 권한 결과 ──
enum PermissionResultType: String {
    case fullAccess    = "fullAccess"
    case limitedAccess = "limitedAccess"
    case denied        = "denied"
}

// ── 권한 시점 ──
enum PermissionTiming: String {
    case firstRequest   = "firstRequest"
    case settingsChange = "settingsChange"
}

// ── 오류 카테고리.항목 (4.2에서 정의한 키를 enum화) ──
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

// ── 정리 도달 단계 (이벤트 7-1) ──
enum CleanupReachedStage: String {
    case buttonTapped     = "buttonTapped"      // 정리 버튼만 탭
    case trashWarningExit = "trashWarningExit"  // 휴지통 경고에서 이탈
    case methodSelected   = "methodSelected"    // 방식 선택까지
    case cleanupDone      = "cleanupDone"       // 정리 완료
    case resultAction     = "resultAction"      // 결과 행동까지
}

// ── 정리 방식 (기존 CleanupMethod enum의 분석용 문자열) ──
enum CleanupMethodType: String {
    case fromLatest        = "fromLatest"
    case continueFromLast  = "continueFromLast"
    case byYear            = "byYear"
}

// ── 정리 결과 ──
enum CleanupResultType: String {
    case completed = "completed"  // N장 이동 완료
    case noneFound = "noneFound"  // 0장 발견
    case cancelled = "cancelled"  // 사용자 취소
}

// ── 결과 행동 ──
enum CleanupResultAction: String {
    case confirm   = "confirm"    // 확인
    case viewTrash = "viewTrash"  // 휴지통 보기
}

// ── 미리보기 도달 단계 (이벤트 7-2) ──
enum PreviewReachedStage: String {
    case analyzed    = "analyzed"     // 분석까지
    case gridShown   = "gridShown"   // 그리드 표시
    case finalAction = "finalAction" // 최종 행동까지
}

// ── 미리보기 최종 행동 ──
enum PreviewFinalAction: String {
    case moveToTrash = "moveToTrash"  // 휴지통 이동
    case close       = "close"        // 닫기
}

// ── 미리보기 최종 도달 단계 (기존 PreviewStage enum의 분석용 문자열) ──
enum PreviewMaxStage: String {
    case light    = "light"     // 완화
    case standard = "standard"  // 기본
    case deep     = "deep"      // 강화
}
```

### 5.3 즉시 전송형 이벤트

#### 이벤트 1: 앱 실행

```swift
func trackAppLaunched() {
    // 사진 규모 구간: defaultParameters로 자동 첨부 (매 시그널)
    // 실행 횟수: SDK의 totalSessionsCount 자동 수집
    // → 커스텀 파라미터 불필요
    TelemetryDeck.signal("app.launched")
}
```

#### 이벤트 2: 사진 접근 권한

```swift
func trackPermissionResult(result: PermissionResultType, timing: PermissionTiming) {
    TelemetryDeck.signal("permission.result", parameters: [
        "result": result.rawValue,    // fullAccess / limitedAccess / denied
        "timing": timing.rawValue,    // firstRequest / settingsChange
    ])
}
```

#### 이벤트 5-2: 유사 사진 그룹 행동

```swift
func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int) {
    TelemetryDeck.signal("similar.groupClosed", parameters: [
        "totalCount":   String(totalCount),    // 그룹 전체 장수
        "deletedCount": String(deletedCount),  // 삭제 장수 (0이면 안 지움)
    ])
}
```

### 5.4 세션 요약형 이벤트

> 이벤트 3, 4-1, 4-2, 5-1, 6은 **4단계(세션 관리 설계)**에서 카운터 구조·플러시 로직 설계 완료.
> 여기서는 각 이벤트의 카운터 증가 메서드만 정리한다.

```swift
// ── 이벤트 3: 사진 열람 ──
func countPhotoViewed(from source: ScreenSource)
// → counters.photoViewing.total += 1, 소스별 += 1

// ── 이벤트 4-1: 삭제·복구 (source 파라미터로 진입 경로 동시 추적) ──
func countGridSwipeDelete(source: DeleteSource)
func countGridSwipeRestore(source: DeleteSource)
func countViewerSwipeDelete(source: DeleteSource)
func countViewerTrashButton(source: DeleteSource)
func countViewerRestoreButton(source: DeleteSource)
// → 각 카운터 += 1 + fromLibrary/fromAlbum += 1

// ── 이벤트 4-2: 휴지통 뷰어 ──
func countTrashPermanentDelete()
func countTrashRestore()
// → 각 카운터 += 1

// ── 이벤트 5-1: 유사 분석 ──
func countSimilarAnalysisCompleted(groups: Int, duration: TimeInterval)
// → completedCount += 1, totalGroups += groups, totalDuration += duration
func countSimilarAnalysisCancelled()
// → cancelledCount += 1

// ── 이벤트 6: 앱 오류 ──
func countError(_ error: AnalyticsError.PhotoLoad)
func countError(_ error: AnalyticsError.Face)
func countError(_ error: AnalyticsError.Cleanup)
func countError(_ error: AnalyticsError.Video)
func countError(_ error: AnalyticsError.Storage)
// → errors[error.rawValue, default: 0] += 1

// ── 이벤트 8: 그리드 성능 ──
func countGrayShown()
// → counters.gridPerformance.grayShown += 1
// 호출 지점: BaseGridViewController.willDisplay (앨범/휴지통), GridViewController.willDisplay (보관함)
// 수집 범위: 보관함, 앨범, 휴지통 — 모든 그리드 화면
```

> **오류 카운팅 참고:** 오버로드된 `countError()` 메서드로 enum별 타입 안전성 확보. 내부적으로 모두 `errors[key] += 1`로 통일.

### 5.5 정리 이벤트 데이터 모델

#### 이벤트 7-1: 기존 정리 — `CleanupEventData`

```swift
/// 기존 정리 흐름의 분석 데이터
/// - 정리 흐름에서 빠져나오는 순간 AnalyticsService에 전달
struct CleanupEventData {
    let reachedStage: CleanupReachedStage   // 도달 단계
    let trashWarningShown: Bool             // 휴지통 경고 표시 여부
    let method: CleanupMethodType?          // 선택 방식 (방식 선택 전 이탈이면 nil)
    let result: CleanupResultType?          // 결과 (정리 미진행이면 nil)
    let foundCount: Int                     // 발견(이동) 수
    let durationSec: Double                 // 소요시간 (초)
    let cancelProgress: Float?              // 취소 시 진행률 (취소 아니면 nil)
    let resultAction: CleanupResultAction?  // 결과 행동 (결과 화면 미도달이면 nil)
}
```

**시그널 변환:**

```swift
func trackCleanupCompleted(data: CleanupEventData) {
    var params: [String: String] = [
        "reachedStage":     data.reachedStage.rawValue,
        "trashWarningShown": String(data.trashWarningShown),
        "foundCount":       String(data.foundCount),
        "durationSec":      String(format: "%.1f", data.durationSec),
    ]
    // 옵셔널 필드: nil이면 파라미터에서 제외
    if let method = data.method {
        params["method"] = method.rawValue
    }
    if let result = data.result {
        params["result"] = result.rawValue
    }
    if let progress = data.cancelProgress {
        params["cancelProgress"] = String(format: "%.0f", progress * 100) // 0~100%
    }
    if let action = data.resultAction {
        params["resultAction"] = action.rawValue
    }
    TelemetryDeck.signal("cleanup.completed", parameters: params)
}
```

**호출 시점 매핑 (기존 코드 → 분석 데이터):**

| 코드 지점 | 데이터 소스 |
|----------|-----------|
| `reachedStage` | 정리 흐름 각 단계 진입 시 업데이트 |
| `trashWarningShown` | 휴지통 비어있지 않을 때 경고 표시 여부 |
| `method` | `CleanupMethod` enum → `CleanupMethodType` 변환 |
| `result` | `CleanupResult.resultType` → `CleanupResultType` 변환 |
| `foundCount` | `CleanupResult.foundCount` |
| `durationSec` | `CleanupResult.totalTimeSeconds` |
| `cancelProgress` | `CleanupProgress.progress` (취소 시점 캡처) |
| `resultAction` | 결과 화면 버튼 탭 콜백에서 캡처 |

#### 이벤트 7-2: 미리보기 정리 — `PreviewCleanupEventData`

```swift
/// 미리보기 정리의 분석 데이터
/// - 미리보기 화면에서 빠져나오는 순간 AnalyticsService에 전달
struct PreviewCleanupEventData {
    let reachedStage: PreviewReachedStage  // 도달 단계
    let foundCount: Int                    // 분석에서 찾은 저품질 사진 수
    let durationSec: Double                // 분석 소요 시간 (초)
    let maxStageReached: PreviewMaxStage   // 최종 도달 단계 (light/standard/deep)
    let expandCount: Int                   // "더 보기" 횟수
    let excludeCount: Int                  // "제외하기" 횟수
    let viewerOpenCount: Int               // 뷰어 열람 횟수
    let finalAction: PreviewFinalAction    // 최종 행동
    let movedCount: Int                    // 실제 휴지통 이동 수 (닫기면 0)
}
```

**시그널 변환:**

```swift
func trackPreviewCleanupCompleted(data: PreviewCleanupEventData) {
    TelemetryDeck.signal("cleanup.previewCompleted", parameters: [
        "reachedStage":    data.reachedStage.rawValue,
        "foundCount":      String(data.foundCount),
        "durationSec":     String(format: "%.1f", data.durationSec),
        "maxStageReached": data.maxStageReached.rawValue,
        "expandCount":     String(data.expandCount),
        "excludeCount":    String(data.excludeCount),
        "viewerOpenCount": String(data.viewerOpenCount),
        "finalAction":     data.finalAction.rawValue,
        "movedCount":      String(data.movedCount),
    ])
}
```

**호출 시점 매핑 (기존 코드 → 분석 데이터):**

| 코드 지점 | 데이터 소스 |
|----------|-----------|
| `reachedStage` | 미리보기 흐름 단계 진입 시 업데이트 |
| `foundCount` | `PreviewResult` 전체 후보 수 (light + standard + deep) |
| `durationSec` | `PreviewResult.totalTimeSeconds` |
| `maxStageReached` | 사용자가 최종적으로 확장한 `PreviewStage` |
| `expandCount` | "더 보기" 버튼 탭 카운터 |
| `excludeCount` | "제외하기" 버튼 탭 카운터 |
| `viewerOpenCount` | 미리보기 그리드에서 사진 탭 카운터 |
| `finalAction` | 화면 닫힘 시 마지막 행동 |
| `movedCount` | 실제 `PHAssetChangeRequest.deleteAssets` 호출 수 |

### 5.6 프로토콜 최종 확정

3.4 초안에서 변경된 사항을 반영한 최종 프로토콜:

```swift
/// 앱 전체에서 호출하는 분석 서비스 인터페이스
/// - PickPhoto: AnalyticsService가 직접 구현
/// - AppCore: Analytics.reporter로 주입 (옵셔널)
/// PickPhoto 모듈 내부 프로토콜 (internal)
/// - PickPhoto 외부에서 접근할 필요 없음 → public 불필요
/// - ScreenSource, DeleteSource 등 내부 enum을 참조하므로 public이면 컴파일 에러
protocol AnalyticsServiceProtocol: AnyObject {

    // ══════════════════════════════════════
    // 즉시 전송형
    // ══════════════════════════════════════
    func trackAppLaunched()
    func trackPermissionResult(result: PermissionResultType, timing: PermissionTiming)

    // ══════════════════════════════════════
    // 세션 누적형 — 카운터 증가만 (전송은 세션 종료 시)
    // ══════════════════════════════════════

    // 이벤트 3: 사진 열람
    func countPhotoViewed(from source: ScreenSource)

    // 이벤트 4-1: 보관함/앨범 삭제·복구
    func countGridSwipeDelete(source: DeleteSource)
    func countGridSwipeRestore(source: DeleteSource)
    func countViewerSwipeDelete(source: DeleteSource)
    func countViewerTrashButton(source: DeleteSource)
    func countViewerRestoreButton(source: DeleteSource)

    // 이벤트 4-2: 휴지통 뷰어
    func countTrashPermanentDelete()
    func countTrashRestore()

    // 이벤트 5-1: 유사 분석
    func countSimilarAnalysisCompleted(groups: Int, duration: TimeInterval)
    func countSimilarAnalysisCancelled()

    // 이벤트 6: 오류 (카테고리별 오버로드)
    func countError(_ error: AnalyticsError.PhotoLoad)
    func countError(_ error: AnalyticsError.Face)
    func countError(_ error: AnalyticsError.Cleanup)
    func countError(_ error: AnalyticsError.Video)
    func countError(_ error: AnalyticsError.Storage)

    // 이벤트 8: 그리드 성능
    func countGrayShown()

    // ══════════════════════════════════════
    // 그룹별 즉시 전송
    // ══════════════════════════════════════
    func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int)

    // ══════════════════════════════════════
    // 정리 기능 — 종료 시 1건
    // ══════════════════════════════════════
    func trackCleanupCompleted(data: CleanupEventData)
    func trackPreviewCleanupCompleted(data: PreviewCleanupEventData)

    // ══════════════════════════════════════
    // 라이프사이클
    // ══════════════════════════════════════
    func handleSessionEnd()
}
```

**3.4 초안 대비 변경 사항:**

| 변경 | 이유 |
|------|------|
| `countPhotoViewed(from:)` 파라미터: `String` → `ScreenSource` | enum으로 오타 방지 |
| 삭제·복구 메서드에 `source: DeleteSource` 추가 | 진입 경로 추적 (4.5). `ScreenSource`와 분리하여 `.trash` 불필요 case 제거 |
| `trackPermissionResult` 파라미터: `String` → enum | enum으로 오타 방지 |
| `countError` 오버로드 5개 | 카테고리별 타입 안전성 |
| `countError(category:item:)` 제거 | 자유 문자열 → enum 강제로 변경 |

### 5.7 AppCore용 경량 프로토콜 (방안 C)

```swift
// ── AppCore/Services/AnalyticsReporting.swift ──

/// AppCore 내부에서 오류를 보고하기 위한 경량 프로토콜
/// - PickPhoto에서 AnalyticsService를 주입
/// - SDK 의존성 없음 (순수 Swift)
public protocol AnalyticsReporting: AnyObject {
    func reportError(key: String)
}

/// AppCore 전역 접근점
public enum Analytics {
    /// PickPhoto에서 앱 시작 시 주입
    public static weak var reporter: AnalyticsReporting?
}
```

**AppCore 내부 호출 예시:**

```swift
// ImagePipeline.swift — 썸네일 로딩 실패 시
Analytics.reporter?.reportError(key: "photoLoad.gridThumbnail")

// ThumbnailCache.swift — 디스크 쓰기 실패 시
Analytics.reporter?.reportError(key: "storage.thumbnailCache")
```

**AnalyticsService에서 브릿지:**

```swift
// AnalyticsService.swift (PickPhoto)
extension AnalyticsService: AnalyticsReporting {
    func reportError(key: String) {
        queue.async(flags: .barrier) {
            self.counters.errors[key, default: 0] += 1
        }
    }
}

// 앱 시작 시 주입
Analytics.reporter = AnalyticsService.shared
```

> **AppCore 프로토콜은 `String` 키 유지:** AppCore에는 `AnalyticsError` enum이 없다 (PickPhoto에 위치). AppCore에서 보고할 오류 키는 소수(2~3종)이므로, 상수 문자열로도 관리 가능하다. 필요 시 AppCore에 별도 경량 enum을 추가할 수 있다.

---

## 6. 파일 구조

> **상태: 완료**

### 6.1 설계 원칙

| 원칙 | 설명 |
|------|------|
| **기능별 Extension 분리** | AnalyticsService 본체는 초기화·설정만. 이벤트 그룹마다 `+기능.swift` Extension으로 분리 |
| **새 이벤트 그룹 = 파일 추가** | 비즈니스 모델 등 새 이벤트 그룹 추가 시 기존 파일 수정 최소화. 새 파일만 추가 |
| **1,000줄 제한** | 프로젝트 코딩 규칙 준수. Extension 분리로 자연스럽게 달성 |
| **Models 분리** | Enum, 데이터 모델은 Models/ 하위에 독립 파일로 관리 |

### 6.2 파일 배치도

```
Sources/AppCore/Services/
└── AnalyticsReporting.swift              ← [신규] 경량 프로토콜 + Analytics.reporter

PickPhoto/PickPhoto/Shared/Analytics/
├── AnalyticsService.swift                ← [신규] 본체: 싱글톤, configure, queue, counters
├── AnalyticsService+Session.swift        ← [신규] SessionCounters, handleSessionEnd, flush
├── AnalyticsService+Lifecycle.swift      ← [신규] trackAppLaunched, trackPermission
├── AnalyticsService+Viewing.swift        ← [신규] countPhotoViewed
├── AnalyticsService+DeleteRestore.swift  ← [신규] countGridSwipeDelete 등 + trashViewer
├── AnalyticsService+Similar.swift        ← [신규] countSimilarAnalysis, trackGroupClosed
├── AnalyticsService+Cleanup.swift        ← [신규] trackCleanupCompleted, trackPreviewCompleted
├── AnalyticsService+Errors.swift         ← [신규] countError 오버로드 5개 + AnalyticsReporting 브릿지
├── Models/
│   ├── AnalyticsEnums.swift              ← [신규] ScreenSource, PermissionResultType 등
│   ├── AnalyticsError.swift              ← [신규] AnalyticsError 중첩 enum (13항목)
│   ├── CleanupEventData.swift            ← [신규] CleanupEventData + 관련 enum
│   └── PreviewCleanupEventData.swift     ← [신규] PreviewCleanupEventData + 관련 enum
│
│   ── 향후 확장 (비즈니스 모델 추가 시) ──
├── AnalyticsService+Business.swift       ← [미래] 결제/구독/페이월 이벤트
└── Models/
    └── BusinessEventData.swift           ← [미래] 비즈니스 이벤트 데이터 모델
```

**총 신규 파일: 12개** (AppCore 1개 + PickPhoto 11개)

### 6.3 각 파일 책임

#### AppCore (1개)

| 파일 | 내용 | 예상 줄 수 |
|------|------|-----------|
| `AnalyticsReporting.swift` | `AnalyticsReporting` 프로토콜 + `Analytics` enum (전역 접근점) | ~20줄 |

#### PickPhoto — 서비스 본체 (1개)

| 파일 | 내용 | 예상 줄 수 |
|------|------|-----------|
| `AnalyticsService.swift` | 싱글톤, `configure()`, `queue`, `counters` 프로퍼티, `refreshPhotoLibraryBucket()`, `AnalyticsServiceProtocol` 정의 | ~120줄 |

#### PickPhoto — Extension (7개)

| 파일 | 담당 이벤트 | 주요 메서드 | 예상 줄 수 |
|------|-----------|-----------|-----------|
| `+Session.swift` | 세션 관리 | `SessionCounters` struct, `handleSessionEnd()`, `flushCounters()` | ~150줄 |
| `+Lifecycle.swift` | 1, 2 | `trackAppLaunched()`, `trackPermissionResult()` | ~30줄 |
| `+Viewing.swift` | 3 | `countPhotoViewed(from:)` | ~25줄 |
| `+DeleteRestore.swift` | 4-1, 4-2 | `countGridSwipeDelete(source:)` 외 6개 | ~70줄 |
| `+Similar.swift` | 5-1, 5-2 | `countSimilarAnalysisCompleted()`, `trackSimilarGroupClosed()` | ~40줄 |
| `+Cleanup.swift` | 7-1, 7-2 | `trackCleanupCompleted()`, `trackPreviewCleanupCompleted()` | ~60줄 |
| `+Errors.swift` | 6 | `countError()` 오버로드 5개, `AnalyticsReporting` 브릿지 | ~50줄 |

#### PickPhoto — Models (4개)

| 파일 | 내용 | 예상 줄 수 |
|------|------|-----------|
| `AnalyticsEnums.swift` | `ScreenSource`, `DeleteSource`, `PermissionResultType`, `PermissionTiming` | ~30줄 |
| `AnalyticsError.swift` | `AnalyticsError` 중첩 enum (5카테고리 13항목) | ~40줄 |
| `CleanupEventData.swift` | `CleanupEventData`, `CleanupReachedStage`, `CleanupMethodType`, `CleanupResultType`, `CleanupResultAction` | ~50줄 |
| `PreviewCleanupEventData.swift` | `PreviewCleanupEventData`, `PreviewReachedStage`, `PreviewFinalAction`, `PreviewMaxStage` | ~40줄 |

### 6.4 확장 패턴 — 새 이벤트 그룹 추가 방법

비즈니스 모델(결제/구독/페이월) 등 새 이벤트 그룹을 추가할 때의 절차:

```
┌─────────────────────────────────────────────────────┐
│ 1. Models/ 에 데이터 모델 파일 추가                    │
│    └→ BusinessEventData.swift (enum + struct)        │
│                                                     │
│ 2. Extension 파일 추가                               │
│    └→ AnalyticsService+Business.swift                │
│       - 즉시 전송: trackXxx() 메서드                  │
│       - 세션 누적: countXxx() 메서드                  │
│                                                     │
│ 3. (세션 누적형이면) SessionCounters에 그룹 추가       │
│    └→ +Session.swift의 SessionCounters에             │
│       struct Business { ... } 추가                   │
│    └→ flushCounters()에 해당 그룹 전송 로직 추가       │
│                                                     │
│ 4. AnalyticsServiceProtocol에 메서드 추가             │
│    └→ AnalyticsService.swift                        │
│                                                     │
│ 5. 호출 지점에서 메서드 호출                           │
└─────────────────────────────────────────────────────┘
```

**수정 필요 파일 요약:**

| 추가 유형 | 새 파일 | 수정 파일 |
|----------|--------|----------|
| 즉시 전송만 | Model + Extension (2개) | Protocol (1개) |
| 세션 누적 포함 | Model + Extension (2개) | Protocol + Session (2개) |

### 6.5 확장 예시 — 비즈니스 모델 이벤트 (미래)

구독/결제 도입 시 추가될 이벤트 예상:

```swift
// ── Models/BusinessEventData.swift ──

/// 페이월 표시 이벤트
enum PaywallTrigger: String {
    case featureGate = "featureGate"   // 프리미엄 기능 시도
    case settingsTab = "settingsTab"   // 설정 탭에서 진입
    case onboarding  = "onboarding"    // 온보딩 중 표시
}

enum PaywallResult: String {
    case purchased  = "purchased"   // 구매 완료
    case restored   = "restored"    // 복원 완료
    case dismissed  = "dismissed"   // 닫기
    case failed     = "failed"      // 실패
}

/// 구독 상태 변경 이벤트
enum SubscriptionEvent: String {
    case started   = "started"
    case renewed   = "renewed"
    case cancelled = "cancelled"
    case expired   = "expired"
}
```

```swift
// ── AnalyticsService+Business.swift ──

extension AnalyticsService {

    func trackPaywallShown(trigger: PaywallTrigger) {
        TelemetryDeck.signal("paywall.shown", parameters: [
            "trigger": trigger.rawValue,
        ])
    }

    func trackPaywallResult(trigger: PaywallTrigger, result: PaywallResult) {
        TelemetryDeck.signal("paywall.result", parameters: [
            "trigger": trigger.rawValue,
            "result":  result.rawValue,
        ])
    }

    func trackSubscriptionChanged(event: SubscriptionEvent, plan: String) {
        TelemetryDeck.signal("subscription.changed", parameters: [
            "event": event.rawValue,
            "plan":  plan,
        ])
    }
}
```

> 이 예시는 비즈니스 모델 확정 시 구체화된다. 현재는 **파일 구조가 확장을 수용할 수 있는지** 검증 목적.

### 6.6 의존성 그래프

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
    │       ├── +Session.swift                            │
    │       ├── +Lifecycle.swift                          │
    │       ├── +Viewing.swift                            │
    │       ├── +DeleteRestore.swift                      │
    │       ├── +Similar.swift                            │
    │       ├── +Cleanup.swift                            │
    │       ├── +Errors.swift ─── AnalyticsReporting 채택 │
    │       └── +Business.swift (미래)                    │
    │                                                    │
    │  Models/                                           │
    │       ├── AnalyticsEnums.swift                      │
    │       ├── AnalyticsError.swift                      │
    │       ├── CleanupEventData.swift                    │
    │       ├── PreviewCleanupEventData.swift             │
    │       └── BusinessEventData.swift (미래)            │
    │                                                    │
    │       ↓ 호출                                       │
    │  TelemetryDeck SDK                                 │
    └────────────────────────────────────────────────────┘
```

---

## 7. 데이터 접근 경로

> **상태: 완료**

### 7.1 목적

수집된 분석 데이터를 두 가지 경로로 활용한다:

| 경로 | 대상 | 방식 |
|------|------|------|
| **대시보드** | 사용자(주인님) | TelemetryDeck 웹 대시보드에서 직접 조회 |
| **Query API** | Claude (AI 분석) | REST API로 데이터 조회 → JSON 파싱 → 인사이트 추출 |

### 7.2 TelemetryDeck Query API 개요

**공식 문서:** https://telemetrydeck.com/docs/api/api-run-query/

| 항목 | 내용 |
|------|------|
| 호스트 | `api.telemetrydeck.com` |
| 인증 | Bearer Token (이메일+비밀번호 → 토큰 발급) |
| 쿼리 언어 | TQL (TelemetryDeck Query Language, Druid 기반) |
| 응답 형식 | JSON (rows 배열 + 메타데이터) |
| 실행 방식 | 비동기 3단계 (제출 → 상태 폴링 → 결과 조회) |

### 7.3 인증 흐름

```
1. 토큰 발급
   POST https://api.telemetrydeck.com/api/v3/users/login
   Authorization: Basic <base64(email:password)>
   → { "value": "<bearer_token>", "expiresAt": "..." }

2. API 호출 시
   Authorization: Bearer <bearer_token>
```

> **보안:** Bearer Token은 비밀번호와 동급. 환경변수 또는 키체인으로 관리. 코드에 하드코딩 금지.

**참고:** https://telemetrydeck.com/docs/api/api-token/

### 7.4 쿼리 실행 3단계

```
Step 1: 쿼리 제출
  POST /api/v3/query/calculate-async/
  Body: TQL 쿼리 (JSON)
  → { "queryTaskID": "55b3487da8018369" }

Step 2: 상태 확인 (폴링)
  GET /api/v3/task/{taskID}/status/
  → { "status": "running" }  또는
  → { "status": "successful" }

Step 3: 결과 조회
  GET /api/v3/task/{taskID}/value/
  → {
      "calculationDuration": 0.218,
      "result": {
        "rows": [{"count": 516, "modelName": "iPhone13,1"}],
        "type": "topNResult"
      }
    }
```

### 7.5 지원 쿼리 타입

| 쿼리 타입 | 용도 | 우리 활용 예시 |
|----------|------|-------------|
| **timeseries** | 시간별 추이 | 일별 앱 실행 수, 주간 삭제 추이 |
| **topN** | 상위 N개 값 | 가장 많은 오류 TOP 5 |
| **groupBy** | 차원별 그룹화 | OS 버전별 사진 열람, 정리 방식별 비율 |
| **scan** | 개별 이벤트 목록 | 특정 날짜 정리 이벤트 전체 |
| **funnel** | 퍼널 분석 | 정리 도달 단계별 이탈률 |
| **retention** | 리텐션 분석 | 주간 재방문율 |
| **experiment** | A/B 테스트 | 향후 활용 |

**참고:** https://telemetrydeck.com/docs/tql/query/

### 7.6 우리 시그널별 쿼리 예시

#### 일별 앱 실행 추이

```json
{
  "queryType": "timeseries",
  "dataSource": "telemetry-signals",
  "granularity": "day",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.app.launched"
  },
  "aggregations": [
    { "type": "count", "name": "launchCount" }
  ],
  "relativeIntervals": [{ "beginningDate": { "component": "day", "offset": -30 }, "endDate": { "component": "day", "offset": 0 } }]
}
```

#### 정리 방식별 사용 비율

```json
{
  "queryType": "topN",
  "dataSource": "telemetry-signals",
  "dimension": "method",
  "threshold": 10,
  "metric": "count",
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.cleanup.completed"
  },
  "aggregations": [
    { "type": "count", "name": "count" }
  ],
  "granularity": "all"
}
```

#### 오류 발생 현황

```json
{
  "queryType": "groupBy",
  "dataSource": "telemetry-signals",
  "dimensions": ["photoLoad.gridThumbnail", "face.detection", "cleanup.startFail"],
  "filter": {
    "type": "selector",
    "dimension": "type",
    "value": "PickPhoto.session.errors"
  },
  "aggregations": [
    { "type": "count", "name": "sessionCount" }
  ],
  "granularity": "week"
}
```

### 7.7 Claude 분석 워크플로우

```
주인님: "지난 주 분석 데이터 요약해줘"
    │
    ▼
Claude: Bash로 curl 실행
    │
    ├─ 1. 토큰 발급 (환경변수에서 credentials 읽기)
    ├─ 2. 시그널별 쿼리 제출 (병렬)
    ├─ 3. 결과 JSON 수집
    │
    ▼
Claude: JSON 파싱 → 인사이트 추출
    │
    ├─ 주간 활성 사용자 추이
    ├─ 가장 많이 사용된 기능
    ├─ 오류 발생률 변화
    ├─ 정리 기능 전환율 (퍼널)
    │
    ▼
주인님에게 요약 리포트 제공
```

**필요 환경 설정 (구현 시):**

```bash
# .env 또는 키체인에 저장 (git 추적 제외)
TELEMETRYDECK_EMAIL=user@example.com
TELEMETRYDECK_PASSWORD=****
```

### 7.8 Insight 활용 (저장된 쿼리)

대시보드에서 자주 쓰는 쿼리를 Insight로 저장해두면, API로 바로 조회할 수 있다.

```
1. Insight 쿼리 가져오기
   POST /api/v3/insights/{insightID}/query/
   → TQL 쿼리 JSON 반환

2. 가져온 쿼리로 실행
   POST /api/v3/query/calculate-async/
   → 결과 조회
```

> 대시보드에서 만든 차트를 그대로 API로 재현할 수 있어, 대시보드와 AI 분석 간 일관성 유지.

**참고:** https://telemetrydeck.com/docs/api/api-query-from-insight/

### 7.9 비용 및 접근 제한

| 항목 | 현재 | 향후 |
|------|------|------|
| API 접근 | **무료 (제한 미적용)** | Tier 2 이상 유료 플랜 필요 예고 |
| API 호출 비용 | 별도 과금 없음 | 미정 |
| 시그널 한도 | Free: 100K/월 | 유료: €19/월~ (1.5M/월) |

> 사용자 증가에 따라 자연스럽게 유료 전환 예정. API 접근도 유료 플랜에 포함되므로 추가 비용 없음.

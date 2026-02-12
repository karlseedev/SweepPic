# Analytics 구현 아키텍처 설계

> **작성일:** 2026-02-12
> **상태:** 설계 진행 중
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

---

## 1. 설계 계획

| 단계 | 내용 | 산출물 | 상태 |
|------|------|--------|------|
| **1** | TelemetryDeck SDK API 파악 | SDK 기능/제약 정리 | **완료** |
| **2** | 래퍼 계층 설계 | 프로토콜 + 구현 클래스 구조 | **완료** |
| **3** | 세션 관리 설계 | SessionManager 구조 | 대기 |
| **4** | 이벤트 수집기 설계 | 7개 이벤트 데이터 모델 | 대기 |
| **5** | 파일 구조 결정 | 폴더/파일 배치도 | 대기 |

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
| 배치 전송 | `DispatchSource` 타이머, 10초 간격, 1회 최대 100건, 오프라인 큐 + 재시도 내장 |

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

```swift
/// 앱 전체에서 호출하는 분석 서비스 인터페이스
public protocol AnalyticsServiceProtocol: AnyObject {
    // === 즉시 전송형 ===
    func trackAppLaunched()
    func trackPermissionResult(result: String, isFirstTime: Bool)

    // === 세션 누적형 — 카운터 증가만 (전송은 세션 종료 시) ===
    func countPhotoViewed(from screen: String)
    func countGridSwipeDelete()
    func countGridSwipeRestore()
    func countViewerSwipeDelete()
    func countViewerTrashButton()
    func countViewerRestoreButton()
    func countTrashPermanentDelete()
    func countTrashRestore()
    func countSimilarAnalysisCompleted(groups: Int, duration: TimeInterval)
    func countSimilarAnalysisCancelled()
    func countError(category: String, item: String)

    // === 그룹별 즉시 전송 ===
    func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int)

    // === 정리 기능 — 종료 시 1건 ===
    func trackCleanupCompleted(data: CleanupEventData)
    func trackPreviewCleanupCompleted(data: PreviewCleanupEventData)

    // === 라이프사이클 ===
    func handleSessionEnd()  // 백그라운드 진입 시 호출
}
```

### 3.5 설계 원칙 (검토 반영)

| 원칙 | 설명 |
|------|------|
| **Duration API 미사용** | SDK Duration API는 별도 시그널을 생성하여 세션 요약과 불일치. 모든 소요시간은 `Date()` 차이로 자체 측정하여 파라미터에 포함. |
| **사진 규모 구간 캐싱** | `defaultParameters` 클로저 내에서 `PHAsset.fetchAssets()` 매번 호출 금지. 앱 실행(포그라운드 진입) 시 1회 계산 후 캐싱. |
| **실행 횟수: SDK 값 활용** | SDK가 `totalSessionsCount`를 자동 수집하므로 별도 카운터 불필요. 중복 방지. |
| **강제종료 시 데이터 유실 수용** | 앱이 강제종료/크래시되면 `sceneDidEnterBackground` 미호출 → 세션 누적 데이터 유실. 세션 요약의 본질적 한계로 수용. |
| **Thread Safety** | 누적 카운터는 `DispatchQueue(label: "analytics", attributes: .concurrent)` + barrier write로 보호. 오류 카운팅 등 백그라운드 큐 호출 대비. |

### 3.6 초기화 흐름

```
AppDelegate.didFinishLaunchingWithOptions
  └→ AnalyticsService.shared.configure()
       └→ TelemetryDeck.initialize(config:)
       └→ 사진 규모 구간 캐싱

SceneDelegate.sceneWillEnterForeground
  └→ AnalyticsService.shared.refreshPhotoLibraryBucket()
       └→ 사진 규모 구간 재계산 (포그라운드 복귀마다)

SceneDelegate.sceneDidEnterBackground
  └→ AnalyticsService.shared.handleSessionEnd()
       └→ 누적 카운터 확인 → 값이 0이 아닌 이벤트만 시그널 전송
       └→ 카운터 리셋
```

---

## 4. 세션 관리 설계

> 대기

---

## 5. 이벤트 수집기 설계

> 대기

---

## 6. 파일 구조

> 대기

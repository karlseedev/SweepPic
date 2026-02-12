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
| Duration 추적 내장 (`@MainActor`) | 자체 타이머 불필요, 메인 스레드 호출 주의 |
| `defaultParameters` 클로저 (매 전송 시 평가) | 사진 규모 구간을 여기에 넣으면 자동 첨부 |
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

TelemetryDeck SDK를 어디에 연결할지 2가지 방안:

| | 방안 A: AppCore에 추가 | 방안 B: PickPhoto에만 추가 |
|--|----------------------|-------------------------|
| SDK 위치 | Package.swift → AppCore 의존성 | Xcode 프로젝트 → PickPhoto 타겟 |
| 래퍼 위치 | AppCore/Services/ | PickPhoto/Shared/Analytics/ |
| 장점 | 기존 서비스와 동일 레벨, 호출 간단 | AppCore 무의존성 유지 |
| 단점 | AppCore 최초 외부 의존성 | AppCore 서비스에서 직접 호출 불가 |

**권장: 방안 A**
- 기존 서비스 패턴과 일관성 유지 (`AnalyticsService.shared.xxx`)
- AppCore 서비스(CleanupService, PhotoLibraryService 등)에서도 바로 호출 가능
- TelemetryDeck SDK는 외부 의존성이 0개인 경량 라이브러리 → AppCore에 추가해도 부담 없음

### 3.3 래퍼 구조

```
┌─────────────────────────────────────────────┐
│  기존 코드 (VC, Service, Store)              │
│  AnalyticsService.shared.trackXxx()         │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  AnalyticsService (Singleton)                │
│  - protocol AnalyticsServiceProtocol         │
│  - 세션 누적 카운터 관리                      │
│  - 백그라운드 진입 시 요약 전송               │
│  - 즉시 전송 이벤트 처리                      │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  AnalyticsBackend (Protocol)                 │
│  - send(name:, parameters:, floatValue:)     │
│  - configure(appID:)                         │
└────────────────┬────────────────────────────┘
                 │
┌────────────────▼────────────────────────────┐
│  TelemetryDeckBackend (구현체)               │
│  - TelemetryDeck SDK 직접 호출               │
│  - 향후 교체 가능 (Supabase, PostHog 등)     │
└─────────────────────────────────────────────┘
```

**2단계 래퍼 구조:**
1. **AnalyticsBackend** (protocol) — SDK 종속성 격리. 전송만 담당.
2. **AnalyticsService** (singleton) — 비즈니스 로직. 누적/요약/시점 판단.

### 3.4 AnalyticsBackend 프로토콜 (SDK 격리층)

```swift
/// Analytics SDK를 추상화하는 백엔드 프로토콜
/// 향후 TelemetryDeck → 다른 SDK 교체 시 이 구현체만 교체
public protocol AnalyticsBackend: AnyObject {
    func configure(appID: String, defaultParameters: @Sendable @escaping () -> [String: String])
    func send(_ signalName: String, parameters: [String: String])
    func send(_ signalName: String, parameters: [String: String], floatValue: Double)
    func startDuration(_ name: String, parameters: [String: String])
    func stopDuration(_ name: String, parameters: [String: String])
    func cancelDuration(_ name: String)
    func navigationChanged(from: String, to: String)
    var isEnabled: Bool { get set }
}
```

### 3.5 AnalyticsService 프로토콜 (비즈니스 로직층)

```swift
/// 앱 전체에서 호출하는 분석 서비스 인터페이스
public protocol AnalyticsServiceProtocol: AnyObject {
    // 즉시 전송형
    func trackAppLaunched()
    func trackPermissionResult(result: String, isFirstTime: Bool)

    // 세션 누적형 — 카운터 증가만 (전송은 세션 종료 시)
    func countPhotoViewed(from screen: String)
    func countGridSwipeDelete()
    func countGridSwipeRestore()
    func countViewerSwipeDelete()
    func countViewerTrashButton()
    func countViewerRestoreButton()
    func countTrashPermanentDelete()
    func countTrashRestore()
    func countSimilarAnalysisCompleted(groups: Int, duration: Double)
    func countSimilarAnalysisCancelled()
    func countError(category: String, item: String)

    // 그룹별 즉시 전송
    func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int)

    // 정리 기능 — 종료 시 1건
    func trackCleanupCompleted(data: CleanupEventData)
    func trackPreviewCleanupCompleted(data: PreviewCleanupEventData)

    // 라이프사이클
    func handleSessionEnd()  // 백그라운드 진입 시 호출
}
```

### 3.6 초기화 흐름

```
AppDelegate.didFinishLaunchingWithOptions
  └→ AnalyticsService.shared.configure()
       └→ TelemetryDeckBackend.configure(appID:, defaultParameters:)
            └→ TelemetryDeck.initialize(config:)

SceneDelegate.sceneDidEnterBackground
  └→ AnalyticsService.shared.handleSessionEnd()
       └→ 누적 카운터 → 시그널 변환 → backend.send() × N
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

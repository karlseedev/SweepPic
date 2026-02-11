# iOS 26 뷰어 Metal Cold-Start Hang 해결

## 문제

iOS 26에서 뷰어 첫 열기 시 ~14초 Hang 발생.
iOS 25에서는 FloatingOverlay(LiquidGlassTabBar)가 앱 시작 시 Metal 워밍업 → 뷰어 빠름.
iOS 26에서는 `useFloatingUI = false`로 FloatingOverlay 미생성 → Metal cold-start가 뷰어 시점에 발생.

## 근본 원인

`LiquidGlassRenderer`는 `@MainActor static let shared` 싱글턴. 첫 접근 시:
- `MTLCreateSystemDefaultDevice()` → GPU 디바이스 할당
- `device.makeDefaultLibrary(bundle:)` → Metal shader 라이브러리 로드
- `library.makeFunction(constantValues:)` → shader 함수 2세트 컴파일
- `device.makeRenderPipelineState()` × 2 → GPU shader 컴파일 (핵심 비용)

이 싱글턴은 `LiquidGlassView.init()`에서 `.device` 접근 시 초기화됨.

### 이전 워밍업 실험 실패 원인

`LiquidGlassEffect(style: .regular, isNative: true)` 사용 →
iOS 26에서 `isNative: true`이면 **네이티브 UIGlassEffect** 반환 → **Metal 코드 전혀 미실행**.

## 해결

`LiquidGlassSettings`에 `warmUp()` public API를 추가하여
iOS 26 앱 시작 시 `LiquidGlassRenderer.shared` 싱글턴을 사전 초기화.

## 수정 파일

### 1. LiquidGlassSettings.swift (LiquidGlassKit)
`/Users/karl/Project/Photos/iOS/LiquidGlassKit/Sources/LiquidGlassKit/LiquidGlassSettings.swift`

`warmUp()` static 메서드 추가:
```swift
/// Metal shader 사전 컴파일 (cold-start Hang 방지)
/// 앱 시작 시 호출하면 첫 LiquidGlassView 생성 시 지연 제거.
/// 메인 스레드에서 호출 (@MainActor singleton).
@MainActor
public static func warmUp() {
    _ = LiquidGlassRenderer.shared
}
```

### 2. TabBarController.swift
`/Users/karl/Project/Photos/iOS/PickPhoto/PickPhoto/Shared/Navigation/TabBarController.swift`

`viewDidLoad()`에서 iOS 26 전용 워밍업 호출:
```swift
/// iOS 26 전용 Metal shader 사전 워밍업
private func warmUpMetalIfNeeded() {
    guard !useFloatingUI else { return }  // iOS 25는 FloatingOverlay가 처리
    DispatchQueue.main.async {
        let t0 = CACurrentMediaTime()
        LiquidGlassSettings.warmUp()
        let t1 = CACurrentMediaTime()
        Log.print("[TabBarController] Metal warmup: \(String(format: "%.0f", (t1-t0)*1000))ms")
    }
}
```

## 검증

1. iOS 26 실기기에서 빌드 후 첫 실행
2. 그리드에서 사진 탭 → 뷰어 열기
3. `[Viewer Timing] ✅ viewDidAppear` 로그에서 탭 후 시간 확인
4. 목표: ~500ms 이하 (FloatingOverlay 강제 시 478ms였으므로)
5. `[TabBarController] Metal warmup: XXms` 로그로 워밍업 비용 확인

## 리스크

- `LiquidGlassRenderer.shared` 초기화만으로 충분한지 미검증
  (GPU shader는 pipelineState 생성 시 컴파일되지만, 첫 draw call에서 추가 초기화 가능)
- 부족할 경우: warmUp()에서 LiquidGlassView를 1개 생성하고 수동 draw() 1회 호출 후 제거하는 방식으로 보강

---

## 실험 결과 (2026-02-11)

### 실험 A: LiquidGlassRenderer.shared 사전 초기화 — 실패

계획서대로 `LiquidGlassSettings.warmUp()` (내부: `_ = LiquidGlassRenderer.shared`) 구현.

| 구간 | 수치 |
|------|------|
| AnalysisLoadingIndicator() | 4120.7ms |
| 탭~화면표시 총 | **13580.3ms** |

→ **효과 없음.** Metal 싱글턴 초기화만으로는 해결 불가.

### 원인 재분석

계획서의 "Metal cold-start" 분석이 틀렸음을 확인:

1. **iOS 26 뷰어에서 LiquidGlassView가 아예 생성되지 않음**
   - `useSystemUI = true` (Push 방식, navigationController != nil) → GlassIconButton 미생성
   - FaceButtonOverlay → iOS 26에서 toggleButton 미생성
   - 뷰어 열기 시점에 Metal을 쓰는 코드 자체가 없음
2. **증상 패턴이 FirstLoading1과 동일**
   - `AnalysisLoadingIndicator()` 4120ms — 순수 UIView(UIActivityIndicatorView + UIBlurEffect)인데 수초 블로킹
   - FirstLoading1에서도 `UIActivityIndicatorView type metadata accessor`에서 dyld 락 블로킹 확인
3. **iOS 26에서 feedbackGenerator.prepare() 실행 경로 전무**
   - FloatingOverlay 미생성 → 내부 버튼의 feedbackGenerator.prepare() 미실행
   - 뷰어 시스템 UI 사용 → GlassIconButton 미생성 → feedbackGenerator.prepare() 미실행
   - 앱 전체에서 dyld 워밍업이 한 번도 수행되지 않음

### 실험 B: feedbackGenerator.prepare()만 호출 — 성공

TabBarController.viewDidLoad()에서 iOS 26 전용:
```swift
if !useFloatingUI {
    UIImpactFeedbackGenerator(style: .light).prepare()
}
```

| 구간 | 실험 A (실패) | 실험 B (성공) |
|------|:-:|:-:|
| AnalysisLoadingIndicator() | 4120.7ms | **2.2ms** |
| FaceButtonOverlay() | 0.1ms | 0.1ms |
| 탭~화면표시 총 | 13580.3ms | **485.8ms** |

→ **해결 확인.** 목표(~500ms) 달성.

### 근본 원인 확정

**FirstLoading1과 동일 원인**: `feedbackGenerator.prepare()`의 dyld 워밍업 부수 효과 부재.

- `feedbackGenerator.prepare()` → CHHapticEngine → AVAudioSession → AudioToolbox **dyld 로딩** (백그라운드)
- 이 백그라운드 로딩이 dyld 글로벌 락을 미리 잡고 풀어줌
- 이후 UIKit 초기화(type metadata accessor 등)가 dyld 락에 블로킹되지 않음
- iOS 25에서는 FloatingOverlay 내 GlassIconButton이 이 역할을 수행
- iOS 26에서는 FloatingOverlay 미생성 + 뷰어 시스템 UI 사용으로 경로 소실

### 최종 수정 파일

**TabBarController.swift** (`viewDidLoad()`에 4줄 추가):
```swift
// iOS 26: feedbackGenerator.prepare()로 dyld 워밍업
// CHHapticEngine → AudioToolbox dyld 로딩이 백그라운드에서 수행되어
// 뷰어 열기 시 dyld 글로벌 락 경합을 방지 (FirstLoading1과 동일 원인)
// iOS 25에서는 FloatingOverlay 내 GlassIconButton이 이 역할을 수행
if !useFloatingUI {
    UIImpactFeedbackGenerator(style: .light).prepare()
}
```

LiquidGlassSettings.swift 수정 불필요 (Metal cold-start가 원인이 아니었으므로).

### 인사이트

계획서에서 "FloatingOverlay 강제 생성 → 478ms 해결"의 원인을 Metal 초기화로 분석했으나, 실제로는 FloatingOverlay 내부 버튼의 `feedbackGenerator.prepare()` 부수 효과가 핵심이었다. 동일 실험(FloatingOverlay 강제)에서 Metal 초기화와 feedbackGenerator 워밍업이 동시에 발생하여 구분이 안 됐으나, 각각 분리 실험한 결과 Metal 초기화는 효과 없고 feedbackGenerator만 효과 있음을 확인.

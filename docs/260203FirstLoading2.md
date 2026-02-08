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

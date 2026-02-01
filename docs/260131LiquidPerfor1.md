# LiquidGlass MTKView 최적화 계획

## 목표
LiquidGlassKit의 MTKView가 불필요하게 GPU 렌더링하는 것을 줄여 성능 개선.
4개 방안을 **1개씩 순차 적용 + 테스트**하여 효과를 수치로 확인.

## 현황

| 컴포넌트 | MTKView 수 | 위치 | 비고 |
|---------|-----------|------|------|
| 탭바 Platter | 1 | LiquidGlassPlatter.swift | 항상 표시 |
| 탭바 SelectionPill | 1 | LiquidGlassSelectionPill.swift | 항상 표시 |
| 상단 backButton (GlassIconButton) | 2 (contracted+expanded) | FloatingTitleBar.swift:128 | **기본 hidden** |
| 상단 selectButton (GlassTextButton) | 2 (contracted+expanded) | FloatingTitleBar.swift:153 | 항상 표시 |
| 상단 secondRightButton (GlassTextButton) | 2 (contracted+expanded) | FloatingTitleBar.swift:163 | **기본 hidden** |
| **합계** | **8개** | | hidden 버튼의 MTKView가 실제 렌더링하는지 진단 로그로 확인 필요 |

> **주의**: backButton, secondRightButton은 `isHidden = true`가 기본.
> UIKit은 hidden 뷰의 draw를 건너뛰지만, MTKView(CAMetalLayer)는 별도 렌더링 루프를 가짐.
> 실제 active 수는 진단 로그로 확인 후 보정.

## 사전 작업: 진단 로그 추가

**파일**: `PickPhoto/PickPhoto/Debug/LiquidGlassOptimizer.swift`

LiquidGlassOptimizer에 유틸리티 메서드 2개 추가:

1. `setMTKViewsPaused(_:in:)` — 특정 뷰 내부의 MTKView isPaused 일괄 설정
2. `logMTKViewStatus(in:label:)` — 현재 전체 MTKView 상태 로그 (active/paused/total)

```swift
/// 특정 뷰 내부의 모든 MTKView isPaused 일괄 설정
static func setMTKViewsPaused(_ paused: Bool, in view: UIView) {
    for mtkView in findAllMTKViews(in: view) {
        mtkView.isPaused = paused
    }
}

/// 진단: 전체 MTKView 상태 로그
static func logMTKViewStatus(in rootView: UIView?, label: String) {
    guard let rootView = rootView else { return }
    let all = findAllMTKViews(in: rootView)
    let active = all.filter { !$0.isPaused }.count
    let paused = all.count - active
    Log.print("[LiquidGlass:Status] \(label): active=\(active), paused=\(paused), total=\(all.count)")
}
```

각 Phase 적용 전후에 이 로그를 찍어서 수치 변화 확인.

---

## Phase 1: 버튼 2뷰 → 1뷰 구조 변경

**대상 파일 (4개)**:
- `PickPhoto/PickPhoto/Shared/Components/GlassIconButton.swift`
- `PickPhoto/PickPhoto/Shared/Components/GlassTextButton.swift`
- `PickPhoto/PickPhoto/Shared/Components/GlassCircleButton.swift`
- `PickPhoto/PickPhoto/Shared/Components/GlassButton.swift`

**배경**: 현재 각 버튼은 contracted(resting) + expanded(pressed) 2개의 LiquidGlassEffect 뷰를 가짐.
두 뷰의 차이는 tintColor뿐 (`UIColor(white: 0.5, alpha: 0.2)` vs 기본값)으로 매우 미세함.
2뷰 크로스페이드를 1뷰 scale 애니메이션으로 대체하면 **MTKView 생성 수 자체를 절반으로 줄임**.

**변경 내용**: expandedView 제거, contractedView 1개로 터치 애니메이션 처리

### 공통 변경 (4개 파일 모두)

1. `expandedView` lazy var 프로퍼티 삭제
2. `isExpanded` 프로퍼티 삭제 (1뷰에서는 불필요 — isHighlighted로 대체 가능)
3. `setupLayers()`에서 `insertSubview(expandedView, ...)` 삭제
4. `layoutSubviews()`에서 expandedView 프레임/코너 설정 블록 삭제
5. `expandButton()` / `contractButton()` → 1뷰 scale 방식으로 변경

```swift
// === 변경: expandButton() ===
private func expandButton(animated: Bool) {
    let duration: TimeInterval = animated ? 0.4 : 0
    UIView.animate(
        withDuration: duration,
        delay: 0,
        usingSpringWithDamping: 0.6,
        initialSpringVelocity: 0,
        options: .beginFromCurrentState
    ) {
        self.contractedView.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
    }
}

// === 변경: contractButton() ===
private func contractButton(animated: Bool) {
    let duration: TimeInterval = animated ? 0.6 : 0
    UIView.animate(
        withDuration: duration,
        delay: 0,
        usingSpringWithDamping: 0.7,
        initialSpringVelocity: 0,
        options: .beginFromCurrentState
    ) {
        self.contractedView.transform = .identity
    }
}
```

> scale 값 1.08은 기존 1.15(확대 후 사라짐)보다 작게 설정.
> 크로스페이드 없이 단일 뷰가 살짝 커지는 것이므로 과한 확대는 부자연스러움.
> 테스트 후 1.05~1.12 범위에서 조정 가능.

### 파일별 추가 변경

**GlassTextButton.swift** — colorOverlay 삽입 위치 변경:
```swift
// 변경 전: insertSubview(colorOverlay, aboveSubview: expandedView)
// 변경 후: insertSubview(colorOverlay, aboveSubview: contractedView)
```

**GlassCircleButton.swift** — backgroundAlpha 단순화:
```swift
// 변경 전: 두 뷰의 alpha를 isExpanded 상태에 따라 분기
var backgroundAlpha: CGFloat = 1.0 {
    didSet {
        contractedView.alpha = isExpanded ? 0 : backgroundAlpha
        expandedView.alpha = isExpanded ? backgroundAlpha : 0
    }
}

// 변경 후: 단일 뷰 alpha만 관리
var backgroundAlpha: CGFloat = 1.0 {
    didSet {
        contractedView.alpha = backgroundAlpha
    }
}
```

**GlassButton.swift** — bringSubviewToFront 유지:
```swift
// layoutSubviews()에서 기존 코드 유지 (expandedView 삭제와 무관)
if let imageView = imageView {
    bringSubviewToFront(imageView)
}
if let titleLabel = titleLabel {
    bringSubviewToFront(titleLabel)
}
```

**GlassIconButton.swift** — 추가 변경 없음 (공통 변경만 적용)

**예상 결과**:
- MTKView 생성 수: 버튼당 2개 → 1개 (전체 최대 8개 → 4개)
- 초기화 시간 감소 (Metal 셋업 절반)
- 메모리 감소 (CAMetalLayer 텍스처 절반)
- 런타임 GPU: expanded MTKView 렌더링 완전 제거

**테스트**:
- `logMTKViewStatus` 진단 로그로 총 MTKView 수 감소 확인
- 버튼 터치 시 scale 애니메이션이 자연스러운지 시각 확인
- scale 값 미세 조정 (1.05, 1.08, 1.10, 1.12 등 비교)

---

## Phase 1.1 (폴백): expandedView 평소 pause

> **Phase 1에서 시각적 문제가 발생할 경우에만 적용.**
> Phase 1이 성공하면 Phase 1.1은 불필요 (expandedView 자체가 없으므로).

**대상 파일**: Phase 1과 동일 (4개)

**변경 내용**: 2뷰 구조를 유지하되, expandedView 내부 MTKView를 평소 pause

1. `layoutSubviews()`에서 최초 1회: expandedView 내부 MTKView 찾아서 `isPaused = true` 설정
2. `expandButton()` (touchesBegan): `isPaused = false`
3. `contractButton()` (touchesEnded/Cancelled): `isPaused = true`

```swift
private var hasInitializedExpandedPause = false

// layoutSubviews()에 추가
if !hasInitializedExpandedPause {
    let mtkViews = LiquidGlassOptimizer.findAllMTKViews(in: expandedView)
    if !mtkViews.isEmpty {
        LiquidGlassOptimizer.setMTKViewsPaused(true, in: expandedView)
        hasInitializedExpandedPause = true
    }
}

// expandButton(): LiquidGlassOptimizer.setMTKViewsPaused(false, in: expandedView)
// contractButton(): LiquidGlassOptimizer.setMTKViewsPaused(true, in: expandedView)
```

**예상 결과**: expanded MTKView pause (hidden 버튼 포함 최대 -4개, 생성 비용은 그대로)

---

## Phase 2: SelectionPill resting 시 pause

**대상 파일**:
- `PickPhoto/PickPhoto/Shared/Components/LiquidGlassSelectionPill.swift`

**변경 내용**: LiquidLensView 내부 MTKView를 resting/lifted 상태에 따라 제어

1. `layoutSubviews()`에서 최초 1회: lensView 내부 MTKView `isPaused = true`
2. `moveTo(button:animated:)` — lifted 전: `isPaused = false`
3. lifted → resting 완료 시: `isPaused = true`

```swift
// 기존의 completion: nil을 completion 클로저로 변경
func moveTo(button: UIView, animated: Bool) {
    button.superview?.layoutIfNeeded()
    let newLeading = button.frame.origin.x

    if animated {
        // lifted 전 MTKView 활성화
        LiquidGlassOptimizer.setMTKViewsPaused(false, in: lensView)

        lensView.setLifted(true, animated: true, alongsideAnimations: {
            self.leadingConstraint?.constant = newLeading
            self.superview?.layoutIfNeeded()
        }, completion: { _ in
            self.lensView.setLifted(false, animated: true,
                                    alongsideAnimations: nil,
                                    completion: { _ in
                // resting 복귀 완료 후 pause
                LiquidGlassOptimizer.setMTKViewsPaused(true, in: self.lensView)
            })
        })
    } else {
        // 비애니메이션 이동: pause 상태에서 위치만 변경 후 1프레임 렌더링
        LiquidGlassOptimizer.setMTKViewsPaused(false, in: lensView)
        leadingConstraint?.constant = newLeading
        superview?.layoutIfNeeded()
        // 다음 런루프에서 1프레임 렌더 후 다시 pause
        DispatchQueue.main.async {
            LiquidGlassOptimizer.setMTKViewsPaused(true, in: self.lensView)
        }
    }
}
```

**예상 결과**: SelectionPill MTKView 1개 추가 pause

**테스트**:
- 탭 전환 시 Pill squash/stretch 효과 정상 확인
- 전환 완료 후 진단 로그에서 pause 확인
- 연속 빠른 탭 전환 시 문제 없는지 확인

---

## Phase 3: preferredFramesPerSecond 제한

**대상 파일**:
- `PickPhoto/PickPhoto/Debug/LiquidGlassOptimizer.swift`

**변경 내용**: 활성 MTKView의 fps를 30으로 제한

```swift
static var preferredFPS: Int = 30

/// 모든 MTKView에 fps 제한 적용
static func applyFPSLimit(in rootView: UIView?) {
    guard let rootView = rootView else { return }
    for mtkView in findAllMTKViews(in: rootView) {
        mtkView.preferredFramesPerSecond = preferredFPS
    }
}
```

**호출 시점**:
- 기존 `preload(in:)` 내에서 새 MTKView 발견 시 fps 적용
- 또는 각 VC의 `viewDidAppear()`에서 1회 호출

> **Phase 3 + Phase 4 관계**: Phase 4에서 idle 시 전부 pause하면 Phase 3의 fps 제한은
> "restore → enterIdle 사이의 짧은 구간(~0.4초)"에만 적용됨.
> 따라서 **Phase 3을 먼저 독립 테스트**하고, 그 다음 Phase 4를 적용해야 각각의 효과를 확인 가능.

**예상 결과**: active MTKView의 GPU 작업량 50~75% 감소 (60fps 기기: 50%, 120fps 기기: 75%)

**테스트**:
- Glass 효과 시각적 품질 확인 (30fps에서 배경 갱신이 부자연스럽지 않은지)
- Instruments Metal System Trace로 GPU 사용량 Before/After 비교
- fps 값을 조절하면서 품질/성능 트레이드오프 확인 (30, 24, 15 등)

---

## Phase 4: 정지 시 전체 pause

**대상 파일**:
- `PickPhoto/PickPhoto/Debug/LiquidGlassOptimizer.swift`
- `PickPhoto/PickPhoto/Features/Grid/GridScroll.swift`
- `PickPhoto/PickPhoto/Features/Grid/GridViewController.swift` (viewDidAppear)
- `PickPhoto/PickPhoto/Features/Albums/AlbumsViewController.swift`
- `PickPhoto/PickPhoto/Features/Albums/TrashAlbumViewController.swift`
- `PickPhoto/PickPhoto/Features/Albums/AlbumGridViewController.swift`
- `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`
- `PickPhoto/PickPhoto/Features/Viewer/PhotoPageViewController.swift`
- `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/PersonPageViewController.swift`

### 핵심 설계: exitIdle()은 불필요

기존 Optimizer.restore()가 이미 MTKView를 resume하므로, 별도 exitIdle()이 필요 없음.

```
정지 → enterIdle() → 모든 MTKView pause (마지막 프레임 유지)
스크롤 시작 → Optimizer.optimize() → blur 대체 (MTKView는 이미 pause 상태 → 중복 pause 무해)
스크롤 종료 → Optimizer.restore() → isPaused=false + 크로스페이드 → 새 프레임 렌더링
            → enterIdle() → 다시 pause
```

스크롤 시작 시 exitIdle()을 호출하면 "resume → 즉시 optimize()가 다시 pause" 무의미한 왕복이 발생.
따라서 **enterIdle()만 구현**하고, resume은 기존 Optimizer.restore()에 위임.

### LiquidGlassOptimizer 변경

```swift
/// idle pause 딜레이 (restore 완료 대기)
/// restore()의 0.15s delay + transitionDuration 0.1s + 렌더링 여유 = 0.4s
private static let idleDelay: TimeInterval = 0.4

/// idle 타이머 (중복 방지)
private static var idleTimer: DispatchWorkItem?

/// 정지 상태 진입 (스크롤/인터랙션 종료 시 호출)
static func enterIdle(in rootView: UIView?) {
    // 기존 타이머 취소 (중복 방지)
    idleTimer?.cancel()

    let workItem = DispatchWorkItem { [weak rootView] in
        guard let rootView = rootView else { return }
        for mtkView in findAllMTKViews(in: rootView) {
            mtkView.isPaused = true
        }
        logMTKViewStatus(in: rootView, label: "Idle 진입")
    }
    idleTimer = workItem
    DispatchQueue.main.asyncAfter(deadline: .now() + idleDelay, execute: workItem)
}

/// idle 타이머 취소 (스크롤 시작 시 호출)
/// MTKView resume은 Optimizer.restore()가 담당하므로 여기서는 타이머만 취소
static func cancelIdleTimer() {
    idleTimer?.cancel()
    idleTimer = nil
}
```

### 호출 위치

**스크롤 시작 시** (각 VC의 scrollViewWillBeginDragging):
```swift
LiquidGlassOptimizer.cancelIdleTimer()  // 진행 중인 idle 타이머 취소
LiquidGlassOptimizer.optimize(in: view.window)  // 기존 코드
```

**스크롤 종료 시** (각 VC의 scrollViewDidEndDecelerating / didEndDragging):
```swift
LiquidGlassOptimizer.restore(in: view.window)  // 기존 코드
LiquidGlassOptimizer.enterIdle(in: view.window)  // 추가
```

**앱 시작 시** (각 VC의 viewDidAppear):
```swift
LiquidGlassOptimizer.preload(in: view.window)  // 기존 코드
LiquidGlassOptimizer.enterIdle(in: view.window)  // 추가 (preload 완료 후 idle)
```

### Optimizer 호출이 있는 전체 VC 목록 (10개)

| VC | preload | optimize | restore | enterIdle 추가 |
|----|---------|----------|---------|---------------|
| GridViewController | viewDidAppear:364 | - | - | viewDidAppear |
| GridScroll | - | scrollDidBegin:78 | scrollDidEnd:139 | scrollDidEnd |
| AlbumsViewController | viewDidAppear:117 | willBeginDragging:549 | didEndDecelerating:555, didEndDragging:562 | viewDidAppear, scroll 종료 |
| TrashAlbumViewController | viewDidAppear:176 | willBeginDragging:620 | didEndDragging:626, didEndDecelerating:631 | viewDidAppear, scroll 종료 |
| AlbumGridViewController | viewDidAppear:130 | willBeginDragging:357 | didEndDragging:363, didEndDecelerating:368 | viewDidAppear, scroll 종료 |
| ViewerViewController | viewDidAppear:311 | willBeginDragging:1393, dismiss:786 | didEndDecelerating:1403, didEndDragging:1415, dismiss취소:803 | viewDidAppear, scroll/dismiss 종료 |
| PhotoPageViewController | - | zoom시작:689, 드래그:744 | zoom완료:715, 드래그종료:766,780 | zoom/드래그 종료 |
| FaceComparisonViewController | viewDidAppear:247 | willBeginDragging:806 | didEndDecelerating:812, didEndDragging:819 | viewDidAppear, scroll 종료 |
| PersonPageViewController | - | willBeginDragging:286 | didEndDecelerating:292, didEndDragging:299 | scroll 종료 |

**예상 결과**: 정지 시 남은 active MTKView → 0개

**테스트**:
- 정지 → 스크롤 전환 시 Glass 배경이 끊김 없이 복원되는지
- 빠른 스크롤 연속 시 idle 타이머 취소/재설정 정상 동작 확인
- 진단 로그로 idle 진입/해제 확인
- **버튼 터치 시**: idle 상태에서 버튼 터치하면 contractedView는 pause 상태이나, scale 애니메이션은 마지막 렌더 프레임 위에서 동작하므로 시각적 문제 없음 (Phase 1 적용 시). Phase 1.1 적용 시에는 expandedView가 resume됨

---

## Phase 5: 툴킷 Metal 리소스 공유

**대상 파일**:
- `LiquidGlassKit/Sources/LiquidGlassKit/LiquidGlassView.swift`
- `LiquidGlassKit/Sources/LiquidGlassKit/LiquidGlassRenderer.swift`

**배경**: LiquidGlassView 인스턴스마다 공유 가능한 Metal 리소스를 독립 생성하고 있음.

| 리소스 | 현재 | 공유 가능? |
|--------|------|-----------|
| MTLDevice | 1개 (싱글톤 공유) | 이미 공유 |
| MTLRenderPipelineState | 1개 (싱글톤 공유) | 이미 공유 |
| MTLCommandQueue | **인스턴스당 1개** | 공유 가능 |
| CVMetalTextureCache | **인스턴스당 1개** | 공유 가능 |
| BackdropView (CABackdropLayer) | 인스턴스당 1개 | 뷰별 필요 (공유 불가) |
| MTLBuffer (uniforms) | 인스턴스당 1개 | 뷰별 필요 (공유 불가) |

**문제**: commandQueue와 CVMetalTextureCache는 스레드 세이프하고 여러 뷰에서 공유 가능한 리소스인데,
각 LiquidGlassView의 `setupMetal()`에서 매번 새로 생성함. 뷰가 N개면 N개의 주방을 차리는 셈.

**변경 내용**: LiquidGlassRenderer 싱글톤에 공유 리소스 추가

```swift
// LiquidGlassRenderer.swift (기존 싱글톤)
class LiquidGlassRenderer {
    static let shared = LiquidGlassRenderer()

    let device: MTLDevice
    let pipelineState: MTLRenderPipelineState

    // === 추가 ===
    let commandQueue: MTLCommandQueue        // 전체 공유
    let textureCache: CVMetalTextureCache    // 전체 공유

    private init() {
        device = MTLCreateSystemDefaultDevice()!
        // ... pipelineState 셋업 ...
        commandQueue = device.makeCommandQueue()!

        var cache: CVMetalTextureCache?
        CVMetalTextureCacheCreate(nil, nil, device, nil, &cache)
        textureCache = cache!
    }
}
```

```swift
// LiquidGlassView.swift — setupMetal() 변경
func setupMetal() {
    // 변경 전: 인스턴스마다 생성
    // commandQueue = device.makeCommandQueue()!
    // zeroCopyBridge = .init(device: device)

    // 변경 후: 싱글톤에서 가져옴
    commandQueue = LiquidGlassRenderer.shared.commandQueue
    zeroCopyBridge = .init(cache: LiquidGlassRenderer.shared.textureCache)

    // uniformsBuffer는 뷰별 파라미터이므로 그대로 유지
    uniformsBuffer = device.makeBuffer(length: ...)!
}
```

> **주의**: 포크 라이브러리(`karlseedev/LiquidGlassKit`) 소스 수정이므로,
> 앱 코드만 수정하는 Phase 1~4와 달리 라이브러리 빌드/테스트 범위가 다름.
> Phase 1~4 적용 후 cold start가 여전히 문제일 때 진행.

**예상 결과**:
- cold start 시 Metal 리소스 생성 횟수: N회 → 1회 (commandQueue, CVMetalTextureCache)
- 뷰 수와 무관하게 초기화 비용 일정
- 런타임 메모리 감소

**테스트**:
- cold start 시간 Before/After 비교 (Instruments Time Profiler)
- Glass 효과 시각적 품질 확인 (공유 commandQueue에서 렌더링 정상 동작)
- 여러 뷰 동시 렌더링 시 경합 문제 없는지 확인 (버튼 터치 + 스크롤 동시)
- 메모리 사용량 Before/After 비교

---

## 최종 예상 결과

| Phase | MTKView 수 | 변화 |
|-------|-----------|------|
| 적용 전 | 최대 8개 (진단 로그로 확인) | — |
| Phase 1 | **최대 4개** (expanded 제거) | 생성 자체를 절반으로 줄임 |
| Phase 1.1 (폴백) | 동일 8개, pause -4개 | Phase 1 실패 시만 적용 |
| Phase 2 | -1 | Pill pause |
| Phase 3 | 동일 (30fps 제한) | GPU 작업량 감소 |
| Phase 4 | **active 0개** | 전체 idle pause |
| Phase 5 | 동일 | 뷰당 초기화 비용 감소 (Metal 리소스 공유) |

## 수정 파일 목록

| 파일 | Phase |
|------|-------|
| `Debug/LiquidGlassOptimizer.swift` | 사전, 3, 4 |
| `Shared/Components/GlassIconButton.swift` | 1 (또는 1.1) |
| `Shared/Components/GlassTextButton.swift` | 1 (또는 1.1) |
| `Shared/Components/GlassCircleButton.swift` | 1 (또는 1.1) |
| `Shared/Components/GlassButton.swift` | 1 (또는 1.1) |
| `Shared/Components/LiquidGlassSelectionPill.swift` | 2 |
| `Features/Grid/GridScroll.swift` | 4 |
| `Features/Grid/GridViewController.swift` | 4 |
| `Features/Albums/AlbumsViewController.swift` | 4 |
| `Features/Albums/TrashAlbumViewController.swift` | 4 |
| `Features/Albums/AlbumGridViewController.swift` | 4 |
| `Features/Viewer/ViewerViewController.swift` | 4 |
| `Features/Viewer/PhotoPageViewController.swift` | 4 |
| `Features/SimilarPhoto/UI/FaceComparisonViewController.swift` | 4 |
| `Features/SimilarPhoto/UI/PersonPageViewController.swift` | 4 |
| `LiquidGlassKit/.../LiquidGlassView.swift` | 5 |
| `LiquidGlassKit/.../LiquidGlassRenderer.swift` | 5 |

## 검증 방법

1. **진단 로그**: 각 Phase 적용 후 `logMTKViewStatus` 로그에서 active/paused 수 확인
2. **시각 검증**: Glass 효과가 필요한 순간(터치, 탭 전환, 스크롤)에 정상 동작 확인
3. **Instruments**: Metal System Trace로 GPU 사용량 Before/After 비교
4. **hidden 버튼 확인**: 사전 진단 로그에서 hidden 버튼의 MTKView가 실제 active인지 확인 → 현황 표 보정
5. **Phase 1 시각 검증**: 1뷰 scale 애니메이션이 기존 2뷰 크로스페이드 대비 자연스러운지 확인. 문제 시 Phase 1.1로 폴백

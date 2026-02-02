# LiquidGlass MTKView 최적화 계획

> **선행 문서**: [260130gridPerfor.md](260130gridPerfor.md) — 유사사진 분석 성능 저하 조사
> 해당 문서의 **대안 B (Metal 경량화)** 구현 계획. 대안 A (점진적 결과 표시)는 [260131perfo_UI.md](similar/260131perfo_UI.md).

## 목표

유사사진 분석 시 LiquidGlassKit MTKView의 Metal 메모리가 PHCachingImageManager 캐시와 경쟁하여 분석 속도 2~5배 저하.
MTKView의 불필요한 GPU 렌더링과 Metal 리소스를 줄여 캐시 경쟁을 완화하고 분석 성능을 회복.
각 Phase를 **1개씩 순차 적용 + 테스트**하여 효과를 수치로 확인.

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

### Phase 1 테스트 결과 ✅

**시각 검증**: scale 1.15 적용. 기존 2뷰 크로스페이드 대비 품질 차이 미미. Phase 1.1 폴백 불필요.

**성능 측정** (선행 문서 260130gridPerfor.md와 동일 3개 화면):

| | 기존 HEAD | **Phase 1** | Phase 1 개선 | pause 유지 (실험3) | 과거 (8563973) |
|---|---|---|---|---|---|
| **#1** FP Gen (콜드) | 766ms | **507ms** | **-34%** | 834ms | 330ms |
| **#1** Total | 1,972ms | **1,928ms** | -2% | 2,053ms | 1,159ms |
| **#2** FP Gen (웜) | 688ms | **216ms** | **-69%** | 183ms | 170ms |
| **#2** Total | 2,220ms | **1,113ms** | **-50%** | 829ms | 376ms |
| **#3** FP Gen (웜) | 732ms | **199ms** | **-73%** | 207ms | 179ms |
| **#3** Total | 3,177ms | **1,819ms** | **-43%** | 1,295ms | 601ms |

| | Memory Start | Memory End | Delta |
|---|---|---|---|
| #1 | 171.4MB | 231.2MB | +59.9MB |
| #2 | 255.1MB | 228.5MB | -26.6MB |
| #3 | 211.5MB | 208.1MB | -3.5MB |

**핵심 발견**:
1. **웜 캐시 FP가 과거 수준으로 회복**: 216ms/199ms vs 과거 170ms/179ms
2. **pause 유지 실험과 FP가 거의 동일**: expandedView 제거만으로 pause 유지와 동등한 효과
3. **콜드 FP도 34% 개선**: 766ms → 507ms
4. **Total은 아직 과거보다 느림**: Face Detect+Match가 지배적 (Phase 4 idle pause로 추가 개선 가능)
5. **Phase 1.1(폴백) 불필요**: Phase 1만으로 FP 캐시 경쟁 사실상 해소

---

## Phase 1.1 (폴백): expandedView 평소 pause

> **Phase 1 테스트 결과 시각적/성능적으로 모두 성공하여 Phase 1.1은 불필요.**
> 아래는 참고용으로 보존.

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

### Phase 2 테스트 결과 ❌ 롤백 (2차 검증 포함)

**1차 롤백 사유**: 탭 전환 시 Pill이 이전 배경을 가진 채 이동하는 현상 발견 → Phase 2 원인으로 판단하여 롤백.

**2차 검증**: 이전 커밋 추적(74ef08f, b0794d9 등)으로 확인한 결과, 해당 현상은 **LiquidLensView 자체의 특성**으로 Phase 2와 무관. Phase 2 재적용 후 성능 측정 실시.

**Phase 2 재적용 성능 (Phase 1+2+3, 3회 평균)**:

| | Phase 1+3 | Phase 1+2+3 | 차이 |
|---|---|---|---|
| #1 FP (콜드) | 394ms | 375ms | -5% |
| #2 FP (웜) | 182ms | 194ms | +7% |
| #3 FP (웜) | 190ms | 172ms | -10% |
| #1 Total | 1,354ms | 1,306ms | -4% |
| #2 Total | 982ms | 1,025ms | +4% |
| #3 Total | 1,477ms | 1,472ms | -0.3% |

**최종 결론**: 성능 효과는 측정 오차 범위(사실상 0). MTKView 1개 pause 절약으로는 의미 없음. resume 시 1~2프레임 지연 리스크도 존재. Phase 4(정지 시 전체 pause)가 SelectionPill을 포함하여 완전 대체하므로 Phase 2는 불필요. 롤백 확정.

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

### Phase 3 테스트 결과 ✅

**시각 검증**: 정지 상태에서 배경이 변하지 않으므로 30fps 제한의 시각적 차이 없음. 품질 저하 없이 적용 가능.

**성능 측정** (3회 평균):

| | Phase 1 | **Phase 3** | Phase 1→3 개선 | 기존 HEAD | HEAD→3 개선 | 과거 (8563973) |
|---|---|---|---|---|---|---|
| **#1** FP (콜드) | 507ms | **394ms** | **-22%** | 766ms | **-49%** | 330ms |
| **#1** Total | 1,928ms | **1,354ms** | **-30%** | 1,972ms | **-31%** | 1,159ms |
| **#2** FP (웜) | 216ms | **182ms** | -16% | 688ms | **-74%** | 170ms |
| **#2** Total | 1,113ms | **982ms** | -12% | 2,220ms | **-56%** | 376ms |
| **#3** FP (웜) | 199ms | **190ms** | -5% | 732ms | **-74%** | 179ms |
| **#3** Total | 1,819ms | **1,477ms** | **-19%** | 3,177ms | **-54%** | 601ms |

<details>
<summary>3회 개별 측정값</summary>

| | 1회 | 2회 | 3회 |
|---|---|---|---|
| #1 FP | 375ms | 387ms | 419ms |
| #1 Total | 1,296ms | 1,396ms | 1,371ms |
| #2 FP | 196ms | 171ms | 178ms |
| #2 Total | 1,009ms | 955ms | 983ms |
| #3 FP | 199ms | 199ms | 173ms |
| #3 Total | 1,463ms | 1,459ms | 1,508ms |

</details>

**핵심 발견**:
1. **콜드 FP 추가 22% 개선**: 507ms → 394ms, 과거(330ms)에 근접
2. **웜 FP 과거 수준 완전 회복**: 182ms/190ms vs 과거 170ms/179ms
3. **Total도 Phase 1 대비 추가 12~30% 개선**
4. **시각적 품질 저하 없음**: 정지 상태에서 배경 불변이므로 fps 감소가 눈에 보이지 않음

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

### Phase 4 테스트 결과 ✅

**진단 로그 검증**: `[LiquidGlass] Status(Idle): active=0, paused=7, total=7` — 정지 시 **active MTKView 0개** 달성. 매 측정마다 idle 진입 확인.

**시각 검증**: 스크롤 시작/종료 시 Glass 효과 전환 끊김 없음. 탭 전환, 버튼 터치, 뷰어 줌 모두 정상.

**성능 측정** (3회 평균, Phase 1+3+4 누적):

| | Phase 1+3 | **Phase 1+3+4** | Phase 3→4 개선 | 기존 HEAD | HEAD→4 개선 | 과거 (8563973) |
|---|---|---|---|---|---|---|
| **#1** FP (콜드) | 394ms | **376ms** | -5% | 766ms | **-51%** | 330ms |
| **#1** Total | 1,354ms | **1,290ms** | -5% | 1,972ms | **-35%** | 1,159ms |
| **#2** FP (웜) | 182ms | **180ms** | -1% | 688ms | **-74%** | 170ms |
| **#2** Total | 982ms | **776ms** | **-21%** | 2,220ms | **-65%** | 376ms |
| **#3** FP (웜) | 190ms | **169ms** | **-11%** | 732ms | **-77%** | 179ms |
| **#3** Total | 1,477ms | **1,242ms** | **-16%** | 3,177ms | **-61%** | 601ms |

<details>
<summary>3회 개별 측정값</summary>

| | 1회 | 2회 | 3회 |
|---|---|---|---|
| #1 FP | 361ms | 390ms | 378ms |
| #1 Total | 1,265ms | 1,320ms | 1,286ms |
| #2 FP | 171ms | 183ms | 185ms |
| #2 Total | 679ms | 823ms | 826ms |
| #3 FP | 169ms | 168ms | 169ms |
| #3 Total | 1,242ms | 1,243ms | 1,242ms |

</details>

**핵심 발견**:
1. **정지 시 active MTKView 0개**: GPU idle 상태 달성
2. **#3 FP 11% 추가 개선**: 190ms → 169ms, 과거(179ms)보다 빠름
3. **#2 Total 21% 추가 개선**: 982ms → 776ms, 반복 분석 시 메모리 경쟁 완화 효과
4. **콜드 FP는 소폭 개선(-5%)**: idle pause의 주 효과는 반복 분석에서 나타남
5. **사용자 경험 변화 없음**: 정지 시 마지막 프레임 유지, 스크롤 시 blur 전환으로 자연스러운 복원

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

## Phase 6: hidden 버튼 Glass 효과 Lazy 생성 ✅ 완료

**배경**: 진단 로그(`total=8`)에서 hidden 상태인 버튼 5개가 불필요하게 MTKView를 생성하고 있음을 확인.

| # | 컴포넌트 | 평상시 | MTKView |
|---|---------|--------|---------|
| #0 | 상단 backButton (GlassIconButton) | **hidden** | 불필요 |
| #1 | 상단 selectButton (GlassTextButton) | 보임 | 필요 |
| #2 | 상단 secondRightButton "정리" (GlassTextButton) | 보임 | 필요 |
| #3 | 탭바 Platter 배경 (LiquidGlassPlatter) | 보임 | 필요 |
| #4 | 탭바 SelectionPill (LiquidLensView) | **hidden** | 불필요 |
| #5 | 탭바 deleteButton (GlassTextButton, select 모드) | **hidden** | 불필요 |
| #6 | 탭바 trashRestoreButton (GlassTextButton, select 모드) | **hidden** | 불필요 |
| #7 | 탭바 trashDeleteButton (GlassTextButton, select 모드) | **hidden** | 불필요 |

**대상 파일 (5개)**:
- `Shared/Components/GlassTextButton.swift` (#5, #6, #7)
- `Shared/Components/GlassIconButton.swift` (#0)
- `Shared/Components/FloatingTitleBar.swift` (backButton 호출 측)
- `Shared/Components/LiquidGlassTabBar.swift` (select 모드 버튼 호출 측)
- `Shared/Components/LiquidGlassSelectionPill.swift` (#4)

### 핵심 위험: layoutSubviews() lazy 트리거

`glassView`는 `private lazy var`인데, `layoutSubviews()`에서 `glassView.bounds = ...`로 접근하면 lazy 초기화가 발동하여 MTKView가 생성됨. 단순히 `setupLayers()`를 스킵하는 것만으로는 불충분 — `layoutSubviews()`에서도 조건부로 스킵해야 함.

### 변경 내용

**GlassTextButton / GlassIconButton 공통:**

1. `deferGlassEffect` init 파라미터 추가 (기본값 false)
2. `glassViewSetupDeferred` 플래그
3. `setupLayers()` — deferred면 glassView 삽입 스킵
4. `layoutSubviews()` — deferred면 glassView 접근 스킵 (lazy 트리거 방지)
5. `setupGlassEffectIfNeeded()` public 메서드 — 보일 때 호출
6. `isHidden` didSet — visible로 변경 시 자동 생성

```swift
// 프로퍼티
private var glassViewSetupDeferred = false

// setupLayers()
if !glassViewSetupDeferred {
    insertSubview(glassView, at: 0)
}

// layoutSubviews()
if !glassViewSetupDeferred {
    glassView.bounds = CGRect(origin: .zero, size: bounds.size)
    // ...
}

// public
func setupGlassEffectIfNeeded() {
    guard glassViewSetupDeferred else { return }
    glassViewSetupDeferred = false
    insertSubview(glassView, at: 0)
    setNeedsLayout()
}

// isHidden didSet (직접 hidden 제어 버튼용)
override var isHidden: Bool {
    didSet {
        if !isHidden && glassViewSetupDeferred {
            setupGlassEffectIfNeeded()
        }
    }
}
```

**FloatingTitleBar:**
- `backButton` 생성 시 `deferGlassEffect: true` → `isHidden = false` 시 자동 생성

**LiquidGlassTabBar:**
- `deleteButton`, `trashRestoreButton`, `trashDeleteButton`에 `deferGlassEffect: true`
- 컨테이너 기반 hidden이라 isHidden didSet 안 타므로 `enterSelectMode()` / `enterTrashSelectMode()`에서 명시적 `setupGlassEffectIfNeeded()` 호출

**예상 결과**: MTKView 8개 → **3개** (63% 절약, Metal 텍스처/버퍼 메모리 감소)

### Phase 6 Baseline (구현 전, blur 대체 ON 상태)

**스크롤 히치 측정** (Phase 1+3+4 누적, blurReplacement 모드):

| 구간 | Hitch Ratio | 등급 | FPS | Dropped | Longest |
|------|-------------|------|-----|---------|---------|
| L1 First | 0.1 ms/s | Good | 119.2 | 0 | 0 |
| L2 Steady #1 | 0.0 ms/s | Good | 118.1 | 0 | 0 |
| L2 Steady #2 | 0.0 ms/s | Good | 119.4 | 0 | 0 |

> 현재 blur 대체 상태에서 히치 없음 (120fps 기기에서 ~119fps 유지).

**스크롤 히치 측정** (blur OFF, normal 모드 — MTKView 8개 active):

| 구간 | Hitch Ratio | 등급 | FPS | Dropped | Longest |
|------|-------------|------|-----|---------|---------|
| L1 First | 648.7 ms/s | **Critical** | 38.7 | 95 | 39 (325ms) |
| L2 Steady #1 | 583.2 ms/s | **Critical** | 48.7 | 121 | 12 (100ms) |
| L2 Steady #2 | 550.5 ms/s | **Critical** | 52.1 | 78 | 12 (100ms) |

> **blur OFF 시 심각한 성능 저하**: 120fps → 38~52fps, 히치 550~650 ms/s.
> MTKView 8개 active 상태에서는 스크롤 사용 불가 수준.

**Phase 6 시뮬레이션** (blur OFF, hidden MTKView pause — 3개만 active):

| 구간 | Hitch Ratio | 등급 | FPS | Dropped | Longest |
|------|-------------|------|-----|---------|---------|
| L1 First | 292.1 ms/s | **Critical** | 83.8 | 42 | 9 (75ms) |

> Phase6 sim 로그: `resumed=3, skipped=4, total=7`
> 8개→3개로 히치 55% 감소, FPS 2배이지만 여전히 Critical (292 ms/s).
> **결론: Phase 6만으로는 blur 제거 불가. 라이브러리 렌더링 파이프라인 최적화 필요.**
> Phase 6은 blur 제거가 아닌 **메모리/리소스 절약 + 유사사진 분석 성능 개선** 목적으로 진행.

**테스트**:
- idle 진단 로그에서 `total=3` 확인
- backButton 표시/숨김 정상 동작
- select 모드 진입 시 Glass 버튼 정상 표시
- trash select 모드 복구/삭제 버튼 정상 표시
- 탭 전환 시 SelectionPill squash/stretch 정상 동작

### Phase 6 테스트 결과 ✅

**진단 로그 검증**: `[LiquidGlass] Status(Idle): active=0, paused=4, total=4` (첫 idle) → 스크롤 후 `total=3`. 기존 8개에서 **4~3개**로 감소. hidden 버튼 4개(backButton, deleteButton, trashRestoreButton, trashDeleteButton)의 MTKView 생성 차단 확인.

**시각 검증**: 스크롤 성능 변화 없음. blur 대체 모드 정상 동작.

**스크롤 히치 측정** (Phase 1+3+4+6 누적, blurReplacement 모드, 3회 평균):

| 구간 | Hitch Ratio | 등급 | FPS | Dropped | Longest |
|------|-------------|------|-----|---------|---------|
| L1 First | 0.0 ms/s | Good | 119.2 | 0 | 0 |
| L2 Steady | 0.0 ms/s | Good | 119.7 | 0 | 0 |

> Baseline(Phase 1+3+4) 대비 동일 Good 등급 유지. MTKView 감소가 blur 모드 성능에 영향 없음.

**유사사진 분석 성능** (Phase 1+3+4+6 누적, 3회 평균):

| | Phase 1+3+4 | **Phase 1+3+4+6** | Phase 4→6 개선 | 기존 HEAD | HEAD→6 개선 | 과거 (8563973) |
|---|---|---|---|---|---|---|
| **#1** FP (콜드) | 376ms | **340ms** | **-10%** | 766ms | **-56%** | 330ms |
| **#1** Total | 1,290ms | **1,268ms** | -2% | 1,972ms | **-36%** | 1,159ms |
| **#2** FP (웜) | 180ms | **180ms** | 0% | 688ms | **-74%** | 170ms |
| **#2** Total | 776ms | **824ms** | +6% | 2,220ms | **-63%** | 376ms |
| **#3** FP (웜) | 169ms | **169ms** | 0% | 732ms | **-77%** | 179ms |
| **#3** Total | 1,242ms | **1,245ms** | 0% | 3,177ms | **-61%** | 601ms |

<details>
<summary>3회 개별 측정값</summary>

| | 1회 | 2회 | 3회 |
|---|---|---|---|
| #1 FP | 328ms | 342ms | 349ms |
| #1 Total | 1,239ms | 1,271ms | 1,294ms |
| #2 FP | 176ms | 201ms | 164ms |
| #2 Total | 823ms | 985ms | 665ms |
| #3 FP | 171ms | 167ms | 170ms |
| #3 Total | 1,247ms | 1,242ms | 1,245ms |

| | L1 Hitch | L1 FPS | L2 Hitch | L2 FPS |
|---|---|---|---|---|
| 1회 | 0.0 ms/s | 119.4 | 0.0 ms/s | 119.7 |
| 2회 | 0.1 ms/s | 119.1 | 0.0 ms/s | 119.7 |
| 3회 | 0.0 ms/s | 119.1 | 0.0 ms/s | 119.8 |

</details>

**핵심 발견**:
1. **idle MTKView 8→4개 (50% 감소)**: hidden 버튼 4개의 MTKView 생성 완전 차단
2. **콜드 FP 10% 추가 개선**: 376ms → 340ms, **과거(330ms)와 동등 수준 달성**
3. **웜 FP 과거 수준 유지**: 180ms/169ms vs 과거 170ms/179ms
4. **스크롤 성능 영향 없음**: blur 모드에서 0.0ms/s Good, 119fps 유지
5. **메모리 절약**: 4개 MTKView + Metal 텍스처/버퍼 미생성 → 초기 메모리 감소 (정량 미측정)

---

## 최종 예상 결과

| Phase | MTKView 수 | 변화 |
|-------|-----------|------|
| 적용 전 | 최대 8개 (진단 로그로 확인) | — |
| Phase 1 | **최대 4개** (expanded 제거) | 생성 자체를 절반으로 줄임 |
| Phase 1.1 (폴백) | 동일 8개, pause -4개 | Phase 1 실패 시만 적용 |
| ~~Phase 2~~ | ~~-1~~ | ~~Pill pause~~ (롤백: 효과 미미) |
| Phase 3 | 동일 (30fps 제한) | GPU 작업량 감소 |
| Phase 4 | **active 0개** | 전체 idle pause |
| Phase 5 | 동일 | 뷰당 초기화 비용 감소 (Metal 리소스 공유) |
| Phase 6 | **total 3개** | hidden 버튼/Pill lazy 생성 (8→3) |

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
| `Shared/Components/FloatingTitleBar.swift` | 6 |
| `Shared/Components/LiquidGlassTabBar.swift` | 6 |
| `Shared/Components/LiquidGlassSelectionPill.swift` | 6 |

## 검증 방법

1. **진단 로그**: 각 Phase 적용 후 `logMTKViewStatus` 로그에서 active/paused 수 확인
2. **시각 검증**: Glass 효과가 필요한 순간(터치, 탭 전환, 스크롤)에 정상 동작 확인
3. **Instruments**: Metal System Trace로 GPU 사용량 Before/After 비교
4. **hidden 버튼 확인**: 사전 진단 로그에서 hidden 버튼의 MTKView가 실제 active인지 확인 → 현황 표 보정
5. **Phase 1 시각 검증**: 1뷰 scale 애니메이션이 기존 2뷰 크로스페이드 대비 자연스러운지 확인. 문제 시 Phase 1.1로 폴백

# iOS 26 뷰어 시스템 UI 전환 조사

## 해결해야 할 문제

### 최종 목표

**iOS 26에서 아래로 드래그 dismiss를 유지하면서 시스템 UI(네비게이션 바/툴바)를 사용하도록 만들기**

### 왜 현재 안 되는가

```
뷰어가 Modal로 열림
  → navigationController == nil
  → useSystemUI = false
  → 커스텀 GlassIconButton 사용 (시스템 백버튼/툴바 미사용)
```

### Modal을 쓰는 이유

커스텀 줌 트랜지션의 Interactive Dismiss(아래로 드래그 닫기)가 Push에서 실패했기 때문.
Modal의 `shouldRemovePresentersView = false`로 그리드를 containerView에 유지하여 해결함.

### Push에서 실패한 이유 (260129gridZoom1.md)

| 시도 | 방식 | 실패 원인 |
|-----|------|----------|
| 1차 | `UIPercentDrivenInteractiveTransition` + ZoomAnimator | `UIPercentDrivenInteractiveTransition`은 CA 레이어 기반 애니메이션만 가로챔. ZoomAnimator는 스냅샷 UIImageView 기반이라 **호환 안 됨** → 전체 애니메이션이 즉시 실행됨 |
| 2차 | Navigation transition 없이 직접 transform 제어 | `popViewController` 호출 없이 Pan에서 직접 imageView.transform 제어. 그러나 **Navigation push 후 그리드가 window에서 제거**되어 좌표 변환/스냅샷 모두 실패 |

### 근본 원인 요약

**Push에서 Interactive Dismiss를 하려면 두 조건이 동시에 필요:**
1. 그리드(toView)가 window에 존재해야 함 (좌표 변환/스냅샷용)
2. 스냅샷 기반 커스텀 애니메이션을 progress로 제어할 수 있어야 함

- 1차 시도: 조건 1은 충족 (containerView에 양쪽 뷰 존재), 조건 2 실패
- 2차 시도: 조건 2는 충족 (직접 transform 제어), 조건 1 실패

### ~~기존에 검토했으나 부적합한 방법~~ (오판 정정)

| 방법 | 당시 판단 | 정정 |
|------|----------|------|
| `UIViewControllerInteractiveTransitioning` 직접 구현 | ~~1차 시도와 동일한 문제~~ | **오판.** 1차 시도는 `UIPercentDrivenInteractiveTransition`이 `UIView.animate`를 가로채려다 실패한 것. `UIViewControllerInteractiveTransitioning` 직접 구현은 animator를 스킵(`isInteractiveDismiss` 가드)하고 interaction controller가 전담하므로 **메커니즘이 완전히 다름** → **방안 C로 재평가** |
| Custom Container VC | iOS 26 시스템 UI 사용 불가 | 여전히 부적합 |

---

## 해결 방안 조사 결과

목표 달성 조건: **iOS 26에서 Push 사용 + 아래 드래그 dismiss + 시스템 UI**

### 방안 C: Push + 기존 커스텀 InteractionController 재사용 (채택)

현재 코드의 핵심 구조를 그대로 활용하여 Navigation Push/Pop에 적용.

**왜 가능한가 — 현재 코드의 "animator 스킵 + 인터랙터 전담" 구조:**

```swift
// ZoomAnimator.swift:60 — Interactive 시 animator 스킵
guard !isInteractiveDismiss else { return }

// ZoomDismissalInteractionController.swift:20 — 직접 구현 (UIPercentDrivenInteractiveTransition 아님)
final class ZoomDismissalInteractionController: NSObject, UIViewControllerInteractiveTransitioning {
    func startInteractiveTransition(_ transitionContext: ...) {
        // 스냅샷 생성, 배경 배치, 손가락 추적 — 모두 직접 제어
    }
}
```

이 패턴이 Navigation Pop에서도 동작하는 이유:
1. `UINavigationControllerDelegate.interactionControllerFor:`가 커스텀 InteractionController 반환
2. 시스템이 `startInteractiveTransition` 호출 → InteractionController가 전체 제어
3. ZoomAnimator의 `animateTransition`은 `isInteractiveDismiss` 가드로 스킵
4. **1차 실패 원인(UIPercentDrivenInteractiveTransition의 CA 레이어 가로채기)이 발생하지 않음**

**Navigation Pop에서 Modal과의 유일한 차이:**

Modal에서는 `shouldRemovePresentersView = false`로 그리드가 containerView에 유지됨.
Navigation Pop에서는 toView(그리드)를 수동으로 추가해야 함:

```swift
// startInteractiveTransition 내부
containerView.insertSubview(toView, at: 0)
toView.layoutIfNeeded()
// 이후 좌표 변환, 스냅샷 생성 등 기존 로직 동일
```

**동작 흐름:**
```
Pan 시작 → isInteractiveDismiss = true
  → popViewController(animated: true)
  → NavigationControllerDelegate → animationControllerFor: → ZoomAnimator 반환
  → NavigationControllerDelegate → interactionControllerFor: → ZoomDismissalInteractionController 반환
  → ZoomAnimator.animateTransition → isInteractiveDismiss 가드 → 스킵
  → ZoomDismissalInteractionController.startInteractiveTransition → 전담 제어
    → toView(그리드) containerView에 추가 + layoutIfNeeded
    → 스냅샷 생성, 배경 배치
  → Pan changed → 스냅샷 위치/스케일 업데이트 (손가락 추적)
  → Pan ended → finish (셀 위치로 스프링) 또는 cancel (원위치 복귀)
```

**장점:**
- 기존 InteractionController 재사용 (손가락 추적 UX 그대로 유지)
- UIViewPropertyAnimator 재작성 불필요
- Non-interactive Push/Pop은 기존 ZoomAnimator의 UIView.animate 그대로 사용
- 제스처 충돌 해결 (커스텀 Pan 제스처 → gestureRecognizerShouldBegin으로 방향 분리)

**리스크:**

| 리스크 | 위험도 | 내용 | 대응 |
|--------|--------|------|------|
| toView 좌표 변환 | **중** | Pop 시 toView를 containerView에 추가한 뒤 layoutIfNeeded → 셀 접근 가능한지 | PoC 검증. scrollToSourceCell + layoutIfNeeded 패턴 재사용 |
| Non-interactive Pop의 toView 관리 | **중** | 백버튼 Pop 시에도 toView를 containerView에 수동 추가 필요 | ZoomAnimator의 dismiss 경로에 toView 추가 로직 |
| cancel 시 뷰 복원 | **낮** | Navigation transition cancel 시 UIKit이 `completeTransition(false)` 후 뷰 계층 자동 복원 | 수동 제거 불필요 |

---

### 방안 A: UIViewPropertyAnimator 기반 전면 재작성 (백업)

ZoomAnimator를 `UIViewPropertyAnimator` + `interruptibleAnimator(using:)` 기반으로 재작성.
`UIPercentDrivenInteractiveTransition`이 `fractionComplete`를 직접 제어.

**방안 C 대비 단점:**
- Interactive dismiss UX 후퇴: `fractionComplete`는 start↔end 사이 선형 보간 (손가락 추적이 아닌 고정 경로)
- UX를 유지하려면 결국 커스텀 InteractionController를 쓰게 되고, 그러면 UIViewPropertyAnimator를 쓸 이유가 없어짐 (= 방안 C)
- 핵심 리스크(toView 좌표 변환)는 방안 C와 동일 — C가 실패하면 A도 실패

**방안 C가 실패하는 경우에만 의미 있는 시나리오:**
- Navigation Pop에서 커스텀 `UIViewControllerInteractiveTransitioning`이 예상과 다르게 동작하는 경우
- 이 경우 `UIPercentDrivenInteractiveTransition` + `interruptibleAnimator`로 전환 시도

---

### 방안 B: iOS 26 전용 `preferredTransition = .zoom` (부적합 확정)

**검증 결과 (2026-02-08):** iOS 26 실 기기에서 테스트 완료.

| # | 문제 | 심각도 |
|---|------|--------|
| 1 | **UIPageViewController 제스처 충돌** — 사진 넘기려고 스와이프하면 화면이 닫힘 | **치명적** |
| 2 | 배경이 이미지에 붙어서 이동 (페이드인 아님) | 높음 |
| 3 | 배경 페이드인 타이밍 불일치 (iOS 18과 동일) | 높음 |
| 4 | 뒤로가기 후 썸네일 위치 지연 | 중간 |

**참고:** `ZoomOptions.interactiveDismissShouldBegin` API(iOS 18+)로 제스처 방향 분리가 가능할 수 있으나, 시각 품질 문제(2, 3번)는 해결 불가.

→ **확정 부적합.**

---

## 방안 비교

| | 방안 C (InteractionController 재사용) | 방안 A (UIViewPropertyAnimator 재작성) | 방안 B (.zoom API) |
|---|---|---|---|
| **시스템 UI** | O | O | O |
| **아래 드래그 dismiss** | O (손가락 추적) | △ (선형 보간, UX 후퇴) | O (시스템 자동) |
| **제스처 충돌 해결** | O (커스텀 Pan + shouldBegin) | O (동일) | X (치명적) |
| **시각 품질** | O (기존과 동일) | O (동일) | X (배경 타이밍) |
| **핵심 리스크** | toView 좌표 변환 | **동일** + fractionComplete 검증 | 제스처 충돌 |
| **C 실패 시 A로 구제 가능?** | — | **아니오** (동일 리스크) | — |

### 결론

**방안 C 채택.** 방안 A는 C 대비 추가 이점이 없고, C가 실패하는 시나리오에서 A도 동일하게 실패함.

---

## 구현 계획 (방안 C)

### 핵심 설계 결정

**TabBarController 확장 (별도 delegate 클래스 불필요):**
TabBarController가 이미 3개 NavigationController의 delegate를 잡고 있고(80, 95, 109행), `animationControllerFor`/`interactionControllerFor`가 nil 반환 stub으로 존재(324~342행). 별도 `ZoomNavigationTransitionController` 대신 TabBarController에 통합.

### 검증 완료 사항

| 우려 | 결론 | 근거 |
|------|------|------|
| 좌표 변환 불일치? | **안전** | containerView는 전체 화면 + window origin → window 좌표 = container 좌표. `convert(to: nil)`은 뷰 계층 상관없이 window 좌표 반환 |
| cleanup() 순서? | **안전** | `context`가 로컬 변수로 캡처됨 → cleanup()이 transitionContext = nil해도 영향 없음 |
| Z-order? | **정확** | toView[0] → fromView(alpha=0) → background → snapshot 순서. 정상 |
| UIKit 취소 시 뷰 복원? | **자동** | Navigation transition cancel 시 UIKit이 `completeTransition(false)` 후 뷰 계층 자동 복원 |
| BarsVisibilityPolicy? | **정상** | willShow가 Push/Pop 양방향에서 호출됨. ViewerVC `prefersFloatingOverlayHidden = true` 반환. Pop 시 그리드 VC는 기본값(false) 적용 → 자동 복원 |

---

### Phase 1: ZoomAnimator에 transitionMode 추가
> 기존 동작 변경 없음 (기본값 .modal)

**파일:** `Shared/Transitions/ZoomAnimator.swift`

- `TransitionMode` enum 추가 (`.modal` / `.navigation`)
- `var transitionMode: TransitionMode = .modal` 프로퍼티 추가
- 84~94행: dismiss 시 `transitionMode == .navigation`이면 `container.insertSubview(toView, at: 0)` 추가

```swift
if isPresenting {
    if toView.superview != container { container.addSubview(toView) }
} else if transitionMode == .navigation {
    container.insertSubview(toView, at: 0)  // Navigation Pop: 그리드를 container에 추가
}
```

---

### Phase 2: ZoomDismissalInteractionController에 transitionMode 추가
> 기존 동작 변경 없음 (기본값 .modal)

**파일:** `Shared/Transitions/ZoomDismissalInteractionController.swift`

- `var transitionMode: ZoomAnimator.TransitionMode = .modal` 프로퍼티 추가
- `startInteractiveTransition` (66~120행) — `sourceProvider?.scrollToSourceCell()` (83행) 앞에 추가:

```swift
// Navigation Pop: toView(그리드)를 container 맨 뒤에 추가 + finalFrame 설정
// Modal dismiss: shouldRemovePresentersView=false로 이미 window에 있음
if transitionMode == .navigation {
    container.insertSubview(toVC.view, at: 0)
    // ⚠️ finalFrame 명시적 설정 (interactive 경로에서는 ZoomAnimator가 스킵되므로 여기서 설정)
    let finalFrame = transitionContext.finalFrame(for: toVC)
    if !finalFrame.isEmpty {
        toVC.view.frame = finalFrame
    }
}
```

---

### Phase 3: TabBarController에 줌 트랜지션 delegate 확장

**파일:** `Shared/Navigation/TabBarController.swift`

**3-1. 프로퍼티 추가:**
```swift
weak var zoomSourceProvider: ZoomTransitionSourceProviding?
weak var zoomDestinationProvider: ZoomTransitionDestinationProviding?
var zoomInteractionController: ZoomDismissalInteractionController?
var isInteractivelyPopping: Bool = false
```

**3-2. animationControllerFor 수정 (324~333행):**
```swift
// iOS 26+ 줌 트랜지션: Viewer push/pop 시에만
guard #available(iOS 26.0, *) else { return nil }
switch operation {
case .push where toVC is ViewerViewController:
    → ZoomAnimator(isPresenting: true, transitionMode: .navigation)
case .pop where fromVC is ViewerViewController:
    → ZoomAnimator(isPresenting: false, transitionMode: .navigation, isInteractiveDismiss: isInteractivelyPopping)
default: return nil  // Albums push/pop 등은 기본 애니메이션
}
```

**3-3. interactionControllerFor 수정 (337~342행):**
- `isInteractivelyPopping`이면 `zoomInteractionController` 반환

**3-4. didShow 메서드 추가 (willShow가 아닌 didShow 사용):**

> ⚠️ `willShow`는 전환 **시작** 시점에 호출되므로, interactive pop 진행 중에 cleanup하면 `zoomInteractionController`가 nil이 됨. `didShow`는 전환 **완료** 후 호출되므로 안전.

```swift
func navigationController(
    _ navigationController: UINavigationController,
    didShow viewController: UIViewController,
    animated: Bool
) {
    // Pop 완료 후 줌 트랜지션 cleanup (interactive + non-interactive 모두 커버)
    if !(viewController is ViewerViewController) {
        cleanupZoomTransition()
    }
    // Edge swipe back: Viewer에서만 비활성화, 다른 VC에서는 활성화
    navigationController.interactivePopGestureRecognizer?.isEnabled = !(viewController is ViewerViewController)
}
```

**3-5. cleanupZoomTransition() 메서드 추가:**
- zoomSourceProvider, zoomDestinationProvider, zoomInteractionController, isInteractivelyPopping 모두 nil/false

---

### Phase 4: ViewerViewController 수정

**파일:** `Features/Viewer/ViewerViewController.swift`

**4-1.** `isPushed` computed property 추가: `navigationController != nil && presentingViewController == nil`

**4-2.** handleDismissPan (780~826행) — `.began` 분기:
- `isPushed`면: TabBarController에 interaction controller 설정 → `popViewController(animated: true)`
  - `[weak self, weak tbc]` 캡처로 retain cycle 방지
  - cancel 시 `tbc?.zoomInteractionController = nil`
- 아니면: 기존 Modal dismiss 코드 유지
- `.changed`/`.ended`도 `isPushed` 기준으로 분기

**4-3.** dismissWithAnimation/dismissWithFadeOut — `isPushed`면 pop, 아니면 dismiss

**4-4.** viewWillDisappear — `guard isBeingDismissed || isMovingFromParent`

**4-5.** init에 `hidesBottomBarWhenPushed = true`

**4-6.** ~~viewDidAppear/viewWillDisappear에서 interactivePopGestureRecognizer 제어~~ → **Phase 3-4의 `didShow`에서 중앙 관리** (ViewerVC에서는 별도 처리 불필요)

---

### Phase 5: Grid VCs에 iOS 26+ Push 분기 (3개 파일)

**파일:**
- `Features/Grid/GridViewController.swift` (811~823행)
- `Features/Albums/AlbumGridViewController.swift` (341~350행)
- `Features/Albums/TrashAlbumViewController.swift` (577~586행)

모두 동일 패턴:
```swift
if #available(iOS 26.0, *), let tbc = tabBarController as? TabBarController {
    tbc.zoomSourceProvider = self
    tbc.zoomDestinationProvider = viewerVC
    navigationController?.pushViewController(viewerVC, animated: true)
} else {
    // 기존 Modal present 코드 (변경 없음)
}
```

---

### 수정 파일 목록

| 파일 | 변경 내용 | 행 수 (예상) |
|------|----------|-------------|
| `ZoomAnimator.swift` | TransitionMode enum + dismiss 시 toView 추가 | +15 |
| `ZoomDismissalInteractionController.swift` | transitionMode + toView 추가 | +8 |
| `TabBarController.swift` | 줌 트랜지션 프로퍼티 + delegate 확장 + willShow cleanup | +45 |
| `ViewerViewController.swift` | isPushed 분기 + handleDismissPan + dismiss + viewWillDisappear | +55 |
| `GridViewController.swift` | iOS 26 Push 분기 | +10 |
| `AlbumGridViewController.swift` | iOS 26 Push 분기 | +10 |
| `TrashAlbumViewController.swift` | iOS 26 Push 분기 | +10 |

**새 파일 없음.** 기존 7개 파일 수정만으로 구현.

**변경 없음:** `ZoomTransitionProtocol`, `ZoomTransitionController`(Modal용 유지), `ZoomPresentationController`(Modal용 유지)

---

### 핵심 리스크 & 대응

| 리스크 | 위험도 | 대응 |
|--------|--------|------|
| Navigation Pop에서 toView 레이아웃 타이밍 | **중** | `transitionContext.finalFrame(for:)` → toView.frame 설정 + layoutIfNeeded (이미 ZoomAnimator 79~97행에 존재) |
| Retain cycle (onTransitionFinished → TabBarController) | **낮** | `[weak tbc]` 캡처 + cancel 시 nil + willShow cleanup |
| 다른 Navigation 전환에 영향 | **낮** | `.push where toVC is ViewerViewController` / `.pop where fromVC is ViewerViewController`로 한정 |

---

## 참고 자료

| 제목 | URL | 비고 |
|------|-----|------|
| WWDC 2016 - Advances in UIKit Animations | https://asciiwwdc.com/2016/sessions/216 | interruptibleAnimator API 소개 |
| InteractiveNavigationControllerTransition | https://github.com/el-starikova/InteractiveNavigationControllerTransition-UIViewPropertyAnimator | UIViewPropertyAnimator 기반 예제 |
| Christian Selig - Interruptible Transitions | https://christianselig.com/2021/02/interruptible-view-controller-transitions/ | 실전 경험담 |
| Douglas Hill - Zoom Transitions | https://douglashill.co/zoom-transitions/ | iOS 18 zoom transition 분석 |
| Apple - Fluid Transitions | https://developer.apple.com/documentation/uikit/enhancing-your-app-with-fluid-transitions | iOS 18 공식 문서 |
| WWDC24 - UI Animations and Transitions | https://developer.apple.com/videos/play/wwdc2024/10145/ | WWDC 세션 |
| devsign.co - Interactive Pop Transition | https://devsign.co/notes/navigation-transitions-iv | Navigation interactive pop 패턴 |
| Apple - Custom Transitions Guide | https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/CustomizingtheTransitionAnimations.html | 공식 가이드 |
| UIZoomTransitionOptions | https://developer.apple.com/documentation/uikit/uiviewcontroller/transition/zoomoptions | .zoom 옵션 API |

---

## 구현 완료 (2026-02-11)

### 달성 내용

iOS 26+에서 뷰어를 Modal → Navigation Push로 전환 완료.

| | iOS 16~25 | iOS 26+ |
|---|---|---|
| **열기** | Modal present | Navigation push |
| **닫기 (드래그)** | Interactive modal dismiss | Interactive navigation pop |
| **닫기 (버튼)** | dismiss(animated:) | popViewController(animated:) |
| **시스템 UI** | 사용 불가 (커스텀 GlassIconButton) | 네비게이션 바/툴바 사용 가능 |
| **탭바** | Modal이라 탭바 유지 | hidesBottomBarWhenPushed로 숨김 |

- 기존 아래 드래그 Interactive Dismiss UX(손가락 추적, 스냅샷 축소, 배경 fade) 완전 유지
- 드래그 취소(원위치 복귀) 정상 동작
- iOS 16~25 기존 Modal 경로 변경 없음
- 3개 그리드(보관함, 앨범, 휴지통) 모두 적용

### 커밋

- `374ffdf` — feat: Plan C 구현 (Phase 1~5, 7개 파일)
- `e10627e` — fix: interactive dismiss freeze 버그 수정
- `77586d6` — chore: 진단 로그 제거

### 버그 수정: Interactive Dismiss Freeze

**증상:** 뷰어에서 아래 드래그 시 앱 완전 멈춤 (터치 무반응)

**원인:** `popViewController(animated: true)` 호출 즉시 `navigationController`가 `nil`이 됨.
`.changed`/`.ended`에서 `isPushed`가 `false` 반환 → IC가 제스처 업데이트를 못 받음 → `completeTransition` 영원히 호출 안 됨 → UIKit이 터치 이벤트 차단.

**수정:** `activeInteractionController` / `activeTabBarController` 프로퍼티를 `.began`에서 미리 저장하고, `.changed`/`.ended`에서 `isPushed` 재계산 없이 저장된 참조 사용.

### 교훈

- `popViewController(animated: true)` 호출 즉시 `viewControllers` 배열 업데이트 → 팝된 VC의 `navigationController` = `nil`
- Interactive 트랜지션에서 필요한 참조는 `.began`에서 반드시 미리 저장
- Custom `UIViewControllerInteractiveTransitioning` 사용 시 `animateTransition`은 호출되지 않음 (`UIPercentDrivenInteractiveTransition`과 다름)

---

## 관련 문서

- `docs/complete/260129gridZoom1.md` - Push 방식 1차/2차 시도 및 실패 기록
- `docs/complete/260129gridZoom2.md` - Modal 방식 구현 완료 (현재 사용 중)
- `docs/bak/260113gridZoom.md` - `.zoom` API 품질 문제 이력 (8차 시도 후 원복)

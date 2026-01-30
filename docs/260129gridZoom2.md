# 커스텀 줌 트랜지션 구현 계획 (v2 - Modal 방식)

## 배경

Navigation 기반 커스텀 줌 트랜지션(v1)에서 Phase 1-2(기본 Push/Pop 줌)는 완료했으나,
Phase 3(Interactive Dismiss)는 구조적 한계로 구현 불가.

**상세 실패 분석:** `260129gridZoom1.md` 참조

**핵심 문제:**
- Navigation push 후 그리드 view가 window에서 제거됨
- 좌표 변환과 스냅샷 모두 실패

---

## 새로운 접근 방식: Modal Presentation

### 핵심 아이디어

Navigation push 대신 **Custom Modal Presentation** 사용

```swift
// UIPresentationController
override var shouldRemovePresentersView: Bool {
    return false  // ← 핵심! presenting VC(그리드)가 containerView에 유지됨
}
```

**장점:**
- Presenting VC(그리드)가 항상 window에 존재
- 좌표 변환 (`convert(to: nil)`) 정상 작동
- Interactive dismiss 중 그리드 셀 위치 실시간 추적 가능

---

### PoC 검증 결과 (2026-01-30)

**테스트 내용:**
1. `ZoomPresentationController` 생성 (`shouldRemovePresentersView = false`)
2. GridViewController에서 Modal로 뷰어 present
3. Dismiss 시 좌표 변환 테스트

**결과:**
```
[ZoomTransition] PoC 검증: currentIndex=3464, sourceFrame=Optional((0.0, 100.0, 128.0, 128.0))
[ZoomTransition] ✅ PoC 성공! 좌표 변환 정상 작동
```

**핵심 확인:**
- `sourceFrame = (0.0, 100.0, 128.0, 128.0)` ← 실제 좌표 반환!
- 이전 Navigation 방식: `(0.0, 0.0, 128.0, 128.0)` ← 실패

**Modal 방식 유효성 검증 완료**

---

## 목표

### 주요 목표

1. **Navigation push → Modal present로 전환**
   - 그리드 → 뷰어: `present()` 사용
   - 뷰어 → 그리드: `dismiss()` 사용

2. **기본 사진 앱과 동일한 Interactive Dismiss 구현**
   - 아래로 드래그하면 이미지가 축소되면서 손가락을 따라감
   - 배경에 그리드가 보이면서 투명해짐
   - 손 떼면 현재 보고 있는 사진의 셀 위치로 줌 아웃

3. **기존 Phase 1-2 코드 최대한 재사용**
   - `ZoomTransitionProtocol.swift` → 그대로 사용
   - `ZoomAnimator.swift` → 약간 수정 (isPush → isPresenting)
   - `ZoomTransitionController.swift` → 전면 재작성 (UIViewControllerTransitioningDelegate)

4. **iOS 16+ 전 버전에서 동일하게 적용**
   - iOS 18의 `preferredTransition = .zoom` 완전 제거

### 변경 범위

| 구분 | 파일 | 작업 |
|-----|-----|-----|
| 재사용 | `ZoomTransitionProtocol.swift` | 그대로 |
| 수정 | `ZoomAnimator.swift` | isPush → isPresenting |
| 재작성 | `ZoomTransitionController.swift` | Navigation → Modal delegate |
| 신규 | `ZoomPresentationController.swift` | shouldRemovePresentersView = false |
| 신규 | `ZoomInteractionController.swift` | Interactive dismiss |
| 수정 | `GridViewController.swift` 등 | push → present |
| 수정 | `ViewerViewController.swift` | pop → dismiss, 커스텀 닫기 버튼 |
| 제거 | `TabBarController.swift` | Navigation delegate에서 줌 관련 코드 제거 |

### 검증 기준

1. **좌우 스와이프**: 뷰어에서 사진 전환 정상 동작
2. **Back 버튼**: 커스텀 버튼으로 뷰어 닫기
3. **Interactive Dismiss**: 아래 드래그로 줌 아웃 + 그리드 복귀
4. **실시간 셀 추적**: 뷰어에서 10장 넘긴 후 dismiss → 현재 사진의 셀로 복귀
5. **Fallback**: 셀이 화면 밖일 때 crossfade

---

## 참고 자료

### 공식 문서
- [Apple - UIPresentationController](https://developer.apple.com/documentation/uikit/uipresentationcontroller)
- [Apple - shouldRemovePresentersView](https://developer.apple.com/documentation/uikit/uipresentationcontroller/shouldremovepresentersview)
- [Apple - UIViewControllerTransitioningDelegate](https://developer.apple.com/documentation/uikit/uiviewcontrollertransitioningdelegate)

### 블로그 및 튜토리얼
- [Daniel Gauthier - Mastering view controller transitions](https://danielgauthier.me/2020/02/27/vctransitions2.html)
- [Kodeco - UIPresentationController Tutorial](https://www.kodeco.com/3636807-uipresentationcontroller-tutorial-getting-started)

### 오픈소스
- [SimpleImageViewer](https://github.com/LcTwisk/SimpleImageViewer) - 가장 단순한 구조
- [PhotoZoomAnimator](https://github.com/jhrcook/PhotoZoomAnimator) - 교육용, 코드 이해 쉬움

---

## 구현 계획

### Phase 1: 기반 구조 변경

#### 1-1. ZoomAnimator.swift 수정

- `isPush` → `isPresenting` 이름 변경
- Modal containerView 대응: `finalFrame.isEmpty ? container.bounds : finalFrame` 가드
- 중복 addSubview 방지: `toView.superview != container` 체크

#### 1-2. ZoomTransitionController.swift 전면 재작성

**변경 전:** `UINavigationControllerDelegate` 헬퍼
**변경 후:** `UIViewControllerTransitioningDelegate` 채택

핵심 메서드:
- `animationController(forPresented:)` → ZoomAnimator(isPresenting: true)
- `animationController(forDismissed:)` → ZoomAnimator(isPresenting: false)
- `interactionControllerForDismissal(using:)` → isInteractivelyDismissing일 때만 반환
- `presentationController(forPresented:)` → ZoomPresentationController 반환

#### 1-3. ZoomPresentationController.swift 신규 생성

```swift
final class ZoomPresentationController: UIPresentationController {
    override var shouldRemovePresentersView: Bool { false }  // 핵심!
}
```

#### 1-1~3 검증
- 빌드 성공 확인

---

### Phase 2: 그리드 → 뷰어 전환 적용

#### 2-1. 그리드 3곳: push → present 변경

| 파일 | 라인 |
|-----|------|
| `GridViewController.swift` | :792 |
| `AlbumGridViewController.swift` | :334 |
| `TrashAlbumViewController.swift` | :551 |

각 위치에서:
```swift
// 변경 전
navigationController?.pushViewController(viewerVC, animated: true)

// 변경 후
let transitionController = ZoomTransitionController()
transitionController.sourceProvider = self
transitionController.destinationProvider = viewerVC
viewerVC.zoomTransitionController = transitionController
viewerVC.transitioningDelegate = transitionController
present(viewerVC, animated: true)
```

#### 2-2. ViewerViewController dismiss 경로 수정 (6곳)

모든 `popViewController` → `dismiss(animated: true)`:

| 메서드 | 현재 | 변경 |
|-------|-----|-----|
| `dismissWithAnimation()` | popViewController(animated: false) | dismiss(animated: true) |
| `dismissWithFadeOut()` | popViewController(animated: true/false) | dismiss(animated: true) |
| `dismissViewer()` | iOS 분기 + pop | dismiss(animated: true) |
| `ViewerVC+SimilarPhoto.swift:734` | pop | dismiss(animated: true) |

#### 2-3. BarsVisibilityControlling 수동 적용

Modal에서는 `NavigationControllerDelegate.willShow`가 호출 안 됨.

```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    // FloatingOverlay 숨김
    findTabBarController()?.floatingOverlay?.isHidden = true
}

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    guard isBeingDismissed else { return }  // 취소 시 호출 방지
    findTabBarController()?.floatingOverlay?.isHidden = false
    delegate?.viewerWillClose(currentAssetID: ...)
}
```

#### 2-4. TabBarController 줌 관련 코드 제거

- `zoomTransitionController` 프로퍼티 제거
- `animationControllerFor` 메서드에서 nil 반환
- `interactionControllerFor` 메서드에서 nil 반환
- `BarsVisibilityControlling` willShow 로직은 **유지** (다른 VC에서 사용)

#### 2-5. ViewerViewController 수정

```swift
var zoomTransitionController: ZoomTransitionController?  // 그리드에서 설정 (strong!)

init(...) {
    // ...
    modalPresentationStyle = .custom
    modalPresentationCapturesStatusBarAppearance = true  // 상태바 제어
    // hidesBottomBarWhenPushed 제거 (Modal에서 불필요)
}
```

#### 2-6. useSystemUI 수정 (⚠️ 필수)

**현재:** iOS 26+에서 `useSystemUI = true` → 커스텀 버튼 미생성
**문제:** Modal에서는 navigationController 없으므로 시스템 UI도, 커스텀 버튼도 없는 상태

```swift
// 변경 전
private var useSystemUI: Bool {
    if #available(iOS 26.0, *) { return true }
    return false
}

// 변경 후: Modal에서는 항상 커스텀 버튼 사용
private var useSystemUI: Bool {
    if #available(iOS 26.0, *) {
        return navigationController != nil  // Modal이면 false
    }
    return false
}
```

#### 2-7. 그리드에서 present 시 순서 주의

```swift
// ⚠️ transitioningDelegate는 weak 참조!
// 반드시 strong 참조(zoomTransitionController) 먼저 설정
viewerVC.zoomTransitionController = transitionController  // 1. strong 먼저
viewerVC.transitioningDelegate = transitionController      // 2. weak 나중
present(viewerVC, animated: true)
```

#### 2-8. disableCustomFadeAnimation 제거

- 그리드 3곳에서 `viewerVC.disableCustomFadeAnimation = true` 제거
- `dismissWithFadeOut()`에서 이 플래그 참조 제거
- ViewerViewController에서 프로퍼티 선언 제거

#### Phase 2 검증
- 그리드 사진 탭 → 줌 인으로 뷰어 열림
- Back 버튼 → 줌 아웃으로 닫힘
- 3개 그리드(보관함, 앨범, 휴지통) 모두 확인
- FloatingOverlay 숨김/복원 확인
- 모든 사진 삭제 시 뷰어 닫힘 확인
- **iOS 26+에서 커스텀 버튼(삭제, 복구, 뒤로가기) 정상 표시 확인**
- 상태바 숨김 정상 동작 확인

#### Phase 1-2 검증 결과 (2026-01-30)

**iOS 18 + iOS 26 실기기 테스트 완료**

구현 중 발견된 문제 및 수정:

| 문제 | 원인 | 수정 |
|-----|-----|------|
| dismiss 후 검은 화면 | `shouldRemovePresentersView=false`인데 dismiss 시 toView(그리드)를 container에 insertSubview → container 제거 시 그리드도 사라짐 | dismiss 시 toView를 container에 추가하지 않음 |
| iOS 26에서 멀리 스와이프 후 줌 아웃 안 됨 | `scrollToItem + layoutIfNeeded` 후에도 iOS 26에서 셀이 dequeue 안 됨 → `cellForItem` nil → sourceFrame nil | `layoutAttributesForItem` fallback 추가 (셀 없이도 프레임 계산) |

검증 항목:
- [x] 그리드 → 뷰어 줌 인 (iOS 18, 26)
- [x] 뷰어 → 그리드 줌 아웃 (Back 버튼)
- [x] 뷰어에서 사진 많이 넘긴 후 줌 아웃 → 해당 셀로 복귀
- [x] 3개 그리드 (보관함, 앨범, 휴지통) 모두 정상
- [x] FloatingOverlay 숨김/복원
- [x] iOS 26+ 커스텀 버튼 정상 표시
- [x] iOS 26+ 시스템 UI 분기 기존대로 유지

---

### Phase 3: Interactive Dismiss 구현

#### 3-1. ZoomDismissalInteractionController.swift 신규 생성

**핵심:** `UIViewControllerInteractiveTransitioning` 직접 구현
**절대 사용 안 함:** `UIPercentDrivenInteractiveTransition`

```swift
final class ZoomDismissalInteractionController: NSObject, UIViewControllerInteractiveTransitioning {

    func startInteractiveTransition(_ transitionContext: ...) {
        // 1. containerView에 toView(그리드) + 배경 + 스냅샷 배치
        // 2. 셀이 보이도록 스크롤
        // 3. fromView(뷰어) 숨김
    }

    func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        // .changed: 스냅샷 frame + 배경 alpha 업데이트
        // .ended: shouldComplete → finish/cancel
    }

    func finishInteractiveTransition(velocity:) {
        // 스프링 애니메이션 → 셀 위치로 축소
        // transitionContext.finishInteractiveTransition()
        // transitionContext.completeTransition(true)
    }

    func cancelInteractiveTransition() {
        // 원위치 복귀 애니메이션
        // transitionContext.cancelInteractiveTransition()
        // transitionContext.completeTransition(false)
    }
}
```

#### 3-2. handleDismissPan 교체

```swift
@objc private func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
    switch gesture.state {
    case .began:
        guard !isDismissing else { return }
        isDismissing = true

        guard let tc = zoomTransitionController else {
            dismissWithFadeOut()  // fallback
            return
        }

        // ⚠️ InteractionController 생성 (누락 시 non-interactive dismiss됨)
        let ic = ZoomDismissalInteractionController()
        ic.sourceProvider = tc.sourceProvider
        ic.destinationProvider = tc.destinationProvider
        ic.onTransitionFinished = { [weak self] completed in
            if !completed { self?.isDismissing = false }  // 취소 시 복원
        }
        tc.interactionController = ic
        tc.isInteractivelyDismissing = true

        dismiss(animated: true)

    case .changed:
        zoomTransitionController?.interactionController?.didPanWith(gestureRecognizer: gesture)

    case .ended, .cancelled:
        zoomTransitionController?.interactionController?.didPanWith(gestureRecognizer: gesture)
        zoomTransitionController?.isInteractivelyDismissing = false
    default: break
    }
}
```

#### 3-3. Gesture Delegate 업데이트

줌 상태에서 dismiss 방지:
```swift
func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    guard gestureRecognizer == dismissPanGesture else { return true }
    let velocity = dismissPanGesture.velocity(in: view)
    guard velocity.y > 0 && abs(velocity.y) > abs(velocity.x) else { return false }

    // 줌 상태 체크
    guard let zoomable = pageViewController.viewControllers?.first as? ZoomableImageProviding else { return true }
    guard zoomable.zoomScale <= 1.01 else { return false }
    return zoomable.isAtTopEdge
}
```

#### Phase 3 검증 항목
- 아래 드래그 → 이미지 축소 + 그리드 배경 보임
- 손 떼면 현재 사진의 셀로 줌 아웃
- 드래그 취소 → 원위치 복귀
- 뷰어에서 10장 넘긴 후 dismiss → 정확한 셀로 복귀
- 줌 상태에서 아래 드래그 → dismiss 안 됨 (스크롤 동작)
- 좌우 스와이프 → 사진 전환 정상

#### Phase 3 검증 결과 (2026-01-30)

**기능 동작: 정상**
- [x] 아래 드래그 → 이미지 축소 + 배경 투명 + 그리드 보임
- [x] 손 떼기 → 현재 사진의 셀 위치로 줌 아웃
- [x] 드래그 취소 → 원위치 복귀
- [x] 사진 많이 넘긴 후 드래그 → 정확한 셀로 복귀
- [x] 줌 상태에서 아래 드래그 → dismiss 안 됨 (스크롤 동작)
- [x] 좌우 스와이프 → 사진 전환 정상

**성능 이슈: Interactive dismiss 드래그 부드러움 미흡 (미해결)**

증상: 아래로 드래그 시 스냅샷 이동이 뚝뚝 끊기는 느낌. 측정 결과 gesture `.changed` 콜백이 55-90ms 간격으로 도착 (120Hz 기기에서 8.3ms가 정상).

수정 완료된 항목:
| 수정 | 내용 |
|-----|------|
| `animateTransition` 충돌 방지 | interactive dismiss 시 `animateTransition`이 호출되어 스냅샷 중복 + 스프링 애니메이션 충돌. `isInteractiveDismiss` 자체 플래그로 가드 (`transitionContext.isInteractive`는 호출 시점에 `false`) |

배제된 원인:
| # | 가설 | 테스트 방법 | 결과 (ms 간격) |
|---|-----|-----------|---------------|
| 1 | `animateTransition` 충돌 | `transitionContext.isInteractive` 가드 | 가드 미작동 (호출 시점에 `false`) → 자체 플래그로 대체 |
| 2 | CATransaction implicit animation | `CATransaction.setDisableActions(true)` 래핑 | 차이 없음 (80-90ms) |
| 3 | `updateInteractiveTransition` 시스템 호출 | 해당 줄 주석 처리 | 차이 없음 (80-90ms) |
| 4 | Grid lifecycle/layout | `viewWillAppear`, `viewDidLayoutSubviews`에 로그 추가 | 드래그 중 호출 안 됨 |
| 5 | 이미지 크기 (GPU 부하) | - | 10MB 미만 이미지, 해당 없음 |
| 6 | UIKit `dismiss(animated:true)` transition 시스템 | dismiss 없이 직접 스냅샷 생성/이동 | 80-90ms → 55-75ms (일부 기여하나 주원인 아님) |
| 7 | 로깅 I/O 오버헤드 (Swift.print USB 전송) | `Log.isEnabled=false`로 전체 비활성화 | 차이 없음 (55-75ms) |
| 8 | Debug 빌드 성능 | Release 빌드 체감 테스트 | Release에서도 동일한 끊김 체감 |
| 9 | UIPageViewController 내부 스크롤뷰 제스처 간섭 | `pageScrollView.isScrollEnabled=false` | 차이 없음 (55-70ms) |

측정 환경: iPhone 13 Pro (120Hz ProMotion). 정상 기대값: 8.3ms (120Hz) 또는 16.7ms (60Hz).

측정 요약:
| 조건 | .changed 간격 |
|-----|-------------|
| 원본 (dismiss + transition) | 80-90ms (~12 FPS) |
| dismiss 제거 (직접 스냅샷) | 55-75ms (~16 FPS) |
| dismiss 제거 + 로그 비활성화 | 55-75ms (~16 FPS) |
| dismiss 제거 + 스크롤뷰 비활성화 | 55-70ms (~16 FPS) |

결론: dismiss 제거로 ~20ms 개선되나, 기본 55-75ms 간격은 **ViewerViewController 또는 앱 전체의 main thread 상시 부하**에서 발생. 코드 분석으로 특정 원인을 찾지 못함.

#### 근본 원인 발견 (2026-01-30)

**LiquidGlassKit이 메인 스레드 부하의 근본 원인으로 확인됨.**

비교 테스트:
| 시점 | LiquidGlass | 줌 방식 | 체감 |
|------|------------|---------|------|
| `decb029` (LiquidGlass 적용 전) | 없음 | 시스템 줌 | **매우 부드러움** |
| `acd26ae` (LiquidGlass 적용 후, 커스텀 줌 전) | 있음 | 시스템 줌 | **끊김** |
| 현재 코드 | 있음 | 커스텀 줌 | **끊김** |

테스트 방법: git 히스토리에서 각 시점으로 체크아웃 후 실기기(iPhone 13 Pro)에서 뷰어 dismiss 드래그 체감 비교. 두 시점 모두 동일한 시스템 줌(preferredTransition = .zoom)을 사용하며, LiquidGlass 유무만 다름.

결론: 커스텀 줌 구현이 아니라 **LiquidGlassKit(MTKView 기반 블러 렌더링)이 메인 스레드에 상시 부하**를 주어, gesture callback 빈도가 저하됨. → LiquidGlass 최적화 또는 비활성화로 해결 필요.

#### 코드 정리 완료 (2026-01-30)

진단 테스트 코드 및 로그를 모두 제거하고 Phase 3 정상 코드로 복원:
- `handleDismissPan`: 진단 코드 제거 → Phase 3 interactive dismiss 코드 복원
- `ZoomDismissalInteractionController.swift`: 프레임 간격 측정 진단 로그 제거
- `BaseGridViewController.swift`: 진단 로그 제거
- `GridViewController.swift`: 진단 로그 제거

유지된 유효 수정:
- `ZoomAnimator.swift`: `isInteractiveDismiss` 플래그 + 가드 (유효)
- `ZoomTransitionController.swift`: `isInteractiveDismiss` 설정 (유효)

---

## 잠재적 함정과 해결책

| 함정 | 해결책 |
|-----|-------|
| UIPercentDriven 사용 | UIViewControllerInteractiveTransitioning 직접 구현 |
| completeTransition 누락 | finish/cancel 양쪽 모두 반드시 호출 |
| 취소 후 isDismissing 복원 | onTransitionFinished 콜백으로 복원 |
| viewWillDisappear 중복 호출 | `isBeingDismissed` 체크 |
| finalFrame이 .zero | `container.bounds` 폴백 |
| dismiss 전 .changed 도착 | `transitionContext != nil` 가드 |
| sourceProvider nil | crossfade 폴백 (기존 로직) |
| iOS 26 커스텀 버튼 누락 | `useSystemUI`를 `navigationController != nil` 조건부로 변경 |
| transitioningDelegate weak 해제 | strong 참조(zoomTransitionController) 먼저 설정 |
| 상태바 미적용 | `modalPresentationCapturesStatusBarAppearance = true` |
| disableCustomFadeAnimation 잔존 | Modal에서 불필요, 제거 |

---

## 파일 목록

### 신규 (2개)
| 파일 | 역할 |
|-----|-----|
| `Shared/Transitions/ZoomPresentationController.swift` | shouldRemovePresentersView = false |
| `Shared/Transitions/ZoomDismissalInteractionController.swift` | Interactive dismiss |

### 수정 (8개)
| 파일 | 변경 |
|-----|-----|
| `Shared/Transitions/ZoomAnimator.swift` | isPush → isPresenting |
| `Shared/Transitions/ZoomTransitionController.swift` | 전면 재작성 |
| `Shared/Navigation/TabBarController.swift` | 줌 코드 제거 |
| `Features/Grid/GridViewController.swift` | push → present |
| `Features/Albums/AlbumGridViewController.swift` | push → present |
| `Features/Albums/TrashAlbumViewController.swift` | push → present |
| `Features/Viewer/ViewerViewController.swift` | init, dismiss, handleDismissPan |
| `Features/Viewer/ViewerViewController+SimilarPhoto.swift` | pop → dismiss |

### 변경 없음
| 파일 | 이유 |
|-----|-----|
| `ZoomTransitionProtocol.swift` | 그대로 재사용 |

# Push 기반 Interactive Dismiss 조사 결과

## 배경

현재 뷰어는 Modal로 열리고 있어 iOS 26에서 시스템 네비게이션 바/툴바를 사용할 수 없음.
Modal을 쓰는 이유는 커스텀 줌 트랜지션의 Interactive Dismiss 때문.
Push 방식으로 두 번 시도했으나 실패함 (260129gridZoom1.md 참조).

---

## 이전 실패 원인 정리

| 시도 | 방식 | 실패 원인 |
|-----|------|----------|
| 1차 | `UIPercentDrivenInteractiveTransition` | CA 레이어 애니메이션만 가로챔 → 스냅샷 기반 커스텀 애니메이션(ZoomAnimator) 무시, 전체 애니메이션이 즉시 실행됨 |
| 2차 | Navigation 없이 직접 transform 제어 | `popViewController` 호출 없이 하면 그리드가 window에 없음 → 좌표 변환/스냅샷 실패 |

---

## 해결 방법: `UIViewControllerInteractiveTransitioning` 직접 구현

**핵심: `UIPercentDrivenInteractiveTransition`을 상속하지 않고, `UIViewControllerInteractiveTransitioning` 프로토콜을 직접 구현**

이 방식은 devsign.co의 Locket Photos 앱 튜토리얼에서 상세히 다루고 있으며, 실제 프로덕션 앱에서 검증된 패턴.

### 동작 흐름

```
1. Pan 시작 → popViewController(animated: true) 호출
2. NavigationControllerDelegate → interactionControllerFor: 호출
   → PhotoDetailInteractiveDismissTransition 반환
3. 시스템이 startInteractiveTransition(_:) 호출
   → containerView에 toView(그리드) + fromView(뷰어) 모두 배치됨  ← 핵심!
4. Pan changed → transitionImageView.transform 직접 제어
                → backgroundAnimation.fractionComplete 직접 제어
5. Pan ended → finish() 또는 cancel()
```

### 왜 이전 실패를 해결하는가

- **`startInteractiveTransition`이 호출되면 시스템이 `containerView`에 fromView/toView를 모두 준비**함
- 그래서 그리드(toView)가 window에 존재 → 좌표 변환 성공, 스냅샷 가능
- `animateTransition`은 호출되지 않으므로 `ZoomAnimator`가 전체 애니메이션을 즉시 실행하는 문제도 없음

### 구현 구조

```swift
class ZoomInteractiveDismissTransition: NSObject,
    UIViewControllerInteractiveTransitioning,
    UIViewControllerAnimatedTransitioning {

    // UIViewPropertyAnimator로 배경 페이드 제어
    var backgroundAnimation: UIViewPropertyAnimator?
    var transitionImageView: UIImageView  // 줌 스냅샷

    // 시스템이 호출 → containerView 설정
    func startInteractiveTransition(_ transitionContext: ...) {
        let container = transitionContext.containerView
        container.addSubview(toView)    // 그리드 (뒤)
        container.addSubview(fromView)  // 뷰어 (앞)
        container.addSubview(transitionImageView) // 스냅샷 (최상위)
    }

    // Pan gesture가 직접 호출
    func didPan(translation:, progress:) {
        transitionImageView.transform = ...  // 스케일 + 위치
        backgroundAnimation?.fractionComplete = progress
        transitionContext?.updateInteractiveTransition(progress)
    }

    // 완료/취소
    func completeTransition(didCancel: Bool) {
        if didCancel {
            // 원위치 스프링 애니메이션
        } else {
            // 소스 셀로 줌 아웃 → completeTransition(true)
        }
    }
}
```

### containerView 뷰 배치 전략

```
containerView
├── toView (그리드) ← 배경 역할, 투명도 연동
├── fromView (뷰어) ← 페이드 아웃
└── transitionImageView ← 최상단, 손가락 추적
```

- 목적지 뷰(그리드)가 먼저 추가되어 배경 역할
- 출발지 뷰(뷰어)가 그 위에 놓임
- 트랜지션 이미지는 최상단에서 제스처로 움직임
- "뷰어 배경이 투명해지면서 하단 그리드가 드러나는" 효과

### UIViewPropertyAnimator 활용

- 제스처 진행 중: `backgroundAnimation.fractionComplete = progress`
- 완료/취소 시: `continueAnimation(withTimingParameters:durationFactor:)`로 부드럽게 이어감
- Spring 타이밍 파라미터로 자연스러운 모션

### Pan Gesture Progress 제어

**`.changed`**: 이미지에 변환 적용 + progress 보고
```swift
transitionImageView.transform = CGAffineTransform.identity
    .scaledBy(x: scale, y: scale)
    .translatedBy(x: translation.x / scale, y: translation.y / scale)
transitionContext.updateInteractiveTransition(percentageComplete)
```

**`.ended`**: 속도와 progress 임계값으로 완료 여부 판단
```swift
let shouldComplete = fingerIsMovingDownwards && transitionMadeSignificantProgress
self.completeTransition(didCancel: !shouldComplete)
```

---

## 대안 비교

| 방법 | 장점 | 단점 |
|-----|------|------|
| **A. `UIViewControllerInteractiveTransitioning` 직접 구현** | 스냅샷 호환, containerView에 양쪽 뷰 존재, 프로덕션 검증됨 | 코드량 많음 |
| **B. iOS 18+ `preferredTransition = .zoom`** | 코드 최소, interactive dismiss 자동 (pinch/swipe/edge) | iOS 18+ 전용, 커스텀 제어 불가 |
| **C. 현재 Modal 방식 유지** | 이미 동작함 | iOS 26 시스템 UI 사용 불가 |

### iOS 18 `preferredTransition = .zoom` 참고

- Navigation push/pop 모두 interactive dismiss 자동 지원 (iOS 18 beta 2부터)
- 지원 제스처: 핀치 축소, 아래 스와이프, 왼쪽 엣지 스와이프
- gesture recognizer 커스텀 불가 (시스템 자동 설치)
- iOS 26 전용 분기로 다시 사용 가능성 있음

---

## 참고 자료

| 제목 | URL | 비고 |
|------|-----|------|
| devsign.co - Interactive Pop Transition (Part IV) | https://devsign.co/notes/navigation-transitions-iv | 핵심 참고. Locket Photos 앱 구현 |
| devsign.co - Complex Push/Pop Animation (Part III) | https://devsign.co/notes/navigation-transitions-iii | Push/Pop 비인터랙티브 구현 |
| InteractiveNavigationControllerTransition (GitHub) | https://github.com/el-starikova/InteractiveNavigationControllerTransition-UIViewPropertyAnimator | UIViewPropertyAnimator 기반 예제 |
| Douglas Hill - Zoom Transitions | https://douglashill.co/zoom-transitions/ | iOS 18 zoom transition 분석 |
| Apple - Enhancing your app with fluid transitions | https://developer.apple.com/documentation/uikit/enhancing-your-app-with-fluid-transitions | iOS 18 공식 문서 |
| WWDC24 - Enhance your UI animations and transitions | https://developer.apple.com/videos/play/wwdc2024/10145/ | WWDC 세션 |
| tristanhimmelman/ZoomTransition (GitHub) | https://github.com/tristanhimmelman/ZoomTransition | 오픈소스 줌 트랜지션 |
| Masamichi Ueta - Photos app 스타일 구현 | https://medium.com/@masamichiueta/create-transition-and-interaction-like-ios-photos-app-2b9f16313d3 | Navigation 기반 Photos 스타일 |
| objc.io - View Controller Transitions | https://www.objc.io/issues/5-ios7/view-controller-transitions/ | 기초 개념 |
| Apple - Customizing the Transition Animations | https://developer.apple.com/library/archive/featuredarticles/ViewControllerPGforiPhoneOS/CustomizingtheTransitionAnimations.html | 공식 가이드 |

---

## 관련 문서

- `docs/complete/260129gridZoom1.md` - Push 방식 1차/2차 시도 및 실패 기록
- `docs/complete/260129gridZoom2.md` - Modal 방식 구현 완료 (현재 사용 중)

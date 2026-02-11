# Plan C 완료: Modal → Navigation Push (iOS 26+)

**작업일**: 2026-02-11
**커밋**: `374ffdf` (구현) + bugfix (interactive dismiss freeze)

---

## 목적

iOS 26에서 뷰어를 Modal로 열면 `navigationController == nil`이라 시스템 UI(네비게이션 바/툴바)를 사용할 수 없음. Navigation Push로 전환하여 시스템 UI 활용 가능하게 함.

## 변경 요약

| iOS 버전 | 열기 방식 | 닫기 방식 | 시스템 UI |
|---------|----------|----------|---------|
| iOS 16~25 | Modal present | Interactive modal dismiss | 불가 (커스텀) |
| iOS 26+ | Navigation push | Interactive navigation pop | 가능 |

## 수정 파일 (7개)

| 파일 | 변경 내용 |
|------|----------|
| `ZoomAnimator.swift` | `TransitionMode` enum (.modal/.navigation) + navigation pop 시 toView 추가 |
| `ZoomDismissalInteractionController.swift` | `transitionMode` + navigation pop 시 toView+finalFrame 설정 |
| `TabBarController.swift` | zoom transition 프로퍼티 + `animationControllerFor`/`interactionControllerFor` 확장 + `didShow` cleanup |
| `ViewerViewController.swift` | `isPushed` 분기 + `handleDismissPan` Navigation Pop 경로 + dismiss 메서드 분기 |
| `GridViewController.swift` | iOS 26+ Push 분기 |
| `AlbumGridViewController.swift` | iOS 26+ Push 분기 |
| `TrashAlbumViewController.swift` | iOS 26+ Push 분기 |

## 핵심 버그 수정

### 증상
뷰어에서 아래 드래그(interactive dismiss) 시 앱 완전 멈춤 (터치 무반응)

### 원인
`popViewController(animated: true)` 호출 후 `navigationController`가 즉시 `nil`이 됨.

```
.began:    isPushed = true  → IC 생성 → popViewController 호출 ✓
.changed:  isPushed = false → Modal 경로 → zoomTransitionController == nil → IC 업데이트 안 됨 ✗
.ended:    IC가 finishInteractiveTransition 호출 못 함 → UIKit이 completeTransition 영원히 대기 → 앱 멈춤
```

### 수정
`activeInteractionController` / `activeTabBarController` 프로퍼티를 `.began`에서 미리 저장하고,
`.changed`/`.ended`에서 `isPushed` 재계산 없이 저장된 참조 사용.

```swift
// .began에서 저장
self.activeInteractionController = ic
self.activeTabBarController = tbc
navigationController?.popViewController(animated: true)

// .changed에서 직접 사용 (isPushed 재계산 안 함)
activeInteractionController?.didPanWith(gestureRecognizer: gesture)
```

## 교훈

**Navigation Pop과 VC 프로퍼티 타이밍:**
- `popViewController(animated: true)` 호출 즉시 `viewControllers` 배열이 업데이트됨
- 팝된 VC의 `navigationController`가 즉시 `nil`이 됨 (트랜지션 완료를 기다리지 않음)
- Interactive 트랜지션에서 `.changed`/`.ended` 핸들러가 실행될 때 이미 `navigationController == nil`
- 트랜지션 중 필요한 참조는 `.began`에서 반드시 미리 저장해야 함

**Custom UIViewControllerInteractiveTransitioning:**
- `animateTransition`은 호출되지 않음 (UIPercentDrivenInteractiveTransition과 다름)
- IC의 `startInteractiveTransition`이 모든 것을 담당
- Navigation Pop에서 toView를 `container.insertSubview(toView, at: 0)`으로 수동 추가 필요

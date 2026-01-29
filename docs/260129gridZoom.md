# 커스텀 줌 트랜지션 구현 계획

## 목표
- iOS 18의 `preferredTransition = .zoom` 제거
- 커스텀 `UIViewControllerAnimatedTransitioning` 기반 줌 트랜지션 구현
- **기본 사진 앱과 유사한 동작** 구현
- UIPageViewController 제스처 충돌 문제 해결
- iOS 16+ 전 버전에서 동일하게 적용

## 참고 자료 (조사 결과)
- [devsign.co - Interactive Pop Transition](https://devsign.co/notes/navigation-transitions-iv)
- [Douglas Hill - Zoom transitions](https://douglashill.co/zoom-transitions/)
- [PhotoZoomAnimator GitHub](https://github.com/jhrcook/PhotoZoomAnimator)

## 적용 범위 (5곳)

| 파일 | 라인 | 전환 |
|-----|------|-----|
| `GridViewController.swift` | :787 | 보관함 → 뷰어 |
| `TrashAlbumViewController.swift` | :552 | 휴지통 → 뷰어 |
| `AlbumGridViewController.swift` | :335 | 앨범 상세 → 뷰어 |
| `AlbumsViewController.swift` | :437 | 앨범 목록 → 일반 앨범 |
| `AlbumsViewController.swift` | :480 | 앨범 목록 → 스마트 앨범 |

---

## 새로운 파일 구조

```
PickPhoto/PickPhoto/Shared/Transitions/
├── ZoomTransitionProtocol.swift      # 소스/목적지 프로토콜
├── ZoomTransitionController.swift    # UINavigationControllerDelegate
├── ZoomAnimator.swift                # 애니메이션 구현
└── ZoomInteractionController.swift   # Interactive dismiss
```

---

## Phase 1: 프로토콜 및 기반 구조

### 1-1. ZoomTransitionProtocol.swift 생성

**⚠️ 좌표계 원칙: 모든 Frame은 window 기준 좌표로 통일**
- `zoomSourceFrame` → `convert(frame, to: nil)` 필수
- `zoomDestinationFrame` → `convert(frame, to: nil)` 필수

```swift
/// 줌 전환 소스 제공 (그리드 VC들이 채택)
protocol ZoomTransitionSourceProviding: AnyObject {
    func zoomSourceView(for index: Int) -> UIView?
    /// ⚠️ window 좌표계 기준으로 반환 필수
    func zoomSourceFrame(for index: Int) -> CGRect?
}

/// 줌 전환 목적지 제공 (뷰어 VC가 채택)
protocol ZoomTransitionDestinationProviding: AnyObject {
    var currentIndex: Int { get }
    var zoomDestinationView: UIView? { get }
    /// ⚠️ window 좌표계 기준으로 반환 필수
    var zoomDestinationFrame: CGRect? { get }
}
```

### 1-2. ZoomAnimator.swift 생성

- `UIViewControllerAnimatedTransitioning` 구현
- 줌 인: duration 0.25초, springDamping 0.9
- 줌 아웃: duration 0.37초, springDamping 0.9
- Fallback: 소스 뷰 없으면 crossfade

**⚠️ 핵심 구현 주의사항 (첫 번째 시도 실패 교훈)**:

```swift
func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
    let container = transitionContext.containerView
    guard let fromVC = transitionContext.viewController(forKey: .from),
          let toVC = transitionContext.viewController(forKey: .to) else {
        transitionContext.completeTransition(false)
        return
    }

    // ⚠️ 1. view(forKey:) 대신 VC.view 직접 사용
    let toView = toVC.view!
    let fromView = fromVC.view!

    // ⚠️ 2. finalFrame 반드시 설정
    let finalFrame = transitionContext.finalFrame(for: toVC)
    toView.frame = finalFrame

    // ⚠️ 3. container에 뷰 추가
    if isPush {
        container.addSubview(toView)
    } else {
        container.insertSubview(toView, belowSubview: fromView)
    }

    // ⚠️ 4. layoutIfNeeded 호출
    toView.layoutIfNeeded()

    // ⚠️ 5. Push 시 toView 숨기고 스냅샷만 보여줌
    toView.alpha = isPush ? 0 : 1

    // 스냅샷 생성 및 애니메이션...

    UIView.animate(...) {
        snapshotView.frame = endFrame
        // ⚠️ 6. Push 시 toView.alpha는 여기서 변경하지 않음!
        if !isPush { fromView.alpha = 0 }
    } completion: { _ in
        // ⚠️ 7. Push 시 completion에서 toView 표시
        if isPush { toView.alpha = 1 }

        snapshotView.removeFromSuperview()
        fromView.alpha = 1
        transitionContext.completeTransition(!transitionContext.transitionWasCancelled)
    }
}
```

### 1-3. ZoomTransitionController.swift 생성

- `UINavigationControllerDelegate` 구현
- `animationController(for:)` → ZoomAnimator 반환
- `interactionController(for:)` → ZoomInteractionController 반환
- BarsVisibilityPolicy 통합

---

## Phase 2: 그리드 → 뷰어 전환 적용

### 2-1. GridViewController 수정

**제거:**
```swift
// iOS 18+: 네이티브 zoom transition (라인 782-817)
if #available(iOS 18.0, *) {
    viewerVC.disableCustomFadeAnimation = true
    viewerVC.preferredTransition = .zoom(sourceViewProvider: { ... })
}
```

**추가:**
```swift
extension GridViewController: ZoomTransitionSourceProviding {
    func zoomSourceView(for index: Int) -> UIView? {
        let cellIndexPath = IndexPath(item: index + paddingCellCount, section: 0)
        guard let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell,
              cell.hasLoadedImage else { return nil }
        return cell.thumbnailImageView
    }

    func zoomSourceFrame(for index: Int) -> CGRect? {
        guard let sourceView = zoomSourceView(for: index) else { return nil }
        return sourceView.superview?.convert(sourceView.frame, to: nil)
    }
}
```

### 2-2. ViewerViewController 수정

**추가:**
```swift
extension ViewerViewController: ZoomTransitionDestinationProviding {
    /// 줌 애니메이션 대상 뷰 (이미지 뷰 스냅샷용)
    var zoomDestinationView: UIView? {
        currentPageImageView  // 현재 페이지의 실제 이미지 뷰
    }

    /// 줌 애니메이션 목적지 프레임 (window 좌표계)
    /// ⚠️ 중요: 로컬 좌표가 아닌 window 기준 좌표로 변환 필수
    var zoomDestinationFrame: CGRect? {
        guard let imageView = currentPageImageView else { return nil }
        return imageView.superview?.convert(imageView.frame, to: nil)
    }

    /// 현재 페이지의 이미지 뷰 (Photo/Video 공통)
    private var currentPageImageView: UIView? {
        guard let currentVC = pageViewController.viewControllers?.first else { return nil }

        if let photoPage = currentVC as? PhotoPageViewController {
            return photoPage.zoomableImageView  // imageView 접근자 사용
        } else if let videoPage = currentVC as? VideoPageViewController {
            return videoPage.posterImageView  // 비디오는 포스터 이미지 사용
        }
        return nil
    }
}
```

### 2-3. TabBarController 수정

- ZoomTransitionController 인스턴스 생성
- 각 NavigationController의 delegate로 설정
- 기존 BarsVisibilityPolicy 로직 통합

---

## Phase 3: Interactive Dismiss (핵심)

### 3-1. ZoomInteractionController.swift 생성

**기본 사진 앱 스타일 구현:**

```swift
class ZoomInteractionController: UIPercentDrivenInteractiveTransition {
    // 상수
    let dismissDistance: CGFloat = 200  // 200pt = 100%
    let minScale: CGFloat = 0.68        // 최소 스케일
    let progressThreshold: CGFloat = 0.1 // 10% 이상이면 완료 가능

    // 스프링 파라미터
    let cancelDuration: TimeInterval = 0.45
    let cancelDamping: CGFloat = 0.75
    let completeDuration: TimeInterval = 0.37
    let completeDamping: CGFloat = 0.90
}
```

**핵심 동작:**
1. 드래그 시 이미지 **스케일 + 위치** 동시 변경
2. 배경 투명도 연동
3. 손가락 방향 + 진행도로 완료/취소 결정
4. UIPropertyAnimator로 취소 시 부드럽게 원위치

### 3-2. ViewerViewController 연동

**기존 handleDismissPan 교체:**
- 현재: 단순히 배경 투명도만 조절
- 변경: ZoomInteractionController가 이미지 transform 제어

**UIPageViewController 제스처 충돌 방지:**
```swift
func gestureRecognizerShouldBegin(_ gesture: UIGestureRecognizer) -> Bool {
    guard let panGesture = gesture as? UIPanGestureRecognizer else { return false }

    // 1. 현재 페이지의 스크롤뷰 상태 확인
    if let photoPage = currentPhotoPage {
        // 확대 상태면 dismiss 불가 (패닝으로 사용)
        guard photoPage.zoomScale <= 1.0 else { return false }
        // 스크롤 위치가 상단이 아니면 dismiss 불가
        guard photoPage.isAtTopEdge else { return false }
    }

    // 2. 속도 기반 방향 판단
    let velocity = panGesture.velocity(in: view)
    // 아래 방향이고 수직 성분이 더 클 때만 인식
    return velocity.y > 0 && abs(velocity.y) > abs(velocity.x)
}
```

**PhotoPageViewController 추가 접근자:**
```swift
/// 현재 줌 스케일
var zoomScale: CGFloat { scrollView.zoomScale }

/// 스크롤이 상단 가장자리인지
var isAtTopEdge: Bool {
    scrollView.contentOffset.y <= -scrollView.contentInset.top + 1  // 1pt 여유
}
```

### 3-3. PhotoPageViewController 수정

**접근자 추가 필요:**
```swift
/// 줌 애니메이션용 이미지 뷰 접근자
var zoomableImageView: UIImageView { imageView }

/// 현재 줌 스케일
var zoomScale: CGFloat { scrollView.zoomScale }

/// 스크롤이 상단 가장자리인지 (dismiss 허용 판단용)
var isAtTopEdge: Bool {
    scrollView.contentOffset.y <= -scrollView.contentInset.top + 1
}
```

### 3-4. VideoPageViewController 수정

**비디오용 줌 애니메이션 대응:**
- 비디오는 `AVPlayerLayer`를 사용하므로 이미지 뷰가 없음
- **Fallback 전략**: 포스터 이미지를 줌 대상으로 사용

```swift
/// 줌 애니메이션용 포스터 이미지 뷰 접근자
var posterImageView: UIImageView? { playerLayerView.posterImageView }

/// 현재 줌 스케일
var zoomScale: CGFloat { scrollView.zoomScale }

/// 스크롤이 상단 가장자리인지
var isAtTopEdge: Bool {
    scrollView.contentOffset.y <= -scrollView.contentInset.top + 1
}
```

**PlayerLayerView에 포스터 접근자 추가:**
```swift
/// 포스터 이미지 뷰 (줌 트랜지션용)
var posterImageView: UIImageView { posterView }
```

---

## Phase 4: 나머지 화면 적용

### 4-1. TrashAlbumViewController

- ZoomTransitionSourceProviding 채택
- preferredTransition = .zoom 제거

### 4-2. AlbumGridViewController

- ZoomTransitionSourceProviding 채택
- preferredTransition = .zoom 제거

### 4-3. AlbumsViewController (앨범 목록 → 앨범 그리드)

- 2곳의 preferredTransition = .zoom 제거
- AlbumCell용 ZoomTransitionSourceProviding 구현

**AlbumCell 접근자 추가:**
```swift
// AlbumCell.swift
/// 줌 트랜지션용 대표 이미지 뷰 접근자
var thumbnailImageView: UIImageView { coverImageView }
```

**AlbumsViewController 프로토콜 채택:**
```swift
extension AlbumsViewController: ZoomTransitionSourceProviding {
    func zoomSourceView(for index: Int) -> UIView? {
        let indexPath = IndexPath(item: index, section: 0)
        guard let cell = collectionView.cellForItem(at: indexPath) as? AlbumCell else {
            return nil
        }
        return cell.thumbnailImageView
    }

    func zoomSourceFrame(for index: Int) -> CGRect? {
        guard let sourceView = zoomSourceView(for: index) else { return nil }
        return sourceView.superview?.convert(sourceView.frame, to: nil)  // window 좌표
    }
}
```

---

## Phase 5: 정리

### 5-1. 미사용 코드 제거

**확인 완료: 아래 클래스들은 현재 외부에서 참조되지 않음**
- ViewerCoordinator.swift의 `ViewerTransitionAnimator` 클래스 제거 (line 359-465)
- ViewerCoordinator.swift의 `ViewerTransitioningDelegate` 클래스 제거 (line 471-487)
- ViewerViewController.`disableCustomFadeAnimation` 플래그 제거

### 5-2. 테스트

- 보관함 → 뷰어 → 좌우 스와이프 → 복귀
- 휴지통 → 뷰어 → 좌우 스와이프 → 복귀
- 앨범 목록 → 앨범 그리드 → 뷰어 → 복귀
- 아래 드래그 dismiss (interactive)
- 셀이 화면 밖인 경우 fallback

---

## 수정 파일 목록

| 파일 | 작업 |
|-----|-----|
| `Shared/Transitions/ZoomTransitionProtocol.swift` | 신규 |
| `Shared/Transitions/ZoomAnimator.swift` | 신규 |
| `Shared/Transitions/ZoomTransitionController.swift` | 신규 |
| `Shared/Transitions/ZoomInteractionController.swift` | 신규 |
| `Shared/Navigation/TabBarController.swift` | 수정 |
| `Features/Grid/GridViewController.swift` | 수정 |
| `Features/Albums/TrashAlbumViewController.swift` | 수정 |
| `Features/Albums/AlbumGridViewController.swift` | 수정 |
| `Features/Albums/AlbumsViewController.swift` | 수정 |
| `Features/Albums/AlbumCell.swift` | 수정 (thumbnailImageView 접근자 추가) |
| `Features/Viewer/ViewerViewController.swift` | 수정 |
| `Features/Viewer/PhotoPageViewController.swift` | 수정 (접근자 추가: zoomableImageView, zoomScale, isAtTopEdge) |
| `Features/Viewer/VideoPageViewController.swift` | 수정 (접근자 추가: posterImageView, zoomScale, isAtTopEdge) |
| `Features/Viewer/PlayerLayerView.swift` | 수정 (posterImageView 접근자 추가) |
| `Features/Viewer/ViewerCoordinator.swift` | 수정 (미사용 코드 제거) |

---

## 주의사항

### 기존 동작 유지
- 위로 스와이프 삭제 (SwipeDeleteHandler) - 그대로 유지
- 아래로 스와이프 닫기 - ZoomInteractionController로 대체

### 잠재적 이슈
1. **스크롤뷰 충돌**: PhotoPageViewController의 줌 스크롤뷰와 dismiss 제스처 충돌 가능
   - 해결: `zoomScale <= 1.0 && isAtTopEdge` 조건으로 dismiss 허용 판단
   - Phase 3-2, 3-3에서 구현
2. **비디오 뷰어**: VideoPageViewController에도 동일 적용 필요
   - 해결: 포스터 이미지를 줌 대상으로 사용 (Phase 3-4)
   - PlayerLayerView에 posterImageView 접근자 추가
3. **메모리**: 스냅샷 이미지 생성 시 메모리 사용량 주의

### ⚠️ UIViewControllerAnimatedTransitioning 구현 함정 (첫 번째 시도 실패 원인)

1. **`transitionContext.view(forKey:)` nil 반환**
   - Navigation push에서 nil 반환 가능
   - 반드시 `toVC.view` 직접 사용

2. **toView frame 미설정**
   - `transitionContext.finalFrame(for:)` 사용 필수
   - 미설정 시 뷰가 잘못된 위치에 표시됨

3. **Push 시 toView.alpha 애니메이션**
   - 뷰어의 imageView에 이미지 로드 전이므로 빈 화면
   - completion에서 즉시 alpha = 1 설정해야 함

4. **sourceView.isHidden 설정**
   - 원본 셀이 검게 변함
   - 스냅샷 사용 시 원본 숨길 필요 없음

5. **LiquidGlassKit 경고**
   - `afterScreenUpdates:YES` 필요 경고 발생
   - 앱 동작에는 영향 없으나 확인 필요

---

## 애니메이션 파라미터 (조사 기반)

### 줌 인 (그리드 → 뷰어) - Non-interactive
```swift
duration: 0.25
springDamping: 0.9
initialSpringVelocity: 0
options: .curveEaseOut
```

### 줌 아웃 (뷰어 → 그리드) - Non-interactive
```swift
duration: 0.37
springDamping: 0.9
initialSpringVelocity: 제스처 속도 반영
```

### Interactive Dismiss (아래 드래그) - 핵심 동작

**기본 사진 앱 스타일:**
1. **스케일 변화**: 드래그하면 이미지가 점점 작아짐 (최소 68%)
2. **위치 추적**: 이미지가 손가락을 따라다님
3. **배경 투명도**: 드래그 양에 따라 배경이 투명해짐

```swift
// 스케일 계산
let minScale: CGFloat = 0.68
let scale = 1 - (1 - minScale) * percentageComplete

// 위치 + 스케일 변환
// ⚠️ 중요: translation을 scale로 나눠서 보정해야 손가락 위치와 일치
// CGAffineTransform은 오른쪽부터 적용되므로 translate → scale 순서
// scale 적용 시 translation도 증폭되므로 미리 보정
let adjustedTranslation = CGPoint(
    x: translation.x / scale,
    y: translation.y / scale
)
imageView.transform = CGAffineTransform.identity
    .scaledBy(x: scale, y: scale)
    .translatedBy(x: adjustedTranslation.x, y: adjustedTranslation.y)

// 배경 투명도
backgroundView.alpha = 1 - percentageComplete
```

**Dismiss 결정 조건:**
- 드래그 거리: 200pt = 100% 완료
- 속도 조건: 손가락이 아래로 움직이는 중
- 진행도 조건: 10% 이상 (percentageComplete > 0.1)
- `fingerIsMovingDownwards && transitionMadeSignificantProgress`

**취소/완료 스프링:**
```swift
// 취소 시 (원위치 복귀)
duration: 0.45
springDamping: 0.75

// 완료 시 (셀로 축소)
duration: 0.37
springDamping: 0.90
```

---

## 검증 방법

1. **제스처 충돌 테스트**: 뷰어에서 좌우 스와이프로 사진 전환 시 pop 안 됨
2. **속도 테스트**: 기본 사진 앱과 비슷한 빠른 전환
3. **Interactive dismiss**: 아래 드래그로 자연스럽게 닫기
4. **Fallback 테스트**: 셀이 화면 밖일 때 중앙 줌
5. **iOS 버전 테스트**: iOS 16, 17, 18+에서 동일 동작
6. **확대 상태 dismiss 차단**: 사진 확대 후 아래 드래그 시 dismiss 안 됨 (패닝으로 동작)
7. **비디오 줌 테스트**: 비디오 → 그리드 복귀 시 포스터 기반 줌 애니메이션

---

## 첫 번째 구현 시도 실패 기록 (2026-01-29)

### 롤백 커밋
- `823aab9` (줌 트랜지션 구현 전)으로 완전 롤백

### 발생한 문제들

#### 1. 애니메이션이 전혀 보이지 않음
**원인**: `transitionContext.view(forKey: .to)`가 nil 반환
- Navigation push에서는 이 API가 nil을 반환할 수 있음
- toView가 nil이면 container에 뷰가 추가되지 않음

**해결책**:
```swift
// ❌ 잘못된 방식
let toView = transitionContext.view(forKey: .to)
if let toView = toView { container.addSubview(toView) }

// ✅ 올바른 방식
let toView = toVC.view!
let finalFrame = transitionContext.finalFrame(for: toVC)
toView.frame = finalFrame
container.addSubview(toView)
```

#### 2. 스냅샷은 이동하지만 빈 화면이 덮어버림
**원인**: Push 시 `toView.alpha`를 애니메이션 중에 0→1로 변경
- 스냅샷이 이동하는 동안 toView(뷰어)가 점점 보이기 시작
- 뷰어의 imageView에 이미지가 아직 로드되지 않은 상태 (`image = null`)
- 빈 뷰어 화면이 스냅샷을 덮어버림

**로그 증거**:
```
destView: ... image = <(null):0x0 (null) anonymous; (0 0)@0>
```

**해결책**:
```swift
// ❌ 잘못된 방식 - 애니메이션 중 alpha 변경
UIView.animate(...) {
    snapshotView.frame = endFrame
    toView.alpha = 1  // 빈 화면이 점점 보임
}

// ✅ 올바른 방식 - completion에서 즉시 변경
UIView.animate(...) {
    snapshotView.frame = endFrame
    // toView.alpha는 여기서 변경하지 않음
} completion: { _ in
    toView.alpha = 1  // 스냅샷 애니메이션 완료 후 즉시 표시
}
```

#### 3. 썸네일이 까맣게 변함
**원인**: `sourceView?.isHidden = true` 설정
- 애니메이션 중 원본 뷰를 숨기면 셀이 검은색으로 보임
- 스냅샷을 사용하므로 원본을 숨길 필요 없음

**해결책**: sourceView.isHidden 설정 제거 또는 다른 방식 사용

#### 4. 그리드 복귀 시 스크롤 위치 변경
**원인**: 조사 필요 (트랜지션 중 collectionView 레이아웃 영향 추정)

### 다음 구현 시 핵심 체크리스트

1. [ ] `transitionContext.view(forKey:)` 대신 `toVC.view` 사용
2. [ ] `transitionContext.finalFrame(for:)` 으로 프레임 설정
3. [ ] Push 시 toView.alpha는 completion에서만 변경
4. [ ] sourceView.isHidden 설정하지 않기 (또는 completion에서만)
5. [ ] destinationView 이미지 로드 타이밍 확인
6. [ ] 각 단계마다 로그로 값 확인 후 진행

### 권장 구현 순서

1. **최소 동작 먼저**: crossfade만 동작하는 기본 구조 확인
2. **스냅샷 줌 추가**: sourceView 스냅샷으로 줌 애니메이션
3. **Pop 구현**: 뷰어 → 그리드 줌 아웃
4. **Interactive 추가**: 아래 드래그 dismiss
5. **나머지 화면 적용**: 휴지통, 앨범 등

---

## 두 번째 구현 완료 (2026-01-29)

### 완료된 기능

#### Phase 1-2: 기본 줌 트랜지션 ✅
- **Push (그리드 → 뷰어)**: 썸네일에서 뷰어로 줌 인 애니메이션
- **Pop (뷰어 → 그리드)**: 뷰어에서 썸네일로 줌 아웃 애니메이션
- **Fallback**: 셀이 화면 밖이거나 이미지 미로드 시 crossfade

#### 적용 범위
- GridViewController (보관함) ✅
- TrashAlbumViewController (휴지통) ✅
- AlbumGridViewController (앨범 상세) ✅
- AlbumsViewController (앨범 목록 → 앨범 그리드) - Phase 4 예정

### 구현 세부사항

#### 파일 구조
```
PickPhoto/PickPhoto/Shared/Transitions/
├── ZoomTransitionProtocol.swift      # 소스/목적지 프로토콜
├── ZoomTransitionController.swift    # UINavigationControllerDelegate
└── ZoomAnimator.swift                # 애니메이션 구현
```

#### 핵심 해결책

1. **filteredIndex → originalIndex 변환**
   - ViewerViewController.currentIndex는 filteredIndex
   - coordinator.originalIndex(from:)로 변환하여 셀 찾기

2. **Pop 전 그리드 스크롤 (기본 사진 앱 스타일)**
   - 셀이 화면 밖이어도 해당 위치로 스크롤 후 줌 아웃
   - scrollToSourceCell(for:) 메서드 추가

3. **destinationFrame을 asset 비율로 계산**
   - imageView.frame 대신 PHAsset.pixelWidth/Height 기반
   - 레이아웃 완료 전에도 정확한 프레임 반환
   - 비디오 줌 시 화면 전체로 확대되는 문제 해결

4. **배경 fade in 애니메이션**
   - Push 시 스냅샷 줌 + 검은 배경 fade in 동시 진행
   - 별도 curveEaseOut 애니메이션으로 부드러운 전환

#### 애니메이션 파라미터 (최종)
```swift
pushDuration: 0.35       // 그리드 → 뷰어
popDuration: 0.37        // 뷰어 → 그리드
springDamping: 0.9
```

### 미구현 (Phase 3)
- Interactive Dismiss: 아래 드래그로 닫기

---

## Phase 3 시도 실패 분석 (2026-01-29)

### 시도한 구현
- `UIPercentDrivenInteractiveTransition` 상속
- `handlePanBegan`에서 `popViewController(animated: true)` 호출
- `handlePanChanged`에서 `update(progress)` 호출
- `handlePanEnded`에서 `finish()` 또는 `cancel()` 호출

### 발생한 문제

**로그 증거:**
```
[ZoomInteraction] Pan began - initialCenter: (195.0, 260.0)
[ZoomTransition] Pop: using ZoomAnimator (interactive: true)
[ZoomAnimator] Animating from ... to ...  ← 즉시 전체 애니메이션 시작!
[ZoomInteraction] handlePan - state: 2    ← 이미 늦음
```

**현상:**
- Pan began 시점에 `popViewController(animated: true)` 호출
- `ZoomAnimator`가 **전체 애니메이션을 즉시 실행**
- 드래그하는 동안 이미 애니메이션 완료됨
- `update(progress)` 호출이 무시됨

### 근본 원인

`UIPercentDrivenInteractiveTransition`은 **CA 레이어 기반 애니메이션**을 가로채서 progress 제어함.
`ZoomAnimator`는 **스냅샷 UIImageView**를 사용하는 커스텀 애니메이션.
→ 두 가지가 **호환되지 않음**

### 해결 방안: ZoomAnimator 우회

**핵심 아이디어:**
Interactive dismiss에서는 `popViewController` + `ZoomAnimator`를 사용하지 않고,
Pan 제스처에서 **직접 transform 제어**

**구현 방식:**
```swift
class ZoomInteractionController {
    // Navigation transition을 사용하지 않음
    // 직접 이미지 transform + 배경 alpha 제어

    func handlePanChanged(translation: CGPoint) {
        // 1. 이미지 스케일 + 위치 직접 변경
        let scale = 1 - (1 - minScale) * progress
        imageView.transform = CGAffineTransform.identity
            .translatedBy(x: translation.x, y: translation.y)
            .scaledBy(x: scale, y: scale)

        // 2. 배경 투명도 직접 변경
        backgroundView.alpha = 1 - progress
    }

    func handlePanEnded(shouldComplete: Bool) {
        if shouldComplete {
            // 줌 아웃 애니메이션 후 pop (animated: false)
            animateToSourceFrame {
                navigationController?.popViewController(animated: false)
            }
        } else {
            // 원위치 복귀 애니메이션
            animateToOriginalPosition()
        }
    }
}
```

**장점:**
- Navigation transition과 독립적으로 동작
- progress에 따라 정확히 제어 가능
- 기본 사진 앱과 동일한 UX

### 다음 구현 시 핵심 체크리스트

1. [ ] `popViewController(animated: true)` 사용하지 않기
2. [ ] Pan 제스처에서 직접 imageView.transform 제어
3. [ ] 완료 시 줌 아웃 애니메이션 후 `popViewController(animated: false)`
4. [ ] 취소 시 원위치 복귀 애니메이션
5. [ ] ZoomTransitionSourceProviding으로 소스 프레임 가져오기

### 커밋 이력
```
a9c078f fix(transition): 배경 fade 애니메이션 개선 및 duration 조정
8d3aa9a fix(transition): Push 시 배경 fade in 애니메이션 추가
ae1d5eb fix(transition): destinationFrame을 asset 비율 기반으로 계산
d398665 feat(transition): Pop 전 그리드 스크롤 추가 (기본 사진 앱 스타일)
87a18d1 fix(transition): filteredIndex → originalIndex 변환 추가
6261dac feat(transition): Phase 2 - iOS 18 네이티브 줌 제거
d34059e feat(transition): Phase 1 구현
```

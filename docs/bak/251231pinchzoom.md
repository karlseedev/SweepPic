# 핀치줌 그리드 열 전환 애니메이션 연구

## 목표
핀치 줌으로 1열/3열/5열 전환 시 iOS 기본 사진앱처럼 중간 애니메이션이 보이도록 구현하는 방법 조사.

현재 구현: 임계값(1.15/0.85) 도달 시 즉시 레이아웃 전환
목표: 핀치 제스처 진행에 따라 연속적으로 셀 크기가 변하는 애니메이션

---

## 조사 방법 요약

| 방법 | 마지막 업데이트 | 성능 | 복잡도 | 핀치 예제 검증 |
|------|---------------|------|--------|---------------|
| UICollectionViewTransitionLayout | Apple 공식 (지속) | ⚠️ CompositionalLayout 이슈 | 중간 | ✅ **Apple 공식 샘플 존재** |
| Real-time itemSize 보간 | ✅ | ⚠️ 빈번한 invalidate | 낮음 | ⚠️ 핀치 예제 없음 |
| TLLayoutTransitioning | ❌ 2016년 | ✅ | 낮음 | ✅ Pinch 예제 있음 |
| Custom Layout (ZoomCollectionView) | ⚠️ 개인 프로젝트 | ✅ | 중간 | ⚠️ 바운스 미작동 |

---

## 방법 1: UICollectionViewTransitionLayout (Apple 공식 권장)

### 개요
iOS 7+에서 제공하는 공식 API. 두 레이아웃 간 인터랙티브 전환 지원.

### ⭐ Apple 공식 샘플 코드 발견
**WWDC 2013 Session 218: "Custom Transitions Using View Controllers"**에서 핀치 제스처를 통한 인터랙티브 레이아웃 전환을 공식적으로 다룸.

- **[Collection View Transition Sample Code](https://developer.apple.com/library/archive/samplecode/CollectionViewTransition/Introduction/Intro.html)**
- Stack View → Grid View 핀치 제스처 인터랙티브 전환 데모
- `UICollectionViewTransitionLayout` 서브클래스를 사용하여 제스처 위치 기반 셀 위치 전환
- 전환 중 속도 제어 및 방향 역전 가능

### 핵심 API
```swift
// 인터랙티브 전환 시작
let transitionLayout = collectionView.startInteractiveTransition(
    to: newLayout,
    completion: nil
)

// 진행률 업데이트 (0.0 ~ 1.0)
transitionLayout.transitionProgress = progress

// 전환 완료 또는 취소
collectionView.finishInteractiveTransition()
collectionView.cancelInteractiveTransition()
```

### Apple 권장 구현 패턴
```swift
@objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    switch gesture.state {
    case .began:
        // 인터랙티브 전환 시작
        collectionView.startInteractiveTransition(to: newLayout) { completed, finished in
            // 완료 처리
        }
    case .changed:
        // 스케일에 따라 진행률 계산
        let progress = calculateProgress(from: gesture.scale)
        collectionView.collectionViewLayout.transitionProgress = progress
    case .ended:
        // 스케일에 따라 완료 또는 취소 결정
        if gesture.scale < 1.0 {
            collectionView.finishInteractiveTransition()
        } else {
            collectionView.cancelInteractiveTransition()
        }
    default:
        break
    }
}
```

### 장점
- **Apple 공식 API이자 권장 방법**
- **핀치 제스처 예제가 공식 샘플에 존재**
- `transitionProgress`로 세밀한 제어 가능
- 두 레이아웃 간 보간 자동 처리

### 단점
- **CompositionalLayout과의 호환성 문제 보고됨** (FlowLayout 사용 권장)
  - [iOS 14 레이아웃 변경 애니메이션 버그](https://forums.developer.apple.com/forums/thread/663449)
  - [레이아웃 리셋 시 크래시](https://developer.apple.com/forums/thread/95662)
  - [iOS 15 UICollectionViewRecursion 크래시](https://developer.apple.com/forums/thread/694141)
  - [iOS 15 estimated size 무한 루프](https://developer.apple.com/forums/thread/682570)
- `visibleItemsInvalidationHandler`는 estimated sizes와 함께 작동하지 않음
- 2013년 샘플이라 Objective-C로 작성됨

### 참고 링크
- [Apple Developer Documentation](https://developer.apple.com/documentation/uikit/uicollectionviewtransitionlayout)
- [Collection View Transition Sample Code](https://developer.apple.com/library/archive/samplecode/CollectionViewTransition/Introduction/Intro.html)
- [WWDC 2013 Session 218](https://developer.apple.com/videos/play/wwdc2013/218/)
- [Stack Overflow - Interactive Transition](https://stackoverflow.com/questions/13780138)

---

## 방법 2: Real-time itemSize 보간

### 개요
핀치 제스처의 scale 값에 따라 실시간으로 itemSize를 계산하고 `invalidateLayout()` 호출.

### 구현 예시
```swift
@objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    switch gesture.state {
    case .changed:
        let scale = gesture.scale
        // 현재 열 수의 itemSize와 목표 열 수의 itemSize 사이를 보간
        let currentSize = calculateItemSize(for: currentColumns)
        let targetSize = calculateItemSize(for: targetColumns)
        let interpolatedSize = lerp(currentSize, targetSize, progress: normalizedScale)

        flowLayout.itemSize = interpolatedSize
        collectionView.collectionViewLayout.invalidateLayout()

    case .ended:
        // 최종 열 수 결정 및 스냅
        snapToNearestColumn()
    }
}
```

### 장점
- 구현이 단순함
- 추가 라이브러리 불필요
- 기존 FlowLayout 유지 가능

### 단점
- **빈번한 `invalidateLayout()` 호출로 성능 저하 우려**
- 스크롤 위치 유지가 어려움
- 핀치 줌 전용 구현 예제가 적음

### 참고 링크
- [Medium - Zooming UICollectionView](https://medium.com/@andrea.toso/zooming-uicollectionview)

---

## 방법 3: TLLayoutTransitioning 라이브러리

### 개요
UICollectionViewTransitionLayout을 래핑한 서드파티 라이브러리. **Pinch 예제가 포함되어 있음**.

### GitHub
- https://github.com/wtmoose/TLLayoutTransitioning
- ⚠️ **마지막 업데이트: 2016년**

### 핵심 기능
```swift
// 레이아웃 전환
collectionView.transitionToLayout(
    nextLayout,
    duration: 0.5,
    easing: TLTransitionEasingFunction.easeInOutQuad
)

// 인터랙티브 전환 (핀치용)
let handler = collectionView.startInteractiveTransitionToLayout(nextLayout)
handler.updateProgress(pinchScale)
```

### 장점
- **핀치 줌 전용 예제 포함** (Examples/Pinch)
- 이징 함수 커스터마이징 지원
- UICollectionViewTransitionLayout 복잡성을 추상화

### 단점
- **2016년 이후 업데이트 없음**
- iOS 9 대응 코드로 최신 iOS와 호환성 불확실
- CompositionalLayout 미지원 (FlowLayout 기반)
- Objective-C로 작성됨

### Pinch 예제 구조
```
Examples/
└── Pinch/
    ├── PinchCollectionViewController.m
    └── PinchLayout.m
```

---

## 방법 4: Custom Layout (ScalingLayoutProtocol)

### 개요
ZoomCollectionView 프로젝트에서 사용된 접근법. 스케일 기반 커스텀 레이아웃 프로토콜 정의.

### GitHub
- https://github.com/nicksay/ZoomCollectionView (개인 프로젝트)

### 프로토콜 정의
```swift
protocol ScalingLayoutProtocol: UICollectionViewLayout {
    func getScale() -> CGFloat
    func setScale(_ scale: CGFloat)
    func contentSizeForScale(_ scale: CGFloat) -> CGSize
}
```

### 구현 방식
```swift
class ScalingFlowLayout: UICollectionViewFlowLayout, ScalingLayoutProtocol {
    private var currentScale: CGFloat = 1.0

    func setScale(_ scale: CGFloat) {
        currentScale = scale
        invalidateLayout()
    }

    override var itemSize: CGSize {
        get {
            let baseSize = super.itemSize
            return CGSize(
                width: baseSize.width * currentScale,
                height: baseSize.height * currentScale
            )
        }
        set { super.itemSize = newValue }
    }
}
```

### 장점
- 완전한 제어 가능
- 성능 최적화 여지 있음
- 최신 iOS 대응 가능

### 단점
- **바운스 효과가 작동하지 않는다고 보고됨**
- 개인 프로젝트로 검증 부족
- 구현 복잡도 높음
- 스크롤 위치 동기화 직접 구현 필요

---

## 결론 및 권장사항

### 검증된 핀치 예제 존재 여부
| 방법 | 핀치 예제 | 비고 |
|------|----------|------|
| UICollectionViewTransitionLayout | ✅ | **Apple 공식 샘플 코드 존재 (WWDC 2013)** |
| Real-time itemSize | ⚠️ | 핀치 전용 예제 드묾 |
| TLLayoutTransitioning | ✅ | Examples/Pinch 폴더에 존재 |
| Custom Layout | ⚠️ | 개인 프로젝트, 바운스 미작동 |

### 🏆 최종 권장: UICollectionViewTransitionLayout

**Apple이 공식적으로 권장하는 방법이며, 핀치 제스처 예제가 공식 샘플 코드에 존재함.**

### 현실적 선택지

1. **UICollectionViewTransitionLayout 구현 (권장)**
   - Apple 공식 API이자 권장 방법
   - **WWDC 2013 공식 샘플 코드 참고** (Objective-C → Swift 포팅 필요)
   - CompositionalLayout 대신 FlowLayout 사용 권장
   - TLLayoutTransitioning은 이 API를 래핑한 것이므로 원본 API 직접 사용

2. **TLLayoutTransitioning 참고**
   - UICollectionViewTransitionLayout을 래핑한 라이브러리
   - 2016년 코드이지만 핀치 구현 로직 참고 가능
   - Apple 샘플 코드가 있으므로 우선순위 낮음

3. **현재 구현 유지 (임계값 기반)**
   - 중간 애니메이션 없이 스냅 방식 유지
   - 구현 복잡도와 성능 리스크 회피
   - UIView.animate으로 전환 시 부드러운 애니메이션은 제공됨

### 구현 시 주의사항
- **FlowLayout 사용 권장**: CompositionalLayout과의 호환성 문제 보고됨
- **iOS 18 Zoom Transition과 혼동 금지**: iOS 18의 Zoom Transition은 뷰 컨트롤러 간 전환용이며, 컬렉션 뷰 레이아웃 전환과는 다름

### 추가 조사 완료 사항
- ~~WWDC 세션에서 관련 내용 확인~~ → WWDC 2013 Session 218 확인됨
- iOS 기본 사진앱이 실제로 어떤 방식을 사용하는지 (리버스 엔지니어링 필요)
- CompositionalLayout에서 인터랙티브 전환을 지원하는 최신 방법

---

## 참고 자료

### 공식 문서
- [UICollectionViewTransitionLayout - Apple](https://developer.apple.com/documentation/uikit/uicollectionviewtransitionlayout)
- [startInteractiveTransition - Apple](https://developer.apple.com/documentation/uikit/uicollectionview/1618098-startinteractivetransition)

### 라이브러리
- [TLLayoutTransitioning - GitHub](https://github.com/wtmoose/TLLayoutTransitioning)
- [ZoomCollectionView - GitHub](https://github.com/nicksay/ZoomCollectionView)

### 블로그/튜토리얼
- [Zooming UICollectionView - Medium](https://medium.com/@andrea.toso/zooming-uicollectionview)
- [Stack Overflow - Interactive Layout Transition](https://stackoverflow.com/questions/13780138)

---

*작성일: 2025-12-31*

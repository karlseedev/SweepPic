# 얼굴 그리드 UI 통일성 개선 계획

**작성일**: 2026-01-29
**목표**: 얼굴 비교 화면(FaceComparisonViewController)을 다른 화면들(앨범 목록 등)과 동일한 플로팅 UI 스타일로 통일

---

## 현재 문제점

### 얼굴 그리드 (FaceComparisonViewController)
```
┌─────────────────────────────────┐
│  FaceComparisonTitleBar         │  ← 배경 없음 (투명), 버튼만 있음
│  [X]     인물 1 (3장)     [↻]   │
├─────────────────────────────────┤
│                                 │
│  ┌─────┐  ┌─────┐               │  ← PageViewController가 상하단
│  │ 얼굴 │  │ 얼굴 │               │     사이에 끼어있음
│  └─────┘  └─────┘               │     (전체 화면 X)
│                                 │
├─────────────────────────────────┤
│  bottomBarContainer             │  ← 불투명 검정 80% + 블러
│  Cancel     항목 선택    Delete  │     완전히 분리된 영역
└─────────────────────────────────┘
```

### 다른 화면들 (Grid, Album, Viewer 등)
```
┌─────────────────────────────────┐
│░░░░░ FloatingTitleBar ░░░░░░░░░│  ← 그라데이션 + Progressive Blur
│░░ 사진보관함         [Select] ░░│     (상단 45% → 투명 페이드)
├─────── 콘텐츠 위에 겹침 ─────────┤
│  ┌─────┐  ┌─────┐  ┌─────┐      │
│  │사진1│  │사진2│  │사진3│      │  ← 전체 화면 사용 + contentInset
│  └─────┘  └─────┘  └─────┘      │     사진이 상하단 뒤로 비쳐보임
│  (스크롤하면 사진이 상단 뒤로 들어감)│
├─────── 콘텐츠 위에 겹침 ─────────┤
│░░░░░░ FloatingTabBar ░░░░░░░░░│  ← 그라데이션 + Progressive Blur
│░░  Photos    Albums    Trash ░░│     (하단 45% → 투명 페이드)
└─────────────────────────────────┘
```

---

## 목표 상태

- **상단**: 그라데이션 + Progressive Blur (FloatingTitleBar 스타일)
- **하단**: 그라데이션 + Progressive Blur (불투명 검정 → 그라데이션)
- **그리드**: 전체 화면 사용 + contentInset으로 상하 여백
- **정렬**: 상단 정렬 유지 (2열 그리드)

---

## 구현 계획

### Phase 1: FaceComparisonTitleBar 그라데이션 추가

**파일**: `FaceComparisonViews.swift`

**변경 내용**:
- `VariableBlurView` (BlurUIKit) 추가 - progressive blur
- `CAGradientLayer` 추가 - 상단→하단 페이드
- FloatingTitleBar와 동일한 스타일 적용 (maxDimAlpha 0.45)

```swift
// 추가할 컴포넌트
private lazy var progressiveBlurView: VariableBlurView = {
    let view = VariableBlurView()
    view.direction = .down  // 상단(강함) → 하단(약함)
    view.maximumBlurRadius = 1.5
    view.dimmingTintColor = UIColor.black
    view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
    return view
}()

private lazy var gradientLayer: CAGradientLayer = {
    let layer = CAGradientLayer()
    layer.colors = [
        UIColor.black.withAlphaComponent(0.45).cgColor,
        UIColor.black.withAlphaComponent(0.45 * 0.7).cgColor,
        UIColor.black.withAlphaComponent(0.45 * 0.3).cgColor,
        UIColor.black.withAlphaComponent(0.45 * 0.1).cgColor,
        UIColor.clear.cgColor
    ]
    layer.locations = [0, 0.25, 0.5, 0.75, 1.0]
    return layer
}()

// ⚠️ CAGradientLayer는 Auto Layout 미적용 - 수동 업데이트 필요
override func layoutSubviews() {
    super.layoutSubviews()
    gradientLayer.frame = bounds
}
```

---

### Phase 2: 하단바 그라데이션 스타일로 변경

**파일**: `FaceComparisonViewController.swift`

**변경 내용**:
- `bottomBarContainer` 배경을 불투명 80% → 그라데이션으로 변경
- `VariableBlurView` 추가 (direction: .up, 하단→상단)
- 기존 `bottomBarBlur` 제거 또는 교체
- 높이 계산: 56 + gradientExtension(15) 반영

```swift
// 현재
backgroundColor = UIColor.black.withAlphaComponent(0.8)

// 변경
private lazy var bottomProgressiveBlurView: VariableBlurView = {
    let view = VariableBlurView()
    view.direction = .up  // 하단(강함) → 상단(약함)
    view.maximumBlurRadius = 1.5
    view.dimmingTintColor = UIColor.black
    view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
    return view
}()

// 하단바도 gradientLayer 사용 시 layoutSubviews에서 프레임 업데이트 필요
override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    bottomGradientLayer.frame = bottomBarContainer.bounds
}
```

---

### Phase 3: FaceComparisonViewController 레이아웃 변경

**파일**: `FaceComparisonViewController.swift`

**변경 내용**:
1. **addSubview 순서 변경**: pageVC → titleBar → bottomBar (z-order)
2. PageViewController를 전체 화면으로 확장
3. iOS 26+ 분기 처리 유지

```swift
// 현재
pageViewController.view.topAnchor.constraint(equalTo: customTitleBar!.bottomAnchor)
pageViewController.view.bottomAnchor.constraint(equalTo: bottomBarContainer.topAnchor)

// 변경
pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor)
pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
```

**iOS 버전별 분기**:

| 항목 | iOS 16~25 | iOS 26+ |
|------|-----------|---------|
| **상단** | 커스텀 타이틀바 (그라데이션) | 시스템 네비게이션바 |
| **하단** | 커스텀 하단바 (그라데이션) | 커스텀 하단바 (그라데이션) |
| **inset** | 수동 계산 | safeArea 자동 + 하단바만 수동 |

---

### Phase 4: PersonPageViewController contentInset 적용

**파일**: `PersonPageViewController.swift`

**변경 내용**:
1. `FaceComparisonDataSource` 프로토콜에 `contentInsetForGrid` 추가
2. iOS 버전별 `contentInsetAdjustmentBehavior` 분기:
   - iOS 16~25: `.never` (수동 inset 계산)
   - iOS 26+: `.automatic` (시스템 네비바 자동 처리)
3. `viewDidLayoutSubviews`에서 inset 적용

```swift
// FaceComparisonDataSource 프로토콜 확장
protocol FaceComparisonDataSource: AnyObject {
    // 기존 메서드들...

    /// 그리드 contentInset (플로팅 UI 높이 반영)
    var contentInsetForGrid: UIEdgeInsets { get }
}

// PersonPageViewController에서 적용
override func viewDidLoad() {
    super.viewDidLoad()

    // iOS 버전별 contentInsetAdjustmentBehavior 분기
    if #available(iOS 26.0, *) {
        collectionView.contentInsetAdjustmentBehavior = .automatic
    } else {
        collectionView.contentInsetAdjustmentBehavior = .never
    }
}

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()

    if let inset = dataSource?.contentInsetForGrid {
        collectionView.contentInset = inset
        collectionView.scrollIndicatorInsets = inset
    }
}
```

**FaceComparisonViewController에서 계산**:
```swift
var contentInsetForGrid: UIEdgeInsets {
    let safeAreaTop = view.safeAreaInsets.top
    let safeAreaBottom = view.safeAreaInsets.bottom

    let topInset: CGFloat
    let bottomInset: CGFloat

    if #available(iOS 26.0, *) {
        // .automatic이 safeArea 자동 처리하므로 제외
        topInset = 0
        bottomInset = 56 + 15  // bottomBarHeight + gradientExtension (safeArea 제외)
    } else {
        // .never이므로 safeArea 수동 추가
        topInset = safeAreaTop + 44 + 15
        bottomInset = safeAreaBottom + 56 + 15
    }

    return UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
}
```

---

### Phase 5: hitTest 조정 (터치 통과 방식)

**파일**: `FaceComparisonViews.swift`, `FaceComparisonViewController.swift`

**설계 결정**: `return nil` (터치 통과)

| 방식 | 그라데이션 영역에서 드래그 | 장점 | 단점 |
|------|---------------------------|------|------|
| `return self` | 스크롤 안 됨 | 버튼 오탭 방지 | 상단에서 스크롤 불가 |
| `return nil` ✅ | 스크롤 됨 | 전체 화면 스크롤 | - |

**선택 이유**:
- 그리드가 전체 화면이므로 어디서든 스크롤되어야 함
- 그라데이션은 시각적 효과일 뿐, 터치를 막을 이유 없음
- 기본 사진 앱과 동일한 UX

**변경 내용**:
- 타이틀바: 버튼만 터치 반응, 나머지는 터치 통과 (nil 반환)
- 하단바: 버튼만 터치 반응, 나머지는 터치 통과

```swift
// FaceComparisonTitleBar에 추가
override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // closeButton 영역 체크
    let closePoint = convert(point, to: closeButton)
    if closeButton.bounds.contains(closePoint) {
        return closeButton
    }

    // cycleButton 영역 체크
    let cyclePoint = convert(point, to: cycleButton)
    if cycleButton.bounds.contains(cyclePoint) {
        return cycleButton
    }

    // 나머지 영역은 터치 통과 → 아래 CollectionView로 전달
    return nil
}
```

---

## 수정 파일 목록

| 파일 | 변경 내용 | 예상 변경량 |
|------|----------|------------|
| `FaceComparisonViews.swift` | TitleBar에 blur + gradient + hitTest 추가 | +60줄 |
| `FaceComparisonViewController.swift` | 레이아웃 순서, 하단바 스타일, inset 계산, contentInsetForGrid 구현 | +40줄, 수정 30줄 |
| `PersonPageViewController.swift` | contentInset 적용, dataSource 프로토콜 확장 | +20줄 |

**총 예상**: 약 120줄 추가/수정

---

## 참고 파일

- `FloatingTitleBar.swift` - 그라데이션/블러 스타일 참조
- `AlbumsViewController.swift` - 레이아웃 패턴 참조
- `LiquidGlassStyle.swift` - maxDimAlpha 등 상수 참조

---

## 체크리스트

- [ ] Phase 1: FaceComparisonTitleBar 그라데이션 추가
- [ ] Phase 2: 하단바 그라데이션 스타일로 변경
- [ ] Phase 3: PageViewController 레이아웃 변경
- [ ] Phase 4: PersonPageViewController contentInset 적용
- [ ] Phase 5: hitTest 조정
- [ ] iOS 16~25 테스트
- [ ] iOS 26+ 테스트

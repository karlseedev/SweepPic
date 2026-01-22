# Liquid Glass 코드 스니펫 (실측 기반)

> iOS 26.0.1 Photos 앱 실측 데이터 기반 구현 코드

**관련 문서:**
- [260122LiquidGlass-Plan.md](./260122LiquidGlass-Plan.md) - 구현 계획
- [iOS26-LiquidGlass-Structure.md](./iOS26-LiquidGlass-Structure.md) - 공통 구조
- [iOS26-TabBar.md](./iOS26-TabBar.md) - TabBar 실측 스펙
- [iOS26-NavigationBar.md](./iOS26-NavigationBar.md) - NavigationBar 실측 스펙

---

## iOS 26 실제 구조 vs 커스텀 구현

### iOS 26 Private 구조
```
_UILiquidLensView
├── _UITabSelectionView (Selection Pill)
├── ClearGlassView (유리 효과)
│   └── CASDFLayer (SDF 기반 형태)
└── DestOutView (destOut 마스킹)
```

### iOS 16~25 커스텀 구현
```
UIView (Container)
├── UIVisualEffectView (블러)
├── UIView (배경 오버레이)
├── CAGradientLayer (Specular Highlight)
├── CAGradientLayer (Rim Light Border)
└── UIView (콘텐츠)
```

---

## 1. LiquidGlassStyle 상수 (실측 기반)

```swift
import UIKit

/// iOS 26 Liquid Glass 스타일 상수 (실측 기반)
enum LiquidGlassStyle {

    // MARK: - 배경 (실측: gray 0.11, alpha 0.73)

    static let backgroundGray: CGFloat = 0.11
    static let backgroundAlpha: CGFloat = 0.73

    static var backgroundColor: UIColor {
        UIColor(white: backgroundGray, alpha: backgroundAlpha)
    }

    // MARK: - cornerCurve (실측: continuous)

    static let cornerCurve: CALayerCornerCurve = .continuous

    // MARK: - TabBar Platter (실측)

    static let tabPlatterWidthRatio: CGFloat = 0.682    // 68.2%
    static let tabPlatterHeight: CGFloat = 62

    // MARK: - Tab Button (실측)

    static let tabButtonWidth: CGFloat = 94
    static let tabButtonHeight: CGFloat = 54
    static let tabButtonPadding: CGFloat = 4

    // MARK: - Selection Pill (실측)

    static let selectionPillWidth: CGFloat = 94
    static let selectionPillHeight: CGFloat = 54
    static let selectionPillCornerRadius: CGFloat = 27  // 높이/2

    // MARK: - Tab 아이콘/레이블 (실측)

    static let tabIconPointSize: CGFloat = 28           // 30~34pt 결과
    static let tabIconTopOffset: CGFloat = 5            // 4~7pt 중간값
    static let tabLabelHeight: CGFloat = 12
    static let tabLabelYPosition: CGFloat = 35
    static let tabLabelFontSize: CGFloat = 10

    // MARK: - NavigationBar 버튼 (실측)

    static let navButtonHeight: CGFloat = 44
    static let navButtonCornerRadius: CGFloat = 22      // 높이/2
    static let backButtonSize: CGFloat = 44

    // MARK: - NavigationBar 여백 (실측)

    static let navLeadingMargin: CGFloat = 16
    static let navTrailingMargin: CGFloat = 16
    static let navButtonSpacing: CGFloat = 12

    // MARK: - 플로팅 버튼 (실측)

    static let floatingButtonSize: CGFloat = 48         // 일반 삭제
    static let trashFloatingWidth: CGFloat = 54         // 휴지통 복구/삭제
    static let trashFloatingHeight: CGFloat = 48
    static let floatingBottomMargin: CGFloat = 76
    static let floatingSideMargin: CGFloat = 28         // 2개일 때
}
```

---

## 2. Selection Pill 구현

### 기본 구조

```swift
/// 탭 선택 시 표시되는 배경 pill
class SelectionPillView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStyle()
    }

    private func setupStyle() {
        // 실측 기반 스타일
        backgroundColor = LiquidGlassStyle.backgroundColor
        layer.cornerRadius = LiquidGlassStyle.selectionPillCornerRadius
        layer.cornerCurve = LiquidGlassStyle.cornerCurve
        layer.masksToBounds = false
    }
}
```

### 탭 전환 애니메이션

```swift
/// Selection Pill을 선택된 탭 위치로 이동
/// - Parameters:
///   - targetFrame: 선택된 탭 버튼의 frame
///   - animated: 애니메이션 여부
func moveSelectionPill(to targetFrame: CGRect, animated: Bool = true) {
    if animated {
        UIView.animate(
            withDuration: 0.35,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: [.beginFromCurrentState]
        ) {
            self.selectionPillView.frame = targetFrame
        }
    } else {
        selectionPillView.frame = targetFrame
    }
}
```

---

## 3. FloatingTabBar 레이아웃 (실측 기반)

### Platter 설정

```swift
private func setupPlatter() {
    let screenWidth = UIScreen.main.bounds.width

    // 실측 기반 크기
    let platterWidth = screenWidth * LiquidGlassStyle.tabPlatterWidthRatio
    let platterHeight = LiquidGlassStyle.tabPlatterHeight
    let platterX = (screenWidth - platterWidth) / 2

    capsuleContainer.frame = CGRect(
        x: platterX,
        y: 0,
        width: platterWidth,
        height: platterHeight
    )

    // cornerCurve 적용
    capsuleContainer.layer.cornerRadius = platterHeight / 2
    capsuleContainer.layer.cornerCurve = LiquidGlassStyle.cornerCurve
}
```

### Tab Button 레이아웃

```swift
private func layoutTabButtons() {
    let buttonWidth = LiquidGlassStyle.tabButtonWidth
    let buttonHeight = LiquidGlassStyle.tabButtonHeight
    let padding = LiquidGlassStyle.tabButtonPadding

    // 3개 탭 위치 (실측 기반)
    // 탭 1: x=4, 탭 2: x=90, 탭 3: x=176
    let tabPositions: [CGFloat] = [4, 90, 176]

    for (index, button) in tabButtons.enumerated() {
        button.frame = CGRect(
            x: tabPositions[index],
            y: padding,
            width: buttonWidth,
            height: buttonHeight
        )
    }
}
```

### Tab Button 구성

```swift
private func configureTabButton(_ button: UIButton, icon: String, title: String) {
    var config = UIButton.Configuration.plain()

    // 아이콘 (실측: 30~34pt)
    config.image = UIImage(systemName: icon)
    config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
        pointSize: LiquidGlassStyle.tabIconPointSize
    )

    // 레이블 (실측: 높이 12pt, 폰트 ~10pt)
    config.title = title
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
        var outgoing = incoming
        outgoing.font = .systemFont(ofSize: LiquidGlassStyle.tabLabelFontSize, weight: .medium)
        return outgoing
    }

    // 아이콘-레이블 배치
    config.imagePlacement = .top
    config.imagePadding = 0  // 실측: 거의 붙어있음

    button.configuration = config
}
```

---

## 4. NavigationBar 버튼 (실측 기반)

### Back 버튼 (44×44pt)

```swift
private func setupBackButton() -> UIButton {
    let button = UIButton(type: .system)

    // 실측 기반 크기
    button.frame = CGRect(
        x: LiquidGlassStyle.navLeadingMargin,
        y: 0,
        width: LiquidGlassStyle.backButtonSize,
        height: LiquidGlassStyle.backButtonSize
    )

    // 스타일
    button.layer.cornerRadius = LiquidGlassStyle.navButtonCornerRadius
    button.layer.cornerCurve = LiquidGlassStyle.cornerCurve
    button.backgroundColor = LiquidGlassStyle.backgroundColor

    // 아이콘
    let config = UIImage.SymbolConfiguration(pointSize: 17, weight: .semibold)
    button.setImage(UIImage(systemName: "chevron.left", withConfiguration: config), for: .normal)

    return button
}
```

### 텍스트 버튼 (Select, Cancel 등)

```swift
private func setupTextButton(title: String, tintColor: UIColor) -> UIButton {
    let button = UIButton(type: .system)

    var config = UIButton.Configuration.plain()
    config.title = title
    config.baseForegroundColor = tintColor
    config.contentInsets = NSDirectionalEdgeInsets(
        top: 0, leading: 16, bottom: 0, trailing: 16
    )

    button.configuration = config

    // 실측 기반 높이
    button.heightAnchor.constraint(equalToConstant: LiquidGlassStyle.navButtonHeight).isActive = true

    // 스타일
    button.layer.cornerRadius = LiquidGlassStyle.navButtonCornerRadius
    button.layer.cornerCurve = LiquidGlassStyle.cornerCurve
    button.backgroundColor = LiquidGlassStyle.backgroundColor

    return button
}
```

### 우측 버튼 배치 (실측 기반)

```swift
private func layoutRightButtons() {
    // Select 버튼 (우측 끝)
    selectButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        selectButton.trailingAnchor.constraint(
            equalTo: trailingAnchor,
            constant: -LiquidGlassStyle.navTrailingMargin
        ),
        selectButton.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])

    // Cancel 버튼 (Select 왼쪽, 12pt 간격)
    cancelButton.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        cancelButton.trailingAnchor.constraint(
            equalTo: selectButton.leadingAnchor,
            constant: -LiquidGlassStyle.navButtonSpacing
        ),
        cancelButton.centerYAnchor.constraint(equalTo: centerYAnchor)
    ])
}
```

---

## 5. 플로팅 버튼 (실측 기반)

### 일반 뷰어 삭제 버튼 (48×48pt, 중앙)

```swift
private func setupDeleteButton() {
    let buttonSize = LiquidGlassStyle.floatingButtonSize
    let bottomMargin = LiquidGlassStyle.floatingBottomMargin

    deleteButton.frame = CGRect(
        x: (view.bounds.width - buttonSize) / 2,
        y: view.bounds.height - bottomMargin - buttonSize,
        width: buttonSize,
        height: buttonSize
    )

    deleteButton.layer.cornerRadius = buttonSize / 2
    deleteButton.layer.cornerCurve = LiquidGlassStyle.cornerCurve
    deleteButton.backgroundColor = LiquidGlassStyle.backgroundColor
}
```

### 휴지통 뷰어 버튼 (54×48pt, 좌우 배치)

```swift
private func setupTrashViewerButtons() {
    let buttonWidth = LiquidGlassStyle.trashFloatingWidth
    let buttonHeight = LiquidGlassStyle.trashFloatingHeight
    let sideMargin = LiquidGlassStyle.floatingSideMargin
    let bottomMargin = LiquidGlassStyle.floatingBottomMargin
    let buttonY = view.bounds.height - bottomMargin - buttonHeight

    // 복구 버튼 (좌측)
    restoreButton.frame = CGRect(
        x: sideMargin,
        y: buttonY,
        width: buttonWidth,
        height: buttonHeight
    )

    // 삭제 버튼 (우측)
    permanentDeleteButton.frame = CGRect(
        x: view.bounds.width - sideMargin - buttonWidth,
        y: buttonY,
        width: buttonWidth,
        height: buttonHeight
    )

    // 스타일
    [restoreButton, permanentDeleteButton].forEach { button in
        button.layer.cornerRadius = buttonHeight / 2
        button.layer.cornerCurve = LiquidGlassStyle.cornerCurve
        button.backgroundColor = LiquidGlassStyle.backgroundColor
    }
}
```

---

## 6. GlassButton 개선

### 크기 타입

```swift
enum GlassButtonSizeType {
    case navBar         // 44pt 높이
    case floatingSmall  // 48×48pt
    case floatingLarge  // 54×48pt

    var size: CGSize {
        switch self {
        case .navBar:
            return CGSize(width: 44, height: 44)
        case .floatingSmall:
            return CGSize(width: 48, height: 48)
        case .floatingLarge:
            return CGSize(width: 54, height: 48)
        }
    }

    var cornerRadius: CGFloat {
        switch self {
        case .navBar:
            return 22
        case .floatingSmall:
            return 24
        case .floatingLarge:
            return 24
        }
    }
}
```

### 초기화

```swift
class GlassButton: UIButton {

    private let sizeType: GlassButtonSizeType

    init(sizeType: GlassButtonSizeType, tintColor: UIColor) {
        self.sizeType = sizeType
        super.init(frame: .zero)
        setupStyle(tintColor: tintColor)
    }

    private func setupStyle(tintColor: UIColor) {
        // 실측 기반 배경
        backgroundColor = LiquidGlassStyle.backgroundColor

        // cornerRadius & cornerCurve
        layer.cornerRadius = sizeType.cornerRadius
        layer.cornerCurve = LiquidGlassStyle.cornerCurve

        // 크기 제약
        let size = sizeType.size
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size.width),
            heightAnchor.constraint(equalToConstant: size.height)
        ])

        // 틴트
        self.tintColor = tintColor
    }
}
```

---

## 7. Spring 애니메이션 (AnimationView 패턴)

### iOS 26 실측 스케일 패턴

```
외곽 확장: 48.2 / 44 = 1.095 (약 9.5% 확장)
내부 축소: 40.2 / 44 = 0.913 (약 8.7% 축소)
```

### Press 애니메이션 구현

```swift
extension UIView {
    /// iOS 26 스타일 press 애니메이션
    /// - Parameter isPressed: 눌림 상태
    func animatePress(_ isPressed: Bool) {
        let scale: CGFloat = isPressed ? 0.913 : 1.0  // 실측 기반

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0.5,
            options: [.beginFromCurrentState]
        ) {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    }
}
```

### 사용 예시

```swift
class GlassButton: UIButton {

    override var isHighlighted: Bool {
        didSet {
            animatePress(isHighlighted)
        }
    }
}
```

---

## 8. 접근성 대응

```swift
extension LiquidGlassStyle {

    /// 접근성 설정에 맞는 배경 alpha
    static var accessibleBackgroundAlpha: CGFloat {
        if UIAccessibility.isReduceTransparencyEnabled {
            return 0.9  // 더 불투명
        }
        return backgroundAlpha  // 기본 0.73
    }

    /// 접근성 설정에 맞는 배경색
    static var accessibleBackgroundColor: UIColor {
        UIColor(white: backgroundGray, alpha: accessibleBackgroundAlpha)
    }

    /// 모션 감소 설정 여부
    static var shouldReduceMotion: Bool {
        UIAccessibility.isReduceMotionEnabled
    }
}
```

### 사용 예시

```swift
// 배경색 적용
button.backgroundColor = LiquidGlassStyle.accessibleBackgroundColor

// 애니메이션
if LiquidGlassStyle.shouldReduceMotion {
    selectionPillView.frame = targetFrame  // 즉시 변경
} else {
    moveSelectionPill(to: targetFrame, animated: true)
}
```

---

## 9. UIVisualEffectView 블러 설정

### 실측 기반 블러 구조

```swift
private func setupBlurEffect() {
    // 실측: UIBlurEffect(style: .dark)
    let blurEffect = UIBlurEffect(style: .dark)
    let blurView = UIVisualEffectView(effect: blurEffect)
    blurView.frame = bounds
    blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

    // cornerRadius (실측: 12pt for popup, 31pt for platter)
    blurView.layer.cornerRadius = layer.cornerRadius
    blurView.layer.cornerCurve = LiquidGlassStyle.cornerCurve
    blurView.clipsToBounds = true

    insertSubview(blurView, at: 0)
}
```

---

## 10. 전체 Glass View 조합

```swift
class LiquidGlassView: UIView {

    private var blurView: UIVisualEffectView!

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        // 1. 블러
        let blur = UIBlurEffect(style: .dark)
        blurView = UIVisualEffectView(effect: blur)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)

        // 2. 배경 오버레이 (실측 기반)
        let overlay = UIView()
        overlay.backgroundColor = LiquidGlassStyle.backgroundColor
        overlay.frame = bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(overlay)

        // 3. cornerCurve
        layer.cornerCurve = LiquidGlassStyle.cornerCurve
        layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        blurView.layer.cornerRadius = layer.cornerRadius
    }
}
```

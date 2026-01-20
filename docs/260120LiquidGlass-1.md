# PickPhoto iOS 16~25 커스텀 UI → Liquid Glass 스타일 변환 계획

## 개요
iOS 16~25에서 사용하는 커스텀 UI (FloatingTabBar, FloatingTitleBar, Viewer 버튼 등)의 **디자인을 Liquid Glass 스타일로 변경**합니다.

- **iOS 26+**: 기존 그대로 유지 (시스템 UI 사용) - **변경 없음**
- **iOS 16~25**: 커스텀 UI 유지, **스타일만 Liquid Glass로 변경**

---

## Liquid Glass 스타일 핵심 특성 (UIKit 구현)

| 특성 | 현재 스타일 | Liquid Glass 스타일 |
|------|------------|---------------------|
| 블러 | `.systemThinMaterialDark` | `.systemUltraThinMaterialDark` (더 투명) |
| 배경 오버레이 | `UIColor(white: 0.12, alpha: 0.5)` | 제거 또는 매우 연하게 |
| 테두리 | 0.5pt white 15% | 0.5pt white 20~25% (더 선명) |
| 그림자 | 검정, 12pt blur, 6pt offset | 더 부드럽고 확산된 그림자 |
| 코너 | 28pt (캡슐) | 동일 유지 |
| 탭 아이콘 | 18pt | 24pt (iOS 26 기준) |
| 액션 버튼 아이콘 | 22pt | 22pt (유지) |
| 백 버튼 아이콘 | 20pt | 20pt (유지) |
| 버튼 배경 | 단색 반투명 (systemRed 90%) | 블러 배경 + tint |
| 스펙큘러 하이라이트 | 없음 | **버튼만 적용** - 상단 그라데이션 (alpha 0.12) |
| 아이콘 대비 보정 | 없음 | **버튼만 적용** - 약한 아이콘 그림자 |

---

## 디자인 퀄리티 보강 (다크 테마 기준)

### 적용 범위

| 컴포넌트 | 스펙큘러 하이라이트 | 아이콘 그림자 |
|---------|-------------------|--------------|
| FloatingTabBar (바 자체) | ❌ 미적용 | - |
| FloatingTitleBar (바 자체) | ❌ 미적용 | - |
| 액션 버튼 (삭제/복구 등) | ✅ 적용 | ✅ 적용 |
| 백 버튼 | ✅ 적용 | ✅ 적용 |
| Select 버튼 | ✅ 적용 | ✅ 적용 |
| Select 모드 Delete 버튼 | ✅ 적용 | ✅ 적용 |

> **이유**: FloatingTabBar/TitleBar는 블러+테두리만으로 유리감이 충분하며, 스펙큘러 하이라이트까지 추가하면 과도해 보임

### 세부 사항

- **스펙큘러 하이라이트**: 버튼 상단 45% 영역에 얇은 화이트 그라데이션 (alpha 0.12→0.0)
- **아이콘 대비**: 흰색 아이콘에 약한 그림자 (blur 3, alpha 0.35)
- **핵심 버튼 강조**: 중요 액션만 shadowOpacity 0.26, shadowRadius 18로 소폭 강화 (옵션)

---

## Phase 1: FloatingTabBar.swift Liquid Glass 스타일 적용

**파일**: `PickPhoto/PickPhoto/Shared/Components/FloatingTabBar.swift`

### 1.1 블러 효과 변경
```swift
// 현재
let effect = UIBlurEffect(style: .systemThinMaterialDark)

// 변경 → 더 투명한 블러
let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
```

### 1.2 배경 오버레이 제거/약화
```swift
// 현재
view.backgroundColor = UIColor(white: 0.12, alpha: 0.5)

// 변경 → 제거 또는 매우 연하게 (LiquidGlassStyle.backgroundAlpha 사용)
view.backgroundColor = UIColor(white: 0.1, alpha: LiquidGlassStyle.backgroundAlpha)
```

### 1.3 테두리 강화
```swift
// 현재
view.layer.borderColor = UIColor.white.withAlphaComponent(0.15).cgColor

// 변경 → 더 선명한 테두리 (Specular highlight 효과)
view.layer.borderColor = UIColor.white.withAlphaComponent(0.25).cgColor
```

### 1.4 그림자 조정
```swift
// 현재
view.layer.shadowOpacity = 0.25
view.layer.shadowRadius = 12
view.layer.shadowOffset = CGSize(width: 0, height: 6)

// 변경 → 더 부드럽고 확산된 그림자
view.layer.shadowOpacity = 0.2
view.layer.shadowRadius = 16
view.layer.shadowOffset = CGSize(width: 0, height: 4)
```

### 1.5 아이콘 크기 변경
```swift
// 현재
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .regular)

// 변경 → iOS 26 기준 크기
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24, weight: .regular)
```

### 1.6 그라데이션 딤 조정
```swift
// 현재: 최대 60% 알파
private static let maxDimAlpha: CGFloat = 0.6

// 변경 → 더 투명하게 (Liquid Glass는 배경이 더 보임)
private static let maxDimAlpha: CGFloat = 0.45
```

---

## Phase 2: FloatingTitleBar.swift Liquid Glass 스타일 적용

**파일**: `PickPhoto/PickPhoto/Shared/Components/FloatingTitleBar.swift`

### 2.1 블러 효과 변경
```swift
// VariableBlurView 설정에서
// 현재: maxBlurRadius = 2.0, dimmingAlpha = 0.5

// 변경 → 더 투명한 효과
maxBlurRadius = 1.5
dimmingAlpha = 0.3
```

### 2.2 그라데이션 딤 조정
```swift
// 현재: 상단 60% 알파
// 변경 → 더 투명하게
// 상단: 45% 알파 → 하단: 투명
```

### 2.3 Select 버튼 Glass 스타일

```swift
// 현재
config.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
config.cornerStyle = .capsule

// 변경 → GlassButton 서브클래스 사용 (캡슐 형태 유지)
```

#### GlassButton 서브클래스 (신규 파일: `GlassButton.swift`)

```swift
import UIKit

/// Liquid Glass 스타일 버튼 (iOS 16~25용)
/// - 블러 배경 + tint 오버레이 + 스펙큘러 하이라이트
/// - layoutSubviews에서 cornerRadius/frame 자동 갱신
final class GlassButton: UIButton {

    // MARK: - Properties (레이어 참조 유지)
    private let blurView: UIVisualEffectView
    private let tintView: UIView
    private var highlightLayer: CAGradientLayer?

    private let overlayTintColor: UIColor
    private let useCapsuleStyle: Bool

    // MARK: - Init
    init(tintColor: UIColor, useCapsuleStyle: Bool = false) {
        self.overlayTintColor = tintColor
        self.useCapsuleStyle = useCapsuleStyle

        // 블러 배경 (cornerRadius는 layoutSubviews에서 설정)
        let effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        self.blurView = UIVisualEffectView(effect: effect)
        blurView.isUserInteractionEnabled = false
        blurView.clipsToBounds = true

        // tint 오버레이
        self.tintView = UIView()
        tintView.backgroundColor = overlayTintColor.withAlphaComponent(LiquidGlassStyle.tintAlpha)
        tintView.isUserInteractionEnabled = false

        super.init(frame: .zero)

        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupViews() {
        // 블러 배경 추가
        insertSubview(blurView, at: 0)

        // tint 오버레이 추가
        blurView.contentView.addSubview(tintView)

        // 스펙큘러 하이라이트 (한 번만 생성, 참조 유지)
        highlightLayer = LiquidGlassStyle.createSpecularHighlightLayer()
        blurView.contentView.layer.addSublayer(highlightLayer!)

        // 테두리
        layer.borderWidth = LiquidGlassStyle.borderWidth
        layer.borderColor = UIColor.white.withAlphaComponent(LiquidGlassStyle.borderAlpha).cgColor
    }

    // MARK: - Layout (cornerRadius/frame 갱신)
    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = useCapsuleStyle ? bounds.height / 2 : LiquidGlassStyle.defaultCornerRadius

        // 블러 뷰 frame + cornerRadius
        blurView.frame = bounds
        blurView.layer.cornerRadius = cornerRadius

        // tint 뷰 frame + cornerRadius
        tintView.frame = blurView.contentView.bounds
        tintView.layer.cornerRadius = cornerRadius

        // 하이라이트 레이어 frame + cornerRadius (기존 레이어 재사용)
        highlightLayer?.frame = blurView.contentView.bounds
        highlightLayer?.cornerRadius = cornerRadius

        // 버튼 자체 cornerRadius
        layer.cornerRadius = cornerRadius

        // 그림자 (shadowPath 포함, bounds 변경 시 갱신)
        LiquidGlassStyle.applyShadow(to: layer, cornerRadius: cornerRadius)
    }
}
```

#### 사용 예시
```swift
// FloatingTitleBar에서 Select 버튼 생성
private lazy var selectButton: GlassButton = {
    let button = GlassButton(tintColor: .systemBlue, useCapsuleStyle: true)
    button.setTitle("Select", for: .normal)
    button.setTitleColor(.white, for: .normal)
    button.titleLabel?.font = .systemFont(ofSize: 15, weight: .medium)
    button.contentEdgeInsets = UIEdgeInsets(top: 8, left: 16, bottom: 8, right: 16)
    return button
}()
```

> **Note**: Select 버튼은 캡슐 형태(`useCapsuleStyle: true`)를 사용합니다. cornerRadius는 `layoutSubviews`에서 `bounds.height / 2`로 동적 계산됩니다.

---

## Phase 3: ViewerViewController.swift 버튼 Liquid Glass 스타일

**파일**: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`

### 3.1 삭제/복구/완전삭제 버튼 스타일 변경

```swift
// 현재: 단색 반투명 배경
button.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)

// 변경 → GlassButton 서브클래스 사용
```

#### GlassButton 활용

`GlassButton` 서브클래스를 사용하여 모든 버튼을 일관되게 생성합니다:

```swift
/// Glass 스타일 액션 버튼 생성 헬퍼
private func createGlassActionButton(tintColor: UIColor, icon: String) -> GlassButton {
    let button = GlassButton(tintColor: tintColor, useCapsuleStyle: false)
    button.translatesAutoresizingMaskIntoConstraints = false

    // 아이콘 설정
    let config = UIImage.SymbolConfiguration(
        pointSize: LiquidGlassStyle.actionButtonIconSize,
        weight: .medium
    )
    let image = UIImage(systemName: icon, withConfiguration: config)
    button.setImage(image, for: .normal)
    button.tintColor = .white

    // 아이콘 그림자 적용
    if let imageView = button.imageView {
        LiquidGlassStyle.applyIconShadow(to: imageView)
    }

    return button
}
```

### 3.2 버튼 생성 코드 변경

```swift
// 삭제 버튼
private lazy var deleteButton: GlassButton = {
    return createGlassActionButton(tintColor: .systemRed, icon: "trash.fill")
}()

// 복구 버튼
private lazy var restoreButton: GlassButton = {
    return createGlassActionButton(tintColor: .systemGreen, icon: "arrow.uturn.backward")
}()

// 완전삭제 버튼
private lazy var permanentDeleteButton: GlassButton = {
    return createGlassActionButton(tintColor: .systemRed, icon: "trash.fill")
}()
```

### 3.3 백 버튼 Glass 스타일

```swift
// 현재
button.backgroundColor = UIColor.black.withAlphaComponent(0.5)

// 변경 → GlassButton 서브클래스 사용 (tintColor: .clear로 tint 없음)
```

#### 백 버튼 구현

```swift
private lazy var backButton: GlassButton = {
    // tint 없는 순수한 glass 스타일
    let button = GlassButton(tintColor: .clear, useCapsuleStyle: false)
    button.translatesAutoresizingMaskIntoConstraints = false

    // 아이콘 설정 (backButtonIconSize: 20pt)
    let config = UIImage.SymbolConfiguration(
        pointSize: LiquidGlassStyle.backButtonIconSize,
        weight: .semibold
    )
    button.setImage(UIImage(systemName: "chevron.backward", withConfiguration: config), for: .normal)
    button.tintColor = .white

    // 아이콘 그림자 적용
    if let imageView = button.imageView {
        LiquidGlassStyle.applyIconShadow(to: imageView)
    }

    return button
}()

private func setupBackButton() {
    view.addSubview(backButton)
    NSLayoutConstraint.activate([
        backButton.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
        backButton.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: 16),
        backButton.widthAnchor.constraint(equalToConstant: 36),
        backButton.heightAnchor.constraint(equalToConstant: 36)
    ])
}
```

> **Note**: 백 버튼은 `tintColor: .clear`를 사용하여 tint 오버레이 없이 순수한 glass 스타일만 적용합니다.

---

## Phase 4: Select 모드 툴바 Glass 스타일

### 4.1 FloatingTabBar Select 모드 Delete 버튼

```swift
// 현재
config.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.3)

// 변경 → GlassButton 서브클래스 사용
```

#### 구현 방법

Select 모드 Delete 버튼도 `GlassButton` 서브클래스를 활용합니다:

```swift
// FloatingTabBar.swift에서 Select 모드 Delete 버튼 생성
private lazy var selectModeDeleteButton: GlassButton = {
    let button = GlassButton(tintColor: .systemRed, useCapsuleStyle: false)
    button.translatesAutoresizingMaskIntoConstraints = false

    // 아이콘 설정
    let config = UIImage.SymbolConfiguration(
        pointSize: LiquidGlassStyle.actionButtonIconSize,
        weight: .medium
    )
    let image = UIImage(systemName: "trash.fill", withConfiguration: config)
    button.setImage(image, for: .normal)
    button.tintColor = .white

    // 아이콘 그림자 적용
    if let imageView = button.imageView {
        LiquidGlassStyle.applyIconShadow(to: imageView)
    }

    return button
}()
```

### 4.2 Select 모드 Share 버튼

```swift
private lazy var selectModeShareButton: GlassButton = {
    let button = GlassButton(tintColor: .systemBlue, useCapsuleStyle: false)
    button.translatesAutoresizingMaskIntoConstraints = false

    let config = UIImage.SymbolConfiguration(
        pointSize: LiquidGlassStyle.actionButtonIconSize,
        weight: .medium
    )
    let image = UIImage(systemName: "square.and.arrow.up", withConfiguration: config)
    button.setImage(image, for: .normal)
    button.tintColor = .white

    if let imageView = button.imageView {
        LiquidGlassStyle.applyIconShadow(to: imageView)
    }

    return button
}()
```

### 4.3 Select 모드 레이아웃

```swift
// Select 모드 진입 시 버튼 전환
func enterSelectMode() {
    // 기존 탭 버튼 숨김
    tabButtonStackView.isHidden = true

    // Select 모드 버튼 표시
    selectModeStackView.isHidden = false
}

func exitSelectMode() {
    tabButtonStackView.isHidden = false
    selectModeStackView.isHidden = true
}
```

---

## 스타일 상수 정리 (LiquidGlassStyle.swift 신규 파일)

**경로**: `PickPhoto/PickPhoto/Shared/Styles/LiquidGlassStyle.swift`

```swift
import UIKit

/// iOS 16~25용 Liquid Glass 스타일 상수
enum LiquidGlassStyle {

    // MARK: - Blur
    static let blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark

    // MARK: - Corner Radius
    static let defaultCornerRadius: CGFloat = 18

    // MARK: - Border (Specular Highlight)
    static let borderWidth: CGFloat = 0.5
    static let borderAlpha: CGFloat = 0.25

    // MARK: - Shadow
    static let shadowOpacity: Float = 0.2
    static let shadowRadius: CGFloat = 16
    static let shadowOffset = CGSize(width: 0, height: 4)

    // MARK: - Background Overlay
    static let backgroundAlpha: CGFloat = 0.15

    // MARK: - Tint
    static let tintAlpha: CGFloat = 0.25

    // MARK: - Gradient Dim
    static let maxDimAlpha: CGFloat = 0.45

    // MARK: - Icon Size
    static let tabIconSize: CGFloat = 24
    static let actionButtonIconSize: CGFloat = 22
    static let backButtonIconSize: CGFloat = 20

    // MARK: - Factory Methods

    /// Glass 스타일 블러 뷰 생성
    static func createBlurView(cornerRadius: CGFloat) -> UIVisualEffectView {
        let effect = UIBlurEffect(style: blurStyle)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = cornerRadius
        view.clipsToBounds = true
        view.isUserInteractionEnabled = false
        return view
    }

    /// Glass 스타일 테두리 적용
    static func applyBorder(to layer: CALayer, cornerRadius: CGFloat) {
        layer.borderWidth = borderWidth
        layer.borderColor = UIColor.white.withAlphaComponent(borderAlpha).cgColor
        layer.cornerRadius = cornerRadius
    }

    /// Glass 스타일 그림자 적용 (원형 버튼용 shadowPath 포함)
    static func applyShadow(to layer: CALayer, cornerRadius: CGFloat? = nil) {
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = shadowOffset

        // shadowPath 설정 (성능 최적화)
        if let radius = cornerRadius, layer.bounds.width > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: layer.bounds,
                cornerRadius: radius
            ).cgPath
        }
    }

    /// Tint 오버레이 뷰 생성
    static func createTintOverlay(color: UIColor, cornerRadius: CGFloat) -> UIView {
        let view = UIView()
        view.backgroundColor = color.withAlphaComponent(tintAlpha)
        view.layer.cornerRadius = cornerRadius
        view.isUserInteractionEnabled = false
        return view
    }

    // MARK: - Specular Highlight (퀄리티 보강)

    /// 스펙큘러 하이라이트 상수
    static let highlightTopAlpha: CGFloat = 0.12
    static let highlightBottomAlpha: CGFloat = 0.0
    static let highlightEndLocation: CGFloat = 0.45

    /// 스펙큘러 하이라이트 레이어 생성 (재사용 가능)
    /// - Note: 반환된 레이어를 프로퍼티에 보관하고 layoutSubviews에서 frame/cornerRadius 업데이트
    /// - Warning: 이 메서드를 layoutSubviews에서 직접 호출하면 레이어가 누적됨!
    static func createSpecularHighlightLayer() -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.white.withAlphaComponent(highlightTopAlpha).cgColor,
            UIColor.white.withAlphaComponent(highlightBottomAlpha).cgColor
        ]
        layer.locations = [0.0, NSNumber(value: Double(highlightEndLocation))]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.masksToBounds = true
        return layer
    }

    /// 스펙큘러 하이라이트 레이어 frame/cornerRadius 업데이트
    /// - Parameter layer: createSpecularHighlightLayer()로 생성한 레이어
    /// - Parameter bounds: 부모 뷰의 bounds
    /// - Parameter cornerRadius: 적용할 cornerRadius
    static func updateSpecularHighlightLayout(
        layer: CAGradientLayer,
        bounds: CGRect,
        cornerRadius: CGFloat
    ) {
        layer.frame = bounds
        layer.cornerRadius = cornerRadius
    }

    // MARK: - Icon Shadow (아이콘 대비 보정)

    /// 아이콘 그림자 상수
    static let iconShadowOpacity: Float = 0.35
    static let iconShadowRadius: CGFloat = 3
    static let iconShadowOffset = CGSize(width: 0, height: 1)

    /// 아이콘에 약한 그림자 적용 (반투명 배경에서 가독성 확보)
    /// - Note: shadowPath는 이미지 변경 시마다 업데이트 필요하므로 생략
    static func applyIconShadow(to imageView: UIImageView) {
        imageView.layer.shadowColor = UIColor.black.cgColor
        imageView.layer.shadowOpacity = iconShadowOpacity
        imageView.layer.shadowRadius = iconShadowRadius
        imageView.layer.shadowOffset = iconShadowOffset
    }
}
```

### 스펙큘러 하이라이트 사용 패턴 (중요)

```swift
// ✅ 올바른 사용: 한 번만 생성하고 참조 유지
class MyGlassView: UIView {
    private var highlightLayer: CAGradientLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 초기화 시 한 번만 생성
        highlightLayer = LiquidGlassStyle.createSpecularHighlightLayer()
        layer.addSublayer(highlightLayer!)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 레이아웃 시 frame/cornerRadius만 업데이트
        if let highlightLayer = highlightLayer {
            LiquidGlassStyle.updateSpecularHighlightLayout(
                layer: highlightLayer,
                bounds: bounds,
                cornerRadius: layer.cornerRadius
            )
        }
    }
}

// ❌ 잘못된 사용: layoutSubviews에서 매번 생성 → 레이어 누적!
override func layoutSubviews() {
    super.layoutSubviews()
    // 이렇게 하면 안 됨!
    LiquidGlassStyle.createSpecularHighlightLayer() // 매번 새 레이어 추가
}
```

---

## 크기/스타일 매핑 요약

| 컴포넌트 | 현재 | Liquid Glass 스타일 |
|---------|------|---------------------|
| **블러** | `.systemThinMaterialDark` | `.systemUltraThinMaterialDark` |
| **배경 오버레이** | `alpha: 0.5` | `alpha: 0.15` |
| **테두리** | `white 15%` | `white 25%` |
| **그림자** | `12pt blur, 6pt offset` | `16pt blur, 4pt offset` + shadowPath |
| **탭 아이콘** | 18pt | 24pt |
| **액션 버튼 아이콘** | 22pt | 22pt (유지) |
| **백 버튼 아이콘** | 20pt | 20pt (유지) |
| **딤 그라데이션** | 최대 60% | 최대 45% |
| **버튼 배경** | 단색 반투명 | `GlassButton` 서브클래스 (블러 + tint) |
| **스펙큘러 하이라이트** | 없음 | 버튼만 - 상단 그라데이션 (alpha 0.12) |
| **아이콘 대비 보정** | 없음 | 버튼만 - 약한 아이콘 그림자 (blur 3, alpha 0.35) |

---

## 구현 순서

1. **Phase 0**: `LiquidGlassStyle.swift` 생성 (스타일 상수 중앙화)
2. **Phase 0.5**: `GlassButton.swift` 생성 (재사용 가능한 버튼 서브클래스)
3. **Phase 1**: `FloatingTabBar.swift` 스타일 변경
4. **Phase 2**: `FloatingTitleBar.swift` 스타일 변경
5. **Phase 3**: `ViewerViewController.swift` 버튼 스타일 변경
6. **Phase 4**: Select 모드 UI 스타일 변경
7. **테스트**: iOS 16~25 시뮬레이터에서 확인 (아래 체크리스트 참조)

---

## 수정 파일 목록

| 파일 | 작업 |
|------|------|
| **신규** `Shared/Styles/LiquidGlassStyle.swift` | 스타일 상수 및 팩토리 메서드 |
| **신규** `Shared/Components/GlassButton.swift` | 재사용 가능한 Glass 스타일 버튼 서브클래스 |
| `FloatingTabBar.swift` | 블러, 배경, 테두리, 그림자, 아이콘 크기 변경 |
| `FloatingTitleBar.swift` | 블러, 그라데이션, Select 버튼 → GlassButton 교체 |
| `ViewerViewController.swift` | 삭제/복구/백 버튼 → GlassButton 교체 |

---

## 변경 없는 파일

- `TabBarController.swift` - iOS 26 분기 로직 그대로 유지
- `FloatingOverlayContainer.swift` - 컨테이너 구조 그대로 유지
- `BarsVisibilityControlling.swift` - 그대로 유지

---

## 테스트 체크리스트

### 시각적 테스트

- [ ] **블러 투명도**: 배경 이미지가 기존보다 더 잘 보이는지 확인
- [ ] **테두리 선명도**: 0.25 alpha 테두리가 유리 경계처럼 보이는지 확인
- [ ] **스펙큘러 하이라이트**: 버튼 상단에 미묘한 광택이 보이는지 확인
- [ ] **아이콘 가독성**: 반투명 배경에서 아이콘 그림자가 대비를 높이는지 확인

### 배경 색상별 테스트

- [ ] **어두운 배경**: 밤 사진, 검정 배경에서 버튼 가독성
- [ ] **밝은 배경**: 하늘, 흰 벽 사진에서 버튼 가독성
- [ ] **다채로운 배경**: 다양한 색상이 포함된 사진에서 전체적인 조화

### 기능 테스트

- [ ] **버튼 터치 반응**: GlassButton 터치 영역이 정상 동작하는지
- [ ] **Select 모드 전환**: 진입/퇴장 시 버튼이 올바르게 표시/숨김
- [ ] **화면 회전**: 가로/세로 전환 시 레이아웃 깨짐 없음
- [ ] **기기별 테스트**: iPhone SE ~ iPhone 15 Pro Max 다양한 화면 크기

### 성능 테스트

- [ ] **메모리**: 스펙큘러 하이라이트 레이어 누적 없음 (Instruments로 확인)
- [ ] **스크롤 성능**: 그리드 뷰 스크롤 시 프레임 드랍 없음
- [ ] **shadowPath 효과**: 그림자 렌더링 성능 저하 없음

### iOS 버전별 테스트

- [ ] **iOS 16**: 최소 지원 버전에서 정상 동작
- [ ] **iOS 17**: 중간 버전 확인
- [ ] **iOS 18**: 최신 안정 버전 확인
- [ ] **iOS 26**: 시스템 UI 사용 (변경 없음) 확인

---

## 참고 자료

- [iOS 26 Liquid Glass: Comprehensive Reference](https://medium.com/@madebyluddy/overview-37b3685227aa)
- [Designing custom UI with Liquid Glass on iOS 26 - Donny Wals](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
- [WWDC25 - Meet Liquid Glass](https://developer.apple.com/videos/play/wwdc2025/219/)

---

## 추가 고려사항

### Select 모드 체크마크 UI

Select 모드에서 선택된 아이템을 표시하는 체크마크 UI도 Liquid Glass 스타일 일관성을 맞출지 검토 필요:
- 현재: 단색 원형 체크마크
- 변경 옵션: Glass 스타일 체크마크 (블러 + 테두리)

> 우선순위 낮음. Phase 1~4 완료 후 필요시 검토.

---

## Phase 5 (옵션): Vibrancy 효과 적용

> **전제조건**: Phase 1~4 완료 후 진행

### 개요

현재 아이콘 가독성을 위해 그림자(`applyIconShadow`)를 사용하지만, `UIVibrancyEffectView`를 활용하면 더 세련된 유리 질감을 표현할 수 있음.

### 현재 방식 vs Vibrancy 방식

| 항목 | 현재 (그림자) | Vibrancy |
|------|--------------|----------|
| 구현 복잡도 | 낮음 | 높음 |
| 시각적 효과 | 아이콘 뒤에 그림자 | 배경에 반응하는 반투명 효과 |
| 아이콘 색상 제어 | 자유로움 | 제한적 (vibrancy가 색상 결정) |
| Liquid Glass 느낌 | 보통 | 높음 |

### 구현 방법

```swift
/// Vibrancy 효과가 적용된 Glass 버튼
final class VibrancyGlassButton: UIButton {

    private let blurView: UIVisualEffectView
    private let vibrancyView: UIVisualEffectView
    private let iconImageView: UIImageView

    init() {
        // 블러 효과
        let blurEffect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        self.blurView = UIVisualEffectView(effect: blurEffect)

        // Vibrancy 효과 (블러 위에 적용)
        let vibrancyEffect = UIVibrancyEffect(blurEffect: blurEffect, style: .label)
        self.vibrancyView = UIVisualEffectView(effect: vibrancyEffect)

        // 아이콘 이미지뷰 (vibrancy 내부에 배치)
        self.iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit

        super.init(frame: .zero)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupViews() {
        // 계층 구조: button > blurView > vibrancyView > iconImageView
        blurView.isUserInteractionEnabled = false
        vibrancyView.isUserInteractionEnabled = false

        insertSubview(blurView, at: 0)
        blurView.contentView.addSubview(vibrancyView)
        vibrancyView.contentView.addSubview(iconImageView)

        // 테두리
        layer.borderWidth = LiquidGlassStyle.borderWidth
        layer.borderColor = UIColor.white.withAlphaComponent(LiquidGlassStyle.borderAlpha).cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let cornerRadius = bounds.height / 2

        blurView.frame = bounds
        blurView.layer.cornerRadius = cornerRadius

        vibrancyView.frame = blurView.contentView.bounds

        // 아이콘 중앙 배치
        let iconSize: CGFloat = 22
        iconImageView.frame = CGRect(
            x: (vibrancyView.contentView.bounds.width - iconSize) / 2,
            y: (vibrancyView.contentView.bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )

        layer.cornerRadius = cornerRadius
    }

    func setIcon(_ systemName: String, pointSize: CGFloat = 22) {
        let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .medium)
        iconImageView.image = UIImage(systemName: systemName, withConfiguration: config)
    }
}
```

### 적용 대상

Vibrancy 효과는 다음 버튼에 선택적으로 적용 가능:
- [ ] 백 버튼 (tint 없는 순수 glass)
- [ ] 액션 버튼 (삭제/복구) - tint와 조합 필요
- [ ] Select 버튼

### 주의사항

1. **색상 제어 제한**: Vibrancy 효과 내부의 아이콘은 시스템이 색상을 결정하므로 `tintColor` 설정이 무시될 수 있음
2. **tint 오버레이와 조합**: 빨간색/초록색 tint가 필요한 버튼에는 vibrancy + tint 조합이 복잡해질 수 있음
3. **테스트 필수**: 다양한 배경에서 가독성 테스트 필요

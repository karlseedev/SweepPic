# PickPhoto iOS 16~25 커스텀 UI → Liquid Glass 스타일 변환 계획 (Final)

## 개요
iOS 16~25에서 사용하는 커스텀 UI (FloatingTabBar, FloatingTitleBar, Viewer 버튼 등)의 **디자인을 iOS 26 스타일의 Liquid Glass로 완벽하게 변환**합니다.

- **목표**: 단순한 반투명을 넘어, 두께감, 질감, 광원 반응(Interaction)이 살아있는 물리적인 유리 느낌 구현
- **대상**: iOS 16~25 (iOS 26+은 시스템 UI 사용)

---

## Liquid Glass 스타일 핵심 특성 (Deep Dive)

| 특성 | 현재 스타일 | Liquid Glass 스타일 (iOS 26 타겟) |
|------|------------|-----------------------------------|
| **소재 (Material)** | `.systemThinMaterialDark` | `.systemUltraThinMaterialDark` (투명도 극대화) |
| **광원 (Lighting)** | 없음 | **Specular Highlight** (상단 엣지 발광) |
| **깊이 (Depth)** | 단순 그림자 | **Ambient Shadow** (부드러운 확산) + 선명한 테두리 |
| **반응 (Reaction)** | 배경색 변경 | **Scale Down** (0.96x) + **Optical Shift** (투명도/밝기 변화) |
| **테두리 (Rim)** | 흐릿한 0.5pt | **0.5pt Sharp White (alpha 0.3)** - 유리 절단면 느낌 |
| **아이콘 (Symbol)** | 18~22pt | **22~24pt** (더 크고 시원하게) + **Soft Shadow** |

---

## 디자인 상세 명세 (다크 테마 기준)

### 1. 물리적 계층 구조 (Layer Hierarchy)
Liquid Glass 버튼은 단순한 뷰가 아니라 여러 광학 레이어의 합성입니다.

1.  **Base Layer (Shadow)**: 뷰 뒤쪽에 맺히는 부드러운 그림자
2.  **Material Layer (Blur)**: 배경을 흐리는 초박형 유리 (`UltraThinMaterial`)
3.  **Tint Layer (Color)**: 유리에 주입된 색상 (Alpha 0.15~0.25)
4.  **Specular Layer (Reflection)**: 위쪽 광원에서 반사된 하이라이트 (Top Gradient)
5.  **Content Layer (Symbol)**: 텍스트 및 아이콘 (약한 그림자로 가독성 확보)

### 2. 컴포넌트별 적용 전략

| 컴포넌트 | Specular Highlight | Shadow | Interaction |
|---------|-------------------|--------|-------------|
| **FloatingTabBar** | ❌ (과도함 방지) | ✅ (Deep) | ❌ |
| **FloatingTitleBar** | ❌ (과도함 방지) | ❌ (Overlay) | ❌ |
| **Action Button** | ✅ (필수) | ✅ (Icon Shadow) | ✅ (Scale + Dim) |
| **Select Button** | ✅ (필수) | ✅ (Layer Shadow) | ✅ (Scale + Dim) |

---

## Phase 0: 스타일 상수 및 팩토리 (LiquidGlassStyle.swift)

**경로**: `PickPhoto/PickPhoto/Shared/Styles/LiquidGlassStyle.swift`

모든 디자인 매직 넘버를 한곳에서 관리합니다.

```swift
import UIKit

/// iOS 16~25용 Liquid Glass 디자인 시스템 상수
enum LiquidGlassStyle {

    // MARK: - Material & Color
    static let blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark
    static let backgroundAlpha: CGFloat = 0.12 // 배경 오버레이 (최소화)
    static let tintAlpha: CGFloat = 0.20       // 색상 틴트 농도
    
    // MARK: - Border & Surface
    static let borderWidth: CGFloat = 0.5
    static let borderAlpha: CGFloat = 0.30     // 유리 절단면 느낌을 위해 조금 더 선명하게
    static let defaultCornerRadius: CGFloat = 18

    // MARK: - Shadow (Ambient)
    static let shadowColor: UIColor = .black
    static let shadowOpacity: Float = 0.25
    static let shadowRadius: CGFloat = 16
    static let shadowOffset = CGSize(width: 0, height: 4)

    // MARK: - Icon Specs
    static let tabIconSize: CGFloat = 24
    static let actionButtonIconSize: CGFloat = 22
    static let backButtonIconSize: CGFloat = 20
    
    // MARK: - Icon Shadow (가독성 보정)
    static let iconShadowOpacity: Float = 0.3
    static let iconShadowRadius: CGFloat = 2
    static let iconShadowOffset = CGSize(width: 0, height: 1)

    // MARK: - Specular Highlight (광원 반사)
    // 버튼 상단에서 시작하여 중간에서 사라지는 화이트 그라데이션
    static let highlightTopAlpha: CGFloat = 0.15
    static let highlightBottomAlpha: CGFloat = 0.0
    static let highlightLocation: NSNumber = 0.5 // 버튼 높이의 50%까지만 빛이 맺힘

    // MARK: - Helper Methods

    /// Glass 스타일 테두리 적용
    static func applyBorder(to layer: CALayer, cornerRadius: CGFloat) {
        layer.borderWidth = borderWidth
        layer.borderColor = UIColor.white.withAlphaComponent(borderAlpha).cgColor
        layer.cornerRadius = cornerRadius
        // 주의: smoothCornerRadius는 iOS 13+ CALayer private API에 가까우므로 기본 cornerRadius 사용
        layer.cornerCurve = .continuous // 부드러운 곡률 (iOS 13+)
    }

    /// Glass 스타일 그림자 적용
    static func applyShadow(to layer: CALayer, cornerRadius: CGFloat) {
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = shadowOffset
        
        // 성능 최적화: Shadow Path 명시
        if layer.bounds.width > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: layer.bounds,
                cornerRadius: cornerRadius
            ).cgPath
        }
    }

    /// 아이콘 가독성 그림자
    static func applyIconShadow(to imageView: UIImageView) {
        imageView.layer.shadowColor = shadowColor.cgColor
        imageView.layer.shadowOpacity = iconShadowOpacity
        imageView.layer.shadowRadius = iconShadowRadius
        imageView.layer.shadowOffset = iconShadowOffset
        imageView.layer.masksToBounds = false
    }

    /// 스펙큘러 하이라이트 레이어 생성 (단일 생성)
    static func createSpecularHighlightLayer() -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.white.withAlphaComponent(highlightTopAlpha).cgColor,
            UIColor.white.withAlphaComponent(highlightBottomAlpha).cgColor
        ]
        layer.locations = [0.0, highlightLocation]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.masksToBounds = true // 코너 래디어스 적용을 위해 필요
        return layer
    }
}
```

---

## Phase 0.5: GlassButton 컴포넌트 (GlassButton.swift)

**경로**: `PickPhoto/PickPhoto/Shared/Components/GlassButton.swift`

모든 버튼(삭제, 복구, 선택 등)의 원형이 되는 클래스입니다. **인터랙션(눌림 효과)**과 **상태(Enabled)** 관리가 핵심입니다.

```swift
import UIKit

/// iOS 26 스타일 Liquid Glass 버튼
/// - 특징: 블러 배경, 틴트, 스펙큘러 하이라이트, 그림자, 물리적 터치 반응
final class GlassButton: UIButton {

    // MARK: - UI Components
    private let blurView: UIVisualEffectView
    private let tintView: UIView
    private var highlightLayer: CAGradientLayer?

    // MARK: - Properties
    private let overlayTintColor: UIColor
    private let useCapsuleStyle: Bool
    
    // MARK: - State Management
    override var isHighlighted: Bool {
        didSet { animateInteraction(isPressed: isHighlighted) }
    }
    
    override var isEnabled: Bool {
        didSet { updateStateStyles() }
    }

    // MARK: - Init
    init(tintColor: UIColor, useCapsuleStyle: Bool = false) {
        self.overlayTintColor = tintColor
        self.useCapsuleStyle = useCapsuleStyle

        // 1. Material Layer
        let effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        self.blurView = UIVisualEffectView(effect: effect)
        blurView.isUserInteractionEnabled = false
        blurView.clipsToBounds = true

        // 2. Tint Layer
        self.tintView = UIView()
        tintView.backgroundColor = overlayTintColor.withAlphaComponent(LiquidGlassStyle.tintAlpha)
        tintView.isUserInteractionEnabled = false

        super.init(frame: .zero)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup
    private func setupLayers() {
        // 그림자를 위해 버튼 자체의 clipsToBounds는 false여야 함
        self.layer.masksToBounds = false
        
        // 계층: Blur -> Tint -> Highlight -> Content(Label/Image)
        insertSubview(blurView, at: 0)
        blurView.contentView.addSubview(tintView)

        // Specular Highlight
        highlightLayer = LiquidGlassStyle.createSpecularHighlightLayer()
        if let highlightLayer = highlightLayer {
            blurView.contentView.layer.addSublayer(highlightLayer)
        }
        
        // Border
        blurView.layer.borderWidth = LiquidGlassStyle.borderWidth
        blurView.layer.borderColor = UIColor.white.withAlphaComponent(LiquidGlassStyle.borderAlpha).cgColor
    }

    // MARK: - Layout
    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = useCapsuleStyle ? bounds.height / 2 : LiquidGlassStyle.defaultCornerRadius

        // 1. Update Frames
        blurView.frame = bounds
        tintView.frame = blurView.contentView.bounds
        
        // 2. Update Corner Radius
        blurView.layer.cornerRadius = cornerRadius
        blurView.layer.cornerCurve = .continuous
        
        // 3. Update Highlight
        if let highlightLayer = highlightLayer {
            highlightLayer.frame = blurView.contentView.bounds
            highlightLayer.cornerRadius = cornerRadius
            highlightLayer.cornerCurve = .continuous
        }

        // 4. Update Shadow (버튼 레이어에 직접 적용)
        LiquidGlassStyle.applyShadow(to: self.layer, cornerRadius: cornerRadius)
    }
    
    // MARK: - Interaction Animations
    private func animateInteraction(isPressed: Bool) {
        let scale: CGFloat = isPressed ? 0.96 : 1.0
        let alpha: CGFloat = isPressed ? 0.8 : 1.0
        
        UIView.animate(withDuration: 0.2, delay: 0, options: [.beginFromCurrentState, .curveEaseOut], animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
            self.alpha = self.isEnabled ? alpha : 0.5
        }, completion: nil)
    }
    
    private func updateStateStyles() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = self.isEnabled ? 1.0 : 0.4
            // 비활성화 시 채도 감소 효과를 흉내낼 수도 있음 (여기선 Alpha로 충분)
        }
    }
}
```

---

## Phase 1: FloatingTabBar.swift 적용

**핵심 변경**: 기존의 어두운 배경을 제거하고, 순수하게 블러와 테두리로만 형태를 잡습니다.

1.  **Blur**: `.systemThinMaterialDark` → `.systemUltraThinMaterialDark`
2.  **Background**: `UIColor(white: 0.12, alpha: 0.5)` → `UIColor(white: 0.1, alpha: LiquidGlassStyle.backgroundAlpha)` (거의 투명하게)
3.  **Border**: 0.5pt, white 0.25 (선명하게)
4.  **Shadow**: Radius 16, Opacity 0.25 (깊게)
5.  **Icons**: 24pt (크게)

---

## Phase 2: FloatingTitleBar.swift 적용

**핵심 변경**: Select 버튼을 `GlassButton`으로 교체하고, 상단 그라데이션을 더 투명하게 만듭니다.

1.  **Gradient Dim**: Max alpha 0.6 → 0.45
2.  **Select Button**:
    ```swift
    // 기존 UIButton 설정을 제거하고 교체
    private lazy var selectButton: GlassButton = {
        let button = GlassButton(tintColor: .systemBlue, useCapsuleStyle: true)
        button.setTitle("Select", for: .normal)
        // ... 폰트 등 설정
        return button
    }()
    ```

---

## Phase 3: ViewerViewController.swift 버튼 교체

**핵심 변경**: 뷰어의 삭제/복구 버튼을 일관된 `GlassButton`으로 교체합니다.

1.  **Helper Method**:
    ```swift
    private func createGlassActionButton(tintColor: UIColor, icon: String) -> GlassButton {
        let button = GlassButton(tintColor: tintColor, useCapsuleStyle: false)
        // 아이콘 설정 (그림자 포함)
        if let imageView = button.imageView {
            LiquidGlassStyle.applyIconShadow(to: imageView)
        }
        return button
    }
    ```
2.  **Back Button**:
    - `tintColor: .clear`로 설정하여 배경 색상 없이 블러와 테두리만 있는 "Pure Glass" 스타일 적용.
    - 아이콘 그림자는 필수 (밝은 사진 위에서 보이기 위해).

---

## Phase 4: Select Mode UI

Select 모드 하단 바의 액션 버튼(삭제, 공유)들도 `GlassButton`으로 통일하여 전체적인 룩앤필을 맞춥니다.
- **Delete Button**: `tintColor: .systemRed`
- **Share Button**: `tintColor: .systemBlue`

---

## 구현 체크리스트 (오류 방지)

1.  **Memory Leak**: `layoutSubviews`에서 `createSpecularHighlightLayer`를 반복 호출하지 않도록 주의 (Phase 0.5 코드에서 `highlightLayer`를 프로퍼티로 들고 있고 프레임만 갱신하므로 해결됨).
2.  **Shadow Clipping**: `GlassButton`의 `layer.masksToBounds`는 반드시 `false`여야 그림자가 보임. 반면 내부 `blurView`는 `clipsToBounds = true`여야 블러가 둥글게 잘림. (Phase 0.5 코드에 반영됨).
3.  **Touch Area**: 버튼의 크기가 작아지지 않도록 오토레이아웃 제약조건 확인 (기존 36x36 유지). `isHighlighted` 애니메이션 시 `transform`만 변경하므로 레이아웃 영향 없음.
4.  **Z-Index**: `blurView`는 항상 `insertSubview(at: 0)`로 맨 뒤로 보내야 텍스트/이미지가 가려지지 않음.

---

## 테스트 시나리오

1.  **배경 테스트**: 흰색 배경(눈밭 사진)과 검은색 배경(야경 사진) 모두에서 버튼의 경계(Border)와 아이콘(Shadow)이 명확히 보이는가?
2.  **터치 테스트**: 버튼을 짧게 탭했을 때와 길게 눌렀을 때 쫀득한 반응(Scale Down)이 있는가?
3.  **회전 테스트**: 가로 모드에서 스펙큘러 하이라이트와 그림자가 찌그러지지 않고 다시 그려지는가? (`layoutSubviews` 로직 검증)

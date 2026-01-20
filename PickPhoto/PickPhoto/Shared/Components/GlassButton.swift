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
        }
    }
}

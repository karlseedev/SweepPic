import UIKit
import LiquidGlassKit

/// iOS 26 스타일 Liquid Glass 버튼
/// - 특징: Dual state (contracted ↔ expanded), 굴절 효과, 햅틱 피드백
/// - Contracted (resting): 일반 블러 배경
/// - Expanded (pressed): 확장 + 굴절 효과 (LiquidGlassEffect)
final class GlassButton: UIButton {

    // MARK: - UI Components

    /// Contracted 상태 뷰 (resting)
    /// 일반 블러 배경 + 틴트 + 하이라이트
    private let contractedView: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }()

    /// Contracted 상태의 블러
    private lazy var blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        let view = UIVisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        view.clipsToBounds = true
        return view
    }()

    /// Contracted 상태의 틴트
    private lazy var tintView: UIView = {
        let view = UIView()
        view.backgroundColor = overlayTintColor.withAlphaComponent(LiquidGlassStyle.tintAlpha)
        view.isUserInteractionEnabled = false
        return view
    }()

    /// Contracted 상태의 하이라이트 레이어
    private var highlightLayer: CAGradientLayer?

    /// Expanded 상태 뷰 (pressed)
    /// LiquidGlassEffect 사용하여 굴절 효과 적용
    private lazy var expandedView: AnyVisualEffectView = {
        let effect = LiquidGlassEffect(style: .regular, isNative: true)
        let view = VisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        view.alpha = 0 // 초기에는 숨김
        view.transform = CGAffineTransform(scaleX: 0.87, y: 0.87) // 축소 상태
        return view
    }()

    // MARK: - Haptic Feedback

    /// 햅틱 피드백 생성기
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Properties

    private let overlayTintColor: UIColor
    private let useCapsuleStyle: Bool

    /// 현재 확장 상태
    private var isExpanded = false

    // MARK: - State Management

    override var isEnabled: Bool {
        didSet { updateStateStyles() }
    }

    // MARK: - Init

    init(tintColor: UIColor, useCapsuleStyle: Bool = false) {
        self.overlayTintColor = tintColor
        self.useCapsuleStyle = useCapsuleStyle

        super.init(frame: .zero)
        setupLayers()

        // 햅틱 준비
        feedbackGenerator.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupLayers() {
        // 그림자를 위해 버튼 자체의 clipsToBounds는 false여야 함
        self.layer.masksToBounds = false

        // Contracted View 계층 구성: Blur -> Tint -> Highlight
        contractedView.addSubview(blurView)
        blurView.contentView.addSubview(tintView)

        // Specular Highlight
        highlightLayer = LiquidGlassStyle.createSpecularHighlightLayer()
        if let highlightLayer = highlightLayer {
            blurView.contentView.layer.addSublayer(highlightLayer)
        }

        // Border
        blurView.layer.borderWidth = LiquidGlassStyle.borderWidth
        blurView.layer.borderColor = UIColor.white.withAlphaComponent(LiquidGlassStyle.borderAlpha).cgColor

        // 뷰 계층에 추가 (Expanded가 위, Contracted가 아래)
        insertSubview(contractedView, at: 0)
        insertSubview(expandedView, aboveSubview: contractedView)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = useCapsuleStyle ? bounds.height / 2 : LiquidGlassStyle.defaultCornerRadius

        // 1. Contracted View 프레임 업데이트
        contractedView.frame = bounds
        blurView.frame = contractedView.bounds
        tintView.frame = blurView.contentView.bounds

        // 2. Update Corner Radius
        contractedView.layer.cornerRadius = cornerRadius
        contractedView.layer.cornerCurve = .continuous
        contractedView.clipsToBounds = true

        blurView.layer.cornerRadius = cornerRadius
        blurView.layer.cornerCurve = .continuous

        // 3. Update Highlight
        if let highlightLayer = highlightLayer {
            highlightLayer.frame = blurView.contentView.bounds
            highlightLayer.cornerRadius = cornerRadius
            highlightLayer.cornerCurve = .continuous
        }

        // 4. Expanded View 프레임 업데이트
        expandedView.frame = bounds
        expandedView.layer.cornerRadius = cornerRadius
        expandedView.layer.cornerCurve = .continuous
        expandedView.clipsToBounds = true

        // 5. Update Shadow (버튼 레이어에 직접 적용)
        LiquidGlassStyle.applyShadow(to: self.layer, cornerRadius: cornerRadius)

        // 6. Ensure Content is Visible (블러 뷰 위로 올림)
        if let imageView = imageView {
            bringSubviewToFront(imageView)
        }
        if let titleLabel = titleLabel {
            bringSubviewToFront(titleLabel)
        }
    }

    // MARK: - Touch Handling (Dual State)

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        expandButton(animated: true)
        feedbackGenerator.impactOccurred()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        contractButton(animated: true)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        contractButton(animated: true)
    }

    // MARK: - Dual State Animations

    /// 버튼 확장 (pressed → expanded)
    /// LiquidGlassSwitch 패턴 참고: 커지면서 굴절 효과 활성화
    private func expandButton(animated: Bool) {
        guard !isExpanded else { return }
        isExpanded = true

        let duration: TimeInterval = animated ? 0.4 : 0
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0,
            options: .beginFromCurrentState
        ) {
            // Contracted → 확대 후 페이드아웃
            self.contractedView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
            self.contractedView.alpha = 0

            // Expanded → 원래 크기로 페이드인
            self.expandedView.transform = .identity
            self.expandedView.alpha = 1
        }
    }

    /// 버튼 수축 (released → contracted)
    private func contractButton(animated: Bool) {
        guard isExpanded else { return }
        isExpanded = false

        let duration: TimeInterval = animated ? 0.6 : 0
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0,
            options: .beginFromCurrentState
        ) {
            // Expanded → 축소 후 페이드아웃
            self.expandedView.transform = CGAffineTransform(scaleX: 0.87, y: 0.87)
            self.expandedView.alpha = 0

            // Contracted → 원래 크기로 페이드인
            self.contractedView.transform = .identity
            self.contractedView.alpha = 1
        }
    }

    // MARK: - State Styles

    private func updateStateStyles() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = self.isEnabled ? 1.0 : 0.4
        }
    }
}

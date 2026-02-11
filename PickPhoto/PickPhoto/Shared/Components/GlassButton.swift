import UIKit
import LiquidGlassKit

/// iOS 26 스타일 Liquid Glass 버튼
/// - 특징: 1뷰 scale 애니메이션, 굴절 효과, 햅틱 피드백
/// - Resting: LiquidGlassEffect 적용
/// - Pressed: scale 확대 (1.08)
final class GlassButton: UIButton {

    // MARK: - UI Components

    /// Glass 효과 뷰 (1뷰 구조)
    /// LiquidGlassEffect 사용 - 터치 시 scale 애니메이션으로 피드백
    private lazy var glassView: AnyVisualEffectView = {
        let effect = LiquidGlassEffect(style: .regular, isNative: true)
        effect.tintColor = UIColor(white: 0.5, alpha: 0.2)  // 중간회색 20%
        let view = VisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        return view
    }()

    // MARK: - Haptic Feedback

    /// 햅틱 피드백 생성기
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Properties

    private let useCapsuleStyle: Bool

    // MARK: - State Management

    override var isEnabled: Bool {
        didSet { updateStateStyles() }
    }

    // MARK: - Init

    /// Glass 버튼 생성
    /// - Parameters:
    ///   - tintColor: 아이콘/텍스트 색상 (배경색이 아님 - 배경은 LiquidGlassEffect 기본값)
    ///   - useCapsuleStyle: true면 pill shape (height/2), false면 기본 코너
    init(tintColor: UIColor, useCapsuleStyle: Bool = false) {
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

        // Glass 뷰 추가 (1뷰 구조)
        insertSubview(glassView, at: 0)
    }

    // MARK: - Layout

    // C-5: preload() 이후 동적 생성된 버튼도 블러 오버레이 자동 생성
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                LiquidGlassOptimizer.preload(in: self)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = useCapsuleStyle ? bounds.height / 2 : LiquidGlassStyle.defaultCornerRadius

        // Glass View 크기/위치 업데이트 (bounds+center 사용 — transform과 독립적)
        glassView.bounds = CGRect(origin: .zero, size: bounds.size)
        glassView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.cornerCurve = .continuous
        glassView.clipsToBounds = true

        // Update Shadow (버튼 레이어에 직접 적용)
        LiquidGlassStyle.applyShadow(to: self.layer, cornerRadius: cornerRadius)

        // Ensure Content is Visible (Glass 뷰 위로 올림)
        if let imageView = imageView {
            bringSubviewToFront(imageView)
        }
        if let titleLabel = titleLabel {
            bringSubviewToFront(titleLabel)
        }
    }

    // MARK: - Touch Handling

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

    // MARK: - Scale Animations

    /// 버튼 확장 (pressed)
    /// 1뷰 scale 애니메이션 — 살짝 커지면서 터치 피드백 제공
    private func expandButton(animated: Bool) {
        let duration: TimeInterval = animated ? 0.4 : 0
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0,
            options: .beginFromCurrentState
        ) {
            self.glassView.transform = CGAffineTransform(scaleX: 1.15, y: 1.15)
        }
    }

    /// 버튼 수축 (released)
    /// 1뷰 scale 복원 — 원래 크기로 돌아옴
    private func contractButton(animated: Bool) {
        let duration: TimeInterval = animated ? 0.6 : 0
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.7,
            initialSpringVelocity: 0,
            options: .beginFromCurrentState
        ) {
            self.glassView.transform = .identity
        }
    }

    // MARK: - State Styles

    private func updateStateStyles() {
        UIView.animate(withDuration: 0.2) {
            self.alpha = self.isEnabled ? 1.0 : 0.4
        }
    }
}

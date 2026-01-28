// GlassIconButton.swift
// 아이콘 전용 Liquid Glass 버튼 컴포넌트
//
// - 특징: Dual state (contracted ↔ expanded), 굴절 효과, 햅틱 피드백
// - Contracted (resting): 일반 블러 배경
// - Expanded (pressed): 확장 + 굴절 효과 (LiquidGlassEffect)
// - Size: small(36pt), medium(44pt), large(56pt)

import UIKit
import LiquidGlassKit

/// 아이콘 전용 Liquid Glass 버튼
/// - backButton, closeButton, cycleButton 등 아이콘만 있는 버튼에 사용
/// - Dual state: contracted(resting) ↔ expanded(pressed)
final class GlassIconButton: UIButton {

    // MARK: - Types

    /// 버튼 크기 사전 정의
    enum Size {
        case small   // 36×36, 아이콘 18pt
        case medium  // 44×44, 아이콘 22pt
        case large   // 56×56, 아이콘 28pt

        /// 버튼 전체 크기 (정사각형)
        var dimension: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 56
            }
        }

        /// SF Symbol point size
        var iconPointSize: CGFloat {
            switch self {
            case .small: return 18
            case .medium: return 22
            case .large: return 28
            }
        }

        /// 코너 반경 (dimension의 약 40%)
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 18
            case .large: return 22
            }
        }
    }

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
        view.backgroundColor = iconTintColor.withAlphaComponent(LiquidGlassStyle.tintAlpha)
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

    /// 아이콘 이미지 뷰
    private let iconImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .center
        view.tintColor = .white
        view.isUserInteractionEnabled = false
        return view
    }()

    // MARK: - Haptic Feedback

    /// 햅틱 피드백 생성기
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)

    // MARK: - Properties

    /// 버튼 크기
    private let buttonSize: Size

    /// 아이콘 틴트 색상
    private let iconTintColor: UIColor

    /// 현재 확장 상태
    private var isExpanded = false

    /// 현재 아이콘 이름 (변경 추적용)
    private var currentIconName: String

    // MARK: - State Management

    override var isEnabled: Bool {
        didSet { updateStateStyles() }
    }

    override var isHighlighted: Bool {
        didSet {
            // isHighlighted 변경 시 추가 처리 (기본 동작 외)
        }
    }

    // MARK: - Init

    /// 아이콘 버튼 생성
    /// - Parameters:
    ///   - icon: SF Symbol 이름
    ///   - size: 버튼 크기 (기본: .medium)
    ///   - tintColor: 아이콘/배경 틴트 색상 (기본: .white)
    init(icon: String, size: Size = .medium, tintColor: UIColor = .white) {
        self.buttonSize = size
        self.iconTintColor = tintColor
        self.currentIconName = icon

        super.init(frame: .zero)

        setupIcon(icon)
        setupLayers()

        // 햅틱 준비
        feedbackGenerator.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// 아이콘 설정
    private func setupIcon(_ icon: String) {
        let config = UIImage.SymbolConfiguration(
            pointSize: buttonSize.iconPointSize,
            weight: .semibold
        )
        iconImageView.image = UIImage(systemName: icon, withConfiguration: config)
        iconImageView.tintColor = iconTintColor

        // 아이콘 그림자 적용 (가독성)
        LiquidGlassStyle.applyIconShadow(to: iconImageView)
    }

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

        // 아이콘은 최상단
        addSubview(iconImageView)
    }

    // MARK: - Layout

    /// 고정 크기 반환
    override var intrinsicContentSize: CGSize {
        return CGSize(width: buttonSize.dimension, height: buttonSize.dimension)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = buttonSize.cornerRadius

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

        // 6. 아이콘 중앙 배치
        iconImageView.frame = bounds
    }

    // MARK: - Public Methods

    /// 아이콘 변경
    /// - Parameters:
    ///   - icon: 새 SF Symbol 이름
    ///   - animated: 애니메이션 적용 여부 (기본: false)
    func setIcon(_ icon: String, animated: Bool = false) {
        guard icon != currentIconName else { return }
        currentIconName = icon

        let config = UIImage.SymbolConfiguration(
            pointSize: buttonSize.iconPointSize,
            weight: .semibold
        )
        let newImage = UIImage(systemName: icon, withConfiguration: config)

        if animated {
            // 크로스페이드 애니메이션
            UIView.transition(
                with: iconImageView,
                duration: 0.2,
                options: .transitionCrossDissolve
            ) {
                self.iconImageView.image = newImage
            }
        } else {
            iconImageView.image = newImage
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

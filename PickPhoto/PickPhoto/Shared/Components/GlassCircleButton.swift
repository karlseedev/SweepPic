// GlassCircleButton.swift
// 원형 Liquid Glass 버튼 컴포넌트
//
// - 특징: 1뷰 scale 애니메이션, 굴절 효과, 햅틱 피드백
// - Resting: LiquidGlassEffect 적용
// - Pressed: scale 확대 (1.08)
// - Size: mini(34pt), small(36pt), medium(44pt), large(56pt)
// - 용도: toggleButton, faceButtons[] 등 원형 버튼에 사용

import UIKit
import LiquidGlassKit
import AppCore

/// 원형 Liquid Glass 버튼
/// - toggleButton, faceButtons[] 등 원형 버튼에 사용
/// - GlassIconButton과 동일한 구현, 용도 구분을 위해 별도 클래스
/// - 터치 시 scale 애니메이션으로 피드백 제공
/// - 상속 허용 (FaceButton 등)
class GlassCircleButton: UIButton {

    // MARK: - Types

    /// 버튼 크기 사전 정의
    enum Size {
        case mini    // 34×34, 아이콘 18pt, .semibold (FaceButton용)
        case small   // 36×36, 아이콘 14pt
        case medium  // 44×44, 아이콘 22pt
        case large   // 56×56, 아이콘 22pt

        /// 버튼 전체 크기 (정사각형)
        var dimension: CGFloat {
            switch self {
            case .mini: return 34
            case .small: return 36
            case .medium: return 44
            case .large: return 56
            }
        }

        /// SF Symbol point size
        var iconPointSize: CGFloat {
            switch self {
            case .mini: return 18
            case .small: return 14
            case .medium: return 22
            case .large: return 22
            }
        }

        /// SF Symbol weight
        var iconWeight: UIImage.SymbolWeight {
            switch self {
            case .mini: return .semibold  // FaceButton용: 굵게
            default: return .light
            }
        }

        /// 코너 반경 (완전한 원형: dimension / 2)
        var cornerRadius: CGFloat {
            switch self {
            case .mini: return 17    // 34 / 2
            case .small: return 18   // 36 / 2
            case .medium: return 22  // 44 / 2
            case .large: return 28   // 56 / 2
            }
        }
    }

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

    /// 현재 아이콘 이름 (변경 추적용)
    private var currentIconName: String

    /// 배경(LiquidGlass) alpha 값 (아이콘은 영향 없음)
    var backgroundAlpha: CGFloat = 1.0 {
        didSet {
            glassView.alpha = backgroundAlpha
        }
    }

    // MARK: - State Management

    override var isEnabled: Bool {
        didSet { updateStateStyles() }
    }

    // MARK: - Init

    /// 원형 버튼 생성
    /// - Parameters:
    ///   - icon: SF Symbol 이름
    ///   - size: 버튼 크기 (기본: .medium)
    ///   - tintColor: 아이콘 틴트 색상 (기본: .white)
    init(icon: String, size: Size = .medium, tintColor: UIColor = .white) {
        self.buttonSize = size
        self.iconTintColor = tintColor
        self.currentIconName = icon

        let t0 = CACurrentMediaTime()
        super.init(frame: .zero)
        let t1 = CACurrentMediaTime()

        setupIcon(icon)
        let t2 = CACurrentMediaTime()

        setupLayers()
        let t3 = CACurrentMediaTime()

        // 햅틱 준비
        feedbackGenerator.prepare()
        let t4 = CACurrentMediaTime()

        Log.print("[Viewer Timing]       GlassCircleButton.init(\(icon)) — super.init: \(String(format: "%.1f", (t1-t0)*1000))ms, setupIcon: \(String(format: "%.1f", (t2-t1)*1000))ms, setupLayers: \(String(format: "%.1f", (t3-t2)*1000))ms, haptic: \(String(format: "%.1f", (t4-t3)*1000))ms")
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// 아이콘 설정
    /// weight는 Size에 따라 결정 (.mini는 .semibold, 나머지는 .light)
    private func setupIcon(_ icon: String) {
        let config = UIImage.SymbolConfiguration(
            pointSize: buttonSize.iconPointSize,
            weight: buttonSize.iconWeight
        )
        iconImageView.image = UIImage(systemName: icon, withConfiguration: config)
        iconImageView.tintColor = iconTintColor
    }

    private func setupLayers() {
        // 그림자를 위해 버튼 자체의 clipsToBounds는 false여야 함
        self.layer.masksToBounds = false

        // Glass 뷰 추가 (1뷰 구조)
        let sl0 = CACurrentMediaTime()
        insertSubview(glassView, at: 0)
        let sl1 = CACurrentMediaTime()

        // 아이콘은 최상단
        addSubview(iconImageView)
        let sl2 = CACurrentMediaTime()

        Log.print("[Viewer Timing]         setupLayers — glassView: \(String(format: "%.1f", (sl1-sl0)*1000))ms, iconImageView: \(String(format: "%.1f", (sl2-sl1)*1000))ms")
    }

    // MARK: - Layout

    /// 고정 크기 반환
    override var intrinsicContentSize: CGSize {
        return CGSize(width: buttonSize.dimension, height: buttonSize.dimension)
    }

    // C-5: preload() 이후 동적 생성된 버튼도 블러 오버레이 자동 생성
    // async: didMoveToWindow 시점에는 MTKView 레이아웃이 미완료일 수 있음
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                self.layoutIfNeeded()
                for subview in self.subviews { subview.layoutIfNeeded() }
                LiquidGlassOptimizer.preload(in: self)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = buttonSize.cornerRadius

        // Glass View 크기/위치 업데이트 (bounds+center 사용 — transform과 독립적)
        glassView.bounds = CGRect(origin: .zero, size: bounds.size)
        glassView.center = CGPoint(x: bounds.midX, y: bounds.midY)
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.cornerCurve = .continuous
        glassView.clipsToBounds = true

        // Update Shadow (버튼 레이어에 직접 적용)
        LiquidGlassStyle.applyShadow(to: self.layer, cornerRadius: cornerRadius)

        // 아이콘 중앙 배치
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
            weight: buttonSize.iconWeight
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

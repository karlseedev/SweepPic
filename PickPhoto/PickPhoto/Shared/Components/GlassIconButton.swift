// GlassIconButton.swift
// 아이콘 전용 Liquid Glass 버튼 컴포넌트
//
// - 특징: 1뷰 scale 애니메이션, 굴절 효과
// - Resting: LiquidGlassEffect 적용
// - Pressed: scale 확대 (1.08)
// - Size: small(36pt), medium(44pt), large(56pt)

import UIKit
import LiquidGlassKit

/// 아이콘 전용 Liquid Glass 버튼
/// - backButton, closeButton, cycleButton 등 아이콘만 있는 버튼에 사용
/// - 터치 시 scale 애니메이션으로 피드백 제공
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
            case .small: return 14
            case .medium: return 22
            case .large: return 22
            }
        }

        /// 코너 반경 (완전한 원형: dimension / 2)
        /// iOS 26 실측 기준: 44×44 버튼에 cornerRadius 22
        var cornerRadius: CGFloat {
            switch self {
            case .small: return 18   // 36 / 2
            case .medium: return 22  // 44 / 2, iOS 26 실측값
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

    /// 커스텀 아이콘 포인트 사이즈 (nil이면 size 기본값 사용)
    private let customIconPointSize: CGFloat?

    /// Glass 효과 생성 지연 플래그 (Phase 6: hidden 상태 버튼의 MTKView 절약)
    private var glassViewSetupDeferred = false

    // MARK: - State Management

    override var isEnabled: Bool {
        didSet { updateStateStyles() }
    }

    // MARK: - Init

    /// 아이콘 버튼 생성
    /// - Parameters:
    ///   - icon: SF Symbol 이름
    ///   - size: 버튼 크기 (기본: .medium)
    ///   - tintColor: 아이콘/배경 틴트 색상 (기본: .white)
    init(icon: String, size: Size = .medium, tintColor: UIColor = .white, iconPointSize: CGFloat? = nil, deferGlassEffect: Bool = false) {
        self.buttonSize = size
        self.iconTintColor = tintColor
        self.currentIconName = icon
        self.customIconPointSize = iconPointSize
        self.glassViewSetupDeferred = deferGlassEffect

        super.init(frame: .zero)

        setupIcon(icon)
        setupLayers()

        // 햅틱 준비 (시스템 서비스 워밍업 효과 — cold-start Hang 방지)
        feedbackGenerator.prepare()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// 아이콘 설정
    /// iOS 26 실측: 그림자 없음, weight light (regular보다 가늘게)
    private func setupIcon(_ icon: String) {
        let config = UIImage.SymbolConfiguration(
            pointSize: customIconPointSize ?? buttonSize.iconPointSize,
            weight: .light  // regular보다 한 단계 가늘게
        )
        iconImageView.image = UIImage(systemName: icon, withConfiguration: config)
        iconImageView.tintColor = iconTintColor
    }

    private func setupLayers() {
        // 그림자를 위해 버튼 자체의 clipsToBounds는 false여야 함
        self.layer.masksToBounds = false

        // Glass 뷰 추가 (deferred 아닌 경우만 — lazy 트리거 방지)
        if !glassViewSetupDeferred {
            insertSubview(glassView, at: 0)
        }

        // 아이콘은 최상단
        addSubview(iconImageView)
    }

    // MARK: - Layout

    /// 고정 크기 반환
    override var intrinsicContentSize: CGSize {
        return CGSize(width: buttonSize.dimension, height: buttonSize.dimension)
    }

    // C-5: preload() 이후 동적 생성된 버튼도 블러 오버레이 자동 생성
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil && !glassViewSetupDeferred {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                LiquidGlassOptimizer.preload(in: self)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = buttonSize.cornerRadius

        // deferred 상태면 glassView 접근 스킵 (lazy 트리거 방지)
        if !glassViewSetupDeferred {
            // Glass View 크기/위치 업데이트 (bounds+center 사용 — transform과 독립적)
            glassView.bounds = CGRect(origin: .zero, size: bounds.size)
            glassView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            glassView.layer.cornerRadius = cornerRadius
            glassView.layer.cornerCurve = .continuous
            glassView.clipsToBounds = true
        }

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
            pointSize: customIconPointSize ?? buttonSize.iconPointSize,
            weight: .light  // setupIcon과 동일하게 light
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

    // MARK: - Glass Effect Lazy Setup (Phase 6)

    /// Glass 효과 생성 (보일 때 호출)
    /// hidden 상태에서 deferred된 MTKView를 실제로 생성
    func setupGlassEffectIfNeeded() {
        guard glassViewSetupDeferred else { return }
        glassViewSetupDeferred = false

        // Glass 뷰를 최하단에 삽입
        insertSubview(glassView, at: 0)

        setNeedsLayout()
        layoutIfNeeded()

        // C-5: deferred된 MTKView에 대해 Optimizer 블러 오버레이 생성
        LiquidGlassOptimizer.preload(in: self)
    }

    /// isHidden 변경 시 deferred된 Glass 효과 자동 생성
    override var isHidden: Bool {
        didSet {
            if !isHidden && glassViewSetupDeferred {
                setupGlassEffectIfNeeded()
            }
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
        guard !glassViewSetupDeferred else { return }
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
        guard !glassViewSetupDeferred else { return }
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

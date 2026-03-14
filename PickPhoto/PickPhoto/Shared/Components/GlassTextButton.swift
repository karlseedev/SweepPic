// GlassTextButton.swift
// 텍스트 전용 Liquid Glass 버튼 컴포넌트
//
// - 특징: 1뷰 scale 애니메이션, 굴절 효과
// - Resting: LiquidGlassEffect 적용
// - Pressed: scale 확대 (1.08)
// - 높이: 44pt 고정, 너비: 텍스트에 따라 동적
// - 용도: cancelButton, deleteButton 등 텍스트 버튼에 사용

import UIKit
import LiquidGlassKit
import MetalKit

/// 텍스트 전용 Liquid Glass 버튼
/// - cancelButton, deleteButton 등 텍스트만 있는 버튼에 사용
/// - 터치 시 scale 애니메이션으로 피드백 제공
class GlassTextButton: UIButton {

    // MARK: - Types

    /// 버튼 스타일
    enum Style {
        case plain      // Glass 배경 + 텍스트 (취소 버튼 등)
        case filled     // Glass 배경 + 색상 오버레이 + 흰색 텍스트 (삭제 버튼 등)
    }

    // MARK: - Constants

    private enum Constants {
        static let height: CGFloat = 44
        static let cornerRadius: CGFloat = 22  // height / 2, pill shape
        static let fontSize: CGFloat = 17
        static let horizontalPadding: CGFloat = 32  // 좌우 패딩 (16pt × 2)
        static let verticalPadding: CGFloat = 16    // 멀티라인 시 상하 패딩 (8pt × 2)
    }

    // MARK: - UI Components

    /// Glass 배경 tintColor (nil이면 기본값 사용)
    private let glassTintColor: UIColor

    /// Glass 효과 뷰 (1뷰 구조)
    /// LiquidGlassEffect 사용 - 터치 시 scale 애니메이션으로 피드백
    private lazy var glassView: AnyVisualEffectView = {
        let effect = LiquidGlassEffect(style: .regular, isNative: true)
        effect.tintColor = glassTintColor
        let view = VisualEffectView(effect: effect)
        view.isUserInteractionEnabled = false
        return view
    }()

    /// 색상 오버레이 (filled 스타일용)
    private lazy var colorOverlay: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.alpha = 0.3
        return view
    }()

    /// 멀티라인 설정값 (init 시 결정)
    private let multilineEnabled: Bool

    /// 멀티라인용 폰트 크기
    private let labelFontSize: CGFloat

    /// 텍스트 라벨
    private lazy var textLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: labelFontSize, weight: .regular)
        label.textAlignment = .center
        label.numberOfLines = multilineEnabled ? 0 : 1
        label.isUserInteractionEnabled = false
        return label
    }()

    // MARK: - Properties

    /// 버튼 스타일
    private let style: Style

    /// 텍스트 색상
    private var textTintColor: UIColor

    /// 현재 텍스트 (변경 추적용)
    private var buttonTitle: String

    /// Glass 효과 생성 지연 플래그 (Phase 6: hidden 상태 버튼의 MTKView 절약)
    private var glassViewSetupDeferred = false

    // MARK: - State Management

    override var isEnabled: Bool {
        didSet { updateStateStyles() }
    }

    // MARK: - Init

    /// 텍스트 버튼 생성
    /// - Parameters:
    ///   - title: 버튼 텍스트
    ///   - style: 버튼 스타일 (기본: .plain)
    ///   - tintColor: 텍스트 색상 (기본: .white, filled 스타일에서는 배경색으로도 사용)
    ///   - deferGlassEffect: Glass 효과 생성 지연 (hidden 상태 최적화)
    ///   - multiline: 멀티라인 허용 (기본: false, true면 \n 줄바꿈 지원 + 동적 높이)
    ///   - fontSize: 폰트 크기 (기본: 17, 멀티라인 보조 버튼 등에서 작은 크기 사용)
    ///   - glassTintColor: Glass 배경 tintColor (기본: 중간회색 20%)
    init(title: String, style: Style = .plain, tintColor: UIColor = .white,
         deferGlassEffect: Bool = false, multiline: Bool = false, fontSize: CGFloat = Constants.fontSize,
         glassTintColor: UIColor = UIColor(white: 0.5, alpha: 0.2)) {
        self.style = style
        self.textTintColor = tintColor
        self.buttonTitle = title
        self.glassViewSetupDeferred = deferGlassEffect
        self.multilineEnabled = multiline
        self.labelFontSize = fontSize
        self.glassTintColor = glassTintColor

        super.init(frame: .zero)

        setupText(title)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    /// 텍스트 설정
    private func setupText(_ title: String) {
        textLabel.text = title

        switch style {
        case .plain:
            // Glass 배경 + 컬러 텍스트
            textLabel.textColor = textTintColor
        case .filled:
            // Glass 배경 + 색상 오버레이 + 흰색 텍스트
            textLabel.textColor = .white
            colorOverlay.backgroundColor = textTintColor
        }
    }

    private func setupLayers() {
        // 그림자를 위해 버튼 자체의 clipsToBounds는 false여야 함
        self.layer.masksToBounds = false

        if !glassViewSetupDeferred {
            // Glass 뷰 추가 (1뷰 구조)
            insertSubview(glassView, at: 0)

            // filled 스타일이면 색상 오버레이 추가 (glassView 위에)
            if style == .filled {
                insertSubview(colorOverlay, aboveSubview: glassView)
            }
        } else {
            // deferred: glassView 접근 없이 colorOverlay만 추가 (lazy 트리거 방지)
            if style == .filled {
                addSubview(colorOverlay)
            }
        }

        // 텍스트는 최상단
        addSubview(textLabel)
    }

    // MARK: - Layout

    /// 높이/너비 반환 (멀티라인: 동적 높이, 단일: 고정 44pt)
    override var intrinsicContentSize: CGSize {
        if multilineEnabled {
            // 멀티라인: 텍스트 높이에 맞춰 동적 계산
            let textSize = textLabel.intrinsicContentSize
            let totalWidth = textSize.width + Constants.horizontalPadding
            let totalHeight = max(Constants.height, textSize.height + Constants.verticalPadding)
            return CGSize(width: totalWidth, height: totalHeight)
        } else {
            // 단일 라인: 고정 높이
            let textWidth = textLabel.intrinsicContentSize.width
            let totalWidth = textWidth + Constants.horizontalPadding
            return CGSize(width: totalWidth, height: Constants.height)
        }
    }

    // C-5: preload() 이후 동적 생성된 버튼도 블러 오버레이 자동 생성
    // iOS 26+: 네이티브 UIGlassEffect 사용 → MTKView 없음 → preload 불필요
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if #available(iOS 26.0, *) { return }
        if window != nil && !glassViewSetupDeferred {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                LiquidGlassOptimizer.preload(in: self)
            }
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        // DEBUG: 비우기/선택 버튼 속성 비교
        if buttonTitle == "비우기" || buttonTitle == "선택" {
            print("🔍 [\(buttonTitle)] bounds=\(bounds), alpha=\(alpha), enabled=\(isEnabled), hidden=\(isHidden), glass.bounds=\(glassView.bounds), tint=\(textTintColor)")
        }

        // pill shape: 높이의 절반 (단일/멀티라인 모두)
        let cornerRadius = bounds.height / 2

        // deferred 상태면 glassView 접근 스킵 (lazy 트리거 방지)
        if !glassViewSetupDeferred {
            // Glass View 크기/위치 업데이트 (bounds+center 사용 — transform과 독립적)
            glassView.bounds = CGRect(origin: .zero, size: bounds.size)
            glassView.center = CGPoint(x: bounds.midX, y: bounds.midY)
            glassView.layer.cornerRadius = cornerRadius
            glassView.layer.cornerCurve = .continuous
            glassView.clipsToBounds = true
        }

        // 색상 오버레이 (filled 스타일)
        if style == .filled {
            colorOverlay.frame = bounds
            colorOverlay.layer.cornerRadius = cornerRadius
            colorOverlay.layer.cornerCurve = .continuous
            colorOverlay.clipsToBounds = true
        }

        // Update Shadow (버튼 레이어에 직접 적용)
        LiquidGlassStyle.applyShadow(to: self.layer, cornerRadius: cornerRadius)

        // 텍스트 중앙 배치
        textLabel.frame = bounds
    }

    // MARK: - Public Methods

    /// 텍스트 색상 변경 (plain 스타일: 텍스트 색상, filled 스타일: 배경 오버레이 색상)
    /// - Parameter color: 새 텍스트 색상
    func setTextColor(_ color: UIColor) {
        textTintColor = color
        switch style {
        case .plain:
            textLabel.textColor = color
        case .filled:
            colorOverlay.backgroundColor = color
        }
    }

    /// 텍스트 변경
    /// - Parameters:
    ///   - title: 새 텍스트
    ///   - animated: 애니메이션 적용 여부 (기본: false)
    func setButtonTitle(_ title: String, animated: Bool = false) {
        guard title != buttonTitle else { return }
        buttonTitle = title

        if animated {
            // 크로스페이드 애니메이션
            UIView.transition(
                with: textLabel,
                duration: 0.2,
                options: .transitionCrossDissolve
            ) {
                self.textLabel.text = title
            } completion: { _ in
                self.invalidateIntrinsicContentSize()
            }
        } else {
            textLabel.text = title
            invalidateIntrinsicContentSize()
        }
    }

    /// Glass 뷰 배경색 설정 (iOS 18 이하에서 어두운 배경 위 가시성 확보용)
    /// glassView가 이미 clipsToBounds + cornerRadius 적용이므로 pill shape으로 자연스럽게 잘림
    func setGlassBackground(_ color: UIColor?) {
        glassView.backgroundColor = color
    }

    // MARK: - Glass Effect Lazy Setup (Phase 6)

    /// Glass 효과 생성 (보일 때 호출)
    /// hidden 상태에서 deferred된 MTKView를 실제로 생성
    func setupGlassEffectIfNeeded() {
        guard glassViewSetupDeferred else { return }
        glassViewSetupDeferred = false

        // Glass 뷰를 최하단에 삽입
        insertSubview(glassView, at: 0)

        // filled 스타일이면 colorOverlay를 glassView 바로 위로 이동
        if style == .filled {
            insertSubview(colorOverlay, aboveSubview: glassView)
        }

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
            // 배경 alpha는 항상 100% 유지, 글씨 색상만 변경
            if self.isEnabled {
                // 활성화: 원래 텍스트 색상 복원
                self.textLabel.textColor = self.style == .plain ? self.textTintColor : .white
            } else {
                // 비활성화: 50% 중간 그레이
                self.textLabel.textColor = UIColor(white: 0.5, alpha: 1.0)
            }
        }
    }
}

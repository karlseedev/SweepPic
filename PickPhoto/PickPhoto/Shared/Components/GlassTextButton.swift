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

    /// 색상 오버레이 (filled 스타일용)
    private lazy var colorOverlay: UIView = {
        let view = UIView()
        view.isUserInteractionEnabled = false
        view.alpha = 0.3
        return view
    }()

    /// 텍스트 라벨
    private let textLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: Constants.fontSize, weight: .regular)
        label.textAlignment = .center
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
    init(title: String, style: Style = .plain, tintColor: UIColor = .white) {
        self.style = style
        self.textTintColor = tintColor
        self.buttonTitle = title

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

        // Glass 뷰 추가 (1뷰 구조)
        insertSubview(glassView, at: 0)

        // filled 스타일이면 색상 오버레이 추가 (glassView 위에)
        if style == .filled {
            insertSubview(colorOverlay, aboveSubview: glassView)
        }

        // 텍스트는 최상단
        addSubview(textLabel)
    }

    // MARK: - Layout

    /// 고정 높이, 동적 너비 반환
    override var intrinsicContentSize: CGSize {
        let textWidth = textLabel.intrinsicContentSize.width
        let totalWidth = textWidth + Constants.horizontalPadding
        return CGSize(width: totalWidth, height: Constants.height)
    }

    override func layoutSubviews() {
        super.layoutSubviews()

        let cornerRadius = Constants.cornerRadius

        // Glass View 프레임 및 코너 업데이트
        glassView.frame = bounds
        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.cornerCurve = .continuous
        glassView.clipsToBounds = true

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
        let duration: TimeInterval = animated ? 0.4 : 0
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0,
            options: .beginFromCurrentState
        ) {
            self.glassView.transform = CGAffineTransform(scaleX: 1.08, y: 1.08)
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

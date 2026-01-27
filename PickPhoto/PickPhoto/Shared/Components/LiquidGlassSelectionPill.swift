// LiquidGlassSelectionPill.swift
// Liquid Glass 스타일 Selection Pill 컴포넌트
//
// iOS 26 TabBar 선택 표시와 동일한 시각 효과 구현
// - 블러 배경 (systemThinMaterialDark)
// - Spring 애니메이션으로 이동
// - 94×54pt, cornerRadius 27pt

import UIKit
import AppCore

/// Liquid Glass 스타일 Selection Pill
/// 현재 선택된 탭을 표시하는 배경 Pill
final class LiquidGlassSelectionPill: UIView {

    // MARK: - Properties

    /// leading constraint 저장 (애니메이션용)
    private(set) var leadingConstraint: NSLayoutConstraint?

    // MARK: - UI Components

    /// 블러 배경
    private lazy var pillBlur: UIVisualEffectView = {
        let effect = UIBlurEffect(style: LiquidGlassConstants.Blur.pillStyle)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupUI() {
        // 코너 설정
        layer.cornerRadius = LiquidGlassConstants.SelectionPill.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        // zPosition 설정 (최상단)
        layer.zPosition = LiquidGlassConstants.ZPosition.selectionPill

        // 블러 배경 추가
        addSubview(pillBlur)

        // 테두리 적용
        LiquidGlassStyle.applyBorder(to: layer, cornerRadius: LiquidGlassConstants.SelectionPill.cornerRadius)

        Log.print("[LiquidGlassSelectionPill] Initialized")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // pillBlur: 전체 영역
            pillBlur.topAnchor.constraint(equalTo: topAnchor),
            pillBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            pillBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            pillBlur.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Public Methods

    /// 특정 버튼 위치로 이동
    /// - Parameters:
    ///   - button: 이동할 대상 버튼
    ///   - animated: 애니메이션 여부
    func moveTo(button: UIView, animated: Bool) {
        // Auto Layout 완료 보장 후 frame 접근
        button.superview?.layoutIfNeeded()

        let newLeading = button.frame.origin.x

        if animated {
            UIView.animate(
                withDuration: LiquidGlassConstants.Animation.duration,
                delay: 0,
                usingSpringWithDamping: LiquidGlassConstants.Animation.dampingRatio,
                initialSpringVelocity: LiquidGlassConstants.Animation.initialVelocity,
                options: .curveEaseInOut
            ) {
                self.leadingConstraint?.constant = newLeading
                self.superview?.layoutIfNeeded()
            }
        } else {
            leadingConstraint?.constant = newLeading
            superview?.layoutIfNeeded()
        }

        Log.print("[LiquidGlassSelectionPill] Moved to x: \(newLeading), animated: \(animated)")
    }

    /// leading constraint를 외부에서 설정
    /// - Parameter constraint: NSLayoutConstraint
    func setLeadingConstraint(_ constraint: NSLayoutConstraint) {
        self.leadingConstraint = constraint
    }
}

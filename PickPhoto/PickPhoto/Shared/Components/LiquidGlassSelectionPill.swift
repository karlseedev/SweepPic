// LiquidGlassSelectionPill.swift
// Liquid Glass 스타일 Selection Pill 컴포넌트
//
// iOS 26 TabBar 선택 표시와 동일한 시각 효과 구현
// - LiquidGlassKit의 LiquidLensView 사용
// - setLifted() 메소드로 resting/lifted 상태 전환
// - 탭 전환 시 squash/stretch 효과 자동 적용
// - 94×54pt, cornerRadius 27pt

import UIKit
import AppCore
import LiquidGlassKit

/// Liquid Glass 스타일 Selection Pill
/// 현재 선택된 탭을 표시하는 배경 Pill
/// LiquidGlassKit의 LiquidLensView를 사용하여 iOS 26 스타일 squash/stretch 효과 구현
final class LiquidGlassSelectionPill: UIView {

    // MARK: - Properties

    /// leading constraint 저장 (애니메이션용)
    private(set) var leadingConstraint: NSLayoutConstraint?

    /// MTKView 초기 pause 설정 완료 여부
    private var hasInitializedPause = false

    // MARK: - UI Components

    /// LiquidGlassKit 기반 Lens 뷰
    /// - resting 상태: 일반 배경
    /// - lifted 상태: 굴절 효과 + squash/stretch 활성화
    private lazy var lensView: LiquidLensView = {
        let view = LiquidLensView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // 기본 배경보다 50% 더 투명하게 설정
        view.restingBackgroundColor = UIColor.white.withAlphaComponent(0.15)
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

        // zPosition 설정 (탭 버튼 뒤)
        layer.zPosition = LiquidGlassConstants.ZPosition.selectionPill

        // LiquidLensView 추가
        // LiquidGlassKit이 블러, 굴절, 테두리를 처리
        addSubview(lensView)

        Log.print("[LiquidGlassSelectionPill] Initialized with LiquidGlassKit")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // lensView: 전체 영역
            lensView.topAnchor.constraint(equalTo: topAnchor),
            lensView.leadingAnchor.constraint(equalTo: leadingAnchor),
            lensView.trailingAnchor.constraint(equalTo: trailingAnchor),
            lensView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // 최초 1회: lensView 내부 MTKView를 pause (resting 상태에서 렌더링 불필요)
        if !hasInitializedPause {
            let mtkViews = LiquidGlassOptimizer.findAllMTKViews(in: lensView)
            if !mtkViews.isEmpty {
                LiquidGlassOptimizer.setMTKViewsPaused(true, in: lensView)
                hasInitializedPause = true
            }
        }
    }

    // MARK: - Public Methods

    /// 특정 버튼 위치로 이동
    /// LiquidLensView의 setLifted()를 사용하여 squash/stretch 효과 적용
    /// - Parameters:
    ///   - button: 이동할 대상 버튼
    ///   - animated: 애니메이션 여부
    func moveTo(button: UIView, animated: Bool) {
        // Auto Layout 완료 보장 후 frame 접근
        button.superview?.layoutIfNeeded()

        let newLeading = button.frame.origin.x

        if animated {
            // lifted 전 MTKView 활성화 (렌더링 재개)
            LiquidGlassOptimizer.setMTKViewsPaused(false, in: lensView)

            // lifted 상태로 전환 → 이동 → resting 상태로 복귀
            // setLifted(true) 시 굴절 효과 활성화 + squash/stretch 애니메이션
            lensView.setLifted(true, animated: true, alongsideAnimations: {
                self.leadingConstraint?.constant = newLeading
                self.superview?.layoutIfNeeded()
            }, completion: { _ in
                // 이동 완료 후 resting 상태로 복귀
                self.lensView.setLifted(false, animated: true,
                                        alongsideAnimations: nil,
                                        completion: { _ in
                    // resting 복귀 완료 후 pause (렌더링 불필요)
                    LiquidGlassOptimizer.setMTKViewsPaused(true, in: self.lensView)
                })
            })
        } else {
            // 비애니메이션: resume → 위치 변경 → 1프레임 렌더 후 pause
            LiquidGlassOptimizer.setMTKViewsPaused(false, in: lensView)
            leadingConstraint?.constant = newLeading
            superview?.layoutIfNeeded()
            DispatchQueue.main.async {
                LiquidGlassOptimizer.setMTKViewsPaused(true, in: self.lensView)
            }
        }

        Log.print("[LiquidGlassSelectionPill] Moved to x: \(newLeading), animated: \(animated)")
    }

    /// leading constraint를 외부에서 설정
    /// - Parameter constraint: NSLayoutConstraint
    func setLeadingConstraint(_ constraint: NSLayoutConstraint) {
        self.leadingConstraint = constraint
    }
}

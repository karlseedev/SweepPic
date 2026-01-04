// BorderAnimationLayer.swift
// 유사 사진 테두리 애니메이션 레이어
//
// T020: BorderAnimationLayer 생성
// - CAShapeLayer + 빛 도는 애니메이션
// - 흰색 그라데이션, 시계방향 회전, 1.5초 주기
// - 모션 감소 시 정적 테두리 (흰색 2pt)

import UIKit
import QuartzCore

/// 유사 사진 테두리 애니메이션 레이어
/// 그리드 셀에 빛이 도는 테두리 효과를 표시
final class BorderAnimationLayer: CALayer {

    // MARK: - Constants

    /// 애니메이션 주기 (1.5초)
    static let animationDuration: CFTimeInterval = 1.5

    /// 정적 테두리 두께 (모션 감소 시)
    static let staticBorderWidth: CGFloat = 2.0

    /// 그라데이션 테두리 두께 (애니메이션)
    static let animatedBorderWidth: CGFloat = 3.0

    /// 빛 그라데이션 길이 비율 (전체 둘레 대비)
    static let gradientLengthRatio: CGFloat = 0.25

    // MARK: - Sublayers

    /// 테두리 형태 레이어 (기본 테두리)
    private var borderShapeLayer: CAShapeLayer?

    /// 빛 효과 그라데이션 레이어
    private var lightGradientLayer: CAGradientLayer?

    /// 빛 효과 마스크 레이어
    private var lightMaskLayer: CAShapeLayer?

    // MARK: - State

    /// 애니메이션 활성화 여부
    private var isAnimating: Bool = false

    /// 모션 감소 설정 여부
    private var isReduceMotionEnabled: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }

    // MARK: - Initialization

    override init() {
        super.init()
        setupLayers()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        if let other = layer as? BorderAnimationLayer {
            self.isAnimating = other.isAnimating
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    // MARK: - Setup

    /// 레이어 설정
    private func setupLayers() {
        // 기본 설정
        masksToBounds = false

        if isReduceMotionEnabled {
            setupStaticBorder()
        } else {
            setupAnimatedBorder()
        }
    }

    /// 정적 테두리 설정 (모션 감소 시)
    private func setupStaticBorder() {
        // 기존 레이어 정리
        clearSublayers()

        // 정적 테두리 레이어 생성
        let shapeLayer = CAShapeLayer()
        shapeLayer.fillColor = nil
        shapeLayer.strokeColor = UIColor.white.cgColor
        shapeLayer.lineWidth = Self.staticBorderWidth
        shapeLayer.lineCap = .square
        shapeLayer.lineJoin = .miter

        addSublayer(shapeLayer)
        borderShapeLayer = shapeLayer

        // 경로 업데이트
        updateBorderPath()
    }

    /// 애니메이션 테두리 설정
    private func setupAnimatedBorder() {
        // 기존 레이어 정리
        clearSublayers()

        // 1. 기본 테두리 레이어 (어두운 테두리)
        let baseLayer = CAShapeLayer()
        baseLayer.fillColor = nil
        baseLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor
        baseLayer.lineWidth = Self.animatedBorderWidth
        baseLayer.lineCap = .square
        baseLayer.lineJoin = .miter
        addSublayer(baseLayer)
        borderShapeLayer = baseLayer

        // 2. 빛 그라데이션 레이어 (회전하는 밝은 부분)
        let gradientLayer = CAGradientLayer()
        gradientLayer.type = .conic
        gradientLayer.colors = [
            UIColor.white.cgColor,
            UIColor.white.withAlphaComponent(0.8).cgColor,
            UIColor.white.withAlphaComponent(0.5).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        // 위치: 0에서 gradientLength까지 밝고 나머지 투명
        let gradientLength = Self.gradientLengthRatio
        gradientLayer.locations = [
            0.0,
            NSNumber(value: Double(gradientLength * 0.3)),
            NSNumber(value: Double(gradientLength * 0.6)),
            NSNumber(value: Double(gradientLength)),
            1.0
        ]
        // 시작점: 상단 중앙 (12시 방향)
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 0.0)

        addSublayer(gradientLayer)
        lightGradientLayer = gradientLayer

        // 3. 빛 마스크 레이어 (테두리 영역만 표시)
        let maskLayer = CAShapeLayer()
        maskLayer.fillColor = nil
        maskLayer.strokeColor = UIColor.white.cgColor
        maskLayer.lineWidth = Self.animatedBorderWidth
        maskLayer.lineCap = .square
        maskLayer.lineJoin = .miter

        gradientLayer.mask = maskLayer
        lightMaskLayer = maskLayer

        // 경로 업데이트
        updateBorderPath()
    }

    /// 서브레이어 정리
    private func clearSublayers() {
        borderShapeLayer?.removeFromSuperlayer()
        lightGradientLayer?.removeFromSuperlayer()

        borderShapeLayer = nil
        lightGradientLayer = nil
        lightMaskLayer = nil
    }

    // MARK: - Layout

    override func layoutSublayers() {
        super.layoutSublayers()
        updateBorderPath()
    }

    /// 테두리 경로 업데이트
    private func updateBorderPath() {
        guard bounds.width > 0, bounds.height > 0 else { return }

        // 테두리 경로 (인셋으로 레이어 내부에 표시)
        let inset = (isReduceMotionEnabled ? Self.staticBorderWidth : Self.animatedBorderWidth) / 2
        let borderRect = bounds.insetBy(dx: inset, dy: inset)
        let borderPath = UIBezierPath(rect: borderRect)

        // 기본 테두리 경로 설정
        borderShapeLayer?.path = borderPath.cgPath
        borderShapeLayer?.frame = bounds

        // 그라데이션 레이어 프레임 설정
        lightGradientLayer?.frame = bounds

        // 마스크 레이어 경로 설정
        lightMaskLayer?.path = borderPath.cgPath
        lightMaskLayer?.frame = bounds
    }

    // MARK: - Animation Control

    /// 애니메이션 시작
    func startAnimation() {
        // 모션 감소 시 애니메이션 없음
        guard !isReduceMotionEnabled else { return }
        guard !isAnimating else { return }

        isAnimating = true

        // 그라데이션 회전 애니메이션
        let rotation = CABasicAnimation(keyPath: "transform.rotation.z")
        rotation.fromValue = 0
        rotation.toValue = CGFloat.pi * 2
        rotation.duration = Self.animationDuration
        rotation.repeatCount = .infinity
        rotation.timingFunction = CAMediaTimingFunction(name: .linear)
        rotation.isRemovedOnCompletion = false

        lightGradientLayer?.add(rotation, forKey: "rotationAnimation")
    }

    /// 애니메이션 중지
    func stopAnimation() {
        guard isAnimating else { return }

        isAnimating = false
        lightGradientLayer?.removeAnimation(forKey: "rotationAnimation")
    }

    /// 레이어 제거 및 정리
    func cleanup() {
        stopAnimation()
        removeFromSuperlayer()
    }

    // MARK: - Accessibility

    /// 모션 감소 설정 변경 시 호출
    func handleReduceMotionChange() {
        let wasAnimating = isAnimating

        // 레이어 재설정
        if isReduceMotionEnabled {
            setupStaticBorder()
        } else {
            setupAnimatedBorder()
            if wasAnimating {
                startAnimation()
            }
        }
    }
}

// MARK: - Factory Method

extension BorderAnimationLayer {

    /// 셀에 테두리 레이어 추가
    /// - Parameters:
    ///   - cell: 대상 셀
    ///   - animated: 애니메이션 시작 여부
    /// - Returns: 생성된 BorderAnimationLayer
    @discardableResult
    static func addToCell(
        _ cell: UICollectionViewCell,
        animated: Bool = true
    ) -> BorderAnimationLayer {
        // 기존 레이어 제거
        removeBorderLayer(from: cell)

        // 새 레이어 생성 및 추가
        let borderLayer = BorderAnimationLayer()
        borderLayer.frame = cell.bounds
        cell.layer.addSublayer(borderLayer)

        if animated {
            borderLayer.startAnimation()
        }

        return borderLayer
    }

    /// 셀에서 테두리 레이어 제거
    /// - Parameter cell: 대상 셀
    static func removeBorderLayer(from cell: UICollectionViewCell) {
        cell.layer.sublayers?.compactMap { $0 as? BorderAnimationLayer }
            .forEach { $0.cleanup() }
    }

    /// 셀에서 테두리 레이어 가져오기
    /// - Parameter cell: 대상 셀
    /// - Returns: BorderAnimationLayer (없으면 nil)
    static func getBorderLayer(from cell: UICollectionViewCell) -> BorderAnimationLayer? {
        return cell.layer.sublayers?.compactMap { $0 as? BorderAnimationLayer }.first
    }
}

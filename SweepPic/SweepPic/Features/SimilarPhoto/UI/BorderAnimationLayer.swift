//
//  BorderAnimationLayer.swift
//  SweepPic
//
//  Created by Claude on 2026/01/05.
//
//  빛이 도는 테두리 애니메이션 레이어
//  - CAShapeLayer + CAKeyframeAnimation 기반
//  - 시계방향 회전, 흰색 그라데이션
//  - 1.5초 주기 애니메이션
//  - 모션 감소 설정 시 정적 테두리 표시
//  - 모든 셀 동일 위상 동기화 (CACurrentMediaTime 기준)
//

import UIKit

// MARK: - BorderAnimationLayer

/// 유사 사진 그룹의 테두리 애니메이션을 표시하는 레이어
/// - 그리드 셀에 추가되어 빛이 도는 효과를 표현
/// - 모션 감소 설정 시 정적 흰색 테두리로 대체
final class BorderAnimationLayer: CALayer {

    // MARK: - Constants

    /// 애니메이션 관련 상수
    private enum AnimationConstants {
        /// 애니메이션 주기 (초)
        static let animationDuration: CFTimeInterval = 1.5

        /// 테두리 선 두께
        static let lineWidth: CGFloat = 2.0

        /// 그라데이션 빛의 길이 비율 (0~1)
        static let glowLength: CGFloat = 0.25

        /// 애니메이션 키
        static let animationKey = "borderGlowAnimation"

        /// 모션 감소 시 테두리 선 두께
        static let staticLineWidth: CGFloat = 2.0
    }

    // MARK: - Sublayers

    /// 테두리 경로를 그리는 shape 레이어
    private let borderShapeLayer = CAShapeLayer()

    /// 그라데이션 효과를 위한 마스크 레이어
    private let glowMaskLayer = CAShapeLayer()

    /// 그라데이션 레이어 (빛 효과)
    private let gradientLayer = CAGradientLayer()

    // MARK: - State

    /// 애니메이션 활성화 상태
    private(set) var isAnimating: Bool = false

    /// 정적 테두리 표시 상태
    private(set) var isShowingStatic: Bool = false

    // MARK: - Initialization

    override init() {
        super.init()
        setupLayers()
    }

    override init(layer: Any) {
        super.init(layer: layer)
        // 프레젠테이션 레이어 복사 시 필요
        if let other = layer as? BorderAnimationLayer {
            self.isAnimating = other.isAnimating
            self.isShowingStatic = other.isShowingStatic
        }
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    // MARK: - Setup

    /// 레이어 초기 설정
    private func setupLayers() {
        // borderShapeLayer 설정
        // - 테두리 경로만 그리고, 채우기는 하지 않음
        borderShapeLayer.fillColor = nil
        borderShapeLayer.strokeColor = UIColor.white.cgColor
        borderShapeLayer.lineWidth = AnimationConstants.lineWidth
        borderShapeLayer.lineCap = .round
        borderShapeLayer.lineJoin = .round

        // glowMaskLayer 설정 (그라데이션 마스크용)
        // - strokeStart/strokeEnd로 빛 위치 조절
        glowMaskLayer.fillColor = nil
        glowMaskLayer.strokeColor = UIColor.white.cgColor
        glowMaskLayer.lineWidth = AnimationConstants.lineWidth
        glowMaskLayer.lineCap = .round
        glowMaskLayer.strokeStart = 0.0
        glowMaskLayer.strokeEnd = AnimationConstants.glowLength

        // gradientLayer 설정 (흰색 그라데이션)
        // - 시작: 불투명 흰색, 끝: 투명 흰색
        gradientLayer.colors = [
            UIColor.white.cgColor,
            UIColor.white.withAlphaComponent(0.8).cgColor,
            UIColor.white.withAlphaComponent(0.4).cgColor,
            UIColor.white.withAlphaComponent(0.0).cgColor
        ]
        gradientLayer.locations = [0.0, 0.3, 0.6, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0.0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1.0)
        gradientLayer.type = .axial

        // 레이어 계층 구성
        // - gradientLayer에 glowMaskLayer를 마스크로 적용
        gradientLayer.mask = glowMaskLayer

        // 서브레이어 추가
        // - borderShapeLayer: 기본 테두리 (약간 투명하게)
        // - gradientLayer: 빛 효과 (마스크로 이동하는 빛 표현)
        addSublayer(borderShapeLayer)
        addSublayer(gradientLayer)

        // 기본적으로 숨김
        isHidden = true
    }

    // MARK: - Layout

    override func layoutSublayers() {
        super.layoutSublayers()
        updatePath()
    }

    /// 경로 업데이트
    /// - 레이어 bounds에 맞춰 사각형 경로 생성
    private func updatePath() {
        // 사각형 경로 생성 (cornerRadius 없음)
        // - 셀 내부에 맞게 inset 적용
        let inset = AnimationConstants.lineWidth / 2
        let pathRect = bounds.insetBy(dx: inset, dy: inset)
        let path = UIBezierPath(rect: pathRect)

        // 모든 레이어에 동일한 경로 적용
        borderShapeLayer.path = path.cgPath
        glowMaskLayer.path = path.cgPath
        borderShapeLayer.frame = bounds
        glowMaskLayer.frame = bounds
        gradientLayer.frame = bounds
    }

    // MARK: - Animation Control

    /// 애니메이션 시작
    /// - 모든 셀이 동일한 위상으로 동기화됨
    /// - 모션 감소 설정 시 정적 테두리로 대체
    func startAnimation() {
        // 이미 애니메이션 중이면 무시
        guard !isAnimating else { return }

        // 모션 감소 설정 확인
        if UIAccessibility.isReduceMotionEnabled {
            showStaticBorder()
            return
        }

        // 레이어 표시
        isHidden = false
        isAnimating = true
        isShowingStatic = false

        // 기본 테두리 약간 투명하게 (빛 효과와 구분)
        borderShapeLayer.strokeColor = UIColor.white.withAlphaComponent(0.3).cgColor

        // 경로 업데이트
        updatePath()

        // strokeEnd 애니메이션 생성
        // - 빛이 시계방향으로 이동하는 효과
        let strokeEndAnimation = CAKeyframeAnimation(keyPath: "strokeEnd")
        strokeEndAnimation.values = [
            AnimationConstants.glowLength,  // 시작: 0.25
            1.0 + AnimationConstants.glowLength  // 끝: 1.25 (한 바퀴 + 25%)
        ]
        strokeEndAnimation.keyTimes = [0.0, 1.0]
        strokeEndAnimation.calculationMode = .linear

        // strokeStart 애니메이션 생성
        // - strokeEnd와 함께 이동하여 일정 길이 유지
        let strokeStartAnimation = CAKeyframeAnimation(keyPath: "strokeStart")
        strokeStartAnimation.values = [
            0.0,  // 시작: 0
            1.0   // 끝: 1.0 (한 바퀴)
        ]
        strokeStartAnimation.keyTimes = [0.0, 1.0]
        strokeStartAnimation.calculationMode = .linear

        // 애니메이션 그룹
        let animationGroup = CAAnimationGroup()
        animationGroup.animations = [strokeEndAnimation, strokeStartAnimation]
        animationGroup.duration = AnimationConstants.animationDuration
        animationGroup.repeatCount = .infinity
        animationGroup.isRemovedOnCompletion = false
        animationGroup.fillMode = .forwards

        // 동기화: 모든 셀이 동일한 시작점에서 시작하도록
        // - CACurrentMediaTime을 기준으로 beginTime 설정
        let now = CACurrentMediaTime()
        let phase = now.truncatingRemainder(dividingBy: AnimationConstants.animationDuration)
        animationGroup.beginTime = now - phase

        // 애니메이션 적용
        glowMaskLayer.add(animationGroup, forKey: AnimationConstants.animationKey)
    }

    /// 애니메이션 중지
    func stopAnimation() {
        // 애니메이션 제거
        glowMaskLayer.removeAnimation(forKey: AnimationConstants.animationKey)

        // 상태 초기화
        isAnimating = false
        isShowingStatic = false
        isHidden = true

        // 기본 테두리 색상 복원
        borderShapeLayer.strokeColor = UIColor.white.cgColor
    }

    /// 정적 테두리 표시
    /// - 모션 감소 설정 시 호출됨
    /// - 흰색 2pt 실선, cornerRadius 없음
    func showStaticBorder() {
        // 애니메이션이 실행 중이면 중지
        if isAnimating {
            glowMaskLayer.removeAnimation(forKey: AnimationConstants.animationKey)
            isAnimating = false
        }

        // 레이어 표시
        isHidden = false
        isShowingStatic = true

        // 정적 테두리 설정
        // - 흰색 2pt 실선
        borderShapeLayer.strokeColor = UIColor.white.cgColor
        borderShapeLayer.lineWidth = AnimationConstants.staticLineWidth

        // 그라데이션 레이어 숨김 (정적 테두리만 표시)
        gradientLayer.isHidden = true

        // 경로 업데이트
        updatePath()
    }

    /// 레이어 완전 숨김
    /// - 테두리와 애니메이션 모두 제거
    func hide() {
        stopAnimation()
        isHidden = true
        gradientLayer.isHidden = false
    }

    // MARK: - Accessibility

    /// 모션 감소 설정 변경 시 업데이트
    /// - 애니메이션 중이면 정적 테두리로 전환하거나 그 반대
    func updateForAccessibilityChange() {
        if isHidden {
            return
        }

        if UIAccessibility.isReduceMotionEnabled {
            // 모션 감소 활성화: 정적 테두리로 전환
            if isAnimating {
                stopAnimation()
                showStaticBorder()
            }
        } else {
            // 모션 감소 비활성화: 애니메이션으로 전환
            if isShowingStatic {
                gradientLayer.isHidden = false
                isShowingStatic = false
                startAnimation()
            }
        }
    }
}

// MARK: - Factory Method

extension BorderAnimationLayer {

    /// 셀에 추가할 BorderAnimationLayer 생성
    /// - Parameter frame: 레이어 프레임 (셀 bounds)
    /// - Returns: 설정된 BorderAnimationLayer 인스턴스
    static func create(with frame: CGRect) -> BorderAnimationLayer {
        let layer = BorderAnimationLayer()
        layer.frame = frame
        layer.updatePath()
        return layer
    }
}

//
//  SimilarGroupBadgeView.swift
//  PickPhoto
//
//  유사사진 그룹 표시용 코너 삼각형 뱃지
//  - 셀 전체에 흰색 테두리 표시
//  - 우측 상단에 45도 직각이등변삼각형 (흰색 채움)
//  - 삼각형 안에 "=" 아이콘 표시
//  - 대각선 빛 스윕 애니메이션 (좌하→우상)
//  - 테두리와 삼각형이 자연스럽게 연결되는 디자인
//  - 풀링 재사용 지원 (show/stopAndHide 사이클)
//

import UIKit

// MARK: - SimilarGroupBadgeView

/// 유사사진 그룹을 표시하는 코너 삼각형 뱃지 뷰
/// - 셀 전체를 덮어 테두리 + 삼각형을 함께 표현
/// - 흰색 테두리에서 우상단 코너에 흰색 면이 밀고 들어온 형태
/// - 삼각형의 두 직각변은 셀의 상단/우측 테두리와 정확히 일치
/// - 빗변은 45도 각도 (직각이등변삼각형)
/// - 대각선 방향 빛 스윕 애니메이션 (테두리+삼각형 전체)
final class SimilarGroupBadgeView: UIView {

    // MARK: - Constants

    /// 뱃지 관련 상수
    enum BadgeConstants {
        /// 삼각형 직각변 길이 (45도 직각이등변삼각형)
        static let triangleSize: CGFloat = 28
        /// 테두리 선 두께
        static let borderWidth: CGFloat = 2.0
        /// 등호 아이콘 폰트 크기
        static let iconFontSize: CGFloat = 10
        /// 내부 그림자 반경
        static let innerShadowRadius: CGFloat = 4
        /// 내부 그림자 투명도
        static let innerShadowOpacity: Float = 0.4
        /// fade-in 시간 (초)
        static let fadeInDuration: TimeInterval = 0.3
        /// 스윕 애니메이션 시간 (초)
        static let sweepDuration: TimeInterval = 1.5
        /// 스윕 대기 시간 포함 전체 주기 (초)
        static let sweepCycleDuration: TimeInterval = 6.0
    }

    // MARK: - Sublayers & Subviews

    /// 셀 테두리를 그리는 shape 레이어
    private let borderLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = BadgeConstants.borderWidth
        return layer
    }()

    /// 우상단 삼각형 채우기 레이어
    private let triangleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.white.cgColor
        layer.strokeColor = nil
        return layer
    }()

    /// 등호(=) 아이콘 라벨
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.text = "="
        label.font = .systemFont(ofSize: BadgeConstants.iconFontSize, weight: .heavy)
        label.textColor = UIColor(white: 0.3, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()

    /// 테두리+삼각형 안쪽 그림자 컨테이너
    /// - 테두리와 삼각형 빗변에서 셀 안쪽 방향으로 살짝 그림자
    /// - even-odd 기법으로 inner shadow 구현
    private let innerShadowContainer = CALayer()

    /// inner shadow 형상 (큰 외부 사각형 - 내부 오각형, even-odd)
    private let innerShadowShape: CAShapeLayer = {
        let shape = CAShapeLayer()
        shape.fillRule = .evenOdd
        shape.fillColor = UIColor.black.cgColor
        shape.shadowColor = UIColor.black.cgColor
        shape.shadowOffset = .zero
        shape.shadowOpacity = BadgeConstants.innerShadowOpacity
        shape.shadowRadius = BadgeConstants.innerShadowRadius
        return shape
    }()

    /// inner shadow 클리핑 마스크 (오각형: 셀 - 삼각형)
    private let innerShadowMask = CAShapeLayer()

    /// 대각선 스윕 그라데이션 레이어
    /// - 테두리+삼각형 영역에만 보이도록 마스크 적용
    private let sweepGradient: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            UIColor.white.withAlphaComponent(0.7).cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]
        // 초기 위치: 셀 완전히 밖 (좌하)
        layer.locations = [-0.5, -0.4, -0.3, -0.2, -0.1]
        // 대각선 방향 (좌하 → 우상)
        layer.startPoint = CGPoint(x: 0, y: 1)
        layer.endPoint = CGPoint(x: 1, y: 0)
        return layer
    }()

    // MARK: - State

    /// 스윕 애니메이션 활성화 상태
    private var isSweepAnimating = false

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 편의 이니셜라이저
    convenience init() {
        self.init(frame: .zero)
    }

    // MARK: - Setup

    /// 뷰 계층 구성
    private func setupViews() {
        // 터치 이벤트 통과 (아래 셀로 전달)
        isUserInteractionEnabled = false
        isHidden = true
        alpha = 0
        backgroundColor = .clear

        // 내부 그림자 레이어 추가 (최하위, 사진 위에 그림자)
        innerShadowContainer.addSublayer(innerShadowShape)
        innerShadowContainer.mask = innerShadowMask
        layer.addSublayer(innerShadowContainer)

        // 테두리 레이어 추가
        layer.addSublayer(borderLayer)

        // 삼각형 레이어 추가
        layer.addSublayer(triangleLayer)

        // 스윕 그라데이션 레이어 추가 (테두리+삼각형 위에)
        layer.addSublayer(sweepGradient)

        // 등호 아이콘 추가 (최상위)
        addSubview(iconLabel)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePaths()
        updateInnerShadow()
        updateIconPosition()
        updateSweepMask()
    }

    /// 테두리 및 삼각형 경로 업데이트
    private func updatePaths() {
        let inset = BadgeConstants.borderWidth / 2

        // 테두리 경로 (셀 전체 사각형)
        let borderRect = bounds.insetBy(dx: inset, dy: inset)
        borderLayer.path = UIBezierPath(rect: borderRect).cgPath
        borderLayer.frame = bounds

        // 삼각형 경로 (우상단 45도 직각이등변삼각형)
        // 직각: 우상단 코너
        // 직각변1: 상단 테두리를 따라 좌측으로 triangleSize만큼
        // 직각변2: 우측 테두리를 따라 아래로 triangleSize만큼
        // 빗변: 45도 대각선 (\)
        let size = BadgeConstants.triangleSize
        let trianglePath = UIBezierPath()
        trianglePath.move(to: CGPoint(x: bounds.width - size, y: 0))   // 상단 좌측 꼭짓점
        trianglePath.addLine(to: CGPoint(x: bounds.width, y: 0))       // 우상단 코너 (직각)
        trianglePath.addLine(to: CGPoint(x: bounds.width, y: size))    // 우측 하단 꼭짓점
        trianglePath.close()                                            // 빗변 (45도)

        triangleLayer.path = trianglePath.cgPath
        triangleLayer.frame = bounds
    }

    /// 내부 그림자 경로 업데이트
    /// - 셀에서 삼각형을 뺀 오각형 영역의 가장자리에서 안쪽으로 그림자
    /// - 테두리 4변 + 삼각형 빗변 모두 inner shadow 적용
    private func updateInnerShadow() {
        let size = BadgeConstants.triangleSize

        // 오각형 경로 (셀 사각형 - 우상단 삼각형)
        // 테두리 4변 + 빗변이 그림자의 경계가 됨
        let pentagonPath = UIBezierPath()
        pentagonPath.move(to: CGPoint(x: 0, y: 0))
        pentagonPath.addLine(to: CGPoint(x: bounds.width - size, y: 0))
        pentagonPath.addLine(to: CGPoint(x: bounds.width, y: size))
        pentagonPath.addLine(to: CGPoint(x: bounds.width, y: bounds.height))
        pentagonPath.addLine(to: CGPoint(x: 0, y: bounds.height))
        pentagonPath.close()

        // even-odd inner shadow: 큰 외부 사각형에서 오각형을 빼냄
        let outerPath = UIBezierPath(rect: bounds.insetBy(dx: -30, dy: -30))
        outerPath.append(pentagonPath)
        outerPath.usesEvenOddFillRule = true

        innerShadowShape.path = outerPath.cgPath
        innerShadowShape.frame = bounds

        // 클리핑 마스크: 오각형 내부에서만 그림자 보임
        innerShadowMask.path = pentagonPath.cgPath
        innerShadowMask.frame = bounds

        innerShadowContainer.frame = bounds
    }

    /// 등호 아이콘 위치 업데이트
    /// - 삼각형 무게중심 부근에 배치
    /// - 무게중심: 직각(우상단)에서 각 변의 1/3 지점
    private func updateIconPosition() {
        let size = BadgeConstants.triangleSize
        // 삼각형 꼭짓점: (w-size, 0), (w, 0), (w, size)
        // 무게중심: (w - size/3, size/3)
        let centerX = bounds.width - size / 3
        let centerY = size / 3

        let labelSize = iconLabel.intrinsicContentSize
        iconLabel.frame = CGRect(
            x: centerX - labelSize.width / 2,
            y: centerY - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }

    /// 스윕 그라데이션 마스크 업데이트
    /// - 테두리(stroke) + 삼각형(fill) 합친 영역에서만 스윕이 보임
    private func updateSweepMask() {
        sweepGradient.frame = bounds

        let inset = BadgeConstants.borderWidth / 2
        let size = BadgeConstants.triangleSize

        // 마스크 컨테이너: 테두리 + 삼각형 합친 영역
        let maskContainer = CALayer()
        maskContainer.frame = bounds

        // 테두리 마스크 (사각형 stroke)
        let borderMask = CAShapeLayer()
        borderMask.path = UIBezierPath(rect: bounds.insetBy(dx: inset, dy: inset)).cgPath
        borderMask.fillColor = nil
        borderMask.strokeColor = UIColor.white.cgColor
        borderMask.lineWidth = BadgeConstants.borderWidth * 2.5
        borderMask.frame = bounds
        maskContainer.addSublayer(borderMask)

        // 삼각형 마스크 (fill)
        let triangleMask = CAShapeLayer()
        let triPath = UIBezierPath()
        triPath.move(to: CGPoint(x: bounds.width - size, y: 0))
        triPath.addLine(to: CGPoint(x: bounds.width, y: 0))
        triPath.addLine(to: CGPoint(x: bounds.width, y: size))
        triPath.close()
        triangleMask.path = triPath.cgPath
        triangleMask.fillColor = UIColor.white.cgColor
        triangleMask.frame = bounds
        maskContainer.addSublayer(triangleMask)

        sweepGradient.mask = maskContainer
    }

    // MARK: - Public API

    /// 뱃지 표시 (fade-in + 스윕 애니메이션 시작)
    func show() {
        // 이미 보이고 있으면 무시
        guard isHidden || alpha < 1.0 else { return }

        isHidden = false
        UIView.animate(withDuration: BadgeConstants.fadeInDuration) {
            self.alpha = 1.0
        }

        // 스윕 애니메이션 시작
        startSweepAnimation()
    }

    /// 뱃지 숨김 + 애니메이션 중지
    func stopAndHide() {
        alpha = 0
        isHidden = true
        stopSweepAnimation()
    }

    // MARK: - Sweep Animation

    /// 대각선 스윕 애니메이션 시작
    /// - 빛 밴드가 좌하→우상 방향으로 테두리+삼각형 위를 스윽 지나감
    /// - 모션 감소 설정 시 애니메이션 없이 정적 표시
    private func startSweepAnimation() {
        guard !isSweepAnimating else { return }

        // 모션 감소 설정 시 정적 표시
        if UIAccessibility.isReduceMotionEnabled { return }

        isSweepAnimating = true

        // locations 애니메이션: 셀 밖(좌하) → 셀 밖(우상)
        let locAnim = CABasicAnimation(keyPath: "locations")
        locAnim.fromValue = [-0.5, -0.4, -0.3, -0.2, -0.1]
        locAnim.toValue = [1.1, 1.2, 1.3, 1.4, 1.5]
        locAnim.duration = BadgeConstants.sweepDuration
        locAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 대기 포함 반복
        let group = CAAnimationGroup()
        group.animations = [locAnim]
        group.duration = BadgeConstants.sweepCycleDuration
        group.repeatCount = .infinity
        sweepGradient.add(group, forKey: "diagonalSweep")
    }

    /// 대각선 스윕 애니메이션 중지
    private func stopSweepAnimation() {
        isSweepAnimating = false
        sweepGradient.removeAnimation(forKey: "diagonalSweep")
        // 초기 위치로 리셋 (셀 밖)
        sweepGradient.locations = [-0.5, -0.4, -0.3, -0.2, -0.1]
    }
}

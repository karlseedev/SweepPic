//
//  SimilarGroupBadgeView.swift
//  PickPhoto
//
//  유사사진 그룹 표시용 코너 삼각형 뱃지
//  - 셀 전체에 흰색 테두리 표시
//  - 우측 상단에 45도 직각이등변삼각형 (흰색 채움)
//  - 삼각형 안에 "=" 아이콘 표시
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
        /// fade-in 시간 (초)
        static let fadeInDuration: TimeInterval = 0.3
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

        // 테두리 레이어 추가
        layer.addSublayer(borderLayer)

        // 삼각형 레이어 추가
        layer.addSublayer(triangleLayer)

        // 등호 아이콘 추가
        addSubview(iconLabel)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updatePaths()
        updateIconPosition()
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

    // MARK: - Public API

    /// 뱃지 표시 (fade-in)
    func show() {
        // 이미 보이고 있으면 무시
        guard isHidden || alpha < 1.0 else { return }

        isHidden = false
        UIView.animate(withDuration: BadgeConstants.fadeInDuration) {
            self.alpha = 1.0
        }
    }

    /// 뱃지 숨김
    func stopAndHide() {
        alpha = 0
        isHidden = true
    }
}

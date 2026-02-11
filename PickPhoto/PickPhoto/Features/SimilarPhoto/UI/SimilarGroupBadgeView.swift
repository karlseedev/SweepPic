//
//  SimilarGroupBadgeView.swift
//  PickPhoto
//
//  유사사진 그룹 표시용 Glass+Gradient 뱃지
//  - UIVisualEffectView 기반 블러 뱃지
//  - 배경색이 보라→핑크→파랑→오렌지로 순환
//  - 모션 감소 설정 시 정적 보라색 배경
//  - 풀링 재사용 지원 (show/stopAndHide 사이클)
//

import UIKit

// MARK: - SimilarGroupBadgeView

/// 유사사진 그룹을 표시하는 Glass+Gradient 뱃지 뷰
/// - 우측 상단에 배치되어 그룹 멤버 수를 표시
/// - 블러 배경색이 4색으로 순환 애니메이션
final class SimilarGroupBadgeView: UIView {

    // MARK: - Constants

    /// 뱃지 관련 상수
    enum BadgeConstants {
        /// 뱃지 너비
        static let width: CGFloat = 36
        /// 뱃지 높이
        static let height: CGFloat = 22
        /// 셀 모서리에서의 마진
        static let margin: CGFloat = 4
        /// 모서리 둥글기
        static let cornerRadius: CGFloat = 6
        /// 색상 순환 주기 (초) — 색상 하나당 전환 시간
        static let colorCycleDuration: TimeInterval = 0.75
        /// fade-in 시간 (초)
        static let fadeInDuration: TimeInterval = 0.3
    }

    /// 순환할 색상 (빨→주→노→초→파→남→보 → 빨 반복)
    private let cycleColors: [UIColor] = [
        UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 0.4),  // 빨
        UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.4),  // 주
        UIColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 0.4),  // 노
        UIColor(red: 0.2, green: 0.8, blue: 0.3, alpha: 0.4),  // 초
        UIColor(red: 0.2, green: 0.5, blue: 1.0, alpha: 0.4),  // 파
        UIColor(red: 0.1, green: 0.2, blue: 0.7, alpha: 0.4),  // 남
        UIColor(red: 0.6, green: 0.2, blue: 0.9, alpha: 0.4),  // 보
    ]

    // MARK: - Subviews

    /// 블러 이펙트 뷰
    private let blurView: UIVisualEffectView = {
        let effect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        let view = UIVisualEffectView(effect: effect)
        view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return view
    }()

    /// 숫자 라벨 ("⊞ N")
    private let countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        return label
    }()

    // MARK: - State

    /// 색상 순환 애니메이션 활성화 상태
    /// - stopAndHide()에서 false 설정 → 재귀 completion에서 중단
    private var isAnimating = false

    /// 현재 색상 인덱스 (순환 위치 추적)
    private var currentColorIndex = 0

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 편의 이니셜라이저 (기본 크기)
    convenience init() {
        self.init(frame: CGRect(
            x: 0, y: 0,
            width: BadgeConstants.width,
            height: BadgeConstants.height
        ))
    }

    // MARK: - Setup

    /// 뷰 계층 구성
    private func setupViews() {
        // 자신 설정
        layer.cornerRadius = BadgeConstants.cornerRadius
        clipsToBounds = true
        isHidden = true
        alpha = 0

        // 블러 뷰 추가
        blurView.frame = bounds
        addSubview(blurView)

        // 초기 배경색 설정 (보라)
        blurView.contentView.backgroundColor = cycleColors[0]

        // 라벨 추가
        countLabel.frame = blurView.contentView.bounds
        blurView.contentView.addSubview(countLabel)
    }

    // MARK: - Public API

    /// 뱃지 표시 + 색상 순환 시작
    /// - Parameter count: 그룹 멤버 수
    func show(count: Int) {
        // 라벨 텍스트 설정
        countLabel.text = "⊞\u{2009}\(count)"

        // 이미 보이고 있으면 애니메이션만 유지
        guard isHidden || alpha < 1.0 else { return }

        // 표시
        isHidden = false

        // fade-in
        UIView.animate(withDuration: BadgeConstants.fadeInDuration) {
            self.alpha = 1.0
        }

        // 색상 순환 시작
        startColorCycle()
    }

    /// 뱃지 숨김 + 애니메이션 중지
    func stopAndHide() {
        // 플래그 먼저 끄기 (재귀 completion에서 중단됨)
        isAnimating = false

        // 즉시 숨김
        alpha = 0
        isHidden = true

        // 진행 중인 UIView 애니메이션 정리
        blurView.contentView.layer.removeAllAnimations()
    }

    /// 라벨 텍스트만 업데이트 (이미 표시 중일 때)
    /// - Parameter count: 그룹 멤버 수
    func updateCount(_ count: Int) {
        countLabel.text = "⊞\u{2009}\(count)"
    }

    // MARK: - Color Cycle Animation

    /// 색상 순환 시작
    private func startColorCycle() {
        // 이미 애니메이션 중이면 무시
        guard !isAnimating else { return }

        // 모션 감소 설정 시 정적 배경
        if UIAccessibility.isReduceMotionEnabled {
            blurView.contentView.backgroundColor = cycleColors[0]
            return
        }

        isAnimating = true
        loopBackgroundColor(index: currentColorIndex)
    }

    /// 배경색 순환 (재귀 애니메이션)
    /// - Parameter index: 현재 색상 인덱스
    private func loopBackgroundColor(index: Int) {
        // 플래그 체크 — stopAndHide() 호출 시 재귀 중단
        guard isAnimating else { return }

        let next = (index + 1) % cycleColors.count
        currentColorIndex = next

        UIView.animate(
            withDuration: BadgeConstants.colorCycleDuration,
            delay: 0,
            options: .curveLinear
        ) {
            self.blurView.contentView.backgroundColor = self.cycleColors[next]
        } completion: { [weak self] _ in
            // weak self + isAnimating 이중 안전장치
            self?.loopBackgroundColor(index: next)
        }
    }
}

//
//  TrashAlbumViewController+Gate.swift
//  PickPhoto
//
//  삭제대기함 게이트 관련 Extension
//  - UsageGaugeView 설정/업데이트
//  - Grace Period 배너 placeholder (US3에서 구현)
//  - 게이트 호출 헬퍼
//
//  기존 TrashAlbumVC 919줄 방지를 위한 Extension 분리
//

import UIKit
import AppCore
import OSLog

// MARK: - Gate Extension

extension TrashAlbumViewController {

    // MARK: - Gauge Setup

    /// 게이지 뷰 설정 (viewDidLoad에서 호출)
    /// Plus 시 미표시
    func setupGaugeView() {
        // Plus 구독자는 게이지 미표시 (T032)
        if SubscriptionStore.shared.isPlusUser { return }

        // 게이트 비활성 시 미표시
        guard FeatureFlags.isGateEnabled else { return }

        let gauge = UsageGaugeView()
        gauge.tag = ViewTag.gaugeView
        view.addSubview(gauge)

        // iOS 버전별 상단 위치 결정
        // - iOS 26+: safeAreaLayoutGuide.topAnchor (시스템 네비게이션 바 아래)
        // - iOS 16~25: view.topAnchor + FloatingOverlay 타이틀바 높이
        if #available(iOS 26.0, *) {
            NSLayoutConstraint.activate([
                gauge.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
                gauge.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                gauge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
        } else {
            let topOffset: CGFloat
            if let tabBar = tabBarController as? TabBarController,
               let heights = tabBar.getOverlayHeights() {
                topOffset = heights.top
            } else {
                topOffset = 8
            }
            NSLayoutConstraint.activate([
                gauge.topAnchor.constraint(equalTo: view.topAnchor, constant: topOffset),
                gauge.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                gauge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
        }

        // 탭 → 상세 팝업
        gauge.onTap = { [weak self] in
            self?.showGaugeDetail()
        }

        // 초기 업데이트
        updateGaugeView()

        // UsageLimitStore 변경 감지
        UsageLimitStore.shared.onUpdate = { [weak self] in
            self?.updateGaugeView()
        }

        // 첫 표시 시 1회 툴팁
        showGaugeFirstTooltipIfNeeded(for: gauge)
    }

    /// 게이지 뷰 업데이트
    func updateGaugeView() {
        guard let gauge = view.viewWithTag(ViewTag.gaugeView) as? UsageGaugeView else { return }
        let remaining = UsageLimitStore.shared.remainingFreeDeletes
        let total = UsageLimitStore.shared.totalDailyCapacity
        gauge.update(remaining: remaining, total: total)
    }

    /// 게이지 상세 팝업 표시
    private func showGaugeDetail() {
        let detail = UsageGaugeDetailPopup()
        detail.onWatchAd = { [weak self] in
            guard let self = self else { return }
            // 광고 시청 → 리워드 기록 → 게이지 자동 갱신 (onUpdate 콜백)
            AdManager.shared.showRewardedAd(from: self) { outcome in
                if case .earned = outcome {
                    UsageLimitStore.shared.recordReward()
                    // [BM] T057: 리워드 광고 시청 완료 이벤트 (FR-056)
                    AnalyticsService.shared.trackAdWatched(type: .rewarded, source: "gauge")
                    ReviewService.shared.isAdJustShown = true
                    Logger.app.debug("TrashAlbumVC+Gate: 게이지 상세에서 광고 시청 완료")
                }
            }
        }
        detail.onPlusUpgrade = { [weak self] in
            guard let self = self else { return }
            let paywall = PaywallViewController()
            paywall.analyticsSource = .gauge
            self.present(paywall, animated: true)
        }
        present(detail, animated: true)
    }

    // MARK: - Grace Period Banner (T025)

    /// Grace Period 배너 설정 (게이지 대신 표시)
    func setupGracePeriodBanner() {
        // 기존 배너가 있으면 제거
        if let existing = view.viewWithTag(ViewTag.graceBanner) {
            existing.removeFromSuperview()
        }

        let banner = GracePeriodBannerView()
        banner.tag = ViewTag.graceBanner
        banner.configure()
        view.addSubview(banner)

        // iOS 버전별 상단 위치 결정 (게이지와 동일 위치)
        if #available(iOS 26.0, *) {
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 18),
                banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
        } else {
            let topOffset: CGFloat
            if let tabBar = tabBarController as? TabBarController,
               let heights = tabBar.getOverlayHeights() {
                topOffset = heights.top
            } else {
                topOffset = 8
            }
            NSLayoutConstraint.activate([
                banner.topAnchor.constraint(equalTo: view.topAnchor, constant: topOffset),
                banner.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                banner.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16)
            ])
        }

        // 배너 탭 → 체험 종료 후 안내 팝업
        banner.onTap = { [weak self] in
            guard let self else { return }
            let popup = GracePeriodDetailPopup()
            self.present(popup, animated: true)
        }

        // 배너 높이만큼 컬렉션뷰 상단 inset 갱신
        view.layoutIfNeeded()
        updateContentInset()
    }

    // MARK: - Day 4 Transition (T026)

    /// Day 4 전환: Grace Period → Apple Free Trial 전환으로 비활성화
    /// Grace Period 배너가 더 이상 표시되지 않으므로 전환 로직 불필요
    func checkGracePeriodTransition() {
        // [BM] Grace Period → Apple Free Trial 전환으로 비활성화
        // 기존: 배너 → 게이지 전환 로직
    }

    /// 게이지 첫 표시 시 1회 툴팁 표시
    /// "오늘의 무료 삭제 한도예요. 탭해서 자세히 볼 수 있어요"
    private func showGaugeFirstTooltipIfNeeded(for gauge: UIView) {
        let key = "GaugeFirstTooltipShown"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        // 약간의 딜레이 후 툴팁 표시 (레이아웃 완료 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.view.viewWithTag(ViewTag.gaugeView) != nil else { return }
            self.showGaugeTooltip()
        }
    }

    /// 게이지 아래에 툴팁 말풍선 표시 (3초 후 자동 소멸)
    private func showGaugeTooltip() {
        let tooltipTag = 9903

        let tooltip = UILabel()
        tooltip.text = "오늘의 무료 삭제 한도예요.\n탭해서 자세히 볼 수 있어요"
        tooltip.font = .systemFont(ofSize: 16, weight: .semibold)
        tooltip.textColor = .red
        tooltip.backgroundColor = .clear
        tooltip.numberOfLines = 2
        tooltip.textAlignment = .center
        tooltip.translatesAutoresizingMaskIntoConstraints = false

        // 말풍선 뷰 (삼각형+사각형 하나의 path로 테두리)
        let arrowHeight: CGFloat = 10
        let cornerRadius: CGFloat = 10
        let borderWidth: CGFloat = 1

        let bubbleView = TooltipBubbleView(
            arrowHeight: arrowHeight,
            cornerRadius: cornerRadius,
            borderWidth: borderWidth,
            fillColor: .white,
            strokeColor: .black
        )
        bubbleView.tag = tooltipTag
        bubbleView.translatesAutoresizingMaskIntoConstraints = false
        bubbleView.alpha = 0

        bubbleView.addSubview(tooltip)
        view.addSubview(bubbleView)

        guard let gauge = view.viewWithTag(ViewTag.gaugeView) else { return }

        NSLayoutConstraint.activate([
            // 라벨 패딩 (arrowHeight 만큼 상단 여백 추가)
            tooltip.topAnchor.constraint(equalTo: bubbleView.topAnchor, constant: arrowHeight + 14),
            tooltip.leadingAnchor.constraint(equalTo: bubbleView.leadingAnchor, constant: 20),
            tooltip.trailingAnchor.constraint(equalTo: bubbleView.trailingAnchor, constant: -20),
            tooltip.bottomAnchor.constraint(equalTo: bubbleView.bottomAnchor, constant: -14),

            // 게이지 아래 위치
            bubbleView.topAnchor.constraint(equalTo: gauge.bottomAnchor, constant: 4),
            bubbleView.centerXAnchor.constraint(equalTo: gauge.centerXAnchor),
            bubbleView.widthAnchor.constraint(lessThanOrEqualTo: gauge.widthAnchor)
        ])

        // 페이드 인
        UIView.animate(withDuration: 0.3) {
            bubbleView.alpha = 1
        }

        // 3초 후 페이드 아웃 + 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.3, animations: {
                bubbleView.alpha = 0
            }, completion: { _ in
                bubbleView.removeFromSuperview()
            })
        }
    }

    // MARK: - Subscription State Observer

    /// 구독 상태 변경 시 게이지/배너 갱신 (Plus 전환 시 게이지 제거)
    /// setupGaugeView() 이후 호출
    func observeSubscriptionStateForGauge() {
        SubscriptionStore.shared.onStateChange { [weak self] _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                // 기존 게이지/배너 모두 제거 후 재평가
                self.view.viewWithTag(ViewTag.gaugeView)?.removeFromSuperview()
                self.view.viewWithTag(ViewTag.graceBanner)?.removeFromSuperview()
                self.setupGaugeView()
                self.view.layoutIfNeeded()
                self.updateContentInset()
            }
        }
    }

    // MARK: - Gate Helper

    /// 게이트 평가 후 삭제 실행 헬퍼
    /// - Parameters:
    ///   - trashCount: 삭제 대상 수
    ///   - onApproved: 게이트 통과 시 실행할 삭제 로직
    func evaluateGateAndExecute(trashCount: Int, onApproved: @escaping () -> Void) {
        TrashGateCoordinator.shared.evaluateAndPresent(
            from: self,
            trashCount: trashCount,
            onApproved: onApproved
        )
    }

    // MARK: - Celebration (FR-039, T046)

    /// 삭제 성공 후 통계 저장 + 축하 화면 표시
    /// - Parameters:
    ///   - deletedCount: 이번에 삭제한 장수
    ///   - freedBytes: 이번에 확보한 용량 (bytes)
    func showCelebrationAfterDeletion(deletedCount: Int, freedBytes: Int64) {
        // 1. 통계 저장 (DeletionStatsStore)
        let updatedStats = DeletionStatsStore.shared.addStats(
            deletedCount: deletedCount,
            freedBytes: freedBytes
        )

        // 2. CelebrationResult 생성
        let result = CelebrationResult(
            sessionDeletedCount: deletedCount,
            sessionFreedBytes: freedBytes,
            totalDeletedCount: updatedStats.totalDeletedCount,
            totalFreedBytes: updatedStats.totalFreedBytes
        )

        // 3. 축하 화면 표시
        let celebrationVC = CelebrationViewController(result: result)
        present(celebrationVC, animated: true)

        Logger.app.debug("TrashAlbumVC: 축하 화면 표시 — 이번 \(deletedCount)장, 누적 \(updatedStats.totalDeletedCount)장")
    }

    // MARK: - Debug Grace Period Toggle

    #if DEBUG
    /// 디버그: Grace Period 토글 알림 수신 등록 (viewDidLoad에서 호출)
    func observeDebugGracePeriodToggle() {
        NotificationCenter.default.addObserver(
            self, selector: #selector(handleDebugGracePeriodToggle),
            name: .debugGracePeriodToggled, object: nil
        )
    }

    /// 디버그: Grace Period 토글 시 게이지/배너 즉시 전환
    @objc private func handleDebugGracePeriodToggle() {
        // 기존 게이지/배너 모두 제거
        view.viewWithTag(ViewTag.gaugeView)?.removeFromSuperview()
        view.viewWithTag(ViewTag.graceBanner)?.removeFromSuperview()
        setupGaugeView()
        // 게이지/배너 높이 변경에 따른 컬렉션뷰 inset 즉시 갱신
        view.layoutIfNeeded()
        updateContentInset()
    }
    #endif

    // MARK: - View Tags

    /// 게이트 관련 뷰 태그 (충돌 방지)
    private enum ViewTag {
        static let gaugeView = 9901
        static let graceBanner = 9902
    }
}

// MARK: - Debug Notification Name

#if DEBUG
extension Notification.Name {
    static let debugGracePeriodToggled = Notification.Name("debugGracePeriodToggled")
}
#endif

// MARK: - TooltipBubbleView

/// 말풍선 모양 뷰 (위쪽 삼각형 + 둥근 사각형을 하나의 path로 그려 테두리 연결)
private final class TooltipBubbleView: UIView {

    private let arrowHeight: CGFloat
    private let cornerRadius: CGFloat
    private let borderWidth: CGFloat
    private let fillColor: UIColor
    private let strokeColor: UIColor

    private let shapeLayer = CAShapeLayer()
    private let borderLayer = CAShapeLayer()

    init(arrowHeight: CGFloat, cornerRadius: CGFloat, borderWidth: CGFloat,
         fillColor: UIColor, strokeColor: UIColor) {
        self.arrowHeight = arrowHeight
        self.cornerRadius = cornerRadius
        self.borderWidth = borderWidth
        self.fillColor = fillColor
        self.strokeColor = strokeColor
        super.init(frame: .zero)
        backgroundColor = .clear
        // 그림자
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.5
        layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowRadius = 12
        layer.addSublayer(shapeLayer)
        layer.addSublayer(borderLayer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let path = makeBubblePath()
        shapeLayer.path = path.cgPath
        shapeLayer.fillColor = fillColor.cgColor

        borderLayer.path = path.cgPath
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.clear.cgColor
        borderLayer.lineWidth = 0

        // 그림자 path
        layer.shadowPath = path.cgPath
    }

    /// 삼각형 + 둥근 사각형 합친 path
    private func makeBubblePath() -> UIBezierPath {
        let w = bounds.width
        let h = bounds.height
        let ah = arrowHeight
        let aw: CGFloat = 16 // 화살표 너비
        let r = cornerRadius

        let path = UIBezierPath()

        // 화살표 꼭짓점 (상단 중앙)
        let arrowTip = CGPoint(x: w / 2, y: 0)
        let arrowLeft = CGPoint(x: w / 2 - aw / 2, y: ah)
        let arrowRight = CGPoint(x: w / 2 + aw / 2, y: ah)

        // 시작: 화살표 꼭짓점
        path.move(to: arrowTip)
        // 화살표 오른쪽 → 사각형 상단 우측
        path.addLine(to: arrowRight)
        path.addLine(to: CGPoint(x: w - r, y: ah))
        // 우상단 코너
        path.addArc(withCenter: CGPoint(x: w - r, y: ah + r), radius: r,
                     startAngle: -.pi / 2, endAngle: 0, clockwise: true)
        // 우측 변
        path.addLine(to: CGPoint(x: w, y: h - r))
        // 우하단 코너
        path.addArc(withCenter: CGPoint(x: w - r, y: h - r), radius: r,
                     startAngle: 0, endAngle: .pi / 2, clockwise: true)
        // 하단 변
        path.addLine(to: CGPoint(x: r, y: h))
        // 좌하단 코너
        path.addArc(withCenter: CGPoint(x: r, y: h - r), radius: r,
                     startAngle: .pi / 2, endAngle: .pi, clockwise: true)
        // 좌측 변
        path.addLine(to: CGPoint(x: 0, y: ah + r))
        // 좌상단 코너
        path.addArc(withCenter: CGPoint(x: r, y: ah + r), radius: r,
                     startAngle: .pi, endAngle: -.pi / 2, clockwise: true)
        // 사각형 상단 좌측 → 화살표 왼쪽
        path.addLine(to: arrowLeft)
        path.close()

        return path
    }
}

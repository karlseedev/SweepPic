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
    /// Plus/Grace Period 시 미표시
    func setupGaugeView() {
        // Plus 구독자는 게이지 미표시 (Phase 6 T032에서 활성화)
        // if SubscriptionStore.shared.isPlusUser { return }

        // Grace Period 중이면 게이지 대신 배너 표시 (US3 T025)
        if GracePeriodService.shared.isActive {
            Logger.app.debug("TrashAlbumVC+Gate: Grace Period 중 — 배너 표시")
            setupGracePeriodBanner()
            return
        }

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
                    Logger.app.debug("TrashAlbumVC+Gate: 게이지 상세에서 광고 시청 완료")
                }
            }
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

        // 배너 탭 → 페이월 (FR-025, 페이월은 US4에서 구현)
        banner.onTapPaywall = { [weak self] in
            Logger.app.debug("TrashAlbumVC+Gate: Grace Period 배너 탭 → 페이월 (US4에서 구현)")
            // Phase 6 T031에서 PaywallViewController present
            _ = self
        }

        // 배너 높이만큼 컬렉션뷰 상단 inset 갱신
        view.layoutIfNeeded()
        updateContentInset()
    }

    // MARK: - Day 4 Transition (T026)

    /// Day 4 전환: Grace Period 만료 시 배너 → 게이지 전환 + 1회 툴팁
    /// viewWillAppear 또는 foreground 진입 시 호출
    func checkGracePeriodTransition() {
        let wasShowingBanner = view.viewWithTag(ViewTag.graceBanner) != nil
        let isGraceActive = GracePeriodService.shared.isActive

        // Grace Period 만료 + 배너가 있었으면 → 전환
        if !isGraceActive && wasShowingBanner {
            Logger.app.debug("TrashAlbumVC+Gate: Day 4 전환 — 배너 → 게이지")
            // 배너 제거
            view.viewWithTag(ViewTag.graceBanner)?.removeFromSuperview()

            // 게이지 설정 (게이트 활성 시)
            if FeatureFlags.isGateEnabled {
                let gauge = UsageGaugeView()
                gauge.tag = ViewTag.gaugeView
                view.addSubview(gauge)

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

                gauge.onTap = { [weak self] in
                    self?.showGaugeDetail()
                }

                updateGaugeView()

                UsageLimitStore.shared.onUpdate = { [weak self] in
                    self?.updateGaugeView()
                }

                // 첫 표시 시 1회 툴팁 (Edge Case: 카운터 게이지 첫 표시)
                showGaugeFirstTooltipIfNeeded(for: gauge)
            }

            // 배너 → 게이지 높이 변경에 따른 inset 갱신
            view.layoutIfNeeded()
            updateContentInset()
        }
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
        tooltip.tag = tooltipTag
        tooltip.text = "오늘의 무료 삭제 한도예요.\n탭해서 자세히 볼 수 있어요"
        tooltip.font = .systemFont(ofSize: 12, weight: .medium)
        tooltip.textColor = .white
        tooltip.backgroundColor = UIColor.darkGray
        tooltip.numberOfLines = 2
        tooltip.textAlignment = .center
        tooltip.layer.cornerRadius = 8
        tooltip.layer.masksToBounds = true
        tooltip.translatesAutoresizingMaskIntoConstraints = false
        tooltip.alpha = 0

        // 패딩을 위한 내부 inset 설정
        tooltip.drawText(in: .zero) // label이라 직접 inset 불가 → 배경뷰로 감싸기

        let container = UIView()
        container.tag = tooltipTag
        container.backgroundColor = UIColor.darkGray
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true
        container.translatesAutoresizingMaskIntoConstraints = false
        container.alpha = 0

        container.addSubview(tooltip)
        view.addSubview(container)

        guard let gauge = view.viewWithTag(ViewTag.gaugeView) else { return }

        NSLayoutConstraint.activate([
            tooltip.topAnchor.constraint(equalTo: container.topAnchor, constant: 8),
            tooltip.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 12),
            tooltip.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -12),
            tooltip.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -8),

            container.topAnchor.constraint(equalTo: gauge.bottomAnchor, constant: 6),
            container.centerXAnchor.constraint(equalTo: gauge.centerXAnchor),
            container.widthAnchor.constraint(lessThanOrEqualTo: gauge.widthAnchor)
        ])

        // 페이드 인
        UIView.animate(withDuration: 0.3) {
            container.alpha = 1
        }

        // 3초 후 페이드 아웃 + 제거
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            UIView.animate(withDuration: 0.3, animations: {
                container.alpha = 0
            }, completion: { _ in
                container.removeFromSuperview()
            })
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

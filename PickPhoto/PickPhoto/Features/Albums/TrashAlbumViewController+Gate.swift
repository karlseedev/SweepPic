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

        // Grace Period 중이면 게이지 대신 배너 표시 (US3 T025에서 구현)
        if GracePeriodService.shared.isActive {
            Logger.app.debug("TrashAlbumVC+Gate: Grace Period 중 — 게이지 미표시")
            return
        }

        // 게이트 비활성 시 미표시
        guard FeatureFlags.isGateEnabled else { return }

        let gauge = UsageGaugeView()
        gauge.tag = ViewTag.gaugeView
        view.addSubview(gauge)

        NSLayoutConstraint.activate([
            gauge.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            gauge.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            gauge.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -60)
        ])

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
            AdManager.shared.showRewardedAd(from: self) { success in
                if success {
                    UsageLimitStore.shared.recordReward()
                    Logger.app.debug("TrashAlbumVC+Gate: 게이지 상세에서 광고 시청 완료")
                }
            }
        }
        present(detail, animated: true)
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

    // MARK: - View Tags

    /// 게이트 관련 뷰 태그 (충돌 방지)
    private enum ViewTag {
        static let gaugeView = 9901
        static let graceBanner = 9902
    }
}

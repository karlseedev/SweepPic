//
//  TrashGateCoordinator.swift
//  PickPhoto
//
//  게이트 판단 중앙 제어 싱글톤
//  모든 영구 삭제(emptyTrash, permanentlyDelete)가 이 코디네이터를 거침
//  TrashGateCoordinatorProtocol 준수 (contracts/protocols.md)
//
//  판단 흐름:
//  1. Plus 구독자? → 바로 실행
//  2. Grace Period 중? → 바로 실행
//  3. 삭제 대상 ≤ 남은 한도? → 바로 실행 + recordDelete
//  4. 한도 초과 → 게이트 팝업 표시
//

import UIKit
import AppCore
import OSLog

// MARK: - TrashGateCoordinatorProtocol

/// 게이트 판단 프로토콜 (contracts/protocols.md)
protocol TrashGateCoordinatorProtocol {
    /// 게이트 평가 후 팝업 표시 또는 바로 실행
    /// - Parameters:
    ///   - viewController: 팝업을 표시할 VC
    ///   - trashCount: 삭제 대상 수
    ///   - onApproved: 게이트 통과 시 실행할 삭제 로직
    func evaluateAndPresent(
        from viewController: UIViewController,
        trashCount: Int,
        onApproved: @escaping () -> Void
    )
}

// MARK: - TrashGateCoordinator

/// 게이트 판단 중앙 제어 싱글톤
/// 모든 영구 삭제가 이 코디네이터의 evaluateAndPresent를 거침
final class TrashGateCoordinator: TrashGateCoordinatorProtocol {

    // MARK: - Singleton

    static let shared = TrashGateCoordinator()
    private init() {}

    // MARK: - Properties

    /// 금지 타이밍 플래그 (리뷰 요청 판단용)
    /// 게이트 팝업 표시 직후에는 리뷰 요청을 하지 않음
    var isGateJustShown = false

    // MARK: - Gate Evaluation

    /// 게이트 평가 후 팝업 표시 또는 바로 실행
    /// - Parameters:
    ///   - viewController: 팝업을 표시할 VC
    ///   - trashCount: 삭제 대상 수 (전체 비우기 시 trashedCount, 선택 삭제 시 선택 수)
    ///   - onApproved: 게이트 통과 시 실행할 삭제 콜백
    func evaluateAndPresent(
        from viewController: UIViewController,
        trashCount: Int,
        onApproved: @escaping () -> Void
    ) {
        // FeatureFlags 체크 — 게이트 비활성 시 바로 실행
        guard FeatureFlags.isGateEnabled else {
            Logger.app.debug("TrashGateCoordinator: 게이트 비활성 — 바로 실행")
            onApproved()
            return
        }

        // 0장이면 게이트 평가 불필요
        guard trashCount > 0 else {
            onApproved()
            return
        }

        // 1. Plus 구독자 체크 (Phase 6 T032에서 구독 연동 후 활성화)
        // if SubscriptionStore.shared.isPlusUser {
        //     onApproved()
        //     return
        // }

        // 2. Grace Period 중 → 바로 실행 (게이트 없이)
        if GracePeriodService.shared.isActive {
            Logger.app.debug("TrashGateCoordinator: Grace Period 중 — 바로 실행")
            onApproved()
            return
        }

        // 3. 남은 기본 한도 내 → 바로 실행
        // ⚠️ recordDelete는 여기서 하지 않음 — iOS 시스템 팝업에서 취소 가능하므로
        //    실제 삭제 성공 후 각 호출부에서 recordDelete 호출
        let remaining = UsageLimitStore.shared.remainingFreeDeletes
        if trashCount <= remaining {
            Logger.app.debug("TrashGateCoordinator: 한도 내 (\(trashCount)/\(remaining)) — 바로 실행")
            onApproved()
            return
        }

        // 4. 한도 초과 → 게이트 팝업 표시
        Logger.app.debug("TrashGateCoordinator: 한도 초과 (\(trashCount) > \(remaining)) — 게이트 팝업")
        isGateJustShown = true

        // 필요한 광고 수 계산
        let adsNeeded = UsageLimitStore.shared.adsNeeded(for: trashCount)

        let popup = TrashGatePopupViewController(
            trashCount: trashCount,
            remainingFreeDeletes: remaining,
            adsNeeded: adsNeeded,
            remainingRewards: UsageLimitStore.shared.remainingRewards
        )

        // 게이트 팝업 결과 핸들링
        popup.onAdWatch = { [weak self] in
            // 광고 시청 → 리워드 기록 → 삭제 실행
            self?.handleAdWatchFlow(from: viewController, trashCount: trashCount, adsNeeded: adsNeeded, onApproved: onApproved)
        }

        popup.onPlusUpgrade = { [weak viewController] in
            // Plus 업그레이드 → 페이월 표시 (Phase 6 T031에서 구현)
            Logger.app.debug("TrashGateCoordinator: Plus 업그레이드 선택")
            _ = viewController // 향후 사용
        }

        popup.onDismiss = {
            Logger.app.debug("TrashGateCoordinator: 게이트 팝업 닫기")
        }

        // present — modalPresentationStyle은 init에서 설정됨
        viewController.present(popup, animated: true)
    }

    // MARK: - Ad Watch Flow

    /// 광고 시청 → 리워드 기록 → 삭제 실행 흐름
    /// 여러 번 광고를 봐야 하는 경우 재귀적으로 처리
    private func handleAdWatchFlow(
        from viewController: UIViewController,
        trashCount: Int,
        adsNeeded: Int,
        onApproved: @escaping () -> Void,
        watchedCount: Int = 0
    ) {
        // 모든 필요 광고를 시청했으면 삭제 실행
        // ⚠️ recordDelete는 여기서 하지 않음 — 각 호출부에서 삭제 성공 후 기록
        if watchedCount >= adsNeeded {
            onApproved()
            return
        }

        // 리워드 광고 표시
        AdManager.shared.showRewardedAd(from: viewController) { [weak self] success in
            if success {
                // 시청 완료 → 리워드 기록
                UsageLimitStore.shared.recordReward()
                Logger.app.debug("TrashGateCoordinator: 광고 시청 완료 (\(watchedCount + 1)/\(adsNeeded))")

                // 다음 광고 필요 여부 확인
                self?.handleAdWatchFlow(
                    from: viewController,
                    trashCount: trashCount,
                    adsNeeded: adsNeeded,
                    onApproved: onApproved,
                    watchedCount: watchedCount + 1
                )
            } else {
                // 광고 시청 실패/취소 → 리워드 미차감
                Logger.app.debug("TrashGateCoordinator: 광고 시청 실패/취소")
            }
        }
    }
}

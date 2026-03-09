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

        // 1. Plus 구독자 → 게이트 즉시 스킵 (T032)
        if SubscriptionStore.shared.isPlusUser {
            Logger.app.debug("TrashGateCoordinator: Plus 구독자 — 바로 실행")
            onApproved()
            return
        }

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
        // [BM] T055: 리뷰 금지 타이밍 플래그 설정 (FR-050)
        ReviewService.shared.isGateJustShown = true

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
            // Plus 업그레이드 → 페이월 표시 (T032)
            Logger.app.debug("TrashGateCoordinator: Plus 업그레이드 선택 → 페이월")
            guard let vc = viewController else { return }
            let paywall = PaywallViewController()
            paywall.modalPresentationStyle = .pageSheet
            vc.present(paywall, animated: true)
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
    ///
    /// RewardedAdOutcome 기반 분기:
    /// - .earned → 리워드 기록 + 다음 광고 또는 삭제
    /// - .dismissedWithoutReward → 사용자가 자발적 취소, 조용히 종료
    /// - .notLoaded / .presentFailed → no-fill 처리 (생애 최초 무료 또는 재시도 팝업)
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

        // RewardedAdPresenter를 통해 리워드 광고 표시
        // ⚠️ viewController weak 캡쳐 — dismiss 중 해제 방어
        RewardedAdPresenter.shared.showAd(from: viewController) { [weak self, weak viewController] outcome in
            guard let self = self, let viewController = viewController else { return }

            switch outcome {
            case .earned:
                // 시청 완료 → 리워드 기록 (FR-013: dismiss 후에만 기록)
                UsageLimitStore.shared.recordReward()
                Logger.app.debug("TrashGateCoordinator: 광고 시청 완료 (\(watchedCount + 1)/\(adsNeeded))")

                // 다음 광고 필요 여부 확인
                self.handleAdWatchFlow(
                    from: viewController,
                    trashCount: trashCount,
                    adsNeeded: adsNeeded,
                    onApproved: onApproved,
                    watchedCount: watchedCount + 1
                )

            case .dismissedWithoutReward:
                // 사용자가 자발적으로 광고를 닫음 → 리워드 미차감, 조용히 종료
                Logger.app.debug("TrashGateCoordinator: 사용자 광고 취소 — 흐름 종료")

            case .notLoaded, .presentFailed:
                // 광고 로드 실패 / 표시 실패 → no-fill 처리
                Logger.app.debug("TrashGateCoordinator: 광고 로드/표시 실패 — no-fill 처리")
                self.handleNoFill(
                    from: viewController,
                    trashCount: trashCount,
                    adsNeeded: adsNeeded,
                    onApproved: onApproved,
                    watchedCount: watchedCount
                )
            }
        }
    }

    // MARK: - No-Fill Handling

    /// 광고 로드/표시 실패(no-fill) 처리
    /// - 생애 최초 no-fill → 무료 +10장 (FR-021)
    /// - 이후 → 재시도/취소 팝업
    private func handleNoFill(
        from viewController: UIViewController,
        trashCount: Int,
        adsNeeded: Int,
        onApproved: @escaping () -> Void,
        watchedCount: Int
    ) {
        // 생애 최초 no-fill → 무료 +10장 (FR-021)
        if !UsageLimitStore.shared.lifetimeFreeGrantUsed {
            UsageLimitStore.shared.recordLifetimeFreeGrant()
            UsageLimitStore.shared.recordReward()
            Logger.app.debug("TrashGateCoordinator: 생애 최초 no-fill → 무료 +10장 부여")

            // 무료 보상 후 남은 광고 계속 진행
            handleAdWatchFlow(
                from: viewController,
                trashCount: trashCount,
                adsNeeded: adsNeeded,
                onApproved: onApproved,
                watchedCount: watchedCount + 1
            )
            return
        }

        // 재시도/취소 팝업 표시
        let alert = UIAlertController(
            title: "광고를 불러올 수 없습니다",
            message: "네트워크 상태를 확인하고 다시 시도해주세요.",
            preferredStyle: .alert
        )

        // 재시도 — 같은 광고 다시 시도
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { [weak self, weak viewController] _ in
            guard let self = self, let viewController = viewController else { return }
            self.handleAdWatchFlow(
                from: viewController,
                trashCount: trashCount,
                adsNeeded: adsNeeded,
                onApproved: onApproved,
                watchedCount: watchedCount
            )
        })

        // 취소 — 광고 흐름 중단
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        viewController.present(alert, animated: true)
    }
}

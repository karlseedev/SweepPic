//
//  ReferralRewardClaimManager.swift
//  SweepPic
//
//  보상 수령 로직 매니저 (Phase 5, T030)
//
//  2단계 확인 구조:
//  1. claim-reward → 코드 할당/서명 생성 (status: claimed)
//  2. confirm-claim → 실제 적용 확인 후 completed
//
//  경로별 동작:
//  - Promotional: claim → 서명 → StoreKit 구매 성공 → confirm-claim → .success
//  - Offer Code: claim → URL 열기 → App Store → 복귀 → Transaction 스캔 → confirm-claim → .success
//  - 취소 시: 보상 화면 복귀, 숫자 유지 (서버는 claimed 상태, 재시도 가능)
//
//  참조: specs/004-referral-reward/spec.md §User Story 3
//

import UIKit
import AppCore
import StoreKit
import OSLog

// MARK: - ClaimState

/// 보상 수령 진행 상태
enum ClaimState {
    /// 대기 중 (아직 수령 시작 안 함)
    case idle
    /// 서버 통신 중 (서명/코드 요청)
    case loading
    /// 수령 성공 (confirm-claim 완료)
    case success
    /// App Store로 전환됨 — 포그라운드 복귀 시 Transaction 스캔 (Offer Code 경로)
    case waitingForReturn(rewardId: String)
    /// 실패 (재시도 가능)
    case failed(message: String)
}

// MARK: - ReferralRewardClaimManager

/// 보상 수령 로직 매니저
/// claim-reward API → 보상 방식 분기 → 적용 → confirm-claim
final class ReferralRewardClaimManager {

    // MARK: - Properties

    /// 현재 수령 상태
    private(set) var state: ClaimState = .idle

    /// 상태 변경 콜백
    var onStateChange: ((ClaimState) -> Void)?

    // MARK: - Public API

    /// 보상을 수령한다
    ///
    /// 1. SubscriptionStore에서 구독 상태 확인
    /// 2. claim-reward API 호출 (서버: claimed 중간 상태)
    /// 3. 응답에 따라 Promotional Offer 또는 Offer Code 적용
    /// 4. 적용 확인 후 confirm-claim API 호출 (completed)
    ///
    /// - Parameter rewardId: pending_rewards 테이블 ID
    func claimReward(rewardId: String) async {
        // 로딩 시작
        await updateState(.loading)

        let userId = ReferralStore.shared.userId
        let subscriptionStatus = await SubscriptionStore.shared.referralSubscriptionStatus()
        let productId = await SubscriptionStore.shared.referralProductId()

        do {
            // 1. claim-reward API 호출 (서버: pending → claimed)
            let response = try await ReferralService.shared.claimReward(
                userId: userId,
                rewardId: rewardId,
                subscriptionStatus: subscriptionStatus,
                productId: productId
            )

            // 이미 수령 완료
            if response.status == "already_claimed" {
                Logger.referral.debug("ReferralRewardClaimManager: 이미 수령 완료")
                await updateState(.success)
                return
            }

            // 2. 보상 방식 분기
            switch response.rewardType {
            case "promotional":
                // Promotional Offer: 서명으로 StoreKit 2 구매
                guard let signature = response.signature else {
                    await updateState(.failed(message: String(localized: "error.referralReward.missingSignature")))
                    return
                }
                try await applyPromotionalOffer(productId: productId, signature: signature)

                // 구매 성공 → confirm-claim
                await confirmClaim(rewardId: rewardId)

                // 구독 상태 갱신
                await SubscriptionStore.shared.refreshSubscriptionStatus()

            case "offer_code":
                // Offer Code: 리딤 URL 열기 → App Store로 전환
                // confirm은 VC에서 Transaction 스캔 후 호출
                guard let redeemURL = response.redeemURL else {
                    await updateState(.failed(message: String(localized: "error.referralReward.missingRedeemURL")))
                    return
                }
                await applyOfferCode(redeemURL: redeemURL)
                await updateState(.waitingForReturn(rewardId: rewardId))
                return

            default:
                await updateState(.failed(message: String(localized: "error.referralReward.unknownRewardType")))
                return
            }

            // 3. 성공 (Promotional 경로만 여기 도달)
            await updateState(.success)

            Logger.referral.debug(
                "ReferralRewardClaimManager: 보상 수령 성공 — type=\(response.rewardType)"
            )

        } catch let error as ReferralServiceError {
            await updateState(.failed(message: error.errorDescription ?? String(localized: "error.referralReward.serverError")))
            Logger.referral.error(
                "ReferralRewardClaimManager: API 에러 — \(error.localizedDescription)"
            )

        } catch let error as PromotionalOfferService.OfferError {
            let message = localizedMessage(for: error)
            switch error {
            case .userCancelled:
                // 사용자 취소 → idle 복귀 (서버는 claimed, 재시도 가능)
                await updateState(.idle)
            default:
                await updateState(.failed(message: message))
            }
            Logger.referral.error(
                "ReferralRewardClaimManager: Offer 에러 — \(message)"
            )

        } catch {
            await updateState(.failed(
                message: String(localized: "error.referralReward.applyFailed")
            ))
            Logger.referral.error(
                "ReferralRewardClaimManager: 알 수 없는 에러 — \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Public API: confirm-claim

    /// 보상 수령을 확정한다 (Transaction 감지 후 VC에서 호출)
    ///
    /// - Parameters:
    ///   - rewardId: pending_rewards ID
    ///   - transactionId: StoreKit Transaction ID (선택)
    func confirmClaim(rewardId: String, transactionId: UInt64? = nil) async {
        let userId = ReferralStore.shared.userId
        do {
            try await ReferralService.shared.confirmClaim(
                userId: userId,
                rewardId: rewardId,
                transactionId: transactionId
            )
            Logger.referral.debug("ReferralRewardClaimManager: confirm-claim 성공 — \(rewardId)")
        } catch {
            // confirm 실패해도 구독은 이미 적용됨 — 다음 실행 시 재시도
            Logger.referral.error(
                "ReferralRewardClaimManager: confirm-claim 실패 — \(error.localizedDescription)"
            )
        }

        // confirm 성공/실패 관계없이 성공 표시 (구독은 이미 적용됨)
        await updateState(.success)

        // 구독 상태 갱신
        await SubscriptionStore.shared.refreshSubscriptionStatus()
    }

    // MARK: - Private

    /// Promotional Offer 서명으로 StoreKit 2 구매를 실행한다
    private func applyPromotionalOffer(
        productId: String,
        signature: PromotionalOfferSignature
    ) async throws {
        try await PromotionalOfferService.shared.purchaseWithOffer(
            productId: productId,
            signature: signature
        )
    }

    /// Offer Code 리딤 URL을 열어 App Store 시트를 표시한다
    @MainActor
    private func applyOfferCode(redeemURL: URL) {
        OfferRedemptionService.shared.openRedeemURL(redeemURL)
    }

    private func localizedMessage(for error: PromotionalOfferService.OfferError) -> String {
        switch error {
        case .productNotFound(let id):
            return String(localized: "error.offer.productNotFound \(id)")
        case .userCancelled:
            return String(localized: "error.offer.userCanceled")
        case .purchasePending:
            return String(localized: "error.offer.purchasePending")
        case .storeKitError(let error):
            return String(localized: "error.offer.storeKit \(error.localizedDescription)")
        case .verificationFailed:
            return String(localized: "error.offer.verificationFailed")
        }
    }

    /// 메인 스레드에서 상태 업데이트
    @MainActor
    private func updateState(_ newState: ClaimState) {
        state = newState
        onStateChange?(newState)
    }
}

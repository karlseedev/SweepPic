//
//  ReferralRewardClaimManager.swift
//  SweepPic
//
//  보상 수령 로직 매니저 (Phase 5, T030)
//
//  역할:
//  - claimReward API 호출 → RewardClaimResult 분기
//  - .promotional → PromotionalOfferService로 StoreKit 2 구매
//  - .offerCode → OfferRedemptionService로 리딤 URL 열기
//  - .error → 에러 안내
//  - 순차 수령 지원 (1건 완료 후 다음 건 자동 진행)
//
//  참조: specs/004-referral-reward/spec.md §User Story 3
//  참조: specs/004-referral-reward/contracts/api-endpoints.md §claim-reward
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
    /// 수령 성공
    case success
    /// 실패 (재시도 가능)
    case failed(message: String)
}

// MARK: - ReferralRewardClaimManager

/// 보상 수령 로직 매니저
/// claim-reward API → 보상 방식 분기 → 적용
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
    /// 2. claim-reward API 호출
    /// 3. 응답에 따라 Promotional Offer 또는 Offer Code 적용
    ///
    /// - Parameter rewardId: pending_rewards 테이블 ID
    func claimReward(rewardId: String) async {
        // 로딩 시작
        await updateState(.loading)

        let userId = ReferralStore.shared.userId
        let subscriptionStatus = await SubscriptionStore.shared.referralSubscriptionStatus()
        let productId = await SubscriptionStore.shared.referralProductId()

        do {
            // 1. claim-reward API 호출
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
                    await updateState(.failed(message: "서명 정보가 없습니다."))
                    return
                }
                try await applyPromotionalOffer(productId: productId, signature: signature)

            case "offer_code":
                // Offer Code: 리딤 URL 열기
                guard let redeemURL = response.redeemURL else {
                    await updateState(.failed(message: "리딤 URL이 없습니다."))
                    return
                }
                await applyOfferCode(redeemURL: redeemURL)

            default:
                await updateState(.failed(message: "알 수 없는 보상 유형입니다."))
                return
            }

            // 3. 성공
            await updateState(.success)

            // 구독 상태 갱신
            await SubscriptionStore.shared.refreshSubscriptionStatus()

            Logger.referral.debug(
                "ReferralRewardClaimManager: 보상 수령 성공 — type=\(response.rewardType)"
            )

        } catch let error as ReferralServiceError {
            // API 에러
            await updateState(.failed(message: error.errorDescription ?? "서버 오류가 발생했습니다."))
            Logger.referral.error(
                "ReferralRewardClaimManager: API 에러 — \(error.localizedDescription)"
            )

        } catch let error as PromotionalOfferService.OfferError {
            // Promotional Offer 에러
            switch error {
            case .userCancelled:
                // 사용자 취소 → idle로 복귀 (에러 표시 안 함)
                await updateState(.idle)
            default:
                await updateState(.failed(
                    message: "혜택 적용에 실패했습니다. 잠시 후 다시 시도해주세요."
                ))
            }
            Logger.referral.error(
                "ReferralRewardClaimManager: Offer 에러 — \(error.localizedDescription)"
            )

        } catch {
            await updateState(.failed(
                message: "혜택 적용에 실패했습니다. 잠시 후 다시 시도해주세요."
            ))
            Logger.referral.error(
                "ReferralRewardClaimManager: 알 수 없는 에러 — \(error.localizedDescription)"
            )
        }
    }

    // MARK: - Private: Promotional Offer 적용

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

    // MARK: - Private: Offer Code 적용

    /// Offer Code 리딤 URL을 열어 App Store 시트를 표시한다
    @MainActor
    private func applyOfferCode(redeemURL: URL) {
        OfferRedemptionService.shared.openRedeemURL(redeemURL)
    }

    // MARK: - Private: 상태 업데이트

    /// 메인 스레드에서 상태 업데이트
    @MainActor
    private func updateState(_ newState: ClaimState) {
        state = newState
        onStateChange?(newState)
    }
}

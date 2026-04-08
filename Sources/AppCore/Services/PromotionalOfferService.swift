//
//  PromotionalOfferService.swift
//  AppCore
//
//  Promotional Offer 서명 기반 StoreKit 2 구매 서비스 (Phase 5, T026)
//
//  역할:
//  - 서버에서 받은 서명으로 Product.PurchaseOption.promotionalOffer 생성
//  - Product.purchase(options:) 호출
//  - 실패 시 에러 반환 (pending_rewards 상태 유지)
//
//  참조: specs/004-referral-reward/research.md §4 Promotional Offer 서버 서명
//  참조: specs/004-referral-reward/contracts/api-endpoints.md §claim-reward
//

import Foundation
import OSLog

#if canImport(StoreKit)
import StoreKit
#endif

// MARK: - PromotionalOfferService

/// Promotional Offer 서명 기반 StoreKit 2 구매 서비스
/// 서버에서 ES256 서명을 받아 StoreKit 2 구매를 실행한다.
public final class PromotionalOfferService {

    // MARK: - Singleton

    public static let shared = PromotionalOfferService()
    private init() {}

    // MARK: - Errors

    /// Promotional Offer 구매 중 발생할 수 있는 에러
    public enum OfferError: Error {
        /// 해당 상품을 찾을 수 없음
        case productNotFound(String)
        /// 사용자가 구매를 취소함
        case userCancelled
        /// 구매 대기 중 (Ask to Buy)
        case purchasePending
        /// StoreKit 에러
        case storeKitError(Error)
        /// 서명 검증 실패
        case verificationFailed

    }

    // MARK: - Purchase with Promotional Offer

    #if canImport(StoreKit)
    /// 서버 서명을 사용하여 Promotional Offer 구매를 실행한다
    ///
    /// StoreKit 2의 Product.purchase(options:)를 사용하여
    /// 서버에서 생성된 서명으로 프로모션 오퍼를 적용한 구매를 진행한다.
    ///
    /// - Parameters:
    ///   - productId: StoreKit 상품 ID (pro_monthly / pro_yearly)
    ///   - signature: 서버에서 받은 Promotional Offer 서명
    /// - Throws: OfferError
    @available(iOS 15.0, *)
    public func purchaseWithOffer(
        productId: String,
        signature: PromotionalOfferSignature
    ) async throws {
        // 1. StoreKit 상품 조회
        let products = try await Product.products(for: [productId])
        guard let product = products.first else {
            Logger.referral.error("PromotionalOfferService: 상품 미발견 — \(productId)")
            throw OfferError.productNotFound(productId)
        }

        // 2. Promotional Offer 옵션 생성
        let offerOption = Product.PurchaseOption.promotionalOffer(
            offerID: signature.offerID,
            keyID: signature.keyID,
            nonce: signature.nonce,
            signature: Data(base64Encoded: signature.signature) ?? Data(),
            timestamp: signature.timestamp
        )

        // 3. 구매 실행
        let result: Product.PurchaseResult
        do {
            result = try await product.purchase(options: [offerOption])
        } catch {
            Logger.referral.error("PromotionalOfferService: 구매 실패 — \(error.localizedDescription)")
            throw OfferError.storeKitError(error)
        }

        // 4. 결과 처리
        switch result {
        case .success(let verification):
            switch verification {
            case .verified(let transaction):
                // 거래 검증 성공 → finish
                await transaction.finish()
                Logger.referral.debug("PromotionalOfferService: 구매 성공 — \(productId), offer=\(signature.offerID)")

            case .unverified(_, let error):
                Logger.referral.error("PromotionalOfferService: 거래 검증 실패 — \(error.localizedDescription)")
                throw OfferError.verificationFailed
            }

        case .userCancelled:
            Logger.referral.debug("PromotionalOfferService: 사용자 취소")
            throw OfferError.userCancelled

        case .pending:
            Logger.referral.debug("PromotionalOfferService: 구매 대기 중 (Ask to Buy)")
            throw OfferError.purchasePending

        @unknown default:
            Logger.referral.error("PromotionalOfferService: 알 수 없는 구매 결과")
            throw OfferError.storeKitError(NSError(domain: "PromotionalOffer", code: -1))
        }
    }
    #endif
}

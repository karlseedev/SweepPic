//
//  ReferralModels.swift
//  AppCore
//
//  초대 리워드 프로그램 클라이언트 데이터 모델
//  서버(Supabase Edge Function) 응답을 디코딩하는 Codable 모델
//
//  참조: specs/004-referral-reward/data-model.md §Client-Side Models
//

import Foundation

// MARK: - ReferralLink

/// 초대 링크 정보 (create-link API 응답)
/// 초대자가 공유할 링크와 초대 코드를 포함
public struct ReferralLink: Codable, Sendable {
    /// 초대 코드 (형식: x0{6chars}9j)
    public let referralCode: String
    /// 공유용 URL (sweeppic.link/r/{code} 또는 폴백 URL)
    public let shareURL: URL

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case referralCode = "referral_code"
        case shareURL = "share_url"
    }

    // MARK: - Init

    public init(referralCode: String, shareURL: URL) {
        self.referralCode = referralCode
        self.shareURL = shareURL
    }
}

// MARK: - ReferralMatchResult

/// 코드 매칭 결과 (match-code / check-status API 응답)
/// 피초대자가 초대 코드를 입력했을 때 서버에서 반환하는 결과
public struct ReferralMatchResult: Codable, Sendable {
    /// referrals 테이블의 ID (리딤 보고 시 사용)
    public let referralId: String?
    /// Offer Code 리딤 URL (App Store 시트 열기용)
    public let redeemURL: URL?
    /// 할당된 Offer 이름 (referral_invited_monthly 등)
    public let offerName: String?
    /// 매칭 상태
    public let status: ReferralMatchStatus

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case referralId = "referral_id"
        case redeemURL = "redeem_url"
        case offerName = "offer_name"
        case status
    }

    // MARK: - Init

    public init(
        referralId: String?,
        redeemURL: URL?,
        offerName: String?,
        status: ReferralMatchStatus
    ) {
        self.referralId = referralId
        self.redeemURL = redeemURL
        self.offerName = offerName
        self.status = status
    }
}

// MARK: - ReferralMatchStatus

/// match-code / check-status 응답 상태
/// 서버에서 반환하는 5가지 + check-status의 none 상태
public enum ReferralMatchStatus: String, Codable, Sendable {
    /// 코드 매칭 성공 (Offer Code 할당됨)
    case matched
    /// Offer Code 리딤 완료
    case redeemed
    /// 초대자 보상 수령 완료
    case rewarded
    /// 자기 자신의 초대 코드 사용 시도
    case selfReferral = "self_referral"
    /// 이미 다른 초대 코드를 사용한 사용자
    case alreadyRedeemed = "already_redeemed"
    /// 유효하지 않은 초대 코드
    case invalidCode = "invalid_code"
    /// 사용 가능한 Offer Code 없음 (풀 소진)
    case noCodesAvailable = "no_codes_available"
    /// 아직 초대 코드를 사용하지 않음 (check-status 전용)
    case none
}

// MARK: - PendingRewardResponse

/// 대기 중인 보상 정보 (get-pending-rewards API 응답)
/// 초대자가 수령할 수 있는 보상 목록의 각 항목
public struct PendingRewardResponse: Codable, Sendable {
    /// pending_rewards 테이블의 ID
    public let id: String
    /// 연결된 referrals ID
    public let referralId: String
    /// 보상 유형 (수령 시점에 결정됨, pending 상태에서는 nil)
    public let rewardType: RewardType?
    /// Offer Code 리딤 URL (offer_code 타입일 때만)
    public let redeemURL: URL?
    /// 보상 상태
    public let status: RewardStatus

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case id
        case referralId = "referral_id"
        case rewardType = "reward_type"
        case redeemURL = "redeem_url"
        case status
    }

    // MARK: - Init

    public init(
        id: String,
        referralId: String,
        rewardType: RewardType?,
        redeemURL: URL?,
        status: RewardStatus
    ) {
        self.id = id
        self.referralId = referralId
        self.rewardType = rewardType
        self.redeemURL = redeemURL
        self.status = status
    }
}

// MARK: - RewardType

/// 보상 지급 방식 (claim-reward 시 서버가 결정)
public enum RewardType: String, Codable, Sendable {
    /// Promotional Offer (기존/만료 구독자용 — StoreKit 2 구매)
    case promotional
    /// Offer Code (비구독자용 — App Store 리딤 시트)
    case offerCode = "offer_code"
}

// MARK: - RewardStatus

/// 보상 상태
public enum RewardStatus: String, Codable, Sendable {
    /// 수령 대기 중
    case pending
    /// 수령 완료
    case completed
    /// 만료 (30일 경과)
    case expired
}

// MARK: - PromotionalOfferSignature

/// Promotional Offer 서명 응답 (claim-reward API에서 promotional 타입일 때)
/// StoreKit 2의 Product.PurchaseOption.promotionalOffer에 전달
public struct PromotionalOfferSignature: Codable, Sendable {
    /// ASC에서 설정한 Offer ID
    public let offerID: String
    /// ASC API Key ID
    public let keyID: String
    /// 서버에서 생성한 nonce
    public let nonce: UUID
    /// Base64 인코딩된 ECDSA P-256 서명
    public let signature: String
    /// Unix timestamp (milliseconds)
    public let timestamp: Int

    // MARK: - CodingKeys

    enum CodingKeys: String, CodingKey {
        case offerID = "offer_id"
        case keyID = "key_id"
        case nonce
        case signature
        case timestamp
    }

    // MARK: - Init

    public init(
        offerID: String,
        keyID: String,
        nonce: UUID,
        signature: String,
        timestamp: Int
    ) {
        self.offerID = offerID
        self.keyID = keyID
        self.nonce = nonce
        self.signature = signature
        self.timestamp = timestamp
    }
}

// MARK: - PendingRewardsListResponse

/// get-pending-rewards API 응답 래퍼
/// 서버에서 { rewards: [...] } 형태로 반환
public struct PendingRewardsListResponse: Codable, Sendable {
    /// 대기 중인 보상 목록 (생성일 오름차순)
    public let rewards: [PendingRewardResponse]
}

// MARK: - RewardClaimResponse

/// claim-reward API 응답 모델
/// 서버에서 보상 방식에 따라 signature 또는 redeem_url을 반환
public struct RewardClaimResponse: Codable, Sendable {
    /// 보상 지급 방식 ("promotional" 또는 "offer_code")
    public let rewardType: String
    /// Promotional Offer 서명 (promotional 타입만)
    public let signature: PromotionalOfferSignature?
    /// Offer Code 리딤 URL (offer_code 타입만)
    public let redeemURL: URL?
    /// 이미 수령 완료 상태일 때
    public let status: String?

    enum CodingKeys: String, CodingKey {
        case rewardType = "reward_type"
        case signature
        case redeemURL = "redeem_url"
        case status
    }
}

// MARK: - RewardClaimResult

/// 보상 수령 결과 (claim-reward API 응답을 파싱한 클라이언트 결과)
public enum RewardClaimResult: Sendable {
    /// Promotional Offer 서명 → StoreKit 2로 구매 적용
    case promotional(signature: PromotionalOfferSignature)
    /// Offer Code 리딤 URL → App Store 시트 열기
    case offerCode(redeemURL: URL)
    /// 에러 발생
    case error(message: String)
}

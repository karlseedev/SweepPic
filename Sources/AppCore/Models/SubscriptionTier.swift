//
//  SubscriptionTier.swift
//  AppCore
//
//  구독 티어 모델
//  - SubscriptionTier: Free / Pro 구분 enum
//  - SubscriptionState: 구독 상태 정보 구조체
//  data-model.md 참조
//

import Foundation

// MARK: - SubscriptionTier

/// 구독 티어 enum
/// - free: 무료 사용자 (일일 한도 + 광고)
/// - pro: Pro 구독자 (무제한 삭제 + 광고 제거)
public enum SubscriptionTier: String, Codable, Sendable {
    case free
    case pro
}

// MARK: - SubscriptionState

/// 구독 상태 정보 구조체
/// 인메모리 + StoreKit 2 캐시 기반
/// SubscriptionStore에서 관리하며, 앱 실행 중 상태를 추적
public struct SubscriptionState: Sendable {

    /// 현재 구독 티어 (.free / .pro)
    public let tier: SubscriptionTier

    /// Pro 구독 활성 여부
    public let isActive: Bool

    /// 자동 갱신 활성 여부
    public let autoRenewEnabled: Bool

    /// 결제 문제 여부 (갱신 실패 등)
    public let hasPaymentIssue: Bool

    /// 구독 만료 예정일 (오프라인 검증용)
    public let expirationDate: Date?

    /// 최초 구매일
    public let originalPurchaseDate: Date?

    // MARK: - Init

    public init(
        tier: SubscriptionTier = .free,
        isActive: Bool = false,
        autoRenewEnabled: Bool = false,
        hasPaymentIssue: Bool = false,
        expirationDate: Date? = nil,
        originalPurchaseDate: Date? = nil
    ) {
        self.tier = tier
        self.isActive = isActive
        self.autoRenewEnabled = autoRenewEnabled
        self.hasPaymentIssue = hasPaymentIssue
        self.expirationDate = expirationDate
        self.originalPurchaseDate = originalPurchaseDate
    }

    // MARK: - Defaults

    /// 기본값: Free 상태
    public static let free = SubscriptionState()
}

// MARK: - Product IDs

/// StoreKit 상품 ID 상수
public enum SubscriptionProductID {
    /// 월간 Pro 구독 ($2.99/월)
    public static let proMonthly = "pro_monthly"
    /// 연간 Pro 구독 ($19.99/년)
    public static let proYearly = "pro_yearly"

    /// 모든 상품 ID 배열
    public static let all: Set<String> = [proMonthly, proYearly]
}

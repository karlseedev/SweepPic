# Swift Protocols: 초대 리워드 프로그램

**Feature**: 004-referral-reward
**Date**: 2026-03-26

## Core Protocols

### ReferralServiceProtocol

Supabase API와 통신하는 서비스 인터페이스.

```swift
public protocol ReferralServiceProtocol: AnyObject {
    /// 초대 코드 생성 또는 기존 코드 조회
    func createOrGetLink(userId: String) async throws -> ReferralLink

    /// 피초대자: 초대 코드 매칭 + Offer Code 할당
    func matchCode(
        userId: String,
        referralCode: String,
        subscriptionStatus: String
    ) async throws -> ReferralMatchResult

    /// 피초대자: 리딤 완료 보고
    func reportRedemption(userId: String, referralId: String) async throws

    /// 피초대자: 초대 코드 적용 상태 확인
    func checkStatus(userId: String) async throws -> ReferralMatchResult

    /// 초대자: 대기 중인 보상 조회
    func getPendingRewards(userId: String) async throws -> [PendingRewardResponse]

    /// 초대자: 보상 수령 (Promotional Offer 서명 또는 Offer Code)
    func claimReward(
        userId: String,
        rewardId: String,
        subscriptionStatus: String,
        productId: String
    ) async throws -> RewardClaimResult

    /// Push 토큰 갱신
    func updateDeviceToken(userId: String, token: String) async throws
}
```

### ReferralStoreProtocol

클라이언트 측 초대 상태 관리.

```swift
public protocol ReferralStoreProtocol: AnyObject {
    /// Keychain 기반 영구 사용자 ID
    var userId: String { get }

    /// Push 프리프롬프트를 이미 표시했는지
    var hasAskedPushPermission: Bool { get set }
}
```

### ReferralCodeParserProtocol

초대 코드 추출 유틸리티.

```swift
public protocol ReferralCodeParserProtocol {
    /// 텍스트에서 초대 코드 추출 (정규식: /x0([a-zA-Z0-9]{6})9j/)
    /// 메시지 전체, 일부, 코드만 모두 지원
    func extractCode(from text: String) -> String?
}
```

### PushNotificationServiceProtocol

Push 알림 등록 및 토큰 관리.

```swift
public protocol PushNotificationServiceProtocol: AnyObject {
    /// Push 권한 상태 확인
    func checkAuthorizationStatus() async -> PushAuthorizationStatus

    /// 시스템 Push 권한 요청
    func requestAuthorization() async throws -> Bool

    /// 원격 알림 등록 (device token 요청)
    func registerForRemoteNotifications()

    /// 서버에 device token 전송
    func updateTokenOnServer(token: Data) async throws
}

public enum PushAuthorizationStatus: Sendable {
    case notDetermined   // 아직 안 물어봄
    case authorized      // 허용됨
    case denied          // 거부됨
    case provisional     // 임시 허용
}
```

### OfferRedemptionServiceProtocol

Offer Code 리딤 처리.

```swift
public protocol OfferRedemptionServiceProtocol {
    /// 리딤 URL을 열어 App Store 리딤 시트 표시
    func openRedeemURL(_ url: URL) async

    /// Transaction.updates에서 초대 관련 리딤 감지
    func observeReferralRedemptions(
        onRedeemed: @escaping (String) -> Void  // offerName
    )
}
```

### PromotionalOfferServiceProtocol

Promotional Offer 서명 요청 및 적용.

```swift
public protocol PromotionalOfferServiceProtocol {
    /// 서버에서 Promotional Offer 서명 요청
    func requestSignature(
        userId: String,
        rewardId: String,
        productId: String,
        subscriptionStatus: String
    ) async throws -> PromotionalOfferSignature

    /// StoreKit 2로 Promotional Offer 구매 적용
    func applyOffer(
        product: Product,
        signature: PromotionalOfferSignature
    ) async throws -> Product.PurchaseResult
}
```

### ReferralDeepLinkHandlerProtocol

딥링크 (Universal Link + Custom URL Scheme) 처리.

```swift
public protocol ReferralDeepLinkHandlerProtocol {
    /// URL에서 초대 코드 추출 시도
    /// Universal Link: sweeppic.link/r/{code}
    /// Custom URL Scheme: sweeppic://referral/{code}
    func extractReferralCode(from url: URL) -> String?

    /// 추출된 코드로 자동 매칭 처리 (Phase 2.5)
    func handleReferralURL(_ url: URL, from viewController: UIViewController) async
}
```

### ReferralNetworkMonitorProtocol

네트워크 연결 상태를 모니터링하여 오프라인 UI를 표시한다. (FR-040)

```swift
public protocol ReferralNetworkMonitorProtocol: AnyObject {
    /// 현재 네트워크 연결 여부
    var isConnected: Bool { get }

    /// 네트워크 상태 변경 시 콜백
    var onStatusChange: ((Bool) -> Void)? { get set }

    /// 모니터링 시작
    func startMonitoring()

    /// 모니터링 중지
    func stopMonitoring()
}
```

### ReferralAnalyticsProtocol

초대 프로그램 전용 분석 이벤트를 기록한다. (FR-045)

```swift
public protocol ReferralAnalyticsProtocol {
    func trackLinkCreated(userId: String)
    func trackLinkShared(userId: String, shareTarget: String)
    func trackCodeEntered(userId: String, referralCode: String, inputMethod: String)
    func trackAutoMatched(userId: String, referralCode: String, entryMethod: String)
    func trackCodeAssigned(userId: String, referralCode: String, offerName: String, subscriptionStatus: String)
    func trackCodeRedeemed(userId: String, referralId: String, offerName: String)
    func trackRewardShown(userId: String, rewardId: String, entryMethod: String)
    func trackRewardClaimed(userId: String, rewardId: String, rewardType: String, offerName: String)
}
```

## Reward Claim Result

```swift
public enum RewardClaimResult: Sendable {
    case promotional(signature: PromotionalOfferSignature)
    case offerCode(redeemURL: URL)
    case error(message: String)
}
```

## SubscriptionStore Extension

기존 `SubscriptionStoreProtocol`에 추가:

```swift
extension SubscriptionStoreProtocol {
    /// 현재 구독 상태를 서버 API용 문자열로 변환
    func referralSubscriptionStatus() -> String
    // Returns: "none", "monthly", "yearly", "expired_monthly", "expired_yearly"

    /// Promotional Offer로 구매 (초대 보상용)
    func purchaseWithPromotionalOffer(
        _ product: Product,
        signature: PromotionalOfferSignature
    ) async throws -> Product.PurchaseResult
}
```

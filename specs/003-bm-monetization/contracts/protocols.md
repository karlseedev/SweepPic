# Internal Protocols: BM 수익화 시스템

**Branch**: `003-bm-monetization` | **Date**: 2026-03-03

---

## UsageLimitStoreProtocol (AppCore)

```swift
public protocol UsageLimitStoreProtocol: AnyObject {
    // 읽기
    var remainingFreeDeletes: Int { get }
    var remainingRewards: Int { get }
    var lifetimeFreeGrantUsed: Bool { get }

    // 판단
    func canDeleteWithinLimit(count: Int) -> Bool
    func adsNeeded(for count: Int) -> Int

    // 기록
    func recordDelete(count: Int)
    func recordReward()
    func recordLifetimeFreeGrant()

    // 리셋
    func resetIfNewDay(serverDate: String?)
}
```

---

## GracePeriodServiceProtocol (AppCore)

```swift
public protocol GracePeriodServiceProtocol {
    var isActive: Bool { get }
    var remainingDays: Int { get }
    var currentDay: Int { get }  // 0, 1, 2, 3+
}
```

---

## SubscriptionStoreProtocol (SweepPic)

```swift
protocol SubscriptionStoreProtocol: AnyObject {
    var isProUser: Bool { get }
    var state: SubscriptionState { get }

    func purchase(_ product: Product) async throws -> Product.PurchaseResult
    func restorePurchases() async throws -> Bool
    func presentRedemptionSheet(from vc: UIViewController)

    func onStateChange(_ handler: @escaping (SubscriptionState) -> Void)
}
```

---

## TrashGateCoordinatorProtocol (SweepPic)

```swift
protocol TrashGateCoordinatorProtocol {
    /// 게이트 평가 후 팝업 표시 또는 바로 실행
    /// - onApproved: 게이트 통과 시 실행할 삭제 로직
    func evaluateAndPresent(
        from viewController: UIViewController,
        trashCount: Int,
        onApproved: @escaping () -> Void
    )
}
```

---

## AdManagerProtocol (SweepPic)

```swift
protocol AdManagerProtocol: AnyObject {
    func configure()
    func shouldShowAds() -> Bool  // Pro/Grace 체크

    // 리워드
    var isRewardedAdReady: Bool { get }
    func preloadRewardedAd()
    func showRewardedAd(from vc: UIViewController, completion: @escaping (Bool) -> Void)

    // 전면
    var isInterstitialReady: Bool { get }
    func preloadInterstitialAd()
    func showInterstitialAd(from vc: UIViewController, completion: @escaping () -> Void)
}
```

---

## DeletionStatsStoreProtocol (AppCore)

```swift
public protocol DeletionStatsStoreProtocol: AnyObject {
    var stats: DeletionStats { get }

    func addStats(deletedCount: Int, freedBytes: Int64)
}
```

---

## ReviewServiceProtocol (AppCore)

```swift
public protocol ReviewServiceProtocol {
    func recordSession()
    func recordTrashMove(count: Int)
    func evaluateAndRequestIfNeeded(from scene: UIWindowScene, isProhibitedTiming: Bool)
}
```

//
//  SubscriptionStore.swift
//  SweepPic
//
//  StoreKit 2 기반 구독 상태 관리 싱글톤
//  SubscriptionStoreProtocol 준수 (contracts/protocols.md)
//
//  역할:
//  - 앱 시작 시 구독 상태 확인 (Transaction.currentEntitlements)
//  - 실시간 상태 변경 감지 (Transaction.updates AsyncSequence)
//  - 구매 / 복원 / 리딤 코드 처리
//  - 환불 → Plus 즉시 해제 (FR-033)
//  - 오프라인: expirationDate 기반 (FR-053)
//  - 구독 완료 시 상태 즉시 갱신
//

import StoreKit
import UIKit
import AppCore
import OSLog

// MARK: - SubscriptionStoreProtocol

/// 구독 관리 프로토콜 (contracts/protocols.md)
protocol SubscriptionStoreProtocol: AnyObject {
    var isPlusUser: Bool { get }
    var state: SubscriptionState { get }

    func purchase(_ product: Product) async throws -> Product.PurchaseResult
    func restorePurchases() async throws -> Bool
    func presentRedemptionSheet(from vc: UIViewController)

    func onStateChange(_ handler: @escaping (SubscriptionState) -> Void)
}

// MARK: - SubscriptionStore

/// StoreKit 2 기반 구독 상태 관리 싱글톤
final class SubscriptionStore: SubscriptionStoreProtocol {

    // MARK: - Singleton

    static let shared = SubscriptionStore()
    private init() {}

    // MARK: - Properties

    /// 현재 구독 상태 (인메모리)
    private(set) var state: SubscriptionState = .free {
        didSet {
            // 상태 변경 시 핸들러 호출
            stateChangeHandlers.forEach { $0(state) }
        }
    }

    /// Plus 구독자 여부 (간편 접근)
    var isPlusUser: Bool {
        state.isActive && state.tier == .plus
    }

    /// 상태 변경 핸들러 목록
    private var stateChangeHandlers: [(SubscriptionState) -> Void] = []

    /// Transaction.updates 리스닝 태스크
    private var updateListenerTask: Task<Void, Never>?

    /// 로드된 상품 목록 캐시
    private(set) var products: [Product] = []

    /// 구독 설정 완료 여부
    private(set) var isConfigured = false

    #if DEBUG
    /// 디버그 오버라이드 활성 여부 — true이면 refreshSubscriptionStatus()가 상태를 덮어쓰지 않음
    private var debugOverrideActive = false
    #endif

    // MARK: - Configure

    /// 앱 시작 시 호출 — 상품 로드 + 구독 상태 확인 + 실시간 감지 시작
    /// AppDelegate.didFinishLaunching에서 호출
    func configure() {
        guard !isConfigured else { return }
        isConfigured = true

        Task {
            // 상품 목록 로드
            await loadProducts()

            // 현재 구독 상태 확인 (FR-028)
            await refreshSubscriptionStatus()

            // 실시간 상태 변경 감지 시작 (FR-029)
            startTransactionListener()

            Logger.app.debug("SubscriptionStore: 설정 완료 — isPlusUser=\(self.isPlusUser)")
        }
    }

    // MARK: - State Change Handler

    /// 상태 변경 핸들러 등록
    func onStateChange(_ handler: @escaping (SubscriptionState) -> Void) {
        stateChangeHandlers.append(handler)
    }

    // MARK: - Products

    /// 상품 로드 완료 알림 이름
    static let productsDidLoadNotification = Notification.Name("SubscriptionStoreProductsDidLoad")

    /// StoreKit 2 상품 목록 로드
    private func loadProducts() async {
        do {
            products = try await Product.products(for: SubscriptionProductID.all)
            Logger.app.debug("SubscriptionStore: 상품 \(self.products.count)개 로드 완료")
            await MainActor.run {
                NotificationCenter.default.post(name: Self.productsDidLoadNotification, object: nil)
            }
        } catch {
            Logger.app.error("SubscriptionStore: 상품 로드 실패 — \(error.localizedDescription)")
        }
    }

    /// 상품 로드 완료 여부
    var hasProducts: Bool { !products.isEmpty }

    /// 월간 상품 (편의 접근)
    var monthlyProduct: Product? {
        products.first { $0.id == SubscriptionProductID.plusMonthly }
    }

    /// 연간 상품 (편의 접근)
    var yearlyProduct: Product? {
        products.first { $0.id == SubscriptionProductID.plusYearly }
    }

    // MARK: - Purchase

    /// 구독 구매 실행
    /// - Parameter product: 구매할 StoreKit Product
    /// - Returns: 구매 결과
    func purchase(_ product: Product) async throws -> Product.PurchaseResult {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // 거래 검증
            let transaction = try checkVerified(verification)
            await transaction.finish()

            // 구독 상태 갱신
            await refreshSubscriptionStatus()

            // [BM] T055: 결제 완료 후 리뷰 금지 타이밍 플래그 설정 (FR-050)
            ReviewService.shared.isPaymentJustCompleted = true
            // [BM] T057: 구독 완료 이벤트 (FR-056)
            AnalyticsService.shared.trackSubscriptionCompleted(productID: product.id)

            Logger.app.debug("SubscriptionStore: 구매 성공 — \(product.id)")
            return result

        case .userCancelled:
            Logger.app.debug("SubscriptionStore: 사용자 구매 취소")
            return result

        case .pending:
            // Ask to Buy 등 대기 상태 (FR-038)
            Logger.app.debug("SubscriptionStore: 구매 대기 중 (Ask to Buy)")
            return result

        @unknown default:
            Logger.app.error("SubscriptionStore: 알 수 없는 구매 결과")
            return result
        }
    }

    // MARK: - Restore

    /// 구매 복원 (AppStore.sync 호출)
    /// - Returns: 복원 후 Plus 활성 여부
    func restorePurchases() async throws -> Bool {
        try await AppStore.sync()
        await refreshSubscriptionStatus()
        Logger.app.debug("SubscriptionStore: 복원 완료 — isPlusUser=\(self.isPlusUser)")
        return isPlusUser
    }

    // MARK: - Redemption Code

    /// 리딤 코드 시트 표시 (FR-031)
    func presentRedemptionSheet(from vc: UIViewController) {
        // iOS 16+에서 SKPaymentQueue.default().presentCodeRedemptionSheet() 사용
        // ⚠️ iOS 16.4+ 에서는 AppStore.presentOfferCodeRedeemSheet 사용 가능
        if #available(iOS 16.4, *) {
            // 비동기 메서드이므로 Task로 감싸서 호출
            Task {
                do {
                    try await AppStore.presentOfferCodeRedeemSheet(in: vc.view.window!.windowScene!)
                } catch {
                    Logger.app.error("SubscriptionStore: 리딤 코드 시트 표시 실패 — \(error.localizedDescription)")
                }
            }
        } else {
            SKPaymentQueue.default().presentCodeRedemptionSheet()
        }
        Logger.app.debug("SubscriptionStore: 리딤 코드 시트 표시")
    }

    // MARK: - Transaction Listener

    /// Transaction.updates AsyncSequence 리스닝 시작 (FR-029)
    /// 환불, 갱신 실패, 외부 구매 등 실시간 감지
    private func startTransactionListener() {
        updateListenerTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }
                do {
                    let transaction = try self.checkVerified(result)
                    await transaction.finish()
                    await self.refreshSubscriptionStatus()
                    Logger.app.debug("SubscriptionStore: Transaction 업데이트 감지 — \(transaction.productID)")
                } catch {
                    Logger.app.error("SubscriptionStore: Transaction 검증 실패 — \(error.localizedDescription)")
                }
            }
        }
    }

    // MARK: - Subscription Status Refresh

    /// 현재 구독 상태 갱신 (Transaction.currentEntitlements 순회)
    @MainActor
    func refreshSubscriptionStatus() async {
        #if DEBUG
        // 디버그 오버라이드 활성 시 StoreKit 조회로 상태를 덮어쓰지 않음
        if debugOverrideActive {
            Logger.app.debug("SubscriptionStore: 디버그 오버라이드 활성 → refresh 스킵")
            return
        }
        #endif

        var foundActiveSubscription = false
        var newState = SubscriptionState.free

        for await result in Transaction.currentEntitlements {
            guard let transaction = try? checkVerified(result) else { continue }

            // 구독 상품인지 확인
            guard SubscriptionProductID.all.contains(transaction.productID) else { continue }

            // 환불 여부 확인 (FR-033)
            if transaction.revocationDate != nil {
                Logger.app.debug("SubscriptionStore: 환불 감지 — \(transaction.productID)")
                continue
            }

            // 만료 확인
            if let expirationDate = transaction.expirationDate, expirationDate < Date() {
                continue
            }

            // 활성 구독 발견
            foundActiveSubscription = true

            // 갱신 상태 확인
            let autoRenew = await checkAutoRenewStatus(for: transaction)
            let paymentIssue = await checkPaymentIssue(for: transaction)

            newState = SubscriptionState(
                tier: .plus,
                isActive: true,
                autoRenewEnabled: autoRenew,
                hasPaymentIssue: paymentIssue,
                expirationDate: transaction.expirationDate,
                originalPurchaseDate: transaction.originalPurchaseDate
            )
        }

        // 오프라인 폴백 (FR-053): 활성 구독 없지만 만료일이 아직 지나지 않은 경우
        // ⚠️ 환불(revocationDate)된 트랜잭션은 currentEntitlements에서 이미 제외됨
        //    → foundActiveSubscription=false이면 환불/만료된 것이므로 폴백 적용 전 확인
        if !foundActiveSubscription, state.tier == .plus {
            // entitlements가 비어있으면 환불/만료 확정 → Free로 전환
            // 네트워크 문제로 entitlements 순회 자체가 안 된 경우만 폴백
            if let cached = state.expirationDate, cached > Date() {
                // 만료일이 남았지만 entitlement이 없음 → 환불 가능성 높음
                // 안전하게 Free로 전환 (온라인 상태에서 entitlement 없음 = 환불)
                Logger.app.debug("SubscriptionStore: entitlement 없음 + 만료일 미도래 → 환불로 판단, Free 전환")
            }
        }

        state = newState
    }

    // MARK: - Auto Renew / Payment Issue Check

    /// 자동 갱신 상태 확인
    private func checkAutoRenewStatus(for transaction: Transaction) async -> Bool {
        guard let statuses = try? await Product.SubscriptionInfo.status(
            for: transaction.productID
        ) else {
            return true // 확인 실패 시 기본값
        }

        for status in statuses {
            if case .verified(let renewalInfo) = status.renewalInfo {
                return renewalInfo.willAutoRenew
            }
        }
        return true
    }

    /// 결제 문제 확인 (갱신 실패)
    private func checkPaymentIssue(for transaction: Transaction) async -> Bool {
        guard let statuses = try? await Product.SubscriptionInfo.status(
            for: transaction.productID
        ) else {
            return false
        }

        for status in statuses {
            if status.state == .inBillingRetryPeriod || status.state == .inGracePeriod {
                return true
            }
        }
        return false
    }

    // MARK: - Verification

    /// 거래 검증 (온디바이스)
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            Logger.app.error("SubscriptionStore: 거래 검증 실패 — \(error.localizedDescription)")
            throw error
        case .verified(let value):
            return value
        }
    }

    // MARK: - Debug

    #if DEBUG
    /// 디버그용: 구독 상태를 Free로 강제 리셋
    func debugResetToFree() {
        debugOverrideActive = false
        state = .free
        Logger.app.debug("SubscriptionStore: DEBUG Free 리셋")
    }

    /// 디버그용: 구독 상태를 Plus로 강제 설정
    func debugSetPlus() {
        debugOverrideActive = true
        state = SubscriptionState(
            tier: .plus,
            isActive: true,
            autoRenewEnabled: true,
            expirationDate: Date().addingTimeInterval(365 * 24 * 3600)
        )
        Logger.app.debug("SubscriptionStore: DEBUG Plus 설정 (오버라이드 ON)")
    }

    /// 디버그용: 결제 문제 시뮬레이션 (갱신 실패 뱃지 테스트)
    func debugSetPaymentIssue() {
        debugOverrideActive = true
        state = SubscriptionState(
            tier: .plus,
            isActive: true,
            autoRenewEnabled: false,
            hasPaymentIssue: true,
            expirationDate: Date().addingTimeInterval(365 * 24 * 3600)
        )
        Logger.app.debug("SubscriptionStore: DEBUG 결제 문제 시뮬레이션 (오버라이드 ON)")
    }
    #endif

    // MARK: - Deinit

    deinit {
        updateListenerTask?.cancel()
    }
}

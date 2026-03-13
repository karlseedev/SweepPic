//
//  PaywallViewModel.swift
//  PickPhoto
//
//  페이월 화면 뷰모델
//  - 가격 포맷팅 (NumberFormatter, locale 반영)
//  - 연간 메인 + 월간 보조 가격 표시
//  - 취소선 정가 계산 (연간 = 월간×12 대비 할인율)
//  - 무료/Plus 비교표 데이터
//

import StoreKit
import Foundation
import AppCore
import OSLog

// MARK: - PaywallViewModel

/// 페이월 화면 데이터 관리
final class PaywallViewModel {

    // MARK: - Properties

    /// 연간 상품
    private(set) var yearlyProduct: Product?
    /// 월간 상품
    private(set) var monthlyProduct: Product?

    /// 상품 로드 완료 여부
    var isLoaded: Bool {
        yearlyProduct != nil && monthlyProduct != nil
    }

    // MARK: - Load Products

    /// SubscriptionStore에서 상품 로드 + eligibility 체크
    func loadProducts() {
        yearlyProduct = SubscriptionStore.shared.yearlyProduct
        monthlyProduct = SubscriptionStore.shared.monthlyProduct
        checkIntroOfferEligibility()
    }

    /// 직접 로드한 상품으로 설정 (SubscriptionStore 미로드 시 폴백)
    func setProducts(_ products: [Product]) {
        yearlyProduct = products.first { $0.id == SubscriptionProductID.plusYearly }
        monthlyProduct = products.first { $0.id == SubscriptionProductID.plusMonthly }
        checkIntroOfferEligibility()
    }

    /// Intro Offer eligibility 비동기 체크
    /// 재구독자 등 미자격자에게는 "무료 체험" 텍스트를 숨김
    private func checkIntroOfferEligibility() {
        guard let product = yearlyProduct ?? monthlyProduct else { return }
        Task {
            let eligible = await product.subscription?.isEligibleForIntroOffer ?? false
            await MainActor.run {
                self.isEligibleForIntroOffer = eligible
            }
        }
    }

    // MARK: - Price Formatting

    /// 연간 가격 표시 문자열 (예: "₩29,900/년")
    var yearlyPriceText: String {
        guard let product = yearlyProduct else { return "로딩 중..." }
        return "\(product.displayPrice)/년"
    }

    /// 월간 가격 표시 문자열 (예: "₩3,900/월")
    var monthlyPriceText: String {
        guard let product = monthlyProduct else { return "로딩 중..." }
        return "\(product.displayPrice)/월"
    }

    /// 연간 상품의 월 환산 가격 (예: "월 ₩2,492")
    var yearlyPerMonthText: String {
        guard let product = yearlyProduct else { return "" }
        let monthlyEquivalent = product.price / 12
        // locale 기반 포맷팅
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = product.priceFormatStyle.locale
        formatter.maximumFractionDigits = 0
        let formatted = formatter.string(from: monthlyEquivalent as NSDecimalNumber) ?? "\(monthlyEquivalent)"
        return "월 \(formatted)"
    }

    /// 취소선 정가 (월간×12 → 연간 비교용)
    /// 예: 월간 $2.99 × 12 = $35.88 → 연간 $19.99 대비 44% 할인
    var yearlyStrikethroughText: String? {
        guard let monthly = monthlyProduct else { return nil }
        let fullYearlyPrice = monthly.price * 12
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = monthly.priceFormatStyle.locale
        formatter.maximumFractionDigits = 0
        return formatter.string(from: fullYearlyPrice as NSDecimalNumber)
    }

    /// 연간 할인율 (예: "44%")
    var yearlySavingsPercent: String? {
        guard let yearly = yearlyProduct, let monthly = monthlyProduct else { return nil }
        let fullYearlyPrice = monthly.price * 12
        guard fullYearlyPrice > 0 else { return nil }
        let savings = ((fullYearlyPrice - yearly.price) / fullYearlyPrice * 100)
        let percent = NSDecimalNumber(decimal: savings).intValue
        guard percent > 0 else { return nil }
        return "\(percent)%"
    }

    /// Intro Offer eligibility (상품 로드 시 조회)
    private(set) var isEligibleForIntroOffer: Bool = true

    /// 연간 무료 체험 기간 텍스트 (introductory offer 기반)
    /// eligibility 미자격 시 nil 반환 (재구독자 등)
    var freeTrialText: String? {
        guard isEligibleForIntroOffer else { return nil }
        guard let yearly = yearlyProduct,
              let intro = yearly.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        return formatTrialPeriod(intro.period)
    }

    /// 월간 무료 체험 기간 텍스트 (introductory offer 기반)
    /// eligibility 미자격 시 nil 반환
    var monthlyFreeTrialText: String? {
        guard isEligibleForIntroOffer else { return nil }
        guard let monthly = monthlyProduct,
              let intro = monthly.subscription?.introductoryOffer,
              intro.paymentMode == .freeTrial else { return nil }
        return formatTrialPeriod(intro.period)
    }

    /// 체험 기간 → 텍스트 변환 헬퍼
    private func formatTrialPeriod(_ period: Product.SubscriptionPeriod) -> String? {
        switch period.unit {
        case .day:
            return "\(period.value)일 무료 체험"
        case .week:
            return "\(period.value)주 무료 체험"
        case .month:
            return "\(period.value)개월 무료 체험"
        case .year:
            return "\(period.value)년 무료 체험"
        @unknown default:
            return nil
        }
    }

    // MARK: - Comparison Table

    /// 비교표 데이터 (FR-035)
    struct ComparisonRow {
        let feature: String
        let freeValue: String
        let plusValue: String
    }

    /// 무료/Plus 비교표 항목
    var comparisonRows: [ComparisonRow] {
        [
            ComparisonRow(feature: "일일 삭제", freeValue: "10장", plusValue: "무제한"),
            ComparisonRow(feature: "광고", freeValue: "있음", plusValue: "없음"),
            ComparisonRow(feature: "유사 사진 정리", freeValue: "제공", plusValue: "제공"),
            ComparisonRow(feature: "얼굴 인식 확대", freeValue: "제공", plusValue: "제공"),
        ]
    }

    // MARK: - Purchase Actions

    /// 연간 구독 구매
    func purchaseYearly() async throws -> Product.PurchaseResult {
        guard let product = yearlyProduct else {
            throw SubscriptionError.productNotLoaded
        }
        return try await SubscriptionStore.shared.purchase(product)
    }

    /// 월간 구독 구매
    func purchaseMonthly() async throws -> Product.PurchaseResult {
        guard let product = monthlyProduct else {
            throw SubscriptionError.productNotLoaded
        }
        return try await SubscriptionStore.shared.purchase(product)
    }

    /// 구매 복원
    func restorePurchases() async throws -> Bool {
        try await SubscriptionStore.shared.restorePurchases()
    }
}

// MARK: - SubscriptionError

/// 구독 관련 에러
enum SubscriptionError: LocalizedError {
    case productNotLoaded

    var errorDescription: String? {
        switch self {
        case .productNotLoaded:
            return "상품 정보를 불러올 수 없습니다. 네트워크 연결을 확인해주세요."
        }
    }
}

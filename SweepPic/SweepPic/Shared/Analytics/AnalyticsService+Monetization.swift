// AnalyticsService+Monetization.swift
// BM 수익화 이벤트 (FR-056)
//
// - 게이트 노출/선택, 광고 시청, 페이월/구독, 삭제 완료,
//   ATT 결과 등 비즈니스 이벤트 추적
// - 모든 이벤트는 즉시 전송형 (sendEvent)
// - 참조: specs/003-bm-monetization/tasks.md T056

import Foundation

// MARK: - Monetization Enums

/// 게이트 팝업에서 사용자 선택
enum GateChoice: String {
    case ad      = "ad"       // 광고 시청
    case plus    = "plus"     // Plus 업그레이드
    case dismiss = "dismiss"  // 닫기
}

/// 광고 유형
enum AdType: String {
    case rewarded     = "rewarded"      // 리워드 광고
    case interstitial = "interstitial"  // 전면 광고
    case banner       = "banner"        // 배너 광고
}

/// 페이월 진입 경로
enum PaywallSource: String {
    case gate   = "gate"    // 게이트 팝업에서 Plus 선택
    case menu   = "menu"    // 프리미엄 메뉴에서 구독 관리
    case banner = "banner"  // 배너 탭
    case gauge  = "gauge"   // 게이지 상세 팝업
    case firstPaywall = "first_paywall"  // 첫 페이월 (Apple Free Trial 전환)
}

/// 구독 해지 사유 (Exit Survey)
enum CancelReason: String {
    case price       = "price"        // 가격이 부담돼요
    case enoughFree  = "enough_free"  // 삭제 한도가 충분해요
    case done        = "done"         // 사진 정리를 다 했어요
    case competitor  = "competitor"   // 다른 앱을 사용해요
    case other       = "other"        // 기타
}

// MARK: - Monetization Events

extension AnalyticsService {

    // MARK: - Gate Events

    /// 게이트 팝업 노출 (한도 초과 시)
    /// - Parameters:
    ///   - trashCount: 삭제 대상 수
    ///   - remainingLimit: 남은 무료 한도
    func trackGateShown(trashCount: Int, remainingLimit: Int) {
        guard !shouldSkip() else { return }
        sendEvent("bm.gateShown", parameters: [
            "trashCount": String(trashCount),
            "remainingLimit": String(remainingLimit),
        ])
    }

    /// 게이트 팝업에서 사용자 선택
    /// - Parameter choice: 선택 항목 (ad/plus/dismiss)
    func trackGateSelection(choice: GateChoice) {
        guard !shouldSkip() else { return }
        sendEvent("bm.gateSelection", parameters: [
            "choice": choice.rawValue,
        ])
    }

    // MARK: - Ad Events

    /// 광고 시청 완료
    /// - Parameters:
    ///   - type: 광고 유형 (rewarded/interstitial)
    ///   - source: 진입 경로 (gate/gauge/auto)
    func trackAdWatched(type: AdType, source: String) {
        guard !shouldSkip() else { return }
        sendEvent("bm.adWatched", parameters: [
            "type": type.rawValue,
            "source": source,
        ])
    }

    // MARK: - Paywall & Subscription Events

    /// 페이월 화면 노출
    /// - Parameter source: 진입 경로 (gate/menu/banner/gauge)
    func trackPaywallShown(source: PaywallSource) {
        guard !shouldSkip() else { return }
        sendEvent("bm.paywallShown", parameters: [
            "source": source.rawValue,
        ])
    }

    /// 구독 완료
    /// - Parameter productID: 구독 상품 ID (plus_monthly/plus_yearly)
    func trackSubscriptionCompleted(productID: String) {
        guard !shouldSkip() else { return }
        sendEvent("bm.subscriptionCompleted", parameters: [
            "productID": productID,
        ])
    }

    // MARK: - Deletion Events

    /// 삭제대기함 비우기/선택 삭제 완료 (게이트 통과 후)
    /// - Parameter count: 삭제된 사진 수
    func trackDeletionCompleted(count: Int) {
        guard !shouldSkip() else { return }
        sendEvent("bm.deletionCompleted", parameters: [
            "count": String(count),
        ])
    }

    // MARK: - ATT Events

    /// ATT 프리프롬프트 결과
    /// - Parameter authorized: 추적 허용 여부
    func trackATTResult(authorized: Bool) {
        guard !shouldSkip() else { return }
        sendEvent("bm.attResult", parameters: [
            "authorized": String(authorized),
        ])
    }

    // MARK: - Cancel Reason Events

    /// 구독 해지 사유 (Exit Survey)
    /// - Parameters:
    ///   - reason: 해지 사유 (5개 선택지)
    ///   - text: 기타 사유 자유 입력 (최대 200자)
    func trackCancelReason(reason: CancelReason, text: String? = nil) {
        guard !shouldSkip() else { return }
        var params: [String: String] = ["reason": reason.rawValue]
        if let text = text, !text.isEmpty {
            params["text"] = String(text.prefix(200))
        }
        sendEvent("bm.cancelReason", parameters: params)
    }
}

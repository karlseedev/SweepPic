//
//  ReferralAnalytics.swift
//  SweepPic
//
//  초대 리워드 프로그램 분석 이벤트 (9종)
//  AnalyticsService.sendEvent 패턴으로 즉시 전송
//
//  이벤트 목록:
//  1. referral.linkCreated    — 초대 링크 생성
//  2. referral.linkShared     — 초대 링크 공유 완료
//  3. referral.landingVisited — 랜딩 페이지 방문 (서버 전용)
//  4. referral.codeEntered    — 초대 코드 입력
//  5. referral.autoMatched    — 딥링크 자동 매칭
//  6. referral.codeAssigned   — Offer Code 할당
//  7. referral.codeRedeemed   — Offer Code 리딤 완료
//  8. referral.rewardShown    — 보상 화면 표시
//  9. referral.rewardClaimed  — 보상 수령 완료
//
//  참조: specs/004-referral-reward/tasks.md T047
//  참조: specs/004-referral-reward/contracts/protocols.md §ReferralAnalyticsProtocol
//

import Foundation

// MARK: - Referral Analytics Events

extension AnalyticsService {

    // MARK: - 1. 링크 생성

    /// 초대 링크 생성 성공 시 호출
    func trackReferralLinkCreated() {
        guard !shouldSkip() else { return }
        sendEvent("referral.linkCreated")
    }

    // MARK: - 2. 링크 공유

    /// 초대 링크 공유 완료 시 호출
    /// - Parameter shareTarget: 공유 대상 (kakao, messages, copy 등)
    func trackReferralLinkShared(shareTarget: String) {
        guard !shouldSkip() else { return }
        sendEvent("referral.linkShared", parameters: [
            "share_target": shareTarget,
        ])
    }

    // MARK: - 3. 랜딩 페이지 방문 (서버 전용 — 클라이언트 미호출)
    // referral-landing Edge Function에서 events 테이블에 직접 INSERT

    // MARK: - 4. 코드 입력

    /// 피초대자가 초대 코드를 입력했을 때 호출
    /// - Parameters:
    ///   - inputMethod: 입력 방식 ("paste" 붙여넣기, "manual" 직접 입력)
    func trackReferralCodeEntered(inputMethod: String) {
        guard !shouldSkip() else { return }
        sendEvent("referral.codeEntered", parameters: [
            "input_method": inputMethod,
        ])
    }

    // MARK: - 5. 딥링크 자동 매칭

    /// 딥링크(Universal Link/Custom URL Scheme)로 자동 매칭 시 호출
    /// - Parameter entryMethod: 진입 방식 ("universal_link", "custom_scheme")
    func trackReferralAutoMatched(entryMethod: String) {
        guard !shouldSkip() else { return }
        sendEvent("referral.autoMatched", parameters: [
            "entry_method": entryMethod,
        ])
    }

    // MARK: - 6. Offer Code 할당

    /// match-code 성공 시 호출 (코드 매칭 + Offer Code 할당 완료)
    /// - Parameters:
    ///   - offerName: 할당된 Offer 이름 (referral_invited_monthly 등)
    ///   - subscriptionStatus: 피초대자 구독 상태
    func trackReferralCodeAssigned(offerName: String, subscriptionStatus: String) {
        guard !shouldSkip() else { return }
        sendEvent("referral.codeAssigned", parameters: [
            "offer_name": offerName,
            "subscription_status": subscriptionStatus,
        ])
    }

    // MARK: - 7. Offer Code 리딤 완료

    /// 피초대자 Offer Code 리딤 완료 시 호출
    func trackReferralCodeRedeemed() {
        guard !shouldSkip() else { return }
        sendEvent("referral.codeRedeemed")
    }

    // MARK: - 8. 보상 화면 표시

    /// 초대자 보상 수령 화면 표시 시 호출
    /// - Parameter entryMethod: 진입 방식 ("cold_start", "menu", "push")
    func trackReferralRewardShown(entryMethod: String) {
        guard !shouldSkip() else { return }
        sendEvent("referral.rewardShown", parameters: [
            "entry_method": entryMethod,
        ])
    }

    // MARK: - 9. 보상 수령 완료

    /// 초대자 보상 수령 완료 시 호출
    /// - Parameters:
    ///   - rewardType: 보상 방식 ("promotional", "offer_code")
    ///   - offerName: Offer 이름
    func trackReferralRewardClaimed(rewardType: String, offerName: String) {
        guard !shouldSkip() else { return }
        sendEvent("referral.rewardClaimed", parameters: [
            "reward_type": rewardType,
            "offer_name": offerName,
        ])
    }
}

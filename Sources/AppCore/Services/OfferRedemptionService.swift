//
//  OfferRedemptionService.swift
//  AppCore
//
//  Offer Code 리딤 처리 서비스
//  리딤 URL을 열어 App Store 리딤 시트를 표시하고,
//  Transaction.updates에서 초대 관련 리딤을 감지하여 서버에 보고한다.
//
//  주요 기능:
//  - 리딤 URL 열기 (UIApplication.shared.open)
//  - Transaction.updates에서 referral_invited_* offerName 감지
//  - report-redemption API 호출 + 지수 백오프 3회 재시도
//  - 앱 실행 시 미보고 리딤 재감지 (FR-035)
//
//  참조: specs/004-referral-reward/contracts/protocols.md §OfferRedemptionServiceProtocol
//  참조: specs/004-referral-reward/spec.md FR-035
//

import Foundation
import StoreKit
import OSLog
#if canImport(UIKit)
import UIKit
#endif

// MARK: - OfferRedemptionService

/// Offer Code 리딤 처리 및 Transaction 감지 서비스
public final class OfferRedemptionService {

    // MARK: - Singleton

    public static let shared = OfferRedemptionService()

    // MARK: - Constants

    /// 초대 관련 Offer Name 접두사 — 이 접두사로 시작하는 트랜잭션을 감지
    /// 피초대자 전용 접두사 (초대자 보상 referral_reward_*와 구분)
    private static let referralOfferPrefix = "referral_invited_"

    /// 리딤 보고 최대 재시도 횟수 (지수 백오프)
    private static let maxRetryCount = 3

    /// 지수 백오프 기본 대기 시간 (초) — 1, 2, 4초
    private static let baseRetryDelay: TimeInterval = 1.0

    // MARK: - Properties

    /// Transaction.updates 리스닝 태스크
    private var transactionListenerTask: Task<Void, Never>?

    /// 리딤 감지 콜백 — offerName을 전달
    private var onRedemptionDetected: ((String) -> Void)?

    /// 현재 진행 중인 referral_id (match-code 결과에서 설정)
    /// report-redemption 호출 시 사용
    public var currentReferralId: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API: 리딤 URL 열기

    /// 리딤 URL을 열어 App Store Offer Code 리딤 시트를 표시한다.
    /// UIApplication.shared.open은 메인 스레드에서 호출해야 한다.
    ///
    /// - Parameter url: App Store 리딤 URL
    ///   (형식: https://apps.apple.com/redeem?ctx=offercodes&id={APP_ID}&code={CODE})
    #if canImport(UIKit)
    @MainActor
    public func openRedeemURL(_ url: URL) {
        Logger.referral.debug("OfferRedemptionService: 리딤 URL 열기 — \(url.absoluteString.prefix(60))...")
        UIApplication.shared.open(url, options: [:]) { success in
            if success {
                Logger.referral.debug("OfferRedemptionService: 리딤 URL 열기 성공")
            } else {
                Logger.referral.error("OfferRedemptionService: 리딤 URL 열기 실패")
            }
        }
    }
    #endif

    // MARK: - Public API: Transaction 감지

    /// Transaction.updates에서 초대 관련 리딤을 감지한다.
    /// 앱 실행 중 Offer Code 리딤이 완료되면 콜백을 호출한다.
    ///
    /// - Parameter onRedeemed: 리딤 감지 시 호출되는 콜백 (offerName 전달)
    public func startObservingRedemptions(
        onRedeemed: @escaping (String) -> Void
    ) {
        self.onRedemptionDetected = onRedeemed

        // 기존 리스닝 태스크 취소
        transactionListenerTask?.cancel()

        // Transaction.updates 리스닝 시작
        transactionListenerTask = Task(priority: .background) { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { break }

                // 트랜잭션 검증
                guard case .verified(let transaction) = result else {
                    continue
                }

                // 초대 관련 Offer인지 확인
                if let offerID = transaction.offerID,
                   offerID.hasPrefix(Self.referralOfferPrefix) {
                    Logger.referral.debug(
                        "OfferRedemptionService: 초대 리딤 감지 — offerID=\(offerID)"
                    )

                    // 트랜잭션 완료 처리
                    await transaction.finish()

                    // 콜백 호출
                    await MainActor.run {
                        self.onRedemptionDetected?(offerID)
                    }

                    // 서버에 리딤 보고
                    await self.reportRedemptionWithRetry()
                }
            }
        }

        Logger.referral.debug("OfferRedemptionService: Transaction 감지 시작")
    }

    /// Transaction 감지를 중지한다.
    public func stopObservingRedemptions() {
        transactionListenerTask?.cancel()
        transactionListenerTask = nil
        onRedemptionDetected = nil
        Logger.referral.debug("OfferRedemptionService: Transaction 감지 중지")
    }

    // MARK: - Public API: 미보고 리딤 재감지

    /// 앱 실행 시 미보고 리딤을 재감지한다 (FR-035).
    /// Transaction.currentEntitlements를 순회하여 초대 관련 Offer를 찾고,
    /// 서버 상태가 matched(미보고)이면 report-redemption을 호출한다.
    public func checkUnreportedRedemptions() async {
        // 현재 referral_id가 없으면 확인 불필요
        // (check-status에서 matched 상태일 때 설정됨)
        guard currentReferralId != nil else { return }

        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else {
                continue
            }

            // 초대 관련 Offer인지 확인
            if let offerID = transaction.offerID,
               offerID.hasPrefix(Self.referralOfferPrefix) {
                Logger.referral.debug(
                    "OfferRedemptionService: 미보고 리딤 발견 — offerID=\(offerID)"
                )
                // 서버에 보고
                await reportRedemptionWithRetry()
                break
            }
        }
    }

    // MARK: - Private: 리딤 보고 (지수 백오프)

    /// 서버에 리딤 완료를 보고한다 (지수 백오프 3회 재시도).
    ///
    /// - FR-035: 실패 시 1초 → 2초 → 4초 대기 후 재시도
    /// - 3회 모두 실패하면 다음 앱 실행 시 checkUnreportedRedemptions()에서 재시도
    private func reportRedemptionWithRetry() async {
        guard let referralId = currentReferralId else {
            Logger.referral.error("OfferRedemptionService: referral_id 없음 — 보고 불가")
            return
        }

        let userId = ReferralStore.shared.userId

        for attempt in 0..<Self.maxRetryCount {
            do {
                try await ReferralService.shared.reportRedemption(
                    userId: userId,
                    referralId: referralId
                )

                Logger.referral.debug(
                    "OfferRedemptionService: 리딤 보고 성공 (시도 \(attempt + 1))"
                )

                // 보고 성공 → referral_id 초기화
                currentReferralId = nil
                return

            } catch {
                let delay = Self.baseRetryDelay * pow(2.0, Double(attempt))
                Logger.referral.error(
                    "OfferRedemptionService: 리딤 보고 실패 (시도 \(attempt + 1)/\(Self.maxRetryCount)) — \(error.localizedDescription), \(delay)초 후 재시도"
                )

                // 지수 백오프 대기
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            }
        }

        Logger.referral.error(
            "OfferRedemptionService: 리딤 보고 최종 실패 — 다음 실행 시 재시도"
        )
    }
}


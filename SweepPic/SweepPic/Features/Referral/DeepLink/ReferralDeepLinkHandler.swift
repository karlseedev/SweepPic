//
//  ReferralDeepLinkHandler.swift
//  SweepPic
//
//  딥링크(Universal Link + Custom URL Scheme)로 앱이 열렸을 때
//  초대 코드를 자동 추출하고 혜택을 적용하는 핸들러
//
//  지원 URL 형식:
//  - Universal Link: https://sweeppic.link/r/{code}
//  - Custom URL Scheme: sweeppic://referral/{code}
//
//  처리 흐름:
//  1. URL에서 초대 코드 추출
//  2. check-status API로 현재 상태 확인
//  3. 분기:
//     - none → matchCode + 리딤 URL 열기
//     - matched → 기존 코드 리딤 URL 열기
//     - redeemed → 무시 (이미 적용됨)
//     - self_referral → "본인의 초대 코드는 사용할 수 없습니다" 안내
//
//  참조: specs/004-referral-reward/tasks.md T036
//  참조: specs/004-referral-reward/contracts/protocols.md §ReferralDeepLinkHandlerProtocol
//

import UIKit
import AppCore
import OSLog

// MARK: - ReferralDeepLinkHandler

/// 딥링크로 전달된 초대 코드를 자동 처리하는 핸들러
/// SceneDelegate에서 URL을 전달받아 처리한다.
final class ReferralDeepLinkHandler {

    // MARK: - Singleton

    static let shared = ReferralDeepLinkHandler()

    // MARK: - Constants

    /// Custom URL Scheme 호스트
    private static let customSchemeHost = "referral"

    /// Universal Link 경로 패턴 (/r/{code})
    private static let universalLinkPathPrefix = "/r/"

    // MARK: - Properties

    /// 현재 처리 중인 코드 (중복 처리 방지)
    private var processingCode: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API: URL에서 코드 추출

    /// URL에서 초대 코드를 추출한다.
    ///
    /// Universal Link: https://sweeppic.link/r/{code}
    /// Custom URL Scheme: sweeppic://referral/{code}
    ///
    /// - Parameter url: 딥링크 URL
    /// - Returns: 추출된 초대 코드, 없으면 nil
    func extractReferralCode(from url: URL) -> String? {
        // Custom URL Scheme: sweeppic://referral/{code}
        if url.scheme == "sweeppic" {
            // host가 "referral"인지 확인
            guard url.host == Self.customSchemeHost else {
                Logger.referral.debug("DeepLinkHandler: Custom Scheme 비매칭 호스트 — \(url.host ?? "nil")")
                return nil
            }

            // 경로에서 코드 추출 (예: /x0k7m2x99j)
            let path = url.path
            let code = path.hasPrefix("/") ? String(path.dropFirst()) : path

            guard !code.isEmpty else {
                Logger.referral.debug("DeepLinkHandler: Custom Scheme 코드 없음")
                return nil
            }

            Logger.referral.debug("DeepLinkHandler: Custom Scheme 코드 추출 — \(code)")
            return code
        }

        // Universal Link: https://sweeppic.link/r/{code}
        // 또는 Supabase 기본 도메인: .../referral-landing/r/{code}
        let path = url.path
        if let range = path.range(of: Self.universalLinkPathPrefix) {
            let code = String(path[range.upperBound...])
            guard !code.isEmpty, !code.contains("/") else {
                Logger.referral.debug("DeepLinkHandler: Universal Link 코드 없음 또는 잘못된 형식")
                return nil
            }

            Logger.referral.debug("DeepLinkHandler: Universal Link 코드 추출 — \(code)")
            return code
        }

        Logger.referral.debug("DeepLinkHandler: URL에서 코드를 찾을 수 없음 — \(url.absoluteString.prefix(80))")
        return nil
    }

    // MARK: - Public API: 딥링크 처리

    /// 딥링크 URL을 처리하여 초대 코드를 자동 매칭한다.
    ///
    /// - Parameters:
    ///   - url: 딥링크 URL
    ///   - presenter: 알림/모달을 표시할 뷰컨트롤러
    func handleReferralURL(_ url: URL, from presenter: UIViewController) {
        // 코드 추출
        guard let code = extractReferralCode(from: url) else {
            Logger.referral.debug("DeepLinkHandler: 초대 코드 없음 — 무시")
            return
        }

        // 중복 처리 방지
        guard processingCode != code else {
            Logger.referral.debug("DeepLinkHandler: 이미 처리 중인 코드 — \(code)")
            return
        }
        processingCode = code

        // [Analytics] T048: 딥링크 자동 매칭 이벤트
        let entryMethod = url.scheme == "sweeppic" ? "custom_scheme" : "universal_link"
        AnalyticsService.shared.trackReferralAutoMatched(entryMethod: entryMethod)

        Logger.referral.debug("DeepLinkHandler: 초대 코드 처리 시작 — \(code)")

        let userId = ReferralStore.shared.userId

        Task { @MainActor in
            defer { self.processingCode = nil }

            do {
                // 1. check-status로 현재 상태 확인
                let statusResult = try await ReferralService.shared.checkStatus(userId: userId)

                switch statusResult.status {
                case .none:
                    // 코드 미적용 → match-code 호출
                    await self.matchAndRedeem(
                        code: code,
                        userId: userId,
                        presenter: presenter
                    )

                case .matched:
                    // 이미 매칭됨, 리딤 미완료 → 기존 리딤 URL 열기
                    if let redeemURL = statusResult.redeemURL {
                        Logger.referral.debug("DeepLinkHandler: matched 상태 → 리딤 URL 열기")

                        // referral_id 설정 (report-redemption용)
                        if let referralId = statusResult.referralId {
                            OfferRedemptionService.shared.currentReferralId = referralId
                        }

                        // Transaction 감지 시작
                        OfferRedemptionService.shared.startObservingRedemptions { offerName in
                            Logger.referral.debug("DeepLinkHandler: 리딤 감지 — \(offerName)")
                        }

                        OfferRedemptionService.shared.openRedeemURL(redeemURL)
                    } else {
                        Logger.referral.debug("DeepLinkHandler: matched 상태이나 리딤 URL 없음")
                    }

                case .redeemed, .rewarded:
                    // 이미 적용됨 → 무시 (토스트로 안내)
                    Logger.referral.debug("DeepLinkHandler: 이미 적용됨 — 무시")
                    self.showToast(String(localized: "error.server.alreadyReferred"), on: presenter)

                default:
                    Logger.referral.debug("DeepLinkHandler: 예상치 못한 상태 — \(statusResult.status.rawValue)")
                }

            } catch let error as ReferralServiceError {
                let message = error.localizedDisplayMessage
                Logger.referral.error("DeepLinkHandler: check-status 실패 — \(message)")
                self.showToast(message, on: presenter)
            } catch {
                Logger.referral.error("DeepLinkHandler: check-status 실패 — \(error.localizedDescription)")
                self.showToast(String(localized: "error.server.noConnection"), on: presenter)
            }
        }
    }

    // MARK: - Private: 매칭 + 리딤

    /// match-code API 호출 후 리딤 URL을 연다.
    ///
    /// - Parameters:
    ///   - code: 초대 코드
    ///   - userId: 사용자 ID
    ///   - presenter: 알림 표시용 뷰컨트롤러
    @MainActor
    private func matchAndRedeem(
        code: String,
        userId: String,
        presenter: UIViewController
    ) async {
        // 구독 상태 확인
        let subscriptionStatus = await getSubscriptionStatus()

        do {
            let result = try await ReferralService.shared.matchCode(
                userId: userId,
                referralCode: code,
                subscriptionStatus: subscriptionStatus
            )

            switch result.status {
            case .matched:
                // 매칭 성공 → 리딤 URL 열기
                if let referralId = result.referralId {
                    OfferRedemptionService.shared.currentReferralId = referralId
                }

                if let redeemURL = result.redeemURL {
                    Logger.referral.debug("DeepLinkHandler: 매칭 성공 → 리딤 URL 열기")

                    // Transaction 감지 시작
                    OfferRedemptionService.shared.startObservingRedemptions { offerName in
                        Logger.referral.debug("DeepLinkHandler: 리딤 감지 — \(offerName)")
                    }

                    OfferRedemptionService.shared.openRedeemURL(redeemURL)
                }

            case .selfReferral:
                // 자기 초대 → 안내 메시지
                Logger.referral.debug("DeepLinkHandler: 자기 초대 감지")
                showToast(String(localized: "error.server.selfReferral"), on: presenter)

            case .alreadyRedeemed:
                // 이미 적용됨
                Logger.referral.debug("DeepLinkHandler: 이미 적용됨")
                showToast(String(localized: "error.server.alreadyReferred"), on: presenter)

            case .invalidCode:
                Logger.referral.debug("DeepLinkHandler: 유효하지 않은 코드")
                showToast(String(localized: "error.server.invalidReferralCode"), on: presenter)

            case .noCodesAvailable:
                Logger.referral.debug("DeepLinkHandler: 코드 풀 소진")
                showToast(String(localized: "error.referralReward.unableToApply"), on: presenter)

            default:
                Logger.referral.debug("DeepLinkHandler: 예상치 못한 응답 — \(result.status.rawValue)")
            }

        } catch let error as ReferralServiceError {
            let message = error.localizedDisplayMessage
            Logger.referral.error("DeepLinkHandler: match-code 실패 — \(message)")
            showToast(message, on: presenter)
        } catch {
            Logger.referral.error("DeepLinkHandler: match-code 실패 — \(error.localizedDescription)")
            showToast(String(localized: "referral.codeInput.error.unableToConnect"), on: presenter)
        }
    }

    // MARK: - Private: 구독 상태

    /// 현재 구독 상태를 서버 API용 문자열로 반환한다.
    private func getSubscriptionStatus() async -> String {
        let store = SubscriptionStore.shared
        guard store.isProUser else { return "none" }
        return await store.referralSubscriptionStatus()
    }

    // MARK: - Private: 토스트 알림

    /// 간단한 토스트 메시지를 표시한다.
    /// 기존 앱의 ToastView가 있으면 사용하고, 없으면 UIAlertController 폴백.
    @MainActor
    private func showToast(_ message: String, on presenter: UIViewController) {
        // ToastView 사용 시도
        if let window = presenter.view.window {
            ToastView.show(message, in: window)
            return
        }

        // 폴백: UIAlertController
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: String(localized: "common.ok"), style: .default))
        presenter.present(alert, animated: true)
    }
}

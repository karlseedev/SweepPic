//
//  AdManager.swift
//  PickPhoto
//
//  AdMob 초기화 및 광고 사전 로드 관리 싱글톤
//  AdManagerProtocol 준수 (contracts/protocols.md)
//
//  역할:
//  - GADMobileAds SDK 초기화
//  - 리워드/전면/배너 광고 사전 로드 관리
//  - Plus/Grace Period 상태에 따른 광고 표시 여부 판단
//

import UIKit
import GoogleMobileAds
import AppCore
import OSLog

// MARK: - AdManagerProtocol

/// 광고 관리 프로토콜 (contracts/protocols.md)
protocol AdManagerProtocol: AnyObject {
    func configure()
    func shouldShowAds() -> Bool

    // 리워드
    var isRewardedAdReady: Bool { get }
    func preloadRewardedAd()
    func showRewardedAd(from vc: UIViewController, completion: @escaping (Bool) -> Void)

    // 전면
    var isInterstitialReady: Bool { get }
    func preloadInterstitialAd()
    func showInterstitialAd(from vc: UIViewController, completion: @escaping () -> Void)
}

// MARK: - AdManager

/// AdMob 광고 관리 싱글톤
final class AdManager: NSObject, AdManagerProtocol {

    // MARK: - Singleton

    static let shared = AdManager()

    // MARK: - Ad Unit IDs (테스트용 — 출시 시 실제 ID로 교체)

    /// 리워드 광고 테스트 ID
    static let rewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"
    /// 전면 광고 테스트 ID
    static let interstitialAdUnitID = "ca-app-pub-3940256099942544/4411468910"
    /// 배너 광고 테스트 ID
    static let bannerAdUnitID = "ca-app-pub-3940256099942544/2435281174"

    // MARK: - Properties

    /// SDK 초기화 완료 여부
    private(set) var isConfigured = false

    /// 로드된 리워드 광고
    private var rewardedAd: GADRewardedAd?

    /// 로드된 전면 광고
    private var interstitialAd: GADInterstitialAd?

    /// 리워드 광고 로드 재시도 횟수 (지수 백오프)
    private var rewardedRetryCount = 0

    /// 전면 광고 로드 재시도 횟수 (지수 백오프)
    private var interstitialRetryCount = 0

    /// 최대 재시도 횟수
    private static let maxRetryCount = 3

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Configure

    /// AdMob SDK 초기화 + 광고 사전 로드
    /// AppDelegate.didFinishLaunching에서 호출
    func configure() {
        guard !isConfigured else { return }

        GADMobileAds.sharedInstance().start { [weak self] status in
            Logger.app.debug("AdManager: SDK 초기화 완료 — \(status.adapterStatusesByClassName)")
            self?.isConfigured = true

            // 초기화 완료 후 광고 사전 로드
            self?.preloadRewardedAd()
            self?.preloadInterstitialAd()
        }
    }

    // MARK: - Should Show Ads

    /// Plus 구독자 또는 Grace Period 중이면 광고 미표시
    func shouldShowAds() -> Bool {
        // FeatureFlags 체크
        guard FeatureFlags.isAdEnabled else { return false }

        // Grace Period 중이면 광고 미표시
        if GracePeriodService.shared.isActive { return false }

        // Plus 구독자 체크는 SubscriptionStore 구현 후 연동 (Phase 6, T033)
        // 현재는 항상 광고 가능으로 처리
        return true
    }

    // MARK: - Rewarded Ad

    /// 리워드 광고 준비 완료 여부
    var isRewardedAdReady: Bool {
        rewardedAd != nil
    }

    /// 리워드 광고 사전 로드
    func preloadRewardedAd() {
        guard shouldShowAds() else { return }

        GADRewardedAd.load(withAdUnitID: Self.rewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self = self else { return }

            if let error = error {
                Logger.app.error("AdManager: 리워드 광고 로드 실패 — \(error.localizedDescription)")
                self.retryRewardedAdLoad()
                return
            }

            self.rewardedAd = ad
            self.rewardedRetryCount = 0
            Logger.app.debug("AdManager: 리워드 광고 로드 완료")
        }
    }

    /// 리워드 광고 표시
    /// - Parameters:
    ///   - vc: 표시할 ViewController
    ///   - completion: 시청 완료(true) / 취소·에러(false)
    func showRewardedAd(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        guard let ad = rewardedAd else {
            Logger.app.error("AdManager: 리워드 광고 미로드 상태")
            completion(false)
            return
        }

        ad.present(fromRootViewController: vc) { [weak self] in
            // 시청 완료 — 보상 지급
            Logger.app.debug("AdManager: 리워드 광고 시청 완료")
            completion(true)

            // 시청 완료 후 즉시 다음 광고 로드 (FR-019)
            self?.rewardedAd = nil
            self?.preloadRewardedAd()
        }
    }

    /// 리워드 광고 지수 백오프 재시도 (2→4→8초)
    private func retryRewardedAdLoad() {
        guard rewardedRetryCount < Self.maxRetryCount else {
            Logger.app.error("AdManager: 리워드 광고 최대 재시도 초과 (\(Self.maxRetryCount)회)")
            return
        }

        rewardedRetryCount += 1
        let delay = pow(2.0, Double(rewardedRetryCount)) // 2→4→8초
        Logger.app.debug("AdManager: 리워드 광고 재시도 #\(self.rewardedRetryCount) — \(delay)초 후")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.preloadRewardedAd()
        }
    }

    // MARK: - Interstitial Ad

    /// 전면 광고 준비 완료 여부
    var isInterstitialReady: Bool {
        interstitialAd != nil
    }

    /// 전면 광고 사전 로드
    func preloadInterstitialAd() {
        guard shouldShowAds() else { return }

        GADInterstitialAd.load(withAdUnitID: Self.interstitialAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self = self else { return }

            if let error = error {
                Logger.app.error("AdManager: 전면 광고 로드 실패 — \(error.localizedDescription)")
                self.retryInterstitialAdLoad()
                return
            }

            self.interstitialAd = ad
            self.interstitialRetryCount = 0
            Logger.app.debug("AdManager: 전면 광고 로드 완료")
        }
    }

    /// 전면 광고 표시
    /// - Parameters:
    ///   - vc: 표시할 ViewController
    ///   - completion: 광고 닫힘 후 콜백
    func showInterstitialAd(from vc: UIViewController, completion: @escaping () -> Void) {
        guard let ad = interstitialAd else {
            Logger.app.error("AdManager: 전면 광고 미로드 상태")
            completion()
            return
        }

        ad.present(fromRootViewController: vc)

        // 전면 광고 닫힘 감지는 delegate로 처리
        // 표시 후 즉시 다음 광고 로드
        interstitialAd = nil
        preloadInterstitialAd()

        // 전면 광고는 표시 직후 completion 호출
        // (실제로는 GADFullScreenContentDelegate로 처리해야 하지만, 기본 흐름에서는 즉시 호출)
        completion()
    }

    /// 전면 광고 지수 백오프 재시도
    private func retryInterstitialAdLoad() {
        guard interstitialRetryCount < Self.maxRetryCount else {
            Logger.app.error("AdManager: 전면 광고 최대 재시도 초과")
            return
        }

        interstitialRetryCount += 1
        let delay = pow(2.0, Double(interstitialRetryCount))
        Logger.app.debug("AdManager: 전면 광고 재시도 #\(self.interstitialRetryCount) — \(delay)초 후")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.preloadInterstitialAd()
        }
    }
}

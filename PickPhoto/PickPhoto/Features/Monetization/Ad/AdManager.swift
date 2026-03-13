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
//  - Plus 상태에 따른 광고 표시 여부 판단
//

import UIKit
import GoogleMobileAds
import AppCore
import OSLog

// MARK: - RewardedAdOutcome

/// 리워드 광고 결과 enum — no-fill/사용자 취소/보상 획득 구분
enum RewardedAdOutcome {
    /// 시청 완료 → 보상 지급
    case earned
    /// 사용자가 광고를 중간에 닫음 (보상 미지급)
    case dismissedWithoutReward
    /// 광고 표시 자체 실패 (present 에러)
    case presentFailed(Error)
    /// 광고 미로드 상태 (preload 실패 또는 미완료)
    case notLoaded
}

// MARK: - AdManagerProtocol

/// 광고 관리 프로토콜 (contracts/protocols.md)
protocol AdManagerProtocol: AnyObject {
    func configure()
    func shouldShowAds() -> Bool

    // 리워드
    var isRewardedAdReady: Bool { get }
    func preloadRewardedAd()
    func showRewardedAd(from vc: UIViewController, completion: @escaping (RewardedAdOutcome) -> Void)

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

    /// 리워드 광고 로드 중 여부 (중복 로드 방지)
    private var isLoadingRewarded = false

    /// 전면 광고 로드 중 여부
    private var isLoadingInterstitial = false

    /// 리워드 광고 시청 완료 콜백 (delegate에서 사용)
    private var rewardedCompletion: ((RewardedAdOutcome) -> Void)?

    /// 리워드 획득 여부 (reward handler → dismiss에서 판정)
    private var didEarnReward = false

    // MARK: - Initialization

    private override init() {
        super.init()
    }

    // MARK: - Configure

    /// AdMob SDK 초기화 + 광고 사전 로드
    /// AppDelegate.didFinishLaunching에서 호출
    func configure() {
        guard !isConfigured else { return }

        // 4+ 연령 등급 앱 → 전체이용가(G) 광고만 허용
        GADMobileAds.sharedInstance().requestConfiguration.maxAdContentRating = .general

        GADMobileAds.sharedInstance().start { [weak self] status in
            Logger.app.debug("AdManager: SDK 초기화 완료 — \(status.adapterStatusesByClassName)")
            self?.isConfigured = true

            // 초기화 완료 후 광고 사전 로드
            self?.preloadRewardedAd()
            self?.preloadInterstitialAd()

            // 전면 광고 사전 로드 (InterstitialAdPresenter 독립 관리)
            // GAD 콜백은 Sendable 클로저 → MainActor 싱글톤 접근 시 메인 스레드 전환 필요
            DispatchQueue.main.async {
                InterstitialAdPresenter.shared.preload()
            }
        }
    }

    // MARK: - Should Show Ads

    /// Plus 구독자이면 광고 미표시
    func shouldShowAds() -> Bool {
        // FeatureFlags 체크
        guard FeatureFlags.isAdEnabled else { return false }

        // Plus 구독자이면 광고 미표시 (FR-027, T033)
        if SubscriptionStore.shared.isPlusUser { return false }

        return true
    }

    // MARK: - Rewarded Ad

    /// 리워드 광고 준비 완료 여부
    var isRewardedAdReady: Bool {
        rewardedAd != nil
    }

    /// 리워드 광고 사전 로드 (중복 로드 방지 가드 포함)
    func preloadRewardedAd() {
        #if DEBUG
        if debugForceNoFill {
            Logger.app.debug("AdManager: DEBUG no-fill 모드 — 로드 차단")
            return
        }
        #endif
        guard shouldShowAds() else { return }
        guard !isLoadingRewarded else {
            Logger.app.debug("AdManager: 리워드 광고 이미 로드 중 — 스킵")
            return
        }
        guard rewardedAd == nil else { return }

        isLoadingRewarded = true
        GADRewardedAd.load(withAdUnitID: Self.rewardedAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingRewarded = false

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

    /// 리워드 광고 표시 (GADFullScreenContentDelegate 기반)
    /// - Parameters:
    ///   - vc: 표시할 ViewController
    ///   - completion: 광고 결과 (earned/dismissed/failed/notLoaded)
    ///
    /// 흐름:
    /// 1. reward handler → didEarnReward = true (마킹만)
    /// 2. adDidDismissFullScreenContent → earned or dismissedWithoutReward 판정 + completion 호출
    /// 3. adDidFailToPresentFullScreenContentWithError → presentFailed + completion 호출
    func showRewardedAd(from vc: UIViewController, completion: @escaping (RewardedAdOutcome) -> Void) {
        guard let ad = rewardedAd else {
            Logger.app.error("AdManager: 리워드 광고 미로드 상태")
            completion(.notLoaded)
            return
        }

        // delegate/상태 설정
        self.rewardedCompletion = completion
        self.didEarnReward = false
        ad.fullScreenContentDelegate = self

        // 광고 표시 — reward handler에서는 마킹만
        ad.present(fromRootViewController: vc) { [weak self] in
            self?.didEarnReward = true
            Logger.app.debug("AdManager: 리워드 획득 마킹")
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

    /// 전면 광고 사전 로드 (중복 로드 방지 가드 포함)
    func preloadInterstitialAd() {
        guard shouldShowAds() else { return }
        guard !isLoadingInterstitial else { return }
        guard interstitialAd == nil else { return }

        isLoadingInterstitial = true
        GADInterstitialAd.load(withAdUnitID: Self.interstitialAdUnitID, request: GADRequest()) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoadingInterstitial = false

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

    // MARK: - Debug

    #if DEBUG
    /// 디버그용: no-fill 시뮬레이션 플래그
    /// true면 preloadRewardedAd가 항상 실패 (로드 차단)
    var debugForceNoFill = false

    /// 디버그용: 로드된 리워드 광고 강제 제거 + 로드 차단 (no-fill 시뮬레이션)
    func debugClearRewardedAd() {
        rewardedAd = nil
        isLoadingRewarded = false
        debugForceNoFill = true
        Logger.app.debug("AdManager: DEBUG no-fill 모드 ON (광고 제거 + 로드 차단)")
    }

    /// 디버그용: no-fill 모드 해제
    func debugDisableNoFill() {
        debugForceNoFill = false
        preloadRewardedAd()
        Logger.app.debug("AdManager: DEBUG no-fill 모드 OFF + 재로드")
    }

    /// 디버그용: 현재 광고 상태 문자열
    var debugStatusDescription: String {
        let rewarded = isRewardedAdReady ? "Ready" : (isLoadingRewarded ? "Loading" : "Empty")
        let noFill = debugForceNoFill ? " [NO-FILL]" : ""
        return "리워드=\(rewarded)\(noFill)"
    }
    #endif

    // MARK: - Rewarded Ad Completion Helper

    /// 리워드 광고 결과 전달 + 클린업 (1회만 호출 보장)
    private func fireRewardedCompletion(_ outcome: RewardedAdOutcome) {
        let handler = rewardedCompletion
        rewardedCompletion = nil
        didEarnReward = false
        handler?(outcome)
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {

    /// 광고가 화면에서 dismiss됨 → 최종 outcome 판정
    /// Google FAQ: reward handler가 dismiss보다 먼저 호출됨
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Logger.app.debug("AdManager: 광고 dismiss — didEarnReward=\(self.didEarnReward)")

        if didEarnReward {
            fireRewardedCompletion(.earned)
        } else {
            fireRewardedCompletion(.dismissedWithoutReward)
        }

        // dismiss 후 광고 인스턴스 정리 + 다음 광고 사전 로드 (FR-019)
        rewardedAd = nil
        preloadRewardedAd()
    }

    /// 광고 표시 자체 실패 (present 에러)
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Logger.app.error("AdManager: 광고 표시 실패 — \(error.localizedDescription)")
        fireRewardedCompletion(.presentFailed(error))

        rewardedAd = nil
        preloadRewardedAd()
    }

    /// 광고가 화면에 표시됨 (로깅용)
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        Logger.app.debug("AdManager: 광고 impression 기록")
    }
}

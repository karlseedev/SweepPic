//
//  InterstitialAdPresenter.swift
//  PickPhoto
//
//  전면 광고 표시 오케스트레이터
//  AdManager의 전면 광고 로드/표시를 래핑
//
//  역할:
//  - AdManager에 로드된 전면 광고가 있으면 표시
//  - 없으면 스킵 (전면 광고는 대기 없이 바로 판단)
//  - GADFullScreenContentDelegate를 통해 dismiss 감지 후 completion 호출
//  - 스킵 가능 (FR-016): 사용자가 광고를 닫을 수 있음
//

import UIKit
import GoogleMobileAds
import AppCore
import OSLog

// MARK: - InterstitialAdPresenter

/// 전면 광고 표시 오케스트레이터
/// 로드 완료된 광고가 있으면 표시, 없으면 스킵하고 completion 호출
final class InterstitialAdPresenter: NSObject {

    // MARK: - Singleton

    static let shared = InterstitialAdPresenter()

    // MARK: - Properties

    /// 광고 dismiss 후 콜백
    private var completionHandler: (() -> Void)?

    /// 로드된 전면 광고 인스턴스 (AdManager와 별도 관리)
    private var interstitialAd: GADInterstitialAd?

    /// 광고 로드 중 여부 (중복 로드 방지)
    private var isLoading = false

    /// 로드 재시도 횟수 (지수 백오프)
    private var retryCount = 0

    /// 최대 재시도 횟수
    private static let maxRetryCount = 3

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Preload

    /// 전면 광고 사전 로드 (AdManager.shouldShowAds() 체크 포함)
    func preload() {
        guard AdManager.shared.shouldShowAds() else { return }
        guard !isLoading else { return }
        guard interstitialAd == nil else { return }

        isLoading = true
        Logger.app.debug("InterstitialAdPresenter: 전면 광고 로드 시작")

        GADInterstitialAd.load(
            withAdUnitID: AdManager.interstitialAdUnitID,
            request: GADRequest()
        ) { [weak self] ad, error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                Logger.app.error("InterstitialAdPresenter: 로드 실패 — \(error.localizedDescription)")
                self.retryLoad()
                return
            }

            self.interstitialAd = ad
            self.interstitialAd?.fullScreenContentDelegate = self
            self.retryCount = 0
            Logger.app.debug("InterstitialAdPresenter: 전면 광고 로드 완료")
        }
    }

    /// 전면 광고 준비 완료 여부
    var isReady: Bool {
        interstitialAd != nil
    }

    // MARK: - Show

    /// 전면 광고 표시
    /// - Parameters:
    ///   - vc: 표시할 ViewController
    ///   - completion: 광고 닫힌 후 또는 미표시 시 즉시 호출
    ///
    /// 로드된 광고가 없으면 스킵하고 completion 즉시 호출
    func showAd(from vc: UIViewController, completion: @escaping () -> Void) {
        // 광고 미표시 조건 체크
        guard AdManager.shared.shouldShowAds() else {
            Logger.app.debug("InterstitialAdPresenter: 광고 미표시 조건 (Plus/Grace)")
            completion()
            return
        }

        guard let ad = interstitialAd else {
            Logger.app.debug("InterstitialAdPresenter: 광고 미로드 → 스킵")
            completion()
            // 다음을 위해 로드 시작
            preload()
            return
        }

        // completion 저장 후 표시
        self.completionHandler = completion
        ad.present(fromRootViewController: vc)
        Logger.app.debug("InterstitialAdPresenter: 전면 광고 표시")
    }

    // MARK: - Retry

    /// 지수 백오프 재시도 (2→4→8초)
    private func retryLoad() {
        guard retryCount < Self.maxRetryCount else {
            Logger.app.error("InterstitialAdPresenter: 최대 재시도 초과 (\(Self.maxRetryCount)회)")
            return
        }

        retryCount += 1
        let delay = pow(2.0, Double(retryCount))
        Logger.app.debug("InterstitialAdPresenter: 재시도 #\(self.retryCount) — \(delay)초 후")

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.preload()
        }
    }

    // MARK: - Cleanup

    /// 결과 전달 + 클린업 (1회만 호출 보장)
    private func fireCompletion() {
        let handler = completionHandler
        completionHandler = nil
        handler?()
    }
}

// MARK: - GADFullScreenContentDelegate

extension InterstitialAdPresenter: GADFullScreenContentDelegate {

    /// 광고 dismiss → completion 호출 + 다음 광고 로드
    func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Logger.app.debug("InterstitialAdPresenter: 광고 dismiss")
        interstitialAd = nil
        // [BM] T055: 전면 광고 시청 후 리뷰 금지 타이밍 플래그 설정 (FR-050)
        ReviewService.shared.isAdJustShown = true
        // [BM] T057: 전면 광고 시청 완료 이벤트 (FR-056)
        AnalyticsService.shared.trackAdWatched(type: .interstitial)
        fireCompletion()

        // 다음 표시를 위해 즉시 사전 로드 (FR-016)
        preload()
    }

    /// 광고 표시 실패 → completion 호출 + 재로드
    func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Logger.app.error("InterstitialAdPresenter: 표시 실패 — \(error.localizedDescription)")
        interstitialAd = nil
        fireCompletion()
        preload()
    }

    /// 광고 impression 기록 (로깅용)
    func adDidRecordImpression(_ ad: GADFullScreenPresentingAd) {
        Logger.app.debug("InterstitialAdPresenter: impression 기록")
    }
}

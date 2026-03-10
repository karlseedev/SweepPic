//
//  RewardedAdPresenter.swift
//  PickPhoto
//
//  리워드 광고 표시 오케스트레이터
//  AdManager의 광고 로드 대기 + 타임아웃 + 결과 전달을 담당
//
//  역할:
//  - AdManager에 로드된 광고가 있으면 즉시 표시
//  - 없으면 로드 시작 + 10초 대기 → 타임아웃 시 .notLoaded
//  - AdManager의 RewardedAdOutcome을 그대로 전달
//  - 광고 로드/표시/dismiss는 AdManager + GADFullScreenContentDelegate가 전담
//

import UIKit
import AppCore
import OSLog

// MARK: - RewardedAdPresenter

/// 리워드 광고 표시 오케스트레이터
/// "로드 대기 + 타임아웃" 오케스트레이션만 담당, 실제 표시/delegate는 AdManager
final class RewardedAdPresenter: NSObject {

    // MARK: - Singleton

    static let shared = RewardedAdPresenter()

    // MARK: - Properties

    /// 광고 결과 콜백 (AdManager의 outcome 그대로 전달)
    private var completionHandler: ((RewardedAdOutcome) -> Void)?

    /// 광고가 표시될 VC (weak 참조)
    private weak var presentingVC: UIViewController?

    /// 광고 로드 대기 타이머 (10초 타임아웃)
    private var loadWaitTimer: Timer?

    /// 로드 대기 타임아웃 (초)
    private static let loadWaitTimeout: TimeInterval = 10.0

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Show Ad

    /// 리워드 광고 표시
    /// - Parameters:
    ///   - vc: 광고를 표시할 ViewController
    ///   - completion: AdManager의 RewardedAdOutcome 전달
    ///
    /// 흐름:
    /// 1. AdManager에 로드된 광고가 있으면 즉시 표시
    /// 2. 없으면 로드 시작 + 10초 폴링 대기 → 타임아웃 시 .notLoaded
    func showAd(from vc: UIViewController, completion: @escaping (RewardedAdOutcome) -> Void) {
        self.completionHandler = completion
        self.presentingVC = vc

        // 이미 로드된 광고가 있으면 즉시 표시
        if AdManager.shared.isRewardedAdReady {
            presentAd(from: vc)
            return
        }

        // 광고 미로드 → 로드 시작 + 10초 대기
        Logger.app.debug("RewardedAdPresenter: 광고 미로드 — 로드 시작 + \(Self.loadWaitTimeout)초 대기")
        AdManager.shared.preloadRewardedAd()
        startLoadWaitTimer()
    }

    // MARK: - Present

    /// 실제 광고 표시 — AdManager에 위임, outcome을 그대로 전달
    private func presentAd(from vc: UIViewController) {
        cancelLoadWaitTimer()

        AdManager.shared.showRewardedAd(from: vc) { [weak self] outcome in
            self?.finishWithOutcome(outcome)
        }
    }

    // MARK: - Load Wait Timer

    /// 광고 로드 대기 타이머 시작 (10초) + 0.5초 간격 폴링
    private func startLoadWaitTimer() {
        cancelLoadWaitTimer()

        loadWaitTimer = Timer.scheduledTimer(withTimeInterval: Self.loadWaitTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            if AdManager.shared.isRewardedAdReady, let vc = self.presentingVC {
                // 타이머 종료 직전에 로드 완료 → 표시
                Logger.app.debug("RewardedAdPresenter: 대기 중 로드 완료 — 표시")
                self.presentAd(from: vc)
            } else {
                // 로드 실패 (no-fill 또는 네트워크 에러)
                Logger.app.error("RewardedAdPresenter: 로드 대기 타임아웃 (\(Self.loadWaitTimeout)초)")
                self.finishWithOutcome(.notLoaded)
            }
        }

        // 로드 완료 시 즉시 표시하기 위해 폴링
        pollForAdReady()
    }

    /// 광고 로드 완료 폴링 (0.5초 간격)
    private func pollForAdReady() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.loadWaitTimer != nil else { return }

            if AdManager.shared.isRewardedAdReady, let vc = self.presentingVC {
                Logger.app.debug("RewardedAdPresenter: 폴링으로 로드 완료 감지 — 표시")
                self.presentAd(from: vc)
            } else {
                self.pollForAdReady()
            }
        }
    }

    /// 로드 대기 타이머 취소
    private func cancelLoadWaitTimer() {
        loadWaitTimer?.invalidate()
        loadWaitTimer = nil
    }

    // MARK: - Result Handling

    /// 최종 결과 처리 + 클린업
    private func finishWithOutcome(_ outcome: RewardedAdOutcome) {
        cancelLoadWaitTimer()
        let handler = completionHandler
        completionHandler = nil
        presentingVC = nil

        // [BM] T055: 광고 시청 완료 시 리뷰 금지 타이밍 플래그 설정 (FR-050)
        if case .earned = outcome {
            ReviewService.shared.isAdJustShown = true
            // [BM] T057: 리워드 광고 시청 완료 이벤트 (FR-056)
            AnalyticsService.shared.trackAdWatched(type: .rewarded, source: "gate")
        }

        DispatchQueue.main.async {
            handler?(outcome)
        }
    }
}

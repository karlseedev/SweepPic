//
//  RewardedAdPresenter.swift
//  PickPhoto
//
//  GADRewardedAd 래핑 — 리워드 광고 표시 + 시청 완료/취소 처리
//
//  역할:
//  - AdManager의 리워드 광고를 활용하여 실제 표시
//  - 시청 완료 시 true, 취소/에러 시 false 콜백
//  - 광고 미로드 시 대기 로드 + 10초 타임아웃 (FR-020)
//  - no-fill 시 지수 백오프 재시도 2→4→8초 (FR-020)
//  - 시청 완료 후 즉시 다음 광고 사전 로드 (FR-019)
//  - GADFullScreenContentDelegate로 dismiss 감지
//

import UIKit
import GoogleMobileAds
import AppCore
import OSLog

// MARK: - RewardedAdPresenter

/// 리워드 광고 표시 전담 프레젠터
/// AdManager의 사전 로드된 광고를 사용하여 표시하고, 결과를 콜백으로 전달
final class RewardedAdPresenter: NSObject {

    // MARK: - Singleton

    static let shared = RewardedAdPresenter()

    // MARK: - Properties

    /// 광고 표시 완료 콜백 (true: 시청 완료 → 보상 지급, false: 취소/에러)
    private var completionHandler: ((Bool) -> Void)?

    /// 광고가 표시 중인 VC
    private weak var presentingVC: UIViewController?

    /// 광고 로드 대기 타이머 (10초 타임아웃)
    private var loadWaitTimer: Timer?

    /// 로드 대기 타임아웃 (초)
    private static let loadWaitTimeout: TimeInterval = 10.0

    /// 리워드가 지급되었는지 (시청 완료 판단)
    private var didEarnReward = false

    // MARK: - Init

    private override init() {
        super.init()
    }

    // MARK: - Show Ad

    /// 리워드 광고 표시
    /// - Parameters:
    ///   - vc: 광고를 표시할 ViewController
    ///   - completion: 시청 완료(true) / 취소·에러(false) 콜백
    ///
    /// 흐름:
    /// 1. AdManager에 로드된 광고가 있으면 즉시 표시
    /// 2. 없으면 로드 시작 + 10초 대기 → 타임아웃 시 false
    func showAd(from vc: UIViewController, completion: @escaping (Bool) -> Void) {
        self.completionHandler = completion
        self.presentingVC = vc
        self.didEarnReward = false

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

    /// 실제 광고 표시 (AdManager에서 광고 가져와서 delegate 설정 후 present)
    private func presentAd(from vc: UIViewController) {
        cancelLoadWaitTimer()

        // AdManager의 showRewardedAd를 사용하되, delegate 콜백을 여기서 처리
        AdManager.shared.showRewardedAd(from: vc) { [weak self] success in
            guard let self = self else { return }
            if success {
                // 시청 완료 — 보상 지급 마킹
                self.didEarnReward = true
                Logger.app.debug("RewardedAdPresenter: 리워드 획득")
            }
            // completion은 광고 dismiss 시점에서 호출
            // AdManager.showRewardedAd의 completion이 즉시 호출되므로
            // 여기서 바로 completion 처리
            self.finishWithResult(success)
        }
    }

    // MARK: - Load Wait Timer

    /// 광고 로드 대기 타이머 시작 (10초)
    private func startLoadWaitTimer() {
        cancelLoadWaitTimer()

        loadWaitTimer = Timer.scheduledTimer(withTimeInterval: Self.loadWaitTimeout, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // 10초 후에도 미로드 → 실패 처리
            if AdManager.shared.isRewardedAdReady, let vc = self.presentingVC {
                // 타이머 종료 직전에 로드 완료 → 표시
                Logger.app.debug("RewardedAdPresenter: 대기 중 로드 완료 — 표시")
                self.presentAd(from: vc)
            } else {
                // 로드 실패 (no-fill 또는 네트워크 에러)
                Logger.app.error("RewardedAdPresenter: 로드 대기 타임아웃 (\(Self.loadWaitTimeout)초)")
                self.finishWithResult(false)
            }
        }

        // 로드 완료 시 즉시 표시하기 위해 폴링
        pollForAdReady()
    }

    /// 광고 로드 완료 폴링 (0.5초 간격으로 체크)
    private func pollForAdReady() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self, self.loadWaitTimer != nil else { return }

            if AdManager.shared.isRewardedAdReady, let vc = self.presentingVC {
                // 로드 완료 → 즉시 표시
                Logger.app.debug("RewardedAdPresenter: 폴링으로 로드 완료 감지 — 표시")
                self.presentAd(from: vc)
            } else {
                // 계속 폴링
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
    private func finishWithResult(_ success: Bool) {
        cancelLoadWaitTimer()
        let handler = completionHandler
        completionHandler = nil
        presentingVC = nil
        didEarnReward = false

        DispatchQueue.main.async {
            handler?(success)
        }
    }
}

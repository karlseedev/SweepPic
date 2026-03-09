//
//  ReviewService.swift
//  AppCore
//
//  앱 스토어 리뷰 요청 관리 (FR-049, FR-050, T054)
//
//  5개 조건 충족 시 트리거 이벤트에서 SKStoreReviewController 호출:
//  1. 설치 후 3일 경과
//  2. 3세션 이상
//  3. 30장 이상 삭제대기함 이동
//  4. 현재 버전에서 미요청
//  5. 마지막 요청 후 90일 경과
//
//  금지 타이밍 (FR-050):
//  - 광고 직후, 결제 직후, 에러 세션, 게이트 직후
//
//  디버그 테스트:
//  - Scheme > Run > Arguments에 `--review-test` 추가하면 조건 자동 충족
//

import Foundation
import StoreKit
import OSLog

// MARK: - ReviewServiceProtocol

/// 리뷰 서비스 프로토콜 (contracts/protocols.md)
public protocol ReviewServiceProtocol {
    /// 세션 카운트 증가 (앱 활성화 시)
    func recordSession()

    /// 삭제대기함 이동 카운트 누적
    func recordTrashMove(count: Int)

    /// 조건 평가 + 리뷰 요청 (조건 충족 시)
    /// - Parameters:
    ///   - scene: 리뷰 팝업 표시 대상 windowScene
    ///   - isProhibitedTiming: 금지 타이밍 여부 (FR-050)
    func evaluateAndRequestIfNeeded(from scene: UIWindowScene, isProhibitedTiming: Bool)
}

// MARK: - ReviewService

/// 앱 스토어 리뷰 요청 관리 싱글톤
/// UserDefaults 기반 ReviewTracker로 조건 추적
public final class ReviewService: ReviewServiceProtocol {

    // MARK: - Singleton

    public static let shared = ReviewService()

    // MARK: - Constants

    /// 리뷰 요청 조건 상수 (FR-049)
    private enum Threshold {
        /// 최소 설치 경과 일수
        static let minInstallDays: Int = 3
        /// 최소 세션 수
        static let minSessions: Int = 3
        /// 최소 삭제대기함 이동 수
        static let minTrashMoves: Int = 30
        /// 리뷰 요청 쿨다운 (일)
        static let cooldownDays: Int = 90
    }

    /// UserDefaults 키
    private enum Keys {
        static let sessionCount = "ReviewTracker.sessionCount"
        static let totalTrashMoveCount = "ReviewTracker.totalTrashMoveCount"
        static let lastRequestDate = "ReviewTracker.lastRequestDate"
        static let lastRequestedVersion = "ReviewTracker.lastRequestedVersion"
    }

    /// 디버그 Launch Argument
    private static let testArgument = "--review-test"

    // MARK: - Properties (UserDefaults 기반)

    /// 누적 세션 수
    private var sessionCount: Int {
        get { UserDefaults.standard.integer(forKey: Keys.sessionCount) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.sessionCount) }
    }

    /// 누적 삭제대기함 이동 수
    private var totalTrashMoveCount: Int {
        get { UserDefaults.standard.integer(forKey: Keys.totalTrashMoveCount) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.totalTrashMoveCount) }
    }

    /// 마지막 리뷰 요청일
    private var lastRequestDate: Date? {
        get { UserDefaults.standard.object(forKey: Keys.lastRequestDate) as? Date }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastRequestDate) }
    }

    /// 마지막 리뷰 요청 앱 버전
    private var lastRequestedVersion: String? {
        get { UserDefaults.standard.string(forKey: Keys.lastRequestedVersion) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.lastRequestedVersion) }
    }

    /// 현재 앱 버전
    private var currentAppVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    // MARK: - Debug Test Mode

    /// `--review-test` Launch Argument가 있으면 조건 자동 충족
    private var isTestMode: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains(Self.testArgument)
        #else
        return false
        #endif
    }

    // MARK: - Prohibited Timing Flags (FR-050)

    /// 광고 시청 직후 플래그
    /// RewardedAdPresenter / InterstitialAdPresenter에서 설정
    public var isAdJustShown = false

    /// 결제 완료 직후 플래그
    /// SubscriptionStore에서 설정
    public var isPaymentJustCompleted = false

    /// 에러 세션 플래그
    /// 심각한 오류 발생 시 설정
    public var isErrorSession = false

    /// 게이트 팝업 표시 직후 플래그
    /// TrashGateCoordinator에서 설정
    public var isGateJustShown = false

    /// 금지 타이밍 여부 (FR-050 4가지 조건 통합)
    public var isProhibitedTiming: Bool {
        isAdJustShown || isPaymentJustCompleted || isErrorSession || isGateJustShown
    }

    /// 모든 금지 타이밍 플래그 리셋
    /// 새 세션 시작 시 호출 (광고/결제/게이트 플래그는 세션 내 유효)
    public func resetProhibitedFlags() {
        isAdJustShown = false
        isPaymentJustCompleted = false
        // isErrorSession은 세션 종료까지 유지
        isGateJustShown = false
    }

    // MARK: - Init

    private init() {
        #if DEBUG
        if isTestMode {
            debugFulfillConditions()
            GracePeriodService.shared.debugExpire()
        }
        #endif
    }

    // MARK: - ReviewServiceProtocol

    /// 세션 카운트 증가 (앱 활성화 시 호출)
    public func recordSession() {
        sessionCount += 1
    }

    /// 삭제대기함 이동 카운트 누적
    /// - Parameter count: 이번에 이동한 사진 수
    public func recordTrashMove(count: Int) {
        totalTrashMoveCount += count
    }

    /// 5개 조건 + 금지 타이밍 평가 후 리뷰 요청
    /// - Parameters:
    ///   - scene: 리뷰 팝업 표시 대상 windowScene
    ///   - isProhibitedTiming: 금지 타이밍 여부 (FR-050)
    public func evaluateAndRequestIfNeeded(from scene: UIWindowScene, isProhibitedTiming: Bool) {
        // FR-050: 금지 타이밍이면 미표시
        guard !isProhibitedTiming else { return }

        // FR-049: 5개 조건 체크
        guard canRequest else { return }

        // 리뷰 요청
        Logger.app.notice("ReviewService: 리뷰 요청 — SKStoreReviewController 호출")
        SKStoreReviewController.requestReview(in: scene)

        // 요청 기록 업데이트
        lastRequestDate = Date()
        lastRequestedVersion = currentAppVersion
    }

    // MARK: - Condition Evaluation

    /// 5개 조건 모두 충족 여부 (FR-049)
    private var canRequest: Bool {
        // 조건 1: 설치 후 3일 경과
        let installDays = GracePeriodService.shared.currentDay
        guard installDays >= Threshold.minInstallDays else { return false }

        // 조건 2: 3세션 이상
        guard sessionCount >= Threshold.minSessions else { return false }

        // 조건 3: 30장 이상 삭제대기함 이동
        guard totalTrashMoveCount >= Threshold.minTrashMoves else { return false }

        // 조건 4: 현재 버전에서 미요청
        if lastRequestedVersion == currentAppVersion { return false }

        // 조건 5: 마지막 요청 후 90일 경과
        if let lastDate = lastRequestDate {
            let daysSince = Calendar.current.dateComponents(
                [.day], from: lastDate, to: Date()
            ).day ?? 0
            guard daysSince >= Threshold.cooldownDays else { return false }
        }

        return true
    }

    // MARK: - Debug

    #if DEBUG
    /// 디버그용: 리뷰 조건 강제 충족
    public func debugFulfillConditions() {
        sessionCount = Threshold.minSessions
        totalTrashMoveCount = Threshold.minTrashMoves
        lastRequestDate = nil
        lastRequestedVersion = nil
    }

    /// 디버그용: 리뷰 트래커 리셋
    public func debugReset() {
        sessionCount = 0
        totalTrashMoveCount = 0
        lastRequestDate = nil
        lastRequestedVersion = nil
    }
    #endif
}

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
//  - Console에서 `ReviewService` 필터로 전체 상태 확인 가능
//

import Foundation
import StoreKit
import OSLog

// MARK: - Logger Extension

private extension Logger {
    /// ReviewService 전용 로거 (subsystem: com.karl.PickPhoto, category: review)
    static let review = Logger(subsystem: "com.karl.PickPhoto", category: "review")
}

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
            Logger.review.notice("━━━ ReviewService 테스트 모드 활성화 (--review-test) ━━━")
            debugFulfillConditions()
            // Grace Period도 만료시켜야 설치 3일 조건 충족
            GracePeriodService.shared.debugExpire()
            logFullStatus(trigger: "INIT (테스트 모드)")
        }
        #endif
    }

    // MARK: - ReviewServiceProtocol

    /// 세션 카운트 증가 (앱 활성화 시 호출)
    public func recordSession() {
        sessionCount += 1
        Logger.review.debug("""
        ▶ recordSession() — 세션 #\(self.sessionCount) \
        [\(self.sessionCount >= Threshold.minSessions ? "충족" : "미충족") \
        \(self.sessionCount)/\(Threshold.minSessions)]
        """)
    }

    /// 삭제대기함 이동 카운트 누적
    /// - Parameter count: 이번에 이동한 사진 수
    public func recordTrashMove(count: Int) {
        totalTrashMoveCount += count
        Logger.review.debug("""
        ▶ recordTrashMove(+\(count)) — 누적 \(self.totalTrashMoveCount)장 \
        [\(self.totalTrashMoveCount >= Threshold.minTrashMoves ? "충족" : "미충족") \
        \(self.totalTrashMoveCount)/\(Threshold.minTrashMoves)]
        """)
    }

    /// 5개 조건 + 금지 타이밍 평가 후 리뷰 요청
    /// - Parameters:
    ///   - scene: 리뷰 팝업 표시 대상 windowScene
    ///   - isProhibitedTiming: 금지 타이밍 여부 (FR-050)
    public func evaluateAndRequestIfNeeded(from scene: UIWindowScene, isProhibitedTiming: Bool) {
        Logger.review.notice("━━━ evaluateAndRequestIfNeeded 호출 ━━━")

        // 전체 상태 로그 (항상)
        logFullStatus(trigger: "evaluate")

        // FR-050: 금지 타이밍이면 미표시
        guard !isProhibitedTiming else {
            logProhibitedReason()
            Logger.review.notice("⛔ 결과: 금지 타이밍으로 리뷰 요청 건너뜀")
            return
        }

        // FR-049: 5개 조건 체크 (개별 결과 로그)
        let result = evaluateAllConditions()
        guard result.allPassed else {
            Logger.review.notice("⛔ 결과: 조건 미충족 (\(result.failedConditions.joined(separator: ", ")))")
            return
        }

        // 리뷰 요청
        Logger.review.notice("✅ 결과: 모든 조건 충족 — SKStoreReviewController.requestReview() 호출!")
        SKStoreReviewController.requestReview(in: scene)

        // 요청 기록 업데이트
        lastRequestDate = Date()
        lastRequestedVersion = currentAppVersion
        Logger.review.notice("📝 요청 기록 저장 — 날짜: \(Date()), 버전: \(self.currentAppVersion)")
    }

    // MARK: - Condition Evaluation (상세 로그 포함)

    /// 5개 조건 개별 평가 결과
    private struct EvaluationResult {
        var condition1_installDays: Bool = false
        var condition2_sessions: Bool = false
        var condition3_trashMoves: Bool = false
        var condition4_versionNotRequested: Bool = false
        var condition5_cooldown: Bool = false

        var allPassed: Bool {
            condition1_installDays && condition2_sessions && condition3_trashMoves
            && condition4_versionNotRequested && condition5_cooldown
        }

        var failedConditions: [String] {
            var failed: [String] = []
            if !condition1_installDays { failed.append("설치일수") }
            if !condition2_sessions { failed.append("세션수") }
            if !condition3_trashMoves { failed.append("삭제이동수") }
            if !condition4_versionNotRequested { failed.append("버전중복") }
            if !condition5_cooldown { failed.append("90일쿨다운") }
            return failed
        }
    }

    /// 5개 조건 모두 개별 평가 + 로그
    private func evaluateAllConditions() -> EvaluationResult {
        var result = EvaluationResult()

        // 조건 1: 설치 후 3일 경과
        let installDays = GracePeriodService.shared.currentDay
        result.condition1_installDays = installDays >= Threshold.minInstallDays
        Logger.review.debug("""
        조건1 설치일수: \(installDays)일 / 최소 \(Threshold.minInstallDays)일 \
        → \(result.condition1_installDays ? "✅" : "❌")
        """)

        // 조건 2: 3세션 이상
        result.condition2_sessions = sessionCount >= Threshold.minSessions
        Logger.review.debug("""
        조건2 세션수: \(self.sessionCount)회 / 최소 \(Threshold.minSessions)회 \
        → \(result.condition2_sessions ? "✅" : "❌")
        """)

        // 조건 3: 30장 이상 삭제대기함 이동
        result.condition3_trashMoves = totalTrashMoveCount >= Threshold.minTrashMoves
        Logger.review.debug("""
        조건3 삭제이동: \(self.totalTrashMoveCount)장 / 최소 \(Threshold.minTrashMoves)장 \
        → \(result.condition3_trashMoves ? "✅" : "❌")
        """)

        // 조건 4: 현재 버전에서 미요청
        result.condition4_versionNotRequested = lastRequestedVersion != currentAppVersion
        Logger.review.debug("""
        조건4 버전미요청: 현재=\(self.currentAppVersion), \
        마지막요청=\(self.lastRequestedVersion ?? "없음") \
        → \(result.condition4_versionNotRequested ? "✅" : "❌")
        """)

        // 조건 5: 마지막 요청 후 90일 경과
        if let lastDate = lastRequestDate {
            let daysSince = Calendar.current.dateComponents(
                [.day], from: lastDate, to: Date()
            ).day ?? 0
            result.condition5_cooldown = daysSince >= Threshold.cooldownDays
            Logger.review.debug("""
            조건5 쿨다운: \(daysSince)일 경과 / 최소 \(Threshold.cooldownDays)일 \
            → \(result.condition5_cooldown ? "✅" : "❌")
            """)
        } else {
            // 요청 이력 없음 → 쿨다운 조건 자동 충족
            result.condition5_cooldown = true
            Logger.review.debug("조건5 쿨다운: 이전 요청 없음 → ✅")
        }

        return result
    }

    /// canRequest 단순 판정 (evaluateAndRequestIfNeeded 외부에서 사용)
    private var canRequest: Bool {
        let installDays = GracePeriodService.shared.currentDay
        guard installDays >= Threshold.minInstallDays else { return false }
        guard sessionCount >= Threshold.minSessions else { return false }
        guard totalTrashMoveCount >= Threshold.minTrashMoves else { return false }
        if lastRequestedVersion == currentAppVersion { return false }
        if let lastDate = lastRequestDate {
            let daysSince = Calendar.current.dateComponents(
                [.day], from: lastDate, to: Date()
            ).day ?? 0
            guard daysSince >= Threshold.cooldownDays else { return false }
        }
        return true
    }

    // MARK: - 상세 로그 헬퍼

    /// 전체 상태를 한 번에 출력
    private func logFullStatus(trigger: String) {
        let installDays = GracePeriodService.shared.currentDay
        let daysSinceLast: String = {
            guard let last = lastRequestDate else { return "없음" }
            let days = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            return "\(days)일 전"
        }()

        Logger.review.notice("""
        ┌─ ReviewService 상태 [\(trigger)]
        │ 세션수:     \(self.sessionCount)/\(Threshold.minSessions) \
        \(self.sessionCount >= Threshold.minSessions ? "✅" : "❌")
        │ 삭제이동:   \(self.totalTrashMoveCount)/\(Threshold.minTrashMoves) \
        \(self.totalTrashMoveCount >= Threshold.minTrashMoves ? "✅" : "❌")
        │ 설치일수:   \(installDays)/\(Threshold.minInstallDays) \
        \(installDays >= Threshold.minInstallDays ? "✅" : "❌")
        │ 앱버전:     \(self.currentAppVersion), 마지막요청: \(self.lastRequestedVersion ?? "없음") \
        \(self.lastRequestedVersion != self.currentAppVersion ? "✅" : "❌")
        │ 쿨다운:     마지막요청=\(daysSinceLast) \
        \(self.canRequestCooldown ? "✅" : "❌")
        │ 금지타이밍:  광고=\(self.isAdJustShown) 결제=\(self.isPaymentJustCompleted) \
        에러=\(self.isErrorSession) 게이트=\(self.isGateJustShown)
        │ 종합판정:   \(self.canRequest ? "요청 가능 ✅" : "요청 불가 ❌")
        └───────────────────────────────
        """)
    }

    /// 쿨다운 조건만 별도 판정 (logFullStatus용)
    private var canRequestCooldown: Bool {
        guard let lastDate = lastRequestDate else { return true }
        let daysSince = Calendar.current.dateComponents(
            [.day], from: lastDate, to: Date()
        ).day ?? 0
        return daysSince >= Threshold.cooldownDays
    }

    /// 금지 타이밍 사유 출력
    private func logProhibitedReason() {
        var reasons: [String] = []
        if isAdJustShown { reasons.append("광고 직후") }
        if isPaymentJustCompleted { reasons.append("결제 직후") }
        if isErrorSession { reasons.append("에러 세션") }
        if isGateJustShown { reasons.append("게이트 직후") }
        Logger.review.notice("⚠️ 금지 타이밍 사유: \(reasons.joined(separator: ", "))")
    }

    // MARK: - Debug

    #if DEBUG
    /// 디버그용: 리뷰 조건 강제 충족
    public func debugFulfillConditions() {
        sessionCount = Threshold.minSessions
        totalTrashMoveCount = Threshold.minTrashMoves
        lastRequestDate = nil
        lastRequestedVersion = nil
        Logger.review.notice("🔧 debugFulfillConditions — 조건 강제 충족")
    }

    /// 디버그용: 리뷰 트래커 리셋
    public func debugReset() {
        sessionCount = 0
        totalTrashMoveCount = 0
        lastRequestDate = nil
        lastRequestedVersion = nil
        Logger.review.notice("🔧 debugReset — 트래커 초기화")
    }

    /// 디버그용: 현재 상태 요약 문자열
    public var debugSummary: String {
        """
        ReviewTracker:
          sessions: \(sessionCount)/\(Threshold.minSessions)
          trashMoves: \(totalTrashMoveCount)/\(Threshold.minTrashMoves)
          installDays: \(GracePeriodService.shared.currentDay)/\(Threshold.minInstallDays)
          lastRequestDate: \(lastRequestDate?.description ?? "nil")
          lastRequestedVersion: \(lastRequestedVersion ?? "nil")
          currentVersion: \(currentAppVersion)
          prohibited: ad=\(isAdJustShown) pay=\(isPaymentJustCompleted) err=\(isErrorSession) gate=\(isGateJustShown)
          canRequest: \(canRequest)
        """
    }
    #endif
}

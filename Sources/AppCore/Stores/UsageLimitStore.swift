//
//  UsageLimitStore.swift
//  AppCore
//
//  일일 삭제 한도 상태 관리 싱글톤
//  Keychain 기반 영속화 + 인메모리 캐시로 빠른 접근 제공
//  UsageLimitStoreProtocol 준수 (contracts/protocols.md)
//
//  저장: Keychain (앱 삭제에도 유지)
//  읽기: 인메모리 캐시에서 (성능)
//  쓰기: 인메모리 갱신 + Keychain 즉시 반영
//

import Foundation
import OSLog

// MARK: - UsageLimitStoreProtocol

/// 한도 상태 관리 프로토콜 (contracts/protocols.md)
public protocol UsageLimitStoreProtocol: AnyObject {
    // 읽기
    var remainingFreeDeletes: Int { get }
    var remainingRewards: Int { get }
    var lifetimeFreeGrantUsed: Bool { get }

    // 판단
    func canDeleteWithinLimit(count: Int) -> Bool
    func adsNeeded(for count: Int) -> Int

    // 기록
    func recordDelete(count: Int)
    func recordReward()
    func recordLifetimeFreeGrant()

    // 리셋
    func resetIfNewDay(serverDate: String?)
}

// MARK: - UsageLimitStore

/// 일일 삭제 한도 관리 싱글톤
/// Keychain에 UsageLimit을 JSON으로 저장, 인메모리 캐시로 빠른 접근
public final class UsageLimitStore: UsageLimitStoreProtocol {

    // MARK: - Singleton

    public static let shared = UsageLimitStore()

    // MARK: - Constants

    /// Keychain 저장 키
    private static let keychainKey = "dailyUsage"

    // MARK: - Properties

    /// 인메모리 캐시 (Keychain에서 로드 또는 새로 생성)
    private var usageLimit: UsageLimit

    /// 상태 변경 시 콜백 (UI 갱신용)
    public var onUpdate: (() -> Void)?

    // MARK: - Initialization

    private init() {
        // Keychain에서 로드 시도
        if let loaded = KeychainHelper.loadCodable(key: Self.keychainKey, type: UsageLimit.self) {
            self.usageLimit = loaded
            Logger.app.debug("UsageLimitStore: Keychain에서 로드 완료 — 삭제 \(loaded.dailyDeleteCount), 리워드 \(loaded.dailyRewardCount)")
        } else {
            // Keychain 접근 실패 또는 첫 실행 → 기본값 (한도 내 간주, FR-051c)
            self.usageLimit = UsageLimit()
            Logger.app.debug("UsageLimitStore: 새로 생성 (첫 실행 또는 Keychain 접근 실패)")
        }
    }

    // MARK: - UsageLimitStoreProtocol — 읽기

    /// 남은 기본 무료 삭제 가능 장수
    public var remainingFreeDeletes: Int {
        usageLimit.remainingFreeDeletes
    }

    /// 남은 리워드 광고 시청 가능 횟수
    public var remainingRewards: Int {
        usageLimit.remainingRewards
    }

    /// 생애 최초 no-fill 무료 사용 여부
    public var lifetimeFreeGrantUsed: Bool {
        usageLimit.lifetimeFreeGrantUsed
    }

    /// 오늘의 일일 삭제 수 (기본 한도 내)
    public var dailyDeleteCount: Int {
        usageLimit.dailyDeleteCount
    }

    /// 오늘의 리워드 시청 횟수
    public var dailyRewardCount: Int {
        usageLimit.dailyRewardCount
    }

    /// 현재 일일 총 삭제 가능 용량
    public var totalDailyCapacity: Int {
        usageLimit.totalDailyCapacity
    }

    /// Grace Period 사용 이력 (Keychain에서)
    public var hasUsedGracePeriod: Bool {
        usageLimit.hasUsedGracePeriod
    }

    // MARK: - UsageLimitStoreProtocol — 판단

    /// 주어진 장수가 현재 한도(기본 + 리워드 확장 가능) 내에서 삭제 가능한지
    public func canDeleteWithinLimit(count: Int) -> Bool {
        // 판단 전 자동 리셋 체크 (앱이 포그라운드에서 자정을 넘긴 경우 대비)
        resetIfNewDay(serverDate: nil)
        return usageLimit.canDeleteWithinLimit(count: count)
    }

    /// 한도 초과분을 커버하기 위해 필요한 광고 횟수
    public func adsNeeded(for count: Int) -> Int {
        usageLimit.adsNeeded(for: count)
    }

    // MARK: - UsageLimitStoreProtocol — 기록

    /// 삭제 기록 (기본 한도 내 삭제 시)
    /// - Parameter count: 삭제한 장수
    public func recordDelete(count: Int) {
        usageLimit.dailyDeleteCount += count
        persistAndNotify()
        Logger.app.debug("UsageLimitStore: recordDelete(\(count)) → 총 \(self.usageLimit.dailyDeleteCount)/\(UsageLimit.dailyFreeLimit)")
    }

    /// 리워드 광고 시청 기록
    /// 리워드 +10장 확장은 이 메서드 호출로 반영됨
    public func recordReward() {
        usageLimit.dailyRewardCount += 1
        persistAndNotify()
        Logger.app.debug("UsageLimitStore: recordReward() → 총 \(self.usageLimit.dailyRewardCount)/\(UsageLimit.maxDailyRewards)")
    }

    /// 생애 최초 no-fill 무료 +10장 기록
    public func recordLifetimeFreeGrant() {
        usageLimit.lifetimeFreeGrantUsed = true
        persistAndNotify()
        Logger.app.debug("UsageLimitStore: recordLifetimeFreeGrant()")
    }

    /// Grace Period 사용 기록 (GracePeriodService에서 호출)
    public func markGracePeriodUsed() {
        usageLimit.hasUsedGracePeriod = true
        persistAndNotify()
    }

    // MARK: - UsageLimitStoreProtocol — 리셋

    /// 새로운 날이면 일일 한도 리셋
    /// - Parameter serverDate: 서버 날짜 문자열 (nil이면 로컬 시간 사용)
    ///
    /// 리셋 조건:
    /// 1. serverDate가 있으면 서버 시간 기준으로 날짜 비교
    /// 2. serverDate가 없으면 로컬 시간 기준 (오프라인 시)
    /// 3. 시계 되돌리기 감지: 로컬 날짜 < lastServerDate면 리셋 거부
    public func resetIfNewDay(serverDate: String?) {
        let today: String

        if let serverDate = serverDate {
            // 온라인: 서버 시간 기준
            today = serverDate
            usageLimit.lastServerDate = serverDate
        } else if let lastServer = usageLimit.lastServerDate {
            // 오프라인: 시계 되돌리기 감지
            let localToday = UsageLimit.todayString()
            if localToday < lastServer {
                // 시계가 서버 시간보다 과거 → 리셋 거부 (FR-052)
                Logger.app.debug("UsageLimitStore: 시계 되돌리기 감지 — 리셋 거부")
                return
            }
            today = localToday
        } else {
            // 서버 확인 이력 없음: 로컬 시간 사용
            today = UsageLimit.todayString()
        }

        // 날짜가 같으면 리셋 불필요
        guard today != usageLimit.lastResetDate else { return }

        // 새로운 날 → 리셋
        usageLimit.dailyDeleteCount = 0
        usageLimit.dailyRewardCount = 0
        usageLimit.lastResetDate = today
        persistAndNotify()
        Logger.app.debug("UsageLimitStore: 일일 한도 리셋 (date: \(today))")
    }

    // MARK: - Private

    /// 인메모리 상태를 Keychain에 저장 + UI 갱신 콜백 호출
    private func persistAndNotify() {
        KeychainHelper.saveCodable(key: Self.keychainKey, value: usageLimit)
        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?()
        }
    }

    // MARK: - Debug

    #if DEBUG
    /// 디버그용: 날짜 변경을 시뮬레이션하여 실제 리셋 경로 검증
    /// lastResetDate를 어제로 변경 → resetIfNewDay()가 새 날로 인식하여 리셋
    public func debugReset() {
        usageLimit.lastResetDate = "1970-01-01"
        persistAndNotify()
        resetIfNewDay(serverDate: nil)
        Logger.app.debug("UsageLimitStore: DEBUG 날짜 리셋 시뮬레이션 완료")
    }

    /// 디버그용: 기본 한도 모두 소진 상태로 설정
    public func debugExhaustFreeLimit() {
        usageLimit.dailyDeleteCount = UsageLimit.dailyFreeLimit
        persistAndNotify()
    }

    /// 디버그용: 모든 리워드까지 소진 상태로 설정
    public func debugExhaustAll() {
        usageLimit.dailyDeleteCount = UsageLimit.dailyFreeLimit
        usageLimit.dailyRewardCount = UsageLimit.maxDailyRewards
        persistAndNotify()
    }
    #endif
}

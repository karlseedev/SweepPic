//
//  UsageLimit.swift
//  AppCore
//
//  일일 삭제 한도 및 광고 시청 상태를 추적하는 모델
//  Keychain에 저장되어 앱 삭제/재설치에도 유지됨
//
//  사용: UsageLimitStore에서 이 모델을 Keychain에 영속화
//

import Foundation

// MARK: - UsageLimit

/// 일일 삭제 한도 상태를 나타내는 Codable 모델
/// Keychain에 JSON으로 저장되어 앱 삭제에도 유지됨
public struct UsageLimit: Codable, Sendable {

    // MARK: - Stored Properties

    /// 오늘 기본 한도 내에서 삭제한 장수
    public var dailyDeleteCount: Int

    /// 오늘 리워드 광고 시청 횟수 (최대 2)
    public var dailyRewardCount: Int

    /// 마지막 리셋 날짜 (yyyy-MM-dd, 서버 시간 기준)
    public var lastResetDate: String

    /// 마지막 확인된 서버 날짜 (시계 조작 감지용)
    public var lastServerDate: String?

    /// 생애 최초 no-fill 무료 +10장 사용 여부
    public var lifetimeFreeGrantUsed: Bool

    /// Grace Period 사용 여부 (재설치 악용 방지, FR-051a)
    public var hasUsedGracePeriod: Bool

    // MARK: - Constants

    /// 일일 기본 무료 삭제 한도 (A/B 테스트 대비 변경 가능)
    public static let dailyFreeLimit: Int = 10

    /// 리워드 광고 1회 시청 시 추가 삭제 가능 장수
    public static let rewardBonusPerAd: Int = 10

    /// 일일 최대 리워드 광고 시청 횟수
    public static let maxDailyRewards: Int = 2

    /// 일일 최대 삭제 가능 장수 (기본 + 리워드 최대)
    /// = dailyFreeLimit + (rewardBonusPerAd × maxDailyRewards) = 30
    public static let maxDailyTotal: Int = dailyFreeLimit + (rewardBonusPerAd * maxDailyRewards)

    // MARK: - Computed Properties

    /// 남은 삭제 가능 장수 (기본 한도 + 리워드 보너스 - 이미 삭제한 수)
    public var remainingFreeDeletes: Int {
        max(0, totalDailyCapacity - dailyDeleteCount)
    }

    /// 남은 리워드 광고 시청 가능 횟수
    public var remainingRewards: Int {
        max(0, Self.maxDailyRewards - dailyRewardCount)
    }

    /// 현재 일일 총 삭제 가능 용량 (기본 + 이미 시청한 리워드 보너스)
    public var totalDailyCapacity: Int {
        Self.dailyFreeLimit + (dailyRewardCount * Self.rewardBonusPerAd)
    }

    /// 주어진 장수가 현재 남은 한도(기본 + 리워드 가능 확장) 내에서 삭제 가능한지 판단
    /// - Parameter count: 삭제하려는 장수
    /// - Returns: 기본 한도 + 리워드로 확장 가능한 총량 내에서 삭제 가능하면 true
    public func canDeleteWithinLimit(count: Int) -> Bool {
        let maxPossible = remainingFreeDeletes + (remainingRewards * Self.rewardBonusPerAd)
        return count <= maxPossible
    }

    /// 한도 초과분을 커버하기 위해 필요한 광고 횟수
    /// - Parameter count: 삭제하려는 총 장수
    /// - Returns: 필요한 광고 시청 횟수 (0이면 기본 한도 내, -1이면 광고로도 부족)
    public func adsNeeded(for count: Int) -> Int {
        // 기본 한도 내면 광고 불필요
        if count <= remainingFreeDeletes {
            return 0
        }

        // 기본 한도 초과분
        let excess = count - remainingFreeDeletes

        // 필요한 광고 수 = ceil(초과분 / 광고당 보너스)
        let needed = (excess + Self.rewardBonusPerAd - 1) / Self.rewardBonusPerAd

        // 남은 리워드 횟수 내에서 가능한지
        if needed > remainingRewards {
            return -1 // 광고로도 부족 (Pro만 가능)
        }

        return needed
    }

    // MARK: - Initialization

    /// 기본 초기 상태 (리셋 상태)
    /// - Parameter todayDateString: 오늘 날짜 문자열 (yyyy-MM-dd)
    public init(todayDateString: String = Self.todayString()) {
        self.dailyDeleteCount = 0
        self.dailyRewardCount = 0
        self.lastResetDate = todayDateString
        self.lastServerDate = nil
        self.lifetimeFreeGrantUsed = false
        self.hasUsedGracePeriod = false
    }

    // MARK: - Date Helpers

    /// 현재 날짜를 yyyy-MM-dd 형식 문자열로 반환
    public static func todayString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.timeZone = TimeZone.current
        return formatter.string(from: Date())
    }

    /// 날짜 문자열 비교 — 다른 날인지 확인
    /// - Parameters:
    ///   - dateString: 비교 대상 날짜 문자열 (yyyy-MM-dd)
    ///   - referenceDate: 기준 날짜 문자열 (nil이면 오늘)
    /// - Returns: 다른 날이면 true
    public static func isNewDay(_ dateString: String, comparedTo referenceDate: String? = nil) -> Bool {
        let reference = referenceDate ?? todayString()
        return dateString != reference
    }
}

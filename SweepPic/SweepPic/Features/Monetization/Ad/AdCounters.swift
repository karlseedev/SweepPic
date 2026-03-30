//
//  AdCounters.swift
//  SweepPic
//
//  전면 광고 표시 빈도 카운터 (인메모리)
//  각 트리거별 독립 카운터 관리
//
//  역할:
//  - 유사사진 삭제 완료 / 자동정리 완료 각각 독립 카운터
//  - 짝수 회차(2, 4, 6...)에만 전면 광고 표시 (FR-015)
//  - 앱 재시작 시 리셋 (인메모리)
//  - Pro 시 카운터 미증가
//

import Foundation
import AppCore
import OSLog

// MARK: - AdTrigger

/// 전면 광고 트리거 종류
enum AdTrigger {
    /// 유사사진 비교 화면에서 삭제 완료
    case similarPhotoDelete
    /// 자동정리 미리보기에서 확인 완료
    case autoCleanupComplete
}

// MARK: - AdCounters

/// 전면 광고 표시 빈도 카운터 (인메모리 싱글톤)
/// 각 트리거별 독립 카운터를 유지하며, 짝수 회차에만 광고 표시 허용
final class AdCounters {

    // MARK: - Singleton

    static let shared = AdCounters()

    // MARK: - Properties

    /// 트리거별 카운터 (인메모리, 앱 재시작 시 리셋)
    private var counters: [AdTrigger: Int] = [:]

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 트리거 이벤트 발생 시 카운터 증가 + 광고 표시 여부 반환
    /// - Parameter trigger: 발생한 트리거
    /// - Returns: true면 이번에 전면 광고를 표시해야 함 (짝수 회차)
    func incrementAndShouldShowAd(for trigger: AdTrigger) -> Bool {
        // Pro 시 광고 미표시 → 카운터도 증가하지 않음
        guard AdManager.shared.shouldShowAds() else {
            Logger.app.debug("AdCounters: 광고 미표시 조건 → 카운터 미증가")
            return false
        }

        let current = (counters[trigger] ?? 0) + 1
        counters[trigger] = current

        // 짝수 회차에만 광고 표시 (FR-015: 2, 4, 6, ...)
        let shouldShow = current % 2 == 0
        Logger.app.debug("AdCounters: \(String(describing: trigger)) #\(current) → 광고 \(shouldShow ? "표시" : "미표시")")

        return shouldShow
    }

    /// 특정 트리거의 현재 카운터 값 조회 (디버그용)
    func count(for trigger: AdTrigger) -> Int {
        counters[trigger] ?? 0
    }

    /// 모든 카운터 리셋 (디버그용)
    func resetAll() {
        counters.removeAll()
        Logger.app.debug("AdCounters: 모든 카운터 리셋")
    }
}

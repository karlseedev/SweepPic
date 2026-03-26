// AnalyticsService+GridPerformance.swift
// 이벤트 8(그리드 성능) 세션 누적 카운터
//
// - 회색 셀(grayShown): 사용자에게 이미지 없는 셀이 노출된 횟수
// - 참조: docs/db/260212db-Archi.md 섹션 5.4, 4.2

import Foundation

extension AnalyticsService {

    // MARK: - 이벤트 8: 그리드 성능

    /// 회색 셀 노출 카운터 증가
    /// - 호출 지점: PhotoCell.incrementGrayShown() (willDisplay 시 이미지 없으면 호출)
    func countGrayShown() {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.gridPerformance.grayShown += 1
        }
    }
}

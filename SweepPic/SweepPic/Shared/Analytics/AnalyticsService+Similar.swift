// AnalyticsService+Similar.swift
// 이벤트 5-1(유사 분석 누적) + 이벤트 5-2(유사 그룹 행동 즉시 전송)
//
// - 5-1: 세션 누적 → 세션 종료 시 요약
// - 5-2: 그룹별 즉시 전송
// - 참조: docs/db/260212db-Archi.md 섹션 5.3, 5.4

import Foundation

extension AnalyticsService {

    // MARK: - 이벤트 5-1: 유사 분석 (세션 누적)

    /// 유사 분석 완료 카운터 증가
    /// - Parameter groups: 발견된 그룹 수
    /// - Parameter duration: 분석 소요 시간 (초)
    func countSimilarAnalysisCompleted(groups: Int, duration: TimeInterval) {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.similarAnalysis.completedCount += 1
            self.counters.similarAnalysis.totalGroups += groups
            self.counters.similarAnalysis.totalDuration += duration
        }
    }

    /// 유사 분석 취소 카운터 증가
    func countSimilarAnalysisCancelled() {
        guard !shouldSkip() else { return }
        queue.async(flags: .barrier) {
            self.counters.similarAnalysis.cancelledCount += 1
        }
    }

    // MARK: - 이벤트 5-2: 유사 그룹 행동 (즉시 전송)

    /// 유사 그룹 닫기 시그널 전송
    /// - Parameter totalCount: 그룹 전체 장수
    /// - Parameter deletedCount: 삭제 장수 (0이면 삭제 없이 닫기)
    func trackSimilarGroupClosed(totalCount: Int, deletedCount: Int) {
        guard !shouldSkip() else { return }
        sendEvent("similar.groupClosed", parameters: [
            "totalCount":   String(totalCount),
            "deletedCount": String(deletedCount),
        ])
    }
}

//
//  SimilarityAnalysisState.swift
//  SweepPic
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 SweepPic. All rights reserved.
//
//  Description:
//  사진별 유사도 분석 상태를 추적하는 열거형입니다.
//  각 사진은 notAnalyzed → analyzing → analyzed 순서로 상태가 전환됩니다.
//
//  State Flow:
//  notAnalyzed ──[그리드 스크롤 멈춤]──▶ analyzing ──[완료]──▶ analyzed
//       ▲                                                          │
//       └───────────[캐시 eviction]────────────────────────────────┘
//

import Foundation

/// 사진별 유사도 분석 상태를 나타내는 열거형
///
/// 각 사진은 분석 범위에 들어오면 analyzing 상태가 되고,
/// 분석이 완료되면 analyzed 상태로 전환됩니다.
/// 캐시에서 제거(eviction)되면 다시 notAnalyzed 상태로 돌아갑니다.
enum SimilarityAnalysisState: Equatable, Sendable {

    // MARK: - Cases

    /// 분석되지 않은 상태 (분석 범위 밖)
    /// - 그리드에서 화면에 보이지 않거나 캐시에서 제거된 사진
    case notAnalyzed

    /// 분석 진행 중인 상태
    /// - Feature Print 생성 또는 얼굴 감지가 진행 중
    case analyzing

    /// 분석 완료 상태
    /// - Parameters:
    ///   - inGroup: 유사 사진 그룹에 속해있는지 여부
    ///   - groupID: 속한 그룹의 고유 식별자 (inGroup이 true일 때만 non-nil)
    case analyzed(inGroup: Bool, groupID: String?)

    // MARK: - Computed Properties

    /// 분석이 완료되었는지 여부
    /// - analyzed 상태일 때 true
    var isAnalyzed: Bool {
        if case .analyzed = self {
            return true
        }
        return false
    }

    /// 분석 중인지 여부
    /// - analyzing 상태일 때 true
    var isAnalyzing: Bool {
        if case .analyzing = self {
            return true
        }
        return false
    }

    /// 유사 사진 그룹에 속해있는지 여부
    /// - analyzed(inGroup: true, _) 상태일 때 true
    var isInGroup: Bool {
        if case .analyzed(inGroup: true, _) = self {
            return true
        }
        return false
    }

    /// 속한 그룹의 ID (그룹에 속해있지 않으면 nil)
    var groupID: String? {
        if case .analyzed(_, let groupID) = self {
            return groupID
        }
        return nil
    }

    // MARK: - State Transition Validation

    /// 특정 상태로 전환이 유효한지 검증합니다.
    ///
    /// - Parameter newState: 전환하려는 새로운 상태
    /// - Returns: 전환이 유효하면 true, 그렇지 않으면 false
    ///
    /// 유효한 상태 전환:
    /// - notAnalyzed → analyzing (분석 시작)
    /// - analyzing → analyzed (분석 완료)
    /// - analyzed → notAnalyzed (캐시 eviction)
    /// - analyzed → analyzing (재분석 - 그룹 변경 시)
    /// - any → notAnalyzed (강제 리셋)
    func canTransition(to newState: SimilarityAnalysisState) -> Bool {
        switch (self, newState) {
        // 분석 시작: notAnalyzed → analyzing
        case (.notAnalyzed, .analyzing):
            return true

        // 분석 완료: analyzing → analyzed
        case (.analyzing, .analyzed):
            return true

        // 캐시 eviction: analyzed → notAnalyzed
        case (.analyzed, .notAnalyzed):
            return true

        // 재분석: analyzed → analyzing
        case (.analyzed, .analyzing):
            return true

        // 분석 취소: analyzing → notAnalyzed
        case (.analyzing, .notAnalyzed):
            return true

        // 그 외는 무효한 전환
        default:
            return false
        }
    }

    // MARK: - Equatable

    /// 두 상태가 같은지 비교합니다.
    static func == (lhs: SimilarityAnalysisState, rhs: SimilarityAnalysisState) -> Bool {
        switch (lhs, rhs) {
        case (.notAnalyzed, .notAnalyzed):
            return true
        case (.analyzing, .analyzing):
            return true
        case let (.analyzed(lhsInGroup, lhsGroupID), .analyzed(rhsInGroup, rhsGroupID)):
            return lhsInGroup == rhsInGroup && lhsGroupID == rhsGroupID
        default:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension SimilarityAnalysisState: CustomStringConvertible {
    /// 상태의 문자열 표현
    var description: String {
        switch self {
        case .notAnalyzed:
            return "notAnalyzed"
        case .analyzing:
            return "analyzing"
        case .analyzed(let inGroup, let groupID):
            if inGroup, let id = groupID {
                return "analyzed(inGroup: true, groupID: \(id))"
            } else {
                return "analyzed(inGroup: false)"
            }
        }
    }
}

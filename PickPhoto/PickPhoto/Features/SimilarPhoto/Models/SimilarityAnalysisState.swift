// SimilarityAnalysisState.swift
// 사진별 유사도 분석 상태 추적
//
// T002: SimilarityAnalysisState 열거형 생성
// - notAnalyzed: 분석 범위 밖
// - analyzing: 분석 진행 중
// - analyzed: 분석 완료 (그룹 포함 여부 및 그룹 ID)

import Foundation

/// 사진별 유사도 분석 상태
/// 각 PHAsset의 분석 진행 상태를 추적
///
/// 상태 전이:
/// ```
/// notAnalyzed ──[그리드 스크롤 멈춤]──▶ analyzing ──[완료]──▶ analyzed
///      ▲                                                          │
///      └───────────[캐시 eviction]────────────────────────────────┘
/// ```
enum SimilarityAnalysisState: Equatable {

    // MARK: - Cases

    /// 분석 범위 밖 (아직 분석되지 않음)
    /// - 그리드 스크롤 범위 밖의 사진
    /// - 캐시에서 eviction된 사진
    case notAnalyzed

    /// 분석 진행 중
    /// - Vision API 요청 대기 또는 처리 중
    /// - UI에 로딩 인디케이터 표시 가능
    case analyzing

    /// 분석 완료
    /// - Parameters:
    ///   - inGroup: 유사 사진 그룹에 포함 여부
    ///   - groupID: 소속 그룹 ID (inGroup이 true일 때만 non-nil)
    case analyzed(inGroup: Bool, groupID: String?)

    // MARK: - Computed Properties

    /// 분석 완료 여부
    var isAnalyzed: Bool {
        if case .analyzed = self {
            return true
        }
        return false
    }

    /// 분석 진행 중 여부
    var isAnalyzing: Bool {
        if case .analyzing = self {
            return true
        }
        return false
    }

    /// 그룹 포함 여부 (분석 완료 상태에서만 유효)
    var isInGroup: Bool {
        if case let .analyzed(inGroup, _) = self {
            return inGroup
        }
        return false
    }

    /// 소속 그룹 ID (그룹에 포함된 경우에만 non-nil)
    var groupID: String? {
        if case let .analyzed(_, groupID) = self {
            return groupID
        }
        return nil
    }

    // MARK: - Validation

    /// 상태 유효성 검사
    /// - analyzed(inGroup: true)일 때 groupID가 non-nil인지 확인
    /// - analyzed(inGroup: false)일 때 groupID가 nil인지 확인
    var isValid: Bool {
        switch self {
        case .notAnalyzed, .analyzing:
            return true
        case let .analyzed(inGroup, groupID):
            if inGroup {
                return groupID != nil
            } else {
                return groupID == nil
            }
        }
    }
}

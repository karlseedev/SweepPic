// PreviewCleanupEventData.swift
// 미리보기 정리(이벤트 7-2) 분석 데이터 모델 및 관련 enum
//
// - 미리보기 화면에서 빠져나오는 순간 AnalyticsService에 전달
// - 참조: docs/db/260212db-Archi.md 섹션 5.5

import Foundation

// MARK: - PreviewReachedStage

/// 미리보기 도달 단계 (이벤트 7-2)
/// - 사용자가 미리보기 흐름에서 어디까지 진행했는지 추적
enum PreviewReachedStage: String {
    /// 분석까지만 도달
    case analyzed    = "analyzed"
    /// 그리드 표시까지 도달
    case gridShown   = "gridShown"
    /// 최종 행동까지 도달
    case finalAction = "finalAction"
}

// MARK: - PreviewFinalAction

/// 미리보기 최종 행동
enum PreviewFinalAction: String {
    /// 삭제대기함 이동
    case moveToTrash = "moveToTrash"
    /// 닫기
    case close       = "close"
}

// MARK: - PreviewMaxStage

/// 미리보기 최종 도달 단계
/// - 기존 PreviewStage enum의 분석 전용 매핑
enum PreviewMaxStage: String {
    /// 매우 낮은 품질 단계
    case light    = "light"
    /// 약간 낮은 품질 단계
    case standard = "standard"
}

// MARK: - PreviewCleanupEventData

/// 미리보기 정리의 분석 데이터
/// - 미리보기 화면에서 빠져나오는 순간 AnalyticsService에 전달
/// - 시그널: cleanup.previewCompleted
struct PreviewCleanupEventData {
    /// 도달 단계
    let reachedStage: PreviewReachedStage
    /// 분석에서 찾은 저품질 사진 수
    let foundCount: Int
    /// 분석 소요 시간 (초)
    let durationSec: Double
    /// 최대 도달 단계 (expand 시 갱신, collapse해도 유지)
    let maxStageReached: PreviewMaxStage
    /// "더 보기" 횟수
    let expandCount: Int
    /// "제외하기" (단계 축소) 횟수
    let collapseCount: Int
    /// 뷰어 제외 횟수
    let excludeCount: Int
    /// 뷰어 열람 횟수
    let viewerOpenCount: Int
    /// 최종 행동 (삭제대기함 이동 or 닫기)
    let finalAction: PreviewFinalAction
    /// 실제 삭제대기함 이동 수 (닫기면 0)
    let movedCount: Int
}

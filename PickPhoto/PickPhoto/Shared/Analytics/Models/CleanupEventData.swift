// CleanupEventData.swift
// 기존 정리(이벤트 7-1) 분석 데이터 모델 및 관련 enum
//
// - 정리 흐름에서 빠져나오는 순간 AnalyticsService에 전달
// - 참조: docs/db/260212db-Archi.md 섹션 5.5

import Foundation

// MARK: - CleanupReachedStage

/// 정리 도달 단계 (이벤트 7-1)
/// - 사용자가 정리 흐름에서 어디까지 진행했는지 추적
enum CleanupReachedStage: String {
    /// 정리 버튼만 탭
    case buttonTapped     = "buttonTapped"
    /// 휴지통 경고에서 이탈
    case trashWarningExit = "trashWarningExit"
    /// 방식 선택까지 도달
    case methodSelected   = "methodSelected"
    /// 정리 완료
    case cleanupDone      = "cleanupDone"
    /// 결과 행동까지 도달
    case resultAction     = "resultAction"
}

// MARK: - CleanupMethodType

/// 정리 방식 (분석용 문자열)
/// - 기존 CleanupMethod enum의 분석 전용 매핑
enum CleanupMethodType: String {
    /// 최신순 정리
    case fromLatest        = "fromLatest"
    /// 이어서 정리
    case continueFromLast  = "continueFromLast"
    /// 연도별 정리
    case byYear            = "byYear"
}

// MARK: - CleanupResultType

/// 정리 결과 타입
enum CleanupResultType: String {
    /// N장 이동 완료
    case completed = "completed"
    /// 0장 발견 (저품질 사진 없음)
    case noneFound = "noneFound"
    /// 사용자 취소
    case cancelled = "cancelled"
}

// MARK: - CleanupResultAction

/// 결과 화면 행동
enum CleanupResultAction: String {
    /// 확인 버튼
    case confirm   = "confirm"
    /// 휴지통 보기 버튼
    case viewTrash = "viewTrash"
}

// MARK: - CleanupEventData

/// 기존 정리 흐름의 분석 데이터
/// - 정리 흐름에서 빠져나오는 순간 AnalyticsService에 전달
/// - 시그널: cleanup.completed
struct CleanupEventData {
    /// 도달 단계
    let reachedStage: CleanupReachedStage
    /// 휴지통 경고 표시 여부
    let trashWarningShown: Bool
    /// 선택 방식 (방식 선택 전 이탈이면 nil)
    let method: CleanupMethodType?
    /// 결과 (정리 미진행이면 nil)
    let result: CleanupResultType?
    /// 발견(이동) 수
    let foundCount: Int
    /// 소요시간 (초)
    let durationSec: Double
    /// 취소 시 진행률 (취소 아니면 nil, 0.0~1.0)
    let cancelProgress: Float?
    /// 결과 행동 (결과 화면 미도달이면 nil)
    let resultAction: CleanupResultAction?
}

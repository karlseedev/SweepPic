//
//  SessionStatus.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  세션 상태 정의
//  - idle: 대기 중
//  - scanning: 탐색 중
//  - paused: 일시정지 (백그라운드)
//  - completed: 완료
//  - cancelled: 취소됨
//
//  상태 전이:
//  idle → scanning (정리 시작)
//  scanning → paused (백그라운드 전환)
//  paused → scanning (포그라운드 복귀)
//  scanning → completed (종료 조건 충족)
//  scanning → cancelled (사용자 취소)
//

import Foundation

/// 세션 상태
///
/// 정리 세션의 현재 상태를 나타냄.
/// 상태 전이는 단방향이며, idle로 돌아가려면 새 세션 생성 필요.
enum SessionStatus: String, Codable, CaseIterable {

    /// 대기 중
    /// - 초기 상태
    /// - 정리 시작 전
    case idle

    /// 탐색 중
    /// - 사진 분석 진행 중
    /// - 배치 처리 및 저품질 판정 수행
    case scanning

    /// 일시정지
    /// - 백그라운드 전환 시 자동 전환
    /// - 포그라운드 복귀 시 자동 재개
    /// - 저장: 메모리에만 유지 (파일 저장 안 함)
    case paused

    /// 완료
    /// - 종료 조건 충족:
    ///   1. 50장 찾음
    ///   2. 1,000장 검색
    ///   3. 범위 끝 (연도별/가장 오래된 사진)
    case completed

    /// 취소됨
    /// - 사용자가 취소 버튼 탭
    /// - 아무것도 휴지통으로 이동하지 않음
    case cancelled
}

// MARK: - 상태 전이

extension SessionStatus {

    /// 해당 상태에서 전이 가능한 다음 상태 목록
    var allowedTransitions: [SessionStatus] {
        switch self {
        case .idle:
            return [.scanning]
        case .scanning:
            return [.paused, .completed, .cancelled]
        case .paused:
            return [.scanning]
        case .completed:
            return []  // 최종 상태
        case .cancelled:
            return []  // 최종 상태
        }
    }

    /// 주어진 상태로 전이 가능한지 확인
    /// - Parameter newStatus: 전이하려는 상태
    /// - Returns: 전이 가능 여부
    func canTransition(to newStatus: SessionStatus) -> Bool {
        return allowedTransitions.contains(newStatus)
    }

    /// 최종 상태인지 확인
    /// - completed 또는 cancelled
    var isFinal: Bool {
        return self == .completed || self == .cancelled
    }

    /// 활성 상태인지 확인
    /// - scanning 또는 paused
    var isActive: Bool {
        return self == .scanning || self == .paused
    }
}

// MARK: - CustomStringConvertible

extension SessionStatus: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        switch self {
        case .idle:
            return "대기 중"
        case .scanning:
            return "탐색 중"
        case .paused:
            return "일시정지"
        case .completed:
            return "완료"
        case .cancelled:
            return "취소됨"
        }
    }
}

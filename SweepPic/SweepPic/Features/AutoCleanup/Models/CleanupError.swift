//
//  CleanupError.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  정리 에러 정의
//  - 정리 서비스에서 발생할 수 있는 에러들
//

import Foundation

/// 정리 에러
///
/// CleanupService에서 발생할 수 있는 에러.
enum CleanupError: Error, Equatable {

    /// 이미 진행 중
    /// - 정리가 이미 실행 중일 때 다시 시작하려는 경우
    case alreadyRunning

    /// 삭제대기함이 비어있지 않음
    /// - 정리 시작 전제조건 미충족
    /// - 사용자에게 "삭제대기함을 먼저 비워주세요" 메시지 표시
    case trashNotEmpty

    /// 사진 라이브러리 접근 권한 없음
    /// - PHPhotoLibrary.authorizationStatus != .authorized
    case noPhotoAccess

    /// 이전 세션 없음
    /// - "이어서 정리" 선택 시 이전 세션이 없는 경우
    case noPreviousSession

    /// 분석 실패
    /// - Metal/Vision API 초기화 또는 실행 실패
    /// - associated value: 에러 상세 메시지
    case analysisFailed(String)

    /// Metal 초기화 실패
    /// - MTLDevice 생성 실패
    /// - 전체 정리 중단
    case metalInitFailed

    /// 삭제대기함 이동 실패
    /// - TrashStore.moveToTrash 실패
    /// - 부분 성공 가능 (일부 사진만 이동)
    case trashMoveFailed(String)
}

// MARK: - LocalizedError

extension CleanupError: LocalizedError {

    /// 사용자에게 표시할 에러 메시지
    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return String(localized: "autoCleanup.error.alreadyRunning")
        case .trashNotEmpty:
            return CleanupConstants.trashNotEmptyMessage
        case .noPhotoAccess:
            return String(localized: "autoCleanup.error.noPhotoAccess")
        case .noPreviousSession:
            return String(localized: "autoCleanup.error.noPreviousSession")
        case .analysisFailed(let message):
            return String(localized: "autoCleanup.error.analysisFailed \(message)")
        case .metalInitFailed:
            return String(localized: "autoCleanup.error.metalInitFailed")
        case .trashMoveFailed(let message):
            return String(localized: "autoCleanup.error.trashMoveFailed \(message)")
        }
    }

    /// 복구 제안
    var recoverySuggestion: String? {
        switch self {
        case .alreadyRunning:
            return String(localized: "autoCleanup.recovery.alreadyRunning")
        case .trashNotEmpty:
            return String(localized: "autoCleanup.recovery.trashNotEmpty")
        case .noPhotoAccess:
            return String(localized: "autoCleanup.recovery.noPhotoAccess")
        case .noPreviousSession:
            return String(localized: "autoCleanup.recovery.noPreviousSession")
        case .analysisFailed, .metalInitFailed:
            return String(localized: "autoCleanup.recovery.restart")
        case .trashMoveFailed:
            return String(localized: "autoCleanup.recovery.retry")
        }
    }
}

// MARK: - 에러 분류

extension CleanupError {

    /// 사용자 액션이 필요한 에러인지
    /// - true: 사용자가 조치를 취해야 함 (예: 삭제대기함 비우기)
    /// - false: 시스템 에러 (예: Metal 실패)
    var requiresUserAction: Bool {
        switch self {
        case .trashNotEmpty, .noPhotoAccess, .noPreviousSession:
            return true
        case .alreadyRunning, .analysisFailed, .metalInitFailed, .trashMoveFailed:
            return false
        }
    }

    /// 복구 가능한 에러인지
    /// - true: 재시도 가능
    /// - false: 조건 변경 필요
    var isRecoverable: Bool {
        switch self {
        case .trashNotEmpty, .noPhotoAccess, .noPreviousSession:
            return false  // 조건 변경 필요
        case .alreadyRunning:
            return true   // 대기 후 재시도
        case .analysisFailed, .trashMoveFailed:
            return true   // 재시도 가능
        case .metalInitFailed:
            return false  // 기기 제약
        }
    }
}

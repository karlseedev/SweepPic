//
//  CleanupServiceProtocol.swift
//  SweepPic
//
//  Created by Claude on 2026-01-23.
//
//  정리 서비스 프로토콜 정의
//  - 정리 실행 인터페이스
//  - async/await 기반 API
//

import Foundation
import Photos

// MARK: - CleanupServiceProtocol

/// 정리 서비스 프로토콜
///
/// 저품질 사진 자동 정리 기능의 메인 인터페이스입니다.
/// 사진을 스캔하여 저품질 사진을 찾고 삭제대기함으로 이동합니다.
protocol CleanupServiceProtocol: AnyObject {

    // MARK: - 상태 조회

    /// 현재 진행 중인 세션
    var currentSession: CleanupSession? { get }

    /// 이전 세션 (이어서 정리용)
    var lastSession: CleanupSession? { get }

    /// 정리 진행 중 여부
    var isRunning: Bool { get }

    // MARK: - 삭제대기함 상태 확인

    /// 삭제대기함이 비어있는지 확인
    /// - Returns: 삭제대기함이 비어있으면 true
    func isTrashEmpty() -> Bool

    // MARK: - 정리 실행

    /// 정리 시작
    ///
    /// - Parameters:
    ///   - method: 정리 방식 (최신사진부터/이어서/연도별)
    ///   - mode: 판별 모드 (Precision/Recall)
    ///   - progressHandler: 진행 상황 콜백 (메인 스레드에서 호출)
    /// - Returns: 정리 결과
    /// - Throws: CleanupError
    ///
    /// - Note: 호출 전 isTrashEmpty()로 삭제대기함 비어있는지 확인 필요
    func startCleanup(
        method: CleanupMethod,
        mode: JudgmentMode,
        progressHandler: @escaping (CleanupProgress) -> Void
    ) async throws -> CleanupResult

    /// 정리 취소
    ///
    /// 진행 중인 정리를 취소합니다.
    /// - Important: 취소 시 아무것도 삭제대기함으로 이동하지 않음
    func cancelCleanup()

    /// 정리 일시정지 (백그라운드 전환 시)
    func pauseCleanup()

    /// 정리 재개 (포그라운드 복귀 시)
    func resumeCleanup()
}

// MARK: - CleanupServiceDelegate

/// 정리 서비스 델리게이트
///
/// 정리 진행 상황을 실시간으로 받기 위한 델리게이트입니다.
protocol CleanupServiceDelegate: AnyObject {

    /// 진행 상황 업데이트
    /// - Parameters:
    ///   - service: 정리 서비스
    ///   - progress: 진행 상황
    func cleanupService(
        _ service: CleanupServiceProtocol,
        didUpdateProgress progress: CleanupProgress
    )

    /// 정리 완료
    /// - Parameters:
    ///   - service: 정리 서비스
    ///   - result: 정리 결과
    func cleanupService(
        _ service: CleanupServiceProtocol,
        didCompleteWith result: CleanupResult
    )

    /// 에러 발생
    /// - Parameters:
    ///   - service: 정리 서비스
    ///   - error: 에러
    func cleanupService(
        _ service: CleanupServiceProtocol,
        didFailWith error: CleanupError
    )
}

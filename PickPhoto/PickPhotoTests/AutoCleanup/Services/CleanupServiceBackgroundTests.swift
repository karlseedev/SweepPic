//
//  CleanupServiceBackgroundTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-02-13.
//
//  백그라운드 전환 테스트
//  - 일시정지 (sceneWillResignActive → pauseCleanup)
//  - 재개 (sceneWillEnterForeground → resumeCleanup)
//  - 앱 종료 시 진행 상태 소실 확인
//

import XCTest
@testable import PickPhoto
import Photos

final class CleanupServiceBackgroundTests: XCTestCase {

    // MARK: - Properties

    var sut: CleanupService!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        sut = CleanupService.shared
    }

    override func tearDown() {
        sut.cancelCleanup()
        sut = nil
        super.tearDown()
    }

    // MARK: - Pause/Resume Tests

    /// pauseCleanup 호출 시 크래시 없이 동작
    func testPauseCleanup_WhenNotRunning_DoesNotCrash() {
        // 실행 중이 아닐 때 일시정지해도 크래시 안 함
        sut.pauseCleanup()
        XCTAssertFalse(sut.isRunning)
    }

    /// resumeCleanup 호출 시 크래시 없이 동작
    func testResumeCleanup_WhenNotRunning_DoesNotCrash() {
        // 실행 중이 아닐 때 재개해도 크래시 안 함
        sut.resumeCleanup()
        XCTAssertFalse(sut.isRunning)
    }

    /// 일시정지 → 재개 순서 테스트
    func testPauseAndResume_Sequential_DoesNotCrash() {
        sut.pauseCleanup()
        sut.resumeCleanup()
        XCTAssertFalse(sut.isRunning)
    }

    /// 여러 번 일시정지 호출 (멱등성)
    func testPauseCleanup_MultipleCalls_Idempotent() {
        sut.pauseCleanup()
        sut.pauseCleanup()
        sut.pauseCleanup()
        XCTAssertFalse(sut.isRunning, "Multiple pause calls should not crash")
    }

    /// 여러 번 재개 호출 (멱등성)
    func testResumeCleanup_MultipleCalls_Idempotent() {
        sut.resumeCleanup()
        sut.resumeCleanup()
        sut.resumeCleanup()
        XCTAssertFalse(sut.isRunning, "Multiple resume calls should not crash")
    }

    // MARK: - Background Integration Tests (실기기 필요)

    /// 정리 중 일시정지 후 재개 테스트
    func testPauseDuringCleanup_ThenResume_Completes() async throws {
        // 전제조건
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }
        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }

        // 정리 시작 (별도 Task)
        let cleanupTask = Task {
            try await sut.startCleanup(
                method: .fromLatest,
                mode: .precision,
                progressHandler: { _ in }
            )
        }

        // 약간 대기 후 일시정지
        try await Task.sleep(nanoseconds: 200_000_000)  // 0.2초
        sut.pauseCleanup()

        // 세션 상태 확인
        if let session = sut.currentSession {
            XCTAssertEqual(session.status, .paused, "Session should be paused")
        }

        // 잠시 대기 (일시정지 상태 유지)
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5초

        // 재개
        sut.resumeCleanup()

        // 정리 완료 대기
        let result = try await cleanupTask.value

        // 결과 확인 (정상 완료되어야 함)
        XCTAssertTrue(result.resultType.isSuccess || result.endReason == .userCancelled,
                      "Cleanup should complete after resume")

        print("""
        === Pause/Resume Test ===
        - Scanned: \(result.scannedCount)
        - Found: \(result.foundCount)
        - End Reason: \(result.endReason)
        """)
    }

    /// 일시정지 중 취소 테스트
    func testCancelDuringPause_CancelsSuccessfully() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }
        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }

        // 정리 시작
        let cleanupTask = Task {
            try await sut.startCleanup(
                method: .fromLatest,
                mode: .precision,
                progressHandler: { _ in }
            )
        }

        // 일시정지
        try await Task.sleep(nanoseconds: 200_000_000)
        sut.pauseCleanup()

        // 일시정지 상태에서 취소
        try await Task.sleep(nanoseconds: 100_000_000)
        sut.cancelCleanup()

        // 결과 확인
        let result = try await cleanupTask.value

        if case .cancelled = result.resultType {
            XCTAssertEqual(result.trashedAssetIDs.count, 0,
                           "Cancelled during pause should not move any photos")
        }
    }

    // MARK: - Session State Tests

    /// 앱 종료 시 currentSession이 nil (메모리만 유지)
    func testCurrentSession_InMemoryOnly() {
        // 정리가 시작되지 않은 상태에서 currentSession은 nil
        XCTAssertNil(sut.currentSession,
                     "Current session should be nil when not running")
    }

    /// CleanupSession 상태 전이 테스트
    func testSessionStatusTransitions() {
        var session = CleanupSession(method: .fromLatest)
        XCTAssertEqual(session.status, .idle)

        // idle → scanning
        session.startScanning()
        XCTAssertEqual(session.status, .scanning)

        // scanning → paused
        session.pause()
        XCTAssertEqual(session.status, .paused)

        // paused → scanning
        session.resume()
        XCTAssertEqual(session.status, .scanning)

        // scanning → completed
        session.complete()
        XCTAssertEqual(session.status, .completed)
    }

    /// 잘못된 상태 전이 무시 테스트
    func testSessionStatusTransitions_InvalidTransition_Ignored() {
        var session = CleanupSession(method: .fromLatest)

        // idle → paused (잘못된 전이, idle에서 바로 pause 불가)
        session.pause()
        // canTransition(to:) 로직에 따라 달라짐
        // 현재 구현은 scanning → paused만 허용

        // completed → scanning (잘못된 전이)
        session.startScanning()
        session.complete()
        session.startScanning()
        XCTAssertEqual(session.status, .completed,
                       "Should not transition from completed to scanning")
    }
}

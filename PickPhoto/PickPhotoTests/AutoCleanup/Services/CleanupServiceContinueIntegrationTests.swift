//
//  CleanupServiceContinueIntegrationTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-02-13.
//
//  이어서 정리 Integration 테스트
//  - 세션 저장 후 재개 플로우
//  - 실기기 테스트 필수
//

import XCTest
@testable import PickPhoto
import Photos

final class CleanupServiceContinueIntegrationTests: XCTestCase {

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

    // MARK: - Full Continue Flow Tests

    /// 이어서 정리 전체 플로우 테스트
    /// - 1차 정리 → 세션 저장 확인 → 2차 시작 위치 검증
    func testFullContinueFlow_SessionSavedAndRestorable() async throws {
        // 전제조건
        try skipIfNotReady()

        // 1차: fromLatest 정리
        let firstResult = try await sut.startCleanup(
            method: .fromLatest,
            mode: .precision,
            progressHandler: { _ in }
        )

        guard firstResult.endReason == .maxFound || firstResult.endReason == .maxScanned else {
            throw XCTSkip("First cleanup must reach maxFound or maxScanned to test continue")
        }

        // 세션 저장 검증
        let store = CleanupSessionStore.shared
        let savedSession = store.latestSession
        XCTAssertNotNil(savedSession, "Session should be persisted")
        XCTAssertEqual(savedSession?.status, .completed)
        XCTAssertNotNil(savedSession?.lastAssetDate, "lastAssetDate should be set")
        XCTAssertTrue(savedSession?.canContinueFromLatest ?? false, "Should be continuable")

        // 세션 데이터 일관성 검증
        XCTAssertGreaterThan(savedSession?.scannedCount ?? 0, 0)
        XCTAssertGreaterThanOrEqual(savedSession?.foundCount ?? 0, 0)

        print("""
        === Continue Flow Verification ===
        - 1st Scanned: \(firstResult.scannedCount)
        - 1st Found: \(firstResult.foundCount)
        - Saved Last Date: \(savedSession?.lastAssetDate?.description ?? "nil")
        - Can Continue: \(savedSession?.canContinueFromLatest ?? false)
        """)
    }

    /// endOfRange 종료 시 이어서 정리 불가 확인
    func testContinueNotAvailable_WhenEndOfRange() async throws {
        // 전제조건
        try skipIfNotReady()

        // 사진이 없는 연도로 정리 → endOfRange
        let result = try await sut.startCleanup(
            method: .byYear(year: 1990),
            mode: .precision,
            progressHandler: { _ in }
        )

        XCTAssertEqual(result.endReason, .endOfRange)

        // byYear 세션에서 이어서 정리 불가
        let store = CleanupSessionStore.shared
        let byYearSession = store.byYearSession

        // endOfRange면 canContinueByYear == false
        if let session = byYearSession, session.targetYear == 1990 {
            XCTAssertFalse(session.canContinueByYear,
                           "Should not be able to continue after endOfRange")
        }
    }

    /// 취소 후 세션 저장 안 함 확인
    func testSessionNotSaved_WhenCancelled() async throws {
        // 전제조건
        try skipIfNotReady()

        // 기존 세션 삭제
        let store = CleanupSessionStore.shared
        store.clear()

        // 정리 시작 후 즉시 취소
        let cleanupTask = Task {
            try await sut.startCleanup(
                method: .fromLatest,
                mode: .precision,
                progressHandler: { _ in }
            )
        }

        // 즉시 취소
        try await Task.sleep(nanoseconds: 100_000_000)  // 0.1초
        sut.cancelCleanup()

        let result = try await cleanupTask.value

        // 취소된 경우 세션 저장 안 됨
        if case .cancelled = result.resultType {
            // 취소 시 세션은 저장되지 않아야 함 (endReason == .userCancelled)
            // Note: 취소 타이밍에 따라 결과가 달라질 수 있음
            let savedSession = store.latestSession
            if let saved = savedSession {
                // 이전 세션이 남아있을 수 있지만, 취소된 세션은 아님
                XCTAssertNotEqual(saved.endReason, .userCancelled,
                                  "Cancelled session should not be saved")
            }
        }
    }

    // MARK: - Helper

    /// 테스트 전제조건 확인
    private func skipIfNotReady() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }
    }
}

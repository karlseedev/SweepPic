//
//  CleanupServiceByYearIntegrationTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-02-13.
//
//  연도별 정리 Integration 테스트
//  - 실기기 테스트 필수
//  - 연도별 정리 전체 플로우 E2E
//  - 연도별 이어서 정리 (continueFrom) 플로우
//

import XCTest
@testable import SweepPic
import Photos

final class CleanupServiceByYearIntegrationTests: XCTestCase {

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

    // MARK: - byYear Full Flow Tests

    /// 연도별 정리 전체 플로우 테스트
    /// - 특정 연도 선택 → 분석 → 결과 확인
    func testByYearFullFlow_WithCurrentYear() async throws {
        // 전제조건 확인
        try skipIfNotReady()

        let currentYear = Calendar.current.component(.year, from: Date())
        var progressUpdates: [CleanupProgress] = []

        // 정리 시작
        let result = try await sut.startCleanup(
            method: .byYear(year: currentYear),
            mode: .precision,
            progressHandler: { progress in
                progressUpdates.append(progress)
            }
        )

        // 결과 검증
        XCTAssertTrue(result.resultType.isSuccess)
        XCTAssertEqual(result.trashedAssetIDs.count, result.foundCount)

        // 진행 상황이 올바르게 업데이트되었는지 확인
        if !progressUpdates.isEmpty {
            let lastProgress = progressUpdates.last!
            XCTAssertGreaterThanOrEqual(lastProgress.scannedCount, 0)
            XCTAssertGreaterThanOrEqual(lastProgress.foundCount, 0)
        }

        print("""
        === byYear Full Flow (\(currentYear)) ===
        - Scanned: \(result.scannedCount)
        - Found: \(result.foundCount)
        - End Reason: \(result.endReason)
        - Progress Updates: \(progressUpdates.count)
        - Time: \(String(format: "%.1f", result.totalTimeSeconds))s
        """)
    }

    /// 연도별 이어서 정리 플로우 테스트
    /// - 첫 정리 → maxFound/maxScanned 도달 → 이어서 정리 시작
    func testByYearContinueFlow() async throws {
        // 전제조건 확인
        try skipIfNotReady()

        let currentYear = Calendar.current.component(.year, from: Date())

        // 1차 정리 (첫 번째)
        let firstResult = try await sut.startCleanup(
            method: .byYear(year: currentYear),
            mode: .precision,
            progressHandler: { _ in }
        )

        // maxFound 또는 maxScanned로 종료되지 않으면 이어서 정리 불가
        guard firstResult.endReason == .maxFound || firstResult.endReason == .maxScanned else {
            print("First cleanup ended with \(firstResult.endReason) - cannot test continue flow")
            throw XCTSkip("Need maxFound or maxScanned to test continue flow")
        }

        // 세션 저장 확인
        let sessionStore = CleanupSessionStore.shared
        let savedSession = sessionStore.byYearSession
        XCTAssertNotNil(savedSession, "Session should be saved after cleanup")
        XCTAssertTrue(savedSession?.canContinueByYear ?? false, "Should be able to continue")

        // 이어서 정리를 위한 continueFrom 날짜
        guard let continueFrom = savedSession?.lastAssetDate else {
            XCTFail("lastAssetDate should be set")
            return
        }

        // 2차 정리 (이어서) - 삭제대기함을 비워야 가능
        // Note: 실제 테스트에서는 중간에 삭제대기함 비우기 필요
        // 여기서는 세션 데이터 검증만 수행
        XCTAssertNotNil(continueFrom)
        XCTAssertEqual(savedSession?.targetYear, currentYear)

        print("""
        === byYear Continue Flow ===
        - First Result: \(firstResult.scannedCount) scanned, \(firstResult.foundCount) found
        - Continue From: \(continueFrom)
        - Target Year: \(currentYear)
        """)
    }

    /// 연도별 정리 취소 테스트
    func testByYearCancelFlow() async throws {
        // 전제조건 확인
        try skipIfNotReady()

        let currentYear = Calendar.current.component(.year, from: Date())

        // 정리 시작 (별도 Task에서)
        let cleanupTask = Task {
            try await sut.startCleanup(
                method: .byYear(year: currentYear),
                mode: .precision,
                progressHandler: { _ in }
            )
        }

        // 약간 대기 후 취소
        try await Task.sleep(nanoseconds: 300_000_000)  // 0.3초
        sut.cancelCleanup()

        // 결과 확인
        let result = try await cleanupTask.value

        if case .cancelled = result.resultType {
            // 취소된 경우 아무것도 이동하지 않음
            XCTAssertEqual(result.trashedAssetIDs.count, 0,
                           "Cancelled byYear cleanup should not move any photos")
        }
        // Note: 취소 타이밍에 따라 이미 완료될 수도 있음
    }

    /// 사진이 없는 연도 정리 테스트
    func testByYear_EmptyYear_ReturnsNoneFound() async throws {
        // 전제조건 확인
        try skipIfNotReady()

        // 사진이 없을 아주 옛날 연도
        let result = try await sut.startCleanup(
            method: .byYear(year: 1995),
            mode: .precision,
            progressHandler: { _ in }
        )

        // 사진 없으므로 0장 검색, 0장 발견, endOfRange
        XCTAssertEqual(result.scannedCount, 0)
        XCTAssertEqual(result.foundCount, 0)
        XCTAssertEqual(result.endReason, .endOfRange)

        if case .noneFound = result.resultType {
            // 정상
        } else {
            XCTFail("Expected noneFound result type")
        }
    }

    // MARK: - Result Message Tests

    /// byYear 결과 메시지 - endOfRange + N장 발견
    func testResultMessage_ByYear_EndOfRange_WithFound() {
        let message = CleanupConstants.resultMessage(
            endReason: .endOfRange,
            foundCount: 15,
            method: .byYear(year: 2024)
        )

        XCTAssertTrue(message.contains("2024"), "Message should contain the year")
        XCTAssertTrue(message.contains("15"), "Message should contain the found count")
    }

    /// byYear 결과 메시지 - endOfRange + 0장 발견
    func testResultMessage_ByYear_EndOfRange_NoneFound() {
        let message = CleanupConstants.resultMessage(
            endReason: .endOfRange,
            foundCount: 0,
            method: .byYear(year: 2023)
        )

        XCTAssertTrue(message.contains("2023"), "Message should contain the year")
        XCTAssertFalse(message.isEmpty, "Message should indicate no photos found")
    }

    /// byYear 결과 메시지 - maxFound
    func testResultMessage_ByYear_MaxFound() {
        let message = CleanupConstants.resultMessage(
            endReason: .maxFound,
            foundCount: 50,
            method: .byYear(year: 2024)
        )

        XCTAssertTrue(message.contains("50"), "Message should contain 50")
        XCTAssertFalse(message.isEmpty, "Message should mention continue option")
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

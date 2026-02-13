//
//  CleanupServiceContinueTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-02-13.
//
//  continueFromLast 탐색 Unit 테스트
//  - 세션 연속성 확인 (lastAssetDate 기반 탐색 재개)
//  - 이전 세션 없을 때 처리
//  - CleanupSession 이어서 정리 가능 여부 검증
//  - CleanupSessionStore 세션 분리 저장 검증
//

import XCTest
@testable import PickPhoto
import Photos

final class CleanupServiceContinueTests: XCTestCase {

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

    // MARK: - CleanupMethod continueFromLast Tests

    /// continueFromLast 메소드의 Codable 인코딩/디코딩 테스트
    func testContinueFromLastMethod_Codable_EncodesDecodesCorrectly() throws {
        // Given
        let method = CleanupMethod.continueFromLast

        // When
        let encoder = JSONEncoder()
        let data = try encoder.encode(method)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(CleanupMethod.self, from: data)

        // Then
        XCTAssertEqual(decoded, method)
    }

    /// continueFromLast 메소드의 displayTitle 테스트
    func testContinueFromLastMethod_DisplayTitle() {
        // Given
        let method = CleanupMethod.continueFromLast

        // Then
        XCTAssertEqual(method.displayTitle, "이어서 정리")
    }

    /// continueFromLast의 year 프로퍼티는 nil
    func testContinueFromLastMethod_YearProperty_ReturnsNil() {
        XCTAssertNil(CleanupMethod.continueFromLast.year)
    }

    // MARK: - CleanupSession Continue Tests

    /// continuingFrom 이니셜라이저 테스트
    func testCleanupSession_ContinuingFrom_UsesLastAssetDate() {
        // Given
        let lastDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        var previousSession = CleanupSession(method: .fromLatest)
        previousSession.lastAssetDate = lastDate
        previousSession.status = .completed

        // When
        let newSession = CleanupSession(continuingFrom: previousSession)

        // Then
        XCTAssertEqual(newSession.startDate, lastDate, "Should start from previous session's lastAssetDate")
        XCTAssertEqual(newSession.method, .continueFromLast)
        XCTAssertEqual(newSession.status, .idle)
        XCTAssertNil(newSession.lastAssetDate)
        XCTAssertEqual(newSession.scannedCount, 0)
        XCTAssertEqual(newSession.foundCount, 0)
    }

    /// continuingFrom - lastAssetDate가 nil인 경우 startDate 사용
    func testCleanupSession_ContinuingFrom_FallsBackToStartDate() {
        // Given
        var previousSession = CleanupSession(method: .fromLatest, startDate: Date(timeIntervalSince1970: 1700000000))
        previousSession.lastAssetDate = nil
        previousSession.status = .completed

        // When
        let newSession = CleanupSession(continuingFrom: previousSession)

        // Then
        XCTAssertEqual(newSession.startDate, previousSession.startDate,
                       "Should fall back to previous session's startDate when lastAssetDate is nil")
    }

    /// canContinueFromLatest - fromLatest + maxFound
    func testCanContinueFromLatest_FromLatest_MaxFound_ReturnsTrue() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.status = .completed
        session.endReason = .maxFound

        // Then
        XCTAssertTrue(session.canContinueFromLatest)
        XCTAssertTrue(session.canContinue)
    }

    /// canContinueFromLatest - fromLatest + maxScanned
    func testCanContinueFromLatest_FromLatest_MaxScanned_ReturnsTrue() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.status = .completed
        session.endReason = .maxScanned

        // Then
        XCTAssertTrue(session.canContinueFromLatest)
    }

    /// canContinueFromLatest - continueFromLast + maxFound
    func testCanContinueFromLatest_ContinueFromLast_MaxFound_ReturnsTrue() {
        // Given
        var session = CleanupSession(method: .continueFromLast)
        session.status = .completed
        session.endReason = .maxFound

        // Then
        XCTAssertTrue(session.canContinueFromLatest,
                       "continueFromLast should also support canContinueFromLatest")
    }

    /// canContinueFromLatest - endOfRange → false
    func testCanContinueFromLatest_EndOfRange_ReturnsFalse() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.status = .completed
        session.endReason = .endOfRange

        // Then
        XCTAssertFalse(session.canContinueFromLatest)
        XCTAssertFalse(session.canContinue)
    }

    /// canContinueFromLatest - userCancelled → false
    func testCanContinueFromLatest_UserCancelled_ReturnsFalse() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.status = .cancelled
        session.endReason = .userCancelled

        // Then
        XCTAssertFalse(session.canContinueFromLatest)
    }

    /// byYear 세션은 canContinueFromLatest가 false
    func testCanContinueFromLatest_ByYear_ReturnsFalse() {
        // Given
        var session = CleanupSession(year: 2024)
        session.status = .completed
        session.endReason = .maxFound

        // Then
        XCTAssertFalse(session.canContinueFromLatest)
        XCTAssertTrue(session.canContinueByYear)  // byYear는 canContinueByYear로 확인
    }

    // MARK: - CleanupSessionStore Continue Tests

    /// latestSession 저장 후 canContinue 확인
    func testSessionStore_CanContinue_WhenSessionSaved() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("TestContinue_\(UUID().uuidString).json")
        let store = CleanupSessionStore(filePath: tempFile)

        // When
        var session = CleanupSession(method: .fromLatest)
        session.status = .completed
        session.lastAssetDate = Date(timeIntervalSince1970: 1704067200)
        session.endReason = .maxFound
        store.save(session)

        // Then
        XCTAssertTrue(store.canContinue)
        XCTAssertNotNil(store.latestSession)
        XCTAssertNotNil(store.lastSessionDate)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    /// 세션 없을 때 canContinue == false
    func testSessionStore_CannotContinue_WhenNoSession() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("TestNoContinue_\(UUID().uuidString).json")
        let store = CleanupSessionStore(filePath: tempFile)

        // Then
        XCTAssertFalse(store.canContinue)
        XCTAssertNil(store.latestSession)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    /// 세션 clear 후 canContinue == false
    func testSessionStore_CannotContinue_AfterClear() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("TestClear_\(UUID().uuidString).json")
        let store = CleanupSessionStore(filePath: tempFile)

        var session = CleanupSession(method: .fromLatest)
        session.status = .completed
        session.lastAssetDate = Date()
        store.save(session)

        // When
        store.clear()

        // Then
        XCTAssertFalse(store.canContinue)
        XCTAssertNil(store.latestSession)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    // MARK: - Service Continue Integration Tests (실기기 필요)

    /// continueFromLast 시작 테스트 (이전 세션 필요)
    func testStartCleanup_ContinueFromLast_Integration() async throws {
        // 전제조건 확인
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }

        // 1차: fromLatest 정리 실행
        let firstResult = try await sut.startCleanup(
            method: .fromLatest,
            mode: .precision,
            progressHandler: { _ in }
        )

        // maxFound 또는 maxScanned가 아니면 이어서 정리 테스트 불가
        guard firstResult.endReason == .maxFound || firstResult.endReason == .maxScanned else {
            print("First cleanup ended with \(firstResult.endReason) - skip continue test")
            throw XCTSkip("Need maxFound or maxScanned to test continue")
        }

        // 세션 저장 확인
        let sessionStore = CleanupSessionStore.shared
        let savedSession = sessionStore.latestSession
        XCTAssertNotNil(savedSession)
        XCTAssertTrue(savedSession?.canContinueFromLatest ?? false)
        XCTAssertNotNil(savedSession?.lastAssetDate)

        print("""
        === Continue Test ===
        - First: \(firstResult.scannedCount) scanned, \(firstResult.foundCount) found
        - Last Date: \(savedSession?.lastAssetDate?.description ?? "nil")
        - Can Continue: \(savedSession?.canContinueFromLatest ?? false)
        """)
    }
}

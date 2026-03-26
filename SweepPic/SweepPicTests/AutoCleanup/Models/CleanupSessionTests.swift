//
//  CleanupSessionTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-01-22.
//
//  CleanupSession 모델 테스트
//  - Codable 인코딩/디코딩
//  - 상태 전이
//  - 진행 상황 업데이트
//

import XCTest
@testable import SweepPic

final class CleanupSessionTests: XCTestCase {

    // MARK: - Initialization Tests

    func testInitWithFromLatest() {
        // Given & When
        let session = CleanupSession(method: .fromLatest)

        // Then
        XCTAssertEqual(session.method, .fromLatest)
        XCTAssertEqual(session.mode, .precision)
        XCTAssertEqual(session.status, .idle)
        XCTAssertEqual(session.scannedCount, 0)
        XCTAssertEqual(session.foundCount, 0)
        XCTAssertTrue(session.trashedAssetIDs.isEmpty)
        XCTAssertNil(session.lastAssetDate)
        XCTAssertNil(session.lastAssetID)
    }

    func testInitWithByYear() {
        // Given
        let year = 2024

        // When
        let session = CleanupSession(year: year)

        // Then
        XCTAssertEqual(session.method, .byYear(year: 2024))
        XCTAssertEqual(session.mode, .precision)

        // 연도 끝 날짜 확인
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: session.startDate)
        XCTAssertEqual(components.year, 2024)
        XCTAssertEqual(components.month, 12)
        XCTAssertEqual(components.day, 31)
    }

    func testInitContinuingFromPreviousSession() {
        // Given
        var previousSession = CleanupSession(method: .fromLatest)
        let lastDate = Date().addingTimeInterval(-86400 * 30)  // 30일 전
        previousSession.updateProgress(
            scannedCount: 500,
            foundCount: 25,
            lastAssetDate: lastDate,
            lastAssetID: "test-id"
        )
        previousSession.complete()

        // When
        let newSession = CleanupSession(continuingFrom: previousSession)

        // Then
        XCTAssertEqual(newSession.method, .continueFromLast)
        XCTAssertEqual(newSession.startDate, lastDate)
        XCTAssertEqual(newSession.scannedCount, 0)
        XCTAssertEqual(newSession.foundCount, 0)
    }

    // MARK: - Codable Tests

    func testEncodeDecode() throws {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.updateProgress(
            scannedCount: 100,
            foundCount: 10,
            lastAssetDate: Date(),
            lastAssetID: "test-asset-123"
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // When
        let data = try encoder.encode(session)
        let decoded = try decoder.decode(CleanupSession.self, from: data)

        // Then
        XCTAssertEqual(decoded.id, session.id)
        XCTAssertEqual(decoded.method, session.method)
        XCTAssertEqual(decoded.mode, session.mode)
        XCTAssertEqual(decoded.status, session.status)
        XCTAssertEqual(decoded.scannedCount, session.scannedCount)
        XCTAssertEqual(decoded.foundCount, session.foundCount)
    }

    func testEncodeDecodeByYear() throws {
        // Given
        let session = CleanupSession(year: 2024)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        // When
        let data = try encoder.encode(session)
        let decoded = try decoder.decode(CleanupSession.self, from: data)

        // Then
        XCTAssertEqual(decoded.method, .byYear(year: 2024))
    }

    // MARK: - State Transition Tests

    func testStartScanning() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        XCTAssertEqual(session.status, .idle)

        // When
        session.startScanning()

        // Then
        XCTAssertEqual(session.status, .scanning)
    }

    func testPauseAndResume() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()

        // When
        session.pause()

        // Then
        XCTAssertEqual(session.status, .paused)

        // When
        session.resume()

        // Then
        XCTAssertEqual(session.status, .scanning)
    }

    func testComplete() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()

        // When
        session.complete()

        // Then
        XCTAssertEqual(session.status, .completed)
        XCTAssertTrue(session.status.isFinal)
    }

    func testCancel() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.recordTrashed(assetIDs: ["id1", "id2"])

        // When
        session.cancel()

        // Then
        XCTAssertEqual(session.status, .cancelled)
        XCTAssertTrue(session.status.isFinal)
        XCTAssertTrue(session.trashedAssetIDs.isEmpty)  // 취소 시 목록 초기화
    }

    func testInvalidStateTransition() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.complete()

        // When - 완료 후 일시정지 시도 (불가)
        session.pause()

        // Then - 상태 변경 안 됨
        XCTAssertEqual(session.status, .completed)
    }

    // MARK: - Progress Update Tests

    func testUpdateProgress() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        let testDate = Date()

        // When
        session.updateProgress(
            scannedCount: 500,
            foundCount: 25,
            lastAssetDate: testDate,
            lastAssetID: "test-id"
        )

        // Then
        XCTAssertEqual(session.scannedCount, 500)
        XCTAssertEqual(session.foundCount, 25)
        XCTAssertEqual(session.lastAssetDate, testDate)
        XCTAssertEqual(session.lastAssetID, "test-id")
    }

    func testRecordTrashed() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()

        // When
        session.recordTrashed(assetID: "id1")
        session.recordTrashed(assetID: "id2")

        // Then
        XCTAssertEqual(session.trashedAssetIDs.count, 2)
        XCTAssertEqual(session.foundCount, 2)
        XCTAssertTrue(session.trashedAssetIDs.contains("id1"))
        XCTAssertTrue(session.trashedAssetIDs.contains("id2"))
    }

    func testRecordTrashedBatch() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()

        // When
        session.recordTrashed(assetIDs: ["id1", "id2", "id3"])

        // Then
        XCTAssertEqual(session.trashedAssetIDs.count, 3)
        XCTAssertEqual(session.foundCount, 3)
    }

    // MARK: - Validation Tests

    func testShouldTerminateWhenMaxFound() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()

        // When
        let ids = (0..<50).map { "id\($0)" }
        session.recordTrashed(assetIDs: ids)

        // Then
        XCTAssertTrue(session.hasReachedMaxFound)
        XCTAssertTrue(session.shouldTerminate)
    }

    func testShouldTerminateWhenMaxScanned() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()

        // When
        session.updateProgress(
            scannedCount: 1000,
            foundCount: 10,
            lastAssetDate: Date(),
            lastAssetID: nil
        )

        // Then
        XCTAssertTrue(session.hasReachedMaxScanned)
        XCTAssertTrue(session.shouldTerminate)
    }

    func testTargetYear() {
        // Given
        let sessionByYear = CleanupSession(year: 2024)
        let sessionFromLatest = CleanupSession(method: .fromLatest)

        // Then
        XCTAssertEqual(sessionByYear.targetYear, 2024)
        XCTAssertNil(sessionFromLatest.targetYear)
    }

    func testIsValid() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.recordTrashed(assetIDs: ["id1", "id2"])

        // Then
        XCTAssertTrue(session.isValid)

        // When - 유효하지 않은 상태
        session.scannedCount = 2000  // 최대 초과

        // Then
        XCTAssertFalse(session.isValid)
    }
}

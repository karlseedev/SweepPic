//
//  CleanupSessionStoreTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-01-22.
//
//  CleanupSessionStore 테스트
//  - 저장/로드/삭제
//  - 이어서 정리 가능 여부
//  - 부분 업데이트
//
//  Note: 테스트용 Store는 동기 모드로 동작하므로 비동기 대기 불필요

import XCTest
@testable import PickPhoto

final class CleanupSessionStoreTests: XCTestCase {

    // MARK: - Properties

    var store: CleanupSessionStore!
    var testFilePath: URL!

    // MARK: - Setup

    override func setUp() {
        super.setUp()

        // 테스트용 임시 파일 경로
        let tempDir = FileManager.default.temporaryDirectory
        testFilePath = tempDir.appendingPathComponent("TestCleanupSession_\(UUID().uuidString).json")

        // 테스트용 스토어 생성 (동기 모드)
        store = CleanupSessionStore(filePath: testFilePath)
    }

    override func tearDown() {
        // 스토어 먼저 해제
        store = nil

        // 테스트 파일 정리
        if let path = testFilePath {
            try? FileManager.default.removeItem(at: path)
        }
        testFilePath = nil

        super.tearDown()
    }

    // MARK: - Save Tests

    func testSaveSession() {
        // Given
        let session = CleanupSession(method: .fromLatest)

        // When - 동기 모드이므로 즉시 완료
        store.save(session)

        // Then
        XCTAssertNotNil(store.currentSession)
        XCTAssertEqual(store.currentSession?.id, session.id)
    }

    func testSaveAndLoad() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.updateProgress(
            scannedCount: 100,
            foundCount: 10,
            lastAssetDate: Date(),
            lastAssetID: "test-id"
        )
        session.recordTrashed(assetIDs: ["id1", "id2"])

        // When - 동기 저장
        store.save(session)

        // Create new store with same path to test persistence
        let newStore = CleanupSessionStore(filePath: testFilePath)

        // Then
        let loaded = newStore.load()
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.id, session.id)
        XCTAssertEqual(loaded?.scannedCount, 100)
        // recordTrashed가 foundCount를 trashedAssetIDs.count로 설정
        XCTAssertEqual(loaded?.foundCount, 2)
        XCTAssertEqual(loaded?.trashedAssetIDs.count, 2)
    }

    // MARK: - Clear Tests

    func testClearSession() {
        // Given
        let session = CleanupSession(method: .fromLatest)
        store.save(session)
        XCTAssertNotNil(store.currentSession)

        // When - 동기 삭제
        store.clear()

        // Then
        XCTAssertNil(store.currentSession)
        XCTAssertFalse(FileManager.default.fileExists(atPath: testFilePath.path))
    }

    // MARK: - Can Continue Tests

    func testCanContinueWhenSessionCompleted() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.updateProgress(
            scannedCount: 500,
            foundCount: 25,
            lastAssetDate: Date(),
            lastAssetID: "test-id"
        )
        session.complete()

        store.save(session)

        // Then
        XCTAssertTrue(store.canContinue)
    }

    func testCannotContinueWhenSessionCancelled() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.cancel()

        store.save(session)

        // Then - 취소된 세션은 이어서 정리 불가
        XCTAssertFalse(store.canContinue)
    }

    func testCannotContinueWhenNoLastAssetDate() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        session.complete()
        // lastAssetDate 설정 안 함

        store.save(session)

        // Then - lastAssetDate 없으면 이어서 정리 불가
        XCTAssertFalse(store.canContinue)
    }

    func testCannotContinueWhenNoSession() {
        // Given - 저장된 세션 없음

        // Then
        XCTAssertFalse(store.canContinue)
    }

    // MARK: - Update Tests

    func testPartialUpdate() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()
        store.save(session)

        let testDate = Date()

        // When - 동기 업데이트
        store.update(
            lastAssetDate: testDate,
            lastAssetID: "updated-id",
            scannedCount: 200,
            foundCount: 15
        )

        // Then - 메모리 캐시에 반영됨
        let updated = store.currentSession
        XCTAssertNotNil(updated)
        XCTAssertEqual(updated?.scannedCount, 200)
        XCTAssertEqual(updated?.foundCount, 15)
        XCTAssertEqual(updated?.lastAssetID, "updated-id")
    }

    // MARK: - Convenience Methods Tests

    func testPreviousSessionDescription() {
        // Given
        var session = CleanupSession(method: .fromLatest)
        session.startScanning()

        let calendar = Calendar.current
        var components = DateComponents()
        components.year = 2024
        components.month = 5
        components.day = 15
        let testDate = calendar.date(from: components)!

        session.updateProgress(
            scannedCount: 500,
            foundCount: 25,
            lastAssetDate: testDate,
            lastAssetID: "test-id"
        )
        session.complete()

        store.save(session)

        // When
        let description = store.previousSessionDescription()

        // Then
        XCTAssertNotNil(description)
        XCTAssertTrue(description!.contains("2024"))
        XCTAssertTrue(description!.contains("5"))
    }

    // MARK: - Persistence Tests

    func testSessionPersistsAcrossStoreInstances() {
        // Given
        var session = CleanupSession(method: .byYear(year: 2024))
        session.startScanning()
        session.updateProgress(
            scannedCount: 300,
            foundCount: 20,
            lastAssetDate: Date(),
            lastAssetID: "persist-test-id"
        )
        session.complete()

        // Save with first store
        store.save(session)

        // Create new store instance with same file
        let newStore = CleanupSessionStore(filePath: testFilePath)

        // Then
        let loaded = newStore.currentSession
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.method, .byYear(year: 2024))
        XCTAssertEqual(loaded?.scannedCount, 300)
        XCTAssertEqual(loaded?.foundCount, 20)
        XCTAssertEqual(loaded?.status, .completed)
    }
}

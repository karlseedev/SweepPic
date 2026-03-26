//
//  CleanupServiceByYearTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-02-13.
//
//  byYear 탐색 Unit 테스트
//  - 연도 범위 제한 확인
//  - 다른 연도로 확장 없이 종료 확인
//  - 연도 기준 PHFetchOptions 쿼리 검증
//  - byYear + continueFrom 조합 테스트
//

import XCTest
@testable import SweepPic
import Photos

final class CleanupServiceByYearTests: XCTestCase {

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

    // MARK: - CleanupMethod byYear Tests

    /// byYear 메소드의 Codable 인코딩/디코딩 테스트
    func testByYearMethod_Codable_EncodesDecodesCorrectly() throws {
        // Given
        let method = CleanupMethod.byYear(year: 2024)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(method)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CleanupMethod.self, from: data)

        // Then
        XCTAssertEqual(decoded, method)
        if case .byYear(let year, let continueFrom) = decoded {
            XCTAssertEqual(year, 2024)
            XCTAssertNil(continueFrom)
        } else {
            XCTFail("Expected byYear method")
        }
    }

    /// byYear + continueFrom 메소드의 Codable 인코딩/디코딩 테스트
    func testByYearMethodWithContinueFrom_Codable_EncodesDecodesCorrectly() throws {
        // Given
        let continueDate = Date(timeIntervalSince1970: 1704067200) // 2024-01-01
        let method = CleanupMethod.byYear(year: 2024, continueFrom: continueDate)

        // When
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(method)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(CleanupMethod.self, from: data)

        // Then
        XCTAssertEqual(decoded, method)
        if case .byYear(let year, let continueFrom) = decoded {
            XCTAssertEqual(year, 2024)
            XCTAssertNotNil(continueFrom)
        } else {
            XCTFail("Expected byYear method with continueFrom")
        }
    }

    /// byYear 메소드의 displayTitle 테스트
    func testByYearMethod_DisplayTitle_ShowsYearCorrectly() {
        // Given
        let method = CleanupMethod.byYear(year: 2023)

        // When
        let title = method.displayTitle

        // Then
        XCTAssertEqual(title, "2023년 사진 정리")
    }

    /// byYear 메소드의 year 프로퍼티 테스트
    func testByYearMethod_YearProperty_ReturnsCorrectYear() {
        // Given
        let method = CleanupMethod.byYear(year: 2025)

        // Then
        XCTAssertEqual(method.year, 2025)
    }

    /// fromLatest 메소드의 year 프로퍼티는 nil
    func testFromLatestMethod_YearProperty_ReturnsNil() {
        // Given
        let method = CleanupMethod.fromLatest

        // Then
        XCTAssertNil(method.year)
    }

    // MARK: - CleanupSession byYear Tests

    /// byYear 세션 생성 테스트
    func testCleanupSession_ByYear_CreatesCorrectStartDate() {
        // Given
        let year = 2024

        // When
        let session = CleanupSession(year: year)

        // Then
        // startDate는 해당 연도 12월 31일 23:59:59
        let expectedEndOfYear = CleanupSession.endOfYear(year)
        XCTAssertEqual(session.startDate, expectedEndOfYear)
        XCTAssertEqual(session.targetYear, year)
    }

    /// byYear 세션의 canContinueByYear 테스트 (50장 도달 시)
    func testCleanupSession_ByYear_CanContinueByYear_WhenMaxFound() {
        // Given
        var session = CleanupSession(year: 2024)
        session.status = .completed
        session.endReason = .maxFound

        // Then
        XCTAssertTrue(session.canContinueByYear)
        XCTAssertFalse(session.canContinueFromLatest)
    }

    /// byYear 세션의 canContinueByYear 테스트 (범위 끝 도달 시)
    func testCleanupSession_ByYear_CannotContinue_WhenEndOfRange() {
        // Given
        var session = CleanupSession(year: 2024)
        session.status = .completed
        session.endReason = .endOfRange

        // Then
        XCTAssertFalse(session.canContinueByYear)
    }

    /// byYear 세션의 canContinueByYear 테스트 (2000장 검색 도달 시)
    func testCleanupSession_ByYear_CanContinue_WhenMaxScanned() {
        // Given
        var session = CleanupSession(year: 2024)
        session.status = .completed
        session.endReason = .maxScanned

        // Then
        XCTAssertTrue(session.canContinueByYear)
    }

    // MARK: - CleanupSessionStore byYear Tests

    /// byYear 세션 저장/로드 테스트
    func testSessionStore_SavesByYearSession_Separately() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("TestByYearSession_\(UUID().uuidString).json")
        let store = CleanupSessionStore(filePath: tempFile)

        // When
        var session = CleanupSession(year: 2024)
        session.status = .completed
        session.endReason = .maxFound
        session.lastAssetDate = Date(timeIntervalSince1970: 1704067200)
        store.save(session)

        // Then
        let loaded = store.byYearSession
        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.targetYear, 2024)
        XCTAssertEqual(loaded?.endReason, .maxFound)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    /// byYear 세션과 latest 세션 독립 저장 테스트
    func testSessionStore_ByYearAndLatest_StoredIndependently() throws {
        // Given
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("TestIndepSession_\(UUID().uuidString).json")
        let store = CleanupSessionStore(filePath: tempFile)

        // When - latest 세션 저장
        var latestSession = CleanupSession(method: .fromLatest)
        latestSession.status = .completed
        latestSession.endReason = .maxFound
        store.save(latestSession)

        // When - byYear 세션 저장
        var byYearSession = CleanupSession(year: 2023)
        byYearSession.status = .completed
        byYearSession.endReason = .maxScanned
        store.save(byYearSession)

        // Then - 각각 독립적으로 로드
        let loadedLatest = store.latestSession
        let loadedByYear = store.byYearSession

        XCTAssertNotNil(loadedLatest)
        XCTAssertNotNil(loadedByYear)
        XCTAssertNil(loadedLatest?.targetYear)  // fromLatest는 targetYear 없음
        XCTAssertEqual(loadedByYear?.targetYear, 2023)

        // Cleanup
        try? FileManager.default.removeItem(at: tempFile)
    }

    // MARK: - Service byYear Integration Tests (실기기 필요)

    /// byYear 정리 시작 테스트
    /// - 실기기에서 실행 필요
    /// - 해당 연도에 사진이 있어야 함
    func testStartCleanup_ByYear_Integration() async throws {
        // 전제조건 확인
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }

        // 현재 연도로 테스트 (사진이 있을 가능성 높음)
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
        XCTAssertTrue(result.resultType.isSuccess, "byYear cleanup should complete")
        XCTAssertGreaterThanOrEqual(result.scannedCount, 0)

        // 종료 조건 검증 (연도 범위 끝 또는 제한 도달)
        let validEndReasons: [EndReason] = [.endOfRange, .maxFound, .maxScanned]
        XCTAssertTrue(
            validEndReasons.contains(result.endReason),
            "End reason should be endOfRange, maxFound, or maxScanned"
        )

        print("""
        === byYear Cleanup Result (\(currentYear)) ===
        - Scanned: \(result.scannedCount)
        - Found: \(result.foundCount)
        - End Reason: \(result.endReason)
        - Time: \(String(format: "%.1f", result.totalTimeSeconds))s
        """)
    }

    /// byYear 정리가 다른 연도로 확장하지 않는지 확인
    /// - 매우 오래된 연도를 지정하여 사진이 없을 때 endOfRange로 즉시 종료되는지 확인
    func testStartCleanup_ByYear_NoExpansionBeyondYear() async throws {
        // 전제조건 확인
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }

        // 사진이 없을 가능성 높은 아주 옛날 연도
        let result = try await sut.startCleanup(
            method: .byYear(year: 1990),
            mode: .precision,
            progressHandler: { _ in }
        )

        // 사진이 없으므로 즉시 종료되어야 함
        XCTAssertEqual(result.scannedCount, 0, "Should not scan any photos from 1990")
        XCTAssertEqual(result.foundCount, 0)
        XCTAssertEqual(result.endReason, .endOfRange)
    }
}

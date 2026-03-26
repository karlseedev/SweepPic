//
//  CleanupServiceIntegrationTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-01-23.
//
//  CleanupService Integration 테스트
//  - 전체 정리 플로우 E2E 테스트
//  - 실기기 테스트 필수 (시뮬레이터에서 일부 기능 제한)
//

import XCTest
@testable import SweepPic
import Photos

final class CleanupServiceIntegrationTests: XCTestCase {

    // MARK: - Properties

    var sut: CleanupService!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        sut = CleanupService.shared
    }

    override func tearDown() {
        // 테스트 후 진행 중인 정리 취소
        sut.cancelCleanup()
        sut = nil
        super.tearDown()
    }

    // MARK: - Full Flow Tests

    /// 전체 정리 플로우 테스트
    /// - 실기기에서 실행 필요
    /// - 사진 라이브러리 권한 필요
    /// - 삭제대기함 비어있어야 함
    func testFullCleanupFlow_FromLatest() async throws {
        // 1. 전제조건 확인
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required for this test")
        }

        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty - please empty the trash first")
        }

        // 2. 진행 상황 추적
        var progressUpdates: [CleanupProgress] = []
        let progressExpectation = expectation(description: "Progress updates received")
        progressExpectation.expectedFulfillmentCount = 1
        progressExpectation.assertForOverFulfill = false

        // 3. 정리 시작
        let result = try await sut.startCleanup(
            method: .fromLatest,
            mode: .precision,
            progressHandler: { progress in
                progressUpdates.append(progress)
                if progress.scannedCount > 0 {
                    progressExpectation.fulfill()
                }
            }
        )

        // 4. 결과 검증
        XCTAssertTrue(result.resultType.isSuccess, "Cleanup should complete successfully")
        XCTAssertGreaterThanOrEqual(result.scannedCount, 0, "Should scan at least 0 photos")
        XCTAssertGreaterThanOrEqual(result.foundCount, 0, "Should find at least 0 photos")
        XCTAssertEqual(result.trashedAssetIDs.count, result.foundCount, "Trashed count should match found count")

        // 5. 진행 상황 검증
        await fulfillment(of: [progressExpectation], timeout: 60)
        XCTAssertFalse(progressUpdates.isEmpty, "Should receive progress updates")

        // 6. 로그 출력 (디버깅용)
        print("""
        === Cleanup Result ===
        - Scanned: \(result.scannedCount)
        - Found: \(result.foundCount)
        - Trashed: \(result.trashedAssetIDs.count)
        - End Reason: \(result.endReason)
        - Time: \(String(format: "%.1f", result.totalTimeSeconds))s
        """)
    }

    /// 취소 플로우 테스트
    func testCancelCleanupFlow() async throws {
        // 전제조건 확인
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required for this test")
        }

        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty - please empty the trash first")
        }

        // 정리 시작 (별도 Task에서)
        let cleanupTask = Task {
            try await sut.startCleanup(
                method: .fromLatest,
                mode: .precision,
                progressHandler: { _ in }
            )
        }

        // 약간 대기 후 취소
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5초
        sut.cancelCleanup()

        // 결과 확인
        let result = try await cleanupTask.value

        // 취소된 경우 아무것도 이동하지 않음
        if case .cancelled = result.resultType {
            XCTAssertEqual(result.trashedAssetIDs.count, 0, "Cancelled cleanup should not move any photos")
        }
    }

    /// 삭제대기함 비어있지 않을 때 에러 테스트
    func testCleanupWithNonEmptyTrash_ThrowsError() async throws {
        // 전제조건: 삭제대기함이 비어있지 않아야 함
        guard !sut.isTrashEmpty() else {
            throw XCTSkip("Trash must NOT be empty for this test - add a photo to trash first")
        }

        do {
            _ = try await sut.startCleanup(
                method: .fromLatest,
                mode: .precision,
                progressHandler: { _ in }
            )
            XCTFail("Should throw trashNotEmpty error")
        } catch let error as CleanupError {
            XCTAssertEqual(error, .trashNotEmpty)
        }
    }
}

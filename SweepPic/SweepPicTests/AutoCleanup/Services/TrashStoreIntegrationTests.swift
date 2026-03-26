//
//  TrashStoreIntegrationTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-02-13.
//
//  TrashStore Integration 테스트
//  - 자동 정리 → 삭제대기함 이동 → 복구 플로우 검증
//  - TrashStore API와 CleanupService 연동 확인
//  - 실기기 테스트 필수
//

import XCTest
@testable import SweepPic
import AppCore
import Photos

final class TrashStoreIntegrationTests: XCTestCase {

    // MARK: - Properties

    var trashStore: TrashStoreProtocol!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        trashStore = TrashStore.shared
    }

    override func tearDown() {
        trashStore = nil
        super.tearDown()
    }

    // MARK: - moveToTrash Tests

    /// moveToTrash 후 isTrashed 확인
    func testMoveToTrash_AssetBecomesTrashed() {
        // Given
        let testAssetID = "test_auto_cleanup_\(UUID().uuidString)"

        // When
        trashStore.moveToTrash(assetIDs: [testAssetID])

        // Then
        XCTAssertTrue(trashStore.isTrashed(testAssetID),
                      "Asset should be in trash after moveToTrash")
        XCTAssertTrue(trashStore.trashedAssetIDs.contains(testAssetID))

        // Cleanup: 테스트 ID 복구
        trashStore.restore(assetIDs: [testAssetID])
    }

    /// 여러 사진 배치 moveToTrash 테스트
    func testMoveToTrash_BatchOperation() {
        // Given
        let testIDs = (1...5).map { "test_batch_\($0)_\(UUID().uuidString)" }
        let initialCount = trashStore.trashedCount

        // When
        trashStore.moveToTrash(assetIDs: testIDs)

        // Then
        XCTAssertEqual(trashStore.trashedCount, initialCount + testIDs.count,
                       "Trash count should increase by batch size")
        for id in testIDs {
            XCTAssertTrue(trashStore.isTrashed(id))
        }

        // Cleanup
        trashStore.restore(assetIDs: testIDs)
    }

    // MARK: - restore Tests

    /// restore 후 isTrashed == false 확인
    func testRestore_AssetNoLongerTrashed() {
        // Given
        let testAssetID = "test_restore_\(UUID().uuidString)"
        trashStore.moveToTrash(assetIDs: [testAssetID])
        XCTAssertTrue(trashStore.isTrashed(testAssetID))

        // When
        trashStore.restore(assetIDs: [testAssetID])

        // Then
        XCTAssertFalse(trashStore.isTrashed(testAssetID),
                       "Asset should not be in trash after restore")
    }

    /// 여러 사진 배치 restore 테스트
    func testRestore_BatchOperation() {
        // Given
        let testIDs = (1...3).map { "test_batch_restore_\($0)_\(UUID().uuidString)" }
        trashStore.moveToTrash(assetIDs: testIDs)
        let countAfterTrash = trashStore.trashedCount

        // When
        trashStore.restore(assetIDs: testIDs)

        // Then
        XCTAssertEqual(trashStore.trashedCount, countAfterTrash - testIDs.count,
                       "Trash count should decrease by batch size")
        for id in testIDs {
            XCTAssertFalse(trashStore.isTrashed(id))
        }
    }

    // MARK: - Auto Cleanup → Restore Flow Tests

    /// 자동 정리로 이동된 사진이 복구 가능한지 확인
    /// - 시뮬레이션: moveToTrash → restore → 상태 확인
    func testAutoCleanupRestoreFlow_Simulation() {
        // Given: 자동 정리에서 발견된 저품질 사진 시뮬레이션
        let foundAssetIDs = (1...10).map { "auto_cleanup_found_\($0)_\(UUID().uuidString)" }
        let initialCount = trashStore.trashedCount

        // Step 1: 자동 정리 → 삭제대기함 이동 (CleanupService.moveToTrash 시뮬레이션)
        trashStore.moveToTrash(assetIDs: foundAssetIDs)
        XCTAssertEqual(trashStore.trashedCount, initialCount + foundAssetIDs.count)

        // Step 2: 모든 사진이 삭제대기함에 있는지 확인
        for id in foundAssetIDs {
            XCTAssertTrue(trashStore.isTrashed(id),
                          "All auto-cleanup photos should be in trash")
        }

        // Step 3: 일부 복구 (사용자가 삭제대기함에서 선택 복구)
        let restoreIDs = Array(foundAssetIDs.prefix(3))
        trashStore.restore(assetIDs: restoreIDs)

        for id in restoreIDs {
            XCTAssertFalse(trashStore.isTrashed(id),
                           "Restored photos should not be in trash")
        }

        // Step 4: 나머지는 여전히 삭제대기함에 있는지 확인
        let remainingIDs = Array(foundAssetIDs.suffix(from: 3))
        for id in remainingIDs {
            XCTAssertTrue(trashStore.isTrashed(id),
                          "Non-restored photos should still be in trash")
        }

        // Cleanup: 남은 테스트 데이터 정리
        trashStore.restore(assetIDs: remainingIDs)
    }

    /// trashedCount == 0 일 때 CleanupService 시작 가능 확인
    func testCleanupService_CanStart_WhenTrashEmpty() {
        // Given: 삭제대기함이 비어있는지 확인
        let cleanupService = CleanupService.shared

        if trashStore.trashedCount == 0 {
            // Then: 정리 시작 가능
            XCTAssertTrue(cleanupService.isTrashEmpty())
        } else {
            // Then: 정리 시작 불가
            XCTAssertFalse(cleanupService.isTrashEmpty())
        }
    }

    /// trashedCount > 0 일 때 CleanupService 시작 불가 확인
    func testCleanupService_CannotStart_WhenTrashNotEmpty() {
        // Given: 테스트 사진 추가
        let testID = "test_not_empty_\(UUID().uuidString)"
        trashStore.moveToTrash(assetIDs: [testID])

        // Then: 정리 시작 불가
        let cleanupService = CleanupService.shared
        XCTAssertFalse(cleanupService.isTrashEmpty(),
                       "Should not be able to start cleanup with non-empty trash")

        // Cleanup
        trashStore.restore(assetIDs: [testID])
    }

    /// onStateChange 콜백 테스트
    func testOnStateChange_CalledAfterMoveToTrash() {
        // Given
        let expectation = expectation(description: "State change callback")
        let testID = "test_callback_\(UUID().uuidString)"

        trashStore.onStateChange { trashedIDs in
            if trashedIDs.contains(testID) {
                expectation.fulfill()
            }
        }

        // When
        trashStore.moveToTrash(assetIDs: [testID])

        // Then
        waitForExpectations(timeout: 2)

        // Cleanup
        trashStore.restore(assetIDs: [testID])
    }
}

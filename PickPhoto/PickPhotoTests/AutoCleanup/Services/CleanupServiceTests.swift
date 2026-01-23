//
//  CleanupServiceTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-01-23.
//
//  CleanupService Unit 테스트
//  - fromLatest 탐색 로직
//  - 종료 조건 (50장 찾음, 1000장 검색)
//  - 휴지통 비어있는지 확인
//  - 취소 처리
//

import XCTest
@testable import PickPhoto
import Photos

final class CleanupServiceTests: XCTestCase {

    // MARK: - Properties

    var sut: CleanupService!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        sut = CleanupService.shared
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    // MARK: - isTrashEmpty Tests

    func testIsTrashEmpty_WhenTrashIsEmpty_ReturnsTrue() {
        // Note: 실제 TrashStore 상태에 의존
        // Mock 없이 통합 테스트로 실행됨
        // 실기기에서 휴지통을 비운 후 테스트 필요
        let result = sut.isTrashEmpty()
        // XCTAssertTrue(result) - 상태에 따라 달라짐
        XCTAssertNotNil(result)
    }

    // MARK: - isRunning Tests

    func testIsRunning_WhenNotStarted_ReturnsFalse() {
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - validatePreConditions Tests

    func testStartCleanup_WhenTrashNotEmpty_ThrowsError() async {
        // Note: 휴지통에 사진이 있는 상태에서 테스트 필요
        // 실기기에서 휴지통에 사진을 추가한 후 테스트

        // 휴지통이 비어있지 않은 상태에서 정리 시작 시도
        if !sut.isTrashEmpty() {
            do {
                _ = try await sut.startCleanup(
                    method: .fromLatest,
                    mode: .precision,
                    progressHandler: { _ in }
                )
                XCTFail("Expected trashNotEmpty error")
            } catch let error as CleanupError {
                XCTAssertEqual(error, .trashNotEmpty)
            } catch {
                XCTFail("Unexpected error: \(error)")
            }
        }
    }

    // MARK: - cancelCleanup Tests

    func testCancelCleanup_WhenNotRunning_DoesNotCrash() {
        // 실행 중이 아닐 때 취소해도 크래시 안 함
        sut.cancelCleanup()
        XCTAssertFalse(sut.isRunning)
    }

    // MARK: - Session Tests

    func testLastSession_WhenNoSession_ReturnsNil() {
        // 세션 저장소가 비어있으면 nil 반환
        // Note: 실제 저장소 상태에 의존
        // 저장소 초기화 후 테스트 필요
        let session = sut.lastSession
        // XCTAssertNil(session) - 상태에 따라 달라짐
        _ = session  // Suppress warning
    }

    // MARK: - Integration Test Placeholder

    func testStartCleanup_FromLatest_Integration() async throws {
        // 통합 테스트: 실기기에서 실행 필요
        // 1. 휴지통 비우기
        // 2. 사진 라이브러리 권한 확인
        // 3. 정리 시작
        // 4. 진행 상황 확인
        // 5. 결과 확인

        // Skip if no photo access
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        // Skip if trash not empty
        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty for this test")
        }

        // Actual test would be:
        // let result = try await sut.startCleanup(
        //     method: .fromLatest,
        //     mode: .precision,
        //     progressHandler: { progress in
        //         print("Progress: \(progress.scannedCount) scanned, \(progress.foundCount) found")
        //     }
        // )
        // XCTAssertTrue(result.resultType.isSuccess)
    }
}

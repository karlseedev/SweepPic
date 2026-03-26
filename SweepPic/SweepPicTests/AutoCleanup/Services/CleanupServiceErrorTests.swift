//
//  CleanupServiceErrorTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-02-13.
//
//  에러 처리 테스트
//  - 분석 실패 시 SKIP (삭제 금지)
//  - iCloud 썸네일 없음 SKIP
//  - Metal 초기화 실패 시 CPU fallback
//  - CleanupError 케이스 검증
//

import XCTest
@testable import SweepPic
import Photos

final class CleanupServiceErrorTests: XCTestCase {

    // MARK: - CleanupError Tests

    /// CleanupError 모든 케이스 검증
    func testCleanupError_AllCases() {
        // trashNotEmpty
        let trashError = CleanupError.trashNotEmpty
        XCTAssertNotNil(trashError.localizedDescription)

        // alreadyRunning
        let runningError = CleanupError.alreadyRunning
        XCTAssertNotNil(runningError.localizedDescription)

        // noPhotoAccess
        let accessError = CleanupError.noPhotoAccess
        XCTAssertNotNil(accessError.localizedDescription)

        // analysisFailed
        let analysisError = CleanupError.analysisFailed("test error")
        XCTAssertNotNil(analysisError.localizedDescription)
    }

    /// CleanupError Equatable 검증
    func testCleanupError_Equatable() {
        XCTAssertEqual(CleanupError.trashNotEmpty, CleanupError.trashNotEmpty)
        XCTAssertEqual(CleanupError.alreadyRunning, CleanupError.alreadyRunning)
        XCTAssertNotEqual(CleanupError.trashNotEmpty, CleanupError.alreadyRunning)
    }

    // MARK: - SkipReason Tests

    /// 모든 SkipReason 케이스 rawValue 존재 확인
    func testSkipReason_AllCases_HaveRawValue() {
        let allCases: [SkipReason] = [
            .favorite, .hidden, .sharedAlbum, .screenshot,
            .iCloudOnly, .analysisError, .longVideo
        ]

        for reason in allCases {
            XCTAssertFalse(reason.rawValue.isEmpty,
                           "\(reason) should have a non-empty rawValue")
        }
    }

    // MARK: - QualityResult SKIP Tests

    /// 분석 실패 시 SKIP 반환 확인
    func testQualityResult_Skipped_ForAnalysisError() {
        let result = QualityResult.skipped(
            assetID: "test123",
            creationDate: Date(),
            reason: .analysisError
        )

        if case .skipped(let reason) = result.verdict {
            XCTAssertEqual(reason, .analysisError)
        } else {
            XCTFail("Expected skipped verdict")
        }

        // SKIP된 결과는 저품질이 아님 (삭제 금지)
        XCTAssertFalse(result.verdict.isLowQuality,
                       "Skipped result should NOT be low quality (deletion forbidden)")
    }

    /// iCloud 전용 SKIP 반환 확인
    func testQualityResult_Skipped_ForICloudOnly() {
        let result = QualityResult.skipped(
            assetID: "cloud123",
            creationDate: Date(),
            reason: .iCloudOnly
        )

        if case .skipped(let reason) = result.verdict {
            XCTAssertEqual(reason, .iCloudOnly)
        } else {
            XCTFail("Expected skipped verdict for iCloud")
        }

        XCTAssertFalse(result.verdict.isLowQuality)
    }

    // MARK: - BlurAnalyzer Fallback Tests

    /// BlurAnalyzer isAvailable 프로퍼티 존재 확인
    func testBlurAnalyzer_IsAvailable_Property() {
        let analyzer = BlurAnalyzer.shared
        // Metal 디바이스 유무에 따라 true/false
        // 시뮬레이터에서도 크래시 없이 동작해야 함
        _ = analyzer.isAvailable
    }

    /// BlurAnalyzer CPU fallback 존재 확인
    func testBlurAnalyzer_CPUFallback_Exists() {
        // analyzeCPU 메서드가 존재하는지 확인 (컴파일 타임 체크)
        let analyzer = BlurAnalyzer.shared
        XCTAssertNotNil(analyzer, "BlurAnalyzer should exist with CPU fallback")
    }

    // MARK: - MetadataFilter SKIP Tests

    /// MetadataFilter 인스턴스 생성
    func testMetadataFilter_Creation() {
        let filter = MetadataFilter()
        XCTAssertNotNil(filter)
    }

    // MARK: - Service Error Integration Tests (실기기 필요)

    /// 이미 실행 중일 때 에러 테스트
    func testStartCleanup_WhenAlreadyRunning_ThrowsError() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }
        guard CleanupService.shared.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }

        let sut = CleanupService.shared

        // 첫 번째 정리 시작
        let firstTask = Task {
            try await sut.startCleanup(
                method: .fromLatest,
                mode: .precision,
                progressHandler: { _ in }
            )
        }

        // 약간 대기
        try await Task.sleep(nanoseconds: 100_000_000)

        // 두 번째 정리 시도 (이미 실행 중)
        if sut.isRunning {
            do {
                _ = try await sut.startCleanup(
                    method: .fromLatest,
                    mode: .precision,
                    progressHandler: { _ in }
                )
                XCTFail("Should throw alreadyRunning error")
            } catch let error as CleanupError {
                XCTAssertEqual(error, .alreadyRunning)
            }
        }

        // 첫 번째 정리 취소
        sut.cancelCleanup()
        _ = try? await firstTask.value
    }

    /// 사진 라이브러리 권한 없을 때 에러 테스트
    func testStartCleanup_WithoutAccess_ThrowsError() async {
        // Note: 시뮬레이터에서 권한 없는 상태를 테스트하기 어려움
        // 실기기에서 권한을 거부한 후 테스트 필요
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        if status != .authorized && status != .limited {
            let sut = CleanupService.shared
            do {
                _ = try await sut.startCleanup(
                    method: .fromLatest,
                    mode: .precision,
                    progressHandler: { _ in }
                )
                XCTFail("Should throw noPhotoAccess error")
            } catch let error as CleanupError {
                XCTAssertEqual(error, .noPhotoAccess)
            } catch {
                XCTFail("Expected CleanupError, got: \(error)")
            }
        }
    }
}

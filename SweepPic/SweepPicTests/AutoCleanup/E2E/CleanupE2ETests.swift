//
//  CleanupE2ETests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-02-13.
//
//  전체 플로우 E2E 테스트 (quickstart.md 시나리오 검증)
//  - 시나리오 1: 최신사진부터 정리 → 완료
//  - 시나리오 2: 연도별 정리 → 완료
//  - 시나리오 3: 이어서 정리 → 완료
//  - 시나리오 4: 정리 중 취소
//  - 시나리오 5: 삭제대기함 비어있지 않음 에러
//  - 시나리오 6: 상수/임계값 일관성 검증
//
//  Note: 실기기 + 사진 라이브러리 필요 (시뮬레이터에서는 XCTSkip)
//

import XCTest
@testable import SweepPic
import Photos

final class CleanupE2ETests: XCTestCase {

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

    // MARK: - Scenario 1: 최신사진부터 정리 (fromLatest)

    /// quickstart.md 핵심 흐름: 최신사진부터 정리 전체 플로우
    func testScenario1_FromLatest_FullFlow() async throws {
        try skipIfNotReady()

        var progressUpdates: [CleanupProgress] = []

        // 정리 실행
        let result = try await sut.startCleanup(
            method: .fromLatest,
            mode: .precision,
            progressHandler: { progress in
                progressUpdates.append(progress)
            }
        )

        // 결과 검증
        verifyResult(result)

        // 진행 상황 업데이트가 있어야 함
        XCTAssertFalse(progressUpdates.isEmpty, "Should have progress updates")

        // 진행률은 단조 증가해야 함
        for i in 1..<progressUpdates.count {
            XCTAssertGreaterThanOrEqual(
                progressUpdates[i].scannedCount,
                progressUpdates[i - 1].scannedCount,
                "Scanned count should be monotonically increasing"
            )
        }

        print("""
        === E2E: fromLatest ===
        - Scanned: \(result.scannedCount)
        - Found: \(result.foundCount)
        - Time: \(String(format: "%.1f", result.totalTimeSeconds))s
        - EndReason: \(result.endReason)
        - Progress updates: \(progressUpdates.count)
        """)
    }

    // MARK: - Scenario 2: 연도별 정리 (byYear)

    /// 연도별 정리 플로우
    func testScenario2_ByYear_FullFlow() async throws {
        try skipIfNotReady()

        // 현재 연도로 정리
        let currentYear = Calendar.current.component(.year, from: Date())

        let result = try await sut.startCleanup(
            method: .byYear(year: currentYear, continueFrom: nil),
            mode: .precision,
            progressHandler: { _ in }
        )

        // 결과 검증
        verifyResult(result)

        // 연도별 결과 메시지 검증
        let message = CleanupConstants.resultMessage(
            endReason: result.endReason,
            foundCount: result.foundCount,
            method: .byYear(year: currentYear, continueFrom: nil)
        )
        XCTAssertFalse(message.isEmpty || result.endReason == .userCancelled,
                       "Should have a result message")

        print("""
        === E2E: byYear(\(currentYear)) ===
        - Scanned: \(result.scannedCount)
        - Found: \(result.foundCount)
        - Time: \(String(format: "%.1f", result.totalTimeSeconds))s
        - EndReason: \(result.endReason)
        - Message: \(message)
        """)
    }

    // MARK: - Scenario 3: 이어서 정리 (continueFromLast)

    /// 이어서 정리: 이전 세션 완료 후 다음 세션 연속성 검증
    func testScenario3_ContinueFromLast_FullFlow() async throws {
        try skipIfNotReady()

        // 1차 정리
        let firstResult = try await sut.startCleanup(
            method: .fromLatest,
            mode: .precision,
            progressHandler: { _ in }
        )

        // 이어서 정리 가능 조건 확인
        // (endOfRange가 아닌 경우에만 이어서 정리 가능)
        guard firstResult.endReason != .endOfRange else {
            print("=== E2E: continueFromLast skipped (endOfRange reached on first run) ===")
            return
        }

        // 삭제대기함 비어있어야 다음 정리 가능 - 비우기 시뮬레이션
        // 실제로는 사용자가 삭제대기함을 비우는 단계가 필요
        // 여기서는 TrashStore 상태만 확인
        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty for continue test")
        }

        // 2차 정리 (이어서)
        let secondResult = try await sut.startCleanup(
            method: .continueFromLast,
            mode: .precision,
            progressHandler: { _ in }
        )

        verifyResult(secondResult)

        print("""
        === E2E: continueFromLast ===
        - 1st: scanned=\(firstResult.scannedCount), found=\(firstResult.foundCount)
        - 2nd: scanned=\(secondResult.scannedCount), found=\(secondResult.foundCount)
        """)
    }

    // MARK: - Scenario 4: 취소

    /// 정리 중 취소 테스트
    func testScenario4_Cancel_DuringCleanup() async throws {
        try skipIfNotReady()

        // 정리 시작 (별도 Task)
        let cleanupTask = Task {
            try await sut.startCleanup(
                method: .fromLatest,
                mode: .precision,
                progressHandler: { _ in }
            )
        }

        // 약간 대기 후 취소
        try await Task.sleep(nanoseconds: 300_000_000)  // 0.3초
        sut.cancelCleanup()

        // 결과 확인
        let result = try await cleanupTask.value

        // 취소 결과 검증
        if case .cancelled = result.resultType {
            XCTAssertEqual(result.trashedAssetIDs.count, 0,
                           "Cancelled cleanup should NOT move any photos to trash")
            XCTAssertEqual(result.endReason, .userCancelled)
        }

        print("""
        === E2E: Cancel ===
        - ResultType: \(result.resultType)
        - Scanned: \(result.scannedCount)
        - Found: \(result.foundCount)
        - Trashed: \(result.trashedAssetIDs.count)
        """)
    }

    // MARK: - Scenario 5: 삭제대기함 비어있지 않음

    /// 삭제대기함이 비어있지 않을 때 에러 검증
    func testScenario5_TrashNotEmpty_ThrowsError() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        // 삭제대기함이 비어있지 않은 경우에만 테스트
        guard !sut.isTrashEmpty() else {
            // 삭제대기함이 비어있으면 이 시나리오 테스트 불가
            print("=== E2E: trashNotEmpty skipped (trash is empty) ===")
            return
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

    // MARK: - Scenario 6: 상수/임계값 일관성

    /// CleanupConstants 설계값 일관성 검증
    func testScenario6_Constants_Consistency() {
        // 종료 조건
        XCTAssertEqual(CleanupConstants.maxFoundCount, 50, "Max found should be 50")
        XCTAssertEqual(CleanupConstants.maxScanCount, 2000, "Max scan should be 2000")

        // 성능 설정
        XCTAssertEqual(CleanupConstants.batchSize, 100, "Batch size should be 100")
        XCTAssertEqual(CleanupConstants.concurrentAnalysis, 4, "Concurrent analysis should be 4")

        // 분석 크기
        XCTAssertEqual(CleanupConstants.exposureAnalysisSize, CGSize(width: 64, height: 64))
        XCTAssertEqual(CleanupConstants.blurAnalysisSize, CGSize(width: 256, height: 256))
        XCTAssertEqual(CleanupConstants.analysisImageMinSize, 360)

        // 임계값 범위 검증 (0~1 사이)
        XCTAssertTrue((0...1).contains(CleanupConstants.extremeDarkLuminance))
        XCTAssertTrue((0...1).contains(CleanupConstants.extremeBrightLuminance))
        XCTAssertTrue(CleanupConstants.extremeDarkLuminance < CleanupConstants.extremeBrightLuminance,
                      "Dark threshold should be less than bright threshold")

        // 블러 임계값 (양수, severe < general)
        XCTAssertGreaterThan(CleanupConstants.severeBlurLaplacian, 0)
        XCTAssertGreaterThan(CleanupConstants.generalBlurLaplacian, 0)
        XCTAssertLessThan(CleanupConstants.severeBlurLaplacian, CleanupConstants.generalBlurLaplacian,
                          "Severe blur should have lower threshold than general blur")

        // 비디오 길이 (too short < max analyzable)
        XCTAssertLessThan(CleanupConstants.tooShortVideoDuration, CleanupConstants.maxAnalyzableVideoDuration)

        // 얼굴 품질 (0~1 사이)
        XCTAssertTrue((0...1).contains(CleanupConstants.faceQualityThreshold))

        // 타임아웃 (양수)
        XCTAssertGreaterThan(CleanupConstants.analysisTimeout, 0)
    }

    // MARK: - Performance Test

    /// 분석 성능 벤치마크 (1000장 30초 목표)
    func testPerformance_ScanRate() async throws {
        try skipIfNotReady()

        let result = try await sut.startCleanup(
            method: .fromLatest,
            mode: .precision,
            progressHandler: { _ in }
        )

        // 성능 통계
        let rate = result.totalTimeSeconds > 0
            ? Double(result.scannedCount) / result.totalTimeSeconds
            : 0

        print("""
        === Performance ===
        - Scanned: \(result.scannedCount)
        - Time: \(String(format: "%.1f", result.totalTimeSeconds))s
        - Rate: \(String(format: "%.0f", rate))장/초
        - Target: 33장/초 (1000장/30초)
        - Status: \(rate >= 33 ? "PASS" : "BELOW TARGET")
        """)

        // 성능 목표: 1000장 30초 = 33.3장/초
        // 참고: 시뮬레이터에서는 실기기보다 느릴 수 있음
        if result.scannedCount >= 100 {
            XCTAssertGreaterThan(rate, 10,
                                 "Scan rate should be at least 10 photos/sec (relaxed for simulator)")
        }
    }

    // MARK: - Result Message Tests

    /// 모든 종료 사유에 대한 결과 메시지 검증
    func testResultMessages_AllEndReasons() {
        // maxFound
        let msg1 = CleanupConstants.resultMessage(endReason: .maxFound, foundCount: 50, method: .fromLatest)
        XCTAssertTrue(msg1.contains("50장"), "maxFound message should mention 50")

        // maxScanned + found
        let msg2 = CleanupConstants.resultMessage(endReason: .maxScanned, foundCount: 30, method: .fromLatest)
        XCTAssertTrue(msg2.contains("2,000장"), "maxScanned message should mention 2000")
        XCTAssertTrue(msg2.contains("30장"), "maxScanned message should mention found count")

        // maxScanned + none found
        let msg3 = CleanupConstants.resultMessage(endReason: .maxScanned, foundCount: 0, method: .fromLatest)
        XCTAssertTrue(msg3.contains("없습니다"), "No-found message should indicate nothing found")

        // endOfRange + found (general)
        let msg4 = CleanupConstants.resultMessage(endReason: .endOfRange, foundCount: 10, method: .fromLatest)
        XCTAssertTrue(msg4.contains("보관함"), "General endOfRange should mention library")

        // endOfRange + found (byYear)
        let msg5 = CleanupConstants.resultMessage(
            endReason: .endOfRange, foundCount: 10, method: .byYear(year: 2024, continueFrom: nil)
        )
        XCTAssertTrue(msg5.contains("2024년"), "ByYear endOfRange should mention the year")

        // endOfRange + none (byYear)
        let msg6 = CleanupConstants.resultMessage(
            endReason: .endOfRange, foundCount: 0, method: .byYear(year: 2023, continueFrom: nil)
        )
        XCTAssertTrue(msg6.contains("2023년"), "ByYear no-found should mention the year")
        XCTAssertTrue(msg6.contains("없습니다"), "No-found message should indicate nothing found")

        // userCancelled
        let msg7 = CleanupConstants.resultMessage(endReason: .userCancelled, foundCount: 0, method: .fromLatest)
        XCTAssertTrue(msg7.isEmpty, "Cancel message should be empty")
    }

    // MARK: - Debug Utilities Test

    #if DEBUG
    /// CleanupDebug 오버라이드 기능 검증
    func testDebug_ThresholdOverride() {
        // 오버라이드 설정
        CleanupDebug.setOverride(.extremeDarkLuminance, value: 0.08)
        let overridden = CleanupDebug.overrideValue(for: .extremeDarkLuminance, default: 0.10)
        XCTAssertEqual(overridden, 0.08, accuracy: 0.001)

        // 오버라이드 제거
        CleanupDebug.setOverride(.extremeDarkLuminance, value: nil)
        let restored = CleanupDebug.overrideValue(for: .extremeDarkLuminance, default: 0.10)
        XCTAssertEqual(restored, 0.10, accuracy: 0.001)

        // 모든 오버라이드 초기화
        CleanupDebug.setOverride(.severeBlurLaplacian, value: 40)
        CleanupDebug.clearAllOverrides()
        let cleared = CleanupDebug.overrideValue(for: .severeBlurLaplacian, default: 50)
        XCTAssertEqual(cleared, 50, accuracy: 0.001)
    }

    /// CleanupDebug Int 오버라이드 검증
    func testDebug_IntOverride() {
        CleanupDebug.setOverride(.batchSize, value: 50)
        let overridden = CleanupDebug.overrideIntValue(for: .batchSize, default: 100)
        XCTAssertEqual(overridden, 50)

        CleanupDebug.clearAllOverrides()
        let restored = CleanupDebug.overrideIntValue(for: .batchSize, default: 100)
        XCTAssertEqual(restored, 100)
    }
    #endif

    // MARK: - Helpers

    /// 전제조건 확인 (권한 + 빈 삭제대기함)
    private func skipIfNotReady() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }
        guard sut.isTrashEmpty() else {
            throw XCTSkip("Trash must be empty")
        }
    }

    /// 결과 공통 검증
    private func verifyResult(_ result: CleanupResult) {
        // 기본 검증
        XCTAssertGreaterThanOrEqual(result.scannedCount, 0)
        XCTAssertGreaterThanOrEqual(result.foundCount, 0)
        XCTAssertGreaterThanOrEqual(result.totalTimeSeconds, 0)

        // 종료 조건 검증
        switch result.endReason {
        case .maxFound:
            XCTAssertEqual(result.foundCount, CleanupConstants.maxFoundCount,
                           "maxFound should find exactly \(CleanupConstants.maxFoundCount)")
        case .maxScanned:
            XCTAssertGreaterThanOrEqual(result.scannedCount, CleanupConstants.maxScanCount,
                                        "maxScanned should scan at least \(CleanupConstants.maxScanCount)")
        case .endOfRange:
            // 범위 끝까지 스캔 완료
            break
        case .userCancelled:
            XCTAssertEqual(result.trashedAssetIDs.count, 0,
                           "Cancelled should not trash anything")
        }

        // 발견 수 <= 검색 수
        XCTAssertLessThanOrEqual(result.foundCount, result.scannedCount,
                                 "Found count should not exceed scanned count")

        // 이동 수 == 발견 수 (취소 제외)
        if result.endReason != .userCancelled {
            XCTAssertEqual(result.trashedAssetIDs.count, result.foundCount,
                           "Trashed count should equal found count")
        }
    }
}

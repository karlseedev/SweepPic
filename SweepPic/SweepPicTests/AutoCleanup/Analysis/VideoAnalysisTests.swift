//
//  VideoAnalysisTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-02-13.
//
//  비디오 분석 테스트
//  - VideoFrameExtractor: 프레임 추출, iCloud SKIP
//  - QualityAnalyzer: 비디오 분석 통합 (3프레임 중앙값 판정)
//  - 1초 미만 즉시 저품질 판정
//  - 5초 초과 SKIP 처리
//

import XCTest
@testable import SweepPic
import Photos

final class VideoAnalysisTests: XCTestCase {

    // MARK: - VideoFrameExtractor Tests

    /// VideoFrameExtractor 인스턴스 생성
    func testVideoFrameExtractor_SharedInstance() {
        let extractor = VideoFrameExtractor.shared
        XCTAssertNotNil(extractor, "Shared instance should exist")
    }

    // MARK: - MetadataFilter Video Tests

    /// 5초 초과 비디오 SKIP 테스트
    /// - MetadataFilter에서 longVideo로 SKIP 처리
    func testMetadataFilter_LongVideo_ReturnsSkipReason() {
        let filter = MetadataFilter()

        // 5초 이하 비디오: 분석 대상 (nil)
        // 5초 초과 비디오: SKIP (.longVideo)
        // Note: 실제 PHAsset은 시뮬레이터에서 생성 불가하므로
        // CleanupConstants 값만 검증
        XCTAssertEqual(CleanupConstants.maxAnalyzableVideoDuration, 5.0,
                       "Max analyzable video duration should be 5 seconds")
    }

    /// 1초 미만 비디오 상수 검증
    func testConstants_TooShortVideoDuration() {
        XCTAssertEqual(CleanupConstants.tooShortVideoDuration, 1.0,
                       "Too short video duration should be 1 second")
    }

    // MARK: - QualityAnalyzer Video Integration Tests (실기기 필요)

    /// 동영상 분석 통합 테스트
    /// - 실기기에서 실행 필요
    /// - 사진 라이브러리에 5초 이하 동영상이 있어야 함
    func testVideoAnalysis_Integration() async throws {
        // 전제조건
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        // 5초 이하 동영상 찾기
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND duration > 0 AND duration <= %f",
            PHAssetMediaType.video.rawValue,
            CleanupConstants.maxAnalyzableVideoDuration
        )
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: options)
        guard let videoAsset = result.firstObject else {
            throw XCTSkip("No short video (≤5s) found in library")
        }

        // 분석 실행
        let analyzer = QualityAnalyzer.shared
        let qualityResult = await analyzer.analyze(videoAsset)

        // 결과 검증 (동영상은 lowQuality, acceptable, skipped 중 하나)
        switch qualityResult.verdict {
        case .lowQuality:
            // 2개 이상 프레임이 저품질
            XCTAssertGreaterThan(qualityResult.signals.count, 0)
        case .acceptable:
            // 정상 품질
            break
        case .skipped:
            // iCloud 전용 등으로 SKIP
            break
        }

        XCTAssertGreaterThan(qualityResult.analysisTimeMs, 0,
                             "Analysis time should be tracked")

        print("""
        === Video Analysis Result ===
        - Asset ID: \(qualityResult.assetID.prefix(8))
        - Duration: \(videoAsset.duration)s
        - Verdict: \(qualityResult.verdict)
        - Signals: \(qualityResult.signals.count)
        - Time: \(String(format: "%.1f", qualityResult.analysisTimeMs))ms
        """)
    }

    /// 1초 미만 동영상 저품질 판정 테스트
    /// - 실기기에서 실행 필요
    func testVeryShortVideo_LowQuality() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        // 1초 미만 동영상 찾기
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND duration > 0 AND duration < %f",
            PHAssetMediaType.video.rawValue,
            CleanupConstants.tooShortVideoDuration
        )
        options.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: options)
        guard let shortVideo = result.firstObject else {
            throw XCTSkip("No very short video (<1s) found in library")
        }

        // 분석 실행
        let analyzer = QualityAnalyzer.shared
        let qualityResult = await analyzer.analyze(shortVideo)

        // 1초 미만은 저품질 확정
        XCTAssertTrue(qualityResult.verdict.isLowQuality,
                      "Video under 1 second should be low quality")

        // tooShortVideo 신호 확인
        let hasTooShortSignal = qualityResult.signals.contains { $0.kind == .tooShortVideo }
        XCTAssertTrue(hasTooShortSignal,
                      "Should have tooShortVideo signal")
    }

    /// 5초 초과 동영상 SKIP 테스트
    /// - 실기기에서 실행 필요
    func testLongVideo_SkippedByMetadataFilter() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        // 5초 초과 동영상 찾기
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND duration > %f",
            PHAssetMediaType.video.rawValue,
            CleanupConstants.maxAnalyzableVideoDuration
        )
        options.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: options)
        guard let longVideo = result.firstObject else {
            throw XCTSkip("No long video (>5s) found in library")
        }

        // 분석 실행
        let analyzer = QualityAnalyzer.shared
        let qualityResult = await analyzer.analyze(longVideo)

        // 5초 초과는 SKIP
        if case .skipped(let reason) = qualityResult.verdict {
            XCTAssertEqual(reason, .longVideo,
                           "Long video should be skipped with .longVideo reason")
        } else {
            XCTFail("Long video should be skipped, got: \(qualityResult.verdict)")
        }
    }

    // MARK: - VideoFrameExtractor Integration Tests (실기기 필요)

    /// 프레임 추출 테스트
    func testFrameExtraction_Integration() async throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        // 1~5초 동영상 찾기
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND duration >= %f AND duration <= %f",
            PHAssetMediaType.video.rawValue,
            CleanupConstants.tooShortVideoDuration,
            CleanupConstants.maxAnalyzableVideoDuration
        )
        options.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: options)
        guard let videoAsset = result.firstObject else {
            throw XCTSkip("No analyzable video (1-5s) found in library")
        }

        // 프레임 추출
        let extractor = VideoFrameExtractor.shared
        let frames = try await extractor.extractFrames(from: videoAsset)

        // 1~3개 프레임이 추출되어야 함
        XCTAssertGreaterThan(frames.count, 0, "Should extract at least 1 frame")
        XCTAssertLessThanOrEqual(frames.count, 3, "Should extract at most 3 frames")

        print("Extracted \(frames.count) frames from \(videoAsset.duration)s video")
    }
}

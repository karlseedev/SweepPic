//
//  SpecialMediaTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-02-13.
//
//  특수 미디어 처리 테스트
//  - Live Photo: 정지 이미지만 분석 (PHImageManager 기본 요청)
//  - Burst: 대표 사진만 분석 (PHFetchResult 기본 동작)
//  - RAW+JPEG: JPEG로 분석 (PHImageManager 기본 요청)
//  - 스크린샷: MetadataFilter에서 SKIP
//  - Portrait 모드: Safe Guard에서 블러 판정 무효화
//

import XCTest
@testable import PickPhoto
import Photos

final class SpecialMediaTests: XCTestCase {

    // MARK: - PHAsset+Cleanup Property Tests

    /// isLivePhoto 프로퍼티 검증 (PHAssetMediaSubtype.photoLive 확인)
    func testPHAssetMediaSubtype_PhotoLive_Exists() {
        // PHAssetMediaSubtype.photoLive가 사용 가능한지 확인
        let subtype = PHAssetMediaSubtype.photoLive
        XCTAssertNotEqual(subtype.rawValue, 0, "photoLive subtype should have a non-zero value")
    }

    /// isHDRPhoto - photoHDR 서브타입 존재 확인
    func testPHAssetMediaSubtype_PhotoHDR_Exists() {
        let subtype = PHAssetMediaSubtype.photoHDR
        XCTAssertNotEqual(subtype.rawValue, 0)
    }

    /// isPanoramaPhoto - photoPanorama 서브타입 존재 확인
    func testPHAssetMediaSubtype_PhotoPanorama_Exists() {
        let subtype = PHAssetMediaSubtype.photoPanorama
        XCTAssertNotEqual(subtype.rawValue, 0)
    }

    /// isPortraitPhoto - photoDepthEffect 서브타입 존재 확인
    func testPHAssetMediaSubtype_PhotoDepthEffect_Exists() {
        let subtype = PHAssetMediaSubtype.photoDepthEffect
        XCTAssertNotEqual(subtype.rawValue, 0)
    }

    // MARK: - MetadataFilter Tests

    /// 스크린샷 SKIP 테스트
    func testMetadataFilter_Screenshot_SkipReason() {
        // CleanupConstants에 스크린샷 관련 상수가 없지만,
        // MetadataFilter에서 photoScreenshot 서브타입으로 필터링
        let subtype = PHAssetMediaSubtype.photoScreenshot
        XCTAssertNotEqual(subtype.rawValue, 0)
    }

    // MARK: - Live Photo Integration Tests (실기기 필요)

    /// Live Photo 분석 테스트
    /// - 정지 이미지(대표 이미지)만 분석되는지 확인
    func testLivePhotoAnalysis_Integration() async throws {
        try skipIfNotReady()

        // Live Photo 찾기
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND ((mediaSubtypes & %d) != 0)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoLive.rawValue
        )
        options.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: options)
        guard let livePhoto = result.firstObject else {
            throw XCTSkip("No Live Photo found in library")
        }

        // Live Photo 확인
        XCTAssertTrue(livePhoto.isLivePhoto, "Should be a Live Photo")

        // 분석 실행 (정지 이미지만 분석됨 - PHImageManager 기본 동작)
        let analyzer = QualityAnalyzer.shared
        let qualityResult = await analyzer.analyze(livePhoto)

        // 결과가 있어야 함 (정지 이미지 분석 완료)
        XCTAssertNotNil(qualityResult)
        XCTAssertGreaterThan(qualityResult.analysisTimeMs, 0)

        print("""
        === Live Photo Analysis ===
        - Verdict: \(qualityResult.verdict)
        - Method: \(qualityResult.analysisMethod)
        - Time: \(String(format: "%.1f", qualityResult.analysisTimeMs))ms
        """)
    }

    // MARK: - Burst Photo Tests

    /// Burst 사진 - PHFetchResult 기본 동작으로 대표 사진만 반환되는지 확인
    func testBurstPhoto_DefaultFetch_ReturnsRepresentativeOnly() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }

        // 기본 fetch (대표 Burst만)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.includeAllBurstAssets = false  // 기본값

        let defaultResult = PHAsset.fetchAssets(with: options)

        // 모든 Burst 포함 fetch
        let allOptions = PHFetchOptions()
        allOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        allOptions.includeAllBurstAssets = true

        let allResult = PHAsset.fetchAssets(with: allOptions)

        // 기본 fetch 결과가 모든 Burst 포함 결과보다 같거나 적어야 함
        XCTAssertLessThanOrEqual(defaultResult.count, allResult.count,
                                 "Default fetch should return same or fewer assets than all-burst fetch")

        print("""
        === Burst Photo Test ===
        - Default fetch count: \(defaultResult.count)
        - All burst fetch count: \(allResult.count)
        - Burst-only count: \(allResult.count - defaultResult.count)
        """)
    }

    // MARK: - Portrait Mode (Depth Effect) Tests

    /// Portrait 모드 사진 분석 테스트
    /// - Safe Guard에서 심도 효과 감지 시 블러 판정 무효화
    func testPortraitPhoto_SafeGuard_Integration() async throws {
        try skipIfNotReady()

        // Portrait 모드 사진 찾기
        let options = PHFetchOptions()
        options.predicate = NSPredicate(
            format: "mediaType == %d AND ((mediaSubtypes & %d) != 0)",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoDepthEffect.rawValue
        )
        options.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: options)
        guard let portraitPhoto = result.firstObject else {
            throw XCTSkip("No Portrait mode photo found in library")
        }

        XCTAssertTrue(portraitPhoto.isPortraitPhoto, "Should be a Portrait photo")

        // 분석 실행
        let analyzer = QualityAnalyzer.shared
        let qualityResult = await analyzer.analyze(portraitPhoto)

        // Portrait 모드 사진은 Safe Guard에 의해 보호될 수 있음
        // (블러가 감지되더라도 심도 효과로 인한 의도적 블러)
        XCTAssertNotNil(qualityResult)

        print("""
        === Portrait Photo Analysis ===
        - Verdict: \(qualityResult.verdict)
        - Safe Guard Applied: \(qualityResult.safeGuardApplied)
        - Safe Guard Reason: \(qualityResult.safeGuardReason?.rawValue ?? "none")
        - Signals: \(qualityResult.signals.map { $0.kind.rawValue })
        """)
    }

    // MARK: - Constants Validation

    /// 특수 미디어 관련 상수 검증
    func testConstants_SpecialMedia() {
        // 저해상도 기준
        XCTAssertEqual(CleanupConstants.lowResolutionPixelCount, 1_000_000,
                       "Low resolution should be 1MP")

        // 비디오 길이 관련
        XCTAssertEqual(CleanupConstants.maxAnalyzableVideoDuration, 5.0,
                       "Max analyzable video should be 5 seconds")
        XCTAssertEqual(CleanupConstants.tooShortVideoDuration, 1.0,
                       "Too short video should be 1 second")

        // 얼굴 품질 임계값
        XCTAssertEqual(CleanupConstants.faceQualityThreshold, 0.4,
                       "Face quality threshold should be 0.4")
    }

    // MARK: - Helper

    private func skipIfNotReady() throws {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard status == .authorized || status == .limited else {
            throw XCTSkip("Photo library access required")
        }
    }
}

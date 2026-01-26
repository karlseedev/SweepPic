//
//  MetadataFilterTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-01-22.
//
//  MetadataFilter 단위 테스트
//  - 필터링 로직 테스트
//  - SkipReason 반환 테스트
//
//  Note: PHAsset은 Mock이 어려우므로 실제 기기 테스트 또는
//        통합 테스트에서 검증 권장
//

import XCTest
import Photos
@testable import PickPhoto

final class MetadataFilterTests: XCTestCase {

    // MARK: - Properties

    var filter: MetadataFilter!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        filter = MetadataFilter()
    }

    override func tearDown() {
        filter = nil
        super.tearDown()
    }

    // MARK: - SkipReason Tests

    func testSkipReasonFavorite() {
        // Given
        let reason = SkipReason.favorite

        // Then
        XCTAssertEqual(reason.rawValue, "favorite")
    }

    func testSkipReasonEdited() {
        // Given
        let reason = SkipReason.edited

        // Then
        XCTAssertEqual(reason.rawValue, "edited")
    }

    func testSkipReasonHidden() {
        // Given
        let reason = SkipReason.hidden

        // Then
        XCTAssertEqual(reason.rawValue, "hidden")
    }

    func testSkipReasonSharedAlbum() {
        // Given
        let reason = SkipReason.sharedAlbum

        // Then
        XCTAssertEqual(reason.rawValue, "sharedAlbum")
    }

    func testSkipReasonScreenshot() {
        // Given
        let reason = SkipReason.screenshot

        // Then
        XCTAssertEqual(reason.rawValue, "screenshot")
    }

    func testSkipReasonICloudOnly() {
        // Given
        let reason = SkipReason.iCloudOnly

        // Then
        XCTAssertEqual(reason.rawValue, "iCloudOnly")
    }

    func testSkipReasonAnalysisError() {
        // Given
        let reason = SkipReason.analysisError

        // Then
        XCTAssertEqual(reason.rawValue, "analysisError")
    }

    func testSkipReasonLongVideo() {
        // Given
        let reason = SkipReason.longVideo

        // Then
        XCTAssertEqual(reason.rawValue, "longVideo")
    }

    func testSkipReasonUtilityImage() {
        // Given
        let reason = SkipReason.utilityImage

        // Then
        XCTAssertEqual(reason.rawValue, "utilityImage")
    }

    // MARK: - All Cases Test

    func testAllSkipReasonCases() {
        // Given
        let allCases = SkipReason.allCases

        // Then
        XCTAssertEqual(allCases.count, 9)
        XCTAssertTrue(allCases.contains(.favorite))
        XCTAssertTrue(allCases.contains(.edited))
        XCTAssertTrue(allCases.contains(.hidden))
        XCTAssertTrue(allCases.contains(.sharedAlbum))
        XCTAssertTrue(allCases.contains(.screenshot))
        XCTAssertTrue(allCases.contains(.iCloudOnly))
        XCTAssertTrue(allCases.contains(.analysisError))
        XCTAssertTrue(allCases.contains(.longVideo))
        XCTAssertTrue(allCases.contains(.utilityImage))
    }

    // MARK: - Filter Method Tests

    func testFilterEmptyArray() {
        // Given
        let assets: [PHAsset] = []

        // When
        let (toAnalyze, skipped) = filter.filter(assets)

        // Then
        XCTAssertTrue(toAnalyze.isEmpty)
        XCTAssertTrue(skipped.isEmpty)
    }

    // MARK: - QualityResult Skipped Tests

    func testQualityResultSkippedCreation() {
        // Given
        let assetID = "test-asset-123"
        let reason = SkipReason.favorite

        // When
        let result = QualityResult.skipped(assetID: assetID, creationDate: nil, reason: reason)

        // Then
        XCTAssertEqual(result.assetID, assetID)
        XCTAssertFalse(result.verdict.isAnalyzed)
        XCTAssertFalse(result.verdict.isLowQuality)

        if case .skipped(let skipReason) = result.verdict {
            XCTAssertEqual(skipReason, .favorite)
        } else {
            XCTFail("Should be skipped verdict")
        }
    }
}

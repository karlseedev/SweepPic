//
//  QualityAnalyzerTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-01-22.
//
//  QualityAnalyzer 단위 테스트
//  - 판정 로직 테스트
//  - 통계 메서드 테스트
//
//  Note: 실제 PHAsset을 사용한 통합 테스트는 실기기에서 수행
//

import XCTest
@testable import PickPhoto

final class QualityAnalyzerTests: XCTestCase {

    // MARK: - Properties

    var analyzer: QualityAnalyzer!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        analyzer = QualityAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Mode Tests

    func testDefaultMode() {
        // Then - 기본 모드는 Precision
        XCTAssertEqual(analyzer.mode, .precision)
    }

    func testSetMode() {
        // When
        analyzer.setMode(.recall)

        // Then
        XCTAssertEqual(analyzer.mode, .recall)
    }

    // MARK: - Statistics Tests

    func testStatisticsEmpty() {
        // Given
        let results: [QualityResult] = []

        // When
        let stats = analyzer.statistics(from: results)

        // Then
        XCTAssertEqual(stats.total, 0)
        XCTAssertEqual(stats.lowQuality, 0)
        XCTAssertEqual(stats.skipped, 0)
        XCTAssertEqual(stats.averageTimeMs, 0)
    }

    func testStatisticsWithMixedResults() {
        // Given
        let results: [QualityResult] = [
            // 저품질
            QualityResult.lowQuality(
                assetID: "1",
                creationDate: nil,
                signals: [QualitySignal(kind: .extremeDark, measuredValue: 0.05, threshold: 0.10)],
                analysisTimeMs: 10.0,
                method: .metalPipeline
            ),
            // 정상
            QualityResult.acceptable(
                assetID: "2",
                creationDate: nil,
                signals: [],
                analysisTimeMs: 15.0,
                method: .metalPipeline
            ),
            // SKIP
            QualityResult.skipped(assetID: "3", creationDate: nil, reason: .favorite),
            QualityResult.skipped(assetID: "4", creationDate: nil, reason: .screenshot)
        ]

        // When
        let stats = analyzer.statistics(from: results)

        // Then
        XCTAssertEqual(stats.total, 4)
        XCTAssertEqual(stats.lowQuality, 1)
        XCTAssertEqual(stats.skipped, 2)
        // 분석된 것만 평균 (10 + 15) / 2 = 12.5
        XCTAssertEqual(stats.averageTimeMs, 12.5, accuracy: 0.01)
    }

    // MARK: - Filter Low Quality Tests

    func testFilterLowQuality() {
        // Given
        let results: [QualityResult] = [
            QualityResult.lowQuality(
                assetID: "1",
                creationDate: nil,
                signals: [QualitySignal(kind: .extremeDark, measuredValue: 0.05, threshold: 0.10)],
                analysisTimeMs: 10.0,
                method: .metalPipeline
            ),
            QualityResult.acceptable(
                assetID: "2",
                creationDate: nil,
                signals: [],
                analysisTimeMs: 15.0,
                method: .metalPipeline
            ),
            QualityResult.lowQuality(
                assetID: "3",
                creationDate: nil,
                signals: [QualitySignal(kind: .severeBlur, measuredValue: 30.0, threshold: 50.0)],
                analysisTimeMs: 20.0,
                method: .metalPipeline
            ),
            QualityResult.skipped(assetID: "4", creationDate: nil, reason: .favorite)
        ]

        // When
        let lowQuality = analyzer.filterLowQuality(results)

        // Then
        XCTAssertEqual(lowQuality.count, 2)
        XCTAssertTrue(lowQuality.allSatisfy { $0.verdict.isLowQuality })
    }

    // MARK: - QualityVerdict Tests

    func testLowQualityVerdict() {
        // Given
        let verdict = QualityVerdict.lowQuality

        // Then
        XCTAssertTrue(verdict.isLowQuality)
        XCTAssertTrue(verdict.isAnalyzed)
    }

    func testAcceptableVerdict() {
        // Given
        let verdict = QualityVerdict.acceptable

        // Then
        XCTAssertFalse(verdict.isLowQuality)
        XCTAssertTrue(verdict.isAnalyzed)
    }

    func testSkippedVerdict() {
        // Given
        let verdict = QualityVerdict.skipped(reason: .favorite)

        // Then
        XCTAssertFalse(verdict.isLowQuality)
        XCTAssertFalse(verdict.isAnalyzed)
    }

    // MARK: - SafeGuard Result Tests

    func testSafeGuardedResult() {
        // Given
        let result = QualityResult.safeGuarded(
            assetID: "test",
            creationDate: nil,
            signals: [QualitySignal(kind: .severeBlur, measuredValue: 30.0, threshold: 50.0)],
            reason: .clearFace,
            analysisTimeMs: 25.0,
            method: .metalPipeline
        )

        // Then
        XCTAssertFalse(result.verdict.isLowQuality)  // Safe Guard로 인해 acceptable
        XCTAssertTrue(result.safeGuardApplied)
        XCTAssertEqual(result.safeGuardReason, .clearFace)
        XCTAssertEqual(result.signals.count, 1)  // 원본 신호는 유지
    }

    // MARK: - Signal Array Extension Tests

    func testSignalArrayHasStrongSignal() {
        // Given
        let signals: [QualitySignal] = [
            QualitySignal(kind: .extremeDark, measuredValue: 0.05, threshold: 0.10),
            QualitySignal(kind: .lowColorVariety, measuredValue: 10.0, threshold: 15.0)
        ]

        // Then
        XCTAssertTrue(signals.hasStrongSignal)
    }

    func testSignalArrayHasConditionalSignal() {
        // Given
        let signals: [QualitySignal] = [
            QualitySignal(kind: .pocketShot, measuredValue: 0.12, threshold: 0.15),
            QualitySignal(kind: .lowColorVariety, measuredValue: 10.0, threshold: 15.0)
        ]

        // Then
        XCTAssertTrue(signals.hasConditionalSignal)
    }

    func testSignalArrayWeakWeightSum() {
        // Given
        let signals: [QualitySignal] = [
            QualitySignal(kind: .generalBlur, measuredValue: 75.0, threshold: 100.0),  // weight 2
            QualitySignal(kind: .lowColorVariety, measuredValue: 10.0, threshold: 15.0),  // weight 1
            QualitySignal(kind: .generalExposure, measuredValue: 0.12, threshold: 0.15)  // weight 1
        ]

        // When
        let sum = signals.weakWeightSum

        // Then
        XCTAssertEqual(sum, 4)  // 2 + 1 + 1 = 4
    }

    func testSignalArrayHasEnoughWeakSignals() {
        // Given - sum >= 3
        let signals: [QualitySignal] = [
            QualitySignal(kind: .generalBlur, measuredValue: 75.0, threshold: 100.0),  // weight 2
            QualitySignal(kind: .lowColorVariety, measuredValue: 10.0, threshold: 15.0)  // weight 1
        ]

        // Then
        XCTAssertTrue(signals.hasEnoughWeakSignals)  // 2 + 1 = 3
    }

    func testSignalArrayNotEnoughWeakSignals() {
        // Given - sum < 3
        let signals: [QualitySignal] = [
            QualitySignal(kind: .lowColorVariety, measuredValue: 10.0, threshold: 15.0),  // weight 1
            QualitySignal(kind: .lowResolution, measuredValue: 500000, threshold: 1000000)  // weight 1
        ]

        // Then
        XCTAssertFalse(signals.hasEnoughWeakSignals)  // 1 + 1 = 2 < 3
    }
}

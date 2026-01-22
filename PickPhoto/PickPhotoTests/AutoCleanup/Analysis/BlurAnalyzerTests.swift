//
//  BlurAnalyzerTests.swift
//  PickPhotoTests
//
//  Created by Claude on 2026-01-22.
//
//  BlurAnalyzer 단위 테스트
//  - Laplacian Variance 계산 테스트
//  - 신호 감지 테스트
//

import XCTest
@testable import PickPhoto

final class BlurAnalyzerTests: XCTestCase {

    // MARK: - Properties

    var analyzer: BlurAnalyzer!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        analyzer = BlurAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// 단색 테스트 이미지 생성 (블러 이미지)
    func createSolidColorImage(gray: UInt8, width: Int = 256, height: Int = 256) -> CGImage? {
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                pixelData[offset] = gray      // R
                pixelData[offset + 1] = gray  // G
                pixelData[offset + 2] = gray  // B
                pixelData[offset + 3] = 255   // A
            }
        }

        let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )

        return context?.makeImage()
    }

    /// 체커보드 패턴 이미지 생성 (선명한 이미지)
    func createCheckerboardImage(size: Int = 256, tileSize: Int = 8) -> CGImage? {
        let bytesPerRow = size * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * size)

        for y in 0..<size {
            for x in 0..<size {
                let offset = (y * size + x) * 4
                let isWhiteTile = ((x / tileSize) + (y / tileSize)) % 2 == 0
                let color: UInt8 = isWhiteTile ? 255 : 0

                pixelData[offset] = color      // R
                pixelData[offset + 1] = color  // G
                pixelData[offset + 2] = color  // B
                pixelData[offset + 3] = 255    // A
            }
        }

        let context = CGContext(
            data: &pixelData,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        )

        return context?.makeImage()
    }

    // MARK: - Availability Tests

    func testAnalyzerAvailability() {
        // Metal이 사용 가능한 환경에서는 true, 시뮬레이터에서는 false일 수 있음
        // 테스트 환경에 따라 다를 수 있으므로 단순히 확인만 함
        _ = analyzer.isAvailable
    }

    // MARK: - CPU Fallback Tests

    func testCPUAnalyzeSolidColorImage() throws {
        // Given - 단색 이미지 (변화 없음 = 블러)
        guard let solidImage = createSolidColorImage(gray: 128) else {
            XCTFail("Failed to create test image")
            return
        }

        // When - CPU 분석
        let metrics = try analyzer.analyzeCPU(solidImage)

        // Then - 단색이므로 Laplacian Variance는 매우 낮아야 함
        XCTAssertLessThan(metrics.laplacianVariance, 10)
    }

    func testCPUAnalyzeCheckerboardImage() throws {
        // Given - 체커보드 패턴 (에지가 많음 = 선명)
        guard let checkerboard = createCheckerboardImage() else {
            XCTFail("Failed to create test image")
            return
        }

        // When - CPU 분석
        let metrics = try analyzer.analyzeCPU(checkerboard)

        // Then - 에지가 많으므로 Laplacian Variance가 높아야 함
        XCTAssertGreaterThan(metrics.laplacianVariance, 100)
    }

    // MARK: - Signal Detection Tests

    func testDetectSevereBlurSignal() {
        // Given - 심각한 블러 (Laplacian < 50)
        let metrics = BlurMetrics(laplacianVariance: 30)

        // When - Precision 모드
        let signals = analyzer.detectSignals(from: metrics, mode: .precision)

        // Then - severeBlur 신호가 감지되어야 함
        XCTAssertTrue(signals.contains { $0.kind == .severeBlur })
    }

    func testDetectGeneralBlurSignalInRecallMode() {
        // Given - 일반 블러 (50 <= Laplacian < 100)
        let metrics = BlurMetrics(laplacianVariance: 75)

        // When
        let precisionSignals = analyzer.detectSignals(from: metrics, mode: .precision)
        let recallSignals = analyzer.detectSignals(from: metrics, mode: .recall)

        // Then
        // Precision 모드에서는 신호 없음 (50 이상이므로)
        XCTAssertFalse(precisionSignals.contains { $0.kind == .generalBlur })
        XCTAssertFalse(precisionSignals.contains { $0.kind == .severeBlur })

        // Recall 모드에서는 generalBlur 신호 감지
        XCTAssertTrue(recallSignals.contains { $0.kind == .generalBlur })
    }

    func testNoSignalForSharpImage() {
        // Given - 선명한 이미지 (Laplacian >= 100)
        let metrics = BlurMetrics(laplacianVariance: 150)

        // When
        let precisionSignals = analyzer.detectSignals(from: metrics, mode: .precision)
        let recallSignals = analyzer.detectSignals(from: metrics, mode: .recall)

        // Then - 모든 모드에서 블러 신호 없어야 함
        XCTAssertTrue(precisionSignals.isEmpty)
        XCTAssertTrue(recallSignals.isEmpty)
    }

    // MARK: - Weight Tests

    func testSevereBlurIsStrongSignal() {
        // Given
        let metrics = BlurMetrics(laplacianVariance: 30)

        // When
        let signals = analyzer.detectSignals(from: metrics, mode: .precision)

        // Then
        guard let severeBlur = signals.first(where: { $0.kind == .severeBlur }) else {
            XCTFail("Should detect severeBlur")
            return
        }

        XCTAssertEqual(severeBlur.type, .strong)
    }

    func testGeneralBlurIsWeakSignal() {
        // Given
        let metrics = BlurMetrics(laplacianVariance: 75)

        // When
        let signals = analyzer.detectSignals(from: metrics, mode: .recall)

        // Then
        guard let generalBlur = signals.first(where: { $0.kind == .generalBlur }) else {
            XCTFail("Should detect generalBlur")
            return
        }

        XCTAssertEqual(generalBlur.type, .weak(weight: 2))  // generalBlur는 weight 2
    }
}

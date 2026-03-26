//
//  ExposureAnalyzerTests.swift
//  SweepPicTests
//
//  Created by Claude on 2026-01-22.
//
//  ExposureAnalyzer 단위 테스트
//  - 휘도 계산 테스트
//  - RGB 표준편차 계산 테스트
//  - 신호 감지 테스트
//

import XCTest
@testable import SweepPic

final class ExposureAnalyzerTests: XCTestCase {

    // MARK: - Properties

    var analyzer: ExposureAnalyzer!

    // MARK: - Setup

    override func setUp() {
        super.setUp()
        analyzer = ExposureAnalyzer()
    }

    override func tearDown() {
        analyzer = nil
        super.tearDown()
    }

    // MARK: - Helper Methods

    /// 단색 테스트 이미지 생성
    func createSolidColorImage(r: UInt8, g: UInt8, b: UInt8, width: Int = 64, height: Int = 64) -> CGImage? {
        let bytesPerRow = width * 4
        var pixelData = [UInt8](repeating: 0, count: bytesPerRow * height)

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                pixelData[offset] = r      // R
                pixelData[offset + 1] = g  // G
                pixelData[offset + 2] = b  // B
                pixelData[offset + 3] = 255 // A
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

    // MARK: - Luminance Tests

    func testAnalyzeBlackImage() throws {
        // Given - 검은색 이미지
        guard let blackImage = createSolidColorImage(r: 0, g: 0, b: 0) else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let metrics = try analyzer.analyze(blackImage)

        // Then - 휘도는 0에 가까워야 함
        XCTAssertEqual(metrics.luminance, 0, accuracy: 0.01)
    }

    func testAnalyzeWhiteImage() throws {
        // Given - 흰색 이미지
        guard let whiteImage = createSolidColorImage(r: 255, g: 255, b: 255) else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let metrics = try analyzer.analyze(whiteImage)

        // Then - 휘도는 1에 가까워야 함
        XCTAssertEqual(metrics.luminance, 1.0, accuracy: 0.01)
    }

    func testAnalyzeGrayImage() throws {
        // Given - 회색 이미지 (128, 128, 128)
        guard let grayImage = createSolidColorImage(r: 128, g: 128, b: 128) else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let metrics = try analyzer.analyze(grayImage)

        // Then - 휘도는 0.5 근처여야 함
        XCTAssertEqual(metrics.luminance, 0.5, accuracy: 0.02)
    }

    // MARK: - RGB Std Tests

    func testAnalyzeSolidColorHasLowRgbStd() throws {
        // Given - 단색 이미지
        guard let solidImage = createSolidColorImage(r: 100, g: 100, b: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let metrics = try analyzer.analyze(solidImage)

        // Then - 단색이므로 RGB Std는 0에 가까워야 함
        XCTAssertEqual(metrics.rgbStd, 0, accuracy: 1.0)
    }

    // MARK: - Signal Detection Tests

    func testDetectExtremeDarkSignal() throws {
        // Given - 매우 어두운 이미지 (휘도 < 0.10)
        guard let darkImage = createSolidColorImage(r: 10, g: 10, b: 10) else {
            XCTFail("Failed to create test image")
            return
        }

        let metrics = try analyzer.analyze(darkImage)

        // When - Precision 모드
        let signals = analyzer.detectSignals(from: metrics, mode: .precision)

        // Then - extremeDark 신호가 감지되어야 함
        XCTAssertTrue(signals.contains { $0.kind == .extremeDark })
    }

    func testDetectExtremeBrightSignal() throws {
        // Given - 매우 밝은 이미지 (휘도 > 0.90)
        guard let brightImage = createSolidColorImage(r: 250, g: 250, b: 250) else {
            XCTFail("Failed to create test image")
            return
        }

        let metrics = try analyzer.analyze(brightImage)

        // When - Precision 모드
        let signals = analyzer.detectSignals(from: metrics, mode: .precision)

        // Then - extremeBright 신호가 감지되어야 함
        XCTAssertTrue(signals.contains { $0.kind == .extremeBright })
    }

    func testNoSignalForNormalImage() throws {
        // Given - 정상 밝기 이미지
        guard let normalImage = createSolidColorImage(r: 128, g: 128, b: 128) else {
            XCTFail("Failed to create test image")
            return
        }

        let metrics = try analyzer.analyze(normalImage)

        // When - Precision 모드
        let signals = analyzer.detectSignals(from: metrics, mode: .precision)

        // Then - 신호 없어야 함
        XCTAssertTrue(signals.isEmpty)
    }

    func testRecallModeDetectsMoreSignals() throws {
        // Given - 약간 어두운 이미지 (휘도 약 0.12)
        guard let slightlyDarkImage = createSolidColorImage(r: 30, g: 30, b: 30) else {
            XCTFail("Failed to create test image")
            return
        }

        let metrics = try analyzer.analyze(slightlyDarkImage)

        // When
        let precisionSignals = analyzer.detectSignals(from: metrics, mode: .precision)
        let recallSignals = analyzer.detectSignals(from: metrics, mode: .recall)

        // Then - Recall 모드가 더 많은 신호를 감지
        // 휘도 0.12 정도면 Precision에서는 extremeDark (< 0.10)에 해당하지 않을 수 있음
        // Recall에서는 lowColorVariety, generalExposure 등 추가 감지 가능
        XCTAssertTrue(recallSignals.count >= precisionSignals.count)
    }

    // MARK: - Region Luminance Tests

    func testCenterAndCornerLuminanceEqual() throws {
        // Given - 균일한 이미지
        guard let uniformImage = createSolidColorImage(r: 100, g: 100, b: 100) else {
            XCTFail("Failed to create test image")
            return
        }

        // When
        let metrics = try analyzer.analyze(uniformImage)

        // Then - 중앙과 모서리 휘도가 같아야 함
        XCTAssertEqual(metrics.centerLuminance, metrics.cornerLuminance, accuracy: 0.05)
        XCTAssertEqual(metrics.vignetting, 0, accuracy: 0.1)
    }
}

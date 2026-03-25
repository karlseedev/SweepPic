//
//  ExposureAnalyzer.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  Stage 2: 노출 분석 (휘도, RGB 표준편차)
//  - 64×64 픽셀로 다운샘플하여 분석
//  - 휘도(Luminance): 극단 어두움/밝음 판정
//  - RGB Std: 색상 다양성 판정
//  - 중앙/모서리 휘도: 주머니 샷, 렌즈 가림 판정
//

import Foundation
import CoreGraphics
import UIKit
import Accelerate

/// 노출 분석 결과
struct ExposureMetrics: Equatable {

    /// 평균 휘도 (0.0 ~ 1.0)
    let luminance: Double

    /// RGB 표준편차 (0.0 ~ 127.5)
    let rgbStd: Double

    /// 중앙 영역 평균 휘도
    let centerLuminance: Double

    /// 모서리 영역 평균 휘도
    let cornerLuminance: Double

    /// 비네팅 값 ((corner - center) / center)
    /// - 음수면 모서리가 더 어두움 (일반적인 비네팅)
    /// - 양수면 모서리가 더 밝음
    var vignetting: Double {
        guard centerLuminance > 0 else { return 0 }
        return (cornerLuminance - centerLuminance) / centerLuminance
    }
}

/// 노출 분석기
///
/// CGImage를 64×64로 다운샘플하여 휘도 및 RGB 표준편차를 분석합니다.
/// vImage/Accelerate 프레임워크를 사용하여 고성능으로 분석합니다.
final class ExposureAnalyzer {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = ExposureAnalyzer()

    // MARK: - Properties

    /// 분석용 다운샘플 크기
    private let analysisSize: CGSize

    // MARK: - Initialization

    /// 분석기 초기화
    /// - Parameter analysisSize: 다운샘플 크기 (기본값: 64×64)
    init(analysisSize: CGSize = CleanupConstants.exposureAnalysisSize) {
        self.analysisSize = analysisSize
    }

    // MARK: - Public Methods

    /// 이미지 노출 분석
    ///
    /// - Parameter image: 분석할 CGImage
    /// - Returns: 노출 분석 결과
    /// - Throws: 이미지 처리 실패 시 에러
    ///
    /// - Note: 내부적으로 64×64로 다운샘플 후 분석
    func analyze(_ image: CGImage) throws -> ExposureMetrics {
        // 1. 다운샘플 (64×64)
        let downsampled = try downsample(image, to: analysisSize)

        // 2. RGBA 픽셀 데이터 추출
        let pixelData = try extractPixelData(from: downsampled)

        // 3. 휘도 계산 (ITU-R BT.601 공식)
        let luminance = calculateLuminance(from: pixelData)

        // 4. RGB 표준편차 계산
        let rgbStd = calculateRgbStd(from: pixelData)

        // 5. 중앙/모서리 휘도 계산
        let (centerLum, cornerLum) = calculateRegionLuminance(
            from: pixelData,
            width: Int(analysisSize.width),
            height: Int(analysisSize.height)
        )

        return ExposureMetrics(
            luminance: luminance,
            rgbStd: rgbStd,
            centerLuminance: centerLum,
            cornerLuminance: cornerLum
        )
    }

    /// 품질 신호 생성
    ///
    /// - Parameters:
    ///   - metrics: 노출 분석 결과
    ///   - mode: 판정 모드 (Precision/Recall)
    /// - Returns: 감지된 품질 신호 배열
    func detectSignals(from metrics: ExposureMetrics, mode: JudgmentMode) -> [QualitySignal] {
        var signals: [QualitySignal] = []

        // Strong 신호 (Precision 모드에서도 사용)

        // 극단 어두움
        if metrics.luminance < CleanupConstants.extremeDarkLuminance {
            signals.append(QualitySignal(
                kind: .extremeDark,
                measuredValue: metrics.luminance,
                threshold: CleanupConstants.extremeDarkLuminance
            ))
        }

        // 극단 밝음
        if metrics.luminance > CleanupConstants.extremeBrightLuminance {
            signals.append(QualitySignal(
                kind: .extremeBright,
                measuredValue: metrics.luminance,
                threshold: CleanupConstants.extremeBrightLuminance
            ))
        }

        // Recall 모드 전용 신호
        if mode == .recall {
            // Conditional 신호

            // 주머니 샷 복합 조건
            // 휘도 < 0.15 AND RGB Std < 15 AND 비네팅 < 0.05
            if metrics.luminance < CleanupConstants.generalDarkLuminance &&
                metrics.rgbStd < CleanupConstants.lowColorVarietyRgbStd &&
                abs(metrics.vignetting) < CleanupConstants.pocketShotVignetting {
                signals.append(QualitySignal(
                    kind: .pocketShot,
                    measuredValue: metrics.luminance,
                    threshold: CleanupConstants.generalDarkLuminance
                ))
            }

            // 극단 단색
            // RGB Std < 10 AND (휘도 < 0.15 OR 휘도 > 0.85)
            if metrics.rgbStd < CleanupConstants.extremeMonochromeRgbStd &&
                (metrics.luminance < CleanupConstants.generalDarkLuminance ||
                    metrics.luminance > CleanupConstants.generalBrightLuminance) {
                signals.append(QualitySignal(
                    kind: .extremeMonochrome,
                    measuredValue: metrics.rgbStd,
                    threshold: CleanupConstants.extremeMonochromeRgbStd
                ))
            }

            // 렌즈 가림
            // 모서리 휘도 < 중앙 휘도 × 0.4
            let lensBlockedThreshold = metrics.centerLuminance * CleanupConstants.lensBlockedRatio
            if metrics.cornerLuminance < lensBlockedThreshold && metrics.centerLuminance > 0.1 {
                signals.append(QualitySignal(
                    kind: .lensBlocked,
                    measuredValue: metrics.cornerLuminance,
                    threshold: lensBlockedThreshold
                ))
            }

            // Weak 신호

            // 일반 노출 (어두움/밝음)
            if metrics.luminance < CleanupConstants.generalDarkLuminance ||
                metrics.luminance > CleanupConstants.generalBrightLuminance {
                // 극단 어두움/밝음이 아닌 경우에만
                if metrics.luminance >= CleanupConstants.extremeDarkLuminance &&
                    metrics.luminance <= CleanupConstants.extremeBrightLuminance {
                    signals.append(QualitySignal(
                        kind: .generalExposure,
                        measuredValue: metrics.luminance,
                        threshold: metrics.luminance < 0.5 ?
                            CleanupConstants.generalDarkLuminance :
                            CleanupConstants.generalBrightLuminance
                    ))
                }
            }

            // 낮은 색상 다양성
            if metrics.rgbStd < CleanupConstants.lowColorVarietyRgbStd {
                signals.append(QualitySignal(
                    kind: .lowColorVariety,
                    measuredValue: metrics.rgbStd,
                    threshold: CleanupConstants.lowColorVarietyRgbStd
                ))
            }
        }

        return signals
    }

    // MARK: - Private Methods

    /// 이미지 다운샘플링
    private func downsample(_ image: CGImage, to targetSize: CGSize) throws -> CGImage {
        let width = Int(targetSize.width)
        let height = Int(targetSize.height)

        // ARGB 8888 컨텍스트 생성
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        // 고품질 보간법으로 리사이징
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let result = context.makeImage() else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        return result
    }

    /// 픽셀 데이터 추출 (RGBA)
    private func extractPixelData(from image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        let bytesPerRow = width * 4
        let totalBytes = bytesPerRow * height

        var pixelData = [UInt8](repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }

    /// 평균 휘도 계산 (ITU-R BT.601)
    /// Y = 0.299 * R + 0.587 * G + 0.114 * B
    private func calculateLuminance(from pixelData: [UInt8]) -> Double {
        let pixelCount = pixelData.count / 4
        guard pixelCount > 0 else { return 0 }

        var totalLuminance: Double = 0

        for i in 0..<pixelCount {
            let offset = i * 4
            let r = Double(pixelData[offset])
            let g = Double(pixelData[offset + 1])
            let b = Double(pixelData[offset + 2])

            // ITU-R BT.601 공식
            let luminance = 0.299 * r + 0.587 * g + 0.114 * b
            totalLuminance += luminance
        }

        // 0~1 범위로 정규화
        return (totalLuminance / Double(pixelCount)) / 255.0
    }

    /// RGB 표준편차 계산
    private func calculateRgbStd(from pixelData: [UInt8]) -> Double {
        let pixelCount = pixelData.count / 4
        guard pixelCount > 0 else { return 0 }

        // R, G, B 각각의 합계 계산
        var sumR: Double = 0
        var sumG: Double = 0
        var sumB: Double = 0
        var sumRSq: Double = 0
        var sumGSq: Double = 0
        var sumBSq: Double = 0

        for i in 0..<pixelCount {
            let offset = i * 4
            let r = Double(pixelData[offset])
            let g = Double(pixelData[offset + 1])
            let b = Double(pixelData[offset + 2])

            sumR += r
            sumG += g
            sumB += b
            sumRSq += r * r
            sumGSq += g * g
            sumBSq += b * b
        }

        let n = Double(pixelCount)

        // 분산 = E[X²] - E[X]²
        let varR = (sumRSq / n) - pow(sumR / n, 2)
        let varG = (sumGSq / n) - pow(sumG / n, 2)
        let varB = (sumBSq / n) - pow(sumB / n, 2)

        // 평균 표준편차
        let stdR = sqrt(max(0, varR))
        let stdG = sqrt(max(0, varG))
        let stdB = sqrt(max(0, varB))

        return (stdR + stdG + stdB) / 3.0
    }

    /// 중앙/모서리 영역 휘도 계산
    private func calculateRegionLuminance(
        from pixelData: [UInt8],
        width: Int,
        height: Int
    ) -> (center: Double, corner: Double) {
        // 중앙 영역: 중심 50% 영역
        let centerX1 = width / 4
        let centerY1 = height / 4
        let centerX2 = width * 3 / 4
        let centerY2 = height * 3 / 4

        var centerSum: Double = 0
        var centerCount = 0

        // 모서리 영역: 각 코너 10% 영역
        let cornerSize = max(width / 10, 1)
        var cornerSum: Double = 0
        var cornerCount = 0

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * 4
                let r = Double(pixelData[offset])
                let g = Double(pixelData[offset + 1])
                let b = Double(pixelData[offset + 2])
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b

                // 중앙 영역
                if x >= centerX1 && x < centerX2 && y >= centerY1 && y < centerY2 {
                    centerSum += luminance
                    centerCount += 1
                }

                // 모서리 영역 (4개 코너)
                let isCorner = (x < cornerSize || x >= width - cornerSize) &&
                               (y < cornerSize || y >= height - cornerSize)
                if isCorner {
                    cornerSum += luminance
                    cornerCount += 1
                }
            }
        }

        let centerLum = centerCount > 0 ? (centerSum / Double(centerCount)) / 255.0 : 0
        let cornerLum = cornerCount > 0 ? (cornerSum / Double(cornerCount)) / 255.0 : 0

        return (centerLum, cornerLum)
    }
}


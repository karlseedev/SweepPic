//
//  BlurAnalyzer.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  Stage 3: 블러 분석 (Laplacian Variance)
//  - 256×256 픽셀로 다운샘플하여 분석
//  - Metal Performance Shaders (MPSImageLaplacian) 사용
//  - Laplacian Variance로 블러 정도 측정
//

import Foundation
import CoreGraphics
import Metal
import MetalPerformanceShaders
import Accelerate

/// 블러 분석 결과
struct BlurMetrics: Equatable {

    /// Laplacian Variance 값
    /// - 높을수록 선명, 낮을수록 블러
    /// - 일반적으로 100 이상이면 선명, 50 미만이면 심각한 블러
    let laplacianVariance: Double
}

/// 블러 분석기
///
/// Metal Performance Shaders를 사용하여 Laplacian Variance를 계산합니다.
/// 이미지의 선명도를 측정하여 블러 여부를 판정합니다.
final class BlurAnalyzer {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = BlurAnalyzer()

    // MARK: - Properties

    /// Metal 디바이스
    private let device: MTLDevice?

    /// Metal 명령 큐
    private let commandQueue: MTLCommandQueue?

    /// Laplacian 커널
    private let laplacian: MPSImageLaplacian?

    /// 분석용 다운샘플 크기
    private let analysisSize: CGSize

    /// Metal 초기화 성공 여부
    var isAvailable: Bool {
        return device != nil && commandQueue != nil && laplacian != nil
    }

    // MARK: - Initialization

    /// 분석기 초기화
    /// - Parameter analysisSize: 다운샘플 크기 (기본값: 256×256)
    init(analysisSize: CGSize = CleanupConstants.blurAnalysisSize) {
        self.analysisSize = analysisSize

        // Metal 디바이스 초기화
        guard let device = MTLCreateSystemDefaultDevice() else {
            self.device = nil
            self.commandQueue = nil
            self.laplacian = nil
            return
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()

        // Laplacian 커널 생성
        self.laplacian = MPSImageLaplacian(device: device)
    }

    // MARK: - Public Methods

    /// 이미지 블러 분석
    ///
    /// - Parameter image: 분석할 CGImage
    /// - Returns: 블러 분석 결과
    /// - Throws: Metal 초기화 실패 또는 분석 실패 시 에러
    func analyze(_ image: CGImage) throws -> BlurMetrics {
        // Metal 사용 가능 여부 확인
        guard isAvailable else {
            throw AnalysisError.metalInitFailed
        }

        guard let device = device,
              let commandQueue = commandQueue,
              let laplacian = laplacian else {
            throw AnalysisError.metalInitFailed
        }

        // 1. 다운샘플 (256×256)
        let downsampled = try downsample(image, to: analysisSize)

        // 2. 그레이스케일 변환
        let grayscale = try convertToGrayscale(downsampled)

        // 3. Metal 텍스처 생성
        let (sourceTexture, destinationTexture) = try createTextures(
            from: grayscale,
            device: device
        )

        // 4. Laplacian 필터 적용
        guard let commandBuffer = commandQueue.makeCommandBuffer() else {
            throw AnalysisError.metalInitFailed
        }

        laplacian.encode(
            commandBuffer: commandBuffer,
            sourceTexture: sourceTexture,
            destinationTexture: destinationTexture
        )

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        // 5. Variance 계산
        let variance = try calculateVariance(from: destinationTexture)

        return BlurMetrics(laplacianVariance: variance)
    }

    /// CPU 기반 Laplacian 분석 (Metal 실패 시 폴백)
    ///
    /// - Parameter image: 분석할 CGImage
    /// - Returns: 블러 분석 결과
    /// - Throws: 분석 실패 시 에러
    func analyzeCPU(_ image: CGImage) throws -> BlurMetrics {
        // 1. 다운샘플
        let downsampled = try downsample(image, to: analysisSize)

        // 2. 그레이스케일 변환
        let grayscale = try convertToGrayscale(downsampled)

        // 3. Laplacian 커널 컨볼루션 (vImage)
        let laplacianResult = try applyLaplacianCPU(to: grayscale)

        // 4. Variance 계산
        let variance = calculateVarianceCPU(from: laplacianResult)

        return BlurMetrics(laplacianVariance: variance)
    }

    /// 품질 신호 생성
    ///
    /// - Parameters:
    ///   - metrics: 블러 분석 결과
    ///   - mode: 판정 모드 (Precision/Recall)
    /// - Returns: 감지된 품질 신호 배열
    ///
    /// - Note: 블러 신호는 Safe Guard 체크 대상 (심도 효과, 선명한 얼굴)
    func detectSignals(from metrics: BlurMetrics, mode: JudgmentMode) -> [QualitySignal] {
        var signals: [QualitySignal] = []

        // Strong 신호 (모든 모드)
        // 심각 블러: Laplacian Variance < 50
        if metrics.laplacianVariance < CleanupConstants.severeBlurLaplacian {
            signals.append(QualitySignal(
                kind: .severeBlur,
                measuredValue: metrics.laplacianVariance,
                threshold: CleanupConstants.severeBlurLaplacian
            ))
        }

        // Weak 신호 (Recall 모드만)
        if mode == .recall {
            // 일반 블러: Laplacian Variance < 100 (심각 블러 아닌 경우)
            if metrics.laplacianVariance < CleanupConstants.generalBlurLaplacian &&
                metrics.laplacianVariance >= CleanupConstants.severeBlurLaplacian {
                signals.append(QualitySignal(
                    kind: .generalBlur,
                    measuredValue: metrics.laplacianVariance,
                    threshold: CleanupConstants.generalBlurLaplacian
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

        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let result = context.makeImage() else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        return result
    }

    /// 그레이스케일 변환
    private func convertToGrayscale(_ image: CGImage) throws -> CGImage {
        let width = image.width
        let height = image.height

        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let result = context.makeImage() else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        return result
    }

    /// Metal 텍스처 생성
    private func createTextures(
        from image: CGImage,
        device: MTLDevice
    ) throws -> (source: MTLTexture, destination: MTLTexture) {
        let width = image.width
        let height = image.height

        // 텍스처 설명자
        let textureDescriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,
            width: width,
            height: height,
            mipmapped: false
        )
        textureDescriptor.usage = [.shaderRead, .shaderWrite]

        // 소스 텍스처
        guard let sourceTexture = device.makeTexture(descriptor: textureDescriptor) else {
            throw AnalysisError.metalInitFailed
        }

        // 이미지 데이터를 텍스처에 복사
        let bytesPerRow = width
        var pixelData = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        sourceTexture.replace(
            region: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0,
            withBytes: pixelData,
            bytesPerRow: bytesPerRow
        )

        // 목적 텍스처
        guard let destinationTexture = device.makeTexture(descriptor: textureDescriptor) else {
            throw AnalysisError.metalInitFailed
        }

        return (sourceTexture, destinationTexture)
    }

    /// 텍스처에서 Variance 계산
    private func calculateVariance(from texture: MTLTexture) throws -> Double {
        let width = texture.width
        let height = texture.height
        let bytesPerRow = width

        var pixelData = [UInt8](repeating: 0, count: width * height)
        texture.getBytes(
            &pixelData,
            bytesPerRow: bytesPerRow,
            from: MTLRegionMake2D(0, 0, width, height),
            mipmapLevel: 0
        )

        return calculateVarianceCPU(from: pixelData)
    }

    /// CPU 기반 Laplacian 커널 적용
    private func applyLaplacianCPU(to image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height

        // 입력 픽셀 데이터 추출
        var inputData = [UInt8](repeating: 0, count: width * height)

        guard let context = CGContext(
            data: &inputData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: CGColorSpaceCreateDeviceGray(),
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            throw AnalysisError.imageLoadFailed(assetID: "unknown")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Laplacian 커널 (3x3)
        // [ 0, -1,  0]
        // [-1,  4, -1]
        // [ 0, -1,  0]
        var outputData = [UInt8](repeating: 0, count: width * height)

        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Int(inputData[y * width + x])
                let top = Int(inputData[(y - 1) * width + x])
                let bottom = Int(inputData[(y + 1) * width + x])
                let left = Int(inputData[y * width + (x - 1)])
                let right = Int(inputData[y * width + (x + 1)])

                let laplacian = abs(4 * center - top - bottom - left - right)
                outputData[y * width + x] = UInt8(min(255, laplacian))
            }
        }

        return outputData
    }

    /// 픽셀 데이터에서 Variance 계산
    private func calculateVarianceCPU(from pixelData: [UInt8]) -> Double {
        let count = pixelData.count
        guard count > 0 else { return 0 }

        // 평균 계산
        var sum: Double = 0
        for pixel in pixelData {
            sum += Double(pixel)
        }
        let mean = sum / Double(count)

        // 분산 계산
        var varianceSum: Double = 0
        for pixel in pixelData {
            let diff = Double(pixel) - mean
            varianceSum += diff * diff
        }

        return varianceSum / Double(count)
    }
}


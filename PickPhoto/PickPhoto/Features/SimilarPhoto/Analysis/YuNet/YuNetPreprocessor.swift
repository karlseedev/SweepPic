//
//  YuNetPreprocessor.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  YuNet 모델 입력을 위한 이미지 전처리를 담당합니다.
//  RGB → BGR 변환, 320×320 리사이즈, NCHW 포맷 변환을 수행합니다.
//
//  Preprocessing Spec (확정):
//  - Color: BGR (iOS RGB에서 R↔B 스왑 필요)
//  - Size: 320×320 (고정)
//  - Range: 0-255 (정규화 없음)
//  - Format: NCHW (batch, channel, height, width)
//  - Mean: [0, 0, 0]
//  - Std: [1, 1, 1]
//

import Foundation
import CoreML
import CoreGraphics
import Accelerate

/// YuNet 전처리기
///
/// CGImage를 YuNet 모델 입력 형식인 MLMultiArray로 변환합니다.
/// BGR 순서, 320×320 크기, 0-255 범위, NCHW 포맷을 사용합니다.
final class YuNetPreprocessor {

    // MARK: - Constants

    /// 입력 이미지 크기
    private let inputWidth = YuNetConfig.inputWidth   // 320
    private let inputHeight = YuNetConfig.inputHeight // 320

    // MARK: - Public Methods

    /// CGImage를 YuNet 입력 형식으로 변환합니다.
    ///
    /// - Parameter image: 원본 CGImage (RGB)
    /// - Returns: MLMultiArray (BGR, 320×320, NCHW, Float32)
    /// - Throws: YuNetError.preprocessingFailed
    ///
    /// 변환 과정:
    /// 1. 320×320으로 리사이즈
    /// 2. RGB → BGR 변환
    /// 3. NCHW 포맷 MLMultiArray 생성
    func preprocess(_ image: CGImage) throws -> MLMultiArray {
        // 1. 320×320으로 리사이즈하고 픽셀 데이터 추출
        guard let pixelData = resizeAndExtractPixels(image) else {
            throw YuNetError.preprocessingFailed("이미지 리사이즈 실패")
        }

        // 2. MLMultiArray 생성 (NCHW: [1, 3, 320, 320])
        let input: MLMultiArray
        do {
            input = try MLMultiArray(
                shape: [1, 3, NSNumber(value: inputHeight), NSNumber(value: inputWidth)],
                dataType: .float32
            )
        } catch {
            throw YuNetError.preprocessingFailed("MLMultiArray 생성 실패: \(error)")
        }

        // 3. RGB → BGR 변환하며 MLMultiArray에 복사
        fillMultiArrayBGR(input, from: pixelData)

        return input
    }

    /// 원본 이미지 크기 대비 스케일 비율을 계산합니다.
    ///
    /// - Parameter originalSize: 원본 이미지 크기
    /// - Returns: (scaleX, scaleY) - 320×320 → 원본 좌표 변환용
    func calculateScale(from originalSize: CGSize) -> (x: Float, y: Float) {
        let scaleX = Float(originalSize.width) / Float(inputWidth)
        let scaleY = Float(originalSize.height) / Float(inputHeight)
        return (scaleX, scaleY)
    }

    // MARK: - Private Methods

    /// 이미지를 320×320으로 리사이즈하고 픽셀 데이터를 추출합니다.
    ///
    /// - Parameter image: 원본 CGImage
    /// - Returns: RGBA 픽셀 데이터 배열 (320×320×4 바이트)
    private func resizeAndExtractPixels(_ image: CGImage) -> [UInt8]? {
        let width = inputWidth
        let height = inputHeight
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        // RGBA 버퍼 생성
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        // Core Graphics 컨텍스트 생성
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // 이미지를 320×320으로 리사이즈하여 그리기
        // 주의: 단순 리사이즈 (aspect ratio 무시)
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return pixelData
    }

    /// RGBA 픽셀 데이터를 BGR 순서로 MLMultiArray에 복사합니다.
    ///
    /// - Parameters:
    ///   - multiArray: 대상 MLMultiArray (shape: [1, 3, H, W])
    ///   - pixelData: 소스 RGBA 픽셀 데이터
    ///
    /// iOS 이미지는 RGB 순서이므로 YuNet이 기대하는 BGR로 변환합니다.
    /// Channel 0 = Blue, Channel 1 = Green, Channel 2 = Red
    private func fillMultiArrayBGR(_ multiArray: MLMultiArray, from pixelData: [UInt8]) {
        let width = inputWidth
        let height = inputHeight
        let bytesPerPixel = 4

        // MLMultiArray 포인터 직접 접근 (성능 최적화)
        let pointer = multiArray.dataPointer.bindMemory(
            to: Float32.self,
            capacity: 3 * height * width
        )

        // 채널별 오프셋 계산 (NCHW 포맷)
        // pointer[0 * H * W + y * W + x] = Blue
        // pointer[1 * H * W + y * W + x] = Green
        // pointer[2 * H * W + y * W + x] = Red
        let channelStride = height * width

        for y in 0..<height {
            for x in 0..<width {
                let pixelIndex = (y * width + x) * bytesPerPixel
                let spatialIndex = y * width + x

                // RGBA 순서로 읽어서 BGR 순서로 저장
                let r = Float32(pixelData[pixelIndex + 0])     // Red
                let g = Float32(pixelData[pixelIndex + 1])     // Green
                let b = Float32(pixelData[pixelIndex + 2])     // Blue
                // pixelData[pixelIndex + 3] = Alpha (무시)

                // BGR 순서로 저장 (0-255 범위 그대로)
                pointer[0 * channelStride + spatialIndex] = b  // Channel 0 = Blue
                pointer[1 * channelStride + spatialIndex] = g  // Channel 1 = Green
                pointer[2 * channelStride + spatialIndex] = r  // Channel 2 = Red
            }
        }
    }
}

// MARK: - Accelerate Optimized Version (Alternative)

extension YuNetPreprocessor {
    /// vImage를 사용한 최적화된 리사이즈 (향후 성능 개선용)
    ///
    /// 현재는 CGContext 기반 구현 사용.
    /// 대량 이미지 처리 시 vImage로 교체 고려.
    @available(*, unavailable, message: "향후 성능 최적화 시 구현 예정")
    private func resizeWithVImage(_ image: CGImage) -> [UInt8]? {
        // TODO: vImageScale_ARGB8888 사용한 고성능 리사이즈
        fatalError("Not implemented")
    }
}

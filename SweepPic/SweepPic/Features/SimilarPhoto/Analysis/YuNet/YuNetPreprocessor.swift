//
//  YuNetPreprocessor.swift
//  SweepPic
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 SweepPic. All rights reserved.
//
//  Description:
//  YuNet 모델 입력을 위한 이미지 전처리를 담당합니다.
//  RGB → BGR 변환, 레터박스 리사이즈, NCHW 포맷 변환을 수행합니다.
//
//  Preprocessing Spec:
//  - Color: BGR (iOS RGB에서 R↔B 스왑 필요)
//  - Size: inputSize × inputSize (기본 1088)
//  - Resize: 레터박스 (비율 유지 + 검정 패딩)
//  - Range: 0-255 (정규화 없음)
//  - Format: NCHW (batch, channel, height, width)
//  - Mean: [0, 0, 0]
//  - Std: [1, 1, 1]
//

import Foundation
import CoreML
import CoreGraphics
import Accelerate

/// 레터박스 변환 정보
///
/// 원본 → 모델 좌표, 모델 → 원본 좌표 변환에 필요한 정보를 담습니다.
struct LetterboxInfo {
    /// 레터박스 내 이미지의 실제 스케일 (원본 → 모델)
    let scale: Float

    /// 레터박스 내 이미지의 X 오프셋 (패딩 크기)
    let offsetX: Float

    /// 레터박스 내 이미지의 Y 오프셋 (패딩 크기)
    let offsetY: Float

    /// 원본 이미지 크기
    let originalSize: CGSize
}

/// YuNet 전처리기
///
/// CGImage를 YuNet 모델 입력 형식인 MLMultiArray로 변환합니다.
/// BGR 순서, 레터박스 리사이즈, 0-255 범위, NCHW 포맷을 사용합니다.
final class YuNetPreprocessor {

    // MARK: - Constants

    /// 입력 이미지 크기
    private let inputWidth: Int
    private let inputHeight: Int

    // MARK: - Initialization

    /// 전처리기를 초기화합니다.
    /// - Parameter inputSize: 입력 이미지 크기 (기본: YuNetConfig.inputWidth)
    init(inputSize: Int = YuNetConfig.inputWidth) {
        self.inputWidth = inputSize
        self.inputHeight = inputSize
    }

    // MARK: - Public Methods

    /// CGImage를 YuNet 입력 형식으로 변환합니다.
    ///
    /// - Parameter image: 원본 CGImage (RGB)
    /// - Returns: (MLMultiArray, LetterboxInfo) — 모델 입력과 좌표 변환 정보
    /// - Throws: YuNetError.preprocessingFailed
    ///
    /// 변환 과정:
    /// 1. 레터박스 리사이즈 (비율 유지 + 검정 패딩)
    /// 2. RGB → BGR 변환
    /// 3. NCHW 포맷 MLMultiArray 생성
    func preprocess(_ image: CGImage) throws -> (MLMultiArray, LetterboxInfo) {
        let originalSize = CGSize(width: image.width, height: image.height)

        // 1. 레터박스 리사이즈하고 픽셀 데이터 추출
        let (pixelData, letterboxInfo) = try resizeWithLetterbox(image, originalSize: originalSize)

        // 2. MLMultiArray 생성 (NCHW: [1, 3, H, W])
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

        return (input, letterboxInfo)
    }

    /// 원본 이미지 크기 대비 스케일 비율을 계산합니다.
    /// (레거시 호환용 — 새 코드에서는 LetterboxInfo 사용)
    ///
    /// - Parameter originalSize: 원본 이미지 크기
    /// - Returns: (scaleX, scaleY) — 레터박스 적용 시 동일한 scale 반환
    func calculateScale(from originalSize: CGSize) -> (x: Float, y: Float) {
        let scale = min(
            Float(inputWidth) / Float(originalSize.width),
            Float(inputHeight) / Float(originalSize.height)
        )
        // 레터박스에서는 x, y 스케일이 동일 (비율 유지)
        return (1.0 / scale, 1.0 / scale)
    }

    // MARK: - Private Methods

    /// 이미지를 레터박스 방식으로 리사이즈하고 픽셀 데이터를 추출합니다.
    ///
    /// 비율을 유지한 채 inputSize × inputSize 캔버스 중앙에 배치하고,
    /// 나머지 영역은 검정(0)으로 채웁니다.
    ///
    /// - Parameters:
    ///   - image: 원본 CGImage
    ///   - originalSize: 원본 이미지 크기
    /// - Returns: (RGBA 픽셀 데이터, LetterboxInfo)
    private func resizeWithLetterbox(
        _ image: CGImage,
        originalSize: CGSize
    ) throws -> ([UInt8], LetterboxInfo) {
        let canvasWidth = inputWidth
        let canvasHeight = inputHeight
        let bytesPerPixel = 4
        let bytesPerRow = canvasWidth * bytesPerPixel

        // 비율 유지 스케일 계산 (작은 쪽에 맞춤)
        let scale = min(
            Float(canvasWidth) / Float(originalSize.width),
            Float(canvasHeight) / Float(originalSize.height)
        )

        // 리사이즈된 이미지 크기
        let resizedW = Int(Float(originalSize.width) * scale)
        let resizedH = Int(Float(originalSize.height) * scale)

        // 중앙 배치를 위한 오프셋
        let offsetX = (canvasWidth - resizedW) / 2
        let offsetY = (canvasHeight - resizedH) / 2

        // 검정 배경 RGBA 버퍼 생성 (0으로 초기화 = 검정)
        var pixelData = [UInt8](repeating: 0, count: canvasWidth * canvasHeight * bytesPerPixel)

        // Core Graphics 컨텍스트 생성
        guard let context = CGContext(
            data: &pixelData,
            width: canvasWidth,
            height: canvasHeight,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw YuNetError.preprocessingFailed("레터박스 컨텍스트 생성 실패")
        }

        // 이미지를 비율 유지하며 중앙에 그리기
        // CGContext는 좌하단 원점이므로 Y 오프셋도 동일하게 적용
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(
            x: offsetX,
            y: offsetY,
            width: resizedW,
            height: resizedH
        ))

        let letterboxInfo = LetterboxInfo(
            scale: scale,
            offsetX: Float(offsetX),
            offsetY: Float(offsetY),
            originalSize: originalSize
        )

        return (pixelData, letterboxInfo)
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

//
//  FaceCropper.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  얼굴 영역을 크롭하는 유틸리티입니다.
//  bounding box에 30% 여백을 추가하고 1:1 정사각형으로 조정합니다.
//
//  Cropping Rules:
//  - 30% 여백 추가 (상하좌우 각각)
//  - 1:1 정사각형 조정
//  - 경계 처리: 중심 고정, 경계 내 최대 크기로 축소
//

import Foundation
import UIKit
import CoreGraphics

/// 얼굴 크롭 에러
enum FaceCropError: Error, LocalizedError {
    /// 잘못된 bounding box
    case invalidBoundingBox

    /// 크롭 영역이 이미지 밖
    case outOfBounds

    /// 이미지 생성 실패
    case cropFailed

    var errorDescription: String? {
        switch self {
        case .invalidBoundingBox:
            return "잘못된 bounding box"
        case .outOfBounds:
            return "크롭 영역이 이미지 경계를 벗어남"
        case .cropFailed:
            return "이미지 크롭 실패"
        }
    }
}

/// 얼굴 영역 크롭 유틸리티
///
/// 감지된 얼굴의 bounding box에 여백을 추가하고
/// 정사각형으로 조정하여 크롭합니다.
///
/// - Note: 비교 화면의 2열 그리드에서 사용됩니다.
enum FaceCropper {

    // MARK: - Configuration

    /// 여백 비율 (bounding box 대비)
    static let paddingRatio: CGFloat = SimilarityConstants.faceCropPaddingRatio

    // MARK: - Public Methods

    /// 이미지에서 얼굴 영역을 크롭합니다.
    ///
    /// - Parameters:
    ///   - image: 원본 CGImage
    ///   - boundingBox: Vision 정규화 좌표 (0~1, 원점 좌하단)
    /// - Returns: 크롭된 CGImage (정사각형)
    /// - Throws: FaceCropError
    static func cropFace(from image: CGImage, boundingBox: CGRect) throws -> CGImage {
        // 이미지 크기
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        // Vision 좌표를 픽셀 좌표로 변환
        var pixelRect = convertToPixelCoordinates(
            boundingBox: boundingBox,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        // 30% 여백 추가
        pixelRect = addPadding(to: pixelRect, ratio: paddingRatio)

        // 정사각형으로 조정
        pixelRect = makeSquare(rect: pixelRect)

        // 경계 클램핑
        pixelRect = clampToBounds(
            rect: pixelRect,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        // 크롭 실행
        guard let croppedImage = image.cropping(to: pixelRect) else {
            throw FaceCropError.cropFailed
        }

        return croppedImage
    }

    /// UIImage에서 얼굴 영역을 크롭합니다.
    ///
    /// - Parameters:
    ///   - image: 원본 UIImage
    ///   - boundingBox: Vision 정규화 좌표
    /// - Returns: 크롭된 UIImage (정사각형)
    /// - Throws: FaceCropError
    static func cropFace(from image: UIImage, boundingBox: CGRect) throws -> UIImage {
        guard let cgImage = image.cgImage else {
            throw FaceCropError.cropFailed
        }

        let croppedCGImage = try cropFace(from: cgImage, boundingBox: boundingBox)
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: image.imageOrientation)
    }

    /// 크롭 영역을 계산합니다 (실제 크롭 없이).
    ///
    /// - Parameters:
    ///   - boundingBox: Vision 정규화 좌표
    ///   - imageSize: 이미지 크기
    /// - Returns: 크롭할 픽셀 영역 (정사각형, 여백 포함)
    static func calculateCropRect(boundingBox: CGRect, imageSize: CGSize) -> CGRect {
        var pixelRect = convertToPixelCoordinates(
            boundingBox: boundingBox,
            imageWidth: imageSize.width,
            imageHeight: imageSize.height
        )

        pixelRect = addPadding(to: pixelRect, ratio: paddingRatio)
        pixelRect = makeSquare(rect: pixelRect)
        pixelRect = clampToBounds(
            rect: pixelRect,
            imageWidth: imageSize.width,
            imageHeight: imageSize.height
        )

        return pixelRect
    }

    // MARK: - Private Methods

    /// Vision 좌표를 픽셀 좌표로 변환합니다.
    ///
    /// Vision: 원점 좌하단, Y 위로 증가 (0~1)
    /// Pixel: 원점 좌상단, Y 아래로 증가
    private static func convertToPixelCoordinates(
        boundingBox: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect {
        let x = boundingBox.origin.x * imageWidth
        // Y축 반전: Vision의 원점이 좌하단이므로
        let y = (1 - boundingBox.origin.y - boundingBox.height) * imageHeight
        let width = boundingBox.width * imageWidth
        let height = boundingBox.height * imageHeight

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// 여백을 추가합니다.
    ///
    /// - Parameters:
    ///   - rect: 원본 영역
    ///   - ratio: 여백 비율 (각 방향)
    /// - Returns: 여백이 추가된 영역
    private static func addPadding(to rect: CGRect, ratio: CGFloat) -> CGRect {
        let paddingX = rect.width * ratio
        let paddingY = rect.height * ratio

        return CGRect(
            x: rect.origin.x - paddingX,
            y: rect.origin.y - paddingY,
            width: rect.width + paddingX * 2,
            height: rect.height + paddingY * 2
        )
    }

    /// 정사각형으로 조정합니다.
    ///
    /// 큰 쪽 길이를 기준으로 정사각형을 만들고 중심을 유지합니다.
    private static func makeSquare(rect: CGRect) -> CGRect {
        let size = max(rect.width, rect.height)
        let centerX = rect.midX
        let centerY = rect.midY

        return CGRect(
            x: centerX - size / 2,
            y: centerY - size / 2,
            width: size,
            height: size
        )
    }

    /// 이미지 경계 내로 클램핑합니다.
    ///
    /// 중심을 고정하고, 경계를 벗어나면 크기를 축소합니다.
    private static func clampToBounds(
        rect: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect {
        var result = rect

        // 경계를 벗어나는 경우 크기 축소
        let maxSize = min(
            imageWidth,
            imageHeight,
            rect.width
        )

        // 크기가 축소되어야 하는 경우
        if result.width > maxSize {
            let centerX = result.midX
            let centerY = result.midY
            result = CGRect(
                x: centerX - maxSize / 2,
                y: centerY - maxSize / 2,
                width: maxSize,
                height: maxSize
            )
        }

        // 위치 클램핑
        if result.origin.x < 0 {
            result.origin.x = 0
        }
        if result.origin.y < 0 {
            result.origin.y = 0
        }
        if result.maxX > imageWidth {
            result.origin.x = imageWidth - result.width
        }
        if result.maxY > imageHeight {
            result.origin.y = imageHeight - result.height
        }

        // 최종 검증
        result.origin.x = max(0, result.origin.x)
        result.origin.y = max(0, result.origin.y)
        result.size.width = min(result.width, imageWidth - result.origin.x)
        result.size.height = min(result.height, imageHeight - result.origin.y)

        return result
    }
}

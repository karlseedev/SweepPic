// FaceCropper.swift
// 얼굴 영역 크롭 유틸리티
//
// T008: FaceCropper 생성
// - bounding box + 30% 여백 + 정사각형 크롭
// - 경계 처리: 중심 고정, 경계 내 최대 크기로 축소

import CoreGraphics
import UIKit

/// 얼굴 크롭 유틸리티
/// Vision에서 감지한 얼굴 영역을 크롭하여 Feature Print 비교에 사용
enum FaceCropper {

    // MARK: - Constants

    /// 얼굴 주변 여백 비율 (30%)
    /// - bounding box 너비/높이 각각 30% 추가
    static let marginRatio: CGFloat = 0.30

    // MARK: - Public Methods

    /// 얼굴 영역 크롭
    /// - Parameters:
    ///   - image: 원본 CGImage
    ///   - boundingBox: Vision 정규화 좌표 (0~1, 원점 좌하단)
    /// - Returns: 크롭된 정사각형 CGImage (실패 시 nil)
    static func cropFace(from image: CGImage, boundingBox: CGRect) -> CGImage? {
        let imageWidth = CGFloat(image.width)
        let imageHeight = CGFloat(image.height)

        // 1. Vision 좌표 → 픽셀 좌표 변환 (Y축 반전)
        let faceRect = CGRect(
            x: boundingBox.origin.x * imageWidth,
            y: (1 - boundingBox.origin.y - boundingBox.height) * imageHeight,
            width: boundingBox.width * imageWidth,
            height: boundingBox.height * imageHeight
        )

        // 2. 30% 여백 추가
        let marginX = faceRect.width * marginRatio
        let marginY = faceRect.height * marginRatio
        var expandedRect = faceRect.insetBy(dx: -marginX, dy: -marginY)

        // 3. 정사각형으로 조정 (긴 변 기준)
        let squareSize = max(expandedRect.width, expandedRect.height)
        let centerX = expandedRect.midX
        let centerY = expandedRect.midY
        var squareRect = CGRect(
            x: centerX - squareSize / 2,
            y: centerY - squareSize / 2,
            width: squareSize,
            height: squareSize
        )

        // 4. 이미지 경계 처리
        squareRect = clampToImageBounds(
            rect: squareRect,
            imageWidth: imageWidth,
            imageHeight: imageHeight
        )

        // 5. 크롭 실행
        guard squareRect.width > 0 && squareRect.height > 0 else {
            return nil
        }

        return image.cropping(to: squareRect)
    }

    /// 여러 얼굴 영역 크롭
    /// - Parameters:
    ///   - image: 원본 CGImage
    ///   - boundingBoxes: Vision 정규화 좌표 배열
    /// - Returns: 크롭된 CGImage 배열 (순서 유지, 실패 시 해당 위치 nil)
    static func cropFaces(from image: CGImage, boundingBoxes: [CGRect]) -> [CGImage?] {
        return boundingBoxes.map { cropFace(from: image, boundingBox: $0) }
    }

    // MARK: - Private Methods

    /// 이미지 경계 내로 rect 클램핑
    /// - 중심 고정, 경계 내 최대 크기로 축소
    private static func clampToImageBounds(
        rect: CGRect,
        imageWidth: CGFloat,
        imageHeight: CGFloat
    ) -> CGRect {
        var result = rect

        // X축 클램핑
        if result.minX < 0 {
            let overflow = -result.minX
            result.origin.x = 0
            result.size.width -= overflow
        }
        if result.maxX > imageWidth {
            let overflow = result.maxX - imageWidth
            result.size.width -= overflow
        }

        // Y축 클램핑
        if result.minY < 0 {
            let overflow = -result.minY
            result.origin.y = 0
            result.size.height -= overflow
        }
        if result.maxY > imageHeight {
            let overflow = result.maxY - imageHeight
            result.size.height -= overflow
        }

        // 정사각형 유지 (작은 변 기준)
        let minSide = min(result.width, result.height)
        if minSide != result.width || minSide != result.height {
            let centerX = result.midX
            let centerY = result.midY
            result = CGRect(
                x: max(0, centerX - minSide / 2),
                y: max(0, centerY - minSide / 2),
                width: minSide,
                height: minSide
            )
        }

        // 정수 픽셀로 반올림
        return CGRect(
            x: floor(result.origin.x),
            y: floor(result.origin.y),
            width: floor(result.width),
            height: floor(result.height)
        )
    }
}

// MARK: - UIImage Extension

extension FaceCropper {

    /// UIImage에서 얼굴 크롭 (편의 메서드)
    /// - Parameters:
    ///   - image: 원본 UIImage
    ///   - boundingBox: Vision 정규화 좌표
    /// - Returns: 크롭된 UIImage (실패 시 nil)
    static func cropFace(from image: UIImage, boundingBox: CGRect) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        guard let croppedCG = cropFace(from: cgImage, boundingBox: boundingBox) else { return nil }
        return UIImage(cgImage: croppedCG, scale: image.scale, orientation: image.imageOrientation)
    }
}

// MARK: - Cached Face Extension

extension FaceCropper {

    /// CachedFace에서 얼굴 크롭
    /// - Parameters:
    ///   - image: 원본 CGImage
    ///   - face: CachedFace 정보
    /// - Returns: 크롭된 CGImage (실패 시 nil)
    static func cropFace(from image: CGImage, face: CachedFace) -> CGImage? {
        return cropFace(from: image, boundingBox: face.boundingBox)
    }
}

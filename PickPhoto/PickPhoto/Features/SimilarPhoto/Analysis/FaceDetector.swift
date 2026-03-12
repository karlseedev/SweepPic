//
//  FaceDetector.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  Vision Framework를 사용한 얼굴 감지기입니다.
//  VNDetectFaceRectanglesRequest를 활용하여 이미지에서 얼굴을 감지합니다.
//
//  Filtering Rules:
//  - 크기순 상위 5개만 반환
//
//  Coordinate System:
//  - Vision 정규화 좌표: (0~1, 원점 좌하단)
//

import Foundation
import Photos
import Vision
import UIKit

/// 감지된 얼굴 정보
struct DetectedFace: Equatable {
    /// Vision 정규화 좌표 (0~1, 원점 좌하단)
    let boundingBox: CGRect

    /// 얼굴 영역 면적 (정렬용)
    var area: CGFloat {
        boundingBox.width * boundingBox.height
    }
}

/// 얼굴 감지 에러
enum FaceDetectionError: Error, LocalizedError {
    /// 이미지 로딩 실패
    case imageLoadFailed(String)

    /// 얼굴 감지 실패
    case detectionFailed(String)

    /// 요청 취소됨
    case cancelled

    var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let reason):
            return "이미지 로딩 실패: \(reason)"
        case .detectionFailed(let reason):
            return "얼굴 감지 실패: \(reason)"
        case .cancelled:
            return "얼굴 감지가 취소되었습니다"
        }
    }
}

/// Vision Framework 기반 얼굴 감지기
///
/// VNDetectFaceRectanglesRequest를 사용하여 이미지에서 얼굴을 감지합니다.
/// 긴 변 1600px 이미지를 사용하여 작은 얼굴의 감지 정확도를 높이고,
/// 크기순 상위 5개만 반환합니다.
final class FaceDetector {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = FaceDetector()

    // MARK: - Dependencies

    /// 이미지 로더
    private let imageLoader: SimilarityImageLoader

    // MARK: - Configuration

    /// 최대 얼굴 수
    private let maxFaces: Int

    // MARK: - Initialization

    /// 얼굴 감지기를 초기화합니다.
    ///
    /// - Parameters:
    ///   - imageLoader: 이미지 로더 (기본값: 공유 인스턴스)
    ///   - maxFaces: 최대 얼굴 수 (기본값: 5)
    init(
        imageLoader: SimilarityImageLoader = .shared,
        maxFaces: Int = SimilarityConstants.maxFacesPerPhoto
    ) {
        self.imageLoader = imageLoader
        self.maxFaces = maxFaces
    }

    // MARK: - Public Methods

    /// 사진에서 얼굴을 감지합니다.
    ///
    /// - Parameter photo: 감지할 PHAsset
    /// - Returns: 감지된 얼굴 배열 (크기순 상위 5개)
    /// - Throws: FaceDetectionError
    ///
    /// - Important: 긴 변 1600px 이미지를 사용하며, 크기순 상위 5개가 반환됩니다.
    func detectFaces(in photo: PHAsset) async throws -> [DetectedFace] {
        // 1. 이미지 로딩 (긴 변 1600px)
        let cgImage: CGImage
        do {
            cgImage = try await imageLoader.loadImage(
                for: photo,
                maxSize: SimilarityConstants.faceDetectionImageMaxSize
            )
        } catch {
            // [Analytics] 얼굴 감지용 이미지 로딩 실패
            AnalyticsService.shared.countError(.detection as AnalyticsError.Face)
            throw FaceDetectionError.imageLoadFailed(error.localizedDescription)
        }

        // 2. 얼굴 감지
        let allFaces = try await detectFaces(in: cgImage)

        // 3. 크기순 상위 5개
        let topFaces = allFaces
            .sorted { $0.area > $1.area }
            .prefix(maxFaces)

        return Array(topFaces)
    }

    /// CGImage에서 얼굴을 감지합니다.
    ///
    /// - Parameter image: 감지할 CGImage
    /// - Returns: 감지된 모든 얼굴 (필터링 전)
    /// - Throws: FaceDetectionError
    func detectFaces(in image: CGImage) async throws -> [DetectedFace] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.performFaceDetection(on: image)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods

    /// Vision 얼굴 감지를 수행합니다.
    ///
    /// - Parameter image: 감지할 CGImage
    /// - Returns: 감지된 얼굴 배열
    /// - Throws: FaceDetectionError
    private func performFaceDetection(on image: CGImage) throws -> [DetectedFace] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            // [Analytics] Vision 얼굴 감지 실패
            AnalyticsService.shared.countError(.detection as AnalyticsError.Face)
            throw FaceDetectionError.detectionFailed(error.localizedDescription)
        }

        guard let results = request.results else {
            return []
        }

        return results.map { observation in
            DetectedFace(boundingBox: observation.boundingBox)
        }
    }

}

// MARK: - Array Extensions

extension Array where Element == DetectedFace {
    /// 크기순으로 정렬합니다 (내림차순).
    func sortedBySize() -> [DetectedFace] {
        sorted { $0.area > $1.area }
    }

    /// 상위 N개만 반환합니다.
    func top(_ count: Int) -> [DetectedFace] {
        Array(prefix(count))
    }
}

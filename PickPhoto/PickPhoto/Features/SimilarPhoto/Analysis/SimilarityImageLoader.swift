//
//  SimilarityImageLoader.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  유사도 분석을 위한 이미지 로더입니다.
//  PHCachingImageManager를 활용하여 분석용 최적 해상도로 이미지를 로딩합니다.
//
//  Image Specifications:
//  - 긴 변 480px 이하
//  - contentMode: aspectFit (패딩/크롭 금지, 원본 비율 유지)
//  - 타임아웃: 3초
//

import Foundation
import Photos
import UIKit

/// 유사도 분석을 위한 이미지 로딩 에러
enum SimilarityImageLoadError: Error, LocalizedError {
    /// 이미지 로딩 실패
    case loadFailed(String)

    /// 타임아웃 발생
    case timeout

    /// 잘못된 이미지 형식
    case invalidImage

    /// 사진 접근 권한 없음
    case accessDenied

    var errorDescription: String? {
        switch self {
        case .loadFailed(let reason):
            return "이미지 로딩 실패: \(reason)"
        case .timeout:
            return "이미지 로딩 타임아웃 (3초 초과)"
        case .invalidImage:
            return "잘못된 이미지 형식"
        case .accessDenied:
            return "사진 접근 권한이 없습니다"
        }
    }
}

/// 유사도 분석을 위한 이미지 로더
///
/// PHCachingImageManager를 사용하여 분석에 최적화된 해상도로 이미지를 로딩합니다.
/// 분석 정확도와 성능의 균형을 위해 긴 변 480px 이하로 리사이즈합니다.
final class SimilarityImageLoader {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SimilarityImageLoader()

    // MARK: - Properties

    /// 이미지 매니저
    private let imageManager: PHCachingImageManager

    /// 분석용 이미지 요청 옵션
    private let requestOptions: PHImageRequestOptions

    /// 분석용 이미지 최대 크기
    private let maxSize: CGFloat

    /// 타임아웃 시간 (초)
    private let timeout: TimeInterval

    // MARK: - Initialization

    /// 이미지 로더를 초기화합니다.
    ///
    /// - Parameters:
    ///   - imageManager: 사용할 이미지 매니저 (기본값: 새 인스턴스)
    ///   - maxSize: 분석용 이미지 최대 크기 (기본값: 480px)
    ///   - timeout: 타임아웃 시간 (기본값: 3초)
    init(
        imageManager: PHCachingImageManager = PHCachingImageManager(),
        maxSize: CGFloat = SimilarityConstants.analysisImageMaxSize,
        timeout: TimeInterval = SimilarityConstants.analysisTimeout
    ) {
        self.imageManager = imageManager
        self.maxSize = maxSize
        self.timeout = timeout

        // 요청 옵션 설정
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true  // iCloud 사진 지원
        options.isSynchronous = false
        self.requestOptions = options
    }

    // MARK: - Public Methods

    /// 분석용 이미지를 로딩합니다.
    ///
    /// - Parameter asset: 로딩할 PHAsset
    /// - Returns: 분석용으로 리사이즈된 CGImage
    /// - Throws: SimilarityImageLoadError
    ///
    /// - Important: 긴 변 480px 이하로 리사이즈되며, 원본 비율이 유지됩니다.
    func loadImage(for asset: PHAsset) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            // 타겟 크기 계산 (긴 변 기준)
            let targetSize = calculateTargetSize(for: asset)

            // 타임아웃 작업 아이템
            let timeoutItem = DispatchWorkItem { [weak self] in
                guard self != nil else { return }
                continuation.resume(throwing: SimilarityImageLoadError.timeout)
            }

            // 타임아웃 스케줄
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            // 이미지 요청
            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,  // 패딩/크롭 금지, 원본 비율 유지
                options: requestOptions
            ) { image, info in
                // 타임아웃 취소
                timeoutItem.cancel()

                // 에러 처리
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: SimilarityImageLoadError.loadFailed(error.localizedDescription))
                    return
                }

                // 취소 확인
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: SimilarityImageLoadError.loadFailed("요청이 취소됨"))
                    return
                }

                // 이미지 검증
                guard let uiImage = image else {
                    continuation.resume(throwing: SimilarityImageLoadError.loadFailed("이미지 nil"))
                    return
                }

                guard let cgImage = uiImage.cgImage else {
                    continuation.resume(throwing: SimilarityImageLoadError.invalidImage)
                    return
                }

                continuation.resume(returning: cgImage)
            }
        }
    }

    /// 분석용 UIImage를 로딩합니다.
    ///
    /// - Parameter asset: 로딩할 PHAsset
    /// - Returns: 분석용으로 리사이즈된 UIImage
    /// - Throws: SimilarityImageLoadError
    func loadUIImage(for asset: PHAsset) async throws -> UIImage {
        let cgImage = try await loadImage(for: asset)
        return UIImage(cgImage: cgImage)
    }

    /// 여러 이미지를 병렬로 로딩합니다.
    ///
    /// - Parameter assets: 로딩할 PHAsset 배열
    /// - Returns: (인덱스, CGImage?) 배열 (실패 시 nil)
    ///
    /// - Note: 개별 로딩 실패는 nil로 처리되며, 전체 로딩은 계속 진행됩니다.
    func loadImages(for assets: [PHAsset]) async -> [(Int, CGImage?)] {
        await withTaskGroup(of: (Int, CGImage?).self) { group in
            for (index, asset) in assets.enumerated() {
                group.addTask {
                    do {
                        let image = try await self.loadImage(for: asset)
                        return (index, image)
                    } catch {
                        // 개별 실패는 nil로 처리
                        return (index, nil)
                    }
                }
            }

            var results: [(Int, CGImage?)] = []
            for await result in group {
                results.append(result)
            }

            // 인덱스 순서대로 정렬
            return results.sorted { $0.0 < $1.0 }
        }
    }

    // MARK: - Private Methods

    /// 타겟 크기를 계산합니다.
    ///
    /// - Parameter asset: 대상 PHAsset
    /// - Returns: 분석용 타겟 크기
    private func calculateTargetSize(for asset: PHAsset) -> CGSize {
        let pixelWidth = CGFloat(asset.pixelWidth)
        let pixelHeight = CGFloat(asset.pixelHeight)

        // 긴 변 기준으로 스케일 계산
        let longerSide = max(pixelWidth, pixelHeight)

        // 이미 maxSize 이하면 원본 크기 사용
        if longerSide <= maxSize {
            return CGSize(width: pixelWidth, height: pixelHeight)
        }

        // 스케일 계산
        let scale = maxSize / longerSide

        return CGSize(
            width: pixelWidth * scale,
            height: pixelHeight * scale
        )
    }

    // MARK: - Caching Control

    /// 특정 에셋들에 대한 캐싱을 시작합니다.
    ///
    /// - Parameters:
    ///   - assets: 캐싱할 PHAsset 배열
    ///   - targetSize: 타겟 크기 (nil이면 분석용 기본 크기)
    func startCaching(assets: [PHAsset], targetSize: CGSize? = nil) {
        let size = targetSize ?? CGSize(width: maxSize, height: maxSize)
        imageManager.startCachingImages(
            for: assets,
            targetSize: size,
            contentMode: .aspectFit,
            options: requestOptions
        )
    }

    /// 특정 에셋들에 대한 캐싱을 중지합니다.
    ///
    /// - Parameters:
    ///   - assets: 캐싱 중지할 PHAsset 배열
    ///   - targetSize: 타겟 크기 (nil이면 분석용 기본 크기)
    func stopCaching(assets: [PHAsset], targetSize: CGSize? = nil) {
        let size = targetSize ?? CGSize(width: maxSize, height: maxSize)
        imageManager.stopCachingImages(
            for: assets,
            targetSize: size,
            contentMode: .aspectFit,
            options: requestOptions
        )
    }

    /// 모든 캐싱을 중지합니다.
    func stopCachingAllImages() {
        imageManager.stopCachingImagesForAllAssets()
    }
}

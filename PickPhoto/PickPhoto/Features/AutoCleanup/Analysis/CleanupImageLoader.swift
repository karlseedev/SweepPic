//
//  CleanupImageLoader.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-27.
//
//  AutoCleanup 전용 이미지 로더
//  - 짧은 변 360px 기준 다운샘플링
//  - 세로로 긴 이미지(블로그 캡쳐 등)에서도 텍스트 감지 가능
//  - SimilarPhoto의 SimilarityImageLoader와 독립적으로 운영
//

import Foundation
import Photos
import UIKit

/// AutoCleanup용 이미지 로딩 에러
enum CleanupImageLoadError: Error, LocalizedError {
    /// 이미지 로딩 실패
    case loadFailed(String)

    /// 타임아웃 발생
    case timeout

    /// 잘못된 이미지 형식
    case invalidImage

    var errorDescription: String? {
        switch self {
        case .loadFailed(let reason):
            return "이미지 로딩 실패: \(reason)"
        case .timeout:
            return "이미지 로딩 타임아웃"
        case .invalidImage:
            return "잘못된 이미지 형식"
        }
    }
}

/// AutoCleanup 전용 이미지 로더
///
/// PHCachingImageManager를 사용하여 품질 분석에 최적화된 해상도로 이미지를 로딩합니다.
/// 짧은 변 360px 기준으로 다운샘플링하여 세로로 긴 이미지에서도 텍스트 감지가 가능합니다.
///
/// - Note: SimilarPhoto의 SimilarityImageLoader(긴 변 480px)와 다른 기준을 사용합니다.
final class CleanupImageLoader {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = CleanupImageLoader()

    // MARK: - Properties

    /// 이미지 매니저
    private let imageManager: PHCachingImageManager

    /// 분석용 이미지 요청 옵션
    private let requestOptions: PHImageRequestOptions

    /// 분석용 이미지 최소 크기 (짧은 변 기준)
    private let minSize: CGFloat

    /// 타임아웃 시간 (초)
    private let timeout: TimeInterval

    // MARK: - Initialization

    /// 이미지 로더 초기화
    ///
    /// - Parameters:
    ///   - imageManager: 사용할 이미지 매니저 (기본값: 새 인스턴스)
    ///   - minSize: 분석용 이미지 최소 크기 - 짧은 변 기준 (기본값: 360px)
    ///   - timeout: 타임아웃 시간 (기본값: 5초)
    init(
        imageManager: PHCachingImageManager = PHCachingImageManager(),
        minSize: CGFloat = CleanupConstants.analysisImageMinSize,
        timeout: TimeInterval = CleanupConstants.analysisTimeout
    ) {
        self.imageManager = imageManager
        self.minSize = minSize
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

    /// 분석용 이미지 로딩
    ///
    /// - Parameter asset: 로딩할 PHAsset
    /// - Returns: 분석용으로 리사이즈된 CGImage
    /// - Throws: CleanupImageLoadError
    ///
    /// - Important: 짧은 변 360px 기준으로 리사이즈되며, 원본 비율이 유지됩니다.
    func loadImage(for asset: PHAsset) async throws -> CGImage {
        return try await loadImage(for: asset, targetMinSize: minSize)
    }

    /// SafeGuard 얼굴 체크용 이미지 로딩
    ///
    /// - Parameter asset: 로딩할 PHAsset
    /// - Returns: 얼굴 감지에 최적화된 해상도의 CGImage
    /// - Throws: CleanupImageLoadError
    ///
    /// - Important: 짧은 변 720px 기준으로 리사이즈되며, 원본 비율이 유지됩니다.
    ///   360px에서 놓칠 수 있는 작은 얼굴의 감지 정확도를 높입니다.
    func loadImageForSafeGuard(for asset: PHAsset) async throws -> CGImage {
        return try await loadImage(for: asset, targetMinSize: CleanupConstants.safeGuardImageMinSize)
    }

    // MARK: - Private Methods

    /// 지정된 최소 크기로 이미지 로딩 (내부 공통 로직)
    ///
    /// - Parameters:
    ///   - asset: 로딩할 PHAsset
    ///   - targetMinSize: 짧은 변 기준 최소 크기 (픽셀)
    /// - Returns: 리사이즈된 CGImage
    /// - Throws: CleanupImageLoadError
    private func loadImage(for asset: PHAsset, targetMinSize: CGFloat) async throws -> CGImage {
        return try await withCheckedThrowingContinuation { continuation in
            // 타겟 크기 계산 (짧은 변 기준)
            let targetSize = calculateTargetSize(for: asset, targetMinSize: targetMinSize)

            // 요청 ID 저장용
            var requestID: PHImageRequestID?

            // 타임아웃 작업 - 요청 취소만 함
            let timeoutItem = DispatchWorkItem { [weak self] in
                guard let self = self, let id = requestID else { return }
                self.imageManager.cancelImageRequest(id)
            }

            // 타임아웃 스케줄
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            // 이미지 요청
            requestID = imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                // 타임아웃 취소
                timeoutItem.cancel()

                // degraded (저품질) 이미지는 무시
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }

                // 취소됨 (타임아웃 포함)
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: CleanupImageLoadError.timeout)
                    return
                }

                // 에러 처리
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: CleanupImageLoadError.loadFailed(error.localizedDescription))
                    return
                }

                // 이미지 검증
                guard let uiImage = image else {
                    continuation.resume(throwing: CleanupImageLoadError.loadFailed("이미지 nil"))
                    return
                }

                guard let cgImage = uiImage.cgImage else {
                    continuation.resume(throwing: CleanupImageLoadError.invalidImage)
                    return
                }

                continuation.resume(returning: cgImage)
            }
        }
    }

    /// 타겟 크기 계산 (짧은 변 기준)
    ///
    /// - Parameters:
    ///   - asset: 대상 PHAsset
    ///   - targetMinSize: 짧은 변 기준 최소 크기
    /// - Returns: 리사이즈 타겟 크기
    ///
    /// - Note: 긴 변이 아닌 짧은 변을 기준으로 스케일을 계산합니다.
    ///   예시 (targetMinSize = 360):
    ///   - 4000×3000 → 480×360 (짧은 변 360)
    ///   - 780×4228 → 360×1953 (짧은 변 360)
    private func calculateTargetSize(for asset: PHAsset, targetMinSize: CGFloat) -> CGSize {
        let pixelWidth = CGFloat(asset.pixelWidth)
        let pixelHeight = CGFloat(asset.pixelHeight)

        // 짧은 변 기준으로 스케일 계산
        let shorterSide = min(pixelWidth, pixelHeight)

        // 이미 targetMinSize 이하면 원본 크기 사용
        if shorterSide <= targetMinSize {
            return CGSize(width: pixelWidth, height: pixelHeight)
        }

        // 스케일 계산
        let scale = targetMinSize / shorterSide

        return CGSize(
            width: pixelWidth * scale,
            height: pixelHeight * scale
        )
    }
}

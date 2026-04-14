//
//  VideoFrameExtractor.swift
//  SweepPic
//
//  Created by Claude on 2026-01-26.
//
//  동영상 프레임 추출기
//  - 1초 이상 5초 이하 동영상에서 3개 프레임 추출 (10%, 50%, 90% 시점)
//  - 1초 미만은 QualityAnalyzer에서 저품질 확정 처리
//  - AVAssetImageGenerator 사용
//  - iCloud-only 동영상은 SKIP
//

import Foundation
import AppCore
import Photos
import AVFoundation

/// 프레임 추출 에러
enum VideoFrameExtractError: Error {
    /// 동영상 URL 획득 실패
    case urlNotAvailable

    /// iCloud 전용 (로컬 파일 없음)
    case iCloudOnly

    /// 동영상이 아님
    case notVideo

    /// 프레임 추출 실패
    case extractionFailed(String)

    /// 동영상 길이가 너무 짧음 (프레임 추출 불가)
    case tooShort

    /// 모든 프레임 추출 실패
    case allFramesFailed

}

/// 동영상 프레임 추출기
///
/// 1초 이상 5초 이하 동영상에서 분석용 프레임 3개를 추출합니다.
/// - 추출 시점: 10%, 50%, 90%
/// - iCloud-only 동영상은 SKIP
final class VideoFrameExtractor {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = VideoFrameExtractor()

    // MARK: - Properties

    /// 프레임 추출 시점 비율 (0.0 ~ 1.0)
    private let framePositions: [Double] = [0.10, 0.50, 0.90]

    /// 이미지 요청 옵션
    private let videoRequestOptions: PHVideoRequestOptions

    // MARK: - Initialization

    init() {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = false  // iCloud 다운로드 안 함
        options.deliveryMode = .fastFormat
        self.videoRequestOptions = options
    }

    // MARK: - Public Methods

    /// 동영상에서 분석용 프레임 3개 추출
    ///
    /// - Parameter asset: 추출할 PHAsset (동영상)
    /// - Returns: CGImage 배열 (10%, 50%, 90% 시점)
    /// - Throws: VideoFrameExtractError
    ///
    /// - Important: 1초 이상 5초 이하 동영상만 대상 (1초 미만은 QualityAnalyzer에서 저품질 확정)
    func extractFrames(from asset: PHAsset) async throws -> [CGImage] {
        // 동영상 타입 확인
        guard asset.mediaType == .video else {
            throw VideoFrameExtractError.notVideo
        }

        // AVAsset 획득
        let avAsset = try await requestAVAsset(for: asset)

        // 프레임 추출
        let frames = try await extractFrames(from: avAsset, duration: asset.duration)

        return frames
    }

    // MARK: - Private Methods

    /// PHAsset에서 AVAsset 획득
    private func requestAVAsset(for asset: PHAsset) async throws -> AVAsset {
        return try await withCheckedThrowingContinuation { continuation in
            PHImageManager.default().requestAVAsset(
                forVideo: asset,
                options: videoRequestOptions
            ) { avAsset, _, info in
                // iCloud 전용 체크
                if let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool, isInCloud {
                    continuation.resume(throwing: VideoFrameExtractError.iCloudOnly)
                    return
                }

                // 에러 체크
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: VideoFrameExtractError.extractionFailed(error.localizedDescription))
                    return
                }

                guard let avAsset = avAsset else {
                    continuation.resume(throwing: VideoFrameExtractError.urlNotAvailable)
                    return
                }

                continuation.resume(returning: avAsset)
            }
        }
    }

    /// AVAsset에서 프레임 추출
    private func extractFrames(from avAsset: AVAsset, duration: Double) async throws -> [CGImage] {
        let generator = AVAssetImageGenerator(asset: avAsset)
        generator.appliesPreferredTrackTransform = true  // 회전 보정
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero

        // 분석용 크기로 제한 (긴 변 480px)
        generator.maximumSize = CGSize(width: 480, height: 480)

        var frames: [CGImage] = []

        for position in framePositions {
            let timeSeconds = duration * position
            let time = CMTime(seconds: timeSeconds, preferredTimescale: 600)

            do {
                let (cgImage, _) = try await generator.image(at: time)
                frames.append(cgImage)
            } catch {
                // 개별 프레임 실패는 계속 진행
                // [Analytics] 개별 프레임 추출 실패
                AnalyticsService.shared.countError(.frameExtract as AnalyticsError.Video)
            }
        }

        // 최소 1개 프레임 필요
        guard !frames.isEmpty else {
            throw VideoFrameExtractError.allFramesFailed
        }

        return frames
    }
}

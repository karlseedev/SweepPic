//
//  AnalysisError.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  분석 에러 정의
//  - 개별 사진 분석 중 발생할 수 있는 에러들
//  - 대부분의 에러는 SKIP 처리 (삭제 금지 원칙)
//

import Foundation

/// 분석 에러
///
/// 개별 사진 분석 중 발생할 수 있는 에러.
/// 대부분의 에러는 해당 사진을 SKIP 처리.
enum AnalysisError: Error, Equatable {

    /// 이미지 로드 실패
    /// - PHImageManager에서 이미지 요청 실패
    /// - 처리: SKIP (개별 사진)
    case imageLoadFailed(assetID: String)

    /// Metal 초기화 실패
    /// - MTLDevice 또는 MPSImageLaplacian 생성 실패
    /// - 처리: 전체 정리 중단
    case metalInitFailed

    /// Vision API 실패
    /// - VNDetectFaceCaptureQualityRequest 등 실패
    /// - 처리: SKIP (개별 사진)
    case visionFailed(String)

    /// AestheticsScore 실패
    /// - iOS 18+ CalculateImageAestheticsScoresRequest 실패
    /// - 처리: Metal 파이프라인 fallback
    case aestheticsFailed

    /// 타임아웃
    /// - 분석이 5초를 초과
    /// - 처리: SKIP (개별 사진)
    case timeout

    /// iCloud 이미지 불가
    /// - 로컬 캐시 썸네일 없음
    /// - 처리: SKIP (개별 사진)
    case iCloudOnly(assetID: String)

    /// 비디오 프레임 추출 실패
    /// - AVAssetImageGenerator 실패
    /// - 처리: SKIP (개별 비디오)
    case videoFrameExtractionFailed(assetID: String)
}

// MARK: - LocalizedError

extension AnalysisError: LocalizedError {

    /// 에러 설명 (로깅용)
    var errorDescription: String? {
        switch self {
        case .imageLoadFailed(let assetID):
            return "Image load failed: \(assetID.prefix(8))..."  // 이미지 로드 실패
        case .metalInitFailed:
            return "Metal initialization failed"  // Metal 초기화 실패
        case .visionFailed(let message):
            return "Vision API failed: \(message)"  // Vision API 실패
        case .aestheticsFailed:
            return "AestheticsScore analysis failed"  // AestheticsScore 분석 실패
        case .timeout:
            return "Analysis timed out (over 5 seconds)"  // 분석 타임아웃
        case .iCloudOnly(let assetID):
            return "iCloud-only image: \(assetID.prefix(8))..."  // iCloud 전용 이미지
        case .videoFrameExtractionFailed(let assetID):
            return "Video frame extraction failed: \(assetID.prefix(8))..."  // 비디오 프레임 추출 실패
        }
    }
}

// MARK: - 에러 처리 정책

extension AnalysisError {

    /// 에러 처리 정책
    enum Policy {
        /// 해당 사진 건너뜀
        case skip
        /// 전체 정리 중단
        case abort
        /// 다른 방법으로 재시도
        case fallback
    }

    /// 해당 에러의 처리 정책
    var policy: Policy {
        switch self {
        case .imageLoadFailed, .visionFailed, .timeout, .iCloudOnly, .videoFrameExtractionFailed:
            return .skip    // 개별 사진 SKIP
        case .metalInitFailed:
            return .abort   // 전체 정리 중단
        case .aestheticsFailed:
            return .fallback // Metal 파이프라인으로 재시도
        }
    }

    /// 해당 에러가 발생한 사진의 SkipReason
    var skipReason: SkipReason? {
        switch self {
        case .imageLoadFailed, .visionFailed, .timeout, .videoFrameExtractionFailed:
            return .analysisError
        case .iCloudOnly:
            return .iCloudOnly
        case .metalInitFailed, .aestheticsFailed:
            return nil  // SKIP 아닌 에러
        }
    }
}

// MARK: - 로깅 지원

extension AnalysisError {

    /// 로깅용 간단 문자열
    var logMessage: String {
        switch self {
        case .imageLoadFailed(let assetID):
            return "[SKIP] Image load failed: \(assetID.prefix(8))"
        case .metalInitFailed:
            return "[ABORT] Metal init failed"
        case .visionFailed(let message):
            return "[SKIP] Vision failed: \(message)"
        case .aestheticsFailed:
            return "[FALLBACK] Aesthetics failed, using Metal pipeline"
        case .timeout:
            return "[SKIP] Analysis timeout"
        case .iCloudOnly(let assetID):
            return "[SKIP] iCloud only: \(assetID.prefix(8))"
        case .videoFrameExtractionFailed(let assetID):
            return "[SKIP] Video frame extraction failed: \(assetID.prefix(8))"
        }
    }
}

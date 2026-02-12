//
//  SafeGuardChecker.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  Stage 4: Safe Guard 체크
//  - 블러 판정 시 심도 효과 확인 (depthData 존재)
//  - 얼굴 품질 체크 (VNDetectFaceCaptureQualityRequest)
//  - 의도적 배경 흐림 또는 선명한 얼굴이 있으면 블러 판정 무효화
//

import Foundation
import Photos
import Vision

/// Safe Guard 체크 결과
struct SafeGuardResult: Equatable {

    /// Safe Guard 적용 여부
    let isApplied: Bool

    /// 적용 사유 (isApplied == true인 경우)
    let reason: SafeGuardReason?

    /// Safe Guard가 적용되지 않은 결과
    static let notApplied = SafeGuardResult(isApplied: false, reason: nil)

    /// Safe Guard가 적용된 결과
    static func applied(_ reason: SafeGuardReason) -> SafeGuardResult {
        return SafeGuardResult(isApplied: true, reason: reason)
    }
}

/// Safe Guard 체커
///
/// 블러 신호가 감지된 경우, 의도적 배경 흐림 또는 선명한 얼굴이 있는지 확인합니다.
/// Safe Guard가 적용되면 블러 판정이 무효화되어 acceptable로 처리됩니다.
final class SafeGuardChecker {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SafeGuardChecker()

    // MARK: - Properties

    /// 얼굴 품질 임계값
    private let faceQualityThreshold: Float

    // MARK: - Initialization

    /// 체커 초기화
    /// - Parameter faceQualityThreshold: 얼굴 품질 임계값 (기본값: 0.4)
    init(faceQualityThreshold: Float = CleanupConstants.faceQualityThreshold) {
        self.faceQualityThreshold = faceQualityThreshold
    }

    // MARK: - Public Methods

    /// Safe Guard 체크 (PHAsset 메타데이터)
    ///
    /// - Parameter asset: 체크할 PHAsset
    /// - Returns: Safe Guard 체크 결과 (메타데이터 기반)
    ///
    /// - Note: 심도 효과 여부만 확인 (빠른 체크)
    func checkMetadata(_ asset: PHAsset) -> SafeGuardResult {
        // 심도 효과 체크 (Portrait 모드)
        // mediaSubtypes로 포트레이트 모드 판별 (Apple 공식 API)
        //
        // Note: PHAssetResource.assetResources() 호출 제거됨
        // - 메인 스레드에서 메타데이터를 동기 로딩하여 "Missing prefetched properties" 경고 발생
        // - mediaSubtypes.contains(.photoDepthEffect)로 포트레이트 모드 판별에 충분
        if asset.mediaSubtypes.contains(.photoDepthEffect) {
            return .applied(.depthEffect)
        }

        return .notApplied
    }

    /// Safe Guard 체크 (이미지 기반 - 얼굴 품질)
    ///
    /// - Parameter image: 체크할 CGImage
    /// - Returns: Safe Guard 체크 결과 (얼굴 품질 기반)
    /// - Throws: Vision API 실패 시 에러
    ///
    /// - Note: 얼굴 품질 >= 0.4 이면 Safe Guard 적용
    func checkFaceQuality(_ image: CGImage) async throws -> SafeGuardResult {
        // VNDetectFaceCaptureQualityRequest 생성
        let request = VNDetectFaceCaptureQualityRequest()

        // 이미지 핸들러 생성
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        // 요청 수행
        do {
            try handler.perform([request])
        } catch {
            throw AnalysisError.visionFailed(error.localizedDescription)
        }

        // 결과 확인
        guard let observations = request.results, !observations.isEmpty else {
            // 얼굴이 감지되지 않음
            return .notApplied
        }

        // 가장 높은 얼굴 품질 확인
        let maxQuality = observations.compactMap { $0.faceCaptureQuality }.max() ?? 0

        if maxQuality >= faceQualityThreshold {
            return .applied(.clearFace)
        }

        return .notApplied
    }

    /// Safe Guard 종합 체크 (메타데이터 + 이미지)
    ///
    /// - Parameters:
    ///   - asset: 체크할 PHAsset
    ///   - image: 체크할 CGImage
    /// - Returns: Safe Guard 체크 결과
    ///
    /// - Note: 메타데이터 체크 후 이미지 체크 수행 (순차적)
    func check(asset: PHAsset, image: CGImage) async throws -> SafeGuardResult {
        // 1. 메타데이터 체크 (빠른 체크 먼저)
        let metadataResult = checkMetadata(asset)
        if metadataResult.isApplied {
            return metadataResult
        }

        // 2. 이미지 기반 체크 (얼굴 품질)
        return try await checkFaceQuality(image)
    }

    /// 블러 신호에 Safe Guard 적용 필요 여부 확인
    ///
    /// - Parameter signals: 감지된 품질 신호 배열
    /// - Returns: Safe Guard 체크 필요 여부
    ///
    /// - Note: severeBlur 또는 generalBlur 신호가 있을 때만 체크 필요
    func needsSafeGuardCheck(for signals: [QualitySignal]) -> Bool {
        return signals.contains { signal in
            signal.kind == .severeBlur || signal.kind == .generalBlur
        }
    }
}


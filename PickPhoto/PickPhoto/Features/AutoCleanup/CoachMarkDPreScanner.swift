//
//  CoachMarkDPreScanner.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-23.
//
//  코치마크 D: 저품질 자동 정리 안내를 위한 사전 스캔
//  - 앱 시작 직후 백그라운드에서 최근 사진부터 순차 스캔
//  - T2 파이프라인: MetadataFilter → Exposure → SKIP필터 → Blur (SafeGuard 제외)
//  - 저품질 사진 3장 확보 시 또는 전체 소진 시 완료
//  - 결과: D 코치마크에서 썸네일 표시용
//

import Photos
import UIKit
import Vision
import AppCore

// MARK: - CoachMarkDPreScanner

/// 코치마크 D용 경량 사전 스캔
/// 최근 사진부터 순차적으로 분석하여 저품질 사진 최대 3장을 확보
final class CoachMarkDPreScanner {

    static let shared = CoachMarkDPreScanner()

    // MARK: - Result

    /// 스캔 결과
    struct Result {
        /// 저품질 판정된 asset (최대 3개)
        let lowQualityAssets: [PHAsset]
        /// 스캔한 총 사진 수
        let totalScanned: Int
    }

    // MARK: - Properties

    /// 스캔 결과 (nil이면 미완료)
    private(set) var result: Result?

    /// 스캔 진행 중 여부
    private(set) var isScanning: Bool = false

    /// 스캔 완료 여부
    var isComplete: Bool { result != nil }

    /// 스캔 완료 콜백 (메인 스레드에서 호출)
    var onComplete: (() -> Void)?

    // MARK: - Constants

    /// 확보 목표 수
    private static let targetCount = 3

    // MARK: - Dependencies

    private let metadataFilter = MetadataFilter()
    private let imageLoader = CleanupImageLoader.shared
    private let exposureAnalyzer = ExposureAnalyzer.shared
    private let blurAnalyzer = BlurAnalyzer.shared

    // MARK: - Init

    private init() {}

    // MARK: - Scan

    /// 스캔 시작 (1회만 실행, 중복 호출 무시)
    func startIfNeeded() {
        // 이미 완료 또는 진행 중이면 무시
        guard !isComplete, !isScanning else { return }
        isScanning = true

        Log.print("[CoachMarkD] PreScanner 시작")

        Task.detached(priority: .utility) { [weak self] in
            await self?.performScan()
        }
    }

    /// 실제 스캔 로직 (백그라운드 스레드)
    private func performScan() async {
        // 최근 사진부터 역순으로 fetch (fetchLimit 없음 — 3장 확보까지 계속)
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        let fetchResult = PHAsset.fetchAssets(with: options)

        var lowQualityAssets: [PHAsset] = []
        var totalScanned = 0

        Log.print("[CoachMarkD] 전체 사진 \(fetchResult.count)장, 스캔 시작")

        // 순차 처리 (PHImageManager가 병목이므로 병렬 효과 없음)
        for i in 0..<fetchResult.count {
            // 3장 확보 시 종료
            guard lowQualityAssets.count < Self.targetCount else { break }

            let asset = fetchResult.object(at: i)

            // Stage 1: 메타데이터 필터 (비디오/스크린샷/즐겨찾기 등 스킵)
            if metadataFilter.shouldAnalyze(asset) != nil {
                continue
            }

            totalScanned += 1

            // Stage 2: 이미지 로딩 + 노출 분석 + SKIP + 블러 분석
            let isLowQuality = await analyzeAsset(asset)
            if isLowQuality {
                lowQualityAssets.append(asset)
                Log.print("[CoachMarkD] 저품질 발견 #\(lowQualityAssets.count) (스캔 \(totalScanned)장째)")
            }
        }

        // 결과 저장 및 콜백 (메인 스레드)
        let scanResult = Result(
            lowQualityAssets: lowQualityAssets,
            totalScanned: totalScanned
        )

        await MainActor.run { [weak self] in
            guard let self else { return }
            self.result = scanResult
            self.isScanning = false
            Log.print("[CoachMarkD] PreScanner 완료: \(lowQualityAssets.count)장 발견 / \(totalScanned)장 스캔")
            self.onComplete?()
            self.onComplete = nil
        }
    }

    // MARK: - Asset Analysis (T2 Pipeline)

    /// 단일 asset 분석 (Strong 신호 판정)
    /// - Returns: 저품질이면 true
    private func analyzeAsset(_ asset: PHAsset) async -> Bool {
        // 이미지 로딩 (짧은변 360px, highQualityFormat)
        guard let image = try? await imageLoader.loadImage(for: asset) else {
            return false
        }

        // Stage 2: 노출 분석
        guard let exposureMetrics = try? exposureAnalyzer.analyze(image) else {
            return false
        }

        // SKIP 필터: 유틸리티 이미지 (극단 휘도 + 낮은 RGB Std)
        if isUtilityImage(exposureMetrics) { return false }

        // SKIP 필터: 텍스트 스크린샷 (극단 노출인 경우만 Vision 체크)
        if hasExtremeExposure(exposureMetrics) {
            let isText = await detectTextScreenshot(image)
            if isText { return false }
        }

        // SKIP 필터: 흰 배경 이미지 (극단 밝음 + 모서리 순백)
        if isWhiteBackgroundImage(exposureMetrics) { return false }

        // 노출 Strong 신호 체크 (극단 어두움/밝음)
        let hasExposureStrong = exposureMetrics.luminance < CleanupConstants.extremeDarkLuminance ||
                                 exposureMetrics.luminance > CleanupConstants.extremeBrightLuminance

        // Stage 3: 블러 분석 (Metal GPU 256x256)
        let hasBlurStrong: Bool
        if let blurMetrics = try? blurAnalyzer.analyze(image) {
            hasBlurStrong = blurMetrics.laplacianVariance < CleanupConstants.severeBlurLaplacian
        } else {
            hasBlurStrong = false
        }

        // Strong 신호가 하나라도 있으면 저품질
        return hasExposureStrong || hasBlurStrong
    }

    // MARK: - SKIP Filter Helpers (QualityAnalyzer 로직 동일)

    /// 유틸리티 이미지 판정 (메모, 문서 등 단색 배경)
    /// 휘도가 극단적 + RGB 표준편차 낮음 → 단색 배경 이미지
    private func isUtilityImage(_ metrics: ExposureMetrics) -> Bool {
        let isExtremeLuminance = metrics.luminance < CleanupConstants.extremeDarkLuminance ||
                                  metrics.luminance > CleanupConstants.extremeBrightLuminance
        let isLowColorVariety = metrics.rgbStd < CleanupConstants.utilityImageRgbStd
        return isExtremeLuminance && isLowColorVariety
    }

    /// 극단 노출 여부 (텍스트 스크린샷 체크 조건)
    private func hasExtremeExposure(_ metrics: ExposureMetrics) -> Bool {
        return metrics.luminance < CleanupConstants.extremeDarkLuminance ||
               metrics.luminance > CleanupConstants.extremeBrightLuminance
    }

    /// 흰 배경 이미지 판정 (일러스트, 문서, 상품 사진)
    /// 극단 밝음 + 모서리 순백 + 모서리가 중앙보다 밝음
    private func isWhiteBackgroundImage(_ metrics: ExposureMetrics) -> Bool {
        let isExtremeBright = metrics.luminance > CleanupConstants.extremeBrightLuminance
        let isCornerNearWhite = metrics.cornerLuminance > CleanupConstants.whiteBackgroundCornerLuminance
        let isCornerBrighterThanCenter = metrics.cornerLuminance > metrics.centerLuminance
        return isExtremeBright && isCornerNearWhite && isCornerBrighterThanCenter
    }

    /// 텍스트 스크린샷 감지 (Vision 프레임워크)
    /// 블로그 캡쳐, 문서 스크린샷 등 텍스트가 많은 이미지 필터링
    private func detectTextScreenshot(_ image: CGImage) async -> Bool {
        return await withCheckedContinuation { continuation in
            var hasResumed = false

            let request = VNRecognizeTextRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: false)
                    return
                }

                // 텍스트 영역이 3개 이상이면 텍스트 스크린샷으로 판정
                let isTextHeavy = observations.count >= 3
                continuation.resume(returning: isTextHeavy)
            }

            if CleanupConstants.textRecognitionUseFastMode {
                request.recognitionLevel = .fast
            }
            request.usesLanguageCorrection = false

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: false)
                }
            }
        }
    }
}

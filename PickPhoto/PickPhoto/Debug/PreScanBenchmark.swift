//
//  PreScanBenchmark.swift
//  PickPhoto
//
//  코치마크 D 사전 스캔 벤치마크 — 이미지 로딩 방식 비교 (DEBUG 전용)
//
//  PHImageRequestOptions.deliveryMode 별 속도 및 분석 결과 비교:
//  - Q1: .highQualityFormat (현재 방식)
//  - Q2: .fastFormat (빠른 로딩)
//
//  파이프라인: T2 (MetadataFilter → Exposure → SKIP필터 → Blur, SafeGuard 제외)
//  측정: 총 시간, 저품질 수, 판정 일치 여부
//  테스트 간 1초 딜레이 (캐시 안정화)
//

#if DEBUG
import UIKit
import Photos
import Vision
import AppCore
import OSLog

// MARK: - 결과 모델

/// 로딩 방식 벤치마크 결과
struct DeliveryBenchmarkResult {
    let label: String
    let totalCount: Int
    let analyzedCount: Int
    let lowQualityCount: Int
    let skippedCount: Int
    let loadFailedCount: Int
    let totalTimeSeconds: Double
    let avgTimeMs: Double
    /// 저품질 상세 정보
    let lowQualityDetails: [(assetID: String, signals: String)]
}

// MARK: - 벤치마크 본체

/// 코치마크 D 사전 스캔 — 이미지 로딩 방식 벤치마크
///
/// highQualityFormat vs fastFormat 로딩 속도 및 분석 결과 차이를 비교합니다.
final class PreScanBenchmark {

    // MARK: - Properties

    /// 벤치마크 실행 중 여부
    private(set) static var isRunning = false

    /// 테스트할 사진 수
    private static let sampleCount = 1000

    /// 테스트 간 딜레이 (초)
    private static let interTestDelay: TimeInterval = 1.0

    // MARK: - Public

    /// 벤치마크 실행
    static func run(from viewController: UIViewController? = nil) {
        guard !isRunning else {
            Logger.cleanup.debug("이미 실행 중")
            return
        }
        isRunning = true

        Logger.cleanup.debug("========================================")
        Logger.cleanup.debug("로딩 방식 벤치마크 시작 (\(sampleCount)장)")
        Logger.cleanup.debug("Q1: highQualityFormat / Q2: fastFormat")
        Logger.cleanup.debug("파이프라인: T2 (SKIP필터 포함, SafeGuard 제외)")
        Logger.cleanup.debug("========================================")

        Task {
            // 1. 사진 fetch (공통)
            let assets = fetchRecentPhotos(count: sampleCount)
            Logger.cleanup.debug("사진 fetch 완료: \(assets.count)장")

            guard !assets.isEmpty else {
                Logger.cleanup.debug("사진이 없어서 종료")
                isRunning = false
                return
            }

            // 2. Q1 — highQualityFormat (현재 방식)
            Logger.cleanup.debug("")
            Logger.cleanup.debug("--- Q1: highQualityFormat (현재) ---")
            let q1 = await runWithDeliveryMode(assets: assets, mode: .highQualityFormat, label: "Q1: highQuality")
            printResult(q1)

            // 딜레이
            try? await Task.sleep(nanoseconds: UInt64(interTestDelay * 1_000_000_000))

            // 3. Q2 — fastFormat
            Logger.cleanup.debug("")
            Logger.cleanup.debug("--- Q2: fastFormat ---")
            let q2 = await runWithDeliveryMode(assets: assets, mode: .fastFormat, label: "Q2: fastFormat")
            printResult(q2)

            // 4. 비교 요약
            printComparison(q1: q1, q2: q2)

            isRunning = false
            Logger.cleanup.debug("========================================")
            Logger.cleanup.debug("벤치마크 완료")
            Logger.cleanup.debug("========================================")
        }
    }

    // MARK: - Fetch

    /// 최근 사진 fetch (이미지만, 시간 역순)
    private static func fetchRecentPhotos(count: Int) -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.fetchLimit = count
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)

        let fetchResult = PHAsset.fetchAssets(with: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(fetchResult.count)
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    // MARK: - 로딩 방식별 실행

    /// 지정된 deliveryMode로 T2 파이프라인 순차 실행
    private static func runWithDeliveryMode(
        assets: [PHAsset],
        mode: PHImageRequestOptionsDeliveryMode,
        label: String
    ) async -> DeliveryBenchmarkResult {
        let metadataFilter = MetadataFilter()
        let exposureAnalyzer = ExposureAnalyzer.shared
        let blurAnalyzer = BlurAnalyzer.shared

        // 로딩 방식별 전용 이미지 로더 생성
        let imageLoader = makeImageLoader(deliveryMode: mode)

        let startTime = CFAbsoluteTimeGetCurrent()
        var results: [LightResult] = []

        for (i, asset) in assets.enumerated() {
            let assetID = asset.localIdentifier

            // Stage 1: MetadataFilter
            if metadataFilter.shouldAnalyze(asset) != nil {
                results.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, loadFailed: false, signals: []))
                continue
            }

            // 이미지 로딩 (deliveryMode별 차이)
            guard let image = try? await imageLoader.loadImage(for: asset) else {
                results.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: false, loadFailed: true, signals: []))
                continue
            }

            // Stage 2: Exposure
            guard let exposureMetrics = try? exposureAnalyzer.analyze(image) else {
                results.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, loadFailed: false, signals: []))
                continue
            }

            // SKIP필터: 유틸리티 이미지
            if isUtilityImage(exposureMetrics) {
                results.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, loadFailed: false, signals: []))
                continue
            }

            // SKIP필터: 텍스트 스크린샷
            if hasExtremeExposure(exposureMetrics) {
                let isText = await detectTextScreenshot(image)
                if isText {
                    results.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, loadFailed: false, signals: []))
                    continue
                }
            }

            // SKIP필터: 흰 배경 이미지
            if isWhiteBackgroundImage(exposureMetrics) {
                results.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, loadFailed: false, signals: []))
                continue
            }

            var signals = exposureAnalyzer.detectSignals(from: exposureMetrics, mode: .precision)

            // Stage 3: Blur
            do {
                let blurMetrics: BlurMetrics
                if blurAnalyzer.isAvailable {
                    blurMetrics = try blurAnalyzer.analyze(image)
                } else {
                    blurMetrics = try blurAnalyzer.analyzeCPU(image)
                }
                signals.append(contentsOf: blurAnalyzer.detectSignals(from: blurMetrics, mode: .precision))
            } catch {
                // 블러 분석 실패
            }

            let isLow = signals.hasStrongSignal
            results.append(LightResult(assetID: assetID, isLowQuality: isLow, isSkipped: false, loadFailed: false, signals: signals))

            if (i + 1) % 100 == 0 {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                Logger.cleanup.debug("  진행: \(i + 1)/\(assets.count) (\(String(format: "%.1f", elapsed))초)")
            }
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        return buildResult(results, label: label, totalTime: totalTime)
    }

    // MARK: - 이미지 로더 생성

    /// deliveryMode를 지정하여 벤치마크용 이미지 로더 생성
    private static func makeImageLoader(deliveryMode: PHImageRequestOptionsDeliveryMode) -> DeliveryModeImageLoader {
        return DeliveryModeImageLoader(deliveryMode: deliveryMode)
    }

    // MARK: - 결과 빌드

    /// LightResult 배열 → DeliveryBenchmarkResult
    private static func buildResult(
        _ results: [LightResult],
        label: String,
        totalTime: Double
    ) -> DeliveryBenchmarkResult {
        let lowQuality = results.filter { $0.isLowQuality }
        let skipped = results.filter { $0.isSkipped }
        let loadFailed = results.filter { $0.loadFailed }
        let analyzed = results.filter { !$0.isSkipped && !$0.loadFailed }
        let avgTime = analyzed.isEmpty ? 0 : (totalTime * 1000) / Double(results.count)

        let details = lowQuality.map { r in
            let signalStr = r.signals.map { $0.kind.rawValue }.joined(separator: ", ")
            return (assetID: r.assetID, signals: signalStr)
        }

        return DeliveryBenchmarkResult(
            label: label,
            totalCount: results.count,
            analyzedCount: analyzed.count,
            lowQualityCount: lowQuality.count,
            skippedCount: skipped.count,
            loadFailedCount: loadFailed.count,
            totalTimeSeconds: totalTime,
            avgTimeMs: avgTime,
            lowQualityDetails: details
        )
    }

    // MARK: - 경량 결과 모델

    /// 개별 분석 결과
    private struct LightResult {
        let assetID: String
        let isLowQuality: Bool
        let isSkipped: Bool
        let loadFailed: Bool
        let signals: [QualitySignal]
    }

    // MARK: - SKIP필터 로직 (QualityAnalyzer에서 복제)

    /// 유틸리티 이미지 여부 (극단 휘도 + 낮은 RGB표준편차)
    private static func isUtilityImage(_ metrics: ExposureMetrics) -> Bool {
        let isExtremeLuminance = metrics.luminance < CleanupConstants.extremeDarkLuminance ||
                                  metrics.luminance > CleanupConstants.extremeBrightLuminance
        let isLowColorVariety = metrics.rgbStd < CleanupConstants.utilityImageRgbStd
        return isExtremeLuminance && isLowColorVariety
    }

    /// 극단 노출 여부
    private static func hasExtremeExposure(_ metrics: ExposureMetrics) -> Bool {
        return metrics.luminance < CleanupConstants.extremeDarkLuminance ||
               metrics.luminance > CleanupConstants.extremeBrightLuminance
    }

    /// 흰 배경 이미지 여부
    private static func isWhiteBackgroundImage(_ metrics: ExposureMetrics) -> Bool {
        let isExtremeBright = metrics.luminance > CleanupConstants.extremeBrightLuminance
        let isCornerNearWhite = metrics.cornerLuminance > CleanupConstants.whiteBackgroundCornerLuminance
        let isCornerBrighterThanCenter = metrics.cornerLuminance > metrics.centerLuminance
        return isExtremeBright && isCornerNearWhite && isCornerBrighterThanCenter
    }

    /// 텍스트 스크린샷 감지
    private static func detectTextScreenshot(_ image: CGImage) async -> Bool {
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
                let isText = observations.count >= CleanupConstants.textBlockCountThreshold
                continuation.resume(returning: isText)
            }
            request.recognitionLevel = CleanupConstants.textRecognitionUseFastMode ? .fast : .accurate
            request.recognitionLanguages = ["ko-KR", "en-US"]

            let handler = VNImageRequestHandler(cgImage: image, options: [:])
            do {
                try handler.perform([request])
            } catch {
                guard !hasResumed else { return }
                hasResumed = true
                continuation.resume(returning: false)
            }
        }
    }

    // MARK: - 출력

    /// 개별 테스트 결과 출력
    private static func printResult(_ result: DeliveryBenchmarkResult) {
        Logger.cleanup.debug("[\(result.label)]")
        Logger.cleanup.debug("  총 시간: \(String(format: "%.2f", result.totalTimeSeconds))초")
        Logger.cleanup.debug("  평균/장: \(String(format: "%.1f", result.avgTimeMs))ms")
        Logger.cleanup.debug("  분석 \(result.analyzedCount)장, 스킵 \(result.skippedCount)장, 로딩실패 \(result.loadFailedCount)장")
        Logger.cleanup.debug("  저품질: \(result.lowQualityCount)장")

        // 저품질 상세 (최대 10개)
        if !result.lowQualityDetails.isEmpty {
            let showCount = min(10, result.lowQualityDetails.count)
            Logger.cleanup.debug("  저품질 상세 (상위 \(showCount)개):")
            for detail in result.lowQualityDetails.prefix(showCount) {
                let shortID = String(detail.assetID.prefix(12))
                Logger.cleanup.debug("    \(shortID)... → [\(detail.signals)]")
            }
        }
    }

    /// 2종 비교 요약
    private static func printComparison(
        q1: DeliveryBenchmarkResult,
        q2: DeliveryBenchmarkResult
    ) {
        Logger.cleanup.debug("")
        Logger.cleanup.debug("============ 로딩 방식 비교 요약 ============")

        // 속도 비교
        Logger.cleanup.debug("총 시간:")
        Logger.cleanup.debug("  Q1 (highQuality): \(String(format: "%.2f", q1.totalTimeSeconds))초 (avg \(String(format: "%.1f", q1.avgTimeMs))ms)")
        Logger.cleanup.debug("  Q2 (fastFormat):  \(String(format: "%.2f", q2.totalTimeSeconds))초 (avg \(String(format: "%.1f", q2.avgTimeMs))ms)")

        if q1.totalTimeSeconds > 0 {
            let speedup = q1.totalTimeSeconds / q2.totalTimeSeconds
            let saved = q1.totalTimeSeconds - q2.totalTimeSeconds
            Logger.cleanup.debug("  속도향상: \(String(format: "%.2f", speedup))x (\(String(format: "%.1f", saved))초 절약)")
        }

        // 로딩 실패 비교
        Logger.cleanup.debug("")
        Logger.cleanup.debug("로딩 실패: Q1=\(q1.loadFailedCount)장, Q2=\(q2.loadFailedCount)장")

        // 저품질 판정 비교
        Logger.cleanup.debug("")
        Logger.cleanup.debug("저품질: Q1=\(q1.lowQualityCount)장, Q2=\(q2.lowQualityCount)장")

        // 판정 일치 여부 (핵심)
        let q1IDs = Set(q1.lowQualityDetails.map { $0.assetID })
        let q2IDs = Set(q2.lowQualityDetails.map { $0.assetID })

        if q1IDs == q2IDs {
            Logger.cleanup.debug("판정 일치: 동일한 사진 판정")
        } else {
            let onlyQ1 = q1IDs.subtracting(q2IDs)
            let onlyQ2 = q2IDs.subtracting(q1IDs)
            let common = q1IDs.intersection(q2IDs)
            Logger.cleanup.debug("판정 차이:")
            Logger.cleanup.debug("  공통: \(common.count)장")
            Logger.cleanup.debug("  Q1에만: \(onlyQ1.count)장")
            Logger.cleanup.debug("  Q2에만: \(onlyQ2.count)장")

            // Q1에만 있는 상세
            if !onlyQ1.isEmpty {
                Logger.cleanup.debug("  Q1에만 저품질 (highQuality에서만 감지):")
                for id in onlyQ1.prefix(5) {
                    let shortID = String(id.prefix(12))
                    if let detail = q1.lowQualityDetails.first(where: { $0.assetID == id }) {
                        Logger.cleanup.debug("    \(shortID)... → [\(detail.signals)]")
                    }
                }
            }

            // Q2에만 있는 상세
            if !onlyQ2.isEmpty {
                Logger.cleanup.debug("  Q2에만 저품질 (fastFormat에서만 감지):")
                for id in onlyQ2.prefix(5) {
                    let shortID = String(id.prefix(12))
                    if let detail = q2.lowQualityDetails.first(where: { $0.assetID == id }) {
                        Logger.cleanup.debug("    \(shortID)... → [\(detail.signals)]")
                    }
                }
            }
        }

        Logger.cleanup.debug("==========================================")
    }
}

// MARK: - DeliveryMode 전용 이미지 로더

/// deliveryMode를 지정 가능한 벤치마크용 이미지 로더
///
/// CleanupImageLoader가 final class이므로 서브클래싱 불가.
/// 동일한 로딩 로직을 독립 구현하여 deliveryMode만 변경 가능하게 합니다.
final class DeliveryModeImageLoader {

    /// 이미지 매니저
    private let imageManager = PHCachingImageManager()

    /// 요청 옵션
    private let requestOptions: PHImageRequestOptions

    /// 분석용 이미지 최소 크기 (짧은 변 기준)
    private let minSize: CGFloat = 360

    /// 지정된 deliveryMode로 초기화
    init(deliveryMode: PHImageRequestOptionsDeliveryMode) {
        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        options.isSynchronous = false
        self.requestOptions = options
    }

    /// 분석용 이미지 로딩
    func loadImage(for asset: PHAsset) async throws -> CGImage {
        let targetSize = calculateTargetSize(for: asset)

        return try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false

            imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFit,
                options: requestOptions
            ) { image, info in
                // degraded (저품질 선행 전달) 무시
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }

                guard !hasResumed else { return }
                hasResumed = true

                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    continuation.resume(throwing: CleanupImageLoadError.timeout)
                    return
                }

                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: CleanupImageLoadError.loadFailed(error.localizedDescription))
                    return
                }

                guard let uiImage = image, let cgImage = uiImage.cgImage else {
                    continuation.resume(throwing: CleanupImageLoadError.loadFailed("이미지 nil"))
                    return
                }

                continuation.resume(returning: cgImage)
            }
        }
    }

    /// 타겟 크기 계산 (짧은 변 기준)
    private func calculateTargetSize(for asset: PHAsset) -> CGSize {
        let pixelWidth = CGFloat(asset.pixelWidth)
        let pixelHeight = CGFloat(asset.pixelHeight)
        let shorterSide = min(pixelWidth, pixelHeight)

        if shorterSide <= minSize {
            return CGSize(width: pixelWidth, height: pixelHeight)
        }

        let scale = minSize / shorterSide
        return CGSize(width: pixelWidth * scale, height: pixelHeight * scale)
    }
}
#endif

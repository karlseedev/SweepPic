//
//  PreScanBenchmark.swift
//  PickPhoto
//
//  코치마크 D 사전 스캔 벤치마크 — 병렬 처리 테스트 (DEBUG 전용)
//
//  동시 처리 수별 속도 비교:
//  - P1: 2개 동시
//  - P2: 4개 동시
//  - P3: 8개 동시
//
//  파이프라인: T2 (MetadataFilter → Exposure → SKIP필터 → Blur, SafeGuard 제외)
//  측정: 총 시간, 3장 확보 시점, 저품질 수
//  각 테스트 간 1초 딜레이 (GPU/캐시 안정화)
//

#if DEBUG
import UIKit
import Photos
import Vision
import AppCore

// MARK: - 결과 모델

/// 병렬 벤치마크 결과
struct ParallelBenchmarkResult {
    let label: String
    let concurrency: Int
    let totalCount: Int
    let analyzedCount: Int
    let lowQualityCount: Int
    let skippedCount: Int
    let totalTimeSeconds: Double
    let avgTimeMs: Double
    /// 저품질 상세 정보
    let lowQualityDetails: [(assetID: String, signals: String)]
}

// MARK: - 벤치마크 본체

/// 코치마크 D 사전 스캔 — 병렬 처리 벤치마크
///
/// T2 파이프라인(SKIP필터 포함, SafeGuard 제외)을 동시 처리 수 2/4/8로 실행하여
/// 3장 확보까지의 시간을 비교합니다.
final class PreScanBenchmark {

    // MARK: - Properties

    /// 벤치마크 실행 중 여부
    private(set) static var isRunning = false

    /// 테스트할 사진 수
    private static let sampleCount = 1000

    /// 테스트 간 딜레이 (초) — GPU/캐시 안정화용
    private static let interTestDelay: TimeInterval = 1.0

    // MARK: - Public

    /// 벤치마크 실행
    static func run(from viewController: UIViewController? = nil) {
        guard !isRunning else {
            Log.print("[PreScanBM] 이미 실행 중")
            return
        }
        isRunning = true

        Log.print("[PreScanBM] ========================================")
        Log.print("[PreScanBM] 병렬 처리 벤치마크 시작 (\(sampleCount)장, 동시 1/2/4/8)")
        Log.print("[PreScanBM] 파이프라인: T2 (SKIP필터 포함, SafeGuard 제외)")
        Log.print("[PreScanBM] ========================================")

        Task {
            // 1. 사진 fetch (공통)
            let assets = fetchRecentPhotos(count: sampleCount)
            Log.print("[PreScanBM] 사진 fetch 완료: \(assets.count)장")

            guard !assets.isEmpty else {
                Log.print("[PreScanBM] 사진이 없어서 종료")
                isRunning = false
                return
            }

            // 2. P0 — 순차 (동시 1개, 기준선)
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] --- P0: 순차 (동시 1개) ---")
            let p0 = await runParallel(assets: assets, concurrency: 1, label: "P0: 순차")
            printResult(p0)

            // 딜레이
            try? await Task.sleep(nanoseconds: UInt64(interTestDelay * 1_000_000_000))

            // 3. P1 — 동시 2개
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] --- P1: 동시 2개 ---")
            let p1 = await runParallel(assets: assets, concurrency: 2, label: "P1: 동시2")
            printResult(p1)

            // 딜레이
            try? await Task.sleep(nanoseconds: UInt64(interTestDelay * 1_000_000_000))

            // 4. P2 — 동시 4개
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] --- P2: 동시 4개 ---")
            let p2 = await runParallel(assets: assets, concurrency: 4, label: "P2: 동시4")
            printResult(p2)

            // 딜레이
            try? await Task.sleep(nanoseconds: UInt64(interTestDelay * 1_000_000_000))

            // 5. P3 — 동시 8개
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] --- P3: 동시 8개 ---")
            let p3 = await runParallel(assets: assets, concurrency: 8, label: "P3: 동시8")
            printResult(p3)

            // 6. 비교 요약
            printComparison(p0: p0, p1: p1, p2: p2, p3: p3)

            isRunning = false
            Log.print("[PreScanBM] ========================================")
            Log.print("[PreScanBM] 벤치마크 완료")
            Log.print("[PreScanBM] ========================================")
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

    // MARK: - 병렬 실행

    /// T2 파이프라인을 지정된 동시 수로 병렬 실행
    ///
    /// TaskGroup + 동시 수 제한 패턴:
    /// - 초기에 concurrency 만큼 태스크 투입
    /// - 하나 완료될 때마다 다음 하나 투입
    /// - 3장 확보 시점 타임스탬프 기록 (조기 종료 안 함, 전체 측정)
    private static func runParallel(
        assets: [PHAsset],
        concurrency: Int,
        label: String
    ) async -> ParallelBenchmarkResult {
        let startTime = CFAbsoluteTimeGetCurrent()

        // 스레드 안전 결과 수집용 actor
        let collector = ResultCollector(startTime: startTime)

        await withTaskGroup(of: Void.self) { group in
            var nextIndex = 0

            // 초기 concurrency 만큼 태스크 투입
            for _ in 0..<min(concurrency, assets.count) {
                let asset = assets[nextIndex]
                let index = nextIndex
                nextIndex += 1
                group.addTask {
                    let result = await analyzeOneT2(asset: asset)
                    await collector.add(result, index: index, totalCount: assets.count)
                }
            }

            // 하나 완료 → 다음 하나 투입
            for await _ in group {
                if nextIndex < assets.count {
                    let asset = assets[nextIndex]
                    let index = nextIndex
                    nextIndex += 1
                    group.addTask {
                        let result = await analyzeOneT2(asset: asset)
                        await collector.add(result, index: index, totalCount: assets.count)
                    }
                }
            }
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        return await collector.buildResult(label: label, concurrency: concurrency, totalTime: totalTime)
    }

    // MARK: - 개별 분석 (T2 파이프라인)

    /// 단일 asset 분석 — T2 (SKIP필터 포함, SafeGuard 제외)
    private static func analyzeOneT2(asset: PHAsset) async -> LightResult {
        let metadataFilter = MetadataFilter()
        let exposureAnalyzer = ExposureAnalyzer.shared
        let blurAnalyzer = BlurAnalyzer.shared
        let imageLoader = CleanupImageLoader.shared

        let assetID = asset.localIdentifier

        // Stage 1: MetadataFilter
        if metadataFilter.shouldAnalyze(asset) != nil {
            return LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [])
        }

        // 이미지 로딩
        guard let image = try? await imageLoader.loadImage(for: asset) else {
            return LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [])
        }

        // Stage 2: Exposure
        guard let exposureMetrics = try? exposureAnalyzer.analyze(image) else {
            return LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [])
        }

        // SKIP필터: 유틸리티 이미지
        if isUtilityImage(exposureMetrics) {
            return LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [])
        }

        // SKIP필터: 텍스트 스크린샷
        if hasExtremeExposure(exposureMetrics) {
            let isText = await detectTextScreenshot(image)
            if isText {
                return LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [])
            }
        }

        // SKIP필터: 흰 배경 이미지
        if isWhiteBackgroundImage(exposureMetrics) {
            return LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [])
        }

        var signals = exposureAnalyzer.detectSignals(from: exposureMetrics, mode: .precision)

        // Stage 3: Blur (SafeGuard 없이)
        do {
            let blurMetrics: BlurMetrics
            if blurAnalyzer.isAvailable {
                blurMetrics = try blurAnalyzer.analyze(image)
            } else {
                blurMetrics = try blurAnalyzer.analyzeCPU(image)
            }
            signals.append(contentsOf: blurAnalyzer.detectSignals(from: blurMetrics, mode: .precision))
        } catch {
            // 블러 분석 실패 — 무시
        }

        let isLow = signals.hasStrongSignal
        return LightResult(assetID: assetID, isLowQuality: isLow, isSkipped: false, signals: signals)
    }

    // MARK: - 결과 수집 Actor

    /// 병렬 태스크에서 결과를 스레드 안전하게 수집하는 actor
    private actor ResultCollector {
        let startTime: Double
        var results: [LightResult] = []
        var lowQualityCount = 0
        /// 진행 로그용 카운터
        var processedCount = 0

        init(startTime: Double) {
            self.startTime = startTime
        }

        /// 결과 추가 (저품질 발견 시점 기록 포함)
        func add(_ result: LightResult, index: Int, totalCount: Int) {
            results.append(result)
            processedCount += 1

            if result.isLowQuality {
                lowQualityCount += 1
            }

            // 100장마다 진행 로그
            if processedCount % 100 == 0 {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                Log.print("[PreScanBM]   진행: \(processedCount)/\(totalCount) (\(String(format: "%.1f", elapsed))초)")
            }
        }

        /// 최종 결과 빌드
        func buildResult(label: String, concurrency: Int, totalTime: Double) -> ParallelBenchmarkResult {
            let lowQuality = results.filter { $0.isLowQuality }
            let skipped = results.filter { $0.isSkipped }
            let analyzed = results.filter { !$0.isSkipped }
            let avgTime = analyzed.isEmpty ? 0 : (totalTime * 1000) / Double(analyzed.count)

            let details = lowQuality.map { r in
                let signalStr = r.signals.map { $0.kind.rawValue }.joined(separator: ", ")
                return (assetID: r.assetID, signals: signalStr)
            }

            return ParallelBenchmarkResult(
                label: label,
                concurrency: concurrency,
                totalCount: results.count,
                analyzedCount: analyzed.count,
                lowQualityCount: lowQuality.count,
                skippedCount: skipped.count,
                totalTimeSeconds: totalTime,
                avgTimeMs: avgTime,
                lowQualityDetails: details
            )
        }
    }

    // MARK: - 경량 결과 모델

    /// 개별 분석 결과
    private struct LightResult {
        let assetID: String
        let isLowQuality: Bool
        let isSkipped: Bool
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
    private static func printResult(_ result: ParallelBenchmarkResult) {
        Log.print("[PreScanBM] [\(result.label)] (동시 \(result.concurrency)개)")
        Log.print("[PreScanBM]   총 시간: \(String(format: "%.2f", result.totalTimeSeconds))초")
        Log.print("[PreScanBM]   분석 \(result.analyzedCount)장, 스킵 \(result.skippedCount)장")
        Log.print("[PreScanBM]   저품질: \(result.lowQualityCount)장")
        Log.print("[PreScanBM]   평균/장: \(String(format: "%.1f", result.avgTimeMs))ms (전체 시간 기준)")

        // 저품질 상세 (최대 10개)
        if !result.lowQualityDetails.isEmpty {
            let showCount = min(10, result.lowQualityDetails.count)
            Log.print("[PreScanBM]   저품질 상세 (상위 \(showCount)개):")
            for detail in result.lowQualityDetails.prefix(showCount) {
                let shortID = String(detail.assetID.prefix(12))
                Log.print("[PreScanBM]     \(shortID)... → [\(detail.signals)]")
            }
        }
    }

    /// 4종 병렬 비교 요약
    private static func printComparison(
        p0: ParallelBenchmarkResult,
        p1: ParallelBenchmarkResult,
        p2: ParallelBenchmarkResult,
        p3: ParallelBenchmarkResult
    ) {
        Log.print("[PreScanBM]")
        Log.print("[PreScanBM] ============ 병렬 처리 비교 요약 ============")

        // 총 시간 비교
        Log.print("[PreScanBM] 총 시간:")
        Log.print("[PreScanBM]   P0 (순차):    \(String(format: "%.2f", p0.totalTimeSeconds))초")
        Log.print("[PreScanBM]   P1 (동시 2):  \(String(format: "%.2f", p1.totalTimeSeconds))초")
        Log.print("[PreScanBM]   P2 (동시 4):  \(String(format: "%.2f", p2.totalTimeSeconds))초")
        Log.print("[PreScanBM]   P3 (동시 8):  \(String(format: "%.2f", p3.totalTimeSeconds))초")

        // 속도 향상 비율 (P0 기준)
        if p0.totalTimeSeconds > 0 {
            Log.print("[PreScanBM]   P1 속도향상: \(String(format: "%.1f", p0.totalTimeSeconds / p1.totalTimeSeconds))x")
            Log.print("[PreScanBM]   P2 속도향상: \(String(format: "%.1f", p0.totalTimeSeconds / p2.totalTimeSeconds))x")
            Log.print("[PreScanBM]   P3 속도향상: \(String(format: "%.1f", p0.totalTimeSeconds / p3.totalTimeSeconds))x")
        }

        // 저품질 수 비교
        Log.print("[PreScanBM]")
        Log.print("[PreScanBM] 저품질: P0=\(p0.lowQualityCount)장, P1=\(p1.lowQualityCount)장, P2=\(p2.lowQualityCount)장, P3=\(p3.lowQualityCount)장")

        // 판정 일치 여부
        let p0IDs = Set(p0.lowQualityDetails.map { $0.assetID })
        let p1IDs = Set(p1.lowQualityDetails.map { $0.assetID })
        let p2IDs = Set(p2.lowQualityDetails.map { $0.assetID })
        let p3IDs = Set(p3.lowQualityDetails.map { $0.assetID })
        if p0IDs == p1IDs && p1IDs == p2IDs && p2IDs == p3IDs {
            Log.print("[PreScanBM] 판정 일치: ✅ 4종 모두 동일한 사진 판정")
        } else {
            let diff01 = p0IDs.symmetricDifference(p1IDs).count
            let diff12 = p1IDs.symmetricDifference(p2IDs).count
            let diff23 = p2IDs.symmetricDifference(p3IDs).count
            Log.print("[PreScanBM] 판정 차이: P0↔P1 = \(diff01)장, P1↔P2 = \(diff12)장, P2↔P3 = \(diff23)장")
        }

        Log.print("[PreScanBM] ==========================================")
    }
}
#endif

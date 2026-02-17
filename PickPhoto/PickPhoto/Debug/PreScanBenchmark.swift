//
//  PreScanBenchmark.swift
//  PickPhoto
//
//  코치마크 D 사전 스캔 벤치마크 (DEBUG 전용)
//
//  세 가지 방식을 순차 비교:
//  - T1: QualityAnalyzer 전체 (Exposure + SKIP필터 + Blur + SafeGuard)
//  - T2: Exposure + SKIP필터 + Blur (SafeGuard 없음)
//  - T3: Exposure + Blur만 (SKIP필터도 SafeGuard도 없음)
//
//  비교:
//  - T1 vs T2 = SafeGuard 비용
//  - T2 vs T3 = SKIP필터 비용
//
//  정리 버튼 탭 시 실행, 각 1000장씩 순차 처리, 결과 로그 출력.
//

#if DEBUG
import UIKit
import Photos
import Vision
import AppCore

/// 사전 스캔 벤치마크 결과
struct PreScanBenchmarkResult {
    let label: String
    let totalCount: Int
    let lowQualityCount: Int
    let skippedCount: Int
    let acceptableCount: Int
    let safeGuardedCount: Int
    let totalTimeSeconds: Double
    let avgTimeMs: Double
    /// 저품질 판정된 assetID → 신호 종류 목록
    let lowQualityDetails: [(assetID: String, signals: String)]
}

/// 코치마크 D 사전 스캔 벤치마크
///
/// 3가지 파이프라인을 같은 사진 세트로 순차 실행하여 속도/결과를 비교합니다.
/// - T1: Full (SafeGuard 포함)
/// - T2: SKIP필터 포함, SafeGuard 없음
/// - T3: Exposure + Blur만 (최경량)
final class PreScanBenchmark {

    // MARK: - Properties

    /// 벤치마크 실행 중 여부
    private(set) static var isRunning = false

    /// 테스트할 사진 수
    private static let sampleCount = 1000

    // MARK: - Public

    /// 벤치마크 실행
    /// - Parameter from: 호출한 ViewController (알림 표시용)
    static func run(from viewController: UIViewController? = nil) {
        guard !isRunning else {
            Log.print("[PreScanBM] 이미 실행 중")
            return
        }
        isRunning = true

        Log.print("[PreScanBM] ========================================")
        Log.print("[PreScanBM] 사전 스캔 벤치마크 시작 (\(sampleCount)장, 3종 비교)")
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

            // 2. T1 — QualityAnalyzer 전체 파이프라인 (SafeGuard 포함)
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] --- T1: Full (Exposure + SKIP필터 + Blur + SafeGuard) ---")
            let result1 = await runFullPipeline(assets: assets)
            printResult(result1)

            // 3. T2 — Exposure + SKIP필터 + Blur (SafeGuard 없음)
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] --- T2: SKIP필터 포함, SafeGuard 없음 ---")
            let result2 = await runWithSkipFilters(assets: assets)
            printResult(result2)

            // 4. T3 — Exposure + Blur만 (최경량)
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] --- T3: Exposure + Blur만 (최경량) ---")
            let result3 = await runLightweight(assets: assets)
            printResult(result3)

            // 5. 비교 요약
            printComparison3(t1: result1, t2: result2, t3: result3)

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

    // MARK: - T1: QualityAnalyzer 전체 파이프라인

    /// QualityAnalyzer.analyze() 사용 (MetadataFilter → Exposure → SKIP필터 → Blur → SafeGuard)
    private static func runFullPipeline(assets: [PHAsset]) async -> PreScanBenchmarkResult {
        let analyzer = QualityAnalyzer.shared
        analyzer.setMode(.precision)

        let startTime = CFAbsoluteTimeGetCurrent()
        var results: [QualityResult] = []

        for (i, asset) in assets.enumerated() {
            let result = await analyzer.analyze(asset)
            results.append(result)

            if (i + 1) % 100 == 0 {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                Log.print("[PreScanBM] T1 진행: \(i + 1)/\(assets.count) (\(String(format: "%.1f", elapsed))초)")
            }
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        return buildResultFromQualityResults(results, label: "T1: Full", totalTime: totalTime)
    }

    // MARK: - T2: Exposure + SKIP필터 + Blur (SafeGuard 없음)

    /// MetadataFilter → Exposure → SKIP필터(유틸리티/화이트배경/텍스트) → Blur (SafeGuard 생략)
    private static func runWithSkipFilters(assets: [PHAsset]) async -> PreScanBenchmarkResult {
        let metadataFilter = MetadataFilter()
        let exposureAnalyzer = ExposureAnalyzer.shared
        let blurAnalyzer = BlurAnalyzer.shared
        let imageLoader = CleanupImageLoader.shared

        let startTime = CFAbsoluteTimeGetCurrent()
        var lightResults: [LightResult] = []

        for (i, asset) in assets.enumerated() {
            let itemStart = CFAbsoluteTimeGetCurrent()
            let assetID = asset.localIdentifier

            // Stage 1: MetadataFilter
            if metadataFilter.shouldAnalyze(asset) != nil {
                lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                continue
            }

            // 이미지 로딩
            guard let image = try? await imageLoader.loadImage(for: asset) else {
                lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                continue
            }

            // Stage 2: Exposure
            guard let exposureMetrics = try? exposureAnalyzer.analyze(image) else {
                lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                continue
            }

            // SKIP필터: 유틸리티 이미지 (극단 휘도 + 낮은 RGB표준편차)
            if isUtilityImage(exposureMetrics) {
                lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                continue
            }

            // SKIP필터: 텍스트 스크린샷 (극단 노출일 때만 체크)
            if hasExtremeExposure(exposureMetrics) {
                let isText = await detectTextScreenshot(image)
                if isText {
                    lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                    continue
                }
            }

            // SKIP필터: 흰 배경 이미지
            if isWhiteBackgroundImage(exposureMetrics) {
                lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                continue
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
                // 블러 분석 실패
            }

            let isLow = signals.hasStrongSignal
            let itemTime = (CFAbsoluteTimeGetCurrent() - itemStart) * 1000
            lightResults.append(LightResult(assetID: assetID, isLowQuality: isLow, isSkipped: false, signals: signals, timeMs: itemTime))

            if (i + 1) % 100 == 0 {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                Log.print("[PreScanBM] T2 진행: \(i + 1)/\(assets.count) (\(String(format: "%.1f", elapsed))초)")
            }
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        return buildResultFromLightResults(lightResults, label: "T2: SKIP필터+NoSafeGuard", totalTime: totalTime)
    }

    // MARK: - T3: Exposure + Blur만 (최경량)

    /// MetadataFilter → Exposure → Blur (SKIP필터 없음, SafeGuard 없음)
    private static func runLightweight(assets: [PHAsset]) async -> PreScanBenchmarkResult {
        let metadataFilter = MetadataFilter()
        let exposureAnalyzer = ExposureAnalyzer.shared
        let blurAnalyzer = BlurAnalyzer.shared
        let imageLoader = CleanupImageLoader.shared

        let startTime = CFAbsoluteTimeGetCurrent()
        var lightResults: [LightResult] = []

        for (i, asset) in assets.enumerated() {
            let itemStart = CFAbsoluteTimeGetCurrent()
            let assetID = asset.localIdentifier

            // Stage 1: MetadataFilter
            if metadataFilter.shouldAnalyze(asset) != nil {
                lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                continue
            }

            // 이미지 로딩
            guard let image = try? await imageLoader.loadImage(for: asset) else {
                lightResults.append(LightResult(assetID: assetID, isLowQuality: false, isSkipped: true, signals: [], timeMs: 0))
                continue
            }

            var signals: [QualitySignal] = []

            // Stage 2: Exposure
            if let metrics = try? exposureAnalyzer.analyze(image) {
                signals.append(contentsOf: exposureAnalyzer.detectSignals(from: metrics, mode: .precision))
            }

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
            let itemTime = (CFAbsoluteTimeGetCurrent() - itemStart) * 1000
            lightResults.append(LightResult(assetID: assetID, isLowQuality: isLow, isSkipped: false, signals: signals, timeMs: itemTime))

            if (i + 1) % 100 == 0 {
                let elapsed = CFAbsoluteTimeGetCurrent() - startTime
                Log.print("[PreScanBM] T3 진행: \(i + 1)/\(assets.count) (\(String(format: "%.1f", elapsed))초)")
            }
        }

        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        return buildResultFromLightResults(lightResults, label: "T3: Exposure+Blur만", totalTime: totalTime)
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

    // MARK: - 결과 변환 헬퍼

    /// 경량 결과 저장용
    private struct LightResult {
        let assetID: String
        let isLowQuality: Bool
        let isSkipped: Bool
        let signals: [QualitySignal]
        let timeMs: Double
    }

    /// QualityResult 배열 → PreScanBenchmarkResult
    private static func buildResultFromQualityResults(
        _ results: [QualityResult],
        label: String,
        totalTime: Double
    ) -> PreScanBenchmarkResult {
        let lowQuality = results.filter { $0.verdict.isLowQuality }
        let skipped = results.filter { !$0.verdict.isAnalyzed }
        let safeGuarded = results.filter { $0.safeGuardApplied }
        let acceptable = results.count - lowQuality.count - skipped.count
        let analyzed = results.filter { $0.verdict.isAnalyzed }
        let avgTime = analyzed.isEmpty ? 0 :
            analyzed.reduce(0) { $0 + $1.analysisTimeMs } / Double(analyzed.count)

        let details = lowQuality.map { r in
            let signalStr = r.signals.map { $0.kind.rawValue }.joined(separator: ", ")
            return (assetID: r.assetID, signals: signalStr)
        }

        return PreScanBenchmarkResult(
            label: label, totalCount: results.count, lowQualityCount: lowQuality.count,
            skippedCount: skipped.count, acceptableCount: acceptable, safeGuardedCount: safeGuarded.count,
            totalTimeSeconds: totalTime, avgTimeMs: avgTime, lowQualityDetails: details
        )
    }

    /// LightResult 배열 → PreScanBenchmarkResult
    private static func buildResultFromLightResults(
        _ results: [LightResult],
        label: String,
        totalTime: Double
    ) -> PreScanBenchmarkResult {
        let lowQuality = results.filter { $0.isLowQuality }
        let skipped = results.filter { $0.isSkipped }
        let acceptable = results.count - lowQuality.count - skipped.count
        let analyzed = results.filter { !$0.isSkipped }
        let avgTime = analyzed.isEmpty ? 0 :
            analyzed.reduce(0) { $0 + $1.timeMs } / Double(analyzed.count)

        let details = lowQuality.map { r in
            let signalStr = r.signals.map { $0.kind.rawValue }.joined(separator: ", ")
            return (assetID: r.assetID, signals: signalStr)
        }

        return PreScanBenchmarkResult(
            label: label, totalCount: results.count, lowQualityCount: lowQuality.count,
            skippedCount: skipped.count, acceptableCount: acceptable, safeGuardedCount: 0,
            totalTimeSeconds: totalTime, avgTimeMs: avgTime, lowQualityDetails: details
        )
    }

    // MARK: - 출력

    /// 개별 테스트 결과 출력
    private static func printResult(_ result: PreScanBenchmarkResult) {
        Log.print("[PreScanBM] [\(result.label)]")
        Log.print("[PreScanBM]   총 시간: \(String(format: "%.2f", result.totalTimeSeconds))초")
        Log.print("[PreScanBM]   평균/장: \(String(format: "%.1f", result.avgTimeMs))ms")
        Log.print("[PreScanBM]   결과: 저품질=\(result.lowQualityCount), 양호=\(result.acceptableCount), 스킵=\(result.skippedCount), 세이프가드=\(result.safeGuardedCount)")

        if !result.lowQualityDetails.isEmpty {
            let showCount = min(10, result.lowQualityDetails.count)
            Log.print("[PreScanBM]   저품질 상세 (상위 \(showCount)개):")
            for detail in result.lowQualityDetails.prefix(showCount) {
                let shortID = String(detail.assetID.prefix(12))
                Log.print("[PreScanBM]     \(shortID)... → [\(detail.signals)]")
            }
        }
    }

    /// 3종 비교 요약 출력
    private static func printComparison3(
        t1: PreScanBenchmarkResult,
        t2: PreScanBenchmarkResult,
        t3: PreScanBenchmarkResult
    ) {
        Log.print("[PreScanBM]")
        Log.print("[PreScanBM] ============ 3종 비교 요약 ============")

        // 속도 비교
        Log.print("[PreScanBM] 속도:")
        Log.print("[PreScanBM]   T1 (Full):          \(String(format: "%.2f", t1.totalTimeSeconds))초 (avg \(String(format: "%.1f", t1.avgTimeMs))ms)")
        Log.print("[PreScanBM]   T2 (SKIP필터only):  \(String(format: "%.2f", t2.totalTimeSeconds))초 (avg \(String(format: "%.1f", t2.avgTimeMs))ms)")
        Log.print("[PreScanBM]   T3 (최경량):        \(String(format: "%.2f", t3.totalTimeSeconds))초 (avg \(String(format: "%.1f", t3.avgTimeMs))ms)")

        // SafeGuard 비용 = T1 - T2
        let safeGuardCost = t1.totalTimeSeconds - t2.totalTimeSeconds
        Log.print("[PreScanBM]")
        Log.print("[PreScanBM] SafeGuard 비용 (T1-T2): \(String(format: "%+.2f", safeGuardCost))초")

        // SKIP필터 비용 = T2 - T3
        let skipFilterCost = t2.totalTimeSeconds - t3.totalTimeSeconds
        Log.print("[PreScanBM] SKIP필터 비용 (T2-T3): \(String(format: "%+.2f", skipFilterCost))초")

        // 저품질 판정 비교
        Log.print("[PreScanBM]")
        Log.print("[PreScanBM] 저품질 판정:")
        Log.print("[PreScanBM]   T1: \(t1.lowQualityCount)장 / T2: \(t2.lowQualityCount)장 / T3: \(t3.lowQualityCount)장")

        // SafeGuard에 의한 판정 차이 = T2 vs T1
        let t1LowIDs = Set(t1.lowQualityDetails.map { $0.assetID })
        let t2LowIDs = Set(t2.lowQualityDetails.map { $0.assetID })
        let t3LowIDs = Set(t3.lowQualityDetails.map { $0.assetID })

        let safeGuardSaved = t2LowIDs.subtracting(t1LowIDs)  // T2에선 저품질인데 T1에선 아님 = SafeGuard 구제
        let skipFilterSaved = t3LowIDs.subtracting(t2LowIDs)  // T3에선 저품질인데 T2에선 아님 = SKIP필터 구제

        if !safeGuardSaved.isEmpty {
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] SafeGuard가 구제한 사진 (T2에만 저품질): \(safeGuardSaved.count)장")
            for id in safeGuardSaved.prefix(5) {
                let shortID = String(id.prefix(12))
                if let detail = t2.lowQualityDetails.first(where: { $0.assetID == id }) {
                    Log.print("[PreScanBM]   \(shortID)... → [\(detail.signals)]")
                }
            }
        } else {
            Log.print("[PreScanBM]   SafeGuard 구제: 0장")
        }

        if !skipFilterSaved.isEmpty {
            Log.print("[PreScanBM]")
            Log.print("[PreScanBM] SKIP필터가 구제한 사진 (T3에만 저품질): \(skipFilterSaved.count)장")
            for id in skipFilterSaved.prefix(5) {
                let shortID = String(id.prefix(12))
                if let detail = t3.lowQualityDetails.first(where: { $0.assetID == id }) {
                    Log.print("[PreScanBM]   \(shortID)... → [\(detail.signals)]")
                }
            }
        } else {
            Log.print("[PreScanBM]   SKIP필터 구제: 0장")
        }

        // 스킵 수 비교
        Log.print("[PreScanBM]")
        Log.print("[PreScanBM] 스킵 수: T1=\(t1.skippedCount) / T2=\(t2.skippedCount) / T3=\(t3.skippedCount)")

        if t1.safeGuardedCount > 0 {
            Log.print("[PreScanBM] T1 SafeGuard 적용: \(t1.safeGuardedCount)장")
        }

        Log.print("[PreScanBM] ==========================================")
    }
}
#endif

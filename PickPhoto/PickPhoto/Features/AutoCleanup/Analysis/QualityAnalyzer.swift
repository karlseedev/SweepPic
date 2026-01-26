//
//  QualityAnalyzer.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  품질 분석기 - 전체 파이프라인 통합
//  - Stage 1: 메타데이터 필터링 (MetadataFilter)
//  - Stage 2: 노출 분석 (ExposureAnalyzer)
//  - Stage 3: 블러 분석 (BlurAnalyzer)
//  - Stage 4: Safe Guard 체크 (SafeGuardChecker)
//  - 최종 판정 및 결과 생성
//
//  동영상 처리:
//  - 5초 이하: 프레임 3개 추출 (10%/50%/90%), 중앙값 판정
//  - 5초 초과: SKIP (MetadataFilter에서 처리)
//

import Foundation
import Photos

/// 품질 분석기
///
/// 개별 사진의 품질을 분석하여 저품질 여부를 판정합니다.
/// 4단계 파이프라인을 통해 분석을 수행합니다.
/// 동영상의 경우 프레임 3개 추출 후 중앙값 판정.
final class QualityAnalyzer {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = QualityAnalyzer()

    // MARK: - Properties

    /// 메타데이터 필터
    private let metadataFilter: MetadataFilter

    /// 노출 분석기
    private let exposureAnalyzer: ExposureAnalyzer

    /// 블러 분석기
    private let blurAnalyzer: BlurAnalyzer

    /// Safe Guard 체커
    private let safeGuardChecker: SafeGuardChecker

    /// 이미지 로더 (기존 SimilarityImageLoader 재사용)
    private let imageLoader: SimilarityImageLoader

    /// 동영상 프레임 추출기
    private let videoFrameExtractor: VideoFrameExtractor

    /// 판정 모드
    private(set) var mode: JudgmentMode = .precision

    // MARK: - Initialization

    /// 분석기 초기화
    /// - Parameters:
    ///   - metadataFilter: 메타데이터 필터
    ///   - exposureAnalyzer: 노출 분석기
    ///   - blurAnalyzer: 블러 분석기
    ///   - safeGuardChecker: Safe Guard 체커
    ///   - imageLoader: 이미지 로더
    ///   - videoFrameExtractor: 동영상 프레임 추출기
    init(
        metadataFilter: MetadataFilter = MetadataFilter(),
        exposureAnalyzer: ExposureAnalyzer = .shared,
        blurAnalyzer: BlurAnalyzer = .shared,
        safeGuardChecker: SafeGuardChecker = .shared,
        imageLoader: SimilarityImageLoader = .shared,
        videoFrameExtractor: VideoFrameExtractor = .shared
    ) {
        self.metadataFilter = metadataFilter
        self.exposureAnalyzer = exposureAnalyzer
        self.blurAnalyzer = blurAnalyzer
        self.safeGuardChecker = safeGuardChecker
        self.imageLoader = imageLoader
        self.videoFrameExtractor = videoFrameExtractor
    }

    // MARK: - Configuration

    /// 판정 모드 설정
    /// - Parameter mode: 새 판정 모드
    func setMode(_ mode: JudgmentMode) {
        self.mode = mode
    }

    // MARK: - Public Methods

    /// 단일 사진/동영상 분석
    ///
    /// - Parameter asset: 분석할 PHAsset
    /// - Returns: 품질 분석 결과
    ///
    /// - Note: Stage 1~4 순차 수행, 에러 발생 시 SKIP 처리
    /// - Note: 동영상은 프레임 3개 추출 후 중앙값 판정
    func analyze(_ asset: PHAsset) async -> QualityResult {
        let startTime = CFAbsoluteTimeGetCurrent()
        let assetID = asset.localIdentifier
        let creationDate = asset.creationDate

        // Stage 1: 메타데이터 필터링
        if let skipReason = metadataFilter.shouldAnalyze(asset) {
            return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: skipReason)
        }

        // 동영상 분기 처리 (5초 이하만 여기까지 도달)
        if asset.mediaType == .video {
            return await analyzeVideo(asset, startTime: startTime)
        }

        // 해상도 체크 (Recall 모드)
        let pixelCount = asset.pixelWidth * asset.pixelHeight
        var resolutionSignal: QualitySignal?
        if mode == .recall && pixelCount < CleanupConstants.lowResolutionPixelCount {
            resolutionSignal = QualitySignal(
                kind: .lowResolution,
                measuredValue: Double(pixelCount),
                threshold: Double(CleanupConstants.lowResolutionPixelCount)
            )
        }

        // 이미지 로딩
        let image: CGImage
        do {
            image = try await imageLoader.loadImage(for: asset)
        } catch {
            // 이미지 로딩 실패 → SKIP
            if let loadError = error as? SimilarityImageLoadError {
                switch loadError {
                case .timeout:
                    return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .analysisError)
                default:
                    return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .analysisError)
                }
            }
            return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .analysisError)
        }

        // Stage 2: 노출 분석
        let exposureMetrics: ExposureMetrics
        do {
            exposureMetrics = try exposureAnalyzer.analyze(image)
        } catch {
            return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .analysisError)
        }

        var signals = exposureAnalyzer.detectSignals(from: exposureMetrics, mode: mode)

        // Stage 3: 블러 분석
        let blurMetrics: BlurMetrics
        do {
            if blurAnalyzer.isAvailable {
                blurMetrics = try blurAnalyzer.analyze(image)
            } else {
                blurMetrics = try blurAnalyzer.analyzeCPU(image)
            }
        } catch {
            return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .analysisError)
        }

        let blurSignals = blurAnalyzer.detectSignals(from: blurMetrics, mode: mode)
        signals.append(contentsOf: blurSignals)

        // 해상도 신호 추가 (Recall 모드)
        if let resSignal = resolutionSignal {
            signals.append(resSignal)
        }

        // Stage 4: Safe Guard 체크 (블러 신호가 있을 때만)
        var safeGuardResult = SafeGuardResult.notApplied

        if safeGuardChecker.needsSafeGuardCheck(for: signals) {
            // 메타데이터 체크 (빠른 체크 먼저)
            safeGuardResult = safeGuardChecker.checkMetadata(asset)

            // 메타데이터로 Safe Guard 적용 안 되면 얼굴 품질 체크
            if !safeGuardResult.isApplied {
                do {
                    safeGuardResult = try await safeGuardChecker.checkFaceQuality(image)
                } catch {
                    // Vision 에러는 무시하고 계속 진행
                    #if DEBUG
                    print("[QualityAnalyzer] SafeGuard face check failed: \(error.localizedDescription)")
                    #endif
                }
            }
        }

        // 최종 판정
        let analysisTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let analysisMethod: AnalysisMethod = blurAnalyzer.isAvailable ? .metalPipeline : .fallback

        return makeVerdict(
            assetID: assetID,
            creationDate: creationDate,
            signals: signals,
            safeGuardResult: safeGuardResult,
            analysisTimeMs: analysisTimeMs,
            method: analysisMethod
        )
    }

    /// 배치 분석 (병렬 처리)
    ///
    /// - Parameters:
    ///   - assets: 분석할 PHAsset 배열
    ///   - maxConcurrent: 최대 동시 분석 수 (기본값: 4)
    ///   - onProgress: 진행 콜백 (분석 완료된 결과)
    /// - Returns: 모든 분석 결과 배열 (원본 순서 보장)
    ///
    /// - Important: 결과는 입력 assets 배열과 동일한 순서로 반환됩니다.
    ///   이는 50장 제한 로직과 이어서 정리 기능의 정확성을 위해 필수입니다.
    func analyzeBatch(
        _ assets: [PHAsset],
        maxConcurrent: Int = 4,  // CleanupConstants.concurrentAnalysis
        onProgress: ((QualityResult) -> Void)? = nil
    ) async -> [QualityResult] {
        // 빈 배열 처리
        guard !assets.isEmpty else { return [] }

        // TaskGroup으로 병렬 분석 (인덱스와 함께 결과 수집)
        let indexedResults = await withTaskGroup(of: (index: Int, result: QualityResult).self) { group in
            var results: [(index: Int, result: QualityResult)] = []
            results.reserveCapacity(assets.count)

            // 동시성 제한을 위한 세마포어 역할
            var activeCount = 0
            var assetIndex = 0

            // 초기 태스크 추가
            while activeCount < maxConcurrent && assetIndex < assets.count {
                let asset = assets[assetIndex]
                let capturedIndex = assetIndex  // 클로저에서 캡처할 인덱스
                group.addTask {
                    let result = await self.analyze(asset)
                    return (index: capturedIndex, result: result)
                }
                activeCount += 1
                assetIndex += 1
            }

            // 결과 수집 및 추가 태스크 시작
            for await indexedResult in group {
                results.append(indexedResult)
                onProgress?(indexedResult.result)

                // 다음 태스크 추가
                if assetIndex < assets.count {
                    let asset = assets[assetIndex]
                    let capturedIndex = assetIndex
                    group.addTask {
                        let result = await self.analyze(asset)
                        return (index: capturedIndex, result: result)
                    }
                    assetIndex += 1
                }
            }

            return results
        }

        // 원본 순서대로 정렬하여 반환
        return indexedResults
            .sorted { $0.index < $1.index }
            .map { $0.result }
    }

    // MARK: - Private Methods

    /// 동영상 분석 (프레임 3개 추출, 중앙값 판정)
    ///
    /// - Parameters:
    ///   - asset: 분석할 동영상 PHAsset
    ///   - startTime: 분석 시작 시간 (성능 측정용)
    /// - Returns: 품질 분석 결과
    ///
    /// - Note: 2개 이상 저품질 프레임 → LOW_QUALITY
    private func analyzeVideo(_ asset: PHAsset, startTime: CFAbsoluteTime) async -> QualityResult {
        let assetID = asset.localIdentifier
        let creationDate = asset.creationDate

        // 프레임 추출
        let frames: [CGImage]
        do {
            frames = try await videoFrameExtractor.extractFrames(from: asset)
        } catch {
            // 프레임 추출 실패 → SKIP
            #if DEBUG
            print("[QualityAnalyzer] 동영상 프레임 추출 실패: \(error.localizedDescription)")
            #endif

            if let extractError = error as? VideoFrameExtractError {
                switch extractError {
                case .iCloudOnly:
                    return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .iCloudOnly)
                default:
                    return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .analysisError)
                }
            }
            return QualityResult.skipped(assetID: assetID, creationDate: creationDate, reason: .analysisError)
        }

        // 각 프레임 분석
        var lowQualityCount = 0
        var allSignals: [QualitySignal] = []

        for frame in frames {
            let frameResult = analyzeFrame(frame)
            allSignals.append(contentsOf: frameResult.signals)

            if frameResult.isLowQuality {
                lowQualityCount += 1
            }
        }

        let analysisTimeMs = (CFAbsoluteTimeGetCurrent() - startTime) * 1000
        let analysisMethod: AnalysisMethod = blurAnalyzer.isAvailable ? .metalPipeline : .fallback

        // 중앙값 판정: 2개 이상 저품질 → LOW_QUALITY
        let isLowQuality = lowQualityCount >= 2

        #if DEBUG
        print("[QualityAnalyzer] 동영상 분석: \(frames.count)프레임, 저품질=\(lowQualityCount), 판정=\(isLowQuality ? "LOW" : "OK")")
        #endif

        if isLowQuality {
            return QualityResult.lowQuality(
                assetID: assetID,
                creationDate: creationDate,
                signals: allSignals,
                analysisTimeMs: analysisTimeMs,
                method: analysisMethod
            )
        }

        return QualityResult.acceptable(
            assetID: assetID,
            creationDate: creationDate,
            signals: allSignals,
            analysisTimeMs: analysisTimeMs,
            method: analysisMethod
        )
    }

    /// 단일 프레임 분석 (노출 + 블러)
    ///
    /// - Parameter frame: 분석할 CGImage
    /// - Returns: (저품질 여부, 신호 배열)
    private func analyzeFrame(_ frame: CGImage) -> (isLowQuality: Bool, signals: [QualitySignal]) {
        var signals: [QualitySignal] = []

        // 노출 분석
        do {
            let exposureMetrics = try exposureAnalyzer.analyze(frame)
            let exposureSignals = exposureAnalyzer.detectSignals(from: exposureMetrics, mode: mode)
            signals.append(contentsOf: exposureSignals)
        } catch {
            #if DEBUG
            print("[QualityAnalyzer] 프레임 노출 분석 실패: \(error.localizedDescription)")
            #endif
        }

        // 블러 분석
        do {
            let blurMetrics: BlurMetrics
            if blurAnalyzer.isAvailable {
                blurMetrics = try blurAnalyzer.analyze(frame)
            } else {
                blurMetrics = try blurAnalyzer.analyzeCPU(frame)
            }
            let blurSignals = blurAnalyzer.detectSignals(from: blurMetrics, mode: mode)
            signals.append(contentsOf: blurSignals)
        } catch {
            #if DEBUG
            print("[QualityAnalyzer] 프레임 블러 분석 실패: \(error.localizedDescription)")
            #endif
        }

        // 판정 (동영상에서는 Safe Guard 적용 안 함)
        let isLowQuality: Bool
        switch mode {
        case .precision:
            isLowQuality = signals.hasStrongSignal
        case .recall:
            isLowQuality = signals.hasStrongSignal ||
                           signals.hasConditionalSignal ||
                           signals.hasEnoughWeakSignals
        }

        return (isLowQuality, signals)
    }

    /// 최종 판정 생성
    private func makeVerdict(
        assetID: String,
        creationDate: Date?,
        signals: [QualitySignal],
        safeGuardResult: SafeGuardResult,
        analysisTimeMs: Double,
        method: AnalysisMethod
    ) -> QualityResult {

        // Safe Guard 적용 시 블러 신호 무효화
        var effectiveSignals = signals
        if safeGuardResult.isApplied {
            effectiveSignals = signals.filter { signal in
                signal.kind != .severeBlur && signal.kind != .generalBlur
            }
        }

        // 판정 로직
        let isLowQuality: Bool

        switch mode {
        case .precision:
            // Precision 모드: Strong 신호만 저품질
            isLowQuality = effectiveSignals.hasStrongSignal

        case .recall:
            // Recall 모드: Strong OR Conditional OR Weak 합산 >= 3
            isLowQuality = effectiveSignals.hasStrongSignal ||
                           effectiveSignals.hasConditionalSignal ||
                           effectiveSignals.hasEnoughWeakSignals
        }

        // 결과 생성
        if isLowQuality {
            return QualityResult.lowQuality(
                assetID: assetID,
                creationDate: creationDate,
                signals: effectiveSignals,
                analysisTimeMs: analysisTimeMs,
                method: method
            )
        }

        if safeGuardResult.isApplied, let reason = safeGuardResult.reason {
            return QualityResult.safeGuarded(
                assetID: assetID,
                creationDate: creationDate,
                signals: signals,  // 원본 신호 유지 (디버깅용)
                reason: reason,
                analysisTimeMs: analysisTimeMs,
                method: method
            )
        }

        return QualityResult.acceptable(
            assetID: assetID,
            creationDate: creationDate,
            signals: effectiveSignals,
            analysisTimeMs: analysisTimeMs,
            method: method
        )
    }
}

// MARK: - Convenience Methods

extension QualityAnalyzer {

    /// 저품질 사진만 필터링
    ///
    /// - Parameter results: 분석 결과 배열
    /// - Returns: 저품질 판정된 결과만 필터링
    func filterLowQuality(_ results: [QualityResult]) -> [QualityResult] {
        return results.filter { $0.verdict.isLowQuality }
    }

    /// 분석 통계 생성
    ///
    /// - Parameter results: 분석 결과 배열
    /// - Returns: (총 분석 수, 저품질 수, SKIP 수, 평균 분석 시간)
    func statistics(from results: [QualityResult]) -> (
        total: Int,
        lowQuality: Int,
        skipped: Int,
        averageTimeMs: Double
    ) {
        let total = results.count
        let lowQuality = results.filter { $0.verdict.isLowQuality }.count
        let skipped = results.filter { !$0.verdict.isAnalyzed }.count
        let analyzed = results.filter { $0.verdict.isAnalyzed }
        let averageTimeMs = analyzed.isEmpty ? 0 :
            analyzed.reduce(0) { $0 + $1.analysisTimeMs } / Double(analyzed.count)

        return (total, lowQuality, skipped, averageTimeMs)
    }
}

// MARK: - Debug Support

#if DEBUG
extension QualityAnalyzer {

    /// 디버그용: 상세 분석 결과 출력
    func debugAnalyze(_ asset: PHAsset) async -> String {
        let result = await analyze(asset)

        var output = """
        === Quality Analysis Debug ===
        Asset ID: \(asset.localIdentifier)
        Mode: \(mode.rawValue)

        """

        // 결과 요약
        output += "Verdict: \(result.description)\n\n"

        // 신호 상세
        if !result.signals.isEmpty {
            output += "Signals:\n"
            for signal in result.signals {
                output += "  - \(signal.description)\n"
            }
        }

        // Safe Guard
        if result.safeGuardApplied, let reason = result.safeGuardReason {
            output += "\nSafeGuard: \(reason.rawValue)\n"
        }

        output += "\nAnalysis Time: \(String(format: "%.1f", result.analysisTimeMs))ms"
        output += "\nMethod: \(result.analysisMethod.rawValue)"

        return output
    }
}
#endif

//
//  CleanupPreviewService.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  미리보기 전용 분석 서비스
//  - 기존 CleanupService와 독립 (즉시 이동 흐름 유지)
//  - 분석만 수행, 삭제대기함 이동 없음
//  - 3모드 (완화/기본/강화) 동시 평가하여 단계별 분류
//  - 3모드 동시 평가 로직 독립 구현
//
//  iOS 분기:
//  - iOS 18+: path1 + path2 → 3단계 결과
//  - iOS 16~17: path1만 → light만, standard/deep 빈 배열
//

import Foundation
import Photos
import Vision
import AppCore
import OSLog

// MARK: - CleanupPreviewService

/// 미리보기 전용 분석 서비스
///
/// 사진을 분석하여 3단계(완화/기본/강화)로 분류합니다.
/// 삭제대기함 이동 없이 결과만 반환하여 미리보기 그리드에 표시.
final class CleanupPreviewService {

    // MARK: - Constants

    /// 경로1: 동의용 임계값 (Weak/Conditional 신호에만 적용)
    private let path1AgreeThreshold: Float = 0.2

    /// 경로2 임계값 - 완화 (엄격)
    private let path2LightThreshold: Float = -0.3

    /// 경로2 임계값 - 기본
    private let path2StandardThreshold: Float = 0.0

    /// 경로2 임계값 - 강화 (완화)
    /// - 0.3: 정상 사진 최소값(0.230) 근처까지 포함하여 적극적으로 검출
    /// - 3등급(가장 완화)이므로 일부 오탐 허용, 사용자가 미리보기에서 확인
    private let path2DeepThreshold: Float = 0.3

    /// 최대 검색 수
    private let maxScanCount: Int = CleanupConstants.maxScanCount

    /// 최대 발견 수 (light 기준, FR-007)
    private let maxFoundCount: Int = CleanupConstants.maxFoundCount

    /// 극단적 비율 임계값 (세로/가로 > 5.0 or < 0.2)
    private let extremeAspectRatioThreshold: CGFloat = 5.0

    // MARK: - Session Storage

    /// 미리보기 세션 키 (기존 CleanupSessionStore와 독립)
    private static let lastScanDateKey = "PreviewSession.lastScanDate"

    /// 연도별 미리보기 세션 키 (byYear 이어서 정리용)
    private static let byYearLastScanDateKey = "PreviewSession.byYear.lastScanDate"
    private static let byYearYearKey = "PreviewSession.byYear.year"
    private static let byYearCanContinueKey = "PreviewSession.byYear.canContinue"

    // MARK: - State

    /// 취소 플래그
    private var isCancelled = false

    /// 동시 접근 보호용 락
    private let lock = NSLock()

    // MARK: - Session Management

    /// 마지막 스캔 날짜 (이어서 정리용)
    static var lastScanDate: Date? {
        return UserDefaults.standard.object(forKey: lastScanDateKey) as? Date
    }

    /// 이어서 정리 가능 여부
    static var canContinue: Bool {
        return lastScanDate != nil
    }

    /// 세션 저장
    private func saveSession(lastDate: Date) {
        UserDefaults.standard.set(lastDate, forKey: Self.lastScanDateKey)
    }

    /// 세션 초기화
    static func clearSession() {
        UserDefaults.standard.removeObject(forKey: lastScanDateKey)
    }

    // MARK: - ByYear Session Management

    /// 연도별 마지막 스캔 날짜
    static var lastByYearScanDate: Date? {
        return UserDefaults.standard.object(forKey: byYearLastScanDateKey) as? Date
    }

    /// 연도별 마지막 정리 대상 연도
    static var lastByYearYear: Int? {
        let value = UserDefaults.standard.integer(forKey: byYearYearKey)
        return value == 0 ? nil : value
    }

    /// 연도별 이어서 정리 가능 여부
    /// - 이전 byYear 세션이 존재하고, 범위 끝에 도달하지 않았을 때 true
    static var canContinueByYear: Bool {
        guard lastByYearScanDate != nil, lastByYearYear != nil else { return false }
        return UserDefaults.standard.bool(forKey: byYearCanContinueKey)
    }

    /// 연도별 세션 저장
    /// - Parameters:
    ///   - year: 정리 대상 연도
    ///   - lastDate: 마지막 스캔 날짜
    ///   - canContinue: 이어서 정리 가능 여부 (maxFound/maxScanned이면 true)
    private func saveByYearSession(year: Int, lastDate: Date, canContinue: Bool) {
        UserDefaults.standard.set(lastDate, forKey: Self.byYearLastScanDateKey)
        UserDefaults.standard.set(year, forKey: Self.byYearYearKey)
        UserDefaults.standard.set(canContinue, forKey: Self.byYearCanContinueKey)
    }

    /// 연도별 세션 초기화
    static func clearByYearSession() {
        UserDefaults.standard.removeObject(forKey: byYearLastScanDateKey)
        UserDefaults.standard.removeObject(forKey: byYearYearKey)
        UserDefaults.standard.removeObject(forKey: byYearCanContinueKey)
    }

    // MARK: - Cancel

    /// 분석 취소
    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
    }

    /// 취소 여부 확인 (thread-safe)
    private var cancelled: Bool {
        lock.lock()
        defer { lock.unlock() }
        return isCancelled
    }

    // MARK: - Main API

    /// 분석 실행 — 이동 없이 3단계 분류 결과만 반환
    ///
    /// - Parameters:
    ///   - method: 정리 방식 (.fromLatest / .continueFromLast / .byYear)
    ///   - progressHandler: 진행 상황 콜백 (메인 스레드 아님)
    /// - Returns: 3단계 분류된 PreviewResult
    /// - Throws: 취소 시 CancellationError
    func analyze(
        method: CleanupMethod,
        progressHandler: @escaping (CleanupProgress) -> Void
    ) async throws -> PreviewResult {

        let startTime = Date()

        // QualityAnalyzer 모드 고정 (싱글톤 상태가 외부에서 변경될 수 있으므로)
        QualityAnalyzer.shared.setMode(.precision)

        // 처음부터 시작이면 세션 초기화
        if case .fromLatest = method {
            Self.clearSession()
        }

        // 연도별 새로 시작이면 byYear 세션 초기화
        if case .byYear(_, let continueFrom) = method, continueFrom == nil {
            Self.clearByYearSession()
        }

        // PHFetchResult 생성 (이미지만)
        let fetchResult = createFetchResult(for: method)
        let totalToScan = min(fetchResult.count, maxScanCount)

        // 결과 수집
        var lightCandidates: [PreviewCandidate] = []
        var standardCandidates: [PreviewCandidate] = []
        var deepCandidates: [PreviewCandidate] = []
        var totalScanned = 0
        var lastAssetDate: Date?

        // 등급별 Path 카운터 (분포 로그용)
        var lightPath1Count = 0, lightPath2Count = 0
        var stdPath1Count = 0, stdPath2Count = 0
        var deepPath1Count = 0, deepPath2Count = 0

        // 배치 처리
        let batchSize = CleanupConstants.batchSize
        var currentIndex = 0

        while currentIndex < totalToScan {
            // 취소 체크
            if cancelled {
                throw CancellationError()
            }

            // 50장 제한 체크 (light 기준 — 그리드 첫 화면에 보이는 수, FR-007)
            if lightCandidates.count >= maxFoundCount {
                break
            }

            let endIndex = min(currentIndex + batchSize, totalToScan)
            var batchAssets: [PHAsset] = []

            for i in currentIndex..<endIndex {
                batchAssets.append(fetchResult.object(at: i))
            }

            // 배치 내 개별 처리
            for asset in batchAssets {
                // 취소 체크 (배치 내에서도)
                if cancelled {
                    throw CancellationError()
                }

                totalScanned += 1

                // 마지막 asset 날짜 기록 (이어서 정리용)
                if let date = asset.creationDate {
                    lastAssetDate = date
                }

                // 극단적 비율 체크 (블로그 저장 이미지 등 제외)
                let aspectRatio = CGFloat(asset.pixelHeight) / CGFloat(asset.pixelWidth)
                let isExtremeRatio = aspectRatio > extremeAspectRatioThreshold ||
                    aspectRatio < (1.0 / extremeAspectRatioThreshold)
                if isExtremeRatio {
                    reportProgress(
                        scanned: totalScanned,
                        found: lightCandidates.count,
                        date: asset.creationDate ?? Date(),
                        handler: progressHandler
                    )
                    continue
                }

                // 1. 기존 로직 (path1)
                let oldResult = await QualityAnalyzer.shared.analyze(asset)

                // 2. iOS 18+: AestheticsScore + 텍스트 감지
                var aestheticsScore: Float? = nil
                var isUtility = false
                var isTextScreenshot = false
                var loadedImage: CGImage? = nil

                if #available(iOS 18.0, *) {
                    // 이미지 로드 (SafeGuard에서도 재사용하기 위해 외부 변수에 캡처)
                    if let image = try? await CleanupImageLoader.shared.loadImage(for: asset) {
                        loadedImage = image

                        // AestheticsScore 분석
                        if let metrics = try? await AestheticsAnalyzer.shared.analyze(image) {
                            aestheticsScore = metrics.overallScore
                            isUtility = metrics.isUtility
                        }

                        // 텍스트 스크린샷 감지 (1회, 결과 재사용)
                        isTextScreenshot = await detectTextScreenshot(image)
                    }
                }
                // iOS 16~17: path1 결과만 사용, 이미지 로드/텍스트 감지 스킵

                // 3. 경로1 판정 (모든 모드 공통)
                let path1Result = evaluatePath1(
                    oldResult: oldResult,
                    aestheticsScore: aestheticsScore
                )

                // 4. 경로2 판정 (임계값만 다르게 3회)
                let path2Light = evaluatePath2(
                    score: aestheticsScore,
                    isUtility: isUtility,
                    isTextScreenshot: isTextScreenshot,
                    threshold: path2LightThreshold
                )
                let path2Std = evaluatePath2(
                    score: aestheticsScore,
                    isUtility: isUtility,
                    isTextScreenshot: isTextScreenshot,
                    threshold: path2StandardThreshold
                )
                let path2Deep = evaluatePath2(
                    score: aestheticsScore,
                    isUtility: isUtility,
                    isTextScreenshot: isTextScreenshot,
                    threshold: path2DeepThreshold
                )

                // 5. 경로2 단독 검출 시 SafeGuard 체크
                //    경로1이 이미 검출했으면 SafeGuard 불필요 (경로1 내부에서 이미 처리됨)
                let anyPath2 = path2Light || path2Std || path2Deep
                var safeGuardDebug: SafeGuardDebugInfo? = nil
                var path2SafeGuarded = false

                if !path1Result && anyPath2 {
                    // QualityAnalyzer가 이미 SafeGuard를 적용한 경우 재사용 (중복 방지)
                    if oldResult.safeGuardApplied {
                        path2SafeGuarded = true
                        safeGuardDebug = SafeGuardDebugInfo(
                            isPortrait: oldResult.safeGuardReason == .depthEffect,
                            faceCount: oldResult.safeGuardReason == .clearFace ? 1 : 0,
                            maxFaceQuality: nil,
                            applied: true,
                            reason: oldResult.safeGuardReason
                        )
                    } else {
                        // 메타데이터 체크 (포트레이트 모드, ~0ms)
                        let metaResult = SafeGuardChecker.shared.checkMetadata(asset)
                        if metaResult.isApplied {
                            path2SafeGuarded = true
                            safeGuardDebug = SafeGuardDebugInfo(
                                isPortrait: true,
                                faceCount: 0,
                                maxFaceQuality: nil,
                                applied: true,
                                reason: metaResult.reason
                            )
                        } else {
                            // 얼굴 감지 체크 (Vision, 720px 이미지 자동 로드)
                            // path2(AestheticsScore)에서는 얼굴이 감지되기만 하면 보호
                            // (path1 블러 SafeGuard와 달리 품질 임계값 불필요)
                            let detail = try? await SafeGuardChecker.shared.checkFaceQuality(asset: asset)
                            let faceCount = detail?.faceCount ?? 0
                            let maxQuality = detail?.maxFaceQuality
                            let hasFace = faceCount > 0

                            path2SafeGuarded = hasFace
                            safeGuardDebug = SafeGuardDebugInfo(
                                isPortrait: false,
                                faceCount: faceCount,
                                maxFaceQuality: maxQuality,
                                applied: hasFace,
                                reason: hasFace ? .clearFace : nil
                            )
                        }
                    }

                    // SafeGuard 적용 시 해당 사진 제외
                    if path2SafeGuarded {
                        reportProgress(
                            scanned: totalScanned,
                            found: lightCandidates.count,
                            date: asset.creationDate ?? Date(),
                            handler: progressHandler
                        )
                        continue
                    }
                }

                // 6. 3모드 계산
                // Path1 Strong(극단 노출/심각 블러)만 5등급, Weak는 4등급부터
                let path1Strong = path1Result && oldResult.signals.hasStrongSignal

                // Path1 Weak 합산 ≥ 2: acceptable이지만 신호가 있는 경계선 사진 (3등급용)
                // oldResult.signals는 SafeGuard 적용 후 값이므로 별도 SafeGuard 불필요
                let path1WeakLoose = !oldResult.verdict.isLowQuality
                    && oldResult.signals.weakWeightSum >= 2
                    && (aestheticsScore == nil || aestheticsScore! < path2DeepThreshold)

                let light    = path1Strong || path2Light
                let standard = path1Result || path2Std
                let deep     = path1Result || path1WeakLoose || path2Deep

                // 7. 단계별 분류 (추가분만 분리) + 등급별 Path 카운터
                if light {
                    lightCandidates.append(PreviewCandidate(
                        assetID: asset.localIdentifier,
                        asset: asset,
                        stage: .light,
                        score: aestheticsScore,
                        qualityResult: oldResult,
                        safeGuardDebug: safeGuardDebug
                    ))
                    if path1Strong { lightPath1Count += 1 }
                    if path2Light { lightPath2Count += 1 }

                } else if standard {
                    standardCandidates.append(PreviewCandidate(
                        assetID: asset.localIdentifier,
                        asset: asset,
                        stage: .standard,
                        score: aestheticsScore,
                        qualityResult: oldResult,
                        safeGuardDebug: safeGuardDebug
                    ))
                    if path1Result { stdPath1Count += 1 }
                    if path2Std { stdPath2Count += 1 }

                } else if deep {
                    deepCandidates.append(PreviewCandidate(
                        assetID: asset.localIdentifier,
                        asset: asset,
                        stage: .deep,
                        score: aestheticsScore,
                        qualityResult: oldResult,
                        safeGuardDebug: safeGuardDebug
                    ))
                    if path1WeakLoose { deepPath1Count += 1 }
                    if path2Deep { deepPath2Count += 1 }
                }

                // 프로그레스 보고
                let currentFound = lightCandidates.count
                reportProgress(
                    scanned: totalScanned,
                    found: currentFound,
                    date: asset.creationDate ?? Date(),
                    handler: progressHandler
                )

                // 50장 도달 시 배치 내에서도 즉시 중단 (light 기준)
                if lightCandidates.count >= maxFoundCount {
                    break
                }
            }

            currentIndex = endIndex
            await Task.yield()
        }

        // 세션 저장 (마지막 날짜 기록)
        if let lastDate = lastAssetDate {
            if case .byYear(let year, _) = method {
                // byYear: 연도별 세션만 저장 (메인 이어서 정리 세션에 영향 안 줌)
                let canContinueByYear = lightCandidates.count >= maxFoundCount ||
                    (totalScanned >= totalToScan && fetchResult.count > maxScanCount)
                saveByYearSession(year: year, lastDate: lastDate, canContinue: canContinueByYear)
            } else {
                // fromLatest / continueFromLast: 메인 세션만 저장
                saveSession(lastDate: lastDate)
            }
        }

        let elapsed = Date().timeIntervalSince(startTime)

        // 종료 사유 판정 (light 기준 — 그리드 첫 화면 수)
        let endReason: EndReason
        if lightCandidates.count >= maxFoundCount {
            endReason = .maxFound
        } else if totalScanned >= totalToScan && fetchResult.count > maxScanCount {
            endReason = .maxScanned
        } else {
            endReason = .endOfRange
        }

        // 등급별 분포 로그
        let lightDup = lightPath1Count + lightPath2Count - lightCandidates.count
        let stdDup = stdPath1Count + stdPath2Count - standardCandidates.count
        let deepDup = deepPath1Count + deepPath2Count - deepCandidates.count
        Logger.cleanup.notice("""
            [등급 분포] 총 스캔: \(totalScanned)장
            5등급: \(lightCandidates.count)장 (Path1: \(lightPath1Count), Path2: \(lightPath2Count), 중복: \(lightDup))
            4등급: \(standardCandidates.count)장 (Path1: \(stdPath1Count), Path2: \(stdPath2Count), 중복: \(stdDup))
            3등급: \(deepCandidates.count)장 (Path1: \(deepPath1Count), Path2: \(deepPath2Count), 중복: \(deepDup))
            """)

        // 스캔은 최신→오래된 순이지만, 그리드 표시는 오래된→최신 (다른 그리드와 통일)
        let result = PreviewResult(
            lightCandidates: lightCandidates.reversed(),
            standardCandidates: standardCandidates.reversed(),
            deepCandidates: deepCandidates.reversed(),
            scannedCount: totalScanned,
            totalTimeSeconds: elapsed,
            endReason: endReason
        )

        return result
    }

    // MARK: - Fetch

    /// PHFetchResult 생성 (이미지만, 비디오 제외)
    ///
    /// CleanupService.createFetchResult는 private이므로 독립 구현.
    /// ModeComparisonTester 패턴: mediaType == .image 만.
    private func createFetchResult(for method: CleanupMethod) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]

        switch method {
        case .fromLatest:
            // 전체 이미지 (최신부터)
            options.predicate = NSPredicate(
                format: "mediaType == %d",
                PHAssetMediaType.image.rawValue
            )

        case .continueFromLast:
            // 마지막 스캔 날짜 이전부터
            if let lastDate = Self.lastScanDate {
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    lastDate as NSDate
                )
            } else {
                // 이력 없으면 전체
                options.predicate = NSPredicate(
                    format: "mediaType == %d",
                    PHAssetMediaType.image.rawValue
                )
            }

        case .byYear(let year, let continueFrom):
            // 특정 연도만
            let startOfYear = Calendar.current.date(from: DateComponents(year: year))!
            let endOfYear = Calendar.current.date(from: DateComponents(year: year + 1))!

            if let fromDate = continueFrom {
                // 이어서: 해당 연도 + fromDate 이전
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate,
                    fromDate as NSDate
                )
            } else {
                // 처음부터: 해당 연도 전체
                options.predicate = NSPredicate(
                    format: "mediaType == %d AND creationDate >= %@ AND creationDate < %@",
                    PHAssetMediaType.image.rawValue,
                    startOfYear as NSDate,
                    endOfYear as NSDate
                )
            }
        }

        return PHAsset.fetchAssets(with: options)
    }

    // MARK: - Path Evaluation

    /// 경로1 판정: 기존 로직 기반
    ///
    /// - Strong 신호 → 동의 없이 저품질 확정
    /// - Weak/Conditional 신호 → AestheticsScore < 0.2 동의 시 저품질
    ///
    /// AestheticsMetrics 대신 Float?로 받아 iOS availability 문제 회피.
    private func evaluatePath1(
        oldResult: QualityResult,
        aestheticsScore: Float?
    ) -> Bool {
        // 기존 로직이 정상이면 경로1 해당 안 함
        guard oldResult.verdict.isLowQuality else {
            return false
        }

        // Strong 신호 확인 (동의 없이 통과)
        if oldResult.signals.hasStrongSignal {
            return true
        }

        // Weak/Conditional 신호는 AestheticsScore 동의 필요
        guard let score = aestheticsScore else {
            // AestheticsScore 없으면 (iOS 16~17) 기존 판정 유지
            return true
        }

        // AestheticsScore < 0.2 → 동의 → 저품질
        return score < path1AgreeThreshold
    }

    /// 경로2 판정: AestheticsScore 기반 (동기 함수)
    ///
    /// AestheticsMetrics 대신 개별 값(score, isUtility)으로 받아 iOS availability 문제 회피.
    private func evaluatePath2(
        score: Float?,
        isUtility: Bool,
        isTextScreenshot: Bool,
        threshold: Float
    ) -> Bool {
        guard let score = score else {
            return false
        }

        // 유틸리티 이미지(스크린샷 등)는 제외
        if isUtility {
            return false
        }

        // AestheticsScore 임계값 체크
        guard score < threshold else {
            return false
        }

        // 텍스트 스크린샷은 제외
        if isTextScreenshot {
            return false
        }

        return true
    }

    /// 텍스트 스크린샷 감지 (Vision 프레임워크)
    ///
    /// - Parameter image: 분석할 이미지
    /// - Returns: 텍스트 블록 >= 5개이면 true (스크린샷)
    private func detectTextScreenshot(_ image: CGImage) async -> Bool {
        return await withCheckedContinuation { continuation in
            // continuation 중복 resume 방지
            var hasResumed = false

            let request = VNRecognizeTextRequest { request, error in
                guard !hasResumed else { return }
                hasResumed = true

                guard error == nil,
                      let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: false)
                    return
                }

                let textBlockCount = observations.count
                let isTextScreenshot = textBlockCount >= CleanupConstants.textBlockCountThreshold
                continuation.resume(returning: isTextScreenshot)
            }

            request.recognitionLevel = .fast
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

    // MARK: - Progress

    /// 프로그레스 보고
    private func reportProgress(
        scanned: Int,
        found: Int,
        date: Date,
        handler: @escaping (CleanupProgress) -> Void
    ) {
        let progress = CleanupProgress.updated(
            scannedCount: scanned,
            foundCount: found,
            currentDate: date,
            maxFoundCount: maxFoundCount,
            maxScanCount: maxScanCount
        )
        handler(progress)
    }
}

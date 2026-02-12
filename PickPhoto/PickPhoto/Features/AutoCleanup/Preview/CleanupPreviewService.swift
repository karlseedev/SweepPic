//
//  CleanupPreviewService.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  미리보기 전용 분석 서비스
//  - 기존 CleanupService와 독립 (즉시 이동 흐름 유지)
//  - 분석만 수행, 휴지통 이동 없음
//  - 3모드 (완화/기본/강화) 동시 평가하여 단계별 분류
//  - ModeComparisonTester 로직 독립 복사 (#if DEBUG 안이라 참조 불가)
//
//  iOS 분기:
//  - iOS 18+: path1 + path2 → 3단계 결과
//  - iOS 16~17: path1만 → light만, standard/deep 빈 배열
//

import Foundation
import Photos
import Vision
import AppCore

// MARK: - CleanupPreviewService

/// 미리보기 전용 분석 서비스
///
/// 사진을 분석하여 3단계(완화/기본/강화)로 분류합니다.
/// 휴지통 이동 없이 결과만 반환하여 미리보기 그리드에 표시.
final class CleanupPreviewService {

    // MARK: - Constants

    /// 경로1: 동의용 임계값 (Weak/Conditional 신호에만 적용)
    private let path1AgreeThreshold: Float = 0.2

    /// 경로2 임계값 - 완화 (엄격)
    private let path2LightThreshold: Float = -0.3

    /// 경로2 임계값 - 기본
    private let path2StandardThreshold: Float = 0.0

    /// 경로2 임계값 - 강화 (완화)
    private let path2DeepThreshold: Float = 0.2

    /// 최대 검색 수 (CleanupConstants보다 넉넉하게)
    // TODO: 테스트 완료 후 2000으로 복원
    private let maxScanCount: Int = 2000

    /// [임시] 1단계(light) 최대 발견 수 — 테스트용 (0이면 제한 없음)
    private let debugLightLimit: Int = 50

    /// 극단적 비율 임계값 (세로/가로 > 5.0 or < 0.2)
    private let extremeAspectRatioThreshold: CGFloat = 5.0

    // MARK: - Session Storage

    /// 미리보기 세션 키 (기존 CleanupSessionStore와 독립)
    private static let lastScanDateKey = "PreviewSession.lastScanDate"

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
        Log.print("[PreviewService] 세션 저장: \(formatDate(lastDate)) 이전까지")
    }

    /// 세션 초기화
    static func clearSession() {
        UserDefaults.standard.removeObject(forKey: lastScanDateKey)
        Log.print("[PreviewService] 세션 초기화됨")
    }

    /// 날짜 포맷 (로그용)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy년 M월"
        return formatter.string(from: date)
    }

    // MARK: - Cancel

    /// 분석 취소
    func cancel() {
        lock.lock()
        isCancelled = true
        lock.unlock()
        Log.print("[PreviewService] 취소 요청됨")
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

        Log.print("[PreviewService] 분석 시작: \(method)")

        // PHFetchResult 생성 (이미지만)
        let fetchResult = createFetchResult(for: method)
        let totalToScan = min(fetchResult.count, maxScanCount)

        Log.print("[PreviewService] 총 \(fetchResult.count)장 중 \(totalToScan)장 검색 예정")

        // 결과 수집
        var lightCandidates: [PreviewCandidate] = []
        var standardCandidates: [PreviewCandidate] = []
        var deepCandidates: [PreviewCandidate] = []
        var totalScanned = 0
        var lastAssetDate: Date?

        // 배치 처리
        let batchSize = CleanupConstants.batchSize
        var currentIndex = 0

        while currentIndex < totalToScan {
            // 취소 체크
            if cancelled {
                Log.print("[PreviewService] 취소됨 (scanned: \(totalScanned))")
                throw CancellationError()
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
                    Log.print("[PreviewService] 취소됨 (scanned: \(totalScanned))")
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
                        found: lightCandidates.count + standardCandidates.count + deepCandidates.count,
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

                if #available(iOS 18.0, *) {
                    // 이미지 로드
                    if let image = try? await CleanupImageLoader.shared.loadImage(for: asset) {
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

                // 5. 3모드 계산 (모두 OR)
                let light    = path1Result || path2Light
                let standard = path1Result || path2Std
                let deep     = path1Result || path2Deep

                // 6. 단계별 분류 (추가분만 분리)
                if light {
                    // 1단계(완화)에서 잡힘 → light
                    lightCandidates.append(PreviewCandidate(
                        assetID: asset.localIdentifier,
                        asset: asset,
                        stage: .light,
                        score: aestheticsScore
                    ))
                } else if standard {
                    // 2단계(기본)에서 추가로 잡힘 → standard 추가분
                    standardCandidates.append(PreviewCandidate(
                        assetID: asset.localIdentifier,
                        asset: asset,
                        stage: .standard,
                        score: aestheticsScore
                    ))
                } else if deep {
                    // 3단계(강화)에서 추가로 잡힘 → deep 추가분
                    deepCandidates.append(PreviewCandidate(
                        assetID: asset.localIdentifier,
                        asset: asset,
                        stage: .deep,
                        score: aestheticsScore
                    ))
                }

                // 프로그레스 보고
                reportProgress(
                    scanned: totalScanned,
                    found: lightCandidates.count + standardCandidates.count + deepCandidates.count,
                    date: asset.creationDate ?? Date(),
                    handler: progressHandler
                )

                // [임시] 1단계 발견 수 제한 — 테스트용
                if debugLightLimit > 0 && lightCandidates.count >= debugLightLimit {
                    Log.print("[PreviewService] debugLightLimit(\(debugLightLimit)) 도달, 스캔 중단")
                    break
                }
            }

            // [임시] 외부 루프도 중단
            if debugLightLimit > 0 && lightCandidates.count >= debugLightLimit {
                break
            }

            currentIndex = endIndex
            await Task.yield()
        }

        // 세션 저장 (마지막 날짜 기록)
        if let lastDate = lastAssetDate {
            saveSession(lastDate: lastDate)
        }

        let elapsed = Date().timeIntervalSince(startTime)

        let result = PreviewResult(
            lightCandidates: lightCandidates,
            standardCandidates: standardCandidates,
            deepCandidates: deepCandidates,
            scannedCount: totalScanned,
            totalTimeSeconds: elapsed
        )

        Log.print("[PreviewService] 완료:")
        Log.print("[PreviewService] - 검색: \(totalScanned)장, 소요: \(String(format: "%.1f", elapsed))초")
        Log.print("[PreviewService] - light: \(result.lightCount)장")
        Log.print("[PreviewService] - standard 추가분: \(result.standardCount)장")
        Log.print("[PreviewService] - deep 추가분: \(result.deepCount)장")
        Log.print("[PreviewService] - 전체: \(result.totalCount)장")

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
            currentDate: date
        )
        handler(progress)
    }
}

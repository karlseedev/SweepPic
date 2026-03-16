//
//  SimilarityAnalysisQueue.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  유사 사진 분석 작업을 관리하는 큐입니다.
//  FIFO 순서로 분석 요청을 처리하고, 동시 분석 수를 제한합니다.
//
//  Concurrency:
//  - 기본: 최대 5개 동시 분석
//  - 과열 시: 최대 2개 동시 분석
//
//  Cancellation:
//  - grid 소스: 스크롤 재개 시 취소 가능
//  - viewer 소스: 취소 불가
//

import Foundation
import Photos
import Vision  // VNFeaturePrintObservation 등 (FaceDetector는 제거됨, YuNet 960 직접 감지)
import UIKit
import AppCore
import OSLog

// MARK: - Notification Extension

extension Notification.Name {
    /// 유사 사진 분석 완료 알림
    ///
    /// userInfo 구조:
    /// - "analysisRange": ClosedRange<Int> - 분석 범위
    /// - "groupIDs": [String] - 유효 그룹 ID 배열 (빈 배열 가능)
    /// - "analyzedAssetIDs": [String] - 분석된 모든 사진 ID
    static let similarPhotoAnalysisComplete = Notification.Name("similarPhotoAnalysisComplete")
}

/// 유사 사진 분석 큐
///
/// 그리드 스크롤 또는 뷰어에서 발생하는 분석 요청을 FIFO 순서로 처리합니다.
/// 디바이스 상태에 따라 동시 분석 수를 조절합니다.
final class SimilarityAnalysisQueue {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SimilarityAnalysisQueue()

    // MARK: - Dependencies

    /// 이미지 로더
    private let imageLoader: SimilarityImageLoader

    /// 유사도 분석기
    private let analyzer: SimilarityAnalyzer

    /// 결과 캐시
    private let cache: SimilarityCache

    // FaceDetector(Vision) 제거됨 — YuNet 960이 직접 감지

    // MARK: - Queue State

    /// 분석 요청 큐 (FIFO)
    private var requestQueue: [AnalysisRequest] = []

    /// 현재 진행 중인 요청 ID
    private var activeRequests: Set<UUID> = []

    /// 동시성 제한 세마포어
    private var semaphore: AsyncSemaphore

    /// 현재 과열 상태 여부
    private var isThermalThrottled: Bool = false

    /// 현재 분석 작업 (취소용)
    private var currentTasks: [UUID: Task<Void, Never>] = [:]

    /// 동기화를 위한 직렬 큐
    private let serialQueue = DispatchQueue(label: "com.pickphoto.similarity.queue")

    // MARK: - Performance Statistics

    /// 성능 측정 데이터 (다회 측정용)
    private struct PerformanceStats {
        var measurementCount: Int = 0
        var fpTimes: [Double] = []           // FP 생성 시간 (ms)
        var faceTimes: [Double] = []         // 얼굴 감지+매칭 시간 (ms)
        var totalTimes: [Double] = []        // 총 시간 (ms)
        var memoryDeltas: [Double] = []      // 메모리 변화 (MB)
        var photoCountSum: Int = 0           // 누적 사진 수
        var faceCountSum: Int = 0            // 누적 얼굴 수

        /// 통계 계산 헬퍼
        private func stats(_ values: [Double]) -> (avg: Double, min: Double, max: Double, stdDev: Double) {
            guard !values.isEmpty else { return (0, 0, 0, 0) }
            let avg = values.reduce(0, +) / Double(values.count)
            let minVal = values.min() ?? 0
            let maxVal = values.max() ?? 0
            let variance = values.reduce(0) { $0 + pow($1 - avg, 2) } / Double(values.count)
            let stdDev = sqrt(variance)
            return (avg, minVal, maxVal, stdDev)
        }

        /// 통계 리포트 출력
        func printReport() {
            guard measurementCount > 0 else { return }

            let fp = stats(fpTimes)
            let face = stats(faceTimes)
            let total = stats(totalTimes)
            let mem = stats(memoryDeltas)

            let avgPhotos = Double(photoCountSum) / Double(measurementCount)
            let avgFaces = Double(faceCountSum) / Double(measurementCount)

            #if DEBUG
            print("""
            ╔══════════════════════════════════════════════════════╗
            ║       PERFORMANCE STATISTICS (Vision) - \(measurementCount) runs       ║
            ╠══════════════════════════════════════════════════════╣
            ║  Avg Photos: \(String(format: "%.1f", avgPhotos)), Avg Faces: \(String(format: "%.1f", avgFaces))
            ╠══════════════════════════════════════════════════════╣
            ║  FP Generation Time:
            ║    avg: \(String(format: "%.2f", fp.avg))ms, min: \(String(format: "%.2f", fp.min))ms, max: \(String(format: "%.2f", fp.max))ms
            ║    stdDev: \(String(format: "%.2f", fp.stdDev))ms
            ╠══════════════════════════════════════════════════════╣
            ║  Face Detect+Match Time:
            ║    avg: \(String(format: "%.2f", face.avg))ms, min: \(String(format: "%.2f", face.min))ms, max: \(String(format: "%.2f", face.max))ms
            ║    stdDev: \(String(format: "%.2f", face.stdDev))ms
            ╠══════════════════════════════════════════════════════╣
            ║  Total Time:
            ║    avg: \(String(format: "%.2f", total.avg))ms, min: \(String(format: "%.2f", total.min))ms, max: \(String(format: "%.2f", total.max))ms
            ║    stdDev: \(String(format: "%.2f", total.stdDev))ms
            ╠══════════════════════════════════════════════════════╣
            ║  Memory Delta:
            ║    avg: \(String(format: "%+.1f", mem.avg))MB, min: \(String(format: "%+.1f", mem.min))MB, max: \(String(format: "%+.1f", mem.max))MB
            ╚══════════════════════════════════════════════════════╝
            """)
            #endif
        }
    }

    /// 성능 통계 저장소
    private var performanceStats = PerformanceStats()

    /// 통계 동기화 큐
    private let statsQueue = DispatchQueue(label: "com.pickphoto.similarity.stats")

    // MARK: - Initialization

    /// 분석 큐를 초기화합니다.
    init(
        imageLoader: SimilarityImageLoader = .shared,
        analyzer: SimilarityAnalyzer = .shared,
        cache: SimilarityCache = .shared
    ) {
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.cache = cache
        self.semaphore = AsyncSemaphore(value: SimilarityConstants.maxConcurrentAnalysis)

        setupThermalStateObserver()
        setupBackgroundObserver()
    }

    // MARK: - Public Methods

    /// 분석 요청을 큐에 추가합니다.
    ///
    /// - Parameter request: 분석 요청
    func enqueue(_ request: AnalysisRequest) {
        serialQueue.sync {
            requestQueue.append(request)
        }
    }

    /// 분석 Task를 등록합니다.
    ///
    /// cancel(source:) 호출 시 등록된 Task를 취소할 수 있도록 합니다.
    /// grid 소스만 등록됩니다 (viewer 소스는 취소 불가이므로 등록 불필요).
    ///
    /// - Parameters:
    ///   - task: 등록할 Task
    ///   - id: Task 식별용 UUID
    ///   - source: 요청 소스 (.grid만 등록)
    func registerTask(_ task: Task<Void, Never>, id: UUID, source: AnalysisSource) {
        guard source == .grid else { return }
        serialQueue.sync {
            currentTasks[id] = task
            activeRequests.insert(id)
        }
    }

    /// 분석 Task 등록을 해제합니다.
    ///
    /// Task 완료 또는 취소 시 defer에서 호출합니다.
    ///
    /// - Parameter id: 해제할 Task의 UUID
    func unregisterTask(id: UUID) {
        serialQueue.sync {
            currentTasks.removeValue(forKey: id)
            activeRequests.remove(id)
        }
    }

    /// 특정 소스의 분석 요청을 취소합니다.
    ///
    /// - Parameter source: 취소할 소스 (.grid만 취소 가능)
    func cancel(source: AnalysisSource) {
        // viewer 소스는 취소 불가
        guard source == .grid else { return }

        // [Analytics] 이벤트 5-1: 유사 분석 취소
        AnalyticsService.shared.countSimilarAnalysisCancelled()

        serialQueue.sync {
            // 큐에서 해당 소스 요청 제거
            requestQueue.removeAll { $0.source == source }

            // 진행 중인 작업 취소
            for (requestID, task) in currentTasks {
                if activeRequests.contains(requestID) {
                    task.cancel()
                    Logger.similarPhoto.debug("Cancelled task: \(requestID)")
                }
            }
        }
    }

    /// 분석 범위에 대한 그룹 형성을 수행합니다.
    ///
    /// research.md §10.5, §10.10 참조
    ///
    /// - Parameters:
    ///   - range: 분석할 사진 인덱스 범위
    ///   - source: 요청 소스 (.grid 또는 .viewer)
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: 생성된 유효 그룹 ID 배열
    /// 성능 측정 활성화 플래그
    private let performanceLoggingEnabled = true

    func formGroupsForRange(
        _ range: ClosedRange<Int>,
        source: AnalysisSource,
        fetchResult: PHFetchResult<PHAsset>
    ) async -> [String] {
        // 성능 측정 시작
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsageMB()

        // T014.1: 분석 준비
        let photos = fetchPhotos(in: range, fetchResult: fetchResult)

        guard photos.count >= SimilarityConstants.minGroupSize else {
            postAnalysisComplete(range: range, groupIDs: [], analyzedAssetIDs: [])
            return []
        }

        let assetIDs = photos.map { $0.localIdentifier }

        // 기존 그룹 정리 (재분석 시)
        await cache.prepareForReanalysis(assetIDs: Set(assetIDs))

        // T014.2: Feature Print 병렬 생성 + Vision 얼굴 유무 체크 (배치 처리)
        let fpStartTime = CFAbsoluteTimeGetCurrent()
        let (featurePrints, hasFaces) = await generateFeaturePrints(for: photos)
        let fpTime = CFAbsoluteTimeGetCurrent() - fpStartTime

        // 취소 체크: FP 생성 후 (캐시/알림 스킵)
        guard !Task.isCancelled else {
            Logger.similarPhoto.debug("Cancelled after FP generation - skipping cache/notification")
            return []
        }

        // T014.3 & T014.4: 인접 거리 계산 및 그룹 분리
        let rawGroups = analyzer.formGroups(
            featurePrints: featurePrints,
            photoIDs: assetIDs,
            threshold: SimilarityConstants.similarityThreshold
        )

        // 유효 그룹이 없으면 종료
        if rawGroups.isEmpty {
            // 분석된 사진들 상태 업데이트
            for assetID in assetIDs {
                await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
            }
            postAnalysisComplete(range: range, groupIDs: [], analyzedAssetIDs: assetIDs)
            return []
        }

        // ── 테두리 조기 표시: 얼굴 있는 그룹만 예비 테두리 표시 ──
        // Vision 얼굴 감지 결과(hasFaces)를 기반으로 얼굴 포함 그룹만 필터링
        // 사물 그룹은 .analyzing 상태 유지 → YuNet 최종 분석에서 판단
        // Vision이 못 잡은 작은 얼굴은 최종 분석 후 테두리 표시 (누락 없음, 지연만)
        let facePresenceMap = Dictionary(uniqueKeysWithValues: zip(assetIDs, hasFaces))
        let faceGroups = rawGroups.filter { groupIDs in
            groupIDs.contains { facePresenceMap[$0] == true }
        }
        let preliminaryAssetIDs = Set(faceGroups.flatMap { $0 })

        // 얼굴 그룹 멤버: 예비 테두리 표시
        for assetID in preliminaryAssetIDs {
            await cache.setState(.analyzed(inGroup: true, groupID: "preliminary"), for: assetID)
        }
        // 그룹에 속하지 않은 사진: 분석 완료 (그룹 없음)
        let allGroupedAssetIDs = Set(rawGroups.flatMap { $0 })
        for assetID in assetIDs where !allGroupedAssetIDs.contains(assetID) {
            await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
        }
        // 사물 그룹(얼굴 없음): .analyzing 상태 유지 → YuNet에서 최종 판단
        // 알림 발송: 그리드가 비-그룹 사진 상태도 반영하도록
        postAnalysisComplete(
            range: range,
            groupIDs: faceGroups.isEmpty ? [] : ["preliminary"],
            analyzedAssetIDs: assetIDs
        )

        // 취소 체크: 조기 표시 후
        guard !Task.isCancelled else {
            Logger.similarPhoto.debug("Cancelled after preliminary borders - keeping preliminary state")
            return []
        }

        // T014.5 & T014.6: 얼굴 감지 + 유효 슬롯 계산
        var validGroupIDs: [String] = []

        // 성능 측정: 얼굴 감지 + 매칭 시간
        let faceStartTime = CFAbsoluteTimeGetCurrent()
        var totalFaceCount = 0

        for groupAssetIDs in rawGroups {
            // 취소 체크: rawGroups 루프 (캐시/알림 스킵)
            guard !Task.isCancelled else {
                Logger.similarPhoto.debug("Cancelled during group processing - skipping cache/notification")
                return []
            }

            // 그룹 내 사진 가져오기
            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }

            // 그룹 단위로 일관된 personIndex 할당 (YuNet 960 직접 감지 + SFace 임베딩)
            let photoFacesMap = await assignPersonIndicesForGroup(
                assetIDs: groupAssetIDs,
                photos: groupPhotos
            )

            // 유효 슬롯 계산: 같은 personIndex가 2장 이상의 사진에서 나타나야 함
            // 주의: 기존 로직은 "같은 personIndex를 가진 얼굴 총 개수"였으나,
            //       이제는 "같은 personIndex가 나타나는 사진 수"로 변경
            var slotPhotoCount: [Int: Set<String>] = [:]
            for (assetID, faces) in photoFacesMap {
                for face in faces {
                    slotPhotoCount[face.personIndex, default: []].insert(assetID)
                }
            }

            let validSlots = Set(slotPhotoCount.filter {
                $0.value.count >= SimilarityConstants.minPhotosPerSlot
            }.keys)

            // ========== 유효 슬롯 얼굴이 있는 사진만 그룹에 포함 (prd9algorithm.md §3.7) ==========
            // 유효 슬롯에 해당하는 얼굴이 있는 사진만 그룹 멤버로 인정
            let validMembers = groupAssetIDs.filter { assetID in
                guard let faces = photoFacesMap[assetID] else { return false }
                return faces.contains { validSlots.contains($0.personIndex) }
            }

            // 그룹 내 탈락 사진 상태 업데이트 (얼굴 없음 또는 유효 슬롯 미충족)
            let excludedFromGroup = Set(groupAssetIDs).subtracting(validMembers)
            for assetID in excludedFromGroup {
                await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
                // 탈락 사진의 얼굴 데이터도 캐시에 저장 (뷰어에서 활용 가능)
                if let faces = photoFacesMap[assetID] {
                    await cache.setFaces(faces, for: assetID)
                }
            }
            // ==============================================================================

            // T014.7: 캐시 저장 요청 (T010 호출)
            // validMembers 전달 (유효 슬롯 얼굴 보유 사진만)
            // 참고: addGroupIfValid 내부에서 조건 미충족 시 members를 inGroup:false로 정리함
            if let groupID = await cache.addGroupIfValid(
                members: validMembers,
                validSlots: validSlots,
                photoFaces: photoFacesMap
            ) {
                validGroupIDs.append(groupID)
            }

            // 성능 측정: 얼굴 수 누적
            totalFaceCount += photoFacesMap.values.reduce(0) { $0 + $1.count }
        }

        // 성능 측정: 얼굴 감지 + 매칭 시간
        let faceTime = CFAbsoluteTimeGetCurrent() - faceStartTime

        // LRU eviction
        await cache.evictIfNeeded()

        // 그룹에 속하지 않은 사진들 상태 업데이트
        let groupedAssetIDs = Set(rawGroups.flatMap { $0 })
        for assetID in assetIDs where !groupedAssetIDs.contains(assetID) {
            await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
        }

        // 성능 측정 로그 출력 및 통계 누적
        if performanceLoggingEnabled {
            let totalTime = CFAbsoluteTimeGetCurrent() - totalStartTime
            let endMemory = getMemoryUsageMB()
            let memoryDelta = endMemory - startMemory

            // ms 단위로 변환
            let fpTimeMs = fpTime * 1000
            let faceTimeMs = faceTime * 1000
            let totalTimeMs = totalTime * 1000

            // 통계 누적 (thread-safe)
            statsQueue.sync {
                performanceStats.measurementCount += 1
                performanceStats.fpTimes.append(fpTimeMs)
                performanceStats.faceTimes.append(faceTimeMs)
                performanceStats.totalTimes.append(totalTimeMs)
                performanceStats.memoryDeltas.append(memoryDelta)
                performanceStats.photoCountSum += photos.count
                performanceStats.faceCountSum += totalFaceCount
            }

            // 개별 측정 결과 출력 (비활성화)
//            print("""
//            ========== PERFORMANCE METRICS (Vision) [#\(performanceStats.measurementCount)] ==========
//            Photos: \(photos.count), Faces: \(totalFaceCount), Groups: \(validGroupIDs.count)
//            --------------------------------------------------
//            FP Generation Time: \(String(format: "%.2f", fpTimeMs))ms (\(String(format: "%.1f", fpTimeMs / Double(photos.count)))ms/photo)
//            Face Detect+Match Time: \(String(format: "%.2f", faceTimeMs))ms (\(String(format: "%.1f", faceTimeMs / Double(max(1, totalFaceCount))))ms/face)
//            Total Time: \(String(format: "%.2f", totalTimeMs))ms
//            --------------------------------------------------
//            Memory Start: \(String(format: "%.1f", startMemory))MB
//            Memory End: \(String(format: "%.1f", endMemory))MB
//            Memory Delta: \(String(format: "%+.1f", memoryDelta))MB
//            Thermal State: \(thermalStateString(thermalState))
//            ==================================================
//            """)

            // 3회 이상 측정되면 통계 리포트 출력 (비활성화)
            // if performanceStats.measurementCount >= 3 {
            //     statsQueue.sync {
            //         performanceStats.printReport()
            //     }
            // }
        }

        // [Analytics] 이벤트 5-1: 유사 분석 완료
        let analysisDuration = CFAbsoluteTimeGetCurrent() - totalStartTime
        AnalyticsService.shared.countSimilarAnalysisCompleted(groups: validGroupIDs.count, duration: analysisDuration)

        // T014.8: UI 알림 발송
        postAnalysisComplete(range: range, groupIDs: validGroupIDs, analyzedAssetIDs: assetIDs)

        return validGroupIDs
    }

    /// 현재 메모리 사용량 (MB)
    private func getMemoryUsageMB() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? Double(info.resident_size) / 1024 / 1024 : 0
    }

    /// Thermal 상태 문자열
    private func thermalStateString(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    // MARK: - Private Methods - Feature Print Generation

    /// 사진들의 Feature Print + 얼굴 유무를 병렬로 생성합니다.
    ///
    /// Vision의 VNGenerateImageFeaturePrintRequest와 VNDetectFaceRectanglesRequest를
    /// 같은 VNImageRequestHandler에서 배치 실행하여 추가 비용을 최소화합니다.
    /// 얼굴 유무(hasFaces)는 예비 테두리 표시 판단에만 사용됩니다.
    ///
    /// - Parameter photos: 분석할 PHAsset 배열
    /// - Returns: (featurePrints: FP 배열, hasFaces: 얼굴 유무 배열)
    private func generateFeaturePrints(for photos: [PHAsset]) async -> (featurePrints: [VNFeaturePrintObservation?], hasFaces: [Bool]) {
        let currentLimit = isThermalThrottled
            ? SimilarityConstants.maxConcurrentAnalysisThermal
            : SimilarityConstants.maxConcurrentAnalysis

        let semaphore = AsyncSemaphore(value: currentLimit)

        // withThrowingTaskGroup 사용: child task에서 CancellationError throw 가능
        // 외부 시그니처는 non-throws 유지 (CancellationError를 내부에서 흡수)
        do {
            return try await withThrowingTaskGroup(of: (Int, VNFeaturePrintObservation?, Bool).self) { group in
                for (index, photo) in photos.enumerated() {
                    group.addTask {
                        // child task 내부에서도 취소 체크
                        try Task.checkCancellation()

                        await semaphore.wait()
                        defer { semaphore.signal() }

                        // 세마포어 획득 후 재확인
                        try Task.checkCancellation()

                        do {
                            let image = try await self.imageLoader.loadImage(for: photo)
                            // 배치 처리: FeaturePrint + 얼굴 유무를 같은 핸들러에서 실행
                            let (fp, hasFace) = try await self.analyzer.generateFeaturePrintWithFaceCheck(for: image)
                            return (index, fp, hasFace)
                        } catch is CancellationError {
                            throw CancellationError()  // 상위로 전파
                        } catch SimilarityImageLoadError.cancelled {
                            throw CancellationError()  // 취소를 CancellationError로 변환
                        } catch {
                            // 다른 에러만 nil/false로 처리
                            return (index, nil, false)
                        }
                    }
                }

                // 결과 수집
                var fpResults = [VNFeaturePrintObservation?](repeating: nil, count: photos.count)
                var faceResults = [Bool](repeating: false, count: photos.count)
                for try await (index, fp, hasFace) in group {
                    // 취소 감지 시 나머지 작업 취소
                    if Task.isCancelled {
                        group.cancelAll()
                        break
                    }
                    fpResults[index] = fp
                    faceResults[index] = hasFace
                }
                return (fpResults, faceResults)
            }
        } catch is CancellationError {
            // 취소 시 부분 결과 전부 버리고 빈 배열 반환 (캐시 오염 방지)
            Logger.similarPhoto.debug("generateFeaturePrints cancelled - returning empty")
            return ([], [])
        } catch {
            Logger.similarPhoto.error("generateFeaturePrints error: \(error)")
            return ([], [])
        }
    }

    // MARK: - Private Methods - Photo Fetching

    /// 범위 내 사진을 가져옵니다.
    ///
    /// 삭제대기함에 있는 사진은 분석 대상에서 제외합니다. (FR-033, FR-037)
    /// 삭제된 사진이 그룹에 포함되면 3장 미만 무효화 로직이 제대로 동작하지 않기 때문입니다.
    ///
    /// - Parameters:
    ///   - range: 인덱스 범위
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: PHAsset 배열 (삭제대기함 사진 제외)
    private func fetchPhotos(in range: ClosedRange<Int>, fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        var photos: [PHAsset] = []
        let clampedRange = max(0, range.lowerBound)...min(fetchResult.count - 1, range.upperBound)

        for i in clampedRange {
            let asset = fetchResult.object(at: i)
            // 삭제대기함에 있는 사진은 분석 대상에서 제외
            if !trashedIDs.contains(asset.localIdentifier) {
                photos.append(asset)
            }
        }

        return photos
    }

    // MARK: - Private Methods - Face Processing

    /// 동적 인물 슬롯 (기준 임베딩 + 메타데이터)
    ///
    /// Keep Best 정책: 더 높은 norm의 임베딩으로 갱신
    /// 위치 갱신 정책: 매칭 시 최근 위치로 갱신 (저품질 경로 정확도 향상)
    private struct PersonSlot {
        let id: Int                // 슬롯 ID (1-based)
        var embedding: [Float]     // 128차원 SFace 임베딩
        var norm: Float            // 임베딩 norm (품질 지표)
        var center: CGPoint        // 최근 매칭 위치 (갱신됨)
        var boundingBox: CGRect    // 최근 매칭 바운딩박스 (갱신됨)
    }

    /// 임베딩 품질 임계값 (norm 기준)
    /// norm < 7인 얼굴은 저품질로 판정하여 신규 슬롯 생성 금지
    private let minEmbeddingNorm: Float = 7.0

    /// 매칭 후보 (전역 정렬용)
    private struct MatchCandidate {
        let faceIdx: Int
        let slotID: Int
        let cost: Float           // Dist_fp
        let posDistNorm: CGFloat  // Dist_pos / √2
        let boundingBox: CGRect
        let center: CGPoint       // 얼굴 중심 (슬롯 위치 갱신용)
        let embedding: [Float]    // Keep Best용 임베딩
        let norm: Float           // 얼굴 임베딩 품질
        let slotNorm: Float       // 슬롯 임베딩 품질 (고품질 확장 판정용)
    }

    /// 그룹 단위로 일관된 인물 번호를 부여합니다.
    ///
    /// YuNet 960으로 얼굴 감지 + SFace 임베딩 생성 후,
    /// 전역 후보 정렬 기반 근사 매칭 알고리즘을 사용합니다.
    /// - 동적 인물 풀: 첫 사진에서 부팅, 이후 신규 인물 등록
    /// - Grey Zone 전략: 확신/모호/거절 구간으로 나누어 위치 조건 적용
    /// - 캐시 미저장 정책: FP 실패 또는 매칭 실패 얼굴은 CachedFace에 저장하지 않음
    ///
    /// - Parameters:
    ///   - assetIDs: 그룹 멤버 순서 (분석 순서)
    ///   - photos: PHAsset 배열 (이미지 로딩용)
    /// - Returns: 일관된 personIndex가 부여된 CachedFace 맵
    private func assignPersonIndicesForGroup(
        assetIDs: [String],
        photos: [PHAsset]
    ) async -> [String: [CachedFace]] {

        // assetID → PHAsset 매핑
        let photoMap = Dictionary(uniqueKeysWithValues: photos.map { ($0.localIdentifier, $0) })

        // 결과 저장
        var result: [String: [CachedFace]] = [:]

        // 동적 인물 풀 (사진 처리하며 성장)
        var activeSlots: [PersonSlot] = []
        var nextSlotID: Int = 1

        // 상수
        let greyZoneThreshold = SimilarityConstants.greyZoneThreshold
        let rejectThreshold = SimilarityConstants.personMatchThreshold
        let greyZonePosLimit = SimilarityConstants.greyZonePositionLimit
        let maxSlots = SimilarityConstants.maxPersonSlots
        let sqrt2: CGFloat = sqrt(2.0)

        // 고품질 확장: 양쪽 norm 모두 높으면 거절 임계값 완화
        let highQualityNormLimit: Float = 8.0       // 양쪽 norm ≥ 8.0이면 고품질 쌍
        let extendedRejectThreshold: Float = 0.75   // 고품질 쌍의 완화된 거절 임계값

        // 각 사진 처리
        for assetID in assetIDs {
            // 취소 체크: 사진 처리 루프
            guard !Task.isCancelled else {
                Logger.similarPhoto.debug("Cancelled during person assignment - skipping cache/notification")
                return result
            }

            let shortID = String(assetID.prefix(8))
            _ = shortID  // 주석 처리된 디버그 로그에서 사용 — 로그 복원 시 제거

            // 이미지 로드 (인물 매칭용 고해상도)
            var cgImage: CGImage? = nil
            if let photo = photoMap[assetID] {
                cgImage = try? await imageLoader.loadImage(
                    for: photo,
                    maxSize: SimilarityConstants.personMatchImageMaxSize
                )
            }

            // === Step 1: YuNet으로 얼굴 감지 + SFace 임베딩 생성 ===
            var faceEmbeddings: [Int: [Float]] = [:]
            var faceData: [Int: (center: CGPoint, boundingBox: CGRect)] = [:]

            guard let image = cgImage,
                  let yunet = YuNetFaceDetector.shared,
                  let sface = SFaceRecognizer.shared else {
                // 모델 또는 이미지 로드 실패 시 빈 결과 (얼굴 없는 것으로 처리)
                result[assetID] = []
                continue
            }

            // YuNet으로 얼굴 감지 (landmark 포함)
            let yunetDetections: [YuNetDetection]
            do {
                yunetDetections = try yunet.detect(in: image)
            } catch {
                result[assetID] = []
                continue
            }

            for (faceIdx, detection) in yunetDetections.enumerated() {
                // normalized 좌표로 변환 (Vision 좌표계: 원점이 왼쪽 아래)
                // YuNet은 일반 이미지 좌표계 (원점이 왼쪽 위)이므로 y좌표 뒤집기 필요
                let imageWidth = CGFloat(image.width)
                let imageHeight = CGFloat(image.height)
                let normalizedBox = CGRect(
                    x: detection.boundingBox.origin.x / imageWidth,
                    y: 1.0 - (detection.boundingBox.origin.y + detection.boundingBox.size.height) / imageHeight,
                    width: detection.boundingBox.size.width / imageWidth,
                    height: detection.boundingBox.size.height / imageHeight
                )
                let center = CGPoint(x: normalizedBox.midX, y: normalizedBox.midY)
                faceData[faceIdx] = (center: center, boundingBox: normalizedBox)

                // FaceAligner로 정렬 (픽셀 좌표 landmark 사용)
                guard let alignedFace = try? FaceAligner.shared.align(
                    image: image,
                    landmarks: detection.landmarks
                ) else {
                    continue
                }

                // SFace로 임베딩 추출
                do {
                    let embedding = try sface.extractEmbedding(from: alignedFace)
                    faceEmbeddings[faceIdx] = embedding
                } catch {
                    // [Analytics] 얼굴 임베딩 추출 실패
                    AnalyticsService.shared.countError(.embedding as AnalyticsError.Face)
                    continue
                }
            }

            // === Step 2: 부팅 (ActiveSlots 비어있을 때) ===
            // 부팅 시에는 저품질 포함 모든 얼굴로 슬롯 생성 (모든 인물이 슬롯 보유)
            if activeSlots.isEmpty {
                // 위치 정렬된 순서로 슬롯 생성 (YuNet 결과 기반)
                let sortedIndices = faceData.keys.sorted { idx1, idx2 in
                    guard let data1 = faceData[idx1], let data2 = faceData[idx2] else { return false }
                    let xDiff = abs(data1.boundingBox.origin.x - data2.boundingBox.origin.x)
                    if xDiff > 0.05 {
                        return data1.boundingBox.origin.x < data2.boundingBox.origin.x
                    } else {
                        return data1.boundingBox.origin.y > data2.boundingBox.origin.y
                    }
                }

                for faceIdx in sortedIndices {
                    guard activeSlots.count < maxSlots else { break }
                    guard let embedding = faceEmbeddings[faceIdx] else { continue }
                    guard let data = faceData[faceIdx] else { continue }

                    // norm 계산
                    let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })

                    let slot = PersonSlot(
                        id: nextSlotID,
                        embedding: embedding,
                        norm: norm,
                        center: data.center,
                        boundingBox: data.boundingBox
                    )
                    activeSlots.append(slot)
                    nextSlotID += 1
                }

                // 부팅 결과 저장
                var cachedFaces: [CachedFace] = []
                for slot in activeSlots {
                    cachedFaces.append(CachedFace(
                        boundingBox: slot.boundingBox,
                        personIndex: slot.id,
                        isValidSlot: false
                    ))
                }
                result[assetID] = cachedFaces
                continue
            }

            // === Step 3: 비용 산출 (코사인 유사도 → 거리 변환) ===
            var allCandidates: [MatchCandidate] = []

            // 각 얼굴의 norm 미리 계산 (결정성 보장: 키 정렬)
            var faceNorms: [Int: Float] = [:]
            for faceIdx in faceEmbeddings.keys.sorted() {
                guard let embedding = faceEmbeddings[faceIdx] else { continue }
                faceNorms[faceIdx] = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
            }

            for faceIdx in faceEmbeddings.keys.sorted() {
                guard let faceEmbedding = faceEmbeddings[faceIdx],
                      let data = faceData[faceIdx] else { continue }
                let faceNorm = faceNorms[faceIdx] ?? 0

                // 모든 슬롯과 비용 계산 (코사인 유사도를 거리로 변환: cost = 1 - similarity)
                var slotCosts: [(slot: PersonSlot, cost: Float, posDist: CGFloat)] = []

                for slot in activeSlots {
                    let similarity = sface.cosineSimilarity(faceEmbedding, slot.embedding)
                    let cost = 1.0 - similarity  // 유사도를 거리로 변환 (낮을수록 동일인)
                    let posDist = hypot(data.center.x - slot.center.x, data.center.y - slot.center.y)
                    slotCosts.append((slot: slot, cost: cost, posDist: posDist))
                }

                // Top-K 필터링: 슬롯 수 > 5개면 상위 3개만 (근사 최적화)
                // 고품질: cost 기준, 저품질: 위치 기준 (GPT 리뷰 반영)
                let candidates: ArraySlice<(slot: PersonSlot, cost: Float, posDist: CGFloat)>
                let isLowQuality = faceNorm < minEmbeddingNorm

                if activeSlots.count > 5 {
                    if isLowQuality {
                        // 저품질: 위치 기준 Top-K (가장 가까운 슬롯이 후보에 포함되도록)
                        candidates = slotCosts.sorted { $0.posDist < $1.posDist }.prefix(3)
                    } else {
                        // 고품질: cost 기준 Top-K
                        candidates = slotCosts.sorted { $0.cost < $1.cost }.prefix(3)
                    }
                } else {
                    candidates = slotCosts[...]
                }

                for item in candidates {
                    let posDistNorm = min(item.posDist / sqrt2, 1.0)
                    allCandidates.append(MatchCandidate(
                        faceIdx: faceIdx,
                        slotID: item.slot.id,
                        cost: item.cost,
                        posDistNorm: posDistNorm,
                        boundingBox: data.boundingBox,
                        center: data.center,
                        embedding: faceEmbedding,
                        norm: faceNorm,
                        slotNorm: item.slot.norm
                    ))
                }
            }

            // === Step 4: 전역 정렬 (Cost 오름차순, tie-breaker: faceIdx, slotID) ===
            // 결정성 보장: cost 동일 시 faceIdx → slotID 순으로 정렬
            allCandidates.sort {
                if $0.cost != $1.cost { return $0.cost < $1.cost }
                if $0.faceIdx != $1.faceIdx { return $0.faceIdx < $1.faceIdx }
                return $0.slotID < $1.slotID
            }

            // === Step 5: 조건부 매칭 (고품질: SFace 우선, 저품질: 위치 우선) ===
            var usedFaces: Set<Int> = []
            var usedSlots: Set<Int> = []
            var cachedFaces: [CachedFace] = []

            /// Keep Best: 매칭된 얼굴의 norm이 슬롯보다 높으면 슬롯 임베딩 갱신
            /// 위치 갱신: 모든 매칭에서 슬롯 위치를 최근 얼굴 위치로 갱신
            func updateSlotIfBetter(slotID: Int, embedding: [Float], norm: Float, center: CGPoint, boundingBox: CGRect) {
                if let idx = activeSlots.firstIndex(where: { $0.id == slotID }) {
                    // 위치 갱신 (항상 적용 - 저품질 경로 정확도 향상)
                    activeSlots[idx].center = center
                    activeSlots[idx].boundingBox = boundingBox

                    // Keep Best: norm이 더 높으면 임베딩도 갱신
                    if norm > activeSlots[idx].norm {
                        activeSlots[idx].embedding = embedding
                        activeSlots[idx].norm = norm
                    }
                }
            }

            // 저품질 위치 매칭용 상수
            let lowQualityPosLimit: CGFloat = 0.25  // 저품질은 위치 조건 완화 (25%)
            let lowQualityCostLimit: Float = min(rejectThreshold + 0.15, 1.0)  // cost 상한선 (1.0 초과 방지)

            // Step 5A: 고품질 얼굴 매칭 (SFace 우선)
            let highQualityCandidates = allCandidates.filter { $0.norm >= minEmbeddingNorm }
            let lowQualityCandidates = allCandidates.filter { $0.norm < minEmbeddingNorm }

            for candidate in highQualityCandidates {
                guard !usedFaces.contains(candidate.faceIdx) else { continue }
                guard !usedSlots.contains(candidate.slotID) else { continue }

                let cost = candidate.cost
                let posNorm = candidate.posDistNorm

                // 구간 판정
                if cost < greyZoneThreshold {
                    // 확신 구간: 즉시 매칭
                    usedFaces.insert(candidate.faceIdx)
                    usedSlots.insert(candidate.slotID)
                    cachedFaces.append(CachedFace(
                        boundingBox: candidate.boundingBox,
                        personIndex: candidate.slotID,
                        isValidSlot: false,
                        sfaceCost: cost
                    ))

                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 확신: face[\(candidate.faceIdx)]→slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) norm=\(String(format: "%.1f", candidate.norm))")

                    // Keep Best + 위치 갱신
                    updateSlotIfBetter(slotID: candidate.slotID, embedding: candidate.embedding, norm: candidate.norm, center: candidate.center, boundingBox: candidate.boundingBox)

                } else if cost < rejectThreshold {
                    // 모호 구간: 위치 조건 확인
                    if posNorm < greyZonePosLimit {
                        usedFaces.insert(candidate.faceIdx)
                        usedSlots.insert(candidate.slotID)
                        cachedFaces.append(CachedFace(
                            boundingBox: candidate.boundingBox,
                            personIndex: candidate.slotID,
                            isValidSlot: false,
                            sfaceCost: cost
                        ))

                        // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ Grey: face[\(candidate.faceIdx)]→slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", candidate.norm))")

                        // Keep Best + 위치 갱신
                        updateSlotIfBetter(slotID: candidate.slotID, embedding: candidate.embedding, norm: candidate.norm, center: candidate.center, boundingBox: candidate.boundingBox)
                    } else {
                        // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ Grey거부: face[\(candidate.faceIdx)]↛slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm))≥\(String(format: "%.2f", greyZonePosLimit)) norm=\(String(format: "%.1f", candidate.norm))")
                    }
                } else {
                    // 고품질 확장: 양쪽 norm ≥ 8.0이면 거절 임계값을 0.75로 완화
                    // (고개 돌림 등 각도 차이로 cost가 높아도 같은 인물일 가능성)
                    let bothHighQuality = candidate.norm >= highQualityNormLimit && candidate.slotNorm >= highQualityNormLimit
                    if bothHighQuality && cost < extendedRejectThreshold {
                        // 고품질 확장 Grey Zone: 위치 조건 확인
                        if posNorm < greyZonePosLimit {
                            usedFaces.insert(candidate.faceIdx)
                            usedSlots.insert(candidate.slotID)
                            cachedFaces.append(CachedFace(
                                boundingBox: candidate.boundingBox,
                                personIndex: candidate.slotID,
                                isValidSlot: false,
                                sfaceCost: cost
                            ))

                            // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 확장Grey: face[\(candidate.faceIdx)]→slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", candidate.norm)) slotNorm=\(String(format: "%.1f", candidate.slotNorm))")

                            updateSlotIfBetter(slotID: candidate.slotID, embedding: candidate.embedding, norm: candidate.norm, center: candidate.center, boundingBox: candidate.boundingBox)
                        } else {
                            // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 확장Grey거부: face[\(candidate.faceIdx)]↛slot\(candidate.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm))≥\(String(format: "%.2f", greyZonePosLimit)) norm=\(String(format: "%.1f", candidate.norm)) slotNorm=\(String(format: "%.1f", candidate.slotNorm))")
                        }
                    } else {
                        // Logger.similarPhoto.debug("[PersonMatch] \(shortID) HQ 거절: face[\(candidate.faceIdx)]↛slot\(candidate.slotID) cost=\(String(format: "%.3f", cost))≥\(String(format: "%.3f", rejectThreshold)) norm=\(String(format: "%.1f", candidate.norm)) slotNorm=\(String(format: "%.1f", candidate.slotNorm))")
                    }
                }
            }

            // Step 5B: 저품질 얼굴 매칭 (위치 우선 + SFace 교차검증)
            // 혼합 점수 계산 함수 (6-1: posNorm 포화 대응)
            // w1=0.7 (cost 가중치), w2=0.3 (posNorm 가중치)
            // posNorm이 1.0으로 포화되는 경우가 많으므로 cost 가중치를 높임
            func mixedScore(cost: Float, posNorm: CGFloat) -> CGFloat {
                let w1: CGFloat = 0.7  // cost 가중치 (권장: 0.7~0.8)
                let w2: CGFloat = 0.3  // posNorm 가중치
                return w1 * CGFloat(cost) + w2 * posNorm
            }

            // 저품질 얼굴별로 그룹화하여 가장 가까운 슬롯에 매칭 시도
            var lowQualityByFace: [Int: [MatchCandidate]] = [:]
            for candidate in lowQualityCandidates {
                guard !usedFaces.contains(candidate.faceIdx) else { continue }
                lowQualityByFace[candidate.faceIdx, default: []].append(candidate)
            }

            // 결정성 보장 + 매칭 품질: mixedScore가 낮은 face부터 처리 (6-1)
            // mixedScore = 0.7*cost + 0.3*posNorm (posNorm 포화 시 cost로 변별)
            let sortedFaceIds = lowQualityByFace.keys.sorted { faceA, faceB in
                let bestA = lowQualityByFace[faceA]?
                    .filter { !usedSlots.contains($0.slotID) }
                    .min(by: { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm)
                             < mixedScore(cost: $1.cost, posNorm: $1.posDistNorm) })
                let bestB = lowQualityByFace[faceB]?
                    .filter { !usedSlots.contains($0.slotID) }
                    .min(by: { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm)
                             < mixedScore(cost: $1.cost, posNorm: $1.posDistNorm) })
                // mixedScore로 비교, 같으면 faceIdx로 tie-break (결정성)
                let scoreA = bestA.map { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm) } ?? 1.0
                let scoreB = bestB.map { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm) } ?? 1.0
                if scoreA != scoreB { return scoreA < scoreB }
                return faceA < faceB
            }

            for faceIdx in sortedFaceIds {
                guard let candidates = lowQualityByFace[faceIdx],
                      !usedFaces.contains(faceIdx) else { continue }

                // 위치 기준으로 정렬 (가장 가까운 슬롯 우선)
                let sortedByPos = candidates
                    .filter { !usedSlots.contains($0.slotID) }
                    .sorted { $0.posDistNorm < $1.posDistNorm }

                guard let bestByPos = sortedByPos.first else { continue }

                let cost = bestByPos.cost
                let posNorm = bestByPos.posDistNorm

                // 교차 검증: 위치가 가깝고(25%) SFace cost가 상한선(0.80) 이하면 매칭
                if posNorm <= lowQualityPosLimit && cost < lowQualityCostLimit {
                    usedFaces.insert(faceIdx)
                    usedSlots.insert(bestByPos.slotID)
                    cachedFaces.append(CachedFace(
                        boundingBox: bestByPos.boundingBox,
                        personIndex: bestByPos.slotID,
                        isValidSlot: false,
                        sfaceCost: cost
                    ))

                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) LQ 매칭: face[\(faceIdx)]→slot\(bestByPos.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", bestByPos.norm))")

                    // 위치만 갱신 (저품질 임베딩으로 슬롯 임베딩 갱신 X, norm 0 전달)
                    updateSlotIfBetter(slotID: bestByPos.slotID, embedding: [], norm: 0, center: bestByPos.center, boundingBox: bestByPos.boundingBox)
                } else {
                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) LQ 거부: face[\(faceIdx)]↛slot\(bestByPos.slotID) cost=\(String(format: "%.3f", cost)) pos=\(String(format: "%.3f", posNorm)) norm=\(String(format: "%.1f", bestByPos.norm)) (limit: pos≤\(String(format: "%.2f", lowQualityPosLimit)) cost<\(String(format: "%.2f", lowQualityCostLimit)))")
                }
            }

            // === Step 6: 신규 슬롯 등록 (저품질 필터 적용) ===
            // 결정성 보장: faceIdx 정렬 순서로 처리
            for faceIdx in faceEmbeddings.keys.sorted() {
                guard let embedding = faceEmbeddings[faceIdx],
                      !usedFaces.contains(faceIdx) else { continue }
                guard activeSlots.count < maxSlots else {
                    continue
                }
                guard let data = faceData[faceIdx] else { continue }

                // norm 계산
                let norm = faceNorms[faceIdx] ?? sqrt(embedding.reduce(0) { $0 + $1 * $1 })

                // 저품질 얼굴은 신규 슬롯 생성 금지
                if norm < minEmbeddingNorm {
                    // Logger.similarPhoto.debug("[PersonMatch] \(shortID) 슬롯거부: face[\(faceIdx)] norm=\(String(format: "%.1f", norm))<\(String(format: "%.1f", self.minEmbeddingNorm))")
                    continue
                }

                // 신규 슬롯 생성
                let slot = PersonSlot(
                    id: nextSlotID,
                    embedding: embedding,
                    norm: norm,
                    center: data.center,
                    boundingBox: data.boundingBox
                )
                activeSlots.append(slot)

                usedFaces.insert(faceIdx)
                cachedFaces.append(CachedFace(
                    boundingBox: data.boundingBox,
                    personIndex: nextSlotID,
                    isValidSlot: false
                ))

                nextSlotID += 1
            }

            // === Step 7: Vision Fallback 얼굴 위치 기반 매칭 ===
            // 임베딩 없는 얼굴 (Vision fallback)은 위치만으로 기존 슬롯과 매칭 시도
            // 조건: posNorm < 0.10 (매우 엄격), 신규 슬롯 생성 안 함
            let visionFallbackPosLimit: CGFloat = 0.10

            // 결정성 보장: faceIdx 정렬 순서로 처리
            for faceIdx in faceData.keys.sorted() {
                guard let data = faceData[faceIdx] else { continue }
                // 이미 매칭된 얼굴 스킵
                guard !usedFaces.contains(faceIdx) else { continue }
                // 임베딩 있는 얼굴 스킵 (이미 위에서 처리됨)
                guard faceEmbeddings[faceIdx] == nil else { continue }

                // 가장 가까운 슬롯 찾기
                var bestSlot: (id: Int, posNorm: CGFloat)? = nil
                for slot in activeSlots {
                    guard !usedSlots.contains(slot.id) else { continue }

                    let dx = data.center.x - slot.center.x
                    let dy = data.center.y - slot.center.y
                    let posNorm = sqrt(dx * dx + dy * dy) / sqrt2

                    if posNorm < visionFallbackPosLimit {
                        if bestSlot == nil || posNorm < bestSlot!.posNorm {
                            bestSlot = (id: slot.id, posNorm: posNorm)
                        }
                    }
                }

                // 매칭 성공
                if let match = bestSlot {
                    usedFaces.insert(faceIdx)
                    usedSlots.insert(match.id)
                    cachedFaces.append(CachedFace(
                        boundingBox: data.boundingBox,
                        personIndex: match.id,
                        isValidSlot: false
                    ))
                    // 위치만 갱신 (임베딩 없으므로 norm=0)
                    updateSlotIfBetter(slotID: match.id, embedding: [], norm: 0, center: data.center, boundingBox: data.boundingBox)
                }
            }

            // === 사진별 매칭 요약 로그 ===
            let totalFaces = faceData.count
            let matchedCount = usedFaces.count
            let unmatchedFaces = faceData.keys.sorted().filter { !usedFaces.contains($0) }
            if !unmatchedFaces.isEmpty {
                let unmatchedInfo = unmatchedFaces.map { idx -> String in
                    let norm = faceNorms[idx] ?? 0
                    return "face[\(idx)](norm=\(String(format: "%.1f", norm)))"
                }.joined(separator: ", ")
                _ = unmatchedInfo  // 주석 처리된 디버그 로그에서 사용 — 로그 복원 시 제거
                // Logger.similarPhoto.debug("[PersonMatch] \(shortID): \(totalFaces)개 감지, \(matchedCount)개 매칭, 미매칭: \(unmatchedInfo)")
            }
            _ = (totalFaces, matchedCount)  // 주석 처리된 디버그 로그에서 사용 — 로그 복원 시 제거

            result[assetID] = cachedFaces
        }

        return result
    }

    // MARK: - Private Methods - UI

    /// 분석 완료 알림을 발송합니다.
    private func postAnalysisComplete(
        range: ClosedRange<Int>,
        groupIDs: [String],
        analyzedAssetIDs: [String]
    ) {
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .similarPhotoAnalysisComplete,
                object: nil,
                userInfo: [
                    "analysisRange": range,
                    "groupIDs": groupIDs,
                    "analyzedAssetIDs": analyzedAssetIDs
                ]
            )
        }
    }

    // MARK: - Thermal State

    /// 과열 상태 옵저버를 설정합니다.
    private func setupThermalStateObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(thermalStateDidChange),
            name: ProcessInfo.thermalStateDidChangeNotification,
            object: nil
        )
    }

    @objc private func thermalStateDidChange(_ notification: Notification) {
        let state = ProcessInfo.processInfo.thermalState

        switch state {
        case .serious, .critical:
            isThermalThrottled = true
        default:
            isThermalThrottled = false
        }
    }

    // MARK: - Background State

    /// 백그라운드 전환 옵저버를 설정합니다.
    private func setupBackgroundObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }

    @objc private func didEnterBackground() {
        // 모든 진행 중인 분석 취소
        serialQueue.sync {
            for (_, task) in currentTasks {
                task.cancel()
            }
            currentTasks.removeAll()
            requestQueue.removeAll()
            activeRequests.removeAll()
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

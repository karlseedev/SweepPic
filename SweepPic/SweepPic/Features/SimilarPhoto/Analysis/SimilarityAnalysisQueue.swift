//
//  SimilarityAnalysisQueue.swift
//  SweepPic
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 SweepPic. All rights reserved.
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

    /// 인물 매칭 엔진 (generateFeaturePrints + assignPersonIndicesForGroup)
    private let matchingEngine: PersonMatchingEngine

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
        self.matchingEngine = PersonMatchingEngine(imageLoader: imageLoader, analyzer: analyzer)
        self.semaphore = AsyncSemaphore(value: SimilarityConstants.maxConcurrentAnalysis)

        setupThermalStateObserver()
        setupBackgroundObserver()
    }

    // MARK: - Image Loading Pause/Resume (뷰어 LOD1 리소스 경쟁 방지)

    /// 분석용 이미지 로딩을 일시정지합니다.
    /// 뷰어 LOD1 요청 시 호출하여 PHCachingImageManager 리소스 경쟁을 제거합니다.
    func pauseImageLoading() {
        imageLoader.pause()
    }

    /// 일시정지된 이미지 로딩을 재개합니다.
    /// LOD1 도착 또는 뷰어 종료 시 호출합니다.
    func resumeImageLoading() {
        imageLoader.resume()
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
        // 격리 인스턴스(FaceScan 등)에서는 analytics 생략
        if self === SimilarityAnalysisQueue.shared {
            AnalyticsService.shared.countSimilarAnalysisCancelled()
        }

        // #if DEBUG: shared 인스턴스 취소 기록 (Stage 2 recorder)
        #if DEBUG
        if self === SimilarityAnalysisQueue.shared {
            GridAnalysisSessionRecorder.shared.recordCancellation(source: source.rawValue)
        }
        #endif

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
        // #if DEBUG: shared 인스턴스 분석 기록 (Stage 2 recorder)
        #if DEBUG
        let debugRequestID = UUID().uuidString
        if self === SimilarityAnalysisQueue.shared {
            GridAnalysisSessionRecorder.shared.recordRequest(
                id: debugRequestID, source: source.rawValue, range: range
            )
        }
        #endif

        // 성능 측정 시작
        let totalStartTime = CFAbsoluteTimeGetCurrent()
        let startMemory = getMemoryUsageMB()

        // T014.1: 분석 준비 — confirmed 그룹 멤버를 분석 대상에서 제외
        let allPhotos = fetchPhotos(in: range, fetchResult: fetchResult)
        let confirmedAssetIDs = await cache.getConfirmedAssetIDs()
        var photos = allPhotos.filter { !confirmedAssetIDs.contains($0.localIdentifier) }

        guard photos.count >= SimilarityConstants.minGroupSize else {
            let ids = photos.map { $0.localIdentifier }
            // confirmed가 아닌 사진만 비그룹으로 설정
            for assetID in ids {
                await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
            }
            postAnalysisComplete(range: range, groupIDs: [], analyzedAssetIDs: ids)
            return []
        }

        var assetIDs = photos.map { $0.localIdentifier }

        // 기존 그룹 정리 (재분석 시) — confirmed 그룹 멤버는 이미 제외됨
        await cache.prepareForReanalysis(assetIDs: Set(assetIDs))

        // T014.2: Feature Print 병렬 생성 + Vision 얼굴 유무 체크 (배치 처리)
        let fpStartTime = CFAbsoluteTimeGetCurrent()
        var (featurePrints, hasFaces) = await matchingEngine.generateFeaturePrints(for: photos)
        let fpTime = CFAbsoluteTimeGetCurrent() - fpStartTime

        // 취소 체크: FP 생성 후 (캐시/알림 스킵)
        guard !Task.isCancelled else {
            Logger.similarPhoto.debug("Cancelled after FP generation - skipping cache/notification")
            return []
        }

        // T014.3: 인접 거리 계산 및 그룹 분리
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

        // T014.3b: 그룹 경계 확인 — 분석 범위 끝에 걸친 그룹만 확장
        let (resolvedGroups, boundaryCompleted) = await resolveGroupBoundaries(
            rawGroups: rawGroups,
            photos: &photos,
            assetIDs: &assetIDs,
            featurePrints: &featurePrints,
            hasFaces: &hasFaces,
            range: range,
            fetchResult: fetchResult
        )

        // 취소 체크: 경계 확인 후
        guard !Task.isCancelled else {
            Logger.similarPhoto.debug("Cancelled after boundary resolution - skipping cache/notification")
            return []
        }

        // T014.4: 테두리 조기 표시 — 얼굴 있는 그룹만 예비 테두리 표시
        // Vision 얼굴 감지 결과(hasFaces)를 기반으로 얼굴 포함 그룹만 필터링
        // 사물 그룹은 .analyzing 상태 유지 → YuNet 최종 분석에서 판��
        let facePresenceMap = Dictionary(uniqueKeysWithValues: zip(assetIDs, hasFaces))
        let faceGroups = resolvedGroups.filter { groupIDs in
            groupIDs.contains { facePresenceMap[$0] == true }
        }
        let preliminaryAssetIDs = Set(faceGroups.flatMap { $0 })

        // 얼굴 그룹 멤버: 예비 테두리 표시
        for assetID in preliminaryAssetIDs {
            await cache.setState(.analyzed(inGroup: true, groupID: "preliminary"), for: assetID)
        }
        // 그룹에 속하지 않은 사진: 분석 완료 (그룹 없음)
        let allGroupedAssetIDs = Set(resolvedGroups.flatMap { $0 })
        for assetID in assetIDs where !allGroupedAssetIDs.contains(assetID) {
            await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
        }
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

        for (groupIndex, groupAssetIDs) in resolvedGroups.enumerated() {
            // 취소 체크: resolvedGroups 루프 (캐시/알림 스킵)
            guard !Task.isCancelled else {
                Logger.similarPhoto.debug("Cancelled during group processing - skipping cache/notification")
                return []
            }

            // 그룹 내 사진 가져오기 (경계 확인으로 확장된 사진 포함)
            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }

            // 그룹 단위로 일관된 personIndex 할당 (YuNet 960 직접 감지 + SFace 임베딩)
            let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
                assetIDs: groupAssetIDs,
                photos: groupPhotos
            )

            // 유효 슬롯 계산: 같은 personIndex가 2장 이상의 사진에서 나타나야 함
            var slotPhotoCount: [Int: Set<String>] = [:]
            for (assetID, faces) in photoFacesMap {
                for face in faces {
                    slotPhotoCount[face.personIndex, default: []].insert(assetID)
                }
            }

            let validSlots = Set(slotPhotoCount.filter {
                $0.value.count >= SimilarityConstants.minPhotosPerSlot
            }.keys)

            // ========== 유효 슬롯 얼굴이 있는 사진만 그룹에 포함 ==========
            let validMembers = groupAssetIDs.filter { assetID in
                guard let faces = photoFacesMap[assetID] else { return false }
                return faces.contains { validSlots.contains($0.personIndex) }
            }

            // 그룹 내 탈락 사진 상태 업데이트
            let excludedFromGroup = Set(groupAssetIDs).subtracting(validMembers)
            for assetID in excludedFromGroup {
                await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
                if let faces = photoFacesMap[assetID] {
                    await cache.setFaces(faces, for: assetID)
                }
            }

            // T014.7: 캐시 저장 요청
            if let groupID = await cache.addGroupIfValid(
                members: validMembers,
                validSlots: validSlots,
                photoFaces: photoFacesMap
            ) {
                validGroupIDs.append(groupID)

                // 경계 확인이 양쪽 모두 완료된 그룹만 confirmed로 등록
                if groupIndex < boundaryCompleted.count && boundaryCompleted[groupIndex] {
                    await cache.confirmGroup(groupID: groupID)
                }
            }

            // 성능 측정: 얼굴 수 누적
            totalFaceCount += photoFacesMap.values.reduce(0) { $0 + $1.count }
        }

        // 성능 측정: 얼굴 감지 + 매칭 시간
        let faceTime = CFAbsoluteTimeGetCurrent() - faceStartTime

        // LRU eviction
        await cache.evictIfNeeded()

        // 그룹에 속하지 않은 사진들 상태 업데이트
        let groupedAssetIDs = Set(resolvedGroups.flatMap { $0 })
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
        // 격리 인스턴스(FaceScan 등)에서는 analytics 생략
        let analysisDuration = CFAbsoluteTimeGetCurrent() - totalStartTime
        if self === SimilarityAnalysisQueue.shared {
            AnalyticsService.shared.countSimilarAnalysisCompleted(groups: validGroupIDs.count, duration: analysisDuration)
        }

        // T014.8: UI 알림 발송
        postAnalysisComplete(range: range, groupIDs: validGroupIDs, analyzedAssetIDs: assetIDs)

        // #if DEBUG: shared 인스턴스 완료 기록 (Stage 2 recorder)
        #if DEBUG
        if self === SimilarityAnalysisQueue.shared {
            GridAnalysisSessionRecorder.shared.recordCompletion(
                id: debugRequestID, groupIDs: validGroupIDs
            )
        }
        #endif

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

    // MARK: - Private Methods - Photo Fetching

    // MARK: - Group Boundary Resolution

    /// 그룹 경계를 확인하여 확정합니다.
    ///
    /// rawGroup이 분석 범위 끝에 걸쳐있으면, 한 장씩 추가 확인하여
    /// 진짜 끊기 지점(distance > threshold)을 찾습니다.
    ///
    /// - Parameters:
    ///   - rawGroups: formGroups()에서 반환된 초기 그룹 배열
    ///   - photos: 분석 범위 내 사진 배열
    ///   - assetIDs: 분석 범위 내 사진 ID 배열
    ///   - featurePrints: 분석 범위 내 Feature Print 배열
    ///   - hasFaces: 분석 범위 내 얼굴 유무 배열
    ///   - range: 원래 분석 범위 (fetchResult 인덱스 기준)
    ///   - fetchResult: 전체 사진 fetch 결과
    /// - Returns: (확장된 그룹, 확장된 사진, 확장된 ID, 확장된 FP, 확장된 hasFaces, 경계 완료 여부 배열)
    private func resolveGroupBoundaries(
        rawGroups: [[String]],
        photos: inout [PHAsset],
        assetIDs: inout [String],
        featurePrints: inout [VNFeaturePrintObservation?],
        hasFaces: inout [Bool],
        range: ClosedRange<Int>,
        fetchResult: PHFetchResult<PHAsset>
    ) async -> (resolvedGroups: [[String]], boundaryCompleted: [Bool]) {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        let maxExpansion = SimilarityConstants.maxBoundaryExpansion
        var resolvedGroups: [[String]] = []
        var boundaryCompleted: [Bool] = []

        for group in rawGroups {
            guard !group.isEmpty else { continue }
            var expandedGroup = group
            // 양쪽 경계 확인 완료 여부 추적
            var leftConfirmed = true
            var rightConfirmed = true

            // --- 왼쪽 경계 확인 ---
            // 그룹의 첫 멤버가 분석 범위의 첫 사진과 일치하면 경계가 불확실
            if group.first == assetIDs.first {
                leftConfirmed = false
                var expansionCount = 0
                // range.lowerBound 이전부터 왼쪽으로 탐색
                var searchIndex = range.lowerBound - 1
                // 현재 그룹 왼쪽 끝의 FP (비교 대상)
                var edgeFP: VNFeaturePrintObservation? = {
                    if let idx = assetIDs.firstIndex(of: group.first!) {
                        return featurePrints[idx]
                    }
                    return nil
                }()

                while searchIndex >= 0 && expansionCount < maxExpansion {
                    // 취소 체크
                    guard !Task.isCancelled else { break }

                    let asset = fetchResult.object(at: searchIndex)
                    searchIndex -= 1

                    // 동영상/삭제대기함 건너뛰기 (fetchPhotos와 동일 규칙)
                    guard asset.mediaType == .image,
                          !trashedIDs.contains(asset.localIdentifier) else {
                        continue
                    }

                    // 이미 확정된 그룹에 속한 사진이면 경계 확정
                    let state = await cache.getState(for: asset.localIdentifier)
                    if case .analyzed(true, let gid?) = state, gid != "preliminary" {
                        let isConfirmed = await cache.isGroupConfirmed(groupID: gid)
                        if isConfirmed {
                            leftConfirmed = true
                            break
                        }
                    }

                    // FP 생성 + 얼굴 유무 확인
                    do {
                        let cgImage = try await imageLoader.loadImage(for: asset)
                        let (fp, hasFace) = try await analyzer.generateFeaturePrintWithFaceCheck(for: cgImage)

                        // 인접 거리 비교
                        if let edgeFP = edgeFP {
                            let distance = try analyzer.computeDistance(edgeFP, fp)
                            if distance > SimilarityConstants.similarityThreshold {
                                // 끊기 지점 발견 → 경계 확정
                                leftConfirmed = true
                                break
                            }
                        }

                        // 유사 → 그룹에 추가
                        expandedGroup.insert(asset.localIdentifier, at: 0)
                        photos.insert(asset, at: 0)
                        assetIDs.insert(asset.localIdentifier, at: 0)
                        featurePrints.insert(fp, at: 0)
                        hasFaces.insert(hasFace, at: 0)
                        edgeFP = fp

                        // 확장된 사진 상태 설정
                        await cache.setState(.analyzing, for: asset.localIdentifier)
                        await cache.removeFaces(for: asset.localIdentifier)

                        expansionCount += 1
                    } catch {
                        // 이미지 로드/FP 생성 실패 → 끊기 지점으로 처리
                        leftConfirmed = true
                        Logger.similarPhoto.error("Boundary expansion left failed: \(error)")
                        break
                    }
                }

                // maxExpansion 도달 시 미확정
                if expansionCount >= maxExpansion {
                    leftConfirmed = false
                    Logger.similarPhoto.notice("Left boundary expansion reached limit (\(maxExpansion))")
                }
                // fetchResult 시작에 도달 시 확정
                if searchIndex < 0 && !leftConfirmed {
                    leftConfirmed = true
                }
            }

            // --- 오른쪽 경계 확인 ---
            // 그룹의 마지막 멤버가 분석 범위의 마지막 사진과 일치하면 경계가 불확실
            if group.last == assetIDs.last {
                rightConfirmed = false
                var expansionCount = 0
                // range.upperBound 이후부터 오른쪽으로 탐색
                var searchIndex = range.upperBound + 1
                // 현재 그룹 오른쪽 끝의 FP (비교 대상)
                var edgeFP: VNFeaturePrintObservation? = {
                    if let idx = assetIDs.lastIndex(of: expandedGroup.last!) {
                        return featurePrints[idx]
                    }
                    return nil
                }()

                while searchIndex < fetchResult.count && expansionCount < maxExpansion {
                    // 취소 체크
                    guard !Task.isCancelled else { break }

                    let asset = fetchResult.object(at: searchIndex)
                    searchIndex += 1

                    // 동영상/삭제대기함 건너뛰기 (fetchPhotos와 동일 규칙)
                    guard asset.mediaType == .image,
                          !trashedIDs.contains(asset.localIdentifier) else {
                        continue
                    }

                    // 이미 확정된 그룹에 속한 사진이면 경계 확정
                    let state = await cache.getState(for: asset.localIdentifier)
                    if case .analyzed(true, let gid?) = state, gid != "preliminary" {
                        let isConfirmed = await cache.isGroupConfirmed(groupID: gid)
                        if isConfirmed {
                            rightConfirmed = true
                            break
                        }
                    }

                    // FP 생성 + 얼굴 유무 확인
                    do {
                        let cgImage = try await imageLoader.loadImage(for: asset)
                        let (fp, hasFace) = try await analyzer.generateFeaturePrintWithFaceCheck(for: cgImage)

                        // 인접 거리 비교
                        if let edgeFP = edgeFP {
                            let distance = try analyzer.computeDistance(edgeFP, fp)
                            if distance > SimilarityConstants.similarityThreshold {
                                // 끊기 지점 발견 → 경계 확정
                                rightConfirmed = true
                                break
                            }
                        }

                        // 유사 → 그룹에 추가
                        expandedGroup.append(asset.localIdentifier)
                        photos.append(asset)
                        assetIDs.append(asset.localIdentifier)
                        featurePrints.append(fp)
                        hasFaces.append(hasFace)
                        edgeFP = fp

                        // 확장된 사진 상태 설정
                        await cache.setState(.analyzing, for: asset.localIdentifier)
                        await cache.removeFaces(for: asset.localIdentifier)

                        expansionCount += 1
                    } catch {
                        // 이미지 로드/FP 생성 실패 → 끊기 지점으로 처리
                        rightConfirmed = true
                        Logger.similarPhoto.error("Boundary expansion right failed: \(error)")
                        break
                    }
                }

                // maxExpansion 도달 시 미확정
                if expansionCount >= maxExpansion {
                    rightConfirmed = false
                    Logger.similarPhoto.notice("Right boundary expansion reached limit (\(maxExpansion))")
                }
                // fetchResult 끝에 도달 시 확정
                if searchIndex >= fetchResult.count && !rightConfirmed {
                    rightConfirmed = true
                }
            }

            resolvedGroups.append(expandedGroup)
            boundaryCompleted.append(leftConfirmed && rightConfirmed)
        }

        return (resolvedGroups, boundaryCompleted)
    }

    /// 범위 내 사진을 가져옵니다.
    ///
    /// 삭제대기함 사진 및 동영상은 분석 대상에서 제외합니다. (FR-033, FR-037)
    /// - 삭제된 사진이 그룹에 포함되면 3장 미만 무효화 로직이 제대로 동작하지 않기 때문입니다.
    /// - 동영상은 첫 프레임만 반환되어 무의미한 Feature Print/얼굴 감지가 발생하므로 제외합니다.
    ///
    /// - Parameters:
    ///   - range: 인덱스 범위
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: PHAsset 배열 (삭제대기함 사진 및 동영상 제외)
    private func fetchPhotos(in range: ClosedRange<Int>, fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        var photos: [PHAsset] = []
        let clampedRange = max(0, range.lowerBound)...min(fetchResult.count - 1, range.upperBound)

        for i in clampedRange {
            let asset = fetchResult.object(at: i)
            // 삭제대기함 사진 및 동영상은 분석 대상에서 제외
            if !trashedIDs.contains(asset.localIdentifier)
                && asset.mediaType == .image {
                photos.append(asset)
            }
        }

        return photos
    }

    // MARK: - Private Methods - UI

    /// 분석 완료 알림을 발송합니다.
    private func postAnalysisComplete(
        range: ClosedRange<Int>,
        groupIDs: [String],
        analyzedAssetIDs: [String]
    ) {
        // 격리 인스턴스(FaceScan 등)에서는 글로벌 notification 억제
        guard self === SimilarityAnalysisQueue.shared else { return }
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

    // MARK: - Debug Helpers

    #if DEBUG

    // MARK: - 그룹 진단: 파이프라인 추적 (로그 3)

    /// 특정 멤버들이 격리 분석에서 어느 단계에서 탈락하는지 추적합니다.
    ///
    /// 파이프라인 단계:
    /// 1. fetchPhotos → 분석 대상 사진 추출
    /// 2. generateFeaturePrints → FP 생성
    /// 3. formGroups → rawGroups 형성 (인접 FP 거리)
    /// 4. assignPersonIndicesForGroup → 얼굴 감지 + 인물 매칭
    /// 5. validSlots 계산 → 슬롯별 사진 수 검증
    /// 6. validMembers 필터 → 유효 슬롯 얼굴 보유 사진만
    ///
    /// - Parameters:
    ///   - targetMembers: 진단 대상 그룹의 멤버 assetID 집합
    ///   - range: 분석 범위 (Grid fetchResult 기준)
    ///   - fetchResult: Grid fetchResult (ascending)
    /// - Returns: 파이프라인 각 단계의 상세 추적 결과
    struct PipelineTrace {
        /// 분석 범위
        let range: ClosedRange<Int>
        /// 분석 투입 사진 수
        let analyzedPhotoCount: Int
        /// rawGroups 총 수 (formGroups 결과)
        let rawGroupCount: Int
        /// 타깃 멤버를 포함하는 rawGroup (없으면 nil)
        let targetRawGroup: [String]?
        /// 멤버별 얼굴 감지 수
        let faceCountPerMember: [String: Int]
        /// personIndex별 등장 사진 수
        let slotPhotoCount: [Int: Int]
        /// 유효 슬롯 (minPhotosPerSlot 이상)
        let validSlots: Set<Int>
        /// 유효 멤버 (유효 슬롯 얼굴 보유)
        let validMembers: [String]
        /// 탈락 멤버
        let excludedMembers: [String]
        /// 판정 결과
        let result: String
        /// 판정 사유
        let rejectionReason: String?
    }

    func debugPipelineTrace(
        targetMembers: Set<String>,
        range: ClosedRange<Int>,
        fetchResult: PHFetchResult<PHAsset>
    ) async -> PipelineTrace {
        // Step 1: 사진 추출
        let photos = fetchPhotos(in: range, fetchResult: fetchResult)
        let photoIDs = photos.map(\.localIdentifier)

        // Step 2: FP 생성
        let (featurePrints, _) = await matchingEngine.generateFeaturePrints(for: photos)

        // Step 3: rawGroups 형성
        let rawGroups = analyzer.formGroups(
            featurePrints: featurePrints,
            photoIDs: photoIDs,
            threshold: SimilarityConstants.similarityThreshold
        )

        // 타깃 멤버를 포함하는 rawGroup 찾기
        var targetRawGroup: [String]? = nil
        for group in rawGroups {
            let groupSet = Set(group)
            if !groupSet.isDisjoint(with: targetMembers) {
                targetRawGroup = group
                break
            }
        }

        // rawGroup에 없으면 여기서 탈락
        guard let rawGroup = targetRawGroup else {
            return PipelineTrace(
                range: range,
                analyzedPhotoCount: photos.count,
                rawGroupCount: rawGroups.count,
                targetRawGroup: nil,
                faceCountPerMember: [:],
                slotPhotoCount: [:],
                validSlots: [],
                validMembers: [],
                excludedMembers: Array(targetMembers),
                result: "rejected",
                rejectionReason: "notInRawGroups — FP 인접 거리에서 그룹 미형성"
            )
        }

        // Step 4: 얼굴 감지 + 인물 매칭
        let groupPhotos = photos.filter { rawGroup.contains($0.localIdentifier) }
        let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
            assetIDs: rawGroup,
            photos: groupPhotos
        )

        // 멤버별 얼굴 수
        let faceCountPerMember = rawGroup.reduce(into: [String: Int]()) { dict, id in
            dict[id] = photoFacesMap[id]?.count ?? 0
        }

        // Step 5: 슬롯 계산
        var slotPhotoCountMap: [Int: Set<String>] = [:]
        for (assetID, faces) in photoFacesMap {
            for face in faces {
                slotPhotoCountMap[face.personIndex, default: []].insert(assetID)
            }
        }

        let validSlots = Set(slotPhotoCountMap.filter {
            $0.value.count >= SimilarityConstants.minPhotosPerSlot
        }.keys)
        let slotCounts = slotPhotoCountMap.mapValues { $0.count }

        // validSlots 미달 탈락
        guard validSlots.count >= SimilarityConstants.minValidSlots else {
            return PipelineTrace(
                range: range,
                analyzedPhotoCount: photos.count,
                rawGroupCount: rawGroups.count,
                targetRawGroup: rawGroup,
                faceCountPerMember: faceCountPerMember,
                slotPhotoCount: slotCounts,
                validSlots: validSlots,
                validMembers: [],
                excludedMembers: rawGroup,
                result: "rejected",
                rejectionReason: "noValidSlots — 유효 슬롯 \(validSlots.count)개 < 최소 \(SimilarityConstants.minValidSlots)개"
            )
        }

        // Step 6: 유효 멤버 필터
        let validMembers = rawGroup.filter { assetID in
            guard let faces = photoFacesMap[assetID] else { return false }
            return faces.contains { validSlots.contains($0.personIndex) }
        }
        let excludedMembers = rawGroup.filter { !validMembers.contains($0) }

        // 멤버 수 미달 탈락
        guard validMembers.count >= SimilarityConstants.minGroupSize else {
            return PipelineTrace(
                range: range,
                analyzedPhotoCount: photos.count,
                rawGroupCount: rawGroups.count,
                targetRawGroup: rawGroup,
                faceCountPerMember: faceCountPerMember,
                slotPhotoCount: slotCounts,
                validSlots: validSlots,
                validMembers: validMembers,
                excludedMembers: excludedMembers,
                result: "rejected",
                rejectionReason: "validMembersTooSmall — 유효 멤버 \(validMembers.count)장 < 최소 \(SimilarityConstants.minGroupSize)장"
            )
        }

        // 통과
        return PipelineTrace(
            range: range,
            analyzedPhotoCount: photos.count,
            rawGroupCount: rawGroups.count,
            targetRawGroup: rawGroup,
            faceCountPerMember: faceCountPerMember,
            slotPhotoCount: slotCounts,
            validSlots: validSlots,
            validMembers: validMembers,
            excludedMembers: excludedMembers,
            result: "accepted",
            rejectionReason: nil
        )
    }
    #endif
}

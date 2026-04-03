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
        let (featurePrints, hasFaces) = await matchingEngine.generateFeaturePrints(for: photos)
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
            let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
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

    /// 격리 인스턴스에서 formGroupsForRange()를 호출하고 결과를 추출합니다 (검증 하네스용).
    ///
    /// production formGroupsForRange()를 그대로 호출하며,
    /// 격리 캐시에서 그룹 멤버를 읽어 반환합니다.
    ///
    /// - Parameters:
    ///   - range: 분석할 인덱스 범위
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: (그룹 ID 배열, 그룹별 멤버 배열, 분석된 사진 ID 배열)
    func debugGroupsForRange(
        _ range: ClosedRange<Int>,
        fetchResult: PHFetchResult<PHAsset>
    ) async -> (groupIDs: [String], groups: [[String]], analyzedAssetIDs: [String]) {
        // production formGroupsForRange를 그대로 호출
        let groupIDs = await formGroupsForRange(range, source: .grid, fetchResult: fetchResult)

        // 격리 캐시에서 그룹 멤버 추출
        var groups: [[String]] = []
        for groupID in groupIDs {
            let members = await cache.getGroupMembers(groupID: groupID)
            groups.append(members)
        }

        // 분석 투입 사진 ID 추출
        let photos = fetchPhotos(in: range, fetchResult: fetchResult)
        let analyzedAssetIDs = photos.map(\.localIdentifier)

        return (groupIDs, groups, analyzedAssetIDs)
    }

    /// private fetchPhotos를 debug 용도로 노출합니다 (입력 동등성 검증용).
    ///
    /// - Parameters:
    ///   - range: 인덱스 범위
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: 삭제대기함 제외된 PHAsset 배열
    func debugFetchPhotos(in range: ClosedRange<Int>, fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        return fetchPhotos(in: range, fetchResult: fetchResult)
    }
    #endif
}

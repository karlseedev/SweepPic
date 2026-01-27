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
import Vision
import UIKit
import AppCore

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

    /// 얼굴 감지기
    private let faceDetector: FaceDetector

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
        cache: SimilarityCache = .shared,
        faceDetector: FaceDetector = .shared
    ) {
        self.imageLoader = imageLoader
        self.analyzer = analyzer
        self.cache = cache
        self.faceDetector = faceDetector
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

    /// 특정 소스의 분석 요청을 취소합니다.
    ///
    /// - Parameter source: 취소할 소스 (.grid만 취소 가능)
    func cancel(source: AnalysisSource) {
        // viewer 소스는 취소 불가
        guard source == .grid else { return }

        serialQueue.sync {
            // 큐에서 해당 소스 요청 제거
            requestQueue.removeAll { $0.source == source }

            // 진행 중인 작업 취소
            for (requestID, task) in currentTasks {
                if activeRequests.contains(requestID) {
                    task.cancel()
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

        // T014.2: Feature Print 병렬 생성
        let fpStartTime = CFAbsoluteTimeGetCurrent()
        let featurePrints = await generateFeaturePrints(for: photos)
        let fpTime = CFAbsoluteTimeGetCurrent() - fpStartTime

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

        // T014.5 & T014.6: 얼굴 감지 + 유효 슬롯 계산
        var validGroupIDs: [String] = []
        let viewerSize = getExpectedViewerSize()

        // 성능 측정: 얼굴 감지 + 매칭 시간
        let faceStartTime = CFAbsoluteTimeGetCurrent()
        var totalFaceCount = 0

        for groupAssetIDs in rawGroups {
            // 그룹 내 사진 가져오기
            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }

            // 각 사진에서 얼굴 감지 (Raw 결과 수집)
            var rawFacesMap: [String: [DetectedFace]] = [:]

            for photo in groupPhotos {
                do {
                    let faces = try await faceDetector.detectFaces(in: photo, viewerSize: viewerSize)
                    rawFacesMap[photo.localIdentifier] = faces
                } catch {
                    // 얼굴 감지 실패 시 빈 배열
                    rawFacesMap[photo.localIdentifier] = []
                }
            }

            // 그룹 단위로 일관된 personIndex 할당 (위치 + Feature Print 이중 검증)
            let photoFacesMap = await assignPersonIndicesForGroup(
                rawFacesMap: rawFacesMap,
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
            let thermalState = ProcessInfo.processInfo.thermalState

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

            // 개별 측정 결과 출력
            print("""
            ========== PERFORMANCE METRICS (Vision) [#\(performanceStats.measurementCount)] ==========
            Photos: \(photos.count), Faces: \(totalFaceCount), Groups: \(validGroupIDs.count)
            --------------------------------------------------
            FP Generation Time: \(String(format: "%.2f", fpTimeMs))ms (\(String(format: "%.1f", fpTimeMs / Double(photos.count)))ms/photo)
            Face Detect+Match Time: \(String(format: "%.2f", faceTimeMs))ms (\(String(format: "%.1f", faceTimeMs / Double(max(1, totalFaceCount))))ms/face)
            Total Time: \(String(format: "%.2f", totalTimeMs))ms
            --------------------------------------------------
            Memory Start: \(String(format: "%.1f", startMemory))MB
            Memory End: \(String(format: "%.1f", endMemory))MB
            Memory Delta: \(String(format: "%+.1f", memoryDelta))MB
            Thermal State: \(thermalStateString(thermalState))
            ==================================================
            """)

            // 3회 이상 측정되면 통계 리포트 출력
            if performanceStats.measurementCount >= 3 {
                statsQueue.sync {
                    performanceStats.printReport()
                }
            }
        }

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

    /// 사진들의 Feature Print를 병렬로 생성합니다.
    ///
    /// - Parameter photos: 분석할 PHAsset 배열
    /// - Returns: Feature Print 배열 (실패 시 nil)
    private func generateFeaturePrints(for photos: [PHAsset]) async -> [VNFeaturePrintObservation?] {
        let currentLimit = isThermalThrottled
            ? SimilarityConstants.maxConcurrentAnalysisThermal
            : SimilarityConstants.maxConcurrentAnalysis

        let semaphore = AsyncSemaphore(value: currentLimit)

        return await withTaskGroup(of: (Int, VNFeaturePrintObservation?).self) { group in
            for (index, photo) in photos.enumerated() {
                group.addTask {
                    await semaphore.wait()
                    defer { semaphore.signal() }

                    do {
                        let image = try await self.imageLoader.loadImage(for: photo)
                        let fp = try await self.analyzer.generateFeaturePrint(for: image)
                        return (index, fp)
                    } catch {
                        // 개별 실패 → nil 반환
                        return (index, nil)
                    }
                }
            }

            // 결과 수집
            var results = [VNFeaturePrintObservation?](repeating: nil, count: photos.count)
            for await (index, fp) in group {
                results[index] = fp
            }
            return results
        }
    }

    // MARK: - Private Methods - Photo Fetching

    /// 범위 내 사진을 가져옵니다.
    ///
    /// 휴지통에 있는 사진은 분석 대상에서 제외합니다. (FR-033, FR-037)
    /// 삭제된 사진이 그룹에 포함되면 3장 미만 무효화 로직이 제대로 동작하지 않기 때문입니다.
    ///
    /// - Parameters:
    ///   - range: 인덱스 범위
    ///   - fetchResult: 사진 fetch 결과
    /// - Returns: PHAsset 배열 (휴지통 사진 제외)
    private func fetchPhotos(in range: ClosedRange<Int>, fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        var photos: [PHAsset] = []
        let clampedRange = max(0, range.lowerBound)...min(fetchResult.count - 1, range.upperBound)

        for i in clampedRange {
            let asset = fetchResult.object(at: i)
            // 휴지통에 있는 사진은 분석 대상에서 제외
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
        let norm: Float           // 임베딩 품질
    }

    /// 그룹 단위로 일관된 인물 번호를 부여합니다.
    ///
    /// 전역 후보 정렬 기반 근사 매칭 알고리즘을 사용합니다.
    /// - 동적 인물 풀: 첫 사진에서 부팅, 이후 신규 인물 등록
    /// - Grey Zone 전략: 확신/모호/거절 구간으로 나누어 위치 조건 적용
    /// - 캐시 미저장 정책: FP 실패 또는 매칭 실패 얼굴은 CachedFace에 저장하지 않음
    ///
    /// - Parameters:
    ///   - rawFacesMap: 사진별 감지된 얼굴 (assetID → [DetectedFace])
    ///   - assetIDs: 그룹 멤버 순서 (분석 순서)
    ///   - photos: PHAsset 배열 (이미지 로딩용)
    /// - Returns: 일관된 personIndex가 부여된 CachedFace 맵
    private func assignPersonIndicesForGroup(
        rawFacesMap: [String: [DetectedFace]],
        assetIDs: [String],
        photos: [PHAsset],
        visionFallbackMode: VisionFallbackMode = .extended
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

        // 각 사진 처리
        for assetID in assetIDs {
            guard let faces = rawFacesMap[assetID] else {
                result[assetID] = []
                continue
            }

            // 이미지 로드
            var cgImage: CGImage? = nil
            if let photo = photoMap[assetID] {
                cgImage = try? await imageLoader.loadImage(for: photo)
            }

            // === Step 1: YuNet으로 얼굴 감지 + SFace 임베딩 생성 ===
            var faceEmbeddings: [Int: [Float]] = [:]
            var faceData: [Int: (center: CGPoint, boundingBox: CGRect)] = [:]

            guard let image = cgImage,
                  let yunet = YuNetFaceDetector.shared,
                  let sface = SFaceRecognizer.shared else {
                // 모델 로드 실패 시 기존 rawFacesMap 기반으로 진행 (임베딩 없이)
                for (faceIdx, face) in faces.enumerated() {
                    let center = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
                    faceData[faceIdx] = (center: center, boundingBox: face.boundingBox)
                }
                Log.print("[FaceMatching] Photo \(assetID.prefix(8)): Model not available, skipping embedding")
                result[assetID] = []
                continue
            }

            // YuNet으로 얼굴 감지 (landmark 포함)
            let yunetDetections: [YuNetDetection]
            do {
                yunetDetections = try yunet.detect(in: image)
            } catch {
                Log.print("[FaceMatching] Photo \(assetID.prefix(8)): YuNet detection failed - \(error.localizedDescription)")
                result[assetID] = []
                continue
            }

            // Vision fallback 처리
            // - off: fallback 없음
            // - basic: YuNet=0일 때만 Vision 사용
            // - extended: YuNet < Vision일 때 누락된 Vision 얼굴 추가
            var visionFallbackFaces: [Int] = []  // Vision에서 가져온 얼굴 인덱스

            switch visionFallbackMode {
            case .off:
                if yunetDetections.isEmpty && !faces.isEmpty {
                    Log.print("[NoFallback] Photo \(assetID.prefix(8)): YuNet=0, Vision=\(faces.count) (skipped)")
                }

            case .basic:
                // YuNet=0일 때만 Vision 사용
                if yunetDetections.isEmpty && !faces.isEmpty {
                    Log.print("[VisionFallback] Photo \(assetID.prefix(8)): YuNet=0, Vision=\(faces.count) faces")
                    for (faceIdx, face) in faces.enumerated() {
                        let center = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
                        faceData[faceIdx] = (center: center, boundingBox: face.boundingBox)
                        visionFallbackFaces.append(faceIdx)
                    }
                }

            case .extended:
                // YuNet=0일 때 Vision 사용
                if yunetDetections.isEmpty && !faces.isEmpty {
                    Log.print("[VisionFallback] Photo \(assetID.prefix(8)): YuNet=0, Vision=\(faces.count) faces")
                    for (faceIdx, face) in faces.enumerated() {
                        let center = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
                        faceData[faceIdx] = (center: center, boundingBox: face.boundingBox)
                        visionFallbackFaces.append(faceIdx)
                    }
                }
                // Extended 로직: YuNet > 0이어도 누락된 작은 얼굴 추가 (아래에서 처리)
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
                    Log.print("[AlignFail] Face(\(faceIdx)): Alignment failed")
                    continue
                }

                // SFace로 임베딩 추출
                do {
                    let embedding = try sface.extractEmbedding(from: alignedFace)
                    faceEmbeddings[faceIdx] = embedding
                } catch {
                    Log.print("[EmbedFail] Face(\(faceIdx)): \(error.localizedDescription)")
                    continue
                }
            }

            // === Extended Fallback: IoU 기반 + 작은 얼굴 조건 ===
            // Vision 얼굴 중 YuNet과 IoU < 0.3이고 작은 얼굴(width < 0.07)만 추가
            // FP 리스크 최소화를 위해 작은 얼굴만 보완
            if visionFallbackMode == .extended && !yunetDetections.isEmpty && !faces.isEmpty {
                // YuNet 얼굴의 boundingBox만 추출
                let yunetBoxes = faceData.compactMapValues { $0.boundingBox }

                // 누락된 작은 얼굴 찾기
                let missedFaces = findMissedSmallFaces(
                    yunetFaceData: yunetBoxes,
                    visionFaces: faces,
                    assetID: assetID
                )

                // 누락된 Vision 얼굴 추가
                for missed in missedFaces {
                    let newFaceIdx = yunetDetections.count + visionFallbackFaces.count
                    let center = CGPoint(x: missed.face.boundingBox.midX, y: missed.face.boundingBox.midY)
                    faceData[newFaceIdx] = (center: center, boundingBox: missed.face.boundingBox)
                    visionFallbackFaces.append(newFaceIdx)
                }
            }

            // 감지 소스 표시 (YuNet, Vision, 또는 YuNet+Vision)
            let detectionSource: String
            let totalFaces: Int
            if yunetDetections.isEmpty && !faces.isEmpty {
                detectionSource = "Vision"
                totalFaces = faces.count
            } else if !visionFallbackFaces.isEmpty {
                detectionSource = "YuNet+Vision"
                totalFaces = yunetDetections.count + visionFallbackFaces.count
            } else {
                detectionSource = "YuNet"
                totalFaces = yunetDetections.count
            }
            Log.print("[FaceMatching] Photo \(assetID.prefix(8)): \(totalFaces) faces (\(detectionSource)), Embed: \(faceEmbeddings.count)/\(totalFaces), Slots: \(activeSlots.count)")

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

                    // Extended fallback 얼굴은 부팅 시에도 슬롯 생성 금지
                    if visionFallbackFaces.contains(faceIdx) {
                        continue
                    }

                    // norm 계산
                    let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })

                    // 부팅 시에는 저품질 얼굴도 슬롯 생성 허용 (모든 인물 포함)
                    let qualityTag = norm < minEmbeddingNorm ? " [LowQ]" : ""

                    let slot = PersonSlot(
                        id: nextSlotID,
                        embedding: embedding,
                        norm: norm,
                        center: data.center,
                        boundingBox: data.boundingBox
                    )
                    activeSlots.append(slot)
                    Log.print("[NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID)): Bootstrap, norm=\(String(format: "%.2f", norm))\(qualityTag)")
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
                        norm: faceNorm
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
                        let oldNorm = activeSlots[idx].norm
                        activeSlots[idx].embedding = embedding
                        activeSlots[idx].norm = norm
                        Log.print("[KeepBest] Slot(\(slotID)): norm \(String(format: "%.2f", oldNorm)) -> \(String(format: "%.2f", norm))")
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
                    Log.print("[Match] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.3f", cost)), norm=\(String(format: "%.2f", candidate.norm)) (Confident)")

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
                        Log.print("[GreyMatch] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.3f", cost)), PosNorm=\(String(format: "%.2f", posNorm)), norm=\(String(format: "%.2f", candidate.norm))")

                        // Keep Best + 위치 갱신
                        updateSlotIfBetter(slotID: candidate.slotID, embedding: candidate.embedding, norm: candidate.norm, center: candidate.center, boundingBox: candidate.boundingBox)
                    } else {
                        Log.print("[GreyReject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.3f", cost)), PosNorm=\(String(format: "%.2f", posNorm))")
                    }
                } else {
                    // 거절 구간
                    Log.print("[Reject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.3f", cost))")
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
                    Log.print("[LowQMatch] Face(\(faceIdx)) -> Slot(\(bestByPos.slotID)): Cost=\(String(format: "%.3f", cost)), PosNorm=\(String(format: "%.2f", posNorm)), norm=\(String(format: "%.2f", bestByPos.norm)) (PositionFirst)")

                    // 위치만 갱신 (저품질 임베딩으로 슬롯 임베딩 갱신 X, norm 0 전달)
                    updateSlotIfBetter(slotID: bestByPos.slotID, embedding: [], norm: 0, center: bestByPos.center, boundingBox: bestByPos.boundingBox)
                } else {
                    Log.print("[LowQReject] Face(\(faceIdx)) -> Slot(\(bestByPos.slotID)): Cost=\(String(format: "%.3f", cost)), PosNorm=\(String(format: "%.2f", posNorm)), norm=\(String(format: "%.2f", bestByPos.norm)) (limit: pos<\(String(format: "%.2f", lowQualityPosLimit)), cost<\(String(format: "%.2f", lowQualityCostLimit)))")
                }
            }

            // === Step 6: 신규 슬롯 등록 (저품질 필터 적용) ===
            // 결정성 보장: faceIdx 정렬 순서로 처리
            for faceIdx in faceEmbeddings.keys.sorted() {
                guard let embedding = faceEmbeddings[faceIdx],
                      !usedFaces.contains(faceIdx) else { continue }
                guard activeSlots.count < maxSlots else {
                    Log.print("[Unassigned] Face(\(faceIdx)): Max slots reached")
                    continue
                }
                guard let data = faceData[faceIdx] else { continue }

                // Extended fallback 얼굴은 신규 슬롯 생성 금지 (기존 슬롯 매칭만 허용)
                if visionFallbackFaces.contains(faceIdx) {
                    Log.print("[ExtendedSkip] Face(\(faceIdx)): Extended fallback face, skip new slot (position-only matching in Step 7)")
                    continue
                }

                // norm 계산
                let norm = faceNorms[faceIdx] ?? sqrt(embedding.reduce(0) { $0 + $1 * $1 })

                // 저품질 얼굴은 신규 슬롯 생성 금지
                if norm < minEmbeddingNorm {
                    Log.print("[LowQuality] Face(\(faceIdx)): norm=\(String(format: "%.2f", norm)) < \(minEmbeddingNorm), skip new slot")
                    continue
                }

                // 기존 슬롯들과의 최소 cost 계산 (디버그용)
                var minCost: Float = Float.infinity
                var minCostSlotID: Int = -1
                for slot in activeSlots {
                    let similarity = sface.cosineSimilarity(embedding, slot.embedding)
                    let cost = 1.0 - similarity
                    if cost < minCost {
                        minCost = cost
                        minCostSlotID = slot.id
                    }
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

                // 상세 로그: 왜 기존 슬롯과 매칭되지 않았는지
                if minCostSlotID > 0 {
                    Log.print("[NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID)): norm=\(String(format: "%.2f", norm)), minCost=\(String(format: "%.3f", minCost)) to Slot(\(minCostSlotID)) (threshold=\(String(format: "%.3f", rejectThreshold)))")
                } else {
                    Log.print("[NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID)): Bootstrap, norm=\(String(format: "%.2f", norm))")
                }
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
                    Log.print("[VisionFallbackMatch] Face(\(faceIdx)) -> Slot(\(match.id)): PosNorm=\(String(format: "%.2f", match.posNorm)) (position-only)")

                    // 위치만 갱신 (임베딩 없으므로 norm=0)
                    updateSlotIfBetter(slotID: match.id, embedding: [], norm: 0, center: data.center, boundingBox: data.boundingBox)
                } else {
                    Log.print("[VisionFallbackSkip] Face(\(faceIdx)): No slot within posNorm < \(String(format: "%.2f", visionFallbackPosLimit))")
                }
            }

            result[assetID] = cachedFaces
        }

        return result
    }

    /// 얼굴을 위치 기준으로 정렬합니다.
    ///
    /// 정렬 기준: X좌표 오름차순 (좌→우), X 동일 시 Y좌표 내림차순 (위→아래)
    ///
    /// - Parameter faces: 정렬할 얼굴 배열
    /// - Returns: 정렬된 얼굴 배열
    private func sortFacesByPosition(_ faces: [DetectedFace]) -> [DetectedFace] {
        return faces.sorted { face1, face2 in
            let xDiff = abs(face1.boundingBox.origin.x - face2.boundingBox.origin.x)

            if xDiff > 0.05 {
                // X가 충분히 다르면 X 기준
                return face1.boundingBox.origin.x < face2.boundingBox.origin.x
            } else {
                // X가 비슷하면 Y 기준 (위가 먼저 = Y 큰 게 먼저)
                return face1.boundingBox.origin.y > face2.boundingBox.origin.y
            }
        }
    }

    /// 감지된 얼굴에 인물 번호를 부여합니다. (단일 사진용, 레거시)
    ///
    /// 정렬 기준: X좌표 오름차순 (좌→우), X 동일 시 Y좌표 내림차순 (위→아래)
    ///
    /// - Parameter faces: 감지된 얼굴 배열
    /// - Returns: 인물 번호가 부여된 CachedFace 배열
    private func assignPersonIndices(faces: [DetectedFace]) -> [CachedFace] {
        let sorted = sortFacesByPosition(faces)

        return sorted.enumerated().map { index, face in
            CachedFace(
                boundingBox: face.boundingBox,
                personIndex: index + 1,  // 1-based
                isValidSlot: false        // 나중에 갱신
            )
        }
    }

    // MARK: - Private Methods - UI

    /// 예상 뷰어 크기를 반환합니다.
    ///
    /// - Returns: 뷰어 크기 (iPad 분할 모드 반영)
    private func getExpectedViewerSize() -> CGSize {
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            return window.bounds.size
        }
        return UIScreen.main.bounds.size
    }

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

    // MARK: - Debug Test API

    /// Vision fallback 비교 테스트용 API (OFF vs Basic)
    ///
    /// 동일한 사진에 대해 Vision fallback OFF/Basic으로 매칭을 실행하고 결과를 비교합니다.
    ///
    /// - Parameters:
    ///   - photos: 테스트할 PHAsset 배열
    ///   - rawFacesMap: Vision 얼굴 감지 결과 (assetID → [DetectedFace])
    /// - Returns: (fallbackOff: 결과, fallbackBasic: 결과)
    func testVisionFallback(
        photos: [PHAsset],
        rawFacesMap: [String: [DetectedFace]]
    ) async -> (fallbackOff: [String: [CachedFace]], fallbackOn: [String: [CachedFace]]) {
        let assetIDs = photos.map { $0.localIdentifier }

        // Vision fallback OFF
        let resultOff = await assignPersonIndicesForGroup(
            rawFacesMap: rawFacesMap,
            assetIDs: assetIDs,
            photos: photos,
            visionFallbackMode: .off
        )

        // Vision fallback Basic
        let resultOn = await assignPersonIndicesForGroup(
            rawFacesMap: rawFacesMap,
            assetIDs: assetIDs,
            photos: photos,
            visionFallbackMode: .basic
        )

        return (fallbackOff: resultOff, fallbackOn: resultOn)
    }

    /// Vision fallback 확장 비교 테스트용 API (Basic vs Extended)
    ///
    /// 동일한 사진에 대해 Vision fallback Basic/Extended로 매칭을 실행하고 결과를 비교합니다.
    /// Extended는 YuNet이 놓친 작은 얼굴(width < 0.07)을 IoU 기반으로 추가합니다.
    ///
    /// - Parameters:
    ///   - photos: 테스트할 PHAsset 배열
    ///   - rawFacesMap: Vision 얼굴 감지 결과 (assetID → [DetectedFace])
    /// - Returns: (basic: 결과, extended: 결과)
    func testVisionFallbackExtended(
        photos: [PHAsset],
        rawFacesMap: [String: [DetectedFace]]
    ) async -> (basic: [String: [CachedFace]], extended: [String: [CachedFace]]) {
        let assetIDs = photos.map { $0.localIdentifier }

        // Vision fallback Basic
        let resultBasic = await assignPersonIndicesForGroup(
            rawFacesMap: rawFacesMap,
            assetIDs: assetIDs,
            photos: photos,
            visionFallbackMode: .basic
        )

        // Vision fallback Extended
        let resultExtended = await assignPersonIndicesForGroup(
            rawFacesMap: rawFacesMap,
            assetIDs: assetIDs,
            photos: photos,
            visionFallbackMode: .extended
        )

        return (basic: resultBasic, extended: resultExtended)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

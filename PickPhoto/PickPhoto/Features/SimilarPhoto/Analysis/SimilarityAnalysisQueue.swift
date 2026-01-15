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
    /// Keep First 정책: 슬롯 최초 생성 시의 임베딩을 유지
    private struct PersonSlot {
        let id: Int                // 슬롯 ID (1-based)
        let embedding: [Float]     // 128차원 SFace 임베딩
        let center: CGPoint        // 최초 등록 시 위치
        let boundingBox: CGRect    // 최초 등록 시 바운딩박스
    }

    /// 매칭 후보 (전역 정렬용)
    private struct MatchCandidate {
        let faceIdx: Int
        let slotID: Int
        let cost: Float           // Dist_fp
        let posDistNorm: CGFloat  // Dist_pos / √2
        let boundingBox: CGRect
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
                print("[FaceMatching] Photo \(assetID.prefix(8)): Model not available, skipping embedding")
                result[assetID] = []
                continue
            }

            // YuNet으로 얼굴 감지 (landmark 포함)
            guard let yunetDetections = try? yunet.detect(in: image) else {
                print("[FaceMatching] Photo \(assetID.prefix(8)): YuNet detection failed")
                result[assetID] = []
                continue
            }

            for (faceIdx, detection) in yunetDetections.enumerated() {
                // normalized 좌표로 변환 (Vision과 동일한 좌표계)
                let imageWidth = CGFloat(image.width)
                let imageHeight = CGFloat(image.height)
                let normalizedBox = CGRect(
                    x: detection.boundingBox.origin.x / imageWidth,
                    y: detection.boundingBox.origin.y / imageHeight,
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
                    print("[AlignFail] Face(\(faceIdx)): Alignment failed")
                    continue
                }

                // SFace로 임베딩 추출
                do {
                    let embedding = try sface.extractEmbedding(from: alignedFace)
                    faceEmbeddings[faceIdx] = embedding
                } catch {
                    print("[EmbedFail] Face(\(faceIdx)): \(error.localizedDescription)")
                    continue
                }
            }

            print("[FaceMatching] Photo \(assetID.prefix(8)): \(yunetDetections.count) faces (YuNet), Embed: \(faceEmbeddings.count)/\(yunetDetections.count), Slots: \(activeSlots.count)")

            // === Step 2: 부팅 (ActiveSlots 비어있을 때) ===
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

                    let slot = PersonSlot(
                        id: nextSlotID,
                        embedding: embedding,
                        center: data.center,
                        boundingBox: data.boundingBox
                    )
                    activeSlots.append(slot)
                    print("[NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID)): Bootstrap")
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

            for (faceIdx, faceEmbedding) in faceEmbeddings {
                guard let data = faceData[faceIdx] else { continue }

                // 모든 슬롯과 비용 계산 (코사인 유사도를 거리로 변환: cost = 1 - similarity)
                var slotCosts: [(slot: PersonSlot, cost: Float, posDist: CGFloat)] = []

                for slot in activeSlots {
                    let similarity = sface.cosineSimilarity(faceEmbedding, slot.embedding)
                    let cost = 1.0 - similarity  // 유사도를 거리로 변환 (낮을수록 동일인)
                    let posDist = hypot(data.center.x - slot.center.x, data.center.y - slot.center.y)
                    slotCosts.append((slot: slot, cost: cost, posDist: posDist))
                }

                // Top-K 필터링: 슬롯 수 > 5개면 상위 3개만 (근사 최적화)
                let candidates: ArraySlice<(slot: PersonSlot, cost: Float, posDist: CGFloat)>
                if activeSlots.count > 5 {
                    candidates = slotCosts.sorted { $0.cost < $1.cost }.prefix(3)
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
                        boundingBox: data.boundingBox
                    ))
                }
            }

            // === Step 4: 전역 정렬 (Cost 오름차순) ===
            allCandidates.sort { $0.cost < $1.cost }

            // === Step 5: 매칭 확정 (Grey Zone 적용) ===
            var usedFaces: Set<Int> = []
            var usedSlots: Set<Int> = []
            var cachedFaces: [CachedFace] = []

            for candidate in allCandidates {
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
                        isValidSlot: false
                    ))
                    print("[Match] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost)) (Confident)")

                } else if cost < rejectThreshold {
                    // 모호 구간: 위치 조건 확인
                    if posNorm < greyZonePosLimit {
                        usedFaces.insert(candidate.faceIdx)
                        usedSlots.insert(candidate.slotID)
                        cachedFaces.append(CachedFace(
                            boundingBox: candidate.boundingBox,
                            personIndex: candidate.slotID,
                            isValidSlot: false
                        ))
                        print("[GreyMatch] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost)), PosNorm=\(String(format: "%.2f", posNorm))")
                    } else {
                        print("[GreyReject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost)), PosNorm=\(String(format: "%.2f", posNorm))")
                    }
                } else {
                    // 거절 구간
                    print("[Reject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost))")
                }
            }

            // === Step 6: 신규 슬롯 등록 ===
            for (faceIdx, embedding) in faceEmbeddings {
                guard !usedFaces.contains(faceIdx) else { continue }
                guard activeSlots.count < maxSlots else {
                    print("[Unassigned] Face(\(faceIdx)): Max slots reached")
                    continue
                }
                guard let data = faceData[faceIdx] else { continue }

                // 신규 슬롯 생성
                let slot = PersonSlot(
                    id: nextSlotID,
                    embedding: embedding,
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

                print("[NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID))")
                nextSlotID += 1
            }

            // 임베딩 없는 얼굴은 CachedFace에 저장하지 않음 (캐시 미저장 정책)

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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

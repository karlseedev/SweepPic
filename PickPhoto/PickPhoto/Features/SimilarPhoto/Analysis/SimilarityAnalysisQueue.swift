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
    func formGroupsForRange(
        _ range: ClosedRange<Int>,
        source: AnalysisSource,
        fetchResult: PHFetchResult<PHAsset>
    ) async -> [String] {
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
        let featurePrints = await generateFeaturePrints(for: photos)

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

            // 그룹 단위로 일관된 personIndex 할당 (위치 기반 매칭)
            let photoFacesMap = assignPersonIndicesForGroup(
                rawFacesMap: rawFacesMap,
                assetIDs: groupAssetIDs
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

            // T014.7: 캐시 저장 요청 (T010 호출)
            if let groupID = await cache.addGroupIfValid(
                members: groupAssetIDs,
                validSlots: validSlots,
                photoFaces: photoFacesMap
            ) {
                validGroupIDs.append(groupID)
            }
        }

        // LRU eviction
        await cache.evictIfNeeded()

        // 그룹에 속하지 않은 사진들 상태 업데이트
        let groupedAssetIDs = Set(rawGroups.flatMap { $0 })
        for assetID in assetIDs where !groupedAssetIDs.contains(assetID) {
            await cache.setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
        }

        // T014.8: UI 알림 발송
        postAnalysisComplete(range: range, groupIDs: validGroupIDs, analyzedAssetIDs: assetIDs)

        return validGroupIDs
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

    /// 그룹 단위로 일관된 인물 번호를 부여합니다.
    ///
    /// 연속 촬영 사진에서 동일 위치의 얼굴은 같은 인물로 매칭합니다.
    /// 첫 번째 사진(얼굴이 있는)의 얼굴 위치를 기준 슬롯으로 설정하고,
    /// 다른 사진의 얼굴은 가장 가까운 슬롯에 매핑합니다.
    ///
    /// - Parameters:
    ///   - rawFacesMap: 사진별 감지된 얼굴 (assetID → [DetectedFace])
    ///   - assetIDs: 그룹 멤버 순서 (분석 순서)
    /// - Returns: 일관된 personIndex가 부여된 CachedFace 맵
    private func assignPersonIndicesForGroup(
        rawFacesMap: [String: [DetectedFace]],
        assetIDs: [String]
    ) -> [String: [CachedFace]] {

        // 기준 슬롯 정의: 첫 번째 얼굴 있는 사진의 얼굴 위치들
        var referenceSlots: [(index: Int, center: CGPoint)] = []

        // 얼굴이 있는 첫 번째 사진 찾기
        for assetID in assetIDs {
            guard let faces = rawFacesMap[assetID], !faces.isEmpty else { continue }

            // 위치 정렬 (X 오름차순, Y 내림차순)
            let sorted = sortFacesByPosition(faces)

            // 기준 슬롯 설정
            for (idx, face) in sorted.enumerated() {
                let center = CGPoint(
                    x: face.boundingBox.midX,
                    y: face.boundingBox.midY
                )
                referenceSlots.append((index: idx + 1, center: center))
            }
            break
        }

        // 기준 슬롯이 없으면 빈 결과 반환
        guard !referenceSlots.isEmpty else {
            // 모든 사진에 얼굴 없음 → 빈 CachedFace 배열로 반환
            var result: [String: [CachedFace]] = [:]
            for assetID in assetIDs {
                result[assetID] = []
            }
            return result
        }

        // 각 사진의 얼굴을 기준 슬롯에 매핑
        var result: [String: [CachedFace]] = [:]
        let positionThreshold: CGFloat = 0.15  // 위치 허용 오차 (정규화 좌표 기준)

        for assetID in assetIDs {
            guard let faces = rawFacesMap[assetID] else {
                result[assetID] = []
                continue
            }

            var cachedFaces: [CachedFace] = []

            for face in faces {
                let faceCenter = CGPoint(
                    x: face.boundingBox.midX,
                    y: face.boundingBox.midY
                )

                // 가장 가까운 기준 슬롯 찾기
                var bestSlot: Int? = nil
                var bestDistance: CGFloat = .infinity

                for slot in referenceSlots {
                    let distance = hypot(faceCenter.x - slot.center.x, faceCenter.y - slot.center.y)
                    if distance < bestDistance && distance < positionThreshold {
                        bestDistance = distance
                        bestSlot = slot.index
                    }
                }

                // 매칭되는 슬롯이 없으면 이 얼굴은 스킵 (유효 슬롯에 포함되지 않음)
                // 연속 촬영이 아닌 사진에서 다른 위치의 얼굴은 무시
                guard let personIndex = bestSlot else { continue }

                cachedFaces.append(CachedFace(
                    boundingBox: face.boundingBox,
                    personIndex: personIndex,
                    isValidSlot: false  // 나중에 갱신
                ))
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

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}

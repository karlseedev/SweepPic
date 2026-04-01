//
//  FaceScanService+Pipeline.swift
//  SweepPic
//
//  인물사진 비교정리 — 분석 파이프라인
//
//  청크 단위 분석 로직:
//  1. Feature Print 생성 + 얼굴 유무 확인
//  2. 그룹 형성 (인접 거리 기반)
//  3. 얼굴 감지 + 인물 매칭 (YuNet + SFace)
//  4. 유효 슬롯 계산
//  5. FaceScanCache에 저장
//
//  개별 분석기(SimilarityAnalyzer, YuNet, SFace, FaceAligner)를
//  직접 조합하여 독립적인 파이프라인을 구성합니다.
//  기존 SimilarityAnalysisQueue의 private 메서드를 재현하되,
//  배치 분석에 최적화된 구조입니다.
//

import Foundation
import Photos
import Vision
import AppCore
import OSLog

// MARK: - Pipeline

extension FaceScanService {

    /// 청크 분석 실행
    ///
    /// 주어진 사진 배열에서 유사 인물 그룹을 형성하고 FaceScanCache에 저장합니다.
    ///
    /// - Parameter photos: 분석 대상 PHAsset 배열 (최소 3장)
    /// - Returns: 발견된 그룹 배열
    func analyzeChunk(photos: [PHAsset]) async -> [FaceScanGroup] {
        let assetIDs = photos.map { $0.localIdentifier }

        // ── Step 1: Feature Print 생성 + 얼굴 유무 확인 ──
        let (featurePrints, hasFaces) = await generateFeaturePrints(for: photos)

        // 취소 체크
        guard !cancelled else { return [] }

        // ── Step 2: 그룹 형성 (인접 거리 기반) ──
        let rawGroups = analyzer.formGroups(
            featurePrints: featurePrints,
            photoIDs: assetIDs,
            threshold: SimilarityConstants.similarityThreshold
        )

        guard !rawGroups.isEmpty else { return [] }

        // 취소 체크
        guard !cancelled else { return [] }

        // ── Step 3~5: 각 그룹별 얼굴 감지 + 인물 매칭 + 유효 슬롯 계산 ──
        var results: [FaceScanGroup] = []

        for groupAssetIDs in rawGroups {
            guard !cancelled else { return results }

            // 얼굴 있는 사진만 포함된 그룹인지 확인
            let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }
            let hasAnyFace = groupAssetIDs.enumerated().contains { idx, id in
                guard let photoIndex = assetIDs.firstIndex(of: id) else { return false }
                return hasFaces[photoIndex]
            }

            // 얼굴이 하나도 없는 그룹은 스킵
            guard hasAnyFace else { continue }

            // 인물 매칭 실행
            let photoFacesMap = await assignPersonIndices(
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

            // 유효 슬롯이 없으면 스킵
            guard !validSlots.isEmpty else { continue }

            // 유효 슬롯 얼굴이 있는 사진만 그룹 멤버로 인정
            let validMembers = groupAssetIDs.filter { assetID in
                guard let faces = photoFacesMap[assetID] else { return false }
                return faces.contains { validSlots.contains($0.personIndex) }
            }

            // 최소 그룹 크기 확인
            guard validMembers.count >= SimilarityConstants.minGroupSize else { continue }

            // 유효 슬롯 정보를 얼굴에 반영
            var updatedPhotoFaces: [String: [CachedFace]] = [:]
            for (assetID, faces) in photoFacesMap {
                updatedPhotoFaces[assetID] = faces.map { face in
                    var updated = face
                    updated.isValidSlot = validSlots.contains(face.personIndex)
                    return updated
                }
            }

            // FaceScanCache에 저장
            let group = SimilarThumbnailGroup(memberAssetIDs: validMembers)
            await cache.addGroup(group, validSlots: validSlots, photoFaces: updatedPhotoFaces)

            // FaceScanGroup 생성 (FaceScanListVC용)
            let scanGroup = FaceScanGroup(
                groupID: group.groupID,
                memberAssetIDs: validMembers,
                validPersonIndices: validSlots
            )
            results.append(scanGroup)
        }

        return results
    }

    // MARK: - Step 1: Feature Print 생성

    /// 모든 사진의 Feature Print를 병렬 생성하고 얼굴 유무를 확인합니다.
    ///
    /// SimilarityAnalysisQueue.generateFeaturePrints() 패턴 재현
    private func generateFeaturePrints(
        for photos: [PHAsset]
    ) async -> (featurePrints: [VNFeaturePrintObservation?], hasFaces: [Bool]) {
        var featurePrints: [VNFeaturePrintObservation?] = Array(repeating: nil, count: photos.count)
        var hasFaces: [Bool] = Array(repeating: false, count: photos.count)

        // AsyncSemaphore 대신 TaskGroup으로 동시성 제한
        let maxConcurrent = ProcessInfo.processInfo.thermalState.rawValue >= ProcessInfo.ThermalState.serious.rawValue
            ? FaceScanConstants.maxConcurrentAnalysisThermal
            : FaceScanConstants.maxConcurrentAnalysis

        // 배치 처리 (동시성 제한)
        for batchStart in stride(from: 0, to: photos.count, by: maxConcurrent) {
            let batchEnd = min(batchStart + maxConcurrent, photos.count)

            await withTaskGroup(of: (Int, VNFeaturePrintObservation?, Bool).self) { group in
                for i in batchStart..<batchEnd {
                    let asset = photos[i]
                    let loader = self.imageLoader
                    let fpAnalyzer = self.analyzer
                    group.addTask {
                        do {
                            // 이미지 로딩 (480px)
                            let image = try await loader.loadImage(
                                for: asset,
                                maxSize: CGFloat(FaceScanConstants.analysisImageMaxSize)
                            )

                            // Feature Print 생성 + 얼굴 유무 (MainActor에서 실행)
                            let result: (VNFeaturePrintObservation, Bool) = try await MainActor.run {
                                let fp = try fpAnalyzer.generateFeaturePrint(for: image)
                                let faceRequest = VNDetectFaceRectanglesRequest()
                                let handler = VNImageRequestHandler(cgImage: image, options: [:])
                                try? handler.perform([faceRequest])
                                let hasFace = !(faceRequest.results?.isEmpty ?? true)
                                return (fp, hasFace)
                            }
                            return (i, result.0, result.1)
                        } catch {
                            Logger.similarPhoto.debug("FaceScan FP 생성 실패 [\(i)]: \(error.localizedDescription)")
                            return (i, nil, false)
                        }
                    }
                }

                for await (index, fp, face) in group {
                    featurePrints[index] = fp
                    hasFaces[index] = face
                }
            }
        }

        return (featurePrints, hasFaces)
    }

    // MARK: - Step 3: 인물 매칭

    /// 그룹 내 사진들의 얼굴을 감지하고 인물 번호를 할당합니다.
    ///
    /// SimilarityAnalysisQueue.assignPersonIndicesForGroup() 패턴 재현
    private func assignPersonIndices(
        assetIDs: [String],
        photos: [PHAsset]
    ) async -> [String: [CachedFace]] {
        guard let detector = faceDetector, let recognizer = faceRecognizer else {
            Logger.similarPhoto.error("FaceScan: YuNet 또는 SFace 초기화 실패")
            return [:]
        }

        var photoFacesMap: [String: [CachedFace]] = [:]

        // 인물 슬롯 관리: personIndex → [임베딩]
        var personEmbeddings: [Int: [[Float]]] = [:]
        var nextPersonIndex = 1

        for (photoIdx, asset) in photos.enumerated() {
            guard !cancelled else { return photoFacesMap }

            let assetID = asset.localIdentifier

            do {
                // 고해상도 이미지 로딩 (960px)
                let image = try await imageLoader.loadImage(
                    for: asset,
                    maxSize: CGFloat(FaceScanConstants.personMatchImageMaxSize)
                )

                // YuNet 얼굴 감지
                let detections = try detector.detect(in: image)

                guard !detections.isEmpty else {
                    photoFacesMap[assetID] = []
                    continue
                }

                var faces: [CachedFace] = []

                for detection in detections {
                    // 얼굴 정렬 (112×112)
                    guard let alignedFace = try? faceAligner.align(
                        image: image,
                        landmarks: detection.landmarks
                    ) else { continue }

                    // 임베딩 추출
                    guard let embedding = try? recognizer.extractEmbedding(from: alignedFace) else {
                        continue
                    }

                    // 인물 매칭: 기존 슬롯과 비교
                    var matchedPersonIndex: Int?
                    var bestScore: Float = 0

                    for (personIdx, embeddings) in personEmbeddings {
                        for refEmbedding in embeddings {
                            let result = recognizer.isSamePerson(embedding, refEmbedding)
                            if result.isSame && result.score > bestScore {
                                bestScore = result.score
                                matchedPersonIndex = personIdx
                            }
                        }
                    }

                    let personIndex: Int
                    if let matched = matchedPersonIndex {
                        personIndex = matched
                        // 임베딩 추가 (참조 데이터 강화)
                        personEmbeddings[matched, default: []].append(embedding)
                    } else {
                        // 새 인물 슬롯 할당
                        personIndex = nextPersonIndex
                        nextPersonIndex += 1
                        personEmbeddings[personIndex] = [embedding]

                        // 슬롯 상한 체크
                        if nextPersonIndex > SimilarityConstants.maxPersonSlots {
                            break
                        }
                    }

                    // CachedFace 생성
                    // Vision 정규화 좌표로 변환 (원점 좌하단)
                    let imageSize = CGSize(width: image.width, height: image.height)
                    let normalizedBox = CGRect(
                        x: detection.boundingBox.origin.x / imageSize.width,
                        y: 1.0 - (detection.boundingBox.origin.y + detection.boundingBox.height) / imageSize.height,
                        width: detection.boundingBox.width / imageSize.width,
                        height: detection.boundingBox.height / imageSize.height
                    )

                    let cachedFace = CachedFace(
                        boundingBox: normalizedBox,
                        personIndex: personIndex,
                        isValidSlot: false,  // 나중에 유효 슬롯 계산 시 업데이트
                        sfaceCost: bestScore > 0 ? (1.0 - bestScore) : nil
                    )
                    faces.append(cachedFace)
                }

                photoFacesMap[assetID] = faces

                // 얼굴 데이터를 캐시에도 저장 (FaceComparisonVC가 조회할 수 있도록)
                await cache.setFaces(faces, for: assetID)

            } catch {
                Logger.similarPhoto.debug("FaceScan 인물 매칭 실패 [\(assetID)]: \(error.localizedDescription)")
                photoFacesMap[assetID] = []
            }
        }

        return photoFacesMap
    }
}

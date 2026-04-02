//
//  FaceScanService+Pipeline.swift
//  SweepPic
//
//  인물사진 비교정리 — 분석 파이프라인
//
//  청크 단위 분석 로직:
//  1. Feature Print 생성 + 얼굴 유무 확인 (PersonMatchingEngine)
//  2. 그룹 형성 (인접 거리 기반, SimilarityAnalyzer)
//  3. 얼굴 감지 + 인물 매칭 (PersonMatchingEngine)
//  4. 유효 슬롯 계산
//  5. FaceScanCache에 저장
//
//  PersonMatchingEngine을 통해 SimilarityAnalysisQueue와 동일한
//  분석 로직을 사용합니다 (분석 결과 일관성 보장).
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

        // ── Step 1: Feature Print 생성 + 얼굴 유무 확인 (PersonMatchingEngine) ──
        let (featurePrints, hasFaces) = await matchingEngine.generateFeaturePrints(for: photos)

        // 취소 체크
        guard !cancelled else { return [] }

        // ── Step 2: 그룹 형성 (인접 거리 기반, SimilarityAnalyzer) ──
        let rawGroups = matchingEngine.analyzer.formGroups(
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

            // 인물 매칭 실행 (PersonMatchingEngine — 경로 A와 동일한 알고리즘)
            let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
                assetIDs: groupAssetIDs,
                photos: groupPhotos
            )

            // 얼굴 데이터를 캐시에 저장 (FaceComparisonVC가 조회할 수 있도록)
            for (assetID, faces) in photoFacesMap {
                await cache.setFaces(faces, for: assetID)
            }

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
}

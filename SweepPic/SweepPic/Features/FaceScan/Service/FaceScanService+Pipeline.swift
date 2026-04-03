//
//  FaceScanService+Pipeline.swift
//  SweepPic
//
//  인물사진 비교정리 — 단일 그룹 처리 파이프라인
//
//  IncrementalGroupBuilder가 확정한 그룹에 대해:
//  1. 얼굴 감지 + 인물 매칭 (PersonMatchingEngine)
//  2. 유효 슬롯 계산
//  3. FaceScanCache에 저장
//
//  PersonMatchingEngine을 통해 SimilarityAnalysisQueue(경로 A)와
//  동일한 분석 로직을 사용합니다 (분석 결과 일관성 보장).
//
//  이전 구조(analyzeChunk + overlap + excludeAssets)에서 변경됨:
//  IncrementalGroupBuilder가 배치 간 상태를 유지하므로
//  overlap/excludeAssets가 불필요합니다.
//

import Foundation
import Photos
import Vision
import AppCore
import OSLog

// MARK: - Pipeline

extension FaceScanService {

    /// 확정된 그룹에 대해 얼굴 감지 + 인물 매칭 + 캐시 저장을 수행합니다.
    ///
    /// IncrementalGroupBuilder가 확정한 그룹을 받아서 처리합니다.
    /// 기존 analyzeChunk의 Step 3~5에 해당합니다.
    /// hasAnyFace 게이트 없음 — Grid(경로 A)와 동일하게 모든 그룹을 YuNet/SFace로 처리.
    ///
    /// - Parameters:
    ///   - groupAssetIDs: 확정된 그룹의 assetID 배열
    ///   - assetMap: assetID → PHAsset 매핑 (배치에서 누적)
    /// - Returns: FaceScanGroup 또는 nil (유효 슬롯 없음)
    func processCompletedGroup(
        groupAssetIDs: [String],
        assetMap: [String: PHAsset]
    ) async -> FaceScanGroup? {
        guard !cancelled else { return nil }

        // PHAsset 조회 (배치에서 누적한 맵 사용, 재조회 없음, 순서 보장)
        let groupPhotos: [PHAsset] = groupAssetIDs.compactMap { assetMap[$0] }
        guard groupPhotos.count >= SimilarityConstants.minGroupSize else { return nil }

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
        guard !validSlots.isEmpty else { return nil }

        // 유효 슬롯 얼굴이 있는 사진만 그룹 멤버로 인정
        let validMembers = groupAssetIDs.filter { assetID in
            guard let faces = photoFacesMap[assetID] else { return false }
            return faces.contains { validSlots.contains($0.personIndex) }
        }

        // 최소 그룹 크기 확인
        guard validMembers.count >= SimilarityConstants.minGroupSize else { return nil }

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

        return FaceScanGroup(
            groupID: group.groupID,
            memberAssetIDs: validMembers,
            validPersonIndices: validSlots
        )
    }
}

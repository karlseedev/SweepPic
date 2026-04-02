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
    /// 2단계 필터링으로 청크 overlap에 의한 중복 그룹을 방지합니다.
    ///
    /// - Parameters:
    ///   - photos: 분석 대상 PHAsset 배열 (최소 3장)
    ///   - excludeAssets: 이전 청크에서 이미 그룹에 포함된 assetID (중복 방지용)
    /// - Returns: 발견된 그룹 배열
    func analyzeChunk(photos: [PHAsset], excludeAssets: Set<String>) async -> [FaceScanGroup] {
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

        // ── Step 2.5: 사전 필터 — 이미 발견된 assetID와 겹치는 그룹 제거 ──
        // 새 멤버(이전 청크에서 미발견)가 최소 그룹 크기 미만이면 스킵
        // → 순수 중복 그룹을 비싼 얼굴 매칭 전에 제거 (성능 최적화)
        // 통과한 그룹은 원본 전체(overlap 포함)로 얼굴 매칭 실행 (정확도 유지)
        let filteredGroups = rawGroups.compactMap { groupAssetIDs -> [String]? in
            let newMembers = groupAssetIDs.filter { !excludeAssets.contains($0) }
            return newMembers.count >= SimilarityConstants.minGroupSize ? groupAssetIDs : nil
        }

        guard !filteredGroups.isEmpty else { return [] }

        // ── Step 3~5: 각 그룹별 얼굴 감지 + 인물 매칭 + 유효 슬롯 계산 ──
        var results: [FaceScanGroup] = []

        for groupAssetIDs in filteredGroups {
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

            // ── Step 5.5: overlap 멤버 제거 (중복 방지 핵심) ──
            // 얼굴 매칭은 전체 멤버(overlap 포함)로 실행했지만,
            // 결과에서 이전 청크에서 이미 발견된 사진은 제거
            let finalMembers = validMembers.filter { !excludeAssets.contains($0) }
            guard finalMembers.count >= SimilarityConstants.minGroupSize else { continue }

            // 유효 슬롯 정보를 얼굴에 반영
            var updatedPhotoFaces: [String: [CachedFace]] = [:]
            for (assetID, faces) in photoFacesMap {
                updatedPhotoFaces[assetID] = faces.map { face in
                    var updated = face
                    updated.isValidSlot = validSlots.contains(face.personIndex)
                    return updated
                }
            }

            // FaceScanCache에 저장 (finalMembers — overlap 제거된 최종 멤버)
            let group = SimilarThumbnailGroup(memberAssetIDs: finalMembers)
            await cache.addGroup(group, validSlots: validSlots, photoFaces: updatedPhotoFaces)

            // FaceScanGroup 생성 (FaceScanListVC용, finalMembers 사용)
            let scanGroup = FaceScanGroup(
                groupID: group.groupID,
                memberAssetIDs: finalMembers,
                validPersonIndices: validSlots
            )
            results.append(scanGroup)
        }

        return results
    }
}

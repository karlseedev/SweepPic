//
//  FaceScanCache.swift
//  SweepPic
//
//  인물사진 비교정리 — 읽기 전용 조회 캐시
//  SimilarityCacheProtocol(읽기 전용)을 준수하는 경량 캐시.
//  기존 SimilarityCache.shared와 완전 격리 — 기존 그리드/뷰어 분석에 영향 제로.
//  쓰기(removeMemberFromGroup)는 불필요 — FaceScan은 diff 기반 삭제/복원 사용.
//
//  생명주기: FaceScanListVC가 소유 → 화면 닫히면 자연스럽게 해제
//

import Foundation

/// FaceScan 전용 읽기 전용 조회 캐시
///
/// FaceComparisonVC가 `cache: any SimilarityCacheProtocol` 파라미터로 받아서
/// 얼굴 데이터, 그룹 멤버, 유효 슬롯을 조회합니다.
/// 기존 `SimilarityCache.shared`를 대체하여 주입됩니다.
/// 쓰기(removeMemberFromGroup)는 미채택 — .faceScan 모드는 diff 기반 삭제.
actor FaceScanCache: SimilarityCacheProtocol {

    // MARK: - 저장소

    /// 그룹 정보 (groupID → SimilarThumbnailGroup)
    private var groups: [String: SimilarThumbnailGroup] = [:]

    /// 사진별 얼굴 캐시 (assetID → [CachedFace])
    private var faces: [String: [CachedFace]] = [:]

    /// 그룹별 유효 인물 슬롯 (groupID → Set<Int>)
    private var validSlots: [String: Set<Int>] = [:]

    // MARK: - SimilarityCacheProtocol 구현

    /// 특정 사진의 캐시된 얼굴 정보를 조회합니다.
    func getFaces(for assetID: String) -> [CachedFace] {
        return faces[assetID] ?? []
    }

    /// 그룹별 유효 인물 슬롯을 조회합니다.
    func getGroupValidPersonIndices(for groupID: String) -> Set<Int> {
        return validSlots[groupID] ?? []
    }

    /// 그룹 멤버 목록을 조회합니다.
    func getGroupMembers(groupID: String) -> [String] {
        return groups[groupID]?.memberAssetIDs ?? []
    }

    // MARK: - FaceScanService 전용 저장 메서드

    /// 분석 결과를 캐시에 저장합니다.
    ///
    /// FaceScanService가 각 청크 분석 완료 후 호출합니다.
    /// - Parameters:
    ///   - group: 유사 사진 그룹
    ///   - slots: 유효 인물 슬롯 번호
    ///   - photoFaces: 사진별 얼굴 정보
    func addGroup(
        _ group: SimilarThumbnailGroup,
        validSlots slots: Set<Int>,
        photoFaces: [String: [CachedFace]]
    ) {
        // 그룹 저장
        groups[group.groupID] = group

        // 유효 슬롯 저장
        validSlots[group.groupID] = slots

        // 얼굴 정보 저장
        for (assetID, faceList) in photoFaces {
            faces[assetID] = faceList
        }
    }

    /// 특정 사진의 얼굴 정보를 저장합니다.
    func setFaces(_ faceList: [CachedFace], for assetID: String) {
        faces[assetID] = faceList
    }

    // MARK: - 조회 헬퍼

    /// 그룹 정보를 조회합니다.
    func getGroup(groupID: String) -> SimilarThumbnailGroup? {
        return groups[groupID]
    }
}

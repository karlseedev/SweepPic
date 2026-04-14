//
//  FaceScanGroup.swift
//  SweepPic
//
//  인물사진 비교정리 — 그룹 데이터 모델
//  FaceScanListVC가 보유하는 그룹 정보.
//  FaceScanService의 onGroupFound 콜백으로 전달됨.
//  SimilarityCache와 독립적으로 관리 (캐시 무효화와 무관하게 재진입 가능).
//

import Foundation

/// 인물사진 비교정리 그룹 데이터
///
/// FaceScanListVC가 콜백으로 받아 배열로 보유합니다.
/// 재진입 시 이 데이터에서 ComparisonGroup을 생성합니다.
struct FaceScanGroup {

    /// 그룹 고유 식별자 (UUID 기반)
    let groupID: String

    /// 원본 멤버 목록 (PHAsset.localIdentifier 배열)
    /// - 캐시 무효화와 무관하게 원본 유지
    /// - 최소 3장
    let memberAssetIDs: [String]

    /// 유효 인물 슬롯 번호 (2장 이상 동일인이 있는 personIndex)
    let validPersonIndices: Set<Int>

    /// 그룹 멤버 수
    var memberCount: Int { memberAssetIDs.count }
}

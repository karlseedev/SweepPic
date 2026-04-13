//
//  SimilarPhotoGroup.swift
//  SweepPic
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 SweepPic. All rights reserved.
//
//  Description:
//  유사 사진 그룹 관련 모델을 정의합니다.
//  - SimilarThumbnailGroup: 그리드 테두리/뷰어 +버튼용 그룹 (크기 제한 없음)
//  - ComparisonGroup: 얼굴 비교 화면용 그룹 (그룹 전체 멤버)
//

import Foundation

// MARK: - SimilarThumbnailGroup

/// 그리드 테두리 및 뷰어 +버튼 표시를 위한 유사 사진 그룹
///
/// 분석 완료 후 생성되며, 그리드에서 테두리를 표시하고
/// 뷰어에서 +버튼을 표시하는 데 사용됩니다.
///
/// - Note: 멤버 수에 제한이 없습니다 (최소 3장).
/// - Important: validPersonIndices는 SimilarityCache가 Source of Truth입니다.
struct SimilarThumbnailGroup: Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// 그룹 고유 식별자
    /// - UUID 기반
    let groupID: String

    /// 그룹 소속 사진 ID 목록
    /// - 최소 3장 이상
    /// - PHAsset.localIdentifier
    var memberAssetIDs: [String]

    // MARK: - Computed Properties

    /// 그룹이 유효한지 여부
    /// - 멤버가 3장 이상이면 유효
    nonisolated var isValid: Bool {
        memberAssetIDs.count >= SimilarityConstants.minGroupSize
    }

    /// 그룹 멤버 수
    nonisolated var memberCount: Int {
        memberAssetIDs.count
    }

    // MARK: - Initialization

    /// SimilarThumbnailGroup을 생성합니다.
    ///
    /// - Parameters:
    ///   - groupID: 그룹 고유 식별자 (기본값: 새 UUID 생성)
    ///   - memberAssetIDs: 그룹 소속 사진 ID 목록
    nonisolated init(groupID: String = UUID().uuidString, memberAssetIDs: [String]) {
        self.groupID = groupID
        self.memberAssetIDs = memberAssetIDs
    }

    // MARK: - Mutation

    /// 특정 사진을 그룹에서 제거합니다.
    ///
    /// - Parameter assetID: 제거할 사진 ID
    /// - Returns: 제거 후 그룹이 여전히 유효하면 true
    @discardableResult
    nonisolated mutating func removeMember(_ assetID: String) -> Bool {
        memberAssetIDs.removeAll { $0 == assetID }
        return isValid
    }

    /// 여러 사진을 그룹에서 제거합니다.
    ///
    /// - Parameter assetIDs: 제거할 사진 ID 배열
    /// - Returns: 제거 후 그룹이 여전히 유효하면 true
    @discardableResult
    nonisolated mutating func removeMembers(_ assetIDs: [String]) -> Bool {
        let idsToRemove = Set(assetIDs)
        memberAssetIDs.removeAll { idsToRemove.contains($0) }
        return isValid
    }

    /// 특정 사진이 그룹에 속해있는지 확인합니다.
    ///
    /// - Parameter assetID: 확인할 사진 ID
    /// - Returns: 그룹에 속해있으면 true
    nonisolated func contains(_ assetID: String) -> Bool {
        memberAssetIDs.contains(assetID)
    }
}

// MARK: - ComparisonGroup

/// 얼굴 비교 화면에서 비교할 사진 집합
///
/// +버튼 탭 시 생성되며, 확정된 그룹의 전체 멤버를
/// 원래 순서(시간순)로 포함합니다.
struct ComparisonGroup: Equatable, Sendable {

    // MARK: - Properties

    /// 원본 ThumbnailGroup ID
    let sourceGroupID: String

    /// 비교 대상 사진 ID 목록
    /// - 그룹 전체 멤버 (원래 순서 유지)
    let selectedAssetIDs: [String]

    /// 비교 대상 인물 번호
    /// - +버튼을 탭한 얼굴의 인물 번호
    let personIndex: Int

    // MARK: - Computed Properties

    /// 선택된 사진 수
    nonisolated var count: Int {
        selectedAssetIDs.count
    }

    /// 비어있는지 여부
    nonisolated var isEmpty: Bool {
        selectedAssetIDs.isEmpty
    }

    // MARK: - Initialization

    /// ComparisonGroup을 생성합니다.
    ///
    /// - Parameters:
    ///   - sourceGroupID: 원본 ThumbnailGroup ID
    ///   - selectedAssetIDs: 비교 대상 사진 ID 목록
    ///   - personIndex: 비교 대상 인물 번호
    nonisolated init(sourceGroupID: String, selectedAssetIDs: [String], personIndex: Int) {
        self.sourceGroupID = sourceGroupID
        self.selectedAssetIDs = selectedAssetIDs
        self.personIndex = personIndex
    }

    // MARK: - Static Factory

    /// ThumbnailGroup과 현재 사진에서 ComparisonGroup을 생성합니다.
    ///
    /// 그룹 전체 멤버를 원래 순서(시간순)로 포함합니다.
    ///
    /// - Parameters:
    ///   - thumbnailGroup: 원본 ThumbnailGroup
    ///   - currentAssetID: 현재 보고 있는 사진 ID (미사용, API 호환성 유지)
    ///   - personIndex: 선택한 인물 번호
    /// - Returns: 생성된 ComparisonGroup
    nonisolated static func create(
        from thumbnailGroup: SimilarThumbnailGroup,
        currentAssetID: String,
        personIndex: Int
    ) -> ComparisonGroup {
        return ComparisonGroup(
            sourceGroupID: thumbnailGroup.groupID,
            selectedAssetIDs: thumbnailGroup.memberAssetIDs,
            personIndex: personIndex
        )
    }
}

// MARK: - CustomStringConvertible

extension SimilarThumbnailGroup: CustomStringConvertible {
    /// 디버깅용 문자열 표현
    nonisolated var description: String {
        "SimilarThumbnailGroup(id: \(groupID), members: \(memberCount))"
    }
}

extension ComparisonGroup: CustomStringConvertible {
    /// 디버깅용 문자열 표현
    nonisolated var description: String {
        "ComparisonGroup(source: \(sourceGroupID), person: \(personIndex), count: \(count))"
    }
}

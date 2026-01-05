//
//  SimilarPhotoGroup.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  유사 사진 그룹 관련 모델을 정의합니다.
//  - SimilarThumbnailGroup: 그리드 테두리/뷰어 +버튼용 그룹 (크기 제한 없음)
//  - ComparisonGroup: 얼굴 비교 화면용 그룹 (최대 8장)
//

import Foundation

// MARK: - SimilarThumbnailGroup

/// 그리드 테두리 및 뷰어 +버튼 표시를 위한 유사 사진 그룹
struct SimilarThumbnailGroup: Equatable, Hashable, Sendable {

    // MARK: - Properties

    let groupID: String
    var memberAssetIDs: [String]

    // MARK: - Computed Properties

    nonisolated var isValid: Bool {
        memberAssetIDs.count >= SimilarityConstants.minGroupSize
    }

    nonisolated var memberCount: Int {
        memberAssetIDs.count
    }

    // MARK: - Initialization

    nonisolated init(groupID: String = UUID().uuidString, memberAssetIDs: [String]) {
        self.groupID = groupID
        self.memberAssetIDs = memberAssetIDs
    }

    // MARK: - Mutation

    @discardableResult
    nonisolated mutating func removeMember(_ assetID: String) -> Bool {
        memberAssetIDs.removeAll { $0 == assetID }
        return isValid
    }

    @discardableResult
    nonisolated mutating func removeMembers(_ assetIDs: [String]) -> Bool {
        let idsToRemove = Set(assetIDs)
        memberAssetIDs.removeAll { idsToRemove.contains($0) }
        return isValid
    }

    nonisolated func contains(_ assetID: String) -> Bool {
        memberAssetIDs.contains(assetID)
    }
}

// MARK: - ComparisonGroup

/// 얼굴 비교 화면에서 비교할 사진 집합 (최대 8장)
struct ComparisonGroup: Equatable, Sendable {

    // MARK: - Properties

    let sourceGroupID: String
    let selectedAssetIDs: [String]
    let personIndex: Int

    // MARK: - Computed Properties

    nonisolated var count: Int {
        selectedAssetIDs.count
    }

    nonisolated var isEmpty: Bool {
        selectedAssetIDs.isEmpty
    }

    // MARK: - Initialization

    nonisolated init(sourceGroupID: String, selectedAssetIDs: [String], personIndex: Int) {
        self.sourceGroupID = sourceGroupID
        self.selectedAssetIDs = Array(selectedAssetIDs.prefix(SimilarityConstants.maxComparisonGroupSize))
        self.personIndex = personIndex
    }

    // MARK: - Static Factory

    nonisolated static func create(
        from thumbnailGroup: SimilarThumbnailGroup,
        currentAssetID: String,
        personIndex: Int
    ) -> ComparisonGroup {
        let members = thumbnailGroup.memberAssetIDs

        guard let currentIndex = members.firstIndex(of: currentAssetID) else {
            return ComparisonGroup(
                sourceGroupID: thumbnailGroup.groupID,
                selectedAssetIDs: [],
                personIndex: personIndex
            )
        }

        let sortedByDistance = members.enumerated()
            .sorted { (a, b) in
                let distA = abs(a.offset - currentIndex)
                let distB = abs(b.offset - currentIndex)
                if distA != distB {
                    return distA < distB
                }
                return a.offset < b.offset
            }
            .map { $0.element }

        let selected = Array(sortedByDistance.prefix(SimilarityConstants.maxComparisonGroupSize))
        let orderedSelected = members.filter { selected.contains($0) }

        return ComparisonGroup(
            sourceGroupID: thumbnailGroup.groupID,
            selectedAssetIDs: orderedSelected,
            personIndex: personIndex
        )
    }
}

// MARK: - CustomStringConvertible

extension SimilarThumbnailGroup: CustomStringConvertible {
    nonisolated var description: String {
        "SimilarThumbnailGroup(id: \(groupID), members: \(memberCount))"
    }
}

extension ComparisonGroup: CustomStringConvertible {
    nonisolated var description: String {
        "ComparisonGroup(source: \(sourceGroupID), person: \(personIndex), count: \(count))"
    }
}

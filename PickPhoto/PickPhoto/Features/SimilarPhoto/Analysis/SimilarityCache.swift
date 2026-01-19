//
//  SimilarityCache.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  유사 사진 분석 결과를 메모리에 캐시하는 Actor입니다.
//  사진별 분석 상태, 얼굴 정보, 그룹 정보를 관리하며,
//  LRU(Least Recently Used) 정책으로 메모리 사용량을 제한합니다.
//
//  Thread Safety:
//  Actor 기반으로 구현되어 있어 모든 프로퍼티 접근이 thread-safe합니다.
//  호출 시 await 키워드가 필요합니다.
//
//  Source of Truth:
//  - 그룹 멤버: groups[groupID].memberAssetIDs
//  - 유효 인물 슬롯: groupValidPersonIndices[groupID]
//  - 사진별 얼굴: assetFaces[assetID]
//

import Foundation
import UIKit

// MARK: - SimilarityCacheProtocol

/// SimilarityCache 의존성 주입을 위한 프로토콜
///
/// FaceComparisonViewController에서 테스트 가능성을 위해 사용됩니다.
/// Actor 기반이므로 모든 메서드가 async입니다.
protocol SimilarityCacheProtocol: Actor {
    /// 특정 사진의 캐시된 얼굴 정보를 조회합니다.
    func getFaces(for assetID: String) -> [CachedFace]

    /// 그룹별 유효 인물 슬롯을 조회합니다.
    func getGroupValidPersonIndices(for groupID: String) -> Set<Int>

    /// 그룹에서 멤버를 제거합니다.
    @discardableResult
    func removeMemberFromGroup(_ assetID: String, groupID: String) -> Bool
}

// MARK: - SimilarityCache

/// 유사 사진 분석 결과 캐시 (Actor)
///
/// 그리드에서 분석된 결과를 저장하여 뷰어에서 재분석 없이 재사용합니다.
/// 최대 500장까지 캐시하며, 초과 시 LRU 정책으로 오래된 항목부터 제거합니다.
///
/// - Important: Actor 기반이므로 모든 메서드 호출 시 `await` 키워드가 필요합니다.
actor SimilarityCache: SimilarityCacheProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SimilarityCache()

    // MARK: - Properties

    /// 사진별 분석 상태
    private var states: [String: SimilarityAnalysisState] = [:]

    /// 그룹 관리 (groupID → SimilarThumbnailGroup)
    private var groups: [String: SimilarThumbnailGroup] = [:]

    /// 사진별 얼굴 캐시 (assetID → [CachedFace])
    private var assetFaces: [String: [CachedFace]] = [:]

    /// 그룹별 유효 인물 슬롯 (groupID → Set<personIndex>)
    private var groupValidPersonIndices: [String: Set<Int>] = [:]

    /// LRU 추적 (가장 최근 접근된 assetID가 배열 끝에 위치)
    private var accessOrder: [String] = []

    /// 최대 캐시 크기
    private let maxSize: Int

    /// 메모리 경고 옵저버 토큰
    private var memoryWarningObserver: NSObjectProtocol?

    // MARK: - Initialization

    /// 캐시를 초기화합니다.
    ///
    /// - Parameter maxSize: 최대 캐시 크기 (기본값: SimilarityConstants.maxCacheSize)
    init(maxSize: Int = SimilarityConstants.maxCacheSize) {
        self.maxSize = maxSize

        // NotificationCenter 옵저버 설정 (nonisolated 컨텍스트에서 설정)
        // Actor 초기화 후 별도로 설정
        Task { @MainActor in
            await self.setupMemoryWarningObserver()
        }
    }

    // MARK: - State Management

    /// 특정 사진의 분석 상태를 조회합니다.
    ///
    /// - Parameter assetID: 사진 ID
    /// - Returns: 분석 상태 (캐시에 없으면 .notAnalyzed)
    func getState(for assetID: String) -> SimilarityAnalysisState {
        updateAccessOrder(for: assetID)
        return states[assetID] ?? .notAnalyzed
    }

    /// 특정 사진의 분석 상태를 설정합니다.
    ///
    /// - Parameters:
    ///   - state: 새로운 상태
    ///   - assetID: 사진 ID
    func setState(_ state: SimilarityAnalysisState, for assetID: String) {
        states[assetID] = state
        updateAccessOrder(for: assetID)
    }

    // MARK: - Face Management

    /// 특정 사진의 캐시된 얼굴 정보를 조회합니다.
    ///
    /// - Parameter assetID: 사진 ID
    /// - Returns: 캐시된 얼굴 배열 (없으면 빈 배열)
    func getFaces(for assetID: String) -> [CachedFace] {
        updateAccessOrder(for: assetID)
        return assetFaces[assetID] ?? []
    }

    /// 특정 사진의 얼굴 정보를 캐시합니다.
    ///
    /// - Parameters:
    ///   - faces: 캐시할 얼굴 배열
    ///   - assetID: 사진 ID
    func setFaces(_ faces: [CachedFace], for assetID: String) {
        assetFaces[assetID] = faces
        updateAccessOrder(for: assetID)
    }

    /// 유효 슬롯(2장 이상 감지된 인물)의 얼굴만 조회합니다.
    ///
    /// - Parameter assetID: 사진 ID
    /// - Returns: isValidSlot이 true인 얼굴만 포함된 배열
    func getValidSlotFaces(for assetID: String) -> [CachedFace] {
        return getFaces(for: assetID).filter { $0.isValidSlot }
    }

    // MARK: - Group Management

    /// 그룹 멤버 목록을 조회합니다.
    ///
    /// - Parameter groupID: 그룹 ID
    /// - Returns: 멤버 사진 ID 배열 (없으면 빈 배열)
    func getGroupMembers(groupID: String) -> [String] {
        return groups[groupID]?.memberAssetIDs ?? []
    }

    /// 그룹 멤버 목록을 설정합니다.
    ///
    /// - Parameters:
    ///   - members: 멤버 사진 ID 배열
    ///   - groupID: 그룹 ID
    func setGroupMembers(_ members: [String], for groupID: String) {
        if var group = groups[groupID] {
            group.memberAssetIDs = members
            groups[groupID] = group
        } else {
            groups[groupID] = SimilarThumbnailGroup(groupID: groupID, memberAssetIDs: members)
        }
    }

    /// 그룹을 조회합니다.
    ///
    /// - Parameter groupID: 그룹 ID
    /// - Returns: 그룹 객체 (없으면 nil)
    func getGroup(groupID: String) -> SimilarThumbnailGroup? {
        return groups[groupID]
    }

    /// 그룹별 유효 인물 슬롯을 조회합니다.
    ///
    /// - Parameter groupID: 그룹 ID
    /// - Returns: 유효 인물 번호 집합 (없으면 빈 집합)
    func getGroupValidPersonIndices(for groupID: String) -> Set<Int> {
        return groupValidPersonIndices[groupID] ?? []
    }

    /// 그룹별 유효 인물 슬롯을 설정합니다.
    ///
    /// - Parameters:
    ///   - indices: 유효 인물 번호 집합
    ///   - groupID: 그룹 ID
    func setGroupValidPersonIndices(_ indices: Set<Int>, for groupID: String) {
        groupValidPersonIndices[groupID] = indices
    }

    // MARK: - Group Validation (T010 - Gate Keeper)

    /// 그룹이 유효한지 검증하고 저장합니다.
    ///
    /// 이 메서드는 분석 완료 후 그룹을 저장하기 전에 호출됩니다.
    /// 유효성 조건을 만족하면 저장하고, 그렇지 않으면 저장하지 않습니다.
    ///
    /// - Parameters:
    ///   - members: 멤버 asset ID 배열
    ///   - validSlots: 유효 슬롯 집합 (T014.6에서 계산)
    ///   - photoFaces: 사진별 얼굴 정보
    /// - Returns: 저장된 groupID (무효 그룹이면 nil)
    ///
    /// - Important: 저장 전에 T015 병합 처리를 수행합니다.
    @discardableResult
    func addGroupIfValid(
        members: [String],
        validSlots: Set<Int>,
        photoFaces: [String: [CachedFace]]
    ) -> String? {
        // 유효성 검사 (spec FR-003, FR-005)
        guard members.count >= SimilarityConstants.minGroupSize else {
            // 조건 미충족 → 멤버들 analyzed(inGroup: false) 설정
            for assetID in members {
                setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
                if let faces = photoFaces[assetID] {
                    setFaces(faces, for: assetID)
                }
            }
            return nil
        }

        guard validSlots.count >= SimilarityConstants.minValidSlots else {
            // 유효 슬롯 없음 → 멤버들 analyzed(inGroup: false) 설정
            for assetID in members {
                setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
                if let faces = photoFaces[assetID] {
                    setFaces(faces, for: assetID)
                }
            }
            return nil
        }

        // T015 병합 처리: 겹치는 기존 그룹과 병합
        let (mergedMembers, mergedSlots) = mergeOverlappingGroups(newMembers: members, newSlots: validSlots)

        // 그룹 저장
        let groupID = UUID().uuidString
        let group = SimilarThumbnailGroup(groupID: groupID, memberAssetIDs: mergedMembers)
        groups[groupID] = group
        groupValidPersonIndices[groupID] = mergedSlots

        // 멤버들 상태 및 얼굴 정보 업데이트
        for assetID in mergedMembers {
            setState(.analyzed(inGroup: true, groupID: groupID), for: assetID)

            // CachedFace의 isValidSlot 플래그 갱신
            if let faces = photoFaces[assetID] {
                let updatedFaces = faces.map { face in
                    var updated = face
                    updated.isValidSlot = mergedSlots.contains(face.personIndex)
                    return updated
                }
                setFaces(updatedFaces, for: assetID)
            } else if let existingFaces = assetFaces[assetID] {
                // 기존 캐시된 얼굴의 isValidSlot 갱신
                let updatedFaces = existingFaces.map { face in
                    var updated = face
                    updated.isValidSlot = mergedSlots.contains(face.personIndex)
                    return updated
                }
                setFaces(updatedFaces, for: assetID)
            }
        }

        return groupID
    }

    // MARK: - Group Invalidation

    /// 그룹을 무효화합니다.
    ///
    /// 삭제로 인해 그룹 멤버가 3장 미만이 되거나, 유효 슬롯이 없어진 경우 호출됩니다.
    /// 각 멤버가 다른 유효 그룹에도 속해있으면 inGroup 유지, 없으면 inGroup=false로 변경합니다.
    ///
    /// - Parameter groupID: 무효화할 그룹 ID
    func invalidateGroup(groupID: String) {
        guard let group = groups[groupID] else { return }

        // 그룹 삭제
        groups.removeValue(forKey: groupID)
        groupValidPersonIndices.removeValue(forKey: groupID)

        // 각 멤버 처리
        for assetID in group.memberAssetIDs {
            // 다른 유효 그룹에 속해있는지 확인
            let otherGroupID = findOtherValidGroup(for: assetID, excluding: groupID)

            if let otherID = otherGroupID {
                // 다른 그룹에 속함 → groupID만 변경
                setState(.analyzed(inGroup: true, groupID: otherID), for: assetID)
            } else {
                // 다른 그룹에 속하지 않음 → inGroup=false
                setState(.analyzed(inGroup: false, groupID: nil), for: assetID)
            }
        }
    }

    /// 그룹 멤버에서 특정 사진을 제거합니다.
    ///
    /// - Parameters:
    ///   - assetID: 제거할 사진 ID
    ///   - groupID: 그룹 ID
    /// - Returns: 제거 후 그룹이 유효하면 true, 무효화되었으면 false
    @discardableResult
    func removeMemberFromGroup(_ assetID: String, groupID: String) -> Bool {
        guard var group = groups[groupID] else { return false }

        // 멤버 제거
        group.removeMember(assetID)
        groups[groupID] = group

        // 해당 사진 상태 업데이트
        setState(.analyzed(inGroup: false, groupID: nil), for: assetID)

        // 그룹 유효성 확인
        if !group.isValid {
            invalidateGroup(groupID: groupID)
            return false
        }

        // 유효 슬롯 재계산
        recalculateValidPersonIndices(for: groupID)

        // 재계산 후 유효 슬롯 확인
        if getGroupValidPersonIndices(for: groupID).isEmpty {
            invalidateGroup(groupID: groupID)
            return false
        }

        return true
    }

    // MARK: - Valid Person Indices Recalculation

    /// 그룹의 유효 인물 슬롯을 재계산합니다.
    ///
    /// 그룹 멤버가 변경된 후 호출하여 유효 슬롯을 갱신합니다.
    ///
    /// - Parameter groupID: 그룹 ID
    func recalculateValidPersonIndices(for groupID: String) {
        guard let group = groups[groupID] else { return }

        // 각 인물 슬롯별 사진 수 집계
        var slotCounts: [Int: Int] = [:]

        for assetID in group.memberAssetIDs {
            let faces = getFaces(for: assetID)
            for face in faces {
                slotCounts[face.personIndex, default: 0] += 1
            }
        }

        // 유효 슬롯 판정 (2장 이상)
        let validSlots = Set(slotCounts.filter {
            $0.value >= SimilarityConstants.minPhotosPerSlot
        }.keys)

        groupValidPersonIndices[groupID] = validSlots

        // 각 멤버의 CachedFace.isValidSlot 갱신
        for assetID in group.memberAssetIDs {
            if let faces = assetFaces[assetID] {
                let updatedFaces = faces.map { face in
                    var updated = face
                    updated.isValidSlot = validSlots.contains(face.personIndex)
                    return updated
                }
                assetFaces[assetID] = updatedFaces
            }
        }
    }

    // MARK: - Reanalysis Preparation

    /// 재분석을 위해 기존 데이터를 정리합니다.
    ///
    /// research.md §10.5 참조:
    /// - 범위 내 사진의 기존 그룹에서 제거
    /// - 영향받은 그룹 3장 미만 → invalidateGroup() 호출
    /// - 3장 이상 → recalculateValidPersonIndices() 호출
    /// - 기존 CachedFace 삭제
    /// - 상태 → analyzing
    ///
    /// - Parameter assetIDs: 재분석할 사진 ID 집합
    func prepareForReanalysis(assetIDs: Set<String>) {
        // 영향받는 그룹 수집
        var affectedGroups: [String: Set<String>] = [:]  // groupID → 제거할 assetIDs

        for assetID in assetIDs {
            if case .analyzed(true, let groupID?) = getState(for: assetID) {
                affectedGroups[groupID, default: []].insert(assetID)
            }
        }

        // 각 그룹 처리
        for (groupID, removedAssetIDs) in affectedGroups {
            guard var group = groups[groupID] else { continue }

            // 멤버에서 제거
            group.removeMembers(Array(removedAssetIDs))
            groups[groupID] = group

            // 그룹 유효성 확인
            if !group.isValid {
                invalidateGroup(groupID: groupID)
            } else {
                recalculateValidPersonIndices(for: groupID)

                // 유효 슬롯 없으면 무효화
                if getGroupValidPersonIndices(for: groupID).isEmpty {
                    invalidateGroup(groupID: groupID)
                }
            }
        }

        // 기존 데이터 삭제 및 상태 변경
        for assetID in assetIDs {
            assetFaces.removeValue(forKey: assetID)
            states[assetID] = .analyzing
        }
    }

    // MARK: - Group Merging (T015)

    /// 겹치는 기존 그룹과 병합합니다.
    ///
    /// 연속 범위 분석이므로 동일 사진이 여러 그룹에 속하지 않도록 보장합니다.
    /// 새 분석 범위가 기존 그룹과 겹칠 경우 그룹을 병합합니다.
    ///
    /// - Parameters:
    ///   - newMembers: 새 그룹 멤버
    ///   - newSlots: 새 그룹 유효 슬롯
    /// - Returns: 병합된 (멤버 목록, 유효 슬롯)
    private func mergeOverlappingGroups(
        newMembers: [String],
        newSlots: Set<Int>
    ) -> ([String], Set<Int>) {
        let newMemberSet = Set(newMembers)
        var overlappingGroupIDs: [String] = []

        // 겹치는 기존 그룹 찾기
        for (groupID, group) in groups {
            let overlap = newMemberSet.intersection(group.memberAssetIDs)
            if !overlap.isEmpty {
                overlappingGroupIDs.append(groupID)
            }
        }

        // 겹치는 그룹이 없으면 그대로 반환
        if overlappingGroupIDs.isEmpty {
            return (newMembers, newSlots)
        }

        // 모든 멤버 수집
        var mergedMemberSet = newMemberSet
        let mergedSlots = newSlots

        for groupID in overlappingGroupIDs {
            if let group = groups[groupID] {
                mergedMemberSet.formUnion(group.memberAssetIDs)
            }

            // 기존 그룹 무효화
            invalidateGroup(groupID: groupID)
        }

        // 병합된 결과에서 유효 슬롯 재계산 필요
        // (호출자가 다시 계산하므로 여기서는 기존 값 반환)

        return (Array(mergedMemberSet), mergedSlots)
    }

    /// 특정 사진이 속한 다른 유효 그룹을 찾습니다.
    ///
    /// - Parameters:
    ///   - assetID: 사진 ID
    ///   - excludingGroupID: 제외할 그룹 ID
    /// - Returns: 다른 유효 그룹의 ID (없으면 nil)
    private func findOtherValidGroup(for assetID: String, excluding excludingGroupID: String) -> String? {
        for (groupID, group) in groups where groupID != excludingGroupID {
            if group.contains(assetID) && group.isValid {
                return groupID
            }
        }
        return nil
    }

    // MARK: - LRU Management

    /// LRU 접근 순서를 업데이트합니다.
    ///
    /// - Parameter assetID: 접근한 사진 ID
    private func updateAccessOrder(for assetID: String) {
        // 이미 있으면 제거
        accessOrder.removeAll { $0 == assetID }
        // 끝에 추가 (가장 최근)
        accessOrder.append(assetID)
    }

    /// 캐시 크기를 확인하고 필요 시 eviction을 수행합니다.
    func evictIfNeeded() {
        while accessOrder.count > maxSize {
            evictOldest()
        }
    }

    /// 가장 오래된 항목을 제거합니다.
    private func evictOldest() {
        guard !accessOrder.isEmpty else { return }

        let oldestAssetID = accessOrder.removeFirst()

        // 분석 중인 사진은 eviction 제외
        if case .analyzing = states[oldestAssetID] {
            // 다시 끝에 추가
            accessOrder.append(oldestAssetID)
            return
        }

        // 그룹에서 제거
        if case .analyzed(true, let groupID?) = states[oldestAssetID] {
            _ = removeMemberFromGroup(oldestAssetID, groupID: groupID)
        }

        // 데이터 제거
        states.removeValue(forKey: oldestAssetID)
        assetFaces.removeValue(forKey: oldestAssetID)
    }

    // MARK: - Memory Warning

    /// 메모리 경고 시 캐시를 정리합니다.
    ///
    /// 캐시의 50%를 LRU 순서로 제거합니다.
    func handleMemoryWarning() {
        let targetCount = accessOrder.count / 2

        while accessOrder.count > targetCount {
            evictOldest()
        }
    }

    /// 메모리 경고 옵저버를 설정합니다.
    private func setupMemoryWarningObserver() {
        memoryWarningObserver = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self = self else { return }
            Task {
                await self.handleMemoryWarning()
            }
        }
    }

    // MARK: - Clear

    /// 모든 캐시를 삭제합니다.
    func clear() {
        states.removeAll()
        groups.removeAll()
        assetFaces.removeAll()
        groupValidPersonIndices.removeAll()
        accessOrder.removeAll()
    }

    // MARK: - Debug

    /// 현재 캐시 상태를 반환합니다.
    func debugStatus() -> String {
        """
        SimilarityCache Status:
        - States: \(states.count)
        - Groups: \(groups.count)
        - Faces: \(assetFaces.count)
        - Access Order: \(accessOrder.count)
        - Max Size: \(maxSize)
        """
    }

    deinit {
        if let observer = memoryWarningObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

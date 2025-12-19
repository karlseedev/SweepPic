// TrashState.swift
// 앱 내 휴지통 상태 모델
//
// T009: TrashState 구조체 (trashedAssetIDs, trashDates, lastModified)

import Foundation

// MARK: - TrashState (T009)

/// 앱 내 휴지통 상태
/// PhotoKit에서 실제 삭제하지 않고 로컬에만 저장하는 휴지통 상태
///
/// - Note: 파일 기반 저장 사용 (대용량 ID Set 대응)
/// - SeeAlso: TrashStore
public struct TrashState: Codable, Sendable {

    // MARK: - Properties

    /// 휴지통에 있는 사진 ID 집합
    /// PHAsset.localIdentifier의 Set
    public var trashedAssetIDs: Set<String>

    /// 삭제 시각 맵
    /// Key: assetID, Value: 휴지통으로 이동한 시각
    /// 향후 자동 정리 기능에 사용될 수 있음
    public var trashDates: [String: Date]

    /// 마지막 수정 시각
    /// 상태 변경 시 알림 및 동기화에 사용
    public var lastModified: Date

    // MARK: - Computed Properties

    /// 휴지통에 있는 사진 수
    public var trashedCount: Int {
        trashedAssetIDs.count
    }

    /// 휴지통이 비어있는지 여부
    public var isEmpty: Bool {
        trashedAssetIDs.isEmpty
    }

    // MARK: - Initialization

    /// TrashState 초기화
    /// - Parameters:
    ///   - trashedAssetIDs: 휴지통에 있는 사진 ID 집합 (기본: 빈 Set)
    ///   - trashDates: 삭제 시각 맵 (기본: 빈 Dictionary)
    ///   - lastModified: 마지막 수정 시각 (기본: 현재 시각)
    public init(
        trashedAssetIDs: Set<String> = [],
        trashDates: [String: Date] = [:],
        lastModified: Date = Date()
    ) {
        self.trashedAssetIDs = trashedAssetIDs
        self.trashDates = trashDates
        self.lastModified = lastModified
    }

    // MARK: - Methods

    /// 특정 사진이 휴지통에 있는지 확인
    /// - Parameter assetID: 확인할 사진 ID
    /// - Returns: 휴지통에 있으면 true
    public func isTrashed(_ assetID: String) -> Bool {
        trashedAssetIDs.contains(assetID)
    }

    /// 사진을 휴지통으로 이동 (mutating)
    /// - Parameter assetID: 이동할 사진 ID
    public mutating func moveToTrash(_ assetID: String) {
        let now = Date()
        trashedAssetIDs.insert(assetID)
        trashDates[assetID] = now
        lastModified = now
    }

    /// 사진을 휴지통에서 복구 (mutating)
    /// - Parameter assetID: 복구할 사진 ID
    public mutating func restore(_ assetID: String) {
        trashedAssetIDs.remove(assetID)
        trashDates.removeValue(forKey: assetID)
        lastModified = Date()
    }

    /// 사진을 휴지통에서 완전 삭제 (mutating)
    /// - Parameter assetID: 삭제할 사진 ID
    /// - Note: 이 메서드는 상태에서만 제거합니다. 실제 PhotoKit 삭제는 별도 처리 필요.
    public mutating func permanentlyDelete(_ assetID: String) {
        trashedAssetIDs.remove(assetID)
        trashDates.removeValue(forKey: assetID)
        lastModified = Date()
    }

    /// 휴지통 비우기 (mutating)
    /// - Returns: 비워진 사진 ID 배열
    /// - Note: 이 메서드는 상태에서만 제거합니다. 실제 PhotoKit 삭제는 별도 처리 필요.
    @discardableResult
    public mutating func emptyTrash() -> [String] {
        let deletedIDs = Array(trashedAssetIDs)
        trashedAssetIDs.removeAll()
        trashDates.removeAll()
        lastModified = Date()
        return deletedIDs
    }

    /// PhotoKit에 존재하지 않는 ID 정리 (mutating)
    /// - Parameter validAssetIDs: 현재 PhotoKit에 존재하는 ID 집합
    public mutating func removeInvalidAssets(validAssetIDs: Set<String>) {
        let invalidIDs = trashedAssetIDs.subtracting(validAssetIDs)
        for id in invalidIDs {
            trashedAssetIDs.remove(id)
            trashDates.removeValue(forKey: id)
        }
        if !invalidIDs.isEmpty {
            lastModified = Date()
        }
    }
}

// MARK: - CustomStringConvertible

extension TrashState: CustomStringConvertible {
    public var description: String {
        "TrashState(count: \(trashedCount), lastModified: \(lastModified))"
    }
}

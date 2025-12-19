// SelectionManager.swift
// 사진 선택 상태 관리
//
// T037: SelectionManager 생성
// - selectedAssetIDs Set 관리
// - toggle/clear/selectRange 기능
// - 선택 변경 알림 (delegate/closure)

import Foundation

/// 선택 매니저 델리게이트
/// 선택 상태 변경 알림 전달
protocol SelectionManagerDelegate: AnyObject {
    /// 선택 상태 변경 시 호출
    /// - Parameters:
    ///   - manager: 선택 매니저
    ///   - assetIDs: 변경된 에셋 ID 목록
    func selectionManager(_ manager: SelectionManager, didChangeSelection assetIDs: Set<String>)

    /// 선택 개수 변경 시 호출
    /// - Parameters:
    ///   - manager: 선택 매니저
    ///   - count: 현재 선택 개수
    func selectionManager(_ manager: SelectionManager, selectionCountDidChange count: Int)
}

/// 사진 선택 상태 관리자
/// Select 모드에서 사진 선택/해제 상태를 추적
final class SelectionManager {

    // MARK: - Properties

    weak var delegate: SelectionManagerDelegate?

    /// 선택된 에셋 ID Set
    private(set) var selectedAssetIDs: Set<String> = []

    /// 현재 선택 개수
    var selectedCount: Int {
        return selectedAssetIDs.count
    }

    /// 선택된 항목이 있는지
    var hasSelection: Bool {
        return !selectedAssetIDs.isEmpty
    }

    // MARK: - Selection Operations

    /// 선택 토글
    /// - Parameter assetID: 토글할 에셋 ID
    /// - Returns: 토글 후 선택 상태 (true = 선택됨)
    @discardableResult
    func toggle(_ assetID: String) -> Bool {
        if selectedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
            notifyChange(assetIDs: [assetID])
            return false
        } else {
            selectedAssetIDs.insert(assetID)
            notifyChange(assetIDs: [assetID])
            return true
        }
    }

    /// 선택 추가
    /// - Parameter assetID: 선택할 에셋 ID
    func select(_ assetID: String) {
        guard !selectedAssetIDs.contains(assetID) else { return }
        selectedAssetIDs.insert(assetID)
        notifyChange(assetIDs: [assetID])
    }

    /// 선택 해제
    /// - Parameter assetID: 해제할 에셋 ID
    func deselect(_ assetID: String) {
        guard selectedAssetIDs.contains(assetID) else { return }
        selectedAssetIDs.remove(assetID)
        notifyChange(assetIDs: [assetID])
    }

    /// 선택 여부 확인
    /// - Parameter assetID: 확인할 에셋 ID
    /// - Returns: 선택 여부
    func isSelected(_ assetID: String) -> Bool {
        return selectedAssetIDs.contains(assetID)
    }

    /// 범위 선택 (드래그 선택용)
    /// - Parameter assetIDs: 선택할 에셋 ID 배열
    func selectRange(_ assetIDs: [String]) {
        let newIDs = Set(assetIDs)
        let addedIDs = newIDs.subtracting(selectedAssetIDs)
        guard !addedIDs.isEmpty else { return }

        selectedAssetIDs.formUnion(addedIDs)
        notifyChange(assetIDs: addedIDs)
    }

    /// 범위 해제
    /// - Parameter assetIDs: 해제할 에셋 ID 배열
    func deselectRange(_ assetIDs: [String]) {
        let removeIDs = Set(assetIDs)
        let removedIDs = selectedAssetIDs.intersection(removeIDs)
        guard !removedIDs.isEmpty else { return }

        selectedAssetIDs.subtract(removedIDs)
        notifyChange(assetIDs: removedIDs)
    }

    /// 전체 선택 해제
    func clearSelection() {
        guard !selectedAssetIDs.isEmpty else { return }
        let clearedIDs = selectedAssetIDs
        selectedAssetIDs.removeAll()
        notifyChange(assetIDs: clearedIDs)
    }

    /// 전체 선택
    /// - Parameter assetIDs: 선택할 모든 에셋 ID
    func selectAll(_ assetIDs: [String]) {
        let newIDs = Set(assetIDs)
        let addedIDs = newIDs.subtracting(selectedAssetIDs)
        guard !addedIDs.isEmpty else { return }

        selectedAssetIDs = newIDs
        notifyChange(assetIDs: addedIDs)
    }

    // MARK: - Private Methods

    /// 변경 알림
    private func notifyChange(assetIDs: Set<String>) {
        delegate?.selectionManager(self, didChangeSelection: assetIDs)
        delegate?.selectionManager(self, selectionCountDidChange: selectedCount)

        print("[SelectionManager] Selection changed: \(selectedCount) items selected")
    }
}

//
//  GridSelectMode.swift
//  PickPhoto
//
//  Description: Grid/Album 공용 선택 모드
//               - supportsSelectMode 오버라이드
//               - 툴바 설정 (iOS 26+): [선택개수] [Delete]
//               - 삭제 액션: 휴지통으로 이동
//
//  공통 로직 (Base):
//  - enterSelectMode(), exitSelectMode()
//  - 드래그 선택, 자동 스크롤
//  - SelectionManagerDelegate
//
//  Trash 전용: TrashSelectMode.swift
//

import UIKit
import Photos
import AppCore

// MARK: - Grid Select Mode Support

extension GridViewController {

    /// Grid는 선택 모드 지원
    override var supportsSelectMode: Bool { true }

    /// iOS 26+ 툴바 설정: [flex] [선택개수] [flex] [Delete]
    override func setupSelectionToolbar() -> [UIBarButtonItem] {
        let countLabel = UILabel()
        countLabel.text = "항목 선택"
        countLabel.font = .systemFont(ofSize: 17)
        countLabel.textColor = .label
        countLabel.sizeToFit()
        let countItem = UIBarButtonItem(customView: countLabel)
        if #available(iOS 26.0, *) {
            countItem.hidesSharedBackground = true
        }
        selectionCountBarItem = countItem

        let deleteItem = UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: self,
            action: #selector(gridDeleteSelectedTapped)
        )
        deleteItem.tintColor = .systemRed

        return [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            countItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteItem
        ]
    }

    /// 툴바 선택 개수 업데이트
    override func updateSelectionToolbar(count: Int) {
        if let countItem = selectionCountBarItem,
           let label = countItem.customView as? UILabel {
            label.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
            label.sizeToFit()
        }
        toolbarItems?.last?.isEnabled = count > 0
    }

    /// 선택된 사진 삭제 (휴지통으로 이동)
    @objc func gridDeleteSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            print("[GridViewController] No photos selected for deletion")
            return
        }

        trashStore.moveToTrash(assetIDs: Array(selectedAssetIDs))
        print("[GridViewController] Moved \(selectedAssetIDs.count) photos to trash")

        selectionManager.clearSelection()
        exitSelectMode()
    }

    /// 선택된 사진 삭제 (TabBarController에서 호출용 - 기존 호환성)
    func deleteSelectedPhotos() {
        gridDeleteSelectedTapped()
    }

    /// Select 모드 Delete 액션 (iOS 16~25 플로팅 UI)
    override func handleSelectModeDeleteAction() {
        gridDeleteSelectedTapped()
    }
}

// MARK: - Grid Cell Selection Toggle

extension GridViewController {

    /// 셀 선택 토글
    /// - Parameter indexPath: 선택할 셀의 indexPath
    /// - Returns: 토글 후 선택 상태
    @discardableResult
    func toggleSelection(at indexPath: IndexPath) -> Bool {
        let padding = paddingCellCount
        guard indexPath.item >= padding else { return false }

        let assetIndexPath = IndexPath(item: indexPath.item - padding, section: indexPath.section)
        guard let assetID = dataSourceDriver.assetID(at: assetIndexPath) else { return false }

        // 딤드 사진(휴지통)은 선택 불가
        guard !trashStore.isTrashed(assetID) else {
            print("[GridViewController] Cannot select trashed photo")
            return false
        }

        let isSelected = selectionManager.toggle(assetID)

        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
            cell.isSelectedForDeletion = isSelected
        }

        return isSelected
    }
}

// MARK: - Album Select Mode Support

extension AlbumGridViewController {

    /// Album은 선택 모드 지원
    override var supportsSelectMode: Bool { true }

    /// iOS 26+ 툴바 설정: [flex] [선택개수] [flex] [Delete]
    override func setupSelectionToolbar() -> [UIBarButtonItem] {
        let countLabel = UILabel()
        countLabel.text = "항목 선택"
        countLabel.font = .systemFont(ofSize: 17)
        countLabel.textColor = .label
        countLabel.sizeToFit()
        let countItem = UIBarButtonItem(customView: countLabel)
        if #available(iOS 26.0, *) {
            countItem.hidesSharedBackground = true
        }
        selectionCountBarItem = countItem

        let deleteItem = UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: self,
            action: #selector(albumDeleteSelectedTapped)
        )
        deleteItem.tintColor = .systemRed

        return [
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            countItem,
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            deleteItem
        ]
    }

    /// 툴바 선택 개수 업데이트
    override func updateSelectionToolbar(count: Int) {
        if let countItem = selectionCountBarItem,
           let label = countItem.customView as? UILabel {
            label.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
            label.sizeToFit()
        }
        toolbarItems?.last?.isEnabled = count > 0
    }

    /// 선택된 사진 삭제 (휴지통으로 이동)
    @objc func albumDeleteSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            print("[AlbumGridViewController] No photos selected for deletion")
            return
        }

        trashStore.moveToTrash(assetIDs: Array(selectedAssetIDs))
        print("[AlbumGridViewController] Moved \(selectedAssetIDs.count) photos to trash")

        selectionManager.clearSelection()
        exitSelectMode()
    }

    /// Select 모드 Delete 액션 (iOS 16~25 플로팅 UI)
    override func handleSelectModeDeleteAction() {
        albumDeleteSelectedTapped()
    }
}

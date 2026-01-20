//
//  TrashSelectMode.swift
//  PickPhoto
//
//  Description: Trash 전용 선택 모드
//               - supportsSelectMode = true
//               - 툴바 설정 (iOS 26+): [Restore] [선택개수] [Delete]
//               - 복원/삭제 액션
//
//  공통 로직 (Base):
//  - enterSelectMode(), exitSelectMode()
//  - 드래그 선택, 자동 스크롤
//  - SelectionManagerDelegate
//
//  Grid/Album 공용: GridSelectMode.swift
//

import UIKit
import Photos
import AppCore

// MARK: - Trash Select Mode Support

extension TrashAlbumViewController {

    /// Trash는 선택 모드 지원
    override var supportsSelectMode: Bool { true }

    /// 휴지통에서는 모든 에셋 선택 가능 (휴지통 에셋이므로)
    override func canSelectAssetInSelectMode(_ assetID: String) -> Bool {
        return true
    }

    // MARK: - iOS 26+ Toolbar

    /// iOS 26+ 툴바 설정: [Restore] [flex] [선택개수] [flex] [Delete]
    override func setupSelectionToolbar() -> [UIBarButtonItem] {
        // Restore 버튼
        let restoreItem = UIBarButtonItem(
            title: "Restore",
            style: .plain,
            target: self,
            action: #selector(trashRestoreSelectedTapped)
        )

        // 선택 개수 라벨
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

        // Delete 버튼
        let deleteItem = UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: self,
            action: #selector(trashDeleteSelectedTapped)
        )
        deleteItem.tintColor = .systemRed

        return [
            restoreItem,
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

        // Restore/Delete 버튼 활성화 상태 업데이트
        if let items = toolbarItems {
            items.first?.isEnabled = count > 0  // Restore
            items.last?.isEnabled = count > 0   // Delete
        }
    }

    // MARK: - iOS 26+ Navigation Bar Restore

    /// iOS 26+ Select 종료 후 네비바 복원: [비우기] [Select] 동시 표시
    override func restoreNavigationBarAfterSelectMode() {
        if #available(iOS 26.0, *) {
            let selectButton = UIBarButtonItem(
                title: "Select",
                style: .plain,
                target: self,
                action: #selector(selectButtonTapped)
            )

            let emptyButton = UIBarButtonItem(
                title: "비우기",
                style: .plain,
                target: self,
                action: #selector(emptyTrashButtonTapped)
            )
            emptyButton.tintColor = .systemRed
            emptyButton.isEnabled = !trashDataSourceAssets.isEmpty

            // 프로퍼티에 저장 (데이터 변경 시 상태 업데이트용)
            emptyTrashBarButtonItem = emptyButton

            // [비우기] [Select] 순서 (배열 첫 요소가 가장 오른쪽)
            navigationItem.rightBarButtonItems = [selectButton, emptyButton]
        }
    }

    // MARK: - iOS 16~25 Floating UI

    /// 플로팅 UI 선택 모드 진입 (Trash 전용)
    override func enterSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.enterSelectMode { [weak self] in
            self?.exitSelectMode()
        }

        // TODO: Phase 4에서 trashSelectModeContainer 구현 후 연결
        // 현재는 기본 selectModeContainer 사용
        overlay.tabBar.enterSelectMode(animated: true)

        print("[TrashAlbumViewController] Floating UI select mode entered")
    }

    /// 플로팅 UI 선택 모드 종료 (Trash 전용)
    override func exitSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.exitSelectMode()

        // TODO: Phase 4에서 trashSelectModeContainer 구현 후 연결
        overlay.tabBar.exitSelectMode(animated: true)

        // 휴지통 전용 FloatingOverlay 상태로 복원
        configureFloatingOverlayForTrashAfterSelectMode()

        print("[TrashAlbumViewController] Floating UI select mode exited")
    }

    /// 플로팅 UI 선택 개수 업데이트 (Trash 전용)
    override func updateSelectionCountFloatingUI(_ count: Int) {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        // TODO: Phase 4에서 trashSelectModeContainer 구현 후 연결
        overlay.tabBar.updateSelectionCount(count)
    }

    /// Select 모드 종료 후 FloatingOverlay를 휴지통 상태로 복원
    private func configureFloatingOverlayForTrashAfterSelectMode() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.setTitle(navigationTitle)
        overlay.titleBar.setShowsBackButton(false, action: nil)

        // [Select] [비우기] 두 버튼 복원 (휴지통이 비어있지 않을 때)
        if !trashDataSourceAssets.isEmpty {
            overlay.titleBar.setTwoRightButtons(
                firstTitle: "Select",
                firstColor: .systemBlue,
                firstAction: { [weak self] in
                    self?.enterSelectMode()
                },
                secondTitle: "비우기",
                secondColor: .systemRed,
                secondAction: { [weak self] in
                    self?.emptyTrashButtonTapped()
                }
            )
        } else {
            overlay.titleBar.isSelectButtonHidden = true
            overlay.titleBar.hideSecondRightButton()
        }
    }

    // MARK: - Actions

    /// 선택된 사진 복원 (Trash 전용)
    @objc func trashRestoreSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            print("[TrashAlbumViewController] No photos selected for restore")
            return
        }

        trashStore.restore(assetIDs: Array(selectedAssetIDs))
        print("[TrashAlbumViewController] Restored \(selectedAssetIDs.count) photos from trash")

        selectionManager.clearSelection()
        exitSelectMode()
    }

    /// 선택된 사진 영구 삭제 (Trash 전용)
    @objc func trashDeleteSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            print("[TrashAlbumViewController] No photos selected for deletion")
            return
        }

        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: Array(selectedAssetIDs))
                await MainActor.run {
                    print("[TrashAlbumViewController] Permanently deleted \(selectedAssetIDs.count) photos")
                    selectionManager.clearSelection()
                    exitSelectMode()
                }
            } catch {
                print("[TrashAlbumViewController] Failed to delete: \(error)")
            }
        }
    }

    /// Select 모드 Delete 액션 (iOS 16~25 플로팅 UI)
    override func handleSelectModeDeleteAction() {
        trashDeleteSelectedTapped()
    }
}

// MARK: - Helper Properties

extension TrashAlbumViewController {

    /// TrashDataSource assets 접근 헬퍼
    fileprivate var trashDataSourceAssets: [PHAsset] {
        (gridDataSource as? TrashDataSource)?.assets ?? []
    }
}

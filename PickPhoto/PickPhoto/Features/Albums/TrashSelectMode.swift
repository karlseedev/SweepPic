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

    /// 삭제대기함에서는 모든 에셋 선택 가능 (삭제대기함 에셋이므로)
    override func canSelectAssetInSelectMode(_ assetID: String) -> Bool {
        return true
    }

    // MARK: - iOS 26+ Toolbar

    /// iOS 26+ 툴바 설정: [Restore] [flex] [선택개수] [flex] [Delete]
    override func setupSelectionToolbar() -> [UIBarButtonItem] {
        // Restore 버튼
        let restoreItem = UIBarButtonItem(
            title: "복구",
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
            title: "삭제",
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

    /// iOS 26+ Select 종료 후 네비바 복원: 초기 설정 함수 재사용
    override func restoreNavigationBarAfterSelectMode() {
        if #available(iOS 26.0, *) {
            setupSystemNavigationBar()  // TrashAlbumViewController.swift
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

        // Trash 전용: trashSelectModeContainer 사용 (Restore + 선택개수 + Delete)
        overlay.tabBar.delegate = self
        overlay.tabBar.enterTrashSelectMode(animated: true)

    }

    /// 플로팅 UI 선택 모드 종료 (Trash 전용): 초기 설정 함수 재사용
    override func exitSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.exitSelectMode()

        // Trash 전용: trashSelectModeContainer 종료
        overlay.tabBar.exitTrashSelectMode(animated: true)

        // delegate를 원래대로 복원 (FloatingOverlayContainer) - 필수
        overlay.tabBar.delegate = overlay

        // 초기 설정 함수 재사용
        configureFloatingOverlayForTrash()
    }

    /// 플로팅 UI 선택 개수 업데이트 (Trash 전용)
    override func updateSelectionCountFloatingUI(_ count: Int) {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        // Trash 전용: trashSelectModeContainer의 선택 개수 업데이트
        overlay.tabBar.updateTrashSelectionCount(count)
    }

    // MARK: - Actions

    /// 선택된 사진 복원 (Trash 전용)
    @objc func trashRestoreSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            return
        }

        // [Analytics] 이벤트 4-2: 삭제대기함 복구 (선택 모드)
        AnalyticsService.shared.countTrashRestore()

        trashStore.restore(assetIDs: Array(selectedAssetIDs))

        selectionManager.clearSelection()
        exitSelectMode()
    }

    /// 선택된 사진 최종 삭제 (Trash 전용)
    /// 게이트 평가 후 통과 시에만 실제 삭제 진행 (BM Phase 3 T018)
    @objc func trashDeleteSelectedTapped() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            return
        }

        evaluateGateAndExecute(trashCount: selectedAssetIDs.count) { [weak self] in
            // [Analytics] 이벤트 4-2: 삭제대기함 최종 삭제 (선택 모드)
            AnalyticsService.shared.countTrashPermanentDelete()

            Task {
                do {
                    try await self?.trashStore.permanentlyDelete(assetIDs: Array(selectedAssetIDs))
                    await MainActor.run {
                        self?.selectionManager.clearSelection()
                        self?.exitSelectMode()
                    }
                } catch {
                    // 취소 또는 오류 시 조용히 무시
                }
            }
        }
    }

    /// Select 모드 Delete 액션 (iOS 16~25 플로팅 UI)
    override func handleSelectModeDeleteAction() {
        trashDeleteSelectedTapped()
    }
}

// MARK: - LiquidGlassTabBarDelegate (Trash Select Mode)

extension TrashAlbumViewController: LiquidGlassTabBarDelegate {

    /// 탭 선택 (Trash Select 모드에서는 무시)
    func liquidGlassTabBar(_ tabBar: LiquidGlassTabBar, didSelectTabAt index: Int) {
        // Select 모드에서는 탭 전환 무시
    }

    /// Grid/Album Delete 버튼 (Trash에서는 사용 안 함)
    func liquidGlassTabBarDidTapDelete(_ tabBar: LiquidGlassTabBar) {
        // Trash에서는 trashDeleteSelectedTapped 사용
    }

    /// 삭제대기함 비우기 버튼 (Select 모드 아닐 때)
    func liquidGlassTabBarDidTapEmptyTrash(_ tabBar: LiquidGlassTabBar) {
        emptyTrashButtonTapped()
    }

    /// Trash Select 모드: Restore 버튼
    func liquidGlassTabBarDidTapRestore(_ tabBar: LiquidGlassTabBar) {
        trashRestoreSelectedTapped()
    }

    /// Trash Select 모드: Delete 버튼 (최종 삭제)
    func liquidGlassTabBarDidTapTrashDelete(_ tabBar: LiquidGlassTabBar) {
        trashDeleteSelectedTapped()
    }
}

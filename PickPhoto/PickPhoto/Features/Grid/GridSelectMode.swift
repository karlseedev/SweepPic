//
//  GridSelectMode.swift
//  PickPhoto
//
//  Created by Claude on 2025-12-31.
//  Description: GridViewController의 Select Mode 관련 기능 분리
//               - Select Mode 진입/종료 (T037~T045)
//               - Drag Selection (T040)
//               - SelectionManagerDelegate
//

import UIKit
import Photos
import AppCore

// MARK: - Select Mode (T037~T045)

extension GridViewController {

    /// Select 모드 진입 (T038)
    /// TabBarController에서 호출 (플로팅 UI의 Select 버튼 탭 시)
    func enterSelectMode() {
        guard !isSelectMode else { return }
        isSelectMode = true

        // iOS 26+: 시스템 UI 사용
        if #available(iOS 26.0, *) {
            enterSelectModeSystemUI()
        } else {
            // iOS 16~25: 플로팅 오버레이에 Select 모드 진입 알림
            if let tabBarController = tabBarController as? TabBarController {
                tabBarController.floatingOverlay?.enterSelectMode()
            }
        }

        // 드래그 선택 제스처 활성화 (T040)
        dragSelectGesture?.isEnabled = true

        // 컬렉션 뷰 리로드 (선택 UI 표시를 위해)
        collectionView.reloadData()

        print("[GridViewController] Entered select mode")
    }

    /// iOS 26+ Select 모드 진입 - 시스템 UI 사용
    @available(iOS 26.0, *)
    private func enterSelectModeSystemUI() {
        // 1. 네비바 우측에 Cancel 버튼 (텍스트로 표시)
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelSelectModeTapped)
        )

        // 2. 탭바 숨기기
        tabBarController?.tabBar.isHidden = true

        // 3. 툴바 아이템 설정: [flexSpace, 선택개수, flexSpace, Delete]
        let flexSpace1 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // 선택 개수 라벨 (UILabel을 customView로 사용)
        let countLabel = UILabel()
        countLabel.text = "항목 선택"
        countLabel.font = .systemFont(ofSize: 17)
        countLabel.textColor = .label
        countLabel.sizeToFit()
        let countItem = UIBarButtonItem(customView: countLabel)
        countItem.hidesSharedBackground = true  // iOS 26 Liquid Glass 배경 제거
        selectionCountBarItem = countItem

        let flexSpace2 = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)

        // Delete 버튼 (빨간색)
        let deleteItem = UIBarButtonItem(
            title: "Delete",
            style: .plain,
            target: self,
            action: #selector(deleteSelectModeTapped)
        )
        deleteItem.tintColor = .systemRed

        toolbarItems = [flexSpace1, countItem, flexSpace2, deleteItem]

        // 4. 툴바 표시
        navigationController?.setToolbarHidden(false, animated: true)

        print("[GridViewController] iOS 26+ system UI select mode entered")
    }

    /// iOS 26+ Cancel 버튼 탭 핸들러
    @objc func cancelSelectModeTapped() {
        exitSelectMode()
    }

    /// iOS 26+ Delete 버튼 탭 핸들러
    @objc func deleteSelectModeTapped() {
        deleteSelectedPhotos()
    }

    /// Select 모드 종료 (T038)
    /// TabBarController에서 호출 (Cancel 버튼 탭 시)
    func exitSelectMode() {
        guard isSelectMode else { return }
        isSelectMode = false

        // iOS 26+: 시스템 UI 원복
        if #available(iOS 26.0, *) {
            exitSelectModeSystemUI()
        } else {
            // iOS 16~25: 플로팅 오버레이에 Select 모드 종료 알림
            if let tabBarController = tabBarController as? TabBarController {
                tabBarController.floatingOverlay?.exitSelectMode()
            }
        }

        // 드래그 선택 제스처 비활성화 (T040)
        dragSelectGesture?.isEnabled = false

        // 선택 상태 초기화 (T037)
        selectionManager.clearSelection()

        // 컬렉션 뷰 리로드 (선택 UI 제거를 위해)
        collectionView.reloadData()

        print("[GridViewController] Exited select mode")
    }

    /// iOS 26+ Select 모드 종료 - 시스템 UI 원복
    @available(iOS 26.0, *)
    private func exitSelectModeSystemUI() {
        // 1. 네비바 우측에 Select 버튼 복원
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Select",
            style: .plain,
            target: self,
            action: #selector(selectButtonTapped)
        )

        // 2. 탭바 다시 표시
        tabBarController?.tabBar.isHidden = false

        // 3. 툴바 숨기기
        navigationController?.setToolbarHidden(true, animated: true)

        // 4. 툴바 아이템 참조 해제
        selectionCountBarItem = nil
        toolbarItems = nil

        print("[GridViewController] iOS 26+ system UI select mode exited")
    }

    /// iOS 26+ Select 버튼 탭 핸들러
    @objc func selectButtonTapped() {
        enterSelectMode()
    }

    /// 선택된 사진 삭제 (T043)
    /// TabBarController에서 호출 (Delete 버튼 탭 시)
    func deleteSelectedPhotos() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            print("[GridViewController] No photos selected for deletion")
            return
        }

        // TrashStore에 이동 (즉시 저장됨)
        trashStore.moveToTrash(assetIDs: Array(selectedAssetIDs))

        print("[GridViewController] Moved \(selectedAssetIDs.count) photos to trash")

        // 선택 상태 초기화 및 Select 모드 종료
        selectionManager.clearSelection()
        exitSelectMode()
    }

    /// 셀 선택 토글 (T039)
    /// - Parameter indexPath: 선택할 셀의 indexPath
    /// - Returns: 토글 후 선택 상태
    @discardableResult
    func toggleSelection(at indexPath: IndexPath) -> Bool {
        // 빈 셀은 선택 불가
        let padding = paddingCellCount
        guard indexPath.item >= padding else { return false }

        // 실제 에셋 인덱스 계산
        let assetIndexPath = IndexPath(item: indexPath.item - padding, section: indexPath.section)

        guard let assetID = dataSourceDriver.assetID(at: assetIndexPath) else { return false }

        // 딤드 사진(휴지통)은 선택 불가 (T044)
        guard !trashStore.isTrashed(assetID) else {
            print("[GridViewController] Cannot select trashed photo: \(assetID.prefix(8))...")
            return false
        }

        // 선택 토글
        let isSelected = selectionManager.toggle(assetID)

        // 셀 UI 업데이트
        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
            cell.isSelectedForDeletion = isSelected
        }

        return isSelected
    }
}

// MARK: - Drag Selection (T040)

extension GridViewController {

    /// 드래그 선택 제스처 핸들러
    /// iOS 사진 앱 동작:
    /// - 수평 드래그로 시작해야만 드래그 선택 모드 진입
    /// - 수직 드래그는 스크롤
    /// - 뒤로 드래그하면 선택 해제
    /// - 화면 가장자리로 드래그하면 자동 스크롤
    @objc func handleDragSelectGesture(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }

        let location = gesture.location(in: collectionView)
        let locationInView = gesture.location(in: view)

        switch gesture.state {
        case .began:
            handleDragSelectBegan(at: location)

        case .changed:
            handleDragSelectChanged(at: location)
            handleAutoScroll(at: locationInView)

        case .ended, .cancelled:
            handleDragSelectEnded()

        default:
            break
        }
    }

    /// 드래그 선택 시작 처리
    private func handleDragSelectBegan(at location: CGPoint) {
        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        let padding = paddingCellCount
        guard indexPath.item >= padding else { return }

        let assetIndex = indexPath.item - padding
        let assetIndexPath = IndexPath(item: assetIndex, section: indexPath.section)

        guard let assetID = dataSourceDriver.assetID(at: assetIndexPath),
              !trashStore.isTrashed(assetID) else { return }

        // 드래그 선택 상태 초기화
        dragSelectStartIndex = indexPath.item
        dragSelectCurrentIndex = indexPath.item
        dragSelectAffectedIndices = [indexPath.item]

        // 첫 번째 셀이 이미 선택된 상태인지 확인
        // 선택된 상태면 해제 모드, 아니면 선택 모드
        dragSelectIsSelecting = !selectionManager.isSelected(assetID)

        // 첫 번째 셀 선택/해제
        if dragSelectIsSelecting {
            selectionManager.select(assetID)
        } else {
            selectionManager.deselect(assetID)
        }

        // 셀 UI 업데이트
        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
            cell.isSelectedForDeletion = dragSelectIsSelecting
        }

        print("[GridViewController] Drag select began at index \(indexPath.item), mode: \(dragSelectIsSelecting ? "select" : "deselect")")
    }

    /// 드래그 선택 변경 처리
    private func handleDragSelectChanged(at location: CGPoint) {
        guard let startIndex = dragSelectStartIndex,
              let previousIndex = dragSelectCurrentIndex else { return }

        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        let currentIndex = indexPath.item
        let padding = paddingCellCount

        // 빈 셀 영역은 무시
        guard currentIndex >= padding else { return }

        // 같은 셀이면 무시
        guard currentIndex != previousIndex else { return }

        dragSelectCurrentIndex = currentIndex

        // 범위 계산: startIndex ~ currentIndex
        let minIndex = min(startIndex, currentIndex)
        let maxIndex = max(startIndex, currentIndex)
        let currentRange = Set(minIndex...maxIndex)

        // 이전에 영향받았던 인덱스 중 현재 범위에 없는 것들 (뒤로 드래그해서 벗어난 셀들)
        let indicesNoLongerInRange = dragSelectAffectedIndices.subtracting(currentRange)

        // 범위에서 벗어난 셀들: 원래 상태로 복원
        for index in indicesNoLongerInRange {
            guard index >= padding else { continue }

            let assetIndex = index - padding
            let assetIndexPath = IndexPath(item: assetIndex, section: 0)

            guard let assetID = dataSourceDriver.assetID(at: assetIndexPath),
                  !trashStore.isTrashed(assetID) else { continue }

            // 원래 상태로 복원 (선택 모드였으면 해제, 해제 모드였으면 선택)
            if dragSelectIsSelecting {
                selectionManager.deselect(assetID)
            } else {
                selectionManager.select(assetID)
            }

            // 셀 UI 업데이트
            let cellIndexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell {
                cell.isSelectedForDeletion = !dragSelectIsSelecting
            }
        }

        // 현재 범위 내의 새로운 셀들 처리
        let newIndicesInRange = currentRange.subtracting(dragSelectAffectedIndices)

        for index in newIndicesInRange {
            guard index >= padding else { continue }

            let assetIndex = index - padding
            let assetIndexPath = IndexPath(item: assetIndex, section: 0)

            guard let assetID = dataSourceDriver.assetID(at: assetIndexPath),
                  !trashStore.isTrashed(assetID) else { continue }

            // 선택/해제 모드에 따라 처리
            if dragSelectIsSelecting {
                selectionManager.select(assetID)
            } else {
                selectionManager.deselect(assetID)
            }

            // 셀 UI 업데이트
            let cellIndexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell {
                cell.isSelectedForDeletion = dragSelectIsSelecting
            }
        }

        // 영향받은 인덱스 업데이트
        dragSelectAffectedIndices = currentRange
    }

    /// 드래그 선택 종료 처리
    private func handleDragSelectEnded() {
        // 자동 스크롤 타이머 중지
        stopAutoScroll()

        // 상태 초기화
        dragSelectStartIndex = nil
        dragSelectCurrentIndex = nil
        dragSelectAffectedIndices = []

        print("[GridViewController] Drag select ended")
    }

    /// 자동 스크롤 처리 (화면 가장자리 드래그 시)
    private func handleAutoScroll(at locationInView: CGPoint) {
        let topEdge = view.safeAreaInsets.top + Self.autoScrollEdgeHeight
        let bottomEdge = view.bounds.height - view.safeAreaInsets.bottom - Self.autoScrollEdgeHeight

        if locationInView.y < topEdge {
            // 상단 가장자리: 위로 스크롤
            startAutoScroll(direction: -1)
        } else if locationInView.y > bottomEdge {
            // 하단 가장자리: 아래로 스크롤
            startAutoScroll(direction: 1)
        } else {
            // 가장자리 아님: 자동 스크롤 중지
            stopAutoScroll()
        }
    }

    /// 자동 스크롤 시작
    /// - Parameter direction: 스크롤 방향 (-1: 위, 1: 아래)
    private func startAutoScroll(direction: CGFloat) {
        // 이미 타이머가 있으면 무시
        guard autoScrollTimer == nil else { return }

        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let scrollAmount = Self.autoScrollSpeed / 60.0 * direction
            var newOffset = self.collectionView.contentOffset
            newOffset.y += scrollAmount

            // 범위 제한
            let minY = -self.collectionView.contentInset.top
            let maxY = self.collectionView.contentSize.height - self.collectionView.bounds.height + self.collectionView.contentInset.bottom

            newOffset.y = max(minY, min(maxY, newOffset.y))

            self.collectionView.setContentOffset(newOffset, animated: false)

            // 스크롤 중 현재 위치의 셀도 선택/해제 처리
            if let gesture = self.dragSelectGesture {
                let location = gesture.location(in: self.collectionView)
                self.handleDragSelectChanged(at: location)
            }
        }
    }

    /// 자동 스크롤 중지
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

// MARK: - SelectionManagerDelegate (T037, T042)

extension GridViewController: SelectionManagerDelegate {

    /// 선택 상태 변경 시 호출
    public func selectionManager(_ manager: SelectionManager, didChangeSelection assetIDs: Set<String>) {
        // 변경된 셀들만 업데이트
        for assetID in assetIDs {
            if let indexPath = dataSourceDriver.indexPath(for: assetID) {
                // padding 오프셋 적용
                let adjustedIndexPath = IndexPath(item: indexPath.item + paddingCellCount, section: indexPath.section)
                if let cell = collectionView.cellForItem(at: adjustedIndexPath) as? PhotoCell {
                    cell.isSelectedForDeletion = manager.isSelected(assetID)
                }
            }
        }
    }

    /// 선택 개수 변경 시 호출 (T042)
    public func selectionManager(_ manager: SelectionManager, selectionCountDidChange count: Int) {
        // iOS 26+: 시스템 툴바 라벨 업데이트
        if #available(iOS 26.0, *) {
            updateSelectionCountSystemUI(count)
        } else {
            // iOS 16~25: 플로팅 오버레이에 선택 개수 업데이트
            if let tabBarController = tabBarController as? TabBarController {
                tabBarController.floatingOverlay?.updateSelectionCount(count)
            }
        }

        print("[GridViewController] Selection count: \(count)")
    }

    /// iOS 26+ 선택 개수 업데이트 - 시스템 툴바 라벨
    @available(iOS 26.0, *)
    private func updateSelectionCountSystemUI(_ count: Int) {
        // 툴바 라벨 업데이트
        if let countItem = selectionCountBarItem,
           let label = countItem.customView as? UILabel {
            // 0개: "항목 선택", 1개 이상: "N개 항목 선택됨"
            label.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
            label.sizeToFit()
        }

        // Delete 버튼 활성화/비활성화
        if let deleteItem = toolbarItems?.last {
            deleteItem.isEnabled = count > 0
        }
    }
}

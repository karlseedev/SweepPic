//
//  BaseSelectMode.swift
//  PickPhoto
//
//  Description: BaseGridViewController의 Select Mode 공통 기능
//               - Select Mode 진입/종료
//               - iOS 버전별 UI 분기 (iOS 26+ 시스템 UI / iOS 16~25 플로팅 UI)
//               - Drag Selection
//               - SelectionManagerDelegate
//
//  Grid/Album/Trash 공용:
//  - enterSelectMode(), exitSelectMode()
//  - 드래그 선택 로직
//  - SelectionManagerDelegate 기본 구현
//
//  서브클래스에서 오버라이드:
//  - supportsSelectMode: Bool
//  - setupSelectionToolbar() -> [UIBarButtonItem]
//  - updateSelectionToolbar(count:)
//  - restoreNavigationBarAfterSelectMode()
//  - enterSelectModeFloatingUI() (Trash만)
//  - exitSelectModeFloatingUI() (Trash만)
//  - updateSelectionCountFloatingUI(_:) (Trash만)
//

import UIKit
import Photos
import AppCore

// MARK: - Select Mode Template Methods

extension BaseGridViewController {

    /// 선택 모드 지원 여부 (서브클래스에서 오버라이드)
    /// 기본값 false - 명시적으로 true로 설정한 VC만 선택 모드 활성화
    @objc var supportsSelectMode: Bool { false }

    /// iOS 26+ 툴바 버튼 구성 (서브클래스에서 오버라이드)
    /// Grid/Album: [flex, 선택개수, flex, Delete]
    /// Trash: [Restore, flex, 선택개수, flex, Delete]
    @objc func setupSelectionToolbar() -> [UIBarButtonItem] { [] }

    /// 툴바 선택 개수 업데이트 (서브클래스에서 오버라이드)
    @objc func updateSelectionToolbar(count: Int) {}

    /// iOS 26+ Select 종료 후 네비바 복원 (서브클래스에서 오버라이드)
    /// Grid/Album: Select 버튼만
    /// Trash: Select + 비우기 버튼
    @objc func restoreNavigationBarAfterSelectMode() {
        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Select",
                style: .plain,
                target: self,
                action: #selector(selectButtonTapped)
            )
        }
    }

    /// Select 모드에서 Delete 액션 처리 (서브클래스에서 오버라이드)
    @objc func handleSelectModeDeleteAction() {
        // 기본 구현: no-op
    }

    /// Select 모드에서 선택 가능한 에셋인지 판단
    /// 기본값: 휴지통 에셋은 선택 불가 (Grid/Album 공통)
    @objc func canSelectAssetInSelectMode(_ assetID: String) -> Bool {
        return !trashStore.isTrashed(assetID)
    }
}

// MARK: - Select Mode Enter/Exit

extension BaseGridViewController {

    /// Select 모드 진입
    func enterSelectMode() {
        guard supportsSelectMode else {
            print("[BaseGridViewController] Select mode not supported")
            return
        }
        guard !isSelectMode else { return }
        isSelectMode = true

        // iOS 26+: 시스템 UI 사용
        if #available(iOS 26.0, *) {
            enterSelectModeSystemUI()
        } else {
            // iOS 16~25: 플로팅 오버레이
            enterSelectModeFloatingUI()
        }

        // 드래그 선택 제스처 활성화
        dragSelectGesture?.isEnabled = true

        // 스와이프/투핑거탭 제스처 비활성화
        updateSwipeDeleteGestureEnabled()

        // 선택 UI 갱신 (전체 리로드 대신 visible 셀만 업데이트)
        updateVisibleSelectionUI()

        print("[BaseGridViewController] Entered select mode")
    }

    /// Select 모드 종료
    func exitSelectMode() {
        guard isSelectMode else { return }
        isSelectMode = false

        // iOS 26+: 시스템 UI 복원
        if #available(iOS 26.0, *) {
            exitSelectModeSystemUI()
        } else {
            // iOS 16~25: 플로팅 오버레이 복원
            exitSelectModeFloatingUI()
        }

        // 드래그 선택 제스처 비활성화
        dragSelectGesture?.isEnabled = false

        // 스와이프/투핑거탭 제스처 복원
        updateSwipeDeleteGestureEnabled()

        // 선택 초기화
        selectionManager.clearSelection()

        // 선택 UI 갱신 (전체 리로드 대신 visible 셀만 업데이트)
        updateVisibleSelectionUI()

        print("[BaseGridViewController] Exited select mode")
    }
}

// MARK: - Select Mode Cell Selection

extension BaseGridViewController {

    /// Select 모드에서 셀 선택 토글
    /// - Parameter indexPath: 선택할 셀의 indexPath
    /// - Returns: 토글 후 선택 상태
    @discardableResult
    func toggleSelectionForSelectMode(at indexPath: IndexPath) -> Bool {
        let padding = paddingCellCount
        guard indexPath.item >= padding else { return false }

        let assetIndex = indexPath.item - padding
        guard let assetID = gridDataSource.assetID(at: assetIndex) else { return false }

        // Grid/Album은 휴지통 에셋 선택 금지, Trash는 오버라이드로 허용
        guard canSelectAssetInSelectMode(assetID) else {
            print("[BaseGridViewController] Cannot select asset in select mode")
            return false
        }

        let isSelected = selectionManager.toggle(assetID)

        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
            cell.isSelectedForDeletion = isSelected
        }

        return isSelected
    }

    /// Select 모드 전환 시 visible 셀의 선택 UI만 갱신
    private func updateVisibleSelectionUI() {
        let padding = paddingCellCount
        let shouldShowSelection = isSelectMode

        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item >= padding else { continue }
            let assetIndex = indexPath.item - padding
            guard let assetID = gridDataSource.assetID(at: assetIndex) else { continue }

            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
                let isSelected = shouldShowSelection && selectionManager.isSelected(assetID)
                cell.isSelectedForDeletion = isSelected
            }
        }
    }
}

// MARK: - iOS 26+ System UI

extension BaseGridViewController {

    /// iOS 26+ Select 모드 진입 - 시스템 UI 사용
    @available(iOS 26.0, *)
    func enterSelectModeSystemUI() {
        // 1. Cancel 버튼
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "Cancel",
            style: .plain,
            target: self,
            action: #selector(cancelSelectModeTapped)
        )

        // 2. 탭바 숨기기
        tabBarController?.tabBar.isHidden = true

        // 3. 서브클래스의 툴바 설정 호출
        toolbarItems = setupSelectionToolbar()

        // 4. 툴바 표시
        navigationController?.setToolbarHidden(false, animated: true)

        print("[BaseGridViewController] iOS 26+ system UI select mode entered")
    }

    /// iOS 26+ Select 모드 종료 - 시스템 UI 복원
    @available(iOS 26.0, *)
    func exitSelectModeSystemUI() {
        // 1. 툴바 숨기기
        navigationController?.setToolbarHidden(true, animated: true)

        // 2. 탭바 복원
        tabBarController?.tabBar.isHidden = false

        // 3. 네비바 복원 (서브클래스에서 오버라이드 가능)
        restoreNavigationBarAfterSelectMode()

        // 4. 참조 해제
        selectionCountBarItem = nil
        toolbarItems = nil

        print("[BaseGridViewController] iOS 26+ system UI select mode exited")
    }

    /// iOS 26+ Cancel 버튼 탭 핸들러
    @objc func cancelSelectModeTapped() {
        exitSelectMode()
    }

    /// iOS 26+ Select 버튼 탭 핸들러
    @objc func selectButtonTapped() {
        enterSelectMode()
    }
}

// MARK: - iOS 16~25 Floating UI (기본 구현 - Grid/Album용)

extension BaseGridViewController {

    /// 플로팅 UI 선택 모드 진입 (Trash에서 오버라이드)
    /// 기본 구현: Grid/Album용 selectModeContainer 사용
    func enterSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.enterSelectMode { [weak self] in
            self?.exitSelectMode()
        }
        overlay.tabBar.enterSelectMode(animated: true)

        print("[BaseGridViewController] Floating UI select mode entered")
    }

    /// 플로팅 UI 선택 모드 종료 (Trash에서 오버라이드)
    func exitSelectModeFloatingUI() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }

        overlay.titleBar.exitSelectMode()
        overlay.tabBar.exitSelectMode(animated: true)

        print("[BaseGridViewController] Floating UI select mode exited")
    }

    /// 플로팅 UI 선택 개수 업데이트 (Trash에서 오버라이드)
    func updateSelectionCountFloatingUI(_ count: Int) {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else { return }
        overlay.tabBar.updateSelectionCount(count)
    }
}

// MARK: - Drag Selection Setup

extension BaseGridViewController {

    /// 드래그 선택 제스처 설정 (setupGestures에서 호출)
    func setupDragSelectGesture() {
        guard supportsSelectMode else { return }

        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragSelectGesture(_:)))
        dragGesture.delegate = self
        dragGesture.isEnabled = false  // Select 모드 진입 시 활성화
        collectionView.addGestureRecognizer(dragGesture)
        dragSelectGesture = dragGesture

        print("[BaseGridViewController] Drag select gesture configured")
    }

    /// 드래그 선택 제스처 핸들러
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
        guard let asset = gridDataSource.asset(at: assetIndex) else { return }

        let assetID = asset.localIdentifier

        // 딤드 사진(휴지통)은 선택 불가
        guard !trashStore.isTrashed(assetID) else { return }

        // 드래그 선택 상태 초기화
        dragSelectStartIndex = indexPath.item
        dragSelectCurrentIndex = indexPath.item
        dragSelectAffectedIndices = [indexPath.item]

        // 첫 번째 셀이 이미 선택된 상태인지 확인
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

        print("[BaseGridViewController] Drag select began at index \(indexPath.item)")
    }

    /// 드래그 선택 변경 처리
    private func handleDragSelectChanged(at location: CGPoint) {
        guard let startIndex = dragSelectStartIndex,
              let previousIndex = dragSelectCurrentIndex else { return }

        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        let currentIndex = indexPath.item
        let padding = paddingCellCount

        guard currentIndex >= padding else { return }
        guard currentIndex != previousIndex else { return }

        dragSelectCurrentIndex = currentIndex

        // 범위 계산
        let minIndex = min(startIndex, currentIndex)
        let maxIndex = max(startIndex, currentIndex)
        let currentRange = Set(minIndex...maxIndex)

        // 범위에서 벗어난 셀들: 원래 상태로 복원
        let indicesNoLongerInRange = dragSelectAffectedIndices.subtracting(currentRange)

        for index in indicesNoLongerInRange {
            guard index >= padding else { continue }

            let assetIndex = index - padding
            guard let asset = gridDataSource.asset(at: assetIndex) else { continue }

            let assetID = asset.localIdentifier
            guard !trashStore.isTrashed(assetID) else { continue }

            if dragSelectIsSelecting {
                selectionManager.deselect(assetID)
            } else {
                selectionManager.select(assetID)
            }

            let cellIndexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell {
                cell.isSelectedForDeletion = !dragSelectIsSelecting
            }
        }

        // 새로운 셀들 처리
        let newIndicesInRange = currentRange.subtracting(dragSelectAffectedIndices)

        for index in newIndicesInRange {
            guard index >= padding else { continue }

            let assetIndex = index - padding
            guard let asset = gridDataSource.asset(at: assetIndex) else { continue }

            let assetID = asset.localIdentifier
            guard !trashStore.isTrashed(assetID) else { continue }

            if dragSelectIsSelecting {
                selectionManager.select(assetID)
            } else {
                selectionManager.deselect(assetID)
            }

            let cellIndexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell {
                cell.isSelectedForDeletion = dragSelectIsSelecting
            }
        }

        dragSelectAffectedIndices = currentRange
    }

    /// 드래그 선택 종료 처리
    private func handleDragSelectEnded() {
        stopAutoScroll()

        dragSelectStartIndex = nil
        dragSelectCurrentIndex = nil
        dragSelectAffectedIndices = []

        print("[BaseGridViewController] Drag select ended")
    }

    /// 자동 스크롤 처리
    private func handleAutoScroll(at locationInView: CGPoint) {
        let topEdge = view.safeAreaInsets.top + Self.autoScrollEdgeHeight
        let bottomEdge = view.bounds.height - view.safeAreaInsets.bottom - Self.autoScrollEdgeHeight

        if locationInView.y < topEdge {
            startAutoScroll(direction: -1)
        } else if locationInView.y > bottomEdge {
            startAutoScroll(direction: 1)
        } else {
            stopAutoScroll()
        }
    }

    /// 자동 스크롤 시작
    private func startAutoScroll(direction: CGFloat) {
        guard autoScrollTimer == nil else { return }

        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let scrollAmount = Self.autoScrollSpeed / 60.0 * direction
            var newOffset = self.collectionView.contentOffset
            newOffset.y += scrollAmount

            let minY = -self.collectionView.contentInset.top
            let maxY = self.collectionView.contentSize.height - self.collectionView.bounds.height + self.collectionView.contentInset.bottom

            newOffset.y = max(minY, min(maxY, newOffset.y))

            self.collectionView.setContentOffset(newOffset, animated: false)

            if let gesture = self.dragSelectGesture {
                let location = gesture.location(in: self.collectionView)
                self.handleDragSelectChanged(at: location)
            }
        }
    }

    /// 자동 스크롤 중지
    func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

// MARK: - SelectionManagerDelegate

extension BaseGridViewController: SelectionManagerDelegate {

    /// 선택 상태 변경 시 호출
    public func selectionManager(_ manager: SelectionManager, didChangeSelection assetIDs: Set<String>) {
        // 변경된 셀만 업데이트 (선택 상태는 manager 기준)
        for assetID in assetIDs {
            guard let assetIndex = gridDataSource.assetIndex(for: assetID) else { continue }
            let indexPath = IndexPath(item: assetIndex + paddingCellCount, section: 0)
            if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
                cell.isSelectedForDeletion = manager.isSelected(assetID)
            }
        }
    }

    /// 선택 개수 변경 시 호출
    public func selectionManager(_ manager: SelectionManager, selectionCountDidChange count: Int) {
        // iOS 26+: 툴바 업데이트
        if #available(iOS 26.0, *) {
            updateSelectionToolbar(count: count)
        } else {
            // iOS 16~25: 플로팅 UI 업데이트
            updateSelectionCountFloatingUI(count)
        }

        print("[BaseGridViewController] Selection count: \(count)")
    }
}

// MARK: - Setup Delegate

extension BaseGridViewController {

    /// SelectionManager delegate 설정 (viewDidLoad에서 호출)
    func setupSelectionManagerDelegate() {
        selectionManager.delegate = self
    }
}

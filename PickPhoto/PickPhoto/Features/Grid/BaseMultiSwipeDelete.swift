//
//  BaseMultiSwipeDelete.swift
//  PickPhoto
//
//  Description: BaseGridViewController의 다중 셀 스와이프 삭제 확장
//               - 단일 스와이프에서 손가락이 다른 셀에 도달하면 다중 모드 진입
//               - 시작 셀(앵커)과 현재 셀의 행/열로 사각형 범위 선택
//               - 자동 스크롤 콜백 연동으로 화면 밖 확장 지원
//               - 다중 모드 진입 시 항상 확정 (취소 없음, 제스처 cancel 제외)
//
//  애니메이션 분기:
//    ● 삭제 모드 (deleteAction=true): 빨간색 채워짐
//      - 지나간 셀: setFullDimmed | 커튼 셀: 빨간색 채워지는 커튼
//    ● 복원 모드 (deleteAction=false): 빨간색 걷힘
//      - 지나간 셀: setRestoredPreview | 커튼 셀: 빨간색 밀어내는 커튼
//    ● 커튼 조건: 셀의 실제 상태가 전환 대상일 때만 (이미 대상 상태면 즉시 적용)
//

import UIKit
import AppCore
import OSLog

// MARK: - Multi Swipe Delete

extension BaseGridViewController {

    // MARK: - 다중 모드 진입

    /// 손가락이 다른 셀에 도달 시 호출 — 단일 → 다중 모드 전환
    /// - 앵커 셀의 커튼 딤드를 대상 상태로 전환
    /// - 자동 스크롤 콜백을 멀티 스와이프용으로 설정
    func enterMultiSwipeMode() {
        guard let anchorIndexPath = swipeDeleteState.targetIndexPath else { return }

        // 1. 다중 모드 플래그 설정
        swipeDeleteState.isMultiMode = true

        // 2. 앵커 정보 설정
        let columnCount = currentGridColumnCount.rawValue
        swipeDeleteState.anchorItem = anchorIndexPath.item
        swipeDeleteState.anchorRow = anchorIndexPath.item / columnCount
        swipeDeleteState.anchorCol = anchorIndexPath.item % columnCount

        // 3. 삭제/복원 방향 결정 (앵커 셀 상태 기준)
        // isTrashed인 셀은 복원, 아니면 삭제
        swipeDeleteState.deleteAction = !swipeDeleteState.targetIsTrashed

        // 4. 앵커 셀 선택 등록
        swipeDeleteState.selectedItems = [anchorIndexPath.item]

        // 5. 스와이프 방향 저장 (앵커 셀 복귀 시 커튼 방향 결정용)
        //    단일 모드의 progress가 셀 경계에서 100%가 아닐 수 있으므로 애니메이션 사용
        if let anchorCell = collectionView.cellForItem(at: anchorIndexPath) as? PhotoCell,
           let gesture = swipeDeleteState.swipeGesture {
            // ★ 복구 모드 색상 준비 (began에서 이미 설정되었을 수 있지만 안전하게)
            if swipeActionIsRestore {
                anchorCell.prepareSwipeOverlay(style: .restore)
            }
            let translation = gesture.translation(in: collectionView)
            let direction: PhotoCell.SwipeDirection = translation.x > 0 ? .right : .left
            swipeDeleteState.swipeDirection = direction
            anchorCell.animateCurtainToTarget(
                direction: direction,
                isTrashed: swipeDeleteState.targetIsTrashed
            )
        }

        // 6. 자동 스크롤 콜백 설정 (멀티 스와이프용)
        autoScrollGesture = swipeDeleteState.swipeGesture
        autoScrollHandler = { [weak self] loc in self?.handleMultiSwipeChanged(at: loc) }

        // 7. 선택 햅틱 피드백
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()
    }

    // MARK: - 사각형 범위 계산

    /// 앵커 셀과 현재 셀의 행/열로 사각형 범위의 item 인덱스를 계산
    /// - Parameters:
    ///   - anchorRow: 앵커 셀 행
    ///   - anchorCol: 앵커 셀 열
    ///   - currentRow: 현재 셀 행
    ///   - currentCol: 현재 셀 열
    ///   - columnCount: 현재 열 수
    ///   - paddingCount: 상단 패딩 셀 수
    ///   - totalItems: 컬렉션 뷰 전체 아이템 수 (paddingCellCount + assetCount)
    /// - Returns: 범위에 포함되는 유효 item 인덱스 집합
    ///
    /// **같은 행**: 앵커 열 ~ 현재 열만 선택 (수평 범위)
    /// **다른 행**: 범위 내 각 행의 모든 열 선택 (선택 모드 드래그와 동일)
    func calculateRectangleSelection(
        anchorRow: Int, anchorCol: Int,
        currentRow: Int, currentCol: Int,
        columnCount: Int, paddingCount: Int, totalItems: Int
    ) -> Set<Int> {
        var result: Set<Int> = []

        if anchorRow == currentRow {
            // 같은 행: 열 범위만 선택
            let minCol = min(anchorCol, currentCol)
            let maxCol = max(anchorCol, currentCol)
            for col in minCol...maxCol {
                let item = anchorRow * columnCount + col
                if item >= paddingCount && item < totalItems {
                    result.insert(item)
                }
            }
        } else {
            // 다른 행: 각 행의 모든 열 선택
            let minRow = min(anchorRow, currentRow)
            let maxRow = max(anchorRow, currentRow)
            for row in minRow...maxRow {
                for col in 0..<columnCount {
                    let item = row * columnCount + col
                    if item >= paddingCount && item < totalItems {
                        result.insert(item)
                    }
                }
            }
        }
        return result
    }

    // MARK: - 다중 모드 Changed 핸들러

    /// 자동 스크롤 틱 또는 제스처 이동 시 호출 — 사각형 범위 업데이트
    ///
    /// **애니메이션 분기:**
    /// - 삭제 모드: 지나간 셀 = 빨간색 전체, 커튼 셀 = 빨간색 채워짐
    /// - 복원 모드: 지나간 셀 = 빨간색 제거, 커튼 셀 = 빨간색 걷힘
    /// - 좌우 변위 없음 (순수 상하): 커튼 없이 모두 즉시 적용
    /// - 커튼은 셀의 실제 상태가 전환 대상일 때만 (이미 대상 상태면 즉시 적용)
    ///
    /// - Parameter location: collectionView 좌표계 위치
    func handleMultiSwipeChanged(at location: CGPoint) {
        // 간격(2pt) 영역에서 nil 반환 시 마지막 유효 위치 유지
        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        let columnCount = currentGridColumnCount.rawValue
        let currentItem = indexPath.item
        let currentRow = currentItem / columnCount
        let currentCol = currentItem % columnCount
        let deleteAction = swipeDeleteState.deleteAction

        // 사각형 범위 계산
        let totalItems = paddingCellCount + gridDataSource.assetCount
        let newSelection = calculateRectangleSelection(
            anchorRow: swipeDeleteState.anchorRow,
            anchorCol: swipeDeleteState.anchorCol,
            currentRow: currentRow,
            currentCol: currentCol,
            columnCount: columnCount,
            paddingCount: paddingCellCount,
            totalItems: totalItems
        )

        let previousSelection = swipeDeleteState.selectedItems
        let prevCurtainItem = swipeDeleteState.curtainItem

        let selectionChanged = newSelection != previousSelection
        let curtainCellChanged = currentItem != prevCurtainItem

        // 커튼 효과 조건: 같은 행 + 좌우 변위 — 다른 행이면 모든 셀 즉시 적용
        let isSameRow = currentRow == swipeDeleteState.anchorRow
        let hasHorizontalDisplacement = isSameRow && currentCol != swipeDeleteState.anchorCol

        // --- 1) 범위에서 빠진 셀 → 원래 상태로 복귀 ---
        if selectionChanged {
            let removed = previousSelection.subtracting(newSelection)
            for item in removed {
                let ip = IndexPath(item: item, section: 0)
                if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                    cell.clearDimmed()
                }
            }
        }

        // --- 2) 이전 커튼 셀 → 대상 상태로 전환 (아직 선택 범위 내이면) ---
        if curtainCellChanged, let prev = prevCurtainItem, newSelection.contains(prev) {
            let ip = IndexPath(item: prev, section: 0)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                if swipeActionIsRestore { cell.prepareSwipeOverlay(style: .restore) }
                applyTargetState(to: cell, deleteAction: deleteAction)
            }
        }

        // --- 3) 새로 추가된 셀 → 대상 상태 적용 (커튼 대상 셀 제외) ---
        if selectionChanged {
            let added = newSelection.subtracting(previousSelection)
            for item in added {
                // 커튼 후보 셀은 아래에서 별도 처리
                if hasHorizontalDisplacement && item == currentItem { continue }
                let ip = IndexPath(item: item, section: 0)
                if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
                   !cell.isAnimating {
                    if swipeActionIsRestore { cell.prepareSwipeOverlay(style: .restore) }
                    applyTargetState(to: cell, deleteAction: deleteAction)
                }
            }
        }

        // --- 4) 현재 셀: 커튼 or 즉시 적용 ---
        if currentItem == swipeDeleteState.anchorItem && isSameRow {
            // ★ 앵커 셀 복귀: 셀 프레임 기반 커튼 효과 (손가락 위치에 따라 취소 가능)
            //   다중 모드 진입 시 저장된 swipeDirection 사용
            let ip = IndexPath(item: currentItem, section: 0)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
               let attrs = collectionView.layoutAttributesForItem(at: ip) {
                let cellFrame = attrs.frame
                let direction = swipeDeleteState.swipeDirection

                // 셀 프레임 기반 progress — 원래 스와이프 방향 끝에서 100%, 반대쪽에서 0%
                let progress: CGFloat
                switch direction {
                case .right:
                    progress = min(1.0, max(0, (location.x - cellFrame.minX) / cellFrame.width))
                case .left:
                    progress = min(1.0, max(0, (cellFrame.maxX - location.x) / cellFrame.width))
                }

                cell.setDimmedProgress(progress, direction: direction, isTrashed: swipeDeleteState.targetIsTrashed)
            }
            swipeDeleteState.curtainItem = currentItem

        } else if hasHorizontalDisplacement && newSelection.contains(currentItem) {
            // 수평 변위 있는 비-앵커 셀: 기존 커튼 로직
            let ip = IndexPath(item: currentItem, section: 0)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
               let attrs = collectionView.layoutAttributesForItem(at: ip) {

                let cellIsTrashed = cell.isTrashed

                // 커튼 조건: 셀의 상태가 전환 대상일 때만
                // - 삭제 모드 + 셀 미삭제 → 빨간색 채워지는 커튼
                // - 복원 모드 + 셀 삭제됨 → 빨간색 걷히는 커튼
                let needsTransition = (deleteAction && !cellIsTrashed) ||
                                      (!deleteAction && cellIsTrashed)

                if needsTransition {
                    if swipeActionIsRestore { cell.prepareSwipeOverlay(style: .restore) }
                    let cellFrame = attrs.frame

                    // 커튼 방향: 앵커 → 현재 수평 방향
                    let direction: PhotoCell.SwipeDirection =
                        currentCol > swipeDeleteState.anchorCol ? .right : .left

                    // 셀 내 progress 계산
                    let progress: CGFloat
                    switch direction {
                    case .right:
                        // 왼쪽에서 채워짐/걷힘 → 오른쪽 끝에 가까울수록 1.0
                        progress = min(1.0, max(0, (location.x - cellFrame.minX) / cellFrame.width))
                    case .left:
                        // 오른쪽에서 채워짐/걷힘 → 왼쪽 끝에 가까울수록 1.0
                        progress = min(1.0, max(0, (cellFrame.maxX - location.x) / cellFrame.width))
                    }

                    cell.setDimmedProgress(progress, direction: direction, isTrashed: cellIsTrashed)
                } else {
                    // 이미 대상 상태 → 즉시 적용 (커튼 불필요)
                    applyTargetState(to: cell, deleteAction: deleteAction)
                }
            }
            swipeDeleteState.curtainItem = currentItem
        } else {
            // 순수 상하 이동: 현재 셀도 즉시 적용, 커튼 없음
            if selectionChanged || curtainCellChanged {
                let ip = IndexPath(item: currentItem, section: 0)
                if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
                   newSelection.contains(currentItem),
                   !cell.isAnimating {
                    applyTargetState(to: cell, deleteAction: deleteAction)
                }
            }
            swipeDeleteState.curtainItem = nil
        }

        // --- 5) 선택 상태 업데이트 ---
        swipeDeleteState.selectedItems = newSelection

        // --- 5-1) Reconciliation: stale animation이 딤드를 덮어쓴 셀 보정 ---
        // 셀 재사용 시 중단된 애니메이션의 completion이 지연 실행되어
        // cellForItemAt에서 적용한 딤드 상태를 파괴할 수 있음 → 강제 재적용
        for cell in collectionView.visibleCells {
            guard let photoCell = cell as? PhotoCell,
                  let indexPath = collectionView.indexPath(for: cell),
                  newSelection.contains(indexPath.item),
                  indexPath.item != swipeDeleteState.curtainItem,
                  !photoCell.isAnimating else { continue }

            if deleteAction {
                // 삭제 모드: 딤드가 안 칠해진 셀 보정
                if !photoCell.isDimmedActive {
                    if swipeActionIsRestore { photoCell.prepareSwipeOverlay(style: .restore) }
                    applyTargetState(to: photoCell, deleteAction: deleteAction)
                }
            } else {
                // 복원 모드: 딤드가 남아있는 셀 보정
                if photoCell.isDimmedActive {
                    if swipeActionIsRestore { photoCell.prepareSwipeOverlay(style: .restore) }
                    applyTargetState(to: photoCell, deleteAction: deleteAction)
                }
            }
        }

        // --- 6) 새 셀 추가 시 선택 햅틱 ---
        if selectionChanged {
            let added = newSelection.subtracting(previousSelection)
            if !added.isEmpty {
                let selectionFeedback = UISelectionFeedbackGenerator()
                selectionFeedback.selectionChanged()
            }
        }
    }

    // MARK: - 대상 상태 적용 헬퍼

    /// 삭제/복원 모드에 따라 셀에 대상 상태를 즉시 적용
    /// - 삭제 모드: 빨간색 전체 딤드
    /// - 복원 모드: 빨간색 제거 (복원 미리보기)
    private func applyTargetState(to cell: PhotoCell, deleteAction: Bool) {
        if deleteAction {
            cell.setFullDimmed(isTrashed: cell.isTrashed)
        } else {
            cell.setRestoredPreview()
        }
    }

    // MARK: - 다중 모드 Confirm

    /// 다중 모드 확정 — 선택된 모든 셀을 일괄 삭제/복원
    func confirmMultiSwipeDelete() {
        // 1. 자동 스크롤 정지 및 콜백 해제
        stopAutoScroll()
        autoScrollGesture = nil
        autoScrollHandler = nil

        let selectedItems = swipeDeleteState.selectedItems
        let deleteAction = swipeDeleteState.deleteAction
        let padding = paddingCellCount

        // 2. 보이는 선택 셀들에 isAnimating 설정
        for item in selectedItems {
            let ip = IndexPath(item: item, section: 0)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                cell.isAnimating = true

                // 삭제 모드 커튼 셀: 전체 딤드로 전환 후 confirm 애니메이션
                // 복원 모드 커튼 셀: 그대로 두면 confirm이 남은 빨간색을 페이드아웃
                if item == swipeDeleteState.curtainItem && deleteAction {
                    cell.setFullDimmed(isTrashed: cell.isTrashed)
                }
            }
        }

        // 3. assetID 배열 수집 (이미 대상 상태인 에셋은 스킵)
        var assetIDsToProcess: [String] = []
        for item in selectedItems {
            let assetIndex = item - padding
            guard assetIndex >= 0,
                  let assetID = gridDataSource.assetID(at: assetIndex) else { continue }

            // 이미 대상 상태인 에셋 스킵
            let alreadyInTargetState: Bool
            if swipeActionIsRestore {
                // 복구 모드: 대상 = "not trashed" → 이미 복구된 것만 스킵
                alreadyInTargetState = !trashStore.isTrashed(assetID)
            } else {
                alreadyInTargetState = deleteAction
                    ? trashStore.isTrashed(assetID)
                    : !trashStore.isTrashed(assetID)
            }
            if alreadyInTargetState { continue }

            assetIDsToProcess.append(assetID)
        }

        // 4. 보이는 셀들 confirmDimmedAnimation
        let toTrashed = deleteAction
        for item in selectedItems {
            let ip = IndexPath(item: item, section: 0)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                cell.confirmDimmedAnimation(toTrashed: toTrashed) {
                    cell.isAnimating = false
                }
            }
        }

        // 5. TrashStore 배치 호출 (fire-and-forget, 선택 모드와 동일 패턴)
        if swipeActionIsRestore {
            // ★ 삭제 애니메이션 준비 (deleteItems용 indexPath 전달)
            let restoreIndexPaths = Array(selectedItems).sorted().map { IndexPath(item: $0, section: 0) }
            prepareSwipeRestoreAnimation(at: restoreIndexPaths)
            trashStore.restore(assetIDs: assetIDsToProcess)
        } else if deleteAction {
            trashStore.moveToTrash(assetIDs: assetIDsToProcess)
        } else {
            trashStore.restore(assetIDs: assetIDsToProcess)
        }

        // 6. Analytics: 개수만큼 카운트
        let analyticsSource: DeleteSource = self is AlbumGridViewController ? .album : .library
        for _ in assetIDsToProcess {
            if swipeActionIsRestore {
                AnalyticsService.shared.countTrashRestore()
            } else if deleteAction {
                AnalyticsService.shared.countGridSwipeDelete(source: analyticsSource)
            } else {
                AnalyticsService.shared.countGridSwipeRestore(source: analyticsSource)
            }
        }

        // 7. 확정 햅틱 피드백 (셀 추가 시와 동일한 selectionChanged)
        let selectionFeedback = UISelectionFeedbackGenerator()
        selectionFeedback.selectionChanged()

        // 8. 상태 초기화
        swipeDeleteState.reset()
    }

    // MARK: - 다중 모드 Cancel

    /// 다중 모드 취소 — 모든 선택 셀의 딤드를 원래 상태로 복귀
    /// cancelDimmedAnimation이 cell.isTrashed 기준으로 원래 상태 복원
    func cancelMultiSwipeDelete() {
        // 1. 자동 스크롤 정지 및 콜백 해제
        stopAutoScroll()
        autoScrollGesture = nil
        autoScrollHandler = nil

        // 2. 보이는 셀들 cancelDimmedAnimation (원래 상태로 복귀)
        for item in swipeDeleteState.selectedItems {
            let ip = IndexPath(item: item, section: 0)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                cell.cancelDimmedAnimation {
                    cell.isAnimating = false
                }
            }
        }
        // 보이지 않는 셀은 cellForItemAt에서 자연히 정상 상태로 복귀

        // 3. 상태 초기화
        swipeDeleteState.reset()
    }
}

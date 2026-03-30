//
//  PreviewGridViewController+MultiSwipe.swift
//  SweepPic
//
//  미리보기 그리드의 다중 셀 스와이프 삭제 + 자동 스크롤
//  - BaseMultiSwipeDelete.swift 기반이나 다중 섹션 대응
//  - 선택은 swipeTargetSection 내에서만 동작 (배너 경계 안 넘음)
//  - ⚠️ 모든 IndexPath에 swipeTargetSection 사용 (section: 0 하드코딩 금지)
//  - 삭제 = "제외" (excludedAssetIDs 아닌 previewResult 직접 갱신)
//

import UIKit
import AppCore
import OSLog

// MARK: - Multi Swipe Delete

extension PreviewGridViewController {

    // MARK: - 다중 모드 진입

    /// 단일 → 다중 모드 전환 (손가락이 같은 섹션의 다른 셀에 도달 시)
    func enterMultiSwipeMode() {
        guard let anchorIndexPath = swipeDeleteState.targetIndexPath else { return }

        // 1. 다중 모드 플래그
        swipeDeleteState.isMultiMode = true

        // 2. 앵커 정보 (section 내 item 기준 행/열)
        let columnCount = Int(columns)
        swipeDeleteState.anchorItem = anchorIndexPath.item
        swipeDeleteState.anchorRow = anchorIndexPath.item / columnCount
        swipeDeleteState.anchorCol = anchorIndexPath.item % columnCount

        // 3. 제외/해제 방향 결정 (앵커 셀 상태 기준)
        // targetIsTrashed=false(일반) → deleteAction=true(제외)
        // targetIsTrashed=true(제외됨) → deleteAction=false(해제)
        swipeDeleteState.deleteAction = !swipeDeleteState.targetIsTrashed

        // 4. 앵커 셀 선택 등록
        swipeDeleteState.selectedItems = [anchorIndexPath.item]

        // 5. 앵커 셀 커튼 전환 애니메이션
        if let anchorCell = collectionView.cellForItem(at: anchorIndexPath) as? PhotoCell,
           let gesture = swipeDeleteState.swipeGesture {
            let translation = gesture.translation(in: collectionView)
            let direction: PhotoCell.SwipeDirection = translation.x > 0 ? .right : .left
            swipeDeleteState.swipeDirection = direction
            anchorCell.animateCurtainToTarget(direction: direction, isTrashed: swipeDeleteState.targetIsTrashed)
        }

        // 6. 자동 스크롤 콜백 설정
        autoScrollGesture = swipeDeleteState.swipeGesture
        autoScrollHandler = { [weak self] loc in self?.handleMultiSwipeChanged(at: loc) }

        // 7. 하단 버튼 비활성화 (expand/collapse/cleanup 차단)
        bottomView.isUserInteractionEnabled = false

        // 8. 선택 햅틱
        let feedback = UISelectionFeedbackGenerator()
        feedback.selectionChanged()
    }

    // MARK: - 사각형 범위 계산

    /// 앵커 셀과 현재 셀의 행/열로 사각형 범위 계산
    /// - 같은 행: 열 범위만 선택
    /// - 다른 행: 각 행의 모든 열 선택
    /// - padding 없음 (item = 배열 인덱스)
    func calculateRectangleSelection(
        anchorRow: Int, anchorCol: Int,
        currentRow: Int, currentCol: Int,
        columnCount: Int, totalItemsInSection: Int
    ) -> Set<Int> {
        var result: Set<Int> = []

        if anchorRow == currentRow {
            // 같은 행: 열 범위만
            let minCol = min(anchorCol, currentCol)
            let maxCol = max(anchorCol, currentCol)
            for col in minCol...maxCol {
                let item = anchorRow * columnCount + col
                if item < totalItemsInSection { result.insert(item) }
            }
        } else {
            // 다른 행: 행 전체
            let minRow = min(anchorRow, currentRow)
            let maxRow = max(anchorRow, currentRow)
            for row in minRow...maxRow {
                for col in 0..<columnCount {
                    let item = row * columnCount + col
                    if item < totalItemsInSection { result.insert(item) }
                }
            }
        }
        return result
    }

    // MARK: - 다중 모드 Changed

    /// 자동 스크롤 틱 또는 제스처 이동 시 — 사각형 범위 업데이트
    /// - Parameter location: collectionView 좌표계
    func handleMultiSwipeChanged(at location: CGPoint) {
        // 셀 간격(2pt) 영역에서 nil 반환 시 마지막 유효 위치 유지
        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        // ⚠️ 같은 photos 섹션 내에서만 유효 (배너/다른 섹션 무시)
        guard indexPath.section == swipeTargetSection,
              case .photos(let candidates) = sectionType(for: indexPath.section) else { return }

        let columnCount = Int(columns)
        let section = swipeTargetSection
        let currentItem = indexPath.item
        let currentRow = currentItem / columnCount
        let currentCol = currentItem % columnCount
        let deleteAction = swipeDeleteState.deleteAction

        // 사각형 범위 계산 — deleteAction에 따라 필터
        // deleteAction=true(제외): 미제외 셀만 / deleteAction=false(해제): 제외 셀만
        let newSelection = calculateRectangleSelection(
            anchorRow: swipeDeleteState.anchorRow,
            anchorCol: swipeDeleteState.anchorCol,
            currentRow: currentRow,
            currentCol: currentCol,
            columnCount: columnCount,
            totalItemsInSection: candidates.count
        ).filter { item in
            guard item < candidates.count else { return false }
            let isExcluded = excludedAssetIDs.contains(candidates[item].assetID)
            return deleteAction ? !isExcluded : isExcluded
        }

        let previousSelection = swipeDeleteState.selectedItems
        let prevCurtainItem = swipeDeleteState.curtainItem
        let selectionChanged = newSelection != previousSelection
        let curtainCellChanged = currentItem != prevCurtainItem

        let isSameRow = currentRow == swipeDeleteState.anchorRow
        let hasHorizontalDisplacement = isSameRow && currentCol != swipeDeleteState.anchorCol

        // --- 1) 범위에서 빠진 셀 → 원래 상태로 복귀 ---
        if selectionChanged {
            let removed = previousSelection.subtracting(newSelection)
            for item in removed {
                let ip = IndexPath(item: item, section: section)
                if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                    if deleteAction {
                        cell.clearDimmed()  // 제외 모드: 딤드 해제
                    } else {
                        // 해제 모드: 그린 딤드 복구 (선택에서 빠졌으므로 다시 제외 상태)
                        cell.prepareSwipeOverlay(style: .restore)
                        cell.setFullDimmed(isTrashed: false)
                    }
                }
            }
        }

        // --- 2) 이전 커튼 셀 → 대상 상태로 전환 (선택 범위 내이면) ---
        if curtainCellChanged, let prev = prevCurtainItem, newSelection.contains(prev) {
            let ip = IndexPath(item: prev, section: section)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                if deleteAction {
                    cell.prepareSwipeOverlay(style: .restore)
                    cell.setFullDimmed(isTrashed: false)  // 제외: 그린 딤드
                } else {
                    cell.clearDimmed()  // 해제: 원래 사진
                }
            }
        }

        // --- 3) 새로 추가된 셀 → 대상 상태 적용 (커튼 대상 제외) ---
        if selectionChanged {
            let added = newSelection.subtracting(previousSelection)
            for item in added {
                if hasHorizontalDisplacement && item == currentItem { continue }
                let ip = IndexPath(item: item, section: section)
                if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
                   !cell.isAnimating {
                    if deleteAction {
                        cell.prepareSwipeOverlay(style: .restore)
                        cell.setFullDimmed(isTrashed: false)  // 제외: 그린 딤드
                    } else {
                        cell.clearDimmed()  // 해제: 원래 사진
                    }
                }
            }
        }

        // --- 4) 현재 셀: 커튼 or 즉시 적용 ---
        if currentItem == swipeDeleteState.anchorItem && isSameRow {
            // 앵커 셀 복귀: 셀 프레임 기반 커튼
            let ip = IndexPath(item: currentItem, section: section)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
               let attrs = collectionView.layoutAttributesForItem(at: ip) {
                cell.prepareSwipeOverlay(style: .restore)  // 그린 보장 (커튼 진행 중)
                let cellFrame = attrs.frame
                let direction = swipeDeleteState.swipeDirection

                let progress: CGFloat
                switch direction {
                case .right:
                    progress = min(1.0, max(0, (location.x - cellFrame.minX) / cellFrame.width))
                case .left:
                    progress = min(1.0, max(0, (cellFrame.maxX - location.x) / cellFrame.width))
                }
                cell.setDimmedProgress(progress, direction: direction, isTrashed: !deleteAction)
            }
            swipeDeleteState.curtainItem = currentItem

        } else if hasHorizontalDisplacement && newSelection.contains(currentItem) {
            // 수평 변위 있는 비-앵커 셀: 커튼 효과
            let ip = IndexPath(item: currentItem, section: section)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
               let attrs = collectionView.layoutAttributesForItem(at: ip) {
                cell.prepareSwipeOverlay(style: .restore)  // 그린 보장 (커튼 진행 중)
                let cellFrame = attrs.frame
                let direction: PhotoCell.SwipeDirection =
                    currentCol > swipeDeleteState.anchorCol ? .right : .left

                let progress: CGFloat
                switch direction {
                case .right:
                    progress = min(1.0, max(0, (location.x - cellFrame.minX) / cellFrame.width))
                case .left:
                    progress = min(1.0, max(0, (cellFrame.maxX - location.x) / cellFrame.width))
                }
                cell.setDimmedProgress(progress, direction: direction, isTrashed: !deleteAction)
            }
            swipeDeleteState.curtainItem = currentItem

        } else {
            // 순수 상하 이동: 즉시 적용, 커튼 없음
            if selectionChanged || curtainCellChanged {
                let ip = IndexPath(item: currentItem, section: section)
                if let cell = collectionView.cellForItem(at: ip) as? PhotoCell,
                   newSelection.contains(currentItem),
                   !cell.isAnimating {
                    if deleteAction {
                        cell.prepareSwipeOverlay(style: .restore)
                        cell.setFullDimmed(isTrashed: false)  // 제외: 그린 딤드
                    } else {
                        cell.clearDimmed()  // 해제: 원래 사진
                    }
                }
            }
            swipeDeleteState.curtainItem = nil
        }

        // --- 5) 선택 상태 업데이트 ---
        swipeDeleteState.selectedItems = newSelection

        // --- 5-1) Reconciliation: stale animation이 딤드를 덮어쓴 셀 보정 ---
        for cell in collectionView.visibleCells {
            guard let photoCell = cell as? PhotoCell,
                  let ip = collectionView.indexPath(for: cell),
                  ip.section == section,
                  newSelection.contains(ip.item),
                  ip.item != swipeDeleteState.curtainItem,
                  !photoCell.isAnimating else { continue }

            if deleteAction && !photoCell.isDimmedActive {
                // 제외 모드: 딤드 안 칠해진 셀 보정
                photoCell.prepareSwipeOverlay(style: .restore)
                photoCell.setFullDimmed(isTrashed: false)
            } else if !deleteAction && photoCell.isDimmedActive {
                // 해제 모드: 딤드 남아있는 셀 보정
                photoCell.clearDimmed()
            }
        }

        // --- 6) 새 셀 추가 시 선택 햅틱 ---
        if selectionChanged {
            let added = newSelection.subtracting(previousSelection)
            if !added.isEmpty {
                let feedback = UISelectionFeedbackGenerator()
                feedback.selectionChanged()
            }
        }
    }

    // MARK: - 다중 모드 Ended 판정

    /// 다중 모드 종료 — 확정/취소 분기
    func confirmOrCancelMultiSwipe(_ gesture: UIPanGestureRecognizer) {
        // 속도 확정
        let velocity = gesture.velocity(in: collectionView)
        if abs(velocity.x) >= SwipeDeleteState.confirmVelocity {
            confirmMultiSwipeExclude()
            return
        }

        // 커튼 셀 없음 (순수 상하) → 모두 확정
        guard let curtainItem = swipeDeleteState.curtainItem else {
            confirmMultiSwipeExclude()
            return
        }

        // 커튼 셀 progress 기준 판정
        let section = swipeTargetSection
        let ip = IndexPath(item: curtainItem, section: section)
        if let attrs = collectionView.layoutAttributesForItem(at: ip) {
            let location = gesture.location(in: collectionView)
            let cellFrame = attrs.frame

            let direction: PhotoCell.SwipeDirection
            if curtainItem == swipeDeleteState.anchorItem {
                direction = swipeDeleteState.swipeDirection
            } else {
                let columnCount = Int(columns)
                let currentCol = curtainItem % columnCount
                direction = currentCol > swipeDeleteState.anchorCol ? .right : .left
            }

            let progress: CGFloat
            switch direction {
            case .right:
                progress = min(1.0, max(0, (location.x - cellFrame.minX) / cellFrame.width))
            case .left:
                progress = min(1.0, max(0, (cellFrame.maxX - location.x) / cellFrame.width))
            }

            if progress >= SwipeDeleteState.confirmRatio {
                confirmMultiSwipeExclude()
            } else {
                // 커튼 셀만 취소, 지나간 셀은 확정
                swipeDeleteState.selectedItems.remove(curtainItem)
                swipeDeleteState.curtainItem = nil

                if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                    let isUnexcludeMode = !swipeDeleteState.deleteAction
                    cell.cancelDimmedAnimation {
                        cell.isAnimating = false
                        // 해제 모드 취소: 그린 딤드 복구
                        if isUnexcludeMode {
                            cell.prepareSwipeOverlay(style: .restore)
                            cell.setFullDimmed(isTrashed: false)
                        }
                    }
                }

                if swipeDeleteState.selectedItems.isEmpty {
                    stopAutoScroll()
                    autoScrollGesture = nil
                    autoScrollHandler = nil
                    bottomView.isUserInteractionEnabled = true
                    swipeDeleteState.reset()
                } else {
                    confirmMultiSwipeExclude()
                }
            }
        } else {
            // 레이아웃 정보 없음 (화면 밖) → 확정
            confirmMultiSwipeExclude()
        }
    }

    // MARK: - 다중 모드 확정

    /// 선택된 모든 셀을 제외 또는 제외 해제
    func confirmMultiSwipeExclude() {
        // 1. 자동 스크롤 정지
        stopAutoScroll()
        autoScrollGesture = nil
        autoScrollHandler = nil

        let selectedItems = swipeDeleteState.selectedItems
        let deleteAction = swipeDeleteState.deleteAction
        let section = swipeTargetSection

        guard case .photos(let candidates) = sectionType(for: section) else {
            bottomView.isUserInteractionEnabled = true
            swipeDeleteState.reset()
            return
        }

        // 2. assetID 수집
        var assetIDs: [String] = []
        for item in selectedItems.sorted() {
            guard item < candidates.count else { continue }
            assetIDs.append(candidates[item].assetID)
        }

        // 3. 보이는 셀 confirm 애니메이션
        let toTrashed = deleteAction  // 제외=true(딤드 유지), 해제=false(딤드 제거)
        for item in selectedItems {
            let ip = IndexPath(item: item, section: section)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                cell.isAnimating = true
                if deleteAction {
                    cell.prepareSwipeOverlay(style: .restore)  // 제외: 그린 보장
                    if item == swipeDeleteState.curtainItem {
                        cell.setFullDimmed(isTrashed: false)
                    }
                }
                cell.confirmDimmedAnimation(toTrashed: toTrashed) {
                    cell.isAnimating = false
                }
            }
        }

        // 4. excludedAssetIDs 갱신
        if deleteAction {
            // 제외: 추가 (이미 제외된 건 필터)
            let newIDs = assetIDs.filter { !excludedAssetIDs.contains($0) }
            applySwipeExclusion(assetIDs: newIDs)
        } else {
            // 해제: 제거
            for id in assetIDs { excludedAssetIDs.remove(id) }
            updateBottomView()
        }

        // 5. 상태 초기화
        swipeDeleteState.reset()

        // 6. 하단 버튼 복원
        bottomView.isUserInteractionEnabled = true

        // 7. 확정 햅틱
        HapticFeedback.light()
    }

    // MARK: - 다중 모드 취소

    /// 모든 선택 셀의 딤드를 원래 상태로 복귀
    func cancelMultiSwipeDelete() {
        // 1. 자동 스크롤 정지
        stopAutoScroll()
        autoScrollGesture = nil
        autoScrollHandler = nil

        // 2. 보이는 셀 cancel 애니메이션
        let section = swipeTargetSection
        let wasUnexcludeMode = !swipeDeleteState.deleteAction  // 해제 모드였는지
        for item in swipeDeleteState.selectedItems {
            let ip = IndexPath(item: item, section: section)
            if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                cell.cancelDimmedAnimation { [weak self] in
                    cell.isAnimating = false
                    // 해제 모드 취소: cancelDimmedAnimation이 딤드를 지우므로 그린 딤드 복구
                    if wasUnexcludeMode {
                        cell.prepareSwipeOverlay(style: .restore)
                        cell.setFullDimmed(isTrashed: false)
                    }
                }
            }
        }

        // 3. 하단 버튼 복원
        bottomView.isUserInteractionEnabled = true

        // 4. 상태 초기화
        swipeDeleteState.reset()
    }

    // MARK: - 자동 스크롤

    /// 화면 가장자리 거리에 따라 자동 스크롤 제어
    /// - Parameter locationInView: view 좌표계 (핫스팟 계산용)
    func handleAutoScroll(at locationInView: CGPoint) {
        let safeTop = view.safeAreaInsets.top
        let safeBottom = view.bounds.height - view.safeAreaInsets.bottom

        let topEdgeStart = safeTop + Self.autoScrollEdgeHeight
        let bottomEdgeStart = safeBottom - Self.autoScrollEdgeHeight

        if locationInView.y < topEdgeStart {
            // 상단 핫스팟: 위로 스크롤
            let distanceIntoEdge: CGFloat
            if locationInView.y >= safeTop {
                distanceIntoEdge = topEdgeStart - locationInView.y
            } else {
                distanceIntoEdge = Self.autoScrollEdgeHeight
            }
            let speed = calculateScrollSpeed(distance: distanceIntoEdge)
            updateAutoScroll(speed: -speed)

        } else if locationInView.y > bottomEdgeStart {
            // 하단 핫스팟: 아래로 스크롤
            let distanceIntoEdge: CGFloat
            if locationInView.y <= safeBottom {
                distanceIntoEdge = locationInView.y - bottomEdgeStart
            } else {
                distanceIntoEdge = Self.autoScrollEdgeHeight
            }
            let speed = calculateScrollSpeed(distance: distanceIntoEdge)
            updateAutoScroll(speed: speed)

        } else {
            // 중앙: 스크롤 중지
            stopAutoScroll()
        }
    }

    /// 거리 기반 스크롤 속도 (제곱 easing)
    private func calculateScrollSpeed(distance: CGFloat) -> CGFloat {
        let fraction = min(distance / Self.autoScrollEdgeHeight, 1.0)
        let easedFraction = pow(fraction, 2.0)
        return Self.autoScrollMinSpeed + (Self.autoScrollMaxSpeed - Self.autoScrollMinSpeed) * easedFraction
    }

    /// 자동 스크롤 속도 업데이트 (타이머 없으면 시작)
    private func updateAutoScroll(speed: CGFloat) {
        currentAutoScrollSpeed = speed
        if autoScrollTimer == nil { startAutoScrollTimer() }
    }

    /// 자동 스크롤 타이머 시작 (60Hz)
    private func startAutoScrollTimer() {
        guard autoScrollTimer == nil else { return }

        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let scrollAmount = self.currentAutoScrollSpeed / 60.0
            var newOffset = self.collectionView.contentOffset
            newOffset.y += scrollAmount

            // 스크롤 범위 제한
            let minY = -self.collectionView.adjustedContentInset.top
            let maxY = self.collectionView.contentSize.height
                - self.collectionView.bounds.height
                + self.collectionView.adjustedContentInset.bottom
            newOffset.y = max(minY, min(maxY, newOffset.y))

            self.collectionView.setContentOffset(newOffset, animated: false)

            // 콜백으로 범위 갱신
            if let gesture = self.autoScrollGesture {
                let location = gesture.location(in: self.collectionView)
                self.autoScrollHandler?(location)
            }
        }
    }

    /// 자동 스크롤 중지
    func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

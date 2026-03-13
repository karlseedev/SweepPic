//
//  GridViewController+CoachMark.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-14.
//
//  코치마크 A: 그리드 스와이프 삭제 안내
//  - 사용자가 약 1화면 높이 이상 스크롤하면 즉시 표시 (스크롤 중)
//  - 화면 중앙 셀을 하이라이트하여 스와이프 시연
//  - 1회만 표시 (UserDefaults)
//
//  트리거: scrollViewDidScroll → trackCoachMarkScroll → 누적 >= 1화면 → 즉시 표시
//  dismiss: 확인 버튼, 스와이프 시작, 새 스크롤 시작, 화면 이탈

import UIKit
import ObjectiveC
import AppCore
import OSLog

// MARK: - Associated Keys

/// extension stored property를 위한 키
private enum CoachMarkAssociatedKeys {
    static var scrollAccumulated: UInt8 = 0
    static var lastTrackedOffset: UInt8 = 0
}

// MARK: - Coach Mark A: Grid Swipe Delete

extension GridViewController {

    /// 코치마크 트리거용 스크롤 누적 거리 (절대값 합산)
    private var coachMarkScrollAccumulated: CGFloat {
        get {
            (objc_getAssociatedObject(self, &CoachMarkAssociatedKeys.scrollAccumulated) as? CGFloat) ?? 0
        }
        set {
            objc_setAssociatedObject(
                self,
                &CoachMarkAssociatedKeys.scrollAccumulated,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// 마지막으로 추적한 contentOffset.y (프레임 간 delta 계산용)
    private var coachMarkLastTrackedOffset: CGFloat {
        get {
            (objc_getAssociatedObject(self, &CoachMarkAssociatedKeys.lastTrackedOffset) as? CGFloat) ?? 0
        }
        set {
            objc_setAssociatedObject(
                self,
                &CoachMarkAssociatedKeys.lastTrackedOffset,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Scroll Tracking

    /// 스크롤 시작 시 추적 기준점 설정 (scrollViewWillBeginDragging에서 호출)
    func recordCoachMarkScrollStart(offset: CGFloat) {
        coachMarkLastTrackedOffset = offset
    }

    /// scrollViewDidScroll에서 호출 — 누적 거리 실시간 추적, threshold 도달 시 스크롤 정지 후 표시
    func trackCoachMarkScroll(currentOffset: CGFloat) {
        guard !CoachMarkType.gridSwipeDelete.hasBeenShown else { return }

        // 현재 표시 중이거나 표시 대기 중이면 스킵
        guard !CoachMarkManager.shared.isShowing else {
            Logger.coachMark.debug("스크롤 추적 스킵: 다른 코치마크 표시 중")
            return
        }

        // 사용자 스크롤만 추적 (프로그래밍 스크롤 제외)
        guard isScrolling else { return }

        // 초기 표시 완료 전이면 스킵
        guard hasFinishedInitialDisplay else { return }

        // 프레임 간 이동 거리 누적 (방향 무관)
        let delta = abs(currentOffset - coachMarkLastTrackedOffset)
        coachMarkLastTrackedOffset = currentOffset
        coachMarkScrollAccumulated += delta

        // 70pt 이상 스크롤했으면 → 스크롤 정지 → 코치마크 표시
        let threshold: CGFloat = 70
        guard coachMarkScrollAccumulated >= threshold else { return }

        Logger.coachMark.debug("threshold 도달 — 누적 \(Int(self.coachMarkScrollAccumulated))pt / \(Int(threshold))pt")

        // 누적 거리 리셋 (재트리거 방지 + 다음 표시를 위한 초기화)
        coachMarkScrollAccumulated = 0

        // 스크롤 즉시 정지 (상태 플래그, 타이머 정리 포함)
        stopScrollForCoachMark()

        // 스크롤 정지 후 잠시 안정화 → 셀 위치 정확히 잡은 뒤 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.showGridSwipeDeleteCoachMark()
            // 코치마크 표시 후 스크롤 복원 (오버레이 hitTest가 터치 차단)
            self?.restoreScrollAfterCoachMark()
        }
    }

    // MARK: - Show

    /// 코치마크 A 즉시 표시 (재생 기능에서도 호출)
    func showGridSwipeDeleteCoachMark() {
        guard !CoachMarkType.gridSwipeDelete.hasBeenShown else {
            Logger.coachMark.debug("표시 스킵: 이미 표시됨")
            return
        }
        guard !CoachMarkManager.shared.isShowing else {
            Logger.coachMark.debug("표시 스킵: 다른 코치마크 표시 중")
            return
        }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard dataSourceDriver.count > 0 else { return }

        // 화면이 활성 상태인지 확인
        guard view.window != nil else { return }

        // Step 1: 화면 중앙 셀을 하이라이트
        guard let (cell, _) = findCenterCell() else { return }

        // Step 2 데이터 수집 (화면 중앙 근처 9셀)
        let multiData = findCellForCoachMarkA()

        // 셀 스냅샷 캡처
        guard let snapshot = cell.snapshotView(afterScreenUpdates: false) else { return }

        // 셀 프레임을 윈도우 좌표로 변환
        guard let window = view.window,
              let cellFrame = cell.superview?.convert(cell.frame, to: window) else { return }

        // 코치마크 표시
        CoachMarkOverlayView.show(
            type: .gridSwipeDelete,
            highlightFrame: cellFrame,
            snapshot: snapshot,
            in: window
        )

        // Step 2 데이터 설정 (show() 후 overlay에 프로퍼티 주입 — 페이드인 중 적용)
        guard let overlay = CoachMarkManager.shared.currentOverlay else { return }
        let multiSnapshots = captureMultiCellSnapshots(indexPaths: multiData.all9IndexPaths)
        overlay.aCurrentStep = 1
        overlay.aMultiCellFrames = multiData.row3Frames
        overlay.aAll9CellFrames = multiData.all9Frames
        overlay.aMultiSnapshots = multiSnapshots
        Logger.coachMark.debug("A Step 2 데이터 설정 완료 — 9셀 스냅샷 수집")

        // A dismiss 후 A-1 타이머 시작 (viewDidAppear 없이도 트리거)
        // 0.1초 지연: overlay removeFromSuperview 완료 대기 (weak ref → nil → isShowing = false)
        CoachMarkManager.shared.currentOverlay?.onDismiss = { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self?.startCoachMarkA1TimerIfNeeded()
            }
        }
    }

    // MARK: - Step 2 Data Collection

    /// Step 2 멀티스와이프 데이터 수집 결과
    struct CoachMarkAMultiData {
        let anchorCell: PhotoCell
        let anchorIndexPath: IndexPath
        let row3Frames: [CGRect]       // 앵커행 3셀 윈도우 프레임
        let all9Frames: [CGRect]       // 전체 9셀 윈도우 프레임
        let all9IndexPaths: [IndexPath] // 전체 9셀 IndexPath
    }

    /// 중앙 1행 아래 셀을 앵커로 선택하고, Step 2에 필요한 9셀 데이터를 수집
    /// - Returns: 멀티 데이터 (화면 중앙 근처 9셀이므로 항상 성공)
    private func findCellForCoachMarkA() -> CoachMarkAMultiData {
        let columns = currentGridColumnCount.rawValue
        let window = view.window!

        // 1. 화면 중앙에서 가장 가까운 셀 찾기
        let (_, centerIndexPath) = findCenterCell()!

        // 2. 중앙 셀의 행 계산 (padding 셀 포함)
        let centerRow = centerIndexPath.item / columns

        // 3. 앵커를 1행 아래로 선택 (위로 2행 확장 공간 확보)
        let anchorRow = centerRow + 1

        // 4. 9셀 IndexPath 수집 (Row 0 = anchorRow-2, Row 1 = anchorRow-1, Row 2 = anchorRow)
        var all9IndexPaths: [IndexPath] = []
        for rowOffset in stride(from: -2, through: 0, by: 1) {
            let rowFirstItem = (anchorRow + rowOffset) * columns
            for col in 0..<min(3, columns) {
                let item = rowFirstItem + col
                all9IndexPaths.append(IndexPath(item: item, section: 0))
            }
        }

        // 5. 9셀 프레임 수집 (윈도우 좌표)
        var all9Frames: [CGRect] = []
        for ip in all9IndexPaths {
            let attrs = collectionView.layoutAttributesForItem(at: ip)!
            let frameInWindow = collectionView.convert(attrs.frame, to: window)
            all9Frames.append(frameInWindow)
        }

        // 6. 앵커행 3셀 프레임 (all9Frames의 마지막 3개 = Row 2)
        let row3Frames = Array(all9Frames[6...8])

        // 7. 앵커 셀 찾기 (Row 2의 첫 번째 셀)
        let anchorIP = all9IndexPaths[6]
        let anchorCell = collectionView.cellForItem(at: anchorIP) as! PhotoCell

        return CoachMarkAMultiData(
            anchorCell: anchorCell,
            anchorIndexPath: anchorIP,
            row3Frames: row3Frames,
            all9Frames: all9Frames,
            all9IndexPaths: all9IndexPaths
        )
    }

    /// 9셀 스냅샷 캡처
    /// - Parameter indexPaths: 9개의 IndexPath
    /// - Returns: 9개의 UIView 스냅샷
    private func captureMultiCellSnapshots(indexPaths: [IndexPath]) -> [UIView] {
        return indexPaths.map { ip in
            if let cell = collectionView.cellForItem(at: ip),
               let snapshot = cell.snapshotView(afterScreenUpdates: false) {
                return snapshot
            } else {
                // 안전장치: 스냅샷 실패 시 회색 대체
                let fallback = UIView()
                fallback.backgroundColor = .darkGray
                return fallback
            }
        }
    }

    /// 화면 중앙에 가장 가까운 셀 찾기 (재생 기능에서도 호출)
    /// - Returns: (셀, indexPath) 또는 nil
    func findCenterCell() -> (PhotoCell, IndexPath)? {
        let centerPoint = CGPoint(
            x: collectionView.bounds.midX,
            y: collectionView.bounds.midY
        )

        // 중앙 좌표에서 가장 가까운 셀 탐색
        var closestCell: PhotoCell?
        var closestIndexPath: IndexPath?
        var closestDistance: CGFloat = .greatestFiniteMagnitude

        for indexPath in collectionView.indexPathsForVisibleItems {
            // 패딩 셀 제외
            guard indexPath.item >= paddingCellCount else { continue }
            guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else { continue }

            let cellCenter = cell.center
            let distance = hypot(cellCenter.x - centerPoint.x, cellCenter.y - centerPoint.y)
            if distance < closestDistance {
                closestDistance = distance
                closestCell = cell
                closestIndexPath = indexPath
            }
        }

        guard let cell = closestCell, let indexPath = closestIndexPath else { return nil }
        return (cell, indexPath)
    }
}

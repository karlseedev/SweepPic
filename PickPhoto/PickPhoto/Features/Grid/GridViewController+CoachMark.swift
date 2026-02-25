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
        // 이미 표시된 적 있으면 스킵
        guard !CoachMarkType.gridSwipeDelete.hasBeenShown else { return }

        // 현재 표시 중이거나 표시 대기 중이면 스킵
        guard !CoachMarkManager.shared.isShowing else {
            Log.print("[CoachMarkA] 스크롤 추적 스킵: 다른 코치마크 표시 중")
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

        // 1화면 높이 이상 스크롤했으면 → 스크롤 정지 → 코치마크 표시
        let threshold = collectionView.bounds.height
        guard threshold > 0, coachMarkScrollAccumulated >= threshold else { return }

        Log.print("[CoachMarkA] threshold 도달 — 누적 \(Int(coachMarkScrollAccumulated))pt / \(Int(threshold))pt")

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
            Log.print("[CoachMarkA] 표시 스킵: 이미 표시됨")
            return
        }
        guard !CoachMarkManager.shared.isShowing else {
            Log.print("[CoachMarkA] 표시 스킵: 다른 코치마크 표시 중")
            return
        }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard dataSourceDriver.count > 0 else { return }

        // 화면이 활성 상태인지 확인
        guard view.window != nil else { return }

        // 화면 중앙 셀 찾기
        guard let (cell, _) = findCenterCell() else { return }

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

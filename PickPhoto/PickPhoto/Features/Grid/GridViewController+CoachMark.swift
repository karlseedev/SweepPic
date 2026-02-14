//
//  GridViewController+CoachMark.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-14.
//
//  코치마크 A: 그리드 스와이프 삭제 안내
//  - finishInitialDisplay 완료 후 2초 뒤 표시
//  - 화면 중앙 셀을 하이라이트하여 스와이프 시연
//  - 1회만 표시 (UserDefaults)
//
//  트리거: GridScroll.finishInitialDisplay → scheduleCoachMarkIfNeeded()
//  dismiss: 확인 버튼, 스와이프 시작, 스크롤 시작, 화면 이탈

import UIKit
import ObjectiveC

// MARK: - Associated Keys

/// extension stored property를 위한 키
private enum CoachMarkAssociatedKeys {
    static var hasScheduledCoachMark: UInt8 = 0
}

// MARK: - Coach Mark A: Grid Swipe Delete

extension GridViewController {

    /// 코치마크 스케줄 여부 (중복 스케줄 방지)
    /// extension에서 stored property 불가 → objc_getAssociatedObject 패턴
    private var hasScheduledCoachMark: Bool {
        get {
            (objc_getAssociatedObject(self, &CoachMarkAssociatedKeys.hasScheduledCoachMark) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &CoachMarkAssociatedKeys.hasScheduledCoachMark,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    /// 코치마크 스케줄 (조건 충족 시 2초 후 표시)
    /// GridScroll.finishInitialDisplay() 끝에서 호출됨
    func scheduleCoachMarkIfNeeded() {
        // 중복 스케줄 방지
        guard !hasScheduledCoachMark else { return }

        // 이미 표시된 적 있으면 스킵
        guard !CoachMarkType.gridSwipeDelete.hasBeenShown else { return }

        // 다른 코치마크가 표시 중이면 스킵
        guard !CoachMarkManager.shared.isShowing else { return }

        // 초기 표시 완료 확인
        guard hasFinishedInitialDisplay else { return }

        // 스크롤 중이면 스킵
        guard !isScrolling else { return }

        // VoiceOver 활성화 시 스킵
        guard !UIAccessibility.isVoiceOverRunning else { return }

        // 빈 그리드 방어
        guard dataSourceDriver.count > 0 else { return }

        hasScheduledCoachMark = true

        // 2초 후 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.showGridSwipeDeleteCoachMark()
        }
    }

    /// 코치마크 A 표시
    private func showGridSwipeDeleteCoachMark() {
        // 2초 사이 조건 변경 가능 → 재확인
        guard !CoachMarkType.gridSwipeDelete.hasBeenShown else { return }
        guard !CoachMarkManager.shared.isShowing else { return }
        guard !isScrolling else {
            // 스크롤 중이면 다음 기회에 재스케줄 가능하도록 리셋
            hasScheduledCoachMark = false
            return
        }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard dataSourceDriver.count > 0 else { return }

        // 화면이 여전히 활성 상태인지 확인
        guard view.window != nil else {
            hasScheduledCoachMark = false
            return
        }

        // 화면 중앙 셀 찾기
        guard let (cell, _) = findCenterCell() else {
            hasScheduledCoachMark = false
            return
        }

        // 셀 스냅샷 캡처
        guard let snapshot = cell.snapshotView(afterScreenUpdates: false) else {
            hasScheduledCoachMark = false
            return
        }

        // 셀 프레임을 윈도우 좌표로 변환
        guard let window = view.window,
              let cellFrame = cell.superview?.convert(cell.frame, to: window) else {
            hasScheduledCoachMark = false
            return
        }

        // 코치마크 표시
        CoachMarkOverlayView.show(
            type: .gridSwipeDelete,
            highlightFrame: cellFrame,
            snapshot: snapshot,
            in: window
        )
    }

    /// 화면 중앙에 가장 가까운 셀 찾기
    /// - Returns: (셀, indexPath) 또는 nil
    private func findCenterCell() -> (PhotoCell, IndexPath)? {
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

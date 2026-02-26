//
//  GridViewController+CoachMarkA1.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-25.
//
//  코치마크 A-1: 스와이프 삭제 실습 유도 — 트리거 로직
//
//  트리거 조건:
//    A 완료 (gridSwipeDelete.hasBeenShown) + E-1 미완료 (firstDeleteGuide 미표시)
//    + 다른 코치마크 미표시 + 화면 활성 상태
//    → viewDidAppear에서 3초 Timer → showCoachMarkA1()
//
//  dismiss:
//    스와이프 삭제 성공 → BaseGridViewController.confirmSwipeDelete에서 감지
//    화면 이탈 → viewWillDisappear에서 cancelTimer + 직접 dismiss
//

import UIKit
import ObjectiveC
import AppCore

// MARK: - Associated Object Keys (A-1 트리거 전용)

private var coachMarkA1TimerKey: UInt8 = 0

// MARK: - Coach Mark A-1: Trigger Logic

extension GridViewController {

    // MARK: - Stored Properties (Associated Objects)

    /// A-1 트리거 타이머 (viewDidAppear → 5초 후 표시)
    var coachMarkA1Timer: Timer? {
        get { objc_getAssociatedObject(self, &coachMarkA1TimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &coachMarkA1TimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Trigger

    /// A-1 트리거 타이머 시작 (viewDidAppear에서 호출)
    /// A 완료 + E-1 미완료일 때만 3초 후 A-1 표시
    func startCoachMarkA1TimerIfNeeded() {
        // A 미완료 → A-1 불필요
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else {
            return
        }
        // E-1 이미 완료 → 스와이프 삭제 경험 있음 → A-1 불필요
        guard !CoachMarkType.firstDeleteGuide.hasBeenShown else {
            return
        }
        // 다른 코치마크 표시 중
        guard !CoachMarkManager.shared.isShowing else {
            Log.print("[CoachMarkA1] 타이머 스킵: 다른 코치마크 표시 중")
            return
        }
        // 화면 비활성
        guard view.window != nil else {
            return
        }

        // 기존 타이머 무효화 (화면 복귀 시 리셋)
        coachMarkA1Timer?.invalidate()

        Log.print("[CoachMarkA1] 타이머 시작 (3초)")

        // 3초 후 A-1 표시
        coachMarkA1Timer = Timer.scheduledTimer(
            withTimeInterval: 3.0, repeats: false
        ) { [weak self] _ in
            self?.showCoachMarkA1()
        }
    }

    // MARK: - Show

    /// A-1 오버레이 표시
    private func showCoachMarkA1() {
        // 재가드 (5초 사이에 상태 변경 가능)
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else {
            Log.print("[CoachMarkA1] 표시 스킵: A 미완료")
            return
        }
        guard !CoachMarkType.firstDeleteGuide.hasBeenShown else {
            Log.print("[CoachMarkA1] 표시 스킵: E-1 이미 완료")
            return
        }
        guard !CoachMarkManager.shared.isShowing else {
            Log.print("[CoachMarkA1] 표시 스킵: 다른 코치마크 표시 중")
            return
        }
        guard !UIAccessibility.isVoiceOverRunning else {
            Log.print("[CoachMarkA1] 표시 스킵: VoiceOver 활성")
            return
        }
        guard view.window != nil else {
            Log.print("[CoachMarkA1] 표시 스킵: view.window nil")
            return
        }
        guard dataSourceDriver.count > 0 else {
            Log.print("[CoachMarkA1] 표시 스킵: 사진 0장")
            return
        }

        // 화면 중앙에서 non-trashed 셀 찾기
        // (trashed 셀은 스와이프 시 '복원'이므로 "삭제해 보세요" 텍스트와 불일치)
        guard let (cell, _) = findCenterCellForA1() else {
            Log.print("[CoachMarkA1] 표시 스킵: 적절한 셀 없음")
            return
        }
        guard let window = view.window,
              let cellFrame = cell.superview?.convert(cell.frame, to: window) else {
            return
        }

        Log.print("[CoachMarkA1] 표시 — cellFrame=\(cellFrame)")

        // A-1 오버레이 표시 (스냅샷 없음, 확인 버튼 없음)
        CoachMarkOverlayView.showA1(
            highlightFrame: cellFrame,
            in: window
        )
    }

    // MARK: - Cancel

    /// A-1 타이머 취소 (viewWillDisappear에서 호출)
    func cancelCoachMarkA1Timer() {
        coachMarkA1Timer?.invalidate()
        coachMarkA1Timer = nil
    }

    // MARK: - Cell Finding

    /// A-1용 셀 탐색 — non-trashed 셀 우선, 없으면 기존 findCenterCell() 폴백
    /// (trashed 셀은 스와이프 시 '복원'이므로 "삭제해 보세요" 텍스트와 불일치)
    private func findCenterCellForA1() -> (PhotoCell, IndexPath)? {
        let centerPoint = CGPoint(
            x: collectionView.bounds.midX,
            y: collectionView.bounds.midY
        )

        var bestCell: PhotoCell?
        var bestIndexPath: IndexPath?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        for indexPath in collectionView.indexPathsForVisibleItems {
            // 패딩 셀 제외
            guard indexPath.item >= paddingCellCount else { continue }
            guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else { continue }
            // non-trashed 셀만
            guard !cell.isTrashed else { continue }

            let distance = hypot(cell.center.x - centerPoint.x, cell.center.y - centerPoint.y)
            if distance < bestDistance {
                bestDistance = distance
                bestCell = cell
                bestIndexPath = indexPath
            }
        }

        // non-trashed 셀 발견
        if let cell = bestCell, let ip = bestIndexPath {
            return (cell, ip)
        }
        // 모두 trashed면 기존 findCenterCell() 폴백
        return findCenterCell()
    }
}

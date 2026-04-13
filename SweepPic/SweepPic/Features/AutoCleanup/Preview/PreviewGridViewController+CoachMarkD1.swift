//
//  PreviewGridViewController+CoachMarkD1.swift
//  SweepPic
//
//  Created by Claude Code on 2026-04-07.
//
//  코치마크 D-1: 자동정리 미리보기 안내 — 트리거 + 프레임 획득
//
//  트리거: viewDidAppear에서 최초 1회 (0.5초 지연)
//  프레임 획득: 헤더 타이틀, secondaryStack, 중앙 셀, primaryButton
//

import UIKit
import OSLog
import AppCore

// MARK: - Coach Mark D-1: Trigger & Frame Helpers

extension PreviewGridViewController {

    // MARK: - Trigger

    /// D-1 코치마크 표시 조건 확인 + 0.5초 지연 후 표시
    /// viewDidAppear에서 호출
    func showCoachMarkD1IfNeeded() {
        // 이미 표시됨
        guard !CoachMarkType.autoCleanupPreview.hasBeenShown else { return }
        // VoiceOver 활성
        guard !UIAccessibility.isVoiceOverRunning else { return }
        // 다른 코치마크 표시 중
        guard !CoachMarkManager.shared.isShowing else { return }
        // 화면 활성
        guard view.window != nil else { return }
        // 사진이 있어야 함
        guard previewResult.lightCount > 0 else { return }

        // 레이아웃 안정화 + push 애니메이션 완료 보장 (0.5초)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }
            // 지연 후 재검증
            guard !CoachMarkType.autoCleanupPreview.hasBeenShown,
                  !CoachMarkManager.shared.isShowing,
                  self.view.window != nil else { return }
            self.showCoachMarkD1()
        }
    }

    // MARK: - Show

    /// 프레임 수집 + D-1 오버레이 표시
    private func showCoachMarkD1() {
        guard let window = view.window else { return }

        // Step 1: 헤더 타이틀 프레임
        guard let step1Frame = headerTitleFrameForCoachMark else {
            Logger.coachMark.debug("D-1: step1Frame 획득 실패 — 스킵")
            return
        }

        // Step 2: secondaryStack 프레임 (nil 가능 — 임시 버튼 대체)
        let step2Frame = bottomView.secondaryStackFrameInWindow()

        // Step 3: 중앙 셀 프레임 + 스냅샷
        guard let cellResult = findCenterCellForD1(in: window) else {
            Logger.coachMark.debug("D-1: step3 셀 획득 실패 — 스킵")
            return
        }

        // Step 4: primaryButton 프레임
        guard let step4Frame = bottomView.primaryButtonFrameInWindow() else {
            Logger.coachMark.debug("D-1: step4Frame 획득 실패 — 스킵")
            return
        }

        // 하단 뷰 상단 Y (임시 버튼 배치용)
        let bottomViewTopY = bottomView.convert(CGPoint.zero, to: window).y

        Logger.coachMark.debug("D-1: 표시 시작 — step1=\(NSCoder.string(for: step1Frame)), step3=\(NSCoder.string(for: cellResult.frame))")

        CoachMarkOverlayView.showAutoCleanupPreview(
            step1Frame: step1Frame,
            step2Frame: step2Frame,
            step3CellFrame: cellResult.frame,
            step3Snapshot: cellResult.snapshot,
            step4Frame: step4Frame,
            bottomViewTopY: bottomViewTopY,
            in: window
        )
    }

    // MARK: - Center Cell Finder

    /// D-1 Step 3용: 중앙 부근 셀 프레임 + 스냅샷 획득
    /// - 1장: item 0
    /// - 2장: item 0
    /// - 3장: item 1 (가운데)
    /// - 4장+: 가시 영역 내 중앙 Y 기준 가장 가까운 PhotoCell
    private func findCenterCellForD1(in window: UIWindow) -> (frame: CGRect, snapshot: UIView)? {
        // 모든 단계에서 section 1이 light 사진 (section 0은 매우 낮은 품질 배너)
        let photosSection = 1

        guard case .photos(let candidates) = sectionType(for: photosSection) else { return nil }
        let count = candidates.count
        guard count > 0 else { return nil }

        // 셀 인덱스 결정
        let targetItem: Int
        switch count {
        case 1: targetItem = 0
        case 2: targetItem = 0
        case 3: targetItem = 1
        default:
            // 가시 영역(헤더/하단 제외) 내 중앙 Y 기준 가장 가까운 셀
            let visibleBounds = collectionView.bounds.inset(by: collectionView.adjustedContentInset)
            let centerY = visibleBounds.midY + collectionView.contentOffset.y
            var closest: (item: Int, dist: CGFloat) = (0, .greatestFiniteMagnitude)
            for item in 0..<count {
                let ip = IndexPath(item: item, section: photosSection)
                guard let attrs = collectionView.layoutAttributesForItem(at: ip) else { continue }
                // 가시 영역 내의 셀만 후보
                let cellMidY = attrs.frame.midY
                if cellMidY < collectionView.contentOffset.y + collectionView.adjustedContentInset.top { continue }
                if cellMidY > collectionView.contentOffset.y + collectionView.bounds.height - collectionView.adjustedContentInset.bottom { continue }
                let dist = abs(cellMidY - centerY)
                if dist < closest.dist { closest = (item, dist) }
            }
            targetItem = closest.item
        }

        let ip = IndexPath(item: targetItem, section: photosSection)

        // 셀이 화면 내에 보이도록 스크롤
        if collectionView.cellForItem(at: ip) == nil {
            collectionView.scrollToItem(at: ip, at: .centeredVertically, animated: false)
            collectionView.layoutIfNeeded()
        }

        // 셀 프레임/스냅샷 획득
        guard let cell = collectionView.cellForItem(at: ip),
              let snapshot = cell.snapshotView(afterScreenUpdates: false) else {
            Logger.coachMark.debug("D-1: cellForItem 실패 — item=\(targetItem)")
            return nil
        }

        let frame = collectionView.convert(cell.frame, to: window)
        return (frame, snapshot)
    }
}

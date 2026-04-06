//
//  GridViewController+CoachMarkReplay.swift
//  SweepPic
//
//  Created by Claude Code on 2026-02-25.
//
//  코치마크 다시 보기 (온보딩 7번)
//  - 전체메뉴 "설명 다시 보기" 서브메뉴에서 호출
//  - 6개 코치마크를 즉시 재생
//  - 공통: 상태 정리 → 플래그 리셋 → 재생 → 실패 시 플래그 복원
//

import UIKit
import Photos
import AppCore
import OSLog

// MARK: - Coach Mark Replay

extension GridViewController {

    // MARK: - Common: State Cleanup

    /// 재생 전 공통 상태 정리
    /// - C-2 대기 상태, E 시퀀스 상태, 현재 표시 중인 코치마크를 모두 해제
    private func cleanupBeforeReplay() {
        // C-2 대기 상태 해제
        CoachMarkManager.shared.resetC2State()
        // E 시퀀스 활성 상태 해제
        CoachMarkManager.shared.isDeleteGuideSequenceActive = false
        // 현재 표시 중인 코치마크 dismiss
        if CoachMarkManager.shared.isShowing {
            CoachMarkManager.shared.currentOverlay?.dismiss()
        }
    }

    // MARK: - A: Grid Swipe Delete Replay

    /// A 코치마크 즉시 재생
    func replayCoachMarkA() {
        Logger.coachMark.debug("A: 목록에서 밀어서 삭제 재생 시작")

        // 사진 0장 체크
        guard dataSourceDriver.count > 0 else {
            if let window = view.window {
                ToastView.show("사진이 없습니다", in: window)
            }
            return
        }

        cleanupBeforeReplay()

        // 플래그 리셋 → 재생
        CoachMarkType.gridSwipeDelete.resetShown()
        showGridSwipeDeleteCoachMark()

        // 표시 실패 시 플래그 복원
        if !CoachMarkManager.shared.isShowing {
            Logger.coachMark.error("A: 표시 실패 — 플래그 복원")
            CoachMarkType.gridSwipeDelete.markAsShown()
        }
    }

    // MARK: - B: Viewer Swipe Delete Replay

    /// B 코치마크 즉시 재생
    /// 화면 중앙에서 가까운 이미지(비디오 제외) 셀을 찾아 뷰어로 이동
    /// viewDidAppear에서 B 가드 통과 → 자동 표시
    func replayCoachMarkB() {
        Logger.coachMark.debug("B: 뷰어에서 밀어서 삭제 재생 시작")

        guard dataSourceDriver.count > 0 else {
            if let window = view.window {
                ToastView.show("사진이 없습니다", in: window)
            }
            return
        }

        // 중앙에서 가까운 이미지 셀 탐색 (비디오 제외)
        guard let indexPath = findNearestImageCell() else {
            if let window = view.window {
                ToastView.show("표시할 이미지가 없습니다", in: window)
            }
            return
        }

        cleanupBeforeReplay()

        // 플래그 리셋
        CoachMarkType.viewerSwipeDelete.resetShown()

        // 뷰어로 이동 (기존 didSelectItemAt 경로 사용 → iOS 버전별 자동 분기)
        collectionView(collectionView, didSelectItemAt: indexPath)
    }

    /// 중앙에서 가까운 이미지(비디오 제외) 셀의 indexPath 반환
    private func findNearestImageCell() -> IndexPath? {
        let centerPoint = CGPoint(
            x: collectionView.bounds.midX,
            y: collectionView.bounds.midY
        )

        // 거리순 정렬
        let sortedItems = collectionView.indexPathsForVisibleItems
            .filter { $0.item >= paddingCellCount }
            .sorted { a, b in
                guard let cellA = collectionView.cellForItem(at: a),
                      let cellB = collectionView.cellForItem(at: b) else { return false }
                let distA = hypot(cellA.center.x - centerPoint.x, cellA.center.y - centerPoint.y)
                let distB = hypot(cellB.center.x - centerPoint.x, cellB.center.y - centerPoint.y)
                return distA < distB
            }

        // 중앙에서 가까운 순서로 이미지(비디오 제외) 셀 탐색
        for indexPath in sortedItems {
            let actualIndex = indexPath.item - paddingCellCount
            let assetIP = IndexPath(item: actualIndex, section: 0)
            guard let asset = dataSourceDriver.asset(at: assetIP) else { continue }
            if asset.mediaType != .video {
                return indexPath
            }
        }
        return nil
    }

    // MARK: - C: Similar Photo Replay

    /// C 코치마크 즉시 재생 (C-1→C-2→C-3 시퀀스)
    func replayCoachMarkC() {
        Logger.coachMark.debug("C: 유사 사진 얼굴 비교 재생 시작")

        cleanupBeforeReplay()

        // 플래그 리셋
        CoachMarkType.similarPhoto.resetShown()
        CoachMarkType.faceComparisonGuide.resetShown()
        hasTriggeredC1 = false

        // SimilarityCache에서 그룹 멤버 탐색
        Task {
            let member = await SimilarityCache.shared.findAnyGroupMember()

            await MainActor.run {
                if let member {
                    // 캐시 hit → 해당 셀로 스크롤 → C-1 직접 트리거
                    self.replayC_withMember(assetID: member.assetID)
                } else {
                    // 캐시 miss → 로딩 UI + 자동 탐색
                    self.replayC_searchForGroup()
                }
            }
        }
    }

    /// C 재생: 캐시에서 그룹 멤버를 찾은 경우
    private func replayC_withMember(assetID: String) {
        // assetID → indexPath 해석
        guard let found = dataSourceDriver.indexPath(for: assetID) else {
            Logger.coachMark.error("C: assetID→indexPath 실패 — 플래그 복원")
            CoachMarkType.similarPhoto.markAsShown()
            CoachMarkType.faceComparisonGuide.markAsShown()
            if let window = view.window {
                ToastView.show("인물사진 비교정리 할 사진을 찾지 못했습니다", in: window)
            }
            return
        }

        // padding 보정
        let gridIndexPath = IndexPath(item: found.item + paddingCellCount, section: found.section)

        // 셀을 실제 가시 영역 기준 중앙으로 스크롤
        scrollToCenteredItem(at: gridIndexPath, animated: true)

        // 스크롤 완료 대기 → 뱃지 표시 → C-1 직접 호출
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self else { return }

            guard let cell = self.collectionView.cellForItem(at: gridIndexPath) as? PhotoCell else {
                Logger.coachMark.error("C: 스크롤 후 셀 미발견 — 플래그 복원")
                CoachMarkType.similarPhoto.markAsShown()
                CoachMarkType.faceComparisonGuide.markAsShown()
                return
            }

            // 뱃지 표시 보장
            self.showBadge(on: cell)

            // 0.3초 후 C-1 직접 호출 (triggerCoachMarkCIfNeeded 우회)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.showSimilarBadgeCoachMark(cell: cell, assetID: assetID)
            }
        }
    }

    /// C 재생: 캐시 miss → 로딩 UI 표시 + 자동 탐색
    private func replayC_searchForGroup() {
        guard let window = view.window else {
            CoachMarkType.similarPhoto.markAsShown()
            CoachMarkType.faceComparisonGuide.markAsShown()
            return
        }

        // 로딩 UI 생성
        let loadingContainer = UIView(frame: window.bounds)
        loadingContainer.backgroundColor = UIColor.black.withAlphaComponent(0.4)

        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false

        let spinner = UIActivityIndicatorView(style: .large)
        spinner.color = .white
        spinner.startAnimating()
        stack.addArrangedSubview(spinner)

        let label = UILabel()
        label.text = "기능이 실행되는\n사진을 찾고 있어요"
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        stack.addArrangedSubview(label)

        loadingContainer.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: loadingContainer.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: loadingContainer.centerYAnchor),
        ])

        window.addSubview(loadingContainer)

        // 보관함 최신 사진부터 유사 그룹 자동 탐색
        Task {
            let found = await self.searchForSimilarGroup()

            await MainActor.run { [weak self] in
                loadingContainer.removeFromSuperview()

                guard let self else { return }

                if let assetID = found {
                    self.replayC_withMember(assetID: assetID)
                } else {
                    // 못 찾음 → 플래그 복원 + 토스트
                    CoachMarkType.similarPhoto.markAsShown()
                    CoachMarkType.faceComparisonGuide.markAsShown()
                    if let window = self.view.window {
                        ToastView.show("인물사진 비교정리 할 사진을 찾지 못했습니다", in: window)
                    }
                }
            }
        }
    }

    /// 보관함에서 유사 그룹이 있는 사진을 탐색
    /// 최신 사진부터 순차적으로 SimilarityCache를 확인하여 그룹 멤버 반환
    private func searchForSimilarGroup() async -> String? {
        let totalCount = dataSourceDriver.count
        guard totalCount > 0 else { return nil }

        // 최신 순서(index 0부터)로 탐색
        for i in 0..<min(totalCount, 500) {
            let indexPath = IndexPath(item: i, section: 0)
            guard let assetID = dataSourceDriver.assetID(at: indexPath) else { continue }

            let state = await SimilarityCache.shared.getState(for: assetID)
            if case .analyzed(true, _) = state {
                return assetID
            }
        }
        return nil
    }

    // MARK: - D: Auto Cleanup Replay

    /// D 코치마크 즉시 재생
    func replayCoachMarkD() {
        Logger.coachMark.debug("D: 저품질 사진 정리 재생 시작")

        guard let window = view.window else { return }

        cleanupBeforeReplay()

        // 플래그 리셋
        CoachMarkType.autoCleanup.resetShown()

        // 정리 버튼 프레임 획득
        let cleanupFrame = getCleanupButtonFrame(in: window)

        // 썸네일 없이 텍스트만 (scanResult: nil), dismiss만 (빈 클로저)
        CoachMarkOverlayView.showAutoCleanup(
            highlightFrame: cleanupFrame,
            scanResult: nil,
            in: window,
            onConfirm: {}
        )

        // 표시 실패 시 플래그 복원
        if !CoachMarkManager.shared.isShowing {
            Logger.coachMark.error("D: 표시 실패 — 플래그 복원")
            CoachMarkType.autoCleanup.markAsShown()
        }
    }

    // MARK: - E-1+E-2: Delete System Guide Replay

    /// E-1+E-2 코치마크 즉시 재생
    /// A 변형 (1회 스와이프) → 실제 삭제 → E 시퀀스
    func replayCoachMarkE1E2() {
        Logger.coachMark.debug("E-1+E-2: 삭제 시스템 안내 재생 시작")

        guard dataSourceDriver.count > 0 else {
            if let window = view.window {
                ToastView.show("사진이 없습니다", in: window)
            }
            return
        }

        // 중앙 셀 찾기
        guard let (cell, indexPath) = findCenterCell() else {
            if let window = view.window {
                ToastView.show("사진이 없습니다", in: window)
            }
            return
        }

        // 사전 캡처: assetID + iconFrame (삭제 후에는 셀이 사라짐)
        let actualIndex = indexPath.item - paddingCellCount
        guard let assetID = dataSourceDriver.assetID(at: IndexPath(item: actualIndex, section: 0)) else {
            return
        }

        guard let window = view.window,
              let cellFrame = cell.superview?.convert(cell.frame, to: window),
              let snapshot = cell.snapshotView(afterScreenUpdates: false) else {
            return
        }

        // trashIcon 프레임 사전 캡처 (삭제 후 셀이 사라지므로)
        let iconFrame = cell.trashIconFrameInWindow()

        cleanupBeforeReplay()

        // 플래그 리셋
        CoachMarkType.firstDeleteGuide.resetShown()

        // A 변형 오버레이 표시 → 1회 스와이프 → 자동 dismiss → 삭제 → E 시퀀스
        CoachMarkOverlayView.showReplaySwipeVariant(
            highlightFrame: cellFrame,
            snapshot: snapshot,
            in: window,
            onComplete: { [weak self] in
                guard let self else { return }

                // 실제 삭제
                self.trashStore.moveToTrash(assetIDs: [assetID])
                Logger.coachMark.debug("E-1+E-2: 사진 삭제 완료 — E 시퀀스 시작")

                // E-1+E-2 시퀀스 시작 (showDeleteSystemGuide 직접 호출)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                    guard let window = self?.view.window else {
                        CoachMarkType.firstDeleteGuide.markAsShown()
                        return
                    }
                    CoachMarkOverlayView.showDeleteSystemGuide(in: window, iconFrame: iconFrame)
                }
            }
        )
    }

    // MARK: - E-3: First Empty Feedback Replay

    /// E-3 코치마크 즉시 재생
    func replayCoachMarkE3() {
        Logger.coachMark.debug("E-3: 비우기 완료 안내 재생 시작")

        guard let window = view.window else { return }

        cleanupBeforeReplay()

        // 플래그 리셋
        CoachMarkType.firstEmpty.resetShown()

        // 카드 팝업 표시
        CoachMarkOverlayView.showFirstEmptyFeedback(in: window)
    }
}

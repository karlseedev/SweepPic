//
//  GridViewController+CoachMarkC.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-17.
//
//  코치마크 C-1: 유사사진 뱃지 셀 하이라이트
//  - showBadge(on:count:) 호출 시 triggerCoachMarkCIfNeeded(for:) 진입
//  - 1초 딜레이 후 재검증 → 코치마크 표시
//  - [확인] + 탭 모션 후 자동으로 뷰어 네비게이션
//  - 중복 방지: hasTriggeredC1 associated object 플래그
//
//  트리거: showBadge → triggerCoachMarkCIfNeeded → 1초 딜레이 → showSimilarBadgeCoachMark
//  네비게이션: navigateToViewerForCoachMark → collectionView(_:didSelectItemAt:) 직접 호출

import UIKit
import ObjectiveC
import AppCore

// MARK: - Associated Keys

/// C-1 extension stored property를 위한 키
private enum CoachMarkCAssociatedKeys {
    static var hasTriggeredC1: UInt8 = 0
}

// MARK: - Coach Mark C-1: Similar Photo Badge

extension GridViewController {

    // MARK: - Associated Property

    /// C-1 트리거 완료 플래그 (중복 방지)
    /// showBadge는 visible 셀 전체에 대해 반복 호출되므로,
    /// 첫 호출에서 true로 설정하여 이후 호출을 스킵
    /// 리셋: dismiss/타임아웃/재검증 실패 시 false
    var hasTriggeredC1: Bool {
        get {
            (objc_getAssociatedObject(self, &CoachMarkCAssociatedKeys.hasTriggeredC1) as? Bool) ?? false
        }
        set {
            objc_setAssociatedObject(
                self,
                &CoachMarkCAssociatedKeys.hasTriggeredC1,
                newValue,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
        }
    }

    // MARK: - Trigger

    /// 뱃지 표시 시 C-1 코치마크 트리거 시도
    /// showBadge(on:count:) 마지막에서 호출됨
    /// - Parameter cell: 뱃지가 표시된 PhotoCell
    func triggerCoachMarkCIfNeeded(for cell: PhotoCell) {
        // 이미 표시된 적 있으면 스킵
        // guard !CoachMarkType.similarPhoto.hasBeenShown else { return } // 테스트: 항상 트리거

        // B(뷰어 스와이프) 완료 후에만 C 표시 (기본 기능 B → 고급 기능 C 순서)
        // guard CoachMarkType.viewerSwipeDelete.hasBeenShown else { return } // 테스트: B 없이도 트리거

        // 현재 다른 코치마크 표시 중이면 스킵
        guard !CoachMarkManager.shared.isShowing else { return }

        // 이미 C-1 트리거됨 (중복 방지)
        guard !hasTriggeredC1 else { return }

        // Select 모드면 스킵 (didSelectItemAt의 isSelectMode 가드 통과 보장)
        guard !isSelectMode else { return }

        // VoiceOver 활성 시 스킵
        guard !UIAccessibility.isVoiceOverRunning else { return }

        // 화면이 활성 상태인지
        guard let window = view.window else { return }

        // 그리드가 최상위 화면인지 (뷰어가 push/present된 상태면 스킵)
        guard navigationController?.topViewController === self,
              presentedViewController == nil else { return }

        // 초기 로딩 완료 후에만
        guard hasFinishedInitialDisplay else { return }

        // 가시 영역 사전 검증: 상하 12.5% 마진 제외한 중앙 75% 영역에 셀이 완전히 들어와야 함
        // 락(hasTriggeredC1) 잡기 전에 체크 → zone 밖 셀은 락을 잡지 않아 다른 셀에 기회를 줌
        guard let cellFrame = cell.superview?.convert(cell.frame, to: window) else { return }
        let screenHeight = window.bounds.height
        let topMargin = screenHeight * 0.125
        let bottomMargin = screenHeight * 0.875
        guard cellFrame.minY >= topMargin && cellFrame.maxY <= bottomMargin else { return }

        // 중복 트리거 방지 — zone 안 첫 뱃지에서만 동작
        hasTriggeredC1 = true

        // 셀의 indexPath + assetID 캡처
        guard let indexPath = collectionView.indexPath(for: cell) else {
            hasTriggeredC1 = false
            return
        }

        // assetID 캡처 (PHChange 안전성 확보)
        let actualIndex = indexPath.item - paddingCellCount
        guard actualIndex >= 0,
              let assetID = dataSourceDriver.assetID(at: IndexPath(item: actualIndex, section: 0)) else {
            hasTriggeredC1 = false
            return
        }

        // 즉시 터치 차단: 투명 뷰로 window 전체를 덮어 스크롤/탭 등 모든 입력 차단
        // 뱃지 등장 → C-1 발동 사이에 사용자가 다른 조작을 할 수 없도록 보장
        // UIView의 기본 hitTest가 터치를 가로채므로 하위 뷰에 이벤트 전달 안 됨
        let blocker = UIView(frame: window.bounds)
        window.addSubview(blocker)

        // 셀을 화면 중앙으로 즉시 스크롤 (1초 대기 없이)
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: true)

        // 스크롤 애니메이션 완료 대기 후 코치마크 표시
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self, weak cell, weak blocker] in
            // 터치 차단 해제 (코치마크 오버레이가 대신 차단)
            blocker?.removeFromSuperview()

            guard let self, let cell else {
                self?.hasTriggeredC1 = false
                self?.retriggerForVisibleBadges()
                return
            }

            // 재검증: 셀이 여전히 visible한지
            guard self.collectionView.visibleCells.contains(cell) else {
                self.hasTriggeredC1 = false
                self.retriggerForVisibleBadges()
                return
            }

            // 재검증: 뱃지가 여전히 표시 중인지
            let hasBadge = cell.contentView.subviews.contains(where: { $0 is SimilarGroupBadgeView })
            guard hasBadge else {
                self.hasTriggeredC1 = false
                self.retriggerForVisibleBadges()
                return
            }

            // 재검증: 다른 코치마크가 안 뜨고 있는지
            guard !CoachMarkManager.shared.isShowing else {
                self.hasTriggeredC1 = false
                return
            }

            // 재검증: 그리드가 최상위 화면인지
            guard self.navigationController?.topViewController === self,
                  self.presentedViewController == nil else {
                self.hasTriggeredC1 = false
                return
            }

            self.showSimilarBadgeCoachMark(cell: cell, assetID: assetID)
        }
    }

    // MARK: - Show

    /// C-1 코치마크 표시
    /// - Parameters:
    ///   - cell: 뱃지가 표시된 셀
    ///   - assetID: 해당 셀의 assetID (PHChange 안전성용)
    private func showSimilarBadgeCoachMark(cell: PhotoCell, assetID: String) {
        // 윈도우 + 셀 프레임 → 윈도우 좌표 변환
        guard let window = view.window,
              let cellFrame = cell.superview?.convert(cell.frame, to: window) else {
            hasTriggeredC1 = false
            return
        }

        // C-1 표시 + onConfirm 콜백 설정
        CoachMarkOverlayView.showSimilarBadge(
            highlightFrame: cellFrame,
            in: window,
            onConfirm: { [weak self] in
                guard let self else { return }

                // C-1 → C-2 전환 중 보호 활성화
                CoachMarkManager.shared.isWaitingForC2 = true
                Log.print("[CoachMarkC1] onConfirm — isWaitingForC2=true, overlay=\(CoachMarkManager.shared.currentOverlay != nil)")

                // C-1 → C-2 안전 타임아웃 (확인 버튼 탭 시점부터 10초)
                // 뷰어 전환(~0.5초) + 버튼 대기(최대 5초) + 여유를 포함한 안전장치
                // C-2 전환 성공 시 ViewerViewController+CoachMarkC에서 cancel하여 무효화
                let timeoutWork = DispatchWorkItem { [weak self] in
                    guard CoachMarkManager.shared.isWaitingForC2 else { return }
                    CoachMarkManager.shared.resetC2State()
                    CoachMarkManager.shared.currentOverlay?.dismiss()
                    self?.hasTriggeredC1 = false
                }
                CoachMarkManager.shared.safetyTimeoutWork = timeoutWork
                DispatchQueue.main.asyncAfter(deadline: .now() + 10.0, execute: timeoutWork)

                // assetID로 indexPath 재해석 (PHChange 안전성)
                // confirm 시점에 fetchResult가 바뀌었을 수 있으므로 assetID → indexPath 재검색
                let resolvedIndexPath: IndexPath
                if let found = self.dataSourceDriver.indexPath(for: assetID) {
                    // padding 보정 (dataSourceDriver는 padding 미포함 indexPath 반환)
                    resolvedIndexPath = IndexPath(item: found.item + self.paddingCellCount, section: found.section)
                } else {
                    // assetID를 못 찾으면 3초 타임아웃이 처리 (여기서는 원래 셀 위치 사용)
                    if let currentIP = self.collectionView.indexPath(for: cell) {
                        resolvedIndexPath = currentIP
                    } else {
                        // 셀도 없으면 실패 → 타임아웃이 정리
                        return
                    }
                }

                // 자동 네비게이션 → 뷰어
                self.navigateToViewerForCoachMark(at: resolvedIndexPath)
            }
        )
    }

    // MARK: - Retrigger

    /// hasTriggeredC1 리셋 후 visible 뱃지 셀 재스캔
    /// 타이밍 문제 해결: Badge A가 락을 잡고 1초 타이머 진행 중에 Badge B가 등장하면,
    /// Badge B의 showBadge 호출은 이미 완료되어 재호출되지 않음.
    /// Badge A 재검증 실패 → hasTriggeredC1 = false 리셋 시,
    /// 현재 visible한 뱃지 셀 중 zone 안에 있는 첫 셀로 재트리거 시도
    private func retriggerForVisibleBadges() {
        // hasTriggeredC1이 이미 true면 중복 방지 (다른 경로에서 이미 트리거됨)
        guard !hasTriggeredC1 else { return }

        // 현재 visible한 셀 중 SimilarGroupBadgeView가 있는 셀 수집
        for cell in collectionView.visibleCells {
            guard let photoCell = cell as? PhotoCell else { continue }
            let hasBadge = photoCell.contentView.subviews.contains(where: { $0 is SimilarGroupBadgeView })
            guard hasBadge else { continue }

            // triggerCoachMarkCIfNeeded에서 zone 검증 + 모든 가드를 다시 수행하므로
            // 여기서는 뱃지가 있는 셀만 넘겨주면 됨
            triggerCoachMarkCIfNeeded(for: photoCell)

            // hasTriggeredC1이 true로 설정되면 (트리거 성공) 더 이상 스캔 불필요
            if hasTriggeredC1 { break }
        }
    }

    // MARK: - Navigate

    /// C-1 자동 네비게이션: 뷰어로 이동
    /// collectionView(_:didSelectItemAt:) 직접 호출
    /// 안전성 확인 완료:
    /// - isSelectMode: C-1 가드에서 !isSelectMode 체크 → false 보장
    /// - padding: collectionView.indexPath(for:)로 얻은 값은 padding 포함 → 통과
    /// - fetchResult: 뱃지가 표시되려면 분석 완료 필수 → non-nil 보장
    private func navigateToViewerForCoachMark(at indexPath: IndexPath) {
        collectionView(collectionView, didSelectItemAt: indexPath)
    }
}

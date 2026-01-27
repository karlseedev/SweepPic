//
//  GridGestures.swift
//  PickPhoto
//
//  Created by Claude on 2025-12-31.
//  Description: GridViewController의 제스처 관련 기능 분리
//               - Pinch Zoom 후처리 (refreshVisibleCellsAfterZoom)
//               - UIGestureRecognizerDelegate (T040)
//               - 드래그 선택 제스처 처리
//
//  Note: SwipeDeleteState 및 스와이프 삭제/복구 코드는
//        BaseGridViewController로 이동됨 (공통화)
//

import UIKit
import Photos
import AppCore

// MARK: - Pinch Zoom (T023)

// handlePinchGesture, performZoom → BaseGridViewController로 이동됨
// 관련 상수 (pinchZoomInThreshold, pinchZoomOutThreshold, pinchCooldown) → BaseGridViewController로 이동됨
// 헬퍼 메서드 (assetIDForCollectionIndexPath, collectionIndexPath) → BaseGridViewController로 이동됨

extension GridViewController {

    // didPerformZoom 오버라이드 → GridViewController.swift 본체로 이동됨

    /// 줌 후 visible cells에 고해상도 썸네일 재요청
    /// - 스크롤 중이면 스킵 (스크롤 완료 후 자연스럽게 재로드됨)
    /// - targetSize가 커질 때만 재요청 (PhotoCell에서 판단)
    func refreshVisibleCellsAfterZoom() {
        // 안전 가드 1: 스크롤 중이면 스킵
        if isScrolling || collectionView.isDragging || collectionView.isDecelerating {
            return
        }

        let targetSize = thumbnailSize(forScrolling: false)

        for indexPath in collectionView.indexPathsForVisibleItems {
            // padding 셀 제외
            guard indexPath.item >= paddingCellCount else { continue }

            // 실제 에셋 인덱스
            let assetIndexPath = IndexPath(item: indexPath.item - paddingCellCount, section: 0)
            guard let asset = dataSourceDriver.asset(at: assetIndexPath),
                  let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else {
                continue
            }

            // 고해상도 재요청 (targetSize 비교는 PhotoCell에서 수행)
            cell.refreshImageIfNeeded(asset: asset, targetSize: targetSize)
        }
    }
}

// MARK: - UIGestureRecognizerDelegate Override (T040)

extension GridViewController {

    /// 제스처 동시 인식 허용 (Base 오버라이드)
    /// 핀치 줌과 드래그 선택이 동시에 동작할 수 있도록
    override public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 드래그 선택 제스처는 핀치와 동시 인식 허용
        if gestureRecognizer == dragSelectGesture {
            return otherGestureRecognizer is UIPinchGestureRecognizer
        }
        // 핀치 줌은 Base에서 처리
        return super.gestureRecognizer(gestureRecognizer, shouldRecognizeSimultaneouslyWith: otherGestureRecognizer)
    }

    /// 드래그 선택 제스처 시작 조건 (Base 오버라이드)
    /// iOS 사진 앱 동작: 수평 드래그로 시작해야만 드래그 선택 모드
    /// 수직 드래그만 하면 스크롤 (드래그 선택 제스처 실패)
    override public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 드래그 선택 제스처
        if gestureRecognizer == dragSelectGesture {
            guard isSelectMode else { return false }

            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = panGesture.velocity(in: collectionView)

            // 수평 이동 속도가 수직 이동 속도보다 커야 드래그 선택 모드
            let isHorizontalDrag = abs(velocity.x) > abs(velocity.y)

            if isHorizontalDrag {
                Log.print("[GridViewController] Drag select gesture began (horizontal drag detected)")
            }

            return isHorizontalDrag
        }

        // 나머지는 Base에서 처리 (스와이프 삭제 포함)
        return super.gestureRecognizerShouldBegin(gestureRecognizer)
    }
}

// MARK: - PRD7: Swipe Delete Override (GridViewController 전용)

extension GridViewController {

    /// 스와이프 제스처 활성화 상태 업데이트 (isSelectMode 고려)
    /// BaseGridViewController의 기본 구현을 오버라이드
    override func updateSwipeDeleteGestureEnabled() {
        let enabled = !isSelectMode && !UIAccessibility.isVoiceOverRunning
        swipeDeleteState.swipeGesture?.isEnabled = enabled
        swipeDeleteState.twoFingerTapGesture?.isEnabled = enabled
    }
}

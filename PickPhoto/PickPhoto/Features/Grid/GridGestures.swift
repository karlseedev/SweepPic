//
//  GridGestures.swift
//  PickPhoto
//
//  Created by Claude on 2025-12-31.
//  Description: GridViewController의 제스처 관련 기능 분리
//               - Pinch Zoom (T023)
//               - UIGestureRecognizerDelegate (T040)
//               - PRD7: Swipe Delete/Restore (FR-101) - 추후 추가
//               - PRD7: Two Finger Tap Delete/Restore (FR-102) - 추후 추가
//

import UIKit
import Photos
import AppCore

// MARK: - Pinch Zoom (T023)

extension GridViewController {

    // TODO: Pinch Zoom 코드 이동 예정 (Phase 4)

}

// MARK: - UIGestureRecognizerDelegate (T040)

extension GridViewController: UIGestureRecognizerDelegate {

    /// 제스처 동시 인식 허용
    /// 핀치 줌과 드래그 선택이 동시에 동작할 수 있도록
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 드래그 선택 제스처는 핀치와 동시 인식 허용
        if gestureRecognizer == dragSelectGesture {
            return otherGestureRecognizer is UIPinchGestureRecognizer
        }
        return false
    }

    /// 드래그 선택 제스처 시작 조건
    /// iOS 사진 앱 동작: 수평 드래그로 시작해야만 드래그 선택 모드
    /// 수직 드래그만 하면 스크롤 (드래그 선택 제스처 실패)
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == dragSelectGesture {
            guard isSelectMode else { return false }

            // 팬 제스처의 이동 방향 확인
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }

            let velocity = panGesture.velocity(in: collectionView)

            // 수평 이동 속도가 수직 이동 속도보다 커야 드래그 선택 모드
            // 이렇게 하면 수직 드래그는 스크롤로 처리됨
            let isHorizontalDrag = abs(velocity.x) > abs(velocity.y)

            if isHorizontalDrag {
                print("[GridViewController] Drag select gesture began (horizontal drag detected)")
            }

            return isHorizontalDrag
        }
        return true
    }
}

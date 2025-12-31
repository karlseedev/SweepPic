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

    // MARK: - Pinch Zoom Constants

    /// 핀치 줌 임계값 (T023)
    static let pinchZoomInThreshold: CGFloat = 1.15  // 확대 시
    static let pinchZoomOutThreshold: CGFloat = 0.85 // 축소 시

    /// 핀치 줌 쿨다운 (T023: 200ms)
    static let pinchCooldown: TimeInterval = 0.2

    // MARK: - Pinch Zoom Methods

    /// 핀치 줌 제스처 핸들러
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            // 앵커 에셋 ID 저장 (핀치 시작 위치의 셀)
            let location = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location) {
                pinchAnchorAssetID = dataSourceDriver.assetID(at: indexPath)
            }

        case .changed:
            // 쿨다운 체크 (200ms)
            if let lastTime = lastPinchZoomTime,
               Date().timeIntervalSince(lastTime) < Self.pinchCooldown {
                return
            }

            // 임계값 체크
            let scale = gesture.scale

            var newColumnCount: ColumnCount?

            if scale > Self.pinchZoomInThreshold {
                // 확대 (열 수 감소)
                newColumnCount = currentColumnCount.zoomIn
            } else if scale < Self.pinchZoomOutThreshold {
                // 축소 (열 수 증가)
                newColumnCount = currentColumnCount.zoomOut
            }

            // 열 수가 변경되면 레이아웃 업데이트
            if let newCount = newColumnCount, newCount != currentColumnCount {
                performZoom(to: newCount)
                gesture.scale = 1.0 // 스케일 리셋
            }

        case .ended, .cancelled:
            pinchAnchorAssetID = nil

        default:
            break
        }
    }

    /// 줌 수행
    /// - Parameter columns: 새 열 수
    func performZoom(to columns: ColumnCount) {
        // 쿨다운 시간 기록
        lastPinchZoomTime = Date()

        // 현재 앵커 IndexPath 저장
        let anchorIndexPath: IndexPath?
        if let anchorID = pinchAnchorAssetID {
            anchorIndexPath = dataSourceDriver.indexPath(for: anchorID)
        } else {
            // 앵커가 없으면 화면 중앙 셀 사용
            let centerPoint = CGPoint(
                x: collectionView.bounds.midX,
                y: collectionView.bounds.midY + collectionView.contentOffset.y
            )
            anchorIndexPath = collectionView.indexPathForItem(at: centerPoint)
        }

        // 열 수 업데이트
        currentColumnCount = columns
        updateCellSize()

        // 레이아웃 애니메이션
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self = self else { return }

            // 새 레이아웃 적용
            self.collectionView.setCollectionViewLayout(
                self.createLayout(columns: columns),
                animated: false
            )

            // 앵커 위치로 스크롤 (drift 0px 목표)
            if let indexPath = anchorIndexPath {
                self.collectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredVertically,
                    animated: false
                )
            }
        }

        print("[GridViewController] Zoom to \(columns.rawValue) columns")
    }
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

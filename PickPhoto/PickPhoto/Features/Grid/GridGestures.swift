//
//  GridGestures.swift
//  PickPhoto
//
//  Created by Claude on 2025-12-31.
//  Description: GridViewController의 제스처 관련 기능 분리
//               - Pinch Zoom (T023)
//               - UIGestureRecognizerDelegate (T040)
//               - PRD7: Swipe Delete/Restore (FR-101)
//               - PRD7: Two Finger Tap Delete/Restore (FR-102)
//

import UIKit
import Photos
import AppCore

// MARK: - Swipe Delete State (PRD7)

/// 스와이프 삭제 상태 (extension에서 stored property 불가 → 구조체로 묶음)
struct SwipeDeleteState {
    /// 스와이프 제스처
    var swipeGesture: UIPanGestureRecognizer?
    /// 투 핑거 탭 제스처
    var twoFingerTapGesture: UITapGestureRecognizer?
    /// 현재 대상 셀 (약한 참조)
    weak var targetCell: PhotoCell?
    /// 현재 대상 IndexPath
    var targetIndexPath: IndexPath?
    /// 대상의 현재 휴지통 상태
    var targetIsTrashed: Bool = false
    /// 각도 판정 통과 여부 (10pt 이동 후 결정)
    var angleCheckPassed: Bool = false

    // MARK: - PRD7 상수

    /// 스와이프 각도 임계값 (수평선 ±15°)
    static let angleThreshold: CGFloat = 15.0 * .pi / 180.0
    /// 최소 이동 거리 (각도 판정 전)
    static let minimumTranslation: CGFloat = 10.0
    /// 확정 비율 (셀 너비의 50%)
    static let confirmRatio: CGFloat = 0.5
    /// 확정 속도 (800pt/s)
    static let confirmVelocity: CGFloat = 800.0

    /// 상태 초기화
    mutating func reset() {
        targetCell = nil
        targetIndexPath = nil
        targetIsTrashed = false
        angleCheckPassed = false
    }
}

// MARK: - Pinch Zoom (T023)

// handlePinchGesture, performZoom → BaseGridViewController로 이동됨
// 관련 상수 (pinchZoomInThreshold, pinchZoomOutThreshold, pinchCooldown) → BaseGridViewController로 이동됨
// 헬퍼 메서드 (assetIDForCollectionIndexPath, collectionIndexPath) → BaseGridViewController로 이동됨

extension GridViewController {

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
        // PRD7: 스와이프 삭제 제스처
        if gestureRecognizer == swipeDeleteState.swipeGesture {
            // 스크롤 momentum 중이면 무시
            if collectionView.isDecelerating { return false }

            // 터치 위치에 셀이 없으면 무시 (빈 영역)
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let location = pan.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: location) else { return false }

            // 패딩 셀이면 무시
            guard indexPath.item >= paddingCellCount else { return false }

            // velocity 기반 힌트 (느슨하게 30° 이내 허용)
            // 정밀 각도 판정은 .changed에서 10pt 이동 후 수행
            let velocity = pan.velocity(in: collectionView)
            let angle = atan2(abs(velocity.y), abs(velocity.x))
            return angle < (30.0 * .pi / 180.0)
        }

        // 드래그 선택 제스처
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

// MARK: - PRD7: Swipe Delete/Restore (FR-101)

extension GridViewController {

    /// 스와이프/투핑거탭 제스처 설정 (setupGestures()에서 호출)
    func setupSwipeDeleteGestures() {
        // 스와이프 삭제 제스처
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeDelete(_:)))
        swipe.delegate = self
        collectionView.addGestureRecognizer(swipe)
        swipeDeleteState.swipeGesture = swipe

        // 투 핑거 탭 제스처 (Phase 2에서 핸들러 구현)
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        tap.numberOfTouchesRequired = 2
        tap.delegate = self
        collectionView.addGestureRecognizer(tap)
        swipeDeleteState.twoFingerTapGesture = tap

        updateSwipeDeleteGestureEnabled()
    }

    /// 스와이프 제스처 활성화 상태 업데이트
    func updateSwipeDeleteGestureEnabled() {
        let enabled = !isSelectMode && !UIAccessibility.isVoiceOverRunning
        swipeDeleteState.swipeGesture?.isEnabled = enabled
        swipeDeleteState.twoFingerTapGesture?.isEnabled = enabled
    }

    /// 진행 중인 스와이프 취소 (백그라운드 진입 등)
    func cancelActiveSwipe() {
        guard let cell = swipeDeleteState.targetCell else { return }
        cell.cancelDimmedAnimation {
            cell.isAnimating = false
        }
        swipeDeleteState.reset()
    }

    // MARK: - Swipe Delete Handler

    /// 스와이프 삭제 제스처 핸들러
    @objc func handleSwipeDelete(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            handleSwipeDeleteBegan(gesture)

        case .changed:
            handleSwipeDeleteChanged(gesture)

        case .ended:
            handleSwipeDeleteEnded(gesture)

        case .cancelled, .failed:
            handleSwipeDeleteCancelled()

        default:
            break
        }
    }

    // MARK: - Swipe Delete State Handlers

    /// 스와이프 시작
    private func handleSwipeDeleteBegan(_ gesture: UIPanGestureRecognizer) {
        // 터치 위치 → indexPath 계산
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location) else {
            gesture.state = .cancelled
            return
        }

        // 패딩 셀 체크
        guard indexPath.item >= paddingCellCount else {
            gesture.state = .cancelled
            return
        }

        // 셀 가져오기
        guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else {
            gesture.state = .cancelled
            return
        }

        // 애니메이션 중인 셀이면 무시
        guard !cell.isAnimating else {
            gesture.state = .cancelled
            return
        }

        // 상태 저장
        swipeDeleteState.targetCell = cell
        swipeDeleteState.targetIndexPath = indexPath
        swipeDeleteState.targetIsTrashed = cell.isTrashed
        swipeDeleteState.angleCheckPassed = false

        // 셀 잠금
        cell.isAnimating = true

        // 햅틱 준비
        HapticFeedback.prepare()
    }

    /// 스와이프 진행 중
    private func handleSwipeDeleteChanged(_ gesture: UIPanGestureRecognizer) {
        guard let cell = swipeDeleteState.targetCell else { return }

        let translation = gesture.translation(in: collectionView)
        let absX = abs(translation.x)

        // 10pt 이동 전에는 각도 판정 보류
        if absX < SwipeDeleteState.minimumTranslation && !swipeDeleteState.angleCheckPassed {
            return
        }

        // 각도 판정 (1회만)
        if !swipeDeleteState.angleCheckPassed {
            let angle = atan2(abs(translation.y), abs(translation.x))
            if angle > SwipeDeleteState.angleThreshold {
                // 스크롤로 전환 (제스처 취소)
                handleSwipeDeleteCancelled()
                gesture.state = .cancelled
                return
            }
            swipeDeleteState.angleCheckPassed = true
        }

        // progress 계산 (0.0 ~ 1.0)
        let cellWidth = currentCellSize.width
        let progress = min(1.0, absX / cellWidth)

        // 방향 결정
        let direction: PhotoCell.SwipeDirection = translation.x > 0 ? .right : .left

        // 셀 딤드 업데이트
        cell.setDimmedProgress(progress, direction: direction, isTrashed: swipeDeleteState.targetIsTrashed)
    }

    /// 스와이프 종료
    private func handleSwipeDeleteEnded(_ gesture: UIPanGestureRecognizer) {
        guard let cell = swipeDeleteState.targetCell,
              let indexPath = swipeDeleteState.targetIndexPath else {
            swipeDeleteState.reset()
            return
        }

        let translation = gesture.translation(in: collectionView)
        let velocity = gesture.velocity(in: collectionView)
        let cellWidth = currentCellSize.width

        // 확정 조건 체크
        let isDistanceConfirmed = abs(translation.x) >= cellWidth * SwipeDeleteState.confirmRatio
        let isVelocityConfirmed = abs(velocity.x) >= SwipeDeleteState.confirmVelocity

        if (isDistanceConfirmed || isVelocityConfirmed) && swipeDeleteState.angleCheckPassed {
            // 확정: 삭제 또는 복원 실행
            confirmSwipeDelete(cell: cell, indexPath: indexPath)
        } else {
            // 취소: 원래 상태로 복귀
            cancelSwipeDelete(cell: cell)
        }
    }

    /// 스와이프 취소
    private func handleSwipeDeleteCancelled() {
        guard let cell = swipeDeleteState.targetCell else {
            swipeDeleteState.reset()
            return
        }

        cancelSwipeDelete(cell: cell)
    }

    // MARK: - Swipe Delete Actions

    /// 스와이프 삭제/복원 확정
    private func confirmSwipeDelete(cell: PhotoCell, indexPath: IndexPath) {
        let isTrashed = swipeDeleteState.targetIsTrashed
        let toTrashed = !isTrashed // 현재 상태 반전

        // 에셋 ID 가져오기
        let actualIndex = indexPath.item - paddingCellCount
        guard let assetID = dataSourceDriver.assetID(at: IndexPath(item: actualIndex, section: 0)) else {
            cancelSwipeDelete(cell: cell)
            return
        }

        // 딤드 애니메이션 확정
        cell.confirmDimmedAnimation(toTrashed: toTrashed) { [weak self] in
            guard let self = self else { return }

            // TrashStore 호출 (completion handler 사용)
            if toTrashed {
                self.trashStore.moveToTrash(assetID) { [weak self] result in
                    self?.handleTrashStoreResult(result, cell: cell)
                }
            } else {
                self.trashStore.restore(assetID) { [weak self] result in
                    self?.handleTrashStoreResult(result, cell: cell)
                }
            }
        }

        swipeDeleteState.reset()
    }

    /// 스와이프 취소
    private func cancelSwipeDelete(cell: PhotoCell) {
        cell.cancelDimmedAnimation { [weak self] in
            cell.isAnimating = false
            self?.swipeDeleteState.reset()
        }
    }

    /// TrashStore 결과 처리
    private func handleTrashStoreResult(_ result: Result<Void, TrashStoreError>, cell: PhotoCell) {
        switch result {
        case .success:
            HapticFeedback.light()
            cell.isAnimating = false

        case .failure:
            rollbackSwipeCell(cell: cell)
        }
    }

    /// 스와이프 롤백 처리
    func rollbackSwipeCell(cell: PhotoCell) {
        let originalTrashed = swipeDeleteState.targetIsTrashed

        // UI 롤백 애니메이션
        if originalTrashed {
            // 원래 삭제 상태였는데 복원 시도 실패 → 다시 딤드 표시
            cell.fadeDimmed(toTrashed: true) {
                cell.isAnimating = false
            }
        } else {
            // 원래 정상 상태였는데 삭제 시도 실패 → 딤드 제거
            cell.cancelDimmedAnimation {
                cell.isAnimating = false
            }
        }

        // 에러 햅틱
        HapticFeedback.error()

        // 토스트 메시지
        ToastView.show("저장 실패. 다시 시도해주세요", in: view.window)
    }

    // MARK: - PRD7: Two Finger Tap Delete/Restore (FR-102)

    /// 투 핑거 탭 제스처 핸들러
    @objc func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        // 두 터치 위치 확인
        let touch0 = gesture.location(ofTouch: 0, in: collectionView)
        let touch1 = gesture.location(ofTouch: 1, in: collectionView)

        // 같은 셀인지 확인
        guard let ip0 = collectionView.indexPathForItem(at: touch0),
              let ip1 = collectionView.indexPathForItem(at: touch1),
              ip0 == ip1 else {
            return
        }

        // 패딩 셀 방어
        guard ip0.item >= paddingCellCount else { return }

        // 에셋 ID 가져오기 (패딩 오프셋 적용)
        let actualIndex = ip0.item - paddingCellCount
        guard let assetID = dataSourceDriver.assetID(at: IndexPath(item: actualIndex, section: 0)) else {
            return
        }

        // 셀 가져오기 및 잠금 체크
        guard let cell = collectionView.cellForItem(at: ip0) as? PhotoCell,
              !cell.isAnimating else {
            return
        }

        // 삭제/복원 실행
        cell.isAnimating = true
        let isTrashed = cell.isTrashed
        let toTrashed = !isTrashed

        // 페이드 애니메이션
        cell.fadeDimmed(toTrashed: toTrashed) { [weak self] in
            guard let self = self else {
                cell.isAnimating = false
                return
            }

            // TrashStore 호출 (completion handler 사용)
            if toTrashed {
                self.trashStore.moveToTrash(assetID) { [weak self] result in
                    self?.handleTwoFingerTapResult(result, cell: cell, originalTrashed: isTrashed)
                }
            } else {
                self.trashStore.restore(assetID) { [weak self] result in
                    self?.handleTwoFingerTapResult(result, cell: cell, originalTrashed: isTrashed)
                }
            }
        }
    }

    /// 투 핑거 탭 TrashStore 결과 처리
    private func handleTwoFingerTapResult(
        _ result: Result<Void, TrashStoreError>,
        cell: PhotoCell,
        originalTrashed: Bool
    ) {
        switch result {
        case .success:
            HapticFeedback.light()
            cell.isAnimating = false

        case .failure:
            rollbackTwoFingerTapCell(cell: cell, toOriginalTrashed: originalTrashed)
        }
    }

    /// 투 핑거 탭 롤백 처리
    private func rollbackTwoFingerTapCell(cell: PhotoCell, toOriginalTrashed: Bool) {
        // UI 롤백 애니메이션
        cell.fadeDimmed(toTrashed: toOriginalTrashed) {
            cell.isAnimating = false
        }

        // 에러 햅틱
        HapticFeedback.error()

        // 토스트 메시지
        ToastView.show("저장 실패. 다시 시도해주세요", in: view.window)
    }
}

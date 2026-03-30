//
//  PreviewGridViewController+SwipeDelete.swift
//  SweepPic
//
//  미리보기 그리드의 스와이프 삭제 기능 (단일 셀)
//  - BaseGridViewController 상속 안 함 → 독립 구현
//  - SwipeDeleteState 구조체 재사용 (같은 모듈 내 접근)
//  - 삭제 = "제외" (previewResult.excluding 직접 갱신)
//  - isTrashed는 항상 false (미리보기는 삭제대기함이 아님)
//  - ⚠️ 모든 IndexPath에 swipeTargetSection 사용 (section: 0 하드코딩 금지)
//

import UIKit
import AppCore
import OSLog

// MARK: - Swipe Delete Gesture Setup & Handlers

extension PreviewGridViewController {

    // MARK: - 제스처 설정

    /// 스와이프 삭제 제스처 추가 (viewDidLoad에서 호출)
    func setupSwipeDeleteGesture() {
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeDelete(_:)))
        pan.delegate = self
        collectionView.addGestureRecognizer(pan)
        swipeDeleteState.swipeGesture = pan
    }

    // MARK: - 셀 너비 (스와이프 진행도 계산용)

    /// 현재 셀 너비 (collectionView.bounds 기반, 캐싱 불필요)
    var currentCellWidth: CGFloat {
        let totalSpacing = cellSpacing * (columns - 1)
        return floor((collectionView.bounds.width - totalSpacing) / columns)
    }

    // MARK: - 메인 제스처 핸들러

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

    // MARK: - Began

    /// 스와이프 시작 — 터치 위치에서 PhotoCell 탐색 + photos 섹션 검증
    private func handleSwipeDeleteBegan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: collectionView)

        // photos 섹션의 PhotoCell만 대상 (배너 차단)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              case .photos(let candidates) = sectionType(for: indexPath.section),
              indexPath.item < candidates.count,
              let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell,
              !cell.isAnimating else {
            gesture.state = .cancelled
            return
        }

        // 제외 여부에 따라 방향 결정
        let isExcluded = excludedAssetIDs.contains(candidates[indexPath.item].assetID)

        // 상태 설정
        swipeDeleteState.targetCell = cell
        swipeDeleteState.targetIndexPath = indexPath
        swipeDeleteState.targetIsTrashed = isExcluded  // 제외됨 → 커튼 걷힘 방향
        swipeDeleteState.angleCheckPassed = false
        swipeTargetSection = indexPath.section

        // 그린 오버레이 준비
        cell.prepareSwipeOverlay(style: .restore)
        cell.isAnimating = true
        HapticFeedback.prepare()
    }

    // MARK: - Changed

    /// 스와이프 진행 — 각도 체크 → 단일 커튼 or 다중 전환
    private func handleSwipeDeleteChanged(_ gesture: UIPanGestureRecognizer) {
        // 다중 모드: 별도 핸들러로 위임
        if swipeDeleteState.isMultiMode {
            let location = gesture.location(in: collectionView)
            let locationInView = gesture.location(in: view)
            handleMultiSwipeChanged(at: location)
            handleAutoScroll(at: locationInView)
            return
        }

        guard let cell = swipeDeleteState.targetCell else { return }

        let translation = gesture.translation(in: collectionView)
        let absX = abs(translation.x)

        // 10pt 이동 전에는 각도 판정 보류
        if absX < SwipeDeleteState.minimumTranslation && !swipeDeleteState.angleCheckPassed {
            return
        }

        // 각도 판정 (1회만 — 25° 초과 시 스크롤에 양보)
        if !swipeDeleteState.angleCheckPassed {
            let angle = atan2(abs(translation.y), abs(translation.x))
            if angle > SwipeDeleteState.angleThreshold {
                handleSwipeDeleteCancelled()
                gesture.state = .cancelled
                return
            }
            swipeDeleteState.angleCheckPassed = true
        }

        // 다른 셀 도달 체크 → 다중 모드 진입 (제외/해제 모두 가능)
        let location = gesture.location(in: collectionView)
        let locationInView = gesture.location(in: view)

        if let currentIP = collectionView.indexPathForItem(at: location),
           currentIP != swipeDeleteState.targetIndexPath,
           currentIP.section == swipeTargetSection,
           case .photos = sectionType(for: currentIP.section) {
            enterMultiSwipeMode()
            handleMultiSwipeChanged(at: location)
            handleAutoScroll(at: locationInView)
            return
        }

        // 같은 셀 내: 커튼 딤드 진행도
        let progress = min(1.0, absX / currentCellWidth)
        let direction: PhotoCell.SwipeDirection = translation.x > 0 ? .right : .left
        cell.setDimmedProgress(progress, direction: direction, isTrashed: swipeDeleteState.targetIsTrashed)
    }

    // MARK: - Ended

    /// 스와이프 종료 — 확정/취소 판정
    private func handleSwipeDeleteEnded(_ gesture: UIPanGestureRecognizer) {
        // 다중 모드: 별도 핸들러
        if swipeDeleteState.isMultiMode {
            confirmOrCancelMultiSwipe(gesture)
            return
        }

        guard let cell = swipeDeleteState.targetCell,
              let indexPath = swipeDeleteState.targetIndexPath else {
            swipeDeleteState.reset()
            return
        }

        let translation = gesture.translation(in: collectionView)
        let velocity = gesture.velocity(in: collectionView)

        let isDistanceConfirmed = abs(translation.x) >= currentCellWidth * SwipeDeleteState.confirmRatio
        let isVelocityConfirmed = abs(velocity.x) >= SwipeDeleteState.confirmVelocity

        if (isDistanceConfirmed || isVelocityConfirmed) && swipeDeleteState.angleCheckPassed {
            confirmSingleSwipeExclude(cell: cell, indexPath: indexPath)
        } else {
            cancelSingleSwipe(cell: cell)
        }
    }

    // MARK: - Cancelled

    /// 스와이프 취소 (시스템 cancel, 백그라운드 등)
    private func handleSwipeDeleteCancelled() {
        if swipeDeleteState.isMultiMode {
            cancelMultiSwipeDelete()
            return
        }
        guard let cell = swipeDeleteState.targetCell else {
            swipeDeleteState.reset()
            return
        }
        let wasUnexclude = swipeDeleteState.targetIsTrashed
        cell.cancelDimmedAnimation {
            cell.isAnimating = false
            // 해제 취소: 그린 딤드 복구
            if wasUnexclude {
                cell.prepareSwipeOverlay(style: .restore)
                cell.setFullDimmed(isTrashed: false)
            }
        }
        swipeDeleteState.reset()
    }

    // MARK: - 단일 확정

    /// 단일 스와이프 확정 → 제외 또는 제외 해제
    private func confirmSingleSwipeExclude(cell: PhotoCell, indexPath: IndexPath) {
        guard case .photos(let candidates) = sectionType(for: indexPath.section),
              indexPath.item < candidates.count else {
            cancelSingleSwipe(cell: cell)
            return
        }

        let assetID = candidates[indexPath.item].assetID
        let wasExcluded = swipeDeleteState.targetIsTrashed  // true = 제외 해제 모드
        swipeDeleteState.reset()

        if wasExcluded {
            // 제외 해제: 그린 딤드 걷어내기 → 원래 사진으로 복귀
            cell.confirmDimmedAnimation(toTrashed: false) { [weak self] in
                cell.isAnimating = false
                self?.excludedAssetIDs.remove(assetID)
                self?.updateBottomView()
            }
        } else {
            // 제외: 그린 딤드 채우기
            cell.confirmDimmedAnimation(toTrashed: true) { [weak self] in
                cell.isAnimating = false
                self?.applySwipeExclusion(assetIDs: [assetID])
            }
        }

        HapticFeedback.light()
    }

    // MARK: - 단일 취소

    /// 단일 스와이프 취소 → spring 복귀
    private func cancelSingleSwipe(cell: PhotoCell) {
        let wasUnexclude = swipeDeleteState.targetIsTrashed
        cell.cancelDimmedAnimation {
            cell.isAnimating = false
            // 해제 취소: cancelDimmedAnimation이 딤드를 지우므로 그린 딤드 복구
            if wasUnexclude {
                cell.prepareSwipeOverlay(style: .restore)
                cell.setFullDimmed(isTrashed: false)
            }
        }
        swipeDeleteState.reset()
    }

    // MARK: - 제외 처리 (단일/다중 공통)

    /// assetID 제외 등록 + 버튼 텍스트 갱신 (reloadData 없음 — 셀은 그린 딤드로 남아있음)
    func applySwipeExclusion(assetIDs: [String]) {
        guard !assetIDs.isEmpty else { return }

        // 1. excludedAssetIDs에 등록 (previewResult는 변경하지 않음)
        for id in assetIDs { excludedAssetIDs.insert(id) }

        // 2. 버튼 텍스트 갱신 (실시간 카운트 반영)
        updateBottomView()

        // 3. [Analytics]
        analyticsExcludeCount += assetIDs.count

        // 전부 제외해도 그리드 유지 — 0장이면 버튼이 무반응, 사용자가 X로 나감
    }

    // MARK: - 스와이프 강제 취소 (stage 전환, viewWillAppear 등)

    /// 진행 중인 스와이프를 안전하게 취소
    func cancelActiveSwipeIfNeeded() {
        if swipeDeleteState.isMultiMode {
            cancelMultiSwipeDelete()
        } else if let cell = swipeDeleteState.targetCell {
            cell.cancelDimmedAnimation { cell.isAnimating = false }
            swipeDeleteState.reset()
        } else if swipeDeleteState.swipeGesture != nil && swipeDeleteState.angleCheckPassed {
            // targetCell이 이미 nil(weak ref 해제)된 경우
            swipeDeleteState.reset()
        }
    }

    // 전부 제외해도 그리드 유지 — "0장 삭제대기함 이동" 버튼은 무반응 (guard !assetIDs.isEmpty)
}

// MARK: - UIGestureRecognizerDelegate

extension PreviewGridViewController: UIGestureRecognizerDelegate {

    /// 스와이프 제스처 시작 조건 필터링
    /// - 스크롤 momentum 중 차단
    /// - photos 섹션 셀 위에서만 허용 (배너 차단)
    /// - velocity 기반 각도 35° 이내만 수락 (수직 스크롤과 분리)
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == swipeDeleteState.swipeGesture else { return true }

        // 스크롤 momentum 중이면 차단
        if collectionView.isDecelerating { return false }

        // 터치 위치에 photos 섹션 셀이 있는지 확인
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let location = pan.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              case .photos = sectionType(for: indexPath.section) else { return false }

        // velocity 기반 각도 힌트 (35° 이내만 수평 스와이프로 인정)
        let velocity = pan.velocity(in: collectionView)
        let angle = atan2(abs(velocity.y), abs(velocity.x))
        return angle < (35.0 * .pi / 180.0)
    }

    /// 스크롤과 스와이프 동시 인식 차단
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 스와이프 제스처와 다른 제스처의 동시 인식 차단
        if gestureRecognizer == swipeDeleteState.swipeGesture { return false }
        if otherGestureRecognizer == swipeDeleteState.swipeGesture { return false }
        return false
    }
}

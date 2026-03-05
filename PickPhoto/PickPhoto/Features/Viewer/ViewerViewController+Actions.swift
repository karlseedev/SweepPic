// ViewerViewController+Actions.swift
// 사용자 액션 처리 (삭제, 복구, 스와이프 삭제, 네비게이션, 닫기)
//
// ViewerViewController에서 분리된 extension
// 버튼 탭/스와이프 제스처 액션 및 사진 전환/닫기 메서드 모음

import UIKit
import AppCore
import OSLog

// MARK: - Actions

extension ViewerViewController {

    /// 뒤로가기 버튼 탭
    @objc func backButtonTapped() {
        dismissWithFadeOut()
    }

    /// 이전 사진 버튼 탭 (일반 모드)
    @objc func previousPhotoButtonTapped() {
        moveToPreviousPhoto()
    }

    /// 삭제 버튼 탭 (일반 모드)
    /// 현재 사진: 위로 올라가며 페이드아웃 + 다음 사진: 옆에서 슬라이드인 (동시 실행)
    @objc func deleteButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // [DeleteLag 측정] 햅틱 시간
        let tH0 = CACurrentMediaTime()

        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        let tH1 = CACurrentMediaTime()
        Logger.viewer.debug("[DeleteLag] buttonTap haptic=\(String(format: "%.1f", (tH1-tH0)*1000))ms")

        // [Analytics] 이벤트 4-1: 뷰어 삭제 버튼
        AnalyticsService.shared.countViewerTrashButton(source: coordinator.deleteSource)

        performDeleteWithSlideAnimation(assetID: assetID)
    }

    /// 복구 버튼 탭
    /// - .trash 모드: 다음 사진으로 이동 (목록에서 사라짐)
    /// - .normal 모드: 제자리 유지, 테두리 제거 + 버튼 교체
    @objc func restoreButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // [Analytics] 이벤트 4-1: 뷰어 복구 버튼
        AnalyticsService.shared.countViewerRestoreButton(source: coordinator.deleteSource)

        // 복구 요청
        delegate?.viewerDidRequestRestore(assetID: assetID)

        if viewerMode == .trash {
            // .trash 모드: 다음 사진으로 이동 (목록에서 사라짐)
            moveToNextAfterDelete()
        } else {
            // .normal 모드: 제자리에서 UI만 업데이트
            updateCurrentPageTrashedState(isTrashed: false)
            updateToolbarForCurrentPhoto()
        }
    }

    /// 최종 삭제 버튼 탭 (삭제대기함 모드)
    /// 주의: permanentDelete는 비동기 작업이므로 moveToNextAfterDelete()를 여기서 호출하지 않음
    /// 삭제 완료 후 delegate에서 handleDeleteComplete()를 호출해야 함
    @objc func permanentDeleteButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        // 최종 삭제 요청 (비동기 - iOS 시스템 팝업 대기)
        // 삭제 완료 후 delegate에서 handleDeleteComplete() 호출 필요
        delegate?.viewerDidRequestPermanentDelete(assetID: assetID)

        // 비동기 작업이므로 여기서 moveToNextAfterDelete() 호출하지 않음
        // TrashAlbumViewController에서 삭제 완료 후 handleDeleteComplete() 호출
    }

    /// 삭제 완료 후 호출 (외부에서 호출)
    /// permanentDelete가 비동기이므로 삭제 완료 후 이 메서드를 호출해야 함
    func handleDeleteComplete() {
        moveToNextAfterDelete()
    }

    // MARK: - Exclude (Cleanup Mode)

    /// 제외 버튼 탭 (정리 미리보기 모드)
    /// 실행 순서: removeAsset → moveToNextAfterDelete (인덱스 정합성 필수)
    @objc func excludeButtonTapped() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // 1. delegate에 제외 알림 (PreviewGridVC가 excludedAssetIDs에 기록)
        delegate?.viewerDidRequestExclude(assetID: assetID)

        // 2. 코디네이터에서 에셋 제거 (removeAsset 후 assets.count가 줄어듬)
        //    moveToNextAfterDelete()가 nextIndexAfterDelete()로 삭제 후 count 기준 계산하므로
        //    반드시 제거가 먼저 완료되어야 함
        (coordinator as? PreviewViewerCoordinator)?.removeAsset(id: assetID)

        // 3. 다음 사진으로 이동 (기존 메서드 재사용 — 모든 사진 제외 시 자동 닫힘)
        moveToNextAfterDelete()
    }

    // MARK: - Swipe Delete

    /// 위 스와이프 삭제 처리 (T030)
    /// 삭제 버튼과 동일한 모션 (위로 올라감 + 옆에서 슬라이드인)
    func handleSwipeDelete() {
        guard let assetID = coordinator.assetID(at: currentIndex) else { return }

        // [DeleteLag 측정] 햅틱 시간
        let tH0 = CACurrentMediaTime()

        // 햅틱 피드백
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        let tH1 = CACurrentMediaTime()
        Logger.viewer.debug("[DeleteLag] swipeDel haptic=\(String(format: "%.1f", (tH1-tH0)*1000))ms")

        // [Analytics] 이벤트 4-1: 뷰어 스와이프 삭제
        AnalyticsService.shared.countViewerSwipeDelete(source: coordinator.deleteSource)

        performDeleteWithSlideAnimation(assetID: assetID)
    }

    /// 삭제 후 다음 사진으로 즉시 전환 (애니메이션 없음)
    /// - Returns: 이동 방향 (.reverse = 이전 사진, .forward = 다음 사진), dismiss 시 nil
    @discardableResult
    func moveToNextAfterDeleteNoAnimation() -> UIPageViewController.NavigationDirection? {
        let nextIndex = coordinator.nextIndexAfterDelete(currentIndex: currentIndex)
        coordinator.refreshFilteredIndices()

        let newTotalCount = coordinator.totalCount
        if newTotalCount == 0 { dismissWithFadeOut(); return nil }
        guard nextIndex >= 0 && nextIndex < newTotalCount else { dismissWithFadeOut(); return nil }

        let direction: UIPageViewController.NavigationDirection = (nextIndex < currentIndex) ? .reverse : .forward
        currentIndex = nextIndex
        guard let pageVC = createPageViewController(at: currentIndex) else { dismissWithFadeOut(); return nil }

        // 애니메이션 없이 즉시 세팅 (스냅샷 뒤에서 대기)
        pageViewController.setViewControllers([pageVC], direction: .forward, animated: false)
        updateSimilarPhotoOverlay()
        scheduleLOD1Request()
        return direction
    }

    /// 삭제 후 다음 사진으로 이동 (빠른 슬라이드)
    /// "이전 사진 우선" 규칙 적용 (FR-013)
    /// 삭제 모션: 현재 사진 위로 올라감 + 다음 사진 옆에서 슬라이드인 (동시 실행)
    /// deleteButtonTapped, handleSwipeDelete 공통
    func performDeleteWithSlideAnimation(assetID: String) {
        let containerView = pageViewController.view!
        let width = containerView.bounds.width

        // [DeleteLag 측정] 구간별 타이밍
        let t0 = CACurrentMediaTime()

        // 1. 현재 사진 스냅샷 (위로 날릴 대상)
        guard let snapshot = containerView.snapshotView(afterScreenUpdates: false) else {
            delegate?.viewerDidRequestDelete(assetID: assetID)
            moveToNextAfterDelete()
            updateToolbarForCurrentPhoto()
            return
        }

        let t1 = CACurrentMediaTime()

        snapshot.frame = containerView.frame
        containerView.superview?.addSubview(snapshot)

        let t1b = CACurrentMediaTime()

        // 2. 삭제 요청 + 다음 사진을 즉시 세팅 (방향 정보 반환)
        delegate?.viewerDidRequestDelete(assetID: assetID)

        let t2 = CACurrentMediaTime()

        guard let direction = moveToNextAfterDeleteNoAnimation() else {
            snapshot.removeFromSuperview()
            return
        }

        let t3 = CACurrentMediaTime()
        let ms = { (d: Double) in String(format: "%.1f", d * 1000) }
        Logger.viewer.debug("[DeleteLag] snap=\(ms(t1-t0)) addSub=\(ms(t1b-t1)) delegate=\(ms(t2-t1b)) move=\(ms(t3-t2)) total=\(ms(t3-t0))ms")

        // 3. 다음 사진을 슬라이드 시작 위치로 이동
        let slideStartX: CGFloat = (direction == .reverse) ? -width : width
        containerView.transform = CGAffineTransform(translationX: slideStartX, y: 0)

        // 4. 동시 애니메이션 (0.2초)
        let totalDuration: TimeInterval = 0.2
        let fadeDelay = totalDuration * 0.3
        let fadeDuration = totalDuration * 0.7

        // 스냅샷: 위로 이동 + 다음 사진: 옆에서 슬라이드인
        UIView.animate(withDuration: totalDuration, delay: 0, options: .curveEaseOut, animations: {
            snapshot.transform = CGAffineTransform(translationX: 0, y: -500)
            containerView.transform = .identity
        }, completion: { [weak self] _ in
            snapshot.removeFromSuperview()
            self?.updateToolbarForCurrentPhoto()
        })

        // 스냅샷 페이드아웃 (30% 지점부터 시작)
        UIView.animate(withDuration: fadeDuration, delay: fadeDelay, options: .curveEaseIn, animations: {
            snapshot.alpha = 0
        })
    }

    // MARK: - Navigation

    func moveToNextAfterDelete() {
        // 다음 인덱스를 먼저 계산 (갱신 전 totalCount 기준)
        let nextIndex = coordinator.nextIndexAfterDelete(currentIndex: currentIndex)

        // filteredIndices 갱신 (삭제/복구 반영)
        coordinator.refreshFilteredIndices()

        let newTotalCount = coordinator.totalCount

        // 모든 사진이 삭제되면 닫기
        if newTotalCount == 0 {
            dismissWithFadeOut()
            return
        }

        // 범위 확인
        guard nextIndex >= 0 && nextIndex < newTotalCount else {
            dismissWithFadeOut()
            return
        }

        // 이동 방향 결정: 이전 사진으로 갔으면 reverse, 다음으로 갔으면 forward
        // (currentIndex 업데이트 전에 비교해야 함)
        let direction: UIPageViewController.NavigationDirection = (nextIndex < currentIndex) ? .reverse : .forward

        currentIndex = nextIndex

        // 새 뷰 컨트롤러 생성 및 표시 (사진/동영상)
        guard let pageVC = createPageViewController(at: currentIndex) else {
            dismissWithFadeOut()
            return
        }
        performFastSlideTransition(to: pageVC, direction: direction) { [weak self] in
            // 삭제 후 이동 시에도 유사 사진 오버레이 업데이트
            // (setViewControllers는 pageViewController delegate를 호출하지 않으므로 수동 호출)
            self?.updateSimilarPhotoOverlay()

            // Phase 2: LOD1 원본 이미지 요청 스케줄링
            self?.scheduleLOD1Request()
        }
    }

    /// 이전 사진으로 이동 (스냅샷 기반 빠른 슬라이드)
    func moveToPreviousPhoto() {
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return }
        guard let pageVC = createPageViewController(at: previousIndex) else { return }

        currentIndex = previousIndex
        performFastSlideTransition(to: pageVC, direction: .reverse) { [weak self] in
            self?.updateSimilarPhotoOverlay()
            self?.scheduleLOD1Request()
            self?.updateToolbarForCurrentPhoto()
        }
    }

    /// 스냅샷 기반 빠른 슬라이드 전환 (0.1초)
    /// UIPageViewController의 기본 전환은 CATransaction으로 제어 불가하므로,
    /// 스냅샷을 활용한 커스텀 슬라이드 애니메이션으로 대체
    /// - Parameters:
    ///   - viewController: 전환할 새 페이지 VC
    ///   - direction: 슬라이드 방향 (.forward = 오른쪽→왼쪽, .reverse = 왼쪽→오른쪽)
    ///   - completion: 전환 완료 후 콜백
    func performFastSlideTransition(
        to viewController: UIViewController,
        direction: UIPageViewController.NavigationDirection,
        completion: (() -> Void)? = nil
    ) {
        let containerView = pageViewController.view!
        let width = containerView.bounds.width

        // 현재 화면 스냅샷 (기존 사진)
        guard let snapshot = containerView.snapshotView(afterScreenUpdates: false) else {
            // 스냅샷 실패 시 애니메이션 없이 즉시 전환
            pageViewController.setViewControllers([viewController], direction: direction, animated: false)
            completion?()
            return
        }
        snapshot.frame = containerView.frame
        containerView.superview?.addSubview(snapshot)

        // 새 VC를 즉시 세팅 (애니메이션 없음)
        pageViewController.setViewControllers([viewController], direction: direction, animated: false)

        // 슬라이드 방향 계산 (reverse: 새 사진이 왼쪽에서, forward: 새 사진이 오른쪽에서)
        let newStartX: CGFloat = (direction == .reverse) ? -width : width
        let snapshotEndX: CGFloat = (direction == .reverse) ? width : -width

        // 새 콘텐츠를 방향에 맞게 오프스크린에서 시작
        containerView.transform = CGAffineTransform(translationX: newStartX, y: 0)

        // 빠른 슬라이드 애니메이션 (0.2초)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            containerView.transform = .identity
            snapshot.transform = CGAffineTransform(translationX: snapshotEndX, y: 0)
        }, completion: { _ in
            snapshot.removeFromSuperview()
            completion?()
        })
    }

    /// 첫 사진 여부에 따라 이전 사진 버튼 상태 업데이트
    func updatePreviousNavigationState() {
        let canMovePrevious = currentIndex > 0
        previousPhotoButton.isEnabled = canMovePrevious
        previousPhotoButton.alpha = canMovePrevious ? 1.0 : 0.45
        toolbarPreviousItem?.isEnabled = canMovePrevious
    }

    // MARK: - Dismiss Pan Gesture (T031)

    /// 아래 스와이프로 닫기 처리 (Interactive Dismiss)
    /// iOS 26+ (isPushed): Navigation Pop 경로
    /// iOS 16~25: Modal Dismiss 경로 (기존)
    @objc func handleDismissPan(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            guard !isDismissing else { return }
            isDismissing = true

            // [LiquidGlass 최적화] dismiss 드래그 시작 → MTKView pause
            LiquidGlassOptimizer.cancelIdleTimer()
            LiquidGlassOptimizer.optimize(in: view.window)

            if isPushed {
                // === iOS 26+ Navigation Pop 경로 ===
                guard let tbc = tabBarController as? TabBarController else {
                    navigationController?.popViewController(animated: true)
                    return
                }
                let ic = ZoomDismissalInteractionController()
                ic.sourceProvider = tbc.zoomSourceProvider
                ic.destinationProvider = tbc.zoomDestinationProvider
                ic.transitionMode = .navigation
                ic.onTransitionFinished = { [weak self, weak tbc] completed in
                    // IC 참조 정리
                    self?.activeInteractionController = nil
                    self?.activeTabBarController = nil
                    if !completed {
                        self?.isDismissing = false
                        tbc?.zoomInteractionController = nil  // retain cycle 방지
                        LiquidGlassOptimizer.restore(in: self?.view.window)
                        LiquidGlassOptimizer.enterIdle(in: self?.view.window)
                    }
                    // 완료 시: didShow → cleanupZoomTransition() 자동 호출
                }
                tbc.zoomInteractionController = ic
                tbc.isInteractivelyPopping = true

                // ⚠️ popViewController 후 navigationController가 nil이 되어
                //   isPushed/tabBarController 접근 불가 → IC/TBC 참조를 미리 저장
                self.activeInteractionController = ic
                self.activeTabBarController = tbc

                navigationController?.popViewController(animated: true)
            } else {
                // === iOS 16~25 Modal Dismiss 경로 (기존 코드) ===
                guard let tc = zoomTransitionController else {
                    dismissWithFadeOut()
                    return
                }
                let ic = ZoomDismissalInteractionController()
                ic.sourceProvider = tc.sourceProvider
                ic.destinationProvider = tc.destinationProvider
                ic.onTransitionFinished = { [weak self] completed in
                    // IC 참조 정리
                    self?.activeInteractionController = nil
                    if !completed {
                        self?.isDismissing = false
                        LiquidGlassOptimizer.restore(in: self?.view.window)
                        LiquidGlassOptimizer.enterIdle(in: self?.view.window)
                    }
                }
                tc.interactionController = ic
                tc.isInteractivelyDismissing = true

                // Modal 경로도 동일하게 IC 참조 저장 (일관성)
                self.activeInteractionController = ic

                dismiss(animated: true)
            }

        case .changed:
            // ⚠️ isPushed/tabBarController 대신 저장된 IC 참조 사용
            //   popViewController 후 navigationController가 nil이 되어 isPushed가 false 반환하므로
            activeInteractionController?.didPanWith(gestureRecognizer: gesture)

        case .ended, .cancelled:
            // ⚠️ 저장된 IC 참조로 제스처 전달
            activeInteractionController?.didPanWith(gestureRecognizer: gesture)
            // TabBarController의 isInteractivelyPopping 정리
            activeTabBarController?.isInteractivelyPopping = false
            // Modal 경로: isInteractivelyDismissing 정리
            zoomTransitionController?.isInteractivelyDismissing = false

        default:
            break
        }
    }

    /// 애니메이션과 함께 닫기 (Modal dismiss 또는 Navigation pop)
    func dismissWithAnimation() {
        guard !isDismissing else { return }
        isDismissing = true

        if isPushed {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }

    /// 페이드 아웃으로 닫기 (Modal dismiss 또는 Navigation pop)
    func dismissWithFadeOut() {
        guard !isDismissing else { return }
        isDismissing = true

        if isPushed {
            navigationController?.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }
    }
}

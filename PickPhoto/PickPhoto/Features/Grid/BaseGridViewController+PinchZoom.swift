// BaseGridViewController+PinchZoom.swift
// virtualColumns 기반 연속 핀치줌 구현
//
// 핵심 기능:
// - 부드러운 연속 줌 (1.0 ~ 5.0 virtualColumns)
// - 앵커 기반 스크롤 위치 고정
// - 다단계 fadeIn (기준점 통과 시)
// - 10%/50% 스냅 규칙
//
// 주의사항 (롤백 피드백 반영):
// 1. 좌표계 통일: bounds → content 변환 필수
// 2. paddingCellCount: 핀치 중 고정, 스냅 완료 후에만 업데이트
// 3. frozenItemCount: 핀치 중 numberOfItems 캐시 문제 방지

import UIKit
import Photos
import AppCore

// MARK: - Zoom Direction

/// 줌 방향 열거형
enum ZoomDirection {
    case zoomIn   // 확대 (열 수 감소)
    case zoomOut  // 축소 (열 수 증가)
}

// MARK: - Pinch Zoom State

/// 핀치줌 상태 관리
struct PinchZoomState {
    /// 핀치 활성화 여부
    var isActive = false

    /// 핀치 시작 시 열 수 (기준점)
    var baseColumns: CGFloat = 3.0

    /// 이전 프레임의 virtualColumns (기준점 통과 감지용)
    var previousVirtualColumns: CGFloat = 3.0

    /// 현재 목표 열 수 (fadeIn 타겟)
    var currentTargetColumns: GridColumnCount?

    /// 초기 줌 방향 (첫 프레임에서 결정)
    var initialDirection: ZoomDirection?

    /// 방향 전환 여부 (10%/50% 규칙 적용)
    var didReverse = false

    /// 초기 fadeIn 발생 여부
    var hasFiredInitialFadeIn = false

    // MARK: - Anchor Properties

    /// 앵커 에셋 ID (핀치 중 고정할 셀)
    var anchorAssetID: String?

    /// 앵커의 화면상 위치 (bounds 좌표)
    var anchorPointInView: CGPoint = .zero

    // MARK: - Frozen Properties (핀치 중 변경 금지)

    /// 핀치 시작 시 패딩 셀 개수
    var frozenPaddingCellCount: Int = 0

    /// 핀치 시작 시 아이템 수
    var frozenItemCount: Int = 0

    /// 상태 초기화
    mutating func reset() {
        self = PinchZoomState()
    }
}

// MARK: - BaseGridViewController + PinchZoom Extension

extension BaseGridViewController {

    // MARK: - Layout Access

    /// ContinuousGridLayout 접근자
    /// - nil이면 아직 ContinuousGridLayout으로 전환되지 않은 상태
    var continuousLayout: ContinuousGridLayout? {
        return collectionView.collectionViewLayout as? ContinuousGridLayout
    }

    // MARK: - Pinch Gesture Handling

    /// 핀치 시작 처리 (.began)
    func handleContinuousPinchBegan(_ gesture: UIPinchGestureRecognizer) {
        guard let layout = continuousLayout else { return }

        // 스냅 애니메이션 취소
        cancelSnapAnimation()

        // 상태 초기화
        var state = PinchZoomState()
        state.isActive = true
        state.baseColumns = CGFloat(currentGridColumnCount.rawValue)
        state.previousVirtualColumns = state.baseColumns

        // 핀치 중 변경 금지 - 시작 시점 값 고정
        state.frozenPaddingCellCount = paddingCellCount
        state.frozenItemCount = collectionView.numberOfItems(inSection: 0)

        // 레이아웃에 frozen 값 설정
        layout.paddingCellCount = state.frozenPaddingCellCount
        layout.frozenItemCount = state.frozenItemCount

        // 앵커 결정 - 좌표계 변환 필수!
        let locationInBounds = gesture.location(in: collectionView)
        let locationInContent = CGPoint(
            x: locationInBounds.x + collectionView.contentOffset.x,
            y: locationInBounds.y + collectionView.contentOffset.y
        )

        state.anchorPointInView = locationInBounds  // bounds 좌표 저장
        state.anchorAssetID = resolveAnchorAssetID(at: locationInContent, state: state)

        // 상태 저장
        pinchZoomState = state
    }

    /// 핀치 진행 처리 (.changed)
    func handleContinuousPinchChanged(_ gesture: UIPinchGestureRecognizer) {
        guard var state = pinchZoomState, state.isActive else { return }
        guard let layout = continuousLayout else { return }

        let scale = gesture.scale

        // virtualColumns 계산 (클램프 적용)
        // scale > 1: 확대 → 열 수 감소
        // scale < 1: 축소 → 열 수 증가
        let rawVirtualColumns = state.baseColumns / scale
        let virtualColumns = min(max(rawVirtualColumns, 0.8), 5.2)

        // 레이아웃 업데이트
        layout.virtualColumns = virtualColumns
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()

        // 앵커 고정
        updateContentOffsetForAnchor(state: state)

        // 첫 프레임에서 방향 결정 후 fadeIn
        if !state.hasFiredInitialFadeIn && abs(scale - 1.0) > 0.01 {
            state.initialDirection = (scale > 1.0) ? .zoomIn : .zoomOut
            let target = inferTargetColumns(from: state.initialDirection!, base: currentGridColumnCount)
            state.currentTargetColumns = target
            triggerFadeIn(target: target, state: state)
            state.hasFiredInitialFadeIn = true
        }

        // 방향 전환 추적
        updateDirectionState(virtualColumns: virtualColumns, state: &state)

        // 기준점 통과 감지 → 다단계 fadeIn
        let crossed = detectCrossedThresholds(
            prev: state.previousVirtualColumns,
            cur: virtualColumns
        )
        for threshold in crossed {
            if let target = GridColumnCount(rawValue: threshold),
               state.currentTargetColumns != target {
                state.currentTargetColumns = target
                triggerFadeIn(target: target, state: state)
            }
        }

        state.previousVirtualColumns = virtualColumns

        // 상태 저장
        pinchZoomState = state
    }

    /// 핀치 종료 처리 (.ended)
    func handleContinuousPinchEnded(_ gesture: UIPinchGestureRecognizer) {
        guard let state = pinchZoomState, state.isActive else { return }

        let finalTarget = decideSnapTarget(state: state)

        animateToTargetColumns(finalTarget, state: state) { [weak self] in
            guard let self = self else { return }
            guard let layout = self.continuousLayout else { return }

            // 스냅 완료 후에만 paddingCellCount 업데이트
            let newPadding = self.calculatePaddingCellCount(for: finalTarget.rawValue)
            if layout.paddingCellCount != newPadding {
                layout.paddingCellCount = newPadding
                // frozenItemCount 해제
                layout.frozenItemCount = 0
                self.collectionView.reloadData()
            } else {
                // frozenItemCount만 해제
                layout.frozenItemCount = 0
            }

            self.currentGridColumnCount = finalTarget
            self.didPerformZoom(to: finalTarget)
        }

        // 상태 초기화 (애니메이션 중에도 새 핀치 가능하도록)
        pinchZoomState?.isActive = false
    }

    // MARK: - Anchor Resolution

    /// 앵커 에셋 ID 해결
    /// - Parameter locationInContent: content 좌표 (bounds가 아닌!)
    /// - Returns: 앵커로 사용할 에셋 ID
    func resolveAnchorAssetID(at locationInContent: CGPoint, state: PinchZoomState) -> String? {
        let padding = state.frozenPaddingCellCount

        // 1) 핀치 위치에서 직접 찾기
        if let indexPath = collectionView.indexPathForItem(at: locationInContent),
           indexPath.item >= padding {
            return assetID(for: indexPath, padding: padding)
        }

        // 2) 화면 중앙으로 fallback
        let centerInContent = CGPoint(
            x: collectionView.bounds.midX + collectionView.contentOffset.x,
            y: collectionView.bounds.midY + collectionView.contentOffset.y
        )

        // anchorPointInView도 동기화 (중앙으로 변경)
        pinchZoomState?.anchorPointInView = CGPoint(
            x: collectionView.bounds.midX,
            y: collectionView.bounds.midY
        )

        if let indexPath = collectionView.indexPathForItem(at: centerInContent),
           indexPath.item >= padding {
            return assetID(for: indexPath, padding: padding)
        }

        // 3) visible 셀 중 가장 가까운 셀
        let visible = collectionView.indexPathsForVisibleItems
            .filter { $0.item >= padding }

        guard let nearest = visible.min(by: { a, b in
            let centerA = collectionView.layoutAttributesForItem(at: a)?.center ?? .zero
            let centerB = collectionView.layoutAttributesForItem(at: b)?.center ?? .zero
            return distance(centerA, centerInContent) < distance(centerB, centerInContent)
        }) else {
            return nil
        }

        return assetID(for: nearest, padding: padding)
    }

    /// indexPath에서 assetID 추출
    private func assetID(for indexPath: IndexPath, padding: Int) -> String? {
        let assetIndex = indexPath.item - padding
        guard assetIndex >= 0 else { return nil }
        return gridDataSource.assetID(at: assetIndex)
    }

    /// 두 점 사이 거리 계산
    private func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x
        let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }

    // MARK: - Anchor-based Content Offset

    /// 앵커 기반 contentOffset 보정
    func updateContentOffsetForAnchor(state: PinchZoomState) {
        guard let assetID = state.anchorAssetID else { return }

        let padding = state.frozenPaddingCellCount
        guard let indexPath = indexPath(for: assetID, padding: padding),
              let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
            return
        }

        let anchorCenter = attributes.center
        let anchorPoint = state.anchorPointInView

        let newOffset = CGPoint(
            x: anchorCenter.x - anchorPoint.x,
            y: anchorCenter.y - anchorPoint.y
        )

        collectionView.contentOffset = clampOffset(newOffset)
    }

    /// assetID에서 indexPath 변환
    private func indexPath(for assetID: String, padding: Int) -> IndexPath? {
        guard let assetIndex = gridDataSource.assetIndex(for: assetID) else { return nil }
        return IndexPath(item: assetIndex + padding, section: 0)
    }

    /// contentOffset 클램핑
    private func clampOffset(_ offset: CGPoint) -> CGPoint {
        let contentSize = collectionView.contentSize
        let boundsSize = collectionView.bounds.size
        let inset = collectionView.adjustedContentInset

        let maxX = max(0, contentSize.width - boundsSize.width + inset.right)
        let maxY = max(0, contentSize.height - boundsSize.height + inset.bottom)

        return CGPoint(
            x: min(max(offset.x, -inset.left), maxX),
            y: min(max(offset.y, -inset.top), maxY)
        )
    }

    // MARK: - Direction Tracking

    /// 현재 이동 방향 계산
    private func currentDirection(virtualColumns: CGFloat, state: PinchZoomState) -> ZoomDirection {
        if virtualColumns < state.previousVirtualColumns {
            return .zoomIn   // 열 수 감소 = 확대
        } else {
            return .zoomOut  // 열 수 증가 = 축소
        }
    }

    /// 방향 전환 추적
    private func updateDirectionState(virtualColumns: CGFloat, state: inout PinchZoomState) {
        guard let initialDirection = state.initialDirection else { return }

        let current = currentDirection(virtualColumns: virtualColumns, state: state)

        // 초기 방향과 현재 방향이 다르면 방향 전환
        if current != initialDirection && !state.didReverse {
            state.didReverse = true
        }
    }

    // MARK: - Threshold Detection

    /// 기준점 통과 감지
    func detectCrossedThresholds(prev: CGFloat, cur: CGFloat) -> [Int] {
        let thresholds = [1, 3, 5]

        if cur < prev {
            // 확대 방향 (열 수 감소)
            return thresholds
                .filter { CGFloat($0) <= prev && CGFloat($0) >= cur }
                .sorted(by: >)
        } else {
            // 축소 방향 (열 수 증가)
            return thresholds
                .filter { CGFloat($0) >= prev && CGFloat($0) <= cur }
                .sorted(by: <)
        }
    }

    // MARK: - Target Inference

    /// 목표 열 수 추론
    func inferTargetColumns(from direction: ZoomDirection, base: GridColumnCount) -> GridColumnCount {
        let thresholds = [1, 3, 5]
        guard let index = thresholds.firstIndex(of: base.rawValue) else {
            return base
        }

        switch direction {
        case .zoomIn:  // 확대 → 열 수 감소
            return GridColumnCount(rawValue: thresholds[max(0, index - 1)]) ?? base
        case .zoomOut: // 축소 → 열 수 증가
            return GridColumnCount(rawValue: thresholds[min(thresholds.count - 1, index + 1)]) ?? base
        }
    }

    // MARK: - Snap Decision

    /// 스냅 대상 결정 (10%/50% 규칙)
    func decideSnapTarget(state: PinchZoomState) -> GridColumnCount {
        let progress = computeStageProgress(state: state)

        if state.didReverse {
            // 방향 전환: 50% 규칙
            return progress >= 0.5 ? stageTarget(state: state) : stageBase(state: state)
        } else {
            // 단방향: 10% 규칙
            return progress >= 0.1 ? stageTarget(state: state) : stageBase(state: state)
        }
    }

    /// 현재 단계의 base (시작점) 열 수 반환
    func stageBase(state: PinchZoomState) -> GridColumnCount {
        let thresholds = [1, 3, 5]
        guard let layout = continuousLayout else { return currentGridColumnCount }
        let current = layout.virtualColumns

        if let direction = state.initialDirection {
            switch direction {
            case .zoomIn:  // 확대 (열 수 감소 방향)
                // 현재 위치보다 큰 기준점 중 가장 작은 것
                if let base = thresholds.filter({ CGFloat($0) >= current }).min() {
                    return GridColumnCount(rawValue: base) ?? currentGridColumnCount
                }
            case .zoomOut: // 축소 (열 수 증가 방향)
                // 현재 위치보다 작은 기준점 중 가장 큰 것
                if let base = thresholds.filter({ CGFloat($0) <= current }).max() {
                    return GridColumnCount(rawValue: base) ?? currentGridColumnCount
                }
            }
        }

        return currentGridColumnCount
    }

    /// 현재 단계의 target (목표) 열 수 반환
    func stageTarget(state: PinchZoomState) -> GridColumnCount {
        let thresholds = [1, 3, 5]
        guard let layout = continuousLayout else { return currentGridColumnCount }
        let current = layout.virtualColumns

        guard let direction = state.initialDirection else {
            return currentGridColumnCount
        }

        switch direction {
        case .zoomIn:  // 확대 (열 수 감소 방향)
            // 현재 위치보다 작은 기준점 중 가장 큰 것
            if let target = thresholds.filter({ CGFloat($0) < current }).max() {
                return GridColumnCount(rawValue: target) ?? .one
            }
            return .one
        case .zoomOut: // 축소 (열 수 증가 방향)
            // 현재 위치보다 큰 기준점 중 가장 작은 것
            if let target = thresholds.filter({ CGFloat($0) > current }).min() {
                return GridColumnCount(rawValue: target) ?? .five
            }
            return .five
        }
    }

    /// 현재 단계 진행도 계산
    func computeStageProgress(state: PinchZoomState) -> CGFloat {
        let base = CGFloat(stageBase(state: state).rawValue)
        let target = CGFloat(stageTarget(state: state).rawValue)
        guard let layout = continuousLayout else { return 0 }
        let current = layout.virtualColumns

        let range = target - base
        guard range != 0 else { return 0 }

        let raw = (current - base) / range
        return min(max(raw, 0), 1)
    }

    // MARK: - Padding Calculation

    /// 열 수에 따른 paddingCellCount 계산
    func calculatePaddingCellCount(for columns: Int) -> Int {
        let totalCount = gridDataSource.assetCount
        guard totalCount > 0 else { return 0 }
        let remainder = totalCount % columns
        return remainder == 0 ? 0 : (columns - remainder)
    }
}

// MARK: - Snap Animation

extension BaseGridViewController {

    // MARK: - Animation Properties

    /// DisplayLink (스냅 애니메이션용)
    private static var displayLinkKey: UInt8 = 0
    private static var animStartTimeKey: UInt8 = 0
    private static var animStartValueKey: UInt8 = 0
    private static var animTargetValueKey: UInt8 = 0
    private static var animCompletionKey: UInt8 = 0
    private static var animStateKey: UInt8 = 0

    var snapDisplayLink: CADisplayLink? {
        get { objc_getAssociatedObject(self, &Self.displayLinkKey) as? CADisplayLink }
        set { objc_setAssociatedObject(self, &Self.displayLinkKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var snapAnimStartTime: CFTimeInterval {
        get { (objc_getAssociatedObject(self, &Self.animStartTimeKey) as? NSNumber)?.doubleValue ?? 0 }
        set { objc_setAssociatedObject(self, &Self.animStartTimeKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var snapAnimStartValue: CGFloat {
        get { (objc_getAssociatedObject(self, &Self.animStartValueKey) as? NSNumber)?.doubleValue ?? 0 }
        set { objc_setAssociatedObject(self, &Self.animStartValueKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var snapAnimTargetValue: CGFloat {
        get { (objc_getAssociatedObject(self, &Self.animTargetValueKey) as? NSNumber)?.doubleValue ?? 0 }
        set { objc_setAssociatedObject(self, &Self.animTargetValueKey, NSNumber(value: newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var snapAnimCompletion: (() -> Void)? {
        get { objc_getAssociatedObject(self, &Self.animCompletionKey) as? () -> Void }
        set { objc_setAssociatedObject(self, &Self.animCompletionKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    var snapAnimState: PinchZoomState? {
        get { objc_getAssociatedObject(self, &Self.animStateKey) as? PinchZoomState }
        set { objc_setAssociatedObject(self, &Self.animStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 목표 열 수로 애니메이션
    func animateToTargetColumns(_ target: GridColumnCount, state: PinchZoomState, completion: @escaping () -> Void) {
        guard let layout = continuousLayout else {
            completion()
            return
        }

        let targetValue = CGFloat(target.rawValue)

        // 이미 도달했으면 즉시 완료
        if abs(layout.virtualColumns - targetValue) < 0.01 {
            layout.snapToColumns(target)
            completion()
            return
        }

        snapAnimStartValue = layout.virtualColumns
        snapAnimTargetValue = targetValue
        snapAnimStartTime = CACurrentMediaTime()
        snapAnimCompletion = completion
        snapAnimState = state

        snapDisplayLink?.invalidate()
        snapDisplayLink = CADisplayLink(target: self, selector: #selector(snapAnimationTick))
        snapDisplayLink?.add(to: .main, forMode: .common)
    }

    /// 스냅 애니메이션 틱
    @objc private func snapAnimationTick() {
        let duration: CFTimeInterval = 0.25
        let elapsed = CACurrentMediaTime() - snapAnimStartTime
        let progress = min(elapsed / duration, 1.0)

        // easeOut 곡선
        let eased = 1 - pow(1 - progress, 3)

        let newValue = snapAnimStartValue + (snapAnimTargetValue - snapAnimStartValue) * CGFloat(eased)

        guard let layout = continuousLayout else { return }
        layout.virtualColumns = newValue
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()

        // 앵커 유지
        if let state = snapAnimState {
            updateContentOffsetForAnchor(state: state)
        }

        if progress >= 1.0 {
            snapDisplayLink?.invalidate()
            snapDisplayLink = nil

            // 정확한 값으로 스냅
            if let target = GridColumnCount(rawValue: Int(snapAnimTargetValue)) {
                layout.snapToColumns(target)
            }

            snapAnimCompletion?()
            snapAnimCompletion = nil
            snapAnimState = nil
        }
    }

    /// 스냅 애니메이션 취소
    func cancelSnapAnimation() {
        snapDisplayLink?.invalidate()
        snapDisplayLink = nil
        snapAnimCompletion = nil
        snapAnimState = nil
    }
}

// MARK: - FadeIn Support

extension BaseGridViewController {

    /// 가시 사진 셀 배열 반환 (padding 제외)
    func visiblePhotoCells(state: PinchZoomState) -> [PhotoCell] {
        let padding = state.frozenPaddingCellCount

        return collectionView.visibleCells.compactMap { cell -> PhotoCell? in
            guard let photoCell = cell as? PhotoCell else { return nil }

            // indexPath 확인하여 padding 셀 제외
            if let indexPath = collectionView.indexPath(for: cell),
               indexPath.item < padding {
                return nil
            }

            return photoCell
        }
    }

    /// fadeIn 트리거
    func triggerFadeIn(target: GridColumnCount, state: PinchZoomState) {
        guard let layout = continuousLayout else { return }

        let targetSize = thumbnailSize(for: target, layout: layout)
        let token = UUID().uuidString
        let requestedTarget = target

        for cell in visiblePhotoCells(state: state) {
            guard cell.currentAssetID != state.anchorAssetID else { continue }
            guard let assetID = cell.currentAssetID else { continue }

            // assetID에서 PHAsset 가져오기
            guard let assetIndex = gridDataSource.assetIndex(for: assetID),
                  let asset = gridDataSource.asset(at: assetIndex) else {
                continue
            }

            cell.fadeToken = token

            _ = imagePipeline.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                quality: .high
            ) { [weak cell, weak self] image, isDegraded in
                guard let cell = cell, let self = self else { return }
                guard cell.fadeToken == token else { return }
                guard self.pinchZoomState?.currentTargetColumns == requestedTarget else { return }
                guard let image = image, !isDegraded else { return }

                cell.fadeInImage(image)
            }
        }
    }

    /// 목표 열 수에 따른 썸네일 크기 계산
    func thumbnailSize(for columns: GridColumnCount, layout: ContinuousGridLayout) -> CGSize {
        let cellSize = layout.cellSize(for: columns)
        let scale = UIScreen.main.scale
        return CGSize(width: cellSize.width * scale, height: cellSize.height * scale)
    }
}

// MARK: - Pinch State Storage

extension BaseGridViewController {

    private static var pinchZoomStateKey: UInt8 = 0

    /// 핀치줌 상태 저장소
    var pinchZoomState: PinchZoomState? {
        get {
            objc_getAssociatedObject(self, &Self.pinchZoomStateKey) as? PinchZoomState
        }
        set {
            objc_setAssociatedObject(self, &Self.pinchZoomStateKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }
}

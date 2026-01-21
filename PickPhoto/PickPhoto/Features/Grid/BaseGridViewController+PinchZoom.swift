// BaseGridViewController+PinchZoom.swift
// 연속 핀치줌 구현 (virtualColumns 기반)
//
// docs/260121zoom3.md 기반 구현:
// - virtualColumns: CGFloat로 연속적인 열 수 변화
// - 앵커 셀 고정 contentOffset 보정
// - 10%/50% 스냅 규칙
// - CADisplayLink 기반 마무리 애니메이션
// - fadeIn 트리거 (기준점 통과 시)

import UIKit

// MARK: - ZoomDirection

/// 줌 방향
enum ZoomDirection {
    case zoomIn   // 확대 (열 수 감소)
    case zoomOut  // 축소 (열 수 증가)
}

// MARK: - PinchZoomState

/// 핀치줌 상태
struct PinchZoomState {
    /// 핀치 활성화 여부
    var isActive = false

    /// 핀치 시작 시 열 수 (기준)
    var baseColumns: CGFloat = 3.0

    /// 이전 프레임의 virtualColumns (기준점 통과 감지용)
    var previousVirtualColumns: CGFloat = 3.0

    /// 현재 단계의 목표 열 수 (fadeIn 중복 방지용)
    var currentTargetColumns: GridColumnCount?

    /// 초기 줌 방향
    var initialDirection: ZoomDirection?

    /// 방향 전환 여부 (50% 규칙 적용 조건)
    var didReverse = false

    /// 앵커 에셋 ID
    var anchorAssetID: String?

    /// 핀치 시작 시 앵커 위치 (뷰 좌표)
    var anchorPointInView: CGPoint = .zero

    /// 첫 fadeIn 트리거 여부 (.changed 첫 프레임용)
    var hasFiredInitialFadeIn = false

    /// 현재 단계의 시작 열 수 (progress 계산용)
    var stageBase: CGFloat = 3.0

    /// 현재 단계의 목표 열 수 (progress 계산용)
    var stageTarget: CGFloat = 1.0
}

// MARK: - BaseGridViewController Pinch Extension

extension BaseGridViewController {

    // MARK: - Properties (연관 객체로 저장)

    /// ContinuousGridLayout 접근자
    var continuousLayout: ContinuousGridLayout? {
        collectionView.collectionViewLayout as? ContinuousGridLayout
    }

    /// 핀치줌 상태 저장 키
    private static var pinchStateKey: UInt8 = 0

    /// 핀치줌 상태
    var pinchZoomState: PinchZoomState {
        get {
            (objc_getAssociatedObject(self, &Self.pinchStateKey) as? PinchZoomStateBox)?.state ?? PinchZoomState()
        }
        set {
            objc_setAssociatedObject(self, &Self.pinchStateKey, PinchZoomStateBox(newValue), .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 스냅 애니메이션 DisplayLink 키
    private static var displayLinkKey: UInt8 = 0

    /// 스냅 애니메이션 상태 키
    private static var snapAnimationKey: UInt8 = 0

    /// 스냅 애니메이션 상태
    private var snapAnimationState: SnapAnimationState? {
        get {
            objc_getAssociatedObject(self, &Self.snapAnimationKey) as? SnapAnimationState
        }
        set {
            objc_setAssociatedObject(self, &Self.snapAnimationKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Continuous Pinch Handler

    /// 연속 핀치줌 제스처 처리 (새 구현)
    /// 기존 handlePinchGesture를 대체
    func handleContinuousPinch(_ gesture: UIPinchGestureRecognizer) {
        guard let layout = continuousLayout else {
            // ContinuousGridLayout이 아니면 기존 방식 사용
            handlePinchGesture(gesture)
            return
        }

        switch gesture.state {
        case .began:
            handlePinchBegan(gesture, layout: layout)

        case .changed:
            handlePinchChanged(gesture, layout: layout)

        case .ended, .cancelled:
            handlePinchEnded(gesture, layout: layout)

        default:
            break
        }
    }

    // MARK: - Pinch State Handlers

    /// 핀치 시작
    private func handlePinchBegan(_ gesture: UIPinchGestureRecognizer, layout: ContinuousGridLayout) {
        // 진행 중인 스냅 애니메이션 취소
        cancelSnapAnimation()

        var state = PinchZoomState()
        state.isActive = true
        state.baseColumns = layout.virtualColumns
        state.previousVirtualColumns = layout.virtualColumns
        state.stageBase = layout.virtualColumns

        // 앵커 결정 (핀치 중심점)
        // visible 셀 기반으로 찾으므로 bounds 좌표 그대로 사용
        let locationInBounds = gesture.location(in: collectionView)
        state.anchorPointInView = locationInBounds
        state.anchorAssetID = resolveAnchorAssetID(at: locationInBounds)

        // 앵커를 못 찾으면 화면 중앙으로 fallback
        if state.anchorAssetID == nil {
            let centerInBounds = CGPoint(x: collectionView.bounds.midX, y: collectionView.bounds.midY)
            state.anchorAssetID = resolveAnchorAssetID(at: centerInBounds)
            state.anchorPointInView = centerInBounds
        }

        pinchZoomState = state

        print("[PinchZoom] Began: baseColumns=\(state.baseColumns), anchor=\(state.anchorAssetID?.prefix(8) ?? "nil")")
    }

    /// 핀치 진행 중
    private func handlePinchChanged(_ gesture: UIPinchGestureRecognizer, layout: ContinuousGridLayout) {
        var state = pinchZoomState
        guard state.isActive else { return }

        let scale = gesture.scale

        // virtualColumns 계산 (클램프 적용)
        let rawVirtualColumns = state.baseColumns / scale
        let virtualColumns = min(max(rawVirtualColumns, ContinuousGridLayout.minVirtualColumns),
                                  ContinuousGridLayout.maxVirtualColumns)

        // 레이아웃 업데이트
        // 핀치 중에는 paddingCellCount 고정 (스냅 완료 시에만 업데이트)
        // 이유: paddingCellCount 변경 시 numberOfItems와 불일치 발생 → indexPath 매핑 오류
        layout.virtualColumns = virtualColumns
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()

        // 앵커 고정 (contentOffset 보정)
        updateContentOffsetForAnchor(
            anchorAssetID: state.anchorAssetID,
            anchorPointInView: state.anchorPointInView,
            layout: layout
        )

        // 첫 프레임에서 방향 결정 후 fadeIn 트리거
        if !state.hasFiredInitialFadeIn {
            if abs(scale - 1.0) > 0.01 {
                state.initialDirection = (scale > 1.0) ? .zoomIn : .zoomOut
                let initialTarget = inferTargetColumns(
                    fromDirection: state.initialDirection!,
                    baseColumns: currentGridColumnCount
                )
                state.currentTargetColumns = initialTarget
                state.stageTarget = CGFloat(initialTarget.rawValue)
                triggerFadeIn(target: initialTarget, anchorAssetID: state.anchorAssetID)
                state.hasFiredInitialFadeIn = true

                print("[PinchZoom] Direction decided: \(state.initialDirection!), target=\(initialTarget.rawValue)")
            }
        }

        // 방향 전환 감지
        if let initialDir = state.initialDirection {
            let currentDir: ZoomDirection = (virtualColumns < state.previousVirtualColumns) ? .zoomIn : .zoomOut
            if currentDir != initialDir && !state.didReverse {
                state.didReverse = true
                state.currentTargetColumns = nil  // 방향 전환 시 리셋
                print("[PinchZoom] Direction reversed")
            }
        }

        // 기준점 통과 감지 (다단계)
        let crossed = detectCrossedThresholds(
            prev: state.previousVirtualColumns,
            cur: virtualColumns,
            thresholds: [1, 3, 5]
        )
        for threshold in crossed {
            if let target = GridColumnCount(rawValue: Int(threshold)) {
                if state.currentTargetColumns != target {
                    state.currentTargetColumns = target
                    state.stageBase = state.previousVirtualColumns
                    state.stageTarget = CGFloat(target.rawValue)
                    triggerFadeIn(target: target, anchorAssetID: state.anchorAssetID)

                    print("[PinchZoom] Crossed threshold: \(threshold), fadeIn triggered")
                }
            }
        }

        state.previousVirtualColumns = virtualColumns
        pinchZoomState = state
    }

    /// 핀치 종료
    private func handlePinchEnded(_ gesture: UIPinchGestureRecognizer, layout: ContinuousGridLayout) {
        var state = pinchZoomState
        guard state.isActive else { return }

        // 스냅 목표 결정 (10%/50% 규칙)
        let finalTarget = decideSnapTarget(using: state, currentVirtualColumns: layout.virtualColumns)

        print("[PinchZoom] Ended: current=\(layout.virtualColumns), target=\(finalTarget.rawValue), didReverse=\(state.didReverse)")

        // 스냅 애니메이션 시작
        animateToTargetColumns(finalTarget, layout: layout, state: state) { [weak self] in
            guard let self = self else { return }
            self.currentGridColumnCount = finalTarget
            self.didPerformZoom(to: finalTarget)
        }

        // 상태 초기화
        state.isActive = false
        pinchZoomState = state
    }

    // MARK: - Anchor Resolution

    /// 앵커 에셋 ID 찾기 (visible 셀 기반)
    /// - Parameter locationInBounds: bounds 좌표계 기준 위치 (화면상 터치 위치)
    /// - Note: indexPathForItem(at:) 대신 visible 셀에서 직접 찾아 좌표 변환 문제 회피
    func resolveAnchorAssetID(at locationInBounds: CGPoint) -> String? {
        // visible 셀 중 터치 위치에 가장 가까운 셀 찾기
        // cell.center는 collectionView의 bounds 좌표이므로 locationInBounds와 직접 비교 가능
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? PhotoCell }
        guard !visibleCells.isEmpty else {
            print("[PinchZoom] resolveAnchor: No visible cells")
            return nil
        }

        let nearest = visibleCells.min { cellA, cellB in
            // convert to collectionView coordinate
            let centerA = cellA.center
            let centerB = cellB.center
            let distA = hypot(centerA.x - locationInBounds.x, centerA.y - locationInBounds.y)
            let distB = hypot(centerB.x - locationInBounds.x, centerB.y - locationInBounds.y)
            return distA < distB
        }

        let assetID = nearest?.currentAssetID
        print("[PinchZoom] resolveAnchor: found \(assetID?.prefix(8) ?? "nil") at \(locationInBounds)")
        return assetID
    }

    // MARK: - Content Offset Correction

    /// 앵커 셀 고정을 위한 contentOffset 보정
    func updateContentOffsetForAnchor(
        anchorAssetID: String?,
        anchorPointInView: CGPoint,
        layout: ContinuousGridLayout
    ) {
        guard let assetID = anchorAssetID,
              let indexPath = collectionIndexPathForContinuousLayout(for: assetID, layout: layout),
              let attributes = layout.layoutAttributesForItem(at: indexPath) else { return }

        let anchorCenterInContent = attributes.center
        let newOffset = CGPoint(
            x: anchorCenterInContent.x - anchorPointInView.x,
            y: anchorCenterInContent.y - anchorPointInView.y
        )
        collectionView.contentOffset = clampOffset(newOffset)
    }

    /// contentOffset 범위 제한
    func clampOffset(_ offset: CGPoint) -> CGPoint {
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

    /// ContinuousLayout용 assetID → indexPath 변환
    func collectionIndexPathForContinuousLayout(for assetID: String, layout: ContinuousGridLayout) -> IndexPath? {
        guard let assetIndex = gridDataSource.assetIndex(for: assetID) else { return nil }
        return IndexPath(item: assetIndex + layout.paddingCellCount, section: 0)
    }

    // MARK: - Threshold Detection

    /// 기준점 통과 감지 (다단계 지원)
    func detectCrossedThresholds(prev: CGFloat, cur: CGFloat, thresholds: [CGFloat]) -> [CGFloat] {
        if cur < prev {
            // 열 수 감소 (확대)
            return thresholds.filter { $0 <= prev && $0 >= cur }.sorted(by: >)
        } else {
            // 열 수 증가 (축소)
            return thresholds.filter { $0 >= prev && $0 <= cur }.sorted(by: <)
        }
    }

    // MARK: - Target Inference

    /// 방향 기반 목표 열 수 추론
    func inferTargetColumns(fromDirection direction: ZoomDirection, baseColumns: GridColumnCount) -> GridColumnCount {
        switch direction {
        case .zoomIn:  // 확대 → 열 수 감소
            return baseColumns.zoomIn
        case .zoomOut: // 축소 → 열 수 증가
            return baseColumns.zoomOut
        }
    }

    // MARK: - Snap Decision (10% / 50% Rule)

    /// 스냅 목표 결정
    func decideSnapTarget(using state: PinchZoomState, currentVirtualColumns: CGFloat) -> GridColumnCount {
        let progress = stageProgress(
            stageBase: state.stageBase,
            stageTarget: state.stageTarget,
            currentVirtual: currentVirtualColumns
        )

        let threshold: CGFloat = state.didReverse ? 0.5 : 0.1

        if progress >= threshold {
            // 목표 방향으로 진행
            return GridColumnCount(rawValue: Int(state.stageTarget.rounded())) ?? currentGridColumnCount
        } else {
            // 원래 상태로 복귀
            return GridColumnCount(rawValue: Int(state.stageBase.rounded())) ?? currentGridColumnCount
        }
    }

    /// 단계 진행도 계산 (0.0 ~ 1.0)
    func stageProgress(stageBase: CGFloat, stageTarget: CGFloat, currentVirtual: CGFloat) -> CGFloat {
        let range = stageTarget - stageBase
        guard range != 0 else { return 0 }
        let raw = (currentVirtual - stageBase) / range
        return min(max(raw, 0), 1)
    }

    // MARK: - Padding Calculation

    /// effectiveColumns 기준 패딩 셀 개수 계산
    func calculatePaddingCount(for effectiveColumns: Int) -> Int {
        let totalCount = gridDataSource.assetCount
        guard totalCount > 0 else { return 0 }
        let remainder = totalCount % effectiveColumns
        return remainder == 0 ? 0 : (effectiveColumns - remainder)
    }

    // MARK: - FadeIn Trigger

    /// fadeIn 트리거 (목표 열 수에 맞는 고해상도 요청)
    /// 앵커 셀 제외, 기존 visible 셀만 대상
    func triggerFadeIn(target: GridColumnCount, anchorAssetID: String?) {
        let targetSize = thumbnailSizeForColumns(target)

        for cell in collectionView.visibleCells.compactMap({ $0 as? PhotoCell }) {
            guard let assetID = cell.currentAssetID,
                  assetID != anchorAssetID else { continue }

            // 고해상도 이미지 요청 (기존 refreshImageIfNeeded 활용)
            if let asset = gridDataSource.assetForID(assetID) {
                cell.refreshImageIfNeeded(asset: asset, targetSize: targetSize)
            }
        }
    }

    /// 특정 열 수에 맞는 썸네일 크기 계산
    func thumbnailSizeForColumns(_ columns: GridColumnCount) -> CGSize {
        let spacing = ContinuousGridLayout.cellSpacing
        let columnCount = CGFloat(columns.rawValue)
        let totalSpacing = spacing * (columnCount - 1)
        let availableWidth = view.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columnCount)

        let scale = UIScreen.main.scale
        return CGSize(width: cellWidth * scale, height: cellWidth * scale)
    }
}

// MARK: - Snap Animation

/// 스냅 애니메이션 상태
private class SnapAnimationState {
    var displayLink: CADisplayLink?
    var startTime: CFTimeInterval = 0
    var startValue: CGFloat = 0
    var targetValue: CGFloat = 0
    var anchorAssetID: String?
    var anchorPointInView: CGPoint = .zero
    var completion: (() -> Void)?

    static let duration: CFTimeInterval = 0.25
}

extension BaseGridViewController {

    /// 스냅 애니메이션 시작
    func animateToTargetColumns(
        _ target: GridColumnCount,
        layout: ContinuousGridLayout,
        state: PinchZoomState,
        completion: @escaping () -> Void
    ) {
        let targetValue = CGFloat(target.rawValue)

        // 이미 목표에 도달했으면 즉시 완료
        if abs(layout.virtualColumns - targetValue) < 0.01 {
            layout.snapToColumns(target)
            completion()
            return
        }

        // 기존 애니메이션 취소
        cancelSnapAnimation()

        // 애니메이션 상태 설정
        let animState = SnapAnimationState()
        animState.startValue = layout.virtualColumns
        animState.targetValue = targetValue
        animState.startTime = CACurrentMediaTime()
        animState.anchorAssetID = state.anchorAssetID
        animState.anchorPointInView = state.anchorPointInView
        animState.completion = completion

        // DisplayLink 생성
        let displayLink = CADisplayLink(target: self, selector: #selector(snapAnimationTick))
        displayLink.add(to: .main, forMode: .common)
        animState.displayLink = displayLink

        snapAnimationState = animState
    }

    /// 스냅 애니메이션 틱
    @objc private func snapAnimationTick() {
        guard let animState = snapAnimationState,
              let layout = continuousLayout else {
            cancelSnapAnimation()
            return
        }

        let elapsed = CACurrentMediaTime() - animState.startTime
        let progress = min(elapsed / SnapAnimationState.duration, 1.0)

        // easeOut 곡선
        let easedProgress = 1 - pow(1 - progress, 3)

        // virtualColumns 보간
        // 애니메이션 중에도 paddingCellCount 고정 (스냅 완료 시에만 업데이트)
        let newValue = animState.startValue + (animState.targetValue - animState.startValue) * CGFloat(easedProgress)
        layout.virtualColumns = newValue
        layout.invalidateLayout()
        collectionView.layoutIfNeeded()

        // 앵커 보정 유지
        updateContentOffsetForAnchor(
            anchorAssetID: animState.anchorAssetID,
            anchorPointInView: animState.anchorPointInView,
            layout: layout
        )

        // 완료 체크
        if progress >= 1.0 {
            let targetColumns = GridColumnCount(rawValue: Int(animState.targetValue.rounded())) ?? .three
            layout.snapToColumns(targetColumns)

            // 스냅 완료 시에만 paddingCellCount 업데이트 + 컬렉션뷰 동기화
            let newPadding = calculatePaddingCount(for: targetColumns.rawValue)
            if layout.paddingCellCount != newPadding {
                layout.paddingCellCount = newPadding
                collectionView.reloadData()  // numberOfItems 동기화
            }

            let completion = animState.completion
            cancelSnapAnimation()
            completion?()
        }
    }

    /// 스냅 애니메이션 취소
    func cancelSnapAnimation() {
        snapAnimationState?.displayLink?.invalidate()
        snapAnimationState = nil
    }
}

// MARK: - PinchZoomStateBox

/// PinchZoomState를 NSObject로 래핑 (associated object 저장용)
private class PinchZoomStateBox: NSObject {
    let state: PinchZoomState
    init(_ state: PinchZoomState) { self.state = state }
}

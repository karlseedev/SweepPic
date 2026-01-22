# 핀치줌/회전 구현 상세

**작성일**: 2026-01-21
**버전**: v5

> **요구사항/설계**: [260121zoom4.md](./260121zoom4.md) 참조

---

## 1. 구현 체크리스트

### 1.1 레이아웃

- [ ] `ContinuousGridLayout` 생성 (`virtualColumns: CGFloat`)
- [ ] `prepare()`에서 캐시 초기화
- [ ] `layoutAttributesForElements`/`layoutAttributesForItem` 구현
- [ ] `collectionViewContentSize` 계산 (virtualColumns 기반)
- [ ] `shouldInvalidateLayout` 최적화

### 1.2 핀치 상태

- [ ] `PinchZoomState`에 `baseColumns`, `previousVirtualColumns`, `currentTargetColumns`, `initialDirection`, `didReverse` 포함
- [ ] `anchorAssetID`, `anchorPointInView` 저장
- [ ] `frozenPaddingCellCount`, `frozenItemCount` 저장 (핀치 시작 시 고정)

### 1.3 핵심 로직

- [ ] 방향 결정 후 fadeIn 즉시 트리거 (`.changed` 첫 프레임)
- [ ] 기준점 통과 시 다단계 fadeIn 재트리거
- [ ] 앵커 셀 고정 contentOffset 보정
- [ ] 손을 뗄 때 10%/50% 규칙 스냅
- [ ] 좌표계 변환 (bounds → content)
- [ ] paddingCellCount 핀치 중 고정

### 1.4 회전

- [ ] `viewWillTransition`에서 `virtualColumns` 즉시 변경
- [ ] 회전 시작 시 fadeIn 트리거
- [ ] 완료 후 앵커 복구 + 고해상도 재요청

### 1.5 안정성

- [ ] 비동기 썸네일 요청에 token/assetID 검증
- [ ] 셀 재사용 시 old overlay 정리
- [ ] contentOffset clamp

---

## 2. 핀치 제스처 의사코드

### 2.1 타입 정의

```swift
enum ZoomDirection {
    case zoomIn   // 확대 (열 수 감소)
    case zoomOut  // 축소 (열 수 증가)
}

struct PinchZoomState {
    var isActive = false
    var baseColumns: CGFloat = 3.0
    var previousVirtualColumns: CGFloat = 3.0
    var currentTargetColumns: GridColumnCount?
    var initialDirection: ZoomDirection?
    var didReverse = false
    var hasFiredInitialFadeIn = false

    // 앵커 관련
    var anchorAssetID: String?
    var anchorPointInView: CGPoint = .zero  // bounds 좌표

    // 핀치 시작 시 고정 (핀치 중 변경 금지)
    var frozenPaddingCellCount: Int = 0
    var frozenItemCount: Int = 0
}
```

### 2.2 핀치 제스처 핸들러

```swift
@objc func handlePinch(_ gesture: UIPinchGestureRecognizer) {
    switch gesture.state {
    case .began:
        handlePinchBegan(gesture)
    case .changed:
        handlePinchChanged(gesture)
    case .ended, .cancelled:
        handlePinchEnded(gesture)
    default:
        break
    }
}
```

### 2.3 핀치 시작 (.began)

```swift
func handlePinchBegan(_ gesture: UIPinchGestureRecognizer) {
    // 상태 초기화
    pinchState = PinchZoomState()
    pinchState.isActive = true
    pinchState.baseColumns = CGFloat(currentGridColumnCount.rawValue)
    pinchState.previousVirtualColumns = pinchState.baseColumns

    // 핀치 중 변경 금지 - 시작 시점 값 고정
    pinchState.frozenPaddingCellCount = paddingCellCount
    pinchState.frozenItemCount = collectionView.numberOfItems(inSection: 0)
    layout.paddingCellCount = pinchState.frozenPaddingCellCount
    layout.frozenItemCount = pinchState.frozenItemCount

    // 앵커 결정 - 좌표계 변환 필수!
    let locationInBounds = gesture.location(in: collectionView)
    let locationInContent = CGPoint(
        x: locationInBounds.x + collectionView.contentOffset.x,
        y: locationInBounds.y + collectionView.contentOffset.y
    )

    pinchState.anchorPointInView = locationInBounds  // bounds 좌표 저장
    pinchState.anchorAssetID = resolveAnchorAssetID(at: locationInContent)
}
```

### 2.4 핀치 진행 (.changed)

```swift
func handlePinchChanged(_ gesture: UIPinchGestureRecognizer) {
    guard pinchState.isActive else { return }

    let scale = gesture.scale

    // virtualColumns 계산 (클램프 적용)
    let rawVirtualColumns = pinchState.baseColumns / scale
    let virtualColumns = min(max(rawVirtualColumns, 0.8), 5.2)

    // 레이아웃 업데이트
    layout.virtualColumns = virtualColumns
    layout.invalidateLayout()
    collectionView.layoutIfNeeded()

    // 앵커 고정
    updateContentOffsetForAnchor()

    // 첫 프레임에서 방향 결정 후 fadeIn
    if !pinchState.hasFiredInitialFadeIn && abs(scale - 1.0) > 0.01 {
        pinchState.initialDirection = (scale > 1.0) ? .zoomIn : .zoomOut
        let target = inferTargetColumns(from: pinchState.initialDirection!, base: currentGridColumnCount)
        pinchState.currentTargetColumns = target
        triggerFadeIn(target: target)
        pinchState.hasFiredInitialFadeIn = true
    }

    // 방향 전환 추적
    updateDirectionState(virtualColumns: virtualColumns)

    // 기준점 통과 감지 → 다단계 fadeIn
    let crossed = detectCrossedThresholds(
        prev: pinchState.previousVirtualColumns,
        cur: virtualColumns
    )
    for threshold in crossed {
        if let target = GridColumnCount(rawValue: threshold),
           pinchState.currentTargetColumns != target {
            pinchState.currentTargetColumns = target
            triggerFadeIn(target: target)
        }
    }

    pinchState.previousVirtualColumns = virtualColumns
}

/// 현재 이동 방향 계산 (이전 값과 비교)
func currentDirection(virtualColumns: CGFloat) -> ZoomDirection {
    if virtualColumns < pinchState.previousVirtualColumns {
        return .zoomIn   // 열 수 감소 = 확대
    } else {
        return .zoomOut  // 열 수 증가 = 축소
    }
}

/// 방향 전환 추적 - didReverse 플래그 업데이트
func updateDirectionState(virtualColumns: CGFloat) {
    guard let initialDirection = pinchState.initialDirection else { return }

    let current = currentDirection(virtualColumns: virtualColumns)

    // 초기 방향과 현재 방향이 다르면 방향 전환
    if current != initialDirection && !pinchState.didReverse {
        pinchState.didReverse = true
    }
}
```

### 2.5 핀치 종료 (.ended)

```swift
func handlePinchEnded(_ gesture: UIPinchGestureRecognizer) {
    guard pinchState.isActive else { return }

    let finalTarget = decideSnapTarget()

    animateToTargetColumns(finalTarget) { [weak self] in
        guard let self = self else { return }

        // 스냅 완료 후에만 paddingCellCount 업데이트
        let newPadding = self.calculatePaddingCount(for: finalTarget.rawValue)
        if self.layout.paddingCellCount != newPadding {
            self.layout.paddingCellCount = newPadding
            self.collectionView.reloadData()
        }

        self.currentGridColumnCount = finalTarget
        self.didPerformZoom(to: finalTarget)
    }

    pinchState = PinchZoomState()
}
```

---

## 3. 앵커 해결 로직

### 3.1 앵커 에셋 ID 해결

**핵심**: 입력은 반드시 content 좌표

```swift
func resolveAnchorAssetID(at locationInContent: CGPoint) -> String? {
    let padding = pinchState.frozenPaddingCellCount

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

    // anchorPointInView도 동기화
    pinchState.anchorPointInView = CGPoint(
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

func assetID(for indexPath: IndexPath, padding: Int) -> String? {
    let assetIndex = indexPath.item - padding
    guard assetIndex >= 0 else { return nil }
    return gridDataSource.assetID(at: assetIndex)
}

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return sqrt(dx * dx + dy * dy)
}
```

### 3.2 앵커 기반 contentOffset 보정

```swift
func updateContentOffsetForAnchor() {
    guard let assetID = pinchState.anchorAssetID else { return }

    let padding = pinchState.frozenPaddingCellCount
    guard let indexPath = indexPath(for: assetID, padding: padding),
          let attributes = collectionView.layoutAttributesForItem(at: indexPath) else {
        return
    }

    let anchorCenter = attributes.center
    let anchorPoint = pinchState.anchorPointInView

    let newOffset = CGPoint(
        x: anchorCenter.x - anchorPoint.x,
        y: anchorCenter.y - anchorPoint.y
    )

    collectionView.contentOffset = clampOffset(newOffset)
}

func indexPath(for assetID: String, padding: Int) -> IndexPath? {
    guard let assetIndex = gridDataSource.assetIndex(for: assetID) else { return nil }
    return IndexPath(item: assetIndex + padding, section: 0)
}

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
```

---

## 4. 스냅 로직

### 4.1 목표 열 수 추론

```swift
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
```

### 4.2 기준점 통과 감지

```swift
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
```

### 4.3 스냅 대상 결정 (10%/50% 규칙)

```swift
func decideSnapTarget() -> GridColumnCount {
    let progress = computeStageProgress()

    if pinchState.didReverse {
        // 방향 전환: 50% 규칙
        return progress >= 0.5 ? stageTarget() : stageBase()
    } else {
        // 단방향: 10% 규칙
        return progress >= 0.1 ? stageTarget() : stageBase()
    }
}

/// 현재 단계의 base (시작점) 열 수 반환
/// - 가장 최근에 통과한 유효 기준점 (1, 3, 5) 또는 시작 열 수
func stageBase() -> GridColumnCount {
    let thresholds = [1, 3, 5]
    let current = layout.virtualColumns

    // 현재 열 수보다 작거나 같은 가장 큰 기준점
    if let direction = pinchState.initialDirection {
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
/// - 현재 방향으로 다음 유효 기준점
func stageTarget() -> GridColumnCount {
    let thresholds = [1, 3, 5]
    let current = layout.virtualColumns

    guard let direction = pinchState.initialDirection else {
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

func computeStageProgress() -> CGFloat {
    let base = CGFloat(stageBase().rawValue)
    let target = CGFloat(stageTarget().rawValue)
    let current = layout.virtualColumns

    let range = target - base
    guard range != 0 else { return 0 }

    let raw = (current - base) / range
    return min(max(raw, 0), 1)
}
```

---

## 5. 마무리 애니메이션

```swift
private var displayLink: CADisplayLink?
private var animStartTime: CFTimeInterval = 0
private var animStartValue: CGFloat = 0
private var animTargetValue: CGFloat = 0
private var animCompletion: (() -> Void)?

func animateToTargetColumns(_ target: GridColumnCount, completion: @escaping () -> Void) {
    let targetValue = CGFloat(target.rawValue)

    // 이미 도달했으면 즉시 완료
    if abs(layout.virtualColumns - targetValue) < 0.01 {
        completion()
        return
    }

    animStartValue = layout.virtualColumns
    animTargetValue = targetValue
    animStartTime = CACurrentMediaTime()
    animCompletion = completion

    displayLink?.invalidate()
    displayLink = CADisplayLink(target: self, selector: #selector(animationTick))
    displayLink?.add(to: .main, forMode: .common)
}

@objc private func animationTick() {
    let duration: CFTimeInterval = 0.25
    let elapsed = CACurrentMediaTime() - animStartTime
    let progress = min(elapsed / duration, 1.0)

    // easeOut 곡선
    let eased = 1 - pow(1 - progress, 3)

    let newValue = animStartValue + (animTargetValue - animStartValue) * CGFloat(eased)
    layout.virtualColumns = newValue
    layout.invalidateLayout()
    collectionView.layoutIfNeeded()

    updateContentOffsetForAnchor()

    if progress >= 1.0 {
        displayLink?.invalidate()
        displayLink = nil
        animCompletion?()
        animCompletion = nil
    }
}

func cancelSnapAnimation() {
    displayLink?.invalidate()
    displayLink = nil
    animCompletion = nil
}
```

---

## 6. fadeIn 처리

### 6.1 가시 셀 조회

```swift
/// 현재 화면에 보이는 사진 셀 배열 반환
/// - padding 셀 제외
func visiblePhotoCells() -> [PhotoCell] {
    let padding = pinchState.frozenPaddingCellCount

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
```

### 6.2 fadeIn 트리거

```swift
func triggerFadeIn(target: GridColumnCount) {
    let targetSize = thumbnailSize(for: target)
    let token = UUID().uuidString
    let requestedTarget = target

    for cell in visiblePhotoCells() {
        guard cell.assetID != pinchState.anchorAssetID else { continue }

        cell.fadeToken = token

        imagePipeline.loadThumbnail(
            for: cell.assetID,
            targetSize: targetSize,
            priority: .high
        ) { [weak cell, weak self] image in
            guard let cell = cell, let self = self else { return }
            guard cell.fadeToken == token else { return }
            guard self.pinchState.currentTargetColumns == requestedTarget else { return }
            guard let image = image else { return }

            cell.fadeInImage(image)
        }
    }
}

/// 목표 열 수에 따른 썸네일 크기 계산
func thumbnailSize(for columns: GridColumnCount) -> CGSize {
    let spacing: CGFloat = 2
    let totalSpacing = spacing * CGFloat(columns.rawValue - 1)
    let itemWidth = (collectionView.bounds.width - totalSpacing) / CGFloat(columns.rawValue)
    let scale = UIScreen.main.scale

    return CGSize(width: itemWidth * scale, height: itemWidth * scale)
}
```

---

## 7. 레이아웃 계산식

### 7.1 기본 공식

```swift
let spacing: CGFloat = 2
let columns = virtualColumns
let totalSpacing = spacing * (columns - 1)
let itemWidth = (bounds.width - totalSpacing) / columns
let itemHeight = itemWidth
```

### 7.2 row/col 매핑

```swift
let effectiveColumns = Int(ceil(virtualColumns))
let row = index / effectiveColumns
let col = index % effectiveColumns

let x = CGFloat(col) * (itemWidth + spacing)
let y = CGFloat(row) * (itemHeight + spacing)
```

### 7.3 contentSize 계산

**주의**: `numberOfItems`는 DataSource 캐시값을 반환합니다. 핀치 중에는
`frozenPaddingCellCount`를 기반으로 레이아웃이 직접 itemCount를 관리해야 합니다.

```swift
// 레이아웃 내부에서 itemCount 관리
// - 핀치 시작 시 저장: frozenItemCount = collectionView.numberOfItems(inSection: 0)
// - 핀치 중: frozenItemCount 사용
// - 스냅 완료 후: reloadData()로 캐시 갱신

let itemCount = frozenItemCount  // collectionView.numberOfItems 대신!
let effectiveColumns = Int(ceil(virtualColumns))
let rowCount = Int(ceil(Double(itemCount) / Double(effectiveColumns)))

let contentHeight = CGFloat(rowCount) * itemHeight
    + CGFloat(max(0, rowCount - 1)) * spacing
```

### 7.4 가시 영역 최적화

```swift
func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    let minRow = max(0, Int(floor(rect.minY / (itemHeight + spacing))))
    let maxRow = Int(ceil(rect.maxY / (itemHeight + spacing)))

    var attributes: [UICollectionViewLayoutAttributes] = []

    for row in minRow...maxRow {
        for col in 0..<effectiveColumns {
            let index = row * effectiveColumns + col
            guard index < itemCount else { break }

            let indexPath = IndexPath(item: index, section: 0)
            if let attr = layoutAttributesForItem(at: indexPath) {
                attributes.append(attr)
            }
        }
    }

    return attributes
}
```

### 7.5 effectiveColumns 히스테리시스

```swift
func stabilizedEffectiveColumns(_ virtualColumns: CGFloat, current: Int) -> Int {
    let hysteresis: CGFloat = 0.2
    let downThreshold = CGFloat(current) - 0.8
    let upThreshold = CGFloat(current) + 0.8

    if virtualColumns <= downThreshold {
        return max(1, current - 1)
    }
    if virtualColumns >= upThreshold {
        return min(5, current + 1)
    }
    return current
}

func snapToValidThreshold(_ columns: Int) -> GridColumnCount {
    if columns <= 2 { return .one }
    if columns <= 4 { return .three }
    return .five
}
```

---

## 8. 회전 처리

```swift
override func viewWillTransition(
    to size: CGSize,
    with coordinator: UIViewControllerTransitionCoordinator
) {
    super.viewWillTransition(to: size, with: coordinator)

    // 중앙 셀 저장
    saveScrollAnchorAssetID()
    let anchorID = scrollAnchorAssetID

    // 새 열 수 계산
    let isLandscape = size.width > size.height
    let newColumns = isLandscape
        ? currentGridColumnCount.landscapeColumnCount
        : currentGridColumnCount.portraitColumnCount

    // fadeIn 트리거
    triggerFadeIn(target: newColumns, anchorAssetID: anchorID)

    coordinator.animate(alongsideTransition: { [weak self] _ in
        guard let self = self else { return }

        self.layout.virtualColumns = CGFloat(newColumns.rawValue)
        // paddingCellCount는 회전 중 변경 금지! (completion에서 업데이트)
        self.layout.invalidateLayout()
        self.collectionView.layoutIfNeeded()
        self.updateCellSize()
        self.updateContentInset()

    }, completion: { [weak self] _ in
        guard let self = self else { return }

        // 회전 완료 후에만 paddingCellCount 업데이트
        let newPadding = self.calculatePaddingCount(for: newColumns.rawValue)
        if self.layout.paddingCellCount != newPadding {
            self.layout.paddingCellCount = newPadding
        }

        self.collectionView.reloadData()
        if anchorID != nil {
            self.restoreScrollAnchorAssetID()
        }
        self.currentGridColumnCount = newColumns
        self.didPerformZoom(to: newColumns)
    })
}
```

---

## 9. paddingCellCount 동기화 규칙

### 9.1 핵심 원칙

**핀치 중에는 paddingCellCount를 고정하고, 스냅 완료 후에만 업데이트한다.**

### 9.2 이유

1. `collectionView.numberOfItems(inSection:)`는 DataSource 캐시값 반환
2. paddingCellCount 변경 시 `numberOfItemsInSection` 반환값도 변해야 함
3. `reloadData()` 없이는 캐시가 갱신되지 않음
4. 핀치 중 `reloadData()` 호출은 깜빡임 유발

### 9.3 적용 위치

```swift
// 핀치 시작 시
pinchState.frozenPaddingCellCount = paddingCellCount
layout.paddingCellCount = pinchState.frozenPaddingCellCount

// 핀치 중
// paddingCellCount 변경 금지!

// 스냅 완료 시
let newPadding = calculatePaddingCount(for: finalTarget.rawValue)
if layout.paddingCellCount != newPadding {
    layout.paddingCellCount = newPadding
    collectionView.reloadData()
}
```

---

## 10. Prefetch 전략 (축소 시)

```swift
func expandPrefetchForPinch(direction: ZoomDirection) {
    guard direction == .zoomOut else { return }

    let visibleRect = collectionView.bounds
    let expandedRect = visibleRect.insetBy(
        dx: -visibleRect.width * 0.5,
        dy: -visibleRect.height * 0.5
    )

    let indexPaths = layout.indexPathsForElements(in: expandedRect)
    prefetchAssets(for: indexPaths)
}
```

---

## 11. 이미지 로딩 Fallback

```swift
func loadThumbnailWithFallback(
    assetID: String,
    targetSize: CGSize,
    completion: @escaping (UIImage?) -> Void
) {
    // 1) 정확한 크기 캐시
    if let cached = imageCache.image(for: assetID, size: targetSize) {
        completion(cached)
        return
    }

    // 2) 더 큰 크기 → 다운샘플링
    if let larger = imageCache.largestCachedImage(for: assetID, minSize: targetSize) {
        completion(downsample(larger, to: targetSize))
        return
    }

    // 3) 더 작은 크기 → 일단 표시 후 비동기 로드
    if let smaller = imageCache.anyCachedImage(for: assetID) {
        completion(smaller)
        loadAsync(assetID: assetID, targetSize: targetSize) { image in
            // 로드 완료 시 교체
        }
        return
    }

    // 4) 캐시 없음 → 비동기 로드
    loadAsync(assetID: assetID, targetSize: targetSize, completion: completion)
}
```

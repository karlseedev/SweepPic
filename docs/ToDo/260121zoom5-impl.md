# 핀치줌/회전 구현 상세

**작성일**: 2026-01-22
**버전**: v6 (6개 문제 완전 해결 버전)

> **요구사항/설계**: [260121zoom5.md](./260121zoom5.md) 참조

---

## 0. v5 코드의 문제점과 v6 수정 사항

### 0.1 문제별 코드 수정 요약

| # | 문제 | v5 코드 문제점 | v6 수정 내용 |
|---|------|---------------|-------------|
| 1 | X축 좌측 정렬 | `x = col * (itemWidth + spacing)` - xOffset 없음 | `x = col * (itemWidth + spacing) + xOffset` |
| 2 | 스크롤 점프 | `layoutIfNeeded()` 후 `updateContentOffsetForAnchor()` 분리 | 레이아웃 내부에서 offset 계산, atomic 갱신 |
| 3 | 바깥 셀 클리핑 | `layoutAttributesForElements(in rect:)`에서 rect 그대로 사용 | rect 확장 + `clipsToBounds = false` |
| 4 | 10% 규칙 | `stageBase()`, `stageTarget()`이 현재 위치 기준 동적 계산 | 핀치 시작 시 base/target 고정 |
| 5 | 취소 시 점프 | 문제 2와 동일 | 문제 2와 동일 |

---

## 1. 구현 체크리스트

### 1.1 레이아웃 (ContinuousGridLayout)

- [ ] `virtualColumns: CGFloat` 프로퍼티
- [ ] `isPinching: Bool` 프로퍼티
- [ ] **`xOffset: CGFloat` 프로퍼티 (v6 추가)**
- [ ] **`anchorIndexPath: IndexPath?` 프로퍼티 (v6 추가)**
- [ ] **`anchorPointInView: CGPoint` 프로퍼티 (v6 추가)**
- [ ] **`calculatedContentOffsetY: CGFloat` 프로퍼티 (v6 추가)**
- [ ] `prepare()`에서 앵커 기준 xOffset, calculatedContentOffsetY 계산
- [ ] `layoutAttributesForElements`에서 **핀치 중 rect 확장**
- [ ] `layoutAttributesForItem`에서 **xOffset 적용**
- [ ] `collectionViewContentSize` 계산

### 1.2 핀치 상태 (PinchZoomState)

- [ ] `snapBaseColumns`, `snapTargetColumns` - 스냅 판단용 (절대 불변)
- [ ] `stageBaseColumns`, `stageTargetColumns` - 단계별 fadeIn용
- [ ] `anchorAssetID`, `anchorPointInView` 저장
- [ ] `frozenPaddingCellCount`, `frozenItemCount` 저장
- [ ] `lastProgressForDirectionCheck` - 방향 전환 감지용

### 1.3 핵심 로직

- [ ] `.began`: 앵커 결정, 고정값 설정, layout에 앵커 전달
- [ ] `.changed` 첫 프레임: 방향/target 결정, fadeIn 트리거
- [ ] `.changed` 매 프레임: virtualColumns 설정 → invalidate → layoutIfNeeded → contentOffset.y 적용
- [ ] `.ended`: 10%/50% 규칙 스냅, xOffset → 0 애니메이션
- [ ] **clipsToBounds 토글** (핀치 시작/종료 시)

### 1.4 fadeIn

- [ ] 트리거: 방향 결정 시 + 기준점 통과 시
- [ ] 대상: visible 셀 중 앵커 제외
- [ ] **애니메이션: UIView.animate 0.2초 easeOut**
- [ ] 비동기 로딩 검증: token/assetID 확인

### 1.5 dataSource 변경 차단

- [ ] 핀치 중 `PHPhotoLibraryChangeObserver` 변경 지연
- [ ] 변경 사항 큐에 저장
- [ ] 핀치 종료 시 지연된 변경 일괄 적용
- [ ] 앵커 셀 삭제 시 재설정 로직

---

## 2. 타입 정의

### 2.1 ZoomDirection

```swift
enum ZoomDirection {
    case zoomIn   // 확대 (열 수 감소)
    case zoomOut  // 축소 (열 수 증가)
}
```

### 2.2 PinchZoomState (v6 수정)

```swift
struct PinchZoomState {
    var isActive = false

    // ===== 1. 스냅 판단용 (핀치 전체, 절대 변경 금지!) =====
    // - 10%/50% 규칙 적용 시 사용
    var snapBaseColumns: CGFloat = 3.0              // 핀치 시작 열 수
    var snapTargetColumns: GridColumnCount = .three // 최종 목표 열 수 (방향 결정 시 설정)

    // ===== 2. 단계별 fadeIn용 (다단계 핀치에서 변경됨) =====
    // - fadeIn 트리거 시 사용
    var stageBaseColumns: CGFloat = 3.0             // 현재 단계 시작점
    var stageTargetColumns: GridColumnCount = .three // 현재 단계 목표

    // ===== 3. 앵커 및 고정값 =====
    var anchorAssetID: String?                  // 앵커 에셋 ID
    var anchorPointInView: CGPoint = .zero      // 앵커의 화면 위치 (bounds 좌표)
    var frozenPaddingCellCount: Int = 0         // padding 고정
    var frozenItemCount: Int = 0                // 아이템 수 고정

    // ===== 4. 진행 상태 =====
    var initialDirection: ZoomDirection?        // 초기 방향
    var didReverse = false                      // 방향 전환 여부
    var hasFiredInitialFadeIn = false           // 첫 fadeIn 트리거 여부
    var lastProgressForDirectionCheck: CGFloat = 0  // 방향 전환 감지용
}
```

**v5 대비 변경점:**
- `baseColumns` → `snapBaseColumns` + `stageBaseColumns`로 분리
- `targetColumns` → `snapTargetColumns` + `stageTargetColumns`로 분리
- 스냅 판단용은 절대 변경 금지, 단계용은 기준점 통과 시 재설정
- `lastProgressForDirectionCheck` 추가 (방향 전환 감지 임계값 적용용)

---

## 3. ContinuousGridLayout (v6 핵심 수정)

### 3.1 프로퍼티 정의

```swift
class ContinuousGridLayout: UICollectionViewLayout {

    // ===== 기본 설정 =====
    var virtualColumns: CGFloat = 3.0 {
        didSet { invalidateLayout() }
    }
    var spacing: CGFloat = 2.0
    var frozenPaddingCellCount: Int = 0
    var frozenItemCount: Int = 0

    // ===== 핀치 상태 (v6 추가) =====
    var isPinching: Bool = false

    /// 앵커 셀의 indexPath (핀치 시작 시 설정)
    var anchorIndexPath: IndexPath?

    /// 앵커 셀이 고정되어야 할 화면 위치 (bounds 좌표)
    var anchorPointInView: CGPoint = .zero

    /// X축 앵커 보정값 (레이아웃에서 모든 셀 x좌표에 적용)
    /// - 핀치 중: 앵커가 화면상 X 위치에 고정되도록 계산
    /// - 핀치 종료 시: 0으로 애니메이션
    private(set) var xOffset: CGFloat = 0

    /// Y축 앵커 보정값 (외부에서 contentOffset.y에 적용)
    /// - prepare()에서 계산됨
    private(set) var calculatedContentOffsetY: CGFloat = 0

    // ===== 캐시 =====
    private var cachedAttributes: [UICollectionViewLayoutAttributes] = []
    private var cachedContentSize: CGSize = .zero

    // ===== 계산된 값 =====
    private var itemWidth: CGFloat = 0
    private var itemHeight: CGFloat = 0
    private var effectiveColumns: Int = 3
}
```

### 3.2 prepare() (v6 핵심 수정)

```swift
override func prepare() {
    super.prepare()
    guard let collectionView = collectionView else { return }

    cachedAttributes.removeAll()

    let bounds = collectionView.bounds
    let itemCount = frozenItemCount > 0 ? frozenItemCount : collectionView.numberOfItems(inSection: 0)

    guard itemCount > 0, bounds.width > 0 else {
        cachedContentSize = .zero
        return
    }

    // ===== 1. 기본 레이아웃 계산 =====
    effectiveColumns = max(1, Int(ceil(virtualColumns)))
    let totalSpacing = spacing * (virtualColumns - 1)
    itemWidth = (bounds.width - totalSpacing) / virtualColumns
    itemHeight = itemWidth

    let rowCount = Int(ceil(Double(itemCount) / Double(effectiveColumns)))

    // ===== 2. 앵커 기반 xOffset 및 contentOffsetY 계산 (v6 핵심!) =====
    if isPinching, let anchorIP = anchorIndexPath, anchorIP.item < itemCount {
        let anchorRow = anchorIP.item / effectiveColumns
        let anchorCol = anchorIP.item % effectiveColumns

        // 앵커 셀의 정상 위치 (xOffset 적용 전)
        let anchorNormalCenterX = CGFloat(anchorCol) * (itemWidth + spacing) + itemWidth / 2
        let anchorNormalCenterY = CGFloat(anchorRow) * (itemHeight + spacing) + itemHeight / 2

        // xOffset: 앵커가 화면상 같은 X 위치에 고정되도록
        xOffset = anchorPointInView.x - anchorNormalCenterX

        // calculatedContentOffsetY: 앵커가 화면상 같은 Y 위치에 고정되도록
        calculatedContentOffsetY = anchorNormalCenterY - anchorPointInView.y
    } else {
        xOffset = 0
        calculatedContentOffsetY = collectionView.contentOffset.y
    }

    // ===== 3. 모든 셀의 layoutAttributes 생성 =====
    for item in 0..<itemCount {
        let indexPath = IndexPath(item: item, section: 0)
        let row = item / effectiveColumns
        let col = item % effectiveColumns

        // 정상 위치 계산
        let normalX = CGFloat(col) * (itemWidth + spacing)
        let normalY = CGFloat(row) * (itemHeight + spacing)

        // xOffset 적용 (v6 핵심!)
        let finalX = normalX + xOffset
        let finalY = normalY

        let attributes = UICollectionViewLayoutAttributes(forCellWith: indexPath)
        attributes.frame = CGRect(x: finalX, y: finalY, width: itemWidth, height: itemHeight)
        cachedAttributes.append(attributes)
    }

    // ===== 4. contentSize 계산 =====
    let contentHeight = CGFloat(rowCount) * itemHeight + CGFloat(max(0, rowCount - 1)) * spacing
    cachedContentSize = CGSize(width: bounds.width, height: contentHeight)
}
```

**v5 대비 변경점:**
- `xOffset` 계산 로직 추가
- `calculatedContentOffsetY` 계산 로직 추가
- 모든 셀의 x 좌표에 `xOffset` 적용

### 3.3 layoutAttributesForElements(in rect:) (v6 수정)

```swift
override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
    // ===== 핀치 중 가시 영역 확장 (v6 핵심!) =====
    var effectiveRect = rect
    if isPinching {
        // 셀 크기의 2배만큼 확장 (상하좌우)
        let expansion = itemWidth * 2
        effectiveRect = rect.insetBy(dx: -expansion, dy: -expansion)
    }

    // ===== 효율적인 범위 검색 =====
    let minRow = max(0, Int(floor((effectiveRect.minY) / (itemHeight + spacing))))
    let maxRow = Int(ceil((effectiveRect.maxY) / (itemHeight + spacing)))

    var result: [UICollectionViewLayoutAttributes] = []

    for row in minRow...maxRow {
        for col in 0..<effectiveColumns {
            let index = row * effectiveColumns + col
            guard index >= 0, index < cachedAttributes.count else { continue }

            let attr = cachedAttributes[index]

            // xOffset이 적용된 frame으로 rect 교차 판단
            if attr.frame.intersects(effectiveRect) {
                result.append(attr)
            }
        }
    }

    return result
}
```

**v5 대비 변경점:**
- `isPinching`일 때 `effectiveRect` 확장
- 바깥 셀도 반환되어 잘린 채로 보임

### 3.4 layoutAttributesForItem(at indexPath:)

```swift
override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
    guard indexPath.item < cachedAttributes.count else { return nil }
    return cachedAttributes[indexPath.item]
}
```

### 3.5 collectionViewContentSize

```swift
override var collectionViewContentSize: CGSize {
    return cachedContentSize
}
```

### 3.6 shouldInvalidateLayout

```swift
override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
    guard let collectionView = collectionView else { return false }
    return newBounds.width != collectionView.bounds.width
}
```

### 3.7 xOffset 리셋 메서드 (스냅 애니메이션용)

```swift
/// xOffset을 0으로 리셋 (스냅 애니메이션 완료 후 호출)
func resetXOffset() {
    xOffset = 0
    anchorIndexPath = nil
    isPinching = false
}

/// 핀치 시작 시 앵커 설정
func setAnchor(indexPath: IndexPath, pointInView: CGPoint) {
    anchorIndexPath = indexPath
    anchorPointInView = pointInView
    isPinching = true
}
```

---

## 4. 핀치 제스처 핸들러 (v6 수정)

### 4.1 메인 핸들러

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

### 4.2 핀치 시작 (.began) - v6 수정

```swift
func handlePinchBegan(_ gesture: UIPinchGestureRecognizer) {
    // ===== 1. 상태 초기화 =====
    pinchState = PinchZoomState()
    pinchState.isActive = true
    pinchState.snapBaseColumns = CGFloat(currentGridColumnCount.rawValue)  // 스냅 판단용 (고정)
    pinchState.stageBaseColumns = pinchState.snapBaseColumns               // 단계별 fadeIn용

    // ===== 2. 고정값 설정 (핀치 중 변경 금지!) =====
    pinchState.frozenPaddingCellCount = paddingCellCount
    pinchState.frozenItemCount = collectionView.numberOfItems(inSection: 0)

    // ===== 3. 앵커 결정 =====
    let locationInBounds = gesture.location(in: collectionView)
    let locationInContent = CGPoint(
        x: locationInBounds.x + collectionView.contentOffset.x,
        y: locationInBounds.y + collectionView.contentOffset.y
    )

    pinchState.anchorPointInView = locationInBounds  // bounds 좌표 저장!
    pinchState.anchorAssetID = resolveAnchorAssetID(at: locationInContent)

    // ===== 4. 레이아웃에 고정값 및 앵커 정보 전달 (v6 핵심!) =====
    layout.frozenPaddingCellCount = pinchState.frozenPaddingCellCount
    layout.frozenItemCount = pinchState.frozenItemCount

    if let anchorAssetID = pinchState.anchorAssetID,
       let anchorIndexPath = indexPath(for: anchorAssetID, padding: pinchState.frozenPaddingCellCount) {
        layout.setAnchor(indexPath: anchorIndexPath, pointInView: locationInBounds)
    }

    // ===== 5. clipsToBounds 해제 (바깥 셀 표시용) =====
    collectionView.clipsToBounds = false
}
```

**v5 대비 변경점:**
- `layout.setAnchor()` 호출로 레이아웃에 앵커 정보 전달
- `collectionView.clipsToBounds = false` 설정

### 4.3 핀치 진행 (.changed) - v6 수정

```swift
func handlePinchChanged(_ gesture: UIPinchGestureRecognizer) {
    guard pinchState.isActive else { return }

    let scale = gesture.scale

    // ===== 1. virtualColumns 계산 (snapBaseColumns 기준) =====
    let rawVirtualColumns = pinchState.snapBaseColumns / scale
    let virtualColumns = min(max(rawVirtualColumns, 0.8), 5.2)

    // ===== 2. 첫 프레임: 방향 결정 + target 고정 + fadeIn =====
    if !pinchState.hasFiredInitialFadeIn && abs(scale - 1.0) > 0.01 {
        pinchState.initialDirection = (scale > 1.0) ? .zoomIn : .zoomOut

        // 스냅용 target 설정 (절대 변경 금지!)
        pinchState.snapTargetColumns = inferTargetColumns(
            from: pinchState.initialDirection!,
            base: currentGridColumnCount
        )

        // 단계용 target 설정 (다단계에서 변경됨)
        pinchState.stageTargetColumns = pinchState.snapTargetColumns
        pinchState.lastProgressForDirectionCheck = 0

        triggerFadeIn(target: pinchState.stageTargetColumns)
        pinchState.hasFiredInitialFadeIn = true
    }

    // ===== 3. 레이아웃 갱신 (v6: 레이아웃이 앵커 기준으로 계산) =====
    layout.virtualColumns = virtualColumns
    // invalidateLayout()은 virtualColumns setter에서 자동 호출됨
    collectionView.layoutIfNeeded()

    // ===== 4. Y축 contentOffset 적용 (v6: 레이아웃에서 계산된 값 사용) =====
    let clampedOffsetY = clampOffsetY(layout.calculatedContentOffsetY)
    collectionView.contentOffset.y = clampedOffsetY
    // X축은 레이아웃 내부의 xOffset으로 이미 처리됨!

    // ===== 5. 방향 전환 감지 (v6: 임계값 적용) =====
    updateDirectionState()

    // ===== 6. 기준점 통과 감지 → 다단계 fadeIn (stageBase/Target만 변경!) =====
    let crossed = detectCrossedThresholds(
        from: pinchState.stageBaseColumns,
        to: virtualColumns
    )
    for threshold in crossed {
        if let newTarget = GridColumnCount(rawValue: threshold),
           newTarget != pinchState.stageTargetColumns {
            // 새 단계 시작 - stageBase/Target만 재설정 (snapBase/Target은 그대로!)
            pinchState.stageBaseColumns = CGFloat(threshold)
            pinchState.stageTargetColumns = inferNextTarget(from: newTarget, direction: pinchState.initialDirection)
            triggerFadeIn(target: pinchState.stageTargetColumns)
        }
    }
}
```

**v5 대비 핵심 변경점:**
1. `updateContentOffsetForAnchor()` 제거 - 레이아웃이 이미 앵커 기준으로 계산함
2. `contentOffset.y`만 외부에서 적용 (X축은 레이아웃 내부 xOffset으로 처리)
3. `updateDirectionState()`에 임계값 적용

### 4.4 방향 전환 감지 (v6 새로 작성)

```swift
/// 방향 전환 감지 임계값
private let directionChangeThreshold: CGFloat = 0.05  // 5%

func updateDirectionState() {
    guard pinchState.initialDirection != nil else { return }
    guard !pinchState.didReverse else { return }  // 이미 전환됐으면 스킵

    let currentProgress = computeSnapProgress()  // 스냅용 진행도 사용!
    let delta = currentProgress - pinchState.lastProgressForDirectionCheck

    // 5% 이상 반대 방향(진행도 감소)으로 움직여야 방향 전환 인식
    // - 진행도는 항상 snapBase → snapTarget 방향이 정방향 (증가)
    // - 반대 방향 = delta < 0
    if delta < -directionChangeThreshold {
        pinchState.didReverse = true
    }

    // 매 프레임 현재 진행도 저장 (다음 비교용)
    pinchState.lastProgressForDirectionCheck = currentProgress
}
```

**v5와의 차이:**
- v5: `previousVirtualColumns`와 매 프레임 비교 → 미세한 떨림에도 didReverse=true
- v6: 진행도 기준 5% 이상 감소 시에만 방향 전환 인식
- 중복 분기 제거 (zoomIn/zoomOut 모두 동일 로직)
- v6: 진행도 기준 5% 이상 변화 시에만 방향 전환 인식

### 4.5 핀치 종료 (.ended) - v6 수정

```swift
func handlePinchEnded(_ gesture: UIPinchGestureRecognizer) {
    guard pinchState.isActive else { return }

    let finalTarget = decideSnapTarget()

    // ===== 스냅 애니메이션 (virtualColumns + xOffset 동시 애니메이션) =====
    animateToTarget(finalTarget) { [weak self] in
        guard let self = self else { return }

        // 스냅 완료 후 정리
        self.layout.resetXOffset()
        self.collectionView.clipsToBounds = true

        // paddingCellCount 업데이트
        let newPadding = self.calculatePaddingCount(for: finalTarget.rawValue)
        if self.layout.frozenPaddingCellCount != newPadding {
            self.layout.frozenPaddingCellCount = newPadding
            self.collectionView.reloadData()
        }

        self.currentGridColumnCount = finalTarget
        self.didPerformZoom(to: finalTarget)
    }

    pinchState = PinchZoomState()
}
```

**v5 대비 변경점:**
- `layout.resetXOffset()` 호출로 xOffset 정리
- `collectionView.clipsToBounds = true` 복원

---

## 5. 진행도 계산 (v6 완전 재작성)

### 5.1 스냅용 진행도 (10%/50% 규칙 적용용)

```swift
/// 스냅 판단용 진행도 계산 (0.0 ~ 1.0)
/// - snapBase/snapTarget 사용 (핀치 전체 기준, 절대 불변)
/// - 10%/50% 규칙 판단에 사용
func computeSnapProgress() -> CGFloat {
    let base = pinchState.snapBaseColumns
    let target = CGFloat(pinchState.snapTargetColumns.rawValue)
    let current = layout.virtualColumns

    let range = target - base
    guard abs(range) > 0.001 else { return 0 }

    let raw = (current - base) / range
    return min(max(raw, 0), 1)
}
```

### 5.2 단계용 진행도 (fadeIn 트리거용)

```swift
/// 단계별 진행도 계산 (fadeIn 트리거 판단용)
/// - stageBase/stageTarget 사용 (기준점 통과 시 재설정됨)
func computeStageProgress() -> CGFloat {
    let base = pinchState.stageBaseColumns
    let target = CGFloat(pinchState.stageTargetColumns.rawValue)
    let current = layout.virtualColumns

    let range = target - base
    guard abs(range) > 0.001 else { return 0 }

    let raw = (current - base) / range
    return min(max(raw, 0), 1)
}
```

**v5와의 핵심 차이:**
- v5: `stageBase()`, `stageTarget()` 함수가 현재 virtualColumns 기준으로 동적 계산
- v6: 스냅용과 단계용 진행도를 분리, 각각 고정값 사용

### 5.3 스냅 대상 결정 (10%/50% 규칙)

```swift
func decideSnapTarget() -> GridColumnCount {
    // 스냅 판단은 snapBase/snapTarget 기준! (절대 불변)
    let progress = computeSnapProgress()

    if pinchState.didReverse {
        // 방향 전환: 50% 규칙
        if progress >= 0.5 {
            return pinchState.snapTargetColumns
        } else {
            return GridColumnCount(rawValue: Int(pinchState.snapBaseColumns)) ?? currentGridColumnCount
        }
    } else {
        // 단방향: 10% 규칙
        if progress >= 0.1 {
            return pinchState.snapTargetColumns
        } else {
            return GridColumnCount(rawValue: Int(pinchState.snapBaseColumns)) ?? currentGridColumnCount
        }
    }
}
```

### 5.3 목표 열 수 추론

```swift
func inferTargetColumns(from direction: ZoomDirection, base: GridColumnCount) -> GridColumnCount {
    let thresholds = [1, 3, 5]
    guard let index = thresholds.firstIndex(of: base.rawValue) else {
        return base
    }

    switch direction {
    case .zoomIn:  // 확대 → 열 수 감소
        let newIndex = max(0, index - 1)
        return GridColumnCount(rawValue: thresholds[newIndex]) ?? base
    case .zoomOut: // 축소 → 열 수 증가
        let newIndex = min(thresholds.count - 1, index + 1)
        return GridColumnCount(rawValue: thresholds[newIndex]) ?? base
    }
}

func inferNextTarget(from current: GridColumnCount, direction: ZoomDirection?) -> GridColumnCount {
    guard let direction = direction else { return current }
    return inferTargetColumns(from: direction, base: current)
}
```

### 5.4 기준점 통과 감지

```swift
func detectCrossedThresholds(from base: CGFloat, to current: CGFloat) -> [Int] {
    let thresholds = [1, 3, 5]

    if current < base {
        // 확대 방향 (열 수 감소)
        return thresholds
            .filter { CGFloat($0) < base && CGFloat($0) >= current }
            .sorted(by: >)
    } else if current > base {
        // 축소 방향 (열 수 증가)
        return thresholds
            .filter { CGFloat($0) > base && CGFloat($0) <= current }
            .sorted(by: <)
    }

    return []
}
```

---

## 6. 앵커 해결 로직

### 6.1 앵커 에셋 ID 해결

```swift
/// 핀치 위치에서 앵커 에셋 ID 해결
/// - Parameter locationInContent: content 좌표 (bounds + contentOffset)
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

    // anchorPointInView도 중앙으로 동기화
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

func indexPath(for assetID: String, padding: Int) -> IndexPath? {
    guard let assetIndex = gridDataSource.assetIndex(for: assetID) else { return nil }
    return IndexPath(item: assetIndex + padding, section: 0)
}

func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
    let dx = a.x - b.x
    let dy = a.y - b.y
    return sqrt(dx * dx + dy * dy)
}
```

### 6.2 contentOffset Y 클램프

```swift
func clampOffsetY(_ offsetY: CGFloat) -> CGFloat {
    let contentHeight = collectionView.contentSize.height
    let boundsHeight = collectionView.bounds.height
    let inset = collectionView.adjustedContentInset

    let minY = -inset.top
    let maxY = max(minY, contentHeight - boundsHeight + inset.bottom)

    return min(max(offsetY, minY), maxY)
}
```

---

## 7. 스냅 애니메이션 (v6 수정)

### 7.1 DisplayLink 기반 애니메이션

**xOffset 애니메이션 전략: anchorPointInView 보간**

```
[핵심 아이디어]
- 레이아웃의 xOffset은 prepare()에서 자동 계산됨:
  xOffset = anchorPointInView.x - anchorCellNormalX

- 따라서 anchorPointInView.x를 보간하면 xOffset도 자연스럽게 변함!
- 목표: anchorPointInView.x → 앵커 셀의 "정상 X 위치" (xOffset=0이 되는 위치)

[애니메이션 흐름]
1. 시작: anchorPointInView = 핀치 시작 위치 (예: x=100)
2. 목표: anchorPointInView = 목표 열 수에서 앵커 셀의 정상 중심 X
3. 보간: 매 프레임 anchorPointInView.x 업데이트
4. 결과: xOffset이 자연스럽게 0으로 수렴
```

```swift
private var displayLink: CADisplayLink?
private var animStartTime: CFTimeInterval = 0
private var animDuration: CFTimeInterval = 0.25

// 시작값
private var animStartVirtualColumns: CGFloat = 0
private var animStartAnchorPointX: CGFloat = 0  // anchorPointInView.x 시작값
private var animStartContentOffsetY: CGFloat = 0

// 목표값
private var animTargetVirtualColumns: CGFloat = 0
private var animTargetAnchorPointX: CGFloat = 0  // 정상 위치 (xOffset=0이 되는 X)
private var animTargetContentOffsetY: CGFloat = 0

private var animCompletion: (() -> Void)?

func animateToTarget(_ target: GridColumnCount, completion: @escaping () -> Void) {
    let targetValue = CGFloat(target.rawValue)

    // 이미 도달했으면 즉시 완료
    if abs(layout.virtualColumns - targetValue) < 0.01 && abs(layout.xOffset) < 0.01 {
        completion()
        return
    }

    // 시작값 저장
    animStartVirtualColumns = layout.virtualColumns
    animStartAnchorPointX = pinchState.anchorPointInView.x
    animStartContentOffsetY = collectionView.contentOffset.y

    // 목표값 설정
    animTargetVirtualColumns = targetValue
    animTargetAnchorPointX = calculateTargetAnchorPointX(for: target)  // xOffset=0이 되는 X
    animTargetContentOffsetY = calculateTargetContentOffsetY(for: target)

    animStartTime = CACurrentMediaTime()
    animCompletion = completion

    displayLink?.invalidate()
    displayLink = CADisplayLink(target: self, selector: #selector(animationTick))
    displayLink?.add(to: .main, forMode: .common)
}

/// 목표 열 수에서 xOffset=0이 되는 anchorPointInView.x 계산
func calculateTargetAnchorPointX(for target: GridColumnCount) -> CGFloat {
    guard let anchorAssetID = pinchState.anchorAssetID,
          let anchorIndexPath = indexPath(for: anchorAssetID, padding: pinchState.frozenPaddingCellCount) else {
        return pinchState.anchorPointInView.x
    }

    let targetColumns = CGFloat(target.rawValue)
    let effectiveColumns = max(1, Int(ceil(targetColumns)))
    let totalSpacing = spacing * (targetColumns - 1)
    let itemWidth = (collectionView.bounds.width - totalSpacing) / targetColumns

    let anchorCol = anchorIndexPath.item % effectiveColumns
    // 앵커 셀의 정상 중심 X (xOffset=0일 때의 위치)
    let anchorNormalCenterX = CGFloat(anchorCol) * (itemWidth + spacing) + itemWidth / 2

    return anchorNormalCenterX
}

/// 목표 열 수에서의 앵커 기반 contentOffsetY 계산
func calculateTargetContentOffsetY(for target: GridColumnCount) -> CGFloat {
    guard let anchorAssetID = pinchState.anchorAssetID,
          let anchorIndexPath = indexPath(for: anchorAssetID, padding: pinchState.frozenPaddingCellCount) else {
        return collectionView.contentOffset.y
    }

    let targetColumns = CGFloat(target.rawValue)
    let effectiveColumns = max(1, Int(ceil(targetColumns)))
    let totalSpacing = spacing * (targetColumns - 1)
    let itemWidth = (collectionView.bounds.width - totalSpacing) / targetColumns
    let itemHeight = itemWidth

    let anchorRow = anchorIndexPath.item / effectiveColumns
    let anchorCenterY = CGFloat(anchorRow) * (itemHeight + spacing) + itemHeight / 2

    // 목표 anchorPointInView.y도 보간된 값 사용해야 하지만,
    // Y축은 contentOffset으로 처리하므로 원래 위치 유지
    return anchorCenterY - pinchState.anchorPointInView.y
}
```

### 7.2 애니메이션 틱

```swift
@objc private func animationTick() {
    let elapsed = CACurrentMediaTime() - animStartTime
    let progress = min(elapsed / animDuration, 1.0)

    // easeOut 곡선
    let eased = 1 - pow(1 - progress, 3)

    // virtualColumns 보간
    let newVirtualColumns = animStartVirtualColumns + (animTargetVirtualColumns - animStartVirtualColumns) * CGFloat(eased)

    // anchorPointInView.x 보간 (v6 핵심!)
    // → 이렇게 하면 레이아웃의 prepare()에서 xOffset이 자동으로 0으로 수렴
    let newAnchorPointX = animStartAnchorPointX + (animTargetAnchorPointX - animStartAnchorPointX) * CGFloat(eased)
    pinchState.anchorPointInView.x = newAnchorPointX
    layout.anchorPointInView.x = newAnchorPointX  // 레이아웃에도 동기화!

    // 레이아웃 업데이트
    layout.virtualColumns = newVirtualColumns
    collectionView.layoutIfNeeded()

    // contentOffsetY 보간
    let newOffsetY = animStartContentOffsetY + (animTargetContentOffsetY - animStartContentOffsetY) * CGFloat(eased)
    collectionView.contentOffset.y = clampOffsetY(newOffsetY)

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

**v5 대비 핵심 변경점:**
- `newXOffset` 계산 후 미적용 문제 해결
- `anchorPointInView.x`를 보간하여 xOffset이 자연스럽게 0으로 수렴
- X축 점프 문제(문제 #1, #5) 원천 차단

---

## 8. fadeIn 처리 (v6 상세화)

### 8.1 fadeIn 트리거

```swift
func triggerFadeIn(target: GridColumnCount) {
    let targetSize = thumbnailSize(for: target)
    let token = UUID().uuidString
    let requestedTarget = target

    // 현재 visible 셀 캡처 (fadeIn 대상)
    let visibleCells = visiblePhotoCells()

    for cell in visibleCells {
        // 앵커 셀 제외
        guard cell.assetID != pinchState.anchorAssetID else { continue }

        cell.fadeToken = token

        imagePipeline.loadThumbnail(
            for: cell.assetID,
            targetSize: targetSize,
            priority: .high
        ) { [weak cell, weak self] image in
            guard let cell = cell, let self = self else { return }

            // 토큰 검증 (요청 취소 대응)
            guard cell.fadeToken == token else { return }

            // 목표 열 수 검증 (다단계 핀치 대응)
            guard self.pinchState.currentStageTarget == requestedTarget else { return }

            guard let image = image else { return }

            // fadeIn 애니메이션 실행 (v6 상세화)
            cell.fadeInImage(image, duration: 0.2)
        }
    }
}
```

### 8.2 PhotoCell fadeIn 구현 (v6 상세화)

```swift
// PhotoCell 내부

/// fadeIn 토큰 (비동기 로딩 검증용)
var fadeToken: String?

/// 오버레이 이미지뷰 (fadeIn용)
private var overlayImageView: UIImageView?

/// fadeIn 애니메이션으로 이미지 교체
func fadeInImage(_ image: UIImage, duration: TimeInterval = 0.2) {
    // 이미 같은 이미지면 스킵
    if imageView.image == image { return }

    // 오버레이 생성
    let overlay = UIImageView(image: image)
    overlay.frame = imageView.bounds
    overlay.contentMode = imageView.contentMode
    overlay.alpha = 0
    addSubview(overlay)

    // 이전 오버레이 정리
    overlayImageView?.removeFromSuperview()
    overlayImageView = overlay

    // fadeIn 애니메이션
    UIView.animate(withDuration: duration, delay: 0, options: .curveEaseOut) {
        overlay.alpha = 1.0
    } completion: { [weak self] finished in
        guard finished else { return }

        // 애니메이션 완료 후 메인 이미지 교체
        self?.imageView.image = image
        overlay.removeFromSuperview()

        if self?.overlayImageView === overlay {
            self?.overlayImageView = nil
        }
    }
}

/// 셀 재사용 시 정리
override func prepareForReuse() {
    super.prepareForReuse()
    fadeToken = nil
    overlayImageView?.removeFromSuperview()
    overlayImageView = nil
}
```

### 8.3 visible 셀 조회

```swift
func visiblePhotoCells() -> [PhotoCell] {
    let padding = pinchState.frozenPaddingCellCount

    return collectionView.visibleCells.compactMap { cell -> PhotoCell? in
        guard let photoCell = cell as? PhotoCell else { return nil }

        // padding 셀 제외
        if let indexPath = collectionView.indexPath(for: cell),
           indexPath.item < padding {
            return nil
        }

        return photoCell
    }
}
```

### 8.4 썸네일 크기 계산

```swift
func thumbnailSize(for columns: GridColumnCount) -> CGSize {
    let spacing: CGFloat = 2
    let totalSpacing = spacing * CGFloat(columns.rawValue - 1)
    let itemWidth = (collectionView.bounds.width - totalSpacing) / CGFloat(columns.rawValue)
    let scale = UIScreen.main.scale

    return CGSize(width: itemWidth * scale, height: itemWidth * scale)
}
```

---

## 9. Prefetch 전략 (축소 시)

```swift
func expandPrefetchForPinch(direction: ZoomDirection) {
    guard direction == .zoomOut else { return }

    // 핀치 중 확장된 가시 영역
    let visibleRect = collectionView.bounds
    let expansion = layout.itemWidth * 2
    let expandedRect = visibleRect.insetBy(dx: -expansion, dy: -expansion)

    // content 좌표로 변환
    let contentRect = expandedRect.offsetBy(
        dx: collectionView.contentOffset.x,
        dy: collectionView.contentOffset.y
    )

    // 해당 영역의 indexPath 조회
    if let attributes = layout.layoutAttributesForElements(in: contentRect) {
        let indexPaths = attributes.map { $0.indexPath }
        prefetchAssets(for: indexPaths)
    }
}
```

---

## 10. 회전 처리

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
        self.layout.invalidateLayout()
        self.collectionView.layoutIfNeeded()
        self.updateCellSize()
        self.updateContentInset()

    }, completion: { [weak self] _ in
        guard let self = self else { return }

        // 회전 완료 후 paddingCellCount 업데이트
        let newPadding = self.calculatePaddingCount(for: newColumns.rawValue)
        if self.layout.frozenPaddingCellCount != newPadding {
            self.layout.frozenPaddingCellCount = newPadding
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

## 11. 검증 포인트 (구현 후 확인)

### 11.1 문제 1 검증 (X축)
```swift
// 테스트: 핀치 중심이 화면 우측일 때
// 기대: layout.xOffset < 0 (좌측으로 당겨짐)
// 결과: 우측이 고정되고 좌측으로 확장
```

### 11.2 문제 2 검증 (스크롤 점프)
```swift
// 테스트: 핀치 시작 직후 앵커 셀 위치 확인
// 기대: anchorPointInView와 실제 셀 위치가 일치
// 확인: layout.calculatedContentOffsetY 적용 후에도 일치
```

### 11.3 문제 3 검증 (클리핑)
```swift
// 테스트: 축소 중 화면 가장자리 확인
// 기대: 새 셀이 잘린 채로 보임
// 확인: collectionView.clipsToBounds == false
```

### 11.4 문제 4 검증 (10% 규칙)
```swift
// 테스트: 3열에서 축소 10% 후 손 뗌
// 계산: progress = (3.2 - 3.0) / (5.0 - 3.0) = 0.1
// 기대: 5열로 스냅
```

---

## 12. v5 코드와 v6 코드 비교 요약

### 12.1 레이아웃 계산

```swift
// ===== v5 (문제 발생) =====
let x = CGFloat(col) * (itemWidth + spacing)
// → xOffset 없음, X축 항상 좌측 고정

// ===== v6 (해결) =====
let normalX = CGFloat(col) * (itemWidth + spacing)
let finalX = normalX + xOffset
// → xOffset으로 X축 앵커 고정
```

### 12.2 offset 보정 타이밍

```swift
// ===== v5 (문제 발생) =====
layout.invalidateLayout()
collectionView.layoutIfNeeded()  // 화면 갱신 (offset 틀어짐!)
updateContentOffsetForAnchor()   // 뒤늦은 보정

// ===== v6 (해결) =====
layout.invalidateLayout()
collectionView.layoutIfNeeded()  // prepare()에서 이미 앵커 기준 계산 완료
collectionView.contentOffset.y = layout.calculatedContentOffsetY  // Y축만 적용
// X축은 레이아웃 내부 xOffset으로 이미 처리됨
```

### 12.3 진행도 계산

```swift
// ===== v5 (문제 발생) =====
func stageBase() -> GridColumnCount {
    let current = layout.virtualColumns  // 현재 값 기준 → 계속 변함!
    // ...
}

// ===== v6 (해결) =====
// 스냅 판단용 (10%/50% 규칙)
func computeSnapProgress() -> CGFloat {
    let base = pinchState.snapBaseColumns       // 고정값! (핀치 전체 기준)
    let target = CGFloat(pinchState.snapTargetColumns.rawValue)
    // ...
}

// 단계용 (fadeIn 트리거)
func computeStageProgress() -> CGFloat {
    let base = pinchState.stageBaseColumns      // 기준점 통과 시 재설정
    let target = CGFloat(pinchState.stageTargetColumns.rawValue)
    // ...
}
```

### 12.4 방향 전환 감지

```swift
// ===== v5 (문제 발생) =====
let current = currentDirection(virtualColumns: virtualColumns)
if current != initialDirection {
    pinchState.didReverse = true  // 미세한 떨림에도 true!
}

// ===== v6 (해결) =====
let delta = currentProgress - pinchState.lastProgressForDirectionCheck
if delta < -directionChangeThreshold {  // 5% 이상 반대로 움직여야
    pinchState.didReverse = true
}
```

---

## 13. dataSource 변경 차단 (v6 추가)

### 13.1 문제 상황

핀치 중 사진 삭제/추가 시:
- `frozenItemCount`와 실제 데이터 불일치
- 레이아웃 크래시 또는 잘못된 셀 표시
- 앵커 셀이 사라지면 스크롤 점프

### 13.2 구현

```swift
// GridViewController에 추가
private var pendingPhotoLibraryChanges: [PHChange] = []
private var isPinching: Bool { pinchState.isActive }

// PHPhotoLibraryChangeObserver
func photoLibraryDidChange(_ changeInstance: PHChange) {
    DispatchQueue.main.async { [weak self] in
        guard let self = self else { return }

        if self.isPinching {
            // 핀치 중: 변경 사항 큐에 저장
            self.pendingPhotoLibraryChanges.append(changeInstance)
            return
        }

        // 핀치 아닐 때: 즉시 적용
        self.applyPhotoLibraryChange(changeInstance)
    }
}

// 핀치 종료 시 호출
func applyPendingPhotoLibraryChanges() {
    guard !pendingPhotoLibraryChanges.isEmpty else { return }

    // 마지막 변경 사항만 적용 (중간 상태 스킵)
    if let lastChange = pendingPhotoLibraryChanges.last {
        applyPhotoLibraryChange(lastChange)
    }

    pendingPhotoLibraryChanges.removeAll()
}

// handlePinchEnded에서 호출
func handlePinchEnded(_ gesture: UIPinchGestureRecognizer) {
    // ... 기존 코드 ...

    animateToTarget(finalTarget) { [weak self] in
        guard let self = self else { return }

        // ... 기존 완료 처리 ...

        // 지연된 데이터 변경 적용
        self.applyPendingPhotoLibraryChanges()
    }
}
```

### 13.3 앵커 셀 삭제 대응

```swift
func applyPhotoLibraryChange(_ change: PHChange) {
    // 앵커 셀이 삭제된 경우 처리
    if let anchorAssetID = pinchState.anchorAssetID,
       !gridDataSource.contains(assetID: anchorAssetID) {
        // 앵커 재설정 (화면 중앙 셀로)
        let centerIndexPath = indexPathForCenterCell()
        if let newAnchorID = assetID(for: centerIndexPath, padding: paddingCellCount) {
            pinchState.anchorAssetID = newAnchorID
            // 레이아웃에도 동기화
            layout.setAnchor(indexPath: centerIndexPath, pointInView: collectionView.center)
        }
    }

    // 일반적인 변경 사항 적용
    // ...
}
```

### 13.4 체크리스트

- [ ] `isPinching` 체크하여 변경 지연
- [ ] 핀치 종료 시 `applyPendingPhotoLibraryChanges()` 호출
- [ ] 앵커 셀 삭제 시 재설정 로직

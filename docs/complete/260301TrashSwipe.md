# 삭제대기함 스와이프 복구 (녹색 커튼) 구현 계획

## Context

삭제대기함(TrashAlbumViewController)에 그리드 스와이프 제스처를 적용하여 사진을 복구(restore)하는 기능을 추가한다. 보관함에서 빨간 커튼이 채워지며 삭제되는 것과 대칭적으로, 삭제대기함에서는 **녹색 커튼**이 채워지며 복구된다.

**동작 요약:**
- 스와이프 → 녹색 커튼 채워짐 → 확정 → 셀 사라짐 (보관함으로 복구)
- 단일 셀 + 멀티 셀 스와이프 모두 지원
- 확정 후 `trashStore.restore()` 호출 → `onStateChange` → `loadTrashedAssets()` → 셀 자동 제거

**핵심 기술 이슈:**
- `confirmSwipeDelete`가 `private` → 오버라이드 불가, 프로퍼티 기반 분기 필요
- 삭제대기함 셀은 `cell.isTrashed = false`(표시용)이므로 기존 로직이 "삭제"로 판단 → 액션만 "복구"로 라우팅 필요
- 멀티 스와이프의 "이미 대상 상태" 체크가 잘못 작동 (모든 셀이 trashStore에서 trashed) → 분기 추가 필요

---

## Phase 1: PhotoCell — 녹색 오버레이 지원

**파일:** `PickPhoto/PickPhoto/Features/Grid/PhotoCell.swift`

### 1-1. SwipeOverlayStyle enum 추가 (~line 25 부근, 상수 영역)
```swift
enum SwipeOverlayStyle {
    case delete   // Maroon (기존)
    case restore  // Green (신규)
}
```

### 1-2. 상수 및 프로퍼티 추가
```swift
// 상수
private static let defaultOverlayColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)  // 기존 마룬색
private static let restoreOverlayColor = UIColor(red: 0.0, green: 0.35, blue: 0.15, alpha: 1)  // 다크 그린

// 프로퍼티
var swipeOverlayStyle: SwipeOverlayStyle = .delete
```

### 1-3. 오버레이 색상 전환 메서드
```swift
func prepareSwipeOverlay(style: SwipeOverlayStyle) {
    swipeOverlayStyle = style
    dimmedOverlayView.backgroundColor = (style == .restore)
        ? Self.restoreOverlayColor
        : Self.defaultOverlayColor
}
```

### 1-4. prepareForReuse에 색상 리셋 추가 (~line 345)
셀 재사용 시 녹색이 남는 것을 방지:
```swift
// prepareForReuse() 내 기존 초기화 코드 뒤에:
dimmedOverlayView.backgroundColor = Self.defaultOverlayColor
swipeOverlayStyle = .delete
```

### 1-5. confirmDimmedAnimation 수정 (~line 876)
completion 블록에서 trashIconView 억제 + 색상 리셋:
```swift
// completion 블록 내 (기존 코드 뒤에):
// 복구 모드에서는 trashIcon 표시 안 함
if self.swipeOverlayStyle == .restore {
    self.trashIconView.isHidden = true
}
// 색상 리셋
self.dimmedOverlayView.backgroundColor = Self.defaultOverlayColor
self.swipeOverlayStyle = .delete
```

### 1-6. cancelDimmedAnimation 수정 (~line 909)
completion 블록에서 색상 리셋:
```swift
// completion 블록 내 (기존 코드 뒤에):
self.dimmedOverlayView.backgroundColor = Self.defaultOverlayColor
self.swipeOverlayStyle = .delete
```

---

## Phase 2: BaseGridViewController — 단일 스와이프 액션 분기

**파일:** `BaseGridViewController.swift`

### 2-1. 프로퍼티 추가 (~line 174 부근, supportsSwipeDelete 옆)
```swift
/// 스와이프 동작이 복구(restore)인지 여부 (삭제대기함에서 true)
var swipeActionIsRestore: Bool { false }
```

### 2-2. handleSwipeDeleteBegan 수정 (~line 880, cell.isAnimating = true 직전)
```swift
// 복구 모드: 녹색 오버레이 준비
if swipeActionIsRestore {
    cell.prepareSwipeOverlay(style: .restore)
}
cell.isAnimating = true
HapticFeedback.prepare()
```

### 2-3. confirmSwipeDelete 수정 (~line 1054)
코치마크 + 액션 라우팅 분기:
```swift
cell.confirmDimmedAnimation(toTrashed: toTrashed) { [weak self] in
    guard let self = self else { return }

    if self.swipeActionIsRestore {
        // ★ 삭제대기함: 항상 복구, 코치마크 스킵
        AnalyticsService.shared.countTrashRestore()
        self.trashStore.restore(assetID) { [weak self] result in
            self?.handleSwipeResult(result, cell: cell)
        }
    } else if toTrashed {
        // 보관함/앨범: 삭제 + 코치마크 가이드
        AnalyticsService.shared.countGridSwipeDelete(source: analyticsSource)
        self.trashStore.moveToTrash(assetID) { [weak self] result in
            self?.handleSwipeResult(result, cell: cell)
            if case .success = result {
                // A-1/E-1/E-2 코치마크 로직 (기존 그대로)
                ...
            }
        }
    } else {
        // 보관함/앨범: 복구
        AnalyticsService.shared.countGridSwipeRestore(source: analyticsSource)
        self.trashStore.restore(assetID) { [weak self] result in
            self?.handleSwipeResult(result, cell: cell)
        }
    }
}
```
**주의:** `swipeActionIsRestore` 분기에서 `showDeleteSystemGuideIfNeeded` 및 A-1 코치마크 로직을 호출하지 않아야 함.

### 2-4. cellForItemAt 멀티 스와이프 재사용 경로 수정 (~line 704)
자동 스크롤로 재사용된 셀에 녹색 설정 누락 방지:
```swift
// 기존: 다중 스와이프 중이면 딤드 상태 복원
if swipeDeleteState.isMultiMode && swipeDeleteState.selectedItems.contains(indexPath.item) {
    // ★ 복구 모드 색상 재적용
    if swipeActionIsRestore {
        cell.prepareSwipeOverlay(style: .restore)
    }
    if swipeDeleteState.deleteAction {
        cell.setFullDimmed(isTrashed: isTrashed)
    } else {
        cell.setRestoredPreview()
    }
}
```

---

## Phase 3: BaseMultiSwipeDelete — 멀티 스와이프 분기

**파일:** `BaseMultiSwipeDelete.swift`

### 3-1. enterMultiSwipeMode 수정 (~line 53)
앵커 셀 커튼 애니메이션 전에 색상 설정:
```swift
if let anchorCell = collectionView.cellForItem(at: anchorIndexPath) as? PhotoCell,
   let gesture = swipeDeleteState.swipeGesture {
    // ★ 복구 모드 색상 준비 (이미 began에서 설정되었을 수 있지만 안전하게)
    if swipeActionIsRestore {
        anchorCell.prepareSwipeOverlay(style: .restore)
    }
    let translation = gesture.translation(in: collectionView)
    ...
    anchorCell.animateCurtainToTarget(...)
}
```

### 3-2. handleMultiSwipeChanged — 새 셀/커튼 셀 색상 설정
**added cells 루프** (~line 186):
```swift
for item in added {
    if item == curtainCandidate { continue }
    if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
        if swipeActionIsRestore { cell.prepareSwipeOverlay(style: .restore) }
        applyTargetState(to: cell, deleteAction: deleteAction)
    }
}
```

**커튼 후보 셀** (~line 220 부근):
```swift
if let cell = collectionView.cellForItem(at: curtainIP) as? PhotoCell {
    if swipeActionIsRestore { cell.prepareSwipeOverlay(style: .restore) }
    cell.setDimmedProgress(progress, direction: direction, isTrashed: ...)
}
```

**이전 커튼 셀 → 대상 상태 전환** (~line 176):
```swift
if swipeActionIsRestore { cell.prepareSwipeOverlay(style: .restore) }
applyTargetState(to: cell, deleteAction: deleteAction)
```

### 3-3. confirmMultiSwipeDelete 수정 (~line 300)

**"이미 대상 상태" 체크 수정 (핵심!):**
```swift
let alreadyInTargetState: Bool
if swipeActionIsRestore {
    // 복구 모드: 대상 = "not trashed" → 이미 복구된 것만 스킵
    alreadyInTargetState = !trashStore.isTrashed(assetID)
} else {
    alreadyInTargetState = deleteAction
        ? trashStore.isTrashed(assetID)
        : !trashStore.isTrashed(assetID)
}
```

**TrashStore 호출 분기:**
```swift
if swipeActionIsRestore {
    trashStore.restore(assetIDs: assetIDsToProcess)
} else if deleteAction {
    trashStore.moveToTrash(assetIDs: assetIDsToProcess)
} else {
    trashStore.restore(assetIDs: assetIDsToProcess)
}
```

**Analytics 분기:**
```swift
for _ in assetIDsToProcess {
    if swipeActionIsRestore {
        AnalyticsService.shared.countTrashRestore()
    } else if deleteAction {
        AnalyticsService.shared.countGridSwipeDelete(source: analyticsSource)
    } else {
        AnalyticsService.shared.countGridSwipeRestore(source: analyticsSource)
    }
}
```

---

## Phase 4: TrashAlbumViewController — 활성화 및 설정

**파일:** `TrashAlbumViewController.swift`

### 4-1. 스와이프 활성화 프로퍼티 오버라이드
```swift
override var supportsSwipeDelete: Bool { true }
override var swipeActionIsRestore: Bool { true }
```

### 4-2. updateSwipeDeleteGestureEnabled 오버라이드
Select 모드 진입 시 스와이프 비활성화 (GridViewController와 동일 패턴):
```swift
override func updateSwipeDeleteGestureEnabled() {
    let enabled = !isSelectMode && !UIAccessibility.isVoiceOverRunning
    swipeDeleteState.swipeGesture?.isEnabled = enabled
}
```

### 4-3. onStateChange 핸들러 수정 위치
수정 대상: `viewWillAppear`의 핸들러 (line 156). `setupObservers` (line 198)도 동일 핸들러를 등록하지만 viewWillAppear가 매번 덮어쓰므로 line 156이 실제 활성 핸들러.

> **Note:** onStateChange → reloadData 타이밍 충돌 위험은 분석 결과 낮음. TrashStore의 `notifyChange()`는 `DispatchQueue.main.async`로 전달되고, 이후 background fetch → main async reloadData 경로를 거치므로 0.15s 애니메이션 완료 후에 reloadData가 도달함. 별도 가드 조건 없이 진행하되, 실기기 테스트에서 애니메이션 깨짐이 발생하면 그때 전용 플래그 추가.

---

## Analytics 참고

- **DeleteSource enum에 .trash 추가 불필요** — 기존 설계에서 삭제대기함은 이벤트 4-2로 별도 추적
- 삭제대기함 스와이프 복구: `countTrashRestore()` 사용 (기존 메서드, source 파라미터 없음)
- 파일: `AnalyticsService+DeleteRestore.swift:103`

---

## 수정 파일 요약

| 파일 | 변경 내용 | 예상 규모 |
|------|---------|---------|
| `PhotoCell.swift` | SwipeOverlayStyle enum, 녹색 상수, prepareSwipeOverlay(), prepareForReuse 리셋, confirm/cancel 리셋 | ~35줄 |
| `BaseGridViewController.swift` | swipeActionIsRestore 프로퍼티, began 색상설정, confirm 분기(코치마크 스킵), cellForItemAt 재사용 색상 | ~30줄 |
| `BaseMultiSwipeDelete.swift` | enter/changed 색상설정, 대상 상태 체크, 액션/애널리틱스 분기 | ~35줄 |
| `TrashAlbumViewController.swift` | supportsSwipeDelete, swipeActionIsRestore, gesture enable 오버라이드 | ~15줄 |

---

## Verification

1. **단일 스와이프 복구**: 삭제대기함에서 사진 스와이프 → 녹색 커튼 채워짐 → 50% 또는 800pt/s로 확정 → 셀 사라짐, 보관함에서 복구 확인
2. **단일 스와이프 취소**: 스와이프 도중 취소 → 녹색 걷히고 원래 상태 복귀, 색상 마룬으로 리셋 확인
3. **멀티 스와이프 복구**: 여러 셀 범위 선택 → 모두 녹색 → 확정 → 모두 복구, 셀 사라짐
4. **멀티 스와이프 자동스크롤**: 멀티 스와이프 중 자동 스크롤 → 재사용 셀이 녹색으로 정상 표시
5. **멀티 스와이프 취소**: 범위 선택 후 취소 → 모든 셀 원래 상태 복귀
6. **Select 모드 전환**: Select 모드 진입 시 스와이프 비활성화, 해제 시 재활성화
7. **보관함 기존 동작 회귀**: 보관함/앨범의 빨간 스와이프 삭제/복구가 변경 없이 동작하는지
8. **코치마크 미작동**: 삭제대기함 스와이프 시 E-1/E-2 코치마크 가이드가 트리거되지 않는지
9. **셀 재사용 색상**: 스와이프 취소 후 셀 재사용 시 마룬색으로 복귀하는지
10. **빌드 확인**: `xcodebuild -project PickPhoto/PickPhoto.xcodeproj -scheme PickPhoto -destination 'platform=iOS Simulator,name=iPhone 17'`

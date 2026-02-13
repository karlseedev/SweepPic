# 휴지통 복구 후 그리드 미반영 버그 분석

> 작성일: 2026-02-12

## 1. 증상

휴지통에서 사진을 복구하면 메인 그리드(사진보관함)에 실시간으로 반영되지 않음.
복구된 사진의 딤드 오버레이가 유지되거나, 그리드가 최신 상태로 갱신되지 않음.

---

## 2. 근본 원인

### 2.1 원흉 커밋: `5874234` (2025-12-31)

**"iOS 18+ Zoom Transition 안정화 및 성능 최적화"**

iOS 18 네이티브 `.zoom` 전환(`preferredTransition = .zoom`) 도중 `reloadData()`가 호출되면
시스템 스냅샷과 실제 뷰가 불일치하여 셀이 깜빡이는 문제가 있었음.

이를 해결하기 위해 다음 변경을 수행:

**변경 1 — `viewerWillClose()`에서 `reloadData()` 제거:**
```swift
// Before
func viewerWillClose(currentAssetID: String?) {
    collectionView.reloadData()        // ← 깜빡임 유발
    // ... scrollToItem
}

// After
func viewerWillClose(currentAssetID: String?) {
    pendingScrollAssetID = currentAssetID  // 저장만
}
```

**변경 2 — `viewWillAppear`에 `transitionCoordinator` 분기 추가:**
```swift
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    handleTrashStateChange(trashStore.trashedAssetIDs)

    if !hasFinishedInitialDisplay { return }

    // ← 이 분기가 추가됨
    if let coordinator = transitionCoordinator {
        coordinator.animate(alongsideTransition: nil) { [weak self] _ in
            self?.applyPendingViewerReturn()  // scroll만 수행
        }
        return  // ← reloadData()에 도달 못함
    }

    collectionView.reloadData()  // ← 여기 도달 못함
}
```

**변경 3 — 신규 `applyPendingViewerReturn()` 함수:**
```swift
// "reloadData() 제거: 변경은 viewerDidRequest*에서 이미 reloadItems() 처리됨"
// scroll만 수행
private func applyPendingViewerReturn() {
    guard let assetID = pendingScrollAssetID else { return }
    pendingScrollAssetID = nil
    // ... scroll 로직만
}
```

### 2.2 이 전제가 깨지는 이유

`5874234`의 전제: **"viewerDidRequest*에서 이미 reloadItems()로 처리됨"**

이 전제는 **같은 VC가 delegate인 뷰어 복귀**에서만 성립함.

- 휴지통 탭에서 복구 → `TrashAlbumVC.viewerDidRequestRestore()` 실행 → **GridVC의 reloadItems는 호출된 적 없음**
- Grid 탭으로 전환 → `viewWillAppear` → `transitionCoordinator` 존재 시 → `reloadData()` 스킵 → **미반영**

### 2.3 네이티브 .zoom은 이미 제거됨

| 날짜 | 커밋 | 내용 |
|------|------|------|
| 12/31 | `5874234` | 네이티브 `.zoom` 깜빡임 → reloadData() 제거 + transitionCoordinator 분기 |
| 01/20 | `f9511ed` | 단일 핸들러 덮어쓰기 → viewWillAppear 재등록 워크어라운드 |
| 01/29 | `6261dac` | **네이티브 `.zoom` 완전 제거** → 커스텀 줌 트랜지션으로 전환 |
| 01/30 | `d4ce98b` | Navigation Push → Modal 전환 |
| 이후 | `374ffdf` | iOS 26+만 다시 Navigation Push |

**`5874234`의 원래 문제(네이티브 .zoom 깜빡임)는 더 이상 존재하지 않음.**
그런데 그 대응책(reloadData 제거)만 잔존하여 버그를 유발하고 있음.

---

## 3. 부수 문제: 단일 핸들러 구조

### 3.1 현재 구조

`TrashStore.changeHandler`가 단일 변수로, 마지막 등록된 VC의 핸들러만 동작:
```swift
// TrashStore.swift:114
private var changeHandler: ((Set<String>) -> Void)?

public func onStateChange(_ handler: @escaping (Set<String>) -> Void) {
    self.changeHandler = handler  // 이전 핸들러 덮어씀
}
```

### 3.2 f9511ed의 워크어라운드

각 VC의 `viewWillAppear`에서 핸들러를 재등록:
```swift
trashStore.onStateChange { [weak self] trashedAssetIDs in
    self?.handleTrashStateChange(trashedAssetIDs)
}
handleTrashStateChange(trashStore.trashedAssetIDs)
```

### 3.3 다중 구독이 근본 해결이 아닌 이유

다중 구독으로 바꾸면 **오히려 악화**될 수 있음:

1. Grid 백그라운드 → 알림 받음 → `handleTrashStateChange` 호출
2. `indexPathsForVisibleItems` 비어있음 → 셀 업데이트 안 됨
3. **하지만 `lastTrashedIDs`는 갱신됨** (563행)
4. 탭 복귀 시 `handleTrashStateChange(currentIDs)` → `changedIDs = empty` → **아무것도 안 함**
5. 기존 단일 핸들러에서는 `lastTrashedIDs`가 유지되어 diff 감지가 정확했음

---

## 4. 수정 계획

### 4.1 핵심 수정: transitionCoordinator completion에서 reloadData() 추가

**GridViewController, AlbumGridViewController** 두 곳에 적용.

`viewWillAppear`의 transitionCoordinator completion에서:
```swift
if let coordinator = transitionCoordinator {
    coordinator.animate(alongsideTransition: nil) { [weak self] _ in
        self?.applyPendingViewerReturn()
        self?.collectionView.reloadData()  // ← 추가
    }
    return
}
```

### 4.2 수정이 안전한 근거

| 항목 | 분석 |
|------|------|
| **깜빡임** | completion은 전환 애니메이션 완료 후 → 구조적으로 깜빡임 불가 |
| **이중 갱신** | viewerDidRequest*의 reloadItems와 중복되지만, 메모리 캐시 히트로 체감 없음 |
| **lastTrashedIDs** | handleTrashStateChange에서 이미 갱신 → changedIDs = empty → 충돌 없음 |
| **cellForItemAt** | `trashStore.isTrashed()` 직접 조회 → reloadData 시 항상 최신 상태 |
| **탭 전환** | transitionCoordinator nil → 기존 reloadData() 경로 그대로 유지 |

### 4.3 viewDidAppear fallback 이중 호출 방지

현재 `viewDidAppear`에서도 `applyPendingViewerReturn()`을 호출함.
`reloadData()`를 추가하면 이중 호출 위험 → **별도 플래그** 필요:

```swift
private var needsReloadOnTransitionComplete = false

// viewWillAppear
if let coordinator = transitionCoordinator {
    needsReloadOnTransitionComplete = true
    coordinator.animate(alongsideTransition: nil) { [weak self] _ in
        self?.completeTransitionReturn()
    }
    return
}

// viewDidAppear (fallback)
if needsReloadOnTransitionComplete {
    completeTransitionReturn()
}

private func completeTransitionReturn() {
    guard needsReloadOnTransitionComplete else { return }
    needsReloadOnTransitionComplete = false
    applyPendingViewerReturn()
    collectionView.reloadData()
}
```

### 4.4 VC별 수정 필요 여부

| VC | 현재 reloadData | 수정 필요? | 비고 |
|----|----------------|-----------|------|
| **GridViewController** | completion에 없음 | **필요** | 메인 그리드 |
| **AlbumGridViewController** | completion에 없음, viewWillAppear에도 없음 | **필요** | 앨범 상세 |
| TrashAlbumViewController | `loadTrashedAssets()` → `reloadData()` 경로 있음 | 불필요 | 이미 동작함 |

### 4.5 주의사항

- `applyPendingViewerReturn()` 내부가 아닌 **호출하는 쪽**에서 `reloadData()` 실행
  - 이유: `pendingScrollAssetID == nil`이면 `applyPendingViewerReturn()`이 조기 리턴하여 내부 코드 도달 불가
- 단일 핸들러 구조는 이번 수정 범위가 아님 (현재 viewWillAppear 재등록 워크어라운드로 충분)

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

---

## 5. 수정 시도 #1: 실패 기록

### 5.1 수정 내용

섹션 4의 계획대로 GridViewController, AlbumGridViewController의 `transitionCoordinator` completion에 `reloadData()` 추가.

- 체크포인트: `46f8ca2`
- 수정 후 테스트 → **실패** → 수동 롤백

### 5.2 실패 원인

**증상을 잘못 파악함.**

- "그리드에 반영이 안 됨" → "메인 사진보관함 그리드(GridViewController)"로 해석
- 증상을 "딤드 오버레이가 유지됨"으로 추측

**실제 증상**: 휴지통 뷰어에서 사진을 복구한 후 뷰어를 닫으면, **복구된 사진이 휴지통 그리드(TrashAlbumViewController)에서 사라지지 않음**.

GridViewController/AlbumGridViewController를 수정했으나, 문제의 VC는 TrashAlbumViewController였음.

---

## 6. 재분석: 실제 문제

### 6.1 문제를 잘못 파악한 이유

1. **"그리드"를 오해**: 사용자가 말한 "그리드"는 휴지통 그리드(TrashAlbumVC)인데, 메인 사진보관함(GridVC)으로 해석
2. **증상 추측**: "딤드 오버레이 유지"로 추측했으나, 실제로는 "복구된 사진이 휴지통 목록에서 안 사라짐"
3. **섹션 2~4의 분석 범위 오류**: `5874234` 커밋의 reloadData 제거 분석은 GridVC/AlbumGridVC에는 유효하지만, 실제 증상(TrashAlbumVC)과는 무관
4. **확인 없이 추측**: 증상을 정확히 모르는 상태에서 물어보지 않고 추측으로 진행

### 6.2 실제 증상

휴지통 뷰어에서 사진을 복구 → 뷰어 닫기 → **복구된 사진이 휴지통 그리드에 여전히 남아있음**

### 6.3 TrashAlbumViewController의 복구 → 갱신 설계 흐름

```
[뷰어에서 복구 버튼 탭]
viewerDidRequestRestore(assetID:)           ← TrashAlbumVC (delegate, 640행)
  → trashStore.restore(assetIDs:)           ← TrashStore
    → notifyChange()                        ← DispatchQueue.main.async로 dispatch
      → changeHandler                       ← loadTrashedAssets() 호출
        → isViewerOpen == true              ← 뷰어 열림 중이므로 지연!
        → pendingDataRefresh = true          ← 플래그만 저장

[뷰어 닫기]
ViewerVC.viewWillDisappear (366행)
  → delegate?.viewerWillClose()             ← TrashAlbumVC.viewerWillClose (679행)
    → pendingScrollAssetID = currentAssetID
    → isViewerOpen 유지 (true)              ← applyPendingViewerReturn에서 해제

[TrashAlbumVC lifecycle 복귀]
viewWillAppear → transitionCoordinator completion → applyPendingViewerReturn()
  → isViewerOpen = false                    (697행)
  → pendingDataRefresh == true → loadTrashedAssets() → reloadData() ✓
```

### 6.4 이 흐름이 깨지는 경우: iOS 16~25 Modal 경로

TrashAlbumVC에서 뷰어를 여는 두 가지 경로 (`openViewer`, 552행):

```swift
// iOS 26+: Navigation Push
navigationController?.pushViewController(viewerVC, animated: true)

// iOS 16~25: Modal (커스텀 줌 트랜지션)
present(viewerVC, animated: true)
```

**iOS 26+ (Navigation Push):**
- Pop 시 `viewWillAppear`/`viewDidAppear` **정상 호출** → `applyPendingViewerReturn()` 실행 → 정상 동작

**iOS 16~25 (Modal + `shouldRemovePresentersView = false`):**
- `ZoomPresentationController`의 `shouldRemovePresentersView = false` (ZoomPresentationController.swift:18)
- → present 시 TrashAlbumVC의 뷰가 제거되지 않음
- → `viewWillDisappear`/`viewDidDisappear` **미호출** (present 시)
- → dismiss 시 `viewWillAppear`/`viewDidAppear` **미호출**
- → **`applyPendingViewerReturn()` 호출되지 않음**
- → `pendingDataRefresh = true`이지만 처리 안 됨
- → `isViewerOpen = true` 유지 → 이후 `onStateChange` 콜백이 와도 `loadTrashedAssets()`가 계속 defer
- → **휴지통 그리드 갱신 안 됨** (탭 전환 후 복귀 시에만 복구)

### 6.5 핵심 원인 정리

| 경로 | viewWillAppear 호출? | applyPendingViewerReturn 호출? | 결과 |
|------|---------------------|-------------------------------|------|
| iOS 26+ Navigation Pop | ✅ | ✅ (transitionCoordinator + viewDidAppear) | 정상 |
| iOS 16~25 Modal dismiss | ❌ (`shouldRemovePresentersView=false`) | ❌ | **버그** |
| 탭 전환 후 복귀 | ✅ | ✅ (viewDidAppear fallback) | 지연 복구 |

**근본 원인**: presenting VC의 lifecycle(`viewWillAppear`/`viewDidAppear`)에 후처리(`applyPendingViewerReturn`)를 의존하는 설계 + iOS 16~25 Modal 경로에서 `shouldRemovePresentersView=false`가 해당 lifecycle 호출을 차단하는 조합. `pendingDataRefresh`가 처리되지 않고, `isViewerOpen`이 `true`로 유지됨.

---

## 7. 수정 계획 (v2)

### 7.1 핵심 문제

iOS 16~25 Modal dismiss 시 `viewWillAppear`/`viewDidAppear`가 호출되지 않아 `applyPendingViewerReturn()`이 트리거되지 않음.

### 7.2 수정 방안: `viewDidDisappear` + delegate `viewerDidClose`

현재 `viewerWillClose`는 ViewerVC의 `viewWillDisappear`에서 호출됨.
마찬가지로 **`viewDidDisappear`에서 `viewerDidClose` 콜백**을 추가하면 모든 경로에서 동작:

```
viewWillDisappear → viewerWillClose       ← 기존 (pendingScrollAssetID 저장)
  ↓ (dismiss 애니메이션 + sourceViewProvider 호출)
viewDidDisappear  → viewerDidClose        ← 신규 (applyPendingViewerReturn 실행)
```

**이 방식이 최적인 이유:**
- `viewDidDisappear`는 **완료된 dismiss/pop 경로**에서 호출됨 (normal, fade, interactive 완료, navigation pop)
- interactive dismiss **취소** 시에는 호출되지 않음 → 뷰어가 열린 상태 유지이므로 갱신 불필요 (의도된 동작)
- dismiss 애니메이션 **완료 후** 호출 → `sourceViewProvider` 호출 이후이므로 안전
- 별도의 completion handler 관리 불필요

### 7.3 구현 상세

**Step 1: ViewerViewControllerDelegate에 추가 (protocol extension으로 기본 no-op 제공)**
```swift
// ViewerViewControllerDelegate (ViewerViewController.swift:39)
func viewerDidClose()

// protocol extension - 기본 no-op (conformer 4개 모두에 빈 구현 불필요)
extension ViewerViewControllerDelegate {
    func viewerDidClose() {}
}
```

**Step 2: ViewerVC에 플래그 + viewDidDisappear 추가**

Apple SDK 헤더 권장에 따라 `isBeingDismissed`/`isMovingFromParent` 판별은 `viewWillDisappear`에서 수행.
`viewDidDisappear`에서는 플래그만 읽음:

```swift
// ViewerViewController.swift
private var isClosing = false  // viewWillDisappear에서 설정

override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    guard isBeingDismissed || isMovingFromParent else { return }
    isClosing = true  // ← 플래그 설정
    // ... 기존 viewerWillClose 호출 코드
}

override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)
    guard isClosing else { return }  // ← 플래그로 판별
    isClosing = false
    delegate?.viewerDidClose()
}
```

**Step 3: TrashAlbumVC에서 override**
```swift
// TrashAlbumViewController.swift (ViewerViewControllerDelegate extension)
func viewerDidClose() {
    applyPendingViewerReturn()
}
```

**Step 4: GridVC, AlbumGridVC에서도 override** (동일 구조 예방)
```swift
func viewerDidClose() {
    // iOS 26+ Navigation Pop에서는 viewDidAppear에서 이미 처리됨
    // iOS 16~25 Modal에서는 이 콜백으로 처리
    applyPendingViewerReturn()
}
```

**Step 5: PreviewGridVC** → protocol extension의 기본 no-op으로 충분 (별도 구현 불필요)

### 7.4 이중 호출 안전성 검증

iOS 26+ Navigation Pop에서는 `viewerDidClose` + `viewDidAppear` 양쪽에서 `applyPendingViewerReturn()`이 호출될 수 있음:

```swift
// applyPendingViewerReturn() 내부:
isViewerOpen = false           // 1차: false 설정, 2차: 이미 false → 무해
pendingDataRefresh = false     // 1차: true→false, loadTrashedAssets() 호출
                               // 2차: 이미 false → skip
pendingScrollAssetID = nil     // 1차: 처리, 2차: 이미 nil → guard return
```

**결론: 이중 호출 시 2차는 no-op → 안전**

### 7.5 적용 범위

| VC | 수정 내용 | 비고 |
|----|----------|------|
| **ViewerViewController** | `viewDidDisappear` 추가 + `viewerDidClose` 호출 | 핵심 |
| **ViewerViewControllerDelegate** | `viewerDidClose()` 메서드 추가 | 프로토콜 |
| **TrashAlbumViewController** | `viewerDidClose()` 구현 | 버그 수정 대상 |
| GridViewController | `viewerDidClose()` 구현 | 동일 구조 예방 |
| AlbumGridViewController | `viewerDidClose()` 구현 | 동일 구조 예방 |
| PreviewGridViewController | protocol extension 기본 no-op 사용 | 별도 구현 불필요 |

### 7.6 주의사항

- `viewerWillClose` 시점에서는 여전히 `loadTrashedAssets()` 호출 금지 (기존 주석 참고, 679행)
  - `sourceViewProvider`가 이후 호출되므로 `reloadData()` 시 셀 불일치 발생
- `viewerDidClose`는 dismiss 애니메이션 **완료 후** 호출 → `sourceViewProvider` 이미 완료 → 안전
- `viewWillDisappear`에서 `isClosing` 플래그 설정 → `viewDidDisappear`에서 플래그로 판별 (Apple SDK 헤더 권장 패턴)
- interactive dismiss 취소 시: `viewWillDisappear` 미호출 → `isClosing = false` 유지 → `viewerDidClose` 미호출 (정상)

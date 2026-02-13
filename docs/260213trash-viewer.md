# 휴지통 뷰어 추가 이슈 2건

> 작성일: 2026-02-13
> 선행 수정: `viewerDidClose` delegate 추가 (`0c76924` 이후 구현)

---

## 이슈 A: 휴지통 그리드 복귀 시 복구된 사진이 잠깐 보임

### 증상

휴지통 뷰어에서 사진 복구 → 뷰어 닫기 → 휴지통 그리드에서 복구된 사진이 ~1초간 보인 후 사라짐.
사라지긴 하지만, 이미 사라져 있어야 함.

### 원인

`loadTrashedAssets()`가 **fetch까지 통째로 지연**되기 때문:

```
[복구 시점] (뷰어 열린 상태)
onStateChange → loadTrashedAssets() → isViewerOpen == true → pendingDataRefresh = true (전체 스킵)

[뷰어 닫힌 후]
applyPendingViewerReturn() → loadTrashedAssets() 시작
  → 백그라운드 fetch (~수백ms)          ← 이 구간 동안 구 데이터 표시
  → 메인 reloadData() → 비로소 갱신
```

핵심: fetch가 뷰어 열린 동안 미리 되어 있으면, 닫힐 때 `reloadData()`만 하면 즉시 반영됨.

### 수정 시도 #1: pre-fetch 캐싱 (실패)

> 커밋 `df55f7a` 이후 구현 → 테스트 실패 → 롤백

**접근:** `loadTrashedAssets()`에서 fetch는 즉시 실행하되, reloadData만 지연.
`PendingFetchState` enum으로 `.empty`/`.fetched`/`.fetching` 상태를 관리하고,
`applyPendingViewerReturn()`에서 캐싱된 결과를 즉시 적용.

**결과:** 증상 동일 — 복구된 사진이 여전히 ~1초간 보임.

**실패 원인:** 이 접근은 `viewDidDisappear` 이후(T=370ms~)의 fetch 지연만 단축.
하지만 실제 문제는 dismiss 애니메이션 중(T=0~370ms)에 구 데이터가 보이는 것.
pre-fetch가 `α`를 0에 가깝게 줄여도, 370ms의 애니메이션 구간은 건드리지 못함.

### 재분석: 실제 원인

**문제의 타이밍 구간이 잘못 특정되었음.**

초기 분석은 "fetch가 느려서 지연된다"고 진단했지만, 실제로는 dismiss 애니메이션 동안
`shouldRemovePresentersView = false`로 인해 그리드가 **항상 뷰어 뒤에 보이는 것**이 핵심.

```
T=0ms       viewerWillClose() 호출
            ZoomAnimator.animateTransition 시작
              → scrollToSourceCell() → 그리드 스크롤
              → fromView(뷰어).alpha → 0 애니메이션 시작
              ★ 이 순간부터 그리드가 드러나기 시작
              ★ 그리드는 OLD 데이터 (복구된 사진 포함)

T=0~370ms   줌 아웃 애니메이션 진행 중
              → 뷰어 서서히 투명 → 그리드 점점 드러남
              → 복구된 사진이 그리드에 보임 ← 사용자가 보는 구간

T=370ms     애니메이션 완료 → viewDidDisappear
              → viewerDidClose() → applyPendingViewerReturn()
              → loadTrashedAssets() (async fetch 시작)

T=370+α ms  fetch 완료 → reloadData() → 비로소 사라짐
```

| 구간 | 설명 | pre-fetch가 해결? |
|------|------|------------------|
| **T=0~370ms** (애니메이션) | 그리드가 구 데이터로 보임 | **아니오** |
| T=370ms~ (애니메이션 후) | fetch → reloadData | 예 (α 단축) |

사용자가 보는 ~1초 = 370ms(애니메이션) + 수백ms(fetch).
pre-fetch는 두 번째만 줄이며, 첫 번째 370ms는 그대로.

### 수정 계획 v2: dismiss 전 셀 숨김

**핵심 원리:** 데이터소스는 변경하지 않고 (sourceViewProvider 셀 인덱스 보존),
복구된 사진의 셀만 **시각적으로 숨긴다** (dismiss 애니메이션 시작 전).

`viewerWillClose()`는 `ZoomAnimator.animateTransition` **이전에** 호출됨.
이 시점에서 복구된 사진을 특정할 수 있음:
- `trashedAssetIDSet` = 뷰어 열기 시점 기준 (이전 상태, isViewerOpen 중 갱신 안 됨)
- `trashStore.trashedAssetIDs` = 현재 상태 (복구된 항목 제외)
- 차집합 = 복구된 사진 ID들

```swift
func viewerWillClose(currentAssetID: String?) {
    pendingScrollAssetID = currentAssetID
    didUserScrollAfterReturn = false

    // ★ dismiss 애니메이션 전: 복구된 사진 셀 숨김
    // 데이터소스 변경 없이 시각적으로만 숨김 (sourceViewProvider 인덱스 보존)
    let currentTrashedIDs = trashStore.trashedAssetIDs
    let restoredIDs = trashedAssetIDSet.subtracting(currentTrashedIDs)
    for restoredID in restoredIDs {
        if let index = _trashDataSource.assetIndex(for: restoredID) {
            let indexPath = IndexPath(item: index + paddingCellCount, section: 0)
            collectionView.cellForItem(at: indexPath)?.isHidden = true
        }
    }
}
```

**후처리 (applyPendingViewerReturn):**

```swift
private func applyPendingViewerReturn() {
    isViewerOpen = false

    if pendingDataRefresh {
        pendingDataRefresh = false
        // 숨긴 셀 복원 (reloadData 전에 — 셀 재사용 시 isHidden 잔존 방지)
        collectionView.visibleCells.forEach { $0.isHidden = false }
        loadTrashedAssets()
    }

    // ... 이하 scroll 로직 동일 ...
}
```

**동작 흐름:**

```
T=0ms       viewerWillClose()
              → 복구된 사진 셀 isHidden = true ★
              → dismiss 애니메이션 시작

T=0~370ms   줌 아웃 애니메이션 진행
              → 그리드 드러남 → 복구된 사진 셀은 이미 숨겨져 있음 ✅

T=370ms     viewDidDisappear → applyPendingViewerReturn()
              → visibleCells.isHidden = false (복원)
              → loadTrashedAssets() → reloadData()
              → 데이터소스에서 제거되어 자연스럽게 사라짐 ✅
```

**안전성:**

| 항목 | 상태 |
|------|------|
| sourceViewProvider 셀 인덱스 | ✅ 데이터소스 변경 없음 — 인덱스 그대로 |
| 줌 트랜지션 소스 뷰 | ✅ 현재 보고 있는 사진 셀은 숨기지 않음 (restoredIDs에 포함 안 됨) |
| 셀 재사용 시 isHidden 잔존 | ✅ applyPendingViewerReturn에서 복원 후 reloadData |
| 복구된 사진이 현재 뷰어 사진인 경우 | ✅ 뷰어에서 다음 사진으로 이동 후 닫히므로 해당 셀은 현재 인덱스 아님 |

### 최종 수정: pre-fetch + viewerWillClose 즉시 적용 + asset ID 기반 셀 검색

> 커밋 `d6d8783` (4차 시도에서 성공)

**시도 #2 (셀 숨김 단독):** 애니메이션 중 플래시는 해결, 하지만 `isHidden`으로 숨긴 셀이
`applyPendingViewerReturn`에서 복원될 때 2차 깜빡임 발생 → unhide를 `onDataLoaded`로 이동하여 해결.

**시도 #3 (셀 숨김 + pre-fetch 조합):** 깜빡임은 해결, 하지만 `isHidden`은 레이아웃에 영향을 주지 않아
복구된 셀의 빈 공간이 보인 후 `reloadData`로 재정렬되는 것이 보임.

**시도 #4 (최종 — pre-fetch + 즉시 reloadData + asset ID 기반 셀 검색):**

핵심: `viewerWillClose()`에서 pre-fetch된 결과를 **즉시 적용** (`reloadData()` 포함).
reloadData 후 셀 인덱스가 바뀌므로, sourceViewProvider에서 asset ID 기반으로 정확한 셀을 찾는
`resolvedIndexPath(for:)` 헬퍼 추가.

```swift
// viewerWillClose에서 pre-fetch 결과 즉시 적용
case .fetched(let fetchResult):
    _trashDataSource.setFetchResult(fetchResult)
    trashedAssetIDSet = trashStore.trashedAssetIDs
    collectionView.reloadData()  // ★ 애니메이션 전에 그리드 완전 갱신

// sourceViewProvider: asset ID 기반 셀 검색 (인덱스 시프트 보정)
private func resolvedIndexPath(for originalIndex: Int) -> IndexPath {
    if let assetID = pendingScrollAssetID,
       let actualIndex = _trashDataSource.assetIndex(for: assetID) {
        return IndexPath(item: actualIndex + paddingCellCount, section: 0)
    }
    return IndexPath(item: originalIndex + paddingCellCount, section: 0)
}
```

**fallback:** pre-fetch 미완료 시 셀 숨김(isHidden)으로 대체.

### 수정 파일

| 파일 | 수정 내용 |
|-----|---------|
| TrashAlbumViewController.swift | `PendingFetchState` enum, `viewerWillClose()` 즉시 적용, `resolvedIndexPath()` 헬퍼, sourceViewProvider 3개 메서드 보정 |

---

## 이슈 B: 휴지통 뷰어에서 완전삭제 후 이미지가 뷰어에 남아있음

### 증상

휴지통 뷰어 → 완전삭제 버튼 → 시스템 팝업에서 삭제 확인 → 이미지가 뷰어에 그대로 남아있음.
기대 동작: 메인 뷰어에서 휴지통 버튼 눌렀을 때처럼 이전/다음 이미지로 이동.

### 원인

`viewerDidRequestPermanentDelete` (TrashAlbumVC:654행)에서 삭제 완료 후 ViewerVC 참조 실패:

```swift
// 현재 코드 (664행)
await MainActor.run {
    if let viewerVC = self.navigationController?.topViewController as? ViewerViewController {
        viewerVC.handleDeleteComplete()
    }
}
```

| 경로 | `navigationController?.topViewController` | 결과 |
|------|------------------------------------------|------|
| iOS 26+ (Push) | ViewerViewController ✅ | `handleDeleteComplete()` 호출됨 |
| iOS 16~25 (Modal) | TrashAlbumViewController ❌ | **캐스트 실패 → 호출 안 됨** |

Modal로 present된 ViewerVC는 `navigationController?.topViewController`에 나타나지 않음.
`self.presentedViewController`로 접근해야 함.

**동일 패턴 존재:** GridViewController(976행)에도 같은 `navigationController?.topViewController` 참조가 있음.
현재 메인 그리드에서 완전삭제가 호출되는 경로는 없지만, 동일한 취약 패턴이므로 함께 수정.

### 수정 계획

**방안: weak 참조 저장 후 사용 (presentation 방식에 무관)**

`openViewer`에서 ViewerVC 생성 시 weak 참조를 저장하고, `viewerDidRequestPermanentDelete`에서 사용:

```swift
// TrashAlbumViewController.swift

/// 현재 열린 뷰어 참조 (완전삭제 완료 후 알림용)
private weak var activeViewerVC: ViewerViewController?

override func openViewer(for asset: PHAsset, at assetIndex: Int) {
    // ... 기존 코드 ...
    let viewerVC = ViewerViewController(...)
    viewerVC.delegate = self
    activeViewerVC = viewerVC  // ← 참조 저장
    // ... present/push ...
}

func viewerDidRequestPermanentDelete(assetID: String) {
    Task {
        do {
            try await trashStore.permanentlyDelete(assetIDs: [assetID])
            await MainActor.run {
                // weak 참조로 접근 (Push/Modal 무관)
                self.activeViewerVC?.handleDeleteComplete()
            }
        } catch { ... }
    }
}

func viewerWillClose(currentAssetID: String?) {
    // ... 기존 코드 ...
    activeViewerVC = nil  // 정리
}
```

### 수정 결과

> 커밋 `b6de3a4` — 성공

계획대로 `activeViewerVC` weak 참조 방식으로 수정. Push/Modal 방식에 무관하게 동작 확인.

**추가 발견 — 마지막 1장 삭제 시 크래시:**

마지막 사진 완전삭제 → `moveToNextAfterDelete()` → `totalCount == 0` → `dismissWithFadeOut()` 경로에서:
1. `viewWillDisappear` → `viewerWillClose()` → `pendingFetchState = .empty` → `reloadData()` → 컬렉션뷰 0개 아이템
2. ZoomAnimator dismiss → `scrollToSourceCell(for: 0)` → 존재하지 않는 IndexPath로 `scrollToItem` 호출
3. `NSInternalInconsistencyException` 크래시

**수정:** `scrollToSourceCell`에 범위 체크 추가:
```swift
let totalItems = collectionView.numberOfItems(inSection: 0)
guard cellIndexPath.item < totalItems else { return }
```

### 수정 파일

| 파일 | 수정 내용 |
|-----|---------|
| TrashAlbumViewController.swift | `activeViewerVC` weak 참조 추가 + `openViewer` 저장 + `viewerDidRequestPermanentDelete` 참조 변경 + `scrollToSourceCell` 범위 체크 |
| GridViewController.swift | 동일 패턴 수정 — `activeViewerVC` weak 참조로 변경 |

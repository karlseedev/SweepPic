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

### 수정 계획

**핵심 원리:** 현재 `isViewerOpen` 시 fetch + reloadData를 통째로 차단하지만,
차단이 필요한 것은 `reloadData()`뿐 (줌 트랜지션의 sourceViewProvider 셀 인덱스 보존).
fetch는 UI와 무관한 백그라운드 작업이므로 즉시 실행 가능.

**fetch는 즉시 실행, reloadData만 지연:**

```swift
/// 뷰어 열린 동안 fetch 결과를 캐싱하는 상태
private enum PendingFetchState {
    case none                              // 대기 중 없음
    case empty                             // 빈 결과 대기 (휴지통 비어있음)
    case fetched(PHFetchResult<PHAsset>)   // fetch 완료, 적용 대기
    case fetching                          // fetch 진행 중 (뷰어 닫힐 때 fallback 필요)
}
private var pendingFetchState: PendingFetchState = .none

private func loadTrashedAssets() {
    let startTime = CFAbsoluteTimeGetCurrent()
    trashedAssetIDSet = trashStore.trashedAssetIDs

    if trashedAssetIDSet.isEmpty {
        if isViewerOpen {
            // fetch 결과를 저장만 하고 reloadData 스킵
            pendingFetchState = .empty
            pendingDataRefresh = true
            return
        }
        _trashDataSource.setFetchResult(nil)
        DispatchQueue.main.async { [weak self] in
            self?.onDataLoaded(startTime: startTime)
        }
        return
    }

    if isViewerOpen {
        pendingFetchState = .fetching  // fetch 시작 표시
        pendingDataRefresh = true
    }

    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
        guard let self = self else { return }
        // ... fetch 수행 ...
        let fetchResult = PHAsset.fetchAssets(...)

        DispatchQueue.main.async {
            if self.isViewerOpen {
                // fetch 결과를 저장만 하고 reloadData 스킵
                self.pendingFetchState = .fetched(fetchResult)
            } else {
                self._trashDataSource.setFetchResult(fetchResult)
                self.onDataLoaded(startTime: startTime)
            }
        }
    }
}
```

**applyPendingViewerReturn에서 즉시 적용:**

```swift
private func applyPendingViewerReturn() {
    let wasViewerOpen = isViewerOpen
    isViewerOpen = false

    if pendingDataRefresh {
        pendingDataRefresh = false
        switch pendingFetchState {
        case .empty:
            // 빈 결과 즉시 적용
            _trashDataSource.setFetchResult(nil)
            onDataLoaded(startTime: CFAbsoluteTimeGetCurrent())
        case .fetched(let fetchResult):
            // 미리 fetch된 결과 즉시 적용 → reloadData() 즉시 실행
            _trashDataSource.setFetchResult(fetchResult)
            onDataLoaded(startTime: CFAbsoluteTimeGetCurrent())
        case .fetching, .none:
            // fetch 진행 중 또는 미시작 → 기존 방식 fallback
            loadTrashedAssets()
        }
        pendingFetchState = .none
    }

    // ... 이하 scroll 로직 동일 ...
}
```

### 수정 파일

| 파일 | 수정 내용 |
|-----|---------|
| TrashAlbumViewController.swift | `PendingFetchState` enum 추가 + `loadTrashedAssets()` 분기 변경 + `applyPendingViewerReturn()` switch 적용 |

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

### 수정 계획

**방안: weak 참조 저장 후 사용**

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

### 수정 파일

| 파일 | 수정 내용 |
|-----|---------|
| TrashAlbumViewController.swift | `activeViewerVC` weak 참조 추가 + `openViewer` 저장 + `viewerDidRequestPermanentDelete` 참조 변경 |

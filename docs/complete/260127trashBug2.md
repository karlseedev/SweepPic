# 휴지통 뷰어 Dismiss 버그 디버깅 기록

## 1. 버그 현상

- **증상**: 휴지통에서 사진을 뷰어로 열고 닫을 때, 올바른 셀이 아닌 **다른 사진으로 축소** 애니메이션 발생
- **영향 범위**: iOS 18+ (네이티브 zoom transition 사용하는 버전)
- **GridViewController**: 정상 동작
- **TrashAlbumViewController**: 버그 발생

---

## 2. 첫 번째 수정 시도 (fetchResult 공유)

### 2.1 원인 분석 (기획서 260127trashBug.md)

| 항목 | GridViewController | TrashAlbumViewController |
|-----|-------------------|-------------------------|
| 뷰어 생성 시 | 같은 fetchResult 사용 | **새 fetchResult 생성** |
| sourceViewProvider | `coordinator.originalIndex(from:)` | `assetID → _trashDataSource.assetIndex()` |

### 2.2 수정 내용

1. **TrashDataSource**: `[PHAsset]` 배열 → `PHFetchResult` 기반으로 변경
2. **openViewer()**: 새 fetchResult 생성 대신 기존 fetchResult 재사용
3. **sourceViewProvider**: `coordinator.originalIndex(from:)` 직접 사용
4. **loadTrashedAssets()**: 뷰어 열린 동안 데이터 갱신 지연 (`isViewerOpen` 플래그)

### 2.3 테스트 결과

**여전히 버그 발생** - 다른 원인이 있음

---

## 3. 디버깅 과정

### 3.1 로그 추가

```swift
// sourceViewProvider 내부
Log.print("currentIndex=\(currentIndex), originalIndex=\(originalIndex), cellIndexPath=\(cellIndexPath.item)")
Log.print("coordinator.assetID=\(assetID), gridDataSource.assetID=\(gridAssetID)")
Log.print("cell.currentAssetID=\(cellAssetID), expected=\(assetID), match=\(cellAssetID == assetID)")
```

### 3.2 로그 결과

```
[TrashAlbumVC.sourceViewProvider] ✅ cell at 3
[TrashAlbumVC.sourceViewProvider] 📍 cell.currentAssetID=D5338343, expected=D5338343, match=true
[TrashAlbumViewController] Loaded 40 trashed assets  ← 문제!
```

**핵심 발견**: sourceViewProvider 로그 **이후에** `Loaded 40 trashed assets`가 출력됨

---

## 4. 실제 원인 발견

### 4.1 타이밍 문제

`viewerWillClose()`에서 `loadTrashedAssets()`를 바로 호출하고 있었음:

```swift
func viewerWillClose(currentAssetID: String?) {
    isViewerOpen = false
    // ...
    if pendingDataRefresh {
        loadTrashedAssets()  // ← reloadData() 실행!
    }
}
```

### 4.2 실제 호출 순서 (버그 발생)

```
1. 뷰어 닫기 시작
2. viewerWillClose() 호출
   → isViewerOpen = false
   → loadTrashedAssets()
   → collectionView.reloadData()  ← 셀 내용 변경!
3. sourceViewProvider 호출
   → indexPath로 셀 찾기
   → 이미 다른 에셋을 표시하는 셀 반환!
4. 잘못된 위치로 축소 애니메이션
```

### 4.3 GridViewController가 정상인 이유

| | GridViewController | TrashAlbumViewController |
|---|---|---|
| **viewWillAppear** | reloadData() 없음 | loadTrashedAssets() → reloadData() |
| **viewerWillClose** | 데이터 갱신 없음 | loadTrashedAssets() → reloadData() |
| **결과** | sourceViewProvider 시점에 셀 상태 유지 | sourceViewProvider 시점에 셀 변경됨 |

---

## 5. 두 번째 수정 (타이밍 조절)

### 5.1 수정 내용

**viewerWillClose()**: `isViewerOpen = false`와 `loadTrashedAssets()` 호출 제거

```swift
func viewerWillClose(currentAssetID: String?) {
    // isViewerOpen = false 제거
    // loadTrashedAssets() 제거
    pendingScrollAssetID = currentAssetID
    didUserScrollAfterReturn = false
}
```

**applyPendingViewerReturn()**: dismiss 애니메이션 완료 후 처리

```swift
private func applyPendingViewerReturn() {
    isViewerOpen = false  // 여기서 해제

    if pendingDataRefresh {
        pendingDataRefresh = false
        loadTrashedAssets()  // 여기서 갱신
    }
    // ...
}
```

### 5.2 수정 후 호출 순서

```
1. 뷰어 닫기 시작
2. viewerWillClose() 호출
   → pendingScrollAssetID 저장만
   → isViewerOpen은 여전히 true
3. sourceViewProvider 호출
   → 올바른 셀 반환 ✅
4. dismiss 애니메이션 완료
5. viewWillAppear → applyPendingViewerReturn()
   → isViewerOpen = false
   → loadTrashedAssets() (필요시)
```

### 5.3 테스트 결과

**정상 동작** - 올바른 셀로 축소됨

---

## 6. 구조적 취약점 (향후 개선 필요)

### 6.1 현재 방식의 문제점

GridViewController와 TrashAlbumViewController 모두 **indexPath 기반**으로 셀을 찾음:

```swift
let cellIndexPath = IndexPath(item: originalIndex + self.paddingCellCount, section: 0)
guard let cell = self.collectionView.cellForItem(at: cellIndexPath) as? PhotoCell else {
    return nil
}
```

**취약점**: sourceViewProvider 호출 시점에 collectionView가 reloadData()되면 잘못된 셀 반환

### 6.2 근본적인 해결책 (미구현)

**옵션 A: assetID 기반 visibleCells 검색**

```swift
// indexPath 대신 assetID로 직접 검색
let targetAssetID = coordinator.assetID(at: currentIndex)
let cell = collectionView.visibleCells
    .compactMap { $0 as? PhotoCell }
    .first { $0.currentAssetID == targetAssetID }
```

**옵션 B: 뷰어 열 때 셀 위치 캡처**

```swift
// openViewer에서 셀의 globalFrame 저장
private var cachedSourceFrame: CGRect?

// sourceViewProvider에서 저장된 위치 사용
```

### 6.3 현재 상태

- **타이밍 조절 방식**으로 동작함
- GridViewController와 동일한 수준의 안정성
- 구조적 취약점은 남아있음 (향후 개선 고려)

---

## 7. 수정된 파일 목록

| 파일 | 수정 내용 |
|-----|---------|
| `GridDataSource.swift` | TrashDataSource를 fetchResult 기반으로 변경 |
| `TrashAlbumViewController.swift` | openViewer(), loadTrashedAssets(), viewerWillClose(), applyPendingViewerReturn() |
| `TrashSelectMode.swift` | 미사용 헬퍼 제거 |
| `Log.swift` | 디버그 카테고리 활성화 (임시) |
| `GridViewController.swift` | 디버그 로그 추가 (임시) |

---

## 8. 결론

1. **원래 기획(fetchResult 공유)**: 필요하지만 충분하지 않았음
2. **실제 원인**: viewerWillClose()에서 reloadData() 호출 타이밍 문제
3. **해결책**: dismiss 애니메이션 완료 후 데이터 갱신
4. **향후 과제**: indexPath 기반 → assetID 기반 셀 검색으로 구조 개선

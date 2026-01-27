# 구조적 수정 기획서: 휴지통 뷰어 Dismiss 애니메이션 버그 수정

## 1. 현재 구조 분석

### 1.1 세 ViewController의 데이터 흐름 비교

| 항목 | GridViewController | AlbumGridViewController | TrashAlbumViewController |
|-----|-------------------|------------------------|-------------------------|
| **그리드 데이터** | `driver.fetchResult` | `fetchResult` (멤버) | `_trashDataSource.assets` (배열) |
| **뷰어 생성 시** | 같은 fetchResult 사용 | 같은 fetchResult 사용 | **새 fetchResult 생성** |
| **sourceViewProvider** | `coordinator.originalIndex(from:)` | `coordinator.originalIndex(from:)` | `assetID → _trashDataSource.assetIndex()` |
| **데이터 동기화** | 자동 보장 | 자동 보장 | **불일치 가능** |

### 1.2 버그 발생 흐름

```
[뷰어 열기]
openViewer() → 새 PHFetchResult 생성 → coordinator에 전달
                 ↓
           그리드의 _trashDataSource.assets와 별개

[뷰어에서 복구/삭제]
trashStore.restore() → onStateChange 콜백 → loadTrashedAssets()
                                              ↓
                                   _trashDataSource.assets 변경
                                   coordinator.fetchResult는 그대로!

[dismiss]
sourceViewProvider() → coordinator.assetID(at:) → 이전 데이터 기준
                     → _trashDataSource.assetIndex() → 새 데이터 기준
                     → 인덱스 불일치 → 잘못된 셀로 축소!
```

---

## 2. 해결 목표

1. **구조 통일**: TrashAlbumViewController도 다른 VC들과 동일한 패턴 사용
2. **단일 데이터 소스**: 그리드와 뷰어가 동일한 fetchResult 공유
3. **일관된 인덱스 계산**: `coordinator.originalIndex(from:)` 사용
4. **데이터 일관성**: 뷰어 열린 동안 데이터 변경 시 안전하게 처리

---

## 3. 수정 설계

### 3.1 TrashDataSource 수정

**현재:**
```swift
final class TrashDataSource: GridDataSource {
    var assets: [PHAsset] = []  // ← 배열 기반

    var fetchResultForViewer: PHFetchResult<PHAsset>? {
        nil  // ← 문제: 항상 nil
    }
}
```

**수정 후:**
```swift
final class TrashDataSource: GridDataSource {
    /// 휴지통 fetchResult (그리드와 뷰어 공유)
    private(set) var fetchResult: PHFetchResult<PHAsset>?

    /// 에셋 ID → 인덱스 캐시 (O(1) 조회용)
    /// 기존 indexCache 재활용 (rebuildIndexCache도 기존 코드 유지)
    private var indexCache: [String: Int] = [:]

    /// fetchResult 설정 (외부에서 갱신)
    func setFetchResult(_ fetchResult: PHFetchResult<PHAsset>?) {
        self.fetchResult = fetchResult
        rebuildIndexCache()
    }

    /// 인덱스 캐시 재구축 (기존 로직 수정)
    private func rebuildIndexCache() {
        indexCache.removeAll(keepingCapacity: true)
        guard let fetchResult = fetchResult else { return }
        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            indexCache[asset.localIdentifier] = i
        }
    }

    var assetCount: Int {
        fetchResult?.count ?? 0
    }

    /// 빈 상태 확인용 computed property (기존 assets.isEmpty 대체)
    var isEmpty: Bool {
        fetchResult == nil || fetchResult!.count == 0
    }

    func asset(at index: Int) -> PHAsset? {
        guard let fetchResult = fetchResult,
              index >= 0, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index)
    }

    var fetchResultForViewer: PHFetchResult<PHAsset>? {
        fetchResult  // ← 수정: 실제 fetchResult 반환
    }
}
```

**제거되는 프로퍼티:**
- `var assets: [PHAsset]` → `fetchResult` 기반으로 대체
- `var orderedAssetIDs: [String]` → 더 이상 필요 없음 (fetchResult 직접 사용)

### 3.2 TrashAlbumViewController.loadTrashedAssets() 수정

**현재:**
```swift
private func loadTrashedAssets() {
    let fetchResult = PHAsset.fetchAssets(...)
    var assets: [PHAsset] = []
    fetchResult.enumerateObjects { asset, _, _ in
        assets.append(asset)
    }
    self._trashDataSource.assets = assets  // 배열만 저장
}
```

**수정 후:**
```swift
private func loadTrashedAssets() {
    // 뷰어 열린 상태면 갱신 지연
    if isViewerOpen {
        pendingDataRefresh = true
        return
    }

    let fetchResult = PHAsset.fetchAssets(...)
    self._trashDataSource.setFetchResult(fetchResult)  // fetchResult 저장
}
```

### 3.3 TrashAlbumViewController.openViewer() 수정

**현재:**
```swift
override func openViewer(for asset: PHAsset, at assetIndex: Int) {
    // 새 fetchResult 생성 (문제!)
    let assetIDs = _trashDataSource.orderedAssetIDs
    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: fetchOptions)

    let coordinator = ViewerCoordinator(fetchResult: fetchResult, ...)

    // sourceViewProvider에서 assetID 기반 간접 변환 (문제!)
    viewerVC.preferredTransition = .zoom(sourceViewProvider: { ...
        guard let assetID = coordinator.assetID(at: currentIndex) else { ... }
        guard let trashIndex = self._trashDataSource.assetIndex(for: assetID) else { ... }
    })
}
```

**수정 후:**
```swift
override func openViewer(for asset: PHAsset, at assetIndex: Int) {
    // 기존 fetchResult 사용 (새로 생성하지 않음!)
    guard let fetchResult = _trashDataSource.fetchResult else { return }

    isViewerOpen = true

    let coordinator = ViewerCoordinator(fetchResult: fetchResult, ...)

    // sourceViewProvider에서 직접 인덱스 변환 (다른 VC와 동일!)
    viewerVC.preferredTransition = .zoom(sourceViewProvider: { ...
        guard let originalIndex = coordinator.originalIndex(from: currentIndex) else { ... }
        let cellIndexPath = IndexPath(item: originalIndex + self.paddingCellCount, section: 0)
    })
}
```

### 3.4 뷰어 열린 동안 데이터 변경 처리

```swift
// 새 프로퍼티 추가
private var isViewerOpen: Bool = false
private var pendingDataRefresh: Bool = false

// viewerWillClose 수정
func viewerWillClose(currentAssetID: String?) {
    isViewerOpen = false
    pendingScrollAssetID = currentAssetID
    didUserScrollAfterReturn = false

    // 지연된 갱신 처리
    if pendingDataRefresh {
        pendingDataRefresh = false
        loadTrashedAssets()
    }
}
```

### 3.5 기존 코드 마이그레이션

**TrashAlbumViewController 내 `_trashDataSource.assets` 직접 접근 코드 변경:**

| 위치 | 현재 코드 | 수정 후 |
|-----|----------|--------|
| `setupSystemNavigationBar()` line 179 | `_trashDataSource.assets.isEmpty` | `_trashDataSource.isEmpty` |
| `configureFloatingOverlayForTrash()` line 225 | `_trashDataSource.assets.isEmpty` | `_trashDataSource.isEmpty` |
| `scrollToBottomIfNeeded()` line 330 | `_trashDataSource.assets.isEmpty` | `_trashDataSource.isEmpty` |
| `emptyTrashButtonTapped()` line 478 | `_trashDataSource.assets.isEmpty` | `_trashDataSource.isEmpty` |
| `emptyTrash()` line 485 | `_trashDataSource.assets.isEmpty` | `_trashDataSource.isEmpty` |
| `loadTrashedAssets()` line 254 | 빈 배열 할당 | `setFetchResult(nil)` |
| `loadTrashedAssets()` line 290 | `_trashDataSource.assets = assets` | `_trashDataSource.setFetchResult(fetchResult)` |
| `onDataLoaded()` line 307 | `_trashDataSource.assets.isEmpty` | `_trashDataSource.isEmpty` |
| `openViewer()` line 512 | `_trashDataSource.orderedAssetIDs` | 제거 (fetchResult 직접 사용) |

**GridDataSource.swift 내 TrashDataSource 변경:**

| 항목 | 현재 | 수정 후 |
|-----|-----|--------|
| `assets` 프로퍼티 | `var assets: [PHAsset] = []` | 제거 |
| `assets.didSet` | `rebuildIndexCache()` 호출 | `setFetchResult()` 내부에서 호출 |
| `assetCount` | `assets.count` | `fetchResult?.count ?? 0` |
| `asset(at:)` | `assets[index]` | `fetchResult.object(at: index)` |
| `assetID(at:)` | `assets[index].localIdentifier` | `fetchResult.object(at: index).localIdentifier` |
| `orderedAssetIDs` | `assets.map { ... }` | 제거 (더 이상 필요 없음) |
| `fetchResultForViewer` | `nil` | `fetchResult` |

---

## 4. 수정 파일 목록

| 파일 | 수정 내용 | 예상 변경량 |
|-----|---------|-----------|
| `GridDataSource.swift` | TrashDataSource 클래스 전면 수정 (fetchResult 기반) | ~50줄 |
| `TrashAlbumViewController.swift` | openViewer(), loadTrashedAssets(), 9개 assets 접근 코드 | ~30줄 |

### 상세 변경 사항

**GridDataSource.swift (TrashDataSource 클래스):**
1. `assets` 프로퍼티 → `fetchResult` 프로퍼티로 교체
2. `setFetchResult(_:)` 메서드 추가
3. `isEmpty` computed property 추가
4. `rebuildIndexCache()` 수정 (fetchResult 기반)
5. `assetCount`, `asset(at:)`, `assetID(at:)` 수정
6. `orderedAssetIDs` 제거
7. `fetchResultForViewer` 수정 (fetchResult 반환)

**TrashAlbumViewController.swift:**
1. `isViewerOpen`, `pendingDataRefresh` 프로퍼티 추가
2. `loadTrashedAssets()` 수정 (뷰어 상태 체크, setFetchResult 호출)
3. `openViewer()` 수정 (fetchResult 재사용, sourceViewProvider 통일)
4. `viewerWillClose()` 수정 (pendingDataRefresh 처리)
5. 9개 `assets.isEmpty` → `isEmpty` 마이그레이션

---

## 5. 수정 전/후 비교

### sourceViewProvider 로직

**수정 전 (TrashAlbumViewController만 다름):**
```swift
// GridViewController, AlbumGridViewController
coordinator.originalIndex(from: currentIndex) → cellIndexPath

// TrashAlbumViewController (문제!)
coordinator.assetID(at: currentIndex) → assetID
_trashDataSource.assetIndex(for: assetID) → trashIndex → cellIndexPath
```

**수정 후 (모두 통일):**
```swift
// GridViewController, AlbumGridViewController, TrashAlbumViewController
coordinator.originalIndex(from: currentIndex) → cellIndexPath
```

---

## 6. 예상 효과

1. **버그 해결**: dismiss 시 올바른 썸네일로 축소
2. **코드 일관성**: 세 ViewController가 동일한 패턴 사용
3. **유지보수성 향상**: 인덱스 계산 로직 단순화
4. **데이터 일관성**: 뷰어 열린 동안 안전한 데이터 관리

---

## 7. 리스크 및 검증 항목

| 검증 항목 | 확인 방법 |
|---------|---------|
| 휴지통 진입 후 그리드 정상 표시 | 휴지통 탭 → 사진 목록 확인 |
| 뷰어 열기/닫기 애니메이션 | 사진 탭 → 뷰어 → 뒤로가기 |
| 뷰어에서 복구 후 dismiss | 뷰어에서 복구 → 뒤로가기 |
| 뷰어에서 완전삭제 후 dismiss | 뷰어에서 삭제 → 다음 사진 → 뒤로가기 |
| 빈 휴지통 처리 | 모든 사진 복구 후 상태 확인 |

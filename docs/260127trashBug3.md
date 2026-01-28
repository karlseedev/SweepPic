# sourceViewProvider 타이밍 의존성 제거 계획

## 목표

**sourceViewProvider의 타이밍 의존성을 제거하여 잘못된 셀 반환을 근본적으로 해결**

## 현재 문제

### 1. indexPath 기반 셀 검색

```swift
// 현재: indexPath 기반 셀 검색
let cellIndexPath = IndexPath(item: originalIndex + self.paddingCellCount, section: 0)
guard let cell = self.collectionView.cellForItem(at: cellIndexPath) as? PhotoCell
```

- reloadData() 호출 시 같은 indexPath에 다른 asset이 표시될 수 있음
- 타이밍에 의존하여 "잘못된 셀 반환" 가능

### 2. 타이밍 조절 코드 (TrashAlbumViewController)

```swift
// 현재: reloadData()를 지연시켜서 문제 회피
private var isViewerOpen: Bool = false
private var pendingDataRefresh: Bool = false
```

- 근본 해결이 아닌 타이밍 회피
- GridViewController, AlbumGridViewController와 일관성 없음

## 해결 방법

### 1. assetID 기반 셀 검색 (3개 ViewController)

```swift
// 변경: assetID 기반 visibleCells 검색
guard let targetAssetID = coordinator.assetID(at: currentIndex) else {
    return nil
}
let cell = self.collectionView.visibleCells
    .compactMap { $0 as? PhotoCell }
    .first { $0.currentAssetID == targetAssetID }
```

- assetID로 직접 검색하여 정확한 셀 반환
- 못 찾으면 nil → 중앙에서 줌 (깔끔한 fallback)

### 2. 타이밍 조절 코드 제거 (TrashAlbumViewController)

옵션 A가 근본 해결이므로 기존 타이밍 조절 코드 제거:
- `isViewerOpen`, `pendingDataRefresh` 변수 제거
- `loadTrashedAssets()`의 지연 로직 제거
- `applyPendingViewerReturn()`의 pendingDataRefresh 처리 제거

**제거 근거:**
1. 목표 중복: 둘 다 같은 문제 해결, 옵션 A가 근본 해결
2. 일관성: GridViewController, AlbumGridViewController와 동일하게
3. 유지보수: 두 해결책 공존 시 코드 이해 어려움

## 수정 대상 파일

| 파일 | 수정 내용 |
|-----|---------|
| `GridViewController.swift` | sourceViewProvider: indexPath → assetID 기반 |
| `AlbumGridViewController.swift` | sourceViewProvider: indexPath → assetID 기반 |
| `TrashAlbumViewController.swift` | sourceViewProvider 변경 + 타이밍 조절 코드 제거 |

## 구현 상세

### 1. sourceViewProvider 변경 (3개 ViewController 공통)

**Before:**
```swift
let currentIndex = viewer.currentIndex
guard let originalIndex = coordinator.originalIndex(from: currentIndex) else {
    return nil
}

// ❌ indexPath 기반
let cellIndexPath = IndexPath(item: originalIndex + self.paddingCellCount, section: 0)
guard let cell = self.collectionView.cellForItem(at: cellIndexPath) as? PhotoCell else {
    return nil
}

guard cell.hasLoadedImage else {
    return nil
}

return cell.thumbnailImageView
```

**After:**
```swift
let currentIndex = viewer.currentIndex

// ✅ assetID 기반 검색 - 타이밍 의존성 제거
guard let targetAssetID = coordinator.assetID(at: currentIndex) else {
    return nil  // 에셋 ID 조회 실패
}

// visibleCells에서 해당 assetID를 가진 셀 찾기
guard let cell = self.collectionView.visibleCells
    .compactMap({ $0 as? PhotoCell })
    .first(where: { $0.currentAssetID == targetAssetID }),
      cell.hasLoadedImage else {
    return nil  // 화면에 없거나 이미지 미로드 시 중앙에서 줌
}

return cell.thumbnailImageView
```

### 2. 타이밍 조절 코드 제거 (TrashAlbumViewController만)

**제거할 것:**
```swift
// 변수 제거
private var isViewerOpen: Bool = false
private var pendingDataRefresh: Bool = false

// loadTrashedAssets()의 지연 로직 제거
if isViewerOpen {
    pendingDataRefresh = true
    return  // ← 이 분기 제거
}

// openViewer()의 isViewerOpen = true 제거
isViewerOpen = true

// viewerWillClose()의 타이밍 관련 로그 제거
Log.print("[TrashAlbumViewController] viewerWillClose - pendingDataRefresh=...")

// applyPendingViewerReturn()의 타이밍 관련 로직 제거
let wasViewerOpen = isViewerOpen
isViewerOpen = false
if pendingDataRefresh {
    pendingDataRefresh = false
    loadTrashedAssets()
}
```

**유지할 것 (타이밍 조절과 무관):**
```swift
// 스크롤 위치 처리용 - 유지
private var pendingScrollAssetID: String?
private var didUserScrollAfterReturn: Bool = false

// viewerWillClose()의 스크롤 관련 - 유지
pendingScrollAssetID = currentAssetID
didUserScrollAfterReturn = false

// applyPendingViewerReturn()의 스크롤 처리 - 유지
guard let assetID = pendingScrollAssetID else { return }
pendingScrollAssetID = nil
// ... 스크롤 로직
```

## 검증 방법

1. **빌드 확인**: `xcodebuild` 성공
2. **기본 동작**: 휴지통에서 뷰어 열고 닫기 → 올바른 셀로 줌
3. **스와이프 후 닫기**: 뷰어에서 다른 사진으로 스와이프 후 닫기 → 해당 셀로 줌
4. **GridViewController 테스트**: 메인 그리드에서 동일 테스트
5. **AlbumGridViewController 테스트**: 앨범 상세에서 동일 테스트

## 예상 결과

| 상황 | Before | After |
|-----|--------|-------|
| 정상 닫기 | 올바른 셀 | 올바른 셀 |
| reloadData 후 닫기 | ❌ 잘못된 셀 | ✅ 올바른 셀 또는 nil |
| 셀 화면 밖 | nil | nil |
| 코드 구조 | 타이밍 의존 | 타이밍 무관 |

## 참고 사항

- **iOS 버전**: sourceViewProvider는 iOS 18+ 전용 (`if #available(iOS 18.0, *)`)
- **주석**: CLAUDE.md 규칙에 따라 모든 변경 코드에 상세 주석 작성
- **Git**: 50줄 이상 수정이므로 구현 전 현재 상태 커밋 필요

# PickPhoto 기술 설계 문서 (Tech Spec v2)

> 본 문서는 [prd4.md](./prd4.md)의 기술 구현 상세를 담고 있습니다.

---

## 1. 프로젝트 구조

### 1.1 AppCore (Swift Package) - 비즈니스 로직

```
Sources/AppCore/
├── Models/
│   ├── PhotoModels.swift           # PhotoAssetEntry, PhotoSection
│   ├── AlbumModels.swift           # Album, SmartAlbum
│   ├── DeletionAction.swift        # 삭제 상태
│   └── PermissionState.swift
├── Services/
│   ├── PhotoLibraryService.swift   # PhotoKit fetch, change observer
│   ├── AlbumService.swift          # 앨범 목록, 스마트 앨범
│   ├── ImageCacheManager.swift     # PHCachingImageManager 래퍼
│   ├── DeletionService.swift       # 삭제 처리
│   └── ImageRequestCoordinator.swift
└── Stores/
    ├── PermissionStore.swift
    └── AppStateStore.swift         # 백그라운드/메모리 관리
```

### 1.2 PickPhoto (SwiftUI App) - UI 레이어

```
PickPhoto/PickPhoto/
├── Features/
│   ├── Grid/
│   │   ├── GridView.swift                    # SwiftUI wrapper
│   │   ├── PhotoGridViewController.swift     # UICollectionView 핵심
│   │   ├── PhotoGridCell.swift
│   │   ├── PinchZoomHandler.swift            # 핀치 줌 (밀도 변화)
│   │   ├── SelectionManager.swift            # 멀티 선택 모드
│   │   └── GridViewModel.swift
│   ├── Albums/
│   │   ├── AlbumListView.swift               # 앨범 리스트
│   │   ├── AlbumGridView.swift               # 앨범 내 그리드
│   │   └── AlbumViewModel.swift
│   ├── Detail/
│   │   ├── DetailView.swift
│   │   ├── DetailTransitionAnimator.swift    # 300ms 전환
│   │   └── SwipeGestureHandler.swift         # 위 스와이프 삭제 포함
│   └── Permissions/
│       └── PermissionGateView.swift
└── Shared/
```

---

## 2. 핵심 컴포넌트 설계

### 2.1 PhotoGridViewController

```swift
final class PhotoGridViewController: UIViewController {
    private lazy var collectionView: UICollectionView = {
        let layout = PhotoGridLayout(columns: 3, spacing: 2)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.prefetchDataSource = self
        cv.isPrefetchingEnabled = true
        return cv
    }()

    private var dataSource: UICollectionViewDiffableDataSource<PhotoSection, PhotoAssetEntry>!
    private let cachingImageManager = PHCachingImageManager()

    // 가시 영역 +-3개 행 프리캐싱
    private var cachedIndexPaths: Set<IndexPath> = []
    private let prefetchBuffer = 3
}

extension PhotoGridViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView,
                        prefetchItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.compactMap { dataSource.itemIdentifier(for: $0)?.asset }
        imageCacheManager.startPrefetching(assets: assets)
    }

    func collectionView(_ collectionView: UICollectionView,
                        cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assets = indexPaths.compactMap { dataSource.itemIdentifier(for: $0)?.asset }
        imageCacheManager.stopPrefetching(assets: assets)
    }
}
```

### 2.2 ImageCacheManager

```swift
final class ImageCacheManager {
    private let cachingManager: PHCachingImageManager
    private let thumbnailOptions: PHImageRequestOptions

    init() {
        cachingManager = PHCachingImageManager()
        cachingManager.allowsCachingHighQualityImages = false // 썸네일 우선

        thumbnailOptions = PHImageRequestOptions()
        thumbnailOptions.deliveryMode = .opportunistic  // 빠른 저품질 먼저
        thumbnailOptions.isNetworkAccessAllowed = false // 로컬만
        thumbnailOptions.isSynchronous = false
    }

    func updateCacheWindow(visible: [PHAsset], prefetch: [PHAsset], stop: [PHAsset]) {
        let targetSize = ThumbnailSizeCalculator.optimalThumbnailSize(for: 3)

        cachingManager.startCachingImages(
            for: prefetch,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: thumbnailOptions
        )

        cachingManager.stopCachingImages(
            for: stop,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: thumbnailOptions
        )
    }
}
```

### 2.3 DeletionService

```swift
final class DeletionService {

    /// 단일 삭제 (뷰어 위 스와이프)
    func deleteSingle(assetID: String) async throws {
        try await performPhotoKitDeletion(assetIDs: [assetID])
    }

    /// 멀티 삭제 (Select 모드)
    func deleteMultiple(assetIDs: [String]) async throws {
        try await performPhotoKitDeletion(assetIDs: assetIDs)
    }

    private func performPhotoKitDeletion(assetIDs: [String]) async throws {
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIDs,
            options: nil
        )

        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(fetchResult)
        }
        // 삭제된 사진은 시스템 '최근 삭제됨'으로 이동 (30일 보관)
    }
}
```

### 2.4 삭제 후 뷰어 이동 로직

```swift
// DetailViewModel
func handleDeletion(currentIndex: Int, totalCount: Int) -> NavigationAction {
    if currentIndex > 0 {
        return .moveTo(index: currentIndex - 1)  // 이전 사진으로
    } else if totalCount > 1 {
        return .moveTo(index: 0)  // 다음 사진으로 (첫 번째였으면)
    } else {
        return .dismissToGrid  // 남은 사진 없으면 그리드 복귀
    }
}
```

---

## 3. 성능 최적화 전략

### 3.1 썸네일 로딩 (≤100ms 목표)

```swift
// 디바이스별 최적 크기 계산
let cellWidth = screenWidth / 3 * scale  // 3열 기준
let targetSize = CGSize(width: cellWidth, height: cellWidth)

// Opportunistic 모드로 빠른 응답
options.deliveryMode = .opportunistic
options.resizeMode = .fast
```

### 3.2 프리페칭 윈도우

```swift
// 가시 영역 기준 ±3화면 캐싱
func updateCacheWindow(visible: [PHAsset], prefetch: [PHAsset], stop: [PHAsset]) {
    cachingManager.startCachingImages(for: prefetch, ...)
    cachingManager.stopCachingImages(for: stop, ...)
}
```

### 3.3 메모리 관리

- 메모리 경고 시 캐시 즉시 비우기
- 화면 밖 셀 이미지 자동 해제
- NSCache로 디코딩된 이미지 100MB 제한

### 3.4 백그라운드 QoS

```swift
// QoS 기반 우선순위
case .visible: .userInitiated    // 즉시 표시
case .prefetch: .utility         // 프리페칭
case .background: .background    // 기타 작업
```

### 3.5 ProMotion 120fps 지원

```swift
// CADisplayLink 120Hz 설정
displayLink.preferredFrameRateRange = CAFrameRateRange(
    minimum: 80,
    maximum: 120,
    preferred: 120
)

// UIViewPropertyAnimator 고주사율 설정
animator.preferredFrameRateRange = CAFrameRateRange(
    minimum: 80,
    maximum: 120,
    preferred: 120
)
```

**핵심 최적화:**
- 메인 스레드 작업 최소화 (8.3ms 프레임 버짓 @ 120Hz)
- 이미지 디코딩 완전 비동기화
- 레이아웃 계산 캐싱
- Metal 기반 렌더링 활용

---

## 4. 데이터 흐름

```
PhotoKit → PhotoLibraryService → ViewModel → UICollectionView
                ↓
         ImageCacheManager
                ↓
         PHCachingImageManager
```

---

## 5. 구현 순서

### Step 1: Foundation (기반 구축)
1. `Package.swift` 의존성 설정 (Photos 프레임워크)
2. `PhotoModels.swift` - 핵심 데이터 모델
3. `AlbumModels.swift` - 앨범 모델
4. `PermissionStore.swift` - 권한 상태 관리
5. `PhotoLibraryService.swift` - PhotoKit 통합
6. `AlbumService.swift` - 앨범 서비스
7. `ImageCacheManager.swift` - PHCachingImageManager 래퍼

### Step 2: Grid (그리드 뷰)
1. `PhotoGridViewController.swift` - UICollectionView 핵심
2. `PhotoGridCell.swift` - 재사용 셀
3. `PhotoGridLayout.swift` - 가변 열 레이아웃
4. `PinchZoomHandler.swift` - 핀치 줌 (연속 밀도 변화 + 앵커 유지)
5. `SelectionManager.swift` - 멀티 선택 모드
6. `GridView.swift` - SwiftUI UIViewRepresentable 래퍼
7. `GridViewModel.swift` - 상태 관리

### Step 3: Albums (앨범)
1. `AlbumListView.swift` - 앨범 리스트 화면
2. `AlbumGridView.swift` - 앨범 내 그리드 (Grid 재사용)
3. `AlbumViewModel.swift` - 앨범 상태 관리

### Step 4: Detail (상세 뷰어)
1. `DetailView.swift` - 전체화면 뷰어
2. `SwipeGestureHandler.swift` - 좌/우/위/아래 제스처
3. `DetailTransitionAnimator.swift` - 300ms 전환 애니메이션
4. `DetailViewModel.swift` - 뷰어 상태 관리

### Step 5: Delete (삭제 시스템)
1. `DeletionService.swift` - 삭제 처리

### Step 6: Permission (권한 화면)
1. `PermissionGateView.swift` - 권한 없을 때 안내
2. `PermissionViewModel.swift` - 권한 요청 로직

### Step 7: Integration (통합)
1. `ContentView.swift` 업데이트 - 탭 네비게이션
2. `PickPhotoApp.swift` - AppStateStore 연결
3. 통합 테스트

---

## 6. 참고 자료

- [PHCachingImageManager - Apple Docs](https://developer.apple.com/documentation/photos/phcachingimagemanager)
- [PHImageRequestOptions.deliveryMode](https://developer.apple.com/documentation/photokit/phimagerequestoptionsdeliverymode/opportunistic)
- [CodeWithChris Photo Gallery Memory Management](https://codewithchris.com/photo-gallery-app-swiftui-part-1/)
- [Kodeco iOS Photos Framework](https://www.kodeco.com/7910383-ios-photos-framework/lessons/5)
- [objc.io - The Photos Framework](https://www.objc.io/issues/21-camera-and-photos/the-photos-framework/)

---

## 7. 문서 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 2.0 | 2025-12-15 | PRD1에서 기술 설계 내용 분리, prd4.md와 연동 |

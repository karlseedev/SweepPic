# PickPhoto 네이티브 수준 성능 구현 계획

> 안내: `docs/prd3.md`가 현재 기준 PRD입니다. 본 문서(`docs/prd1.md`)의 구현 상세(파일 구조/코드 스니펫/클래스 설계)는 `docs/tech_spec.md`로 분리해 관리하는 것을 권장합니다.

## 1. 개요

### 1.1 목표
아이폰 네이티브 사진 앱 수준의 성능과 UX를 달성하는 사진 갤러리 앱 구현

### 1.2 타깃 환경

| 구분 | 사양 |
|------|------|
| 최상위 타깃 | iPhone 17 Pro (ProMotion 120Hz) |
| 최저 타깃 | iPhone 12 |
| iOS 버전 | iOS 16+ |

### 1.3 핵심 원칙
- Apple이 제공하는 공식 API와 도구를 최대한 활용
- 네이티브 앱과 동일한 기술 스택 사용
- ProMotion 디스플레이에서 120fps, 일반 디스플레이에서 60fps 유지
- 5만 장 이상의 대규모 라이브러리에서도 성능 저하 없음

---

## 2. 핵심 기술 결정

### 2.1 그리드 뷰: UICollectionView (UIViewRepresentable)

| 기준 | SwiftUI LazyVGrid | UICollectionView |
|------|-------------------|------------------|
| 셀 재사용 | 없음 (뷰 생성/해제 반복) | 완전한 재사용 풀 |
| 메모리 (5만장) | 누적 증가 위험 | 일정 수준 유지 |
| Prefetch 제어 | 제한적 | `prefetchDataSource` 완전 지원 |
| 스크롤 FPS | 대규모에서 드랍 | 120fps 안정 (ProMotion) |
| 120Hz 지원 | 제한적 | CADisplayLink 완전 제어 |

**결정: UICollectionView 사용**
- 셀 재사용 메커니즘으로 5만 장 이상에서도 메모리 안정
- `UICollectionViewDataSourcePrefetching`으로 정밀한 프리페칭 제어
- `DiffableDataSource`로 효율적인 업데이트
- SwiftUI `LazyVGrid`는 메모리 누적 문제 있음

### 2.2 이미지 캐싱: PHCachingImageManager

Apple의 공식 캐싱 솔루션 활용:
- `startCachingImages()` / `stopCachingImages()`로 가시 영역 ±3화면 프리캐싱
- `deliveryMode = .opportunistic`으로 저품질 먼저 → 고품질 대체
- `isNetworkAccessAllowed = false`로 로컬 전용 (iCloud 대기 방지)

### 2.3 아키텍처: 단방향 데이터 흐름

```
PhotoKit → PhotoLibraryService → ViewModel → UICollectionView
                ↓
         ImageCacheManager
                ↓
         PHCachingImageManager
```

---

## 3. 파일 구조

### 3.1 AppCore (Swift Package) - 비즈니스 로직

```
Sources/AppCore/
├── Models/
│   ├── PhotoModels.swift           # PhotoAssetEntry, PhotoSection
│   ├── AlbumModels.swift           # Album, SmartAlbum
│   ├── DeletionAction.swift        # 삭제 상태 머신
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

### 3.2 PickPhoto (SwiftUI App) - UI 레이어

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

## 4. 성능 최적화 전략

### 4.1 썸네일 로딩 (≤100ms 목표)

```swift
// 디바이스별 최적 크기 계산
let cellWidth = screenWidth / 3 * scale  // 3열 기준
let targetSize = CGSize(width: cellWidth, height: cellWidth)

// Opportunistic 모드로 빠른 응답
options.deliveryMode = .opportunistic
options.resizeMode = .fast
```

### 4.2 프리페칭 윈도우

```swift
// 가시 영역 기준 ±3화면 캐싱
func updateCacheWindow(visible: [PHAsset], prefetch: [PHAsset], stop: [PHAsset]) {
    cachingManager.startCachingImages(for: prefetch, ...)
    cachingManager.stopCachingImages(for: stop, ...)
}
```

### 4.3 메모리 관리

- 메모리 경고 시 캐시 즉시 비우기
- 화면 밖 셀 이미지 자동 해제
- NSCache로 디코딩된 이미지 100MB 제한

### 4.4 백그라운드 처리

```swift
// QoS 기반 우선순위
case .visible: .userInitiated    // 즉시 표시
case .prefetch: .utility         // 프리페칭
case .background: .background    // 얼굴 인식 등
```

---

## 5. 구현 순서

### Step 1: Foundation (기반 구축)
1. `Package.swift` 의존성 설정 (Photos 프레임워크)
2. `PhotoModels.swift` - 핵심 데이터 모델
   - PhotoAssetEntry, PhotoSection, DeletionAction
   - **테스트**: PhotoModelsTests.swift
3. `AlbumModels.swift` - 앨범 모델
   - Album, SmartAlbum
4. `PermissionStore.swift` - 권한 상태 관리
   - **테스트**: PermissionStoreTests.swift
5. `PhotoLibraryService.swift` - PhotoKit 통합
   - fetch, change observer, 배치 처리
   - **테스트**: PhotoLibraryServiceTests.swift (Mock 사용)
6. `AlbumService.swift` - 앨범 서비스
   - 사용자 앨범, 스마트 앨범 (Screenshots 등)
7. `ImageCacheManager.swift` - PHCachingImageManager 래퍼
   - 프리페칭 윈도우 관리
   - **테스트**: ImageCacheManagerTests.swift

### Step 2: Grid (그리드 뷰)
1. `PhotoGridViewController.swift` - UICollectionView 핵심
   - 셀 재사용, Prefetch DataSource
2. `PhotoGridCell.swift` - 재사용 셀
3. `PhotoGridLayout.swift` - 가변 열 레이아웃
4. `PinchZoomHandler.swift` - 핀치 줌 (연속 밀도 변화 + 앵커 유지)
5. `SelectionManager.swift` - 멀티 선택 모드 (Select 모드)
6. `GridView.swift` - SwiftUI UIViewRepresentable 래퍼
7. `GridViewModel.swift` - 상태 관리
   - **테스트**: GridViewModelTests.swift

### Step 3: Albums (앨범)
1. `AlbumListView.swift` - 앨범 리스트 화면
2. `AlbumGridView.swift` - 앨범 내 그리드 (Grid 재사용)
3. `AlbumViewModel.swift` - 앨범 상태 관리
   - **테스트**: AlbumViewModelTests.swift

### Step 4: Detail (상세 뷰어)
1. `DetailView.swift` - 전체화면 뷰어
2. `SwipeGestureHandler.swift` - 좌/우/위/아래 제스처
   - 위 스와이프: 삭제
   - 좌/우: 이전/다음 사진
   - 아래: 그리드 복귀
3. `DetailTransitionAnimator.swift` - 300ms 전환 애니메이션
4. `DetailViewModel.swift` - 뷰어 상태 관리
   - **테스트**: DetailViewModelTests.swift

### Step 5: Delete (삭제 시스템)
1. `DeletionService.swift` - 삭제 처리
   - 단일 삭제 (뷰어 위 스와이프)
   - 멀티 삭제 (Select 모드)
   - 확인 팝업 없이 즉시 삭제
   - **테스트**: DeletionServiceTests.swift
2. 삭제 후 동작:
   - 뷰어: 이전 사진으로 이동 → 없으면 다음 → 없으면 그리드 복귀
   - 복구: 시스템 Photos '최근 삭제됨'에서 (MVP)

**MVP 제외 (후속 버전):**
- 앱 내 휴지통/복구 기능

### Step 6: Permission (권한 화면)
1. `PermissionGateView.swift` - 권한 없을 때 안내
2. `PermissionViewModel.swift` - 권한 요청 로직

### Step 7: Integration (통합)
1. `ContentView.swift` 업데이트 - 탭 네비게이션 (라이브러리/앨범)
2. `PickPhotoApp.swift` - AppStateStore 연결
3. **통합 테스트**: 전체 플로우 테스트

---

## 6. 성능 목표

### 6.1 FPS 목표

| 디바이스 | 디스플레이 | 목표 FPS |
|----------|-----------|----------|
| Pro 모델 (13 Pro 이상) | ProMotion 120Hz | **120fps** |
| 일반 모델 | 60Hz | 60fps |

### 6.2 세부 성능 지표

| 지표 | 목표 | 달성 전략 |
|------|------|-----------|
| 스크롤 FPS | **≥120** (ProMotion) | UICollectionView + Prefetch + 비동기 디코딩 + CADisplayLink |
| 썸네일 로딩 | ≤100ms | PHCachingImageManager + opportunistic |
| 캐시 히트율 | ≥90% | ±3화면 프리캐싱 |
| 전환 애니메이션 | 300ms, 120fps | UIViewPropertyAnimator + preferredFrameRateRange |
| 삭제 응답 | ≤500ms | Actor 기반 파이프라인 |
| 메모리 | ≤400MB | LRU + 메모리 경고 대응 |
| 콜드 스타트 | ≤2초 | 배치 처리 + 지연 로딩 |

### 6.3 ProMotion 120fps 지원 전략

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

## 7. 핵심 컴포넌트 상세 설계

### 7.1 PhotoGridViewController

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

### 7.2 ImageCacheManager

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

### 7.3 DeletionService

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

**삭제 후 뷰어 이동 로직:**
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

## 8. 참고 자료

- [PHCachingImageManager - Apple Docs](https://developer.apple.com/documentation/photos/phcachingimagemanager)
- [PHImageRequestOptions.deliveryMode](https://developer.apple.com/documentation/photokit/phimagerequestoptionsdeliverymode/opportunistic)
- [CodeWithChris Photo Gallery Memory Management](https://codewithchris.com/photo-gallery-app-swiftui-part-1/)
- [Kodeco iOS Photos Framework](https://www.kodeco.com/7910383-ios-photos-framework/lessons/5)
- [objc.io - The Photos Framework](https://www.objc.io/issues/21-camera-and-photos/the-photos-framework/)

---

## 9. 문서 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2025-12-15 | 초안 작성 |
| 1.1 | 2025-12-15 | 타깃 디바이스 명시 (iPhone 12~17 Pro, iOS 16+), 120fps 목표 추가 |
| 1.2 | 2025-12-15 | PRD2와 통합 결정 반영: 앨범/핀치줌/멀티선택 MVP 포함, 삭제 후 이전 사진 이동 |

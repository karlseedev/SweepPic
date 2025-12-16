# PickPhoto 기술 설계 문서 (Tech Spec)

> 본 문서는 [prd5.md](./prd5.md)의 기술 구현 상세를 담고 있습니다.
> PRD의 요구사항과 검증 게이트를 만족하는 구현 방식을 정의합니다.

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
│   ├── DeletionService.swift       # 삭제 처리, 권한 검증 포함
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
│   │   ├── PhotoGridLayout.swift             # 1/3/5열 가변 레이아웃
│   │   ├── PinchZoomHandler.swift            # 핀치 줌 (1/3/5열 + 앵커 유지)
│   │   ├── SelectionManager.swift            # 멀티 선택 모드
│   │   └── GridViewModel.swift
│   ├── Albums/
│   │   ├── AlbumListView.swift               # 앨범 리스트
│   │   ├── AlbumGridView.swift               # 앨범 내 그리드
│   │   └── AlbumViewModel.swift
│   ├── Detail/
│   │   ├── DetailView.swift
│   │   ├── DetailTransitionAnimator.swift    # 전환 애니메이션
│   │   └── SwipeGestureHandler.swift         # 위 스와이프 삭제 포함
│   └── Permissions/
│       └── PermissionGateView.swift
└── Shared/
```

---

## 2. 핵심 컴포넌트 설계

> 아래 설계는 **Spike 0, Spike 1 결과**에 따라 조정될 수 있습니다.
> 현재는 UIKit + DiffableDataSource 기반으로 작성되었습니다.

### 2.1 PhotoGridViewController

```swift
final class PhotoGridViewController: UIViewController {

    // MARK: - 줌 단계 (PRD 6.3: 1/3/5열)
    enum ZoomLevel: Int, CaseIterable {
        case single = 1   // 1열
        case normal = 3   // 3열 (기본)
        case dense = 5    // 5열
    }

    private var currentZoomLevel: ZoomLevel = .normal

    private lazy var collectionView: UICollectionView = {
        let layout = PhotoGridLayout(columns: currentZoomLevel.rawValue, spacing: 2)
        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.prefetchDataSource = self
        cv.isPrefetchingEnabled = true
        return cv
    }()

    // 데이터 소스 패턴: Spike 1 결과에 따라 확정
    private var dataSource: UICollectionViewDiffableDataSource<PhotoSection, PhotoAssetEntry>!
    private let cachingImageManager = PHCachingImageManager()

    // preheat 윈도우: Gate 2에서 확정 (±N, N ∈ {1,2,3,4})
    private var prefetchBuffer = 3  // 임시값, Gate 2에서 조정
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
        // 썸네일 옵션: Gate 2에서 A/B 테스트 후 확정
        // A) 빠른 표시: .opportunistic + .fast
        // B) 품질 우선: .highQualityFormat
        thumbnailOptions.deliveryMode = .opportunistic
        thumbnailOptions.resizeMode = .fast
        thumbnailOptions.isNetworkAccessAllowed = false // 로컬만 (PRD 4.2)
        thumbnailOptions.isSynchronous = false
    }

    func updateCacheWindow(visible: [PHAsset], prefetch: [PHAsset], stop: [PHAsset]) {
        let targetSize = ThumbnailSizeCalculator.optimalThumbnailSize(
            for: currentColumns  // 1/3/5열에 따라 동적 계산
        )

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

    // MARK: - 권한 검증 (PRD 5.3 삭제 안전장치)

    var canDelete: Bool {
        PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
    }

    /// 단일 삭제 (뷰어 위 스와이프)
    func deleteSingle(assetID: String) async throws {
        guard canDelete else {
            throw DeletionError.insufficientPermission
        }
        try await performPhotoKitDeletion(assetIDs: [assetID])
    }

    /// 멀티 삭제 (Select 모드)
    func deleteMultiple(assetIDs: [String]) async throws {
        guard canDelete else {
            throw DeletionError.insufficientPermission
        }
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

enum DeletionError: Error {
    case insufficientPermission
    case assetNotFound
}
```

### 2.4 삭제 후 뷰어 이동 로직

```swift
// DetailViewModel
// PRD 5.3: "이전 사진 우선" 규칙 준수
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

### 2.5 PinchZoomHandler

```swift
final class PinchZoomHandler {

    // PRD 6.3: 줌 단계 1/3/5열
    private let zoomLevels: [Int] = [1, 3, 5]
    private var currentLevelIndex: Int = 1  // 3열 시작

    // 앵커 유지 (PRD 6.3: 점프/떨림 없이 유지)
    private var anchorAssetID: String?
    private var anchorRelativePosition: CGPoint?

    func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            captureAnchor(at: gesture.location(in: collectionView))
        case .changed:
            updateZoomLevel(scale: gesture.scale)
        case .ended:
            snapToNearestLevel()
            restoreAnchor()
        default:
            break
        }
    }

    private func captureAnchor(at point: CGPoint) {
        // 핀치 중심점 아래 콘텐츠를 앵커로 캡처
        guard let indexPath = collectionView.indexPathForItem(at: point),
              let asset = dataSource.itemIdentifier(for: indexPath) else { return }
        anchorAssetID = asset.localIdentifier
        // 셀 내 상대 위치 저장
    }

    private func restoreAnchor() {
        // 줌 변화 후 앵커 콘텐츠가 동일 위치에 오도록 오프셋 보정
    }
}
```

---

## 3. 성능 최적화 전략

### 3.1 썸네일 로딩 (≤100ms 목표)

```swift
// 디바이스별 최적 크기 계산 (1/3/5열에 따라 동적)
func optimalThumbnailSize(for columns: Int) -> CGSize {
    let cellWidth = screenWidth / CGFloat(columns) * scale
    return CGSize(width: cellWidth, height: cellWidth)
}

// 썸네일 옵션: Gate 2에서 A/B 테스트 후 확정
options.deliveryMode = .opportunistic  // 또는 .highQualityFormat
options.resizeMode = .fast
```

### 3.2 프리페칭 윈도우

```swift
// preheat 정책: Gate 2에서 확정
// A) 고정 윈도우: ±N (N ∈ {1,2,3,4})
// B) 속도 적응형: 느림 ±1, 보통 ±2, 빠름 ±3

func updateCacheWindow(visible: [PHAsset], prefetch: [PHAsset], stop: [PHAsset]) {
    cachingManager.startCachingImages(for: prefetch, ...)
    cachingManager.stopCachingImages(for: stop, ...)
}
```

### 3.3 메모리 관리

- 메모리 경고 시 캐시 즉시 비우기
- 화면 밖 셀 이미지 자동 해제
- NSCache로 디코딩된 이미지 100MB 제한
- **PRD 6.5**: 장시간 사용 후 400MB 이내 유지

### 3.4 백그라운드 QoS

```swift
// QoS 기반 우선순위
case .visible: .userInitiated    // 즉시 표시
case .prefetch: .utility         // 프리페칭
case .background: .background    // 기타 작업
```

### 3.5 ProMotion 지원

> **PRD 6.2**: ProMotion은 가변 주사율(10~120Hz)이며, 앱이 120Hz를 강제할 수는 없음.
> **목표**: 시스템이 120Hz를 선택할 수 있도록 프레임 버짓(8.3ms) 준수를 보장

```swift
// CADisplayLink에 선호 프레임 레이트 힌트 제공
displayLink.preferredFrameRateRange = CAFrameRateRange(
    minimum: 80,
    maximum: 120,
    preferred: 120
)

// UIViewPropertyAnimator도 동일하게 설정
animator.preferredFrameRateRange = CAFrameRateRange(
    minimum: 80,
    maximum: 120,
    preferred: 120
)
```

**핵심 최적화 (8.3ms 프레임 버짓 준수):**
- 메인 스레드 작업 최소화
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

## 5. 구현 순서 (검증 게이트 연동)

> PRD 9.2의 검증 게이트와 연동된 구현 순서입니다.

### Phase 0: 스파이크 (개발 전)

| 스파이크 | 결정 사항 |
|----------|-----------|
| Spike 0 | UI 기술 스택 (UIKit vs SwiftUI) |
| Spike 1 | 데이터 소스 패턴 (DiffableDataSource vs 수동) |

### Phase 1: Foundation → Gate 1

1. `Package.swift` 의존성 설정 (Photos 프레임워크)
2. `PhotoModels.swift` - 핵심 데이터 모델
3. `AlbumModels.swift` - 앨범 모델
4. `PermissionStore.swift` - 권한 상태 관리
5. `PhotoLibraryService.swift` - PhotoKit 통합
6. `PhotoGridViewController.swift` - UICollectionView 핵심
7. `PhotoGridCell.swift` - 재사용 셀 (placeholder)
8. `PhotoGridLayout.swift` - 1/3/5열 가변 레이아웃

**Gate 1 검증**: 5만 장 더미 셀 스크롤 hitch 목표 이내

### Phase 2: 이미지 로딩 → Gate 2

1. `ImageCacheManager.swift` - PHCachingImageManager 래퍼
2. `ImageRequestCoordinator.swift` - 요청/취소 관리
3. 썸네일 옵션 A/B 테스트
4. preheat 정책 튜닝

**Gate 2 검증**: 오표시 0, 첫 그리드 유효 썸네일 목표 이내

### Phase 3: 핀치/삭제 → Gate 3

1. `PinchZoomHandler.swift` - 핀치 줌 (1/3/5열 + 앵커 유지)
2. `SelectionManager.swift` - 멀티 선택 모드
3. `DeletionService.swift` - 삭제 처리 (권한 검증 포함)
4. `DetailView.swift` - 전체화면 뷰어
5. `SwipeGestureHandler.swift` - 위 스와이프 삭제

**Gate 3 검증**: 핀치 앵커 유지, 삭제 안정성

### Phase 4: 앨범/통합 → Gate 4

1. `AlbumService.swift` - 앨범 서비스
2. `AlbumListView.swift` - 앨범 리스트 화면
3. `AlbumGridView.swift` - 앨범 내 그리드
4. `ContentView.swift` 업데이트 - 탭 네비게이션
5. 성능 튜닝 및 최적화

**Gate 4 검증**: 120Hz 프레임 버짓, 메모리 400MB 이내, 콜드 스타트 목표 이내

---

## 6. 미확정 항목 (스파이크/게이트 후 확정)

| 항목 | 확정 시점 | 후보 |
|------|-----------|------|
| UI 기술 스택 | Spike 0 | UIKit vs SwiftUI |
| 데이터 소스 패턴 | Spike 1 | DiffableDataSource vs 수동 배치 |
| preheat 윈도우 크기 | Gate 2 | ±N (N ∈ {1,2,3,4}) 또는 속도 적응형 |
| 썸네일 옵션 | Gate 2 | opportunistic+fast vs highQualityFormat |
| 변경 감지 업데이트 규칙 | Gate 3 | 부분 업데이트 vs 전체 리로드 조건 |

---

## 7. 참고 자료

- [PHCachingImageManager - Apple Docs](https://developer.apple.com/documentation/photos/phcachingimagemanager)
- [PHImageRequestOptions.deliveryMode](https://developer.apple.com/documentation/photokit/phimagerequestoptionsdeliverymode/opportunistic)
- [UICollectionViewDiffableDataSource](https://developer.apple.com/documentation/uikit/uicollectionviewdiffabledatasource)
- [CAFrameRateRange](https://developer.apple.com/documentation/quartzcore/caframeraterange)

---

## 8. 문서 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 2.0 | 2025-12-15 | PRD1에서 기술 설계 내용 분리, prd4.md와 연동 |
| **3.0** | **2025-12-15** | **prd5.md와 연동**, 1/3/5열 줌 단계 반영, ProMotion 표현 수정 (프레임 버짓 준수 보장), 삭제 안전장치(권한 검증) 추가, 구현 순서를 Gate와 연동, 미확정 항목 섹션 추가 |

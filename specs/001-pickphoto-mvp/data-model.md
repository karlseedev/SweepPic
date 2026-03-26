# Data Model: SweepPic MVP

**Branch**: `001-pickphoto-mvp`
**Created**: 2025-12-16

## Overview

SweepPic MVP의 데이터 모델은 PhotoKit API를 기반으로 하며, 앱 내 휴지통 상태를 로컬에 저장합니다.

---

## Core Entities

### PhotoAssetEntry

PhotoKit의 `PHAsset`을 래핑하는 앱 내부 표현입니다.

```swift
struct PhotoAssetEntry: Identifiable, Hashable {
    // Primary Key (PHAsset.localIdentifier)
    let localIdentifier: String

    // Metadata
    let creationDate: Date?
    let mediaType: MediaType
    let pixelWidth: Int
    let pixelHeight: Int

    // Computed (from TrashState)
    var isTrashed: Bool { TrashStore.shared.isTrashed(localIdentifier) }

    var id: String { localIdentifier }
}

enum MediaType: String, Codable {
    case photo
    case video
    case livePhoto
}
```

**Relationships**:
- Many-to-Many: Album (PHAsset은 여러 앨범에 속할 수 있음)
- One-to-One: TrashState (휴지통 상태)

**Validation Rules**:
- `localIdentifier`는 빈 문자열 불가
- `creationDate`가 nil이면 정렬 시 맨 뒤로

---

### TrashState

앱 내 휴지통 상태를 관리합니다. PhotoKit에서 실제 삭제하지 않고 로컬에만 저장합니다.

```swift
struct TrashState: Codable {
    // 휴지통에 있는 사진 ID 집합
    var trashedAssetIDs: Set<String>

    // 삭제 시각 (향후 자동 정리용)
    var trashDates: [String: Date]

    // 상태 변경 시 알림
    var lastModified: Date
}
```

**Persistence**:
- 파일 기반 저장 (대용량 ID Set 대응)
- Key: `"SweepPic.TrashState"`

**State Transitions**:

```
┌─────────────────┐
│  Normal Photo   │
│  (isTrashed=F)  │
└────────┬────────┘
         │
         │ moveToTrash()
         ▼
┌─────────────────┐
│  Trashed Photo  │
│  (isTrashed=T)  │◄──────┐
│  (Dimmed 표시)  │       │
└────────┬────────┘       │
         │                │
    ┌────┴────┐           │
    │         │           │
    ▼         ▼           │
restore()  permanentlyDelete()
    │         │           │
    │         │           │
    │         ▼           │
    │  ┌─────────────┐    │
    │  │ iOS 최근    │    │
    │  │ 삭제됨     │    │
    │  │ (시스템팝업)│    │
    │  └─────────────┘    │
    │                     │
    └─────────────────────┘
```

---

### Album

사용자가 생성한 앨범을 나타냅니다.

```swift
struct Album: Identifiable, Hashable {
    // Primary Key (PHAssetCollection.localIdentifier)
    let localIdentifier: String

    // Metadata
    let title: String
    let assetCount: Int
    let creationDate: Date?

    // 대표 썸네일 (최신 사진)
    let keyAssetIdentifier: String?

    var id: String { localIdentifier }
}
```

**Relationships**:
- One-to-Many: PhotoAssetEntry (앨범 내 사진들)

---

### SmartAlbum

시스템 정의 스마트 앨범입니다.

```swift
struct SmartAlbum: Identifiable, Hashable {
    // 스마트 앨범 타입
    let type: PHAssetCollectionSubtype

    // 로컬라이즈된 제목
    let title: String

    // 사진 수
    let assetCount: Int

    var id: Int { type.rawValue }
}
```

**MVP 지원 타입**:
- `.smartAlbumScreenshots` - 스크린샷

---

### TrashAlbum (Virtual)

앱 내 휴지통을 앨범처럼 표시하기 위한 가상 앨범입니다.

```swift
struct TrashAlbum: Identifiable {
    let id = "trash"
    let title = "휴지통"

    var assetCount: Int { TrashStore.shared.trashedCount }
    var isEmpty: Bool { assetCount == 0 }
}
```

---

## PhotoKit Mapping

### All Photos Fetch

```swift
// PRD 5.1 All Photos 정의
let fetchOptions = PHFetchOptions()
fetchOptions.sortDescriptors = [
    NSSortDescriptor(key: "creationDate", ascending: true) // 오래된 것이 위
]
fetchOptions.predicate = NSPredicate(
    format: "mediaType == %d OR mediaType == %d",
    PHAssetMediaType.image.rawValue,
    PHAssetMediaType.video.rawValue
)
// Live Photo는 image 타입에 포함됨

let allPhotos = PHAsset.fetchAssets(with: fetchOptions)
```

### Album Fetch

```swift
// 사용자 앨범
let userAlbums = PHAssetCollection.fetchAssetCollections(
    with: .album,
    subtype: .albumRegular,
    options: nil
)

// 스마트 앨범 (Screenshots)
let screenshots = PHAssetCollection.fetchAssetCollections(
    with: .smartAlbum,
    subtype: .smartAlbumScreenshots,
    options: nil
)
```

---

## Local Storage Schema

### TrashState Persistence (파일 기반)

```swift
// 파일 경로 (Documents 디렉토리)
var trashStateURL: URL {
    FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        .appendingPathComponent("TrashState.json")
}

// 저장 (비동기, 증분 업데이트 고려)
func saveTrashState(_ state: TrashState) async throws {
    let encoder = JSONEncoder()
    let data = try encoder.encode(state)
    try data.write(to: trashStateURL, options: .atomic)
}

// 로드 (앱 시작 시 1회)
func loadTrashState() -> TrashState {
    guard let data = try? Data(contentsOf: trashStateURL),
          let state = try? JSONDecoder().decode(TrashState.self, from: data) else {
        return TrashState(trashedAssetIDs: [], trashDates: [:], lastModified: Date())
    }
    return state
}
```

> **Note**: UserDefaults는 앱 시작 시 전체 plist를 메모리에 로드하며, [Apple은 512KB 이하를 권장](https://www.vadimbulavin.com/advanced-guide-to-userdefaults-in-swift/). 수만 개 ID Set은 이를 초과할 수 있어 파일 기반 저장 채택.

---

## Validation Rules

### PhotoAssetEntry

| 필드 | 규칙 |
|------|------|
| localIdentifier | 비어있으면 안 됨 |
| creationDate | nil 허용 (정렬 시 맨 뒤) |
| mediaType | photo/video/livePhoto 중 하나 |

### TrashState

| 필드 | 규칙 |
|------|------|
| trashedAssetIDs | PhotoKit에 존재하지 않는 ID는 자동 정리 |
| trashDates | trashedAssetIDs와 키 일치 보장 |

---

## Data Flow

### 사진 브라우징

```
PHFetchResult<PHAsset>
        │
        ▼
[PhotoAssetEntry 변환]
        │
        ▼
[TrashState 적용] ──► isTrashed 계산
        │
        ▼
GridDataSourceDriver
        │
        ▼
UICollectionView
```

### 삭제 플로우

```
사용자 삭제 액션
        │
        ▼
TrashStore.moveToTrash()
        │
        ├──► TrashState 업데이트
        │
        └──► GridDataSourceDriver.applyTrashStateChange()
                    │
                    ▼
              셀 딤드 표시 업데이트
```

### 완전 삭제 플로우

```
사용자 완전삭제/비우기 액션
        │
        ▼
TrashStore.permanentlyDelete()
        │
        ▼
PHPhotoLibrary.performChanges {
    PHAssetChangeRequest.deleteAssets(assets)
}
        │
        ▼
[iOS 시스템 팝업 표시]
        │
        ▼
성공 시: TrashState에서 제거
```

# Data Model: 유사 사진 정리 기능

**Date**: 2025-12-31
**Feature**: 001-similar-photo

---

## Entities

### SimilarGroup

유사한 사진들의 그룹을 나타냄

```swift
/// 유사 사진 그룹 모델
/// - 최소 3장 이상의 유사한 사진으로 구성
/// - 모든 사진에는 얼굴이 감지되어야 함
struct SimilarGroup: Identifiable {
    /// 그룹 고유 식별자
    let id: UUID

    /// 그룹에 포함된 사진들의 PHAsset localIdentifier 목록
    /// - 최소 3개 이상
    /// - 정렬 순서: 그리드/뷰어 표시 순서 기준
    let assetIdentifiers: [String]

    /// 그룹 생성 시점의 기준 사진 identifier
    /// - 뷰어: 현재 표시 중인 사진
    /// - 그리드: 화면 중앙에 가장 가까운 사진
    let anchorAssetIdentifier: String

    /// 그룹 내 사진 개수
    var count: Int { assetIdentifiers.count }

    /// 유효성 검증
    var isValid: Bool { assetIdentifiers.count >= 3 }
}
```

**Validation Rules**:
- `assetIdentifiers.count >= 3` (최소 3장)
- 모든 identifier는 유효한 PHAsset을 참조해야 함
- 앱 내 휴지통에 있는 사진은 포함되지 않음

---

### FaceRegion

사진 내 감지된 얼굴 영역 정보

```swift
/// 사진 내 감지된 얼굴 영역
/// - Vision Framework의 VNFaceObservation에서 추출
struct FaceRegion: Identifiable {
    /// 얼굴 영역 고유 식별자
    let id: UUID

    /// 해당 사진의 PHAsset localIdentifier
    let assetIdentifier: String

    /// 정규화된 bounding box (0.0~1.0 범위)
    /// - Vision 좌표계: 왼쪽 아래 원점
    let normalizedBoundingBox: CGRect

    /// 얼굴 크기 비율 (화면 너비 대비)
    /// - 5% 미만은 필터링됨
    let sizeRatio: CGFloat

    /// 인물 번호 (1부터 시작)
    /// - 좌→우, 위→아래 순서로 부여
    let personIndex: Int

    /// Vision 감지 신뢰도 (0.0~1.0)
    let confidence: Float
}
```

**Validation Rules**:
- `sizeRatio >= 0.05` (화면 너비 5% 이상)
- `personIndex >= 1 && personIndex <= 5` (최대 5명)
- `normalizedBoundingBox` 값은 0.0~1.0 범위

**State Transitions**: N/A (불변 데이터)

---

### PersonComparison

특정 인물의 얼굴 비교 상태 관리

```swift
/// 얼굴 비교 화면의 인물별 상태
/// - 2열 그리드에 표시될 얼굴 크롭 정보 포함
struct PersonComparison {
    /// 비교 대상 인물 번호 (1~5)
    let personIndex: Int

    /// 이 인물이 포함된 사진들의 identifier 목록
    let assetIdentifiers: [String]

    /// 각 사진별 얼굴 크롭 이미지
    /// - Key: assetIdentifier
    /// - Value: 크롭된 UIImage (30% 여백 포함, 정사각형)
    var croppedImages: [String: UIImage]

    /// 선택된 사진들의 identifier Set
    var selectedAssetIdentifiers: Set<String>

    /// 선택된 사진 개수
    var selectedCount: Int { selectedAssetIdentifiers.count }

    /// 비교 가능한 사진 개수
    var comparableCount: Int { assetIdentifiers.count }
}
```

**Validation Rules**:
- `personIndex` 범위: 1~5
- `assetIdentifiers`는 해당 인물 얼굴이 감지된 사진만 포함

**State Transitions**:
- **Initial**: 모든 사진 미선택 (`selectedAssetIdentifiers.isEmpty`)
- **Selecting**: 사진 선택/해제 토글
- **Cancelled**: Cancel 버튼으로 모든 선택 해제
- **Deleted**: Delete 버튼으로 선택된 사진 삭제

---

### SimilarPhotoState

유사 사진 기능의 전역 상태

```swift
/// 유사 사진 기능 전체 상태 관리
/// - SimilarPhotoStore에서 관리
struct SimilarPhotoState {
    /// 현재 분석된 유사 그룹 목록
    var groups: [SimilarGroup]

    /// 그리드에서 테두리 표시 중인 assetIdentifier Set
    var highlightedAssets: Set<String>

    /// 현재 분석 진행 중 여부
    var isAnalyzing: Bool

    /// 뷰어에서 + 버튼 오버레이 표시 중 여부
    var isShowingFaceOverlay: Bool

    /// 현재 표시 중인 얼굴 영역 목록 (뷰어용)
    var currentFaceRegions: [FaceRegion]

    /// 얼굴 비교 화면 활성화 여부
    var isComparingFaces: Bool

    /// 현재 비교 중인 인물 정보
    var currentComparison: PersonComparison?
}
```

---

## Relationships

```
┌─────────────────────────────────────────────────────────────────┐
│                        SimilarPhotoState                         │
│  (SimilarPhotoStore에서 관리하는 전역 상태)                        │
└─────────────────────────────────────────────────────────────────┘
         │
         │ contains
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                         SimilarGroup                             │
│  - assetIdentifiers: [String]  ────────────────────┐            │
│  - anchorAssetIdentifier: String                    │            │
└─────────────────────────────────────────────────────│────────────┘
                                                      │
         ┌────────────────────────────────────────────┘
         │ references (PHAsset localIdentifier)
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                          PHAsset                                 │
│  (PhotoKit 제공, 기존 PhotoModels.swift의 PhotoAssetEntry 참조)  │
└─────────────────────────────────────────────────────────────────┘
         │
         │ detected from
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                         FaceRegion                               │
│  - assetIdentifier: String  (1:N 관계 - 한 사진에 여러 얼굴)     │
│  - personIndex: Int                                              │
└─────────────────────────────────────────────────────────────────┘
         │
         │ grouped into
         ▼
┌─────────────────────────────────────────────────────────────────┐
│                      PersonComparison                            │
│  - personIndex: Int                                              │
│  - assetIdentifiers: [String]  (동일 인물 위치의 사진들)         │
│  - selectedAssetIdentifiers: Set<String>                        │
└─────────────────────────────────────────────────────────────────┘
```

---

## Integration with Existing Models

### PhotoModels.swift 연동

```swift
// 기존 PhotoAssetEntry와의 관계
extension SimilarGroup {
    /// PHFetchResult에서 해당 그룹의 인덱스 목록 반환
    func indices(in fetchResult: PHFetchResult<PHAsset>) -> [Int] {
        assetIdentifiers.compactMap { identifier in
            // PHAsset.localIdentifier로 인덱스 찾기
            fetchResult.index(of: PHAsset.fetchAssets(
                withLocalIdentifiers: [identifier],
                options: nil
            ).firstObject ?? PHAsset())
        }
    }
}
```

### TrashStore 연동

```swift
// 삭제 시 기존 TrashStore 활용
extension PersonComparison {
    /// 선택된 사진들을 휴지통으로 이동
    func deleteSelectedPhotos(using trashStore: TrashStore) async throws {
        let identifiers = Array(selectedAssetIdentifiers)
        try await trashStore.moveToTrash(assetIdentifiers: identifiers)
    }
}
```

---

## Data Flow

### 1. 그리드 분석 플로우

```
스크롤 멈춤 (0.3초 디바운싱)
    │
    ▼
GridViewController → SimilarPhotoStore.analyzeVisibleRange(indices:)
    │
    ▼
SimilarityService.findSimilarGroups(assets:) → [SimilarGroup]
    │
    ▼
FaceDetectionService.filterByFace(groups:) → [SimilarGroup] (얼굴 있는 것만)
    │
    ▼
SimilarPhotoState.groups 업데이트
    │
    ▼
PhotoCell.showSimilarBorder() (테두리 표시)
```

### 2. 뷰어 분석 플로우

```
사진 표시/스와이프
    │
    ▼
ViewerViewController → SimilarPhotoStore.analyzeCurrentPhoto(index:)
    │
    ▼
SimilarityService.findSimilarGroup(anchorIndex:, range: ±7)
    │
    ▼
조건 충족 (3장 이상 + 얼굴 있음)?
    │
    ├─ Yes → 유사사진정리버튼 표시
    │
    └─ No → 버튼 숨김
```

### 3. 얼굴 비교 플로우

```
유사사진정리버튼 탭
    │
    ▼
FaceDetectionService.detectFaces(in: currentAsset)
    │
    ▼
[FaceRegion] 생성 (5% 이상, 최대 5개, 위치순 정렬)
    │
    ▼
+ 버튼 오버레이 표시
    │
    ▼
+ 버튼 탭 (인물 N)
    │
    ▼
PersonComparison 생성 (해당 인물 얼굴만)
    │
    ▼
FaceComparisonViewController 표시
```

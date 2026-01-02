# Data Model: 유사 사진 정리 기능

**Date**: 2026-01-02
**Branch**: `002-similar-photo`

---

## Entity Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                       SimilarityCache                             │
│  ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐   │
│  │ AnalysisState   │  │ SimilarGroup    │  │ CachedFace      │   │
│  │ (per asset)     │──│ (thumbnailGroup)│──│ (per face)      │   │
│  └─────────────────┘  └─────────────────┘  └─────────────────┘   │
└──────────────────────────────────────────────────────────────────┘
                                │
                                ▼
                    ┌─────────────────────┐
                    │ ComparisonGroup     │
                    │ (max 8 photos)      │
                    └─────────────────────┘
```

---

## 1. SimilarityAnalysisState

사진별 분석 상태를 추적하는 열거형

### Definition

```swift
enum SimilarityAnalysisState {
    case notAnalyzed                              // 분석 범위 밖
    case analyzing                                // 분석 진행 중
    case analyzed(inGroup: Bool, groupID: String?) // 분석 완료
}
```

### State Transitions

```
notAnalyzed ──[그리드 스크롤 멈춤]──▶ analyzing ──[완료]──▶ analyzed
     ▲                                                          │
     └───────────[캐시 eviction]────────────────────────────────┘
```

### Validation Rules
- `analyzed(inGroup: true)` 상태에서는 `groupID`가 non-nil
- `analyzed(inGroup: false)` 상태에서는 `groupID`가 nil
- 동시에 하나의 상태만 가능

---

## 2. CachedFace

얼굴 감지 결과를 캐시하는 구조체

### Definition

```swift
struct CachedFace {
    let boundingBox: CGRect   // Vision 정규화 좌표 (0~1, 원점 좌하단)
    let personIndex: Int      // 위치 기반 인물 번호 (1, 2, 3...)
    let isValidSlot: Bool     // 유효 인물 슬롯 여부 (그룹 내 2장 이상)
}
```

### Field Descriptions

| 필드 | 타입 | 설명 | 제약 |
|------|------|------|------|
| boundingBox | CGRect | Vision에서 반환한 정규화 좌표 | 0.0~1.0, 원점 좌하단 |
| personIndex | Int | 위치 기반 인물 번호 | >= 1 |
| isValidSlot | Bool | 그룹 내 2장 이상 감지된 슬롯 여부 | - |

### Validation Rules
- `personIndex >= 1` (0 사용 안함)
- `boundingBox` 값은 0.0~1.0 범위
- 화면 너비 5% 이상 얼굴만 저장

---

## 3. SimilarThumbnailGroup

그리드 테두리 및 뷰어 +버튼 표시를 위한 유사 사진 그룹

### Definition

```swift
struct SimilarThumbnailGroup {
    let groupID: String
    var memberAssetIDs: [String]
    var validPersonIndices: Set<Int>
}
```

### Field Descriptions

| 필드 | 타입 | 설명 | 제약 |
|------|------|------|------|
| groupID | String | 고유 그룹 식별자 | UUID |
| memberAssetIDs | [String] | 그룹 소속 사진 ID 목록 | >= 3개 |
| validPersonIndices | Set<Int> | 유효 인물 슬롯 번호 집합 | >= 1개 |

### Validation Rules
- `memberAssetIDs.count >= 3` (3장 미만 시 그룹 무효화)
- `validPersonIndices.count >= 1` (유효 슬롯 없으면 그룹 무효화)
- 그룹 내 모든 멤버는 동일한 `groupID` 참조

### Lifecycle
- **생성**: 그리드 스크롤 멈춤 시 분석 완료 후
- **갱신**: 멤버 삭제, 캐시 eviction 시 재계산
- **무효화**: 멤버 3장 미만 또는 유효 슬롯 없음

---

## 4. ComparisonGroup

얼굴 비교 화면에서 비교할 사진 집합

### Definition

```swift
struct ComparisonGroup {
    let sourceGroupID: String
    let selectedAssetIDs: [String]  // 최대 8장
    let personIndex: Int            // 비교 대상 인물 번호
}
```

### Field Descriptions

| 필드 | 타입 | 설명 | 제약 |
|------|------|------|------|
| sourceGroupID | String | 원본 ThumbnailGroup ID | - |
| selectedAssetIDs | [String] | 비교 대상 사진 ID 목록 | <= 8개 |
| personIndex | Int | 비교 대상 인물 번호 | >= 1 |

### Selection Algorithm
```
1. ThumbnailGroup에서 현재 사진 인덱스 확인
2. 거리순 선택 (동일 거리면 앞쪽 우선)
3. 최대 8장까지 선택
4. 원래 순서로 재정렬 (시간순 유지)
```

### Validation Rules
- `selectedAssetIDs.count <= 8`
- 선택된 사진은 반드시 `sourceGroupID`의 멤버

---

## 5. SimilarityCache

분석 결과를 관리하는 캐시 클래스

### Definition

```swift
class SimilarityCache {
    // 사진별 상태
    private var states: [String: SimilarityAnalysisState]

    // 그룹 관리
    private var groups: [String: SimilarThumbnailGroup]

    // 사진별 얼굴 캐시
    private var assetFaces: [String: [CachedFace]]

    // LRU 추적
    private var accessOrder: [String]

    // 분석 완료 콜백
    private var completionHandlers: [String: [(SimilarityAnalysisState) -> Void]]
}
```

### Capacity Constraints
- **최대 캐시 크기**: 500장
- **Eviction 정책**: LRU (Least Recently Used)

### Key Operations

| 연산 | 설명 | 복잡도 |
|------|------|--------|
| getState(assetID:) | 사진 분석 상태 조회 | O(1) |
| setState(_:for:) | 사진 분석 상태 설정 | O(1) |
| getFaces(for:) | 사진별 CachedFace 조회 | O(1) |
| getValidSlotFaces(for:) | 유효 슬롯 얼굴만 조회 | O(n) |
| evictIfNeeded() | LRU eviction 수행 | O(n) |
| invalidateGroup(groupID:) | 그룹 전체 무효화 | O(m) |

---

## 6. AnalysisRequest

분석 요청을 추적하는 구조체

### Definition

```swift
struct AnalysisRequest {
    let assetID: String
    let source: AnalysisSource
    let range: ClosedRange<Int>  // 분석 범위 인덱스
}

enum AnalysisSource {
    case grid    // 그리드 스크롤 멈춤
    case viewer  // 뷰어에서 notAnalyzed 사진 접근
}
```

### Cancellation Rules
- `source == .grid`: 스크롤 재개 시 취소 가능
- `source == .viewer`: 취소 불가 (사용자가 명시적으로 보고 있음)

---

## 7. FaceMatch

인물 매칭 검증 결과

### Definition

```swift
struct FaceMatch {
    let assetID: String
    let personIndex: Int
    let distance: Float
    let confidence: MatchConfidence
}

enum MatchConfidence {
    case high    // 거리 < 0.6
    case medium  // 0.6 <= 거리 < 1.0
    case low     // 거리 >= 1.0 (경고 표시)
}
```

### UI Behavior by Confidence
| 신뢰도 | 거리 범위 | UI 표시 |
|--------|----------|---------|
| high | < 0.6 | 정상 표시 |
| medium | 0.6 ~ 1.0 | 정상 표시 |
| low | >= 1.0 | 경고 배지 표시 |

---

## Entity Relationships

```
PHAsset (1) ─────────────────── (0..1) SimilarityAnalysisState
    │
    ├── (0..n) CachedFace
    │
    └── (0..1) SimilarThumbnailGroup (via groupID)
                    │
                    └── (0..1) ComparisonGroup (max 8 from group)
                              │
                              └── (0..n) FaceMatch (per person)
```

---

## Data Flow

```
1. 그리드 스크롤 멈춤
   └─▶ 분석 범위 결정 (화면 ±7장)
       └─▶ FeaturePrint 생성
           └─▶ 유사도 비교 (거리 10.0 기준)
               └─▶ 얼굴 감지 + 5% 필터
                   └─▶ CachedFace 저장
                       └─▶ ThumbnailGroup 생성
                           └─▶ 테두리 표시

2. 뷰어 진입 (캐시 hit)
   └─▶ CachedFace 조회
       └─▶ isValidSlot 필터
           └─▶ +버튼 표시

3. +버튼 탭
   └─▶ ComparisonGroup 생성 (거리순 8장)
       └─▶ 얼굴 비교 화면 표시
           └─▶ 백그라운드 검증 (FaceMatch)
               └─▶ 경고 표시 (low confidence)

4. 삭제
   └─▶ TrashStore 이동
       └─▶ 그룹 멤버 감소
           └─▶ 3장 미만 시 그룹 무효화
```

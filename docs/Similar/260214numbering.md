# 유사사진 — 사진 번호 표기

> 뷰어와 얼굴 그리드에 동일한 사진 번호를 표시하여, 사진-얼굴 매칭 엇갈림을 시각적으로 확인할 수 있게 한다.

## 배경

- 뷰어에서 보는 사진과 얼굴 비교 그리드의 얼굴 크롭이 엇갈리는 경우 발생
- 현재 어떤 사진의 얼굴인지 확인할 시각적 수단이 없음
- 양쪽에 동일한 번호를 표기하면 즉시 매칭 여부 확인 가능

## 넘버링 기준

**SimilarThumbnailGroup.memberAssetIDs** 배열 순서 기반 (1-based)

- 유사 그룹 원본 순서를 기준으로 번호 부여
- 뷰어와 그리드 모두 같은 기준 → 같은 사진은 항상 같은 번호
- ComparisonGroup이 일부만 선택해도(최대 8장), 원본 순서 번호 유지

### 예시

```
SimilarThumbnailGroup.memberAssetIDs = [A, B, C, D, E]  (5장)
→ A=1, B=2, C=3, D=4, E=5

ComparisonGroup.selectedAssetIDs = [A, C, D]  (거리순 3장 선택)
→ 그리드에 표시되는 번호: "1", "3", "4" (원본 순서 유지)
```

## UI 명세

### 뷰어 (ViewerViewController)

| 항목 | 내용 |
|------|------|
| 위치 | 좌측 상단, **뒤로가기 버튼 아래** (leading: 16, top: safeArea + 68) |
| 형태 | 반투명 검정 배경 배지 (cornerRadius: 4) |
| 폰트 | .systemFont(ofSize: 14, weight: .bold), 흰색 |
| 내용 | `3 / 8` (그룹 내 순서 / 총 멤버 수) |
| 표시 조건 | +버튼이 보일 때만 함께 표시 |
| 숨김 조건 | 아래 상태별 동작 표 참조 |

#### FaceButtonOverlay 상태별 photoNumberLabel 동작

| 메서드 | 라벨 동작 | 설명 |
|--------|----------|------|
| `showButtons()` | 표시 | +버튼과 함께 페이드인 |
| `hideButtons()` | 숨김 | +버튼과 함께 페이드아웃 |
| `hideButtonsImmediately()` | 숨김 | 줌 시작 — 즉시 숨김 |
| `showButtonsWithZoom()` | 표시 | 줌 완료 — 버튼과 함께 표시 |
| `resetState()` | 숨김 + 초기화 | 다른 사진으로 스와이프 시 |
| `clearButtonsOnly()` | **유지** | 얼굴 그리드에서 복귀 시 |
| `toggleButtonTapped()` | 토글 | eye 버튼과 연동 |

### 얼굴 그리드 (FaceComparisonViewController)

| 항목 | 내용 |
|------|------|
| 위치 | 각 셀 좌측 상단 (기존 debugLabel 자리) |
| 형태 | 기존 debugLabel 스타일 유지 |
| 내용 | `3` (뷰어의 번호와 동일) |
| 기존 표기 | "a1" 형식 (인물별 넘버링) → 사진 번호로 대체 |

## 수정 파일

| # | 파일 | 수정 내용 |
|---|------|----------|
| 1 | `SimilarityCache.swift` | SimilarityCacheProtocol에 `getGroupMembers(groupID:)` 추가 |
| 2 | `FaceButtonOverlay.swift` | photoNumberLabel 추가, showPhotoNumber/hidePhotoNumber, 각 상태 메서드에 라벨 처리 |
| 3 | `ViewerViewController+SimilarPhoto.swift` | showFaceButtons 내에서 그룹 조회 → 번호 전달 |
| 4 | `FaceComparisonViewController.swift` | memberAssetIDs 순서 맵 캐싱, photoNumber(for:) 구현 |
| 5 | `PersonPageViewController.swift` | debugText 로직: "a1" → 사진 번호 기반으로 변경 |

## 데이터 흐름

```
[뷰어]
showFaceButtons(for: assetID)
  → SimilarityCache.getState(assetID) → groupID 획득
  → SimilarityCache.getGroup(groupID) → SimilarThumbnailGroup
  → memberAssetIDs.firstIndex(of: assetID) + 1 = photoNumber
  → faceButtonOverlay.showPhotoNumber(photoNumber, total: memberCount)

[얼굴 그리드]
FaceComparisonViewController.viewDidLoad
  → cache.getGroupMembers(sourceGroupID) → memberAssetIDs
  → memberNumberMap 구축: [assetID: 1-based index]

PersonPageViewController.cellForItemAt
  → dataSource.photoNumber(for: assetID) → memberNumberMap에서 조회
  → cell.configure(debugText: "\(photoNumber)")
```

## 검토에서 발견한 주의사항

### 1. SimilarityCacheProtocol 확장 필요
FaceComparisonViewController는 `cache: any SimilarityCacheProtocol`을 사용.
프로토콜에 `getGroupMembers(groupID:) -> [String]`이 없어서 호출 불가.
→ **프로토콜에 메서드 추가** 필요 (SimilarityCache.swift에 이미 구현체 존재).

### 2. 뷰어 좌측 상단 — 뒤로가기 버튼과 충돌
iOS 16~25 뷰어 레이아웃:
- 좌측 상단: 뒤로가기 버튼 (safeArea top+16, leading+16)
- 우측 상단: eye 토글 버튼 (safeArea top+16, trailing-16)

photoNumberLabel을 "좌측 상단"에 넣으면 뒤로가기 버튼과 겹침.
→ **뒤로가기 버튼 아래** (safeArea top + 68)에 배치.

### 3. ComparisonGroup은 부분집합
그룹이 10장인데 ComparisonGroup은 거리순 최대 8장만 선택.
→ 그리드에 일부 번호가 빠질 수 있음 (예: 1,2,3,5,6,7,8,9).
→ 뷰어에서 보던 사진은 **항상 ComparisonGroup에 포함** (거리 0)이므로 실사용에 문제 없음.

## 검증

1. 뷰어에서 유사 그룹 사진을 넘기며 번호 변경 확인
2. +버튼 탭 → 얼굴 그리드 진입 → 각 셀의 번호가 뷰어 번호와 일치하는지 확인
3. 인물 페이지 전환 시 동일 사진은 동일 번호 유지 확인
4. 토글(eye) OFF/ON 시 번호도 함께 숨김/표시 확인
5. 줌 → 줌 완료 시 번호 재표시 확인
6. 뒤로가기 버튼과 번호 라벨이 겹치지 않는지 확인

# 삭제대기함 스와이프 복구 기능 제거 계획

> 작성일: 2026-04-10
> 목적: 삭제대기함에서 셀을 스와이프하여 녹색으로 복구하는 기능 완전 제거

---

## 영향 파일 (4개)

| 파일 | 역할 |
|------|------|
| `TrashAlbumViewController.swift` | 복구 플래그 및 애니메이션 처리 |
| `BaseGridViewController.swift` | 스와이프 restore 분기 (공통) |
| `BaseMultiSwipeDelete.swift` | 다중 셀 스와이프 restore 분기 |
| `PhotoCell.swift` | 녹색 오버레이 UI 코드 |

---

## Phase 1: TrashAlbumViewController.swift (핵심 비활성화)

| 라인 | 변경 | 상세 |
|------|------|------|
| 50-52 | **삭제** | `pendingDeleteIndexPaths` 프로퍼티 선언 |
| 119-120 | **삭제** | `override var supportsSwipeDelete: Bool { true }` |
| 122-123 | **삭제** | `override var swipeActionIsRestore: Bool { true }` |
| 152-156 | **삭제** | `override func updateSwipeDeleteGestureEnabled()` (스와이프 없으면 불필요) |
| 158-161 | **삭제** | `override func prepareSwipeRestoreAnimation(at:)` |
| 405-428 | **삭제** | `onDataLoaded()`의 `pendingDeleteIndexPaths` 분기 전체 (else의 `reloadData()`만 남김) |

## Phase 2: BaseGridViewController.swift (restore 분기 제거)

| 라인 | 변경 | 상세 |
|------|------|------|
| 179-181 | **삭제** | `var swipeActionIsRestore: Bool { false }` 프로퍼티 |
| 695-697 | **삭제** | `func prepareSwipeRestoreAnimation(at:)` 빈 메서드 |
| 757-762 | **축소** | `cellForItemAt`의 `if swipeActionIsRestore` 분기 제거 |
| 936-939 | **축소** | `handleSwipeDeleteBegan`의 `if swipeActionIsRestore` 분기 제거 |
| 1128-1134 | **축소** | `confirmSwipeDelete`의 `if self.swipeActionIsRestore` 분기 전체 제거 |

## Phase 3: BaseMultiSwipeDelete.swift (restore 분기 제거)

| 라인 | 변경 | 상세 |
|------|------|------|
| 56-58 | **삭제** | `enterMultiSwipeMode`의 `if swipeActionIsRestore` |
| 183 | **삭제** | `handleMultiSwipeChanged`의 `if swipeActionIsRestore` (이전 커튼 셀) |
| 197 | **삭제** | 같은 함수 내 새 셀 추가 분기 |
| 241 | **삭제** | 같은 함수 내 커튼 조건 분기 |
| 295, 301 | **삭제** | reconciliation 루프의 `if swipeActionIsRestore` |
| 366-368 | **축소** | `confirmMultiSwipeDelete`의 `alreadyInTargetState` restore 분기 |
| 391-395 | **축소** | `confirmMultiSwipeDelete`의 `if swipeActionIsRestore` 분기 |
| 405 | **축소** | analytics의 `if swipeActionIsRestore` 분기 |

## Phase 4: PhotoCell.swift (restore UI 코드 제거)

| 라인 | 변경 | 상세 |
|------|------|------|
| 31-32 | **삭제** | `restoreOverlayColor` 상수 |
| 325-329 | **삭제** | `SwipeOverlayStyle` enum 전체 (`.delete`만 남으므로 불필요) |
| 332 | **삭제** | `swipeOverlayStyle` 프로퍼티 |
| 360-365 | **삭제** | `prepareSwipeOverlay` 함수 (호출처 모두 제거됨) |
| 414 | **삭제** | `prepareForReuse`의 `swipeOverlayStyle = .delete` |
| 961 | **단순화** | `confirmDimmedAnimation`의 `swipeOverlayStyle == .restore` 분기 → 직접 `!toTrashed` |
| 965-967 | **단순화** | 같은 함수 내 리셋 분기 → 무조건 리셋 |
| 1027 | **삭제** | `cancelDimmedAnimation`의 `swipeOverlayStyle = .delete` |

---

## 영향 정리

| 항목 | 결과 |
|------|------|
| 삭제대기함 스와이프 복구 | **완전 제거** |
| 보관함/앨범 스와이프 삭제 | **영향 없음** (삭제 로직 유지) |
| 선택 모드 복구 버튼 | **영향 없음** (TrashSelectMode는 별도) |
| `SwipeOverlayStyle` enum | enum 자체 제거, `prepareSwipeOverlay` 함수도 제거 |

## 수정 순서

1. Phase 1 → 2 → 3 → 4 순서 (의존성 순)
2. 각 Phase 완료 후 빌드 확인
3. 총 수정 파일: **4개**, 예상 삭제 라인: **약 60~80줄**

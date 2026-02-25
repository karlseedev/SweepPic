# 코치마크 다시 보기 구현 계획

## Context

온보딩 기획안 7번 "코치마크 다시 보기" 구현. 전체메뉴에 "설명 다시 보기" 항목을 추가하고, 목록에서 선택하면 해당 코치마크를 즉시 재생한다.

---

## 목록 항목 (6개)

| # | 표시 텍스트 | 코치마크 |
|---|-----------|---------|
| 1 | 그리드 스와이프 삭제 | A |
| 2 | 뷰어 스와이프 삭제 | B |
| 3 | 유사 사진 얼굴 비교 | C (C-1→C-2→C-3 전체 시퀀스) |
| 4 | 저품질 사진 정리 | D |
| 5 | 삭제 시스템 안내 | E-1+E-2 |
| 6 | 비우기 완료 안내 | E-3 |

---

## 각 코치마크별 즉시 재생

### A: 그리드 스와이프 삭제

```
[재생 흐름]
1. 플래그 리셋
2. showGridSwipeDeleteCoachMark() 호출 (접근 수준 private → func)

[동작] (기존 코드 그대로)
  findCenterCell() → 중앙 셀 찾기 → 스냅샷 캡처
  → 딤 + 셀 하이라이트 + 손가락 좌우 스와이프 애니메이션
  + "사진을 밀어서 바로 정리하세요" + [확인] → dismiss

[실패] 사진 0장 → 토스트
```

### B: 뷰어 스와이프 삭제

```
[재생 흐름]
1. 플래그 리셋
2. 보이는 셀 중 중앙에서 가까운 순서로 이미지(비디오 제외) 셀 탐색
3. 해당 셀의 indexPath로 뷰어 push
4. viewDidAppear에서 자동 트리거 (플래그 리셋 상태이므로 가드 통과)

[동작]
  뷰어로 이동 → 0.5초 후 검정 배경 + 사진 스냅샷
  + 손가락 위로 스와이프 애니메이션 (3회)
  + blur 카드 "위로 밀면 삭제대기함으로" + [확인] → dismiss

[실패] 보이는 셀에 이미지 없음 → 토스트
```

### C: 유사 사진 얼굴 비교 (C-1→C-2→C-3 시퀀스)

```
[재생 흐름]
1. 플래그 리셋 + hasTriggeredC1 = false
2. SimilarityCache에서 분석 완료된 그룹 멤버 탐색
3-a. 캐시에 그룹 있음:
   → assetID → indexPath → 셀로 스크롤
   → 뱃지 표시 → C-1 자동 트리거
   → C-1→C-2→C-3 전체 시퀀스 이어짐
3-b. 캐시에 없음:
   → 로딩 UI 표시: 화면 중앙 인디케이터 + "기능이 실행되는\n사진을 찾고 있어요"
   → 보관함 최신 사진부터 유사 그룹 자동 탐색
   → 그룹 발견 시 → 로딩 dismiss → 해당 셀로 스크롤 → C-1 트리거
   → 끝까지 못 찾으면 → "유사 사진을 찾지 못했습니다" 토스트

[동작] (그룹 발견 시)
  C-1: 딤 + 뱃지 셀 하이라이트 + 안내 텍스트 + [확인]
  → 탭 모션 → 뷰어 이동
  → C-2: + 버튼 하이라이트 + [확인]
  → 탭 모션 → 얼굴 비교 진입
  → C-3: 셀 선택 안내 + Pic 라벨 안내
```

### D: 저품질 사진 정리

```
[재생 흐름]
1. 플래그 리셋
2. getCleanupButtonFrame() → 정리 버튼 프레임 (접근 수준 private → func)
3. CoachMarkOverlayView.showAutoCleanup(
       highlightFrame: buttonFrame,
       scanResult: nil,        ← 항상 nil (썸네일 없이 텍스트만)
       in: window,
       onConfirm: {}           ← 빈 클로저 (dismiss만)
   )

[동작]
  포커싱 모션 → 정리 버튼 하이라이트
  + 카드 (썸네일 없이 텍스트만) + [확인]
  → 탭 모션 → dismiss (정리 시트 없음)
```

### E-1+E-2: 삭제 시스템 안내 (A 변형 → 실제 삭제 → E 시퀀스)

```
[재생 흐름]
1. 플래그 리셋
2. findCenterCell() → 중앙 셀 (A와 동일)
3. A 변형 오버레이 표시:
   - 딤 + 셀 하이라이트 + 스와이프 모션 (삭제 1회만, 복원 없음)
   - 텍스트: "설명을 위해 사진을 임시로 삭제합니다
            (삭제대기함에서 복구 가능)"
   - [확인] 버튼 없음
4. 모션 완료 → 해당 사진을 실제로 삭제대기함으로 이동
5. → E-1+E-2 시퀀스 자동 시작 (기존 showDeleteSystemGuide 흐름)

[동작]
  A 변형: 셀 하이라이트 + 스와이프 1회 + 안내 텍스트 (확인 없음)
  → 자동 삭제
  → E-1: 카드 "삭제대기함으로 이동됐어요" + [확인]
  → 포커스 원 → 손가락 탭 → 삭제대기함 탭 전환
  → E-2: Step 2/3 순차 → [확인] → dismiss

[실패] 사진 0장 → 토스트
```

### E-3: 비우기 완료 안내

```
[재생 흐름]
1. 플래그 리셋
2. CoachMarkOverlayView.showFirstEmptyFeedback(in: window)

[동작]
  딤 + 중앙 blur 카드:
  "✓ 삭제 완료"
  "애플 사진앱의 '최근 삭제된 항목'에서
   30일 후 완전히 삭제됩니다."
  + [확인] → dismiss
```

---

## 수정 대상 파일

| 파일 | 변경 내용 |
|------|----------|
| `CoachMarkOverlayView.swift:51-56` | `resetShown()` `#if DEBUG` 제거 |
| `GridViewController+Cleanup.swift:58,96` | UIMenu에 "설명 다시 보기" 항목 추가 |
| `GridViewController+CoachMark.swift:113` | `showGridSwipeDeleteCoachMark()` `private` → `func` |
| `GridViewController+CoachMarkC.swift:174` | `showSimilarBadgeCoachMark(cell:assetID:)` `private` → `func` |
| `GridViewController+CoachMarkD.swift:191` | `getCleanupButtonFrame(in:)` `private` → `func` |
| `SimilarityCache.swift` | `findAnyGroupMember()` 메서드 추가 |
| **신규** `GridViewController+CoachMarkReplay.swift` | 목록 표시 + A~E-3 즉시 재생 로직 |

### SimilarityCache 추가 메서드

```swift
func findAnyGroupMember() -> (assetID: String, groupID: String)? {
    for (assetID, state) in states {
        if case .analyzed(true, let groupID?) = state {
            return (assetID, groupID)
        }
    }
    return nil
}
```

---

## 검증

1. 빌드 확인
2. 전체메뉴 → "설명 다시 보기" → 액션시트 6개 항목
3. A: 그리드 중앙 셀 스와이프 애니메이션
4. B: 뷰어 이동 + 위로 스와이프 애니메이션
5. C: 그룹 탐색 (캐시 or 자동 탐색) → C-1→C-2→C-3 시퀀스
6. D: 정리 버튼 포커싱 + 텍스트 카드, dismiss만
7. E-1+E-2: A 변형 스와이프 → 실제 삭제 → E 풀 시퀀스
8. E-3: 팝업 카드 그대로 표시

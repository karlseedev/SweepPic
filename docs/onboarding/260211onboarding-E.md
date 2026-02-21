# 삭제 시스템 안내 (E-1, E-2, E-3) 구현 계획 v2

## 목표

사용자가 삭제 행동을 수행한 직후, PickPhoto의 2단계 삭제 구조(삭제대기함 → 비우기)를 점진적으로 이해시킨다. 코치마크(A~D)와 달리 기능 안내가 아닌 **행동 결과 피드백**이므로, 사용자 행동 직후에 표시되어 맥락이 명확하다.

> 이전 버전: `260211onboarding-E-bak.md`

---

## Context

온보딩 기획(`docs/onboarding/260211onboarding.md`) 섹션 6. 기존 코치마크(A~D)의 공용 구조(`CoachMarkOverlayView`, `CoachMarkManager`, `CoachMarkType`)를 확장하여 구현한다.

### 코치마크(A~D)와의 핵심 차이

| | 코치마크 (A~D) | 시스템 피드백 (E-1~3) |
|---|---|---|
| 목적 | 기능/제스처 안내 | 삭제 시스템 구조 이해 |
| 트리거 | 화면 진입/스크롤 | **사용자 행동 직후** |
| 레이아웃 | 딤 + 하이라이트 구멍 + 스냅샷 | **딤 + 아이콘 애니메이션 + 카드 팝업** |

---

## 파일 구조

### 신규 생성 (2개)

| 파일 | 역할 |
|------|------|
| `Shared/Components/CoachMarkOverlayView+E1E2.swift` | E-1+E-2: 삭제 시스템 안내 시퀀스 전체 |
| `Shared/Components/CoachMarkOverlayView+E3.swift` | E-3: 첫 비우기 완료 안내 (단독 카드) |

E-1+E-2와 E-3는 절대 동시에 존재하지 않는 독립 오버레이이므로 각각 **완전히 자급자족**하는 파일로 분리한다. 공용 파일 없음.

### 삭제 (1개)

| 파일 | 사유 |
|------|------|
| `CoachMarkOverlayView+SystemFeedback.swift` | 위 2개 파일로 분배 완료 |

### 수정 (3개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `dismiss()`에서 cleanup 호출 변경 |
| `BaseGridViewController.swift` | `showDeleteSystemGuideIfNeeded(cell:)` 파라미터 추가 |
| `PhotoCell.swift` | `trashIconFrameInWindow()` public 메서드 추가 |

---

## E-1 → E-2: 삭제 시스템 안내 (연속 시퀀스)

E-1과 E-2는 **하나의 연속 시퀀스**로 실행된다. 단일 오버레이가 시작부터 끝까지 유지되며, 모든 입력을 차단한다.

### 트리거

```
사용자의 생애 첫 moveToTrash() 호출 완료 직후
  → guard: !CoachMarkType.firstDeleteGuide.hasBeenShown
  → guard: !CoachMarkManager.shared.isShowing
  → guard: !UIAccessibility.isVoiceOverRunning
  → guard: view.window != nil
  → showDeleteSystemGuide(in: window, iconFrame: cell?.trashIconFrameInWindow())
```

### 트리거 삽입 위치

| 호출 지점 | 파일 | cell 전달 |
|-----------|------|-----------|
| 그리드 스와이프 삭제 | `BaseGridViewController.swift:916` | `cell: cell` (아이콘 애니메이션 O) |
| 뷰어 삭제 (delegate) | `GridViewController.swift:934` | `cell: nil` (아이콘 생략, 바로 카드) |

### 전체 시퀀스

```
[Step 1] 딤 페이드인 → 아이콘 이동 → 카드 팝업

  1. 딤 배경 페이드인 (0.3s, 구멍 없음)
  2. 삭제된 셀의 trashIcon 위치에 xmark.bin 아이콘 생성 (25×25)
  3. 아이콘이 커지면서 화면 중앙으로 이동 (~0.6s, spring)
  4. 아이콘 아래에 카드 팝업:
     "방금 삭제된 사진은
      삭제대기함으로 이동됐어요
      삭제대기함으로 가볼게요"
              [확인]

       ── [확인] 탭 ──

  5. 카드+아이콘 페이드아웃 (0.2s)
  6. 포커스 원 축소 애니메이션 (0.9s)
     — 화면 밖 큰 원 → 삭제대기함 탭 크기 (60%)
     — 흰색 테두리 (2pt) 동기화
  7. 손가락 탭 모션 (삭제대기함 탭 위)
  8. 탭 전환 (selectedIndex = 2)
     iOS 16~25: 뷰어 모달 dismiss(animated: false) 후 전환

[Step 2] (+0.3s) 카드 팝업
  "보관함에서 삭제하면 여기에 임시 보관돼요."

[Step 3] (+2.3s) 카드 확장 + 비우기 하이라이트
  비우기 버튼 딤 구멍 (원형)
  "[비우기]를 누르면 사진이 최종 삭제돼요."
              [확인]

       ── [확인] 탭 ──

  오버레이 dismiss
```

### 레이아웃

```
[Step 1: 아이콘 + 카드]              [Step 2~3: 카드 + 비우기 하이라이트]
┌──────────────────────────┐         ┌──────────────────────────┐
│      딤 (black 70%)      │         │      딤 (black 70%)      │
│                          │         │  ┌────────────────────┐  │
│         🗑️ (48pt)        │         │  │ 비우기 (하이라이트) │  │ ← 딤 구멍 (원형)
│                          │         │  └────────────────────┘  │
│   ┌────────────────────┐ │         │                          │
│   │  방금 삭제된 사진은  │ │         │   ┌────────────────────┐ │
│   │  삭제대기함으로      │ │         │   │  보관함에서 삭제하면 │ │
│   │  이동됐어요          │ │         │   │  여기에 임시 보관돼요│ │ ← Step 2
│   │  삭제대기함으로      │ │         │   │                    │ │
│   │  가볼게요            │ │         │   │  [비우기]를 누르면   │ │
│   │                      │ │         │   │  사진이 최종 삭제돼요│ │ ← Step 3
│   │      [확인]          │ │         │   │                    │ │
│   └────────────────────┘ │         │   │      [확인]         │ │
│                          │         │   └────────────────────┘ │
└──────────────────────────┘         └──────────────────────────┘
```

### 카드 스타일 (E-1+E-2 공통)

| 항목 | 값 |
|------|-----|
| 카드 배경 | `UIColor(white: 0.15, alpha: 1.0)` (어두운 회색, 100% 불투명) |
| 카드 cornerRadius | 20pt |
| 카드 width | 화면 너비 - 48pt (좌우 24pt 마진) |
| 내부 패딩 | 상하 24pt, 좌우 20pt |
| 텍스트 font | 17pt medium, white |
| [확인] 버튼 | 120×44pt, white bg, black text, cornerRadius 22 |
| 딤 배경 | black 70% |

### 아이콘 이동 애니메이션

| 항목 | 값 |
|------|-----|
| SF Symbol | `xmark.bin` (PhotoCell과 동일) |
| 시작 크기 | 25×25 pt (셀 아이콘과 동일) |
| 시작 위치 | 삭제된 셀의 trashIconView window 좌표 |
| 최종 크기 | ~48pt (카드 위 중앙) |
| 최종 위치 | 화면 centerX, 카드 위쪽 |
| 애니메이션 | ~0.6s, spring |
| 색상 | white |

### 포커스 원 축소 애니메이션

| 항목 | 값 |
|------|-----|
| 시작 | 화면 밖 (3배 크기) |
| 최종 | 삭제대기함 탭의 60% 크기 |
| 시간 | 0.9s, easeInEaseOut |
| 테두리 | 흰색, 2pt |
| 방식 | CABasicAnimation (dimLayer.path + borderLayer.path 동기화) |

### 뷰어에서 삭제 시

`iconFrame: nil` → 아이콘 이동 애니메이션 생략, 화면 중앙에 바로 카드 팝업 표시. 이후 흐름(포커스 원, 손가락 모션, 탭 전환)은 동일.

---

## E-3: 첫 비우기 완료 안내

### 트리거

```
performEmptyTrash() 첫 성공 완료 직후
  → guard: !CoachMarkType.firstEmpty.hasBeenShown
  → guard: !CoachMarkManager.shared.isShowing
  → guard: !UIAccessibility.isVoiceOverRunning
  → guard: view.window != nil
  → showFirstEmptyFeedback(in: window)
```

### 레이아웃 (중앙 카드)

```
┌──────────────────────────────────┐
│        딤 배경 (black 70%)       │
│                                  │
│   ┌────────────────────────┐     │
│   │                        │     │
│   │  ✓ 삭제 완료           │     │  ← 타이틀 (17pt semibold)
│   │                        │     │
│   │  애플 사진앱의          │     │  ← 본문 (15pt regular)
│   │  '최근 삭제된 항목'에서 │     │
│   │  30일 후 완전히         │     │
│   │  삭제됩니다.            │     │
│   │                        │     │
│   │       [확인]            │     │
│   │                        │     │
│   └────────────────────────┘     │
│                                  │
└──────────────────────────────────┘
```

### 카드 스타일

E-1+E-2와 동일 (`UIColor(white: 0.15, alpha: 1.0)`, cornerRadius 20, 등)

### [확인] 액션

dismiss만. markAsShown 자동.

---

## CoachMarkType

```swift
case firstDeleteGuide = "coachMark_firstDeleteGuide"  // E-1+E-2 통합
case firstEmpty = "coachMark_firstEmpty"               // E-3
```

`markAsShown()`은 최종 dismiss 시 1회만 호출.

---

## 공통 사항

### VoiceOver 대응
1차 구현: VoiceOver 가드 유지 (A~D와 동일). 접근성 대응은 후속 작업.

### dismiss 보호
E-1+E-2 시퀀스 진행 중 `isDeleteGuideSequenceActive = true` → `CoachMarkManager.dismissCurrent()` 차단.

### UserDefaults 키

| 키 | 용도 |
|----|------|
| `coachMark_firstDeleteGuide` | E-1+E-2 통합 시퀀스 완료 |
| `coachMark_firstEmpty` | E-3 표시 완료 |

---

## 검증

### E-1+E-2

1. 그리드 스와이프 삭제 → 딤 → 아이콘 이동 → 카드 → [확인] → 포커스 원 → 손가락 → 탭 전환 → Step 2/3
2. 뷰어 삭제 → 아이콘 없이 바로 카드 → 이후 동일
3. Step 2/3 카드 확장 + 비우기 하이라이트 정상 동작
4. Step 3 [확인] → dismiss
5. 두 번째 삭제 → 시퀀스 안 뜸 (1회성)
6. 시퀀스 중 모든 터치 차단 ([확인]만 가능)

### E-3

7. 첫 비우기 완료 → 중앙 카드 표시
8. [확인] → dismiss
9. 두 번째 비우기 → 안 뜸

### 공통

10. VoiceOver 활성 → 모두 안 뜸
11. 빌드 성공

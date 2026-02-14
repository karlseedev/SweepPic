# 코치마크 A — 그리드 스와이프 삭제 안내 구현 계획

## 목표

사용자가 그리드에 처음 진입했을 때, 스와이프로 사진을 정리할 수 있다는 것을 자연스러운 제스처 시연 애니메이션으로 안내한다. 텍스트 설명이 아니라 실제 UI 반응(Maroon 딤드 채워짐)을 보여주어, 사용자가 직관적으로 조작법을 이해하도록 한다.

---

## Context

온보딩 기획(`docs/260211onboarding.md`)의 첫 번째 코치마크를 구현한다. 사용자가 그리드에서 약 1화면 높이 이상 스크롤하면 스크롤을 부드럽게 멈추고 코치마크를 표시한다. 향후 B/C/D 코치마크 확장을 고려해 공용 구조로 설계한다.

---

## 파일 구조

### 신규 생성 (2개)

| 파일 | 역할 |
|------|------|
| `PickPhoto/PickPhoto/Shared/Components/CoachMarkOverlayView.swift` | 코치마크 오버레이 뷰 + CoachMarkManager 싱글톤 + CoachMarkType enum |
| `PickPhoto/PickPhoto/Features/Grid/GridViewController+CoachMark.swift` | 코치마크 A 트리거 (스크롤 추적/threshold/표시) |

### 수정 (3개)

| 파일 | 수정 내용 |
|------|-----------|
| `BaseGridViewController.swift` | `handleSwipeDeleteBegan` 첫 줄에 `CoachMarkManager.shared.dismissCurrent()` 추가 |
| `GridScroll.swift` | `stopScrollForCoachMark()` 메서드 추가, `scrollDidBegin`에서 `dismissCurrent()` 호출 |
| `GridViewController.swift` | `scrollViewWillBeginDragging`에서 `recordCoachMarkScrollStart` 호출, `scrollViewDidScroll`에서 `trackCoachMarkScroll` 호출, `viewWillDisappear`에서 `dismissCurrent()` 호출 |

---

## 트리거 설계

### 스크롤 기반 트리거 (구현 완료)

초기 계획은 `finishInitialDisplay` 후 2초 딜레이였으나, **사용자가 충분히 탐색한 뒤 자연스럽게 안내**하는 방식으로 변경.

```
scrollViewWillBeginDragging
  → recordCoachMarkScrollStart(offset:)  // 세션 시작 offset 기록

scrollViewDidScroll (매 프레임)
  → trackCoachMarkScroll(currentOffset:)
      ├── guard: !hasBeenShown, !isShowing, isScrolling, hasFinishedInitialDisplay
      ├── delta = abs(currentOffset - lastTrackedOffset)
      ├── accumulated += delta
      └── accumulated >= collectionView.bounds.height?
            ├── accumulated = 0 (리셋)
            ├── stopScrollForCoachMark()  // 즉시 정지 + 상태 정리
            └── asyncAfter(0.2초) → showGridSwipeDeleteCoachMark()
```

**핵심 설계 결정:**
- `isScrolling` 가드로 프로그래밍 스크롤(`scrollToBottom` 등) 제외 — 사용자 드래그만 추적
- `abs(delta)` 누적 — 스크롤 방향 무관, 위아래 왔다갔다 해도 총 거리로 카운트
- threshold 도달 시 `setContentOffset(현재위치, animated: false)` + 상태 정리 → 0.2초 안정화 후 표시
- `stopScrollForCoachMark()`는 `isScrolling = false`, `scrollEndTimer 취소`, `LiquidGlass 최적화 해제` 포함

### dismiss 트리거

```
confirmButton 탭  → dismiss() → markAsShown()
viewWillDisappear → CoachMarkManager.shared.dismissCurrent()
```

**표시 중 모든 터치 차단:** `hitTest`가 확인 버튼 외 모든 터치를 `self`로 흡수. 스크롤, 스와이프, 탭 등 불가.

---

## 애니메이션 상세 설계

### 핵심 원칙: "Show, Don't Tell"

NNGroup 연구에 따르면 텍스트 튜토리얼을 읽은 사용자(4.92점)보다 건너뛴 사용자(5.49점)가 오히려 사용 용이성을 높게 평가했다. 정적 설명이 아니라 **실제 UI가 반응하는 시연**이 핵심이다.

### 실제 스와이프 삭제 동작 분석

- 셀 자체는 이동하지 않음 (transform/frame 변경 없음)
- 셀 위에 Maroon(#800000, alpha 0.6) `dimmedOverlayView`가 CAShapeLayer 마스크로 채워짐
- 오른쪽 스와이프 시 → 빨간 딤드가 왼쪽에서부터 채워짐 (손가락 뒤를 따라옴)
- 왼쪽 스와이프 시 → 빨간 딤드가 줄어들며 복원

### 코치마크 레이아웃 구성

```
[딤 배경 (전체 화면, black 60%)]
  └── [하이라이트 구멍 (셀 영역, CAShapeLayer evenOdd로 투명)]
        ├── 셀 스냅샷 (snapshotView, clipsToBounds=true)
        │     └── Maroon 딤드 뷰 (width 애니메이션)
        └── 손가락 아이콘 (center.x = maroon 우측 끝과 동기화)
  └── [텍스트 + 확인 버튼 (하이라이트 아래)]
```

### 손가락-딤드 좌표 동기화

**핵심:** 손가락 `center.x`와 Maroon 딤드의 우측 끝이 항상 일치해야 자연스러움.

```
초기 상태:
  fingerView.center.x = highlightFrame.minX     (셀 왼쪽 끝)
  maroonView.frame     = (x:0, y:0, w:0, h:셀높이)  (스냅샷 내 좌표)

삭제 스와이프 후:
  fingerView.center.x = highlightFrame.minX + swipeDistance
  maroonView.width    = swipeDistance

복원 스와이프 후:
  fingerView.center.x = highlightFrame.minX     (원위치)
  maroonView.width    = 0                        (원위치)
```

### 애니메이션 루프: 삭제 → 텀 → 복원 → 텀 → 반복

총 사이클: 약 3.0초 (삭제 1.0초 + 텀 0.5초 + 복원 1.0초 + 텀 0.5초)

#### 삭제 스와이프 (→ 오른쪽) — `performDeleteSwipe()`

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| Touch Down | 0.3초 | `.curveEaseOut` | fingerView alpha 0→1, scale 1.1→1.0, shadow 등장 |
| Press | 0.2초 | spring (damping 0.7) | fingerView scale 1.0→0.95, shadow 축소 |
| Drag → | 0.3초 | `UICubicTimingParameters(0.4, 0, 0.2, 1)` | finger center.x += swipeDistance, maroon width 0→swipeDistance, finger 7.5° 기울기 |
| Release | 0.2초 | `.curveEaseIn` | finger alpha 0, scale 1.05, y -10pt (떼기 반동). **maroon은 유지** |

#### 텀 — 0.5초

삭제된 상태(Maroon 100% 채워진 셀)를 잠시 보여줌.

#### 복원 스와이프 (← 왼쪽) — `performRestoreSwipe()`

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| 배치 | 즉시 | - | finger를 오른쪽 끝(minX + swipeDistance)에 배치, alpha 0 |
| Touch Down | 0.3초 | `.curveEaseOut` | fingerView alpha 0→1, scale 1.1→1.0 |
| Press | 0.2초 | spring (damping 0.7) | fingerView scale 1.0→0.95 |
| Drag ← | 0.3초 | `UICubicTimingParameters(0.4, 0, 0.2, 1)` | finger center.x -= swipeDistance, maroon width swipeDistance→0, finger -7.5° 기울기 |
| Release | 0.2초 | `.curveEaseIn` | finger alpha 0, scale 1.05, y -10pt |

#### 텀 — 0.5초

원래 상태로 돌아온 셀을 잠시 보여준 뒤 `resetPositions()` → 루프 재시작.

### 이징 커브 선택 근거

| 구간 | 이징 | 근거 |
|------|------|------|
| Touch Down | `.curveEaseOut` | 빠르게 나타나고 부드럽게 안착. 나타나는 애니메이션은 ease-out이 표준 (Val Head) |
| Press | spring (damping 0.7) | 물리적 누름 + 미세한 바운스. WWDC23 권장: 제스처 피드백에 spring이 가장 자연스러움 |
| Drag | `UICubicTimingParameters(0.4, 0, 0.2, 1)` | Google Authentic Motion. 빠른 가속 + 부드러운 감속이 사람 손동작 속도 곡선과 일치 |
| Release | `.curveEaseIn` | 사라지는 애니메이션은 ease-in이 표준. 나타나는 것보다 짧게 (300ms 등장 vs 200ms 퇴장) |

### 상수 값

| 항목 | 값 | 비고 |
|------|-----|------|
| 딤 배경 알파 | 0.6 | black 60% |
| 손가락 아이콘 | `hand.point.up.fill`, 48pt, white | 그림자: black, offset(0,2), radius 6, opacity 0.3 |
| Maroon 색상 | `UIColor(red:0.5, green:0, blue:0)` | PhotoCell과 동일 |
| Maroon 알파 | 0.60 | PhotoCell.dimmedOverlayAlpha와 동일 |
| 스와이프 거리 | 셀 너비 × 100% | 전체 셀을 채움 |
| 확인 버튼 | 120×44pt, systemBlue, cornerRadius 22 | 캡슐형 |
| 안내 문구 | "사진을 밀어서 바로 휴지통으로 보내세요\n다시 밀면 복원돼요" | 2줄, 17pt medium, white |

### 접근성: Reduce Motion 대응

```swift
if UIAccessibility.isReduceMotionEnabled {
    // 정적 표시: maroon 100% + 손가락 정지 + arrow.right 화살표
} else {
    startGestureLoop()  // 삭제↔복원 반복 애니메이션
}
```

---

## 구현 코드 구조

### CoachMarkOverlayView.swift

```swift
// CoachMarkType enum — UserDefaults 키 관리
// CoachMarkManager — 싱글톤, weak currentOverlay, isShowing, dismissCurrent()

final class CoachMarkOverlayView: UIView {
    // show(type:highlightFrame:snapshot:in:) — UIWindow에 추가
    // dismiss() — shouldStopAnimation + removeAllAnimations + markAsShown + fade
    // hitTest — 확인 버튼만 통과, 나머지 모두 차단 (return self)

    // startGestureLoop() → performDeleteSwipe() → performRestoreSwipe() → resetPositions() → loop
    // showStaticGuide() — Reduce Motion 정적 모드
}
```

### GridViewController+CoachMark.swift

```swift
extension GridViewController {
    // Associated properties (objc_getAssociatedObject 패턴):
    //   coachMarkScrollAccumulated: CGFloat — 스크롤 누적 거리
    //   coachMarkLastTrackedOffset: CGFloat — 마지막 추적 offset

    func recordCoachMarkScrollStart(offset:)    // scrollViewWillBeginDragging에서 호출
    func trackCoachMarkScroll(currentOffset:)    // scrollViewDidScroll에서 호출
    private func showGridSwipeDeleteCoachMark()  // threshold 도달 → 스크롤 정지 → 표시
    private func findCenterCell()                // 화면 중앙 셀 탐색
}
```

---

## 검증 방법

1. 앱 첫 실행 → 그리드 진입 → 스크롤 없이는 코치마크 안 뜸
2. 약 1화면 분량 스크롤 → 스크롤 부드럽게 정지 → 0.2초 후 코치마크 표시
3. 삭제 스와이프(→) → 텀 → 복원 스와이프(←) → 텀 → 반복 자연스러운지
4. 손가락 center.x와 빨간딤드 우측 끝이 항상 일치하는지
5. 표시 중 화면 터치 → 확인 버튼 외 모든 동작 차단되는지
6. [확인] 탭 → dismiss + 앱 재실행 시 안 나타남
7. VoiceOver 켠 상태 → 코치마크 안 뜨는지
8. Reduce Motion 켠 상태 → 정적 안내로 대체되는지
9. 빈 그리드(사진 0장) → 코치마크 안 뜨는지
10. 코치마크 표시 중 화면 이탈(뷰어 진입 등) → dismiss
11. UserDefaults에서 `coachMark_gridSwipe` 키 삭제 후 다시 표시되는지

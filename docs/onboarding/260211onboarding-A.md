# 코치마크 A — 그리드 스와이프 삭제 안내 구현 계획

> **✅ 구현 완료** — 아래 계획 기반으로 구현 완료. 계획과 달라진 부분은 [하단 구현 완료 섹션](#구현-완료) 참조.

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

---

# 온보딩 A-1: 스와이프 삭제 실습 유도 (독립 트리거)

## Context

A 온보딩은 스와이프 삭제 데모를 보여주고 [확인]으로 종료된다.
그러나 사용자가 데모만 보고 실제로 스와이프하지 않으면 E-1이 영영 트리거되지 않고,
결과적으로 유사사진 기능(C 온보딩)도 잠긴 채로 남는다.

**목표**: A 완료 후 스와이프 삭제를 하지 않는 사용자에게 직접 실습을 강제 유도.

---

## 전체 플로우

```
[A 완료] dismiss + markAsShown (기존 로직 변경 없음)
    │
    ├── 5초 내 그리드 스와이프 삭제 수행 → E-1 트리거 (A-1 불필요)
    │
    └── 5초 경과, 스와이프 삭제 미수행
          │
        [A-1 표시] "셀을 가로로 스와이프해서\n삭제해 보세요"
          │     ├── 확인 버튼 없음
          │     ├── 하이라이트 셀만 터치 통과 (스와이프 가능)
          │     └── 그 외 모든 터치 차단 (스크롤, 탭, 뒤로가기 등 불가)
          │
          ├── 스와이프 삭제 성공 → A-1 dismiss → E-1 자동 트리거
          │
          └── 화면 이탈 (viewWillDisappear) → A-1 dismiss
                └── 그리드 재진입 (viewDidAppear) → 조건 충족 시 5초 후 A-1 재표시
```

**핵심**: A-1은 A의 연장이 아닌 **독립 코치마크**. A는 기존대로 [확인] → dismiss → markAsShown.

---

## 트리거 조건

```swift
CoachMarkType.gridSwipeDelete.hasBeenShown == true   // A 완료
CoachMarkType.firstDeleteGuide.hasBeenShown == false  // E-1 미완료 (스와이프 삭제 한 번도 안 함)
!CoachMarkManager.shared.isShowing                    // 다른 코치마크 표시 중 아님
view.window != nil                                    // 화면 활성 상태
```

그리드 `viewDidAppear`에서 위 조건 확인 → **5초 Timer** 시작 → 조건 재확인 후 표시.

---

## 핵심 설계

### 1. 트리거 — `GridViewController+CoachMarkA1.swift` (신규)

D 코치마크의 타이머 패턴을 참고한 독립 트리거.

```swift
extension GridViewController {
    /// A-1 트리거 타이머 시작 (viewDidAppear에서 호출)
    func startCoachMarkA1TimerIfNeeded() {
        // 가드: A 완료 + E-1 미완료일 때만
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else { return }
        guard !CoachMarkType.firstDeleteGuide.hasBeenShown else { return }
        guard !CoachMarkManager.shared.isShowing else { return }
        guard view.window != nil else { return }

        coachMarkA1Timer?.invalidate()
        coachMarkA1Timer = Timer.scheduledTimer(
            withTimeInterval: 5.0, repeats: false
        ) { [weak self] _ in
            self?.showCoachMarkA1()
        }
    }

    /// A-1 오버레이 표시
    private func showCoachMarkA1() {
        // 재가드 (5초 사이에 상태 변경 가능)
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else { return }
        guard !CoachMarkType.firstDeleteGuide.hasBeenShown else { return }
        guard !CoachMarkManager.shared.isShowing else { return }
        guard view.window != nil else { return }

        // 화면 중앙 셀 찾기 (기존 findCenterCell() 활용)
        guard let (cell, _) = findCenterCell() else { return }
        guard let window = view.window,
              let cellFrame = cell.superview?.convert(cell.frame, to: window) else { return }

        // A-1 오버레이 표시 (스냅샷 없음, 확인 버튼 없음)
        CoachMarkOverlayView.showA1(
            highlightFrame: cellFrame,
            in: window
        )
    }

    /// A-1 타이머 취소 (viewWillDisappear에서 호출)
    func cancelCoachMarkA1Timer() {
        coachMarkA1Timer?.invalidate()
        coachMarkA1Timer = nil
    }
}
```

### 2. viewDidAppear / viewWillDisappear 훅
**파일**: `GridViewController.swift`

```swift
// viewDidAppear에 추가
startCoachMarkA1TimerIfNeeded()

// viewWillDisappear에 추가
cancelCoachMarkA1Timer()
// A-1이 활성 중이면 직접 해제 (dismissCurrent는 A-1을 차단하므로)
if CoachMarkManager.shared.isA1Active {
    CoachMarkManager.shared.isA1Active = false
    CoachMarkManager.shared.currentOverlay?.dismiss()
}
```

### 3. A-1 오버레이 UI — `CoachMarkOverlayView+CoachMarkA1.swift` (신규)

```swift
extension CoachMarkOverlayView {
    /// A-1 전용 표시 (스냅샷/손가락/확인버튼 없음)
    static func showA1(highlightFrame: CGRect, in window: UIWindow) {
        let overlay = CoachMarkOverlayView()
        overlay.coachMarkType = .gridSwipeDelete  // 기존 타입 재사용
        overlay.isA1SwipeMode = true
        overlay.highlightFrame = highlightFrame
        overlay.frame = window.bounds

        // 딤 배경 + 하이라이트 구멍 (스냅샷 없이 실제 셀이 보임)
        overlay.setupDimBackground(highlightFrame: highlightFrame)

        // 텍스트: "셀을 가로로 스와이프해서\n삭제해 보세요"
        //   "가로로 스와이프" bold + yellow 강조
        overlay.setupA1Text(below: highlightFrame)

        // 확인 버튼 숨김
        overlay.confirmButton.isHidden = true

        // CoachMarkManager 등록
        CoachMarkManager.shared.currentOverlay = overlay
        CoachMarkManager.shared.isA1Active = true

        window.addSubview(overlay)
        overlay.alpha = 0
        UIView.animate(withDuration: 0.2) { overlay.alpha = 1 }
    }

    /// A-1 텍스트 설정
    private func setupA1Text(below highlightFrame: CGRect) {
        let mainText = "셀을 가로로 스와이프해서\n삭제해 보세요"
        let keyword = "가로로 스와이프"

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 12

        let attributed = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )

        // "가로로 스와이프" bold + yellow 강조
        if let range = mainText.range(of: keyword) {
            let nsRange = NSRange(range, in: mainText)
            attributed.addAttributes([
                .font: UIFont.systemFont(ofSize: 17, weight: .bold),
                .foregroundColor: UIColor.systemYellow
            ], range: nsRange)
        }

        messageLabel.attributedText = attributed
        // 하이라이트 아래 16pt 간격으로 배치
        messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 16,
            width: bounds.width - 40,
            height: 80
        )
    }

    /// A-1 상태 정리
    func cleanupA1() {
        isA1SwipeMode = false
        CoachMarkManager.shared.isA1Active = false
    }
}
```

### 4. hitTest 수정
**파일**: `CoachMarkOverlayView.swift`

```swift
override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
    // A-1: 하이라이트 영역은 터치 통과 (스와이프 허용)
    if isA1SwipeMode && highlightFrame.contains(point) {
        return nil  // 터치가 아래 그리드 셀로 전달
    }
    // 확인 버튼 (A-1에서는 숨겨져 있으므로 도달 안 함)
    let buttonPoint = confirmButton.convert(point, from: self)
    if confirmButton.bounds.contains(buttonPoint) && confirmButton.alpha > 0 {
        return confirmButton
    }
    return self  // 나머지 터치 차단
}
```

### 5. 스와이프 완료 감지 + A-1 dismiss
**파일**: `BaseGridViewController.swift` — confirmSwipeDelete() 성공 콜백

```swift
if case .success = result {
    if CoachMarkManager.shared.isA1Active {
        // A-1 완료: overlay 즉시 제거 → E-1 가드 통과
        CoachMarkManager.shared.isA1Active = false
        let overlay = CoachMarkManager.shared.currentOverlay
        CoachMarkManager.shared.currentOverlay = nil  // isShowing = false
        overlay?.dismiss()  // 시각적 페이드아웃 (백그라운드)
    }
    self?.showDeleteSystemGuideIfNeeded(cell: cell)
}
```

`currentOverlay = nil`을 먼저 설정하여 E-1의 `!isShowing` 가드가 즉시 통과.
A-1 overlay는 백그라운드에서 페이드아웃 (0.2s).

### 6. CoachMarkManager 확장
**파일**: `CoachMarkOverlayView.swift` (CoachMarkManager 내)

```swift
/// A-1 스와이프 실습 모드 활성 중
var isA1Active: Bool = false
```

`dismissCurrent()`에 가드 추가:
```swift
guard !isA1Active else { return }  // A-1 진행 중 dismiss 차단
```

> **이유**: `handleSwipeDeleteBegan`에서 `dismissCurrent()`가 호출됨.
> A-1은 스와이프 진행 중에도 유지되어야 하므로 차단 필요.
> 화면 이탈 시에는 `viewWillDisappear`에서 직접 해제.

### 7. dismiss 시 markAsShown

A-1은 `.gridSwipeDelete` 타입을 재사용하며, gridSwipeDelete는 **이미 markAsShown 완료** 상태.
따라서 dismiss에서 `markAsShown()` 재호출해도 무해 (UserDefaults에 이미 true).

dismiss()에서 `cleanupA1()` 호출 추가:
```swift
cleanupA1()  // isA1SwipeMode, isA1Active 리셋
```

### 8. A는 기존 로직 유지

A의 `confirmTapped()` 분기 **변경 없음**:
```swift
case .gridSwipeDelete:
    if let action = onConfirm { action() } else { dismiss() }
```

A [확인] → dismiss() → markAsShown() → 완료.
A-1은 5초 후 별도 트리거.

### 9. Reduce Motion 대응

```swift
if UIAccessibility.isReduceMotionEnabled {
    // A-1 텍스트 + 정적 화살표 표시 (애니메이션 없음)
    // 하이라이트 셀 터치 통과는 동일
}
```

---

## 수정 대상 파일 요약

| 파일 | 작업 |
|-----|------|
| `GridViewController+CoachMarkA1.swift` **(신규)** | 5초 타이머 트리거, showCoachMarkA1(), cancelTimer |
| `CoachMarkOverlayView+CoachMarkA1.swift` **(신규)** | showA1() 정적 메서드, setupA1Text(), cleanupA1() |
| `CoachMarkOverlayView.swift` | hitTest A-1 분기, CoachMarkManager.isA1Active, dismissCurrent() 가드, dismiss() cleanup |
| `BaseGridViewController.swift` | confirmSwipeDelete()에 A-1 완료 감지 + dismiss |
| `GridViewController.swift` | viewDidAppear에 startCoachMarkA1TimerIfNeeded(), viewWillDisappear에 cancelTimer + A-1 해제 |

---

## 검증

1. **A 완료 → 5초 대기 → A-1 표시**: 딤 배경 + 하이라이트 셀 + 텍스트
2. **A-1에서 스와이프 삭제 성공**: overlay 사라짐 → E-1 트리거
3. **A-1에서 스와이프 취소 (중간에 놓음)**: A-1 유지, 재시도 가능
4. **A-1에서 하이라이트 밖 터치**: 차단됨 (스크롤/탭 불가)
5. **화면 이탈 → 재진입**: A-1 dismiss → 5초 후 다시 A-1 표시
6. **5초 내 스와이프 삭제**: A-1 안 뜸, E-1 직행
7. **앱 kill 후 재실행**: A 이미 완료 상태 → 5초 후 A-1 표시
8. **E-1 완료 후**: A-1 트리거 조건 미충족 → 더 이상 안 뜸
9. **Reduce Motion ON**: 정적 안내 모드
10. **빌드 성공** 확인

---

---

# 구현 완료

> 위 계획 기반으로 구현 완료. 아래는 계획과 **달라진 부분**만 기록.

---

## 변경 1: 타이틀 라벨 추가

계획에 없던 타이틀 라벨 추가.

```
"새로운 삭제 방법" — 24pt light, white, pill shape 흰색 테두리
```

하이라이트 셀 위쪽에 배치.

---

## 변경 2: 안내 문구

| 항목 | 계획 | 구현 |
|------|------|------|
| 문구 | "사진을 밀어서 바로 휴지통으로 보내세요\n다시 밀면 복원돼요" (2줄) | "사진을 밀어서 바로 정리하세요\n다시 밀면 복원돼요\n정리한 사진은 삭제대기함으로 이동됩니다" (3줄) |
| 명칭 | "휴지통" | "삭제대기함" |

---

## 변경 3: 확인 버튼 스타일

| 항목 | 계획 | 구현 |
|------|------|------|
| 색상 | systemBlue 배경 | **흰색 배경 + 검정 텍스트** |
| 크기 | 120×44pt | 120×44pt (동일) |

---

## 변경 4: 딤 배경 알파

| 항목 | 계획 | 구현 |
|------|------|------|
| 딤 알파 | 0.6 (black 60%) | **0.8 (black 80%)** |

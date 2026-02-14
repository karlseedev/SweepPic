# 코치마크 B — 뷰어 스와이프 삭제 안내 구현 계획

## 목표

뷰어에서 사진을 처음 열었을 때, **위로 스와이프하면 사진을 삭제할 수 있다**는 것을 시연 애니메이션으로 안내한다. 실제 삭제 시 사진이 위로 올라가며 사라지는 동작을 스냅샷으로 재현하여, 사용자가 직관적으로 이해하도록 한다.

---

## Context

온보딩 기획(`docs/onboarding/260211onboarding.md`)의 두 번째 코치마크. 코치마크 A(그리드 스와이프 삭제, 구현 완료)의 공용 구조(`CoachMarkOverlayView`, `CoachMarkManager`, `CoachMarkType`)를 확장하여 구현한다.

### A와의 핵심 차이

| | A (그리드) | B (뷰어) |
|---|---|---|
| 스와이프 방향 | 가로 (→←) | **세로 (↑)** |
| 하이라이트 | 셀 1개 (evenOdd 구멍) | **없음** (전체 화면이 대상) |
| 실제 삭제 효과 | Maroon 딤드 채워짐 | **사진 위로 올라감 + 페이드** |
| 시연 요소 | 스냅샷 + maroon 오버레이 | **스냅샷 transform Y + alpha** |
| 복원 모션 | 있음 (←) | **없음** (복구는 휴지통에서) |
| 트리거 | 스크롤 누적 1화면 | **viewDidAppear + 0.5초** |

---

## 파일 구조

### 신규 생성 (1개)

| 파일 | 역할 |
|------|------|
| `PickPhoto/Features/Viewer/ViewerViewController+CoachMark.swift` | 코치마크 B 트리거 (viewDidAppear 호출 → 조건 확인 → 표시) |

### 수정 (2개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `.viewerSwipeDelete` case 추가 + `showViewerSwipeDelete()` 메서드 + 수직 애니메이션 메서드 4개 + dismiss 시 스냅샷 메모리 해제 |
| `ViewerViewController.swift` | `viewDidAppear` 끝에 `scheduleViewerCoachMarkIfNeeded()` 호출 추가, `viewWillDisappear`에 `dismissCurrent()` 추가 |

---

## 트리거 설계

```
viewDidAppear (= 전환 애니메이션 완료 확정 시점)
  └── showViewerSwipeDeleteCoachMark()
        ├── guard: !CoachMarkType.viewerSwipeDelete.hasBeenShown
        ├── guard: !CoachMarkManager.shared.isShowing
        ├── guard: viewerMode == .normal    ← 휴지통/정리 모드 제외
        ├── guard: !UIAccessibility.isVoiceOverRunning
        ├── guard: view.window != nil
        ├── 즉시: 스냅샷 캡처 + 오버레이 생성 (alpha 0) + 윈도우에 추가 (터치 즉시 차단)
        └── 0.5초 후: 오버레이 페이드인 (alpha 1) + 애니메이션 시작
```

**핵심:** 오버레이를 즉시 올려서 0.5초 대기 중 사진 넘기기/뒤로가기 등 모든 터치를 차단. 스냅샷도 즉시 캡처하므로 0.5초 사이 화면 변경 문제 없음. 0.5초 동안 사용자는 사진을 눈으로만 인지.

### dismiss 트리거

```
[확인] 버튼 탭     → dismiss() → markAsShown()
viewWillDisappear  → CoachMarkManager.shared.dismissCurrent()
```

**표시 중 모든 터치 차단**: `hitTest`가 [확인] 버튼 외 모든 터치를 `self`로 흡수 (A와 동일 정책). 스와이프 포함 모든 제스처 차단.

---

## 레이아웃

```
┌──────────────────────────────┐
│  Dim 배경 (black 50%)        │ ← A(60%)보다 밝음
│  ┌──────────────────────────┐│
│  │                          ││
│  │    Photo Snapshot        ││ ← pageVC.view 스냅샷 (전체 화면)
│  │    (transform Y↑ + fade) ││
│  │                          ││
│  │          👆              ││ ← Finger (center, ↑ 이동)
│  │                          ││
│  └──────────────────────────┘│
│  ▓▓▓ gradient ▓▓▓▓▓▓▓▓▓▓▓▓▓▓│ ← transparent→black 70% (150pt)
│  "위로 밀면 바로 삭제돼요"     │
│  "삭제된 사진은 휴지통에서     │
│   복구할 수 있어요"           │
│          [확인]               │
└──────────────────────────────┘
```

**레이어 Z-순서 (아래→위):**
1. `dimLayer` — CAShapeLayer, black 50%, **구멍 없음** (A와 달리 evenOdd 불필요)
2. `snapshotView` — 사진 스냅샷 (전체 화면, transform 애니메이션 대상)
3. `gradientLayer` — **신규** 하단 그라디언트 (텍스트 가독성)
4. `fingerView` — 손가락 아이콘
5. `messageLabel` + `confirmButton` — 안내 텍스트 + 버튼

**스냅샷이 올라가면:** 하단에 dim 배경(검정 50%)이 드러남 → 사진이 "빠져나가는" 느낌.

---

## 애니메이션 상세 설계

### 실제 뷰어 삭제 동작 분석

- 사진 콘텐츠만 위로 이동 (UI 버튼은 제자리)
- 드래그 중: `transform Y = offsetY × 0.3` (30% 축소, 느린 따라옴)
- 삭제 확정: `Y = -100, alpha = 0.5`, 0.2초
- 바운스백: 스프링 damping 0.6

### 코치마크 시연: 삭제 → 텀 → 리셋 → 텀 → 반복 (3회)

총 사이클: 약 3.0초, **3회 반복 후 정지** (NNGroup 권장: 과다 반복 시 사용자 무시)

#### 삭제 시연 — `performUpSwipe()`

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| Touch Down | 0.3초 | `.curveEaseOut` | finger alpha 0→1, scale 1.1→1.0 |
| Press | 0.35초 | spring (damping 0.7) | finger scale 1.0→0.95 ("여기를 누르는구나" 인지 시간) |
| Drag ↑ | 0.45초 | `UICubicTimingParameters(0.4, 0, 0.2, 1)` | finger center.y -= 200pt, snapshot transform Y -= 80pt + alpha 1.0→0.5 |
| Release | 0.2초 | `.curveEaseIn` | finger alpha 0, scale 1.05, y +10pt (떼기 반동). **snapshot 유지** |

> **타이밍 근거:** CHI 2024 연구에 따르면 실제 인간의 스와이프 평균 시간은 ~421ms. Press 0.35초로 누름 동작 인지 시간 확보, Drag 0.45초로 실제 손 속도에 가깝게 설정.

#### 텀 — 0.8초

삭제된 상태(사진 올라가고 투명해진)를 잠시 보여줌. 사용자가 "삭제됐구나"를 인지할 충분한 시간.

#### 리셋 — `resetVerticalPositions()`

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| 즉시 리셋 | 0초 | - | snapshot transform → .identity (위치 원복), alpha는 0 유지 |
| 페이드인 | 0.3초 | `.curveEaseOut` | snapshot alpha 0 → 1.0 (**다음 사진이 나타나는** 느낌) |

실제 뷰어에서 삭제 후 다음 사진이 나타나는 동작을 재현. 슬라이드백(복원)이 아님.

#### 텀 — 0.8초

새 사진 상태를 잠시 보여준 뒤 루프 재시작. 3회째 완료 후 스냅샷이 원위치에서 정지.

### 손가락-스냅샷 좌표 동기화

```
초기 상태:
  fingerView.center = (screen.midX, screen.midY + 50)  ← 화면 중앙보다 약간 아래
  snapshot.transform = .identity
  snapshot.alpha     = 1.0

삭제 시연 후:
  fingerView.center.y -= 200                            ← 위로 200pt
  snapshot.transform  = CGAffineTransform(translationX: 0, y: -80)
  snapshot.alpha      = 0.5

리셋 후 (즉시):
  fingerView — 초기 위치로 복귀, alpha 0
  snapshot.transform  = .identity
  snapshot.alpha      = 0              ← 투명 상태에서 시작

페이드인 후:
  snapshot.alpha      = 1.0            ← 다음 사진이 나타나는 효과
```

finger 200pt vs snapshot 80pt = 실제 앱의 ×0.3 축소 비율을 ×0.4로 약간 과장하여 시각적 명확성 확보.

### 이징 커브 선택 근거

A와 동일 (WWDC23 권장 + Google Authentic Motion):
- Touch Down: `.curveEaseOut` — 빠르게 나타나고 부드럽게 안착
- Press: spring (damping 0.7) — 물리적 누름 바운스
- Drag: cubic(0.4, 0, 0.2, 1) — 사람 손동작 속도 곡선
- Release: `.curveEaseIn` — 빠르게 사라짐

### 상수 값

| 항목 | 값 | 비고 |
|------|-----|------|
| 딤 배경 알파 | 0.50 | A(0.6)보다 밝음 — 사진 배경 인지 |
| 손가락 아이콘 | `hand.point.up.fill`, 48pt, white | A와 동일 |
| 스냅샷 이동 거리 | 80pt | 화면 높이의 ~10% |
| 손가락 이동 거리 | 200pt | 드래그 제스처 명확히 |
| 그라디언트 높이 | 150pt | 텍스트 가독성 |
| 버튼 텍스트 | "확인" | A와 동일 |
| 반복 횟수 | 3회 | NNGroup 권장: 과다 반복 시 사용자 무시 |
| 안내 문구 | "위로 밀면 바로 삭제돼요\n삭제된 사진은 휴지통에서 복구할 수 있어요" | 2줄, 17pt medium, white |

### 접근성: Reduce Motion 대응

```swift
if UIAccessibility.isReduceMotionEnabled {
    // 정적 표시: snapshot transform Y -= 40, alpha 0.7
    //           + 손가락 정지 + arrow.up 화살표
} else {
    startVerticalGestureLoop()
}
```

---

## 구현 코드 구조

### CoachMarkType 확장

```swift
enum CoachMarkType: String {
    case gridSwipeDelete = "coachMark_gridSwipe"
    case viewerSwipeDelete = "coachMark_viewerSwipe"   // NEW
}
```

### CoachMarkOverlayView — 새 show 메서드

```swift
/// 코치마크 B: 뷰어 스와이프 삭제 표시
/// - 즉시: 오버레이 생성 + 윈도우에 추가 (alpha 0, 터치 차단 시작)
/// - 0.5초 후: 페이드인 + 애니메이션 시작
static func showViewerSwipeDelete(
    photoSnapshot: UIView,
    in window: UIWindow
)
```

**A와의 차이:** A는 show() 호출 시 즉시 페이드인. B는 show() 호출 시 즉시 터치 차단하되, 0.5초 후 페이드인.
기존 `show(type:highlightFrame:snapshot:in:)` (A용)은 그대로 유지.

### CoachMarkOverlayView — 수정/추가 메서드

```swift
// 기존 수정
updateDimPath()
  → coachMarkType 분기: A는 evenOdd 구멍, B는 구멍 없음

dismiss()
  → snapshotView?.removeFromSuperview(); snapshotView = nil  // 풀스크린 스냅샷 메모리 즉시 해제

// 신규 추가 (B 전용 애니메이션)
startVerticalGestureLoop()    // B 루프 시작점 (3회 카운터 포함)
performUpSwipe()              // 위로 스와이프 시연
resetVerticalPositions()      // 스냅샷+손가락 원위치
showStaticVerticalGuide()     // Reduce Motion 정적 모드

// 신규 추가 (B 전용 UI)
gradientLayer: CAGradientLayer  // 하단 그라디언트
loopCount: Int                  // 반복 카운터 (3회 후 정지)
```

### ViewerViewController+CoachMark.swift

```swift
extension ViewerViewController {
    /// viewDidAppear에서 호출 — 조건 확인 + 즉시 오버레이 배치 (터치 차단 + 0.5초 후 페이드인)
    func showViewerSwipeDeleteCoachMarkIfNeeded()
}
```

A의 `GridViewController+CoachMark.swift`와 달리 스크롤 추적이 불필요하므로 associated object도 불필요. 조건 확인 + 스냅샷 캡처 + show 호출만.

---

## 검증 방법

1. 뷰어 첫 진입 → 0.5초 후 코치마크 표시
2. 사진 스냅샷이 위로 올라가면서 투명해지는 애니메이션 3회 반복 후 정지
3. 손가락 이동(200pt)과 스냅샷 이동(80pt)이 비례하는지
4. 하단 그라디언트 위 텍스트가 밝은 사진에서도 읽히는지
5. [확인] 탭 → dismiss + 앱 재실행 시 안 나타남
6. 표시 중 모든 터치 차단 ([확인] 외 스와이프/탭 모두 불가)
7. VoiceOver 켠 상태 → 코치마크 안 뜨는지
8. Reduce Motion → 정적 안내로 대체
9. 휴지통 모드 / 정리 모드 → 코치마크 안 뜨는지
10. 코치마크 표시 중 뷰어 닫기 (back) → dismiss
11. UserDefaults `coachMark_viewerSwipe` 삭제 후 다시 표시되는지
12. 코치마크 A가 아직 안 뜬 상태에서 뷰어 진입 → A/B 동시 표시 안 되는지 (isShowing 가드)

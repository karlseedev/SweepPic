# 코치마크 B — 뷰어 스와이프 삭제 안내 구현 계획

> **✅ 구현 완료** — 아래 계획 기반으로 구현 완료. 계획과 달라진 부분은 [하단 구현 완료 섹션](#구현-완료) 참조.

## 목표

뷰어에서 사진을 처음 열었을 때, **위로 스와이프하면 사진을 삭제할 수 있다**는 것을 시연 애니메이션으로 안내한다. 실제 삭제 시 사진이 위로 올라가며 사라지는 동작을 스냅샷으로 재현하여, 사용자가 직관적으로 이해하도록 한다.

---

## Context

온보딩 기획(`docs/onboarding/260211onboarding.md`)의 두 번째 코치마크. 코치마크 A(목록 스와이프 삭제, 구현 완료)의 공용 구조(`CoachMarkOverlayView`, `CoachMarkManager`, `CoachMarkType`)를 확장하여 구현한다.

### A와의 핵심 차이

| | A (그리드) | B (뷰어) |
|---|---|---|
| 스와이프 방향 | 가로 (→←) | **세로 (↑)** |
| 하이라이트 | 셀 1개 (evenOdd 구멍) | **없음** (전체 화면이 대상) |
| 실제 삭제 효과 | Maroon 딤드 채워짐 | **사진 위로 올라가며 alpha 페이드아웃** |
| 시연 요소 | 스냅샷 + maroon 오버레이 | **스냅샷 transform Y + alpha 페이드** |
| 복원 모션 | 있음 (←) | **없음** (복구는 휴지통에서) |
| 트리거 | 스크롤 누적 1화면 | **viewDidAppear + 0.5초** |

---

## 파일 구조

### 수정 (4개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `.viewerSwipeDelete` case 추가 + `showViewerSwipeDelete()` 메서드 + 수직 애니메이션 메서드 4개 + dismiss 시 스냅샷 메모리 해제 |
| `ViewerViewController.swift` | `capturePhotoSnapshot()` 메서드 추가 (private 우회), `viewDidAppear` 끝에 호출 추가, `viewWillDisappear` guard **앞에** `dismissCurrent()` 추가 |
| `ViewerViewController+CoachMark.swift` | 기존 빈 스텁 → 코치마크 B 트리거 구현 (조건 확인 + 스냅샷 + 표시) |
| `SwipeDeleteHandler.swift` | `handlePan .began`에서 `CoachMarkManager.shared.dismissCurrent()` 1줄 추가 (방어 코드) |

---

## 트리거 설계

### 트리거 시점 (2곳)

```
1) viewDidAppear (= 전환 애니메이션 완료 확정 시점)
     └── showViewerSwipeDeleteCoachMarkIfNeeded()

2) didFinishAnimating (= 페이지 스와이프 완료 시점, completed=true)
     └── currentIndex 갱신 후
     └── showViewerSwipeDeleteCoachMarkIfNeeded()
```

**시나리오 커버:**
- 이미지 직접 탭 → `viewDidAppear`에서 트리거
- 동영상 탭 → 스킵 → 스와이프해서 이미지로 이동 → `didFinishAnimating`에서 트리거
- 동영상 → 동영상 → 이미지 스와이프 → 이미지 도착 시 트리거

### 가드 조건

```
showViewerSwipeDeleteCoachMarkIfNeeded()
  ├── guard: !CoachMarkType.viewerSwipeDelete.hasBeenShown
  ├── guard: !CoachMarkManager.shared.isShowing
  ├── guard: viewerMode == .normal    ← 휴지통/정리(.cleanup) 모드 제외
  ├── guard: mediaType != .video      ← 동영상 스킵, 이미지만 표시
  ├── guard: !UIAccessibility.isVoiceOverRunning
  ├── guard: view.window != nil
  ├── guard: presentedViewController == nil  ← 모달이 올라온 경우 방지
  ├── 즉시: 스냅샷 캡처 + 오버레이 생성 (alpha 0.01) + 윈도우에 추가 (터치 즉시 차단)
  └── 0.5초 후: 오버레이 페이드인 (alpha 1) + 애니메이션 시작
```

**핵심:** 오버레이를 즉시 올려서 0.5초 대기 중 사진 넘기기/뒤로가기 등 모든 터치를 차단. 스냅샷도 즉시 캡처하므로 0.5초 사이 화면 변경 문제 없음. 0.5초 동안 사용자는 사진을 눈으로만 인지.
**동영상 스킵:** `coordinator.asset(at: currentIndex)?.mediaType == .video`이면 코치마크를 표시하지 않음. 동영상은 스냅샷 캡처가 부정확하고, 재생 UI가 겹쳐 코치마크와 충돌.

### `capturePhotoSnapshot()` — private 접근 우회 + 이미지만 캡처

`pageViewController`는 `private lazy var` (ViewerViewController.swift:154).
별도 파일인 `ViewerViewController+CoachMark.swift`에서는 접근 불가.

**ViewerViewController.swift에 추가:**
```swift
/// 사진 콘텐츠 스냅샷 + 윈도우 좌표 (코치마크용)
/// - pageViewController.view가 아닌 currentPageImageView를 캡처 (검은 여백 제외, 이미지만)
/// - 반환: (snapshot: 스냅샷 뷰, frame: 윈도우 기준 이미지 프레임)
func capturePhotoSnapshot() -> (snapshot: UIView, frame: CGRect)? {
    guard let imageView = currentPageImageView,
          let snapshot = imageView.snapshotView(afterScreenUpdates: false),
          let window = view.window else { return nil }
    let frameInWindow = imageView.convert(imageView.bounds, to: window)
    return (snapshot, frameInWindow)
}
```

**pageViewController.view 대신 currentPageImageView를 쓰는 이유:**
pageVC.view 스냅샷은 위아래 검은 여백(letterbox)을 포함하여, 스냅샷이 올라갈 때 여백도 같이 이동하는 문제 발생. 이미지뷰만 캡처하면 사진만 올라가고 여백은 그대로 유지된다.

### dismiss 트리거

```
[확인] 버튼 탭     → dismiss() → markAsShown()
위 스와이프 시작    → SwipeDeleteHandler .began → dismissCurrent() (방어 코드*)
viewWillDisappear  → CoachMarkManager.shared.dismissCurrent() (guard 앞에 배치)
```

*\* hitTest가 모든 터치를 차단하므로 SwipeDeleteHandler 제스처는 코치마크 표시 중 도달하지 않음. 방어 코드로만 유효.*

**viewWillDisappear 배치 위치:**
```swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // 코치마크 dismiss — guard 앞에 배치 (모달 등 모든 disappear에서 동작)
    CoachMarkManager.shared.dismissCurrent()

    // 기존 guard (dismiss/pop 시에만 실행되는 로직)
    guard isBeingDismissed || isMovingFromParent else { return }
    // ... 기존 코드 ...
}
```

**표시 중 모든 터치 차단**: `hitTest`가 [확인] 버튼 외 모든 터치를 `self`로 흡수 (A와 동일 정책). 스와이프 포함 모든 제스처 차단.

---

## 레이아웃

```
┌──────────────────────────────┐
│  솔리드 black 배경             │ ← overlay.backgroundColor = .black
│  ┌──────────────────────────┐│
│  │    Photo Snapshot        ││ ← currentPageImageView 스냅샷 (이미지만, 검은 여백 제외)
│  │    (transform Y↑ + fade) ││    photoFrame 좌표에 배치
│  │  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┐ ││
│  │  │  dimView (alpha 0.5)│ ││ ← 스냅샷 위 반투명 딤드
│  │  └ ─ ─ ─ ─ ─ ─ ─ ─ ─ ┘ ││
│  │          👆              ││ ← Finger (center, ↑ 이동)
│  └──────────────────────────┘│
│                              │
│  "위로 밀면 바로 삭제돼요"     │ ← 화면 높이의 2/3 지점
│  "삭제된 사진은 휴지통에서     │
│   복구할 수 있어요"           │
│         [확인]               │ ← iOS 26: glass() / iOS 25-: 기존 파란 버튼
└──────────────────────────────┘
```

**레이어 Z-순서 (아래→위):**
1. `overlay.backgroundColor = .black` — 솔리드 검정 배경 (원본 VC 완전 차단)
2. `snapshotView` — 사진 이미지만 스냅샷 (photoFrame 좌표에 배치, transform + alpha 애니메이션 대상)
3. `dimView` — UIView, black alpha 0.50 (스냅샷 위에 배치, 텍스트 가독성 확보)
4. `fingerView` — 손가락 아이콘
5. `messageLabel` + `confirmButton` — 안내 텍스트 + 버튼

**배경을 솔리드 black으로 한 이유:** 반투명 딤(70%)으로는 뒤의 원본 이미지가 비쳐 보임. 솔리드 black으로 완전 차단 후, 스냅샷 위에 별도 dimView(50%)를 올려 텍스트 가독성 확보.
**스냅샷이 올라가면:** 위로 이동하며 alpha 페이드아웃 → 솔리드 black 배경이 드러남 → 사진이 "삭제되어 사라지는" 느낌.

---

## 애니메이션 상세 설계

### 실제 뷰어 삭제 동작 분석

- 사진 콘텐츠만 위로 이동 (UI 버튼은 제자리)
- 드래그 중: `transform Y = offsetY × 0.3` (30% 축소, 느린 따라옴)
- 삭제 확정: `Y = -100, alpha = 0.5`, 0.2초 (코치마크에서는 alpha 변경 안 함 — 겹침 방지)
- 바운스백: 스프링 damping 0.6

### 코치마크 시연: 삭제 → 텀 → 리셋 → 텀 → 반복 (3회)

총 사이클: 약 3.0초, **3회 반복 후 정지** (NNGroup 권장: 과다 반복 시 사용자 무시)

#### 삭제 시연 — `performUpSwipe()`

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| Touch Down | 0.35초 | `.curveEaseOut` | finger alpha 0→1, scale 1.1→1.0 |
| Press | 0.2초 | spring (damping 0.7) | finger scale 1.0→0.95 |
| Drag ↑ | 0.7초 | keyframe `.calculationModeCubic` | **단일 연속 모션** (아래 상세) |
| Release | 0.2초 | `.curveEaseIn` | finger만 alpha 0, scale 1.05, y +10pt (떼기 반동) |

**Drag 단계 상세 (keyframe animation, 0.7초):**
```
[0%─────────────────────────────────────100%]  finger center.y -= 300pt
[0%─────────────────────────────────────100%]  snapshot transform Y -= 300pt
                              [55%──────100%]  snapshot alpha 1.0 → 0 (후반 페이드)
```
- `UIView.animateKeyframes` + `.calculationModeCubic`으로 하나의 연속 모션
- 0~100%: 손가락과 스냅샷이 동일한 300pt를 동일한 속도로 이동 (속도 동기화)
- 55~100%: 스냅샷 alpha만 1.0→0으로 페이드 (이동 중 자연스럽게 사라짐)
- Release는 손가락 페이드아웃만 담당 (스냅샷은 Drag에서 이미 완료)

> **타이밍 근거:** CHI 2024 연구에 따르면 실제 인간의 스와이프 평균 시간은 ~421ms. Drag 0.7초는 시연 목적으로 약간 느리게 설정.

#### 텀 — 0.8초

삭제된 상태(사진이 화면 상단으로 빠져나간)를 잠시 보여줌. 사용자가 "삭제됐구나"를 인지할 충분한 시간.

#### 리셋 — `resetVerticalPositions()`

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| 즉시 리셋 | 0초 | - | snapshot transform → .identity (위치 원복), alpha → 0 |
| 페이드인 | 0.3초 | `.curveEaseOut` | snapshot alpha 0 → 1.0 (**다음 사진이 나타나는** 느낌) |

실제 뷰어에서 삭제 후 다음 사진이 나타나는 동작을 재현. 슬라이드백(복원)이 아님.
리셋 시 alpha 0→1.0 페이드인은 0.3초로 짧아 dim(70%)과 합쳐져 원본 겹침이 거의 보이지 않음.

#### 텀 — 0.8초

새 사진 상태를 잠시 보여준 뒤 루프 재시작. 3회째 완료 후 스냅샷이 원위치에서 정지.

### 손가락-스냅샷 좌표 동기화

```
초기 상태:
  fingerView.center = (screen.midX, screen.midY + 50)  ← 화면 중앙보다 약간 아래
  snapshot.transform = .identity
  snapshot.alpha     = 1.0

Drag 완료 후:
  fingerView.center.y -= 300                            ← 위로 300pt
  snapshot.transform  = CGAffineTransform(translationX: 0, y: -300)  ← 동일 300pt
  snapshot.alpha      = 0               ← 페이드아웃 완료

리셋 후 (즉시):
  fingerView — 초기 위치로 복귀, alpha 0
  snapshot.transform  = .identity       ← 원위치
  snapshot.alpha      = 0               ← 투명 상태에서 시작

페이드인 후:
  snapshot.alpha      = 1.0             ← 다음 사진이 나타나는 효과
```

**속도 동기화:** finger 300pt = snapshot 300pt. 동일 거리를 동일 시간(0.7초)에 이동하여 속도가 일치.
배경이 솔리드 black이므로 alpha 페이드 시 원본 이미지 겹침 문제 없음.

### 이징 커브 선택 근거

A와 동일 (WWDC23 권장 + Google Authentic Motion):
- Touch Down: `.curveEaseOut` — 빠르게 나타나고 부드럽게 안착
- Press: spring (damping 0.7) — 물리적 누름 바운스
- Drag: `.calculationModeCubic` keyframe — 부드러운 연속 커브
- Release: `.curveEaseIn` — 빠르게 사라짐

### 상수 값

| 항목 | 값 | 비고 |
|------|-----|------|
| 배경 | 솔리드 black | `overlay.backgroundColor = .black` (원본 VC 완전 차단) |
| 딤뷰 알파 | 0.50 | 스냅샷 위 UIView (텍스트 가독성 확보) |
| 손가락 아이콘 | `hand.point.up.fill`, 48pt, white | A와 동일 |
| 스냅샷 이동 거리 | 300pt | 손가락과 동일 거리 (속도 동기화) |
| 손가락 이동 거리 | 300pt | 드래그 제스처 명확히 |
| 스냅샷 alpha 변화 | 1.0 → 0 (Drag 후반 55%~) | 이동 중 자연스럽게 페이드아웃 |
| 텍스트 위치 | 화면 높이의 2/3 지점 | 중간 약간 아래 |
| 버튼 텍스트 | "확인" | A와 동일 |
| 버튼 스타일 | iOS 26: `UIButton.Configuration.glass()` / iOS 25-: 기존 파란색 라운드 | |
| 안내 문구 | "이미지를 위로 밀면 바로 휴지통으로 이동돼요\n잘못 삭제된 사진은 휴지통에서 복구할 수 있어요" | 2줄, 17pt medium, white |
| 반복 횟수 | 3회 | NNGroup 권장: 과다 반복 시 사용자 무시 |

### 접근성: Reduce Motion 대응

```swift
if UIAccessibility.isReduceMotionEnabled {
    // 정적 표시: snapshot transform Y -= 150pt (위로 이동된 상태)
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
/// - photoSnapshot: currentPageImageView 스냅샷 (이미지만, 검은 여백 제외)
/// - photoFrame: 윈도우 기준 이미지 프레임 (스냅샷 배치 좌표)
/// - 즉시: 오버레이 생성 (alpha 0.01, 터치 차단) + 윈도우에 추가
/// - 0.5초 후: 페이드인 + 애니메이션 시작
static func showViewerSwipeDelete(
    photoSnapshot: UIView,
    photoFrame: CGRect,
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
  → snapshotView?.layer.removeAllAnimations()  // 진행 중 애니메이션 중단
  → snapshotView?.removeFromSuperview(); snapshotView = nil  // 풀스크린 스냅샷 메모리 즉시 해제
  → dimView 등 B 전용 서브뷰 정리

// 신규 추가 (B 전용 애니메이션)
startVerticalGestureLoop()    // B 루프 시작점 (3회 카운터 포함)
performUpSwipe()              // 위로 스와이프 시연 (keyframe animation)
resetVerticalPositions()      // 스냅샷+손가락 원위치
showStaticVerticalGuide()     // Reduce Motion 정적 모드

// 신규 추가 (B 전용 프로퍼티)
loopCount: Int                  // 반복 카운터 (3회 후 정지)
```

### ViewerViewController.swift — 추가

```swift
/// 사진 콘텐츠 스냅샷 + 윈도우 좌표 (코치마크용)
func capturePhotoSnapshot() -> (snapshot: UIView, frame: CGRect)? {
    guard let imageView = currentPageImageView,
          let snapshot = imageView.snapshotView(afterScreenUpdates: false),
          let window = view.window else { return nil }
    let frameInWindow = imageView.convert(imageView.bounds, to: window)
    return (snapshot, frameInWindow)
}
```

### ViewerViewController+CoachMark.swift

```swift
extension ViewerViewController {
    /// viewDidAppear에서 호출 — 조건 확인 + 즉시 오버레이 배치 (터치 차단 + 0.5초 후 페이드인)
    func showViewerSwipeDeleteCoachMarkIfNeeded()
}
```

A의 `GridViewController+CoachMark.swift`와 달리 스크롤 추적이 불필요하므로 associated object도 불필요. 조건 확인 + 스냅샷 캡처 + show 호출만.

### 스냅샷 애니메이션 안전 규칙 (1차 실패 교훈)

1차 구현에서 스냅샷 애니메이션이 전혀 작동하지 않았음. 원인은 코드 에러로 추정 (ViewerCoordinator.swift:465-477에서 동일 snapshotView 애니메이션이 정상 작동하므로 _UIReplicantView 자체의 제한은 아님).

**재구현 시 준수 사항:**
1. `guard let result = capturePhotoSnapshot() else { return }` — non-nil 검증 필수
2. 애니메이션 클로저에서 **로컬 변수로 캡처** (self.snapshotView? 옵셔널 체이닝 사용 금지)
3. Z-순서: 솔리드 black bg → snapshotView → dimView(UIView) → fingerView → 텍스트/버튼
4. CAShapeLayer sublayer는 UIView subview 아래에 렌더링되므로, dim은 UIView로 구현해야 스냅샷 위에 표시됨

---

## 테스트 모드

개발/디버깅 중에는 `hasBeenShown` 가드를 일시적으로 비활성화하여 뷰어 진입 시 매번 코치마크가 표시되도록 한다.

```swift
// ViewerViewController+CoachMark.swift — 테스트 중 임시 비활성화
// guard !CoachMarkType.viewerSwipeDelete.hasBeenShown else { return }
```

QA 완료 후 가드를 다시 활성화한다.

---

## 구현 이력

### 1차 구현 (2026-02-14) — 롤백 `2b70824`

계획대로 3개 파일 수정/생성 완료. 빌드 성공. 오버레이 표시, 터치 차단, 손가락 애니메이션, dismiss 등 대부분 정상 동작 확인.

**미해결: 스냅샷(사진) 애니메이션 미동작.** 손가락은 올라가지만 사진은 전혀 이동하지 않음. 4가지 접근 시도 후 전체 롤백.

### 2차 구현 (2026-02-16) — 롤백 `74a1b67`

스냅샷 애니메이션 안전 규칙 적용하여 재구현. 빌드 성공. **스냅샷 애니메이션 정상 동작 확인.**

**사용자 피드백:**
1. 딤 배경(0.50)이 낮아서 텍스트가 잘 안 보임 → **0.70으로 상향**
2. 스냅샷 이동 거리(80pt)가 너무 작음, 실제 스와이프 삭제처럼 크게 올라가야 함 → **screenHeight×0.5로 상향**
3. 스냅샷 alpha 감소(1.0→0.5) 시 뒤에 원본 이미지가 겹쳐 보임 → **alpha 변경 제거, 물리적 이동만으로 삭제감 전달**

피드백 반영하여 3차 구현 진행.

### 3차 구현 (2026-02-16) — `7064b9c`

2차 피드백 + 추가 피드백 반영하여 재구현. **구현 완료.**

**2차 대비 주요 변경점:**
1. **스냅샷 소스 변경**: `pageViewController.view` → `currentPageImageView` (검은 여백 제외, 이미지만 캡처)
2. **배경 변경**: 반투명 dimLayer(70%) → 솔리드 black 배경 + dimView(UIView, 50%)
3. **Z-순서 수정**: CAShapeLayer sublayer → UIView subview (sublayer는 subview 아래 렌더링되는 문제 해결)
4. **애니메이션 통합**: 별도 Drag(0.45s) + Release(0.2s) → 단일 keyframe animation(0.7s)으로 끊김 제거
5. **속도 동기화**: 스냅샷 screenHeight×0.5 → 300pt (손가락과 동일 거리로 속도 일치)
6. **alpha 페이드 추가**: Drag 후반(55%~)에서 스냅샷 alpha 1.0→0 페이드 (솔리드 배경이라 겹침 없음)

---

## 검증 방법

1. 뷰어 첫 진입 → 0.5초 후 코치마크 표시
2. 사진 스냅샷이 위로 올라가며 페이드아웃하는 애니메이션 3회 반복 후 정지
3. 손가락 이동(300pt)과 스냅샷 이동(300pt)이 동일 속도인지
4. 텍스트가 화면 2/3 지점에 위치하는지, 밝은 사진에서도 읽히는지
5. [확인] 탭 → dismiss + 앱 재실행 시 안 나타남
6. 표시 중 모든 터치 차단 ([확인] 외 스와이프/탭 모두 불가)
7. VoiceOver 켠 상태 → 코치마크 안 뜨는지
8. Reduce Motion → 정적 안내로 대체
9. 휴지통 모드 / 정리 모드 → 코치마크 안 뜨는지
10. 코치마크 표시 중 뷰어 닫기 (back) → dismiss
11. UserDefaults `coachMark_viewerSwipe` 삭제 후 다시 표시되는지
12. 코치마크 A가 아직 안 뜬 상태에서 뷰어 진입 → A/B 동시 표시 안 되는지 (isShowing 가드)
13. iOS 26에서 glass 버튼 확인 / iOS 25 이하에서 파란 버튼 확인

---

---

# 구현 완료

> 위 계획 기반으로 구현 완료 (3차 구현 `7064b9c`). 아래는 계획과 **달라진 부분**만 기록.

---

## 변경 1: 안내 문구

| 항목 | 계획 | 구현 |
|------|------|------|
| 문구 | "이미지를 위로 밀면 바로 휴지통으로 이동돼요\n잘못 삭제된 사진은 휴지통에서 복구할 수 있어요" (2줄) | "사진을 위로 밀면 바로\n삭제대기함으로 이동해요" (1줄) |
| 명칭 | "휴지통" | "삭제대기함" |
| 강조 | 없음 | **"삭제대기함" 볼드+노란색(#FFD700)** |

---

## 변경 2: 딤뷰 알파

| 항목 | 계획 | 구현 |
|------|------|------|
| 스냅샷 위 dimView 알파 | 0.50 | **0.30** |

사진 스냅샷 가시성 개선을 위해 더 밝게 조정.

---

## 변경 3: 애니메이션 타이밍 미세 조정

| 단계 | 계획 | 구현 |
|------|------|------|
| Touch Down | 0.35s | **0.3s** |
| Press | 0.2s | **0.35s** |

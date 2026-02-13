# 코치마크 A — 그리드 스와이프 삭제 안내 구현 계획

## 목표

사용자가 그리드에 처음 진입했을 때, 스와이프로 사진을 정리할 수 있다는 것을 자연스러운 제스처 시연 애니메이션으로 안내한다. 텍스트 설명이 아니라 실제 UI 반응(Maroon 딤드 채워짐)을 보여주어, 사용자가 직관적으로 조작법을 이해하도록 한다.

---

## Context

온보딩 기획(`docs/260211onboarding.md`)의 첫 번째 코치마크를 구현한다. 사용자가 그리드에 처음 진입하면 2초 후 "스와이프로 사진을 정리할 수 있다"는 안내를 딤 배경 + 손가락 애니메이션 + 셀 반응 피드백 + 텍스트로 보여준다. 향후 B/C/D 코치마크 확장을 고려해 공용 구조로 설계한다.

---

## 파일 구조

### 신규 생성 (2개)

| 파일 | 역할 |
|------|------|
| `PickPhoto/Shared/Components/CoachMarkOverlayView.swift` | 코치마크 오버레이 뷰 + CoachMarkManager 싱글톤 + CoachMarkType enum |
| `PickPhoto/Features/Grid/GridViewController+CoachMark.swift` | 코치마크 A 트리거/표시/dismiss 로직 |

### 수정 (2개, 각 1줄)

| 파일 | 수정 내용 |
|------|-----------|
| `BaseGridViewController.swift:795` | `handleSwipeDeleteBegan` 첫 줄에 `CoachMarkManager.shared.dismissCurrent()` 추가 |
| `GridScroll.swift:420` | `finishInitialDisplay` 끝에 `scheduleCoachMarkIfNeeded()` 추가 |

---

## 애니메이션 상세 설계

### 핵심 원칙: "Show, Don't Tell"

NNGroup 연구에 따르면 텍스트 튜토리얼을 읽은 사용자(4.92점)보다 건너뛴 사용자(5.49점)가 오히려 사용 용이성을 높게 평가했다. 정적 설명이 아니라 **실제 UI가 반응하는 시연**이 핵심이다. Mailbox, Clear, Tinder 등 제스처 기반 앱의 성공 사례가 이를 뒷받침한다.

따라서 손가락만 움직이는 것이 아니라, **셀에 Maroon 딤드가 채워지는 실제 삭제 피드백을 함께 보여준다.**

### 실제 스와이프 삭제 동작 분석

코치마크 애니메이션은 실제 삭제 동작과 시각적으로 일치해야 한다. 실제 동작(PhotoCell 기준):

- 셀 자체는 이동하지 않음 (transform/frame 변경 없음)
- 셀 위에 Maroon(#800000, alpha 0.6) `dimmedOverlayView`가 CAShapeLayer 마스크로 서서히 채워짐
- 오른쪽 스와이프 시 → 빨간 딤드가 왼쪽에서부터 채워짐 (손가락 뒤를 따라옴)
- 셀 너비의 50% 도달 또는 800pt/s 속도로 삭제 확정
- 확정 시 0.15초 easeOut으로 전체 딤드 채움

### 코치마크 애니메이션 구성 요소

```
[딤 배경 (전체 화면, black 60%)]
  └── [하이라이트 구멍 (셀 영역, evenOdd로 투명)]
        ├── 셀 스냅샷 (snapshotView로 실제 셀 캡처, clipsToBounds=true)
        ├── Maroon 딤드 (스냅샷 위에서 width 애니메이션)  ← 실제 동작 재현
        └── 손가락 아이콘 (위에서 이동)
  └── [텍스트 + 확인 버튼 (하이라이트 아래)]
```

### 애니메이션 방식: UIView.animate completion 체인

`UIView.animateKeyframes`는 전체 시퀀스에 하나의 calculationMode만 적용 가능하여, stage별 다른 이징(easeOut, spring, cubic-bezier)을 줄 수 없다. 따라서 **`UIView.animate` completion 체인**으로 구현한다.

### 애니메이션 5단계 시퀀스

총 사이클: 3.2초 (애니메이션 1.8초 + 대기 1.4초), completion 재귀 호출로 무한 반복

#### Stage 1: Touch Down — 등장 (0.3초)

손가락이 셀 위에 나타나며 내려앉는 느낌.

```
duration: 0.3초
easing: .curveEaseOut (빠르게 나타나고 부드럽게 안착)

fingerView:
  - alpha: 0 → 1
  - transform: scale(1.1) → identity (위에서 내려앉는 느낌)
  - position: 하이라이트 셀의 중앙-오른쪽 (x: midX + 10%, y: midY)
  - layer.shadowOpacity: 0 → 0.3
  - layer.shadowRadius: 4 → 8
```

#### Stage 2: Press — 누르기 (0.2초)

손가락이 표면을 누르는 물리적 피드백.

```
duration: 0.2초
easing: spring (damping 0.7, velocity 0) — 미세한 바운스로 물리적 느낌

fingerView:
  - transform: identity → scale(0.95) (눌림)
  - layer.shadowRadius: 8 → 4 (표면에 가까워짐)
  - layer.shadowOpacity: 0.3 → 0.2
```

#### Stage 3: Drag — 스와이프 (0.6초)

핵심 구간. 손가락이 오른쪽으로 이동하면서 셀에 Maroon 딤드가 채워진다.

```
duration: 0.6초
easing: UIView.animate + CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0)
        → Google Authentic Motion: 빠른 가속 + 부드러운 감속, 사람 손동작과 유사

fingerView:
  - center.x: +셀너비 × 0.55 (실제 확정 비율 50%를 약간 초과하여 "확정됨"을 암시)
  - transform: scale(0.95).rotated(by: .pi/24) (7.5° 기울기 — 이동 방향으로 자연스러운 기울어짐)

maroonView (스냅샷 위에 배치, clipsToBounds로 셀 안에만 보임):
  - frame.size.width: 0 → 셀너비 × 0.55 (왼쪽에서부터 채워짐)
  - 실제 PhotoCell.updateDimmedMask의 .right 방향과 동일한 시각효과
```

fingerView 이동과 maroonView width를 동일 animate 블록에서 처리하여 자연스럽게 동기화.

#### Stage 4: Release — 떼기 + 페이드 (0.35초)

손가락을 떼고 사라진다. 셀 딤드는 0.15초 후 리셋.

```
duration: 0.35초
easing: .curveEaseIn (빠르게 사라짐)

fingerView (0.2초):
  - transform: scale(0.95) → scale(1.05) (떼는 반동)
  - alpha: 1 → 0
  - center.y: -10pt (살짝 위로 떠오름)

maroonView (0.15초, 0.2초 delay — 손가락이 먼저 사라진 후):
  - alpha: 1 → 0
```

#### Stage 5: Pause — 대기 (1.4초)

모든 요소 숨김 상태에서 대기. 사용자가 텍스트를 읽는 시간.

```
duration: 1.4초
모든 요소: alpha = 0
completion에서:
  - fingerView 위치/transform/shadow 리셋
  - maroonView width/alpha 리셋
  - startGestureLoop() 재귀 호출
```

### 구현 코드 구조

```swift
private var shouldStopAnimation = false

func startGestureLoop() {
    guard !shouldStopAnimation else { return }

    // Stage 1: Touch Down (0.3초, easeOut)
    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
        self.fingerView.alpha = 1.0
        self.fingerView.transform = .identity
    }) { [weak self] _ in
        guard let self, !self.shouldStopAnimation else { return }

        // Stage 2: Press (0.2초, spring)
        UIView.animate(withDuration: 0.2, delay: 0,
                       usingSpringWithDamping: 0.7,
                       initialSpringVelocity: 0, animations: {
            self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            // Stage 3: Drag (0.6초, custom curve via CATransaction)
            CATransaction.begin()
            CATransaction.setAnimationTimingFunction(
                CAMediaTimingFunction(controlPoints: 0.4, 0.0, 0.2, 1.0))
            UIView.animate(withDuration: 0.6, animations: {
                self.fingerView.center.x += self.swipeDistance
                self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    .rotated(by: .pi / 24)
                self.maroonView.frame.size.width = self.swipeDistance
            }) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { return }

                // Stage 4: Release (0.35초, easeIn)
                UIView.animate(withDuration: 0.2, delay: 0,
                               options: .curveEaseIn, animations: {
                    self.fingerView.alpha = 0
                    self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                }) { _ in }

                UIView.animate(withDuration: 0.15, delay: 0.2,
                               options: .curveEaseOut, animations: {
                    self.maroonView.alpha = 0
                }) { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { return }

                    // Stage 5: Pause (1.4초) → 리셋 → 재시작
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) { [weak self] in
                        guard let self, !self.shouldStopAnimation else { return }
                        self.resetPositions()
                        self.startGestureLoop()
                    }
                }
            }
            CATransaction.commit()
        }
    }
}

func stopAnimation() {
    shouldStopAnimation = true
    fingerView.layer.removeAllAnimations()
    maroonView.layer.removeAllAnimations()
}
```

### 이징 커브 선택 근거

| 구간 | 이징 | 근거 |
|------|------|------|
| Touch Down | `.curveEaseOut` | 빠르게 나타나고 부드럽게 안착. 나타나는 애니메이션은 ease-out이 표준 (Val Head) |
| Press | spring (damping 0.7) | 물리적 누름 + 미세한 바운스. WWDC23 권장: 제스처 피드백에 spring이 가장 자연스러움 |
| Drag | cubic-bezier(0.4, 0, 0.2, 1) | Google Authentic Motion. 빠른 가속 + 부드러운 감속이 사람 손동작의 속도 곡선과 일치 |
| Release | `.curveEaseIn` | 사라지는 애니메이션은 ease-in이 표준. 나타나는 것보다 짧게 (300ms 등장 vs 200ms 퇴장) |

### 타이밍 근거 (NNGroup / Val Head 기반)

| 항목 | 값 | 근거 |
|------|-----|------|
| 등장 | 300ms | 사용자가 손가락 위치를 인지하는 최소 시간 (시각 인지 230ms + 여유) |
| 프레스 | 200ms | 즉각적 느낌(100ms)과 인지 가능(230ms) 사이 |
| 스와이프 | 600ms | 경로를 따라갈 수 있되 느리지 않은 범위 (400~600ms 권장) |
| 릴리즈 | 350ms | 나타나는 것보다 짧게 |
| 대기 | 1400ms | 사용자가 본 내용을 처리하는 시간 (1.0~2.0s 권장) |
| 총 사이클 | 3200ms | 2.5~3.8s 범위 내 |

### 손가락 아이콘 설계

- SF Symbol: `hand.point.up.fill`, pointSize 48
- 색상: `.white`
- 그림자: `shadowColor = .black`, `shadowOffset = (0, 2)`, `shadowRadius = 6`, `shadowOpacity = 0.3`
- 다크모드 전용 앱이므로 흰색 아이콘 + 어두운 그림자로 충분한 가시성 확보

### 셀 스냅샷 활용

```swift
// 하이라이트 대상 셀의 스냅샷 캡처
guard let snapshot = targetCell.snapshotView(afterScreenUpdates: false) else { return }
snapshot.clipsToBounds = true  // Maroon 딤드가 스냅샷 영역 안에만 보이도록

// 스냅샷 위에 Maroon 딤드 뷰 배치
let maroonView = UIView()
maroonView.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)
maroonView.alpha = 0.6  // PhotoCell.dimmedOverlayAlpha와 동일
maroonView.frame = CGRect(x: 0, y: 0, width: 0, height: snapshot.bounds.height)
snapshot.addSubview(maroonView)
```

snapshotView는 원본 셀과 완전히 독립된 UIView이므로 frame/transform 변경이 원본에 영향 없음.

### 접근성: Reduce Motion 대응

Apple 앱 심사 기준에서 Reduce Motion 대응은 필수.

```swift
if UIAccessibility.isReduceMotionEnabled {
    // 애니메이션 없이 정적 표시:
    // 1. 셀 스냅샷 위에 Maroon 딤드를 55% 채운 정적 상태로 표시
    // 2. 손가락 아이콘을 셀 오른쪽에 정지 상태로 배치
    // 3. 화살표 SF Symbol (arrow.right) 추가하여 스와이프 방향 표시
    // 4. 텍스트 + 확인 버튼만 표시 (페이드인 0.3초만 허용)
} else {
    startGestureLoop()
}
```

---

## 구현 단계

### Phase 1: CoachMarkOverlayView.swift 생성

**CoachMarkType enum**
- `case gridSwipeDelete` (향후 B/C/D 추가)
- `var shownKey: String` → UserDefaults 키
- `hasBeenShown` / `markAsShown()`

**CoachMarkManager 싱글톤**
- `weak var currentOverlay` — 현재 표시 중인 오버레이
- `isShowing` / `dismissCurrent()`

**CoachMarkOverlayView (UIView)**
- 딤 배경: `CAShapeLayer` + `fillRule = .evenOdd` → 하이라이트 셀만 투명
- 셀 스냅샷 + Maroon 딤드 (스냅샷 위 서브뷰)
- 손가락 아이콘: SF Symbol `hand.point.up.fill`, 48pt, 흰색 + 그림자
- 텍스트: "사진을 밀어서 바로 정리하세요\n다시 밀면 복원돼요"
- [확인] 버튼: 캡슐형, systemBlue 배경, 흰색 텍스트
- `show()`: UIWindow에 직접 추가 (ToastView 패턴)
- `dismiss()`: shouldStopAnimation + removeAllAnimations + 페이드아웃 → removeFromSuperview
- `hitTest` 오버라이드: [확인] 버튼만 터치 받고, 나머지는 아래로 통과

### Phase 2: 애니메이션 구현

- `startGestureLoop()` — UIView.animate completion 체인 (5단계)
- `stopAnimation()` — shouldStopAnimation flag + removeAllAnimations
- `resetPositions()` — 모든 뷰를 초기 상태로
- Reduce Motion 분기 — 정적 표시 모드

### Phase 3: GridViewController+CoachMark.swift 생성

```
scheduleCoachMarkIfNeeded()
├── guard: hasScheduledCoachMark == false
├── guard: hasBeenShown == false
├── guard: isShowing == false
├── guard: hasFinishedInitialDisplay == true
├── guard: !isScrolling
├── guard: !UIAccessibility.isVoiceOverRunning
├── guard: dataSourceDriver.count > 0
├── hasScheduledCoachMark = true
└── DispatchQueue.main.asyncAfter(2초) → showGridSwipeDeleteCoachMark()

showGridSwipeDeleteCoachMark()
├── 조건 재확인
├── findCenterCell()
├── targetCell.snapshotView(afterScreenUpdates: false)
├── cellFrameInWindow()
└── CoachMarkOverlayView.show(...)
```

**화면 이탈 시 dismiss:**
```
viewWillDisappear()
└── CoachMarkManager.shared.dismissCurrent()
```

### Phase 4: 기존 파일 수정 (각 1줄)

1. `BaseGridViewController.swift:795` — `handleSwipeDeleteBegan` 첫 줄에 `CoachMarkManager.shared.dismissCurrent()`
2. `GridScroll.swift:420` — `updateCleanupButtonState()` 아래에 `scheduleCoachMarkIfNeeded()`

---

## 검증 방법

1. 앱 첫 실행 → 그리드 진입 → 2초 후 코치마크 표시 확인
2. 손가락 등장 → 누르기 바운스 → 스와이프 + 딤드 동기화 → 떼기 반동 → 대기 → 반복이 자연스러운지
3. [확인] 탭 → dismiss + 앱 재실행 시 안 나타남 확인
4. 코치마크 표시 중 셀 스와이프 → dismiss 확인
5. VoiceOver 켠 상태에서 코치마크 안 뜨는지 확인
6. Reduce Motion 켠 상태에서 정적 안내로 대체되는지 확인
7. 빈 그리드(사진 0장) → 코치마크 안 뜨는지 확인
8. 코치마크 표시 중 탭 전환 → dismiss 확인
9. UserDefaults에서 키 삭제 후 다시 표시되는지 확인

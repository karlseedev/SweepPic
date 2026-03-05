# Coach Mark A 2-Step 확장: 멀티스와이프 온보딩

## Context

멀티스와이프 삭제 기능이 구현되어 (`BaseMultiSwipeDelete.swift`), 기존 Coach Mark A 온보딩을 2단계로 확장한다.
- **Step 1**: 기존 단일 스와이프 데모 (시작 위치와 버튼만 변경)
- **Step 2**: 멀티스와이프 데모 (가로 3셀 → 위로 2행 확장, 카운터 뱃지)

사용자가 "다음 →"을 눌러야 Step 2 진입 → **강제 중단점**으로 멀티스와이프를 명확히 인식.

---

## 파일 변경 개요

| 파일 | 작업 | 분량 |
|------|------|------|
| `CoachMarkOverlayView+CoachMarkA2.swift` **(신규)** | Step 2 전환, 멀티 데모 루프, 카운터, cleanup | ~450줄 |
| `GridViewController+CoachMark.swift` **(수정)** | 셀 탐색 (중앙+1행), 9셀 스냅샷 수집, show 후 프로퍼티 설정 | ~100줄 추가 |
| `CoachMarkOverlayView.swift` **(수정)** | confirmTapped 분기, dismiss cleanup, private→internal 3개 뷰, A2 전환 플래그 | ~25줄 수정 |

**show() 시그니처 변경 없음** — 호출 후 프로퍼티 설정 (onDismiss 패턴과 동일)

---

## Phase 1: GridViewController+CoachMark.swift 수정

### 1-1. `findCellForCoachMarkA()` 신규

중앙+1행 셀을 찾고, Step 2에 필요한 9셀 데이터를 사전 수집.

```
출력: (anchorCell, anchorIndexPath, row3Frames[3], all9Frames[9], all9IndexPaths[9])?
      — nil이면 Step 2 불가 → findCenterCell() 폴백

로직:
1. 화면 중앙 좌표에서 가장 가까운 셀 → 그 행 + 1행 셀 탐색
   - non-trashed 우선 (A-1 텍스트 "삭제해 보세요"와 일치)
2. anchorRow 위로 2행 존재 가드: anchorRow >= 2 (item 기준 행)
   - paddingCellCount가 있으면 padding 행이 포함될 수 있음
   - 9셀 중 padding 셀이 있으면 실패 처리 (nil 반환)
3. 9셀 프레임 수집: layoutAttributesForItem(at:) + convert(to: window)
4. 9셀 모두 화면 내 존재 가드: cellForItem(at:) != nil (스냅샷 캡처 필수)
5. 9셀 합산 rect가 safeArea 내인지 가드 (소형 기기 대응)
6. 하단 여유 공간 가드: anchorRow maxY + 메시지(80pt) + 간격(16pt) + 버튼(buttonHeight) + safeAreaBottom < bounds.height
   - 공간 부족 시 nil 반환 → Step 1 폴백
7. columnCount 가드: currentGridColumnCount.rawValue < 3이면 nil 반환 (1열 모드 폴백)
```

### 1-2. `captureMultiCellSnapshots()` 신규

```
입력: [IndexPath] (9개)
출력: [UIView] (9개 스냅샷)

로직:
- cellForItem(at:) → snapshotView(afterScreenUpdates: false)
- nil인 경우 backgroundColor .darkGray 대체 (안전장치)
```

### 1-3. `showGridSwipeDeleteCoachMark()` 수정

```swift
func showGridSwipeDeleteCoachMark() {
    // ... 기존 가드 유지 ...

    // [변경] Step 2 데이터 시도 → 실패 시 기존 findCenterCell() 폴백
    let multiData = findCellForCoachMarkA()
    let anchorCell: PhotoCell
    let anchorIndexPath: IndexPath

    if let data = multiData {
        (anchorCell, anchorIndexPath) = (data.0, data.1)
    } else if let fallback = findCenterCell() {
        (anchorCell, anchorIndexPath) = fallback
    } else { return }

    guard let snapshot = anchorCell.snapshotView(afterScreenUpdates: false),
          let window = view.window,
          let cellFrame = anchorCell.superview?.convert(anchorCell.frame, to: window)
    else { return }

    // 기존 show() 호출 (시그니처 변경 없음)
    CoachMarkOverlayView.show(
        type: .gridSwipeDelete,
        highlightFrame: cellFrame,
        snapshot: snapshot,
        in: window
    )

    // [신규] Step 2 데이터 설정 (onDismiss 패턴과 동일)
    if let data = multiData, let overlay = CoachMarkManager.shared.currentOverlay {
        let multiSnapshots = captureMultiCellSnapshots(indexPaths: data.4)
        overlay.aCurrentStep = 1
        overlay.aMultiCellFrames = data.2       // 같은 행 3셀 프레임
        overlay.aAll9CellFrames = data.3        // 전체 9셀 프레임
        overlay.aMultiSnapshots = multiSnapshots
        overlay.confirmButton.setTitle("다음 →", for: .normal)
    }

    // 기존 onDismiss (변경 없음)
    CoachMarkManager.shared.currentOverlay?.onDismiss = { [weak self] in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self?.startCoachMarkA1TimerIfNeeded()
        }
    }
}
```

**핵심**: show()는 overlay.alpha=0 상태에서 시작 → 0.3s 페이드인 동안 프로퍼티가 설정됨 → 버튼 텍스트 "다음 →"은 사용자에게 보이기 전에 적용됨.

---

## Phase 2: CoachMarkOverlayView.swift 수정

### 2-0. 접근 제어 변경 + A2 전환 플래그

Step 2 전환 시 별도 파일(A2.swift)에서 접근해야 하는 `private` 멤버 3개를 `internal`로 변경:

```swift
// 변경 전: private var snapshotView: UIView?     (211줄)
// 변경 후:
var snapshotView: UIView?

// 변경 전: private let maroonView: UIView = { ... (214줄)
// 변경 후:
let maroonView: UIView = { ... }()

// 변경 전: private let arrowView: UIImageView = { ... (287줄)
// 변경 후:
let arrowView: UIImageView = { ... }()
```

CoachMarkManager에 A2 전환 중 dismiss 차단 플래그 추가 (C-3 `isC3TransitionActive` 패턴):

```swift
/// A Step 1→2 전환 중 (true 동안 dismissCurrent() 차단)
var isA2TransitionActive = false
```

dismissCurrent()에 차단 조건 추가:

```swift
guard !isA2TransitionActive else {
    Logger.coachMark.debug("dismissCurrent BLOCKED — isA2TransitionActive=true")
    return
}
```

### 2-1. confirmTapped() gridSwipeDelete 분기 수정 (924줄)

```swift
case .gridSwipeDelete:
    if let action = onConfirm {
        action()                    // Replay Variant (기존)
    } else if aCurrentStep == 1 {
        confirmButton.isEnabled = false
        transitionToA2()            // Step 1 → Step 2 전환 (신규)
    } else {
        dismiss()                   // Step 2 "확인" 또는 레거시(aCurrentStep=0)
    }
```

### 2-2. dismiss() cleanup 추가 (883줄 근처)

```swift
cleanupA1()     // 기존
cleanupA2()     // 추가
CoachMarkManager.shared.isA2TransitionActive = false  // 안전 정리
```

---

## Phase 3: CoachMarkOverlayView+CoachMarkA2.swift (신규)

### 3-1. Associated Object Properties

| 프로퍼티 | 타입 | 기본값 | 용도 |
|---------|------|--------|------|
| `aCurrentStep` | `Int` | 0 | 0=레거시/Replay, 1=Step 1, 2=Step 2 |
| `aCounterBadge` | `UILabel?` | nil | 빨간 원형 카운터 |
| `aMultiSnapshots` | `[UIView]?` | nil | 9셀 스냅샷 (인덱스 순서: Row0→Row2) |
| `aMultiMaroonViews` | `[UIView]?` | nil | 9셀 개별 maroon 딤드 |
| `aMultiCellFrames` | `[CGRect]?` | nil | 같은 행 3셀 윈도우 프레임 |
| `aAll9CellFrames` | `[CGRect]?` | nil | 전체 9셀 윈도우 프레임 |

### 3-2. transitionToA2() — Step 1 → Step 2 전환

```
t=0.00  shouldStopAnimation = true (Step 1 루프 정지)
        CoachMarkManager.shared.isA2TransitionActive = true (dismiss 차단)

t=0.00~0.25  Step 1 요소 페이드아웃 (0.25s)
  - snapshotView alpha → 0
  - fingerView alpha → 0
  - maroonView alpha → 0

t=0.25  타이틀 크로스페이드 (UIView.transition .crossDissolve, 0.3s)
  - "새로운 삭제 방법" → "한번에 쓱"

t=0.25  하이라이트 구멍 확장 (CABasicAnimation 0.4s)
  - animateHighlightExpansion(to: row3UnionRect)
  - 패턴: C-2 animateC2FocusCircle()의 rect 버전
  - from: 1셀 rect path → to: 3셀 rect path (포인트 수 동일, 자연스러운 보간)

t=0.30  3셀 스냅샷 배치 + 페이드인 (0.3s)
  - aMultiSnapshots[6,7,8] addSubview → 윈도우 좌표 위치
  - 3개 maroonView 생성 (width=0) → 각 스냅샷 위에 addSubview

t=0.55  메시지 텍스트 교체 + 페이드인 (0.25s)
  - "밀면서 옆이나 아래로 쓸면\n여러 장을 한번에 정리해요"
  - "여러 장", "한번에" → bodyBoldFont + highlightYellow

t=0.65  버튼 변경
  - confirmButton.setTitle("확인", for: .normal)
  - confirmButton.isEnabled = true

t=0.80  멀티 데모 시작
  - aCurrentStep = 2
  - shouldStopAnimation = false
  - CoachMarkManager.shared.isA2TransitionActive = false (dismiss 차단 해제)
  - UIAccessibility.isReduceMotionEnabled ? showA2StaticGuide() : startMultiSwipeLoop()
```

### 3-3. 멀티스와이프 데모 루프

셀 인덱스 (9셀 배열 기준, 위→아래):
```
[0] [1] [2]  ← Row 0 (최상단) — Phase B 두 번째 확장
[3] [4] [5]  ← Row 1 (중간)   — Phase B 첫 번째 확장
[6] [7] [8]  ← Row 2 (앵커행) — Phase A 시작
```

**Phase A — 가로 순차 채움**
```
0.00s  fingerView 등장 (셀[6] 좌측) — 0.3s ease-out
0.30s  누르기 — 0.2s spring(0.7)
0.50s  셀[6] maroon 채움 (0.25s) + 카운터 "1" bounce
0.75s  finger → 셀[7] (0.2s cubic-bezier)
0.95s  셀[7] maroon 채움 (0.25s) + 카운터 "2"
1.20s  finger → 셀[8] (0.2s)
1.40s  셀[8] maroon 채움 (0.25s) + 카운터 "3"
```

**Phase B — 세로 확장 (손가락 떼지 않고 연속)**
```
1.65s  finger ↑ Row 1 중앙 (0.3s)
       하이라이트 확장: 3셀→6셀 rect (animateHighlightExpansion)
       Row 1 스냅샷[3,4,5] 페이드인 (0.2s)
1.95s  셀[3,4,5] maroon 동시 채움 (0.25s) + 카운터 "6" bounce

2.20s  finger ↑ Row 0 중앙 (0.3s)
       하이라이트 확장: 6셀→9셀 rect
       Row 0 스냅샷[0,1,2] 페이드인 (0.2s)
2.50s  셀[0,1,2] maroon 동시 채움 (0.25s) + 카운터 "9" bounce

2.75s  릴리즈 — 0.2s ease-in
2.95s  텀 — 0.5s (9셀 빨간 상태 유지)
```

**복원 (역방향)**
```
3.45s  finger 등장 (Row 0 근처) — 0.25s
3.70s  셀[0,1,2] maroon 걷힘 (0.2s) + 카운터 "6"
       하이라이트 수축: 9셀→6셀
3.90s  셀[3,4,5] maroon 걷힘 (0.2s) + 카운터 "3"
       하이라이트 수축: 6셀→3셀
4.10s  셀[8] 걷힘 (0.15s) + 카운터 "2"
4.25s  셀[7] 걷힘 (0.15s) + 카운터 "1"
4.40s  셀[6] 걷힘 (0.15s) + 카운터 → 페이드아웃
4.55s  릴리즈 — 0.2s
4.75s  텀 — 0.7s
5.45s  루프 반복
```

### 3-4. animateHighlightExpansion()

C-2의 `animateC2FocusCircle()` 패턴을 rect 버전으로 적용:

```swift
func animateHighlightExpansion(to newFrame: CGRect, duration: TimeInterval = 0.3) {
    let startPath = UIBezierPath(rect: bounds)
    startPath.append(UIBezierPath(rect: highlightFrame))  // 현재 hole

    let endPath = UIBezierPath(rect: bounds)
    endPath.append(UIBezierPath(rect: newFrame))           // 새 hole

    // model layer 동기화 (C-2/D 패턴: 애니메이션 전 시작 상태 명시)
    dimLayer.path = startPath.cgPath

    CATransaction.begin()
    CATransaction.setCompletionBlock { [weak self] in
        self?.highlightFrame = newFrame
        self?.dimLayer.path = endPath.cgPath
        self?.dimLayer.removeAnimation(forKey: "highlightExpand")
    }

    let anim = CABasicAnimation(keyPath: "path")
    anim.fromValue = startPath.cgPath
    anim.toValue = endPath.cgPath
    anim.duration = duration
    anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
    anim.fillMode = .forwards
    anim.isRemovedOnCompletion = false
    dimLayer.add(anim, forKey: "highlightExpand")

    CATransaction.commit()
}
```

### 3-5. 카운터 뱃지

```
위치: 하이라이트 우상단 외부 (offset +4, -4)
모양: systemRed 배경, 흰 텍스트 (bold 14pt), cornerRadius 14
크기: 28×28pt (1자리) / 34×28pt (2자리)
효과: scale 1.0→1.3→1.0 (0.2s spring, damping 0.6)
0일 때: 페이드아웃 (0.15s)
```

### 3-6. Reduce Motion 대응

```
showA2StaticGuide():
  - 3셀(Row 2) 전체 maroon 55% 채움 (정적)
  - 카운터 "3" 표시 (애니메이션 없음)
  - 손가락 셀[8] 우측 끝 정지
  - arrowView: arrow.right + arrow.up 표시
  - 하이라이트는 3셀 유지 (확장 없음)
```

### 3-7. cleanupA2()

```swift
func cleanupA2() {
    aCounterBadge?.removeFromSuperview()
    aCounterBadge = nil
    aMultiSnapshots?.forEach { $0.removeFromSuperview() }
    aMultiSnapshots = nil
    aMultiMaroonViews?.forEach { $0.removeFromSuperview() }
    aMultiMaroonViews = nil
    aMultiCellFrames = nil
    aAll9CellFrames = nil
    aCurrentStep = 0
}
```

---

## 호환성 보장

| 항목 | 상태 | 근거 |
|------|------|------|
| **Replay Variant** | 변경 불필요 | 별도 overlay, onConfirm 설정 → confirmTapped에서 onConfirm 분기 먼저 진입 (aCurrentStep=0) |
| **A-1 실습** | 변경 불필요 | 별도 overlay(isA1SwipeMode), onDismiss는 Step 2 dismiss에서만 호출 |
| **1열 모드** | 폴백 처리 | columnCount < 3 → findCellForCoachMarkA() nil → Step 1만 표시 |
| **가로 모드 (5열)** | 동작 보장 | 같은 행 3셀 선택은 columnCount 무관, 하이라이트 3셀 너비 |
| **소형 기기** | 폴백 처리 | 9셀 rect + 하단 UI 공간 부족 → findCellForCoachMarkA() nil → Step 1만 표시 |
| **사진 9장 미만** | 폴백 처리 | 9셀 수집 실패 → Step 1만 표시 |
| **전환 중 회전/스크롤** | 차단 처리 | isA2TransitionActive=true 동안 dismissCurrent() 차단 |
| **show() 호출처** | 영향 없음 | 시그니처 변경 없음, 1개 호출처만 호출 후 프로퍼티 설정 추가 |

---

## 검증 방법

1. **Step 1 기본 동작**: ~1화면 스크롤 → 코치마크 표시, 시작 셀 중앙+1행
2. **"다음 →" 전환**: 타이틀 크로스페이드 + 하이라이트 확장 + 3셀 스냅샷
3. **Phase A**: 가로 1→2→3 순차 + 카운터 bounce
4. **Phase B**: 세로 3→6→9 행단위 동시 + 하이라이트 확장 + 카운터 점프
5. **복원 루프**: 역방향 9→6→3→2→1→0 + 하이라이트 수축
6. **Step 2 "확인"**: dismiss → markAsShown → 3초 후 A-1 실습
7. **Replay 호환**: 재생 → 기존 Replay Variant 동작 유지
8. **Reduce Motion**: Step 1/2 정적 모드
9. **iPhone SE**: 9셀 화면 내 + 하단 메시지/버튼 잘림 없음
10. **사진 9장 미만**: Step 1만 표시 (Step 2 스킵)
11. **1열 모드**: Step 1만 표시 (Step 2 스킵)
12. **전환 중 회전**: dismiss 차단 → 전환 완료 후 정상 동작
13. **빌드 성공**: xcodebuild

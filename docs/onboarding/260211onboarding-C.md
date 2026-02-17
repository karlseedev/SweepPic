# 코치마크 C — 유사 사진·얼굴 비교 안내 구현 계획

## 목표

유사사진 뱃지가 표시된 셀을 하이라이트하고, 사용자가 [확인]을 누르면 **자동으로 해당 셀을 탭하여 뷰어로 진입** → + 버튼을 하이라이트하고, 다시 [확인]을 누르면 **자동으로 + 버튼을 탭하여 얼굴 비교 화면으로 진입**한다.

사용자는 [확인] 2회만 누르면 기능의 전체 흐름을 체험한다. 그 외 모든 터치는 차단된다.

---

## Context

온보딩 기획(`docs/onboarding/260211onboarding.md`)의 세 번째 코치마크. A(그리드 스와이프, 구현 완료), B(뷰어 스와이프, 구현 완료)의 공용 구조를 확장한다.

### A/B와의 핵심 차이

| | A (그리드) | B (뷰어) | **C (유사사진)** |
|---|---|---|---|
| 단계 | 1단계 | 1단계 | **2단계 연속 (C-1 → C-2)** |
| 시연 방식 | 스와이프 모션 반복 | 스와이프 모션 반복 | **하이라이트 + 탭 모션 (1회)** |
| [확인] 후 | dismiss | dismiss | **자동 네비게이션** |
| 터치 차단 범위 | 코치마크 표시 중 | 코치마크 표시 중 | **C-1 시작 ~ C-2 완료까지 연속** |

---

## 전체 플로우

```
[C-1 시작] 뱃지 표시 즉시 터치 차단 (투명 blocker)
    │
    ├── scrollToItem 셀 중앙 배치 (0.4초)
    ├── blocker 제거 → 코치마크 오버레이 표시 (터치 차단 이어받음)
    ├── 그리드: 뱃지 셀 하이라이트 (evenOdd 구멍)
    ├── 카피: "유사사진 정리기능이 표시된 사진이에요.
    │         각 사진의 얼굴을 비교해서 정리할 수 있어요"
    ├── [확인] ← 유일한 터치 허용 (1회차)
    ├── 확인 버튼+카피+테두리 링 페이드아웃
    ├── 손가락 탭 모션 on 뱃지 셀 (0.5초)
    ├── fillDimHole (CA 암묵적 애니메이션 제거) + 오버레이 alpha=0.01
    ├── 자동 네비게이션 → 뷰어 (didSelectItemAt 호출)
    │       (오버레이 alpha=0.01 + 뷰어 isUserInteractionEnabled=false)
    │
    ├── 뷰어 viewDidAppear 대기
    ├── + 버튼 표시 대기 (~100ms, 캐시 hit)
    │
[C-2 시작] 터치 차단 유지
    │
    ├── 뷰어 isUserInteractionEnabled 복원
    ├── 오버레이 bringSubviewToFront + alpha 0.01→1.0 페이드인
    ├── 뷰어: + 버튼 하이라이트 (원형 구멍) + 흰색 테두리 링 강조
    ├── 카피: "+버튼을 눌러 얼굴비교화면으로 이동하세요.
    │         인물이 여러 명이면 좌우로 넘겨볼 수 있어요."
    ├── [확인] ← 유일한 터치 허용 (2회차)
    ├── 확인 버튼+카피 페이드아웃
    ├── 손가락 탭 모션 on + 버튼 (0.6초)
    ├── 오버레이 dismiss + 터치 차단 해제
    ├── 자동 네비게이션 → 얼굴 비교 화면 (delegate 메서드 호출)
    │       ⚠️ .fullScreen present 시 UIKit transition container가
    │          window 최상단에 삽입되어 오버레이를 가림
    │          → dismiss 후 present 순서로 해결
    ├── present 성공 후 markAsShown()
    │       ⚠️ present 실패 시 markAsShown() 미호출 → 다음 기회에 재시도
    │
[C-2 완료]
```

---

## 파일 구조

### 수정 (3개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `.similarPhoto` case 추가 + C-1/C-2 show 메서드 + 탭 모션 애니메이션 + `confirmTapped()` C 분기 + `onConfirm` 콜백 |
| `CoachMarkType` | `similarPhoto` 케이스 추가 (C-1/C-2 통합 플래그) |
| `FaceButtonOverlay.swift` | 첫 번째 + 버튼의 프레임을 외부에 노출하는 접근자 추가 |

### 신규 (2개)

| 파일 | 내용 |
|------|------|
| `GridViewController+CoachMarkC.swift` | C-1 트리거 로직 (zone 검증 + 뱃지 감지 + 안전 타임아웃) |
| `CoachMarkOverlayView+CoachMarkC.swift` | C-1/C-2 show/transition + 탭 모션 + 눌림 피드백 + fillDimHole |
| `ViewerViewController+CoachMarkC.swift` | C-2 트리거 (폴링 + 전환 + 얼굴 비교 자동 진입) |

### 기존 수정 (4개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `dimLayer` internal 접근 + `CoachMarkManager`에 `safetyTimeoutWork`/`resetC2State()` 추가 + 버튼 흰색 통일 + 딤 70% |
| `GridViewController+SimilarPhoto.swift` | `showBadge(on:count:)` — 신규 뱃지 + 기존 뱃지 양쪽에서 C-1 트리거 호출 |
| `GridViewController.swift` | `viewDidAppear`에서 `hasTriggeredC1` 리셋 |
| `Log.swift` | CoachMarkC1, CoachMarkC2, CoachMarkManager 카테고리 추가 |

---

## 트리거 설계

### C-1 트리거 (그리드 뱃지)

```
showBadge(on:count:) 호출 시
  └── 이미 C가 표시된 적 있으면 스킵 (hasBeenShown)
  └── CoachMarkManager.isShowing이면 스킵
  └── 가시 영역 검증: 상하 12.5% 마진 제외한 중앙 75%에 셀이 완전히 들어와야 함
        (zone 밖 셀은 lock을 잡지 않아 다른 셀에 기회를 줌)
  └── 첫 번째 뱃지만 트리거 (hasTriggeredC1 associated object 플래그, zone 체크 후에 설정)
  └── 그리드가 최상위 화면인지 확인 (topViewController + presentedViewController)
  └── indexPath + assetID 캡처: collectionView.indexPath(for: cell) + asset.localIdentifier
  └── 즉시 터치 차단 (투명 UIView를 window에 addSubview)
  └── scrollToItem으로 셀 중앙 배치
  └── 0.4초 딜레이 (스크롤 완료 대기)
        └── 터치 차단 해제 (코치마크 오버레이가 대신 차단)
        └── 재검증: 셀 visible, 뱃지 존재, 다른 코치마크 없음, 그리드 최상위
        └── showSimilarBadgeCoachMark(cell:assetID:)
              ├── 셀 프레임 → 윈도우 좌표 변환
              └── CoachMarkOverlayView.showSimilarBadge(
                      highlightFrame:,
                      in: window,
                      onConfirm: { self.navigateToViewer(at: indexPath, assetID: assetID) }
                  )
                  // confirm 시점에 assetID로 indexPath를 재해석하여 PHChange 안전성 확보
```

**`showBadge` 접근 레벨 대응:**
`showBadge(on:count:)`는 `GridViewController+SimilarPhoto.swift` 내의 `private` 메서드.
별도 파일(`+CoachMarkC.swift`)에서 직접 호출 불가.
→ `showBadge` 마지막에 `triggerCoachMarkCIfNeeded(for: cell)` 1줄 추가.
  `triggerCoachMarkCIfNeeded`는 `+CoachMarkC.swift`에 `internal`로 정의.

**중복 방지:**
`hasTriggeredC1`을 associated object로 관리. `showBadge`는 visible 셀 전체에 대해 반복 호출되므로, 첫 호출에서 플래그를 true로 설정하여 이후 호출을 스킵.
리셋 조건:
- **`viewDidAppear`**: 그리드 복귀 시 (코치마크 미표시 중일 때) → false
- 타임아웃 시 → false
- **1초 딜레이 재검증 실패 시 → false** (셀이 사라지거나 뱃지가 없어진 경우, 다음 뱃지 표시 시 재트리거 가능하도록)

**기존 뱃지 재트리거:**
`showBadge(on:count:)`에서 기존 뱃지가 이미 있는 셀도 `triggerCoachMarkCIfNeeded(for:)` 호출.
(뷰어에서 그리드 복귀 시 뱃지는 이미 셀에 붙어있어 새 뱃지 생성 경로를 타지 않으므로 필요)

### `confirmTapped()` 분기 설계

현재 `confirmTapped()`은 바로 `dismiss()`를 호출. C에서는 dismiss 대신 탭 모션 → 네비게이션 시퀀스가 필요.

```swift
@objc private func confirmTapped() {
    switch coachMarkType {
    case .gridSwipeDelete, .viewerSwipeDelete:
        dismiss()                    // A/B: 즉시 dismiss + markAsShown
    case .similarPhoto:
        confirmButton.isEnabled = false  // ⚠️ 재진입 방지 (중복 탭 차단)
        startC_ConfirmSequence()     // C: 페이드아웃 → 탭 모션 → onConfirm 콜백
    }
}

private func startC_ConfirmSequence() {
    // ⚠️ 0.8초 이상 비동기 시퀀스 — 연타 시 이중 push/present 위험
    //    confirmButton.isEnabled = false로 재진입 차단 (위에서 설정)
    // 1. 확인 버튼 + 카피 페이드아웃 (0.2초)
    // 2. performTapMotion (0.6초)
    // 3. onConfirm?() 호출
    //    C-1: isWaitingForC2 = true → didSelectItemAt
    //    C-2: dismiss → triggerFaceComparison → present 성공 후 markAsShown()
}
```

C에서는 `dismiss()`의 `markAsShown()`이 호출되면 안 됨 (C-2 완료 시에만 호출).
→ `startC_ConfirmSequence()`가 `dismiss()` 대신 직접 시퀀스를 관리.

### C-1 → C-2 전환

```
[확인] 탭
  └── 확인 버튼 + 카피 페이드아웃 (0.2초)
  └── 손가락 탭 모션 on 셀 (0.6초)
        ├── 손가락 아이콘 나타남 → 셀 중앙으로 이동 → 누름(scale 0.95) → 떼기
        └── 셀 하이라이트 dim 효과 (눌림 피드백)
  └── onConfirm 콜백 실행
        └── collectionView(_:didSelectItemAt: indexPath) 직접 호출
              ⚠️ didSelectItemAt 안전성:
              - isSelectMode=true 시 뷰어 안 열림 → C-1 가드에서 !isSelectMode 체크
              - padding 가드: collectionView.indexPath(for:)로 얻은 값은 padding 포함 → 통과
              - fetchResult=nil: hasFinishedInitialDisplay 이후에만 트리거 → 통과
        └── 뷰어 전환 시작
  └── C-1 오버레이 유지 (fade out하지 않음, 전환 중 터치 차단 유지)
        ⚠️ push(iOS 26+)와 custom present(iOS 16~25) 모두
           window.addSubview 오버레이가 전환된 화면 위에 유지됨 확인 완료
```

### C-2 트리거 (뷰어 + 버튼)

```
ViewerViewController viewDidAppear
  ├── showSimilarPhotoOverlay()  ← 라인 364 (기존, + 버튼 표시)
  ├── showViewerSwipeDeleteCoachMarkIfNeeded()  ← 라인 371 (B 코치마크)
  │     └── guard !CoachMarkManager.shared.isWaitingForC2  ← 추가 필요
  │           (C-2 대기 중이면 B 스킵 — 충돌 방지)
  │
  └── C-2 트리거 (showSimilarPhotoOverlay 이후):
        └── CoachMarkManager.shared.isWaitingForC2 체크
              (C-1에서 설정한 플래그)
        └── + 버튼 표시 대기 (hasVisibleButtons == true)
              ⚠️ hasVisibleButtons는 faceButtons.append 직후 true
                 실제 alpha=1은 200ms 후. 0.3초 딜레이로 커버됨.
              ⚠️ 캐시 miss 시: showSimilarPhotoOverlay() → checkAndShowFaceButtons()가
                 async 체인 (SimilarityCache → Vision 분석 → showButtons). 수초 소요 가능.
                 C-1 뱃지가 표시된 사진이므로 캐시 hit 가능성 높지만,
                 메모리 압박으로 캐시 퇴거된 경우 miss. 5초 타임아웃으로 폴백.
        └── 0.3초 딜레이 (버튼 페이드인 완료 + 인식 시간)
        └── + 버튼 프레임 → 윈도우 좌표 변환
              (faceButtonOverlay.firstButtonFrameInWindow())
        └── 기존 C-1 오버레이를 C-2로 재구성
              (transitionToC2: dim path 변경 + 새 카피/확인 표시)
```

**B와 C-2 충돌 방지:**
`viewDidAppear`에서 `showViewerSwipeDeleteCoachMarkIfNeeded()` (B)와 C-2 트리거가 동시에 실행될 수 있음. B의 `hasBeenShown` 가드가 현재 테스트 모드로 주석 처리되어 있으므로, `isWaitingForC2` 가드를 B 트리거 상단에 추가하여 C-2 대기 중일 때 B를 스킵.

### C-2 완료

```
[확인] 탭
  └── 확인 버튼 + 카피 페이드아웃 (0.2초)
  └── 손가락 탭 모션 on + 버튼 (0.6초)
  └── 오버레이 dismiss + 터치 차단 해제
        ⚠️ dismiss를 먼저 해야 함!
           showFaceComparisonViewController는 .fullScreen present 사용.
           UIKit transition container가 window 최상단에 삽입되어
           window.addSubview 오버레이를 가림.
           → dismiss 후 present 순서가 필수.
  └── onConfirm 콜백 실행
        └── 첫 번째 + 버튼의 face 정보로 delegate 메서드 호출
        └── faceButtonOverlay(_:didTapFaceAtPersonIndex:face:)
        └── → showFaceComparisonViewController (.fullScreen present)
  └── present 성공 후 CoachMarkType.similarPhoto.markAsShown()
        ⚠️ markAsShown()은 반드시 present 성공 이후에 호출!
           present 실패 시(firstFace nil, present 충돌 등)
           markAsShown()이 먼저 찍히면 재노출이 영구 차단되어
           사용자가 C-2 안내를 영영 볼 수 없게 됨.
           → present completion 콜백에서 호출하거나,
             presentedViewController != nil 확인 후 호출.
```

---

## 레이아웃

### C-1 (그리드 뱃지 하이라이트)

```
┌──────────────────────────────┐
│  Dim 배경 (black 70%)        │
│  ┌────┐ ┌────┐ ┌────┐       │
│  │    │ │    │ │    │       │
│  ├────┤ ├────┤ ├────┤       │
│  │    │ │ ⊞3 │ │    │       │ ← evenOdd rounded rect 구멍 (margin 8pt)
│  ├────┤ ├────┤ ├────┤       │
│  │    │ │    │ │    │       │
│  └────┘ └────┘ └────┘       │
│                              │
│  "유사사진 정리기능이 표시된    │ ← 하이라이트 셀 아래
│   사진이에요                   │
│   각 사진의 얼굴을 비교해서    │
│   정리할 수 있어요"            │
│         [확인]               │ ← 흰색 버튼 (검정 텍스트)
└──────────────────────────────┘
```

### C-2 (뷰어 + 버튼 하이라이트)

```
┌──────────────────────────────┐
│  Dim 배경 (black 70%)        │
│                              │
│       ╭───╮                  │
│       │ + │ ← 원형 구멍      │ ← 버튼 크기 × 1.2 원형
│       ╰───╯                  │
│                              │
│  "+버튼을 눌러 얼굴비교화면    │ ← 원형 구멍 아래 기준
│   으로 이동하세요              │
│   인물이 여러 명이면 좌우로    │
│   넘겨볼 수 있어요"            │
│         [확인]               │ ← 흰색 버튼 (검정 텍스트)
└──────────────────────────────┘
```

**레이어 Z-순서 (아래→위):**
1. `dimLayer` — CAShapeLayer, black 70%, evenOdd (구멍으로 대상 하이라이트)
2. `fingerView` — 손가락 아이콘 ([확인] 후 탭 모션에서만 표시)
3. `messageLabel` + `confirmButton` — 안내 텍스트 + 흰색 버튼

C는 스냅샷이 필요 없음 — 하이라이트 대상(셀/버튼)은 구멍을 통해 실제 UI가 보임.

### iOS 26 전환 대응: `fillDimHole()`

C-1 탭 모션 완료 후 `onConfirm()` 호출 전에 `fillDimHole()`로 evenOdd 구멍을 제거.
iOS 26에서 push 전환 시 오버레이가 뷰 계층 최상단에 유지되어 C-1 구멍이 전환 중 노출되는 것을 방지.

---

## 탭 모션 애니메이션

### 공통: `performCTapMotion(at:completion:)`

[확인] 후 대상을 "탭한다"는 느낌을 주는 1회성 애니메이션.
**회전 없음** — 실제 손가락은 화면을 누를 때 기울어지지 않으므로, Scale + Y이동 + 그림자 변화 3가지로 "표면 밀착감"을 표현.

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| 등장 | 0.15초 | `.curveEaseOut` | fingerView alpha 0→1, 타겟 위치에 즉시 배치 (이동 없음) |
| 누르기 | 0.12초 | spring (damping 0.6) | scale 0.93 + center.y +2.5pt + 그림자 축소 (radius 6→2, offset 2→1, opacity 0.3→0.15) |
| 유지 | 0.05초 | — | 누른 상태 유지 |
| 떼기 | 0.2초 | spring (damping 0.7, velocity 2.0) | 원상 복원 + alpha 0 |

총 ~0.52초. A/B의 반복 시연과 달리 **1회성 탭** 모션.

**손가락 위치 보정**: `hand.point.up.fill`은 손가락 끝이 이미지 상단 좌측에 치우침.
- x: `targetCenter.x + fingerWidth * 0.08` (우측 보정)
- y: `targetCenter.y + fingerHeight * 0.4` (손가락 끝이 타겟 중앙을 가리키도록)

### 대상 눌림 피드백 (`showCTapPressFeedback`)

탭 모션 중 하이라이트 구멍 영역에 눌림 효과 (2중):
1. **스냅샷 축소**: 타겟 영역 스냅샷 → scale 0.93 축소 (spring) → 복원 + 페이드아웃 (실제 뷰를 건드리지 않음)
2. **흰색 플래시**: 반투명 흰색 오버레이 (alpha 0→1→0, 0.25초 keyframe)

---

## 터치 차단 연속성 설계

### 핵심 과제

C-1 dismiss → 화면 전환 → C-2 show 사이에 터치 차단이 끊기면 안 됨.

### 전략: 오버레이를 **제거하지 않고 재구성**

```
C-1 표시 중:
  overlay (window 위) = dim + 구멍(셀) + 카피 + 확인

[확인] 탭 후:
  overlay 유지 (터치 차단 계속)
  카피/확인 페이드아웃
  탭 모션 실행
  isWaitingForC2 = true        ← dismissCurrent() 차단 시작
  자동 네비게이션 트리거

화면 전환 중:
  overlay 유지 (dim만 남아 전환 덮음)
  ⚠️ GridViewController.viewWillDisappear → dismissCurrent() 호출됨!
     → isWaitingForC2 가드로 차단 (오버레이 파괴 방지)
  화면 전환 완료 대기 (viewDidAppear)

C-2 시작:
  기존 overlay에 새 dim path + 카피 + 확인을 재구성
  (removeFromSuperview 하지 않으므로 터치 차단 끊김 없음)

C-2 완료:
  isWaitingForC2 = false       ← dismissCurrent() 차단 해제
```

### `isWaitingForC2` 리셋 체크리스트

`isWaitingForC2 = true` 고착 시 앱 전체의 dismiss 경로가 차단되므로, **모든 종료 경로에서 반드시 `false`로 리셋**해야 한다.

| # | 경로 | 리셋 위치 |
|---|------|-----------|
| 1 | C-2 정상 완료 | `startC_ConfirmSequence()` 시퀀스 끝 (present 성공 후) |
| 2 | C-1→뷰어 전환 타임아웃 (3초) | 타임아웃 핸들러에서 `isWaitingForC2 = false` + 오버레이 dismiss |
| 3 | C-2 + 버튼 대기 타임아웃 (5초) | 타임아웃 핸들러에서 `isWaitingForC2 = false` + 오버레이 dismiss |
| 4 | C-2 present 실패 | `onConfirm` 콜백 실패 경로에서 `isWaitingForC2 = false` |
| 5 | 앱 백그라운드 진입 | `sceneDidEnterBackground` 또는 `applicationDidEnterBackground`에서 `isWaitingForC2 = false` + 오버레이 dismiss |

### `dismissCurrent()` 가드 — 오버레이 보호의 핵심

C-1 → C-2 전환 중 `dismissCurrent()`를 호출하는 코드가 **5곳** 존재:

| 호출 위치 | 발동 시점 | C 전환 중 도달 가능? |
|-----------|-----------|---------------------|
| `GridViewController.viewWillDisappear` (라인 365) | 뷰어로 전환 시 | **YES — 반드시 발동** |
| `ViewerViewController.viewWillDisappear` (라인 403) | 뷰어 닫힐 때 | NO (hitTest가 차단) |
| `BaseGridViewController.handleSwipeDeleteBegan` (라인 809) | 그리드 스와이프 시 | NO (hitTest가 차단) |
| `GridScroll.scrollDidBegin` (라인 104) | 그리드 스크롤 시 | NO (hitTest가 차단) |
| `SwipeDeleteHandler.swift` (라인 80) | 뷰어 스와이프 삭제 시작 시 | NO (hitTest가 차단) |

**GridVC.viewWillDisappear만이 실제 위협.** 뷰어 열림(push/present) 시 GridVC가 disappear하면서 반드시 발동.
이 한 줄이 오버레이를 파괴하고 markAsShown()까지 호출하므로, **`isWaitingForC2` 가드 없이는 C 전체가 실패.**

### CoachMarkManager 확장

```swift
final class CoachMarkManager {
    static let shared = CoachMarkManager()
    weak var currentOverlay: CoachMarkOverlayView?
    var isShowing: Bool { currentOverlay != nil }

    // C 전용 상태
    var isWaitingForC2: Bool = false       // C-1 완료 후 C-2 대기 중
    var c2OnConfirm: (() -> Void)?         // C-2 확인 후 실행할 콜백
    var safetyTimeoutWork: DispatchWorkItem?  // 안전 타임아웃 (C-2 성공 시 cancel)

    /// 현재 코치마크 dismiss
    /// ⚠️ C-1 → C-2 전환 중에는 dismiss 차단 (오버레이 보호)
    func dismissCurrent() {
        guard !isWaitingForC2 else { return }  // ← 핵심 가드
        currentOverlay?.dismiss()
    }

    /// C 상태 완전 리셋 (모든 실패/완료 경로에서 호출)
    func resetC2State() {
        isWaitingForC2 = false
        c2OnConfirm = nil
        safetyTimeoutWork?.cancel()
        safetyTimeoutWork = nil
    }
}
```

---

## 자동 네비게이션 구현

### C-1 → 뷰어 진입

```swift
// GridViewController+CoachMarkC.swift
func navigateToViewerForCoachMark(at indexPath: IndexPath) {
    // didSelectItemAt 직접 호출
    // 안전성 확인 완료:
    // - isSelectMode: C-1 가드에서 !isSelectMode 체크 → false 보장
    // - padding: collectionView.indexPath(for:)로 얻은 값은 padding 포함 → 통과
    // - fetchResult: 뱃지가 표시되려면 분석 완료 필수 → non-nil 보장
    collectionView(collectionView, didSelectItemAt: indexPath)
}
```

### C-2 → 얼굴 비교 진입

```swift
// ViewerViewController+SimilarPhoto.swift (또는 +CoachMark.swift)
func triggerFaceComparisonForCoachMark() {
    // 첫 번째 + 버튼의 face 정보로 delegate 메서드 직접 호출
    guard let overlay = faceButtonOverlay,
          let firstFace = overlay.firstVisibleFace else { return }
    faceButtonOverlay(overlay, didTapFaceAtPersonIndex: firstFace.personIndex, face: firstFace)
}
```

### FaceButtonOverlay 접근자 추가

```swift
// FaceButtonOverlay.swift에 추가
/// 첫 번째 표시 중인 + 버튼의 얼굴 정보 (코치마크 C-2 자동 탭용)
var firstVisibleFace: CachedFace? {
    faceButtons.first?.face
}

/// 첫 번째 표시 중인 + 버튼의 윈도우 좌표 프레임 (코치마크 C-2 하이라이트용)
func firstButtonFrameInWindow() -> CGRect? {
    guard let button = faceButtons.first else { return nil }
    return convert(button.frame, to: nil)
}
```

---

## 롤백 안전장치

자동 네비게이션은 실패 가능성이 있으므로 각 단계에서 타임아웃 + 폴백:

| 단계 | 실패 조건 | 대응 |
|------|-----------|------|
| C-1 트리거 | 뱃지 셀이 1초 내 사라짐 | 트리거 취소 (hasTriggeredC1=false), 다음 기회 대기 |
| C-1 → C-2 전환 | 확인 탭 후 10초 내 C-2 미전환 | DispatchWorkItem 타임아웃 → resetC2State + dismiss |
| C-2 + 버튼 대기 | hasVisibleButtons 5초 내 미달성 | 오버레이 dismiss, 차단 해제, C 전체 스킵 (markAsShown) |
| C-2 → 비교 화면 | present 실패 | 오버레이 dismiss, 차단 해제 |

**안전 타임아웃 구현**: `DispatchWorkItem`을 `CoachMarkManager.safetyTimeoutWork`에 저장.
- 생성 시점: C-1 **확인 버튼 탭 시점** (`onConfirm` 내부)
- Cancel 시점: C-2 전환 성공 시 (`ViewerViewController+CoachMarkC`에서 cancel)
- 발동 시: `resetC2State()` + overlay dismiss + `hasTriggeredC1 = false`

---

## CoachMarkType 확장

```swift
enum CoachMarkType: String {
    case gridSwipeDelete = "coachMark_gridSwipe"       // A
    case viewerSwipeDelete = "coachMark_viewerSwipe"   // B
    case similarPhoto = "coachMark_similarPhoto"       // C (C-1 + C-2 통합 플래그)
}
```

C-1, C-2를 하나의 플래그(`similarPhoto`)로 관리. 이유:
- C-1만 보고 C-2를 못 봤으면 기능 안내가 불완전
- 다음 기회에 C-1부터 다시 시작하는 게 일관적

---

## 상수 값

| 항목 | 값 | 비고 |
|------|-----|------|
| 딤 배경 알파 | 0.70 | A/B/C 공통 |
| C-1 하이라이트 구멍 | rounded rect, margin 8pt | 셀 크기 + 여유 |
| C-2 하이라이트 구멍 | **원형**, scale 1.2 | 버튼 중심 기준 원형 (버튼이 원형이므로) |
| 손가락 아이콘 | `hand.point.up.fill`, 48pt, white | A/B와 동일 |
| 확인 버튼 | 흰색 배경 + 검정 텍스트 | A/B/C 공통, iOS 버전 무관 |
| C-1 카피 | "유사사진 정리기능이 표시된 사진이에요\n각 사진의 얼굴을 비교해서 정리할 수 있어요" | 마침표 없음 |
| C-2 카피 | "+버튼을 눌러 얼굴비교화면으로 이동하세요\n인물이 여러 명이면 좌우로 넘겨볼 수 있어요" | 마침표 없음 |
| 버튼 텍스트 | "확인" | A/B와 동일 |
| 탭 모션 총 시간 | ~0.52초 | |
| 뱃지 안정 대기 | 즉시 (0초) | 뱃지 표시 즉시 터치 차단 + 스크롤 → 0.4초 후 코치마크 표시 |
| C-1 zone 검증 | 상하 12.5% 마진 (중앙 75%) | 셀이 완전히 zone 내에 있어야 트리거 |
| 안전 타임아웃 | 10초 (**확인 버튼 탭 시점부터**) | DispatchWorkItem, C-2 성공 시 cancel |
| C-2 + 버튼 대기 타임아웃 | 5.0초 | hasVisibleButtons 미달성 시 폴백 |

### 접근성: Reduce Motion 대응

```swift
if UIAccessibility.isReduceMotionEnabled {
    // 탭 모션 생략 — [확인] 탭 후 즉시 네비게이션
} else {
    performTapMotion(at: targetFrame) { navigateAction() }
}
```

---

## 트리거 가드 조건

C-1 (그리드):
- `!CoachMarkType.similarPhoto.hasBeenShown`
- `!CoachMarkManager.shared.isShowing`
- `!hasTriggeredC1` — 중복 트리거 방지 (associated object)
- `!isSelectMode` — didSelectItemAt의 isSelectMode 가드 통과 보장
- `!UIAccessibility.isVoiceOverRunning`
- `view.window != nil`
- `navigationController?.topViewController === self && presentedViewController == nil` — 뷰어 표시 중이면 스킵
- `hasFinishedInitialDisplay` — 초기 로딩 완료 후에만
- zone 검증 (상하 12.5% 마진, 중앙 75%)

B 코치마크 (C-2 충돌 방지 가드 추가):
- `!CoachMarkManager.shared.isWaitingForC2` — C-2 대기 중이면 B 스킵

C-2 (뷰어):
- `CoachMarkManager.shared.isWaitingForC2` (C-1에서 설정)
- `faceButtonOverlay?.hasVisibleButtons == true`
- `view.window != nil`
- `presentedViewController == nil`

---

## 검증 방법

1. 그리드에서 유사사진 뱃지 표시 → 즉시 C-1 코치마크 트리거 (터치 차단 + 스크롤 → 0.4초 후 표시)
2. C-1 표시 중 [확인] 외 모든 터치 차단
3. [확인] 탭 → 손가락 탭 모션 → 자동으로 뷰어 진입
4. 뷰어 전환 중에도 터치 차단 유지
5. + 버튼 표시 후 C-2 코치마크 표시
6. C-2 [확인] 탭 → 손가락 탭 모션 → 자동으로 얼굴 비교 화면 진입
7. 얼굴 비교 화면 진입 후 터치 차단 해제
8. 앱 재실행 시 C 코치마크 안 나타남 (UserDefaults)
9. VoiceOver 활성 시 C 코치마크 안 뜨는지
10. Reduce Motion → 탭 모션 생략, 즉시 네비게이션
11. 뱃지 셀이 스크롤로 사라지면 C-1 트리거 취소
12. + 버튼 미표시 시 (분석 실패 등) C-2 타임아웃 → 전체 스킵
13. C-1만 보고 앱 종료 → 재실행 시 C-1부터 다시 (통합 플래그)
14. A/B 코치마크 표시 중 → C 트리거 안 됨 (isShowing 가드)
15. C-2 대기 중 B 코치마크 → 스킵되는지 (isWaitingForC2 가드)
16. Select 모드 중 → C-1 트리거 안 됨 (isSelectMode 가드)
17. C-2 [확인] → 오버레이 dismiss 후 얼굴 비교 화면 present (순서 확인)

---

## 검토 이력

### 1차 검토 (2026-02-16)

코드 분석으로 6가지 이슈 발견, 문서 반영 완료:

| # | 이슈 | 위험도 | 대응 |
|---|------|--------|------|
| 1 | `.fullScreen` present 시 오버레이 가림 | 높음 | C-2 탭 모션 후 오버레이 dismiss → present 순서로 변경 |
| 2 | `showBadge(on:count:)`에서 indexPath 미보유 | 높음 | `collectionView.indexPath(for: cell)` 역추적 |
| 3 | 뱃지 중복 트리거 | 중간 | `hasTriggeredC1` associated object 플래그 |
| 4 | viewDidAppear에서 B와 C-2 충돌 | 중간 | B 트리거에 `isWaitingForC2` 가드 추가 |
| 5 | padding 계산 | 낮음 | 문제 없음 (indexPath(for:) 사용으로 자동 포함) |
| 6 | + 버튼 alpha 타이밍 | 낮음 | 기존 0.3초 딜레이로 충분 (200ms 애니메이션 + 100ms 여유) |

### 2차 검토 (2026-02-16, Claude)

코드 심층 분석으로 7가지 이슈 발견, 문서 반영 완료:

| # | 이슈 | 위험도 | 대응 |
|---|------|--------|------|
| 1 | `GridVC.viewWillDisappear` → `dismissCurrent()` 호출로 C-1 오버레이 강제 파괴 + markAsShown() | **치명** | `dismissCurrent()`에 `isWaitingForC2` 가드 추가. 터치 차단 연속성 섹션에 상세 기술 |
| 2 | `confirmTapped()`이 바로 `dismiss()` 호출 — C 모드 분기 미설계 | 높음 | `confirmTapped()` 분기 설계 섹션 추가 (A/B: dismiss, C: startC_ConfirmSequence) |
| 3 | `dismiss()`가 무조건 `markAsShown()` 호출 — C 전환 중 오발동 | 높음 | C는 `dismiss()` 경유하지 않고 `startC_ConfirmSequence()`가 직접 시퀀스 관리. C-2 완료 시에만 명시적 markAsShown() |
| 4 | `showBadge(on:count:)`가 `private` — 별도 파일 접근 불가 | 중간 | `showBadge` 끝에 `triggerCoachMarkCIfNeeded(for:)` 1줄 추가, 트리거 메서드는 `+CoachMarkC.swift`에 internal로 정의 |
| 5 | `hasTriggeredC1` 재검증 실패 시 리셋 경로 누락 | 중간 | 재검증 실패 시 `hasTriggeredC1 = false` 리셋 추가 |
| 6 | 파일 구조 표의 CoachMarkType case 명칭 불일치 (`.similarBadge`/`.faceButton` vs `.similarPhoto`) | 중간 | `.similarPhoto` 단일 case로 통일 |
| 7 | 캐시 miss 시 C-2 + 버튼 대기 2초 타임아웃 부족 가능성 | 낮음 | C-2 트리거 섹션에 캐시 miss 시나리오 주의사항 추가 |

### 3차 검토 (2026-02-16, GPT 교차검토)

GPT Codex 교차 검토 피드백 6건 반영:

| # | 이슈 | 위험도 | 대응 |
|---|------|--------|------|
| 1 | `markAsShown()` 순서 — present 실패 시 영구 스킵 | 높음 | C-2 완료 섹션: markAsShown()을 present 성공 후로 이동 |
| 2 | `confirmTapped()` 재진입 방지 미설계 | 높음 | confirmTapped() 분기에 `confirmButton.isEnabled = false` 추가 |
| 3 | C-2 대기 2초 타임아웃이 캐시 miss와 충돌 | 높음 | 2초 → 5초로 변경 (상수 테이블, 롤백 테이블, C-2 트리거 섹션) |
| 4 | `isWaitingForC2` 고착 시 dismiss 전체 차단 | 중간 | 리셋 체크리스트 5개 경로 추가 (정상 완료, 타임아웃 2종, present 실패, 앱 백그라운드) |
| 5 | `dismissCurrent()` 호출 지점 4곳 → 5곳 (SwipeDeleteHandler 누락) | 중간 | 호출 테이블에 `SwipeDeleteHandler.swift:80` 추가 |
| 6 | indexPath만 캡처 시 PHChange 오탐 가능성 | 중간 | C-1 트리거에 assetID 함께 캡처 주의사항 추가 |

### 4차: 구현 후 디버깅 + 폴리싱 (2026-02-17)

실기기 테스트에서 발견된 이슈 수정:

| # | 이슈 | 대응 |
|---|------|------|
| 1 | C-2 오버레이가 뷰어 뒤에 가려짐 | `transitionToC2()`에서 `superview?.bringSubviewToFront(self)` 추가 |
| 2 | C-1이 그리드 상단 끝 셀에서 레이아웃 깨짐 | zone 검증 추가 (상하 12.5% 마진, 중앙 75%) + scrollToItem으로 중앙 배치 |
| 3 | zone 밖 셀이 lock 선점 → zone 안 셀 차단 | zone 체크를 `hasTriggeredC1 = true` 전으로 이동 |
| 4 | 탭 모션 회전(-5°)이 부자연스러움 | 회전 제거 → Scale(0.93) + Y이동(+2.5pt) + 그림자 축소 조합 |
| 5 | 눌림 피드백 약함 | 스냅샷 기반 scale 0.93 축소 + 흰색 플래시 2중 피드백 |
| 6 | C-2가 10초 후 자동 사라짐 | 안전 타임아웃을 C-1 표시 시점 → 확인 탭 시점으로 이동 + DispatchWorkItem cancel 패턴 |
| 7 | iOS 26에서 C-1 구멍이 push 전환 중 노출 | `fillDimHole()`로 onConfirm 전 evenOdd 구멍 제거 |
| 8 | 1회 후 재트리거 안됨 | `hasTriggeredC1` viewDidAppear 리셋 + 기존 뱃지 경로에서도 트리거 |
| 9 | 손가락 위치가 + 버튼과 불일치 | x/y 오프셋 보정 (hand.point.up.fill 손가락 끝 기준) |
| 10 | C-2 하이라이트가 사각형 | 원형 구멍으로 변경 (scale 1.2) |
| 11 | 버튼/딤 스타일 불일치 | 버튼 흰색 통일, 딤 70%, 텍스트 마침표 제거 |
| 12 | 로그가 안 찍힘 | Log.swift에 CoachMarkC1/C2/Manager 카테고리 등록 |

### 5차: 터치 차단 강화 + UX 개선 (2026-02-17)

실기기 테스트에서 발견된 터치 차단 구멍 및 UX 이슈 수정:

| # | 이슈 | 대응 |
|---|------|------|
| 1 | C-1→뷰어 전환 시 iOS 26에서 암흑 화면 (dim overlay가 줌 전환을 가림) | `fillDimHole()`에 `CATransaction.setDisableActions(true)` + 탭 모션 후 `alpha=0.01` → `transitionToC2()`에서 `alpha=1.0` 복원 |
| 2 | C-1 재트리거 안 됨 (hasTriggeredC1 타이밍 락) | `retriggerForVisibleBadges()` 추가 — 재검증 실패 시 visible 뱃지 재스캔 |
| 3 | 뱃지 표시 전 뷰어 진입 시 뷰어 위에서 C-1 발동 | `triggerCoachMarkCIfNeeded`에 `topViewController === self && presentedViewController == nil` 가드 추가 (초기 + 재검증 3곳) |
| 4 | 1초 대기 중 사용자 스크롤/탭 가능 | 1초 딜레이 제거 → 뱃지 즉시 터치 차단(투명 blocker) + 스크롤 → 0.4초 후 코치마크 표시 |
| 5 | C-1→C-2 전환 중 뷰어 이미지 스와이프 가능 | `triggerCoachMarkC2IfNeeded()` 진입 즉시 `view.isUserInteractionEnabled = false`, C-2 overlay 준비 시 복원 |
| 6 | C-2 + 버튼이 Glass 반투명이라 잘 안 보임 | + 버튼 바깥에 흰색 테두리 링(39pt, borderWidth 2.5pt) 추가 — [확인] 시 함께 페이드아웃 |
| 7 | 테스트용 hasBeenShown 가드 해제 코드 잔존 | `guard !CoachMarkType.similarPhoto.hasBeenShown` 복원 |

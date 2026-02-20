# 삭제 시스템 안내 (E-1, E-2, E-3) 구현 계획

## 목표

사용자가 삭제 행동을 수행한 직후, PickPhoto의 2단계 삭제 구조(삭제대기함 → 비우기)를 점진적으로 이해시킨다. 코치마크(A~D)와 달리 기능 안내가 아닌 **행동 결과 피드백**이므로, 사용자 행동 직후에 표시되어 맥락이 명확하다.

---

## Context

온보딩 기획(`docs/onboarding/260211onboarding.md`) 섹션 6. 기존 코치마크(A~D)의 공용 구조(`CoachMarkOverlayView`, `CoachMarkManager`, `CoachMarkType`)를 확장하여 구현한다.

### 코치마크(A~D)와의 핵심 차이

| | 코치마크 (A~D) | 시스템 피드백 (E-1~3) |
|---|---|---|
| 목적 | 기능/제스처 안내 | 삭제 시스템 구조 이해 |
| 트리거 | 화면 진입/스크롤 | **사용자 행동 직후** |
| 하이라이트 | 셀/버튼 강조 | E-1: 탭바 탭 / E-2: 비우기 버튼 / E-3: 없음 |
| 애니메이션 | 제스처 시연 | E-1: 탭 가리키는 손가락 모션 / E-2: 순차 텍스트 + 하이라이트 전환 / E-3: 없음 |
| 레이아웃 | 딤 + 하이라이트 구멍 + 스냅샷 | **딤 + 텍스트 (카드 또는 인라인)** |
| [확인] 액션 | dismiss만 | **E-1: dismiss → 삭제대기함 이동**, E-2/E-3: dismiss |

---

## 파일 구조

### 신규 생성 (1개)

| 파일 | 역할 |
|------|------|
| `Shared/Components/CoachMarkOverlayView+SystemFeedback.swift` | E 전용 show 메서드 + 중앙 카드 레이아웃 |

CoachMarkOverlayView.swift가 이미 867줄이므로, E 전용 레이아웃/show 로직은 extension 파일로 분리한다. `CoachMarkManager`, `hitTest`, `dismiss` 등 기존 인프라를 그대로 재활용.

### 수정 (4개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `CoachMarkType`에 `.firstDeleteGuide`, `.firstEmpty` case 추가. `confirmTapped()`에 E 분기 추가 |
| `BaseGridViewController.swift` | `confirmSwipeDelete()` 내부 moveToTrash completion에서 시퀀스 트리거 추가 |
| `GridViewController.swift` | `viewerDidRequestDelete()` 내부 moveToTrash 직후 시퀀스 트리거 추가 |
| `TrashAlbumViewController.swift` | `performEmptyTrash()` 완료 후 E-3 트리거 추가 |

### 추가 트리거 삽입 대상 (선택적)

E-1은 "생애 첫 moveToTrash" 시에만 표시되므로, 모든 호출 지점을 커버할 필요는 없다. 사용자가 가장 먼저 접할 확률이 높은 2곳만 우선 커버:

| 호출 지점 | 파일:라인 | 우선순위 |
|-----------|----------|----------|
| 그리드 스와이프 삭제 | `BaseGridViewController.swift:912` | **필수** |
| 뷰어 삭제 (delegate 경유) | `GridViewController.swift:919` | **필수** |
| 선택 모드 일괄 삭제 | `GridSelectMode.swift:75` | 선택 |
| 앨범 뷰어 삭제 | `AlbumGridViewController.swift:389` | 선택 |
| 자동정리 확인 | `GridViewController+Cleanup.swift:433` | 선택 |
| 얼굴 비교 삭제 | `FaceComparisonViewController.swift:519` | 선택 |

---

## 레이아웃

E-1+E-2 시퀀스와 E-3 단독 팝업은 레이아웃 구조가 다르다.

### E-1+E-2 시퀀스 레이아웃 (전체 화면 딤 + 인라인 텍스트 + 동적 하이라이트)

시퀀스 진행 중 콘텐츠가 바뀌므로 카드가 아닌 **인라인 텍스트** 방식을 사용한다.

```
[Step 1]                          [Step 2~3]
┌──────────────────────────┐      ┌──────────────────────────┐
│      딤 (black 70%)      │      │      딤 (black 70%)      │
│                          │      │  ┌────────────────────┐  │
│  방금 삭제한 사진은       │      │  │ 비우기 (하이라이트) │  │ ← 딤 구멍
│  삭제대기함으로 이동됐어요│      │  └────────────────────┘  │
│  아래 탭을 눌러           │      │                          │
│  삭제대기함으로 가볼까요? │      │  보관함에서 삭제하면      │
│                          │      │  여기에 임시 보관돼요.    │ ← Step 2 텍스트
│       [확인]             │      │                          │
│                          │      │  [비우기]를 누르면        │
│  ☝️ (탭 가리키는 모션)    │      │  사진이 최종 삭제돼요.   │ ← Step 3 텍스트
│  ┌──┬──┬──┬──┐           │      │                          │
│  │  │  │🗑│  │ (탭바)    │      │       [확인]             │ ← Step 3에서 나타남
│  └──┴──┴──┴──┘           │      │                          │
└──────────────────────────┘      └──────────────────────────┘
```

**Step 1 텍스트 위치**: 화면 중앙 (centerY)에 배치. 하단에 탭바 손가락 모션.
**Step 2~3 텍스트 위치**: 비우기 버튼 하이라이트 아래에 배치. 하이라이트 구멍과 시각적으로 연결.

### E-3 레이아웃 (중앙 카드)

기존 코치마크의 하이라이트/스냅샷/손가락 없이, **딤 배경 + 중앙 카드**만.

```
┌──────────────────────────────────┐
│        딤 배경 (black 70%)       │
│                                  │
│   ┌────────────────────────┐     │
│   │                        │     │
│   │  ✓ 삭제 완료           │     │  ← 아이콘 + 타이틀 (17pt bold)
│   │                        │     │
│   │  애플 사진앱의          │     │  ← 본문 (15pt regular)
│   │  '최근 삭제된 항목'에서 │     │
│   │  30일 후 완전히         │     │
│   │  삭제됩니다.            │     │
│   │                        │     │
│   │       [확인]            │     │  ← 흰색 캡슐 버튼 (기존과 동일)
│   │                        │     │
│   └────────────────────────┘     │
│                                  │
└──────────────────────────────────┘
```

### 카드 스타일 (E-3)

| 항목 | 값 |
|------|-----|
| 카드 배경 | `UIColor.black.withAlphaComponent(0.85)` (반투명 dark) |
| 카드 cornerRadius | 20pt |
| 카드 width | 화면 너비 - 48pt (좌우 24pt 마진) |
| 카드 위치 | 화면 중앙 (centerY) |
| 내부 패딩 | 상하 24pt, 좌우 20pt |
| 타이틀 font | 17pt semibold, white |
| 본문 font | 15pt regular, white (alpha 0.9) |
| [확인] 버튼 | 120×44pt, white bg, black text, cornerRadius 22 (기존 동일) |
| 딤 배경 | black 70% (기존 코치마크와 동일) |

### 인라인 텍스트 스타일 (E-1+E-2 시퀀스)

| 항목 | 값 |
|------|-----|
| 텍스트 font | 17pt regular, white |
| 강조 키워드 | `NSAttributedString`으로 볼드 + 강조 컬러 |
| [확인] 버튼 | 120×44pt, white bg, black text, cornerRadius 22 (기존 동일) |
| 텍스트 정렬 | center |
| 텍스트 전환 | crossDissolve (0.25s) |
| 딤 배경 | black 70% (기존 코치마크와 동일) |

### 뷰 계층 (hitTest 호환)

**E-1+E-2 시퀀스:**
```
overlay (CoachMarkOverlayView, window 전체)
  ├── dimLayer (CAShapeLayer, Step별 구멍 전환)
  ├── messageLabel (인라인 텍스트, 화면 중앙 또는 하이라이트 아래)
  ├── secondaryLabel (Step 3 추가 텍스트)
  ├── confirmButton (Auto Layout, Step 1/3에서만 visible)
  └── fingerAnimationView (Step 1에서만 visible, 탭바 하단)
```

**E-3 카드:**
```
overlay (CoachMarkOverlayView, window 전체)
  ├── dimLayer (CAShapeLayer, 구멍 없음)
  └── cardView (UIView, corner 20, clip)
        ├── iconLabel (✓)
        ├── titleLabel (semibold)
        ├── messageLabel (attributed, numberOfLines 0)
        └── confirmButton (Auto Layout)
```

**confirmButton은 E-3에서 cardView의 subview로 배치한다.** 기존 hitTest의 `confirmButton.convert(point, from: self)`는 `UIView.convert(_:from:)` API가 뷰 계층을 따라가며 좌표를 변환하므로, confirmButton이 cardView 안에 있어도 정상 동작한다. cardView 안에 Auto Layout으로 배치하면 동적 높이/회전/다국어 대응이 자연스럽고, 수동 frame 동기화가 불필요하다.

**E-1+E-2 시퀀스에서 confirmButton은 overlay의 직접 subview로 배치한다.** Step별로 위치가 바뀌고 cardView가 없으므로 overlay에 직접 배치하는 것이 자연스럽다. hitTest는 동일하게 동작한다.

---

## E-1 → E-2: 삭제 시스템 안내 (연속 시퀀스)

E-1과 E-2는 **하나의 연속 시퀀스**로 실행된다. 단일 오버레이가 시작부터 끝까지 유지되며, 모든 입력을 차단한다. 중간에 사용자가 이탈할 수 없다.

### 트리거

```
사용자의 생애 첫 moveToTrash() 호출 완료 직후
  → guard: !CoachMarkType.firstDeleteGuide.hasBeenShown
  → guard: !CoachMarkManager.shared.isShowing
  → guard: !UIAccessibility.isVoiceOverRunning
  → guard: view.window != nil
  → showDeleteSystemGuide(in: window)
```

### 전체 시퀀스

```
[Step 1] (0.0s) 딤 + 텍스트 + 탭바 손가락 모션 + [확인]
  "방금 삭제한 사진은 삭제대기함으로 이동됐어요.
   아래 탭을 눌러 삭제대기함으로 가볼까요?"
  (탭바 삭제대기함 탭을 가리키는 손가락 모션)
          [확인]

       ── [확인] 탭 ──

  오버레이 유지한 채 탭 전환 (selectedIndex = 2)
  iOS 16~25: 뷰어 모달 dismiss(animated: false) 후 탭 전환
  텍스트 페이드아웃 → 다음 텍스트 페이드인

[Step 2] (+0.3s) 텍스트 전환
  "보관함에서 삭제하면 여기에 임시 보관돼요."

[Step 3] (+1.3s) 비우기 버튼 하이라이트 + 텍스트 추가 + [확인] 나타남
  "[비우기]를 누르면 사진이 최종 삭제돼요."
          [확인]

       ── [확인] 탭 ──

  오버레이 dismiss
```

- **오버레이가 처음부터 끝까지 유지** → 입력 차단 갭 없음
- 중간 탭 전환은 오버레이 아래에서 일어남
- [확인] 2번으로 전체 시퀀스 완료
- Step 1의 [확인] 전까지: [확인] 버튼만 터치 가능
- Step 1 [확인] ~ Step 3 [확인] 나타나기 전: 모든 터치 차단 (버튼 없음)
- Step 3의 [확인] 나타난 후: [확인] 버튼만 터치 가능

### CoachMarkType

E-1과 E-2가 하나의 시퀀스이므로 **단일 CoachMarkType**으로 관리한다.

```swift
case firstDeleteGuide = "coachMark_firstDeleteGuide"  // E-1+E-2 통합
```

`markAsShown()`은 최종 dismiss 시 1회만 호출. Step 1 [확인] 시점에는 마킹하지 않는다 (중간 이탈 불가이므로 불필요).

### [확인] 액션 — Step 1

오버레이를 dismiss하지 않고, 탭 전환 + 텍스트 전환만 실행한다.

```swift
case .firstDeleteGuide:
    if currentStep == 1 {
        // Step 1 → Step 2: 오버레이 유지, 탭 전환 + 텍스트 전환
        transitionToStep2()
    } else {
        // Step 3: 최종 dismiss
        dismiss()
    }
```

#### 탭 전환 (transitionToStep2)

```swift
private func transitionToStep2() {
    guard let tabBar = findTabBarController() else { return }

    // 텍스트 페이드아웃 + 손가락 모션 중단
    // [확인] 버튼 숨김
    hideStep1Content()

    // 탭 전환 + 후속 스텝 스케줄링을 하나의 블록으로 묶음
    let switchTabAndSchedule = { [weak self] in
        tabBar.selectedIndex = 2
        tabBar.floatingOverlay?.selectedTabIndex = 2

        // 탭 전환 완료 후 0.3초 뒤 Step 2 텍스트 페이드인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self?.showStep2Content()  // "보관함에서 삭제하면 여기에 임시 보관돼요."
        }

        // 탭 전환 완료 후 1.3초 뒤 Step 3: 비우기 하이라이트 + 두 번째 텍스트 + [확인]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            self?.showStep3Content()  // 비우기 버튼 하이라이트 + "[비우기]를 누르면..." + [확인]
            self?.currentStep = 3
        }
    }

    // iOS 16~25: 뷰어 모달이 떠 있으면 먼저 dismiss 후 스케줄링
    if tabBar.presentedViewController != nil {
        tabBar.dismiss(animated: false) { switchTabAndSchedule() }
    } else {
        switchTabAndSchedule()
    }
}
```

**핵심: `floatingOverlay?.selectedTabIndex = 2` 동기화를 반드시 포함한다.** 기존 `navigateToTrash()` 패턴(`GridViewController+Cleanup.swift:200-205`)과 동일.

#### TabBarController 참조

```swift
private func findTabBarController() -> TabBarController? {
    guard let window = self.window ?? self.superview?.window else { return nil }
    return window.rootViewController as? TabBarController
}
```

### Step 1: 탭바 탭 frame 접근 (손가락 모션 대상)

Step 1에서 삭제대기함 탭을 가리키는 손가락 모션을 구현하려면 해당 탭의 window 좌표가 필요하다.

| iOS 버전 | 탭바 종류 | 접근 방법 |
|----------|-----------|-----------|
| 16~25 | `FloatingTabBar` (커스텀) | `tabBar.floatingOverlay?.tabButtonFrame(at: 2)` 공개 메서드 추가 |
| 26+ | 시스템 `UITabBar` | `tabBar.tabBar.subviews`에서 3번째 탭 영역 추출 (private API 의존 회피: `UITabBar`의 `items`와 `convert` 조합) |

**구현 방향:**
- `FloatingOverlayContainer`에 `tabButtonFrame(at index: Int) -> CGRect?` 메서드 추가
- iOS 26+: `UITabBarController.tabBar`의 subviews에서 탭 index에 해당하는 control 탐색 → `convert(_:to: window)` 변환
- frame 획득 실패 시: 손가락 모션 생략, 텍스트만 표시 (graceful degradation)

### Step 3: 비우기 버튼 frame 접근 (하이라이트 대상)

Step 3에서 비우기 버튼을 하이라이트(딤 구멍)하려면 버튼의 window 좌표가 필요하다.

| iOS 버전 | 비우기 버튼 위치 | 현재 접근성 | 해결 방법 |
|----------|-----------------|-------------|-----------|
| 16~25 | `FloatingTitleBar.secondRightButton` (`GlassTextButton`) | **private** — frame 접근 불가 | `secondRightButtonFrameInWindow() -> CGRect?` 공개 메서드 추가 |
| 26+ | `navigationItem.rightBarButtonItems`의 `UIBarButtonItem` | `customView`가 nil이면 frame 직접 접근 불가 | `UIBarButtonItem` → `value(forKey: "view")` 로 내부 view 획득 후 `convert` |

**구현 방향:**

```swift
// FloatingTitleBar에 추가 (iOS 16~25)
func secondRightButtonFrameInWindow() -> CGRect? {
    guard !secondRightButton.isHidden,
          let window = secondRightButton.window else { return nil }
    return secondRightButton.convert(secondRightButton.bounds, to: window)
}
```

```swift
// TrashAlbumViewController에서 (iOS 26+)
func emptyButtonFrameInWindow() -> CGRect? {
    guard let barButtonItem = navigationItem.rightBarButtonItems?.first(where: { /* 비우기 버튼 식별 */ }),
          let itemView = barButtonItem.value(forKey: "view") as? UIView,
          let window = itemView.window else { return nil }
    return itemView.convert(itemView.bounds, to: window)
}
```

- frame 획득 실패 시: 하이라이트 구멍 생략, 텍스트만 표시 (graceful degradation)
- `TrashAlbumViewController`에 `emptyButtonFrame(in window: UIWindow) -> CGRect?` 공개 메서드를 추가하여 iOS 버전 분기를 내부에서 처리

### 트리거 삽입 위치 상세

moveToTrash는 **2가지 시그니처**가 있으므로, 트리거 삽입 방식이 다르다:

**그리드 스와이프 삭제 — completion handler 버전 (`BaseGridViewController.swift:912`)**

```swift
self.trashStore.moveToTrash(assetID) { [weak self] result in
    self?.handleSwipeResult(result, cell: cell)
    if case .success = result {
        self?.showDeleteSystemGuideIfNeeded()
    }
}
```

**뷰어 삭제 — 동기 배열 버전 (`GridViewController.swift:919`)**

```swift
trashStore.moveToTrash(assetIDs: [assetID])
// ... 기존 코드 ...
showDeleteSystemGuideIfNeeded()
```

### 뷰어에서 삭제 시 시나리오

오버레이가 유지된 채로 탭 전환이 이루어지므로, 뷰어 모달 처리가 단순해진다:

**iOS 26+ (push 방식)**:
- 뷰어가 네비게이션 push 상태 → 오버레이가 window 위에 덮여 있음
- Step 1 [확인] → 오버레이 아래에서 `selectedIndex = 2` → 삭제대기함이 보관함+뷰어를 대체
- 뷰어는 탭 0 스택에 남아 있음 → 나중에 탭 0으로 돌아가면 뷰어 복귀

**iOS 16~25 (`.custom` 모달 방식)**:
- 뷰어가 `.custom` 모달 → 오버레이가 window 위에 덮여 있음
- Step 1 [확인] → `tabBar.dismiss(animated: false)` → 뷰어 모달 즉시 닫힘 → `selectedIndex = 2`
- 오버레이는 window에 붙어있으므로 영향 없음 (모달 dismiss와 무관)

**오버레이 유지 방식이므로 화면 전환 중 깜빡임이나 입력 갭이 없다.**

---

## E-3: 첫 비우기 완료 안내

### 트리거

```
performEmptyTrash() 또는 permanentlyDelete() 첫 성공 완료 직후
  → guard: !CoachMarkType.firstEmpty.hasBeenShown
  → guard: !CoachMarkManager.shared.isShowing
  → guard: !UIAccessibility.isVoiceOverRunning
  → guard: view.window != nil
  → showFirstEmptyFeedback(in: window)
```

emptyTrash()는 내부에서 iOS 시스템 팝업을 띄우고, 사용자 확인 후 await가 해제된다. 사용자가 시스템 팝업에서 **취소**하면 catch로 빠져 E-3가 표시되지 않는다 (의도된 동작).

### 카피

```
✓ 삭제 완료

애플 사진앱의 '최근 삭제된 항목'에서
30일 후 완전히 삭제됩니다.

        [확인]
```

### [확인] 액션

dismiss만.

### 트리거 삽입 위치

```swift
// TrashAlbumViewController.swift performEmptyTrash() (라인 546)
private func performEmptyTrash() {
    AnalyticsService.shared.countTrashPermanentDelete()
    Task {
        do {
            try await trashStore.emptyTrash()
            showFirstEmptyFeedbackIfNeeded()  // ← E-3: 성공 시에만
        } catch {
            // 취소 또는 오류 시 조용히 무시 → E-3 안 뜸
        }
    }
}
```

개별 완전삭제(`viewerDidRequestPermanentDelete:668`, `trashDeleteSelectedTapped:173`)에서도 동일하게 try await 성공 후 트리거 추가.

---

## 구현 코드 구조

### CoachMarkType 확장

```swift
enum CoachMarkType: String {
    case gridSwipeDelete = "coachMark_gridSwipe"       // A
    case viewerSwipeDelete = "coachMark_viewerSwipe"   // B
    case similarPhoto = "coachMark_similarPhoto"       // C
    case firstDeleteGuide = "coachMark_firstDeleteGuide"  // E-1+E-2 통합 (신규)
    case firstEmpty = "coachMark_firstEmpty"               // E-3 (신규)
}
```

### confirmTapped() 분기 추가

```swift
@objc func confirmTapped() {
    switch coachMarkType {
    case .gridSwipeDelete, .viewerSwipeDelete:
        dismiss()
    case .similarPhoto:
        confirmButton.isEnabled = false
        startC_ConfirmSequence()
    case .firstDeleteGuide:
        if currentStep == 1 {
            // Step 1 → Step 2,3: 오버레이 유지, 탭 전환 + 순차 텍스트
            transitionToStep2()
        } else {
            // Step 3: 최종 dismiss
            dismiss()
        }
    case .firstEmpty:
        // E-3: dismiss만
        dismiss()
    }
}
```

### 트리거 메서드

```swift
// BaseGridViewController 또는 GridViewController extension
func showDeleteSystemGuideIfNeeded() {
    guard !CoachMarkType.firstDeleteGuide.hasBeenShown else { return }
    guard !CoachMarkManager.shared.isShowing else { return }
    guard !UIAccessibility.isVoiceOverRunning else { return }
    guard let window = view.window else { return }

    CoachMarkOverlayView.showDeleteSystemGuide(in: window)
}
```

### CoachMarkOverlayView+SystemFeedback.swift (신규)

E-1+E-2 통합 시퀀스와 E-3 단독 피드백 모두 이 파일에 구현한다.

```swift
extension CoachMarkOverlayView {

    /// 현재 시퀀스 단계 (E-1+E-2 통합용)
    /// Step 1: E-1 (삭제 안내 + 탭 가리키기)
    /// Step 3: E-2 Phase 2 (비우기 하이라이트 + [확인])
    var currentStep: Int  // associated object로 관리

    /// E-1+E-2 통합: 삭제 시스템 안내 시퀀스 시작
    static func showDeleteSystemGuide(in window: UIWindow) {
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .firstDeleteGuide
        overlay.currentStep = 1
        overlay.alpha = 0

        overlay.updateDimPath()  // 딤 배경
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // Step 1 콘텐츠: 텍스트 + 탭바 손가락 모션 + [확인]
        overlay.showStep1Content()

        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }

    /// E-3: 첫 비우기 완료 안내 (단독 팝업)
    static func showFirstEmptyFeedback(in window: UIWindow) {
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .firstEmpty
        overlay.alpha = 0

        overlay.updateDimPath()
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 중앙 카드: ✓ 삭제 완료 + 본문 + [확인]
        let card = overlay.buildFeedbackCard(...)
        overlay.addSubview(card)
        // ... Auto Layout 중앙 배치 ...

        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }
}
```

### updateDimPath 확장 — 동적 하이라이트

기존 `updateDimPath()`는 `.gridSwipeDelete`와 `.similarPhoto`만 하이라이트 구멍을 만든다. E-1+E-2 시퀀스에서는 Step별로 하이라이트 대상이 바뀌므로 동적 업데이트가 필요하다.

| Step | 하이라이트 대상 | highlightFrame |
|------|----------------|----------------|
| Step 1 | 없음 (전체 딤) | `.zero` |
| Step 2 | 없음 (전체 딤) | `.zero` |
| Step 3 | 비우기 버튼 | `emptyButtonFrame` (위 섹션 참조) |

```swift
// updateDimPath() 확장 — CoachMarkOverlayView.swift 또는 extension
func updateDimPath() {
    let fullPath = UIBezierPath(rect: bounds)

    // A, C: 셀/버튼 하이라이트
    if coachMarkType == .gridSwipeDelete || coachMarkType == .similarPhoto {
        let margin: CGFloat = 8
        let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
        let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: 8)
        fullPath.append(holePath)
    }

    // E-1+E-2 시퀀스: Step 3에서 비우기 버튼 하이라이트
    if coachMarkType == .firstDeleteGuide && highlightFrame != .zero {
        let margin: CGFloat = 6
        let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
        let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: 10)
        fullPath.append(holePath)
    }

    dimLayer.path = fullPath.cgPath
}
```

**Step 전환 시 하이라이트 업데이트:**

```swift
// showStep3Content() 내부
func showStep3Content() {
    // 비우기 버튼 frame 획득
    guard let trashVC = findTrashAlbumViewController(),
          let buttonFrame = trashVC.emptyButtonFrame(in: self.window!) else {
        // frame 획득 실패 → 하이라이트 없이 텍스트만 표시
        showStep3TextOnly()
        return
    }

    highlightFrame = buttonFrame
    updateDimPath()  // 딤 구멍 갱신 (애니메이션 가능)

    // 텍스트 + [확인] 나타남
    // ...
}
```

`highlightFrame` 변경 + `updateDimPath()` 호출로 딤 구멍이 동적으로 전환된다. CAShapeLayer의 path 변경은 기본적으로 즉시 반영되므로, 필요시 `CABasicAnimation`으로 구멍 등장 애니메이션 추가 가능.

---

## dismiss 동작

기존 `dismiss()` 메서드를 그대로 재활용한다. E-1+E-2 통합 시퀀스에서는 Step 1 [확인] 시 dismiss를 호출하지 않고 `transitionToStep2()`를 실행하며, Step 3 [확인] 시에만 `dismiss()`를 호출한다.

`markAsShown()`은 dismiss 시 자동 호출되므로, 시퀀스가 완전히 끝난 후 1회만 마킹된다.

---

## VoiceOver 대응

기존 코치마크(A~D)는 제스처 기능이 VoiceOver에서 비활성화되므로 `!isVoiceOverRunning` 가드로 표시하지 않는다.

E는 삭제 행동의 피드백이므로 VoiceOver 사용자에게도 필요하지만, 현재 CoachMarkOverlayView에 접근성 대응(accessibilityLabel, UIAccessibilityPost 등)이 구현되어 있지 않다.

**1차 구현: VoiceOver 가드 유지** (A~D와 동일). VoiceOver 사용자에게 카드 내용이 올바르게 읽히지 않을 수 있으므로, 접근성 대응 없이 표시하는 것보다 표시하지 않는 것이 안전하다.

**TODO: 후속 작업으로 CoachMarkOverlayView 전체에 접근성 대응 추가 시, E의 VoiceOver 가드를 제거.**

---

## UserDefaults 키

| 키 | 용도 |
|----|------|
| `coachMark_firstDeleteGuide` | E-1+E-2 통합 시퀀스 완료 |
| `coachMark_firstEmpty` | E-3 표시 완료 |

---

## 검증 방법

### E-1+E-2 통합 시퀀스

1. 그리드에서 첫 스와이프 삭제 → Step 1 표시 (텍스트 + 탭바 손가락 모션 + [확인])
2. Step 1 표시 중 모든 터치 차단 ([확인]만 가능)
3. Step 1 [확인] → 오버레이 유지 + 삭제대기함 탭으로 전환
4. (iOS 26+) 탭 전환 정상 동작, 탭 0 돌아가면 뷰어 유지
5. (iOS 16~25) 뷰어 모달 dismiss → 탭 전환 + floatingOverlay 동기화
6. Step 2 텍스트 페이드인 ("보관함에서 삭제하면 여기에 임시 보관돼요.")
7. Step 3: 비우기 버튼 하이라이트 + 텍스트 추가 + [확인] 나타남
8. Step 2~3 전환 중 모든 터치 차단 ([확인] 나타나기 전)
9. Step 3 [확인] → 오버레이 dismiss, 삭제대기함 화면 유지
10. 두 번째 삭제 → 시퀀스 안 뜨는지 (1회성)
11. 뷰어에서 삭제 → 동일하게 시퀀스 시작되는지
12. 코치마크 A 표시 중 삭제 시 → 시퀀스 안 뜨는지 (isShowing 가드)
13. 스와이프 삭제 실패(저장 에러) → 시퀀스 안 뜨는지 (success 분기)

### E-3

14. 첫 비우기 완료 → 중앙 카드 팝업 표시
15. [확인] 탭 → dismiss
16. 두 번째 비우기 → 팝업 안 뜨는지
17. 개별 완전삭제 시에도 E-3 트리거되는지 (선택적)
18. 비우기 취소(시스템 팝업에서 거부) → 팝업 안 뜨는지

### 공통

19. VoiceOver 활성 → 시퀀스/E-3 모두 안 뜨는지
20. UserDefaults 키 삭제 후 다시 표시되는지
21. 앱 재실행 후 표시되지 않는지 (1회성 확인)
22. 시퀀스 전체 동안 (Step 1 ~ Step 3 dismiss) 사용자 이탈 불가능한지

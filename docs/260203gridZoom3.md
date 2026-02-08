# iOS 26 뷰어 시스템 UI 전환 조사

## 해결해야 할 문제

### 최종 목표

**iOS 26에서 아래로 드래그 dismiss를 유지하면서 시스템 UI(네비게이션 바/툴바)를 사용하도록 만들기**

### 왜 현재 안 되는가

```
뷰어가 Modal로 열림
  → navigationController == nil
  → useSystemUI = false
  → 커스텀 GlassIconButton 사용 (시스템 백버튼/툴바 미사용)
```

### Modal을 쓰는 이유

커스텀 줌 트랜지션의 Interactive Dismiss(아래로 드래그 닫기)가 Push에서 실패했기 때문.
Modal의 `shouldRemovePresentersView = false`로 그리드를 containerView에 유지하여 해결함.

### Push에서 실패한 이유 (260129gridZoom1.md)

| 시도 | 방식 | 실패 원인 |
|-----|------|----------|
| 1차 | `UIPercentDrivenInteractiveTransition` + ZoomAnimator | `UIPercentDrivenInteractiveTransition`은 CA 레이어 기반 애니메이션만 가로챔. ZoomAnimator는 스냅샷 UIImageView 기반이라 **호환 안 됨** → 전체 애니메이션이 즉시 실행됨 |
| 2차 | Navigation transition 없이 직접 transform 제어 | `popViewController` 호출 없이 Pan에서 직접 imageView.transform 제어. 그러나 **Navigation push 후 그리드가 window에서 제거**되어 좌표 변환/스냅샷 모두 실패 |

### 근본 원인 요약

**Push에서 Interactive Dismiss를 하려면 두 조건이 동시에 필요:**
1. 그리드(toView)가 window에 존재해야 함 (좌표 변환/스냅샷용)
2. 스냅샷 기반 커스텀 애니메이션을 progress로 제어할 수 있어야 함

- 1차 시도: 조건 1은 충족 (containerView에 양쪽 뷰 존재), 조건 2 실패
- 2차 시도: 조건 2는 충족 (직접 transform 제어), 조건 1 실패

### 기존에 검토했으나 부적합한 방법

| 방법 | 부적합 이유 |
|------|-----------|
| `UIViewControllerInteractiveTransitioning` 직접 구현 | `popViewController(animated: true)` 호출 시 `NavigationControllerDelegate`의 `animationControllerFor:`가 ZoomAnimator를 반환 → 1차 시도와 동일한 문제 발생 |
| Custom Container VC (UINavigationController 대체) | Navigation이 아니므로 iOS 26 시스템 네비게이션 바/툴바 사용 불가 → 목표 미달성 |

---

## 해결 방안 조사 결과

목표 달성 조건: **iOS 26에서 Push 사용 + 아래 드래그 dismiss + 시스템 UI**

### 방안 A: ZoomAnimator를 UIViewPropertyAnimator 기반으로 재작성

현재 ZoomAnimator는 `UIView.animate` + 스냅샷 방식이라 `UIPercentDrivenInteractiveTransition`과 호환 안 됨.
이를 `UIViewPropertyAnimator` 기반으로 변경하면 interactive transition과 호환 가능.

**필요한 작업:**
1. ZoomAnimator에 `interruptibleAnimator(using:)` 구현
2. 내부에서 `UIViewPropertyAnimator` 생성 및 반환
3. 동일한 animator 인스턴스를 캐싱하여 여러 번 호출에도 같은 객체 반환
4. `UIPercentDrivenInteractiveTransition`이 해당 animator의 `fractionComplete`를 제어

**동작 원리:**
```
Pan 시작 → popViewController(animated: true)
  → NavigationControllerDelegate → animationControllerFor: → ZoomAnimator 반환
  → NavigationControllerDelegate → interactionControllerFor: → UIPercentDrivenInteractiveTransition 반환
  → 시스템이 interruptibleAnimator(using:) 호출 → UIViewPropertyAnimator 반환
  → UIPercentDrivenInteractiveTransition이 animator.fractionComplete 직접 제어
  → Pan changed → update(progress)
  → Pan ended → finish() 또는 cancel()
```

**왜 이전 실패를 해결하는가:**
- 1차 실패 원인: ZoomAnimator가 `UIView.animate`(CA 레이어) 기반이 아닌 스냅샷 직접 조작이라 percent-driven이 가로챌 수 없었음
- `interruptibleAnimator(using:)`로 `UIViewPropertyAnimator`를 반환하면 시스템이 해당 animator를 통해 progress 제어 가능
- containerView에 양쪽 뷰가 존재하므로 2차 실패 원인도 해결

**장점:** 전 iOS 버전(16+)에서 동작, Push 기반이므로 시스템 UI 자동 사용
**단점:** ZoomAnimator 재작성 필요, 스냅샷 기반 애니메이션을 UIViewPropertyAnimator 블록 안에서 구현하는 것이 가능한지 검증 필요

**검증 필요 사항:**
- UIViewPropertyAnimator의 addAnimations 블록 안에서 스냅샷 UIImageView의 frame/transform 변경이 percent-driven과 호환되는지
- 스냅샷 생성 타이밍 (animator 생성 시점 vs 애니메이션 시작 시점)

**참고:**
- WWDC 2016 - Advances in UIKit Animations and Transitions: https://asciiwwdc.com/2016/sessions/216
- InteractiveNavigationControllerTransition (GitHub): https://github.com/el-starikova/InteractiveNavigationControllerTransition-UIViewPropertyAnimator
- Christian Selig 블로그: https://christianselig.com/2021/02/interruptible-view-controller-transitions/

---

### 방안 B: iOS 26 전용으로 `preferredTransition = .zoom` 복원 (검증 필요)

iOS 26 전용 분기로 시스템 `.zoom`을 다시 사용하면 interactive dismiss를 자동 제공.

**⚠️ 이전 품질 문제 이력 (docs/bak/260113gridZoom.md):**
- iOS 18에서 `.zoom` 사용 시 배경 페이드인 타이밍 불일치 (alongside: 0.34초 vs 실제 zoom: ~0.9초)
- SDK의 `.zoom`은 이미지와 배경을 분리 제어 불가 (Apple Photos는 내부 API 사용 추정)
- 8차례 수정 시도 후 품질 미달로 원복 → 커스텀 ZoomAnimator 구현으로 대체
- **iOS 26에서 이 API가 개선되었는지 검증 필요. 미개선 시 본 방안 부적합.**

**구현:**
```swift
if #available(iOS 26.0, *) {
    // Push + 시스템 zoom transition (interactive dismiss 자동)
    viewerVC.preferredTransition = .zoom(sourceViewProvider: { context in
        return self.zoomSourceView(for: index)
    })
    navigationController?.pushViewController(viewerVC, animated: true)
} else {
    // iOS 16~25: 현재 Modal 방식 유지
    present(viewerVC, animated: true)
}
```

**장점:** 코드 최소, 시스템 UI 자동 사용, interactive dismiss 자동 (핀치/스와이프/엣지)
**단점:** iOS 16~25는 여전히 Modal (커스텀 UI), 두 가지 코드 경로 유지, 커스텀 제스처 제어 불가

**참고:**
- Douglas Hill - Zoom Transitions: https://douglashill.co/zoom-transitions/
- Apple - Enhancing your app with fluid transitions: https://developer.apple.com/documentation/uikit/enhancing-your-app-with-fluid-transitions
- WWDC24 - Enhance your UI animations and transitions: https://developer.apple.com/videos/play/wwdc2024/10145/

---

## 방안 비교

| | 방안 A (ZoomAnimator 재작성) | 방안 B (iOS 26 전용 .zoom) |
|---|---|---|
| **iOS 26 시스템 UI** | O | O |
| **아래 드래그 dismiss** | O | O (시스템 자동) |
| **iOS 16~25 호환** | O (전 버전 Push) | X (Modal 유지) |
| **작업량** | 큼 (ZoomAnimator 재작성) | 작음 (분기 추가) |
| **코드 경로** | 단일 | 이중 (Push/Modal) |
| **리스크** | UIViewPropertyAnimator + 스냅샷 호환성 검증 필요 | iOS 18에서 품질 문제 이력 있음. iOS 26에서 개선 여부 검증 필요 |

### 검증 순서

1. **방안 B 먼저 검증** (작업량 적음) → iOS 26에서 `.zoom` 품질이 기본 사진 앱 수준인지 확인
2. 방안 B 품질 미달 시 → **방안 A 진행**

---

## 방안 B 적용 계획

### 현재 코드 상태

ViewerViewController에는 이미 Push를 대비한 시스템 UI 코드가 작성되어 있으나 미사용 상태.

**이미 준비된 것 (iOS 26 분기 있음):**
- `useSystemUI` → `navigationController != nil`이면 true (Push면 자동 활성화)
- `setupSystemUIIfNeeded()` → Push일 때만 실행
- `setupSystemNavigationBar()` / `setupSystemToolbar()` → `@available(iOS 26.0, *)` 마킹됨
- `updateToolbarForCurrentPhoto()` → useSystemUI 분기 존재

**변경 필요한 것 (iOS 26 분기 없음):**
- 3개 그리드 VC의 뷰어 열기: `present()` → `pushViewController()` 분기 추가
- `ZoomTransitionController`: Modal 전용 (`UIViewControllerTransitioningDelegate`) → Push용 처리 필요
- `dismissWithFadeOut()` / `handleDismissPan`: `dismiss()` 하드코딩 → `popViewController()` 분기
- `setupBackButton()`: iOS 26 Push에서는 시스템 백버튼 자동 → 호출 방지

### Phase 1: 뷰어를 Push로 열기 (3곳)

GridViewController, AlbumGridViewController, TrashAlbumViewController에서:

```swift
if #available(iOS 26.0, *) {
    viewerVC.preferredTransition = .zoom(sourceViewProvider: { context in
        return self.zoomSourceView(for: index)
    })
    navigationController?.pushViewController(viewerVC, animated: true)
} else {
    // 기존 Modal 방식 유지
    viewerVC.transitioningDelegate = transitionController
    present(viewerVC, animated: true)
}
```

- ZoomTransitionController, ZoomAnimator 등 Modal용 코드는 iOS 26에서 **사용하지 않음**
- `.zoom`이 시스템 애니메이션을 자동 제공하므로 커스텀 animator 불필요

### Phase 2: ViewerViewController dismiss 분기

```swift
// dismissWithFadeOut() 내부
if navigationController != nil {
    navigationController?.popViewController(animated: true)
} else {
    dismiss(animated: true)
}
```

- `handleDismissPan`도 동일하게 분기
- iOS 26 `.zoom`은 interactive dismiss(핀치/스와이프)를 **시스템이 자동 처리**
- 커스텀 handleDismissPan은 iOS 26에서 비활성화 가능 (시스템 제스처와 충돌 방지)

### Phase 3: 커스텀 버튼 조건부 생성 방지

```swift
// setupUI() 내부
if !useSystemUI {
    setupActionButtons()   // 커스텀 삭제/복구 버튼
    setupBackButton()      // 커스텀 백버튼
}
// useSystemUI == true면 viewWillAppear에서 setupSystemUIIfNeeded() 호출됨 (이미 구현됨)
```

### Phase 4: 검증

**품질 검증 항목:**
1. 줌 인 애니메이션 (그리드 → 뷰어): 배경 페이드인 타이밍이 자연스러운지
2. 줌 아웃 애니메이션 (뷰어 → 그리드): 셀 위치로 정확히 돌아가는지
3. 아래 스와이프 interactive dismiss: 동작 여부 및 부드러움
4. 시스템 네비게이션 바/툴바: 백버튼, 삭제 버튼 정상 표시
5. 좌우 스와이프로 사진 전환 후 dismiss 시 올바른 셀로 복귀
6. iOS 18 때 발생했던 배경 페이드인 타이밍 불일치 재현 여부

**품질 미달 판정 기준:**
- 배경 타이밍 불일치가 iOS 18과 동일하게 재현되면 → 방안 B 부적합 → 방안 A 진행

### 수정 파일 목록

| 파일 | 변경 내용 |
|------|----------|
| `Features/Grid/GridViewController.swift` | 뷰어 열기 iOS 26 분기 추가 |
| `Features/Albums/AlbumGridViewController.swift` | 뷰어 열기 iOS 26 분기 추가 |
| `Features/Albums/TrashAlbumViewController.swift` | 뷰어 열기 iOS 26 분기 추가 |
| `Features/Viewer/ViewerViewController.swift` | dismiss 분기, 커스텀 버튼 조건부, handleDismissPan 분기 |

---

## 참고 자료

| 제목 | URL | 비고 |
|------|-----|------|
| WWDC 2016 - Advances in UIKit Animations | https://asciiwwdc.com/2016/sessions/216 | interruptibleAnimator API 소개 |
| InteractiveNavigationControllerTransition | https://github.com/el-starikova/InteractiveNavigationControllerTransition-UIViewPropertyAnimator | UIViewPropertyAnimator 기반 예제 |
| Christian Selig - Interruptible Transitions | https://christianselig.com/2021/02/interruptible-view-controller-transitions/ | 실전 경험담 |
| Douglas Hill - Zoom Transitions | https://douglashill.co/zoom-transitions/ | iOS 18 zoom transition 분석 |
| Apple - Fluid Transitions | https://developer.apple.com/documentation/uikit/enhancing-your-app-with-fluid-transitions | iOS 18 공식 문서 |
| WWDC24 - UI Animations and Transitions | https://developer.apple.com/videos/play/wwdc2024/10145/ | WWDC 세션 |
| devsign.co - Interactive Pop Transition | https://devsign.co/notes/navigation-transitions-iv | Navigation interactive pop 패턴 |
| Masamichi Ueta - Photos app 스타일 | https://medium.com/@masamichiueta/create-transition-and-interaction-like-ios-photos-app-2b9f16313d3 | Navigation 기반 Photos 스타일 |

---

## 관련 문서

- `docs/complete/260129gridZoom1.md` - Push 방식 1차/2차 시도 및 실패 기록
- `docs/complete/260129gridZoom2.md` - Modal 방식 구현 완료 (현재 사용 중)

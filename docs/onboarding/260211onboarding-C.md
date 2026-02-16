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
[C-1 시작] 윈도우 레벨 터치 차단 시작
    │
    ├── 그리드: 뱃지 셀 하이라이트 (evenOdd 구멍)
    ├── 카피: "유사사진 정리기능이 표시된 사진이에요.
    │         각 사진의 얼굴을 비교해서 정리할 수 있어요"
    ├── [확인] ← 유일한 터치 허용 (1회차)
    ├── 확인 버튼+카피 페이드아웃
    ├── 손가락 탭 모션 on 뱃지 셀 (0.5초)
    ├── 자동 네비게이션 → 뷰어 (didSelectItemAt 호출)
    │       (전환 중에도 터치 차단 유지)
    │
    ├── 뷰어 viewDidAppear 대기
    ├── + 버튼 표시 대기 (~100ms, 캐시 hit)
    │
[C-2 시작] 터치 차단 유지
    │
    ├── 뷰어: + 버튼 하이라이트 (evenOdd 구멍)
    ├── 카피: "+버튼을 눌러 얼굴비교화면으로 이동하세요.
    │         인물이 여러 명이면 좌우로 넘겨볼 수 있어요."
    ├── [확인] ← 유일한 터치 허용 (2회차)
    ├── 확인 버튼+카피 페이드아웃
    ├── 손가락 탭 모션 on + 버튼 (0.6초)
    ├── 오버레이 dismiss + 터치 차단 해제 + markAsShown()
    ├── 자동 네비게이션 → 얼굴 비교 화면 (delegate 메서드 호출)
    │       ⚠️ .fullScreen present 시 UIKit transition container가
    │          window 최상단에 삽입되어 오버레이를 가림
    │          → dismiss 후 present 순서로 해결
    │
[C-2 완료]
```

---

## 파일 구조

### 수정 (3개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `.similarBadge`, `.faceButton` case 추가 + C-1/C-2 show 메서드 + 탭 모션 애니메이션 + 자동 네비게이션 콜백 |
| `CoachMarkType` | `similarBadge`, `faceButton` 케이스 추가 (단, C-1/C-2는 하나의 플래그로 관리) |
| `FaceButtonOverlay.swift` | 첫 번째 + 버튼의 프레임을 외부에 노출하는 접근자 추가 |

### 신규 (1개)

| 파일 | 내용 |
|------|------|
| `GridViewController+CoachMarkC.swift` | C-1 트리거 로직 (뱃지 최초 표시 감지 + 조건 확인 + show) |

### 기존 수정 (2개)

| 파일 | 수정 내용 |
|------|-----------|
| `GridViewController+SimilarPhoto.swift` | `showBadge(on:count:)` 에서 C-1 트리거 호출 추가 |
| `ViewerViewController+SimilarPhoto.swift` | C-2 트리거 (+ 버튼 표시 후 코치마크 C-2 표시) |

---

## 트리거 설계

### C-1 트리거 (그리드 뱃지)

```
showBadge(on:count:) 호출 시
  └── 이미 C가 표시된 적 있으면 스킵 (hasBeenShown)
  └── CoachMarkManager.isShowing이면 스킵
  └── 첫 번째 뱃지만 트리거 (hasTriggeredC1 associated object 플래그)
  └── indexPath 역추적: collectionView.indexPath(for: cell)
        ⚠️ showBadge(on:count:)는 cell만 파라미터로 받음
           indexPath는 collectionView.indexPath(for:)로 역추적 필요
  └── 1.0초 딜레이 (뱃지 안정 표시 확인)
        └── 재검증: 해당 셀이 여전히 visible한지
        └── 재검증: 뱃지가 여전히 표시 중인지
        └── 재검증: collectionView.indexPath(for: cell) != nil
        └── showSimilarBadgeCoachMark(cell:indexPath:)
              ├── 셀 프레임 → 윈도우 좌표 변환
              └── CoachMarkOverlayView.showSimilarBadge(
                      highlightFrame:,
                      in: window,
                      onConfirm: { self.navigateToViewer(at: indexPath) }
                  )
```

**중복 방지:**
`hasTriggeredC1`을 associated object로 관리. `showBadge`는 visible 셀 전체에 대해 반복 호출되므로, 첫 호출에서 플래그를 true로 설정하여 이후 호출을 스킵. 코치마크 dismiss 또는 타임아웃 시 false로 리셋.

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
  └── CoachMarkType.similarPhoto.markAsShown()
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
```

---

## 레이아웃

### C-1 (그리드 뱃지 하이라이트)

```
┌──────────────────────────────┐
│  Dim 배경 (black 60%)        │
│  ┌────┐ ┌────┐ ┌────┐       │
│  │    │ │    │ │    │       │
│  ├────┤ ├────┤ ├────┤       │
│  │    │ │ ⊞3 │ │    │       │ ← evenOdd 구멍으로 뱃지 셀 하이라이트
│  ├────┤ ├────┤ ├────┤       │     (A와 동일 방식)
│  │    │ │    │ │    │       │
│  └────┘ └────┘ └────┘       │
│                              │
│  "유사사진 정리기능이 표시된    │ ← 하이라이트 셀 아래
│   사진이에요. 각 사진의 얼굴을  │
│   비교해서 정리할 수 있어요"    │
│         [확인]               │
└──────────────────────────────┘
```

### C-2 (뷰어 + 버튼 하이라이트)

```
┌──────────────────────────────┐
│  Dim 배경 (black 60%)        │
│                              │
│        [+] ← evenOdd 구멍    │ ← + 버튼만 하이라이트
│                              │
│  "+버튼을 눌러 얼굴비교화면    │ ← + 버튼 아래
│   으로 이동하세요.             │
│   인물이 여러 명이면 좌우로    │
│   넘겨볼 수 있어요."          │
│         [확인]               │
└──────────────────────────────┘
```

**레이어 Z-순서 (아래→위):**
1. `dimLayer` — CAShapeLayer, black 60%, evenOdd (A와 동일, 구멍으로 대상 하이라이트)
2. `fingerView` — 손가락 아이콘 ([확인] 후 탭 모션에서만 표시)
3. `messageLabel` + `confirmButton` — 안내 텍스트 + 버튼

C는 스냅샷이 필요 없음 — 하이라이트 대상(셀/버튼)은 구멍을 통해 실제 UI가 보임.

---

## 탭 모션 애니메이션

### 공통: `performTapMotion(at:completion:)`

[확인] 후 대상을 "탭한다"는 느낌을 주는 애니메이션.

| 단계 | 시간 | 이징 | 동작 |
|------|------|------|------|
| 손가락 나타남 | 0.2초 | `.curveEaseOut` | fingerView alpha 0→1, 대상 중앙 약간 위에 배치 |
| 내려오기 | 0.15초 | `.curveEaseIn` | fingerView center → 대상 중앙 |
| 누르기 | 0.1초 | spring (damping 0.7) | fingerView scale 0.90, 대상 영역 밝기 변화 (tap 피드백) |
| 떼기 | 0.15초 | `.curveEaseOut` | fingerView scale 1.0, alpha 0 |

총 0.6초. A/B의 반복 시연과 달리 **1회성 탭** 모션.

### 대상 눌림 피드백

탭 모션 중 하이라이트 구멍 영역에 눌림 효과:
- C-1: 셀 위에 반투명 흰색 오버레이 flash (UIView, alpha 0→0.3→0)
- C-2: + 버튼에 scale 축소 효과 (실제 버튼은 오버레이 아래이므로 시각적으로만)

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
  자동 네비게이션 트리거

화면 전환 중:
  overlay 유지 (dim만 남아 전환 덮음)
  화면 전환 완료 대기 (viewDidAppear)

C-2 시작:
  기존 overlay에 새 dim path + 카피 + 확인을 재구성
  (removeFromSuperview 하지 않으므로 터치 차단 끊김 없음)
```

### CoachMarkManager 확장

```swift
final class CoachMarkManager {
    static let shared = CoachMarkManager()
    weak var currentOverlay: CoachMarkOverlayView?
    var isShowing: Bool { currentOverlay != nil }

    // C 전용 상태
    var isWaitingForC2: Bool = false       // C-1 완료 후 C-2 대기 중
    var c2OnConfirm: (() -> Void)?         // C-2 확인 후 실행할 콜백

    func dismissCurrent()                  // 기존 (markAsShown 호출)
    func transitionToC2(...)               // C-1 → C-2 전환 (오버레이 유지, 내용 교체)
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
| C-1 트리거 | 뱃지 셀이 1초 내 사라짐 | 트리거 취소, 다음 기회 대기 |
| C-1 → 뷰어 전환 | viewDidAppear 3초 내 미호출 | 오버레이 dismiss, 차단 해제 |
| C-2 + 버튼 대기 | hasVisibleButtons 2초 내 미달성 | 오버레이 dismiss, 차단 해제, C 전체 스킵 (markAsShown) |
| C-2 → 비교 화면 | present 실패 | 오버레이 dismiss, 차단 해제 |

타임아웃 시 `CoachMarkType.similarPhoto.markAsShown()` 호출하여 재시도하지 않음 (실패한 코치마크 반복은 UX 악화).

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
| 딤 배경 알파 | 0.60 | A와 동일 |
| 하이라이트 구멍 margin | 8pt | 셀/버튼보다 약간 크게 (A와 동일) |
| 손가락 아이콘 | `hand.point.up.fill`, 48pt, white | A/B와 동일 |
| C-1 카피 | "유사사진 정리기능이 표시된 사진이에요.\n각 사진의 얼굴을 비교해서 정리할 수 있어요" | |
| C-2 카피 | "+버튼을 눌러 얼굴비교화면으로 이동하세요.\n인물이 여러 명이면 좌우로 넘겨볼 수 있어요." | |
| 버튼 텍스트 | "확인" | A/B와 동일 |
| 탭 모션 총 시간 | 0.6초 | |
| 뱃지 안정 대기 | 1.0초 | 뱃지가 1초 이상 표시 후 트리거 |
| C-1 → C-2 전환 타임아웃 | 3.0초 | viewDidAppear 미호출 시 폴백 |
| C-2 + 버튼 대기 타임아웃 | 2.0초 | hasVisibleButtons 미달성 시 폴백 |

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
- `!isSelectMode` — didSelectItemAt의 isSelectMode 가드 통과 보장
- `!UIAccessibility.isVoiceOverRunning`
- `view.window != nil`
- `FeatureFlags.isSimilarPhotoEnabled`
- `hasFinishedInitialDisplay` — 초기 로딩 완료 후에만
- `!hasTriggeredC1` — 중복 트리거 방지 (associated object)

B 코치마크 (C-2 충돌 방지 가드 추가):
- `!CoachMarkManager.shared.isWaitingForC2` — C-2 대기 중이면 B 스킵

C-2 (뷰어):
- `CoachMarkManager.shared.isWaitingForC2` (C-1에서 설정)
- `faceButtonOverlay?.hasVisibleButtons == true`
- `view.window != nil`
- `presentedViewController == nil`

---

## 검증 방법

1. 그리드에서 유사사진 뱃지 표시 → 1초 후 C-1 코치마크 표시
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

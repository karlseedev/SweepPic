# 코치마크 D — 저품질 자동 정리 구현 계획

> 작성일: 2026-02-17

## Context

온보딩 코치마크 A(그리드 스와이프), B(뷰어 스와이프), C(유사사진·얼굴 비교)가 모두 구현 완료된 상태. 마지막 4번째 코치마크 D(저품질 자동 정리)를 구현한다.

**핵심 목표**: 사용자에게 정리 기능의 **가치를 체감**시키는 것. 단순 텍스트 안내가 아니라, 사용자의 실제 저품질 사진을 보여주고 정리 플로우로 자동 진입시킨다.

---

## 전체 플로우

```
앱 실행 → 즉시 사전 스캔 시작 (백그라운드)
  │         └── 최근 사진부터 순차 스캔 (3장 확보까지 계속)
  │
  ├── 사용자 스크롤 → A 코치마크 (기존)
  ├── 사용자 첫 삭제 → E-1 시스템 피드백 (기존)
  │
  ├── A 완료 + E-1 완료 + 그리드 3초 체류
  │     └── 스캔 미완료면 스캔 완료 대기
  │
  └── D 표시
        ├── 정리 버튼 하이라이트 (evenOdd 구멍)
        ├── "보관함에서 저품질 사진이 발견됐어요" + 최하위 3장 썸네일
        ├── [확인] → 탭 모션 on 정리 버튼 → dismiss
        └── showCleanupMethodSheet() 직접 호출 (삭제대기함 체크 우회)
```

---

## 파일 구조

### 신규 생성 (2개)

| 파일 | 역할 |
|------|------|
| `Features/AutoCleanup/CoachMarkDPreScanner.swift` | 사전 스캔 (T2 파이프라인, 3장 확보까지 계속) |
| `Features/Grid/GridViewController+CoachMarkD.swift` | D 트리거 로직 + 레이아웃 |

### 수정 (4개)

| 파일 | 수정 내용 |
|------|-----------|
| `CoachMarkOverlayView.swift` | `.autoCleanup` case 추가, `showAutoCleanup()` 정적 메서드 (썸네일 그리드 레이아웃), `confirmTapped()` D 분기, `updateDimPath()` 조건 추가 |
| `FloatingTitleBar.swift` | `secondRightButtonFrameInWindow()` 접근자 메서드 추가 |
| `GridViewController.swift` | `viewDidAppear`에 D 타이머 시작, `viewWillDisappear`에 D 타이머 취소, 사전 스캔 시작 호출 추가 |
| `GridViewController+Cleanup.swift` | `showCleanupMethodSheet()` 접근 수준 `private` → `internal` 변경, `cleanupButtonTapped()`에 D 미완료 시 가로채기 추가 |

---

## 1. 사전 스캔 (CoachMarkDPreScanner.swift)

### API

```swift
final class CoachMarkDPreScanner {
    static let shared = CoachMarkDPreScanner()

    struct Result {
        let lowQualityAssets: [PHAsset]   // 저품질 판정된 asset (최대 3개)
        let totalScanned: Int             // 스캔한 총 사진 수
    }

    private(set) var result: Result?
    private(set) var isScanning: Bool = false
    var isComplete: Bool { result != nil }

    /// 스캔 시작 (1회만 실행, 중복 호출 무시)
    func startIfNeeded()

    /// 스캔 완료 콜백 (메인 스레드)
    var onComplete: (() -> Void)?
}
```

### 파이프라인 (벤치마크 검증 완료)

**T2: MetadataFilter → Exposure → SKIP필터 → Blur (SafeGuard 제외)**

- SafeGuard: 0.18~3.62초 추가 비용, 구제 0건 → 제외
- SKIP필터: 1.43초로 7장 오판 방지 → 포함 필수
- 상세: `docs/onboarding/260217onboarding-D-prescan-benchmark.md`

### 스캔 로직

```
1. 앱 시작 직후 startIfNeeded() 호출
2. PHAsset.fetchAssets(ascending=false, mediaType=image, fetchLimit 없음)
3. 각 asset에 대해 순차 처리 (백그라운드):
   a. MetadataFilter → 비디오/스크린샷 등 스킵
   b. CleanupImageLoader.loadImage (짧은변 360px, highQualityFormat)
   c. ExposureAnalyzer.analyze → 노출 신호
   d. SKIP필터 (유틸리티/텍스트스크린샷/화이트배경) → 해당 시 스킵
   e. BlurAnalyzer.analyze (Metal GPU 256x256) → 블러 신호
   f. Strong 신호 있으면 lowQuality → 저품질 목록에 추가
4. 종료 조건: 3장 확보 또는 전체 사진 소진
5. 메인 스레드에서 onComplete 콜백
```

### 성능 (벤치마크 실측)

- 장당 평균 14~18ms (이미지 로딩 ~93%, 분석 ~7%)
- 순차 처리 (병렬 효과 없음 — PHImageManager가 병목)
- 앱 시작 → D 트리거까지 ~13초 → ~930장 처리 가능
- 앨범 A (0.5% 비율): ~930장 중 ~4.6장 → 3장 확보 가능
- 극단적으로 깨끗한 앨범 (0.2% 미만): 부족 가능 → 텍스트 폴백

### 속도 개선 시도 및 결과

| 방안 | 결과 | 비고 |
|------|------|------|
| 병렬 처리 (2/4/8) | ❌ 최대 1.16x | PHImageManager가 병목 |
| fastFormat 로딩 | ❌ 블러 오판 심각 | 168장 vs 48장 (120장 거짓양성) |
| 해상도 축소 | ❌ 검토 제외 | BlurAnalyzer 정확도 하락 |
| Exposure만 선행 | ❌ 검토 제외 | 블러(핵심 신호)를 못 잡음 |

---

## 2. 트리거 설계 (GridViewController+CoachMarkD.swift)

### 사전 스캔 시작 (앱 시작 직후)

```swift
// GridViewController.swift — viewDidLoad 또는 hasFinishedInitialDisplay 시점
func startCoachMarkDPreScanIfNeeded() {
    guard !CoachMarkType.autoCleanup.hasBeenShown else { return }
    CoachMarkDPreScanner.shared.startIfNeeded()
}
```

- 앱 시작 직후 가능한 빨리 호출 (A 코치마크와 무관하게 즉시 시작)
- D가 이미 표시된 적 있으면 스캔 안 함
- 스캔은 백그라운드에서 진행, D 트리거 시점까지 최대한 많은 사진 처리

### 트리거 1 (자동): 그리드 3초 체류

viewDidAppear에서 조건 체크 + 3초 타이머. 다른 화면에 갔다 오면 타이머 리셋.

```swift
// viewDidAppear에서 호출
func startCoachMarkDTimerIfNeeded() {
    guard !CoachMarkType.autoCleanup.hasBeenShown else { return }
    guard CoachMarkType.gridSwipeDelete.hasBeenShown else { return }  // A 완료 후만
    guard CoachMarkType.firstDelete.hasBeenShown else { return }      // E-1 완료 후만

    coachMarkDTimer?.invalidate()
    coachMarkDTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
        // 트리거 1은 스캔 결과 1장 이상일 때만 (0건이면 안 뜸)
        let count = CoachMarkDPreScanner.shared.result?.lowQualityAssets.count ?? 0
        guard count > 0 else { return }
        self?.showCoachMarkD(highlightButton: true)
    }
}

// viewWillDisappear에서 호출
func cancelCoachMarkDTimer() {
    coachMarkDTimer?.invalidate()
    coachMarkDTimer = nil
}
```

### 트리거 2 (수동): 정리 버튼 탭

D 미완료 상태에서 정리 버튼 탭 시, 정리 플로우 대신 D를 먼저 표시.

```swift
@objc func cleanupButtonTapped() {
    // D 미완료 + 스캔 결과 1장 이상 → D 먼저 표시 → [확인] → 정리 플로우 이어서 진행
    let scanCount = CoachMarkDPreScanner.shared.result?.lowQualityAssets.count ?? 0
    if !CoachMarkType.autoCleanup.hasBeenShown && scanCount > 0 {
        showCoachMarkD(highlightButton: false)
        return
    }

    // D 완료 → 기존 정리 플로우
    cleanupTracker = CleanupFlowTracker()
    if !CleanupService.shared.isTrashEmpty() { ... }
    showCleanupMethodSheet()
}
```

### D 표시 (트리거 1, 2 공용)

```swift
/// - Parameter highlightButton: true면 정리 버튼에 구멍 하이라이트 (트리거 1), false면 구멍 없음 (트리거 2)
func showCoachMarkD(highlightButton: Bool) {
    // 재검증 가드
    guard !CoachMarkType.autoCleanup.hasBeenShown else { return }
    guard !CoachMarkManager.shared.isShowing else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showCoachMarkD(highlightButton: highlightButton)
        }
        return
    }
    guard !UIAccessibility.isVoiceOverRunning else { return }
    guard view.window != nil else { return }
    guard navigationController?.topViewController === self else { return }
    guard presentedViewController == nil else { return }
    guard !isSelectMode else { return }
    guard !isScrolling else {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.showCoachMarkD(highlightButton: highlightButton)
        }
        return
    }

    guard let window = view.window else { return }

    // 트리거 1: 정리 버튼 하이라이트 (사용자가 버튼 위치를 모름)
    // 트리거 2: 하이라이트 없음 (사용자가 이미 버튼을 눌렀으므로)
    let cleanupFrame: CGRect? = highlightButton ? getCleanupButtonFrame(in: window) : nil

    // 스캔 결과: 있으면 썸네일, 없으면 텍스트 폴백 (대기 안 함)
    let scanResult = CoachMarkDPreScanner.shared.result

    CoachMarkOverlayView.showAutoCleanup(
        highlightFrame: cleanupFrame,
        scanResult: scanResult,
        in: window,
        onConfirm: { [weak self] in
            // 삭제대기함 체크 우회하여 정리 플로우 직접 진입
            self?.showCleanupMethodSheet()
        }
    )
}
```

### 시나리오 검증

| 시나리오 | 흐름 | D 표시 | 버튼 하이라이트 |
|---------|------|--------|---------------|
| 이상적 흐름 | A→E-1→그리드 3초 (스캔 3장) | 썸네일 3장 | ✅ |
| 즉시 버튼 탭 (스캔 초기) | 정리 버튼 탭 (스캔 0장) | **D 안 끼움** | — |
| 중간에 버튼 탭 (스캔 2장) | 정리 버튼 탭 (스캔 2장) | 썸네일 2장 | ❌ |
| 깨끗한 앨범 (자동) | A→E-1→그리드 3초 (스캔 0장) | **D 안 뜸** | — |
| 깨끗한 앨범 (수동) | 정리 버튼 탭 (스캔 0장) | **D 안 끼움** | — |

---

## 3. 정리 버튼 프레임 접근

```swift
private func getCleanupButtonFrame(in window: UIWindow) -> CGRect? {
    if #available(iOS 26.0, *) {
        // rightBarButtonItems = [menuItem, selectItem, cleanupItem]
        guard let items = navigationItem.rightBarButtonItems,
              items.count >= 3,
              let itemView = items[2].value(forKey: "view") as? UIView
        else { return nil }
        return itemView.convert(itemView.bounds, to: window)
    } else {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay
        else { return nil }
        return overlay.titleBar.secondRightButtonFrameInWindow(window)
    }
}
```

### FloatingTitleBar 접근자 추가 (FloatingTitleBar.swift)

```swift
/// 두 번째 오른쪽 버튼(정리 버튼) 프레임을 윈도우 좌표로 반환
func secondRightButtonFrameInWindow(_ window: UIWindow) -> CGRect? {
    guard !secondRightButton.isHidden else { return nil }
    return secondRightButton.convert(secondRightButton.bounds, to: window)
}
```

---

## 4. 레이아웃 (showAutoCleanup)

### 트리거 1 (자동): 버튼 하이라이트 + 썸네일

```
┌──────────────────────────────────────┐
│  사진보관함         ┌정리┐ [선택] ...  │ ← 정리 버튼 evenOdd 구멍 (pill shape)
│  ██████████████████ └──┘ ████████████│
│  ██████████████████████████████████  │
│                                      │
│  보관함에서 저품질 사진이 발견됐어요   │ ← 타이틀 (17pt medium, white)
│                                      │
│       ┌─────┐  ┌─────┐  ┌─────┐     │
│       │     │  │     │  │     │     │ ← 최하위 3장 썸네일
│       │     │  │     │  │     │     │   (ImagePipeline 로딩)
│       └─────┘  └─────┘  └─────┘     │   cornerRadius 8, 균등 간격
│                                      │
│    흔들리거나 초점이 맞지 않은        │
│    사진들을 AI가 자동으로 찾아주는    │ ← 설명 (15pt regular, white 70%)
│    정리 기능을 사용해보세요           │
│                                      │
│              [ 확인 ]                │ ← 흰색 pill 버튼 (120x44)
│                                      │
└──────────────────────────────────────┘
```

### 트리거 2 (수동): 하이라이트 없음 + 썸네일

```
┌──────────────────────────────────────┐
│  ██████████████████████████████████  │ ← 구멍 없음 (전체 딤)
│  ██████████████████████████████████  │
│                                      │
│  보관함에서 저품질 사진이 발견됐어요   │ ← 타이틀
│                                      │
│       ┌─────┐  ┌─────┐  ┌─────┐     │
│       │     │  │     │  │     │     │ ← 썸네일
│       │     │  │     │  │     │     │
│       └─────┘  └─────┘  └─────┘     │
│                                      │
│    흔들리거나 초점이 맞지 않은        │
│    사진들을 AI가 자동으로 찾아주는    │ ← 설명
│    정리 기능입니다                    │
│                                      │
│              [ 확인 ]                │
│                                      │
└──────────────────────────────────────┘
```

### 문구 정리

| 조건 | 타이틀 | 설명 |
|------|--------|------|
| 트리거 1 (썸네일 있음) | "보관함에서 저품질 사진이 발견됐어요" | "흔들리거나 초점이 맞지 않은 사진들을 AI가 자동으로 찾아주는 정리 기능을 사용해보세요" |
| 트리거 1 + 0건 | **D 안 뜸** | — |
| 트리거 2 + 썸네일 있음 | "보관함에서 저품질 사진이 발견됐어요" | "흔들리거나 초점이 맞지 않은 사진들을 AI가 자동으로 찾아주는 정리 기능입니다" |
| 트리거 2 + 0건 | **D 안 끼움** — 정상 정리 플로우 진행 | — |

### 구멍 모양 (트리거 1만 해당)

- iOS 16~25 (GlassTextButton): pill shape → `cornerRadius = 버튼높이/2` (22pt)
- iOS 26+ (UIBarButtonItem): 시스템 버튼 모양에 맞게 `cornerRadius = 8`

### 썸네일 배치

- 크기: `(화면너비 - 64 - 16) / 3` (좌우 패딩 32 + 간격 8x2)
- 정사각형, cornerRadius 8
- 중앙 정렬, 수평 균등 간격 8pt
- 발견 3장 미만: 발견된 만큼만 표시 (중앙 정렬)

### 썸네일 로딩

```swift
// 스캔 결과의 lowQualityAssets에서 썸네일 로딩
let size = CGSize(width: thumbSize * scale, height: thumbSize * scale)
for (i, asset) in scanResult.lowQualityAssets.enumerated() {
    ImagePipeline.shared.requestImage(for: asset, targetSize: size, quality: .fast) {
        image, _ in
        thumbnailViews[i].image = image
    }
}
```

---

## 5. confirmTapped 분기 (CoachMarkOverlayView.swift)

```swift
@objc func confirmTapped() {
    switch coachMarkType {
    case .gridSwipeDelete, .viewerSwipeDelete:
        dismiss()
    case .similarPhoto:
        confirmButton.isEnabled = false
        startC_ConfirmSequence()
    case .autoCleanup:
        // D: 재진입 방지 → 탭 모션 → onConfirm
        confirmButton.isEnabled = false
        startD_ConfirmSequence()
    // E-1/E-2/E-3 case는 260211onboarding-E.md 참조
    }
}
```

### startD_ConfirmSequence

트리거에 따라 동작이 다름:

**트리거 1 (자동 — 사용자가 버튼 위치를 모름):**
```
1. 텍스트 + 썸네일 + 확인 버튼 페이드아웃 (0.2초)
2. 정리 버튼 위치에 탭 모션 (C의 performCTapMotion 재사용)
3. dismiss() — markAsShown() 포함
4. onConfirm?() — showCleanupMethodSheet() 호출 (정리 플로우 자동 진입)
```

**트리거 2 (수동 — 사용자가 이미 버튼을 탭함):**
```
1. 텍스트 + 썸네일 + 확인 버튼 페이드아웃 (0.2초)
2. 탭 모션 없음
3. dismiss() — markAsShown() 포함
4. onConfirm?() — showCleanupMethodSheet() 호출 (가로챈 정리 플로우 이어서 진행)
```

---

## 6. CoachMarkType 확장

```swift
enum CoachMarkType: String {
    case gridSwipeDelete = "coachMark_gridSwipe"       // A
    case viewerSwipeDelete = "coachMark_viewerSwipe"   // B
    case similarPhoto = "coachMark_similarPhoto"        // C
    case autoCleanup = "coachMark_autoCleanup"          // D
}
```

---

## 7. updateDimPath 분기

```swift
// .autoCleanup 추가
if coachMarkType == .gridSwipeDelete || coachMarkType == .similarPhoto || coachMarkType == .autoCleanup {
    let margin: CGFloat = 8
    let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
    // D: pill shape 대응 — cornerRadius를 버튼 높이 기반으로
    let radius: CGFloat = (coachMarkType == .autoCleanup) ? holeRect.height / 2 : 8
    let holePath = UIBezierPath(roundedRect: holeRect, cornerRadius: radius)
    fullPath.append(holePath)
}
```

---

## 충돌 방지

| 대상 | 방지 방법 |
|------|-----------|
| E → D 순서 | `CoachMarkType.firstDelete.hasBeenShown` 가드. E-1 미완료 시 D 발동 안 함 |
| A → D 순서 | `CoachMarkType.gridSwipeDelete.hasBeenShown` 가드. A 미완료 시 D 발동 안 함 |
| B 끼어들기 | viewDidAppear 기반 3초 타이머. 뷰어 가면 타이머 취소, 돌아오면 새 3초 시작 |
| D 표시 중 다른 코치마크 | `isShowing` 가드. D 표시 중 B/C 차단 |
| 다른 코치마크 표시 중 D | `isShowing` 가드 + 0.5초 재시도. 끝나면 자연스럽게 D 표시 |
| 스크롤 중 D 표시 | `!isScrolling` 가드. 스크롤 중이면 0.5초 후 재시도 |
| Select 모드 | `!isSelectMode` 가드 |
| viewWillDisappear | 타이머 취소 + 기존 `dismissCurrent()`가 D도 처리 |
| 삭제대기함 체크 | D의 onConfirm에서 `showCleanupMethodSheet()` 직접 호출 (우회) |

---

## 검증 체크리스트

1. E-1 완료 + A 완료 + 그리드 3초 체류 → D 표시
2. E-1 미완료 → 그리드에서 아무리 오래 있어도 D 안 뜸
3. A 미완료 → D 안 뜸
4. 그리드 → 뷰어 → 그리드 복귀 → 3초 후 D (타이머 리셋 확인)
5. D에서 정리 버튼이 pill shape 구멍으로 하이라이트되는지
6. 최하위 3장 썸네일이 표시되는지 (blur/dark 사진)
7. 0건 시 텍스트 폴백으로 전환되는지
8. [확인] → 탭 모션 → dismiss → 정리 방법 선택 시트 표시
9. 삭제대기함에 사진이 있어도 정리 시트가 정상 표시되는지 (우회 확인)
10. iOS 16~25 / iOS 26+ 각각 정리 버튼 위치 확인
11. 표시 중 모든 터치 차단 ([확인] 외)
12. VoiceOver 활성 시 D 안 뜨는지
13. D 표시 중 화면 이탈 → dismiss
14. 앱 재실행 시 D 안 나타남 (UserDefaults)
15. 스크롤 중 D 트리거 시 스크롤 멈출 때까지 대기하는지
16. B 표시 중 3초 경과 → B 끝난 후 D 표시 (isShowing 재시도)

# LiquidGlassOptimizer iOS 26 불필요 동작 이슈

## 발견일: 2026-02-13

## 증상
- iOS 26에서 `useFloatingUI = false`로 FloatingOverlay가 비활성화되어 있음
- 그런데 `[LiquidGlass]` 로그가 여전히 출력됨:
  ```
  [LiquidGlass] NEW overlay: frame=(0.0, 0.0, 61.67, 44.0), superview=LiquidGlassEffectView
  [LiquidGlass] Blur preload: new=1, total=4, found=1
  ```
- UIAlertController present 시점에 발생

## 원인 (추정)
- `LiquidGlassOptimizer`에 iOS 버전 가드가 없음
- `GridViewController.viewDidAppear`에서 무조건 `LiquidGlassOptimizer.preload(in: view.window)` 호출
- iOS 26에서도 `findAllMTKViews(in:)`로 뷰 계층 전체를 스캔
- 시스템 UIAlertController나 다른 컴포넌트의 MTKView를 감지하여 불필요한 overlay 생성 가능

## 영향
- 불필요한 뷰 계층 스캔 (성능)
- 시스템 UI 컴포넌트에 대한 불필요한 블러 오버레이 생성 가능
- 예측 불가능한 부작용

## 수정 방향
- `LiquidGlassOptimizer.preload()`에 `#unavailable(iOS 26.0)` 가드 추가
- 또는 호출 지점에서 `useFloatingUI` 체크

## 관련 파일
- `PickPhoto/PickPhoto/Debug/LiquidGlassOptimizer.swift` — preload() 함수
- `PickPhoto/PickPhoto/Features/Grid/GridViewController.swift:368` — 호출 지점
- GlassButton, GlassIconButton, GlassTextButton, GlassCircleButton — 각 `didMoveToWindow`에서 호출

---

## 상세 분석 (2026-02-13)

### 핵심 발견: `isNative: true` 분기

`LiquidGlassEffectView.swift:153-178`의 팩토리 함수가 핵심:

```swift
public func VisualEffectView(effect: UIVisualEffect?) -> AnyVisualEffectView {
    if let effect = effect as? LiquidGlassEffect {
        if #available(iOS 26.0, *), effect.isNative {
            // → 네이티브 UIVisualEffectView 반환 (MTKView 없음!)
            return UIVisualEffectView(effect: UIGlassEffect(...))
        } else {
            // → LiquidGlassEffectView 반환 (내부에 LiquidGlassView: MTKView 포함)
            return LiquidGlassEffectView(effect: effect)
        }
    }
}
```

모든 GlassButton 컴포넌트가 `LiquidGlassEffect(style: .regular, isNative: true)`를 사용하므로:

| iOS 버전 | 반환 타입 | MTKView 생성 |
|---------|----------|-------------|
| 16~25 | `LiquidGlassEffectView` | O (Metal 렌더링) |
| 26+ | `UIVisualEffectView` (네이티브) | X |

### iOS 26에서의 전체 그림

| 컴포넌트 | iOS 26에서 존재? | MTKView? |
|---------|----------------|----------|
| FloatingOverlay (TitleBar + TabBar) | `useFloatingUI=false` → 생성 안 됨 | X |
| LiquidGlassTabBar + SelectionPill | FloatingOverlay 안에 있으므로 없음 | X |
| Viewer GlassButton들 (delete, restore 등) | 있음 (iOS 버전 무관) | `isNative=true` → X |
| FaceButtonOverlay | 있음 | `isNative=true` → X |

**결론: iOS 26에서는 앱이 직접 생성하는 LiquidGlassKit MTKView는 0개 → LiquidGlassOptimizer는 불필요**
(시스템 내부 MTKView 존재 여부는 Apple 비공개이므로 단정 불가 — 오히려 시스템 MTKView를 건드릴 위험이 있어 비활성화 필요)

### 역사적 맥락 (왜 이렇게 되었나)

1. LiquidGlassKit은 iOS 16~25에서 iOS 26 스타일 Glass 효과를 Metal로 구현하는 Fork 라이브러리
2. MTKView가 많아져 GPU 부하가 커지자 LiquidGlassOptimizer가 만들어짐 (blur 대체, idle pause 등)
3. iOS 26 출시 후 `isNative: true` 분기 추가 → 네이티브 API로 전환
4. `useFloatingUI` 분기도 추가 → FloatingOverlay 비활성화
5. **Optimizer에는 iOS 26 가드가 아직 추가되지 않음** ← 점진적 전환 과정의 누락

### iOS 26에서의 실제 위험

1. **시스템 MTKView 간섭**: `findAllMTKViews(in: window)`가 뷰 계층 전체를 재귀 탐색 → iOS 26 시스템 UI(UIAlertController 등)가 내부적으로 사용하는 MTKView를 잡아서 블러 오버레이 생성 또는 pause 시도 가능
2. **불필요한 비용**: 매 viewDidAppear, 스크롤 시작/종료마다 window 전체 탐색 → 앱 MTKView 0개인데 탐색만 반복 (약 10개 VC에서 호출)
3. **GlassButton didMoveToWindow**: iOS 26에서 버튼 내부에 MTKView 없으므로 무의미한 preload 호출 (무해하지만 낭비)

### 로그 `superview=LiquidGlassEffectView`에 대해

iOS 26에서 모든 GlassButton이 `isNative: true`를 쓰면 `LiquidGlassEffectView`는 생성되지 않아야 함.
이 로그가 실제 iOS 26 디바이스에서 나온 것이라면 `isNative: false`를 사용하는 컴포넌트가 존재하거나,
iOS 25 환경에서 관찰한 것을 iOS 26 이슈로 추정 기록했을 가능성 있음.

---

## 해결 방안

### 방안 A: Optimizer 내부에 iOS 26 가드 (권장)

Optimizer의 public 메서드 4개(`preload`, `optimize`, `restore`, `enterIdle`)에 일괄 가드 추가.
호출 지점(10개+ VC)은 수정하지 않아도 됨 → 변경 범위 최소화.

```swift
// LiquidGlassOptimizer.swift
static func preload(in rootView: UIView?) {
    guard isEnabled else { return }
    if #available(iOS 26.0, *) { return }  // ← 추가
    ...
}

static func optimize(in rootView: UIView?) {
    guard isEnabled else { return }
    if #available(iOS 26.0, *) { return }  // ← 추가
    ...
}

static func restore(in rootView: UIView?) {
    guard isEnabled else { return }
    if #available(iOS 26.0, *) { return }  // ← 추가
    ...
}

static func enterIdle(in rootView: UIView?) {
    guard isEnabled else { return }

    // 기존 타이머 취소 (iOS 26에서도 안전하게 정리)
    idleTimer?.cancel()

    if #available(iOS 26.0, *) { return }  // ← 취소 후 가드
    ...
}
```

**장점**: 수정 1개 파일, 호출 지점 변경 불필요, 즉시 적용
**단점**: 향후 iOS 26에서도 커스텀 MTKView를 쓸 일이 생기면 가드 제거 필요

### 방안 B: GlassButton didMoveToWindow 가드 추가 (보완)

방안 A에 추가로, GlassButton 4종의 `didMoveToWindow`에서도 iOS 26 가드.
방안 A만으로 이미 preload 내부에서 early return하므로 필수는 아니지만,
불필요한 async dispatch 자체를 막는 추가 최적화.

```swift
// GlassButton.swift, GlassIconButton.swift, GlassTextButton.swift, GlassCircleButton.swift
override func didMoveToWindow() {
    super.didMoveToWindow()
    if #available(iOS 26.0, *) { return }  // ← 추가
    if window != nil {
        DispatchQueue.main.async { ... }
    }
}
```

### 추천 실행 순서

1. **방안 A 적용** (LiquidGlassOptimizer.swift 1파일, 4줄 추가)
2. **방안 B 적용** (GlassButton 4파일, 각 1줄 추가) — 선택
3. iOS 26 디바이스에서 `[LiquidGlass]` 로그 미출력 확인

> **참고**: `cancelIdleTimer()`는 가드 불필요. 함수 자체가 가볍고(nil 체크 + cancel), iOS 26에서도 항상 취소 동작을 허용하는 것이 안전.

---

## 수정 결과 (2026-02-13 완료)

### 적용 내용
- **방안 A + B 모두 적용**
- 빌드 성공, iOS 26 / iOS 25 이하 모두 정상 동작 확인

### 수정 파일 (5개)
| 파일 | 수정 내용 |
|-----|----------|
| `Debug/LiquidGlassOptimizer.swift` | `preload`, `optimize`, `restore`에 `if #available(iOS 26.0, *) { return }` 추가. `enterIdle`은 `idleTimer?.cancel()` 뒤에 가드 배치 |
| `Shared/Components/GlassButton.swift` | `didMoveToWindow()`에 iOS 26 가드 추가 |
| `Shared/Components/GlassCircleButton.swift` | 동일 |
| `Shared/Components/GlassIconButton.swift` | 동일 |
| `Shared/Components/GlassTextButton.swift` | 동일 |

### 검증 결과
- iOS 26: `[LiquidGlass]` 로그 미출력, 그리드 스크롤·뷰어·UIAlertController 정상
- iOS 25 이하: 기존 idle pause/resume 동작 유지 (mode=.normal 기준)

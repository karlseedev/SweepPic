# LiquidGlassKit 성능 최적화

## 1. 문제 상황

iOS 18에서 그리드 스크롤 시 LiquidGlassKit 적용 후 심각한 성능 저하 발생.
LiquidGlassKit 롤백 시 정상 동작 확인됨.

---

## 2. 병목 원인 분석

`LiquidGlassView.swift` (MTKView 상속) 분석 결과:

| 병목 | 내용 | 코드 위치 |
|------|------|-----------|
| 1 | `drawHierarchy()` 배경 캡처 (매 프레임) | `captureBackdrop()` |
| 2 | `waitUntilCompleted()` 블러 동기 대기 | `blurTexture()` |
| 3 | Metal 셰이더 (굴절/프레넬/글레어) | `draw()` |

### 제어 가능한 옵션

```swift
// LiquidGlassView (MTKView 상속)
autoCapture: Bool  // false → 병목 1+2 중지 (internal, 라이브러리 수정 필요)
isPaused: Bool     // true → 병목 1+2+3 모두 중지 (public, MTKView 기본)
```

---

## 3. Baseline 측정 결과

### 측정 환경
- 기기: (기록 필요)
- iOS 버전: 18.x
- 사진 수: ~35장
- 측정 도구: HitchMonitor (Apple 방식)

### 측정 기준 (Apple 공식)

| Hitch Time Ratio | 등급 | 의미 |
|------------------|------|------|
| < 5 ms/s | Good | 거의 인지 못함 |
| 5-10 ms/s | Warning | 가끔 인지됨 |
| > 10 ms/s | Critical | 명확히 불편함 |

### L1 First (첫 스크롤)

```
[Scroll] First scroll 시작: +5006.1ms
[Hitch] L1 First: hitch: 753.0 ms/s [Critical], fps: 29.1 (avg 8.33ms), frames: 125, dropped: 391, longest: 391 (3258.6ms)
[Scroll] First scroll 완료: 4298.9ms 동안 스크롤
========== PERFORMANCE METRICS (Vision) [#2] ==========
Photos: 35, Faces: 0, Groups: 0
--------------------------------------------------
FP Generation Time: 662.11ms (18.9ms/photo)
Face Detect+Match Time: 433.77ms (433.8ms/face)
Total Time: 1119.21ms
--------------------------------------------------
Memory Start: 228.0MB
Memory End: 224.0MB
Memory Delta: -4.0MB
Thermal State: nominal
```

### L2 Steady (이후 스크롤)

```
[Hitch] L2 Steady: hitch: 745.2 ms/s [Critical], fps: 29.9 (avg 8.33ms), frames: 110, dropped: 329, longest: 315 (2625.2ms)
========== PERFORMANCE METRICS (Vision) [#3] ==========
Photos: 38, Faces: 22, Groups: 3
--------------------------------------------------
FP Generation Time: 789.30ms (20.8ms/photo)
Face Detect+Match Time: 2349.59ms (106.8ms/face)
Total Time: 3182.58ms
--------------------------------------------------
Memory Start: 256.5MB
Memory End: 258.6MB
Memory Delta: +2.1MB
Thermal State: nominal
```

### L1 vs L2 비교

| 항목 | L1 First | L2 Steady | 차이 |
|------|----------|-----------|------|
| **Hitch Ratio** | 753.0 ms/s | 745.2 ms/s | -7.8 (거의 동일) |
| **FPS** | 29.1 | 29.9 | +0.8 |
| **Dropped Frames** | 391 | 329 | -62 |
| **Longest Hitch** | 3258ms | 2625ms | -633ms |
| **Vision Time** | 1119ms | 3182ms | +2063ms |

### Baseline 분석

1. **L1 ≈ L2** - 첫 스크롤과 이후 스크롤 차이 거의 없음
2. **Vision 영향 미미** - L2에서 Vision 3배 더 오래 걸렸지만 Hitch는 비슷
3. **주 원인은 LiquidGlassKit** - Vision과 무관하게 일정한 성능 저하
4. **기준치 75배 초과** - 목표 <10ms/s 대비 750ms/s

---

## 4. 테스트 계획

### 테스트 시나리오

| 테스트 | 설정 | 중지되는 병목 | 확인 사항 |
|--------|------|---------------|-----------|
| Baseline | 현재 상태 | 없음 | 기준값 (완료) |
| A | `autoCapture = false` | 1+2 (캡처/블러) | 셰이더만으로 성능 확보 가능한지 |
| B | `isPaused = true` | 1+2+3 (전체) | Glass 효과 완전 중지 시 성능 |

### 구현 필요 항목

1. **LiquidGlassOptimizer** - MTKView 탐색 및 모드 제어
2. **BaseGridViewController 연동** - 스크롤 감지 + 옵션 토글
3. **테스트 모드 스위치** - 3가지 모드 순환

### 테스트 흐름

```
1. 테스트 모드 선택 (normal / noCapture / paused)
2. 그리드 스크롤 (동일한 패턴으로)
3. HitchMonitor 결과 수집
4. 모드 변경 후 반복
```

---

## 5. 테스트 결과

### Test A: autoCapture = false

```
(측정 예정 - 라이브러리 수정 필요)
```

### Test B: isPaused = true (완료)

```
[Hitch] L2 Steady: hitch: 0.7 ms/s [Good], fps: 119.9 (avg 8.33ms), frames: 371, dropped: 0, longest: 0 (0.0ms)
[Performance] MTKView resumed: 13개
========== PERFORMANCE METRICS (Vision) [#5] ==========
Photos: 35, Faces: 6, Groups: 2
--------------------------------------------------
FP Generation Time: 705.17ms (20.1ms/photo)
Face Detect+Match Time: 832.13ms (138.7ms/face)
Total Time: 1566.62ms
--------------------------------------------------
Memory Start: 264.8MB
Memory End: 266.2MB
Memory Delta: +1.4MB
Thermal State: nominal
```

### Test C: blurReplacement (UIBlurEffect 대체)

**개념**: 스크롤 중 LiquidGlass(MTKView)를 UIVisualEffectView로 대체

```
[Performance] Blur replacement: 13개
[Hitch] L2 Steady: hitch: 74.6 ms/s [Critical], fps: 111.2 (avg 8.33ms), frames: 284, dropped: 23, longest: 23 (191.7ms)
[Performance] Blur restored: 13개

[Performance] Blur replacement: 13개
[Hitch] L2 Steady: hitch: 60.3 ms/s [Critical], fps: 112.8 (avg 8.33ms), frames: 317, dropped: 20, longest: 20 (166.7ms)
[Performance] Blur restored: 13개
```

### 결과 비교

| 테스트 | Hitch Ratio | FPS | Dropped | 개선율 | 등급 |
|--------|-------------|-----|---------|--------|------|
| Baseline | 745.2 ms/s | 29.9 | 329 | - | Critical |
| Test A | (예정) | | | | |
| **Test B** | **0.7 ms/s** | **119.9** | **0** | **99.9%** | **Good** |
| Test C | 67.5 ms/s | 112.0 | 22 | 91% | Critical |

### Test B 분석

- **Hitch**: 745.2 → 0.7 ms/s (**99.9% 개선**)
- **FPS**: 29.9 → 119.9 (**4배 개선**, 120Hz 달성)
- **Dropped**: 329 → 0 (**100% 개선**)
- **MTKView 개수**: 13개 (FloatingTabBar, FloatingTitleBar, GlassButton 등)
- **등급**: Critical → **Good**
- **단점**: 스크롤 중 배경이 freeze (마지막 캡처된 이미지 유지)

### Test C 분석

- **Hitch**: 745.2 → 67.5 ms/s (**91% 개선**)
- **FPS**: 29.9 → 112.0 (**3.7배 개선**)
- **Dropped**: 329 → 22 (**93% 개선**)
- **블러 스타일**: `UIBlurEffect(style: .systemThinMaterial)`
- **등급**: Critical → **Critical** (여전히 10ms/s 초과)
- **원인**: UIVisualEffectView 13개 생성/제거 오버헤드 + 0.15s 애니메이션
- **시각적**: 자연스러운 블러 (배경이 실시간 반영됨)

### Test B vs Test C 비교

| 항목 | Test B (isPaused) | Test C (blurReplacement) |
|------|-------------------|--------------------------|
| 성능 | **Good (0.7ms/s)** | Critical (67.5ms/s) |
| FPS | **119.9** | 112.0 |
| 시각적 | 배경 freeze | 자연스러운 블러 |
| 구현 복잡도 | 단순 | 복잡 |
| 추천 | **성능 우선** | 시각적 품질 우선 |

---

## 6. 최적화 방안 (테스트 후 결정)

### 옵션 1: 스크롤 중 autoCapture 비활성화
- 스크롤 시작 → `autoCapture = false`
- 스크롤 종료 → `autoCapture = true`
- Glass 효과는 유지, 배경 캡처만 중지
- **라이브러리 수정 필요** (autoCapture가 internal)

### 옵션 2: 스크롤 중 isPaused 활성화 (Test B 검증 완료)
- 스크롤 시작 → `isPaused = true`
- 스크롤 종료 → `isPaused = false`
- Glass 효과 완전 중지 (정적 상태로 freeze)
- **장점**: 라이브러리 수정 없이 적용 가능
- **단점**: 스크롤 중 Glass 애니메이션 중지

### 옵션 3: LiquidGlassKit 라이브러리 수정
- `waitUntilCompleted()` 비동기화
- 캡처 주기 조절 (매 프레임 → N프레임마다)
- (Fork 버전이므로 수정 가능)

---

## 7. 구현 코드

### Test C: blurReplacement 모드

```swift
enum LiquidGlassOptimizeMode {
    case normal         // 최적화 없음 (baseline)
    case paused         // isPaused = true (Test B)
    case blurReplacement // UIBlurEffect로 대체 (Test C)
}

// 스크롤 시작 시
static func replaceWithBlur(in rootView: UIView) {
    let mtkViews = findAllMTKViews(in: rootView)
    for mtkView in mtkViews {
        // 블러 뷰 생성
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterial))
        blurView.frame = mtkView.frame
        blurView.layer.cornerRadius = mtkView.layer.cornerRadius
        blurView.clipsToBounds = true

        // MTKView 아래에 삽입
        mtkView.superview?.insertSubview(blurView, belowSubview: mtkView)
        blurView.alpha = 0
        blurOverlays[ObjectIdentifier(mtkView)] = (blurView, mtkView.alpha)

        // 애니메이션 전환
        UIView.animate(withDuration: 0.15) {
            mtkView.alpha = 0
            blurView.alpha = 1
        } completion: { _ in
            mtkView.isPaused = true
        }
    }
}

// 스크롤 종료 시
static func restoreFromBlur() {
    for (identifier, overlay) in blurOverlays {
        let blurView = overlay.blurView
        // MTKView 복원 후 블러 뷰 제거
        UIView.animate(withDuration: 0.15) { ... }
    }
    blurOverlays.removeAll()
}
```

---

## 8. 구현 코드 (Test B)

### LiquidGlassOptimizer.swift

```swift
#if DEBUG
import UIKit
import MetalKit
import AppCore

/// LiquidGlassKit 성능 최적화 모드
enum LiquidGlassOptimizeMode {
    case normal      // 최적화 없음 (baseline)
    case paused      // isPaused = true (Test B: 병목 1+2+3 중지)
}

/// LiquidGlassKit 성능 최적화 유틸리티
enum LiquidGlassOptimizer {

    /// 현재 최적화 모드 (테스트용)
    static var mode: LiquidGlassOptimizeMode = .paused

    /// 최적화 활성화 여부
    static var isEnabled: Bool = true

    /// 뷰 계층의 모든 MTKView를 일시정지
    static func pauseAllMTKViews(in rootView: UIView?) {
        guard isEnabled, mode == .paused else { return }
        guard let rootView = rootView else { return }

        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.isPaused = true
        }

        Log.debug("Performance", "MTKView paused: \(mtkViews.count)개")
    }

    /// 뷰 계층의 모든 MTKView를 재개
    static func resumeAllMTKViews(in rootView: UIView?) {
        guard isEnabled, mode == .paused else { return }
        guard let rootView = rootView else { return }

        let mtkViews = findAllMTKViews(in: rootView)
        for mtkView in mtkViews {
            mtkView.isPaused = false
        }

        Log.debug("Performance", "MTKView resumed: \(mtkViews.count)개")
    }

    /// 뷰 계층에서 모든 MTKView 찾기 (재귀 탐색)
    private static func findAllMTKViews(in view: UIView) -> [MTKView] {
        var result: [MTKView] = []
        if let mtkView = view as? MTKView {
            result.append(mtkView)
        }
        for subview in view.subviews {
            result.append(contentsOf: findAllMTKViews(in: subview))
        }
        return result
    }
}
#endif
```

### GridScroll.swift 연동

```swift
// scrollDidBegin()
#if DEBUG
LiquidGlassOptimizer.pauseAllMTKViews(in: view.window)
#endif

// scrollDidEnd() 타이머 콜백 내
#if DEBUG
LiquidGlassOptimizer.resumeAllMTKViews(in: self.view.window)
#endif
```

### BaseGridViewController 안전 복구 (필수)

**문제**: 스크롤 중 화면 전환 시 resume 콜백 누락 → MTKView가 영구 paused 상태로 남음

```swift
// BaseGridViewController.swift
override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    // 스크롤 중이었다면 MTKView 복구 보장 (유리 고정 버그 방지)
    #if DEBUG
    LiquidGlassOptimizer.resumeAllMTKViews(in: view.window)
    #endif
}
```

---

## 8. 관련 파일

- `LiquidGlassKit/Sources/LiquidGlassKit/LiquidGlassView.swift` - 라이브러리 소스
- `PickPhoto/PickPhoto/Debug/LiquidGlassOptimizer.swift` - 최적화 유틸리티 (신규)
- `PickPhoto/PickPhoto/Features/Grid/GridScroll.swift` - 스크롤 감지
- `PickPhoto/PickPhoto/Features/Grid/BaseGridViewController.swift` - viewWillDisappear 안전 복구
- `Sources/AppCore/Services/HitchMonitor.swift` - 성능 측정
- `Sources/AppCore/Services/Log.swift` - 로그 카테고리 (Hitch, Scroll, Performance)

---

## 9. 변경 이력

| 날짜 | 내용 |
|------|------|
| 2026-01-29 | 문서 생성, Baseline 측정 완료 |
| 2026-01-29 | Test B 구현 및 측정 완료 (99.9% 개선, 120fps 달성) |
| 2026-01-29 | Test C (blurReplacement) 구현 및 측정 - 91% 개선, 여전히 Critical |
| 2026-01-29 | viewWillDisappear 안전 복구 로직 추가 (유리 고정 버그 방지) |
| 2026-01-29 | Test C 개선 - Preload + 방안 D/E 테스트 |
| 2026-01-29 | 초기 버벅임 원인 발견: 유사사진 분석과 GPU 경쟁 |

---

## 10. Test C 개선 (Preload + 방안 D)

### 문제점
기존 Test C에서 스크롤 시작할 때 UIVisualEffectView 생성 오버헤드로 초기 랙 발생.

### 해결: Preload 방식

**viewDidAppear에서 블러 뷰 사전 생성:**
```swift
static func preload(in rootView: UIView?) {
    let mtkViews = findAllMTKViews(in: rootView)
    for mtkView in mtkViews {
        let blurView = createBlurView(matching: mtkView)
        blurView.alpha = 0
        superview.insertSubview(blurView, belowSubview: mtkView)
        preloadedOverlays[identifier] = PreloadedOverlay(blurView, mtkView, originalAlpha)
    }
}
```

**스크롤 시에는 alpha만 전환:**
- 생성 비용 제거
- 프레임 동기화만 수행

### 방안 D: 즉시 isPaused + 단일 애니메이션

**문제**: 기존 구현에서 `isPaused = true`가 애니메이션 완료 후(0.1초 뒤) 실행됨

**해결**:
```swift
// 1단계: 모든 MTKView 즉시 정지 (렌더링 즉시 중단)
for (_, overlay) in preloadedOverlays {
    mtkView.isPaused = true
    mtkView.alpha = 0
    blurViewsToAnimate.append(overlay.blurView)
}

// 2단계: 블러 뷰만 단일 애니메이션으로 fade in
UIView.animate(withDuration: transitionDuration) {
    for blurView in blurViewsToAnimate {
        blurView.alpha = blurAlpha
    }
}
```

**개선 효과**:
- 애니메이션 14개 → 1개로 통합
- isPaused 즉시 설정 (0.1초 지연 제거)

### 방안 E: 애니메이션 완전 제거

```swift
for (_, overlay) in preloadedOverlays {
    mtkView.isPaused = true
    mtkView.alpha = 0
    overlay.blurView.alpha = blurAlpha
}
```

**테스트 결과**: 방안 D와 큰 차이 없음

### 현재 적용 설정

```swift
static var mode: LiquidGlassOptimizeMode = .blurReplacement
static var blurAlpha: CGFloat = 0.3
let blurEffect = UIBlurEffect(style: .systemThinMaterial)
```

**커밋 포인트**:
- `4b097ef` - 방안 E (애니메이션 완전 제거)
- `823aab9` - 방안 D (즉시 isPaused + 단일 애니메이션)


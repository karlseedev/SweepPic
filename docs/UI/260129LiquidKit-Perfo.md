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
| 2026-01-29 | ViewerViewController 성능 분석 추가 (Baseline: 434~489 ms/s Critical) |
| 2026-01-29 | ViewerViewController 최적화 계획: UIScrollViewDelegate 방식 |
| 2026-01-29 | ViewerViewController Test B/C 비교: Test C 효과 없음, Test B만 Good 달성 |
| 2026-01-29 | Viewer Test C 원인 분석: blur 애니메이션과 측정 구간 겹침 가설 |
| 2026-01-29 | 검증 1 완료: transitionDuration=0 → 애니메이션 원인 아님 |
| 2026-01-29 | 검증 2 완료: 그리드 Good vs Viewer Critical, 새 가설 - UIVisualEffectView가 페이지 전환 시 문제 |
| 2026-01-29 | 검증 3 완료: Viewer view 내 MTKView 0개, 개수 문제 아님 |

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

---

## 11. ViewerViewController 최적화

### 문제 상황

ViewerViewController (사진 뷰어)에서 좌우 스와이프 시 심각한 성능 저하 발생.

### Baseline 측정 (willTransitionTo 시점 최적화)

```
[LiquidGlass] Blur show: 14개
[Viewer:Hitch] L1 First: hitch: 434.3 ms/s [Critical], fps: 63.0, frames: 22, dropped: 17
[Viewer:Swipe] completed=true, duration=349.4ms

[LiquidGlass] Blur show: 14개
[Viewer:Hitch] L2 Steady: hitch: 489.3 ms/s [Critical], fps: 50.6, frames: 16, dropped: 19
[Viewer:Swipe] completed=true, duration=316.3ms
```

| 항목 | L1 First | L2 Steady |
|------|----------|-----------|
| Hitch Ratio | 434.3 ms/s | 489.3 ms/s |
| 등급 | Critical | Critical |
| FPS | 63.0 | 50.6 |
| Dropped | 17 | 19 |

### 원인 분석

`willTransitionTo`는 스크롤이 **이미 진행된 후** 호출됨:

```
사용자 터치 시작
    ↓
[scrollViewWillBeginDragging] ← 여기서 최적화해야 빠름 ✅
    ↓
    ... 스크롤 진행 중 (프레임 렌더링) ...
    ↓
[willTransitionTo] ← 현재 여기서 최적화 (이미 늦음) ❌
    ↓
    ... 계속 스크롤 ...
```

- 초기 10~15프레임이 MTKView 부하로 드랍
- 최적화 적용 전 프레임들이 버벅임

### 개선 방안: UIScrollViewDelegate 사용

UIPageViewController 내부 UIScrollView의 delegate를 직접 사용하여 더 빠른 시점에 최적화 적용.

**구현 내용:**

| 메서드 | 시점 | 동작 |
|--------|------|------|
| `viewDidAppear` | 화면 표시 후 | `preload()` - 블러 뷰 사전 생성 |
| `scrollViewWillBeginDragging` | 터치 직후 | `optimize()` - MTKView 정지 |
| `scrollViewDidEndDecelerating` | 스크롤 완료 | `restore()` - MTKView 재개 |
| `scrollViewDidEndDragging(willDecelerate: false)` | 드래그만 종료 | `restore()` |

**수정 파일:**
- `ViewerViewController.swift` - UIScrollViewDelegate 구현

### 테스트 결과

#### Test C (blurReplacement) - scrollViewWillBeginDragging 적용

```
[Viewer:Hitch] L2 Steady: hitch: 403.6 ms/s [Critical], fps: 66.3, frames: 26, dropped: 19
[Viewer:Hitch] L2 Steady: hitch: 417.9 ms/s [Critical], fps: 68.1, frames: 91, dropped: 62
```

#### Test B (isPaused) - scrollViewWillBeginDragging 적용

```
[Viewer:Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 119.9, frames: 40, dropped: 0
[Viewer:Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 117.5, frames: 44, dropped: 0
```

#### 결과 비교

| 테스트 | Hitch Ratio | FPS | Dropped | 등급 |
|--------|-------------|-----|---------|------|
| Baseline (willTransitionTo) | 434~489 ms/s | 50~63 | 17~19 | Critical |
| Test C (willBeginDragging) | 403~417 ms/s | 66~68 | 19~62 | Critical |
| **Test B (willBeginDragging)** | **0.0 ms/s** | **117~120** | **0** | **Good** |

### 분석

#### 확인된 사실
- **Test B (isPaused)**: 0.0 ms/s [Good] → Viewer 자체는 문제없음
- **Test C (blurReplacement)**: 400+ ms/s [Critical] → blurReplacement가 Viewer에서 문제

#### 그리드 vs Viewer 차이

| 항목 | 그리드 | Viewer |
|------|--------|--------|
| Test C 결과 | 67 ms/s | 400+ ms/s |
| 스크롤 특성 | 연속 스크롤 (길게 지속) | 페이징 (짧은 전환 ~350ms) |

#### 원인 가설: 측정 구간과 애니메이션 타이밍 겹침

```
그리드: scrollDidBegin ─────────────────────────── scrollDidEnd
           blur show(0.1s)  [긴 스크롤 구간]        blur hide
           └─ 애니메이션 완료 후 대부분 측정 ─┘

Viewer:        willTransitionTo ─── didFinishAnimating
                   blur show(0.1s) [짧은 전환 ~350ms]
                   └─ 애니메이션이 측정 구간과 겹침 ─┘
```

- **그리드**: 스크롤이 길어서 blur 애니메이션(0.1s)이 측정 전에 완료
- **Viewer**: 전환이 짧아서 blur 애니메이션이 측정 중에 진행

### 검증 계획

| 순서 | 테스트 | 목적 |
|------|--------|------|
| 1 | transitionDuration = 0 | blur 애니메이션이 원인인지 확인 |
| 2 | 절대값 로그 추가 | Hitch Ratio가 과대 평가인지 확인 |
| 3 | Viewer 전용 2개만 처리 | MTKView 개수(14개 vs 2개) 영향 확인 |

### 검증 결과

#### 검증 1: transitionDuration = 0 (애니메이션 제거)

```
[Viewer:Hitch] L2 Steady: hitch: 558.6 ms/s [Critical], fps: 50.8, dropped: 62
[Viewer:Hitch] L2 Steady: hitch: 450.9 ms/s [Critical], fps: 59.4, dropped: 20
```

| 설정 | Hitch Ratio | 결과 |
|------|-------------|------|
| transitionDuration = 0.1 | 400+ ms/s | Critical |
| transitionDuration = 0 | 450~558 ms/s | Critical (오히려 악화) |

**결론**: blur 애니메이션은 원인 아님

#### 검증 2: 절대값 로그

**그리드 결과:**
```
[Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 120.1, frames: 125, dropped: 0
[Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 120.2, frames: 236, dropped: 0
```

**Viewer 결과:**
```
[Viewer:Hitch] L1 First: hitch: 482.5 ms/s [Critical], fps: 57.5, dropped: 23
[Viewer:Hitch:Abs] totalHitchMs=193.1, duration=0.400s

[Viewer:Hitch] L2 Steady: hitch: 428.9 ms/s [Critical], fps: 61.3, dropped: 20
[Viewer:Hitch:Abs] totalHitchMs=167.9, duration=0.392s

[Viewer:Hitch] L2 Steady: hitch: 572.4 ms/s [Critical], fps: 49.4, dropped: 77
[Viewer:Hitch:Abs] totalHitchMs=660.0, duration=1.153s

[Viewer:Hitch] L2 Steady: hitch: 368.9 ms/s [Critical], fps: 67.8, dropped: 12
[Viewer:Hitch:Abs] totalHitchMs=108.9, duration=0.295s
```

**비교:**

| 화면 | totalHitchMs | duration | Hitch Ratio | 등급 |
|------|-------------|----------|-------------|------|
| 그리드 | ~0 | ~1s | 0.0 ms/s | **Good** |
| Viewer | 108~660ms | 0.3~1.2s | 368~572 ms/s | **Critical** |

**결론:**
- 그리드: Test C로 **Good** 달성 (이전 67ms/s에서 개선)
- Viewer: 여전히 **Critical**
- **같은 blurReplacement, 같은 14개 MTKView인데 결과가 다름**
- Viewer totalHitchMs = 108~660ms → 비율 문제 아님, **실제 hitch 발생**

**새로운 가설:**
- UIVisualEffectView가 **Viewer 페이지 전환 시에만** 문제
- 페이지 전환 시 배경이 급격히 변화 → blur 계산 비용 증가
- 그리드는 배경이 서서히 변화 (셀 스크롤)

#### 검증 3: Viewer 전용 2개만 처리

**목적:** MTKView 개수(14개 vs 2개) 영향 확인

**방법:** static 변수 우회하여 Viewer view 내 MTKView만 처리

**결과:**
```
[LiquidGlass] Blur preload 완료: 14개  ← 그리드의 LiquidGlassOptimizer
[Viewer:Blur] preload 완료: 0개        ← Viewer view 내 MTKView 없음
```

| 항목 | 값 |
|------|-----|
| Viewer view 내 MTKView | **0개** |
| Hitch Ratio | 479~597 ms/s |
| 등급 | Critical |

**결론:**
- Viewer 화면 자체에는 MTKView가 없음
- 14개 MTKView는 모두 **window 레벨** (FloatingTabBar, FloatingTitleBar 등)
- MTKView 개수 문제가 아님

### 검증 종합 결론

| 검증 | 가설 | 결과 |
|------|------|------|
| 1 | blur 애니메이션이 원인 | ❌ 아님 (제거해도 Critical) |
| 2 | 비율 과대 평가 | ❌ 아님 (절대값도 큼) |
| 3 | MTKView 개수 문제 | ❌ 아님 (Viewer에 0개) |
| 4 | cornerRadius/clipsToBounds offscreen rendering | ⚠️ 부분 원인 (64% 개선, 여전히 Critical) |

#### 검증 4: cornerRadius/clipsToBounds 제거

**방법:** `createBlurView()`에서 cornerRadius, clipsToBounds 주석 처리

```swift
// 검증 4: cornerRadius/clipsToBounds 주석 처리
// blurView.layer.cornerRadius = mtkView.layer.cornerRadius
// blurView.layer.cornerCurve = mtkView.layer.cornerCurve
// blurView.clipsToBounds = true
```

**결과:**
```
[Viewer:Hitch] L1 First: hitch: 158.1 ms/s [Critical], fps: 95.5, dropped: 7
[Viewer:Hitch:Abs] totalHitchMs=58.0, duration=0.367s

[Viewer:Hitch] L2 Steady: hitch: 228.1 ms/s [Critical], fps: 87.1, dropped: 11
[Viewer:Hitch:Abs] totalHitchMs=91.7, duration=0.402s

[Viewer:Hitch] L2 Steady: hitch: 448.6 ms/s [Critical], fps: 59.5, dropped: 19
[Viewer:Hitch:Abs] totalHitchMs=158.3, duration=0.353s

[Viewer:Hitch] L2 Steady: hitch: 472.1 ms/s [Critical], fps: 56.6, dropped: 20
[Viewer:Hitch:Abs] totalHitchMs=166.7, duration=0.353s
```

**비교:**

| 항목 | 기존 (cornerRadius 있음) | 검증 4 (제거) | 변화 |
|------|-------------------------|---------------|------|
| L1 First | 434~489 ms/s | **158 ms/s** | **64% 개선** |
| L2 Steady | 400~489 ms/s | 228~472 ms/s | 부분 개선 |
| 등급 | Critical | Critical | 여전히 Critical |

**분석:**
- cornerRadius/clipsToBounds = **부분 원인** (offscreen rendering 유발)
- L1에서 64% 개선되었으나 여전히 Critical
- L2에서 점점 악화 (228 → 448 → 472) → 누적 문제
- 나머지 원인 = **UIVisualEffectView 실시간 blur 계산 비용** 추정

**미해결 문제:**
- 그리드: Test C로 **Good**
- Viewer: Test C로 **Critical**
- 같은 14개 MTKView, 같은 blurReplacement인데 결과가 다름
- **UIVisualEffectView 실시간 blur + 급격한 배경 변화**가 원인으로 추정

### 추가 검증 계획

| 순서 | 검증 | 목적 | 구현 난이도 |
|------|------|------|-------------|
| 5 | `effect = nil` | blur 제거, 투명 뷰만 → 실시간 blur가 원인인지 확정 | 쉬움 |
| 6 | 정적 CoreImage blur | 한 번만 blur 처리 → 실시간 계산이 원인인지 확정 | 중간 |
| 7 | 배경 스냅샷 고정 | 배경 변화 없이 테스트 → 급격한 배경 변화가 원인인지 확정 | 복잡 |


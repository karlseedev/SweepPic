# 뷰어 열림 랙 분석 (2026-01-31)

> **✅ 해결 완료** — 빌드 후 첫 뷰어 열기 시 7~15초 Hang의 근본 원인 특정 및 해결.
> 원인: f296691에서 GlassIconButton/GlassTextButton의 `feedbackGenerator.prepare()` 제거 → 시스템 서비스(CHHapticEngine/AudioToolbox) 워밍업 부수 효과 소실 → Metal cold-start 시 dyld 락 블로킹.
> 해결: GlassIconButton에 feedbackGenerator 복원 (`fee7434`).

## 문제 현상

- 앱을 빌드 후 첫 실행 시, 썸네일 탭 → 뷰어 열림까지 **수초의 랙** 발생
- 2번째 클릭부터는 정상 (26ms 수준)
- Hang 감지: 최대 **9.00초**

---

## 조사 방법

1. ViewerViewController, ZoomAnimator, GridViewController에 `CACurrentMediaTime()` 기반 타이밍 로그 삽입
2. 단계별로 병목 구간을 좁혀서 함수 내부까지 세분화
3. 과거 커밋으로 이동하여 동일 타이밍 로그로 A/B 비교 (git bisect 방식으로 병목 발생 커밋 특정)

---

## 타이밍 로그 측정 구간

| 위치 | 측정 구간 |
|------|----------|
| ViewerVC.viewDidLoad | setupUI, setupGestures, swipeDelete, displayInitialPhoto, setupSimilarPhoto (각각 + 총) |
| displayInitialPhoto 내부 | createPageVC, setViewControllers |
| setupSimilarPhotoFeature 내부 | faceButtonOverlay, loadingIndicator, observers |
| ZoomAnimator.animateTransition | 준비, addSubview, layoutIfNeeded |
| ViewerVC.viewWillAppear | 마커 |
| ViewerVC.viewDidAppear | 탭~화면표시 총 시간 (openStartTime 기준) |
| GridVC.didSelectItemAt | 준비, Coordinator, filteredIndex, ViewerVC생성, transition설정, present/push, 총 |

---

## 테스트 결과 비교

### 커밋별 첫 클릭 성능 (1st tap after fresh build)

| 구간 | decb029 (1/28) | d34059e (1/29) | d4ce98b (1/30) | 131f00e (1/30) | 018a380 (1/30) | bd6577a (1/30) | f296691 (1/30) | e88957b (현재) |
|------|:-:|:-:|:-:|:-:|:-:|:-:|:-:|:-:|
| **createPageVC** | 0.2ms | 0.2ms | 0.1ms | 0.1ms | 0.1ms | 0.2ms | 0.1ms | 0.3ms |
| **setViewControllers** | **1,623.1ms** | 2.3ms | 2.3ms | 2.2ms | 1.1ms | 2.2ms | 1.4ms | **937.5ms** |
| **faceButtonOverlay** | 2.8ms | 4.8ms | 4.8ms | 4.8ms | 2.4ms | 5.1ms | **7,914.1ms** | **3,294.3ms** |
| **loadingIndicator** | 1.7ms | 1.0ms | 0.9ms | 0.9ms | 0.5ms | 0.8ms | 0.9ms | 2.4ms |
| **observers** | 0.1ms | 0.3ms | 0.1ms | 0.0ms | 0.0ms | 0.1ms | 0.1ms | 0.3ms |
| **setupUI** | 13.1ms | - | 17.4ms | 16.4ms | 6.7ms | 16.8ms | 9.3ms | - |
| displayInitialPhoto 총 | 1,623.6ms | 2.5ms | 2.5ms | 2.4ms | 1.2ms | 2.4ms | 1.5ms | 938.1ms |
| setupSimilarPhoto 총 | 4.9ms | 5.9ms | 5.8ms | 5.9ms | 3.0ms | 6.1ms | 8,927.6ms | 3,298.4ms |
| **viewDidLoad 총** | **1,645.6ms** | 34.7ms | 26.0ms | 24.8ms | 10.9ms | 25.4ms | **8,939.8ms** | **7,956.8ms** |
| transition설정 | **1,648.0ms** | - | - | - | - | - | - | - |
| push/present | **3,809.9ms** | - | - | - | - | - | - | - |
| GridVC 총 | **5,467.0ms** | - | - | - | - | - | - | - |
| ZoomAnimator layoutIfNeeded | (없음) | - | 6.6ms | 6.7ms | 5.0ms | 6.3ms | 10.1ms | - |
| 탭~화면표시 총 | **8,753.9ms** | - | 433.5ms | 444.9ms | 410.0ms | 455.3ms | 9,377.4ms | - |
| Hang 감지 | **7.87s** | 없음 | 없음 | 없음 | 없음 | 없음 | **9.00s** | **8.02s** |

### 커밋 정보

| 커밋 | 날짜 | 방식 | 버튼 | 설명 | 결과 |
|------|------|------|------|------|------|
| `decb029` | 1/28 | Push + iOS18 Zoom | GlassButton | LiquidGlassKit 도입 전 | **병목 있음 (setViewControllers 1,623ms)** |
| `d34059e` | 1/29 | Push + 커스텀 Zoom | GlassButton | 커스텀 줌 트랜지션 Phase 1 | **병목 없음** |
| `d4ce98b` | 1/30 | Modal + 커스텀 Zoom | GlassButton→GlassIconButton | Navigation → Modal 전환 | **병목 없음** |
| `131f00e` | 1/30 | Modal + 커스텀 Zoom | GlassIconButton | LiquidGlass 최적화 | **병목 없음** |
| `018a380` | 1/30 | Modal + 커스텀 Zoom | GlassIconButton | SimilarPhoto Task 취소 | **병목 없음** |
| `bd6577a` | 1/30 | Modal + 커스텀 Zoom | GlassIconButton | Task 취소 Sendable | **병목 없음** |
| **`f296691`** | **1/30** | Modal + 커스텀 Zoom | GlassIconButton | **진단 코드 정리** | **병목 발생! (faceButtonOverlay 7,914ms)** |
| `e88957b` | 1/31 | Modal + 커스텀 Zoom | GlassIconButton | 현재 | **병목 있음 (faceButtonOverlay 3,294ms + setViewControllers 938ms)** |

### e88957b 재측정 (현재 브랜치 복귀 후)

| 구간 | 이전 측정 | 재측정 | 비고 |
|------|:-:|:-:|------|
| createPageVC | 0.3ms | 0.1ms | 유사 |
| **setViewControllers** | **937.5ms** | **1.2ms** | 병목 소멸 |
| **faceButtonOverlay** | **3,294.3ms** | **5,146.5ms** | 더 증가 |
| **loadingIndicator** | 2.4ms | **771.7ms** | 새 병목 |
| observers | 0.3ms | 0.2ms | 유사 |
| displayInitialPhoto 총 | 938.1ms | 1.3ms | |
| setupSimilarPhoto 총 | 3,298.4ms | 5,918.7ms | |
| GridVC push/present | - | 5,935.0ms | |
| GridVC 총 | - | 5,940.4ms | |
| 탭~화면표시 총 | - | 6,402.5ms | |
| Hang 감지 | 8.02s | 6.00s | |

→ **병목 총량은 비슷하나 분포가 다름**. LiquidGlassKit 첫 초기화 비용이 setViewControllers / faceButtonOverlay / loadingIndicator 사이에서 이동하는 패턴. BackdropView 경고 8건 일관 발생.

### 추가 측정 — GlassCircleButton 1뷰 구조 변경 후 (expandedView 제거)

| 구간 | 수치 | 비고 |
|------|------|------|
| createPageVC | 0.2ms | |
| setViewControllers | 2.5ms | |
| setupLayers (glassView 1개) | **2,124.7ms** | 측정1과 큰 차이 |
| GlassCircleButton.init(eye.fill) | 2,130.2ms | |
| toggleButton lazy생성 | 2,130.6ms | |
| FaceButtonOverlay() | 3,021.8ms | |
| **faceButtonOverlay** | **5,025.9ms** | |
| loadingIndicator | 4.5ms | |
| displayInitialPhoto 총 | 2.7ms | |
| setupSimilarPhoto 총 | 5,030.7ms | |
| push | 5,049.8ms | |
| GridVC 총 | 5,054.6ms | |
| **탭~화면표시 총** | **5,473.9ms** | |
| **Hang 감지** | **5.10s** | |
| BackdropView 경고 | 4건 | |

### 추가 측정 2차 — 동일 조건

| 구간 | 수치 |
|------|------|
| createPageVC | 0.2ms |
| setViewControllers | 2.9ms |
| setupLayers (glassView 1개) | **1.9ms** |
| GlassCircleButton.init(eye.fill) | 6.0ms |
| toggleButton lazy생성 | 6.4ms |
| FaceButtonOverlay() | **1,205.7ms** |
| **faceButtonOverlay** | **1,205.9ms** |
| loadingIndicator | 1.0ms |
| displayInitialPhoto 총 | 3.2ms |
| setupSimilarPhoto 총 | 1,207.1ms |
| push | 1,229.6ms |
| GridVC 총 | 1,235.4ms |
| **탭~화면표시 총** | **14,761.7ms** |
| **Hang 감지** | **14.39s** |
| BackdropView 경고 | 4건 |
| AVHapticClient 오류 | XPC call failed |

→ 우리 코드에서 잡힌 시간 ~1.2초, 전체 14.8초 → **약 13초가 로그 밖에서 소비됨**.

### 1차 vs 2차 비교

| | 1차 | 2차 |
|---|---|---|
| setupLayers | 2,124ms | 1.9ms |
| faceButtonOverlay | 5,025ms | 1,205ms |
| 우리 코드 총 | ~5초 | ~1.2초 |
| Hang | 5.10s | **14.39s** |
| 탭~화면표시 총 | 5,473ms | **14,761ms** |

### 추가 측정 3차 — 동일 조건

| 구간 | 수치 |
|------|------|
| createPageVC | 0.2ms |
| setViewControllers | 2.9ms |
| setupLayers (glassView 1개) | 3.5ms |
| **setupIcon** | **3,183.8ms** |
| GlassCircleButton.init(eye.fill) | 3,187.6ms |
| toggleButton lazy생성 | 3,187.7ms |
| FaceButtonOverlay() | 3,187.9ms |
| **faceButtonOverlay** | **3,188.0ms** |
| loadingIndicator | 0.8ms |
| displayInitialPhoto 총 | 3.2ms |
| setupSimilarPhoto 총 | 3,189.0ms |
| push | 3,209.6ms |
| GridVC 총 | 3,215.4ms |
| **탭~화면표시 총** | **7,392.8ms** |
| **Hang 감지** | **7.03s** |
| BackdropView 경고 | 4건 |

### 3회 측정 종합 비교

| | 1차 | 2차 | 3차 |
|---|---|---|---|
| **병목 위치** | setupLayers 2,124ms | FaceButtonOverlay() 1,205ms | **setupIcon 3,183ms** |
| setupLayers | **2,124ms** | 1.9ms | 3.5ms |
| setupIcon | 4.8ms | 3.5ms | **3,183ms** |
| FaceButtonOverlay() | 3,021ms | **1,205ms** | 3,187ms |
| 우리 코드 총 | ~5초 | ~1.2초 | ~3.2초 |
| Hang | 5.10s | **14.39s** | 7.03s |
| 탭~화면표시 총 | 5,473ms | **14,761ms** | 7,392ms |

### 추가 측정 4차 — 동일 조건

| 구간 | 수치 |
|------|------|
| createPageVC | 0.2ms |
| setViewControllers | 2.7ms |
| setupLayers (glassView 1개) | 2.2ms |
| **setupIcon** | **1,915.0ms** |
| GlassCircleButton.init(eye.fill) | 1,917.4ms |
| toggleButton lazy생성 | 1,917.5ms |
| FaceButtonOverlay() | 1,917.7ms |
| **faceButtonOverlay** | **1,917.9ms** |
| loadingIndicator | 1.1ms |
| displayInitialPhoto 총 | 3.0ms |
| setupSimilarPhoto 총 | 1,919.1ms |
| push | 1,939.1ms |
| GridVC 총 | 1,945.1ms |
| **탭~화면표시 총** | **8,004.4ms** |
| **Hang 감지** | **7.63s** |
| BackdropView 경고 | 4건 |

### 4회 측정 종합 비교

| | 1차 | 2차 | 3차 | 4차 |
|---|---|---|---|---|
| **병목 위치** | setupLayers | FaceButtonOverlay() | setupIcon | setupIcon |
| setupLayers | **2,124ms** | 1.9ms | 3.5ms | 2.2ms |
| setupIcon | 4.8ms | 3.5ms | **3,183ms** | **1,915ms** |
| faceButtonOverlay | 5,025ms | 1,205ms | 3,188ms | 1,917ms |
| 우리 코드 총 | ~5초 | ~1.2초 | ~3.2초 | ~1.9초 |
| Hang | 5.10s | **14.39s** | 7.03s | 7.63s |
| 탭~화면표시 총 | 5,473ms | **14,761ms** | 7,392ms | 8,004ms |
| BackdropView 경고 | 4건 | 4건 | 4건 | 4건 |

→ 병목이 잡히는 코드 위치는 매번 다르지만, **원인은 동일** — LiquidGlassKit BackdropView/Metal 첫 초기화.
→ 이 비용이 우리 코드의 어느 줄에서 메인 스레드를 블로킹하느냐만 달라짐.
→ BackdropView 경고 4건은 항상 일관.

### 현재 상태 2번째 클릭 (e88957b)

| 구간 | 수치 |
|------|------|
| setViewControllers | 0.7ms |
| faceButtonOverlay | 5.3ms |
| viewDidLoad 총 | 26.4ms |

→ 2번째부터는 정상. **첫 클릭에서만 발생하는 초기화 비용 문제**.

---

## Bisect 결과: 원인 커밋 확정

### **원인 커밋: `f296691` (chore: 진단 코드 정리, 줌 트랜지션 성능 원인 분석 결과 기록)**

| 커밋 | 결과 |
|------|------|
| `bd6577a` (직전) | 병목 없음 (25.4ms) |
| **`f296691`** (원인) | **병목 있음 (8,940ms)** |

→ `bd6577a` → `f296691` 사이의 코드 변경이 faceButtonOverlay 초기화를 7,914ms로 만든 원인.

### git diff bd6577a..f296691 분석 결과

**변경된 코드 파일 (docs 제외):**

| 파일 | 변경 내용 | faceButtonOverlay 영향 |
|------|----------|----------------------|
| `GlassIconButton.swift` | `UIImpactFeedbackGenerator` 제거 (-9줄) | ❌ 초기화 가벼워지는 방향 |
| `GlassTextButton.swift` | `UIImpactFeedbackGenerator` 제거 (-9줄) | ❌ 초기화 가벼워지는 방향 |
| `ZoomAnimator.swift` | `isInteractiveDismiss` guard 추가 (+12줄) | ❌ dismiss 시에만 영향 |
| `ZoomTransitionController.swift` | `isInteractiveDismiss` 값 전달 (+1줄) | ❌ dismiss 시에만 영향 |
| `QualityAnalyzer.swift` | Vision continuation 중복 resume 방지 (+38줄) | ❌ 뷰어 UI와 무관 |
| `CompareAnalysisTester.swift` | 극단적 비율 체크 + continuation 보호 (+34줄) | ❌ 뷰어 UI와 무관 |

**SPM 패키지 변경: 없음** (Package.swift, Package.resolved 동일)

**결론: 직접적 원인 코드 없음**

`bd6577a` → `f296691` 사이의 코드 변경에는 faceButtonOverlay 초기화를 7,914ms로 만들 수 있는 직접적인 원인이 **보이지 않음**. GlassIconButton에서 haptic feedback을 제거한 것은 오히려 초기화를 가볍게 만드는 방향.

**가능한 원인 가설:**

1. **빌드 캐시 상태 차이**: 테스트 시 branch 전환으로 SPM/Xcode derived data 캐시 상태가 달라져 LiquidGlassKit 재컴파일 시 최적화 수준이 달라졌을 가능성
2. **간접적 영향**: `feedbackGenerator.prepare()`가 UIKit 내부 초기화를 트리거하여, 그 부작용으로 LiquidGlassKit BackdropView 관련 시스템 리소스가 미리 워밍업되었을 가능성
3. **비결정적 병목**: LiquidGlassKit 첫 초기화 비용이 시스템 상태에 따라 5~9초 범위에서 변동 (e88957b 재측정에서 분포가 달라진 것이 이를 뒷받침)

→ **다음 단계**: bd6577a에서 haptic feedback만 제거하여 테스트하면 가설 2 검증 가능. 또는 현재 코드에서 setupFaceButtonOverlay() 내부의 LiquidGlassKit 컴포넌트를 lazy/비동기로 생성하는 방식으로 해결 시도.

---

## 병목 원인 분석

### 두 가지 다른 병목 패턴 발견

**패턴 A: setViewControllers 병목 (decb029, 1/28 이전)**
- setViewControllers: **1,623ms**, faceButtonOverlay: 2.8ms (정상)
- iOS 18 네이티브 zoom transition의 `preferredTransition = .zoom` 설정이 1,648ms
- push 자체도 3,810ms
- 원인: iOS 18 zoom transition의 sourceViewProvider 클로저 내부 처리가 무거운 것으로 추정

**패턴 B: faceButtonOverlay 병목 (f296691 이후, 현재)**
- faceButtonOverlay: **7,914ms**, setViewControllers: 1.4ms (정상)
- `GlassCircleButton` (LiquidGlassKit 기반) 초기화가 무거운 것으로 추정
- `BackdropView` 렌더링 경고 다수 발생

**d34059e ~ bd6577a 구간은 두 병목 모두 없음** (커스텀 줌 트랜지션 도입으로 패턴 A 해소, f296691 이전이라 패턴 B 미발생)

### LiquidGlassKit BackdropView 경고

```
Rendering a view (LiquidGlassKit.BackdropView) that has not been rendered at least once requires afterScreenUpdates:YES.
```

→ 모든 커밋에서 발생하지만 bd6577a까지는 성능 영향 없음. f296691에서 병목화.

---

## 세분화 타이밍 측정 (e88957b, 현재)

### 측정 결과

```
setupFaceButtonOverlay [7,925.8ms]
  └─ FaceButtonOverlay() [7,925.3ms]
       └─ setupUI → toggleButton lazy생성 [7,924.6ms]
            └─ GlassCircleButton.init(eye.fill) [7,918.3ms 중 setupLayers]
                 └─ setupLayers [7,918.3ms]
                      ├─ contractedView (LiquidGlassEffect + VisualEffectView): 3,786.8ms
                      └─ expandedView  (LiquidGlassEffect + VisualEffectView): 4,131.4ms
                      └─ iconImageView: 0.0ms

setupLoadingIndicator [3.4ms] ← 정상 (LiquidGlassKit 미사용)

setViewControllers [2,395.0ms] ← 이번 측정에서는 높음 (비결정적)
```

### 병목 확정

| 구간 | 시간 | 비율 |
|------|------|------|
| `LiquidGlassEffect` 1번째 (contractedView) | **3,786.8ms** | 36% |
| `LiquidGlassEffect` 2번째 (expandedView) | **4,131.4ms** | 40% |
| `setViewControllers` | **2,395.0ms** | 23% |
| 기타 (setupIcon, haptic, addSubview 등) | ~6ms | <1% |
| **총** | **~10,350ms** | 100% |

### 핵심 원인

**`LiquidGlassEffect(style: .regular, isNative: true)` + `VisualEffectView(effect:)` 생성이 cold start에서 각각 ~4초 소요.**

- `GlassCircleButton`은 contracted + expanded 2개의 `LiquidGlassEffect`를 생성
- 합계 **~7.9초**가 `setupLayers()` 한 함수에서 소비
- 이것은 LiquidGlassKit 프레임워크의 `BackdropView` 첫 렌더링 초기화 비용
- 2번째 탭부터는 시스템 캐시 상태로 인해 5ms 수준으로 정상화
- `setViewControllers`의 비결정적 병목도 동일 원인 (LiquidGlassKit 프레임워크 로딩 부하)

### 호출 경로

```
GridVC.didSelectItemAt
  → ViewerVC.viewDidLoad
    → displayInitialPhoto → setViewControllers [2,395ms, 비결정적]
    → setupSimilarPhotoFeature
      → setupFaceButtonOverlay
        → FaceButtonOverlay()
          → setupUI → toggleButton (lazy)
            → GlassCircleButton.init
              → setupLayers
                → contractedView = VisualEffectView(LiquidGlassEffect) [3,787ms]
                → expandedView = VisualEffectView(LiquidGlassEffect)   [4,131ms]
```

---

## LiquidGlassKit 내부 구조 분석

### LiquidGlassView 생성 시 일어나는 일

LiquidGlassKit 소스 (`DerivedData/SourcePackages/checkouts/LiquidGlassKit/`) 확인 결과:

```
VisualEffectView(effect: LiquidGlassEffect)
  → LiquidGlassEffectView(effect:)
    → LiquidGlassView(liquidGlass)          ← MTKView 서브클래스
         ├─ backdropView = BackdropView()    ← 프로퍼티 기본값 (init 전 실행, CABackdropLayer)
         ├─ LiquidGlassRenderer.shared.device 접근
         │    └─ (첫 접근 시) LiquidGlassRenderer.init()  ← @MainActor 싱글톤
         │         ├─ MTLCreateSystemDefaultDevice()       ← GPU 리소스 할당
         │         ├─ device.makeDefaultLibrary(bundle:)   ← Metal 라이브러리 로드
         │         └─ device.makeRenderPipelineState()     ← Metal shader JIT 컴파일 (540줄 셰이더)
         ├─ super.init(frame: .zero, device:)              ← MTKView 초기화
         └─ setupMetal()
              ├─ device.makeCommandQueue()                 ← 인스턴스별 생성
              ├─ device.makeBuffer(length:)                ← Uniforms 버퍼
              └─ ZeroCopyBridge(device:)                   ← CVMetalTextureCache 생성
```

### 리소스 공유 구조

| 리소스 | 공유 방식 | 비고 |
|--------|----------|------|
| MTLDevice | 싱글톤 (`LiquidGlassRenderer.shared`) | 앱 전체 1개 |
| MTLRenderPipelineState | 싱글톤 | 셰이더 컴파일 결과 |
| MTLCommandQueue | **인스턴스별 독립 생성** | 공유 가능하나 안 함 |
| CVMetalTextureCache | **인스턴스별 독립 생성** | 공유 가능하나 안 함 |
| BackdropView (CABackdropLayer) | **인스턴스별 독립 생성** | 뷰별로 필요 |
| MTLBuffer (uniforms) | **인스턴스별 독립 생성** | 뷰별로 필요 |

### 앱 코드 구조 문제

**GlassCircleButton의 dual-state 구조:**

버튼의 pressed 애니메이션(크로스페이드)을 위해 `LiquidGlassView`를 **2개** 보유:
- `contractedView`: tintColor 있음, resting 상태에서 표시
- `expandedView`: tintColor 없음, pressed 상태에서 표시
- 터치 시 contractedView가 확대되며 사라지고, expandedView가 원래 크기로 나타남

→ GlassIconButton, GlassTextButton도 동일 구조

**뷰어에서 생성되는 총 LiquidGlassView 수:**

```
뷰어 열 때:
  backButton (GlassIconButton)     → LiquidGlassView 2개
  deleteButton (GlassIconButton)   → LiquidGlassView 2개
  toggleButton (GlassCircleButton) → LiquidGlassView 2개
  ────────────────────────────────
  총 6개의 LiquidGlassView
```

### 근본 원인에 대한 핵심 관찰

**리소스 중복(6세트)은 개선 사항이지 근본 원인이 아님.**

- 리소스 중복이 원인이라면 **매번** 느려야 함
- 2번째 탭부터 빠른 것은 commandQueue, ZeroCopyBridge 등이 원래 빠른 작업이기 때문
- **첫 번째에서만 느린 이유 = 1회성 시스템 초기화 비용** (Metal shader 컴파일, MTKView 프레임워크 로딩, BackdropView 첫 렌더링 등)

**그런데 bd6577a에서는 동일한 LiquidGlassKit + 동일한 GlassCircleButton인데 25ms였음.**

→ 1회성 초기화 비용이 **앱 시작 시 다른 경로에서 먼저 소화**되었기 때문으로 추정
→ bd6577a에서는 앱 시작 시 FloatingOverlayContainer → LiquidGlassTabBar 경로에서 LiquidGlassEffect가 먼저 생성되어 워밍업이 완료된 상태였을 가능성

### 추가 발견: 빌드 후 첫 실행에서만 발생

- **빌드(Xcode Run) 후 첫 실행**: 7~20초 랙 발생
- **앱 완전 종료 후 아이콘으로 재실행**: 랙 없음, 바로 열림

→ 빌드 시 Metal shader 디스크 캐시가 무효화되어 첫 실행 시 재컴파일되는 것으로 추정.

**그러나 bd6577a도 빌드 후 첫 실행인데 25ms로 빨랐음.** shader 캐시 무효화만으로는 설명 불가.

### 현재까지의 결론

느려지려면 **두 조건이 동시에** 필요:

1. **빌드 후 첫 실행** (shader 캐시 무효화 상태)
2. **f296691 이후 코드** (뭔가가 달라짐)

bd6577a에서는 조건 1은 동일하지만 빠름 → 앱 시작 시 **다른 경로에서 LiquidGlass가 먼저 초기화**되어, 빌드로 인한 캐시 재컴파일 비용이 뷰어 열기 전에 이미 소화되었을 가능성.

### 다음 단계

1. **bd6577a vs 현재(e88957b)의 앱 시작 시 LiquidGlass 초기화 순서 비교**
   - FloatingOverlayContainer → LiquidGlassTabBar lazy 초기화 트리거 시점
   - 워밍업 경로가 끊어진 지점을 찾으면 직접적인 해결 가능
2. **실 사용자 영향도: 높음**
   - 모든 테스트는 실기기에서 수행 (시뮬레이터 아님)
   - 앱 스토어에서 처음 설치한 사용자도 shader 캐시 없는 상태이므로 **첫 뷰어 열기에서 동일한 랙 발생 예상**
   - 앱 종료 후 재실행 시에는 shader 캐시가 유지되어 정상

---

## 참고: 이전 확인된 사항

- **1/28 이전 (decb029 등)**: 병목 있음 (패턴 A: setViewControllers + iOS 18 zoom)
- **1/29 (d34059e) ~ 1/30 (bd6577a)**: 병목 없음 (두 패턴 모두 해소)
- **1/30 (f296691) 이후**: 병목 있음 (패턴 B: faceButtonOverlay)
- 캐시/시뮬레이터 문제가 아닌 **코드 변경에 의한 회귀**임이 확인됨

---

## 추가 조사 (2026-02-02)

### 1. 워밍업 실험 — 가설 부정

**가설**: 앱 시작 시 LiquidGlassEffect를 미리 생성하면 뷰어 열기 시 Hang이 사라질 것.

**구현**: SceneDelegate `scene(_:willConnectTo:)`에서 window 설정 직후:
```swift
let warmupEffect = LiquidGlassEffect(style: .regular, isNative: true)
let warmupView = VisualEffectView(effect: warmupEffect)
warmupView.frame = CGRect(x: -100, y: -100, width: 1, height: 1)
window.addSubview(warmupView)
window.layoutIfNeeded()
warmupView.removeFromSuperview()
```

**결과**: 워밍업 자체는 1,175.8ms에 완료되었으나, 뷰어 진입 시 Hang 7.36s **여전히 발생**.

→ **워밍업 가설 부정**. "같은 초기화를 반복"이 아니라 "매번 다른 문제가 발생"하는 것.
→ 실험 코드는 제거 완료.

### 2. Xcode Pause 디버깅 (bt / bt all)

Hang 진행 중 Xcode Pause(Control+Cmd+Y) → LLDB `bt all`로 모든 스레드의 콜스택 캡처.

#### 1차 Pause (탭 직후)

```
Thread #1 (Main Thread):
  UIActivityIndicatorView type metadata accessor  ← Swift 타입 메타데이터 로드에서 블로킹
    AnalysisLoadingIndicator.setupUI()
      AnalysisLoadingIndicator.init()
        ViewerViewController.setupLoadingIndicator()
          ViewerViewController.setupSimilarPhotoFeature()
            ViewerViewController.viewDidLoad()
```

→ Swift 런타임의 type metadata accessor에서 멈춰있었음. 정상적이라면 즉시 완료되어야 하는 작업.

#### 2차 Pause (탭 후 2~3초)

**Thread #1 (메인 스레드) — SF Symbol 벡터 렌더링 중 (CPU 작업)**
```
CoreGraphics`aa_render                     ← 안티앨리어싱 벡터 렌더링
  CoreUI`CUIVectorGlyphLayer drawInContext  ← SF Symbol 벡터 글리프
    UIImageView._setImage
      GlassCircleButton.setupIcon()         ← 아이콘 설정
        FaceButtonOverlay.toggleButton.getter
          FaceButtonOverlay.setupUI()
            ViewerViewController.viewDidLoad()
```

**Thread #9 — CHHapticEngine XPC 동기 대기**
```
mach_msg2_trap
  xpc_connection_send_message_with_reply_sync
    __NSXPCCONNECTION_IS_WAITING_FOR_A_SYNCHRONOUS_REPLY__
      AVAudioSession privateCreateSessionInServerUsingXPC:
        CHHapticEngine initWithAudioSession:
          _UIFeedbackCoreHapticsEngine _internal_createCoreHapticsEngine
            _UIFeedbackEngine _internal_prewarmEngine
```
→ `feedbackGenerator.prepare()` → CHHapticEngine → AVAudioSession XPC 서버 **동기 응답 대기**
→ 이전 로그의 `CHHapticEngine error: Server timeout`의 정체

**Thread #36 — AudioToolbox dlopen (동적 라이브러리 로드)**
```
dyld`dlopen_from
  AudioToolboxCore`GetAudioDSPManager
    AudioToolboxCore`AudioComponentFindNext
      AudioConverterPrepare
```
→ 오디오 컴포넌트 탐색 중 동적 라이브러리 로드. dlopen은 전역 dyld 락을 잡음.

**Thread #30~33 — H11ANEServices (Apple Neural Engine)**
→ 4개의 ANE 스레드 mach_msg 대기 중 (Vision/CoreML 관련)

**Thread #37 — PHImageRequest**
→ PhotoKit 이미지 디코딩 (백그라운드, 정상)

#### Pause 디버깅에서 발견한 중요 사실

- Continue 누르자마자 뷰어가 바로 열림 → **Pause 중에 시스템 서비스(Metal 컴파일러 등)가 별도 프로세스에서 계속 작업을 진행**하여, Continue 시점에 이미 완료됨
- 메인 스레드가 시스템 서비스 응답을 동기적으로 기다리고 있다는 증거

### 3. feedbackGenerator 제거 테스트 — 원인 아님

**가설**: GlassCircleButton의 `feedbackGenerator.prepare()`가 CHHapticEngine XPC 체인을 유발하여 메인 스레드를 간접 블로킹.

**방법**: GlassCircleButton.swift에서 feedbackGenerator 관련 3줄 제거 (프로퍼티, prepare(), impactOccurred())

**결과**:
| 구간 | 수치 |
|------|------|
| setupIcon | **3,072.7ms** |
| setupLoadingIndicator | **2,649.7ms** |
| setViewControllers | **1,861.9ms** |
| Hang 감지 | **7.65s** |
| 탭~화면표시 총 | **7,997.7ms** |

→ **feedbackGenerator는 원인이 아님.** Hang 7.65s로 동일.
→ CHHapticEngine XPC 대기는 별도 스레드(#9)에서 진행되어 메인 스레드에 직접 영향 없음.
→ 제거 코드 롤백 완료.

### 4. 현재까지의 결론 업데이트

**확인된 사실:**
- 메인 스레드는 "블로킹 대기"뿐 아니라 **실제 CPU 작업**(SF Symbol 렌더링, UIKit 초기화)도 오래 걸림
- 시간 분포 예시: setupIcon 3,072ms + loadingIndicator 2,649ms + setViewControllers 1,861ms = ~7.5초
- CHHapticEngine XPC 타임아웃은 별도 스레드 → 메인 스레드 Hang의 직접 원인이 아님
- 워밍업(LiquidGlass 사전 초기화)도 효과 없음

**아직 미해결:**
- 같은 UIKit/LiquidGlassKit 초기화인데 **왜 bd6577a에서는 빠르고 f296691부터 느린가?**
- bd6577a..f296691 diff에서 직접적 원인 코드를 찾지 못함
- feedbackGenerator 제거도, 워밍업도 효과 없음

**다음 단계:**
1. **bd6577a를 체크아웃하여 현재 환경에서 빠른지 재확인** — 빠르면 f296691 변경을 그룹별로 적용하면서 좁히기
2. 또는 **Instruments Time Profiler**로 Hang 구간의 전체 콜스택 자동 샘플링

---

## 근본 원인 특정 (2026-02-02 후반)

### 1. git worktree로 bd6577a 재확인

`git worktree add ../iOS-test bd6577a`로 별도 폴더에 bd6577a 코드를 꺼내서 Xcode 빌드/테스트.

**결과**: Hang 0.78초 (디버거 연결 상태). → **bd6577a는 현재 환경에서도 빠름 확정.**

### 2. 그룹별 변경 적용 테스트

bd6577a..f296691 diff의 6개 파일을 3그룹으로 나누어 순차 테스트:

| 그룹 | 파일 | 변경 내용 |
|------|------|-----------|
| A | GlassIconButton + GlassTextButton | feedbackGenerator 제거 |
| B | ZoomAnimator + ZoomTransitionController | isInteractiveDismiss 추가 |
| C | QualityAnalyzer + CompareAnalysisTester | Vision continuation 보호 |

**Group A 적용 (feedbackGenerator 둘 다 제거):**

| 테스트 | Hang |
|--------|------|
| bd6577a + Group A (1차) | **9.71초** |
| bd6577a + Group A (2차) | **6.53초** |

→ **Group A가 원인 확정.** Group B, C 테스트 불필요.

### 3. 개별 파일 좁히기

| 테스트 | Hang |
|--------|------|
| GlassIconButton만 제거 (GlassTextButton 복원) | **없음** |
| GlassTextButton만 제거 (GlassIconButton 복원) | **없음** |

→ **둘 다 제거해야 Hang 발생.** 하나라도 feedbackGenerator.prepare()가 있으면 정상.

### 4. 현재 코드(001-auto-cleanup)에 적용

GlassIconButton에 feedbackGenerator를 다시 추가 (프로퍼티 + prepare() + impactOccurred()).

**결과**: **Hang 없음. 해결 확인.**

### 5. 근본 원인 분석

`feedbackGenerator.prepare()`가 CHHapticEngine → AVAudioSession → AudioToolbox 시스템 서비스를 **미리 초기화(워밍업)**하는 부수 효과가 있었음. 이 워밍업이 LiquidGlassKit의 Metal/dyld cold-start 블로킹을 방지해주고 있었는데, f296691에서 GlassIconButton + GlassTextButton 모두에서 feedbackGenerator를 제거하면서 워밍업이 사라지고 Hang 발생.

**핵심 메커니즘:**
- feedbackGenerator.prepare() → CHHapticEngine 초기화 → AudioToolbox dyld 로딩 (백그라운드)
- 이 백그라운드 로딩이 LiquidGlassKit MTKView 초기화 시 필요한 dyld 글로벌 락 경합을 미리 해소
- 하나라도 있으면 충분 (시스템 서비스는 한 번만 초기화되면 됨)

**해결**: GlassIconButton에 feedbackGenerator 복원. GlassTextButton은 햅틱 불필요하여 복원하지 않음.

---

## 인사이트

### 1. "코드 제거 = 안전하다"는 편견

코드를 추가하면 문제가 생길 수 있다고 생각하지, 제거가 문제를 일으킨다고는 잘 생각하지 않는다. 특히 `feedbackGenerator`처럼 주 기능과 무관해 보이는 코드는 "정리" 대상이 되기 쉬운데, 그 코드가 시스템 서비스 워밍업이라는 **보이지 않는 부수 효과**를 갖고 있었다. 실제로 "성능 개선을 위한 정리"가 오히려 cold-start Hang의 원인이 되었다.

### 2. 증상 위치 ≠ 원인 위치

Hang이 `setupLayers`, `setupIcon`, `loadingIndicator` 등 매번 다른 곳에서 발생했다. 원인은 그 함수들이 아니라, 그 이전에 호출되어야 할 `feedbackGenerator.prepare()`의 부재였다. 증상이 비결정적으로 나타나면 원인은 다른 곳에 있을 가능성이 높다.

### 3. git bisect + 그룹별 적용의 위력

코드 리뷰, bt all, Time Profiler 같은 분석 도구로는 이 원인을 찾기 어려웠다. 결국 **"이 커밋에서는 빠르고, 저 커밋에서는 느리다"**를 기반으로 변경을 그룹별로 적용하며 좁혀가는 방식이 결정적이었다. 원인을 이해하지 못해도 특정할 수 있는 방법이다.

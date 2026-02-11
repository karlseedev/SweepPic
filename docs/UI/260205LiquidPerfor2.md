# LiquidGlassKit 렌더링 파이프라인 최적화

> **선행 문서**: [260131LiquidPerfor1.md](260131LiquidPerfor1.md) — MTKView 최적화 (Phase 1~6 완료)

## 목표

**스크롤 중 blur 대체 없이 LiquidGlass 효과를 유지하면서 Good(< 5ms/s) 히치 달성.**

### 현재 상황

| 모드 | Hitch Ratio | FPS | 등급 |
|------|-------------|-----|------|
| blur 대체 ON (현재 사용 중) | 0.0 ms/s | 119 | Good |
| blur 대체 OFF, MTKView 3개 active | 292 ms/s | 84 | Critical |

스크롤 시 blur 대체(Optimizer.optimize)로 전환하여 성능을 확보하고 있지만,
LiquidGlass 굴절 효과가 사라지는 UX 트레이드오프가 있음.

### 목표 수치

- 스크롤 중 LiquidGlass 3개 active 상태에서 **hitch < 5ms/s Good**
- 현재 292ms/s → **98% 감소** 필요

### 병목 3곳 (LiquidGlassKit fork 분석)

| # | 병목 | 위치 | 문제 |
|---|------|------|------|
| ① | captureBackground() | LiquidGlassView.swift | 매 프레임 전체 윈도우 뷰 계층 렌더링 (CPU) |
| ② | blurTexture() | LiquidGlassView.swift | MPSImageGaussianBlur + waitUntilCompleted() 동기 대기 (CPU+GPU) |
| ③ | Fragment shader | LiquidGlassFragment.metal | 541줄: SDF, 굴절, 프레넬, 글레어, LCH 변환 (GPU) |

### 최적화 방안 (8개)

| # | 병목 | 방안 | UX 영향 | 기대 효과 |
|---|------|------|---------|----------|
| 1 | ② blur | waitUntilCompleted 제거 | 없음 | CPU 블로킹 제거 |
| 2 | ② blur | blur 비활성화 (radius 0.3→0) | 거의 없음 | blur 연산 완전 제거 |
| 3 | ② blur | MPS blur 커널 재사용 | 없음 | 프레임당 할당 제거 |
| 4 | ③ shader | ~~float → half 전환~~ | — | ~~스킵~~ (이미 최적화됨) |
| 5 | ③ shader | Function Constants (스크롤 중 경량 모드) | 스크롤 중 프레넬/글레어 OFF | shader 비용 30~50% 감소 |
| 6 | ③ shader | 축소 해상도 렌더링 (drawableSize 1/2) | 엣지 약간 소프트 | fragment 호출 75% 감소 |
| 7 | ① 캡처 | 캡처 주기 낮추기 (3~5프레임마다) | 유리 뒤 배경 약간 지연 | CPU 캡처 60~80% 감소 |
| 8 | ① 캡처 | 캡처 해상도 낮추기 (0.2→0.1) | 유리 뒤 더 뿌옇게 | 캡처 비용 75% 감소 |

**UX 손상 없음**: 1, 2, 3 (그룹 A — 우선 적용)
**약간의 트레이드오프**: 5, 6, 7, 8 (그룹 C — 필요 시 추가 적용)
**스킵**: ~~4~~ (셰이더 이미 최적화됨)

### 구현 그룹

| 그룹 | 방안 | 수정 범위 | 비고 |
|------|------|----------|------|
| **A** | 1+2+3 (blur 계열) | `blurTexture()` 한 함수 | 병목② 해결 |
| **B** | ~~4 (half precision)~~ | — | **스킵** — 셰이더 이미 최적화됨 |
| **C** | 7→5→6→8 (필요 시) | shader + Swift + Optimizer | 병목①③ 해결 |

> **그룹 B 스킵 사유**: Fragment shader 분석 결과, float 필수 영역(SDF, 굴절, 프레넬, 글레어, LCH)과
> half 이미 사용 영역(텍스처, 출력, UV 오프셋)이 명확히 분리되어 있어 추가 전환 여지 없음.

### 적용 순서

1. **그룹 A** (blur 계열) → 측정 ✅ 완료 (L2 550→65 ms/s, -88%)
2. ~~Good 미달 시 → **C-1** (캡처 주기) → 측정~~ ❌ 롤백됨 (UX 저하)
3. → **C-2** (Function Constants) + **C-3** (축소 해상도) → 측정
4. **C-4** (캡처 해상도)는 단독 또는 C-2/C-3과 조합 가능

> **현실적 예측**: 292ms/s에서 blur(병목②)는 전체의 일부.
> 그룹 A만으로 Good(< 5ms/s) 달성은 어려울 가능성 높음.
> C-1(캡처 주기)이 가장 큰 효과 — captureBackground()(병목①)가 주 병목.

### 대상 파일

| 파일 | 위치 |
|------|------|
| LiquidGlassView.swift | LiquidGlassKit/Sources/LiquidGlassKit/ |
| LiquidGlassFragment.metal | LiquidGlassKit/Sources/LiquidGlassKit/ |
| LiquidGlassVertex.metal | LiquidGlassKit/Sources/LiquidGlassKit/ |
| ZeroCopyBridge.swift | LiquidGlassKit/Sources/LiquidGlassKit/ |

---

## 그룹 A: blur 계열 (방안 1+2+3)

### 현재 코드 (`LiquidGlassView.swift:363-378`)

```swift
func blurTexture() {
    guard liquidGlass.backgroundTextureBlurRadius > 0,  // ← radius 0이면 early return
          let device,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          var backgroundTexture else { return }

    let sigma = Float(liquidGlass.backgroundTextureBlurRadius * layer.contentsScale)
    let blur = MPSImageGaussianBlur(device: device, sigma: sigma)  // ← 매 프레임 새 인스턴스
    blur.edgeMode = .clamp

    blur.encode(commandBuffer: commandBuffer, inPlaceTexture: &backgroundTexture, fallbackCopyAllocator: nil)
    commandBuffer.commit()
    commandBuffer.waitUntilCompleted()  // ← CPU 블로킹 (메인 스레드 정지)
}
```

현재 blur가 사용되는 프리셋: `regular`만 (`backgroundTextureBlurRadius: 0.3`).
`thumb`과 `lens`는 이미 0 → guard에서 스킵됨.

### 적용 전략

방안 2(blur 비활성화)를 적용하면 guard에서 early return → 1과 3은 코드에 도달하지 않음.
따라서 **2를 먼저 적용하고 UX 확인** → 문제 있으면 2 롤백하고 1+3 조합으로 대체.

```
경로 1 (blur OFF):  방안 2 적용 → UX OK → 완료
경로 2 (blur 유지): 방안 2 롤백 → 방안 1+3 적용 → blur 비용만 절감
```

### 방안 2: blur 비활성화 (radius 0.3 → 0)

**수정 파일**: `LiquidGlassView.swift` (1줄)

```swift
// 변경 전 (line 118)
static let regular = Self.init(
    // ...
    backgroundTextureBlurRadius: 0.3,
    // ...
)

// 변경 후
static let regular = Self.init(
    // ...
    backgroundTextureBlurRadius: 0,    // blur 비활성화
    // ...
)
```

**원리**: `blurTexture()`의 첫 guard에서 `backgroundTextureBlurRadius > 0` 체크 → 0이면 즉시 return.
MPS blur 인스턴스 생성, GPU encode, waitUntilCompleted 모두 스킵됨.

**UX 예상**: `regular` 프리셋의 `backgroundTextureScaleCoefficient: 0.2`로 캡처 해상도가 이미 20%로 낮음.
낮은 해상도 자체가 자연스러운 흐림을 만들므로, 추가 blur(sigma 0.3 × contentsScale)의 시각적 기여가 미미.

**테스트**:
1. 빌드 후 Glass 배경이 시각적으로 달라지는지 비교 (스크린샷 Before/After)
2. blur 대체 OFF 상태에서 스크롤 히치 측정

### 방안 1: waitUntilCompleted 제거 (방안 2 롤백 시)

**수정 파일**: `LiquidGlassView.swift` (1줄 삭제)

```swift
// 변경 후
func blurTexture() {
    guard liquidGlass.backgroundTextureBlurRadius > 0,
          let device,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          var backgroundTexture else { return }

    let sigma = Float(liquidGlass.backgroundTextureBlurRadius * layer.contentsScale)
    let blur = MPSImageGaussianBlur(device: device, sigma: sigma)
    blur.edgeMode = .clamp

    blur.encode(commandBuffer: commandBuffer, inPlaceTexture: &backgroundTexture, fallbackCopyAllocator: nil)
    commandBuffer.commit()
    // waitUntilCompleted 제거 — GPU가 비동기로 처리, 결과는 같은 프레임의 draw()에서 사용
}
```

**원리**: blur encode 후 CPU가 기다리지 않고 바로 draw()로 진행.
`draw()` 내부 호출 순서:
```
draw() {
    captureBackground()   → blurTexture() → blur commandBuffer commit  // ①
    commandBuffer = commandQueue.makeCommandBuffer()                    // ②
    encoder.setFragmentTexture(backgroundTexture)  // 같은 텍스처 읽기
    commandBuffer.commit()                                              // ③
}
```
①과 ③이 같은 `commandQueue`에서 순차 commit되므로, Metal이 GPU 실행 순서를 보장함.
blur commandBuffer 완료 후 draw commandBuffer가 실행됨 → **지연 없음, 위험 없음.**

### 방안 3: MPS blur 커널 재사용 (방안 2 롤백 시)

**수정 파일**: `LiquidGlassView.swift` (프로퍼티 추가 + blurTexture 수정)

```swift
// 프로퍼티 추가
private var blurKernel: MPSImageGaussianBlur?

// blurTexture() 변경
func blurTexture() {
    guard liquidGlass.backgroundTextureBlurRadius > 0,
          let device,
          let commandBuffer = commandQueue.makeCommandBuffer(),
          var backgroundTexture else { return }

    // blur 커널 재사용 (sigma가 고정이므로 한 번만 생성)
    if blurKernel == nil {
        let sigma = Float(liquidGlass.backgroundTextureBlurRadius * layer.contentsScale)
        blurKernel = MPSImageGaussianBlur(device: device, sigma: sigma)
        blurKernel?.edgeMode = .clamp
    }

    blurKernel?.encode(commandBuffer: commandBuffer, inPlaceTexture: &backgroundTexture, fallbackCopyAllocator: nil)
    commandBuffer.commit()
    // waitUntilCompleted 제거 (방안 1과 함께 적용)
}
```

**원리**: `MPSImageGaussianBlur`는 스레드 세이프하고 재사용 가능.
sigma가 프리셋에서 고정값이므로 인스턴스 한 번 생성 후 계속 사용.
매 프레임 `alloc + init` 오버헤드 제거.

### 측정 계획

blur 대체 OFF 상태에서 동일 스크롤 테스트 3회:

| 측정항목 | Baseline | 그룹 A (3회 평균) | 변화 |
|---------|----------|------------------|------|
| L1 First Hitch | 292 ms/s | **154.4 ms/s** | **-47%** |
| L2 Steady Hitch | ~550 ms/s | **65.3 ms/s** | **-88%** |
| L1 FPS | 84 | 100.3 | +19% |
| L2 FPS | ~52 | 111.2 | +114% |

> Baseline은 Phase 6 문서의 "blur OFF, MTKView 3개 active" 측정값.

<details>
<summary>3회 개별 측정값</summary>

| | L1 Hitch | L1 FPS | L2 Hitch | L2 FPS |
|---|----------|--------|----------|--------|
| 1회 | 122.1 ms/s | 105.6 | 53.7 ms/s | 113.1 |
| 2회 | 233.6 ms/s | 89.8 | 75.8 ms/s | 110.7 |
| 3회 | 107.4 ms/s | 105.6 | 66.3 ms/s | 109.7 |

> 2회차 L1이 높은 것은 스크롤 시간이 짧았기 때문 (557ms vs 805ms/3060ms).
> L2 Steady는 연속 스크롤 시 점진적으로 개선 (30~55 ms/s까지).

</details>

**UX 확인**: blur 제거 후 시각적 차이 없음 ✅ (0.2 스케일 캡처가 자연스러운 흐림 제공)
**결론**: blur radius 0 하나로 L2 평균 550→65 ms/s 대폭 개선. 여전히 Critical이므로 그룹 C 진행.

---

## 그룹 B: half precision (방안 4) — 스킵

Fragment shader 분석 결과, 셰이더가 이미 half/float 혼합 최적화되어 있음.

| 영역 | 현재 타입 | half 전환 가능? |
|------|----------|----------------|
| SDF, 법선, 굴절 | float | ❌ (pow, asin, tan, sqrt) |
| 프레넬, 글레어 | float | ❌ (pow(x,5), sin, cos) |
| LCH 색공간, 행렬 | float3, float3x3 | ❌ (행렬×벡터, 지수) |
| UV 좌표 | float2 | ❌ (텍스처 정확성) |
| 텍스처 색상 | **half4** | ✅ 이미 사용 중 |
| 최종 출력, UV 오프셋 | **half4, half2** | ✅ 이미 사용 중 |

**결론**: 추가 전환 여지 없음. 스킵.

---

## 그룹 C: 추가 최적화 (방안 5~8)

### 앱 쪽 연동: 로컬 패키지 전환

> **상세 계획**: [260205LiquidPerfor3.md](260205LiquidPerfor3.md) — LiquidGlassKit 로컬 패키지 전환

DerivedData SPM checkout 직접 수정 방식에서는 새 public 심볼 추가 시 모듈 인터페이스가 갱신되지 않아
`import LiquidGlassKit` 후 새 API 접근이 불가했음 (C-1 구현 중 빌드 에러로 확인).

**해결**: LiquidGlassKit을 로컬 패키지(`iOS/LiquidGlassKit/`)로 전환.
- 모든 수정이 git에 추적됨
- public API 자유롭게 추가 가능
- `LiquidGlassSettings` public enum으로 C-1~C-4 설정 제어

### C-1: 방안 7 — 캡처 주기 낮추기 ❌ 롤백됨

> **롤백 사유 (2026-02-03)**: `scrollCaptureInterval = 3` 및 `2`로 테스트했으나,
> Glass 효과의 배경 갱신 지연이 체감되어 UX 저하. C-1 코드 전체 제거.
> 롤백 상세: [260205LiquidPerfor3.md](260205LiquidPerfor3.md) 하단 참조.
>
> `LiquidGlassSettings.swift`는 향후 C-2~C-4에서 활용 가능하므로 유지.

**대상 파일**: `LiquidGlassView.swift`, `LiquidGlassOptimizer.swift`
**병목**: ① captureBackground() — 매 프레임 rootView.layer.render(in:) 호출

**변경**: 프레임 카운터로 N프레임마다 캡처, 나머지는 이전 텍스처 재사용

#### 1단계: LiquidGlassSettings public enum

**새 파일**: `LiquidGlassSettings.swift` (LiquidGlassKit)
```swift
/// LiquidGlassKit 전역 렌더링 설정 (앱에서 import 후 직접 접근)
public enum LiquidGlassSettings {
    /// 배경 캡처 주기 (1=매 프레임, 3=3프레임마다)
    public static var captureInterval: Int = 1
}
```

**LiquidGlassView.swift** — draw() 수정:
```swift
private var frameCounter: Int = 0

override func draw(_ rect: CGRect) {
    if autoCapture {
        frameCounter += 1
        if frameCounter >= LiquidGlassSettings.captureInterval {
            frameCounter = 0
            captureBackground()
        }
    }
    // ... render (backgroundTexture 사용) ...
}
```

**LiquidGlassOptimizer.swift** — 연동:
```swift
import LiquidGlassKit

static var scrollCaptureInterval: Int = 3

// optimize() — mode 분기 전:
LiquidGlassSettings.captureInterval = scrollCaptureInterval

// restore() — mode 분기 전:
LiquidGlassSettings.captureInterval = 1
```

#### 2단계 (1단계 빌드 실패 시): @objc dynamic + KVC

모듈 인터페이스 변경 없이 Objective-C 런타임으로 접근.

**LiquidGlassView.swift**:
```swift
@objc dynamic var captureInterval: Int = 1  // ObjC 런타임 등록, Swift 인터페이스와 무관
private var frameCounter: Int = 0

override func draw(_ rect: CGRect) {
    if autoCapture {
        frameCounter += 1
        if frameCounter >= captureInterval {
            frameCounter = 0
            captureBackground()
        }
    }
    // ... render ...
}
```

**LiquidGlassOptimizer.swift** — KVC로 접근 (`import LiquidGlassKit` 불필요):
```swift
static var scrollCaptureInterval: Int = 3

private static func setCaptureInterval(_ interval: Int, in rootView: UIView) {
    var count = 0
    for mtkView in findAllMTKViews(in: rootView) {
        if mtkView.responds(to: NSSelectorFromString("captureInterval")) {
            mtkView.setValue(interval, forKey: "captureInterval")
            count += 1
        }
    }
    Log.print("[LiquidGlass] captureInterval: \(interval) → \(count)개")
}

// optimize() case .normal: setCaptureInterval(scrollCaptureInterval, in: rootView)
// restore() case .normal: setCaptureInterval(1, in: rootView)
```

**텍스처 재사용 안전성 ✅**: ZeroCopyBridge는 `setupBuffer()`에서 1회 생성한 동일 pixelBuffer/CVMetalTexture를 `render()`마다 덮어씀. captureBackground() 스킵 시 이전 프레임 데이터가 그대로 남아있으므로 안전.

**UX**: 유리 뒤 배경이 2~3프레임 지연 — 빠른 스크롤 중에는 인지 어려움
**기대 효과**: CPU 캡처 비용 60~66% 감소

### C-2: 방안 5 — Function Constants (프레넬/글레어 OFF)

**대상 파일**: `LiquidGlassFragment.metal`, `LiquidGlassRenderer` (싱글톤), `LiquidGlassView.swift`

**셰이더 변경** (`LiquidGlassFragment.metal`):
```metal
// Function Constants 선언 — default=true로 기존 파이프라인 호환 유지
constant bool enableFresnel [[function_constant(0)]] = true;
constant bool enableGlare [[function_constant(1)]] = true;

fragment half4 liquidGlassEffect(...) {
    // ... 기존 코드 ...
    if (enableFresnel) { /* 프레넬 블록 (라인 482~499) */ }
    if (enableGlare) { /* 글레어 블록 (라인 501~530) */ }
}
```

> Function Constants의 `if`는 **컴파일 타임에 제거**됨. 런타임 분기 비용 0.

**Swift 변경** (`LiquidGlassRenderer`):
```swift
// 기존 pipelineState 옆에 경량 버전 추가
let lightPipelineState: MTLRenderPipelineState  // fresnel=false, glare=false

// 기존 makeFunction(name:) → makeFunction(name:constantValues:) 변경
// full: MTLFunctionConstantValues(enableFresnel=true, enableGlare=true)
// light: MTLFunctionConstantValues(enableFresnel=false, enableGlare=false)
```

**LiquidGlassSettings 변경** (LiquidGlassView 인스턴스 프로퍼티 대신 Settings static 사용):
```swift
// LiquidGlassSettings.swift — captureInterval과 동일 패턴
public nonisolated(unsafe) static var useLightMode: Bool = false
```
> View 인스턴스 프로퍼티 대신 Settings static 변수를 사용하는 이유:
> MTKView가 3개 존재하므로 개별 접근보다 전역 1회 설정이 간편.
> Optimizer에서 `LiquidGlassSettings.useLightMode = true/false`로 제어.

**LiquidGlassView.draw() 변경**:
```swift
// draw() 내: Settings 참조로 파이프라인 선택
let pipeline = LiquidGlassSettings.useLightMode
    ? LiquidGlassRenderer.shared.lightPipelineState
    : LiquidGlassRenderer.shared.pipelineState
encoder.setRenderPipelineState(pipeline)
```

**UX**: 스크롤 중 프레넬/글레어 OFF → 반짝임 줄어들지만 굴절/분산은 유지
**UX 확인**: 알고 보지 않으면 모를 정도 ✅
**기대 효과**: shader 비용 30~50% 감소

#### C-2 측정 결과

그룹 A 적용 상태(blur radius 0)에서 C-2 추가 적용 후 측정:

| 측정항목 | 그룹 A only | C-2 추가 (3회 평균) | 변화 |
|---------|------------|-------------------|------|
| L1 First Hitch | 154.4 ms/s | **81.6 ms/s** | **-47%** |
| L2 Steady Hitch | 65.3 ms/s | **25.5 ms/s** | **-61%** |
| L1 FPS | 100.3 | 109.5 | +9% |
| L2 FPS | 111.2 | 115.1 | +4% |

<details>
<summary>3회 개별 측정값</summary>

| | L1 Hitch | L1 FPS | L2 Hitch | L2 FPS |
|---|----------|--------|----------|--------|
| 1회 | 111.4 ms/s | 105.9 | 35.1→23.1 ms/s | 114.7→109.9 |
| 2회 | 93.0 ms/s | 108.0 | 26.6→18.1 ms/s | 116.2→116.1 |
| 3회 | 40.3 ms/s | 114.5 | 46.3→4.0 ms/s | 113.3→119.2 |

</details>

### C-3: 방안 6 — 축소 해상도 렌더링 ✅ 완료

> **상세 구현 기록**: [260210LiquidPerfor2-C3.md](260210LiquidPerfor2-C3.md) — v1/v2 실패 분석, v3 구현

**최종 구현 (v3 — contentScaleFactor 방식):**

v1(autoResizeDrawable 영구 false), v2(autoResizeDrawable 동적 토글) 모두 MTKView 내부 상태 불일치로 실패.
v3는 `contentScaleFactor`만 변경하여 autoResizeDrawable(항상 true)이 drawableSize를 자동 관리.

| 파일 | 변경 |
|------|------|
| `LiquidGlassSettings.swift` | `renderScale: CGFloat = 1.0` 추가 |
| `LiquidGlassOptimizer.swift` | optimize/restore에서 `contentScaleFactor` 설정 + 크로스페이드 복원 |
| `LiquidGlassView.swift` | **변경 없음 (0곳)** |
| `LiquidGlassFragment.metal` | AA 스케일 보정 (저해상도 테두리 계단 현상 방지) |

**기대 효과**: fragment 호출 75% 감소 (renderScale=0.5 시)

#### C-3 측정 결과

그룹 A + C-2 적용 상태에서 C-3 추가 적용 후 측정:

| 측정항목 | A + C-2 | + C-3 (3회 평균) | 변화 |
|---------|---------|-----------------|------|
| L1 First Hitch | 81.6 ms/s | **96.6 ms/s** | +18% (편차 큼) |
| L2 Steady Hitch | 25.5 ms/s | **26.6 ms/s** | 동일 수준 |

<details>
<summary>3회 개별 측정값</summary>

| | L1 Hitch | L2 Hitch |
|---|----------|----------|
| 1회 | ~~0.1 ms/s~~ (이상치) | 30.4, 25.4 ms/s |
| 2회 | 66.2 ms/s | 14.1, 45.8 ms/s |
| 3회 | 126.9 ms/s | 27.0, 16.8 ms/s |

</details>

**분석**: L2가 C-2 단독(25.5)과 거의 동일.
C-3의 fragment 감소 효과보다 **captureBackground() (병목①)이 여전히 지배적**.
C-3은 체감 성능보다는 GPU 부하 경감에 기여 (FPS 유지에 도움).

### C-4: 방안 8 — 캡처 해상도 낮추기 ❌ UX 불합격

**대상 파일**: `LiquidGlassView.swift` (LiquidGlass struct)

현재 `regular` 프리셋: `backgroundTextureScaleCoefficient: 0.2` (20% 해상도)
→ `0.1` (10%)로 변경 시도

**구체 크기** (44×44pt 버튼, contentsScale=3): 26×26px → 13×13px

**기대 효과**: 캡처 텍스처 75% 감소 → render(in:) CPU 비용 감소

**구현**: `LiquidGlassSettings.captureScale` 동적 설정 (optimize 0.5 / restore 1.0)

**결과**: 배경이 너무 이상하게 보여 UX 문제. 해상도가 지나치게 낮아 유리 효과의 배경 품질이 허용 수준 이하.
코드 원복 완료, C-4 미적용.

### C-5: 상시 적용 — 배경 캡처 제거 + 셰이더 간소화

**C-2/C-3 원복 완료**: C-5가 배경 캡처 자체를 제거하므로 C-2(Function Constants), C-3(축소 해상도) 불필요. 원복됨.

#### 핵심 아이디어

`captureBackground()` (`layer.render(in:)`)를 **상시 제거**하고 아키텍처를 2레이어로 단순화:

| 레이어 | 역할 | 담당 |
|--------|------|------|
| **UIVisualEffectView** (아래) | 블러 배경 + 틴트 색상 | 유리 본체 (면) |
| **MTKView 셰이더** (위) | SDF + 글레어 + 바운더리 AA | 테두리 빛남 (선) |

#### 기존 셰이더 8개 효과 → 4개로 축소

| # | 효과 | C-5 이전 | C-5 이후 | 이유 |
|---|------|---------|---------|------|
| 1 | 배경 캡처 | ✅ layer.render | ❌ **제거** | UIVisualEffectView로 대체 |
| 2 | SDF 도형 | ✅ | ✅ 유지 | 모양 정의 (모든 효과의 기반) |
| 3 | 굴절 | ✅ | ❌ **제거** | 배경 텍스처 없음 → 굴절 불가 |
| 4 | 색분산 | ✅ | ❌ **제거** | 굴절의 일부 |
| 5 | 틴트 | ✅ (셰이더) | ❌ **이동** | UIVisualEffectView tintOverlay로 이동 |
| 6 | 프레넬 | ✅ | ❌ **제거** | 전 프리셋 fresnelIntensity: 0 (미사용) |
| 7 | 글레어 | ✅ | ✅ 유지 | 방향성 하이라이트 (SDF만 필요) |
| 8 | 바운더리 AA | ✅ | ✅ 유지 | 테두리 안티앨리어싱 |

**틴트를 UIVisualEffectView로 이동하는 이유**:
- 틴트는 단순한 반투명 색상 오버레이 — 셰이더에서 할 필요 없음
- 셰이더에서 틴트를 빼면 **내부가 완전 투명 (alpha ≈ 0)** → UIVisualEffectView 블러가 100% 비침
- 기존 문제: 셰이더 틴트 alpha ~0.64 → 블러가 36%만 비쳐서 안 보였음 → **자동 해결**

#### blurReplacement 모드와의 비교

| | blurReplacement | C-5 |
|---|---|---|
| UIVisualEffectView | ✅ | ✅ |
| MTKView | isPaused + alpha=0 (완전 숨김) | **계속 렌더링** (테두리 효과만) |
| 셰이더 효과 | ❌ 안 돌아감 | SDF + 글레어 + AA |
| captureBackground | ❌ | ❌ |
| 시각 결과 | 블러 판 (밋밋함) | 블러 판 + **유리 테두리 빛남** |

#### 수정 대상 파일

| 파일 | 변경 내용 |
|------|----------|
| `LiquidGlassFragment.metal` | 굴절/색분산/틴트/프레넬 코드 제거. SDF + 글레어 + AA만 남김. 내부 alpha ≈ 0 출력 |
| `LiquidGlassView.swift` | captureBackground() 호출 제거, transparentTexture 제거, draw() 간소화 |
| `LiquidGlassSettings.swift` | freezeCapture 제거 (항상 캡처 안 함), captureInterval 제거 |
| `LiquidGlassOptimizer.swift` | C-5 블러뷰 관리 (preload에서 항상 생성, 항상 표시) |

#### 구현 결과 ✅ 완료

- **병목① 완전 제거**: `captureBackground()` (`layer.render(in:)`) CPU 비용 0
- **병목② 완전 제거**: `blurTexture()` (MPS Gaussian blur) 호출 없음
- **병목③ 대폭 감소**: 셰이더 8→3개 효과 (프레넬도 제거 — 전 프리셋 미사용), 내부 투명 출력
- **투명도 문제 해결**: 셰이더 내부 alpha ≈ 0 → UIVisualEffectView 블러 비침
- **히치 해결**: 스크롤 중 히치/랙 체감 없음
- **추가 정리**: 프레넬 코드 제거 (전 프리셋 fresnelIntensity: 0), blurView UIKit border 제거 (셰이더 AA와 중복)

---

## 수정 파일 목록

| 파일 | 그룹 | 비고 |
|------|------|------|
| LiquidGlassView.swift | A, C-1, C-2, C-3, C-4 | 로컬 패키지 (`iOS/LiquidGlassKit/`) |
| LiquidGlassSettings.swift | C-1, C-2, C-3 | public enum, 동적 설정 제어 |
| LiquidGlassFragment.metal | C-2 | Function Constants |
| LiquidGlassRenderer (LiquidGlassView.swift 내 싱글톤) | C-2 | lightPipelineState |
| LiquidGlassOptimizer.swift (앱 쪽) | C-1~C-3 연동 | import LiquidGlassKit + Settings |

## 검증

각 그룹/방안 적용 후:
1. blur 대체 OFF 상태에서 스크롤 히치 3회 측정
2. 정지 상태에서 Glass 효과 시각 확인 (엣지, 배경 흐림, 프레넬/글레어)
3. 빌드 성공 확인

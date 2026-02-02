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
| 4 | ③ shader | float → half 전환 | 없음 | GPU 레지스터 50% 절약 |
| 5 | ③ shader | Function Constants (스크롤 중 경량 모드) | 스크롤 중 프레넬/글레어 OFF | shader 비용 30~50% 감소 |
| 6 | ③ shader | 축소 해상도 렌더링 (drawableSize 1/2) | 엣지 약간 소프트 | fragment 호출 75% 감소 |
| 7 | ① 캡처 | 캡처 주기 낮추기 (3~5프레임마다) | 유리 뒤 배경 약간 지연 | CPU 캡처 60~80% 감소 |
| 8 | ① 캡처 | 캡처 해상도 낮추기 (0.2→0.1) | 유리 뒤 더 뿌옇게 | 캡처 비용 75% 감소 |

**UX 손상 없음**: 1, 2, 3, 4 (우선 적용 대상)
**약간의 트레이드오프**: 5, 6, 7, 8 (1~4로 부족할 시 추가 적용)

### 구현 그룹

| 그룹 | 방안 | 수정 범위 | 비고 |
|------|------|----------|------|
| **A** | 1+2+3 (blur 계열) | `blurTexture()` 한 함수 | 병목② 해결 |
| **B** | ~~4 (half precision)~~ | — | **스킵** — 셰이더 이미 최적화됨 |
| **C** | 7→5→6→8 (필요 시) | shader + Swift + Optimizer | 병목①③ 해결 |

> **그룹 B 스킵 사유**: Fragment shader 분석 결과, float 필수 영역(SDF, 굴절, 프레넬, 글레어, LCH)과
> half 이미 사용 영역(텍스처, 출력, UV 오프셋)이 명확히 분리되어 있어 추가 전환 여지 없음.

### 적용 순서

1. **그룹 A** (blur 계열) → 측정
2. Good 미달 시 → **C-1** (캡처 주기) → 측정
3. 여전히 미달 시 → **C-2** (Function Constants) + **C-3** (축소 해상도) → 측정
4. **C-4** (캡처 해상도)는 C-1과 함께 조합 가능

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

| 측정항목 | Baseline (현재) | 그룹 A 적용 후 |
|---------|----------------|---------------|
| L1 First Hitch | 292 ms/s Critical | ? |
| L2 Steady Hitch | ~550 ms/s Critical | ? |
| FPS | 84 | ? |

> Baseline은 Phase 6 문서의 "blur OFF, MTKView 3개 active" 측정값.

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

### 앱 쪽 연동: LiquidGlassView 다운캐스팅

C-1~C-3 모두 LiquidGlassView의 커스텀 프로퍼티를 동적 변경해야 함.
현재 Optimizer는 `MTKView`로만 캐스팅 → `LiquidGlassView` 다운캐스팅 헬퍼 추가 필요.

```swift
// LiquidGlassOptimizer에 추가
static func findAllLiquidGlassViews(in view: UIView) -> [LiquidGlassView] {
    return findAllMTKViews(in: view).compactMap { $0 as? LiquidGlassView }
}
```

### C-1: 방안 7 — 캡처 주기 낮추기

**대상 파일**: `LiquidGlassView.swift`
**병목**: ① captureBackground() — 매 프레임 rootView.layer.render(in:) 호출

**변경**: 프레임 카운터로 N프레임마다 캡처, 나머지는 이전 텍스처 재사용

```swift
// 프로퍼티 추가
var captureInterval: Int = 1        // 1=매 프레임(기존), 3=3프레임마다
private var frameCounter: Int = 0

override func draw(_ rect: CGRect) {
    if autoCapture {
        frameCounter += 1
        if frameCounter >= captureInterval {
            frameCounter = 0
            captureBackground()
        }
    }
    // ... render (backgroundTexture 사용) ...
}
```

**텍스처 재사용 안전성 ✅**: ZeroCopyBridge는 `setupBuffer()`에서 1회 생성한 동일 pixelBuffer/CVMetalTexture를 `render()`마다 덮어씀. captureBackground() 스킵 시 이전 프레임 데이터가 그대로 남아있으므로 안전.

**앱 연동**: Optimizer에서 `findAllLiquidGlassViews()`로 접근:
- 스크롤 시: `captureInterval = 3`
- 정지 시: `captureInterval = 1`

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
```

**LiquidGlassView 변경**:
```swift
var useLightMode: Bool = false
// draw() 내: useLightMode ? lightPipelineState : pipelineState 선택
```

**UX**: 스크롤 중 프레넬/글레어 OFF → 반짝임 줄어들지만 굴절/분산은 유지
**기대 효과**: shader 비용 30~50% 감소

### C-3: 방안 6 — 축소 해상도 렌더링 ⚠️

**대상 파일**: `LiquidGlassView.swift`

**핵심 주의**: drawableSize를 줄이면 `uniforms.resolution`과 불일치 → SDF 계산 깨짐.
→ resolution, contentsScale 모두 renderScale 반영 필수. `autoResizeDrawable = false` 필수.

```swift
var renderScale: CGFloat = 1.0  // 1.0=원본, 0.5=절반

// layoutSubviews: drawableSize 수동 제어
// updateUniforms: effectiveScale = contentsScale * renderScale 반영
```

**부작용**: resolution 변경 → SDF 거리 단위 변경 → cornerRadius 등 형상이 미묘하게 달라질 가능성. 실측 테스트 필수.

**기대 효과**: fragment 호출 75% 감소 (renderScale=0.5 시)

### C-4: 방안 8 — 캡처 해상도 낮추기

**대상 파일**: `LiquidGlassView.swift` (LiquidGlass struct)

현재 `regular` 프리셋: `backgroundTextureScaleCoefficient: 0.2` (20% 해상도)
→ `0.1` (10%)로 변경

**구체 크기** (44×44pt 버튼, contentsScale=3): 26×26px → 13×13px
→ 매우 작음. 배경이 상당히 뿌옇게 보일 수 있음. UX 확인 필수.

**기대 효과**: 캡처 텍스처 75% 감소 → render(in:) CPU 비용 감소

---

## 수정 파일 목록

| 파일 | 그룹 |
|------|------|
| LiquidGlassView.swift | A, C-1, C-2, C-3, C-4 |
| LiquidGlassFragment.metal | C-2 |
| LiquidGlassRenderer (LiquidGlassView.swift 내 싱글톤) | C-2 |
| LiquidGlassOptimizer.swift (앱 쪽) | C-1~C-3 연동 |

## 검증

각 그룹/방안 적용 후:
1. blur 대체 OFF 상태에서 스크롤 히치 3회 측정
2. 정지 상태에서 Glass 효과 시각 확인 (엣지, 배경 흐림, 프레넬/글레어)
3. 빌드 성공 확인

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

| 그룹 | 방안 | 수정 범위 | 측정 |
|------|------|----------|------|
| **A** | 1+2+3 (blur 계열) | `blurTexture()` 한 함수 | 1회 |
| **B** | 4 (half precision) | `.metal` shader 파일 | 1회 |
| **C** | 5~8 (필요 시) | shader + Swift | A+B 결과 보고 결정 |

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

## 그룹 B: half precision (방안 4)

> 그룹 A 측정 후 작성 예정.

**대상 파일**: `LiquidGlassFragment.metal`
**변경 요약**: 셰이더 내 `float` → `half`, `float2/3/4` → `half2/3/4` 전환.
텍스처 샘플링, SDF 계산, 굴절, 프레넬, 글레어, LCH 변환 등 전 영역.

---

## 그룹 C: 추가 최적화 (방안 5~8)

> 그룹 A+B로 Good 미달성 시 작성 예정.

| # | 방안 | 상태 |
|---|------|------|
| 5 | Function Constants (경량 모드) | 대기 |
| 6 | 축소 해상도 렌더링 | 대기 |
| 7 | 캡처 주기 낮추기 | 대기 |
| 8 | 캡처 해상도 낮추기 | 대기 |

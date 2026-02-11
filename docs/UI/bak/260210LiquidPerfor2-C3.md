# C-3 렌더 해상도 축소 — 분석 및 구현 계획

> **상위 문서**: [260205LiquidPerfor2.md](260205LiquidPerfor2.md)
> **작성일**: 2026-02-08
> **상태**: v3 구현 완료 (2026-02-10)

---

## 1. C-3 목표

스크롤 중 Metal drawable 해상도를 절반으로 낮춰 **fragment shader 호출 75% 감소**.

- renderScale=0.5: drawableSize 132→66 (3x Retina → 1.5x)
- 스크롤 종료 시 원본 해상도 완전 복원

---

## 2. 현재 상태

- 브랜치: `001-auto-cleanup`
- **롤백 완료**: 커밋 `63bd08f` (C-3 구현 전 상태)
- 백업 커밋: `352890b` (v1 코드 백업), v2는 커밋 안 됨
- **코드 3개 파일 모두 원본 상태**:
  - `LiquidGlassSettings.swift` — renderScale 없음
  - `LiquidGlassView.swift` — 원본 layoutSubviews/updateUniforms/draw()
  - `LiquidGlassOptimizer.swift` — C-3 코드 없음

---

## 3. v1 구현 및 실패 원인

### v1 변경사항 (4곳)
1. `LiquidGlassSettings.swift`: `renderScale: CGFloat = 1.0` 추가
2. `LiquidGlassView.swift` init: `autoResizeDrawable = false` (영구)
3. `LiquidGlassView.swift` updateUniforms: `scaleFactor = layer.contentsScale * renderScale`
4. `LiquidGlassView.swift` draw(): drawableSize 불일치 감지 → mid-frame 변경
5. `LiquidGlassOptimizer.swift`: renderScale 0.5/1.0 설정

### v1 실패 증상
- 첫 스크롤은 괜찮음
- 반복할수록 정지 시 해상도 저하 (점진적 악화)
- 더 반복 시 버튼 까매짐 → 이후 버튼 연해지고 안 보임

### v1 실패 원인 3가지
1. **updateUniforms에서 renderScale 반영**: `contentsScale = layer.contentsScale * renderScale` → 매 사이클 미세 오차 누적
2. **draw() 안에서 drawableSize 변경**: `currentDrawable` 무효화 → 렌더링 실패 (검정/투명)
3. **autoResizeDrawable = false 영구 설정**: MTKView의 자동 복구 불가

---

## 4. v2 구현 및 실패 원인

### v2 핵심 변경 (v1 대비)
- **updateUniforms 수정 없음** — layer.contentsScale(3.0) 고정
- **draw() 수정 없음** — mid-frame 변경 제거
- **init 수정 없음** — autoResizeDrawable 기본값(true) 유지
- layoutSubviews: `if !autoResizeDrawable { drawableSize = bounds * contentsScale * renderScale }`
- Optimizer: autoResizeDrawable 동적 토글 + drawableSize 직접 설정/복원

### v2 Optimizer 코드
```swift
// optimize:
LiquidGlassSettings.renderScale = 0.5
for mtkView in findAllMTKViews(in: rootView) {
    mtkView.autoResizeDrawable = false
    mtkView.drawableSize = CGSize(
        width: mtkView.bounds.width * mtkView.layer.contentsScale * 0.5,
        height: mtkView.bounds.height * mtkView.layer.contentsScale * 0.5)
}

// restore:
LiquidGlassSettings.renderScale = 1.0
for mtkView in findAllMTKViews(in: rootView) {
    mtkView.drawableSize = CGSize(
        width: mtkView.bounds.width * mtkView.layer.contentsScale,
        height: mtkView.bounds.height * mtkView.layer.contentsScale)
    mtkView.autoResizeDrawable = true
}
```

### v2 실패 증상
- v1과 동일: 정지 시 해상도 완벽 복원 안 됨, 스크롤마다 중첩되는 느낌

### v2 실패 원인 분석

**코드 로직상 누적되는 변수는 없음.** 모든 값이 상수(`bounds * contentsScale`)에서 fresh 계산.

**가장 유력한 원인: MTKView 내부 상태 불일치**

`autoResizeDrawable`을 false→true로 토글 시, MTKView가 내부적으로 drawableSize를 재계산.
이때 `contentScaleFactor`가 리셋되거나 내부 캐시가 꼬이면:
```
기대: drawableSize = 44 * 3.0 = 132 (Full Retina)
실제: drawableSize = 44 * 1.0 = 44  (1x, 해상도 대폭 저하)
```

restore에서 `drawableSize = 132`로 명시 설정해도,
직후의 `autoResizeDrawable = true`가 내부 자동 재계산으로 덮어쓸 수 있음.

**검증 필요**: restore 직후 아래 로그 확인
```swift
print("drawableSize: \(mtkView.drawableSize)")
print("contentScaleFactor: \(mtkView.contentScaleFactor)")
print("contentsScale: \(mtkView.layer.contentsScale)")
```

---

## 5. v3 계획: `contentScaleFactor` 방식

### 핵심 원칙
- **autoResizeDrawable을 건드리지 않음** (항상 true)
- **drawableSize를 직접 설정하지 않음** (autoResizeDrawable이 자동 관리)
- **contentScaleFactor만 변경** → layer.contentsScale 변경 → drawableSize 자동 반영

### 변경 파일

**LiquidGlassSettings.swift** (1곳):
```swift
import CoreGraphics

/// C-3: Render scale
public nonisolated(unsafe) static var renderScale: CGFloat = 1.0
```

**LiquidGlassView.swift** (0곳):
- updateUniforms: **수정 없음** (layer.contentsScale을 그대로 읽음 → 1.5 또는 3.0)
- draw(): **수정 없음**
- init: **수정 없음**
- layoutSubviews: **수정 없음**

**LiquidGlassOptimizer.swift** (2곳):
```swift
// optimize — switch mode 전:
LiquidGlassSettings.renderScale = 0.5
for mtkView in findAllMTKViews(in: rootView) {
    mtkView.contentScaleFactor = UIScreen.main.scale * 0.5  // 3.0 → 1.5
}

// restore — switch mode 전:
LiquidGlassSettings.renderScale = 1.0
for mtkView in findAllMTKViews(in: rootView) {
    mtkView.contentScaleFactor = UIScreen.main.scale  // 1.5 → 3.0
}
```

### 동작 흐름

| 상태 | contentScaleFactor | layer.contentsScale | drawableSize (자동) | uniforms |
|------|-------------------|--------------------|--------------------|----------|
| 앱 시작 | 3.0 (기본) | 3.0 | 132 (자동) | resolution=132, scale=3.0 |
| 스크롤 중 | 1.5 (Optimizer) | 1.5 | 66 (자동) | resolution=66, scale=1.5 |
| 스크롤 종료 | 3.0 (Optimizer) | 3.0 | 132 (자동) | resolution=132, scale=3.0 |

### SDF 정합성 (v1과 동일한 분석, 재검증 완료)

uniforms.resolution과 uniforms.contentsScale이 동일 비율로 변경 → SDF 좌표 비율 불변:
- `normalizedDist = D / resolution.y` → (D/2)/(H/2) = D/H ✓
- `logicalResolution = resolution / contentsScale` → (H*1.5)/1.5 = H ✓
- `rectOriginPx = rect.xy * contentsScale` → 좌표 축소, fragmentPixelCoord도 축소 → 비율 동일 ✓

### 알려진 부작용
- **굴절 강도 ~50% 감소**: offsetUv에서 `contentsScale`(1.5)이 곱해짐 (원본 3.0 대비 절반)
- 스크롤 중에만 일시적, C-2 프레넬/글레어 OFF 상태이므로 체감 미미
- **captureBackground 해상도 감소**: layer.contentsScale 1.5 → 캡처 해상도도 절반
- 스크롤 중이므로 수용 가능, 복원 시 자동 원복
- **zeroCopyBridge 버퍼 크기 변경**: layoutSubviews에서 layer.contentsScale 사용
- 스크롤 시작/종료 시 버퍼 재할당 1회씩 발생

### v1/v2 대비 v3의 장점

| 항목 | v1 | v2 | v3 (계획) |
|------|-----|-----|-----------|
| autoResizeDrawable | 영구 false | 동적 토글 | **변경 없음 (항상 true)** |
| drawableSize | 수동 관리 | 수동 관리 | **자동 관리 (MTKView)** |
| updateUniforms | 수정 (renderScale) | 수정 없음 (불일치) | **수정 없음 (자연 반영)** |
| draw() | 수정 (감지 로직) | 수정 없음 | **수정 없음** |
| LiquidGlassView 변경 | 4곳 | 1곳 | **0곳** |
| 상태 누적 위험 | 있음 (오차 누적) | 있음 (내부 상태) | **없음 (절대값 설정)** |
| 복원 메커니즘 | 수동 계산 | 수동 + autoResize | **UIKit 자동** |

### 잠재 위험 및 대응

1. **UIKit이 contentScaleFactor를 리셋할 수 있음**
   - 대응: 항상 `UIScreen.main.scale` 기반 절대값 설정 (이전 값 참조 안 함)
   - 추가 안전장치: optimize/restore에서 명시적으로 설정하므로 매 사이클 재설정

2. **contentScaleFactor 변경이 sublayer에 영향**
   - 확인: contentScaleFactor는 해당 뷰의 layer.contentsScale만 변경, 자식 뷰 무관

3. **captureBackground 해상도 변경**
   - 수용: 스크롤 중 배경 캡처 해상도 저하는 성능 이점으로 오히려 긍정적

---

## 6. v3 구현 결과 (2026-02-10)

### 변경 파일 4개

| 파일 | 변경 내용 |
|------|----------|
| `LiquidGlassSettings.swift` | `renderScale: CGFloat = 1.0` 추가 + `import CoreGraphics` |
| `LiquidGlassOptimizer.swift` | optimize/restore에 contentScaleFactor 설정 + 크로스페이드 복원 |
| `LiquidGlassView.swift` | **변경 없음 (0곳)** |
| `LiquidGlassFragment.metal` | AA 스케일 보정 (저해상도 계단 현상 방지) |

### 구현 과정에서 발견/해결한 이슈

1. **깜빡임 (blink)**: restore 시 contentScaleFactor 변경과 layout 사이에 1프레임 불일치
   - 해결: `setNeedsLayout()` + `layoutIfNeeded()` 동기 layout 강제

2. **해상도 전환 "띡" 현상**: 저해상도→고해상도 즉시 전환이 눈에 띔
   - 해결: 스냅샷 크로스페이드 (delay 0.05s + fade 0.3s = 총 0.35s)
   - C-2(fresnel/glare 복원)도 같은 크로스페이드에 자연스럽게 포함

3. **테두리 계단 현상**: 저해상도에서 SDF AA 폭이 절반 → 둥근 테두리 우둘투둘
   - 해결: 셰이더에서 `aaScale = 3.0 / contentsScale` → AA 폭을 해상도 비례로 보정
   - 3x: 원본과 동일 / 1.5x: AA 2배 확장 → 항상 ~2px AA 유지

### 커밋 히스토리

| 커밋 | 내용 |
|------|------|
| `cde4379` | C-3 구현 전 롤백 포인트 |
| `30d0b16` | v3 기본 구현 (contentScaleFactor + 크로스페이드) |
| (현재) | + 셰이더 AA 보정 |

### 최종 호출 흐름

```
scrollDidBegin (GridScroll.swift:78)
  → cancelIdleTimer()
  → optimize(in: view.window)
      → useLightMode = true                          (C-2)
      → contentScaleFactor = UIScreen.main.scale * 0.5 (C-3)
      → setNeedsLayout()
      → .normal: resumeAllMTKViews (isPaused = false)

scrollDidEnd (GridScroll.swift:96, 50ms debounce)
  → restore(in: self.view.window)
      → useLightMode = false                          (C-2)
      → snapshot crossfade:                           (C-3)
          1. snapshotView(afterScreenUpdates: false)
          2. contentScaleFactor = UIScreen.main.scale
          3. setNeedsLayout + layoutIfNeeded (동기)
          4. UIView.animate(0.3s, delay 0.05s) → snapshot fadeOut
      → .normal: break
  → enterIdle(in: self.view.window)
      → 0.4s 후 isPaused = true
```

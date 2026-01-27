# LiquidGlassKit 자료 조사

**작성일**: 2026-01-27
**버전**: v1
**저장소**: https://github.com/DnV1eX/LiquidGlassKit

---

## 1. 개요

LiquidGlassKit은 iOS 26의 Liquid Glass 디자인 시스템을 iOS 13-18로 백포트한 라이브러리.

**핵심 특징:**
- iOS 13.0+ 지원
- iOS 26+에서는 네이티브 API 자동 사용
- Metal 셰이더 기반 고품질 렌더링
- App Store 제출 가능 (Public API 옵션 제공)

**저장소 정보:**
- Stars: 157
- Forks: 7
- 생성일: 2025-12-17
- 최종 업데이트: 2026-01-09
- 라이선스: Copyright 2025 DnV1eX

---

## 2. 요구사항

| 항목 | 버전 |
|------|------|
| iOS | 13.0+ |
| Xcode | 14.0+ |
| Swift | 6.2+ |

---

## 3. 컴포넌트

### 3.1. LiquidGlassView (핵심 렌더링 엔진)

Metal 셰이더 기반 유리 효과 렌더링 뷰 (MTKView 상속).

**시각 효과:**
| 효과 | 설명 | 파라미터 |
|------|------|----------|
| Refraction | 굴절 - 빛이 유리 통과할 때 휘는 효과 | `refractiveIndex` (1.45-1.52) |
| Chromatic Dispersion | 색수차 - 가장자리 프리즘 색 분리 | `dispersionStrength` (0.0-0.02) |
| Fresnel Reflections | 프레넬 - 시야각 기반 가장자리 조명 | `fresnelIntensity`, `fresnelEdgeSharpness` |
| Glare Highlights | 글레어 - 방향성 스펙큘러 하이라이트 | `glareIntensity`, `glareDirectionOffset` |
| Shape Merging | 여러 사각형 부드럽게 합치기 | `shapeMergeSmoothness` |

**프리셋:**
```swift
LiquidGlass.regular  // 일반 유리 (Platter 배경용)
LiquidGlass.lens     // 렌즈 효과 (Selection Pill용)
LiquidGlass.thumb()  // 썸네일용 (magnification 조절 가능)
```

**ShaderUniforms 구조체:**
```swift
struct ShaderUniforms {
    var resolution: SIMD2<Float>           // 프레임 크기 (픽셀)
    var contentsScale: Float               // 스케일 팩터 (2 또는 3)
    var touchPoint: SIMD2<Float>           // 터치 위치
    var shapeMergeSmoothness: Float        // 형태 병합 부드러움
    var cornerRadius: Float                // 코너 반경
    var cornerRoundnessExponent: Float     // 1=다이아몬드, 2=원, 4=스퀴클
    var materialTint: SIMD4<Float>         // RGBA 틴트
    var glassThickness: Float              // 유리 두께 (8-16px)
    var refractiveIndex: Float             // 굴절률 (1.45-1.52)
    var dispersionStrength: Float          // 색수차 강도
    var fresnelDistanceRange: Float        // 프레넬 거리 범위
    var fresnelIntensity: Float            // 프레넬 강도 (0.0-1.0)
    var fresnelEdgeSharpness: Float        // 프레넬 가장자리 선명도
    var glareDistanceRange: Float          // 글레어 거리 범위
    var glareAngleConvergence: Float       // 글레어 각도 수렴 (0.0-π)
    var glareOppositeSideBias: Float       // 반대측 하이라이트 강조
    var glareIntensity: Float              // 글레어 강도 (1.0-4.0)
    var glareEdgeSharpness: Float          // 글레어 가장자리 선명도
    var glareDirectionOffset: Float        // 글레어 방향 오프셋 (라디안)
    var rectangleCount: Int32              // 활성 사각형 수
    var rectangles: (SIMD4<Float> × 16)    // 사각형 배열 (최대 16개)
}
```

**배경 캡처 방식:**
| 방식 | iOS 버전 | API | 성능 |
|------|----------|-----|------|
| `captureBackdrop()` | 13-26.1 | CABackdropLayer (Private) | 빠름 |
| `captureRootView()` | 26.2+ | Root View Rendering (Public) | CPU 부하 높음 |

### 3.2. LiquidLensView (탭바 Selection Pill)

iOS 26 `_UILiquidLensView`의 커스텀 구현.

**상태:**
| 상태 | 설명 | 뷰 |
|------|------|-----|
| Resting | 반투명 흰색 pill (alpha 0.3) | `restingPillView` |
| Lifted | 굴절 효과가 있는 유리 | `LiquidGlassView(.lens)` |

**주요 기능:**
- `setLifted(_:animated:alongsideAnimations:completion:)` - 상태 전환
- 가속도 기반 squash/stretch 애니메이션
- Spring 애니메이션 전환 (damping: 0.7-0.8)

**가속도 애니메이션 상수:**
```swift
accelerationWindowDuration: 0.3초      // 가속도 계산 시간 윈도우
accelerationScaleCoefficient: 0.00005  // 가속도 → 스케일 변환 계수
maxScaleDeviation: 0.3                 // 최대 스케일 편차 (±30%)
```

**프로토콜:**
```swift
@MainActor @objc public protocol AnyLiquidLensView {
    init()
    init(restingBackground backgroundView: UIView?)
    var restingBackgroundColor: UIColor? { get set }
    func setLiftedContainerView(_ containerView: UIView?)
    func setLiftedContentView(_ contentView: UIView?)
    func setOverridePunchoutView(_ punchoutView: UIView?)
    func setLifted(_ lifted: Bool, animated: Bool,
                   alongsideAnimations: (() -> Void)?,
                   completion: ((Bool) -> Void)?)
    func setLiftedContentMode(_ contentMode: Int)
    func setStyle(_ style: Int)
    func setWarpsContentBelow(_ warpsContentBelow: Bool)
}
```

### 3.3. LiquidGlassEffectView (UIVisualEffectView 호환)

UIVisualEffectView 대체 래퍼.

**Effect 클래스:**
```swift
// 개별 유리 효과
LiquidGlassEffect(style: .regular, isNative: true)
LiquidGlassEffect(style: .clear, isNative: true)

// 컨테이너 (여러 유리 요소 합성)
LiquidGlassContainerEffect(isNative: true)
```

**팩토리 함수:**
```swift
// iOS 26+: UIVisualEffectView + UIGlassEffect
// iOS 13-25: LiquidGlassEffectView
let view = VisualEffectView(effect: LiquidGlassEffect(style: .regular))
```

### 3.4. LiquidGlassSlider (UISlider 대체)

iOS 26 스타일 슬라이더.

**Dual Thumb State:**
| 상태 | 크기 | 설명 |
|------|------|------|
| Contracted (resting) | 37×24pt | Solid filled pill |
| Expanded (interaction) | 58×38pt | LiquidGlassView 굴절 효과 |

**애니메이션:**
- 확장: Spring (duration: 0.4, damping: 0.6)
- 축소: Spring (duration: 0.6, damping: 0.7)
- Rubber-band physics (경계 넘어가면 탄성)
- Haptic feedback (light/medium impact)

**팩토리:**
```swift
let slider = LiquidGlassSlider.make(isNative: true)
```

### 3.5. LiquidGlassSwitch (UISwitch 대체)

iOS 26 스타일 토글 스위치.

**크기:**
```swift
switchWidth: 63pt
switchHeight: 28pt
contractedThumbWidth: 37pt
contractedThumbHeight: 24pt
expandedThumbWidth: 58pt
expandedThumbHeight: 38.333pt
```

**기능:**
- Dual Thumb State (contracted ↔ expanded)
- Edge-based toggling (가장자리 도달 시 토글)
- Tap vs Drag 구분 (tapTimeThreshold: 0.15초)
- Haptic feedback

**팩토리:**
```swift
let toggle = LiquidGlassSwitch.make(isNative: true)
```

### 3.6. ZeroCopyBridge (성능 최적화)

IOSurface 기반 zero-copy 텍스처 브릿지.

```swift
// Metal 텍스처로 직접 렌더링 (메모리 복사 없음)
backgroundTexture = zeroCopyBridge.render { context in
    rootViewLayer.render(in: context)
}
```

---

## 4. 프로토콜 요약

| 프로토콜 | 네이티브 | 커스텀 |
|----------|----------|--------|
| `AnyVisualEffectView` | UIVisualEffectView | LiquidGlassEffectView |
| `AnyLiquidLensView` | _UILiquidLensView | LiquidLensView |
| `AnySlider` | UISlider | LiquidGlassSlider |
| `AnySwitch` | UISwitch | LiquidGlassSwitch |

---

## 5. Metal 셰이더

### 5.1. 파일 구조

```
LiquidGlassVertex.metal    // 버텍스 셰이더 (fullscreenQuad)
LiquidGlassFragment.metal  // 프래그먼트 셰이더 (liquidGlassEffect)
```

### 5.2. 색수차 구현

```metal
// 굴절률 (RGB 채널별 다름 → 프리즘 효과)
constant float refractiveIndexRed = 1.0f - 0.02f;    // 빨강: 약간 낮음
constant float refractiveIndexGreen = 1.0f;          // 초록: 기준
constant float refractiveIndexBlue = 1.0f + 0.02f;   // 파랑: 약간 높음
```

### 5.3. SDF (Signed Distance Field)

```metal
// Superellipse SDF - 유기적 형태 생성
// exponent: 1=다이아몬드, 2=원, 4=스퀴클
float3 superellipseSDF(float2 point, float scale, float exponent, ...)
```

---

## 6. 애니메이션 패턴

### 6.1. Expand/Contract Morphing

```swift
// 확장 (touchesBegan)
UIView.animate(
    withDuration: 0.4,
    delay: 0,
    usingSpringWithDamping: 0.6,
    initialSpringVelocity: 0
) {
    contractedView.transform = scaleUp
    contractedView.alpha = 0
    expandedView.transform = .identity
    expandedView.alpha = 1
}

// 축소 (touchesEnded)
UIView.animate(
    withDuration: 0.6,
    delay: 0,
    usingSpringWithDamping: 0.7,
    initialSpringVelocity: 0
) {
    expandedView.transform = scaleDown
    expandedView.alpha = 0
    contractedView.transform = .identity
    contractedView.alpha = 1
}
```

### 6.2. Haptic Feedback

```swift
let feedbackGenerator = UIImpactFeedbackGenerator(style: .light)
feedbackGenerator.prepare()
feedbackGenerator.impactOccurred()
```

### 6.3. Rubber-band Effect

```swift
func clampWithRubberBand(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
    if value < min {
        return min - sqrt(min - value)
    } else if value > max {
        return max + sqrt(value - max)
    }
    return value
}
```

---

## 7. 설치 방법

### Swift Package Manager

```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/DnV1eX/LiquidGlassKit.git", from: "1.0.0")
]
```

### Xcode

1. File → Add Packages...
2. URL 입력: `https://github.com/DnV1eX/LiquidGlassKit.git`
3. 버전 선택

---

## 8. 우리 앱(PickPhoto)과의 매핑

### 8.1. 컴포넌트 대응

| 우리 코드 | LiquidGlassKit | 대체 여부 |
|-----------|----------------|----------|
| `LiquidGlassPlatter` | `LiquidGlassView(.regular)` | ✅ 대체 |
| `LiquidGlassShadowContainer` | 내장 (`ShadowView`) | ✅ 삭제 |
| `LiquidGlassSelectionPill` | `LiquidLensView` | ✅ 대체 |
| `LiquidGlassStyle` | 내장 | ✅ 대부분 삭제 |
| `LiquidGlassConstants` | 일부 유지 | ⚠️ 크기/레이아웃만 |
| `LiquidGlassTabButton` | 없음 | ❌ 유지 |
| `LiquidGlassTabBar` | 없음 | ❌ 유지 (내부만 교체) |
| `GlassButton` | 없음 | ⚠️ LiquidGlassView 통합 |
| `VideoControlsOverlay` (UISlider) | `LiquidGlassSlider` | ❌ 부적합 (미니멀 유지) |

### 8.2. GlassButton 개선 방향

**현재 (GlassButton.swift):**
```swift
// 눌리면 작아짐
let scale: CGFloat = isPressed ? 0.96 : 1.0
```

**iOS 26 스타일 (LiquidGlassKit 패턴):**
```swift
// 눌리면 커지면서 굴절 효과 + 햅틱
touchesBegan → expandThumb() + haptic
touchesEnded → contractThumb()
```

---

## 9. 주의사항

### 9.1. App Store 제출

- iOS 26.2 이전: `CABackdropLayer` (Private API) 사용 가능
- iOS 26.2 이후: Root View Rendering (Public API)만 동작
- 라이브러리가 자동으로 적절한 방식 선택

### 9.2. 성능

- Metal 셰이더 기반으로 GPU 가속
- `captureRootView()`는 CPU 부하 높음 (iOS 26.2+)
- `ZeroCopyBridge`로 메모리 복사 최소화

### 9.3. 제한사항

- 버튼 컴포넌트 없음 (직접 구현 필요)
- `LiquidGlassEffect.Style.clear`는 아직 `.regular`와 동일 (TODO)

---

## 10. iOS 26 네이티브 API vs LiquidGlassKit 비교

### 10.1. 기능 비교표

| 기능 | iOS 26 네이티브 | LiquidGlassKit | 비고 |
|------|----------------|----------------|------|
| 굴절 (Refraction) | ✅ | ✅ | Metal 셰이더 |
| 색수차 (Chromatic Dispersion) | ✅ | ✅ | Metal 셰이더 |
| 프레넬/글레어 | ✅ | ✅ | Metal 셰이더 |
| GlassEffectContainer | ✅ | ❌ 없음 | 여러 요소 자동 병합 |
| glassEffectID (모핑) | ✅ | ❌ 없음 | Namespace 기반 전환 |
| matchedTransitionSource | ✅ | ❌ 없음 | Sheet 모핑 전환 |
| .interactive() 자동 효과 | ✅ | ❌ 없음 | 터치 시 스케일/반짝임 |
| UIGlassContainerEffect | ✅ | ⚠️ 일부 | LiquidGlassContainerEffect |
| LiquidLensView (탭바 pill) | ✅ (_UILiquidLensView) | ✅ | squash/stretch 포함 |
| Slider/Switch | ✅ | ✅ | Dual Thumb State |

### 10.2. iOS 26 네이티브 전용 기능

#### GlassEffectContainer (SwiftUI)

여러 glass 요소를 하나의 그룹으로 묶어 자동 병합/모핑:

```swift
GlassEffectContainer(spacing: 30) {
    Button("A") { }.glassEffect()
    Button("B") { }.glassEffect()
    // spacing 이하 거리면 자동으로 "액체처럼" 합쳐짐
}
```

**spacing 파라미터:**
- 요소 간 거리가 이 값 이하면 시각적으로 병합
- 전환 시 유동적 모핑 애니메이션 적용

#### glassEffectID + Namespace (모핑 전환)

```swift
@State private var isExpanded = false
@Namespace private var namespace

GlassEffectContainer(spacing: 30) {
    Button {
        withAnimation(.bouncy) { isExpanded.toggle() }
    } label: {
        Text(isExpanded ? "Collapse" : "Expand")
    }
    .glassEffect()
    .glassEffectID("main", in: namespace)

    if isExpanded {
        Button("Action 1") { }
            .glassEffect()
            .glassEffectID("action1", in: namespace)

        Button("Action 2") { }
            .glassEffect()
            .glassEffectID("action2", in: namespace)
    }
}
```

**요구사항:**
- 같은 `GlassEffectContainer` 내부
- 각 뷰에 `glassEffectID(_:in:)` 적용
- 같은 `@Namespace` 공유
- `withAnimation(.bouncy)` 등으로 상태 변경

#### Sheet 모핑 전환

Toolbar 버튼에서 Sheet로 유동적 전환:

```swift
@Namespace private var transition
@State private var showInfo = false

NavigationStack {
    ContentView()
        .toolbar {
            ToolbarItem(placement: .bottomBar) {
                Button("Info", systemImage: "info") {
                    showInfo = true
                }
                .matchedTransitionSource(id: "info", in: transition)
            }
        }
        .sheet(isPresented: $showInfo) {
            InfoView()
                .presentationDetents([.medium, .large])
                .navigationTransition(.zoom(sourceID: "info", in: transition))
        }
}
```

#### .interactive() 효과

```swift
Button("Tap Me") { }
    .glassEffect(.regular.interactive())
```

**자동 적용 효과:**
- 터치 시 스케일링 (커짐)
- 바운싱 효과
- 반짝임 (shimmering)

#### UIKit: UIGlassContainerEffect

```swift
// UIKit에서 morphing/grouping
let containerEffect = UIGlassContainerEffect()
containerEffect.spacing = 30

let containerView = UIVisualEffectView(effect: containerEffect)

// 개별 glass 요소 추가
let glassEffect = UIGlassEffect(style: .regular)
let glassView = UIVisualEffectView(effect: glassEffect)
containerView.contentView.addSubview(glassView)
```

### 10.3. Liquid Glass 적용 가이드라인 (Apple)

**적합한 곳:**
- Navigation bars, Toolbars
- Tab bars, Bottom accessories
- Floating action buttons
- Sheets, Popovers, Menus
- Context-sensitive controls
- System-level alerts

**부적합한 곳:**
- Content layers (리스트, 테이블)
- Full-screen backgrounds
- Scrollable content
- Stacked glass layers (glass 위에 glass)

> "Liquid Glass is best reserved for the navigation layer that floats above the content of your app."

### 10.4. Sheet Liquid Glass 적용

**기본 적용:**
```swift
.sheet(isPresented: $show) {
    ContentView()
        .presentationDetents([.medium, .large])  // 부분 높이 필수
        // presentationBackground() 사용하지 않음 → 자동 Liquid Glass
}
```

**Form이 있는 Sheet:**
```swift
.sheet(isPresented: $show) {
    Form {
        // ...
    }
    .scrollContentBackground(.hidden)  // Form 배경 숨김 필수
    .presentationDetents([.medium, .large])
}
```

### 10.5. LiquidGlassKit에 없는 것 요약

| 기능 | 대안 |
|------|------|
| GlassEffectContainer | 직접 구현 또는 iOS 26+에서만 사용 |
| glassEffectID 모핑 | 직접 애니메이션 구현 |
| matchedTransitionSource | 직접 전환 애니메이션 구현 |
| .interactive() | Expand/Contract 패턴으로 유사 구현 |
| UIGlassContainerEffect | LiquidGlassContainerEffect (일부) |

---

## 11. 참고 링크

### 공식 문서
- [Apple Developer - Applying Liquid Glass](https://developer.apple.com/documentation/SwiftUI/Applying-Liquid-Glass-to-custom-views)

### GitHub 저장소
- [LiquidGlassKit](https://github.com/DnV1eX/LiquidGlassKit) - iOS 13-18 백포트
- [LiquidGlassReference](https://github.com/conorluddy/LiquidGlassReference) - iOS 26 Swift/SwiftUI 레퍼런스
- [awesome-liquid-glass](https://github.com/GetStream/awesome-liquid-glass) - 애니메이션 예제 모음
- [LiquidGlassCheatsheet](https://github.com/GonzaloFuentes28/LiquidGlassCheatsheet) - SwiftUI 치트시트

### 기술 문서
- [Liquid Glass Effect Explanation (Medium)](https://medium.com/@aghajari/liquid-glass-ios-effect-explanation-dabadd6414ae)
- [Refractive Glass Shader in Metal](https://medium.com/@victorbaro/implementing-a-refractive-glass-shader-in-metal-3f97974fbc24)
- [GlassEffectContainer in iOS 26 (DEV)](https://dev.to/arshtechpro/understanding-glasseffectcontainer-in-ios-26-2n8p)
- [Morphing glass effect with glassEffectID](https://www.createwithswift.com/morphing-glass-effect-elements-into-one-another-with-glasseffectid/)

### 튜토리얼
- [Exploring tab bars on iOS 26 (Donny Wals)](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/)
- [Designing custom UI with Liquid Glass (Donny Wals)](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
- [Presenting Liquid Glass sheets in SwiftUI](https://nilcoalescing.com/blog/PresentingLiquidGlassSheetsInSwiftUI/)
- [Grow on iOS 26 - UIKit + SwiftUI Hybrid](https://fatbobman.com/en/posts/grow-on-ios26/)

---

## 변경 이력

| 날짜 | 변경 내용 |
|------|-----------|
| 2026-01-27 | 초안 작성 - LiquidGlassKit 전체 기능 조사 |
| 2026-01-27 | iOS 26 네이티브 API vs LiquidGlassKit 비교 추가 |

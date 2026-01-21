# Liquid Glass 기술 스펙

> iOS 26 Liquid Glass를 이해하기 위한 기술 조사 결과

**관련 문서:**
- [260121-LiquidGlass-Code.md](./260121-LiquidGlass-Code.md) - 구현 코드 스니펫
- [260121-LiquidGlass-Plan.md](./260121-LiquidGlass-Plan.md) - 작업 계획 및 체크리스트

---

## 1. Apple 공식 Liquid Glass 특성

| 특성 | 설명 |
|------|------|
| **Lensing** | 빛을 굴절시켜 배경을 왜곡 (전통적 blur와 다름) |
| **Specular Highlights** | 기기 움직임에 반응하는 광택 하이라이트 |
| **Adaptive Shadows** | 배경에 적응하는 그림자 |
| **Rim Light** | 가장자리가 밝게 빛나는 효과 |
| **Interactive** | 터치 시 bounce, shimmer 효과 |

### 내부 구현 (Apple Private API)
```
CABackdropLayer + CASDFLayer + glassBackground filter
→ _UIMultiLayer로 래핑
→ SDF 텍스처 동적 생성
```

---

## 2. iOS 26 API

### Glass Variant (3가지 타입)
| Variant | 투명도 | 용도 |
|---------|-------|------|
| `.regular` | 중간 | 대부분의 UI (기본값) |
| `.clear` | 높음 | 미디어 배경 (디밍 레이어 필요) |
| `.identity` | 없음 | 조건부 비활성화 |

### SwiftUI API
```swift
// 기본 사용
.glassEffect()  // 기본값: .regular, .capsule shape

// 명시적 파라미터
.glassEffect(.regular, in: .capsule, isEnabled: true)

// 메서드 체이닝
.glassEffect(.regular.tint(.blue).interactive())

// 지원 도형
.glassEffect(.regular, in: .circle)
.glassEffect(.regular, in: .ellipse)
.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
.glassEffect(.regular, in: .rect(cornerRadius: .containerConcentric))
```

### GlassEffectContainer (그룹화)
```swift
// 유리 효과 요소들 간 샘플링 영역 공유 + 모핑 전환
GlassEffectContainer(spacing: 40.0) {
    ForEach(icons) { icon in
        IconView(icon).glassEffect()
    }
}
```

### 모핑 전환 (Morphing)
```swift
@Namespace private var namespace

// 요소에 ID 부여
.glassEffect()
.glassEffectID("toggle", in: namespace)

// 상태 변경 시 애니메이션
withAnimation {
    isExpanded.toggle()
}
```

### UIKit API
```swift
// UIGlassEffect 생성
let glassEffect = UIGlassEffect(
    glass: .regular,
    isInteractive: true
)
let effectView = UIVisualEffectView(effect: glassEffect)

// UIGlassContainerEffect (컨테이너용)
let containerEffect = UIGlassContainerEffect()

// UIButton.Configuration
var config = UIButton.Configuration.glass()
```

---

## 3. 접근성 자동 지원

iOS 26 Glass Effect는 시스템 설정에 자동 적응:

| 설정 | 동작 |
|------|------|
| **투명도 감소** 활성화 | 서리(frost) 효과 증가, 더 불투명 |
| **고대비 모드** | 명확한 테두리 자동 추가 |
| **모션 감소** | 탄성/bounce 효과 완화 |

**iOS 16~25 커스텀 구현 시 고려사항:**
```swift
// 투명도 감소 설정 확인
if UIAccessibility.isReduceTransparencyEnabled {
    backgroundAlpha = 0.6  // 기본 0.2 대신
}

// 고대비 모드 확인
if UIAccessibility.isDarkerSystemColorsEnabled {
    borderAlpha = 0.5
    borderWidth = 2.0
}
```

---

## 4. Tab Bar 동작 변경 (iOS 26)

| 기능 | 설명 |
|------|------|
| **자동 축소** | 스크롤 시 탭바가 자동으로 축소됨 |
| **플로팅 스타일** | 콘텐츠 위에 투명하게 떠있는 형태 |
| **그룹화** | 버튼들이 자동으로 glass 그룹으로 묶임 |

```swift
// SwiftUI: 탭바 축소 동작
.tabBarMinimizeBehavior(.onScrollDown)

// 탭바 위 액세서리 버튼
.tabViewBottomAccessory {
    Button("Add") { }
        .glassEffect(.regular.interactive())
}
```

---

## 5. Glass Material 투명도

| Material | 투명도 범위 | 용도 |
|----------|------------|------|
| **Glass Light** | 20-40% opacity (흰색) | 밝은 배경 위 UI |
| **Glass Dark** | 10-30% opacity (검정) | 어두운 배경 위 UI |
| **Glass Accent** | 15% opacity | 색상 틴트 강조 |
| **Tint Opacity** | 20% | 버튼/컨트롤 색상 |

---

## 6. Apple 공식 색상 팔레트

### Primary Colors
| 색상명 | HEX | RGB |
|--------|-----|-----|
| Liquid Blue | #007AFF | 0, 122, 255 |
| Liquid Purple | #AF52DE | 175, 82, 222 |
| Liquid Indigo | #5856D6 | 88, 86, 214 |
| Liquid Teal | #5AC8FA | 90, 200, 250 |

### Semantic Colors
| 색상명 | HEX | RGB |
|--------|-----|-----|
| System Red | #FF3B30 | 255, 59, 48 |
| System Orange | #FF9500 | 255, 149, 0 |
| System Yellow | #FFCC00 | 255, 204, 0 |
| System Green | #34C759 | 52, 199, 89 |

### Neutral Colors
| 색상명 | HEX | RGB |
|--------|-----|-----|
| System Gray | #8E8E93 | 142, 142, 147 |
| System Gray 2 | #AEAEB2 | 174, 174, 178 |
| System Gray 3 | #C7C7CC | 199, 199, 204 |
| Glass Blur | #F2F2F7 | 242, 242, 247 |

---

## 7. 구현 권장 수치 (종합)

여러 소스에서 수치가 다르지만, iOS 느낌을 내기 위한 **권장 수치**:

| 속성 | 권장 값 | 근거 |
|------|--------|------|
| 배경 투명도 (Light) | **20-30%** | Apple 공식 20-40% 중간값 |
| 배경 투명도 (Dark) | **15-20%** | Apple 공식 10-30% 중간값 |
| 테두리 (밝은 쪽) | **35-40%** alpha | Rim Light 좌상단 |
| 테두리 (어두운 쪽) | **8-10%** alpha | Rim Light 우하단 |
| 테두리 두께 | **1.5pt** | 빛나는 느낌 강조 |
| 그림자 opacity | **0.05-0.08** | 부드럽고 미묘하게 |
| 그림자 radius | **20-30pt** | 넓게 퍼지도록 |
| 블러 | **systemUltraThinMaterial** | iOS 기본 제공 사용 |

### 기타 수치 (참고용)

**liquid-glass-js:**
| 파라미터 | 범위/기본값 |
|---------|------------|
| Blur Radius | 1~15 |
| Rim Intensity | 0~0.2 |
| Rim Distance | 0.1~2.0 |
| tintOpacity | 0.2 |
| borderRadius | 48px |

**CSS/Web:**
| 속성 | 값 |
|------|-----|
| 배경 | rgba(255,255,255, 0.15) |
| 테두리 | rgba(255,255,255, 0.1) |
| 블러 | blur(2px) saturate(180%) |
| 그림자 | 0 4px 30px rgba(0,0,0,0.05) |

---

## 8. 참고 자료

### Apple 공식
- [Apple Newsroom - Liquid Glass](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [WWDC25: Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/) ⭐️
- [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple HIG - Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple Developer - glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))

### 종합 레퍼런스 ⭐️
- [LiquidGlassReference GitHub](https://github.com/conorluddy/LiquidGlassReference) - Claude용 Liquid Glass 레퍼런스
- [liquidglass.shop - Colors](https://liquidglass.shop/en/resources/colors) - 공식 색상 팔레트
- [iOS 26 Liquid Glass: Comprehensive Reference](https://medium.com/@madebyluddy/overview-37b3685227aa)

### UIKit 구현 가이드
- [Liquid Glass in iOS 26: A UIKit Developer's Guide](https://medium.com/@himalimarasinghe/build-a-stunning-uikit-app-with-liquid-glass-in-ios-26-2a0d4427ff8e)
- [Donny Wals - Designing custom UI with Liquid Glass](https://www.donnywals.com/designing-custom-ui-with-liquid-glass-on-ios-26/)
- [Donny Wals - Exploring tab bars on iOS 26](https://www.donnywals.com/exploring-tab-bars-on-ios-26-with-liquid-glass/)
- [Grow on iOS 26 - UIKit + SwiftUI Hybrid](https://fatbobman.com/en/posts/grow-on-ios26/)

### Private API 탐색 (실험/교육용)
- [GlassExplorer GitHub](https://github.com/ktiays/GlassExplorer) - iOS 26 private glass API 탐색

### CALayer 구현 기법
- [Gradient Borders in UIKit](https://nemecek.be/blog/144/gradient-borders-in-uikit) ⭐️
- [Hacking with Swift - UIView Glow](https://www.hackingwithswift.com/example-code/calayer/how-to-make-a-uiview-glow-using-shadowcolor)
- [Hacking with Swift - CAGradientLayer](https://www.hackingwithswift.com/example-code/calayer/how-to-draw-color-gradients-using-cagradientlayer)
- [Animated Gradient Border](https://medium.com/@subhrajitdeb54/how-to-add-an-animated-gradient-border-to-any-uiview-in-swift-ddbaa7bb3a23)

### 커스텀 블러 라이브러리
- [VisualEffectView](https://github.com/efremidze/VisualEffectView) - blurRadius 직접 제어
- [CustomBlurEffectView](https://github.com/perfectdim/CustomBlurEffectView) - radius, tint 커스텀
- [VisualEffectBlurView](https://github.com/dominicstop/VisualEffectBlurView) - 애니메이션 지원

### 기타
- [Linear - Custom Liquid Glass](https://linear.app/now/linear-liquid-glass)
- [liquid-glass-js GitHub](https://github.com/dashersw/liquid-glass-js)

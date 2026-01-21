# iOS 26 Liquid Glass 스타일 구현 계획

## 목표
iOS 16~25용 커스텀 UI를 실제 iOS 26 Liquid Glass 수준으로 개선

---

## Part 1: Liquid Glass 기술 조사 결과

### 1.1 Apple 공식 Liquid Glass 특성

| 특성 | 설명 |
|------|------|
| **Lensing** | 빛을 굴절시켜 배경을 왜곡 (전통적 blur와 다름) |
| **Specular Highlights** | 기기 움직임에 반응하는 광택 하이라이트 |
| **Adaptive Shadows** | 배경에 적응하는 그림자 |
| **Rim Light** | 가장자리가 밝게 빛나는 효과 |
| **Interactive** | 터치 시 bounce, shimmer 효과 |

### 1.2 내부 구현 (Apple Private API)
```
CABackdropLayer + CASDFLayer + glassBackground filter
→ _UIMultiLayer로 래핑
→ SDF 텍스처 동적 생성
```

### 1.3 iOS 26 API 상세

#### Glass Variant (3가지 타입)
| Variant | 투명도 | 용도 |
|---------|-------|------|
| `.regular` | 중간 | 대부분의 UI (기본값) |
| `.clear` | 높음 | 미디어 배경 (디밍 레이어 필요) |
| `.identity` | 없음 | 조건부 비활성화 |

#### SwiftUI API
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

#### GlassEffectContainer (그룹화)
```swift
// 유리 효과 요소들 간 샘플링 영역 공유 + 모핑 전환
GlassEffectContainer(spacing: 40.0) {
    ForEach(icons) { icon in
        IconView(icon).glassEffect()
    }
}
```

#### 모핑 전환 (Morphing)
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

#### UIKit API
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

### 1.4 접근성 자동 지원

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
    // 더 불투명한 배경 사용
    backgroundAlpha = 0.6  // 기본 0.2 대신
}

// 고대비 모드 확인
if UIAccessibility.isDarkerSystemColorsEnabled {
    // 테두리 강화
    borderAlpha = 0.5
    borderWidth = 2.0
}
```

### 1.5 Tab Bar 동작 변경 (iOS 26)

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

## Part 2: 구체적 수치 (자료 조사 기반)

### 2.1 Apple 공식 Glass Material 투명도 (liquidglass.shop 기준)

| Material | 투명도 범위 | 용도 |
|----------|------------|------|
| **Glass Light** | 20-40% opacity (흰색) | 밝은 배경 위 UI |
| **Glass Dark** | 10-30% opacity (검정) | 어두운 배경 위 UI |
| **Glass Accent** | 15% opacity | 색상 틴트 강조 |
| **Tint Opacity** | 20% | 버튼/컨트롤 색상 |

### 2.2 Apple 공식 색상 팔레트 (HEX/RGB)

**Primary Colors:**
| 색상명 | HEX | RGB |
|--------|-----|-----|
| Liquid Blue | #007AFF | 0, 122, 255 |
| Liquid Purple | #AF52DE | 175, 82, 222 |
| Liquid Indigo | #5856D6 | 88, 86, 214 |
| Liquid Teal | #5AC8FA | 90, 200, 250 |

**Semantic Colors:**
| 색상명 | HEX | RGB |
|--------|-----|-----|
| System Red | #FF3B30 | 255, 59, 48 |
| System Orange | #FF9500 | 255, 149, 0 |
| System Yellow | #FFCC00 | 255, 204, 0 |
| System Green | #34C759 | 52, 199, 89 |

**Neutral Colors:**
| 색상명 | HEX | RGB |
|--------|-----|-----|
| System Gray | #8E8E93 | 142, 142, 147 |
| System Gray 2 | #AEAEB2 | 174, 174, 178 |
| System Gray 3 | #C7C7CC | 199, 199, 204 |
| Glass Blur | #F2F2F7 | 242, 242, 247 |

### 2.3 liquid-glass-js 라이브러리 파라미터

| 파라미터 | 범위/기본값 | 설명 |
|---------|------------|------|
| `Blur Radius` | 1~15 | 배경 블러 강도 |
| `Rim Intensity` | 0~0.2 | **가장자리 발광 강도** |
| `Rim Distance` | 0.1~2.0 | Rim light falloff |
| `tintOpacity` | 0.2 | 색상 틴트 투명도 |
| `borderRadius` | 48px | 모서리 반경 |

### 2.4 CSS/Web 구현 수치

| 속성 | 값 | 설명 |
|------|-----|------|
| 배경 | `rgba(255,255,255, 0.15)` | 15% 반투명 |
| 테두리 | `rgba(255,255,255, 0.1)` | 10% 반투명 |
| 블러 | `blur(2px) saturate(180%)` | 블러 + 채도 |
| 그림자 | `0 4px 30px rgba(0,0,0,0.05)` | 부드러운 그림자 |

### 2.5 iOS 16~25 커스텀 구현 권장 수치 (종합)

**핵심 결론:** 여러 소스에서 수치가 다르지만, iOS 느낌을 내기 위한 **권장 수치**:

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

---

## Part 3: CALayer 기반 커스텀 구현 코드

### 3.1 Gradient Border (Rim Light 효과)

```swift
public extension UIView {
    func setGradientBorder(
        width: CGFloat,
        colors: [UIColor],
        startPoint: CGPoint = CGPoint(x: 0, y: 0),     // 좌상단
        endPoint: CGPoint = CGPoint(x: 1, y: 1)        // 우하단
    ) {
        let border = CAGradientLayer()
        border.frame = bounds
        border.colors = colors.map { $0.cgColor }
        border.startPoint = startPoint
        border.endPoint = endPoint

        // 테두리만 보이도록 마스크
        let mask = CAShapeLayer()
        mask.path = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
        mask.fillColor = UIColor.clear.cgColor
        mask.strokeColor = UIColor.white.cgColor
        mask.lineWidth = width

        border.mask = mask
        layer.addSublayer(border)
    }
}
```

**Rim Light 적용 예시:**
```swift
view.setGradientBorder(
    width: 1.5,
    colors: [
        UIColor.white.withAlphaComponent(0.4),  // 좌상단: 밝음
        UIColor.white.withAlphaComponent(0.08)  // 우하단: 어두움
    ]
)
```

### 3.2 Inner Shadow (내부 그림자)

```swift
class InnerShadowLayer: CAShapeLayer {
    override init() {
        super.init()
        shadowColor = UIColor.black.cgColor
        shadowOffset = CGSize(width: 2, height: 2)  // 우하단 방향
        shadowOpacity = 0.15
        shadowRadius = 8
        fillRule = .evenOdd
    }

    func updatePath(for bounds: CGRect, cornerRadius: CGFloat) {
        let shadowPath = CGMutablePath()
        let inset = -shadowRadius * 2.0

        // 외부 큰 사각형 (그림자 영역)
        shadowPath.addRect(bounds.insetBy(dx: inset, dy: inset))
        // 내부 뷰 경로 (그림자가 안쪽으로만 보이도록)
        shadowPath.addRoundedRect(
            in: bounds,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius
        )

        path = shadowPath
    }
}
```

### 3.3 Specular Highlight (상단 광택)

```swift
static func createSpecularHighlightLayer(
    bounds: CGRect,
    cornerRadius: CGFloat
) -> CAGradientLayer {
    let layer = CAGradientLayer()
    layer.frame = bounds

    // 상단에서 중간으로 페이드
    layer.colors = [
        UIColor.white.withAlphaComponent(0.12).cgColor,
        UIColor.white.withAlphaComponent(0.0).cgColor
    ]
    layer.locations = [0.0, 0.4]  // 40% 지점에서 완전 투명
    layer.startPoint = CGPoint(x: 0.5, y: 0.0)
    layer.endPoint = CGPoint(x: 0.5, y: 1.0)

    layer.cornerRadius = cornerRadius
    layer.masksToBounds = true

    return layer
}
```

### 3.4 Outer Glow 효과 (shadowColor 활용)

```swift
/// UIView에 Glow 효과 적용
func applyGlowEffect(
    color: UIColor = .white,
    radius: CGFloat = 20,
    opacity: Float = 0.5
) {
    layer.shadowOffset = .zero           // 모든 방향으로 균등 분산
    layer.shadowColor = color.cgColor    // 빛나는 색상
    layer.shadowRadius = radius          // 광선 확산 정도
    layer.shadowOpacity = opacity        // 투명도
    layer.shadowPath = UIBezierPath(
        roundedRect: bounds,
        cornerRadius: layer.cornerRadius
    ).cgPath
}

// 사용 예시 (밝은 테두리 효과)
view.applyGlowEffect(
    color: .white,
    radius: 8,
    opacity: 0.15
)
```

**참고:** Glow 효과는 어두운 배경에서 가장 효과적입니다.

### 3.5 레이어 스택 구조 (권장 순서)

```
┌─────────────────────────────────────┐
│  6. Content (아이콘/텍스트)           │  ← 최상위
├─────────────────────────────────────┤
│  5. Rim Light (Gradient Border)     │  ← 테두리 빛남
├─────────────────────────────────────┤
│  4. Specular Highlight (상단 광택)   │  ← 상단 하이라이트
├─────────────────────────────────────┤
│  3. Inner Shadow (우하단 그림자)     │  ← 입체감
├─────────────────────────────────────┤
│  2. Tint Overlay (색상 틴트)         │  ← 20% alpha
├─────────────────────────────────────┤
│  1. Blur Effect (UIVisualEffectView)│  ← 배경 블러
└─────────────────────────────────────┘
     ↓ 배경 콘텐츠 (사진 등)
```

### 3.6 UIKit에서 커스텀 블러 강도 조절

Apple의 기본 `UIBlurEffect`는 블러 강도를 노출하지 않음. 커스텀 강도가 필요한 경우:

**방법 1: 애니메이션 프랙션 활용 (Private API 없이)**
```swift
let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
let blurView = UIVisualEffectView(effect: nil)
view.addSubview(blurView)

// 0.0 ~ 1.0 사이의 fractionComplete로 강도 조절
UIViewPropertyAnimator(duration: 1, curve: .linear) {
    blurView.effect = blurEffect
}.fractionComplete = 0.5  // 50% 강도
```

**방법 2: 서드파티 라이브러리 사용**
- `VisualEffectView` by efremidze: `blurRadius` 직접 설정 가능
- `CustomBlurEffectView`: radius 기본값 10, 커스텀 가능

---

## Part 4: 현재 구현 vs iOS 26 차이점 분석

### 4.1 사용자 피드백 기반 문제점

| 항목 | 현재 | iOS 26 | 문제 |
|------|------|--------|------|
| **탭바 너비** | 60% | 80%+ | 너무 좁음 |
| **탭바 높이** | 56pt | 60pt+ | 약간 낮음 |
| **아이콘 크기** | 24pt | 20pt | 오히려 큼 |
| **텍스트 크기** | 11pt | 10pt | 오히려 큼 |
| **선택 표시** | 색상만 | **pill 배경** | 핵심 누락 |
| **배경** | 불투명 | 더 투명 | 블러 조정 필요 |
| **테두리** | 0.5px, 30% | Rim Light | 빛나는 효과 없음 |
| **뒤로가기 버튼** | 작음 | 큼 | 크기 증가 필요 |
| **Select/비우기** | 낮음 | 높음 | 높이 증가 필요 |
| **질감** | 단순 블러 | Rim Light + Specular | **핵심 누락** |

### 4.2 현재 LiquidGlassStyle.swift 값

```swift
// 현재 값
blurStyle: .systemUltraThinMaterialDark
backgroundAlpha: 0.12
tintAlpha: 0.20
borderWidth: 0.5
borderAlpha: 0.30
shadowOpacity: 0.25
shadowRadius: 16
tabIconSize: 24
highlightTopAlpha: 0.15
```

### 4.3 개선 목표 값

```swift
// 개선 값
blurStyle: .systemUltraThinMaterial  // Dark 제거
backgroundAlpha: 0.15                 // 약간 증가
tintAlpha: 0.12                       // 감소
borderWidth: 1.5                      // 증가
borderAlpha: 0.08~0.4 (그라데이션)    // Rim Light
shadowOpacity: 0.08                   // 감소 (더 부드럽게)
shadowRadius: 20                      // 증가 (더 넓게)
tabIconSize: 20                       // 감소
rimLightIntensity: 0.15               // 신규
```

---

## Part 5: 구현 계획

### Phase 1: LiquidGlassStyle.swift 전면 개선

**파일**: `PickPhoto/PickPhoto/Shared/Styles/LiquidGlassStyle.swift`

#### 1.1 기존 상수 수정
```swift
// Material
static let blurStyle: UIBlurEffect.Style = .systemUltraThinMaterial
static let backgroundAlpha: CGFloat = 0.15
static let tintAlpha: CGFloat = 0.12

// Shadow (더 부드럽게)
static let shadowOpacity: Float = 0.08
static let shadowRadius: CGFloat = 20
static let shadowOffset = CGSize(width: 0, height: 4)
```

#### 1.2 Rim Light 관련 신규 상수
```swift
// Rim Light (그라데이션 테두리)
static let rimLightWidth: CGFloat = 1.5
static let rimLightBrightAlpha: CGFloat = 0.35   // 좌상단
static let rimLightDarkAlpha: CGFloat = 0.08     // 우하단
static let rimLightStartPoint = CGPoint(x: 0, y: 0)
static let rimLightEndPoint = CGPoint(x: 1, y: 1)
```

#### 1.3 탭바 전용 상수
```swift
// Tab Bar
static let tabBarHeight: CGFloat = 60
static let tabBarWidthRatio: CGFloat = 0.85
static let tabIconSize: CGFloat = 20
static let tabTextSize: CGFloat = 10
static let selectedPillHeight: CGFloat = 48
static let selectedPillAlpha: CGFloat = 0.18
```

#### 1.4 버튼 크기 상수
```swift
// Buttons
static let backButtonSize: CGFloat = 44
static let selectButtonHeight: CGFloat = 40
static let actionButtonSize: CGFloat = 56
```

#### 1.5 신규 헬퍼 메서드

```swift
/// Rim Light 그라데이션 테두리 레이어 생성
static func createRimLightBorder(
    bounds: CGRect,
    cornerRadius: CGFloat
) -> CAGradientLayer {
    let gradient = CAGradientLayer()
    gradient.frame = bounds
    gradient.colors = [
        UIColor.white.withAlphaComponent(rimLightBrightAlpha).cgColor,
        UIColor.white.withAlphaComponent(rimLightDarkAlpha).cgColor
    ]
    gradient.startPoint = rimLightStartPoint
    gradient.endPoint = rimLightEndPoint

    // 테두리만 보이도록 마스크
    let mask = CAShapeLayer()
    let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
    let innerRect = bounds.insetBy(dx: rimLightWidth, dy: rimLightWidth)
    let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius - rimLightWidth)
    outerPath.append(innerPath.reversing())
    mask.path = outerPath.cgPath
    gradient.mask = mask

    return gradient
}

/// Inner Shadow 레이어 생성 (우하단 방향)
static func createInnerShadowLayer(
    bounds: CGRect,
    cornerRadius: CGFloat
) -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOffset = CGSize(width: 2, height: 2)
    layer.shadowOpacity = 0.12
    layer.shadowRadius = 6
    layer.fillRule = .evenOdd

    let path = CGMutablePath()
    let inset = -layer.shadowRadius * 2
    path.addRect(bounds.insetBy(dx: inset, dy: inset))
    path.addRoundedRect(in: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
    layer.path = path

    return layer
}
```

---

### Phase 2: GlassButton.swift 개선

**파일**: `PickPhoto/PickPhoto/Shared/Components/GlassButton.swift`

#### 2.1 레이어 구조 변경

```
현재: Blur → Tint → Specular Highlight → Content
개선: Blur → Tint → Inner Shadow → Specular Highlight → Rim Light → Content
```

#### 2.2 Rim Light 레이어 추가

```swift
private var rimLightLayer: CAGradientLayer?

private func setupLayers() {
    // ... 기존 코드 ...

    // Rim Light 레이어 추가
    rimLightLayer = LiquidGlassStyle.createRimLightBorder(
        bounds: bounds,
        cornerRadius: cornerRadius
    )
    if let rimLightLayer = rimLightLayer {
        layer.addSublayer(rimLightLayer)
    }
}

override func layoutSubviews() {
    super.layoutSubviews()
    // ... 기존 코드 ...

    // Rim Light 업데이트
    rimLightLayer?.removeFromSuperlayer()
    rimLightLayer = LiquidGlassStyle.createRimLightBorder(
        bounds: bounds,
        cornerRadius: cornerRadius
    )
    if let rimLightLayer = rimLightLayer {
        layer.addSublayer(rimLightLayer)
    }
}
```

#### 2.3 형태 옵션 추가

```swift
enum GlassButtonShape {
    case circle    // 완전 원형 (아이콘 버튼)
    case capsule   // 캡슐 (텍스트 버튼)
    case rounded   // 둥근 사각형
}

init(tintColor: UIColor, shape: GlassButtonShape = .rounded) {
    self.shape = shape
    // ...
}
```

#### 2.4 Spring 애니메이션 개선

```swift
private func animateInteraction(isPressed: Bool) {
    let scale: CGFloat = isPressed ? 0.94 : 1.0

    UIView.animate(
        withDuration: 0.2,
        delay: 0,
        usingSpringWithDamping: 0.7,
        initialSpringVelocity: 0.5,
        options: [.beginFromCurrentState],
        animations: {
            self.transform = CGAffineTransform(scaleX: scale, y: scale)
        }
    )
}
```

---

### Phase 3: FloatingTabBar.swift 대폭 수정 (핵심!)

**파일**: `PickPhoto/PickPhoto/Shared/Components/FloatingTabBar.swift`

#### 3.1 크기 변경

```swift
// 변경 전
static let capsuleHeight: CGFloat = 56
widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6)

// 변경 후
static let capsuleHeight: CGFloat = 60
widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.85)
```

#### 3.2 선택 Pill 배경 추가 (핵심 신규!)

```swift
/// 선택된 탭 뒤의 pill 배경
private lazy var selectionPillView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor.white.withAlphaComponent(0.18)
    view.layer.cornerRadius = 24  // 높이/2
    view.translatesAutoresizingMaskIntoConstraints = false
    return view
}()

private var selectionPillLeadingConstraint: NSLayoutConstraint?
private var selectionPillWidthConstraint: NSLayoutConstraint?
```

#### 3.3 Pill 애니메이션

```swift
private func animateSelectionPill(to index: Int) {
    guard let targetButton = [photosButton, albumsButton, trashButton][safe: index] else { return }

    UIView.animate(
        withDuration: 0.3,
        delay: 0,
        usingSpringWithDamping: 0.75,
        initialSpringVelocity: 0.5,
        options: [.beginFromCurrentState]
    ) {
        self.selectionPillLeadingConstraint?.constant = targetButton.frame.minX - 4
        self.selectionPillWidthConstraint?.constant = targetButton.frame.width + 8
        self.layoutIfNeeded()
    }
}
```

#### 3.4 아이콘/텍스트 크기 축소

```swift
// 변경 전
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24)
outgoing.font = .systemFont(ofSize: 11, weight: .medium)

// 변경 후
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
outgoing.font = .systemFont(ofSize: 10, weight: .medium)
```

#### 3.5 Rim Light 적용

```swift
private func setupCapsule() {
    // ... 기존 블러, 배경 설정 ...

    // Rim Light 테두리 추가
    let rimLight = LiquidGlassStyle.createRimLightBorder(
        bounds: capsuleContainer.bounds,
        cornerRadius: Self.capsuleCornerRadius
    )
    capsuleContainer.layer.addSublayer(rimLight)
}
```

---

### Phase 4: FloatingTitleBar.swift 수정

**파일**: `PickPhoto/PickPhoto/Shared/Components/FloatingTitleBar.swift`

#### 4.1 뒤로가기 버튼 크기 증가

```swift
// 변경 전: 약 36pt
// 변경 후: 44pt
backButton.widthAnchor.constraint(equalToConstant: 44),
backButton.heightAnchor.constraint(equalToConstant: 44),
```

#### 4.2 Select/비우기 버튼 높이 증가

```swift
// 변경 전
config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

// 변경 후
config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
```

---

### Phase 5: ViewerViewController.swift 수정

**파일**: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`

#### 5.1 삭제 버튼 (원형 유지)

```swift
deleteButton: GlassButton(tintColor: .systemRed, shape: .circle)
// 크기: 56x56 유지
// 아이콘: trash.fill
```

#### 5.2 복구/영구삭제 버튼 (텍스트로 변경)

```swift
// 기존: 아이콘 버튼
// 변경: 텍스트 캡슐 버튼

restoreButton: GlassButton(tintColor: .systemBlue, shape: .capsule)
// 텍스트: "복구"

permanentDeleteButton: GlassButton(tintColor: .systemRed, shape: .capsule)
// 텍스트: "삭제"
```

---

## Part 6: 수정 파일 목록

| 우선순위 | 파일 | 주요 변경 | 예상 라인 |
|---------|------|----------|----------|
| 1 | `LiquidGlassStyle.swift` | Rim Light, Inner Shadow, 상수 전면 수정 | ~80줄 |
| 2 | `GlassButton.swift` | Rim Light 레이어, 형태 옵션, 애니메이션 | ~60줄 |
| 3 | `FloatingTabBar.swift` | 크기, 선택 pill, Rim Light | ~120줄 |
| 4 | `FloatingTitleBar.swift` | 버튼 크기 증가 | ~30줄 |
| 5 | `ViewerViewController.swift` | 버튼 형태/텍스트 변경 | ~40줄 |
| **총계** | | | **~330줄** |

---

## Part 7: 검증 방법

### 7.1 시각적 검증
- iOS 26 Photos 앱과 나란히 비교
- 탭바 너비/높이 유사성
- 선택 pill 애니메이션 자연스러움
- Rim Light 테두리 빛나는 느낌

### 7.2 다양한 배경 테스트
- 밝은 사진 (흰색 배경)
- 어두운 사진 (검은색 배경)
- 버튼 가시성 및 대비

### 7.3 인터랙션 테스트
- 탭 선택 시 pill 이동 애니메이션
- 버튼 탭 시 Spring bounce
- 전체적인 반응 속도

---

## Part 8: 참고 자료

### Apple 공식
- [Apple Newsroom - Liquid Glass](https://www.apple.com/newsroom/2025/06/apple-introduces-a-delightful-and-elegant-new-software-design/)
- [WWDC25: Build a UIKit app with the new design](https://developer.apple.com/videos/play/wwdc2025/284/) ⭐️
- [WWDC25: Build a SwiftUI app with the new design](https://developer.apple.com/videos/play/wwdc2025/323/)
- [Apple HIG - Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple Developer - glassEffect](https://developer.apple.com/documentation/swiftui/view/glasseffect(_:in:))

### 종합 레퍼런스 (강력 추천) ⭐️
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

---

## Part 9: 구현 체크리스트

### 필수 구현 항목
- [ ] Rim Light 그라데이션 테두리 (좌상단 밝음 → 우하단 어두움)
- [ ] Specular Highlight 상단 광택
- [ ] 레이어 스택 순서 준수 (Blur → Tint → Shadow → Highlight → Rim → Content)
- [ ] Tab Bar 선택 Pill 배경
- [ ] Spring 애니메이션 (버튼 터치, Pill 이동)
- [ ] 접근성 설정 대응 (투명도 감소, 고대비)

### 수치 확인
- [ ] 배경 투명도: 20-30% (Light), 15-20% (Dark)
- [ ] 테두리 그라데이션: 35-40% → 8-10% alpha
- [ ] 테두리 두께: 1.5pt
- [ ] 그림자: opacity 0.05-0.08, radius 20-30pt
- [ ] 탭바 크기: 너비 85%, 높이 60pt
- [ ] 아이콘: 20pt, 텍스트: 10pt

### 시각적 검증
- [ ] iOS 26 Photos 앱과 비교
- [ ] 밝은/어두운 배경에서 가시성 테스트
- [ ] Rim Light 테두리 "빛나는 느낌" 확인
- [ ] 선택 Pill 애니메이션 자연스러움

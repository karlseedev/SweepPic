# Liquid Glass 구현 코드

> iOS 16~25에서 Liquid Glass를 흉내내기 위한 CALayer 기반 코드 스니펫

**관련 문서:**
- [260121-LiquidGlass-Spec.md](./260121-LiquidGlass-Spec.md) - 기술 스펙 및 수치
- [260121-LiquidGlass-Plan.md](./260121-LiquidGlass-Plan.md) - 작업 계획 및 체크리스트

---

## 레이어 스택 구조 (권장 순서)

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

---

## 1. Gradient Border (Rim Light 효과)

Liquid Glass의 핵심 - 가장자리가 빛나는 효과

```swift
public extension UIView {
    /// Rim Light 그라데이션 테두리 적용
    /// - Parameters:
    ///   - width: 테두리 두께 (권장: 1.5pt)
    ///   - colors: 그라데이션 색상 배열 [밝은색, 어두운색]
    ///   - startPoint: 시작점 (기본: 좌상단 0,0)
    ///   - endPoint: 끝점 (기본: 우하단 1,1)
    func setGradientBorder(
        width: CGFloat,
        colors: [UIColor],
        startPoint: CGPoint = CGPoint(x: 0, y: 0),
        endPoint: CGPoint = CGPoint(x: 1, y: 1)
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

### 사용 예시
```swift
// Rim Light 효과 (좌상단 밝음 → 우하단 어두움)
view.setGradientBorder(
    width: 1.5,
    colors: [
        UIColor.white.withAlphaComponent(0.35),  // 좌상단: 밝음
        UIColor.white.withAlphaComponent(0.08)   // 우하단: 어두움
    ]
)
```

---

## 2. Rim Light Border 레이어 (재사용 가능)

LiquidGlassStyle에서 사용할 정적 메서드

```swift
/// Rim Light 그라데이션 테두리 레이어 생성
/// - Parameters:
///   - bounds: 레이어 크기
///   - cornerRadius: 모서리 반경
///   - width: 테두리 두께 (기본: 1.5)
///   - brightAlpha: 밝은 쪽 투명도 (기본: 0.35)
///   - darkAlpha: 어두운 쪽 투명도 (기본: 0.08)
/// - Returns: 구성된 CAGradientLayer
static func createRimLightBorder(
    bounds: CGRect,
    cornerRadius: CGFloat,
    width: CGFloat = 1.5,
    brightAlpha: CGFloat = 0.35,
    darkAlpha: CGFloat = 0.08
) -> CAGradientLayer {
    let gradient = CAGradientLayer()
    gradient.frame = bounds
    gradient.colors = [
        UIColor.white.withAlphaComponent(brightAlpha).cgColor,
        UIColor.white.withAlphaComponent(darkAlpha).cgColor
    ]
    gradient.startPoint = CGPoint(x: 0, y: 0)  // 좌상단
    gradient.endPoint = CGPoint(x: 1, y: 1)    // 우하단

    // 테두리만 보이도록 마스크 (내부는 투명)
    let mask = CAShapeLayer()
    let outerPath = UIBezierPath(roundedRect: bounds, cornerRadius: cornerRadius)
    let innerRect = bounds.insetBy(dx: width, dy: width)
    let innerPath = UIBezierPath(roundedRect: innerRect, cornerRadius: cornerRadius - width)
    outerPath.append(innerPath.reversing())
    mask.path = outerPath.cgPath
    gradient.mask = mask

    return gradient
}
```

### 사용 예시
```swift
let rimLight = LiquidGlassStyle.createRimLightBorder(
    bounds: view.bounds,
    cornerRadius: 28
)
view.layer.addSublayer(rimLight)
```

---

## 3. Inner Shadow (내부 그림자)

입체감을 위한 내부 그림자

```swift
class InnerShadowLayer: CAShapeLayer {

    override init() {
        super.init()
        shadowColor = UIColor.black.cgColor
        shadowOffset = CGSize(width: 2, height: 2)  // 우하단 방향
        shadowOpacity = 0.12
        shadowRadius = 6
        fillRule = .evenOdd
        fillColor = UIColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 경로 업데이트
    func updatePath(for bounds: CGRect, cornerRadius: CGFloat) {
        let shadowPath = CGMutablePath()
        let inset = -shadowRadius * 2.0

        // 외부 큰 사각형 (그림자가 그려질 영역)
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

### 정적 메서드 버전
```swift
/// Inner Shadow 레이어 생성 (우하단 방향)
static func createInnerShadowLayer(
    bounds: CGRect,
    cornerRadius: CGFloat,
    shadowOpacity: Float = 0.12,
    shadowRadius: CGFloat = 6
) -> CAShapeLayer {
    let layer = CAShapeLayer()
    layer.shadowColor = UIColor.black.cgColor
    layer.shadowOffset = CGSize(width: 2, height: 2)
    layer.shadowOpacity = shadowOpacity
    layer.shadowRadius = shadowRadius
    layer.fillRule = .evenOdd
    layer.fillColor = UIColor.clear.cgColor

    let path = CGMutablePath()
    let inset = -shadowRadius * 2
    path.addRect(bounds.insetBy(dx: inset, dy: inset))
    path.addRoundedRect(in: bounds, cornerWidth: cornerRadius, cornerHeight: cornerRadius)
    layer.path = path

    return layer
}
```

---

## 4. Specular Highlight (상단 광택)

상단에서 하단으로 페이드되는 광택 효과

```swift
/// Specular Highlight 레이어 생성
/// - Parameters:
///   - bounds: 레이어 크기
///   - cornerRadius: 모서리 반경
///   - topAlpha: 상단 투명도 (기본: 0.12)
///   - fadeLocation: 페이드 끝 위치 (기본: 0.4 = 40%)
/// - Returns: 구성된 CAGradientLayer
static func createSpecularHighlightLayer(
    bounds: CGRect,
    cornerRadius: CGFloat,
    topAlpha: CGFloat = 0.12,
    fadeLocation: NSNumber = 0.4
) -> CAGradientLayer {
    let layer = CAGradientLayer()
    layer.frame = bounds

    // 상단에서 중간으로 페이드
    layer.colors = [
        UIColor.white.withAlphaComponent(topAlpha).cgColor,
        UIColor.white.withAlphaComponent(0.0).cgColor
    ]
    layer.locations = [0.0, fadeLocation]
    layer.startPoint = CGPoint(x: 0.5, y: 0.0)  // 상단 중앙
    layer.endPoint = CGPoint(x: 0.5, y: 1.0)    // 하단 중앙

    layer.cornerRadius = cornerRadius
    layer.masksToBounds = true

    return layer
}
```

---

## 5. Outer Glow 효과

shadowColor를 활용한 발광 효과

```swift
extension UIView {
    /// Glow 효과 적용
    /// - Parameters:
    ///   - color: 빛나는 색상 (기본: 흰색)
    ///   - radius: 광선 확산 정도 (기본: 20)
    ///   - opacity: 투명도 (기본: 0.5)
    func applyGlowEffect(
        color: UIColor = .white,
        radius: CGFloat = 20,
        opacity: Float = 0.5
    ) {
        layer.shadowOffset = .zero           // 모든 방향으로 균등 분산
        layer.shadowColor = color.cgColor
        layer.shadowRadius = radius
        layer.shadowOpacity = opacity
        layer.shadowPath = UIBezierPath(
            roundedRect: bounds,
            cornerRadius: layer.cornerRadius
        ).cgPath
    }

    /// Glow 효과 제거
    func removeGlowEffect() {
        layer.shadowOpacity = 0
    }
}
```

### 사용 예시
```swift
// 밝은 테두리 효과 (어두운 배경에서 효과적)
view.applyGlowEffect(
    color: .white,
    radius: 8,
    opacity: 0.15
)
```

---

## 6. 커스텀 블러 강도 조절

Apple의 기본 `UIBlurEffect`는 블러 강도를 노출하지 않음

### 방법 1: 애니메이션 프랙션 활용 (Private API 없이)
```swift
let blurEffect = UIBlurEffect(style: .systemUltraThinMaterial)
let blurView = UIVisualEffectView(effect: nil)
view.addSubview(blurView)

// 0.0 ~ 1.0 사이의 fractionComplete로 강도 조절
let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
    blurView.effect = blurEffect
}
animator.fractionComplete = 0.5  // 50% 강도
animator.pausesOnCompletion = true
```

### 방법 2: 서드파티 라이브러리 사용
- `VisualEffectView` by efremidze: `blurRadius` 직접 설정 가능
- `CustomBlurEffectView`: radius 기본값 10, 커스텀 가능

---

## 7. Spring 애니메이션

버튼 터치 반응 및 Pill 이동에 사용

```swift
/// Spring 애니메이션으로 스케일 변경
/// - Parameters:
///   - isPressed: 눌림 상태
///   - scale: 눌렸을 때 스케일 (기본: 0.94)
///   - duration: 애니메이션 시간 (기본: 0.2)
///   - damping: 스프링 감쇠 (기본: 0.7)
///   - velocity: 초기 속도 (기본: 0.5)
func animateScale(
    isPressed: Bool,
    scale: CGFloat = 0.94,
    duration: TimeInterval = 0.2,
    damping: CGFloat = 0.7,
    velocity: CGFloat = 0.5
) {
    let targetScale: CGFloat = isPressed ? scale : 1.0

    UIView.animate(
        withDuration: duration,
        delay: 0,
        usingSpringWithDamping: damping,
        initialSpringVelocity: velocity,
        options: [.beginFromCurrentState]
    ) {
        self.transform = CGAffineTransform(scaleX: targetScale, y: targetScale)
    }
}
```

### Pill 이동 애니메이션
```swift
/// Selection Pill을 특정 위치로 애니메이션
func animateSelectionPill(
    to targetFrame: CGRect,
    duration: TimeInterval = 0.3,
    damping: CGFloat = 0.75
) {
    UIView.animate(
        withDuration: duration,
        delay: 0,
        usingSpringWithDamping: damping,
        initialSpringVelocity: 0.5,
        options: [.beginFromCurrentState]
    ) {
        self.selectionPillView.frame = targetFrame
    }
}
```

---

## 8. 접근성 대응

```swift
/// 접근성 설정에 따른 Glass 스타일 조정
struct AccessibilityAwareGlassStyle {

    /// 현재 접근성 설정에 맞는 배경 투명도
    static var backgroundAlpha: CGFloat {
        if UIAccessibility.isReduceTransparencyEnabled {
            return 0.6  // 더 불투명
        }
        return 0.2  // 기본값
    }

    /// 현재 접근성 설정에 맞는 테두리 투명도
    static var borderAlpha: CGFloat {
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return 0.5  // 더 진하게
        }
        return 0.35  // 기본값
    }

    /// 현재 접근성 설정에 맞는 테두리 두께
    static var borderWidth: CGFloat {
        if UIAccessibility.isDarkerSystemColorsEnabled {
            return 2.0  // 더 두껍게
        }
        return 1.5  // 기본값
    }

    /// 모션 감소 설정 여부
    static var shouldReduceMotion: Bool {
        return UIAccessibility.isReduceMotionEnabled
    }
}
```

### 사용 예시
```swift
// 접근성 설정에 맞게 Rim Light 생성
let rimLight = LiquidGlassStyle.createRimLightBorder(
    bounds: bounds,
    cornerRadius: cornerRadius,
    width: AccessibilityAwareGlassStyle.borderWidth,
    brightAlpha: AccessibilityAwareGlassStyle.borderAlpha,
    darkAlpha: 0.08
)

// 모션 감소 설정 시 애니메이션 비활성화
if AccessibilityAwareGlassStyle.shouldReduceMotion {
    // 즉시 변경
    selectionPillView.frame = targetFrame
} else {
    // 애니메이션
    animateSelectionPill(to: targetFrame)
}
```

---

## 9. 전체 Glass View 조합 예시

```swift
class LiquidGlassView: UIView {

    private var blurView: UIVisualEffectView!
    private var tintView: UIView!
    private var innerShadowLayer: CAShapeLayer?
    private var specularLayer: CAGradientLayer?
    private var rimLightLayer: CAGradientLayer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupLayers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupLayers()
    }

    private func setupLayers() {
        // 1. Blur Effect
        let blur = UIBlurEffect(style: .systemUltraThinMaterial)
        blurView = UIVisualEffectView(effect: blur)
        blurView.frame = bounds
        blurView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(blurView)

        // 2. Tint Overlay
        tintView = UIView()
        tintView.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        tintView.frame = bounds
        tintView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(tintView)

        // 레이어는 layoutSubviews에서 설정
        layer.cornerRadius = 28
        layer.masksToBounds = true
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateEffectLayers()
    }

    private func updateEffectLayers() {
        let cornerRadius = layer.cornerRadius

        // 3. Inner Shadow
        innerShadowLayer?.removeFromSuperlayer()
        innerShadowLayer = LiquidGlassStyle.createInnerShadowLayer(
            bounds: bounds,
            cornerRadius: cornerRadius
        )
        if let innerShadowLayer = innerShadowLayer {
            layer.addSublayer(innerShadowLayer)
        }

        // 4. Specular Highlight
        specularLayer?.removeFromSuperlayer()
        specularLayer = LiquidGlassStyle.createSpecularHighlightLayer(
            bounds: bounds,
            cornerRadius: cornerRadius
        )
        if let specularLayer = specularLayer {
            layer.addSublayer(specularLayer)
        }

        // 5. Rim Light
        rimLightLayer?.removeFromSuperlayer()
        rimLightLayer = LiquidGlassStyle.createRimLightBorder(
            bounds: bounds,
            cornerRadius: cornerRadius
        )
        if let rimLightLayer = rimLightLayer {
            layer.addSublayer(rimLightLayer)
        }
    }
}
```

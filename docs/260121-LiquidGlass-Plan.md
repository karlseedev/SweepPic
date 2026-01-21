# Liquid Glass 구현 계획

> iOS 16~25용 커스텀 UI를 iOS 26 Liquid Glass 수준으로 개선하기 위한 작업 계획

**관련 문서:**
- [260121-LiquidGlass-Spec.md](./260121-LiquidGlass-Spec.md) - 기술 스펙 및 수치
- [260121-260121-LiquidGlass-Code.md](./260121-260121-LiquidGlass-Code.md) - 구현 코드 스니펫

---

## 현재 vs iOS 26 차이점 분석

### 사용자 피드백 기반 문제점

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

### 현재 LiquidGlassStyle.swift 값

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

### 개선 목표 값

```swift
// 개선 값
blurStyle: .systemUltraThinMaterial  // Dark 제거
backgroundAlpha: 0.15                 // 약간 증가
tintAlpha: 0.12                       // 감소
borderWidth: 1.5                      // 증가
borderAlpha: 0.08~0.35 (그라데이션)   // Rim Light
shadowOpacity: 0.08                   // 감소 (더 부드럽게)
shadowRadius: 20                      // 증가 (더 넓게)
tabIconSize: 20                       // 감소
rimLightIntensity: 0.15               // 신규
```

---

## Phase 1: LiquidGlassStyle.swift 전면 개선

**파일**: `PickPhoto/PickPhoto/Shared/Styles/LiquidGlassStyle.swift`

### 1.1 기존 상수 수정
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

### 1.2 Rim Light 관련 신규 상수
```swift
// Rim Light (그라데이션 테두리)
static let rimLightWidth: CGFloat = 1.5
static let rimLightBrightAlpha: CGFloat = 0.35   // 좌상단
static let rimLightDarkAlpha: CGFloat = 0.08     // 우하단
static let rimLightStartPoint = CGPoint(x: 0, y: 0)
static let rimLightEndPoint = CGPoint(x: 1, y: 1)
```

### 1.3 탭바 전용 상수
```swift
// Tab Bar
static let tabBarHeight: CGFloat = 60
static let tabBarWidthRatio: CGFloat = 0.85
static let tabIconSize: CGFloat = 20
static let tabTextSize: CGFloat = 10
static let selectedPillHeight: CGFloat = 48
static let selectedPillAlpha: CGFloat = 0.18
```

### 1.4 버튼 크기 상수
```swift
// Buttons
static let backButtonSize: CGFloat = 44
static let selectButtonHeight: CGFloat = 40
static let actionButtonSize: CGFloat = 56
```

### 1.5 신규 헬퍼 메서드
- `createRimLightBorder(bounds:cornerRadius:)` → [260121-LiquidGlass-Code.md](./260121-LiquidGlass-Code.md#2-rim-light-border-레이어-재사용-가능) 참고
- `createInnerShadowLayer(bounds:cornerRadius:)` → [260121-LiquidGlass-Code.md](./260121-LiquidGlass-Code.md#3-inner-shadow-내부-그림자) 참고

---

## Phase 2: GlassButton.swift 개선

**파일**: `PickPhoto/PickPhoto/Shared/Components/GlassButton.swift`

### 2.1 레이어 구조 변경

```
현재: Blur → Tint → Specular Highlight → Content
개선: Blur → Tint → Inner Shadow → Specular Highlight → Rim Light → Content
```

### 2.2 Rim Light 레이어 추가

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

### 2.3 형태 옵션 추가

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

### 2.4 Spring 애니메이션 개선

```swift
private func animateInteraction(isPressed: Bool) {
    let scale: CGFloat = isPressed ? 0.94 : 1.0

    UIView.animate(
        withDuration: 0.2,
        delay: 0,
        usingSpringWithDamping: 0.7,
        initialSpringVelocity: 0.5,
        options: [.beginFromCurrentState]
    ) {
        self.transform = CGAffineTransform(scaleX: scale, y: scale)
    }
}
```

---

## Phase 3: FloatingTabBar.swift 대폭 수정 (핵심!)

**파일**: `PickPhoto/PickPhoto/Shared/Components/FloatingTabBar.swift`

### 3.1 크기 변경

```swift
// 변경 전
static let capsuleHeight: CGFloat = 56
widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6)

// 변경 후
static let capsuleHeight: CGFloat = 60
widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.85)
```

### 3.2 선택 Pill 배경 추가 (핵심 신규!)

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

### 3.3 Pill 애니메이션

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

### 3.4 아이콘/텍스트 크기 축소

```swift
// 변경 전
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 24)
outgoing.font = .systemFont(ofSize: 11, weight: .medium)

// 변경 후
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20)
outgoing.font = .systemFont(ofSize: 10, weight: .medium)
```

### 3.5 Rim Light 적용

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

## Phase 4: FloatingTitleBar.swift 수정

**파일**: `PickPhoto/PickPhoto/Shared/Components/FloatingTitleBar.swift`

### 4.1 뒤로가기 버튼 크기 증가

```swift
// 변경 전: 약 36pt
// 변경 후: 44pt
backButton.widthAnchor.constraint(equalToConstant: 44),
backButton.heightAnchor.constraint(equalToConstant: 44),
```

### 4.2 Select/비우기 버튼 높이 증가

```swift
// 변경 전
config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)

// 변경 후
config.contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 18, bottom: 10, trailing: 18)
```

---

## Phase 5: ViewerViewController.swift 수정

**파일**: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`

### 5.1 삭제 버튼 (원형 유지)

```swift
deleteButton: GlassButton(tintColor: .systemRed, shape: .circle)
// 크기: 56x56 유지
// 아이콘: trash.fill
```

### 5.2 복구/영구삭제 버튼 (텍스트로 변경)

```swift
// 기존: 아이콘 버튼
// 변경: 텍스트 캡슐 버튼

restoreButton: GlassButton(tintColor: .systemBlue, shape: .capsule)
// 텍스트: "복구"

permanentDeleteButton: GlassButton(tintColor: .systemRed, shape: .capsule)
// 텍스트: "삭제"
```

---

## 수정 파일 목록

| 우선순위 | 파일 | 주요 변경 | 예상 라인 |
|---------|------|----------|----------|
| 1 | `LiquidGlassStyle.swift` | Rim Light, Inner Shadow, 상수 전면 수정 | ~80줄 |
| 2 | `GlassButton.swift` | Rim Light 레이어, 형태 옵션, 애니메이션 | ~60줄 |
| 3 | `FloatingTabBar.swift` | 크기, 선택 pill, Rim Light | ~120줄 |
| 4 | `FloatingTitleBar.swift` | 버튼 크기 증가 | ~30줄 |
| 5 | `ViewerViewController.swift` | 버튼 형태/텍스트 변경 | ~40줄 |
| **총계** | | | **~330줄** |

---

## 검증 방법

### 시각적 검증
- [ ] iOS 26 Photos 앱과 나란히 비교
- [ ] 탭바 너비/높이 유사성
- [ ] 선택 pill 애니메이션 자연스러움
- [ ] Rim Light 테두리 빛나는 느낌

### 다양한 배경 테스트
- [ ] 밝은 사진 (흰색 배경)
- [ ] 어두운 사진 (검은색 배경)
- [ ] 버튼 가시성 및 대비

### 인터랙션 테스트
- [ ] 탭 선택 시 pill 이동 애니메이션
- [ ] 버튼 탭 시 Spring bounce
- [ ] 전체적인 반응 속도

---

## 구현 체크리스트

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

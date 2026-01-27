# Liquid Glass 구현 계획 v2

**작성일**: 2026-01-27
**버전**: v2.0 (v1 기반 + 구현 실패 원인 보완)

---

## 1. 배경

### 1.1. iOS 버전별 UI 전략

| iOS 버전 | UI 방식 | 플래그 |
|---------|--------|-------|
| iOS 16~25 | FloatingOverlay (커스텀 UI) | `useFloatingUI = true` |
| iOS 26+ | 시스템 네비게이션 바 | `useFloatingUI = false` |

### 1.2. v1 구현 실패 원인 분석

| 문제 | 상세 | 해결 방안 |
|------|------|----------|
| 레이아웃 전략 혼용 | Auto Layout + Frame 기반 혼용 | **Auto Layout 전용** 명시 |
| 뷰 계층 구조 불명확 | 각 클래스 내부 구조 미정의 | **파일별 내부 구조** 상세화 |
| 통합 방법 미정의 | FloatingOverlayContainer 연결 방식 불명확 | **통합 인터페이스** 명시 |
| 크기 계산 타이밍 미정의 | 언제 어떻게 계산하는지 불명확 | **계산 시점/방식** 명시 |

---

## 2. 목표

### 2.1. 핵심 목표

**iOS 16~25의 커스텀 FloatingOverlay UI를 iOS 26 Liquid Glass 스타일과 99% 유사하게 업그레이드**

### 2.2. 품질 기준

| 기준 | 목표 |
|------|------|
| 시각적 유사도 | **99%** |
| 크기/레이아웃 | iOS 26 실측값과 동일 |
| 애니메이션 | iOS 26과 동일한 Spring 애니메이션 |
| 색상/투명도 | iOS 26 실측값 적용 |

### 2.3. 대상 컴포넌트 (우선순위)

| 순위 | 컴포넌트 | 상태 |
|------|----------|------|
| 1 | TabBar | 이번 구현 대상 |
| 2 | NavBar | 대기 |
| 3 | 플로팅 버튼 | 대기 |

---

## 3. 파일 구조

### 3.1. 파일 목록

```
Shared/Styles/
├── LiquidGlassStyle.swift           (기존, 유지)
└── LiquidGlassConstants.swift       (신규: 모든 실측 상수)

Shared/Components/
├── FloatingTabBar.swift             (기존, deprecated 예정)
├── LiquidGlassTabBar.swift          (신규: 메인 컨테이너)
├── LiquidGlassPlatter.swift         (신규: 배경 Platter)
├── LiquidGlassSelectionPill.swift   (신규: Selection Pill)
└── LiquidGlassTabButton.swift       (신규: 개별 탭 버튼)
```

### 3.2. 파일별 역할

| 파일 | 역할 | 재사용 |
|------|------|--------|
| `LiquidGlassConstants` | 실측 상수 (크기, 색상, 애니메이션) | TabBar, NavBar, Button 공용 |
| `LiquidGlassPlatter` | 배경 블러 + 둥근 모서리 컨테이너 | TabBar, NavBar 공용 |
| `LiquidGlassSelectionPill` | 선택 표시 Pill, Spring 애니메이션 | TabBar 전용 |
| `LiquidGlassTabButton` | 아이콘 + 레이블, 선택/비선택 스타일 | TabBar 전용 |
| `LiquidGlassTabBar` | 위 컴포넌트 조합, 탭 전환 로직 | - |

---

## 4. 아키텍처 설계

### 4.1. 뷰 계층 구조

```
FloatingOverlayContainer (기존)
└── LiquidGlassTabBar (신규, FloatingTabBar 대체)
    └── LiquidGlassPlatter (배경)
        ├── backgroundBlur: UIVisualEffectView
        └── backgroundOverlay: UIView
    └── LiquidGlassSelectionPill (선택 표시)
        └── pillBlur: UIVisualEffectView
    └── LiquidGlassTabButton[0] (사진보관함)
        ├── iconImageView: UIImageView
        └── titleLabel: UILabel
    └── LiquidGlassTabButton[1] (앨범)
    └── LiquidGlassTabButton[2] (휴지통)
```

### 4.2. 레이아웃 전략 (필수 준수)

**✅ Auto Layout 전용 (Frame 사용 금지)**

```swift
// ❌ 금지: layoutSubviews에서 frame 직접 설정
override func layoutSubviews() {
    super.layoutSubviews()
    button.frame = CGRect(x: ..., y: ..., width: ..., height: ...)
}

// ✅ 허용: setupConstraints에서 Auto Layout 설정
private func setupConstraints() {
    NSLayoutConstraint.activate([
        button.leadingAnchor.constraint(equalTo: ...),
        button.widthAnchor.constraint(equalToConstant: ...)
    ])
}
```

**크기 계산 방식:**
| 유형 | 방식 | 예시 |
|------|------|------|
| 비율 기반 | `multiplier` 사용 | `widthAnchor.constraint(equalTo: superview.widthAnchor, multiplier: 0.682)` |
| 고정 크기 | `equalToConstant` 사용 | `widthAnchor.constraint(equalToConstant: 94)` |
| 동적 위치 | constraint 저장 후 `.constant` 변경 | `selectionPillLeadingConstraint?.constant = newValue` |

### 4.3. 기존 코드 통합 방식

**FloatingOverlayContainer 수정 범위:**
- `FloatingTabBar` → `LiquidGlassTabBar`로 교체
- delegate 패턴 동일하게 유지

**⚠️ 프로토콜 호환성 (High 이슈 해결):**
- **기존 프로토콜 유지**: `FloatingTabBarDelegate` 그대로 사용
- `LiquidGlassTabBar`가 기존 delegate 타입을 받아 Drop-in 교체 가능
- FloatingOverlayContainer 수정 최소화

```swift
// ✅ 기존 프로토콜 유지 (FloatingTabBar.swift에 이미 정의됨)
protocol FloatingTabBarDelegate: AnyObject {
    func floatingTabBar(_ tabBar: FloatingTabBar, didSelectTabAt index: Int)
    func floatingTabBarDidTapDelete(_ tabBar: FloatingTabBar)
    func floatingTabBarDidTapEmptyTrash(_ tabBar: FloatingTabBar)
}

// LiquidGlassTabBar에서 사용
final class LiquidGlassTabBar: UIView {
    // 기존 프로토콜 타입 사용 (typealias로 연결)
    weak var delegate: FloatingTabBarDelegate?

    // 공개 메서드 (FloatingTabBar와 동일)
    var selectedIndex: Int { get set }
    func enterSelectMode(animated: Bool)
    func exitSelectMode(animated: Bool)
    func updateSelectionCount(_ count: Int)
}
```

**마이그레이션 단계:**
1. `LiquidGlassTabBar`가 `FloatingTabBarDelegate` 사용
2. `FloatingOverlayContainer`에서 `tabBar` 타입만 변경
3. delegate 연결 코드 변경 없음

---

## 5. 상수 정의 (iOS 26 실측값)

### 5.1. Platter (전체 컨테이너)

| 항목 | 값 | 비고 |
|------|-----|------|
| 너비 | **max(컨텐츠, 68.2%)** | 아래 정책 참조 |
| 높이 | 62pt | 고정 |
| cornerRadius | 31pt | 높이의 절반 |
| cornerCurve | continuous | iOS 13+ |

**⚠️ 크기 정책 (혼합 방식):**

```swift
let contentWidth: CGFloat = 274  // 버튼×3 + 패딩×2 - 겹침×2
let ratioWidth = UIScreen.main.bounds.width * 0.682
let platterWidth = max(contentWidth, ratioWidth)
```

| 기기 | 화면폭 | 68.2% | contentWidth | **적용 너비** |
|------|--------|-------|--------------|---------------|
| iPhone SE | 375pt | 255pt | 274pt | **274pt** (컨텐츠) |
| iPhone 15 | 393pt | 268pt | 274pt | **274pt** (컨텐츠) |
| iPhone 17 | 402pt | 274pt | 274pt | **274pt** (동일) |
| iPad | 744pt | 507pt | 274pt | **507pt** (비율) |

**버튼 배치:**
- 버튼 영역(274pt)은 항상 고정
- Platter가 더 클 경우 **버튼을 Platter 중앙 정렬**
- 남는 공간은 좌우 패딩으로 흡수

```swift
// Platter constraint
platter.widthAnchor.constraint(equalToConstant: platterWidth)

// 버튼 스택 중앙 정렬
tabStackView.centerXAnchor.constraint(equalTo: platter.centerXAnchor)
```

### 5.2. Selection Pill

| 항목 | 값 | 비고 |
|------|-----|------|
| 너비 | 94pt | TabButton과 동일 |
| 높이 | 54pt | Platter 높이 - 패딩×2 |
| cornerRadius | 27pt | 높이의 절반 |
| 내부 패딩 | 4pt | Platter 내부 여백 |

### 5.3. Tab Button

| 항목 | 값 | 비고 |
|------|-----|------|
| 너비 | 94pt | 고정 |
| 높이 | 54pt | Selection Pill과 동일 |
| 아이콘 pointSize | 28pt | SF Symbol |
| 아이콘 y 오프셋 | 9pt | 버튼 상단 기준 |
| 레이블 y 오프셋 | 35pt | 버튼 상단 기준 |
| 레이블 높이 | 12pt | - |

### 5.4. 배경 색상

| 항목 | iOS 26 실측값 | 현재 LiquidGlassStyle | 변경 필요 |
|------|--------------|----------------------|----------|
| Platter 배경 gray | 0.11 | - | 신규 추가 |
| Platter 배경 alpha | 0.73 | 0.12 (backgroundAlpha) | ✅ 수정 필요 |
| 선택 탭 tint | .systemBlue | - | - |
| 비선택 탭 tint | .secondaryLabel | - | - |

**⚠️ LiquidGlassConstants에 TabBar 전용 상수 추가:**
```swift
// LiquidGlassConstants.Background (TabBar 전용)
enum Background {
    static let gray: CGFloat = 0.11
    static let alpha: CGFloat = 0.73  // iOS 26 실측값
}

// LiquidGlassStyle.backgroundAlpha (0.12)는 변경하지 않음
// → 다른 컴포넌트(NavBar, 플로팅 버튼)에 영향 방지
```

### 5.5. 애니메이션

| 항목 | 값 |
|------|-----|
| duration | 0.35s |
| damping ratio | 0.8 |
| API | `UIView.animate(withDuration:delay:usingSpringWithDamping:initialSpringVelocity:options:animations:completion:)` |

### 5.6. 블러 설정

**iOS 26 실측값 (UICABackdropLayer 기반):**

| 항목 | 값 | 설명 |
|------|-----|------|
| scale | 0.25 | 1/4 해상도로 캡처 (성능 최적화) |
| zoom | 0 | 줌 없음 |
| cornerRadius | 27 | Selection Pill (높이 54/2) |
| cornerCurve | continuous | 부드러운 곡선 |
| zPosition | -2 | 최하단 배치 |

**gaussianBlur 필터:**

| 파라미터 | 값 | 설명 |
|----------|-----|------|
| inputRadius | 2 | 블러 반경 (약함) |
| inputNormalizeEdges | 1 | 엣지 정규화 |
| inputQuality | "default" | 품질 |

**iOS 16~25 블러 구현 (결정):**

| 컴포넌트 | UIBlurEffect.Style | overlay 색상 | 이유 |
|----------|-------------------|--------------|------|
| Platter 배경 | `.systemUltraThinMaterialDark` | gray 0.11, alpha 0.73 | 투명 블러 + 정확한 overlay로 iOS 26 실측값 직접 적용 |
| Selection Pill | `.systemThinMaterialDark` | 없음 | Platter보다 "선명한 블러"로 선택 영역 강조 |

```swift
// LiquidGlassConstants에 추가
enum Blur {
    static let platterStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark
    static let platterOverlayAlpha: CGFloat = 0.73  // iOS 26 실측값 (gray 0.11 위에)
    static let pillStyle: UIBlurEffect.Style = .systemThinMaterialDark
}

// 적용 코드
// Platter
let blur = UIBlurEffect(style: .systemUltraThinMaterialDark)
backgroundBlur.effect = blur
backgroundOverlay.backgroundColor = UIColor(white: 0.11, alpha: 0.73)

// Selection Pill
pillBlur.effect = UIBlurEffect(style: .systemThinMaterialDark)
```

> ⚠️ gaussianBlur radius=2는 Public API로 구현 불가. UIVisualEffectView 스타일로 대체.

### 5.7. Color Matrix (5×4 행렬)

**선택된 탭 아이콘 (파란 틴트):**
```swift
let selectedMatrix: [Float] = [
    // R      G      B      A      bias
    0.500, 0.000, 0.000, 0.000, 0.000,  // R: 채도 50%
    0.000, 0.500, 0.000, 0.000, 0.569,  // G: 채도 50% + 녹색 틴트
    0.000, 0.000, 0.500, 0.000, 1.000,  // B: 채도 50% + 파란색 최대
    0.000, 0.000, 0.000, 1.000, 0.000   // A: 유지
]
// 결과: .systemBlue 유사 틴트
```

**비선택 탭 아이콘 (회색):**
```swift
let unselectedMatrix: [Float] = [
    // R       G       B       A      bias
     0.798, -0.680, -0.069, 0.000, 0.950,  // R
    -0.202,  0.321, -0.069, 0.000, 0.950,  // G
    -0.202, -0.679,  0.931, 0.000, 0.950,  // B
     0.000,  0.000,  0.000, 1.000, 0.000   // A
]
// 결과: 탈색 + 밝은 회색 (bias 0.95로 밝기 증가)
```

**배경 색상 보정:**
```swift
let backgroundMatrix: [Float] = [
    // R       G       B       A      bias
     1.082, -0.113, -0.011, 0.000, 0.135,  // R: 약간 증가
    -0.034,  1.003, -0.011, 0.000, 0.135,  // G: 유지
    -0.034, -0.113,  1.105, 0.000, 0.135,  // B: 약간 증가
     0.000,  0.000,  0.000, 1.000, 0.000   // A: 유지
]
// 결과: 채도/밝기 미세 증가 (유리 느낌)
```

**⚠️ iOS 16~25 구현 방식:**
- CAFilter는 Private API → `UIVisualEffectView` + `tintColor` 조합으로 대체
- 선택 탭: `.systemBlue` tintColor
- 비선택 탭: `.secondaryLabel` tintColor

### 5.8. 테두리 (Border)

**LiquidGlassStyle 기존값 사용:**
```swift
static let borderWidth: CGFloat = 0.5
static let borderAlpha: CGFloat = 0.30  // 유리 절단면 느낌
```

**적용 대상:**
- Platter: cornerRadius = 31
- Selection Pill: cornerRadius = 27

```swift
// 적용 코드
LiquidGlassStyle.applyBorder(to: layer, cornerRadius: 31)
```

### 5.9. 그림자 (Shadow)

**외부 그림자 (Platter 전체):**
```swift
// LiquidGlassStyle 기존값
static let shadowOpacity: Float = 0.25
static let shadowRadius: CGFloat = 16
static let shadowOffset = CGSize(width: 0, height: 4)
```

**내부 그림자 (innerShadowView):**
- iOS 26에서 발견되었으나 상세 설정 미파악
- iOS 16~25: 생략 또는 추후 추가

```swift
// 적용 코드
LiquidGlassStyle.applyShadow(to: platter.layer, cornerRadius: 31)
```

### 5.10. 하이라이트 (Specular)

**LiquidGlassStyle 기존값:**
```swift
static let highlightTopAlpha: CGFloat = 0.15
static let highlightBottomAlpha: CGFloat = 0.0
static let highlightLocation: NSNumber = 0.5  // 버튼 높이의 50%까지만 빛이 맺힘
```

**Platter 상단에 적용:**
```swift
let highlightLayer = LiquidGlassStyle.createSpecularHighlightLayer()
highlightLayer.frame = platter.bounds
highlightLayer.cornerRadius = 31
platter.layer.addSublayer(highlightLayer)
```

### 5.11. destOut 마스킹 (Selection Pill 영역)

**역할:**
- 선택된 탭 위치에 "구멍"을 뚫어서 Selection Pill의 블러가 보이게 함

**iOS 26 구현:**
```swift
// Private API
layer.backgroundColor = UIColor.black.cgColor
layer.setValue("destOut", forKey: "compositingFilter")
// CAMatchMoveAnimation으로 Selection Pill과 위치 동기화
```

**iOS 16~25 대체 방안 (결정):**

compositingFilter는 Private API → **CALayer.mask 활용**

```swift
// Selection Pill 영역을 마스크로 처리
// 1. 비선택 탭 ContentView에 마스크 레이어 적용
// 2. Selection Pill 위치에 "구멍" 생성

func updateMask(for pillFrame: CGRect) {
    let maskLayer = CAShapeLayer()
    let path = UIBezierPath(rect: contentView.bounds)
    // Selection Pill 영역을 제외 (구멍 뚫기)
    let pillPath = UIBezierPath(roundedRect: pillFrame, cornerRadius: 27)
    path.append(pillPath)
    maskLayer.path = path.cgPath
    maskLayer.fillRule = .evenOdd  // 내부 영역 제외
    contentView.layer.mask = maskLayer
}
```

**시각적 차이:**
| 항목 | iOS 26 (destOut) | iOS 16~25 (mask) | 차이 |
|------|------------------|------------------|------|
| 구멍 효과 | ✅ 완벽 | ✅ 동일 | 없음 |
| 애니메이션 | CAMatchMoveAnimation | mask path 애니메이션 | 구현 복잡도 ↑ |
| 성능 | GPU 합성 | CPU path 계산 | 미미한 차이 |

> ✅ CALayer.mask + fillRule.evenOdd로 destOut과 동일한 시각 효과 구현 가능

### 5.12. zPosition 구조

| 레이어 | zPosition | 설명 |
|--------|-----------|------|
| Platter 배경 (블러) | -2 | 최하단 |
| ContentView (비선택 탭) | 0 | 기본 |
| Selection Pill | 10 | 최상단 (선택 표시) |
| Tab Buttons | 1 | Selection Pill 아래 |

**구현 코드:**
```swift
// LiquidGlassPlatter
backgroundBlur.layer.zPosition = -2

// LiquidGlassTabBar
selectionPill.layer.zPosition = 10
tabButtons.forEach { $0.layer.zPosition = 1 }
```

---

## 6. 파일별 상세 설계

### 6.1. LiquidGlassConstants.swift

```swift
enum LiquidGlassConstants {
    enum Platter {
        static let height: CGFloat = 62
        static let cornerRadius: CGFloat = 31
        static let padding: CGFloat = 4  // 내부 여백 (좌우)
        static let ratioToScreen: CGFloat = 0.682  // iOS 26 실측 비율

        // 컨텐츠 기반 너비 (최소 보장)
        // = padding×2 + button×3 + spacing×2
        // = 4×2 + 94×3 - 8×2 = 274pt
        static var contentWidth: CGFloat {
            padding * 2 + TabButton.width * 3 + TabButton.spacing * 2
        }

        // 실제 적용 너비: max(컨텐츠, 화면×68.2%)
        static func calculatedWidth(screenWidth: CGFloat) -> CGFloat {
            max(contentWidth, screenWidth * ratioToScreen)
        }
    }

    enum SelectionPill {
        static let width: CGFloat = 94
        static let height: CGFloat = 54
        static let cornerRadius: CGFloat = 27
    }

    enum TabButton {
        static let width: CGFloat = 94
        static let height: CGFloat = 54
        static let spacing: CGFloat = -8  // 버튼 간 겹침 (음수)
        static let iconPointSize: CGFloat = 28
        static let iconTopOffset: CGFloat = 9
        static let labelTopOffset: CGFloat = 35
        static let labelHeight: CGFloat = 12
    }

    enum Background {
        static let gray: CGFloat = 0.11
        static let alpha: CGFloat = 0.73
    }

    enum Animation {
        static let duration: TimeInterval = 0.35
        static let dampingRatio: CGFloat = 0.8
    }
}
```

### 6.2. LiquidGlassPlatter.swift

**내부 뷰 계층:**
```
LiquidGlassPlatter (UIView)
├── backgroundBlur: UIVisualEffectView  (전체 영역)
└── backgroundOverlay: UIView           (전체 영역, 블러 위)
```

**핵심 구현:**
```swift
final class LiquidGlassPlatter: UIView {
    private lazy var backgroundBlur: UIVisualEffectView = { ... }()
    private lazy var backgroundOverlay: UIView = { ... }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    private func setupUI() {
        layer.cornerRadius = LiquidGlassConstants.Platter.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        addSubview(backgroundBlur)
        addSubview(backgroundOverlay)
    }

    private func setupConstraints() {
        // backgroundBlur: 전체 영역
        NSLayoutConstraint.activate([
            backgroundBlur.topAnchor.constraint(equalTo: topAnchor),
            backgroundBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundBlur.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])

        // backgroundOverlay: 전체 영역
        NSLayoutConstraint.activate([
            backgroundOverlay.topAnchor.constraint(equalTo: topAnchor),
            backgroundOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundOverlay.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }
}
```

### 6.3. LiquidGlassSelectionPill.swift

**내부 뷰 계층:**
```
LiquidGlassSelectionPill (UIView)
└── pillBlur: UIVisualEffectView  (전체 영역)
```

**핵심 구현:**
```swift
final class LiquidGlassSelectionPill: UIView {
    private lazy var pillBlur: UIVisualEffectView = { ... }()

    /// leading constraint 저장 (애니메이션용)
    private(set) var leadingConstraint: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    private func setupUI() {
        layer.cornerRadius = LiquidGlassConstants.SelectionPill.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        addSubview(pillBlur)
    }

    /// 위치 이동 (버튼 실제 위치 기반)
    /// - Parameters:
    ///   - button: 이동할 대상 버튼
    ///   - animated: 애니메이션 여부
    func moveTo(button: UIView, animated: Bool) {
        // ⚠️ Auto Layout 완료 보장 후 frame 접근
        button.superview?.layoutIfNeeded()
        let newLeading = button.frame.origin.x

        if animated {
            UIView.animate(
                withDuration: LiquidGlassConstants.Animation.duration,
                delay: 0,
                usingSpringWithDamping: LiquidGlassConstants.Animation.dampingRatio,
                initialSpringVelocity: 0,
                options: .curveEaseInOut
            ) {
                self.leadingConstraint?.constant = newLeading
                self.superview?.layoutIfNeeded()
            }
        } else {
            leadingConstraint?.constant = newLeading
            superview?.layoutIfNeeded()
        }
    }
}
```

### 6.4. LiquidGlassTabButton.swift

**내부 뷰 계층:**
```
LiquidGlassTabButton (UIControl)
├── iconImageView: UIImageView  (상단)
└── titleLabel: UILabel         (하단)
```

**핵심 구현:**
```swift
final class LiquidGlassTabButton: UIControl {
    private lazy var iconImageView: UIImageView = { ... }()
    private lazy var titleLabel: UILabel = { ... }()

    /// 선택 상태
    var isSelectedTab: Bool = false {
        didSet { updateAppearance() }
    }

    init(icon: String, title: String) {
        super.init(frame: .zero)
        setupUI(icon: icon, title: title)
        setupConstraints()
    }

    private func setupConstraints() {
        let const = LiquidGlassConstants.TabButton.self

        NSLayoutConstraint.activate([
            // 아이콘: 상단 중앙
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: const.iconTopOffset),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),

            // 레이블: 아이콘 아래
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: const.labelTopOffset),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: const.labelHeight)
        ])
    }

    private func updateAppearance() {
        let color: UIColor = isSelectedTab ? .systemBlue : .secondaryLabel
        iconImageView.tintColor = color
        titleLabel.textColor = color
    }
}
```

### 6.5. LiquidGlassTabBar.swift

**내부 뷰 계층:**
```
LiquidGlassTabBar (UIView)
├── platter: LiquidGlassPlatter           (배경, 중앙 정렬)
├── selectionPill: LiquidGlassSelectionPill (platter 내부)
├── tabButtons[0]: LiquidGlassTabButton    (platter 내부)
├── tabButtons[1]: LiquidGlassTabButton    (platter 내부)
└── tabButtons[2]: LiquidGlassTabButton    (platter 내부)
```

**Platter 크기 계산:**
```swift
private func setupConstraints() {
    let platterConst = LiquidGlassConstants.Platter.self
    let pillConst = LiquidGlassConstants.SelectionPill.self
    let buttonConst = LiquidGlassConstants.TabButton.self

    // Platter 너비: max(컨텐츠, 화면×68.2%)
    let screenWidth = UIScreen.main.bounds.width
    let platterWidth = platterConst.calculatedWidth(screenWidth: screenWidth)

    // Platter: 중앙 정렬
    NSLayoutConstraint.activate([
        platter.centerXAnchor.constraint(equalTo: centerXAnchor),
        platter.centerYAnchor.constraint(equalTo: centerYAnchor),
        platter.widthAnchor.constraint(equalToConstant: platterWidth),
        platter.heightAnchor.constraint(equalToConstant: platterConst.height)
    ])

    // Selection Pill: platter 내부, 고정 크기
    // ⚠️ 버튼 실제 위치 기반으로 이동 (상수 계산 대신)
    selectionPill.leadingConstraint = selectionPill.leadingAnchor.constraint(
        equalTo: platter.leadingAnchor,
        constant: platterConst.padding
    )
    NSLayoutConstraint.activate([
        selectionPill.topAnchor.constraint(equalTo: platter.topAnchor, constant: platterConst.padding),
        selectionPill.leadingConstraint!,
        selectionPill.widthAnchor.constraint(equalToConstant: pillConst.width),
        selectionPill.heightAnchor.constraint(equalToConstant: pillConst.height)
    ])

    // Tab Buttons: 버튼 그룹을 Platter 중앙에 배치
    // (Platter가 컨텐츠보다 클 경우 좌우 패딩 자동 흡수)

    // 버튼 컨테이너 또는 첫 버튼 기준 중앙 정렬
    let contentWidth = platterConst.contentWidth
    let leftPadding = (platterWidth - contentWidth) / 2 + platterConst.padding

    for (index, button) in tabButtons.enumerated() {
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: platter.topAnchor, constant: platterConst.padding),
            button.widthAnchor.constraint(equalToConstant: buttonConst.width),
            button.heightAnchor.constraint(equalToConstant: buttonConst.height)
        ])

        if index == 0 {
            // 첫 버튼: 중앙 정렬된 시작 위치
            button.leadingAnchor.constraint(
                equalTo: platter.leadingAnchor,
                constant: leftPadding
            ).isActive = true
        } else {
            // 버튼 간 겹침: spacing = -8pt
            button.leadingAnchor.constraint(
                equalTo: tabButtons[index - 1].trailingAnchor,
                constant: buttonConst.spacing
            ).isActive = true
        }
    }
}
```

**탭 선택 로직:**
```swift
var selectedIndex: Int = 0 {
    didSet {
        updateSelection(animated: true)
    }
}

private func updateSelection(animated: Bool) {
    guard selectedIndex < tabButtons.count else { return }

    // Selection Pill 이동 (버튼 실제 위치 기반)
    let targetButton = tabButtons[selectedIndex]
    selectionPill.moveTo(button: targetButton, animated: animated)

    // 버튼 상태 업데이트
    for (index, button) in tabButtons.enumerated() {
        button.isSelectedTab = (index == selectedIndex)
    }
}

@objc private func tabButtonTapped(_ sender: LiquidGlassTabButton) {
    guard let index = tabButtons.firstIndex(of: sender) else { return }
    selectedIndex = index
    delegate?.floatingTabBar(self, didSelectTabAt: index)  // 기존 delegate 사용
}
```

---

## 7. 구현 단계

### Phase 1: 상수 파일 생성
- [ ] `LiquidGlassConstants.swift` 생성
- [ ] 빌드 확인

### Phase 2: Platter 구현
- [ ] `LiquidGlassPlatter.swift` 생성
- [ ] 빌드 확인

### Phase 3: Selection Pill 구현
- [ ] `LiquidGlassSelectionPill.swift` 생성
- [ ] 빌드 확인

### Phase 4: Tab Button 구현
- [ ] `LiquidGlassTabButton.swift` 생성
- [ ] 빌드 확인

### Phase 5: TabBar 통합
- [ ] `LiquidGlassTabBar.swift` 생성
- [ ] 빌드 확인
- [ ] 3개 탭 버튼 표시 확인
- [ ] Selection Pill 이동 확인

### Phase 6: FloatingOverlayContainer 마이그레이션
- [ ] `FloatingTabBar` → `LiquidGlassTabBar` 교체
- [ ] 빌드 확인
- [ ] 탭 전환 동작 확인
- [ ] delegate 콜백 확인

### Phase 7: Select 모드 구현
- [ ] `enterSelectMode()`, `exitSelectMode()` 구현
- [ ] 툴바 UI 구현 (또는 별도 LiquidGlassToolbar)
- [ ] 선택 개수 표시

### Phase 8: 마무리
- [ ] 접근성 대응 (투명도 감소, 모션 감소)
- [ ] 다크/라이트 모드 확인
- [ ] 기존 FloatingTabBar deprecated 처리

---

## 8. 검증 체크리스트

### 기능 검증

| 항목 | 확인 |
|------|------|
| 3개 탭 버튼 모두 표시 | [ ] |
| 탭 탭하면 Pill 이동 | [ ] |
| 탭 탭하면 화면 전환 | [ ] |
| 선택 탭 파란색, 비선택 회색 | [ ] |
| Select 모드 진입/종료 | [ ] |
| 삭제 버튼 동작 | [ ] |

### 레이아웃 검증

| 항목 | 확인 |
|------|------|
| Platter 너비 max(274pt, 화면×68.2%) | [ ] |
| Platter 높이 62pt | [ ] |
| Platter 화면 중앙 정렬 | [ ] |
| 버튼 그룹 Platter 중앙 정렬 | [ ] |
| cornerRadius continuous | [ ] |
| 버튼 간 -8pt 겹침 배치 | [ ] |

### 호환성 검증

| 항목 | 확인 |
|------|------|
| iOS 16 시뮬레이터 | [ ] |
| iOS 17 시뮬레이터 | [ ] |
| 다크 모드 | [ ] |
| 라이트 모드 | [ ] |
| 투명도 감소 설정 | [ ] |

---

## 9. 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|-----------|
| 2026-01-27 | v1.0 | 최초 기획 (260127Liquid-Plan.md) |
| 2026-01-27 | v2.0 | v1 기반 + 구현 실패 원인 보완 (레이아웃 전략, 파일별 상세 설계, 통합 방식) |
| 2026-01-27 | v2.1 | GPT 리뷰 반영 - High 이슈 2개 해결 |
|  |  | - Platter 크기: 비율 → 컨텐츠 기반 (274pt) |
|  |  | - 프로토콜: 기존 FloatingTabBarDelegate 유지 |
|  |  | - Selection Pill: 상수 → 버튼 실제 위치 기반 |
|  |  | - 버튼 간격: spacing = -8pt (겹침) 추가 |
| 2026-01-27 | v2.2 | 시각적 디테일 섹션 추가 (5.6~5.12) |
|  |  | - 블러 설정 (gaussianBlur 파라미터, UICABackdropLayer) |
|  |  | - 배경 색상 LiquidGlassStyle 연결 (0.12→0.73 변경 필요) |
|  |  | - Color Matrix 5×4 행렬 (선택/비선택/배경) |
|  |  | - 테두리/그림자/하이라이트 (LiquidGlassStyle 연결) |
|  |  | - destOut 마스킹 대체 방안 (zPosition 활용) |
|  |  | - zPosition 구조 (-2 ~ 10) |
| 2026-01-27 | v2.3 | GPT 리뷰 2차 반영 - 5개 이슈 해결 |
|  |  | - High: SelectionPill layoutIfNeeded() 보장 추가 |
|  |  | - Medium: 체크리스트 68.2% → 274pt 수정 |
|  |  | - Medium: 블러 fallback 결정 (Platter/Pill 스타일 명시) |
|  |  | - Medium: destOut → CALayer.mask + evenOdd로 대체 |
|  |  | - Low: backgroundAlpha TabBar 전용 상수 분리 |
| 2026-01-27 | v2.4 | GPT 리뷰 3차 반영 - 정밀도 향상 |
|  |  | - Blur: Platter `.systemUltraThinMaterialDark` + overlay 0.73 |
|  |  | - Blur: Pill `.systemThinMaterialDark` (더 선명) |
|  |  | - 폭: `max(contentWidth, screenWidth*0.682)` 혼합 정책 |
|  |  | - 버튼 그룹 Platter 중앙 정렬 (대형 기기 대응) |

---

## 10. 참조 자료

- [260127Liquid-Plan.md](./260127Liquid-Plan.md) - v1 기획서
- [260126Liquid-tabbar.md](./260126Liquid-tabbar.md) - TabBar 상세 속성
- [DumpData/](./DumpData/) - iOS 26 JSON 덤프 파일

# Liquid Glass 구현 계획 (실측 기반)

> iOS 26.0.1 Photos 앱 실측 데이터 기반 구현 계획

**관련 문서:**
- [iOS26-LiquidGlass-Structure.md](./iOS26-LiquidGlass-Structure.md) - 공통 구조
- [iOS26-TabBar.md](./iOS26-TabBar.md) - TabBar 실측 스펙
- [iOS26-NavigationBar.md](./iOS26-NavigationBar.md) - NavigationBar 실측 스펙
- [260122LiquidGlass-Code.md](./260122LiquidGlass-Code.md) - 코드 스니펫

---

## 실측값 vs 현재 구현 비교

### TabBar (FloatingTabBar.swift)

| 항목 | 현재 구현 | iOS 26 실측 | 변경 필요 |
|------|----------|-------------|----------|
| Platter 너비 | 60% | **68.2%** (274/402) | O |
| Platter 높이 | 56pt | **62pt** | O |
| Tab Button 크기 | - | **94×54pt** | O |
| 내부 패딩 | - | **4pt** | O |
| Selection Pill 크기 | - | **94×54pt** | 신규 |
| Selection Pill cornerRadius | - | **27pt** (높이/2) | 신규 |
| cornerCurve | circular | **continuous** | O |
| 아이콘 크기 | 24pt | **30~34pt** (원본 비율) | O |
| 레이블 높이 | - | **12pt** | O |
| 레이블 y 위치 | - | **35pt** (버튼 기준) | O |

### NavigationBar (FloatingTitleBar.swift, GlassButton.swift)

| 항목 | 현재 구현 | iOS 26 실측 | 변경 필요 |
|------|----------|-------------|----------|
| NavigationBar 높이 | - | **54pt** | 참고 |
| 버튼 높이 | - | **44pt** (공통) | O |
| Back 버튼 | 36pt | **44×44pt** | O |
| Select 버튼 | - | **73.33×44pt** | O |
| Cancel 버튼 | - | **68.33×44pt** | O |
| 버튼 cornerRadius | - | **22pt** (높이/2) | O |
| 좌측 마진 | - | **16pt** | O |
| 우측 마진 | - | **16pt** | O |
| 버튼 간격 | - | **12pt** | O |

### 하단 플로팅 버튼 (ViewerViewController.swift)

| 항목 | 현재 구현 | iOS 26 실측 | 변경 필요 |
|------|----------|-------------|----------|
| 삭제 버튼 (일반) | 56×56pt | **48×48pt** | O |
| 복구/삭제 버튼 (휴지통) | - | **54×48pt** | O |
| y 좌표 | - | **798pt** | 참고 |
| 하단 여백 | - | **76pt** | O |
| 좌우 마진 (2개일 때) | - | **28pt** | O |

### 공통 스타일 (LiquidGlassStyle.swift)

| 항목 | 현재 구현 | iOS 26 실측 | 변경 필요 |
|------|----------|-------------|----------|
| 배경 gray | - | **0.11** (11%) | O |
| 배경 alpha | 0.12 | **0.73** (73%) | O |
| cornerCurve | circular | **continuous** | O |
| UICABackdropLayer scale | - | **0.25** | 참고 |

---

## Phase 1: LiquidGlassStyle.swift 수정

### 1.1 기존 상수 수정

```swift
// 배경 (실측 기반)
static let backgroundGray: CGFloat = 0.11       // 11% 밝기
static let backgroundAlpha: CGFloat = 0.73      // 73% 불투명

// cornerCurve
static let cornerCurve: CALayerCornerCurve = .continuous
```

### 1.2 TabBar 전용 상수 (신규)

```swift
// TabBar Platter
static let tabBarPlatterWidthRatio: CGFloat = 0.682  // 68.2%
static let tabBarPlatterHeight: CGFloat = 62

// Tab Button
static let tabButtonWidth: CGFloat = 94
static let tabButtonHeight: CGFloat = 54
static let tabButtonPadding: CGFloat = 4

// Selection Pill
static let selectionPillCornerRadius: CGFloat = 27  // 높이/2

// 아이콘/레이블
static let tabIconTopOffset: CGFloat = 5            // 4~7pt 중간값
static let tabLabelHeight: CGFloat = 12
static let tabLabelYPosition: CGFloat = 35
```

### 1.3 NavigationBar 버튼 상수 (신규)

```swift
// 버튼 크기
static let navButtonHeight: CGFloat = 44
static let navButtonCornerRadius: CGFloat = 22      // 높이/2
static let backButtonSize: CGFloat = 44             // 정사각형

// 여백
static let navLeadingMargin: CGFloat = 16
static let navTrailingMargin: CGFloat = 16
static let navButtonSpacing: CGFloat = 12
```

### 1.4 플로팅 버튼 상수 (신규)

```swift
// 일반 뷰어 삭제 버튼
static let floatingButtonSize: CGFloat = 48

// 휴지통 뷰어 버튼
static let trashFloatingButtonWidth: CGFloat = 54
static let trashFloatingButtonHeight: CGFloat = 48

// 여백
static let floatingButtonBottomMargin: CGFloat = 76
static let floatingButtonSideMargin: CGFloat = 28   // 2개일 때
```

---

## Phase 2: FloatingTabBar.swift 수정

### 2.1 Platter 크기 변경

```swift
// 변경 전
static let capsuleHeight: CGFloat = 56
widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6)

// 변경 후
static let capsuleHeight: CGFloat = 62
widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.682)
```

### 2.2 Tab Button 레이아웃

```swift
// Tab Button 크기
let tabButtonSize = CGSize(width: 94, height: 54)
let internalPadding: CGFloat = 4

// 위치 계산 (3개 탭)
// 탭 1: x=4, 탭 2: x=90, 탭 3: x=176
```

### 2.3 Selection Pill 추가 (핵심!)

```swift
private lazy var selectionPillView: UIView = {
    let view = UIView()
    view.backgroundColor = UIColor(white: 0.11, alpha: 0.73)
    view.layer.cornerRadius = 27
    view.layer.cornerCurve = .continuous
    return view
}()
```

### 2.4 아이콘 크기 조정

```swift
// SF Symbol 원본 비율 유지 (pointSize로 제어)
// 실측: 30~34pt 범위
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 28)
```

### 2.5 레이블 위치 조정

```swift
// 레이블 y 위치: 35pt (버튼 기준)
// 레이블 높이: 12pt
config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
    var outgoing = incoming
    outgoing.font = .systemFont(ofSize: 10, weight: .medium)  // ~12pt 높이
    return outgoing
}
```

### 2.6 cornerCurve 적용

```swift
capsuleContainer.layer.cornerCurve = .continuous
selectionPillView.layer.cornerCurve = .continuous
```

---

## Phase 3: FloatingTitleBar.swift 수정

### 3.1 버튼 높이 통일

```swift
// 모든 버튼 높이: 44pt
static let buttonHeight: CGFloat = 44
```

### 3.2 Back 버튼 크기

```swift
// 44×44pt 정사각형, cornerRadius 22pt
backButton.widthAnchor.constraint(equalToConstant: 44),
backButton.heightAnchor.constraint(equalToConstant: 44),
backButton.layer.cornerRadius = 22
backButton.layer.cornerCurve = .continuous
```

### 3.3 텍스트 버튼 (Select, Cancel 등)

```swift
// 높이 44pt, 너비는 텍스트에 따라 동적
// cornerRadius 22pt (캡슐형)
selectButton.heightAnchor.constraint(equalToConstant: 44),
selectButton.layer.cornerRadius = 22
selectButton.layer.cornerCurve = .continuous
```

### 3.4 여백 적용

```swift
// 좌측 버튼
backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16)

// 우측 버튼
selectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)

// 버튼 간격
cancelButton.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -12)
```

---

## Phase 4: GlassButton.swift 수정

### 4.1 크기 옵션

```swift
enum GlassButtonSize {
    case navBar      // 44pt 높이
    case floating    // 48pt 높이
    case trashFloat  // 54×48pt
}
```

### 4.2 cornerCurve 적용

```swift
layer.cornerCurve = .continuous
```

### 4.3 배경색 수정

```swift
// 실측 기반
backgroundColor = UIColor(white: 0.11, alpha: 0.73)
```

---

## Phase 5: ViewerViewController.swift 수정

### 5.1 삭제 버튼 (일반 뷰어)

```swift
// 48×48pt, 중앙 배치
deleteButton.frame = CGRect(
    x: (view.bounds.width - 48) / 2,
    y: view.bounds.height - 76 - 48,
    width: 48,
    height: 48
)
```

### 5.2 복구/삭제 버튼 (휴지통 뷰어)

```swift
// 54×48pt, 좌우 배치
let sideMargin: CGFloat = 28
let buttonWidth: CGFloat = 54
let buttonHeight: CGFloat = 48
let bottomMargin: CGFloat = 76

restoreButton.frame = CGRect(
    x: sideMargin,
    y: view.bounds.height - bottomMargin - buttonHeight,
    width: buttonWidth,
    height: buttonHeight
)

deleteButton.frame = CGRect(
    x: view.bounds.width - sideMargin - buttonWidth,
    y: view.bounds.height - bottomMargin - buttonHeight,
    width: buttonWidth,
    height: buttonHeight
)
```

---

## 수정 파일 목록

| 우선순위 | 파일 | 주요 변경 |
|---------|------|----------|
| 1 | `LiquidGlassStyle.swift` | 상수 전면 수정 (실측값) |
| 2 | `FloatingTabBar.swift` | Platter 크기, Selection Pill, cornerCurve |
| 3 | `FloatingTitleBar.swift` | 버튼 높이 44pt, 여백 16pt |
| 4 | `GlassButton.swift` | 크기 옵션, cornerCurve, 배경색 |
| 5 | `ViewerViewController.swift` | 플로팅 버튼 크기/위치 |

---

## 검증 체크리스트

### TabBar
- [ ] Platter 너비 68.2%
- [ ] Platter 높이 62pt
- [ ] Tab Button 94×54pt
- [ ] Selection Pill cornerRadius 27pt
- [ ] cornerCurve: continuous
- [ ] 아이콘 28~32pt (SF Symbol 원본 비율)
- [ ] 레이블 y=35pt, 높이 12pt

### NavigationBar
- [ ] 버튼 높이 44pt (공통)
- [ ] Back 버튼 44×44pt
- [ ] cornerRadius 22pt
- [ ] 좌측 마진 16pt
- [ ] 우측 마진 16pt
- [ ] 버튼 간격 12pt

### 플로팅 버튼
- [ ] 일반 삭제 48×48pt
- [ ] 휴지통 버튼 54×48pt
- [ ] 하단 여백 76pt
- [ ] 좌우 마진 28pt (2개일 때)

### 공통
- [ ] 배경 gray 0.11, alpha 0.73
- [ ] cornerCurve: continuous

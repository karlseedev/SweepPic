# Liquid Glass 구현 계획 (실측 기반)

> iOS 26.0.1 Photos 앱 실측 데이터 기반, iOS 16~25용 커스텀 구현 계획

**관련 문서:**
- [iOS26-LiquidGlass-Structure.md](./iOS26-LiquidGlass-Structure.md) - 공통 구조
- [iOS26-TabBar.md](./iOS26-TabBar.md) - TabBar 실측 스펙
- [iOS26-NavigationBar.md](./iOS26-NavigationBar.md) - NavigationBar 실측 스펙
- [260122LiquidGlass-Code.md](./260122LiquidGlass-Code.md) - 코드 스니펫

---

## 파일 구조 (신규 + 분리)

### 현재 파일 크기

| 파일 | 라인 수 | 상태 |
|------|--------|------|
| `LiquidGlassStyle.swift` | 89 | 작음 |
| `GlassButton.swift` | 120 | 작음 |
| `FloatingTitleBar.swift` | 509 | 중간 |
| `FloatingTabBar.swift` | 747 | 큼 |
| `ViewerViewController.swift` | 1148 | **1000줄 초과** |

### 변경 후 파일 구조

```
Shared/Styles/
├── LiquidGlassStyle.swift              (기존, 유지)
└── LiquidGlassStyle+Measurements.swift (신규, 실측 상수 ~80줄)

Shared/Components/
├── FloatingTabBar.swift                (기존, 일부 수정)
├── FloatingTabBar+SelectionPill.swift  (신규, ~80줄)
├── SelectionPillView.swift             (신규, ~50줄)
├── FloatingTitleBar.swift              (기존, 수정)
└── GlassButton.swift                   (기존, 수정)

Features/Viewer/
├── ViewerViewController.swift              (기존, 플로팅 버튼 분리 → ~900줄)
└── ViewerViewController+FloatingButtons.swift (신규, ~150줄)
```

### 파일별 작업 요약

| 파일 | 작업 | 내용 |
|------|------|------|
| `LiquidGlassStyle+Measurements.swift` | **신규** | 실측 상수 (TabBar, NavBar, 플로팅 버튼) |
| `SelectionPillView.swift` | **신규** | Selection Pill 독립 컴포넌트 |
| `FloatingTabBar+SelectionPill.swift` | **신규** | Selection Pill 로직 Extension |
| `ViewerViewController+FloatingButtons.swift` | **신규** | 플로팅 버튼 로직 분리 |
| `LiquidGlassStyle.swift` | 유지 | 변경 없음 |
| `FloatingTabBar.swift` | 수정 | Platter 크기, cornerCurve |
| `FloatingTitleBar.swift` | 수정 | 버튼 크기/여백 |
| `GlassButton.swift` | 수정 | 크기 타입, cornerCurve |
| `ViewerViewController.swift` | 분리 | 플로팅 버튼 코드 Extension으로 이동 |

---

## 실측값 vs 현재 구현 비교

### TabBar (FloatingTabBar.swift)

| 항목 | 현재 구현 | 실측값 | 변경 필요 |
|------|----------|--------|----------|
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

| 항목 | 현재 구현 | 실측값 | 변경 필요 |
|------|----------|--------|----------|
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

| 항목 | 현재 구현 | 실측값 | 변경 필요 |
|------|----------|--------|----------|
| 삭제 버튼 (일반) | 56×56pt | **48×48pt** | O |
| 복구/삭제 버튼 (휴지통) | - | **54×48pt** | O |
| y 좌표 | - | **798pt** | 참고 |
| 하단 여백 | - | **76pt** | O |
| 좌우 마진 (2개일 때) | - | **28pt** | O |

### 공통 스타일 (LiquidGlassStyle.swift)

| 항목 | 현재 구현 | 실측값 | 변경 필요 |
|------|----------|--------|----------|
| 배경 gray | - | **0.11** (11%) | O |
| 배경 alpha | 0.12 | **0.73** (73%) | O |
| cornerCurve | circular | **continuous** | O |
| UICABackdropLayer scale | - | **0.25** | 참고 |

---

## Phase 1: 실측 상수 파일 생성

### 1.1 LiquidGlassStyle+Measurements.swift (신규)

```swift
// MARK: - 실측 기반 상수 (iOS 26.0.1 Photos 앱)

extension LiquidGlassStyle {

    // MARK: - 배경

    static let measuredBackgroundGray: CGFloat = 0.11
    static let measuredBackgroundAlpha: CGFloat = 0.73

    static var measuredBackgroundColor: UIColor {
        UIColor(white: measuredBackgroundGray, alpha: measuredBackgroundAlpha)
    }

    // MARK: - TabBar Platter

    static let tabPlatterWidthRatio: CGFloat = 0.682  // 68.2%
    static let tabPlatterHeight: CGFloat = 62

    // MARK: - Tab Button

    static let tabButtonWidth: CGFloat = 94
    static let tabButtonHeight: CGFloat = 54
    static let tabButtonPadding: CGFloat = 4

    // MARK: - Selection Pill

    static let selectionPillWidth: CGFloat = 94
    static let selectionPillHeight: CGFloat = 54
    static let selectionPillCornerRadius: CGFloat = 27  // 높이/2

    // MARK: - Tab 아이콘/레이블

    static let tabIconPointSize: CGFloat = 28
    static let tabIconTopOffset: CGFloat = 5
    static let tabLabelHeight: CGFloat = 12
    static let tabLabelYPosition: CGFloat = 35
    static let tabLabelFontSize: CGFloat = 10

    // MARK: - NavigationBar 버튼

    static let navButtonHeight: CGFloat = 44
    static let navButtonCornerRadius: CGFloat = 22
    static let backButtonSize: CGFloat = 44

    // MARK: - NavigationBar 여백

    static let navLeadingMargin: CGFloat = 16
    static let navTrailingMargin: CGFloat = 16
    static let navButtonSpacing: CGFloat = 12

    // MARK: - 플로팅 버튼

    static let floatingButtonSize: CGFloat = 48
    static let trashFloatingWidth: CGFloat = 54
    static let trashFloatingHeight: CGFloat = 48
    static let floatingBottomMargin: CGFloat = 76
    static let floatingSideMargin: CGFloat = 28
}
```

---

## Phase 2: Selection Pill 컴포넌트 생성

### 2.1 SelectionPillView.swift (신규)

```swift
import UIKit

/// 탭 선택 시 표시되는 배경 pill
class SelectionPillView: UIView {

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupStyle()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupStyle()
    }

    private func setupStyle() {
        backgroundColor = LiquidGlassStyle.measuredBackgroundColor
        layer.cornerRadius = LiquidGlassStyle.selectionPillCornerRadius
        layer.cornerCurve = .continuous
        layer.masksToBounds = false
    }
}
```

### 2.2 FloatingTabBar+SelectionPill.swift (신규)

```swift
import UIKit

extension FloatingTabBar {

    /// Selection Pill 설정
    func setupSelectionPill() {
        // SelectionPillView 생성 및 추가
        // 초기 위치 설정
    }

    /// Selection Pill을 선택된 탭 위치로 이동
    func moveSelectionPill(to index: Int, animated: Bool = true) {
        guard let targetButton = tabButton(at: index) else { return }

        let targetFrame = CGRect(
            x: targetButton.frame.origin.x,
            y: LiquidGlassStyle.tabButtonPadding,
            width: LiquidGlassStyle.selectionPillWidth,
            height: LiquidGlassStyle.selectionPillHeight
        )

        if animated {
            UIView.animate(
                withDuration: 0.35,
                delay: 0,
                usingSpringWithDamping: 0.8,
                initialSpringVelocity: 0.5,
                options: [.beginFromCurrentState]
            ) {
                self.selectionPillView.frame = targetFrame
            }
        } else {
            selectionPillView.frame = targetFrame
        }
    }
}
```

---

## Phase 3: FloatingTabBar.swift 수정

### 3.1 Platter 크기 변경

```swift
// 변경 전
static let capsuleHeight: CGFloat = 56
widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6)

// 변경 후
static let capsuleHeight: CGFloat = LiquidGlassStyle.tabPlatterHeight  // 62
widthAnchor.constraint(equalTo: widthAnchor, multiplier: LiquidGlassStyle.tabPlatterWidthRatio)  // 0.682
```

### 3.2 cornerCurve 적용

```swift
capsuleContainer.layer.cornerCurve = .continuous
```

### 3.3 아이콘/레이블 크기 조정

```swift
// 아이콘
config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
    pointSize: LiquidGlassStyle.tabIconPointSize  // 28
)

// 레이블
outgoing.font = .systemFont(ofSize: LiquidGlassStyle.tabLabelFontSize, weight: .medium)  // 10
```

---

## Phase 4: FloatingTitleBar.swift 수정

### 4.1 버튼 높이 통일 (44pt)

```swift
backButton.heightAnchor.constraint(equalToConstant: LiquidGlassStyle.navButtonHeight)
selectButton.heightAnchor.constraint(equalToConstant: LiquidGlassStyle.navButtonHeight)
```

### 4.2 Back 버튼 크기 (44×44pt)

```swift
backButton.widthAnchor.constraint(equalToConstant: LiquidGlassStyle.backButtonSize)
backButton.layer.cornerRadius = LiquidGlassStyle.navButtonCornerRadius  // 22
backButton.layer.cornerCurve = .continuous
```

### 4.3 여백 적용

```swift
// 좌측
backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: LiquidGlassStyle.navLeadingMargin)

// 우측
selectButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -LiquidGlassStyle.navTrailingMargin)

// 버튼 간격
cancelButton.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -LiquidGlassStyle.navButtonSpacing)
```

---

## Phase 5: GlassButton.swift 수정

### 5.1 크기 타입 추가

```swift
enum GlassButtonSizeType {
    case navBar         // 44pt 높이
    case floatingSmall  // 48×48pt
    case floatingLarge  // 54×48pt

    var size: CGSize { ... }
    var cornerRadius: CGFloat { ... }
}
```

### 5.2 cornerCurve 적용

```swift
layer.cornerCurve = .continuous
```

---

## Phase 6: ViewerViewController 플로팅 버튼 분리

### 6.1 ViewerViewController+FloatingButtons.swift (신규)

기존 `ViewerViewController.swift`에서 플로팅 버튼 관련 코드 분리:

```swift
import UIKit

extension ViewerViewController {

    // MARK: - 플로팅 버튼 설정

    func setupFloatingButtons() {
        // 삭제 버튼 (일반 뷰어)
        // 복구/삭제 버튼 (휴지통 뷰어)
    }

    func layoutFloatingButtons() {
        if isTrashMode {
            layoutTrashFloatingButtons()
        } else {
            layoutSingleDeleteButton()
        }
    }

    // MARK: - 일반 삭제 버튼 (48×48pt, 중앙)

    private func layoutSingleDeleteButton() {
        let buttonSize = LiquidGlassStyle.floatingButtonSize
        let bottomMargin = LiquidGlassStyle.floatingBottomMargin

        deleteButton.frame = CGRect(
            x: (view.bounds.width - buttonSize) / 2,
            y: view.bounds.height - bottomMargin - buttonSize,
            width: buttonSize,
            height: buttonSize
        )
    }

    // MARK: - 휴지통 버튼 (54×48pt, 좌우)

    private func layoutTrashFloatingButtons() {
        let buttonWidth = LiquidGlassStyle.trashFloatingWidth
        let buttonHeight = LiquidGlassStyle.trashFloatingHeight
        let sideMargin = LiquidGlassStyle.floatingSideMargin
        let bottomMargin = LiquidGlassStyle.floatingBottomMargin
        let buttonY = view.bounds.height - bottomMargin - buttonHeight

        restoreButton.frame = CGRect(
            x: sideMargin,
            y: buttonY,
            width: buttonWidth,
            height: buttonHeight
        )

        permanentDeleteButton.frame = CGRect(
            x: view.bounds.width - sideMargin - buttonWidth,
            y: buttonY,
            width: buttonWidth,
            height: buttonHeight
        )
    }
}
```

### 6.2 ViewerViewController.swift 수정

- 플로팅 버튼 관련 코드 제거 (Extension으로 이동)
- 1148줄 → ~900줄로 축소

---

## 작업 순서

| 순서 | 파일 | 작업 | 예상 라인 |
|------|------|------|----------|
| 1 | `LiquidGlassStyle+Measurements.swift` | 신규 생성 | ~80줄 |
| 2 | `SelectionPillView.swift` | 신규 생성 | ~50줄 |
| 3 | `FloatingTabBar+SelectionPill.swift` | 신규 생성 | ~80줄 |
| 4 | `FloatingTabBar.swift` | 크기/cornerCurve 수정 | 수정 |
| 5 | `FloatingTitleBar.swift` | 버튼 크기/여백 수정 | 수정 |
| 6 | `GlassButton.swift` | 크기 타입/cornerCurve 수정 | 수정 |
| 7 | `ViewerViewController+FloatingButtons.swift` | 신규 생성 | ~150줄 |
| 8 | `ViewerViewController.swift` | 플로팅 버튼 코드 분리 | 분리 |

---

## 검증 체크리스트

### TabBar
- [ ] Platter 너비 68.2%
- [ ] Platter 높이 62pt
- [ ] Tab Button 94×54pt
- [ ] Selection Pill cornerRadius 27pt
- [ ] cornerCurve: continuous
- [ ] 아이콘 28pt (SF Symbol)
- [ ] 레이블 y=35pt, 폰트 10pt

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

### 파일 크기
- [ ] 모든 파일 1000줄 미만
- [ ] ViewerViewController.swift ~900줄로 축소

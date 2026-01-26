# iOS 26 UI 속성 추출 계획

**작성일**: 2026-01-26
**상태**: SystemUIInspector3 구현 대기

---

## 1. 목적

iOS 26 시스템 UI (TabBar, NavigationBar 등)를 **픽셀 단위로 동일하게 재현**하기 위해, 모든 UI 속성을 파일로 추출하는 도구를 만든다.

### 1.1. 배경

- iOS 16~25에서는 커스텀 FloatingOverlay UI 사용
- iOS 26에서는 시스템 UI와 동일한 Liquid Glass 스타일 필요
- 기존 문서 (iOS26-TabBar.md, iOS26-NavigationBar.md)는 수동 조사 결과
- **자동화된 추출 도구**가 필요

### 1.2. 요구사항

| 항목 | 요구사항 |
|------|----------|
| 출력 형식 | **JSON** (Claude가 파싱하기 쉬움) |
| 출력 위치 | Documents 폴더 (파일로 저장) |
| 실행 방식 | 앱 내 디버그 버튼 |
| 대상 | TabBar, NavigationBar, 하단 플로팅 버튼 |

---

## 2. 현재 상태: 테스트 완료

모든 필요한 속성에 **접근 가능함**을 확인했다.

### 2.1. 접근 가능한 속성 요약

| 카테고리 | 접근 방법 | 상태 |
|----------|----------|------|
| CALayer 기본 | `layer.cornerRadius`, `layer.cornerCurve` 등 | ✅ |
| layer.filters | `layer.filters` (Private) | ✅ |
| layer.compositingFilter | `layer.compositingFilter` (Private) | ✅ |
| UIColor 분해 | `getWhite()`, `getRed()` | ✅ |
| _UILiquidLensView | KVC `value(forKey:)` | ✅ |
| CABackdropLayer | KVC `value(forKey:)` | ✅ |
| CAFilter 이름 | KVC `value(forKey: "name")` | ✅ |
| CAAnimation | `layer.animation(forKey:)` | ✅ |

### 2.2. 발견된 iOS 26 Private 타입

```
필터 (CAFilter):
- variableBlur
- gaussianBlur
- colorMatrix
- vibrantColorMatrix

컴포지팅 필터:
- destIn
- destOut

애니메이션 (iOS 26 신규):
- CAMatchPropertyAnimation
- CAMatchMoveAnimation
```

### 2.3. 미해결 사항

| 항목 | 상태 | 비고 |
|------|------|------|
| CAFilter 세부 파라미터 | ⚠️ 추가 조사 필요 | inputRadius 등 |

---

## 3. 다음 단계: SystemUIInspector3 구현

### 3.1. 구현 목표

```
Debug/SystemUIInspector3.swift
```

- JSON 형식으로 UI 계층 전체 덤프
- 버튼 한 번으로 현재 화면의 모든 시스템 UI 속성 추출
- Documents 폴더에 파일 저장

### 3.2. 수집할 속성 목록

```swift
// A. UIView 기본
struct ViewProperties {
    let className: String
    let frame: CGRect
    let bounds: CGRect
    let alpha: CGFloat
    let isHidden: Bool
    let clipsToBounds: Bool
    let backgroundColor: ColorInfo?
}

// B. CALayer 속성
struct LayerProperties {
    let cornerRadius: CGFloat
    let cornerCurve: String
    let masksToBounds: Bool
    let borderWidth: CGFloat
    let borderColor: ColorInfo?
    let shadowColor: ColorInfo?
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: CGSize
    let filters: [FilterInfo]
    let compositingFilter: String?
}

// C. UIColor 분해
struct ColorInfo {
    let white: CGFloat?
    let alpha: CGFloat
    let red: CGFloat?
    let green: CGFloat?
    let blue: CGFloat?
}

// D. CAFilter 정보
struct FilterInfo {
    let name: String
    let type: String
    // 추가 파라미터 (가능하면)
}

// E. Private 클래스 속성
struct LiquidLensInfo {
    let warpsContentBelow: Bool
    let liftedContentMode: Int
    let hasCustomRestingBackground: Bool
}

struct BackdropLayerInfo {
    let scale: CGFloat
    let groupName: String?
    let captureOnly: Bool
    let usesGlobalGroupNamespace: Bool
}

// F. 애니메이션 정보
struct AnimationInfo {
    let key: String
    let type: String
    let duration: Double
    let fillMode: String
    let timingFunction: String?
}
```

### 3.3. 출력 예시

```json
{
  "captureDate": "2026-01-26T12:00:00Z",
  "screen": "TabBar",
  "views": [
    {
      "className": "_UITabBarPlatterView",
      "frame": {"x": 0, "y": 0, "width": 402, "height": 54},
      "layer": {
        "cornerRadius": 27,
        "cornerCurve": "continuous",
        "filters": [
          {"name": "variableBlur", "type": "variableBlur"}
        ]
      },
      "children": [...]
    }
  ]
}
```

### 3.4. 활성화 방법

`SceneDelegate.swift`의 `showMainInterface()` 끝에 추가:

```swift
#if DEBUG
SystemUIInspector3.shared.showDebugButton()
#endif
```

### 3.5. 사용 방법

1. 디버그 빌드로 앱 실행 (iOS 26 시뮬레이터)
2. 조사할 화면으로 이동
3. 디버그 버튼 탭
4. Documents 폴더에서 JSON 파일 확인

```bash
open $(xcrun simctl get_app_container booted com.pickphoto.app data)/Documents/
```

---

## 4. 부록: 테스트 결과 상세

### 4.1. CALayer 기본 속성

```
cornerRadius: 0.0 ✅
cornerCurve: continuous ✅
masksToBounds: false ✅
borderWidth: 0.0 ✅
shadowOpacity: 0.0 ✅
shadowRadius: 3.0 ✅
```

### 4.2. layer.filters

```
[PocketBlur] layer.filters: [variableBlur]
[_UIPortalView] layer.filters: [colorMatrix]
[HostedViewWrapper] layer.filters: [gaussianBlur]
[SubviewContainerView] layer.filters: [gaussianBlur]
```

### 4.3. layer.compositingFilter

```
[_UIPortalView] layer.compositingFilter: destIn
[DestOutView] layer.compositingFilter: destOut
```

### 4.4. UIColor 분해

```
[systemBackground]
  getWhite: white=0.000, alpha=1.000 ✅
  getRed: r=0.000, g=0.000, b=0.000, a=1.000 ✅
[gray 0.5 alpha 0.8]
  getWhite: white=0.500, alpha=0.800 ✅
```

### 4.5. _UILiquidLensView (KVC)

```
warpsContentBelow: 1 ✅
liftedContentMode: 1 ✅
hasCustomRestingBackground: 1 ✅
```

### 4.6. CABackdropLayer (KVC)

```
scale: 0.5 ✅
groupName: backgroundGroup-0x... ✅
captureOnly: 0 ✅
usesGlobalGroupNamespace: 0 ✅
```

### 4.7. CAFilter (KVC)

```
[CABackdropLayer] Filter: variableBlur
  name: variableBlur ✅
  type: variableBlur ✅
```

### 4.8. CAAnimation

```
iOS 26 신규 타입:
- CAMatchPropertyAnimation (duration: inf, fillMode: both)
- CAMatchMoveAnimation (duration: inf, fillMode: both)

animationKeys:
- match-bounds
- match-position
- match-corner-radius
- match-corner-radii
- match-corner-curve
- match-hidden
```

---

## 5. 부록: 참고 자료

### 5.1. 기존 조사 문서

| 문서 | 내용 |
|------|------|
| `iOS26-TabBar.md` | TabBar 수동 조사 결과 |
| `iOS26-NavigationBar.md` | NavigationBar 수동 조사 결과 |
| `260125inspect.md` | 조사 방법 히스토리 (참고용) |

### 5.2. 기존 디버그 파일

| 파일 | 상태 |
|------|------|
| `Debug/SystemUIInspector.swift` | ❌ 불완전 (class_copyIvarList) |
| `Debug/SystemUIInspector2.swift` | ❌ 불완전 (_ivarDescription만) |
| `Debug/SystemUIInspector3.swift` | 🔜 **구현 예정** |

### 5.3. 핵심 접근 방법

```swift
// 1. layer.filters 접근
if let filters = layer.filters {
    for filter in filters {
        if let name = (filter as? NSObject)?.value(forKey: "name") {
            print(name)  // "variableBlur"
        }
    }
}

// 2. layer.compositingFilter 접근
if let filter = layer.compositingFilter {
    print(filter)  // "destOut"
}

// 3. Private 클래스 KVC 접근
if let value = view.value(forKey: "warpsContentBelow") {
    print(value)  // 1
}

// 4. UIColor 분해
var white: CGFloat = 0, alpha: CGFloat = 0
color.getWhite(&white, alpha: &alpha)
```

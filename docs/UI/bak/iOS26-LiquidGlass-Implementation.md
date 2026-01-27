# iOS 26 Liquid Glass 구현 자료

**작성일**: 2026-01-26
**데이터 소스**: SystemUIInspector3 자동 덤프 (iOS 26.0.1)

---

## 1. 개요

iOS 26 시스템 UI (TabBar, NavigationBar)의 Liquid Glass 효과를 재현하기 위한 구현 자료.

### 1.1. 핵심 발견사항

| 항목 | 내용 |
|------|------|
| 핵심 필터 | `vibrantColorMatrix`, `gaussianBlur`, `colorMatrix` |
| 신규 필터 | `glassBackground` (iOS 26 신규) |
| 컴포지팅 | `destOut`, `normalBlendMode` |
| 렌즈 효과 | `_UILiquidLensView` + `displacementMap` |

---

## 2. CAFilter 구현

### 2.1. 필터 타입 목록

| 필터 | 용도 | 파라미터 |
|------|------|----------|
| `vibrantColorMatrix` | 아이콘/텍스트 색상 조정 | `inputColorMatrix` (5x4 Float) |
| `gaussianBlur` | 블러 효과 | `inputRadius`, `inputNormalizeEdges` |
| `colorMatrix` | 배경 색상 보정 | `inputColorMatrix` (5x4 Float) |
| `opacityPair` | 투명도 쌍 | 없음 |
| `displacementMap` | 렌즈 왜곡 효과 | `inputAmount` |
| `glassBackground` | 유리 배경 (신규) | 없음 |

### 2.2. CAFilter 생성 코드

```swift
// CAFilter 생성 (Private API)
func createFilter(name: String) -> NSObject? {
    guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
    let filter = filterClass.perform(NSSelectorFromString("filterWithName:"), with: name)?.takeUnretainedValue() as? NSObject
    return filter
}

// 필터 적용
func applyFilter(_ filter: NSObject, to layer: CALayer) {
    layer.setValue([filter], forKey: "filters")
}
```

---

## 3. Color Matrix 값

### 3.1. 5x4 행렬 구조

```
[ R_r, R_g, R_b, R_a, R_bias ]
[ G_r, G_g, G_b, G_a, G_bias ]
[ B_r, B_g, B_b, B_a, B_bias ]
[ A_r, A_g, A_b, A_a, A_bias ]
```

**계산**: `output = input * matrix + bias`

### 3.2. TabBar 색상 매트릭스

#### 선택된 탭 아이콘 (파란색 틴트)
```swift
let selectedIconMatrix: [Float] = [
    0.500, 0.000, 0.000, 0.000, 0.000,  // R
    0.000, 0.500, 0.000, 0.000, 0.569,  // G
    0.000, 0.000, 0.500, 0.000, 1.000,  // B
    0.000, 0.000, 0.000, 1.000, 0.000   // A
]
// 효과: 채도 50% + 파란색 틴트 (G+0.569, B+1.0)
```

#### 비선택 탭 아이콘 (회색 톤)
```swift
let unselectedIconMatrix: [Float] = [
    0.798, -0.680, -0.069, 0.000, 0.950,  // R
   -0.202,  0.321, -0.069, 0.000, 0.950,  // G
   -0.202, -0.679,  0.931, 0.000, 0.950,  // B
    0.000,  0.000,  0.000, 1.000, 0.000   // A
]
// 효과: 탈색 + 밝은 회색 (bias 0.95)
```

#### 배경 색상 보정
```swift
let backgroundColorMatrix: [Float] = [
    1.082, -0.113, -0.011, 0.000, 0.135,  // R
   -0.034,  1.003, -0.011, 0.000, 0.135,  // G
   -0.034, -0.113,  1.105, 0.000, 0.135,  // B
    0.000,  0.000,  0.000, 1.000, 0.000   // A
]
// 효과: 약간의 채도 증가 + 밝기 증가
```

### 3.3. NavigationBar 색상 매트릭스

#### 타이틀 텍스트 (흰색)
```swift
let whiteTitleMatrix: [Float] = [
    0.000, 0.000, 0.000, 0.000, 1.000,  // R
    0.000, 0.000, 0.000, 0.000, 1.000,  // G
    0.000, 0.000, 0.000, 0.000, 1.000,  // B
    0.000, 0.000, 0.000, 0.000, 1.000   // A
]
// 효과: 입력 무시, 항상 흰색 출력
```

#### 강조 색상 (Platter 내부)
```swift
let accentColorMatrix: [Float] = [
    2.649, -1.180, -0.119, 0.000, 0.150,  // R
   -0.351,  1.820, -0.119, 0.000, 0.150,  // G
   -0.351, -1.180,  2.881, 0.000, 0.150,  // B
    0.000,  0.000,  0.000, 1.000, 0.000   // A
]
// 효과: 고채도 + 컬러 부스트
```

---

## 4. Gaussian Blur 설정

### 4.1. 기본 파라미터

```swift
let blurFilter = createFilter(name: "gaussianBlur")
blurFilter?.setValue(2, forKey: "inputRadius")        // 반경: 2pt
blurFilter?.setValue(1, forKey: "inputNormalizeEdges") // 가장자리 정규화
blurFilter?.setValue("default", forKey: "inputQuality")
```

### 4.2. 용도별 Blur 설정

| 용도 | inputRadius | 비고 |
|------|-------------|------|
| TabBar 배경 | 2 | 약한 블러 |
| NavBar 버튼 | 0 | 블러 없음 (준비용) |
| Glass 효과 | 미지정 | 동적 조절 |

---

## 5. 컴포지팅 필터

### 5.1. destOut (마스킹)

TabBar의 `DestOutView`에 사용. 선택된 탭 영역을 "구멍 뚫기" 효과.

```swift
layer.setValue("destOut", forKey: "compositingFilter")
```

### 5.2. normalBlendMode

NavigationBar의 Platter 내부 레이어에 사용.

```swift
layer.setValue("normalBlendMode", forKey: "compositingFilter")
```

---

## 6. 뷰 계층 구조

### 6.1. TabBar 구조

```
UITabBar (402×83)
└─ _UITabBarPlatterView (274×62, 중앙 정렬)
   ├─ [0] SelectedContentView - 선택된 탭 컨텐츠 (vibrantColorMatrix 적용)
   │   └─ _UITabButton × 3
   ├─ [1] _UILiquidLensView (94×54) - 선택 인디케이터 ⭐
   │   ├─ opacityPair 필터
   │   ├─ gaussianBlur + colorMatrix (배경 블러)
   │   └─ displacementMap (렌즈 왜곡)
   ├─ [2] ContentView - 비선택 탭 컨텐츠 (회색 vibrantColorMatrix)
   │   └─ _UITabButton × 3
   └─ [3] DestOutView - destOut 컴포지팅 (선택 영역 마스크)
```

### 6.2. NavigationBar 구조

```
UINavigationBar (402×54)
├─ _UIBarBackground (배경)
├─ NavigationBarContentView
│   └─ NavigationBarTransitionContainer
│       ├─ HostedViewContainer - 타이틀 영역
│       │   └─ HostedViewWrapper
│       │       └─ _UINavigationBarTitleControl
│       └─ NavigationBarPlatterContainer - 버튼 영역
│           ├─ PlatterView[0] - 왼쪽 버튼
│           │   └─ AnimationView > PlatterContentView > PlatterGlassView
│           │       └─ SubviewContainerView > PlatterItemView
│           └─ PlatterView[1] - 오른쪽 버튼
└─ _UIPointerInteractionAssistantEffectContainerView
```

---

## 7. 크기 및 레이아웃

### 7.1. TabBar

| 요소 | 크기 | 위치 |
|------|------|------|
| UITabBar | 402×83 | y=791 (화면 하단) |
| _UITabBarPlatterView | 274×62 | x=64 (중앙) |
| _UILiquidLensView | 94×54 | x=4, y=4 (첫 번째 탭 위) |
| _UITabButton | 94×54 | 각 탭 영역 |

### 7.2. NavigationBar

| 요소 | 크기 | 위치 |
|------|------|------|
| UINavigationBar | 402×54 | y=62 (상태바 아래) |
| _UIBarBackground | 402×116 | y=-62 (확장 영역 포함) |
| NavigationBarContentView | 402×54 | 전체 영역 |

---

## 8. 구현 우선순위

### Phase 1: 기본 필터 적용
1. `vibrantColorMatrix` 생성 및 적용
2. `gaussianBlur` 생성 및 적용
3. 선택/비선택 탭 색상 구분

### Phase 2: 컴포지팅
1. `destOut` 마스킹 구현
2. `normalBlendMode` 적용

### Phase 3: Liquid Lens 효과
1. `_UILiquidLensView` 분석
2. `displacementMap` 렌즈 왜곡
3. 선택 애니메이션

### Phase 4: Glass Background (NavigationBar)
1. `glassBackground` 필터 분석
2. Platter 효과 구현

---

## 9. 코드 예시

### 9.1. vibrantColorMatrix 적용

```swift
import QuartzCore

extension CALayer {
    func applyVibrantColorMatrix(_ matrix: [Float]) {
        guard matrix.count == 20 else { return }

        // CAFilter 생성
        guard let filterClass = NSClassFromString("CAFilter") as? NSObject.Type,
              let filter = filterClass.perform(
                  NSSelectorFromString("filterWithName:"),
                  with: "vibrantColorMatrix"
              )?.takeUnretainedValue() as? NSObject else { return }

        // 5x4 행렬을 NSValue로 변환
        var floats = matrix
        let data = Data(bytes: &floats, count: 80)
        let nsValue = data.withUnsafeBytes { ptr in
            NSValue(bytes: ptr.baseAddress!, objCType: "{CAColorMatrix=fffff}")
        }

        filter.setValue(nsValue, forKey: "inputColorMatrix")
        filter.setValue(true, forKey: "enabled")

        self.filters = [filter]
    }
}
```

### 9.2. 선택된 탭 스타일 적용

```swift
func applySelectedTabStyle(to layer: CALayer) {
    layer.applyVibrantColorMatrix([
        0.500, 0.000, 0.000, 0.000, 0.000,
        0.000, 0.500, 0.000, 0.000, 0.569,
        0.000, 0.000, 0.500, 0.000, 1.000,
        0.000, 0.000, 0.000, 1.000, 0.000
    ])
}

func applyUnselectedTabStyle(to layer: CALayer) {
    layer.applyVibrantColorMatrix([
        0.798, -0.680, -0.069, 0.000, 0.950,
       -0.202,  0.321, -0.069, 0.000, 0.950,
       -0.202, -0.679,  0.931, 0.000, 0.950,
        0.000,  0.000,  0.000, 1.000, 0.000
    ])
}
```

---

## 10. 참고 사항

### 10.1. Private API 주의

- `CAFilter`는 Private API
- App Store 심사 시 리젝 가능성 있음
- 대안: `UIVisualEffectView` 또는 Metal Shader

### 10.2. 성능 고려

- 필터는 GPU 가속 사용
- 과도한 블러는 배터리 소모 증가
- 중첩 필터 최소화 권장

### 10.3. 다크/라이트 모드

- 현재 데이터는 다크 모드 기준
- 라이트 모드는 색상 매트릭스 값이 다를 수 있음
- 추가 덤프 필요

---

## 부록: 원본 데이터 파일

| 파일 | 내용 |
|------|------|
| `260126_232348_tabbar_filters.json` | TabBar 필터 전체 |
| `260126_232348_tabbar_structure.json` | TabBar 계층 구조 |
| `260126_232348_navbar_filters.json` | NavBar 필터 전체 |
| `260126_232348_navbar_structure.json` | NavBar 계층 구조 |

# iOS 26 Liquid Glass TabBar 구현 자료

**작성일**: 2026-01-26
**데이터 소스**: SystemUIInspector3 (iOS 26.0.1 시뮬레이터)

---

## 1. 전체 구조

```
UITabBar (402×83, y=791)
└─ _UITabBarPlatterView (274×62, x=64) ← 중앙 정렬, clipsToBounds=true
   ├─ [0] SelectedContentView (274×62) ← 선택된 탭 아이콘/라벨 (파란 틴트)
   │   ├─ _UITabButton (94×54, x=4)
   │   │   ├─ _UIMultiLayer ← 아이콘 (vibrantColorMatrix 필터)
   │   │   └─ _UIMultiLayer ← 라벨 (_UILabelLayer)
   │   ├─ _UITabButton (94×54, x=90)
   │   └─ _UITabButton (94×54, x=176)
   │
   ├─ [1] _UILiquidLensView (94×54, x=4, zPos=10) ← 선택 인디케이터 ⭐
   │   ├─ opacityPair 필터
   │   ├─ _UIMultiLayer
   │   │   ├─ UICABackdropLayer (cornerRadius=27, zPos=-2) ← 블러+색보정
   │   │   │   ├─ gaussianBlur (radius=2)
   │   │   │   └─ colorMatrix (배경 색보정)
   │   │   └─ CALayer (cornerRadius=27)
   │   └─ ClearGlassView
   │       ├─ liftedContentWarpWrapper (displacementMap)
   │       │   ├─ CASDFLayer (warpSDF)
   │       │   │   └─ CASDFElementLayer
   │       │   └─ CAPortalLayer
   │       └─ innerShadowView
   │
   ├─ [2] ContentView (274×62) ← 비선택 탭 아이콘/라벨 (회색)
   │   ├─ _UITabButton (94×54, x=4)
   │   ├─ _UITabButton (94×54, x=90)
   │   └─ _UITabButton (94×54, x=176)
   │
   └─ [3] DestOutView (94×54, x=0) ← 마스킹용
       ├─ compFilter: destOut
       ├─ bgColor: 검정 (rgba 0,0,0,1)
       └─ CAMatchMoveAnimation (위치 동기화)
```

---

## 2. 크기 및 레이아웃

### 2.1. 프레임 정보

| 요소 | 크기 | 위치 | 비고 |
|------|------|------|------|
| UITabBar | 402×83 | x=0, y=791 | 화면 하단 |
| _UITabBarPlatterView | 274×62 | x=64, y=0 | 중앙 정렬 (64 = (402-274)/2) |
| _UITabButton | 94×54 | y=4 | 3개 버튼, 간격 없음 |
| _UILiquidLensView | 94×54 | x=4, y=4 | 선택된 탭 위치 |
| UICABackdropLayer | 94×54 | x=0, y=0 | cornerRadius=27 |

### 2.2. 버튼 위치 (3탭 기준)

| 탭 인덱스 | x 좌표 | 계산 |
|-----------|--------|------|
| 0 | 4 | padding |
| 1 | 90 | 4 + 94 - 8 (겹침) |
| 2 | 176 | 90 + 94 - 8 |

### 2.3. PlatterView 중앙 정렬 공식

```swift
let platterWidth: CGFloat = 274  // 탭 3개 기준
let tabBarWidth: CGFloat = 402   // iPhone 17 기준
let platterX = (tabBarWidth - platterWidth) / 2  // = 64
```

---

## 3. 레이어 타입

### 3.1. 사용된 레이어 클래스

| 클래스 | 용도 | 생성 방법 |
|--------|------|-----------|
| `CALayer` | 기본 컨테이너 | `CALayer()` |
| `_UIMultiLayer` | 아이콘/라벨 래퍼 | Private |
| `UICABackdropLayer` | 백드롭 블러 | Private (`CABackdropLayer` 서브클래스) |
| `CASDFLayer` | SDF 렌더링 | Private |
| `CASDFElementLayer` | SDF 요소 | Private |
| `CAPortalLayer` | 레이어 참조 | Private |
| `_UILabelLayer` | 텍스트 | `UILabel.layer` |

### 3.2. Private 속성

모든 레이어에 적용:
```swift
layer.setValue(true, forKey: "continuousCorners")
layer.cornerCurve = .continuous
```

아이콘/라벨 레이어 (`_UIMultiLayer`):
```swift
layer.setValue(false, forKey: "allowsGroupBlending")  // 0
```

기타 레이어:
```swift
layer.setValue(true, forKey: "allowsGroupBlending")   // 1
```

---

## 4. 필터 (CAFilter)

### 4.1. 필터 목록

| 필터 | 적용 위치 | 파라미터 |
|------|-----------|----------|
| vibrantColorMatrix | 아이콘/라벨 레이어 | inputColorMatrix |
| gaussianBlur | UICABackdropLayer | inputRadius=2, inputNormalizeEdges=1 |
| colorMatrix | UICABackdropLayer | inputColorMatrix |
| opacityPair | _UILiquidLensView.layer | 없음 |
| displacementMap | ClearGlassView 내부 | inputAmount=0 |

### 4.2. CAFilter 생성 코드

```swift
func createCAFilter(name: String) -> NSObject? {
    guard let CAFilter = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
    return CAFilter.perform(NSSelectorFromString("filterWithName:"), with: name)?
        .takeUnretainedValue() as? NSObject
}

// 사용 예
let filter = createCAFilter(name: "vibrantColorMatrix")
filter?.setValue(colorMatrix, forKey: "inputColorMatrix")
filter?.setValue(true, forKey: "enabled")
layer.filters = [filter!]
```

---

## 5. Color Matrix 값

### 5.1. 행렬 구조 (5×4)

```
출력 = 입력 × 행렬 + bias

[ R_out ]   [ R_r  R_g  R_b  R_a ] [ R_in ]   [ R_bias ]
[ G_out ] = [ G_r  G_g  G_b  G_a ] [ G_in ] + [ G_bias ]
[ B_out ]   [ B_r  B_g  B_b  B_a ] [ B_in ]   [ B_bias ]
[ A_out ]   [ A_r  A_g  A_b  A_a ] [ A_in ]   [ A_bias ]
```

### 5.2. 선택된 탭 아이콘 (파란 틴트)

```swift
let selectedMatrix: [Float] = [
    // R      G      B      A      bias
    0.500, 0.000, 0.000, 0.000, 0.000,  // R: 채도 50%
    0.000, 0.500, 0.000, 0.000, 0.569,  // G: 채도 50% + 녹색 틴트
    0.000, 0.000, 0.500, 0.000, 1.000,  // B: 채도 50% + 파란색 최대
    0.000, 0.000, 0.000, 1.000, 0.000   // A: 유지
]
// 결과: 파란색 계열 틴트 (iOS 기본 tintColor)
```

### 5.3. 비선택 탭 아이콘 (회색)

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

### 5.4. 배경 색상 보정 (UICABackdropLayer)

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

### 5.5. NSValue 변환 코드

```swift
func createColorMatrixValue(_ matrix: [Float]) -> NSValue? {
    guard matrix.count == 20 else { return nil }
    var floats = matrix
    return floats.withUnsafeMutableBytes { ptr in
        NSValue(bytes: ptr.baseAddress!, objCType: "{CAColorMatrix=ffffffffffffffffffff}")
    }
}

// 적용
let matrixValue = createColorMatrixValue(selectedMatrix)
filter?.setValue(matrixValue, forKey: "inputColorMatrix")
```

---

## 6. 백드롭 레이어 (UICABackdropLayer)

### 6.1. 속성

| 속성 | 값 | 설명 |
|------|-----|------|
| cornerRadius | 27 | 둥근 모서리 (54/2) |
| cornerCurve | continuous | 부드러운 곡선 |
| zPosition | -2 | 아래 배치 |
| scale | 0.25 | 1/4 해상도로 캡처 |
| groupName | `<UITabSelectionView: 0x...>` | 캡처 대상 그룹 |
| captureOnly | false | 실제 렌더링 함 |

### 6.2. 필터 조합

```swift
// 1. gaussianBlur
let blur = createCAFilter(name: "gaussianBlur")
blur?.setValue(2, forKey: "inputRadius")
blur?.setValue(1, forKey: "inputNormalizeEdges")
blur?.setValue("default", forKey: "inputQuality")

// 2. colorMatrix
let color = createCAFilter(name: "colorMatrix")
color?.setValue(createColorMatrixValue(backgroundMatrix), forKey: "inputColorMatrix")

// 적용 (순서 중요!)
backdropLayer.filters = [blur!, color!]
```

---

## 7. 컴포지팅 (DestOutView)

### 7.1. 역할

선택된 탭 위치에 "구멍"을 뚫어서 _UILiquidLensView가 보이게 함.

### 7.2. 속성

```swift
// DestOutView.layer
layer.backgroundColor = UIColor.black.cgColor  // 마스크 색상
layer.setValue("destOut", forKey: "compositingFilter")
```

### 7.3. destOut 동작

`destOut` = Destination Out 합성 모드
- 소스(검정 레이어)가 있는 곳의 대상(배경)을 투명하게 만듦
- 결과: 선택된 탭 영역이 "뚫림"

---

## 8. 애니메이션

### 8.1. CAMatchMoveAnimation

DestOutView의 위치를 _UILiquidLensView와 동기화:

```swift
// key: "_UILiquidLensView.punchout.matchPosition"
// className: CAMatchMoveAnimation
// duration: 0 (즉시)
```

### 8.2. 탭 전환 애니메이션 구현

```swift
func animateTabSelection(to index: Int) {
    let newX = CGFloat(index) * 86 + 4  // 탭 위치 계산

    UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
        self.liquidLensView.frame.origin.x = newX
        self.destOutView.frame.origin.x = newX
    }
}
```

---

## 9. zPosition 구조

| 레이어 | zPosition | 설명 |
|--------|-----------|------|
| UICABackdropLayer | -2 | 최하단 (블러 배경) |
| ContentView | 0 (기본) | 비선택 탭 |
| SelectedContentView | 0 (기본) | 선택 탭 |
| _UILiquidLensView 관련 | 10 | 최상단 |
| DestOutView | 0 (기본) | 마스킹 |

---

## 10. 구현 체크리스트

### Phase 1: 기본 구조
- [ ] _UITabBarPlatterView 대체 뷰 생성
- [ ] 중앙 정렬 로직 구현
- [ ] clipsToBounds 적용

### Phase 2: 탭 버튼
- [ ] SelectedContentView (선택 탭)
- [ ] ContentView (비선택 탭)
- [ ] vibrantColorMatrix 필터 적용

### Phase 3: Liquid Lens
- [ ] 블러 백드롭 레이어 생성
- [ ] cornerRadius=27, cornerCurve=continuous
- [ ] gaussianBlur + colorMatrix 필터

### Phase 4: 마스킹
- [ ] DestOutView 생성
- [ ] destOut compositingFilter 적용
- [ ] 위치 동기화

### Phase 5: 애니메이션
- [ ] 탭 전환 시 LiquidLens 이동
- [ ] DestOutView 위치 동기화

---

## 부록: 원본 데이터

### A. 필터 파일
`260126_232348_tabbar_filters.json` (27KB, 66개 필터)

### B. 구조 파일
`260126_232348_tabbar_structure.json` (5KB)

### C. 전체 데이터
`260126_232348_tabbar_full_1.json` (210KB)

### D. 애니메이션
`260126_232348_tabbar_animations.json` (766B, 3개)

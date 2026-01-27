# iOS 26 Liquid Glass TabBar 구현 자료

**작성일**: 2026-01-27 (v2)
**데이터 소스**: SystemUIInspector3 (iOS 26.0.1 시뮬레이터)
**최신 덤프**: `260127_100514_tabbar_*.json`

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
   │   ├─ _UIMultiLayer (allowsGroupBlending=0)
   │   │   ├─ UICABackdropLayer (cornerRadius=27, zPos=-2) ← 블러+색보정
   │   │   │   ├─ gaussianBlur (radius=2, normalizeEdges=1)
   │   │   │   └─ colorMatrix (배경 색보정)
   │   │   └─ CALayer (cornerRadius=27)
   │   └─ ClearGlassView
   │       ├─ liftedContentWarpWrapper (displacementMap, inputAmount=0)
   │       │   ├─ CASDFLayer (name="warpSDF")
   │       │   │   └─ CASDFElementLayer
   │       │   └─ CAPortalLayer (masksToBounds=true)
   │       │       ├─ hidesSourceLayer=true
   │       │       ├─ matchesOpacity=true
   │       │       ├─ matchesPosition=true
   │       │       └─ matchesTransform=true
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

| 클래스 | 용도 | 생성 방법 | 확인됨 |
|--------|------|-----------|--------|
| `CALayer` | 기본 컨테이너 | `CALayer()` | ✅ |
| `_UIMultiLayer` | 아이콘/라벨 래퍼 | Private | ✅ |
| `UICABackdropLayer` | 백드롭 블러 | Private | ✅ |
| `CASDFLayer` | SDF 렌더링 | Private | ✅ |
| `CASDFElementLayer` | SDF 요소 | Private | ✅ |
| `CAPortalLayer` | 레이어 참조 | Private | ✅ |
| `_UILabelLayer` | 텍스트 | `UILabel.layer` | ✅ |

### 3.2. 공통 Private 속성

**모든 레이어에 적용:**
```swift
layer.setValue(true, forKey: "continuousCorners")  // ✅ 확인됨
layer.cornerCurve = .continuous                     // ✅ 확인됨
layer.contentsScale = 1.0  // ⚠️ 주의: 화면 스케일(3)이 아님!
```

**아이콘/라벨 레이어 (`_UIMultiLayer`):**
```swift
layer.setValue(false, forKey: "allowsGroupBlending")  // 0 ✅ 확인됨
```

**기타 레이어:**
```swift
layer.setValue(true, forKey: "allowsGroupBlending")   // 1 ✅ 확인됨
```

### 3.3. CAPortalLayer 속성 ✅ 발견됨

```swift
// CAPortalLayer - 다른 레이어를 미러링
layer.masksToBounds = true                          // ✅ 확인됨
layer.setValue(true, forKey: "hidesSourceLayer")    // ✅ 확인됨
layer.setValue(true, forKey: "matchesOpacity")      // ✅ 확인됨
layer.setValue(true, forKey: "matchesPosition")     // ✅ 확인됨
layer.setValue(true, forKey: "matchesTransform")    // ✅ 확인됨
// sourceLayer - 🔍 참조 대상 레이어 (아직 미확인)
```

### 3.4. UICABackdropLayer 속성 ✅ 발견됨

```swift
backdrop.scale = 0.25           // ✅ 1/4 해상도로 캡처
backdrop.zoom = 0               // ✅ 줌 없음
backdrop.captureOnly = false    // ✅
backdrop.groupName = "<UITabSelectionView: 0x...>"  // ✅
// blurRadius, saturation - 🔍 추가 조사 필요
```

### 3.5. CASDFLayer 속성 🔍 조사 중

```swift
// 발견된 속성
layer.name = "warpSDF"          // ✅ 확인됨
layer.contentsScale = 1         // ✅ 확인됨

// 미발견 (추가 조사 필요)
// shape, path, sdfData, cornerRadius, fillRule 등
```

---

## 4. 필터 (CAFilter)

### 4.1. 필터 목록

| 필터 | 적용 위치 | 파라미터 | 상태 |
|------|-----------|----------|------|
| vibrantColorMatrix | 아이콘/라벨 레이어 | inputColorMatrix | ✅ 완전 파악 |
| gaussianBlur | UICABackdropLayer | inputRadius=2, inputNormalizeEdges=1, inputQuality="default" | ✅ 완전 파악 |
| colorMatrix | UICABackdropLayer | inputColorMatrix | ✅ 완전 파악 |
| opacityPair | _UILiquidLensView.layer | 🔍 파라미터 없음 - 역할 불명 | 🔍 조사 중 |
| displacementMap | ClearGlassView 내부 | inputAmount=0 🔍 다른 파라미터? | 🔍 조사 중 |

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

### 4.3. 필터 파라미터 키 (시도한 키 목록)

```swift
// 확인된 파라미터
let confirmedKeys = [
    "inputRadius",           // gaussianBlur ✅
    "inputAmount",           // displacementMap ✅ (값=0)
    "inputNormalizeEdges",   // gaussianBlur ✅
    "inputQuality",          // gaussianBlur ✅
    "inputColorMatrix",      // colorMatrix, vibrantColorMatrix ✅
    "enabled"                // 모든 필터 ✅
]

// 시도했지만 응답 없음 (opacityPair, displacementMap용)
let triedKeys = [
    "inputOpacity", "inputOpacity0", "inputOpacity1",
    "inputImage", "inputScaleX", "inputScaleY", "inputCenter",
    "inputMaskImage", "inputDisplacementImage",
    "opacity", "opacity0", "opacity1", "inputOpacityPair"
]
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

### 5.2. 선택된 탭 아이콘 (파란 틴트) ✅

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

### 5.3. 비선택 탭 아이콘 (회색) ✅

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

### 5.4. 배경 색상 보정 (UICABackdropLayer) ✅

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

| 속성 | 값 | 설명 | 상태 |
|------|-----|------|------|
| cornerRadius | 27 | 둥근 모서리 (54/2) | ✅ |
| cornerCurve | continuous | 부드러운 곡선 | ✅ |
| zPosition | -2 | 아래 배치 | ✅ |
| contentsScale | 1 | 화면 스케일 아님 | ✅ |
| scale | 0.25 | 1/4 해상도로 캡처 | ✅ |
| zoom | 0 | 줌 없음 | ✅ |
| groupName | `<UITabSelectionView: 0x...>` | 캡처 대상 그룹 | ✅ |
| captureOnly | false | 실제 렌더링 함 | ✅ |
| blurRadius | - | 🔍 조사 필요 | 🔍 |
| saturation | - | 🔍 조사 필요 | 🔍 |

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

### 7.2. 속성 ✅

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

### 8.1. CAMatchMoveAnimation ✅

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

## 10. 미해결 항목 🔍

**상세 내용은 [260126Liquid-tabbar-gaps.md](./260126Liquid-tabbar-gaps.md) 참조**

| 항목 | 상태 | 요약 |
|------|------|------|
| opacityPair 필터 | 🔍 | 파라미터 없음, 역할 불명 |
| displacementMap 필터 | 🔍 | inputAmount=0 외 파라미터 불명 |
| CASDFLayer | 🔍 | SDF 데이터 정의 방법 불명 |
| CAPortalLayer.sourceLayer | 🔍 | 참조 대상 레이어 미확인 |
| innerShadowView | 🔍 | 그림자 설정 방법 불명 |

---

## 11. 구현 체크리스트

### Phase 1: 기본 구조
- [ ] _UITabBarPlatterView 대체 뷰 생성
- [ ] 중앙 정렬 로직 구현
- [ ] clipsToBounds 적용

### Phase 2: 탭 버튼
- [ ] SelectedContentView (선택 탭)
- [ ] ContentView (비선택 탭)
- [ ] vibrantColorMatrix 필터 적용

### Phase 3: Liquid Lens
- [ ] 블러 백드롭 레이어 생성 (UIVisualEffectView 대체?)
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
`260127_100514_tabbar_filters.json` (27KB)

### B. 구조 파일
`260127_100514_tabbar_structure.json` (5KB)

### C. 전체 데이터
`260127_100514_tabbar_full_1.json` (225KB)

### D. 애니메이션
`260127_100514_tabbar_animations.json` (766B)

---

## 변경 이력

| 날짜 | 변경 내용 |
|------|-----------|
| 2026-01-26 | 초안 작성 |
| 2026-01-27 | CAPortalLayer 속성 발견 (hidesSourceLayer, matches*) |
| 2026-01-27 | UICABackdropLayer.zoom=0, contentsScale=1 발견 |
| 2026-01-27 | 미해결 항목 섹션 추가 |

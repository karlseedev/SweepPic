# iOS 26 Liquid Glass 공통 구조

iOS 26.0.1 기준 Photos 앱에서 추출한 Liquid Glass UI 구조 분석.

---

## 핵심 View 계층 구조

```
_UILiquidLensView
├── UIView (contentWrapper)
│   ├── _UIMultiLayer
│   │   ├── UICABackdropLayer (배경 블러 캡처)
│   │   └── CALayer
│   ├── _UITabSelectionView (Selection Pill - 배경)
│   └── ClearGlassView (유리 효과)
│       ├── UIView (filters: [displacementMap])
│       │   ├── SDFView → CASDFLayer → CASDFElementLayer
│       │   └── _UIPortalView → CAPortalLayer
│       └── UIView (내부 콘텐츠)
└── DestOutView (마스킹)
```

---

## 핵심 Private 클래스

### 1. _UILiquidLensView
- **역할**: Liquid Glass 효과의 루트 뷰
- **filters**: `[opacityPair]`
- **주요 속성**:
  - `warpsContentBelow`: Bool = true
  - `liftedContentView`: UIView
  - `liftedContentMode`: Int64 = 1
  - `hasCustomRestingBackground`: Bool = true
  - `restingBackground`: UIView (_UITabSelectionView)
  - `glass`: ClearGlassView
  - `liftedContentPunchout`: DestOutView

### 2. ClearGlassView
- **역할**: 투명 유리 효과 렌더링
- **주요 속성**:
  - `style`: Int = 0
  - `contentView`
  - `liftedContentPortalView`
  - `innerShadowView`
  - `animatesBackground`

### 3. _UITabSelectionView
- **역할**: 탭 선택 시 배경 pill
- **레이어 속성**:
  - `cornerRadius`: **27.0** (높이 54pt의 절반)
  - `cornerCurve`: **continuous**
  - `masksToBounds`: false

### 4. DestOutView
- **역할**: 콘텐츠 마스킹 (펀칭)
- **배경색**: `gray(0.00, alpha: 1.00)` (완전 검정)
- **compositingFilter**: **destOut**

---

## 핵심 CALayer 타입

### UICABackdropLayer
- **역할**: 배경 캡처 및 블러
- **주요 속성**:
  - `scale`: **0.25** (1/4 해상도로 캡처)
  - `usesGlobalGroupNamespace`: 0
  - `captureOnly`: 0
  - `allowsInPlaceFiltering`: 0
  - `reducesCaptureBitDepth`: 0
  - `ignoresScreenClip`: 0
  - `groupName`: 연결된 뷰 참조
  - `zoom`: 0

### CASDFLayer / CASDFElementLayer
- **역할**: SDF(Signed Distance Field) 기반 형태 정의
- 유리 가장자리와 rim light 효과에 사용

### CAPortalLayer
- **역할**: 다른 레이어 콘텐츠를 포털로 표시
- `_UIPortalView`와 연결
- **속성**:
  - `_hidesSourceLayerInOtherPortals`: false
  - `__prefersClientLayer`: false

---

## CAFilter 타입

### 1. vibrantColorMatrix
- **용도**: 아이콘/레이블에 동적 색상 적용
- **적용 위치**: _UIMultiLayer (아이콘, 레이블 레이어)
- **속성**:
  - `type`: "vibrantColorMatrix"
  - `name`: "vibrantColorMatrix"
  - `enabled`: true
  - `cachesInputImage`: false
  - `inputColorMatrix`: CAColorMatrix()

### 2. displacementMap
- **용도**: 굴절 효과 (유리 왜곡)
- **적용 위치**: ClearGlassView 내부 UIView
- **효과**: 유리를 통해 보이는 배경이 미세하게 왜곡

### 3. opacityPair
- **용도**: _UILiquidLensView의 투명도 페어링
- **적용 위치**: _UILiquidLensView 루트

### 4. gaussianBlur
- **용도**: 배경 블러
- **적용 위치**: UIVisualEffectView 내 _UIVisualEffectBackdropView
- **참고**: UIBlurEffectStyleDark와 함께 사용

### 5. colorSaturate
- **용도**: 색상 채도 조정
- **적용 위치**: _UIVisualEffectBackdropView (gaussianBlur와 함께)

---

## UIVisualEffectView 구조 (inspection_2 기준)

### 기본 속성
- **effect**: `UIBlurEffect(style: .dark)`
- **cornerRadius**: **12.0**
- **cornerCurve**: **continuous**
- **masksToBounds**: true

### 내부 구조
```
UIVisualEffectView
├── _UIVisualEffectBackdropView (layer: UICABackdropLayer)
│   filters: [gaussianBlur, colorSaturate]
├── _UIVisualEffectSubview
│   backgroundColor: gray(0.11, alpha: 0.73)
│   compositingFilter: sourceOver
└── _UIVisualEffectContentView
    (실제 콘텐츠 배치)
```

### _UIVisualEffectSubview 배경색
- **gray**: 0.11 (약 11% 밝기)
- **alpha**: 0.73 (73% 불투명)
- 이 값이 Liquid Glass의 어두운 오버레이 색상

---

## PlatterView 구조 (NavigationBar 버튼)

### 버튼 공통 구조
```
PlatterView
└── AnimationView (터치 애니메이션)
    └── AnimationView
        └── AnimationView (scale 변형)
            └── AnimationView
                └── ... (콘텐츠)
```

### AnimationView 스케일 변형 패턴
일반 상태와 pressed 상태의 스케일 변화:
- 외곽: `frame=(-2.1, -2.1, 48.2, 48.2)` → bounds 44×44 (확장)
- 내부: `frame=(1.9, 1.9, 40.2, 40.2)` → bounds 44×44 (축소)
- 이 중첩된 AnimationView가 spring 애니메이션으로 press/release 효과 구현

### PlatterView 런타임 속성
- `scaleOffset`
- `transformViewA`, `transformViewB`
- `contentView`
- `scalePulseScheduler`
- `mode`

---

## 핵심 색상 값

| 용도 | 색상 | 설명 |
|------|------|------|
| DestOut 배경 | `gray(0.00, alpha: 1.00)` | 완전 검정 (마스킹용) |
| VisualEffect 배경 | `gray(0.11, alpha: 0.73)` | 어두운 반투명 오버레이 |

---

## 핵심 수치 정리

| 속성 | 값 | 용도 |
|------|-----|------|
| Selection Pill cornerRadius | 27pt | 높이(54pt)의 절반 |
| cornerCurve | continuous | iOS 13+ 부드러운 곡선 |
| UICABackdropLayer scale | 0.25 | 1/4 해상도 캡처 |
| VisualEffect cornerRadius | 12pt | 팝업/버튼 배경 |
| VisualEffect background alpha | 0.73 | 73% 불투명 |
| VisualEffect background gray | 0.11 | 11% 밝기 |

---

## 구현 시 핵심 포인트

1. **다층 구조**: 단순 블러가 아닌 여러 레이어의 조합
2. **SDF 기반 형태**: CASDFLayer로 부드러운 가장자리
3. **Portal 레이어**: 콘텐츠를 다른 위치에 렌더링
4. **DestOut 마스킹**: 선택된 탭의 콘텐츠가 유리 위에 "떠있는" 효과
5. **Spring 애니메이션**: AnimationView 중첩으로 자연스러운 press 반응
6. **continuous cornerCurve**: 기존 circular보다 부드러운 곡선

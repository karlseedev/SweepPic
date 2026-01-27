# iOS 26 Liquid Glass TabBar - 누락 항목 분석

**작성일**: 2026-01-27
**목적**: 100% 구현을 위해 추가 조사가 필요한 항목

---

## 1. Inspector가 수집하지 않는 CALayer 속성

### 1.1. 콘텐츠 관련
| 속성 | 용도 | 중요도 |
|------|------|--------|
| `contents` | 레이어 이미지 (CGImage) | ⚠️ 높음 |
| `contentsGravity` | 이미지 정렬/스케일 모드 | 중간 |
| `contentsScale` | 이미지 스케일 (@2x, @3x) | 중간 |
| `contentsRect` | 이미지 표시 영역 (0~1) | 낮음 |
| `contentsCenter` | 9-slice 영역 | 낮음 |

### 1.2. 렌더링 관련
| 속성 | 용도 | 중요도 |
|------|------|--------|
| `masksToBounds` | 자식 클리핑 여부 | ⚠️ 높음 |
| `shouldRasterize` | 레이어 캐싱 | 중간 |
| `rasterizationScale` | 캐싱 해상도 | 중간 |
| `drawsAsynchronously` | 비동기 그리기 | 낮음 |
| `allowsEdgeAntialiasing` | 가장자리 AA | 낮음 |

### 1.3. 필터 관련
| 속성 | 용도 | 중요도 |
|------|------|--------|
| `minificationFilter` | 축소 필터 (linear/nearest/trilinear) | 중간 |
| `magnificationFilter` | 확대 필터 | 중간 |

---

## 2. Private 레이어 클래스 정보 부족

### 2.1. CAPortalLayer ✅ 해결됨
**상태**: Inspector 보강으로 속성 수집 완료

```json
// 수집된 데이터
"portal" : {
  "hidesSourceLayer" : true,
  "matchesOpacity" : true,
  "matchesPosition" : true,
  "matchesTransform" : true
}
"masksToBounds" : true
```

**남은 문제**: `sourceLayer`가 어떤 레이어를 참조하는지 (클래스명만 수집, 실제 참조 대상 불명)

### 2.2. CASDFLayer / CASDFElementLayer ⚠️ 높음
**문제**: SDF 모양 정의 방법 불명

```swift
// 필요한 정보
- SDF 데이터 (Signed Distance Field)
- 모양 정의 (둥근 사각형?)
- 해상도/품질 설정
```

**해결 방법**: KVC로 SDF 관련 속성 탐색 필요

### 2.3. UICABackdropLayer 추가 속성 ✅ 부분 해결
**현재 수집**: scale, groupName, captureOnly, zoom, blurRadius, saturation

**수집된 데이터**:
```json
"backdrop" : {
  "captureOnly" : false,
  "groupName" : "<UITabSelectionView: 0x...>",
  "scale" : 0.25,
  "zoom" : 0
}
```

**여전히 누락 가능**:
```swift
allowsInPlaceFiltering
disablesOccludedBackdropBlur
bleedAmount
statisticsType
```

---

## 3. 필터 파라미터 부족

### 3.1. opacityPair 필터
**문제**: 파라미터가 없음. 역할 불명.

**추측**:
- 두 개의 투명도 값을 쌍으로 관리?
- 선택/비선택 상태 전환용?

**해결 방법**: 더 많은 필터 파라미터 키 시도

### 3.2. displacementMap 필터
**현재**: `inputAmount: 0`

**문제**: amount가 0이면 왜곡 효과가 없음. 실제 렌즈 효과는 어디서?

**누락 가능성**:
```swift
inputImage       // 변위 맵 이미지
inputScaleX      // X 스케일
inputScaleY      // Y 스케일
inputCenter      // 중심점
```

### 3.3. gaussianBlur 필터 - inputQuality
**현재**: `"default"`

**가능한 값**:
- `low`
- `medium`
- `high`
- `default`

---

## 4. 뷰 계층 정보 부족

### 4.1. _UILiquidLensView Private 속성
**현재 수집**: warpsContentBelow, liftedContentMode, hasCustomRestingBackground

**누락 가능성**:
```swift
cornerRadius        // 뷰 레벨 corner
blurRadius          // 뷰 레벨 블러
saturation          // 채도
brightness          // 밝기
tintColor           // 틴트
elevation           // 높이감
```

### 4.2. innerShadowView 설정
**문제**: 이름만 있고 그림자 설정 없음

**필요한 정보**:
```swift
shadowColor
shadowRadius
shadowOpacity
shadowOffset
shadowPath       // 내부 그림자 경로
```

---

## 5. 애니메이션 정보 부족

### 5.1. CAMatchMoveAnimation
**현재**: key, className, duration

**누락**:
```swift
sourceLayer      // 어떤 레이어를 따라가는지
targetLayer      // 어떤 레이어에 적용되는지
positionOffset   // 위치 오프셋
```

### 5.2. 탭 전환 애니메이션
**문제**: 정적 덤프에서 애니메이션 동작 파악 불가

**필요한 정보**:
- 전환 시간
- 이징 커브
- 중간 상태 (선택/비선택 전환 중)

---

## 6. 레이아웃 동적 계산

### 6.1. PlatterView 크기 계산
**현재**: 274×62 (3탭)

**누락**:
- 2탭일 때 크기?
- 4탭일 때 크기?
- 5탭일 때 크기?
- 탭 간격 공식?

### 6.2. LiquidLens 위치 계산
**현재**: x=4 (첫 번째 탭)

**누락**:
- 두 번째 탭 선택 시 x값?
- 애니메이션 중 x값 변화?

---

## 7. 다음 단계: Inspector 보강

### 7.1. 추가 수집 항목
```swift
// CALayer 기본
layer.masksToBounds
layer.contents != nil  // 이미지 있음 표시
layer.contentsGravity
layer.contentsScale

// CAPortalLayer 전용
(layer as? NSObject)?.value(forKey: "sourceLayer")
(layer as? NSObject)?.value(forKey: "hidesSourceLayer")

// CASDFLayer 전용
(layer as? NSObject)?.value(forKey: "sdfData")
(layer as? NSObject)?.value(forKey: "shape")

// UICABackdropLayer 추가
(layer as? NSObject)?.value(forKey: "blurRadius")
(layer as? NSObject)?.value(forKey: "saturationAmount")
```

### 7.2. 추가 필터 파라미터
```swift
let additionalFilterKeys = [
    "inputImage",
    "inputScaleX", "inputScaleY",
    "inputCenter",
    "inputOpacity0", "inputOpacity1",  // opacityPair용?
]
```

### 7.3. 동적 테스트
- 탭 전환하면서 여러 번 덤프
- 선택 탭 변경 시 값 변화 비교

---

## 8. 구현 우회 방안 (Private API 없이)

### 8.1. CABackdropLayer → UIVisualEffectView
```swift
let blur = UIBlurEffect(style: .systemMaterial)
let vibrancy = UIVibrancyEffect(blurEffect: blur, style: .label)
```

### 8.2. CASDFLayer → UIBezierPath + CAShapeLayer
```swift
let path = UIBezierPath(roundedRect: bounds, cornerRadius: 27)
shapeLayer.path = path.cgPath
```

### 8.3. CAPortalLayer → 스냅샷 또는 직접 렌더링
```swift
// 스냅샷 방식
let renderer = UIGraphicsImageRenderer(bounds: sourceView.bounds)
let image = renderer.image { sourceView.layer.render(in: $0.cgContext) }
```

### 8.4. displacementMap → Metal Shader
```swift
// CIFilter 또는 Metal compute shader로 구현
```

---

## 요약: 100% 구현까지 남은 작업

| 항목 | 작업 | 예상 난이도 |
|------|------|-------------|
| CAPortalLayer 분석 | Inspector 보강 + 덤프 | 중간 |
| CASDFLayer 분석 | Inspector 보강 + 덤프 | 높음 |
| opacityPair 분석 | 필터 파라미터 탐색 | 중간 |
| displacementMap 분석 | 필터 파라미터 탐색 | 높음 |
| innerShadow 분석 | 그림자 속성 덤프 | 낮음 |
| 동적 값 확인 | 탭 전환 중 덤프 | 중간 |
| Public API 대체 | 우회 구현 | 높음 |

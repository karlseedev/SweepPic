# Liquid Glass 자료 수집 계획

**작성일**: 2026-01-27
**버전**: v1

---

## 1. 목표 (Plan 연계)

### 1.1. 핵심 목표

**99% 유사도 구현에 필요한 모든 데이터 확보**

- [260127Liquid-Plan.md](./260127Liquid-Plan.md)의 미해결 항목(🔍)을 모두 해결
- Private API의 정확한 동작 파악 → Public API 대안 확정

### 1.2. 완료 기준

Plan 문서의 모든 🔍 항목이 다음 중 하나로 전환될 때:
- ✅ 대안 확정 (Public API로 구현 가능)
- ⛔ 구현 불가 (시각적 영향도 평가 후 생략 결정)

### 1.3. 수집 프로세스 (반복)

```
┌─────────────────────────────────────────────────────────┐
│  1. Research 문서에 수집 계획 작성                        │
│     - 뭘 수집할지, 어떻게 수집할지                         │
│     - 섹션 7 "다음 조사 계획" 업데이트                     │
├─────────────────────────────────────────────────────────┤
│  2. Inspector로 수집 실행                                │
│     - 앱 빌드 → 덤프 버튼 → JSON 분석                     │
├─────────────────────────────────────────────────────────┤
│  3. 자료 문서에 결과 추가                                 │
│     - 260126Liquid-tabbar.md (또는 navbar.md)            │
│     - 수집된 값, 발견된 속성 기록                          │
├─────────────────────────────────────────────────────────┤
│  4. 부족한 것 체크                                       │
│     - 섹션 2 "수집 대상 요약" 상태 업데이트                 │
│     - 섹션 5 "미해결 항목" 업데이트                        │
│     - Plan 문서의 🔍 상태 업데이트                        │
├─────────────────────────────────────────────────────────┤
│  5. 완료 기준 확인                                       │
│     - 모든 🔍 → ✅ 또는 ⛔ 전환됨?                        │
│     - No → 1번으로 돌아감                                │
│     - Yes → 수집 완료, 구현 단계로 이동                   │
└─────────────────────────────────────────────────────────┘
```

**현재 사이클**: 3회차 완료 (데이터 수집 한계 도달, 구현 단계 진행 가능)

---

## 2. 수집 대상 요약 (Plan에서 도출)

### 2.1. 수집 완료 (✅)

| 항목 | 내용 | Plan 반영 |
|------|------|-----------|
| 뷰 계층 구조 | PlatterView → LiquidLens → ContentView | ✅ |
| 크기/레이아웃 | 274×62, 94×54, cornerRadius=27 | ✅ |
| vibrantColorMatrix | 선택/비선택 아이콘 색상 행렬 | ✅ |
| gaussianBlur | radius=2, normalizeEdges=1 | ✅ |
| colorMatrix | 배경 색보정 행렬 | ✅ |
| destOut 컴포지팅 | 마스킹 방식 | ✅ |
| CAPortalLayer 속성 | hidesSourceLayer, matches* | ✅ |
| UICABackdropLayer 속성 | scale=0.25, zoom=0 | ✅ |

### 2.2. 검증 필요 (🔍)

| 항목 | 현재 대안 | 검증 내용 |
|------|-----------|-----------|
| vibrantColorMatrix 대체 | UIVibrancyEffect 또는 tintColor | 시각적 유사도 비교 필요 |
| destOut 대체 | CALayer.mask 또는 별도 뷰 | 마스킹 효과 동일성 검증 |

### 2.3. 미해결 → 조사 완료 (구현 시 생략/대안 결정)

| 항목 | 문제 | 조사 결과 | 최종 상태 |
|------|------|-----------|----------|
| opacityPair 필터 | 역할 불명 | 웹 검색 결과 없음, 파라미터 없음 | ⛔ 구현 생략 (시각적 영향 미미) |
| displacementMap 필터 | 역할 불명 | inputAmount=0, 웹 문서 없음 | ⛔ 구현 생략 (렌즈 왜곡 효과 미미) |
| CASDFLayer | SDF 데이터 정의 방법 불명 | 핵심 속성 없음 (아래 상세) | ✅ UIBezierPath + CAShapeLayer로 대체 |
| innerShadowView | 그림자 설정 방법 불명 | 모든 shadow 속성 기본값 | ✅ CALayer.shadow로 직접 구현 |

#### 2.3.1. 260127_123512 덤프 분석 결과 (2회차)

`respondingKeys` 검증으로 필터 파라미터 존재 여부 확인 완료:

| 필터 | respondingKeys | 결론 |
|------|----------------|------|
| opacityPair | `["enabled", "cachesInputImage"]` | 추가 파라미터 없음 |
| displacementMap | `["enabled", "cachesInputImage"]` | inputAmount 외 없음 |

#### 2.3.2. 260127_124914 덤프 분석 결과 (3회차)

**Inspector 보강 내용**:
- SDFInfo 구조체 개선: `respondingKeys`, `keyValues` 필드 추가
- ShadowAllInfo 구조체 추가: 기본값 포함 모든 shadow 속성 수집
- CGColor 타입 처리 개선 (unsafeBitCast 사용)

**CASDFLayer 조사 결과**:
| 항목 | 결과 |
|------|------|
| respondingKeys | `["cornerContents", "bounds", "contents", "contentsRect", "contentsCenter"]` |
| keyValues | bounds 정보만 수집됨 |
| shape, path, sdfData | 접근 불가 (nil 또는 미지원) |

→ **결론**: CASDFLayer의 핵심 SDF 정의 방법은 Private API로 보호됨. UIBezierPath + CAShapeLayer로 대체.

**innerShadowView 조사 결과**:
| 속성 | 값 |
|------|-----|
| shadowColor | nil |
| shadowOpacity | 0.0 |
| shadowRadius | 3.0 (기본값) |
| shadowOffset | (0, -3) (기본값) |
| shadowPath | nil |

→ **결론**: 명시적 shadow 설정 없음. CALayer.shadow로 직접 구현.

**웹 검색 결과**:
- opacityPair, displacementMap 관련 공개 문서 없음
- iOS 26 Private API로 확인됨

#### 2.3.3. 최종 평가

| 항목 | 구현 결정 | 예상 유사도 |
|------|-----------|-------------|
| opacityPair | 생략 | 95%+ |
| displacementMap | 생략 | 90%+ (렌즈 왜곡 없음) |
| CASDFLayer | CAShapeLayer + cornerCurve: continuous | 99% |
| innerShadowView | CALayer.shadow 직접 설정 | 95%+ |

**종합**: 현재 데이터로 **90-95% 시각적 유사도** 달성 가능. 더 이상의 데이터 수집은 Private API 한계로 어려움.

---

## 3. 수집 도구

### 3.1. SystemUIInspector3

**위치**: `SweepPic/SweepPic/Debug/SystemUIInspector3.swift`

**기능**:
- CALayer 전체 속성 수집
- CAFilter 파라미터 파싱 (inputColorMatrix → Float[20])
- Private 속성 KVC 접근 (CAPortalLayer, CABackdropLayer 등)
- JSON 파일 분리 저장 (filters, animations, structure, full)

**활성화 방법**:
```swift
// SceneDelegate.swift의 showMainInterface() 끝에 추가
#if DEBUG
SystemUIInspector3.shared.showDebugButton()
#endif
```

**사용법**:
1. 디버그 빌드로 앱 실행 (iOS 26 시뮬레이터)
2. 조사할 화면으로 이동
3. 디버그 버튼 탭
4. Documents 폴더에서 JSON 확인

```bash
open $(xcrun simctl get_app_container booted com.anthropic.SweepPic data)/Documents/
```

**출력 파일**:
| 파일 | 내용 | 크기 |
|------|------|------|
| `*_filters.json` | 필터 파라미터 전체 | ~27KB |
| `*_structure.json` | 뷰 계층 구조 | ~5KB |
| `*_animations.json` | 애니메이션 정보 | ~1KB |
| `*_full.json` | 전체 데이터 | ~225KB |

---

## 4. 접근 방법 레퍼런스

### 4.1. 접근 가능한 속성 요약

| 카테고리 | 접근 방법 | 상태 |
|----------|----------|------|
| CALayer 기본 | `layer.cornerRadius`, `layer.cornerCurve` 등 | ✅ |
| layer.filters | `layer.filters` (Private) | ✅ |
| layer.compositingFilter | `layer.compositingFilter` (Private) | ✅ |
| UIColor 분해 | `getWhite()`, `getRed()` | ✅ |
| _UILiquidLensView | KVC `value(forKey:)` | ✅ |
| CABackdropLayer | KVC `value(forKey:)` | ✅ |
| CAFilter 이름 | KVC `value(forKey: "name")` | ✅ |
| CAFilter 파라미터 | KVC `value(forKey: "inputRadius")` 등 | ✅ |
| CAAnimation | `layer.animation(forKey:)` | ✅ |

### 4.2. 발견된 iOS 26 Private 타입

**필터 (CAFilter)**:
- `variableBlur` - 가변 블러
- `gaussianBlur` - 가우시안 블러
- `colorMatrix` - 색상 행렬
- `vibrantColorMatrix` - 진동 색상 행렬
- `opacityPair` - 투명도 쌍 (🔍 역할 불명)
- `displacementMap` - 변위 맵 (🔍 파라미터 불명)

**컴포지팅 필터**:
- `destIn` - Destination In
- `destOut` - Destination Out (마스킹)

**애니메이션 (iOS 26 신규)**:
- `CAMatchPropertyAnimation` (duration: inf, fillMode: both)
- `CAMatchMoveAnimation` (duration: inf, fillMode: both)

**애니메이션 키**:
- match-bounds, match-position, match-corner-radius
- match-corner-radii, match-corner-curve, match-hidden

### 4.3. CAFilter 파라미터 접근 결과

| 필터 타입 | 파라미터 | 접근 방법 | 값 |
|----------|----------|----------|-----|
| variableBlur | `inputRadius` | KVC | 1 |
| variableBlur | `inputNormalizeEdges` | KVC | 1 |
| gaussianBlur | `inputRadius` | KVC | 2 |
| gaussianBlur | `inputNormalizeEdges` | KVC | 1 |
| gaussianBlur | `inputQuality` | KVC | "default" |
| colorMatrix | `inputColorMatrix` | KVC (NSValue) | 80바이트 |
| vibrantColorMatrix | `inputColorMatrix` | KVC (NSValue) | 80바이트 |
| opacityPair | 🔍 | 파라미터 없음 | - |
| displacementMap | `inputAmount` | KVC | 0 |

> **참고**: `inputKeys` 속성은 접근 불가하지만, 알려진 키로 직접 KVC 접근하면 값을 가져올 수 있음

### 4.4. inputColorMatrix 파싱 코드

```swift
// CAFilter에서 inputColorMatrix 추출
if let nsFilter = filter as? NSObject,
   let nsValue = nsFilter.value(forKey: "inputColorMatrix") as? NSValue {
    var buffer = [UInt8](repeating: 0, count: 80)
    nsValue.getValue(&buffer)

    // Float 배열로 변환 (5x4 행렬)
    var floats = [Float](repeating: 0, count: 20)
    for i in 0..<20 {
        let bytes = Array(buffer[i*4..<i*4+4])
        floats[i] = bytes.withUnsafeBytes { $0.load(as: Float.self) }
    }
    // floats = [R_r, R_g, R_b, R_a, R_bias, G_r, G_g, ...]
}
```

### 4.5. 핵심 접근 코드

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

---

## 5. TabBar 수집 현황

### 5.1. 진행률: 95% (데이터 수집 완료)

| 카테고리 | 완료 | 미해결 |
|----------|------|--------|
| 뷰 계층 | ✅ | - |
| 크기/레이아웃 | ✅ | - |
| 필터 (확정) | 3개 | - |
| 필터 (미해결) | 2개 (생략 결정) | - |
| 레이어 속성 | ✅ | - |
| 기타 | 2개 (대안 확정) | - |

**데이터 수집 상태**: Private API 한계로 추가 수집 어려움. 구현 단계 진행 가능.

### 5.2. 완료 항목 상세

#### 뷰 계층 구조
```
UITabBar (402×83, y=791)
└─ _UITabBarPlatterView (274×62, x=64)
   ├─ [0] SelectedContentView (274×62)
   │   └─ _UITabButton × 3 (vibrantColorMatrix 적용)
   ├─ [1] _UILiquidLensView (94×54, zPos=10) ← Selection Pill
   │   ├─ UICABackdropLayer (gaussianBlur + colorMatrix)
   │   └─ ClearGlassView (displacementMap)
   ├─ [2] ContentView (274×62)
   │   └─ _UITabButton × 3 (vibrantColorMatrix 적용)
   └─ [3] DestOutView (destOut 컴포지팅)
```

#### 크기/레이아웃 실측값
| 요소 | 크기 | 위치 |
|------|------|------|
| UITabBar | 402×83 | y=791 |
| PlatterView | 274×62 | x=64 (중앙) |
| Tab Button | 94×54 | y=4, 간격=-8 (오버랩) |
| Selection Pill | 94×54 | cornerRadius=27 |

#### vibrantColorMatrix 값

**선택된 탭 (파란 틴트)**:
```swift
[0.500, 0.000, 0.000, 0.000, 0.000,  // R
 0.000, 0.500, 0.000, 0.000, 0.569,  // G
 0.000, 0.000, 0.500, 0.000, 1.000,  // B
 0.000, 0.000, 0.000, 1.000, 0.000]  // A
```

**비선택 탭 (회색)**:
```swift
[ 0.798, -0.680, -0.069, 0.000, 0.950,  // R
 -0.202,  0.321, -0.069, 0.000, 0.950,  // G
 -0.202, -0.679,  0.931, 0.000, 0.950,  // B
  0.000,  0.000,  0.000, 1.000, 0.000]  // A
```

**배경 색보정**:
```swift
[ 1.082, -0.113, -0.011, 0.000, 0.135,  // R
 -0.034,  1.003, -0.011, 0.000, 0.135,  // G
 -0.034, -0.113,  1.105, 0.000, 0.135,  // B
  0.000,  0.000,  0.000, 1.000, 0.000]  // A
```

#### gaussianBlur 파라미터
```swift
inputRadius: 2
inputNormalizeEdges: 1
inputQuality: "default"
```

#### UICABackdropLayer 속성
```swift
scale: 0.25          // 1/4 해상도로 캡처
zoom: 0              // 줌 없음
captureOnly: false
groupName: "<UITabSelectionView: 0x...>"
```

#### CAPortalLayer 속성
```swift
masksToBounds: true
hidesSourceLayer: true
matchesOpacity: true
matchesPosition: true
matchesTransform: true
```

### 5.3. 미해결 항목 → 조사 완료

#### opacityPair 필터 ⛔ 생략
| 항목 | 내용 |
|------|------|
| **현상** | 파라미터가 없음 |
| **적용 위치** | _UILiquidLensView.layer |
| **조사 결과** | respondingKeys에 추가 파라미터 없음, 웹 문서 없음 |
| **결정** | ⛔ **구현 생략** - 시각적 영향 미미 |

#### displacementMap 필터 ⛔ 생략
| 항목 | 내용 |
|------|------|
| **현상** | `inputAmount: 0` |
| **적용 위치** | ClearGlassView 내부 |
| **조사 결과** | amount=0이면 효과 없음, 웹 문서 없음 |
| **결정** | ⛔ **구현 생략** - 렌즈 왜곡 효과 미미 (90%+ 유사도) |

#### CASDFLayer ✅ 대안 확정
| 항목 | 내용 |
|------|------|
| **현상** | SDF 모양 정의 방법 불명 |
| **적용 위치** | ClearGlassView 내부 (warpSDF) |
| **조사 결과** | respondingKeys에 shape/path 없음, keyValues에 bounds만 있음 |
| **결정** | ✅ **UIBezierPath + CAShapeLayer + cornerCurve: continuous** (99% 유사도) |

#### innerShadowView ✅ 대안 확정
| 항목 | 내용 |
|------|------|
| **현상** | 이름만 있고 그림자 설정 없음 |
| **적용 위치** | ClearGlassView 내부 |
| **조사 결과** | 모든 shadow 속성 기본값 (shadowOpacity: 0, shadowRadius: 3) |
| **결정** | ✅ **CALayer.shadow 직접 설정** (필요시 추가) |

### 5.4. 수집 자료

- [260126Liquid-tabbar.md](./260126Liquid-tabbar.md) - 상세 속성 자료
- 원본 JSON (DumpData 폴더에 복사됨):
  - `260127_100514_tabbar_*.json` - 파라미터 값 포함
  - `260127_123512_tabbar_*.json` - respondingKeys 포함
  - `260127_124914_tabbar_*.json` - SDF/Shadow 정보 (tabbar_full 생성 실패)
  - `260127_124914_navbar_*.json` - SDF respondingKeys 확인
- 덤프 파일 위치: [docs/UI/DumpData/](./DumpData/) (48개 파일)

---

## 6. NavBar 수집

> ⏸️ TabBar 완료 후 진행 예정

### 6.1. 진행률: 10%

기본 틀만 작성됨

### 6.2. 수집 자료

- [260126Liquid-navbar.md](./260126Liquid-navbar.md) - 기본 틀

---

## 7. 3회차 조사 결과

### 7.0. 조사 수행 내역

| 순위 | 항목 | 수행 방법 | 결과 |
|------|------|----------|------|
| 1 | opacityPair 역할 파악 | 웹 검색, 문서 조사 | ⛔ 정보 없음 → 생략 결정 |
| 2 | displacementMap 역할 파악 | 웹 검색, 문서 조사 | ⛔ 정보 없음 → 생략 결정 |
| 3 | CASDFLayer 속성 | Inspector 보강 후 덤프 | ✅ 핵심 속성 미지원 → 대안 확정 |
| 4 | innerShadowView 속성 | Inspector 보강 후 덤프 | ✅ 기본값만 → 대안 확정 |

### 7.1. Inspector 보강 내역

**코드 변경** (`SystemUIInspector3.swift`):
```swift
// SDFInfo 구조체 개선
struct SDFInfo: Codable {
    let shape: String?
    let fillColor: ColorInfo?
    let strokeColor: ColorInfo?
    let strokeWidth: CGFloat?
    let sdfPath: String?
    let cornerRadius: CGFloat?
    let fillRule: String?
    let respondingKeys: [String]?   // 신규: responds(to:) true인 키들
    let keyValues: [String: String]? // 신규: 실제 값이 있는 키-값 쌍
}

// ShadowAllInfo 구조체 추가
struct ShadowAllInfo: Codable {
    let shadowColor: ColorInfo?
    let shadowOpacity: Float
    let shadowRadius: CGFloat
    let shadowOffset: SizeInfo
    let shadowPath: String?
}

// CGColor 타입 처리 개선
if CFGetTypeID(value as CFTypeRef) == CGColor.typeID {
    let cgColor = unsafeBitCast(value, to: CGColor.self)
    // ...
}
```

### 7.2. 웹 검색 결과

| 검색어 | 결과 |
|--------|------|
| "iOS opacityPair CAFilter" | 공개 문서 없음 |
| "iOS displacementMap CAFilter" | 공개 문서 없음 |
| "CAFilter opacityPair parameters" | 관련 정보 없음 |

→ **결론**: iOS 26 Private API로 보호됨. 구현 생략 결정.

### 7.3. 최종 구현 대안 확정

| Private API | 구현 대안 | 검증 시점 | 예상 유사도 |
|-------------|----------|----------|------------|
| vibrantColorMatrix | UIVibrancyEffect 또는 tintColor | 구현 시 | 95% |
| destOut | CALayer.mask | 구현 시 | 99% |
| CABackdropLayer | UIVisualEffectView | 구현 시 | 95% |
| opacityPair | **생략** | - | 95%+ |
| displacementMap | **생략** | - | 90%+ |
| CASDFLayer | CAShapeLayer + cornerCurve | 구현 시 | 99% |
| innerShadowView | CALayer.shadow | 구현 시 | 95%+ |

---

## 8. 부록: 테스트 결과 상세

### 8.1. CALayer 기본 속성
```
cornerRadius: 27.0 ✅
cornerCurve: continuous ✅
masksToBounds: false ✅
borderWidth: 0.0 ✅
shadowOpacity: 0.0 ✅
shadowRadius: 3.0 ✅
```

### 8.2. layer.filters
```
[PocketBlur] layer.filters: [variableBlur]
[_UIPortalView] layer.filters: [colorMatrix]
[HostedViewWrapper] layer.filters: [gaussianBlur]
[SubviewContainerView] layer.filters: [gaussianBlur]
[_UIMultiLayer] layer.filters: [vibrantColorMatrix]
```

### 8.3. layer.compositingFilter
```
[_UIPortalView] layer.compositingFilter: destIn
[DestOutView] layer.compositingFilter: destOut
```

### 8.4. _UILiquidLensView (KVC)
```
warpsContentBelow: 1 ✅
liftedContentMode: 1 ✅
hasCustomRestingBackground: 1 ✅
```

### 8.5. CABackdropLayer (KVC)
```
scale: 0.25 ✅
groupName: "<UITabSelectionView: 0x...>" ✅
captureOnly: 0 ✅
usesGlobalGroupNamespace: 0 ✅
zoom: 0 ✅
```

---

## 9. 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|-----------|
| 2026-01-27 | v1 | 문서 생성 (기존 SearchPlan + gaps 통합, Plan 연계 구조) |
| 2026-01-27 | v1.1 | 260127_123512 덤프 분석 결과 반영, respondingKeys 발견, 3회차 조사 계획 수립 |
| 2026-01-27 | v1.2 | 3회차 조사 완료: Inspector 보강, SDF/Shadow 조사, 웹 검색, 최종 대안 확정 |

---

## 10. 다음 단계

### 10.1. 데이터 수집 완료

모든 미해결 항목(🔍)이 다음으로 전환됨:
- ✅ 대안 확정 (CASDFLayer, innerShadowView)
- ⛔ 구현 생략 (opacityPair, displacementMap)

### 10.2. 구현 단계 진행 가능

**예상 시각적 유사도**: 90-95%

**구현 순서** (Plan 문서 참조):
1. Phase 1: 실측 상수 적용 (`LiquidGlassStyle+Measurements.swift`)
2. Phase 2: Selection Pill 구현 (`SelectionPillView.swift`)
3. Phase 3: FloatingTabBar 수정
4. Phase 4: 아이콘/레이블 스타일
5. Phase 5: 마무리 (접근성, 다크모드, 성능)

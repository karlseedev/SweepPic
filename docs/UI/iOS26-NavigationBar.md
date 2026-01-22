# iOS 26 NavigationBar 버튼 스펙

iOS 26.0.1 기준 Photos 앱 NavigationBar 버튼 분석.

---

## NavigationBar 기본 정보

| 속성 | 값 |
|------|-----|
| frame | (0.0, 62.0, 402.0, 54.0) |
| **height** | **54pt** |
| 상단 safe area | 62pt |
| 전체 높이 (safe area 포함) | 116pt |

### 내부 구조
```
UINavigationBar
├── _UIBarBackground (투명, 효과 없음)
├── NavigationBarContentView
│   └── NavigationBarTransitionContainer
│       ├── HostedViewContainer (타이틀)
│       ├── UIView
│       └── NavigationBarPlatterContainer
│           └── PlatterView (버튼들)
└── _UIPointerInteractionAssistantEffectContainerView
```

---

## 버튼 타입별 크기

### NavigationBar 버튼: 44pt

### 1. Back 버튼 (아이콘 전용)
- **크기**: **44×44pt** (정사각형)
- **위치**: 좌측 (x: 16pt)
- **용도**: 앨범 상세, 뷰어 등 하위 화면에서 뒤로가기

```
PlatterView frame: (16.0, 0.0, 44.0, 44.0)
└── AnimationView (44×44)
    └── AnimationView (44×44)
        └── AnimationView (48.2×48.2, scale 확장)
            └── AnimationView (40.2×40.2, scale 축소)
```

### 2. Select 버튼 (텍스트)
- **크기**: **73.33×44pt**
- **위치**: 우측 끝 (x: 312.67pt)
- **용도**: 사진 선택 모드 진입

```
PlatterView frame: (312.67, 0.0, 73.33, 44.0)
└── AnimationView 중첩 구조
```

### 3. Cancel/취소 버튼 (텍스트)
- **크기**: **68.33×44pt**
- **위치**: Select 버튼 좌측 (x: 232.33pt)
- **용도**: 선택 모드 취소

```
PlatterView frame: (232.33, 0.0, 68.33, 44.0)
└── AnimationView 중첩 구조
```

---

## 버튼 크기 요약

| 버튼 타입 | 너비 | 높이 | 형태 |
|----------|------|------|------|
| Back (아이콘) | 44pt | 44pt | 정사각형 |
| Select (텍스트) | 73.33pt | 44pt | 캡슐 |
| Cancel (텍스트) | 68.33pt | 44pt | 캡슐 |

**공통점**: 높이는 모두 **44pt**

---

## 타이틀 정보

### 기본 타이틀 (메인 그리드)
- **frame**: (164.17, 11.83, 73.67, 20.33)
- **위치**: 중앙 정렬
- **높이**: 20.33pt

### 앨범 타이틀 (상세 화면)
- **frame**: (16.0, 11.83, 129.0, 20.33)
- **위치**: 좌측 정렬
- **높이**: 20.33pt

### 타이틀 래퍼 구조
```
HostedViewWrapper (filters: [gaussianBlur])
└── _UINavigationBarTitleControl
    └── _UIIntrinsicContentSizeInvalidationForwardingWrapperView
        └── _UIMultiLayer (filters: [vibrantColorMatrix])
            └── _UILabelLayer
                └── UILabel
```

### 타이틀 필터
- **gaussianBlur**: HostedViewWrapper에 적용 (배경과 블렌딩)
- **vibrantColorMatrix**: 레이블 레이어에 적용 (동적 색상)

---

## PlatterView 상세

### 런타임 속성 (Swift Mirror)
```swift
struct PlatterViewProperties {
    var scaleOffset: Unknown
    var transformViewA: Unknown
    var transformViewB: Unknown
    var contentView: Unknown
    var scalePulseScheduler: Unknown
    var mode: Unknown
}
```

### AnimationView 중첩 패턴

4단계 중첩된 AnimationView로 press 애니메이션 구현:

```
AnimationView (0, 0, W, H)      // 1단계: 기본 프레임
└── AnimationView (0, 0, W, H)  // 2단계: 전환용
    └── AnimationView           // 3단계: 확장 (pressed 시)
        frame: (-2.1, -2.1, W+4.2, H+4.2)
        bounds: (0, 0, W, H)
        └── AnimationView       // 4단계: 축소 (콘텐츠)
            frame: (1.92, 1.92, W*0.91, H*0.91)
            bounds: (0, 0, W, H)
```

**스케일 팩터 계산** (44pt 버튼 기준):
- 외곽 확장: `48.2 / 44 = 1.095` (약 9.5% 확장)
- 내부 축소: `40.17 / 44 = 0.913` (약 8.7% 축소)

---

## 화면별 버튼 구성

### 메인 그리드 (보관함)
```
NavigationBar
├── 타이틀: "보관함" (중앙)
└── Select 버튼 (우측)
```

### 앨범 상세 (일반 모드)
```
NavigationBar
├── Back 버튼 (좌측)
├── 타이틀: 앨범명 (좌측, Back 옆)
└── (우측 버튼 없음 또는 Select)
```

### 앨범 상세 (선택 모드)
```
NavigationBar
├── 타이틀: 앨범명 (좌측)
├── Cancel 버튼 (우측-1)
└── Select 버튼 (우측-2)
```

### 뷰어 (사진 상세)
```
NavigationBar
├── Back 버튼 (좌측)
└── (기타 액션 버튼)

TabBar: isHidden = true
```

---

## 버튼 여백 및 간격

### 좌측 버튼 (Back)
- **x offset**: 16pt (leading margin)

### 우측 버튼들
- **trailing margin**: 16pt (화면 우측 ~ 마지막 버튼)
- **버튼 간 간격**: ~12pt (Cancel과 Select 사이)

### 계산 예시 (화면 너비 402pt)
```
Select 버튼 우측 끝: 312.67 + 73.33 = 386pt
Trailing margin: 402 - 386 = 16pt ✓

Cancel-Select 간격:
Cancel 우측: 232.33 + 68.33 = 300.66pt
Select 좌측: 312.67pt
간격: 312.67 - 300.66 = 12pt
```

---

## 구현 가이드

### 버튼 사이징
```swift
// 아이콘 버튼 (Back, 삭제 등)
let iconButtonSize: CGFloat = 44

// 텍스트 버튼 (Select, Cancel 등)
let textButtonHeight: CGFloat = 44
let textButtonMinWidth: CGFloat = 68  // 최소 너비
// 너비는 텍스트 길이에 따라 동적
```

### cornerRadius
- 아이콘 버튼: `44 / 2 = 22pt` (완전 원형)
- 텍스트 버튼: `44 / 2 = 22pt` (캡슐형)

### 위치 계산
```swift
// 좌측 버튼
backButton.frame.origin.x = 16

// 우측 버튼들 (우측 정렬)
let trailingMargin: CGFloat = 16
let buttonSpacing: CGFloat = 12

selectButton.frame.origin.x = navBarWidth - trailingMargin - selectButton.width
cancelButton.frame.origin.x = selectButton.frame.origin.x - buttonSpacing - cancelButton.width
```

---

## 하단 플로팅 버튼 (뷰어 화면)

뷰어 화면 하단의 액션 버튼(삭제, 복구 등)은 NavigationBar 버튼과 **시각적으로 동일**하지만 크기만 다름.

### 크기 및 위치 (화면 너비 402pt 기준)

| 화면 | 버튼 | x 좌표 | 크기 | 배치 |
|------|------|--------|------|------|
| 일반 뷰어 | 삭제 1개 | 177pt | 48×48pt | 중앙 |
| 휴지통 뷰어 | 복구 | 28pt | 54×48pt | 좌측 |
| 휴지통 뷰어 | 삭제 | 320pt | 54×48pt | 우측 |

- **y 좌표**: 798pt (모두 동일)
- **하단 여백**: 76pt (safe area 포함)
- **좌우 마진**: 28pt (2개일 때)

### 내부 구조
- 컨테이너: `UIPlatformGlassInteractionView` (48×48pt)
- 내부 버튼: 38×38pt (5pt 패딩)
- 필터: `vibrantColorMatrix` (NavigationBar와 동일)

### 구현 시
iOS 16~25에서는 **같은 GlassButton 컴포넌트**로 통일하고 크기만 다르게 설정.

```swift
// NavigationBar 버튼
let navButtonSize: CGFloat = 44

// 하단 플로팅 버튼
let floatingButtonSize: CGFloat = 48
```

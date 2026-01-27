# iOS 26 TabBar 스펙

iOS 26.0.1 기준 Photos 앱 TabBar(Floating Tab Bar) 분석.

---

## TabBar 기본 정보

| 속성 | 값 |
|------|-----|
| frame | (0.0, 791.0, 402.0, 83.0) |
| **전체 높이** | **83pt** (safe area 포함) |
| safe area bottom | 13pt |

---

## Platter (Floating Capsule) 정보

### _UITabBarPlatterView
| 속성 | 값 |
|------|-----|
| frame | (64.0, 0.0, 274.0, 62.0) |
| **너비** | **274pt** |
| **높이** | **62pt** |
| **x offset** | 64pt (중앙 정렬) |

### 화면 대비 비율
- 화면 너비: 402pt
- Platter 너비: 274pt
- **비율**: 274 / 402 = **68.2%**

### Platter 내부 구조
```
_UITabBarPlatterView (274×62)
├── SelectedContentView (274×62)
│   └── _UITabButton × 3 (선택된 탭 콘텐츠)
├── _UILiquidLensView (94×54, 선택 효과)
│   └── UIView (contentWrapper)
│       ├── _UITabSelectionView (Selection Pill)
│       └── ClearGlassView (유리 효과)
├── ContentView (274×62)
│   └── _UITabButton × 3 (일반 탭 콘텐츠)
└── DestOutView (94×54, 마스킹)
```

---

## Tab Button 정보

### _UITabButton
| 속성 | 값 |
|------|-----|
| frame | (4.0, 4.0, 94.0, 54.0) 등 |
| **너비** | **94pt** |
| **높이** | **54pt** |
| **내부 패딩** | 4pt (Platter 가장자리로부터) |

### Tab Button 위치 (3개 탭 기준)
| 탭 순서 | x 좌표 | y 좌표 |
|--------|--------|--------|
| 1번 탭 | 4pt | 4pt |
| 2번 탭 | 90pt | 4pt |
| 3번 탭 | 176pt | 4pt |

**탭 간격 계산**:
- 2번 탭 시작: 90pt
- 1번 탭 끝: 4 + 94 = 98pt
- 간격: 90 - 98 = **-8pt** (오버랩, 터치 영역 확장)

실제로는 시각적으로 균등 배치 (패딩 제외 영역에서):
- 유효 너비: 274 - 8 = 266pt (좌우 4pt 패딩)
- 탭 간격: (266 - 94×3) / 2 = -8pt (정확히 맞음)

---

## 아이콘 및 레이블 정보

### 아이콘 (UIImageView)
| 탭 | 아이콘 frame | 아이콘 크기 |
|----|-------------|------------|
| 1번 | (30.0, 6.33, 34.33, 28.67) | 34.33×28.67 |
| 2번 | (32.0, 5.0, 30.0, 31.33) | 30×31.33 |
| 3번 | (34.0, 4.0, 25.67, 29.67) | 25.67×29.67 |

- 아이콘 크기가 탭마다 다름 (SF Symbol 원본 비율 유지)
- 수직 위치: 상단 정렬 (4~7pt)
- 수평 위치: 중앙 정렬

### 레이블 (Label / _UILabelLayer)
| 탭 | 레이블 frame | 레이블 크기 |
|----|-------------|------------|
| 1번 | (34.0, 35.0, 26.0, 12.0) | 26×12 |
| 2번 | (38.0, 35.0, 17.33, 12.0) | 17.33×12 |
| 3번 | (34.0, 35.0, 26.0, 12.0) | 26×12 |

- **레이블 높이**: **12pt** (폰트 크기 ~10pt 추정)
- **레이블 y 위치**: **35pt** (탭 버튼 기준)
- 레이블 너비: 텍스트 길이에 따라 동적

### 아이콘-레이블 간격
- 아이콘 하단: 6.33 + 28.67 = 35pt
- 레이블 상단: 35pt
- **간격**: 0pt (거의 붙어있음)

---

## Selection Pill (_UITabSelectionView)

### 크기 및 위치
| 속성 | 값 |
|------|-----|
| frame | (0.0, 0.0, 94.0, 54.0) |
| **너비** | **94pt** (Tab Button과 동일) |
| **높이** | **54pt** (Tab Button과 동일) |

### 스타일
| 속성 | 값 |
|------|-----|
| **cornerRadius** | **27.0** (높이의 절반) |
| **cornerCurve** | **continuous** |
| masksToBounds | false |

### 선택 위치에 따른 frame
- 1번 탭 선택: x = 4pt (SelectedContentView 내)
- 2번 탭 선택: x = 90pt
- 3번 탭 선택: x = 176pt

_UILiquidLensView가 선택된 탭 위치로 이동하면서 Selection Pill 표시

---

## Liquid Glass 효과 상세

### _UILiquidLensView 속성
```swift
// 주요 속성
warpsContentBelow: true          // 배경 왜곡 활성화
liftedContentMode: 1             // 콘텐츠 리프팅 모드
hasCustomRestingBackground: true // 커스텀 배경 사용
```

### 레이어 필터
| 뷰/레이어 | 필터 |
|----------|------|
| _UILiquidLensView | opacityPair |
| ClearGlassView 내부 UIView | displacementMap |
| _UIMultiLayer (아이콘/레이블) | vibrantColorMatrix |

### UICABackdropLayer 속성
```swift
scale: 0.25                  // 1/4 해상도로 배경 캡처
usesGlobalGroupNamespace: 0  // 로컬 그룹
captureOnly: 0               // 캡처 + 렌더링
groupName: "<UITabSelectionView: 0x...>"  // 그룹 식별자
```

---

## DestOutView (마스킹)

### 역할
선택된 탭의 콘텐츠가 Liquid Glass 위에 "떠있는" 효과 구현

### 속성
| 속성 | 값 |
|------|-----|
| frame | (0.0, 0.0, 94.0, 54.0) |
| backgroundColor | gray(0.00, alpha: 1.00) |
| **compositingFilter** | **destOut** |

### 작동 원리
1. SelectedContentView에 선택된 탭의 콘텐츠 렌더링
2. DestOutView가 그 위치를 "펀칭" (destOut 블렌드)
3. ContentView의 동일 위치가 "뚫려서" 보임
4. 결과: 선택된 콘텐츠가 Glass 위에 떠있는 효과

---

## 콘텐츠 이중 렌더링

### SelectedContentView vs ContentView
TabBar는 동일한 탭 버튼을 두 번 렌더링:

1. **SelectedContentView**: _UILiquidLensView 아래
   - 선택된 탭 콘텐츠가 Glass 아래로 "가라앉음"
   - DestOut으로 마스킹되어 Glass 위로 "떠오름"

2. **ContentView**: 최상단
   - 일반 탭 콘텐츠
   - 선택된 위치는 DestOut으로 투명해짐

### 아이콘 레이어 필터 상세
```
_UIMultiLayer
├── filters: [vibrantColorMatrix]
├── sublayer[0]: CALayer (아이콘 이미지)
└── (두 번째 _UIMultiLayer)
    ├── filters: [vibrantColorMatrix]
    └── sublayer[0]: _UILabelLayer (레이블)
```

---

## 핵심 수치 요약

| 항목 | 값 |
|------|-----|
| TabBar 전체 높이 | 83pt |
| Platter 크기 | 274×62pt |
| Platter 화면 비율 | 68.2% |
| Tab Button 크기 | 94×54pt |
| Tab Button 내부 패딩 | 4pt |
| Selection Pill cornerRadius | 27pt |
| 아이콘 상단 여백 | 4~7pt |
| 레이블 높이 | 12pt |
| 레이블 y 위치 | 35pt |
| UICABackdropLayer scale | 0.25 |

---

## 구현 가이드

### Platter 사이징
```swift
// 화면 너비 기준 동적 계산
let screenWidth: CGFloat = view.bounds.width
let platterWidthRatio: CGFloat = 0.682  // 68.2%
let platterWidth = screenWidth * platterWidthRatio
let platterHeight: CGFloat = 62
let platterX = (screenWidth - platterWidth) / 2
```

### Tab Button 레이아웃
```swift
let tabButtonSize = CGSize(width: 94, height: 54)
let internalPadding: CGFloat = 4
let numberOfTabs = 3

// 탭 버튼 위치 계산
for i in 0..<numberOfTabs {
    let x = internalPadding + CGFloat(i) * (platterWidth - internalPadding * 2) / CGFloat(numberOfTabs)
    tabButtons[i].frame = CGRect(x: x, y: internalPadding, width: tabButtonSize.width, height: tabButtonSize.height)
}
```

### Selection Pill 스타일
```swift
selectionPill.layer.cornerRadius = 27  // 높이의 절반
selectionPill.layer.cornerCurve = .continuous
selectionPill.layer.masksToBounds = false
```

### 탭 전환 애니메이션
```swift
UIView.animate(
    withDuration: 0.35,
    delay: 0,
    usingSpringWithDamping: 0.8,
    initialSpringVelocity: 0.5
) {
    liquidLensView.frame.origin.x = selectedTabButton.frame.origin.x
}
```

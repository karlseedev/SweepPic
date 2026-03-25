# 뷰어 상단 타이틀 + 그라데이션 딤드 기획

> 날짜: 2026-02-17
> 상태: 기획 확정

## 목표

뷰어 상단에 "유사사진 정리가능" 타이틀과 그라데이션 딤드를 추가하여
유사사진 분석 기능의 존재를 사용자에게 안내한다.

## 조건

| 항목 | 값 |
|------|-----|
| 타이틀 텍스트 | "유사사진 정리가능" |
| 표시 모드 | `.normal` 모드에서만 (`.trash`, `.cleanup` 제외) |
| 그라데이션 | iOS 16~25 + iOS 26 Modal에서만 (iOS 26 Push는 시스템 자동) |
| 눈 버튼 토글 | 타이틀 + 숫자넘버링 + +버튼 제거, **딤드는 유지** |

## iOS 버전별 구현

### iOS 16~25 + iOS 26 Modal (`useSystemUI == false`)

```
┌─────────────────────────────────┐
│ ▓▓▓▓▓▓▓ 그라데이션 딤드 ▓▓▓▓▓▓▓ │  ← black 50% → clear
│ [←]   유사사진 정리가능    [👁]  │  ← centerY = safeArea top + 38pt
│ ░░░░░░░░░░░░░░░░░░░░░░░░░░░░░░ │  ← 그라데이션 페이드아웃
│                                 │
│          (사진 영역)             │
└─────────────────────────────────┘
```

- **분기 조건**: `useSystemUI == false` (iOS 버전이 아닌 시스템UI 여부로 분기)
- **그라데이션**: `CAGradientLayer`
  - maxDimAlpha = **0.50**
  - 색상: black 50% → black 35% → black 15% → black 5% → clear
  - 높이: safeArea top 기준 + 약 60pt
  - `isUserInteractionEnabled = false` (터치 통과)
- **타이틀**: UILabel
  - font: semibold 15pt, color: white
  - centerX = 화면 중앙
  - centerY = safeArea top + 38pt (backButton과 수평 정렬)
- **항상 표시** (탭 토글 없음, 뷰어에 탭 토글 기능 없음)

### iOS 26+ Push (`useSystemUI == true`)

- **타이틀**: `self.title = "유사사진 정리가능"` (시스템 네비게이션 바)
- **그라데이션**: 시스템 자동 생성 → 추가 작업 없음

## 눈 버튼(토글) 동작

눈 버튼 탭 시 FaceButtonOverlay의 toggleOverlay()가 호출됨.

### 기존 동작 (변경 없음)
- +버튼 show/hide

### 추가 동작
- **타이틀 라벨**: 눈 버튼 토글에 따라 show/hide
- **숫자 넘버링** (photoNumberLabel): 눈 버튼 토글에 따라 show/hide (기존 동작 유지)
- **그라데이션 딤드**: **항상 유지** (토글 영향 없음)

| 상태 | 타이틀 | 숫자넘버링 | +버튼 | 딤드 |
|------|--------|-----------|-------|------|
| 눈 버튼 ON (eye.fill) | 표시 | 표시 | 표시 | 표시 |
| 눈 버튼 OFF (eye.slash) | 숨김 | 숨김 | 숨김 | **표시** |

## 뷰 계층 (z-order)

```
view
  ├── backgroundView               (최하단)
  ├── pageViewController.view      (사진 콘텐츠)
  ├── topGradientView              ← NEW (그라데이션 딤드)
  ├── titleLabel                   ← NEW (타이틀)
  ├── actionButtons (delete 등)    (하단 버튼)
  ├── backButton                   (좌상단)
  └── faceButtonOverlay            (최상단, +버튼/눈버튼/번호라벨)
```

- `topGradientView`: pageVC 위, backButton 아래
- `titleLabel`: topGradientView 위, backButton 아래 (또는 같은 레벨)
- 둘 다 `isUserInteractionEnabled = false`

## 구현 위치

| 작업 | 파일 | 설명 |
|------|------|------|
| topGradientView 생성 | `ViewerViewController.swift` | `setupUI()`에서 pageVC.view 다음, actionButtons 앞에 삽입 |
| titleLabel 생성 | `ViewerViewController.swift` | `setupUI()`에서 topGradientView 다음에 삽입 |
| iOS 26 Push 타이틀 | `ViewerViewController.swift` | `setupSystemNavigationBar()`에서 `self.title` 설정 |
| 모드 분기 | `ViewerViewController.swift` | `viewerMode == .normal`일 때만 생성 |
| 눈 버튼 토글 연동 | `FaceButtonOverlay.swift` | `toggleButtonTapped()`에서 타이틀 숨김 알림 발송 또는 델리게이트 |
| iOS 26 눈 버튼 토글 | `ViewerViewController.swift` | `navBarEyeButtonTapped()`에서 타이틀 숨김 처리 |

## 그라데이션 스펙 상세

FaceComparisonTitleBar 패턴 참고, 뷰어 전용으로 조정:

```swift
// maxDimAlpha = 0.50 (테스트 후 조정)
gradientLayer.colors = [
    UIColor.black.withAlphaComponent(0.50).cgColor,      // 상단
    UIColor.black.withAlphaComponent(0.50 * 0.7).cgColor, // 35%
    UIColor.black.withAlphaComponent(0.50 * 0.3).cgColor, // 15%
    UIColor.black.withAlphaComponent(0.50 * 0.1).cgColor, // 5%
    UIColor.clear.cgColor                                  // 하단 투명
]
gradientLayer.locations = [0, 0.25, 0.5, 0.75, 1.0]
```

## 좌표 정리

| 요소 | 위치 |
|------|------|
| backButton (iOS 16~25) | topAnchor = safeArea top + 16, leading + 16, size 44×44 |
| backButton centerY | safeArea top + 38pt |
| titleLabel centerY | safeArea top + 38pt (backButton과 수평 정렬) |
| toggleButton (FaceButtonOverlay) | topAnchor = safeArea top + 16, trailing - 16 |
| topGradientView | top = view.top (safeArea 아닌 전체), height = safeArea top + 60pt |

## 핵심 주의사항

1. **`useSystemUI` 기준 분기**: iOS 버전이 아닌 `useSystemUI` 프로퍼티로 분기
   - iOS 26 Modal에서도 커스텀 타이틀 + 그라데이션 필요
2. **backButton은 지역 변수**: 프로퍼티 승격 불필요, 좌표 hardcode (safeArea + 38)
3. **탭 토글 없음**: 뷰어에 사진 탭 시 UI show/hide 기능이 없으므로, 타이틀/딤드는 항상 표시
4. **눈 버튼 토글 시 딤드 유지**: 타이틀만 숨기고 그라데이션은 유지

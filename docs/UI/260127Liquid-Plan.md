# Liquid Glass 구현 계획

**작성일**: 2026-01-27
**버전**: v1 (데이터 수집 완료 후 v2로 업데이트 예정)

---

## 1. 배경

### 1.1. iOS 버전별 UI 전략

| iOS 버전 | UI 방식 | 플래그 |
|---------|--------|-------|
| iOS 16~25 | FloatingOverlay (커스텀 UI) | `useFloatingUI = true` |
| iOS 26+ | 시스템 네비게이션 바 | `useFloatingUI = false` |

- iOS 26+에서는 시스템이 Liquid Glass를 자동 적용
- iOS 16~25에서는 커스텀 FloatingOverlay를 사용 중

### 1.2. 현재 FloatingOverlay 상태

| 컴포넌트 | 파일 | 현재 스타일 |
|----------|------|-------------|
| FloatingTabBar | `Shared/Components/FloatingTabBar.swift` | 단순 블러 + 둥근 캡슐 |
| FloatingTitleBar | `Shared/Components/FloatingTitleBar.swift` | 단순 블러 버튼 |
| GlassButton | `Shared/Components/GlassButton.swift` | 단순 블러 버튼 |
| 플로팅 버튼 | `Features/Viewer/ViewerViewController.swift` | 단순 블러 버튼 |

### 1.3. 문제점

현재 커스텀 UI는 iOS 26 시스템 Liquid Glass와 시각적으로 차이가 큼:
- 배경 색상/투명도 불일치
- Selection Pill 효과 없음
- cornerCurve가 circular (iOS 26은 continuous)
- 크기/여백이 실측값과 불일치

---

## 2. 목표

### 2.1. 핵심 목표

**iOS 16~25의 커스텀 FloatingOverlay UI를 iOS 26 Liquid Glass 스타일과 99% 유사하게 업그레이드**

### 2.2. 품질 기준

| 기준 | 목표 |
|------|------|
| 시각적 유사도 | 99% (일반 사용자가 구분 불가 수준) |
| 크기/레이아웃 | iOS 26 실측값과 동일 |
| 애니메이션 | iOS 26과 동일한 Spring 애니메이션 |
| 색상/투명도 | iOS 26 실측값 적용 |

### 2.3. 대상 컴포넌트 (우선순위)

| 순위 | 컴포넌트 | 상태 |
|------|----------|------|
| 1 | TabBar | 🔄 진행 중 |
| 2 | NavBar | ⏸️ 대기 |
| 3 | 플로팅 버튼 | ⏸️ 대기 |

---

## 3. 제약 및 대안

### 3.1. 제약: Private API 사용 불가

- App Store 심사에서 Private API 사용 시 리젝
- iOS 26 Liquid Glass는 Private API 기반
- Public API로 동등한 효과 구현 필요

### 3.2. Private API → Public API 대안

| Private API | 역할 | Public API 대안 | 유사도 |
|-------------|------|----------------|--------|
| `_UILiquidLensView` | Liquid Glass 루트 | `UIView` + `UIVisualEffectView` | 95% |
| `vibrantColorMatrix` | 아이콘/레이블 색상 | `UIVibrancyEffect` 또는 고정 tintColor | 🔍 검증 필요 |
| `gaussianBlur` + `colorMatrix` | 배경 블러/색보정 | `UIVisualEffectView(.systemMaterial)` | 95% |
| `destOut` compositingFilter | Selection Pill 마스킹 | `CALayer.mask` 또는 별도 뷰 구조 | 🔍 검증 필요 |
| `CASDFLayer` | SDF 형태/Rim Light | `CAGradientLayer` + `cornerCurve: .continuous` | 🔍 검증 필요 |
| `UICABackdropLayer` | 배경 캡처 (scale 0.25) | `UIVisualEffectView` 기본 동작 | 90% |

### 3.3. 미해결 항목 (데이터 수집 후 대안 결정)

| Private API | 역할 | 현재 상태 | 대안 후보 |
|-------------|------|----------|-----------|
| `opacityPair` 필터 | 🔍 역할 불명 | 파라미터 없음 | 🔍 조사 후 결정 |
| `displacementMap` 필터 | 렌즈 왜곡 효과 | inputAmount=0 외 불명 | Metal Shader 또는 생략 |
| `CASDFLayer` | SDF 데이터 정의 | 정의 방법 불명 | UIBezierPath + CAShapeLayer |
| `CAPortalLayer` | 레이어 미러링 | sourceLayer 불명 | 스냅샷 또는 직접 렌더링 |
| `innerShadowView` | 내부 그림자 | 설정 방법 불명 | CALayer.shadow + mask |

### 3.4. 예상 시각적 차이

| 효과 | iOS 26 | 대안 구현 | 예상 유사도 |
|------|--------|----------|------------|
| 배경 블러 | ✅ | ✅ UIVisualEffectView | 99% |
| 배경 색상/투명도 | ✅ | ✅ 실측값 적용 | 99% |
| Selection Pill 형태 | ✅ | ✅ cornerCurve: continuous | 99% |
| Selection Pill 이동 | ✅ | ✅ Spring 애니메이션 | 100% |
| 아이콘 색상 (선택/비선택) | ✅ | 🔍 UIVibrancyEffect | 95% |
| 렌즈 왜곡 (굴절) | ✅ | 🔍 미해결 | 80~95% |
| Rim Light | ✅ | 🔍 CAGradientLayer | 90% |

---

## 4. TabBar 구현

### 4.1. 현재 vs 실측 비교

| 항목 | 현재 구현 | iOS 26 실측 | 변경 필요 |
|------|----------|-------------|----------|
| Platter 너비 비율 | 60% | **68.2%** | ✅ |
| Platter 높이 | 56pt | **62pt** | ✅ |
| Tab Button 크기 | - | **94×54pt** | ✅ |
| 내부 패딩 | - | **4pt** | ✅ |
| Selection Pill 크기 | - | **94×54pt** | ✅ (신규) |
| Selection Pill cornerRadius | - | **27pt** | ✅ (신규) |
| cornerCurve | circular | **continuous** | ✅ |
| 배경 gray | - | **0.11** | ✅ |
| 배경 alpha | 0.12 | **0.73** | ✅ |

### 4.2. 파일 구조 (예정)

```
Shared/Styles/
├── LiquidGlassStyle.swift              (기존, 유지)
└── LiquidGlassStyle+Measurements.swift (신규, 실측 상수)

Shared/Components/
├── FloatingTabBar.swift                (기존, 수정)
├── FloatingTabBar+SelectionPill.swift  (신규)
└── SelectionPillView.swift             (신규)
```

### 4.3. Phase 체크리스트

#### Phase 1: 실측 상수 적용
- [ ] `LiquidGlassStyle+Measurements.swift` 생성
- [ ] Platter 크기 상수 (274×62, 68.2%)
- [ ] Tab Button 크기 상수 (94×54, 패딩 4pt)
- [ ] Selection Pill 상수 (cornerRadius 27pt)
- [ ] 배경 색상 상수 (gray 0.11, alpha 0.73)

#### Phase 2: Selection Pill 구현
- [ ] `SelectionPillView.swift` 생성
- [ ] cornerRadius=27, cornerCurve=continuous
- [ ] 배경 블러 효과 (UIVisualEffectView 또는 🔍 대안)
- [ ] `FloatingTabBar+SelectionPill.swift` 생성
- [ ] 선택 탭 위치 계산 로직
- [ ] Spring 애니메이션 (0.35s, damping 0.8)

#### Phase 3: FloatingTabBar 수정
- [ ] Platter 크기 실측값 적용
- [ ] cornerCurve: continuous 적용
- [ ] Tab Button 레이아웃 수정
- [ ] Selection Pill 통합

#### Phase 4: 아이콘/레이블 스타일
- [ ] 선택 탭 색상 (파란 틴트) - 🔍 UIVibrancyEffect 또는 tintColor
- [ ] 비선택 탭 색상 (회색) - 🔍 UIVibrancyEffect 또는 고정 색상
- [ ] 아이콘 크기 조정 (28pt pointSize)
- [ ] 레이블 위치/크기 (y=35pt, 높이 12pt)

#### Phase 5: 마무리
- [ ] 접근성 대응 (투명도 감소, 모션 감소)
- [ ] 다크/라이트 모드 대응
- [ ] 성능 최적화

### 4.4. 검증 체크리스트

#### 크기/레이아웃
- [ ] Platter 너비 68.2%
- [ ] Platter 높이 62pt
- [ ] Tab Button 94×54pt
- [ ] Selection Pill cornerRadius 27pt
- [ ] cornerCurve: continuous

#### 색상/효과
- [ ] 배경 gray 0.11, alpha 0.73
- [ ] 선택 탭 파란 틴트
- [ ] 비선택 탭 회색

#### 애니메이션
- [ ] Selection Pill Spring 애니메이션
- [ ] 전환 시간 0.35s
- [ ] damping 0.8

#### 접근성
- [ ] 투명도 감소 설정 대응
- [ ] 모션 감소 설정 대응

---

## 5. NavBar 구현

> ⏸️ TabBar 완료 후 진행 예정

### 5.1. 참조 자료

- [260126Liquid-navbar.md](./260126Liquid-navbar.md) - 기본 틀

---

## 6. 플로팅 버튼 구현

> ⏸️ TabBar 완료 후 진행 예정

### 6.1. 실측값 (참고)

| 항목 | 값 |
|------|-----|
| 일반 삭제 버튼 | 48×48pt |
| 휴지통 버튼 | 54×48pt |
| 하단 여백 | 76pt |
| 좌우 마진 (2개일 때) | 28pt |

---

## 7. 변경 이력

| 날짜 | 버전 | 변경 내용 |
|------|------|-----------|
| 2026-01-27 | v1 | 문서 생성 (데이터 수집 80% 기준) |
| - | v2 | 🔜 데이터 수집 완료 후 상세 대안 확정 |

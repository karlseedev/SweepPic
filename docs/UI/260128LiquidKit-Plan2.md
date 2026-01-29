# LiquidGlassKit 일반 버튼 적용 계획

**작성일**: 2026-01-28
**버전**: v1
**관련 문서**: [260127LiquidKit-Plan1.md](./260127LiquidKit-Plan1.md)

---

## iOS 버전별 전략

| iOS 버전 | 전략 |
|---------|------|
| **iOS 26+** | 시스템 제공 UIGlassEffect 사용 (네이티브) |
| **iOS 16~25** | LiquidGlassKit으로 Liquid Glass 효과 구현 |

이 문서는 **iOS 16~25에서 사용되는 일반 버튼**들에 LiquidGlassKit을 적용하는 계획입니다.
탭바 관련 구현은 [Plan1](./260127LiquidKit-Plan1.md)에서 완료되었습니다.

---

## iOS 26 버튼 실측 스펙

> **측정일**: 2026-01-28
> **측정 도구**: ButtonInspector (Debug/ButtonInspector.swift)
> **iOS 버전**: 26.0.1

### NavBar 아이콘 버튼 (뒤로가기)

| 항목 | 값 |
|------|-----|
| **Glass 컨테이너** | PlatterGlassView |
| **크기** | 44×44 |
| **cornerRadius** | 22 (완전한 원형) |
| **cornerCurve** | continuous |
| **iconSize** | 28 |
| **tintColor** | #0091FF (파란색) |

### 하단 아이콘 버튼 (휴지통 - Grid)

| 항목 | 값 |
|------|-----|
| **터치 영역** | 48×48 |
| **버튼 크기** | 38×38 |
| **iconSize** | 28 |
| **tintColor** | #FF4245 (빨간색) |
| **cornerRadius** | 0 |

### 하단 텍스트 버튼 (Viewer: 복구/삭제)

| 항목 | 복구 | 삭제 |
|------|------|------|
| **텍스트** | "복구" | "삭제" |
| **터치 영역** | 48×54 | 48×54 |
| **버튼 크기** | 38×44 | 38×44 |
| **fontSize** | 17 | 17 |
| **tintColor** | #30D158 (녹색) | #FF4245 (빨간색) |
| **cornerRadius** | 0 | 0 |

### 하단 텍스트 버튼 (Grid: Restore All / Delete All)

| 항목 | Restore All | Delete All |
|------|-------------|------------|
| **터치 영역** | 48×84.33 | 48×74.67 |
| **버튼 크기** | 38×(동적) | 38×(동적) |
| **라벨 크기** | 20.33×60.33 | 20.33×50.67 |
| **fontSize** | 17 | 17 |
| **tintColor** | #0091FF (파란색) | #FF4245 (빨간색) |
| **높이** | 38 (고정) | 38 (고정) |

> **Note**: 텍스트 버튼의 너비는 텍스트 길이에 따라 동적으로 결정됨

### 상단 눈모양 버튼 (NavBar - 얼굴 토글)

> **측정 기기**: iPhone 13 mini (iOS 26.2)

| 항목 | 값 |
|------|-----|
| **Glass 컨테이너** | PlatterGlassView |
| **크기** | 44×45.67 |
| **cornerRadius** | 22 |
| **iconSize** | 29.67 |
| **tintColor** | #FFFFFF (흰색) |

### FaceButton (얼굴 위 버튼)

| 항목 | 값 |
|------|-----|
| **크기** | 44×44 |
| **cornerRadius** | 22 (원형) |
| **backgroundColor** | #000000 (50%) - 반투명 검정 |
| **tintColor** | #FFFFFF (흰색) |
| **iconSize** | 26.33 |
| **shadowRadius** | 4 |
| **shadowOpacity** | 0.3 |
| **shadowOffset** | (0, 2) |

### 얼굴 비교 타이틀바 버튼 (닫기/다음 인물)

> **참조**: 기존 NavBar 아이콘 버튼과 동일 스펙, 아이콘만 다름

| 항목 | 닫기 버튼 | 다음 인물 버튼 |
|------|----------|----------------|
| **참조 스펙** | NavBar 아이콘 버튼 (뒤로가기) | 상단 눈모양 버튼 |
| **크기** | 44×44 | 44×45.67 |
| **cornerRadius** | 22 | 22 |
| **아이콘** | xmark | arrow.trianglehead.2.clockwise.rotate.90 |
| **tintColor** | #FFFFFF (흰색) | #FFFFFF (흰색) |

### 얼굴 비교 화면 하단 버튼 (취소/삭제)

> **참조**: 휴지통 그리드 선택 모드의 Restore All / Delete All 버튼과 동일 스펙 적용

| 항목 | 취소 | 삭제 |
|------|------|------|
| **터치 영역** | 48×(동적) | 48×(동적) |
| **버튼 크기** | 38×(동적) | 38×(동적) |
| **fontSize** | 17 | 17 |
| **tintColor** | #0091FF (파란색) | #FF4245 (빨간색) |
| **높이** | 38 (고정) | 38 (고정) |
| **cornerRadius** | 19 (pill shape) | 19 (pill shape) |

### 자동 정리 취소 버튼

> **참조**: 얼굴 비교 화면 취소 버튼과 동일 스펙 적용

| 항목 | 값 |
|------|-----|
| **버튼 크기** | 38×(동적) |
| **fontSize** | 17 |
| **tintColor** | #0091FF (파란색) |
| **높이** | 38 (고정) |
| **cornerRadius** | 19 (pill shape) |

### 색상 정리

| 용도 | 색상 | Hex |
|------|------|-----|
| 기본 (파란색) | systemBlue | #0091FF |
| 복구/긍정 (녹색) | systemGreen | #30D158 |
| 삭제/위험 (빨간색) | systemRed | #FF4245 |

### 구현 스펙 (iOS 16-25용) - ✅ 구현 완료

#### GlassIconButton (아이콘 버튼)

> **파일**: `Shared/Components/GlassIconButton.swift`
> **적용**: backButton, closeButton, cycleButton

| 항목 | 값 | 비고 |
|------|-----|------|
| **크기** | 44×44 | Size.medium |
| **cornerRadius** | 22 | height / 2, 원형 |
| **배경** | `LiquidGlassEffect` | LiquidGlassPlatter와 동일 |
| **배경 tintColor** | `UIColor(white: 0, alpha: 0.2)` | 어둡고 투명 |
| **iconSize** | 22pt | |
| **iconWeight** | `.light` | |
| **iconColor** | `.white` | 기본값 |
| **아이콘 그림자** | 없음 | |
| **Specular Highlight** | 없음 | |
| **Dual State** | contracted ↔ expanded | 터치 시 확장 애니메이션 |
| **햅틱** | `.light` | |

#### GlassCircleButton (원형 버튼) - Phase 3 예정

> **파일**: `Shared/Components/GlassCircleButton.swift`
> **적용**: toggleButton, faceButtons[]

| 항목 | 값 | 비고 |
|------|-----|------|
| **크기** | 44×44 | Size.medium |
| **cornerRadius** | 22 | height / 2, 원형 |
| **배경** | `LiquidGlassEffect` | GlassIconButton과 동일 |
| **배경 tintColor** | `UIColor(white: 0, alpha: 0.2)` | 어둡고 투명 |
| **iconSize** | 22pt | |
| **iconWeight** | `.light` | |
| **iconColor** | `.white` | 기본값 |
| **아이콘 그림자** | 없음 | |
| **Specular Highlight** | 없음 | |
| **Dual State** | contracted ↔ expanded | |
| **햅틱** | `.light` | |

#### GlassTextButton (텍스트 버튼) - Phase 5 예정

> **파일**: `Shared/Components/GlassTextButton.swift`
> **적용**: cancelButton, deleteButton

| 항목 | 값 | 비고 |
|------|-----|------|
| **높이** | 38 (고정) | |
| **cornerRadius** | 19 | height / 2, pill shape |
| **배경** | `LiquidGlassEffect` | GlassIconButton과 동일 |
| **배경 tintColor** | `UIColor(white: 0, alpha: 0.2)` | 어둡고 투명 |
| **fontSize** | 17pt | |
| **fontWeight** | `.regular` | |
| **textColor** | 용도별 | 파란/빨간/흰색 |
| **텍스트 그림자** | 없음 | |
| **Specular Highlight** | 없음 | |
| **Dual State** | contracted ↔ expanded | |
| **햅틱** | `.light` | |
| **좌우 패딩** | 7pt | |
| **너비** | 텍스트 너비 + 14 | 패딩×2 |

#### 텍스트별 버튼 너비 (참고용)
| 텍스트 | 버튼 너비 |
|--------|----------|
| 복구 / 삭제 | 44pt |
| Restore All | 74pt |
| Delete All | 65pt |

---

## 1. 전체 버튼 목록 및 Liquid Glass 적용 판단

### 1.1. FloatingTabBar (하단 탭바) - iOS 16~25
**파일**: `Shared/Components/FloatingTabBar.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `photosButton` | UIButton | 아이콘+텍스트 수직 | 보관함 탭 | ❌ | 탭바 구현 완료 (Plan1) |
| `albumsButton` | UIButton | 아이콘+텍스트 수직 | 앨범 탭 | ❌ | 탭바 구현 완료 (Plan1) |
| `trashButton` | UIButton | 아이콘+텍스트 수직 | 휴지통 탭 | ❌ | 탭바 구현 완료 (Plan1) |
| `emptyTrashButton` | UIButton | 원형 아이콘 | 휴지통 비우기 | ❌ | **미사용** (isHidden=true, 비활성화됨) |
| `deleteButton` | GlassButton | Capsule+텍스트 | Select 삭제 | ✅ | Phase 7 (GlassButton 수정) |
| `trashRestoreButton` | GlassButton | Capsule+텍스트 | Trash 복구 | ✅ | Phase 7 (GlassButton 수정) |
| `trashDeleteButton` | GlassButton | Capsule+텍스트 | Trash 영구삭제 | ✅ | Phase 7 (GlassButton 수정) |

---

### 1.2. FloatingTitleBar (상단 타이틀바) - iOS 16~25
**파일**: `Shared/Components/FloatingTitleBar.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `backButton` | GlassIconButton | 아이콘만 (chevron.left) | 뒤로가기 | ✅ 완료 | Phase 2a |
| `selectButton` | GlassButton | Capsule+텍스트 | Select 모드 | ✅ | Phase 7 (GlassButton 수정) |
| `secondRightButton` | GlassButton | Capsule+텍스트 | 비우기/커스텀 | ✅ | Phase 7 (GlassButton 수정) |

---

### 1.3. LiquidGlassTabBar - iOS 26+
**파일**: `Shared/Components/LiquidGlassTabBar.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `tabButtons[0~2]` | LiquidGlassTabButton | 아이콘+레이블 수직 | 탭 선택 | ❌ | iOS 26 네이티브 (수정 불필요) |
| `deleteButton` | GlassButton | Capsule+텍스트 | Select 삭제 | ✅ | Phase 7 (GlassButton 수정) |
| `trashRestoreButton` | GlassButton | Capsule+텍스트 | Trash 복구 | ✅ | Phase 7 (GlassButton 수정) |
| `trashDeleteButton` | GlassButton | Capsule+텍스트 | Trash 영구삭제 | ✅ | Phase 7 (GlassButton 수정) |

---

### 1.4. ViewerViewController (전체화면 뷰어)
**파일**: `Features/Viewer/ViewerViewController.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `deleteButton` | GlassButton | 아이콘 56×56 | 사진 삭제 | ✅ | Phase 7 (GlassButton 수정) + 아이콘 그림자 제거 |
| `restoreButton` | GlassButton | 아이콘 56×56 | 복구 | ✅ | Phase 7 (GlassButton 수정) + 아이콘 그림자 제거 |
| `permanentDeleteButton` | GlassButton | 아이콘 56×56 | 영구삭제 | ✅ | Phase 7 (GlassButton 수정) + 아이콘 그림자 제거 |
| `backButton` (iOS 26) | GlassButton | 아이콘 | 뒤로가기 | ✅ | Phase 7 (GlassButton 수정) |
| `debugAnalyzeButton` | UIButton | 텍스트만 | 디버그용 | ❌ | DEBUG 전용, 변경 불필요 |

---

### 1.5. VideoControlsOverlay (비디오 컨트롤)
**파일**: `Features/Viewer/VideoControlsOverlay.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `playPauseButton` | UIButton | 아이콘 22pt | 재생/일시정지 | ❌ | iOS 26에서도 Glass 배경 없음 |
| `muteButton` | UIButton | 아이콘 22pt | 음소거 토글 | ❌ | iOS 26에서도 Glass 배경 없음 |

---

### 1.6. FaceButtonOverlay (얼굴 버튼)
**파일**: `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `toggleButton` | GlassCircleButton | 36×36 아이콘 | 표시/숨김 토글 | ✅ 완료 | Phase 4 |
| `faceButtons[]` | FaceButton (GlassCircleButton 상속) | 44pt 원형 | 얼굴 비교 진입 | ✅ 완료 | Phase 4 |

---

### 1.7. FaceComparisonViews (얼굴 비교 타이틀바)
**파일**: `Features/SimilarPhoto/UI/FaceComparisonViews.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `closeButton` | GlassIconButton | 아이콘만 (xmark) | 닫기 | ✅ 완료 | Phase 2c |
| `cycleButton` | GlassIconButton | 아이콘만 | 다음 인물 | ✅ 완료 | Phase 2c |

---

### 1.8. FaceComparisonViewController (얼굴 비교)
**파일**: `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `cancelButton` | GlassTextButton | 텍스트 (.plain) | 취소 | ✅ 완료 | Phase 6 |
| `deleteButton` | GlassTextButton | 텍스트 (.filled) | 삭제 | ✅ 완료 | Phase 6 |

---

### 1.9. PermissionViewController (권한 요청)
**파일**: `Features/Permissions/PermissionViewController.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `actionButton` | UIButton | 텍스트+파란배경 | 권한 요청 | ❌ | 시스템 스타일 유지 (권한 화면 특성상) |

---

### 1.10. CleanupProgressView (자동 정리)
**파일**: `Features/AutoCleanup/UI/CleanupProgressView.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `cancelButton` | GlassTextButton | 텍스트 (.plain) | 정리 취소 | ✅ 완료 | Phase 6 |

---

## 2. 적용 판단 요약

### 2.1. 상태별 집계

| 상태 | 버튼 수 | 설명 |
|------|--------|------|
| ✅ Phase 1-6 완료 | 8개 | GlassIconButton, GlassCircleButton, GlassTextButton |
| ✅ Phase 7 예정 | 12개 | GlassButton 수정 (LiquidGlassEffect 적용) |
| ❌ 적용 안함 | 8개 | iOS 26 전용, 디버그용, 시스템 스타일, 미사용 등 |

### 2.2. Phase 1-6 완료 버튼 목록

| 버튼명 | 파일 | 변경된 타입 | Phase |
|--------|------|------------|-------|
| `backButton` | FloatingTitleBar | GlassIconButton | 2a ✅ |
| `closeButton` | FaceComparisonViews | GlassIconButton | 2c ✅ |
| `cycleButton` | FaceComparisonViews | GlassIconButton | 2c ✅ |
| `toggleButton` | FaceButtonOverlay | GlassCircleButton | 4 ✅ |
| `faceButtons[]` | FaceButtonOverlay | GlassCircleButton (상속) | 4 ✅ |
| `cancelButton` | FaceComparisonViewController | GlassTextButton | 6 ✅ |
| `deleteButton` | FaceComparisonViewController | GlassTextButton | 6 ✅ |
| `cancelButton` | CleanupProgressView | GlassTextButton | 6 ✅ |

### 2.3. Phase 7 예정 버튼 목록 (GlassButton 수정)

| 버튼명 | 파일 | tintColor | useCapsuleStyle |
|--------|------|-----------|-----------------|
| `deleteButton` | FloatingTabBar | .systemRed | true |
| `trashRestoreButton` | FloatingTabBar | .systemBlue | true |
| `trashDeleteButton` | FloatingTabBar | .systemRed | true |
| `selectButton` | FloatingTitleBar | .systemBlue | true |
| `secondRightButton` | FloatingTitleBar | .systemRed | true |
| `deleteButton` | LiquidGlassTabBar | .systemRed | true |
| `trashRestoreButton` | LiquidGlassTabBar | .systemBlue | true |
| `trashDeleteButton` | LiquidGlassTabBar | .systemRed | true |
| `deleteButton` | ViewerViewController | .systemRed | false (아이콘) |
| `restoreButton` | ViewerViewController | .systemGreen | false (아이콘) |
| `permanentDeleteButton` | ViewerViewController | .systemRed | false (아이콘) |
| `backButton` (iOS 26) | ViewerViewController | .clear | false (아이콘) |

### 2.4. 적용 안함 버튼 목록

| 버튼명 | 파일 | 이유 |
|--------|------|------|
| `photosButton` | FloatingTabBar | 탭바 구현 완료 (Plan1) |
| `albumsButton` | FloatingTabBar | 탭바 구현 완료 (Plan1) |
| `trashButton` | FloatingTabBar | 탭바 구현 완료 (Plan1) |
| `emptyTrashButton` | FloatingTabBar | **미사용** (isHidden=true, 비활성화됨) |
| `playPauseButton` | VideoControlsOverlay | iOS 26에서도 Glass 배경 없음 |
| `muteButton` | VideoControlsOverlay | iOS 26에서도 Glass 배경 없음 |
| `debugAnalyzeButton` | ViewerViewController | DEBUG 전용 |
| `actionButton` | PermissionViewController | 시스템 스타일 유지 |

---

## 3. 파일 구조

### 3.1. 최종 구조 (옵션 A: 유형별 파일 분리)

```
Shared/Components/
├── GlassButton.swift        # 기존 유지 (Capsule, 아이콘+텍스트)
├── GlassIconButton.swift    # NEW - 아이콘 전용
├── GlassCircleButton.swift  # NEW - 원형
└── GlassTextButton.swift    # NEW - 텍스트 전용
```

### 3.2. 선택 근거

| 기준 | 판단 |
|------|------|
| 파일 크기 | 각 150~200줄 예상 (1000줄 제한 준수) |
| 코드 중복 | LiquidGlassKit이 대부분 처리, 중복 최소화 |
| 유지보수 | 각 파일 독립적 수정 가능 |
| 버튼 유형 차이 | 레이아웃이 달라서 분리가 자연스러움 |

### 3.3. 유형별 적용 버튼

| 파일 | 적용 버튼 | 개수 |
|------|----------|------|
| `GlassIconButton.swift` | backButton, closeButton, cycleButton | 3개 |
| `GlassCircleButton.swift` | toggleButton, faceButtons[] | 2개 |
| `GlassTextButton.swift` | cancelButton(2), deleteButton | 3개 |

---

## 4. 구현 계획

### Phase 1: ✅ GlassIconButton 구현 완료

**목표:** 아이콘 전용 Liquid Glass 버튼 클래스 생성

**생성 파일:** `Shared/Components/GlassIconButton.swift`

**최종 구현:**
```swift
final class GlassIconButton: UIButton {

    enum Size {
        case small   // 36×36, 아이콘 14pt
        case medium  // 44×44, 아이콘 22pt
        case large   // 56×56, 아이콘 22pt
    }

    init(icon: String, size: Size = .medium, tintColor: UIColor = .white)

    func setIcon(_ icon: String, animated: Bool = false)
}
```

**구현된 기능:**
- ✅ Dual state (contracted ↔ expanded)
- ✅ LiquidGlassEffect 적용 (LiquidGlassPlatter와 동일)
- ✅ 배경 tintColor: `UIColor(white: 0, alpha: 0.2)`
- ✅ 아이콘 weight: `.light`
- ✅ 햅틱 피드백 (.light)
- ✅ 아이콘 변경 메서드 (토글용)
- ✅ 아이콘 그림자 없음
- ✅ Specular Highlight 없음

---

### Phase 2a: ✅ GlassIconButton 첫 적용 완료 (backButton)

**목표:** backButton 하나만 먼저 적용하여 기본 동작 검증

**변경 파일 및 버튼:**

| 파일 | 버튼 | 크기 | 아이콘 | tintColor |
|------|------|------|--------|-----------|
| `FloatingTitleBar.swift` | `backButton` | .medium | chevron.left | .white |

---

### Phase 2b: ✅ 검증 완료

**목표:** GlassIconButton 기본 동작 확인

**확인 방법:**
1. 앱 실행 → 앨범 탭 → 아무 앨범 선택
2. 좌상단 **뒤로가기 버튼** 확인

**검증 항목:**
- [x] Liquid Glass 배경 효과 표시
- [x] 버튼 터치 시 햅틱 피드백
- [x] 버튼 동작 (뒤로가기) 정상
- [x] 다양한 배경(사진)에서 굴절 효과 확인

**결과:** Phase 2c 진행 가능

---

### Phase 2c: ✅ GlassIconButton 나머지 적용 완료

**목표:** 검증된 GlassIconButton을 나머지 버튼에 적용

**변경 파일 및 버튼:**

| 파일 | 버튼 | 크기 | 아이콘 | tintColor |
|------|------|------|--------|-----------|
| `FaceComparisonViews.swift` | `closeButton` | .medium | xmark | .white |
| `FaceComparisonViews.swift` | `cycleButton` | .medium | arrow.trianglehead.2.clockwise.rotate.90 | .white |

**구현 완료 내용:**
- FaceComparisonTitleBar에서 UIButton.Configuration → GlassIconButton 교체
- blurView 배경 제거 (버튼 자체가 glass 효과 가짐)
- setCycleButtonEnabled() 간소화 (GlassIconButton이 isEnabled 변경 시 자동 alpha 조정)

---

### Phase 3: ✅ GlassCircleButton 구현 완료

**목표:** 원형 Liquid Glass 버튼 클래스 생성 (GlassIconButton과 동일 스타일)

**생성 파일:** `Shared/Components/GlassCircleButton.swift`

**클래스 설계:**
```swift
final class GlassCircleButton: UIButton {

    enum Size {
        case small   // 36×36, 아이콘 14pt
        case medium  // 44×44, 아이콘 22pt
        case large   // 56×56, 아이콘 22pt
    }

    init(icon: String, size: Size = .medium, tintColor: UIColor = .white)

    func setIcon(_ icon: String, animated: Bool = false)
}
```

**구현 스펙 (GlassIconButton과 동일):**

| 항목 | 값 | 비고 |
|------|-----|------|
| **배경** | `LiquidGlassEffect` | LiquidGlassPlatter와 동일 |
| **배경 tintColor** | `UIColor(white: 0, alpha: 0.2)` | 어둡고 투명 |
| **cornerRadius** | dimension / 2 | 완전한 원형 |
| **iconSize** | 22pt (medium) | |
| **iconWeight** | `.light` | |
| **iconColor** | `.white` | 기본값 |
| **아이콘 그림자** | 없음 | |
| **Specular Highlight** | 없음 | |
| **Dual State** | contracted ↔ expanded | |
| **햅틱** | `.light` | |

> **Note:** GlassIconButton과 구조 동일. 용도 구분을 위해 별도 클래스로 분리.

---

### Phase 4: ✅ GlassCircleButton 적용 완료

**목표:** 기존 버튼을 GlassCircleButton으로 교체

**변경 파일 및 버튼:**

| 파일 | 버튼 | 크기 | 아이콘 | tintColor | iOS 버전 |
|------|------|------|--------|-----------|----------|
| `FaceButtonOverlay.swift` | `toggleButton` | .small | eye.fill / eye.slash.fill | .white | 16-25 |
| `FaceButtonOverlay.swift` | `faceButtons[]` | .medium | plus.circle.fill | .white | **전체** |

**구현 완료 내용:**
- `toggleButton`: UIButton → GlassCircleButton (.small)
- `FaceButton`: GlassCircleButton 상속으로 변경
  - face 프로퍼티 유지
  - 접근성 설정 유지
  - Dual state, 햅틱은 GlassCircleButton 기본 동작 사용
- `updateToggleIcon()`: setIcon 메서드 사용으로 변경

---

### Phase 5: ✅ GlassTextButton 구현 완료

**목표:** 텍스트 전용 Liquid Glass 버튼 클래스 생성

**생성 파일:** `Shared/Components/GlassTextButton.swift`

**클래스 설계:**
```swift
class GlassTextButton: UIButton {

    enum Style {
        case plain      // Glass 배경 + 텍스트
        case filled     // Glass 배경 + 색상 오버레이 + 텍스트
    }

    init(title: String, style: Style = .plain, tintColor: UIColor = .white)

    func setButtonTitle(_ title: String, animated: Bool = false)
}
```

**구현 스펙:**

| 항목 | 값 | 비고 |
|------|-----|------|
| **배경** | `LiquidGlassEffect` | LiquidGlassPlatter와 동일 |
| **배경 tintColor** | `UIColor(white: 0, alpha: 0.2)` | 어둡고 투명 |
| **높이** | 38pt (고정) | |
| **cornerRadius** | 19 (pill shape) | height / 2 |
| **fontSize** | 17pt | |
| **fontWeight** | `.regular` | |
| **textColor** | 용도별 (파란/빨간/흰색) | |
| **텍스트 그림자** | 없음 | |
| **Specular Highlight** | 없음 | |
| **Dual State** | contracted ↔ expanded | |
| **햅틱** | `.light` | |

**Style별 차이:**

| Style | 배경 | 용도 |
|-------|------|------|
| `.plain` | Glass만 | 취소 버튼 |
| `.filled` | Glass + 색상 오버레이 (alpha 0.3) | 삭제/확인 버튼 |

---

### Phase 6: ✅ GlassTextButton 적용 완료

**목표:** 기존 UIButton을 GlassTextButton으로 교체

**변경 파일 및 버튼:**

| 파일 | 버튼 | Style | textColor | iOS 버전 |
|------|------|-------|-----------|----------|
| `FaceComparisonViewController.swift` | `cancelButton` | .plain | .systemBlue | **전체** |
| `FaceComparisonViewController.swift` | `deleteButton` | .filled (.systemRed) | .white | **전체** |
| `CleanupProgressView.swift` | `cancelButton` | .plain | .systemRed | 16-25 |

**구현 완료 내용:**
- FaceComparisonViewController: cancelButton, deleteButton → GlassTextButton
- CleanupProgressView: cancelButton → GlassTextButton
- GlassTextButton은 intrinsicContentSize 사용하여 텍스트에 맞게 자동 크기 조정

---

### Phase 7: GlassButton 수정 (LiquidGlassEffect 적용)

**목표:** 기존 GlassButton의 contractedView를 UIBlurEffect → LiquidGlassEffect로 변경

**수정 파일:** `Shared/Components/GlassButton.swift`

**현재 문제점:**
- contractedView가 `UIBlurEffect`를 사용 (탭바와 다른 느낌)
- tintView, highlightLayer 등 불필요한 레이어 존재
- GlassIconButton과 스타일 불일치

**수정 내용:**
```swift
// 기존 (UIBlurEffect)
private lazy var blurView: UIVisualEffectView = {
    let effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
    ...
}()

// 변경 (LiquidGlassEffect)
private lazy var contractedView: AnyVisualEffectView = {
    let effect = LiquidGlassEffect(style: .regular, isNative: true)
    effect.tintColor = UIColor(white: 0, alpha: 0.2)
    let view = VisualEffectView(effect: effect)
    ...
}()
```

**삭제할 컴포넌트:**
- `blurView` (UIVisualEffectView + UIBlurEffect)
- `tintView` (UIView)
- `highlightLayer` (CAGradientLayer - Specular Highlight)

**최종 구현 스펙 (GlassIconButton과 동일):**

| 항목 | 값 | 비고 |
|------|-----|------|
| **배경** | `LiquidGlassEffect` | LiquidGlassPlatter와 동일 |
| **배경 tintColor** | `UIColor(white: 0, alpha: 0.2)` | 어둡고 투명 |
| **cornerRadius** | capsule: height/2, 기본: defaultCornerRadius | |
| **Specular Highlight** | 없음 | 제거 |
| **Dual State** | contracted ↔ expanded | 유지 |
| **햅틱** | `.light` | 유지 |

**영향받는 버튼 (자동 적용):**

| 파일 | 버튼 | tintColor | useCapsuleStyle |
|------|------|-----------|-----------------|
| `FloatingTabBar.swift` | `deleteButton` | .systemRed | true |
| `FloatingTabBar.swift` | `trashRestoreButton` | .systemBlue | true |
| `FloatingTabBar.swift` | `trashDeleteButton` | .systemRed | true |
| `FloatingTitleBar.swift` | `selectButton` | .systemBlue | true |
| `FloatingTitleBar.swift` | `secondRightButton` | .systemRed | true |
| `LiquidGlassTabBar.swift` | `deleteButton` | .systemRed | true |
| `LiquidGlassTabBar.swift` | `trashRestoreButton` | .systemBlue | true |
| `LiquidGlassTabBar.swift` | `trashDeleteButton` | .systemRed | true |
| `ViewerViewController.swift` | `deleteButton` | .systemRed | false (아이콘) |
| `ViewerViewController.swift` | `restoreButton` | .systemGreen | false (아이콘) |
| `ViewerViewController.swift` | `permanentDeleteButton` | .systemRed | false (아이콘) |
| `ViewerViewController.swift` | `backButton` (iOS 26) | .clear | false (아이콘) |

**Phase 7 실제 변경 내용:**
- GlassButton.swift: UIBlurEffect → LiquidGlassEffect 교체
- ViewerViewController: 아이콘 버튼 → GlassTextButton 텍스트 버튼으로 변경 (iOS 26 스펙)
- ViewerViewController backButton: GlassButton → GlassIconButton (44×44)
- FloatingTabBar/FloatingTitleBar/LiquidGlassTabBar: GlassButton → GlassTextButton

---

## 5. 파일별 변경 요약

| 파일 | 작업 | Phase | 상태 |
|------|------|-------|------|
| `GlassIconButton.swift` | 생성 | 1 | ✅ 완료 |
| `FloatingTitleBar.swift` | 수정 (backButton) | 2a | ✅ 완료 |
| - | 검증 | 2b | ✅ 완료 |
| `FaceComparisonViews.swift` | 수정 (close, cycle) | 2c | ✅ 완료 |
| `GlassCircleButton.swift` | 생성 | 3 | ✅ 완료 |
| `FaceButtonOverlay.swift` | 수정 (toggle, faceButtons) | 4 | ✅ 완료 |
| `GlassTextButton.swift` | 생성 | 5 | ✅ 완료 |
| `FaceComparisonViewController.swift` | 수정 (cancel, delete) | 6 | ✅ 완료 |
| `CleanupProgressView.swift` | 수정 (cancel) | 6 | ✅ 완료 |
| `GlassButton.swift` | 수정 (LiquidGlassEffect 적용) | 7 | ✅ 완료 |
| `ViewerViewController.swift` | 수정 (텍스트 버튼으로 변경, backButton → GlassIconButton) | 7 | ✅ 완료 |
| `FloatingTabBar.swift` | 수정 (GlassTextButton으로 변경) | 7 | ✅ 완료 |
| `FloatingTitleBar.swift` | 수정 (GlassTextButton으로 변경) | 7 | ✅ 완료 |
| `LiquidGlassTabBar.swift` | 수정 (GlassTextButton으로 변경) | 7 | ✅ 완료 |

---

## 6. 테스트 계획

### 6.1. 기능 테스트

| Phase | 테스트 항목 |
|-------|------------|
| 1-2 | 아이콘 버튼 터치, Dual state 애니메이션, 햅틱 |
| 3-4 | 원형 버튼 터치, 얼굴 버튼 동작, 토글 상태 |
| 5-6 | 텍스트 버튼 터치, plain/filled 스타일 |

### 6.2. 시각적 테스트

| 항목 | 확인 내용 |
|------|----------|
| 다크/라이트 모드 | 버튼 배경색, 아이콘/텍스트 색상 |
| 다양한 배경 | 사진 위, 영상 위, 블러 배경 위 |
| 크기 일관성 | small/medium/large |

---

## 7. 롤백 계획

각 Phase 시작 전 Git 커밋 필수.

```bash
# Phase 시작 전
git commit -m "chore: before Phase N - Glass Button 구현"

# 문제 발생 시
git revert HEAD
```

---

## 변경 이력

| 날짜 | 변경 내용 |
|------|-----------|
| 2026-01-28 | 초안 작성 - 버튼 목록 및 적용 판단 |
| 2026-01-28 | 파일 구조 확정 (옵션 A) 및 구현 계획 추가 |
| 2026-01-28 | VideoControlsOverlay 제외 (iOS 26에서도 Glass 없음) |
| 2026-01-28 | faceButtons[] 모든 iOS 버전 동일 적용으로 명시 |
| 2026-01-28 | FaceComparison cancel/deleteButton 모든 iOS 버전 동일 적용 |
| 2026-01-28 | Phase 2 분리 (2a→2b검증→2c) - 조기 검증 포인트 추가 |
| 2026-01-28 | **iOS 26 버튼 실측 스펙 추가** (ButtonInspector로 측정) |
| 2026-01-28 | 얼굴 비교 화면 취소/삭제 버튼 스펙 추가 (Grid 텍스트 버튼과 동일) |
| 2026-01-28 | `emptyTrashButton` 미사용으로 확인, 적용 목록에서 제외 |
| 2026-01-28 | 얼굴 비교 타이틀바 버튼 스펙 추가 (닫기=뒤로가기, 다음인물=눈모양과 동일) |
| 2026-01-28 | 자동 정리 취소 버튼 스펙 추가 (텍스트 버튼 동일 스펙) |
| 2026-01-28 | **Phase 1~2b 완료**: GlassIconButton 구현 및 backButton 적용 |
| 2026-01-28 | GlassIconButton 최종 스펙: LiquidGlassEffect, iconSize 22pt, weight .light, tintColor .white |
| 2026-01-28 | Phase 2c~6 구현 계획을 GlassIconButton 스펙 기준으로 통일 |
| 2026-01-28 | GlassCircleButton, GlassTextButton 구현 스펙 상세화 |
| 2026-01-29 | **Phase 7 완료 후 추가 수정** - 아래 참조 |

---

## 8. Phase 7 완료 후 추가 수정 (2026-01-29)

### 8.1. FaceButton (+버튼) 스타일 변경

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| **아이콘** | `plus.circle.fill` (흰 원 + 아이콘) | `plus` (아이콘만) |
| **버튼 크기** | 44×44 (.medium) | **34×34** (.mini) |
| **아이콘 크기** | 22pt | **18pt** |
| **아이콘 굵기** | .light | **.semibold** (약 1.5배) |
| **cornerRadius** | 22 | **17** |

**GlassCircleButton에 `.mini` Size 추가:**
```swift
enum Size {
    case mini    // 34×34, 아이콘 18pt, .semibold
    case small   // 36×36, 아이콘 14pt, .light
    case medium  // 44×44, 아이콘 22pt, .light
    case large   // 56×56, 아이콘 22pt, .light
}
```

### 8.2. 눈버튼 (토글) 크기 통일

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| **크기** | .small (36×36) | **.medium** (44×44) |
| **여백** | top: 16, trailing: -16 | 동일 (뒤로가기 버튼과 일치) |

### 8.3. 뷰어 휴지통 아이콘 통일

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| **아이콘** | `trash.fill` (채워진) | `trash` (outline) |
| **사유** | iOS 26 시스템 `.trash`와 동일하게 통일 | |

### 8.4. 얼굴 비교 화면 삭제 버튼 스타일 통일

| 항목 | 변경 전 | 변경 후 |
|------|---------|---------|
| **Style** | `.filled` (빨간 배경) | `.plain` (글씨만 빨간색) |
| **사유** | 다른 삭제 버튼들과 스타일 통일 | |

### 8.5. 수정된 파일 목록

| 파일 | 수정 내용 |
|------|----------|
| `GlassCircleButton.swift` | `.mini` Size 추가 (34×34, 18pt, .semibold) |
| `FaceButtonOverlay.swift` | FaceButton: `.mini` 사용, 아이콘 `plus`, Constants 34pt |
| `FaceButtonOverlay.swift` | toggleButton: `.small` → `.medium` (44×44) |
| `ViewerViewController.swift` | deleteButton 아이콘: `trash.fill` → `trash` |
| `FaceComparisonViewController.swift` | deleteButton: `.filled` → `.plain` |

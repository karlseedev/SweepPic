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

## 1. 전체 버튼 목록 및 Liquid Glass 적용 판단

### 1.1. FloatingTabBar (하단 탭바) - iOS 16~25
**파일**: `Shared/Components/FloatingTabBar.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `photosButton` | UIButton | 아이콘+텍스트 수직 | 보관함 탭 | ❌ | 탭바 구현 완료 (Plan1) |
| `albumsButton` | UIButton | 아이콘+텍스트 수직 | 앨범 탭 | ❌ | 탭바 구현 완료 (Plan1) |
| `trashButton` | UIButton | 아이콘+텍스트 수직 | 휴지통 탭 | ❌ | 탭바 구현 완료 (Plan1) |
| `emptyTrashButton` | UIButton | 원형 아이콘 | 휴지통 비우기 | ✅ | 원형 Glass 버튼으로 변경 |
| `deleteButton` | GlassButton | Capsule+텍스트 | Select 삭제 | ✅ 완료 | 이미 적용됨 |
| `trashRestoreButton` | GlassButton | Capsule+텍스트 | Trash 복구 | ✅ 완료 | 이미 적용됨 |
| `trashDeleteButton` | GlassButton | Capsule+텍스트 | Trash 영구삭제 | ✅ 완료 | 이미 적용됨 |

---

### 1.2. FloatingTitleBar (상단 타이틀바) - iOS 16~25
**파일**: `Shared/Components/FloatingTitleBar.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `backButton` | UIButton | 아이콘만 (chevron.left) | 뒤로가기 | ✅ | 아이콘 Glass 버튼으로 변경 |
| `selectButton` | GlassButton | Capsule+텍스트 | Select 모드 | ✅ 완료 | 이미 적용됨 |
| `secondRightButton` | GlassButton | Capsule+텍스트 | 비우기/커스텀 | ✅ 완료 | 이미 적용됨 |

---

### 1.3. LiquidGlassTabBar - iOS 26+
**파일**: `Shared/Components/LiquidGlassTabBar.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `tabButtons[0~2]` | LiquidGlassTabButton | 아이콘+레이블 수직 | 탭 선택 | ✅ 완료 | 이미 적용됨 |
| `deleteButton` | GlassButton | Capsule+텍스트 | Select 삭제 | ✅ 완료 | 이미 적용됨 |
| `trashRestoreButton` | GlassButton | Capsule+텍스트 | Trash 복구 | ✅ 완료 | 이미 적용됨 |
| `trashDeleteButton` | GlassButton | Capsule+텍스트 | Trash 영구삭제 | ✅ 완료 | 이미 적용됨 |

---

### 1.4. ViewerViewController (전체화면 뷰어)
**파일**: `Features/Viewer/ViewerViewController.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `deleteButton` | GlassButton | 아이콘 56×56 | 사진 삭제 | ✅ 완료 | 이미 적용됨 |
| `restoreButton` | GlassButton | 아이콘 56×56 | 복구 | ✅ 완료 | 이미 적용됨 |
| `permanentDeleteButton` | GlassButton | 아이콘 56×56 | 영구삭제 | ✅ 완료 | 이미 적용됨 |
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
| `toggleButton` | UIButton | 36×36 아이콘 | 표시/숨김 토글 | ✅ | iOS 16-25 전용 (iOS 26은 NavBar) |
| `faceButtons[]` | FaceButton | 44pt 원형 | 얼굴 비교 진입 | ✅ | **모든 iOS 버전** 동일 적용 |

---

### 1.7. FaceComparisonViews (얼굴 비교 타이틀바)
**파일**: `Features/SimilarPhoto/UI/FaceComparisonViews.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `closeButton` | UIButton | 아이콘만 (xmark) | 닫기 | ✅ | 아이콘 Glass 버튼으로 변경 |
| `cycleButton` | UIButton | 아이콘만 | 다음 인물 | ✅ | 아이콘 Glass 버튼으로 변경 |

---

### 1.8. FaceComparisonViewController (얼굴 비교)
**파일**: `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `cancelButton` | UIButton | 텍스트만 | 취소 | ✅ | **모든 iOS 버전** 동일 적용 |
| `deleteButton` | UIButton | 텍스트+배경색 | 삭제 | ✅ | **모든 iOS 버전** 동일 적용 |

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
| `cancelButton` | UIButton | 텍스트만 | 정리 취소 | ✅ | GlassButton (selectButton과 동일) |

---

## 2. 적용 판단 요약

### 2.1. 상태별 집계

| 상태 | 버튼 수 | 설명 |
|------|--------|------|
| ✅ 완료 | 12개 | GlassButton, LiquidGlassTabButton 이미 적용 |
| ✅ 적용 예정 | 9개 | 새로 Liquid Glass 적용 필요 |
| ❌ 적용 안함 | 7개 | iOS 26 전용, 디버그용, 시스템 스타일 등 |

### 2.2. 적용 예정 버튼 목록

| 버튼명 | 파일 | 변경할 타입 | iOS 버전 |
|--------|------|------------|----------|
| `emptyTrashButton` | FloatingTabBar | 원형 Glass | 16-25 |
| `backButton` | FloatingTitleBar | 아이콘 Glass | 16-25 |
| `toggleButton` | FaceButtonOverlay | 원형 Glass | 16-25 |
| `faceButtons[]` | FaceButtonOverlay | 원형 Glass | **전체** |
| `closeButton` | FaceComparisonViews | 아이콘 Glass | 16-25 |
| `cycleButton` | FaceComparisonViews | 아이콘 Glass | 16-25 |
| `cancelButton` | FaceComparisonViewController | 텍스트 Glass | **전체** |
| `deleteButton` | FaceComparisonViewController | 텍스트 Glass | **전체** |
| `cancelButton` | CleanupProgressView | GlassButton (selectButton과 동일) | 16-25 |

### 2.3. 적용 안함 버튼 목록

| 버튼명 | 파일 | 이유 |
|--------|------|------|
| `photosButton` | FloatingTabBar | 탭바 구현 완료 (Plan1) |
| `albumsButton` | FloatingTabBar | 탭바 구현 완료 (Plan1) |
| `trashButton` | FloatingTabBar | 탭바 구현 완료 (Plan1) |
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
| `GlassCircleButton.swift` | emptyTrashButton, toggleButton, faceButtons[] | 3개 |
| `GlassTextButton.swift` | cancelButton(2), deleteButton | 3개 |

---

## 4. 구현 계획

### Phase 1: GlassIconButton 구현

**목표:** 아이콘 전용 Liquid Glass 버튼 클래스 생성

**생성 파일:** `Shared/Components/GlassIconButton.swift`

**클래스 설계:**
```swift
final class GlassIconButton: UIButton {

    enum Size {
        case small   // 36×36, 아이콘 18pt
        case medium  // 44×44, 아이콘 22pt
        case large   // 56×56, 아이콘 28pt
    }

    init(icon: String, size: Size = .medium, tintColor: UIColor = .white)

    func setIcon(_ icon: String, animated: Bool = false)
}
```

**포함 기능:**
- Dual state (contracted ↔ expanded)
- LiquidGlassEffect 적용
- 햅틱 피드백 (.light)
- 아이콘 변경 메서드 (토글용)

---

### Phase 2a: GlassIconButton 첫 적용 (backButton)

**목표:** backButton 하나만 먼저 적용하여 기본 동작 검증

**변경 파일 및 버튼:**

| 파일 | 버튼 | 크기 | 아이콘 |
|------|------|------|--------|
| `FloatingTitleBar.swift` | `backButton` | .medium | chevron.left |

---

### Phase 2b: ✅ 검증

**목표:** GlassIconButton 기본 동작 확인

**확인 방법:**
1. 앱 실행 → 앨범 탭 → 아무 앨범 선택
2. 좌상단 **뒤로가기 버튼** 확인

**검증 항목:**
- [ ] Liquid Glass 배경 효과 표시
- [ ] 버튼 터치 시 햅틱 피드백
- [ ] 버튼 동작 (뒤로가기) 정상
- [ ] 다양한 배경(사진)에서 굴절 효과 확인

**통과 시:** Phase 2c 진행
**실패 시:** Phase 1 수정 후 재검증

---

### Phase 2c: GlassIconButton 나머지 적용

**목표:** 검증된 GlassIconButton을 나머지 버튼에 적용

**변경 파일 및 버튼:**

| 파일 | 버튼 | 크기 | 아이콘 |
|------|------|------|--------|
| `FaceComparisonViews.swift` | `closeButton` | .medium | xmark |
| `FaceComparisonViews.swift` | `cycleButton` | .medium | arrow.trianglehead.2.clockwise.rotate.90 |

---

### Phase 3: GlassCircleButton 구현

**목표:** 원형 Liquid Glass 버튼 클래스 생성

**생성 파일:** `Shared/Components/GlassCircleButton.swift`

**클래스 설계:**
```swift
final class GlassCircleButton: UIButton {

    enum Size {
        case small   // 36pt 지름
        case medium  // 44pt 지름
        case large   // 56pt 지름
    }

    init(icon: String, size: Size = .medium, tintColor: UIColor = .white)

    func setIcon(_ icon: String, animated: Bool = false)
}
```

**포함 기능:**
- 원형 레이아웃 (cornerRadius = height/2)
- Dual state (contracted ↔ expanded)
- LiquidGlassEffect 적용
- 햅틱 피드백 (.light)

---

### Phase 4: GlassCircleButton 적용

**목표:** 기존 버튼을 GlassCircleButton으로 교체

**변경 파일 및 버튼:**

| 파일 | 버튼 | 크기 | 아이콘 | iOS 버전 |
|------|------|------|--------|----------|
| `FloatingTabBar.swift` | `emptyTrashButton` | .medium | trash | 16-25 |
| `FaceButtonOverlay.swift` | `toggleButton` | .small | eye.fill / eye.slash.fill | 16-25 |
| `FaceButtonOverlay.swift` | `faceButtons[]` | .medium | plus.circle.fill | **전체** |

**추가 작업:**
- `FaceButton` 클래스를 `GlassCircleButton`으로 교체
- faceButtons[]는 iOS 분기 없이 모든 버전에서 동일하게 Liquid Glass 적용

---

### Phase 5: GlassTextButton 구현

**목표:** 텍스트 전용 Liquid Glass 버튼 클래스 생성

**생성 파일:** `Shared/Components/GlassTextButton.swift`

**클래스 설계:**
```swift
final class GlassTextButton: UIButton {

    enum Style {
        case plain      // 텍스트만 (취소)
        case filled     // 배경색 있음 (삭제)
    }

    init(title: String, style: Style = .plain, tintColor: UIColor = .white)

    func setTitle(_ title: String, animated: Bool = false)
}
```

**포함 기능:**
- plain: 텍스트만, 투명 배경
- filled: 텍스트 + 배경색 (systemRed, systemBlue 등)
- Dual state (contracted ↔ expanded)
- LiquidGlassEffect 적용
- 햅틱 피드백 (plain: 없음, filled: .medium)

---

### Phase 6: GlassTextButton 적용 및 CleanupProgressView 수정

**목표:** 기존 UIButton을 GlassTextButton 또는 GlassButton으로 교체

**변경 파일 및 버튼:**

| 파일 | 버튼 | 변경 타입 | iOS 버전 |
|------|------|----------|----------|
| `FaceComparisonViewController.swift` | `cancelButton` | GlassTextButton(.plain) | **전체** |
| `FaceComparisonViewController.swift` | `deleteButton` | GlassTextButton(.filled) | **전체** |
| `CleanupProgressView.swift` | `cancelButton` | GlassButton | 16-25 |

---

## 5. 파일별 변경 요약

| 파일 | 작업 | Phase |
|------|------|-------|
| `GlassIconButton.swift` | 생성 | 1 |
| `FloatingTitleBar.swift` | 수정 (backButton) | 2a |
| - | ✅ 검증 | 2b |
| `FaceComparisonViews.swift` | 수정 (close, cycle) | 2c |
| `GlassCircleButton.swift` | 생성 | 3 |
| `FloatingTabBar.swift` | 수정 (emptyTrash) | 4 |
| `FaceButtonOverlay.swift` | 수정 (toggle, faceButtons) | 4 |
| `GlassTextButton.swift` | 생성 | 5 |
| `FaceComparisonViewController.swift` | 수정 (cancel, delete) | 6 |
| `CleanupProgressView.swift` | 수정 (cancel) | 6 |

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

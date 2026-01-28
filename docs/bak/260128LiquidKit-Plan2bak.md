# LiquidGlassKit 일반 버튼 적용 계획

**작성일**: 2026-01-28
**버전**: v1
**관련 문서**: [260127LiquidKit-Plan1.md](./260127LiquidKit-Plan1.md)

---

## 1. 현재 버튼 현황

### 1.1. 이미 Liquid Glass 적용된 버튼

| 클래스 | 위치 | 상태 |
|--------|------|------|
| `GlassButton` | Shared/Components/ | ✅ LiquidGlassKit 적용 완료 |
| `LiquidGlassTabButton` | Shared/Components/ | ✅ Liquid Glass 스타일 |

### 1.2. 변환 대상 버튼 목록

#### 그룹 A: 비디오 컨트롤 버튼
| 버튼명 | 파일 | 스타일 | 용도 |
|--------|------|--------|------|
| `playPauseButton` | VideoControlsOverlay.swift | 아이콘 22pt | 재생/일시정지 |
| `muteButton` | VideoControlsOverlay.swift | 아이콘 22pt | 음소거 토글 |

#### 그룹 B: 얼굴 관련 버튼
| 버튼명 | 파일 | 스타일 | 용도 |
|--------|------|--------|------|
| `toggleButton` | FaceButtonOverlay.swift | 36×36 아이콘 | 얼굴 버튼 표시/숨김 |
| `faceButtons[]` | FaceButtonOverlay.swift | 44pt 원형 | 얼굴 비교 진입 |
| `closeButton` | FaceComparisonViews.swift | 아이콘만 | 닫기 |
| `cycleButton` | FaceComparisonViews.swift | 아이콘만 | 다음 인물 |

#### 그룹 C: 네비게이션/액션 버튼
| 버튼명 | 파일 | 스타일 | 용도 |
|--------|------|--------|------|
| `backButton` | FloatingTitleBar.swift | 아이콘만 | 뒤로가기 |
| `cancelButton` | FaceComparisonViewController.swift | 텍스트만 | 취소 |
| `cancelButton` | CleanupProgressView.swift | 텍스트만 | 정리 취소 |
| `deleteButton` | FaceComparisonViewController.swift | 텍스트+배경 | 삭제 |
| `actionButton` | PermissionViewController.swift | 텍스트+배경 | 권한 요청 |

---

## 2. 버튼 그룹화 및 파일 구조 계획

### 2.1. 새로 생성할 파일

| 파일명 | 역할 | 포함 버튼 스타일 |
|--------|------|-----------------|
| `GlassIconButton.swift` | 아이콘만 있는 Liquid Glass 버튼 | 비디오 컨트롤, 닫기, 뒤로가기 등 |
| `GlassCircleButton.swift` | 원형 Liquid Glass 버튼 | 얼굴 + 버튼, 토글 버튼 |
| `GlassTextButton.swift` | 텍스트만 있는 Liquid Glass 버튼 | 취소, 확인 등 |

### 2.2. 기존 파일 수정

| 파일명 | 변경 내용 |
|--------|----------|
| `GlassButton.swift` | 기존 유지 (Capsule 스타일, 아이콘+텍스트) |

### 2.3. 최종 Liquid Glass 버튼 체계

```
Shared/Components/
├── GlassButton.swift          # Capsule 스타일 (기존, 아이콘+텍스트)
├── GlassIconButton.swift      # 아이콘만 (NEW)
├── GlassCircleButton.swift    # 원형 (NEW)
└── GlassTextButton.swift      # 텍스트만 (NEW)
```

---

## 3. 버튼 클래스 상세 설계

### 3.1. GlassIconButton (아이콘 전용)

**용도:** 비디오 컨트롤, 네비게이션, 닫기 등

**속성:**
```swift
final class GlassIconButton: UIButton {

    enum Size {
        case small   // 36×36, 아이콘 18pt
        case medium  // 44×44, 아이콘 22pt
        case large   // 56×56, 아이콘 28pt
    }

    // 초기화
    init(
        icon: String,           // SF Symbol 이름
        size: Size = .medium,
        tintColor: UIColor = .white
    )

    // 아이콘 변경 (토글용)
    func setIcon(_ icon: String, animated: Bool)
}
```

**적용 대상:**
| 버튼 | 크기 | 아이콘 |
|------|------|--------|
| `playPauseButton` | .medium | play.fill / pause.fill |
| `muteButton` | .medium | speaker.fill / speaker.slash.fill |
| `backButton` | .medium | chevron.left |
| `closeButton` | .medium | xmark |
| `cycleButton` | .medium | arrow.trianglehead.2.clockwise.rotate.90 |

---

### 3.2. GlassCircleButton (원형)

**용도:** 얼굴 위 + 버튼, 토글 버튼

**속성:**
```swift
final class GlassCircleButton: UIButton {

    enum Size {
        case small   // 36pt 지름
        case medium  // 44pt 지름
        case large   // 56pt 지름
    }

    // 초기화
    init(
        icon: String,
        size: Size = .medium,
        tintColor: UIColor = .white,
        backgroundColor: UIColor = UIColor.black.withAlphaComponent(0.5)
    )

    // 아이콘 변경
    func setIcon(_ icon: String, animated: Bool)
}
```

**적용 대상:**
| 버튼 | 크기 | 아이콘 |
|------|------|--------|
| `faceButtons[]` | .medium | plus.circle.fill |
| `toggleButton` | .small | eye.fill / eye.slash.fill |

---

### 3.3. GlassTextButton (텍스트 전용)

**용도:** 취소, 확인 등 텍스트 버튼

**속성:**
```swift
final class GlassTextButton: UIButton {

    enum Style {
        case plain      // 텍스트만 (취소)
        case filled     // 배경색 있음 (확인, 삭제)
    }

    // 초기화
    init(
        title: String,
        style: Style = .plain,
        tintColor: UIColor = .systemBlue
    )

    // 타이틀 변경
    func setTitle(_ title: String, animated: Bool)
}
```

**적용 대상:**
| 버튼 | 스타일 | 색상 |
|------|--------|------|
| `cancelButton` (FaceComparison) | .plain | .white |
| `cancelButton` (CleanupProgress) | .plain | .white |
| `deleteButton` (FaceComparison) | .filled | .systemRed |
| `actionButton` (Permission) | .filled | .systemBlue |

---

## 4. 공통 Liquid Glass 효과

### 4.1. Dual State 패턴 (GlassButton과 동일)

모든 Glass 버튼 클래스에 적용:

```swift
// 공통 프로토콜
protocol GlassButtonProtocol {
    var contractedView: UIView { get }      // resting 상태
    var expandedView: AnyVisualEffectView { get }  // pressed 상태
    var feedbackGenerator: UIImpactFeedbackGenerator { get }

    func expandButton(animated: Bool)
    func contractButton(animated: Bool)
}
```

### 4.2. 햅틱 피드백

| 버튼 타입 | 햅틱 스타일 |
|----------|------------|
| GlassIconButton | .light |
| GlassCircleButton | .light |
| GlassTextButton (plain) | 없음 |
| GlassTextButton (filled) | .medium |

### 4.3. 애니메이션 파라미터

```swift
// 확장 애니메이션
duration: 0.4
springDamping: 0.6
scale: 1.15 → 1.0

// 수축 애니메이션
duration: 0.6
springDamping: 0.7
scale: 1.0 → 0.87
```

---

## 5. 구현 계획

### Phase 1: GlassIconButton 구현

**작업 내용:**
1. `GlassIconButton.swift` 파일 생성
2. Dual state + 햅틱 구현
3. Size enum 구현 (small/medium/large)

**변경 파일:**
- 생성: `Shared/Components/GlassIconButton.swift`

---

### Phase 2: VideoControlsOverlay 적용

**작업 내용:**
1. `playPauseButton` → `GlassIconButton` 교체
2. `muteButton` → `GlassIconButton` 교체

**변경 파일:**
- 수정: `Features/Viewer/VideoControlsOverlay.swift`

---

### Phase 3: GlassCircleButton 구현

**작업 내용:**
1. `GlassCircleButton.swift` 파일 생성
2. 원형 레이아웃 + Dual state 구현

**변경 파일:**
- 생성: `Shared/Components/GlassCircleButton.swift`

---

### Phase 4: FaceButtonOverlay 적용

**작업 내용:**
1. `FaceButton` → `GlassCircleButton` 교체
2. `toggleButton` → `GlassCircleButton` 교체

**변경 파일:**
- 수정: `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`

---

### Phase 5: GlassTextButton 구현

**작업 내용:**
1. `GlassTextButton.swift` 파일 생성
2. plain/filled 스타일 구현

**변경 파일:**
- 생성: `Shared/Components/GlassTextButton.swift`

---

### Phase 6: 나머지 버튼 적용

**작업 내용:**
1. `FloatingTitleBar.backButton` → `GlassIconButton`
2. `FaceComparisonViews` 버튼들 → `GlassIconButton`
3. `FaceComparisonViewController` 버튼들 → `GlassTextButton`
4. `CleanupProgressView.cancelButton` → `GlassTextButton`
5. `PermissionViewController.actionButton` → `GlassTextButton`

**변경 파일:**
- `Shared/Components/FloatingTitleBar.swift`
- `Features/SimilarPhoto/UI/FaceComparisonViews.swift`
- `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- `Features/AutoCleanup/UI/CleanupProgressView.swift`
- `Features/Permissions/PermissionViewController.swift`

---

## 6. 파일별 변경 요약

| 파일 | 작업 | Phase |
|------|------|-------|
| `GlassIconButton.swift` | 생성 | 1 |
| `VideoControlsOverlay.swift` | 수정 | 2 |
| `GlassCircleButton.swift` | 생성 | 3 |
| `FaceButtonOverlay.swift` | 수정 | 4 |
| `GlassTextButton.swift` | 생성 | 5 |
| `FloatingTitleBar.swift` | 수정 | 6 |
| `FaceComparisonViews.swift` | 수정 | 6 |
| `FaceComparisonViewController.swift` | 수정 | 6 |
| `CleanupProgressView.swift` | 수정 | 6 |
| `PermissionViewController.swift` | 수정 | 6 |

---

## 7. 테스트 계획

### 7.1. 기능 테스트

| 테스트 항목 | 확인 내용 |
|------------|----------|
| 비디오 컨트롤 | 재생/정지, 음소거 토글, Liquid Glass 효과 |
| 얼굴 버튼 | + 버튼 터치, 토글 버튼, 확장/수축 애니메이션 |
| 텍스트 버튼 | 취소/확인 동작, 색상 스타일 |
| 햅틱 피드백 | 각 버튼 타입별 피드백 강도 |

### 7.2. 시각적 테스트

| 테스트 항목 | 확인 내용 |
|------------|----------|
| 다크/라이트 모드 | 버튼 배경색, 아이콘 색상 |
| 다양한 배경 | 사진 위, 영상 위, 블러 배경 위 |
| 크기 일관성 | small/medium/large 크기 비교 |

---

## 8. 리스크 및 대응

| 리스크 | 대응 |
|--------|------|
| 기존 버튼 동작 변경 | 각 Phase별 테스트 후 다음 진행 |
| 성능 이슈 (Metal) | 비디오 재생 중 GPU 부하 모니터링 |
| 접근성 저하 | 기존 accessibilityLabel 유지 |

---

## 9. 롤백 계획

각 Phase 시작 전 Git 커밋 필수.

```bash
# Phase 시작 전
git add . && git commit -m "chore: before Phase N - Glass Button 적용"

# 문제 발생 시 롤백
git revert HEAD
```

---

## 변경 이력

| 날짜 | 변경 내용 |
|------|-----------|
| 2026-01-28 | 초안 작성 |

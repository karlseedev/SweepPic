# LiquidGlassKit 일반 버튼 적용 계획

**작성일**: 2026-01-28
**버전**: v1
**관련 문서**: [260127LiquidKit-Plan1.md](./260127LiquidKit-Plan1.md)

---

## 1. 전체 버튼 목록 및 Liquid Glass 적용 판단

### 1.1. FloatingTabBar (하단 탭바) - iOS 16~25
**파일**: `Shared/Components/FloatingTabBar.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `photosButton` | UIButton | 아이콘+텍스트 수직 | 보관함 탭 | ❌ | iOS 26에서는 LiquidGlassTabBar 사용 |
| `albumsButton` | UIButton | 아이콘+텍스트 수직 | 앨범 탭 | ❌ | iOS 26에서는 LiquidGlassTabBar 사용 |
| `trashButton` | UIButton | 아이콘+텍스트 수직 | 휴지통 탭 | ❌ | iOS 26에서는 LiquidGlassTabBar 사용 |
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
| `playPauseButton` | UIButton | 아이콘 22pt | 재생/일시정지 | ✅ | 아이콘 Glass 버튼으로 변경 |
| `muteButton` | UIButton | 아이콘 22pt | 음소거 토글 | ✅ | 아이콘 Glass 버튼으로 변경 |

---

### 1.6. FaceButtonOverlay (얼굴 버튼)
**파일**: `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`

| 버튼명 | 현재 타입 | 스타일 | 용도 | LG 적용 | 비고 |
|--------|----------|--------|------|---------|------|
| `toggleButton` | UIButton | 36×36 아이콘 | 표시/숨김 토글 | ✅ | 원형 Glass 버튼으로 변경 |
| `faceButtons[]` | FaceButton | 44pt 원형 | 얼굴 비교 진입 | ✅ | 원형 Glass 버튼으로 변경 |

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
| `cancelButton` | UIButton | 텍스트만 | 취소 | ✅ | 텍스트 Glass 버튼으로 변경 |
| `deleteButton` | UIButton | 텍스트+배경색 | 삭제 | ✅ | 텍스트 Glass 버튼으로 변경 |

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
| `cancelButton` | UIButton | 텍스트만 | 정리 취소 | ✅ | 텍스트 Glass 버튼으로 변경 |

---

## 2. 적용 판단 요약

### 2.1. 상태별 집계

| 상태 | 버튼 수 | 설명 |
|------|--------|------|
| ✅ 완료 | 12개 | GlassButton, LiquidGlassTabButton 이미 적용 |
| ✅ 적용 예정 | 11개 | 새로 Liquid Glass 적용 필요 |
| ❌ 적용 안함 | 5개 | iOS 26 전용, 디버그용, 시스템 스타일 등 |

### 2.2. 적용 예정 버튼 목록

| 버튼명 | 파일 | 변경할 타입 |
|--------|------|------------|
| `emptyTrashButton` | FloatingTabBar | 원형 Glass |
| `backButton` | FloatingTitleBar | 아이콘 Glass |
| `playPauseButton` | VideoControlsOverlay | 아이콘 Glass |
| `muteButton` | VideoControlsOverlay | 아이콘 Glass |
| `toggleButton` | FaceButtonOverlay | 원형 Glass |
| `faceButtons[]` | FaceButtonOverlay | 원형 Glass |
| `closeButton` | FaceComparisonViews | 아이콘 Glass |
| `cycleButton` | FaceComparisonViews | 아이콘 Glass |
| `cancelButton` | FaceComparisonViewController | 텍스트 Glass |
| `deleteButton` | FaceComparisonViewController | 텍스트 Glass |
| `cancelButton` | CleanupProgressView | 텍스트 Glass |

### 2.3. 적용 안함 버튼 목록

| 버튼명 | 파일 | 이유 |
|--------|------|------|
| `photosButton` | FloatingTabBar | iOS 26에서는 LiquidGlassTabBar 사용 |
| `albumsButton` | FloatingTabBar | iOS 26에서는 LiquidGlassTabBar 사용 |
| `trashButton` | FloatingTabBar | iOS 26에서는 LiquidGlassTabBar 사용 |
| `debugAnalyzeButton` | ViewerViewController | DEBUG 전용 |
| `actionButton` | PermissionViewController | 시스템 스타일 유지 |

---

## 3. 구현 계획

(추후 작성 예정)

---

## 변경 이력

| 날짜 | 변경 내용 |
|------|-----------|
| 2026-01-28 | 초안 작성 - 버튼 목록 및 적용 판단 |

# false 카테고리 로그 삭제 계획 (검토 반영 v2)

## 완료 (2026-02-20)

- **삭제**: ~488개 Log.print/Log.debug 호출 삭제 (57개 파일)
- **Log.swift 정리**: false 카테고리 75개 제거 (true 32개만 잔존), 미사용 메서드 4개 삭제
- **경고 해소**: 로그 전용 변수 16건 삭제 → Xcode 경고 0건
- **빌드**: Xcode BUILD SUCCEEDED (경고 0, 에러 0)
- **커밋**: `66f857a` → `2506a3e` → `3721301` → `d3f1530` → `fefaaf4` → `bc3cba4` → `ce022b9` → `3f64700` → `533aaa9` → `23b2682`

---

## Context

Log 시스템 리팩토링(Log.swift → Apple Logger 마이그레이션)의 **선행 작업**으로, 현재 비활성 로그 호출을 먼저 삭제한다. 삭제 후 남는 true 카테고리 로그만 Logger로 마이그레이션하면 작업량이 절반 이하로 줄어든다.

**정책**: 완전 삭제. git history에 보존되므로 필요 시 복원 가능.

---

## 검토에서 발견된 문제 3가지

### 문제 1: 미등록 카테고리가 기존 추정(~18개)보다 훨씬 많음

Log.swift에 등록되지 않은 카테고리가 **42종, ~80호출** 추가 발견됨.
주요 누락 파일:
- `CleanupPreviewService.swift` (13호출, PreviewService)
- `LiquidGlassTabBar.swift` (9호출)
- `AutoScrollTester.swift` (7호출)
- `SupabaseProvider.swift` (5호출)
- `FaceComparisonViewController.swift` 내 미등록 추가 (7호출)
- `PhotoCell.swift` 내 미등록 추가 (4호출)
- 기타 10개 파일

→ **해결**: 미등록 카테고리를 별도 Phase로 분리하지 않고, 해당 기능 영역 Phase에 통합.

### 문제 2: 로그 전용 변수 삭제 누락 위험

타이밍 측정용 변수(`startTime`, `stateUpdateTime` 등)가 로그 출력에만 사용되는 곳이 다수.
로그만 삭제하면 **unused variable 경고** 발생.

영향 파일:
- `TrashStore.swift` — `startTime`, `stateUpdateTime`, `saveTime`, `notifyTime`
- `TrashAlbumViewController.swift` — `startTime`, `fetchTime`, `reloadStartTime`, `reloadTime`, `endTime` (2개 메서드)
- `GridViewController.swift` — `startTime`, `trashStoreTime`, `uiUpdateTime`

→ **해결**: 각 Phase에 "함께 삭제할 변수" 명시.

### 문제 3: debugOverlayEnabled 연쇄 삭제

`PhotoPageViewController.swift`의 `debugOverlayEnabled` 프로퍼티가 `false`가 되면, 이를 사용하는 `debugAssetLabel` 관련 코드(UI 생성, constraint)도 dead code가 됨.

→ **해결**: Phase 4에서 `debugOverlayEnabled` + `debugAssetLabel` + 관련 if 블록 함께 삭제.

---

## 삭제 대상 총괄 (수정)

| 구분 | 파일 수 | 삭제 호출 수 |
|------|---------|-------------|
| Phase 1: AppCore | 8 | ~61 |
| Phase 2: Grid | 12 | ~75 |
| Phase 3: Albums/Permissions/Cleanup | 5 | ~62 |
| Phase 4: Viewer | 6 | ~80 |
| Phase 5: SimilarPhoto | 10 | ~80 |
| Phase 6: Shared/Navigation/App/Debug | 20 | ~108 |
| Phase 7: Log.swift 정리 | 1 | - |
| **합계** | **~57** | **~466** |

---

## 삭제 규칙

### R1. 단순 삭제
```swift
Log.print("[GridViewController] something")  // ← 줄 삭제
```

### R2. guard/if 안의 로그 — 로그만 삭제, 흐름 유지
```swift
guard someCondition else {
    Log.print("[TrashStore] error")  // ← 이 줄만 삭제
    return                           // ← return 유지
}
```

### R3. 로그가 유일 구문인 if 블록 — 블록 전체 삭제
```swift
// 전체 삭제:
if someCondition {
    Log.print("[GridViewController] something")
}
```

### R4. 로그 전용 변수 — 변수도 함께 삭제
```swift
let elapsed = Date().timeIntervalSince(startTime)  // ← 함께 삭제
Log.print("[Timing] elapsed: \(elapsed)")           // ← 삭제
```

### R5. Log.categories[] 기능 분기 — 대체 처리
삭제가 아닌 코드 변경 (3곳).

### R6. FileLogger.logThumbEnabled 분기 내 로그 — 분기 포함 삭제
`FileLogger.logThumbEnabled`는 하드코딩 `false`이므로 해당 if문 내부의 로그 코드 삭제.

### R7. switch case 내 로그-only — `break`로 대체
```swift
// AS-IS
case .burst(let burstDuration, let restDuration, let restSpeedRatio):
    Log.print("[AutoScroll] 프로파일: burst...")  // ← 유일 구문
// TO-BE
case .burst:
    break
```
로그가 case의 유일한 구문이면, 삭제 후 빈 case가 되어 컴파일 에러. `break`로 대체.

---

## Phase 0: 사전 커밋

현재 변경사항 커밋 (롤백 포인트).

---

## Phase 1: AppCore (8파일, ~61호출)

| 파일 | 호출 수 | 규칙 | 특이사항 |
|------|---------|------|---------|
| `Sources/AppCore/Stores/TrashStore.swift` | 15 | R1+R2+**R4** | `startTime`, `stateUpdateTime`, `saveTime`, `notifyTime` 변수 함께 삭제 |
| `Sources/AppCore/Services/ThumbnailCache.swift` | 11 | R1 | `#if false` 블록(line 135-144)도 삭제 |
| `Sources/AppCore/Services/ImagePipeline.swift` | 10 | R1+R6 | line 446 FileLogger 분기 내 로그 포함 |
| `Sources/AppCore/Services/AlbumService.swift` | 9 | R1 | |
| `Sources/AppCore/Stores/AppStateStore.swift` | 6 | R1 | |
| `Sources/AppCore/Services/VideoPipeline.swift` | 6 | R1 | |
| `Sources/AppCore/Services/PhotoLibraryService.swift` | 2 | R1 | |
| `Sources/AppCore/Services/MemoryThumbnailCache.swift` | 2 | R1 | |

검증: `swift build`
커밋: `refactor: AppCore false 카테고리 로그 삭제`

---

## Phase 2: Grid (12파일, ~75호출)

| 파일 | 호출 수 | 규칙 | 특이사항 |
|------|---------|------|---------|
| `GridViewController.swift` | 16 | R1+**R4** | `startTime`, `trashStoreTime`, `uiUpdateTime` 함께 삭제. 미등록 `[GridViewController.Timing]` 1개 포함 |
| `GridScroll.swift` | 14+4 | R1+R6 | 등록 false 14개 + FileLogger 분기 내 미등록 4개(`R2:Timing`, `R2`, `Thumb:Check`, `Preheat:Decel`) |
| `BaseSelectMode.swift` | 13 | R1+R2 | guard-return 패턴 주의 (line 78, 150) |
| `GridDataSourceDriver.swift` | 8 | R1+**R4** | `startTime`, `elapsed` 변수 함께 삭제 (buildCache 메서드) |
| `GridSelectMode.swift` | 5 | R1 | |
| `PhotoCell.swift` | 1+4 | R1+R6 | 등록 `GridStats` 1개 + 미등록 `PhotoCell` 4개 + FileLogger 분기 내 `Thumb:Req`/`Thumb:Res` 2개 |
| `BaseGridViewController+PinchZoom.swift` | 3 | R1 | |
| `BaseGridViewController.swift` | 1 | R1 | |
| `GridGestures.swift` | 1 | R1 | |
| `SelectionManager.swift` | 1 | R1 | |
| `GridViewController+Cleanup.swift` | 1 | R1 | 미등록 `PreviewCleanup` |
| `GridViewController+SimilarPhoto.swift` | 0 | - | [SimilarPhoto]는 true → 이 Phase에서 건드리지 않음 |

검증: Xcode 빌드
커밋: `refactor: Grid false 카테고리 로그 삭제`

---

## Phase 3: Albums + Permissions + AutoCleanup Preview (5파일, ~62호출)

| 파일 | 호출 수 | 규칙 | 특이사항 |
|------|---------|------|---------|
| `TrashAlbumViewController.swift` | 24 | R1+**R4** | 2개 메서드에서 타이밍 변수 함께 삭제 (`startTime`, `fetchTime`, `reloadStartTime`, `reloadTime`, `endTime`, `trashStoreTime`) |
| `CleanupPreviewService.swift` | 13 | R1 | 미등록 `PreviewService` 전부 |
| `AlbumGridViewController.swift` | 10 | R1 | |
| `PermissionViewController.swift` | 9 | R1 | |
| `TrashSelectMode.swift` | 6 | R1 | |

검증: Xcode 빌드
커밋: `refactor: Albums/Permissions/Preview false 카테고리 로그 삭제`

---

## Phase 4: Viewer (6파일, ~80호출) — 가장 주의 필요

### 일반 삭제

| 파일 | 호출 수 | 규칙 | 특이사항 |
|------|---------|------|---------|
| `VideoPageViewController.swift` | 27 | R1+**R5** | line 310-315 `Log.categories["Video"]` 블록 전체 삭제 (callStack 포함) |
| `PhotoPageViewController.swift` | 24 | R1+**R5** | 아래 상세 참고 |
| `VideoControlsOverlay.swift` | 10 | R1 | |
| `ViewerViewController+SimilarPhoto.swift` | 7 | R1 | |
| `ViewerViewController.swift` | 5 | R1+**R5** | 아래 상세 참고 |
| `ViewerCoordinator.swift` | 1 | R1 | 미등록 `ViewerCoordinator` |

### 기능 분기 특별 처리 3곳

**1. PhotoPageViewController.swift** (R5)
- line 126-128: `debugOverlayEnabled` 프로퍼티 → `private let debugOverlayEnabled = false`로 변경
- line 289-299: `if debugOverlayEnabled { ... }` 블록 전체 삭제 (debugAssetLabel 추가 + constraint)
- `debugAssetLabel` lazy 프로퍼티: 위 블록에서만 사용 시 함께 삭제

**2. VideoPageViewController.swift:310-315** (R5)
- `if Log.categories["Video"] == true { ... }` 블록 전체 삭제

**3. ViewerViewController.swift** (R5)
- line 1290: `guard Log.categories["Viewer"] == true` → 함수 본문 전체 삭제 (early return만 남기거나 함수 자체 삭제 검토)
- line 1324: `guard Log.categories["Viewer"] == true` → guard 이하 삭제
- line 1361-1371: `if Log.categories["Viewer"] == true { ... }` → 블록 전체 삭제 (내부 변수 `now`, `prevIndex`, `nextIndex` + `debugSnapshot()` 호출 포함)

검증: Xcode 빌드 + 시뮬레이터 뷰어 동작 확인
커밋: `refactor: Viewer false 카테고리 로그 삭제 + 기능분기 처리`

---

## Phase 5: SimilarPhoto (10파일, ~80호출)

| 파일 | 호출 수 | 규칙 | 특이사항 |
|------|---------|------|---------|
| `SimilarityAnalysisQueue.swift` | 8+15 | R1 | 등록 false 8개 + 미등록 15개 (`NoFallback`, `AlignFail`, `EmbedFail`, `KeepBest`, `Match` 등) |
| `YuNetDebugTest.swift` | 12+6 | R1 | 등록 false 12개 + 미등록 (`Image`, `Detection`, `ERROR` 등) |
| `FaceComparisonViewController.swift` | 10+7 | R1 | 등록 10개 + 미등록 (`FaceComparison:Scroll` 5, `MatchingTest` 2, `ExtendedTest` 2) |
| `SimilarityAnalyzer.swift` | 8 | R1 | |
| `PersonPageViewController.swift` | 1+3 | R1 | 등록 1개 + 미등록 `PersonPage:Scroll` 3개 |
| `YuNetFaceDetector.swift` | 3 | R1 | |
| `FaceButtonOverlay.swift` | 2 | R1 | |
| `SimilarityAnalysisQueue+ExtendedFallback.swift` | 2 | R1 | 미등록 `ExtendedFallback` |
| `SFaceRecognizer.swift` | 1+1 | R1 | 등록 `SFace` 1개 + 미등록 `SFaceRecognizer` 1개 |
| `FaceComparisonDebug.swift` | 1 | R1 | 미등록 `FaceComparisonDebugHelper` |

검증: Xcode 빌드
커밋: `refactor: SimilarPhoto false 카테고리 로그 삭제`

---

## Phase 6: Shared + Navigation + App + Debug (20파일, ~108호출)

| 파일 | 호출 수 | 규칙 | 특이사항 |
|------|---------|------|---------|
| `TabBarController.swift` | 15 | R1 | |
| `FloatingTabBar.swift` | 10 | R1 | |
| `FloatingTitleBar.swift` | 10 | R1 | |
| `LiquidGlassTabBar.swift` | 9 | R1 | 미등록 |
| `LayerDumpInspector.swift` | 9 | R1 | |
| `AutoScrollTester.swift` | 7 | R1+**R7** | 미등록 `AutoScroll`. switch case 내 로그-only 패턴 있음 → `break` 대체 |
| `FloatingOverlayContainer.swift` | 6 | R1 | |
| `AppDelegate.swift` | 6 | R1 | `LaunchArgs`, `Env` |
| `ZoomAnimator.swift` | 10 | R1 | |
| `SupabaseProvider.swift` | 5 | R1 | 미등록 `Supabase` |
| `SystemUIInspector2.swift` | 5 | R1 | |
| `AlbumsViewController.swift` | 3 | R1 | 미등록 `Albums:Scroll` |
| `AnalyticsService.swift` | 2 | R1 | 미등록 `Supabase` |
| `LiquidGlassSelectionPill.swift` | 2 | R1 | 미등록 |
| `LayerPropertyTest.swift` | 2 | R1 | |
| `SystemUIInspector3.swift` | 2 | R1 | |
| `LiquidGlassPlatter.swift` | 1 | R1 | 미등록 |
| `LiquidGlassTabButton.swift` | 1 | R1 | 미등록 |
| `S2DebugAnalyzer.swift` | 1 | R1 | 미등록 `S2Debug` |
| `SystemUIInspector.swift` | 1 | R1 | `SystemUIInspector` (false) |

검증: Xcode 빌드
커밋: `refactor: Shared/Navigation/App/Debug false 카테고리 로그 삭제`

---

## Phase 7: Log.swift 정리

- `Log.categories` 딕셔너리에서 **false 엔트리 75개 제거** (true 32개만 남김)
- `Log.enable()`, `Log.disable()`, `Log.enableAll()`, `Log.disableAll()` 메서드 삭제 (외부 호출 없음 확인됨)
- `Log.showUncategorized` 삭제 (외부 참조 없음 확인됨)

검증: `swift build`
커밋: `refactor: Log.swift false 카테고리 엔트리 + 미사용 메서드 정리`

---

## 검증 방법

1. 각 Phase 후 빌드 (`swift build` 또는 Xcode 빌드)
2. Phase 7 후 잔존 확인: `grep -r "Log\.print\|Log\.debug" Sources/ PickPhoto/`로 **남은 호출이 모두 true 카테고리인지** 검증 (미등록 카테고리 포함 전수 확인)
3. 최종 `swift build` + Xcode 빌드 통과 확인

# Log 시스템 리팩토링: Log.swift → Apple Logger 마이그레이션

> 작성일: 2026-02-17
> 상태: 계획 수립 (미착수)

---

## 1. 현재 상태 (AS-IS)

### Log.swift 구조
- **위치**: `Sources/AppCore/Services/Log.swift` (295줄)
- **방식**: `Log.categories` 딕셔너리에 ~100개 카테고리를 등록하고, `true/false`로 출력 제어
- **호출부**: `Log.print("[Category] msg")` 650개 + `Log.debug("Category", "msg")` 106개 = **약 756개** (80개 소스 파일)

### 문제점
1. **카테고리 등록 번거로움**: 새 로그 추가 시 딕셔너리에 카테고리를 수동 등록해야 함
2. **릴리즈 성능**: `Log.print()`는 내부적으로 `Swift.print()` 호출 → 릴리즈에서도 I/O 발생
3. **정보 노출**: 릴리즈 빌드에서 Console.app으로 모든 내부 로그가 그대로 노출
4. **출시 후 디버깅 불가**: `isEnabled = false`로 끄면 필요한 로그도 볼 수 없음
5. **레벨 구분 없음**: 디버그 로그와 에러 로그가 동일한 방식으로 출력

---

## 2. 목표 상태 (TO-BE)

### Apple `Logger` API (iOS 14+, Unified Logging)

```swift
import OSLog

extension Logger {
    /// 테스트 환경에서 nil 가능 → 폴백 제공
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pickphoto.appcore"

    public static let viewer       = Logger(subsystem: subsystem, category: "Viewer")
    public static let grid         = Logger(subsystem: subsystem, category: "Grid")
    public static let similarPhoto = Logger(subsystem: subsystem, category: "SimilarPhoto")
    public static let pipeline     = Logger(subsystem: subsystem, category: "Pipeline")
    public static let cleanup      = Logger(subsystem: subsystem, category: "Cleanup")
    public static let transition   = Logger(subsystem: subsystem, category: "Transition")
    public static let analytics    = Logger(subsystem: subsystem, category: "Analytics")
    // ... 기능별로 추가
}
```

**주의: 사용하는 파일에서 `import OSLog` 필수** (Swift는 transitive import를 re-export하지 않음)

```swift
import OSLog      // Logger 타입 자체를 위해 필수
import AppCore    // Logger.viewer 등 extension 멤버를 위해 필수
```

### 호출 변환 예시

```swift
// AS-IS
Log.print("[Viewer] scale: \(scale)")
Log.debug("Zoom", "transition started")

// TO-BE
Logger.viewer.debug("scale: \(scale)")
Logger.transition.debug("transition started")

// 에러는 레벨로 구분
Logger.pipeline.error("thumbnail load failed: \(error)")
```

---

## 3. 왜 Logger인가 — print() 대비 이점

### 3-1. 성능

| 항목 | `print()` / `Log.print()` | `Logger` |
|------|--------------------------|----------|
| 릴리즈 동작 | **실행됨** (I/O 발생) | `.debug` 레벨은 **컴파일러가 코드 자체 제거** |
| 문자열 생성 | **항상** 생성 | 수집될 때만 **지연 평가 (lazy)** |
| 처리 방식 | 동기 (메인 스레드 블로킹 가능) | **비동기** + 커널 버퍼 |
| 속도 | 기준 | print 대비 **10~50배 빠름** |

핵심: `.debug` 레벨은 릴리즈에서 문자열 보간(interpolation) 자체가 실행되지 않음:
```swift
// 릴리즈에서 computeExpensive()가 호출되지 않음
logger.debug("result: \(computeExpensive())")
```

### 3-2. 로그 레벨 자동 관리

| 레벨 | 용도 | 메모리 | 디스크 | 릴리즈 |
|------|------|--------|--------|--------|
| `.debug` | 개발 중 상세 로그 | X | X | **자동 제거** |
| `.info` | 참고 정보 | O | X | 스트리밍 시만 |
| `.notice` | 핵심 이벤트 (기본) | O | **O** | 확인 가능 |
| `.error` | 런타임 에러 | O | **O (장기)** | 확인 가능 |
| `.fault` | 버그/크래시급 | O | **O (최장)** | 확인 가능 |

→ 현재 `Log.categories`의 `true/false` on/off가 하던 역할을 **OS가 레벨 기반으로 자동 처리**

### 3-3. 개인정보 보호 (Privacy)

```swift
// 동적 값은 기본적으로 private → Console에서 <private>으로 표시
Logger.grid.info("photo: \(assetID)")
// → Console: "photo: <private>"

// 공개해도 되는 값은 명시
Logger.grid.info("count: \(photoCount, privacy: .public)")

// 해시로 상관관계 추적
Logger.viewer.info("user: \(userID, privacy: .private(mask: .hash))")
// → Console: "user: 8A3F2C1..."
```

### 3-4. 출시 후 실기기 디버깅

```bash
# Mac에서 USB 연결 기기 실시간 로그 스트리밍
log stream --predicate 'subsystem == "com.karl.PickPhoto"' --level debug

# 특정 카테고리만 필터
log stream --predicate 'subsystem == "com.karl.PickPhoto" AND category == "Viewer"'

# 로그 아카이브 수집 (사후 분석용)
log collect --device --output pickphoto.logarchive
```

Console.app에서도 subsystem/category 기반 필터링 가능.

---

## 4. 마이그레이션 전략

### 4-1. 카테고리 매핑 (현재 → Logger)

현재 ~100개 카테고리를 **기능 단위로 통합**:

| 현재 카테고리 (Log.swift) | Logger 카테고리 | 비고 |
|--------------------------|----------------|------|
| Viewer, Video, Photo, Zoom, Overlay, VideoControls, FaceButton, ViewerPerf, Viewer:Hitch, Viewer:Swipe, Viewer:Scroll | `Logger.viewer` | 뷰어 관련 통합 |
| GridViewController, BaseGridViewController, GridDataSource, GridDataSourceDriver, GridScroll, GridGestures, GridStats, PinchZoom | `Logger.grid` | 그리드 관련 통합 |
| GridSelectMode, BaseSelectMode, TrashSelectMode, SelectionManager | `Logger.selection` | 선택 모드 통합 |
| SimilarPhoto, SimilarityAnalysisQueue, SimilarityAnalyzer, FaceComparisonViewController, PersonPageViewController | `Logger.similarPhoto` | 유사사진 통합 |
| YuNet, YuNetFaceDetector, SFace, FaceMatching, VisionFallback | `Logger.faceDetect` | 얼굴 인식 통합 |
| QualityAnalyzer, CleanupService, CleanupSessionStore, AutoCleanup, VideoFrameExtractor, TextDetect, QA-TextDetect | `Logger.cleanup` | 자동정리 통합 |
| ImagePipeline, Pipeline, ThumbnailCache, MemoryCache, DiskSave, Thumb:Req, Thumb:Res, Preload | `Logger.pipeline` | 이미지 파이프라인 통합 |
| ZoomTransition, ZoomAnimator, Zoom Timing | `Logger.transition` | 전환 애니메이션 통합 |
| TabBarController, FloatingTabBar, FloatingTitleBar, FloatingOverlayContainer | `Logger.navigation` | 네비게이션/UI 통합 |
| AlbumsViewController, AlbumGridViewController, TrashAlbumViewController | `Logger.albums` | 앨범 관련 통합 |
| Hitch, Scroll, Performance, LiquidGlass | `Logger.performance` | 성능 측정 통합 |
| AppDelegate, SceneDelegate, LaunchArgs, Env, Config, Timing | `Logger.app` | 앱 라이프사이클 통합 |
| TrashStore, AppStateStore | `Logger.store` | 상태 관리 통합 |
| Analytics | `Logger.analytics` | 분석 |
| CoachMarkC1, CoachMarkC2, CoachMarkManager | `Logger.coachMark` | 코치마크 통합 |
| Permission, PermissionVC | `Logger.permission` | 권한 |
| Debug, ButtonInspector, SystemUIInspector 등 | `Logger.appDebug` | 디버그 전용 (`debug`는 인스턴스 메서드 충돌) |

**~100개 → ~17개 카테고리**로 통합

### 4-2. 로그 레벨 분류 기준

| 현재 패턴 | 변환 레벨 | 이유 |
|----------|----------|------|
| 개발 중 상세 로그 (scale, count, timing 등) | `.debug` | 릴리즈에서 자동 제거 |
| 기능 동작 확인 (started, completed 등) | `.info` | 필요 시만 수집 |
| 핵심 이벤트 (사용자 행동, 상태 변경) | `.notice` | 디스크 저장 |
| 실패/에러 | `.error` | 장기 보존 |
| 크래시급 문제 | `.fault` | 최장 보존 |

### 4-3. 작업 순서

1. **Logger extension 파일 생성** (`Logger+App.swift`)
2. **파일별 마이그레이션** (기능 단위로 진행)
   - `import OSLog` 추가
   - `Log.print("[Category] msg")` → `Logger.category.debug("msg")` 변환
   - `Log.debug("Category", "msg")` → `Logger.category.debug("msg")` 변환
   - 에러성 로그는 `.error` 레벨로 분류
3. **Log.swift 삭제**
4. **CLAUDE.md 로그 관련 섹션 업데이트**
5. **빌드 및 동작 확인**

---

## 5. 참고 자료

- [Logging | Apple Developer Documentation](https://developer.apple.com/documentation/os/logging)
- [Debug with structured logging - WWDC23](https://developer.apple.com/videos/play/wwdc2023/10226/)
- [Explore logging in Swift - WWDC20](https://developer.apple.com/videos/play/wwdc2020/10168/)
- [OSLog and Unified logging - SwiftLee](https://www.avanderlee.com/debugging/oslog-unified-logging/)
- [Xcode Console and Unified Logging - Use Your Loaf](https://useyourloaf.com/blog/xcode-console-and-unified-logging/)
- [Logging in Swift - Swift with Majid](https://swiftwithmajid.com/2022/04/06/logging-in-swift/)
- [Modern logging with OSLog - Donny Wals](https://www.donnywals.com/modern-logging-with-the-oslog-framework-in-swift/)
- [Swift Logging Techniques - Bugfender](https://bugfender.com/blog/swift-logging/)

---
---

# 구현 계획 (삭제 후 수정본)

> false 카테고리 로그 삭제 완료 후 재작성 (2026-02-20)
> 선행 작업: `260217Log-refac-del.md` (완료)
> 원본: 756호출/80파일 → 삭제 후: **326호출/38파일** (57% 감소)
> 최종 검토: 2026-02-25 (DB Hybrid 완료 후 재검증)

## 현황 요약

| 항목 | 삭제 전 | 삭제 후 |
|------|---------|---------|
| 총 호출 | ~756 | **326** |
| 파일 수 | 80 | **38** |
| String(format:) | 94곳 | **41곳** |
| Log.categories[] 직접 접근 | 6곳 | **0** (전부 삭제됨) |
| FileLogger.logThumbEnabled | 7곳 | **0** (전부 삭제됨) |
| callStack 등 긴 메시지 | 있음 | **0** (전부 삭제됨) |

---

## 리스크 (삭제 후 재평가)

| # | 리스크 | 심각도 | 상태 |
|---|--------|--------|------|
| 0 | `public` + `import OSLog` 누락 시 컴파일 실패 | 치명적 | **대응 완료** — 코드에 반영됨 |
| 1 | OSLogMessage 보간 (`String(format:)`, CGRect) | 높음 | **41곳으로 감소** (94→41). Phase 0에서 검증 |
| 2 | 메시지 크기 1024바이트 | - | **해소** — callStack 코드 삭제됨 |
| 3 | `self.` 명시 | 낮음 | 유지 — 컴파일러가 알려줌, 기계적 수정 |
| 4 | `Log.categories[]` 직접 접근 | - | **해소** — 6곳 전부 삭제됨 |
| 5 | `FileLogger.logThumbEnabled` 패턴 | - | **해소** — 7곳 전부 삭제됨 |

---

## Phase 0: Logger+App.swift 생성 + 검증

### 0-1. `Sources/AppCore/Services/Logger+App.swift` 신규 생성

```swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pickphoto.appcore"

    // Feature
    public static let viewer       = Logger(subsystem: subsystem, category: "Viewer")
    public static let albums       = Logger(subsystem: subsystem, category: "Albums")
    public static let similarPhoto = Logger(subsystem: subsystem, category: "SimilarPhoto")
    public static let cleanup      = Logger(subsystem: subsystem, category: "Cleanup")
    public static let transition   = Logger(subsystem: subsystem, category: "Transition")

    // Infrastructure
    public static let pipeline     = Logger(subsystem: subsystem, category: "Pipeline")
    public static let performance  = Logger(subsystem: subsystem, category: "Performance")
    public static let analytics    = Logger(subsystem: subsystem, category: "Analytics")
    public static let coachMark    = Logger(subsystem: subsystem, category: "CoachMark")

    // App
    public static let app          = Logger(subsystem: subsystem, category: "App")
    public static let appDebug     = Logger(subsystem: subsystem, category: "Debug")
}
```

**11개 카테고리** (삭제 전 17개에서 미사용 6개 제거: grid, selection, faceDetect, navigation, store, permission)

### 0-2. 검증용 테스트

OSLogMessage 보간 패턴 컴파일 확인:
```swift
logger.debug("v: \(String(format: "%.1f", 3.14))")   // String(format:)
logger.debug("v: \(isOn ? "ON" : "OFF")")              // 삼항 연산자
logger.debug("frame: \(view.frame)")                    // CGRect (1곳 존재)
logger.debug("size: \(image.size)")                     // CGSize
```

+ PickPhoto에서 `import OSLog` + `import AppCore`로 `Logger.viewer` 접근 가능한지 확인.
검증 후 테스트 파일 삭제.

**커밋**: `refactor: Logger+App.swift 생성`

---

## Phase 1: App + Grid (29호출, 3파일)

| 파일 | 호출 수 | Logger | String(format:) |
|------|---------|--------|----------------|
| `Features/Grid/GridScroll.swift` | 14 | `.performance` / `.pipeline` | **15곳** |
| `App/SceneDelegate.swift` | 13 | `.app` | - |
| `App/AppDelegate.swift` | 2 | `.app` | - |

GridScroll 카테고리 매핑:
- `[InitialDisplay]`, `[Scroll]`, `[Hitch]`, `[Timing]` → `Logger.performance`
- `[Preload]` → `Logger.pipeline`

**에러 레벨**: AppDelegate "Memory warning" → `.notice`

**검증**: Xcode 빌드
**커밋**: `refactor(Phase1): App/Grid Logger 마이그레이션`

---

## Phase 2: Albums + SimilarPhoto + CoachMark (74호출, 12파일)

| 파일 | 호출 수 | Logger | String(format:) |
|------|---------|--------|----------------|
| `Features/Grid/GridViewController+CoachMarkD.swift` | 13 | `.coachMark` | - |
| `Features/Grid/GridViewController+CoachMarkReplay.swift` | 11 | `.coachMark` | - |
| `Features/Albums/AlbumsViewController.swift` | 10 | `.albums` | - |
| `Features/Grid/GridViewController+CoachMarkA1.swift` | 10 | `.coachMark` | - |
| `Features/AutoCleanup/CoachMarkDPreScanner.swift` | 8 | `.coachMark` | - |
| `Features/Grid/GridViewController+SimilarPhoto.swift` | 8 | `.similarPhoto` | - |
| `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift` | 6 | `.similarPhoto` | - |
| `Features/Grid/GridViewController+CoachMark.swift` | 4 | `.coachMark` | - |
| `Features/Grid/BaseGridViewController.swift` | 1 | `.coachMark` | - |
| `Features/Grid/GridDataSourceDriver.swift` | 1 | `.performance` | 1곳 |
| `Features/Grid/GridViewController+CoachMarkC.swift` | 1 | `.coachMark` | - |
| `Features/Grid/GridViewController.swift` | 1 | - | 주석 삭제만 |

**에러 레벨**:
- AlbumsViewController: "Failed to fetch photos" → `.error`
- SimilarityAnalysisQueue: "error:" → `.error`

**검증**: Xcode 빌드
**커밋**: `refactor(Phase2): Albums/SimilarPhoto/CoachMark Logger 마이그레이션`

---

## Phase 3: Viewer + Shared (58호출, 14파일)

> SupabaseProvider: DB Hybrid 구현으로 추가된 파일. `[Supabase]` 카테고리 → `.analytics`로 매핑.
> CoachMarkOverlayView+CoachMarkA1: CoachMark A-1 구현으로 추가된 파일.

### Viewer (19호출)

| 파일 | 호출 수 | Logger | String(format:) |
|------|---------|--------|----------------|
| `Features/Viewer/ViewerViewController.swift` | 8 | `.viewer` | 3곳 |
| `Features/Viewer/ViewerViewController+CoachMarkC.swift` | 8 | `.coachMark` | 1곳 (CGRect) |
| `Features/Viewer/ViewerViewController+SimilarPhoto.swift` | 3 | `.viewer` | 3곳 |

### Shared (39호출)

| 파일 | 호출 수 | Logger | String(format:) |
|------|---------|--------|----------------|
| `Shared/Analytics/AnalyticsService+DeleteRestore.swift` | 7 | `.analytics` | - |
| `Shared/Analytics/AnalyticsService.swift` | 6 | `.analytics` | - |
| `Shared/Components/CoachMarkOverlayView.swift` | 6 | `.coachMark` | - |
| `Shared/Analytics/AnalyticsService+Session.swift` | 4 | `.analytics` | - |
| `Shared/Analytics/SupabaseProvider.swift` | 4 | `.analytics` | - |
| `Shared/Analytics/AnalyticsService+Lifecycle.swift` | 3 | `.analytics` | - |
| `Shared/Transitions/ZoomDismissalInteractionController.swift` | 3 | `.transition` | - |
| `Shared/Transitions/ZoomTransitionController.swift` | 3 | `.transition` | - |
| `Shared/Components/CoachMarkOverlayView+CoachMarkA1.swift` | 1 | `.coachMark` | - |
| `Shared/Analytics/AnalyticsService+Viewing.swift` | 1 | `.analytics` | - |
| `Features/Grid/PhotoCell.swift` | 1 | - | 주석 삭제만 |

**에러 레벨**:
- SupabaseProvider: "error:" → `.error` (2곳: send error, batch error)

**검증**: Xcode 빌드 + 시뮬레이터 동작 확인
**커밋**: `refactor(Phase3): Viewer/Shared Logger 마이그레이션`

---

## Phase 4: Debug (165호출, 9파일)

| 파일 | 호출 수 | Logger | String(format:) |
|------|---------|--------|----------------|
| `Debug/PreScanBenchmark.swift` | 43 | `.cleanup` | 9곳 |
| `Debug/CompareAnalysisTester.swift` | 35 | `.cleanup` | 5곳 |
| `Debug/ModeComparisonTester.swift` | 33 | `.cleanup` | 3곳 |
| `Debug/CleanupDebug.swift` | 16 | `.cleanup` | 2곳 |
| `Debug/ButtonInspector.swift` | 11 | `.appDebug` | - |
| `Debug/AestheticsOnlyTester.swift` | 9 | `.cleanup` | 1곳 |
| `Debug/LiquidGlassOptimizer.swift` | 7 | `.performance` | - |
| `Debug/RenderABTest.swift` | 7 | `.performance` | - |
| `Debug/AnalyticsTestInjector.swift` | 4 | `.appDebug` | - |

**CleanupDebug 특별 처리**: `Log.debug(category, "msg")` 형태 (동적 카테고리).
→ `Logger.cleanup.debug("[\(category)] msg")` 로 변환 (카테고리를 메시지에 포함).

**에러 레벨**: ButtonInspector "저장 실패" → `.error`

**검증**: Xcode 빌드
**커밋**: `refactor(Phase4): Debug Logger 마이그레이션`

---

## Phase 5: Log.swift 삭제 + 정리

1. **`Log.swift` 삭제** (사용자 확인 후)
2. **잔존 참조 확인**: `grep -r "Log\.print\|Log\.debug" Sources/ PickPhoto/`
3. **CLAUDE.md 로그 섹션 업데이트**: Logger 사용법으로 재작성
4. **최종 빌드**: `swift build` + Xcode 빌드

**검증**:
- Console.app에서 subsystem 필터: `log stream --predicate 'subsystem == "com.karl.PickPhoto"' --level debug`

**커밋**: `refactor(Phase5): Log.swift 삭제 — Logger 마이그레이션 완료`

---

## 로그 레벨 분류 기준

| 키워드/패턴 | 레벨 | 예시 |
|------------|------|------|
| Failed, Error, 실패 | `.error` | "Failed to fetch photos" |
| Memory warning | `.notice` | "Memory warning received" |
| 나머지 전부 | `.debug` | "scale: 2.0", "index: 5" |

---

## String(format:) 발생 현황 (총 41곳, 8파일)

| Phase | 파일 수 | String(format:) 수 | 주요 파일 |
|-------|---------|-------------------|----------|
| 1 (App+Grid) | 1 | 15 | GridScroll(15) |
| 2 (Albums/Similar) | 1 | 1 | GridDataSourceDriver(1) |
| 3 (Viewer/Shared) | 2 | 7 | ViewerVC(3), ViewerVC+Similar(3), ViewerVC+CoachMarkC(1 CGRect) |
| 4 (Debug) | 5 | 20 | PreScanBM(9), Compare(5), ModeComp(3), CleanupDebug(2), Aesthetics(1) |
| **합계** | **8** | **41** | |

Phase 0에서 패턴 검증 후 일괄 적용.

---

## 카테고리 매핑 (삭제 후)

| 현재 true 카테고리 | Logger | 주요 파일 |
|-------------------|--------|----------|
| AppDelegate, SceneDelegate | `.app` | SceneDelegate, AppDelegate |
| Viewer:Hitch, Viewer:Swipe, Viewer:Scroll, ViewerPerf | `.viewer` | ViewerVC, ViewerVC+SimilarPhoto |
| CoachMarkA, CoachMarkA1, CoachMarkC1, CoachMarkC2, CoachMarkD, CoachMark, CoachMarkManager, CoachMarkReplay | `.coachMark` | GridVC+CoachMarkD, GridVC+CoachMarkReplay, GridVC+CoachMarkA1, CoachMarkDPreScanner, GridVC+CoachMark, ViewerVC+CoachMarkC, GridVC+CoachMarkC, CoachMarkOverlayView, CoachMarkOverlayView+CoachMarkA1, BaseGridVC |
| AlbumsViewController | `.albums` | AlbumsViewController |
| SimilarPhoto | `.similarPhoto` | SimilarityAnalysisQueue, GridVC+SimilarPhoto |
| ZoomTransition | `.transition` | ZoomTransitionController, ZoomDismissalInteractionController |
| Analytics, Supabase | `.analytics` | AnalyticsService (+extensions), SupabaseProvider |
| Hitch, Scroll, InitialDisplay, Timing, Performance, LiquidGlass, ABTest | `.performance` | GridScroll, LiquidGlassOptimizer, RenderABTest |
| Preload | `.pipeline` | GridScroll |
| QualityAnalyzer, CleanupService, PreScanBM, CompareAnalysis, ModeComparison, TextDetect, AestheticsOnly 등 | `.cleanup` | CleanupDebug, PreScanBM, CompareAnalysisTester, ModeComparisonTester, AestheticsOnlyTester |
| ButtonInspector, Debug, AnalyticsTest | `.appDebug` | ButtonInspector, AnalyticsTestInjector |

---

## 주의사항

1. **`public` 필수**: Logger extension의 모든 static let에 `public` 키워드 필수
2. **`import OSLog` 필수**: 모든 마이그레이션 대상 파일(~38개)에 `import OSLog` 추가 필요
3. **OSLogMessage 보간**: Phase 0에서 검증. `String(format:)` 41곳 + CGRect 1곳 확인
4. **`self.` 명시**: 컴파일러가 알려줌, 기계적 수정
5. **Privacy**: `.debug` 레벨은 릴리즈에서 제거되므로 초기 마이그레이션에서는 미지정
6. **Git 규칙**: 각 Phase 전후 커밋 (50줄 이상 수정)
7. **파일 삭제**: Log.swift 삭제는 Phase 5에서 사용자 확인 후 진행

---

## 수정 대상 파일 목록

| # | 파일 | Phase | 호출 수 |
|---|------|-------|---------|
| - | `Sources/AppCore/Services/Logger+App.swift` (신규) | 0 | - |
| 1 | `Features/Grid/GridScroll.swift` | 1 | 14 |
| 2 | `App/SceneDelegate.swift` | 1 | 13 |
| 3 | `App/AppDelegate.swift` | 1 | 2 |
| 4 | `Features/Grid/GridViewController+CoachMarkD.swift` | 2 | 13 |
| 5 | `Features/Grid/GridViewController+CoachMarkReplay.swift` | 2 | 11 |
| 6 | `Features/Albums/AlbumsViewController.swift` | 2 | 10 |
| 7 | `Features/Grid/GridViewController+CoachMarkA1.swift` | 2 | 10 |
| 8 | `Features/AutoCleanup/CoachMarkDPreScanner.swift` | 2 | 8 |
| 9 | `Features/Grid/GridViewController+SimilarPhoto.swift` | 2 | 8 |
| 10 | `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift` | 2 | 6 |
| 11 | `Features/Grid/GridViewController+CoachMark.swift` | 2 | 4 |
| 12 | `Features/Grid/BaseGridViewController.swift` | 2 | 1 |
| 13 | `Features/Grid/GridDataSourceDriver.swift` | 2 | 1 |
| 14 | `Features/Grid/GridViewController+CoachMarkC.swift` | 2 | 1 |
| 15 | `Features/Grid/GridViewController.swift` | 2 | 주석 |
| 16 | `Features/Viewer/ViewerViewController.swift` | 3 | 8 |
| 17 | `Features/Viewer/ViewerViewController+CoachMarkC.swift` | 3 | 8 |
| 18 | `Shared/Analytics/AnalyticsService+DeleteRestore.swift` | 3 | 7 |
| 19 | `Shared/Analytics/AnalyticsService.swift` | 3 | 6 |
| 20 | `Shared/Components/CoachMarkOverlayView.swift` | 3 | 6 |
| 21 | `Shared/Analytics/AnalyticsService+Session.swift` | 3 | 4 |
| 22 | `Shared/Analytics/SupabaseProvider.swift` | 3 | 4 |
| 23 | `Features/Viewer/ViewerViewController+SimilarPhoto.swift` | 3 | 3 |
| 24 | `Shared/Analytics/AnalyticsService+Lifecycle.swift` | 3 | 3 |
| 25 | `Shared/Transitions/ZoomDismissalInteractionController.swift` | 3 | 3 |
| 26 | `Shared/Transitions/ZoomTransitionController.swift` | 3 | 3 |
| 27 | `Shared/Components/CoachMarkOverlayView+CoachMarkA1.swift` | 3 | 1 |
| 28 | `Shared/Analytics/AnalyticsService+Viewing.swift` | 3 | 1 |
| 29 | `Features/Grid/PhotoCell.swift` | 3 | 주석 |
| 30 | `Debug/PreScanBenchmark.swift` | 4 | 43 |
| 31 | `Debug/CompareAnalysisTester.swift` | 4 | 35 |
| 32 | `Debug/ModeComparisonTester.swift` | 4 | 33 |
| 33 | `Debug/CleanupDebug.swift` | 4 | 16 |
| 34 | `Debug/ButtonInspector.swift` | 4 | 11 |
| 35 | `Debug/AestheticsOnlyTester.swift` | 4 | 9 |
| 36 | `Debug/LiquidGlassOptimizer.swift` | 4 | 7 |
| 37 | `Debug/RenderABTest.swift` | 4 | 7 |
| 38 | `Debug/AnalyticsTestInjector.swift` | 4 | 4 |
| - | `Sources/AppCore/Services/Log.swift` (삭제) | 5 | - |
| - | `CLAUDE.md` (로그 섹션 업데이트) | 5 | - |

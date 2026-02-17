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
    private static let subsystem = Bundle.main.bundleIdentifier!

    static let viewer       = Logger(subsystem: subsystem, category: "Viewer")
    static let grid         = Logger(subsystem: subsystem, category: "Grid")
    static let similarPhoto = Logger(subsystem: subsystem, category: "SimilarPhoto")
    static let pipeline     = Logger(subsystem: subsystem, category: "ImagePipeline")
    static let cleanup      = Logger(subsystem: subsystem, category: "AutoCleanup")
    static let transition   = Logger(subsystem: subsystem, category: "Transition")
    static let analytics    = Logger(subsystem: subsystem, category: "Analytics")
    // ... 기능별로 추가
}
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
log stream --predicate 'subsystem == "com.pickphoto.app"' --level debug

# 특정 카테고리만 필터
log stream --predicate 'subsystem == "com.pickphoto.app" AND category == "Viewer"'

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
| Debug, ButtonInspector, SystemUIInspector 등 | `Logger.debug` | 디버그 전용 |

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

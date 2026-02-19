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

# 구현 계획 (2차 검토 완료)

## 검토에서 발견된 핵심 리스크

### 리스크 0: `public` 키워드 누락 + `import OSLog` 필요 (심각도: 치명적)

**문제 A**: Logger extension의 static property에 `public`이 없으면 AppCore 외부(PickPhoto)에서 사용 불가.
Swift의 extension 멤버는 기본 `internal`이므로 **반드시 `public` 명시 필요**.

**문제 B**: PickPhoto 파일에서 `import AppCore`만으로는 `Logger` 타입이 보이지 않음.
Swift는 transitive import를 re-export하지 않으므로, 각 파일에 **`import OSLog` 추가 필수**.

**대응**:
- `Logger+App.swift`의 모든 static let에 `public` 추가
- PickPhoto의 모든 마이그레이션 대상 파일(~71개)에 `import OSLog` 추가
- Phase 0 검증에서 모듈 간 가시성도 함께 테스트

### 리스크 1: OSLogMessage 문자열 보간 ≠ Swift String 보간 (심각도: 높음)

`Logger`의 보간은 `OSLogMessage` 기반이라 일반 Swift String 보간과 다르다.
`String(format:)` 보간이 **94곳 (24파일)**에 존재하며, OSLogMessage에서 컴파일 에러 가능성이 있다.

**대응 전략**: Phase 0에서 검증용 테스트 파일을 만들어 실제 컴파일 여부를 먼저 확인한다.
- 컴파일되면 → 그대로 사용
- 컴파일 안 되면 → 변수로 사전 추출 (`let formatted = String(format: "%.1f", value)` 후 `Logger.x.debug("\(formatted)")`)

```swift
// 검증할 패턴들:
logger.debug("v: \(String(format: "%.1f", 3.14))")   // String(format:)
logger.debug("v: \(isOn ? "ON" : "OFF")")              // 삼항 연산자
logger.debug("v: \(opt.map(String.init) ?? "nil")")     // .map + ??
logger.debug("v: \(arr.joined(separator: ", "))")       // .joined()
logger.debug("v: \(self.someProperty)")                 // self. 필요?
logger.debug("frame: \(view.frame)")                    // CGRect
logger.debug("size: \(image.size)")                     // CGSize
logger.debug("origin: \(view.frame.origin)")            // CGPoint
```

### 리스크 2: 메시지 크기 제한 1024바이트 (심각도: 중간)

Unified Logging은 단일 메시지 ~1024바이트 제한이 있다.
`Thread.callStackSymbols` (VideoPageViewController.swift:312) 등 긴 메시지는 잘릴 수 있다.

**대응**: 이미 `#if DEBUG` 블록 안에 있으므로, 해당 부분만 `print()`를 유지하거나 메시지를 분할한다.

### 리스크 3: `self.` 명시 요구 (심각도: 낮음)

Logger 보간은 `@autoclosure @escaping`이므로 클래스 메서드 내에서 인스턴스 프로퍼티 접근 시 `self.` 명시가 필요할 수 있다. 컴파일러가 알려주므로 기계적 수정 가능.

---

## Phase 0: 사전 커밋 + 패턴 검증

1. 현재 변경사항 커밋 후 롤백 포인트 생성
2. **검증용 테스트 파일** 생성 → 다음 패턴들을 실제 컴파일하여 확인:
   - `String(format:)` 보간 (리스크 1)
   - 삼항 연산자, `.map()??`, `.joined()` 보간 (리스크 1)
   - `self.` 필요 여부 (리스크 3)
   - **PickPhoto에서 `import OSLog` + `import AppCore`로 `Logger.viewer` 접근 가능한지** (리스크 0)
   - **`public static let`이 모듈 외부에서 보이는지** (리스크 0)
3. 결과에 따라 Phase 1 이후 변환 전략 확정
4. 검증 후 테스트 파일 삭제

---

## Phase 1: Logger extension 생성 + AppCore 마이그레이션

### 1-1. `Sources/AppCore/Services/Logger+App.swift` 신규 생성

```swift
import OSLog

extension Logger {
    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.pickphoto.appcore"

    // 뷰어/미디어
    public static let viewer       = Logger(subsystem: subsystem, category: "Viewer")

    // 그리드
    public static let grid         = Logger(subsystem: subsystem, category: "Grid")
    public static let selection    = Logger(subsystem: subsystem, category: "Selection")

    // 분석
    public static let similarPhoto = Logger(subsystem: subsystem, category: "SimilarPhoto")
    public static let faceDetect   = Logger(subsystem: subsystem, category: "FaceDetect")
    public static let cleanup      = Logger(subsystem: subsystem, category: "Cleanup")

    // 인프라
    public static let pipeline     = Logger(subsystem: subsystem, category: "Pipeline")
    public static let transition   = Logger(subsystem: subsystem, category: "Transition")
    public static let navigation   = Logger(subsystem: subsystem, category: "Navigation")
    public static let albums       = Logger(subsystem: subsystem, category: "Albums")
    public static let performance  = Logger(subsystem: subsystem, category: "Performance")

    // 앱 레벨
    public static let app          = Logger(subsystem: subsystem, category: "App")
    public static let store        = Logger(subsystem: subsystem, category: "Store")
    public static let analytics    = Logger(subsystem: subsystem, category: "Analytics")
    public static let coachMark    = Logger(subsystem: subsystem, category: "CoachMark")
    public static let permission   = Logger(subsystem: subsystem, category: "Permission")

    // 디버그 ("debug"는 인스턴스 메서드 충돌 → "appDebug")
    public static let appDebug     = Logger(subsystem: subsystem, category: "Debug")
}
```

### 1-2. AppCore 9개 파일 변환 (62호출)

| 파일 | 호출 수 | Logger | 에러 레벨 | String(format:) |
|------|---------|--------|----------|----------------|
| `Stores/TrashStore.swift` | 15 | `.store` | 4곳 | 1곳 |
| `Services/ThumbnailCache.swift` | 11 | `.pipeline` | 2곳 | 2곳 |
| `Services/ImagePipeline.swift` | 10 | `.pipeline` | 1곳 | 3곳 |
| `Services/AlbumService.swift` | 9 | `.albums` | - | - |
| `Services/AppStateStore.swift` | 6 | `.store` | - | - |
| `Services/VideoPipeline.swift` | 6 | `.pipeline` | 1곳 | - |
| `Services/PhotoLibraryService.swift` | 2 | `.app` | - | - |
| `Services/MemoryThumbnailCache.swift` | 2 | `.pipeline` | - | - |
| `Services/FileLogger.swift` | 1 | 주석만 | - | - |

**String(format:) 처리** (Phase 0 검증 결과에 따라):
```swift
// 방법 A: 직접 사용 (컴파일되는 경우)
Logger.pipeline.debug("elapsed: \(String(format: "%.1f", elapsed))ms")

// 방법 B: 변수 추출 (컴파일 안 되는 경우)
let elapsedStr = String(format: "%.1f", elapsed)
Logger.pipeline.debug("elapsed: \(elapsedStr)ms")
```

**검증**: `swift build`
**커밋**: `refactor(Phase1): Logger extension 생성 + AppCore 마이그레이션`

---

## Phase 2: App + Grid + Albums + Permissions (20파일, 171호출)

| 그룹 | 파일 수 | 호출 수 | Logger | String(format:) |
|------|---------|---------|--------|----------------|
| App | 2 | 21 | `.app` | - |
| Grid | 13 | 88 | `.grid` / `.selection` | 19곳 |
| Albums | 4 | 53 | `.albums` / `.selection` | 3곳 |
| Permissions | 1 | 9 | `.permission` | - |

**에러 레벨 분류:**
- `GridViewController`: "Failed to permanently delete" → `.error`
- `AlbumGridViewController`: "Failed to permanently delete" → `.error`
- `TrashAlbumViewController`: "Failed to permanently delete" → `.error`
- `AlbumsViewController`: "Failed to fetch photos" → `.error`
- `TrashSelectMode`: "Failed to delete" → `.error`
- `PermissionViewController`: "Failed to create settings URL" → `.error`

**주의**: `GridScroll.swift`에 String(format:) 9곳 집중

**검증**: Xcode 빌드 (시뮬레이터)
**커밋**: `refactor(Phase2): App/Grid/Albums/Permissions Logger 마이그레이션`

---

## Phase 3: Viewer (8파일, 90호출) — 가장 주의 필요

### 3-1. 일반 변환 (84호출)

| 파일 | Log.print | Log.debug | Logger | String(format:) |
|------|-----------|-----------|--------|----------------|
| `VideoPageViewController.swift` | 0 | 27 | `.viewer` | 1곳 |
| `PhotoPageViewController.swift` | 0 | 24 | `.viewer` | 12곳 |
| `ViewerViewController.swift` | 8 | 5 | `.viewer` / `.performance` | 5곳 |
| `VideoControlsOverlay.swift` | 0 | 10 | `.viewer` | - |
| `ViewerViewController+CoachMarkC.swift` | 8 | 0 | `.coachMark` | - |
| `ViewerViewController+SimilarPhoto.swift` | 7 | 0 | `.similarPhoto` | 3곳 |
| `ViewerCoordinator.swift` | 1 | 0 | `.viewer` | 1곳 |

### 3-2. `Log.categories[]` 직접 접근 6곳 처리

**PhotoPageViewController.swift:127-128** — 디버그 UI 토글
```swift
// AS-IS
private var debugOverlayEnabled: Bool {
    Log.categories["Overlay"] == true
}
// TO-BE
#if DEBUG
private var debugOverlayEnabled: Bool {
    ProcessInfo.processInfo.arguments.contains("-debugOverlay")
}
#else
private let debugOverlayEnabled = false
#endif
```

**VideoPageViewController.swift:310-315** — 비싼 callStack 연산
```swift
// AS-IS
if Log.categories["Video"] == true {
    let callStack = Thread.callStackSymbols.prefix(6).joined(separator: "\n")
    Log.debug("Video", "Call stack:\n\(callStack)")
}
// TO-BE: callStack은 길이가 수KB → Logger의 1024바이트 제한 초과
// print()를 유지하거나 메시지를 분할
#if DEBUG
print("[Viewer] Requesting video - index: \(index)")
print("[Viewer] Call stack:\n\(Thread.callStackSymbols.prefix(6).joined(separator: "\n"))")
#endif
```

**ViewerViewController.swift:1290** — 디버그 전용 함수 전체
```swift
// 함수 본문 전체를 #if DEBUG로 감싸기
@objc private func handlePageScrollPan(_ gesture: UIPanGestureRecognizer) {
    #if DEBUG
    guard let sv = pageScrollView else { return }
    guard isTransitioning else { return }
    // ... Logger.viewer.debug(...)
    #endif
}
```

**ViewerViewController.swift:1324-1339, 1361-1375** — debugSnapshot 호출 포함
```swift
// debugSnapshot()은 비싼 연산 → #if DEBUG로 감싸기
#if DEBUG
Logger.viewer.debug("willTransition - tid=\(self.transitionId)...")
current.debugSnapshot(tag: "current@will", transitionId: transitionId)
#endif
```

**검증**: Xcode 빌드 + 시뮬레이터에서 뷰어 스와이프/비디오 재생 확인
**커밋**: `refactor(Phase3): Viewer Logger 마이그레이션 + categories[] 대체`

---

## Phase 4: SimilarPhoto + AutoCleanup (13파일, 127호출)

| 그룹 | 파일 수 | 호출 수 | Logger | String(format:) |
|------|---------|---------|--------|----------------|
| SimilarPhoto/Analysis | 8 | 72 | `.similarPhoto` / `.faceDetect` | 24곳 |
| SimilarPhoto/UI | 3 | 25 | `.similarPhoto` | 1곳 |
| AutoCleanup | 2 | 32 | `.cleanup` | 2곳 |

**주의**: `SimilarityAnalysisQueue.swift`에 String(format:) 13곳, `YuNetDebugTest.swift`에 10곳 집중

**검증**: Xcode 빌드
**커밋**: `refactor(Phase4): SimilarPhoto/AutoCleanup Logger 마이그레이션`

---

## Phase 5: Shared + Debug (29파일, 271호출)

| 그룹 | 파일 수 | 호출 수 | Logger | String(format:) |
|------|---------|---------|--------|----------------|
| Shared/Transitions | 3 | 16 | `.transition` | - |
| Shared/Navigation | 1 | 14 | `.navigation` | - |
| Shared/Components | 8 | 41 | `.navigation` / `.coachMark` | - |
| Shared/Analytics | 5 | 16 | `.analytics` | - |
| Debug | 13 | 169 | `.appDebug` / `.performance` | 18곳 |

**주의**: `PreScanBenchmark.swift` 6곳, `CompareAnalysisTester.swift` 5곳, `ModeComparisonTester.swift` 3곳에 String(format:) 집중

**검증**: Xcode 빌드
**커밋**: `refactor(Phase5): Shared/Debug Logger 마이그레이션`

---

## Phase 6: 정리 및 마무리

1. **`Log.swift` 삭제** (사용자 확인 후)
2. **잔존 참조 확인**: `grep -r "Log\.print\|Log\.debug\|Log\.categories" Sources/ PickPhoto/`
3. **CLAUDE.md 로그 섹션 업데이트**: Logger 사용법으로 재작성
4. **docs/260217Log-refac.md 상태 업데이트**: 완료로 변경
5. **최종 빌드**: `swift build` + Xcode 빌드

**검증**:
- Console.app에서 subsystem 필터로 로그 확인
- `log stream --predicate 'subsystem == "com.karl.PickPhoto"' --level debug`

**커밋**: `refactor(Phase6): Log.swift 삭제 + 문서 업데이트 — Logger 마이그레이션 완료`

---

## 로그 레벨 분류 기준 (전체 적용)

| 키워드/패턴 | 레벨 | 예시 |
|------------|------|------|
| Failed, Error, 실패 | `.error` | "Failed to save state" |
| Warning, Memory warning | `.notice` | "Memory warning received" |
| 초기화 완료, 상태 변경 | `.info` | "PhotoLibrary authorized" |
| 나머지 전부 | `.debug` | "scale: 2.0", "index: 5" |

---

## String(format:) 발생 현황 (총 94곳, 24파일)

| Phase | 파일 수 | String(format:) 수 | 주요 파일 |
|-------|---------|-------------------|----------|
| 1 (AppCore) | 3 | 6 | ImagePipeline(3), ThumbnailCache(2), TrashStore(1) |
| 2 (Grid/Albums) | 5 | 22 | GridScroll(9), GridViewController(7), TrashAlbumVC(3) |
| 3 (Viewer) | 5 | 22 | PhotoPageVC(12), ViewerVC(5), ViewerVC+Similar(3) |
| 4 (Similar/Cleanup) | 4 | 27 | SimilarityAnalysisQueue(13), YuNetDebugTest(10) |
| 5 (Debug) | 5 | 18 | PreScanBenchmark(6), CompareAnalysis(5) |
| **합계** | **24** | **94** | |

Phase 0에서 패턴 검증 후 일괄 적용할 변환 전략을 확정한다.

---

## 주의사항

1. **`public` 필수**: Logger extension의 모든 static let에 `public` 키워드 필수 (없으면 AppCore 외부에서 접근 불가)
2. **`import OSLog` 필수**: PickPhoto의 모든 마이그레이션 대상 파일(~71개)에 `import OSLog` 추가 필요 (Swift는 transitive import를 re-export하지 않음)
3. **OSLogMessage 보간 제약**: Phase 0에서 반드시 검증. `String(format:)`, 삼항 연산자, `.map()??`, `.joined()` 패턴 확인
4. **메시지 크기 제한**: Logger는 ~1024바이트 제한. callStack 등 긴 메시지는 `#if DEBUG print()` 유지
5. **`self.` 명시**: Logger 보간이 `@escaping`이므로 클래스 메서드에서 인스턴스 프로퍼티 접근 시 `self.` 필요할 수 있음 (컴파일러가 알려줌, 기계적 수정)
6. **FileLogger.logThumbEnabled 패턴**: 7곳(GridScroll 5, PhotoCell 2, ImagePipeline 1)에서 `FileLogger.logThumbEnabled` 분기 안에 `Log.print()`를 사용 → Logger로 동일하게 변환, `FileLogger.logThumbEnabled` 분기는 그대로 유지
7. **debugSnapshot()**: PhotoPageViewController.swift:228에 `#if DEBUG` 없이 존재. 내부에서 `Log.debug()` 사용 → Logger로 변환. 호출부는 이미 계획대로 `#if DEBUG`로 감싸기
8. **이미 #if DEBUG 안의 Log.print()**: ImagePipeline.swift 3곳에서 존재. Logger.x.debug()로 변환하면 이중 가드가 되지만 기능적 문제 없음. 정리 원하면 `#if DEBUG` 제거 가능 (Logger.debug가 릴리즈에서 자동 제거하므로)
9. **Privacy**: 초기 마이그레이션에서는 미지정 (`.debug` 레벨은 릴리즈에서 제거). 추후 `.info` 이상 검토
10. **Git 규칙**: 각 Phase 전후 커밋 (50줄 이상 수정)
11. **파일 삭제**: Log.swift 삭제는 Phase 6에서 사용자 확인 후 진행

---

## 수정해야 할 주요 파일 목록

| 파일 | 경로 |
|------|------|
| Log.swift (삭제 대상) | `Sources/AppCore/Services/Log.swift` |
| Logger+App.swift (신규) | `Sources/AppCore/Services/Logger+App.swift` |
| ViewerViewController.swift | `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift` |
| PhotoPageViewController.swift | `PickPhoto/PickPhoto/Features/Viewer/PhotoPageViewController.swift` |
| VideoPageViewController.swift | `PickPhoto/PickPhoto/Features/Viewer/VideoPageViewController.swift` |
| GridScroll.swift | `PickPhoto/PickPhoto/Features/Grid/GridScroll.swift` |
| SimilarityAnalysisQueue.swift | `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift` |
| CLAUDE.md | `/Users/karl/Project/Photos/iOS/CLAUDE.md` |

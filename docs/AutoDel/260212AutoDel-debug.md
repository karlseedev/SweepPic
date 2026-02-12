# AutoCleanup DEBUG/테스트 코드 삭제 기록

> 작성일: 2026-02-12
> 목적: 개발 중 사용한 인라인 DEBUG/테스트 코드 정리 (production 전환)

## 삭제 원칙

- **별도 파일** (Debug/ 폴더): 유지
- **인라인 `#if DEBUG`**: 전체 삭제 (로그 포함)
- **테스트 전용 프로퍼티/메서드**: 삭제

## 유지된 파일 (Debug/ 폴더)

| 파일 | 용도 |
|------|------|
| `Debug/CompareAnalysisTester.swift` | 통합 로직 비교 테스트 (경로1 vs 경로2) |
| `Debug/ModeComparisonTester.swift` | 3모드 비교 테스트 (완화/기본/강화) |
| `Debug/AestheticsOnlyTester.swift` | AestheticsScore 전용 테스트 |
| `Debug/PhotoCell+CompareBadge.swift` | 비교 테스트 배지 표시 |
| `Debug/AutoScrollTester.swift` | 자동 스크롤 테스트 (AutoCleanup 무관) |
| `Debug/YearLoadingAlertTester.swift` | 연도 로딩 테스트 (AutoCleanup 무관) |

---

## 삭제 내역

### 1. GridViewController+Cleanup.swift

**`#if !DEBUG` 휴지통 체크 가드 제거** (→ 항상 체크하도록 변경)
```swift
// 삭제 전: DEBUG에서는 휴지통 체크 스킵
#if !DEBUG
if !CleanupService.shared.isTrashEmpty() { ... }
#endif

// 삭제 후: 항상 휴지통 체크
if !CleanupService.shared.isTrashEmpty() { ... }
```

**`#if DEBUG` delegate 메서드 구현** (~12줄)
```swift
#if DEBUG
func cleanupMethodSheetDidSelectIntegratedTest(...)
func cleanupMethodSheetDidSelectModeTest(...)
#endif
```

**통합 로직 테스트 extension** (~95줄)
```swift
#if DEBUG
extension GridViewController {
    func startIntegratedLogicTest(continueFromLast:)
    func showIntegratedLogicResult(...)
}
#endif
```

**3모드 비교 테스트 extension** (~95줄)
```swift
#if DEBUG
extension GridViewController {
    func startModeComparisonTest(continueFromLast:)
    func showModeComparisonResult(...)
}
#endif
```

### 2. CleanupMethodSheet.swift

**프로토콜 DEBUG 메서드** (~9줄)
```swift
#if DEBUG
func cleanupMethodSheetDidSelectIntegratedTest(...)
func cleanupMethodSheetDidSelectModeTest(...)
#endif
```

**빈 DEBUG 블록** (~4줄)
```swift
#if DEBUG
if #available(iOS 18.0, *) {
    // 통합 테스트 / 3모드 비교 테스트 — 필요 시 여기에 추가
}
#endif
```

### 3. CleanupService.swift

**인라인 로그 8곳** (각 2~10줄)
- 정리 취소 로그
- 정리 일시정지/재개 로그
- 스캔 시작 로그
- 50장 도달 로그
- 배치 완료 상세 로그 (SKIP 통계 포함)
- 휴지통 이동 로그
- 세션 저장 로그

### 4. CleanupSessionStore.swift

**인라인 로그 12곳** (각 2~3줄)
- 세션 로드 성공/실패 로그 (sync/async 각 2쌍)
- 세션 저장 로그 (latest/byYear)
- 세션 파일 삭제 성공/실패 로그
- 세션 저장 실패 로그

**디버그 전용 extension** (~33줄)
```swift
#if DEBUG
extension CleanupSessionStore {
    func debugPrintSession()
    func debugSaveTestSession()
}
#endif
```

### 5. CleanupConstants.swift

**디버그 임계값 오버라이드 extension** (~22줄)
```swift
#if DEBUG
extension CleanupConstants {
    static var isDebugOverrideEnabled: Bool    // UserDefaults 기반
    static var debugExtremeDarkLuminance: Double
    static var debugSevereBlurLaplacian: Double
}
#endif
```

### 6. CleanupPreviewService.swift

**debugLightLimit 프로퍼티 + 사용 코드** (~12줄)
```swift
// 프로퍼티
private let debugLightLimit: Int = 50  // 삭제

// 사용 코드 (내부 루프 + 외부 루프 중단)
if debugLightLimit > 0 && lightCandidates.count >= debugLightLimit { break }
```
- TODO 주석도 함께 삭제

### 7. QualityAnalyzer.swift

**인라인 로그 9곳** (각 2~8줄)
- 동영상 1초 미만 저품질 로그
- SafeGuard face check 실패 로그
- 텍스트 감지 상세 로그 (completion 진입, 중복 resume 방지, perform 시작/종료)
- 동영상 프레임 추출 실패 로그
- 동영상 분석 결과 로그
- 프레임 노출/블러 분석 실패 로그

**디버그 전용 extension** (~36줄)
```swift
#if DEBUG
extension QualityAnalyzer {
    func debugAnalyze(_ asset: PHAsset) async -> String
}
#endif
```

### 8. TrashAlbumViewController.swift

**휴지통 셀 비교 분석 배지 표시** (~12줄)
```swift
#if DEBUG
if #available(iOS 18.0, *) {
    // ModeCategoryStore / CompareCategoryStore 참조하여 배지 표시
    cell.setModeBadge(modeCategory)
    cell.setCompareBadge(category)
}
#endif
```

### 9. BlurAnalyzer.swift

**디버그 description extension** (~18줄)
```swift
#if DEBUG
extension BlurMetrics: CustomStringConvertible {
    var description: String { ... }  // Laplacian 값 + Severe/Mild/Sharp 상태
}
#endif
```

### 10. MetadataFilter.swift

**디버그 필터 결과 출력 extension** (~27줄)
```swift
#if DEBUG
extension MetadataFilter {
    func debugFilter(_ asset: PHAsset) -> String  // SKIP/ANALYZE 결과 + 메타데이터 상세
}
#endif
```

### 11. PHAsset+Cleanup.swift

**디버그 요약 정보 extension** (~32줄)
```swift
#if DEBUG
extension PHAsset {
    var debugSummary: String  // ID, Type, Size, Date, Favorite, Screenshot 등
}
#endif
```

### 12. AestheticsAnalyzer.swift

**디버그 description extension** (~22줄)
```swift
#if DEBUG
@available(iOS 18.0, *)
extension AestheticsMetrics: CustomStringConvertible {
    var description: String { ... }  // score + utility + Low Quality/Acceptable 상태
}
#endif
```

### 13. VideoFrameExtractor.swift

**인라인 로그** (~3줄)
```swift
#if DEBUG
Log.print("[VideoFrameExtractor] 프레임 추출 실패 ...")
#endif
```

**디버그 프레임 추출 extension** (~27줄)
```swift
#if DEBUG
extension VideoFrameExtractor {
    func debugExtractFrames(from asset: PHAsset) async -> String
}
#endif
```

### 14. ExposureAnalyzer.swift

**디버그 description extension** (~16줄)
```swift
#if DEBUG
extension ExposureMetrics: CustomStringConvertible {
    var description: String { ... }  // Luminance, RGB Std, Center/Corner, Vignetting
}
#endif
```

### 15. SafeGuardChecker.swift

**디버그 얼굴 품질 분석 extension** (~33줄)
```swift
#if DEBUG
extension SafeGuardChecker {
    func debugFaceQualityAnalysis(_ image: CGImage) async throws -> String
}
#endif
```

---

### 16. ViewerViewController.swift

**디버그 분석 버튼 + 관련 메서드** (~130줄)
```swift
#if DEBUG
private lazy var debugAnalyzeButton: UIButton = { ... }()
#endif

#if DEBUG
if viewerMode == .trash { setupDebugAnalyzeButton() }
#endif

#if DEBUG
func setupDebugAnalyzeButton()
func debugAnalyzeButtonTapped()     // 현재 이미지 재분석
func debugPrintExposureMetrics()    // 노출 분석 상세
func debugPrintTextDetection()      // Vision 텍스트 감지 테스트
#endif
```

---

## 삭제 통계

| 항목 | 수량 |
|------|------|
| 수정 파일 | 16개 |
| 삭제된 `#if DEBUG` 블록 | ~50개 |
| 삭제된 코드 라인 (추정) | ~840줄 |
| 유지된 Debug/ 파일 | 6개 |

## 비고

- `CleanupSessionStore.isTestInstance` + `init(filePath:)`: 유닛 테스트 인프라이므로 유지
- `CleanupPreviewService.maxScanCount`: production 값 2000 확정 (TODO 주석 삭제)
- `CleanupService.pauseCleanup()/resumeCleanup()`: 기능 메서드이므로 유지 (내부 로그만 삭제)

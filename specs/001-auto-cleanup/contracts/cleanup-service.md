# Internal Contracts: 저품질 사진 자동 정리

**Feature**: 001-auto-cleanup
**Date**: 2026-01-21

---

## 1. CleanupServiceProtocol

정리 실행 서비스의 메인 인터페이스.

```swift
/// 정리 서비스 프로토콜
protocol CleanupServiceProtocol: AnyObject {

    // MARK: - 상태 조회

    /// 현재 진행 중인 세션
    var currentSession: CleanupSession? { get }

    /// 이전 세션 (이어서 정리용)
    var lastSession: CleanupSession? { get }

    /// 정리 진행 중 여부
    var isRunning: Bool { get }

    // MARK: - 정리 실행

    /// 정리 시작
    /// - Parameters:
    ///   - method: 정리 방식 (최신사진부터/이어서/연도별)
    ///   - mode: 판별 모드 (Precision/Recall) - 1차에서는 Precision만
    ///   - progressHandler: 진행 상황 콜백
    ///   - completion: 완료 콜백
    func startCleanup(
        method: CleanupMethod,
        mode: JudgmentMode,
        progressHandler: @escaping (CleanupProgress) -> Void,
        completion: @escaping (Result<CleanupResult, CleanupError>) -> Void
    )

    /// 정리 취소
    /// 아무것도 휴지통으로 이동하지 않고 즉시 종료
    func cancelCleanup()

    /// 정리 일시정지 (백그라운드 전환 시)
    func pauseCleanup()

    /// 정리 재개 (포그라운드 복귀 시)
    func resumeCleanup()
}

/// 정리 진행 상황
struct CleanupProgress {
    /// 검색한 사진 수
    let scannedCount: Int
    /// 찾은 저품질 사진 수
    let foundCount: Int
    /// 현재 탐색 시점 (연/월 표시용)
    let currentDate: Date
    /// 진행률 (0.0 ~ 1.0, 최대 스캔 기준)
    let progress: Float
}

/// 정리 에러
enum CleanupError: Error {
    /// 이미 진행 중
    case alreadyRunning
    /// 휴지통이 비어있지 않음
    case trashNotEmpty
    /// 사진 라이브러리 접근 권한 없음
    case noPhotoAccess
    /// 분석 실패
    case analysisFailed(String)
}
```

### 사용 예시

```swift
// 최신 사진부터 정리
cleanupService.startCleanup(
    method: .fromLatest,
    mode: .precision,
    progressHandler: { progress in
        // UI 업데이트
        progressView.update(
            found: progress.foundCount,
            current: progress.currentDate
        )
    },
    completion: { result in
        switch result {
        case .success(let cleanupResult):
            showResultAlert(cleanupResult)
        case .failure(let error):
            showErrorAlert(error)
        }
    }
)
```

---

## 2. QualityAnalyzerProtocol

품질 분석 인터페이스.

```swift
/// 품질 분석기 프로토콜
protocol QualityAnalyzerProtocol {

    /// 사진 품질 분석
    /// - Parameters:
    ///   - asset: 분석할 PHAsset
    ///   - mode: 판별 모드
    /// - Returns: 분석 결과
    func analyze(
        asset: PHAsset,
        mode: JudgmentMode
    ) async throws -> QualityResult

    /// 배치 분석
    /// - Parameters:
    ///   - assets: 분석할 PHAsset 배열
    ///   - mode: 판별 모드
    ///   - concurrency: 동시 분석 수 (기본: 4)
    /// - Returns: 분석 결과 배열
    func analyzeBatch(
        assets: [PHAsset],
        mode: JudgmentMode,
        concurrency: Int
    ) async throws -> [QualityResult]
}
```

### 파이프라인 흐름

```
┌─────────────────────────────────────────────────────────────────┐
│                      QualityAnalyzer                             │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   [PHAsset] ──▶ [iOS 버전 체크]                                   │
│                      │                                           │
│           ┌─────────┴─────────┐                                  │
│           ▼                   ▼                                  │
│      [iOS 18+]           [iOS 16-17]                             │
│           │                   │                                  │
│   ┌───────▼───────┐   ┌──────▼──────┐                           │
│   │ Metadata      │   │ Metadata    │  ◀── Stage 1              │
│   │ Filter        │   │ Filter      │      (즐겨찾기/편집됨 등)    │
│   └───────┬───────┘   └──────┬──────┘                           │
│           │                   │                                  │
│   ┌───────▼───────┐   ┌──────▼──────┐                           │
│   │ Aesthetics    │   │ Exposure    │  ◀── Stage 2              │
│   │ Score         │   │ Analyzer    │      (휘도/색상)            │
│   └───────┬───────┘   └──────┬──────┘                           │
│           │                   │                                  │
│    [실패?]─┼──────┐   ┌──────▼──────┐                           │
│           │      │   │ Blur        │  ◀── Stage 3              │
│           │      │   │ Analyzer    │      (Laplacian)           │
│           │      │   └──────┬──────┘                           │
│           │      │          │                                    │
│   ┌───────▼──────▼──────────▼──────┐                            │
│   │         Safe Guard             │  ◀── Stage 4              │
│   │   (얼굴 품질, 심도 효과)          │      (보호 로직)            │
│   └───────────────┬────────────────┘                            │
│                   │                                              │
│                   ▼                                              │
│            [QualityResult]                                       │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## 3. ExposureAnalyzerProtocol

노출/색상 분석 인터페이스 (Stage 2).

```swift
/// 노출 분석기 프로토콜
protocol ExposureAnalyzerProtocol {

    /// 노출 분석
    /// - Parameters:
    ///   - image: 분석할 이미지 (64×64 권장)
    ///   - mode: 판별 모드
    /// - Returns: 노출 분석 결과
    func analyze(
        image: CGImage,
        mode: JudgmentMode
    ) -> ExposureAnalysisResult
}

/// 노출 분석 결과
struct ExposureAnalysisResult {
    /// 평균 휘도 (0.0 ~ 1.0)
    let meanLuminance: Double
    /// RGB 표준편차
    let rgbStandardDeviation: Double
    /// 비네팅 값 (0.0 ~ 1.0)
    let vignetting: Double
    /// 감지된 신호 목록
    let signals: [QualitySignal]
    /// 조기 종료 여부 (Strong 신호 감지 시)
    let shouldTerminateEarly: Bool
}
```

---

## 4. BlurAnalyzerProtocol

블러 분석 인터페이스 (Stage 3).

```swift
/// 블러 분석기 프로토콜
protocol BlurAnalyzerProtocol {

    /// 블러 분석
    /// - Parameters:
    ///   - image: 분석할 이미지 (256×256 권장)
    ///   - mode: 판별 모드
    /// - Returns: 블러 분석 결과
    func analyze(
        image: CGImage,
        mode: JudgmentMode
    ) async throws -> BlurAnalysisResult
}

/// 블러 분석 결과
struct BlurAnalysisResult {
    /// Laplacian Variance 값
    let laplacianVariance: Double
    /// 감지된 신호 (nil이면 블러 아님)
    let signal: QualitySignal?
    /// Safe Guard 체크 필요 여부
    let needsSafeGuardCheck: Bool
}
```

---

## 5. SafeGuardProtocol

안전장치 인터페이스 (Stage 4).

```swift
/// Safe Guard 프로토콜
protocol SafeGuardProtocol {

    /// Safe Guard 체크
    /// - Parameters:
    ///   - asset: 체크할 PHAsset
    ///   - signal: 무효화 대상 신호 (블러 신호)
    /// - Returns: Safe Guard 결과
    func check(
        asset: PHAsset,
        signal: QualitySignal
    ) async throws -> SafeGuardResult
}

/// Safe Guard 결과
struct SafeGuardResult {
    /// 신호 무효화 여부
    let shouldInvalidate: Bool
    /// 무효화 사유
    let reason: SafeGuardReason?
    /// 얼굴 품질 점수 (감지된 경우)
    let faceQuality: Float?
    /// 심도 효과 여부
    let hasDepthEffect: Bool
}
```

---

## 6. AestheticsAnalyzerProtocol

iOS 18+ AestheticsScore 분석 인터페이스.

```swift
/// Aesthetics 분석기 프로토콜 (iOS 18+)
@available(iOS 18.0, *)
protocol AestheticsAnalyzerProtocol {

    /// Aesthetics 분석
    /// - Parameters:
    ///   - image: 분석할 이미지
    ///   - mode: 판별 모드
    /// - Returns: 분석 결과 (실패 시 nil)
    func analyze(
        image: CIImage,
        mode: JudgmentMode
    ) async -> AestheticsAnalysisResult?
}

/// Aesthetics 분석 결과
struct AestheticsAnalysisResult {
    /// Overall Score (-1 ~ 1)
    let overallScore: Float
    /// isUtility 여부
    let isUtility: Bool
    /// 감지된 신호 (저품질인 경우)
    let signal: QualitySignal?
}
```

---

## 7. CleanupSessionStoreProtocol

세션 저장 인터페이스.

```swift
/// 정리 세션 저장소 프로토콜
protocol CleanupSessionStoreProtocol {

    /// 현재 저장된 세션
    var currentSession: CleanupSession? { get }

    /// 세션 저장
    /// - Parameter session: 저장할 세션
    func save(_ session: CleanupSession)

    /// 세션 로드
    /// - Returns: 저장된 세션 (없으면 nil)
    func load() -> CleanupSession?

    /// 세션 삭제
    func clear()

    /// 세션 업데이트 (부분 저장)
    /// - Parameters:
    ///   - lastAssetDate: 마지막 탐색 날짜
    ///   - lastAssetID: 마지막 탐색 ID
    ///   - scannedCount: 검색 수
    ///   - foundCount: 찾은 수
    func update(
        lastAssetDate: Date?,
        lastAssetID: String?,
        scannedCount: Int,
        foundCount: Int
    )
}
```

---

## 8. Delegate/Callback Contracts

### CleanupServiceDelegate

```swift
/// 정리 서비스 델리게이트
protocol CleanupServiceDelegate: AnyObject {

    /// 진행 상황 업데이트
    func cleanupService(
        _ service: CleanupServiceProtocol,
        didUpdateProgress progress: CleanupProgress
    )

    /// 저품질 사진 발견
    func cleanupService(
        _ service: CleanupServiceProtocol,
        didFindLowQualityAsset assetID: String,
        result: QualityResult
    )

    /// 정리 완료
    func cleanupService(
        _ service: CleanupServiceProtocol,
        didCompleteWith result: CleanupResult
    )

    /// 에러 발생
    func cleanupService(
        _ service: CleanupServiceProtocol,
        didFailWith error: CleanupError
    )
}
```

---

## 9. 상수 정의

```swift
/// 정리 관련 상수
enum CleanupConstants {

    // MARK: - 종료 조건

    /// 최대 찾기 수
    static let maxFoundCount = 50

    /// 최대 검색 수
    static let maxScanCount = 1000

    // MARK: - 성능

    /// 배치 크기
    static let batchSize = 100

    /// 동시 분석 수
    static let concurrentAnalysis = 4

    /// 노출 분석 다운샘플 크기
    static let exposureAnalysisSize = CGSize(width: 64, height: 64)

    /// 블러 분석 다운샘플 크기
    static let blurAnalysisSize = CGSize(width: 256, height: 256)

    // MARK: - 임계값 (Precision 모드)

    /// 극단 어두움 휘도
    static let extremeDarkLuminance: Double = 0.10

    /// 극단 밝음 휘도
    static let extremeBrightLuminance: Double = 0.90

    /// 심각 블러 Laplacian
    static let severeBlurLaplacian: Double = 50

    /// 일반 블러 Laplacian
    static let generalBlurLaplacian: Double = 100

    /// 극단 단색 RGB Std
    static let extremeMonochromeRgbStd: Double = 10

    /// 낮은 색상 다양성 RGB Std
    static let lowColorVarietyRgbStd: Double = 15

    /// 얼굴 품질 임계값
    static let faceQualityThreshold: Float = 0.4

    /// 비네팅 임계값 (주머니 샷)
    static let pocketShotVignetting: Double = 0.05

    // MARK: - iOS 18+ AestheticsScore

    /// Precision 모드 임계값
    static let aestheticsPrecisionThreshold: Float = -0.3

    /// Recall 모드 임계값
    static let aestheticsRecallThreshold: Float = 0.0

    // MARK: - Weak 가중치

    /// 일반 블러 가중치
    static let generalBlurWeight = 2

    /// 기타 Weak 신호 가중치
    static let otherWeakWeight = 1

    /// Weak 합산 임계값
    static let weakSumThreshold = 3
}
```

---

## 10. 에러 처리 계약

```swift
/// 분석 에러
enum AnalysisError: Error {
    /// 이미지 로드 실패
    case imageLoadFailed(assetID: String)
    /// Metal 초기화 실패
    case metalInitFailed
    /// Vision API 실패
    case visionFailed(Error)
    /// AestheticsScore 실패 (iOS 18+ 전용)
    case aestheticsFailed
    /// 타임아웃
    case timeout
}

/// 에러 처리 정책
/// - imageLoadFailed: SKIP (건너뜀)
/// - metalInitFailed: 전체 정리 중단
/// - visionFailed: SKIP (개별 사진)
/// - aestheticsFailed: Metal 파이프라인 fallback
/// - timeout: SKIP (개별 사진)
```

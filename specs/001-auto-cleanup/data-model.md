# Data Model: 저품질 사진 자동 정리

**Feature**: 001-auto-cleanup
**Date**: 2026-01-21

---

## Entity Relationship

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────────┐
│ CleanupSession  │────▶│  QualityResult  │────▶│  QualitySignal  │
└─────────────────┘     └─────────────────┘     └─────────────────┘
        │                                               │
        │                                               ▼
        │                                       ┌─────────────────┐
        │                                       │   SignalType    │
        │                                       │ (Strong/Cond/   │
        │                                       │  Weak)          │
        │                                       └─────────────────┘
        │
        ▼
┌─────────────────┐     ┌─────────────────┐
│  CleanupResult  │────▶│   TrashStore    │ (기존)
└─────────────────┘     └─────────────────┘
```

---

## 1. CleanupSession

정리 세션 상태. 파일로 저장되어 "이어서 정리" 기능 지원.

```swift
/// 정리 세션 상태
/// 파일 기반 저장으로 앱 재시작 후에도 유지
struct CleanupSession: Codable {

    // MARK: - 식별자

    /// 세션 ID (UUID)
    let id: UUID

    /// 세션 생성 시간
    let createdAt: Date

    // MARK: - 탐색 위치

    /// 시작점 (정리 방식에 따라 다름)
    /// - 최신사진부터: 가장 최근 사진
    /// - 이어서 정리: 이전 세션의 lastAssetDate
    /// - 연도별: 해당 연도 12월 31일
    let startDate: Date

    /// 마지막 탐색 사진의 creationDate
    /// "이어서 정리"의 시작점으로 사용
    var lastAssetDate: Date?

    /// 마지막 탐색 사진의 localIdentifier
    /// 같은 날짜 내 정확한 위치 추적용
    var lastAssetID: String?

    // MARK: - 정리 방식

    /// 정리 방식
    let method: CleanupMethod

    /// 판별 모드 (1차에서는 Precision만 사용)
    let mode: JudgmentMode

    // MARK: - 진행 상황

    /// 검색한 사진 수
    var scannedCount: Int = 0

    /// 찾은 저품질 사진 수
    var foundCount: Int = 0

    /// 휴지통으로 이동한 사진 ID 목록
    var trashedAssetIDs: [String] = []

    // MARK: - 상태

    /// 세션 상태
    var status: SessionStatus = .idle

    /// 마지막 업데이트 시간
    var updatedAt: Date
}

/// 정리 방식
enum CleanupMethod: String, Codable {
    /// 최신 사진부터
    case fromLatest
    /// 이어서 정리
    case continueFromLast
    /// 연도별 정리
    case byYear(year: Int)

    // Codable 구현 필요 (associated value)
}

/// 판별 모드
enum JudgmentMode: String, Codable {
    /// 신중한 정리 (Strong 신호만)
    case precision
    /// 적극적 정리 (Strong + Conditional + Weak)
    case recall
}

/// 세션 상태
enum SessionStatus: String, Codable {
    /// 대기 중
    case idle
    /// 탐색 중
    case scanning
    /// 일시정지 (백그라운드)
    case paused
    /// 완료
    case completed
    /// 취소됨
    case cancelled
}
```

### Validation Rules
- `scannedCount` <= 1,000 (최대 검색 수)
- `foundCount` <= 50 (최대 찾기 수)
- `trashedAssetIDs.count` == `foundCount`
- `lastAssetDate` <= `startDate`

### State Transitions
```
idle → scanning (정리 시작)
scanning → paused (백그라운드 전환)
paused → scanning (포그라운드 복귀)
scanning → completed (종료 조건 충족)
scanning → cancelled (사용자 취소)
```

---

## 2. QualitySignal

품질 판정 신호. 분석 결과를 표현.

```swift
/// 품질 판정 신호
struct QualitySignal {

    /// 신호 타입
    let type: SignalType

    /// 신호 종류
    let kind: SignalKind

    /// 측정된 값 (디버깅/로깅용)
    let measuredValue: Double

    /// 임계값 (디버깅/로깅용)
    let threshold: Double
}

/// 신호 타입 (Strong/Conditional/Weak)
enum SignalType {
    /// 단일 조건으로 즉시 저품질 확정
    case strong
    /// 기술적 실패지만 오탐 위험 (Recall 모드에서만 사용)
    case conditional
    /// 가중치 합산용 (Recall 모드에서만 사용)
    case weak(weight: Int)
}

/// 신호 종류
enum SignalKind: String {
    // Strong
    case extremeDark        // 극단 어두움 (휘도 < 0.10)
    case extremeBright      // 극단 밝음 (휘도 > 0.90)
    case severeBlur         // 심각 블러 (Laplacian < 50)

    // Conditional (Recall only)
    case pocketShot         // 주머니 샷 (복합 조건)
    case extremeMonochrome  // 극단 단색
    case lensBlocked        // 렌즈 가림

    // Weak (Recall only)
    case generalBlur        // 일반 블러 (Laplacian < 100) - 2점
    case generalExposure    // 일반 노출 (0.15-0.85) - 1점
    case lowColorVariety    // 낮은 색상 다양성 (RGB Std < 15) - 1점
    case lowResolution      // 저해상도 (< 1MP) - 1점

    // iOS 18+ AestheticsScore
    case lowAesthetics      // 낮은 미적 점수
}
```

---

## 3. QualityResult

개별 사진 분석 결과.

```swift
/// 사진 품질 분석 결과
struct QualityResult {

    /// 사진 ID
    let assetID: String

    /// 최종 판정
    let verdict: QualityVerdict

    /// 감지된 신호 목록
    let signals: [QualitySignal]

    /// Safe Guard 적용 여부
    let safeGuardApplied: Bool

    /// Safe Guard 사유 (적용된 경우)
    let safeGuardReason: SafeGuardReason?

    /// 분석 소요 시간 (ms)
    let analysisTimeMs: Double

    /// 분석 방법 (iOS 18+ AestheticsScore vs Metal)
    let analysisMethod: AnalysisMethod
}

/// 품질 판정 결과
enum QualityVerdict {
    /// 저품질 (휴지통 이동 대상)
    case lowQuality
    /// 정상
    case acceptable
    /// 분석 건너뜀 (iCloud 전용, 메타데이터 필터 등)
    case skipped(reason: SkipReason)
}

/// 건너뜀 사유
enum SkipReason: String {
    case favorite           // 즐겨찾기
    case edited             // 편집됨
    case hidden             // 숨김
    case sharedAlbum        // 공유 앨범
    case screenshot         // 스크린샷
    case iCloudOnly         // iCloud 전용 (로컬 캐시 없음)
    case analysisError      // 분석 실패
    case longVideo          // 10분 초과 비디오
}

/// Safe Guard 사유
enum SafeGuardReason: String {
    case depthEffect        // 심도 효과
    case clearFace          // 선명한 얼굴 (Quality >= 0.4)
}

/// 분석 방법
enum AnalysisMethod: String {
    case aestheticsScore    // iOS 18+ AestheticsScore
    case metalPipeline      // Metal Laplacian + Luminance
    case fallback           // AestheticsScore 실패 후 Metal
}
```

---

## 4. CleanupResult

전체 정리 결과.

```swift
/// 정리 결과
struct CleanupResult {

    /// 세션 ID
    let sessionID: UUID

    /// 결과 유형
    let resultType: CleanupResultType

    /// 검색한 사진 수
    let scannedCount: Int

    /// 찾은 저품질 사진 수
    let foundCount: Int

    /// 휴지통으로 이동한 사진 ID 목록
    let trashedAssetIDs: [String]

    /// 총 소요 시간 (초)
    let totalTimeSeconds: Double

    /// 탐색 종료 사유
    let endReason: EndReason
}

/// 결과 유형
enum CleanupResultType {
    /// 정상 완료 (N장 이동)
    case completed(count: Int)
    /// 0장 발견
    case noneFound
    /// 사용자 취소 (아무것도 이동하지 않음)
    case cancelled
}

/// 종료 사유
enum EndReason: String {
    case maxFound           // 50장 찾음
    case maxScanned         // 1,000장 검색
    case endOfRange         // 범위 끝 (연도별/가장 오래된 사진)
    case userCancelled      // 사용자 취소
}
```

---

## 5. 기존 모델 연동

### TrashStore (기존)

자동 정리 기능에서 활용할 기존 API:

```swift
// 기존 API 사용
func moveToTrash(assetIDs: [String])
var trashedAssetIDs: Set<String>
var trashedCount: Int

// 신규 추가 (선택적 - 배치 성능 최적화)
func moveToTrashBatch(assetIDs: [String], completion: @escaping (Result<Void, TrashStoreError>) -> Void)
```

### PHAsset 확장

```swift
extension PHAsset {

    /// Safe Guard 조기 필터 조건 확인
    var shouldSkipForCleanup: Bool {
        // 즐겨찾기
        if isFavorite { return true }
        // 편집됨
        if hasAdjustments { return true }
        // 숨김
        if isHidden { return true }
        // 스크린샷
        if mediaSubtypes.contains(.photoScreenshot) { return true }
        return false
    }

    /// 저해상도 여부 (< 1MP)
    var isLowResolution: Bool {
        return pixelWidth * pixelHeight < 1_000_000
    }

    /// 긴 비디오 여부 (> 10분)
    var isLongVideo: Bool {
        guard mediaType == .video else { return false }
        return duration > 600 // 10분 = 600초
    }
}
```

---

## 6. 저장 형식

### CleanupSession.json

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "createdAt": "2026-01-21T10:30:00Z",
  "startDate": "2026-01-21T10:30:00Z",
  "lastAssetDate": "2026-01-15T14:22:00Z",
  "lastAssetID": "ABC123...",
  "method": "fromLatest",
  "mode": "precision",
  "scannedCount": 342,
  "foundCount": 23,
  "trashedAssetIDs": ["ABC123...", "DEF456..."],
  "status": "completed",
  "updatedAt": "2026-01-21T10:35:00Z"
}
```

### 저장 위치

```
Documents/
├── TrashState.json         # 기존 휴지통 상태
└── CleanupSession.json     # 정리 세션 상태 (이어서 정리용)
```

---

## 7. 제약 조건 요약

| 항목 | 제약 |
|-----|------|
| 최대 검색 수 | 1,000장 |
| 최대 찾기 수 | 50장 |
| Weak 점수 합산 | >= 3점이면 저품질 |
| 비디오 최대 길이 | 10분 |
| 저해상도 기준 | < 1MP (1,000,000 픽셀) |
| 세션 저장 | 파일 기반, 앱 재시작 후 유지 |

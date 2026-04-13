# FaceScan ↔ Grid 동등성 검증 하네스 구현 계획 (최종)

## 목적

FaceScan 결과가 Grid 결과와 같은지 검증하는 도구를 만든다.
구조 수정 착수 전에 이 하네스를 먼저 만든다.

이 하네스는 두 단계로 구성된다:

- **Stage 1 (Engine Equivalence)**: 같은 입력 범위에서 Grid 엔진과 FaceScan 엔진의 알고리즘 결과를 자동 비교한다. 반복 실행 가능하며 개발 중 주 사용 도구다.
- **Stage 2 (Live Grid Verification)**: 사용자가 실제 Grid에서 본 최종 상태와 FaceScan 결과를 비교한다. 수동 확인이며 출시 전 최종 승인용이다.

**왜 두 단계가 필요한가:**

Stage 1만으로는 "사용자가 보던 것과 같다"고 단정할 수 없다. Grid는 스크롤마다 윈도우 분석 결과가 shared cache에 누적되며, mergeOverlappingGroups가 작동한다. Stage 1의 oracle(전체 범위 1회 실행)은 이 누적 과정을 거치지 않으므로 live 결과와 다를 수 있다.

Stage 2만으로는 원인 분리가 불가능하다. live 결과가 다를 때, 알고리즘 차이인지 윈도우/누적 차이인지 알 수 없다.

따라서:
- **Stage 1은 원인 분리용** (알고리즘 동등성)
- **Stage 2는 최종 승인용** (사용자 경험 동등성)

**하네스 ≈ 수정안:**
Stage 1의 Grid oracle은 격리 인스턴스에서 `formGroupsForRange()`를 그대로 호출한다. FP 생성, 그루핑, 얼굴 감지, slot 필터링이 모두 이 함수 안에 포함되어 있다. 수정안은 FaceScan이 이와 같은 방식으로 `formGroupsForRange()`를 격리 호출하는 것이므로, 하네스가 올바르게 동작하면 수정안의 방향도 검증된 것이다.

---

## 핵심 원칙

### 원칙 1. production 로직을 바꾸지 않는다

- `formGroups()` 재구현 또는 리팩터링 금지
- FaceScan overlap/excludeAssets/hasAnyFace 수정 금지
- Grid 로직 수정 금지
- 기존 메서드 시그니처 변경 금지
- `formGroupsForRange()` 내부의 core 추출/분리 금지 (이번 단계에서는)

비교기가 현재 production 경로를 있는 그대로 호출해야 수집 데이터가 의미 있다.

### 원칙 2. debug 진입점만 추가한다

추가하는 것은 `#if DEBUG` 블록 내의 코드뿐이다.

### 원칙 3. 캐시 오염을 원천 차단한다

`SimilarityCache.shared.clear()`를 호출하지 **않는다.**

Stage 1은 새 인스턴스를 주입하여 격리한다:
- `SimilarityAnalysisQueue.init(cache:)`가 cache 주입을 지원한다 (기본값: `.shared`). (SimilarityAnalysisQueue.swift:158)
- `FaceScanService.init(cache:)`가 cache 주입을 지원한다. (FaceScanService.swift:85)
- 두 인스턴스 모두 내부에서 새 `PersonMatchingEngine()`을 자동 생성한다.

Stage 2는 production 동작을 **관찰만** 한다. 변경하지 않는다.

### 원칙 4. 부수효과를 명시적으로 억제한다

격리 인스턴스가 해결하는 것은 **캐시 격리뿐**이다.
`formGroupsForRange()` 내부에는 캐시 외의 부수효과가 3곳 있다:

| 위치 | 부수효과 | 억제 방법 |
|------|---------|----------|
| SimilarityAnalysisQueue.swift:476 | `AnalyticsService.shared.countSimilarAnalysisCompleted(...)` | `#if DEBUG` + `self !== .shared` 가드 |
| SimilarityAnalysisQueue.swift:479 | `postAnalysisComplete(...)` (global notification) | `#if DEBUG` + `self !== .shared` 가드 |
| SimilarityAnalysisQueue.swift:235 | `AnalyticsService.shared.countSimilarAnalysisCancelled()` | `#if DEBUG` + `self !== .shared` 가드 |

이 3곳에 `#if DEBUG` 가드를 삽입하여, 격리 인스턴스(`self !== .shared`)에서는 부수효과를 발생시키지 않는다.

### 원칙 5. 비교 단위는 정렬된 멤버 집합이다

비교 시 무시: `groupID`, 그룹 발견 순서, UI 표시 순서.
비교 기준: `Set(memberAssetIDs)` — 완전 일치만 통과.

---

## 현재 코드 기준 사실 정리

### Grid production 경로

`SimilarityAnalysisQueue.formGroupsForRange(range:source:fetchResult:)` (SimilarityAnalysisQueue.swift:263)

이 함수는 FP 생성부터 최종 그룹 저장까지 전체 파이프라인을 포함한다:

1. `fetchPhotos(in:range:fetchResult:)` — 삭제대기함 제외
2. `matchingEngine.generateFeaturePrints(for:)` — FP 생성 + 얼굴 유무 확인
3. `analyzer.formGroups(featurePrints:photoIDs:threshold:)` — 인접 거리 그루핑
4. 각 rawGroup에 대해 `assignPersonIndicesForGroup(assetIDs:photos:)` — 얼굴 감지 + 인물 매칭
5. validSlots 계산 → validMembers 필터링
6. `cache.addGroupIfValid(members:validSlots:photoFaces:)` — 최종 그룹 저장 (mergeOverlappingGroups 포함)
7. `AnalyticsService.shared.countSimilarAnalysisCompleted(...)` — analytics (부수효과)
8. `postAnalysisComplete(...)` — global notification (부수효과)

중요: Grid는 `hasAnyFace` 게이트가 **없다**. rawGroups 전부를 YuNet/SFace까지 보낸다.
중요: Grid는 request 여러 개가 shared cache 위에 누적된다.
중요: FP 생성이 함수 내부에 포함되어 있으므로, FP만 따로 배치할 수 없다. 함수를 호출하면 FP 생성부터 그룹 저장까지 일괄 실행된다.

### FaceScan production 경로

`FaceScanService.analyze(method:onGroupFound:onProgress:)` (FaceScanService.swift:117)

1. `buildFetchResult(method:)` — 최신순 정렬, method별 predicate
2. `findStartIndex(method:fetchResult:)` — 이어서 스캔 시 시작점
3. 청크 루프 (chunkSize=20, chunkOverlap=3)
4. 각 청크: `analyzeChunk(photos:excludeAssets:)`
   - FP 생성 + `formGroups()` 호출
   - Step 2.5: excludeAssets 사전 필터
   - `hasAnyFace` 게이트 (Vision 얼굴 없으면 스킵)
   - `assignPersonIndicesForGroup()` — 얼굴 감지 + 인물 매칭
   - Step 5.5: overlap 멤버 제거
   - `FaceScanCache.addGroup()`

### 두 경로의 구조적 차이

| 항목 | Grid | FaceScan |
|------|------|----------|
| formGroups 호출 | 범위 전체를 한 번에 | 20장 청크 단위 |
| hasAnyFace 게이트 | 없음 | 있음 |
| overlap/excludeAssets | 없음 | 있음 |
| 캐시 | SimilarityCache (shared, 누적) | FaceScanCache (독립) |
| 그룹 병합 | mergeOverlappingGroups | 없음 |

---

## Stage 1: Engine Equivalence

### 목적

같은 명시적 입력 범위에서 Grid 엔진 결과와 FaceScan 결과가 같은지 확인한다.
이 단계는 **원인 분리 단계**이며, 최종 승인 기준이 아니다.

여기서 다르면 live Grid 비교까지 갈 필요 없이 알고리즘 또는 입력 처리부터 다르다는 뜻이다.

### 동일 입력 계약

1. 같은 `FaceScanMethod`로 생성한 `PHFetchResult`
2. 같은 정렬 (`creationDate DESC`)
3. 같은 명시적 `ClosedRange<Int>`
4. 같은 삭제대기함 제외
5. 같은 clamp 결과

### 캐시 격리 + 부수효과 억제

```
Grid oracle:
  SimilarityCache()                      ← 새 인스턴스
  SimilarityAnalysisQueue(cache: ↑)      ← 새 인스턴스 (self !== .shared)
  → formGroupsForRange() 호출 (production 코드 그대로)
  → 캐시: 새 인스턴스에만 저장됨. SimilarityCache.shared 무관.
  → analytics: self !== .shared 가드로 억제됨.
  → notification: self !== .shared 가드로 억제됨.

FaceScan debug:
  FaceScanCache()                        ← 새 인스턴스
  FaceScanService(cache: ↑)              ← 새 인스턴스
  → analyzeDebugRange() 호출 (production analyzeChunk 그대로)
  → 기존 FaceScanCache 무관
```

### 구현 파일

#### 파일 1: `SweepPic/SweepPic/Debug/FaceScanGridEquivalenceTester.swift` (신규)

전체가 `#if DEBUG`. 릴리즈 빌드 미포함.

**타입 정의:**

```swift
#if DEBUG
struct GroupSignature: Hashable, Codable {
    let members: [String]   // sorted
}

struct EngineEquivalenceReport: Codable {
    let timestamp: Date
    let methodDescription: String
    let fetchResultCount: Int
    let requestedRange: ClosedRange<Int>
    let clampedRange: ClosedRange<Int>?
    let gridAnalyzedAssetIDs: [String]
    let faceScanAnalyzedAssetIDs: [String]
    let gridGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
    let faceScanTerminationReason: FaceScanDebugTerminationReason
    let passed: Bool
}

enum FaceScanDebugTerminationReason: String, Codable {
    case naturalEnd
    case maxScanCount
    case maxGroupCount
    case cancelled
}
#endif
```

**메인 클래스:**

```swift
#if DEBUG
final class FaceScanGridEquivalenceTester {

    func runEngineEquivalence(
        method: FaceScanMethod,
        range: ClosedRange<Int>? = nil
    ) async throws -> EngineEquivalenceReport
}
#endif
```

**runEngineEquivalence() 내부 단계:**

Step 1. fetchResult 생성:
```swift
let faceScanService = FaceScanService(cache: FaceScanCache())
let fetchResult = faceScanService.debugBuildFetchResult(method: method)
```

Step 2. 범위 보정:
```swift
guard fetchResult.count > 0 else { return emptyReport }
let maxRange = 0...(fetchResult.count - 1)
let clampedRange = range.map { $0.clamped(to: maxRange) } ?? maxRange
guard clampedRange.lowerBound <= clampedRange.upperBound else { return emptyReport }
```

Step 3. Grid oracle 실행 (격리 인스턴스에서 formGroupsForRange 직접 호출):
```swift
let gridCache = SimilarityCache()
let gridQueue = SimilarityAnalysisQueue(cache: gridCache)
// formGroupsForRange()를 격리 인스턴스에서 그대로 호출한다.
// FP 생성, 그루핑, 얼굴 감지, slot 필터링이 모두 이 함수 안에서 실행된다.
// self !== .shared 가드에 의해 analytics/notification은 억제된다.
let gridGroupIDs = await gridQueue.formGroupsForRange(
    clampedRange, source: .grid, fetchResult: fetchResult
)

// 결과 추출 (격리된 gridCache에서 읽기)
var gridGroups: [[String]] = []
for groupID in gridGroupIDs {
    let members = await gridCache.getGroupMembers(groupID: groupID)
    if !members.isEmpty { gridGroups.append(members) }
}
```

Step 4. FaceScan 실행 (격리):
```swift
let faceScanCache = FaceScanCache()
let faceScanService2 = FaceScanService(cache: faceScanCache)
let faceScanResult = await faceScanService2.analyzeDebugRange(
    fetchResult: fetchResult, range: clampedRange
)
```

Step 5. 입력 동등성 사전 검증:
```swift
let gridPhotos = gridQueue.debugFetchPhotos(in: clampedRange, fetchResult: fetchResult)
let gridInputIDs = Set(gridPhotos.map(\.localIdentifier))
let faceScanInputIDs = Set(faceScanResult.analyzedAssetIDs)
// 불일치 시 로그 출력, 비교는 계속 진행 (원인 추적용)
```

Step 6. 정규화 + diff:
```swift
let gridSigs = Set(gridGroups.map { GroupSignature(members: $0.sorted()) })
let fsSigs = Set(faceScanResult.groups.map { GroupSignature(members: $0.memberAssetIDs.sorted()) })
let common = gridSigs.intersection(fsSigs)
let gridOnly = gridSigs.subtracting(fsSigs)
let faceScanOnly = fsSigs.subtracting(gridSigs)
```

Step 7. 로그 + JSON 저장:

Logger 출력:
```
[Engine Equivalence] PASS (또는 FAIL)
  범위: 0...99 (fetchResult: 5000장)
  입력: Grid 92장, FaceScan 92장
  그룹: Grid 5개, FaceScan 3개
  일치: 3개, Grid에만: 2개, FaceScan에만: 0개
```

JSON: `/tmp/facescan-engine-equivalence-{timestamp}.json` + `*-latest.json`

**PASS/FAIL 판정:**

- `gridOnly.isEmpty && faceScanOnly.isEmpty` → PASS
- `faceScanTerminationReason == .maxGroupCount`이고 `gridOnly`만 있고 `faceScanOnly`가 없으면 → PARTIAL (상한 내 일치, 상한 초과 미검증)
- 그 외 → FAIL

#### 파일 2: `FaceScanService.swift` 수정 (#if DEBUG)

추가 1: fetchResult builder 노출

```swift
#if DEBUG
func debugBuildFetchResult(method: FaceScanMethod) -> PHFetchResult<PHAsset> {
    buildFetchResult(method: method)
}
#endif
```

추가 2: 명시적 range 분석 진입점

```swift
#if DEBUG
struct FaceScanDebugResult {
    let groups: [FaceScanGroup]
    let analyzedAssetIDs: [String]
    let terminationReason: FaceScanDebugTerminationReason
}

func analyzeDebugRange(
    fetchResult: PHFetchResult<PHAsset>,
    range: ClosedRange<Int>
) async -> FaceScanDebugResult
#endif
```

구현 방식:
- production `analyze()`의 청크 루프를 범위 제한 버전으로 작성
- 내부에서 기존 `analyzeChunk(photos:excludeAssets:)`를 **그대로 호출**
- 반드시 유지: chunkSize=20, chunkOverlap=3, excludeAssets, hasAnyFace, Step 2.5/5.5, maxScanCount/maxGroupCount, 삭제대기함 제외
- 반드시 금지: saveSession(), UserDefaults 갱신

결과 수집:
- `analyzeChunk()` 반환값의 그룹을 로컬 배열에 append
- 각 청크의 투입 사진 ID를 순서대로 누적 (중복 제거)하여 `analyzedAssetIDs` 구성
- maxGroupCount 도달 여부를 `terminationReason`에 기록

#### 파일 3: `SimilarityAnalysisQueue.swift` 수정 (#if DEBUG)

추가 1: 부수효과 억제 가드 (3곳)

```swift
// SimilarityAnalysisQueue.swift:235 (cancel 내부)
#if DEBUG
if self !== SimilarityAnalysisQueue.shared { /* analytics 생략 */ }
else { AnalyticsService.shared.countSimilarAnalysisCancelled() }
#else
AnalyticsService.shared.countSimilarAnalysisCancelled()
#endif

// SimilarityAnalysisQueue.swift:476 (formGroupsForRange 완료 시)
#if DEBUG
if self !== SimilarityAnalysisQueue.shared { /* analytics 생략 */ }
else { AnalyticsService.shared.countSimilarAnalysisCompleted(groups: validGroupIDs.count, duration: analysisDuration) }
#else
AnalyticsService.shared.countSimilarAnalysisCompleted(groups: validGroupIDs.count, duration: analysisDuration)
#endif

// SimilarityAnalysisQueue.swift:479 (notification)
#if DEBUG
if self !== SimilarityAnalysisQueue.shared { /* notification 생략 */ }
else { postAnalysisComplete(range: range, groupIDs: validGroupIDs, analyzedAssetIDs: assetIDs) }
#else
postAnalysisComplete(range: range, groupIDs: validGroupIDs, analyzedAssetIDs: assetIDs)
#endif
```

추가 2: debug oracle helper

```swift
#if DEBUG
func debugGroupsForRange(
    _ range: ClosedRange<Int>,
    fetchResult: PHFetchResult<PHAsset>
) async -> (groupIDs: [String], groups: [[String]], analyzedAssetIDs: [String]) {
    let groupIDs = await formGroupsForRange(range, source: .grid, fetchResult: fetchResult)
    var groups: [[String]] = []
    for groupID in groupIDs {
        let members = await cache.getGroupMembers(groupID: groupID)
        groups.append(members)
    }
    let photos = fetchPhotos(in: range, fetchResult: fetchResult)
    let analyzedAssetIDs = photos.map(\.localIdentifier)
    return (groupIDs, groups, analyzedAssetIDs)
}
#endif
```

추가 3: fetchPhotos 노출

```swift
#if DEBUG
func debugFetchPhotos(in range: ClosedRange<Int>, fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
    fetchPhotos(in: range, fetchResult: fetchResult)
}
#endif
```

### Stage 1 해석 기준

| 결과 | 의미 | 다음 행동 |
|------|------|----------|
| PASS | 알고리즘 동등 | Stage 2로 진행 |
| PARTIAL | 상한 내 동등, 상한 초과 미검증 | 허용 (maxGroupCount 설계) |
| FAIL | 알고리즘 또는 입력 처리 차이 | Stage 2 전에 원인 분석 |

---

## Stage 2: Live Grid Verification

### 목적

사용자가 실제 Grid에서 본 최종 상태와 FaceScan 결과를 비교한다.

Stage 1이 PASS여도 이 단계가 필요한 이유:
- Grid는 스크롤마다 shared cache에 분석 결과가 누적된다
- mergeOverlappingGroups가 누적 과정에서 그룹을 변형할 수 있다
- Stage 1 oracle(1회 실행)은 이 누적 과정을 거치지 않는다

### oracle 정의

**실제 live Grid 세션에서, 사용자가 본 시점의 `SimilarityCache.shared` 최종 그룹 상태.**

- "Grid 알고리즘을 재실행한 결과"가 아니다
- "관찰된 실제 세션 결과"다

### 구현

#### 파일 4: `SweepPic/SweepPic/Debug/GridAnalysisSessionRecorder.swift` (신규)

전체가 `#if DEBUG`. 릴리즈 빌드 미포함.

**구조체:**

```swift
#if DEBUG
struct LiveGridFinalSnapshot: Codable {
    let groups: [GroupSignature]       // preliminary 제외, 최종 확정 그룹만
    let capturedAt: Date
}

struct LiveGridRequestRecord: Codable {
    let requestID: String
    let source: String
    let range: String                  // "\(range.lowerBound)...\(range.upperBound)"
    let timestamp: Date
    let outcome: String                // "completed" | "cancelled"
    let groupIDs: [String]?            // completed일 때만
}

struct LiveGridSessionRecord: Codable {
    let requests: [LiveGridRequestRecord]
    let finalSnapshot: LiveGridFinalSnapshot
}
#endif
```

**recorder 클래스:**

```swift
#if DEBUG
final class GridAnalysisSessionRecorder {
    static let shared = GridAnalysisSessionRecorder()

    private var requests: [LiveGridRequestRecord] = []

    /// formGroupsForRange 호출 시 기록
    func recordRequest(id: String, source: String, range: ClosedRange<Int>)
    func recordCompletion(id: String, groupIDs: [String])

    /// cancel(source:) 호출 시 기록
    /// 주의: 현재 cancel(source:)는 source 단위 취소이므로,
    /// recorder 내부에서 해당 source의 미완료 request를 찾아 매핑해야 한다.
    func recordCancellation(source: String)

    /// 사용자가 수동으로 호출: 현재 shared cache의 최종 그룹을 snapshot
    func captureSnapshot() async -> LiveGridFinalSnapshot

    /// 전체 세션 기록 저장
    func saveSession() async
}
#endif
```

**captureSnapshot() 구현:**

SimilarityCache에 현재 전체 그룹을 dump하는 API가 없으므로, debug helper를 추가해야 한다.

SimilarityCache.swift에 추가:
```swift
#if DEBUG
/// 현재 캐시의 모든 유효 그룹을 반환한다. preliminary 제외.
func debugAllGroups() -> [SimilarThumbnailGroup] {
    groups.values.filter { $0.isValid }.map { $0 }
}
#endif
```

captureSnapshot:
```swift
func captureSnapshot() async -> LiveGridFinalSnapshot {
    let allGroups = await SimilarityCache.shared.debugAllGroups()
    let signatures = allGroups.map {
        GroupSignature(members: $0.memberAssetIDs.sorted())
    }
    return LiveGridFinalSnapshot(groups: signatures, capturedAt: Date())
}
```

**final snapshot 시점 계약:**

snapshot은 반드시 다음 조건이 충족된 시점에서 캡처한다:
- 스크롤이 멈춰 있고
- 진행 중인 analysis가 없고
- UI가 최종 배지 상태를 반영한 뒤

방식: 수동 DEBUG 액션으로 사용자가 직접 snapshot을 찍는다.
이유: 자동 시점 추정은 틀릴 수 있다. "사용자가 보던 상태"이므로 관찰 시점을 사용자가 고정하는 것이 정확하다.

**preliminary 처리 계약:**

최종 oracle에는 `preliminary` 상태 그룹을 포함하면 안 된다.
`debugAllGroups()`는 `isValid` 필터로 이를 처리한다.

**cancellation 처리 계약:**

cancellation은 live Grid 동작의 일부다.
- request/cancel/complete 기록은 원인 추적용
- final snapshot은 비교 기준용

#### SimilarityAnalysisQueue.swift 추가 수정 (Stage 2용)

recorder 호출 삽입:

```swift
#if DEBUG
// formGroupsForRange() 시작 시 (shared 인스턴스에서만 기록)
if self === SimilarityAnalysisQueue.shared {
    GridAnalysisSessionRecorder.shared.recordRequest(id: requestID, source: source.rawValue, range: range)
}

// 완료 시
if self === SimilarityAnalysisQueue.shared {
    GridAnalysisSessionRecorder.shared.recordCompletion(id: requestID, groupIDs: groupIDs)
}
#endif

// cancel(source:) 내부
#if DEBUG
if self === SimilarityAnalysisQueue.shared {
    GridAnalysisSessionRecorder.shared.recordCancellation(source: source.rawValue)
}
#endif
```

recorder는 `self === .shared`일 때만 기록한다. 격리 인스턴스의 호출은 기록하지 않는다.

### Stage 2 비교

```swift
#if DEBUG
struct LiveEquivalenceReport: Codable {
    let liveGridGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
    let timestamp: Date
}
#endif
```

FaceScanGridEquivalenceTester에 추가:

```swift
func runLiveEquivalence(
    liveSnapshot: LiveGridFinalSnapshot,
    faceScanGroups: [GroupSignature]
) -> LiveEquivalenceReport
```

### Stage 2 해석 기준

| 결과 | 의미 |
|------|------|
| gridOnly 없음 + faceScanOnly 있음 | FaceScan이 Grid보다 더 많이 찾음. **정상** (FaceScan은 전체를 스캔하므로) |
| gridOnly 있음 | FaceScan이 Grid가 찾은 그룹을 놓침. **문제** |
| 양쪽 모두 없음 | 완전 일치. **이상적** |

핵심: Stage 2에서 `faceScanOnly`는 실패가 아니다. FaceScan은 사용자가 스크롤하지 않은 영역의 그룹도 찾으므로 Grid보다 많을 수 있다. `gridOnly`만 문제다.

### Stage 2 실행 흐름

```
1. 사용자가 Grid에서 원하는 범위까지 스크롤
2. 스크롤 멈춤 → 분석 완료 대기
3. DEBUG 액션: "Grid snapshot 저장"
4. 같은 사진 범위에서 FaceScan 실행 (또는 Stage 1의 FaceScan 결과 재사용)
5. live snapshot과 FaceScan 결과 비교
6. 리포트 저장
```

---

## 실행 흐름 전체

```
[개발 중 — 반복 사용]

FaceScanGridEquivalenceTester.runEngineEquivalence(method:range:)
  ├─ fetchResult 생성 (FaceScan predicate 재사용)
  ├─ range 보정
  ├─ Grid oracle (격리 인스턴스)
  │   └─ formGroupsForRange() 직접 호출 (부수효과 억제됨)
  │   └─ gridCache에서 결과 추출
  ├─ FaceScan (격리 인스턴스)
  │   └─ analyzeDebugRange() → FaceScanDebugResult
  ├─ 입력 동등성 검증
  ├─ 정규화 + diff
  └─ 로그 + JSON 저장
  → PASS / PARTIAL / FAIL

[출시 전 — 수동 확인]

1. Grid에서 스크롤 → snapshot 저장
2. FaceScan 실행 → 결과 수집
3. runLiveEquivalence(snapshot, faceScan)
  → gridOnly 확인
```

---

## 대표 범위 반복 수집 (Stage 1)

| 범위 | 목적 |
|------|------|
| 최근 100장 | 기본 동작 확인 |
| 최근 300장 | 다중 청크 경계 확인 |
| 문제 재현 anchor를 포함하는 100장 | 6장→4장 잘림 케이스 재현 |
| 연도별 스캔 1개 범위 | byYear method 검증 |
| 1000장 경계 근처 범위 | maxScanCount 종료 시점 검증 |

---

## 이번 단계에서 하지 않을 것

- FaceScan 알고리즘 수정
- Grid 알고리즘 수정
- `formGroups()` 리팩터링 또는 IncrementalGroupBuilder 구현
- `formGroupsForRange()` 내부의 core 추출/분리
- overlap/excludeAssets 로직 수정
- `hasAnyFace` 게이트 제거
- SimilarityCache.shared 상태 변경 (clear 포함)
- baseline 함수 재구현

---

## 구현 순서

### Phase 1: Stage 1 구현

1. `SimilarityAnalysisQueue.swift`에 부수효과 억제 가드 3곳 삽입
2. `FaceScanGridEquivalenceTester.swift` 추가
   - GroupSignature, EngineEquivalenceReport 타입
   - runEngineEquivalence() (Step 1~7)
3. `FaceScanService.swift` debug helper 추가
   - `debugBuildFetchResult(method:)`
   - `analyzeDebugRange(fetchResult:range:)`
4. `SimilarityAnalysisQueue.swift` debug helper 추가
   - `debugGroupsForRange(_:fetchResult:)`
   - `debugFetchPhotos(in:fetchResult:)`
5. 빌드 확인
6. 대표 범위 3~5개 실행
7. diff 패턴 정리

### Phase 2: Stage 2 구현

8. `SimilarityCache.swift`에 `debugAllGroups()` 추가
9. `GridAnalysisSessionRecorder.swift` 추가
10. `SimilarityAnalysisQueue.swift`에 recorder 호출 삽입 (shared만)
11. captureSnapshot() 구현
12. runLiveEquivalence() 구현
13. 실기기에서 수동 검증 1회 이상 실행

### Phase 3: 수정안

14. Stage 1 + Stage 2 결과를 근거로 수정안 설계

---

## 승인 기준

| 단계 | 기준 | 용도 |
|------|------|------|
| Stage 1 PASS | gridOnly 없고 faceScanOnly 없음 | 개발 완료 판정 |
| Stage 1 PARTIAL | maxGroupCount 내 일치 | 허용 (설계 제약) |
| Stage 2 gridOnly 없음 | live Grid가 찾은 그룹을 FaceScan이 모두 포함 | **출시 승인** |

최종 출시 기준은 Stage 2다. Stage 1 PASS만으로는 부족하다.

---

## 하네스 → 수정안 전환 경로

### 현재 상태 예상

Stage 1 FAIL: Grid oracle은 격리 인스턴스에서 `formGroupsForRange()`를 호출하여 전체 범위를 한 번에 처리하므로 경계 문제가 없다. FaceScan은 20장 청크로 `formGroups()`를 호출하므로 경계 그룹이 잘린다.

### 수정 방향

FaceScan의 `analyze()`를 수정하여, **격리 인스턴스에서 `formGroupsForRange()`를 직접 호출**하는 구조로 변경한다.

`formGroupsForRange()`는 FP 생성부터 최종 그룹 저장까지 전체 파이프라인을 포함하므로, FP를 별도로 배치 생성할 필요가 없다. 함수를 호출하면 전체가 일괄 실행된다.

```
현재 FaceScan:
  buildFetchResult → 청크 루프 { analyzeChunk() } → saveSession

수정 후 FaceScan:
  buildFetchResult → 격리 인스턴스 생성 → formGroupsForRange() 호출 → 결과를 FaceScanGroup으로 변환
```

1000장 FP를 한 번에 처리하는 것은 `AsyncSemaphore`가 동시 5개로 제한하므로 메모리 문제없음.

이 구조의 핵심 이점: **향후 Grid에 어떤 변경이 있어도 FaceScan에 자동 반영된다.**

### 장기 아키텍처 (하네스 검증 후 결정)

`formGroupsForRange()`를 직접 호출하는 방식에서 부수효과 억제가 `#if DEBUG` 가드에 의존하는 점은 production에서는 다른 방식이 필요하다. 하네스 검증 후 둘 중 하나를 결정한다:

- **최소 수정**: `formGroupsForRange()`에 sideEffects 옵션 파라미터 추가
- **장기 아키텍처**: 엔진 코어를 side-effect-free 함수로 추출, Grid와 FaceScan이 각각 wrapper로 사용

이 결정은 하네스 검증 결과를 보고 내린다. 지금 결정하지 않는다.

### 수정 후 검증

Stage 1 → PASS 전환 확인.
Stage 2 → gridOnly 없음 확인.
하네스는 이후 회귀 테스트로 유지.

---

## 파일별 변경 요약

| 파일 | 작업 | Phase | 라인 수 (추정) |
|------|------|-------|--------------|
| `SimilarityAnalysisQueue.swift` (수정) | 부수효과 가드 3곳 + debug helper 2개 + recorder 호출 | 1+2 | ~50줄 |
| `FaceScanGridEquivalenceTester.swift` (신규) | Stage 1+2 타입 + run + 로그/JSON | 1+2 | ~250줄 |
| `FaceScanService.swift` (수정) | `#if DEBUG` 진입점 2개 | 1 | ~80줄 |
| `GridAnalysisSessionRecorder.swift` (신규) | Stage 2 recorder + snapshot | 2 | ~120줄 |
| `SimilarityCache.swift` (수정) | `debugAllGroups()` 추가 | 2 | ~10줄 |
| **합계** | | | ~510줄 |

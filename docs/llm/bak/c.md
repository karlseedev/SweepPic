# FaceScan ↔ Grid 동등성 검증 하네스 구현 계획

## 목적

이 문서는 **수정안이 아니라 검증 하네스 구현 계획**이다.

FaceScan(경로 B) 결과가 Grid(경로 A) 결과와 같은지 자동으로 비교하는 도구를 만든다.
구조 수정(IncrementalGroupBuilder 등) 착수 전에 이 하네스를 먼저 만들어야 한다.

**이 하네스가 중요한 이유:**
하네스의 기준값 생성기(Grid 로직을 전체 범위에 한 번 실행)는 구조적으로 수정안과 동일한 형태다. 따라서 하네스가 올바르게 동작하면 수정안의 방향도 검증된 것이다. 하네스를 대충 만들 수 없는 이유가 여기에 있다.

---

## 핵심 원칙

### 원칙 1. production 로직을 바꾸지 않는다

데이터 수집 단계에서는 다음을 하지 않는다:

- `formGroups()` 재구현 또는 리팩터링
- FaceScan overlap/excludeAssets 로직 수정
- FaceScan `hasAnyFace` 게이트 수정
- Grid 로직 수정
- 기존 메서드 시그니처 변경

비교기가 현재 production 경로를 있는 그대로 호출해야 수집 데이터가 의미 있다.

### 원칙 2. debug 진입점만 추가한다

추가하는 것은 `#if DEBUG` 블록 내의 다음뿐이다:

- Grid oracle을 격리 실행하는 debug helper
- FaceScan을 명시적 range로 돌리는 debug 진입점
- 두 결과를 정규화/비교/저장하는 harness

### 원칙 3. 캐시 오염을 원천 차단한다

`SimilarityCache.shared.clear()`를 호출하지 **않는다.** 앱 사용 중 호출하면 그리드 UI의 배지가 날아가는 부작용이 있다.

대신:
- Grid oracle은 **새 SimilarityAnalysisQueue 인스턴스 + 새 SimilarityCache 인스턴스**로 실행한다.
- FaceScan debug는 **새 FaceScanService 인스턴스 + 새 FaceScanCache 인스턴스**로 실행한다.

이것이 가능한 이유:
- `SimilarityAnalysisQueue.init(cache:)`가 cache 주입을 지원한다 (기본값: `.shared`).
- `FaceScanService.init(cache:)`가 cache 주입을 지원한다.
- 두 인스턴스 모두 내부에서 새 `PersonMatchingEngine()`을 자동 생성한다.

### 원칙 4. 비교 단위는 정렬된 멤버 집합이다

비교 시 무시하는 것:
- `groupID` (UUID이므로 매번 다름)
- 그룹 발견 순서
- UI 표시 순서

비교 기준:
- `Set(memberAssetIDs)` — 완전 일치만 통과

---

## 현재 코드 기준 사실 정리

### Grid 경로의 최종 그룹 생성 지점

`SimilarityAnalysisQueue.formGroupsForRange(range:source:fetchResult:)`

내부 처리 순서:
1. `fetchPhotos(in:range:fetchResult:)` — 삭제대기함 제외
2. `matchingEngine.generateFeaturePrints(for:)` — FP + 얼굴 유무
3. `analyzer.formGroups(featurePrints:photoIDs:threshold:)` — 인접 거리 그루핑
4. 각 rawGroup에 대해 `matchingEngine.assignPersonIndicesForGroup(assetIDs:photos:)` — 얼굴 감지 + 인물 매칭
5. validSlots 계산 (personIndex가 2장 이상에 등장)
6. validMembers 필터링 (유효 슬롯 얼굴이 있는 사진만)
7. `cache.addGroupIfValid(members:validSlots:photoFaces:)` — 최종 그룹 저장

최종 그룹의 source of truth: `cache.getGroupMembers(groupID:)`

중요: Grid 경로는 `hasAnyFace` 게이트가 **없다**. rawGroups 전부를 YuNet/SFace 단계까지 보낸다.

### FaceScan 경로의 최종 그룹 생성 지점

`FaceScanService.analyze(method:onGroupFound:onProgress:)`

내부 처리 순서:
1. `buildFetchResult(method:)` — 최신순 정렬, method별 predicate
2. `findStartIndex(method:fetchResult:)` — 이어서 스캔 시 시작점
3. 청크 루프 (chunkSize=20, chunkOverlap=3)
4. 각 청크: `analyzeChunk(photos:excludeAssets:)`
   - FP 생성 + `formGroups()` 호출
   - Step 2.5: excludeAssets 기반 사전 필터 (새 멤버 3장 미만이면 스킵)
   - **`hasAnyFace` 게이트** (Vision 얼굴 없으면 그룹 스킵)
   - `assignPersonIndicesForGroup()` — 얼굴 감지 + 인물 매칭
   - Step 5.5: overlap 멤버 제거
   - `FaceScanCache.addGroup()`

### 두 경로의 구조적 차이 (현재)

| 항목 | Grid | FaceScan |
|------|------|----------|
| formGroups 호출 | 범위 전체를 한 번에 | 20장 청크 단위 |
| hasAnyFace 게이트 | 없음 | 있음 (Vision 얼굴 없으면 스킵) |
| overlap/excludeAssets | 없음 | 있음 (청크 경계 보정 시도) |
| 캐시 | SimilarityCache | FaceScanCache |
| 그룹 병합 | addGroupIfValid 내부 mergeOverlappingGroups | 없음 |

이 차이를 지금 없애는 것이 아니라, **정확히 수집**하는 것이 이번 구현의 목적이다.

### Grid UI 상태는 oracle이 될 수 없다

실제 사용 중인 Grid는 "사용자가 어디까지 스크롤했는지"에 따라 분석 범위가 달라진다. 비교 기준으로 쓰면 안 된다.

비교 기준: 같은 fetchResult, 같은 정렬, 같은 삭제대기함 제외, 같은 명시적 range를 Grid 엔진과 FaceScan 엔진에 각각 직접 넣어서 결과를 수집한다.

---

## 캐시 격리 전략

### 왜 `SimilarityCache.shared.clear()`를 쓰지 않는가

Grid oracle 실행 전에 shared 캐시를 clear하면:
- 현재 그리드에 표시 중인 유사 사진 배지가 사라진다
- 사용자가 앱을 쓰는 중에 UI가 깨진다
- DEBUG 전용이라도 앱 상태 오염은 허용하면 안 된다

### 격리 방식: 새 인스턴스 주입

```
Grid oracle:
  SimilarityCache()          ← 새 인스턴스 (shared 아님)
  SimilarityAnalysisQueue(cache: ↑)  ← 새 인스턴스
  → formGroupsForRange() 호출
  → 결과는 새 캐시에만 저장됨
  → SimilarityCache.shared는 그대로

FaceScan debug:
  FaceScanCache()            ← 새 인스턴스
  FaceScanService(cache: ↑)  ← 새 인스턴스
  → analyzeDebugRange() 호출
  → 결과는 새 캐시에만 저장됨
  → 기존 FaceScanCache 무관
```

양쪽 모두 내부에서 새 `PersonMatchingEngine()`을 자동 생성하므로 상태 간섭 없음.

---

## 구현 범위

### 새 파일 1개

| 파일 | 위치 |
|------|------|
| `FaceScanGridEquivalenceTester.swift` | `SweepPic/SweepPic/Debug/` |

### 수정 파일 2개

| 파일 | 변경 |
|------|------|
| `FaceScanService.swift` | `#if DEBUG` 진입점 2개 추가 |
| `SimilarityAnalysisQueue.swift` | `#if DEBUG` helper 1개 추가 |

---

## 파일 1: `FaceScanGridEquivalenceTester.swift`

전체가 `#if DEBUG` 블록. 릴리즈 빌드에 포함되지 않음.

### 책임

- 비교용 범위와 입력 준비
- Grid oracle 실행 (격리된 인스턴스)
- FaceScan 실행 (격리된 인스턴스)
- 그룹 정규화
- diff 생성
- 로그 + JSON 저장

### 타입 정의

```swift
#if DEBUG
import Foundation
import Photos
import OSLog

/// 정규화된 그룹 시그니처 (비교 단위)
struct GroupSignature: Hashable, Codable {
    /// memberAssetIDs를 정렬한 배열
    let members: [String]
}

/// 비교 결과 리포트
struct GroupDiffReport: Codable {
    let timestamp: Date
    let methodDescription: String
    let rangeDescription: String
    let gridInputAssetCount: Int
    let faceScanInputAssetCount: Int
    let gridGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]       // Grid에만 있음 (FaceScan이 놓침)
    let faceScanOnly: [GroupSignature]   // FaceScan에만 있음
    let common: [GroupSignature]         // 양쪽 일치
    let faceScanHitMaxGroupCount: Bool   // FaceScan이 30그룹 상한 도달 여부
    let passed: Bool                     // gridOnly와 faceScanOnly 모두 비어있으면 true
}
#endif
```

### 메인 클래스

```swift
#if DEBUG
final class FaceScanGridEquivalenceTester {

    /// 동등성 비교 실행
    ///
    /// - Parameters:
    ///   - method: FaceScan 스캔 방식 (fetchResult 구성에 사용)
    ///   - range: 비교할 fetchResult 인덱스 범위
    /// - Returns: 비교 리포트
    func run(
        method: FaceScanMethod,
        range: ClosedRange<Int>? = nil
    ) async throws -> GroupDiffReport
}
#endif
```

### run() 내부 단계

#### Step 1. 입력 fetchResult 생성

FaceScan이 실제 쓰는 정렬/필터를 그대로 재사용한다.

```swift
let faceScanService = FaceScanService(cache: FaceScanCache())
let fetchResult = faceScanService.debugBuildFetchResult(method: method)
```

#### Step 2. 범위 보정

```swift
guard fetchResult.count > 0 else { return emptyReport }
let maxRange = 0...(fetchResult.count - 1)
let clampedRange = range.map { $0.clamped(to: maxRange) } ?? maxRange
guard clampedRange.lowerBound <= clampedRange.upperBound else { return emptyReport }
```

range가 nil이면 fetchResult 전체를 사용한다.

#### Step 3. Grid oracle 실행 (격리)

```swift
let gridCache = SimilarityCache()
let gridQueue = SimilarityAnalysisQueue(cache: gridCache)
let gridGroupIDs = await gridQueue.formGroupsForRange(
    clampedRange,
    source: .grid,
    fetchResult: fetchResult
)

// 결과 추출 (gridCache에서 읽기)
var gridGroups: [[String]] = []
for groupID in gridGroupIDs {
    let members = await gridCache.getGroupMembers(groupID: groupID)
    if !members.isEmpty {
        gridGroups.append(members)
    }
}

// 입력 asset 수 계산 (같은 로직으로 직접 계산)
let gridPhotos = gridQueue.debugFetchPhotos(in: clampedRange, fetchResult: fetchResult)
let gridInputAssetCount = gridPhotos.count
```

**핵심**: `SimilarityCache.shared`를 건드리지 않는다. 새 인스턴스에만 결과가 쌓인다.

#### Step 4. FaceScan 실행 (격리)

```swift
let faceScanCache = FaceScanCache()
let faceScanService2 = FaceScanService(cache: faceScanCache)
let faceScanResult = await faceScanService2.analyzeDebugRange(
    fetchResult: fetchResult,
    range: clampedRange
)
```

#### Step 5. 입력 동등성 사전 검증

Grid와 FaceScan이 같은 범위에서 실제로 같은 입력 자산을 봤는지 먼저 확인한다.

```swift
let gridInputIDs = Set(gridPhotos.map(\.localIdentifier))
let faceScanInputIDs = Set(faceScanResult.analyzedAssetIDs)

if gridInputIDs != faceScanInputIDs {
    Logger.similarPhoto.error("""
        [Equivalence] 입력 불일치 — 그룹 비교 무의미
        Grid: \(gridInputIDs.count)장, FaceScan: \(faceScanInputIDs.count)장
        Grid에만: \(gridInputIDs.subtracting(faceScanInputIDs).count)장
        FaceScan에만: \(faceScanInputIDs.subtracting(gridInputIDs).count)장
    """)
}
```

입력이 불일치하면 그룹 비교 결과는 신뢰할 수 없다. 리포트에 기록하되 비교는 계속 진행한다 (불일치 원인 추적용).

#### Step 6. 정규화

```swift
let gridSignatures = Set(gridGroups.map {
    GroupSignature(members: $0.sorted())
})
let faceScanSignatures = Set(faceScanResult.groups.map {
    GroupSignature(members: $0.memberAssetIDs.sorted())
})
```

#### Step 7. diff 생성

```swift
let common = gridSignatures.intersection(faceScanSignatures)
let gridOnly = gridSignatures.subtracting(faceScanSignatures)
let faceScanOnly = faceScanSignatures.subtracting(gridSignatures)

let passed = gridOnly.isEmpty && faceScanOnly.isEmpty
```

#### Step 8. 저장 + 로그

**Logger 출력:**

```
[Equivalence] PASS (또는 FAIL)
  범위: 0...99 (fetchResult: 5000장)
  입력: Grid 92장, FaceScan 92장
  그룹: Grid 5개, FaceScan 3개
  일치: 3개
  Grid에만: 2개
  FaceScan에만: 0개
```

PASS는 `.debug` 레벨, FAIL은 `.error` 레벨.

FAIL인 경우 각 불일치 그룹의 멤버를 개별 로그로 출력:
```
[Equivalence/GridOnly] {id1, id2, id3, id4, id5, id6} (6장)
```

**JSON 파일 저장:**

`/tmp/facescan-grid-equivalence-{timestamp}.json`에 `GroupDiffReport`를 저장한다.
마지막 실행 결과를 `/tmp/facescan-grid-equivalence-latest.json`에도 덮어쓴다.

반복 수집 시 이력을 남겨 패턴 분석에 사용한다.

---

## 파일 2: `FaceScanService.swift` 수정

production `analyze(method:onGroupFound:onProgress:)`는 유지한다. `#if DEBUG` 블록만 추가한다.

### 추가 1. fetchResult builder 노출

```swift
#if DEBUG
/// 비교 하네스용: FaceScan이 실제 쓰는 fetchResult를 동일하게 생성
func debugBuildFetchResult(method: FaceScanMethod) -> PHFetchResult<PHAsset> {
    buildFetchResult(method: method)
}
#endif
```

기존 `private buildFetchResult(method:)`를 감싸는 wrapper. production API surface 확장 없음.

### 추가 2. 명시적 range 분석 진입점

```swift
#if DEBUG
/// 비교 하네스용 결과 구조체
struct FaceScanDebugResult {
    let groups: [FaceScanGroup]
    let analyzedAssetIDs: [String]
    let hitMaxGroupCount: Bool
}

/// 지정된 범위에서 현재 FaceScan 로직을 그대로 실행하여 결과를 수집한다.
///
/// production analyze()와의 차이:
/// - fetchResult와 range를 외부에서 받는다
/// - 세션 저장(UserDefaults)을 하지 않는다
/// - 결과를 콜백이 아닌 반환값으로 전달한다
///
/// production 로직과의 동등성:
/// - chunkSize, chunkOverlap, excludeAssets, hasAnyFace 게이트,
///   Step 2.5/5.5 overlap 제거 — 모두 현재 analyzeChunk() 그대로 호출
/// - maxScanCount, maxGroupCount 종료 조건 동일
func analyzeDebugRange(
    fetchResult: PHFetchResult<PHAsset>,
    range: ClosedRange<Int>
) async -> FaceScanDebugResult
#endif
```

### analyzeDebugRange 구현 방식

production `analyze()`의 청크 루프를 범위 제한 버전으로 작성한다.
내부에서 기존 `analyzeChunk(photos:excludeAssets:)`를 그대로 호출한다.

```
현재 analyze() 구조:
  buildFetchResult → findStartIndex → 청크 루프 { analyzeChunk() } → saveSession

analyzeDebugRange() 구조:
  외부 fetchResult 사용 → range로 시작/끝 고정 → 청크 루프 { analyzeChunk() } → 반환
```

반드시 유지해야 할 현재 동작:
- `chunkSize = 20`
- `chunkOverlap = 3`
- `chunkStart = max(range.lowerBound, currentIndex - overlap)` (range 내부로 clamp)
- `chunkEnd = min(range.upperBound, currentIndex + chunkSize - 1)`
- `excludeAssets` 누적
- `analyzeChunk()` 그대로 호출 (hasAnyFace 게이트, Step 2.5/5.5 포함)
- `maxScanCount` / `maxGroupCount` 종료 조건
- 삭제대기함 제외 (`TrashStore.shared.trashedAssetIDs`)

반드시 하지 않을 것:
- `saveSession()` 호출
- `UserDefaults` 갱신
- `onGroupFound` / `onProgress` 외부 콜백

결과 수집:
- `analyzeChunk()` 반환값의 그룹을 로컬 배열에 append
- 각 청크의 투입 사진 ID를 순서대로 누적 (중복 제거)하여 `analyzedAssetIDs` 구성
- maxGroupCount 도달 여부를 `hitMaxGroupCount`에 기록

이 메서드는 production `analyzeChunk()`을 변경 없이 호출하므로,
"현재 FaceScan이 이 범위를 입력받았을 때 내는 결과"를 정확히 수집한다.

---

## 파일 3: `SimilarityAnalysisQueue.swift` 수정

production `formGroupsForRange()`는 유지한다. `#if DEBUG` 블록만 추가한다.

### 추가 1. debug oracle helper

```swift
#if DEBUG
/// 비교 하네스용: 지정 범위에서 Grid 분석 결과를 반환한다.
///
/// production formGroupsForRange()를 그대로 호출한다.
/// 반환값으로 groupIDs와 각 그룹의 memberAssetIDs를 함께 제공한다.
func debugGroupsForRange(
    _ range: ClosedRange<Int>,
    fetchResult: PHFetchResult<PHAsset>
) async -> (groupIDs: [String], groups: [[String]]) {
    let groupIDs = await formGroupsForRange(
        range,
        source: .grid,
        fetchResult: fetchResult
    )

    var groups: [[String]] = []
    for groupID in groupIDs {
        let members = await cache.getGroupMembers(groupID: groupID)
        groups.append(members)
    }

    return (groupIDs, groups)
}
#endif
```

**핵심**: Grid 로직을 복제하지 않는다. 기존 production 함수를 그대로 호출하고 결과를 읽기 쉽게 묶을 뿐이다.

### 추가 2. fetchPhotos 노출

```swift
#if DEBUG
/// 비교 하네스용: 입력 asset 목록 추출 (입력 동등성 검증용)
func debugFetchPhotos(
    in range: ClosedRange<Int>,
    fetchResult: PHFetchResult<PHAsset>
) -> [PHAsset] {
    fetchPhotos(in: range, fetchResult: fetchResult)
}
#endif
```

기존 `private fetchPhotos(in:fetchResult:)`를 감싸는 wrapper.

---

## 실행 흐름

```
FaceScanGridEquivalenceTester.run(method:range:)
  │
  ├─ Step 1: fetchResult 생성 (FaceScan predicate 재사용)
  ├─ Step 2: range 보정 (clamp)
  │
  ├─ Step 3: Grid oracle (격리)
  │   ├─ SimilarityCache() 새 인스턴스
  │   ├─ SimilarityAnalysisQueue(cache: ↑) 새 인스턴스
  │   ├─ formGroupsForRange() 호출 (production 코드 그대로)
  │   └─ 결과: gridCache에서 memberAssetIDs 추출
  │
  ├─ Step 4: FaceScan (격리)
  │   ├─ FaceScanCache() 새 인스턴스
  │   ├─ FaceScanService(cache: ↑) 새 인스턴스
  │   ├─ analyzeDebugRange() 호출 (production analyzeChunk 그대로)
  │   └─ 결과: FaceScanDebugResult
  │
  ├─ Step 5: 입력 동등성 검증
  ├─ Step 6: 정규화 (GroupSignature)
  ├─ Step 7: diff 생성 (Set 연산)
  └─ Step 8: 로그 + JSON 저장
```

---

## maxGroupCount / maxScanCount 처리

FaceScan은 30그룹(`maxGroupCount`) 또는 1000장(`maxScanCount`)에서 조기 종료한다.

Grid oracle은 같은 범위에서 제한 없이 모든 그룹을 찾는다.

따라서 FaceScan이 `maxGroupCount`에 도달한 경우:
- Grid가 31개 이상 그룹을 찾을 수 있다
- 31번째 이후 그룹은 `gridOnly`로 나타난다
- 이것은 **청크 경계 문제가 아니라 상한 도달에 의한 예상된 차이**다

리포트에서 구분할 수 있도록:
- `FaceScanDebugResult.hitMaxGroupCount` 플래그를 전달한다
- 리포트의 `faceScanHitMaxGroupCount`가 true이면 `gridOnly` 그룹은 "상한 도달로 인한 미탐지"로 분류한다
- 로그에 `[참고] FaceScan이 maxGroupCount(30)에 도달하여 조기 종료됨` 추가

**PASS/FAIL 판정 보정:**
- `faceScanHitMaxGroupCount == true`이면, `gridOnly`가 있어도 **PASS로 판정하지 않는다**
- 대신 `PARTIAL` 상태를 추가한다: "상한 내의 그룹은 일치하지만 상한 초과 그룹은 미검증"
- FAIL은 상한과 무관하게 `faceScanOnly`가 있거나, 상한 도달 전 그룹에서 불일치가 있을 때만

---

## 검증 항목

### 1. 입력 동등성 검증 (비교 전제조건)

Grid와 FaceScan이 같은 범위에서 실제로 같은 입력 자산을 봤는지 먼저 확인한다.

- `gridInputAssetCount == faceScanInputAssetCount`
- `Set(gridInputAssetIDs) == Set(faceScanInputAssetIDs)`

불일치하면 그룹 비교는 무의미하다. 원인은 삭제대기함 제외 타이밍 또는 range clamp 차이.

### 2. 그룹 동등성 검증 (핵심)

3종을 항상 출력한다:
- `gridOnly` — Grid에만 있는 그룹 (FaceScan이 놓침)
- `faceScanOnly` — FaceScan에만 있는 그룹 (Grid에 없음)
- `common` — 양쪽 완전 일치

### 3. 대표 범위 반복 수집

초기 데이터 수집은 아래 범위로 진행한다:

| 범위 | 목적 |
|------|------|
| 최근 100장 | 기본 동작 확인 |
| 최근 300장 | 다중 청크 경계 확인 |
| 문제 재현 anchor를 포함하는 100장 | 기존 6장→4장 잘림 케이스 재현 |
| 연도별 스캔 1개 범위 | byYear method 검증 |
| 1000장 경계 근처 범위 | maxScanCount 종료 시점 검증 |

목적은 "어느 종류의 차이가 반복적으로 발생하는지" 패턴을 수집하는 것이다.

---

## 출력 포맷

### JSON 예시

```json
{
  "timestamp": "2026-04-03T15:30:00Z",
  "methodDescription": "최신사진부터 스캔",
  "rangeDescription": "100...199 (fetchResult: 5000장)",
  "gridInputAssetCount": 92,
  "faceScanInputAssetCount": 92,
  "gridGroups": [
    { "members": ["id1", "id2", "id3", "id4", "id5", "id6"] }
  ],
  "faceScanGroups": [
    { "members": ["id1", "id2", "id3", "id4"] }
  ],
  "gridOnly": [
    { "members": ["id1", "id2", "id3", "id4", "id5", "id6"] }
  ],
  "faceScanOnly": [
    { "members": ["id1", "id2", "id3", "id4"] }
  ],
  "common": [],
  "faceScanHitMaxGroupCount": false,
  "passed": false
}
```

이 예시에서:
- Grid는 6장 그룹을 찾았지만 FaceScan은 4장으로 잘렸다
- 멤버 집합이 다르므로 common이 아닌 각각 gridOnly/faceScanOnly로 분류됨
- 이것이 **청크 경계 문제의 전형적 증상**이다

---

## 이번 단계에서 하지 않을 것

- FaceScan 알고리즘 수정
- Grid 알고리즘 수정
- `formGroups()` 리팩터링 또는 IncrementalGroupBuilder 구현
- overlap/excludeAssets 로직 수정
- `hasAnyFace` 게이트 제거
- UI 버튼 연결
- 실제 그리드 스크롤 자동화
- SimilarityCache.shared 상태 변경

---

## 구현 순서

1. `FaceScanGridEquivalenceTester.swift` 추가
   - GroupSignature, GroupDiffReport 타입
   - run() 메서드 (Step 1~8)
   - 로그 출력 + JSON 저장
2. `FaceScanService.swift` debug helper 추가
   - `debugBuildFetchResult(method:)`
   - `analyzeDebugRange(fetchResult:range:)`
3. `SimilarityAnalysisQueue.swift` debug helper 추가
   - `debugGroupsForRange(_:fetchResult:)`
   - `debugFetchPhotos(in:fetchResult:)`
4. 빌드 확인
5. 대표 범위 3~5개 실행
6. diff 패턴 정리

**이 순서를 지켜야 "고치기 전에 무엇이 얼마나 다른지"를 먼저 확보할 수 있다.**

---

## 하네스 → 수정안 전환 경로

이 하네스가 올바르게 동작한 후, 수정안 적용 시의 경로:

### 현재 상태에서의 예상 결과

하네스를 돌리면 **FAIL**이 예상된다. Grid oracle은 전체 범위에서 formGroups를 한 번 호출하므로 경계 문제가 없지만, 현재 FaceScan은 20장 청크로 formGroups를 호출하므로 경계에 걸린 그룹이 잘린다.

이 FAIL이 청크 경계 문제의 존재를 증명한다.

### 수정안 적용 후

FaceScan의 analyze()를 수정하여:
1. FP를 배치로 생성하되 결과를 하나의 배열로 합치고
2. formGroups를 전체 FP 배열에 한 번 호출하고
3. 각 그룹별로 얼굴 감지 + slot 필터링을 수행하면

이것은 **Grid oracle이 하는 일과 구조적으로 동일**하다.

수정 후 하네스를 돌리면 **PASS**로 전환되어야 한다.
PASS가 아니면 수정에 문제가 있다.

### 기존 플랜(IncrementalGroupBuilder)과의 관계

기존 플랜은 formGroups 내부를 IncrementalGroupBuilder로 추출하여 증분 처리하는 방식이었다. 이 하네스가 증명하는 것은 "전체를 한 번에 formGroups하면 정답"이라는 사실이다.

1000장의 FP를 메모리에 한 번에 들고 있는 것이 가능하면(~4–8MB, 문제없음), IncrementalGroupBuilder 없이 **단순히 청크를 없애는 것**이 가장 간단한 수정이다.

하네스가 이 판단의 근거를 제공한다.

---

## 파일별 변경 요약

| 파일 | 작업 | 라인 수 (추정) |
|------|------|--------------|
| `FaceScanGridEquivalenceTester.swift` (신규) | 타입 정의 + run() + 로그/JSON | ~200줄 |
| `FaceScanService.swift` (수정) | `#if DEBUG` 진입점 2개 | ~80줄 |
| `SimilarityAnalysisQueue.swift` (수정) | `#if DEBUG` helper 2개 | ~25줄 |
| **합계** | | ~305줄 |

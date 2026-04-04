# FaceScan vs Grid 동등성 데이터 수집 구현 계획

## 목적

이 문서는 **수정안 구현 계획이 아니라 데이터 수집용 비교 하네스 구현 계획**이다.

최우선 목표:

- FaceScan 결과와 Grid 분석 경로 결과를 **같은 입력 범위에서 직접 비교**할 수 있게 만든다.
- 비교 기준은 `groupID`나 UI 표시가 아니라 **최종 그룹 멤버 집합(`memberAssetIDs`)** 이다.
- 지금 단계에서는 FaceScan 로직이나 Grid 로직을 바꾸지 않는다.
- 지금 단계의 산출물은 “어디가 다른지 정확히 수집하는 도구”다.

기본 전제:

- 같은 입력이면 결과는 결정론적이어야 한다.
- 하지만 이번 데이터 수집의 핵심은 그 위에 더해 **`FaceScan == Grid 경로`** 를 검증하는 것이다.

---

## 현재 코드 기준 사실 정리

### 1. Grid 경로의 실제 최종 그룹 생성 지점

Grid/Viewer 공용 분석 경로는 `SimilarityAnalysisQueue.formGroupsForRange(...)` 이다.

- 입력:
  - `range`
  - `source`
  - `fetchResult`
- 내부 처리:
  - `fetchPhotos(in:range, fetchResult:)` 로 삭제대기함 제외
  - `matchingEngine.generateFeaturePrints(for:)`
  - `analyzer.formGroups(...)`
  - `rawGroups` 전부에 대해 `assignPersonIndicesForGroup(...)`
  - `SimilarityCache.addGroupIfValid(...)` 로 최종 그룹 저장
- 최종 그룹의 source of truth:
  - `SimilarityCache.groups[groupID].memberAssetIDs`

중요:

- Grid 경로는 `Vision hasFaces`를 최종 필터로 쓰지 않는다.
- `rawGroups` 전부를 YuNet/SFace 단계까지 보낸다.
- 그룹 병합은 `SimilarityCache.addGroupIfValid(...)` 내부 `mergeOverlappingGroups(...)` 에서 처리된다.

즉 Grid oracle은:

1. `SimilarityAnalysisQueue.formGroupsForRange(...)` 호출
2. 반환된 `groupIDs`
3. 각 `groupID`에 대해 `SimilarityCache.shared.getGroupMembers(groupID:)`

이 조합으로 정확히 추출할 수 있다.

### 2. FaceScan 경로의 실제 최종 그룹 생성 지점

FaceScan은 `FaceScanService.analyze(...)` 에서 별도 파이프라인을 돈다.

- 입력:
  - `FaceScanMethod`
- 내부 처리:
  - `buildFetchResult(method:)`
  - `findStartIndex(...)`
  - 20장 청크 + overlap 3장
  - `analyzeChunk(photos:excludeAssets:)`
- `analyzeChunk(...)` 내부:
  - `generateFeaturePrints`
  - `formGroups`
  - Step 2.5: `excludeAssets` 기반 사전 필터
  - `hasAnyFace` 없으면 그룹 스킵
  - `assignPersonIndicesForGroup`
  - `validMembers`
  - Step 5.5: overlap 멤버 제거
  - `FaceScanCache.addGroup(...)`
  - `FaceScanGroup` 콜백 전달

중요:

- FaceScan은 Grid와 다르게 `hasAnyFace` 게이트가 있다.
- FaceScan은 Grid와 다르게 overlap 제거 로직이 있다.
- FaceScan은 Grid와 다르게 `FaceScanCache` 를 따로 쓴다.
- 따라서 현재는 동일 범위라도 결과가 다를 가능성이 구조적으로 있다.

이 차이를 지금 없애는 것이 아니라, **정확히 수집**하는 것이 이번 구현의 목적이다.

### 3. Grid UI 상태는 oracle이 될 수 없다

실제 사용 중인 Grid는 “사용자가 어디까지 스크롤했는지”에 따라 분석 범위와 취소 시점이 달라진다.

따라서 비교 기준으로 쓰면 안 된다.

비교는 반드시 다음 방식으로 한다.

- 같은 `fetchResult`
- 같은 정렬
- 같은 삭제대기함 제외
- 같은 명시적 `range`

를 Grid 엔진과 FaceScan 엔진에 각각 직접 넣어서 결과를 수집한다.

---

## 데이터 수집 설계 원칙

### 원칙 1. production 로직을 바꾸지 않는다

데이터 수집 단계에서는 다음을 하지 않는다.

- `formGroups()` 재구현
- FaceScan overlap 로직 수정
- FaceScan `hasAnyFace` 게이트 수정
- Grid 로직 수정

비교기가 현재 production 경로를 있는 그대로 호출해야 수집 데이터가 의미가 있다.

### 원칙 2. debug 진입점만 추가한다

필요한 추가는 다음뿐이다.

- FaceScan을 “명시적 range”로 돌리는 debug 진입점
- Grid oracle을 호출하고 결과를 읽기 쉽게 묶는 debug helper
- 두 결과를 정규화/비교/로그 저장하는 debug harness

### 원칙 3. 세션/캐시 오염을 제거한다

Grid는 `SimilarityCache.shared` 싱글턴을 사용하므로 이전 분석 결과가 남을 수 있다.

따라서 비교 실행 전:

- `await SimilarityCache.shared.clear()`

를 수행해야 한다.

FaceScan은 새 `FaceScanCache()` 인스턴스를 매 실행마다 생성하면 격리된다.

### 원칙 4. 비교 단위는 정렬된 멤버 집합이다

비교 시 무시해야 하는 것:

- `groupID`
- 그룹 생성 순서
- UI 표시 순서

비교 기준:

- `memberAssetIDs.sorted()`

---

## 구현 범위

이번 단계에서 구현할 파일은 3개다.

1. 새 DEBUG harness 파일 추가
2. FaceScanService에 debug range 진입점 추가
3. Grid oracle helper 추가

핵심은 **비교용 입력 범위를 동일하게 고정하고, 현재 로직을 그대로 실행하는 것**이다.

---

## 파일별 구현 계획

## 1. `SweepPic/SweepPic/Debug/FaceScanGridEquivalenceTester.swift`

새 파일 추가. `#if DEBUG` 전용.

### 책임

- 비교용 범위와 입력 준비
- Grid oracle 실행
- FaceScan 실행
- 그룹 정규화
- diff 생성
- 로그/JSON 저장

### 추가 타입

```swift
#if DEBUG
import Foundation
import Photos
import OSLog

struct GroupSignature: Hashable, Codable {
    let members: [String]   // sorted
}

struct GroupDiffReport: Codable {
    let methodDescription: String
    let range: ClosedRange<Int>
    let gridInputAssetCount: Int
    let faceScanInputAssetCount: Int
    let gridGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
}

final class FaceScanGridEquivalenceTester {
    static let shared = FaceScanGridEquivalenceTester()

    func run(
        method: FaceScanMethod,
        range: ClosedRange<Int>
    ) async throws -> GroupDiffReport
}
#endif
```

### 내부 단계

#### Step 1. 입력 fetchResult 생성

FaceScan이 실제 쓰는 정렬/필터와 동일해야 하므로, FaceScanService 쪽 helper를 사용한다.

```swift
let service = FaceScanService(cache: FaceScanCache())
let fetchResult = service.debugBuildFetchResult(method: method)
```

#### Step 2. 범위 유효성 보정

- `fetchResult.count == 0` 이면 바로 빈 결과 리포트
- `range`를 `0...(fetchResult.count - 1)` 에 clamp
- clamp 결과가 역전되면 빈 결과

#### Step 3. Grid oracle 실행

```swift
await SimilarityCache.shared.clear()
let gridResult = await SimilarityAnalysisQueue.shared.debugGroupsForRange(
    clampedRange,
    fetchResult: fetchResult
)
```

#### Step 4. FaceScan 결과 실행

```swift
let faceScanCache = FaceScanCache()
let faceScanService = FaceScanService(cache: faceScanCache)
let faceScanResult = await faceScanService.analyzeDebugRange(
    fetchResult: fetchResult,
    range: clampedRange
)
```

#### Step 5. 정규화

```swift
let gridSignatures = Set(gridResult.groups.map { GroupSignature(members: $0.sorted()) })
let faceScanSignatures = Set(faceScanResult.groups.map { GroupSignature(members: $0.memberAssetIDs.sorted()) })
```

#### Step 6. diff 생성

```swift
let gridOnly = Array(gridSignatures.subtracting(faceScanSignatures)).sorted(...)
let faceScanOnly = Array(faceScanSignatures.subtracting(gridSignatures)).sorted(...)
let common = Array(gridSignatures.intersection(faceScanSignatures)).sorted(...)
```

#### Step 7. 저장/로그

- `Logger.similarPhoto.debug` 로 요약 출력
- `/tmp/facescan-grid-equivalence.json` 에 마지막 실행 결과 저장

저장 내용:

- method
- range
- 각 경로의 입력 asset 수
- 각 경로의 그룹 시그니처
- diff 결과

### 왜 이 구조가 맞는가

- Grid UI를 건드리지 않는다.
- 현재 Grid 엔진/FaceScan 엔진을 그대로 호출한다.
- 나중에 수정 전/후 diff를 같은 포맷으로 반복 수집할 수 있다.

---

## 2. `SweepPic/SweepPic/Features/FaceScan/Service/FaceScanService.swift`

production `analyze(method:onGroupFound:onProgress:)` 는 유지한다.

여기에 **DEBUG/비교용 entrypoint** 만 추가한다.

### 필요한 변경 1. fetchResult builder 노출

현재 `buildFetchResult(method:)` 가 `private` 이다. 비교 하네스가 Grid와 FaceScan에 **같은 입력 fetchResult** 를 넣으려면 이 로직을 재사용해야 한다.

변경안:

- `private` 를 `internal` 로 낮추지 말고
- `#if DEBUG` helper 를 추가한다.

```swift
#if DEBUG
func debugBuildFetchResult(method: FaceScanMethod) -> PHFetchResult<PHAsset> {
    buildFetchResult(method: method)
}
#endif
```

이유:

- production API surface 확장 최소화
- FaceScan이 실제 쓰는 predicate/sort를 그대로 재사용 가능

### 필요한 변경 2. 명시적 range 분석 entrypoint 추가

```swift
#if DEBUG
struct FaceScanDebugResult {
    let groups: [FaceScanGroup]
    let analyzedAssetIDs: [String]
}

func analyzeDebugRange(
    fetchResult: PHFetchResult<PHAsset>,
    range: ClosedRange<Int>
) async -> FaceScanDebugResult
#endif
```

### 구현 방식

중복 구현을 피하려면 현재 `analyze(...)` 의 루프를 내부 helper로 추출한다.

추천 구조:

```swift
private struct FaceScanRunConfig {
    let fetchResult: PHFetchResult<PHAsset>
    let startIndex: Int
    let endIndex: Int
    let shouldSaveSession: Bool
}

private func runAnalysis(
    config: FaceScanRunConfig,
    onGroupFound: @escaping (FaceScanGroup) -> Void,
    onProgress: @escaping (FaceScanProgress) -> Void
) async throws
```

production path:

- `buildFetchResult(method:)`
- `findStartIndex(...)`
- `endIndex = fetchResult.count - 1`
- `shouldSaveSession = true`

debug path:

- 외부에서 받은 `fetchResult`
- `startIndex = clampedRange.lowerBound`
- `endIndex = clampedRange.upperBound`
- `shouldSaveSession = false`

### runAnalysis 내부에서 반드시 유지할 현재 동작

데이터 수집 단계이므로 아래는 절대 바꾸지 않는다.

- `chunkSize = 20`
- `chunkOverlap = 3`
- `chunkStart = max(0, currentIndex - overlap)` production 로직
- 다만 debug range에서는 비교 입력을 고정해야 하므로
  - `chunkStart = max(range.lowerBound, currentIndex - overlap)`
  - `chunkEnd = min(range.upperBound, currentIndex + chunkSize - 1)`
- `excludeAssets`
- `analyzeChunk(...)`
- `hasAnyFace` 게이트
- Step 2.5 / Step 5.5 overlap 제거
- `maxScanCount` / `maxGroupCount`

주의:

debug path는 “현재 FaceScan이 **이 bounded range를 입력으로 받았을 때** 내는 결과”를 수집하는 용도다.
따라서 chunk 경계도 range 내부로 clamp 하는 것이 맞다.

### debug result 수집 방법

`onGroupFound` 콜백에서 local array에 append 한다.

동시에 최종 `analyzedAssetIDs` 도 수집한다.

추천 방식:

```swift
var emittedGroups: [FaceScanGroup] = []
var analyzedIDs: [String] = []
```

`analyzedIDs` 는 각 청크에서 실제 투입된 `photos.map(\.localIdentifier)` 를 순서대로 누적하되, 중복 제거해서 저장한다.

이 값은 “Grid와 FaceScan이 실제로 같은 입력 자산을 봤는지” 확인하는 용도다.

### 세션 저장 금지

debug path는 절대 다음을 수행하면 안 된다.

- `saveSession(...)`
- UserDefaults 갱신

이건 데이터 수집 실행이 앱 상태를 오염시키지 않게 하기 위함이다.

---

## 3. `SweepPic/SweepPic/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`

새 debug helper를 추가한다.

production `formGroupsForRange(...)` 로직은 바꾸지 않는다.

### 추가 타입

```swift
#if DEBUG
struct GridDebugResult {
    let groupIDs: [String]
    let groups: [[String]]
    let analyzedAssetIDs: [String]
}
#endif
```

### 추가 메서드

```swift
#if DEBUG
func debugGroupsForRange(
    _ range: ClosedRange<Int>,
    fetchResult: PHFetchResult<PHAsset>
) async -> GridDebugResult
#endif
```

### 구현 방식

이 helper는 절대 Grid 로직을 복제하지 않는다.

반드시 기존 production 함수를 그대로 호출한다.

```swift
let groupIDs = await formGroupsForRange(
    range,
    source: .viewer,
    fetchResult: fetchResult
)
```

그 다음:

```swift
var groups: [[String]] = []
for groupID in groupIDs {
    let members = await cache.getGroupMembers(groupID: groupID)
    groups.append(members)
}
```

`analyzedAssetIDs` 는 기존 알림 userInfo를 억지로 구독하지 말고, 같은 로직으로 직접 계산한다.

이유:

- 알림은 부수효과 채널이다.
- 비교 하네스는 직접 반환값을 가져와야 한다.

추천 방식:

- 기존 private `fetchPhotos(in:fetchResult:)` 를 재사용해
- `photos.map(\.localIdentifier)` 를 반환

즉:

```swift
let photos = fetchPhotos(in: range, fetchResult: fetchResult)
let analyzedAssetIDs = photos.map(\.localIdentifier)
```

### 실행 전 캐시 초기화

debug helper 내부가 아니라 caller에서 수행한다.

이유:

- 비교 하네스가 Grid 전/후 상태를 명시적으로 관리하는 편이 더 안전하다.
- Grid oracle 추출 전 `await SimilarityCache.shared.clear()` 를 호출한다.

---

## 실행 플로우

비교 하네스의 한 번의 실행은 아래 순서를 따른다.

1. `FaceScanService.debugBuildFetchResult(method:)` 로 fetchResult 생성
2. 비교 범위 clamp
3. `await SimilarityCache.shared.clear()`
4. `SimilarityAnalysisQueue.debugGroupsForRange(...)` 실행
5. 새 `FaceScanCache()` 생성
6. `FaceScanService.analyzeDebugRange(fetchResult:range:)` 실행
7. 두 결과를 `GroupSignature` 로 정규화
8. diff 계산
9. JSON/로그 저장

---

## 출력 포맷

### 비교용 그룹 시그니처

```swift
GroupSignature(members: members.sorted())
```

### diff report 예시

```json
{
  "methodDescription": "최신사진부터 스캔",
  "range": "100...199",
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
  "common": []
}
```

### 꼭 포함할 메타데이터

- `method.description`
- `range`
- `fetchResult.count`
- Grid 실제 입력 asset 수
- FaceScan 실제 입력 asset 수
- 각 경로 그룹 수
- diff 수

---

## 검증 항목

## 1. 입력 동등성 검증

Grid와 FaceScan이 같은 범위에서 실제로 같은 입력 자산을 봤는지 먼저 확인한다.

확인 조건:

- `gridInputAssetCount == faceScanInputAssetCount`
- 필요 시 `analyzedAssetIDs` 정렬 비교 로그 추가

이 단계가 불일치면 그룹 비교는 무의미하다.

## 2. 그룹 동등성 검증

다음 3종을 항상 출력한다.

- `gridOnly`
- `faceScanOnly`
- `common`

## 3. 대표 범위 반복 수집

초기 데이터 수집은 아래 범위로 진행한다.

- 최근 100장
- 최근 300장
- 문제 재현 anchor를 포함하는 100장 범위
- 연도별 스캔 1개 범위
- 1000장 경계 근처 범위

목적은 “어느 종류의 차이가 반복적으로 발생하는지” 패턴을 수집하는 것이다.

---

## 이번 단계에서 하지 않을 것

- FaceScan 알고리즘 수정
- Grid 알고리즘 수정
- `formGroups()` 리팩터링
- overlap 로직 수정
- `hasAnyFace` 게이트 제거
- UI 버튼 연결
- 실제 그리드 스크롤 자동화

이번 단계의 목적은 어디까지나 **정확한 diff 수집**이다.

---

## 왜 이 계획이 현재 코드에 맞는가

1. Grid oracle은 이미 production 코드에 있다.
   - `SimilarityAnalysisQueue.formGroupsForRange(...)`
   - `SimilarityCache.shared.getGroupMembers(groupID:)`

2. FaceScan은 public API가 method 기반 전체 스캔뿐이라 같은 range 비교가 불가능하다.
   - 따라서 debug range 진입점만 추가하면 된다.

3. cache 오염 문제는 이미 해결 수단이 있다.
   - `SimilarityCache.clear()`
   - `FaceScanCache` 새 인스턴스 생성

4. 이 방식은 production 로직을 거의 건드리지 않는다.
   - 데이터 수집 단계에 맞다.

---

## 구현 순서

1. `FaceScanGridEquivalenceTester.swift` 추가
2. `FaceScanService` debug helper 2개 추가
   - `debugBuildFetchResult(method:)`
   - `analyzeDebugRange(fetchResult:range:)`
3. `SimilarityAnalysisQueue.debugGroupsForRange(...)` 추가
4. JSON/log 저장 구현
5. 대표 범위 3~5개 실행
6. diff 패턴 정리 후에만 수정안 설계 시작

이 순서를 지켜야 “고치기 전에 무엇이 얼마나 다른지”를 먼저 확보할 수 있다.

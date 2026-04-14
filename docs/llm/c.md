# FaceScan = Grid 동일성 보장 설계 (최종)

## 목표

기준은 오직 하나다.

**FaceScan이 Grid와 같은 입력을 보고, 같은 그룹 형성 엔진을 타서, 같은 결과를 내는가**

추가 조건: **기존 진행률 UX를 유지한다.**

---

## 결론

FaceScan을 Grid와 동일하게 만들려면 아래 4가지가 모두 같아야 한다.

1. 같은 `PHFetchResult<PHAsset>` snapshot
2. 같은 index space
3. 같은 그룹 형성 함수
4. 같은 캐시 병합 규칙

이 조건을 만족하는 방법:

- Grid가 현재 보유 중인 `fetchResult`를 FaceScan 시작 시 그대로 넘기고
- FaceScan은 그 fetchResult 위에서 단계를 분해 호출하되
- 각 단계는 Grid의 `formGroupsForRange()` 내부와 동일한 함수를 사용하며
- 결과만 `FaceScanCache`/`FaceScanGroup`으로 브리지한다.

즉 FaceScan은 더 이상 독자 엔진이 아니라,

**Grid 엔진의 다른 UI 모드**

가 되어야 한다.

---

## 왜 기존 구조는 동일하지 않은가

### 1. 입력이 다르다

| | Grid | FaceScan (기존) |
|---|---|---|
| fetchResult | GridDataSourceDriver.fetchResult (실제 화면 snapshot) | buildFetchResult(method:) (별도 생성) |
| 정렬 | ascending | descending |
| 대상 | image + video | image only |

### 2. 엔진이 다르다

| | Grid | FaceScan (기존) |
|---|---|---|
| 그룹 형성 | formGroupsForRange() 단일 호출 | 20장 배치 축적 + sealed-group |
| 병합 | mergeOverlappingGroups (SimilarityCache) | 없음 (FaceScanCache) |
| 재시도 | 없음 | 없음 (1회 rejected → 영원히 스킵) |

---

## 핵심 설계: 단계 분해 + 진행률 유지

### formGroupsForRange 통호출 vs 단계 분해

| 방식 | 동일성 | 진행률 |
|------|--------|--------|
| formGroupsForRange 통호출 | 보장 | ~60초 0% 멈춤 |
| 단계 분해 직접 호출 | 보장 | 기존 UX 유지 |

**단계 분해를 채택한다.** formGroupsForRange 내부의 각 단계를 동일한 함수로 직접 호출하되, 단계 사이에 진행률을 보고한다.

### 왜 단계 분해가 동일성을 깨지 않는가

문제의 원인은 FP 생성을 배치로 한 것이 아니라, **formGroups + sealed 처리를 배치마다 반복**한 것이었다.

단계 분해는:
- FP 생성: 배치로 해도 됨 (그룹 형성에 영향 없음)
- formGroups: 전체 FP가 모인 뒤 **1회만 호출** (배치 축적 아님)
- 얼굴 감지 + 검증: 그룹별 순차 (formGroupsForRange와 동일)
- addGroupIfValid: 격리 SimilarityCache에서 호출 (merge 동작 동일)

---

## 실제 구현 설계

### 1. Grid fetchResult 직접 주입

```swift
let listVC = FaceScanListViewController(
    method: method,
    sourceFetchResult: dataSourceDriver.fetchResult
)
```

FaceScanService에도 전달:

```swift
func analyze(
    method: FaceScanMethod,
    fetchResult: PHFetchResult<PHAsset>,
    onGroupFound: @escaping (FaceScanGroup) -> Void,
    onProgress: @escaping (FaceScanProgress) -> Void
) async throws
```

이렇게 하면 FaceScan이 독자 fetch를 만드는 경로를 원천 차단한다.

### 2. FaceScanMethod는 주입된 Grid fetchResult 위에서 range로 해석

```swift
private func resolveAnalysisRange(
    method: FaceScanMethod,
    fetchResult: PHFetchResult<PHAsset>
) -> ClosedRange<Int>?
```

정렬 가정: ascending (Grid와 동일)

#### fromLatest

```swift
let upper = fetchResult.count - 1
let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
return lower...upper
```

#### continueFromLast

의미: 이전 실행의 가장 오래된 경계보다 더 오래된 쪽으로 계속

```swift
let upper = boundaryIndex - 1
let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
return lower...upper
```

#### byYear

의미: Grid fetchResult 안에서 해당 연도 subrange만 대상

구현: 연도에 해당하는 최소/최대 index를 찾아서 그 안에서 최신 1000장

---

### 3. 분석 파이프라인 (단계 분해 + 진행률)

```
Phase A: FP 생성 (배치, 진행률 보고)
  ┌─ 20장 FP 생성 → onProgress(scannedCount) ─┐
  │  20장 FP 생성 → onProgress(scannedCount)   │ 반복
  │  ...                                        │
  └─ 전체 FP 축적 완료 ────────────────────────┘

Phase B: 그룹 형성 (단일 호출)
  formGroups(전체 FP, 전체 ID) → rawGroups

Phase C: 그룹별 얼굴 감지 + 검증 + 브리지 (진행률 보고)
  ┌─ rawGroup → assignPersonIndicesForGroup ─┐
  │  validSlots/validMembers 계산             │
  │  addGroupIfValid (격리 SimilarityCache)   │ 그룹마다
  │  FaceScanCache 복사 + onGroupFound        │ 반복
  │  onProgress(groupCount)                   │
  └───────────────────────────────────────────┘
```

#### Phase A: FP 배치 생성

```swift
let photos = fetchPhotosInRange(analysisRange, fetchResult: sourceFetchResult)
var allFPs: [VNFeaturePrintObservation?] = []
let batchSize = 20

for batchStart in stride(from: 0, to: photos.count, by: batchSize) {
    if cancelled { throw CancellationError() }

    let batchEnd = min(batchStart + batchSize, photos.count)
    let batchPhotos = Array(photos[batchStart..<batchEnd])
    let (batchFPs, _) = await matchingEngine.generateFeaturePrints(for: batchPhotos)
    allFPs.append(contentsOf: batchFPs)

    let progress = FaceScanProgress.updated(
        scannedCount: batchEnd,
        groupCount: 0,
        currentDate: Date()
    )
    await MainActor.run { onProgress(progress) }
}
```

FP 배치는 그룹 형성에 영향을 주지 않는다. 축적만 하고 formGroups는 전체 완료 후 1회.

#### Phase B: formGroups 단일 호출

```swift
let allIDs = photos.map(\.localIdentifier)
let rawGroups = matchingEngine.analyzer.formGroups(
    featurePrints: allFPs,
    photoIDs: allIDs,
    threshold: SimilarityConstants.similarityThreshold
)
```

배치 축적 + sealed 처리 없음. 전체 FP에 대해 1회 호출.

#### Phase C: 그룹별 처리 + 브리지

```swift
let isolatedCache = SimilarityCache()
var totalGroupsFound = 0

for groupAssetIDs in rawGroups {
    if cancelled { throw CancellationError() }

    let groupPhotos = photos.filter { groupAssetIDs.contains($0.localIdentifier) }

    // 얼굴 감지 + 인물 매칭 (formGroupsForRange:384와 동일)
    let photoFacesMap = await matchingEngine.assignPersonIndicesForGroup(
        assetIDs: groupAssetIDs,
        photos: groupPhotos
    )

    // validSlots 계산 (formGroupsForRange:392-401과 동일)
    var slotPhotoCount: [Int: Set<String>] = [:]
    for (assetID, faces) in photoFacesMap {
        for face in faces {
            slotPhotoCount[face.personIndex, default: []].insert(assetID)
        }
    }
    let validSlots = Set(slotPhotoCount.filter {
        $0.value.count >= SimilarityConstants.minPhotosPerSlot
    }.keys)

    // validMembers 필터 (formGroupsForRange:405-408과 동일)
    let validMembers = groupAssetIDs.filter { assetID in
        guard let faces = photoFacesMap[assetID] else { return false }
        return faces.contains { validSlots.contains($0.personIndex) }
    }

    // addGroupIfValid (mergeOverlappingGroups 포함)
    if let groupID = await isolatedCache.addGroupIfValid(
        members: validMembers,
        validSlots: validSlots,
        photoFaces: photoFacesMap
    ) {
        // FaceScanCache로 브리지
        let members = await isolatedCache.getGroupMembers(groupID: groupID)
        let mergedSlots = await isolatedCache.getGroupValidPersonIndices(for: groupID)

        for assetID in members {
            let faces = await isolatedCache.getFaces(for: assetID)
            await cache.setFaces(faces, for: assetID)
        }

        let group = SimilarThumbnailGroup(groupID: groupID, memberAssetIDs: members)
        await cache.addGroup(group, validSlots: mergedSlots, photoFaces: [:])

        totalGroupsFound += 1

        // maxGroupCount는 UI 전달 상한 (엔진 제한 아님)
        if totalGroupsFound <= FaceScanConstants.maxGroupCount {
            let scanGroup = FaceScanGroup(
                groupID: groupID,
                memberAssetIDs: members,
                validPersonIndices: mergedSlots
            )
            let progress = FaceScanProgress.updated(
                scannedCount: photos.count,
                groupCount: totalGroupsFound,
                currentDate: Date()
            )
            await MainActor.run {
                onGroupFound(scanGroup)
                onProgress(progress)
            }
        }
    }
}
```

---

### 4. 세션 저장 (ascending 기준)

ascending에서 "다음에 이어서"는 범위의 lowerBound (가장 오래된 쪽).

```swift
let boundaryAsset = sourceFetchResult.object(at: analysisRange.lowerBound)
saveSession(
    method: method,
    lastDate: boundaryAsset.creationDate,
    lastAssetID: boundaryAsset.localIdentifier
)
```

---

### 5. 취소

`formGroupsForRange` 통호출이 아니므로 각 단계에서 `cancelled` 체크 가능.

- Phase A: 배치마다 체크
- Phase C: 그룹마다 체크

추가로 `FaceScanListViewController`에서 Task 저장 + `task.cancel()` 호출:

```swift
private var analysisTask: Task<Void, Error>?

func startAnalysis(method: FaceScanMethod) {
    analysisTask = Task {
        try await scanService.analyze(method: method, fetchResult: sourceFetchResult, ...)
    }
}

// 취소 시
analysisTask?.cancel()
scanService?.cancel()
```

이렇게 하면 `generateFeaturePrints` 내부의 `Task.checkCancellation()`도 동작.

---

### 6. maxGroupCount는 UI 정책

그룹 형성은 전부 수행한다. UI 전달만 상한을 적용한다.

이유:
- 그룹 형성 단계에서 30개에 도달했다고 멈추면 Grid와 동등성이 깨진다
- addGroupIfValid의 merge가 이후 그룹에도 영향을 줄 수 있다
- UI 상한과 engine 상한은 분리해야 한다

---

## 비디오 포함 여부

strict equality가 목표라면 선택지가 아니다.

Grid가 비디오를 포함하면 FaceScan도 포함해야 한다. Grid fetchResult를 그대로 주입하므로 자동으로 해결된다.

---

## 진행률 UX 비교

| | 기존 FaceScan | formGroupsForRange 통호출 | 이 설계 (단계 분해) |
|---|---|---|---|
| FP 생성 중 | 20장마다 게이지 업데이트 | 0% ~30초 멈춤 | 20장마다 게이지 업데이트 |
| 첫 그룹 표시 | ~3초 | ~60초 | FP 완료 후 즉시 (~30초) |
| 그룹 표시 | 하나씩 즉시 | 한꺼번에 | 하나씩 즉시 |
| 완료 | 자연스러움 | 급격한 점프 | 자연스러움 |

FP 생성 후 첫 그룹까지 ~30초 대기는 기존(~3초)보다 느리지만, 게이지가 멈추지는 않는다.

---

## 파일별 변경안

| 파일 | 변경 |
|------|------|
| `GridViewController+FaceScan.swift` | `FaceScanListViewController(method:sourceFetchResult:)` 호출 |
| `FaceScanListViewController.swift` | init에 `sourceFetchResult` 추가, Task 저장 + cancel |
| `FaceScanService.swift` | analyze() 배치 루프 → 단계 분해로 교체, resolveAnalysisRange 추가, saveSession 수정 |

**변경 없음**: FaceScanCache, FaceComparisonViewController, SimilarityCache, SimilarityAnalysisQueue, GridViewController

---

## 동일성 검증 체크리스트

- [ ] 같은 fetchResult instance (Grid에서 주입)
- [ ] 같은 fetchPhotos (trash 제외)
- [ ] 같은 generateFeaturePrints (같은 matchingEngine)
- [ ] 같은 formGroups (전체 FP 1회 호출, 배치 축적 아님)
- [ ] 같은 assignPersonIndicesForGroup (같은 matchingEngine)
- [ ] 같은 validSlots/validMembers 계산
- [ ] 같은 addGroupIfValid + mergeOverlappingGroups (격리 SimilarityCache)
- [ ] maxGroupCount는 UI 전달 상한 (엔진 미제한)
- [ ] 비디오 포함 (Grid fetchResult 그대로)

---

## 최종 판단

이 설계는 d.md의 strict equality를 유지하면서, 기존 진행률 UX도 보존한다.

핵심 차이는 formGroupsForRange를 통째로 호출하는 대신, **내부 단계를 동일한 함수로 분해 호출**하는 것이다. 이렇게 하면:

- FP 배치 생성으로 진행률 보고 가능
- formGroups는 전체 1회 호출로 배치 축적 문제 제거
- 그룹별 즉시 콜백으로 기존 UX 유지
- addGroupIfValid로 merge 동일성 보장

한 줄 요약:

**FaceScan은 Grid fetchResult를 받아, Grid 엔진의 각 단계를 동일하게 실행하되, 단계 사이에 진행률을 보고하는 다른 UI다.**

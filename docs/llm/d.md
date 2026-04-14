# FaceScan = Grid 동일성 보장 설계

## 목표

이 문서의 기준은 구현 편의가 아니다.

기준은 오직 하나다.

**FaceScan이 Grid와 같은 입력을 보고, 같은 그룹 형성 엔진을 타서, 같은 결과를 내는가**

즉 질문은 이것이다.

- "잘 동작할까?"가 아니라
- "**Grid와 FaceScan이 구조적으로 같은가?**"

이 기준에서 기존 `b.md`는 방향은 맞지만 아직 strict equality 관점에서 한 단계 부족하다.

가장 큰 부족점:

- `PhotoLibraryService.fetchAllPhotos()`를 다시 호출하는 방식은 "같은 조건"일 수는 있어도
- **Grid가 지금 실제로 들고 있는 그 fetchResult snapshot과 완전히 같다고 보장하지는 못한다**

따라서 이 문서는 `b.md`를 보강하여,

1. **Grid의 실제 fetchResult를 FaceScan에 직접 전달**
2. 그 fetchResult 위에서 **같은 range 의미**
3. **같은 formGroupsForRange()**
4. **같은 mergeOverlappingGroups**

까지 맞추는 설계를 제안한다.

---

## 결론

FaceScan을 Grid와 동일하게 만들려면 아래 4가지가 모두 같아야 한다.

1. 같은 `PHFetchResult<PHAsset>` snapshot
2. 같은 index space
3. 같은 그룹 형성 함수
4. 같은 캐시 병합 규칙

이 조건을 만족하는 가장 직접적인 방법은:

- Grid가 현재 보유 중인 `fetchResult`를 FaceScan 시작 시 그대로 넘기고
- FaceScan은 그 fetchResult 위에서 `SimilarityAnalysisQueue.formGroupsForRange()`를 격리 호출하며
- 결과만 `FaceScanCache`/`FaceScanGroup`으로 브리지하는 것이다.

즉 FaceScan은 더 이상 독자 엔진이 아니라,

**Grid 엔진의 다른 UI 모드**

가 되어야 한다.

---

## 왜 기존 구조는 동일하지 않은가

현재 차이는 크게 두 층이다.

### 1. 입력이 다르다

Grid:
- `GridDataSourceDriver.fetchResult`
- 실제 사용자 화면과 같은 snapshot
- ascending
- image + video

기존 FaceScan:
- `buildFetchResult(method:)`
- 호출 시점에 새로 만든 별도 snapshot
- descending
- image only

이 시점에서 이미 strict equality는 깨진다.

### 2. 엔진이 다르다

Grid:
- `SimilarityAnalysisQueue.formGroupsForRange()`
- 내부에서 `addGroupIfValid()`
- 내부에서 `mergeOverlappingGroups()`

기존 FaceScan:
- 누적 배치
- sealed/unsealed 처리
- 독자 `processGroupForFaceScan()`
- merge 없음

즉 같은 멤버가 있어도 최종 그룹 경계가 달라질 수밖에 없다.

---

## 동일성의 정의

이 설계에서 "동일"은 아래 의미다.

### 동일 입력

- 같은 `PHFetchResult` 인스턴스 또는 적어도 같은 snapshot
- 같은 인덱스
- 같은 asset ordering
- 같은 trashed 제외 규칙

### 동일 엔진

- 같은 `fetchPhotos`
- 같은 `generateFeaturePrints`
- 같은 `formGroups`
- 같은 `assignPersonIndicesForGroup`
- 같은 `validSlots / validMembers`
- 같은 `addGroupIfValid`
- 같은 `mergeOverlappingGroups`

### 동일 출력

- 비교 기준은 `memberAssetIDs` 집합
- `groupID`는 동일성 기준이 아님

---

## b.md 대비 핵심 보강점

`b.md`의 핵심 장점은 유지하되, 아래를 강화한다.

### 보강 1. fetchAllPhotos() 재조회 대신 Grid fetchResult 직접 전달

`b.md`의 약점:

- `PhotoLibraryService.shared.fetchAllPhotos()`를 새로 호출하면
- "Grid와 같은 쿼리"일 수는 있어도
- "Grid가 지금 들고 있는 정확한 snapshot"은 아닐 수 있다

예:

- 사용자가 FaceScan 시작 직전 사진을 추가/삭제
- PhotoKit change 반영 타이밍 차이
- Grid는 old snapshot, FaceScan은 new snapshot

이 경우 같은 설계를 써도 strict equality는 깨질 수 있다.

### 보강 2. method 의미를 Grid fetchResult 위에서 정의

`fromLatest`, `continueFromLast`, `byYear`는
이제 "FaceScan이 만든 fetchResult"가 아니라
**Grid fetchResult 위의 range 해석 규칙**이어야 한다.

### 보강 3. 비디오 포함 여부를 옵션으로 두지 않음

strict equality가 목표라면
"비디오를 포함할지 말지"는 선택지가 아니다.

Grid가 비디오를 포함하면 FaceScan도 포함해야 한다.

### 보강 4. 진행률/취소/세션 저장을 equality를 깨지 않는 보조 정책으로 제한

이 항목들은 엔진보다 우선할 수 없다.

- progress는 단순화 가능
- cancellation은 호출 제어의 문제
- session 저장은 다음 range 계산 규칙의 문제

하지만 이 셋이 그룹 형성 규칙을 바꾸면 안 된다.

---

## 최종 설계

## 1. FaceScan 진입 시 Grid fetchResult를 직접 주입

현재:

- `GridViewController+FaceScan`에서 method만 넘김

변경:

- `GridViewController`가 현재 사용 중인 fetchResult를 `FaceScanListViewController`에 전달

예시:

```swift
let listVC = FaceScanListViewController(
    method: method,
    sourceFetchResult: dataSourceDriver.fetchResult
)
```

또는 직접 `PHFetchResult`를 넘기기 부담되면,

- `GridDataSourceDriver` 또는 `GridDataSource`를 넘겨서
- 시작 시점의 fetchResult를 고정 스냅샷처럼 읽게 할 수 있다

하지만 strict equality 관점에서는

**실제 fetchResult 자체를 직접 넘기는 편이 더 좋다.**

### 권장 시그니처

```swift
final class FaceScanListViewController: UIViewController {
    init(method: FaceScanMethod, sourceFetchResult: PHFetchResult<PHAsset>)
}
```

그리고 `FaceScanService`에도 전달:

```swift
func analyze(
    method: FaceScanMethod,
    fetchResult: PHFetchResult<PHAsset>,
    onGroupFound: @escaping (FaceScanGroup) -> Void,
    onProgress: @escaping (FaceScanProgress) -> Void
) async throws
```

이렇게 하면 FaceScan이 독자 fetch를 만드는 경로를 원천 차단할 수 있다.

---

## 2. FaceScanMethod는 주입된 Grid fetchResult 위에서 range로 해석

새 helper:

```swift
private func resolveAnalysisRange(
    method: FaceScanMethod,
    fetchResult: PHFetchResult<PHAsset>
) -> ClosedRange<Int>?
```

중요:

- 이 함수는 **반드시 Grid fetchResult 기준**
- 정렬 가정은 ascending

### fromLatest

```swift
let upper = fetchResult.count - 1
let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
return lower...upper
```

### continueFromLast

의미:

- 이전 실행에서 처리한 가장 오래된 경계보다 더 오래된 쪽으로 계속

ascending 기준:

```swift
let boundaryIndex = ...
let upper = boundaryIndex - 1
let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
return lower...upper
```

### byYear

의미:

- 주입된 Grid fetchResult 안에서 해당 연도 subrange만 사용

구현 원칙:

- 연도에 해당하는 최소/최대 index를 찾는다
- 그 안에서 최신 쪽 1000장만 취한다
- `continueFrom`이 있으면 upperBound를 더 줄인다

중요:

연도 계산도 **새 fetch가 아니라 주입된 fetchResult 기준**이어야 한다.

---

## 3. 그룹 형성은 격리 formGroupsForRange 1회 호출

FaceScan의 독자 배치 루프는 제거한다.

```swift
let isolatedCache = SimilarityCache()
let isolatedQueue = SimilarityAnalysisQueue(cache: isolatedCache)

let groupIDs = await isolatedQueue.formGroupsForRange(
    analysisRange,
    source: .grid,
    fetchResult: sourceFetchResult
)
```

이 방식이 중요한 이유:

- Grid와 같은 engine
- Grid와 같은 merge
- Grid와 같은 group validation

즉 "비슷하게 만든다"가 아니라
"같은 코드를 실행한다"가 된다.

---

## 4. 결과는 FaceScan UI 모델로만 브리지

그룹 형성은 Grid 엔진이 한다.
FaceScan은 결과를 보여주는 UI 레이어만 담당한다.

브리지 방식:

```swift
for groupID in groupIDs.prefix(FaceScanConstants.maxGroupCount) {
    let members = await isolatedCache.getGroupMembers(groupID: groupID)
    let validSlots = await isolatedCache.getGroupValidPersonIndices(for: groupID)

    var photoFaces: [String: [CachedFace]] = [:]
    for assetID in members {
        photoFaces[assetID] = await isolatedCache.getFaces(for: assetID)
    }

    let group = SimilarThumbnailGroup(groupID: groupID, memberAssetIDs: members)
    await cache.addGroup(group, validSlots: validSlots, photoFaces: photoFaces)

    await MainActor.run {
        onGroupFound(FaceScanGroup(
            groupID: groupID,
            memberAssetIDs: members,
            validPersonIndices: validSlots
        ))
    }
}
```

### 원칙

- 결과 형성은 Grid
- 결과 저장/표시는 FaceScan

즉 responsibility를 분리한다.

---

## 5. maxGroupCount는 UI 정책이지 엔진 입력 제한이 아님

strict equality 관점에서 중요한 점:

- 그룹 형성 자체는 전부 해야 한다
- 그 뒤 UI에 몇 개 보여줄지는 FaceScan 정책일 수 있다

따라서:

- `analysisRange`는 최대 1000장 정책을 그대로 적용 가능
- 하지만 range 안 그룹 형성은 전부 수행
- `maxGroupCount`는 `prefix(30)`로 전달만 제한

이게 맞는 이유:

- 그룹 형성 단계에서 30개에 도달했다고 멈추면 Grid와 동등성이 약해진다
- UI 상한과 engine 상한은 분리해야 한다

---

## 6. 세션 저장도 Grid fetchResult 기준

세션 저장은 다음 continue range를 계산하기 위한 boundary 저장이다.

ascending 기준이므로:

- 다음 continue는 더 오래된 쪽으로 이동해야 한다
- 따라서 현재 range의 `lowerBound` asset을 저장해야 한다

```swift
let boundaryAsset = sourceFetchResult.object(at: analysisRange.lowerBound)
saveSession(
    method: method,
    lastDate: boundaryAsset.creationDate,
    lastAssetID: boundaryAsset.localIdentifier
)
```

여기서도 기준은 항상:

**Grid fetchResult index space**

다.

---

## 7. cancellation과 progress는 equality를 깨지 않는 선에서 단순화

### cancellation

권장:

- `scanTask.cancel()`
- `scanService.cancel()`

둘 다 유지

이유:

- `formGroupsForRange()`는 `Task.isCancelled`를 봄
- service 레벨 플래그는 외부 상태 표현용으로 유지 가능

### progress

이 설계는 배치 progress를 잃는다.
하지만 strict equality 목표에서는 허용 가능하다.

1차 구현:

1. 시작 시 0
2. `formGroupsForRange()` 완료 후 `scannedCount = 실제 range 장수`
3. 그룹 브리지하면서 `groupCount` 증가
4. 완료

즉 progress는 약해져도 엔진 동일성은 유지한다.

---

## 파일별 변경안

### 1. `GridViewController+FaceScan.swift`

변경:

- `FaceScanListViewController(method:)`
- ->
- `FaceScanListViewController(method:sourceFetchResult:)`

필요 조건:

- 현재 Grid가 쓰는 fetchResult가 nil이 아니어야 함

### 2. `FaceScanListViewController.swift`

변경:

- init에 `sourceFetchResult` 추가
- `startAnalysis()`에서 service.analyze 호출 시 함께 전달
- cancel 시 `scanTask.cancel()` 유지/보강

### 3. `FaceScanService.swift`

변경:

- `buildFetchResult(method:)`를 analyze 핵심 경로에서 제거
- `resolveAnalysisRange(method:fetchResult:)` 추가
- 기존 배치 루프 제거
- 격리 `SimilarityAnalysisQueue(cache:)` 호출
- 결과 브리지
- 세션 저장 경계 수정

### 4. 선택적 정리

- 진단용 debug path는 유지 가능
- 하지만 production 경로는 더 이상 독자 배치 엔진을 타지 않도록 분리

---

## 이 설계의 장점

- strict equality 관점에서 가장 강하다
- Grid와 FaceScan이 같은 snapshot을 본다
- Grid와 FaceScan이 같은 engine을 탄다
- 기존 FaceScan UI는 대부분 유지 가능하다
- 문제 원인인 batch/sealed/descending/image-only 차이를 전부 제거한다

---

## 이 설계의 단점

### 1. 진행률 UX 저하

배치형 progress가 사라진다.

하지만 equality 목표에서는 수용 가능하다.

### 2. Grid fetchResult 의존성 증가

FaceScan이 더 이상 완전히 독립적인 스캔기가 아니다.

하지만 이번 목표는 "독립성"이 아니라 "동일성"이므로 오히려 맞는 방향이다.

### 3. Grid가 없는 진입점은 별도 처리 필요

만약 미래에 FaceScan을 Grid 밖에서 실행한다면,

- 그때는 별도 snapshot 생성 규칙이 필요하다
- 하지만 그 경우는 strict equality 대상이 아니므로 별도 정책으로 분리하면 된다

---

## 최종 판단

`b.md`는 "같은 쿼리 + 같은 엔진" 수준의 설계다.

이 문서 `d.md`는 그걸 더 밀어붙여

**"같은 snapshot + 같은 engine"**

으로 만든다.

Grid와 FaceScan이 정말 동일해야 한다면,
이게 더 맞다.

한 줄로 요약하면:

**FaceScan은 Grid와 같은 fetchResult를 받아, Grid 엔진을 그대로 실행하는 다른 UI여야 한다.**

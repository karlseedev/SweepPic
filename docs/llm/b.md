# FaceScan을 Grid 엔진으로 교체하는 설계 재검토

## 결론

방향 자체는 맞다.

- FaceScan의 독자 배치 파이프라인을 유지하면 Grid와 완전 동등해질 수 없다.
- 그룹 형성은 `SimilarityAnalysisQueue.formGroupsForRange()`를 격리 호출하는 방식으로 통일해야 한다.

다만 이전 설계는 아래 3가지를 더 구체화해야 실제 구현이 안전하다.

1. `fetchResult`를 Grid와 완전히 동일하게 맞출 것
2. `FaceScanMethod`를 ascending 기준 range로 다시 정의할 것
3. 세션 저장 경계(`lastAssetID`, `lastScanDate`)를 새 기준에 맞게 바꿀 것

핵심은 "FaceScan이 Grid 엔진을 재사용한다"가 아니라, "FaceScan이 Grid와 같은 입력 우주 위에서 Grid 엔진을 돌린다"이다.

---

## 왜 이전 FaceScan이 틀렸는가

현재 FaceScan은 다음 두 가지가 Grid와 다르다.

1. `fetchResult`가 다르다
- FaceScan: `descending + image-only`
- Grid: `ascending + image+video`

2. 그룹 확정 방식이 다르다
- FaceScan: 20장 누적 배치 + sealed group
- Grid: 주어진 range를 한 번에 처리 + `mergeOverlappingGroups`

로그상 문제 그룹은:

- FaceScan 범위 안에 있었다
- 얼굴 감지/validSlots/validMembers도 통과했다
- 격리 Grid 파이프라인에서는 `accepted`였다

즉 원인은 매칭 엔진이 아니라 FaceScan의 바깥 파이프라인이다.

---

## 설계 판단

### 채택

`FaceScanService.analyze()`의 중심 로직을 다음으로 교체한다.

1. Grid와 같은 `PHFetchResult<PHAsset>` 생성
2. `FaceScanMethod`를 그 fetchResult 위의 `ClosedRange<Int>`로 변환
3. 격리 `SimilarityAnalysisQueue(cache:)`에서 `formGroupsForRange()` 1회 호출
4. 결과를 `FaceScanCache`와 `FaceScanGroup`으로 브리지

### 기각

기존 FaceScan 배치 루프를 유지한 채 일부만 보정하는 방식

이 방식은 계속해서 아래 위험을 남긴다.

- batch 경계 차이
- sealed/unsealed 차이
- merge 부재
- Grid와 다른 입력 집합

즉 버그를 고치는 게 아니라 차이를 줄이는 수준에 머문다.

---

## 실제 구현 설계

## 1. fetchResult 통일

FaceScan 전용 `buildFetchResult(method:)`를 그룹 형성의 기준으로 쓰지 않는다.

대신 Grid와 동일한 소스를 사용한다.

```swift
let fetchResult = PhotoLibraryService.shared.fetchAllPhotos()
```

이 fetchResult의 의미:

- 정렬: `creationDate ASC`
- 대상: `image + video`

이걸 써야 Grid 인덱스와 FaceScan 인덱스가 같은 우주에서 해석된다.

### 비고

`buildFetchResult(method:)` 자체를 바로 삭제할 필요는 없다.

- DEBUG 진단용 비교
- 마이그레이션 중 레거시 동작 확인

용도로 잠시 남겨둘 수 있다.

---

## 2. method를 ascending range로 재정의

이 단계가 구현의 핵심이다.

기존 FaceScan은 descending 기준으로 "처음 1000장"을 본다.
Grid fetchResult는 ascending이므로, 같은 의미를 range로 다시 계산해야 한다.

새 private helper 예시:

```swift
private func resolveAnalysisRange(
    method: FaceScanMethod,
    fetchResult: PHFetchResult<PHAsset>
) -> ClosedRange<Int>?
```

### fromLatest

의미:
- 최신 사진부터 최대 1000장

ascending 기준 구현:

```swift
let upper = fetchResult.count - 1
let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
return lower...upper
```

### continueFromLast

의미:
- 이전 실행에서 처리한 가장 오래된 경계보다 더 오래된 쪽으로 계속

ascending 기준 구현:

1. 저장된 `lastAssetID`를 fetchResult에서 찾는다.
2. 그 index의 바로 앞이 이번 실행의 `upperBound`다.
3. 거기서 다시 최대 1000장만 뒤로 확장한다.

```swift
let upper = boundaryIndex - 1
let lower = max(0, upper - FaceScanConstants.maxScanCount + 1)
return lower...upper
```

### byYear(year, continueFrom)

의미:
- shared fetchResult 안에서 해당 연도 subrange만 대상으로 함
- 그 subrange의 최신 쪽부터 최대 1000장

구현:

1. fetchResult를 순회해 해당 연도에 속하는 최소/최대 index를 찾는다.
2. `continueFrom`이 있으면 그 날짜보다 오래된 쪽까지만 `upperBound`를 줄인다.
3. 남은 year subrange 안에서 다시 최신 1000장을 계산한다.

---

## 3. 그룹 형성은 formGroupsForRange 1회 호출

기존 배치 루프 전체를 제거하고 격리 queue를 쓴다.

```swift
let isolatedCache = SimilarityCache()
let isolatedQueue = SimilarityAnalysisQueue(cache: isolatedCache)

let groupIDs = await isolatedQueue.formGroupsForRange(
    analysisRange,
    source: .grid,
    fetchResult: fetchResult
)
```

이 호출이 보장하는 것:

- Grid와 같은 `fetchPhotos`
- Grid와 같은 `generateFeaturePrints`
- Grid와 같은 `formGroups`
- Grid와 같은 `assignPersonIndicesForGroup`
- Grid와 같은 `validSlots / validMembers`
- Grid와 같은 `addGroupIfValid`
- Grid와 같은 `mergeOverlappingGroups`

즉 문제의 핵심인 그룹 형성 규칙을 전부 재사용한다.

---

## 4. 결과 브리지

FaceScan UI는 현재 `FaceScanCache`와 `FaceScanGroup`에 기대고 있다.
따라서 격리 `SimilarityCache` 결과를 읽어서 FaceScan 쪽 모델로 옮긴다.

필요한 데이터:

- `groupID`
- `memberAssetIDs`
- `validSlots`
- member별 `CachedFace`

예시 흐름:

```swift
for groupID in groupIDs {
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

### 왜 copy가 필요한가

더 단순한 구조는 FaceScan이 `SimilarityCache`를 직접 들고 가는 것이다.
하지만 현재 UI 타입은 `FaceScanCache`를 중심으로 짜여 있다.

따라서 1차 구현은 "격리 SimilarityCache -> FaceScanCache 복사"가 안전하다.

---

## 5. 진행률 처리

이 설계의 단점은 `formGroupsForRange()`가 내부 일괄 실행이라는 점이다.
즉 기존 FaceScan처럼 배치별 progress를 자연스럽게 줄 수 없다.

1차 구현 원칙:

- correctness 우선
- progress는 단순화

권장안:

1. 시작 시 `0 / 0`
2. `formGroupsForRange()` 완료 후 `scannedCount = range 내 실제 분석 장수`
3. 그룹을 브리지하며 `groupCount`만 1씩 증가
4. 마지막 완료 표시

이렇게 하면 UX는 약간 단순해지지만, 결과 동등성은 맞출 수 있다.

---

## 6. 세션 저장 규칙 재정의

이 부분이 이전 설계에서 가장 덜 구체화된 부분이다.

현재 FaceScan은 descending 기준이라 실행 종료 시 `endIndex` asset을 저장한다.
하지만 ascending range로 바꾸면 continue 기준도 바뀐다.

### 새 원칙

- `fromLatest` / `continueFromLast` 완료 시:
  - 이번 range에서 **가장 오래된 쪽 asset**을 경계로 저장
  - 즉 `analysisRange.lowerBound`의 asset을 저장

- 이유:
  - 다음 continue는 그보다 더 오래된 쪽으로 가야 하기 때문

예시:

```swift
let boundaryAsset = fetchResult.object(at: analysisRange.lowerBound)
saveSession(method: method, lastDate: boundaryAsset.creationDate, lastAssetID: boundaryAsset.localIdentifier)
```

`byYear`도 동일하게 해당 year subrange 안에서 `lowerBound` 경계를 저장한다.

---

## 7. 취소 동작

이 설계는 별도 배치 루프가 없어져서 `service.cancelled` 체크 지점은 줄어든다.

하지만 실제 호출 경로에서는:

- `scanService?.cancel()`
- `scanTask?.cancel()`

가 함께 호출된다.

`formGroupsForRange()` 내부는 `Task.isCancelled`를 보므로, `scanTask.cancel()` 경로는 그대로 작동한다.

따라서 1차 구현은 아래 정도면 충분하다.

- 호출 전 `if cancelled { throw CancellationError() }`
- `formGroupsForRange()` 반환 직후 한 번 더 취소 체크

---

## 8. maxGroupCount 처리

주의점:

- Grid 엔진은 range 내 그룹을 전부 만들 수 있다.
- FaceScan UX는 최대 30그룹만 보여주고 싶다.

따라서 그룹 형성은 전체 수행하되, 전달만 상한을 적용한다.

```swift
for groupID in groupIDs.prefix(FaceScanConstants.maxGroupCount) { ... }
```

이 방식이 맞는 이유:

- 그룹 형성 자체는 Grid와 동등해야 한다.
- UI/세션 정책만 FaceScan 상한을 적용해야 한다.

---

## 9. 이전 설계에서 수정해야 할 점

### 맞는 점

- FaceScan이 `formGroupsForRange()`를 재사용해야 한다는 판단
- `PhotoLibraryService.fetchAllPhotos()`를 써야 한다는 판단
- 결과를 `FaceScanGroup`으로 브리지해야 한다는 판단

### 보완된 점

- 단순히 "끝에서 1000장"이 아니라 `continueFromLast`, `byYear`를 ascending range로 재정의해야 함
- 세션 저장 경계는 `upperBound`가 아니라 `lowerBound`
- `maxGroupCount`는 엔진 입력 제한이 아니라 UI 전달 상한으로 취급하는 편이 안전함
- `buildFetchResult()`는 즉시 삭제보다 마이그레이션 단계에서 보조 용도로 남길 수 있음

---

## 최종 권장 구현 순서

1. `FaceScanService`에 `resolveAnalysisRange(method:fetchResult:)` 추가
2. `analyze()`에서 `buildFetchResult()/findStartIndex()` 경로 제거
3. `PhotoLibraryService.shared.fetchAllPhotos()` 기반으로 `analysisRange` 계산
4. 격리 `SimilarityAnalysisQueue(cache:)`로 `formGroupsForRange()` 1회 호출
5. 결과를 `FaceScanCache` + `FaceScanGroup`으로 브리지
6. `saveSession()` 호출 기준을 `analysisRange.lowerBound` asset으로 변경
7. progress는 단순화하여 유지
8. 배치 진단용 DEBUG 로그는 제거하거나 별도 진단 경로로 이동

---

## 최종 판단

이 설계는 "FaceScan을 Grid처럼 보이게 고친다"가 아니라,
"FaceScan의 그룹 형성 자체를 Grid 엔진으로 바꾼다"는 설계다.

문제의 원인이 구조 차이였기 때문에, 해결도 구조 수준에서 가야 한다.

이게 현재 코드 기준으로 가장 짧고, 가장 안전하고, 가장 설득력 있는 수정 방향이다.

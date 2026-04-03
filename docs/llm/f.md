# FaceScan-Grid 동등성 검증 선행 계획

## 목적

이 문서는 **FaceScan 수정안 문서가 아니라, 수정 전에 반드시 구현해야 하는 검증/데이터 수집 문서**다.

최종 목표는 하나다.

- **FaceScan 결과가 사용자가 실제 Grid에서 보던 최종 결과와 정확히 같아야 한다.**

따라서 이 문서는 다음보다 우선한다.

- `docs/llm/a.md`
- `docs/llm/b.md`
- `docs/llm/c.md`
- `docs/llm/d.md`
- 모든 구조 수정안

핵심 원칙:

- baseline을 새로 구현하지 않는다
- production 알고리즘을 먼저 바꾸지 않는다
- 현재 Grid production 결과를 oracle로 삼는다
- 단, 최종 oracle은 “engine 1회 실행 결과”가 아니라 **live Grid final state**다

---

## 최종 oracle 정의

이번 문서에서 최종 oracle은 다음이다.

- **실제 live Grid 세션에서, 사용자가 보던 시점의 최종 shared-cache 그룹 상태**

즉 비교 기준은:

1. 실제 Grid가 생성한 요청들
2. 그 요청들의 cancel/complete 순서
3. 그 결과 `SimilarityCache.shared` 에 남은 최종 그룹 멤버들

중요:

- 새 baseline 함수는 oracle이 아니다
- 명시적 range로 Grid 엔진을 한 번 돌린 결과도 oracle이 아니다
- FaceScan이 실제 본 사진들로 재계산한 결과도 oracle이 아니다

최종 비교 대상은 오직:

- **live Grid final group signatures**
- **FaceScan final group signatures**

이다.

---

## 왜 2단계가 필요한가

최종 목표만 보면 live Grid 비교 하나만 있으면 될 것 같지만, 그 상태로는 원인 분리가 안 된다.

그래서 두 단계가 필요하다.

## Stage 1: Engine Equivalence

목적:

- 같은 명시적 입력 범위에 대해
- Grid 엔진 결과와 FaceScan 결과가 같은지 확인

역할:

- 알고리즘 차이 / 입력 처리 차이 / 종료 조건 차이 분리

여기서 다르면:

- live Grid replay 전에 이미 FaceScan 로직이 다르다는 뜻이다

## Stage 2: Live Grid Equivalence

목적:

- 사용자가 실제로 보던 Grid final state와 FaceScan 결과를 비교

역할:

- 최종 승인 기준

즉:

- **Stage 1은 원인 분리용**
- **Stage 2는 최종 동등성 검증용**

이다.

최종 합격 기준은 Stage 2 PASS다.

---

## 현재 코드 기준 사실 정리

## Grid production 경로

현재 Grid/Viewer 공용 분석 경로는 다음이다.

- `SimilarityAnalysisQueue.formGroupsForRange(...)`

내부 핵심 단계:

1. `fetchPhotos(in:range, fetchResult:)`
2. `matchingEngine.generateFeaturePrints(for:)`
3. `analyzer.formGroups(...)`
4. `rawGroups` 전체에 대해 `assignPersonIndicesForGroup(...)`
5. `SimilarityCache.addGroupIfValid(...)`
6. `similarPhotoAnalysisComplete` notification 발송

최종 그룹 source of truth:

- `SimilarityCache.groups[groupID].memberAssetIDs`

중요:

- Grid는 `hasFaces`를 최종 그룹 스킵 조건으로 쓰지 않는다
- Grid는 여러 request 결과가 `SimilarityCache.shared` 위에 누적된다
- 그룹 병합은 `SimilarityCache.addGroupIfValid(...)` 내부에서 일어난다

## FaceScan production 경로

현재 FaceScan 경로는 다음이다.

- `FaceScanService.analyze(...)`
- 청크 루프
- `analyzeChunk(photos:excludeAssets:)`

구조적 차이:

- 20장 청크 + overlap 3장
- Step 2.5 사전 필터
- `hasAnyFace` 게이트
- Step 5.5 overlap 멤버 제거
- `FaceScanCache` 사용

즉 현재는 Grid와 다를 수 있다.

---

## 핵심 설계 원칙

## 원칙 1. production 알고리즘은 먼저 바꾸지 않는다

이번 단계에서 하지 않을 것:

- `formGroups()` 재구현
- FaceScan overlap 로직 수정
- FaceScan `hasAnyFace` 게이트 수정
- Grid 알고리즘 수정

허용되는 변경:

- debug helper 추가
- side effect 분리용 core 추출
- recorder 추가
- snapshot/diff 저장 코드

## 원칙 2. Stage 1은 isolated execution 이어야 한다

Stage 1은 live UI를 오염시키면 안 된다.

따라서 금지:

- `SimilarityCache.shared.clear()`
- shared queue/shared cache 재사용
- analytics 전송
- global notification 발송

Stage 1은:

- 새 `SimilarityCache`
- 새 `SimilarityAnalysisQueue`
- 새 `FaceScanCache`
- 새 `FaceScanService`

로 격리 실행해야 한다.

## 원칙 3. Stage 2는 actual observation 이어야 한다

Stage 2는 live Grid를 새로 재현하는 게 아니라 실제 동작을 기록해야 한다.

즉:

- Stage 1 = 격리 실행
- Stage 2 = 관찰 실행

## 원칙 4. 비교 단위는 그룹 멤버 집합이다

비교 기준:

- `memberAssetIDs.sorted()`

비교 시 무시:

- `groupID`
- 그룹 생성 순서
- UI 표시 순서

---

## Stage 1 구현 계획

## 목적

같은 명시적 입력에 대해 Grid 엔진과 FaceScan이 같은 결과를 내는지 수집한다.

## 입력 계약

Stage 1에서 “같은 입력”은 다음을 의미한다.

1. 같은 `FaceScanMethod`
2. 같은 `PHFetchResult` 생성 로직
3. 같은 정렬
   - `creationDate DESC`
4. 같은 명시적 `ClosedRange<Int>`
5. 같은 삭제대기함 제외 규칙
6. 같은 clamp 결과

## 구현 파일

### 1. `SweepPic/SweepPic/Debug/FaceScanGridEquivalenceTester.swift`

책임:

- method/range 입력
- fetchResult 생성
- range clamp
- Stage 1 Grid oracle 실행
- FaceScan debug range 실행
- 정규화/diff
- JSON/log 저장

핵심 타입:

```swift
enum FaceScanDebugTerminationReason: String, Codable {
    case naturalEnd
    case maxScanCount
    case maxGroupCount
    case cancelled
}

struct GroupSignature: Hashable, Codable {
    let members: [String]
}

struct EngineEquivalenceReport: Codable {
    let timestamp: Date
    let methodDescription: String
    let requestedRange: ClosedRange<Int>
    let clampedRange: ClosedRange<Int>?
    let fetchResultCount: Int
    let gridAnalyzedAssetIDs: [String]
    let faceScanAnalyzedAssetIDs: [String]
    let gridGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
    let faceScanTerminationReason: FaceScanDebugTerminationReason
}
```

### 2. `FaceScanService.swift`

추가:

- `debugBuildFetchResult(method:)`
- `analyzeDebugRange(fetchResult:range:)`

계약:

- 현재 FaceScan 알고리즘 그대로
- 세션 저장 금지
- 실제 analyzed assetID 기록
- 종료 사유 기록

중요:

- 기존 `analyzeChunk(photos:excludeAssets:)` 를 그대로 호출해야 한다
- 즉 Step 2.5, `hasAnyFace`, Step 5.5 모두 그대로 유지한다

### 3. `SimilarityAnalysisQueue.swift`

핵심 요구사항:

- Grid production 알고리즘은 그대로 사용
- 하지만 shared cache / analytics / notification 오염은 막아야 한다

따라서 필요한 것:

- core 로직 추출
- side effect suppression 옵션
- isolated cache 주입

권장 구조:

```swift
private struct SimilarityAnalysisSideEffects {
    let shouldRecordAnalytics: Bool
    let shouldPostNotification: Bool
}

private struct SimilarityAnalysisResult {
    let groupIDs: [String]
    let analyzedAssetIDs: [String]
}

private func runAnalysisCore(
    photos: [PHAsset],
    range: ClosedRange<Int>,
    sideEffects: SimilarityAnalysisSideEffects
) async -> SimilarityAnalysisResult
```

DEBUG helper:

```swift
func debugGroupsForRange(
    _ range: ClosedRange<Int>,
    fetchResult: PHFetchResult<PHAsset>,
    cache: SimilarityCache
) async -> (groupIDs: [String], groups: [[String]], analyzedAssetIDs: [String])
```

중요:

- `formGroupsForRange(...)` 를 side effect 고려 없이 그대로 하네스에서 호출하면 안 된다
- 현재 함수는 analytics와 global notification을 발송한다

## Stage 1 실행 흐름

1. `FaceScanService.debugBuildFetchResult(method:)`
2. range clamp
3. 새 `SimilarityCache`
4. 새 `SimilarityAnalysisQueue(cache:)`
5. `debugGroupsForRange(...)`
6. 새 `FaceScanCache`
7. 새 `FaceScanService(cache:)`
8. `analyzeDebugRange(...)`
9. `GroupSignature` 정규화
10. diff 생성
11. `/tmp/facescan-grid-engine-equivalence-*.json` 저장

## Stage 1 해석 기준

- `gridOnly` / `faceScanOnly` 존재 → 알고리즘 또는 입력 처리 차이
- Stage 1 PASS → 엔진 차이는 없을 가능성이 높음
- 그래도 최종 승인 기준은 아님

---

## Stage 2 구현 계획

## 목적

실제 사용자가 보던 Grid final state와 FaceScan 결과를 비교한다.

이 단계가 최종 oracle 단계다.

## 핵심 전략

Grid를 새로 replay해서 추정하지 않는다.

대신 실제 Grid 세션에서 다음을 기록한다.

1. enqueue
2. cancel
3. completion
4. 최종 shared cache snapshot

즉 Stage 2는 “재현”보다 “관찰”이 우선이다.

## 구현 파일

### 1. `SweepPic/SweepPic/Debug/GridAnalysisSessionRecorder.swift`

책임:

- live Grid 세션의 request lifecycle 기록
- 최종 snapshot 저장

기록 대상:

#### request enqueue

- request id
- source
- assetID
- range
- timestamp

hook 지점:

- `SimilarityAnalysisQueue.enqueue(_:)`

#### request cancel

- request id 또는 source
- timestamp

hook 지점:

- `SimilarityAnalysisQueue.cancel(source:)`

주의:

- 현재 `cancel(source:)` 는 source 단위 취소라 request 단위 맵핑이 필요할 수 있다
- recorder는 enqueue 당시 request 목록을 내부에 보관해야 한다

#### request completion

- completion timestamp
- `analysisRange`
- `groupIDs`
- `analyzedAssetIDs`

hook 지점:

- `Notification.Name.similarPhotoAnalysisComplete`

#### final cache snapshot

- 최종 유효 groupID들
- 각 group의 memberAssetIDs
- capture timestamp

이 snapshot이 Stage 2 oracle이다.

### 2. `SimilarityCache.swift`

현재는 전체 그룹을 debug dump하는 API가 없다.

따라서 DEBUG helper가 필요하다.

예:

```swift
#if DEBUG
func debugAllGroups() -> [SimilarThumbnailGroup]
#endif
```

이 helper는 final snapshot 시점에 `preliminary` 를 제외하고 유효 group만 추출할 수 있어야 한다.

### 3. `SweepPic/SweepPic/Debug/LiveGridFaceScanEquivalenceTester.swift`

책임:

- 저장된 live Grid snapshot 로드
- 같은 조건의 FaceScan 실행
- 최종 diff 생성

핵심 타입:

```swift
struct LiveGridRequestRecord: Codable {
    let requestID: String
    let assetID: String
    let source: String
    let range: ClosedRange<Int>
    let timestamp: Date
}

struct LiveGridCancellationRecord: Codable {
    let requestID: String?
    let source: String
    let timestamp: Date
}

struct LiveGridCompletionRecord: Codable {
    let range: ClosedRange<Int>
    let groupIDs: [String]
    let analyzedAssetIDs: [String]
    let timestamp: Date
}

struct LiveGridFinalSnapshot: Codable {
    let finalGroups: [GroupSignature]
    let capturedAt: Date
}

struct LiveGridSessionRecord: Codable {
    let methodDescription: String?
    let requests: [LiveGridRequestRecord]
    let cancellations: [LiveGridCancellationRecord]
    let completions: [LiveGridCompletionRecord]
    let finalSnapshot: LiveGridFinalSnapshot
}

struct LiveEquivalenceReport: Codable {
    let liveGridFinalGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
}
```

## final snapshot 계약

이 부분이 가장 중요하다.

final snapshot은 반드시:

- 사용자가 “지금 보이는 상태가 비교 기준이다”라고 판단한 시점
- 스크롤이 멈춰 있고
- 관련 completion이 끝났고
- UI가 최종 반영된 뒤

에 수동으로 찍어야 한다.

권장 방식:

- DEBUG 액션으로 “현재 Grid snapshot 저장” 버튼/명령 제공

이유:

- 자동 시점 추정은 틀릴 수 있다
- 최종 oracle은 사용자가 실제로 보던 상태여야 한다

## preliminary 처리 계약

최종 oracle에는 `groupID == "preliminary"` 를 포함하면 안 된다.

규칙:

- `preliminary` 제외
- 최종 유효 그룹만 snapshot

## cancellation 처리 계약

cancellation은 live Grid 동작의 일부다.

규칙:

- cancellation 기록은 반드시 남긴다
- 하지만 최종 비교 기준은 “모든 과정을 거친 뒤 shared cache에 남은 최종 상태”다

즉:

- request/cancel/complete 기록은 원인 추적용
- final snapshot은 비교 기준용

## Stage 2 실행 흐름

1. 사용자가 실제 Grid에서 원하는 상태까지 스크롤/대기
2. DEBUG 액션으로 live session snapshot 저장
3. 같은 조건으로 FaceScan 실행
4. `finalSnapshot.finalGroups` 와 `faceScanGroups` 비교
5. `/tmp/facescan-grid-live-equivalence-*.json` 저장

---

## Stage 1과 Stage 2의 관계

- Stage 1 PASS, Stage 2 FAIL
  - live Grid 실행/누적/취소 문제
- Stage 1 FAIL
  - 알고리즘/입력 처리 차이

즉 구조 수정은:

- Stage 1 결과로 원인을 좁히고
- Stage 2 결과로 최종 합격 여부를 판단

해야 한다.

---

## 이번 단계에서 하지 않을 것

- FaceScan 알고리즘 수정
- Grid 알고리즘 수정
- IncrementalGroupBuilder 구현
- overlap 로직 수정
- `hasAnyFace` 게이트 제거
- shared core 승격

이번 단계는 어디까지나 **검증 선행 단계**다.

---

## 최종 문서 제안

최종 문서는 `d.md`를 상위 방향으로 유지하되, 아래를 `c.md`에서 흡수한 버전이 맞다.

채택할 내용:

- `c.md`의 Stage 1 구체 타입/하네스 구조
- `FaceScanService` debug 진입점 설계
- 입력 동등성 검증
- JSON/log 저장 계획

반드시 버릴 내용:

- `formGroupsForRange(...)` 를 side effect 고려 없이 그대로 Stage 1 oracle로 호출하는 부분
- Stage 1만으로 최종 동등성을 말하려는 뉘앙스

즉 최종 문서는:

- **`d.md`의 oracle 정의와 단계 구조**
- **`c.md`의 Stage 1 구현 디테일**

을 합친 형태여야 한다.

이 문서가 그 초안이다.

# FaceScan-Grid 동등성 검증 및 장기 통합 계획

## 문서 목적

이 문서는 **FaceScan 수정안 자체가 아니라, 수정 전에 반드시 구현해야 하는 검증/데이터 수집 계획이자 장기 통합 방향 문서**다.

최종 목표는 하나다.

- **FaceScan 결과가 사용자가 실제 Grid에서 보던 최종 결과와 정확히 같아야 한다.**

이 문서는 다음보다 우선한다.

- `docs/llm/a.md`
- `docs/llm/b.md`
- `docs/llm/c.md`
- `docs/llm/d.md`
- `docs/llm/e.md`
- `docs/llm/f.md`
- 모든 구조 수정안

핵심은 두 가지다.

1. 지금 당장은 **검증 하네스와 데이터 수집 체계**를 먼저 만든다.
2. 장기적으로는 **FaceScan이 Grid 엔진을 직접 재사용**하도록 간다.

---

## 장기 해법 명시

이 문서가 명시적으로 선언하는 **장기 해법**은 다음이다.

- **FaceScan은 궁극적으로 `SimilarityAnalysisQueue.formGroupsForRange(...)` 경로를 직접 재사용해야 한다.**

정확히는 다음 둘 중 하나다.

1. FaceScan이 격리 인스턴스의 `formGroupsForRange(...)` 를 직접 호출한다.
2. 필요할 경우 그 함수의 **side-effect-free core** 를 추출해 FaceScan이 그 core를 직접 사용한다.

즉 장기 해법은:

- FaceScan이 지금처럼 별도 파이프라인
  - 청크 루프
  - `analyzeChunk(photos:excludeAssets:)`
  - `hasAnyFace`
  - overlap 제거
  를 유지한 채 Grid와 “비슷하게 맞추는 것”

이 아니라,

- **Grid의 실제 그룹 형성/후처리 경로 자체를 재사용하는 것**

이다.

이 방향을 명시하는 이유:

1. Grid 로직 변경이 FaceScan에 자동 반영되어야 한다.
2. 두 경로의 알고리즘 드리프트를 원천 차단해야 한다.
3. “같아지게 보정”보다 “같은 엔진을 사용”하는 편이 훨씬 강한 보장이다.

중요:

- **장기 방향은 Grid 엔진 직접 재사용**
- **실행 순서는 검증 선행**

이다.

---

## 왜 지금 바로 직접 호출로 가지 않는가

방향은 명확하지만, 현재 코드에서 `formGroupsForRange(...)` 를 그대로 FaceScan에 붙이는 것은 아직 이르다.

이유:

1. 현재 함수는 순수 엔진 함수가 아니다.
   - analytics 전송
   - global notification 발송
   - cache state 반영
   - preliminary 상태 처리

2. 함수 안에 FP 생성까지 포함되어 있다.
   - “FP는 배치로 만들고, 그루핑/후처리만 `formGroupsForRange()` 호출” 같은 단순 조합은 현재 구조상 바로 안 된다.

3. live Grid와 FaceScan의 차이가 현재 정확히 어디서 나는지 아직 계측되지 않았다.

따라서 순서는 다음이어야 한다.

1. 검증 하네스 구현
2. Stage 1 / Stage 2 데이터 수집
3. 차이 패턴 확인
4. 그 다음 장기 해법으로 승격

즉:

- **장기 방향은 직접 재사용**
- **실행 순서는 검증 선행**

이다.

---

## 최종 oracle 정의

이번 문서에서 최종 oracle은 다음이다.

- **실제 live Grid 세션에서, 사용자가 보던 시점의 최종 shared-cache 그룹 상태**

즉 비교 기준은:

1. 실제 Grid가 생성한 request들
2. 그 request들의 cancel / complete 순서
3. 그 결과 `SimilarityCache.shared` 에 남은 최종 그룹 멤버들

중요:

- 새 baseline 함수는 oracle이 아니다.
- 명시적 range로 Grid 엔진을 한 번 돌린 결과도 oracle이 아니다.
- FaceScan이 실제 본 사진들로 재계산한 결과도 oracle이 아니다.

최종 비교 대상은 오직:

- **live Grid final group signatures**
- **FaceScan final group signatures**

이다.

---

## 왜 2단계가 필요한가

최종 목표만 보면 live Grid 비교 하나면 될 것 같지만, 그 상태로는 원인 분리가 안 된다.

그래서 두 단계가 필요하다.

### Stage 1: Engine Equivalence

목적:

- 같은 명시적 입력 범위에 대해
- Grid 엔진 결과와 FaceScan 결과가 같은지 확인

역할:

- 알고리즘 차이
- 입력 처리 차이
- 종료 조건 차이

여기서 다르면 live Grid 검증 전에 이미 FaceScan 로직이 다르다는 뜻이다.

### Stage 2: Live Grid Equivalence

목적:

- 사용자가 실제로 보던 Grid final state와 FaceScan 결과를 비교

역할:

- 최종 승인 기준

즉:

- **Stage 1은 원인 분리용**
- **Stage 2는 최종 동등성 검증용**

이다.

최종 합격 기준은 **Stage 2 PASS** 다.

---

## 현재 코드 기준 사실 정리

### Grid production 경로

현재 Grid / Viewer 공용 분석 경로는 다음이다.

- `SimilarityAnalysisQueue.formGroupsForRange(...)`

내부 핵심 단계:

1. `fetchPhotos(in:range, fetchResult:)`
2. `matchingEngine.generateFeaturePrints(for:)`
3. `analyzer.formGroups(...)`
4. `rawGroups` 전체에 대해 `assignPersonIndicesForGroup(...)`
5. `SimilarityCache.addGroupIfValid(...)`
6. analytics / notification 처리

최종 그룹 source of truth:

- `SimilarityCache` 안에 저장된 최종 그룹 멤버들

중요:

- Grid는 `hasFaces` 를 최종 그룹 스킵 조건으로 쓰지 않는다.
- Grid는 request 여러 개의 결과가 `SimilarityCache.shared` 위에 누적된다.
- 그룹 병합은 `SimilarityCache.addGroupIfValid(...)` 내부에서 일어난다.

### FaceScan production 경로

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

### 원칙 1. production 알고리즘은 먼저 바꾸지 않는다

이번 단계에서 하지 않을 것:

- `formGroups()` 재구현
- FaceScan overlap 로직 수정
- FaceScan `hasAnyFace` 게이트 수정
- Grid 알고리즘 수정

허용되는 변경:

- debug helper 추가
- side effect 분리용 최소 구조 정리
- recorder 추가
- snapshot / diff 저장 코드

### 원칙 2. Stage 1은 isolated execution 이어야 한다

Stage 1은 live UI를 오염시키면 안 된다.

따라서 금지:

- `SimilarityCache.shared.clear()`
- shared queue / shared cache 재사용
- analytics 전송
- global notification 발송

Stage 1은:

- 새 `SimilarityCache`
- 새 `SimilarityAnalysisQueue`
- 새 `FaceScanCache`
- 새 `FaceScanService`

로 격리 실행해야 한다.

### 원칙 3. Stage 2는 actual observation 이어야 한다

Stage 2는 live Grid를 새로 재현하는 게 아니라 실제 동작을 기록해야 한다.

즉:

- Stage 1 = 격리 실행
- Stage 2 = 관찰 실행

### 원칙 4. 비교 단위는 그룹 멤버 집합이다

비교 기준:

- `memberAssetIDs.sorted()`

비교 시 무시:

- `groupID`
- 그룹 생성 순서
- UI 표시 순서

### 원칙 5. 이 문서는 검증 문서이면서 장기 승격 문서여야 한다

단순히 “diff를 찍어본다”로 끝나면 부족하다.

문서에는 반드시 다음이 함께 있어야 한다.

1. 왜 지금은 수집이 먼저인지
2. 그 수집이 통과하면 무엇을 production 경로로 승격할지
3. 장기 해법이 무엇인지

이번 문서에서 그 장기 해법은:

- **FaceScan의 Grid 엔진 직접 재사용**

이다.

---

## Stage 1 구현 계획

### 목적

같은 명시적 입력에 대해 Grid 엔진과 FaceScan이 같은 결과를 내는지 수집한다.

### 입력 계약

Stage 1에서 “같은 입력”은 다음을 의미한다.

1. 같은 `FaceScanMethod`
2. 같은 `PHFetchResult` 생성 로직
3. 같은 정렬
   - `creationDate DESC`
4. 같은 명시적 `ClosedRange<Int>`
5. 같은 삭제대기함 제외 규칙
6. 같은 clamp 결과

### 구현 파일

#### 1. `SweepPic/SweepPic/Debug/FaceScanGridEquivalenceTester.swift`

책임:

- method / range 입력
- fetchResult 생성
- range clamp
- Stage 1 Grid oracle 실행
- FaceScan debug range 실행
- 정규화 / diff
- 로그 / JSON 저장

`e.md` 에서 흡수할 운영 디테일:

- report 구조체를 구체적으로 정의
- PASS / PARTIAL / FAIL 개념을 운영적으로 구분
- JSON 이력 저장과 latest 파일 저장

핵심 타입:

```swift
enum FaceScanDebugTerminationReason: String, Codable {
    case naturalEnd
    case maxScanCount
    case maxGroupCount
    case cancelled
}

enum EngineEquivalenceStatus: String, Codable {
    case pass
    case partial
    case fail
}

struct GroupSignature: Hashable, Codable {
    let members: [String]
}

struct EngineEquivalenceReport: Codable {
    let timestamp: Date
    let methodDescription: String
    let requestedRange: ClosedRange<Int>?
    let clampedRange: ClosedRange<Int>?
    let fetchResultCount: Int
    let gridInputAssetCount: Int
    let faceScanInputAssetCount: Int
    let gridAnalyzedAssetIDs: [String]
    let faceScanAnalyzedAssetIDs: [String]
    let gridGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
    let faceScanTerminationReason: FaceScanDebugTerminationReason
    let status: EngineEquivalenceStatus
}
```

상태 판정 규칙:

- `gridOnly.isEmpty && faceScanOnly.isEmpty` → `pass`
- `faceScanTerminationReason == .maxGroupCount && faceScanOnly.isEmpty` → `partial`
- 그 외 → `fail`

#### 2. `FaceScanService.swift`

추가:

- `debugBuildFetchResult(method:)`
- `analyzeDebugRange(fetchResult:range:)`

계약:

- 현재 FaceScan 알고리즘 그대로
- 세션 저장 금지
- UserDefaults 갱신 금지
- 실제 analyzed assetID 기록
- 종료 사유 기록

중요:

- 기존 `analyzeChunk(photos:excludeAssets:)` 를 그대로 호출해야 한다.
- 즉 Step 2.5, `hasAnyFace`, Step 5.5, `maxScanCount`, `maxGroupCount` 를 그대로 유지한다.

예시 타입:

```swift
struct FaceScanDebugResult {
    let groups: [FaceScanGroup]
    let analyzedAssetIDs: [String]
    let terminationReason: FaceScanDebugTerminationReason
}
```

#### 3. `SimilarityAnalysisQueue.swift`

핵심 요구사항:

- Grid production 알고리즘은 그대로 사용
- 하지만 shared cache / analytics / notification 오염은 막아야 한다

따라서 필요한 것:

- isolated cache 주입
- side effect suppression
- debug 결과 반환 helper

여기서 중요한 판단:

- `e.md` 처럼 `formGroupsForRange(...)` 를 Stage 1 하네스에서 그대로 호출하는 안은 불충분하다.
- 새 인스턴스로 cache 오염은 막을 수 있어도 analytics / global notification 은 여전히 남는다.

따라서 Stage 1에는 최소한 아래 둘 중 하나가 필요하다.

1. `formGroupsForRange(...)` 내부에 side effect suppression 옵션 추가
2. side effect 없는 내부 helper로 core를 감싸는 DEBUG helper 추가

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

#### 4. 저장 포맷

`e.md` 에서 가져올 운영 규칙:

- `/tmp/facescan-grid-engine-equivalence-{timestamp}.json`
- `/tmp/facescan-grid-engine-equivalence-latest.json`

로그 예시:

```text
[Engine Equivalence] PASS
  method: all
  requestedRange: 0...199
  clampedRange: 0...199
  input: Grid 187 / FaceScan 187
  groups: Grid 6 / FaceScan 6
  common: 6 / gridOnly: 0 / faceScanOnly: 0
```

### Stage 1 실행 흐름

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
11. 로그 출력
12. `/tmp/facescan-grid-engine-equivalence-{timestamp}.json` 저장
13. `/tmp/facescan-grid-engine-equivalence-latest.json` 갱신

### Stage 1 해석 기준

- `pass`
  - 같은 명시적 입력에서 엔진 결과가 일치
  - 그래도 최종 승인 기준은 아님
- `partial`
  - `maxGroupCount` 같은 종료 조건 영향 가능
  - 추가 수집 필요
- `fail`
  - 알고리즘 또는 입력 처리 차이
  - Stage 2 전에 원인 분석 필요

---

## Stage 2 구현 계획

### 목적

실제 사용자가 보던 Grid final state와 FaceScan 결과를 비교한다.

이 단계가 최종 oracle 단계다.

### 핵심 전략

Grid를 새로 replay 해서 추정하지 않는다.

대신 실제 Grid 세션에서 다음을 기록한다.

1. enqueue
2. cancel
3. completion
4. 최종 shared cache snapshot

즉 Stage 2는 “재현”보다 “관찰”이 우선이다.

### 구현 파일

#### 1. `SweepPic/SweepPic/Debug/GridAnalysisSessionRecorder.swift`

책임:

- live Grid 세션의 request lifecycle 기록
- 최종 snapshot 저장

기록 대상:

##### request enqueue

- request id
- source
- range
- timestamp

hook 지점:

- `SimilarityAnalysisQueue.enqueue(_:)`

##### request cancel

- request id 또는 source
- timestamp

hook 지점:

- `SimilarityAnalysisQueue.cancel(source:)`

주의:

- 현재 `cancel(source:)` 는 source 단위 취소다.
- recorder는 enqueue 당시 active request 목록을 내부에 보관해야 한다.

##### request completion

- completion timestamp
- `analysisRange`
- `groupIDs`
- `analyzedAssetIDs`

hook 지점:

- `Notification.Name.similarPhotoAnalysisComplete`

##### final cache snapshot

- 최종 유효 groupID들
- 각 group의 `memberAssetIDs`
- capture timestamp
- fetch universe 메타데이터

#### 2. `SimilarityCache.swift`

현재는 전체 그룹을 dump 하는 debug API가 없다.

따라서 DEBUG helper가 필요하다.

예:

```swift
#if DEBUG
func debugAllGroups() -> [SimilarThumbnailGroup]
#endif
```

추가 규칙:

- `preliminary` 제외
- 최종 유효 그룹만 반환

#### 3. `SweepPic/SweepPic/Debug/LiveGridFaceScanEquivalenceTester.swift`

책임:

- 저장된 live Grid snapshot 로드
- 같은 조건의 FaceScan 실행
- 최종 diff 생성

핵심 타입:

```swift
struct LiveGridRequestRecord: Codable {
    let requestID: String
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
    let fetchUniverseDescription: String
    let capturedAt: Date
}

struct LiveGridSessionRecord: Codable {
    let methodDescription: String?
    let requests: [LiveGridRequestRecord]
    let cancellations: [LiveGridCancellationRecord]
    let completions: [LiveGridCompletionRecord]
    let finalSnapshot: LiveGridFinalSnapshot
}

enum LiveEquivalenceStatus: String, Codable {
    case pass
    case fail
}

struct LiveEquivalenceReport: Codable {
    let timestamp: Date
    let liveGridFinalGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
    let status: LiveEquivalenceStatus
}
```

`e.md` 에서 흡수할 운영 디테일:

- live report도 JSON 이력 저장과 latest 파일 갱신을 같이 한다
- request / completion / cancellation 을 session 단위로 묶어 저장한다

저장 경로:

- `/tmp/facescan-grid-live-equivalence-{timestamp}.json`
- `/tmp/facescan-grid-live-equivalence-latest.json`

### final snapshot 계약

final snapshot 은 반드시:

1. 사용자가 “지금 보이는 상태가 비교 기준이다”라고 판단한 시점
2. 스크롤이 멈춰 있고
3. 관련 completion 이 끝났고
4. UI가 최종 반영된 뒤

에 수동으로 찍어야 한다.

권장 방식:

- DEBUG 액션으로 “현재 Grid snapshot 저장” 버튼 / 명령 제공

이유:

- 자동 시점 추정은 틀릴 수 있다.
- 최종 oracle 은 사용자가 실제로 보던 상태여야 한다.

### preliminary 처리 계약

최종 oracle 에는 `preliminary` 를 포함하면 안 된다.

규칙:

- `preliminary` 제외
- 최종 유효 그룹만 snapshot

### cancellation 처리 계약

cancellation 은 live Grid 동작의 일부다.

규칙:

- cancellation 기록은 반드시 남긴다
- 하지만 최종 비교 기준은 “모든 과정을 거친 뒤 shared cache 에 남은 최종 상태”다

즉:

- request / cancel / complete 기록은 원인 추적용
- final snapshot 은 비교 기준용

### Stage 2 판정 규칙

`e.md` 의 운영 관점을 흡수하되, 최종 목표에 맞게 판정은 아래로 고정한다.

- `gridOnly.isEmpty` 이고 `faceScanOnly.isEmpty` → `pass`
- `gridOnly.isEmpty` 이고 `faceScanOnly` 만 존재 → `fail` 로 보지 않는다
  - live Grid가 아직 보지 못한 영역의 그룹일 수 있기 때문
- `gridOnly` 존재 → `fail`
  - Grid가 실제로 보여준 그룹을 FaceScan이 놓친 것

즉 Stage 2의 핵심 실패 조건은:

- **Grid가 보여준 그룹을 FaceScan이 놓쳤는가**

이다.

### Stage 2 실행 흐름

1. 사용자가 실제 Grid에서 원하는 상태까지 스크롤 / 대기
2. DEBUG 액션으로 live session snapshot 저장
3. 같은 fetch universe / 같은 조건으로 FaceScan 실행
4. `finalSnapshot.finalGroups` 와 `faceScanGroups` 비교
5. 로그 출력
6. `/tmp/facescan-grid-live-equivalence-{timestamp}.json` 저장
7. `/tmp/facescan-grid-live-equivalence-latest.json` 갱신

---

## Stage 1과 Stage 2의 관계

- Stage 1 PASS, Stage 2 FAIL
  - live Grid 실행 / 누적 / 취소 / 관찰 시점 문제
- Stage 1 FAIL
  - 알고리즘 / 입력 처리 / 종료 조건 차이

즉 구조 수정은:

1. Stage 1 결과로 원인을 좁히고
2. Stage 2 결과로 최종 합격 여부를 판단

해야 한다.

---

## 장기 승격 계획

이 문서가 명시하는 장기 승격 방향은 다음이다.

1. Stage 1 / Stage 2 하네스 구현
2. 현재 차이 수집
3. 차이 패턴 분류
4. FaceScan을 Grid 엔진 직접 재사용 구조로 승격
5. 다시 Stage 1 / Stage 2 로 PASS 검증

여기서 4번은 구체적으로 다음 중 하나다.

1. FaceScan이 격리 인스턴스의 `formGroupsForRange(...)` 를 직접 사용하는 구조
2. 필요 시 `formGroupsForRange(...)` 의 side-effect-free core 를 추출해 FaceScan이 직접 사용하는 구조

즉 장기적으로는:

- 별도 FaceScan 파이프라인 유지 + 보정

이 아니라

- **Grid 엔진 직접 재사용**

이 정답이다.

---

## 이번 단계에서 하지 않을 것

- FaceScan 알고리즘 수정
- Grid 알고리즘 수정
- overlap 로직 수정
- `hasAnyFace` 게이트 제거
- 청크 전략 수정
- direct reuse 승격 자체

이번 단계는 어디까지나 **검증 선행 단계**다.

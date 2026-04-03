# FaceScan-Grid 동등성 데이터 수집 선행 계획 v3

## 문서 목적

이 문서는 **수정안 문서가 아니라, 수정 전에 반드시 구현해야 하는 데이터 수집/검증 문서**다.

최종 목표는 하나다.

- **FaceScan 결과가 사용자가 실제 Grid에서 보던 최종 결과와 정확히 같아야 한다.**

이 문서의 핵심은 그 목표를 애매하게 “비슷한 baseline”으로 검증하지 않고,
**실제 live Grid final state를 oracle로 삼는 수집 체계**를 먼저 만드는 것이다.

즉, 이 문서는 다음보다 우선한다.

- `docs/llm/a.md`
- `docs/llm/b.md`
- 모든 구조 수정안
- 모든 overlap 보정안
- 모든 shared-core 추출안

---

## 최종 oracle 정의

이번 문서에서 oracle은 이것이다.

- **실제 live Grid 세션에서, 사용자가 본 시점의 최종 shared-cache 그룹 상태**

더 정확히 말하면:

- 실제 Grid가 생성한 분석 요청들
- 그 요청들의 취소/완료 순서
- 그 결과로 `SimilarityCache.shared` 에 남은 최종 그룹들

이 최종 cache snapshot이 oracle이다.

중요:

- “Grid 알고리즘과 비슷한 새 baseline 함수”는 oracle이 아니다.
- “Grid 엔진을 같은 range로 한 번 돌린 결과”도 oracle이 아니다.
- “FaceScan이 실제로 본 사진들로 재계산한 baseline”도 oracle이 아니다.

최종 비교 대상은 오직:

- **실제 live Grid final state**

이다.

---

## 왜 이전 문서들로는 부족했는가

## `a.md`의 문제

- baseline을 새로 구현하려 했다
- 기준값이 Grid production 경로와 분리돼 있다
- live Grid 결과와는 더 멀다

즉 `a.md`는 oracle 정의부터 틀렸다.

## `b.md`의 문제

- Grid production 경로를 oracle로 쓰려는 방향은 맞다
- 하지만 “명시적 range로 Grid 엔진 1회 실행” 수준이라
  **실제 네가 보던 live Grid 결과**까지는 못 간다

즉 `b.md`는 좋은 engine-level 수집 계획이지만,
최종 목표인 live Grid equivalence를 직접 보장하진 못 한다.

## v2 `d.md`의 문제

- 2단계 구조 자체는 맞았다
- 하지만 `Stage 2A`를 너무 열어둬서, “대충 live에 가까운 비교”로 타협할 여지가 남아 있었다

이번 v3에서는 그걸 막는다.

- `Stage 2A`는 선택적 보조 수집
- **`Stage 2B`만 최종 oracle 경로**

로 고정한다.

---

## 두 단계가 필요한 이유

최종 목표는 Stage 2B 하나로 충분해 보일 수 있다.
하지만 실제 구현과 해석을 위해서는 Stage 1이 필요하다.

## Stage 1

목적:

- 같은 명시적 입력 범위에서
- Grid 엔진 결과와 FaceScan 결과가 같은지 확인

이 단계의 역할:

- 알고리즘/입력 처리 차이 분리

여기서 다르면:

- live Grid replay까지 갈 필요 없이
- FaceScan 알고리즘 또는 range 처리부터 다르다는 뜻이다

## Stage 2B

목적:

- 사용자가 실제로 본 live Grid final state와 FaceScan 결과 비교

이 단계의 역할:

- 최종 동등성 검증

즉:

- **Stage 1은 원인 분리용**
- **Stage 2B는 최종 목표 검증용**

이다.

중요:

- 최종 승인 기준은 Stage 2B다
- Stage 1 통과만으로는 부족하다

---

## 현재 코드 기준 사실 정리

## Grid production 경로

현재 Grid/Viewer 공용 분석 경로는:

- `SimilarityAnalysisQueue.formGroupsForRange(...)`

내부 핵심 단계:

1. `fetchPhotos(in:range, fetchResult:)`
2. `matchingEngine.generateFeaturePrints(for:)`
3. `analyzer.formGroups(...)`
4. `rawGroups` 전체에 대해 `assignPersonIndicesForGroup(...)`
5. `SimilarityCache.addGroupIfValid(...)`
6. notification 발송

최종 그룹 source of truth:

- `SimilarityCache.groups[groupID].memberAssetIDs`

중요:

- Grid는 `hasFaces`를 최종 그룹 스킵 조건으로 쓰지 않는다
- Grid는 request 여러 개가 shared cache 위에 누적된다
- live UI는 notification과 cache state를 보고 갱신된다

## FaceScan production 경로

현재 FaceScan은:

- `FaceScanService.analyze(...)`
- 청크 루프
- `analyzeChunk(photos:excludeAssets:)`

핵심 차이:

- 20장 청크 + overlap 3장
- Step 2.5 사전 필터
- `hasAnyFace` 게이트
- Step 5.5 overlap 제거
- `FaceScanCache` 사용

즉 현재는 구조적으로 Grid와 달라질 수 있다.

---

## 최종 비교 대상 정의

최종 비교 대상은 아래 둘이다.

1. **Live Grid final group signatures**
2. **FaceScan final group signatures**

비교 단위:

- `memberAssetIDs.sorted()`

비교 시 무시:

- `groupID`
- 생성 순서
- 셀 표시 순서

중요:

- 최종 그룹 시그니처 비교만으로 충분한가?
  - **최종 동등성 검증 자체는 yes**
  - 다만 원인 추적을 위해 request sequence와 cancellation 기록도 같이 필요하다

즉 필수 저장 데이터는:

- 최종 그룹 시그니처
- live request/complete/cancel sequence

둘 다다.

---

## Stage 1: Engine Equivalence

## 목적

같은 명시적 입력 범위에 대해

- Grid 엔진 결과
- FaceScan 결과

가 같은지 본다.

이 단계는 최종 승인 기준이 아니라 **원인 분리 단계**다.

## 동일 입력 계약

1. 같은 `FaceScanMethod`
2. 같은 `PHFetchResult` 생성 로직
3. 같은 정렬
   - `creationDate DESC`
4. 같은 명시적 `ClosedRange<Int>`
5. 같은 삭제대기함 제외 규칙
6. 같은 clamp 결과

## 구현 원칙

- production 알고리즘은 바꾸지 않는다
- baseline 재구현 금지
- isolated execution 사용
- shared cache 오염 금지

## Stage 1 구현물

### 1. `SweepPic/SweepPic/Debug/FaceScanGridEquivalenceTester.swift`

책임:

- method/range 입력
- fetchResult 생성
- range clamp
- Grid engine oracle 실행
- FaceScan debug range 실행
- diff/report 저장

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
    let methodDescription: String
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
}
```

### 2. `FaceScanService` debug helper

추가:

- `debugBuildFetchResult(method:)`
- `analyzeDebugRange(fetchResult:range:)`

계약:

- 현재 FaceScan 알고리즘 그대로
- 세션 저장 금지
- 실제 처리 assetID 기록
- 종료 사유 기록

### 3. `SimilarityAnalysisQueue` isolated engine helper

Stage 1 oracle도 shared cache를 건드리면 안 된다.

따라서:

- core 로직 추출
- isolated cache 주입
- analytics suppression
- notification suppression

이 필요하다.

중요:

- 이건 Grid 알고리즘을 바꾸는 게 아니라
- **같은 알고리즘을 오염 없이 호출하는 경로**를 만드는 것이다

## Stage 1 해석 기준

결과 해석:

- `gridOnly` / `faceScanOnly` 존재 → 알고리즘 또는 입력 처리 차이
- 여기서 이미 다르면 Stage 2B 전에 원인을 좁힐 수 있음

하지만 Stage 1이 PASS여도 끝이 아니다.

---

## Stage 2B: Live Grid Equivalence

## 이 단계가 필수다

이번 문서에서 최종 oracle은 **Stage 2B** 다.

Stage 2A 같은 “근사 live 비교”는 선택적 보조일 뿐, 승인 기준이 아니다.

즉:

- **실제 네가 보던 Grid 결과와 같다고 말하려면 Stage 2B가 반드시 구현되어야 한다**

## 목표

실제 live Grid 세션의 final cache state를 기록하고,
그 state와 FaceScan 결과를 비교한다.

## 핵심 아이디어

Grid를 새로 재현하지 않는다.

대신 실제 Grid 세션에서:

1. 어떤 request가 enqueue되었는지
2. 어떤 request가 cancel되었는지
3. 어떤 request가 complete되었는지
4. 최종적으로 `SimilarityCache.shared` 에 어떤 그룹들이 남았는지

를 기록한다.

즉 oracle은 **관찰된 실제 세션 결과**다.

## 필수 구현 요소

### 1. Live Grid Recorder

새 DEBUG recorder 추가.

추천 파일:

- `SweepPic/SweepPic/Debug/GridAnalysisSessionRecorder.swift`

이 recorder는 다음을 기록해야 한다.

#### a. request enqueue

기록 항목:

- request id
- source
- assetID
- range
- timestamp

#### b. request cancel

기록 항목:

- request id
- timestamp

#### c. request completion

기록 항목:

- completion timestamp
- `analysisRange`
- `groupIDs`
- `analyzedAssetIDs`

#### d. final cache snapshot

세션 종료 시점 또는 수동 dump 시점에:

- `SimilarityCache.shared` 의 최종 그룹들
- 각 그룹의 `memberAssetIDs`

를 snapshot 한다.

### 2. final snapshot 시점 계약

이 부분이 이번 버전에서 가장 중요하다.

final snapshot은 반드시 아래 조건을 만족하는 시점에서 찍어야 한다.

- 사용자가 비교 대상으로 삼는 화면 상태가 **안정화된 직후**
- 즉:
  - 스크롤이 멈춰 있고
  - 관련 analysis completion이 끝났고
  - UI가 최종 badge/group 상태를 반영한 뒤

추천 방식:

- 수동 DEBUG 액션으로 “현재 Grid 세션 snapshot 저장” 버튼/명령을 만든다
- 사용자가 “지금 보이는 상태”에서 직접 snapshot을 찍게 한다

이유:

- 자동 시점 추정은 틀릴 수 있다
- 최종 oracle은 “사용자가 보던 상태”여야 하므로, 관찰 시점을 사용자가 고정하는 편이 더 정확하다

### 3. preliminary 상태 처리 계약

live Grid는 intermediate 상태로 `groupID == "preliminary"` 가 있을 수 있다.

최종 oracle에는 이 상태를 포함하면 안 된다.

final snapshot 규칙:

- `preliminary` 그룹 제외
- 최종 유효 groupID만 포함

즉, snapshot은 **최종 확정 그룹만** 담아야 한다.

### 4. cancellation 처리 계약

취소된 request가 이전에 cache에 남긴 흔적이 있을 수 있다.

이번 문서의 원칙:

- cancellation 자체를 oracle에서 제거하지 않는다
- cancellation은 **live Grid 동작의 일부**로 기록한다
- 최종 oracle은 “그 모든 과정을 거친 뒤 shared cache에 남은 최종 상태”다

즉:

- request sequence는 원인 추적용
- 최종 cache snapshot은 비교 기준용

### 5. Live Grid Snapshot 구조체

```swift
struct LiveGridRequestRecord: Codable {
    let requestID: String
    let assetID: String
    let source: String
    let range: ClosedRange<Int>
    let timestamp: Date
}

struct LiveGridCancellationRecord: Codable {
    let requestID: String
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
    let requests: [LiveGridRequestRecord]
    let cancellations: [LiveGridCancellationRecord]
    let completions: [LiveGridCompletionRecord]
    let finalSnapshot: LiveGridFinalSnapshot
}
```

### 6. FaceScan 비교 report

```swift
struct LiveEquivalenceReport: Codable {
    let liveGridFinalGroups: [GroupSignature]
    let faceScanGroups: [GroupSignature]
    let gridOnly: [GroupSignature]
    let faceScanOnly: [GroupSignature]
    let common: [GroupSignature]
}
```

## Stage 2B 실행 방식

1. 사용자가 실제 Grid에서 원하는 상태까지 스크롤/대기
2. DEBUG 액션으로 live session snapshot 저장
3. 같은 method/range 조건으로 FaceScan 데이터 수집 실행
4. live snapshot의 finalGroups 와 FaceScan groups 비교

여기서 중요한 건:

- Grid 쪽은 **실제 관찰 결과**
- FaceScan 쪽은 **동일 범위를 위한 수집 실행**

이라는 점이다.

---

## Stage 2A의 위치

이번 버전에서 Stage 2A는 필수가 아니다.

있다면 용도는 하나다.

- live session replay를 만들기 전, 보조적으로 범위 기반 근사 비교를 해보는 것

하지만 이 결과로는

- “실제 Grid와 같다”

고 말할 수 없다.

따라서:

- Stage 2A는 선택적 참고 수단
- **승인 기준에서 제외**

로 명시한다.

---

## side effect 전략

## Stage 1

- isolated cache
- isolated queue/helper
- analytics suppression
- notification suppression
- session save 금지

## Stage 2B

- live Grid는 실제 production 동작을 그대로 관찰
- recorder는 관찰만 하고 변경하지 않음
- snapshot 캡처만 추가

즉:

- Stage 1은 격리 실행
- Stage 2B는 관찰 실행

---

## 반드시 수집할 메타데이터

### Stage 1

1. requested range
2. clamped range
3. Grid analyzedAssetIDs
4. FaceScan analyzedAssetIDs
5. Grid groups
6. FaceScan groups
7. gridOnly
8. faceScanOnly
9. common
10. FaceScan terminationReason

### Stage 2B

1. request sequence
2. cancellation sequence
3. completion sequence
4. final live snapshot groups
5. FaceScan groups
6. gridOnly
7. faceScanOnly
8. common
9. snapshot capture timestamp

---

## 승인 기준

이번 문서가 충족해야 하는 기준은 아래다.

1. 최종 oracle이 live Grid final state로 명시되어 있는가
2. Stage 1과 Stage 2B의 역할이 분리되어 있는가
3. Stage 2A가 필수가 아니라는 점이 명시되어 있는가
4. baseline 재구현을 금지하는가
5. Stage 1은 isolated execution인가
6. Stage 2B는 actual observation인가
7. final snapshot 시점 계약이 명확한가
8. preliminary 제외 규칙이 있는가

이 8개를 만족해야, 이 문서는 “실제 사용자가 보던 Grid 결과와의 동등성”을 목표로 하는 선행 문서가 된다.

---

## 구현 우선순위

1. Stage 1 구현
2. Stage 1 diff 수집
3. Live Grid Recorder 구현
4. 수동 final snapshot capture 구현
5. Stage 2B live snapshot 수집
6. Stage 2B 기준 diff 수집
7. 그 다음에만 구조 수정 문서 작성

중요:

- 구조 수정의 합격 기준은 Stage 2B PASS다
- Stage 1 PASS만으로는 출시 기준을 만족하지 않는다

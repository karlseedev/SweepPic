# E2E 그룹 동등성 검증 하네스 구현 계획

## 배경

FaceScan(경로 B)이 그리드(경로 A)와 동일한 그룹을 찾는지 검증하는 도구.
구조 수정(IncrementalGroupBuilder) 착수 전에 이 하네스를 먼저 만든다.

**핵심 원칙:**
- 비교 지점: 최종 출력 (validSlot 필터링 후 memberAssetIDs)
- 그룹 매칭: 멤버 집합 **완전 일치** (겹침 판정 불필요)
- 사진 목록: 한 번만 생성하여 양쪽에 동일하게 전달
- 기준값 함수: 캐시에 쓰지 않음 (읽기 전용)

---

## 기준값의 정의

그리드의 스크롤 결과는 범위에 따라 달라지므로 기준이 될 수 없다.
대신 **그리드 로직(formGroups → 얼굴 감지 → slot 필터링)을 FaceScan과 같은 사진 범위에 한 번에 실행**한 결과를 기준값으로 사용한다.

이것은 "그리드가 전체를 볼 수 있었다면 찾았을 그룹"이며, 스크롤 의존성이 없고 결정적(deterministic)이다.

---

## 구현 범위

### 새 파일 1개

| 파일 | 위치 |
|------|------|
| `FaceScanEquivalenceHarness.swift` | `SweepPic/SweepPic/Features/FaceScan/Debug/` |

### 수정 파일 1개

| 파일 | 변경 |
|------|------|
| `FaceScanService.swift` | analyze() 내부에 하네스 호출 코드 추가 (#if DEBUG) |

---

## 새 파일: FaceScanEquivalenceHarness.swift

전체가 `#if DEBUG` 블록. 릴리즈 빌드에 포함되지 않음.

### 구조

```
FaceScanEquivalenceHarness
├── Report (결과 구조체)
├── generateBaseline(photos:) → [Set<String>]    // 기준값 생성
├── compare(baseline:faceScan:) → Report          // 자동 diff
└── logReport(_:)                                 // 로그 출력
```

### Report 구조체

```swift
struct Report {
    let baselineGroups: [Set<String>]     // 기준값 그룹들
    let faceScanGroups: [Set<String>]     // FaceScan 그룹들
    let matched: [Set<String>]            // 양쪽 일치
    let baselineOnly: [Set<String>]       // 기준값에만 존재 (FaceScan이 놓침)
    let faceScanOnly: [Set<String>]       // FaceScan에만 존재 (기준값에 없음)
    var passed: Bool { baselineOnly.isEmpty && faceScanOnly.isEmpty }
}
```

### generateBaseline(photos:) — 기준값 생성

FaceScan이 실제로 스캔한 사진 목록을 받아서, 그리드 로직으로 한 번에 처리한다.

```
입력: [PHAsset] (FaceScan이 스캔한 순서 그대로, 중복 없음)
  ↓
Step 1: FP 생성 (배치 단위로 생성, 결과는 하나의 배열로 합침)
  - 배치 크기: 50장 (메모리 보호)
  - matchingEngine.generateFeaturePrints(for: batch)
  - 모든 배치의 FP를 allFPs 배열에 순서대로 append
  ↓
Step 2: formGroups 호출 (전체 FP 배열을 한 번에)
  - matchingEngine.analyzer.formGroups(featurePrints: allFPs, photoIDs: allIDs)
  - 청크 분할 없음 → 경계 문제 원천 제거
  - 결과: rawGroups: [[String]]
  ↓
Step 3: 각 그룹별 얼굴 감지 + slot 필터링 (그리드 파이프라인과 동일)
  - matchingEngine.assignPersonIndicesForGroup(assetIDs:, photos:)
  - slotPhotoCount 계산 → validSlots (2장 이상 등장한 personIndex)
  - validSlots에 속하는 얼굴이 있는 사진만 validMembers
  - validMembers >= 3장인 그룹만 최종 결과에 포함
  ↓
출력: [Set<String>] (각 그룹의 memberAssetIDs를 Set으로 변환)
```

**주의: 캐시에 쓰지 않는다.** SimilarityCache, FaceScanCache 모두 건드리지 않음.
별도의 PersonMatchingEngine 인스턴스를 생성하여 기존 상태와 격리.

### compare(baseline:faceScan:) — 자동 diff

```
for each group in baseline:
    faceScan에 완전 일치하는 Set이 있는가?
    → 있으면: matched
    → 없으면: baselineOnly

faceScan에서 매칭되지 않은 나머지 → faceScanOnly
```

매칭 판정: `Set<String> == Set<String>` (완전 일치만 통과)

### logReport(_:) — 로그 출력

```
[Equivalence] PASS (또는 FAIL)
  기준값: N개 그룹
  FaceScan: M개 그룹
  일치: K개
  기준값에만: X개
  FaceScan에만: Y개

FAIL인 경우 추가 출력:
  [기준값에만] {assetID1, assetID2, ...} (N장)
  [FaceScan에만] {assetID3, assetID4, ...} (M장)
```

Logger.similarPhoto 카테고리 사용. PASS는 .debug, FAIL은 .error 레벨.

---

## 수정: FaceScanService.swift — analyze()

### 변경 1: 스캔한 사진 목록 캡처

analyze() 내부에서 실제로 처리한 사진을 순서대로 캡처한다.
청크 overlap으로 같은 사진이 중복 포함될 수 있으므로 중복 제거한다.

```swift
// analyze() 상단, 루프 시작 전
#if DEBUG
var scannedPhotoIDs: [String] = []           // 순서 유지
var scannedPhotoSet: Set<String> = []        // 중복 체크
var scannedPhotos: [String: PHAsset] = [:]   // ID → PHAsset
#endif

// 각 청크에서 photos 배열 구성 후 (trashedIDs 제외 완료된 시점)
#if DEBUG
for photo in photos {
    let id = photo.localIdentifier
    if !scannedPhotoSet.contains(id) {
        scannedPhotoSet.insert(id)
        scannedPhotoIDs.append(id)
        scannedPhotos[id] = photo
    }
}
#endif
```

이렇게 하면 FaceScan이 실제로 본 사진 목록이 정확히 캡처된다.
(trashedIDs 제외됨, overlap 중복 제거됨, 순서 유지됨)

### 변경 2: 분석 완료 후 하네스 실행

```swift
// analyze() 종료 직전, 세션 저장 후
#if DEBUG
Task.detached(priority: .utility) {
    let orderedPhotos = scannedPhotoIDs.compactMap { scannedPhotos[$0] }
    let faceScanGroupSets = allFoundGroups.map { Set($0.memberAssetIDs) }

    let harness = FaceScanEquivalenceHarness()
    let baseline = await harness.generateBaseline(photos: orderedPhotos)
    let report = harness.compare(baseline: baseline, faceScan: faceScanGroupSets)
    harness.logReport(report)
}
#endif
```

**Task.detached를 쓰는 이유:**
- 기준값 생성은 FP 생성 + 얼굴 감지를 다시 수행하므로 무겁다
- FaceScan UI 완료 후 백그라운드에서 실행
- 사용자 경험에 영향 없음

### 변경 3: FaceScan 결과 수집

현재 analyze()에서 onGroupFound 콜백으로 그룹을 하나씩 전달한다.
하네스 비교를 위해 모든 그룹을 내부 배열에도 누적한다.

```swift
// analyze() 상단
#if DEBUG
var allFoundGroups: [FaceScanGroup] = []
#endif

// 그룹 발견 시 (onGroupFound 호출 직전)
#if DEBUG
allFoundGroups.append(group)
#endif
```

---

## 실행 흐름 전체

```
사용자가 FaceScan 버튼 탭
  ↓
FaceScanService.analyze() 시작
  ↓
청크 루프 실행 (기존 로직 그대로)
  ├─ 각 청크: photos 캡처 (#if DEBUG)
  ├─ 그룹 발견: allFoundGroups에 누적 (#if DEBUG)
  └─ 종료 조건 도달 (1000장 or 30그룹)
  ↓
세션 저장
  ↓
#if DEBUG: Task.detached로 하네스 실행
  ├─ 캡처된 사진 목록으로 기준값 생성
  │   └─ 전체 FP → formGroups → 얼굴 감지 → slot 필터
  ├─ FaceScan 결과와 비교
  └─ 로그 출력 (PASS/FAIL)
  ↓
사용자 화면: FaceScan 결과 정상 표시 (하네스는 백그라운드)
```

---

## maxGroupCount / maxScanCount 처리

FaceScan은 30그룹 또는 1000장에서 조기 종료한다.
기준값은 같은 사진 목록(=FaceScan이 실제로 스캔한 사진)에서 생성하므로,
스캔 범위는 동일하다.

단, 기준값이 30개 초과 그룹을 찾을 수 있다 (FaceScan은 30개에서 멈추므로).
이 경우 diff에서 baselineOnly로 나타나는데, 이것은 **maxGroupCount에 의한 예상된 차이**이다.

로그에서 구분할 수 있도록:
- FaceScan이 maxGroupCount로 종료됐는지 플래그 전달
- 해당 시 로그에 "[참고] FaceScan이 maxGroupCount(30)에 도달하여 조기 종료" 추가
- baselineOnly 그룹은 "조기종료로 인한 미탐지"로 분류

---

## 검증 방법

### 현재 코드 상태에서의 예상 결과

현재 FaceScan은 청크 경계 문제가 있으므로, 경계에 걸린 그룹이 있는 경우 **FAIL**이 예상된다.
이것이 정상이다 — 하네스가 문제를 감지하고 있다는 뜻이다.

### 구조 수정(IncrementalGroupBuilder) 적용 후

수정이 올바르면 **PASS**로 전환되어야 한다.
PASS가 아니면 수정에 문제가 있다는 뜻이다.

### 실기기 테스트

1. 빌드 후 FaceScan 실행
2. Console.app 또는 `log stream --predicate 'subsystem == "com.karl.SweepPic"'`에서 `[Equivalence]` 검색
3. PASS/FAIL 확인
4. FAIL이면 baselineOnly/faceScanOnly 그룹의 assetID로 원인 추적

---

## 의존성

| 의존 대상 | 사용 방식 | 비고 |
|----------|----------|------|
| `PersonMatchingEngine` | 별도 인스턴스 생성 | 기존 인스턴스와 격리 |
| `SimilarityAnalyzer.formGroups()` | 기존 함수 그대로 호출 | 수정 없음 |
| `SimilarityConstants` | threshold, minGroupSize 등 참조 | 수정 없음 |
| `FaceScanCache` / `SimilarityCache` | **사용하지 않음** | 읽기도 쓰기도 안 함 |
| `TrashStore` | **사용하지 않음** | 사진 목록 캡처 시점에 이미 제외됨 |

---

## 파일별 변경 요약

| 파일 | 작업 | 라인 수 (추정) |
|------|------|--------------|
| `FaceScanEquivalenceHarness.swift` (신규) | 하네스 클래스 전체 | ~120줄 |
| `FaceScanService.swift` (수정) | #if DEBUG 블록 3개 추가 | ~30줄 |
| **합계** | | ~150줄 |

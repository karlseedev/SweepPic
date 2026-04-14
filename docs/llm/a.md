# FaceScan → Grid 경로 통합 계획

## 문제

FaceScan이 Grid에서 보이는 그룹을 못 찾는다. 구조적 불일치가 원인이다.

### 확인된 구조적 차이

| | Grid | FaceScan |
|---|---|---|
| fetchResult | ascending, images+videos (18,265장) | descending, images only (17,617장) |
| 그룹 형성 | formGroupsForRange() 단일 호출 | 20장 배치 축적 + sealed-group |
| 얼굴 매칭 순서 | ascending (오래된 순) | descending (최신 순) |
| 그룹 병합 | mergeOverlappingGroups (SimilarityCache) | 없음 (FaceScanCache) |
| 재시도 | 없음 (1회 판정) | 없음 (1회 판정 후 영원히 스킵) |

### 진단 로그로 확인된 직접 원인

1. 타깃 그룹 3장이 FaceScan 첫 배치(0...19)에서 `processGroupForFaceScan()` 진입
2. `assignPersonIndicesForGroup()`에서 3얼굴 감지됨
3. 그러나 **rejected** (nil 반환) — 격리 파이프라인(Grid 방식)에서는 같은 3장이 accepted
4. FaceScan은 rejected된 그룹을 이후 배치에서 `isNew: false`로 영원히 스킵
5. 근본 원인: descending 순서로 인해 기준 얼굴이 달라지고, SFace 매칭이 경계값에서 갈림

---

## 해결 방향

FaceScan의 자체 배치 파이프라인을 소스 오브 트루스로 쓰지 않는다.
Grid의 `formGroupsForRange()`를 격리 인스턴스에서 직접 호출하여 동일한 결과를 보장한다.

260403groupLogic.md "수정 방향"에 이미 계획됨:
> 수정 후 FaceScan: buildFetchResult → 격리 인스턴스 생성 → formGroupsForRange() 호출 → 결과를 FaceScanGroup으로 변환

격리 테스트(EQ)에서 이 방식으로 PASS를 확인했으므로 방향은 검증됨.

---

## 구체 변경

### 변경 대상: `FaceScanService.analyze()` 1개 메서드

**호출자**: `FaceScanListViewController.startAnalysis()` (단 1곳)

```
현재 analyze():
  buildFetchResult(descending, images only)
  → 배치 루프 50회 (20장씩 FP 축적 → formGroups → sealed → processGroup)
  → saveSession

변경 후 analyze():
  PhotoLibraryService.fetchAllPhotos()               ← Grid와 동일 (ascending, images+videos)
  → 범위 결정 (method 기반, ascending 기준)
  → 격리 SimilarityAnalysisQueue.formGroupsForRange() 1회 호출
  → 격리 SimilarityCache에서 결과 읽기 → FaceScanCache로 복사
  → onGroupFound 콜백 (1개씩)
  → saveSession (ascending 기준)
```

### 건드리지 않는 것

- `FaceScanListViewController` — 콜백 인터페이스 동일
- `FaceScanCache` — 그대로 사용, 쓰기 방식만 변경
- `FaceComparisonViewController` — FaceScanCache에서 읽으므로 영향 없음
- `SimilarityCache.shared` — 격리 인스턴스 사용으로 무관
- `SimilarityAnalysisQueue` — 변경 없음 (호출만)
- `processGroupForFaceScan()` — 더 이상 호출 안 함 (formGroupsForRange가 대체)

---

## 세부 설계

### 1. fetchResult 통일

```swift
// 기존: FaceScan 전용 (descending, images only)
let fetchResult = buildFetchResult(method: method)

// 변경: Grid와 동일 (ascending, images+videos)
let fetchResult = PhotoLibraryService.shared.fetchAllPhotos()
```

### 2. 범위 결정 (ascending 기준)

```swift
// fromLatest: 최신 N장 = 끝에서 N장
let start = max(0, fetchResult.count - FaceScanConstants.maxScanCount)
let end = fetchResult.count - 1
let range = start...end

// continueFromLast: lastAssetID에서 더 오래된 방향으로
// ascending에서 lastAssetID를 찾아 그 왼쪽으로 maxScanCount장
let lastIdx = findIndex(of: lastAssetID, in: fetchResult)
let end = lastIdx - 1
let start = max(0, end - maxScanCount + 1)
let range = start...end

// byYear: ascending fetchResult에서 연도 경계 이진탐색
// creationDate가 정렬되어 있으므로 ~14회 비교로 결정
let yearStart = binarySearch(fetchResult, firstDateIn: year)
let yearEnd = binarySearch(fetchResult, lastDateIn: year)
let scanEnd = min(yearEnd, yearStart + maxScanCount - 1)
let range = yearStart...scanEnd
```

### 3. 격리 인스턴스에서 formGroupsForRange 호출

```swift
let isolatedCache = SimilarityCache()
let isolatedQueue = SimilarityAnalysisQueue(cache: isolatedCache)

let groupIDs = await isolatedQueue.formGroupsForRange(
    range, source: .grid, fetchResult: fetchResult
)
```

격리 인스턴스 안전성 (검증됨):
- `self !== .shared` 가드로 analytics/notification 자동 억제
- postAnalysisComplete의 `guard self === .shared` 가드로 Grid/Viewer 알림 차단
- 격리 SimilarityCache에만 쓰기 → .shared 오염 없음

### 4. 결과 변환 + FaceScanCache 복사

```swift
var totalGroupsFound = 0
for groupID in groupIDs {
    if cancelled { throw CancellationError() }
    if totalGroupsFound >= FaceScanConstants.maxGroupCount { break }

    // 격리 캐시에서 읽기
    let members = await isolatedCache.getGroupMembers(groupID: groupID)
    let validSlots = await isolatedCache.getGroupValidPersonIndices(for: groupID)

    // FaceScanCache에 복사 (FaceComparisonViewController 조회용)
    for memberID in members {
        let faces = await isolatedCache.getFaces(for: memberID)
        await cache.setFaces(faces, for: memberID)
    }
    let group = SimilarThumbnailGroup(memberAssetIDs: members)
    await cache.addGroup(group, validSlots: validSlots, photoFaces: [:])

    // 콜백
    let scanGroup = FaceScanGroup(
        groupID: groupID,
        memberAssetIDs: members,
        validPersonIndices: validSlots
    )
    totalGroupsFound += 1

    let progress = FaceScanProgress.updated(
        scannedCount: range.count,
        groupCount: totalGroupsFound,
        currentDate: Date()
    )
    await MainActor.run {
        onGroupFound(scanGroup)
        onProgress(progress)
    }
}
```

### 5. session 저장 (ascending 기준)

```swift
// ascending에서 "다음에 이어서"는 범위의 lowerBound (가장 오래된 쪽)
let lastAsset = fetchResult.object(at: range.lowerBound)
if let lastDate = lastAsset.creationDate {
    saveSession(method: method, lastDate: lastDate, lastAssetID: lastAsset.localIdentifier)
}
```

---

## 검증에서 발견된 오류 및 수정

### 오류 1: 취소 메커니즘 불일치 (심각)

`formGroupsForRange`는 `Task.isCancelled` 사용, FaceScan은 `self.isCancelled` 플래그 사용. 연결 안 됨.

**증상**: 사용자 뒤로가기 → `scanService.cancel()` → `isCancelled = true` → 그러나 formGroupsForRange 내부의 `Task.isCancelled`는 false → FP 1000장 생성 완료까지 ~30-60초 블로킹

**해결**: `FaceScanListViewController`에서 분석 `Task`를 저장하고, 취소 시 `task.cancel()` 호출 추가.

```swift
// FaceScanListViewController
private var analysisTask: Task<Void, Error>?

func startAnalysis(method: FaceScanMethod) {
    analysisTask = Task {
        try await scanService.analyze(method: method, ...)
    }
}

// 취소 시
analysisTask?.cancel()
scanService?.cancel()  // 기존 플래그도 유지
```

이렇게 하면 `generateFeaturePrints` 내부의 `Task.checkCancellation()`이 동작하여 FP 생성 중에도 즉시 취소 가능.

### 오류 2: session 저장 방향 반전

descending에서는 `endIndex`(가장 오래된 쪽)를 저장. ascending에서는 `lowerBound`(가장 오래된 쪽)를 저장.

`continueFromLast` 방향도 반전:
- 기존(descending): lastAssetID → index + 1 (더 오래된 방향)
- 변경(ascending): lastAssetID → index - 1에서 역방향

위 "2. 범위 결정" 섹션에 반영 완료.

### 오류 3: 진행률 0% 구간 ~60초 (UX 문제)

- `generateFeaturePrints(1000장)`: AsyncSemaphore(5) → ~30초
- 그룹별 `assignPersonIndicesForGroup`: ~60그룹 × ~500ms ≈ ~30초
- **총 ~60초 동안 진행률 0%**, 이후 그룹 전달 시 한꺼번에 상승

**해결 옵션 (결정 필요)**:
- (A) 스피너로 대체 — 가장 간단, 진행률 포기
- (B) FP 생성 중 진행률 보고 — formGroupsForRange 구조 변경 필요, 복잡
- (C) "분석 중..." 텍스트만 표시, 게이지바는 그룹 전달 시에만 갱신 — 타협안

---

## 결정 필요 항목

### 결정 1: 비디오 포함 여부

Grid fetchResult = images + videos. 기존 FaceScan = images only.

| 옵션 | 장점 | 단점 |
|------|------|------|
| Grid 동일 (비디오 포함) | 그룹 구성 100% 일치 | "인물사진 비교정리"에 비디오 노출 |
| images only 필터 | 기존 UX 유지 | 인접 사진 사이 비디오 제거로 그룹 경계 미세 차이 가능 |

### 결정 2: 진행률 표시 방식

위 옵션 A/B/C 중 선택.

---

## 영향 범위 요약

| 파일 | 변경 | 수정량 |
|------|------|--------|
| `FaceScanService.swift` | analyze() 배치 루프 → formGroupsForRange 호출로 교체 | ~100줄 제거, ~60줄 추가 |
| `FaceScanService.swift` | 범위 결정 로직 신규 (ascending + method별) | ~40줄 추가 |
| `FaceScanService.swift` | saveSession 방향 수정 | ~5줄 수정 |
| `FaceScanListViewController.swift` | Task 저장 + task.cancel() | ~10줄 수정 |
| `FaceScanService.swift` | byYear 이진탐색 구현 | ~30줄 추가 |

**변경 없음**: FaceScanListViewController(콜백), FaceScanCache, FaceComparisonViewController, SimilarityCache, SimilarityAnalysisQueue, GridViewController

## 검증 방법

1. 기존 진단 버튼으로 문제 그룹 재확인 → FaceScan에서 accepted 여부
2. EQ 테스트 재실행 → PASS 유지 확인
3. continueFromLast/byYear 세션 이어서 하기 동작 확인
4. 취소 동작 확인 (FP 생성 중 뒤로가기)

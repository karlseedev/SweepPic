# 온보딩 C 사전분석 경량화 계획

## Context

온보딩 C 사전분석이 현재 메뉴 진입용 `analyze()`를 그대로 사용하여 Phase A(1,000장 FP 전체 생성)를 거침.
목적은 그룹 1개만 빠르게 찾는 것인데, 불필요하게 무거운 파이프라인을 사용 중.
또한 `SimilarityImageLoader.shared`를 공유하여 그리드 스크롤 시 사전분석도 함께 멈추는 문제 있음.

## 변경 방향

- 기존 `analyze()`는 메뉴 진입용으로 **그대로 유지** (Phase A→B→C, Grid 동등성 보장)
- 온보딩 C 전용 경량 분석 메서드를 **별도로 신규 생성**
- 전용 이미지 로더를 사용하여 **스크롤과 독립적**으로 동작

## 변경 파일

- `FaceScanConstants.swift` — 사전분석 상수 추가
- `FaceScanService.swift` — 경량 분석 메서드 추가 + init 확장
- `GridViewController+CoachMarkC.swift` — 호출부를 새 메서드로 교체

## 경량 분석 메서드 설계

### 핵심 로직: 동적 탐색 (FP 누적 + 100장마다 그루핑)

```
checkedAssetIDs: Set<String> = []  // 이미 얼굴감지 완료한 assetID

FP 생성 루프 (20장씩 배치):
  FP 20장 생성 → 누적 배열에 추가
  누적 100장 도달? → 그루핑 체크포인트:
    1. formGroups (누적된 전체 FP 대상)
    2. 각 그룹에서 checkedAssetIDs에 없는 새 멤버가 있는 그룹만 필터
    3. 필터된 그룹에 얼굴감지 실행
    4. 유효한 그룹(얼굴 확인됨)이면 → 콜백 + 종료
    5. 처리한 assetID를 checkedAssetIDs에 추가
    6. 아직 없음 → FP 생성 루프 계속
  2,000장 도달 또는 사진 소진 → 마지막 잔여분 체크포인트 실행 후 종료
```

### 특징
- FP 생성: 20장씩 배치 (기존 batchSize 동일)
- 그루핑 체크: 100장마다 (formGroups + 얼굴감지)
- formGroups는 누적된 전체 FP 대상 — 배치 경계와 무관하게 그룹 발견 가능
- **checkedAssetIDs로 중복 얼굴감지 방지** — 이전 체크포인트에서 처리한 그룹 재처리 안 함
- 그룹 1개 발견 즉시 종료
- 경계 그룹 잘림 허용 — Grid 동등성 불필요
- 검색 상한: 2,000장

### 스크롤 독립 동작
- `FaceScanService` init에 `imageLoader` 파라미터 추가
- 전용 `SimilarityImageLoader()` 인스턴스를 주입하여 생성
- `matchingEngine`이 `let`이므로 init 시점에 주입 (외부에서 교체 불가)
- 그리드 스크롤 시 `.shared.pause()`의 영향을 받지 않음

## 구현 단계

### Step 1: 상수 추가
- `FaceScanConstants.swift`에 추가:
  - `preScanMaxCount: Int = 2_000` (사전분석 검색 상한)
  - `preScanGroupingInterval: Int = 100` (그루핑 체크 간격)
- 빌드 확인

### Step 2: FaceScanService init 확장
- `FaceScanService.swift`의 `matchingEngine` 선언 변경:
  ```swift
  let matchingEngine: PersonMatchingEngine
  ```
- init에 imageLoader 파라미터 추가:
  ```swift
  init(cache: FaceScanCache, imageLoader: SimilarityImageLoader = .shared) {
      self.cache = cache
      self.matchingEngine = PersonMatchingEngine(imageLoader: imageLoader)
  }
  ```
- 기존 호출부(`analyze` 등)는 기본값 `.shared`로 동작 변경 없음
- 빌드 확인

### Step 3: 경량 분석 메서드 작성
- `FaceScanService.swift`에 `analyzeForFirstGroup()` 메서드 추가
- 시그니처: `func analyzeForFirstGroup(fetchResult: PHFetchResult<PHAsset>) async throws -> FaceScanGroup?`
  - 그룹 발견 시: `FaceScanGroup` 반환 (콜백 아님 — race condition 방지)
  - 미발견 시: `nil` 반환
  - 취소 시: `CancellationError` throw
- 내부 로직:
  1. 범위 결정: `findPhotoBasedLower`를 직접 호출, maxCount = `preScanMaxCount`, overlap = 0
  2. 사진 추출: `fetchPhotosInRange` 재사용
  3. FP 생성 루프: 20장씩 배치, 누적
  4. 100장마다 체크포인트: formGroups → 새 그룹만 얼굴감지 → 유효하면:
     - `isolatedCache.addGroupIfValid` 경로로 `isValidSlot` 반영된 얼굴 데이터 생성
     - 얼굴 데이터를 `FaceScanCache`에 저장 (호출부에서 `cache.getFaces` 호출 시 필요)
     - `FaceScanGroup` return
  5. 잔여분 처리: 루프 종료 후 마지막 체크포인트
  6. 취소 체크: 매 배치마다 `cancelled` 플래그 확인
- 빌드 확인

### Step 4: 호출부 교체
- `GridViewController+CoachMarkC.swift`의 `startCoachMarkCPreScanIfNeeded()` 수정:
  ```swift
  let cache = FaceScanCache()
  let service = FaceScanService(cache: cache, imageLoader: SimilarityImageLoader())
  service.skipSessionSave = true
  ```
- 기존 `service.analyze(...)` + 콜백 + cancel 패턴을 반환값 패턴으로 교체:
  ```swift
  let group = try await service.analyzeForFirstGroup(fetchResult: fetchResult)
  if let group {
      // 순차 await — race condition 없음
      // 1. SimilarityCache.shared 브리지
      // 2. FaceScanCache → SimilarityCache 얼굴 데이터 복사
      // 3. UserDefaults 저장
      // 4. UI 갱신 (MainActor)
  } else {
      // 0건 완료 마킹
  }
  ```
- `service.cancel()` 호출 제거 (메서드가 자체 return하므로 불필요)
- `CancellationError` catch는 유지 (외부 취소 대응)
- 빌드 확인

### Step 5: 실행 테스트

## 테스트

1. **사전분석 정상 동작**: 앱 진입 → 백그라운드에서 그룹 발견 → 뱃지 표시
2. **조기 종료**: 그룹 발견 즉시 분석 종료 (로그 확인)
3. **스크롤 독립**: 그리드 스크롤 중에도 사전분석 계속 진행 (로그로 확인)
4. **기존 메뉴 진입 무영향**: 인물사진 비교정리 메뉴 진입 시 기존과 동일하게 동작
5. **0건 케이스**: 2,000장 검색 후 미발견 시 정상 종료
6. **중복 방지**: 로그에서 같은 그룹이 반복 처리되지 않는지 확인

## 후속 수정: 키보드 사진 false positive 해소 (dd728aa)

### 문제
사전분석에서 키보드 사진(얼굴 없음)이 유효 그룹에 포함되어 온보딩이 시작됨.
그리드로 돌아오면 정규 분석에서 해당 사진에 테두리가 없어 UX 불일치 발생.

### 원인
사전분석이 `photos.reversed()`로 최신→과거 순서로 formGroups/assignPersonIndicesForGroup을 실행.
정규 분석은 과거→최신 순서(ascending).
`assignPersonIndicesForGroup`은 첫 사진에서 person slot을 부팅하고 이후 사진을 매칭하므로,
입력 순서가 다르면 저품질 false positive(norm 3.8, minEmbeddingNorm 7.0 미만)가 기존 slot에 매칭되는 양상이 달라짐.

### 해결
- FP 생성 순서: 최신부터 유지 (속도)
- formGroups/assignPersonIndices: 체크포인트 내에서 ascending 정렬 후 전달 (정규 분석과 동일)
- 그룹 검사: `rawGroups.reversed()` (최신 그룹부터, 정규 분석과 동일)

### 참고: hasFaces는 무관
`hasFaces`(VNDetectFaceRectanglesRequest)는 그리드에서 예비 테두리 조기 표시용 UI 최적화일 뿐,
최종 그룹 결정(YuNet → validSlots → validMembers → addGroupIfValid)과 무관.
그리드와 메뉴 버튼의 최종 분석 로직은 동일.

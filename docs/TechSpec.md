# PickPhoto Tech Spec (통합/개정안)

> 본 문서는 [prd5.md](./prd5.md)의 요구사항을 구현하기 위한 기술 설계 문서입니다.
> 원칙: PRD는 "무엇(요구사항/수용 기준)"을 고정하고, Tech Spec은 "어떻게(후보/가설/구현)"를 다룹니다.
> **개발 전 스파이크**(Spike 0, 1)로 아키텍처 결정을 확정하고, **개발 단계별 게이트**(Gate 1~4)에서 세부 정책을 검증합니다.

---

## 0. 목표/범위(Tech Spec)

- 타깃: iOS 16+, iPhone 17 ProMotion(120Hz) / iPhone 12(최저 보장)
- 데이터: 로컬 중심, 기본 정책 `isNetworkAccessAllowed = false`
- MVP: All Photos + 앨범(사용자/일부 스마트) + 뷰어 + 삭제(즉시, 위 스와이프 포함) + 멀티선택
- 그리드 줌: `1열 / 3열 / 5열` 3단(Photos와 유사한 타입) 지원을 전제로 설계

---

## 1. 검증 단계별 확정 항목

> PRD 9장의 검증 계획과 연동됩니다.
> - **개발 전 스파이크** (Spike 0, 1): 아키텍처 결정, 나중에 바꾸기 어려움
> - **개발 단계별 게이트** (Gate 1~4): 구현 중 튜닝/확정

---

### 1.1 개발 전 스파이크 (필수, 1~2일)

#### ~~Spike 0: UI 기술 스택~~ → **확정: UIKit**

> 대용량 그리드에서 UIKit UICollectionView가 SwiftUI LazyVGrid보다 셀 재사용/메모리 관리에서 유리함이 명확하므로 스파이크 없이 확정.

#### Spike 1: 데이터 소스 패턴 검증 → **확정: performBatchUpdates**

**확정 구조 (Spike 1 결과)**

| 레이어 | 선택 | 근거 |
|--------|------|------|
| UI | `UICollectionView` | UIKit 확정 (Spike 0) |
| 데이터 접근 | `PHFetchResult<PHAsset>` 기반 | 전량 배열 물질화 지양, lazy loading |
| 이미지 | `PHCachingImageManager` | 프리패치/취소 + 토큰 검증 (오표시 0) |
| **업데이트** | **`performBatchUpdates` + 수동 배열** | O(1) 스케일링, 50k에서 5ms 달성 |

> **핵심 통찰**: DiffableDataSource의 `apply()` 자체가 O(N) 비용을 가짐.
> 10k 이상에서 구조적 한계로 인해 `performBatchUpdates` 채택.

**검증된 시나리오**
1. 초기 로드 (스냅샷 생성 + apply)
2. 100개 일괄 삭제
3. 연속 삭제 20회 (1개씩)
4. 스크롤 중 삭제

**확정 사항 (Spike 1 출력)**
- ~~DiffableDataSource~~ → 10k 이상에서 O(N) 스케일링으로 불합격
- **performBatchUpdates + 수동 배열**: O(1) 스케일링, 50k에서 hitch 0 ms/s [Good]
- 수동 배열과 PHFetchResult 동기화 필요 (변경 감지 시)
- 배치 삭제 시 인덱스 정렬 후 뒤에서부터 삭제 권장

---

#### Spike 1 결과 (2025-12-16, 실기기 iPhone iOS 18.2)

**기본안(DiffableDataSource) 벤치마크 결과**

| 시나리오 | 1k | 5k | 10k | 50k |
|----------|-----|-----|-----|-----|
| Initial Load | 19ms | 40ms | 47ms | 142ms |
| Batch Delete (100) | 7.7ms | 16ms | 22ms | 59ms |
| Consecutive Delete (max) | 5.2ms | 12.9ms | 23ms | 52ms |
| Scroll Delete (max) | 15.5ms | 15.1ms | 24.5ms | 57ms |

> 50k에서 Hang 감지됨 (0.29~0.31초, Apple 기준 250ms 초과)

**프레임 기준 해석**

| 기준 | 값 | 근거 |
|------|-----|------|
| 120Hz (ProMotion) | 8.3ms | 이상적 목표 |
| **60Hz (기본)** | **16.67ms** | 현실적 필수 기준 |
| 터치 응답 | < 100ms | 업계 표준 |
| Hang 방지 | < 250ms | Apple 정의 |

**60Hz(16.67ms) 기준 판정**

| 시나리오 | 1k | 5k | 10k | 50k |
|----------|:---:|:---:|:---:|:---:|
| Batch Delete | ✅ | ✅ | ⚠️ | ❌ |
| Consecutive (max) | ✅ | ✅ | ⚠️ | ❌ |
| Scroll Delete (max) | ✅ | ✅ | ⚠️ | ❌ |

**Plan B (performBatchUpdates) 벤치마크 결과**

| 시나리오 | 1k | 5k | 10k | 50k |
|----------|-----|-----|-----|-----|
| 단일 삭제 (L1-1, p95) | ~4ms | ~4ms | ~4ms | **5ms** |
| hitch (Apple 기준) | 0 ms/s | 0 ms/s | 0 ms/s | **0 ms/s** |

> Apple Hitch 기준: < 5 ms/s = Good, 5-10 ms/s = Warning, > 10 ms/s = Critical

**Plan A vs Plan B 비교 (50k)**

| 지표 | Plan A | Plan B | 개선율 |
|------|--------|--------|--------|
| L1-1 p95 | 52ms | **5ms** | **10x** |
| hitch | 22 ms/s ❌ Critical | **0 ms/s** ✅ Good | - |
| 스케일링 | O(N) | **O(1)** | - |

**최종 결론**

| 항목 | 결정 |
|------|------|
| **채택** | **Plan B (performBatchUpdates + 수동 배열)** |
| 근거 | 50k에서 단일 삭제 ~5ms (프레임 예산 16.67ms 내), hitch 0 ms/s [Good], O(1) 스케일링 |
| Plan A 폐기 사유 | `apply()` 비용이 O(N)으로 10k 이상에서 구조적 한계 |

**구현 시 고려사항**

1. **수동 배열 동기화**: PhotoKit의 `PHFetchResult`와 로컬 배열 동기화 필요
2. **인덱스 관리**: 삭제 시 인덱스 정확성 유지 (뒤에서부터 삭제 권장)
3. **배치 삭제**: 여러 항목 삭제 시 `performBatchUpdates` 내에서 한번에 처리

> 상세 측정 데이터 및 시나리오별 결과는 [spiketest.md](./spiketest.md) 참조

---

### 1.2 개발 단계별 게이트 확정 항목

> 각 게이트에서 A/B 테스트 또는 튜닝으로 확정합니다.

#### Gate 2: 이미지 로딩

**preheat 윈도우 정책**

윈도우가 작으면 hitch↑, 크면 메모리/CPU↑이며 기기별 최적점이 다릅니다.

| 후보 | 설명 |
|------|------|
| A) 고정 윈도우 | 가시 영역 ±N (N ∈ {1,2,3,4}) |
| B) 속도 적응형 | 스크롤 속도에 따라 N 동적 조절 (느림 ±1, 보통 ±2, 빠름 ±3) |

확정할 것:
- 그리드 모드별(1/3/5열) 윈도우 값
- prefetch(delegate)와 preheat(`PHCachingImageManager`)의 역할 분담

**썸네일 요청 옵션**

Photos 앱 내부 옵션은 비공개이므로 A/B 테스트로 "유사 체감" 확보합니다.

| 후보 | 설명 |
|------|------|
| A) 빠른 표시 우선 | `deliveryMode = .opportunistic`, `resizeMode = .fast` |
| B) 품질 우선 | `deliveryMode = .highQualityFormat` 계열 |

확정할 것:
- 그리드(1/3/5열)별 `deliveryMode/resizeMode/targetSize` 정책
- "저→고 교체(펌핑)" 허용 조건

#### Gate 3: 핀치 줌 / 삭제

- 핀치 모드 전환 임계값 및 히스테리시스(떨림 방지)
- 변경 감지 업데이트 규칙 (부분 업데이트 vs 전체 리로드 조건)

#### Gate 4: 성능 튜닝 (120Hz)

**ProMotion 정책**

> 중요: ProMotion은 가변 주사율(10~120Hz)이며, 앱이 120Hz를 강제할 수는 없음.
> **목표**: 시스템이 120Hz를 선택할 수 있도록 프레임 버짓(8.3ms) 준수를 보장

| 후보 | 설명 |
|------|------|
| A) 상호작용 구간 최적화 | 스크롤/핀치/전환에서만 120 우선 + 병목 제거 중심 |
| B) 전반 120 선호 | `preferredFrameRateRange` 넓게 적용 + 발열/배터리 트레이드오프 |

확정할 것:
- `preferredFrameRateRange` 적용 범위
- 병목 분류 (메인 스레드/디코딩/레이아웃) 및 개선 우선순위

---

## 2. 기술 스택(확정)

- PhotoKit: `PHAsset`, `PHFetchResult`, `PHPhotoLibraryChangeObserver`
- 이미지: `PHCachingImageManager` 중심
- UI: `UICollectionView`(핵심 스크롤/뷰어 경로는 UIKit)
- SwiftUI: 셸/설정 등 비핵심에 한해 하이브리드 가능

---

## 3. 아키텍처 경계(구현 관점)

- `LibraryStore`: 권한/Fetch/Change observation, 정렬/필터 단일 소스
- `AlbumStore`: 사용자 앨범/스마트 앨범 목록 및 앨범별 fetch
- `TimelineIndex`(MVP: All-only): `assetID ↔ indexPath`/앵커 점프 기반 마련(후속: Days/Months/Years 확장)
- `ImagePipeline`: 요청/취소/코얼레싱/캐시/preheat 정책 단일화
- `GridController`: 재사용/프리패치/멀티선택/핀치 줌/앵커 유지(이미지 요청은 `ImagePipeline`만)
- `ViewerCoordinator`: 좌/우 탐색, 위 스와이프 삭제, 삭제 후 “이전 사진” 우선 이동

---

## 4. 이미지 파이프라인(오표시 0 보장 규칙)

### 4.1 요청 취소 + 토큰 검증(필수)

오표시 0을 위해, 셀 재사용 시 아래 규칙을 강제합니다.

- 셀은 “현재 바인딩된 `assetID` + 요청 토큰(예: `requestID` 또는 자체 `UUID`)"을 보유합니다.
- 셀 재사용/바인딩 변경 시:
  - 이전 요청은 반드시 취소합니다.
  - 토큰을 갱신합니다.
- 콜백 수신 시:
  - 콜백이 현재 토큰/assetID와 일치할 때만 이미지를 적용합니다.

### 4.2 코얼레싱(선택)

동일 `assetID + targetSize`의 동시 요청은 합쳐서 불필요한 디코딩/요청을 줄이는 후보입니다(스파이크로 필요성 판단).

---

## 5. 그리드 레이아웃/핀치 줌(1/3/5열)

### 5.1 모드(확정)

- 그리드 모드: `1열 / 3열 / 5열`
- 핀치로 모드 전환 시 앵커(핀치 중심) 유지가 깨지지 않아야 합니다.

### 5.2 스파이크로 확정할 파라미터

- 각 모드별 targetSize(요청 픽셀 크기) 및 preheat 윈도우
- 모드 전환 임계값(핀치 스케일)과 히스테리시스(떨림 방지)
- 모드 전환 중 이미지 요청 폭증 방지 규칙(요청 rate-limit/우선순위)

---

## 6. 삭제(즉시) 구현 요건

- 삭제는 항상 라이브러리 삭제(`PHAssetChangeRequest.deleteAssets`)
- 확인 UI 없음(즉시)
- 삭제 가능: 그리드(단일/멀티) + 뷰어(위 스와이프)
- 뷰어 삭제 후 이동: 이전 사진 우선 → 없으면 다음 → 없으면 그리드 복귀

### 6.1 권한 검증 (필수)

```swift
// PRD 5.3 삭제 안전장치
var canDelete: Bool {
    PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
}
```

| 권한 상태 | 동작 |
|-----------|------|
| `.authorized` (readWrite) | 삭제 UI 활성화 |
| 그 외 | 삭제 UI 비활성화 또는 권한 요청 안내 |

---

## 7. 계측/검증(스파이크/개발 공통)

- Instruments: Time Profiler, Core Animation, Allocations/Leaks
- 스파이크는 “결정 항목(섹션 1)”을 반드시 산출물로 남깁니다(선택 결과 + 파라미터 + 근거 지표).

---

## 8. 프로젝트 구조(초안)

> 아래는 초기 제안입니다. 실제 폴더/타깃 구성은 팀 합의로 확정합니다.

### 8.1 AppCore (Swift Package) - 비즈니스 로직

```
Sources/AppCore/
├── Models/
│   ├── PhotoModels.swift           # PhotoAssetEntry 등
│   ├── AlbumModels.swift           # Album, SmartAlbum
│   └── PermissionState.swift
├── Services/
│   ├── PhotoLibraryService.swift   # PhotoKit fetch/change observer
│   ├── AlbumService.swift          # 앨범/스마트 앨범
│   ├── ImagePipeline.swift         # 요청/취소/코얼레싱/캐시 정책
│   └── DeletionService.swift       # 삭제 처리
└── Stores/
    ├── PermissionStore.swift
    └── AppStateStore.swift         # 백그라운드/메모리 관리
```

### 8.2 App(Target) - UI 레이어

```
PickPhoto/
├── Features/
│   ├── Grid/
│   ├── Albums/
│   ├── Viewer/
│   └── Permissions/
└── Shared/
```

---

## 9. 핵심 컴포넌트 설계(초안)

### 9.1 Grid 데이터 소스 드라이버

**확정**: `performBatchUpdates` 기반 드라이버 (Spike 1 결과)

UI 레이어가 데이터 소스 구현에 의존하지 않도록 "드라이버" 경계를 둡니다.

- `GridDataSourceDriver` 프로토콜
  - `assetID(at indexPath) -> String?`
  - `reloadVisibleRange(anchorAssetID: String?)`
  - `applyDeletion(deletedAssetIDs: [String])`

구현:
- **채택**: `BatchUpdatesDriver` — Spike 1에서 O(1) 스케일링 검증 완료
- ~~DiffableDriver~~ — O(N) 스케일링으로 10k 이상에서 성능 불합격

> `performBatchUpdates` + 수동 배열 관리로 50k에서도 5ms 이내 삭제 성능 달성

### 9.2 프리패치/프리히트 연결(파라미터는 스파이크 확정)

- `UICollectionViewDataSourcePrefetching`는 “곧 보일 셀”을 선제 요청합니다.
- `PHCachingImageManager` preheat는 “가시 영역 ±N” 범위를 캐싱합니다.
- N(윈도우) 및 속도 적응 여부는 섹션 1.2 스파이크로 확정합니다.

### 9.3 핀치 줌(1/3/5열) + 앵커 유지

- 레이아웃은 1/3/5열 3단을 지원합니다.
- 핀치 중심점을 기준으로 “가장 가까운 셀의 assetID”를 앵커로 캡처합니다.
- 모드 전환 전/후에도 앵커가 화면에서 크게 튀지 않도록 스크롤 오프셋을 보정합니다.
- 전환 임계값/히스테리시스는 섹션 5.2에서 스파이크로 확정합니다.

---

## 10. 구현 순서(권장)

### Step 1: Foundation

1. 권한/Fetch/Change observation 파이프라인 구축(`LibraryStore`)
2. 앨범 목록/앨범 fetch(`AlbumStore`)
3. `ImagePipeline` 기본 요청/취소/토큰 검증 규칙 구현(오표시 0의 기반)
4. 삭제 처리(`DeletionService`) + 권한 게이트

### Step 2: Grid (All Photos)

1. `GridController` + 1/3/5열 레이아웃(기본은 3열)
2. 프리패치/프리히트 연결(윈도우 파라미터는 임시값으로 시작하고 스파이크로 확정)
3. 멀티선택 모드(Select) + 멀티 삭제

### Step 3: Viewer

1. 좌/우 탐색
2. 위 스와이프 삭제 + 삭제 후 “이전 사진” 우선 이동
3. 전환/제스처 중 hitch 없는지 계측

### Step 4: 게이트 검증 및 튜닝

1. ~~데이터 소스 검증~~ → **완료**: performBatchUpdates 채택 (Spike 1)
2. preheat 정책 확정 및 파라미터 고정 (Gate 2)
3. 썸네일 옵션(품질/속도) 확정 (Gate 2)
4. ProMotion(120Hz) 정책 확정 (Gate 4)

---

## 11. 문서 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|-----------|
| 1.0 | 2025-12-15 | 초안 작성 (prd4.md 기반) |
| 2.0 | 2025-12-15 | prd5.md 연동: PRD 참조 변경, 윈도잉(C) 옵션 제거, 스파이크 구조를 Spike 0,1 + Gate 1~4로 재구성, 권한 검증 코드 추가 |
| 2.1 | 2025-12-15 | Spike 1 재설계: "A/B 선택"에서 "기본안 검증 + Plan B 전환 조건" 구조로 변경, PHFetchResult 기반 설계 명시, 스냅샷 패턴이 핵심임을 강조 |
| **2.2** | **2025-12-16** | **Spike 1 완료**: Plan B(performBatchUpdates) 채택 확정, Apple Hitch 기준(< 5 ms/s) 적용, Plan A vs B 비교 결과 추가 |


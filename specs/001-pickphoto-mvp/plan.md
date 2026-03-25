# Implementation Plan: SweepPic MVP

**Branch**: `001-pickphoto-mvp` | **Date**: 2025-12-16 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `specs/001-pickphoto-mvp/spec.md`
**References**: [prd6.md](../../docs/prd6.md), [TechSpec.md](../../docs/TechSpec.md), [spiketest.md](../../docs/spiketest.md)

**Source of Truth** (충돌 시 우선순위):
1. **PRD** - 제품 요구사항 (최종 권위)
2. **Spec** - MVP 기능 요구사항
3. **TechSpec** - 구현 후보/검증 결과
4. **Plan** - 실행 순서 및 태스크

## Summary

SweepPic MVP는 iOS 기본 사진 앱 수준의 부드러운 브라우징 경험을 제공하면서, 위 스와이프 삭제와 앱 내 휴지통을 통한 빠른 사진 정리 기능을 제공하는 iOS 사진 갤러리 앱입니다.

**핵심 기술 결정 (Spike 완료)**:
- UIKit `UICollectionView` + `performBatchUpdates` (50k 기준 일정한 비용 관측, p95 5ms)
- `PHCachingImageManager` 기반 이미지 파이프라인
- 2단계 삭제 (앱 내 휴지통 → iOS 휴지통)

## Technical Context

**Language/Version**: Swift 5.9+, iOS 16+
**Primary Dependencies**: UIKit, PhotoKit (PHAsset, PHFetchResult, PHCachingImageManager, PHPhotoLibraryChangeObserver)
**Storage**: 파일 기반 저장 (앱 내 휴지통 상태, 대용량 ID Set 대응)
**Testing**: XCTest (단위/통합), Instruments (성능)
**Target Platform**: iOS 16+, iPhone 12 (최저) ~ iPhone 17 Pro (최적, ProMotion 120Hz)
**Project Type**: Mobile (iOS)
**Performance Goals** (목표/허용, 출처 포함):

| 항목 | 목표 | 허용 | 출처 |
|------|------|------|------|
| 스크롤 hitch | < 5 ms/s | < 5 ms/s | [Apple WWDC 2020](https://developer.apple.com/videos/play/wwdc2020/10077/) |
| 썸네일 응답 | < 100ms | < 100ms | [NNg](https://www.nngroup.com/articles/response-times-3-important-limits/) |
| 오표시 | 0 | 0 | 품질 필수 |
| 메모리 | < 250MB | < 250MB | [BrowserStack](https://www.browserstack.com/guide/how-to-conduct-ios-performance-testing) |
| 삭제 반영 | < 100ms | < 250ms | [NNg](https://www.nngroup.com/articles/response-times-3-important-limits/) / [Apple](https://developer.apple.com/videos/play/wwdc2020/10077/) |
| 콜드 스타트 | < 400ms | < 1s | [Apple WWDC 2019](https://developer.apple.com/videos/play/wwdc2019/423/) / [NNg](https://www.nngroup.com/articles/response-times-3-important-limits/) |
| 단일 삭제 (50k) | < 5ms | < 5ms | Spike 1 검증 |
**Scale/Scope**: 5만 장 사진 라이브러리 기준 성능 보장

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| 원칙 | 상태 | 설계 대응 |
|------|------|----------|
| I. 대용량 전제 (5만 장) | ✅ PASS | `performBatchUpdates` O(1) 스케일링 (Spike 1 검증) |
| II. 모션 품질 | ✅ PASS | hitch < 5 ms/s 목표 (상세: Gate 상태 요약 참조) |
| III. 핀치 줌 앵커 | ✅ PASS | Gate 3 검증: drift 0px, longest hitch 1f (Auto 테스트) |
| IV. 삭제 안정성 | ✅ PASS | "이전 사진 우선" 규칙, 앱 내 휴지통 설계 |
| V. 메모리 제한 (250MB) | ✅ PASS | `PHCachingImageManager` + 메모리 경고 시 캐시 해제 |
| VI. 단계적 검증 | ✅ PASS | Step 1~5 구현 순서 + Gate 검증 체계 |

**Performance KPI** (상세는 Performance Goals 테이블 참조):
- 오표시: 0 (토큰 검증 규칙으로 보장)
- 메모리 상한: 250MB ([BrowserStack](https://www.browserstack.com/guide/how-to-conduct-ios-performance-testing))
- 콜드 스타트: 목표 400ms / 허용 1s ([Apple](https://developer.apple.com/videos/play/wwdc2019/423/) / [NNg](https://www.nngroup.com/articles/response-times-3-important-limits/))
- 삭제 반영: 목표 100ms / 허용 250ms ([NNg](https://www.nngroup.com/articles/response-times-3-important-limits/) / [Apple](https://developer.apple.com/videos/play/wwdc2020/10077/))

## Project Structure

### Documentation (this feature)

```text
specs/001-pickphoto-mvp/
├── plan.md              # This file
├── spec.md              # Feature specification
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (API contracts)
├── checklists/          # Quality checklists
│   └── requirements.md
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
# iOS Mobile Application Structure

Sources/AppCore/           # Swift Package - Business Logic
├── Models/
│   ├── PhotoModels.swift           # PhotoAssetEntry, MediaType
│   ├── AlbumModels.swift           # Album, SmartAlbum
│   ├── TrashState.swift            # 앱 내 휴지통 상태
│   └── PermissionState.swift       # 권한 상태
├── Services/
│   ├── PhotoLibraryService.swift   # PhotoKit fetch/change observer
│   ├── AlbumService.swift          # 앨범/스마트 앨범
│   └── ImagePipeline.swift         # 요청/취소/코얼레싱/캐시 정책
└── Stores/
    ├── TrashStore.swift            # 앱 내 휴지통 상태 관리
    ├── PermissionStore.swift       # 권한 상태 관리
    └── AppStateStore.swift         # 백그라운드/메모리 관리

PickPhoto/                 # iOS App Target - UI Layer
├── App/
│   ├── AppDelegate.swift           # App entry (UIKit lifecycle)
│   └── SceneDelegate.swift         # Scene 관리
├── Features/
│   ├── Grid/
│   │   ├── GridViewController.swift
│   │   ├── GridDataSourceDriver.swift   # performBatchUpdates 기반
│   │   ├── PhotoCell.swift
│   │   └── SelectionManager.swift
│   ├── Albums/
│   │   ├── AlbumsViewController.swift
│   │   ├── AlbumCell.swift
│   │   └── TrashAlbumViewController.swift
│   ├── Viewer/
│   │   ├── ViewerViewController.swift
│   │   ├── ViewerCoordinator.swift
│   │   └── SwipeDeleteHandler.swift
│   └── Permissions/
│       └── PermissionViewController.swift
└── Shared/
    ├── Navigation/
    │   └── TabBarController.swift
    └── Components/
        ├── EmptyStateView.swift
        ├── FloatingTitleBar.swift       # 상단 플로팅 타이틀바 (타이틀 + Select)
        ├── FloatingTabBar.swift         # 하단 플로팅 캡슐 탭바 (iOS 18 스타일)
        └── FloatingOverlayContainer.swift  # 플로팅 오버레이 컨테이너

Tests/AppCoreTests/        # Package Tests
test/Spike1/               # Spike Test App (기존)
```

**Structure Decision**: iOS 앱 표준 구조 채택. AppCore Swift Package에 비즈니스 로직 분리, PickPhoto 앱 타겟에 UI 레이어 구현. Spike 테스트 앱은 별도 유지.

**MVP 범위 참고**: GridDataSourceDriver가 ID↔indexPath 매핑 및 앵커 유지 담당. TimelineIndex는 M2 이후 Days/Months/Years 모드 도입 시 분리 예정.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

모든 헌법 원칙 준수 - 위반 사항 없음.

---

## Phase 0: Research (주요 결정 완료, 일부 검증 보류)

### 기술 결정 사항

주요 기술 결정이 Spike/Gate 테스트를 통해 확정되었습니다. (일부 항목은 추가 검증 필요)

| 결정 항목 | 선택 | 근거 | 대안 |
|----------|------|------|------|
| UI 프레임워크 | UIKit 기반 (통일성 우선) | 셀 재사용 완전 제어, 대용량 메모리 관리 | SwiftUI 부분 하이브리드 (사용자 확인 후 허용) |
| 데이터 소스 | performBatchUpdates + 수동 배열 | 50k 기준 일정한 비용 관측 (p95 5ms) | DiffableDataSource (50k에서 52ms) |
| 이미지 로딩 | PHCachingImageManager | PhotoKit 공식 API, 시스템 최적화 | 커스텀 캐싱 (불필요) |
| 핀치 줌 | threshold 0.85/1.15, cooldown 200ms | Gate 3: drift 0px, longest hitch 1f | - |
| 120Hz | 시스템 자동 관리 (잠정) | Mock 테스트 관찰 결과, 실사진+120Hz 테스트 보류 | preferredFrameRateRange 강제 (발열/배터리) |
| 삭제 방식 | 2단계 (앱 내 휴지통 → iOS 휴지통) | 앱 내 1차 저장, 완전삭제 시 시스템 확인 | 즉시 삭제 (팝업 강제 표시됨) |

**UI 프레임워크 정책**:
- 기본: UIKit으로 구현
- 예외: SwiftUI가 현저히 유리한 경우, 사용자 확인 후 부분적 하이브리드 허용
- 판단 기준: "UIKit 대비 개발 효율 또는 UX 품질이 현저히 높을 때"

### Gate 상태 요약

| Gate | 상태 | 요약 |
|------|------|------|
| Gate 1 | ✅ 통과 | 5만 장 스크롤 hitch < 5 ms/s |
| Gate 2 | ⚠️ 부분 통과 | Auto(L1/L2): Good, Manual(L3): Critical → 스크롤 중 품질 저하 적용, 재검증 필요 |
| Gate 3 | ✅ 통과 | drift 0px, longest hitch 1f (Auto 테스트) |
| Gate 4 | ⏳ 보류 | Mock: Good (2.0 ms/s), 실사진+120Hz 조합 테스트 필요 |

---

## Phase 1: Design & Contracts

### Data Model

> 상세: [data-model.md](./data-model.md) (생성 예정)

#### Core Entities

```
PhotoAssetEntry
├── localIdentifier: String (PK, PHAsset.localIdentifier)
├── creationDate: Date
├── mediaType: MediaType (photo/video/livePhoto)
├── pixelWidth: Int
├── pixelHeight: Int
└── isTrashed: Bool (computed from TrashState)

TrashState
├── trashedAssetIDs: Set<String>
├── trashDates: [String: Date] (assetID → 삭제 시각)
└── persistence: File (대용량 ID Set 대응)

Album
├── localIdentifier: String (PK)
├── title: String
├── assetCount: Int
└── keyAssetIdentifier: String? (대표 썸네일 ID)

SmartAlbum
├── type: PHAssetCollectionSubtype (.smartAlbumScreenshots)
├── title: String (localized)
└── fetchOptions: PHFetchOptions
```

#### State Flow

```
[Normal Photo] --위 스와이프/Delete--> [Trashed (Dimmed)]
[Trashed] --복구--> [Normal Photo]
[Trashed] --완전삭제/비우기--> [iOS "최근 삭제됨"] (시스템 팝업)
```

### API Contracts

> 상세: [contracts/](./contracts/) (생성 예정)

#### Internal Service Interfaces

```swift
// PhotoLibraryService
protocol PhotoLibraryServiceProtocol {
    var authorizationStatus: PHAuthorizationStatus { get }
    func requestAuthorization() async -> PHAuthorizationStatus
    func fetchAllPhotos() -> PHFetchResult<PHAsset>
    func startObservingChanges()
}

// TrashStore
protocol TrashStoreProtocol {
    var trashedAssetIDs: Set<String> { get }
    func moveToTrash(assetIDs: [String])
    func restore(assetIDs: [String])
    func permanentlyDelete(assetIDs: [String]) async throws
    func emptyTrash() async throws
}

// ImagePipeline
enum ImageQuality {
    case fast   // 그리드 썸네일용 (opportunistic + fast)
    case high   // 뷰어용 (highQualityFormat + exact)
}

protocol ImagePipelineProtocol {
    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        quality: ImageQuality,  // 기본값: .fast
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> Cancellable
    func cancelRequest(_ cancellable: Cancellable)
    func preheat(assetIDs: [String], targetSize: CGSize)
    func stopPreheating(assetIDs: [String])
}

// GridDataSourceDriver
protocol GridDataSourceDriverProtocol {
    func assetID(at indexPath: IndexPath) -> String?
    func indexPath(for assetID: String) -> IndexPath?
    func reloadVisibleRange(anchorAssetID: String?)
    func applyTrashStateChange(trashedAssetIDs: Set<String>)
}
```

### Quickstart

> 상세: [quickstart.md](./quickstart.md) (생성 예정)

**Prerequisites**:
- Xcode 15+
- iOS 16+ 시뮬레이터 또는 실기기
- macOS Sonoma+ (권장)

**Build & Run**:
```bash
# AppCore Swift Package 빌드/테스트
swift build
swift test

# iOS 앱 (Xcode에서 열기)
open PickPhoto/PickPhoto.xcodeproj
# Xcode에서 PickPhoto 스킴 선택 후 Cmd+R
```

---

## Implementation Steps (TechSpec 기반)

### Step 1: Foundation

| 태스크 | 담당 모듈 | 의존성 | 검증 |
|--------|----------|--------|------|
| 권한/Fetch/Change observation | PhotoLibraryService | PhotoKit | 권한 상태별 동작 확인 |
| 권한 상태 관리 | PermissionStore | PhotoLibraryService | 상태 저장/UI 연동 |
| 앨범 목록/앨범 fetch | AlbumService | PhotoKit | 앨범 목록 표시 |
| ImagePipeline 기본 구현 | ImagePipeline | PHCachingImageManager | 오표시 0 검증 |
| 휴지통 관리 | TrashStore | File | 상태 저장/복원 |

### Step 2: Grid (All Photos)

| 태스크 | 담당 모듈 | 의존성 | 검증 |
|--------|----------|--------|------|
| GridController + 1/3/5열 레이아웃 | GridController | PhotoLibraryService | 핀치 줌 동작 |
| 플로팅 UI 컴포넌트 생성 | FloatingTitleBar, FloatingTabBar, FloatingOverlayContainer | - | 블러+딤, 터치 통과/버튼만 반응 |
| Edge-to-edge + 플로팅 오버레이 적용 | GridController, TabBarController | FloatingOverlayContainer | iOS 16~25: 시스템 바 숨김 + 커스텀 오버레이 + 플로팅 타이틀바에 Select, iOS 26+: 시스템 기본 + 네비바에 Select |
| contentInset/indicatorInsets 설정 | GridController | FloatingOverlayContainer | 첫/마지막 줄 가림 방지 |
| 빈칸 맨 위 정렬 | GridDataSourceDriver | - | 최신 사진(맨 아래) 기준 꽉 차게, 3의 배수 아닐 시 맨 위 행(스크롤 끝)에 빈 셀 |
| 프리패치/프리히트 연결 | ImagePipeline | GridController | hitch < 5 ms/s |
| 멀티선택 + 휴지통 이동 | SelectionManager | TrashStore | 선택/삭제 동작 |
| Select 모드 UI 전환 | FloatingOverlayContainer | SelectionManager | GridVC가 이벤트 발생 → Container가 UI 전환, 캡슐 탭바 ↔ Select 툴바 |
| 딤드 표시 | PhotoCell | TrashStore | 휴지통 사진 표시 |

**플로팅 오버레이 정책:**
- **적용 위치**: TabBarController.view 위에 한 번만 붙임 (탭 전환에도 유지), 현재 탭 타이틀/선택 상태만 동기화
- **Albums 탭**: 동일 오버레이 사용, 타이틀만 "Albums"로 변경, Select 버튼은 Albums 그리드 구현 시(Phase 6) 활성화
- **이벤트 흐름**: GridViewController가 Select 진입/종료 이벤트 발생 → FloatingOverlayContainer가 이벤트 받아 UI만 전환
- **iOS 버전별 Select 버튼**: iOS 16~25는 플로팅 타이틀바, iOS 26+는 시스템 네비바
- **블러/딤 정책**: 상단(FloatingTitleBar)만 블러(systemUltraThinMaterialDark) + 그라데이션 딤 적용, 하단(FloatingTabBar)은 블러 없이 그라데이션 딤만 적용
- **딤 알파**: maxDimAlpha = 0.55, 자연스러운 그라데이션(5단계 locations)

### Step 3: Viewer

| 태스크 | 담당 모듈 | 의존성 | 검증 |
|--------|----------|--------|------|
| 좌/우 탐색 | ViewerCoordinator | GridController | 제스처 인식 |
| 위 스와이프 휴지통 이동 | SwipeDeleteHandler | TrashStore | 20% 임계값 |
| "이전 사진 우선" 이동 | ViewerCoordinator | - | 삭제 후 이동 규칙 |
| 줌 전환 애니메이션 | ViewerCoordinator | GridController | 0.25초 전환 (Core Animation 기본값) |

### Step 4: 휴지통 (Albums 탭)

| 태스크 | 담당 모듈 | 의존성 | 검증 |
|--------|----------|--------|------|
| Albums 탭 UI (2열) | AlbumsViewController | AlbumService | 레이아웃 |
| 휴지통 앨범 표시 | TrashAlbumViewController | TrashStore | 목록 표시 |
| 복구/완전삭제 | ViewerCoordinator | TrashStore | 시스템 팝업 |
| 휴지통 비우기 | TrashAlbumViewController | TrashStore | 일괄 삭제 |

### Step 5: 게이트 검증 및 튜닝

| 태스크 | Gate | 검증 항목 |
|--------|------|----------|
| preheat 정책 확정 | Gate 2 | 실기기 PhotoKit 테스트 |
| 썸네일 옵션 확정 | Gate 2 | 품질/속도 트레이드오프 |
| 전체 통합 성능 | - | 5만 장 30초 스크롤 |
| 플로팅 UI 터치 검증 | - | 터치 충돌 0 (성능 검증은 Phase 9 T074) |

**플로팅 UI 터치 검증 통과 기준:**
- **터치**: 스크롤 중 상단 오버레이에 손이 닿아도 제스처 충돌 0
- 성능(hitch) 검증은 Phase 9 마무리 단계 T074에서 통합 수행

---

## Post-Design Constitution Re-check

| 원칙 | 상태 | 비고 |
|------|------|------|
| I. 대용량 전제 | ✅ | performBatchUpdates 일정 비용 채택 |
| II. 모션 품질 | ✅ | PHCachingImageManager + 토큰 검증 |
| III. 핀치 줌 앵커 | ✅ | CompositionalLayout + 앵커 보정 |
| IV. 삭제 안정성 | ✅ | 2단계 삭제 + "이전 사진 우선" |
| V. 메모리 제한 | ✅ | 메모리 경고 시 캐시 해제 |
| VI. 단계적 검증 | ✅ | Step 1~5 순차 구현 |

---

## Next Steps

1. `/speckit.tasks` 실행하여 상세 태스크 생성
2. Step 1 (Foundation) 구현 시작
3. Gate 2 개선 검증 (스크롤 중 품질 저하 적용 후 Manual 테스트)

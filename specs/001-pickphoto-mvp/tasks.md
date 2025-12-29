# Tasks: PickPhoto MVP

**입력**: `/specs/001-pickphoto-mvp/` 설계 문서
**필수 조건**: plan.md (필수), spec.md (유저 스토리 필수), research.md, data-model.md, quickstart.md

**테스트**: 이 MVP에서 테스트는 선택 사항 - 명시적으로 요청된 경우에만 포함

**구성**: 태스크는 유저 스토리별로 그룹화되어 각 스토리를 독립적으로 구현하고 테스트할 수 있음

## 형식: `[ID] [P?] [Story] 설명`

- **[P]**: 병렬 실행 가능 (다른 파일, 의존성 없음)
- **[Story]**: 해당 태스크가 속한 유저 스토리 (예: US1, US2, US3)
- 설명에 정확한 파일 경로 포함

## 경로 규칙

- **AppCore 패키지**: `Sources/AppCore/` (비즈니스 로직)
- **iOS 앱**: `PickPhoto/PickPhoto/` (UI 레이어)
- **테스트**: `Tests/AppCoreTests/`

---

## Phase 1: 셋업 (공유 인프라) ✅ 완료

**목적**: 프로젝트 초기화 및 기본 구조 생성

- [X] T001 iOS 16+ 배포 타겟으로 PickPhoto Xcode 프로젝트 생성 (PickPhoto/PickPhoto.xcodeproj)
- [X] T002 [P] Package.swift로 AppCore Swift 패키지 설정
- [X] T003 [P] PickPhoto.xcodeproj에 AppCore를 로컬 패키지 의존성으로 추가
- [X] T004 [P] Info.plist에 NSPhotoLibraryUsageDescription, NSPhotoLibraryAddUsageDescription 설정
- [X] T005 [P] 디렉토리 구조 생성: Sources/AppCore/Models/, Sources/AppCore/Services/, Sources/AppCore/Stores/
- [X] T006 [P] 디렉토리 구조 생성: PickPhoto/PickPhoto/App/, PickPhoto/PickPhoto/Features/, PickPhoto/PickPhoto/Shared/

---

## Phase 2: 기반 (블로킹 선행 조건) ✅ 완료

**목적**: 모든 유저 스토리 구현 전 완료해야 하는 핵심 인프라

**⚠️ 중요**: 이 단계 완료 전까지 유저 스토리 작업 불가

### 핵심 모델

- [X] T007 [P] MediaType enum 생성 (photo/video/livePhoto) - Sources/AppCore/Models/PhotoModels.swift
- [X] T008 [P] PhotoAssetEntry 구조체 생성 (localIdentifier, creationDate, mediaType, pixelWidth, pixelHeight) - Sources/AppCore/Models/PhotoModels.swift
- [X] T009 [P] TrashState 구조체 생성 (trashedAssetIDs, trashDates, lastModified) - Sources/AppCore/Models/TrashState.swift
- [X] T010 [P] PermissionState enum 생성 - Sources/AppCore/Models/PermissionState.swift

### 핵심 서비스

- [X] T011 PhotoLibraryServiceProtocol 및 PhotoLibraryService 생성 (authorizationStatus, requestAuthorization, fetchAllPhotos, startObservingChanges) - Sources/AppCore/Services/PhotoLibraryService.swift
- [X] T012 ImagePipelineProtocol 및 ImagePipeline 생성 (requestImage, cancelRequest, preheat, stopPreheating), PHCachingImageManager 사용 - Sources/AppCore/Services/ImagePipeline.swift

### 핵심 스토어

- [X] T013 [P] TrashStoreProtocol 및 TrashStore 생성 (trashedAssetIDs, moveToTrash, restore, permanentlyDelete, emptyTrash), 파일 기반 저장 - Sources/AppCore/Stores/TrashStore.swift
- [X] T014 [P] PermissionStore 생성 (currentStatus, requestAuthorization) - Sources/AppCore/Stores/PermissionStore.swift
- [X] T015 [P] AppStateStore 생성 (handleMemoryWarning, handleBackgroundTransition) - Sources/AppCore/Stores/AppStateStore.swift

### 앱 진입점

- [X] T016 [P] UIKit 라이프사이클로 AppDelegate 생성 - PickPhoto/PickPhoto/App/AppDelegate.swift
- [X] T017 [P] 윈도우 설정으로 SceneDelegate 생성 - PickPhoto/PickPhoto/App/SceneDelegate.swift
- [X] T018 Photos/Albums 탭으로 TabBarController 생성 - PickPhoto/PickPhoto/Shared/Navigation/TabBarController.swift

### 공유 UI 컴포넌트

- [X] T019 [P] EmptyStateView 컴포넌트 생성 - PickPhoto/PickPhoto/Shared/Components/EmptyStateView.swift

**체크포인트**: 기반 완료 - 유저 스토리 구현 시작 가능 ✅

---

## Phase 3: User Story 1 - 사진 브라우징 (Priority: P1) 🎯 MVP ✅ 완료

**목표**: 앱 실행 시 전체 사진 라이브러리를 그리드 형태로 탐색, 5만 장에서도 부드러운 스크롤 (hitch < 5 ms/s)

**독립 테스트**: 앱 실행 후 사진 그리드가 표시되고, 스크롤이 부드럽게 동작하는지 확인. 5만 장 라이브러리에서 끊김 없이 스크롤 가능.

### User Story 1 구현

- [X] T020 [US1] GridDataSourceDriverProtocol 및 GridDataSourceDriver 생성 (assetID↔indexPath 매핑, performBatchUpdates 래퍼) - PickPhoto/PickPhoto/Features/Grid/GridDataSourceDriver.swift
- [X] T021 [US1] PhotoCell 생성 (이미지 표시, 딤드 오버레이 65% opacity, 재사용 로직: 이전 요청 취소 + 토큰 검증) - PickPhoto/PickPhoto/Features/Grid/PhotoCell.swift
- [X] T022 [US1] GridViewController 생성 (UICollectionView, 3열 기본 레이아웃, 2pt 셀 간격, 정사각형 비율, CompositionalLayout) - PickPhoto/PickPhoto/Features/Grid/GridViewController.swift
- [X] T023 [US1] 핀치 줌 제스처 구현 (1/3/5열 전환, threshold 0.85/1.15, cooldown 200ms, 앵커 유지) - PickPhoto/PickPhoto/Features/Grid/GridViewController.swift
- [X] T024 [US1] ImagePipeline preheat/stopPreheating을 prefetchDataSource와 연동 - GridViewController
- [X] T025 [US1] 스크롤 스로틀링 (100ms 간격) 및 품질 저하 (스크롤 중 50% 썸네일 크기) 구현 - GridViewController
- [X] T026 [US1] PHPhotoLibraryChangeObserver 연동하여 실시간 업데이트 - GridViewController
- [X] T027 [US1] 휴지통 사진 딤드 표시 구현 (isTrashed 체크 → 65% 검정 오버레이) - PhotoCell
- [X] T027-1a [US1] FloatingTitleBar 컴포넌트 생성 (타이틀 + Select 버튼 + 블러 배경, 44pt + safe area, Select만 터치 반응, hitTest 오버라이드) - PickPhoto/PickPhoto/Shared/Components/FloatingTitleBar.swift
- [X] T027-1b [US1] FloatingTabBar 컴포넌트 생성 (캡슐 형태 + 좌우 아이콘, iOS 18 Photos 스타일, 블러+딤, 버튼만 터치, Select 모드 시 Select 툴바로 대체). 이벤트 흐름: GridVC가 Select 진입/종료 이벤트 발생 → FloatingOverlayContainer가 UI 전환 - PickPhoto/PickPhoto/Shared/Components/FloatingTabBar.swift
- [X] T027-1c [US1] FloatingOverlayContainer 생성 (상하단 그라데이션 + 블러뷰, FloatingTitleBar/FloatingTabBar 배치, 고정 레이어). 적용 위치: TabBarController.view 위에 한 번만 붙임 (탭 전환에도 유지), 현재 탭 타이틀/선택 상태만 동기화. Albums 탭: 동일 오버레이, 타이틀만 "Albums"로 변경 - PickPhoto/PickPhoto/Shared/Components/FloatingOverlayContainer.swift
- [X] T027-1d [US1] TabBarController iOS 버전별 분기 (iOS 26+: 시스템 기본 + 네비바에 Select 버튼, iOS 16~25: 시스템 탭바 숨김 + 커스텀 플로팅 UI + 플로팅 타이틀바에 Select 버튼) - TabBarController.swift
- [X] T027-1e [US1] 각 탭 UINavigationController 네비바 숨김 처리 (루트에서 일관 통제, iOS 16~25만 숨김, iOS 26+는 시스템 네비바 표시) - TabBarController.swift
- [X] T027-1f [US1] GridViewController edge-to-edge 설정 (contentInsetAdjustmentBehavior=.never, contentInset/indicatorInsets=플로팅 UI 높이, viewDidLayoutSubviews/viewSafeAreaInsetsDidChange) - GridViewController.swift
- [X] T027-1g [US1] 터치 차단 검증: 딤드 영역 터치 시 스크롤 차단 (기본 사진 앱 동작), 버튼만 반응 (성능 검증은 Phase 9 T074에서 수행) - 검증 태스크
- [X] T027-2 [US1] 그리드 빈칸 맨 위 정렬 구현 (최신 사진(맨 아래) 기준 꽉 차게, 3의 배수 아닐 시 맨 위 행(스크롤 끝)에 빈 셀) - GridViewController

**체크포인트**: User Story 1 독립적으로 완전히 동작하고 테스트 가능
- FR-001~FR-008 검증 가능
- SC-001, SC-002, SC-003, SC-008, SC-009 측정 가능

---

## Phase 4: User Story 2 - 뷰어에서 사진 탐색 및 삭제 (Priority: P2) ✅ 완료

**목표**: 그리드에서 사진 탭 → 전체 화면 뷰어 → 좌우 스와이프 탐색 → 위 스와이프 삭제 → 이전 사진으로 자동 이동

**독립 테스트**: 그리드에서 사진 탭 → 뷰어 진입 → 좌우 스와이프 탐색 → 위 스와이프 삭제 → 이전 사진으로 자동 이동 확인.

### User Story 2 구현

- [X] T028 [US2] ViewerViewController 생성 (UIPageViewController로 좌우 스와이프) - PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift
- [X] T029 [US2] ViewerCoordinator 생성 (네비게이션 로직, "이전 사진 우선" 규칙 구현) - PickPhoto/PickPhoto/Features/Viewer/ViewerCoordinator.swift
- [X] T030 [US2] SwipeDeleteHandler 생성 (팬 제스처, 20% 임계값, 위 스와이프 → moveToTrash) - PickPhoto/PickPhoto/Features/Viewer/SwipeDeleteHandler.swift
- [X] T031 [US2] 아래 스와이프로 닫기 구현 (뷰어 닫고 그리드로 복귀) - ViewerViewController
- [X] T032 [US2] 줌 전환 애니메이션 구현 (그리드 ↔ 뷰어, Core Animation 사용) - ViewerCoordinator
- [X] T033 [US2] 더블탭/핀치 줌 구현 (이미지 확대/축소) - ViewerViewController
- [X] T034 [US2] 원형 플로팅 삭제 버튼 생성 (하단에 항상 표시) - ViewerViewController
- [X] T035 [US2] 휴지통 사진 뷰어 모드 구현 (삭제 버튼 대신 "복구/완전삭제" 옵션 표시) - ViewerViewController
- [X] T036 [US2] 삭제 시 TrashStore 즉시 저장 연동 - ViewerViewController

**체크포인트**: User Story 1, 2 모두 독립적으로 동작
- FR-009~FR-015 검증 가능
- SC-004 테스트 코드로 검증 가능

---

## Phase 5: User Story 3 - 그리드에서 다중 선택 삭제 (Priority: P3) ✅ 완료

**목표**: Select 모드에서 여러 사진 선택 → 한 번에 앱 내 휴지통으로 이동

**독립 테스트**: Select 버튼 탭 → 여러 사진 탭/드래그 선택 → Delete 버튼 탭 → 선택된 사진 앱 내 휴지통으로 이동 확인.

### User Story 3 구현

- [X] T037 [US3] SelectionManager 생성 (selectedAssetIDs Set, toggle/clear/selectRange) - PickPhoto/PickPhoto/Features/Grid/SelectionManager.swift
- [X] T038 [US3] 네비게이션 바에 Select 버튼 추가, 선택 모드 토글 구현 - GridViewController
- [X] T039 [US3] 탭으로 선택 구현 (체크마크 토글, iOS 사진 앱 스타일) - PhotoCell
- [X] T040 [US3] 드래그로 연속 선택 구현 (딤드 사진 제외, MVP에서 화면 경계 자동 스크롤 미지원) - GridViewController
- [X] T041 [US3] 선택 모드에서 Cancel/Delete 툴바 버튼 추가 - GridViewController
- [X] T042 [US3] 네비게이션 바 타이틀에 선택된 사진 수 표시 - GridViewController
- [X] T043 [US3] 일괄 삭제 구현 (선택된 모든 사진 TrashStore.moveToTrash, 선택 해제) - GridViewController
- [X] T044 [US3] 딤드 사진 선택 비활성화 (isTrashed → 탭 무시) - PhotoCell
- [X] T045 [US3] 핀치 줌 중 선택 상태 유지 - GridViewController

**체크포인트**: User Story 1, 2, 3 모두 독립적으로 동작
- FR-016~FR-020 검증 가능
- SC-005 검증 가능

---

## Phase 6: User Story 4 - 앨범 브라우징 (Priority: P4) ✅ 완료

**목표**: Albums 탭에서 사용자 앨범, 스마트 앨범(Screenshots), 휴지통을 탐색하고 앨범 내 사진 보기

**독립 테스트**: 앨범 탭 진입 → 앨범 목록 확인 → 앨범 탭하여 진입 → 앨범 내 사진 그리드 확인.

### User Story 4 구현

- [X] T046 [P] [US4] Album 구조체 생성 (localIdentifier, title, assetCount, keyAssetIdentifier) - Sources/AppCore/Models/AlbumModels.swift
- [X] T047 [P] [US4] SmartAlbum 구조체 생성 (type, title, assetCount) - Sources/AppCore/Models/AlbumModels.swift
- [X] T048 [US4] AlbumServiceProtocol 및 AlbumService 생성 (fetchUserAlbums, fetchSmartAlbums, fetchPhotosInAlbum) - Sources/AppCore/Services/AlbumService.swift
- [X] T049 [US4] AlbumCell 생성 (썸네일, 제목, 사진 수 표시) - PickPhoto/PickPhoto/Features/Albums/AlbumCell.swift
- [X] T050 [US4] AlbumsViewController 생성 (2열 그리드 레이아웃, iOS 사진 앱 스타일) - PickPhoto/PickPhoto/Features/Albums/AlbumsViewController.swift
- [X] T051 [US4] 앨범 목록에 "휴지통" 가상 앨범 (TrashAlbum) 추가 - AlbumsViewController
- [X] T052 [US4] 앨범 탭 → 앨범 그리드 뷰 구현 (GridViewController 재사용, 앨범 필터 적용) - AlbumsViewController
- [X] T053 [US4] 앨범에서 삭제 구현 (moveToTrash) - 앨범 그리드 뷰

**체크포인트**: User Story 1-4 모두 독립적으로 동작
- FR-027~FR-031 검증 가능

---

## Phase 7: User Story 5 - 앱 내 휴지통 관리 (Priority: P5) ✅ 완료

**목표**: 휴지통에서 삭제 예정 사진 확인, 복구 또는 완전 삭제(iOS 휴지통으로 이동)

**독립 테스트**: 휴지통 진입 → 사진 목록 확인 → 개별 복구/삭제 → 일괄 비우기 시 시스템 팝업 확인.

### User Story 5 구현

- [X] T054 [US5] TrashAlbum 구조체 생성 → 하단 탭으로 대체 (별도 Trash 탭)
- [X] T055 [US5] TrashAlbumViewController 생성 (휴지통 전용 그리드, 빈 상태 표시) - PickPhoto/PickPhoto/Features/Albums/TrashAlbumViewController.swift
- [X] T056 [US5] "복구" 액션 구현 (TrashStore.restore → 딤드 효과 제거) - 휴지통 뷰어
- [X] T057 [US5] "완전삭제" 액션 구현 (TrashStore.permanentlyDelete → PHPhotoLibrary.performChanges로 iOS 시스템 팝업) - 휴지통 뷰어
- [X] T058 [US5] "비우기" 버튼 구현 (TrashStore.emptyTrash → 일괄 삭제 iOS 시스템 팝업) - TrashAlbumViewController
- [X] T059 [US5] 휴지통 비었을 때 빈 상태 표시 ("휴지통이 비어 있습니다") - TrashAlbumViewController
- [X] T060 [US5] 외부 삭제 처리 (PHAsset 더 이상 존재하지 않으면 TrashState에서 자동 제거) - TrashStore

**체크포인트**: User Story 1-5 모두 독립적으로 동작
- FR-021~FR-026 검증 가능
- SC-006, SC-007 검증 가능

---

## Phase 8: User Story 6 - 권한 관리 (Priority: P6) ✅ 완료

**목표**: 앱 최초 실행 시 권한 요청, 권한 상태에 따른 적절한 UI 표시

**독립 테스트**: 앱 최초 실행 → 권한 요청 화면 → 허용/거부 후 적절한 화면 표시 확인.

### User Story 6 구현

- [X] T061 [US6] PermissionViewController 생성 (권한 요청 UI) - PickPhoto/PickPhoto/Features/Permissions/PermissionViewController.swift
- [X] T062 [US6] "사진 접근 허용" 버튼 구현 (시스템 권한 다이얼로그 트리거) - PermissionViewController
- [X] T063 [US6] 거부/제한 상태 UI 구현 (Limited도 Denied와 동일하게 "설정에서 권한을 허용해주세요" + "설정 열기" 버튼) - PermissionViewController
- [X] T064 [US6] ~~제한 접근 배너 구현~~ → Limited도 Denied와 동일하게 PermissionViewController 표시로 변경됨
- [X] T065 [US6] SceneDelegate에 권한 체크 추가 (미승인 시 PermissionViewController 표시) - SceneDelegate
- [X] T066 [US6] 앱 실행 중 권한 변경 처리 (PHPhotoLibrary 권한 변경 감지) - SceneDelegate

**체크포인트**: 6개 User Story 모두 완전히 동작 ✅
- FR-032~FR-034 검증 가능

---

## Phase 9: 마무리 및 교차 관심사

**목적**: 여러 유저 스토리에 영향을 미치는 개선 사항

### 미디어 타입 지원

- [X] T067 [P] 비디오 썸네일 표시 구현 (재생 아이콘 + duration 배지), FR-035 기준 - PhotoCell
- [X] T068 [P] Live Photo 표시 구현 (정지 이미지, 배지 없음), FR-036 기준 - PhotoCell
- [X] T069 비디오 첫 프레임 표시 구현 (재생 미지원) - ViewerViewController

### 엣지 케이스

- [X] T070 [P] 사진 0장 빈 상태 구현 ("사진이 없습니다") - GridViewController
- [X] T071 [P] 앨범 내 사진 0장 빈 상태 구현 - 앨범 그리드
- [X] T072 메모리 경고 처리 구현 (ImagePipeline 캐시 해제) - AppStateStore
- [X] T073 iCloud 전용 사진 placeholder 표시 구현 - PhotoCell

### 성능 검증

- [ ] T074 Instruments로 5만 장 사진에서 hitch < 5 ms/s 프로파일 및 검증
- [ ] T075 일반 사용 시 메모리 사용량 < 250MB 검증
- [ ] T076 콜드 스타트 < 1s (목표 400ms) 검증

### 통합 및 최종 테스트

- [ ] T077 quickstart.md 검증 실행 (빌드, 테스트, 실행 워크플로우)
- [ ] T078 모든 성공 기준 검증 (SC-001 ~ SC-009)

---

## 의존성 및 실행 순서

### Phase 의존성

- **셋업 (Phase 1)**: 의존성 없음 - 즉시 시작 가능
- **기반 (Phase 2)**: 셋업 완료 의존 - 모든 유저 스토리 블로킹
- **유저 스토리 (Phase 3-8)**: 모두 기반 단계 완료 의존
  - 우선순위 순서대로 진행 가능 (P1 → P6)
  - 또는 팀 역량에 따라 병렬 진행 가능
- **마무리 (Phase 9)**: 모든 유저 스토리 완료 의존

### User Story 의존성

- **User Story 1 (P1)**: 기반 (Phase 2) 완료 후 시작 가능 - 다른 스토리 의존성 없음
- **User Story 2 (P2)**: 기반 (Phase 2) 완료 후 시작 가능 - US1의 GridViewController를 네비게이션 컨텍스트로 사용
- **User Story 3 (P3)**: 기반 (Phase 2) 완료 후 시작 가능 - US1의 GridViewController 확장
- **User Story 4 (P4)**: 기반 (Phase 2) 완료 후 시작 가능 - GridViewController 패턴 재사용
- **User Story 5 (P5)**: 기반 (Phase 2) 완료 후 시작 가능 - 기반의 TrashStore 의존
- **User Story 6 (P6)**: 기반 (Phase 2) 완료 후 시작 가능 - 플로우상 먼저 테스트해야 하지만 우선순위는 최하위

### 각 User Story 내부

- 모델 → 서비스 순서
- 서비스 → UI 컴포넌트 순서
- 핵심 구현 → 통합 순서
- 스토리 완료 후 다음 우선순위로 이동

### 병렬 실행 기회

Phase 1 (셋업) 내:
- T002, T003, T004, T005, T006 모두 병렬 실행 가능

Phase 2 (기반) 내:
- T007, T008, T009, T010 (핵심 모델) 병렬 실행 가능
- T013, T014, T015 (핵심 스토어) 병렬 실행 가능
- T016, T017 (앱 진입점) 병렬 실행 가능
- T011, T012 (핵심 서비스)는 순차 실행 권장 (ImagePipeline이 PhotoLibraryService 패턴 의존 가능)

User Story 내:
- 같은 스토리 내 [P] 표시된 태스크는 병렬 실행 가능

---

## 병렬 실행 예시: 셋업 및 기반

```bash
# 셋업 태스크 병렬 실행:
Task: T002 "Package.swift로 AppCore Swift 패키지 설정"
Task: T004 "사진 라이브러리 권한으로 Info.plist 설정"
Task: T005 "AppCore 디렉토리 구조 생성"
Task: T006 "PickPhoto 디렉토리 구조 생성"

# 핵심 모델 병렬 실행:
Task: T007 "MediaType enum 생성"
Task: T008 "PhotoAssetEntry 구조체 생성"
Task: T009 "TrashState 구조체 생성"
Task: T010 "PermissionState enum 생성"

# 핵심 스토어 병렬 실행:
Task: T013 "파일 기반 저장으로 TrashStore 생성"
Task: T014 "PermissionStore 생성"
Task: T015 "AppStateStore 생성"
```

---

## 구현 전략

### MVP 우선 (User Story 1만)

1. Phase 1: 셋업 완료
2. Phase 2: 기반 완료 (중요 - 모든 스토리 블로킹)
3. Phase 3: User Story 1 (사진 브라우징) 완료
4. **중단 및 검증**: User Story 1 독립적으로 테스트
   - 그리드 표시 확인
   - 5만 장 스크롤 테스트
   - hitch < 5 ms/s 검증
5. 준비되면 배포/데모

### 점진적 배포

1. 셋업 + 기반 → 기반 준비 완료
2. User Story 1 추가 → 독립 테스트 → **MVP 데모** (그리드 브라우징)
3. User Story 2 추가 → 독립 테스트 → 데모 (뷰어 + 스와이프 삭제)
4. User Story 3 추가 → 독립 테스트 → 데모 (다중 선택 삭제)
5. User Story 4 추가 → 독립 테스트 → 데모 (앨범)
6. User Story 5 추가 → 독립 테스트 → 데모 (휴지통 관리)
7. User Story 6 추가 → 독립 테스트 → **전체 MVP** (권한 관리)

### 1인 개발 권장 순서

Phase 1 → Phase 2 → Phase 3 (US1) → Phase 8 (US6) → Phase 4 (US2) → Phase 5 (US3) → Phase 6 (US4) → Phase 7 (US5) → Phase 9

**이유**: 권한 관리(US6)를 US1 직후에 구현하면 이후 테스트가 수월함.

---

## 참고 사항

- [P] 태스크 = 다른 파일, 의존성 없음
- [Story] 라벨은 태스크를 특정 유저 스토리에 매핑하여 추적성 확보
- 각 유저 스토리는 독립적으로 완료하고 테스트 가능해야 함
- 각 태스크 또는 논리적 그룹 후 커밋
- 체크포인트에서 중단하여 스토리 독립 검증 가능
- 피해야 할 것: 모호한 태스크, 같은 파일 충돌, 독립성을 해치는 스토리 간 의존성
- **성능 KPI**: hitch < 5 ms/s, 오표시 0, 메모리 < 250MB
- **헌법 체크**: 모든 원칙 준수 확인됨 (plan.md 참조)

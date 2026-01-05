# Tasks: 유사 사진 정리 기능

**Input**: Design documents from `/specs/002-similar-photo/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅
**Branch**: `002-similar-photo`
**Tech Stack**: Swift 5.9+, UIKit, Vision Framework, PhotoKit, iOS 16+

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

- **App Source**: `PickPhoto/PickPhoto/`
- **Features**: `PickPhoto/PickPhoto/Features/`
- **Tests**: `PickPhoto/PickPhotoTests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Feature Flag 및 기본 디렉토리 구조 생성

- [ ] T001 FeatureFlags.swift 생성 - `isSimilarPhotoEnabled` 플래그 정의 in `PickPhoto/PickPhoto/Shared/FeatureFlags.swift`
- [ ] T002 [P] SimilarPhoto 모듈 디렉토리 구조 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/` (Analysis/, UI/, Models/ 하위 폴더)
- [ ] T003 SimilarPhoto 모듈을 Xcode 프로젝트에 추가 in `PickPhoto/PickPhoto.xcodeproj`
  - PBXGroup에 Features/SimilarPhoto/ 폴더 구조 추가
  - 신규 Swift 파일들을 Build Phases > Compile Sources에 등록
  - Extension 파일들(GridViewController+SimilarPhoto, ViewerViewController+SimilarPhoto) 등록

**Checkpoint**: Feature Flag로 기능 on/off 가능, 디렉토리 구조 완성, Xcode 프로젝트 반영

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 User Story에서 공유하는 핵심 분석 인프라

**⚠️ CRITICAL**: User Story 구현 전에 반드시 완료해야 함

### 2.1 데이터 모델

- [ ] T004 [P] SimilarityAnalysisState 열거형 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/SimilarityAnalysisState.swift`
  - `notAnalyzed`, `analyzing`, `analyzed(inGroup: Bool, groupID: String?)` 케이스
  - 상태 전환 유효성 검증 메서드

- [ ] T005 [P] CachedFace 구조체 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/CachedFace.swift`
  - `boundingBox: CGRect` (Vision 정규화 좌표 0~1)
  - `personIndex: Int` (위치 기반 인물 번호, >= 1)
  - `isValidSlot: Bool` (그룹 내 2장 이상 감지 여부)
  - Vision → UIKit 좌표 변환 유틸리티 메서드

- [ ] T006 [P] SimilarThumbnailGroup + ComparisonGroup 구조체 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/SimilarPhotoGroup.swift`
  - **SimilarThumbnailGroup** (유사사진썸네일그룹 - 크기 제한 없음):
    - `groupID: String` (UUID)
    - `memberAssetIDs: [String]` (>= 3개)
    - `validPersonIndices: Set<Int>` (>= 1개)
    - `isValid: Bool` computed property
  - **ComparisonGroup** (유사사진정리그룹 - 최대 8장):
    - `sourceGroupID: String`
    - `selectedAssetIDs: [String]` (<= 8개)
    - `personIndex: Int`
    - 거리순 선택 알고리즘 (현재 사진 기준, 동일 거리 시 앞쪽 우선)

- [ ] T007 [P] FaceMatch 구조체 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/FaceMatch.swift`
  - `assetID: String`
  - `personIndex: Int`
  - `distance: Float`
  - `isSamePerson: Bool` computed property (거리 < 1.0이면 true)
  - 거리 >= 1.0이면 다른 인물로 판정하여 비교 그리드에서 제외 (spec FR-030)

- [ ] T008 [P] AnalysisRequest 구조체 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/AnalysisRequest.swift`
  - `assetID: String`
  - `source: AnalysisSource` (.grid, .viewer)
  - `range: ClosedRange<Int>`
  - 취소 규칙: grid는 취소 가능, viewer는 취소 불가

### 2.2 분석 엔진

- [ ] T009 SimilarityCache 클래스 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`
  - `states: [String: SimilarityAnalysisState]` - 사진별 상태
  - `groups: [String: SimilarThumbnailGroup]` - 그룹 관리
  - `assetFaces: [String: [CachedFace]]` - 사진별 얼굴 캐시
  - `accessOrder: [String]` - LRU 추적
  - 최대 캐시 크기: **500장**
  - LRU eviction 로직 (`evictIfNeeded()`)
  - `getState(for:)`, `setState(_:for:)`, `getFaces(for:)` 메서드
  - `getValidSlotFaces(for:)` - 유효 슬롯 얼굴만 반환
  - `invalidateGroup(groupID:)` - 그룹 삭제 시 각 멤버가 다른 유효 그룹에도 속해있으면 inGroup 유지 및 groupID 변경, 없으면 inGroup=false
  - 메모리 경고 시 50% LRU 제거 (`handleMemoryWarning()`)

- [ ] T010 그룹 유효성 필터링 및 상태 갱신 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`
  - **addGroup 호출 전** 유효성 검사 수행
  - 그룹 유효 조건 (spec FR-003, FR-005):
    - 멤버 3장 이상 AND
    - 유효 인물 슬롯(validPersonIndices) 1개 이상
  - 처리:
    - 조건 충족 → 그룹 저장 + 멤버들 `analyzed(inGroup: true, groupID)` 설정
    - 조건 미충족 → **그룹 미저장** + 멤버들 `analyzed(inGroup: false, nil)` 설정
  - **invalid 그룹이 캐시에 남지 않도록 보장**

- [ ] T011 SimilarityImageLoader 클래스 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift`
  - PHCachingImageManager 활용
  - 분석용 이미지: **긴 변 480px** 이하, `contentMode = .aspectFit`
  - `loadImage(for:completion:)` 메서드
  - 패딩/크롭 금지, 원본 비율 유지
  - 타임아웃: **3초**

- [ ] T012 SimilarityAnalyzer 클래스 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
  - **순수 계산만 담당** (로딩/큐 제어 안함)
  - `VNGenerateImageFeaturePrintRequest` 활용
  - `computeDistance(_:to:)` 로 유사도 계산
  - 유사도 임계값: **거리 10.0 이하**
  - `generateFeaturePrint(for:completion:)` 메서드
  - `compareFeaturePrints(_:_:) -> Float` 메서드

- [ ] T013 SimilarityAnalysisQueue 클래스 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
  - FIFO 큐 관리
  - 동시 분석: **최대 5개** (기본), **2개** (과열 시)
  - `thermalState` 모니터링 (.serious/.critical 시 제한)
  - `enqueue(_:)`, `cancel(source:)` 메서드
  - 스크롤 재개 시 `.grid` 소스만 취소, **`.viewer` 소스는 취소 불가**
  - **분석 완료 콜백**:
    - payload: `[String]` (assetIDs) 또는 `String?` (groupID) - 인덱스 대신 ID 사용
    - `NotificationCenter.post(name: .similarPhotoAnalysisComplete, userInfo: ["groupID": String?, "assetIDs": [String]])`
  - 그리드/뷰어에서 해당 알림 구독하여 UI 갱신

- [ ] T014 분석 파이프라인 통합 (SimilarityAnalysisQueue가 orchestrate) in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
  - 분석 플로우 orchestration:
    1. SimilarityImageLoader 호출 → 이미지 로딩
    2. SimilarityAnalyzer 호출 → 순수 유사도 계산 (FeaturePrint 생성/비교)
    3. FaceDetector 호출 → 얼굴 감지
    4. 위치 기반 인물 번호(personIndex) 부여 (좌→우, 위→아래)
    5. validPersonIndices 계산: 그룹 내 2장 이상 감지된 인물 슬롯 집합
    6. SimilarityCache에 결과 저장 요청 (T010 유효성 검사 거침)
  - 분석 범위: 화면에 보이는 사진 기준 **앞뒤 7장**
  - 최소 그룹 크기: **3장 이상**

- [ ] T015 FaceDetector 클래스 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/FaceDetector.swift`
  - `VNDetectFaceRectanglesRequest` 활용
  - 유효 얼굴 기준: 화면 너비의 **5% 이상**
  - `detectFaces(in:imageSize:viewWidth:completion:)` 메서드
  - Vision 정규화 좌표 반환 (0~1, 원점 좌하단)
  - 인물 번호 부여: 좌→우, 위→아래 순서 (X좌표 오름차순, X 동일 시 Y 내림차순)

- [ ] T016 FaceCropper 유틸리티 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/FaceCropper.swift`
  - bounding box + **30% 여백** 추가
  - **1:1 정사각형** 조정
  - 경계 처리: 중심 고정, 경계 내 최대 크기로 축소
  - `cropFace(from:boundingBox:)` 메서드

**Checkpoint**: Foundation 완료 - 분석 인프라 및 모델 사용 가능, User Story 구현 시작 가능

---

## Phase 3: User Story 1 - 그리드에서 유사 사진 발견 (Priority: P1) 🎯 MVP

**Goal**: 사용자가 그리드 스크롤을 멈추면 유사 사진에 테두리 애니메이션 표시

**Independent Test**: 그리드에서 스크롤 후 멈추면 유사 사진에 빛이 도는 테두리가 표시되는지 확인

**Acceptance Criteria**:
- 스크롤 멈춤 후 **0.3초 디바운싱** 후 분석 시작
- 분석 완료 후 **1초 이내** 테두리 표시
- 테두리: 흰색 그라데이션, 시계방향 회전, **1.5초 주기**
- 스크롤 재개 시 테두리 사라짐 및 분석 취소
- 테두리 탭 시 해당 사진의 뷰어로 이동

### Implementation for User Story 1

- [ ] T017 [P] [US1] BorderAnimationLayer 클래스 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/BorderAnimationLayer.swift`
  - `CAShapeLayer` + `CAKeyframeAnimation`
  - 사각형 path, 흰색 그라데이션
  - 시계방향 회전, **1.5초 주기**
  - `strokeStart/strokeEnd` 애니메이션
  - 모션 감소 설정 시 정적 테두리: 흰색 **2pt 실선**, cornerRadius = 0
  - `startAnimation()`, `stopAnimation()`, `showStaticBorder()` 메서드
  - 모든 셀 **동일한 위상으로 동기화** (CACurrentMediaTime 기준)

- [ ] T018 [US1] GridViewController+SimilarPhoto.swift Extension 생성 in `PickPhoto/PickPhoto/Features/Grid/GridViewController+SimilarPhoto.swift`
  - FeatureFlag 체크 (`FeatureFlags.isSimilarPhotoEnabled`)
  - VoiceOver 활성화 시 기능 비활성화 (`UIAccessibility.isVoiceOverRunning`)
  - 선택 모드 시 기능 비활성화
  - 휴지통 화면 시 기능 적용 안함
  - `scrollViewDidEndDecelerating`/`scrollViewDidEndDragging` 감지
  - **0.3초 디바운싱** 타이머 (`DispatchWorkItem` 활용)
  - 분석 범위 계산: 화면 내 보이는 셀 기준 **앞뒤 7장**
  - SimilarityAnalysisQueue에 분석 요청 (source: .grid)
  - `NotificationCenter` 구독하여 분석 완료 시 BorderAnimationLayer 표시
  - `scrollViewWillBeginDragging` 시 분석 취소 및 테두리 제거
  - `collectionView(_:didSelectItemAt:)` 에서 테두리 있는 셀 탭 시 뷰어 이동 처리

- [ ] T019 [US1] GridViewController 기존 파일에 최소 수정 in `PickPhoto/PickPhoto/Features/Grid/GridViewController.swift`
  - Extension 메서드 호출만 추가
  - `viewDidLoad`에서 `setupSimilarPhotoObserver()` 호출
  - `scrollViewDidEndDecelerating`에서 `handleScrollEnd()` 호출
  - `scrollViewWillBeginDragging`에서 `handleScrollStart()` 호출
  - 셀 구성 시 `configureBorderAnimation(for:)` 호출

- [ ] T020 [US1] 셀 레이어 관리 in `PickPhoto/PickPhoto/Features/Grid/GridViewController+SimilarPhoto.swift`
  - `collectionView(_:willDisplay:forItemAt:)` - 테두리 레이어 추가/갱신
  - `collectionView(_:didEndDisplaying:forItemAt:)` - 테두리 레이어 제거 (메모리 최적화)
  - 테두리 레이어 재사용 풀 관리

- [ ] T021 [US1] 그룹 무효화 처리 in `PickPhoto/PickPhoto/Features/Grid/GridViewController+SimilarPhoto.swift`
  - 삭제 후 그룹 멤버 3장 미만 시 테두리 즉시 제거
  - SimilarityCache.invalidateGroup 호출 연동
  - NotificationCenter로 삭제 이벤트 감지
  - **삭제 후 즉시 재분석하지 않고 다음 스크롤 멈춤 시 자동 재분석** (spec Gesture & Layout)

**Checkpoint**: 그리드 스크롤 멈춤 → 테두리 표시 → 탭으로 뷰어 진입 가능

---

## Phase 4: User Story 2 - 뷰어에서 얼굴 비교 진입 (Priority: P1)

**Goal**: 유사 사진 뷰어에서 감지된 얼굴 위에 + 버튼 표시, 탭하면 얼굴 비교 화면으로 진입

**Independent Test**: 유사 사진 뷰어에서 + 버튼 표시 및 탭으로 얼굴 비교 화면 진입 테스트

**Acceptance Criteria**:
- 캐시 hit 시 **100ms 이내** +버튼 표시
- 캐시 miss 시 분석 완료 후 **0.5초 이내** +버튼 표시
- +버튼 최대 **5개**까지 표시 (6개 이상 시 얼굴 크기순 상위 5개)
- +버튼 위치: 얼굴 위 중앙, 겹침 시 좌→우→아래→위 순서로 조정
- 유효 슬롯(2장 이상 감지된 인물)의 얼굴에만 +버튼 표시

### Implementation for User Story 2

- [ ] T022 [P] [US2] FaceButtonOverlay 클래스 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
  - UIView 기반 오버레이
  - +버튼: SF Symbol `plus.circle.fill`, 탭 제스처
  - 최대 **5개** 버튼 (얼굴 크기순 상위)
  - 기본 위치: 얼굴 위 중앙 (boundingBox.midX, boundingBox.minY - buttonRadius)
  - 겹침 방지 로직: 좌 → 우 → 아래 → 위 순서 (버튼 지름 × **1.2** 이동)
  - 화면 경계 초과 시 반대 방향 시도, 4회 실패 시 현재 위치 유지
  - `layoutButtons(for:imageSize:viewerFrame:)` 메서드
  - 화면 회전 시 위치 재계산 (`viewWillTransition` 대응)
  - iPad 멀티윈도우 대응

- [ ] T023 [P] [US2] AnalysisLoadingIndicator 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/AnalysisLoadingIndicator.swift`
  - UIActivityIndicatorView 기반
  - 분석 중(notAnalyzed → analyzing) 상태에서 표시
  - 분석 완료 시 자동 숨김
  - `show()`, `hide()` 메서드

- [ ] T024 [US2] ViewerViewController+SimilarPhoto.swift Extension 생성 in `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController+SimilarPhoto.swift`
  - FeatureFlag 체크
  - VoiceOver/선택모드/휴지통 시 비활성화
  - 뷰어 진입 시 캐시 조회 (`SimilarityCache.getState(for:)`)
  - 캐시 hit (analyzed, inGroup=true): 즉시 FaceButtonOverlay 표시
  - 캐시 miss (notAnalyzed): AnalysisLoadingIndicator 표시 + 분석 요청 (source: .viewer)
  - **분석 범위: 현재 사진의 인덱스 기준 ±7장** (spec FR-001)
  - **viewer source는 스크롤 시에도 취소되지 않음** (T013 cancel 규칙 참조)
  - **notAnalyzed만 분석 (기존 analyzed 유지), 분석 완료 후 범위 내 그룹 재계산, CachedFace.isValidSlot 갱신** (prd9 §2.3.1)
  - `NotificationCenter` 구독하여 분석 완료 콜백으로 +버튼 표시
  - `getValidSlotFaces(for:)` 호출하여 유효 슬롯 얼굴만 표시
  - +버튼 탭 핸들러: FaceComparisonViewController 표시
  - 스와이프로 다른 사진 이동 시 +버튼 갱신 (`pageViewController(_:didFinishAnimating:)`)

- [ ] T025 [US2] ViewerViewController 기존 파일에 최소 수정 in `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`
  - Extension 메서드 호출만 추가
  - `viewDidAppear`에서 `showSimilarPhotoOverlay()` 호출
  - 스와이프 완료 시 `updateSimilarPhotoOverlay()` 호출
  - FaceButtonOverlay와 AnalysisLoadingIndicator를 subview로 추가

- [ ] T026 [US2] +버튼 탭 → 인물 매칭 로직 in `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController+SimilarPhoto.swift`
  - 탭된 얼굴의 `personIndex` 확인
  - ComparisonGroup 생성: 현재 사진 기준 거리순 **최대 8장**
  - Feature Print 비교로 동일 인물 필터링 (거리 **1.0 이상** 제외)
  - FaceComparisonViewController 표시 (~**0.5초** 로딩)

**Checkpoint**: 유사 사진 뷰어 → +버튼 표시 → 탭으로 얼굴 비교 화면 진입 가능

---

## Phase 5: User Story 3 - 얼굴 비교 및 삭제 (Priority: P1)

**Goal**: 얼굴 비교 화면에서 동일 인물의 얼굴을 2열 그리드로 비교하고 삭제

**Independent Test**: 얼굴 비교 화면에서 사진 선택 후 삭제하여 휴지통 이동 테스트

**Acceptance Criteria**:
- 2열 정사각형 그리드
- 헤더: "인물 N (M장)" 형식
- 순환 버튼으로 다음 인물 전환 (선택 상태 유지)
- 사진 탭으로 선택/해제 토글, 체크마크 표시
- Delete 탭 시 휴지통 이동 + 뷰어 복귀
- 기존 Undo 기능과 통합

### Implementation for User Story 3

- [ ] T027 [P] [US3] FaceComparisonViewController 기본 구조 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
  - UIViewController 기반
  - UICollectionView 2열 그리드 (`UICollectionViewFlowLayout`)
  - 셀 크기: (화면너비 - 간격) / 2, 정사각형
  - 간격: 2pt (itemSpacing, lineSpacing)
  - `comparisonGroup: ComparisonGroup` 프로퍼티
  - `delegate: FaceComparisonDelegate` (삭제/닫기 콜백)

- [ ] T028 [US3] FaceComparisonViewController 헤더 구현 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
  - 헤더 레이블: "인물 N (M장)" 형식
  - 순환 버튼: SF Symbol `arrow.trianglehead.2.clockwise.rotate.90`
  - 순환 로직: 인물 번호 오름차순, 마지막→첫 번째 (원형 순환)
  - 순환 시 선택 상태 유지
  - iOS 16~25: 커스텀 FloatingTitleBar 사용
  - iOS 26+: 시스템 네비게이션바 사용 (Liquid Glass)

- [ ] T029 [US3] FaceComparisonViewController 그리드 셀 구현 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
  - 셀: 크롭된 얼굴 이미지 (30% 여백, 정사각형)
  - FaceCropper 활용
  - 탭으로 선택/해제 토글
  - 선택 시 체크마크 오버레이 표시 (기존 선택 모드 UI 재사용)
  - 거리 1.0 이상 사진은 비교 그리드에 표시되지 않음 (T026에서 필터링됨)

- [ ] T030 [US3] FaceComparisonViewController 하단바 구현 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
  - FloatingTabBar 재사용 또는 커스텀 구현
  - Cancel 버튼: 선택 해제 후 뷰어 복귀
  - 선택 개수 레이블: "N개 선택됨"
  - Delete 버튼: 선택된 사진 삭제 (비활성화 상태: 0개 선택 시)

- [ ] T031 [US3] 삭제 로직 구현 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
  - Delete 탭 시 TrashStore.moveToTrash 호출
  - 삭제 후 뷰어로 복귀
  - 현재 사진 삭제 시 이전 사진으로 이동 (없으면 다음 사진)
  - 모든 사진 삭제 시 뷰어 닫고 그리드로 복귀
  - 그룹 멤버 3장 미만 시 그룹 무효화 + 테두리/+버튼 즉시 제거
  - Undo 지원: 기존 앱 Undo 기능과 동일하게 복구 가능

- [ ] T032 [US3] TrashStore 연동 in `PickPhoto/PickPhoto/Stores/TrashStore.swift` (기존 파일 수정)
  - `moveToTrash(assetIDs:)` 호출 시 SimilarityCache 알림
  - NotificationCenter.post로 삭제 이벤트 전파
  - Undo 시 SimilarityCache 상태 복원

**Checkpoint**: 얼굴 비교 화면에서 사진 비교 → 선택 → 삭제 → 뷰어 복귀 가능

---

## Phase 6: User Story 4 - 오버레이 토글 (Priority: P3)

**Goal**: 뷰어에서 + 버튼 오버레이를 숨기거나 보이게 전환

**Independent Test**: 토글 버튼으로 + 버튼 숨김/보임 전환 테스트

**Acceptance Criteria**:
- eye 아이콘 탭 → +버튼 숨김, 아이콘 eye.slash로 변경
- 다른 사진으로 스와이프 후 복귀 시 +버튼 보임 상태로 리셋

### Implementation for User Story 4

- [ ] T033 [P] [US4] 토글 버튼 UI 추가 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
  - eye/eye.slash 토글 아이콘 (SF Symbol)
  - 위치: 화면 우측 하단 또는 상단 (기존 UI와 충돌 방지)
  - 탭 제스처 핸들러

- [ ] T034 [US4] 토글 상태 관리 in `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController+SimilarPhoto.swift`
  - `isOverlayHidden: Bool` 상태 변수
  - 토글 시 FaceButtonOverlay.isHidden 설정
  - 다른 사진으로 스와이프 시 `isOverlayHidden = false` 리셋
  - 아이콘 상태 동기화 (eye ↔ eye.slash)

**Checkpoint**: +버튼 토글 가능, 스와이프 후 자동 리셋

---

## Phase 7: Edge Cases & System State Handling

**Purpose**: 명세서에 정의된 엣지 케이스 및 시스템 상태 처리

### Edge Cases

- [ ] T035 [P] 유사 사진 3장 미만 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
  - 그룹 생성 조건: 최소 3장 이상
  - 미충족 시 테두리/+버튼 미표시

- [ ] T036 [P] 얼굴 없는 사진 처리 in `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController+SimilarPhoto.swift`
  - CachedFace 배열이 비어있으면 +버튼 미표시
  - 로딩 인디케이터 없이 정상 뷰어 표시

- [ ] T037 [P] 작은 얼굴 필터링 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/FaceDetector.swift`
  - 화면 너비 5% 미만 얼굴 제외
  - `isValidFace(boundingBox:viewWidth:)` 메서드

- [ ] T038 [P] 유효 슬롯 미달 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
  - 인물 슬롯에 2장 미만 시 해당 인물 +버튼 미표시
  - `isValidSlot` 필터링

- [ ] T039 분석 타임아웃 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
  - 단일 사진 분석 **3초 초과** 시 실패 처리
  - `DispatchWorkItem` 타임아웃 설정
  - 실패 사진은 그룹에 미포함

### System State Handling

- [ ] T040 [P] 메모리 경고 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`
  - `UIApplication.didReceiveMemoryWarningNotification` 구독
  - 캐시 **50% LRU 제거**
  - 현재 분석 중인 사진은 eviction 제외

- [ ] T041 [P] 디바이스 과열 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
  - `ProcessInfo.thermalState` 모니터링
  - `.serious`/`.critical` 시 동시 분석 **5개 → 2개**
  - 상태 복구 시 원래 제한으로 복원

- [ ] T042 [P] 백그라운드 전환 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
  - `UIApplication.didEnterBackgroundNotification` 구독
  - 진행 중인 분석 취소, 캐시 유지
  - 포그라운드 복귀 시 재분석 없음

- [ ] T043 외부 라이브러리 변경 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`
  - `PHPhotoLibraryChangeObserver` 연동
  - 변경된 사진의 캐시 무효화
  - 그룹 멤버 변경 시 그룹 재계산

### Error Handling

- [ ] T044 [P] Vision API 오류 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
  - 개별 사진 분석 실패 시 해당 사진만 건너뛰기
  - 다른 사진 분석은 계속 진행
  - silent failure (사용자 알림 없음)
  - **전체 분석 실패 시 (화면 내 모든 사진 실패) 기능 비활성화처럼 동작** (spec Error Handling)

- [ ] T045 [P] 이미지 로드 실패 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift`
  - 로드 실패 사진은 분석 실패로 처리
  - 유사 사진 그룹에서 제외
  - 에러 로깅만 수행

- [ ] T046 얼굴 감지 실패 폴백 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/FaceDetector.swift`
  - API 오류 시 "얼굴 없음"으로 처리
  - +버튼 미표시, 정상 동작 유지

- [ ] T047 권한 거부 시 기능 비활성화 in `PickPhoto/PickPhoto/Shared/FeatureFlags.swift`
  - PHPhotoLibrary 권한 상태 체크 (`PHPhotoLibrary.authorizationStatus()`)
  - 권한 거부/제한 시 `isSimilarPhotoEnabled` false 반환
  - 기존 앱 권한 요청 UI 따름 (spec System State)

**Checkpoint**: 모든 엣지 케이스 및 시스템 상태 안정적 처리

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: 전체 기능에 걸친 개선 및 마무리

- [ ] T048 [P] 접근성 처리 통합 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`
  - VoiceOver 활성화 체크 통합 (`UIAccessibility.isVoiceOverRunning`)
  - 기능 전체 비활성화 로직 일원화

- [ ] T049 [P] 모션 감소 설정 처리 in `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/BorderAnimationLayer.swift`
  - `UIAccessibility.isReduceMotionEnabled` 체크
  - 정적 테두리로 대체 (흰색 2pt 실선, cornerRadius = 0)

- [ ] T050 [P] 성능 검증 in `PickPhoto/PickPhoto/Features/Grid/GridViewController+SimilarPhoto.swift`
  - 60fps/120fps 스크롤 유지 확인
  - 10개 이상 테두리 동시 표시 시 프레임 드롭 없음
  - Instruments 프로파일링

- [ ] T051 [P] 메모리 누수 검증 in `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`
  - Instruments Leaks 도구로 검증
  - 10분간 기능 사용 후 누수 0건 확인
  - LRU eviction 정상 동작 확인

- [ ] T052 quickstart.md 체크리스트 검증
  - 그리드 테두리 체크리스트 통과
  - 뷰어 +버튼 체크리스트 통과
  - 얼굴 비교 화면 체크리스트 통과

- [ ] T053 코드 정리 및 주석 보강
  - 모든 public 메서드에 상세 주석
  - 복잡한 로직에 인라인 주석
  - CLAUDE.md 코딩 스타일 준수 확인

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    ↓
Phase 2 (Foundational) ← BLOCKS all User Stories
    ↓
┌───────────────────────────────────────────────────────┐
│  Phase 3 (US1: 그리드 테두리) - P1 MVP                 │
│      ↓                                                │
│  Phase 4 (US2: 뷰어 +버튼) - P1                       │
│      ↓                                                │
│  Phase 5 (US3: 얼굴 비교/삭제) - P1                    │
│      ↓                                                │
│  Phase 6 (US4: 토글) - P3                             │
└───────────────────────────────────────────────────────┘
    ↓
Phase 7 (Edge Cases) - Phase 3~6과 병행 가능
    ↓
Phase 8 (Polish)
```

### User Story Dependencies

| User Story | 의존성 | 독립 테스트 |
|------------|--------|------------|
| US1 (그리드 테두리) | Foundational만 | ✅ 스크롤 멈춤 → 테두리 표시 |
| US2 (뷰어 +버튼) | US1 캐시 재사용 | ✅ 뷰어 진입 → +버튼 표시 |
| US3 (얼굴 비교) | US2 +버튼 탭 | ✅ 비교 화면 → 선택 → 삭제 |
| US4 (토글) | US2 +버튼 | ✅ 토글 동작 |

### Within Each User Story

1. Models → Analysis → UI 순서
2. Extension 먼저, 기존 파일 최소 수정
3. 각 User Story 완료 후 독립 테스트

### Parallel Opportunities

- **Phase 2 내부**: T004~T008 (Models) 병렬, T009~T016 (Analysis) 일부 순차
- **Phase 3 내부**: T017 (BorderAnimationLayer) 독립 개발 가능
- **Phase 4 내부**: T022, T023 (UI 컴포넌트) 병렬
- **Phase 7 전체**: Edge Cases (T035~T047) 대부분 병렬

---

## Parallel Example: Phase 2 Models

```bash
# 모든 모델 파일 병렬 생성:
Task: "T004 SimilarityAnalysisState 열거형 생성"
Task: "T005 CachedFace 구조체 생성"
Task: "T006 SimilarThumbnailGroup + ComparisonGroup 구조체 생성"
Task: "T007 FaceMatch 구조체 생성"
Task: "T008 AnalysisRequest 구조체 생성"
```

---

## Implementation Strategy

### MVP First (User Story 1~3)

1. **Phase 1: Setup** → Feature Flag 준비, Xcode 프로젝트 반영
2. **Phase 2: Foundational** → 분석 인프라 완성
3. **Phase 3: US1** → 그리드 테두리 표시 **← 첫 번째 데모 가능**
4. **Phase 4: US2** → 뷰어 +버튼 표시
5. **Phase 5: US3** → 얼굴 비교/삭제 **← MVP 완성**
6. **STOP and VALIDATE**: 전체 플로우 테스트

### Incremental Delivery

1. Setup + Foundational → Foundation 완성
2. US1 완료 → 그리드 테두리 데모 가능
3. US1 + US2 완료 → 뷰어 +버튼 데모 가능
4. US1~US3 완료 → **MVP 릴리즈 가능** (핵심 가치 제공)
5. US4 추가 → 편의 기능 추가
6. Edge Cases + Polish → 프로덕션 품질

### Feature Flag 활용

- 개발 중: `FeatureFlags.isSimilarPhotoEnabled = true`
- 버그 발생 시: `FeatureFlags.isSimilarPhotoEnabled = false` (1줄 수정으로 롤백)
- 단계적 배포: 베타 사용자만 활성화 가능

---

## Notes

- [P] tasks = 다른 파일 작업, 의존성 없음
- [Story] label = User Story 추적용
- 각 User Story는 독립적으로 완성/테스트 가능
- 테스트 실패 전에 구현 확인
- 50줄 이상 수정 시 Git 커밋 (CLAUDE.md 규칙)
- 각 Phase 완료 후 체크포인트에서 검증
- 파일당 2천줄 미만 유지 (필요 시 분할)

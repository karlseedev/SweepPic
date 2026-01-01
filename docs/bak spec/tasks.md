# Tasks: 유사 사진 정리 기능

**Input**: Design documents from `/specs/001-similar-photo/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅
**Algorithm Reference**: [prd8algorithm.md](../../docs/prd8algorithm.md)

**Tests**: 테스트 코드는 명시적 요청 시에만 생성 (이 작업에서는 미포함)

**Organization**: User Story 기준으로 태스크 구성 - 각 스토리 독립적 구현/테스트 가능

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: 병렬 실행 가능 (다른 파일, 의존성 없음)
- **[Story]**: 해당 태스크가 속한 User Story (US1, US2, ...)
- 모든 설명에 정확한 파일 경로 포함

## Path Conventions

- **AppCore** (비즈니스 로직): `Sources/AppCore/`
- **PickPhoto** (UI): `PickPhoto/PickPhoto/`
- **Tests**: `Tests/AppCoreTests/`

---

## Phase 1: Setup (프로젝트 초기화)

**Purpose**: 유사 사진 기능 관련 모델 및 서비스 기본 구조 생성

- [ ] T001 [P] SimilarThumbnailGroup 모델 생성 in `Sources/AppCore/Models/SimilarThumbnailGroup.swift`
  - 유사사진썸네일그룹: assetIdentifiers, anchorAssetIdentifier, isValid (3장 이상)
  - prd8.md §2.1.6 기준: 그리드 테두리/뷰어 버튼 표시용, 분석 범위 내 전체
- [ ] T002 [P] SimilarCleanupGroup 모델 생성 in `Sources/AppCore/Models/SimilarCleanupGroup.swift`
  - 유사사진정리그룹: 최대 8장, 인덱스 거리순 선택 알고리즘 (동일 거리면 앞쪽 우선)
  - prd8.md §2.1.6 유사사진정리그룹 선택 알고리즘 구현
- [ ] T003 [P] FaceRegion 모델 생성 in `Sources/AppCore/Models/FaceRegion.swift`
  - normalizedBoundingBox, sizeRatio (5% 이상), personIndex (1~5), confidence
  - Vision 좌표계 (왼쪽 아래 원점) 명시
- [ ] T004 [P] MatchConfidence enum 생성 in `Sources/AppCore/Models/MatchConfidence.swift`
  - high (<0.6), medium (0.6~1.0), low (>1.0) - prd8algorithm.md §4.4 기준
- [ ] T005 [P] CroppedFace 모델 생성 in `Sources/AppCore/Models/CroppedFace.swift`
  - observation, featurePrint, personIndex, croppedImage
- [ ] T006 [P] FaceMatch 모델 생성 in `Sources/AppCore/Models/FaceMatch.swift`
  - personIndex, faceObservation, featurePrint, distance, confidence
- [ ] T007 [P] ValidationResult 모델 생성 in `Sources/AppCore/Models/ValidationResult.swift`
  - isValid, overallConfidence, mismatchedPhotos, details (PhotoValidation 배열)
- [ ] T008 [P] PersonComparison 모델 생성 in `Sources/AppCore/Models/PersonComparison.swift`
  - personIndex, assetIdentifiers, croppedImages, selectedAssetIdentifiers

**Checkpoint**: 모든 데이터 모델 정의 완료

---

## Phase 2: Foundational (핵심 서비스)

**Purpose**: 모든 User Story에서 공유하는 핵심 서비스 구현

**⚠️ CRITICAL**: 이 Phase 완료 전 User Story 작업 불가

### Vision 기반 서비스

- [ ] T009 SimilarityService 생성 in `Sources/AppCore/Services/SimilarityService.swift`
  - generateFeaturePrint(for:) → VNFeaturePrintObservation (해상도 480x480)
  - calculateDistance(_:_:) → Float (거리)
  - prd8algorithm.md §3.4 기준: 거리 10.0 이하 = 유사
- [ ] T010 SimilarityService에 인접 사진 간 Feature Print 거리 기반 그룹핑 알고리즘 구현
  - calculateAdjacentDistances(featurePrints:) → [Float]
  - groupSimilarPhotos(assets:distances:threshold:) → [[PHAsset]]
  - prd8algorithm.md §3.3 알고리즘 흐름 구현
- [ ] T011 FaceDetectionService 생성 in `Sources/AppCore/Services/FaceDetectionService.swift`
  - detectFaces(in:) → [VNFaceObservation]
  - VNDetectFaceRectanglesRequest 사용
  - Vision 좌표 → UIKit 좌표 변환 (Y축 반전: y = 1 - boundingBox.maxY)
- [ ] T012 FaceDetectionService에 얼굴 필터링 로직 추가
  - filterBySize(observations:viewWidth:minRatio:) → [VNFaceObservation] (5% 이상)
  - selectTopFaces(observations:maxCount:) → [VNFaceObservation] (최대 5개, 크기순)
  - assignPersonIndices(faces:) → [FaceRegion] (위치순 재정렬: 좌→우, 위→아래)
- [ ] T013 FaceDetectionService에 얼굴 크롭 기능 추가
  - cropFaceRegion(from:boundingBox:) → CGImage
  - 30% 여백, 정사각형, 이미지 경계 클램핑
  - prd8algorithm.md §6 얼굴 크롭 규칙 구현

### 인물 매칭 검증 서비스

- [ ] T014 FaceMatchValidator 생성 in `Sources/AppCore/Services/FaceMatchValidator.swift`
  - matchFacesWithFeaturePrint(referenceFaces:targetFaces:) → [FaceMatch]
  - 각 기준 얼굴에 대해 가장 가까운 타겟 얼굴 매칭
  - 거리 기반 신뢰도 결정: <0.6 high, 0.6~1.0 medium, >1.0 low
- [ ] T015 FaceMatchValidator에 검증 기능 추가
  - validatePersonMatching(referencePhoto:referenceFaces:groupPhotos:personIndex:) → ValidationResult
  - 위치 기반 매칭 후 Feature Print 비교로 검증
  - prd8algorithm.md §5 자동 검증 방법 구현

### 상태 관리

- [ ] T016 SimilarPhotoStore 생성 in `Sources/AppCore/Stores/SimilarPhotoStore.swift`
  - @Published state: SimilarPhotoState
  - 유사사진썸네일그룹 판정 조건 구현 (prd8.md §2.1.6):
    1. 현재 사진에 얼굴 1개 이상
    2. 앞뒤 7장 범위 내 거리 10.0 이하 유사 사진 존재
    3. 현재 사진 포함 3장 이상
    4. 얼굴 있는 사진 3장 이상 (필터 후)
- [ ] T017 SimilarPhotoStore에 분석 메서드 추가
  - analyzeVisibleRange(indices:fetchResult:) async → 그리드용 분석
  - analyzeCurrentPhoto(index:fetchResult:) async → 뷰어용 분석
  - 동시 분석 제한: 그리드 5개, 뷰어 3개
- [ ] T018 SimilarPhotoStore에 유사사진정리그룹 생성 로직 추가
  - createCleanupGroup(from:currentIndex:) → SimilarCleanupGroup
  - 최대 8장, 인덱스 거리순 선택 (prd8.md §2.1.6 알고리즘)

**Checkpoint**: Vision 분석, 인물 매칭, 상태 관리 완료 → User Story 구현 가능

---

## Phase 3: User Story 1 - 그리드에서 유사 사진 발견 (Priority: P1) 🎯 MVP

**Goal**: 스크롤 멈춤 시 유사사진썸네일그룹에 빛 회전 테두리 애니메이션 표시

**Independent Test**: 연속 촬영된 얼굴 사진 3장 이상이 포함된 앨범에서 스크롤 후 멈추면 테두리 애니메이션이 표시되는지 확인

### Implementation for User Story 1

- [ ] T019 [US1] SimilarBorderLayer 생성 in `PickPhoto/PickPhoto/Features/Grid/SimilarBorderLayer.swift`
  - CAShapeLayer + CABasicAnimation (strokeStart/strokeEnd)
  - 빛(흰색 그라데이션)이 사각형 테두리를 시계방향으로 회전
  - configure(for:) / stopAnimation() 메서드
- [ ] T020 [US1] SimilarBorderLayer에 접근성 지원 추가
  - UIAccessibility.isReduceMotionEnabled 체크
  - 모션 감소 시 정적 흰색 테두리로 대체 (애니메이션 없음)
- [ ] T021 [US1] PhotoCell에 테두리 레이어 통합 in `PickPhoto/PickPhoto/Features/Grid/PhotoCell.swift`
  - similarBorderLayer: SimilarBorderLayer? 프로퍼티 추가
  - showSimilarBorder() / hideSimilarBorder() 메서드
  - prepareForReuse()에서 hideSimilarBorder() 호출
- [ ] T022 [US1] GridSimilarPhoto 확장 생성 in `PickPhoto/PickPhoto/Features/Grid/GridSimilarPhoto.swift`
  - 스크롤 멈춤 감지 + 0.3초 디바운싱
  - 화면에 보이는 사진 범위 파악 (index N~M)
  - 확장 범위 계산: max(0, N-7) ~ min(총개수-1, M+7)
- [ ] T023 [US1] GridSimilarPhoto에 분석 트리거 로직 추가
  - scrollViewDidEndDecelerating/scrollViewDidEndDragging에서 디바운싱 시작
  - SimilarPhotoStore.analyzeVisibleRange() 호출
  - 스크롤 재시작 시 분석 취소 및 테두리 해제
- [ ] T024 [US1] GridSimilarPhoto에 테두리 표시 로직 추가
  - 유사사진썸네일그룹에 속하는 셀에만 테두리 표시
  - collectionView(_:willDisplay:forItemAt:)에서 조건 확인 후 테두리 적용
  - collectionView(_:didEndDisplaying:forItemAt:)에서 테두리 제거
- [ ] T025 [US1] GridViewController에 GridSimilarPhoto 통합
  - scrollView delegate 연결
  - 테두리 탭 → 해당 사진의 뷰어로 이동 (기존 탭 로직 유지)
- [ ] T026 [US1] VoiceOver 접근성 지원 추가
  - 유사사진 셀에 "유사 사진 있음" accessibilityLabel 추가
  - accessibilityHint로 "탭하여 비교하기" 안내

**Checkpoint**: 그리드에서 스크롤 멈춤 시 테두리 애니메이션 표시, 네이티브 주사율 유지

---

## Phase 4: User Story 2 - 뷰어에서 유사사진정리버튼 표시 (Priority: P1)

**Goal**: 뷰어에서 유사사진썸네일그룹에 속한 사진이면 우측 상단에 버튼 표시

**Independent Test**: 유사 사진 3장 중 하나를 뷰어에서 열면 정리버튼이 표시되는지 확인

### Implementation for User Story 2

- [ ] T027 [US2] ViewerViewController에 유사사진정리버튼 UI 추가
  - iOS 26+: navigationItem.rightBarButtonItem
  - iOS 16~25: FloatingTitleBar에 버튼 추가
  - 아이콘: SF Symbols `square.stack.3d.up`, 반투명 원형 배경
- [ ] T028 [US2] ViewerViewController에 버튼 표시/숨김 로직 추가
  - viewDidAppear에서 SimilarPhotoStore.analyzeCurrentPhoto() 호출
  - 조건 충족 시 버튼 페이드인
  - 스와이프로 다른 사진 이동 시 조건 재평가
- [ ] T029 [US2] 뷰어 사진 스와이프 시 재평가 로직 구현
  - pageViewController(_:didFinishAnimating:) 또는 유사 delegate에서
  - 현재 사진 기준 앞뒤 7장 범위 재분석
  - 조건 미충족 시 버튼 숨김
- [ ] T030 [US2] VoiceOver 접근성 지원 추가
  - 버튼 accessibilityLabel: "유사 사진 N장, 정리하기, 버튼"
  - accessibilityHint: "탭하여 얼굴 비교 시작"

**Checkpoint**: 뷰어에서 조건 충족 시 유사사진정리버튼 표시, 스와이프 시 재평가

---

## Phase 5: User Story 3 - 얼굴 위 + 버튼 표시 (Priority: P2)

**Goal**: 유사사진정리버튼 탭 시 감지된 얼굴 위에 + 버튼 표시

**Independent Test**: 유사사진정리버튼 탭 시 감지된 얼굴마다 + 버튼이 표시되는지 확인

### Implementation for User Story 3

- [ ] T031 [US3] FacePlusButtonOverlay 생성 in `PickPhoto/PickPhoto/Features/Viewer/FacePlusButtonOverlay.swift`
  - UIView 기반 오버레이
  - + 버튼: 반투명 원형 배경 + 아이콘
  - 기본 위치: 얼굴 위 중앙
- [ ] T032 [US3] FacePlusButtonOverlay에 버튼 겹침 처리 알고리즘 추가
  - CGRect intersects로 겹침 감지
  - 이동 순서: 좌→우→아래, 버튼 지름 1.2배씩
  - 최대 4회 시도 후 현재 위치 유지
  - prd8.md §2.4.6 겹침 처리 알고리즘 구현
- [ ] T033 [US3] ViewerViewController에 유사사진정리버튼 탭 핸들러 추가
  - FaceDetectionService.detectFaces() 호출
  - 화면 너비 5% 이상 얼굴만 필터
  - 최대 5개, 크기순 선택 후 위치순 재정렬
- [ ] T034 [US3] ViewerViewController에 + 버튼 오버레이 표시/해제 로직 추가
  - 유사사진정리버튼 재탭: 토글로 닫기
  - 스와이프로 다른 사진 이동: 자동 해제
  - 0.5초 이내 + 버튼 표시 (성능 목표)
- [ ] T035 [US3] + 버튼에 인물 번호 부여 로직 구현
  - 크기순 상위 5개 선택 → 위치순 재정렬 (좌→우, 위→아래)
  - personIndex = 위치 순서
  - prd8.md §2.4.4 인물 번호 부여 순서 구현
- [ ] T036 [US3] VoiceOver 접근성 지원 추가
  - + 버튼 accessibilityLabel: "인물 N 얼굴 비교, 버튼"
  - accessibilityHint: "탭하여 이 인물의 얼굴 비교"

**Checkpoint**: 유사사진정리버튼 탭 시 0.5초 내 + 버튼 표시, 최대 5개, 겹침 처리 정상

---

## Phase 6: User Story 4 - 얼굴 비교 화면에서 정리 (Priority: P2)

**Goal**: 특정 인물의 얼굴만 크롭한 2열 그리드에서 사진 선택 후 삭제

**Independent Test**: 인물 + 버튼 탭 → 얼굴 비교 화면 → 사진 선택 → Delete로 삭제 완료

### Implementation for User Story 4

- [ ] T037 [US4] FaceComparisonViewController 생성 in `PickPhoto/PickPhoto/Features/FaceComparison/FaceComparisonViewController.swift`
  - UICollectionViewController 기반 2열 정사각형 그리드
  - iOS 26+: 시스템 네비바/툴바
  - iOS 16~25: 커스텀 FloatingTitleBar/FloatingTabBar
- [ ] T038 [US4] FaceComparisonViewController 헤더 구현
  - 좌측: ← 뒤로 (Navigation Push 사용)
  - 중앙: "인물 N (M장)"
  - 우측: ↻ 순환 버튼 (arrow.trianglehead.2.clockwise.rotate.90)
- [ ] T039 [US4] FaceComparisonViewController 하단바 구현
  - 좌측: Cancel (흰색 텍스트)
  - 중앙: "N개 선택됨" (전체 선택 사진 수, 인물 무관)
  - 우측: Delete (빨간색, 0개면 비활성화)
  - 기존 FloatingTabBar Select 모드 UI 재사용
- [ ] T040 [US4] FaceCropCell 생성 in `PickPhoto/PickPhoto/Features/FaceComparison/FaceCropCell.swift`
  - 정사각형 비율 얼굴 크롭 이미지 표시
  - 선택 시 체크마크 오버레이 (기존 선택 모드와 동일)
  - 탭으로 선택/해제 토글
- [ ] T041 [US4] FaceCropCell에 경고 배지 추가
  - 우측 하단 ⚠️ 노란색 삼각형
  - 크기: 셀 크기의 약 15%
  - 배경: 반투명 검정 원형
  - 신뢰도 낮음 (거리 > 1.0) 시 표시
- [ ] T042 [US4] MatchWarningBanner 생성 in `PickPhoto/PickPhoto/Features/FaceComparison/MatchWarningBanner.swift`
  - 위치: 얼굴 비교 화면 상단
  - 내용: "⚠️ 인물 매칭 확인 필요 - 일부 사진에서 다른 사람이 포함되었을 수 있습니다"
  - [확인] 버튼 탭 시 닫힘, 개별 배지는 유지
- [ ] T043 [US4] PersonCycleManager 생성 in `PickPhoto/PickPhoto/Features/FaceComparison/PersonCycleManager.swift`
  - 인물 1→2→3→...→1 순환
  - 크로스페이드 애니메이션 0.3초
  - 선택 상태 유지 (사진 기준)
- [ ] T044 [US4] FaceComparisonViewController에 데이터 로딩 로직 추가
  - + 버튼 탭 시 유사사진정리그룹 생성 (최대 8장)
  - 해당 인물의 얼굴 크롭 이미지 생성 (30% 여백, 정사각형)
  - 백그라운드에서 Feature Print 검증 수행
- [ ] T045 [US4] FaceComparisonViewController에 검증 결과 UI 업데이트 로직 추가
  - FaceMatchValidator.validatePersonMatching() 결과 수신
  - 신뢰도 낮음 사진에 경고 배지 표시
  - 1개 이상 발견 시 MatchWarningBanner 표시
- [ ] T046 [US4] Cancel 버튼 동작 구현
  - 선택 체크만 해제 (전체 선택 취소)
  - 얼굴 비교 화면 유지 (다시 선택 가능)
- [ ] T047 [US4] Delete 버튼 동작 구현
  - 선택된 사진들 → TrashStore.moveToTrash(assetIdentifiers:) 호출
  - 얼굴 비교 화면 닫힘 → 뷰어로 복귀
  - 기존 Undo 기능과 동일하게 동작
- [ ] T048 [US4] 뒤로 버튼 동작 구현
  - 얼굴 비교 화면 닫힘 → 뷰어로 복귀
  - + 버튼 오버레이 해제된 상태 (재탭 필요)
- [ ] T049 [US4] VoiceOver 접근성 지원 추가
  - 셀: "사진 N, 선택됨/선택 안됨"
  - 경고 있는 셀: "사진 N, 선택됨/선택 안됨, 인물 매칭 확인 필요"
  - 순환 버튼: "다음 인물, 버튼"
  - 경고 헤더: "인물 매칭 경고, 일부 사진에서 다른 사람이 포함되었을 수 있습니다"
  - 확인 버튼: "확인, 버튼"

**Checkpoint**: 얼굴 비교 화면에서 사진 선택/해제, 인물 순환, Delete/Cancel 정상 동작

---

## Phase 7: User Story 5 - 현재 사진 삭제 후 자동 이동 (Priority: P3)

**Goal**: 얼굴 비교 화면에서 현재 사진 삭제 후 뷰어 복귀 시 적절한 사진으로 이동

**Independent Test**: 현재 사진 삭제 후 뷰어 복귀 시 이전/다음 사진이 표시되는지 확인

### Implementation for User Story 5

- [ ] T050 [US5] FaceComparisonViewController에 삭제 후 복귀 로직 추가
  - 현재 사진(anchor) 삭제 여부 확인
  - 삭제됨 → 이전 사진 인덱스 계산
  - 이전 사진 없으면 → 다음 사진 인덱스 계산
- [ ] T051 [US5] ViewerViewController에 삭제 후 사진 이동 로직 추가
  - FaceComparisonViewController dismiss 시 callback으로 새 인덱스 수신
  - 해당 인덱스로 페이지 전환
  - 기존 뷰어 이동 로직과 통합
- [ ] T052 [US5] 모든 사진 삭제 시 처리 로직 추가
  - 유사사진정리그룹 내 모든 사진 삭제됨
  - 뷰어 닫힘 → 그리드로 복귀
  - NavigationController.popViewController() 또는 dismiss

**Checkpoint**: 삭제 후 이전/다음/그리드 복귀 정상 동작

---

## Phase 8: User Story 6 - 접근성 지원 (Priority: P3)

**Goal**: VoiceOver 및 모션 감소 설정 사용자도 동일하게 기능 사용 가능

**Independent Test**: VoiceOver로 모든 기능에 접근 가능하고 적절한 라벨이 읽히는지 확인

### Implementation for User Story 6

- [ ] T053 [US6] 모션 감소 설정 반응 통합
  - SimilarBorderLayer: 정적 테두리로 대체 (T020에서 구현)
  - FaceComparisonViewController: 인물 순환 애니메이션 최소화
  - NotificationCenter로 UIAccessibility.reduceMotionStatusDidChangeNotification 감지
- [ ] T054 [US6] VoiceOver 라벨 최종 검증 및 보완
  - 모든 화면/버튼/셀에 accessibilityLabel 확인
  - accessibilityTraits 적절성 확인 (.button, .image, .selected 등)
  - accessibilityHint 필요한 곳 보완
- [ ] T055 [US6] VoiceOver 네비게이션 테스트 및 수정
  - 그리드 → 뷰어 → 얼굴 비교 화면 전체 플로우
  - 선택/해제/삭제/순환 모든 동작 VoiceOver로 수행 가능 확인
  - 포커스 순서 적절성 확인

**Checkpoint**: VoiceOver 및 모션 감소 설정에서 모든 기능 정상 동작

---

## Phase 9: Polish & 통합

**Purpose**: 전체 플로우 통합 및 성능 최적화

- [ ] T056 전체 플로우 통합 테스트
  - 그리드 테두리 → 뷰어 버튼 → + 버튼 → 얼굴 비교 → 삭제 → 뷰어 복귀
  - Edge Case: 분석 중 사진 삭제, 빠른 스크롤 반복, 앱 백그라운드 전환
- [ ] T057 [P] 성능 최적화 검증
  - 그리드 스크롤 네이티브 주사율 유지 (60Hz/120Hz)
  - 테두리 10개 동시 표시해도 성능 저하 없음
  - 메모리 누수 없음 (Instruments Leaks 확인)
- [ ] T058 [P] 테두리 애니메이션 최적화
  - didEndDisplaying → 애니메이션 제거
  - prepareForReuse → 테두리 레이어 제거
  - willDisplay → 조건 확인 후 테두리 재적용
- [ ] T059 [P] 코드 정리 및 주석 보완
  - 모든 파일 2000줄 미만 확인
  - 복잡한 알고리즘에 prd8algorithm.md 참조 주석 추가
  - 미사용 코드 제거
- [ ] T060 quickstart.md 검증 수행
  - 수동 테스트 시나리오 전체 수행
  - 성능 테스트 수행 (5만 장 라이브러리)
  - 결과 문서화

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup): 의존성 없음 - 즉시 시작 가능
    │
    ▼
Phase 2 (Foundational): Phase 1 완료 필요 - 모든 User Story 차단
    │
    ▼
Phase 3~8 (User Stories): Phase 2 완료 후 시작 가능
    │
    ▼
Phase 9 (Polish): 모든 User Story 완료 후
```

### User Story Dependencies

| User Story | 의존성 | 독립 테스트 가능 |
|------------|--------|-----------------|
| US1 (그리드 테두리) | Foundational만 | ✅ |
| US2 (뷰어 버튼) | Foundational만 | ✅ |
| US3 (+ 버튼) | US2 필요 (버튼이 트리거) | ✅ (US2와 함께) |
| US4 (얼굴 비교) | US3 필요 (+ 버튼이 트리거) | ✅ (US2,3과 함께) |
| US5 (삭제 후 이동) | US4 필요 | ✅ (US2,3,4와 함께) |
| US6 (접근성) | 모든 US | ✅ (전체와 함께) |

### Within Each Phase

- 모델 → 서비스 → 스토어 순서
- [P] 태스크는 병렬 실행 가능
- 각 Phase 완료 후 Checkpoint에서 검증

### Parallel Opportunities

```bash
# Phase 1: 모든 모델 동시 생성 가능
Task: T001 SimilarThumbnailGroup
Task: T002 SimilarCleanupGroup
Task: T003 FaceRegion
Task: T004 MatchConfidence
Task: T005 CroppedFace
Task: T006 FaceMatch
Task: T007 ValidationResult
Task: T008 PersonComparison

# Phase 9: 최적화/정리 동시 진행 가능
Task: T057 성능 최적화 검증
Task: T058 테두리 애니메이션 최적화
Task: T059 코드 정리
```

---

## Implementation Strategy

### MVP First (User Story 1 + 2 Only)

1. Phase 1: Setup 완료
2. Phase 2: Foundational 완료 (CRITICAL)
3. Phase 3: US1 (그리드 테두리) 완료
4. Phase 4: US2 (뷰어 버튼) 완료
5. **STOP and VALIDATE**: 그리드/뷰어에서 유사 사진 발견 기능 테스트
6. Deploy/demo if ready

### Incremental Delivery

1. Setup + Foundational → 기반 완성
2. + US1 → 그리드 테두리 (테스트 가능)
3. + US2 → 뷰어 버튼 (테스트 가능)
4. + US3 → + 버튼 (테스트 가능)
5. + US4 → 얼굴 비교 화면 (핵심 가치 실현!)
6. + US5 → 삭제 후 UX 개선
7. + US6 → 접근성 완성

### 추천 MVP 범위

**US1 + US2 + US3 + US4** = 핵심 가치 실현
- 유사 사진 발견 (그리드/뷰어)
- 얼굴 비교 및 삭제

---

## Notes

- [P] 태스크 = 다른 파일, 의존성 없음 → 병렬 실행 가능
- [US#] 라벨 = 해당 User Story에 매핑
- 모든 파일 2000줄 미만 유지 (CLAUDE.md 규칙)
- 알고리즘 복잡한 부분은 prd8algorithm.md 참조 주석 필수
- 각 Phase 완료 후 Checkpoint에서 독립 테스트 수행
- Git 규칙: 50줄 이상 수정 전 커밋, Phase 전후 커밋

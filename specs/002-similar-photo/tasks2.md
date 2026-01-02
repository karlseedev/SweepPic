# Tasks: 유사 사진 정리 기능

**Input**: `specs/002-similar-photo/spec.md`, `specs/002-similar-photo/plan.md`, `specs/002-similar-photo/research.md`, `specs/002-similar-photo/data-model.md`  
**Prerequisites**: plan.md, spec.md  
**Tests**: 스펙에 테스트 요구사항이 명시되지 않아 본 문서에는 포함하지 않음

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 가능 (서로 다른 파일, 의존 없음)
- **[Story]**: US1/US2/US3/US4 또는 SHARED

---

## Phase 1: Setup (Shared Infrastructure)

- [ ] T001 [SHARED] `PickPhoto/PickPhoto/Features/SimilarPhoto/` 모듈 디렉토리 생성 및 Xcode 프로젝트 반영
- [ ] T002 [P] [SHARED] 모델 생성: `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/CachedFace.swift`
- [ ] T003 [P] [SHARED] 모델 생성: `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/SimilarThumbnailGroup.swift`
- [ ] T004 [P] [SHARED] 모델 생성: `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/ComparisonGroup.swift`
- [ ] T005 [P] [SHARED] 상태/요청 모델 생성: `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/SimilarityAnalysisState.swift`, `PickPhoto/PickPhoto/Features/SimilarPhoto/Models/AnalysisRequest.swift`

---

## Phase 2: Foundational (Blocking Prerequisites)

- [ ] T006 [SHARED] 캐시 구현: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift` (상태, 그룹, CachedFace, LRU, completion handler)
- [ ] T007 [P] [SHARED] 분석 큐/동시성 제어 구현: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift` (FIFO, 동시 5개, thermal 상태 2개 제한)
- [ ] T008 [P] [SHARED] 이미지 로더 유틸리티: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift` (긴 변 480px, aspectFit, 패딩/크롭 금지)
- [ ] T009 [SHARED] 분석 타임아웃/취소 처리: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift` (3초 초과 실패 처리)

---

## Phase 3: User Story 1 - 그리드에서 유사 사진 발견 (P1) 🎯

**Goal**: 스크롤 멈춤 시 유사사진 분석을 수행하고, 조건을 만족하는 셀에 테두리를 표시한다.

**Independent Test**: 스크롤 멈춤 후 1초 이내 테두리 표시 여부 확인.

- [ ] T010 [US1] 스크롤 멈춤/디바운싱 구현: `PickPhoto/PickPhoto/Features/Grid/GridViewController.swift`
- [ ] T011 [P] [US1] Feature Print 생성 및 인접 거리 계산: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T012 [P] [US1] 얼굴 감지 및 5% 유효 얼굴 필터: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/FaceDetector.swift`
- [ ] T013 [US1] 유효 인물 슬롯 계산 + 그룹 유효성 검증 + CachedFace 생성: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T014 [P] [US1] 테두리 애니메이션 레이어 구현: `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/BorderAnimationLayer.swift`
- [ ] T015 [US1] 셀 라이프사이클 테두리 적용/해제: `PickPhoto/PickPhoto/Features/Grid/GridViewController.swift` (willDisplay/didEndDisplaying/prepareForReuse)

---

## Phase 4: User Story 2 - 뷰어에서 얼굴 비교 진입 (P1) 🎯

**Goal**: 유사사진 뷰어에서 +버튼 오버레이를 표시하고, 캐시 상태에 맞춰 동작한다.

**Independent Test**: 캐시 hit/miss 상황에서 +버튼 표시 및 notAnalyzed 분석 요청 확인.

- [ ] T020 [US2] 뷰어 상태 확인 및 분석 요청/구독: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`
- [ ] T021 [P] [US2] 좌표 변환 + 얼굴 위 +버튼 배치: `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T022 [P] [US2] +버튼 겹침 이동 로직 구현: `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T023 [US2] 분석 중 로딩 인디케이터 표시: `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/AnalysisLoadingIndicator.swift`, `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`

---

## Phase 5: User Story 3 - 얼굴 비교 및 삭제 (P1) 🎯

**Goal**: 얼굴 비교 화면에서 2열 그리드로 비교하고, 선택 삭제를 앱 내 휴지통으로 이동한다.

**Independent Test**: +버튼 탭 → 비교 화면 → 선택 삭제 후 뷰어 복귀 확인.

- [ ] T030 [US3] 비교 그룹 선택 알고리즘 구현: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/ComparisonGroupBuilder.swift`
- [ ] T031 [US3] 얼굴 크롭 유틸 구현: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/FaceCropper.swift` (30% 여백, 정사각형 유지 + 경계 내 최대 축소)
- [ ] T032 [US3] 얼굴 비교 화면 UI 구현: `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T033 [US3] +버튼 탭 → 비교 화면 전환 및 personIndex 전달: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`
- [ ] T034 [US3] 선택/해제 및 헤더 M장 계산: `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T035 [US3] 삭제 처리 + 캐시 갱신: `PickPhoto/PickPhoto/Stores/TrashStore.swift`, `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`

---

## Phase 6: User Story 4 - 오버레이 토글 (P3)

**Goal**: 뷰어에서 +버튼 오버레이를 숨김/보임으로 전환한다.

**Independent Test**: eye/eye.slash 토글과 스와이프 복귀 시 보임 리셋 확인.

- [ ] T040 [US4] 토글 버튼 UI/상태 구현: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`
- [ ] T041 [US4] 스와이프 이동 시 토글 상태 리셋: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`

---

## Phase 7: Cross-Cutting Concerns

- [ ] T050 [P] [SHARED] VoiceOver/모션 감소 대응: `PickPhoto/PickPhoto/Features/Grid/GridViewController.swift`, `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`, `PickPhoto/PickPhoto/Features/SimilarPhoto/UI/BorderAnimationLayer.swift`
- [ ] T051 [P] [SHARED] 시스템 상태 처리(메모리 경고/백그라운드/thermal): `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift`, `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
- [ ] T052 [P] [SHARED] 사진 라이브러리 변경 처리 및 캐시 무효화: `PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityCache.swift` 또는 기존 Observer 위치
- [ ] T053 [P] [SHARED] 회전/윈도우 크기 변경 시 +버튼 위치 재계산: `PickPhoto/PickPhoto/Features/Viewer/ViewerViewController.swift`

---

## Dependencies & Execution Order

- **Phase 1 → Phase 2** 완료 후 사용자 스토리 작업 시작
- **US1 → US2/US3/US4**: 그리드 분석/캐시가 있어야 뷰어/비교 화면이 동작
- **US3**는 US2의 +버튼 오버레이 연동 필요
- **Cross-Cutting**은 각 스토리 구현 이후에 통합 적용

# Tasks: 유사 사진 정리 기능

**Input**: Design documents from `/specs/002-similar-photo/`
**Prerequisites**: plan.md ✅, spec.md ✅, research.md ✅, data-model.md ✅, quickstart.md ✅

**Tests**: 테스트는 명시적 요청 없으므로 포함하지 않음

**Organization**: User Story별로 그룹화하여 독립적 구현 및 테스트 가능

## Format: `[ID] [P?] [Story] Description`

- **[P]**: 병렬 실행 가능 (다른 파일, 의존성 없음)
- **[Story]**: User Story 소속 (US1, US2, US3, US4)
- 정확한 파일 경로 포함

## Path Conventions

- **iOS App**: `PickPhoto/PickPhoto/` 기준
- **신규 모듈**: `Features/SimilarPhoto/{Analysis,UI,Models}/`
- **기존 수정**: `Features/Grid/`, `Features/Viewer/`, `Stores/`

---

## Phase 1: Setup (프로젝트 구조)

**Purpose**: Feature Flag 및 SimilarPhoto 모듈 디렉토리 생성

- [ ] T000 FeatureFlags.swift 생성 - `isSimilarPhotoEnabled` 플래그 정의, **권한 거부 시 기능 비활성화 체크 포함** (spec System State) in `PickPhoto/PickPhoto/Shared/FeatureFlags.swift`
- [ ] T001 SimilarPhoto 모듈 디렉토리 구조 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/{Analysis,UI,Models}/`

---

## Phase 2: Foundational (핵심 인프라)

**Purpose**: 모든 User Story가 의존하는 핵심 분석 엔진 및 캐시

**⚠️ CRITICAL**: User Story 작업 전 반드시 완료해야 함

### 데이터 모델 (T002~T006)

- [ ] T002 [P] SimilarityAnalysisState 열거형 생성 in `Features/SimilarPhoto/Models/SimilarityAnalysisState.swift`
- [ ] T003 [P] CachedFace 구조체 생성 in `Features/SimilarPhoto/Models/CachedFace.swift`
- [ ] T004 [P] SimilarThumbnailGroup + ComparisonGroup 구조체 생성 in `Features/SimilarPhoto/Models/SimilarPhotoGroup.swift`
- [ ] T005 [P] AnalysisRequest 구조체 생성 - **source 필드 포함 (grid/viewer 구분)** (prd9 §2.2.4) in `Features/SimilarPhoto/Models/AnalysisRequest.swift`
- [ ] T006 [P] FaceMatch 구조체 생성 in `Features/SimilarPhoto/Models/FaceMatch.swift`

### 분석 엔진 - 유틸리티 (T007~T009)

- [ ] T007 [P] SimilarityImageLoader 생성 - PHImageManager 480px aspectFit 이미지 로딩 in `Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift`
- [ ] T008 [P] FaceCropper 생성 - bounding box + 30% 여백 + 정사각형 크롭 in `Features/SimilarPhoto/Analysis/FaceCropper.swift`
- [ ] T009 [P] SimilarityAnalysisQueue 생성 - FIFO 큐, 동시 5개(과열 시 2개), 취소 처리, **source=viewer 요청은 스크롤 시 취소 제외** (prd9 §2.2.4) in `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`

### 분석 엔진 - 핵심 (T010~T012)

- [ ] T010 SimilarityAnalyzer 생성 - VNGenerateImageFeaturePrintRequest 유사도 분석, **임계값 10.0 적용** (FR-002, prd9 §2.1.2) in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T011 FaceDetector 생성 - VNDetectFaceRectanglesRequest 얼굴 감지, 5% 필터 in `Features/SimilarPhoto/Analysis/FaceDetector.swift`
- [ ] T012 SimilarityCache 생성 - LRU 500장, 상태 관리, 완료 콜백, **분석 중(analyzing) 사진은 eviction 대상 제외** (spec Edge Case) in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

### 시스템 상태 처리 (T013~T015)

- [ ] T013 [P] 메모리 경고 시 캐시 50% LRU 제거 + 과열 시 동시 분석 제한 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`, `SimilarityAnalysisQueue.swift`
- [ ] T014 [P] 백그라운드 전환 시 분석 취소 in `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
- [ ] T015 [P] PHPhotoLibraryChangeObserver 연동 - 캐시 무효화 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

**Checkpoint**: 분석 엔진 완료 - User Story 구현 가능

### 얼굴 필터링 및 그룹 유효성 (T016~T019) - PRD 요구사항

- [ ] T016 [US1] 얼굴 감지 + 5% 필터 + 인물 번호 부여 - FaceDetector를 그리드 분석 파이프라인에 연결, 화면 너비 5% 이상 얼굴만 유효, 좌→우/위→아래 순서로 인물 번호 부여 (FR-004, FR-019) in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T017 [US1] 유효 인물 슬롯 계산 + CachedFace.isValidSlot 업데이트 - 동일 인물이 2장 이상 감지된 슬롯만 유효 (FR-005) in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`, `Features/SimilarPhoto/Models/CachedFace.swift`
- [ ] T018 [US1] 그룹 필터링 + 캐시 상태 갱신 - 유효 얼굴 3장 이상 + 유효 슬롯 1개 이상 조건 충족 시만 그룹 활성화, 미충족 그룹은 analyzed(inGroup:false)로 상태 갱신 (FR-003, FR-005) in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`, `Features/SimilarPhoto/Analysis/SimilarityCache.swift`
- [ ] T019 [US1] 범위 겹침 시 그룹 병합 - 동일 사진이 여러 그룹에 속하지 않도록 중복 그룹 방지 (spec Edge Case) in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`

---

## Phase 3: User Story 1 - 그리드에서 유사 사진 발견 (Priority: P1) 🎯 MVP

**Goal**: 그리드 스크롤 멈춤 시 유사 사진에 테두리 애니메이션 표시

**Independent Test**: 그리드에서 스크롤 후 멈추면 유사 사진에 테두리가 표시되는지 확인

### UI 컴포넌트 (T020~T021)

- [ ] T020 [P] [US1] BorderAnimationLayer 생성 - CAShapeLayer + 빛 도는 애니메이션 (흰색 그라데이션, 시계방향 회전, 1.5초 주기) + 모션 감소 시 정적 테두리(흰색 2pt) + **모든 셀 동일 위상 동기화** (FR-007) in `Features/SimilarPhoto/UI/BorderAnimationLayer.swift`

### GridViewController 통합 (T021~T026)

- [ ] T021 [US1] GridViewController+SimilarPhoto.swift Extension 생성 + 스크롤 멈춤 감지 + 0.3초 디바운싱 + 분석 범위 결정 (화면 ±7장) in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T022 [US1] SimilarityAnalyzer 호출 및 결과 처리 + 유사 사진 셀에 BorderAnimationLayer 적용 in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T023 [US1] 스크롤 재개 시 분석 취소 + 테두리 제거, **source=grid인 요청만 취소** (prd9 §2.2.4) in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T024 [US1] 테두리 있는 사진 탭 시 뷰어 이동 처리 in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T025 [US1] VoiceOver/선택 모드/휴지통 화면 + FeatureFlags 체크 in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T026 [US1] 셀 라이프사이클 테두리 적용/해제 - **willDisplay에서 캐시 조회 후 재적용, didEndDisplaying/prepareForReuse에서 제거** (prd9 §2.2.5) in `Features/Grid/GridViewController+SimilarPhoto.swift`

**Checkpoint**: 그리드 테두리 표시 완료 - 독립 테스트 가능

---

## Phase 4: User Story 2 - 뷰어에서 얼굴 비교 진입 (Priority: P1) 🎯 MVP

**Goal**: 유사 사진 뷰어에서 얼굴 +버튼 표시 및 얼굴 비교 화면 진입

**Independent Test**: 유사 사진 뷰어에서 + 버튼 표시 및 탭으로 얼굴 비교 화면 진입 테스트 가능

### UI 컴포넌트 (T030~T031)

- [ ] T030 [P] [US2] FaceButtonOverlay 생성 - Vision→UIKit 좌표 변환, 얼굴 위치에 + 버튼 표시, 겹침 방지, 최대 5개 (6개 이상 시 크기순), 인물 번호 부여 (좌→우, 위→아래), **유효 슬롯(isValidSlot=true)인 얼굴만 +버튼 표시, 얼굴 없으면 +버튼 미표시** (FR-020, spec Edge Case) in `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T031 [P] [US2] AnalysisLoadingIndicator 생성 - 분석 중 로딩 표시 in `Features/SimilarPhoto/UI/AnalysisLoadingIndicator.swift`

### ViewerViewController 통합 (T032~T035)

- [ ] T032 [US2] ViewerViewController+SimilarPhoto.swift Extension 생성 + 캐시 hit 시 +버튼 즉시 표시 (100ms 이내) in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T033 [US2] 캐시 miss(notAnalyzed) 시 분석 요청 - **그리드에 분석 요청 (현재 ±7장), notAnalyzed만 분석, 분석 완료 후 범위 내 그룹 재계산, CachedFace.isValidSlot 갱신** (prd9 §2.3.1) + 로딩 인디케이터 + 완료 후 +버튼 표시 (0.5초 이내) in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T034 [US2] 화면 회전/iPad 멀티윈도우 시 +버튼 위치 재계산 (viewWillTransition) in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T035 [US2] +버튼 탭 시 FaceComparisonViewController 표시 in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`

**Checkpoint**: 뷰어 +버튼 표시 완료 - 독립 테스트 가능

---

## Phase 5: User Story 3 - 얼굴 비교 및 삭제 (Priority: P1) 🎯 MVP

**Goal**: 얼굴 비교 화면에서 동일 인물 얼굴 비교 및 사진 삭제

**Independent Test**: 얼굴 비교 화면에서 사진 선택 후 삭제하여 휴지통 이동 테스트 가능

### FaceComparisonViewController (T040~T046)

- [ ] T040 [US3] FaceComparisonViewController 생성 - 2열 정사각형 그리드 레이아웃 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T041 [US3] ComparisonGroupBuilder 생성 - Feature Print 비교(거리 1.0 기준) + 거리순 최대 8장 선택 알고리즘 (FR-028~FR-030) in `Features/SimilarPhoto/Analysis/ComparisonGroupBuilder.swift`
- [ ] T042 [US3] +버튼 탭 시 ComparisonGroupBuilder 호출 + 로딩 스피너 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T043 [US3] FaceCropper로 얼굴 크롭 + 2열 그리드 표시 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T044 [US3] 헤더 "인물 N (M장)" + 순환 버튼(↻) 구현 - 인물 번호 오름차순 원형 순환, 선택 상태 유지 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T045 [US3] 사진 탭 선택/해제 + 체크마크 + 하단바 (Cancel, 선택 개수, Delete) in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T046 [US3] Delete 탭 시 TrashStore로 이동 + 뷰어 복귀 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

### 삭제 후 처리 (T047~T049)

- [ ] T047 [US3] 현재 사진 삭제 시 이전/다음 사진 이동 + 모든 사진 삭제 시 그리드 복귀 in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T048 [US3] 그룹 멤버 3장 미만 시 그룹 무효화 + 테두리/+버튼 제거, **삭제 후 즉시 재분석하지 않고 다음 스크롤 멈춤 시 자동 재분석** (spec Gesture & Layout) in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`
- [ ] T049 [US3] Undo 기능 통합 - 기존 TrashStore와 동일 in `Stores/TrashStore.swift`

**Checkpoint**: 얼굴 비교 및 삭제 완료 - 핵심 MVP 완성

---

## Phase 6: User Story 4 - 오버레이 토글 (Priority: P3)

**Goal**: 뷰어에서 +버튼 오버레이 숨김/보임 전환

**Independent Test**: 토글 버튼으로 + 버튼 숨김/보임 전환 테스트 가능

- [ ] T050 [US4] eye/eye.slash 토글 버튼 + 상태 관리 + 스와이프 복귀 시 보임 리셋 in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`

**Checkpoint**: 오버레이 토글 완료

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 성능 최적화 및 품질 개선

### 성능 검증 (T060~T062)

- [ ] T060 [P] 그리드 60fps/120fps(ProMotion) + 테두리 1초 이내 표시 검증 in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T061 [P] +버튼 탭 후 0.5초 이내 얼굴 비교 화면 표시 검증 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T062 [P] 캐시 메모리 누수 검증 (Instruments Leaks) in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

### 에러 처리 (T063~T065)

- [ ] T063 [P] Vision API 오류/이미지 로드 실패/얼굴 감지 실패 시 silent failure 처리 - 해당 사진은 분석 실패로 처리하고 그룹에서 제외, 다른 사진 분석은 계속 진행, **전체 분석 실패 시 기능 비활성화처럼 동작** (spec Error Handling) in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`, `Features/SimilarPhoto/Analysis/FaceDetector.swift`
- [ ] T064 [P] 분석 타임아웃 3초 구현 in `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
- [ ] T065 [P] 권한 거부 시 기능 비활성화 - PHPhotoLibrary 권한 체크, 기존 앱 권한 요청 UI 따름 (spec System State) in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`, `Shared/FeatureFlags.swift`

### quickstart.md 검증 (T066)

- [ ] T066 quickstart.md 기능 테스트 체크리스트 수행

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: 의존성 없음 - 즉시 시작
- **Phase 2 (Foundational)**: Phase 1 완료 후 - 모든 User Story 블로킹
- **Phase 3-6 (User Stories)**: Phase 2 완료 후 시작 가능
  - US1, US2, US3은 모두 P1 (MVP)
  - US4는 P3 (편의 기능)
- **Phase 7 (Polish)**: 모든 User Story 완료 후

### User Story Dependencies

```
Phase 2 (Foundational)
       │
       ├──▶ US1 (그리드 테두리) ──▶ US2 (뷰어 +버튼) ──▶ US3 (얼굴 비교/삭제)
       │                                                         │
       └──────────────────────────────────────────────▶ US4 (오버레이 토글)
```

- **US1**: Phase 2 완료 후 즉시 시작
- **US2**: US1 완료 후 (그리드에서 뷰어로 진입 필요)
- **US3**: US2 완료 후 (+버튼에서 얼굴 비교 화면 진입)
- **US4**: Phase 2 완료 후 (US2와 병렬 가능하나, US2 UI 필요)

### Parallel Opportunities

**Phase 2 병렬 실행 가능:**
```
T002~T006 (모든 모델)
T007~T009 (유틸리티)
T013~T015 (시스템 상태)
```

**US1/US2 병렬 실행 가능:**
```
T020 (BorderAnimationLayer)
T030, T031 (FaceButtonOverlay, AnalysisLoadingIndicator)
```

**Phase 7 병렬 실행 가능:**
```
T060~T065 (성능/에러 처리)
```

---

## Implementation Strategy

### MVP First (US1 + US2 + US3)

1. Phase 1: Setup 완료
2. Phase 2: Foundational 완료 (CRITICAL)
3. Phase 3: US1 완료 → 그리드 테두리 검증
4. Phase 4: US2 완료 → 뷰어 +버튼 검증
5. Phase 5: US3 완료 → 얼굴 비교/삭제 검증
6. **MVP 완성** - 핵심 가치 제공 가능

### Incremental Delivery

1. Setup + Foundational → 기반 완료
2. US1 → 그리드 테두리 (발견)
3. US2 → 뷰어 +버튼 (진입)
4. US3 → 얼굴 비교 (삭제) **← MVP**
5. US4 → 오버레이 토글 (편의)
6. Polish → 성능/품질 개선

---

## Notes

- [P] 태스크 = 다른 파일, 의존성 없음
- [Story] 라벨 = 특정 User Story 소속
- 각 User Story는 독립적으로 완료 및 테스트 가능
- 태스크 또는 논리적 그룹 완료 후 커밋
- 50줄 이상 수정 시 사전 커밋 (CLAUDE.md 규칙)
- Checkpoint에서 독립 검증 가능

---

## Summary

| 항목 | 수량 |
|------|------|
| **총 태스크** | 52개 |
| Phase 1 (Setup) | 2개 |
| Phase 2 (Foundational) | 18개 (T002~T019) |
| US1 (그리드 테두리) | 11개 (T016~T019 + T020~T026) |
| US2 (뷰어 +버튼) | 6개 |
| US3 (얼굴 비교/삭제) | 10개 |
| US4 (오버레이 토글) | 1개 |
| Phase 7 (Polish) | 8개 |
| **병렬 가능 태스크** | 18개 |
| **MVP 범위** | Phase 1~5 (43개 태스크) |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2026-01-02 | 초안 생성 (63개 태스크) |
| 1.1 | 2026-01-02 | 파일 구조 개선 (SimilarityAnalysisQueue, SimilarityImageLoader, FaceCropper 분리), 태스크 병합 (46개로 축소), 태스크 번호 그룹화 (T0xx, T02x, T03x...) |
| 1.2 | 2026-01-03 | Feature Flag 추가 (T000), Extension 파일 분리 (GridViewController+SimilarPhoto.swift, ViewerViewController+SimilarPhoto.swift), 총 45개 태스크 |
| 1.3 | 2026-01-04 | PRD 요구사항 누락 보완 - T016~T019 추가 (얼굴 5% 필터 FR-004, 인물 번호 FR-019, 유효 슬롯 FR-005, 그룹 병합), T026 추가 (셀 라이프사이클), T063 확장 (얼굴 감지 실패 처리), T041 ComparisonGroupBuilder 분리 (Analysis/), 총 50개 태스크 |
| 1.4 | 2026-01-04 | **전체 롤백 및 누락 요구사항 보완** - 모든 체크 해제, 9개 누락 항목 반영: (1) T010 임계값 10.0 명시, (2) T020 테두리 위상 동기화, (3) T030 유효 슬롯/얼굴 없음 시 미표시, (4) T033 notAnalyzed 분석 상세 규칙, (5) T009/T023 viewer 요청 취소 제외, (6) T012 분석 중 eviction 제외, (7) T063 전체 분석 실패 처리, (8) T000/T065 권한 거부 처리, (9) T048 삭제 후 재분석 타이밍. 총 52개 태스크 |

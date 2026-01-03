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

- [ ] T000 FeatureFlags.swift 생성 - `isSimilarPhotoEnabled` 플래그 정의 in `PickPhoto/PickPhoto/Shared/FeatureFlags.swift`
- [ ] T001 SimilarPhoto 모듈 디렉토리 구조 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/{Analysis,UI,Models}/`

---

## Phase 2: Foundational (핵심 인프라)

**Purpose**: 모든 User Story가 의존하는 핵심 분석 엔진 및 캐시

**⚠️ CRITICAL**: User Story 작업 전 반드시 완료해야 함

### 데이터 모델 (T002~T006)

- [ ] T002 [P] SimilarityAnalysisState 열거형 생성 in `Features/SimilarPhoto/Models/SimilarityAnalysisState.swift`
- [ ] T003 [P] CachedFace 구조체 생성 in `Features/SimilarPhoto/Models/CachedFace.swift`
- [ ] T004 [P] SimilarThumbnailGroup + ComparisonGroup 구조체 생성 in `Features/SimilarPhoto/Models/SimilarPhotoGroup.swift`
- [ ] T005 [P] AnalysisRequest 구조체 생성 in `Features/SimilarPhoto/Models/AnalysisRequest.swift`
- [ ] T006 [P] FaceMatch 구조체 생성 in `Features/SimilarPhoto/Models/FaceMatch.swift`

### 분석 엔진 - 유틸리티 (T007~T009)

- [ ] T007 [P] SimilarityImageLoader 생성 - PHImageManager 480px aspectFit 이미지 로딩 in `Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift`
- [ ] T008 [P] FaceCropper 생성 - bounding box + 30% 여백 + 정사각형 크롭 in `Features/SimilarPhoto/Analysis/FaceCropper.swift`
- [ ] T009 [P] SimilarityAnalysisQueue 생성 - FIFO 큐, 동시 5개(과열 시 2개), 취소 처리 in `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`

### 분석 엔진 - 핵심 (T010~T012)

- [ ] T010 SimilarityAnalyzer 생성 - VNGenerateImageFeaturePrintRequest 유사도 분석 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T011 FaceDetector 생성 - VNDetectFaceRectanglesRequest 얼굴 감지, 5% 필터 in `Features/SimilarPhoto/Analysis/FaceDetector.swift`
- [ ] T012 SimilarityCache 생성 - LRU 500장, 상태 관리, 완료 콜백 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

### 시스템 상태 처리 (T013~T015)

- [ ] T013 [P] 메모리 경고 시 캐시 50% LRU 제거 + 과열 시 동시 분석 제한 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`, `SimilarityAnalysisQueue.swift`
- [ ] T014 [P] 백그라운드 전환 시 분석 취소 in `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`
- [ ] T015 [P] PHPhotoLibraryChangeObserver 연동 - 캐시 무효화 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

**Checkpoint**: 분석 엔진 완료 - User Story 구현 가능

---

## Phase 3: User Story 1 - 그리드에서 유사 사진 발견 (Priority: P1) 🎯 MVP

**Goal**: 그리드 스크롤 멈춤 시 유사 사진에 테두리 애니메이션 표시

**Independent Test**: 그리드에서 스크롤 후 멈추면 유사 사진에 테두리가 표시되는지 확인

### UI 컴포넌트 (T020~T021)

- [ ] T020 [P] [US1] BorderAnimationLayer 생성 - CAShapeLayer + 빛 도는 애니메이션 (흰색 그라데이션, 시계방향 회전, 1.5초 주기) + 모션 감소 시 정적 테두리(흰색 2pt) in `Features/SimilarPhoto/UI/BorderAnimationLayer.swift`

### GridViewController 통합 (T021~T025)

- [ ] T021 [US1] GridViewController+SimilarPhoto.swift Extension 생성 + 스크롤 멈춤 감지 + 0.3초 디바운싱 + 분석 범위 결정 (화면 ±7장) in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T022 [US1] SimilarityAnalyzer 호출 및 결과 처리 + 유사 사진 셀에 BorderAnimationLayer 적용 in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T023 [US1] 스크롤 재개 시 분석 취소 + 테두리 제거 in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T024 [US1] 테두리 있는 사진 탭 시 뷰어 이동 처리 in `Features/Grid/GridViewController+SimilarPhoto.swift`
- [ ] T025 [US1] VoiceOver/선택 모드/휴지통 화면 + FeatureFlags 체크 in `Features/Grid/GridViewController+SimilarPhoto.swift`

**Checkpoint**: 그리드 테두리 표시 완료 - 독립 테스트 가능

---

## Phase 4: User Story 2 - 뷰어에서 얼굴 비교 진입 (Priority: P1) 🎯 MVP

**Goal**: 유사 사진 뷰어에서 얼굴 +버튼 표시 및 얼굴 비교 화면 진입

**Independent Test**: 유사 사진 뷰어에서 + 버튼 표시 및 탭으로 얼굴 비교 화면 진입 테스트 가능

### UI 컴포넌트 (T030~T031)

- [ ] T030 [P] [US2] FaceButtonOverlay 생성 - Vision→UIKit 좌표 변환, 얼굴 위치에 + 버튼 표시, 겹침 방지, 최대 5개 (6개 이상 시 크기순), 인물 번호 부여 (좌→우, 위→아래) in `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T031 [P] [US2] AnalysisLoadingIndicator 생성 - 분석 중 로딩 표시 in `Features/SimilarPhoto/UI/AnalysisLoadingIndicator.swift`

### ViewerViewController 통합 (T032~T035)

- [ ] T032 [US2] ViewerViewController+SimilarPhoto.swift Extension 생성 + 캐시 hit 시 +버튼 즉시 표시 (100ms 이내) in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T033 [US2] 캐시 miss 시 분석 요청 + 로딩 인디케이터 + 완료 후 +버튼 표시 (0.5초 이내) in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T034 [US2] 화면 회전/iPad 멀티윈도우 시 +버튼 위치 재계산 (viewWillTransition) in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T035 [US2] +버튼 탭 시 FaceComparisonViewController 표시 in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`

**Checkpoint**: 뷰어 +버튼 표시 완료 - 독립 테스트 가능

---

## Phase 5: User Story 3 - 얼굴 비교 및 삭제 (Priority: P1) 🎯 MVP

**Goal**: 얼굴 비교 화면에서 동일 인물 얼굴 비교 및 사진 삭제

**Independent Test**: 얼굴 비교 화면에서 사진 선택 후 삭제하여 휴지통 이동 테스트 가능

### FaceComparisonViewController (T040~T046)

- [ ] T040 [US3] FaceComparisonViewController 생성 - 2열 정사각형 그리드 레이아웃 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T041 [US3] ComparisonGroup 생성 알고리즘 - 거리순 최대 8장 선택 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T042 [US3] +버튼 탭 시 Feature Print 비교 (거리 1.0 기준) + 로딩 스피너 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T043 [US3] FaceCropper로 얼굴 크롭 + 2열 그리드 표시 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T044 [US3] 헤더 "인물 N (M장)" + 순환 버튼(↻) 구현 - 인물 번호 오름차순 원형 순환, 선택 상태 유지 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T045 [US3] 사진 탭 선택/해제 + 체크마크 + 하단바 (Cancel, 선택 개수, Delete) in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T046 [US3] Delete 탭 시 TrashStore로 이동 + 뷰어 복귀 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

### 삭제 후 처리 (T047~T049)

- [ ] T047 [US3] 현재 사진 삭제 시 이전/다음 사진 이동 + 모든 사진 삭제 시 그리드 복귀 in `Features/Viewer/ViewerViewController+SimilarPhoto.swift`
- [ ] T048 [US3] 그룹 멤버 3장 미만 시 그룹 무효화 + 테두리/+버튼 제거 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`
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

### 에러 처리 (T063~T064)

- [ ] T063 [P] Vision API 오류/이미지 로드 실패 시 silent failure 처리 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T064 [P] 분석 타임아웃 3초 구현 in `Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`

### quickstart.md 검증 (T065)

- [ ] T065 quickstart.md 기능 테스트 체크리스트 수행

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
T060~T064 (성능/에러 처리)
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
| **총 태스크** | 47개 |
| Phase 1 (Setup) | 2개 |
| Phase 2 (Foundational) | 14개 |
| US1 (그리드 테두리) | 6개 |
| US2 (뷰어 +버튼) | 6개 |
| US3 (얼굴 비교/삭제) | 10개 |
| US4 (오버레이 토글) | 1개 |
| Phase 7 (Polish) | 6개 |
| **병렬 가능 태스크** | 18개 |
| **MVP 범위** | US1 + US2 + US3 (37개 태스크) |

---

## 변경 이력

| 버전 | 날짜 | 변경 내용 |
|------|------|----------|
| 1.0 | 2026-01-02 | 초안 생성 (63개 태스크) |
| 1.1 | 2026-01-02 | 파일 구조 개선 (SimilarityAnalysisQueue, SimilarityImageLoader, FaceCropper 분리), 태스크 병합 (46개로 축소), 태스크 번호 그룹화 (T0xx, T02x, T03x...) |
| 1.2 | 2026-01-03 | Feature Flag 추가 (T000), Extension 파일 분리 (GridViewController+SimilarPhoto.swift, ViewerViewController+SimilarPhoto.swift), 총 47개 태스크 |

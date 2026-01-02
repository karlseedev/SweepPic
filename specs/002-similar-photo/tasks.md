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

**Purpose**: SimilarPhoto 모듈 디렉토리 생성 및 기본 구조

- [ ] T001 SimilarPhoto 모듈 디렉토리 구조 생성 in `PickPhoto/PickPhoto/Features/SimilarPhoto/{Analysis,UI,Models}/`

---

## Phase 2: Foundational (핵심 인프라)

**Purpose**: 모든 User Story가 의존하는 핵심 분석 엔진 및 캐시

**⚠️ CRITICAL**: User Story 작업 전 반드시 완료해야 함

### 데이터 모델

- [ ] T002 [P] SimilarityAnalysisState 열거형 생성 in `Features/SimilarPhoto/Models/SimilarityAnalysisState.swift`
- [ ] T003 [P] CachedFace 구조체 생성 in `Features/SimilarPhoto/Models/CachedFace.swift`
- [ ] T004 [P] SimilarThumbnailGroup 구조체 생성 in `Features/SimilarPhoto/Models/SimilarPhotoGroup.swift`
- [ ] T005 [P] ComparisonGroup 구조체 생성 in `Features/SimilarPhoto/Models/SimilarPhotoGroup.swift`
- [ ] T006 [P] AnalysisRequest 구조체 생성 in `Features/SimilarPhoto/Models/AnalysisRequest.swift`
- [ ] T007 [P] FaceMatch 구조체 생성 in `Features/SimilarPhoto/Models/FaceMatch.swift`

### 분석 엔진

- [ ] T008 SimilarityAnalyzer 클래스 생성 - VNGenerateImageFeaturePrintRequest 기반 유사도 분석 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T009 FaceDetector 클래스 생성 - VNDetectFaceRectanglesRequest 기반 얼굴 감지 in `Features/SimilarPhoto/Analysis/FaceDetector.swift`
- [ ] T010 SimilarityCache 클래스 생성 - LRU 캐시 (500장), 메모리 경고 처리, 과열 동시성 제한 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

### 시스템 상태 처리

- [ ] T011 메모리 경고 시 캐시 50% LRU 제거 구현 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`
- [ ] T012 디바이스 과열 시 동시 분석 5개→2개 제한 구현 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T013 백그라운드 전환 시 분석 취소 구현 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T014 PHPhotoLibraryChangeObserver 연동 - 캐시 무효화 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

**Checkpoint**: 분석 엔진 완료 - User Story 구현 가능

---

## Phase 3: User Story 1 - 그리드에서 유사 사진 발견 (Priority: P1) 🎯 MVP

**Goal**: 그리드 스크롤 멈춤 시 유사 사진에 테두리 애니메이션 표시

**Independent Test**: 그리드에서 스크롤 후 멈추면 유사 사진에 테두리가 표시되는지 확인

### UI 컴포넌트

- [ ] T015 [P] [US1] BorderAnimationLayer 생성 - CAShapeLayer + 빛 도는 애니메이션 (흰색 그라데이션, 시계방향 회전, 1.5초 주기) in `Features/SimilarPhoto/UI/BorderAnimationLayer.swift`
- [ ] T016 [P] [US1] 정적 테두리 대체 구현 - 모션 감소 설정 시 흰색 2pt 실선 in `Features/SimilarPhoto/UI/BorderAnimationLayer.swift`

### GridViewController 통합

- [ ] T017 [US1] 스크롤 멈춤 감지 + 0.3초 디바운싱 구현 in `Features/Grid/GridViewController.swift`
- [ ] T018 [US1] 분석 범위 결정 (화면 내 사진 ±7장) 로직 구현 in `Features/Grid/GridViewController.swift`
- [ ] T019 [US1] SimilarityAnalyzer 호출 및 결과 처리 in `Features/Grid/GridViewController.swift`
- [ ] T020 [US1] 유사 사진 셀에 BorderAnimationLayer 적용 in `Features/Grid/GridViewController.swift`
- [ ] T021 [US1] 스크롤 재개 시 분석 취소 + 테두리 제거 in `Features/Grid/GridViewController.swift`
- [ ] T022 [US1] 테두리 있는 사진 탭 시 뷰어 이동 처리 in `Features/Grid/GridViewController.swift`

### 접근성 처리

- [ ] T023 [US1] VoiceOver 활성화 시 기능 비활성화 체크 in `Features/Grid/GridViewController.swift`
- [ ] T024 [US1] 선택 모드일 때 기능 비활성화 체크 in `Features/Grid/GridViewController.swift`

**Checkpoint**: 그리드 테두리 표시 완료 - 독립 테스트 가능

---

## Phase 4: User Story 2 - 뷰어에서 얼굴 비교 진입 (Priority: P1) 🎯 MVP

**Goal**: 유사 사진 뷰어에서 얼굴 +버튼 표시 및 얼굴 비교 화면 진입

**Independent Test**: 유사 사진 뷰어에서 + 버튼 표시 및 탭으로 얼굴 비교 화면 진입 테스트 가능

### UI 컴포넌트

- [ ] T025 [P] [US2] FaceButtonOverlay 생성 - 얼굴 위치에 + 버튼 표시 (최대 5개) in `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T026 [P] [US2] AnalysisLoadingIndicator 생성 - 분석 중 로딩 표시 in `Features/SimilarPhoto/UI/AnalysisLoadingIndicator.swift`

### ViewerViewController 통합

- [ ] T027 [US2] 캐시 hit 시 +버튼 즉시 표시 (100ms 이내) in `Features/Viewer/ViewerViewController.swift`
- [ ] T028 [US2] 캐시 miss 시 분석 요청 + 로딩 인디케이터 표시 in `Features/Viewer/ViewerViewController.swift`
- [ ] T029 [US2] 분석 완료 후 +버튼 표시 (0.5초 이내) in `Features/Viewer/ViewerViewController.swift`
- [ ] T030 [US2] Vision 좌표 → UIKit 좌표 변환 구현 in `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T031 [US2] +버튼 겹침 방지 위치 조정 로직 in `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T032 [US2] 6개 이상 얼굴 시 크기순 상위 5개 선택 로직 in `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`
- [ ] T033 [US2] 인물 번호 부여 (좌→우, 위→아래 순) in `Features/SimilarPhoto/UI/FaceButtonOverlay.swift`

### 화면 회전/멀티윈도우

- [ ] T034 [US2] 화면 회전 시 +버튼 위치 재계산 (viewWillTransition) in `Features/Viewer/ViewerViewController.swift`
- [ ] T035 [US2] iPad 멀티윈도우 지원 - 윈도우 크기 변경 시 +버튼 위치 재계산 in `Features/Viewer/ViewerViewController.swift`

**Checkpoint**: 뷰어 +버튼 표시 완료 - 독립 테스트 가능

---

## Phase 5: User Story 3 - 얼굴 비교 및 삭제 (Priority: P1) 🎯 MVP

**Goal**: 얼굴 비교 화면에서 동일 인물 얼굴 비교 및 사진 삭제

**Independent Test**: 얼굴 비교 화면에서 사진 선택 후 삭제하여 휴지통 이동 테스트 가능

### FaceComparisonViewController

- [ ] T036 [US3] FaceComparisonViewController 생성 - 2열 정사각형 그리드 레이아웃 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T037 [US3] ComparisonGroup 생성 - 거리순 최대 8장 선택 알고리즘 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T038 [US3] 헤더 "인물 N (M장)" 표시 구현 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T039 [US3] 얼굴 크롭 구현 - bounding box + 30% 여백 + 정사각형 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T040 [US3] 사진 탭 선택/해제 + 체크마크 표시 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

### 인물 순환

- [ ] T041 [US3] 순환 버튼(↻) 구현 - 인물 번호 오름차순, 원형 순환 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T042 [US3] 인물 전환 시 선택 상태 유지 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

### Feature Print 인물 매칭

- [ ] T043 [US3] +버튼 탭 시 Feature Print 비교로 동일 인물 필터링 (거리 1.0 기준) in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T044 [US3] FaceMatch 경고 표시 (거리 >= 1.0) in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

### 하단바 및 삭제

- [ ] T045 [US3] 하단바 구현 - Cancel, 선택 개수, Delete 버튼 (FloatingTabBar 재사용) in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T046 [US3] Delete 탭 시 TrashStore로 사진 이동 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T047 [US3] 삭제 후 뷰어 복귀 처리 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`

### 삭제 후 그룹 처리

- [ ] T048 [US3] 현재 사진 삭제 시 이전 사진으로 이동 (없으면 다음) in `Features/Viewer/ViewerViewController.swift`
- [ ] T049 [US3] 모든 사진 삭제 시 뷰어 닫고 그리드 복귀 in `Features/Viewer/ViewerViewController.swift`
- [ ] T050 [US3] 그룹 멤버 3장 미만 시 그룹 무효화 + 테두리/+버튼 제거 in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`
- [ ] T051 [US3] Undo 기능 통합 - 기존 TrashStore Undo와 동일 in `Stores/TrashStore.swift`

**Checkpoint**: 얼굴 비교 및 삭제 완료 - 핵심 MVP 완성

---

## Phase 6: User Story 4 - 오버레이 토글 (Priority: P3)

**Goal**: 뷰어에서 +버튼 오버레이 숨김/보임 전환

**Independent Test**: 토글 버튼으로 + 버튼 숨김/보임 전환 테스트 가능

- [ ] T052 [US4] eye/eye.slash 토글 버튼 구현 in `Features/Viewer/ViewerViewController.swift`
- [ ] T053 [US4] +버튼 숨김/보임 상태 관리 in `Features/Viewer/ViewerViewController.swift`
- [ ] T054 [US4] 다른 사진으로 스와이프 후 복귀 시 보임 상태 리셋 in `Features/Viewer/ViewerViewController.swift`

**Checkpoint**: 오버레이 토글 완료

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: 성능 최적화 및 품질 개선

### 성능 최적화

- [ ] T055 [P] 그리드 스크롤 60fps/120fps(ProMotion) 유지 검증 in `Features/Grid/GridViewController.swift`
- [ ] T056 [P] 테두리 표시 1초 이내 성능 검증 in `Features/SimilarPhoto/UI/BorderAnimationLayer.swift`
- [ ] T057 [P] +버튼 탭 후 0.5초 이내 얼굴 비교 화면 표시 검증 in `Features/SimilarPhoto/UI/FaceComparisonViewController.swift`
- [ ] T058 [P] 캐시 메모리 누수 검증 (Instruments Leaks) in `Features/SimilarPhoto/Analysis/SimilarityCache.swift`

### 에러 처리

- [ ] T059 [P] Vision API 오류 시 silent failure 처리 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T060 [P] 이미지 로드 실패 시 분석 스킵 처리 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`
- [ ] T061 [P] 분석 타임아웃 3초 구현 in `Features/SimilarPhoto/Analysis/SimilarityAnalyzer.swift`

### 휴지통 제외

- [ ] T062 휴지통 화면에서 기능 비활성화 체크 in `Features/Grid/GridViewController.swift`

### quickstart.md 검증

- [ ] T063 quickstart.md 기능 테스트 체크리스트 수행

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

### Within Each User Story

- UI 컴포넌트 먼저 생성
- ViewController 통합
- 접근성/예외 처리

### Parallel Opportunities

**Phase 2 병렬 실행 가능:**
```
T002, T003, T004, T005, T006, T007 (모든 모델)
```

**US1 병렬 실행 가능:**
```
T015, T016 (BorderAnimationLayer)
```

**US2 병렬 실행 가능:**
```
T025, T026 (FaceButtonOverlay, AnalysisLoadingIndicator)
```

**Phase 7 병렬 실행 가능:**
```
T055, T056, T057, T058 (성능 검증)
T059, T060, T061 (에러 처리)
```

---

## Parallel Example: Phase 2 Models

```bash
# 모든 모델을 동시에 생성:
Task: "SimilarityAnalysisState 열거형 생성 in Features/SimilarPhoto/Models/SimilarityAnalysisState.swift"
Task: "CachedFace 구조체 생성 in Features/SimilarPhoto/Models/CachedFace.swift"
Task: "SimilarThumbnailGroup 구조체 생성 in Features/SimilarPhoto/Models/SimilarPhotoGroup.swift"
Task: "ComparisonGroup 구조체 생성 in Features/SimilarPhoto/Models/SimilarPhotoGroup.swift"
Task: "AnalysisRequest 구조체 생성 in Features/SimilarPhoto/Models/AnalysisRequest.swift"
Task: "FaceMatch 구조체 생성 in Features/SimilarPhoto/Models/FaceMatch.swift"
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
| **총 태스크** | 63개 |
| Phase 1 (Setup) | 1개 |
| Phase 2 (Foundational) | 13개 |
| US1 (그리드 테두리) | 10개 |
| US2 (뷰어 +버튼) | 11개 |
| US3 (얼굴 비교/삭제) | 16개 |
| US4 (오버레이 토글) | 3개 |
| Phase 7 (Polish) | 9개 |
| **병렬 가능 태스크** | 23개 |
| **MVP 범위** | US1 + US2 + US3 (50개 태스크) |

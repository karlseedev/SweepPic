# Tasks: 저품질 사진 자동 정리

**Input**: `/specs/001-auto-cleanup/` 설계 문서
**Prerequisites**: plan.md (required), spec.md (required), data-model.md, contracts/cleanup-service.md, research.md, quickstart.md
**Created**: 2026-01-22

---

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: 병렬 실행 가능 (파일 충돌 없음, 의존성 없음)
- **[Story]**: 해당 User Story (US1, US2, US3)
- 모든 파일 경로는 정확한 위치 포함

## Path Conventions

- **Models**: `PickPhoto/PickPhoto/Features/AutoCleanup/Models/`
- **Analysis**: `PickPhoto/PickPhoto/Features/AutoCleanup/Analysis/`
- **Services**: `PickPhoto/PickPhoto/Features/AutoCleanup/Services/`
- **UI**: `PickPhoto/PickPhoto/Features/AutoCleanup/UI/`
- **Tests**: `PickPhoto/PickPhotoTests/AutoCleanup/`

---

## Phase 1: Setup (프로젝트 구조)

**Purpose**: AutoCleanup 기능 디렉토리 구조 생성

- [x] T001 `PickPhoto/PickPhoto/Features/AutoCleanup/` 폴더 구조 생성 (Models/, Analysis/, Services/, UI/, Debug/)
- [x] T002 [P] `PickPhoto/PickPhotoTests/AutoCleanup/` 테스트 폴더 구조 생성
- [x] T003 [P] CleanupConstants.swift 상수 정의 파일 생성 (`PickPhoto/PickPhoto/Features/AutoCleanup/CleanupConstants.swift`)

**Checkpoint**: 폴더 구조 준비 완료

---

## Phase 2: Foundational (기반 모델 + Store)

**Purpose**: 모든 User Story가 의존하는 핵심 데이터 모델 및 저장소

**⚠️ CRITICAL**: 이 Phase 완료 전까지 User Story 구현 불가

### Models

- [x] T004 [P] CleanupMethod enum 정의 (fromLatest, continueFromLast, byYear) in `Models/CleanupMethod.swift`
- [x] T005 [P] JudgmentMode enum 정의 (precision, recall) in `Models/JudgmentMode.swift`
- [x] T006 [P] SessionStatus enum 정의 (idle, scanning, paused, completed, cancelled) in `Models/SessionStatus.swift`
- [x] T007 [P] QualitySignal 모델 정의 (SignalType, SignalKind, QualitySignal struct) in `Models/QualitySignal.swift`
- [x] T008 CleanupSession 모델 정의 (Codable, 세션 상태 관리) in `Models/CleanupSession.swift` (depends on T004, T005, T006)
- [x] T009 [P] QualityResult 모델 정의 (QualityVerdict, SkipReason, SafeGuardReason, AnalysisMethod) in `Models/QualityResult.swift`
- [x] T010 [P] CleanupResult 모델 정의 (CleanupResultType, EndReason) in `Models/CleanupResult.swift`
- [x] T011 [P] CleanupProgress 모델 정의 (진행 상황 콜백용) in `Models/CleanupProgress.swift`
- [x] T012 [P] CleanupError enum 정의 in `Models/CleanupError.swift`
- [x] T013 [P] AnalysisError enum 정의 in `Models/AnalysisError.swift`

### Session Store

- [x] T014 CleanupSessionStoreProtocol 프로토콜 정의 in `Services/CleanupSessionStoreProtocol.swift` (depends on T008)
- [x] T015 CleanupSessionStore 구현 (파일 기반 JSON 저장/로드) in `Services/CleanupSessionStore.swift` (depends on T014)

### Unit Tests - Models

- [x] T016 [P] CleanupSession 모델 테스트 (Codable 인코딩/디코딩, 상태 전이) in `PickPhoto/PickPhotoTests/AutoCleanup/Models/CleanupSessionTests.swift`
- [x] T017 [P] QualitySignal 모델 테스트 in `PickPhoto/PickPhotoTests/AutoCleanup/Models/QualitySignalTests.swift`
- [x] T018 [P] CleanupSessionStore 테스트 (저장/로드/삭제) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupSessionStoreTests.swift`

### PHAsset Extension

- [x] T019 PHAsset+Cleanup extension 구현 (shouldSkipForCleanup, isLowResolution, isLongVideo) in `Models/PHAsset+Cleanup.swift`

**Checkpoint**: 기반 모델 준비 완료 - User Story 구현 가능

---

## Phase 3: Analysis Pipeline (분석 파이프라인)

**Purpose**: 저품질 판정을 위한 분석 모듈 구현 - 모든 User Story가 공유

### Analysis Protocols

- [x] T020 [P] ExposureAnalyzerProtocol 정의 in `Analysis/Protocols/ExposureAnalyzerProtocol.swift`
- [x] T021 [P] BlurAnalyzerProtocol 정의 in `Analysis/Protocols/BlurAnalyzerProtocol.swift`
- [x] T022 [P] SafeGuardProtocol 정의 in `Analysis/Protocols/SafeGuardProtocol.swift`
- [x] T023 [P] AestheticsAnalyzerProtocol 정의 (iOS 18+) in `Analysis/Protocols/AestheticsAnalyzerProtocol.swift`
- [x] T024 QualityAnalyzerProtocol 정의 in `Analysis/Protocols/QualityAnalyzerProtocol.swift` (depends on T020-T023)

### Exposure Analyzer (Stage 2)

- [x] T025 ExposureAnalyzer 구현 - 휘도 계산 (ITU-R BT.601) in `Analysis/ExposureAnalyzer.swift` (depends on T020)
- [x] T026 ExposureAnalyzer - RGB 표준편차 계산 추가 in `Analysis/ExposureAnalyzer.swift` (depends on T025)
- [x] T027 ExposureAnalyzer - 비네팅 계산 추가 (3x3 그리드) in `Analysis/ExposureAnalyzer.swift` (depends on T026)
- [x] T028 [P] ExposureAnalyzer 테스트 (극단 어두움/밝음, 단색 감지) in `PickPhoto/PickPhotoTests/AutoCleanup/Analysis/ExposureAnalyzerTests.swift`

### Blur Analyzer (Stage 3)

- [x] T029 BlurAnalyzer 구현 - Metal 초기화 (MTLDevice, MPSImageLaplacian) in `Analysis/BlurAnalyzer.swift` (depends on T021)
- [x] T030 BlurAnalyzer - Laplacian Variance 계산 구현 in `Analysis/BlurAnalyzer.swift` (depends on T029)
- [x] T031 BlurAnalyzer - 256x256 다운샘플링 및 결과 반환 in `Analysis/BlurAnalyzer.swift` (depends on T030)
- [x] T032 [P] BlurAnalyzer 테스트 (심각 블러/일반 블러 감지) in `PickPhoto/PickPhotoTests/AutoCleanup/Analysis/BlurAnalyzerTests.swift`

### Safe Guard (Stage 4)

- [x] T033 SafeGuard 구현 - 심도 효과 감지 (PHAsset depthData 확인) in `Analysis/SafeGuard.swift` (depends on T022)
- [x] T034 SafeGuard - 얼굴 품질 감지 (VNDetectFaceCaptureQualityRequest) in `Analysis/SafeGuard.swift` (depends on T033)
- [x] T035 [P] SafeGuard 테스트 (블러 판정 무효화 케이스) in `PickPhoto/PickPhotoTests/AutoCleanup/Analysis/SafeGuardTests.swift`

### Aesthetics Analyzer (iOS 18+)

- [x] T036 AestheticsAnalyzer 구현 (CalculateImageAestheticsScoresRequest) in `Analysis/AestheticsAnalyzer.swift` (depends on T023)
- [x] T037 AestheticsAnalyzer - 실패 시 fallback 반환 처리 in `Analysis/AestheticsAnalyzer.swift` (depends on T036)

### Quality Analyzer (코디네이터)

- [x] T038 QualityAnalyzer 구현 - iOS 버전별 분기 로직 in `Analysis/QualityAnalyzer.swift` (depends on T024, T025, T029, T033, T036)
- [x] T039 QualityAnalyzer - Precision 모드 Strong 신호 판정 in `Analysis/QualityAnalyzer.swift` (depends on T038)
- [x] T040 QualityAnalyzer - 배치 분석 (analyzeBatch) 구현 in `Analysis/QualityAnalyzer.swift` (depends on T039)
- [x] T041 QualityAnalyzer Integration 테스트 (전체 파이프라인 통합) in `PickPhoto/PickPhotoTests/AutoCleanup/Analysis/QualityAnalyzerIntegrationTests.swift` (depends on T040)

**Checkpoint**: 분석 파이프라인 완료 - 서비스 레이어 구현 가능

---

## Phase 4: User Story 1 - 최신 사진부터 정리 (Priority: P1) 🎯 MVP

**Goal**: 정리 버튼 → 최신사진부터 정리 → 휴지통 이동 → 결과 표시

**Independent Test**: 정리 버튼 탭 후 "최신사진부터 정리" 선택 시 저품질 사진이 휴지통으로 이동됨

### Service Layer

- [x] T042 [US1] CleanupServiceProtocol 정의 in `Services/CleanupServiceProtocol.swift`
- [x] T043 [US1] CleanupService 구현 - 휴지통 비어있는지 확인 in `Services/CleanupService.swift` (depends on T042)
- [x] T044 [US1] CleanupService - fromLatest 방식 탐색 로직 (최신→오래된 순) in `Services/CleanupService.swift` (depends on T043)
- [x] T045 [US1] CleanupService - 종료 조건 구현 (50장 찾음, 1000장 검색, 범위 끝) in `Services/CleanupService.swift` (depends on T044)
- [x] T046 [US1] CleanupService - 배치 처리 (100장 단위) 및 동시성 제어 (4개) in `Services/CleanupService.swift` (depends on T045)
- [x] T047 [US1] CleanupService - TrashStore 연동 (휴지통 이동) in `Services/CleanupService.swift` (depends on T046)
- [x] T048 [US1] CleanupService - 진행 상황 콜백 (progressHandler) in `Services/CleanupService.swift` (depends on T047)
- [x] T049 [US1] CleanupService - 취소 처리 (아무것도 이동하지 않음) in `Services/CleanupService.swift` (depends on T048)

### UI Components

- [x] T050 [P] [US1] CleanupButton 컴포넌트 구현 in `UI/CleanupButton.swift` (GridViewController+Cleanup.swift에 통합)
- [x] T051 [P] [US1] CleanupMethodSheet - 정리 방식 선택 시트 (최신사진부터/이어서/연도별) in `UI/CleanupMethodSheet.swift`
- [x] T052 [P] [US1] CleanupProgressView - 탐색 진행 UI (진행바, 찾은 수, 취소 버튼) in `UI/CleanupProgressView.swift`
- [x] T053 [P] [US1] CleanupResultAlert - 결과 알림 (N장 이동/0장 발견/취소) in `UI/CleanupResultAlert.swift`
- [x] T054 [P] [US1] TrashNotEmptyAlert - 휴지통 비어있지 않음 알림 in `UI/TrashNotEmptyAlert.swift`

### GridViewController 통합

- [x] T055 [US1] GridViewController에 CleanupButton 추가 (셀렉트 버튼 왼쪽) in `Features/Grid/GridViewController+Cleanup.swift` (depends on T050)
- [x] T056 [US1] GridViewController - 정리 버튼 탭 핸들러 구현 in `Features/Grid/GridViewController+Cleanup.swift` (depends on T055, T051)
- [x] T057 [US1] GridViewController - 정리 진행/결과 UI 연동 in `Features/Grid/GridViewController+Cleanup.swift` (depends on T056, T052, T053, T054)

### Tests for US1

- [x] T058 [P] [US1] CleanupService Unit 테스트 (fromLatest 탐색, 종료 조건) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceTests.swift`
- [x] T059 [US1] CleanupService Integration 테스트 (전체 정리 플로우) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceIntegrationTests.swift` (depends on T049)

**Checkpoint**: User Story 1 완료 - 최신 사진부터 정리 기능 독립 테스트 가능

---

## Phase 5: User Story 2 - 연도별 정리 (Priority: P2)

**Goal**: 특정 연도의 사진만 선택적으로 정리

**Independent Test**: "연도별 정리 > 2024"를 선택하면 2024년 사진만 분석되어 정리됨

### Service Extension

- [ ] T060 [US2] CleanupService - byYear 방식 탐색 로직 (선택 연도만) in `Services/CleanupService.swift`
- [ ] T061 [US2] CleanupService - 연도 범위 끝에서 확장 없이 종료 in `Services/CleanupService.swift` (depends on T060)
- [ ] T062 [US2] CleanupService - 연도 기준 PHFetchOptions 쿼리 구성 in `Services/CleanupService.swift` (depends on T061)

### UI Extension

- [ ] T063 [US2] CleanupMethodSheet - 연도 선택 하위 메뉴 추가 (PHAsset에서 연도 목록 추출) in `UI/CleanupMethodSheet.swift` (depends on T051)
- [ ] T064 [US2] CleanupProgressView - 연도 표시 ("2024년 5월부터 탐색 중...") in `UI/CleanupProgressView.swift` (depends on T063)

### Tests for US2

- [ ] T065 [P] [US2] byYear 탐색 Unit 테스트 (범위 제한, 확장 없이 종료) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceByYearTests.swift`
- [ ] T066 [US2] 연도별 정리 Integration 테스트 in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceByYearIntegrationTests.swift` (depends on T062)

**Checkpoint**: User Story 2 완료 - 연도별 정리 기능 독립 테스트 가능

---

## Phase 6: User Story 3 - 이어서 정리 (Priority: P2)

**Goal**: 이전 정리 위치부터 계속 정리 진행

**Independent Test**: 첫 번째 정리 후 "이어서 정리"를 선택하면 마지막 탐색 위치부터 계속됨

### Service Extension

- [ ] T067 [US3] CleanupService - continueFromLast 방식 탐색 로직 in `Services/CleanupService.swift`
- [ ] T068 [US3] CleanupService - 세션 저장/로드 연동 (lastAssetDate, lastAssetID 활용) in `Services/CleanupService.swift` (depends on T067, T015)
- [ ] T069 [US3] CleanupService - 이전 이력 없으면 에러 반환 in `Services/CleanupService.swift` (depends on T068)

### UI Extension

- [ ] T070 [US3] CleanupMethodSheet - "이어서 정리" 옵션 활성화/비활성화 로직 in `UI/CleanupMethodSheet.swift` (depends on T068)
- [ ] T071 [US3] CleanupMethodSheet - 이전 세션 정보 표시 ("2024년 5월부터 계속") in `UI/CleanupMethodSheet.swift` (depends on T070)

### Tests for US3

- [ ] T072 [P] [US3] continueFromLast 탐색 Unit 테스트 (세션 연속성 확인) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceContinueTests.swift`
- [ ] T073 [US3] 이어서 정리 Integration 테스트 (세션 저장 후 재개) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceContinueIntegrationTests.swift` (depends on T069)

**Checkpoint**: User Story 3 완료 - 이어서 정리 기능 독립 테스트 가능

---

## Phase 7: User Story 5 - 휴지통 복구 확인 (Priority: P1)

**Goal**: 기존 TrashStore 복구 기능이 자동 정리와 호환되는지 확인

**Independent Test**: 자동 정리로 이동된 사진이 휴지통에서 정상 복구됨

### Integration Verification

- [ ] T074 [US5] TrashStore 복구 API 확인 및 문서화 in `Services/CleanupService.swift` (주석으로 연동 방식 기술)
- [ ] T075 [US5] TrashStore Integration 테스트 (자동 정리 → 복구 플로우) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/TrashStoreIntegrationTests.swift`

**Checkpoint**: User Story 5 확인 완료 - 복구 플로우 정상 동작

---

## Phase 8: 특수 케이스 처리

**Purpose**: 비디오, Live Photo, Burst, RAW+JPEG 등 특수 미디어 처리

### Video Analysis

- [ ] T076 [P] VideoFrameExtractor 구현 (AVAssetImageGenerator로 프레임 3개 추출) in `Analysis/VideoFrameExtractor.swift`
- [ ] T077 VideoFrameExtractor - 10분 초과/iCloud 전용 비디오 SKIP 처리 in `Analysis/VideoFrameExtractor.swift` (depends on T076)
- [ ] T078 QualityAnalyzer - 비디오 분석 통합 (3개 중 2개 이상 저품질 = LOW_QUALITY) in `Analysis/QualityAnalyzer.swift` (depends on T077)

### Live Photo / Burst / RAW

- [ ] T079 [P] PHAsset+Cleanup - Live Photo 처리 (정지 이미지만 분석) in `Models/PHAsset+Cleanup.swift`
- [ ] T080 [P] PHAsset+Cleanup - Burst 처리 (대표 사진만, PHFetchResult 기본 동작 활용) in `Models/PHAsset+Cleanup.swift`
- [ ] T081 [P] PHAsset+Cleanup - RAW+JPEG 처리 (JPEG로 분석) in `Models/PHAsset+Cleanup.swift`

### Tests for Special Media

- [ ] T082 [P] 비디오 분석 테스트 (프레임 추출, 중앙값 판정) in `PickPhoto/PickPhotoTests/AutoCleanup/Analysis/VideoAnalysisTests.swift`
- [ ] T083 [P] 특수 미디어 처리 테스트 (Live Photo, Burst, RAW) in `PickPhoto/PickPhotoTests/AutoCleanup/Analysis/SpecialMediaTests.swift`

**Checkpoint**: 특수 미디어 처리 완료

---

## Phase 9: 백그라운드 + 에러 처리

**Purpose**: 백그라운드 전환, 에러 상황 처리

### Background Handling

- [ ] T084 CleanupService - 백그라운드 전환 시 일시정지 (pauseCleanup) in `Services/CleanupService.swift`
- [ ] T085 CleanupService - 포그라운드 복귀 시 자동 재개 (resumeCleanup) in `Services/CleanupService.swift` (depends on T084)
- [ ] T086 CleanupService - 앱 종료 시 상태 초기화 (진행 상태 소실) in `Services/CleanupService.swift` (depends on T085)

### Error Handling

- [ ] T087 CleanupService - 분석 실패 시 SKIP 처리 (삭제 금지) in `Services/CleanupService.swift`
- [ ] T088 CleanupService - iCloud 썸네일 없음 SKIP 처리 in `Services/CleanupService.swift` (depends on T087)
- [ ] T089 CleanupService - Metal 초기화 실패 시 전체 정리 중단 in `Services/CleanupService.swift` (depends on T088)

### Tests

- [ ] T090 [P] 백그라운드 전환 테스트 (일시정지/재개) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceBackgroundTests.swift`
- [ ] T091 [P] 에러 처리 테스트 (SKIP, 중단 케이스) in `PickPhoto/PickPhotoTests/AutoCleanup/Services/CleanupServiceErrorTests.swift`

**Checkpoint**: 안정성 처리 완료

---

## Phase 10: Polish & Cross-Cutting

**Purpose**: 디버그 기능, 성능 최적화, 최종 검증

### Debug Utilities

- [ ] T092 [P] CleanupDebug 구현 (분석 로그, 임계값 오버라이드) in `Debug/CleanupDebug.swift`

### Performance Optimization

- [ ] T093 성능 프로파일링 및 배치 크기/동시성 튜닝 (1000장 30초 목표) in `Services/CleanupService.swift`
- [ ] T094 메모리 최적화 (autoreleasepool, 이미지 다운샘플링 확인) in `Analysis/QualityAnalyzer.swift`

### Final Validation

- [ ] T095 quickstart.md 시나리오 검증 (전체 플로우 E2E 테스트) in `PickPhoto/PickPhotoTests/AutoCleanup/E2E/CleanupE2ETests.swift`
- [ ] T096 실기기 테스트 (iOS 18 AestheticsScore, Metal 성능) - Manual Test
- [ ] T097 코드 정리 및 주석 보완

**Checkpoint**: 기능 완료 - 출시 준비 완료

---

## Dependencies & Execution Order

### Phase Dependencies

```
Phase 1 (Setup)
    └──▶ Phase 2 (Foundational) ← BLOCKS ALL
              └──▶ Phase 3 (Analysis Pipeline) ← BLOCKS USER STORIES
                        │
                        ├──▶ Phase 4 (US1: 최신 사진부터) 🎯 MVP
                        ├──▶ Phase 5 (US2: 연도별)
                        ├──▶ Phase 6 (US3: 이어서)
                        └──▶ Phase 7 (US5: 복구 확인)
                                    │
                                    ├──▶ Phase 8 (특수 케이스)
                                    └──▶ Phase 9 (백그라운드 + 에러)
                                              │
                                              └──▶ Phase 10 (Polish)
```

### User Story Dependencies

- **US1 (P1)**: Phase 3 완료 후 시작 가능 - 다른 Story 의존 없음
- **US2 (P2)**: Phase 3 완료 후 시작 가능 - US1 부분 의존 (CleanupService 기반)
- **US3 (P2)**: Phase 3 완료 후 시작 가능 - US1 부분 의존 (CleanupService 기반)
- **US5 (P1)**: Phase 4 완료 후 확인 - 기존 TrashStore 활용

### Parallel Opportunities

**Phase 2 내:**
```
T004, T005, T006, T007, T009, T010, T011, T012, T013 (병렬)
    └──▶ T008 (depends on T004, T005, T006)
              └──▶ T014, T015, T016, T017, T018, T019
```

**Phase 3 내:**
```
T020, T021, T022, T023 (병렬)
    └──▶ T024
              └──▶ T025 → T026 → T027 (순차)
              └──▶ T029 → T030 → T031 (순차)
              └──▶ T033 → T034 (순차)
              └──▶ T036 → T037 (순차)
                        └──▶ T038 → T039 → T040 → T041
```

**Phase 4 내 (US1):**
```
T050, T051, T052, T053, T054 (UI 컴포넌트 병렬)
T042 → T043 → T044 → T045 → T046 → T047 → T048 → T049 (Service 순차)
    └──▶ T055 → T056 → T057 (GridViewController 통합)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup 완료
2. Phase 2: Foundational 완료 (CRITICAL)
3. Phase 3: Analysis Pipeline 완료
4. Phase 4: User Story 1 완료
5. **STOP and VALIDATE**: US1 독립 테스트
6. Deploy/Demo 가능 (MVP!)

### Incremental Delivery

| Milestone | 포함 범위 | 테스트 가능 시나리오 |
|-----------|----------|-------------------|
| MVP | Phase 1-4 (US1) | 최신 사진부터 정리 |
| v1.1 | + Phase 5 (US2) | + 연도별 정리 |
| v1.2 | + Phase 6 (US3) | + 이어서 정리 |
| v1.3 | + Phase 7-9 | + 특수 미디어, 안정성 |
| Final | + Phase 10 | + 성능 최적화, 디버그 |

---

## Summary

| 항목 | 값 |
|-----|---|
| 총 태스크 수 | 97개 |
| Phase 수 | 10개 |
| User Story 수 | 4개 (US1, US2, US3, US5) |
| 병렬 가능 태스크 | 41개 ([P] 마킹) |
| MVP 범위 태스크 | 59개 (Phase 1-4) |

---

## Notes

- [P] 태스크 = 파일 충돌 없음, 의존성 없음
- [Story] 레이블 = User Story 추적성 확보
- 각 User Story는 독립적으로 완료 및 테스트 가능
- 테스트 실패 확인 후 구현 진행
- 태스크 완료 또는 논리적 그룹 완료 후 커밋
- 어느 체크포인트에서든 중단하여 Story 독립 검증 가능

# Implementation Plan: 저품질 사진 자동 정리

**Branch**: `001-auto-cleanup` | **Date**: 2026-01-21 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-auto-cleanup/spec.md`, docs/autodel/ 기획 문서

---

## Summary

사진 라이브러리에서 저품질 사진(블러, 극단 노출, 주머니 샷 등)을 자동 감지하여 앱 내부 휴지통으로 이동하는 기능.

**핵심 기술 접근:**
- iOS 18+: `CalculateImageAestheticsScoresRequest` 우선, 실패 시 Metal 파이프라인 fallback
- iOS 16-17: Metal Laplacian + Luminance 분석
- iCloud 사진: 로컬 캐시 썸네일만 사용 (원본 다운로드 없음)
- 휴지통: 기존 `TrashStore` 활용

---

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: UIKit, PhotoKit, Vision, Metal, MetalPerformanceShaders
**Storage**: 파일 기반 (Documents/CleanupSession.json, 기존 TrashState.json)
**Testing**: XCTest (Unit + Integration)
**Target Platform**: iOS 16.0+
**Project Type**: Mobile (기존 SweepPic 앱에 기능 추가)
**Performance Goals**: 1,000장 스캔 30초 이내, 분석당 10ms 이내
**Constraints**: 원본 다운로드 금지, 백그라운드 30초 제약
**Scale/Scope**: 10만장 이상 라이브러리 지원

---

## Constitution Check

*GATE: Constitution 파일이 템플릿 상태이므로 프로젝트별 원칙 적용*

**적용 원칙 (CLAUDE.md 기반):**
- [x] 모든 파일 1,000줄 이하 분할
- [x] 상세 주석 작성
- [x] 50줄 이상 수정 시 커밋 선행
- [x] 분석/원인 파악 요청 시 허락 없이 코드 수정 금지

**기술 원칙:**
- [x] 기존 아키텍처 패턴 준수 (Features/ 하위 구조, AppCore 공유 로직)
- [x] 기존 서비스 활용 (TrashStore, ImagePipeline, PhotoLibraryService)
- [x] iOS 버전별 조건부 생성 패턴

---

## Project Structure

### Documentation (this feature)

```text
specs/001-auto-cleanup/
├── spec.md              # Feature specification
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (internal API contracts)
│   └── cleanup-service.md
└── tasks.md             # Phase 2 output (별도 명령)
```

### Source Code (repository root)

```text
# 신규 생성
SweepPic/SweepPic/Features/AutoCleanup/
├── Models/
│   ├── CleanupSession.swift       # 정리 세션 상태
│   ├── QualitySignal.swift        # 품질 판정 신호 (Strong/Conditional/Weak)
│   └── CleanupResult.swift        # 정리 결과
├── Analysis/
│   ├── QualityAnalyzer.swift      # 품질 분석 코디네이터
│   ├── ExposureAnalyzer.swift     # Stage 2: 노출/색상 분석
│   ├── BlurAnalyzer.swift         # Stage 3: Metal Laplacian 블러 분석
│   ├── AestheticsAnalyzer.swift   # iOS 18+ AestheticsScore 분석
│   └── SafeGuard.swift            # Stage 4: 안전장치 (얼굴, 심도 등)
├── Services/
│   ├── CleanupService.swift       # 정리 실행 서비스
│   └── CleanupSessionStore.swift  # 세션 저장 (이어서 정리용)
├── UI/
│   ├── CleanupButton.swift        # 정리 버튼 컴포넌트
│   ├── CleanupMethodSheet.swift   # 정리 방식 선택 시트
│   ├── CleanupProgressView.swift  # 탐색 진행 UI
│   └── CleanupResultAlert.swift   # 결과 알림
└── Debug/
    └── CleanupDebug.swift         # 디버그 유틸리티

# 기존 파일 수정
Sources/AppCore/Stores/TrashStore.swift        # 기존 moveToTrash(assetIDs:) API 활용 (수정 불필요)
SweepPic/SweepPic/Features/Grid/GridViewController.swift  # 정리 버튼 추가
SweepPic/SweepPic/Features/Grid/BaseGridViewController.swift  # 버튼 영역 확보
```

**Structure Decision**: 기존 Features/ 패턴을 따라 `AutoCleanup/` 폴더에 기능별로 분리. Analysis/ 폴더에 4단계 파이프라인 분석기 배치.

---

## Complexity Tracking

| 항목 | 설명 | 근거 |
|-----|------|------|
| iOS 버전 분기 | iOS 18+ AestheticsScore vs iOS 16-17 Metal | Apple API 가용성 차이 |
| 4단계 파이프라인 | Metadata → Exposure → Blur → SafeGuard | 조기 종료 최적화, 비용순 실행 |

---

## Phase 0: Research Summary

**완료된 연구 항목:**

1. **Laplacian Variance 임계값**: PyImageSearch 100 기준, 심각 블러 50 (설계값)
2. **휘도 임계값**: GitHub Gist 기준, 0.10/0.90 (Precision 엄격값)
3. **AestheticsScore**: Apple WWDC24 API, 임계값 -0.3/0 (설계값)
4. **Face Quality**: Apple Vision API, 0.4 (설계값, 절대 임계값 사용 주의)
5. **iCloud 썸네일**: networkAccessAllowed=false로 로컬 캐시만 사용

상세 내용: [research.md](./research.md)

---

## Phase 1: Design Summary

### Data Model

**주요 엔티티:**
- `CleanupSession`: 정리 세션 (시작점, 현재 위치, 찾은 수, 모드)
- `QualitySignal`: 품질 판정 신호 (Strong/Conditional/Weak)
- `QualityResult`: 개별 사진 분석 결과
- `CleanupResult`: 전체 정리 결과

상세 내용: [data-model.md](./data-model.md)

### Internal Contracts

**주요 서비스:**
- `CleanupServiceProtocol`: 정리 실행 인터페이스
- `QualityAnalyzerProtocol`: 품질 분석 인터페이스
- `CleanupSessionStoreProtocol`: 세션 저장 인터페이스

상세 내용: [contracts/cleanup-service.md](./contracts/cleanup-service.md)

---

## Implementation Phases

### Phase A: 기반 구조 (Models + Store)

1. CleanupSession, QualitySignal, CleanupResult 모델 정의
2. CleanupSessionStore 구현 (파일 기반 저장)
3. Unit 테스트

### Phase B: 분석 파이프라인

1. ExposureAnalyzer 구현 (휘도, RGB Std, 비네팅)
2. BlurAnalyzer 구현 (Metal Laplacian)
3. SafeGuard 구현 (얼굴 품질, 심도 효과)
4. QualityAnalyzer 코디네이터 구현
5. iOS 18+ AestheticsAnalyzer 구현
6. Unit + Integration 테스트

### Phase C: 서비스 레이어

1. CleanupService 구현 (탐색 로직, 종료 조건)
2. 배치 처리 + 동시성 제어
3. 취소 처리
4. Integration 테스트

### Phase D: UI 레이어

1. CleanupButton 추가 (GridViewController)
2. CleanupMethodSheet 구현 (정리 방식 선택)
3. CleanupProgressView 구현 (탐색 진행)
4. CleanupResultAlert 구현 (결과 표시)
5. 휴지통 비어있지 않음 처리

### Phase E: 특수 케이스 + 통합

1. 비디오 프레임 추출 분석
2. Live Photo/Burst/RAW 처리
3. 백그라운드 전환 일시정지/재개
4. E2E 테스트

---

## Risk Mitigation

| 리스크 | 대응 |
|-------|------|
| AestheticsScore 시뮬레이터 미지원 | Metal fallback 구현, 실기기 테스트 필수 |
| Face Quality 절대 임계값 오탐 | 테스트 데이터셋으로 검증, 임계값 조정 가능하게 설계 |
| 1,000장 30초 성능 목표 | 조기 종료 최적화, 배치 크기/동시성 튜닝 |
| iCloud 썸네일 부재 | SKIP 처리, 분석 정확도 영향 모니터링 |

---

## Next Steps

1. `/speckit.tasks` 실행하여 세부 태스크 생성
2. Phase A부터 순차 구현
3. 각 Phase 완료 시 커밋

# Implementation Plan: 유사 사진 정리 기능

**Branch**: `001-similar-photo` | **Date**: 2025-12-31 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-similar-photo/spec.md`
**Algorithm**: [prd8algorithm.md](../../docs/prd8algorithm.md)

## Summary

연속 촬영된 유사 사진 중 얼굴 표정을 비교하여 불필요한 사진을 쉽게 삭제할 수 있는 기능 구현. iOS Vision 프레임워크를 활용한 이미지 유사도 비교 및 얼굴 감지, 그리드/뷰어 트리거 UI, 얼굴 비교 화면 구현.

### 핵심 알고리즘
- **유사 사진 분류**: VNGenerateImageFeaturePrintRequest + 거리 10.0 이하
- **인물 매칭**: 위치 기반 (x좌표 우선) + Feature Print 검증 (0.6/1.0 임계값)
- **그룹 유형**: 유사사진썸네일그룹(분석 범위 내 전체) / 유사사진정리그룹(최대 8장)

### 유사사진썸네일그룹 판정 조건
그리드 테두리/뷰어 버튼 표시 여부 결정 (모든 조건 충족 필요):
1. 현재 사진에 얼굴 1개 이상 감지
2. 앞뒤 7장 범위 내 Feature Print 거리 10.0 이하 유사 사진 존재
3. 현재 사진 포함 유사 사진 3장 이상
4. 그룹 내 얼굴 있는 사진 3장 이상 (얼굴 필터 적용 후)

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: UIKit, PhotoKit, Vision Framework
**Storage**: 앱 내 휴지통 (기존 TrashStore 활용), 분석 결과 캐싱 없음 (MVP)
**Testing**: XCTest, UI Tests
**Target Platform**: iOS 16+
**Project Type**: Mobile (iOS)
**Performance Goals**: 그리드 스크롤 네이티브 주사율 유지 (60Hz/120Hz), 1초 내 테두리 표시, 0.5초 내 얼굴 버튼 표시
**Constraints**: 5만 장 라이브러리에서도 성능 유지, 메모리 효율적 관리
**Scale/Scope**: 앞뒤 7장 범위 분석, 최대 5개 얼굴 + 버튼

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Constitution이 템플릿 상태이므로 프로젝트별 규칙 적용:

| Gate | Status | Notes |
|------|--------|-------|
| 기존 아키텍처 준수 | PASS | AppCore + PickPhoto 구조 유지 |
| iOS 16+ 호환성 | PASS | Vision Framework iOS 11+, 사용 API 모두 iOS 16+ 호환 |
| 테스트 가능성 | PASS | 모든 서비스/스토어 분리, 단위 테스트 가능 |
| 기존 컴포넌트 재사용 | PASS | TrashStore, FloatingUI 재사용 |

## Project Structure

### Documentation (this feature)

```text
specs/001-similar-photo/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (N/A - 네이티브 앱)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
# iOS Mobile App Structure
Sources/AppCore/
├── Models/
│   ├── PhotoModels.swift              # 기존
│   ├── SimilarThumbnailGroup.swift    # NEW: 그리드 테두리용 그룹 (무제한)
│   ├── SimilarCleanupGroup.swift      # NEW: 얼굴 비교 화면용 그룹 (최대 8장)
│   ├── FaceRegion.swift               # NEW: 얼굴 영역 (boundingBox, 크기비율)
│   ├── PersonComparison.swift         # NEW: 인물별 얼굴 크롭 목록 및 선택 상태
│   └── MatchConfidence.swift          # NEW: 매칭 신뢰도 (high/medium/low)
├── Services/
│   ├── PhotoLibraryService.swift      # 기존
│   ├── ImagePipeline.swift            # 기존
│   ├── SimilarityService.swift        # NEW: Feature Print 기반 유사도 분석
│   ├── FaceDetectionService.swift     # NEW: 얼굴 감지 (VNDetectFaceRectanglesRequest)
│   └── FaceMatchValidator.swift       # NEW: Feature Print 기반 인물 매칭 검증
└── Stores/
    ├── TrashStore.swift               # 기존 (재사용)
    └── SimilarPhotoStore.swift        # NEW: 유사 사진 상태 관리

PickPhoto/PickPhoto/
├── Features/
│   ├── Grid/
│   │   ├── GridViewController.swift    # 분할 후 메인 (~905줄)
│   │   ├── GridSelectMode.swift        # NEW: Select 모드 분리 (251231file)
│   │   ├── GridScroll.swift            # NEW: 스크롤/초기표시 분리 (251231file) + PRD8 트리거
│   │   ├── GridGestures.swift          # NEW: 제스처 분리 (251231file) + PRD7 예정
│   │   ├── GridSimilarPhoto.swift      # NEW: 유사사진 테두리 관리 [PRD8]
│   │   ├── PhotoCell.swift             # 수정: 테두리 레이어 추가
│   │   └── SimilarBorderLayer.swift    # NEW: 빛 회전 애니메이션 [PRD8]
│   ├── Viewer/
│   │   ├── ViewerViewController.swift  # 수정: 유사사진정리버튼 추가
│   │   └── FacePlusButtonOverlay.swift # NEW: 얼굴 + 버튼 오버레이
│   └── FaceComparison/                 # NEW: 얼굴 비교 화면
│       ├── FaceComparisonViewController.swift
│       ├── FaceCropCell.swift          # 경고 배지 표시 포함
│       └── PersonCycleManager.swift    # 크로스페이드 0.3초
└── Shared/
    └── Components/
        ├── FloatingTabBar.swift        # 기존 (재사용)
        └── FloatingTitleBar.swift      # 기존 (재사용)

Tests/AppCoreTests/
├── SimilarityServiceTests.swift       # NEW: 유사도 거리 테스트
├── FaceDetectionServiceTests.swift    # NEW: 얼굴 감지 테스트
├── FaceMatchValidatorTests.swift      # NEW: 인물 매칭 검증 테스트
└── SimilarPhotoStoreTests.swift       # NEW: 상태 관리 테스트
```

**Structure Decision**: 기존 AppCore + PickPhoto 이중 아키텍처 유지. Vision 기반 서비스는 AppCore에, UI 컴포넌트는 PickPhoto에 배치.

## Complexity Tracking

> 모든 Constitution Gate 통과, 추가 정당화 불필요

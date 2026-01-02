# Implementation Plan: 유사 사진 정리 기능

**Branch**: `002-similar-photo` | **Date**: 2026-01-02 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/002-similar-photo/spec.md`

## Summary

유사 사진 정리 기능은 연속 촬영된 사진들 중 유사한 사진을 자동 감지하고, 얼굴 비교를 통해 눈 감은 사진이나 표정이 이상한 사진을 쉽게 삭제할 수 있는 iOS 앱 기능입니다. Vision Framework를 사용하여 이미지 유사도 분석과 얼굴 감지를 수행하며, 그리드 테두리 애니메이션과 뷰어 +버튼 오버레이를 통해 사용자에게 유사 사진을 안내합니다.

## Technical Context

**Language/Version**: Swift 5.9+
**Primary Dependencies**: UIKit, Vision Framework (VNGenerateImageFeaturePrintRequest, VNDetectFaceRectanglesRequest), PhotoKit (PHAsset, PHCachingImageManager)
**Storage**: 파일 기반 저장 (앱 내 휴지통 상태), 메모리 캐시 (SimilarityCache)
**Testing**: XCTest, UI Testing
**Target Platform**: iOS 16+
**Project Type**: Mobile (iOS)
**Performance Goals**: 그리드 60fps/120fps(ProMotion) 스크롤 유지, 테두리 표시 1초 이내, 캐시 hit 시 +버튼 즉시 표시
**Constraints**: 캐시 500장 이내, 동시 분석 최대 5개, 5만장 이상 라이브러리 지원
**Scale/Scope**: 그리드 뷰, 뷰어, 얼굴 비교 화면 3개 화면 + 기존 UI 통합

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

프로젝트 constitution이 아직 설정되지 않아 (템플릿 상태), CLAUDE.md의 코딩 스타일 가이드를 따릅니다:

| 원칙 | 상태 | 비고 |
|------|------|------|
| 모든 코드에 상세 주석 | PASS | 적용 예정 |
| 파일 2천줄 미만 유지 | PASS | 기능별 파일 분할 계획 |
| 한글 대화/문서화 | PASS | 적용 중 |
| Git 50줄 이상 수정 시 커밋 | PASS | 적용 예정 |

## Project Structure

### Documentation (this feature)

```text
specs/002-similar-photo/
├── spec.md              # Feature specification (완료)
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (해당 없음 - iOS 앱)
├── checklists/          # Quality checklists
│   └── requirements.md  # Spec quality checklist (완료)
└── tasks.md             # Phase 2 output (/speckit.tasks)
```

### Source Code (repository root)

```text
PickPhoto/PickPhoto/
├── Features/
│   ├── Grid/
│   │   └── GridViewController.swift      # 기존 - 테두리 표시 추가
│   ├── Viewer/
│   │   └── ViewerViewController.swift    # 기존 - +버튼 오버레이 추가
│   └── SimilarPhoto/                     # 신규 모듈
│       ├── Analysis/
│       │   ├── SimilarityAnalyzer.swift       # 유사도 분석 (Vision)
│       │   ├── FaceDetector.swift             # 얼굴 감지 (Vision)
│       │   └── SimilarityCache.swift          # 분석 결과 캐시
│       ├── UI/
│       │   ├── BorderAnimationLayer.swift     # 테두리 애니메이션
│       │   ├── FaceButtonOverlay.swift        # +버튼 오버레이
│       │   └── FaceComparisonViewController.swift  # 얼굴 비교 화면
│       └── Models/
│           ├── SimilarPhotoGroup.swift        # 유사사진그룹 모델
│           └── CachedFace.swift               # 캐시된 얼굴 정보
├── Shared/
│   └── Components/
│       └── FloatingTabBar.swift          # 기존 - 하단바 재사용
└── Stores/
    └── TrashStore.swift                  # 기존 - 삭제 기능 통합
```

**Structure Decision**: 기존 PickPhoto 앱 구조를 유지하면서 `Features/SimilarPhoto/` 모듈을 신규 추가합니다. Analysis, UI, Models 하위 디렉토리로 관심사 분리를 적용합니다.

## Complexity Tracking

> Constitution 위반 사항 없음 - 기존 앱 구조에 모듈 추가 방식으로 복잡도 최소화

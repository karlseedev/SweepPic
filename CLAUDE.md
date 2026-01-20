# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# ⚠️ 중요: 모든 대화는 한글로 진행합니다

**이 저장소에서 작업할 때 Claude Code와의 모든 대화는 반드시 한글로 진행해야 합니다.**
**All conversations in this repository MUST be conducted in Korean.**

코드 작성, 설명, 질문, 답변 등 모든 커뮤니케이션을 한글로 해주세요.

# 사용자에 대한 호칭을 "사용자"라고 부른다.

---

## 프로젝트 개요

PickPhoto는 iOS 사진 갤러리 앱입니다. 네이티브 iOS 사진 앱과 유사한 경험을 제공하면서 빠른 사진 정리를 위한 생산성 기능을 추가하는 것을 목표로 합니다. 스와이프 삭제 제스처 등의 사진 정리를 간소화하는 특장점을 가지고 있습니다.

주요 기능 :
- 네이티브 사진 앱과 유사한 그리드 기반 사진 브라우징
- 사진 정리 특화 기능 보유(추후 상세 기능 명확화 예정)

## 언어 & 문서화

- **모든 대화와 설명은 한글로 작성**
- PRD 및 품질 문서는 한글로 작성됨
- 코드 식별자와 주석은 영어 사용
- 문서는 한글 권장

## 코딩 스타일

- **모든 코드에는 상세한 주석을 달아서 작성한다**
- **모든 파일은 1,000줄이 넘어가지 않도록 기능별로 파일을 분할해서 저장한다**

## 파일 삭제 규칙

- **임시파일 포함 모든 파일 삭제 작업은 사용자의 허락 없이 절대 하지 않는다**

## 분석/디버깅 규칙

- **분석 또는 원인 파악 요청 시, 사용자의 명시적 허락 없이 코드를 수정하지 않는다**

## Git 규칙

- **코드 수정을 50줄 이상 하게 될 경우 수정 전에 무조건 깃에 커밋하고 수정한다**
- **tasks.md의 각 페이즈 진행 전에 커밋하고, 진행후에도 커밋한다**
- **롤백 작업 요청 시 수동으로 코드를 수정하는 것을 기본으로 한다. 깃으로 롤백이 필요할 경우에는 사용자에게 확인을 받고 깃으로 롤백한다**
- **git checkout, git reset 등 git 명령어로 코드를 원복할 때는 반드시 본인(Claude)이 해당 대화에서 커밋한 경우에만 가능하다. 사용자가 커밋한 내용은 그 사이에 어떤 수정이 있었는지 알 수 없으므로 git으로 원복하지 않는다**

## 프로젝트 파일 구조

> **주의:** 신규 파일 생성 또는 기존 파일 수정으로 구조가 변경되면 이 섹션도 함께 업데이트한다.

```
iOS/
├── Package.swift                    # Swift Package: AppCore 라이브러리
├── CLAUDE.md                        # Claude Code 가이드
│
├── Sources/AppCore/                 # 공유 비즈니스 로직 및 유틸리티
│   ├── AppCore.swift
│   ├── Models/
│   │   ├── AlbumModels.swift
│   │   ├── PermissionState.swift
│   │   ├── PhotoModels.swift
│   │   └── TrashState.swift
│   ├── Services/
│   │   ├── AlbumService.swift
│   │   ├── FileLogger.swift
│   │   ├── HitchMonitor.swift
│   │   ├── ImagePipeline.swift
│   │   ├── MemoryThumbnailCache.swift
│   │   ├── PhotoLibraryService.swift
│   │   ├── ThumbnailCache.swift
│   │   └── VideoPipeline.swift
│   └── Stores/
│       ├── AppStateStore.swift
│       ├── PermissionStore.swift
│       └── TrashStore.swift
│
├── Tests/AppCoreTests/              # AppCore 패키지 테스트
│   └── AppCoreTests.swift
│
├── PickPhoto/                       # 메인 iOS 애플리케이션
│   └── PickPhoto/
│       ├── App/
│       │   ├── AppDelegate.swift
│       │   └── SceneDelegate.swift
│       │
│       ├── Debug/
│       │   └── AutoScrollTester.swift
│       │
│       ├── Features/
│       │   ├── Albums/              # 앨범 관련 기능
│       │   │   ├── AlbumCell.swift
│       │   │   ├── AlbumGridViewController.swift
│       │   │   ├── AlbumsViewController.swift
│       │   │   └── TrashAlbumViewController.swift
│       │   │
│       │   ├── Grid/                # 그리드 뷰 기능
│       │   │   ├── BaseGridViewController.swift
│       │   │   ├── GridColumnCount.swift
│       │   │   ├── GridDataSource.swift
│       │   │   ├── GridDataSourceDriver.swift
│       │   │   ├── GridGestures.swift
│       │   │   ├── GridScroll.swift
│       │   │   ├── GridSelectMode.swift
│       │   │   ├── GridViewController.swift
│       │   │   ├── GridViewController+SimilarPhoto.swift
│       │   │   ├── PhotoCell.swift
│       │   │   └── SelectionManager.swift
│       │   │
│       │   ├── Permissions/         # 권한 요청
│       │   │   └── PermissionViewController.swift
│       │   │
│       │   ├── SimilarPhoto/        # 유사 사진 분석 기능
│       │   │   ├── Analysis/
│       │   │   │   ├── ExtendedFallbackTester.swift
│       │   │   │   ├── FaceAligner.swift
│       │   │   │   ├── FaceCropper.swift
│       │   │   │   ├── FaceDetector.swift
│       │   │   │   ├── S2DebugAnalyzer.swift
│       │   │   │   ├── SFaceRecognizer.swift
│       │   │   │   ├── SimilarityAnalysisQueue.swift
│       │   │   │   ├── SimilarityAnalysisQueue+ExtendedFallback.swift
│       │   │   │   ├── SimilarityAnalyzer.swift
│       │   │   │   ├── SimilarityCache.swift
│       │   │   │   ├── SimilarityImageLoader.swift
│       │   │   │   ├── VisionFallbackMode.swift
│       │   │   │   └── YuNet/       # YuNet 얼굴 감지
│       │   │   │       ├── YuNetDebugTest.swift
│       │   │   │       ├── YuNetDecoder.swift
│       │   │   │       ├── YuNetFaceDetector.swift
│       │   │   │       ├── YuNetPreprocessor.swift
│       │   │   │       └── YuNetTypes.swift
│       │   │   ├── Debug/
│       │   │   │   └── FaceComparisonDebug.swift
│       │   │   ├── Models/
│       │   │   │   ├── AnalysisRequest.swift
│       │   │   │   ├── CachedFace.swift
│       │   │   │   ├── FaceMatch.swift
│       │   │   │   ├── SimilarPhotoGroup.swift
│       │   │   │   ├── SimilarityAnalysisState.swift
│       │   │   │   └── SimilarityConstants.swift
│       │   │   ├── UI/
│       │   │   │   ├── AnalysisLoadingIndicator.swift
│       │   │   │   ├── BorderAnimationLayer.swift
│       │   │   │   ├── FaceButtonOverlay.swift
│       │   │   │   ├── FaceComparisonViewController.swift
│       │   │   │   ├── FaceComparisonViews.swift
│       │   │   │   └── PersonPageViewController.swift
│       │   │   └── Utils/
│       │   │       └── AsyncSemaphore.swift
│       │   │
│       │   └── Viewer/              # 사진 뷰어 기능
│       │       ├── PhotoPageViewController.swift
│       │       ├── PlayerLayerView.swift
│       │       ├── SwipeDeleteHandler.swift
│       │       ├── VideoControlsOverlay.swift
│       │       ├── VideoPageViewController.swift
│       │       ├── ViewerCoordinator.swift
│       │       ├── ViewerViewController.swift
│       │       └── ViewerViewController+SimilarPhoto.swift
│       │
│       └── Shared/                  # 공유 컴포넌트
│           ├── Components/
│           │   ├── EmptyStateView.swift
│           │   ├── FloatingOverlayContainer.swift
│           │   ├── FloatingTabBar.swift
│           │   ├── FloatingTitleBar.swift
│           │   └── ToastView.swift
│           ├── FeatureFlags.swift
│           ├── Navigation/
│           │   └── TabBarController.swift
│           ├── Protocols/
│           │   └── BarsVisibilityControlling.swift
│           └── Utils/
│               └── HapticFeedback.swift
│
├── docs/                            # 문서
│   ├── prd*.md                      # 제품 요구사항 문서
│   ├── 26MMDD*.md                   # 작업 로그
│   ├── log/                         # 상세 로그
│   ├── complete/                    # 완료된 작업 문서
│   └── bak/                         # 백업 문서
│
├── specs/                           # 기능 명세
│   ├── 001-auto-cleanup/
│   ├── 001-pickphoto-mvp/
│   └── 002-similar-photo/
│
└── test/                            # 테스트 및 스파이크
    └── Spike1/                      # 성능 테스트 프로젝트
```

## Active Technologies (001-pickphoto-mvp)
- Swift 5.9+, iOS 16+
- UIKit 기반 (UICollectionView + performBatchUpdates)
- PhotoKit (PHAsset, PHFetchResult, PHCachingImageManager, PHPhotoLibraryChangeObserver)
- 파일 기반 저장 (앱 내 휴지통 상태)

## Recent Changes
- 002-similar-photo: Added Swift 5.9+ + UIKit, Vision Framework (VNGenerateImageFeaturePrintRequest, VNDetectFaceRectanglesRequest), PhotoKit (PHAsset, PHCachingImageManager)
- 001-similar-photo: Added Swift 5.9+ + UIKit, PhotoKit, Vision Framework
- 001-pickphoto-mvp: UIKit 기반 + performBatchUpdates + PHCachingImageManager 확정

## 빌드 & 테스트 명령어

```bash
# AppCore Swift 패키지 빌드/테스트
swift build
swift test

# iOS 앱 빌드 (시뮬레이터)
xcodebuild -project PickPhoto/PickPhoto.xcodeproj -scheme PickPhoto -destination 'platform=iOS Simulator,name=iPhone 16'

# Xcode에서 열기
open PickPhoto/PickPhoto.xcodeproj
```

## 주요 클래스 역할

| 클래스 | 파일 위치 | 역할 |
|-------|----------|------|
| `BaseGridViewController` | Features/Grid/ | 그리드 뷰의 공통 베이스 클래스. 컬렉션뷰, 스크롤, 제스처 기본 동작 |
| `GridViewController` | Features/Grid/ | 메인 사진 보관함 그리드. BaseGridViewController 상속 |
| `AlbumGridViewController` | Features/Albums/ | 앨범 상세 그리드. BaseGridViewController 상속 |
| `TrashAlbumViewController` | Features/Albums/ | 휴지통 그리드. BaseGridViewController 상속 |
| `GridDataSource` | Features/Grid/ | PHFetchResult 기반 데이터 소스 관리 |
| `ViewerViewController` | Features/Viewer/ | 전체화면 사진 뷰어 |
| `TrashStore` | AppCore/Stores/ | 앱 내 휴지통 상태 관리 (파일 기반) |
| `ImagePipeline` | AppCore/Services/ | 썸네일 로딩 및 캐싱 |
| `SimilarityAnalysisQueue` | Features/SimilarPhoto/ | 유사 사진 분석 큐 관리 |

## 아키텍처 패턴 & 규칙

- **ViewController 위치**: Features/ 하위에 기능별로 분리
- **상속 구조**: 그리드 계열은 `BaseGridViewController` 상속
- **모델/서비스**: 공용 로직은 `AppCore` 패키지에 위치
- **Extension 네이밍**: `+기능명.swift` 형식 (예: `GridViewController+SimilarPhoto.swift`)
- **디버그 기능**: 별도 파일로 분리 (예: `Debug/`, `*Debug.swift`)

## iOS 버전 분기 원칙

| iOS 버전 | UI 방식 | 플래그 |
|---------|--------|-------|
| iOS 16~25 | FloatingOverlay (커스텀 UI) | `useFloatingUI = true` |
| iOS 26+ | 시스템 네비게이션 바 | `useFloatingUI = false` |

**핵심 원칙: 조건부 생성**
```swift
// ❌ 잘못된 방식: 만들어놓고 숨기기
lazy var floatingOverlay = FloatingOverlay()
if #available(iOS 26.0, *) { floatingOverlay.isHidden = true }

// ✅ 올바른 방식: 처음부터 분기
if #available(iOS 26.0, *) {
    setupSystemNavigationBar()
} else {
    setupFloatingOverlay()
}
```

**`useFloatingUI` 정의 위치:**
- `BaseGridViewController.swift:152` - 그리드 계열 VC용
- `TabBarController.swift:31` - 탭바 컨트롤러용

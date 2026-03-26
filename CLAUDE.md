# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

---

# ⚠️ 중요: 모든 대화는 한글로 진행합니다

**이 저장소에서 작업할 때 Claude Code와의 모든 대화는 반드시 한글로 진행해야 합니다.**
**All conversations in this repository MUST be conducted in Korean.**

코드 작성, 설명, 질문, 답변 등 모든 커뮤니케이션을 한글로 해주세요.

# 사용자에 대한 호칭을 "주인님"이라고 부르며, 존칭을 쓴다.

---

## 프로젝트 개요

SweepPic는 iOS 사진 갤러리 앱입니다. 네이티브 iOS 사진 앱과 유사한 경험을 제공하면서 빠른 사진 정리를 위한 생산성 기능을 추가하는 것을 목표로 합니다. 스와이프 삭제 제스처 등의 사진 정리를 간소화하는 특장점을 가지고 있습니다.

주요 기능 :
- 네이티브 사진 앱과 유사한 그리드 기반 사진 브라우징
- 사진 정리 특화 기능 보유(추후 상세 기능 명확화 예정)

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

## 기술 스택
- iOS 16+, Swift 5.9+, UIKit
- PhotoKit, Vision Framework
- **LiquidGlassKit**: Fork 버전 사용 중 (`karlseedev/LiquidGlassKit`) - 상세: [docs/UI/260127LiquidKit-Plan.md](docs/UI/260127LiquidKit-Plan.md)

## 폴더 구조

| 폴더 | 역할 |
|-----|------|
| `Sources/AppCore/Models/` | 데이터 모델 (Album, Photo, Trash 등) |
| `Sources/AppCore/Services/` | 서비스 레이어 (ImagePipeline, PhotoLibraryService 등) |
| `Sources/AppCore/Stores/` | 상태 관리 (AppState, Permission, Trash) |
| `SweepPic/SweepPic/App/` | 앱 진입점 (AppDelegate, SceneDelegate) |
| `SweepPic/SweepPic/Features/Albums/` | 앨범 목록 및 상세, 삭제대기함 |
| `SweepPic/SweepPic/Features/Grid/` | 메인 사진 그리드, 셀, 선택 모드 |
| `SweepPic/SweepPic/Features/Permissions/` | 사진 라이브러리 권한 요청 |
| `SweepPic/SweepPic/Features/SimilarPhoto/` | 유사 사진 분석 (얼굴 인식, Vision) |
| `SweepPic/SweepPic/Features/Viewer/` | 전체화면 사진/비디오 뷰어 |
| `SweepPic/SweepPic/Shared/Components/` | 공용 UI (FloatingTabBar, Toast 등) |
| `specs/` | 기능별 명세 문서 |
| `docs/` | 작업 로그, PRD 문서 |

## 주요 클래스 역할

| 클래스 | 파일 위치 | 역할 |
|-------|----------|------|
| `BaseGridViewController` | Features/Grid/ | 그리드 뷰의 공통 베이스 클래스. 컬렉션뷰, 스크롤, 제스처 기본 동작 |
| `GridViewController` | Features/Grid/ | 메인 사진 보관함 그리드. BaseGridViewController 상속 |
| `AlbumGridViewController` | Features/Albums/ | 앨범 상세 그리드. BaseGridViewController 상속 |
| `TrashAlbumViewController` | Features/Albums/ | 삭제대기함 그리드. BaseGridViewController 상속 |
| `GridDataSource` | Features/Grid/ | PHFetchResult 기반 데이터 소스 관리 |
| `ViewerViewController` | Features/Viewer/ | 전체화면 사진 뷰어 |
| `TrashStore` | AppCore/Stores/ | 앱 내 삭제대기함 상태 관리 (파일 기반) |
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

## 명칭 규칙

| 기존 명칭 | 변경 명칭 | 비고 |
|----------|----------|------|
| 휴지통 | 삭제대기함 | UI 문자열, 주석 모두 적용 |

- 영문 코드 식별자(TrashStore, TrashAlbum, isTrashed 등)는 변경하지 않음
- 새 코드 작성 시 한글 "휴지통" 대신 "삭제대기함" 사용

## 로그 관리 시스템

앱 전체 로그는 Apple `Logger` API (Unified Logging)를 사용합니다.
Logger extension 정의: `Sources/AppCore/Services/Logger+App.swift`

```swift
import OSLog      // Logger 타입
import AppCore    // Logger extension (.viewer, .app 등)

// 사용 예시
Logger.viewer.debug("scale: \(scale)")
Logger.pipeline.error("thumbnail load failed: \(error)")
Logger.app.notice("Memory warning received")
```

**로그 레벨:**
| 레벨 | 용도 | 릴리즈 |
|------|------|--------|
| `.debug` | 개발 중 상세 로그 | 자동 제거 |
| `.info` | 참고 정보 | 스트리밍 시만 |
| `.notice` | 핵심 이벤트 | 디스크 저장 |
| `.error` | 런타임 에러 | 장기 보존 |

**카테고리 (11개):**
`viewer`, `albums`, `similarPhoto`, `cleanup`, `transition`, `pipeline`, `performance`, `analytics`, `coachMark`, `app`, `appDebug`

**실기기 로그 확인:**
```bash
log stream --predicate 'subsystem == "com.karl.SweepPic"' --level debug
```

> ⚠️ `Log.swift`는 레거시로 남아있으나 실제 사용처 없음. 새 코드에서는 `Logger` 사용

## 빌드 & 테스트 명령어

```bash
# AppCore Swift 패키지 빌드/테스트
swift build
swift test

# iOS 앱 빌드 (시뮬레이터)
xcodebuild -project SweepPic/SweepPic.xcodeproj -scheme SweepPic -destination 'platform=iOS Simulator,name=iPhone 17'

# Xcode에서 열기
open SweepPic/SweepPic.xcodeproj
```

## Active Technologies
- Swift 5.9+ + UIKit, PhotoKit, StoreKit 2, Google Mobile Ads SDK 11.x (SPM), AppTrackingTransparency (003-bm-monetization)
- Keychain (UsageLimit), Documents/JSON (DeletionStats), UserDefaults (GracePeriod, ATT, Review), 인메모리 (SubscriptionState, AdCounters) (003-bm-monetization)

## Recent Changes
- 003-bm-monetization: Added Swift 5.9+ + UIKit, PhotoKit, StoreKit 2, Google Mobile Ads SDK 11.x (SPM), AppTrackingTransparency

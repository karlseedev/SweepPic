# iOS 18+ Zoom Transition 적용 가이드

## 개요

iOS 18부터 Apple이 `preferredTransition` API를 제공하여 사진 앱과 동일한 줌 전환 애니메이션을 쉽게 구현할 수 있습니다.

---

## 1. API 소개

### preferredTransition (iOS 18+)

```swift
viewController.preferredTransition = .zoom(sourceViewProvider: { context in
    // 줌 시작점이 될 뷰 반환
    return sourceView
})
```

| 항목 | 설명 |
|------|------|
| **도입 버전** | iOS 18 |
| **용도** | 뷰 컨트롤러 전환 시 줌 애니메이션 |
| **동작** | 소스 뷰에서 전체 화면으로 확대/축소 |
| **지원** | push, present 모두 지원 |

### sourceViewProvider 클로저

- **context.zoomedViewController**: 줌되는 뷰 컨트롤러 (destination)
- **반환값**: 줌 시작/종료점이 될 UIView
- **nil 반환 시**: 화면 중앙에서 줌 애니메이션

---

## 2. 현재 코드 상태

### 위치: GridViewController.swift (1302~1315줄)

```swift
// 뷰어 뷰컨트롤러 생성
let viewerVC = ViewerViewController(
    coordinator: coordinator,
    startIndex: filteredIndex,
    mode: mode
)
viewerVC.delegate = self

// TODO: T032 줌 전환 애니메이션은 Phase 9에서 iOS 사진 앱 수준으로 구현 예정
// 현재는 기본 전환 사용 (fullScreen + crossDissolve)

// 뷰어 표시
present(viewerVC, animated: false)
```

### 문제점
- `animated: false`로 즉시 표시
- 줌 전환 애니메이션 없음
- 사진 앱과 다른 UX

---

## 3. iOS 18+ 적용 방법

> **중요**: 아래는 **통합 예시**입니다. 스와이프 후 돌아오기를 지원하는 완전한 버전이므로,
> 이 코드 하나만 사용하세요. 별도의 "기본 적용" 버전을 추가로 복붙하지 마세요.

```swift
// 뷰어 뷰컨트롤러 생성
let viewerVC = ViewerViewController(
    coordinator: coordinator,
    startIndex: filteredIndex,
    mode: mode
)
viewerVC.delegate = self

// iOS 18+: 네이티브 zoom transition
if #available(iOS 18.0, *) {
    // ⚠️ iOS 18에서는 ViewerViewController의 커스텀 페이드 애니메이션 비활성화 필요
    viewerVC.disableCustomFadeAnimation = true

    // ⚠️ iOS 18에서는 modalTransitionStyle 설정하지 않음 (preferredTransition과 충돌 방지)
    // 기존: viewerVC.modalTransitionStyle = .crossDissolve  ← 제거 또는 주석 처리

    viewerVC.preferredTransition = .zoom(sourceViewProvider: { [weak self] context in
        guard let self = self,
              let viewer = context.zoomedViewController as? ViewerViewController else {
            return nil
        }

        // ⚠️ viewer.currentIndex는 read-only public 속성으로 노출 필요
        // ViewerViewController에서: public private(set) var currentIndex: Int
        let currentIndex = viewer.currentIndex

        // coordinator.originalIndex(from:): 필터링된 인덱스를 원본 fetchResult 인덱스로 변환
        // ViewerCoordinator에 구현된 메서드 (휴지통 필터링 등 적용 시 필요)
        guard let originalIndex = self.coordinator?.originalIndex(from: currentIndex) else {
            return nil  // 인덱스 변환 실패 시 중앙에서 줌
        }

        let indexPath = IndexPath(item: originalIndex, section: 0)

        // ⚠️ 셀이 화면 밖인 경우: scrollToItem 대신 nil 반환 권장
        // scrollToItem + layoutIfNeeded는 전환 중 잔상/깜빡임 유발 가능
        guard let cell = self.collectionView.cellForItem(at: indexPath) as? PhotoCell else {
            return nil  // 셀이 화면에 없으면 중앙에서 줌 (fallback)
        }

        // placeholder가 아닌 실제 이미지가 로드된 경우에만 줌 전환
        guard cell.hasLoadedImage else {
            return nil  // 이미지 미로드 시 중앙에서 줌 (fallback)
        }

        return cell.imageView
    })

    // 뷰어 표시 (animated: true 필수)
    present(viewerVC, animated: true)
} else {
    // iOS 16~17: 기존 방식 유지
    viewerVC.modalTransitionStyle = .crossDissolve
    present(viewerVC, animated: true)
}
```

---

## 4. 주의사항

### 4.1 애니메이션 충돌 방지

현재 `ViewerViewController`는 자체 커스텀 페이드 인/아웃 로직이 있습니다.
`preferredTransition`과 함께 사용하면 **이중 애니메이션**이 발생할 수 있습니다.

**가드해야 할 위치:**

| 위치 | 기존 로직 | 가드 필요 |
|------|----------|----------|
| `viewWillAppear` | `view.alpha = 0` 설정 | ✅ |
| `viewDidAppear` | 페이드 인 애니메이션 | ✅ |
| `dismissWithFadeOut()` | 페이드 아웃 후 dismiss | ✅ |
| 닫기 버튼 액션 | dismissWithFadeOut 호출 | (위에서 처리됨) |

**해결 방법:**
```swift
// ViewerViewController에 플래그 추가
var disableCustomFadeAnimation: Bool = false

// viewWillAppear에서 체크
override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    if !disableCustomFadeAnimation {
        view.alpha = 0  // 기존 페이드 인 준비
    }
}

// viewDidAppear에서 체크
override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    guard !disableCustomFadeAnimation else { return }
    // 기존 커스텀 페이드 인 로직...
    UIView.animate(withDuration: 0.2) {
        self.view.alpha = 1
    }
}

// dismiss 시 체크
func dismissWithFadeOut() {
    if disableCustomFadeAnimation {
        // iOS 18: preferredTransition이 줌 아웃 처리
        dismiss(animated: true)
    } else {
        // iOS 16~17: 기존 페이드 아웃 후 dismiss
        UIView.animate(withDuration: 0.2, animations: {
            self.view.alpha = 0
        }) { _ in
            self.dismiss(animated: false)
        }
    }
}
```

### 4.2 modalTransitionStyle 충돌 방지

`modalTransitionStyle = .crossDissolve`가 설정되어 있으면 `preferredTransition`과 충돌합니다.

**규칙:**
- iOS 18+: `modalTransitionStyle` 설정하지 않음 (기본값 유지)
- iOS 16~17: 기존대로 `.crossDissolve` 사용 가능

```swift
if #available(iOS 18.0, *) {
    // modalTransitionStyle 설정 생략 (preferredTransition 사용)
} else {
    viewerVC.modalTransitionStyle = .crossDissolve
}
```

### 4.3 sourceViewProvider nil 반환 규칙

다음 상황에서는 **nil을 반환**하여 중앙 줌 fallback 사용:

| 상황 | 이유 |
|------|------|
| 셀이 화면 밖 (offscreen) | scrollToItem 중 잔상 발생 가능 |
| 셀을 찾지 못함 | dequeue 타이밍 이슈 |
| placeholder 이미지 상태 | 저품질 이미지로 줌 시 UX 저하 |
| 인덱스 변환 실패 | 필터링 로직 불일치 |

### 4.4 PhotoCell 이미지 상태 확인

줌 시작 뷰가 placeholder면 확대 시 품질이 떨어져 보입니다.

**권장 구현:**
```swift
// PhotoCell에 추가
var hasLoadedImage: Bool {
    // placeholder가 아닌 실제 이미지가 로드되었는지 확인
    return imageView.image != nil && !isShowingPlaceholder
}
```

### 4.5 currentIndex 접근성

`ViewerViewController.currentIndex`가 private인 경우, sourceViewProvider에서 접근 불가합니다.

**필수 수정:**
```swift
// ViewerViewController.swift
// 기존: private var currentIndex: Int
// 변경:
public private(set) var currentIndex: Int
```

---

## 5. iOS 버전별 분기 전략

### 전체 구조

프로젝트는 **UI 스타일**과 **전환 애니메이션**이 독립적으로 분기됩니다:

```
┌─────────────────────────────────────────────────────────────┐
│                    iOS 버전별 UI 스타일                      │
├─────────────────────────────────────────────────────────────┤
│  iOS 26+     │ 시스템 기본 UI (탭바, 네비바, 툴바)           │
│  iOS 16~25   │ 커스텀 FloatingUI (캡슐 탭바, 플로팅 타이틀)  │
└─────────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                iOS 버전별 전환 애니메이션                    │
├─────────────────────────────────────────────────────────────┤
│  iOS 18+     │ preferredTransition = .zoom (네이티브)       │
│  iOS 16~17   │ 커스텀 ZoomAnimator 또는 기본 전환            │
└─────────────────────────────────────────────────────────────┘
```

### iOS 26에서의 동작

> **중요**: `preferredTransition`은 iOS 18+에서 도입된 API이므로,
> iOS 26에서도 `#available(iOS 18.0, *)`가 true입니다.
> 즉, **iOS 26에서도 동일한 줌 전환이 적용**됩니다.

| iOS 버전 | UI 스타일 | 줌 전환 |
|----------|-----------|---------|
| iOS 26+ | 시스템 기본 UI | ✅ preferredTransition |
| iOS 18~25 | 커스텀 FloatingUI | ✅ preferredTransition |
| iOS 16~17 | 커스텀 FloatingUI | ❌ fallback 필요 |

### 분기 코드 패턴

```swift
// UI 스타일 분기 (기존)
if #available(iOS 26.0, *) {
    // 시스템 기본 UI
} else {
    // 커스텀 FloatingUI
}

// 전환 애니메이션 분기 (신규)
if #available(iOS 18.0, *) {
    // iOS 18+ (iOS 26 포함): 네이티브 zoom transition
    viewerVC.disableCustomFadeAnimation = true
    viewerVC.preferredTransition = .zoom(sourceViewProvider: { ... })
    present(viewerVC, animated: true)
} else {
    // iOS 16~17: 커스텀 구현 또는 기본 전환
    // TODO: 출시 전 ZoomAnimator 구현
    viewerVC.modalTransitionStyle = .crossDissolve
    present(viewerVC, animated: true)
}
```

### 조합 매트릭스

| iOS 버전 | UI 스타일 | 전환 애니메이션 | 비고 |
|----------|-----------|-----------------|------|
| 26+ | 시스템 기본 | 네이티브 줌 | 최신 환경 |
| 18~25 | 커스텀 FloatingUI | 네이티브 줌 | 현재 주력 타겟 |
| 16~17 | 커스텀 FloatingUI | 커스텀/기본 | 출시 전 구현 필요 |

---

## 6. iOS 17 이하 Fallback (출시 전 구현)

### 필요한 클래스

| 클래스 | 역할 |
|--------|------|
| `ZoomTransitionController` | UIViewControllerTransitioningDelegate 구현 |
| `ZoomAnimator` | UIViewControllerAnimatedTransitioning 구현 |
| `ZoomInteractionController` | 드래그로 돌아가기 (인터랙티브) |

### 참고 구현

1. **Apple WWDC24 세션**: [Enhance your UI animations and transitions](https://developer.apple.com/videos/play/wwdc2024/10145/)
2. **Douglas Hill 가이드**: [Zoom transitions](https://douglashill.co/zoom-transitions/)
3. **GitHub 예제**: [PhotoZoomAnimator](https://github.com/jhrcook/PhotoZoomAnimator)
4. **Medium 튜토리얼**: [Create transition like iOS Photos app](https://medium.com/@masamichiueta/create-transition-and-interaction-like-ios-photos-app-2b9f16313d3)

---

## 7. 변수/메서드 설명

### 샘플 코드에서 사용된 변수

| 변수/메서드 | 출처 | 설명 |
|-------------|------|------|
| `indexPath` | `collectionView(_:didSelectItemAt:)` | 사용자가 탭한 셀의 IndexPath |
| `coordinator` | `GridViewController` 속성 | ViewerCoordinator 인스턴스 |
| `coordinator.originalIndex(from:)` | `ViewerCoordinator` | 필터링된 인덱스 → 원본 인덱스 변환 |
| `viewer.currentIndex` | `ViewerViewController` | 뷰어에서 현재 표시 중인 사진 인덱스 (read-only 공개 필요) |
| `cell.hasLoadedImage` | `PhotoCell` | 실제 이미지 로드 완료 여부 (구현 필요) |
| `cell.imageView` | `PhotoCell` | 줌 시작점이 될 UIImageView (접근자 확인 필요) |

---

## 8. 체크리스트

### MVP (iOS 18+ 우선)

- [ ] GridViewController에 `preferredTransition` 적용
- [ ] PhotoCell에서 `imageView` 접근 가능하도록 확인
- [ ] PhotoCell에 `hasLoadedImage` 속성 추가
- [ ] ViewerViewController에서 `currentIndex` read-only 공개
- [ ] ViewerViewController에 `disableCustomFadeAnimation` 플래그 추가
- [ ] 기존 커스텀 페이드 로직에 플래그 체크 추가
- [ ] 스와이프 후 돌아오기 테스트
- [ ] 성능 테스트 (hitch 없는지 확인)

### 출시 전 (iOS 16~17 지원)

- [ ] ZoomTransitionController 구현
- [ ] ZoomAnimator 구현
- [ ] ZoomInteractionController 구현 (드래그 dismiss)
- [ ] iOS 16, 17 시뮬레이터 테스트

---

## 9. 관련 파일

| 파일 | 수정 내용 |
|------|----------|
| `GridViewController.swift` | preferredTransition 적용, 버전 분기 |
| `PhotoCell.swift` | `imageView` 접근자, `hasLoadedImage` 속성 추가 |
| `ViewerViewController.swift` | `currentIndex` 공개, `disableCustomFadeAnimation` 플래그 |
| `ViewerCoordinator.swift` | `originalIndex(from:)` 메서드 확인 |
| `AlbumGridViewController.swift` | 동일한 패턴 적용 |
| `TrashAlbumViewController.swift` | 동일한 패턴 적용 |

---

## 10. 관련 PRD 참조

> **참고**: 뷰어 프리패칭 범위 관련하여 `prd8.md`에서 FR-201은 ±7, FR-203과 테스트는 ±5로 불일치가 있습니다.
> 줌 전환 구현 시 프리패칭 범위와 연관될 수 있으므로 PRD 통일 후 적용하세요.

---

## 11. 버전 정보

- **문서 작성일**: 2025-12-30
- **최종 수정일**: 2025-12-30
- **최소 지원 버전**: iOS 16+
- **네이티브 API 지원**: iOS 18+
- **프로젝트 브랜치**: 001-pickphoto-mvp

# PreviewGrid 레이아웃 수정 + 스와이프 삭제 구현 계획

> 작성일: 2026-03-27
> 대상: PreviewGridViewController (자동정리 미리보기 그리드)

## Context
PreviewGridViewController의 `photosSection()`이 `fractionalWidth` + `subitems:` + `contentInsetsReference` 미설정으로 우측 ~10pt 여백 발생. 추가로 스와이프 삭제(단일+다중) 기능이 전혀 없어 추가 필요.

## 수정/생성 파일

| 파일 | 작업 |
|------|------|
| `PreviewGridViewController.swift` | 레이아웃 수정 + 프로퍼티 추가 + 접근제어 변경 + 안전장치 |
| `PreviewGridViewController+SwipeDelete.swift` | **신규** — 단일 스와이프 + 제외 처리 |
| `PreviewGridViewController+MultiSwipe.swift` | **신규** — 다중 스와이프 + 자동 스크롤 |

경로: `SweepPic/SweepPic/Features/AutoCleanup/Preview/`

---

## Phase 1: 레이아웃 수정

`photosSection(environment:)` (374~399행) 변경:

| 항목 | 현재 | 변경 |
|------|------|------|
| 아이템 크기 | `.fractionalWidth(fraction)` | `.absolute(cellWidth)` |
| 그룹 높이 | `.fractionalWidth(fraction)` | `.absolute(cellWidth)` |
| 그룹 생성 | `subitems: [item]` | `repeatingSubitem: item, count: Int(columns)` |
| 섹션 inset | 미설정 (`.automatic`) | `section.contentInsetsReference = .none` |

`fraction` 변수 및 관련 계산 제거. `cellWidth` 계산은 유지.

### 원인 분석
`contentInsetsReference = .automatic`(기본값)이 `effectiveContentSize.width`를 layout margins만큼 축소하지만, `contentInsetAdjustmentBehavior = .never`와 결합 시 positioning은 축소되지 않아 우측에 비대칭 여백 발생. BaseGridViewController는 `section.contentInsetsReference = .none`으로 이 문제를 회피.

---

## Phase 2: 단일 스와이프 삭제

### 신규 파일: `PreviewGridViewController+SwipeDelete.swift`

**제스처 흐름** (BaseGridVC 패턴 복사 후 적응):
1. **began**: 터치 위치에서 PhotoCell 탐색, photos 섹션 검증, banner 차단
2. **changed**: 각도 체크(25°) → 단일 커튼 진행도 or 다중 전환
3. **ended**: `confirmRatio(0.5)` 또는 `confirmVelocity(800pt/s)` → 확정/취소
4. **cancelled**: 원래 상태 복귀

**BaseGridVC와의 핵심 차이**:
- paddingCell 없음 → `indexPath.item = 배열 인덱스` 직접 매핑
- `sectionType(for:)`로 photos/banner 분기 → banner에서 스와이프 시작 차단
- TrashStore 대신 즉시 previewResult 갱신 + reloadData
- `isTrashed`는 항상 false, `swipeActionIsRestore`는 항상 false

**⚠️ 모든 IndexPath 생성 시 `swipeTargetSection` 사용** (section: 0 하드코딩 금지):
```swift
// ❌ BaseMultiSwipeDelete 원본 (단일 섹션 전제)
let ip = IndexPath(item: item, section: 0)

// ✅ PreviewGrid 적응 (다중 섹션)
let ip = IndexPath(item: item, section: swipeTargetSection)
```

**제스처 충돌 해결** (UIGestureRecognizerDelegate):
- `gestureRecognizerShouldBegin`:
  - `collectionView.isDecelerating` → false (momentum 중 차단)
  - photos 섹션 셀 위에서만 허용 (banner 차단)
  - velocity 기반 각도 판정 35° 이내만 수락
- `shouldRecognizeSimultaneouslyWith`: 스크롤 panGesture와는 false

**PhotoCell 메서드 재사용** (수정 없이 그대로):
- `prepareSwipeOverlay(style: .delete)` → 마룬색
- `setDimmedProgress(progress, direction, isTrashed: false)` → 커튼
- `confirmDimmedAnimation(toTrashed: true)` → 확정
- `cancelDimmedAnimation()` → 취소

**셀 너비 — computed property** (캐싱 불필요):
```swift
var currentCellWidth: CGFloat {
    let totalSpacing = cellSpacing * (columns - 1)
    return floor((collectionView.bounds.width - totalSpacing) / columns)
}
```

### 제외 처리: `applySwipeExclusion(assetIDs:)`

**⚠️ `excludedAssetIDs`를 사용하지 않음** — 뷰어 전용이므로:

```swift
func applySwipeExclusion(assetIDs: [String]) {
    // 1. previewResult 직접 갱신 (excludedAssetIDs 건드리지 않음!)
    previewResult = previewResult.excluding(Set(assetIDs))

    // 2. 빈 stage 축소 (reloadData 전에 → 1회 리로드로 완료)
    if currentStage == .deep && previewResult.deepCandidates.isEmpty {
        currentStage = .standard
    }
    if currentStage == .standard && previewResult.standardCandidates.isEmpty {
        currentStage = .light
    }

    // 3. UI 갱신 — reloadData 1회
    collectionView.reloadData()

    // 4. 헤더/하단 업데이트
    updateHeader()
    updateBottomView()

    // 5. 전체 0장 → 자동 닫기
    if previewResult.count(upToStage: currentStage) == 0 {
        showAllExcludedAlert()  // "모든 사진이 제외되었습니다" → pop
    }

    // 6. [Analytics]
    analyticsExcludeCount += assetIDs.count
}
```

**confirm 애니메이션 → reloadData 타이밍**:
- 단일: `confirmDimmedAnimation` completion(0.15초 후) 안에서 `applySwipeExclusion` 호출
- 다중: 모든 셀 `confirmDimmedAnimation` 시작 → **0.2초 딜레이** → `applySwipeExclusion` 호출
- ⚠️ 딜레이 중 새 스와이프 차단: `isApplyingExclusion` 플래그로 guard

---

## Phase 3: 다중 스와이프 + 자동 스크롤

### 신규 파일: `PreviewGridViewController+MultiSwipe.swift`

**다중 모드 진입 조건**: 단일 스와이프 중 손가락이 **같은 photos 섹션**의 다른 셀에 도달

**⚠️ 핵심: 섹션 범위 제한**
- 다중 선택은 `swipeTargetSection` 내에서만 동작
- 배너 섹션이나 다른 photos 섹션으로 이동 시 → 마지막 유효 상태 유지
- 자동 스크롤은 계속 (같은 섹션의 위/아래 셀은 도달 가능)

**사각형 범위 선택** `calculateRectangleSelection()`:
- 같은 행: 열 범위만 (앵커 열~현재 열)
- 다른 행: 행 전체 (모든 열 × 행 범위)
- `item < candidates.count` 검증 (마지막 행 불완전 처리)

**확정**: `confirmMultiSwipeExclude()`:
1. 자동 스크롤 정지
2. 선택된 셀 assetID 수집 — **candidates[item].assetID** 직접 조회
3. 셀별 confirmDimmedAnimation 실행
4. `isApplyingExclusion = true` → 0.2초 딜레이 → `applySwipeExclusion(assetIDs:)`
5. `swipeDeleteState.reset()`

**자동 스크롤** (BaseSelectMode 패턴 복사):
- 상/하단 100pt 핫스팟, 200~1500pt/s 속도
- 60Hz 타이머
- 콜백에서 전달하는 좌표: `gesture.location(in: collectionView)` (collectionView 좌표)
- `handleAutoScroll(at:)`의 파라미터: `gesture.location(in: view)` (view 좌표) — 핫스팟 계산용

---

## ⚠️ 안전장치 (심층 리뷰 발견 사항)

### 1. Stage 전환 시 스와이프 강제 취소

expand/collapse가 섹션 구조를 변경하므로, 진행 중인 스와이프는 반드시 취소:

```swift
// previewBottomViewDidTapExpand, previewBottomViewDidTapCollapse에 추가:
cancelActiveSwipeIfNeeded()

func cancelActiveSwipeIfNeeded() {
    guard swipeDeleteState.swipeGesture != nil else { return }
    if swipeDeleteState.isMultiMode {
        cancelMultiSwipeDelete()  // 모든 딤드 해제 + 자동 스크롤 정지
    } else if let cell = swipeDeleteState.targetCell {
        cell.cancelDimmedAnimation { cell.isAnimating = false }
    }
    swipeDeleteState.reset()
}
```

### 2. 다중 스와이프 중 하단 버튼 차단

다중 모드에서 expand/collapse/cleanup 탭 방지:

```swift
// enterMultiSwipeMode()에 추가:
bottomView.isUserInteractionEnabled = false

// confirmMultiSwipeExclude(), cancelMultiSwipeDelete()에 추가:
bottomView.isUserInteractionEnabled = true
```

### 3. 스와이프 중 셀 탭(뷰어 열기) 차단

스와이프 진행 중 didSelectItemAt이 호출되면 무시:

```swift
// didSelectItemAt 맨 앞에 추가:
guard !swipeDeleteState.angleCheckPassed && !swipeDeleteState.isMultiMode else { return }
```

### 4. viewWillAppear에서 스와이프 상태 정리

뷰어에서 돌아올 때 잔여 스와이프 상태 정리:

```swift
// viewWillAppear에 추가:
cancelActiveSwipeIfNeeded()
```

### 5. 제외 적용 중 새 스와이프 차단

`applySwipeExclusion` → `reloadData` 사이에 새 스와이프 시작 방지:

```swift
// 프로퍼티:
var isApplyingExclusion: Bool = false

// gestureRecognizerShouldBegin에 추가:
if isApplyingExclusion { return false }

// applySwipeExclusion에서:
isApplyingExclusion = true
// ... reloadData 등 ...
isApplyingExclusion = false
```

### 6. 전체 사진 0장 처리

```swift
private func showAllExcludedAlert() {
    let alert = UIAlertController(
        title: "모든 사진이 제외되었습니다",
        message: nil,
        preferredStyle: .alert
    )
    alert.addAction(UIAlertAction(title: "확인", style: .default) { [weak self] _ in
        self?.navigationController?.popViewController(animated: true)
    })
    present(alert, animated: true)
}
```

---

## PreviewGridViewController.swift 본체 변경 요약

**프로퍼티 추가**:
```swift
var swipeDeleteState = SwipeDeleteState()
var swipeTargetSection: Int = 0
var isApplyingExclusion: Bool = false
var autoScrollTimer: Timer?
weak var autoScrollGesture: UIGestureRecognizer?
var autoScrollHandler: ((CGPoint) -> Void)?
var currentAutoScrollSpeed: CGFloat = 0
```

**viewDidLoad에 추가**: `setupSwipeDeleteGesture()`
**viewWillAppear에 추가**: `cancelActiveSwipeIfNeeded()`
**didSelectItemAt에 추가**: 스와이프 중 guard
**expand/collapse에 추가**: `cancelActiveSwipeIfNeeded()`

**접근제어 private → internal** (extension에서 접근 필요):
- `sectionType(for:)`, `collectionView`, `previewResult`, `currentStage`
- `columns`, `cellSpacing`, `analyticsExcludeCount`, `bottomView`
- `updateHeader()`, `updateBottomView()`

---

## 검증 확인 사항 (코드 리뷰 완료)

| 항목 | 상태 | 비고 |
|------|------|------|
| SwipeDeleteState 접근 | ✅ | BaseGridVC.swift에 internal struct |
| HapticFeedback 접근 | ✅ | Shared/Utils/HapticFeedback.swift |
| PreviewResult.excluding(_:) | ✅ | PreviewResult.swift:96, immutable 반환 |
| excludedAssetIDs 분리 | ✅ | 뷰어 전용 유지, 스와이프는 직접 갱신 |
| IndexPath section 하드코딩 | ✅ | 모든 곳에서 swipeTargetSection 사용 |
| stage 전환 시 스와이프 취소 | ✅ | expand/collapse에 cancelActiveSwipeIfNeeded 추가 |
| 다중 모드 중 버튼 차단 | ✅ | bottomView.isUserInteractionEnabled 제어 |
| 스와이프 중 뷰어 차단 | ✅ | didSelectItemAt guard 추가 |
| 전체 0장 처리 | ✅ | Alert → pop |

---

## Phase 4: 검증

| 항목 | 검증 방법 |
|------|----------|
| 우측 여백 제거 | 시뮬레이터 iPhone 13 Pro에서 좌우 대칭 확인 |
| light/standard/deep 레이아웃 | 3단계 모두 정상 그리드 확인 |
| 단일 스와이프 확정 | 수평 50%+ → 셀 제외 → 카운트 감소 |
| 단일 스와이프 취소 | 수평 50%- → spring 복귀 |
| 배너 차단 | 배너 셀에서 스와이프 시작 → 무반응 |
| 스크롤 정상 | 수직 드래그 → 스크롤만, 스와이프 미발동 |
| 다중 전환 | 같은 섹션 다른 셀 도달 → 사각형 선택 + 햅틱 |
| 섹션 경계 | 배너로 이동 → 선택 유지 (확장 안됨) |
| 자동 스크롤 | 상/하단 핫스팟에서 스크롤 + 범위 확장 |
| stage 축소 | 해당 등급 전부 제외 → 자동 축소 + 1회 reloadData |
| 전체 제외 | 0장 → Alert → pop |
| expand 중 스와이프 | expand 탭 → 진행 중 스와이프 자동 취소 |
| 다중 모드 중 expand | 하단 버튼 비활성 → 탭 불가 |
| 스와이프 중 셀 탭 | didSelectItemAt 무시 |
| 뷰어 복귀 후 | 스와이프 상태 정리 + applyExclusions 정상 |
| 빌드 | `xcodebuild -project SweepPic/SweepPic.xcodeproj -scheme SweepPic` |

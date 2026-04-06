# 온보딩 C/D 리디자인

> 작성일: 2026-04-03 ~ 04-06
> 배경: 간편정리 메뉴에 인물사진 비교정리 + 저품질 자동정리가 합쳐지면서 온보딩 C, D의 접근 방식이 변경됨

---

## 변경 배경

- **기존 D**: 자동정리 단독 버튼 → 이제 간편정리 메뉴 안에 포함
- **기존 C**: 뱃지 경로만 안내 → 이제 간편정리 버튼 경로도 안내 필요
- 사용자가 그리드 스크롤보다 버튼을 먼저 누르는 경우가 많을 것으로 예상

---

## 온보딩 전체 흐름 (변경 후)

```
앱 시작 → 유사사진 사전 분석 시작 (FaceScan 최신순, 백그라운드)
  ↓
A (첫 터치 → 그리드 스와이프 삭제 안내) → A Step 2 (멀티스와이프)
  ↓
A-1 (스와이프 실습 유도)
  ↓
E-1+E-2 (첫 삭제 → 삭제 시스템 안내)
  ↓
C (유사사진 비교정리 체험) → 자동 pop → 그리드 → 간편정리 안내
  ↓
D 사전 분석 시작 (C 완료 후에야 시작, 동시 분석 방지)
  ↓
D (저품질 자동정리 안내)
  ↓
B (뷰어 스와이프 삭제 안내 — 다음 뷰어 진입 시)
```

---

## 선행 조건 매트릭스

| 온보딩 | 선행 조건 | 트리거 |
|--------|----------|--------|
| A | 없음 | 첫 터치 |
| A-1 | A 완료 + E-1 미완료 | 3초 타이머 / 탭바·선택·간편정리 버튼 탭 시 즉시 |
| E-1+E-2 | 그리드 스와이프 삭제 성공 | 자동 |
| C | A 완료 + E-1 완료 | 뱃지 발견 / 간편정리 버튼 탭 |
| D | A 완료 + E-1 완료 + (**C 완료** 또는 **C 사전분석 완료+0건**) | 저품질 1장 이상 시 바로 표시 |
| B | B 미표시 + C2 대기 아님 | 뷰어 진입 + 페이지 스와이프 |

---

## C 온보딩 상세

### 사전 분석

- **시작 시점**: 앱 시작 시 즉시 (백그라운드, `.utility` 우선순위)
- **분석 방식**: FaceScan 최신순 프로세스와 동일
- **목표**: 유사사진 그룹 **1개** 확보 즉시 중단
- **구현 방식**: `CoachMarkDPreScanner` 패턴의 독립 스캐너 클래스
  - `SimilarityAnalysisQueue`와 독립적으로 동작 (경합 방지)
  - pause/resume 패턴으로 백그라운드 대응
  - 결과를 자체 프로퍼티에 보관
  - **발견한 그룹은 `SimilarityCache.shared`에도 반영** (뱃지 표시 + C-1 동작에 필요)

### 사전 분석 — 앱 종료/재시작 대응

- **백그라운드 진입**: pause (일시정지) → 포그라운드 복귀 시 resume (재개)
- **앱 완전 종료**: 분석 진행 상태를 디스크에 저장 (UserDefaults)
  - 마지막 분석 위치 (assetID/index)
  - 발견된 유사사진 유무 + 대표 assetID
- **앱 재시작 시**:
  - 이전 분석 완료 + 유사사진 있음 → 재분석 불필요, 저장된 결과 사용
  - 이전 분석 완료 + 유사사진 없음 → 사전 분석 재실행 불필요 (스크롤 기반 분석은 독립 동작)
  - 이전 분석 미완료 → 저장된 위치부터 이어서 분석

### 트리거 2가지

#### 1. 그리드 스크롤 중 뱃지 발견 (기존과 동일)
- 사전 분석 또는 스크롤 기반 분석으로 뱃지가 표시된 셀 발견 시
- `triggerCoachMarkCIfNeeded(for:)` 호출

#### 2. 간편정리 버튼 탭 (신규)
- C 미완료 상태에서 간편정리 버튼 탭 시 메뉴 차단
- **인터셉트 방식**: 기존 A-1 인터셉트 메커니즘 확장
  - iOS 26+: **간편정리 버튼만** `primaryAction`을 C용 로직으로 설정 (전체메뉴 버튼은 통과)
  - iOS 16~25: `rightButtonInterceptor`에서 C 조건 체크
  - 우선순위: A-1과 C는 조건이 겹치지 않음 (A-1은 E-1 미완료, C는 E-1 완료)
- 사전 분석 결과에 따라 분기:

| 상태 | 동작 |
|------|------|
| 분석 완료 + 유사사진 있음 | 뱃지 셀로 자동 스크롤 → C 시작 |
| 분석 중 + 이미 찾은 거 있음 | 뱃지 셀로 자동 스크롤 → C 시작 |
| 분석 중 + 아직 없음 | "비슷한 사진을 찾고 있어요" 로딩 → 발견 시 C 시작 / **타임아웃 5초** 시 메뉴 정상 진행 |
| 분석 완료 + 유사사진 없음 | 메뉴 정상 진행 |

### C 온보딩 흐름

```
C-1 (뱃지 셀 하이라이트) → 확인
  ↓
C-2 (뷰어 + 버튼 안내) → 확인
  ↓
C-3 (비교 화면 사용법) → 확인
  ↓
자동 pop (뷰어 → 그리드로 복귀)
  ↓
간편정리 버튼 하이라이트 (코치마크 오버레이)
  "간편정리 메뉴에서 더욱 편리하게 자동 탐색이 가능해요"
  ※ 상세 메뉴명(인물사진 비교정리 등)은 안내하지 않음
```

※ 자동 pop으로 그리드에 복귀하므로 뷰어에 머무는 순간이 없음 → B 딜레이 처리 불필요

### 유사사진 없는 사용자 처리

- 사전 분석 완료 후 결과 0건 → C를 markAsShown() **하지 않음**
- D 트리거 조건을 "C 완료 **또는** C 사전분석 완료+0건"으로 분기하여 D 언블록
- 사진이 나중에 추가되면 스크롤 기반 분석으로 뱃지가 뜨고 C가 자연스럽게 트리거될 수 있음

---

## D 온보딩 상세

### 사전 분석

- **시작 시점**: C 완료 후 (동시 분석 방지)
- **분석 방식**: 기존 `CoachMarkDPreScanner`와 동일
- **목표**: 저품질 사진 3장 확보

### 트리거 조건

- A 완료 + E-1 완료 + (**C 완료** 또는 **C 사전분석 완료+0건**) + 저품질 1장 이상
- ~~3초 체류 조건 제거~~ → 분석 결과 있으면 바로 표시
- C 완료와 D 표시 사이 별도 딜레이 불필요 (D 사전 분석 소요 시간이 자연스러운 간격)

### D 표시 내용

- 기존과 동일 (간편정리 버튼 하이라이트 + 저품질 사진 썸네일 + 안내)

---

## 코드 변경사항 (이미 적용)

| 파일 | 변경 | 비고 |
|------|------|------|
| `GridViewController+CoachMarkC.swift` | B 완료 가드 제거 | C 선행 조건: A + E-1만 |
| `GridViewController+SimilarPhoto.swift` | `shouldEnableSimilarPhoto()` B 가드 제거 | 유사사진 분석 활성화 조건 |
| `ViewerViewController+SimilarPhoto.swift` | `shouldEnableSimilarPhoto` B 가드 제거 | 뷰어 유사사진 활성화 조건 |
| `GridViewController+CoachMarkD.swift` | C 완료 가드 추가 | D 선행 조건: A + E-1 + C |
| `CoachMarkOverlayView+CoachMarkA2.swift` | A Step 2 텍스트 수정 | "가로로 밀면서 좌우/상하까지 더 선택하면" |
| `TabBarController.swift` | 온보딩 A 터치캐처 + A-1 인터셉트 | 첫 터치 시 A 표시, 버튼 탭 시 A-1 차단 |
| `GridViewController+Cleanup.swift` | 온보딩 리셋 메뉴 추가 | (테스트)리셋 → "온보딩 리셋" |

---

## 구현 계획 (v2)

### v1 테스트에서 발견된 버그

| # | 증상 | 원인 | 해결 |
|---|------|------|------|
| 1 | 간편정리 탭 → 스크롤 후 C-1 안 뜸 | `triggerCoachMarkCIfNeeded` 뱃지 재검증이 비동기 타이밍으로 실패 | 자동스크롤 경로: `showSimilarBadgeCoachMark` 직접 호출 |
| 2 | 간편정리 하이라이트 확인 → 탭 모션 + 먹통 | `showCleanupGuide`에 `.similarPhoto` 타입 → C 전용 시퀀스 실행 | `.autoCleanup` 타입 + confirmButton 타겟 교체 (dismiss 우회) |
| 3 | 그리드 복귀 시 C-1 오버레이 잔존 (공통) | C-3 생성 시 기존 C-1/C-2 오버레이를 제거하지 않음 | `showFaceComparisonGuide()`에서 `currentOverlay?.removeFromSuperview()` |
| 4 | C 미완료인데 D 표시 | `similarPhoto.markAsShown()`이 FaceComparison present 시 호출 | D 트리거에 `isAutoPopForC`/`pendingCleanupHighlight`/`pendingDAfterCComplete` 가드 |
| 5 | 하이라이트 dismiss 후 터치 불가 | `dismiss()` 내부 `.autoCleanup.markAsShown()` 호출 | dismiss() 호출 안 함 — 직접 fadeOut + removeFromSuperview |
| ~~6~~ | ~~C-1→C-2→C-3 전환 시 전 화면 잔존 (iOS 26+만)~~ | 기존 코드에서 이미 처리됨 (`startC_ConfirmSequence` alpha=0.01 + `transitionToC2` alpha 복원) | 수정 불필요 |

### iOS 버전별 차이점

| 항목 | iOS 16~25 | iOS 26+ |
|------|----------|---------|
| 뷰어 전환 | Modal present | Navigation push |
| 오버레이 가시성 | Modal 뒤에 숨겨짐 | window 위 → nav 위에 보임 (#6) |
| 뷰어 → 그리드 복귀 | dismiss → viewerDidClose() | pop → transitionCoordinator completion |
| 그리드 viewDidAppear | Modal dismiss 시 호출 안 될 수 있음 | Pop 시 호출됨 → D 트리거 주의 (#4) |
| 간편정리 인터셉트 | FloatingTitleBar.cleanupButtonInterceptor | items[1].primaryAction |
| 자동 pop | `dismiss(animated:)` | `popViewController(animated:)` |

---

### Phase 1: C 사전 분석

FaceScanService를 직접 활용하여 앱 시작 시 유사사진 1그룹을 백그라운드에서 찾아둔다.

**수정 파일:**

- [ ] `GridViewController+CoachMarkC.swift` — 사전 분석 메서드 추가
  - `startCoachMarkCPreScanIfNeeded()`: FaceScanService 활용, 1그룹 발견 즉시 cancel
  - `onGroupFound`: bridge → SimilarityCache.shared.addGroupIfValid → UserDefaults 저장
  - **순서**: SimilarityCache 반영 완료 → UserDefaults 저장 → `updateVisibleCellBorders()` → `onCPreScanStateChanged?()` 콜백
  - `cancel()` 후 `CancellationError`는 성공적 조기 종료로 처리
  - UserDefaults: `CoachMarkCPreScan.isComplete`, `CoachMarkCPreScan.foundAssetID`
  - `#if DEBUG debugResetCPreScan()` 메서드
- [ ] `GridViewController+SimilarPhoto.swift` — `updateVisibleCellBorders()` private → internal
- [ ] `GridViewController.swift` — viewDidAppear에 `startCoachMarkCPreScanIfNeeded()` 호출
- [ ] `GridViewController+Cleanup.swift` — 온보딩 리셋 메뉴에 C 사전분석 리셋 추가

---

### Phase 2: 간편정리 버튼 C 인터셉트 + 로딩 + 자동 스크롤

C 미완료 상태에서 간편정리 버튼 탭 시 메뉴를 차단하고, 사전 분석 결과에 따라 C를 트리거한다.

**수정 파일:**

- [ ] `FloatingTitleBar.swift` — iOS 16~25 간편정리 전용 인터셉터
  - `cleanupButtonInterceptor: (() -> Bool)?` 프로퍼티 추가
  - hitTest: selectButton(간편정리)에만 체크 → 전체메뉴(menuButton)는 통과
- [ ] `GridViewController+CoachMarkC.swift` — C 인터셉트 + 자동 스크롤 + 로딩
  - `enableCCleanupButtonIntercept()` / `disableCCleanupButtonIntercept()`
    - iOS 26+: `items[1].primaryAction` 설정/해제
    - iOS 16~25: `cleanupButtonInterceptor` 설정/해제
  - `handleCleanupInterceptForC()`: 사전 분석 상태 분기
    - 유사사진 있음 → `scrollToBadgeCellAndTriggerC(assetID:)`
    - 0건 → `cleanupButtonTapped()` (메뉴 정상)
    - 분석 중 → `showCPreScanLoading()` (5초 타임아웃)
  - **`scrollToBadgeCellAndTriggerC(assetID:)`** — **버그 #1 대응**
    - `scrollToCenteredItem` → 0.6초 딜레이
    - ~~`triggerCoachMarkCIfNeeded`~~ → **`showSimilarBadgeCoachMark(cell:assetID:)` 직접 호출**
    - `hasTriggeredC1 = true` 수동 설정, `showBadge(on:)` 수동 호출
    - (이유: `triggerCoachMarkCIfNeeded` 내부 뱃지 재검증이 비동기 `updateVisibleCellBorders` 완료 전에 실패)
  - `showCPreScanLoading()` / `dismissCPreScanLoading()`
    - 5초 DispatchWorkItem 타임아웃
    - `onCPreScanStateChanged` 콜백으로 그룹 발견/완료 감지
- [ ] `GridViewController.swift` — viewDidAppear에 `enableCCleanupButtonIntercept()` 호출

---

### Phase 3: C-3 자동 pop + B 가드 + 간편정리 하이라이트

C-3 확인 후 자동으로 그리드까지 복귀하고, 간편정리 버튼 안내를 표시한다.

**수정 파일:**

- [ ] `CoachMarkOverlayView.swift` — CoachMarkManager 프로퍼티 추가
  - `isAutoPopForC: Bool = false`
  - `pendingCleanupHighlight: Bool = false`
- [ ] `CoachMarkOverlayView+CoachMarkC3.swift`
  - **버그 #3 대응**: `showFaceComparisonGuide()` 진입부에 `currentOverlay?.removeFromSuperview()` (C-1/C-2 오버레이 제거)
  - Step 2 확인 시: `isAutoPopForC = true`, `pendingCleanupHighlight = true`, `dismiss()`
- [ ] `FaceComparisonViewController.swift` — C-3 dismiss 후 자동 dismiss
  - `showFaceComparisonGuide()` 마지막에 `currentOverlay?.onDismiss` 설정
  - `isAutoPopForC` 체크 → `self.dismiss(animated:)` 또는 `navigationController?.dismiss(animated:)`
- [ ] `ViewerViewController.swift` — viewDidAppear에서 자동 pop
  - `isAutoPopForC` 체크 → pop/dismiss + `return` (B, C-2 스킵)
  - `isPushed` 분기: iOS 26+ pop, iOS 16~25 dismiss
- [ ] `ViewerViewController+CoachMark.swift` — B 가드
  - `guard !CoachMarkManager.shared.isAutoPopForC` 추가
- [ ] `GridViewController+CoachMarkC.swift` — 그리드 복귀 + 간편정리 하이라이트
  - `showCleanupHighlightIfPending()`: 플래그 체크 → 리셋 → 0.3초 딜레이 → `showCleanupButtonHighlight()`
  - `showCleanupButtonHighlight()`: `getCleanupButtonFrame(in:)` → `showCleanupGuide()`
- [ ] `CoachMarkOverlayView+CoachMarkC.swift` — **버그 #2, #5 대응**: `showCleanupGuide()` static 메서드
  - 타입: `.autoCleanup` (pill shape 하이라이트 재사용)
  - **confirmButton 타겟 완전 교체** (기존 `confirmTapped` 제거):
    ```swift
    overlay.confirmButton.removeTarget(overlay, action: nil, for: .touchUpInside)
    overlay.confirmButton.addAction(UIAction { [weak overlay] _ in
        // dismiss() 호출 안 함 — .autoCleanup.markAsShown() 방지 (#5)
        CoachMarkManager.shared.currentOverlay = nil
        UIView.animate(withDuration: 0.2, animations: { overlay?.alpha = 0 }) { _ in
            overlay?.removeFromSuperview()
        }
        onConfirm()
    }, for: .touchUpInside)
    ```
  - 카드 구성 (D와 유사한 구조):
    - 타이틀: "간편정리 → 인물사진 비교정리" (1뎁스 → 2뎁스 메뉴 경로)
    - 본문: "간편정리 메뉴에서 더욱 편리하게 자동 탐색이 가능해요"
    - 확인 버튼
  - D 포커싱 애니메이션 재사용 → `animateDFocus` private → internal 변경 필요
- [ ] `GridViewController.swift` — 그리드 복귀 시점에 `showCleanupHighlightIfPending()` 호출
  - iOS 26+: transitionCoordinator completion 내부
  - iOS 16~25: `viewerDidClose()` 내부

---

### Phase 4: D 조건 변경

D 사전 분석을 C 완료 후로 지연하고, D 표시를 탭 전환 복귀 시로 제한한다.

**D 표시 타이밍:**
- C 완료 직후 D를 바로 표시하지 **않음** (연속 온보딩 피로)
- **D 표시 조건**: C 완료 + 그리드를 한번 떠났다 돌아올 때 (탭 전환, 뷰어 복귀 등)
- 구현: `pendingDAfterCComplete` 플래그를 **`viewWillDisappear`에서** 설정 (C 완료 상태 감지)
  - cleanup highlight onConfirm 시점이 아닌, 그리드를 **떠나는 시점**에 설정
  - → 같은 viewDidAppear 사이클에서 D가 즉시 트리거되는 문제 방지

**수정 파일:**

- [ ] `CoachMarkOverlayView.swift` — CoachMarkManager에 D 대기 플래그 추가
  - `pendingDAfterCComplete: Bool = false`
- [ ] `GridViewController+CoachMarkD.swift`
  - `startCoachMarkDPreScanIfNeeded()`: C 완료 가드 추가 — **버그 #4 대응**
    ```swift
    guard !CoachMarkManager.shared.isAutoPopForC,
          !CoachMarkManager.shared.pendingCleanupHighlight else { return }
    guard CoachMarkType.similarPhoto.hasBeenShown
          || Self.cPreScanCompleteWithNoGroups else { return }
    ```
  - `startCoachMarkDTimerIfNeeded()`: 3초 타이머 제거 → 즉시 체크
    - `isAutoPopForC`/`pendingCleanupHighlight` 가드 (#4)
    - `pendingDAfterCComplete` 가드: true일 때만 D 표시 허용
    - C 완료 가드: `similarPhoto.hasBeenShown || cPreScanCompleteWithNoGroups`
- [ ] `GridViewController+CoachMarkC.swift` — cleanup highlight onConfirm
  - `disableCCleanupButtonIntercept()`
  - `startCoachMarkDPreScanIfNeeded()` (사전 스캔만 시작, D 표시는 안 함)
  - ※ `pendingDAfterCComplete`는 여기서 설정하지 **않음** (viewWillDisappear에서 설정)
- [ ] `GridViewController.swift`
  - **viewWillDisappear**: C 완료 + D 미표시 시 `pendingDAfterCComplete = true` 설정
    ```swift
    if CoachMarkType.similarPhoto.hasBeenShown
       && !CoachMarkType.autoCleanup.hasBeenShown
       && !CoachMarkManager.shared.pendingDAfterCComplete {
        CoachMarkManager.shared.pendingDAfterCComplete = true
    }
    ```
  - **viewDidAppear**: 기존 `startCoachMarkDTimerIfNeeded()` 호출이 이미 있음 → 내부에서 `pendingDAfterCComplete` 체크

---

### 구현 순서

Phase 1 → Phase 2 → Phase 3 → Phase 4 (각 Phase 완료 시 커밋)

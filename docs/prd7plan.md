# PRD 7: 그리드 즉시 삭제/복원 구현 계획

## 개요
그리드 화면에서 선택 모드 진입 없이 스와이프/투 핑거 탭으로 사진을 즉시 삭제/복원하는 기능

## 핵심 파일

| 파일 | 변경 내용 | 추가 줄수 |
|------|-----------|----------|
| `GridViewController+Gestures.swift` | **SwipeDeleteState 구조체 + 모든 제스처 로직** | ~300줄 |
| `GridViewController.swift` | `var swipeDeleteState` 1줄 + `setupSwipeDeleteGestures()` 호출 1줄 | ~2줄 |
| `PhotoCell.swift` | 진행도 기반 딤드 애니메이션, 셀별 잠금 | ~100줄 |
| `TrashStore.swift` | completion handler API 추가 (FR-106 필수) | ~40줄 |
| `AlbumGridViewController.swift` | 스와이프/투핑거탭 제스처 (복제) | ~200줄 |
| 새 `HapticFeedback.swift` | 햅틱 유틸리티 | ~20줄 |
| 새 `ToastView.swift` | 토스트 메시지 | ~60줄 |

### 전제: GridViewController 파일 분할 (251231file.md)

PRD7 구현 전에 GridViewController.swift를 4개 파일로 분할:

```
Features/Grid/
├── GridViewController.swift           (~900줄) - 메인
├── GridViewController+SelectMode.swift (~500줄) - Select 모드
├── GridViewController+Scroll.swift    (~400줄) - 스크롤/초기표시
└── GridViewController+Gestures.swift  (~200줄→500줄) - 제스처 ← PRD7 여기에 구현
```

### 아키텍처 결정: 단순 복제

GridViewController와 AlbumGridViewController에 **각각 제스처 로직을 구현**합니다.

**이유**:
- 2개 VC에서만 사용 (휴지통 탭 제외)
- Swift Protocol Extension 제약: stored property ❌, @objc ❌
- Helper 클래스는 delegate 간접 참조로 오버엔지니어링
- ~200줄 × 2 = ~400줄 (관리 가능한 수준)
- 각 VC가 독립적으로 발전 가능 (선택 모드 유무 등 차이점 처리 용이)

---

## Phase 0: 공통 인프라 (선행 작업)

### T0-1: HapticFeedback 유틸리티
```
파일: PickPhoto/PickPhoto/Shared/Utils/HapticFeedback.swift

enum HapticFeedback {
    static func light()  // UIImpactFeedbackGenerator(.light) - 확정 시
    static func error()  // UINotificationFeedbackGenerator(.error) - 실패 시
}
```

### T0-2: ToastView 컴포넌트
```
파일: PickPhoto/PickPhoto/Shared/Components/ToastView.swift

- 하단에 메시지 표시, 2초 후 자동 사라짐
- "저장 실패. 다시 시도해주세요" 메시지용
```

### T0-3: TrashStore completion handler API 추가 (FR-106 필수)
```
파일: PickPhoto/PickPhoto/Features/Shared/TrashStore.swift

기존 동기 API 유지 + completion handler 버전 추가:

// 기존 (내부용, 성공 가정)
func moveToTrash(_ assetID: String)
func restore(_ assetID: String)

// 신규 (제스처용, 실패 시 롤백 가능)
func moveToTrash(_ assetID: String, completion: @escaping (Result<Void, Error>) -> Void)
func restore(_ assetID: String, completion: @escaping (Result<Void, Error>) -> Void)

실패 시나리오:
- 디스크 공간 부족
- 파일 시스템 오류
- JSON 인코딩 실패
```

### T0-4: PhotoCell 확장 - 진행도 기반 딤드 애니메이션
```
파일: PhotoCell.swift

추가할 프로퍼티:
- isAnimating: Bool (셀별 잠금)
- dimmedMaskLayer: CAShapeLayer (커튼 효과용)

추가할 메서드:
- setDimmedProgress(_ progress: CGFloat, direction: SwipeDirection, isTrashed: Bool)
  → 스와이프 거리에 따른 실시간 딤드 변화
  → 삭제: 손가락 뒤에서 빨간색이 채워짐
  → 복원: 손가락이 빨간색을 밀어냄

- confirmDimmedAnimation(toTrashed: Bool, completion: @escaping () -> Void)
  → 나머지 영역 빠르게 채움/걷힘 (0.15초)

- cancelDimmedAnimation(completion: @escaping () -> Void)
  → 원래 상태로 복귀 (0.2초 spring)

- fadeDimmed(toTrashed: Bool, completion: (() -> Void)?)
  → 투 핑거 탭용 페이드 인/아웃 (0.15초)
```

---

## Phase 1: 스와이프 삭제/복원

### T1-1: 스와이프 제스처 추가

#### GridViewController.swift (메인) - 1줄만 추가
```swift
// MARK: - Properties 섹션에 추가
var swipeDeleteState = SwipeDeleteState()
```

#### GridViewController+Gestures.swift - 나머지 전부
```swift
// MARK: - Swipe Delete State

/// 스와이프 삭제 상태 (extension에서 stored property 불가 → 구조체로 묶음)
struct SwipeDeleteState {
    var swipeGesture: UIPanGestureRecognizer?
    var twoFingerTapGesture: UITapGestureRecognizer?
    weak var targetCell: PhotoCell?
    var targetIndexPath: IndexPath?
    var targetIsTrashed: Bool = false

    // 상수 (PRD 7 스펙)
    static let angleThreshold: CGFloat = 15.0 * .pi / 180.0
    static let minimumTranslation: CGFloat = 10.0
    static let confirmRatio: CGFloat = 0.5
    static let confirmVelocity: CGFloat = 800.0
}

// MARK: - Swipe Delete Setup

extension GridViewController {
    /// 스와이프/투핑거탭 제스처 설정 (setupGestures()에서 호출)
    func setupSwipeDeleteGestures() {
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeDelete(_:)))
        swipe.delegate = self
        collectionView.addGestureRecognizer(swipe)
        swipeDeleteState.swipeGesture = swipe

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        tap.numberOfTouchesRequired = 2
        tap.delegate = self
        collectionView.addGestureRecognizer(tap)
        swipeDeleteState.twoFingerTapGesture = tap

        updateSwipeDeleteGestureEnabled()
    }

    func updateSwipeDeleteGestureEnabled() {
        let enabled = !isSelectMode && !UIAccessibility.isVoiceOverRunning
        swipeDeleteState.swipeGesture?.isEnabled = enabled
        swipeDeleteState.twoFingerTapGesture?.isEnabled = enabled
    }
}
```

#### GridViewController.swift - setupGestures() 수정
```swift
private func setupGestures() {
    // 기존 핀치 줌...

    // PRD7: 스와이프/투핑거탭 제스처 (+Gestures.swift에서 구현)
    setupSwipeDeleteGestures()
}
```

### T1-2: 스와이프 로직 상세
```
@objc private func handleSwipeDelete(_ gesture: UIPanGestureRecognizer):

.began:
  - 터치 위치 → indexPath 계산
  - 패딩 셀/빈 영역 체크 → indexPath == nil이면 무시
  - cell.isAnimating 체크 → true면 무시
  - swipeDeleteState.targetCell/targetIndexPath/targetIsTrashed 저장
  - cell.isAnimating = true

.changed:
  - |translation.x| < 10pt면 각도 판정 보류 (미세 움직임)
  - |translation.x| >= 10pt 후 각도 판정:
    - angle = atan2(abs(translation.y), abs(translation.x))
    - angle > SwipeDeleteState.angleThreshold이면 제스처 취소 (스크롤로 전환)
  - 각도 통과 시 progress 계산 (0.0~1.0)
  - cell.setDimmedProgress(progress, direction, isTrashed)

.ended:
  - 확정 조건: |translation.x| >= cellWidth * SwipeDeleteState.confirmRatio OR |velocity.x| >= SwipeDeleteState.confirmVelocity
  - 확정 시:
    cell.confirmDimmedAnimation(toTrashed: !isTrashed) { [weak self] in
        // TrashStore 호출 (completion handler 사용)
        trashStore.moveToTrash(assetID) { result in
            switch result {
            case .success:
                HapticFeedback.light()
                cell.isAnimating = false  // ✅ completion에서 해제
            case .failure:
                self?.rollbackSwipeCell()  // 롤백 처리 (T3-4)
            }
        }
    }
  - 취소 시:
    cell.cancelDimmedAnimation {
        cell.isAnimating = false  // ✅ completion에서 해제
    }

.cancelled:
  - cell.cancelDimmedAnimation {
      cell.isAnimating = false  // ✅ completion에서 해제
  }
```

### T1-3: gestureRecognizerShouldBegin 확장
```
기존 UIGestureRecognizerDelegate에 스와이프 조건 추가:

func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
    if gestureRecognizer == swipeDeleteState.swipeGesture {
        // 스크롤 momentum 중이면 무시
        if collectionView.isDecelerating { return false }

        // 터치 위치에 셀이 없으면 무시 (빈 영역)
        guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
        let location = pan.location(in: collectionView)
        guard collectionView.indexPathForItem(at: location) != nil else { return false }

        // ⚠️ 각도 판정은 여기서 하지 않음 (translation이 0에 가까움)
        // → .changed에서 10pt 이동 후 판정

        // velocity 기반 힌트만 제공 (느슨하게)
        let velocity = pan.velocity(in: collectionView)
        let angle = atan2(abs(velocity.y), abs(velocity.x))
        return angle < (30.0 * .pi / 180.0)  // 느슨하게 허용
    }
    // 기존 dragSelectGesture 로직...
}
```

---

## Phase 2: 투 핑거 탭 삭제/복원

### T2-1: 투 핑거 탭 핸들러 구현
```
※ 제스처 등록은 Phase 1의 setupSwipeDeleteGestures()에서 완료

파일: GridViewController+Gestures.swift

extension GridViewController {
    @objc func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        // 두 터치 위치 확인
        let touch0 = gesture.location(ofTouch: 0, in: collectionView)
        let touch1 = gesture.location(ofTouch: 1, in: collectionView)

        // 같은 셀인지 확인 + 빈 영역/패딩 셀 방어
        guard let ip0 = collectionView.indexPathForItem(at: touch0),
              let ip1 = collectionView.indexPathForItem(at: touch1),
              ip0 == ip1,
              assetID(at: ip0) != nil  // ✅ 패딩 셀 방어
        else { return }

        // 셀 가져오기 및 잠금 체크
        guard let cell = collectionView.cellForItem(at: ip0) as? PhotoCell,
              !cell.isAnimating else { return }

        // 삭제/복원 실행 (completion handler로 잠금 해제)
        cell.isAnimating = true
        let isTrashed = self.isTrashed(at: ip0)
        let toTrashed = !isTrashed

        cell.fadeDimmed(toTrashed: toTrashed) { [weak self] in
            guard let self = self, let assetID = self.assetID(at: ip0) else {
                cell.isAnimating = false
                return
            }

            let operation = toTrashed ? self.trashStore.moveToTrash : self.trashStore.restore
            operation(assetID) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success:
                        HapticFeedback.light()  // ✅ 성공 햅틱
                        cell.isAnimating = false  // ✅ completion에서 해제
                    case .failure:
                        self.rollbackTwoFingerTapCell(cell, toOriginalTrashed: isTrashed)
                    }
                }
            }
        }
    }
}
```

### T2-2: PhotoCell - fadeDimmed 메서드
```
파일: PhotoCell.swift

func fadeDimmed(toTrashed: Bool, duration: TimeInterval = 0.15, completion: (() -> Void)? = nil) {
    UIView.animate(withDuration: duration) {
        self.dimmedOverlayView.alpha = toTrashed ? Self.dimmedOverlayAlpha : 0
        self.dimmedOverlayView.isHidden = false
    } completion: { _ in
        if !toTrashed {
            self.dimmedOverlayView.isHidden = true
        }
        completion?()
    }
}
```

---

## Phase 3: 통합 및 안정화

### T3-1: VoiceOver 감지
```
파일: GridViewController.swift (Observer 등록)
      GridViewController+Gestures.swift (제스처 활성화/비활성화)

viewDidLoad():
  NotificationCenter.default.addObserver(
    self,
    selector: #selector(voiceOverStatusChanged),
    name: UIAccessibility.voiceOverStatusDidChangeNotification,
    object: nil
  )
  updateSwipeDeleteGestureEnabled()

@objc func voiceOverStatusChanged() {
    updateSwipeDeleteGestureEnabled()
}

// GridViewController+Gestures.swift에 구현
func updateSwipeDeleteGestureEnabled() {
    let disabled = UIAccessibility.isVoiceOverRunning || isSelectMode
    swipeDeleteState.swipeGesture?.isEnabled = !disabled
    swipeDeleteState.twoFingerTapGesture?.isEnabled = !disabled
}
```

### T3-2: 앱 백그라운드 진입 시 스와이프 취소
```
⚠️ UIGestureRecognizer.state는 읽기 전용 → 직접 설정 불가
→ 활성 셀 추적 + 수동 취소 애니메이션

GridViewController+Gestures.swift에 추가:

/// 진행 중인 스와이프 취소 (백그라운드 진입 등)
func cancelActiveSwipe() {
    guard let cell = swipeDeleteState.targetCell else { return }
    cell.cancelDimmedAnimation {
        cell.isAnimating = false
    }
    swipeDeleteState.targetCell = nil
    swipeDeleteState.targetIndexPath = nil
}

GridViewController.swift viewDidLoad에 Observer 등록:

NotificationCenter.default.addObserver(
    self,
    selector: #selector(appDidEnterBackground),
    name: UIApplication.didEnterBackgroundNotification,
    object: nil
)

@objc func appDidEnterBackground() {
    cancelActiveSwipe()  // ✅ 활성 스와이프 취소
}
```

### T3-3: AlbumGridViewController 적용 (복제)
```
파일: AlbumGridViewController.swift

GridViewController의 제스처 로직을 복제:

1. 프로퍼티 추가 (GridViewController와 동일):
   private var swipeDeleteGesture: UIPanGestureRecognizer?
   private var twoFingerTapGesture: UITapGestureRecognizer?
   private weak var swipeTargetCell: PhotoCell?
   private var swipeTargetIndexPath: IndexPath?
   private var swipeTargetIsTrashed: Bool = false

2. setupGestures() 추가:
   - 스와이프 제스처 등록
   - 투 핑거 탭 제스처 등록
   - updateSwipeDeleteGestureEnabled() 호출

3. 핸들러 복제:
   - handleSwipeDelete(_:)
   - handleTwoFingerTap(_:)
   - gestureRecognizerShouldBegin 확장

4. VoiceOver 연동 (선택 모드 없으므로 단순):
   func updateSwipeDeleteGestureEnabled() {
       let enabled = !UIAccessibility.isVoiceOverRunning
       swipeDeleteGesture?.isEnabled = enabled
       twoFingerTapGesture?.isEnabled = enabled
   }

※ 차이점: isSelectMode 체크 없음 (선택 모드가 없으므로)
```

### T3-4: TrashStore 실패 시 롤백 (FR-106 필수)
```
GridViewController+Gestures.swift에 롤백 메서드 추가:

/// 스와이프 롤백 처리
func rollbackSwipeCell() {
    guard let cell = swipeDeleteState.targetCell else { return }
    let originalTrashed = swipeDeleteState.targetIsTrashed

    // 1. UI 롤백 애니메이션
    if originalTrashed {
        // 원래 삭제 상태였는데 복원 시도 실패 → 다시 딤드 표시
        cell.fadeDimmed(toTrashed: true) {
            cell.isAnimating = false
        }
    } else {
        // 원래 정상 상태였는데 삭제 시도 실패 → 딤드 제거
        cell.cancelDimmedAnimation {
            cell.isAnimating = false
        }
    }

    // 2. 에러 햅틱
    HapticFeedback.error()

    // 3. 토스트 메시지
    ToastView.show("저장 실패. 다시 시도해주세요", in: view.window)

    // 4. 상태 초기화
    swipeDeleteState.targetCell = nil
    swipeDeleteState.targetIndexPath = nil
}

/// 투 핑거 탭 롤백 처리
func rollbackTwoFingerTapCell(_ cell: PhotoCell, toOriginalTrashed: Bool) {
    // 1. UI 롤백 애니메이션
    cell.fadeDimmed(toTrashed: toOriginalTrashed) {
        cell.isAnimating = false
    }

    // 2. 에러 햅틱
    HapticFeedback.error()

    // 3. 토스트 메시지
    ToastView.show("저장 실패. 다시 시도해주세요", in: view.window)
}

호출 위치:
- T1-2 handleSwipeDelete .ended에서 TrashStore 실패 시
- T2-1 handleTwoFingerTap에서 TrashStore 실패 시
```

---

## 제스처 충돌 해결 요약

| 제스처 | 조건 | 판정 시점 |
|--------|------|---------|
| 스와이프 삭제 | 수평 ±15° 이내, 10pt 이상 이동 | `.changed`에서 10pt 후 각도 판정 |
| 스크롤 | 수직/대각선 드래그 | 기본 동작 |
| 투 핑거 탭 | 두 손가락 동시 터치, 같은 셀, assetID 존재 | iOS 기본 인식 |
| 핀치 줌 | 두 손가락 + 이동 | iOS 기본 인식 |

```swift
// gestureRecognizerShouldBegin: 사전 필터링만 (느슨하게)
if gestureRecognizer == swipeDeleteState.swipeGesture {
    // 1. 스크롤 momentum 중 → false
    // 2. 터치 위치에 셀 없음 → false
    // 3. velocity 기반 힌트 (30° 이내, 느슨하게 허용)
}

// .changed: 정밀 각도 판정 (10pt 이동 후)
// 1. |translation.x| < 10pt → 판정 보류
// 2. |translation.x| >= 10pt 후:
//    angle = atan2(abs(translation.y), abs(translation.x))
//    angle > SwipeDeleteState.angleThreshold → 제스처 취소
```

---

## 예상 작업량

| Phase | 파일 | 추가 줄수 |
|-------|------|----------|
| 0 | HapticFeedback.swift (신규) | ~20줄 |
| 0 | ToastView.swift (신규) | ~60줄 |
| 0 | TrashStore.swift (completion API) | ~40줄 |
| 0 | PhotoCell.swift | ~100줄 |
| 1~2 | GridViewController+Gestures.swift | ~300줄 |
| 1~2 | GridViewController.swift | **~2줄** |
| 3 | AlbumGridViewController.swift | ~200줄 |
| **합계** | | **~720줄** |

### 파일별 최종 예상 줄수

| 파일 | 분할 직후 | PRD7 후 | 증가 |
|------|----------|---------|------|
| GridViewController.swift | ~900줄 | ~902줄 | **+2줄** |
| GridViewController+Gestures.swift | ~200줄 | ~450줄 | +250줄 |
| AlbumGridViewController.swift | 기존 | +200줄 | +200줄 |

---

## 테스트 체크리스트 (PRD TC-101~116)

- [ ] TC-101: 스와이프 삭제 (50% 이상)
- [ ] TC-102: 스와이프 복원
- [ ] TC-103: 스와이프 취소 (30% + 느린 속도)
- [ ] TC-104: 빠른 스와이프 (800pt/s 이상)
- [ ] TC-105: 투 핑거 탭 삭제
- [ ] TC-106: 투 핑거 탭 복원
- [ ] TC-107: 선택 모드에서 비활성화
- [ ] TC-108: 핀치 줌과 구분
- [ ] TC-109: 연속 스와이프 삭제
- [ ] TC-110: 스와이프 중 다른 셀로 이동 (시작 셀만 동작)
- [ ] TC-111: 스크롤 momentum 중 스와이프 무시
- [ ] TC-112: 두 손가락이 다른 섬네일에서 탭 (무시)
- [ ] TC-113: TrashStore 저장 실패 시 롤백 (에러 햅틱 + 토스트 + UI 복원)
- [ ] TC-114: VoiceOver 활성화 시 제스처 비활성화
- [ ] TC-115: 스와이프 중 앱 백그라운드 진입 (취소)
- [ ] TC-116: 대각선 드래그 시 스크롤 처리

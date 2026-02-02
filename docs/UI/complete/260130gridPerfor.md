# 유사사진 분석 성능 저하 조사

> **✅ 완료** — 근본 원인 확인됨: LiquidGlass MTKView Metal 리소스가 PHCachingImageManager 캐시와 경쟁.
> 해결 구현은 [260131LiquidPerfor1.md](260131LiquidPerfor1.md) (Phase 1~6)에서 진행 완료.

## 현상

- 그리드 화면에서 스크롤 멈춤 → 유사사진 분석 → 테두리 표시까지의 시간이 체감상 크게 느려짐
- LiquidGlass UI 수정, AutoCleanup(정리) 기능 추가 이후 인지됨

## 성능 측정 결과

### 측정 환경

- `SimilarityAnalysisQueue.performanceLoggingEnabled = true`
- 동일 기기, 동일 3개 화면에서 스크롤 멈춤 테스트
- **현재**: `001-auto-cleanup` 브랜치 (HEAD)
- **과거**: `8563973` 커밋 (2026-01-20, LiquidGlass/AutoCleanup 이전)

### 비교 데이터

#### #1 — 얼굴 없는 화면 (Photos: 25, Faces: 0)

|  | 과거 (8563973) | 현재 | 배율 |
|---|---|---|---|
| FP Generation | 330ms (13.2ms/장) | 766ms (30.7ms/장) | **2.3x** |
| Face Detect+Match | 827ms | 1168ms | **1.4x** |
| **Total** | **1159ms** | **1972ms** | **1.7x** |

#### #2 — 얼굴 있는 화면 (Photos: 35, Faces: 7)

|  | 과거 (8563973) | 현재 | 배율 |
|---|---|---|---|
| FP Generation | 170ms (4.9ms/장) | 688ms (19.7ms/장) | **4.0x** |
| Face Detect+Match | 206ms (29.4ms/face) | 1530ms (218.7ms/face) | **7.4x** |
| **Total** | **376ms** | **2220ms** | **5.9x** |

#### #3 — 얼굴 많은 화면 (Photos: 38, Faces: 32)

|  | 과거 (8563973) | 현재 | 배율 |
|---|---|---|---|
| FP Generation | 179ms (4.7ms/장) | 732ms (19.3ms/장) | **4.1x** |
| Face Detect+Match | 420ms (13.1ms/face) | 2361ms (73.8ms/face) | **5.6x** |
| **Total** | **601ms** | **3177ms** | **5.3x** |

### 핵심 관찰

1. **FP Generation과 Face Detect+Match 모두** 느려짐 → 공통 원인 존재 가능성
2. **PHCachingImageManager 캐시 효과 감소**:
   - 과거: #1(330ms) → #2(170ms) — 캐시 히트로 **절반 감소**
   - 현재: #1(766ms) → #2(688ms) — **10%만 감소** (캐시 효과 거의 없음)
3. #1(첫 실행, 캐시 미스) 기준에서도 1.7~2.3배 느림 → 캐시 외 기본 성능도 저하

---

## 분리 측정 (Phase 2)

### 추가된 로깅

`generateFeaturePrints`, `formGroupsForRange`, `assignPersonIndicesForGroup`에 단계별 분리 측정 추가:

- **FP Generation**: 이미지 로딩 시간 vs FP 연산 시간 (병렬 task 누적 합)
- **Face Detect+Match**: Vision 감지 시간 vs YuNet+SFace 매칭 시간
- **YuNet+SFace 내부**: 2차 이미지 로딩 / YuNet 감지 / FaceAligner+SFace 임베딩

### 분리 측정 결과 (현재 HEAD)

#### FP Generation Breakdown

| | #1 (25장) | #2 (35장) |
|---|---|---|
| Image Loading | 2287ms sum (91.5ms/장) — **60%** | 1841ms sum (52.6ms/장) — **56%** |
| FP Computation | 1522ms sum (60.9ms/장) — 40% | 1442ms sum (41.2ms/장) — 44% |
| Wall-clock | 798ms | 805ms |

> 병렬 task 5개의 누적 합이므로 wall-clock의 ~5배. 비율(60:40)이 핵심.

**이미지 로딩이 FP Generation의 60%를 차지** — PHCachingImageManager 이미지 로딩이 주요 병목.

#### Face Detect+Match Breakdown (#2 기준)

| 구간 | 시간 |
|---|---|
| Vision Detect (얼굴 감지) | 838ms |
| YuNet+SFace Assign (매칭) | 947ms |
| **합계** | **1785ms** (Total 1860ms의 96%) |

#### YuNet+SFace 내부 Breakdown (#2, 5개 그룹 합산)

| 구간 | 시간 |
|---|---|
| Image Loading (2nd) | 421ms (5그룹 합) |
| YuNet Detection | 318ms |
| Align+Embed (SFace) | 206ms |
| **합계** | **944ms** ≈ wall-clock 947ms ✓ |

2차 이미지 로딩은 21~33ms/장으로 1차(52~91ms)보다 빠름 — 캐시가 부분적으로 작동.

---

## 가설 검증 실험

### 실험 1: degraded 이미지 스킵 제거

**가설**: `SimilarityImageLoader`의 degraded 체크(commit `33f6c82`)가 fast-path 캐시 응답을 건너뛰어 성능 저하 유발.

**방법**: degraded 체크 코드 주석 처리 후 동일 테스트.

| #1 (25장) | 현재 HEAD | degraded OFF | 차이 |
|---|---|---|---|
| FP Gen | 798ms | 720ms | -10% |
| Total | 2146ms | 1957ms | -9% |

| #2 (38장) | 현재 HEAD | degraded OFF | 차이 |
|---|---|---|---|
| FP Gen | 805ms | 734ms | -9% |
| Total | 2686ms | 2754ms | +3% |

**결론: 원인 아님.** 10% 미만 개선. 과거 대비 2~4배 차이를 설명하지 못함.

### 실험 2: loadImage 전체를 과거 방식으로 교체

**가설**: `withTaskCancellationHandler`, NSLock, 이중 continuation 등 `loadImage` 구조 변경이 복합적으로 성능 저하 유발.

**방법**: `SimilarityImageLoader.loadImage`를 commit `8563973`의 원본 구현으로 완전 교체.

과거 방식:
```swift
withCheckedThrowingContinuation { continuation in
    imageManager.requestImage(...) { image, info in
        // 바로 resume (degraded 체크 없음, lock 없음, 취소 핸들러 없음)
    }
}
```

| | 과거 (8563973) | 현재 HEAD | loadImage 과거방식 | 차이 (HEAD vs 과거방식) |
|---|---|---|---|---|
| **#1** FP Gen | **330ms** | 798ms | 786ms | -2% |
| **#1** Total | **1159ms** | 2146ms | 2033ms | -5% |
| **#2** FP Gen | **170ms** | 805ms | 716ms | -11% |
| **#2** Total | **376ms** | 2686ms | 2712ms | +1% |
| **#3** FP Gen | **179ms** | 732ms | 689ms | -6% |
| **#3** Total | **601ms** | 3177ms | 3115ms | -2% |

**결론: 원인 아님.** `loadImage` 코드를 완전히 과거로 되돌려도 성능이 거의 동일. 분석 코드 자체의 변경은 성능 저하의 원인이 아님.

---

## 코드 변경 분석

### 8563973 → HEAD 사이 유사사진 분석 관련 변경

| 커밋 | 날짜 | 변경 내용 | 성능 영향 평가 |
|---|---|---|---|
| `33f6c82` | 1/22 | SimilarityImageLoader: degraded 체크 추가, 타임아웃 방식 변경 | **실험 1에서 10% 미만 확인** |
| `384d522` | 1/27 | FaceButtonOverlay: debugFlag 제거 → Log.debug() 상시 호출 | 없음 (뷰어 전용) |
| `aecfbb6` | 1/27 | SimilarityAnalysisQueue: print() → Log.print() 치환 (~10곳) | 없음 (로그만) |
| `9b1a981` | 1/29 | showBorder에 isScrolling 방어 코드 추가 | 없음 (가드 조건만) |
| `b69ff07` | 1/29 | performanceLoggingEnabled = false | 없음 |
| `018a380` | 1/30 | Task 취소 기능 구현 (withThrowingTaskGroup, checkCancellation) | **git diff 확인: 세마포어는 과거에도 있었음** |
| `bd6577a` | 1/30 | SimilarityImageLoader에 withTaskCancellationHandler + NSLock 추가 | **실험 2에서 영향 없음 확인** |

### 제외된 원인

- **AutoCleanup 리소스 경쟁**: AutoCleanup은 수동 트리거(버튼)이므로 그리드 스크롤 중 경쟁 없음
- **LiquidGlassOptimizer**: 측정 시점(8563973)에는 `#if DEBUG`로 감싸져 있어 릴리스에서 미동작
- **SimilarityImageLoader degraded 체크**: 실험 1에서 10% 미만 영향 확인
- **SimilarityImageLoader 구조 변경**: 실험 2에서 영향 없음 확인 (과거 코드로 완전 교체해도 동일)
- **generateFeaturePrints 변경 (withThrowingTaskGroup)**: 세마포어는 과거에도 있었고, 취소 체크 오버헤드는 미미
- **LiquidGlass MTKView GPU 경쟁**: MTKView는 1회 렌더 후 정지하므로 지속적 경쟁 아님

### 주요 코드 차이 (SimilarityImageLoader.loadImage)

```
[과거]
withCheckedThrowingContinuation { continuation in
    imageManager.requestImage(...) { image, info in
        // 바로 resume
    }
}

[현재]
withTaskCancellationHandler {
    withCheckedThrowingContinuation { continuation in
        let requestID = imageManager.requestImage(...) { image, info in
            self.lock.lock()          // lock 획득
            // hasResumed 체크
            // isTimeout 체크
            self.lock.unlock()        // lock 해제
            // resume
        }
        self.lock.lock()              // requestID 저장
        self.activeRequestIDs[requestUUID] = requestID
        self.lock.unlock()
    }
} onCancel: {
    self.lock.lock()                  // 취소 시 lock
    // cancelImageRequest
    self.lock.unlock()
}
```

### 주요 코드 차이 (SimilarityAnalysisQueue.generateFeaturePrints)

```
[과거] withTaskGroup (non-throwing)
- 단순 병렬 실행, 에러 시 nil 반환
- 세마포어 있음 (AsyncSemaphore)

[현재] withThrowingTaskGroup
- child task 시작 시 Task.checkCancellation() x2
- CancellationError catch/전파 로직 추가
- 결과 수집 시 Task.isCancelled 체크
- 세마포어 동일 (AsyncSemaphore)
```

---

## 실험 3: LiquidGlass MTKView pause 유지

**가설**: 스크롤 종료 시 `LiquidGlassOptimizer.restore()`가 MTKView를 재활성화하면서, Metal 리소스가 PHCachingImageManager 캐시 성능을 저하시킴.

**방법**: `GridScroll.swift`의 `scrollDidEnd()`에서 `restore()` 호출을 주석 처리. 스크롤 종료 후에도 MTKView가 pause 상태를 유지하도록 변경.

**참고**: 그리드 셀(PhotoCell)에는 LiquidGlass/MTKView가 없음. MTKView는 플로팅 UI(탭바, 글래스 버튼 등)에 존재하며, `LiquidGlassOptimizer`가 스크롤 시 이들을 pause/restore하는 구조.

### 실험 결과

| | 과거 (8563973) | 현재 HEAD | MTKView pause 유지 | HEAD vs pause 유지 |
|---|---|---|---|---|
| **#1** FP Gen | 330ms | 766ms | 834ms | +9% |
| **#1** Total | 1159ms | 1972ms | 2053ms | +4% |
| **#2** FP Gen | **170ms** | 688ms | **183ms** | **-73%** ✅ |
| **#2** Total | **376ms** | 2220ms | **829ms** | **-63%** ✅ |
| **#3** FP Gen | **179ms** | 732ms | **207ms** | **-72%** ✅ |
| **#3** Total | **601ms** | 3177ms | **1295ms** | **-59%** ✅ |

### 메모리 측정

| | Memory Start | Memory End | Delta |
|---|---|---|---|
| #1 | 139.9MB | 240.3MB | +100.4MB |
| #2 | 262.0MB | 228.2MB | -33.8MB |
| #3 | 218.3MB | 214.9MB | -3.4MB |

### 핵심 발견

1. **FP Generation이 과거 수준으로 회복**: #2(183ms vs 170ms), #3(207ms vs 179ms) — 거의 동일
2. **캐시 효과 완전 회복**: #1(834ms) → #2(183ms)로 **78% 감소**. 과거(48%)보다 오히려 더 좋음
3. **#1(콜드 스타트)만 여전히 느림**: 834ms vs 과거 330ms — 캐시 워밍 전 상태에서 다른 요인 존재
4. **Face Detect+Match도 크게 개선**: #2(645ms vs 2220ms), #3(1086ms vs 3177ms)

**결론: 원인 확인됨.** LiquidGlass MTKView의 `restore()`(재활성화)가 Metal 리소스를 점유하면서 PHCachingImageManager 캐시 성능을 저하시키고 있었음. MTKView를 pause 상태로 유지하면 캐시가 정상 작동하여 과거 수준의 성능 회복.

---

## 최종 결론

### 근본 원인

**LiquidGlass MTKView의 Metal 리소스가 PHCachingImageManager 캐시와 경쟁.**

- 스크롤 종료 시 `LiquidGlassOptimizer.restore()`가 MTKView를 재활성화
- 활성화된 MTKView의 Metal 텍스처/버퍼가 시스템 메모리를 점유
- PHCachingImageManager의 캐시 크기가 축소되어 이미지 로딩 성능 저하
- 특히 캐시 히트율이 급감 (과거 50% → 현재 10%)

### 해결 방향

분석 실행 중 MTKView를 pause 상태로 유지:
- 스크롤 종료 → `restore()` 지연 (분석 완료 후 호출)
- 또는 분석 시작 시 `optimize()` 호출, 완료 시 `restore()` 호출
- 사용자 체감 영향: 플로팅 UI의 굴절 효과가 분석 중(1~3초) blur로 대체됨 — 실질적으로 눈치채기 어려운 수준

### 제외된 원인 (검증 완료)

- ~~SimilarityImageLoader degraded 체크~~ (실험 1: 10% 미만)
- ~~SimilarityImageLoader 구조 변경~~ (실험 2: 영향 없음)
- ~~SimilarityAnalysisQueue 코드 변경~~ (실험 2: 영향 없음)
- ~~AutoCleanup 리소스 경쟁~~ (수동 트리거이므로 해당 없음)
- ~~LiquidGlass MTKView GPU 경쟁~~ (1회 렌더 후 정지하므로 GPU는 아님 — **메모리가 원인**)

---

## 해결 구현: LiquidGlass restore 타이밍 최적화

### 변경 전 흐름 (문제)

```
T+50ms: scrollDidEnd
  → restore 즉시 호출 (Metal 활성화)
  → debounce 0.3초 스케줄
T+300ms: glass visible
T+350ms: 분석 시작 (Metal 이미 300ms째 활성 → 캐시 경쟁 → 느림)
```

### 변경 후 흐름

```
T+50ms: scrollDidEnd
  → restore 호출 안 함
  → debounce 0.3초 스케줄
T+350ms: debounce 발동
  → 분석 시작 (MTKView 아직 paused → 캐시 경쟁 없이 빠름)
  → restore 호출 (Metal 활성화 시작)
T+600ms: glass visible
```

추가 blur 시간: **~0.3초** (debounce 구간만큼)

### 수정 파일 및 내용

#### 1. GridScroll.swift (line 138-139)

**변경**: `LiquidGlassOptimizer.restore()` 호출 제거

```swift
// Before:
// [LiquidGlass 최적화] 스크롤 종료 시 최적화 해제
LiquidGlassOptimizer.restore(in: self.view.window)

// After:
// [LiquidGlass 최적화] restore를 분석 debounce 콜백으로 이동 (성능 최적화)
// → GridViewController+SimilarPhoto.swift의 handleSimilarPhotoScrollEnd()에서 처리
```

#### 2. GridViewController+SimilarPhoto.swift — handleSimilarPhotoScrollEnd()

**변경**: guard 실패 시 restore 직접 호출 + debounce 콜백에서 분석 후 restore 호출

```swift
func handleSimilarPhotoScrollEnd() {
    guard shouldEnableSimilarPhoto() else {
        // 분석 비활성 → 즉시 restore
        LiquidGlassOptimizer.restore(in: view.window)
        return
    }

    debounceWorkItem?.cancel()

    let workItem = DispatchWorkItem { [weak self] in
        guard let self = self else { return }
        // 1. 분석 먼저 시작 (MTKView paused 상태 → 빠름)
        self.startAnalysis()
        // 2. restore (Metal 활성화)
        LiquidGlassOptimizer.restore(in: self.view.window)
    }
    debounceWorkItem = workItem

    DispatchQueue.main.asyncAfter(
        deadline: .now() + SimilarPhotoConstants.debounceInterval,
        execute: workItem
    )
}
```

### 엣지 케이스

| 케이스 | 동작 |
|--------|------|
| 분석 비활성 (`shouldEnableSimilarPhoto()` false) | guard에서 즉시 restore |
| debounce 중 다시 스크롤 | `handleSimilarPhotoScrollStart()`가 debounce 취소. 스크롤 시작 시 optimize 유지. 다음 scroll end에서 재스케줄 |
| debounce 중 셀 탭 (뷰어 열기) | debounce 계속 실행 → 분석 + restore 정상 처리 |
| startAnalysis early return | debounce 콜백에서 startAnalysis 후 restore가 순차 호출되므로 정상 복원 |
| self가 nil (weak self 해제) | DispatchWorkItem에서 guard let self 실패 → VC가 해제된 상태이므로 문제없음 |

### 잠재적 한계

`startAnalysis()`는 `Task { ... }`를 생성할 뿐 동기 실행하지 않음. debounce 콜백에서 `startAnalysis()` → `restore()` 순서로 호출해도 두 작업이 거의 동시에 실행됨.

다만, Metal 초기화에 ~150ms 소요 (hideBlurOverlays의 0.15s 대기) → 분석 Task가 Metal 초기화 중에 이미지 로딩 가능. 완전한 pause(183ms)만큼은 아니지만, 현재(688ms)보다 크게 개선 예상.

### 2차 방안 (테스트 후 필요 시)

restore 전에 100~200ms 딜레이 추가 → 분석에 더 확실한 head start 제공:

```swift
self.startAnalysis()
DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
    LiquidGlassOptimizer.restore(in: self.view.window)
}
```

추가 blur: 0.15초. 필요 시에만 적용.

### 검증 계획

1. 빌드 성공 확인
2. `performanceLoggingEnabled = true` 상태에서 동일 3개 화면 테스트
3. 과거 실험 결과와 비교:
   - MTKView pause 유지 실험: #2 FP Gen 183ms, #3 FP Gen 207ms
   - 현재 HEAD: #2 FP Gen 688ms, #3 FP Gen 732ms
   - 목표: warm cache 기준 개선 (200~400ms 범위)

### 테스트 결과: debounce 콜백 순서 변경 (실패 → 롤백)

**방법**: `handleSimilarPhotoScrollEnd()`의 debounce 콜백에서 `startAnalysis()` → `restore()` 순서로 호출.

**실패 원인**: `startAnalysis()`가 `Task { ... }`만 생성하고 즉시 리턴하므로, `restore()`가 사실상 동시에 실행됨. 분석에 head start 없음.

| | 현재 HEAD | debounce 순서 변경 | 차이 |
|---|---|---|---|
| **#1** FP Gen | 766ms | 696ms | -9% |
| **#1** Total | 1972ms | 1927ms | -2% |
| **#2** FP Gen | 688ms | 681ms | -1% |
| **#2** Total | 2220ms | 2929ms | +32% |
| **#3** FP Gen | 732ms | 1281ms | **+75%** |
| **#3** Total | 3177ms | 3863ms | **+22%** |

**결론: 효과 없음.** #3에서 오히려 악화. `startAnalysis()`가 동기 함수가 아니므로 호출 순서 변경만으로는 타이밍 제어 불가. 롤백 완료.

### 2차 구현: 분석 완료 후 restore (방안 B)

**방법**: `startAnalysis()`의 Task 내부 `defer`에서 분석 완료 후 `DispatchQueue.main.async`로 `restore()` 호출. 분석 전체가 MTKView paused 상태에서 실행.

```swift
let window = view.window
let task = Task {
    defer {
        SimilarityAnalysisQueue.shared.unregisterTask(id: taskID)
        DispatchQueue.main.async {
            LiquidGlassOptimizer.restore(in: window)
        }
    }
    let groupIDs = await SimilarityAnalysisQueue.shared.formGroupsForRange(...)
}
```

**테스트 결과**:

| | 과거 (8563973) | HEAD | 실험3 (pause유지) | **방안B** | HEAD vs 방안B |
|---|---|---|---|---|---|
| **#1** FP Gen | 330ms | 766ms | 834ms | 828ms | +8% |
| **#1** Total | 1159ms | 1972ms | 2053ms | 2095ms | +6% |
| **#2** FP Gen | **170ms** | 688ms | 183ms | **180ms** | **-74%** ✅ |
| **#2** Total | **376ms** | 2220ms | 829ms | **830ms** | **-63%** ✅ |
| **#3** FP Gen | **179ms** | 732ms | 207ms | **199ms** | **-73%** ✅ |
| **#3** Total | **601ms** | 3177ms | 1295ms | **1284ms** | **-60%** ✅ |

**결론: 성능은 성공, UX는 실패.** 실험 3(MTKView pause 유지)과 동일 수준으로 회복. 그러나 분석 완료까지 1~3초간 LiquidGlass가 blur 상태로 유지되어 UX가 매우 나빠짐. 롤백.

### 3차 구현: FP 완료 후 restore (방안 C)

**방법**: `formGroupsForRange()`에 `onFPComplete` 콜백 파라미터 추가. FP Generation 직후(그룹 형성 전) restore 호출. blur 시간을 debounce(0.3초) + FP(~0.2초) = ~0.5초로 제한.

**테스트 결과**: FP Gen 174ms (성능 회복). 하지만 사용자 체감 시간은 여전히 ~2.5초. Face Detect+Match(1,900ms)가 전체 시간의 대부분을 차지하므로 FP만 개선해도 체감 변화 없음. 롤백.

### 타이밍 조절 방식의 한계

3가지 방안 모두 `restore()` 호출 시점만 변경하는 "타이밍 조절"이었으며, 공통적으로:
- FP Generation(~180ms)만 개선 가능
- Face Detect+Match(~1,900ms)는 개선 불가
- 사용자 체감 시간(~2.5초)에 의미 있는 변화를 주지 못함

**결론: 타이밍 조절만으로는 해결 불가. 근본적으로 다른 접근 필요.**

---

## 근본 대안 탐색

### 배경

타이밍 조절(restore 지연/순서 변경)은 FP Generation에만 영향을 주며, 전체 체감 시간 ~2.5초 중 Face Detect+Match(1,900ms)가 지배적이므로 효과가 미미. 코드베이스, LiquidGlassKit 구현, Apple 기술 문서를 종합 조사하여 5가지 근본 대안을 도출.

### 현재 파이프라인 구조

```
scrollDidEnd (T+0)
  → Timer 50ms
  → debounce 300ms (T+350ms)
  → FP 생성 (~180ms, 병렬 semaphore=5) (T+530ms)
  → 그룹 형성 (T+530ms)
  → Face Detection + Match (~1,900ms) (T+2,430ms)
  → 테두리 표시 (T+2,430ms) ← 사용자 체감 시점
```

### 대안 A: 점진적 결과 표시

**핵심**: FP 그룹 형성 즉시(530ms) 테두리를 먼저 표시하고, 얼굴 매칭은 백그라운드에서 계속 진행.

```
T+350ms: debounce 발동
T+530ms: FP 완료 → 그룹 형성 → 테두리 즉시 표시 ★ (사용자 체감 0.5초)
T+2,430ms: 얼굴 매칭 완료 → 얼굴 줌 아이콘 추가 업데이트
```

- **예상 효과**: 체감 2.5초 → **0.5초** (압도적)
- **난이도**: 중
- **원리**: 실제 처리 시간은 그대로이지만, 중간 결과를 먼저 보여줌

### 대안 B: Metal 리소스 경량화

**핵심**: LiquidGlassKit fork에서 Metal 메모리 사용량을 줄여 PHCachingImageManager 캐시와의 경쟁 자체를 완화.

현재 22개 MTKView가 ~110-130MB 메모리 점유 (5.9MB/텍스처 × 22개). 이를 줄이면 restore 타이밍과 무관하게 분석 성능 유지 가능.

방법:
1. `drawableSize` 축소 (2x scale → 1x) → 텍스처 75% 감소
2. `preferredFramesPerSecond` 30으로 → GPU 작업 빈도 50% 감소
3. `autoCapture = false` 제어 → 배경 캡처 중단 (병목 1+2 제거)
4. Memoryless 텍스처 적용 → 임시 렌더 타겟 메모리 0

- **예상 효과**: Metal 메모리 130MB → 30~40MB. FP + Face 이미지 로딩 모두 개선. 체감 **~500ms+ 단축**
- **난이도**: 중

### 대안 C: 파이프라인 병렬화 (FP + Face Detection 동시)

**핵심**: 현재 순차 실행인 FP 생성과 Face Detection을 동시에 시작. 같은 이미지에서 VNImageRequestHandler 하나에 두 요청 번들링.

```
현재: FP 생성 (180ms) → 그룹 → Face Detection (1,900ms) = 순차
변경: FP 생성 ─────→ 그룹 → 인물 매칭만
      Face Detection ────────→ ┘ (캐시에서 조회)
```

- **예상 효과**: 이미지 로딩 중복 제거 + 병렬 실행 → **~300-500ms 단축**
- **난이도**: 상 (파이프라인 구조 변경 필요)
- **참고**: 점진적 결과와 합치면 백그라운드 시간만 줄어들고 1차 체감에는 추가 효과 없음

### 대안 D: 분석용 별도 이미지 로더 (캐시 분리)

**핵심**: SimilarityImageLoader가 PHCachingImageManager 대신 별도 PHImageManager() 인스턴스를 사용하여 Metal과 캐시 경쟁 자체를 회피.

```swift
// 분석 전용 (Metal 캐시와 완전 분리)
private let analysisImageManager = PHImageManager()
```

- **예상 효과**: Metal과 캐시 경쟁 제거 → FP ~500ms 절약. 체감 **~500ms 단축**
- **난이도**: 하
- **한계**: 프리캐싱 기능 없음. Face Detect 시간(1,900ms)은 미변

### 대안 E: 분석 이미지 크기 축소 + 요청 번들링

**핵심**: FP용 480px → 300px, Face Detection용 480px → 320px (YuNet 입력 크기)으로 축소. 동일 이미지에 대해 VNImageRequestHandler 하나에 FP + FaceDetection 번들링.

- **예상 효과**: 이미지 로딩/디코딩 40-60% 감소 → **~100-200ms 단축**
- **난이도**: 하
- **한계**: 효과가 가장 작음

### 효과 순 정렬

| 순위 | 대안 | 체감 시간 변화 | 난이도 |
|------|------|--------------|--------|
| **1** | **A: 점진적 결과 표시** | **2.5초 → 0.5초** | 중 |
| **2** | **B: Metal 경량화** | **2.5초 → 2.0초** | 중 |
| **3** | **D: 캐시 분리** | **2.5초 → 2.0초** | 하 |
| **4** | **C: 파이프라인 병렬화** | **2.5초 → 2.0~2.2초** | 상 |
| **5** | **E: 이미지 축소** | **2.5초 → 2.3초** | 하 |

### 최적 조합 분석

| 조합 | 체감 시간 | 백그라운드 시간 | 난이도 |
|------|----------|---------------|--------|
| **A + B (점진적 + Metal 경량화)** | **0.5초** | **~1.5초** | 중+중 |
| A + D (점진적 + 캐시 분리) | 0.5초 | ~2.0초 | 중+하 |
| A + C (점진적 + 병렬화) | 0.5초 | ~1.8초 | 중+상 |

A(점진적 결과)가 체감 효과의 대부분을 차지. B(Metal 경량화)는 백그라운드 시간도 줄여주므로 최적 조합.

---

## 진행 계획

**A + B (점진적 결과 표시 + Metal 경량화)** 순서대로 구현 예정.

1단계: **점진적 결과 표시** (대안 A) — 체감 시간 2.5초 → 0.5초
→ 구현 문서: [260131perfo_UI.md](similar/260131perfo_UI.md)

2단계: **Metal 경량화** (대안 B) — 백그라운드 시간 추가 단축
→ 구현 문서: [260131LiquidPerfor1.md](260131LiquidPerfor1.md)

### 2단계 Phase 1 결과 (버튼 2뷰→1뷰)

expandedView 제거로 MTKView 수를 절반(8→4개)으로 줄인 결과, 웜 캐시 FP Generation이 과거 수준으로 회복:

| | 기존 HEAD | Phase 1 적용 | 개선 | 과거 (8563973) |
|---|---|---|---|---|
| #2 FP Gen (웜) | 688ms | **216ms** | **-69%** | 170ms |
| #3 FP Gen (웜) | 732ms | **199ms** | **-73%** | 179ms |
| #2 Total | 2,220ms | **1,113ms** | **-50%** | 376ms |
| #3 Total | 3,177ms | **1,819ms** | **-43%** | 601ms |

### 3단계 Phase 3 결과 (fps 30 제한)

Phase 1 + preferredFramesPerSecond 30 제한 적용 (3회 평균):

| | Phase 1 | Phase 3 | 추가 개선 | 과거 (8563973) |
|---|---|---|---|---|
| #1 FP Gen (콜드) | 507ms | **394ms** | **-22%** | 330ms |
| #2 FP Gen (웜) | 216ms | **182ms** | -16% | 170ms |
| #3 FP Gen (웜) | 199ms | **190ms** | -5% | 179ms |
| #2 Total | 1,113ms | **982ms** | -12% | 376ms |
| #3 Total | 1,819ms | **1,477ms** | **-19%** | 601ms |

### 4단계 Phase 4 결과 (정지 시 전체 idle pause)

Phase 1 + 3 + 정지 시 모든 MTKView idle pause 적용 (3회 평균):

| | Phase 3 | Phase 4 | 추가 개선 | 과거 (8563973) |
|---|---|---|---|---|
| #1 FP Gen (콜드) | 394ms | **376ms** | -5% | 330ms |
| #2 FP Gen (웜) | 182ms | **180ms** | -1% | 170ms |
| #3 FP Gen (웜) | 190ms | **169ms** | **-11%** | 179ms |
| #2 Total | 982ms | **776ms** | **-21%** | 376ms |
| #3 Total | 1,477ms | **1,242ms** | **-16%** | 601ms |

idle 상태에서 active MTKView = 0개 달성. 반복 분석(#3) FP가 과거보다 빨라짐.

상세 결과 및 후속 Phase는 [260131LiquidPerfor1.md](260131LiquidPerfor1.md) 참조.

# 유사사진 분석 성능 저하 조사

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

## 현재 결론

**분석 코드(SimilarityImageLoader, SimilarityAnalysisQueue)의 변경은 성능 저하 원인이 아님.**

과거 코드로 완전 교체해도 성능이 동일하므로, 원인은 분석 코드 외부에 있음. 가능성:

1. **앱 전체 메모리/리소스 증가**: LiquidGlass MTKView 14개의 Metal 텍스처/버퍼 할당, AutoCleanup 관련 코드/데이터가 기본 메모리 풋프린트를 높임
   - 현재 앱 분석 시작 시 메모리: 170~183MB
   - 과거 앱의 메모리 데이터 없음 (비교 불가)
2. **PHCachingImageManager 캐시 동작 변화**: 시스템 메모리 압박이 높아지면 캐시 크기가 줄어들어 이미지 로딩 성능 저하
3. **기타 환경 요인**: iOS 업데이트, 기기 상태 등

## 다음 단계

- [ ] LiquidGlass를 그리드 셀에서 비활성화한 상태로 동일 테스트 → 메모리/리소스 경쟁 확인
- [ ] 과거 커밋(8563973)으로 빌드한 앱에서 분석 시작 시 메모리 측정 → 메모리 차이 비교
- [ ] `loadImage`를 현재 방식(withTaskCancellationHandler)으로 원복 (실험 완료)

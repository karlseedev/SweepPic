# 뷰어 이미지 로딩 개선 #2 — 분석 이미지 로더 pause/resume

## Context
뷰어 진입 시 LOD0 non-degraded 도착이 ~1900ms 지연되는 문제.
SimilarityImageLoader가 분석용 이미지 ~15장을 PHCachingImageManager로 동시 요청하면서
뷰어의 LOD0/LOD1 요청과 CPU/GPU 리소스를 경쟁함.
(Analysis completed in 3828ms 동안 LOD0이 +1900ms에 도착)

## 해결 원칙
뷰어 이미지 요청 시 분석용 이미지 로딩을 일시정지하여 리소스 경쟁을 제거.
LOD0 non-degraded 도착 후 분석 재개. 스와이프 시에도 반복.

## 변경 내용

### 1. SimilarityImageLoader — pause/resume 메커니즘
**파일**: `PickPhoto/Features/SimilarPhoto/Analysis/SimilarityImageLoader.swift`

**(a)** 프로퍼티 추가:
```swift
private var isPaused = false
private var waitingContinuations: [CheckedContinuation<Void, Never>] = []
private let pauseLock = NSLock()
```

**(b)** pause/resume 메서드:
```swift
func pause() {
    pauseLock.lock()
    isPaused = true
    pauseLock.unlock()
}

func resume() {
    pauseLock.lock()
    isPaused = false
    let continuations = waitingContinuations
    waitingContinuations.removeAll()
    pauseLock.unlock()
    for c in continuations { c.resume() }
}
```

**(c)** `loadImage(for:)` (Line 120) 시작부에 대기 로직:
```swift
func loadImage(for asset: PHAsset, ...) async throws -> CGImage {
    // 뷰어 이미지 로딩 중이면 대기
    await waitIfPaused()
    // ... 기존 로직
}
```

**(d)** `waitIfPaused()` 헬퍼:
```swift
private func waitIfPaused() async {
    pauseLock.lock()
    guard isPaused else {
        pauseLock.unlock()
        return
    }
    await withCheckedContinuation { (c: CheckedContinuation<Void, Never>) in
        waitingContinuations.append(c)
        pauseLock.unlock()  // body는 동기 실행 → lock 안전
    }
}
```
- isPaused면 `withCheckedContinuation`으로 대기
- resume() 호출 시 모든 대기 중인 continuation을 resume
- race condition 방지를 위해 pauseLock 사용
- `withCheckedContinuation`의 body 클로저는 동기 실행이므로 lock→append→unlock 순서 보장

### 2. SimilarityAnalysisQueue — 공개 API
**파일**: `PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift`

imageLoader가 private이므로 포워딩 메서드 추가:
```swift
func pauseImageLoading() { imageLoader.pause() }
func resumeImageLoading() { imageLoader.resume() }
```

### 3. PhotoPageViewController — pause/resume 호출
**파일**: `PickPhoto/Features/Viewer/PhotoPageViewController.swift`

**(a)** `requestLOD0Image()` (Line 370) — 요청 전에 pause:
```swift
SimilarityAnalysisQueue.shared.pauseImageLoading()
```

**(b)** LOD0 콜백 — non-degraded 도착 또는 실패 시 resume:
```swift
// guard image 실패 시에도 분석 재개 (영구 pause 방지)
guard let image = image else {
    SimilarityAnalysisQueue.shared.resumeImageLoading()
    return
}
// ...
if !isDegraded {
    SimilarityAnalysisQueue.shared.resumeImageLoading()
}
```

### 4. 안전장치
**파일**: `PickPhoto/Features/Viewer/PhotoPageViewController.swift`

**(a)** deinit에서 resume (뷰어 종료 시 잠금 해제):
```swift
deinit {
    requestCancellable?.cancel()
    SimilarityAnalysisQueue.shared.resumeImageLoading()
}
```

## 수정 파일 목록
| 파일 | 변경 |
|------|------|
| `SimilarityImageLoader.swift` | isPaused, waitIfPaused(), pause(), resume() |
| `SimilarityAnalysisQueue.swift` | pauseImageLoading(), resumeImageLoading() 포워딩 |
| `PhotoPageViewController.swift` | requestLOD0Image 전후 pause/resume 호출 |

## 검증
1. 로그로 LOD0 도착 시간 확인: +1900ms → 개선 여부
2. 분석 완료도 정상적으로 이루어지는지 확인 (resume 후 분석 진행)
3. 스와이프 시에도 LOD0 빠르게 도착하는지 확인
4. 뷰어 닫기 후 분석이 정상 진행되는지 확인

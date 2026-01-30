# 유사사진 분석 Task 취소 기능 구현 계획

## 목표
스크롤 시작 시 유사사진 분석을 즉시 취소하여 GPU/CPU 경쟁으로 인한 버벅임 해결

## 현재 문제
1. `cancel(source: .grid)` 호출해도 `currentTasks`가 비어있어서 취소 안 됨
2. `Task.isCancelled` 체크가 전혀 없어서 취소 신호 무시
3. `PHImageRequest`가 Task 취소와 연동 안 됨

---

## 구현 단계

### Phase 1: Task 등록 메커니즘 (~35줄)

**파일**: `SimilarityAnalysisQueue.swift`

1. `registerTask()` 메서드 추가
```swift
func registerTask(_ task: Task<Void, Never>, id: UUID, source: AnalysisSource) {
    guard source == .grid else { return }
    serialQueue.sync {
        currentTasks[id] = task
        activeRequests.insert(id)
    }
}
```

2. `unregisterTask()` 메서드 추가
```swift
func unregisterTask(id: UUID) {
    serialQueue.sync {
        currentTasks.removeValue(forKey: id)
        activeRequests.remove(id)
    }
}
```

**파일**: `GridViewController+SimilarPhoto.swift` (startAnalysis 수정)
```swift
let taskID = UUID()
let task = Task {
    defer { SimilarityAnalysisQueue.shared.unregisterTask(id: taskID) }
    let groupIDs = await SimilarityAnalysisQueue.shared.formGroupsForRange(...)
}
SimilarityAnalysisQueue.shared.registerTask(task, id: taskID, source: .grid)
```

---

### Phase 2: Task.isCancelled 체크 추가 (~50줄)

**파일**: `SimilarityAnalysisQueue.swift`

#### 2-1. 체크 포인트
| 위치 | 메서드 | 설명 |
|------|--------|------|
| ~236행 | formGroupsForRange | FP 생성 후 |
| ~264행 | formGroupsForRange | rawGroups 루프 |
| ~436행 | generateFeaturePrints | group.addTask 시작 |
| ~443행 | generateFeaturePrints | 세마포어 획득 후 |
| ~556행 | assignPersonIndicesForGroup | assetID 루프 |

예시:
```swift
guard !Task.isCancelled else {
    Log.print("[SimilarPhoto] Cancelled at ...")
    return []
}
```

#### 2-2. TaskGroup 내 child task 취소 (중요)

**주의**: CancellationError를 throw하려면 `withThrowingTaskGroup` 사용 필수

**에러 흡수 정책**: `generateFeaturePrints`는 현재 non-throws (`async -> [VNFeaturePrintObservation?]`).
이 시그니처를 유지하기 위해 내부에서 CancellationError를 catch하여 빈 배열로 반환한다.
`formGroupsForRange`도 마찬가지로 non-throws 유지. throws 전파하지 않으므로
`GridViewController`의 `Task<Void, Never>` 및 `currentTasks` 타입 변경 불필요.

**부분 결과 정책**: 취소 시 부분 결과는 전부 버리고 빈 배열 반환 (캐시 오염 방지)

```swift
// generateFeaturePrints 내부
func generateFeaturePrints(for photos: [PHAsset]) async -> [VNFeaturePrintObservation?] {
    do {
        return try await withThrowingTaskGroup(of: (Int, VNFeaturePrintObservation?).self) { group in
            for (index, photo) in photos.enumerated() {
                group.addTask {
                    // child task 내부에서도 취소 체크
                    try Task.checkCancellation()
                    ...
                }
            }

            var results = [VNFeaturePrintObservation?](repeating: nil, count: photos.count)
            for try await (index, fp) in group {
                // 취소 감지 시 나머지 작업 취소
                if Task.isCancelled {
                    group.cancelAll()
                    break
                }
                results[index] = fp
            }
            return results
        }
    } catch is CancellationError {
        Log.print("[SimilarPhoto] generateFeaturePrints cancelled - returning empty")
        return []  // 부분 결과 버림, throws 전파하지 않음
    } catch {
        Log.print("[SimilarPhoto] generateFeaturePrints error: \(error)")
        return []
    }
}
```

#### 2-3. 취소 시 캐시 정책 (중요)

**원칙**: 취소 시 캐시/알림 완전히 스킵

```swift
guard !Task.isCancelled else {
    // ❌ cache.setState() 호출 금지
    // ❌ postAnalysisComplete() 호출 금지
    Log.print("[SimilarPhoto] Cancelled - skipping cache update")
    return []
}
```

**이유**: 부분 완료 상태로 캐시 업데이트하면 "그룹 아님" 상태로 덮어쓰기 위험

---

### Phase 3: PHImageRequest 취소 연동 (~70줄)

**파일**: `SimilarityImageLoader.swift`

**핵심**: GPU 경쟁 해결을 위해 이미지 디코딩도 즉시 중단 필요

#### 3-1. cancelled 케이스 추가

**기존 케이스 유지**, `cancelled`만 추가:
```swift
enum SimilarityImageLoadError: Error, LocalizedError {
    case loadFailed(String)   // 기존
    case timeout              // 기존
    case invalidImage         // 기존
    case accessDenied         // 기존
    case cancelled            // 추가: Task 취소 전용 에러
}
```

#### 3-2. 취소 연동 구현

```swift
// 클래스 레벨에 추가
private let lock = NSLock()
private var activeRequestIDs: [UUID: PHImageRequestID] = [:]

func loadImage(for asset: PHAsset) async throws -> CGImage {
    let requestUUID = UUID()
    var hasResumed = false  // 중복 resume 방지
    var isTimeout = false   // timeout/cancelled 구분용

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            // 타임아웃 로직 유지 (cancelImageRequest 후 콜백 미보장 대비)
            let timeoutItem = DispatchWorkItem { [weak self] in
                guard let self = self else { return }
                self.lock.lock()
                isTimeout = true
                if let id = self.activeRequestIDs.removeValue(forKey: requestUUID) {
                    self.imageManager.cancelImageRequest(id)
                }
                self.lock.unlock()
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout, execute: timeoutItem)

            let requestID = imageManager.requestImage(...) { [weak self] image, info in
                timeoutItem.cancel()
                guard let self = self else { return }

                // degraded 이미지는 ID 유지하고 스킵 (high-quality 대기)
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return  // ID 제거하지 않음!
                }

                // 최종 콜백에서만 ID 제거
                self.lock.lock()
                self.activeRequestIDs.removeValue(forKey: requestUUID)
                let alreadyResumed = hasResumed
                hasResumed = true
                let wasTimeout = isTimeout
                self.lock.unlock()

                // 중복 resume 방지
                guard !alreadyResumed else { return }

                // 취소된 경우
                if let cancelled = info?[PHImageCancelledKey] as? Bool, cancelled {
                    // timeout과 cancelled 구분
                    if wasTimeout {
                        continuation.resume(throwing: SimilarityImageLoadError.timeout)
                    } else {
                        continuation.resume(throwing: SimilarityImageLoadError.cancelled)
                    }
                    return
                }

                // 정상 처리...
            }

            // requestID 저장 (thread-safe)
            lock.lock()
            activeRequestIDs[requestUUID] = requestID
            lock.unlock()
        }
    } onCancel: { [weak self] in
        guard let self = self else { return }
        self.lock.lock()
        let requestID = self.activeRequestIDs.removeValue(forKey: requestUUID)
        self.lock.unlock()

        if let id = requestID {
            self.imageManager.cancelImageRequest(id)
        }
        // 콜백 보장 가정: cancelImageRequest 후 PHImageManager가 콜백 호출
        // 타임아웃은 안전장치: 콜백 미보장 시 fallback으로 resume 처리
    }
}
```

#### 3-3. 에러 전파 정책 (중요)

**generateFeaturePrints에서 CancellationError 처리:**
```swift
group.addTask {
    do {
        let image = try await self.imageLoader.loadImage(for: photo)
        let fp = try await self.analyzer.generateFeaturePrint(for: image)
        return (index, fp)
    } catch is CancellationError {
        throw CancellationError()  // 상위로 전파 (nil로 흡수 금지)
    } catch SimilarityImageLoadError.cancelled {
        throw CancellationError()  // 상위로 전파
    } catch {
        return (index, nil)  // 다른 에러만 nil로 처리
    }
}
```

---

## 수정 파일 목록

| 파일 | 변경량 | 내용 |
|------|--------|------|
| `SimilarityAnalysisQueue.swift` | ~90줄 | Task 등록/취소 체크/캐시 정책 |
| `SimilarityImageLoader.swift` | ~50줄 | PHImageRequest 취소/에러 처리 |
| `GridViewController+SimilarPhoto.swift` | ~15줄 | Task 등록 호출 |

**총 예상**: ~155줄

---

## 테스트 방법

### 1. 취소 동작 확인
- 분석 중 스크롤 → `[SimilarPhoto] Cancelled` 로그 출력 확인
- **캐시 미변경 확인**: 취소 후 `cache.setState` 로그 없어야 함
- **알림 미발송 확인**: 취소 후 `postAnalysisComplete` 로그 없어야 함

### 2. 성능 확인
- 분석 중 스크롤 시 버벅임 감소 확인
- HitchMonitor 로그로 hitch ratio 확인
- **PHImageRequest 취소 타이밍**: 스크롤 시작 직후 `cancelImageRequest` 로그 확인

### 3. viewer 영향 없음 확인
- 뷰어에서 분석은 취소되지 않아야 함

### 4. 재분석 정상 동작 확인
- 취소 → 스크롤 멈춤 → 재분석 시 테두리 정상 복원 확인

---

## 구현 순서

1. Phase 1: Task 등록 (기본 취소 메커니즘)
2. Phase 2: 취소 체크 + 캐시 정책 추가
3. Phase 3: PHImageRequest 취소 + 에러 전파 (GPU 경쟁 해결 핵심)
4. 테스트

**참고**: GPU가 병목이므로 Phase 3까지 모두 필수

---

## 구현 완료 (2026-01-30)

### 구현 결과

| Phase | 파일 | 변경 |
|-------|------|------|
| 1 | `SimilarityAnalysisQueue.swift` | registerTask()/unregisterTask() 추가 |
| 1 | `GridViewController+SimilarPhoto.swift` | startAnalysis에서 Task 등록/해제 |
| 2 | `SimilarityAnalysisQueue.swift` | isCancelled 체크 3곳 (FP 생성 후, rawGroups 루프, person assignment) |
| 2 | `SimilarityAnalysisQueue.swift` | generateFeaturePrints: withThrowingTaskGroup + CancellationError 흡수 |
| 3 | `SimilarityImageLoader.swift` | cancelled 케이스 추가, withTaskCancellationHandler, activeRequestIDs |

**총 변경**: +194줄, -69줄 (3파일)

### Sendable 이슈 해결

`onCancel`은 `@Sendable` 클로저이므로 main actor-isolated property에 접근 불가.
`activeRequestIDs`에 `nonisolated(unsafe)` 적용하여 해결. `NSLock`으로 thread safety 보장.

```swift
nonisolated(unsafe) private var activeRequestIDs: [UUID: PHImageRequestID] = [:]
```

### 테스트 결과

#### 1. 취소 동작 ✅
```
[SimilarPhoto] Cancelled task: CC7392E2-18B5-4C82-BBFD-4F713B834D11
[SimilarPhoto] Cancelled during person assignment - skipping cache/notification
[SimilarPhoto] Cancelled during group processing - skipping cache/notification
[SimilarPhoto] Analysis complete, found 0 groups
```
- Task 취소 로그 출력 확인
- 캐시/알림 스킵 확인 (취소 후 `Received analysis complete` 미출력)

#### 2. 성능 ✅
```
[Hitch] L1 First: hitch: 2.5 ms/s [Good], fps: 120.0
[Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 120.0
[Hitch] L2 Steady: hitch: 0.1 ms/s [Good], fps: 118.0
```
- 분석 중 스크롤 시 120fps 유지, hitch 0.0~0.1 ms/s [Good]

#### 3. 재분석 ✅
```
[SimilarPhoto] Starting analysis for range: 3400...3437
[SimilarPhoto] Analysis complete, found 2 groups
[SimilarPhoto] Received analysis complete - groups: 2, assets: 38
```
- 취소 후 스크롤 멈춤 → 재분석 정상 완료, 그룹 정상 감지

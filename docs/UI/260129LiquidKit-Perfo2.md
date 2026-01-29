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

### Phase 2: Task.isCancelled 체크 추가 (~40줄)

**파일**: `SimilarityAnalysisQueue.swift`

체크 포인트:
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

---

### Phase 3: PHImageRequest 취소 연동 (~60줄)

**파일**: `SimilarityImageLoader.swift`

**핵심**: GPU 경쟁 해결을 위해 이미지 디코딩도 즉시 중단 필요

1. 클래스에 `activeRequestID` 프로퍼티 추가 (thread-safe)
2. `withTaskCancellationHandler` 래핑
3. onCancel에서 `cancelImageRequest()` 호출

```swift
// 클래스 레벨에 추가
private let lock = NSLock()
private var activeRequestIDs: [UUID: PHImageRequestID] = [:]

func loadImage(for asset: PHAsset) async throws -> CGImage {
    let requestUUID = UUID()

    return try await withTaskCancellationHandler {
        try await withCheckedThrowingContinuation { continuation in
            let requestID = imageManager.requestImage(...) { ... }

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
    }
}
```

---

## 수정 파일 목록

| 파일 | 변경량 | 내용 |
|------|--------|------|
| `SimilarityAnalysisQueue.swift` | ~80줄 | Task 등록/취소 체크 |
| `SimilarityImageLoader.swift` | ~40줄 | PHImageRequest 취소 |
| `GridViewController+SimilarPhoto.swift` | ~15줄 | Task 등록 호출 |

**총 예상**: ~135줄

---

## 테스트 방법

1. **취소 동작 확인**
   - 분석 중 스크롤 → `[SimilarPhoto] Cancelled` 로그 출력 확인

2. **성능 확인**
   - 분석 중 스크롤 시 버벅임 감소 확인
   - HitchMonitor 로그로 hitch ratio 확인

3. **viewer 영향 없음 확인**
   - 뷰어에서 분석은 취소되지 않아야 함

---

## 구현 순서

1. Phase 1: Task 등록 (기본 취소 메커니즘)
2. Phase 2: 취소 체크 추가
3. Phase 3: PHImageRequest 취소 (GPU 경쟁 해결 핵심)
4. 테스트

**참고**: GPU가 병목이므로 Phase 3까지 모두 필수

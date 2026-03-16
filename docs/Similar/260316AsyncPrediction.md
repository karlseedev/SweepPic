# iOS 17+ Core ML 비동기 예측으로 유사사진 분석 속도 개선

## 베이스라인 측정 결과 (2026-03-16)

### iPhone 11 (A13, iOS 26) — 18개 그룹

| 그룹 | 사진 | 얼굴 | Load | YuNet | SFace | Match | Total |
|------|------|------|------|-------|-------|-------|-------|
| 1 | 6 | 5 | 926 | 1433 | 121 | 0 | 3494 |
| 2 | 7 | 30 | 976 | 1527 | 838 | 1 | 3342 |
| 3 | 3 | 6 | 1433 | 709 | 186 | 0 | 2328 |
| 4 | 3 | 2 | 239 | 702 | 62 | 0 | 1003 |
| 5 | 10 | 10 | 800 | 2328 | 308 | 2 | 3438 |
| 6 | 5 | 2 | 3371 | 983 | 65 | 0 | 4420 |
| 7 | 4 | 4 | 1419 | 966 | 124 | 0 | 2510 |
| 8 | 3 | 6 | 2137 | 724 | 190 | 0 | 3051 |
| 9 | 6 | 4 | 490 | 1446 | 123 | 0 | 2059 |
| 10 | 5 | 9 | 409 | 1183 | 274 | 0 | 1868 |
| 11 | 3 | 3 | 796 | 739 | 98 | 0 | 1632 |
| 12 | 3 | 15 | 109 | 746 | 475 | 0 | 1331 |
| 13 | 5 | 25 | 237 | 1213 | 664 | 1 | 2116 |
| 14 | 6 | 8 | 279 | 1450 | 213 | 0 | 1943 |
| 15 | 4 | 17 | 185 | 964 | 447 | 1 | 1598 |
| 16 | 6 | 12 | 2750 | 1546 | 403 | 0 | 4701 |
| 17 | 4 | 4 | 333 | 1012 | 133 | 0 | 1478 |
| 18 | 3 | 3 | 251 | 768 | 99 | 0 | 1119 |

**단가:**

| 지표 | 평균 | 범위 | 편차 |
|------|------|------|------|
| YuNet/장 | 242ms | 197~258ms | ±12% (안정) |
| SFace/얼굴 | 29ms | 24~34ms | ±15% (안정) |
| Load/장 | — | 36~712ms | ±900% (PHImageManager 캐시 의존) |

### iPhone 13 Pro (A15, iOS 18) — 23개 그룹

| 그룹 | 사진 | 얼굴 | Load | YuNet | SFace | Match | Total |
|------|------|------|------|-------|-------|-------|-------|
| 1 | 5 | 5 | 141 | 795 | 128 | 2 | 1066 |
| 2 | 10 | 1 | 485 | 1591 | 21 | 0 | 2097 |
| 3 | 3 | 7 | 55 | 481 | 158 | 0 | 694 |
| 4 | 3 | 3 | 49 | 480 | 68 | 0 | 598 |
| 5 | 3 | 6 | 39 | 481 | 137 | 0 | 657 |
| 6 | 5 | 7 | 69 | 812 | 166 | 0 | 1047 |
| 7 | 5 | 17 | 85 | 800 | 387 | 0 | 1273 |
| 8 | 5 | 5 | 77 | 809 | 115 | 0 | 1001 |
| 9 | 3 | 3 | 43 | 498 | 75 | 0 | 616 |
| 10 | 3 | 5 | 57 | 486 | 121 | 0 | 664 |
| 11 | 5 | 8 | 88 | 808 | 191 | 0 | 1087 |
| 12 | 5 | 20 | 68 | 807 | 480 | 0 | 1356 |
| 13 | 6 | 13 | 72 | 968 | 279 | 0 | 1319 |
| 14 | 4 | 6 | 47 | 640 | 136 | 0 | 825 |
| 15 | 6 | 19 | 72 | 963 | 416 | 0 | 1452 |
| 16 | 6 | 15 | 79 | 964 | 336 | 0 | 1379 |
| 17 | 5 | 4 | 67 | 805 | 90 | 0 | 962 |
| 18 | 5 | 8 | 62 | 809 | 176 | 0 | 1047 |
| 19 | 6 | 12 | 78 | 970 | 267 | 0 | 1316 |
| 20 | 3 | 3 | 38 | 489 | 73 | 0 | 600 |
| 21 | 3 | 3 | 36 | 490 | 74 | 0 | 600 |
| 22 | 5 | 19 | 56 | 819 | 426 | 0 | 1301 |
| 23 | 6 | 24 | 101 | 964 | 531 | 1 | 1596 |

**단가:**

| 지표 | 평균 | 범위 | 편차 |
|------|------|------|------|
| YuNet/장 | 161ms | 159~166ms | ±2% (매우 안정) |
| SFace/얼굴 | 23ms | 21~26ms | ±10% (안정) |
| Load/장 | 70ms | 11~49ms (초반 제외) | 안정 (사진 3,550장, 캐시 히트율 높음) |

### 기기 간 비교

| 지표 | iPhone 11 (A13) | iPhone 13 Pro (A15) | 배율 |
|------|----------------|--------------------|----- |
| YuNet/장 | 242ms | 161ms | 1.5x |
| SFace/얼굴 | 29ms | 23ms | 1.3x |
| Load/장 | 36~712ms (편차 극심) | 11~49ms (안정) | — |
| 그룹 평균 Total | 2,417ms | 1,024ms | 2.4x |

### 병목 비중 (iPhone 11 기준)

- Load 38% — 편차 극심, 프리로드(병렬 로딩)로 구조적 개선 가능
- YuNet 45% — 안정, async 파이프라이닝으로 개선
- SFace 16% — 안정, async 파이프라이닝으로 개선
- Match <1% — 무시 가능

### 개선 효과 측정 방법

- **프리로드**: Load 총 시간이 구조적으로 줄어야 함 (순차 합산 → 병렬 max)
- **async 예측**: YuNet+SFace 합산의 변화로 판별 (편차 작아서 비교 가능)
- Load 편차가 크므로 Total만으로는 개선/편차 구분 어려움 → 단계별 분리 비교 필수

---

## Context

### 문제
유사사진 분석 파이프라인이 사진을 완전히 순차 처리하여 최신 기기에서도 불필요한 대기 발생.
현재 `model.prediction(from:)` 동기 호출을 사용하며, 사진별로 이미지 로딩 → YuNet → SFace → 매칭을 직렬 실행.

### 목표
iOS 17+에서 Core ML 비동기 예측 API + TaskGroup 병렬 처리로 분석 속도 개선.
iOS 16은 기존 순차 방식 유지.

### 근거
- WWDC 2023 (session 10049): `model.prediction(from:options:) async`는 thread-safe하며 동시 호출 시 Core ML이 내부 파이프라이닝
- Xcode가 이미 YuNet/SFace에 iOS 17+ async prediction 메서드를 자동 생성해둠 (현재 미사용)
- 현재 `YuNetFaceDetector.detectAsync()`는 GCD 래퍼일 뿐, 진정한 async가 아님

### 현재 흐름 (순차)
```
Photo 1: [Load] [YuNet] [SFace] [Match]
Photo 2:                               [Load] [YuNet] [SFace] [Match]
Photo 3:                                                              [Load] [YuNet] [SFace] [Match]
```

### 개선 후 흐름 (iOS 17+, 병렬 compute → 순차 matching)
```
Phase 1 (병렬):
  Photo 1: [Load] [YuNet async] [SFace async]
  Photo 2: [Load] [YuNet async] [SFace async]
  Photo 3: [Load] [YuNet async] [SFace async]
  → Core ML이 async prediction을 내부 파이프라이닝

Phase 2 (순차):
  Photo 1: [Match] → Photo 2: [Match] → Photo 3: [Match]
  → activeSlots 의존성 때문에 순차 필수, 매칭 자체는 ~2ms로 빠름
```

### 기각된 대안: 모델 인스턴스 풀
- YuNet/SFace MLModel 인스턴스를 여러 개 만들어 병렬 추론하는 방식 검토
- **기각 이유**: ANE(Neural Engine)는 인스턴스 수와 무관하게 큐 기반 직렬 처리
- M4 역공학: 127개 깊이의 평가 큐 확인 — 큐잉이지 병렬이 아님
- `computeUnits = .cpuOnly`로 진짜 CPU 병렬은 가능하나, ANE 대비 ~3배 느려 오히려 역효과

---

## Phase 1: YuNet 비동기 추론 추가

### 파일: `YuNet/YuNetFaceDetector.swift`

**(a)** `runInferenceAsync()` 메서드 추가 (라인 192 이후):
```swift
/// Core ML 비동기 추론 (iOS 17+ 파이프라이닝 지원)
@available(iOS 17.0, *)
private func runInferenceAsync(input: MLMultiArray) async throws -> MLFeatureProvider {
    let inputFeature = try MLDictionaryFeatureProvider(dictionary: [
        "input": MLFeatureValue(multiArray: input)
    ])
    return try await model.prediction(from: inputFeature, options: MLPredictionOptions())
}
```

**(b)** `detectAsync()` 메서드 개선 (라인 159-170 교체):
```swift
func detectAsync(in image: CGImage) async throws -> [YuNetDetection] {
    // iOS 17+: Core ML 네이티브 async (파이프라이닝 지원)
    if #available(iOS 17.0, *) {
        let (input, letterboxInfo) = try preprocessor.preprocess(image)
        let outputs = try await runInferenceAsync(input: input)
        let detections = decoder.decode(outputs: outputs, scoreThreshold: scoreThreshold)
        if detections.isEmpty { return [] }
        let nmsResult = performNMS(detections: detections)
        let topKResult = Array(nmsResult.prefix(topK))
        return topKResult.map { YuNetDecoder.transformFromLetterbox($0, letterboxInfo: letterboxInfo) }
    }
    // iOS 16: 기존 GCD 래퍼 유지
    return try await withCheckedThrowingContinuation { continuation in
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let result = try self.detect(in: image)
                continuation.resume(returning: result)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
}
```

---

## Phase 2: SFace 비동기 추론 추가

### 파일: `SFaceRecognizer.swift`

**(a)** `runInferenceAsync()` 메서드 추가 (라인 348 이후):
```swift
@available(iOS 17.0, *)
private func runInferenceAsync(input: MLMultiArray) async throws -> [Float] {
    let inputFeature = try MLDictionaryFeatureProvider(dictionary: [
        "input_1": MLFeatureValue(multiArray: input)
    ])
    let output = try await model.prediction(from: inputFeature, options: MLPredictionOptions())
    guard let embeddingArray = output.featureValue(for: "var_811")?.multiArrayValue else {
        throw SFaceError.inferenceFailed("출력 텐서를 찾을 수 없습니다")
    }
    var embedding = [Float](repeating: 0, count: SFaceConfig.embeddingDim)
    for i in 0..<SFaceConfig.embeddingDim {
        embedding[i] = embeddingArray[i].floatValue
    }
    return embedding
}
```

**(b)** `extractEmbeddingAsync()` 메서드 추가:
```swift
/// 비동기 임베딩 추출 (iOS 17+ 파이프라이닝 지원)
func extractEmbeddingAsync(from alignedFace: CGImage) async throws -> [Float] {
    guard alignedFace.width == SFaceConfig.inputSize,
          alignedFace.height == SFaceConfig.inputSize else {
        throw SFaceError.invalidImage("112×112 이미지 필요")
    }
    let input = try preprocess(alignedFace)
    if #available(iOS 17.0, *) {
        return try await runInferenceAsync(input: input)
    }
    return try runInference(input: input)
}
```

---

## Phase 3: SimilarityAnalysisQueue 2-Phase 리팩토링

### 파일: `SimilarityAnalysisQueue.swift`

### 3-1. FaceComputeResult 구조체 추가 (라인 617 부근)
```swift
/// Phase 1 결과: 사진별 얼굴 감지 + 임베딩 (병렬 처리용)
private struct FaceComputeResult: Sendable {
    let assetID: String
    let faceEmbeddings: [Int: [Float]]
    let faceData: [Int: FaceSpatialData]
}

/// 얼굴 위치 데이터 (Sendable 준수)
private struct FaceSpatialData: Sendable {
    let center: CGPoint
    let boundingBox: CGRect
}
```

### 3-2. 병렬 계산 헬퍼 메서드 추가
```swift
/// Phase 1: 모든 사진의 얼굴 감지 + 임베딩을 병렬 처리
/// iOS 17+에서만 호출, iOS 16은 기존 순차 방식 사용
@available(iOS 17.0, *)
private func parallelDetectAndEmbed(
    assetIDs: [String],
    photoMap: [String: PHAsset]
) async -> [String: FaceComputeResult] {

    let maxConcurrent = 3  // 동시 처리 제한 (메모리 + I/O 관리)
    let semaphore = AsyncSemaphore(value: maxConcurrent)

    return await withTaskGroup(of: FaceComputeResult.self) { group in
        for assetID in assetIDs {
            group.addTask { [imageLoader] in
                return await semaphore.withPermit {

                guard !Task.isCancelled else {
                    return FaceComputeResult(assetID: assetID, faceEmbeddings: [:], faceData: [:])
                }

                guard let photo = photoMap[assetID],
                      let cgImage = try? await imageLoader.loadImage(
                          for: photo,
                          maxSize: SimilarityConstants.personMatchImageMaxSize
                      ),
                      let yunet = YuNetFaceDetector.shared,
                      let sface = SFaceRecognizer.shared else {
                    return FaceComputeResult(assetID: assetID, faceEmbeddings: [:], faceData: [:])
                }

                guard let detections = try? await yunet.detectAsync(in: cgImage) else {
                    return FaceComputeResult(assetID: assetID, faceEmbeddings: [:], faceData: [:])
                }

                var embeddings: [Int: [Float]] = [:]
                var spatialData: [Int: FaceSpatialData] = [:]
                let imgW = CGFloat(cgImage.width)
                let imgH = CGFloat(cgImage.height)

                for (faceIdx, det) in detections.enumerated() {
                    let box = CGRect(
                        x: det.boundingBox.origin.x / imgW,
                        y: 1.0 - (det.boundingBox.origin.y + det.boundingBox.size.height) / imgH,
                        width: det.boundingBox.size.width / imgW,
                        height: det.boundingBox.size.height / imgH
                    )
                    spatialData[faceIdx] = FaceSpatialData(
                        center: CGPoint(x: box.midX, y: box.midY),
                        boundingBox: box
                    )

                    guard let aligned = try? FaceAligner.shared.align(
                        image: cgImage, landmarks: det.landmarks
                    ) else { continue }

                    if let emb = try? await sface.extractEmbeddingAsync(from: aligned) {
                        embeddings[faceIdx] = emb
                    } else {
                        AnalyticsService.shared.countError(.embedding as AnalyticsError.Face)
                    }
                }

                return FaceComputeResult(
                    assetID: assetID,
                    faceEmbeddings: embeddings,
                    faceData: spatialData
                )
                } // withPermit
            }
        }

        var results: [String: FaceComputeResult] = [:]
        for await result in group {
            results[result.assetID] = result
        }
        return results
    }
}
```

### 3-3. assignPersonIndicesForGroup 수정

기존 순차 루프의 compute 부분(라인 668-729)을 iOS 버전에 따라 분기:

```swift
private func assignPersonIndicesForGroup(...) async -> [String: [CachedFace]] {
    let photoMap = Dictionary(uniqueKeysWithValues: photos.map { ($0.localIdentifier, $0) })
    var result: [String: [CachedFace]] = [:]
    // ... 상수 선언 (기존 그대로) ...

    // === Phase 1: 얼굴 감지 + 임베딩 ===
    var precomputedFaces: [String: FaceComputeResult]? = nil

    if #available(iOS 17.0, *) {
        precomputedFaces = await parallelDetectAndEmbed(
            assetIDs: assetIDs,
            photoMap: photoMap
        )
    }
    // iOS 16: precomputedFaces == nil → 루프 내에서 기존 순차 처리

    // === Phase 2: 순차 매칭 ===
    for assetID in assetIDs {
        guard !Task.isCancelled else { ... }

        let faceEmbeddings: [Int: [Float]]
        let faceData: [Int: FaceSpatialData]  // 타입 변경: tuple → struct

        if let precomputed = precomputedFaces?[assetID] {
            faceEmbeddings = precomputed.faceEmbeddings
            faceData = precomputed.faceData
        } else {
            // iOS 16: 기존 순차 처리 (현재 코드와 동일)
            // ... 이미지 로드 → YuNet detect → FaceAligner → SFace ...
        }

        // Steps 2-7: 매칭 로직 (기존과 완전 동일)
        // faceData 접근만 .center / .boundingBox → 동일 (struct에서도 같은 프로퍼티명)
    }
    return result
}
```

### 주의: faceData 타입 변경
기존: `[Int: (center: CGPoint, boundingBox: CGRect)]` (named tuple)
변경: `[Int: FaceSpatialData]` (struct)

매칭 로직에서 `faceData[idx]?.center`, `faceData[idx]?.boundingBox`로 접근하므로 동일하게 작동.
iOS 16 경로에서도 같은 struct를 사용하도록 통일.

---

## Sendable 고려사항

### TaskGroup 클로저에서 캡처하는 것들:
- `imageLoader`: SimilarityImageLoader (class) → `@unchecked Sendable` 아님
- `YuNetFaceDetector.shared`: Optional singleton (class)
- `SFaceRecognizer.shared`: Optional singleton (class)
- `FaceAligner.shared`: Singleton (class, 상태 없음 → thread-safe 확인됨)

### 대응:
- 프로젝트의 Swift concurrency 엄격도가 "Minimal"이면 경고만 발생, 빌드 가능
- "Complete"면 `nonisolated(unsafe)` 또는 `@unchecked Sendable` 필요
- **빌드 후 경고/에러 확인하여 대응** (현재 코드에서 이미 async context에서 이들을 캡처 중이므로 문제없을 가능성 높음)

---

## 선행 작업: 단계별 성능 측정 로그

구현 전에 `assignPersonIndicesForGroup` 내부에 단계별 타이밍 로그를 추가하여 기준선 측정:
- Load / YuNet / SFace / Match 각 단계별 시간 누적
- 그룹당 요약 로그 1줄 출력 (faces > 0인 그룹만 유의미)
- iPhone 11 (A13) + iPhone 13 Pro (A15) 두 기기에서 측정

```
[Perf] assignPerson: 5장, 8faces — Load:425ms YuNet:850ms SFace:264ms Match:10ms Total:1549ms
```

---

## 수정 파일 목록

| 파일 | 변경 |
|------|------|
| `YuNet/YuNetFaceDetector.swift` | `runInferenceAsync()` 추가, `detectAsync()` 개선 |
| `SFaceRecognizer.swift` | `runInferenceAsync()` + `extractEmbeddingAsync()` 추가 |
| `SimilarityAnalysisQueue.swift` | `FaceComputeResult` struct, `parallelDetectAndEmbed()`, `assignPersonIndicesForGroup` 2-Phase 분리 |

---

## 검증

1. **빌드 확인**: `xcodebuild -scheme PickPhoto -configuration Debug`
2. **iOS 16 회귀 테스트**: 시뮬레이터에서 기존 동작 유지 확인
3. **iOS 17+ 실기기 테스트**:
   - 단계별 로그로 수정 전후 비교 (faces > 0 그룹의 평균)
   - `Perf Cache MISS - Analysis completed in Xms` 로그로 전체 시간 비교
4. **기능 정상**: +버튼 표시, 인물 매칭 결과가 기존과 동일한지 확인
5. **뷰어 LOD 영향**: 병렬 이미지 로딩이 뷰어 진입 시 LOD0에 영향 주는지 확인
   - maxConcurrent=3으로 제한하므로 2200px 프리로드 때보다 부하 적음
   - 문제 시 maxConcurrent 축소 또는 ViewerLOD pause/resume 적용 후 재시도

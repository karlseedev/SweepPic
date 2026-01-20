# 260114SimilarEdit3 구현 계획

## 1. 수정 대상

| 파일 | 위치 | 변경 내용 |
|------|------|-----------|
| `SimilarityConstants.swift` | line 51-57 | `personMatchThreshold` 값 변경 |
| `SimilarityConstants.swift` | 신규 추가 | 3개 상수 추가 |
| `SimilarityAnalysisQueue.swift` | line 337-342 | `ReferenceSlot` → `PersonSlot` 확장 |
| `SimilarityAnalysisQueue.swift` | line 355-551 | `assignPersonIndicesForGroup` 전체 재작성 |

---

## 2. Task 분할

### Task 1: SimilarityConstants 상수 추가/변경

**위치**: `SimilarityConstants.swift`

```swift
// MARK: - Person Matching (변경)

/// 인물 매칭 거절 임계값 (iOS 버전별)
/// - iOS 17+: 0.65 (변경: 0.8 → 0.65)
/// - iOS 16: 8.0 (변경 없음)
nonisolated static var personMatchThreshold: Float {
    if #available(iOS 17.0, *) {
        return 0.65
    } else {
        return 8.0
    }
}

// MARK: - Grey Zone (신규)

/// Grey Zone 시작 임계값 (확신/모호 구간 경계)
/// - iOS 17+: 0.50
/// - iOS 16: 6.0
nonisolated static var greyZoneThreshold: Float {
    if #available(iOS 17.0, *) {
        return 0.50
    } else {
        return 6.0
    }
}

/// Grey Zone 위치 조건 (정규화된 거리)
nonisolated static let greyZonePositionLimit: CGFloat = 0.15

/// 최대 인물 슬롯 수
nonisolated static let maxPersonSlots: Int = 10
```

---

### Task 2: PersonSlot 구조체 정의

**위치**: `SimilarityAnalysisQueue.swift` (line 337 부근)

```swift
/// 동적 인물 슬롯 (기준 FP + 메타데이터)
private struct PersonSlot {
    let id: Int                              // 슬롯 ID (1-based)
    let featurePrint: VNFeaturePrintObservation  // 기준 FP (Keep First)
    let center: CGPoint                      // 최초 등록 시 위치
    let boundingBox: CGRect                  // 최초 등록 시 바운딩박스
}
```

---

### Task 3: assignPersonIndicesForGroup 함수 재작성

**위치**: `SimilarityAnalysisQueue.swift` (line 355-551)

#### 3.1. 함수 시그니처 및 초기화

```swift
private func assignPersonIndicesForGroup(
    rawFacesMap: [String: [DetectedFace]],
    assetIDs: [String],
    photos: [PHAsset]
) async -> [String: [CachedFace]] {

    // assetID → PHAsset 매핑
    let photoMap = Dictionary(uniqueKeysWithValues: photos.map { ($0.localIdentifier, $0) })

    // 결과 저장
    var result: [String: [CachedFace]] = [:]

    // 동적 인물 풀 (사진 처리하며 성장)
    var activeSlots: [PersonSlot] = []
    var nextSlotID: Int = 1

    // 상수
    let greyZoneThreshold = SimilarityConstants.greyZoneThreshold
    let rejectThreshold = SimilarityConstants.personMatchThreshold
    let greyZonePosLimit = SimilarityConstants.greyZonePositionLimit
    let maxSlots = SimilarityConstants.maxPersonSlots
    let sqrt2: CGFloat = sqrt(2.0)
```

#### 3.2. 매칭 후보 구조체

```swift
    // 매칭 후보 (전역 정렬용)
    struct MatchCandidate {
        let faceIdx: Int
        let slotID: Int
        let cost: Float           // Dist_fp
        let posDistNorm: CGFloat  // Dist_pos / √2
        let boundingBox: CGRect
    }
```

#### 3.3. 사진별 처리 루프

```swift
    for assetID in assetIDs {
        guard let faces = rawFacesMap[assetID] else {
            result[assetID] = []
            continue
        }

        // 이미지 로드
        var cgImage: CGImage? = nil
        if let photo = photoMap[assetID] {
            cgImage = try? await imageLoader.loadImage(for: photo)
        }

        // === Step 1: 모든 얼굴 FP 1회 생성 ===
        var faceFPs: [Int: VNFeaturePrintObservation] = [:]
        var faceData: [Int: (center: CGPoint, boundingBox: CGRect)] = [:]

        for (faceIdx, face) in faces.enumerated() {
            let center = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
            faceData[faceIdx] = (center: center, boundingBox: face.boundingBox)

            guard let image = cgImage else { continue }
            guard let cropped = try? FaceCropper.cropFace(from: image, boundingBox: face.boundingBox) else { continue }
            guard let fp = try? await analyzer.generateFeaturePrint(for: cropped) else {
                print("[FPFail] Face(\(faceIdx)): FP generation failed")
                continue
            }
            faceFPs[faceIdx] = fp
        }

        print("[FaceMatching] Photo \(assetID.prefix(8)): \(faces.count) faces, FP: \(faceFPs.count)/\(faces.count), Slots: \(activeSlots.count)")
```

#### 3.4. 부팅 처리 (첫 사진)

```swift
        // === Step 2: 부팅 (ActiveSlots 비어있을 때) ===
        if activeSlots.isEmpty {
            for (faceIdx, fp) in faceFPs {
                guard activeSlots.count < maxSlots else { break }
                guard let data = faceData[faceIdx] else { continue }

                // Quality Gate는 FaceDetector에서 이미 적용됨 (minFaceWidthRatio)
                let slot = PersonSlot(
                    id: nextSlotID,
                    featurePrint: fp,
                    center: data.center,
                    boundingBox: data.boundingBox
                )
                activeSlots.append(slot)
                print("[NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID)): Bootstrap")
                nextSlotID += 1
            }

            // 부팅 결과 저장
            var cachedFaces: [CachedFace] = []
            for slot in activeSlots {
                cachedFaces.append(CachedFace(
                    boundingBox: slot.boundingBox,
                    personIndex: slot.id,
                    isValidSlot: false
                ))
            }
            result[assetID] = cachedFaces
            continue
        }
```

#### 3.5. 비용 산출 및 전역 정렬

```swift
        // === Step 3: 비용 산출 ===
        var allCandidates: [MatchCandidate] = []

        for (faceIdx, faceFP) in faceFPs {
            guard let data = faceData[faceIdx] else { continue }

            // Top-K: 슬롯 수 > 5개면 상위 3개만
            var slotCosts: [(slot: PersonSlot, cost: Float, posDist: CGFloat)] = []

            for slot in activeSlots {
                guard let cost = try? analyzer.computeDistance(faceFP, slot.featurePrint) else { continue }
                let posDist = hypot(data.center.x - slot.center.x, data.center.y - slot.center.y)
                slotCosts.append((slot: slot, cost: cost, posDist: posDist))
            }

            // Top-K 필터링 (근사 최적화)
            let candidates: ArraySlice<(slot: PersonSlot, cost: Float, posDist: CGFloat)>
            if activeSlots.count > 5 {
                candidates = slotCosts.sorted { $0.cost < $1.cost }.prefix(3)
            } else {
                candidates = slotCosts[...]
            }

            for item in candidates {
                let posDistNorm = min(item.posDist / sqrt2, 1.0)
                allCandidates.append(MatchCandidate(
                    faceIdx: faceIdx,
                    slotID: item.slot.id,
                    cost: item.cost,
                    posDistNorm: posDistNorm,
                    boundingBox: data.boundingBox
                ))
            }
        }

        // === Step 4: 전역 정렬 (Cost 오름차순) ===
        allCandidates.sort { $0.cost < $1.cost }
```

#### 3.6. 매칭 확정 (Grey Zone 적용)

```swift
        // === Step 5: 매칭 확정 ===
        var usedFaces: Set<Int> = []
        var usedSlots: Set<Int> = []
        var cachedFaces: [CachedFace] = []

        for candidate in allCandidates {
            guard !usedFaces.contains(candidate.faceIdx) else { continue }
            guard !usedSlots.contains(candidate.slotID) else { continue }

            let cost = candidate.cost
            let posNorm = candidate.posDistNorm

            // 구간 판정
            if cost < greyZoneThreshold {
                // 확신 구간: 즉시 매칭
                usedFaces.insert(candidate.faceIdx)
                usedSlots.insert(candidate.slotID)
                cachedFaces.append(CachedFace(
                    boundingBox: candidate.boundingBox,
                    personIndex: candidate.slotID,
                    isValidSlot: false
                ))
                print("[Match] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost)) (Confident)")

            } else if cost < rejectThreshold {
                // 모호 구간: 위치 조건 확인
                if posNorm < greyZonePosLimit {
                    usedFaces.insert(candidate.faceIdx)
                    usedSlots.insert(candidate.slotID)
                    cachedFaces.append(CachedFace(
                        boundingBox: candidate.boundingBox,
                        personIndex: candidate.slotID,
                        isValidSlot: false
                    ))
                    print("[GreyMatch] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost)), PosNorm=\(String(format: "%.2f", posNorm))")
                } else {
                    print("[GreyReject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost)), PosNorm=\(String(format: "%.2f", posNorm))")
                }
            } else {
                // 거절 구간
                print("[Reject] Face(\(candidate.faceIdx)) -> Slot(\(candidate.slotID)): Cost=\(String(format: "%.2f", cost))")
            }
        }
```

#### 3.7. 신규 슬롯 등록

```swift
        // === Step 6: 신규 슬롯 등록 ===
        for (faceIdx, fp) in faceFPs {
            guard !usedFaces.contains(faceIdx) else { continue }
            guard activeSlots.count < maxSlots else {
                print("[Unassigned] Face(\(faceIdx)): Max slots reached")
                continue
            }
            guard let data = faceData[faceIdx] else { continue }

            // 신규 슬롯 생성
            let slot = PersonSlot(
                id: nextSlotID,
                featurePrint: fp,
                center: data.center,
                boundingBox: data.boundingBox
            )
            activeSlots.append(slot)

            usedFaces.insert(faceIdx)
            cachedFaces.append(CachedFace(
                boundingBox: data.boundingBox,
                personIndex: nextSlotID,
                isValidSlot: false
            ))

            print("[NewSlot] Face(\(faceIdx)) -> Slot(\(nextSlotID))")
            nextSlotID += 1
        }

        // FP 없는 얼굴은 CachedFace에 저장하지 않음 (캐시 미저장 정책)

        result[assetID] = cachedFaces
    }

    return result
}
```

---

## 3. 구현 순서

| 순서 | Task | 예상 변경량 | 위험도 |
|------|------|------------|--------|
| 1 | Task 1: 상수 추가/변경 | ~30줄 | 낮음 |
| 2 | Task 2: PersonSlot 구조체 | ~10줄 | 낮음 |
| 3 | Task 3: 함수 재작성 | ~150줄 | 높음 |
| 4 | 빌드 테스트 | - | - |

**총 예상 변경량**: 약 190줄 (기존 ~200줄 → 새 ~190줄)

---

## 4. 체크리스트 확인 결과

| 항목 | 상태 | 비고 |
|------|------|------|
| `personMatchThreshold` 변경 | Task 1에서 처리 | iOS 17+: 0.8→0.65 |
| 신규 상수 3개 | Task 1에서 처리 | |
| iOS 16/17 분기 | Task 1에서 처리 | 기존 패턴 유지 |
| `FaceCropper` nonisolated | **확인 필요** | 현재 코드 검토 필요 |
| 세마포어 사용 | 기존 구조 유지 | analyzer 내부에서 처리 |
| FaceDetector Quality 필터 | **minFaceWidthRatio만** | confidence 필터 없음 |
| Grey Zone 로그 | Task 3에서 구현 | |

---

## 5. 롤백 계획

- **롤백 커밋**: `59c339f`
- **명령어**: `git reset --hard 59c339f`

---

## 6. 테스트 케이스

### 6.1. 기존 문제 재현

| 케이스 | 설명 | 기대 결과 |
|--------|------|-----------|
| 위치 이동 | 같은 인물이 다른 위치 | 매칭 성공 (FP 우선) |
| 신규 인물 | 첫 사진에 없는 인물 | 신규 슬롯 생성 |
| 다른 인물 | fpDistance 0.59~0.67 | Grey Zone + 위치 조건으로 거절 |

### 6.2. Grey Zone 검증

| 케이스 | Cost | PosNorm | 기대 결과 |
|--------|------|---------|-----------|
| 확신 | 0.45 | any | 즉시 매칭 |
| Grey 통과 | 0.55 | 0.08 | 매칭 |
| Grey 거절 | 0.55 | 0.25 | 거절 |
| 거절 | 0.70 | any | 거절 |

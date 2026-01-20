# 260114SimilarEdit1 구현 계획

## 1. 수정 대상
- **파일**: `SimilarityAnalysisQueue.swift`
- **함수**: `assignPersonIndicesForGroup`
- **위치**: line 355 ~ 551

---

## 2. 현재 코드 문제점

| 문제 | 현재 코드 | 위치 |
|------|----------|------|
| 위치 필터 | `posDistance < 0.15` 조건으로 후보 제한 | line 464 |
| FP 재생성 | 각 후보 슬롯마다 FP 생성 | line 496, 505 |
| 순서 의존 | 얼굴 루프 순서대로 슬롯 즉시 점유 | line 450, 538 |
| 점수 혼용 | fpDistance와 posDistance가 bestScore에 섞임 | line 480, 525 |

---

## 3. Phase 1 구현 태스크

### Task 1: 상수 추가
**위치**: `SimilarityConstants.swift`
```swift
/// Top-K 후보 슬롯 수 (위치 기반 정렬 후 상위 K개만 FP 비교)
nonisolated static let topKCandidateSlots: Int = 4
```

### Task 2: 얼굴 FP 1회 생성
**변경 전**: 각 후보 슬롯마다 FP 생성
**변경 후**: 사진 처리 시작 시 모든 얼굴 FP를 미리 생성

```swift
// 사진별 처리 시작 시
var faceFPs: [Int: VNFeaturePrintObservation] = [:]  // faceIndex → FP

for (faceIdx, face) in faces.enumerated() {
    if let image = cgImage,
       let cropped = try? FaceCropper.cropFace(from: image, boundingBox: face.boundingBox),
       let fp = try? await analyzer.generateFeaturePrint(for: cropped) {
        faceFPs[faceIdx] = fp
    }
}
```

### Task 3: Top-K 후보 선정
**변경 전**: `posDistance < 0.15` 필터
**변경 후**: 모든 슬롯 거리 계산 → 정렬 → Top-K 선택

```swift
// 모든 슬롯과 거리 계산
var allCandidates: [(slot: ReferenceSlot, posDistance: CGFloat)] = []
for slot in referenceSlots {
    let posDistance = hypot(faceCenter.x - slot.center.x, faceCenter.y - slot.center.y)
    allCandidates.append((slot: slot, posDistance: posDistance))
}

// 거리순 정렬 후 Top-K 선택
let topK = SimilarityConstants.topKCandidateSlots
let candidateSlots = allCandidates
    .sorted { $0.posDistance < $1.posDistance }
    .prefix(topK)
```

### Task 4: 순서 의존성 완화 (전역 정렬 매칭)
**변경 전**: 얼굴별로 슬롯 즉시 점유
**변경 후**: 사진 내 모든 (face, slot) 쌍의 fpDistance 계산 → 정렬 → 순차 확정

```swift
// 매칭 후보 구조체
struct MatchCandidate {
    let faceIdx: Int
    let slotIdx: Int
    let fpDistance: Float
    let posDistance: CGFloat
}

// 1. 모든 (face, slot) 쌍 계산
var allMatches: [MatchCandidate] = []
for (faceIdx, face) in faces.enumerated() {
    guard let faceFP = faceFPs[faceIdx] else { continue }

    for slot in referenceSlots {
        guard let slotFP = slot.featurePrint else { continue }
        guard let fpDist = try? analyzer.computeDistance(faceFP, slotFP) else { continue }

        let posDist = hypot(faceCenter.x - slot.center.x, faceCenter.y - slot.center.y)
        allMatches.append(MatchCandidate(
            faceIdx: faceIdx,
            slotIdx: slot.index,
            fpDistance: fpDist,
            posDistance: posDist
        ))
    }
}

// 2. fpDistance 기준 정렬 (동률 시 posDistance)
allMatches.sort { m1, m2 in
    if abs(m1.fpDistance - m2.fpDistance) < 0.01 {
        return m1.posDistance < m2.posDistance
    }
    return m1.fpDistance < m2.fpDistance
}

// 3. 순차 확정 (greedy, 전역 정렬 기반)
var usedFaces: Set<Int> = []
var usedSlots: Set<Int> = []
var cachedFaces: [CachedFace] = []

for match in allMatches {
    guard !usedFaces.contains(match.faceIdx) else { continue }
    guard !usedSlots.contains(match.slotIdx) else { continue }
    guard match.fpDistance < featurePrintThreshold else { continue }

    usedFaces.insert(match.faceIdx)
    usedSlots.insert(match.slotIdx)

    cachedFaces.append(CachedFace(
        boundingBox: faces[match.faceIdx].boundingBox,
        personIndex: match.slotIdx,
        isValidSlot: false
    ))
}
```

### Task 5: Fallback 규칙 분리
**조건**: faceFP가 없는 얼굴만 위치 기반 fallback

```swift
// FP 없는 얼굴 처리 (fallback)
for (faceIdx, face) in faces.enumerated() {
    guard !usedFaces.contains(faceIdx) else { continue }
    guard faceFPs[faceIdx] == nil else { continue }  // FP가 있으면 이미 처리됨

    // 위치 기반 매칭 (가장 가까운 미사용 슬롯)
    let faceCenter = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
    var bestSlot: Int? = nil
    var bestDist: CGFloat = .infinity

    for slot in referenceSlots {
        guard !usedSlots.contains(slot.index) else { continue }
        let dist = hypot(faceCenter.x - slot.center.x, faceCenter.y - slot.center.y)
        if dist < bestDist && dist < 0.15 {  // 위치 fallback은 엄격하게
            bestDist = dist
            bestSlot = slot.index
        }
    }

    if let slotIdx = bestSlot {
        usedFaces.insert(faceIdx)
        usedSlots.insert(slotIdx)
        cachedFaces.append(CachedFace(
            boundingBox: face.boundingBox,
            personIndex: slotIdx,
            isValidSlot: false
        ))
    }
}
```

### Task 6: 검증 로그 추가

```swift
print("[FaceMatching] Photo \(assetID.prefix(8)): \(faces.count) faces, \(referenceSlots.count) slots")
print("[FaceMatching] FP generated: \(faceFPs.count)/\(faces.count)")
print("[FaceMatching] Matches found: \(cachedFaces.count)")
print("[FaceMatching] Fallback used: \(fallbackCount)")
```

---

## 4. 구현 순서

| 순서 | 태스크 | 예상 변경량 |
|------|--------|------------|
| 1 | Task 1: 상수 추가 | 3줄 |
| 2 | Task 2: 얼굴 FP 1회 생성 | 15줄 |
| 3 | Task 3: Top-K 후보 선정 | 10줄 |
| 4 | Task 4: 순서 의존성 완화 | 40줄 |
| 5 | Task 5: Fallback 규칙 분리 | 20줄 |
| 6 | Task 6: 검증 로그 추가 | 5줄 |

**총 예상 변경량**: 약 100줄 (기존 100줄 → 새 100줄)

---

## 5. 테스트 케이스

### 5.1 기존 문제 재현 테스트
- **케이스 1**: 기준 사진에 없는 인물 (사진 1: A, 사진 5,6: B)
- **케이스 2**: 위치 변화로 인한 잘못된 매칭

### 5.2 성능 테스트
- FP 생성 횟수 확인 (얼굴당 1회)
- Top-K 후보 수 확인 (K=4)

### 5.3 디버그 버튼으로 확인
- 모든 슬롯과의 fpDistance 출력
- 매칭 결과 검증

---

## 6. 롤백 계획
- 문제 발생 시 git revert로 원복
- 커밋 전 현재 상태 커밋 필수

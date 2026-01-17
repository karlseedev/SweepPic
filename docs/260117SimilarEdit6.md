# SimilarEdit6: S2 방지 + 매칭 품질 개선 계획

## 배경
- 결정성 보장 (Phase 1-1 ~ 1-5) 완료
- S2 미발생 확인
- GPT 인사이트: posNorm 포화(1.0), 연쇄 효과 문제

---

## 개선 순서

| 순서 | 항목 | 난이도 | 효과 |
|------|------|--------|------|
| 1 | 혼합 점수 정렬 (Face 처리 순서) | 쉬움 | 중간 |
| 2 | 혼합 점수 선택 (슬롯 선택) | 쉬움 | 중간 |
| 3 | EMA 갱신 (슬롯 center) | 중간 | 높음 |
| 4 | 2-pass 매칭 | 복잡 | 높음 |

---

## 1. 혼합 점수 정렬 (Face 처리 순서)

### 현재 (line 848-860)
```swift
let sortedFaceIds = lowQualityByFace.keys.sorted { faceA, faceB in
    let bestA = lowQualityByFace[faceA]?
        .filter { !usedSlots.contains($0.slotID) }
        .min(by: { $0.posDistNorm < $1.posDistNorm })  // posNorm만 사용
    ...
}
```

### 문제
- posNorm이 1.0으로 포화되면 변별력 없음
- cost 정보를 활용 안 함

### 개선
```swift
// 혼합 점수 계산 함수
func mixedScore(cost: Float, posNorm: CGFloat) -> CGFloat {
    let w1: CGFloat = 0.5  // cost 가중치
    let w2: CGFloat = 0.5  // posNorm 가중치
    return w1 * CGFloat(cost) + w2 * posNorm
}

let sortedFaceIds = lowQualityByFace.keys.sorted { faceA, faceB in
    let bestA = lowQualityByFace[faceA]?
        .filter { !usedSlots.contains($0.slotID) }
        .min(by: { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm)
                 < mixedScore(cost: $1.cost, posNorm: $1.posDistNorm) })
    let bestB = lowQualityByFace[faceB]?
        .filter { !usedSlots.contains($0.slotID) }
        .min(by: { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm)
                 < mixedScore(cost: $1.cost, posNorm: $1.posDistNorm) })

    let scoreA = bestA.map { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm) } ?? 1.0
    let scoreB = bestB.map { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm) } ?? 1.0
    if scoreA != scoreB { return scoreA < scoreB }
    return faceA < faceB
}
```

### 가중치 옵션
| 케이스 | w1 (cost) | w2 (posNorm) | 특성 |
|--------|-----------|--------------|------|
| A | 0.5 | 0.5 | 균형 (기본값) |
| B | 0.7 | 0.3 | cost 중심 |
| C | 0.3 | 0.7 | 위치 중심 |

---

## 2. 혼합 점수 선택 (슬롯 선택)

### 현재 (line 867-869)
```swift
let sortedByPos = candidates
    .filter { !usedSlots.contains($0.slotID) }
    .sorted { $0.posDistNorm < $1.posDistNorm }  // posNorm만 사용
```

### 개선
```swift
let sortedByMixed = candidates
    .filter { !usedSlots.contains($0.slotID) }
    .sorted { mixedScore(cost: $0.cost, posNorm: $0.posDistNorm)
            < mixedScore(cost: $1.cost, posNorm: $1.posDistNorm) }
```

### 효과
- posNorm 포화 시에도 cost로 변별
- 같은 mixedScore 함수 재사용

---

## 3. EMA 갱신 (슬롯 center)

### 현재 (line 767-781)
```swift
func updateSlotIfBetter(...) {
    // 위치 갱신 (항상 적용)
    activeSlots[idx].center = center  // 무조건 대체
    activeSlots[idx].boundingBox = boundingBox

    // Keep Best: norm이 더 높으면 임베딩도 갱신
    if norm > activeSlots[idx].norm {
        activeSlots[idx].embedding = embedding
        activeSlots[idx].norm = norm
    }
}
```

### 문제
- 저품질 매칭이 center를 오염시킴
- 다음 사진의 posNorm 계산에 영향 (연쇄 효과)

### 개선
```swift
func updateSlotIfBetter(slotID: Int, embedding: [Float], norm: Float,
                        center: CGPoint, boundingBox: CGRect,
                        matchQuality: MatchQuality) {  // 매칭 품질 추가
    if let idx = activeSlots.firstIndex(where: { $0.id == slotID }) {
        // EMA 가중치: 품질에 따라 결정
        let alpha: CGFloat
        switch matchQuality {
        case .confident:  // cost < greyZone
            alpha = 0.8  // 고품질: 빠르게 반영
        case .greyZone:   // greyZone <= cost < reject
            alpha = 0.5  // 중간 품질
        case .lowQuality: // LowQ 매칭
            alpha = 0.2  // 저품질: 완만하게 반영
        }

        // EMA로 center 갱신
        let oldCenter = activeSlots[idx].center
        activeSlots[idx].center = CGPoint(
            x: alpha * center.x + (1 - alpha) * oldCenter.x,
            y: alpha * center.y + (1 - alpha) * oldCenter.y
        )

        // boundingBox도 EMA 적용
        let oldBox = activeSlots[idx].boundingBox
        activeSlots[idx].boundingBox = CGRect(
            x: alpha * boundingBox.origin.x + (1 - alpha) * oldBox.origin.x,
            y: alpha * boundingBox.origin.y + (1 - alpha) * oldBox.origin.y,
            width: alpha * boundingBox.width + (1 - alpha) * oldBox.width,
            height: alpha * boundingBox.height + (1 - alpha) * oldBox.height
        )

        // Keep Best: norm이 더 높으면 임베딩도 갱신 (기존 로직 유지)
        if norm > activeSlots[idx].norm {
            activeSlots[idx].embedding = embedding
            activeSlots[idx].norm = norm
        }
    }
}

// MatchQuality enum 추가
enum MatchQuality {
    case confident   // cost < greyZoneThreshold
    case greyZone    // greyZone <= cost < rejectThreshold
    case lowQuality  // LowQ 매칭
}
```

### 호출부 수정
```swift
// Confident 매칭 (line 812)
updateSlotIfBetter(..., matchQuality: .confident)

// GreyZone 매칭 (line 828)
updateSlotIfBetter(..., matchQuality: .greyZone)

// LowQ 매칭 (line 889)
updateSlotIfBetter(..., matchQuality: .lowQuality)

// Vision Fallback (line 994)
updateSlotIfBetter(..., matchQuality: .lowQuality)
```

---

## 4. 2-pass 매칭

### 현재 구조
```
Step 5A: 고품질 (Confident + GreyZone) → greedy 순차 처리
Step 5B: 저품질 (LowQ) → greedy 순차 처리
```

### 문제
- greedy는 처리 순서에 민감
- 먼저 처리된 face가 잘못된 슬롯을 선점할 수 있음

### 개선: 2-pass 매칭
```
Pass 1: 확신 매칭만 (Confident only)
  - cost < greyZoneThreshold인 것만 즉시 매칭

Pass 2: 애매한 것들 글로벌 재정렬
  - GreyZone + LowQ를 모아서
  - mixedScore 기준으로 전역 정렬
  - 다시 greedy 매칭
```

### 구현 방향
```swift
// Pass 1: Confident만
var pendingCandidates: [MatchCandidate] = []
for candidate in sortedCandidates {
    if cost < greyZoneThreshold && !usedFaces.contains(...) {
        // 즉시 매칭
        usedFaces.insert(...)
        usedSlots.insert(...)
    } else {
        // 보류
        pendingCandidates.append(candidate)
    }
}

// Pass 2: 보류된 것들 + LowQ 글로벌 재정렬
let allPending = pendingCandidates + lowQualityCandidates
let globalSorted = allPending
    .filter { !usedFaces.contains($0.faceIdx) && !usedSlots.contains($0.slotID) }
    .sorted { mixedScore($0) < mixedScore($1) }

for candidate in globalSorted {
    // greedy 매칭 (조건 확인 후)
}
```

### 복잡도
- 기존 Step 5A, 5B 구조 변경 필요
- 테스트 충분히 필요

---

## 적용 계획

| Phase | 내용 | 테스트 |
|-------|------|--------|
| 6-1 | 혼합 점수 정렬 | S2 테스트 |
| 6-2 | 혼합 점수 선택 | S2 테스트 |
| 6-3 | EMA 갱신 | S2 + 다중 그룹 테스트 |
| 6-4 | 2-pass 매칭 | 전체 회귀 테스트 |

각 Phase마다:
1. 커밋 (수정 전)
2. 코드 수정
3. S2 테스트
4. 결과 문서화
5. 커밋 (수정 후)

---

## 가중치 튜닝 가이드

### mixedScore 가중치
```swift
// 현재 권장값
let w1: CGFloat = 0.5  // cost
let w2: CGFloat = 0.5  // posNorm

// posNorm 포화가 심하면
let w1: CGFloat = 0.7  // cost 중시
let w2: CGFloat = 0.3
```

### EMA alpha 값
```swift
// 현재 권장값
confident: 0.8   // 빠르게 반영
greyZone:  0.5   // 중간
lowQuality: 0.2  // 완만하게

// 연쇄 효과가 심하면
lowQuality: 0.1  // 더 완만하게
```

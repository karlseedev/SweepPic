# SimilarEdit6: S2 방지 + 매칭 품질 개선 계획

## 배경
- 결정성 보장 (Phase 1-1 ~ 1-5) 완료
- S2 미발생 확인
- GPT 인사이트: posNorm 포화(1.0), 연쇄 효과 문제

---

## 개선 순서

| 순서 | 항목 | 난이도 | 목적 | 효과 |
|------|------|--------|------|------|
| 1 | 혼합 점수 정렬 (Face 처리 순서) | 쉬움 | **성능** | 중간 |
| 2 | 혼합 점수 선택 (슬롯 선택) | 쉬움 | **성능** | 중간 |
| 3 | 2-pass 매칭 확장 | 복잡 | **성능** | 높음 |
| 4 | EMA 갱신 (슬롯 center) | 중간 | **안정성** | 중간 |

> **Note:** 6-3(EMA)는 성능보다 안정성 목적이므로 후순위로 이동

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
| A | 0.5 | 0.5 | 균형 |
| **B** | **0.7** | **0.3** | **cost 중심 (권장)** |
| C | 0.3 | 0.7 | 위치 중심 |

> **권장:** posNorm이 1.0으로 포화되는 경우가 많으므로 **w1=0.7~0.8** 권장.
> 포화 상황에서 cost만 변별력을 가지므로 cost 가중치를 높여야 효과적.

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

## 4. EMA 갱신 (슬롯 center) - 안정성 목적

> **목적:** 성능(정확도) 개선보다 **안정성** 목적.
> 연쇄 효과(저품질 매칭 → center 오염 → 다음 사진 영향)를 완화.

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

## 3. 2-pass 매칭 확장 (기존 구조 기반)

> **중요:** 현재 코드에 이미 2-pass 구조가 존재함 (HighQ → LowQ).
> 이 개선은 **새 구조가 아닌 기존 구조의 확장**임.

### 현재 구조 (이미 2-pass)
```
Step 5A: HighQ (Confident + GreyZone) → cost 기준 greedy
Step 5B: LowQ → posNorm 기준 greedy (별도 처리)
```

### 문제
- GreyZone이 HighQ에 섞여 있어서 Confident와 함께 처리됨
- LowQ가 별도 경로로 분리되어 글로벌 최적화 불가

### 개선: 3-tier 확장
```
Pass 1: Confident only (cost < greyZoneThreshold)
  - 즉시 매칭 (변경 없음)

Pass 2: GreyZone + LowQ 글로벌 재정렬
  - GreyZone을 LowQ와 합쳐서 mixedScore 기준 정렬
  - 통합된 greedy 매칭
```

### 구현 방향
```swift
// Step 5A 수정: Confident만 즉시 매칭
var greyZoneCandidates: [MatchCandidate] = []
for candidate in sortedCandidates {
    let cost = candidate.cost
    if cost < greyZoneThreshold && !usedFaces.contains(candidate.faceIdx) {
        // Confident: 즉시 매칭 (기존 로직)
        usedFaces.insert(...)
        usedSlots.insert(...)
    } else if cost < rejectThreshold {
        // GreyZone: 보류
        greyZoneCandidates.append(candidate)
    }
}

// Step 5B 수정: GreyZone + LowQ 통합 처리
let allPending = greyZoneCandidates + lowQualityCandidates
let globalSorted = allPending
    .filter { !usedFaces.contains($0.faceIdx) && !usedSlots.contains($0.slotID) }
    .sorted { mixedScore($0) < mixedScore($1) }

for candidate in globalSorted {
    // 통합 조건 검사 후 매칭
    let posNorm = candidate.posDistNorm
    let cost = candidate.cost

    // GreyZone 조건 또는 LowQ 조건 충족 시 매칭
    if (posNorm < greyZonePosLimit) ||
       (posNorm <= lowQualityPosLimit && cost < lowQualityCostLimit) {
        // 매칭
    }
}
```

### 복잡도
- Step 5A, 5B 경계 수정 필요
- GreyZone 분리 로직 추가
- 테스트 충분히 필요

### 리스크
- 기존 동작과 다른 결과 가능성
- 충분한 회귀 테스트 필수

---

## 적용 계획

| Phase | 내용 | 목적 | 테스트 |
|-------|------|------|--------|
| 6-1 | 혼합 점수 정렬 | 성능 | S2 테스트 |
| 6-2 | 혼합 점수 선택 | 성능 | S2 테스트 |
| 6-3 | 2-pass 매칭 확장 | 성능 | 전체 회귀 테스트 |
| 6-4 | EMA 갱신 | 안정성 | S2 + 다중 그룹 테스트 |

> **순서 근거:** 성능 목적 개선(6-1, 6-2, 6-3)을 먼저 진행 후,
> 안정성 목적(6-4)은 마지막에 적용.

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
// 권장값 (posNorm 포화 고려)
let w1: CGFloat = 0.7  // cost (권장)
let w2: CGFloat = 0.3  // posNorm

// 균형 옵션 (포화가 적은 경우)
let w1: CGFloat = 0.5
let w2: CGFloat = 0.5
```

> **posNorm 포화 문제:** 로그에서 posNorm=1.0이 빈번하게 관찰됨.
> 포화 시 cost만 변별력을 가지므로 **w1=0.7~0.8** 권장.

### EMA alpha 값
```swift
// 현재 권장값
confident: 0.8   // 빠르게 반영
greyZone:  0.5   // 중간
lowQuality: 0.2  // 완만하게

// 연쇄 효과가 심하면
lowQuality: 0.1  // 더 완만하게
```

---

## 적용 결과 (2026-01-18)

### 6-1: 혼합 점수 정렬 (Face 처리 순서) ✅ 적용

| 항목 | 내용 |
|------|------|
| 커밋 | 141b096 |
| 결과 | S2 미발생, 정상 동작 |
| 상태 | **유지** |

### 6-2: 혼합 점수 선택 (슬롯 선택) ❌ 롤백

| 항목 | 내용 |
|------|------|
| 커밋 | bc87a2c (적용) → 1fb637e (롤백) |
| 결과 | **S1 문제 발생** (같은 사람이 여러 슬롯에 분리) |
| 상태 | **폐기** |

**S1 발생 원인 분석:**
```
6-2 흐름:
1. mixedScore로 슬롯 선택 → "멀지만 cost 낮은" Slot 선택
2. posNorm 검증 → 거절 (posNorm > lowQualityPosLimit)
3. 더 가까운 슬롯 기회 상실 → S1

예시:
- Slot 1: 위치 가까움(posNorm=0.1), cost=0.7
- Slot 2: 위치 멈(posNorm=0.5), cost=0.4

기존 (posNorm 우선): Slot 1 선택 ✅
6-2 (mixedScore):
  - Slot 1: 0.7×0.7 + 0.3×0.1 = 0.52
  - Slot 2: 0.7×0.4 + 0.3×0.5 = 0.43
  → Slot 2 선택 → posNorm 검증 실패 → S1
```

**핵심 교훈:**
- LowQ 얼굴은 임베딩 품질이 낮음 → cost 신뢰도 낮음
- LowQ 슬롯 선택은 **위치 우선**이 올바른 전략
- 6-1(Face 처리 순서)과 6-2(슬롯 선택)는 다른 문제

### 6-3: 2-pass 매칭 확장 ❌ 롤백

| 항목 | 내용 |
|------|------|
| 커밋 | 69068b3 (적용) → 1fb637e (롤백) |
| 결과 | 6-2 포함하여 동일 문제 |
| 상태 | **폐기** |

### 6-4: EMA 갱신 ⏸️ 보류

| 항목 | 내용 |
|------|------|
| 상태 | 미적용, 추후 검토 |

---

## 최종 결론

| Phase | 상태 | 이유 |
|-------|------|------|
| 6-1 | ✅ 유지 | Face 처리 순서에 mixedScore 적용, 정상 동작 |
| 6-2 | ❌ 폐기 | LowQ 슬롯 선택에 cost 섞으면 S1 발생 |
| 6-3 | ❌ 폐기 | 6-2 포함, 동일 문제 |
| 6-4 | ⏸️ 보류 | 필요 시 추후 검토 |

**6-2 대안 (미적용, 참고용):**
- posNorm 하드 필터 통과 후보만 대상으로
- posNorm 차이 < 0.02일 때만 cost로 tie-break
- 효과 불확실하여 현재는 적용하지 않음

---

## 기술 노트

### Swift sorted()는 stable sort가 아님

> **주의:** Swift의 `sorted()`는 stable sort를 보장하지 않음.
> 동점 시 순서가 임의이므로, 결정성이 필요한 경우 명시적 tie-break 필요.

```swift
// 잘못된 가정
.sorted { $0.posDistNorm < $1.posDistNorm }  // 동점 시 순서 임의

// 올바른 방식 (tie-break 추가)
.sorted {
    if $0.posDistNorm != $1.posDistNorm {
        return $0.posDistNorm < $1.posDistNorm
    }
    return $0.slotID < $1.slotID  // 명시적 tie-break
}
```

# Similar Photo Face Matching - S2 원인 분석

**문서 버전:** 2026-01-16
**기준:** 261116SimilarEdit5-2.md + 결정성 수정 후 S2 재발 분석

---

## 1. 현재 상황

### 1.1 문제 발생 경위

1. **결정성 보장 수정 적용** (c87acce)
   - Dictionary 순회 시 `keys.sorted()` 사용
   - 동일 입력 → 동일 출력 보장

2. **S2 재발 확인**
   - 결정성 수정 후 다른 사람이 같은 슬롯에 합쳐지는 S2 문제 발생
   - 롤백(6b594c2) 후에도 S2 지속 발생

3. **현재 상태**
   - 결정성 수정 전 상태로 롤백 완료 (6b594c2)
   - S2 원인 분석용 디버그 도구 구현 완료

### 1.2 GPT 분석 결과

**핵심 원인:** 결정성 보장 자체가 문제가 아니라, **greedy 매칭의 순서 의존성**이 근본 원인

```
기존: Dictionary 순회 순서 (비결정적) → 운 좋게 맞는 경우 존재
수정: sorted() 순서 (결정적) → 순서가 바뀌면서 기존에 맞던 매칭이 틀어짐
```

**greedy 매칭 문제:**
- 먼저 처리되는 후보가 슬롯을 선점
- 순서에 따라 결과가 달라짐
- 결정성 보장으로 순서가 고정되면서 문제가 표면화

---

## 2. S2 원인 분석 도구

### 2.1 녹색 디버그 버튼 (개미 아이콘)

**파일:** `S2DebugAnalyzer.swift`

**기능:** GPT 제안 9개 디버그 로그 출력

### 2.2 9개 로그 상세

| # | 로그 | 내용 | 목적 |
|---|------|------|------|
| 1 | 얼굴 처리 순서 | Original Dict Order + Sorted Order | 순서 변화 비교 |
| 2 | 슬롯 스냅샷 | id, center, norm, bbox | 매칭 전 슬롯 상태 |
| 3 | 후보 리스트 | Top-K 전/후 분리 출력 | 필터링 영향 확인 |
| 4 | 전역 정렬 결과 | rank, faceIdx, slotID, cost, posNorm, norm | 최종 후보 순서 |
| 5 | 동점 그룹 | cost 차이 < 0.001 | tie-breaker 영향 확인 |
| 6 | HighQ 매칭 | Confident/GreyZone/Reject | 고품질 매칭 단계 |
| 7 | LowQ 매칭 | sortedByPos 전체 리스트 | 저품질 매칭 단계 |
| 8 | NewSlot 생성 | minCost, threshold | 신규 슬롯 생성 근거 |
| 9 | 종결 로그 | uiLabel → slotID + center/bbox | 최종 매핑 결과 |

### 2.3 설정값 출력

```
[Config] greyZoneThreshold=0.45, rejectThreshold=0.637
[Config] greyZonePosLimit=0.20, minEmbeddingNorm=7.0
[Config] lowQualityPosLimit=0.25, lowQualityCostLimit=0.787
[Config] topK=3 (when slots > 5), tieGroupThreshold=0.001
```

---

## 3. 분석 방법

### 3.1 비교 테스트 절차

1. **롤백 상태에서 녹색 버튼** → 로그 저장
2. **결정성 수정 적용**
3. **결정성 상태에서 녹색 버튼** → 로그 저장
4. **두 로그 비교** → 차이점 확인

### 3.2 주요 확인 포인트

| 확인 항목 | 비교 방법 |
|----------|----------|
| 순서 변화 | LOG 1의 Original vs Sorted 비교 |
| 선점 순서 | LOG 4의 rank 비교 |
| 동점 상황 | LOG 5에서 tie-breaker 영향 확인 |
| 매칭 결과 | LOG 9의 최종 매핑 비교 |

---

## 4. 예상 원인 후보

### 4.1 greedy 순서 의존성

```swift
// 현재 코드 (순서에 따라 결과 달라짐)
for candidate in sortedCandidates {
    if !usedFaces.contains(candidate.faceIdx) &&
       !usedSlots.contains(candidate.slotID) {
        // 먼저 온 후보가 슬롯 선점
        usedFaces.insert(candidate.faceIdx)
        usedSlots.insert(candidate.slotID)
    }
}
```

### 4.2 해결 방향 후보

| 방향 | 설명 | 장점 | 단점 |
|------|------|------|------|
| 슬롯 중심 매칭 | 각 슬롯에 대해 최적 후보 선택 | 순서 무관 | 구현 복잡 |
| Hungarian 알고리즘 | 전역 최적 매칭 | 최적해 보장 | 성능 부담 |
| 2-pass 매칭 | Confident → Ambiguous 분리 | 간단 | 부분 해결 |

---

## 5. Phase 1 세분화 테스트 (2026-01-17)

### 5.1 테스트 계획

결정성 수정을 단계별로 적용하여 S2 발생 시점 특정:

| 단계 | 항목 | 영향 범위 |
|------|------|----------|
| 1-1 | faceNorms + faceEmbeddings 순회 | 후보 생성 순서 |
| 1-2 | 전역 정렬 tie-breaker | 매칭 우선순위 |
| 1-3 | lowQualityByFace 순회 | 저품질 매칭 순서 |
| 1-4 | 신규 슬롯 등록 순회 | 슬롯 생성 순서 |
| 1-5 | Vision fallback 순회 | fallback 매칭 순서 |

### 5.2 테스트 결과

| 단계 | 적용 코드 | S2 발생 | 로그 파일 |
|------|----------|---------|-----------|
| 1-1 | `faceEmbeddings.keys.sorted()` | ❌ 미발생 | 0116logOk3.md |
| 1-2 | tie-breaker (faceIdx → slotID) | ✅ **발생** | 0116logNo1.md |

### 5.3 적용된 코드

**1-1: faceNorms + faceEmbeddings 순회 (line 700, 705)**
```swift
var faceNorms: [Int: Float] = [:]
for faceIdx in faceEmbeddings.keys.sorted() {
    guard let embedding = faceEmbeddings[faceIdx] else { continue }
    faceNorms[faceIdx] = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
}

for faceIdx in faceEmbeddings.keys.sorted() {
    // ... 후보 생성 로직
}
```

**1-2: 전역 정렬 tie-breaker (line 754-758)**
```swift
allCandidates.sort {
    if $0.cost != $1.cost { return $0.cost < $1.cost }
    if $0.faceIdx != $1.faceIdx { return $0.faceIdx < $1.faceIdx }
    return $0.slotID < $1.slotID
}
```

---

## 6. S2 원인 분석 결과

### 6.1 차이 시작점

**Photo 8199D9B4의 LowQ 매칭**:

| 항목 | 1-1 (Ok3) | 1-2 (No1) |
|------|-----------|-----------|
| Face(0) | Slot(2) 매칭 (PosNorm=0.08) | **Rejected** (PosNorm=0.26) |
| Face(2) | Slot(3) 매칭 (PosNorm=0.13) | **Slot(2)** 매칭 (PosNorm=0.09) |
| 결과 | 2개 얼굴 (c3, b5) | 3개 얼굴 (c3, b5, **a3**) |

### 6.2 연쇄 효과

```
1-2 tie-breaker 적용
    ↓
allCandidates 정렬 순서 변화
    ↓
lowQualityByFace 삽입 순서 변화
    ↓
8199D9B4에서 Face(2)가 Slot(2) 먼저 선점 (기존: Face(0))
    ↓
Slot(2) center가 Face(2) 위치로 갱신
    ↓
이후 사진에서 posNorm 계산 달라짐
    ↓
A1EF6352: PosNorm 0.16 → 0.01
A9A61D7E: LowQMatch Slot(1) → Slot(3)
    ↓
a3가 추가로 매칭됨 (S2)
```

### 6.3 핵심 발견

**GPT 분석:**
> S2의 직접 원인은 "8199D9B4에서 LowQ face 처리 순서가 바뀌어 slot2 선점이 뒤바뀐 것"

**Claude 분석:**
> 1-2가 직접 LowQ 순서를 바꾸는 게 아니라, allCandidates 정렬 → lowQualityByFace 삽입 순서 → 슬롯 위치 갱신 차이 → posNorm 차이로 이어지는 간접 영향

**합의된 결론:**
- 결정성이 깨진 게 아니라, **결정된 기준이 바뀌어 결과가 달라진 것**
- 1-2 tie-breaker가 "랜덤"을 만든 게 아니라, **allCandidates 정렬이 바뀌면서 LowQ 처리 순서가 바뀌고 S2 유발**

### 6.4 추가 로그 필요 (증명용)

| 로그 | 목적 |
|------|------|
| lowQualityCandidates 순서 | allCandidates에서 필터링된 순서 |
| lowQualityByFace key 삽입 순서 | Dictionary 순회 순서 결정 요인 |
| 8199D9B4 Face(0)/Face(2)의 bestByPos | 왜 Face(2)가 먼저 Slot(2)를 잡는지 |

---

## 7. 다음 단계

### 7.1 옵션 A: 추가 로그로 증명

- S2DebugAnalyzer에 6.4 로그 추가
- Face(2)가 Slot(2) 먼저 선점하는 이유 명확히 확인

### 7.2 옵션 B: 해결 방향 검토

| 방향 | 설명 | 장점 | 단점 |
|------|------|------|------|
| 슬롯 중심 매칭 | 각 슬롯에 대해 최적 후보 선택 | 순서 무관 | 구현 복잡 |
| Hungarian 알고리즘 | 전역 최적 매칭 | 최적해 보장 | 성능 부담 |
| LowQ 순서 고정 | lowQualityByFace를 faceIdx 순으로 처리 | 간단 | 부분 해결 |

---

## 8. 커밋 히스토리

| 커밋 | 내용 |
|------|------|
| 6b594c2 | 41445d4 상태로 롤백 + PosCandidate 검증 결과 문서화 |
| a0cdbfe | S2 원인 분석용 녹색 디버그 버튼 추가 |
| cb36989 | S2 디버그 로직을 별도 파일로 분리 (S2DebugAnalyzer.swift) |

---

## 9. 파일 변경 내역

### 9.1 신규 파일

| 파일 | 역할 |
|------|------|
| `S2DebugAnalyzer.swift` | S2 원인 분석용 9개 로그 출력 |

### 9.2 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `FaceComparisonViewController.swift` | 녹색 버튼 추가, 디버그 로직 분리 |

---

## 10. 변경 이력

| 일시 | 내용 |
|------|------|
| 2026-01-16 | 문서 생성, S2 원인 분석 도구 구현 내역 정리 |
| 2026-01-17 | Phase 1 세분화 테스트 결과 추가 (1-1 OK, 1-2 S2 발생) |
| 2026-01-17 | S2 원인 분석 결과 추가 (8199D9B4 LowQ 매칭 순서 차이) |
| 2026-01-17 | GPT/Claude 분석 비교, 합의 결론 정리 |

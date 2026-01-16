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

## 5. 다음 단계

### 5.1 즉시 실행

1. **현재 상태(롤백)에서 녹색 버튼 → 로그 저장**
2. **결정성 수정 적용**
3. **결정성 상태에서 녹색 버튼 → 로그 저장**
4. **두 로그 비교하여 원인 특정**

### 5.2 원인 특정 후

- 원인에 따라 해결 방향 결정
- 슬롯 중심 매칭 또는 다른 방법 적용

---

## 6. 커밋 히스토리

| 커밋 | 내용 |
|------|------|
| 6b594c2 | 41445d4 상태로 롤백 + PosCandidate 검증 결과 문서화 |
| a0cdbfe | S2 원인 분석용 녹색 디버그 버튼 추가 |
| cb36989 | S2 디버그 로직을 별도 파일로 분리 (S2DebugAnalyzer.swift) |

---

## 7. 파일 변경 내역

### 7.1 신규 파일

| 파일 | 역할 |
|------|------|
| `S2DebugAnalyzer.swift` | S2 원인 분석용 9개 로그 출력 |

### 7.2 수정 파일

| 파일 | 변경 내용 |
|------|----------|
| `FaceComparisonViewController.swift` | 녹색 버튼 추가, 디버그 로직 분리 |

---

## 8. 변경 이력

| 일시 | 내용 |
|------|------|
| 2026-01-16 | 문서 생성, S2 원인 분석 도구 구현 내역 정리 |

# 얼굴 매칭 로직 개선 설계 (Final v2)

## 1. 핵심 문제점 요약

| 결함 | 설명 |
|------|------|
| **위치 선행 필터링** | `posDistance < 0.15` 미충족 시 FP 비교 차단 |
| **정적 기준 슬롯** | 첫 사진 이후 등장 인물 인식 불가 |
| **선착순 탐욕 매칭** | 순서 의존적 매칭으로 최적 짝 놓침 |
| **좁은 데이터 마진** | 동일인(0.56~0.58) vs 타인(0.59~0.67) 차이 미세 |

---

## 2. 개선 알고리즘: 전역 후보 정렬 기반 근사 매칭

> **Note**: 완전한 전역 최적화(헝가리안 등)가 아닌, 후보를 Cost 순 정렬 후 Greedy 확정하는 **근사(Approximation)** 방식입니다. Top-K 제한 적용 시 일부 후보가 누락될 수 있습니다.

### 2.1. 동적 인물 풀 (Dynamic Person Pool)

- **초기화(Bootstrapping)**: `ActiveSlots`가 비어있는 첫 사진 처리 시, Quality Gate 통과 얼굴을 신규 슬롯으로 등록
- **부팅 실패 처리**: Quality Gate 통과 얼굴이 없으면 슬롯 0개 유지
  - **정책**: 기존 동작과 동일하게 각 사진의 `CachedFace` 배열을 빈 배열(`[]`)로 저장
  - 그룹 자체는 유지되나, 유효 슬롯(`validSlots`)이 없어 그룹 형성 조건 미충족
- **상한 제한**: `maxPersonSlots` (기본 10개) 초과 시 신규 생성 중단
- **기준 FP 정책**: **Keep First** - 슬롯 최초 생성 시의 FP를 유지 (품질 기반 갱신 없음, 단순성 우선)

### 2.2. 비용 함수 (Cost Function)

**Cost = Dist_fp** (위치 페널티 미포함)

- **Dist_fp**: Feature Print 거리
- 위치 정보는 Grey Zone에서만 활용 (이중 반영 방지)

### 2.3. 매칭 구간 (Grey Zone 전략)

위치 조건을 별도 단계에서만 적용하여 이중 반영 방지:

| 구간 | iOS 17+ | iOS 16 | 조건 |
|------|---------|--------|------|
| **확신** | Cost < 0.50 | Cost < 6.0 | 즉시 매칭 |
| **모호(Grey)** | 0.50 ≤ Cost < 0.65 | 6.0 ≤ Cost < 8.0 | `Dist_pos_norm < 0.15` 시에만 매칭 |
| **거절** | Cost ≥ 0.65 | Cost ≥ 8.0 | 매칭 실패 |

**Dist_pos 정규화**:
```
Dist_pos_norm = Dist_pos / √2
```
- 원본 유클리드 거리(0 ~ √2)를 0 ~ 1 범위로 정규화
- Grey Zone 위치 조건은 정규화된 값 기준으로 적용

### 2.4. 매칭 프로세스 (Step-by-Step)

```
1. 준비 (Preparation)
   - 현재 사진의 모든 얼굴 FP 생성 (1회만, 캐싱)
   - FP 생성 실패 얼굴: 매칭 후보에서 제외, CachedFace에도 저장하지 않음

2. 비용 산출 (Cost Calculation)
   - 모든 (얼굴 N) × (슬롯 M) 조합의 Cost(=Dist_fp) 계산
   - [근사 최적화] 슬롯 수 > 5개인 경우: 각 얼굴당 Top-3 슬롯만 후보 등록
     (일부 최적 매칭이 누락될 수 있으나 성능 확보)

3. 전역 정렬 (Global Sorting)
   - 모든 후보를 Cost 오름차순 정렬

4. 확정 (Assignment)
   - 정렬된 리스트 순회:
     - 이미 사용된 얼굴/슬롯이면 Skip
     - 확신 구간: 즉시 매칭 → CachedFace 저장
     - 모호 구간: Dist_pos_norm < 0.15 시에만 매칭 → CachedFace 저장
     - 거절 구간: Skip

5. 신규 등록 (New Slot)
   - 미매칭 얼굴 중 Quality Gate 통과 시 새 슬롯 생성 → CachedFace 저장
   - maxPersonSlots 초과 시 생성 중단

6. 미매칭 처리 (Unassigned)
   - 매칭 실패 + 신규 등록 실패 얼굴: CachedFace에 저장하지 않음
   - 뷰어에 표시되지 않고, 그룹 형성에도 배제됨
```

### 2.5. 얼굴별 캐시 처리 요약

| 상태 | CachedFace 저장 | personIndex | isValidSlot |
|------|-----------------|-------------|-------------|
| FP 생성 실패 | ❌ 미저장 | - | - |
| 매칭 성공 | ✅ 저장 | 슬롯 ID | false (추후 계산) |
| 신규 슬롯 생성 | ✅ 저장 | 새 슬롯 ID | false |
| 매칭 실패 + 신규 실패 | ❌ 미저장 | - | - |

---

## 3. 구현 세부 지침

### 3.1. 성능 및 자원 관리

- **FP 1회 생성**: 사진당 얼굴별로 FP를 딱 한 번만 생성하여 Dictionary에 캐싱
- **동시성 제한**: FP 생성 시 기존 `SimilarityAnalysisQueue`의 세마포어(`maxConcurrentAnalysis`) 준수
- **Top-K 비교 (근사 최적화)**: 슬롯 수 > 5개인 경우, 각 얼굴당 Dist_fp 기준 상위 3개 슬롯만 비용 계산
  - 전역 최적 매칭이 아닌 근사 매칭임을 인지

### 3.2. 품질 게이트 (Quality Gate)

신규 슬롯 생성 조건:
- **Confidence**: `VNFaceObservation.confidence` > 0.8
  - (참고: 현재 FaceDetector의 필터링 여부 확인 필요)
- **Size**: `boundingBox` 면적 > `minFaceWidthRatio²` (현재 0.04² = 0.0016)
  - (참고: 현재 FaceDetector의 필터링 여부 확인 필요)

---

## 4. 파라미터 (SimilarityConstants)

### 4.1. 기존 상수 변경

| 상수명 | 현재값 | 변경값 | 비고 |
|--------|--------|--------|------|
| `personMatchThreshold` | iOS 17+: 0.8 | iOS 17+: **0.65** | 거절 구간 임계값 |
| `personMatchThreshold` | iOS 16: 8.0 | iOS 16: **8.0 (변경 없음)** | 기존과 동일 |
| `minFaceWidthRatio` | 0.04 | 0.04 (변경 없음) | Quality Gate 크기 기준 |
| `maxConcurrentAnalysis` | 5 | 5 (변경 없음) | FP 생성 동시성 제한 |

### 4.2. 신규 상수 추가 필요

| 상수명 | 제안값 (iOS 17+) | 제안값 (iOS 16) | 용도 |
|--------|------------------|-----------------|------|
| `greyZoneThreshold` | 0.50 | 6.0 | 확신/모호 구간 경계 |
| `greyZonePositionLimit` | 0.15 | 0.15 | 모호 구간 위치 조건 (정규화 기준) |
| `maxPersonSlots` | 10 | 10 | 인물 수 상한 |

---

## 5. 구현 전 체크리스트

- [ ] `personMatchThreshold` 값 변경 (iOS 17+: 0.8 → 0.65, iOS 16: 변경 없음)
- [ ] 신규 상수 3개 추가 (`greyZoneThreshold`, `greyZonePositionLimit`, `maxPersonSlots`)
- [ ] iOS 16/17 분기 처리 확인 (Cost 계산 시 버전별 임계값 사용)
- [ ] `FaceCropper` 백그라운드 호출 가능 여부 확인 (`nonisolated` 처리)
- [ ] FP 생성 시 기존 세마포어 사용 확인
- [ ] FaceDetector의 기존 Quality 필터링 여부 확인
- [ ] Grey Zone 판정 로그 출력 구현

---

## 6. 검증 로그 포맷

```
[Match] Face(0) -> Slot(1): Cost=0.45 (Confident)
[GreyMatch] Face(1) -> Slot(2): Cost=0.52, PosNorm=0.08 (Grey Zone Pass)
[GreyReject] Face(2) -> Slot(1): Cost=0.55, PosNorm=0.18 (Grey Zone Fail)
[Reject] Face(3) -> Slot(2): Cost=0.70 (Over Threshold)
[NewSlot] Face(4) -> Slot(3): Quality=0.92
[Unassigned] Face(5): No match, Quality=0.65 (Below Gate)
[FPFail] Face(6): FP generation failed
```

---

## 7. 결론

본 설계는:
1. **전역 후보 정렬 기반 근사 매칭**으로 순서 의존성 제거
2. **Grey Zone 전략**으로 좁은 마진 변별
3. **위치 단일 반영**으로 과도한 엄격성 방지
4. **iOS 버전별 임계값 분리**로 호환성 확보 (iOS 17+ 변경, iOS 16 유지)
5. **캐시 미저장 정책**으로 기존 코드 충돌 방지
6. **명확한 캐시 처리 흐름**으로 뷰어/그룹 일관성 유지

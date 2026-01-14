# 얼굴 매칭 로직 심층 분석 및 개선 설계 (Ultimate)

## 1. 현황 및 핵심 문제점 분석 (Why)

기존 `assignPersonIndicesForGroup` 로직을 정밀 분석한 결과, 단순히 임계값을 조정하는 것으로는 해결할 수 없는 **구조적 결함 3가지**가 식별되었습니다.

### 1.1. 위치 기반 선행 필터링 (Fatal Flaw)
*   **현상**: `위치 거리 < 0.15`를 만족하지 않으면 Feature Print(얼굴 특징) 비교 자체를 수행하지 않음.
*   **문제**: 같은 사람이 사진 촬영 중 이동하거나, 카메라 구도가 바뀌어 화면 내 위치가 달라지면 **완전히 다른 사람으로 취급**됨.

### 1.2. 정적 기준 슬롯 (Static Reference)
*   **현상**: **첫 번째 사진**에 등장한 얼굴들만 '기준 슬롯'으로 생성됨.
*   **문제**: 첫 번째 사진에 없다가 나중에 등장하는 인물('New Person')은 들어갈 슬롯이 없어 엉뚱한 사람과 매칭되거나 누락됨.

### 1.3. 선착순 탐욕 매칭 (Greedy Matching Failure)
*   **현상**: 얼굴 루프를 돌면서 기준을 통과하는 첫 번째 슬롯을 즉시 점유(Lock).
*   **문제**: 더 적합한 매칭 대상(진짜 주인)이 뒤에 있어도, 앞선 덜 적합한 대상이 자리를 차지해버림. (Global Optimization 부재)

---

## 2. 심화 개선 알고리즘: 전역 최적화 (Global Optimization)

위 문제들을 해결하기 위해 **Cost Matrix 기반의 전역 최적 매칭**과 **동적 슬롯 할당** 방식을 도입합니다.

### 2.1. 동적 인물 풀 (Dynamic Person Pool)
*   **개념**: 분석이 진행됨에 따라 성장하는 인물 목록(`ActiveSlots`) 운용.
*   **구조**: `[PersonSlot]`. 각 슬롯은 `id`와 `기준 FeaturePrint`를 가짐.
*   **동작**: 초기엔 빈 목록. 매칭 실패 시 조건(Quality)을 만족하면 새 슬롯 추가.

### 2.2. 성능 최적화: FP 1회 생성 (Optimization)
*   **개선**: **사진당 각 얼굴의 Feature Print는 최초 1회만 생성**하여 메모리에 캐싱하고, 슬롯 비교 시 재사용함. ($N$개의 얼굴에 대해 $N$번만 생성)

### 2.3. 하이브리드 비용 함수 (Advanced Cost Function)
단순 거리가 아닌, 위치 정보를 가중치로 활용하는 **비용(Cost)** 개념 도입.

$$ Cost = Dist_{fp} + (Penalty_{pos} 	imes 0.2) $$

*   **$Dist_{fp}$**: Feature Print 거리 (0.0 ~ 2.0). 가장 중요한 척도.
*   **$Penalty_{pos}$**: 위치 거리($Dist_{pos}$). 
    *   위치가 다르면($Dist_{pos} 
approx 1.0$) 비용이 0.2 증가 → 유사도 판단 기준이 엄격해짐.
    *   위치가 같으면($Dist_{pos} 
approx 0.0$) 비용 증가 없음 → FP 거리 그대로 인정.

### 2.4. 전역 최적 매칭 프로세스 (Step-by-Step)

1.  **준비 (Preparation)**:
    *   현재 사진의 모든 얼굴에 대해 Feature Print 생성 (병렬 처리).
    *   유효한 FP가 생성된 얼굴만 매칭 후보로 등록.

2.  **비용 산출 (Cost Calculation)**:
    *   `매칭 후보(N)` vs `활성 슬롯(M)`의 모든 조합에 대해 비용 계산.
    *   `candidates = [(Face, Slot, Cost)]` 리스트 생성.

3.  **전역 정렬 (Global Sorting)**:
    *   `candidates`를 **Cost 오름차순**으로 정렬. (가장 확실한 매칭부터 처리)

4.  **확정 및 점유 (Assignment)**:
    *   정렬된 리스트를 순회하며:
        *   Face나 Slot이 이미 사용되었으면 Skip.
        *   `Cost < 0.7 (Threshold)` 이면 매칭 확정 (`Face -> Slot`).
        *   사용된 Face와 Slot 마킹.

5.  **신규 등록 (New Person Registration)**:
    *   매칭되지 않은 Face 중:
        *   **Quality Gate**: 얼굴 크기나 선명도(Confidence)가 기준(0.8) 이상인 경우.
        *   새로운 `PersonSlot` 생성 및 `ActiveSlots`에 추가.

---

## 3. 예외 상황 처리 (Edge Cases)

### 3.1. 얼굴 품질 게이트 (Face Quality Gate)
*   **목적**: 흐릿하거나 너무 작은 얼굴이 '기준(Reference)'이 되는 것을 방지.
*   **규칙**: `confidence > 0.8` AND `boundingBox area > minSize` 일 때만 신규 슬롯 생성. 기준 미달 얼굴은 매칭 실패 시 그냥 버림(Unassigned).

### 3.2. 중복 매칭 방지 (Ghost Face)
*   **목적**: 배경 오인 등으로 인한 일회성 슬롯 생성 방지.
*   **규칙**: 최종 그룹 형성 시 `SimilarityConstants.minPhotosPerSlot` (최소 2장 이상 등장) 조건을 만족하는 슬롯만 유효한 인물로 인정.

---

## 4. 파라미터 튜닝 가이드

| 항목 | 제안값 | 설명 |
|---|---|---|
| **Match Threshold** | **0.7** | iOS 17+ 기준. 오탐지를 줄이기 위해 더 엄격하게 설정(0.8 -> 0.7). |
| **Position Weight** | **0.2** | 위치 차이가 최대일 때 FP 거리 페널티 최대 0.2 부여. |
| **Min Quality** | **0.8** | 신규 슬롯 생성 시 필요한 최소 Confidence. |

---

## 5. 결론
이 설계는 **전역 최적화 알고리즘**을 통해 매칭 정확도를 극대화하고, **FP 1회 생성**으로 성능 저하를 방지하며, **품질 게이트**로 데이터의 질을 관리하는 완성형 로직입니다.

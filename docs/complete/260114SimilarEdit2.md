# 얼굴 매칭 로직 심층 분석 및 개선 설계 (Ultimate v6)

## 1. 개요 및 목적 (Introduction)

본 문서는 `assignPersonIndicesForGroup` 로직의 구조적 결함과 데이터 변별력 문제를 해결하기 위한 최종 기술 명세서입니다. 상위 문서인 `prd9algorithm.md`의 §4 섹션을 대체합니다.

---

## 2. 핵심 문제점 분석 (Why)

### 2.1. 구조적 결함
- **위치 기반 선행 필터링**: 위치가 다르면 특징 비교를 차단하여 매칭 실패 유발.
- **정적 기준 슬롯**: 첫 사진 이후 등장하는 인물 인식 불가.
- **선착순 탐욕 매칭**: 최적의 짝이 아닌 순서에 의한 매칭으로 오류 발생.

### 2.2. 데이터 변별력 한계
- 실제 데이터(iOS 17+)에서 동일인($0.56 \sim 0.58$)과 타인($0.59 \sim 0.67$)의 FP 거리 차이가 미세함.
- 단순 임계값만으로는 변별이 불가능하여 **Grey Zone 전략**이 필수적임.

---

## 3. 개선 알고리즘: 전역 후보 정렬 기반 그리디 매칭

### 3.1. 동적 인물 풀 (Dynamic Person Pool)
- **부팅(Bootstrapping)**: `ActiveSlots`가 비어있는 첫 사진 처리 시, **Quality Gate**를 통과한 모든 얼굴을 즉시 신규 슬롯으로 등록.
- **상한 제한**: `maxPersonSlots` (10개) 초과 시 신규 생성을 중단하여 시스템 부하 방지.
- **기준 FP 정책**: **최초 등록된 FP 유지 (Keep First)**. 슬롯의 기준값이 변하면(Drift) 일관성이 깨질 위험이 있으므로, 처음 등록된 가장 선명한 모습을 기준으로 삼음.

### 3.2. 하이브리드 비용 함수 (Cost Function)
**Cost = Dist_fp + (Dist_pos * 0.2)**

- **Dist_fp**: Feature Print 거리 (iOS 17+: 0.0 ~ 2.0).
- **Dist_pos**: 정규화 좌표계(0~1) 내 중심점 간의 유클리드 거리.
- **Weight(0.2)**: 위치가 멀어질 때 부여하는 페널티.

### 3.3. 매칭 구간 세분화 (Grey Zone 전략)
1. **확신 구간 (Cost < 0.58)**: 즉시 매칭 확정.
2. **모호 구간 (0.58 <= Cost < 0.65)**: `Dist_pos < 0.1` (위치 매우 근접)일 때만 매칭 허용.
3. **거절 구간 (Cost >= 0.65)**: 매칭 실패.

---

## 4. 상세 실행 흐름 (Execution Flow)

다음 5단계를 순차적으로 수행합니다.

1.  **준비 (Preparation)**:
    - 현재 사진의 모든 얼굴 FP를 병렬로 1회 생성.
    - FP 생성 실패 시: 매칭 불가(`Unknown`) 처리.

2.  **비용 산출 (Cost Calculation)**:
    - `(얼굴 N) x (슬롯 M)` 모든 조합의 비용 계산.
    - `maxPersonSlots=10`이므로 Top-K 최적화 없이 **전수 비교** 수행 (충분히 빠름).

3.  **전역 정렬 (Global Sorting)**:
    - 모든 후보를 **Cost 오름차순(낮은 순)**으로 정렬.

4.  **확정 (Assignment)**:
    - 정렬된 리스트를 순회하며 **3.3항(Grey Zone)** 기준에 따라 매칭 확정.
    - 이미 매칭된 얼굴이나 슬롯은 건너뜀.

5.  **신규/실패 처리**:
    - **신규 등록**: 미매칭 얼굴 중 **Quality Gate** 통과 시 새 슬롯 생성.
    - **매칭 실패**: 신규 등록도 못한 얼굴은 `CachedFace`로 저장하되 `personIndex: -1`로 설정하고 UI 렌더링 시 필터링함.

---

## 5. 예외 상황 처리 및 기준

### 5.1. 얼굴 품질 게이트 (Face Quality Gate)
저품질 얼굴이 슬롯의 기준(Reference)이 되는 것을 방지합니다. (부팅 및 신규 등록 시 공통 적용)
- **Confidence**: `VNFaceObservation.confidence` > `SimilarityConstants.minFaceQuality` (0.8)
- **Size**: `boundingBox` 면적 > `SimilarityConstants.minFaceAreaRatio` (0.005)

### 5.2. 구현 체크리스트 (Checklist)
- [ ] **버전별 스케일**: iOS 16/17 분기 처리 확인.
- [ ] **메인 액터 격리**: `FaceCropper` nonisolated 처리.
- [ ] **Thread-Safe Resumer**: `SimilarityImageLoader` 중복 resume 방지.
- [ ] **로그 출력**: Grey Zone 판정 로그 구현.

---

## 6. 파라미터 제안값 (SimilarityConstants)

| 항목 | 값 (iOS 17+) | 설명 |
|---|---|---|
| **personMatchThreshold** | **0.65** | 최종 상한선 |
| **greyZoneThreshold** | **0.58** | 위치 조건 필수 시작점 |
| **positionPenaltyWeight** | **0.2** | 위치 가중치 |
| **minFaceQuality** | **0.8** | 신규 등록 신뢰도 |
| **maxPersonSlots** | **10** | 인물 수 상한 |

---

## 7. 결론
이 설계는 **전역 후보 정렬**을 통해 매칭 순서 문제를 해결하고, **Grey Zone 전략**으로 데이터 변별력을 보완하며, **품질 게이트와 안전장치**를 통해 모바일 환경에서의 안정성을 보장합니다.
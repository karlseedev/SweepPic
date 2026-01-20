# Similar Photo Face Matching - Current Summary

## 1. 증상(Observed Symptoms)

1) 같은 사람 분리(under-merge)
- 실제 동일인: a1, a2, c1, c2, c3, c4
- 현재는 personIndex 1과 3으로 분리됨

2) 다른 사람 합침(over-merge)
- a3가 personIndex 1로 들어감(실제는 그룹 2)
- b5가 personIndex 2로 들어감(실제는 그룹 3)

3) 얼굴 미검출
- 얼굴이 있는데 감지되지 않아 매칭/슬롯에서 누락되는 케이스 존재

## 2. 문제 정의(What must be fixed)

- 분리(같은 사람을 여러 슬롯으로 나눔)를 줄이면서
- 합침(다른 사람을 같은 슬롯으로 묶음)을 줄이고
- 미검출로 인한 누락을 최소화해야 함

## 3. 파이프라인 구조(현재 기준)

1) 얼굴 감지 (YuNet)
2) 랜드마크 → 정렬 (FaceAligner)
3) 임베딩 추출 (SFace)
4) 매칭/슬롯 할당 (Grey Zone + 저품질 경로)

※ YuNet 실패 시 Vision fallback은 현재 없음.

## 4. 케이스 정답(샘플, 사용자 제공 기준)

본 케이스는 샘플이며, 다른 그룹에도 동일한 유형(분리/합침/미검출)이 발생함.

- 그룹 1: a1, a2, c1, c2, c3, c4
- 그룹 2: b1, b2, b3, b4, b6, b7, a3
- 그룹 3: b5

## 5. 단계별 근본 원인(Why)

### 5.1 감지 단계 (S3 중심)
- YuNet은 작은 얼굴(5~7%)에서 누락이 발생함 (Vision-only로 확인됨).
- YuNet scoreThreshold=0.6, topK=5, 입력 320x320은 작은 얼굴에 불리함.
- 분석 이미지 자체가 480px로 제한되어 작은 얼굴이 더 작아짐.

### 5.2 랜드마크/정렬 단계 (S1/S2 간접 원인)
- 랜드마크 오차가 정렬 품질을 떨어뜨리고 임베딩 품질 저하로 이어짐.
- 정렬 실패/품질 저하는 norm 저하 및 동일인 cost 상승을 유발함.

### 5.3 임베딩 단계 (S1/S2 직접 원인)
- 측면/가림/조명 변화 시 동일인 cost가 급증하는 경향이 관찰됨.
- 동일인/타인 cost 분포 간 마진이 좁아 경계 구간이 많아짐.

## 6. 코드 기반 원인(How)

### 6.1 분리(under-merge) 원인

A. cost 하드 컷오프
- cost >= rejectThreshold이면 매칭이 즉시 거절됨
- 이후 신규 슬롯 생성으로 이어져 분리 발생
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift

B. 슬롯 위치 고정
- PersonSlot.center/boundingBox가 생성 시점 고정
- KeepBest는 임베딩만 갱신하고 위치는 갱신하지 않음
- 위치 변화가 있으면 Grey Zone에서 거절될 가능성 증가
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift

C. 후보 풀 편향
- 후보를 cost 기준 Top-K로 제한
- 실제로 가까운 슬롯이 후보에 포함되지 않으면 매칭 실패
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift

### 6.2 합침(over-merge) 원인

A. 저품질 경로 과완화
- lowQuality 경로는 posNorm <= 0.25 + cost < (rejectThreshold + 0.15)만 통과해도 매칭
- 위치만 가까우면 다른 사람도 합쳐질 위험이 큼
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift

B. 저품질 신규 슬롯 금지
- norm < 7이면 신규 슬롯 생성 금지
- 잘못된 슬롯으로 들어가거나 버려지면서 오탐/누락을 유발
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift

### 6.3 얼굴 미검출 원인

A. YuNet 실패 시 Vision 대체 없음
- YuNet 감지 실패 시 result[assetID] = []로 종료
- Vision rawFacesMap 결과를 사용하지 않음
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/SimilarityAnalysisQueue.swift

B. YuNet 필터링/입력 제한
- scoreThreshold=0.6, topK=5, 320x320 입력
- 전체 분석 이미지가 max 480px로 제한됨
- 작은 얼굴은 감지에서 제거될 가능성 높음
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Analysis/YuNet/YuNetTypes.swift
- 관련: PickPhoto/PickPhoto/Features/SimilarPhoto/Models/SimilarityConstants.swift

## 7. 테스트 결과 요약(현재까지)

- YuNet vs Vision 감지 비교: 정상 그룹에서 94.7%~100% 일치
- YuNet-only FP는 score 0.63~0.64 수준에서 발생
- Vision-only 누락 사례는 작은 얼굴(5~7%)에서 반복적으로 확인됨

## 8. 원인 검증이 필요한 이유

현재 원인은 코드 구조상 발생 가능한 이유를 정리한 것입니다.
실제 로그로 다음을 검증해야 원인을 확정할 수 있습니다.

### 8.1 후보 풀 편향 검증
- pos 기준 가장 가까운 슬롯이 cost Top-K 후보에 있었는지 확인

### 8.2 슬롯 위치 고정 검증
- 매칭 성공 시 slot.center와 face.center 차이를 누적 출력

### 8.3 저품질 매칭 과완화 검증
- LowQMatch 로그에서 posNorm/cost 분포 기록
- 오탐 케이스에서 cost가 얼마나 높은지 확인

### 8.4 미검출 원인 검증
- YuNet 결과가 0일 때 Vision 감지 개수 병행 출력

## 9. 다음 단계 후보(검증 이후 확정)

- 후보 풀에 pos 기준 후보를 강제로 추가
- 매칭 성공 시 slot 위치(센터/박스) EMA 갱신
- lowQuality 규칙 강화 또는 보류 슬롯 적용
- YuNet 실패 시 Vision fallback 추가

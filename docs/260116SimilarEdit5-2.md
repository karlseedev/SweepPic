# Similar Photo Face Matching - 통합 분석 문서

**문서 버전:** 2026-01-16
**기준:** 261116SimilarEdit5-1.md + 테스트 결과

---

## 1. 증상 (Observed Symptoms)

| # | 증상 | 설명 | 심각도 |
|---|------|------|--------|
| S1 | 같은 사람 분리 (under-merge) | 동일인이 여러 슬롯으로 나뉨 | High |
| S2 | 다른 사람 합침 (over-merge) | 타인이 같은 슬롯에 들어감 | High |
| S3 | 얼굴 미검출 | 얼굴이 있는데 감지 안됨 | Medium |

**샘플 케이스 (사용자 제공):**
- 그룹 1: a1, a2, c1, c2, c3, c4 → 현재 personIndex 1과 3으로 **분리됨**
- 그룹 2: b1, b2, b3, b4, b6, b7, a3 → a3가 personIndex 1로 **합쳐짐**
- 그룹 3: b5 → personIndex 2로 **합쳐짐**

---

## 2. 현행 코드 구조 (2026-01-16 기준)

**파이프라인:**
```
사진 → YuNet 감지 → 랜드마크(5-point) → FaceAligner 정렬 → SFace 임베딩 → 슬롯 매칭 → CachedFace
         ↓
    (실패 시 종료, Vision rawFacesMap 미사용)
```

**핵심 파일:**
| 파일 | 역할 |
|------|------|
| `SimilarityAnalysisQueue.swift` | 전체 파이프라인, 슬롯 매칭 |
| `YuNetFaceDetector.swift` | 얼굴 감지 + 랜드마크 |
| `FaceAligner.swift` | 112×112 정렬 |
| `SFaceRecognizer.swift` | 128차원 임베딩 |
| `SimilarityConstants.swift` | 임계값 상수 |

**현행 상수:**
| 상수 | 값 | 용도 |
|------|-----|------|
| `greyZoneThreshold` | 0.45 | 확신/모호 구간 경계 |
| `personMatchThreshold` | 0.637 | 거절 임계값 (LFW 기준) |
| `greyZonePositionLimit` | 0.20 | Grey Zone 위치 조건 |
| `lowQualityPosLimit` | 0.25 | 저품질 위치 조건 |
| `lowQualityCostLimit` | 0.787 | 저품질 cost 상한 *(계산값: min(rejectThreshold+0.15, 1.0))* |
| `scoreThreshold` (YuNet) | 0.6 | 얼굴 감지 신뢰도 |
| `analysisImageMaxSize` | 480px | 분석 이미지 최대 크기 |

**매칭 구간:**
| 구간 | Cost 범위 | 조건 |
|------|-----------|------|
| 확신 | < 0.45 | 즉시 매칭 |
| 모호 (Grey) | 0.45 ~ 0.637 | posNorm < 0.20 시 매칭 |
| 거절 | ≥ 0.637 | 매칭 실패 |
| 저품질 | cost < 0.787 | posNorm ≤ 0.25 시 매칭 |

---

## 3. 단계별 근본 원인 (Why)

### 3.1 감지 단계 (S3 중심)

| 원인 | 설명 | 검증 상태 |
|------|------|----------|
| YuNet 작은 얼굴 미검출 | 5~7% 크기 얼굴 누락 | ✅ 테스트 확인 |
| YuNet 가장자리 FP | 경계 부근에서 score 0.63~0.64 FP | ✅ 테스트 확인 |
| YuNet 입력 제한 | 320×320, 분석 이미지 480px 제한 | 코드 확인 |
| Vision fallback 없음 | YuNet=0이면 그냥 종료 | 코드 확인 |

### 3.2 랜드마크/정렬 단계 (S1/S2 간접 원인)

| 원인 | 설명 | 검증 상태 |
|------|------|----------|
| 랜드마크 오차 | 측면/가림 시 5-point 부정확 | 테스트 필요 |
| 정렬 품질 저하 | norm 저하 → 저품질 경로 진입 | 테스트 필요 |

### 3.3 임베딩 단계 (S1/S2 직접 원인)

| 원인 | 설명 | 검증 상태 |
|------|------|----------|
| 측면 얼굴 cost 급증 | 고개 돌린 상태에서 cost=0.82 | ✅ 이전 테스트 확인 |
| 동일인/타인 마진 좁음 | 동일인 0.56~0.58 vs 타인 0.59~0.67 | ✅ 이전 테스트 확인 |

---

## 4. 코드 기반 원인 (How)

### 4.1 분리(under-merge) 원인

| # | 원인 | 설명 | 코드 위치 |
|---|------|------|----------|
| A | **cost 하드 컷오프** | cost ≥ 0.637이면 즉시 거절 → 신규 슬롯 생성 | SimilarityAnalysisQueue.swift |
| B | **후보 풀 편향** | 슬롯 > 5개 시 cost Top-3만 후보 → 위치상 가까운 슬롯 제외 가능 | SimilarityAnalysisQueue.swift |

~~C. 슬롯 위치 고정~~ → **해결됨** (updateSlotIfBetter에서 매칭마다 위치 갱신)

### 4.2 합침(over-merge) 원인

| # | 원인 | 설명 | 코드 위치 |
|---|------|------|----------|
| A | **저품질 경로 과완화** | posNorm ≤ 0.25 + cost < 0.787이면 매칭 → 다른 사람도 합쳐짐 | SimilarityAnalysisQueue.swift |
| B | **저품질 신규 슬롯 금지** | norm < 7이면 신규 생성 불가 → 버림 (캐시 미저장) | SimilarityAnalysisQueue.swift:865-867 |

### 4.3 얼굴 미검출 원인

| # | 원인 | 설명 | 코드 위치 |
|---|------|------|----------|
| A | **Vision fallback 없음** | YuNet 실패 시 `result[assetID] = []`로 종료 | SimilarityAnalysisQueue.swift:585-589 |
| B | **YuNet 입력 제한** | scoreThreshold=0.6, 320×320, 480px 제한 | YuNetTypes.swift, SimilarityConstants.swift |

---

## 5. 테스트 결과

### 5.1 YuNet vs Vision 감지 비교

| 테스트 | 사진 | Both | YuNet-only | Vision-only | 일치율 |
|--------|------|------|------------|-------------|--------|
| Test #1 (정상A) | 6장 | 18 | 1 (FP) | 0 | 94.7% |
| Test #2 (정상B) | 4장 | 16 | 0 | 0 | 100% |
| Test #3 (그룹C) | 6장 | 20 | 1 | 1 | 90.9% |
| Test #4 (그룹D) | 7장 | 17 | 0 | 3 | 85.0% |
| **합계** | **23장** | **71** | **2** | **4** | **92.2%** |

### 5.2 주요 발견

**YuNet-only (FP 가능성):**
| Photo | 위치 | Score | 실제 |
|-------|------|-------|------|
| 959EE2E1 | 가장자리 (x=0.04) | 0.64 | FP 확인 |
| 53290326 | 중앙 (x=0.52) | 0.63 | 확인 필요 |

**Vision-only (YuNet 미검출):**
| Photo | 크기 | 비고 |
|-------|------|------|
| A9CF9959 | 0.05×0.04 | 작은 얼굴 |
| 07F52250 | 0.06×0.05 | 작은 얼굴 |
| 31B008F3 | 0.06×0.05 | 작은 얼굴 |
| 45039110 | 0.07×0.05 | 작은 얼굴 |

**결론:** YuNet은 5~7% 크기 얼굴을 놓침, Vision이 더 민감

---

## 6. 원인 검증 계획

| 검증 항목 | 로그 내용 | 목적 |
|----------|----------|------|
| **후보 풀 편향** | pos 기준 가장 가까운 슬롯이 cost Top-K에 있는지 | 4.1.B 검증 |
| **저품질 매칭 분포** | LowQMatch에서 posNorm/cost 분포 | 4.2.A 검증 |
| **저품질 신규 금지** | norm < 7인 얼굴이 잘못된 슬롯에 들어가는지 | 4.2.B 검증 |
| **YuNet 실패 시 Vision** | YuNet=0일 때 Vision 감지 개수 | 4.3.A 검증 |

---

## 7. 해결 전략 후보

| 원인 | 해결 방안 | 우선순위 | 검증 결과 |
|------|----------|----------|-----------|
| 4.1.B 후보 풀 편향 | Top-K에 pos 기준 가장 가까운 슬롯 1개 추가 (PosCandidate) | ~~High~~ **Low** | ❌ 효용성 낮음 (아래 참조) |
| 4.2.A 저품질 과완화 | posNorm 0.25 → 0.15, cost 상한 낮춤 | High | - |
| 4.2.B 저품질 신규 금지 | norm 조건 완화 또는 보류 슬롯 도입 | Medium | - |
| 4.3.A Vision fallback | YuNet=0이면 rawFacesMap 사용 | High | ✅ Extended fallback 구현 완료 |
| 4.3.B YuNet 입력 | 분석 이미지 크기 증가 (480 → 640) | Medium | - |

### 7.1 PosCandidate 검증 결과 (4.1.B)

**구현 내용:** Top-K 후보 선정 시 cost 기준 Top-K에 위치 기준으로 가장 가까운 슬롯 1개를 추가

**테스트 결과:** 효용성 낮음 ❌

**이유:**
1. cost 기준 Top-K에 위치 가까운 슬롯이 대부분 이미 포함됨
2. 위치가 가까워도 다른 사람이면 cost가 높아서 어차피 매칭 안 됨
3. Basic vs +PosCandidate 비교 시 결과 차이 거의 없음

**결론:** 우선순위 Low로 하향, 필요 시 재검토

---

## 8. 변경 이력

| 일시 | 내용 |
|------|------|
| 2026-01-16 | 5-1.md + 5.md 통합, 슬롯 위치 고정 원인 제거 (해결됨), 테스트 결과 추가 |
| 2026-01-16 | PosCandidate 검증 결과 추가 (효용성 낮음), Extended fallback 구현 완료 표시 |
| 2026-01-17 | Extended Fallback 복구 (41445d4 → 롤백 → ffcfb1d 재구현) |

---

## 9. Extended Vision Fallback 복구 (2026-01-17)

### 9.1 배경

**롤백 히스토리:**
```
202382e  Vision fallback 위치 기반 매칭 구현 (Basic)
   ↓
41445d4  Extended fallback IoU 기반 + 작은 얼굴 조건으로 변경
   ↓
c87acce  결정성 보장 수정 → S2 발생
   ↓
6b594c2  41445d4로 롤백
   ↓
202382e  다시 202382e로 롤백 (Extended 코드 손실)
   ↓
ffcfb1d  Extended fallback 복구 (별도 파일로 분리)
```

**문제:** 결정성 수정 작업 중 S2 발생으로 202382e로 롤백하면서 Extended 코드가 손실됨

### 9.2 VisionFallbackMode

```swift
enum VisionFallbackMode {
    case off       // Fallback 없음 - YuNet 결과만 사용
    case basic     // YuNet=0일 때만 Vision 사용
    case extended  // YuNet이 놓친 작은 얼굴도 Vision으로 보완
}
```

| 모드 | 조건 | 동작 |
|------|------|------|
| `off` | - | Vision fallback 비활성화 |
| `basic` | YuNet = 0 | Vision rawFacesMap 위치 정보 사용 |
| `extended` | YuNet > 0 but Vision > YuNet | IoU 기반으로 누락된 작은 얼굴 추가 |

### 9.3 Extended 조건

```swift
// 상수
let iouThreshold: CGFloat = 0.3      // IoU 30% 이상이면 동일 얼굴
let smallFaceLimit: CGFloat = 0.07   // 작은 얼굴 기준 (7% 이하)

// 조건
- Vision 얼굴 중 YuNet과 IoU < 0.3 (겹침 없음)
- 작은 얼굴만 (width < 0.07)
- FP 방지를 위해 작은 얼굴만 보완
```

### 9.4 파일 구조

| 파일 | 역할 |
|------|------|
| `VisionFallbackMode.swift` | enum 정의 |
| `SimilarityAnalysisQueue+ExtendedFallback.swift` | IoU 계산, 누락 얼굴 찾기 헬퍼 |
| `SimilarityAnalysisQueue.swift` | 파라미터 변경, Extended 로직 호출 |

### 9.5 API

```swift
// Production (기본값 .basic)
assignPersonIndicesForGroup(
    rawFacesMap: rawFacesMap,
    assetIDs: assetIDs,
    photos: photos
    // visionFallbackMode: .basic (기본값)
)

// Basic vs Extended 비교 테스트
let (basic, extended) = await testVisionFallbackExtended(
    photos: photos,
    rawFacesMap: rawFacesMap
)
```

### 9.6 로그 출력

```
[VisionFallback] Photo 07F52250: YuNet=0, Vision=3 faces
[ExtendedFallback] Photo 07F52250: YuNet=2, Vision=3, SmallMissed=1
[ExtendedFallback] +Vision[2] size=0.06 at (0.47, 0.57)
[FaceMatching] Photo 07F52250: 3 faces (YuNet+Vision), Embed: 2/3, Slots: 3
```

### 9.7 다음 단계

| 항목 | 상태 |
|------|------|
| Extended 코드 복구 | ✅ 완료 (ffcfb1d) |
| 하늘색 테스트 버튼 복원 | 필요 시 |
| Extended Production 적용 | 테스트 후 결정 |

# Research: 유사 사진 정리 기능

**Date**: 2026-01-02
**Branch**: `002-similar-photo`
**Status**: Complete

---

## 1. Vision Framework 이미지 유사도 분석

### Decision
`VNGenerateImageFeaturePrintRequest`를 사용하여 이미지 간 유사도를 측정

### Rationale
- Apple 공식 Vision Framework로 iOS에 최적화
- 별도 ML 모델 로딩 없이 시스템 리소스 활용
- `computeDistance(_:to:)` 메서드로 두 이미지 간 거리 계산 가능
- WWDC 2019/2021에서 검증된 기술

### Alternatives Considered
| 대안 | 장점 | 단점 | 탈락 이유 |
|------|------|------|----------|
| pHash (Perceptual Hash) | 매우 빠름 | 연속 촬영 사진 구분 어려움 | 유사도 정밀도 부족 |
| Core ML 커스텀 모델 | 높은 정확도 | 모델 크기, 메모리 사용량 | 복잡도 증가, 유지보수 부담 |
| 서버 기반 분석 | 강력한 처리 능력 | 네트워크 필요, 프라이버시 | 오프라인 지원 불가 |

### Key Implementation Details
- 분석 이미지 해상도: **긴 변 480px 이하**
- `PHImageManager.contentMode = .aspectFit` (패딩/크롭 금지)
- 유사도 임계값: **거리 10.0 이하**

---

## 2. Vision Framework 얼굴 감지

### Decision
`VNDetectFaceRectanglesRequest`를 사용하여 얼굴 위치 감지

### Rationale
- Vision Framework 통일로 API 일관성 유지
- `boundingBox` 반환으로 얼굴 위치 정보 제공
- 실시간 처리에 충분한 성능 (30ms 이하)

### Alternatives Considered
| 대안 | 장점 | 단점 | 탈락 이유 |
|------|------|------|----------|
| VNDetectFaceLandmarksRequest | 76개 특징점 제공 | 처리 시간 증가 | MVP에서 불필요한 복잡도 |
| Core ML Face Detection | 커스텀 학습 가능 | 별도 모델 필요 | 기본 제공 API로 충분 |
| AVFoundation | 실시간 카메라 최적화 | 정적 이미지에 부적합 | 사용 케이스 불일치 |

### Key Implementation Details
- 좌표계: Vision 정규화 좌표 (0~1, 원점 좌하단)
- Y축 반전 필요: `UIKit 좌표 = (1 - boundingBox.maxY)`
- 유효 얼굴 기준: 화면 너비의 **5% 이상**

---

## 3. 인물 매칭 알고리즘

### Decision
하이브리드 방식: 1차 위치 기반 + 2차 Feature Print 검증

### Rationale
- 연속 촬영 사진은 구도가 거의 동일 → 위치 기반 매칭 ~90% 정확도
- Feature Print 검증으로 불일치 사진은 비교 그리드에서 자동 제외 (spec FR-030)
- 빠른 초기 표시 + 백그라운드 검증으로 UX 최적화

### Alternatives Considered
| 대안 | 장점 | 단점 | 탈락 이유 |
|------|------|------|----------|
| 위치 기반만 | 매우 빠름 | 위치 변경 시 오류 | 정확도 부족 |
| Feature Print만 | 높은 정확도 | 초기 표시 지연 | UX 저하 |
| Face ID/Recognition | 정확한 인물 식별 | iOS 미제공 | 사용 불가 |

### Key Implementation Details
- 위치 정렬: X좌표 오름차순, X 동일 시 Y 내림차순
- 제외 임계값: 얼굴 크롭 Feature Print 거리 **1.0 이상**이면 다른 인물로 판정하여 비교 그리드에서 제외
- 인물 번호: 좌→우, 위→아래 순서

---

## 4. 캐시 설계

### Decision
`SimilarityCache` 클래스로 분석 결과 메모리 캐싱, LRU Eviction

### Rationale
- 뷰어에서 그리드 분석 결과 재사용 (재분석 방지)
- 메모리 제한으로 무한 증가 방지
- 상태 기반 관리로 분석 중복 방지

### Key Implementation Details
- 캐시 크기: **최대 500장**
- LRU Eviction: 오래된 항목부터 제거
- 상태 모델: `notAnalyzed` → `analyzing` → `analyzed`
- 저장 항목: CachedFace 배열, 그룹 멤버, 유효 인물 슬롯

---

## 5. 테두리 애니메이션

### Decision
`CAShapeLayer` + `CAKeyframeAnimation`으로 빛이 도는 테두리 구현

### Rationale
- Core Animation으로 GPU 가속
- `strokeStart/strokeEnd` 애니메이션으로 빛 이동 효과
- 메인 스레드 블로킹 없음

### Key Implementation Details
- 레이어: `CAShapeLayer`로 사각형 path 생성
- 애니메이션: 시계방향 회전, 빛 색상 흰색 그라데이션
- 최적화: `didEndDisplaying` 시 애니메이션 제거

---

## 6. 얼굴 크롭 규칙

### Decision
bounding box + 30% 여백 + 정사각형 조정

### Rationale
- 30% 여백으로 얼굴 주변 맥락 포함
- 정사각형으로 2열 그리드 표시 최적화
- 경계 처리로 이미지 밖 크롭 방지

### Key Implementation Details
- 여백: bounding box 너비/높이 각각 **30% 추가**
- 비율: **1:1 정사각형**
- 경계 처리: 중심 고정, 경계 내 최대 크기로 축소

---

## 7. 분석 타이밍 및 동시성

### Decision
스크롤 멈춤 후 0.3초 디바운싱, 최대 5개 동시 분석

### Rationale
- 디바운싱으로 불필요한 분석 방지
- 동시성 제한으로 메모리/CPU 관리
- 스크롤 성능 유지

### Key Implementation Details
- 디바운싱: **0.3초**
- 동시 분석: **최대 5개**
- 취소 규칙: 스크롤 재개 시 `source=grid` 작업만 취소, `source=viewer`는 유지

---

## 8. iOS 버전별 UI 분기

### Decision
iOS 16~25: 커스텀 FloatingUI, iOS 26+: 시스템 네비바/툴바 (Liquid Glass)

### Rationale
- iOS 26+ Liquid Glass 자동 적용으로 시스템 일관성
- 기존 iOS 버전은 커스텀 UI로 동일한 경험 제공

### Key Implementation Details
```swift
if #available(iOS 26.0, *) {
    // 시스템 네비바/툴바 사용
} else {
    // 커스텀 FloatingTitleBar/TabBar 사용
}
```

---

## 9. 접근성 고려사항

### Decision
VoiceOver 활성화 시 기능 전체 비활성화

### Rationale
- 얼굴 표정/눈 감김 비교는 시각 기반 기능
- 시각장애인에게 실질적 사용 가치 없음
- 모션 감소 설정 시 정적 테두리로 대체

### Key Implementation Details
- VoiceOver: `UIAccessibility.isVoiceOverRunning` 체크
- 모션 감소: `UIAccessibility.isReduceMotionEnabled` 체크

---

## 10. 유사 사진 그룹 형성 알고리즘 ⭐ 핵심

> **중요**: 이 섹션은 전체 기능의 핵심 알고리즘을 정의합니다. Phase 2 (T014) 구현 전에 반드시 숙지해야 합니다.

### 10.1 Problem Statement (문제 정의)

**입력**:
- 분석 범위 내 N장의 사진 (시간순 정렬)
- 각 사진의 Feature Print (VNFeaturePrintObservation)

**출력**:
- 0개 이상의 유사사진썸네일그룹
- 각 그룹은 유사한 사진들의 집합
- 각 사진의 분석 상태 (analyzed, inGroup 여부)

**목표**:
- 연속 촬영된 유사한 사진들을 하나의 그룹으로 묶기
- 유사하지 않은 사진은 별도 그룹 또는 그룹 없음
- O(n) 복잡도로 효율적 처리

---

### 10.2 Decision (결정)

**인접 사진 순차 비교 방식 (Adjacent Comparison / Sliding Window)**

사진이 시간순 정렬되어 있다는 가정 하에, 인접한 사진끼리만 Feature Print 거리를 비교하여 그룹을 형성합니다.

```
photos:     [P1] ─── [P2] ─── [P3] ─── [P4] ─── [P5] ─── [P6] ─── [P7]
distances:       3.2      4.1      2.8      15.2     3.5      4.0
                  ✓        ✓        ✓        ✗        ✓        ✓
               (≤10.0)  (≤10.0)  (≤10.0)  (>10.0) (≤10.0)  (≤10.0)

groups:     [──── Group A ────]              [─── Group B ───]
                P1, P2, P3, P4                   P5, P6, P7
```

---

### 10.3 Rationale (선택 이유)

1. **시간적 연속성 가정**
   - 연속 촬영된 사진은 라이브러리에서 시간순으로 인접해 있음
   - "비슷한 사진"은 대부분 연속 촬영의 결과 (버스트 촬영, 단체 사진 여러 장 등)
   - 시간적으로 떨어진 유사 사진을 같은 그룹으로 묶을 필요 없음 (PRD 요구사항)

2. **효율성**
   - O(n) 복잡도: N장에 대해 N-1번의 비교만 수행
   - Pairwise 전체 비교 O(n²) 대비 획기적으로 효율적
   - 15장 분석 범위 기준: 14번 비교 vs 105번 비교

3. **구현 단순성**
   - 단일 for 루프로 구현 가능
   - 복잡한 클러스터링 알고리즘 불필요
   - 디버깅 및 유지보수 용이

4. **PRD 요구사항 부합**
   - "화면에 보이는 사진 기준 앞뒤 7장 범위" (prd9.md §2.1.1)
   - "연속 촬영된 유사한 사진" (prd9.md §1.1)

---

### 10.4 Alternatives Considered (대안 검토)

| 알고리즘 | 복잡도 | 장점 | 단점 | 탈락 이유 |
|----------|--------|------|------|----------|
| **인접 비교 (채택)** | O(n) | 단순, 빠름 | 비인접 유사 사진 미감지 | - |
| Pairwise 전체 비교 | O(n²) | 모든 유사 관계 탐지 | 계산량 급증 | 15장 → 105번 비교, 불필요 |
| Union-Find | O(n·α(n)) | 비인접 사진 그룹화 | 복잡도 증가 | PRD 요구사항 불일치 |
| K-means 클러스터링 | O(n·k·i) | 유연한 그룹화 | K값 결정 어려움 | 과도한 복잡도 |
| DBSCAN | O(n²) | 밀도 기반 클러스터 | 계산 비용 | 사용 케이스 불일치 |
| Hierarchical Clustering | O(n² log n) | 계층적 그룹화 | 매우 느림 | 실시간 분석 불가 |

**Pairwise 전체 비교가 필요하지 않은 이유**:
```
시나리오: [사진1] [사진2] [사진3] [풍경] [사진5] [사진6]
                      ↑                    ↑
                  연속 촬영 A           연속 촬영 B

- 사진1~3과 사진5~6은 시간적으로 떨어져 있음
- 설령 사진1과 사진5가 유사하더라도 (같은 장소 재방문 등)
- 사용자 입장에서 이들을 같은 "유사 사진 그룹"으로 보지 않음
- PRD: "연속 촬영된 사진" 대상
```

---

### 10.5 Algorithm Steps (상세 알고리즘 단계)

#### Phase 1: Feature Print 생성

```
INPUT: photos[0..n-1] (시간순 정렬된 사진 배열)
OUTPUT: featurePrints[0..n-1] (각 사진의 Feature Print)

FOR i = 0 TO n-1:
    image = loadImage(photos[i], maxSize: 480px, contentMode: aspectFit)
    featurePrints[i] = VNGenerateImageFeaturePrintRequest(image)
END FOR
```

**병렬 처리**:
- 최대 5개 동시 분석 (thermalState .serious/.critical 시 2개)
- DispatchQueue.global(qos: .userInitiated) 사용

#### Phase 2: 인접 거리 계산

```
INPUT: featurePrints[0..n-1]
OUTPUT: distances[0..n-2] (인접 사진 간 거리)

FOR i = 0 TO n-2:
    distances[i] = featurePrints[i].computeDistance(to: featurePrints[i+1])
END FOR
```

**복잡도**: O(n-1) = O(n)

#### Phase 3: 그룹 형성 (핵심)

```
INPUT: photos[0..n-1], distances[0..n-2], threshold = 10.0
OUTPUT: groups (유사사진썸네일그룹 배열)

CONSTANT THRESHOLD = 10.0
CONSTANT MIN_GROUP_SIZE = 3

groups = []
currentGroup = [photos[0]]

FOR i = 0 TO n-2:
    IF distances[i] <= THRESHOLD THEN
        // 유사함 → 현재 그룹에 추가
        currentGroup.append(photos[i+1])
    ELSE
        // 유사하지 않음 → 현재 그룹 종료, 새 그룹 시작
        IF currentGroup.count >= MIN_GROUP_SIZE THEN
            groups.append(currentGroup)
        END IF
        currentGroup = [photos[i+1]]
    END IF
END FOR

// 마지막 그룹 처리
IF currentGroup.count >= MIN_GROUP_SIZE THEN
    groups.append(currentGroup)
END IF

RETURN groups
```

**상태 전이 다이어그램**:
```
                    distance ≤ 10.0
                   ┌──────────────┐
                   │              │
                   ▼              │
            ┌─────────────┐      │
   START───▶│ IN_GROUP    │──────┘
            │ (collecting)│
            └─────────────┘
                   │
                   │ distance > 10.0
                   ▼
            ┌─────────────┐
            │ GROUP_END   │──┐
            │ (evaluate)  │  │
            └─────────────┘  │
                   │         │
                   │ count<3 │ count≥3
                   │         ▼
                   │    ┌─────────────┐
                   │    │ SAVE_GROUP  │
                   │    └─────────────┘
                   │         │
                   ▼         ▼
            ┌─────────────────────┐
            │   NEW_GROUP_START   │
            └─────────────────────┘
```

#### Phase 4: 얼굴 필터링 및 유효성 검증

```
INPUT: groups (Phase 3 결과)
OUTPUT: validGroups (유효한 그룹만 필터링)

FOR EACH group IN groups:
    // 4.1 각 사진에서 얼굴 감지
    FOR EACH photo IN group:
        faces = detectFaces(photo)
        eligibleFaces = faces.filter { faceWidth >= screenWidth * 0.05 }

        IF eligibleFaces.count > 5 THEN
            eligibleFaces = eligibleFaces.sortedBySize().prefix(5)
        END IF

        // 위치 기반 인물 번호 부여 (좌→우, 위→아래)
        assignPersonIndices(eligibleFaces)

        cache.setFaces(eligibleFaces, for: photo.id)
    END FOR

    // 4.2 인물 슬롯별 사진 수 집계
    slotCounts = [:] // personIndex → count
    FOR EACH photo IN group:
        FOR EACH face IN cache.getFaces(photo.id):
            slotCounts[face.personIndex] += 1
        END FOR
    END FOR

    // 4.3 유효 슬롯 판정 (2장 이상)
    validSlots = slotCounts.filter { $0.value >= 2 }.keys

    // 4.4 유효 얼굴이 있는 사진만 필터링
    validPhotos = group.filter { photo IN
        faces = cache.getFaces(photo.id)
        RETURN faces.any { validSlots.contains($0.personIndex) }
    }

    // 4.5 최종 유효성 검사
    IF validPhotos.count >= 3 AND validSlots.count >= 1 THEN
        // 그룹 유효 → 저장
        groupID = generateUUID()
        cache.setGroupMembers(validPhotos.map(\.id), for: groupID)
        cache.setGroupValidPersonIndices(validSlots, for: groupID)

        FOR EACH photo IN validPhotos:
            cache.setState(.analyzed(inGroup: true, groupID: groupID), for: photo.id)
            // CachedFace.isValidSlot 플래그 갱신
            updateIsValidSlotFlags(photo.id, validSlots)
        END FOR

        validGroups.append(groupID)
    ELSE
        // 그룹 무효 → 분석 완료 상태만 설정
        FOR EACH photo IN group:
            cache.setState(.analyzed(inGroup: false, groupID: nil), for: photo.id)
        END FOR
    END IF
END FOR

RETURN validGroups
```

---

### 10.6 Data Flow Diagram (데이터 흐름)

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         그리드 스크롤 멈춤                                │
│                              (trigger)                                  │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  1. 분석 범위 결정                                                       │
│     visibleRange = [N, M] (화면에 보이는 사진)                           │
│     analysisRange = [max(0, N-7), min(total-1, M+7)]                   │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  2. Feature Print 생성 (병렬, 최대 5개 동시)                             │
│                                                                          │
│     ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                   │
│     │ P[0] │  │ P[1] │  │ P[2] │  │ ...  │  │P[n-1]│                   │
│     └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘  └──┬───┘                   │
│        │         │         │         │         │                        │
│        ▼         ▼         ▼         ▼         ▼                        │
│     ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐  ┌──────┐                   │
│     │FP[0] │  │FP[1] │  │FP[2] │  │ ...  │  │FP[n-1]│                  │
│     └──────┘  └──────┘  └──────┘  └──────┘  └──────┘                   │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  3. 인접 거리 계산                                                       │
│                                                                          │
│     FP[0]──d[0]──FP[1]──d[1]──FP[2]──d[2]──...──d[n-2]──FP[n-1]        │
│            3.2         4.1         2.8              4.0                 │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  4. 그룹 분리 (threshold = 10.0)                                        │
│                                                                          │
│     d[i] ≤ 10.0 → 같은 그룹 유지                                         │
│     d[i] > 10.0 → 새 그룹 시작                                           │
│                                                                          │
│     예: [P0,P1,P2,P3] ─(15.2)─ [P4,P5,P6]                               │
│         ─────────────          ──────────                               │
│          Group A                Group B                                 │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  5. 얼굴 감지 + 5% 필터 + 인물 번호 부여                                  │
│                                                                          │
│     각 사진:                                                             │
│       faces = VNDetectFaceRectangles(photo)                             │
│       eligible = faces.filter(width ≥ screenWidth * 5%)                 │
│       top5 = eligible.sortBySize().prefix(5)                            │
│       assignPersonIndices(top5)  // 좌→우, 위→아래                       │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  6. 유효 슬롯 계산 + 최종 검증                                            │
│                                                                          │
│     Group A: 4 photos                                                    │
│       Person 1: 4장 ✓ (≥2)                                              │
│       Person 2: 3장 ✓ (≥2)                                              │
│       Person 3: 1장 ✗ (<2)                                              │
│                                                                          │
│     validSlots = {1, 2}                                                  │
│     validPhotos = 4 (≥3) ✓                                              │
│     → Group A 유효!                                                      │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  7. 캐시 저장 + 상태 업데이트                                             │
│                                                                          │
│     cache.groups[groupID] = [P0.id, P1.id, P2.id, P3.id]                │
│     cache.groupValidPersonIndices[groupID] = {1, 2}                     │
│     cache.assetFaces[P0.id] = [CachedFace(...), ...]                    │
│     cache.states[P0.id] = .analyzed(inGroup: true, groupID: groupID)    │
└─────────────────────────────────────────────────────────────────────────┘
                                   │
                                   ▼
┌─────────────────────────────────────────────────────────────────────────┐
│  8. UI 알림 (NotificationCenter)                                         │
│                                                                          │
│     post(.similarPhotoAnalysisComplete, userInfo: [                     │
│         "groupID": groupID,                                              │
│         "assetIDs": [P0.id, P1.id, P2.id, P3.id]                        │
│     ])                                                                   │
│                                                                          │
│     → GridViewController: 테두리 표시                                    │
│     → ViewerViewController: +버튼 표시 준비                              │
└─────────────────────────────────────────────────────────────────────────┘
```

---

### 10.7 Complexity Analysis (복잡도 분석)

#### 시간 복잡도

| 단계 | 복잡도 | 설명 |
|------|--------|------|
| Feature Print 생성 | O(n) | N장 각각 1회 |
| 인접 거리 계산 | O(n-1) | N-1번 비교 |
| 그룹 분리 | O(n) | 단일 패스 |
| 얼굴 감지 | O(n) | N장 각각 1회 |
| 유효 슬롯 계산 | O(n·f) | f = 평균 얼굴 수 (≤5) |
| **전체** | **O(n)** | 선형 복잡도 |

#### 공간 복잡도

| 항목 | 크기 | 설명 |
|------|------|------|
| Feature Prints | O(n) | 임시 저장, 분석 후 해제 가능 |
| Distances | O(n) | 임시 배열 |
| Groups | O(n) | 최악: 전체가 1그룹 |
| Cache (영구) | O(500) | LRU 제한 |
| **전체** | **O(n)** | 분석 중 / O(500) 캐시 |

#### 실제 성능 예측

```
분석 범위: 15장 (화면 7장 + 앞뒤 4장씩)
Feature Print 생성: 15 × 50ms = 750ms (병렬 시 ~200ms)
인접 거리 계산: 14 × 1ms = 14ms
그룹 분리: ~1ms
얼굴 감지: 15 × 30ms = 450ms (병렬 시 ~150ms)
유효 슬롯 계산: ~5ms

총 예상 시간: ~400ms (병렬 처리)
목표: 스크롤 멈춤 후 1초 이내 테두리 표시 ✓
```

---

### 10.8 Edge Cases (엣지 케이스 처리)

#### Case 1: 전체가 하나의 유사 그룹

```
INPUT:  [P1] ─3.0─ [P2] ─2.5─ [P3] ─4.0─ [P4] ─3.2─ [P5]
                 (모든 거리 ≤ 10.0)
OUTPUT: Group A = [P1, P2, P3, P4, P5]
```

#### Case 2: 모든 사진이 다름

```
INPUT:  [P1] ─15.0─ [P2] ─12.5─ [P3] ─18.0─ [P4]
                 (모든 거리 > 10.0)
OUTPUT: 유효 그룹 없음 (각 1장씩이므로 3장 미만)
```

#### Case 3: 경계값 처리 (거리 = 10.0)

```
INPUT:  [P1] ─10.0─ [P2] ─10.0─ [P3]
                 (거리 = threshold)
OUTPUT: Group A = [P1, P2, P3]  // ≤ 이므로 같은 그룹
```

#### Case 4: 2장짜리 그룹들

```
INPUT:  [P1] ─5.0─ [P2] ─15.0─ [P3] ─4.0─ [P4]
OUTPUT: 유효 그룹 없음
        - [P1, P2]: 2장 < 3장 (무효)
        - [P3, P4]: 2장 < 3장 (무효)
```

#### Case 5: 1장만 분석 범위

```
INPUT:  [P1]
OUTPUT: 유효 그룹 없음 (비교 대상 없음)
```

#### Case 6: 얼굴 없는 사진 포함

```
INPUT:  Group = [P1(얼굴3), P2(풍경), P3(얼굴2), P4(얼굴3)]

처리 과정:
  - P1: 얼굴 3개 → eligible
  - P2: 얼굴 0개 → excluded
  - P3: 얼굴 2개 → eligible
  - P4: 얼굴 3개 → eligible

  validPhotos = [P1, P3, P4] (3장 ≥ 3)
  슬롯 계산:
    - Person 1: P1, P3, P4 = 3장 ✓
    - Person 2: P1, P3, P4 = 3장 ✓
    - Person 3: P1, P4 = 2장 ✓

OUTPUT: Group = [P1, P3, P4], validSlots = {1, 2, 3}
```

#### Case 7: 얼굴은 있지만 유효 슬롯 없음

```
INPUT:  Group = [P1(얼굴:A,B), P2(얼굴:C,D), P3(얼굴:E,F)]
        (모든 사진에서 다른 얼굴이 다른 위치)

슬롯 계산:
  - Person 1: P1만 = 1장 ✗
  - Person 2: P2만 = 1장 ✗
  - ... 모든 슬롯 < 2장

OUTPUT: 그룹 무효 (유효 슬롯 0개)
```

#### Case 8: 범위 겹침 (연속 분석)

```
분석 1: 범위 [0-14], 그룹 A = [P10-P14]
분석 2: 범위 [10-24], P10-P14가 다시 분석됨

처리:
  1. prepareForReanalysis([P10-P14])
  2. 기존 그룹 A에서 P10-P14 제거
  3. 그룹 A 멤버 < 3 → 그룹 A 무효화
  4. 새 분석 결과로 그룹 재생성
```

---

### 10.9 Key Implementation Details (구현 상세)

#### 10.9.1 구현 위치

| 컴포넌트 | 파일 | 역할 |
|----------|------|------|
| SimilarityAnalysisQueue | `Analysis/SimilarityAnalysisQueue.swift` | 전체 파이프라인 오케스트레이션 |
| SimilarityAnalyzer | `Analysis/SimilarityAnalyzer.swift` | Feature Print 생성/비교 |
| SimilarityCache | `Analysis/SimilarityCache.swift` | 그룹/상태/얼굴 캐시 관리 |
| FaceDetector | `Analysis/FaceDetector.swift` | 얼굴 감지 |

#### 10.9.2 핵심 메서드

**SimilarityAnalysisQueue**:
```swift
/// 분석 범위에 대한 그룹 형성 (핵심 오케스트레이션)
func formGroupForRange(_ range: ClosedRange<Int>) async throws -> [String] {
    // 1. Feature Print 생성 (병렬)
    // 2. 인접 거리 계산
    // 3. 그룹 분리 (threshold 10.0)
    // 4. 얼굴 필터링 + 유효성 검증
    // 5. 캐시 저장
    // 6. 알림 발송
}

/// 인접 사진 간 거리로 그룹 분리
private func splitIntoGroups(
    photos: [PHAsset],
    distances: [Float],
    threshold: Float = 10.0
) -> [[PHAsset]] {
    // 핵심 알고리즘 구현
}
```

**SimilarityAnalyzer**:
```swift
/// Feature Print 생성
func generateFeaturePrint(for image: CGImage) throws -> VNFeaturePrintObservation

/// 두 Feature Print 간 거리 계산
func computeDistance(_ fp1: VNFeaturePrintObservation,
                     _ fp2: VNFeaturePrintObservation) throws -> Float
```

#### 10.9.3 상수 정의

```swift
enum SimilarityConstants {
    /// Feature Print 거리 임계값 (이하면 유사)
    static let similarityThreshold: Float = 10.0

    /// 최소 그룹 크기
    static let minGroupSize: Int = 3

    /// 최소 유효 슬롯 (인물당 사진 수)
    static let minPhotosPerSlot: Int = 2

    /// 최소 유효 슬롯 개수
    static let minValidSlots: Int = 1

    /// 분석 범위 확장 (앞뒤 각각)
    static let analysisRangeExtension: Int = 7

    /// 분석 이미지 최대 크기 (긴 변)
    static let analysisImageMaxSize: CGFloat = 480

    /// 유효 얼굴 최소 비율 (화면 너비 대비)
    static let minFaceWidthRatio: CGFloat = 0.05

    /// 최대 얼굴 개수 (사진당)
    static let maxFacesPerPhoto: Int = 5
}
```

---

### 10.10 Swift Implementation (구현 코드)

#### 10.10.1 핵심 그룹 분리 알고리즘

```swift
/// 인접 사진 간 Feature Print 거리를 기준으로 그룹 분리
/// - Parameters:
///   - photos: 시간순 정렬된 사진 배열
///   - featurePrints: 각 사진의 Feature Print (photos와 동일 순서)
///   - threshold: 유사도 임계값 (기본 10.0)
/// - Returns: 분리된 그룹들 (각 그룹은 PHAsset 배열)
func splitIntoGroups(
    photos: [PHAsset],
    featurePrints: [VNFeaturePrintObservation],
    threshold: Float = SimilarityConstants.similarityThreshold
) throws -> [[PHAsset]] {

    // 입력 검증
    guard photos.count == featurePrints.count else {
        throw SimilarityError.mismatchedArrayLengths
    }

    guard photos.count >= 2 else {
        // 1장 이하면 비교 불가, 빈 결과 반환
        return []
    }

    var groups: [[PHAsset]] = []
    var currentGroup: [PHAsset] = [photos[0]]

    // 인접 사진 간 거리 계산 및 그룹 분리
    for i in 0..<(photos.count - 1) {
        var distance: Float = 0
        try featurePrints[i].computeDistance(&distance, to: featurePrints[i + 1])

        if distance <= threshold {
            // 유사함 → 현재 그룹에 추가
            currentGroup.append(photos[i + 1])
        } else {
            // 유사하지 않음 → 현재 그룹 저장 (3장 이상일 때만), 새 그룹 시작
            if currentGroup.count >= SimilarityConstants.minGroupSize {
                groups.append(currentGroup)
            }
            currentGroup = [photos[i + 1]]
        }
    }

    // 마지막 그룹 처리
    if currentGroup.count >= SimilarityConstants.minGroupSize {
        groups.append(currentGroup)
    }

    return groups
}
```

#### 10.10.2 전체 파이프라인 구현

```swift
/// 분석 범위에 대한 완전한 그룹 형성 파이프라인
/// - Parameter range: 분석할 사진 인덱스 범위
/// - Returns: 생성된 유효 그룹 ID 배열
func formGroupsForRange(_ range: ClosedRange<Int>) async throws -> [String] {

    // 0. 분석 범위 내 사진 가져오기
    let photos = fetchPhotos(in: range)
    guard photos.count >= SimilarityConstants.minGroupSize else {
        return []
    }

    // 1. 기존 그룹 정리 (재분석 시)
    let assetIDs = Set(photos.map { $0.localIdentifier })
    cache.prepareForReanalysis(assetIDs: assetIDs)

    // 2. Feature Print 생성 (병렬)
    let featurePrints = try await withThrowingTaskGroup(of: (Int, VNFeaturePrintObservation).self) { group in
        for (index, photo) in photos.enumerated() {
            group.addTask {
                let image = try await self.imageLoader.loadImage(for: photo)
                let fp = try self.analyzer.generateFeaturePrint(for: image)
                return (index, fp)
            }
        }

        var results = [VNFeaturePrintObservation?](repeating: nil, count: photos.count)
        for try await (index, fp) in group {
            results[index] = fp
        }
        return results.compactMap { $0 }
    }

    // 3. 그룹 분리 (인접 비교)
    let rawGroups = try splitIntoGroups(
        photos: photos,
        featurePrints: featurePrints,
        threshold: SimilarityConstants.similarityThreshold
    )

    // 4. 얼굴 필터링 + 유효성 검증
    let viewerSize = getExpectedViewerSize()
    var validGroupIDs: [String] = []

    for rawGroup in rawGroups {
        // 4.1 각 사진에서 얼굴 감지 + 캐싱
        var photoFacesMap: [String: [CachedFace]] = [:]

        for photo in rawGroup {
            let faces = try await faceDetector.detectFaces(in: photo)

            // 5% 필터 + 상위 5개 + 인물 번호 부여
            let eligibleFaces = faces
                .filter { isEligibleFace(boundingBox: $0.boundingBox, viewerSize: viewerSize) }
                .sorted { $0.boundingBox.width * $0.boundingBox.height >
                          $1.boundingBox.width * $1.boundingBox.height }
                .prefix(SimilarityConstants.maxFacesPerPhoto)

            let cachedFaces = assignPersonIndices(faces: Array(eligibleFaces))
            photoFacesMap[photo.localIdentifier] = cachedFaces
        }

        // 4.2 유효 슬롯 계산
        var slotCounts: [Int: Int] = [:]
        for (_, faces) in photoFacesMap {
            for face in faces {
                slotCounts[face.personIndex, default: 0] += 1
            }
        }

        let validSlots = Set(slotCounts.filter {
            $0.value >= SimilarityConstants.minPhotosPerSlot
        }.keys)

        // 4.3 유효 사진 필터링 (유효 슬롯 얼굴이 있는 사진만)
        let validPhotos = rawGroup.filter { photo in
            let faces = photoFacesMap[photo.localIdentifier] ?? []
            return faces.contains { validSlots.contains($0.personIndex) }
        }

        // 4.4 최종 유효성 검사
        if validPhotos.count >= SimilarityConstants.minGroupSize &&
           validSlots.count >= SimilarityConstants.minValidSlots {

            // 그룹 유효 → 캐시 저장
            let groupID = UUID().uuidString
            let memberIDs = validPhotos.map { $0.localIdentifier }

            cache.setGroupMembers(memberIDs, for: groupID)
            cache.setGroupValidPersonIndices(validSlots, for: groupID)

            for photo in validPhotos {
                // CachedFace 저장 (isValidSlot 플래그 갱신)
                let updatedFaces = (photoFacesMap[photo.localIdentifier] ?? []).map { face in
                    CachedFace(
                        boundingBox: face.boundingBox,
                        personIndex: face.personIndex,
                        isValidSlot: validSlots.contains(face.personIndex)
                    )
                }
                cache.setFaces(updatedFaces, for: photo.localIdentifier)
                cache.setState(.analyzed(inGroup: true, groupID: groupID), for: photo.localIdentifier)
            }

            validGroupIDs.append(groupID)
        }

        // 탈락한 사진들 상태 업데이트
        let validPhotoIDs = Set(validPhotos.map { $0.localIdentifier })
        for photo in rawGroup where !validPhotoIDs.contains(photo.localIdentifier) {
            cache.setState(.analyzed(inGroup: false, groupID: nil), for: photo.localIdentifier)
        }
    }

    // 5. LRU Eviction 체크
    cache.evictIfNeeded()

    // 6. 알림 발송
    for groupID in validGroupIDs {
        NotificationCenter.default.post(
            name: .similarPhotoAnalysisComplete,
            object: nil,
            userInfo: [
                "groupID": groupID,
                "assetIDs": cache.getGroupMembers(groupID: groupID)
            ]
        )
    }

    return validGroupIDs
}
```

#### 10.10.3 인물 번호 부여 함수

```swift
/// 위치 기반 인물 번호 부여 (좌→우, 위→아래)
/// - Parameter faces: 감지된 얼굴 배열
/// - Returns: personIndex가 부여된 CachedFace 배열
func assignPersonIndices(faces: [DetectedFace]) -> [CachedFace] {
    // Vision 좌표: 원점 좌하단, Y축 위로 증가
    // 정렬: X 오름차순 (좌→우), X 동일 시 Y 내림차순 (위→아래)
    let sorted = faces.sorted { face1, face2 in
        let xDiff = abs(face1.boundingBox.origin.x - face2.boundingBox.origin.x)

        if xDiff > 0.05 {
            // X 좌표가 충분히 다름 → X 기준 정렬
            return face1.boundingBox.origin.x < face2.boundingBox.origin.x
        } else {
            // X 좌표가 비슷함 → Y 기준 정렬 (위가 먼저 = Y 큰 게 먼저)
            return face1.boundingBox.origin.y > face2.boundingBox.origin.y
        }
    }

    return sorted.enumerated().map { index, face in
        CachedFace(
            boundingBox: face.boundingBox,
            personIndex: index + 1,  // 1-based index
            isValidSlot: false       // 나중에 갱신됨
        )
    }
}
```

---

### 10.11 Validation Rules (검증 규칙)

구현 후 다음 조건들을 검증해야 합니다:

#### 그룹 형성 검증

| # | 규칙 | 검증 방법 |
|---|------|----------|
| 1 | 모든 인접 거리 ≤ 10.0인 N장 → 1개 그룹 | 단위 테스트 |
| 2 | 거리 > 10.0 지점에서 그룹 분리 | 단위 테스트 |
| 3 | 3장 미만 그룹은 무효 | 단위 테스트 |
| 4 | 유효 슬롯 0개 그룹은 무효 | 단위 테스트 |
| 5 | 캐시 상태가 올바르게 업데이트됨 | 통합 테스트 |

#### 성능 검증

| # | 규칙 | 기준 |
|---|------|------|
| 1 | 15장 분석 < 1초 | 병렬 처리 시 |
| 2 | 메모리 누수 없음 | Instruments Leaks |
| 3 | 60fps 스크롤 유지 | Core Animation FPS |

#### Edge Case 검증

| # | 시나리오 | 예상 결과 |
|---|----------|----------|
| 1 | 1장만 분석 | 그룹 없음 |
| 2 | 모든 사진 다름 | 그룹 없음 |
| 3 | 얼굴 없는 사진만 | 그룹 없음 |
| 4 | 경계값 거리 (10.0) | 같은 그룹 |

---

## References

- [Apple Developer - VNGenerateImageFeaturePrintRequest](https://developer.apple.com/documentation/vision/vngenerateimagefeatureprintrequest)
- [Apple ML Research - Recognizing People in Photos](https://machinelearning.apple.com/research/recognizing-people-photos)
- [WWDC 2019 - Image Similarity](https://developer.apple.com/videos/play/wwdc2019/222/)
- [WWDC 2021 - Vision Updates](https://developer.apple.com/videos/play/wwdc2021/10040/)
- PRD 문서: [prd9.md](../../docs/prd9.md), [prd9algorithm.md](../../docs/prd9algorithm.md)

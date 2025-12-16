# Spike Test 설계 문서

## 목표

레벨별 시나리오 + 레벨별 기준으로 테스트를 설계하여, max 한 방에 휘둘리지 않고 **현실 체감**과 **최악 회귀**를 동시에 관리

---

## 공통 전제

| 항목 | 값 |
|------|-----|
| 데이터 규모 | 1k / 5k / 10k / 50k |
| 기기 | iPhone 실기기 (60Hz 기준, ProMotion 있으면 추가) |
| 지표 | p50 / p90 / p95 / max + hitch 비율 + longest hitch |
| 측정 횟수 | L1: 50회, L2/L3: 20회 |
| 1차 게이트 | hitch 비율 + longest hitch (체감 기준) |
| 2차 게이트 | p95 (회귀 추적용, 절대 기준 아님) |

---

## Apple 공식 Hitch 기준 (WWDC 2020/2021)

> 출처: [Eliminate animation hitches with XCTest](https://developer.apple.com/videos/play/wwdc2020/10077/), [Explore UI animation hitches and the render loop](https://developer.apple.com/videos/play/tech-talks/10855/)

| 등급 | Hitch Time Ratio | 사용자 체감 |
|------|------------------|-------------|
| **Good** | < 5 ms/s | 거의 인지 못함 |
| **Warning** | 5-10 ms/s | 가끔 인지됨, 조사 필요 |
| **Critical** | > 10 ms/s | 명확히 불편함, 즉시 해결 필요 |

**Hitch Time Ratio 계산 (Apple 방식 - 초과분 누적):**
```
hitchTime = sum( max(0, actualDelta - expectedFrameTime) )  // 초과분의 합
hitchTimeRatio = hitchTime / durationSeconds                 // 단위: ms/s
```

**예시:**
- 60Hz에서 프레임이 35ms 걸렸다면: 초과분 = 35ms - 16.67ms = **18.33ms**
- 120Hz에서 1프레임 드랍/초 → ~8.33 ms/s = **Warning**
- 60Hz에서 1프레임 드랍/초 → ~16.67 ms/s = **Critical**

---

## 측정 정의

| 지표 | 정의 |
|------|------|
| **p95 측정 구간** | 삭제 트리거 시점 → `dataSource.apply()` 완료까지 메인 스레드 블로킹 시간 |
| **측정 방법** | `CACurrentMediaTime()` 으로 apply 전후 타임스탬프 차이 (ms 단위) |
| **Hitch Time 누적** | `delta > baseline` 이면 `hitchTime += (delta - baseline)` (Apple 기준: 초과분 전부) |
| **dropped 판정** | `delta > baseline * 1.5` 일 때만 드랍으로 카운트 (체감 가능한 hitch) |
| **dropped 계산** | `dropped = max(0, round(delta / baseline) - 1)` (참고용) |
| **longest hitch** | 최대 연속 드랍 프레임 수 + ms 단위 병기 (예: `2 (33.3ms)`) |
| **baseline** | CADisplayLink의 첫 30프레임 중앙값 (ProMotion 가변 주사율 대응) |

**주의: baseline은 maximumFramesPerSecond(최대치)가 아닌 실측값 사용**
- ProMotion 기기에서 정지 상태일 때 60Hz로 동작할 수 있음
- 고정 8.33ms budget 사용 시 과대 측정 위험

---

## 레벨별 시나리오 설계

### Level 1: 현실 (Realistic)

> 사용자가 "멈춘 상태에서" 삭제/정리하는 일반 패턴

| ID | 시나리오 | 설명 |
|----|---------|------|
| L1-1 | 정지 상태 단일 삭제 | 스크롤 정지 후 1장 삭제, 1~2초 간격, **50회** |
| L1-2 | 멀티 선택 삭제 | 100장 선택 후 한번에 삭제, 1회 (단일값 기록) |

**기준** (Apple 기준 적용):
- Hitch Time Ratio < 5 ms/s (Good)
- longest hitch ≤ 2 프레임
- p95는 회귀 추적용 기록

---

### Level 2: 현실+엣지 (Realistic Edge)

> 실제로 충분히 발생 가능한 "감속 중/빠른 템포" 상황

| ID | 시나리오 | 설명 |
|----|---------|------|
| L2-1 | 감속 중 삭제 | 플릭 후 `isDecelerating` 상태에서 삭제, **20회** |
| L2-2 | 빠른 템포 삭제 | 0.5~1초 간격으로 삭제, **20회** |

**기준** (Apple 기준 적용):
- Hitch Time Ratio < 10 ms/s (Warning 이하)
- longest hitch ≤ 3 프레임
- p90/p95가 튀면 정책 변경 검토 트리거

---

### Level 3: 스트레스 (Stress / Regression)

> 구조적 약점과 최악 회귀를 잡는 용도

| ID | 시나리오 | 설명 |
|----|---------|------|
| L3-1 | 감속 중 연속 삭제 | 감속 상태에서 **20회** 연속 삭제 |
| L3-2 | 극한 연속 삭제 | **20회**/2초 (0.1초 간격) |

**기준** (회귀 방지용):
- Critical (> 10 ms/s) 발생 시 구조 검토
- longest hitch를 회귀 기준으로 관리
- 문제 시 구조 개선 (코얼레싱/지연 적용) 검토

---

## 판단 규칙

| 조건 | 의미 | 액션 |
|------|------|------|
| L1에서 hitch 목표 미달 | 기본 구조 문제 | Plan B 검토 |
| L2에서만 문제 | 정책 문제 | 지연 적용/코얼레싱 검토 |
| L3에서만 max가 튐 | 회귀 방지 문제 | 제품 목표와 분리 관리 |

---

## 스케일링 판정

1k → 5k → 10k → 50k 에서 p95 증가 추세 분석:

| 추세 | 해석 |
|------|------|
| 선형 (O(N)) 이고 기울기가 가파름 | 구조 문제 의심 |
| 선형이지만 기울기 완만 | 예상 범위 내 |
| 로그/상수에 가까움 | 안전 |

---

## 예상 결과 포맷

```
=== Level 1: Realistic (10k items) ===

L1-1 정지 상태 단일 삭제 (50회):
  p50: 8.2ms  p90: 10.5ms  p95: 12.1ms  max: 15.3ms
  hitch: 2.3 ms/s [Good], dropped: 2, longest: 1 (16.7ms)
  ✅ PASS [Good]

L1-2 멀티 선택 삭제 (100장):
  time: 22.1ms
  ⚠️ OVER budget (단일 작업이므로 허용)

=== Level 2: Edge (10k items) ===

L2-1 감속 중 삭제 (20회):
  p50: 15.2ms  p90: 17.8ms  p95: 18.5ms  max: 21.3ms
  hitch: 6.5 ms/s [Warning], dropped: 3, longest: 2 (33.3ms)
  ⚠️ WARNING (6.5 ms/s)

=== Level 3: Stress (10k items) ===

L3-2 극한 연속 삭제 (20회/2초):
  p50: 18.5ms  p90: 25.2ms  p95: 28.1ms  max: 35.7ms
  hitch: 12.3 ms/s [Critical], dropped: 5, longest: 4 (66.7ms)
  📊 회귀 기준선 기록
```

---

# Spike 1 결론

## 실험 목표

50k 사진 라이브러리에서 삭제 시 Apple 기준 (< 5 ms/s, Good) 충족 여부 검증

---

## Plan A: DiffableDataSource

### 접근 방식
```swift
var snapshot = dataSource.snapshot()
snapshot.deleteItems([id])
dataSource.apply(snapshot, animatingDifferences: false)
```

### 결과 (50k, L1-1 정지 상태 단일 삭제)

| 지표 | 값 | 판정 |
|------|-----|------|
| p95 | **52ms** | - |
| hitchTimeRatio | **22 ms/s** | ❌ Critical |
| longest hitch | 3 프레임 (50ms) | ❌ 기준 초과 |

### 스케일링 분석

| Scale | p95 | 비고 |
|-------|-----|------|
| 5k | ~14ms | ✅ Good |
| 10k | ~23ms | ❌ Critical |
| 50k | ~52ms | ❌ Critical |

**결론**: `apply()` 비용이 **O(N)** 스케일링. 10k 이상에서 구조적 한계.

---

## Plan B: performBatchUpdates

### 접근 방식
```swift
identifiers.remove(at: index)
collectionView.performBatchUpdates {
    collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
}
```

### 결과 (50k, L1-1 정지 상태 단일 삭제)

| 지표 | 값 | 판정 |
|------|-----|------|
| p95 | **5ms** | - |
| hitchTimeRatio | **0 ms/s** | ✅ Good |
| longest hitch | 0 | ✅ 기준 충족 |

### 스케일링 분석

| Scale | p95 | 비고 |
|-------|-----|------|
| 5k | ~4ms | ✅ Good |
| 10k | ~4ms | ✅ Good |
| 50k | ~5ms | ✅ Good |

**결론**: 삭제 비용이 **O(1)** 상수. 스케일 무관하게 일정한 성능.

---

## Plan A vs Plan B 비교 (50k)

| 지표 | Plan A | Plan B | 개선율 |
|------|--------|--------|--------|
| L1-1 p95 | 52ms | **5ms** | **10x** |
| L1-1 hitch | 22 ms/s ❌ | **0 ms/s** ✅ | - |
| L2-2 p95 | 53ms | **4ms** | **13x** |
| L3-2 p95 | 50ms | **4ms** | **12x** |

---

## 최종 결론

### 채택: Plan B (performBatchUpdates + 수동 배열)

**이유**:
1. 50k에서 단일 삭제 ~5ms (프레임 예산 16.67ms 내)
2. hitchTimeRatio 0 ms/s [Good] 달성
3. O(1) 스케일링으로 데이터 규모 무관하게 일정한 성능

### 구현 시 고려사항

1. **수동 배열 동기화**: PhotoKit의 `PHFetchResult`와 로컬 배열 동기화 필요
2. **인덱스 관리**: 삭제 시 인덱스 정확성 유지 (뒤에서부터 삭제 권장)
3. **배치 삭제**: 여러 항목 삭제 시 `performBatchUpdates` 내에서 한번에 처리

### 테스트 코드 위치

```
/Users/karl/Project/Photos/iOS/test/Spike1/Spike1Test/
├── Spike1ViewController.swift      # Plan B 구현
├── HitchMonitor.swift              # Apple 방식 hitch 측정
├── BenchmarkMetrics.swift          # p50/p90/p95/max 계산
└── backup/
    └── Spike1ViewController_PlanA_backup.swift  # Plan A 백업
```

---

# Gate 2 결과: Image Loading

## 테스트 인프라

Provider 패턴으로 Mock/PhotoKit 전환 가능하게 구현:

```
├── Gate2ViewController.swift    # Provider 기반 이미지 로딩 테스트
├── ImageProvider.swift          # Protocol + MockImageProvider + PhotoKitImageProvider
├── ImageLoadingMetrics.swift    # 요청/취소/완료 추적, latency, maxInFlight
```

## Mock Provider 결과 (시뮬레이터)

| 규모 | hitch | 판정 |
|------|-------|------|
| 1k | 1.6 ms/s | ✅ Good |
| 5k | 2.0 ms/s | ✅ Good |
| 10k | 2.4 ms/s | ✅ Good |
| 50k | 3.2 ms/s | ✅ Good |

## 측정 지표

- hitch (ms/s): Apple 기준
- req/cancel/complete per second
- latency avg/p95/max (ms)
- maxInFlight (동시 요청 최대치)

## ⏳ 실기기 테스트 보류

| 항목 | 상태 | 비고 |
|------|------|------|
| PhotoKit Provider | **보류** | 실기기 + 실사진 라이브러리 필요 |
| 50k 실사진 스크롤 | **보류** | Gate 2 PhotoKit 테스트 시 수행 |

---

# Gate 3 결과: Pinch Zoom

## 테스트 결과 (10k, 시뮬레이터)

| 전환 | hitch | drift |
|------|-------|-------|
| 3→1 | 0.0 ms/s | 13px |
| 1→3 | 0.0 ms/s | 13px |
| 3→5 | 0.0 ms/s | 13px |
| 5→3 | 0.0 ms/s | 65px |

**평균**: hitch 0.0 ms/s ✅ Good, drift 26px

## 확정 파라미터

| 파라미터 | 값 | 비고 |
|----------|-----|------|
| zoomInThreshold | **0.85** | scale < 0.85 → 확대 (열 수 감소) |
| zoomOutThreshold | **1.15** | scale > 1.15 → 축소 (열 수 증가) |
| cooldown | **200ms** | 전환 간 최소 간격 |
| 앵커 drift 허용 | **65px** | 1셀 이내 오차 허용 |

## 스케일링 분석

| 규모 | hitch | drift | 비고 |
|------|-------|-------|------|
| 1k | 0.0 ms/s | 26px | ✅ |
| 10k | 0.0 ms/s | 26px | ✅ |
| 50k | 0.0 ms/s | 26px | ✅ |

**결론**: CompositionalLayout이 가상화를 잘 처리하여 스케일 무관하게 일정한 성능

---

# Gate 4 결과: 120Hz Performance

## 테스트 결과 (50k, 실기기 120Hz)

| 모드 | hitch | avgFrame | 판정 |
|------|-------|----------|------|
| ProMotion OFF | 2.0 ms/s | 15.94ms | ✅ Good |
| ProMotion ON | 2.0 ms/s | 15.93ms | ✅ Good |

## 관찰

- 120Hz 기기이지만 avgFrame ~16ms (60Hz 수준으로 동작)
- 시스템이 콘텐츠에 따라 자동으로 프레임 레이트 조절
- 단순 컬러 셀에서는 120Hz 불필요하다고 판단

## 확정 정책

| 항목 | 결정 |
|------|------|
| ProMotion 정책 | **시스템 자동 관리** |
| preferredFrameRateRange | 별도 설정 불필요 |
| 프레임 버짓 | 8.33ms (120Hz) / 16.67ms (60Hz) 준수 확인 |

---

# 실기기 테스트 보류 목록

| Gate | 테스트 항목 | 필요 조건 | 우선순위 |
|------|------------|----------|----------|
| Gate 2 | PhotoKit Provider 50k 스크롤 | 실기기 + 5만장 사진 | **높음** |
| Gate 2 | 실사진 로딩 latency 측정 | 실기기 + 실사진 | **높음** |
| Gate 4 | 실사진 + 120Hz 조합 테스트 | 실기기 + ProMotion | 중간 |

## 테스트 방법 (실기기 준비 후)

1. Xcode에서 Spike1Test 앱을 실기기에 빌드
2. Gate 2 → PhotoKit Provider 선택
3. Test 버튼으로 자동 스크롤 테스트 실행
4. 콘솔에서 결과 확인

```
예상 출력:
=== Gate 2: PhotoKit ===
Items: 50000, Fetch time: XXms
hitch: X.X ms/s [Good/Warning/Critical]
req/s: XX | cancel/s: XX | complete/s: XX
latency avg: XXms p95: XXms max: XXms
maxInFlight: XX
```

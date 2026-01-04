# 썸네일 고해상도 전환 개선 계획 (Phase 1/2 + 로그 수집)

## 목표
- "고해상도 전환이 티 나게 보임"을 완화한다.
- "더 빠르게" 전환되도록 R2 도착 시점을 앞당긴다.
- 스크롤 속도에 따른 차이를 분리 측정한다 (Slow/Fast).

---

## Phase 1: CrossFade + 디바운스 단축

### 변경 내용
- R2 전용 CrossFade 적용
  - 위치: `PhotoCell.refreshImageIfNeeded`
  - 조건: `isDegraded == false`, `imageView.window != nil`
  - `imageView.image == nil`이면 애니메이션 생략
- scrollEnd 디바운스 100ms -> 50ms

### 기대 효과
- 전환 "티남" 완화 (체감 개선)
- R2 시작 시점이 최대 50ms 단축

---

## Phase 2: 감속 중 preheat 선행

### 변경 내용
- `scrollViewWillEndDragging(_:velocity:)` 또는 `scrollViewDidScroll`에서
  감속 진입 시 full-size preheat 선행 호출
- 중복 호출 방지 플래그/타이머 추가
- preheat 범위: visible + 1 screen (기존 로직 재사용)

### 기대 효과
- R2 시점에 캐시 히트 확률 상승
- 고해상도 도착 시간이 더 빠르게 수렴

---

## 로그 수집 계획 (속도 2분류)

### 속도 분류 기준 (예시)
- Slow: `abs(velocity.y) < 1500`
- Fast: `abs(velocity.y) > 5000`
- 중간 구간은 제외(분석 노이즈 방지)

### 공통 로그
1) 속도 분류 로그 (감속 진입 시점)
```
[Scroll] end velocity=XXXX, class=slow|fast
```

2) R2 시작/완료 타이밍 로그
```
[R2] start class=slow|fast t=+XXXXms
[R2] final latency=XXms class=slow|fast
```

3) 해상도 체크 (고정 타이밍 2회)
```
[Thumb:Check] t=0.2s class=slow|fast expected=384px total=24 match=XX underSized=YY
[Thumb:Check] t=0.6s class=slow|fast expected=384px total=24 match=XX underSized=YY
```

### 측정 방식
- Slow/Fast 각각 최소 5회씩 수행
- 동일한 기기/동일한 컬럼 수(3열) 기준으로 고정
- Phase별 로그를 분리 저장

---

## 기대 로그 변화 요약

| 구간 | 지표 | 현재 | Phase 1 | Phase 2 |
|------|------|------|---------|---------|
| Slow | [R2] final latency | 기준값 | ~50ms 감소 | 추가 감소(수십~수백ms) |
| Slow | [Thumb:Check] underSized @0.2s | 높음 | 유사 | 감소 |
| Fast | [R2] final latency | 기준값 | ~50ms 감소 | 소폭 감소 |
| Fast | [Thumb:Check] underSized @0.6s | 높음 | 유사 | 감소 |

---

## 테스트 시나리오
1) 현재 상태 로그 수집 (Slow/Fast)
2) Phase 1 적용 후 로그 수집
3) Phase 2 적용 후 로그 수집
4) 체감(전환 부드러움) + 로그(R2 latency, underSized) 동시 판단


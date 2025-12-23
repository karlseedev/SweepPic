# Gate 2 테스트 로그 - v7 디스크 캐시 OFF + 캐시 계측 (2025-12-22)

## 테스트 환경
- Device: iPhone14,2 (iPhone 13 Pro)
- iOS: 18.6.2
- Build: Release
- LowPowerMode: OFF

## 설정
- deliveryMode: opportunistic
- cancelPolicy: prepareForReuse
- R2Recovery: disabled
- **skipDiskCache: true** (디스크 캐시 비활성화)

---

## 로그

```
=== PickPhoto Launch Log ===
Date: 2025-12-22 18:51:28
Device: iPhone14,2
============================
[+6.7ms] [Env] Build: Release
[+6.7ms] [Env] LowPowerMode: OFF
[+6.7ms] [Env] PhotosAuth: authorized
[+7.0ms] [Config] deliveryMode: opportunistic
[+7.0ms] [Config] cancelPolicy: prepareForReuse
[+7.0ms] [Config] R2Recovery: disabled
[+54.3ms] [Timing] === 초기 로딩 시작 ===
[+86.8ms] [Timing] viewWillAppear: +32.5ms (초기 진입 - reloadData 스킵)
[+99.5ms] [Timing] C) 첫 레이아웃 완료: +45.2ms
[+159.9ms] [Timing] E0) finishInitialDisplay 시작: +105.6ms (reason: preload complete, preloaded: 12/12)
[+165.1ms] [Timing] D) 첫 셀 표시: +110.8ms (indexPath: [0, 0])
[+168.2ms] [Pipeline] requestImage #10: +161.2ms
[+173.7ms] [Timing] E1) reloadData+layout 완료: +119.4ms (E0→E1: 13.7ms)
[+175.0ms] [Pipeline] requestImage #20: +168.0ms
[+184.4ms] [Timing] E2) scrollToItem+layout 완료: +130.1ms (E1→E2: 10.7ms)
[+184.6ms] [Timing] === 초기 로딩 완료: +130.1ms (E0→E1: 13.7ms, E1→E2: 10.7ms) ===
[+184.6ms] [Timing] 최종 통계: cellForItemAt 36회, 총 15.7ms, 평균 0.44ms
[+184.6ms] [Initial Load] req: 24 (135.1/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+184.6ms] [Initial Load] degraded: 24, maxInFlight: 24
[+184.6ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+184.6ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+184.6ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+184.6ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+1426.2ms] [Scroll] First scroll 시작: +1371.8ms
[+1435.2ms] [Pipeline] completion #50 도달: +1428.5ms
[+1466.3ms] [Pipeline] requestImage #30: +1459.6ms
[+3212.9ms] [Hitch] L1 First: hitch: 21.6 ms/s [Critical], dropped: 3, longest: 1 (15.0ms)
[+3213.0ms] [L1 First] memHit: 0, memMiss: 81, hitRate: 0.0%
[+3213.1ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+3213.1ms] [Scroll] First scroll 완료: 1787.5ms 동안 스크롤
[+3213.3ms] [First Scroll] req: 105 (32.7/s), cancel: 63 (19.6/s), complete: 105 (32.7/s)
[+3213.3ms] [First Scroll] degraded: 77, maxInFlight: 24
[+3213.3ms] [First Scroll] latency avg: 16.7ms, p95: 83.9ms, max: 136.8ms
[+3213.3ms] [First Scroll] preheat: 6회, 총 30개 에셋
[+6225.1ms] [Hitch] L2 Steady: hitch: 16.6 ms/s [Critical], dropped: 4, longest: 2 (26.5ms)
[+6225.2ms] [L2 Steady] memHit: 0, memMiss: 207, hitRate: 0.0%
[+6225.2ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+10866.3ms] [Hitch] L2 Steady: hitch: 27.3 ms/s [Critical], dropped: 6, longest: 2 (27.3ms)
[+10866.3ms] [L2 Steady] memHit: 0, memMiss: 2604, hitRate: 0.0%
[+10866.3ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
```

---

## 분석

### 1. Initial Load 정상 동작 확인 ✅
- preloaded: 12/12 → 초기 프리로드 완료
- memHit: 12, memMiss: 36 → 프리로드된 12개가 메모리 캐시 히트
- hitRate: 25.0% (12/48 = 25%)

### 2. 스크롤 시 메모리 캐시 히트율 0% 🔍
- L1 First: memHit: 0, memMiss: 81
- L2 Steady: memHit: 0, memMiss: 207 / 2604
- **원인**: 극한 스크롤로 새 영역만 방문 → 당연히 0%
- **검증 필요**: 같은 구간 반복 스크롤 시 히트율 확인

### 3. mismatch 카운터 모두 0 ✅
- diskCacheMismatch: 0 (skipDiskCache=true라 호출 안 함)
- pipelineMismatch: 0 (Pipeline 콜백이 버려지지 않음)
- **좋은 신호**: 셀 재사용 전에 degraded 응답이 도착

### 4. Hitch 수준
| 구간 | Hitch | 레벨 |
|------|-------|------|
| L1 First | 21.6 ms/s | Critical |
| L2 Steady #1 | 16.6 ms/s | Critical |
| L2 Steady #2 | 27.3 ms/s | Critical |

- Phase 6 대비 5~7배 개선 (151 → 21 ms/s)
- 여전히 Critical (>10 ms/s)

### 5. Pipeline 통계
- cancel율: 60% (105 req, 63 cancel)
- degraded: 77 (73% degraded first-paint)
- latency p95: 83.9ms (final 완료까지)

---

## 결론

1. **디스크 캐시 OFF로 회색 썸네일 문제 해결됨**
2. **pipelineMismatch: 0 → degraded가 충분히 빨라서 셀 재사용 전에 도착**
3. **메모리 캐시 히트율 0%는 극한 스크롤에서 당연 (새 영역만 방문)**
4. **Hitch는 여전히 Critical → 후보 A 적용 필요**

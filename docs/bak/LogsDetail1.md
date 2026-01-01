# 성능 로그 상세 (원본 로그)

> **파일 안내:**
> - 이 파일은 `logs.md`의 원본 로그를 분리한 파일입니다
> - 각 파일이 2000줄 초과 시 다음 번호 파일에 저장 (1 → 2 → 3 → ...)
> - 각 섹션은 `<!-- LOG_ID: [식별자] -->`로 검색 가능합니다

---

<!-- LOG_ID: P0_16-25_3500 -->
## P0 기준점 (2025-12-23 16:25) - 3500장

```
=== PickPhoto Launch Log ===
Date: 2025-12-23 16:25:25
Device: iPhone14,2
============================
[+4.5ms] [Env] Build: Release
[+4.6ms] [Env] LowPowerMode: OFF
[+4.6ms] [Env] PhotosAuth: authorized
[+4.8ms] [Config] deliveryMode: opportunistic
[+4.8ms] [Config] cancelPolicy: prepareForReuse
[+4.8ms] [Config] R2Recovery: disabled
[+64.4ms] [Timing] === 초기 로딩 시작 ===
[+97.3ms] [Timing] viewWillAppear: +33.0ms (초기 진입 - reloadData 스킵)
[+111.3ms] [Timing] C) 첫 레이아웃 완료: +47.0ms
[+130.4ms] [Preload] DISK HIT: F3EC02C8...
[+134.6ms] [Preload] DISK HIT: 0655447F...
[+138.7ms] [Preload] DISK HIT: 699CA480...
[+142.2ms] [Preload] DISK HIT: E5D2A7F7...
[+145.8ms] [Preload] DISK HIT: 61F383D4...
[+149.6ms] [Preload] DISK HIT: 97EEA684...
[+153.7ms] [Preload] DISK HIT: B2F48D66...
[+157.4ms] [Preload] DISK HIT: F00FD4BC...
[+160.7ms] [Preload] DISK HIT: 70ACEA88...
[+164.3ms] [Preload] DISK HIT: 6907A28F...
[+167.7ms] [Preload] DISK HIT: C2E6BD92...
[+171.3ms] [Preload] DISK HIT: E70BD01F...
[+171.4ms] [Timing] E0) finishInitialDisplay 시작: +107.0ms (reason: preload complete, preloaded: 12/12)
[+176.6ms] [Timing] D) 첫 셀 표시: +112.2ms (indexPath: [0, 0])
[+179.6ms] [Pipeline] requestImage #10: +174.8ms
[+184.9ms] [Timing] E1) reloadData+layout 완료: +120.6ms (E0→E1: 13.6ms)
[+185.9ms] [Pipeline] requestImage #20: +181.1ms
[+194.6ms] [Timing] E2) scrollToItem+layout 완료: +130.2ms (E1→E2: 9.6ms)
[+194.7ms] [Timing] === 초기 로딩 완료: +130.2ms (E0→E1: 13.6ms, E1→E2: 9.6ms) ===
[+194.7ms] [Timing] 최종 통계: cellForItemAt 36회, 총 15.6ms, 평균 0.43ms
[+194.7ms] [Initial Load] req: 24 (126.4/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+194.7ms] [Initial Load] degraded: 20, maxInFlight: 24
[+194.7ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+194.7ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+194.7ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+194.7ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+194.7ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+1898.8ms] [Scroll] First scroll 시작: +1834.1ms
[+1916.7ms] [Pipeline] completion #50 도달: +1911.9ms
[+1940.3ms] [Pipeline] requestImage #30: +1935.6ms
[+10245.0ms] [Hitch] L1 First: hitch: 15.0 ms/s [Critical], dropped: 11, longest: 2 (27.1ms)
[+10245.1ms] [L1 First] memHit: 0, memMiss: 549, hitRate: 0.0%
[+10245.1ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+10245.2ms] [L1 First] grayShown: 90, grayResolved: 573, pending: -483
[+10245.4ms] [L1 First] req: 573 (56.0/s), cancel: 531 (51.9/s), complete: 573 (56.0/s)
[+10245.5ms] [L1 First] degraded: 573, maxInFlight: 24
[+10245.5ms] [L1 First] latency avg: 7.4ms, p95: 9.2ms, max: 145.5ms
[+10245.5ms] [L1 First] preheat: 0회, 총 0개 에셋
[+10245.6ms] [Scroll] First scroll 완료: 8347.3ms 동안 스크롤
[+11221.0ms] [Pipeline] requestImage #10: +975.4ms
[+11294.6ms] [Pipeline] requestImage #20: +1049.0ms
[+11325.8ms] [Pipeline] completion #50 도달: +1080.3ms
[+11394.2ms] [Pipeline] requestImage #30: +1148.6ms
[+24812.5ms] [Hitch] L2 Steady: hitch: 29.8 ms/s [Critical], dropped: 32, longest: 2 (26.6ms)
[+24812.6ms] [L2 Steady] memHit: 0, memMiss: 7762, hitRate: 0.0%
[+24812.7ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+24812.7ms] [L2 Steady] grayShown: 7038, grayResolved: 7762, pending: -724
[+24814.7ms] [L2 Steady] req: 7762 (532.8/s), cancel: 7750 (532.0/s), complete: 7761 (532.8/s)
[+24814.8ms] [L2 Steady] degraded: 7762, maxInFlight: 0
[+24814.8ms] [L2 Steady] latency avg: 5.5ms, p95: 9.6ms, max: 17.1ms
[+24814.9ms] [L2 Steady] preheat: 1회, 총 66개 에셋
```

---

<!-- LOG_ID: P0+Phase7_23-17_3500 -->
## P0+Phase7 (2025-12-23 23:17) - 3500장 (재측정)

```
=== PickPhoto Launch Log ===
Date: 2025-12-23 23:17:27
Device: iPhone14,2
============================
[+4.8ms] [Env] Build: Release
[+4.9ms] [Env] LowPowerMode: OFF
[+4.9ms] [Env] PhotosAuth: authorized
[+5.1ms] [Config] deliveryMode: opportunistic
[+5.1ms] [Config] cancelPolicy: prepareForReuse
[+5.1ms] [Config] R2Recovery: disabled
[+101.5ms] [Timing] === 초기 로딩 시작 ===
[+103.1ms] [Timing] viewWillAppear: +1.6ms (초기 진입 - reloadData 스킵)
[+138.6ms] [Timing] C) 첫 레이아웃 완료: +37.1ms
[+161.2ms] [Preload] DISK HIT: B72E5653...
[+166.0ms] [Preload] DISK HIT: 6A03D5D4...
[+169.1ms] [Preload] DISK HIT: EB31907C...
[+172.4ms] [Preload] DISK HIT: F3EC02C8...
[+177.0ms] [Preload] DISK HIT: 0655447F...
[+182.0ms] [Preload] DISK HIT: E5D2A7F7...
[+186.1ms] [Preload] DISK HIT: 61F383D4...
[+189.5ms] [Preload] DISK HIT: B2F48D66...
[+192.9ms] [Preload] DISK HIT: 70ACEA88...
[+196.1ms] [Preload] DISK HIT: 6907A28F...
[+200.4ms] [Preload] DISK HIT: C2E6BD92...
[+204.7ms] [Preload] DISK HIT: E70BD01F...
[+204.7ms] [Timing] E0) finishInitialDisplay 시작: +103.2ms (reason: preload complete, preloaded: 12/12)
[+209.8ms] [Timing] D) 첫 셀 표시: +108.3ms (indexPath: [0, 0])
[+212.7ms] [Pipeline] requestImage #10: +207.7ms
[+218.0ms] [Timing] E1) reloadData+layout 완료: +116.5ms (E0→E1: 13.3ms)
[+218.8ms] [Pipeline] requestImage #20: +213.8ms
[+226.8ms] [Timing] E2) scrollToItem+layout 완료: +125.3ms (E1→E2: 8.8ms)
[+226.9ms] [Timing] === 초기 로딩 완료: +125.3ms (E0→E1: 13.3ms, E1→E2: 8.8ms) ===
[+226.9ms] [Timing] 최종 통계: cellForItemAt 36회, 총 15.0ms, 평균 0.42ms
[+226.9ms] [Initial Load] req: 24 (108.2/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+226.9ms] [Initial Load] degraded: 24, maxInFlight: 24
[+226.9ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+227.0ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+227.0ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+227.0ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+227.0ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+1817.6ms] [Scroll] First scroll 시작: +1715.8ms
[+1826.8ms] [Pipeline] completion #50 도달: +1821.7ms
[+1847.6ms] [Pipeline] requestImage #30: +1842.5ms
[+8776.2ms] [Hitch] L1 First: hitch: 22.8 ms/s [Critical], dropped: 14, longest: 2 (27.2ms)
[+8776.3ms] [L1 First] memHit: 0, memMiss: 894, hitRate: 0.0%
[+8776.3ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+8776.3ms] [L1 First] grayShown: 537, grayResolved: 918, pending: -381
[+8776.7ms] [L1 First] req: 918 (104.7/s), cancel: 876 (99.9/s), complete: 918 (104.7/s)
[+8776.7ms] [L1 First] degraded: 918, maxInFlight: 24
[+8776.8ms] [L1 First] latency avg: 6.0ms, p95: 8.3ms, max: 108.6ms
[+8776.8ms] [L1 First] preheat: 0회, 총 0개 에셋
[+8776.9ms] [Scroll] First scroll 완료: 6959.6ms 동안 스크롤
[+10963.7ms] [Pipeline] requestImage #10: +2186.8ms
[+11038.7ms] [Pipeline] requestImage #20: +2261.8ms
[+11113.1ms] [Pipeline] completion #50 도달: +2336.3ms
[+11154.5ms] [Pipeline] requestImage #30: +2377.6ms
[+20256.6ms] [Hitch] L2 Steady: hitch: 37.1 ms/s [Critical], dropped: 35, longest: 2 (27.1ms)
[+20256.7ms] [L2 Steady] memHit: 0, memMiss: 5895, hitRate: 0.0%
[+20256.8ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+20256.8ms] [L2 Steady] grayShown: 5424, grayResolved: 5895, pending: -471
[+20258.3ms] [L2 Steady] req: 5896 (513.6/s), cancel: 5878 (512.0/s), complete: 5894 (513.4/s)
[+20258.4ms] [L2 Steady] degraded: 5896, maxInFlight: 0
[+20258.4ms] [L2 Steady] latency avg: 5.8ms, p95: 9.8ms, max: 55.7ms
[+20258.4ms] [L2 Steady] preheat: 1회, 총 63개 에셋
```

---

<!-- LOG_ID: P0+Phase7_23-12_3500 -->
## P0+Phase7 (2025-12-23 23:12) - 3500장 (첫 측정)

```
=== PickPhoto Launch Log ===
Date: 2025-12-23 23:12:38
Device: iPhone14,2
============================
[+5.1ms] [Env] Build: Release
[+5.2ms] [Env] LowPowerMode: OFF
[+5.3ms] [Env] PhotosAuth: authorized
[+5.6ms] [Config] deliveryMode: opportunistic
[+5.6ms] [Config] cancelPolicy: prepareForReuse
[+5.6ms] [Config] R2Recovery: disabled
[+99.9ms] [Timing] === 초기 로딩 시작 ===
[+101.5ms] [Timing] viewWillAppear: +1.6ms (초기 진입 - reloadData 스킵)
[+137.0ms] [Timing] C) 첫 레이아웃 완료: +37.1ms
[+156.7ms] [Preload] DISK HIT: B72E5653...
[+160.4ms] [Preload] DISK HIT: 6A03D5D4...
[+163.9ms] [Preload] DISK HIT: EB31907C...
[+167.1ms] [Preload] DISK HIT: F3EC02C8...
[+170.6ms] [Preload] DISK HIT: 0655447F...
[+174.2ms] [Preload] DISK HIT: E5D2A7F7...
[+177.8ms] [Preload] DISK HIT: 61F383D4...
[+181.5ms] [Preload] DISK HIT: B2F48D66...
[+184.5ms] [Preload] DISK HIT: 70ACEA88...
[+187.8ms] [Preload] DISK HIT: 6907A28F...
[+191.4ms] [Preload] DISK HIT: C2E6BD92...
[+194.8ms] [Preload] DISK HIT: E70BD01F...
[+194.9ms] [Timing] E0) finishInitialDisplay 시작: +94.9ms (reason: preload complete, preloaded: 12/12)
[+199.9ms] [Timing] D) 첫 셀 표시: +99.9ms (indexPath: [0, 0])
[+202.8ms] [Pipeline] requestImage #10: +197.2ms
[+208.2ms] [Timing] E1) reloadData+layout 완료: +108.3ms (E0→E1: 13.4ms)
[+209.2ms] [Pipeline] requestImage #20: +203.6ms
[+219.2ms] [Timing] E2) scrollToItem+layout 완료: +119.3ms (E1→E2: 11.0ms)
[+219.3ms] [Timing] === 초기 로딩 완료: +119.3ms (E0→E1: 13.4ms, E1→E2: 11.0ms) ===
[+219.3ms] [Timing] 최종 통계: cellForItemAt 36회, 총 15.3ms, 평균 0.43ms
[+219.4ms] [Initial Load] req: 24 (112.3/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+219.4ms] [Initial Load] degraded: 24, maxInFlight: 24
[+219.4ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+219.4ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+219.4ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+219.4ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+219.4ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+2665.7ms] [Scroll] First scroll 시작: +2565.6ms
[+2676.0ms] [Pipeline] completion #50 도달: +2670.4ms
[+2694.0ms] [Pipeline] requestImage #30: +2688.4ms
[+10958.1ms] [Hitch] L1 First: hitch: 18.1 ms/s [Critical], dropped: 15, longest: 2 (28.2ms)
[+10958.2ms] [L1 First] memHit: 0, memMiss: 857, hitRate: 0.0%
[+10958.3ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+10958.3ms] [L1 First] grayShown: 521, grayResolved: 881, pending: -360
[+10958.6ms] [L1 First] req: 881 (80.4/s), cancel: 839 (76.6/s), complete: 881 (80.4/s)
[+10958.6ms] [L1 First] degraded: 881, maxInFlight: 24
[+10958.7ms] [L1 First] latency avg: 6.0ms, p95: 9.5ms, max: 110.7ms
[+10958.7ms] [L1 First] preheat: 0회, 총 0개 에셋
[+10958.8ms] [Scroll] First scroll 완료: 8293.3ms 동안 스크롤
[+13080.0ms] [Pipeline] requestImage #10: +2121.3ms
[+13141.8ms] [Pipeline] requestImage #20: +2183.0ms
[+13183.3ms] [Pipeline] completion #50 도달: +2224.5ms
[+13228.4ms] [Pipeline] requestImage #30: +2269.7ms
[+18071.4ms] [Hitch] L2 Steady: hitch: 33.6 ms/s [Critical], dropped: 15, longest: 2 (27.6ms)
[+18071.5ms] [L2 Steady] memHit: 0, memMiss: 2686, hitRate: 0.0%
[+18071.5ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+18071.5ms] [L2 Steady] grayShown: 2440, grayResolved: 2686, pending: -246
[+18072.2ms] [L2 Steady] req: 2686 (377.6/s), cancel: 2676 (376.2/s), complete: 2652 (372.8/s)
[+18072.2ms] [L2 Steady] degraded: 2686, maxInFlight: 0
[+18072.3ms] [L2 Steady] latency avg: 8.4ms, p95: 18.6ms, max: 27.5ms
[+18072.3ms] [L2 Steady] preheat: 1회, 총 66개 에셋
```

---

<!-- LOG_ID: P0+Phase7_23-23_40000 -->
## P0+Phase7 (2025-12-23 23:23) - 4만장

```
=== PickPhoto Launch Log ===
Date: 2025-12-23 23:23:02
Device: iPhone14,2
============================
[+7.4ms] [Env] Build: Release
[+7.5ms] [Env] LowPowerMode: OFF
[+7.5ms] [Env] PhotosAuth: authorized
[+7.9ms] [Config] deliveryMode: opportunistic
[+7.9ms] [Config] cancelPolicy: prepareForReuse
[+7.9ms] [Config] R2Recovery: disabled
[+78.8ms] [Timing] === 초기 로딩 시작 ===
[+117.8ms] [Timing] viewWillAppear: +39.0ms (초기 진입 - reloadData 스킵)
[+658.9ms] [Timing] C) 첫 레이아웃 완료: +580.1ms
[+684.9ms] [Preload] DISK HIT: 7FBCE8BE...
[+689.5ms] [Preload] DISK HIT: 7348B8F7...
[+693.5ms] [Preload] DISK HIT: 8C03A517...
[+697.5ms] [Preload] DISK HIT: E6B8A4B1...
[+701.2ms] [Preload] DISK HIT: 9220E539...
[+705.2ms] [Preload] DISK HIT: 19A61F4A...
[+708.9ms] [Preload] DISK HIT: ECE08950...
[+712.3ms] [Preload] DISK HIT: BC07197E...
[+716.6ms] [Preload] DISK HIT: CD712098...
[+720.6ms] [Preload] DISK HIT: D5D7CE8A...
[+724.3ms] [Preload] DISK HIT: D19D5A41...
[+728.1ms] [Preload] DISK HIT: 8502FC1B...
[+728.1ms] [Timing] E0) finishInitialDisplay 시작: +649.3ms (reason: preload complete, preloaded: 12/12)
[+729.3ms] [Timing] D) 첫 셀 표시: +650.5ms (indexPath: [0, 0])
[+736.7ms] [Pipeline] requestImage #10: +728.8ms
[+741.8ms] [Timing] E1) reloadData+layout 완료: +663.0ms (E0→E1: 13.6ms)
[+743.0ms] [Pipeline] requestImage #20: +735.2ms
[+751.0ms] [Timing] E2) scrollToItem+layout 완료: +672.2ms (E1→E2: 9.2ms)
[+751.1ms] [Timing] === 초기 로딩 완료: +672.2ms (E0→E1: 13.6ms, E1→E2: 9.2ms) ===
[+751.1ms] [Timing] 최종 통계: cellForItemAt 35회, 총 14.6ms, 평균 0.42ms
[+751.1ms] [Initial Load] req: 23 (30.9/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+751.1ms] [Initial Load] degraded: 23, maxInFlight: 23
[+751.1ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+751.1ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+751.1ms] [Initial Load] memHit: 12, memMiss: 35, hitRate: 25.5%
[+751.1ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+751.1ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+2400.0ms] [Scroll] First scroll 시작: +2320.8ms
[+2421.7ms] [Pipeline] completion #50 도달: +2413.8ms
[+2431.1ms] [Pipeline] requestImage #30: +2423.2ms
[+11279.7ms] [Hitch] L1 First: hitch: 19.2 ms/s [Critical], dropped: 15, longest: 1 (13.7ms)
[+11279.9ms] [L1 First] memHit: 0, memMiss: 1011, hitRate: 0.0%
[+11279.9ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+11279.9ms] [L1 First] grayShown: 544, grayResolved: 1034, pending: -490
[+11280.2ms] [L1 First] req: 1034 (91.7/s), cancel: 992 (88.0/s), complete: 1034 (91.7/s)
[+11280.3ms] [L1 First] degraded: 1034, maxInFlight: 23
[+11280.3ms] [L1 First] latency avg: 6.5ms, p95: 15.1ms, max: 156.2ms
[+11280.3ms] [L1 First] preheat: 0회, 총 0개 에셋
[+11280.4ms] [Scroll] First scroll 완료: 8880.6ms 동안 스크롤
[+14192.6ms] [Pipeline] requestImage #10: +2912.2ms
[+14304.0ms] [Pipeline] requestImage #20: +3023.6ms
[+14378.4ms] [Pipeline] completion #50 도달: +3098.0ms
[+14428.6ms] [Pipeline] requestImage #30: +3148.2ms
[+31344.0ms] [Hitch] L2 Steady: hitch: 32.3 ms/s [Critical], dropped: 58, longest: 2 (26.5ms)
[+31344.1ms] [L2 Steady] memHit: 0, memMiss: 11127, hitRate: 0.0%
[+31344.2ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+31344.2ms] [L2 Steady] grayShown: 10382, grayResolved: 11127, pending: -745
[+31346.5ms] [L2 Steady] req: 11127 (554.6/s), cancel: 11117 (554.1/s), complete: 9696 (483.3/s)
[+31346.5ms] [L2 Steady] degraded: 11127, maxInFlight: 0
[+31346.5ms] [L2 Steady] latency avg: 13.6ms, p95: 28.3ms, max: 67.3ms
[+31346.6ms] [L2 Steady] preheat: 1회, 총 63개 에셋
```

---

<!-- LOG_ID: P0+Phase7_23-15_40000 -->
## P0+Phase7 (2025-12-23 23:15) - 4만장

```
=== PickPhoto Launch Log ===
Date: 2025-12-23 23:15:09
Device: iPhone14,2
============================
[+4.5ms] [Env] Build: Release
[+4.5ms] [Env] LowPowerMode: OFF
[+4.6ms] [Env] PhotosAuth: authorized
[+4.9ms] [Config] deliveryMode: opportunistic
[+4.9ms] [Config] cancelPolicy: prepareForReuse
[+4.9ms] [Config] R2Recovery: disabled
[+71.2ms] [Timing] === 초기 로딩 시작 ===
[+109.3ms] [Timing] viewWillAppear: +38.1ms (초기 진입 - reloadData 스킵)
[+645.2ms] [Timing] C) 첫 레이아웃 완료: +574.0ms
[+662.0ms] [Preload] DISK HIT: 7FBCE8BE...
[+670.5ms] [Preload] DISK HIT: 7348B8F7...
[+674.9ms] [Preload] DISK HIT: 8C03A517...
[+679.3ms] [Preload] DISK HIT: E6B8A4B1...
[+683.0ms] [Preload] DISK HIT: 9220E539...
[+687.3ms] [Preload] DISK HIT: 19A61F4A...
[+691.3ms] [Preload] DISK HIT: ECE08950...
[+694.9ms] [Preload] DISK HIT: BC07197E...
[+698.9ms] [Preload] DISK HIT: CD712098...
[+702.6ms] [Preload] DISK HIT: D5D7CE8A...
[+706.6ms] [Preload] DISK HIT: D19D5A41...
[+710.5ms] [Preload] DISK HIT: 8502FC1B...
[+710.6ms] [Timing] E0) finishInitialDisplay 시작: +639.4ms (reason: preload complete, preloaded: 12/12)
[+711.8ms] [Timing] D) 첫 셀 표시: +640.6ms (indexPath: [0, 0])
[+719.0ms] [Pipeline] requestImage #10: +714.0ms
[+724.0ms] [Timing] E1) reloadData+layout 완료: +652.8ms (E0→E1: 13.4ms)
[+725.2ms] [Pipeline] requestImage #20: +720.3ms
[+732.5ms] [Timing] E2) scrollToItem+layout 완료: +661.3ms (E1→E2: 8.5ms)
[+732.6ms] [Timing] === 초기 로딩 완료: +661.3ms (E0→E1: 13.4ms, E1→E2: 8.5ms) ===
[+732.6ms] [Timing] 최종 통계: cellForItemAt 35회, 총 14.0ms, 평균 0.40ms
[+732.6ms] [Initial Load] req: 23 (31.6/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+732.6ms] [Initial Load] degraded: 23, maxInFlight: 23
[+732.6ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+732.6ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+732.6ms] [Initial Load] memHit: 12, memMiss: 35, hitRate: 25.5%
[+732.6ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+732.6ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+3359.5ms] [Scroll] First scroll 시작: +3288.0ms
[+3381.5ms] [Pipeline] completion #50 도달: +3376.5ms
[+3385.5ms] [Pipeline] requestImage #30: +3380.5ms
[+11022.7ms] [Hitch] L1 First: hitch: 12.5 ms/s [Critical], dropped: 7, longest: 2 (27.1ms)
[+11022.8ms] [L1 First] memHit: 0, memMiss: 804, hitRate: 0.0%
[+11022.9ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+11022.9ms] [L1 First] grayShown: 429, grayResolved: 827, pending: -398
[+11023.2ms] [L1 First] req: 827 (75.1/s), cancel: 785 (71.2/s), complete: 827 (75.1/s)
[+11023.2ms] [L1 First] degraded: 827, maxInFlight: 23
[+11023.2ms] [L1 First] latency avg: 6.4ms, p95: 12.4ms, max: 165.5ms
[+11023.3ms] [L1 First] preheat: 0회, 총 0개 에셋
[+11023.3ms] [Scroll] First scroll 완료: 7664.0ms 동안 스크롤
[+14118.7ms] [Pipeline] requestImage #10: +3095.3ms
[+14264.0ms] [Pipeline] requestImage #20: +3240.7ms
[+14339.2ms] [Pipeline] completion #50 도달: +3315.8ms
[+14409.5ms] [Pipeline] requestImage #30: +3386.2ms
[+22173.6ms] [Hitch] L2 Steady: hitch: 16.2 ms/s [Critical], dropped: 6, longest: 1 (13.3ms)
[+22173.7ms] [L2 Steady] memHit: 0, memMiss: 6048, hitRate: 0.0%
[+22173.8ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+22173.8ms] [L2 Steady] grayShown: 5603, grayResolved: 6048, pending: -445
[+22174.6ms] [L2 Steady] req: 6048 (542.4/s), cancel: 6038 (541.5/s), complete: 3583 (321.3/s)
[+22174.6ms] [L2 Steady] degraded: 6048, maxInFlight: 0
[+22174.7ms] [L2 Steady] latency avg: 16.8ms, p95: 35.4ms, max: 66.4ms
[+22174.7ms] [L2 Steady] preheat: 1회, 총 63개 에셋
```

---

<!-- LOG_ID: P0+Phase7_23-08_40000 -->
## P0+Phase7 (2025-12-23 23:08) - 4만장 (첫 측정)

```
=== PickPhoto Launch Log ===
Date: 2025-12-23 23:08:23
Device: iPhone14,2
============================
[+4.2ms] [Env] Build: Release
[+4.2ms] [Env] LowPowerMode: OFF
[+4.2ms] [Env] PhotosAuth: authorized
[+4.6ms] [Config] deliveryMode: opportunistic
[+4.6ms] [Config] cancelPolicy: prepareForReuse
[+4.6ms] [Config] R2Recovery: disabled
[+103.5ms] [Timing] === 초기 로딩 시작 ===
[+144.3ms] [Timing] viewWillAppear: +40.7ms (초기 진입 - reloadData 스킵)
[+461.5ms] [Timing] C) 첫 레이아웃 완료: +358.0ms
[+483.8ms] [Preload] DISK HIT: 7FBCE8BE...
[+489.0ms] [Preload] DISK HIT: 7348B8F7...
[+493.4ms] [Preload] DISK HIT: 8C03A517...
[+497.9ms] [Preload] DISK HIT: E6B8A4B1...
[+502.0ms] [Preload] DISK HIT: 9220E539...
[+506.2ms] [Preload] DISK HIT: 19A61F4A...
[+510.1ms] [Preload] DISK HIT: ECE08950...
[+513.9ms] [Preload] DISK HIT: BC07197E...
[+518.7ms] [Preload] DISK HIT: CD712098...
[+523.1ms] [Preload] DISK HIT: D5D7CE8A...
[+527.2ms] [Preload] DISK HIT: D19D5A41...
[+531.6ms] [Preload] DISK HIT: 8502FC1B...
[+531.6ms] [Timing] E0) finishInitialDisplay 시작: +428.1ms (reason: preload complete, preloaded: 12/12)
[+533.5ms] [Timing] D) 첫 셀 표시: +430.0ms (indexPath: [0, 0])
[+541.1ms] [Pipeline] requestImage #10: +536.5ms
[+546.0ms] [Timing] E1) reloadData+layout 완료: +442.5ms (E0→E1: 14.4ms)
[+547.6ms] [Pipeline] requestImage #20: +543.0ms
[+556.6ms] [Timing] E2) scrollToItem+layout 완료: +453.1ms (E1→E2: 10.6ms)
[+556.7ms] [Timing] === 초기 로딩 완료: +453.1ms (E0→E1: 14.4ms, E1→E2: 10.6ms) ===
[+556.7ms] [Timing] 최종 통계: cellForItemAt 35회, 총 15.2ms, 평균 0.43ms
[+556.7ms] [Initial Load] req: 23 (41.7/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+556.7ms] [Initial Load] degraded: 23, maxInFlight: 23
[+556.7ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+556.7ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+556.7ms] [Initial Load] memHit: 12, memMiss: 35, hitRate: 25.5%
[+556.7ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+556.7ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+3981.1ms] [Scroll] First scroll 시작: +3877.2ms
[+4007.7ms] [Pipeline] completion #50 도달: +4003.1ms
[+4032.0ms] [Pipeline] requestImage #30: +4027.3ms
[+12744.2ms] [Hitch] L1 First: hitch: 16.2 ms/s [Critical], dropped: 12, longest: 1 (13.9ms)
[+12744.3ms] [L1 First] memHit: 0, memMiss: 531, hitRate: 0.0%
[+12744.3ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+12744.3ms] [L1 First] grayShown: 139, grayResolved: 554, pending: -415
[+12744.6ms] [L1 First] req: 554 (43.5/s), cancel: 512 (40.2/s), complete: 554 (43.5/s)
[+12744.6ms] [L1 First] degraded: 554, maxInFlight: 23
[+12744.7ms] [L1 First] latency avg: 7.8ms, p95: 17.7ms, max: 171.9ms
[+12744.7ms] [L1 First] preheat: 0회, 총 0개 에셋
[+12744.7ms] [Scroll] First scroll 완료: 8763.9ms 동안 스크롤
[+14714.7ms] [Pipeline] requestImage #10: +1969.9ms
[+14831.3ms] [Pipeline] requestImage #20: +2086.5ms
[+14888.0ms] [Pipeline] completion #50 도달: +2143.3ms
[+14930.4ms] [Pipeline] requestImage #30: +2185.7ms
[+33117.0ms] [Hitch] L2 Steady: hitch: 25.6 ms/s [Critical], dropped: 31, longest: 2 (26.5ms)
[+33117.1ms] [L2 Steady] memHit: 0, memMiss: 20014, hitRate: 0.0%
[+33117.2ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+33117.2ms] [L2 Steady] grayShown: 18972, grayResolved: 20014, pending: -1042
[+33120.1ms] [L2 Steady] req: 20014 (982.4/s), cancel: 19994 (981.4/s), complete: 12209 (599.3/s)
[+33120.2ms] [L2 Steady] degraded: 20013, maxInFlight: 0
[+33120.2ms] [L2 Steady] latency avg: 18.0ms, p95: 32.9ms, max: 149.7ms
[+33120.2ms] [L2 Steady] preheat: 1회, 총 66개 에셋
```

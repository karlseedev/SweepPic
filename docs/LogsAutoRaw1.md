# 자동 테스트 성능 로그 상세 (원본 로그)

> **파일 안내:**
> - 이 파일은 `LogsAuto.md`의 원본 로그를 분리한 파일입니다
> - 각 파일이 2000줄 초과 시 다음 번호 파일에 저장 (1 → 2 → 3 → ...)
> - 각 섹션은 `<!-- LOG_ID: [식별자] -->`로 검색 가능합니다

---

<!-- LOG_ID: XCUITest_23-32_v8000_8x -->
## XCUITest swipe (2025-12-25 23:32) - testL1L2Sequence (velocity 8000, 8회 측정)

```
=== PickPhoto Launch Log ===
Date: 2025-12-25 23:32:25
Device: iPhone14,2
============================
[+5.8ms] [Env] Build: Release
[+278.0ms] [Timing] === 초기 로딩 완료: +172.4ms ===
[+2460.1ms] [Scroll] First scroll 시작: +2354.4ms
[+5909.9ms] [Hitch] L1: hitch: 0.0 ms/s [Good], fps: 119.7, frames: 413, dropped: 0
[+5910.3ms] [L1] req: 132 (22.4/s), latency avg: 16.5ms
[+10802.0ms] [Hitch] L2: hitch: 14.9 ms/s [Critical], fps: 118.0, frames: 412, dropped: 6
[+10802.1ms] [L2] req: 99 (20.2/s), latency avg: 4.5ms
[+14374.5ms] [Hitch] L3: hitch: 4.8 ms/s [Good], fps: 117.4, frames: 407, dropped: 2
[+14374.6ms] [L3] req: 93 (26.0/s), latency avg: 16.3ms
[+17992.1ms] [Hitch] L4: hitch: 4.8 ms/s [Good], fps: 117.7, frames: 412, dropped: 2
[+17992.2ms] [L4] req: 96 (26.5/s), latency avg: 19.5ms
[+21561.0ms] [Hitch] L5: hitch: 17.4 ms/s [Critical], fps: 117.6, frames: 408, dropped: 7
[+21561.1ms] [L5] req: 93 (26.1/s), latency avg: 19.6ms
[+25126.7ms] [Hitch] L6: hitch: 14.6 ms/s [Critical], fps: 118.0, frames: 409, dropped: 6
[+25126.8ms] [L6] req: 93 (26.1/s), latency avg: 10.7ms
[+28706.6ms] [Hitch] L7: hitch: 14.1 ms/s [Critical], fps: 118.1, frames: 411, dropped: 6
[+28706.7ms] [L7] req: 96 (26.8/s), latency avg: 15.3ms
[+32377.6ms] [Hitch] L8: hitch: 0.0 ms/s [Good], fps: 119.7, frames: 413, dropped: 0
[+32377.8ms] [L8] req: 93 (25.3/s), latency avg: 4.3ms
```

---

<!-- LOG_ID: XCUITest_22-26_v8000 -->
## XCUITest swipe (2025-12-25 22:26) - testL1L2Sequence (velocity 8000, 4회 측정)

```
=== PickPhoto Launch Log ===
Date: 2025-12-25 22:26:27
Device: iPhone14,2
============================
[+3.7ms] [LaunchArgs] didFinishLaunching: count=1
[+3.7ms] [LaunchArgs] --auto-scroll: false
[+5.0ms] [Env] Build: Release
[+5.0ms] [Env] LowPowerMode: OFF
[+5.0ms] [Env] PhotosAuth: authorized
[+5.1ms] [Config] deliveryMode: opportunistic
[+5.1ms] [Config] cancelPolicy: prepareForReuse
[+5.1ms] [Config] R2Recovery: disabled
[+95.2ms] [Timing] === 초기 로딩 시작 ===
[+99.5ms] [Timing] viewWillAppear: +4.3ms (초기 진입 - reloadData 스킵)
[+110.7ms] [Timing] C) 첫 레이아웃 완료: +15.5ms
[+172.4ms] [Timing] E0) finishInitialDisplay 시작: +77.2ms (reason: preload complete, preloaded: 12/12)
[+187.9ms] [Timing] E1) reloadData+layout 완료: +92.7ms (E0→E1: 15.6ms)
[+199.5ms] [Timing] E2) scrollToItem+layout 완료: +104.2ms (E1→E2: 11.5ms)
[+199.7ms] [Timing] === 초기 로딩 완료: +104.2ms ===
[+199.8ms] [Initial Load] req: 24 (123.3/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+199.8ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+2406.4ms] [Scroll] First scroll 시작: +2310.9ms
[+5889.8ms] [Hitch] L1: hitch: 0.0 ms/s [Good], fps: 119.7, frames: 417, dropped: 0
[+5890.2ms] [L1] req: 138 (23.4/s), cancel: 96 (16.3/s), complete: 138 (23.4/s)
[+5890.3ms] [L1] latency avg: 15.1ms, p95: 83.7ms, max: 109.8ms
[+5890.4ms] [Scroll] First scroll 완료: 3484.3ms 동안 스크롤
[+10738.6ms] [Hitch] L2: hitch: 17.1 ms/s [Critical], fps: 117.7, frames: 408, dropped: 7
[+10738.6ms] [L2] req: 93 (19.2/s), cancel: 93 (19.2/s), complete: 93 (19.2/s)
[+10738.7ms] [L2] latency avg: 4.4ms, p95: 8.2ms, max: 11.4ms
[+14470.8ms] [Hitch] L3: hitch: 7.1 ms/s [Warning], fps: 117.5, frames: 411, dropped: 3
[+14470.9ms] [L3] req: 96 (25.7/s), cancel: 96 (25.7/s), complete: 96 (25.7/s)
[+14471.0ms] [L3] latency avg: 4.0ms, p95: 7.5ms, max: 15.2ms
[+18024.0ms] [Hitch] L4: hitch: 0.0 ms/s [Good], fps: 119.7, frames: 413, dropped: 0
[+18024.3ms] [L4] req: 93 (26.2/s), cancel: 93 (26.2/s), complete: 93 (26.2/s)
[+18024.5ms] [L4] latency avg: 20.1ms, p95: 123.2ms, max: 150.1ms
```

---

<!-- LOG_ID: XCUITest_00-22_swipe_deleted -->
## [삭제됨] XCUITest swipe (2025-12-24 00:22) - velocity 30000 실패

> velocity 30000 설정 시 L2 스크롤 동작 안 함. 기록 삭제.

---

<!-- LOG_ID: XCUITest_00-22_swipe_original -->
## (참고) 기존 00:22 로그 원본

```
=== PickPhoto Launch Log ===
Date: 2025-12-25 00:22:36
Device: iPhone14,2
============================
[+3.4ms] [Env] Build: Release
[+3.4ms] [Env] LowPowerMode: OFF
[+3.4ms] [Env] PhotosAuth: authorized
[+3.6ms] [Config] deliveryMode: opportunistic
[+3.6ms] [Config] cancelPolicy: prepareForReuse
[+3.6ms] [Config] R2Recovery: disabled
[+101.1ms] [Timing] === 초기 로딩 시작 ===
[+103.2ms] [Timing] viewWillAppear: +2.0ms (초기 진입 - reloadData 스킵)
[+146.9ms] [Timing] C) 첫 레이아웃 완료: +45.7ms
[+183.3ms] [Preload] DISK HIT: C686BEAA...
[+190.8ms] [Preload] DISK HIT: EFCDAD54...
[+196.6ms] [Preload] DISK HIT: B72E5653...
[+202.8ms] [Preload] DISK HIT: 6A03D5D4...
[+207.3ms] [Preload] DISK HIT: EB31907C...
[+211.8ms] [Preload] DISK HIT: F3EC02C8...
[+217.3ms] [Preload] DISK HIT: 0655447F...
[+222.4ms] [Preload] DISK HIT: E5D2A7F7...
[+227.0ms] [Preload] DISK HIT: 61F383D4...
[+231.5ms] [Preload] DISK HIT: 70ACEA88...
[+236.2ms] [Preload] DISK HIT: 6907A28F...
[+240.9ms] [Preload] DISK HIT: C2E6BD92...
[+240.9ms] [Timing] E0) finishInitialDisplay 시작: +139.7ms (reason: preload complete, preloaded: 12/12)
[+246.7ms] [Timing] D) 첫 셀 표시: +145.5ms (indexPath: [0, 0])
[+251.3ms] [Pipeline] requestImage #10: +247.7ms
[+257.4ms] [Timing] E1) reloadData+layout 완료: +156.3ms (E0→E1: 16.6ms)
[+258.5ms] [Pipeline] requestImage #20: +254.9ms
[+267.5ms] [Timing] E2) scrollToItem+layout 완료: +166.4ms (E1→E2: 10.1ms)
[+267.7ms] [Timing] === 초기 로딩 완료: +166.4ms (E0→E1: 16.6ms, E1→E2: 10.1ms) ===
[+267.7ms] [Timing] 최종 통계: cellForItemAt 36회, 총 18.2ms, 평균 0.50ms
[+267.7ms] [Initial Load] req: 24 (90.9/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+267.7ms] [Initial Load] degraded: 24, maxInFlight: 24
[+267.7ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+267.8ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+267.8ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+267.8ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+267.8ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+2511.3ms] [Scroll] First scroll 시작: +2409.9ms
[+2522.0ms] [Pipeline] completion #50 도달: +2518.4ms
[+2544.6ms] [Pipeline] requestImage #30: +2541.0ms
[+5945.9ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 119.7 (avg 8.33ms), frames: 411, dropped: 0, longest: 0 (0.0ms)
[+5946.0ms] [L1 First] memHit: 0, memMiss: 102, hitRate: 0.0%
[+5946.1ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+5946.1ms] [L1 First] grayShown: 11, grayResolved: 126, pending: -115
[+5946.3ms] [L1 First] req: 126 (21.2/s), cancel: 84 (14.1/s), complete: 126 (21.2/s)
[+5946.3ms] [L1 First] degraded: 126, maxInFlight: 24
[+5946.4ms] [L1 First] latency avg: 16.6ms, p95: 86.8ms, max: 112.7ms
[+5946.4ms] [L1 First] preheat: 0회, 총 0개 에셋
[+5946.5ms] [Scroll] First scroll 완료: 3435.5ms 동안 스크롤
[+7520.0ms] [Pipeline] requestImage #10: +1573.6ms
[+7578.5ms] [Pipeline] requestImage #20: +1632.1ms
[+7616.1ms] [Pipeline] completion #50 도달: +1669.7ms
[+7645.0ms] [Pipeline] requestImage #30: +1698.5ms
[+11010.1ms] [Hitch] L2 Steady: hitch: 6.9 ms/s [Warning], fps: 117.3 (avg 8.33ms), frames: 422, dropped: 3, longest: 3 (25.0ms)
[+11010.2ms] [L2 Steady] memHit: 0, memMiss: 117, hitRate: 0.0%
[+11010.2ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+11010.2ms] [L2 Steady] grayShown: 10, grayResolved: 117, pending: -107
[+11010.2ms] [L2 Steady] req: 117 (23.1/s), cancel: 117 (23.1/s), complete: 117 (23.1/s)
[+11010.2ms] [L2 Steady] degraded: 117, maxInFlight: 0
[+11010.2ms] [L2 Steady] latency avg: 4.1ms, p95: 6.9ms, max: 10.0ms
[+11010.2ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+11411.8ms] [Pipeline] requestImage #10: +401.5ms
[+11469.8ms] [Pipeline] requestImage #20: +459.6ms
[+11498.7ms] [Pipeline] completion #50 도달: +488.5ms
[+11528.0ms] [Pipeline] requestImage #30: +517.8ms
[+14891.5ms] [Hitch] L2 Steady: hitch: 15.9 ms/s [Critical], fps: 117.9 (avg 8.33ms), frames: 424, dropped: 7, longest: 5 (41.7ms)
[+14891.6ms] [L2 Steady] memHit: 0, memMiss: 117, hitRate: 0.0%
[+14891.6ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+14891.6ms] [L2 Steady] grayShown: 10, grayResolved: 117, pending: -107
[+14891.6ms] [L2 Steady] req: 117 (30.1/s), cancel: 117 (30.1/s), complete: 117 (30.1/s)
[+14891.6ms] [L2 Steady] degraded: 117, maxInFlight: 0
[+14891.6ms] [L2 Steady] latency avg: 3.8ms, p95: 6.7ms, max: 11.7ms
[+14891.7ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+15295.0ms] [Pipeline] requestImage #10: +403.3ms
[+15353.6ms] [Pipeline] requestImage #20: +461.9ms
[+15382.4ms] [Pipeline] completion #50 도달: +490.7ms
[+15411.8ms] [Pipeline] requestImage #30: +520.1ms
[+18746.4ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.7 (avg 8.33ms), frames: 427, dropped: 0, longest: 0 (0.0ms)
[+18746.5ms] [L2 Steady] memHit: 0, memMiss: 117, hitRate: 0.0%
[+18746.5ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+18746.5ms] [L2 Steady] grayShown: 10, grayResolved: 117, pending: -107
[+18746.6ms] [L2 Steady] req: 117 (30.4/s), cancel: 117 (30.4/s), complete: 117 (30.4/s)
[+18746.6ms] [L2 Steady] degraded: 117, maxInFlight: 0
[+18746.6ms] [L2 Steady] latency avg: 3.9ms, p95: 7.4ms, max: 10.1ms
[+18746.6ms] [L2 Steady] preheat: 1회, 총 66개 에셋
```

---

<!-- LOG_ID: AutoScrollTester_00-43_continuous -->
## AutoScrollTester (2025-12-24 00:43) - testAutoScrollTester

```
=== PickPhoto Launch Log ===
Date: 2025-12-25 00:43:51
Device: iPhone14,2
============================
[+4.0ms] [LaunchArgs] didFinishLaunching: count=6
[+4.1ms] [LaunchArgs] --auto-scroll: true
[+4.1ms] [LaunchArgs] ALL: ["/var/containers/Bundle/Application/06B6A20C-C1F5-4160-9DE9-718A69283995/PickPhoto.app/PickPhoto", "--auto-scroll", "--auto-scroll-speed=12000", "--auto-scroll-duration=12", "--auto-scroll-direction=down", "--auto-scroll-boundary=reverse"]
[+5.4ms] [Env] Build: Debug
[+5.4ms] [Env] LowPowerMode: OFF
[+5.4ms] [Env] PhotosAuth: authorized
[+5.6ms] [Config] deliveryMode: opportunistic
[+5.6ms] [Config] cancelPolicy: prepareForReuse
[+5.6ms] [Config] R2Recovery: disabled
[+99.2ms] [Timing] === 초기 로딩 시작 ===
[+101.4ms] [Timing] viewWillAppear: +2.1ms (초기 진입 - reloadData 스킵)
[+104.8ms] [InitialDisplay] 시작: +5.6ms, cellSize=128x128pt
[+110.1ms] [InitialDisplay] 데이터 로드 완료: +10.9ms, 3465장
[+110.2ms] [Preload] 시작: index 3453~3464 (12개), pixelSize=384x384px
[+112.1ms] [MemoryCache] 초기화: countLimit=100, costLimit=50MB
[+112.4ms] [ThumbnailCache] Cache directory: /var/mobile/Containers/Data/Application/AE8724D9-12CB-4823-A838-EF428C5BD648/Library/Caches/Thumbnails
[+112.4ms] [Timing] C) 첫 레이아웃 완료: +13.2ms
[+128.7ms] [LaunchArgs] count=6, contains --auto-scroll: true
[+128.8ms] [AutoScroll] === 시작 ===
[+128.9ms] [AutoScroll] 속도: 12000.0 pt/s, 방향: down, 지속: 12.0초, 경계: reverse
[+128.9ms] [AutoScroll] 프로파일: continuous (일정 속도)
[+128.9ms] [Scroll] First scroll 시작: +29.7ms
[+134.0ms] [Preload] DISK HIT: C686BEAA...
[+137.6ms] [Preload] DISK HIT: EFCDAD54...
[+141.0ms] [Preload] DISK HIT: B72E5653...
[+144.4ms] [Preload] DISK HIT: 6A03D5D4...
[+148.3ms] [Preload] DISK HIT: EB31907C...
[+152.5ms] [Preload] DISK HIT: F3EC02C8...
[+157.3ms] [Preload] DISK HIT: 0655447F...
[+161.2ms] [Preload] DISK HIT: E5D2A7F7...
[+164.7ms] [Preload] DISK HIT: 61F383D4...
[+168.0ms] [Preload] DISK HIT: 70ACEA88...
[+171.1ms] [Preload] DISK HIT: 6907A28F...
[+174.7ms] [Preload] DISK HIT: C2E6BD92...
[+174.8ms] [Timing] E0) finishInitialDisplay 시작: +75.5ms (reason: preload complete, preloaded: 12/12)
[+180.6ms] [Timing] D) 첫 셀 표시: +81.4ms (indexPath: [0, 0])
[+185.4ms] [Pipeline] requestImage #10: +179.8ms
[+192.2ms] [Timing] E1) reloadData+layout 완료: +93.0ms (E0→E1: 17.4ms)
[+193.2ms] [Pipeline] requestImage #20: +187.6ms
[+197.8ms] [Pipeline] requestImage #30: +192.3ms
[+197.8ms] [ThumbnailCache] Cache size OK: 99MB / 100MB (1331 files)
[+203.2ms] [Timing] E2) scrollToItem+layout 완료: +104.0ms (E1→E2: 11.0ms)
[+203.3ms] [Timing] === 초기 로딩 완료: +104.0ms (E0→E1: 17.4ms, E1→E2: 11.0ms) ===
[+203.4ms] [Timing] 최종 통계: cellForItemAt 36회, 총 20.1ms, 평균 0.56ms
[+203.4ms] [Initial Load] req: 36 (182.0/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+203.4ms] [Initial Load] degraded: 36, maxInFlight: 36
[+203.4ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+203.4ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+203.4ms] [Initial Load] memHit: 0, memMiss: 48, hitRate: 0.0%
[+203.4ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+203.4ms] [Initial Load] grayShown: 36, grayResolved: 0, pending: 36
[+206.3ms] [Pipeline] completion #50 도달: +200.7ms
[+12203.6ms] [AutoScroll] === 중지: 12.00초 경과 ===
[+12305.2ms] [Hitch] L1 First: hitch: 3.5 ms/s [Good], fps: 119.5 (avg 8.33ms), frames: 1455, dropped: 5, longest: 3 (25.0ms)
[+12305.3ms] [L1 First] memHit: 0, memMiss: 3321, hitRate: 0.0%
[+12305.4ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+12305.4ms] [L1 First] grayShown: 3321, grayResolved: 3357, pending: -36
[+12330.5ms] [L1 First] req: 3357 (272.9/s), cancel: 3321 (270.0/s), complete: 3357 (272.9/s)
[+12330.5ms] [L1 First] degraded: 3357, maxInFlight: 36
[+12330.6ms] [L1 First] latency avg: 4.0ms, p95: 5.7ms, max: 37.9ms
[+12330.6ms] [L1 First] preheat: 0회, 총 0개 에셋
[+12330.6ms] [Scroll] First scroll 완료: 12202.0ms 동안 스크롤
```

---

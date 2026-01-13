# 썸네일 고해상도 전환 원본 로그 #1

원본 로그 데이터를 저장하는 문서입니다.

> **요약은 \`260103thumbnailLog.md\`에 있습니다.**

---

<!-- LOG_ID: 260103_phase1_1 -->
## Phase 1 테스트 1 (2026-01-03 23:11)

```
=== PickPhoto Launch Log ===
Date: 2026-01-03 23:11:35
Device: iPhone14,2
============================
[+6.4ms] [LaunchArgs] didFinishLaunching: count=1
[+6.5ms] [LaunchArgs] --auto-scroll: false
[+7.8ms] [Env] Build: Release
[+7.8ms] [Env] LowPowerMode: OFF
[+7.8ms] [Env] PhotosAuth: authorized
[+8.0ms] [Config] deliveryMode: opportunistic
[+8.0ms] [Config] cancelPolicy: prepareForReuse
[+8.0ms] [Config] R2Recovery: disabled
[+68.2ms] [Timing] === 초기 로딩 시작 ===
[+98.9ms] [Timing] viewWillAppear: +30.6ms (초기 진입 - reloadData 스킵)
[+152.4ms] [Timing] C) 첫 레이아웃 완료: +84.2ms
[+170.3ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+171.7ms] [Preload] DISK HIT: F29EC2F9...
[+175.4ms] [Preload] DISK HIT: F0146B79...
[+178.7ms] [Preload] DISK HIT: 261056EB...
[+182.1ms] [Preload] DISK HIT: D10201EA...
[+186.7ms] [Preload] DISK HIT: 5FEA5EE7...
[+190.0ms] [Preload] DISK HIT: 7F2BACF6...
[+193.6ms] [Preload] DISK HIT: 5AE38379...
[+197.8ms] [Preload] DISK HIT: 2CD47CFB...
[+201.4ms] [Preload] DISK HIT: 48EC0DA1...
[+204.7ms] [Preload] DISK HIT: E0FEC1AD...
[+208.1ms] [Preload] DISK HIT: 82E65101...
[+211.5ms] [Preload] DISK HIT: 0EBF73ED...
[+211.6ms] [Timing] E0) finishInitialDisplay 시작: +143.3ms (reason: preload complete, preloaded: 12/12)
[+216.7ms] [Thumb:Req] #1 target=384x384px, fullSize=true
[+216.9ms] [Timing] D) 첫 셀 표시: +148.6ms (indexPath: [0, 0])
[+217.5ms] [Thumb:Req] #2 target=384x384px, fullSize=true
[+217.9ms] [Thumb:Req] #3 target=384x384px, fullSize=true
[+218.0ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+218.1ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+218.2ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+218.3ms] [Thumb:Req] #4 target=384x384px, fullSize=true
[+218.6ms] [Thumb:Req] #5 target=384x384px, fullSize=true
[+220.4ms] [Thumb:Req] #10 target=384x384px, fullSize=true
[+220.4ms] [Pipeline] requestImage #10: +212.4ms
[+227.8ms] [Timing] E1) reloadData+layout 완료: +159.6ms (E0→E1: 16.3ms)
[+229.0ms] [Thumb:Req] #20 target=384x384px, fullSize=true
[+229.0ms] [Pipeline] requestImage #20: +221.0ms
[+233.0ms] [Thumb:Req] #30 target=384x384px, fullSize=true
[+234.0ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+240.0ms] [Timing] E2) scrollToItem+layout 완료: +171.8ms (E1→E2: 12.2ms)
[+240.1ms] [Timing] === 초기 로딩 완료: +171.8ms (E0→E1: 16.3ms, E1→E2: 12.2ms) ===
[+240.1ms] [Timing] 최종 통계: cellForItemAt 36회, 총 17.7ms, 평균 0.49ms
[+240.1ms] [Initial Load] req: 24 (103.4/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+240.1ms] [Initial Load] degraded: 24, maxInFlight: 24
[+240.1ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+240.1ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+240.1ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+240.1ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+240.1ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+242.0ms] [Thumb:Res] #1 img=120x90px, target=384x384px, degraded=true
[+242.0ms] [Thumb:Res] #2 img=120x90px, target=384x384px, degraded=true
[+242.0ms] [Thumb:Res] #3 img=120x90px, target=384x384px, degraded=true
[+242.1ms] [Thumb:Res] #4 img=120x90px, target=384x384px, degraded=true
[+242.1ms] [Thumb:Res] #5 img=90x120px, target=384x384px, degraded=true
[+242.1ms] [Thumb:Res] #10 img=120x90px, target=384x384px, degraded=true
[+242.2ms] [Thumb:Res] #20 img=90x120px, target=384x384px, degraded=true
[+258.3ms] [Thumb:Res] #30 img=384x512px, target=384x384px, degraded=false
[+297.1ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+297.2ms] [Thumb:Res] #40 img=384x512px, target=384x384px, degraded=false
[+1242.6ms] [Scroll] First scroll 시작: +1174.1ms
[+1277.0ms] [Pipeline] completion #50 도달: +1269.0ms
[+1279.0ms] [Thumb:Res] #50 img=90x120px, target=192x192px, degraded=true
[+1279.7ms] [Thumb:Req] #40 target=192x192px, fullSize=false
[+1293.9ms] [Pipeline] requestImage #30: +1285.9ms
[+1299.2ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+1299.3ms] [Thumb:Res] #60 img=192x256px, target=192x192px, degraded=false
[+1339.1ms] [Thumb:Res] #70 img=192x256px, target=192x192px, degraded=false
[+1358.7ms] [Thumb:Req] #50 target=192x192px, fullSize=false
[+1389.4ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+1389.6ms] [Thumb:Res] #80 img=192x256px, target=192x192px, degraded=false
[+1429.1ms] [Thumb:Res] #90 img=192x256px, target=192x192px, degraded=false
[+1458.8ms] [Thumb:Req] #60 target=192x192px, fullSize=false
[+1487.9ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+1488.0ms] [Thumb:Res] #100 img=192x256px, target=192x192px, degraded=false
[+1784.7ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 118.1 (avg 8.33ms), frames: 64, dropped: 0, longest: 0 (0.0ms)
[+1784.8ms] [L1 First] memHit: 0, memMiss: 30, hitRate: 0.0%
[+1784.9ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+1784.9ms] [L1 First] grayShown: 2, grayResolved: 54, pending: -52
[+1784.9ms] [L1 First] req: 54 (30.4/s), cancel: 18 (10.1/s), complete: 54 (30.4/s)
[+1785.0ms] [L1 First] degraded: 54, maxInFlight: 24
[+1785.0ms] [L1 First] latency avg: 31.1ms, p95: 114.9ms, max: 118.5ms
[+1785.0ms] [L1 First] preheat: 0회, 총 0개 에셋
[+1785.1ms] [Scroll] First scroll 완료: 542.7ms 동안 스크롤
[+1785.6ms] [R2:Timing] seq=2, velocity=3155pt/s, 디바운스=50ms
[+1786.5ms] [Pipeline] requestImage #10: +1.5ms
[+1786.9ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+1786.9ms] [R2] seq=2, visible=21, upgraded=15
[+1787.9ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+1788.1ms] [Pipeline] #3 target=384x384px → img=68x120px (18%), degraded=true
[+1995.6ms] [Thumb:Check] seq=2, t=0.2s, velocity=3155, underSized=12/21
[+2035.4ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+2409.6ms] [Thumb:Check] seq=2, t=0.6s, velocity=3155, underSized=0/21
[+3435.8ms] [Thumb:Res] #110 img=192x256px, target=192x192px, degraded=false
[+3476.8ms] [Thumb:Req] #70 target=192x192px, fullSize=false
[+3485.8ms] [Pipeline] requestImage #20: +1700.7ms
[+3492.9ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+3499.1ms] [Thumb:Res] #120 img=192x256px, target=192x192px, degraded=false
[+3574.4ms] [Pipeline] completion #50 도달: +1789.3ms
[+3582.7ms] [Thumb:Res] #130 img=192x256px, target=192x192px, degraded=false
[+3743.8ms] [Thumb:Req] #80 target=192x192px, fullSize=false
[+3751.8ms] [Pipeline] requestImage #30: +1966.7ms
[+3757.5ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+3943.2ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.1 (avg 8.33ms), frames: 65, dropped: 0, longest: 0 (0.0ms)
[+3943.3ms] [L2 Steady] memHit: 0, memMiss: 15, hitRate: 0.0%
[+3943.3ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+3943.3ms] [L2 Steady] grayShown: 0, grayResolved: 15, pending: -15
[+3943.4ms] [L2 Steady] req: 30 (13.9/s), cancel: 9 (4.2/s), complete: 30 (13.9/s)
[+3943.4ms] [L2 Steady] degraded: 30, maxInFlight: 15
[+3943.4ms] [L2 Steady] latency avg: 118.7ms, p95: 288.7ms, max: 439.5ms
[+3943.5ms] [L2 Steady] preheat: 1회, 총 54개 에셋
[+3943.9ms] [R2:Timing] seq=4, velocity=2930pt/s, 디바운스=50ms
[+3944.6ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+3944.7ms] [Pipeline] requestImage #10: +1.2ms
[+3944.9ms] [Pipeline] #3 target=384x384px → img=384x683px (100%), degraded=false
[+3945.3ms] [R2] seq=4, visible=24, upgraded=15
[+3946.0ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+4151.4ms] [Thumb:Check] seq=4, t=0.2s, velocity=2930, underSized=0/24
[+4575.7ms] [Thumb:Check] seq=4, t=0.6s, velocity=2930, underSized=0/24
[+5153.1ms] [Thumb:Res] #140 img=192x256px, target=192x192px, degraded=false
[+5160.7ms] [Pipeline] #20 target=192x192px → img=90x120px (47%), degraded=true
[+5193.5ms] [Pipeline] requestImage #20: +1250.0ms
[+5206.5ms] [Thumb:Res] #150 img=192x256px, target=192x192px, degraded=false
[+5234.3ms] [Thumb:Req] #90 target=192x192px, fullSize=false
[+5273.6ms] [Thumb:Res] #160 img=192x256px, target=192x192px, degraded=false
[+5345.9ms] [Pipeline] #40 target=192x192px → img=90x120px (47%), degraded=true
[+5359.7ms] [Pipeline] requestImage #30: +1416.1ms
[+5659.9ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.2 (avg 8.33ms), frames: 69, dropped: 0, longest: 0 (0.0ms)
[+5660.0ms] [L2 Steady] memHit: 0, memMiss: 15, hitRate: 0.0%
[+5660.0ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+5660.1ms] [L2 Steady] grayShown: 0, grayResolved: 15, pending: -15
[+5660.1ms] [L2 Steady] req: 30 (17.5/s), cancel: 15 (8.7/s), complete: 30 (17.5/s)
[+5660.1ms] [L2 Steady] degraded: 15, maxInFlight: 11
[+5660.2ms] [L2 Steady] latency avg: 3.4ms, p95: 7.2ms, max: 8.0ms
[+5660.2ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+5660.6ms] [R2:Timing] seq=6, velocity=3834pt/s, 디바운스=50ms
[+5661.3ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+5661.4ms] [Pipeline] requestImage #10: +1.2ms
[+5661.9ms] [R2] seq=6, visible=24, upgraded=15
[+5662.2ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+5662.6ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+5867.7ms] [Thumb:Check] seq=6, t=0.2s, velocity=3834, underSized=0/24
[+6276.6ms] [Thumb:Check] seq=6, t=0.6s, velocity=3834, underSized=0/24
[+7204.9ms] [Thumb:Res] #170 img=192x256px, target=192x192px, degraded=false
[+7212.4ms] [Pipeline] #20 target=192x192px → img=90x120px (47%), degraded=true
[+7227.5ms] [Thumb:Req] #100 target=192x192px, fullSize=false
[+7235.1ms] [Pipeline] requestImage #20: +1574.9ms
[+7248.7ms] [Thumb:Res] #180 img=192x256px, target=192x192px, degraded=false
[+7297.5ms] [Thumb:Res] #190 img=192x256px, target=192x192px, degraded=false
[+7318.7ms] [Pipeline] #40 target=192x192px → img=90x120px (47%), degraded=true
[+7326.4ms] [Thumb:Req] #110 target=192x192px, fullSize=false
[+7334.6ms] [Pipeline] requestImage #30: +1674.3ms
[+7347.6ms] [Thumb:Res] #200 img=192x256px, target=192x192px, degraded=false
[+7359.8ms] [Pipeline] completion #50 도달: +1699.5ms
[+7397.6ms] [Thumb:Res] #210 img=256x192px, target=192x192px, degraded=false
[+7410.0ms] [Pipeline] #60 target=192x192px → img=68x120px (35%), degraded=true
[+7417.6ms] [Thumb:Req] #120 target=192x192px, fullSize=false
[+7446.8ms] [Thumb:Res] #220 img=192x256px, target=192x192px, degraded=false
[+7495.1ms] [Thumb:Res] #230 img=192x256px, target=192x192px, degraded=false
[+7510.6ms] [Pipeline] #80 target=192x192px → img=68x120px (35%), degraded=true
[+7517.4ms] [Thumb:Req] #130 target=192x192px, fullSize=false
[+7539.5ms] [Thumb:Res] #240 img=192x341px, target=192x192px, degraded=false
[+7597.3ms] [Thumb:Res] #250 img=192x341px, target=192x192px, degraded=false
[+7617.4ms] [Pipeline] #100 target=192x192px → img=120x68px (62%), degraded=true
[+7625.4ms] [Thumb:Req] #140 target=192x192px, fullSize=false
[+7653.9ms] [Thumb:Res] #260 img=256x192px, target=192x192px, degraded=false
[+7731.2ms] [Thumb:Res] #270 img=256x192px, target=192x192px, degraded=false
[+7851.8ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+7859.7ms] [Thumb:Req] #150 target=192x192px, fullSize=false
[+8193.4ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.0 (avg 8.33ms), frames: 123, dropped: 0, longest: 0 (0.0ms)
[+8193.5ms] [L2 Steady] memHit: 0, memMiss: 54, hitRate: 0.0%
[+8193.6ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+8193.6ms] [L2 Steady] grayShown: 0, grayResolved: 54, pending: -54
[+8193.7ms] [L2 Steady] req: 69 (27.2/s), cancel: 54 (21.3/s), complete: 69 (27.2/s)
[+8193.7ms] [L2 Steady] degraded: 54, maxInFlight: 14
[+8193.8ms] [L2 Steady] latency avg: 4.2ms, p95: 7.2ms, max: 10.5ms
[+8193.8ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+8194.2ms] [R2:Timing] seq=9, velocity=7019pt/s, 디바운스=50ms
[+8194.9ms] [Pipeline] requestImage #10: +1.1ms
[+8195.4ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+8195.4ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+8195.5ms] [Pipeline] requestImage #20: +1.7ms
[+8195.7ms] [R2] seq=9, visible=24, upgraded=24
[+8196.2ms] [Pipeline] #3 target=384x384px → img=68x120px (18%), degraded=true
[+8201.7ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+8403.0ms] [Thumb:Check] seq=9, t=0.2s, velocity=7019, underSized=19/24
[+8580.3ms] [Pipeline] #40 target=384x384px → img=384x683px (100%), degraded=false
[+8825.4ms] [Thumb:Check] seq=9, t=0.6s, velocity=7019, underSized=0/24
[+9686.9ms] [Pipeline] completion #50 도달: +1493.1ms
[+9694.5ms] [Thumb:Res] #280 img=192x256px, target=192x192px, degraded=false
[+9726.6ms] [Pipeline] requestImage #30: +1532.7ms
[+9731.5ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+9741.3ms] [Thumb:Res] #290 img=192x341px, target=192x192px, degraded=false
[+9768.6ms] [Thumb:Req] #160 target=192x192px, fullSize=false
[+9789.1ms] [Thumb:Res] #300 img=192x341px, target=192x192px, degraded=false
[+9831.9ms] [Pipeline] #80 target=192x192px → img=192x341px (100%), degraded=false
[+9837.1ms] [Thumb:Res] #310 img=256x192px, target=192x192px, degraded=false
[+9859.5ms] [Thumb:Req] #170 target=192x192px, fullSize=false
[+9880.1ms] [Thumb:Res] #320 img=192x256px, target=192x192px, degraded=false
[+9920.8ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+9928.8ms] [Thumb:Res] #330 img=192x256px, target=192x192px, degraded=false
[+9950.7ms] [Thumb:Req] #180 target=192x192px, fullSize=false
[+9970.6ms] [Thumb:Res] #340 img=192x256px, target=192x192px, degraded=false
[+10013.0ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+10021.3ms] [Thumb:Res] #350 img=192x256px, target=192x192px, degraded=false
[+10051.5ms] [Thumb:Req] #190 target=192x192px, fullSize=false
[+10146.2ms] [Thumb:Res] #360 img=90x120px, target=192x192px, degraded=true
[+10468.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.7 (avg 8.33ms), frames: 98, dropped: 0, longest: 0 (0.0ms)
[+10468.7ms] [L2 Steady] memHit: 0, memMiss: 45, hitRate: 0.0%
[+10468.7ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+10468.7ms] [L2 Steady] grayShown: 0, grayResolved: 45, pending: -45
[+10468.8ms] [L2 Steady] req: 69 (30.3/s), cancel: 45 (19.8/s), complete: 69 (30.3/s)
[+10468.8ms] [L2 Steady] degraded: 69, maxInFlight: 24
[+10468.9ms] [L2 Steady] latency avg: 112.8ms, p95: 398.9ms, max: 405.6ms
[+10468.9ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+10469.3ms] [R2:Timing] seq=12, velocity=7768pt/s, 디바운스=50ms
[+10470.0ms] [Pipeline] requestImage #10: +1.1ms
[+10470.4ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+10470.6ms] [Pipeline] requestImage #20: +1.7ms
[+10470.9ms] [R2] seq=12, visible=24, upgraded=24
[+10471.2ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+10471.5ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+10476.4ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+10676.9ms] [Thumb:Check] seq=12, t=0.2s, velocity=7768, underSized=9/24
[+10709.4ms] [Pipeline] #40 target=384x384px → img=384x683px (100%), degraded=false
[+11077.1ms] [Thumb:Check] seq=12, t=0.6s, velocity=7768, underSized=0/24
[+12013.4ms] [Pipeline] completion #50 도달: +1544.4ms
[+12020.3ms] [Thumb:Res] #370 img=192x256px, target=192x192px, degraded=false
[+12043.3ms] [Thumb:Req] #200 target=192x192px, fullSize=false
[+12051.9ms] [Pipeline] requestImage #30: +1583.0ms
[+12056.9ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+12077.8ms] [Thumb:Res] #380 img=192x341px, target=192x192px, degraded=false
[+12112.7ms] [Thumb:Res] #390 img=256x192px, target=192x192px, degraded=false
[+12142.5ms] [Thumb:Req] #210 target=192x192px, fullSize=false
[+12154.9ms] [Pipeline] #80 target=192x192px → img=256x192px (133%), degraded=false
[+12163.6ms] [Thumb:Res] #400 img=256x192px, target=192x192px, degraded=false
[+12214.3ms] [Thumb:Res] #410 img=192x256px, target=192x192px, degraded=false
[+12234.4ms] [Thumb:Req] #220 target=192x192px, fullSize=false
[+12246.1ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+12254.5ms] [Thumb:Res] #420 img=192x256px, target=192x192px, degraded=false
[+12305.9ms] [Thumb:Res] #430 img=192x256px, target=192x192px, degraded=false
[+12334.4ms] [Thumb:Req] #230 target=192x192px, fullSize=false
[+12349.7ms] [Pipeline] #120 target=192x192px → img=192x341px (100%), degraded=false
[+12354.5ms] [Thumb:Res] #440 img=192x256px, target=192x192px, degraded=false
[+12405.7ms] [Thumb:Res] #450 img=192x256px, target=192x192px, degraded=false
[+12435.2ms] [Thumb:Req] #240 target=192x192px, fullSize=false
[+12457.7ms] [Pipeline] #140 target=192x192px → img=192x341px (100%), degraded=false
[+12464.4ms] [Thumb:Res] #460 img=192x341px, target=192x192px, degraded=false
[+12860.4ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 105, dropped: 0, longest: 0 (0.0ms)
[+12860.5ms] [L2 Steady] memHit: 0, memMiss: 51, hitRate: 0.0%
[+12860.6ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+12860.6ms] [L2 Steady] grayShown: 0, grayResolved: 51, pending: -51
[+12860.6ms] [L2 Steady] req: 75 (31.4/s), cancel: 51 (21.3/s), complete: 75 (31.4/s)
[+12860.7ms] [L2 Steady] degraded: 75, maxInFlight: 24
[+12860.7ms] [L2 Steady] latency avg: 64.4ms, p95: 292.3ms, max: 302.9ms
[+12860.7ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+12861.1ms] [R2:Timing] seq=15, velocity=7502pt/s, 디바운스=50ms
[+12861.8ms] [Pipeline] requestImage #10: +1.1ms
[+12862.3ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+12862.4ms] [Pipeline] requestImage #20: +1.7ms
[+12862.5ms] [R2] seq=15, visible=21, upgraded=21
[+12863.2ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+12863.4ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+12868.3ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+13070.1ms] [Thumb:Check] seq=15, t=0.2s, velocity=7502, underSized=13/21
[+13195.9ms] [Pipeline] #40 target=384x384px → img=512x384px (133%), degraded=false
[+13492.4ms] [Thumb:Check] seq=15, t=0.6s, velocity=7502, underSized=0/21
[+14346.6ms] [Thumb:Res] #470 img=90x120px, target=192x192px, degraded=true
[+14369.0ms] [Thumb:Req] #250 target=192x192px, fullSize=false
[+14378.5ms] [Pipeline] completion #50 도달: +1517.7ms
[+14390.0ms] [Thumb:Res] #480 img=192x256px, target=192x192px, degraded=false
[+14409.4ms] [Pipeline] requestImage #30: +1548.6ms
[+14412.7ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+14438.2ms] [Thumb:Res] #490 img=192x256px, target=192x192px, degraded=false
[+14460.7ms] [Thumb:Req] #260 target=192x192px, fullSize=false
[+14479.5ms] [Thumb:Res] #500 img=192x256px, target=192x192px, degraded=false
[+14514.7ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+14531.0ms] [Thumb:Res] #510 img=192x256px, target=192x192px, degraded=false
[+14550.9ms] [Thumb:Req] #270 target=192x192px, fullSize=false
[+14571.4ms] [Thumb:Res] #520 img=192x256px, target=192x192px, degraded=false
[+14624.2ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+14638.6ms] [Thumb:Res] #530 img=192x256px, target=192x192px, degraded=false
[+14659.5ms] [Thumb:Req] #280 target=192x192px, fullSize=false
[+14679.7ms] [Thumb:Res] #540 img=192x256px, target=192x192px, degraded=false
[+14704.7ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+14713.5ms] [Thumb:Res] #550 img=256x192px, target=192x192px, degraded=false
[+14734.6ms] [Thumb:Req] #290 target=192x192px, fullSize=false
[+14746.8ms] [Thumb:Res] #560 img=256x192px, target=192x192px, degraded=false
[+14778.3ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+14795.9ms] [Thumb:Res] #570 img=256x192px, target=192x192px, degraded=false
[+14817.6ms] [Thumb:Req] #300 target=192x192px, fullSize=false
[+14830.5ms] [Thumb:Res] #580 img=192x256px, target=192x192px, degraded=false
[+14871.5ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+14888.5ms] [Thumb:Res] #590 img=192x256px, target=192x192px, degraded=false
[+14901.7ms] [Thumb:Req] #310 target=192x192px, fullSize=false
[+14921.2ms] [Thumb:Res] #600 img=192x256px, target=192x192px, degraded=false
[+14952.1ms] [Pipeline] #180 target=192x192px → img=90x120px (47%), degraded=true
[+14963.1ms] [Thumb:Res] #610 img=192x256px, target=192x192px, degraded=false
[+14976.5ms] [Thumb:Req] #320 target=192x192px, fullSize=false
[+14998.4ms] [Thumb:Res] #620 img=192x341px, target=192x192px, degraded=false
[+15023.1ms] [Pipeline] #200 target=192x192px → img=192x341px (100%), degraded=false
[+15039.2ms] [Thumb:Res] #630 img=192x341px, target=192x192px, degraded=false
[+15067.7ms] [Thumb:Req] #330 target=192x192px, fullSize=false
[+15088.9ms] [Thumb:Res] #640 img=192x256px, target=192x192px, degraded=false
[+15129.8ms] [Pipeline] #220 target=192x192px → img=192x256px (100%), degraded=false
[+15138.8ms] [Thumb:Res] #650 img=192x256px, target=192x192px, degraded=false
[+15150.9ms] [Thumb:Req] #340 target=192x192px, fullSize=false
[+15155.6ms] [Thumb:Res] #660 img=192x256px, target=192x192px, degraded=false
[+15164.0ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+15168.9ms] [Thumb:Res] #670 img=90x120px, target=192x192px, degraded=true
[+15176.6ms] [Thumb:Req] #350 target=192x192px, fullSize=false
[+15188.4ms] [Thumb:Res] #680 img=192x256px, target=192x192px, degraded=false
[+15201.5ms] [Pipeline] #260 target=192x192px → img=90x120px (47%), degraded=true
[+15205.4ms] [Thumb:Res] #690 img=192x256px, target=192x192px, degraded=false
[+15217.7ms] [Thumb:Req] #360 target=192x192px, fullSize=false
[+15226.8ms] [Thumb:Res] #700 img=90x120px, target=192x192px, degraded=true
[+15234.6ms] [Pipeline] #280 target=192x192px → img=120x90px (62%), degraded=true
[+15238.8ms] [Thumb:Res] #710 img=256x192px, target=192x192px, degraded=false
[+15259.4ms] [Thumb:Req] #370 target=192x192px, fullSize=false
[+15264.3ms] [Thumb:Res] #720 img=256x192px, target=192x192px, degraded=false
[+15276.7ms] [Pipeline] #300 target=192x192px → img=90x120px (47%), degraded=true
[+15284.9ms] [Thumb:Res] #730 img=90x120px, target=192x192px, degraded=true
[+15293.0ms] [Thumb:Req] #380 target=192x192px, fullSize=false
[+15304.9ms] [Thumb:Res] #740 img=256x192px, target=192x192px, degraded=false
[+15326.2ms] [Pipeline] #320 target=192x192px → img=120x90px (62%), degraded=true
[+15330.2ms] [Thumb:Res] #750 img=256x192px, target=192x192px, degraded=false
[+15342.6ms] [Thumb:Req] #390 target=192x192px, fullSize=false
[+15354.3ms] [Thumb:Res] #760 img=192x256px, target=192x192px, degraded=false
[+15370.9ms] [Pipeline] #340 target=192x192px → img=192x256px (100%), degraded=false
[+15458.5ms] [Thumb:Res] #770 img=192x256px, target=192x192px, degraded=false
[+15484.7ms] [Thumb:Req] #400 target=192x192px, fullSize=false
[+15506.7ms] [Thumb:Res] #780 img=192x256px, target=192x192px, degraded=false
[+15531.0ms] [Pipeline] #360 target=192x192px → img=192x256px (100%), degraded=false
[+15545.8ms] [Thumb:Res] #790 img=192x256px, target=192x192px, degraded=false
[+15702.4ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.2 (avg 8.33ms), frames: 166, dropped: 0, longest: 0 (0.0ms)
[+15702.5ms] [L2 Steady] memHit: 0, memMiss: 162, hitRate: 0.0%
[+15702.5ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+15702.5ms] [L2 Steady] grayShown: 43, grayResolved: 162, pending: -119
[+15702.6ms] [L2 Steady] req: 183 (64.4/s), cancel: 162 (57.0/s), complete: 183 (64.4/s)
[+15702.7ms] [L2 Steady] degraded: 183, maxInFlight: 21
[+15702.7ms] [L2 Steady] latency avg: 30.2ms, p95: 298.6ms, max: 341.8ms
[+15702.7ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+15703.1ms] [R2:Timing] seq=21, velocity=13574pt/s, 디바운스=50ms
[+15703.8ms] [Pipeline] requestImage #10: +1.0ms
[+15704.2ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+15704.2ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+15704.4ms] [Pipeline] requestImage #20: +1.6ms
[+15704.5ms] [R2] seq=21, visible=21, upgraded=21
[+15704.9ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+15710.5ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+15910.6ms] [Thumb:Check] seq=21, t=0.2s, velocity=13574, underSized=10/21
[+16044.6ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+16326.0ms] [Thumb:Check] seq=21, t=0.6s, velocity=13574, underSized=0/21
[+16877.8ms] [Thumb:Req] #410 target=192x192px, fullSize=false
[+16911.0ms] [Pipeline] completion #50 도달: +1208.2ms
[+16912.0ms] [Thumb:Res] #800 img=192x256px, target=192x192px, degraded=false
[+16943.8ms] [Pipeline] requestImage #30: +1241.1ms
[+16948.3ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+16948.4ms] [Thumb:Res] #810 img=192x256px, target=192x192px, degraded=false
[+16976.3ms] [Thumb:Req] #420 target=192x192px, fullSize=false
[+16997.1ms] [Thumb:Res] #820 img=192x256px, target=192x192px, degraded=false
[+17046.5ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+17046.6ms] [Thumb:Res] #830 img=192x256px, target=192x192px, degraded=false
[+17077.6ms] [Thumb:Req] #430 target=192x192px, fullSize=false
[+17124.4ms] [Thumb:Res] #840 img=192x256px, target=192x192px, degraded=false
[+17171.8ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+17171.9ms] [Thumb:Res] #850 img=192x256px, target=192x192px, degraded=false
[+17193.0ms] [Thumb:Req] #440 target=192x192px, fullSize=false
[+17223.2ms] [Thumb:Res] #860 img=192x256px, target=192x192px, degraded=false
[+17263.7ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+17263.8ms] [Thumb:Res] #870 img=192x256px, target=192x192px, degraded=false
[+17284.7ms] [Thumb:Req] #450 target=192x192px, fullSize=false
[+17313.1ms] [Thumb:Res] #880 img=192x256px, target=192x192px, degraded=false
[+17382.3ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+17382.4ms] [Thumb:Res] #890 img=192x256px, target=192x192px, degraded=false
[+17409.8ms] [Thumb:Req] #460 target=192x192px, fullSize=false
[+17431.5ms] [Thumb:Res] #900 img=192x256px, target=192x192px, degraded=false
[+17471.4ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+17471.5ms] [Thumb:Res] #910 img=192x256px, target=192x192px, degraded=false
[+17502.2ms] [Thumb:Req] #470 target=192x192px, fullSize=false
[+17523.6ms] [Thumb:Res] #920 img=192x256px, target=192x192px, degraded=false
[+17564.3ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+17564.4ms] [Thumb:Res] #930 img=192x256px, target=192x192px, degraded=false
[+17593.1ms] [Thumb:Req] #480 target=192x192px, fullSize=false
[+17613.9ms] [Thumb:Res] #940 img=192x256px, target=192x192px, degraded=false
[+17665.4ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+17665.5ms] [Thumb:Res] #950 img=192x256px, target=192x192px, degraded=false
[+17684.6ms] [Thumb:Req] #490 target=192x192px, fullSize=false
[+17705.9ms] [Thumb:Res] #960 img=192x256px, target=192x192px, degraded=false
[+17763.2ms] [Pipeline] #220 target=192x192px → img=192x256px (100%), degraded=false
[+17763.2ms] [Thumb:Res] #970 img=192x256px, target=192x192px, degraded=false
[+17793.1ms] [Thumb:Req] #500 target=192x192px, fullSize=false
[+17822.6ms] [Thumb:Res] #980 img=256x192px, target=192x192px, degraded=false
[+17897.9ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+17897.9ms] [Thumb:Res] #990 img=192x256px, target=192x192px, degraded=false
[+17927.1ms] [Thumb:Req] #510 target=192x192px, fullSize=false
[+17952.1ms] [Thumb:Res] #1000 img=90x120px, target=192x192px, degraded=true
[+17965.6ms] [Pipeline] #260 target=192x192px → img=192x341px (100%), degraded=false
[+17965.6ms] [Thumb:Res] #1010 img=192x341px, target=192x192px, degraded=false
[+17977.2ms] [Thumb:Req] #520 target=192x192px, fullSize=false
[+17988.8ms] [Thumb:Res] #1020 img=192x256px, target=192x192px, degraded=false
[+18001.5ms] [Pipeline] #280 target=192x192px → img=120x90px (62%), degraded=true
[+18002.1ms] [Thumb:Res] #1030 img=120x90px, target=192x192px, degraded=true
[+18010.0ms] [Thumb:Req] #530 target=192x192px, fullSize=false
[+18022.9ms] [Thumb:Res] #1040 img=192x341px, target=192x192px, degraded=false
[+18038.3ms] [Pipeline] #300 target=192x192px → img=192x256px (100%), degraded=false
[+18038.3ms] [Thumb:Res] #1050 img=192x256px, target=192x192px, degraded=false
[+18051.3ms] [Thumb:Req] #540 target=192x192px, fullSize=false
[+18060.3ms] [Thumb:Res] #1060 img=90x120px, target=192x192px, degraded=true
[+18072.1ms] [Pipeline] #320 target=192x192px → img=192x256px (100%), degraded=false
[+18072.1ms] [Thumb:Res] #1070 img=192x256px, target=192x192px, degraded=false
[+18085.2ms] [Thumb:Req] #550 target=192x192px, fullSize=false
[+18096.5ms] [Thumb:Res] #1080 img=192x256px, target=192x192px, degraded=false
[+18118.2ms] [Pipeline] #340 target=192x192px → img=68x120px (35%), degraded=true
[+18118.9ms] [Thumb:Res] #1090 img=68x120px, target=192x192px, degraded=true
[+18126.8ms] [Thumb:Req] #560 target=192x192px, fullSize=false
[+18138.2ms] [Thumb:Res] #1100 img=192x256px, target=192x192px, degraded=false
[+18163.2ms] [Pipeline] #360 target=192x192px → img=192x256px (100%), degraded=false
[+18163.3ms] [Thumb:Res] #1110 img=192x256px, target=192x192px, degraded=false
[+18176.2ms] [Thumb:Req] #570 target=192x192px, fullSize=false
[+18187.9ms] [Thumb:Res] #1120 img=256x192px, target=192x192px, degraded=false
[+18213.1ms] [Pipeline] #380 target=192x192px → img=192x256px (100%), degraded=false
[+18213.2ms] [Thumb:Res] #1130 img=192x256px, target=192x192px, degraded=false
[+18226.7ms] [Thumb:Req] #580 target=192x192px, fullSize=false
[+18245.6ms] [Thumb:Res] #1140 img=192x256px, target=192x192px, degraded=false
[+18271.1ms] [Pipeline] #400 target=192x192px → img=192x256px (100%), degraded=false
[+18271.2ms] [Thumb:Res] #1150 img=192x256px, target=192x192px, degraded=false
[+18284.9ms] [Thumb:Req] #590 target=192x192px, fullSize=false
[+18296.6ms] [Thumb:Res] #1160 img=192x256px, target=192x192px, degraded=false
[+18415.5ms] [Pipeline] #420 target=192x192px → img=192x256px (100%), degraded=false
[+18415.7ms] [Thumb:Res] #1170 img=192x256px, target=192x192px, degraded=false
[+18443.3ms] [Thumb:Req] #600 target=192x192px, fullSize=false
[+18465.4ms] [Thumb:Res] #1180 img=192x256px, target=192x192px, degraded=false
[+18702.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.4 (avg 8.33ms), frames: 222, dropped: 0, longest: 0 (0.0ms)
[+18702.7ms] [L2 Steady] memHit: 0, memMiss: 198, hitRate: 0.0%
[+18702.7ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+18702.7ms] [L2 Steady] grayShown: 44, grayResolved: 198, pending: -154
[+18702.8ms] [L2 Steady] req: 219 (73.0/s), cancel: 198 (66.0/s), complete: 219 (73.0/s)
[+18702.9ms] [L2 Steady] degraded: 219, maxInFlight: 21
[+18702.9ms] [L2 Steady] latency avg: 25.4ms, p95: 206.0ms, max: 351.8ms
[+18702.9ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+18703.4ms] [R2:Timing] seq=27, velocity=15367pt/s, 디바운스=50ms
[+18704.1ms] [Pipeline] requestImage #10: +1.2ms
[+18704.6ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+18704.7ms] [Pipeline] requestImage #20: +1.8ms
[+18705.0ms] [R2] seq=27, visible=24, upgraded=24
[+18705.3ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+18705.9ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+18709.7ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+18897.7ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+18909.8ms] [Thumb:Check] seq=27, t=0.2s, velocity=15367, underSized=5/24
[+19326.3ms] [Thumb:Check] seq=27, t=0.6s, velocity=15367, underSized=0/24
[+19906.3ms] [Pipeline] completion #50 도달: +1203.3ms
[+19906.6ms] [Thumb:Res] #1190 img=90x120px, target=192x192px, degraded=true
[+19927.6ms] [Thumb:Req] #610 target=192x192px, fullSize=false
[+19944.2ms] [Pipeline] requestImage #30: +1241.2ms
[+19949.5ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+19949.7ms] [Thumb:Res] #1200 img=192x256px, target=192x192px, degraded=false
[+19999.0ms] [Thumb:Res] #1210 img=192x341px, target=192x192px, degraded=false
[+20018.4ms] [Thumb:Req] #620 target=192x192px, fullSize=false
[+20046.9ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+20047.0ms] [Thumb:Res] #1220 img=192x256px, target=192x192px, degraded=false
[+20088.7ms] [Thumb:Res] #1230 img=192x256px, target=192x192px, degraded=false
[+20110.2ms] [Thumb:Req] #630 target=192x192px, fullSize=false
[+20166.5ms] [Pipeline] #100 target=192x192px → img=256x192px (133%), degraded=false
[+20166.7ms] [Thumb:Res] #1240 img=256x192px, target=192x192px, degraded=false
[+20214.4ms] [Thumb:Res] #1250 img=192x341px, target=192x192px, degraded=false
[+20234.9ms] [Thumb:Req] #640 target=192x192px, fullSize=false
[+20256.2ms] [Pipeline] #120 target=192x192px → img=192x341px (100%), degraded=false
[+20256.3ms] [Thumb:Res] #1260 img=192x341px, target=192x192px, degraded=false
[+20304.5ms] [Thumb:Res] #1270 img=192x256px, target=192x192px, degraded=false
[+20326.8ms] [Thumb:Req] #650 target=192x192px, fullSize=false
[+20346.9ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+20347.0ms] [Thumb:Res] #1280 img=192x256px, target=192x192px, degraded=false
[+20422.5ms] [Thumb:Res] #1290 img=192x256px, target=192x192px, degraded=false
[+20443.3ms] [Thumb:Req] #660 target=192x192px, fullSize=false
[+20464.8ms] [Pipeline] #160 target=192x192px → img=192x341px (100%), degraded=false
[+20464.9ms] [Thumb:Res] #1300 img=192x341px, target=192x192px, degraded=false
[+20513.5ms] [Thumb:Res] #1310 img=192x256px, target=192x192px, degraded=false
[+20535.0ms] [Thumb:Req] #670 target=192x192px, fullSize=false
[+20554.8ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+20554.8ms] [Thumb:Res] #1320 img=192x256px, target=192x192px, degraded=false
[+20605.1ms] [Thumb:Res] #1330 img=192x256px, target=192x192px, degraded=false
[+20626.6ms] [Thumb:Req] #680 target=192x192px, fullSize=false
[+20646.8ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+20646.9ms] [Thumb:Res] #1340 img=192x256px, target=192x192px, degraded=false
[+20687.9ms] [Thumb:Res] #1350 img=192x256px, target=192x192px, degraded=false
[+20718.5ms] [Thumb:Req] #690 target=192x192px, fullSize=false
[+20738.6ms] [Pipeline] #220 target=192x192px → img=192x256px (100%), degraded=false
[+20738.7ms] [Thumb:Res] #1360 img=192x256px, target=192x192px, degraded=false
[+20796.8ms] [Thumb:Res] #1370 img=192x256px, target=192x192px, degraded=false
[+20818.6ms] [Thumb:Req] #700 target=192x192px, fullSize=false
[+20839.0ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+20839.2ms] [Thumb:Res] #1380 img=192x256px, target=192x192px, degraded=false
[+20888.4ms] [Thumb:Res] #1390 img=192x256px, target=192x192px, degraded=false
[+20909.9ms] [Thumb:Req] #710 target=192x192px, fullSize=false
[+20939.9ms] [Pipeline] #260 target=192x192px → img=256x192px (133%), degraded=false
[+20940.0ms] [Thumb:Res] #1400 img=256x192px, target=192x192px, degraded=false
[+21016.1ms] [Thumb:Res] #1410 img=256x192px, target=192x192px, degraded=false
[+21661.2ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.4 (avg 8.33ms), frames: 215, dropped: 0, longest: 0 (0.0ms)
[+21661.3ms] [L2 Steady] memHit: 0, memMiss: 111, hitRate: 0.0%
[+21661.4ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+21661.4ms] [L2 Steady] grayShown: 0, grayResolved: 111, pending: -111
[+21661.5ms] [L2 Steady] req: 135 (45.6/s), cancel: 111 (37.5/s), complete: 135 (45.6/s)
[+21661.5ms] [L2 Steady] degraded: 135, maxInFlight: 24
[+21661.5ms] [L2 Steady] latency avg: 36.9ms, p95: 193.3ms, max: 308.1ms
[+21661.6ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+21662.0ms] [R2:Timing] seq=32, velocity=7795pt/s, 디바운스=50ms
[+21662.7ms] [Pipeline] requestImage #10: +1.1ms
[+21663.1ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+21663.3ms] [Pipeline] requestImage #20: +1.7ms
[+21663.4ms] [R2] seq=32, visible=21, upgraded=21
[+21664.0ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+21664.0ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+21669.0ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+21871.1ms] [Thumb:Check] seq=32, t=0.2s, velocity=7795, underSized=12/21
[+21938.8ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+22278.1ms] [Thumb:Check] seq=32, t=0.6s, velocity=7795, underSized=0/21
```

---

<!-- LOG_ID: 260103_phase1_2 -->
## Phase 1 테스트 2 (2026-01-03 23:16)

```
=== PickPhoto Launch Log ===
Date: 2026-01-03 23:16:22
Device: iPhone14,2
============================
[+5.5ms] [LaunchArgs] didFinishLaunching: count=1
[+5.7ms] [LaunchArgs] --auto-scroll: false
[+7.0ms] [Env] Build: Release
[+7.0ms] [Env] LowPowerMode: OFF
[+7.0ms] [Env] PhotosAuth: authorized
[+7.2ms] [Config] deliveryMode: opportunistic
[+7.3ms] [Config] cancelPolicy: prepareForReuse
[+7.3ms] [Config] R2Recovery: disabled
[+78.7ms] [Timing] === 초기 로딩 시작 ===
[+109.5ms] [Timing] viewWillAppear: +30.7ms (초기 진입 - reloadData 스킵)
[+160.4ms] [Timing] C) 첫 레이아웃 완료: +81.7ms
[+165.1ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+181.3ms] [Preload] DISK HIT: F29EC2F9...
[+185.9ms] [Preload] DISK HIT: F0146B79...
[+189.6ms] [Preload] DISK HIT: 261056EB...
[+193.3ms] [Preload] DISK HIT: D10201EA...
[+199.2ms] [Preload] DISK HIT: 5FEA5EE7...
[+203.8ms] [Preload] DISK HIT: 7F2BACF6...
[+207.2ms] [Preload] DISK HIT: 5AE38379...
[+211.1ms] [Preload] DISK HIT: 2CD47CFB...
[+214.9ms] [Preload] DISK HIT: 48EC0DA1...
[+218.7ms] [Preload] DISK HIT: E0FEC1AD...
[+222.3ms] [Preload] DISK HIT: 82E65101...
[+226.1ms] [Preload] DISK HIT: 0EBF73ED...
[+226.2ms] [Timing] E0) finishInitialDisplay 시작: +147.5ms (reason: preload complete, preloaded: 12/12)
[+231.5ms] [Thumb:Req] #1 target=384x384px, fullSize=true
[+231.7ms] [Timing] D) 첫 셀 표시: +153.0ms (indexPath: [0, 0])
[+232.2ms] [Thumb:Req] #2 target=384x384px, fullSize=true
[+232.6ms] [Thumb:Req] #3 target=384x384px, fullSize=true
[+232.9ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+232.9ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+233.0ms] [Thumb:Req] #4 target=384x384px, fullSize=true
[+233.2ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+233.4ms] [Thumb:Req] #5 target=384x384px, fullSize=true
[+235.1ms] [Thumb:Req] #10 target=384x384px, fullSize=true
[+235.1ms] [Pipeline] requestImage #10: +227.9ms
[+242.0ms] [Timing] E1) reloadData+layout 완료: +163.3ms (E0→E1: 15.9ms)
[+243.0ms] [Thumb:Req] #20 target=384x384px, fullSize=true
[+243.0ms] [Pipeline] requestImage #20: +235.8ms
[+243.3ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+246.7ms] [Thumb:Req] #30 target=384x384px, fullSize=true
[+253.2ms] [Timing] E2) scrollToItem+layout 완료: +174.5ms (E1→E2: 11.2ms)
[+253.3ms] [Timing] === 초기 로딩 완료: +174.5ms (E0→E1: 15.9ms, E1→E2: 11.2ms) ===
[+253.3ms] [Timing] 최종 통계: cellForItemAt 36회, 총 17.4ms, 평균 0.48ms
[+253.3ms] [Initial Load] req: 24 (97.5/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+253.3ms] [Initial Load] degraded: 24, maxInFlight: 24
[+253.3ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+253.3ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+253.3ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+253.3ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+253.3ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+254.8ms] [Thumb:Res] #1 img=120x90px, target=384x384px, degraded=true
[+254.9ms] [Thumb:Res] #2 img=120x90px, target=384x384px, degraded=true
[+254.9ms] [Thumb:Res] #3 img=120x90px, target=384x384px, degraded=true
[+254.9ms] [Thumb:Res] #4 img=120x90px, target=384x384px, degraded=true
[+254.9ms] [Thumb:Res] #5 img=90x120px, target=384x384px, degraded=true
[+255.0ms] [Thumb:Res] #10 img=120x90px, target=384x384px, degraded=true
[+255.1ms] [Thumb:Res] #20 img=90x120px, target=384x384px, degraded=true
[+278.2ms] [Thumb:Res] #30 img=512x384px, target=384x384px, degraded=false
[+319.7ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+319.8ms] [Thumb:Res] #40 img=384x512px, target=384x384px, degraded=false
[+1804.6ms] [Scroll] First scroll 시작: +1725.5ms
[+1822.7ms] [Pipeline] completion #50 도달: +1815.5ms
[+1824.5ms] [Thumb:Res] #50 img=90x120px, target=192x192px, degraded=true
[+1845.3ms] [Thumb:Req] #40 target=192x192px, fullSize=false
[+1855.8ms] [Pipeline] requestImage #30: +1848.5ms
[+1862.9ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+1864.0ms] [Thumb:Res] #60 img=192x256px, target=192x192px, degraded=false
[+1893.8ms] [Thumb:Res] #70 img=192x256px, target=192x192px, degraded=false
[+1912.6ms] [Thumb:Req] #50 target=192x192px, fullSize=false
[+1932.8ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+1933.0ms] [Thumb:Res] #80 img=192x256px, target=192x192px, degraded=false
[+1983.9ms] [Thumb:Res] #90 img=192x256px, target=192x192px, degraded=false
[+2004.0ms] [Thumb:Req] #60 target=192x192px, fullSize=false
[+2024.5ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+2024.7ms] [Thumb:Res] #100 img=192x256px, target=192x192px, degraded=false
[+2075.5ms] [Thumb:Res] #110 img=192x256px, target=192x192px, degraded=false
[+2095.9ms] [Thumb:Req] #70 target=192x192px, fullSize=false
[+2116.5ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+2116.7ms] [Thumb:Res] #120 img=192x256px, target=192x192px, degraded=false
[+2170.4ms] [Thumb:Res] #130 img=192x256px, target=192x192px, degraded=false
[+2264.0ms] [Thumb:Req] #80 target=192x192px, fullSize=false
[+2529.8ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 118.6 (avg 8.33ms), frames: 86, dropped: 0, longest: 0 (0.0ms)
[+2529.8ms] [L1 First] memHit: 0, memMiss: 45, hitRate: 0.0%
[+2529.9ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+2529.9ms] [L1 First] grayShown: 5, grayResolved: 69, pending: -64
[+2530.0ms] [L1 First] req: 69 (27.4/s), cancel: 27 (10.7/s), complete: 69 (27.4/s)
[+2530.1ms] [L1 First] degraded: 69, maxInFlight: 24
[+2530.1ms] [L1 First] latency avg: 28.2ms, p95: 94.3ms, max: 137.3ms
[+2530.1ms] [L1 First] preheat: 0회, 총 0개 에셋
[+2530.1ms] [Scroll] First scroll 완료: 725.9ms 동안 스크롤
[+2530.6ms] [R2:Timing] seq=3, velocity=6087pt/s, 디바운스=50ms
[+2531.4ms] [Pipeline] requestImage #10: +1.2ms
[+2531.9ms] [Pipeline] requestImage #20: +1.8ms
[+2532.0ms] [R2] seq=3, visible=21, upgraded=21
[+2532.1ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+2532.1ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+2532.8ms] [Pipeline] #3 target=384x384px → img=68x120px (18%), degraded=true
[+2538.2ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+2737.8ms] [Thumb:Check] seq=3, t=0.2s, velocity=6087, underSized=13/21
[+2892.9ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+3153.1ms] [Thumb:Check] seq=3, t=0.6s, velocity=6087, underSized=0/21
[+3898.7ms] [Thumb:Res] #140 img=90x120px, target=192x192px, degraded=true
[+3937.2ms] [Pipeline] completion #50 도달: +1407.0ms
[+3950.7ms] [Thumb:Res] #150 img=192x256px, target=192x192px, degraded=false
[+3987.3ms] [Thumb:Req] #90 target=192x192px, fullSize=false
[+3987.3ms] [Pipeline] requestImage #30: +1457.2ms
[+3992.3ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+4026.0ms] [Thumb:Res] #160 img=192x256px, target=192x192px, degraded=false
[+4134.5ms] [Thumb:Res] #170 img=192x256px, target=192x192px, degraded=false
[+4196.2ms] [Thumb:Req] #100 target=192x192px, fullSize=false
[+4204.3ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+4217.7ms] [Thumb:Res] #180 img=192x256px, target=192x192px, degraded=false
[+4372.6ms] [Thumb:Res] #190 img=192x256px, target=192x192px, degraded=false
[+4472.1ms] [Thumb:Req] #110 target=192x192px, fullSize=false
[+4478.1ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+4888.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.0 (avg 8.33ms), frames: 123, dropped: 0, longest: 0 (0.0ms)
[+4888.1ms] [L2 Steady] memHit: 0, memMiss: 30, hitRate: 0.0%
[+4888.1ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+4888.1ms] [L2 Steady] grayShown: 0, grayResolved: 30, pending: -30
[+4888.2ms] [L2 Steady] req: 51 (21.6/s), cancel: 30 (12.7/s), complete: 51 (21.6/s)
[+4888.2ms] [L2 Steady] degraded: 51, maxInFlight: 21
[+4888.3ms] [L2 Steady] latency avg: 96.3ms, p95: 361.1ms, max: 373.1ms
[+4888.3ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+4888.7ms] [R2:Timing] seq=6, velocity=4080pt/s, 디바운스=50ms
[+4889.4ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+4889.4ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+4889.4ms] [Pipeline] requestImage #10: +1.1ms
[+4889.7ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+4890.0ms] [Pipeline] requestImage #20: +1.7ms
[+4890.3ms] [R2] seq=6, visible=24, upgraded=24
[+4893.4ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+5099.6ms] [Thumb:Check] seq=6, t=0.2s, velocity=4080, underSized=5/24
[+5520.0ms] [Thumb:Check] seq=6, t=0.6s, velocity=4080, underSized=0/24
[+6483.4ms] [Thumb:Res] #200 img=90x120px, target=192x192px, degraded=true
[+6489.6ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+6521.4ms] [Pipeline] requestImage #30: +1633.0ms
[+6527.0ms] [Thumb:Res] #210 img=256x192px, target=192x192px, degraded=false
[+6546.4ms] [Pipeline] completion #50 도달: +1658.1ms
[+6553.9ms] [Thumb:Req] #120 target=192x192px, fullSize=false
[+6582.6ms] [Thumb:Res] #220 img=192x256px, target=192x192px, degraded=false
[+6592.0ms] [Pipeline] #60 target=192x192px → img=192x341px (100%), degraded=false
[+6640.3ms] [Thumb:Res] #230 img=192x256px, target=192x192px, degraded=false
[+6670.4ms] [Thumb:Req] #130 target=192x192px, fullSize=false
[+6691.4ms] [Thumb:Res] #240 img=192x341px, target=192x192px, degraded=false
[+6717.0ms] [Pipeline] #80 target=192x192px → img=192x341px (100%), degraded=false
[+6777.3ms] [Thumb:Res] #250 img=192x341px, target=192x192px, degraded=false
[+6821.3ms] [Thumb:Req] #140 target=192x192px, fullSize=false
[+6886.4ms] [Thumb:Res] #260 img=256x192px, target=192x192px, degraded=false
[+6893.5ms] [Pipeline] #100 target=192x192px → img=256x192px (133%), degraded=false
[+7146.5ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.5 (avg 8.33ms), frames: 84, dropped: 0, longest: 0 (0.0ms)
[+7146.6ms] [L2 Steady] memHit: 0, memMiss: 33, hitRate: 0.0%
[+7146.6ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+7146.6ms] [L2 Steady] grayShown: 0, grayResolved: 33, pending: -33
[+7146.7ms] [L2 Steady] req: 57 (25.2/s), cancel: 33 (14.6/s), complete: 57 (25.2/s)
[+7146.7ms] [L2 Steady] degraded: 45, maxInFlight: 20
[+7146.7ms] [L2 Steady] latency avg: 51.6ms, p95: 385.6ms, max: 398.0ms
[+7146.7ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+7147.1ms] [R2:Timing] seq=9, velocity=5821pt/s, 디바운스=50ms
[+7147.8ms] [Pipeline] requestImage #10: +1.0ms
[+7148.2ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+7148.2ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+7148.4ms] [Pipeline] requestImage #20: +1.6ms
[+7148.5ms] [R2] seq=9, visible=21, upgraded=21
[+7148.9ms] [Pipeline] #3 target=384x384px → img=68x120px (18%), degraded=true
[+7152.4ms] [Pipeline] #20 target=384x384px → img=68x120px (18%), degraded=true
[+7353.3ms] [Thumb:Check] seq=9, t=0.2s, velocity=5821, underSized=2/21
[+7751.4ms] [Thumb:Check] seq=9, t=0.6s, velocity=5821, underSized=0/21
[+9905.7ms] [Thumb:Res] #270 img=256x192px, target=192x192px, degraded=false
[+9926.3ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+9929.6ms] [Thumb:Req] #150 target=192x192px, fullSize=false
[+9958.6ms] [Thumb:Res] #280 img=192x256px, target=192x192px, degraded=false
[+9962.4ms] [Pipeline] requestImage #30: +2815.6ms
[+9984.3ms] [Pipeline] completion #50 도달: +2837.5ms
[+10010.6ms] [Thumb:Res] #290 img=192x341px, target=192x192px, degraded=false
[+10023.7ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+10037.4ms] [Thumb:Req] #160 target=192x192px, fullSize=false
[+10059.8ms] [Thumb:Res] #300 img=192x341px, target=192x192px, degraded=false
[+10107.5ms] [Thumb:Res] #310 img=256x192px, target=192x192px, degraded=false
[+10134.6ms] [Pipeline] #80 target=192x192px → img=256x192px (133%), degraded=false
[+10138.1ms] [Thumb:Req] #170 target=192x192px, fullSize=false
[+10167.3ms] [Thumb:Res] #320 img=192x256px, target=192x192px, degraded=false
[+10216.6ms] [Thumb:Res] #330 img=192x256px, target=192x192px, degraded=false
[+10244.9ms] [Pipeline] #100 target=192x192px → img=192x341px (100%), degraded=false
[+10246.1ms] [Thumb:Req] #180 target=192x192px, fullSize=false
[+10292.5ms] [Thumb:Res] #340 img=192x256px, target=192x192px, degraded=false
[+10398.3ms] [Thumb:Res] #350 img=192x256px, target=192x192px, degraded=false
[+10410.1ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+10456.2ms] [Thumb:Req] #190 target=192x192px, fullSize=false
[+10481.6ms] [Thumb:Res] #360 img=192x341px, target=192x192px, degraded=false
[+10636.5ms] [Thumb:Res] #370 img=192x256px, target=192x192px, degraded=false
[+10736.0ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+10738.9ms] [Thumb:Req] #200 target=192x192px, fullSize=false
[+10892.7ms] [Thumb:Res] #380 img=90x120px, target=192x192px, degraded=true
[+10969.7ms] [Thumb:Res] #390 img=256x192px, target=192x192px, degraded=false
[+10993.2ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+10996.8ms] [Thumb:Req] #210 target=192x192px, fullSize=false
[+11026.6ms] [Thumb:Res] #400 img=256x192px, target=192x192px, degraded=false
[+11076.6ms] [Thumb:Res] #410 img=192x256px, target=192x192px, degraded=false
[+11093.1ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+11105.0ms] [Thumb:Req] #220 target=192x192px, fullSize=false
[+11126.1ms] [Thumb:Res] #420 img=192x256px, target=192x192px, degraded=false
[+11176.5ms] [Thumb:Res] #430 img=192x256px, target=192x192px, degraded=false
[+11200.7ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+11205.4ms] [Thumb:Req] #230 target=192x192px, fullSize=false
[+11234.3ms] [Thumb:Res] #440 img=192x256px, target=192x192px, degraded=false
[+11361.2ms] [Thumb:Res] #450 img=192x256px, target=192x192px, degraded=false
[+11513.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.4 (avg 8.33ms), frames: 198, dropped: 0, longest: 0 (0.0ms)
[+11513.7ms] [L2 Steady] memHit: 0, memMiss: 93, hitRate: 0.0%
[+11513.7ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+11513.7ms] [L2 Steady] grayShown: 0, grayResolved: 93, pending: -93
[+11513.8ms] [L2 Steady] req: 114 (26.1/s), cancel: 93 (21.3/s), complete: 114 (26.1/s)
[+11513.8ms] [L2 Steady] degraded: 102, maxInFlight: 21
[+11513.9ms] [L2 Steady] latency avg: 16.3ms, p95: 164.5ms, max: 298.9ms
[+11513.9ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+11514.3ms] [R2:Timing] seq=13, velocity=6184pt/s, 디바운스=50ms
[+11515.0ms] [Pipeline] requestImage #10: +1.1ms
[+11515.5ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+11515.6ms] [Pipeline] requestImage #20: +1.6ms
[+11515.8ms] [R2] seq=13, visible=24, upgraded=24
[+11516.2ms] [Pipeline] #2 target=384x384px → img=68x120px (18%), degraded=true
[+11516.8ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+11521.5ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+11722.0ms] [Thumb:Check] seq=13, t=0.2s, velocity=6184, underSized=19/24
[+11829.3ms] [Pipeline] #40 target=384x384px → img=512x384px (133%), degraded=false
[+12120.7ms] [Thumb:Check] seq=13, t=0.6s, velocity=6184, underSized=0/24
[+12392.2ms] [Pipeline] completion #50 도달: +878.2ms
[+12398.7ms] [Thumb:Req] #240 target=192x192px, fullSize=false
[+12430.5ms] [Pipeline] requestImage #30: +916.6ms
[+12431.0ms] [Thumb:Res] #460 img=192x341px, target=192x192px, degraded=false
[+12434.1ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+12476.2ms] [Thumb:Res] #470 img=192x256px, target=192x192px, degraded=false
[+12496.8ms] [Thumb:Req] #250 target=192x192px, fullSize=false
[+12516.3ms] [Thumb:Res] #480 img=192x256px, target=192x192px, degraded=false
[+12524.1ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+12564.0ms] [Thumb:Res] #490 img=90x120px, target=192x192px, degraded=true
[+12571.8ms] [Thumb:Req] #260 target=192x192px, fullSize=false
[+12592.5ms] [Thumb:Res] #500 img=192x256px, target=192x192px, degraded=false
[+12600.6ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+12633.8ms] [Thumb:Res] #510 img=192x256px, target=192x192px, degraded=false
[+12654.5ms] [Thumb:Req] #270 target=192x192px, fullSize=false
[+12684.6ms] [Thumb:Res] #520 img=192x256px, target=192x192px, degraded=false
[+12689.7ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+12717.2ms] [Thumb:Res] #530 img=192x256px, target=192x192px, degraded=false
[+12738.3ms] [Thumb:Req] #280 target=192x192px, fullSize=false
[+12759.0ms] [Thumb:Res] #540 img=192x256px, target=192x192px, degraded=false
[+12767.3ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+12887.3ms] [Thumb:Res] #550 img=256x192px, target=192x192px, degraded=false
[+12904.5ms] [Thumb:Req] #290 target=192x192px, fullSize=false
[+12928.8ms] [Thumb:Res] #560 img=256x192px, target=192x192px, degraded=false
[+12935.0ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+13080.5ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.6 (avg 8.33ms), frames: 86, dropped: 0, longest: 0 (0.0ms)
[+13080.5ms] [L2 Steady] memHit: 0, memMiss: 57, hitRate: 0.0%
[+13080.6ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+13080.6ms] [L2 Steady] grayShown: 3, grayResolved: 57, pending: -54
[+13080.7ms] [L2 Steady] req: 81 (51.7/s), cancel: 57 (36.4/s), complete: 81 (51.7/s)
[+13080.7ms] [L2 Steady] degraded: 81, maxInFlight: 24
[+13080.8ms] [L2 Steady] latency avg: 82.7ms, p95: 330.6ms, max: 344.1ms
[+13080.8ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+13103.7ms] [R2:Timing] seq=16, velocity=9525pt/s, 디바운스=50ms
[+13104.0ms] [Pipeline] requestImage #10: +23.2ms
[+13104.3ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+13104.3ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+13104.3ms] [Pipeline] requestImage #20: +23.5ms
[+13104.3ms] [R2] seq=16, visible=21, upgraded=21
[+13104.6ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+13107.3ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+13305.6ms] [Thumb:Check] seq=16, t=0.2s, velocity=9525, underSized=13/21
[+13443.8ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+13720.7ms] [Thumb:Check] seq=16, t=0.6s, velocity=9525, underSized=0/21
[+14489.9ms] [Thumb:Res] #570 img=256x192px, target=192x192px, degraded=false
[+14502.6ms] [Pipeline] completion #50 도달: +1421.7ms
[+14514.0ms] [Thumb:Req] #300 target=192x192px, fullSize=false
[+14533.4ms] [Thumb:Res] #580 img=192x256px, target=192x192px, degraded=false
[+14537.8ms] [Pipeline] requestImage #30: +1456.9ms
[+14539.2ms] [Pipeline] #60 target=192x192px → img=90x120px (47%), degraded=true
[+14566.4ms] [Thumb:Res] #590 img=192x256px, target=192x192px, degraded=false
[+14572.0ms] [Thumb:Req] #310 target=192x192px, fullSize=false
[+14588.9ms] [Thumb:Res] #600 img=90x120px, target=192x192px, degraded=true
[+14591.8ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+14616.2ms] [Thumb:Res] #610 img=192x256px, target=192x192px, degraded=false
[+14629.6ms] [Thumb:Req] #320 target=192x192px, fullSize=false
[+14651.7ms] [Thumb:Res] #620 img=192x341px, target=192x192px, degraded=false
[+14654.6ms] [Pipeline] #100 target=192x192px → img=90x120px (47%), degraded=true
[+14672.1ms] [Thumb:Res] #630 img=90x120px, target=192x192px, degraded=true
[+14687.6ms] [Thumb:Req] #330 target=192x192px, fullSize=false
[+14707.4ms] [Thumb:Res] #640 img=192x256px, target=192x192px, degraded=false
[+14713.4ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+14751.3ms] [Thumb:Res] #650 img=192x256px, target=192x192px, degraded=false
[+14755.1ms] [Thumb:Req] #340 target=192x192px, fullSize=false
[+14774.4ms] [Thumb:Res] #660 img=192x256px, target=192x192px, degraded=false
[+14782.8ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+14817.4ms] [Thumb:Res] #670 img=192x256px, target=192x192px, degraded=false
[+14837.9ms] [Thumb:Req] #350 target=192x192px, fullSize=false
[+14868.7ms] [Thumb:Res] #680 img=192x256px, target=192x192px, degraded=false
[+14876.2ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+14907.6ms] [Thumb:Res] #690 img=192x256px, target=192x192px, degraded=false
[+14929.7ms] [Thumb:Req] #360 target=192x192px, fullSize=false
[+14949.8ms] [Thumb:Res] #700 img=192x256px, target=192x192px, degraded=false
[+14957.9ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+15000.8ms] [Thumb:Res] #710 img=256x192px, target=192x192px, degraded=false
[+15021.4ms] [Thumb:Req] #370 target=192x192px, fullSize=false
[+15041.3ms] [Thumb:Res] #720 img=256x192px, target=192x192px, degraded=false
[+15052.5ms] [Pipeline] #200 target=192x192px → img=192x341px (100%), degraded=false
[+15169.3ms] [Thumb:Res] #730 img=192x256px, target=192x192px, degraded=false
[+15187.9ms] [Thumb:Req] #380 target=192x192px, fullSize=false
[+15305.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 103, dropped: 0, longest: 0 (0.0ms)
[+15305.7ms] [L2 Steady] memHit: 0, memMiss: 87, hitRate: 0.0%
[+15305.7ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+15305.7ms] [L2 Steady] grayShown: 14, grayResolved: 87, pending: -73
[+15305.8ms] [L2 Steady] req: 108 (48.5/s), cancel: 87 (39.1/s), complete: 108 (48.5/s)
[+15305.8ms] [L2 Steady] degraded: 108, maxInFlight: 21
[+15305.9ms] [L2 Steady] latency avg: 47.3ms, p95: 327.5ms, max: 348.0ms
[+15305.9ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+15306.3ms] [R2:Timing] seq=19, velocity=11904pt/s, 디바운스=50ms
[+15307.0ms] [Pipeline] requestImage #10: +1.0ms
[+15307.4ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+15307.6ms] [Pipeline] requestImage #20: +1.6ms
[+15307.7ms] [R2] seq=19, visible=21, upgraded=21
[+15308.1ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+15308.4ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+15313.2ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+15513.8ms] [Thumb:Check] seq=19, t=0.2s, velocity=11904, underSized=4/21
[+15635.2ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+15920.9ms] [Thumb:Check] seq=19, t=0.6s, velocity=11904, underSized=0/21
[+17175.7ms] [Thumb:Res] #740 img=90x120px, target=192x192px, degraded=true
[+17203.3ms] [Pipeline] completion #50 도달: +1897.3ms
[+17218.6ms] [Thumb:Res] #750 img=256x192px, target=192x192px, degraded=false
[+17237.8ms] [Thumb:Req] #390 target=192x192px, fullSize=false
[+17237.8ms] [Pipeline] requestImage #30: +1931.9ms
[+17239.0ms] [Pipeline] #60 target=192x192px → img=90x120px (47%), degraded=true
[+17247.2ms] [Thumb:Res] #760 img=120x90px, target=192x192px, degraded=true
[+17268.9ms] [Thumb:Res] #770 img=192x341px, target=192x192px, degraded=false
[+17280.0ms] [Thumb:Req] #400 target=192x192px, fullSize=false
[+17283.4ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+17297.1ms] [Thumb:Res] #780 img=90x120px, target=192x192px, degraded=true
[+17322.6ms] [Thumb:Res] #790 img=90x120px, target=192x192px, degraded=true
[+17330.0ms] [Thumb:Req] #410 target=192x192px, fullSize=false
[+17333.2ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+17341.9ms] [Thumb:Res] #800 img=192x256px, target=192x192px, degraded=false
[+17380.5ms] [Thumb:Res] #810 img=90x120px, target=192x192px, degraded=true
[+17396.0ms] [Thumb:Req] #420 target=192x192px, fullSize=false
[+17399.1ms] [Pipeline] #120 target=192x192px → img=256x192px (133%), degraded=false
[+17413.4ms] [Thumb:Res] #820 img=90x120px, target=192x192px, degraded=true
[+17441.6ms] [Thumb:Res] #830 img=192x256px, target=192x192px, degraded=false
[+17455.0ms] [Thumb:Req] #430 target=192x192px, fullSize=false
[+17458.3ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+17474.4ms] [Thumb:Res] #840 img=192x256px, target=192x192px, degraded=false
[+17516.2ms] [Thumb:Res] #850 img=192x256px, target=192x192px, degraded=false
[+17529.9ms] [Thumb:Req] #440 target=192x192px, fullSize=false
[+17533.2ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+17550.0ms] [Thumb:Res] #860 img=192x256px, target=192x192px, degraded=false
[+17593.0ms] [Thumb:Res] #870 img=192x256px, target=192x192px, degraded=false
[+17638.3ms] [Thumb:Req] #450 target=192x192px, fullSize=false
[+17640.6ms] [Pipeline] #180 target=192x192px → img=90x120px (47%), degraded=true
[+17647.6ms] [Thumb:Res] #880 img=90x120px, target=192x192px, degraded=true
[+17667.2ms] [Thumb:Res] #890 img=192x256px, target=192x192px, degraded=false
[+17680.0ms] [Thumb:Req] #460 target=192x192px, fullSize=false
[+17683.5ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+17691.6ms] [Thumb:Res] #900 img=192x256px, target=192x192px, degraded=false
[+17708.3ms] [Thumb:Res] #910 img=192x256px, target=192x192px, degraded=false
[+17721.4ms] [Thumb:Req] #470 target=192x192px, fullSize=false
[+17724.6ms] [Pipeline] #220 target=192x192px → img=192x256px (100%), degraded=false
[+17733.4ms] [Thumb:Res] #920 img=192x256px, target=192x192px, degraded=false
[+17758.0ms] [Thumb:Res] #930 img=192x256px, target=192x192px, degraded=false
[+17771.1ms] [Thumb:Req] #480 target=192x192px, fullSize=false
[+17772.3ms] [Pipeline] #240 target=192x192px → img=90x120px (47%), degraded=true
[+17783.3ms] [Thumb:Res] #940 img=192x256px, target=192x192px, degraded=false
[+17816.3ms] [Thumb:Res] #950 img=192x256px, target=192x192px, degraded=false
[+17822.0ms] [Thumb:Req] #490 target=192x192px, fullSize=false
[+17826.1ms] [Pipeline] #260 target=192x192px → img=192x256px (100%), degraded=false
[+17838.9ms] [Thumb:Res] #960 img=90x120px, target=192x192px, degraded=true
[+17871.9ms] [Thumb:Res] #970 img=90x120px, target=192x192px, degraded=true
[+17879.9ms] [Thumb:Req] #500 target=192x192px, fullSize=false
[+17882.5ms] [Pipeline] #280 target=192x192px → img=192x256px (100%), degraded=false
[+17907.7ms] [Thumb:Res] #980 img=256x192px, target=192x192px, degraded=false
[+17930.5ms] [Thumb:Res] #990 img=90x120px, target=192x192px, degraded=true
[+17946.7ms] [Thumb:Req] #510 target=192x192px, fullSize=false
[+17951.2ms] [Pipeline] #300 target=192x192px → img=192x341px (100%), degraded=false
[+17966.5ms] [Thumb:Res] #1000 img=192x256px, target=192x192px, degraded=false
[+18017.0ms] [Thumb:Res] #1010 img=192x256px, target=192x192px, degraded=false
[+18030.5ms] [Thumb:Req] #520 target=192x192px, fullSize=false
[+18035.6ms] [Pipeline] #320 target=192x192px → img=192x341px (100%), degraded=false
[+18049.6ms] [Thumb:Res] #1020 img=256x192px, target=192x192px, degraded=false
[+18091.6ms] [Thumb:Res] #1030 img=256x192px, target=192x192px, degraded=false
[+18113.1ms] [Thumb:Req] #530 target=192x192px, fullSize=false
[+18116.2ms] [Pipeline] #340 target=192x192px → img=192x256px (100%), degraded=false
[+18144.1ms] [Thumb:Res] #1040 img=192x341px, target=192x192px, degraded=false
[+18183.3ms] [Thumb:Res] #1050 img=192x256px, target=192x192px, degraded=false
[+18204.6ms] [Thumb:Req] #540 target=192x192px, fullSize=false
[+18207.7ms] [Pipeline] #360 target=192x192px → img=192x256px (100%), degraded=false
[+18224.8ms] [Thumb:Res] #1060 img=192x256px, target=192x192px, degraded=false
[+18276.1ms] [Thumb:Res] #1070 img=192x256px, target=192x192px, degraded=false
[+18296.7ms] [Thumb:Req] #550 target=192x192px, fullSize=false
[+18300.1ms] [Pipeline] #380 target=192x192px → img=192x256px (100%), degraded=false
[+18316.4ms] [Thumb:Res] #1080 img=192x256px, target=192x192px, degraded=false
[+18368.2ms] [Thumb:Res] #1090 img=192x341px, target=192x192px, degraded=false
[+18397.6ms] [Thumb:Req] #560 target=192x192px, fullSize=false
[+18400.9ms] [Pipeline] #400 target=192x192px → img=192x256px (100%), degraded=false
[+18722.5ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.3 (avg 8.33ms), frames: 189, dropped: 0, longest: 0 (0.0ms)
[+18722.6ms] [L2 Steady] memHit: 0, memMiss: 180, hitRate: 0.0%
[+18722.6ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+18722.6ms] [L2 Steady] grayShown: 48, grayResolved: 180, pending: -132
[+18722.7ms] [L2 Steady] req: 201 (58.8/s), cancel: 180 (52.7/s), complete: 201 (58.8/s)
[+18722.8ms] [L2 Steady] degraded: 201, maxInFlight: 21
[+18722.8ms] [L2 Steady] latency avg: 22.9ms, p95: 190.0ms, max: 335.7ms
[+18722.8ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+18723.2ms] [R2:Timing] seq=23, velocity=13094pt/s, 디바운스=50ms
[+18723.9ms] [Pipeline] requestImage #10: +1.1ms
[+18724.4ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+18724.7ms] [Pipeline] requestImage #20: +1.9ms
[+18725.0ms] [R2] seq=23, visible=24, upgraded=24
[+18725.2ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+18725.3ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+18730.5ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+18873.6ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+18931.4ms] [Thumb:Check] seq=23, t=0.2s, velocity=13094, underSized=5/24
[+19339.4ms] [Thumb:Check] seq=23, t=0.6s, velocity=13094, underSized=0/24
[+19625.3ms] [Pipeline] completion #50 도달: +902.4ms
[+19625.6ms] [Thumb:Res] #1100 img=90x120px, target=192x192px, degraded=true
[+19664.3ms] [Pipeline] requestImage #30: +941.4ms
[+19668.8ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+19668.9ms] [Thumb:Res] #1110 img=192x256px, target=192x192px, degraded=false
[+19688.4ms] [Thumb:Req] #570 target=192x192px, fullSize=false
[+19708.2ms] [Thumb:Res] #1120 img=256x192px, target=192x192px, degraded=false
[+19735.6ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+19735.7ms] [Thumb:Res] #1130 img=192x256px, target=192x192px, degraded=false
[+19747.2ms] [Thumb:Req] #580 target=192x192px, fullSize=false
[+19764.1ms] [Thumb:Res] #1140 img=90x120px, target=192x192px, degraded=true
[+19792.1ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+19792.2ms] [Thumb:Res] #1150 img=192x256px, target=192x192px, degraded=false
[+19821.3ms] [Thumb:Req] #590 target=192x192px, fullSize=false
[+19826.4ms] [Thumb:Res] #1160 img=192x256px, target=192x192px, degraded=false
[+19863.9ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+19864.0ms] [Thumb:Res] #1170 img=90x120px, target=192x192px, degraded=true
[+19879.9ms] [Thumb:Req] #600 target=192x192px, fullSize=false
[+19900.9ms] [Thumb:Res] #1180 img=192x256px, target=192x192px, degraded=false
[+19967.2ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+19967.3ms] [Thumb:Res] #1190 img=192x256px, target=192x192px, degraded=false
[+19972.6ms] [Thumb:Req] #610 target=192x192px, fullSize=false
[+19989.4ms] [Thumb:Res] #1200 img=90x120px, target=192x192px, degraded=true
[+20010.5ms] [Pipeline] #160 target=192x192px → img=192x341px (100%), degraded=false
[+20010.6ms] [Thumb:Res] #1210 img=192x341px, target=192x192px, degraded=false
[+20029.6ms] [Thumb:Req] #620 target=192x192px, fullSize=false
[+20034.1ms] [Thumb:Res] #1220 img=192x256px, target=192x192px, degraded=false
[+20055.5ms] [Pipeline] #180 target=192x192px → img=90x120px (47%), degraded=true
[+20055.5ms] [Thumb:Res] #1230 img=90x120px, target=192x192px, degraded=true
[+20071.3ms] [Thumb:Req] #630 target=192x192px, fullSize=false
[+20083.4ms] [Thumb:Res] #1240 img=256x192px, target=192x192px, degraded=false
[+20111.3ms] [Pipeline] #200 target=192x192px → img=192x341px (100%), degraded=false
[+20111.4ms] [Thumb:Res] #1250 img=192x341px, target=192x192px, degraded=false
[+20122.2ms] [Thumb:Req] #640 target=192x192px, fullSize=false
[+20138.9ms] [Thumb:Res] #1260 img=90x120px, target=192x192px, degraded=true
[+20166.2ms] [Pipeline] #220 target=192x192px → img=192x256px (100%), degraded=false
[+20166.3ms] [Thumb:Res] #1270 img=192x256px, target=192x192px, degraded=false
[+20196.3ms] [Thumb:Req] #650 target=192x192px, fullSize=false
[+20201.2ms] [Thumb:Res] #1280 img=192x256px, target=192x192px, degraded=false
[+20233.3ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+20233.4ms] [Thumb:Res] #1290 img=192x256px, target=192x192px, degraded=false
[+20254.7ms] [Thumb:Req] #660 target=192x192px, fullSize=false
[+20276.1ms] [Thumb:Res] #1300 img=192x341px, target=192x192px, degraded=false
[+20310.7ms] [Pipeline] #260 target=192x192px → img=192x341px (100%), degraded=false
[+20310.8ms] [Thumb:Res] #1310 img=192x341px, target=192x192px, degraded=false
[+20329.7ms] [Thumb:Req] #670 target=192x192px, fullSize=false
[+20349.6ms] [Thumb:Res] #1320 img=192x256px, target=192x192px, degraded=false
[+20391.7ms] [Pipeline] #280 target=192x192px → img=192x256px (100%), degraded=false
[+20391.8ms] [Thumb:Res] #1330 img=192x256px, target=192x192px, degraded=false
[+20421.8ms] [Thumb:Req] #680 target=192x192px, fullSize=false
[+20441.5ms] [Thumb:Res] #1340 img=192x256px, target=192x192px, degraded=false
[+20482.9ms] [Pipeline] #300 target=192x192px → img=192x256px (100%), degraded=false
[+20483.0ms] [Thumb:Res] #1350 img=192x256px, target=192x192px, degraded=false
[+20505.0ms] [Thumb:Req] #690 target=192x192px, fullSize=false
[+20533.2ms] [Thumb:Res] #1360 img=192x256px, target=192x192px, degraded=false
[+20583.2ms] [Pipeline] #320 target=192x192px → img=192x256px (100%), degraded=false
[+20583.3ms] [Thumb:Res] #1370 img=192x256px, target=192x192px, degraded=false
[+20614.0ms] [Thumb:Req] #700 target=192x192px, fullSize=false
[+20706.8ms] [Thumb:Res] #1380 img=90x120px, target=192x192px, degraded=true
[+20939.3ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.2 (avg 8.33ms), frames: 161, dropped: 0, longest: 0 (0.0ms)
[+20939.4ms] [L2 Steady] memHit: 0, memMiss: 144, hitRate: 0.0%
[+20939.4ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+20939.5ms] [L2 Steady] grayShown: 32, grayResolved: 144, pending: -112
[+20939.5ms] [L2 Steady] req: 168 (75.8/s), cancel: 144 (65.0/s), complete: 168 (75.8/s)
[+20939.6ms] [L2 Steady] degraded: 168, maxInFlight: 24
[+20939.6ms] [L2 Steady] latency avg: 26.0ms, p95: 149.3ms, max: 269.3ms
[+20939.6ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+20940.1ms] [R2:Timing] seq=27, velocity=12518pt/s, 디바운스=50ms
[+20940.7ms] [Pipeline] requestImage #10: +1.1ms
[+20941.1ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+20941.3ms] [Pipeline] requestImage #20: +1.6ms
[+20941.6ms] [R2] seq=27, visible=24, upgraded=24
[+20942.1ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+20942.6ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+20947.5ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+21099.5ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+21151.7ms] [Thumb:Check] seq=27, t=0.2s, velocity=12518, underSized=7/24
[+21554.7ms] [Thumb:Check] seq=27, t=0.6s, velocity=12518, underSized=0/24
[+21941.5ms] [Pipeline] completion #50 도달: +1001.9ms
[+21948.9ms] [Thumb:Res] #1390 img=192x256px, target=192x192px, degraded=false
[+21964.0ms] [Thumb:Req] #710 target=192x192px, fullSize=false
[+21972.9ms] [Pipeline] requestImage #30: +1033.2ms
[+21977.3ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+21995.1ms] [Thumb:Res] #1400 img=256x192px, target=192x192px, degraded=false
[+22034.0ms] [Thumb:Res] #1410 img=256x192px, target=192x192px, degraded=false
[+22055.1ms] [Thumb:Req] #720 target=192x192px, fullSize=false
[+22076.7ms] [Pipeline] #80 target=192x192px → img=256x192px (133%), degraded=false
[+22080.6ms] [Thumb:Res] #1420 img=120x90px, target=192x192px, degraded=true
[+22108.7ms] [Thumb:Res] #1430 img=192x256px, target=192x192px, degraded=false
[+22130.4ms] [Thumb:Req] #730 target=192x192px, fullSize=false
[+22142.2ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+22150.0ms] [Thumb:Res] #1440 img=192x256px, target=192x192px, degraded=false
[+22200.2ms] [Thumb:Res] #1450 img=192x256px, target=192x192px, degraded=false
[+22214.9ms] [Thumb:Req] #740 target=192x192px, fullSize=false
[+22244.0ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+22251.2ms] [Thumb:Res] #1460 img=192x256px, target=192x192px, degraded=false
[+22289.6ms] [Thumb:Res] #1470 img=90x120px, target=192x192px, degraded=true
[+22304.9ms] [Thumb:Req] #750 target=192x192px, fullSize=false
[+22317.3ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+22322.4ms] [Thumb:Res] #1480 img=90x120px, target=192x192px, degraded=true
[+22342.6ms] [Thumb:Res] #1490 img=256x192px, target=192x192px, degraded=false
[+22355.5ms] [Thumb:Req] #760 target=192x192px, fullSize=false
[+22367.6ms] [Pipeline] #160 target=192x192px → img=256x192px (133%), degraded=false
[+22375.6ms] [Thumb:Res] #1500 img=256x192px, target=192x192px, degraded=false
[+22416.7ms] [Thumb:Res] #1510 img=192x256px, target=192x192px, degraded=false
[+22430.3ms] [Thumb:Req] #770 target=192x192px, fullSize=false
[+22439.5ms] [Pipeline] #180 target=192x192px → img=90x120px (47%), degraded=true
[+22442.7ms] [Thumb:Res] #1520 img=192x256px, target=192x192px, degraded=false
[+22483.8ms] [Thumb:Res] #1530 img=192x256px, target=192x192px, degraded=false
[+22505.2ms] [Thumb:Req] #780 target=192x192px, fullSize=false
[+22525.7ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+22534.0ms] [Thumb:Res] #1540 img=192x256px, target=192x192px, degraded=false
[+22577.3ms] [Thumb:Res] #1550 img=192x341px, target=192x192px, degraded=false
[+22596.6ms] [Thumb:Req] #790 target=192x192px, fullSize=false
[+22610.3ms] [Pipeline] #220 target=192x192px → img=192x341px (100%), degraded=false
[+22617.9ms] [Thumb:Res] #1560 img=192x341px, target=192x192px, degraded=false
[+22666.9ms] [Thumb:Res] #1570 img=192x256px, target=192x192px, degraded=false
[+22689.6ms] [Thumb:Req] #800 target=192x192px, fullSize=false
[+22773.3ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+22780.9ms] [Thumb:Res] #1580 img=192x256px, target=192x192px, degraded=false
[+22827.2ms] [Thumb:Res] #1590 img=192x256px, target=192x192px, degraded=false
[+22846.9ms] [Thumb:Req] #810 target=192x192px, fullSize=false
[+22997.9ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.0 (avg 8.33ms), frames: 130, dropped: 0, longest: 0 (0.0ms)
[+22998.0ms] [L2 Steady] memHit: 0, memMiss: 105, hitRate: 0.0%
[+22998.0ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+22998.0ms] [L2 Steady] grayShown: 12, grayResolved: 105, pending: -93
[+22998.1ms] [L2 Steady] req: 129 (62.7/s), cancel: 105 (51.0/s), complete: 129 (62.7/s)
[+22998.1ms] [L2 Steady] degraded: 129, maxInFlight: 24
[+22998.2ms] [L2 Steady] latency avg: 35.3ms, p95: 211.7ms, max: 270.7ms
[+22998.2ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+22998.6ms] [R2:Timing] seq=31, velocity=10182pt/s, 디바운스=50ms
[+22999.3ms] [Pipeline] requestImage #10: +1.0ms
[+22999.7ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+23000.0ms] [Pipeline] requestImage #20: +1.8ms
[+23000.3ms] [R2] seq=31, visible=24, upgraded=24
[+23000.5ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+23000.7ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+23005.8ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+23182.5ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+23206.4ms] [Thumb:Check] seq=31, t=0.2s, velocity=10182, underSized=8/24
[+23621.5ms] [Thumb:Check] seq=31, t=0.6s, velocity=10182, underSized=0/24
```

---

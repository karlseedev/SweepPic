# 썸네일 고해상도 전환 원본 로그 #2

원본 로그 데이터를 저장하는 문서입니다.

> **요약은 \`260103thumbnailLog.md\`에 있습니다.**

---

<!-- LOG_ID: 260103_phase1_3 -->
## Phase 1 테스트 3 (2026-01-03 23:20)

```
=== PickPhoto Launch Log ===
Date: 2026-01-03 23:20:28
Device: iPhone14,2
============================
[+5.4ms] [LaunchArgs] didFinishLaunching: count=1
[+5.5ms] [LaunchArgs] --auto-scroll: false
[+7.2ms] [Env] Build: Release
[+7.2ms] [Env] LowPowerMode: OFF
[+7.2ms] [Env] PhotosAuth: authorized
[+7.4ms] [Config] deliveryMode: opportunistic
[+7.4ms] [Config] cancelPolicy: prepareForReuse
[+7.5ms] [Config] R2Recovery: disabled
[+68.8ms] [Timing] === 초기 로딩 시작 ===
[+99.3ms] [Timing] viewWillAppear: +30.4ms (초기 진입 - reloadData 스킵)
[+150.1ms] [Timing] C) 첫 레이아웃 완료: +81.3ms
[+164.5ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+170.1ms] [Preload] DISK HIT: F29EC2F9...
[+174.0ms] [Preload] DISK HIT: F0146B79...
[+177.5ms] [Preload] DISK HIT: 261056EB...
[+180.7ms] [Preload] DISK HIT: D10201EA...
[+185.7ms] [Preload] DISK HIT: 5FEA5EE7...
[+189.1ms] [Preload] DISK HIT: 7F2BACF6...
[+193.2ms] [Preload] DISK HIT: 5AE38379...
[+196.6ms] [Preload] DISK HIT: 2CD47CFB...
[+200.0ms] [Preload] DISK HIT: 48EC0DA1...
[+203.5ms] [Preload] DISK HIT: E0FEC1AD...
[+207.0ms] [Preload] DISK HIT: 82E65101...
[+210.6ms] [Preload] DISK HIT: 0EBF73ED...
[+210.6ms] [Timing] E0) finishInitialDisplay 시작: +141.8ms (reason: preload complete, preloaded: 12/12)
[+216.0ms] [Thumb:Req] #1 target=384x384px, fullSize=true
[+216.1ms] [Timing] D) 첫 셀 표시: +147.3ms (indexPath: [0, 0])
[+216.7ms] [Thumb:Req] #2 target=384x384px, fullSize=true
[+217.1ms] [Thumb:Req] #3 target=384x384px, fullSize=true
[+217.2ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+217.2ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+217.3ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+217.5ms] [Thumb:Req] #4 target=384x384px, fullSize=true
[+217.8ms] [Thumb:Req] #5 target=384x384px, fullSize=true
[+219.6ms] [Thumb:Req] #10 target=384x384px, fullSize=true
[+219.6ms] [Pipeline] requestImage #10: +212.1ms
[+226.9ms] [Timing] E1) reloadData+layout 완료: +158.1ms (E0→E1: 16.3ms)
[+228.4ms] [Thumb:Req] #20 target=384x384px, fullSize=true
[+228.5ms] [Pipeline] requestImage #20: +221.0ms
[+232.6ms] [Thumb:Req] #30 target=384x384px, fullSize=true
[+235.0ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+239.6ms] [Timing] E2) scrollToItem+layout 완료: +170.7ms (E1→E2: 12.6ms)
[+239.6ms] [Timing] === 초기 로딩 완료: +170.7ms (E0→E1: 16.3ms, E1→E2: 12.6ms) ===
[+239.6ms] [Timing] 최종 통계: cellForItemAt 36회, 총 18.2ms, 평균 0.51ms
[+239.6ms] [Initial Load] req: 24 (103.4/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+239.6ms] [Initial Load] degraded: 24, maxInFlight: 24
[+239.6ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+239.6ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+239.6ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+239.6ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+239.6ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+241.1ms] [Thumb:Res] #1 img=120x90px, target=384x384px, degraded=true
[+241.1ms] [Thumb:Res] #2 img=120x90px, target=384x384px, degraded=true
[+241.1ms] [Thumb:Res] #3 img=120x90px, target=384x384px, degraded=true
[+241.1ms] [Thumb:Res] #4 img=120x90px, target=384x384px, degraded=true
[+241.1ms] [Thumb:Res] #5 img=90x120px, target=384x384px, degraded=true
[+241.2ms] [Thumb:Res] #10 img=120x90px, target=384x384px, degraded=true
[+241.3ms] [Thumb:Res] #20 img=90x120px, target=384x384px, degraded=true
[+260.6ms] [Thumb:Res] #30 img=384x512px, target=384x384px, degraded=false
[+299.3ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+299.4ms] [Thumb:Res] #40 img=384x512px, target=384x384px, degraded=false
[+1570.8ms] [Scroll] First scroll 시작: +1501.7ms
[+1604.2ms] [Pipeline] completion #50 도달: +1596.7ms
[+1606.0ms] [Thumb:Res] #50 img=90x120px, target=192x192px, degraded=true
[+1606.6ms] [Thumb:Req] #40 target=192x192px, fullSize=false
[+1620.9ms] [Pipeline] requestImage #30: +1613.4ms
[+1625.5ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+1625.7ms] [Thumb:Res] #60 img=192x256px, target=192x192px, degraded=false
[+1665.7ms] [Thumb:Res] #70 img=192x256px, target=192x192px, degraded=false
[+1687.0ms] [Thumb:Req] #50 target=192x192px, fullSize=false
[+1716.0ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+1716.1ms] [Thumb:Res] #80 img=192x256px, target=192x192px, degraded=false
[+1757.2ms] [Thumb:Res] #90 img=192x256px, target=192x192px, degraded=false
[+1786.2ms] [Thumb:Req] #60 target=192x192px, fullSize=false
[+1816.8ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+1816.9ms] [Thumb:Res] #100 img=192x256px, target=192x192px, degraded=false
[+2272.3ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 118.3 (avg 8.33ms), frames: 83, dropped: 0, longest: 0 (0.0ms)
[+2272.4ms] [L1 First] memHit: 0, memMiss: 30, hitRate: 0.0%
[+2272.4ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+2272.5ms] [L1 First] grayShown: 2, grayResolved: 54, pending: -52
[+2272.5ms] [L1 First] req: 54 (23.8/s), cancel: 18 (7.9/s), complete: 54 (23.8/s)
[+2272.5ms] [L1 First] degraded: 54, maxInFlight: 24
[+2272.6ms] [L1 First] latency avg: 31.3ms, p95: 117.1ms, max: 119.9ms
[+2272.6ms] [L1 First] preheat: 0회, 총 0개 에셋
[+2272.6ms] [Scroll] First scroll 완료: 702.1ms 동안 스크롤
[+2273.2ms] [R2:Timing] seq=2, velocity=3055pt/s, 디바운스=50ms
[+2274.1ms] [Pipeline] requestImage #10: +1.4ms
[+2274.4ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+2274.4ms] [Pipeline] #1 target=384x384px → img=68x120px (18%), degraded=true
[+2274.6ms] [R2] seq=2, visible=24, upgraded=18
[+2275.1ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+2300.6ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+2484.7ms] [Thumb:Check] seq=2, t=0.2s, velocity=3055, underSized=14/24
[+2902.4ms] [Thumb:Check] seq=2, t=0.6s, velocity=3055, underSized=0/24
[+3654.8ms] [Pipeline] requestImage #20: +1382.1ms
[+3656.1ms] [Thumb:Res] #110 img=90x120px, target=192x192px, degraded=true
[+3662.4ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+3712.3ms] [Thumb:Req] #70 target=192x192px, fullSize=false
[+3734.3ms] [Thumb:Res] #120 img=192x256px, target=192x192px, degraded=false
[+3768.5ms] [Pipeline] completion #50 도달: +1495.8ms
[+3818.1ms] [Thumb:Res] #130 img=192x256px, target=192x192px, degraded=false
[+3820.3ms] [Pipeline] requestImage #30: +1547.6ms
[+3825.7ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+3871.1ms] [Thumb:Req] #80 target=192x192px, fullSize=false
[+4162.3ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.1 (avg 8.33ms), frames: 64, dropped: 0, longest: 0 (0.0ms)
[+4162.4ms] [L2 Steady] memHit: 0, memMiss: 15, hitRate: 0.0%
[+4162.5ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+4162.5ms] [L2 Steady] grayShown: 0, grayResolved: 15, pending: -15
[+4162.5ms] [L2 Steady] req: 33 (17.5/s), cancel: 9 (4.8/s), complete: 33 (17.5/s)
[+4162.6ms] [L2 Steady] degraded: 33, maxInFlight: 18
[+4162.6ms] [L2 Steady] latency avg: 126.7ms, p95: 299.2ms, max: 428.3ms
[+4162.6ms] [L2 Steady] preheat: 1회, 총 57개 에셋
[+4163.0ms] [R2:Timing] seq=4, velocity=3019pt/s, 디바운스=50ms
[+4163.8ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+4163.8ms] [Pipeline] requestImage #10: +1.2ms
[+4164.1ms] [Pipeline] #2 target=384x384px → img=384x683px (100%), degraded=false
[+4164.2ms] [R2] seq=4, visible=24, upgraded=15
[+4164.4ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+4368.9ms] [Thumb:Check] seq=4, t=0.2s, velocity=3019, underSized=0/24
[+4769.2ms] [Thumb:Check] seq=4, t=0.6s, velocity=3019, underSized=0/24
[+5490.0ms] [Thumb:Res] #140 img=90x120px, target=192x192px, degraded=true
[+5496.7ms] [Pipeline] #20 target=192x192px → img=192x256px (100%), degraded=false
[+5555.1ms] [Pipeline] requestImage #20: +1392.4ms
[+5567.9ms] [Thumb:Res] #150 img=192x256px, target=192x192px, degraded=false
[+5603.9ms] [Thumb:Req] #90 target=192x192px, fullSize=false
[+5643.1ms] [Thumb:Res] #160 img=192x256px, target=192x192px, degraded=false
[+5689.8ms] [Pipeline] #40 target=192x192px → img=90x120px (47%), degraded=true
[+5703.4ms] [Pipeline] requestImage #30: +1540.7ms
[+5904.1ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 117.8 (avg 8.33ms), frames: 53, dropped: 0, longest: 0 (0.0ms)
[+5904.2ms] [L2 Steady] memHit: 0, memMiss: 15, hitRate: 0.0%
[+5904.2ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+5904.2ms] [L2 Steady] grayShown: 0, grayResolved: 15, pending: -15
[+5904.3ms] [L2 Steady] req: 30 (17.2/s), cancel: 15 (8.6/s), complete: 30 (17.2/s)
[+5904.3ms] [L2 Steady] degraded: 15, maxInFlight: 13
[+5904.3ms] [L2 Steady] latency avg: 3.7ms, p95: 8.0ms, max: 9.6ms
[+5904.3ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+5904.7ms] [R2:Timing] seq=6, velocity=3265pt/s, 디바운스=50ms
[+5905.2ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+5905.2ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+5905.2ms] [Pipeline] requestImage #10: +0.9ms
[+5905.5ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+5905.6ms] [R2] seq=6, visible=24, upgraded=15
[+6116.0ms] [Thumb:Check] seq=6, t=0.2s, velocity=3265, underSized=0/24
[+6520.9ms] [Thumb:Check] seq=6, t=0.6s, velocity=3265, underSized=0/24
[+8073.3ms] [Thumb:Res] #170 img=90x120px, target=192x192px, degraded=true
[+8081.9ms] [Pipeline] #20 target=192x192px → img=90x120px (47%), degraded=true
[+8096.1ms] [Thumb:Req] #100 target=192x192px, fullSize=false
[+8104.1ms] [Pipeline] requestImage #20: +2199.7ms
[+8117.2ms] [Thumb:Res] #180 img=192x256px, target=192x192px, degraded=false
[+8166.7ms] [Thumb:Res] #190 img=192x256px, target=192x192px, degraded=false
[+8174.5ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+8178.7ms] [Thumb:Req] #110 target=192x192px, fullSize=false
[+8186.5ms] [Pipeline] requestImage #30: +2282.1ms
[+8192.1ms] [Thumb:Res] #200 img=192x256px, target=192x192px, degraded=false
[+8203.6ms] [Pipeline] completion #50 도달: +2299.2ms
[+8222.9ms] [Thumb:Res] #210 img=256x192px, target=192x192px, degraded=false
[+8236.6ms] [Thumb:Req] #120 target=192x192px, fullSize=false
[+8236.7ms] [Pipeline] #60 target=192x192px → img=68x120px (35%), degraded=true
[+8248.1ms] [Thumb:Res] #220 img=192x256px, target=192x192px, degraded=false
[+8281.9ms] [Thumb:Res] #230 img=192x341px, target=192x192px, degraded=false
[+8295.0ms] [Pipeline] #80 target=192x192px → img=68x120px (35%), degraded=true
[+8303.5ms] [Thumb:Req] #130 target=192x192px, fullSize=false
[+8323.2ms] [Thumb:Res] #240 img=192x341px, target=192x192px, degraded=false
[+8357.4ms] [Thumb:Res] #250 img=192x341px, target=192x192px, degraded=false
[+8370.1ms] [Pipeline] #100 target=192x192px → img=120x68px (62%), degraded=true
[+8378.2ms] [Thumb:Req] #140 target=192x192px, fullSize=false
[+8398.2ms] [Thumb:Res] #260 img=256x192px, target=192x192px, degraded=false
[+8449.0ms] [Thumb:Res] #270 img=256x192px, target=192x192px, degraded=false
[+8463.0ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+8470.5ms] [Thumb:Req] #150 target=192x192px, fullSize=false
[+8491.3ms] [Thumb:Res] #280 img=192x256px, target=192x192px, degraded=false
[+8543.7ms] [Thumb:Res] #290 img=192x341px, target=192x192px, degraded=false
[+8554.6ms] [Pipeline] #140 target=192x192px → img=90x120px (47%), degraded=true
[+8562.3ms] [Thumb:Req] #160 target=192x192px, fullSize=false
[+8585.1ms] [Thumb:Res] #300 img=192x341px, target=192x192px, degraded=false
[+8623.4ms] [Thumb:Res] #310 img=256x192px, target=192x192px, degraded=false
[+8646.0ms] [Pipeline] #160 target=192x192px → img=120x90px (62%), degraded=true
[+8653.5ms] [Thumb:Req] #170 target=192x192px, fullSize=false
[+8679.6ms] [Thumb:Res] #320 img=192x256px, target=192x192px, degraded=false
[+8791.4ms] [Thumb:Res] #330 img=192x256px, target=192x192px, degraded=false
[+8954.3ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.9 (avg 8.33ms), frames: 109, dropped: 0, longest: 0 (0.0ms)
[+8954.4ms] [L2 Steady] memHit: 0, memMiss: 81, hitRate: 0.0%
[+8954.4ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+8954.5ms] [L2 Steady] grayShown: 9, grayResolved: 81, pending: -72
[+8954.6ms] [L2 Steady] req: 96 (31.5/s), cancel: 81 (26.6/s), complete: 96 (31.5/s)
[+8954.6ms] [L2 Steady] degraded: 81, maxInFlight: 12
[+8954.6ms] [L2 Steady] latency avg: 3.8ms, p95: 7.7ms, max: 9.3ms
[+8954.7ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+8955.1ms] [R2:Timing] seq=9, velocity=9473pt/s, 디바운스=50ms
[+8955.7ms] [Pipeline] requestImage #10: +1.0ms
[+8956.1ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+8956.1ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+8956.3ms] [Pipeline] requestImage #20: +1.6ms
[+8956.4ms] [R2] seq=9, visible=21, upgraded=21
[+8956.8ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+8962.0ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+9162.6ms] [Thumb:Check] seq=9, t=0.2s, velocity=9473, underSized=15/21
[+9282.5ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+9569.6ms] [Thumb:Check] seq=9, t=0.6s, velocity=9473, underSized=0/21
[+10347.4ms] [Thumb:Req] #180 target=192x192px, fullSize=false
[+10368.0ms] [Pipeline] completion #50 도달: +1413.3ms
[+10375.3ms] [Thumb:Res] #340 img=192x256px, target=192x192px, degraded=false
[+10403.6ms] [Pipeline] requestImage #30: +1448.9ms
[+10407.8ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+10426.0ms] [Thumb:Res] #350 img=192x256px, target=192x192px, degraded=false
[+10445.7ms] [Thumb:Req] #190 target=192x192px, fullSize=false
[+10466.8ms] [Thumb:Res] #360 img=192x341px, target=192x192px, degraded=false
[+10491.1ms] [Pipeline] #80 target=192x192px → img=192x341px (100%), degraded=false
[+10498.3ms] [Thumb:Res] #370 img=192x256px, target=192x192px, degraded=false
[+10528.2ms] [Thumb:Req] #200 target=192x192px, fullSize=false
[+10542.7ms] [Thumb:Res] #380 img=192x341px, target=192x192px, degraded=false
[+10565.1ms] [Pipeline] #100 target=192x192px → img=256x192px (133%), degraded=false
[+10573.2ms] [Thumb:Res] #390 img=256x192px, target=192x192px, degraded=false
[+10595.0ms] [Thumb:Req] #210 target=192x192px, fullSize=false
[+10615.1ms] [Thumb:Res] #400 img=256x192px, target=192x192px, degraded=false
[+10657.8ms] [Pipeline] #120 target=192x192px → img=256x192px (133%), degraded=false
[+10665.2ms] [Thumb:Res] #410 img=192x256px, target=192x192px, degraded=false
[+10686.6ms] [Thumb:Req] #220 target=192x192px, fullSize=false
[+10706.5ms] [Thumb:Res] #420 img=192x256px, target=192x192px, degraded=false
[+10749.4ms] [Pipeline] #140 target=192x192px → img=256x192px (133%), degraded=false
[+10756.3ms] [Thumb:Res] #430 img=192x256px, target=192x192px, degraded=false
[+10779.2ms] [Thumb:Req] #230 target=192x192px, fullSize=false
[+10798.2ms] [Thumb:Res] #440 img=192x256px, target=192x192px, degraded=false
[+10834.7ms] [Pipeline] #160 target=192x192px → img=256x192px (133%), degraded=false
[+10921.1ms] [Thumb:Res] #450 img=192x256px, target=192x192px, degraded=false
[+10945.5ms] [Thumb:Req] #240 target=192x192px, fullSize=false
[+10971.2ms] [Thumb:Res] #460 img=192x341px, target=192x192px, degraded=false
[+11146.1ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 100, dropped: 0, longest: 0 (0.0ms)
[+11146.2ms] [L2 Steady] memHit: 0, memMiss: 66, hitRate: 0.0%
[+11146.2ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+11146.2ms] [L2 Steady] grayShown: 3, grayResolved: 66, pending: -63
[+11146.3ms] [L2 Steady] req: 87 (39.7/s), cancel: 66 (30.1/s), complete: 87 (39.7/s)
[+11146.3ms] [L2 Steady] degraded: 87, maxInFlight: 21
[+11146.4ms] [L2 Steady] latency avg: 62.0ms, p95: 318.2ms, max: 335.6ms
[+11146.4ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+11146.8ms] [R2:Timing] seq=12, velocity=10006pt/s, 디바운스=50ms
[+11147.4ms] [Pipeline] requestImage #10: +1.0ms
[+11147.9ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+11148.0ms] [Pipeline] requestImage #20: +1.6ms
[+11148.1ms] [R2] seq=12, visible=21, upgraded=21
[+11148.7ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+11149.3ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+11151.8ms] [Pipeline] #20 target=384x384px → img=120x90px (31%), degraded=true
[+11354.5ms] [Thumb:Check] seq=12, t=0.2s, velocity=10006, underSized=9/21
[+11455.8ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+11769.8ms] [Thumb:Check] seq=12, t=0.6s, velocity=10006, underSized=0/21
[+12551.8ms] [Pipeline] completion #50 도달: +1405.4ms
[+12552.0ms] [Thumb:Res] #470 img=192x256px, target=192x192px, degraded=false
[+12571.5ms] [Thumb:Req] #250 target=192x192px, fullSize=false
[+12587.1ms] [Pipeline] requestImage #30: +1440.7ms
[+12590.8ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+12590.9ms] [Thumb:Res] #480 img=192x256px, target=192x192px, degraded=false
[+12640.3ms] [Thumb:Res] #490 img=192x256px, target=192x192px, degraded=false
[+12653.7ms] [Thumb:Req] #260 target=192x192px, fullSize=false
[+12666.0ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+12666.1ms] [Thumb:Res] #500 img=192x256px, target=192x192px, degraded=false
[+12708.1ms] [Thumb:Res] #510 img=192x256px, target=192x192px, degraded=false
[+12720.0ms] [Thumb:Req] #270 target=192x192px, fullSize=false
[+12740.1ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+12740.2ms] [Thumb:Res] #520 img=192x256px, target=192x192px, degraded=false
[+12773.6ms] [Thumb:Res] #530 img=192x256px, target=192x192px, degraded=false
[+12804.3ms] [Thumb:Req] #280 target=192x192px, fullSize=false
[+12821.0ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+12821.1ms] [Thumb:Res] #540 img=90x120px, target=192x192px, degraded=true
[+12858.2ms] [Thumb:Res] #550 img=256x192px, target=192x192px, degraded=false
[+12878.6ms] [Thumb:Req] #290 target=192x192px, fullSize=false
[+12899.8ms] [Pipeline] #140 target=192x192px → img=256x192px (133%), degraded=false
[+12899.9ms] [Thumb:Res] #560 img=256x192px, target=192x192px, degraded=false
[+12959.4ms] [Thumb:Res] #570 img=256x192px, target=192x192px, degraded=false
[+13045.6ms] [Thumb:Req] #300 target=192x192px, fullSize=false
[+13067.1ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+13067.3ms] [Thumb:Res] #580 img=192x256px, target=192x192px, degraded=false
[+13116.6ms] [Thumb:Res] #590 img=192x256px, target=192x192px, degraded=false
[+13188.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.6 (avg 8.33ms), frames: 83, dropped: 0, longest: 0 (0.0ms)
[+13188.0ms] [L2 Steady] memHit: 0, memMiss: 66, hitRate: 0.0%
[+13188.1ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+13188.1ms] [L2 Steady] grayShown: 6, grayResolved: 66, pending: -60
[+13188.1ms] [L2 Steady] req: 87 (42.6/s), cancel: 66 (32.3/s), complete: 87 (42.6/s)
[+13188.2ms] [L2 Steady] degraded: 87, maxInFlight: 21
[+13188.2ms] [L2 Steady] latency avg: 54.3ms, p95: 300.2ms, max: 315.5ms
[+13188.2ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+13188.5ms] [R2:Timing] seq=15, velocity=11243pt/s, 디바운스=50ms
[+13189.1ms] [Pipeline] requestImage #10: +0.9ms
[+13189.5ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+13189.5ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+13189.5ms] [Pipeline] requestImage #20: +1.3ms
[+13189.6ms] [R2] seq=15, visible=21, upgraded=21
[+13190.2ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+13194.3ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+13397.2ms] [Thumb:Check] seq=15, t=0.2s, velocity=11243, underSized=9/21
[+13526.1ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+13803.3ms] [Thumb:Check] seq=15, t=0.6s, velocity=11243, underSized=0/21
[+14647.0ms] [Thumb:Req] #310 target=192x192px, fullSize=false
[+14669.8ms] [Thumb:Res] #600 img=192x256px, target=192x192px, degraded=false
[+14685.3ms] [Pipeline] completion #50 도달: +1497.0ms
[+14716.8ms] [Thumb:Res] #610 img=192x256px, target=192x192px, degraded=false
[+14721.4ms] [Pipeline] requestImage #30: +1533.1ms
[+14725.6ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+14746.0ms] [Thumb:Req] #320 target=192x192px, fullSize=false
[+14768.3ms] [Thumb:Res] #620 img=192x341px, target=192x192px, degraded=false
[+14808.9ms] [Thumb:Res] #630 img=192x341px, target=192x192px, degraded=false
[+14824.2ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+14836.8ms] [Thumb:Req] #330 target=192x192px, fullSize=false
[+14849.0ms] [Thumb:Res] #640 img=192x256px, target=192x192px, degraded=false
[+14892.9ms] [Thumb:Res] #650 img=192x256px, target=192x192px, degraded=false
[+14900.1ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+14937.7ms] [Thumb:Req] #340 target=192x192px, fullSize=false
[+14958.1ms] [Thumb:Res] #660 img=192x256px, target=192x192px, degraded=false
[+14982.4ms] [Thumb:Res] #670 img=192x256px, target=192x192px, degraded=false
[+14988.1ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+14995.2ms] [Thumb:Req] #350 target=192x192px, fullSize=false
[+15007.5ms] [Thumb:Res] #680 img=192x256px, target=192x192px, degraded=false
[+15029.5ms] [Thumb:Res] #690 img=90x120px, target=192x192px, degraded=true
[+15032.6ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+15045.2ms] [Thumb:Req] #360 target=192x192px, fullSize=false
[+15057.3ms] [Thumb:Res] #700 img=192x256px, target=192x192px, degraded=false
[+15076.3ms] [Thumb:Res] #710 img=256x192px, target=192x192px, degraded=false
[+15082.2ms] [Pipeline] #160 target=192x192px → img=256x192px (133%), degraded=false
[+15087.5ms] [Thumb:Req] #370 target=192x192px, fullSize=false
[+15104.7ms] [Thumb:Res] #720 img=68x120px, target=192x192px, degraded=true
[+15132.1ms] [Thumb:Res] #730 img=192x256px, target=192x192px, degraded=false
[+15140.1ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+15161.7ms] [Thumb:Req] #380 target=192x192px, fullSize=false
[+15167.7ms] [Thumb:Res] #740 img=256x192px, target=192x192px, degraded=false
[+15200.7ms] [Thumb:Res] #750 img=256x192px, target=192x192px, degraded=false
[+15224.4ms] [Pipeline] #200 target=192x192px → img=256x192px (133%), degraded=false
[+15237.4ms] [Thumb:Req] #390 target=192x192px, fullSize=false
[+15254.3ms] [Thumb:Res] #760 img=120x90px, target=192x192px, degraded=true
[+15276.3ms] [Thumb:Res] #770 img=192x341px, target=192x192px, degraded=false
[+15278.8ms] [Pipeline] #220 target=192x192px → img=90x120px (47%), degraded=true
[+15279.5ms] [Thumb:Req] #400 target=192x192px, fullSize=false
[+15290.8ms] [Thumb:Res] #780 img=192x256px, target=192x192px, degraded=false
[+15312.7ms] [Thumb:Res] #790 img=90x120px, target=192x192px, degraded=true
[+15315.6ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+15328.5ms] [Thumb:Req] #410 target=192x192px, fullSize=false
[+15333.4ms] [Thumb:Res] #800 img=192x256px, target=192x192px, degraded=false
[+15354.4ms] [Thumb:Res] #810 img=90x120px, target=192x192px, degraded=true
[+15357.2ms] [Pipeline] #260 target=192x192px → img=192x256px (100%), degraded=false
[+15370.1ms] [Thumb:Req] #420 target=192x192px, fullSize=false
[+15379.8ms] [Thumb:Res] #820 img=90x120px, target=192x192px, degraded=true
[+15398.9ms] [Thumb:Res] #830 img=192x256px, target=192x192px, degraded=false
[+15406.9ms] [Pipeline] #280 target=192x192px → img=192x256px (100%), degraded=false
[+15412.5ms] [Thumb:Req] #430 target=192x192px, fullSize=false
[+15429.6ms] [Thumb:Res] #840 img=90x120px, target=192x192px, degraded=true
[+15462.6ms] [Thumb:Res] #850 img=90x120px, target=192x192px, degraded=true
[+15465.6ms] [Pipeline] #300 target=192x192px → img=192x256px (100%), degraded=false
[+15470.6ms] [Thumb:Req] #440 target=192x192px, fullSize=false
[+15482.6ms] [Thumb:Res] #860 img=192x256px, target=192x192px, degraded=false
[+15512.8ms] [Thumb:Res] #870 img=90x120px, target=192x192px, degraded=true
[+15515.8ms] [Pipeline] #320 target=192x192px → img=192x256px (100%), degraded=false
[+15528.4ms] [Thumb:Req] #450 target=192x192px, fullSize=false
[+15548.8ms] [Thumb:Res] #880 img=192x256px, target=192x192px, degraded=false
[+15574.1ms] [Thumb:Res] #890 img=192x256px, target=192x192px, degraded=false
[+15582.5ms] [Pipeline] #340 target=192x192px → img=192x256px (100%), degraded=false
[+15595.5ms] [Thumb:Req] #460 target=192x192px, fullSize=false
[+15615.1ms] [Thumb:Res] #900 img=192x256px, target=192x192px, degraded=false
[+15649.1ms] [Thumb:Res] #910 img=192x256px, target=192x192px, degraded=false
[+15657.2ms] [Pipeline] #360 target=192x192px → img=192x256px (100%), degraded=false
[+15670.5ms] [Thumb:Req] #470 target=192x192px, fullSize=false
[+15690.5ms] [Thumb:Res] #920 img=192x256px, target=192x192px, degraded=false
[+15733.4ms] [Thumb:Res] #930 img=192x256px, target=192x192px, degraded=false
[+15749.8ms] [Pipeline] #380 target=192x192px → img=192x256px (100%), degraded=false
[+15762.2ms] [Thumb:Req] #480 target=192x192px, fullSize=false
[+15782.0ms] [Thumb:Res] #940 img=192x256px, target=192x192px, degraded=false
[+15823.8ms] [Thumb:Res] #950 img=192x256px, target=192x192px, degraded=false
[+15832.0ms] [Pipeline] #400 target=192x192px → img=192x256px (100%), degraded=false
[+15854.6ms] [Thumb:Req] #490 target=192x192px, fullSize=false
[+15874.2ms] [Thumb:Res] #960 img=192x256px, target=192x192px, degraded=false
[+15923.1ms] [Thumb:Res] #970 img=192x256px, target=192x192px, degraded=false
[+15931.6ms] [Pipeline] #420 target=192x192px → img=192x256px (100%), degraded=false
[+15953.7ms] [Thumb:Req] #500 target=192x192px, fullSize=false
[+15973.4ms] [Thumb:Res] #980 img=256x192px, target=192x192px, degraded=false
[+16032.8ms] [Thumb:Res] #990 img=192x256px, target=192x192px, degraded=false
[+16051.0ms] [Pipeline] #440 target=192x192px → img=192x256px (100%), degraded=false
[+16062.1ms] [Thumb:Req] #510 target=192x192px, fullSize=false
[+16072.3ms] [Thumb:Res] #1000 img=68x120px, target=192x192px, degraded=true
[+16080.1ms] [Thumb:Res] #1010 img=68x120px, target=192x192px, degraded=true
[+16080.5ms] [Thumb:Req] #520 target=192x192px, fullSize=false
[+16080.9ms] [Pipeline] #460 target=192x192px → img=68x120px (35%), degraded=true
[+16090.6ms] [Thumb:Res] #1020 img=192x256px, target=192x192px, degraded=false
[+16103.9ms] [Thumb:Req] #530 target=192x192px, fullSize=false
[+16104.2ms] [Pipeline] #480 target=192x192px → img=120x90px (62%), degraded=true
[+16104.8ms] [Thumb:Res] #1030 img=90x120px, target=192x192px, degraded=true
[+16113.4ms] [Thumb:Res] #1040 img=90x120px, target=192x192px, degraded=true
[+16124.5ms] [Thumb:Res] #1050 img=192x256px, target=192x192px, degraded=false
[+16125.3ms] [Pipeline] #500 target=192x192px → img=192x256px (100%), degraded=false
[+16128.6ms] [Thumb:Req] #540 target=192x192px, fullSize=false
[+16137.6ms] [Thumb:Res] #1060 img=90x120px, target=192x192px, degraded=true
[+16149.4ms] [Thumb:Res] #1070 img=192x256px, target=192x192px, degraded=false
[+16153.8ms] [Pipeline] #520 target=192x192px → img=90x120px (47%), degraded=true
[+16161.8ms] [Thumb:Req] #550 target=192x192px, fullSize=false
[+16166.2ms] [Thumb:Res] #1080 img=192x256px, target=192x192px, degraded=false
[+16179.5ms] [Thumb:Res] #1090 img=68x120px, target=192x192px, degraded=true
[+16182.7ms] [Pipeline] #540 target=192x192px → img=192x256px (100%), degraded=false
[+16186.8ms] [Thumb:Req] #560 target=192x192px, fullSize=false
[+16190.5ms] [Thumb:Res] #1100 img=192x256px, target=192x192px, degraded=false
[+16206.9ms] [Thumb:Res] #1110 img=192x256px, target=192x192px, degraded=false
[+16207.6ms] [Pipeline] #560 target=192x192px → img=256x192px (133%), degraded=false
[+16211.9ms] [Thumb:Req] #570 target=192x192px, fullSize=false
[+16220.8ms] [Thumb:Res] #1120 img=120x90px, target=192x192px, degraded=true
[+16232.2ms] [Thumb:Res] #1130 img=192x256px, target=192x192px, degraded=false
[+16237.0ms] [Pipeline] #580 target=192x192px → img=120x90px (62%), degraded=true
[+16245.1ms] [Thumb:Req] #580 target=192x192px, fullSize=false
[+16248.9ms] [Thumb:Res] #1140 img=192x256px, target=192x192px, degraded=false
[+16262.5ms] [Thumb:Res] #1150 img=90x120px, target=192x192px, degraded=true
[+16264.9ms] [Pipeline] #600 target=192x192px → img=192x256px (100%), degraded=false
[+16270.1ms] [Thumb:Req] #590 target=192x192px, fullSize=false
[+16274.0ms] [Thumb:Res] #1160 img=192x256px, target=192x192px, degraded=false
[+16298.7ms] [Thumb:Res] #1170 img=192x256px, target=192x192px, degraded=false
[+16299.3ms] [Pipeline] #620 target=192x192px → img=192x256px (100%), degraded=false
[+16303.5ms] [Thumb:Req] #600 target=192x192px, fullSize=false
[+16312.6ms] [Thumb:Res] #1180 img=90x120px, target=192x192px, degraded=true
[+16331.6ms] [Thumb:Res] #1190 img=192x256px, target=192x192px, degraded=false
[+16337.2ms] [Pipeline] #640 target=192x192px → img=90x120px (47%), degraded=true
[+16345.1ms] [Thumb:Req] #610 target=192x192px, fullSize=false
[+16348.9ms] [Thumb:Res] #1200 img=192x256px, target=192x192px, degraded=false
[+16371.3ms] [Thumb:Res] #1210 img=120x90px, target=192x192px, degraded=true
[+16373.9ms] [Pipeline] #660 target=192x192px → img=256x192px (133%), degraded=false
[+16378.9ms] [Thumb:Req] #620 target=192x192px, fullSize=false
[+16390.0ms] [Thumb:Res] #1220 img=192x256px, target=192x192px, degraded=false
[+16492.4ms] [Thumb:Res] #1230 img=192x256px, target=192x192px, degraded=false
[+16499.9ms] [Pipeline] #680 target=192x192px → img=192x256px (100%), degraded=false
[+16512.2ms] [Thumb:Req] #630 target=192x192px, fullSize=false
[+16533.5ms] [Thumb:Res] #1240 img=256x192px, target=192x192px, degraded=false
[+16575.1ms] [Thumb:Res] #1250 img=192x341px, target=192x192px, degraded=false
[+16582.8ms] [Pipeline] #700 target=192x192px → img=192x341px (100%), degraded=false
[+16746.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.5 (avg 8.33ms), frames: 254, dropped: 0, longest: 0 (0.0ms)
[+16746.7ms] [L2 Steady] memHit: 0, memMiss: 330, hitRate: 0.0%
[+16746.7ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+16746.7ms] [L2 Steady] grayShown: 137, grayResolved: 330, pending: -193
[+16746.8ms] [L2 Steady] req: 351 (98.6/s), cancel: 330 (92.7/s), complete: 351 (98.6/s)
[+16746.9ms] [L2 Steady] degraded: 351, maxInFlight: 21
[+16746.9ms] [L2 Steady] latency avg: 16.1ms, p95: 96.9ms, max: 353.7ms
[+16746.9ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+16747.3ms] [R2:Timing] seq=21, velocity=20761pt/s, 디바운스=50ms
[+16748.0ms] [Pipeline] requestImage #10: +1.1ms
[+16748.5ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+16748.6ms] [Pipeline] requestImage #20: +1.7ms
[+16748.9ms] [R2] seq=21, visible=24, upgraded=24
[+16749.2ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+16749.8ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+16753.3ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+16953.5ms] [Thumb:Check] seq=21, t=0.2s, velocity=20761, underSized=9/24
[+17022.6ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+17370.3ms] [Thumb:Check] seq=21, t=0.6s, velocity=20761, underSized=0/24
[+17738.6ms] [Thumb:Req] #640 target=192x192px, fullSize=false
[+17748.7ms] [Pipeline] completion #50 도달: +1001.7ms
[+17765.1ms] [Thumb:Res] #1260 img=192x341px, target=192x192px, degraded=false
[+17787.7ms] [Pipeline] requestImage #30: +1040.7ms
[+17792.3ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+17817.2ms] [Thumb:Res] #1270 img=192x256px, target=192x192px, degraded=false
[+17837.3ms] [Thumb:Req] #650 target=192x192px, fullSize=false
[+17867.1ms] [Thumb:Res] #1280 img=192x256px, target=192x192px, degraded=false
[+17890.5ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+17908.6ms] [Thumb:Res] #1290 img=192x256px, target=192x192px, degraded=false
[+17954.9ms] [Thumb:Req] #660 target=192x192px, fullSize=false
[+17975.9ms] [Thumb:Res] #1300 img=192x341px, target=192x192px, degraded=false
[+18008.2ms] [Pipeline] #100 target=192x192px → img=192x341px (100%), degraded=false
[+18023.8ms] [Thumb:Res] #1310 img=192x256px, target=192x192px, degraded=false
[+18053.8ms] [Thumb:Req] #670 target=192x192px, fullSize=false
[+18074.2ms] [Thumb:Res] #1320 img=192x256px, target=192x192px, degraded=false
[+18096.5ms] [Pipeline] #120 target=192x192px → img=68x120px (35%), degraded=true
[+18107.6ms] [Thumb:Res] #1330 img=192x256px, target=192x192px, degraded=false
[+18129.0ms] [Thumb:Req] #680 target=192x192px, fullSize=false
[+18149.0ms] [Thumb:Res] #1340 img=192x256px, target=192x192px, degraded=false
[+18165.8ms] [Pipeline] #140 target=192x192px → img=256x192px (133%), degraded=false
[+18199.4ms] [Thumb:Res] #1350 img=192x256px, target=192x192px, degraded=false
[+18220.7ms] [Thumb:Req] #690 target=192x192px, fullSize=false
[+18232.6ms] [Thumb:Res] #1360 img=192x256px, target=192x192px, degraded=false
[+18254.3ms] [Pipeline] #160 target=192x192px → img=90x120px (47%), degraded=true
[+18262.9ms] [Thumb:Res] #1370 img=90x120px, target=192x192px, degraded=true
[+18263.0ms] [Thumb:Req] #700 target=192x192px, fullSize=false
[+18279.7ms] [Thumb:Res] #1380 img=90x120px, target=192x192px, degraded=true
[+18290.6ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+18298.8ms] [Thumb:Res] #1390 img=192x256px, target=192x192px, degraded=false
[+18312.5ms] [Thumb:Req] #710 target=192x192px, fullSize=false
[+18332.0ms] [Thumb:Res] #1400 img=256x192px, target=192x192px, degraded=false
[+18341.4ms] [Pipeline] #200 target=192x192px → img=256x192px (133%), degraded=false
[+18354.8ms] [Thumb:Res] #1410 img=120x90px, target=192x192px, degraded=true
[+18370.4ms] [Thumb:Req] #720 target=192x192px, fullSize=false
[+18382.1ms] [Thumb:Res] #1420 img=256x192px, target=192x192px, degraded=false
[+18400.2ms] [Pipeline] #220 target=192x192px → img=192x341px (100%), degraded=false
[+18415.6ms] [Thumb:Res] #1430 img=192x256px, target=192x192px, degraded=false
[+18454.4ms] [Thumb:Req] #730 target=192x192px, fullSize=false
[+18472.2ms] [Thumb:Res] #1440 img=68x120px, target=192x192px, degraded=true
[+18482.3ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+18488.2ms] [Thumb:Res] #1450 img=90x120px, target=192x192px, degraded=true
[+18495.4ms] [Thumb:Req] #740 target=192x192px, fullSize=false
[+18504.8ms] [Thumb:Res] #1460 img=90x120px, target=192x192px, degraded=true
[+18508.8ms] [Pipeline] #260 target=192x192px → img=192x256px (100%), degraded=false
[+18515.7ms] [Thumb:Res] #1470 img=192x256px, target=192x192px, degraded=false
[+18520.5ms] [Thumb:Req] #750 target=192x192px, fullSize=false
[+18530.0ms] [Thumb:Res] #1480 img=90x120px, target=192x192px, degraded=true
[+18537.4ms] [Pipeline] #280 target=192x192px → img=90x120px (47%), degraded=true
[+18546.4ms] [Thumb:Res] #1490 img=120x90px, target=192x192px, degraded=true
[+18546.6ms] [Thumb:Req] #760 target=192x192px, fullSize=false
[+18563.1ms] [Thumb:Res] #1500 img=120x90px, target=192x192px, degraded=true
[+18573.7ms] [Pipeline] #300 target=192x192px → img=256x192px (133%), degraded=false
[+18579.6ms] [Thumb:Res] #1510 img=90x120px, target=192x192px, degraded=true
[+18587.1ms] [Thumb:Req] #770 target=192x192px, fullSize=false
[+18596.7ms] [Thumb:Res] #1520 img=90x120px, target=192x192px, degraded=true
[+18601.0ms] [Pipeline] #320 target=192x192px → img=192x256px (100%), degraded=false
[+18607.1ms] [Thumb:Res] #1530 img=192x256px, target=192x192px, degraded=false
[+18620.4ms] [Thumb:Req] #780 target=192x192px, fullSize=false
[+18629.4ms] [Thumb:Res] #1540 img=90x120px, target=192x192px, degraded=true
[+18637.3ms] [Pipeline] #340 target=192x192px → img=90x120px (47%), degraded=true
[+18650.0ms] [Thumb:Res] #1550 img=192x341px, target=192x192px, degraded=false
[+18655.0ms] [Thumb:Req] #790 target=192x192px, fullSize=false
[+18666.8ms] [Thumb:Res] #1560 img=192x256px, target=192x192px, degraded=false
[+18673.6ms] [Pipeline] #360 target=192x192px → img=192x256px (100%), degraded=false
[+18682.1ms] [Thumb:Res] #1570 img=192x256px, target=192x192px, degraded=false
[+18695.3ms] [Thumb:Req] #800 target=192x192px, fullSize=false
[+18707.1ms] [Thumb:Res] #1580 img=192x256px, target=192x192px, degraded=false
[+18716.3ms] [Pipeline] #380 target=192x192px → img=192x256px (100%), degraded=false
[+18723.8ms] [Thumb:Res] #1590 img=192x256px, target=192x192px, degraded=false
[+18737.0ms] [Thumb:Req] #810 target=192x192px, fullSize=false
[+18746.1ms] [Thumb:Res] #1600 img=120x90px, target=192x192px, degraded=true
[+18757.2ms] [Pipeline] #400 target=192x192px → img=192x256px (100%), degraded=false
[+18774.1ms] [Thumb:Res] #1610 img=256x192px, target=192x192px, degraded=false
[+18779.4ms] [Thumb:Req] #820 target=192x192px, fullSize=false
[+18799.6ms] [Thumb:Res] #1620 img=256x192px, target=192x192px, degraded=false
[+18901.3ms] [Pipeline] #420 target=192x192px → img=256x192px (133%), degraded=false
[+18918.4ms] [Thumb:Res] #1630 img=192x256px, target=192x192px, degraded=false
[+18938.4ms] [Thumb:Req] #830 target=192x192px, fullSize=false
[+18967.9ms] [Thumb:Res] #1640 img=192x256px, target=192x192px, degraded=false
[+19196.8ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.3 (avg 8.33ms), frames: 178, dropped: 0, longest: 0 (0.0ms)
[+19196.8ms] [L2 Steady] memHit: 0, memMiss: 195, hitRate: 0.0%
[+19196.9ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+19196.9ms] [L2 Steady] grayShown: 78, grayResolved: 195, pending: -117
[+19197.0ms] [L2 Steady] req: 219 (89.4/s), cancel: 195 (79.6/s), complete: 219 (89.4/s)
[+19197.0ms] [L2 Steady] degraded: 219, maxInFlight: 24
[+19197.1ms] [L2 Steady] latency avg: 25.5ms, p95: 188.7ms, max: 343.0ms
[+19197.1ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+19197.5ms] [R2:Timing] seq=27, velocity=16428pt/s, 디바운스=50ms
[+19198.2ms] [Pipeline] requestImage #10: +1.0ms
[+19198.6ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+19198.6ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+19198.7ms] [Pipeline] requestImage #20: +1.6ms
[+19198.9ms] [R2] seq=27, visible=21, upgraded=21
[+19199.4ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+19205.5ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+19405.1ms] [Thumb:Check] seq=27, t=0.2s, velocity=16428, underSized=16/21
[+19553.7ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+19803.8ms] [Thumb:Check] seq=27, t=0.6s, velocity=16428, underSized=0/21
[+20188.3ms] [Thumb:Res] #1650 img=192x256px, target=192x192px, degraded=false
[+20203.3ms] [Pipeline] completion #50 도달: +1006.2ms
[+20213.7ms] [Thumb:Req] #840 target=192x192px, fullSize=false
[+20233.0ms] [Thumb:Res] #1660 img=192x256px, target=192x192px, degraded=false
[+20237.7ms] [Pipeline] requestImage #30: +1040.6ms
[+20241.4ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+20283.0ms] [Thumb:Res] #1670 img=192x256px, target=192x192px, degraded=false
[+20304.3ms] [Thumb:Req] #850 target=192x192px, fullSize=false
[+20324.5ms] [Thumb:Res] #1680 img=192x256px, target=192x192px, degraded=false
[+20333.0ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+20372.4ms] [Thumb:Res] #1690 img=90x120px, target=192x192px, degraded=true
[+20379.5ms] [Thumb:Req] #860 target=192x192px, fullSize=false
[+20418.2ms] [Thumb:Res] #1700 img=192x341px, target=192x192px, degraded=false
[+20426.0ms] [Pipeline] #100 target=192x192px → img=192x341px (100%), degraded=false
[+20454.7ms] [Thumb:Res] #1710 img=90x120px, target=192x192px, degraded=true
[+20470.5ms] [Thumb:Req] #870 target=192x192px, fullSize=false
[+20487.9ms] [Thumb:Res] #1720 img=90x120px, target=192x192px, degraded=true
[+20490.4ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+20507.4ms] [Thumb:Res] #1730 img=192x256px, target=192x192px, degraded=false
[+20521.1ms] [Thumb:Req] #880 target=192x192px, fullSize=false
[+20538.1ms] [Thumb:Res] #1740 img=90x120px, target=192x192px, degraded=true
[+20540.9ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+20571.5ms] [Thumb:Res] #1750 img=90x120px, target=192x192px, degraded=true
[+20579.3ms] [Thumb:Req] #890 target=192x192px, fullSize=false
[+20592.3ms] [Thumb:Res] #1760 img=192x341px, target=192x192px, degraded=false
[+20599.1ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+20648.8ms] [Thumb:Res] #1770 img=192x256px, target=192x192px, degraded=false
[+20670.7ms] [Thumb:Req] #900 target=192x192px, fullSize=false
[+20688.5ms] [Thumb:Res] #1780 img=90x120px, target=192x192px, degraded=true
[+20691.0ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+20700.2ms] [Thumb:Res] #1790 img=192x256px, target=192x192px, degraded=false
[+20712.9ms] [Thumb:Req] #910 target=192x192px, fullSize=false
[+20723.7ms] [Thumb:Res] #1800 img=256x192px, target=192x192px, degraded=false
[+20725.0ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+20754.6ms] [Thumb:Res] #1810 img=90x120px, target=192x192px, degraded=true
[+20762.3ms] [Thumb:Req] #920 target=192x192px, fullSize=false
[+20767.2ms] [Thumb:Res] #1820 img=192x256px, target=192x192px, degraded=false
[+20774.3ms] [Pipeline] #220 target=192x192px → img=192x256px (100%), degraded=false
[+20796.7ms] [Thumb:Res] #1830 img=90x120px, target=192x192px, degraded=true
[+20812.3ms] [Thumb:Req] #930 target=192x192px, fullSize=false
[+20829.8ms] [Thumb:Res] #1840 img=90x120px, target=192x192px, degraded=true
[+20832.2ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+20849.2ms] [Thumb:Res] #1850 img=192x256px, target=192x192px, degraded=false
[+20862.8ms] [Thumb:Req] #940 target=192x192px, fullSize=false
[+20880.0ms] [Thumb:Res] #1860 img=120x90px, target=192x192px, degraded=true
[+20882.6ms] [Pipeline] #260 target=192x192px → img=256x192px (133%), degraded=false
[+20915.6ms] [Thumb:Res] #1870 img=192x256px, target=192x192px, degraded=false
[+20929.2ms] [Thumb:Req] #950 target=192x192px, fullSize=false
[+20941.4ms] [Thumb:Res] #1880 img=192x256px, target=192x192px, degraded=false
[+20949.2ms] [Pipeline] #280 target=192x192px → img=192x256px (100%), degraded=false
[+20974.1ms] [Thumb:Res] #1890 img=192x256px, target=192x192px, degraded=false
[+21003.8ms] [Thumb:Req] #960 target=192x192px, fullSize=false
[+21016.1ms] [Thumb:Res] #1900 img=256x192px, target=192x192px, degraded=false
[+21024.1ms] [Pipeline] #300 target=192x192px → img=256x192px (133%), degraded=false
[+21058.1ms] [Thumb:Res] #1910 img=192x256px, target=192x192px, degraded=false
[+21079.4ms] [Thumb:Req] #970 target=192x192px, fullSize=false
[+21099.2ms] [Thumb:Res] #1920 img=192x256px, target=192x192px, degraded=false
[+21190.2ms] [Pipeline] #320 target=192x192px → img=68x120px (35%), degraded=true
[+21220.3ms] [Thumb:Res] #1930 img=192x341px, target=192x192px, degraded=false
[+21237.4ms] [Thumb:Req] #980 target=192x192px, fullSize=false
[+21257.8ms] [Thumb:Res] #1940 img=192x256px, target=192x192px, degraded=false
[+21266.2ms] [Pipeline] #340 target=192x192px → img=192x256px (100%), degraded=false
[+21447.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.2 (avg 8.33ms), frames: 156, dropped: 0, longest: 0 (0.0ms)
[+21447.1ms] [L2 Steady] memHit: 0, memMiss: 150, hitRate: 0.0%
[+21447.1ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+21447.1ms] [L2 Steady] grayShown: 39, grayResolved: 150, pending: -111
[+21447.2ms] [L2 Steady] req: 171 (76.0/s), cancel: 150 (66.7/s), complete: 171 (76.0/s)
[+21447.2ms] [L2 Steady] degraded: 171, maxInFlight: 21
[+21447.3ms] [L2 Steady] latency avg: 36.1ms, p95: 324.0ms, max: 367.2ms
[+21447.3ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+21447.7ms] [R2:Timing] seq=32, velocity=12019pt/s, 디바운스=50ms
[+21448.4ms] [Pipeline] requestImage #10: +1.1ms
[+21448.9ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+21449.0ms] [Pipeline] requestImage #20: +1.6ms
[+21449.1ms] [R2] seq=32, visible=21, upgraded=21
[+21449.6ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+21449.8ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+21455.0ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+21655.3ms] [Thumb:Check] seq=32, t=0.2s, velocity=12019, underSized=4/21
[+21724.4ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+22055.6ms] [Thumb:Check] seq=32, t=0.6s, velocity=12019, underSized=0/21
```

---

<!-- LOG_ID: 260103_phase2_1_bug -->
## Phase 2 테스트 1 (2026-01-03 23:56) - 버그 있음 (targetSize=192px)

```
=== PickPhoto Launch Log ===
Date: 2026-01-03 23:56:40
Device: iPhone14,2
============================
[+4.2ms] [LaunchArgs] didFinishLaunching: count=1
[+4.3ms] [LaunchArgs] --auto-scroll: false
[+5.7ms] [Env] Build: Release
[+5.7ms] [Env] LowPowerMode: OFF
[+5.7ms] [Env] PhotosAuth: authorized
[+5.9ms] [Config] deliveryMode: opportunistic
[+5.9ms] [Config] cancelPolicy: prepareForReuse
[+5.9ms] [Config] R2Recovery: disabled
[+65.1ms] [Timing] === 초기 로딩 시작 ===
[+101.5ms] [Timing] viewWillAppear: +36.2ms (초기 진입 - reloadData 스킵)
[+116.1ms] [Timing] C) 첫 레이아웃 완료: +51.0ms
[+135.8ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+140.5ms] [Preload] DISK HIT: F29EC2F9...
[+146.2ms] [Preload] DISK HIT: F0146B79...
[+150.8ms] [Preload] DISK HIT: 261056EB...
[+155.1ms] [Preload] DISK HIT: D10201EA...
[+163.0ms] [Preload] DISK HIT: 5FEA5EE7...
[+167.5ms] [Preload] DISK HIT: 7F2BACF6...
[+170.9ms] [Preload] DISK HIT: 5AE38379...
[+174.7ms] [Preload] DISK HIT: 2CD47CFB...
[+178.5ms] [Preload] DISK HIT: 48EC0DA1...
[+182.0ms] [Preload] DISK HIT: E0FEC1AD...
[+185.4ms] [Preload] DISK HIT: 82E65101...
[+188.8ms] [Preload] DISK HIT: 0EBF73ED...
[+188.9ms] [Timing] E0) finishInitialDisplay 시작: +123.7ms (reason: preload complete, preloaded: 12/12)
[+194.9ms] [Thumb:Req] #1 target=384x384px, fullSize=true
[+195.1ms] [Timing] D) 첫 셀 표시: +130.0ms (indexPath: [0, 0])
[+195.7ms] [Thumb:Req] #2 target=384x384px, fullSize=true
[+196.0ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+196.1ms] [Thumb:Req] #3 target=384x384px, fullSize=true
[+196.1ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+196.2ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+196.5ms] [Thumb:Req] #4 target=384x384px, fullSize=true
[+196.8ms] [Thumb:Req] #5 target=384x384px, fullSize=true
[+198.6ms] [Thumb:Req] #10 target=384x384px, fullSize=true
[+198.6ms] [Pipeline] requestImage #10: +192.7ms
[+205.6ms] [Timing] E1) reloadData+layout 완료: +140.4ms (E0→E1: 16.7ms)
[+206.6ms] [Thumb:Req] #20 target=384x384px, fullSize=true
[+206.6ms] [Pipeline] requestImage #20: +200.7ms
[+207.8ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+210.3ms] [Thumb:Req] #30 target=384x384px, fullSize=true
[+216.5ms] [Timing] E2) scrollToItem+layout 완료: +151.4ms (E1→E2: 11.0ms)
[+216.6ms] [Timing] === 초기 로딩 완료: +151.4ms (E0→E1: 16.7ms, E1→E2: 11.0ms) ===
[+216.6ms] [Timing] 최종 통계: cellForItemAt 36회, 총 17.7ms, 평균 0.49ms
[+216.6ms] [Initial Load] req: 24 (113.9/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+216.6ms] [Initial Load] degraded: 24, maxInFlight: 24
[+216.6ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+216.6ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+216.6ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+216.6ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+216.6ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+217.9ms] [Thumb:Res] #1 img=120x90px, target=384x384px, degraded=true
[+218.0ms] [Thumb:Res] #2 img=120x90px, target=384x384px, degraded=true
[+218.0ms] [Thumb:Res] #3 img=120x90px, target=384x384px, degraded=true
[+218.0ms] [Thumb:Res] #4 img=120x90px, target=384x384px, degraded=true
[+218.0ms] [Thumb:Res] #5 img=90x120px, target=384x384px, degraded=true
[+218.1ms] [Thumb:Res] #10 img=120x90px, target=384x384px, degraded=true
[+218.2ms] [Thumb:Res] #20 img=90x120px, target=384x384px, degraded=true
[+271.3ms] [Thumb:Res] #30 img=512x384px, target=384x384px, degraded=false
[+311.3ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+311.3ms] [Thumb:Res] #40 img=384x512px, target=384x384px, degraded=false
[+1265.6ms] [Scroll] First scroll 시작: +1200.4ms
[+1283.1ms] [Pipeline] completion #50 도달: +1277.2ms
[+1283.9ms] [Thumb:Res] #50 img=90x120px, target=192x192px, degraded=true
[+1291.6ms] [Thumb:Req] #40 target=192x192px, fullSize=false
[+1308.0ms] [Pipeline] requestImage #30: +1302.1ms
[+1312.2ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+1312.4ms] [Thumb:Res] #60 img=192x256px, target=192x192px, degraded=false
[+1354.0ms] [Thumb:Res] #70 img=192x256px, target=192x192px, degraded=false
[+1374.0ms] [Thumb:Req] #50 target=192x192px, fullSize=false
[+1401.8ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+1401.8ms] [Thumb:Res] #80 img=192x256px, target=192x192px, degraded=false
[+1443.0ms] [Thumb:Res] #90 img=192x256px, target=192x192px, degraded=false
[+1465.6ms] [Thumb:Req] #60 target=192x192px, fullSize=false
[+1493.7ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+1493.8ms] [Thumb:Res] #100 img=192x256px, target=192x192px, degraded=false
[+1523.6ms] [Preheat:Decel] seq=1, 21개 에셋, targetSize=192px
[+1574.7ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 116.4 (avg 8.33ms), frames: 36, dropped: 0, longest: 0 (0.0ms)
[+1574.7ms] [L1 First] memHit: 0, memMiss: 30, hitRate: 0.0%
[+1574.7ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+1574.7ms] [L1 First] grayShown: 3, grayResolved: 54, pending: -51
[+1574.7ms] [L1 First] req: 54 (34.4/s), cancel: 18 (11.5/s), complete: 54 (34.4/s)
[+1574.7ms] [L1 First] degraded: 54, maxInFlight: 24
[+1574.7ms] [L1 First] latency avg: 49.0ms, p95: 184.0ms, max: 186.4ms
[+1574.7ms] [L1 First] preheat: 1회, 총 21개 에셋
[+1574.8ms] [Scroll] First scroll 완료: 309.3ms 동안 스크롤
[+1574.8ms] [R2:Timing] seq=2, velocity=3808pt/s, 디바운스=50ms
[+1575.0ms] [Pipeline] requestImage #10: +0.2ms
[+1575.1ms] [R2] seq=2, visible=21, upgraded=15
[+1575.3ms] [Pipeline] #1 target=384x384px → img=68x120px (18%), degraded=true
[+1575.3ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+1575.5ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+1783.2ms] [Thumb:Check] seq=2, t=0.2s, velocity=3808, underSized=12/21
[+1788.5ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+2200.9ms] [Thumb:Check] seq=2, t=0.6s, velocity=3808, underSized=1/21
[+2630.1ms] [Thumb:Res] #110 img=192x256px, target=192x192px, degraded=false
[+2657.9ms] [Thumb:Req] #70 target=192x192px, fullSize=false
[+2666.3ms] [Pipeline] requestImage #20: +1091.6ms
[+2670.7ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+2678.7ms] [Thumb:Res] #120 img=192x256px, target=192x192px, degraded=false
[+2728.7ms] [Pipeline] completion #50 도달: +1154.0ms
[+2737.8ms] [Thumb:Res] #130 img=192x256px, target=192x192px, degraded=false
[+2766.0ms] [Thumb:Req] #80 target=192x192px, fullSize=false
[+2774.4ms] [Pipeline] requestImage #30: +1199.6ms
[+2778.6ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+2790.6ms] [Preheat:Decel] seq=3, 21개 에셋, targetSize=192px
[+2824.8ms] [Thumb:Res] #140 img=192x256px, target=192x192px, degraded=false
[+3007.8ms] [Thumb:Req] #90 target=192x192px, fullSize=false
[+3012.3ms] [Thumb:Res] #150 img=192x256px, target=192x192px, degraded=false
[+3482.0ms] [Preheat:Decel] seq=4, 21개 에셋, targetSize=192px
[+3541.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 112, dropped: 0, longest: 0 (0.0ms)
[+3541.6ms] [L2 Steady] memHit: 0, memMiss: 27, hitRate: 0.0%
[+3541.6ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+3541.6ms] [L2 Steady] grayShown: 0, grayResolved: 27, pending: -27
[+3541.6ms] [L2 Steady] req: 42 (21.4/s), cancel: 21 (10.7/s), complete: 42 (21.4/s)
[+3541.6ms] [L2 Steady] degraded: 36, maxInFlight: 15
[+3541.6ms] [L2 Steady] latency avg: 81.5ms, p95: 213.5ms, max: 635.7ms
[+3541.7ms] [L2 Steady] preheat: 3회, 총 96개 에셋
[+3551.6ms] [R2:Timing] seq=5, velocity=5119pt/s, 디바운스=50ms
[+3551.9ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+3551.9ms] [Pipeline] requestImage #10: +10.2ms
[+3552.0ms] [Pipeline] #2 target=384x384px → img=384x683px (100%), degraded=false
[+3552.0ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+3552.0ms] [Pipeline] requestImage #20: +10.4ms
[+3552.1ms] [R2] seq=5, visible=21, upgraded=21
[+3553.8ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+3752.6ms] [Thumb:Check] seq=5, t=0.2s, velocity=5119, underSized=0/21
[+4182.4ms] [Thumb:Check] seq=5, t=0.6s, velocity=5119, underSized=0/21
[+4302.5ms] [Thumb:Res] #160 img=192x256px, target=192x192px, degraded=false
[+4390.8ms] [Thumb:Req] #100 target=192x192px, fullSize=false
[+4391.1ms] [Pipeline] #40 target=192x192px → img=90x120px (47%), degraded=true
[+4394.1ms] [Thumb:Res] #170 img=192x256px, target=192x192px, degraded=false
[+4407.3ms] [Pipeline] requestImage #30: +865.7ms
[+4449.4ms] [Pipeline] completion #50 도달: +907.7ms
[+4451.8ms] [Thumb:Res] #180 img=192x256px, target=192x192px, degraded=false
[+4873.8ms] [Preheat:Decel] seq=6, 24개 에셋, targetSize=192px
[+4924.2ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.4 (avg 8.33ms), frames: 80, dropped: 0, longest: 0 (0.0ms)
[+4924.3ms] [L2 Steady] memHit: 0, memMiss: 15, hitRate: 0.0%
[+4924.3ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+4924.3ms] [L2 Steady] grayShown: 0, grayResolved: 15, pending: -15
[+4924.3ms] [L2 Steady] req: 36 (26.0/s), cancel: 15 (10.8/s), complete: 36 (26.0/s)
[+4924.3ms] [L2 Steady] degraded: 21, maxInFlight: 18
[+4924.3ms] [L2 Steady] latency avg: 17.7ms, p95: 104.9ms, max: 111.8ms
[+4924.3ms] [L2 Steady] preheat: 2회, 총 87개 에셋
[+4924.4ms] [R2:Timing] seq=7, velocity=3304pt/s, 디바운스=50ms
[+4924.7ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+4924.7ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+4924.7ms] [Pipeline] requestImage #10: +0.4ms
[+4924.8ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+4924.9ms] [R2] seq=7, visible=24, upgraded=18
[+5133.4ms] [Thumb:Check] seq=7, t=0.2s, velocity=3304, underSized=0/24
[+5546.6ms] [Thumb:Check] seq=7, t=0.6s, velocity=3304, underSized=0/24
[+5880.2ms] [Pipeline] #20 target=192x192px → img=192x256px (100%), degraded=false
[+5883.3ms] [Thumb:Req] #110 target=192x192px, fullSize=false
[+5883.4ms] [Pipeline] requestImage #20: +959.1ms
[+5887.9ms] [Thumb:Res] #190 img=192x256px, target=192x192px, degraded=false
[+5890.8ms] [Preheat:Decel] seq=8, 24개 에셋, targetSize=192px
[+5934.9ms] [Thumb:Res] #200 img=192x256px, target=192x192px, degraded=false
[+5969.0ms] [Pipeline] #40 target=192x192px → img=192x341px (100%), degraded=false
[+5973.7ms] [Thumb:Req] #120 target=192x192px, fullSize=false
[+5973.8ms] [Pipeline] requestImage #30: +1049.5ms
[+5977.1ms] [Thumb:Res] #210 img=192x256px, target=192x192px, degraded=false
[+5996.7ms] [Pipeline] completion #50 도달: +1072.4ms
[+5999.6ms] [Thumb:Res] #220 img=68x120px, target=192x192px, degraded=true
[+6016.1ms] [Thumb:Req] #130 target=192x192px, fullSize=false
[+6016.3ms] [Pipeline] #60 target=192x192px → img=68x120px (35%), degraded=true
[+6019.9ms] [Thumb:Res] #230 img=192x341px, target=192x192px, degraded=false
[+6060.4ms] [Thumb:Res] #240 img=192x341px, target=192x192px, degraded=false
[+6079.6ms] [Pipeline] #80 target=192x192px → img=341x192px (178%), degraded=false
[+6082.4ms] [Thumb:Req] #140 target=192x192px, fullSize=false
[+6085.2ms] [Thumb:Res] #250 img=192x256px, target=192x192px, degraded=false
[+6118.6ms] [Thumb:Res] #260 img=192x256px, target=192x192px, degraded=false
[+6143.2ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+6148.9ms] [Thumb:Req] #150 target=192x192px, fullSize=false
[+6151.3ms] [Thumb:Res] #270 img=192x256px, target=192x192px, degraded=false
[+6184.7ms] [Thumb:Res] #280 img=192x256px, target=192x192px, degraded=false
[+6218.6ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+6224.0ms] [Thumb:Req] #160 target=192x192px, fullSize=false
[+6226.7ms] [Thumb:Res] #290 img=192x256px, target=192x192px, degraded=false
[+6336.4ms] [Thumb:Res] #300 img=192x256px, target=192x192px, degraded=false
[+6378.2ms] [Pipeline] #140 target=192x192px → img=256x192px (133%), degraded=false
[+6382.5ms] [Thumb:Req] #170 target=192x192px, fullSize=false
[+6386.5ms] [Thumb:Res] #310 img=192x256px, target=192x192px, degraded=false
[+6515.5ms] [Preheat:Decel] seq=9, 21개 에셋, targetSize=192px
[+6574.2ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.6 (avg 8.33ms), frames: 86, dropped: 0, longest: 0 (0.0ms)
[+6574.2ms] [L2 Steady] memHit: 0, memMiss: 66, hitRate: 0.0%
[+6574.2ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+6574.2ms] [L2 Steady] grayShown: 13, grayResolved: 66, pending: -53
[+6574.3ms] [L2 Steady] req: 84 (50.9/s), cancel: 66 (40.0/s), complete: 84 (50.9/s)
[+6574.3ms] [L2 Steady] degraded: 66, maxInFlight: 14
[+6574.3ms] [L2 Steady] latency avg: 3.1ms, p95: 4.8ms, max: 25.4ms
[+6574.3ms] [L2 Steady] preheat: 3회, 총 111개 에셋
[+6574.4ms] [R2:Timing] seq=10, velocity=10513pt/s, 디바운스=50ms
[+6574.6ms] [Pipeline] requestImage #10: +0.3ms
[+6574.8ms] [Pipeline] requestImage #20: +0.5ms
[+6574.8ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+6574.8ms] [R2] seq=10, visible=21, upgraded=21
[+6575.0ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+6575.1ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+6577.1ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+6783.5ms] [Thumb:Check] seq=10, t=0.2s, velocity=10513, underSized=18/21
[+6845.1ms] [Pipeline] #40 target=384x384px → img=512x384px (133%), degraded=false
[+7200.2ms] [Thumb:Check] seq=10, t=0.6s, velocity=10513, underSized=0/21
[+7634.3ms] [Thumb:Res] #320 img=192x341px, target=192x192px, degraded=false
[+7640.9ms] [Preheat:Decel] seq=11, 21개 에셋, targetSize=192px
[+7668.2ms] [Pipeline] completion #50 도달: +1093.9ms
[+7674.3ms] [Thumb:Req] #180 target=192x192px, fullSize=false
[+7677.4ms] [Thumb:Res] #330 img=192x341px, target=192x192px, degraded=false
[+7699.2ms] [Pipeline] requestImage #30: +1124.9ms
[+7702.6ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+7727.4ms] [Thumb:Res] #340 img=192x256px, target=192x192px, degraded=false
[+7766.2ms] [Thumb:Req] #190 target=192x192px, fullSize=false
[+7769.4ms] [Thumb:Res] #350 img=192x256px, target=192x192px, degraded=false
[+7808.4ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+7833.4ms] [Thumb:Res] #360 img=192x256px, target=192x192px, degraded=false
[+7849.9ms] [Thumb:Req] #200 target=192x192px, fullSize=false
[+7991.3ms] [Thumb:Res] #370 img=192x256px, target=192x192px, degraded=false
[+8007.6ms] [Thumb:Req] #210 target=192x192px, fullSize=false
[+8041.2ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+8124.0ms] [Preheat:Decel] seq=12, 24개 에셋, targetSize=192px
[+8183.3ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.2 (avg 8.33ms), frames: 69, dropped: 0, longest: 0 (0.0ms)
[+8183.3ms] [L2 Steady] memHit: 0, memMiss: 42, hitRate: 0.0%
[+8183.4ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+8183.4ms] [L2 Steady] grayShown: 1, grayResolved: 42, pending: -41
[+8183.4ms] [L2 Steady] req: 63 (39.2/s), cancel: 42 (26.1/s), complete: 63 (39.2/s)
[+8183.4ms] [L2 Steady] degraded: 39, maxInFlight: 21
[+8183.4ms] [L2 Steady] latency avg: 84.2ms, p95: 270.2ms, max: 277.3ms
[+8183.4ms] [L2 Steady] preheat: 3회, 총 108개 에셋
[+8183.5ms] [R2:Timing] seq=13, velocity=8222pt/s, 디바운스=50ms
[+8183.8ms] [Pipeline] requestImage #10: +0.3ms
[+8183.9ms] [Pipeline] requestImage #20: +0.5ms
[+8183.9ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+8184.0ms] [R2] seq=13, visible=24, upgraded=24
[+8184.2ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+8184.3ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+8186.0ms] [Pipeline] #20 target=384x384px → img=68x120px (18%), degraded=true
[+8389.0ms] [Thumb:Check] seq=13, t=0.2s, velocity=8222, underSized=20/24
[+8499.3ms] [Pipeline] #40 target=384x384px → img=384x683px (100%), degraded=false
[+8800.3ms] [Thumb:Check] seq=13, t=0.6s, velocity=8222, underSized=0/24
[+9114.3ms] [Pipeline] completion #50 도달: +930.9ms
[+9114.5ms] [Thumb:Res] #380 img=192x256px, target=192x192px, degraded=false
[+9115.9ms] [Preheat:Decel] seq=14, 21개 에셋, targetSize=192px
[+9141.6ms] [Thumb:Req] #220 target=192x192px, fullSize=false
[+9158.4ms] [Pipeline] requestImage #30: +975.0ms
[+9162.0ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+9162.0ms] [Thumb:Res] #390 img=192x256px, target=192x192px, degraded=false
[+9212.1ms] [Thumb:Res] #400 img=192x256px, target=192x192px, degraded=false
[+9232.6ms] [Thumb:Req] #230 target=192x192px, fullSize=false
[+9262.2ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+9262.3ms] [Thumb:Res] #410 img=192x256px, target=192x192px, degraded=false
[+9302.5ms] [Thumb:Res] #420 img=192x256px, target=192x192px, degraded=false
[+9332.9ms] [Thumb:Req] #240 target=192x192px, fullSize=false
[+9399.9ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+9400.0ms] [Thumb:Res] #430 img=192x256px, target=192x192px, degraded=false
[+9507.7ms] [Thumb:Req] #250 target=192x192px, fullSize=false
[+9682.4ms] [Preheat:Decel] seq=15, 24개 에셋, targetSize=192px
[+9741.8ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.4 (avg 8.33ms), frames: 78, dropped: 0, longest: 0 (0.0ms)
[+9741.8ms] [L2 Steady] memHit: 0, memMiss: 39, hitRate: 0.0%
[+9741.8ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+9741.9ms] [L2 Steady] grayShown: 0, grayResolved: 39, pending: -39
[+9741.9ms] [L2 Steady] req: 63 (40.4/s), cancel: 39 (25.0/s), complete: 63 (40.4/s)
[+9741.9ms] [L2 Steady] degraded: 45, maxInFlight: 24
[+9741.9ms] [L2 Steady] latency avg: 105.2ms, p95: 324.6ms, max: 339.1ms
[+9741.9ms] [L2 Steady] preheat: 3회, 총 111개 에셋
[+9742.0ms] [R2:Timing] seq=16, velocity=6337pt/s, 디바운스=50ms
[+9742.3ms] [Pipeline] requestImage #10: +0.3ms
[+9742.4ms] [Pipeline] requestImage #20: +0.5ms
[+9742.5ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+9742.5ms] [R2] seq=16, visible=24, upgraded=24
[+9742.6ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+9742.6ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+9744.2ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+9948.8ms] [Thumb:Check] seq=16, t=0.2s, velocity=6337, underSized=2/24
[+10362.2ms] [Thumb:Check] seq=16, t=0.6s, velocity=6337, underSized=0/24
[+10600.2ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+10609.0ms] [Thumb:Res] #440 img=192x256px, target=192x192px, degraded=false
[+10624.0ms] [Preheat:Decel] seq=17, 24개 에셋, targetSize=192px
[+10649.5ms] [Thumb:Req] #260 target=192x192px, fullSize=false
[+10657.7ms] [Pipeline] requestImage #30: +915.8ms
[+10708.4ms] [Pipeline] completion #50 도달: +966.5ms
[+10717.4ms] [Thumb:Res] #450 img=192x256px, target=192x192px, degraded=false
[+10741.7ms] [Thumb:Req] #270 target=192x192px, fullSize=false
[+10800.2ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+10808.8ms] [Thumb:Res] #460 img=192x256px, target=192x192px, degraded=false
[+10832.9ms] [Thumb:Req] #280 target=192x192px, fullSize=false
[+10888.2ms] [Thumb:Res] #470 img=192x256px, target=192x192px, degraded=false
[+10925.7ms] [Pipeline] #80 target=192x192px → img=120x90px (62%), degraded=true
[+10930.1ms] [Thumb:Res] #480 img=256x192px, target=192x192px, degraded=false
[+10941.8ms] [Thumb:Req] #290 target=192x192px, fullSize=false
[+10979.8ms] [Thumb:Res] #490 img=192x256px, target=192x192px, degraded=false
[+11017.0ms] [Pipeline] #100 target=192x192px → img=90x120px (47%), degraded=true
[+11021.4ms] [Thumb:Res] #500 img=192x256px, target=192x192px, degraded=false
[+11033.6ms] [Thumb:Req] #300 target=192x192px, fullSize=false
[+11073.6ms] [Thumb:Res] #510 img=192x341px, target=192x192px, degraded=false
[+11142.1ms] [Thumb:Req] #310 target=192x192px, fullSize=false
[+11149.5ms] [Preheat:Decel] seq=19, 21개 에셋, targetSize=192px
[+11159.2ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+11168.4ms] [Thumb:Res] #520 img=192x256px, target=192x192px, degraded=false
[+11233.2ms] [Thumb:Req] #320 target=192x192px, fullSize=false
[+11258.9ms] [Thumb:Res] #530 img=192x256px, target=192x192px, degraded=false
[+11316.6ms] [Thumb:Req] #330 target=192x192px, fullSize=false
[+11317.0ms] [Pipeline] #140 target=192x192px → img=90x120px (47%), degraded=true
[+11321.0ms] [Thumb:Res] #540 img=192x256px, target=192x192px, degraded=false
[+11379.6ms] [Thumb:Res] #550 img=192x256px, target=192x192px, degraded=false
[+11409.6ms] [Thumb:Req] #340 target=192x192px, fullSize=false
[+11413.6ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+11414.3ms] [Thumb:Res] #560 img=192x256px, target=192x192px, degraded=false
[+11429.6ms] [Thumb:Res] #570 img=192x256px, target=192x192px, degraded=false
[+11441.3ms] [Thumb:Req] #350 target=192x192px, fullSize=false
[+11441.9ms] [Pipeline] #180 target=192x192px → img=90x120px (47%), degraded=true
[+11443.3ms] [Thumb:Res] #580 img=90x120px, target=192x192px, degraded=true
[+11450.0ms] [Thumb:Res] #590 img=90x120px, target=192x192px, degraded=true
[+11457.7ms] [Thumb:Req] #360 target=192x192px, fullSize=false
[+11458.8ms] [Pipeline] #200 target=192x192px → img=120x90px (62%), degraded=true
[+11461.8ms] [Thumb:Res] #600 img=192x256px, target=192x192px, degraded=false
[+11475.0ms] [Thumb:Res] #610 img=120x90px, target=192x192px, degraded=true
[+11483.1ms] [Thumb:Req] #370 target=192x192px, fullSize=false
[+11486.1ms] [Pipeline] #220 target=192x192px → img=256x192px (133%), degraded=false
[+11491.7ms] [Thumb:Res] #620 img=192x341px, target=192x192px, degraded=false
[+11507.5ms] [Thumb:Req] #380 target=192x192px, fullSize=false
[+11508.1ms] [Thumb:Res] #630 img=192x256px, target=192x192px, degraded=false
[+11532.9ms] [Thumb:Req] #390 target=192x192px, fullSize=false
[+11533.1ms] [Pipeline] #240 target=192x192px → img=256x192px (133%), degraded=false
[+11542.8ms] [Thumb:Res] #640 img=90x120px, target=192x192px, degraded=true
[+11550.6ms] [Thumb:Res] #650 img=90x120px, target=192x192px, degraded=true
[+11558.1ms] [Thumb:Req] #400 target=192x192px, fullSize=false
[+11561.6ms] [Pipeline] #260 target=192x192px → img=192x256px (100%), degraded=false
[+11566.3ms] [Thumb:Res] #660 img=90x120px, target=192x192px, degraded=true
[+11583.0ms] [Thumb:Res] #670 img=90x120px, target=192x192px, degraded=true
[+11591.2ms] [Thumb:Req] #410 target=192x192px, fullSize=false
[+11594.9ms] [Pipeline] #280 target=192x192px → img=192x256px (100%), degraded=false
[+11599.6ms] [Thumb:Res] #680 img=90x120px, target=192x192px, degraded=true
[+11616.4ms] [Thumb:Res] #690 img=90x120px, target=192x192px, degraded=true
[+11624.3ms] [Thumb:Req] #420 target=192x192px, fullSize=false
[+11628.6ms] [Pipeline] #300 target=192x192px → img=192x256px (100%), degraded=false
[+11628.7ms] [Thumb:Res] #700 img=192x256px, target=192x192px, degraded=false
[+11641.7ms] [Thumb:Res] #710 img=90x120px, target=192x192px, degraded=true
[+11657.9ms] [Thumb:Req] #430 target=192x192px, fullSize=false
[+11660.2ms] [Pipeline] #320 target=192x192px → img=192x256px (100%), degraded=false
[+11666.4ms] [Thumb:Res] #720 img=90x120px, target=192x192px, degraded=true
[+11679.0ms] [Thumb:Res] #730 img=192x256px, target=192x192px, degraded=false
[+11699.3ms] [Thumb:Req] #440 target=192x192px, fullSize=false
[+11699.8ms] [Pipeline] #340 target=192x192px → img=90x120px (47%), degraded=true
[+11700.2ms] [Thumb:Res] #740 img=90x120px, target=192x192px, degraded=true
[+11716.2ms] [Thumb:Res] #750 img=90x120px, target=192x192px, degraded=true
[+11732.5ms] [Thumb:Req] #450 target=192x192px, fullSize=false
[+11736.5ms] [Pipeline] #360 target=192x192px → img=192x256px (100%), degraded=false
[+11737.2ms] [Thumb:Res] #760 img=192x256px, target=192x192px, degraded=false
[+11758.1ms] [Thumb:Res] #770 img=90x120px, target=192x192px, degraded=true
[+11774.8ms] [Thumb:Req] #460 target=192x192px, fullSize=false
[+11778.7ms] [Pipeline] #380 target=192x192px → img=192x256px (100%), degraded=false
[+11784.1ms] [Thumb:Res] #780 img=90x120px, target=192x192px, degraded=true
[+11900.2ms] [Thumb:Res] #790 img=90x120px, target=192x192px, degraded=true
[+11932.8ms] [Thumb:Req] #470 target=192x192px, fullSize=false
[+11936.3ms] [Pipeline] #400 target=192x192px → img=192x256px (100%), degraded=false
[+11941.8ms] [Thumb:Res] #800 img=90x120px, target=192x192px, degraded=true
[+12132.6ms] [Preheat:Decel] seq=21, 24개 에셋, targetSize=192px
[+12191.8ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.3 (avg 8.33ms), frames: 194, dropped: 0, longest: 0 (0.0ms)
[+12191.9ms] [L2 Steady] memHit: 0, memMiss: 219, hitRate: 0.0%
[+12191.9ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+12191.9ms] [L2 Steady] grayShown: 87, grayResolved: 219, pending: -132
[+12191.9ms] [L2 Steady] req: 243 (99.2/s), cancel: 219 (89.4/s), complete: 243 (99.2/s)
[+12191.9ms] [L2 Steady] degraded: 165, maxInFlight: 24
[+12191.9ms] [L2 Steady] latency avg: 13.3ms, p95: 156.3ms, max: 303.6ms
[+12191.9ms] [L2 Steady] preheat: 4회, 총 135개 에셋
[+12192.1ms] [R2:Timing] seq=22, velocity=20434pt/s, 디바운스=50ms
[+12192.3ms] [Pipeline] requestImage #10: +0.3ms
[+12192.5ms] [Pipeline] requestImage #20: +0.5ms
[+12192.5ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+12192.5ms] [R2] seq=22, visible=24, upgraded=24
[+12192.7ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+12192.9ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+12194.4ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+12400.5ms] [Thumb:Check] seq=22, t=0.2s, velocity=20434, underSized=18/24
[+12468.3ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+12815.7ms] [Thumb:Check] seq=22, t=0.6s, velocity=20434, underSized=0/24
[+12989.4ms] [Pipeline] completion #50 도달: +797.5ms
[+12993.0ms] [Thumb:Res] #810 img=90x120px, target=192x192px, degraded=true
[+13008.1ms] [Preheat:Decel] seq=23, 24개 에셋, targetSize=192px
[+13041.2ms] [Thumb:Req] #480 target=192x192px, fullSize=false
[+13041.3ms] [Pipeline] requestImage #30: +849.3ms
[+13044.1ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+13049.7ms] [Thumb:Res] #820 img=90x120px, target=192x192px, degraded=true
[+13099.6ms] [Thumb:Res] #830 img=90x120px, target=192x192px, degraded=true
[+13132.8ms] [Thumb:Req] #490 target=192x192px, fullSize=false
[+13135.3ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+13141.3ms] [Thumb:Res] #840 img=90x120px, target=192x192px, degraded=true
[+13183.2ms] [Thumb:Res] #850 img=90x120px, target=192x192px, degraded=true
[+13208.9ms] [Thumb:Req] #500 target=192x192px, fullSize=false
[+13211.8ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+13225.0ms] [Thumb:Res] #860 img=90x120px, target=192x192px, degraded=true
[+13267.1ms] [Thumb:Res] #870 img=90x120px, target=192x192px, degraded=true
[+13299.9ms] [Thumb:Req] #510 target=192x192px, fullSize=false
[+13303.7ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+13305.2ms] [Thumb:Res] #880 img=192x341px, target=192x192px, degraded=false
[+13333.1ms] [Thumb:Res] #890 img=68x120px, target=192x192px, degraded=true
[+13349.9ms] [Thumb:Req] #520 target=192x192px, fullSize=false
[+13353.7ms] [Pipeline] #140 target=192x192px → img=192x341px (100%), degraded=false
[+13358.6ms] [Thumb:Res] #900 img=90x120px, target=192x192px, degraded=true
[+13394.1ms] [Thumb:Res] #910 img=192x256px, target=192x192px, degraded=false
[+13416.1ms] [Thumb:Req] #530 target=192x192px, fullSize=false
[+13419.4ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+13424.8ms] [Thumb:Res] #920 img=90x120px, target=192x192px, degraded=true
[+13474.8ms] [Thumb:Res] #930 img=120x90px, target=192x192px, degraded=true
[+13524.5ms] [Preheat:Decel] seq=25, 21개 에셋, targetSize=192px
[+13525.4ms] [Thumb:Req] #540 target=192x192px, fullSize=false
[+13541.2ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+13541.7ms] [Thumb:Res] #940 img=192x256px, target=192x192px, degraded=false
[+13583.7ms] [Thumb:Req] #550 target=192x192px, fullSize=false
[+13600.9ms] [Thumb:Res] #950 img=192x341px, target=192x192px, degraded=false
[+13633.5ms] [Thumb:Req] #560 target=192x192px, fullSize=false
[+13648.5ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+13651.0ms] [Thumb:Res] #960 img=90x120px, target=192x192px, degraded=true
[+13687.7ms] [Thumb:Res] #970 img=192x256px, target=192x192px, degraded=false
[+13699.6ms] [Thumb:Req] #570 target=192x192px, fullSize=false
[+13712.3ms] [Pipeline] #220 target=192x192px → img=256x192px (133%), degraded=false
[+13716.5ms] [Thumb:Res] #980 img=120x90px, target=192x192px, degraded=true
[+13759.1ms] [Thumb:Res] #990 img=90x120px, target=192x192px, degraded=true
[+13767.2ms] [Thumb:Req] #580 target=192x192px, fullSize=false
[+13785.4ms] [Pipeline] #240 target=192x192px → img=192x256px (100%), degraded=false
[+13791.9ms] [Thumb:Res] #1000 img=90x120px, target=192x192px, degraded=true
[+13833.6ms] [Thumb:Res] #1010 img=90x120px, target=192x192px, degraded=true
[+13858.3ms] [Thumb:Req] #590 target=192x192px, fullSize=false
[+13871.4ms] [Pipeline] #260 target=192x192px → img=192x256px (100%), degraded=false
[+13875.4ms] [Thumb:Res] #1020 img=90x120px, target=192x192px, degraded=true
[+13917.7ms] [Thumb:Res] #1030 img=90x120px, target=192x192px, degraded=true
[+13932.8ms] [Thumb:Req] #600 target=192x192px, fullSize=false
[+13953.4ms] [Pipeline] #280 target=192x192px → img=192x256px (100%), degraded=false
[+13958.4ms] [Thumb:Res] #1040 img=90x120px, target=192x192px, degraded=true
[+14008.3ms] [Thumb:Res] #1050 img=90x120px, target=192x192px, degraded=true
[+14024.5ms] [Thumb:Req] #610 target=192x192px, fullSize=false
[+14044.6ms] [Pipeline] #300 target=192x192px → img=192x256px (100%), degraded=false
[+14049.7ms] [Thumb:Res] #1060 img=90x120px, target=192x192px, degraded=true
[+14175.0ms] [Thumb:Res] #1070 img=120x90px, target=192x192px, degraded=true
[+14191.2ms] [Thumb:Req] #620 target=192x192px, fullSize=false
[+14491.0ms] [Preheat:Decel] seq=26, 21개 에셋, targetSize=192px
[+14550.3ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.3 (avg 8.33ms), frames: 191, dropped: 0, longest: 0 (0.0ms)
[+14550.3ms] [L2 Steady] memHit: 0, memMiss: 147, hitRate: 0.0%
[+14550.3ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+14550.3ms] [L2 Steady] grayShown: 25, grayResolved: 147, pending: -122
[+14550.4ms] [L2 Steady] req: 171 (72.5/s), cancel: 147 (62.3/s), complete: 171 (72.5/s)
[+14550.4ms] [L2 Steady] degraded: 147, maxInFlight: 24
[+14550.4ms] [L2 Steady] latency avg: 35.5ms, p95: 275.9ms, max: 276.0ms
[+14550.4ms] [L2 Steady] preheat: 4회, 총 132개 에셋
[+14550.5ms] [R2:Timing] seq=27, velocity=10161pt/s, 디바운스=50ms
[+14550.7ms] [Pipeline] requestImage #10: +0.3ms
[+14550.9ms] [Pipeline] requestImage #20: +0.5ms
[+14550.9ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+14551.0ms] [R2] seq=27, visible=21, upgraded=21
[+14551.5ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+14551.6ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+14553.1ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+14758.6ms] [Thumb:Check] seq=27, t=0.2s, velocity=10161, underSized=19/21
[+14780.6ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+15165.8ms] [Thumb:Check] seq=27, t=0.6s, velocity=10161, underSized=0/21
[+15331.9ms] [Preheat:Decel] seq=28, 24개 에셋, targetSize=192px
[+15334.2ms] [Thumb:Res] #1080 img=192x256px, target=192x192px, degraded=false
[+15384.2ms] [Pipeline] completion #50 도달: +833.8ms
[+15392.0ms] [Thumb:Req] #630 target=192x192px, fullSize=false
[+15392.1ms] [Pipeline] requestImage #30: +841.7ms
[+15434.5ms] [Thumb:Res] #1090 img=192x341px, target=192x192px, degraded=false
[+15475.8ms] [Pipeline] #60 target=192x192px → img=192x341px (100%), degraded=false
[+15483.8ms] [Thumb:Req] #640 target=192x192px, fullSize=false
[+15521.7ms] [Thumb:Res] #1100 img=192x256px, target=192x192px, degraded=false
[+15576.5ms] [Thumb:Res] #1110 img=90x120px, target=192x192px, degraded=true
[+15584.4ms] [Thumb:Req] #650 target=192x192px, fullSize=false
[+15591.7ms] [Pipeline] #80 target=192x192px → img=90x120px (47%), degraded=true
[+15604.5ms] [Thumb:Res] #1120 img=192x256px, target=192x192px, degraded=false
[+15638.1ms] [Thumb:Res] #1130 img=192x256px, target=192x192px, degraded=false
[+15641.5ms] [Thumb:Req] #660 target=192x192px, fullSize=false
[+15646.5ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+15658.7ms] [Thumb:Res] #1140 img=68x120px, target=192x192px, degraded=true
[+15685.2ms] [Thumb:Res] #1150 img=192x256px, target=192x192px, degraded=false
[+15691.6ms] [Thumb:Req] #670 target=192x192px, fullSize=false
[+15700.0ms] [Pipeline] #120 target=192x192px → img=90x120px (47%), degraded=true
[+15719.9ms] [Thumb:Res] #1160 img=192x256px, target=192x192px, degraded=false
[+15742.6ms] [Thumb:Res] #1170 img=68x120px, target=192x192px, degraded=true
[+15749.9ms] [Thumb:Req] #680 target=192x192px, fullSize=false
[+15758.3ms] [Pipeline] #140 target=192x192px → img=68x120px (35%), degraded=true
[+15783.5ms] [Thumb:Res] #1180 img=256x192px, target=192x192px, degraded=false
[+15859.3ms] [Thumb:Req] #690 target=192x192px, fullSize=false
[+15866.8ms] [Preheat:Decel] seq=30, 24개 에셋, targetSize=192px
[+15884.8ms] [Thumb:Res] #1190 img=192x256px, target=192x192px, degraded=false
[+15908.0ms] [Thumb:Req] #700 target=192x192px, fullSize=false
[+15908.1ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+15934.5ms] [Thumb:Res] #1200 img=192x256px, target=192x192px, degraded=false
[+15958.2ms] [Thumb:Req] #710 target=192x192px, fullSize=false
[+15961.7ms] [Thumb:Res] #1210 img=192x256px, target=192x192px, degraded=false
[+15983.2ms] [Pipeline] #180 target=192x192px → img=120x90px (62%), degraded=true
[+15987.8ms] [Thumb:Res] #1220 img=256x192px, target=192x192px, degraded=false
[+16016.1ms] [Thumb:Req] #720 target=192x192px, fullSize=false
[+16017.3ms] [Thumb:Res] #1230 img=120x90px, target=192x192px, degraded=true
[+16033.4ms] [Pipeline] #200 target=192x192px → img=120x90px (62%), degraded=true
[+16054.5ms] [Thumb:Res] #1240 img=192x341px, target=192x192px, degraded=false
[+16083.7ms] [Thumb:Req] #730 target=192x192px, fullSize=false
[+16087.0ms] [Thumb:Res] #1250 img=192x256px, target=192x192px, degraded=false
[+16102.5ms] [Pipeline] #220 target=192x192px → img=192x256px (100%), degraded=false
[+16119.5ms] [Thumb:Res] #1260 img=192x256px, target=192x192px, degraded=false
[+16166.5ms] [Thumb:Req] #740 target=192x192px, fullSize=false
[+16170.4ms] [Thumb:Res] #1270 img=192x256px, target=192x192px, degraded=false
[+16183.7ms] [Pipeline] #240 target=192x192px → img=90x120px (47%), degraded=true
[+16203.7ms] [Thumb:Res] #1280 img=192x256px, target=192x192px, degraded=false
[+16241.6ms] [Thumb:Req] #750 target=192x192px, fullSize=false
[+16245.2ms] [Thumb:Res] #1290 img=192x256px, target=192x192px, degraded=false
[+16266.7ms] [Pipeline] #260 target=192x192px → img=90x120px (47%), degraded=true
[+16295.2ms] [Thumb:Res] #1300 img=192x256px, target=192x192px, degraded=false
[+16409.7ms] [Thumb:Req] #760 target=192x192px, fullSize=false
[+16415.7ms] [Thumb:Res] #1310 img=256x192px, target=192x192px, degraded=false
[+16435.0ms] [Pipeline] #280 target=192x192px → img=120x90px (62%), degraded=true
[+16456.4ms] [Thumb:Res] #1320 img=256x192px, target=192x192px, degraded=false
[+16616.7ms] [Preheat:Decel] seq=31, 24개 에셋, targetSize=192px
[+16675.7ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.2 (avg 8.33ms), frames: 166, dropped: 0, longest: 0 (0.0ms)
[+16675.7ms] [L2 Steady] memHit: 0, memMiss: 147, hitRate: 0.0%
[+16675.7ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+16675.7ms] [L2 Steady] grayShown: 32, grayResolved: 147, pending: -115
[+16675.8ms] [L2 Steady] req: 168 (79.0/s), cancel: 147 (69.2/s), complete: 168 (79.0/s)
[+16675.8ms] [L2 Steady] degraded: 123, maxInFlight: 21
[+16675.8ms] [L2 Steady] latency avg: 29.7ms, p95: 229.6ms, max: 229.8ms
[+16675.8ms] [L2 Steady] preheat: 4회, 총 135개 에셋
[+16676.0ms] [R2:Timing] seq=32, velocity=10246pt/s, 디바운스=50ms
[+16676.4ms] [Pipeline] requestImage #10: +0.6ms
[+16676.6ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+16676.6ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+16676.7ms] [Pipeline] requestImage #20: +0.8ms
[+16676.8ms] [R2] seq=32, visible=24, upgraded=24
[+16676.9ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+16679.6ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+16882.8ms] [Thumb:Check] seq=32, t=0.2s, velocity=10246, underSized=12/24
[+16893.0ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+17299.5ms] [Thumb:Check] seq=32, t=0.6s, velocity=10246, underSized=0/24
```

---

<!-- LOG_ID: 260104_phase2_2 -->
## Phase 2 테스트 2 (2026-01-04 00:04) - 버그 수정 후

```
=== PickPhoto Launch Log ===
Date: 2026-01-04 00:03:57
Device: iPhone14,2
============================
[+7.1ms] [LaunchArgs] didFinishLaunching: count=1
[+7.2ms] [LaunchArgs] --auto-scroll: false
[+8.1ms] [Env] Build: Release
[+8.1ms] [Env] LowPowerMode: OFF
[+8.1ms] [Env] PhotosAuth: authorized
[+8.3ms] [Config] deliveryMode: opportunistic
[+8.3ms] [Config] cancelPolicy: prepareForReuse
[+8.3ms] [Config] R2Recovery: disabled
[+73.0ms] [Timing] === 초기 로딩 시작 ===
[+110.0ms] [Timing] viewWillAppear: +36.9ms (초기 진입 - reloadData 스킵)
[+176.4ms] [Timing] C) 첫 레이아웃 완료: +103.4ms
[+182.0ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+210.9ms] [Preload] DISK HIT: F29EC2F9...
[+225.5ms] [Preload] DISK HIT: F0146B79...
[+233.7ms] [Preload] DISK HIT: 261056EB...
[+240.7ms] [Preload] DISK HIT: D10201EA...
[+252.0ms] [Preload] DISK HIT: 5FEA5EE7...
[+258.0ms] [Preload] DISK HIT: 7F2BACF6...
[+263.3ms] [Preload] DISK HIT: 5AE38379...
[+271.8ms] [Preload] DISK HIT: 2CD47CFB...
[+277.2ms] [Timing] E0) finishInitialDisplay 시작: +204.2ms (reason: timeout, preloaded: 8/12)
[+283.3ms] [Thumb:Req] #1 target=384x384px, fullSize=true
[+283.6ms] [Timing] D) 첫 셀 표시: +210.5ms (indexPath: [0, 0])
[+284.2ms] [Thumb:Req] #2 target=384x384px, fullSize=true
[+284.7ms] [Thumb:Req] #3 target=384x384px, fullSize=true
[+285.0ms] [Thumb:Req] #4 target=384x384px, fullSize=true
[+285.4ms] [Thumb:Req] #5 target=384x384px, fullSize=true
[+286.3ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+286.7ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+286.8ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+287.1ms] [Thumb:Req] #10 target=384x384px, fullSize=true
[+287.1ms] [Pipeline] requestImage #10: +278.8ms
[+294.6ms] [Timing] E1) reloadData+layout 완료: +221.6ms (E0→E1: 17.4ms)
[+295.7ms] [Thumb:Req] #20 target=384x384px, fullSize=true
[+295.7ms] [Pipeline] requestImage #20: +287.4ms
[+295.9ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+299.3ms] [Thumb:Req] #30 target=384x384px, fullSize=true
[+306.2ms] [Timing] E2) scrollToItem+layout 완료: +233.2ms (E1→E2: 11.6ms)
[+306.3ms] [Timing] === 초기 로딩 완료: +233.2ms (E0→E1: 17.4ms, E1→E2: 11.6ms) ===
[+306.3ms] [Timing] 최종 통계: cellForItemAt 36회, 총 18.5ms, 평균 0.51ms
[+306.3ms] [Initial Load] req: 28 (94.0/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+306.3ms] [Initial Load] degraded: 28, maxInFlight: 28
[+306.3ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+306.3ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+306.3ms] [Initial Load] memHit: 8, memMiss: 40, hitRate: 16.7%
[+306.3ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+306.3ms] [Initial Load] grayShown: 28, grayResolved: 8, pending: 20
[+311.1ms] [Preload] DISK HIT: 48EC0DA1...
[+311.1ms] [Preload] DISK HIT: E0FEC1AD...
[+311.1ms] [Thumb:Res] #1 img=120x90px, target=384x384px, degraded=true
[+311.1ms] [Thumb:Res] #2 img=120x90px, target=384x384px, degraded=true
[+311.1ms] [Thumb:Res] #3 img=120x90px, target=384x384px, degraded=true
[+311.2ms] [Thumb:Res] #4 img=90x120px, target=384x384px, degraded=true
[+311.2ms] [Thumb:Res] #5 img=120x90px, target=384x384px, degraded=true
[+311.2ms] [Thumb:Res] #10 img=120x90px, target=384x384px, degraded=true
[+311.4ms] [Thumb:Res] #20 img=90x120px, target=384x384px, degraded=true
[+318.7ms] [Thumb:Res] #30 img=512x384px, target=384x384px, degraded=false
[+360.8ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+361.0ms] [Thumb:Res] #40 img=384x512px, target=384x384px, degraded=false
[+375.2ms] [Preload] DISK HIT: 82E65101...
[+403.3ms] [Pipeline] completion #50 도달: +395.0ms
[+403.4ms] [Thumb:Res] #50 img=384x683px, target=384x384px, degraded=false
[+445.0ms] [Preload] DISK HIT: 0EBF73ED...
[+1899.3ms] [Scroll] First scroll 시작: +1826.2ms
[+1932.4ms] [Pipeline] requestImage #30: +1924.1ms
[+1933.3ms] [Pipeline] #60 target=192x192px → img=90x120px (47%), degraded=true
[+1933.8ms] [Thumb:Res] #60 img=90x120px, target=192x192px, degraded=true
[+1934.0ms] [Thumb:Req] #40 target=192x192px, fullSize=false
[+1962.2ms] [Thumb:Res] #70 img=192x256px, target=192x192px, degraded=false
[+2003.4ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+2003.6ms] [Thumb:Res] #80 img=192x256px, target=192x192px, degraded=false
[+2016.4ms] [Thumb:Req] #50 target=192x192px, fullSize=false
[+2053.3ms] [Thumb:Res] #90 img=192x256px, target=192x192px, degraded=false
[+2103.3ms] [Pipeline] #100 target=192x192px → img=192x341px (100%), degraded=false
[+2103.3ms] [Thumb:Res] #100 img=192x341px, target=192x192px, degraded=false
[+2115.3ms] [Thumb:Req] #60 target=192x192px, fullSize=false
[+2151.9ms] [Thumb:Res] #110 img=192x256px, target=192x192px, degraded=false
[+2390.4ms] [Preheat:Decel] seq=1, 24개 에셋, targetSize=384px
[+2441.4ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 118.1 (avg 8.33ms), frames: 64, dropped: 0, longest: 0 (0.0ms)
[+2441.4ms] [L1 First] memHit: 0, memMiss: 30, hitRate: 0.0%
[+2441.4ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+2441.4ms] [L1 First] grayShown: 2, grayResolved: 58, pending: -56
[+2441.4ms] [L1 First] req: 58 (23.8/s), cancel: 22 (9.0/s), complete: 58 (23.8/s)
[+2441.4ms] [L1 First] degraded: 58, maxInFlight: 28
[+2441.4ms] [L1 First] latency avg: 53.8ms, p95: 252.1ms, max: 311.7ms
[+2441.4ms] [L1 First] preheat: 1회, 총 24개 에셋
[+2441.4ms] [Scroll] First scroll 완료: 542.3ms 동안 스크롤
[+2441.6ms] [R2:Timing] seq=2, velocity=2698pt/s, 디바운스=50ms
[+2441.7ms] [Pipeline] requestImage #10: +0.3ms
[+2441.8ms] [R2] seq=2, visible=24, upgraded=18
[+2442.2ms] [Pipeline] #1 target=384x384px → img=68x120px (18%), degraded=true
[+2442.4ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+2442.6ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+2493.0ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+2649.7ms] [Thumb:Check] seq=2, t=0.2s, velocity=2698, underSized=1/24
[+3064.9ms] [Thumb:Check] seq=2, t=0.6s, velocity=2698, underSized=0/24
[+3449.7ms] [Pipeline] requestImage #20: +1008.3ms
[+3454.4ms] [Thumb:Res] #120 img=192x256px, target=192x192px, degraded=false
[+3491.2ms] [Thumb:Req] #70 target=192x192px, fullSize=false
[+3533.4ms] [Pipeline] #40 target=192x192px → img=90x120px (47%), degraded=true
[+3537.5ms] [Thumb:Res] #130 img=192x256px, target=192x192px, degraded=false
[+3599.3ms] [Pipeline] requestImage #30: +1157.9ms
[+3599.9ms] [Pipeline] completion #50 도달: +1158.5ms
[+3604.3ms] [Thumb:Res] #140 img=192x256px, target=192x192px, degraded=false
[+3641.5ms] [Thumb:Req] #80 target=192x192px, fullSize=false
[+3690.5ms] [Preheat:Decel] seq=3, 21개 에셋, targetSize=384px
[+3724.7ms] [Pipeline] #60 target=192x192px → img=90x120px (47%), degraded=true
[+3782.5ms] [Thumb:Res] #150 img=90x120px, target=192x192px, degraded=true
[+3878.1ms] [Thumb:Res] #160 img=256x192px, target=192x192px, degraded=false
[+3890.3ms] [Thumb:Req] #90 target=192x192px, fullSize=false
[+4008.2ms] [Pipeline] #80 target=192x192px → img=90x120px (47%), degraded=true
[+4011.7ms] [Thumb:Res] #170 img=192x256px, target=192x192px, degraded=false
[+4415.3ms] [Preheat:Decel] seq=4, 21개 에셋, targetSize=384px
[+4474.1ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.1 (avg 8.33ms), frames: 126, dropped: 0, longest: 0 (0.0ms)
[+4474.1ms] [L2 Steady] memHit: 0, memMiss: 30, hitRate: 0.0%
[+4474.1ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+4474.1ms] [L2 Steady] grayShown: 0, grayResolved: 30, pending: -30
[+4474.2ms] [L2 Steady] req: 48 (23.6/s), cancel: 24 (11.8/s), complete: 48 (23.6/s)
[+4474.2ms] [L2 Steady] degraded: 39, maxInFlight: 18
[+4474.2ms] [L2 Steady] latency avg: 39.1ms, p95: 136.4ms, max: 471.9ms
[+4474.2ms] [L2 Steady] preheat: 3회, 총 99개 에셋
[+4474.3ms] [R2:Timing] seq=5, velocity=3089pt/s, 디바운스=50ms
[+4474.5ms] [Pipeline] requestImage #10: +0.3ms
[+4474.7ms] [Pipeline] requestImage #20: +0.5ms
[+4474.8ms] [R2] seq=5, visible=21, upgraded=21
[+4474.8ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+4474.9ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+4475.0ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+4475.9ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+4683.2ms] [Thumb:Check] seq=5, t=0.2s, velocity=3089, underSized=0/21
[+5093.4ms] [Thumb:Check] seq=5, t=0.6s, velocity=3089, underSized=0/21
[+5303.9ms] [Thumb:Res] #180 img=192x256px, target=192x192px, degraded=false
[+5333.0ms] [Thumb:Req] #100 target=192x192px, fullSize=false
[+5378.8ms] [Thumb:Res] #190 img=192x256px, target=192x192px, degraded=false
[+5391.1ms] [Pipeline] requestImage #30: +916.9ms
[+5416.8ms] [Pipeline] #40 target=192x192px → img=90x120px (47%), degraded=true
[+5436.7ms] [Thumb:Res] #200 img=192x256px, target=192x192px, degraded=false
[+5457.3ms] [Preheat:Decel] seq=6, 24개 에셋, targetSize=384px
[+5474.7ms] [Thumb:Req] #110 target=192x192px, fullSize=false
[+5532.7ms] [Pipeline] completion #50 도달: +1058.5ms
[+5618.0ms] [Thumb:Res] #210 img=192x256px, target=192x192px, degraded=false
[+5638.8ms] [Pipeline] #60 target=192x192px → img=192x256px (100%), degraded=false
[+5669.3ms] [Thumb:Res] #220 img=192x341px, target=192x192px, degraded=false
[+5682.3ms] [Thumb:Req] #120 target=192x192px, fullSize=false
[+6107.2ms] [Preheat:Decel] seq=7, 24개 에셋, targetSize=384px
[+6166.5ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 111, dropped: 0, longest: 0 (0.0ms)
[+6166.5ms] [L2 Steady] memHit: 0, memMiss: 24, hitRate: 0.0%
[+6166.5ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+6166.5ms] [L2 Steady] grayShown: 0, grayResolved: 24, pending: -24
[+6166.5ms] [L2 Steady] req: 45 (26.6/s), cancel: 24 (14.2/s), complete: 45 (26.6/s)
[+6166.5ms] [L2 Steady] degraded: 24, maxInFlight: 21
[+6166.5ms] [L2 Steady] latency avg: 21.7ms, p95: 151.7ms, max: 155.1ms
[+6166.5ms] [L2 Steady] preheat: 3회, 총 111개 에셋
[+6166.6ms] [R2:Timing] seq=8, velocity=3295pt/s, 디바운스=50ms
[+6166.7ms] [Pipeline] requestImage #10: +0.2ms
[+6166.8ms] [Pipeline] requestImage #20: +0.3ms
[+6166.9ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+6166.9ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+6166.9ms] [R2] seq=8, visible=24, upgraded=24
[+6166.9ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+6167.4ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+6377.1ms] [Thumb:Check] seq=8, t=0.2s, velocity=3295, underSized=0/24
[+6771.1ms] [Thumb:Check] seq=8, t=0.6s, velocity=3295, underSized=0/24
[+7357.4ms] [Preheat:Decel] seq=9, 24개 에셋, targetSize=384px
[+7399.7ms] [Pipeline] requestImage #30: +1233.2ms
[+7400.3ms] [Thumb:Res] #230 img=68x120px, target=192x192px, degraded=true
[+7441.4ms] [Thumb:Req] #130 target=192x192px, fullSize=false
[+7448.1ms] [Pipeline] #40 target=192x192px → img=192x256px (100%), degraded=false
[+7448.2ms] [Thumb:Res] #240 img=192x256px, target=192x192px, degraded=false
[+7468.4ms] [Pipeline] completion #50 도달: +1301.8ms
[+7468.4ms] [Thumb:Res] #250 img=192x341px, target=192x192px, degraded=false
[+7508.0ms] [Pipeline] #60 target=192x192px → img=120x68px (62%), degraded=true
[+7508.1ms] [Thumb:Res] #260 img=120x68px, target=192x192px, degraded=true
[+7515.6ms] [Thumb:Req] #140 target=192x192px, fullSize=false
[+7535.0ms] [Thumb:Res] #270 img=256x192px, target=192x192px, degraded=false
[+7585.2ms] [Pipeline] #80 target=192x192px → img=192x256px (100%), degraded=false
[+7585.2ms] [Thumb:Res] #280 img=192x256px, target=192x192px, degraded=false
[+7599.0ms] [Thumb:Req] #150 target=192x192px, fullSize=false
[+7618.1ms] [Thumb:Res] #290 img=192x256px, target=192x192px, degraded=false
[+7659.8ms] [Pipeline] #100 target=192x192px → img=192x256px (100%), degraded=false
[+7659.9ms] [Thumb:Res] #300 img=192x256px, target=192x192px, degraded=false
[+7673.9ms] [Thumb:Req] #160 target=192x192px, fullSize=false
[+7710.3ms] [Thumb:Res] #310 img=256x192px, target=192x192px, degraded=false
[+7751.8ms] [Pipeline] #120 target=192x192px → img=192x256px (100%), degraded=false
[+7751.9ms] [Thumb:Res] #320 img=192x256px, target=192x192px, degraded=false
[+7765.4ms] [Thumb:Req] #170 target=192x192px, fullSize=false
[+7793.7ms] [Thumb:Res] #330 img=256x192px, target=192x192px, degraded=false
[+7843.4ms] [Pipeline] #140 target=192x192px → img=192x256px (100%), degraded=false
[+7843.5ms] [Thumb:Res] #340 img=192x256px, target=192x192px, degraded=false
[+7857.4ms] [Thumb:Req] #180 target=192x192px, fullSize=false
[+7885.2ms] [Thumb:Res] #350 img=192x256px, target=192x192px, degraded=false
[+7935.1ms] [Pipeline] #160 target=192x192px → img=192x256px (100%), degraded=false
[+7935.2ms] [Thumb:Res] #360 img=192x256px, target=192x192px, degraded=false
[+7948.9ms] [Thumb:Req] #190 target=192x192px, fullSize=false
[+7986.4ms] [Thumb:Res] #370 img=192x256px, target=192x192px, degraded=false
[+8036.8ms] [Pipeline] #180 target=192x192px → img=192x256px (100%), degraded=false
[+8037.0ms] [Thumb:Res] #380 img=192x256px, target=192x192px, degraded=false
[+8066.3ms] [Thumb:Req] #200 target=192x192px, fullSize=false
[+8136.6ms] [Thumb:Res] #390 img=192x256px, target=192x192px, degraded=false
[+8286.3ms] [Pipeline] #200 target=192x192px → img=192x256px (100%), degraded=false
[+8286.5ms] [Thumb:Res] #400 img=192x256px, target=192x192px, degraded=false
[+8299.7ms] [Thumb:Req] #210 target=192x192px, fullSize=false
[+8615.5ms] [Preheat:Decel] seq=10, 21개 에셋, targetSize=384px
[+8674.8ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.2 (avg 8.33ms), frames: 160, dropped: 0, longest: 0 (0.0ms)
[+8674.8ms] [L2 Steady] memHit: 0, memMiss: 90, hitRate: 0.0%
[+8674.8ms] [L2 Steady] diskCacheMismatch: 0, pipelineMismatch: 0
[+8674.8ms] [L2 Steady] grayShown: 4, grayResolved: 90, pending: -86
[+8674.9ms] [L2 Steady] req: 114 (45.4/s), cancel: 90 (35.9/s), complete: 114 (45.4/s)
[+8674.9ms] [L2 Steady] degraded: 90, maxInFlight: 22
[+8674.9ms] [L2 Steady] latency avg: 6.4ms, p95: 49.9ms, max: 78.1ms
[+8674.9ms] [L2 Steady] preheat: 3회, 총 111개 에셋
[+8675.0ms] [R2:Timing] seq=11, velocity=11139pt/s, 디바운스=50ms
[+8675.1ms] [Pipeline] requestImage #10: +0.2ms
[+8675.1ms] [Pipeline] requestImage #20: +0.2ms
[+8675.1ms] [R2] seq=11, visible=21, upgraded=21
[+8675.5ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+8675.5ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+8675.6ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+8676.3ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+8883.4ms] [Thumb:Check] seq=11, t=0.2s, velocity=11139, underSized=0/21
[+9283.5ms] [Thumb:Check] seq=11, t=0.6s, velocity=11139, underSized=0/21
[+9899.2ms] [Preheat:Decel] seq=12, 24개 에셋, targetSize=384px
[+9933.9ms] [Thumb:Res] #410 img=90x120px, target=192x192px, degraded=true
[+9966.1ms] [Pipeline] requestImage #30: +1291.3ms
[+9983.5ms] [Thumb:Req] #220 target=192x192px, fullSize=false
[+10000.4ms] [Pipeline] #40 target=192x192px → img=90x120px (47%), degraded=true
[+10014.3ms] [Thumb:Res] #420 img=192x256px, target=192x192px, degraded=false
[+10018.3ms] [Pipeline] completion #50 도달: +1343.5ms
[+10020.4ms] [Thumb:Res] #430 img=192x256px, target=192x192px, degraded=false
[+10041.0ms] [Pipeline] #60 target=192x192px → img=90x120px (47%), degraded=true
[+10052.3ms] [Thumb:Res] #440 img=192x256px, target=192x192px, degraded=false
[+10074.3ms] [Thumb:Req] #230 target=192x192px, fullSize=false
[+10093.3ms] [Thumb:Res] #450 img=192x256px, target=192x192px, degraded=false
[+10766.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 107, dropped: 0, longest: 0 (0.0ms)
[+10766.7ms] [R2:Timing] seq=14, velocity=9016pt/s, 디바운스=50ms
[+10766.9ms] [R2] seq=14, visible=21, upgraded=21
[+10970.9ms] [Thumb:Check] seq=14, t=0.2s, velocity=9016, underSized=0/21
[+11389.6ms] [Thumb:Check] seq=14, t=0.6s, velocity=9016, underSized=0/21
[+12850.2ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.9 (avg 8.33ms), frames: 117, dropped: 0, longest: 0 (0.0ms)
[+12850.4ms] [R2:Timing] seq=17, velocity=11403pt/s, 디바운스=50ms
[+12850.5ms] [Pipeline] #1 target=384x384px → img=384x683px (100%), degraded=false
[+12850.5ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+12850.6ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+12850.7ms] [R2] seq=17, visible=21, upgraded=21
[+13052.8ms] [Thumb:Check] seq=17, t=0.2s, velocity=11403, underSized=1/21
[+13465.8ms] [Thumb:Check] seq=17, t=0.6s, velocity=11403, underSized=0/21
[+15875.4ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.4 (avg 8.33ms), frames: 200, dropped: 0, longest: 0 (0.0ms)
[+15875.6ms] [R2:Timing] seq=22, velocity=16441pt/s, 디바운스=50ms
[+15876.0ms] [R2] seq=22, visible=24, upgraded=24
[+16083.9ms] [Thumb:Check] seq=22, t=0.2s, velocity=16441, underSized=0/24
[+16502.7ms] [Thumb:Check] seq=22, t=0.6s, velocity=16441, underSized=0/24
[+17933.8ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.2 (avg 8.33ms), frames: 161, dropped: 0, longest: 0 (0.0ms)
[+17934.0ms] [R2:Timing] seq=27, velocity=9813pt/s, 디바운스=50ms
[+17934.3ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+17934.4ms] [R2] seq=27, visible=21, upgraded=21
[+18144.5ms] [Thumb:Check] seq=27, t=0.2s, velocity=9813, underSized=0/21
[+18557.9ms] [Thumb:Check] seq=27, t=0.6s, velocity=9813, underSized=2/21
[+19859.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.3 (avg 8.33ms), frames: 170, dropped: 0, longest: 0 (0.0ms)
[+19859.1ms] [R2:Timing] seq=32, velocity=10497pt/s, 디바운스=50ms
[+19859.5ms] [R2] seq=32, visible=21, upgraded=21
[+19859.5ms] [Pipeline] #1 target=384x384px → img=512x384px (133%), degraded=false
[+19859.6ms] [Pipeline] #2 target=384x384px → img=512x384px (133%), degraded=false
[+20065.9ms] [Thumb:Check] seq=32, t=0.2s, velocity=10497, underSized=0/21
[+20466.1ms] [Thumb:Check] seq=32, t=0.6s, velocity=10497, underSized=0/21
```

---

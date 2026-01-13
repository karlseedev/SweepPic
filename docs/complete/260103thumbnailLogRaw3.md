# 썸네일 고해상도 전환 원본 로그 #3

원본 로그 데이터를 저장하는 문서입니다.

> **요약은 `260103thumbnailLog.md`에 있습니다.**

---

<!-- LOG_ID: 260104_phase2_3 -->
## Phase 2 테스트 3 (2026-01-04 00:10)

```
=== PickPhoto Launch Log ===
Date: 2026-01-04 00:10:06
Device: iPhone14,2
============================
[+8.0ms] [LaunchArgs] didFinishLaunching: count=1
[+8.1ms] [LaunchArgs] --auto-scroll: false
[+9.7ms] [Env] Build: Release
[+9.7ms] [Env] LowPowerMode: OFF
[+9.7ms] [Env] PhotosAuth: authorized
[+9.9ms] [Config] deliveryMode: opportunistic
[+9.9ms] [Config] cancelPolicy: prepareForReuse
[+9.9ms] [Config] R2Recovery: disabled
[+74.7ms] [Timing] === 초기 로딩 시작 ===
[+104.6ms] [Timing] viewWillAppear: +29.7ms (초기 진입 - reloadData 스킵)
[+117.3ms] [Timing] C) 첫 레이아웃 완료: +42.6ms
[+122.5ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+132.6ms] [Preload] DISK HIT: F29EC2F9...
[+172.4ms] [Preload] DISK HIT: 0EBF73ED...
[+172.4ms] [Timing] E0) finishInitialDisplay 시작: +97.7ms (reason: preload complete, preloaded: 12/12)
[+178.1ms] [Thumb:Req] #1 target=384x384px, fullSize=true
[+178.2ms] [Timing] D) 첫 셀 표시: +103.5ms (indexPath: [0, 0])
[+201.6ms] [Timing] === 초기 로딩 완료: +126.8ms (E0→E1: 17.0ms, E1→E2: 12.2ms) ===
[+850.7ms] [Scroll] First scroll 시작: +775.7ms
[+1082.4ms] [Preheat:Decel] seq=1, 24개 에셋, targetSize=384px
[+1825.4ms] [Preheat:Decel] seq=2, 21개 에셋, targetSize=384px
[+1883.5ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 119.1 (avg 8.33ms), frames: 123, dropped: 0, longest: 0 (0.0ms)
[+1883.7ms] [Scroll] First scroll 완료: 1033.3ms 동안 스크롤
[+1883.8ms] [R2:Timing] seq=3, velocity=3221pt/s, 디바운스=50ms
[+1884.1ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+1884.1ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+1884.2ms] [Pipeline] #3 target=384x384px → img=384x683px (100%), degraded=false
[+1884.3ms] [R2] seq=3, visible=21, upgraded=21
[+1885.3ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+2094.4ms] [Thumb:Check] seq=3, t=0.2s, velocity=3221, underSized=4/21
[+2508.1ms] [Thumb:Check] seq=3, t=0.6s, velocity=3221, underSized=0/21
[+2642.8ms] [Preheat:Decel] seq=4, 21개 에셋, targetSize=384px
[+3358.2ms] [Preheat:Decel] seq=5, 24개 에셋, targetSize=384px
[+3417.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 115, dropped: 0, longest: 0 (0.0ms)
[+3417.2ms] [R2:Timing] seq=6, velocity=6942pt/s, 디바운스=50ms
[+3417.5ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+3417.5ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+3417.6ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+3417.7ms] [R2] seq=6, visible=24, upgraded=24
[+3418.2ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+3623.4ms] [Thumb:Check] seq=6, t=0.2s, velocity=6942, underSized=0/24
[+4032.4ms] [Thumb:Check] seq=6, t=0.6s, velocity=6942, underSized=0/21
[+4124.3ms] [Preheat:Decel] seq=7, 21개 에셋, targetSize=384px
[+4824.9ms] [Preheat:Decel] seq=8, 21개 에셋, targetSize=384px
[+4883.7ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 105, dropped: 0, longest: 0 (0.0ms)
[+4883.9ms] [R2:Timing] seq=9, velocity=4312pt/s, 디바운스=50ms
[+4884.1ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+4884.1ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+4884.2ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+4884.2ms] [R2] seq=9, visible=21, upgraded=21
[+4884.8ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+5094.4ms] [Thumb:Check] seq=9, t=0.2s, velocity=4312, underSized=0/21
[+5499.1ms] [Thumb:Check] seq=9, t=0.6s, velocity=4312, underSized=0/21
[+5674.4ms] [Preheat:Decel] seq=10, 24개 에셋, targetSize=384px
[+6624.7ms] [Preheat:Decel] seq=11, 21개 에셋, targetSize=384px
[+6683.7ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.1 (avg 8.33ms), frames: 127, dropped: 0, longest: 0 (0.0ms)
[+6683.8ms] [R2:Timing] seq=12, velocity=10943pt/s, 디바운스=50ms
[+6684.2ms] [R2] seq=12, visible=21, upgraded=21
[+6684.3ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+6684.3ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+6684.4ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+6685.6ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+6894.2ms] [Thumb:Check] seq=12, t=0.2s, velocity=10943, underSized=0/21
[+7234.3ms] [Preheat:Decel] seq=13, 24개 에셋, targetSize=384px
[+7309.4ms] [Thumb:Check] seq=12, t=0.6s, velocity=10943, underSized=10/21
[+8033.2ms] [Preheat:Decel] seq=14, 24개 에셋, targetSize=384px
[+8092.3ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.9 (avg 8.33ms), frames: 108, dropped: 0, longest: 0 (0.0ms)
[+8092.5ms] [R2:Timing] seq=15, velocity=26351pt/s, 디바운스=50ms
[+8092.9ms] [R2] seq=15, visible=24, upgraded=24
[+8092.9ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+8092.9ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+8093.1ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+8094.2ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+8300.6ms] [Thumb:Check] seq=15, t=0.2s, velocity=26351, underSized=0/24
[+8703.2ms] [Thumb:Check] seq=15, t=0.6s, velocity=26351, underSized=0/24
[+8791.2ms] [Preheat:Decel] seq=16, 24개 에셋, targetSize=384px
[+9516.6ms] [Preheat:Decel] seq=17, 24개 에셋, targetSize=384px
[+9575.7ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 100, dropped: 0, longest: 0 (0.0ms)
[+9576.1ms] [R2:Timing] seq=18, velocity=9326pt/s, 디바운스=50ms
[+9576.3ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+9576.4ms] [Pipeline] #2 target=384x384px → img=384x683px (100%), degraded=false
[+9576.5ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+9576.5ms] [R2] seq=18, visible=24, upgraded=24
[+9577.3ms] [Pipeline] #20 target=384x384px → img=384x512px (100%), degraded=false
[+9784.0ms] [Thumb:Check] seq=18, t=0.2s, velocity=9326, underSized=0/24
[+10204.6ms] [Thumb:Check] seq=18, t=0.6s, velocity=9326, underSized=0/24
[+10316.4ms] [Preheat:Decel] seq=19, 24개 에셋, targetSize=384px
[+10974.4ms] [Preheat:Decel] seq=20, 21개 에셋, targetSize=384px
[+12183.3ms] [Preheat:Decel] seq=22, 24개 에셋, targetSize=384px
[+12242.4ms] [Hitch] L2 Steady: hitch: 4.2 ms/s [Good], fps: 119.0 (avg 8.33ms), frames: 235, dropped: 1, longest: 1 (8.3ms)
[+12242.7ms] [R2:Timing] seq=23, velocity=11337pt/s, 디바운스=50ms
[+12242.9ms] [Pipeline] #1 target=384x384px → img=384x683px (100%), degraded=false
[+12243.0ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+12243.0ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+12243.2ms] [R2] seq=23, visible=24, upgraded=24
[+12244.2ms] [Pipeline] #20 target=384x384px → img=384x683px (100%), degraded=false
[+12450.8ms] [Thumb:Check] seq=23, t=0.2s, velocity=11337, underSized=0/24
[+12733.2ms] [Preheat:Decel] seq=24, 21개 에셋, targetSize=384px
[+12866.2ms] [Thumb:Check] seq=23, t=0.6s, velocity=11337, underSized=0/24
[+13291.3ms] [Preheat:Decel] seq=26, 21개 에셋, targetSize=384px
[+14508.5ms] [Preheat:Decel] seq=27, 21개 에셋, targetSize=384px
[+14567.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.5 (avg 8.33ms), frames: 225, dropped: 0, longest: 0 (0.0ms)
[+14567.2ms] [R2:Timing] seq=28, velocity=17203pt/s, 디바운스=50ms
[+14567.5ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+14567.6ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+14567.6ms] [R2] seq=28, visible=21, upgraded=21
[+14567.8ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+14569.5ms] [Pipeline] #20 target=384x384px → img=384x683px (100%), degraded=false
[+14773.1ms] [Thumb:Check] seq=28, t=0.2s, velocity=17203, underSized=1/21
[+14991.6ms] [Preheat:Decel] seq=29, 24개 에셋, targetSize=384px
[+15191.9ms] [Thumb:Check] seq=28, t=0.6s, velocity=17203, underSized=0/24
[+15533.0ms] [Preheat:Decel] seq=31, 24개 에셋, targetSize=384px
[+16367.0ms] [Preheat:Decel] seq=32, 24개 에셋, targetSize=384px
[+16426.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.3 (avg 8.33ms), frames: 176, dropped: 0, longest: 0 (0.0ms)
[+16426.2ms] [R2:Timing] seq=33, velocity=11674pt/s, 디바운스=50ms
[+16426.5ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+16426.5ms] [R2] seq=33, visible=24, upgraded=24
[+16426.6ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+16426.7ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+16427.8ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+16633.0ms] [Thumb:Check] seq=33, t=0.2s, velocity=11674, underSized=0/24
[+17033.2ms] [Thumb:Check] seq=33, t=0.6s, velocity=11674, underSized=0/24
```

---

<!-- LOG_ID: 260104_phase2_4 -->
## Phase 2 테스트 4 (2026-01-04 00:14)

```
=== PickPhoto Launch Log ===
Date: 2026-01-04 00:14:22
Device: iPhone14,2
============================
[+5.4ms] [LaunchArgs] didFinishLaunching: count=1
[+5.5ms] [LaunchArgs] --auto-scroll: false
[+7.5ms] [Env] Build: Release
[+7.5ms] [Env] LowPowerMode: OFF
[+7.5ms] [Env] PhotosAuth: authorized
[+7.8ms] [Config] deliveryMode: opportunistic
[+7.8ms] [Config] cancelPolicy: prepareForReuse
[+7.8ms] [Config] R2Recovery: disabled
[+77.3ms] [Timing] === 초기 로딩 시작 ===
[+111.6ms] [Timing] viewWillAppear: +34.2ms (초기 진입 - reloadData 스킵)
[+175.3ms] [Timing] C) 첫 레이아웃 완료: +98.1ms
[+185.5ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+195.5ms] [Preload] DISK HIT: F29EC2F9...
[+269.5ms] [Timing] === 초기 로딩 완료: +192.2ms (E0→E1: 16.1ms, E1→E2: 12.0ms) ===
[+924.4ms] [Scroll] First scroll 시작: +846.8ms
[+990.1ms] [Preheat:Decel] seq=1, 21개 에셋, targetSize=384px
[+1533.2ms] [Preheat:Decel] seq=2, 21개 에셋, targetSize=384px
[+1591.2ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 118.4 (avg 8.33ms), frames: 79, dropped: 0, longest: 0 (0.0ms)
[+1591.3ms] [Scroll] First scroll 완료: 667.2ms 동안 스크롤
[+1591.4ms] [R2:Timing] seq=3, velocity=13723pt/s, 디바운스=50ms
[+1591.7ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+1591.8ms] [R2] seq=3, visible=21, upgraded=21
[+1591.9ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+1799.5ms] [Thumb:Check] seq=3, t=0.2s, velocity=13723, underSized=0/21
[+2206.7ms] [Thumb:Check] seq=3, t=0.6s, velocity=13723, underSized=0/21
[+2632.0ms] [Preheat:Decel] seq=4, 21개 에셋, targetSize=384px
[+3332.7ms] [Preheat:Decel] seq=5, 21개 에셋, targetSize=384px
[+3391.5ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.0 (avg 8.33ms), frames: 119, dropped: 0, longest: 0 (0.0ms)
[+3391.7ms] [R2:Timing] seq=6, velocity=3606pt/s, 디바운스=50ms
[+3391.9ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+3392.1ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+3392.1ms] [R2] seq=6, visible=21, upgraded=21
[+3392.2ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+3602.2ms] [Thumb:Check] seq=6, t=0.2s, velocity=3606, underSized=0/21
[+4019.4ms] [Thumb:Check] seq=6, t=0.6s, velocity=3606, underSized=0/21
[+4733.2ms] [Preheat:Decel] seq=8, 21개 에셋, targetSize=384px
[+4791.5ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.9 (avg 8.33ms), frames: 111, dropped: 0, longest: 0 (0.0ms)
[+4791.7ms] [R2:Timing] seq=9, velocity=7330pt/s, 디바운스=50ms
[+4792.0ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+4792.0ms] [R2] seq=9, visible=21, upgraded=21
[+4792.1ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+4792.2ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+4997.7ms] [Thumb:Check] seq=9, t=0.2s, velocity=7330, underSized=0/21
[+5422.4ms] [Thumb:Check] seq=9, t=0.6s, velocity=7330, underSized=0/21
[+6457.5ms] [Preheat:Decel] seq=11, 24개 에셋, targetSize=384px
[+6516.4ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.0 (avg 8.33ms), frames: 120, dropped: 0, longest: 0 (0.0ms)
[+6516.6ms] [R2:Timing] seq=12, velocity=11580pt/s, 디바운스=50ms
[+6516.8ms] [Pipeline] #1 target=384x384px → img=384x512px (100%), degraded=false
[+6517.0ms] [R2] seq=12, visible=24, upgraded=24
[+6517.1ms] [Pipeline] #2 target=384x384px → img=384x512px (100%), degraded=false
[+6517.1ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+6725.0ms] [Thumb:Check] seq=12, t=0.2s, velocity=11580, underSized=0/24
[+7144.9ms] [Thumb:Check] seq=12, t=0.6s, velocity=11580, underSized=0/24
[+7916.0ms] [Preheat:Decel] seq=14, 24개 에셋, targetSize=384px
[+7974.9ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 103, dropped: 0, longest: 0 (0.0ms)
[+7975.1ms] [R2:Timing] seq=15, velocity=14995pt/s, 디바운스=50ms
[+7975.4ms] [Pipeline] #1 target=384x384px → img=512x384px (133%), degraded=false
[+7975.5ms] [R2] seq=15, visible=24, upgraded=24
[+7975.6ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+7975.7ms] [Pipeline] #3 target=384x384px → img=90x120px (23%), degraded=true
[+8184.6ms] [Thumb:Check] seq=15, t=0.2s, velocity=14995, underSized=0/24
[+8591.9ms] [Thumb:Check] seq=15, t=0.6s, velocity=14995, underSized=0/24
[+10032.9ms] [Preheat:Decel] seq=17, 24개 에셋, targetSize=384px
[+10091.8ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.6 (avg 8.33ms), frames: 89, dropped: 0, longest: 0 (0.0ms)
[+10091.9ms] [R2:Timing] seq=18, velocity=12866pt/s, 디바운스=50ms
[+10092.3ms] [R2] seq=18, visible=24, upgraded=24
[+10092.4ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+10092.4ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+10301.2ms] [Thumb:Check] seq=18, t=0.2s, velocity=12866, underSized=0/24
[+10707.2ms] [Thumb:Check] seq=18, t=0.6s, velocity=12866, underSized=0/24
[+12457.8ms] [Preheat:Decel] seq=22, 24개 에셋, targetSize=384px
[+12516.9ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.2 (avg 8.33ms), frames: 162, dropped: 0, longest: 0 (0.0ms)
[+12517.1ms] [R2:Timing] seq=23, velocity=10491pt/s, 디바운스=50ms
[+12517.4ms] [R2] seq=23, visible=24, upgraded=24
[+12517.5ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+12517.5ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+12725.4ms] [Thumb:Check] seq=23, t=0.2s, velocity=10491, underSized=0/24
[+13131.1ms] [Thumb:Check] seq=23, t=0.6s, velocity=10491, underSized=0/24
[+14391.3ms] [Preheat:Decel] seq=27, 21개 에셋, targetSize=384px
[+14450.4ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.1 (avg 8.33ms), frames: 140, dropped: 0, longest: 0 (0.0ms)
[+14450.6ms] [R2:Timing] seq=28, velocity=10915pt/s, 디바운스=50ms
[+14450.8ms] [Pipeline] #1 target=384x384px → img=384x683px (100%), degraded=false
[+14450.9ms] [R2] seq=28, visible=21, upgraded=21
[+14451.0ms] [Pipeline] #2 target=384x384px → img=384x683px (100%), degraded=false
[+14451.0ms] [Pipeline] #3 target=384x384px → img=384x683px (100%), degraded=false
[+14658.7ms] [Thumb:Check] seq=28, t=0.2s, velocity=10915, underSized=0/21
[+15058.9ms] [Thumb:Check] seq=28, t=0.6s, velocity=10915, underSized=0/21
[+16733.1ms] [Preheat:Decel] seq=32, 24개 에셋, targetSize=384px
[+16792.0ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.3 (avg 8.33ms), frames: 171, dropped: 0, longest: 0 (0.0ms)
[+16792.2ms] [R2:Timing] seq=33, velocity=10937pt/s, 디바운스=50ms
[+16792.5ms] [R2] seq=33, visible=24, upgraded=24
[+16792.8ms] [Pipeline] #1 target=384x384px → img=90x120px (23%), degraded=true
[+16792.8ms] [Pipeline] #2 target=384x384px → img=90x120px (23%), degraded=true
[+16792.9ms] [Pipeline] #3 target=384x384px → img=384x512px (100%), degraded=false
[+17001.6ms] [Thumb:Check] seq=33, t=0.2s, velocity=10937, underSized=0/24
[+17400.1ms] [Thumb:Check] seq=33, t=0.6s, velocity=10937, underSized=0/24
```

---

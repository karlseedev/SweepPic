# 썸네일 고해상도 전환 원본 로그 #1

원본 로그 데이터를 저장하는 문서입니다.

> **요약은 `260103thumbnailLog.md`에 있습니다.**

---

<!-- LOG_ID: 260103_baseline_0 -->
## 테스트 1: Baseline (2026-01-03 20:40)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 100ms
- CrossFade: 없음
- Preheat: 없음

**테스트 시나리오:**
- 짧은 스크롤 3회
- 긴 스크롤 3회

### R2 관련 로그

```
[R2:Timing] seq=3, velocity=17430pt/s, 디바운스=100ms
[Thumb:Check] seq=3, t=0.2s, velocity=17430, underSized=19/24
[Thumb:Check] seq=3, t=0.6s, velocity=17430, underSized=0/24
[R2:Timing] seq=6, velocity=8811pt/s, 디바운스=100ms
[Thumb:Check] seq=6, t=0.2s, velocity=8811, underSized=16/24
[Thumb:Check] seq=6, t=0.6s, velocity=8811, underSized=0/24
[R2:Timing] seq=9, velocity=8819pt/s, 디바운스=100ms
[Thumb:Check] seq=9, t=0.2s, velocity=8819, underSized=14/21
[Thumb:Check] seq=9, t=0.6s, velocity=8819, underSized=0/21
[R2:Timing] seq=16, velocity=28394pt/s, 디바운스=100ms
[Thumb:Check] seq=16, t=0.2s, velocity=28394, underSized=3/21
[Thumb:Check] seq=16, t=0.6s, velocity=28394, underSized=0/21
[R2:Timing] seq=22, velocity=13090pt/s, 디바운스=100ms
[Thumb:Check] seq=22, t=0.2s, velocity=13090, underSized=6/24
[Thumb:Check] seq=22, t=0.6s, velocity=13090, underSized=0/24
[R2:Timing] seq=29, velocity=11666pt/s, 디바운스=100ms
[Thumb:Check] seq=29, t=0.2s, velocity=11666, underSized=9/21
[Thumb:Check] seq=29, t=0.6s, velocity=11666, underSized=0/21
```

> 원본 로그는 대화 요약에서 추출 (전체 로그 없음)

---

<!-- LOG_ID: 260103_baseline_2 -->
## 테스트 2: Baseline (2026-01-03 20:44)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 100ms
- CrossFade: 없음
- Preheat: 없음

**테스트 시나리오:**
- 짧은 스크롤 3회
- 긴 스크롤 3회

### R2 관련 로그

```
[+2194.4ms] [R2:Timing] seq=3, velocity=9698pt/s, 디바운스=100ms
[+2402.7ms] [Thumb:Check] seq=3, t=0.2s, velocity=9698, underSized=14/21
[+2822.1ms] [Thumb:Check] seq=3, t=0.6s, velocity=9698, underSized=0/24
[+3653.4ms] [R2:Timing] seq=6, velocity=7449pt/s, 디바운스=100ms
[+3861.0ms] [Thumb:Check] seq=6, t=0.2s, velocity=7449, underSized=13/21
[+4268.0ms] [Thumb:Check] seq=6, t=0.6s, velocity=7449, underSized=0/21
[+5195.3ms] [R2:Timing] seq=9, velocity=8097pt/s, 디바운스=100ms
[+5401.2ms] [Thumb:Check] seq=9, t=0.2s, velocity=8097, underSized=12/24
[+5803.5ms] [Thumb:Check] seq=9, t=0.6s, velocity=8097, underSized=0/24
[+7678.8ms] [R2:Timing] seq=15, velocity=18104pt/s, 디바운스=100ms
[+7884.9ms] [Thumb:Check] seq=15, t=0.2s, velocity=18104, underSized=9/24
[+8310.4ms] [Thumb:Check] seq=15, t=0.6s, velocity=18104, underSized=0/24
[+10137.3ms] [R2:Timing] seq=21, velocity=15406pt/s, 디바운스=100ms
[+10348.6ms] [Thumb:Check] seq=21, t=0.2s, velocity=15406, underSized=8/21
[+10769.9ms] [Thumb:Check] seq=21, t=0.6s, velocity=15406, underSized=0/21
[+12470.8ms] [R2:Timing] seq=27, velocity=18795pt/s, 디바운스=100ms
[+12678.2ms] [Thumb:Check] seq=27, t=0.2s, velocity=18795, underSized=5/21
[+13101.9ms] [Thumb:Check] seq=27, t=0.6s, velocity=18795, underSized=0/21
```

### 전체 원본 로그

```
=== PickPhoto Launch Log ===
Date: 2026-01-03 20:44:37
Device: iPhone14,2
============================
[+7.8ms] [LaunchArgs] didFinishLaunching: count=1
[+7.9ms] [LaunchArgs] --auto-scroll: false
[+8.8ms] [Env] Build: Release
[+8.8ms] [Env] LowPowerMode: OFF
[+8.8ms] [Env] PhotosAuth: authorized
[+9.0ms] [Config] deliveryMode: opportunistic
[+9.0ms] [Config] cancelPolicy: prepareForReuse
[+9.0ms] [Config] R2Recovery: disabled
[+125.6ms] [Timing] === 초기 로딩 시작 ===
[+127.5ms] [Timing] viewWillAppear: +1.9ms (초기 진입 - reloadData 스킵)
[+166.5ms] [Timing] C) 첫 레이아웃 완료: +40.9ms
[+180.1ms] [LaunchArgs] count=1, contains --auto-scroll: false
[+194.0ms] [Preload] DISK HIT: F29EC2F9...
[+198.7ms] [Preload] DISK HIT: F0146B79...
[+203.0ms] [Preload] DISK HIT: 261056EB...
[+207.7ms] [Preload] DISK HIT: D10201EA...
[+213.2ms] [Preload] DISK HIT: 5FEA5EE7...
[+217.2ms] [Preload] DISK HIT: 7F2BACF6...
[+221.0ms] [Preload] DISK HIT: 5AE38379...
[+224.9ms] [Preload] DISK HIT: 2CD47CFB...
[+228.6ms] [Preload] DISK HIT: 48EC0DA1...
[+232.3ms] [Preload] DISK HIT: E0FEC1AD...
[+236.5ms] [Preload] DISK HIT: 82E65101...
[+240.8ms] [Preload] DISK HIT: 0EBF73ED...
[+240.8ms] [Timing] E0) finishInitialDisplay 시작: +115.3ms (reason: preload complete, preloaded: 12/12)
[+246.2ms] [Thumb:Req] #1 target=384x384px, fullSize=true
[+246.4ms] [Timing] D) 첫 셀 표시: +120.8ms (indexPath: [0, 0])
[+246.9ms] [Thumb:Req] #2 target=384x384px, fullSize=true
[+247.3ms] [Thumb:Req] #3 target=384x384px, fullSize=true
[+247.6ms] [Pipeline] #1 target=384x384px → img=120x90px (31%), degraded=true
[+247.7ms] [Pipeline] #2 target=384x384px → img=120x90px (31%), degraded=true
[+247.7ms] [Thumb:Req] #4 target=384x384px, fullSize=true
[+247.8ms] [Pipeline] #3 target=384x384px → img=120x90px (31%), degraded=true
[+248.1ms] [Thumb:Req] #5 target=384x384px, fullSize=true
[+249.8ms] [Thumb:Req] #10 target=384x384px, fullSize=true
[+249.8ms] [Pipeline] requestImage #10: +240.8ms
[+256.7ms] [Timing] E1) reloadData+layout 완료: +131.1ms (E0→E1: 15.9ms)
[+257.7ms] [Thumb:Req] #20 target=384x384px, fullSize=true
[+257.7ms] [Pipeline] requestImage #20: +248.7ms
[+258.0ms] [Pipeline] #20 target=384x384px → img=90x120px (23%), degraded=true
[+261.6ms] [Thumb:Req] #30 target=384x384px, fullSize=true
[+268.4ms] [Timing] E2) scrollToItem+layout 완료: +142.9ms (E1→E2: 11.7ms)
[+268.5ms] [Timing] === 초기 로딩 완료: +142.9ms (E0→E1: 15.9ms, E1→E2: 11.7ms) ===
[+268.5ms] [Timing] 최종 통계: cellForItemAt 36회, 총 17.7ms, 평균 0.49ms
[+268.5ms] [Initial Load] req: 24 (92.5/s), cancel: 0 (0.0/s), complete: 0 (0.0/s)
[+268.5ms] [Initial Load] degraded: 24, maxInFlight: 24
[+268.5ms] [Initial Load] latency avg: 0.0ms, p95: 0.0ms, max: 0.0ms
[+268.5ms] [Initial Load] preheat: 0회, 총 0개 에셋
[+268.5ms] [Initial Load] memHit: 12, memMiss: 36, hitRate: 25.0%
[+268.5ms] [Initial Load] diskCacheMismatch: 0, pipelineMismatch: 0
[+268.5ms] [Initial Load] grayShown: 24, grayResolved: 12, pending: 12
[+270.1ms] [Thumb:Res] #1 img=120x90px, target=384x384px, degraded=true
[+270.1ms] [Thumb:Res] #2 img=120x90px, target=384x384px, degraded=true
[+270.1ms] [Thumb:Res] #3 img=120x90px, target=384x384px, degraded=true
[+270.2ms] [Thumb:Res] #4 img=120x90px, target=384x384px, degraded=true
[+270.2ms] [Thumb:Res] #5 img=90x120px, target=384x384px, degraded=true
[+270.2ms] [Thumb:Res] #10 img=120x90px, target=384x384px, degraded=true
[+270.4ms] [Thumb:Res] #20 img=90x120px, target=384x384px, degraded=true
[+291.6ms] [Thumb:Res] #30 img=512x384px, target=384x384px, degraded=false
[+332.8ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+332.9ms] [Thumb:Res] #40 img=384x512px, target=384x384px, degraded=false
[+1219.2ms] [Scroll] First scroll 시작: +1093.4ms
[+2193.8ms] [Hitch] L1 First: hitch: 0.0 ms/s [Good], fps: 119.0 (avg 8.33ms), frames: 116, dropped: 0, longest: 0 (0.0ms)
[+2193.8ms] [L1 First] memHit: 0, memMiss: 78, hitRate: 0.0%
[+2193.9ms] [L1 First] diskCacheMismatch: 0, pipelineMismatch: 0
[+2193.9ms] [L1 First] grayShown: 23, grayResolved: 102, pending: -79
[+2194.0ms] [L1 First] req: 102 (46.7/s), cancel: 60 (27.5/s), complete: 102 (46.7/s)
[+2194.0ms] [L1 First] degraded: 102, maxInFlight: 24
[+2194.0ms] [L1 First] latency avg: 20.1ms, p95: 88.6ms, max: 148.3ms
[+2194.0ms] [L1 First] preheat: 0회, 총 0개 에셋
[+2194.0ms] [Scroll] First scroll 완료: 975.2ms 동안 스크롤
[+2194.4ms] [R2:Timing] seq=3, velocity=9698pt/s, 디바운스=100ms
[+2195.2ms] [R2] seq=3, visible=21, upgraded=21
[+2402.7ms] [Thumb:Check] seq=3, t=0.2s, velocity=9698, underSized=14/21
[+2529.8ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+2822.1ms] [Thumb:Check] seq=3, t=0.6s, velocity=9698, underSized=0/24
[+3652.7ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 101, dropped: 0, longest: 0 (0.0ms)
[+3653.0ms] [L2 Steady] latency avg: 82.7ms, p95: 334.8ms, max: 334.8ms
[+3653.0ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+3653.4ms] [R2:Timing] seq=6, velocity=7449pt/s, 디바운스=100ms
[+3654.8ms] [R2] seq=6, visible=21, upgraded=21
[+3861.0ms] [Thumb:Check] seq=6, t=0.2s, velocity=7449, underSized=13/21
[+4016.8ms] [Pipeline] #40 target=384x384px → img=384x683px (100%), degraded=false
[+4268.0ms] [Thumb:Check] seq=6, t=0.6s, velocity=7449, underSized=0/21
[+5194.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 118.8 (avg 8.33ms), frames: 102, dropped: 0, longest: 0 (0.0ms)
[+5194.8ms] [L2 Steady] latency avg: 83.5ms, p95: 358.4ms, max: 368.7ms
[+5194.8ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+5195.3ms] [R2:Timing] seq=9, velocity=8097pt/s, 디바운스=100ms
[+5196.8ms] [R2] seq=9, visible=24, upgraded=24
[+5401.2ms] [Thumb:Check] seq=9, t=0.2s, velocity=8097, underSized=12/24
[+5468.8ms] [Pipeline] #40 target=384x384px → img=384x683px (100%), degraded=false
[+5803.5ms] [Thumb:Check] seq=9, t=0.6s, velocity=8097, underSized=0/24
[+7678.1ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.4 (avg 8.33ms), frames: 224, dropped: 0, longest: 0 (0.0ms)
[+7678.4ms] [L2 Steady] latency avg: 21.1ms, p95: 132.1ms, max: 312.0ms
[+7678.4ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+7678.8ms] [R2:Timing] seq=15, velocity=18104pt/s, 디바운스=100ms
[+7680.4ms] [R2] seq=15, visible=24, upgraded=24
[+7884.9ms] [Thumb:Check] seq=15, t=0.2s, velocity=18104, underSized=9/24
[+7906.1ms] [Pipeline] #40 target=384x384px → img=384x512px (100%), degraded=false
[+8310.4ms] [Thumb:Check] seq=15, t=0.6s, velocity=18104, underSized=0/24
[+10136.6ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.4 (avg 8.33ms), frames: 233, dropped: 0, longest: 0 (0.0ms)
[+10136.9ms] [L2 Steady] latency avg: 25.8ms, p95: 186.5ms, max: 364.2ms
[+10136.9ms] [L2 Steady] preheat: 1회, 총 66개 에셋
[+10137.3ms] [R2:Timing] seq=21, velocity=15406pt/s, 디바운스=100ms
[+10138.5ms] [R2] seq=21, visible=21, upgraded=21
[+10348.6ms] [Thumb:Check] seq=21, t=0.2s, velocity=15406, underSized=8/21
[+10409.3ms] [Pipeline] #40 target=384x384px → img=384x683px (100%), degraded=false
[+10769.9ms] [Thumb:Check] seq=21, t=0.6s, velocity=15406, underSized=0/21
[+12470.5ms] [Hitch] L2 Steady: hitch: 0.0 ms/s [Good], fps: 119.5 (avg 8.33ms), frames: 233, dropped: 0, longest: 0 (0.0ms)
[+12470.5ms] [L2 Steady] preheat: 1회, 총 63개 에셋
[+12470.8ms] [R2:Timing] seq=27, velocity=18795pt/s, 디바운스=100ms
[+12471.4ms] [R2] seq=27, visible=21, upgraded=21
[+12678.2ms] [Thumb:Check] seq=27, t=0.2s, velocity=18795, underSized=5/21
[+12775.9ms] [Pipeline] #40 target=384x384px → img=384x683px (100%), degraded=false
[+13101.9ms] [Thumb:Check] seq=27, t=0.6s, velocity=18795, underSized=0/21
```

---

<!-- LOG_ID: 260103_baseline_3 -->
## 테스트 3: Baseline (2026-01-03 22:38)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 100ms

**테스트 시나리오:**
- 느린 스크롤 3회
- 빠른 스크롤 3회
- 긴 스크롤 3회

### R2 관련 로그

```
[+5077.9ms] [R2:Timing] seq=3, velocity=1137pt/s, 디바운스=100ms
[+5285.0ms] [Thumb:Check] seq=3, t=0.2s, velocity=1137, underSized=10/24
[+5708.7ms] [Thumb:Check] seq=3, t=0.6s, velocity=1137, underSized=0/24
[+7686.0ms] [R2:Timing] seq=6, velocity=2116pt/s, 디바운스=100ms
[+7891.9ms] [Thumb:Check] seq=6, t=0.2s, velocity=2116, underSized=0/24
[+8297.2ms] [Thumb:Check] seq=6, t=0.6s, velocity=2116, underSized=0/24
[+9919.4ms] [R2:Timing] seq=9, velocity=4559pt/s, 디바운스=100ms
[+10125.4ms] [Thumb:Check] seq=9, t=0.2s, velocity=4559, underSized=0/21
[+10525.6ms] [Thumb:Check] seq=9, t=0.6s, velocity=4559, underSized=0/21
[+13702.8ms] [R2:Timing] seq=12, velocity=6055pt/s, 디바운스=100ms
[+13914.3ms] [Thumb:Check] seq=12, t=0.2s, velocity=6055, underSized=19/21
[+14325.8ms] [Thumb:Check] seq=12, t=0.6s, velocity=6055, underSized=0/21
[+15927.8ms] [R2:Timing] seq=15, velocity=13160pt/s, 디바운스=100ms
[+16133.9ms] [Thumb:Check] seq=15, t=0.2s, velocity=13160, underSized=13/21
[+16559.1ms] [Thumb:Check] seq=15, t=0.6s, velocity=13160, underSized=0/21
[+17911.4ms] [R2:Timing] seq=18, velocity=5282pt/s, 디바운스=100ms
[+18118.9ms] [Thumb:Check] seq=18, t=0.2s, velocity=5282, underSized=11/24
[+18525.9ms] [Thumb:Check] seq=18, t=0.6s, velocity=5282, underSized=0/24
[+21628.1ms] [R2:Timing] seq=23, velocity=13840pt/s, 디바운스=100ms
[+21834.3ms] [Thumb:Check] seq=23, t=0.2s, velocity=13840, underSized=17/21
[+22259.5ms] [Thumb:Check] seq=23, t=0.6s, velocity=13840, underSized=0/21
[+24261.5ms] [R2:Timing] seq=28, velocity=11544pt/s, 디바운스=100ms
[+24469.1ms] [Thumb:Check] seq=28, t=0.2s, velocity=11544, underSized=1/21
[+24877.7ms] [Thumb:Check] seq=28, t=0.6s, velocity=11544, underSized=0/21
[+27036.7ms] [R2:Timing] seq=33, velocity=12249pt/s, 디바운스=100ms
[+27242.7ms] [Thumb:Check] seq=33, t=0.2s, velocity=12249, underSized=21/24
[+27659.6ms] [Thumb:Check] seq=33, t=0.6s, velocity=12249, underSized=0/24
```

---

<!-- LOG_ID: 260103_baseline_4 -->
## 테스트 4: Baseline (2026-01-03 22:41)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 100ms

**테스트 시나리오:**
- 느린 스크롤 3회
- 중간 스크롤 3회
- 빠른 스크롤 3회

### R2 관련 로그

```
[+1770.5ms] [R2:Timing] seq=2, velocity=2923pt/s, 디바운스=100ms
[+1980.4ms] [Thumb:Check] seq=2, t=0.2s, velocity=2923, underSized=10/24
[+2384.7ms] [Thumb:Check] seq=2, t=0.6s, velocity=2923, underSized=0/24
[+3628.6ms] [R2:Timing] seq=4, velocity=2723pt/s, 디바운스=100ms
[+3839.3ms] [Thumb:Check] seq=4, t=0.2s, velocity=2723, underSized=0/24
[+4251.5ms] [Thumb:Check] seq=4, t=0.6s, velocity=2723, underSized=0/24
[+5418.8ms] [R2:Timing] seq=6, velocity=2652pt/s, 디바운스=100ms
[+5624.7ms] [Thumb:Check] seq=6, t=0.2s, velocity=2652, underSized=0/24
[+6047.3ms] [Thumb:Check] seq=6, t=0.6s, velocity=2652, underSized=0/24
[+7345.4ms] [R2:Timing] seq=9, velocity=5218pt/s, 디바운스=100ms
[+7551.4ms] [Thumb:Check] seq=9, t=0.2s, velocity=5218, underSized=15/24
[+7977.3ms] [Thumb:Check] seq=9, t=0.6s, velocity=5218, underSized=0/24
[+9428.9ms] [R2:Timing] seq=12, velocity=3954pt/s, 디바운스=100ms
[+9636.4ms] [Thumb:Check] seq=12, t=0.2s, velocity=3954, underSized=6/21
[+10051.7ms] [Thumb:Check] seq=12, t=0.6s, velocity=3954, underSized=0/21
[+11578.5ms] [R2:Timing] seq=15, velocity=4285pt/s, 디바운스=100ms
[+11784.9ms] [Thumb:Check] seq=15, t=0.2s, velocity=4285, underSized=6/21
[+12185.2ms] [Thumb:Check] seq=15, t=0.6s, velocity=4285, underSized=0/21
[+15454.2ms] [R2:Timing] seq=18, velocity=13076pt/s, 디바운스=100ms
[+15665.9ms] [Thumb:Check] seq=18, t=0.2s, velocity=13076, underSized=14/24
[+16070.2ms] [Thumb:Check] seq=18, t=0.6s, velocity=13076, underSized=0/24
[+18179.1ms] [R2:Timing] seq=21, velocity=11318pt/s, 디바운스=100ms
[+18385.5ms] [Thumb:Check] seq=21, t=0.2s, velocity=11318, underSized=5/21
[+18785.4ms] [Thumb:Check] seq=21, t=0.6s, velocity=11318, underSized=0/21
[+20445.9ms] [R2:Timing] seq=24, velocity=12564pt/s, 디바운스=100ms
[+20651.9ms] [Thumb:Check] seq=24, t=0.2s, velocity=12564, underSized=11/21
[+21052.1ms] [Thumb:Check] seq=24, t=0.6s, velocity=12564, underSized=0/21
```

---

<!-- LOG_ID: 260103_baseline_5 -->
## 테스트 5: Baseline (2026-01-03 22:44)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 100ms

**테스트 시나리오:**
- 느린 스크롤 3회
- 중간 스크롤 3회
- 빠른 스크롤 3회

### R2 관련 로그

```
[+3879.0ms] [R2:Timing] seq=3, velocity=3106pt/s, 디바운스=100ms
[+4090.5ms] [Thumb:Check] seq=3, t=0.2s, velocity=3106, underSized=18/21
[+4509.9ms] [Thumb:Check] seq=3, t=0.6s, velocity=3106, underSized=0/21
[+7028.7ms] [R2:Timing] seq=6, velocity=4276pt/s, 디바운스=100ms
[+7234.6ms] [Thumb:Check] seq=6, t=0.2s, velocity=4276, underSized=10/24
[+7643.4ms] [Thumb:Check] seq=6, t=0.6s, velocity=4276, underSized=0/24
[+9912.1ms] [R2:Timing] seq=9, velocity=2374pt/s, 디바운스=100ms
[+10113.8ms] [Thumb:Check] seq=9, t=0.2s, velocity=2374, underSized=0/21
[+10528.4ms] [Thumb:Check] seq=9, t=0.6s, velocity=2374, underSized=0/21
[+13220.6ms] [R2:Timing] seq=12, velocity=9569pt/s, 디바운스=100ms
[+13426.7ms] [Thumb:Check] seq=12, t=0.2s, velocity=9569, underSized=11/24
[+13843.7ms] [Thumb:Check] seq=12, t=0.6s, velocity=9569, underSized=0/24
[+15670.8ms] [R2:Timing] seq=15, velocity=8003pt/s, 디바운스=100ms
[+15878.4ms] [Thumb:Check] seq=15, t=0.2s, velocity=8003, underSized=16/21
[+16277.1ms] [Thumb:Check] seq=15, t=0.6s, velocity=8003, underSized=0/21
[+18112.6ms] [R2:Timing] seq=18, velocity=5742pt/s, 디바운스=100ms
[+18322.4ms] [Thumb:Check] seq=18, t=0.2s, velocity=5742, underSized=6/21
[+18728.7ms] [Thumb:Check] seq=18, t=0.6s, velocity=5742, underSized=0/21
[+22621.1ms] [R2:Timing] seq=23, velocity=16023pt/s, 디바운스=100ms
[+22828.6ms] [Thumb:Check] seq=23, t=0.2s, velocity=16023, underSized=7/21
[+23244.0ms] [Thumb:Check] seq=23, t=0.6s, velocity=16023, underSized=0/21
[+25512.9ms] [R2:Timing] seq=26, velocity=10951pt/s, 디바운스=100ms
[+25720.4ms] [Thumb:Check] seq=26, t=0.2s, velocity=10951, underSized=2/21
[+26144.3ms] [Thumb:Check] seq=26, t=0.6s, velocity=10951, underSized=0/21
[+27988.0ms] [R2:Timing] seq=29, velocity=11105pt/s, 디바운스=100ms
[+28195.5ms] [Thumb:Check] seq=29, t=0.2s, velocity=11105, underSized=5/21
[+28595.8ms] [Thumb:Check] seq=29, t=0.6s, velocity=11105, underSized=0/21
```

---

## 테스트 6 원본 (2026-01-03 22:53)

<!-- LOG_ID: 260103_baseline_6 -->

```
[+1949.7ms] [R2:Timing] seq=2, velocity=3258pt/s, 디바운스=100ms
[+2156.7ms] [Thumb:Check] seq=2, t=0.2s, velocity=3258, underSized=2/24
[+2573.6ms] [Thumb:Check] seq=2, t=0.6s, velocity=3258, underSized=1/24
[+3934.0ms] [R2:Timing] seq=5, velocity=4483pt/s, 디바운스=100ms
[+4141.1ms] [Thumb:Check] seq=5, t=0.2s, velocity=4483, underSized=4/24
[+4541.1ms] [Thumb:Check] seq=5, t=0.6s, velocity=4483, underSized=0/24
[+5891.2ms] [R2:Timing] seq=8, velocity=2483pt/s, 디바운스=100ms
[+6100.0ms] [Thumb:Check] seq=8, t=0.2s, velocity=2483, underSized=0/21
[+6510.3ms] [Thumb:Check] seq=8, t=0.6s, velocity=2483, underSized=0/21
[+8300.5ms] [R2:Timing] seq=11, velocity=7457pt/s, 디바운스=100ms
[+8508.1ms] [Thumb:Check] seq=11, t=0.2s, velocity=7457, underSized=19/24
[+8923.2ms] [Thumb:Check] seq=11, t=0.6s, velocity=7457, underSized=0/24
[+10108.0ms] [R2:Timing] seq=14, velocity=5498pt/s, 디바운스=100ms
[+10316.7ms] [Thumb:Check] seq=14, t=0.2s, velocity=5498, underSized=6/21
[+10728.8ms] [Thumb:Check] seq=14, t=0.6s, velocity=5498, underSized=0/21
[+12158.1ms] [R2:Timing] seq=17, velocity=4915pt/s, 디바운스=100ms
[+12359.1ms] [Thumb:Check] seq=17, t=0.2s, velocity=4915, underSized=5/21
[+12774.9ms] [Thumb:Check] seq=17, t=0.6s, velocity=4915, underSized=0/21
[+15074.9ms] [R2:Timing] seq=21, velocity=12828pt/s, 디바운스=100ms
[+15279.0ms] [Thumb:Check] seq=21, t=0.2s, velocity=12828, underSized=19/21
[+15702.5ms] [Thumb:Check] seq=21, t=0.6s, velocity=12828, underSized=0/21
[+16991.7ms] [R2:Timing] seq=25, velocity=10661pt/s, 디바운스=100ms
[+17192.7ms] [Thumb:Check] seq=25, t=0.2s, velocity=10661, underSized=19/21
[+17617.9ms] [Thumb:Check] seq=25, t=0.6s, velocity=10661, underSized=0/21
[+19000.2ms] [R2:Timing] seq=29, velocity=12018pt/s, 디바운스=100ms
[+19208.6ms] [Thumb:Check] seq=29, t=0.2s, velocity=12018, underSized=7/24
[+19624.2ms] [Thumb:Check] seq=29, t=0.6s, velocity=12018, underSized=0/24
```

---

# 썸네일 고해상도 전환 원본 로그 #1

원본 로그 데이터를 저장하는 문서입니다.

> **요약은 `260103thumbnailLog.md`에 있습니다.**

---

<!-- LOG_ID: 260103_baseline_1 -->
## Baseline 1 (2026-01-03 22:41)

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

<!-- LOG_ID: 260103_baseline_2 -->
## Baseline 2 (2026-01-03 22:44)

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

<!-- LOG_ID: 260103_baseline_3 -->
## Baseline 3 (2026-01-03 22:53)

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

<!-- LOG_ID: 260103_phase1_1 -->
## Phase 1 테스트 1 (2026-01-03 23:12)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 50ms
- CrossFade: 0.15s

**테스트 시나리오:**
- 느린 스크롤 3회
- 중간 스크롤 3회
- 빠른 스크롤 3회

### R2 관련 로그

```
[+1785.6ms] [R2:Timing] seq=2, velocity=3155pt/s, 디바운스=50ms
[+1995.6ms] [Thumb:Check] seq=2, t=0.2s, velocity=3155, underSized=12/21
[+2409.6ms] [Thumb:Check] seq=2, t=0.6s, velocity=3155, underSized=0/21
[+3943.9ms] [R2:Timing] seq=4, velocity=2930pt/s, 디바운스=50ms
[+4151.4ms] [Thumb:Check] seq=4, t=0.2s, velocity=2930, underSized=0/24
[+4575.7ms] [Thumb:Check] seq=4, t=0.6s, velocity=2930, underSized=0/24
[+5660.6ms] [R2:Timing] seq=6, velocity=3834pt/s, 디바운스=50ms
[+5867.7ms] [Thumb:Check] seq=6, t=0.2s, velocity=3834, underSized=0/24
[+6276.6ms] [Thumb:Check] seq=6, t=0.6s, velocity=3834, underSized=0/24
[+8194.2ms] [R2:Timing] seq=9, velocity=7019pt/s, 디바운스=50ms
[+8403.0ms] [Thumb:Check] seq=9, t=0.2s, velocity=7019, underSized=19/24
[+8825.4ms] [Thumb:Check] seq=9, t=0.6s, velocity=7019, underSized=0/24
[+10469.3ms] [R2:Timing] seq=12, velocity=7768pt/s, 디바운스=50ms
[+10676.9ms] [Thumb:Check] seq=12, t=0.2s, velocity=7768, underSized=9/24
[+11077.1ms] [Thumb:Check] seq=12, t=0.6s, velocity=7768, underSized=0/24
[+12861.1ms] [R2:Timing] seq=15, velocity=7502pt/s, 디바운스=50ms
[+13070.1ms] [Thumb:Check] seq=15, t=0.2s, velocity=7502, underSized=13/21
[+13492.4ms] [Thumb:Check] seq=15, t=0.6s, velocity=7502, underSized=0/21
[+15703.1ms] [R2:Timing] seq=21, velocity=13574pt/s, 디바운스=50ms
[+15910.6ms] [Thumb:Check] seq=21, t=0.2s, velocity=13574, underSized=10/21
[+16326.0ms] [Thumb:Check] seq=21, t=0.6s, velocity=13574, underSized=0/21
[+18703.4ms] [R2:Timing] seq=27, velocity=15367pt/s, 디바운스=50ms
[+18909.8ms] [Thumb:Check] seq=27, t=0.2s, velocity=15367, underSized=5/24
[+19326.3ms] [Thumb:Check] seq=27, t=0.6s, velocity=15367, underSized=0/24
[+21662.0ms] [R2:Timing] seq=32, velocity=7795pt/s, 디바운스=50ms
[+21871.1ms] [Thumb:Check] seq=32, t=0.2s, velocity=7795, underSized=12/21
[+22278.1ms] [Thumb:Check] seq=32, t=0.6s, velocity=7795, underSized=0/21
```

---

<!-- LOG_ID: 260103_phase1_2 -->
## Phase 1 테스트 2 (2026-01-03 23:19)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 50ms
- CrossFade: 0.15s

**테스트 시나리오:**
- 느린 스크롤 3회
- 중간 스크롤 3회
- 빠른 스크롤 3회

### R2 관련 로그

```
[+2530.6ms] [R2:Timing] seq=3, velocity=6087pt/s, 디바운스=50ms
[+2737.8ms] [Thumb:Check] seq=3, t=0.2s, velocity=6087, underSized=13/21
[+3153.1ms] [Thumb:Check] seq=3, t=0.6s, velocity=6087, underSized=0/21
[+4888.7ms] [R2:Timing] seq=6, velocity=4080pt/s, 디바운스=50ms
[+5099.6ms] [Thumb:Check] seq=6, t=0.2s, velocity=4080, underSized=5/24
[+5520.0ms] [Thumb:Check] seq=6, t=0.6s, velocity=4080, underSized=0/24
[+7147.1ms] [R2:Timing] seq=9, velocity=5821pt/s, 디바운스=50ms
[+7353.3ms] [Thumb:Check] seq=9, t=0.2s, velocity=5821, underSized=2/21
[+7751.4ms] [Thumb:Check] seq=9, t=0.6s, velocity=5821, underSized=0/21
[+11514.3ms] [R2:Timing] seq=13, velocity=6184pt/s, 디바운스=50ms
[+11722.0ms] [Thumb:Check] seq=13, t=0.2s, velocity=6184, underSized=19/24
[+12120.7ms] [Thumb:Check] seq=13, t=0.6s, velocity=6184, underSized=0/24
[+13103.7ms] [R2:Timing] seq=16, velocity=9525pt/s, 디바운스=50ms
[+13305.6ms] [Thumb:Check] seq=16, t=0.2s, velocity=9525, underSized=13/21
[+13720.7ms] [Thumb:Check] seq=16, t=0.6s, velocity=9525, underSized=0/21
[+15306.3ms] [R2:Timing] seq=19, velocity=11904pt/s, 디바운스=50ms
[+15513.8ms] [Thumb:Check] seq=19, t=0.2s, velocity=11904, underSized=4/21
[+15920.9ms] [Thumb:Check] seq=19, t=0.6s, velocity=11904, underSized=0/21
[+18723.2ms] [R2:Timing] seq=23, velocity=13094pt/s, 디바운스=50ms
[+18931.4ms] [Thumb:Check] seq=23, t=0.2s, velocity=13094, underSized=5/24
[+19339.4ms] [Thumb:Check] seq=23, t=0.6s, velocity=13094, underSized=0/24
[+20940.1ms] [R2:Timing] seq=27, velocity=12518pt/s, 디바운스=50ms
[+21151.7ms] [Thumb:Check] seq=27, t=0.2s, velocity=12518, underSized=7/24
[+21554.7ms] [Thumb:Check] seq=27, t=0.6s, velocity=12518, underSized=0/24
[+22998.6ms] [R2:Timing] seq=31, velocity=10182pt/s, 디바운스=50ms
[+23206.4ms] [Thumb:Check] seq=31, t=0.2s, velocity=10182, underSized=8/24
[+23621.5ms] [Thumb:Check] seq=31, t=0.6s, velocity=10182, underSized=0/24
```

---

<!-- LOG_ID: 260103_phase1_3 -->
## Phase 1 테스트 3 (2026-01-03 23:22)

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 50ms
- CrossFade: 0.15s

**테스트 시나리오:**
- 느린 스크롤 3회
- 중간 스크롤 3회
- 빠른 스크롤 3회

### R2 관련 로그

```
[+2273.2ms] [R2:Timing] seq=2, velocity=3055pt/s, 디바운스=50ms
[+2484.7ms] [Thumb:Check] seq=2, t=0.2s, velocity=3055, underSized=14/24
[+2902.4ms] [Thumb:Check] seq=2, t=0.6s, velocity=3055, underSized=0/24
[+4163.0ms] [R2:Timing] seq=4, velocity=3019pt/s, 디바운스=50ms
[+4368.9ms] [Thumb:Check] seq=4, t=0.2s, velocity=3019, underSized=0/24
[+4769.2ms] [Thumb:Check] seq=4, t=0.6s, velocity=3019, underSized=0/24
[+5904.7ms] [R2:Timing] seq=6, velocity=3265pt/s, 디바운스=50ms
[+6116.0ms] [Thumb:Check] seq=6, t=0.2s, velocity=3265, underSized=0/24
[+6520.9ms] [Thumb:Check] seq=6, t=0.6s, velocity=3265, underSized=0/24
[+8955.1ms] [R2:Timing] seq=9, velocity=9473pt/s, 디바운스=50ms
[+9162.6ms] [Thumb:Check] seq=9, t=0.2s, velocity=9473, underSized=15/21
[+9569.6ms] [Thumb:Check] seq=9, t=0.6s, velocity=9473, underSized=0/21
[+11146.8ms] [R2:Timing] seq=12, velocity=10006pt/s, 디바운스=50ms
[+11354.5ms] [Thumb:Check] seq=12, t=0.2s, velocity=10006, underSized=9/21
[+11769.8ms] [Thumb:Check] seq=12, t=0.6s, velocity=10006, underSized=0/21
[+13188.5ms] [R2:Timing] seq=15, velocity=11243pt/s, 디바운스=50ms
[+13397.2ms] [Thumb:Check] seq=15, t=0.2s, velocity=11243, underSized=9/21
[+13803.3ms] [Thumb:Check] seq=15, t=0.6s, velocity=11243, underSized=0/21
[+16747.3ms] [R2:Timing] seq=21, velocity=20761pt/s, 디바운스=50ms
[+16953.5ms] [Thumb:Check] seq=21, t=0.2s, velocity=20761, underSized=9/24
[+17370.3ms] [Thumb:Check] seq=21, t=0.6s, velocity=20761, underSized=0/24
[+19197.5ms] [R2:Timing] seq=27, velocity=16428pt/s, 디바운스=50ms
[+19405.1ms] [Thumb:Check] seq=27, t=0.2s, velocity=16428, underSized=16/21
[+19803.8ms] [Thumb:Check] seq=27, t=0.6s, velocity=16428, underSized=0/21
[+21447.7ms] [R2:Timing] seq=32, velocity=12019pt/s, 디바운스=50ms
[+21655.3ms] [Thumb:Check] seq=32, t=0.2s, velocity=12019, underSized=4/21
[+22055.6ms] [Thumb:Check] seq=32, t=0.6s, velocity=12019, underSized=0/21
```

---

<!-- LOG_ID: 260103_phase2_1_bug -->
## Phase 2 테스트 1 (2026-01-03 23:57) - 버그 있음

**조건:**
- 기기: iPhone 13 Pro (iPhone14,2)
- 빌드: Release
- 디바운스: 50ms
- CrossFade: 0.15s
- Preheat: 있음 (⚠️ 버그: 192px/50%로 요청됨)

**⚠️ 버그:** `thumbnailSize(forScrolling: false)`가 `isScrolling` 체크로 50% 반환

### R2 관련 로그

```
[+1523.6ms] [Preheat:Decel] seq=1, 21개 에셋, targetSize=192px
[+1574.8ms] [R2:Timing] seq=2, velocity=3808pt/s, 디바운스=50ms
[+1783.2ms] [Thumb:Check] seq=2, t=0.2s, velocity=3808, underSized=12/21
[+2200.9ms] [Thumb:Check] seq=2, t=0.6s, velocity=3808, underSized=1/21
[+3551.6ms] [R2:Timing] seq=5, velocity=5119pt/s, 디바운스=50ms
[+3752.6ms] [Thumb:Check] seq=5, t=0.2s, velocity=5119, underSized=0/21
[+4182.4ms] [Thumb:Check] seq=5, t=0.6s, velocity=5119, underSized=0/21
[+4924.4ms] [R2:Timing] seq=7, velocity=3304pt/s, 디바운스=50ms
[+5133.4ms] [Thumb:Check] seq=7, t=0.2s, velocity=3304, underSized=0/24
[+5546.6ms] [Thumb:Check] seq=7, t=0.6s, velocity=3304, underSized=0/24
[+6574.4ms] [R2:Timing] seq=10, velocity=10513pt/s, 디바운스=50ms
[+6783.5ms] [Thumb:Check] seq=10, t=0.2s, velocity=10513, underSized=18/21
[+7200.2ms] [Thumb:Check] seq=10, t=0.6s, velocity=10513, underSized=0/21
[+8183.5ms] [R2:Timing] seq=13, velocity=8222pt/s, 디바운스=50ms
[+8389.0ms] [Thumb:Check] seq=13, t=0.2s, velocity=8222, underSized=20/24
[+8800.3ms] [Thumb:Check] seq=13, t=0.6s, velocity=8222, underSized=0/24
[+9742.0ms] [R2:Timing] seq=16, velocity=6337pt/s, 디바운스=50ms
[+9948.8ms] [Thumb:Check] seq=16, t=0.2s, velocity=6337, underSized=2/24
[+10362.2ms] [Thumb:Check] seq=16, t=0.6s, velocity=6337, underSized=0/24
[+12192.1ms] [R2:Timing] seq=22, velocity=20434pt/s, 디바운스=50ms
[+12400.5ms] [Thumb:Check] seq=22, t=0.2s, velocity=20434, underSized=18/24
[+12815.7ms] [Thumb:Check] seq=22, t=0.6s, velocity=20434, underSized=0/24
[+14550.5ms] [R2:Timing] seq=27, velocity=10161pt/s, 디바운스=50ms
[+14758.6ms] [Thumb:Check] seq=27, t=0.2s, velocity=10161, underSized=19/21
[+15165.8ms] [Thumb:Check] seq=27, t=0.6s, velocity=10161, underSized=0/21
[+16676.0ms] [R2:Timing] seq=32, velocity=10246pt/s, 디바운스=50ms
[+16882.8ms] [Thumb:Check] seq=32, t=0.2s, velocity=10246, underSized=12/24
[+17299.5ms] [Thumb:Check] seq=32, t=0.6s, velocity=10246, underSized=0/24
```

---

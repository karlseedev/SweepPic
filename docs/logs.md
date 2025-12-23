# 성능 로그 기록

스크롤 성능 테스트 결과를 비교/추적하는 문서입니다.

---

## 테스트 방식

### 디버거 연결 테스트 (연결테스트)

Xcode에서 Run (⌘R) 후 디버거가 연결된 상태로 테스트합니다.

**특징:**
- Xcode 콘솔에서 실시간 로그 확인 가능
- **PhotoKit 성능 84배 저하** (뷰어 열기 시 ~4초 지연)
- 디버깅/개발 용도로만 사용

**절차:**
1. Xcode Run (⌘R)
2. 테스트 수행
3. Xcode 콘솔에서 로그 확인

---

### 디버거 미연결 테스트 (미연결테스트)

디버거 없이 실제 사용자 환경과 동일한 조건에서 테스트합니다.

**특징:**
- 실제 사용자 환경과 동일한 성능
- **성능 측정 시 필수** (연결테스트는 성능 왜곡)
- 로그는 파일로 확인

**절차:**
1. Xcode Run → Stop
2. 아이콘으로 앱 실행
3. 테스트 수행
4. 로그 파일 확인 (Documents/launch_log.txt)

---

## 기준점: P0 적용 (2025-12-23 16:25)

**조건:** P0 적용 (prefetch preheat 제거), Release 빌드, iPhone 13 Pro, iOS 18, 사진 3500장, 미연결테스트

### 요약

| 구간 | 시나리오 | 스크롤 시간 |
|------|----------|-------------|
| L1 First | 일상 스크롤 (사진 찾는 정도) | 8.3초 |
| L2 Steady | 극한 스크롤 (회색 확인용) | 14.6초 |

### Initial Load

| grayShown | grayResolved | pending |
|-----------|--------------|---------|
| 24 | 12 | 12 |

### L1 First (일상 스크롤)

| 지표 | 값 | 판정 |
|------|-----|------|
| hitch | 15.0 ms/s | Critical |
| dropped | 11 | - |
| grayShown | 90 | 양호 |
| grayResolved | 573 | - |
| pending | -483 | 정상 (offscreen 미리 로드) |
| req/s | 56.0 | - |
| cancel/s | 51.9 | - |
| latency avg | 7.4ms | - |
| latency p95 | 9.2ms | - |
| latency max | 145.5ms | - |

### L2 Steady (극한 스크롤)

| 지표 | 값 | 판정 |
|------|-----|------|
| hitch | 29.8 ms/s | Critical |
| dropped | 32 | - |
| grayShown | 7038 | 예상대로 (극한) |
| grayResolved | 7762 | - |
| pending | -724 | 정상 |
| req/s | 532.8 | - |
| cancel/s | 532.0 | - |
| latency avg | 5.5ms | - |
| latency p95 | 9.6ms | - |
| latency max | 17.1ms | - |

<details>
<summary>원본 로그</summary>

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

</details>

---

## 로그 비교 템플릿

새 테스트 결과를 추가할 때 아래 형식을 사용:

```markdown
## [테스트명] (날짜 시간)

**조건:** [적용된 변경사항], [빌드 타입], [디바이스], [iOS 버전], [사진 수], [테스트 방식]

### L1 First (일상 스크롤)

| 지표 | 값 | vs 기준점 |
|------|-----|-----------|
| hitch | X ms/s | +/-% |
| grayShown | X | +/-% |

### L2 Steady (극한 스크롤)

| 지표 | 값 | vs 기준점 |
|------|-----|-----------|
| hitch | X ms/s | +/-% |
| grayShown | X | +/-% |

<details>
<summary>원본 로그</summary>

\`\`\`
(로그 붙여넣기)
\`\`\`

</details>
```

---

## 목표

| 등급 | 임계값 | 사용자 체감 |
|------|--------|-------------|
| Good | < 5 ms/s | 거의 인지 못함 |
| Warning | 5-10 ms/s | 인지하기 시작함 |
| Critical | > 10 ms/s | 크게 불편함 |

**현재 목표:** Warning (< 10 ms/s)

# Gate 2 Required Logs (고정 기준)

목적: Gate 2(그리드 썸네일 파이프라인)에서 “전/후 비교”와 “결론 도출”에 필요한 로그 항목을 고정합니다.  
원칙: 이 문서의 항목이 없으면 Gate 2 결론을 확정하지 않습니다(나중에 “없어서 못 본다”가 없도록).

---

## 0) 공통 규칙

1) 모든 로그는 “구간 START/END”를 기준으로 집계합니다.  
2) HIT/MISS 개별 로그는 기본적으로 출력하지 않습니다(요약만).  
3) Q3(디스크 MISS가 PhotoKit 요청을 지연시키는지)만 예외로 샘플 10개까지 허용합니다.  
4) FileLogger는 메모리 버퍼링 후 구간 END에서 flush 합니다(스크롤 중 동기 파일 쓰기 금지).  
5) 모든 수치는 같은 기기/같은 빌드/같은 구간 정의로만 비교합니다.

---

## 1) 실행 환경/설정 로그 (매 실행 1회, 앱 시작 직후)

### 1.1 환경(Env)

- [Env] Build: Debug/Release
- [Env] LowPowerMode: ON/OFF
- [Env] PhotosAuth: authorized/limited/denied
- [Device] model, iOS version, maximumFramesPerSecond(60/120)

### 1.2 파이프라인 설정(Config)

- [Config] deliveryMode: opportunistic/fastFormat
- [Config] cancelPolicy: prepareForReuse / prepareForReuse+didEndDisplaying
- [Config] R2Recovery: enabled/disabled + debounce(ms) + maxCount
- [Config] preheatPolicy: off / scrollOff+idleOn / on
- [Config] preheatWindow: ±N rows (또는 6 cells 같은 정규화 값)
- [Config] preheatThrottle: N ms
- [Config] scrollQuality: scrollingThumbnailScale(예: 0.5/0.3) + degrade 기준(언제 degraded로 처리하는지)

---

## 2) 구간 정의(필수 4구간) + 타이밍 로그

모든 구간은 START/END를 반드시 남깁니다.

### 2.1 Initial Load

- [Timing] InitialLoad START
- [Timing] Fetch done: Xms (items: N)
- [Timing] First layout done(C): +Xms
- [Timing] First cell visible(D): +Xms (indexPath)
- [Timing] E0 finishInitialDisplay start: +Xms (reason, preloaded n/m)
- [Timing] E1 reloadData+layout end: +Xms (E0→E1: Xms)
- [Timing] E2 scrollToItem+layout end: +Xms (E1→E2: Xms)
- [Timing] InitialLoad END: total +Xms

### 2.2 L1 First Scroll (수동)

- [Scroll] L1 START (target duration: 5.0s 같이 목표를 함께 기록)
- [Scroll] L1 END (actual duration: Xs)

### 2.3 L2 Steady (MISS 구간 수동)

- [Scroll] L2 START (MISS 유도 시점부터 시작)
- [Scroll] L2 END (actual duration: Xs)

### 2.4 L3 Extreme (스트레스 수동)

- [Scroll] L3 START
- [Scroll] L3 END

---

## 3) 각 구간 END 시점에 반드시 덤프해야 하는 3종 요약(고정 포맷)

구간 END마다 동일 포맷으로 출력합니다.

### 3.1 Hitch 요약(Apple ms/s 기준)

- [Hitch] <구간명>: hitch: X ms/s [Good/Warning/Critical], dropped: N, longest: N frames (Y ms), rendered: N, hitchTime: Z ms

### 3.2 Pipeline 요약(요청/취소/완료/지연/인플라이트)

- [Pipeline] <구간명>: req: N (N/s), cancel: N (N/s), complete: N (N/s)
- [Pipeline] <구간명>: latency avg: Xms, p95: Xms, max: Xms
- [Pipeline] <구간명>: degraded: N, maxInFlight: N
- [Pipeline] <구간명>: preheat: 호출횟수, 총 에셋 수

### 3.3 Cache 요약(디스크 캐시 필요성 판단용)

- [DiskCache] <구간명>: hit: N, miss: N, hitRate: X%
- [MemoryCache] <구간명>: hit: N, miss: N, hitRate: X%
- [DiskCache] size: X MB / limit: Y MB (files: N)  (앱 시작 1회만 찍어도 허용)

---

## 4) Q3 필수: “DiskCache MISS → PhotoKit 요청 시작 지연” 측정(없으면 결론 불가)

목적: “디스크 캐시 미스 시, PhotoKit 요청이 디스크 체크 때문에 늦어지는가(게이트/직렬화 여부)”를 확정합니다.

### 4.1 샘플 로그(권장, 샘플 10개 한정)

- [DiskCache] MISS asset=<id> at T
- [Pipeline] requestStart asset=<id> at T
- [DiskCache→Request] delta=<X ms> asset=<id>

### 4.2 요약 로그(대안)

- [DiskCache→Request] delta avg: Xms, p95: Xms, max: Xms (samples: N)

주의: 4.2만으로도 “추정”은 가능하지만, 최종 결론은 4.1 샘플을 최소 1회 이상 확보하는 것을 원칙으로 합니다.

---

## 5) 정합성(오표시 0) 증빙 로그(최소)

- [Correctness] staleApplyDrop: N (토큰 불일치로 completion을 드롭한 수)
- [Correctness] wrongImageDetected: N (가능하면)

---

## 6) 회색(placeholder) 체감 지표(감이 아니라 수치로 고정)

각 구간 END에 아래 2개를 반드시 남깁니다.

- [Placeholder] <구간명>: shownCount: N (placeholder가 표시된 셀 수)
- [Placeholder] <구간명>: stillVisibleAtEnd: N (구간 종료 시점에도 회색인 셀 수)

---

## 7) Gate 2 “전/후 비교” 기본 체크리스트

전/후 비교 시 아래를 한 번에 표로 정리합니다(구간별):

1) hitch(ms/s), dropped, longest  
2) req/s, cancel/s, complete/s  
3) latency(p95/max), maxInFlight  
4) DiskCache hitRate, MemoryCache hitRate  
5) placeholder shownCount / stillVisibleAtEnd  
6) staleApplyDrop(오표시 방지 동작 여부)


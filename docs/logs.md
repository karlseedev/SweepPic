# 성능 로그 기록

스크롤 성능 테스트 결과를 비교/추적하는 문서입니다.

> **📁 파일 분리 안내:**
> - 원본 로그 데이터는 `LogsDetailN.md`에 분리되어 있습니다 (현재: LogsDetail1.md)
> - 각 파일이 2000줄 초과 시 다음 번호 파일에 저장 (1 → 2 → 3 → ...)
> - 각 로그는 `<!-- LOG_ID: [식별자] -->` 주석으로 검색 가능합니다
> - **새 테스트 추가 시:** 요약은 이 파일에, 원본 로그는 최신 `LogsDetailN.md`에 따로 저장하세요

---

## 종합 비교표

| 버전 | 사진 수 | 시간 | L1 hitch | L2 hitch | L1 gray | L2 gray | 비고 |
|------|---------|------|----------|----------|---------|---------|------|
| **P0 (기준점)** | 3500 | 16:25 | 15.0 | 29.8 | 90 | 7038 | 기준 |
| P0+Phase7 | 3500 | 23:12 | 18.1 (+21%) | 33.6 (+13%) | 521 | 2440 | |
| P0+Phase7 | 3500 | 23:17 | 22.8 (+52%) | 37.1 (+24%) | 537 | 5424 | |
| P0+Phase7 | 4만 | 23:08 | 16.2 | 25.6 | 139 | 18972 | |
| P0+Phase7 | 4만 | 23:15 | 12.5 | 16.2 | 429 | 5603 | |
| P0+Phase7 | 4만 | 23:23 | 19.2 | 32.3 | 544 | 10382 | |

> **목표:** L1/L2 hitch < 10 ms/s (Warning 이하)
> **현재:** 모든 테스트 Critical (>10 ms/s)

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

<!-- 원본 로그: LogsDetail1.md - LOG_ID: P0_16-25_3500 -->

---

## P0+Phase7 (2025-12-23 23:17) - 3500장 (재측정)

**조건:** P0 + Phase7 (휴지통 관리), Release 빌드, iPhone 13 Pro, iOS 18, 사진 3500장, 미연결테스트

### 요약

| 구간 | 시나리오 | 스크롤 시간 |
|------|----------|-------------|
| L1 First | 일상 스크롤 (사진 찾는 정도) | 7.0초 |
| L2 Steady | 극한 스크롤 (회색 확인용) | 11.5초 |

### Initial Load

| grayShown | grayResolved | pending |
|-----------|--------------|---------|
| 24 | 12 | 12 |

### L1 First (일상 스크롤)

| 지표 | 값 | vs 이전(23:12) |
|------|-----|----------------|
| hitch | 22.8 ms/s | +26% (18.1) ❌ |
| dropped | 14 | - |
| grayShown | 537 | +3% (521) |
| grayResolved | 918 | - |
| pending | -381 | 정상 |
| req/s | 104.7 | - |
| cancel/s | 99.9 | - |
| latency avg | 6.0ms | - |
| latency p95 | 8.3ms | - |
| latency max | 108.6ms | - |

### L2 Steady (극한 스크롤)

| 지표 | 값 | vs 이전(23:12) |
|------|-----|----------------|
| hitch | 37.1 ms/s | +10% (33.6) ❌ |
| dropped | 35 | - |
| grayShown | 5424 | +122% (2440) ❌ |
| grayResolved | 5895 | - |
| pending | -471 | 정상 |
| req/s | 513.6 | - |
| cancel/s | 512.0 | - |
| latency avg | 5.8ms | - |
| latency p95 | 9.8ms | - |
| latency max | 55.7ms | - |

<!-- 원본 로그: LogsDetail1.md - LOG_ID: P0+Phase7_23-17_3500 -->

---

## P0+Phase7 (2025-12-23 23:12) - 3500장 (첫 측정)

**조건:** P0 + Phase7 (휴지통 관리), Release 빌드, iPhone 13 Pro, iOS 18, 사진 3500장, 미연결테스트

### 요약

| 구간 | 시나리오 | 스크롤 시간 |
|------|----------|-------------|
| L1 First | 일상 스크롤 (사진 찾는 정도) | 8.3초 |
| L2 Steady | 극한 스크롤 (회색 확인용) | 7.1초 |

### Initial Load

| grayShown | grayResolved | pending |
|-----------|--------------|---------|
| 24 | 12 | 12 |

### L1 First (일상 스크롤)

| 지표 | 값 | vs 기준점 |
|------|-----|-----------|
| hitch | 18.1 ms/s | +21% (15.0) ❌ |
| dropped | 15 | +36% (11) |
| grayShown | 521 | +479% (90) ❌ |
| grayResolved | 881 | - |
| pending | -360 | 정상 |
| req/s | 80.4 | - |
| cancel/s | 76.6 | - |
| latency avg | 6.0ms | - |
| latency p95 | 9.5ms | - |
| latency max | 110.7ms | - |

### L2 Steady (극한 스크롤)

| 지표 | 값 | vs 기준점 |
|------|-----|-----------|
| hitch | 33.6 ms/s | +13% (29.8) ❌ |
| dropped | 15 | -53% (32) |
| grayShown | 2440 | -65% (7038) ✅ |
| grayResolved | 2686 | - |
| pending | -246 | 정상 |
| req/s | 377.6 | - |
| cancel/s | 376.2 | - |
| latency avg | 8.4ms | - |
| latency p95 | 18.6ms | - |
| latency max | 27.5ms | - |

<!-- 원본 로그: LogsDetail1.md - LOG_ID: P0+Phase7_23-12_3500 -->

---

## P0+Phase7 (2025-12-23 23:23) - 4만장

**조건:** P0 + Phase7 (휴지통 관리), Release 빌드, iPhone 13 Pro, iOS 18, 사진 4만장, 미연결테스트

### 요약

| 구간 | 시나리오 | 스크롤 시간 |
|------|----------|-------------|
| L1 First | 일상 스크롤 (사진 찾는 정도) | 8.9초 |
| L2 Steady | 극한 스크롤 (회색 확인용) | 20.1초 |

### L1 First (일상 스크롤)

| 지표 | 값 |
|------|-----|
| hitch | 19.2 ms/s |
| dropped | 15 |
| grayShown | 544 |
| req/s | 91.7 |
| latency avg | 6.5ms |
| latency p95 | 15.1ms |

### L2 Steady (극한 스크롤)

| 지표 | 값 |
|------|-----|
| hitch | 32.3 ms/s |
| dropped | 58 |
| grayShown | 10382 |
| req/s | 554.6 |
| latency avg | 13.6ms |
| latency p95 | 28.3ms |

<!-- 원본 로그: LogsDetail1.md - LOG_ID: P0+Phase7_23-23_40000 -->

---

## P0+Phase7 (2025-12-23 23:15) - 4만장

**조건:** P0 + Phase7 (휴지통 관리), Release 빌드, iPhone 13 Pro, iOS 18, 사진 4만장, 미연결테스트

### 요약

| 구간 | 시나리오 | 스크롤 시간 |
|------|----------|-------------|
| L1 First | 일상 스크롤 (사진 찾는 정도) | 7.7초 |
| L2 Steady | 극한 스크롤 (회색 확인용) | 11.2초 |

### Initial Load

| grayShown | grayResolved | pending |
|-----------|--------------|---------|
| 24 | 12 | 12 |

### L1 First (일상 스크롤)

| 지표 | 값 | vs 이전(23:08) |
|------|-----|----------------|
| hitch | 12.5 ms/s | -23% (16.2) ✅ |
| dropped | 7 | - |
| grayShown | 429 | +209% (139) |
| grayResolved | 827 | - |
| pending | -398 | 정상 |
| req/s | 75.1 | - |
| cancel/s | 71.2 | - |
| latency avg | 6.4ms | - |
| latency p95 | 12.4ms | - |
| latency max | 165.5ms | - |

### L2 Steady (극한 스크롤)

| 지표 | 값 | vs 이전(23:08) |
|------|-----|----------------|
| hitch | 16.2 ms/s | -37% (25.6) ✅ |
| dropped | 6 | - |
| grayShown | 5603 | -70% (18972) |
| grayResolved | 6048 | - |
| pending | -445 | 정상 |
| req/s | 542.4 | - |
| cancel/s | 541.5 | - |
| latency avg | 16.8ms | - |
| latency p95 | 35.4ms | - |
| latency max | 66.4ms | - |

<!-- 원본 로그: LogsDetail1.md - LOG_ID: P0+Phase7_23-15_40000 -->

---

## P0+Phase7 (2025-12-23 23:08) - 4만장 (첫 측정)

**조건:** P0 + Phase7 (휴지통 관리), Release 빌드, iPhone 13 Pro, iOS 18, 사진 4만장, 미연결테스트

> ⚠️ 동일 조건 재측정(23:15)과 큰 차이 - 테스트 변동성 존재

### 요약

| 구간 | 시나리오 | 스크롤 시간 |
|------|----------|-------------|
| L1 First | 일상 스크롤 (사진 찾는 정도) | 8.8초 |
| L2 Steady | 극한 스크롤 (회색 확인용) | 20.4초 |

### Initial Load

| grayShown | grayResolved | pending |
|-----------|--------------|---------|
| 24 | 12 | 12 |

### L1 First (일상 스크롤)

| 지표 | 값 | vs 기준점 |
|------|-----|-----------|
| hitch | 16.2 ms/s | +8% (15.0) |
| dropped | 12 | - |
| grayShown | 139 | (비교불가) |
| grayResolved | 554 | - |
| pending | -415 | 정상 |
| req/s | 43.5 | - |
| cancel/s | 40.2 | - |
| latency avg | 7.8ms | - |
| latency p95 | 17.7ms | - |
| latency max | 171.9ms | - |

### L2 Steady (극한 스크롤)

| 지표 | 값 | vs 기준점 |
|------|-----|-----------|
| hitch | 25.6 ms/s | -14% (29.8) |
| dropped | 31 | - |
| grayShown | 18972 | (비교불가) |
| grayResolved | 20014 | - |
| pending | -1042 | 정상 |
| req/s | 982.4 | - |
| cancel/s | 981.4 | - |
| latency avg | 18.0ms | - |
| latency p95 | 32.9ms | - |
| latency max | 149.7ms | - |

<!-- 원본 로그: LogsDetail1.md - LOG_ID: P0+Phase7_23-08_40000 -->

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

<!-- 원본 로그: LogsDetail1.md - LOG_ID: [식별자] -->
```

> **원본 로그 추가 시:** LogsDetail1.md에 `<!-- LOG_ID: [식별자] -->` 주석과 함께 로그를 추가하세요.

---

## 목표

| 등급 | 임계값 | 사용자 체감 |
|------|--------|-------------|
| Good | < 5 ms/s | 거의 인지 못함 |
| Warning | 5-10 ms/s | 인지하기 시작함 |
| Critical | > 10 ms/s | 크게 불편함 |

**현재 목표:** Warning (< 10 ms/s)

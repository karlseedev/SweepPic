# 자동 테스트 성능 로그 기록

자동화된 스크롤 성능 테스트 결과를 비교/추적하는 문서입니다.

> **📁 파일 분리 안내:**
> - 원본 로그 데이터는 `LogsAutoRawN.md`에 분리되어 있습니다 (현재: LogsAutoRaw1.md)
> - 각 파일이 2000줄 초과 시 다음 번호 파일에 저장 (1 → 2 → 3 → ...)
> - 각 로그는 `<!-- LOG_ID: [식별자] -->` 주석으로 검색 가능합니다
> - **새 테스트 추가 시:** 요약은 이 파일에, 원본 로그는 최신 `LogsAutoRawN.md`에 따로 저장하세요

---

## 종합 비교표

| 테스트 방식 | 빌드 | velocity | hitch | fps | req/s | 비고 |
|-------------|------|----------|-------|-----|-------|------|
| 수동 극한 (기준) | Release | - | 15~37 | - | 500~580 | 참고용 |
| XCUITest swipe | Release | 8000 | 0~17.1 | 117~119 | 19~26 | 변동 큼 |
| AutoScrollTester | Debug | 12000 pt/s | 3.5 | 119.5 | 272.9 | 단일 구간 |

> **목표:** 수동 스크롤과 유사한 hitch 패턴 재현
> **현재:** XCUITest swipe가 hitch 패턴은 유사하나 req/s 부족

---

## 테스트 방식

### XCUITest swipe (testL1L2Sequence)

XCUITest의 `swipeDown(velocity:)`로 스크롤 자동화.

**특징:**
- UIKit 터치/관성 시스템 사용 → 수동 스크롤과 유사한 부하 패턴
- hitch 6.9~15.9 ms/s로 수동(12~28)과 유사한 범위
- **req/s가 21~30으로 매우 낮음** (수동 극한 500~580 대비)

**설정:**
- L1~L4: velocity 8000 (동일)
- 총 11초 스크롤 (3초 + pause 1초 + 8초)

---

### AutoScrollTester (testAutoScrollTester)

CADisplayLink 기반 contentOffset 직접 조작.

**특징:**
- req/s 272.9로 높음
- **hitch 3.5 ms/s로 매우 낮음** → 수동 스크롤과 다른 부하 패턴
- UIKit 스크롤 시스템 우회

**설정:**
- speed: 12000 pt/s
- duration: 12초
- direction: down
- boundary: reverse
- profile: continuous

---

## XCUITest swipe (2025-12-25 22:26) - 4회 측정

**조건:** Release 빌드, iPhone 13 Pro, iOS 18, 사진 3465장, XCUITest

### 결과

| 구간 | velocity | hitch | fps | req/s |
|------|----------|-------|-----|-------|
| L1 | 8000 | 0.0 ms/s [Good] | 119.7 | 23.4 |
| L2 | 8000 | 17.1 ms/s [Critical] | 117.7 | 19.2 |
| L3 | 8000 | 7.1 ms/s [Warning] | 117.5 | 25.7 |
| L4 | 8000 | 0.0 ms/s [Good] | 119.7 | 26.2 |

> **관찰:** 동일한 velocity 8000인데 hitch가 0→17.1→7.1→0으로 변동. req/s는 19~26.

<!-- 원본 로그: LogsAutoRaw1.md - LOG_ID: XCUITest_22-26_v8000 -->

---

## XCUITest swipe (2025-12-25 23:32) - 8회 측정

**조건:** Release 빌드, iPhone 13 Pro, iOS 18, 사진 3465장, XCUITest

### 결과

| 구간 | velocity | hitch | fps | req/s |
|------|----------|-------|-----|-------|
| L1 | 8000 | 0.0 ms/s [Good] | 119.7 | 22.4 |
| L2 | 8000 | 14.9 ms/s [Critical] | 118.0 | 20.2 |
| L3 | 8000 | 4.8 ms/s [Good] | 117.4 | 26.0 |
| L4 | 8000 | 4.8 ms/s [Good] | 117.7 | 26.5 |
| L5 | 8000 | 17.4 ms/s [Critical] | 117.6 | 26.1 |
| L6 | 8000 | 14.6 ms/s [Critical] | 118.0 | 26.1 |
| L7 | 8000 | 14.1 ms/s [Critical] | 118.1 | 26.8 |
| L8 | 8000 | 0.0 ms/s [Good] | 119.7 | 25.3 |

> **관찰:** hitch 패턴 0→14.9→4.8→4.8→17.4→14.6→14.1→0. Good 3회, Critical 4회. 동일 조건에서 큰 변동.

<!-- 원본 로그: LogsAutoRaw1.md - LOG_ID: XCUITest_23-32_v8000_8x -->

---

## AutoScrollTester (2025-12-24 00:43)

**조건:** Debug 빌드, iPhone 13 Pro, iOS 18, 사진 3465장, XCUITest + launchArguments

### 설정

| 항목 | 값 |
|------|-----|
| speed | 12000 pt/s |
| duration | 12초 |
| direction | down |
| boundary | reverse |
| profile | continuous |

### 결과 (12초 연속 스크롤)

| 지표 | 값 | 판정 |
|------|-----|------|
| hitch | 3.5 ms/s | Good |
| fps | 119.5 | 120Hz 정상 |
| frames | 1455 | - |
| dropped | 5 | - |
| grayShown | 3321 | 많음 |
| req/s | 272.9 | 안정적 |
| latency avg | 4.0ms | 양호 |
| latency p95 | 5.7ms | - |
| latency max | 37.9ms | - |

> **관찰:** req/s 272.9로 높지만 hitch 3.5 ms/s로 낮음. 수동 스크롤(hitch 12~28)과 다른 부하 패턴.

<!-- 원본 로그: LogsAutoRaw1.md - LOG_ID: AutoScrollTester_00-43_continuous -->

---

## 테스트 방식 비교

| 특성 | XCUITest swipe | AutoScrollTester | 수동 스크롤 |
|------|----------------|------------------|-------------|
| 스크롤 방식 | UIKit 터치/관성 | contentOffset 직접 | UIKit 터치/관성 |
| hitch 패턴 | 수동과 유사 | 낮음 | 기준 |
| req/s | 21~30 (부족) | 272.9 | 500~580 |
| 제어 가능성 | 중간 | 높음 | 없음 |

### 현재 상태

- **XCUITest swipe**: hitch 패턴은 수동과 유사하나 req/s 부족
- **AutoScrollTester**: req/s는 높으나 hitch 패턴이 수동과 다름
- **최종 방식 미결정** - 추가 검토 필요

---

## 로그 비교 템플릿

새 테스트 결과를 추가할 때 아래 형식을 사용:

```markdown
## [테스트 방식] (날짜 시간)

**조건:** [빌드 타입], [디바이스], [iOS 버전], [사진 수], [테스트 방식]

### 설정 (AutoScrollTester인 경우)

| 항목 | 값 |
|------|-----|
| speed | X pt/s |
| duration | X초 |

### 결과

| 지표 | 값 | 판정 |
|------|-----|------|
| hitch | X ms/s | Good/Warning/Critical |
| fps | X | - |
| req/s | X | - |

<!-- 원본 로그: LogsAutoRawN.md - LOG_ID: [식별자] -->
```

---

## 목표

| 등급 | 임계값 | 사용자 체감 |
|------|--------|-------------|
| Good | < 5 ms/s | 거의 인지 못함 |
| Warning | 5-10 ms/s | 인지하기 시작함 |
| Critical | > 10 ms/s | 크게 불편함 |

**현재 목표:** 수동 스크롤(hitch 12~28 ms/s)과 유사한 자동화 테스트 환경 구축

---

*작성일: 2025-12-24*
*테스트 환경: iPhone 13 Pro, Debug/Release 빌드*

# 자동 테스트 성능 로그 기록

자동화된 스크롤 성능 테스트 결과를 비교/추적하는 문서입니다.

> **📁 파일 분리 안내:**
> - 원본 로그 데이터는 `LogsAutoRawN.md`에 분리되어 있습니다 (현재: LogsAutoRaw1.md)
> - 각 파일이 2000줄 초과 시 다음 번호 파일에 저장 (1 → 2 → 3 → ...)
> - 각 로그는 `<!-- LOG_ID: [식별자] -->` 주석으로 검색 가능합니다
> - **새 테스트 추가 시:** 요약은 이 파일에, 원본 로그는 최신 `LogsAutoRawN.md`에 따로 저장하세요

---

## 종합 비교표

| 테스트 방식 | 빌드 | hitch (L1) | hitch (L2) | fps | req/s | gray | 비고 |
|-------------|------|------------|------------|-----|-------|------|------|
| 수동 극한 (기준) | Release | 15.0~22.8 | 29.8~37.1 | - | 500~580 | 5000~7000 | 참고용 |
| XCUITest swipe | Release | 0.0 | 6.9~15.9 | 117~119 | 21~30 | 10~11 | 부하 부족 |
| AutoScrollTester | Debug | 3.5 | - | 119.5 | 272.9 | 3321 | 단일 구간 |

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
- L1: 3초, velocity 8000
- pause: 1초
- L2: 8초, velocity 30000

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

## XCUITest swipe (2025-12-24 00:22)

**조건:** Release 빌드, iPhone 13 Pro, iOS 18, 사진 3465장, XCUITest

### 요약

| 구간 | 시나리오 | 스크롤 시간 |
|------|----------|-------------|
| L1 First | 일상 스크롤 (3초) | 3.4초 |
| L2 Steady (1) | 극한 스크롤 | 5.1초 |
| L2 Steady (2) | 극한 스크롤 | 3.9초 |
| L2 Steady (3) | 극한 스크롤 | 3.9초 |

### L1 First

| 지표 | 값 | 판정 |
|------|-----|------|
| hitch | 0.0 ms/s | Good |
| fps | 119.7 | 120Hz 정상 |
| dropped | 0 | - |
| grayShown | 11 | 매우 적음 |
| req/s | 21.2 | **부하 부족** |
| latency avg | 16.6ms | - |

### L2 Steady (3회 측정)

| 측정 | hitch | fps | req/s | dropped |
|------|-------|-----|-------|---------|
| 1회 | 6.9 ms/s [Warning] | 117.3 | 23.1 | 3 |
| 2회 | 15.9 ms/s [Critical] | 117.9 | 30.1 | 7 |
| 3회 | 0.0 ms/s [Good] | 119.7 | 30.4 | 0 |

> **관찰:** hitch가 0.0~15.9로 변동이 큼. req/s가 21~30으로 부하 부족.

<!-- 원본 로그: LogsAutoRaw1.md - LOG_ID: XCUITest_00-22_swipe -->

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

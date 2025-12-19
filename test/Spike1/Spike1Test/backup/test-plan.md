# Gate 2 성능 테스트 계획

## 1. 배경

### 1.1 현재 상태 (2024-12-18 측정)

| 항목 | Spike1Test | Photos (네이티브) | 차이 |
|------|------------|------------------|------|
| Hitch/초 | 2.28 | 1.76 | +30% |
| 최대 Duration | 83ms | 58ms | +43% |
| High severity | 8개+ | 2개 | +300% |

측정 환경: iPhone 13 Pro, iOS 18.6.2, Release 빌드

### 1.2 문제점

1. **Pre-Commit latency** - 메인 스레드에서 프레임 준비 지연
2. **Commit to Render latency** - 렌더링 비용 과다
3. **High severity hitch가 네이티브 대비 4배 많음**

### 1.3 HitchMonitor 한계

| 항목 | HitchMonitor | Instruments |
|------|--------------|-------------|
| 측정 방식 | CADisplayLink 콜백 | 시스템 렌더링 파이프라인 |
| 정확도 | 낮음 | 높음 |
| 네이티브 비교 | 불가 | 가능 |

**결론**: 절대값 측정은 Instruments, A/B 상대 비교만 HitchMonitor 사용

### 1.4 측정 도구 역할 분리 (핵심 원칙)

| 도구 | 역할 | 용도 |
|------|------|------|
| **XCUITest** | 회귀/비교 | A/B 테스트, 변동폭 측정, 자동화된 반복 |
| **Instruments** | 원인 분류 | Pre-Commit vs Commit-to-Render 판별, 최적화 방향 결정 |
| **HitchMonitor** | 빠른 확인 | 개발 중 즉각 피드백 (절대값 무시) |

> **XCUITest는 "얼마나 끊겼나"는 알려주지만, "왜 끊겼나"는 Instruments 타임라인 분석이 필요하다.**

---

## 2. 목표

### 2.1 1차 목표 (네이티브 대비 격차 줄이기)

| 메트릭 | 현재 | 목표 |
|--------|------|------|
| Hitch/초 | +30% | +10% 이내 |
| High severity | 8개+ | 2~3개 |
| 최대 Duration | 83ms | 60ms 근처 |

### 2.2 최종 목표

- Photos 앱과 **동등한 수준**의 스크롤 성능

### 2.3 제품 합격 기준 (Apple 등급 vs 체감)

> **주의**: HitchMonitor에서 Critical(>10ms/s)이 떠도 체감상 괜찮을 수 있음이 확인됨.
> Apple 등급을 그대로 PASS/FAIL 기준으로 쓰지 않고, 아래 **제품 기준**을 병행한다.

| 테스트 유형 | 합격 기준 |
|-------------|-----------|
| **L2 (실사용 패턴)** | Hitch Time Ratio ≤ **Warning(10ms/s)** AND longest hitch ≤ **5프레임** |
| **Instruments** | High severity ≤ **Photos 대비 +50%** (예: Photos 2개 → 3개까지 허용) |

> Apple 등급 Good(<5ms/s)은 이상적 목표이지, 필수 합격선이 아니다.

---

## 3. 측정 방법

### 3.1 기본 측정: Instruments (수동)

**방법**: Instruments > Animation Hitches 템플릿

**기록 항목**:
- Hitch/초 (hitch count / 측정 시간)
- 최대 Duration (ms)
- High severity 개수
- High severity 유형 분포 (Pre-Commit vs Commit-to-Render)

**제약**: 수동 스크롤 → 변동폭 큼

### 3.2 자동화 측정: XCUITest (권장)

> **XCUITest 측정 정의**: `scrollDecelerationMetric`은 **Hitch Time Ratio(ms/s)**와 **Hitch Count**를 "스크롤 감속 구간(플릭 시작 → 감속 완료)" 기준으로 측정한다. 테스트는 이 구간이 포함되도록 구성해야 한다.

**Apple 공식 방법** (WWDC20 "Eliminate animation hitches with XCTest"):

```swift
import XCTest

final class ScrollPerformanceTests: XCTestCase {
    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
    }

    func testGate2ScrollPerformance() {
        app.launch()

        // Navigate to Gate 2
        app.buttons["PhotoKit Provider"].tap()

        let collection = app.collectionViews.firstMatch
        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions = [.manuallyStop]

        // 자동 측정 (5회 반복 + baseline)
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric],
                options: measureOptions) {
            collection.swipeUp(velocity: .fast)
            stopMeasuring()
            collection.swipeDown(velocity: .fast)  // reset position
        }
    }

    func testGate2ExtremeFlingPerformance() {
        app.launch()
        app.buttons["PhotoKit Provider"].tap()

        let collection = app.collectionViews.firstMatch

        // Extreme fling pattern (L2 시뮬레이션)
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            for _ in 0..<5 {
                collection.swipeUp(velocity: .fast)
            }
        }
    }
}
```

**장점**:
- **velocity 파라미터**로 스크롤 속도 일관성 확보 (.slow, .default, .fast)
- Instruments와 동일한 시스템 레벨 측정
- 자동 반복 → 변동폭 자동 계산
- Baseline 설정 및 회귀 감지 가능

**제약**:
- 실기기 필수 (시뮬레이터는 Duration만 지원)
- Release 빌드 필요
- 테스트 스킴 설정 필요 (diagnostic 비활성화)

**측정 메트릭** (실기기):
1. Frame Count
2. Frame Rate
3. Hitch Count
4. Hitch Time (ms)
5. **Hitch Time Ratio** (ms/s) ← 핵심 메트릭

### 3.3 빠른 A/B 비교: HitchMonitor (앱 내부)

**용도**: 레버 변경 효과 빠르게 확인 (절대값 무시, 상대 비교만)

**기존 L1/L2 테스트 활용**:
- L1: 6,000 pt/s flick + deceleration (10초)
- L2: 10,000 pt/s extreme flick (10초)

---

## 4. 조정 가능한 레버

### 4.1 현재 코드에서 조정 가능한 레버

| 레버 | 위치 | 현재 값 | 조정 방법 |
|------|------|---------|-----------|
| **Preheat Mode** | Gate2ViewController | ON (100ms throttle) | P 버튼으로 ON/150ms/OFF 전환 |
| **Delivery Mode** | PhotoKitImageProvider | opportunistic | 좌측 버튼으로 Fast/Opp 전환 |
| **Experiment Mode** | Gate2ViewController | normal | GateMenu에서 Minimal 버전 선택 |
| **Scroll Quality** | Gate2ViewController | 스크롤 중 50% 축소 | `lowQualityThumbnailSize` 변경 |

### 4.2 추가 구현 필요한 레버

| 레버 | 설명 | 구현 난이도 |
|------|------|-------------|
| **Preheat Throttle 200ms** | 더 공격적인 throttle | 낮음 (enum case 추가) |
| **최소 렌더링 프로파일** | 셀에서 불필요 요소 제거 | 중간 |
| **Cancel Policy** | didEndDisplaying에서만 cancel | 낮음 |
| **Request Dedupe** | 동일 assetID+size 중복 요청 방지 | 이미 구현됨 |

### 4.3 셀 렌더링 비용 요소 (현재 ImageCell)

```swift
// 현재 ImageCell 구조 (매우 단순)
final class ImageCell: UICollectionViewCell {
    let imageView = UIImageView()  // aspectFill + clipsToBounds
}
```

현재 셀은 이미 최소화되어 있음. 추가로 확인할 것:
- cornerRadius 없음 ✓
- shadow 없음 ✓
- blur 없음 ✓
- alpha 변경 없음 ✓
- 오버레이 없음 ✓

**→ 셀 렌더링 비용은 낮음. Commit-to-Render 문제는 이미지 디코딩 쪽일 가능성 높음**

---

## 5. 실험 순서

### 핵심 규칙

> **각 Step에서 레버는 1개만 바꾸고, 나머지는 고정한다.**
>
> 조건표에 "고정 레버"와 "변경 레버"를 명시하여 테스트가 산으로 가지 않도록 한다.

피드백 기반 우선순위:

### Step 0: 변동폭 측정 (Baseline)

**목적**: A/B 테스트 유의미성 판단 기준 확보

**방법**:
1. XCUITest로 동일 조건 5회 측정
2. 또는 Instruments + 동일 패턴 수동 테스트 3회

**기록**: 평균, 표준편차, min/max

### Step 1: 최소 렌더링 프로파일

**목적**: Commit-to-Render가 렌더링/레이어 비용인지 확인

**방법**:
- 현재 ImageCell이 이미 최소화되어 있으므로, 이 단계는 **스킵 가능**
- 만약 셀에 추가 요소가 있다면: 제거 후 측정

**예상**: 셀이 단순하므로 큰 차이 없을 것 → 이미지 디코딩이 주 원인일 가능성

### Step 2: Preheat 레버 (A/B/C)

**목적**: Pre-Commit latency가 cacheUpdate 비용인지 확인

**조건**:
- A: Preheat ON (100ms throttle)
- B: Preheat 150ms throttle
- C: Preheat OFF

**방법**: 각 조건에서 XCUITest 또는 L2 테스트 실행

#### 승리 조건 (A/B 판정 기준)

**1순위 (필수)**: Hitch Time Ratio 기준
| 조건 | 기준 |
|------|------|
| **Hitch Time Ratio 감소** | Baseline 대비 **10% 이상** 감소 AND 감소폭이 **변동폭(σ)의 2배 이상** |

**2순위 (보조)**: 1순위 만족 시 추가 확인
| 조건 | 기준 |
|------|------|
| High severity 감소 | Baseline 대비 **30% 이상** 감소 OR **3개 이상** 감소 |

> 최종 판정은 **Hitch Time Ratio 중심**으로 하고, High severity는 보조 지표로 사용한다.

#### 결론 트리 (판정 로직)

```
Baseline 3회 측정 → 평균/표준편차 확보
    ↓
조건 A/B/C 각 3회 측정
    ↓
┌─ C(OFF)에서 승리 조건 만족?
│   ├─ YES → preheat/updateCachedAssets가 병목 (Pre-Commit 의심)
│   │         → 해결 방향: throttle 조정, 윈도우 축소
│   │
│   └─ NO → preheat는 병목 아님
│            → 다음 단계: deliveryMode/targetSize/콜백 (Step 3)
│
└─ B(150ms)에서만 승리 조건 만족?
    └─ YES → throttle 간격이 중요
             → 해결 방향: 최적 throttle 값 탐색 (200ms, 250ms...)
```

### Step 3: 이미지 옵션 레버

**목적**: deliveryMode와 이미지 준비/디코드가 성능에 미치는 영향 확인

**조건 A - deliveryMode**:
- A1: opportunistic (multi callback, degraded → final)
- A2: fastFormat (single callback, lower quality)

**조건 B - targetSize**:
- B1: 현재 (화면 scale 기준)
- B2: 스크롤 중 더 작은 thumbnailSize (현재 50% → 25%?)

**조건 C - 이미지 준비/디코드** (Commit-to-Render 주 원인 시):
- C1: 현재 (메인 스레드에서 이미지 표시)
- C2: **표시 전 백그라운드 디코드/preparing** (UIImage → CGImage 미리 디코드)

> **Step 2에서 Preheat가 병목 아님으로 판명되면**, Step 3의 C(디코드/준비)가 핵심 레버가 된다.
> Instruments에서 Commit-to-Render가 주로 나올 경우 "표시 시점 디코드/업로드"가 관건일 가능성 높음.

### Step 4: 요청 폭주 방지 레버

**목적**: worst-case 붕괴 방지 (BURST 패턴 대응)

**조건**:
- 현재: cancel on reuse + cancel on didEndDisplaying
- 실험: didEndDisplaying에서만 cancel

---

## 6. 테스트 절차 표준화

### 6.1 환경 고정

| 항목 | 값 |
|------|------|
| 기기 | iPhone 13 Pro |
| iOS | 18.6.2 |
| 빌드 | Release |
| 사진 수 | 실제 라이브러리 (약 N장) |
| 시작 위치 | 중간 (count/2) |

### 6.2 스크롤 패턴

**XCUITest (권장)**:
```swift
collection.swipeUp(velocity: .fast)  // 표준화된 속도
```

**수동 (Instruments) - 표준화된 패턴**:

> 사람마다 스크롤 속도가 달라 변동폭이 커지므로, 아래 체크리스트를 **정확히** 따른다.

| 구간 | 시간 | 동작 | 체크 |
|------|------|------|------|
| 1 | 0~5초 | 아래로 빠른 플릭 3회 | ☐ |
| 2 | 5~10초 | 위로 빠른 플릭 3회 | ☐ |
| 3 | 10~15초 | 아래 플릭 2회 + 정지 1초 | ☐ |
| 4 | 15~20초 | 위 플릭 2회 + 정지 1초 | ☐ |

**주의사항**:
- "빠른 플릭" = 손가락을 빠르게 튕기듯 스와이프 (속도 일정하게 유지)
- 감속 완료 전에 다음 플릭 시작 금지 (자연스러운 감속 허용)
- 타이머 또는 시계 보면서 구간 준수
- 측정 시작/종료는 Instruments에서 Record/Stop

### 6.3 기록 템플릿

```markdown
## 측정 기록

**날짜**: YYYY-MM-DD
**조건**: [레버 설정 명시]
**빌드**: Release / Debug
**측정 도구**: Instruments / XCUITest / HitchMonitor

### 결과

| 회차 | Hitch/초 | 최대 Duration | High severity | 유형 분포 |
|------|----------|---------------|---------------|-----------|
| 1 | | | | |
| 2 | | | | |
| 3 | | | | |
| **평균** | | | | |
| **표준편차** | | | | |

### 분석
- 효과 있음/없음 판단
- 다음 실험 결정
```

---

## 7. 다음 액션

### 즉시 실행 (우선순위 순)

1. **XCUITest 테스트 타겟 생성**
   - Spike1TestUITests 타겟 추가
   - ScrollPerformanceTests.swift 작성
   - Release 스킴 설정

2. **변동폭 측정 (Baseline)**
   - XCUITest로 현재 상태 5회 측정
   - 평균/표준편차 기록

3. **Step 2 실행 (Preheat A/B/C)**
   - 변동폭 대비 유의미한 차이인지 판단

### 참고 자료

- [WWDC20: Eliminate animation hitches with XCTest](https://developer.apple.com/videos/play/wwdc2020/10077/)
- [Tech Talks: Find and fix hitches in the commit phase](https://developer.apple.com/videos/play/tech-talks/10856/)
- [Tech Talks: Demystify and eliminate hitches in the render phase](https://developer.apple.com/videos/play/tech-talks/10857/)
- test/251218.md (오늘 테스트 결과)

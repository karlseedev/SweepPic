# SweepPic 매출 성장 시뮬레이션

> 작성일: 2026-03-13 (v3 수정: 2026-03-13)
> 목적: 사업계획서 매출 추정 근거
> 방식: 33개월 월별 복리 재투자 시뮬레이션

---

## 1. 전제 조건

### 1-1. 사업 구조

| 항목 | 값 |
|------|---|
| 사업 기간 | 1년차 9개월 + 2년차 12개월 + 3년차 12개월 = 33개월 |
| 정부 광고비 | 2,250만원 (1년차 9개월간, 월 250만) |
| 매출 재투자 | 실수령액의 70% → 다음 달 광고비로 재투자 |
| 매출 표기 | 총매출 (Gross Revenue, Apple 수수료 차감 전) |
| Apple 수수료 | 15% (Small Business Program, 연 $1M 미만) — 재투자 계산에만 적용 |

### 1-2. CPI (설치당 비용)

| 시기 | CPI | 채널 비율 | 산출 |
|------|-----|----------|------|
| 1년차 | **₩3,100** | ASA국내 30% + ASA글로벌 50% + 릴스 20% | 0.3×₩1,500 + 0.5×₩3,500 + 0.2×₩4,500 |
| 2년차~ | **₩2,900** | ASA국내 30% + ASA글로벌 70% (릴스 제외) | 0.3×₩1,500 + 0.7×₩3,500 |

**채널별 CPI 근거:**

| 채널 | CPI | 출처 |
|------|-----|------|
| ASA 국내 (한국) | ₩1,500 | AppTweak 2025: 유틸리티 ASA 글로벌 중앙값 $1.80, 한국은 경쟁 낮아 하단 |
| ASA 글로벌 (미국·일본·유럽) | ₩3,500 | AppTweak 2025: 유틸리티 카테고리 $2.90, SplitMetrics 2025: ASA 평균 $2.37 |
| 인스타 릴스 (한국/글로벌) | ₩4,500 | Wask 2025: 릴스 CPI iOS $3.50~$5.00, 한국 CPM $6~$12 |

> 출처: [AppTweak Apple Ads Benchmarks 2025](https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks), [SplitMetrics ASA Benchmarks 2025](https://splitmetrics.com/apple-ads-search-results-benchmarks-2025/), [Wask Instagram Costs](https://www.wask.co/instagram-advertising-costs)

### 1-3. 구독 전환율

| 항목 | 값 | 근거 |
|------|---|------|
| iOS 전환율 | **5%** | 체험 시작률 20% × Trial→Paid 26% (아래 상세) |
| Android 전환율 | **3%** | iOS 대비 ARPU 49%, 전환율도 비례 하향 (Adapty 2026) |
| 구독 가격 (월) | ₩4,400 ($2.99) | |
| 구독 가격 (연) | ₩29,000 ($19.99) | |
| 월구독:연구독 비율 | **50:50** | RevenueCat 2025 주간 제외 재조정 (아래 상세) |
| 가중 ARPU | **₩3,408/월** | 0.5×₩4,400 + 0.5×(₩29,000÷12) |
| 구독 모델 | Apple Free Trial 7일 (Opt-out) | |

**전환율 산출 근거:**

| 단계 | 수치 | 출처 |
|------|------|------|
| Photo & Video Trial→Paid (중앙값) | 22~26% | RevenueCat 2025/2026: 115,000개 앱 실측 |
| 5~9일 Trial→Paid (전체 카테고리 평균) | 45% | RevenueCat 2025 (참고, 본 계산에는 Photo & Video 수치 사용) |
| 체험 시작률 — Hard Paywall | 10~15% | RevenueCat 2026, Adapty 2026 |
| 체험 시작률 — Soft Paywall | 25~35% | 동일 |
| SweepPic 체험 시작률 (Soft + 삭제한도 제한) | ~20% | Hard(10~15%)와 Soft(25~35%) 중간. 무료로 사용 가능하나 한도 제한으로 체험 유도 |
| **전체 전환율 = 20% × 26%** | **~5.2% → 5%** | |

> 출처: [RevenueCat State of Subscription Apps 2025](https://www.revenuecat.com/state-of-subscription-apps-2025/), [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps/), [Adapty Trial Conversion Rates](https://adapty.io/blog/trial-conversion-rates-for-in-app-subscriptions/)

**월:연 구독 비율 근거:**

| 데이터 | 수치 | 출처 |
|--------|------|------|
| 전체 시장 구독 수 비율 | 월간 36.7% : 연간 41.4% : 주간 21.9% | RevenueCat 2025 |
| 주간 구독 미제공 시 재조정 | 월간 47% : 연간 53% | 주간 제외 후 비례 배분 |
| SweepPic 연간 할인율 | 44% ($2.99×12=$35.88 vs $19.99) | 업계 평균 75% 대비 낮음 |
| **적용 비율** | **50:50** | 낮은 할인율로 연간 유도력 약화 보정 |

> 출처: [RevenueCat 2025](https://www.revenuecat.com/state-of-subscription-apps-2025/), [Adapty Subscription Pricing](https://adapty.io/blog/how-to-price-mobile-in-app-subscriptions/)

### 1-4. 구독 갱신율

| 항목 | 값 | 출처 |
|------|---|------|
| Photo & Video 12개월 구독 갱신율 (중앙값) | 58.1% | RevenueCat 2026 (전 카테고리 최저) |
| 월구독 월간 유지율 (환산) | 95.6% (= 0.581^(1/12)) | 수학적 환산 |

> 주의: RevenueCat 원본에서 Photo & Video 카테고리의 "월간 구독 갱신률 중앙값"으로 보고됨.
> Utilities 카테고리도 유사한 수준(58.1%)으로, 사진 정리 앱(Photo & Video + Utilities 혼합 성격)에 적용 가능.
>
> 출처: [RevenueCat State of Subscription Apps 2026](https://www.revenuecat.com/state-of-subscription-apps/)

### 1-5. 광고 수익

| 광고 유형 | eCPM (한국/Tier1 iOS) | 일 노출/DAU | 출처 |
|----------|:---:|:---:|------|
| 리워드 비디오 | $15~$30 | ~1.5회 | MAF, Business of Apps |
| 전면 (Interstitial) | $10~$20 | ~2회 | MAF, Playwire |
| 배너 | $0.5~$2 | ~15회 | 동일 |

**ARPDAU 산출:**

| 항목 | 계산 | 일 수익 |
|------|------|--------|
| 전면 광고 (세션당 1~2회) | eCPM $12 × 2회 ÷ 1,000 | $0.024 |
| 리워드 (비구독자 시청률 ~30%) | eCPM $20 × 1.5회 × 0.3 ÷ 1,000 | $0.009 |
| 배너 (상시 노출) | eCPM $1 × 15회 ÷ 1,000 | $0.015 |
| **합계 ARPDAU** | | **$0.048 → 보정 $0.035** |

**보정 근거:**
- 유틸리티 앱 성공적 ARPDAU 벤치마크: **$0.03** (Adjust, adjoe)
- 전면 광고 권장 빈도: 시간당 최대 1회 (Google 권장, Yango Ads)
- 리워드 광고 시청률: 게임 78% → 유틸리티 추정 30% (Yango Ads: 유틸리티는 게임 대비 20~30% 낮음)
- 한국 eCPM은 미국 대비 50~70% 수준

**적용: 비구독 DAU 1명당 ~₩1,500/월** (ARPDAU $0.035 × 30일 = $1.05 ≈ ₩1,470)

> 출처: [MAF Mobile Ads eCPM](https://maf.ad/en/blog/mobile-ads-ecpm/), [Playwire AdMob Benchmarks](https://www.playwire.com/blog/admob-ecpm-benchmarks-what-publishers-should-expect), [Adjust ARPDAU](https://www.adjust.com/glossary/arpdau/), [adjoe ARPDAU Guide](https://adjoe.io/blog/increase-arpdau-guide/), [Yango Ads Interstitial](https://yango-ads.com/blog/mobile-interstitial-ads)

### 1-6. 오가닉 성장 요인

| 요인 | 1년차 | 2년차 | 3년차 | 근거 |
|------|------|------|------|------|
| ASO 오가닉 | 월 100→400건 (점진) | +36% (ASO 최적화) | +20% (추가 개선) | 아래 상세 |
| 유료 부스트 | 유료의 40% | 동일 | 동일 | Digital Turbine: 유료 광고 ×1.5 오가닉 부스트, 보수 적용 |
| 자연 검색 유입 | 월 150→310건 | 월 350→680건 | 월 700→975건 | 아래 상세 |
| 바이럴 K | 0.15 | 0.20 | 0.25 | Amplitude: 실무 기준 K 0.15~0.25(좋음) |
| Android | - | - | 25개월차~ (iOS의 30%→) | Adapty 2026: Android ARPU $69 vs iOS $140 |

**ASO 오가닉 월 100건 출발점 근거:**

| 데이터 | 수치 | 출처 |
|--------|------|------|
| 인디 앱 론칭 시 오가닉 (마케팅 없음) | 월 60~150건 (일 2~5건) | PreApps 2025 |
| 기본 ASO 적용 후 | 월 300~1,500건 (일 10~50건) | SplitMetrics 2025 |
| 사진 앱 ASO 최적화 효과 | +36% 오가닉 증가 | ASO World (RAW 편집 앱 사례) |
| ASO 적극 적용 시 | YoY +150% 오가닉 | MobileAction 2025 |
| **SweepPic 적용** | **월 100건 시작 (인디 앱 범위 중앙)** | PreApps 범위(60~150) 내 |

**자연 검색 유입 근거:**

| 데이터 | 수치 | 출처 |
|--------|------|------|
| 앱스토어 검색 노출 → 설치 전환율 | 3.8% (Install Rate, 미국 2024 H1) | Adapty 2026 |
| 비게임 앱 다운로드 중 검색 비중 | ~70% | Sensor Tower 2021 |
| Photo & Video 카테고리 앱 수 | 수만 개 (상위 경쟁 치열) | Appfigures |
| **SweepPic 적용** | **1년차 월 150건 시작** | 인디 앱(60~150건) + 유료 광고의 ASO 시너지. 연차별 ASO 개선에 따라 점진 증가 |

> ⚠️ 자연 검색 유입의 절대 수치는 키워드 검색 볼륨에 의존하며, 실제 ASA 캠페인 impression 데이터로 보정 필요.
> Apple은 절대 검색 횟수를 공개하지 않으므로, 론칭 후 실측으로 대체해야 함.

**유료 부스트 근거:**
- Digital Turbine: 유료 광고 집행 시 오가닉 다운로드가 ×1.5 증가 (50% 부스트)
- 본 시뮬레이션에서는 보수적으로 **40%** 적용

> 출처: [PreApps Organic Downloads](https://www.preapps.com/blog/organic-app-downloads/), [SplitMetrics Organic Growth](https://splitmetrics.com/blog/how-to-grow-app-organically-app-store/), [ASO World Photo App Case Study](https://asoworld.com/blog/photo-app-case-study-36-organic-installs-through-strategic-app-store-optimization/), [Digital Turbine Organic Uplift](https://digitalturbine.com/blog/paid-media-affects-organic-lifts-in-app-downloads/), [Amplitude Pirate Metrics](https://amplitude.com/en-us/blog/actionable-pirate-metrics), [Adapty iOS vs Android](https://adapty.io/blog/iphone-vs-android-users/), [Sensor Tower Download Sources 2021](https://sensortower.com/blog/app-store-download-sources-report-2021)

---

## 2. 월별 시뮬레이션 결과

### 주요 월별 데이터

| 월 | 연차 | 광고비 | 총설치 | 구독자 | 구독매출 | 광고매출 | 총매출 | 누적매출 |
|---:|:---:|------:|------:|------:|-------:|-------:|------:|-------:|
| 1 | 1차 | 250만 | 1,622 | 81 | 27.6만 | 0.5만 | 28.1만 | 28.1만 |
| 3 | 1차 | 284만 | 1,940 | 256 | 87.3만 | 1.5만 | 88.8만 | 174.6만 |
| 6 | 1차 | 343만 | 2,453 | 551 | 187.9만 | 3.5만 | 191.4만 | 643.1만 |
| 9 | 1차 | 409만 | 3,010 | 887 | 302.2만 | 5.9만 | 308.1만 | 1,447.5만 |
| 12 | 2차 | 214만 | 2,484 | 1,112 | 379.1만 | 8.0만 | 387.1만 | 2,527.6만 |
| 15 | 2차 | 265만 | 2,905 | 1,368 | 466.2만 | 10.4만 | 476.6만 | 3,865.5만 |
| 18 | 2차 | 323만 | 3,365 | 1,655 | 564.2만 | 13.2만 | 577.4만 | 5,494.3만 |
| 21 | 2차 | 387만 | 3,868 | 1,976 | 673.6만 | 16.4만 | 690.0만 | 7,448.9만 |
| 24 | 3차 | 468만 | 4,882 | 2,395 | 816.4만 | 20.5만 | 836.9만 | 9,809.3만 |
| 27 | 3차 | 583만 | 8,013 | 3,034 | 1,034.1만 | 26.9만 | 1,061.0만 | 12,755.6만 |
| 30 | 3차 | 741만 | 10,600 | 3,855 | 1,314.1만 | 35.4만 | 1,349.4만 | 16,499.1만 |
| 33 | 3차 | 942만 | 13,174 | 4,881 | 1,663.5만 | 46.2만 | 1,709.7만 | 21,255.3만 |

---

## 3. 연도별 요약

| | 1년차 (9개월) | 2년차 (12개월) | 3년차 (12개월) |
|--|------|------|------|
| 총 광고비 | 2,928만 | 3,344만 | 7,608만 |
| 신규 설치 | 20,639건 | 36,062건 | 102,188건 |
| **누적 설치** | **20,639건** | **56,701건** | **158,889건** |
| 활성 구독자 | 887명 | 1,976명 | 4,881명 |
| 구독 매출 | 1,421만 | 5,868만 | 13,451만 |
| 광고 매출 | 27만 | 133만 | 355만 |
| **총매출 (Gross)** | **1,448만** | **6,001만** | **13,806만** |
| 월말 매출 | 308만/월 | 690만/월 | 1,710만/월 |

### 성장률

| | 1→2년차 | 2→3년차 |
|--|:---:|:---:|
| 설치 성장 | +75% | +183% |
| 매출 성장 | +315% | +130% |
| 구독자 성장 | +123% | +147% |

---

## 4. 성장 구조 분석

### 4-1. 오가닉 비중 증가 (광고 의존도 감소)

| | 1년차 | 2년차 | 3년차 |
|--|:---:|:---:|:---:|
| 유료 설치 비중 | ~45% | ~30% | ~20% |
| 오가닉+바이럴 비중 | ~55% | ~70% | ~80% |

광고비를 중단해도 오가닉으로 매출이 유지되는 구조로 전환.

### 4-2. 복리 재투자 효과

- 1년차: 정부 광고비 2,250만 + 매출 재투자 678만 = 총 2,928만
- 2년차: 매출 재투자만으로 3,344만 (정부지원 종료 후에도 광고 규모 유지)
- 3년차: 매출 재투자 7,608만 (1년차 정부지원의 3.4배 규모)

### 4-3. 3년차 Android 효과

- 25개월차(3년차 4월)부터 Android 출시
- 3년차 신규 설치 102,188건 중 Android 비중 증가
- Android 전환율(3%)은 iOS(5%)보다 낮지만 설치 볼륨으로 보완
- Android ARPU는 iOS의 49% 수준 (Adapty 2026: 연 $69 vs $140)

---

## 5. 근거 출처 종합

| # | 데이터 | 적용 위치 | 출처 URL |
|---|--------|----------|----------|
| 1 | Photo & Video Trial→Paid 22~26% | §1-3 전환율 | [RevenueCat 2025](https://www.revenuecat.com/state-of-subscription-apps-2025/) |
| 2 | 5~9일 Trial→Paid 45% (전체 평균) | §1-3 참고 | [RevenueCat 2025](https://www.revenuecat.com/state-of-subscription-apps-2025/) |
| 3 | 구독 기간별 비율 (월 36.7%:연 41.4%:주간 21.9%) | §1-3 월:연 비율 | [RevenueCat 2025](https://www.revenuecat.com/state-of-subscription-apps-2025/) |
| 4 | Photo & Video 12개월 갱신율 58.1% | §1-4 갱신율 | [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps/) |
| 5 | Hard Paywall 전환율 10.7%, Freemium 2.1% | §1-3 체험시작률 | [RevenueCat 2026](https://www.revenuecat.com/state-of-subscription-apps/) |
| 6 | 유틸리티 앱 ARPDAU $0.03 (성공적 수준) | §1-5 광고수익 | [Adjust](https://www.adjust.com/glossary/arpdau/), [adjoe](https://adjoe.io/blog/increase-arpdau-guide/) |
| 7 | 리워드 eCPM $15~30, 전면 $10~20, 배너 $0.5~2 | §1-5 eCPM | [MAF](https://maf.ad/en/blog/mobile-ads-ecpm/), [Playwire](https://www.playwire.com/blog/admob-ecpm-benchmarks-what-publishers-should-expect) |
| 8 | 인디 앱 론칭 오가닉 월 60~150건 | §1-6 ASO 기준점 | [PreApps](https://www.preapps.com/blog/organic-app-downloads/) |
| 9 | 앱스토어 Install Rate 3.8% | §1-6 자연검색 | [Adapty 2026](https://adapty.io/blog/app-store-conversion-rate/) |
| 10 | 사진 앱 ASO +36% 오가닉 | §1-6 ASO 효과 | [ASO World](https://asoworld.com/blog/photo-app-case-study-36-organic-installs-through-strategic-app-store-optimization/) |
| 11 | 유료→오가닉 부스트 ×1.5 | §1-6 유료부스트 | [Digital Turbine](https://digitalturbine.com/blog/paid-media-affects-organic-lifts-in-app-downloads/) |
| 12 | 바이럴 K 0.15~0.25 (실무 기준 "좋음") | §1-6 바이럴 | [Amplitude](https://amplitude.com/en-us/blog/actionable-pirate-metrics) |
| 13 | Branch 공유완료율 30%(비인센티브)~70%(인센티브) | §1-6 바이럴 경로 | [Branch](https://www.branch.io/resources/blog/mobile-sharing-and-referral-feature-benchmarks-from-branch/) |
| 14 | iOS vs Android ARPU $140 vs $69 | §1-6 Android | [Adapty 2026](https://adapty.io/blog/iphone-vs-android-users/) |
| 15 | CPI: ASA 유틸리티 $1.80~$2.90 | §1-2 CPI | [AppTweak 2025](https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks) |
| 16 | CPI: 릴스 iOS $3.50~$5.00 | §1-2 CPI | [Wask 2025](https://www.wask.co/instagram-advertising-costs) |
| 17 | 전면 광고 권장: 시간당 최대 1회 | §1-5 노출빈도 | [Yango Ads](https://yango-ads.com/blog/mobile-interstitial-ads) |

---

## 6. 시뮬레이션 한계 및 주의사항

| # | 한계 | 설명 |
|---|------|------|
| 1 | 자연 검색 유입 절대치 | 월 150~975건은 인디 앱 범위(60~1,500)에서 추정. Apple은 절대 검색 횟수를 비공개하므로 론칭 후 ASA impression 데이터로 보정 필요 |
| 2 | 바이럴 K | 0.15→0.25는 공유 기능 단계적 강화를 전제. Amplitude 기준 "좋음" 범위(0.15~0.25)이나 미구현 시 하향 |
| 3 | Android 전환율 | 3%는 iOS(5%)의 ARPU 비례 추정. 실제 Android 사진 정리 앱 전환율 데이터 부재 |
| 4 | 광고 eCPM | 시장 변동에 따라 ±30% 편차 가능. 한국 eCPM은 미국 대비 50~70% |
| 5 | 구독 갱신율 | 58.1%는 Photo & Video 카테고리 중앙값. 사진 정리 앱은 "Use & Forget" 리스크로 더 낮을 수 있음 |
| 6 | 피처드 미반영 | Apple 피처드 선정 시 다운로드 7~10배 스파이크 가능하나 확률적이므로 제외 |
| 7 | 월:연 구독 비율 | 50:50은 RevenueCat 전체 시장 비율에서 추정. Photo & Video 카테고리 단독 비율은 미공개 |
| 8 | ARPDAU | $0.035는 유틸리티 벤치마크 상단($0.03). 광고 배치 최적화 전제 |

---

## 7. v2→v3 변경 이력

| 항목 | v2 | v3 | 변경 사유 |
|------|----|----|----------|
| CPI (1년차) | ₩3,295 | ₩3,100 | 채널별 가중평균 재산출 (0.3×1,500+0.5×3,500+0.2×4,500) |
| 월:연 비율 | 60:40 | 50:50 | RevenueCat 2025 근거 확보 (주간 제외 재조정 47:53 + 낮은 할인율 보정) |
| 광고 수익 | ₩2,000/DAU/월 | ₩1,500/DAU/월 | ARPDAU 벤치마크 $0.03 기반 (Adjust, adjoe) |
| ASO 출발점 출처 | "ASO World" | PreApps 2025 | 인디 앱 론칭 시 월 60~150건 직접 근거 |
| 자연검색 출처 | "Apple 70% 검색" | Sensor Tower 2021, Adapty 2026 | Apple 70%는 행동 비율이지 절대치 근거가 아님 |
| 갱신율 카테고리 | "유틸리티" | "Photo & Video" | RevenueCat 원본 카테고리 정정 |

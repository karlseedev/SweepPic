# 광고비 배분 전략 리서치: 초반 집중 vs 균등 배분

> 조사일: 2026-03-19
> 목적: 사업계획서 광고선전비(6,500만원, 8개월) 배분 전략 근거 마련
> 기준 문서: `260303BusinessPlanB.md`, `260313revenue.md`

---

## 1. 조사 배경

| 항목 | 값 |
|------|---|
| CPI 직접 광고비 | 6,500만원 (ASA한국 1,500 + ASA글로벌 3,800 + 인스타 1,200) |
| 협약기간 | 5~12월 (8개월) |
| 균등 배분 시 | 월 약 812만원 |
| 비교 대상 | 초반 집중(Front-Loading) vs 균등 배분(Even Pacing) |

---

## 2. 초반 집중 투자 (Front-Loading)

### 장점

- **다운로드 속도(Velocity) 극대화**: App Store 알고리즘은 단기간 내 다운로드 급증을 "핫한 앱"으로 인식하여 오가닉 노출 증가
- **초기 저렴한 단가 확보**: 월 후반/시즌 말로 갈수록 광고 경매 가격 상승 경향
- **신규 앱 부스트 활용**: Apple이 신규 앱에 7일간 키워드 랭킹 부스트 제공 (최근 약화 추세)
- **광고 노출 25~40% 증가**: Google Ad Manager 기준 Front-loaded 딜리버리는 Even 대비 초반 노출 우위
- **알고리즘 학습 데이터 축적**: 충분한 초기 데이터로 광고 플랫폼 ML 최적화 가속

### 단점

- **예산 조기 소진 리스크**: 성과 미검증 채널에 과다 지출 가능
- **학습 없는 과투자**: 어떤 채널/크리에이티브가 효과적인지 모른 채 대규모 투자 시 낭비
- **CPI 상승 가능성**: 급격한 스케일링 시 타겟 품질 저하, CPI 상승
- **전문가 수준 관리 필요**: ASAP/프론트로드 방식은 경험 있는 미디어 바이어에게만 권장

---

## 3. 균등 배분 (Even Pacing)

### 장점

- **안정적 예산 관리**: 전 기간에 걸쳐 예산 유지 가능
- **지속적 테스트**: 다양한 크리에이티브, 채널, 타겟을 꾸준히 A/B 테스트하며 최적화
- **CPI 점진 하락**: 알고리즘에 충분한 학습 시간 → 최적화 진행 → CPI 감소
- **장기 캠페인에 적합**: 6개월 이상의 장기 UA 캠페인에서 안정적

### 단점

- **초기 모멘텀 부족**: App Store 랭킹 상승에 필요한 다운로드 속도 확보 어려움
- **후반부 비용 상승**: 시즌/경쟁 심화 시기에 높은 단가 지불 가능
- **알고리즘 부스트 미활용**: 론칭 초기 윈도우를 놓칠 수 있음

---

## 4. 앱스토어 랭킹 부스트 효과

### 다운로드 속도와 랭킹

- **최근 24시간 다운로드 수**가 가장 큰 가중치, **72시간까지** 영향력 유지
- 단순 누적 다운로드보다 **다운로드 증가 속도(가속도)**가 더 중요
- 랭킹 변동은 실시간이 아닌 인터벌 단위 평가 (수시간~수일)

### 버스트 캠페인 효과

- 24~72시간 집중 광고로 랭킹 상승 가능
- 효과는 **7~14일 내 급격히 감소** — 지속적 리텐션/인게이지먼트 시그널 없이는 원위치
- 미국 시장 의미 있는 랭킹 상승: 최소 12만 다운로드 이상 필요
- 한국 금융 카테고리 Top 1: 일 1,000건 미만 (카테고리별 편차 큼)

### 신규 앱 부스트

- Apple 신규 앱 약 **7일간 키워드 랭킹 부스트** 제공
- AI 기반 저품질 앱 대량 출시 문제로 **최근 약화/폐지 추세**
- 부스트 기간 중 #23~26위 → 7일 후 #50~260위 급락 사례 (Sensor Tower)
- 부스트 기간 중 유료 UA로 속도를 유지하면 종료 후에도 오가닉 랭킹 유지 확률 상승

### 오가닉 다운로드 영향

- 랭킹 상승 → Top Charts 노출 → **오가닉 다운로드 급증** (cascade effect)
- 유료 다운로드보다 오가닉이 더 많아질 수 있으나, 앱 품질(리텐션, 평점, 크래시율) 필수
- Pfizer 앱 사례: 48시간 만에 Top 3 진입, CPI 시장 평균의 절반

---

## 5. CPI 최적화 관점

### 예산과 CPI의 관계

- **초반 급투자 → CPI 상승**: 학습 단계에서 알고리즘 미최적화 상태에 과다 지출 시 비효율적 노출 증가
- **균등 배분 → CPI 점진 하락**: 알고리즘에 충분한 학습 시간 부여
- **핵심 원칙**: 월/분기 단위 전진 배치는 OK, **일일 예산의 급격한 증감은 NG**

### 최적 일일 예산 설정

| 플랫폼 | 설정 기준 | 예시 (목표 CPI $3) |
|--------|----------|-------------------|
| Google UAC | 목표 CPI × 50 | 일일 $150 |
| Facebook/Meta | 목표 일일 설치 × CPI × 1.5 | 일일 $45~$75 |
| ASA | Daily Cap으로 간접 조절 | 일일 $15~$30 (인디 앱 초기) |

- 예산 변경 시 한 번에 **10~20% 이내**, 최소 **2~4주 간격**
- 급격한 스케일링은 학습 모드 재진입 → 일시적 CPI 급등

### 계절성에 따른 CPI 변동

| 분기 | CPI 경향 | 주요 요인 |
|------|---------|----------|
| Q1 (1~3월) | **가장 낮음** | 연말 이후 광고주 예산 리셋, 경쟁 완화 |
| Q2 (4~6월) | **급등 (+79%)** | 여름 시즌 준비, 6월 특히 높음 |
| Q3 (7~9월) | 안정화 | 8~10월이 연중 가장 안정적 |
| Q4 (10~12월) | 변동적 | 블프/연말 시즌 CPM 급등, 12월 말 급락 |

> SweepPic 협약기간(5~12월) 기준: **5~6월 CPI 높음 → 7~10월 안정 → 11~12월 변동**
> 테스트 기간을 CPI 높은 5~6월에 배치하고, 집중 투자를 7~9월 안정기에 하는 것이 효율적

### Photo & Video 앱 CPI 벤치마크

| 채널 | CPI |
|------|-----|
| Apple Search Ads (Photo & Video) | $3.13 (중앙값) |
| Apple Search Ads (Utilities) | $2.90 (중앙값) |
| Apple Search Ads 전체 평균 | $1.42 |
| Google UAC 평균 | $2.65~$4.00 |
| Facebook 평균 | $3.75 |
| Instagram 평균 | $3.50 |

---

## 6. ASA(Apple Search Ads) 예산 전략

### ASA 예산 구조

- **캠페인 총 예산**: 전체 기간 최대 지출 한도 (도달 시 자동 중단)
- **일일 예산 상한(Daily Cap)**: 하루 최대 지출 (실제 지출은 이보다 낮을 수 있음)
- ASA는 Google Ads처럼 명시적 pacing 옵션(균등/가속) 없음 — Apple이 Daily Cap 내에서 자동 분배

### ASA 학습 기간

- 공식 "Learning Phase" 상태 표시 없으나 실무적으로 **7~14일 데이터 수집** 필요
- 키워드별 최소 10~20회 탭 + 5~10회 설치가 있어야 통계적으로 유의미
- 이 기간 입찰가 급변/키워드 대량 변경 금지

### 인디 앱 ASA 전략

- **초기 예산**: 월 $500~$2,000 권장 (SplitMetrics)
- **캠페인 3개 구성**:
  1. **Brand**: 앱 이름 키워드 (Exact Match, 낮은 입찰가) — CPA 최저
  2. **Discovery**: Search Match ON + Broad Match — 키워드 발굴용
  3. **Exact Match**: Discovery에서 검증된 고성과 키워드 이동
- **입찰 전략**: 소규모 예산에서는 CPA 자동 입찰보다 **수동 CPT Max가 효과적**
- **롱테일 키워드 집중**: "photo organizer" 대신 "swipe delete photos" 같은 구체적 키워드
- **ASO 연계**: 메타데이터·스크린샷 최적화가 ASA 전환율(TTR, CR)에 직접 영향

---

## 7. 권장 전략: 하이브리드 (테스트 → 집중 → 유지)

### 업계 표준 권장

- "Pace Ahead" 방식: 캠페인 전반부에 예산 약 60% 배분이 디지털 미디어 집행 베스트 프랙티스
- 론칭 시 전체 예산의 40~50%를 론칭 2~4주에 집중, 연간 기준 출시 후 6개월 내 60~70% 투하

### SweepPic 적용: 3단계 배분안

| 단계 | 기간 | 예산 비중 | 월 예산 | 활동 |
|------|------|------:|------:|------|
| 테스트 | 1~2개월 (5~6월) | 15% | ~490만 | ASA 키워드 발굴, 크리에이티브 A/B, CPI 기준선 확립 |
| 집중 투자 | 3~5개월 (7~9월) | 55% | ~1,190만 | 검증 채널 스케일업, CPI 안정기 활용, 랭킹 부스트 |
| 유지·최적화 | 6~8개월 (10~12월) | 30% | ~650만 | 고효율 키워드 유지, 리텐션 중심 |
| **합계** | **8개월** | **100%** | | **6,500만** |

### 균등 배분 대비 하이브리드의 이점

- 5~6월(CPI 높은 시기)에 소규모 테스트 → 비용 절감
- 7~9월(CPI 안정기)에 집중 투자 → 동일 예산으로 더 많은 설치 확보
- 랭킹 부스트 → 오가닉 선순환 효과
- 10~12월 Q4 변동기에 예산 축소 → 리스크 관리

---

## 8. 참고 자료

| # | 주제 | 출처 |
|---|------|------|
| 1 | 예산 배분 전략 | [ShyftUp - Budget Strategies](https://www.shyftup.com/blog/budgeting-strategies-for-mobile-app-marketing-get-the-most-out-of-your-ad-spend/) |
| 2 | 신규 앱 랭킹 하락 | [Sensor Tower - Rankings Drop After 7 Days](https://sensortower.com/blog/why-app-store-keyword-rankings-drop-dramatically-seven-days-after-launch) |
| 3 | 광고 Pacing 이해 | [Pathlabs - Pacing in Advertising](https://www.pathlabs.com/blog/what-is-pacing-in-advertising) |
| 4 | 론칭 마케팅 예산 | [BusinessDojo - App Launch Budget](https://dojobusiness.com/blogs/news/mobile-app-marketing-budget-estimate) |
| 5 | 예산 Pacing 가이드 | [Improvado - Budget Pacing](https://improvado.io/blog/budget-pacing) |
| 6 | 앱스토어 랭킹 요인 | [Moburst - Ranking Factors](https://www.moburst.com/blog/app-store-ranking-factors/) |
| 7 | 버스트 캠페인 | [AppSamurai - Burst Campaigns 2025](https://appsamurai.com/blog/burst-campaigns-for-mobile-app-marketing/) |
| 8 | CPI 벤치마크 2025 | [Business of Apps - CPI Research](https://www.businessofapps.com/ads/cpi/research/cost-per-install/) |
| 9 | ASA 벤치마크 2025 | [AppTweak - Apple Ads Benchmarks](https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks) |
| 10 | ASA 비용 2025 | [SplitMetrics - ASA Cost](https://splitmetrics.com/blog/apple-search-ads-cost/) |
| 11 | ASA 베스트 프랙티스 | [SplitMetrics - ASA Best Practices](https://splitmetrics.com/blog/apple-search-ads-best-practices/) |
| 12 | CPI 카테고리별 2025 | [Mapendo - CPI by Category](https://mapendo.co/blog/cost-per-install-by-app-category-2025) |
| 13 | Google App Campaign | [Google Ads Help - App Campaigns](https://support.google.com/google-ads/answer/6167162?hl=en) |
| 14 | 계절별 광고 트렌드 | [Setupad - Seasonal Trends](https://setupad.com/blog/seasonal-advertising-trends/) |
| 15 | UA 스케일링 | [Udonis - Scale UA](https://www.blog.udonis.co/mobile-marketing/how-to-successfully-scale-your-user-acquisition-campaigns) |
| 16 | 앱스토어 랭킹 2026 | [AppTweak - Ranking Factors 2026](https://www.apptweak.com/en/aso-blog/app-store-ranking-factors) |

---

## 9. 론칭 마케팅 전략: 오픈 효과 및 Apple 신규 앱 혜택

> 추가 조사일: 2026-03-20
> 목적: 광고비 배분 시 론칭 시점 집중 투자의 근거 확보

### 9-1. Apple 신규 앱 부스트 (일회성)

| 혜택 | 기간 | 비고 |
|------|------|------|
| 키워드 랭킹 부스트 | **7일** (일회성) | 7일 후 #26 → #260 급락 사례 (Sensor Tower) |
| 자동완성 제안 노출 | **5일** | 앱 제목 내 키워드 기준 |
| Featuring Nomination | 상시 | App Store Connect에서 무료 신청, 3주 전 제출 권장 |
| $100 광고 크레딧 | 1회 | 신규 Apple Ads 계정 |

- 7일 부스트는 **각 국가별 첫 출시 시에만 1회 적용** — 업데이트에서는 미적용
- 부스트 기간 동안 실제 성과 대비 훨씬 높은 검색 순위 부여
- 부스트 종료 후 "Seven Day Cliff" 현상: Top 10 → #40~50, #28 → #260 수준 급락
- **전략**: 7일간 공격적 키워드 타겟 + 부스트 종료 후 현실적 난이도 키워드로 전환

### 9-2. 론칭 초기 테스트 vs 집중 투자

**론칭 후 1~2개월을 테스트로 쓰면 안 되는 이유:**

- 7일간의 New App Boost를 낭비 (다시 오지 않음)
- 자동완성 부스트 5일도 소진
- 초기 낮은 다운로드 → 알고리즘이 "관심 없는 앱"으로 분류
- Marketing Science Institute: 잘 준비된 론칭을 한 제품은 초기 시장 존재감 50% 높음

**권장: 소프트 론칭(론칭 전) → 하드 론칭(집중 투자)**

| 단계 | 시점 | 활동 |
|------|------|------|
| 소프트 론칭 | 론칭 4~8주 전 | 소규모 국가에서 리텐션·전환율 테스트 |
| 하드 론칭 | D-Day | 목표 시장 정식 출시, 마케팅 집중 투하 |
| 안착 | D+7~ | 부스트 종료 후 키워드 전환, 지속 UA |

### 9-3. Apple 공식 광고 상품

| 상품 | 위치 | CPA 벤치마크 | 론칭 시 우선순위 |
|------|------|-------------|--------------|
| **Search Results** | 검색 결과 내 | Photo & Video **$1.03** | **최우선** — 전환율 최고 |
| Today Tab | 앱스토어 첫 화면 | $5.08 | 후순위 — 브랜드 인지도용 |
| Search Tab | 검색 탭 상단 | - | 보조 |
| Product Pages | 타 앱 페이지 하단 | - | 경쟁 앱 유저 타겟 |

- **피처링은 유료 상품이 아님** — 돈 주고 살 수 없고, Nomination만 가능
- Photo & Video 카테고리 ASA CPA $1.03은 전 카테고리 중 **최저** (AppTweak 2025)
- Apple Search Ads Advanced 권장 (Basic은 월 $10,000 한도, 키워드 관리 불가)

### 9-4. Featuring Nomination 활용법

- App Store Connect > Featuring > Nominations에서 신청
- 3가지 유형: New Content / App Enhancements / **App Launch**
- **3주 전 제출 권장**, 넓은 피처링은 3개월 전
- Apple 중시 요소: UX, UI 디자인, 혁신성, 독창성, 접근성, 현지화, 제품 페이지 품질
- "New Apps We Love" 선정 시 **최대 1개월간** 노출 가능

### 9-5. 시뮬레이션 반영 포인트

조사 결과 기반 파라미터 조정 권장:

| 파라미터 | 기존 | 조정안 | 근거 |
|----------|------|--------|------|
| 1개월차 CPI | ₩3,200 | **₩2,500** | ASA 집중 시 Photo CPA $1.03 반영 |
| 1개월차 PAID_BOOST | 50% | **80~100%** | 7일 랭킹 부스트 오가닉 급증 효과 |
| ASO 오가닉 시작 | 월 100건 | **월 200건** | 소프트 론칭 후 스토어 최적화 완료 상태 |
| 광고비 배분 | 8개월 균등/하이브리드 | **5개월 집중** | 론칭 모멘텀 극대화 |

### 참고 자료

| # | 주제 | 출처 |
|---|------|------|
| 1 | 7일 랭킹 하락 | [Sensor Tower](https://sensortower.com/blog/why-app-store-keyword-rankings-drop-dramatically-seven-days-after-launch) |
| 2 | 론칭 부스트 전략 | [RadASO](https://radaso.com/blog/how-to-boost-an-app-at-the-first-app-store-release-life-hacks-from-radaso) |
| 3 | 소프트 론칭 전략 | [MobileAction](https://www.mobileaction.co/blog/soft-launch-marketing-strategy/) |
| 4 | 앱 론칭 전략 2026 | [Moburst](https://www.moburst.com/blog/app-launch-strategy/) |
| 5 | 피처링 신청 | [Apple Developer](https://developer.apple.com/app-store/getting-featured/) |
| 6 | Featuring Nomination | [Apple Help](https://developer.apple.com/help/app-store-connect/manage-featuring-nominations/nominate-your-app-for-featuring/) |
| 7 | Apple Ads 배치 | [Apple Ads](https://ads.apple.com/app-store/help/ad-placements/0081-ad-placement-options) |
| 8 | $100 크레딧 | [Apple Ads](https://searchads.apple.com/help/billing/0032-apple-search-ads-promo-credit) |
| 9 | ASA 벤치마크 2025 | [AppTweak](https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks) |
| 10 | 앱스토어 랭킹 2025 | [SplitMetrics](https://splitmetrics.com/blog/apple-app-store-ranking-factors/) |
| 11 | 앱스토어 랭킹 2026 | [MobileAction](https://www.mobileaction.co/blog/app-store-ranking-factors/) |
| 12 | ASA Basic vs Advanced | [Apple Ads](https://ads.apple.com/app-store/help/apple-ads-basic/0001-compare-apple-ads-solutions) |

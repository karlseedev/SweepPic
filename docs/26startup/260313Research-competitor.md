# 경쟁사 분석 및 시장 포지셔닝 리서치

> 조사일: 2026-03-13
> 목적: 사업계획서 "경쟁사 분석 및 시장 포지셔닝" 섹션 근거 마련
> 방법: 8개 에이전트 병렬 조사

---

## 1. Codeway(Cleanup 개발사) 마케팅 전략

### 회사 개요
- 터키 2020년 설립, 연 매출 약 $150M
- 60개+ 앱 포트폴리오, 16개 핵심 앱, 9개 앱이 각 월 $200K+ 매출
- 총 사용자 4.55억+

### 마케팅 비용 추정
- 매출 대비 30~40% (연 $45M~$60M)
- **터키 정부 광고비 60~70% 환급** (앱당 최대 $400K/년, 3앱 최대 $1.2M/년)
- 실질 마케팅 부담: 연 $15M~$24M

### 주요 채널
| 채널 | 역할 |
|------|------|
| Meta (Facebook/Instagram) | 핵심 UA, pLTV 기반 최적화, 32% 더 많은 구독, 19% 낮은 CPA |
| Apple Search Ads | 가장 예측 가능한 채널, 월 지출 800% 확대 |
| TikTok | 보조 UA |
| YouTube | 고령층 타겟 |

### 고령층 타겟팅
- Facebook/YouTube에서 고령층 집중 타겟팅 (Connor Tumbleson 보고서)
- 주간 구독으로 구독 잊음 유도

### 출처
- [Growth Hacking Lab - Codeway $150M](https://thegrowthhackinglab.com/case-studies/codeway-150-million-revenue-16-apps/)
- [MobileAction - Codeway ASA 800%](https://www.mobileaction.co/success-story/codeway/)
- [Meta - Codeway 케이스 스터디](https://www.facebook.com/business/success/3-codeway-studios)
- [Finahukuk - 터키 인센티브](https://www.finahukuk.com/en/2025/01/04/why-non-gaming-app-companies-should-consider-turkey-my-experience-with-government-incentives/)

---

## 2. 시장 집중도 및 매출 점유율

### 상위 앱 매출 분포

| 순위 | 앱 | 추정 월매출 | 점유율 |
|------|---|-----------|--------|
| 1 | Cleanup | ~$9M | ~22.5% |
| 2 | Cleaner Guru | ~$5M | ~12.5% |
| 3 | AI Cleaner | ~$4M | ~10.0% |
| 4 | Cleaner Kit | ~$3M | ~7.5% |
| 5+ | Swipewipe 외 | 각 ~$1M | 각 ~2.5% |

### 시장 구조
- HHI ~856 → **비집중 경쟁 시장** (< 1,500)
- 2024년 상위 10개 합산: $197M
- 2025년 월간 전체: $40M (MoM 17% 성장)
- 매출 95%+ iOS App Store 집중
- 앱 1,500개 중 월 $1M+ 매출: 7개뿐

### 신규 진입 성공 사례: Swipewipe
- 2021년 출시, 스와이프 UX 차별화
- 현재 월 $1M 매출, 40만 다운로드, ★4.7 (47K 리뷰)

### 출처
- [Appfigures - Storage Cleaner Apps](https://appfigures.com/resources/insights/20250606?f=1)
- [Sensor Tower - 개별 앱 매출](https://app.sensortower.com/)

---

## 3. 갤러리+정리 통합 앱 사례 (포지션 유일성 검증)

### 결론: **"그리드에서 바로 스와이프 삭제"가 가능한 앱은 시장에 존재하지 않음**

### 조사 결과

| 앱 | 갤러리 기능 | 그리드 삭제 | 비고 |
|---|:---:|:---:|---|
| Slidebox | X (전체화면만) | X | 1장씩 스와이프 |
| SwipeWipe | X | X | 전체화면 좌우 스와이프 |
| HashPhotos | O (그리드) | X | 중복 제거는 별도 메뉴 |
| CleanMyPhone | X | X | AI 카테고리 브라우징 |
| Google Photos | O (그리드) | X | 스와이프 정리 테스트 중이나 별도 모드 |
| Apple Photos | O (그리드) | X | 선택 > 삭제 (다단계) |

### 통합 실패/성공 분석
- **Flic (2014)**: 스와이프만으로 리텐션 불가 → 사실상 폐업
- **Slidebox**: 스와이프+앨범 결합으로 생존, 갤러리 시도 안 함
- **근본 딜레마**: 정리 앱은 정리 끝나면 열 이유 없음, 갤러리 앱은 Apple Photos 전환비용 높음

### Google Photos 동향
- 2025년 "Clean up this day" 틴더 스와이프 테스트 중 (APK teardown)
- 단, 별도 모드로만 구현, 그리드 탐색 중 정리 아님

### 출처
- [Android Authority - Google Photos 스와이프](https://www.androidauthority.com/google-photos-tinder-swipe-left-right-3589872/)
- [Slidebox 공식](https://slidebox.co/)
- [SwipeWipe - InsanelyMac](https://www.insanelymac.com/blog/swipewipe-photo-cleaner-review/)

---

## 4. 다크패턴·약탈적 과금 규제 동향

### 글로벌 규제 현황

| 규제 | 핵심 내용 | 상태 |
|------|----------|------|
| Apple Guidelines 3.1.2 | 구독 투명성, 2024년 37,000 사기 앱 제거 | 시행 중 (약탈적 앱은 여전히 존재) |
| 한국 전자상거래법 | 6대 다크패턴 유형 규제 | 2025.02 시행, 2025.08 본격 집행 |
| EU DSA | 다크패턴 명시적 금지 | 2024.02 전면 시행 |
| EU DMA | 게이트키퍼 다크패턴 금지 | 시행 중 |
| EU DFA | 다크패턴 포괄 규제 | 2026년 중반 입법안 예정 |
| FTC (미국) | Amazon $25억 합의 | 개별 집행 계속 |

### 한국 6대 다크패턴 유형
1. 숨은 갱신
2. 순차공개 가격책정
3. 특정 옵션 사전선택
4. 잘못된 계층구조
5. 취소/탈퇴 방해
6. 반복 간섭

### SweepPic 시사점
- 규제 방향이 투명한 가격 정책 앱에 구조적으로 유리
- 경쟁앱의 주간 $5-10 구독 + 다크패턴은 중장기 규제 리스크

### 출처
- [한국 전자상거래법 다크패턴 - 김앤장](https://www.kimchang.com/ko/insights/detail.kc?sch_section=4&idx=29766)
- [EU DSA](https://digital-strategy.ec.europa.eu/en/policies/digital-services-act)
- [FTC Amazon 합의](https://www.ftc.gov/news-events/news/press-releases/2025/09/ftc-secures-historic-25-billion-settlement-against-amazon)
- [Connor Tumbleson - Predatory iOS Apps](https://connortumbleson.com/2025/01/13/predatory-ios-cleanup-applications/)

---

## 5. 사용자 앱 선택/전환 행동

### 앱 선택 기준 (우선순위)
1. 기술 성능 (53% 성능 문제로 삭제)
2. 평점/리뷰 (79% 다운로드 전 확인, 3→4점 시 설치율 89% 증가)
3. UI/UX 품질
4. 가격/무료체험
5. 업데이트 빈도

### 앱 발견 경로
- App Store 검색: 59~70% (비게임 앱 70%)
- 브라우징: 15%
- AI 추천: 40~60%

### 전환 비용
- **매우 낮음** — PhotoKit 기반이므로 데이터 lock-in 없음
- 구독 해지하면 즉시 다른 앱으로 이동 가능

### 사진 정리 앱 특유 행동
- "저장공간 부족" 알림 → 급하게 검색 → 상위 결과 첫 번째 앱 설치
- 이 급박함을 이용한 약탈적 패턴 다수

### 무료체험 3일 vs 7일
- 3일: 전환율 30~35%로 높으나 체험 시작 사용자 적음
- 7일: 체험 시작 비율 22%로 높으나 전환율 20%
- 사진 정리 앱은 가치 체감 빠르므로 3일도 유효

### 첫인상 영향
- 50ms 내 시각적 판단
- Day 1 이탈률 75%
- 온보딩 개선 시 1주차 리텐션 60%→75%

### 출처
- [AppsFlyer - 평점 영향](https://www.appsflyer.com/blog/tips-strategy/app-ratings-reviews/)
- [Phiture - 무료체험 최적화](https://phiture.com/mobilegrowthstack/the-subscription-stack-how-to-optimize-trial-length/)
- [Sensor Tower - 검색 비율](https://sensortower.com/blog/app-store-download-sources)

---

## 6. Clever Cleaner(CleverFiles) 무료 전략 분석

### 전략 요약
- **Loss Leader 전략**: Disk Drill(연 $89~$149)이 핵심 수익원, Clever Cleaner는 브랜드 인지도 확장용
- 완전 무료 + 광고 없음 + 인앱결제 없음
- "Early users will never be asked to pay" → **Freemium 전환 가능성 내포** (Grandfathering)

### CleverFiles 포트폴리오
- Disk Drill PRO: 연 $89 / 평생 $149
- Clever Cleaner: 무료
- 50만+ 고객, 150개국, 16개 언어

### 크로스셀링
- 앱 내 직접 홍보 없으나, 모든 PR에서 "Disk Drill 개발사" 강조
- 브랜드 연상(brand association) 통한 간접 효과

### 유료 시장에 미치는 영향
- "무료 앱이 유사 기능 제공" → 구독 모델 정당성 약화
- 단, 약탈적 앱의 타겟층(고령)은 무료 대안 탐색 소극적 → 즉각적 붕괴 가능성 낮음

### 출처
- [CleverFiles 공식](https://www.cleverfiles.com/clever-cleaner/)
- [InsanelyMac - Clever Cleaner](https://www.insanelymac.com/blog/clever-cleaner-review/)
- [iLounge - Clever Cleaner](https://www.ilounge.com/articles/clever-cleaner-app-for-iphone-review-a-truly-free-ios-cleaner)

---

## 7. 시장 진입장벽 분석

### 종합 평가

| 장벽 | 강도 | SweepPic 영향 |
|------|:----:|--------------|
| 기술적 | 중-하 | Apple 프레임워크로 기본 구현 용이. 차별화 수준은 난이도 높음 |
| 마케팅/ASA | **높음** | 1,500+ 앱, 핵심 키워드 경쟁 극심. 롱테일 키워드 우회 필요 |
| 브랜드/리뷰 | **매우 높음** | Cleanup 624K 리뷰 vs 신규 0. 단기 극복 불가 |
| 네트워크 효과 | **없음** | 사진 정리는 개인 활동 → 신규 진입에 유리 |
| 전환 비용 | **매우 낮음** | PhotoKit 공통 → 진입도 쉬우나 이탈도 쉬움 |
| 규모의 경제 | **높음** | Codeway 60개+ 앱 포트폴리오, 정부 보조금 |

### ASA 키워드 경쟁
- Utilities CPT: $0.92~$2.25
- "photo cleaner" 실제 CPT: $2~$4+ (고수익 프리미엄)
- 상위 앱들이 수천 개 키워드 동시 입찰

### 권장 전략
- "photo cleaner" 레드오션 대신 "photo gallery organizer", "swipe delete photos" 등 롱테일 키워드
- "갤러리" 카테고리로 재정의하여 기존 경쟁 우회

### 출처
- [AppTweak - ASA 벤치마크 2025](https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks)
- [Appfigures - Storage Cleaner Apps](https://appfigures.com/resources/insights/20250606?f=1)

---

## 8. 예비창업패키지 경쟁사 분석 고득점 포인트

### 심사위원 핵심 평가 요소
1. 시장 이해도 (경쟁 구도 정확히 파악)
2. 차별화의 구체성 (경쟁사 강/약점에서 도출된 논리적 차별화)
3. 실현 가능성 (보유 역량과 연결)
4. 시장 규모와 연결

### 모범 구조
1. 경쟁사 3레벨 분류 (직접/간접/대체재)
2. 정량적 비교표
3. ERRC 분석으로 차별화 도출
4. 포지셔닝 맵으로 시각화
5. 진입 전략 및 지속가능성

### 감점 패턴
- "경쟁사 없음", "국내 최초" 주장
- 단순 O/X 비교표만 나열
- 근거 없는 우월 주장
- 차별화와 역량의 불일치

### 적정 분량
- 전체 10페이지 중 경쟁사 분석: 1~1.5페이지
- ERRC + 포지셔닝 맵 조합이 가장 적합

### 출처
- [전 심사위원 작성법](https://brunch.co.kr/@nexttrack/2)
- [사업계획서 실수 5가지](https://brunch.co.kr/@a33f93b357b349e/102)
- [예비창업패키지 합격 전략](https://imweb.me/blog?idx=215)

---

## 9. 목표 시장 진입 전략 리서치

> 조사일: 2026-03-16
> 목적: 사업계획서 "목표 시장 진입 전략" 섹션 근거 마련

---

### 9-1. 예비창업패키지 심사 포인트

심사위원이 "목표 시장 진입 전략"에서 보는 핵심 평가 요소:

1. **구체적인 액션 전략**: "인스타 운영, 블로그 마케팅" 같은 일반론은 감점. 타겟 고객에 맞는 구체적 실행 계획 필요
2. **진입 단계 vs 성장 단계 구분**: (1) 첫 고객을 어떻게 확보할 것인가(진입), (2) 어떻게 확장할 것인가(성장)를 분리
3. **경쟁사 분석 기반 차별성 입증**: 경쟁자가 어떻게 성장했는지 분석하고, 우리가 어떻게 다른지 명확히 제시
4. **시점별 구체적 계획**: 월별/분기별 마일스톤

**고득점 체크리스트:**

| 항목 | 해야 할 것 | 하지 말 것 |
|------|-----------|-----------|
| 시장 규모 | 경쟁사 매출 역산으로 현실적 추정 | TAM만 크게 보여주고 끝내기 |
| 타겟 고객 | 구체적 페르소나 + 정량 근거 | "모든 스마트폰 사용자" |
| 진입 전략 | 이 타겟만을 위한 구체적 채널/액션 | "SNS 마케팅 예정" |
| 성장 전략 | 거점 → 인접시장 확장 로드맵 | 처음부터 글로벌 선언 |
| 시각화 | 도표, 차트, 타임라인 활용 | 글로만 장황하게 설명 |

### 출처
- [예비창업패키지 합격 전략 (imweb)](https://imweb.me/blog?idx=215)
- [전 심사위원 작성법 (brunch)](https://brunch.co.kr/@nexttrack/2)
- [예비창업패키지 사업계획서 목차별 가이드 (wishket)](https://blog.wishket.com/reserve-startups-package-business-plan-list-guide/)
- [2026 예비창업패키지 완전정복 (brunch)](https://brunch.co.kr/@plusmach/55)

---

### 9-2. 거점시장(Beachhead Market) 전략 프레임워크

MIT Bill Aulet 정의:
> "거점시장이란, 일단 지배적 시장 점유율을 확보하면 다른 기회가 있는 인접 시장을 공략할 힘을 갖게 되는 곳"

**거점시장의 3가지 조건 (MIT 기준):**
1. 시장 내 고객이 유사한 제품을 구매함
2. 고객의 구매 주기와 가치 기대 방식이 유사함
3. 시장 내 고객 간 입소문(Word of Mouth)이 존재함

**거점시장 선정 프로세스:**
1. 가능한 시장 세그먼트 6~12개 나열
2. 각 세그먼트를 평가 — 접근 가능한가? 경제적 여력? 경쟁 과도하지 않은가? 인접 시장 확장 가능한가?
3. 하나의 거점시장 선택 → 모든 자원 집중
4. 빠르게 10~20% 시장 점유율 달성
5. 인접 시장으로 순차 확장

**합격 사례 공통 패턴:** 작고 지배 가능한 시장 → 빠른 점유율 확보 → 인접 시장 확장
- 토스: 간편 송금(좁은 거점) → 금융 플랫폼
- Airbnb: 컨퍼런스 참석자 → 일반 여행객 → 글로벌 숙박

### 출처
- [MIT Sloan: The Beachhead Market](https://executive.mit.edu/launching-a-successful-start-up-3-the-beachhead-market-MC7FUMDZ6IU5AIPP4WGIPN2PZJI4.html)
- [Beachhead Market Strategy: 4 Examples (MasterClass)](https://www.masterclass.com/articles/beachhead-market)
- [Disciplined Entrepreneurship](https://www.d-eship.com/step2/)
- [스타트업 거점시장 공략 (brunch)](https://brunch.co.kr/@jongkoo/65)

---

### 9-3. App Store 키워드 전략 (ASO)

#### 키워드 경쟁도 비교

| 키워드 | CPT (US) | CPI (US) | 경쟁 강도 | 비고 |
|--------|---------|---------|----------|------|
| "photo cleaner" | $2~$4+ | $3~$5+ | 극심 | 상위 앱이 수천 개 키워드 동시 입찰 |
| "photo organizer" | $1.5~$2.5 | $2~$4 | 높음 | 갤러리/관리 앱과 경쟁 |
| "photo gallery organizer" | $0.8~$1.5 | $1.5~$3 | 중간 | 롱테일, 경쟁 완화 |
| "swipe delete photos" | 낮음 | $1~$2 | 낮음 | SweepPic 특화 키워드 |

- Photo & Video 카테고리 평균 CPT: $1.69 (US), CPI: $3.13 (US)
- Utilities(Cleaner/Optimizer) CPT: $0.60~$1.50, CPI: $0.90~$2.80

#### 롱테일 키워드 전략

MobileAction ASO 가이드:
- 70~80% 롱테일 + 20~30% 단어형 키워드 비율 권장
- 10개의 타겟팅된 다운로드가 100개의 무작위 다운로드보다 효과적
- Apple이 스크린샷 내 텍스트도 인덱싱 시작 → 캡션 포함 스크린샷으로 검색 노출 22% 향상

**SweepPic 롱테일 키워드 후보:**
- "swipe to delete photos iPhone"
- "photo gallery organizer swipe"
- "clean up similar photos fast"
- "free photo cleanup no subscription"
- "organize photos by swipe"

#### 신규 앱 ASO 성공 사례
- Kleo (언어학습앱): ASO + 키워드 최적화 + 스크린샷 개편으로 1개월 만에 다운로드 127% 증가, 전환율 110% 향상
- Superscale: 포괄적 ASO로 오가닉 다운로드 450% 증가
- 평점 3.5 미만 앱은 검색 노출 크게 감소, 4.0 이상 유지 필수

### 출처
- [AppTweak Apple Ads Benchmarks 2025](https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks)
- [MobileAction - ASO Long-Tail Optimization](https://www.mobileaction.co/blog/aso-long-tail-optimization/)
- [MobileAction - ASO Keyword Research 2026](https://www.mobileaction.co/blog/aso-keyword-research/)
- [AppTweak - ASO Trends 2026](https://www.apptweak.com/en/aso-blog/aso-trends-to-watch-in-2026)

---

### 9-4. Apple Search Ads (ASA) 진입 전략

#### 국가별 CPI (AppTweak 2025 벤치마크)

| 국가 | CPI | US 대비 비율 |
|------|-----|------------|
| 미국 (US) | $4.06 | 100% |
| 일본 (JP) | $2.57 | 63% |
| 한국 (KR) | $1.84 | 45% |
| 영국 (UK) | $2.60 | 64% |
| 캐나다 | $2.24 | 55% |
| 프랑스 | $1.78 | 44% |

#### 카테고리별 CPI (US)

| 카테고리 | CPI | CPT | TTR | 전환율 |
|---------|-----|-----|-----|-------|
| Photo & Video | $3.13 | $1.69 | 5~10% | 45~65% |
| Utilities (Cleaner) | $0.90~$2.80 | $0.60~$1.50 | 5~9% | 50~70% |

핵심: 한국은 미국 대비 CPI가 45% 수준. 일본/한국은 미국 대비 3~5배 나은 CPI에 비슷하거나 더 좋은 LTV.

#### 소규모 예산 ASA 전략

1. 한국 먼저 시작 (CPI $1.84) → 리뷰/평점 확보 → 미국 확장
2. ASA Basic으로 시작 ($100~$500/월) → 전환 데이터 수집
3. 롱테일 키워드에 ASA Advanced 집중 → "photo cleaner" 대신 "swipe photo cleanup" 등
4. 경쟁사 키워드 입찰 (Competitor 캠페인) → Cleanup, SwipeWipe 검색 시 노출

**Codeway(Cleanup 개발사) 참고:**
- ASA 월 지출 800% 확대 (가장 예측 가능한 채널로 평가)
- Meta(Facebook/Instagram)가 핵심 UA 채널: 32% 더 많은 구독, 19% 낮은 CPA

### 출처
- [AppTweak Apple Ads Benchmarks 2025](https://www.apptweak.com/en/aso-blog/apple-ads-benchmarks)
- [Admiral Media - Apple Search Ads Benchmarks](https://admiral.media/apple-search-ads-benchmarks/)
- [Business of Apps - Apple Search Ads Costs 2026](https://www.businessofapps.com/marketplace/apple-search-ads/research/apple-search-ads-costs/)
- [SplitMetrics - Apple Ads Benchmarks 2025](https://splitmetrics.com/apple-ads-search-results-benchmarks-2025/)
- [MobileAction - Codeway ASA 800%](https://www.mobileaction.co/success-story/codeway/)

---

### 9-5. 숏폼 영상(릴스/TikTok) 마케팅

#### 앱 마케팅에서 릴스/틱톡 효과
- 마이크로 인플루언서(15K 미만 팔로워) 평균 참여율: 17.96% (대형 인플루언서 대비 월등)
- 2026년 트렌드: 넓은 바이럴보다 특정 커뮤니티 타겟 "마이크로 바이럴" 전략이 더 효과적

#### SwipeWipe 바이럴 사례

- 2021년 출시, TikTok에서 Gen Z 사이에 바이럴
- MAU가 2개월 만에 15,000 → 300,000 (20배 성장)
- 현재 월 100만+ MAU, 월 매출 ~$1M, 40만 다운로드
- 2024년 6월 프랑스 MWM에 최대 규모 인수 (TechCrunch)
- 성공 공식: 오가닉 TikTok 바이럴 → 유료 광고 캠페인 후속

#### SweepPic용 숏폼 콘텐츠 전략

| 콘텐츠 유형 | 플랫폼 적합도 | 바이럴 잠재력 |
|------------|-------------|-------------|
| "전/후" 저장공간 비교 (nGB 확보) | TikTok/릴스 | 매우 높음 |
| "1분 안에 100장 정리" 타임랩스 | TikTok/릴스/Shorts | 높음 |
| "스와이프로 사진 정리" 시연 | TikTok | 높음 (SwipeWipe 성공 공식) |
| "iPhone 저장공간 부족 해결법" | 릴스/YouTube | 높음 |

### 출처
- [TechCrunch - SwipeWipe MWM Acquisition](https://techcrunch.com/2024/06/25/gen-z-photos-app-swipewipe-sells-to-french-publisher-mwm-in-its-largest-acquisition-to-date/)
- [Marketing Dive - Instagram vs TikTok UA](https://www.marketingdive.com/news/instagram-beats-tiktok-video-based-user-acquisition-zoomd-survey/715598/)

---

### 9-6. 한국 시장 먼저 진입하는 이유

#### 한국 앱 시장 규모 — 세계 4위

| 항목 | 수치 | 출처 |
|------|------|------|
| 2023년 소비자 지출 | $7.86B (약 11.4조 원) | data.ai 2024 |
| 세계 순위 | 4위 (중국 > 미국 > 일본 > 한국) | data.ai 2024 |
| 전년 대비 성장률 | +25% | data.ai 2024 |
| 2025년 시장 규모 전망 | $10B (약 14.5조 원) | Business of Apps |
| 스마트폰 사용률 | 성인 99% | 통계 |
| 사진 저장량 | 평균 1,400장+ (글로벌 952장의 1.5배, 세계 1위) | 기존 리서치 |

#### 한국 vs 미국 CPI 비교

| 시장 | CPI (사진 정리/유틸리티) | 비고 |
|------|------------------------|------|
| 한국 | $1.0~$2.8 (ASA 기준 $1.84) | 미국 대비 3~5배 저렴 |
| 미국 | $2.37~$4.06 | CPI 최고가 시장 |
| 일본 | ~$2.57 | 한국과 유사하거나 약간 높음 |

핵심: 한국/일본은 미국 대비 CPI가 3~5배 저렴하면서 LTV(생애가치)는 비슷하거나 더 높음

#### 한국에서 검증 후 글로벌 확장한 앱 사례

| 앱 | 한국 출시 | 글로벌 성과 | 확장 경로 |
|---|---------|-----------|---------|
| SNOW (네이버) | 2015.09 | 글로벌 21.5억 다운로드 | 한국 → 일본 → 대만 → 동남아 → 글로벌 |
| LINE (네이버) | 2011.08 | 1억 명 돌파 (1년 7개월) | 한국/일본 → 대만 → 태국 → 글로벌 |
| 비트윈 (VCNC) | 2012 | 글로벌 3,500만 다운로드 | 한국 → 일본/싱가포르/대만/태국 |
| 토스 | 2015 | MAU 2,480만, 유니콘 | 한국 검증 후 해외 확장 추진 중 |

한국이 테스트 마켓으로 적합한 이유:
- 규모가 작지만 문화적 영향력이 큼 (K-wave 효과)
- 저비용 고효율 검증: 미국 대비 CPI 3~5배 저렴, 사용자 품질 유사
- Shake Shack 사례: 아시아 첫 매장으로 서울 선택 (2016) — 저리스크 테스트 마켓

### 출처
- [South Korea App Market Statistics - Business of Apps](https://www.businessofapps.com/data/south-korea-app-market/)
- [CPI 2025 Ultimate Report - Mapendo](https://mapendo.co/blog/cost-per-install-2025-the-ultimate-report-to-grow-your-app-worldwide)
- [Why Korean Apps Winning Over Global Giants - App Growth Summit](https://appgrowthsummit.com/why-are-korean-apps-winning-over-global-giants/)
- [Digital Marketing in Korea - iCrossBorder](https://www.icrossborderjapan.com/en/blog/asian-marketing/marketing-in-korea-shortcut-asia/)
- [SNOW 일본 1위 석권 - 모비인사이드](https://brunch.co.kr/@mobiinside/264)

---

### 9-7. iOS 먼저 → Android 확장 전략

#### iOS vs Android ARPU (2025~2026)

| 지표 | iOS | Android | 배수 |
|------|-----|---------|------|
| 월간 앱 지출 | $10.40 | $1.40 | 7.4배 |
| 앱당 평균 지출 | $1.64 | $0.43 | 3.8배 |
| 구독 매출 비중 | 73% | 27% | 2.7배 |
| 전체 소비자 지출 점유 | 68.6% | 31.4% | 2.2배 |

출처: Adapty 2025, Sensor Tower 2026 Forecast, DemandSage 2026

#### iOS 먼저 출시하는 근거
1. MVP 31% 빠른 출시: iOS는 기기 파편화 적어 빌드/테스트/QA 빠름
2. 매출 효율: App Store가 전체 모바일 앱 매출의 65~70% 차지
3. 고가치 사용자: iOS 사용자가 구독, IAP, 프로 업그레이드 전환율 높음
4. 전략적 순서: iOS에서 PMF 검증 → 투자 유치 → Android 확장이 효율적

#### Storage Cleaner 카테고리 iOS/Android 매출 비율

| 카테고리 | iOS 매출 비중 | Android 매출 비중 | 출처 |
|---------|-------------|------------------|------|
| Storage Cleaner 앱 | 95% 이상 | 5% 미만 | Appfigures 2025 |
| Photo & Video (전체) | ~70% | ~30% | Sensor Tower |
| 앱 전체 | ~68.6% | ~31.4% | 2025 글로벌 |

Storage Cleaner가 iOS 편중인 이유:
- Android OEM(삼성 Device Care, Xiaomi MIUI Cleaner, Files by Google 등)이 자체 클리너 기능 탑재
- iOS는 기본 중복 앨범(iOS 16+)만 제공, 유사사진/흐린사진/자동 정리 기능 없음

#### Android 확장 시 기대 효과

| 시나리오 | 설치 증가 | 매출 증가 |
|---------|---------|---------|
| 보수적 (구독 중심) | +120~180% | +30~70% |
| 기준 (구독+광고 혼합) | +180~260% | +50~110% |
| 공격적 (광고/볼륨 중심) | +260~380% | +80~150% |

출처: 260313Research-growth.md

### 출처
- [iPhone vs Android Statistics 2026 - DemandSage](https://www.demandsage.com/iphone-vs-android-users/)
- [iPhone vs Android Revenue Statistics 2026 - Backlinko](https://backlinko.com/iphone-vs-android-statistics)
- [Why Startups Prioritize iOS - CustomerThink](https://customerthink.com/why-startups-are-prioritizing-ios-before-android-a-business-perspective/)
- [Appfigures - Storage Cleaner Apps](https://appfigures.com/resources/insights/20250606?f=1)
- [Adapty - iOS vs Android Revenue 2025](https://adapty.io/)

---

### 9-8. 글로벌 확장 순서

| 순서 | 시장 | 근거 |
|------|------|------|
| 1단계: 한국 | CPI 저렴($1.84), 사진 저장량 세계 1위, PMF 검증 최적 | 저비용으로 제품 검증 + 리텐션/전환율 데이터 확보 |
| 2단계: 일본 | 앱 시장 세계 3위($16.5B), 한국과 문화적 유사성, CPI 합리적($2.57) | K-wave 영향권, iOS 점유율 높음(~65%), 높은 ARPU |
| 3단계: 영어권 (미국/영국/호주) | 앱 시장 세계 1~2위, 최대 매출 풀 | CPI 높지만 LTV도 높음, 글로벌 스케일 |
| 4단계: Android 확장 | 설치 볼륨 3.8배 확대 | iOS에서 검증된 모델을 Android에 이식 |

#### 국가별 앱 시장 규모

| 국가 | 전체 앱 소비자 지출 (2024~2025) | Photo & Video 성장률 | 비고 |
|------|-------------------------------|---------------------|------|
| 미국 | ~$45B+ (1위) | YoY +40% (Q1 2025) | 최대 시장, CPI 최고가 |
| 일본 | ~$16.5B (3위) | AI 사진 편집 급성장 | iOS 점유율 65%+, ARPU 최상위 |
| 한국 | ~$10B (4위) | 사진/비디오 성장 카테고리 | 사진 저장량 세계 1위, CPI 최저 |

### 출처
- [South Korea App Market Statistics - Business of Apps](https://www.businessofapps.com/data/south-korea-app-market/)
- [Japan App Market Trends 2025 - Adjust](https://www.adjust.com/blog/japan-app-trends-2025/)
- [Q1 2025 Digital Market Index - Sensor Tower](https://sensortower.com/blog/q1-2025-digital-market-index)

---

## 10. 그래프 삽입용 데이터

> 조사일: 2026-03-17
> 목적: 사업계획서 시각 자료(그래프) 삽입 근거

### 10-1. 전 세계 사진 촬영량 추이 (Photutorial)

| 연도 | 촬영량 (조 장) |
|------|--------------|
| 2020 | 1.12 |
| 2021 | 1.20 |
| 2022 | 1.37 |
| 2023 | 1.56 |
| 2024 | 1.81 |
| 2025 | 2.10 |

- 출처: Photutorial, "Photos Statistics" (2025) — https://photutorial.com/photos-statistics/
- 6개년 연속 데이터 확보, 무료 출처
- 메시지: 촬영량 급증 → 정리 수요 지속 확대

### 10-2. Photo & Video 앱 시장 규모 추이 (Statista)

| 연도 | 시장 규모 | 출처 |
|------|----------|------|
| 2019 | $7.5B | Statista |
| 2021 | $9.5B | Statista |
| 2022 | $10.5B | Statista |
| 2023 | $12.0B | Statista |
| 2025 | $14.7B | Statista |

- 2020, 2024 데이터 누락 (동일 출처 연속 5개년 불가)
- Statista 유료 구독 $1,399/월 필요
- 다른 무료 출처에서 연속 데이터 미확보

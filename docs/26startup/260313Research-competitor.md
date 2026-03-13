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

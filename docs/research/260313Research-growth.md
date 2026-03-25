# SweepPic 비선형 성장 요인 리서치 (매출 시뮬레이션 보강)

> 조사일: 2026-03-13  
> 기준 문서: `docs/26startup/260309Research-sales.md`  
> 목적: 광고비 기반 선형 성장 모델에 **랭킹 오가닉/바이럴/플랫폼 확장/피처드** 비선형 계수 반영

---

## 1) 앱스토어 카테고리 랭킹별 오가닉 유입량 벤치마크

### 1-1. 공개 원천 수치 (직접 인용 가능)

| 구분 | 수치 | 해석 | 출처 |
|---|---:|---|---|
| US iOS 비게임 Top10 진입(2019) | 일 49,000 다운로드(중앙값) | 상위권 랭킹은 매우 높은 임계치 필요 | https://sensortower.com/blog/app-downloads-to-number-one |
| JP iOS 비게임 Top10 진입(2019) | 일 14,000 다운로드(중앙값) | 일본은 미국 대비 약 28.6% 수준 임계치 | https://sensortower.com/blog/app-downloads-to-number-one |
| US iOS Photo & Video #10(2019) | 일 16,000+ 다운로드(중앙값) | Photo & Video는 카테고리 난이도 최상위권 | https://sensortower.com/blog/app-downloads-to-number-one |
| iOS 국가별 전체 다운로드(2025) | 미국 6.8B, 일본 1.4B | 국가별 랭킹 난이도 보정용 볼륨 지표 | https://www.apptweak.com/en/reports/app-downloads-by-country |
| App Store 글로벌 구조(2025) | iOS 총 다운로드 약 30.2B(=미국 6.8B/22.5%) | 글로벌 추정 스케일 기준 | https://www.apptweak.com/en/reports/app-downloads-by-country |
| 카테고리 시장 규모(2025, 양대스토어) | Photo & Video 3.5B, Tools 3.9B 다운로드 | Photo/Utilities(도구) 모두 대규모 카테고리 | https://www.apptweak.com/en/reports/mobile-market-report-2025 |
| 랭킹 곡선 기준점(미국, 과거치) | Top200 6,720 / Top100 11,662 / Top10 68,133 | 상위권으로 갈수록 급경사(파워커브) | https://www.pocketgamer.biz/how-many-downloads-does-it-take-to-reach-the-us-top-25/ |
| 국가별 Photo & Video 차트 확인용 | US/KR/JP 카테고리 랭킹 스냅샷 제공 | 국가별 차트 포지션 모니터링용 | https://appfigures.com/top-apps/ios-app-store/united-states/photo-and-video |

### 1-2. SweepPic용 실무 추정치 (Photo & Video, iOS)

> 주의: Top 200/100/50/10을 국가별로 동시에 공개하는 무료 원천이 제한적이어서, 아래는 **공개 앵커 + 파워커브 추정치**입니다.  
> 추정식: `D(rank)=a*rank^-0.76` (랭킹 상위로 갈수록 가파르게 증가하는 비선형 곡선)

| 시장 | Top 200 (일) | Top 100 (일) | Top 50 (일) | Top 10 (일) | Top 200 (월) | Top 100 (월) | Top 50 (월) | Top 10 (월) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| 미국 (US) | 1,818 | 3,078 | 5,238 | 18,000 | 54,540 | 92,340 | 157,140 | 540,000 |
| 일본 (JP) | 525 | 889 | 1,513 | 5,200 | 15,750 | 26,670 | 45,390 | 156,000 |
| 한국 (KR, 추정) | 343 | 581 | 989 | 3,400 | 10,290 | 17,430 | 29,670 | 102,000 |
| 글로벌(가중 평균 추정) | 859 | 1,454 | 2,474 | 8,500 | 25,770 | 43,620 | 74,220 | 255,000 |

### 1-3. 랭킹 상승 시 오가닉 증가 곡선 (선형 vs 비선형)

| 구간 | 선형 가정(동일 증가) | 비선형 추정(권장) |
|---|---:|---:|
| Top200 → Top100 | +50% | +69% |
| Top100 → Top50 | +50% | +70% |
| Top50 → Top10 | +400%/4구간 평균 +100% | +244% (단일 점프) |

핵심: **Top50 이후가 급경사**라서, 랭킹이 상위권에 들어갈수록 오가닉이 선형이 아니라 급증(볼록 곡선)합니다.

### 1-4. Photo & Video vs Utilities 카테고리 적용 메모

- Photo & Video는 상위 앱(YouTube, Instagram, CapCut 등) 집중도가 높아 **Top10 진입 임계치가 큼**.
- Utilities(도구/정리)는 검색 기반 유입 비중이 높아 중하위 랭킹 구간에서 효율이 좋고, 상위권 급등폭은 Photo & Video 대비 완만한 편.
- 실무 적용 권장: Utilities는 위 표 대비 **0.7~0.85배 임계치**로 보수 추정 후 실제 ASA/ASO 데이터로 보정.

---

## 2) 바이럴 계수 (K-coefficient) 벤치마크

### 2-1. 정의 및 공통 벤치마크

| 항목 | 수치 | 출처 |
|---|---:|---|
| K 정의 | `K = i(유저당 초대한 수) × c(초대 전환율)` | https://amplitude.com/en-us/blog/actionable-pirate-metrics |
| K>1 | 지수 성장(드묾) | https://amplitude.com/en-us/blog/actionable-pirate-metrics |
| 실무 기준 | K 0.15~0.25(좋음), 0.4(매우 좋음), 0.7(상위권) | https://amplitude.com/en-us/blog/actionable-pirate-metrics |

### 2-2. Branch 리퍼럴 퍼널 벤치마크

| 지표 | 수치 | 해석 | 출처 |
|---|---:|---|---|
| 공유 완료율(인센티브형) | ~70% | 보상형 루프에서 공유 단계 이탈이 크게 줄어듦 | https://www.branch.io/resources/blog/mobile-sharing-and-referral-feature-benchmarks-from-branch/ |
| 공유 완료율(비인센티브형) | ~30% | 일반 공유 UX만으론 전파력 제한 | 동일 |
| 클릭→설치(CTI) 평균 | ~15% (분포 피크 ~8%) | 루프 후반 전환 효율의 현실치 | 동일 |
| 추천 유입 가치 | 전환율/RPU가 타 채널 대비 200~300% | 추천 유저 질(quality)이 높음 | 동일 |
| 추천 매출 기여 | 20% 기업이 총매출 10%+를 추천에서 획득 | 루프 최적화 시 매출 기여도 큼 | 동일 |

### 2-3. Photo & Video / Utilities 카테고리 K 범위 (SweepPic 적용 추정)

> 아래 범위는 위 공개 벤치마크(Amplitude/Branch)와 카테고리 사용성 차이를 결합한 **운영 추정치**입니다.

| 카테고리 | 베이스 K (무보상/약한 루프) | 강화 K (보상/공유동선 최적화) | 상위 사례 가능 구간 |
|---|---:|---:|---:|
| Photo & Video | 0.12 ~ 0.30 | 0.30 ~ 0.55 | 0.55 ~ 0.80 |
| Utilities (정리/최적화) | 0.08 ~ 0.22 | 0.20 ~ 0.40 | 0.40 ~ 0.70 |

### 2-4. 사진 정리 앱에서 실제 바이럴 경로

| 경로 | Photo & Video 적합도 | Utilities 적합도 | 구현 포인트 |
|---|---|---|---|
| 전/후 비교 공유(용량 절감 결과) | 높음 | 매우 높음 | “nGB 확보” 카드 자동 생성 |
| 정리 리포트 공유(SNS/메신저) | 높음 | 높음 | 주간 리포트 + 원탭 공유 |
| 친구 추천 코드(양면 보상) | 중간 | 높음 | 2-sided incentive 적용 |
| 가족 앨범/공유 앨범 연계 | 매우 높음 | 중간 | iCloud 공유 컨텍스트 연계 |

---

## 3) iOS에서 Android 확장 시 매출/설치 증가 효과

### 3-1. 플랫폼 구조 데이터

| 지표 | 수치 | 의미 | 출처 |
|---|---:|---|---|
| 모바일 OS 점유율(전세계, 2026-02) | Android 68.24%, iOS 31.48% | 설치 풀은 Android가 약 2.17배 | https://gs.statcounter.com/os-market-share/mobile/worldwide/ |
| 앱 설치량 전망(2026, Sensor Tower) | App Store 37.8B vs Play 143.1B | 설치 볼륨은 Play가 약 3.8배 | https://sensortower.com/blog/sensor-tower-app-market-forecast-2026 |
| 앱 소비자지출 전망(2026, Sensor Tower) | App Store $161B vs Play $72B | 매출은 App Store가 약 2.24배 | https://sensortower.com/blog/sensor-tower-app-market-forecast-2026 |
| 사용자 지출(Adapty) | 연간 iOS $140 vs Android $69 | ARPU/지불의사는 iOS 우위 | https://adapty.io/blog/iphone-vs-android-users/ |
| 구독 매출 비중(Adapty) | iOS 73% vs Android 27% | 구독앱은 iOS 비중이 특히 큼 | https://adapty.io/blog/iphone-vs-android-users/ |

### 3-2. iOS 전용 → Android 확장 효과 (Photo & Video/Utilities 시뮬레이션)

> SweepPic(구독+광고 혼합) 기준 추정.  
> 설치 증가는 크고, 매출 증가는 ARPU 차이로 설치 증가폭보다 작게 반영.

| 시나리오 | Android 출시 후 설치 증가 | Android 출시 후 매출 증가 | 전제 |
|---|---:|---:|---|
| 보수적(구독 중심) | +120% ~ +180% | +30% ~ +70% | iOS 결제 우위, Android 결제 전환 낮음 |
| 기준(구독+광고 혼합) | +180% ~ +260% | +50% ~ +110% | 광고수익으로 Android 볼륨 일부 상쇄 |
| 공격적(광고/볼륨 중심) | +260% ~ +380% | +80% ~ +150% | 대규모 설치를 광고/제휴로 수익화 |

### 3-3. “Android 72%인데 왜 매출은 낮은가?” 구조 설명

- `72%`는 2025년 평균치에 가까운 설명값이고, **최신 공개치(2026-02)는 Android 68.24%, iOS 31.48%**입니다.  
  (출처: https://gs.statcounter.com/os-market-share/mobile/worldwide/)
- 설치/기기 점유율은 여전히 Android 우위(대중 시장, 신흥국 중심).
- 결제 ARPU, 구독 전환, 프리미엄 지불은 iOS 우위(미국/일본 등 고소득 시장 집중).
- 따라서 **Android 확장은 CAC 완화와 규모 확장에 유리**, **iOS는 매출 효율(ARPU/LTV)에 유리**한 이중 구조.

### 3-4. 카테고리 특화 시사점

- Photo & Video: 생성/편집 도구는 Android에서 대량 설치, iOS에서 결제효율이 높아 듀얼스토어 최적화가 유리.
- Utilities: 정리/최적화 앱은 광고+구독 혼합이 쉬워 Android 확장 시 총수익이 빠르게 증가 가능.

---

## 4) 앱스토어 피처드(Apple Editorial Feature) 효과

### 4-1. 다운로드 증가 배수 벤치마크

| 피처드 형태 | 다운로드 증가율 | 배수 환산 | 측정 기간 | 출처 |
|---|---:|---:|---|---|
| Game of the Day | +802% | 9.02x | 피처드 전 주 대비 후 1주 | https://techcrunch.com/2018/04/20/ios-11s-new-app-store-boosts-downloads-by-800-for-featured-apps/ |
| App of the Day | +685% | 7.85x | 동일 | 동일 |
| App Store Stories | +222% | 3.22x | 동일 | 동일 |
| App Lists | +240% | 3.40x | 동일 | 동일 |
| AppTweak 관측 예시 | +1633% | 17.33x | 개별 스토리 사례 | https://www.apptweak.com/en/aso-blog/get-advanced-insights-about-your-app-s-featurings |

### 4-2. 피처드 효과 지속 기간

| 구간 | 일반 패턴(벤치마크 해석) |
|---|---|
| D0~D1 | 가장 큰 스파이크(노출 집중) |
| D2~D7 | 고점 대비 완만한 하향, 그러나 베이스 대비 높은 유지 |
| D8+ | 카테고리/브랜드력에 따라 베이스 회귀 or 잔존 상승 |

### 4-3. Apple 공식 선정 조건/기준

| 항목 | Apple Developer 공식 내용 | 출처 |
|---|---|---|
| 후보 제출 | App Store Connect의 Featuring Nominations로 제출 | https://developer.apple.com/app-store/getting-featured/ |
| 리드타임 | 최소 2주 전, 넓은 노출 고려 시 최대 3개월 전 권장 | 동일 |
| 고려 요소 | UX, UI, 혁신성, 독창성, 접근성, 로컬라이제이션, 제품페이지 품질(스크린샷/평점/리뷰) | 동일 |
| 에셋 요청 | 선정 검토 시 프로모셔널 아트워크 제출 요청 가능 | 동일 |

### 4-4. 실무 적용 포인트 (SweepPic)

- 피처드가 붙는 주는 UA를 줄이고(오가닉 최대화), 피처드 종료 후 리타겟팅/ASA 재가동.
- 피처드용 스크린샷/앱 프리뷰를 “정리 전후 성과” 중심으로 별도 제작.
- Today 탭/스토리형 노출을 목표로 기능 업데이트 시점을 Apple nomination 일정(2주~3개월)과 동기화.

---

## 시뮬레이션 반영용 요약 파라미터

| 파라미터 | 보수 | 기준 | 공격 |
|---|---:|---:|---:|
| 랭킹 오가닉 탄력(Top50→Top10) | 1.8x | 2.4x | 3.0x |
| 바이럴 K (Photo/Utilities 혼합) | 0.12 | 0.28 | 0.45 |
| Android 확장 설치 배수 | 2.2x | 2.8x | 3.8x |
| Android 확장 매출 배수 | 1.3x | 1.7x | 2.5x |
| 피처드 이벤트 배수(D0~D7) | 3.0x | 7.0x | 10.0x |

---

## 참고: 출처 신뢰도 메모

- `직접 수치(높음)`: Sensor Tower, AppTweak, Branch, Amplitude, Statcounter, Apple Developer.
- `운영 추정(중간)`: Top200/100/50/10 국가별 상세치, 카테고리별 K 범위, SweepPic 시나리오 배수.
- 추정치는 실제 ASA/ASO/리퍼럴 로그가 쌓이면 월 단위로 재보정 권장.

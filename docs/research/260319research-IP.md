# 사진 정리 앱 IP(지식재산권) 조사 보고서

> 조사일: 2026-03-19
> 조사 범위: 미국 중심, 경쟁사 IP 현황 + 앱 IP 출원의 실질적 가치

---

## Part 1. 경쟁사 IP 현황 (미국 중심)

### 1. 상표(Trademark)

MacPaw만 적극적, 나머지는 미등록 상태.

| 경쟁사 | USPTO 상표 | 비고 |
|--------|-----------|------|
| **MacPaw** (Gemini Photos) | **36건** 등록/출원 | Class 9+42, 제품별 개별 출원. 법무 대리인 보유 |
| Slidebox | 미확인 | 앱스토어 브랜드만 운영 |
| Flic | 미확인 | "FLIC" 명칭 다른 회사와 충돌 가능 |
| Cleen | 미확인 | 개발사 변경 이력, 브랜드 관리 미비 |
| Smart Cleaner | 미확인 | 설명적 명칭으로 등록 자체 어려움 |
| Gallery Doctor | 미확인 | 설명적 명칭 |

**MacPaw 상표 전략 상세:**
- 이중 클래스 출원: Class 9(다운로드 소프트웨어) + Class 42(SaaS)
- 상품 설명에 "removing duplicate files, identifying and removing blurred or similar images" 명시
- MACPAW 상표 2011년 등록, 2020년 갱신 완료
- 제품별 개별 출원 (CleanMyMac, Gemini, ClearVPN, Encrypto 등)

**Nice Classification (사진 정리 앱 해당 분류):**

| Nice Class | 적용 범위 | 해당 여부 |
|------------|----------|----------|
| **Class 9** | 다운로드 가능한 소프트웨어, 모바일 앱 | **필수** |
| **Class 42** | SaaS, 클라우드 기반 소프트웨어 서비스 | **권장** |
| Class 35 | 광고, 사업 관리 | 앱 내 광고 운영 시 고려 |

**"SweepPic"은 USPTO에 유사 상표가 없어 등록 가능성이 높음.**

**참고 자료:**
- [MacPaw Trademarks - USPTO Report](https://uspto.report/company/Macpaw-Inc)
- [MacPaw Trademarks - Trademarkia](https://www.trademarkia.com/owners/macpaw-inc)
- [Software Trademark Guide - JPG Legal](https://jpglegal.com/software-trademark-guide-classes-and-specimens/)
- [Trademark Classes for Mobile Apps - Trademark Factory](https://trademarkfactory.com/blog/trademark-classes-explained-for-mobile-apps/)

---

### 2. 디자인 특허(Design Patent)

**사진 정리 앱 경쟁사 중 디자인 특허 출원 업체는 없음.**

| 경쟁사 | 디자인 특허 | 비고 |
|--------|-----------|------|
| Slidebox | 미출원 추정 | Tinder 스타일 스와이프 UI 사용하나 특허 없음 |
| Gemini Photos (MacPaw) | 미출원 | 유틸리티 특허(US10706130)만 보유 |
| Cleanup | 미출원 추정 | 소규모 개발사 |
| Flic | 미출원 추정 | 좌/우 스와이프 UI 사용 |
| Cleen | 미출원 추정 | 우측 유지/좌측 삭제 UI |
| Smart Cleaner | 미출원 추정 | 카테고리별 분류 UI |

**스와이프 UI 관련 주요 특허 보유자:**

| 특허권자 | 특허 | 핵심 내용 |
|---------|------|----------|
| **Tinder/Match Group** | USD798,314S1 (디자인) | 카드 스택 좌/우 스와이프 시각적 디자인. 만료 2032년 |
| **Tinder/Match Group** | US9,733,811 (유틸리티) | 스와이프 매칭 시스템. "양방향 매칭"에 한정 |
| **Apple** | USD604,305S1 | 화면 아이콘 레이아웃 GUI (Samsung 소송 $5.33억) |
| **MemoryWeb** | US9,552,376 외 3건 | 위치/인물별 사진 정리 인터페이스. 2021년 Apple 소송 |

**2026년 3월 USPTO 규정 변경 (중요):**
- 2026.03.12 GUI 디자인 특허 가이던스 완화
- 디스플레이 패널 도시 요건 제거 (화면 그림 선택사항)
- VR/AR/홀로그램까지 보호 대상 확대
- GUI 디자인 특허 등록이 한층 용이해짐

**SweepPic 침해 리스크: 낮음**
- "위로 스와이프 삭제"는 Tinder의 좌/우 스와이프와 시각적으로 구별
- Apple의 swipe-to-delete는 업계 표준으로 확산, 특정 특허로 보호 어려움
- 경쟁사 중 관련 디자인 특허 보유자 없음

**참고 자료:**
- [Tinder Design Patent USD798314S1](https://patents.google.com/patent/USD798314)
- [USPTO 2026 GUI Design Patent Guidance](https://www.federalregister.gov/documents/2026/03/13/2026-04987/supplemental-guidance-for-examination-of-design-patent-applications-related-to-computer-generated)
- [MemoryWeb Sues Apple](https://appleinsider.com/articles/21/05/26/memoryweb-sues-apple-over-photos-app-places-and-people-tech)

---

### 3. 지식재산권(저작권, 영업비밀 등)

**대부분의 경쟁사는 저작권 자동 보호 + 영업비밀에 의존.**

**MacPaw:**
- 특허 11건 보유 (주로 소프트웨어 활성화/라이선스 추적)
- 핵심 중복 탐지 알고리즘(해싱, ML 유사도 분석)은 **영업비밀로 보호** (특허 공개 안 함)
- GitHub에 130개 공개 저장소 운영, 핵심 상용 코드는 비공개
- 오픈소스는 주로 MIT 라이선스 사용

**기타 경쟁사:**
- Slidebox, Flic, Smart Cleaner 등: 저작권 자동 보호 + App Store 이용약관에 의존
- 사진 정리 앱 특화 IP 소송 사례 거의 없음

**소송/분쟁 관련:**
- Tinder vs Bumble (2018): 스와이프 특허·상표·트레이드 드레스 침해 주장 → 합의 종결
- Apple App Review Guidelines (2025.11): 카피캣 앱 단속 강화. 아이콘/브랜딩/제품명 무단 사용 명시적 금지

**참고 자료:**
- [MacPaw Patents - Justia](https://patents.justia.com/assignee/macpaw-inc)
- [Match vs Bumble - Harvard JOLT](https://jolt.law.harvard.edu/digest/match-group-tinder-v-bumble-online-dating-company-which-owns-tinder-sues-dating-app-founders-by-tinders-co-founders)
- [Apple App Review Copycat Crackdown - 9to5Mac](https://9to5mac.com/2025/11/13/apple-tightens-app-review-guidelines-to-crack-down-on-copycat-apps/)

---

### 4. 유틸리티 특허(Utility Patent)

**대형 기업이 핵심 기술 특허 보유. SweepPic 직접 리스크는 낮음.**

#### 4-1. 유사/중복 사진 탐지

| 특허 번호 | 특허권자 | 출원일 | 핵심 내용 |
|-----------|---------|--------|-----------|
| US7801893B2 | IAC Search and Media | 2005 | 웨이블릿 변환 기반 이미지 시그니처, 유사 클러스터링 |
| US20170046595A1 | **Dropbox** | 2016 | 이미지 핑거프린트 기반 중복/유사 탐지 |
| US8527469B2 | (미상) | 2012 | 디지털 사진 자동 중복 탐지 |
| WO2021187776A1 | (미상) | 2021 | 코사인 거리 기반 피처 벡터 유사도 그룹핑 |

- 대부분 2005~2016년 출원으로 일부 만료 접근 중
- SweepPic이 Vision Framework 기반 `VNFeaturePrintObservation` 사용 시 기존 특허와 구별됨

#### 4-2. 스와이프 제스처 삭제

| 특허 번호 | 특허권자 | 핵심 내용 |
|-----------|---------|-----------|
| US9733811B2 | **Tinder/Match Group** | 카드 스택 스와이프 + **양방향 매칭 시스템**에 한정 |
| US20140331175A1 | Barnes & Noble | 터치 디바이스 스와이프 삭제 확인 |
| US8046721B2 | **Apple** | 슬라이드-투-언락 (유럽 무효 판결) |

- **Google Photos가 2025년 Tinder 스타일 스와이프 정리 UI 도입 중** → 업계가 특허 리스크 없다고 판단
- SwipeWipe, Slidebox, Swipy 등 다수 앱이 이미 동일 기능 제공 중
- SweepPic의 "위로 스와이프 삭제"는 침해 리스크 **극히 낮음**

#### 4-3. 얼굴 인식 분류

| 특허 번호 | 특허권자 | 핵심 내용 |
|-----------|---------|-----------|
| US9639740B2 | Applied Recognition Corp | 얼굴 좌표 탐지, PCA 기반 시그니처 |
| US8189880B2 | (미상) | 얼굴 유사도 기반 클러스터링 사진 주석 |
| US11087121 | (미상) | 모바일 고정밀 얼굴 인식 |

- SweepPic이 Apple Vision Framework API 사용 시 직접적 침해 리스크 없음

#### 4-4. 사진 품질 자동 평가

| 특허 번호 | 특허권자 | 만료일 | 핵심 내용 |
|-----------|---------|--------|-----------|
| US9412043B2 | **EyeEm** | ~2034 | 슈퍼픽셀 기반 다중 스케일 피처 + ML 미학 점수 |
| US10410108B2 | **EyeEm** | **2037** | 신경망 기반 개인화 미학 점수 |
| US9734567B2 | (미상) | - | 딥 뉴럴 네트워크 이미지 품질 평가 |

- EyeEm이 미학 품질 평가 분야 핵심 특허 보유 (2024년 사업 축소/종료 추정)
- SweepPic은 "미학 점수"가 아닌 **기술적 품질 지표**(흐림/노출/노이즈)에 집중하므로 EyeEm 특허와 구별됨

**참고 자료:**
- [Dropbox 중복 이미지 탐지 특허](https://patents.google.com/patent/US20170046595)
- [Tinder 매칭 특허](https://patents.google.com/patent/US9733811B2/en)
- [Google Photos 스와이프 정리 도입 - Android Authority](https://www.androidauthority.com/google-photos-tinder-swipe-left-right-3589872/)
- [EyeEm 미학 점수 특허](https://patents.google.com/patent/US10410108B2/en)
- [EyeEm 특허 목록 - Justia](https://patents.justia.com/assignee/eyeem-mobile-gmbh)

---

## Part 2. 앱 IP 출원의 실질적 의미와 가치

### IP 유형별 실효성

| IP 유형 | 비용 (한국) | 비용 (미국) | 실효성 | 인디 개발자 ROI |
|---------|------------|------------|--------|---------------|
| **상표** | 25~70만 원 | $500~$2,000 | 앱 이름/브랜드 선점 | **매우 높음** |
| **저작권** | 자동 발생 | $65 (등록) | 코드/디자인 복제 방지 | **높음** |
| **디자인 특허** | 100~200만 원 | $3,000~$6,000 | UI 외관만 보호, 기능 카피에 무력 | **낮음** |
| **유틸리티 특허** | 200~500만 원 | $25,000~$45,000 | Alice 판결 후 등록 어려움, 2~5년 소요 | **매우 낮음** |

### 상표 등록 — 실효성: 매우 높음

- 한국은 **선출원주의** — 먼저 출원한 사람이 권리 보유
- App Store에서 유사 이름 앱 침해 신고가 상표 보유 시 훨씬 수월
- 실제 사례: 게임 "The Day Before"가 제3자 상표 주장으로 출시 지연
- 비용: 셀프 출원 약 25만 원 (출원료 4.6만 + 등록료 21만), 대리인 이용 시 60~70만 원
- 2019년 이후 Class 9 출원 시 "downloadable" 또는 "recorded" 명시 필수

### 유틸리티 특허 — Alice 판결의 영향

- 2014년 Alice Corp. v. CLS Bank 판결: "추상적 아이디어를 컴퓨터로 구현"만으로는 특허 부적격
- 2020년 소프트웨어 특허 27건 중 **4건만 적격** 판정
- "스와이프로 사진 삭제" 같은 워크플로우 개선은 "추상적 아이디어"로 거절 가능성 높음
- 총 비용 $25,000~$45,000, 심사 2~5년 → 인디 개발자에게 비현실적

### 디자인 특허 — 제한적 실효성

- UI 외관(아이콘, 레이아웃, UI 흐름)만 보호
- 경쟁자가 색상/버튼/레이아웃만 변경하면 우회 가능
- 2025년 1월 USPTO 수수료 27~76% 인상
- 심사 기간: 1~3년, 허여율 약 84%

### IP 없이 앱을 보호하는 대안

- **저작권 자동 보호**: 코드/UI 에셋은 창작 즉시 자동 보호. Git 히스토리가 증거
- **App Store 정책**: Apple/Google DMCA 테이크다운 절차로 카피캣 제거 가능
- **영업비밀**: MacPaw처럼 핵심 알고리즘을 비공개로 유지
- **NDA**: 외주 개발자/협력사와 비밀유지계약 체결

### 인디 개발자 vs 대기업 IP 전략 차이

| 구분 | 인디 개발자 | 대기업 |
|------|------------|--------|
| 주요 전략 | 상표 + 저작권 중심 | 유틸리티 + 디자인 특허 대량 출원 |
| 연간 IP 예산 | $500~$5,000 | 수백만~수천만 달러 |
| 방어 수단 | NDA, 영업비밀, App Store 신고 | 특허 포트폴리오, 소송 |

### IP가 투자/기업가치에 미치는 영향

- 투자자 실사(Due Diligence)에서 IP 현황은 필수 점검 항목
- 초기 스타트업에서는 특허보다 **상표 등록**이 "브랜드를 진지하게 관리"하는 신호
- 다만 인디 앱 수준에서는 **매출, MAU, 성장률**이 IP보다 훨씬 중요한 평가 요소

### 실제 앱 IP 분쟁 사례

| 사례 | 유형 | 교훈 |
|------|------|------|
| Apple vs Samsung (2011~) | 디자인 특허 | $10억+ 배상. 대기업 간 분쟁 |
| Google vs Oracle (Java) | 저작권 | API fair use 인정. 기능적 유사성에 한계 |
| Peloton vs Echelon (2019) | 복합 IP | 특허+상표+트레이드드레스 복합 공격. 다층 IP 보유 시 협상력 증가 |
| Fntastic "The Day Before" | 상표 | 상표 미등록 → 제3자 주장으로 출시 지연 |

**참고 자료:**
- [Mobile App Trademarks - Stanzione & Associates](https://www.stanzioneiplaw.com/mobile-app-tradesmarks/)
- [IP for Apps - Rapacke Law Group](https://arapackelaw.com/startups/intellectual-property-for-apps/)
- [Software Patents After Alice - Rapacke Law Group](https://arapackelaw.com/patents/softwaremobile-apps/software-patents-after-alice/)
- [Mobile App Patent Cost 2026 - PatentAILab](https://patentailab.com/mobile-app-patent-cost-2026-why-we-spent-38k/)
- [App Store Copyright Infringement - Red Points](https://www.redpoints.com/blog/app-store-copyright-infringement/)
- [IP Due Diligence for Startups - Innovent Law](https://www.innoventlaw.com/ip-due-diligence-for-startups/)

---

## Part 3. SweepPic 권장 IP 전략

### 즉시 실행 (비용: ~30만 원)

1. **"SweepPic" 한국 상표 출원** — 제9류, 특허로(patent.go.kr) 셀프 출원 (~25만 원)
   - 상품 설명 예시: "다운로드 가능한 사진 관리 및 정리용 모바일 애플리케이션 소프트웨어"
2. **저작권 고지 표시** — 앱 내 + App Store 페이지 (무료)

### 출시 전후

3. **미국 상표 출원** — 해외 출시 계획 시 ($350~$550/class)
4. **App Store 모니터링 체계** — 카피캣 앱 발견 시 즉시 DMCA 신고

### 필요시 검토

5. **디자인 특허** — 스와이프 삭제+Undo 결합 UI, 얼굴 인식 줌 뷰어 등 차별화 UI
6. **영업비밀 체계** — 유사 사진 탐지 알고리즘 등 핵심 로직은 NDA + 접근 제한

### 권장하지 않음

- **유틸리티 특허**: 비용 과다($25,000+), Alice 테스트 통과 불확실, 인디 개발자 ROI 극히 낮음

> **결론: 상표 등록은 반드시, 특허는 불필요.** 경쟁사 대부분이 상표조차 등록하지 않은 상황에서 SweepPic이 빠르게 상표를 확보하면 브랜드 보호에서 확실한 우위를 가질 수 있음.

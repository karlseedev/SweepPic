# PIClear BM 명세 — 누락 항목 Gap 분석 리서치

> 작성일: 2026-02-27
> 목적: 260213bm-spec.md 목차에서 빠진 항목을 다양한 소스에서 조사
> 서브에이전트 8개 병렬 실행 결과 원본 취합

---

# Part A: 공식 플랫폼 가이드라인

---

## 1. Apple 공식 BM 가이드라인 조사

---

### 1. App Store Review Guidelines - 비즈니스 관련 섹션 (Section 3)

**공식 URL**: https://developer.apple.com/app-store/review/guidelines/

#### 3.1 Payments (결제)

##### 3.1.1 In-App Purchase (인앱 구매)

IAP가 **필수**인 경우:
- 기능/콘텐츠 잠금 해제 (구독, 인게임 화폐, 게임 레벨, 프리미엄 콘텐츠, 풀버전 언락)
- 디지털 기프트 카드, 인증서, 바우처, 쿠폰

IAP 외 결제 수단 사용이 **금지**된 것들:
- 라이선스 키, AR 마커, QR 코드, 암호화폐

**허용 기능들**:
- **팁(Tipping)**: IAP 화폐를 통해 개발자나 콘텐츠 제공자에게 팁 가능
- **크레딧/화폐**: 구매한 크레딧은 만료 불가, 복원 메커니즘 필수
- **선물(Gifting)**: IAP 아이템을 타인에게 선물 가능 (환불은 원래 구매자에게만)
- **루트박스**: 각 아이템 타입의 확률을 구매 전 공개 필수
- **무료 체험**: 비구독 앱은 Non-Consumable IAP(가격 0단계)으로 무료 체험 제공 가능. "XX-day Trial" 명명 규칙 적용
- **NFT**: 민팅/리스팅/전송 서비스 가능, 단 NFT 소유로 앱 기능 잠금 해제 불가

##### 3.1.1(a) 외부 결제 링크 (Link to Other Purchase Methods)

**StoreKit External Purchase Link Entitlement**:
- 특정 지역(US 포함)에서 대안 결제 수단 링크 허용
- 비교 가격 정보 제공 가능
- **미국 스토어프론트**: 2025년 5월 법원 판결에 따라 Apple 커미션 없이 외부 결제 링크 1개 표시 가능 (현재 0% 커미션, 향후 합리적 수수료 결정 예정)

**Music Streaming Services Entitlement**: 음악 스트리밍 앱 전용, 개발자 웹사이트 링크 포함 가능

##### 3.1.2 Subscriptions (구독)

**기본 요구사항**:
- 최소 구독 기간: **7일**
- 사용자의 모든 기기에서 작동해야 함
- 지속적인 가치를 제공해야 함
- 추가 작업(SNS 포스팅, 연락처 업로드 등) 없이 결제한 것을 제공해야 함

**허용되는 구독 콘텐츠**:
- 새 게임 레벨, 에피소드 콘텐츠, 멀티플레이어 지원
- SaaS, 클라우드 지원, 대규모 미디어 컬렉션 접근
- 소모성 크레딧, 인게임 화폐 포함 가능

**비즈니스 모델 전환 시 주의**:
- 구독 모델로 전환할 때 기존 사용자가 이미 구매한 주요 기능을 제거하면 안 됨

**사기 행위 금지**: 구독 구매를 속이려는 앱은 App Store에서 삭제 및 개발자 추방

**3.1.2(b) 업그레이드/다운그레이드**: 사용자가 실수로 같은 상품의 여러 변형을 구독하지 않도록 해야 함

**3.1.2(c) 구독 정보 공개**: 구독 요청 전 월간 이슈 수, 클라우드 저장 용량, 서비스 유형, 비용 등을 명확히 설명해야 함

##### 3.1.3 기타 결제 방식

- **(a) Reader 앱**: 잡지, 신문, 책, 오디오, 음악, 비디오 - 이전에 구매한 콘텐츠 접근 허용
- **(b) 멀티플랫폼 서비스**: 다른 플랫폼에서 구매한 콘텐츠 접근 가능, 단 앱 내 IAP로도 제공 필수
- **(c) 기업 서비스**: 조직에 직접 판매하는 앱 (직원/학생용). 소비자/개인 판매는 IAP 필수
- **(d) 개인간 서비스**: 실시간 과외, 의료 상담, 부동산 투어 등 - 대안 결제 허용 (1:1만 해당, 1:다수는 IAP 필수)
- **(e) 앱 외 재화/서비스**: 물리적 상품, 앱 외부에서 소비되는 서비스 - Apple Pay, 신용카드 등 사용
- **(f) 무료 독립 앱**: 유료 웹 기반 도구의 무료 동반 앱 (VoIP, 클라우드 스토리지, 이메일 등)
- **(g) 광고 관리 앱**: 광고 캠페인 구매/관리 앱은 IAP 불필요

##### 3.1.5 암호화폐
- 지갑: 조직으로 등록된 개발자만 허용
- 채굴: 온디바이스 채굴 금지, 클라우드 채굴 허용
- 거래소: 적절한 라이선스가 있는 지역에서만 허용
- ICO: 설립된 금융기관만 가능

#### 3.2 기타 비즈니스 모델 이슈

**허용되는 관행**:
- 자체 앱 프로모션, 비영리 모금(승인된 비영리단체), 개인간 금전적 선물(선택적이고 100% 수신자에게 전달)
- 보험 앱: 무료 제공 필수, IAP 사용 불가

**금지되는 관행**:
- 앱 스토어프론트 생성, 광고 사기, 바이너리 옵션 거래 앱
- 개인 대출 앱: APR 36% 상한, 60일 이내 전액 상환 요구 금지
- 사용자에게 앱 평가/리뷰/다른 앱 다운로드 강제 금지

---

### 2. App Store Connect 비즈니스 설정 항목

#### 계약/세금/뱅킹 (Agreements, Tax, and Banking)

**URL**: https://appstoreconnect.apple.com/agreements/

**두 가지 계약 유형**:
- **Free Apps Agreement**: 기본적으로 활성화
- **Paid Apps Agreement**: 별도 설정 필요. 유료 앱, IAP, 구독 판매를 위해 반드시 체결해야 함

**세금 정보 제출** (https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/):
- 미국 기반: W-9 양식
- 미국 외: W-8BEN, W-8BEN-E, 또는 W-8ECI 양식
- 모든 개발자는 Paid Apps Agreement 준수를 위해 미국 세금 양식을 완료해야 함

#### 가격 설정

**URL**: https://developer.apple.com/help/app-store-connect/manage-app-pricing/set-a-price/

- **800개 표준 가격 포인트** (전체 통화 포함)
- 추가 **100개 고가 포인트** 요청 가능 (최대 $10,000)
- 친숙한 국가/지역의 가격을 기준으로 174개 스토어프론트, 43개 통화에 자동 생성
- **가격 인하**: 다음 갱신 시 자동 적용, 사용자 동의 불필요
- **가격 인상**: 사용자 옵트인 필요, Apple이 푸시 알림/이메일/인앱 메시지로 통지

#### 구독 그룹 설정

- 각 구독은 **구독 그룹에 소속** 필수
- **단일 그룹 권장** (실수로 여러 구독 구매 방지)
- 다중 그룹은 사용자가 여러 활성 구독을 필요로 할 때만 (예: 스트리밍 앱의 채널별 구독)
- 그룹 내 서비스 레벨 순위 설정 (최상위 = 가장 프리미엄)
  - **업그레이드**: 즉시 접근 + 원래 구독의 비례 환불
  - **다운그레이드**: 다음 갱신까지 현재 유지, 이후 낮은 가격으로 갱신
  - **크로스그레이드**: 같은 기간 = 즉시, 다른 기간 = 다음 갱신 시

#### 커미션 구조

| 조건 | 커미션 비율 |
|------|------------|
| 표준 (1년차) | **30%** (개발자 70%) |
| 1년 이상 구독 유지 후 | **15%** (개발자 85%) |
| Small Business Program | **15%** (첫해부터) |
| EU 대안 조건 + Small Business | **10%** |

---

### 3. Apple Developer 문서 - 비즈니스/수익화 관련

#### 3-1. 비즈니스 모델 공식 가이드

**URL**: https://developer.apple.com/app-store/business-models/

Apple이 공식 제공하는 **4가지 비즈니스 모델**:

| 모델 | 설명 |
|------|------|
| **Free** | 무료 (광고, 물리적 상품 판매, Reader 앱 등 4가지 변형) |
| **Freemium** | 무료 다운로드 + 선택적 IAP |
| **Paid** | 일회 결제, 모든 기능 접근 |
| **Paymium** | 유료 다운로드 + 추가 IAP |

**IAP 유형**:
| 유형 | 설명 | 예시 |
|------|------|------|
| Consumable | 사용 시 소모, 재구매 가능 | 게임 보석, 라이프 |
| Non-consumable | 1회 구매, 만료 없음 | 사진 필터, 프리미엄 기능 |
| Auto-renewable subscription | 취소까지 자동 갱신 | 클라우드 스토리지, 잡지 |
| Non-renewing subscription | 제한 기간, 수동 갱신 | 시즌 패스, 이벤트 접근 |

#### 3-2. Auto-Renewable Subscriptions 가이드

**URL**: https://developer.apple.com/app-store/subscriptions/

**구독 오퍼 4종류**:

**(1) Introductory Offers (소개 오퍼)**
- **URL**: https://developer.apple.com/documentation/storekit/implementing-introductory-offers-in-your-app
- 대상: 신규 구독자만 (구독 그룹당 1회)
- 유형: 무료 체험 / Pay as you go / 선불

**(2) Promotional Offers (프로모션 오퍼)**
- **URL**: https://developer.apple.com/documentation/storekit/implementing-promotional-offers-in-your-app
- 대상: 기존/이탈 구독자
- 구독당 최대 10개 오퍼, 개발자가 비즈니스 로직 및 자격 제어
- 활용: 취소 구독자 할인, 장기 구독자 무료 월, 비활동 구독자 할인

**(3) Offer Codes (오퍼 코드)**
- 유형: 1회용 코드(18자리 고유) / 커스텀 코드(SPRINGPROMO 형식)
- 상환 방법: 상환 URL, App Store(iOS 14.2+), 앱 내 `offerCodeRedemption`
- 배포 채널: 이메일, 인앱, 인쇄물, 파트너 마케팅, 이벤트, 고객 서비스
- **WWDC 2025 업데이트**: 구독 외에 Consumable, Non-consumable, Non-renewing subscription에도 확장

**(4) Win-Back Offers (윈백 오퍼)**
- iOS 18.0+ 지원 (WWDC 2024에서 도입)
- 대상: 이탈한 이전 구독자
- 노출 위치: App Store 제품 페이지, 에디토리얼 추천, 앱 내 자동 오퍼 시트, Apple 계정 구독 설정, 마케팅 URL
- 오퍼 우선순위 설정 가능, 승인된 구독 이미지 필요

**Billing Grace Period (결제 유예 기간)**:
- 결제 실패 시 구독자 접근 유지
- 옵션: 3일 / 16일 / 28일
- 비자발적 이탈(involuntary churn) 방지에 핵심

**Family Sharing**:
- 최대 5명 가족 구성원과 구독 공유
- App Store Connect에서 활성화 (비활성화 불가)
- `ownershipType` 속성으로 구매자/가족 구성원 구분

**구독 관리 UI**:
- `showManageSubscriptions(in:)` 메서드
- 앱 내에서 업그레이드/다운그레이드/크로스그레이드 가능

**갱신 일자 연장 API**:
- 연간 최대 2회, 각 최대 90일
- 서버 장애, 기술 문제, 이벤트 취소 시 활용

**구독 가입 화면 필수 항목**:
- 구독 이름 및 기간
- 제공 콘텐츠/서비스
- 전체 갱신 가격 (눈에 띄게, 현지화)
- 로그인 또는 구매 복원 옵션
- 이용약관 및 개인정보 보호정책 링크
- 연간 총 가격이 가장 눈에 띄는 요소여야 함

#### 3-3. StoreKit 2

**URL**: https://developer.apple.com/storekit/

StoreKit 2는 Swift의 async/await 패턴 기반의 현대적 IAP 프레임워크:
- `AppTransaction`: 앱 트랜잭션 ID, 원래 플랫폼 포함 (iOS 18.4+)
- `Transaction`: 거래 검증 및 이력
- `RenewalInfo`: 갱신 정보
- `Product`: 상품 정보 로드
- `SubscriptionOfferView` (WWDC 2025 신규): SwiftUI 구독 오퍼 머천다이징 뷰

#### 3-4. App Store Small Business Program

**URL**: https://developer.apple.com/app-store/small-business-program/

- 자격: 전년도 전체 수익금(proceeds) $1M 이하
- **15% 커미션** (표준 30% 대신)
- 연관 개발자 계정(Associated Developer Accounts)의 수익금 합산
- EU 대안 조건 적용 시 **10%**까지 인하 가능
- 다음 해 수익이 다시 $1M 이하로 떨어지면 재자격 획득 가능

---

### 4. Apple의 "Business Planning for App Developers" 리소스

Apple은 "Business Planning for App Developers"라는 **단일 명칭의 문서를 공식적으로 제공하지 않음**. 동일한 역할을 하는 리소스들이 분산:

| 리소스 | URL |
|--------|-----|
| Business Models and Monetization | https://developer.apple.com/app-store/business-models/ |
| Auto-Renewable Subscriptions 가이드 | https://developer.apple.com/app-store/subscriptions/ |
| Freemium Business Model 가이드 | https://developer.apple.com/app-store/freemium-business-model/ |
| App Store 프로모션 도구 | https://developer.apple.com/app-store/promote/ |
| Sales and Trends 분석 | App Store Connect 내 대시보드 |
| App Store Connect 도움말 | https://developer.apple.com/help/app-store-connect/ |

**Sales and Trends** 분석 대시보드에서 제공하는 5가지 페이지:
1. **Subscription Summary**: 전체 성과, 활성 구독, 유지율/전환율, 취소 사유
2. **Subscription State**: 상태별 활성 구독 (표준, 소개, 프로모션, 결제 재시도)
3. **Subscription Event**: 활성화, 전환, 재활성화, 갱신
4. **Subscription Retention**: 연속 기간별 갱신율, 오퍼 전환율
5. **Reports**: 익명화된 상세 데이터 일일 다운로드

---

### 5. WWDC 세션 - 비즈니스 모델/수익화 관련 (2024-2025)

#### WWDC 2024

| 세션 | 내용 | URL |
|------|------|-----|
| **What's new in StoreKit and In-App Purchase** | StoreKit 뷰 컨트롤 스타일, 구독 커스터마이징 API, StoreKit 1 공식 폐기(deprecation) 선언 | https://developer.apple.com/videos/play/wwdc2024/10061/ |
| **Implement App Store Offers** | Win-Back Offers 설정, Mac 오퍼 코드, App Store Connect + StoreKit 최신 기능 활용 | https://developer.apple.com/videos/play/wwdc2024/10110/ |

#### WWDC 2025

| 세션 | 내용 | URL |
|------|------|-----|
| **What's new in StoreKit and In-App Purchase** | `SubscriptionOfferView` (SwiftUI 신규), `appTransactionID` (iOS 18.4+), 오퍼 코드의 모든 IAP 유형 확장, JWS 포맷 프로모션 오퍼 서명, iOS 18.2+ UI 컨텍스트 필수 | https://developer.apple.com/videos/play/wwdc2025/241/ |
| **Dive into App Store server APIs for In-App Purchase** | App Store Server API 업데이트, 환불 V2 엔드포인트 (입력 필드 12개→5개), `GRANT_PRORATED` 비례 환불 옵션, 모든 상품 유형 지원 | https://developer.apple.com/videos/play/wwdc2025/249/ |

#### 이전 중요 세션들

| 세션 | 연도 | URL |
|------|------|-----|
| Meet StoreKit for SwiftUI | WWDC 2023 | https://developer.apple.com/videos/play/wwdc2023/10013/ |
| What's new in StoreKit 2 and StoreKit Testing | WWDC 2023 | https://developer.apple.com/videos/play/wwdc2023/10140/ |
| Meet StoreKit 2 | WWDC 2021 | https://developer.apple.com/videos/play/wwdc2021/10114/ |
| Support customers and handle refunds | WWDC 2021 | https://developer.apple.com/videos/play/wwdc2021/10175/ |

#### WWDC 2025 주요 비즈니스 변경사항 요약
- App Store Connect Analytics 대폭 개선: 수익화 및 사용자 세그먼테이션 중심
- **코호트 분석**: 어떤 기능이 실제 결제로 이어지는지 추적
- Custom Product Pages와 In-App Events가 메인 화면으로 이동
- 오퍼 코드가 구독을 넘어 모든 IAP 유형으로 확장

---

### 6. Apple이 요구하는 법적/규제 사항

#### 6-1. Privacy Nutrition Labels (앱 프라이버시 세부사항)

**URL**: https://developer.apple.com/app-store/app-privacy-details/

- 2020년 12월부터 모든 앱은 데이터 수집 관행을 App Store Connect에서 공개해야 함
- App Store 리스팅에 "App Privacy" 레이블로 표시
- 서드파티 SDK 포함 모든 데이터 수집 공개 필수
- **2025년 업데이트**: 일반적인 "광고용 추적" 대신 실제 파트너 명시 필요

#### 6-2. App Tracking Transparency (ATT)

**URL**: https://developer.apple.com/documentation/apptrackingtransparency

- iOS 14.5+ 필수: 사용자 추적 또는 광고 식별자 접근 전 ATT 프레임워크를 통한 사용자 동의 필요
- IDFA(광고 식별자) 접근 시 반드시 허가 요청
- 2025년 Q1에 **Privacy Manifest 위반으로 12%의 App Store 제출이 거절**됨

#### 6-3. Privacy Manifest (프라이버시 매니페스트)

**URL**: https://developer.apple.com/documentation/bundleresources/privacy-manifest-files

**필수 제출 항목**:
1. 개인정보 보호정책 URL (앱 내에서 접근 가능)
2. App Store Connect에서 완성된 프라이버시 영양 레이블
3. 계정 생성 허용 시 **계정 삭제 기능** 필수
4. Required Reason API 사용 시 프라이버시 매니페스트 파일
5. 서드파티 SDK 포함 모든 데이터 수집 공개

#### 6-4. 계정 삭제 요구사항

**URL**: https://developer.apple.com/support/offering-account-deletion-in-your-app/

- 계정 생성을 허용하는 모든 앱은 앱 내에서 계정 삭제도 허용해야 함
- 쉽게 찾을 수 있어야 함
- 임시 비활성화만으로는 불충분 - 개인 데이터와 함께 계정 삭제 가능해야 함

#### 6-5. EU Digital Services Act (DSA) 준수

**URL**: https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/

- EU App Store 배포 시 **Trader 상태 선언** 필수
- 미등록 앱은 EU App Store에서 제거됨

#### 6-6. EU Digital Markets Act (DMA) 관련

**URL**: https://developer.apple.com/support/dma-and-apps-in-the-eu/

- EU에서의 대안 앱 마켓플레이스 배포 허용
- 대안 결제 처리 업체(PSP) 사용 가능
- **Core Technology Fee (CTF)**: 연간 100만 다운로드 초과 시 설치당 EUR 0.50
- 2026년 1월 1일까지 단일 비즈니스 모델로 전환 예정

#### 6-7. 환불 정책

**URL**: https://developer.apple.com/documentation/storekit/handling-refund-notifications

- Apple이 환불 프로세스를 제어, 개발자는 지원 역할
- `CONSUMPTION_REQUEST` 알림 수신 시 12시간 내 소비 정보 응답
- **WWDC 2025 업데이트**: V2 환불 엔드포인트, `GRANT_PRORATED` 비례 환불 옵션
- `beginRefundRequest(in:)` API로 앱 내에서 환불 요청 시작 가능

#### 6-8. 미국 스토어프론트 외부 결제 링크 현황

**URL**: https://developer.apple.com/support/storekit-external-entitlement-us/

- Epic vs. Apple 소송 결과: 미국에서 외부 결제 링크 허용
- 현재 **0% Apple 커미션** (법원이 합리적 수수료 결정 중)

---

#### 요약 체크리스트

| 카테고리 | 필수 확인 사항 |
|---------|---------------|
| **비즈니스 모델 선택** | Free / Freemium / Paid / Paymium 중 택 1 |
| **IAP 설정** | Consumable / Non-consumable / Auto-renewable / Non-renewing 유형 결정 |
| **구독 설정** | 구독 그룹, 서비스 레벨 순위, 가격 포인트, 오퍼 4종 |
| **App Store Connect** | Paid Apps 계약 체결, 세금 양식, 뱅킹 정보 |
| **커미션** | Small Business Program 자격 여부 확인 (15% vs 30%) |
| **프라이버시** | Privacy Nutrition Labels, ATT, Privacy Manifest |
| **계정 관리** | 계정 생성 시 삭제 기능 필수 |
| **EU 배포** | DSA Trader 상태, DMA 대안 조건 검토 |
| **환불** | Server Notifications 설정, Consumption API 연동 |
| **가입 UI** | 가격, 기간, 이용약관, 개인정보 보호정책 링크 필수 표시 |

---

## 2. Google Play BM 가이드 조사

---

### 1. Google Play 개발자 정책 - 수익화 관련

#### 1-1. 수수료 구조

| 항목 | Google Play | Apple (비교) |
|------|------------|-------------|
| 개발자 등록비 | **1회 $25** | **연간 $99** |
| 표준 수수료 | **30%** | 30% |
| 소규모 개발자 | **첫 $1M까지 15%** (매년 자동 적용) | 첫 $1M까지 15% (전년 기준 자격 심사) |
| 구독 수수료 | **첫 해 30%, 이후 15%** | 동일 |

> **[Apple과 차이점]** Google은 매년 첫 $1M까지 자동으로 15%가 적용되지만, Apple은 전년도 매출 기준으로 자격을 심사

#### 1-2. 대체 결제 시스템 (미국)

> **[Apple과 큰 차이점]** 2025년 10월 29일부터 미국에서 Google Play의 정책이 대폭 변경

- **대체 결제 수단 허용**: 미국에서 Google Play Billing 외 제3자 결제 시스템 사용 가능
- **외부 링크 허용**: 앱 내에서 외부 앱스토어/결제 페이지 링크 제공 가능
- **가격 차별 금지**: Google Play Billing 사용 여부에 따른 가격 차등 설정 금지
- **준수 기한**: 2026년 1월 28일까지 새 정책 준수 필요

---

### 2. Google Play Console 비즈니스 설정 항목

#### 2-1. 구독 설정

| 기능 | 설명 |
|------|------|
| **Base Plan (기본 플랜)** | 결제 주기(월/연), 갱신 유형(자동갱신/선불), 가격 설정 |
| **Offer (오퍼)** | 무료 체험, 할인가 등 프로모션 조건 설정 |
| **Grace Period (유예 기간)** | 결제 실패 시 최대 30일간 서비스 유지 (기본 활성화) |
| **Account Hold (계정 보류)** | 유예 기간 후 최대 60일간 계정 보류 |
| **Resubscribe (재구독)** | 만료된 구독을 Play Store에서 재구매 가능 설정 |

> **[Apple과 차이점]** Google Play는 Base Plan + Offer 구조. 하나의 구독에 여러 Base Plan을 연결할 수 있어 더 유연

#### 2-2. 가격 변경

| 항목 | 내용 |
|------|------|
| **가격 인상 (Opt-in)** | 기존 구독자에게 기본적으로 동의를 받아야 함 |
| **사전 알림** | 가격 인상 적용 37일 전 사전 알림 기간 |
| **개발자 알림 우선** | 처음 7일은 Google이 알리지 않으므로, 개발자가 먼저 사용자에게 안내 가능 |
| **미동의 시** | 사용자가 수락하지 않으면 Google Play가 자동으로 구독 취소 |

---

### 3. Google Play Billing Library (PBL)

#### 3-1. 버전 현황

| 버전 | 상태 | 비고 |
|------|------|------|
| **PBL 8.0** | 최신 (2025년 6월 30일) | 신규 앱 제출 시 PBL 7 이상 필수 |
| **PBL 7** | 현재 최소 요구 버전 | |
| **PBL 6 이하** | 폐기 예정/완료 | |

#### 3-2. 구독 생명주기 관리

| 상태 | 설명 |
|------|------|
| **Active** | 정상 구독 중 |
| **Grace Period** | 결제 실패, 유예 기간 (최대 30일, 서비스 유지) |
| **Account Hold** | 계정 보류 (서비스 중단, 결제 재시도) |
| **Paused** | 사용자가 일시정지 (최대 3개월) |
| **Expired** | 만료 |
| **Canceled** | 취소됨 (남은 기간까지는 이용 가능) |

> **[Apple과 차이점]** Google Play는 **구독 일시정지(Pause)** 기능을 공식 지원. Apple은 이 기능 없음

---

### 4. Google의 "Grow Your App Business" 리소스

- **[Google Play Console 메인](https://play.google.com/console/about/)**: 앱 출시, 수익화, 성장 도구 종합 안내
- **[Monetize with Play Commerce](https://play.google.com/console/about/guides/monetize/)**: 수익화 공식 가이드
- **[Growth and Monetization](https://developers.google.com/products/growth-and-monetization)**: 성장 및 수익화 제품/도구 카탈로그
- **Google Play Apps Accelerator**: 초기 단계 앱 회사를 위한 12주 프로그램, 다음 기수 2026년 3월

---

### 5. Google Play Academy

- **URL**: https://playacademy.withgoogle.com/
- **비용**: 완전 무료

| 코스 | 내용 |
|------|------|
| **Set up and manage monetization options** | 수익화 옵션 및 매출 극대화 방법 |
| **Google Play Policy** | 정책 위반 해결 방법, 정책 준수 가이드 |
| **Store Listing Certificate** | 스토어 리스팅 최적화 인증 |

---

### 6. 법적 요구사항

#### 6-1. Data Safety Section

| 항목 | 요구사항 |
|------|---------|
| **Data Safety Form** | 모든 앱 필수 제출 |
| **Privacy Policy** | 링크 필수 제공 |
| **제3자 SDK** | SDK가 수집하는 데이터도 개발자가 신고 책임 |

#### 6-2. 어린이 보호 (Families Policy)

| 항목 | 내용 |
|------|------|
| **COPPA 준수** | 필수 (2025년 6월 23일 FTC 개정, 2026년 4월 22일 준수 기한) |
| **광고 SDK** | Families Self-Certified Ads SDK만 사용 가능 |

#### 6-3. 연령 확인 법률 (2026년 신규)

| 주 | 시행일 |
|----|--------|
| **Texas** | 2026.1.1 예정 (보류 중) |
| **Utah** | 2026.5 |
| **Louisiana** | 2026.7 |
| **California** | 2027.1.1 |

---

### 7. Apple 대비 Google Play 추가 체크 항목 종합

| 항목 | 중요도 |
|------|--------|
| **대체 결제 시스템 (미국)** | 매우 높음 |
| **구독 일시정지 (Pause)** | 높음 |
| **Account Hold (계정 보류)** | 높음 |
| **Data Safety Section** | 높음 |
| **PBL 버전 관리** | 높음 |
| **가격 인상 방식 (opt-in 기본)** | 중간 |
| **Play Age Signals API** | 중간 (2026) |

---

# Part B: 컨설팅/프레임워크/벤치마크

---

## 3. 앱 BM 컨설팅 프레임워크 조사

---

### 1. RevenueCat - 구독 앱 수익화 가이드

**출처:** State of Subscription Apps 2025 / 5 App Monetization Trends 2025
75,000개 이상 앱, $10B 매출 데이터 기반

#### A. 가격 전략
- 프리미엄 가격대 상승 추세 (중간 가격대 하락, 양극화)
- 지역별 현지화 가격 설정 (일본/한국은 Android, 북미는 iOS 강세)
- SKU와 구매 경험을 현지 선호도에 맞춤

#### B. 하이브리드 수익 모델
- 구독 + 소비형 IAP + 평생 구매를 혼합 (앱의 35%가 이미 채택)
- 게이밍(61.7%), 소셜/라이프스타일(39.4%)이 하이브리드 선도

#### C. 트라이얼 & 온보딩
- 트라이얼 시작의 80%가 앱 최초 실행 당일 발생
- 장기 트라이얼(17~32일)이 가장 높은 전환율(45.7%)
- 하드 페이월: 다운로드 대비 유료 전환 12.1% vs 프리미엄 모델 2.2%
- 연간 구독의 30%가 첫 달에 취소 → 초기 가치 전달이 핵심

#### D. 핵심 벤치마크 지표

| 지표 | 설명 | 벤치마크 |
|------|------|----------|
| ARPU (14일) | 설치 후 14일 평균 매출 | Health&Fitness 중앙값 $0.44, 상위 $1.31 |
| RPI (60일) | 설치 당 매출 | AI앱 $0.63 (전체 중앙값 $0.31의 2배) |
| 월간 이탈률 | 활성 구독 손실 비율 | 낮은 편 5~10%, 높은 편 30%+ |
| 연간 잔존율 | 1년 후 구독 유지 | 저가 연간: 36%, 고가 월간: 6.7% |

#### E. 머니백 보장
- 무료 트라이얼을 대체하는 새로운 트렌드

---

### 2. Adapty - 인앱 구독 수익화 가이드

**출처:** State of In-App Subscriptions 2025
11,000개 이상 앱, $1.9B 매출 데이터 기반

#### A. 12가지 수익화 전략
1. 인앱 구독 (주간/월간/연간)
2. 프리미엄 모델 (기능 제한 무료 + 유료 잠금 해제)
3. 인앱 광고
4. 인앱 구매 (소비형/비소비형)
5. 유료 앱 (선결제)
6. 스폰서십/파트너십
7. 제휴 마케팅
8. 데이터 수익화
9. 하이브리드 모델
10. 크라우드펀딩
11. 트랜잭션 수수료
12. 화이트라벨/라이선싱

#### B. 핵심 벤치마크 발견
- 주간 구독이 전체 인앱 매출의 거의 절반 (전년 대비 9.5% 증가)
- 주간 구독: 65%가 30일 내 이탈 (가장 높은 이탈률)
- 트라이얼 적용 시 주간 플랜 30일 잔존: 23% → 42%로 개선
- 트라이얼이 LTV를 최대 64% 향상
- A/B 테스트를 자주 하는 앱이 안 하는 앱 대비 최대 100배 매출

---

### 3. Superwall - 페이월 최적화 체크리스트

#### A. 런칭 전 필수 체크리스트 (6+3항목)

**필수 6항목:**
1. 결제 카드 등록
2. App Store Connect / Google Play에 상품 설정 후 Superwall에 식별자 매칭
3. 페이월에 상품 연결
4. SDK 설정 및 페이월 정상 표시 검증
5. TestFlight/베타 빌드에서 전체 구매 플로우 테스트 완료
6. 각 스토어에서 구독 상품 승인 확인

**보너스 3항목:**
7. 서베이 붙이기 (비전환 사용자의 거절 이유 파악)
8. 개별 플레이스먼트 생성 (단일 catch-all이 아닌 액션별 분리)
9. 커스텀 오디언스 세분화

#### B. 10가지 검증된 페이월 전략
1. 기능이 아닌 **혜택(benefit)** 중심 가치 제안
2. 심플한 가격: **1~3개 옵션**, 명확한 추천 플랜
3. 국가별 **현지화 가격**
4. 연간 플랜 푸시 (LTV 10~30% 향상)
5. 가치 체험 후 페이월 노출 ("Aha moment" 직후)
6. 긴급성 유발 (한정 시간 오퍼)
7. 타겟 재참여 오퍼 (전환율 25%+)
8. 개인화된 메시지 & 레이아웃
9. 전용 가격 테스트
10. 지속적 실험 마인드셋

#### C. 실험 카테고리별 테스트 항목

| 카테고리 | 테스트 항목 |
|---------|-----------|
| 전환 실험 | 연간 vs 월간 기본값, "트라이얼 곧 종료" 타이머, 사용자 후기, 3티어 vs 2티어, "인기" 라벨 |
| 세분화 실험 | iOS vs Android별 페이월, 지역별 메시지, 파워유저 vs 라이트유저 |
| 크리에이티브 실험 | 비디오 페이월, 성공 사례, 인터랙티브 기능 미리보기, 게이미피케이션 |

---

### 4. Sensor Tower - 모바일 시장 프레임워크

**출처:** State of Mobile 2025

#### 시장 규모 벤치마크 (2024 기준)

| 지표 | 수치 |
|------|------|
| 글로벌 IAP 매출 | $150B (사상 최초, YoY +13%) |
| 비게임 앱 성장 | YoY +23% |
| 미국 IAP 매출 | $52B (글로벌의 1/3 이상) |
| 유럽 IAP 성장 | YoY +24% (미국 초과) |

---

### 5. a16z (Andreessen Horowitz) - 앱 수익화 프레임워크

#### A. 16 Startup Metrics

| # | 지표 | 설명 |
|---|------|------|
| 1 | Bookings | 계약 총 가치 |
| 2 | Revenue | 실제 인식 매출 (GAAP 기준) |
| 3 | ARR | 반복 매출의 연간 환산 |
| 4 | MRR | 월간 반복 매출 |
| 5 | Gross Margin | 매출 - 매출원가 |
| 6 | TCV | 계약 총 가치 (일회성 + 반복) |
| 7 | ACV | 계약의 연간 환산 가치 |
| 8 | ARPU/ARPA | 유저/계정당 평균 매출 |
| 9 | LTV | 고객 생애 가치 |
| 10 | CAC | 고객 획득 비용 |
| 11 | LTV/CAC | 생애가치 대비 획득비용 비율 |
| 12 | Active Users | HAU/DAU/WAU/MAU |
| 13 | Activation Rate | 핵심 가치 행동 완료 비율 |
| 14 | CMGR | 복리 월간 성장률 |
| 15 | Churn | 월간 이탈률 |
| 16 | Burn Rate | 월간 현금 소진율 |

#### B. 멀티모달 비즈니스 모델 프레임워크

| 수익 유형 | 예시 |
|----------|------|
| 프리미엄 + 마이크로페이먼트 | 무료 콘텐츠 2/3 + 결말 유료 잠금 |
| 팁/도네이션 | 크리에이터에게 직접 결제 |
| 티어드 멤버십 | 기본/프리미엄/VIP |
| 상황 기반 광고 | AI 매칭 콘텐츠 연동 광고 |
| 커머스 연동 | 인비디오 쇼핑, 쿠폰 |
| 커스터마이제이션 | 앱 스킨, 개인화 요소 판매 |

#### C. 가격 & 패키징 핵심 원칙
1. 초기 단계의 수익화 전략이 후기에는 수익성을 보장하지 않음 — 단계별 진화 필수
2. 사용량 기반 가격 — 초과 요금 대신 티어드 소비 옵션
3. 번들링 — 경쟁 해자 강화 vs 마진 축소 트레이드오프
4. 프리미엄 — 무료 티어 가치 최적화가 핵심
5. 세분화 & 가치 전달 — 올바른 고객에게 올바른 가치
6. AI 기능 가격 책정 — 가치는 크지만 비용 회계가 복잡

---

### 6. Phiture - Mobile Growth Stack & 구독 최적화 프레임워크

#### A. Mobile Growth Stack — 3개 핵심 계층

| 계층 | 항목 |
|------|------|
| **Acquisition** | ASO, 퍼포먼스 마케팅, 바이럴/추천, 파트너십, 소셜미디어/PR |
| **Engagement & Retention** | 신규 사용자 경험 최적화, 환영 이메일/인앱 튜토리얼, CRM, 딥링킹 |
| **Monetization** | 인앱 구매, 광고 모델, 프리미엄, 구독, 일회성 구매 |
| **Insight & Analytics** (기반) | 분석 기반 계층 |

#### B. 구독 최적화 프레임워크 - 4가지 앱 유형별 전략

| 앱 유형 | 가치 패턴 | 권장 전략 |
|---------|----------|----------|
| **Personal Improvement** (Tinder, Duolingo) | 초기 높고 점차 감소 | 초기에 전환, 트라이얼 → 장기 구독 |
| **Constant Value** (Netflix, HBO) | 안정적 유지 | 월간 구독 중심, 2~4주 트라이얼 |
| **Vault** (Dropbox, Google Photos) | 시간 따라 증가 | 연간 구독 + 트라이얼, 장기 커밋 조기 유도 |
| **Use & Forget** (사진 정리, 보안 앱) | 높지만 일시적 | 일회성 구매/평생 딜, 첫 세션 다중 오퍼 |

> **PIClear는 "Use & Forget" 또는 "Vault" 유형에 해당할 수 있음** — 사진 정리(Use & Forget) + 사진 보관/축적(Vault) 성격을 모두 가짐

---

### 7. Business Model Canvas - 9개 빌딩 블록

| # | 빌딩 블록 | 모바일 앱 적용 핵심 질문 |
|---|----------|----------------------|
| 1 | **Customer Segments** | 누구를 위한 앱인가? |
| 2 | **Value Proposition** | 왜 이 앱을 써야 하는가? |
| 3 | **Channels** | 어떻게 사용자에게 도달하는가? |
| 4 | **Customer Relationships** | 사용자와 어떤 관계를 맺는가? |
| 5 | **Revenue Streams** | 어떻게 돈을 버는가? |
| 6 | **Key Resources** | 필요한 핵심 자원은? |
| 7 | **Key Activities** | 핵심 활동은? |
| 8 | **Key Partnerships** | 전략적 파트너는? |
| 9 | **Cost Structure** | 주요 비용은? |

---

### 8. SubClub & Subscription Index - 구독 앱 벤치마크

#### A. Subscription Value Loop (Phil Carter) — 3단계 순환

**1단계: Value Creation**
- 4R 원칙: Robust, Rapid, Repeatable, Revenue-generating
- 몰입형 온보딩 → 즉시 제품 가치 체험
- 게이미피케이션 (XP, 스트릭, 리더보드, 알림)
- 행동 기반 개인화

**2단계: Value Delivery**
- 바이럴 입소문
- 소셜미디어 공유 메커니즘
- 타겟 유료 광고
- 인플루언서 파트너십

**3단계: Value Capture — 5P**

| P | 항목 | 설명 |
|---|------|------|
| P1 | **Paywall** | 앱 특성에 맞춘 페이월 전략 |
| P2 | **Pricing** | 가격 포인트 최적화 & A/B 테스트 |
| P3 | **Packaging** | 구독 티어 구성 |
| P4 | **Payments** | 결제 플로우 최적화 |
| P5 | **Promotions** | 프로모션 & 할인 전략 |

#### B. Dan Layfield 성장 공식

**핵심 공식:**
```
월간 사용자 상한 = 월간 신규 사용자 / 월간 이탈률
```

**평균 유지 기간 = 1 / 월간 이탈률**
- 이탈률 20% = 5개월 유지
- 이탈률 10% = 10개월 유지

**이탈의 5가지 핵심 동인:**
1. 문제 생애주기 — 사용자가 솔루션을 필요로 하는 기간
2. PMF 강도 — "이 제품 없이 못 산다" 40%+
3. 유저 활성화 — 초기 성공 경험 & 온보딩 효과
4. 가격 티어 정렬 — 올바른 플랜-사용자 매칭
5. 결제 프로세싱 품질

**최고 ROI 최적화 영역:**
1. 구매/체크아웃 플로우 (매출 100%가 통과)
2. 온보딩 시퀀스 (초기 활성화 결정)
3. 핵심 제품 액션 (지속 잔존 동력)

**건강한 잔존 곡선:**
- 1~3개월: 높은 이탈 (관광객 vs 거주자 분리)
- 3~6개월: 곡선 평탄화
- 2~3년 시점 8~25% 잔존: PMF 신호

---

# Part C: 법률/규제/컴플라이언스

---

## 4. 법률/규제 컴플라이언스 조사

---

### 1. 개인정보보호 법규

#### 1-1. GDPR (유럽)

| 항목 | 수준 | 상세 내용 |
|------|------|----------|
| 법적 근거 확보 | **필수** | 얼굴 인식은 **생체 데이터(Art.9)**로 분류 — **명시적 동의** 필요 |
| 동의 획득 메커니즘 | **필수** | 얼굴 인식 기능 사용 전 별도의 명시적 동의 UI. 사전 체크된 체크박스 금지 |
| 데이터 최소화 원칙 | **필수** | 얼굴 벡터 데이터는 기기 내에서만 처리, 서버 전송 금지 권장 |
| 삭제권 (Art.17) | **필수** | 얼굴 인식 데이터 삭제 요청 처리 |
| DPIA | **필수** | 얼굴 인식은 "대규모 생체 데이터 처리"에 해당 |
| EU 대리인 지정 | **필수** | EU 내 사업장이 없는 경우 (Art.27) |

#### 1-2. CCPA/CPRA (캘리포니아)

| 항목 | 수준 |
|------|------|
| "Do Not Sell or Share" 링크 | **필수** |
| 민감 개인정보 사용 제한권 | **필수** (생체 데이터는 민감 정보) |
| 차별 금지 | **필수** |

#### 1-3. PIPL (중국)

| 항목 | 수준 |
|------|------|
| 별도 동의 (민감 개인정보) | **필수** |
| 데이터 현지화 | **필수** |
| 현지 대리인 지정 | **필수** |

#### 1-4. 개인정보보호법 (한국)

| 항목 | 수준 |
|------|------|
| 개인정보 처리방침 공개 | **필수** |
| 민감정보 처리 동의 (얼굴 인식 = 생체인식정보) | **필수** |
| 개인정보 보호 책임자 지정 | **필수** |
| 만 14세 미만 법정대리인 동의 | **필수** |

**사진 앱 특화 데이터 분류:**

| 데이터 유형 | 분류 | 특별 요구사항 |
|------------|------|-------------|
| 사진 자체 | 개인정보 | 처리 목적 고지, 동의 |
| EXIF 메타데이터 | 개인정보 | 수집 고지 |
| GPS 위치정보 | 위치정보 (별도 법률) | 위치정보법에 따른 별도 동의 |
| 얼굴 인식 벡터 | 민감정보 (생체인식정보) | 명시적 별도 동의, 암호화 저장 |

---

### 2. 어린이 보호

| 국가/지역 | 연령 기준 | 특이사항 |
|-----------|----------|---------|
| 미국 (COPPA) | 13세 미만 | 부모 동의 필요 |
| EU (GDPR) | 16세 미만 (국가별 13~16세) | |
| 한국 | 14세 미만 | 법정대리인 동의 필수 |
| 중국 | 14세 미만 | 별도 개인정보 처리 규칙 |
| 영국 | 13세 미만 | AADC 적용 |

---

### 3. 소비자 보호

#### 3-1. 자동갱신 구독 고지

- 구독 가격/기간 명시 **필수**
- "자동 갱신" 문구 **필수**
- 취소 방법 안내 **필수**

#### 3-2. 쿨링오프 기간

| 국가 | 기간 |
|------|------|
| EU | 14일 |
| 한국 | 7일 |
| 호주 | 합리적 기간 |
| 일본 | 통신판매에는 미적용 |

---

### 4. 광고 규제

| 항목 | 수준 |
|------|------|
| ATT 프롬프트 | **필수** (iOS 14.5+) |
| 추적 거부 시 불이익 금지 | **필수** |
| 도박/성인 광고 제한 | **필수** |
| 풀스크린 광고 닫기 버튼 | **필수** |

---

### 5. 접근성 (Accessibility)

| 항목 | 수준 |
|------|------|
| VoiceOver 지원 | **필수** |
| Dynamic Type 지원 | **필수** |
| 색상 대비 (WCAG 2.1 AA) | **필수** |
| 스와이프 제스처 대안 | **필수** (VoiceOver 사용자용) |
| Reduce Motion 대응 | **권장** |

**사진 앱 특화 접근성:**
- 그리드 탐색: VoiceOver로 셀 간 이동/선택/삭제 가능해야 함
- 줌/확대 기능: VoiceOver 사용자에게도 의미 있게 전달

---

### 6. 수출 규제

| 항목 | 수준 |
|------|------|
| 암호화 사용 신고 | **필수** |
| HTTPS만 사용 시 | 면제 자격 해당 (ECCN 5D992) |
| OFAC 제재 국가 | **필수** 준수 |
| 얼굴 인식 이중 용도 기술 | **권장** 검토 |

---

### 7. 세금

| 구분 | 처리 주체 |
|------|----------|
| App Store 판매 VAT/GST | **Apple 대행** |
| 자체 웹사이트 판매 | **자체 처리** |
| W-8BEN 세금 양식 | **필수** 제출 (미제출 시 30% 원천징수) |

---

### 8. 약관 및 정책 문서

| 문서 | 수준 | Apple 요구 |
|------|------|-----------|
| 개인정보 처리방침 | **필수** | URL 제출 필수 |
| 이용약관 | **필수** | 구독 앱은 사실상 필수 |
| EULA | **선택** | 기본 EULA 제공됨 |
| 지원 URL | **필수** | App Store Connect 필수 |

**PIClear 개인정보처리방침 필수 포함 내용:**
- 사진 라이브러리 접근, EXIF 메타데이터, GPS, 얼굴 인식 벡터 데이터
- 기기 내 처리(로컬 전용) 여부 명확히
- 제3자 공유 (분석/광고 SDK)
- 얼굴 인식 별도 고지, 옵트아웃 방법

---

### 출시 전 필수 우선순위

- [ ] 개인정보 처리방침 작성 및 URL (한국어 + 영어)
- [ ] 지원 URL 확보
- [ ] App Store Privacy Nutrition Labels 작성
- [ ] 얼굴 인식 별도 동의 메커니즘 (opt-in)
- [ ] App Store 연령 등급 설정
- [ ] 암호화 질문 답변
- [ ] 세금 양식 제출
- [ ] VoiceOver 기본 지원
- [ ] 스와이프 삭제 접근성 대안 메커니즘
- [ ] ATT 프레임워크 통합 (광고 사용 시)

---

# Part D: 앱 출시 전 비즈니스 체크리스트

---

## 5. 앱 출시 전 비즈니스 체크리스트

> `[!놓치기 쉬움]` 표시는 많은 인디 개발자가 놓치는 항목

---

### 1. App Store Connect 설정

#### 1-1. 앱 메타데이터

| 항목 | 상세 |
|------|------|
| 앱 이름 | 최대 30자. 핵심 키워드 포함 권장 |
| 부제(Subtitle) | 최대 30자 |
| 설명 | 최대 4,000자. 첫 3줄이 핵심 |
| 키워드 | 최대 100자. 쉼표 구분 |
| 스크린샷 | iPhone 6.9인치(필수). 최소 3장, 최대 10장 |
| 앱 프리뷰 영상 | 최대 30초, 최대 3개 |
| 프로모션 텍스트 | `[!놓치기 쉬움]` 170자. 앱 업데이트 없이 변경 가능 |

#### 1-2. 구독/IAP 설정

| 항목 | 상세 |
|------|------|
| IAP 리뷰 제출 | `[!놓치기 쉬움]` IAP는 앱과 별도로 리뷰 승인 필요 |
| 구매 복원 버튼 | `[!놓치기 쉬움]` 미구현 시 리젝 사유 |
| Sandbox 테스트 계정 | 구매 흐름 테스트용 |

#### 1-3. 연령 등급

| 항목 | 상세 |
|------|------|
| 2025년 7월 변경 | `[!놓치기 쉬움]` Apple이 새 연령 등급(13+, 16+, 18+) 도입. 2026년 1월 31일까지 업데이트 필수 |

#### 1-4. 앱 리뷰 정보

| 항목 | 상세 |
|------|------|
| 리뷰 노트 | `[!놓치기 쉬움]` 사진 라이브러리 접근 필수 앱 — 테스트 방법 상세 안내 필요 |

---

### 2. 마케팅 준비

#### 2-1. ASO

| 항목 | 상세 |
|------|------|
| 스크린샷 내 텍스트 | `[!놓치기 쉬움]` Apple AI/OCR로 키워드 활용 |
| 현지화 | `[!놓치기 쉬움]` 한국어 외 영어, 일본어 등 |
| A/B 테스트 | Product Page Optimization 활용 |

#### 2-2. 소셜/커뮤니티

| 항목 | 상세 |
|------|------|
| 출시 전 활동 | `[!놓치기 쉬움]` Product Hunt, HN, 한국 커뮤니티 사전 활동 |

#### 2-3. 웹사이트

| 항목 | 필수 여부 |
|------|-----------|
| Support URL | **Apple 필수** |
| Privacy Policy URL | **Apple 필수** |
| 랜딩 페이지 | `[!놓치기 쉬움]` GitHub Pages / Notion / Carrd 등으로 간단히라도 |

---

### 3. 고객 지원

| 항목 | 상세 |
|------|------|
| 인앱 피드백 | `[!놓치기 쉬움]` 없으면 불만 사용자가 별 1개 리뷰 남김 |
| 리뷰 응답 | `[!놓치기 쉬움]` App Store Connect에서 직접 답변 가능 |
| 리뷰 요청 타이밍 | SKStoreReviewController. 연간 3회 제한 |

---

### 4. 분석 및 모니터링

| 항목 | 상세 |
|------|------|
| 핵심 이벤트 정의 | `[!놓치기 쉬움]` 출시 전에 추적할 이벤트 정의 필수 |
| Remote Config | `[!놓치기 쉬움]` 최소한 Remote Config는 초기부터 설정 권장 |

---

### 5. 비즈니스 인프라 (한국 특화)

#### 5-1. 사업자 등록

| 항목 | 상세 |
|------|------|
| 필요 시점 | `[!놓치기 쉬움]` 유료 앱/IAP 있으면 출시 전 반드시 |

#### 5-2. 통신판매업 신고

| 항목 | 상세 |
|------|------|
| 구매안전서비스 비적용 확인서 | `[!놓치기 쉬움]` 없으면 신고 반려 |

#### 5-3. Apple Developer Account

| 항목 | 상세 |
|------|------|
| 갱신 | `[!놓치기 쉬움]` 만료 시 앱이 스토어에서 내려감 |

#### 5-4. 세금

| 항목 | 상세 |
|------|------|
| W-8BEN | `[!놓치기 쉬움]` 미제출 시 미국 판매분 30% 원천징수 |

#### 5-5. 앱 내 법적 고지 (한국 전자상거래법)

| 항목 | 상세 |
|------|------|
| 사업자 정보 표시 | `[!놓치기 쉬움]` 2024년 12월부터 Apple App Store에도 적용. 위반 시 과태료 최대 500만 원 |

---

### 6. 론칭 후 운영

| 항목 | 상세 |
|------|------|
| iOS 메이저 업데이트 | `[!놓치기 쉬움]` WWDC 직후 베타 대응 시작 |
| 공개 로드맵 | `[!놓치기 쉬움]` 사용자에게 비전 공유 → 리텐션 향상 |
| 무료→유료 전환 | `[!놓치기 쉬움]` 초기부터 수익 모델 확정 필수 |
| 구독 해지 시 할인/일시정지 | `[!놓치기 쉬움]` 간단한 구현으로 이탈률 크게 낮출 수 있음 |

---

### 7. 출시 D-Day 체크리스트

| 순서 | 항목 |
|------|------|
| 1 | 앱 심사 승인 완료 (Manual Release 권장) |
| 2 | 크래시 리포팅 정상 작동 확인 |
| 3 | 분석 이벤트 정상 수집 확인 |
| 4 | 모든 딥링크/URL 정상 작동 |
| 5 | Support URL / Privacy Policy URL 접근 가능 |
| 6 | 랜딩 페이지 라이브 |
| 7 | SNS 런칭 포스트 예약/발행 |
| 8 | `[!놓치기 쉬움]` 앱 삭제 후 재설치 시 정상 동작 확인 |
| 9 | `[!놓치기 쉬움]` 네트워크 없는 환경에서 동작 확인 |
| 10 | 사업자정보 표시 확인 (한국 전자상거래법) |

---

### 8. 인디 개발자가 놓치기 쉬운 항목 종합 (20개)

**App Store / 기술:**
1. 프로모션 텍스트 미활용
2. IAP 별도 리뷰 제출 누락
3. 구매 복원(Restore Purchases) 버튼 미구현
4. Privacy Policy URL 누락/접근 불가
5. 연령 등급 질문지 미갱신
6. 리뷰 노트 미작성 (사진 앱 특화)
7. 스크린샷 텍스트의 키워드 효과 미활용
8. 메타데이터 현지화 누락

**비즈니스 / 법적:**
9. 통신판매업 신고 시 구매안전서비스 비적용 확인서 누락
10. Apple Developer 계정 갱신 실패
11. W-8BEN 세금 양식 미제출
12. 한국 사업자정보 표시 누락

**마케팅 / 운영:**
13. 출시 전 커뮤니티 활동 없음
14. 핵심 분석 이벤트 미정의
15. 인앱 피드백 채널 미구현
16. 리뷰 응답 미실시
17. iOS 메이저 업데이트 대응 지연
18. 무료→유료 전환 시 기존 사용자 반발
19. 구독 해지 시 할인/일시정지 옵션 미제공
20. 공개 로드맵 미운영

---

# Part E: 경쟁 앱 BM 구조 분석

---

## 6. 구독 앱 성공사례 BM 구조 조사

---

### 1. 사진/갤러리 앱

#### 1-1. Gemini Photos (MacPaw) — 유사사진 정리

**무료/유료 경계:**
- 무료: 스크린샷, 흐릿한 사진, 메모 촬영본 식별 및 정리
- 유료: 유사 사진 자동 탐지 및 정리

**가격:**
| 플랜 | 가격 |
|------|------|
| 월간 | $1.99 |
| 연간 | $11.99 |
| 라이프타임 | $14.99 |

- 광고 없음
- 3일 무료 체험 후 자동 결제
- 라이프타임이 연간보다 약간만 비싸서 라이프타임 구매 유도 강함
- Setapp($9.99/월 번들)에서도 이용 가능

#### 1-2. CleanMyPhone (MacPaw)

**무료/유료 경계:**
- 무료: Health 모듈, 일부 Declutter/Organize
- 유료: 전체 클러터 스캔/정리, 비디오 압축, Live Photo 변환 등

**가격:** 연간 $24.99

- 3일 무료 체험
- "건강 점수"라는 심리적 트리거를 무료로 제공

#### 1-3. Slidebox (사진 정리)

**무료/유료 경계:**
- 무료: 기본 사진 정리, 즐겨찾기 100장까지 동기화
- 유료: 10,000장 이상 지원, 전체 클라우드 동기화

**가격:**
| 플랜 | 가격 |
|------|------|
| 월간 | $4.99 |
| 연간 | $49.99 |
| 일회성 | $19.99 |

- 틴더 스타일 스와이프 UX — PIClear와 유사

#### 1-4. HashPhotos

**무료/유료 경계:**
- 무료: 기본 갤러리, 각 유료 기능 3회까지 무료 체험
- 유료: 개별 기능팩 $1/개 또는 올인원 $3.99

- "Try Before Buy" — 각 기능 3회 무료
- 매우 저렴한 가격

#### 1-5. Google Photos

- **전환 전**: 무제한 고화질 무료
- **전환 후**: 15GB 무료 → Google One ($1.99~$99.99/월)
- "Bait & Switch" 전략
- AI 기능을 유료 차별점으로

---

### 2. 유틸리티 구독 앱

#### 2-1. 1Blocker (광고차단)

- 무료: 1개 차단 필터만 선택
- 유료: 모든 카테고리 + 인앱 트래커 차단
- 월간 $2.99 / 연간 $14.99 / 라이프타임 $39.99
- 14일 무료 체험

#### 2-2. Fantastical (캘린더)

- 무료: 기본 캘린더, 다중 계정, 날씨 — 캘린더 세트 1개
- 유료: 캘린더 세트, 위치 기반 전환, 작업 생성
- 개인 연간 $4.75/월 / 월간 $6.99
- 14일 무료 체험, "27% 절약" 앵커링
- 월 $350,000 수익, 35,000 다운로드 — 소규모 사용자에서 높은 ARPU

#### 2-3. Bear (노트)

- 무료: 기본 노트 — 동기화 불가, 50개 제한
- 유료: iCloud 동기화, 무제한 노트, 25+ 테마
- 월간 $2.99 / 연간 $29.99
- "동기화 = 유료"라는 단 하나의 킬러 제한

#### 2-4. Spark (이메일)

- 무료: 기본 이메일 관리
- 유료: AI 기능, 우선순위 이메일, 발신자 차단
- Premium 연간 $59.99 / 월간 $7.99
- AI를 핵심 유료 차별점으로

#### 2-5. Halide (카메라)

- 무료: 7일 체험 후 전체 잠금 (실질적 Hard Paywall)
- 월간 $2.99 / 연간 $11.99 / 라이프타임 $49.99
- 구독과 일회성 구매 동시 제시
- 개발자가 "왜 무료가 아닌가" 블로그로 투명 소통
- 일회성 구매 옵션이 구독 거부감 완화

---

### 3. Freemium 성공 사례

#### 3-1. Duolingo

- 무료: 전체 학습 콘텐츠 — 광고 + 하트(실수 제한) 시스템
- Super: ~$6.99/월 (광고 제거, 무제한 하트)
- Max: ~$13.99/월 (AI 기능)
- MAU 대비 구독 전환율: 3% → 8.8% (5년간 176% 성장)
- 40.5M DAU, 9.5M 유료 구독자
- 2025년 연 매출 $10억 돌파
- 핵심 교훈: 콘텐츠 차단 아닌 "편의성" 과금

#### 3-2. Evernote

- 무료: 노트 50개, 기기 1대만
- Starter: $8.25/월 / Advanced: $20.83/월
- 가격 70%+ 인상 + 무료 기능 축소 → 대규모 사용자 반발
- **실패 사례 교훈**: 기존 무료 가치를 빼앗으면 신뢰 상실

---

### 4. 종합 인사이트

#### 사진 앱 가격대 벤치마크

| 앱 | 월간 | 연간 | 라이프타임 |
|----|------|------|-----------|
| Gemini Photos | $1.99 | $11.99 | $14.99 |
| CleanMyPhone | - | $24.99 | - |
| Slidebox | $4.99 | $49.99 | $19.99 |
| HashPhotos | - | - | $3.99 |
| Halide | $2.99 | $11.99 | $49.99 |

사진 정리 앱 적정 연간 가격대: **$11.99~$24.99**

#### 페이월 전략 비교

| 유형 | 중간 전환율 | 리텐션 |
|------|-----------|--------|
| Hard Paywall | 12.11% | 12.8% |
| Soft Paywall | 2.18% | 9.3% |

#### 핵심 교훈
1. "스캔은 무료, 정리는 유료" — Gemini, CleanMyPhone 모델
2. 라이프타임 옵션 필수 — 구독 거부감 있는 사용자용
3. 무료 체험은 3~14일
4. 편의성 과금 > 기능 차단 — Duolingo 교훈
5. 온보딩 중 페이월이 전환의 50%
6. Try Before Buy — HashPhotos의 "3회 무료 체험"
7. 기존 무료 가치를 빼앗지 말 것 — Evernote 실패
8. Photo & Video 카테고리는 27.57%가 2년 내 $1,000 매출 달성 (전체 카테고리 중 최고)

---

# Part F: 누락 항목 Gap 분석

---

## 7. 수익화 누락 항목 Gap 분석

---

### 1. 가격 심리학 / 프라이싱 전략 심화

| 항목 | 커버 상태 |
|------|-----------|
| 앵커링, 디코이 효과 | **부분적으로 커버됨** |
| 지역별 가격 차별화 (PPP) | **전혀 없음** |
| 가격 인상 전략 | **전혀 없음** |
| 프로모션/세일 전략 | **부분적으로 커버됨** |

**지역별 가격 차별화 — 추가 필요:**
- App Store는 175개 스토어프론트별 가격 티어 지원
- 동일 USD 적용 시 구매력 낮은 지역에서 전환율 극단적 하락
- 제안: 6번 하위에 "6-A. 지역별 가격 티어 매핑" 추가

**가격 인상 전략 — 추가 필요:**
- Apple은 가격 인상 시 구독자 동의 요구, 미동의 시 자동 해지
- 제안: 6번 하위에 "6-B. 가격 인상 로드맵 & 기존 구독자 보호" 추가
- 내용: Grandfather pricing vs 일괄 인상, 인상폭 단계(20% 이하 권장)

---

### 2. 구독 관리 심화

| 항목 | 커버 상태 |
|------|-----------|
| 구독 업/다운그레이드 | **부분적으로 커버됨** |
| 구독 일시정지 / Billing Grace Period | **전혀 없음** |
| 크로스플랫폼 구독 동기화 | **전혀 없음** |
| Family Sharing | **전혀 없음** |
| 교육/단체 할인 | **전혀 없음** |

**Billing Grace Period — 추가 필요:**
- 비자발적 이탈이 전체 이탈의 20~40%
- Grace Period 활성화하지 않으면 결제 실패 = 즉시 해지
- 제안: "6-C. 구독 생명주기 관리" 추가

**Family Sharing — 추가 필요:**
- 사진 앱은 가족 단위 사용 자연스러움
- 제안: "6-D. Family Sharing 정책" 추가

---

### 3. 고객 여정 상세

| 항목 | 커버 상태 |
|------|-----------|
| 온보딩 플로우 (수익화 관점) | **부분적으로 커버됨** |
| 첫 구매 경험 (First Purchase Experience) | **전혀 없음** |
| 구독 해지 플로우 (Cancellation Flow) | **전혀 없음** |
| 환불 처리 프로세스 | **전혀 없음** |

**구독 해지 플로우 — 추가 필요:**
- 앱 내에서 해지 전 세이브 오퍼, 해지 사유 수집 가능
- 제안: "8-B. 구독 해지 방어 플로우" 추가

**환불 처리 — 추가 필요:**
- `Transaction.revocationDate` 모니터링
- 환불 어뷰징 임계치 설정
- 제안: "14-A. 환불 정책 & 기술 대응" 추가

---

### 4. 마케팅/성장

| 항목 | 커버 상태 |
|------|-----------|
| 앱 스토어 마케팅 (Apple Search Ads, ASO) | **전혀 없음** |
| Referral 프로그램 | **전혀 없음** |
| 리뷰/평점 관리 전략 | **전혀 없음** |
| 콘텐츠 마케팅 | **전혀 없음** |

**사용자 획득 전략 — 추가 필요:**
- Apple Search Ads는 iOS 앱 최고 ROI 광고 채널
- CAC 계산이 12번(유닛 이코노믹스)과 연동
- 제안: 신규 "16. 사용자 획득 전략 (UA)" 추가

**리뷰/평점 관리 — 추가 필요:**
- 4.5점 이상 vs 4.0점 이하 전환율 차이 2~3배
- 제안: "9-A. 앱 평점 관리" 추가

---

### 5. 운영

| 항목 | 커버 상태 |
|------|-----------|
| 고객 지원 전략 | **전혀 없음** |
| 인시던트 대응 | **부분적으로 커버됨** |
| 가격 변경 커뮤니케이션 | **전혀 없음** |
| 피처 디프리케이션 정책 | **전혀 없음** |

**고객 지원 — 추가 필요:**
- "결제했는데 프리미엄이 안 풀려요"는 가장 빈번한 CS
- 제안: 신규 "17. 운영 & 고객 지원" 추가

**피처 디프리케이션 — 추가 필요:**
- 제안: "15-A. 기능 변경/제거 정책" 추가

---

### 6. 수익 다각화

| 항목 | 커버 상태 |
|------|-----------|
| IAP (일회성 구매) | **부분적으로 커버됨** |
| 팁 / 후원 기능 | **전혀 없음** |
| 제휴/파트너십 수익 | **전혀 없음** |
| 데이터 수익화 | **전혀 없음** |

**데이터 수익화 미실시 선언 — 추가 필요:**
- "하지 않겠다"고 명시적 선언이 프라이버시 차별점
- 제안: 1번 하위에 "1-A. 데이터 수익화 미실시 선언" 추가

---

### 추가 필요 항목 우선순위 정리

| 우선순위 | 추가 항목 | 배치 위치 |
|---------|----------|----------|
| **높음** | 구독 해지 방어 플로우 | 8-B |
| **높음** | 환불 정책 & 기술 대응 | 14-A |
| **높음** | 가격 인상 전략 & 커뮤니케이션 | 6-B |
| **높음** | 고객 지원 전략 | 신규 17장 |
| **높음** | Billing Grace Period | 6-C |
| **높음** | 사용자 획득 전략 (ASA, ASO) | 신규 16장 |
| **높음** | 리뷰/평점 관리 | 9-A |
| **중간** | 지역별 가격 차별화 | 6-A |
| **중간** | 첫 구매 후 경험 설계 | 8-A |
| **중간** | Family Sharing 정책 | 6-D |
| **중간** | 데이터 수익화 미실시 선언 | 1-A |
| **중간** | 피처 디프리케이션 정책 | 15-A |
| **중간** | Referral 프로그램 | 16-A |
| **낮음** | 팁 / 후원 기능 | 6-E |
| **낮음** | 교육/단체 할인 | 부록 |
| **낮음** | 크로스플랫폼 구독 동기화 | 13-A |
| **낮음** | 콘텐츠 마케팅 | 부록 |
| **낮음** | 제휴/파트너십 수익 | 부록 |

---

# Part G: 인디앱 실패사례 교훈

---

## 8. 인디 개발자 앱 비즈니스 모델 실패 사례와 교훈

---

### 1. 가격 책정 실수

#### 사례 A: 너무 싸게 — "Race to the Bottom"

한 인디 개발자가 **월 $1 구독**으로 광고 제거 제공. "싸면 많이 구독하겠지"였지만, $1은 "그 정도 가치"라는 신호. **$5로 올린 후** 오히려 구독 수익 **2.5배 증가**.

#### 사례 B: Jared Sinclair의 "Unread" RSS 리더

8개월간 주 60~80시간 개발. iPhone $32K + iPad $10K → 세후 실질 수입 **$21,000**. "충동 구매" 가격대($2.99~$4.99)를 넘기기 어려운 App Store 구조적 문제.

#### 수익 현실 데이터 (RevenueCat 2025)
- 앱의 **17.2%만** 월 $1,000 이상 수익
- **3.5%만** 월 $10,000 도달 (풀타임 최소 기준)
- 인디 프로젝트 중위값: **월 $500**

---

### 2. 무료 티어 설계 실패

#### 사례 A: Marco Arment의 Overcast — 너무 관대

Overcast 2.0에서 "전부 무료, 원하면 후원" 모델 → 후원 전환율 겨우 **1.9%**. 사용자 80%가 무료만 사용. 이후 다크 테마를 유료로 묶었더니 **후원자들까지 분노**. 결국 **광고 + 구독** 모델로 전환.

#### 사례 B: 너무 인색한 무료 티어

무료 버전에서 핵심 가치를 전혀 경험 못하면, 유료 전환 이전에 삭제됨.

---

### 3. 페이월/온보딩 타이밍 실수

**핵심 데이터:**
- 트라이얼 시작의 **82%가 설치 당일**
- 하드 페이월 전환율: **12.1%** vs 프리미엄 모델: **2.2%**

**Superwall 분석 — 4가지 실수:**
1. 복잡한 기능 비교 테이블 → 분석 마비
2. 영감 없는 메시지 → "Pro 구매" 대신 결과 중심 메시지
3. 단일 가격 옵션만 → 다양한 선택지 필요
4. 과도하게 복잡한 UI → 심플한 2티어가 효과적

**맥락의 중요성:** 명상 앱에서 온보딩 **전** 페이월 1% 전환 vs 온보딩 **후** 20% 전환

---

### 4. 구독 피로 (Subscription Fatigue)

**핵심 데이터:**
- "사용량 부족"이 취소 이유 **1위** (32%~47%)
- 월간 구독 리텐션: **17.0%**
- 연간 구독 리텐션: **44.1%**
- 첫 달 이탈율 30% 이상

**대응:** 하이브리드 모델 (구독 + 라이프타임), 취소 흐름에서 50% 할인 또는 다운그레이드 옵션

---

### 5. 가격 변경으로 인한 이탈

#### 사례 A: Inkdrop — 가격 2배 인상

$4.90/월 → $9.98/월. 이탈률 **~4% → 9%**로 즉시 두 배. **약 20% 이탈**. 하지만 9개월 후 이탈률 **~3%로 안정화** (오히려 이전보다 낮아짐). 핵심: "호기심 사용자"가 떠나고 실제 가치를 느끼는 사용자만 남음.

#### 사례 B: Paradox Games — 지역별 가격 인상으로 리뷰 폭탄

DLC 정책 누적 불만 + 가격 인상 = 폭발

---

### 6. StoreKit/결제 버그로 수익 손실

#### 사례 A: StoreKit 트랜잭션 누락
버그로 트랜잭션을 놓칠 수 있음. 유료 고객이 서비스 못 받거나, 무료 사용자가 프리미엄 사용.

#### 사례 B: TestFlight에서 IAP 작동 안 함
시뮬레이터 정상 → TestFlight 빈 배열 반환 → 릴리즈 후 발견

#### 사례 C: Billing Grace Period 미설정
활성화한 앱이 그렇지 않은 앱보다 **15~20% 더 많은 구독 회수**

---

### 7. 환불 악용

- 사용자가 콘텐츠 소비 후 "실수로 구매" 환불
- 도용된 카드로 프리미엄 → 전체 환불
- Apple이 환불을 쉽게 승인 → 개발자가 대가 못 받음
- 사진 앱은 소비성 아이템이 아니므로 리스크 상대적으로 낮음

---

### 8. App Store 리젝/법적 문제

**주요 리젝 사유:**
- 3.1.1: 외부 결제 링크
- 구독 설명 불충분 / 취소 방법 불명확

**인디 개발자 경험:** 동일 기능 앱이 어떤 개발자는 통과, 어떤 개발자는 리젝

---

### 9. 리뷰 테러

- 가격/기능 변경 시 조직적 1점 리뷰
- Apple이 연간 9,400만 개 가짜 리뷰 제거하지만, 실제 사용자 부정 리뷰는 제거 불가
- 업데이트마다 평점 리셋 가능 → 대규모 사용자 없으면 급락 위험

---

### 10. 마케팅 부재 실패

#### 사례 A: HN 런칭 → 가입 0명
$200과 9일로 SaaS 제작, 사전 마케팅 전무 → 가입 0

#### 사례 B: Widgetsmith — 마케팅 $0으로 1억 다운로드
iOS 14 위젯 출시 타이밍 정확히 맞춤. 타이밍 + 입소문 = 모든 마케팅 대체

#### 사례 C: Codakuma 지역별 가격
인도 90% 가격 인하 → 해당 지역 수익 **128% 증가**. 전체 매출 29% 성장

---

### 종합 권장 사항

| 항목 | 권장 | 근거 |
|------|------|------|
| 모델 | 프리미엄 + 하이브리드 (구독 + 평생) | 구독 피로 대응 |
| 가격대 | 월 $3.99~$5.99 / 연 $29.99 / 평생 $79.99 | 너무 싼 가격은 해로움 |
| 페이월 타이밍 | 온보딩 직후 + 프리미엄 기능 사용 시점 | 첫날 전환 82% |
| 트라이얼 | 7일 무료 | 체험 후 전환율 향상 |
| 지역 가격 | 반드시 설정 | 128% 수익 증가 사례 |
| 결제 인프라 | RevenueCat 권장 | StoreKit 직접 구현 리스크 큼 |
| Grace Period | 16일 또는 28일 | 15~20% 구독 회수 |
| 가격 변경 | Grandfather clause 필수 | 이탈 + 리뷰 테러 방지 |

---

# Sources

## Apple 공식
- https://developer.apple.com/app-store/review/guidelines/
- https://developer.apple.com/app-store/business-models/
- https://developer.apple.com/app-store/subscriptions/
- https://developer.apple.com/app-store/small-business-program/
- https://developer.apple.com/storekit/
- https://developer.apple.com/app-store/app-privacy-details/
- https://developer.apple.com/documentation/apptrackingtransparency
- https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- https://developer.apple.com/support/offering-account-deletion-in-your-app/
- https://developer.apple.com/support/dma-and-apps-in-the-eu/
- https://developer.apple.com/documentation/storekit/handling-refund-notifications
- https://developer.apple.com/videos/play/wwdc2025/241/
- https://developer.apple.com/videos/play/wwdc2025/249/
- https://developer.apple.com/videos/play/wwdc2024/10061/
- https://developer.apple.com/videos/play/wwdc2024/10110/

## Google Play
- https://play.google.com/console/about/
- https://play.google.com/console/about/guides/monetize/
- https://developer.android.com/google/play/billing/subscriptions
- https://playacademy.withgoogle.com/

## 컨설팅/프레임워크
- https://www.revenuecat.com/state-of-subscription-apps-2025/
- https://adapty.io/state-of-in-app-subscriptions/
- https://superwall.com/blog/superwall-best-practices-winning-paywall-strategies-and-experiments-to/
- https://sensortower.com/state-of-mobile-2025
- https://a16z.com/16-startup-metrics/
- https://a16z.com/pricing-packaging/
- https://phiture.com/mobilegrowthstack/the-mobile-growth-stack-3ffa6856f482/
- https://phiture.com/mobilegrowthstack/the-subscription-optimization-framework-how-to-better-monetize-your-app-in-2021/
- https://philgcarter.substack.com/p/the-subscription-value-loop

## 앱 출시 체크리스트
- https://www.applaunchflow.com/blog/app-launch-checklist-2026
- https://github.com/adamwulf/app-launch-guide

## 경쟁 앱
- https://www.revenuecat.com/blog/growth/hard-paywall-vs-soft-paywall/
- https://www.lux.camera/why-is-halide-not-free/

## 인디 개발자 실패사례
- https://marco.org/2016/09/09/overcast-ads
- https://www.devas.life/how-i-successfully-doubled-my-saas-price-to-10-month-and-lowered-the-churn-rate-to-3/
- https://medium.com/revenuecat-blog/ios-subscriptions-are-hard-d9b29c74e96f
- https://adapty.io/blog/how-to-handle-apple-billing-grace-period/
- https://codakuma.com/2025-in-review/
- https://cherpake.medium.com/lessons-learned-after-first-year-as-indie-ios-developer-4507787ff379

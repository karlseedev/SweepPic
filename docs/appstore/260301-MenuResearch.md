# 그리드 전체메뉴(...) 하위 메뉴 구성 조사

> 작성일: 2026-03-01
> 목적: 그리드 화면 상단 ellipsis(...) 메뉴의 "사용자/설정", "구독/결제", "고객센터/도움말" 3개 메뉴 하위 구성 결정을 위한 타 앱 사례 조사 및 App Store 심사 필수사항 조사

---

## 목차

1. [현재 메뉴 구조](#1-현재-메뉴-구조)
2. [사용자/설정 메뉴 조사](#2-사용자설정-메뉴-조사)
3. [구독/결제 메뉴 조사](#3-구독결제-메뉴-조사)
4. [고객센터/도움말 메뉴 조사](#4-고객센터도움말-메뉴-조사)
5. [App Store 심사 필수 항목](#5-app-store-심사-필수-항목)
6. [사진 앱(PhotoKit) 특화 필수사항](#6-사진-앱photokit-특화-필수사항)
7. [구독 앱 필수 UI 요소](#7-구독-앱-필수-ui-요소)
8. [프라이버시/개인정보 필수사항](#8-프라이버시개인정보-필수사항)
9. [실제 리젝 사례](#9-실제-리젝-사례)
10. [Apple HIG 설정 메뉴 패턴](#10-apple-hig-설정-메뉴-패턴)
11. [PickPhoto 최종 메뉴 권장안](#11-pickphoto-최종-메뉴-권장안)
12. [핵심 체크리스트](#12-핵심-체크리스트)

---

## 1. 현재 메뉴 구조

**파일**: `GridViewController+Cleanup.swift`

### iOS 26+ (시스템 네비바) — 55~66줄 / iOS 16~25 (FloatingUI) — 97~104줄

현재 ellipsis(...) 메뉴 구성:

| 순서 | 메뉴 항목 | 아이콘 | 동작 |
|------|----------|--------|------|
| 1 | 자동정리 | `wand.and.stars` | 빈 액션 (미구현) |
| 2 | 사용자 | `person.circle` | 빈 액션 (미구현) |
| 3 | 구독 | `creditcard` | 빈 액션 (미구현) |
| 4 | 기타 | `ellipsis` | 빈 액션 (미구현) |
| 5 | 고객센터 | `questionmark.circle` | 빈 액션 (미구현) |
| 6 | 설명 다시 보기 (서브메뉴) | `arrow.counterclockwise` | 하위 6개 항목 |

상단 우측 버튼 배치: `[menuItem, selectItem, cleanupItem]` → 화면에서 좌→우: **[정리] [선택] [...메뉴]**

---

## 2. 사용자/설정 메뉴 조사

### 2-1. 앱별 사례

#### Google Photos
프로필 아이콘 탭 시:
- 계정 관리/전환, 백업 설정 (품질/모바일데이터/폴더별), 저장공간 사용량, 환경설정 (알림), 도움말/피드백

#### Apple Photos
- 앱 내 설정 최소화, 시스템 설정에 위임
- iCloud 사진 켜기/끄기, 저장공간 최적화, 앨범 정렬 기준

#### VSCO
- Activity, Messages, Favorites, People, Member Hub, Settings, Security, Support, About, Sign out

#### Adobe Lightroom
- 계정/프로필, 클라우드/로컬 저장공간, 프리미엄 기능, 구독 관리, 로그인 방식

#### Snapseed
- JPEG 품질, 언어, 도움말, App Store 리뷰 (매우 간결, 계정 없는 오프라인 앱)

#### Darkroom
- 구독 플랜, 내보내기 설정, 언어, 피드백/지원, 약관/개인정보

### 2-2. 공통 패턴

| 분류 | 공통 항목 |
|------|----------|
| 계정 | 프로필 정보, 로그아웃, 계정 전환 |
| 저장공간 | 사용량 표시, 클라우드/로컬 분리 |
| 구독/결제 | 현재 플랜, 업그레이드 유도 |
| 알림 | 항목별 on/off |
| 개인정보 | 권한, 데이터 추적 설정 |
| 앱 정보 | 버전, 피드백, 고객지원, 약관 |

### 2-3. PickPhoto 추천 항목

PickPhoto는 계정 없이 동작하는 **로컬 특화 앱**이므로 사진 정리 설정 + 앱 사용 통계 중심이 적합.

| 항목 | 이유 |
|------|------|
| **삭제대기함 자동 비우기** | X일 후 자동 삭제 타이머. 쌓아두기 방지 |
| **스와이프 삭제 감도** | 핵심 제스처 민감도 조절. 실수 삭제 vs 빠른 정리 균형 |
| **유사 사진 분석 자동 실행** | 배터리/성능 민감 사용자를 위한 제어권 |
| **저장공간 사용 현황** | 기기 저장공간 파악 → 정리 동기 부여 |
| **정리 통계** | "248장 정리, 3.2GB 확보" — 성취감 제공 |
| **앱 잠금 (Face ID)** | 사진 앱 프라이버시 필수 |
| **테마 (다크/라이트/시스템)** | OLED 배터리 절약, 야간 사용 |
| **정리 리마인더 알림** | 주기적 정리 습관 형성, 재방문 유도 |

---

## 3. 구독/결제 메뉴 조사

### 3-1. 앱별 사례

#### iCloud+
- 현재 플랜, 플랜 변경, 스토리지 사용량 시각화, 다음 결제일, 전용 기능 목록, 구독 취소, 패밀리 공유

#### Google One
- 스토리지 대시보드, 플랜 변경, 월간/연간 전환, 멤버십 혜택, 구독 취소, 스토리지 관리 도구

#### Adobe Lightroom
- 현재 플랜/계정, 클라우드 사용량, 프리미엄 기능 목록, 구독 관리, 구매 복원, Early Access

#### VSCO
- 멤버십 등급 배지, Pro 혜택 목록, 업그레이드, Live Chat (Pro 전용), 구독 관리, 구매 복원

#### YouTube Premium
- 멤버십 종류, 다음 결제일, 트라이얼 종료일, 일시정지/재개, 플랜 변경, 패밀리 관리, 결제 수단

#### Facetune
- 무료 체험 배너, 플랜 선택 (월/분기/연/평생), VIP 기능 목록, 구매 복원, 구독 관리

### 3-2. 공통 패턴

| 항목 | 포함 앱 |
|------|---------|
| 현재 플랜/등급 표시 | 전체 |
| 프리미엄 혜택 목록 | 전체 |
| 다음 결제일 | iCloud+, YouTube, VSCO 등 |
| 플랜 업그레이드/변경 | 전체 |
| 구독 취소 (App Store 연결) | 전체 |
| **구매 복원** | Lightroom, VSCO, Facetune (**App Store 필수**) |
| 스토리지/사용량 시각화 | iCloud+, Google One, Lightroom |
| 패밀리 플랜 관리 | iCloud+, YouTube, Spotify |

### 3-3. PickPhoto 추천 항목

**필수 (Must-Have):**

| 항목 | 이유 |
|------|------|
| **현재 플랜 표시** (Free/Pro) | 권한 범위 즉시 파악 |
| **Pro 기능 목록** | 업셀링 및 이탈 방지 |
| **플랜 업그레이드** | 수익 전환 진입점 |
| **다음 결제일** | 자동 갱신 예고 → 불만/환불 감소 |
| **구독 관리 (App Store)** | Apple 가이드라인 준수 |
| **구매 복원** | **App Store 심사 필수** (가이드라인 3.1.1) |

**권장 (Should-Have):**

| 항목 | 이유 |
|------|------|
| **무료 체험** (7일) | 첫 결제 허들 낮추기 |
| **정리 통계 요약** | Pro 가치를 수치로 체감 |
| **연간 전환 유도** | 이탈률 감소, LTV 향상 |

---

## 4. 고객센터/도움말 메뉴 조사

### 4-1. 앱별 사례

#### Google Photos
- Help Center, Send feedback (스크린샷 첨부), Report a problem, Privacy Policy, Terms of Service

#### Adobe Lightroom
- Help & Support, Community 포럼, About Lightroom, Early Access, Send feedback

#### Snapseed
- Help, Send feedback, Tutorials

#### 카카오톡
- 공지사항, FAQ (카테고리별), 1:1 문의, 고객센터 웹사이트, 이용약관, 개인정보처리방침, 오픈소스 라이선스, 앱 버전

#### 토스
- 자주 찾는 질문 (검색 우선), 채팅 상담, 전화 상담, 공지사항

#### 당근마켓
- FAQ, 문의하기, 신고하기 (별도 분리), 공지사항, 이용약관/개인정보처리방침

### 4-2. PickPhoto 추천 항목

| 항목 | 이유 |
|------|------|
| **사용 가이드** | 스와이프 삭제, 삭제대기함 등 고유 제스처 학습 |
| **FAQ** | "삭제한 사진 어디 갔나요?" 등 선제적 해소 |
| **버그 신고 / 피드백** | 기기/iOS 정보 자동 첨부로 빠른 품질 개선 |
| **기능 제안** | 사용자 니즈 수집 (버그와 분리 운영) |
| **앱 평가하기** | App Store 평점 = 신규 유입 핵심 |
| **공지사항** | 업데이트/변경사항 안내 |
| **이용약관** | **구독 시 필수** |
| **개인정보 처리방침** | **100% 필수** (Apple + 한국법) |
| **오픈소스 라이선스** | LiquidGlassKit 등 법적 의무 |
| **앱 버전 정보** | 디버깅 참조 |

---

## 5. App Store 심사 필수 항목

### 5-1. 구독(IAP) 관련 — 가이드라인 3.1.1 / 3.1.2

| 필수 항목 | 가이드라인 | 리젝 사유 |
|----------|-----------|----------|
| **구매 복원 버튼** | 3.1.1 | 구독/비소비성 IAP 있으면 무조건 필수 |
| **구독 전 5가지 정보** | 3.1.2(c) | 구독명, 기간, 가격, 자동갱신 안내, 개인정보+이용약관 링크 |
| **전체 청구금액 최대 표시** | 3.1.2 | 월 환산가만 크게 쓰고 연간 총액 숨기면 리젝 |
| **무료 체험 조건 명시** | 3.1.2 | "X일 체험 후 ₩XX,XXX 자동 청구" 문구 필수 |
| **토글 페이월 금지** (2026.01~) | 3.1.2 | 스위치로 무료 체험 숨기는 UI 리젝 |
| **취소 방법 안내** | 3.1.2 | "언제든 취소 가능" 문구 + 방법 안내 |
| **이용약관(EULA) 링크** | Schedule 2 | 구독 앱은 앱 내 탭 가능한 링크 필수 |

### 5-2. 개인정보 관련 — 가이드라인 5.1.1

| 필수 항목 | 가이드라인 | 리젝 사유 |
|----------|-----------|----------|
| **개인정보처리방침 링크 (앱 내)** | 5.1.1(i) | 모든 앱 100% 필수. 링크 깨져도 리젝 |
| **개인정보처리방침 URL (ASC)** | 5.1.1(i) | 미등록 시 제출 자체 불가 |
| **PrivacyInfo.xcprivacy** | 5.1.1 | 2024.5월부터 필수 |
| **App Privacy Nutrition Label** | 5.1.1 | ASC에서 데이터 수집 항목 선언 |
| **NSPhotoLibraryUsageDescription** | 5.1.1(ii) | 모호한 문구 리젝 |

### 5-3. 기타 필수

| 필수 항목 | 가이드라인 | 비고 |
|----------|-----------|------|
| **Support URL (ASC)** | 1.5 | 미등록 시 제출 불가 |
| **계정 삭제 기능** | 5.1.1(v) | 계정 생성 시 필수 (PickPhoto는 현재 해당 없음) |
| **Sign in with Apple** | 4.8 | 소셜 로그인 시 필수 (PickPhoto는 현재 해당 없음) |

---

## 6. 사진 앱(PhotoKit) 특화 필수사항

| 항목 | 상세 | 미대응 시 리스크 |
|------|------|---------------|
| **Limited Photo Access 처리** | `.limited` 상태에서 빈 화면/크래시 → 가이드라인 2.1 위반 | 리젝 |
| **`authorizationStatus(for: .readWrite)` 사용** | 구형 API는 `.limited`를 `.authorized`로 반환 | 기능 오동작 |
| **Limited 상태 UI 제공** | "N장 접근 중" 표시 + `presentLimitedLibraryPicker()` 버튼 | 권장(리젝 리스크) |
| **권한 거부 시 안내 화면** | 사진 접근 거부 상태에서 적절한 안내 필수 | 가이드라인 2.1 리젝 |
| **권한 요청 타이밍** | 앱 첫 실행 즉시 X → 기능 사용 직전에 요청 | 5.1.1 리젝 |
| **Vision(얼굴 인식) 기기 내 처리 명시** | 처리방침에 "기기 내에서만 처리, 외부 전송 없음" 기재 | 법적 리스크 |
| **사진 GPS 접근 시 Nutrition Label 선언** | `PHAsset.location` 사용 시 "정밀 위치" 선언 | Nutrition Label 불일치 리젝 |

### 권한 문구 예시

```
❌ "앱 사용에 사진 접근이 필요합니다." — 리젝
❌ "Photo access needed." — 리젝

✅ "사진 라이브러리의 사진을 탐색하고, 스와이프 제스처로 빠르게 정리하기 위해
    접근합니다. 사진 데이터는 기기 내에서만 처리됩니다."
```

### Privacy Manifest 예시

```xml
<!-- PrivacyInfo.xcprivacy -->
NSPrivacyAccessedAPITypes:
  - UserDefaults (CA92.1) — analytics opt-out 상태 저장
  - FileTimestamp (3B52.1) — 사진 파일 타임스탬프 접근
  - DiskSpace (7D9E.1) — 캐시 공간 확인

NSPrivacyCollectedDataTypes:
  - 사용 데이터 (앱 분석용)
  - 진단 데이터 (크래시)

NSPrivacyTrackingDomains: []
NSPrivacyTracking: false
```

### App Privacy Nutrition Label 선언 항목

| 데이터 타입 | 수집 여부 | 추적 여부 | 비고 |
|-----------|---------|---------|------|
| Photos or Videos | NO (처리만) | NO | 외부 전송 없음 |
| Precise Location (사진 GPS) | 조건부 | NO | PHAsset.location 사용 시 |
| Usage Data | YES | NO | 분석용 |
| Crash Data | YES | NO | 진단용 |
| Face Data | NO (기기 내) | NO | 외부 전송 없음 |

---

## 7. 구독 앱 필수 UI 요소

### 7-1. 페이월 필수 표시 정보

**전체 청구 금액이 가장 눈에 띄어야 함:**

```
✅ "연간 ₩59,900 청구"  ← 가장 크고 눈에 띄게
   "월 환산 ₩4,991"    ← 더 작은 크기

❌ "월 ₩4,991"만 크게 표시하고 연간 합계 숨기거나 작게 표시
```

필수 정보:
- 구독 이름, 기간, 가격 (현지화, `product.displayPrice` 사용)
- 자동갱신 조건 문구
- 취소 방법 안내
- 이용약관 링크 (앱 내 탭 가능)
- 개인정보처리방침 링크 (앱 내 탭 가능)

### 7-2. 무료 체험 필수 고지

```
"X일 무료 체험 후 월 ₩X,XXX 자동 청구. 언제든 취소 가능."
```

**2026년 1월부터 토글 페이월 리젝**: 사용자가 스위치를 켜야만 무료 체험 보이는 방식 금지

### 7-3. 구독 관리 딥링크

```swift
// StoreKit 2 (iOS 15+)
try await AppStore.showManageSubscriptions(in: scene)

// URL 방식
UIApplication.shared.open(URL(string: "https://apps.apple.com/account/subscriptions")!)
```

### 7-4. 가격 변경 동의

가격 인상이 50% 초과 + USD $5/$50 초과 시 사용자 동의 필수. Apple이 자동으로 이메일/푸시/앱 내 시트 표시.

```swift
// StoreKit 1
SKPaymentQueue.default().showPriceConsentIfNeeded()

// StoreKit 2
for await message in AppStore.messages {
    if message.reason == .priceIncreaseConsent {
        try await message.display(in: scene)
    }
}
```

### 7-5. StoreKit 2 권장 패턴

```swift
// Apple 준수 페이월 한 줄 구현
SubscriptionStoreView(groupID: "your.subscription.group.id")
// 자동 처리: 가격/기간 표시, 무료 체험, 현지화, 구독 관리 링크
```

---

## 8. 프라이버시/개인정보 필수사항

### 8-1. 한국 개인정보보호법

| 항목 | 법률 근거 | 대응 |
|------|----------|------|
| 개인정보 처리방침 공개 | 제30조 | 앱 내 설정에 링크 |
| 수집 항목/목적/기간 명시 | 제30조 | 처리방침 문서 |
| 제3자 제공 명시 | 제30조 | TelemetryDeck, Supabase 명시 |
| 보호책임자 연락처 | 제30조 | 처리방침에 기재 |
| 처리정지 요구권 (옵트아웃) | 제37조 | 분석 수집 토글 UI |
| 자동화된 의사결정 고지 | 2025년 개정 | AutoCleanup AI 기능 고지 |
| 생체정보 처리 명시 | 제23조 | 얼굴 인식 기기 내 처리 기술 |

### 8-2. 처리방침 필수 포함 내용 (한국법)

1. 개인정보의 처리 목적
2. 처리하는 개인정보 항목
3. 처리 및 보유 기간
4. 제3자 제공 여부 (TelemetryDeck, Supabase 명시)
5. 처리 업무 위탁 여부
6. 정보주체의 권리/의무 및 행사 방법
7. 보호책임자 성명/연락처
8. 변경 시 고지 방법

### 8-3. GDPR (EU 출시 시)

| 항목 | 필수 여부 |
|------|----------|
| 처리 목적 및 법적 근거 | 필수 |
| 동의 기반 분석 데이터 수집 | 필수 |
| 동의 철회(옵트아웃) | 필수 |
| 데이터 접근/삭제 요청 수단 | 필수 |

### 8-4. 분석 옵트아웃 UI

PickPhoto는 `AnalyticsService.swift`에 `isOptedOut` / `setOptOut()` 구현 완료. **UI 연결 필요:**

```
설정 > 개인정보 > 사용 분석 데이터 수집 [토글]
```

### 8-5. 얼굴 인식 고지 문구 (처리방침 포함)

```
"얼굴 인식 기술은 사진 내 얼굴을 자동으로 감지하고 확대하는 데 사용됩니다.
 감지된 얼굴 데이터는 기기 내에서만 처리되며, 저장되거나 외부로 전송되지 않습니다."
```

---

## 9. 실제 리젝 사례

### 9-1. 리젝 규모

2024년 Apple: **777만 건 심사, 193만 건(25%) 리젝**

### 9-2. 주요 사례 & Apple 실제 메시지

| # | 사유 | Apple 메시지 | 가이드라인 | 해결 |
|---|------|------------|-----------|------|
| 1 | 개인정보처리방침 링크 누락 | "does not include a privacy policy linked to from within the app" | 5.1.1(i) | 설정에 1~2탭 내 링크 |
| 2 | 구매 복원 버튼 없음 | "does not include a 'Restore Purchases' feature" | 3.1.1 | 페이월+설정에 버튼 |
| 3 | 계정 삭제 미제공 | "supports account creation but does not include deletion" | 5.1.1(v) | 마이페이지→계정삭제 |
| 4 | 구독 정보 불충분 | "does not include link to EULA and Privacy Policy within the app binary" | 3.1.2 | 페이월 내 링크 직접 삽입 |
| 5 | 권한 문구 불충분 | "purpose string does not clearly explain why access is needed" | 5.1.1 | 구체적 목적 문구 수정 |
| 6 | 고객지원 URL 깨짐 | "support URL does not properly navigate to the intended destination" | 1.5 | 접근 가능한 URL 교체 |

### 9-3. Halide 카메라 앱 사건 (2024.09)

- Apple 디자인 어워드 수상 + iPhone 16 키노트 소개 앱
- "카메라 앱이 왜 카메라가 필요한지 설명 불충분"으로 리젝
- Apple이 "심사 실수" 인정, 수정 없이 재제출 통과
- **교훈**: 명백한 경우에도 리젝 가능 → 권한 문구 최대한 구체적으로

### 9-4. 한국 개발자 특화 리젝 사유

| 사유 | 상세 | 가이드라인 |
|------|------|-----------|
| **Apple 로그인 미포함** | 카카오/네이버 로그인만 → 필수 리젝 | 4.8 |
| **PASS 본인인증 추가 요구** | Apple 로그인 + 추가 인증 → 리젝 | 4.8 |
| **타 플랫폼 언급** | "구글 플레이에서 검색" 문구 → 즉각 리젝 | 2.3.1 |
| **인앱 결제 우회** | "외부 결제 시 할인" 문구 → 리젝 | 3.1.1 |
| **불필요한 개인정보 필수 수집** | 앱과 무관한 성별/주소 필수 → 리젝 | 5.1.1 |

### 9-5. 2024-2026 리젝 트렌드

- **AI 심사 병행**: 기존에 통과하던 앱도 갑자기 리젝
- **PrivacyInfo.xcprivacy 필수화** (2024.05~)
- **토글 페이월 금지** (2026.01~)
- **계정 삭제 지속 강화**: "비활성화 ≠ 삭제"

---

## 10. Apple HIG 설정 메뉴 패턴

### 10-1. Settings Bundle vs 앱 내 설정

| 변경 빈도 | 위치 | 예시 |
|----------|------|------|
| 자주 변경 | **앱 내 설정** | 그리드 열 수, 삭제 감도, 얼굴 인식 ON/OFF |
| 거의 안 변경 | **Settings Bundle** | 분석 수집 동의, 디버그 모드 |

### 10-2. 시스템 설정 딥링크 (공식 API만)

```swift
// ✅ 공식 (안전)
UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)

// ❌ 비공식 (app-settings:// 등) — 미래 iOS 동작 보장 안 됨
```

### 10-3. 접근성 필수 항목

| 항목 | 필수 여부 | PickPhoto 대응 |
|------|----------|---------------|
| **VoiceOver 레이블** | 필수 | 모든 인터랙티브 요소에 `accessibilityLabel` |
| **스와이프 대체 액션** | **필수** (핵심!) | `accessibilityCustomActions`로 삭제 대안 제공 |
| **터치 타겟 44x44pt** | 필수 | 버튼/셀 최소 크기 |
| **색상 대비 4.5:1** | 필수 | 텍스트/배경 대비 검증 |
| **Dynamic Type** | 실질적 필수 | `preferredFont(forTextStyle:)` 사용 |
| **다크모드** | 강력 권장 | Semantic Color 사용 |
| **Reduce Motion** | 권장 | 애니메이션 → crossfade 대체 |

### 10-4. iOS 26 Liquid Glass 대응

| 시기 | 요구사항 |
|------|---------|
| **2026년 4월 28일** | App Store 제출 시 **Xcode 26 (iOS 26 SDK) 필수** |
| 자동 적용 | UINavigationBar, UITabBar → Liquid Glass 자동 |
| 수동 대응 필요 | FloatingTabBar (커스텀) → glassEffect 적용 |
| 옵트아웃 | 현재 가능, Xcode 27 이후 제거 예정 |

### 10-5. 앱 정보(About) 필수 항목

| 항목 | 필수/권장 | 근거 |
|------|----------|------|
| **개인정보처리방침** | 필수 | App Store 심사 |
| **오픈소스 라이선스** | 필수 | 법적 의무 (LiquidGlassKit 등) |
| 앱 버전/빌드 | 강력 권장 | 버그 신고 참조 |
| 저작권 표시 | 권장 | 법적 보호 |
| 문의/지원 링크 | 권장 | UX |

---

## 11. PickPhoto 최종 메뉴 권장안

### 설정 메뉴

```
설정
├── 사진 정리
│   ├── 삭제대기함 자동 비우기
│   ├── 스와이프 삭제 감도
│   └── 유사 사진 분석 자동 실행
├── 개인정보
│   ├── 사용 분석 데이터 수집 [토글]  ← 한국법 필수
│   ├── 데이터 삭제 요청 (이메일/폼)  ← GDPR/한국법
│   └── 개인정보 처리방침 → [링크]    ← App Store 필수
├── 접근 권한
│   └── 사진 라이브러리 → [iOS 설정 딥링크]
├── 저장공간 사용 현황
├── 정리 통계 (정리한 사진 수 / 확보한 공간)
├── 테마 (다크/라이트/시스템)
└── 앱 잠금 (Face ID)
```

### 구독/결제 메뉴

```
구독 관리
├── [현재 플랜 배지]  Free / Pro
├── Pro 기능 목록
├── 플랜 업그레이드 (페이월)
│   ├── 구독명 + 기간 + 가격 (전체 청구액 최대 표시)
│   ├── 자동갱신 안내 문구
│   ├── 무료 체험 조건 (항상 노출, 토글 금지)
│   ├── 취소 방법 안내 문구
│   ├── 이용약관 링크           ← 구독 시 필수
│   └── 개인정보처리방침 링크   ← 필수
├── 다음 결제일
├── 연간 전환 유도 ("30% 절약")
├── 이번 달 정리 통계
├── 구독 관리 (App Store)
├── 구매 복원                   ← App Store 심사 필수
└── 패밀리 공유 안내
```

### 도움말 메뉴

```
도움말
├── 사용 가이드
├── 자주 묻는 질문 (FAQ)
├── 버그 신고 / 피드백 (기기정보 자동 첨부)
├── 기능 제안
├── 앱 평가하기 (App Store 리뷰)
├── 공지사항
├── 이용약관                    ← 구독 시 필수
├── 개인정보 처리방침           ← 100% 필수
├── 오픈소스 라이선스           ← 법적 필수
└── 앱 버전 정보
```

---

## 12. 핵심 체크리스트

### 빠뜨리면 100% 리젝

| # | 항목 | 가이드라인 |
|---|------|-----------|
| 1 | 개인정보처리방침 (앱 내 링크 + ASC URL) | 5.1.1(i) |
| 2 | 구매 복원 버튼 (구독 도입 시) | 3.1.1 |
| 3 | PrivacyInfo.xcprivacy 파일 | 5.1.1 |
| 4 | 구독 전 5가지 정보 표시 (구독 도입 시) | 3.1.2(c) |
| 5 | Support URL (ASC) | 1.5 |

### 빠뜨리면 리젝 가능성 높음

| # | 항목 | 가이드라인 |
|---|------|-----------|
| 6 | Limited Photo Access (.limited) 처리 | 2.1 |
| 7 | 권한 거부 시 안내 화면 | 2.1 |
| 8 | 구체적인 NSPhotoLibraryUsageDescription | 5.1.1(ii) |
| 9 | App Privacy Nutrition Label 정확 선언 | 5.1.1 |
| 10 | 토글 페이월 사용 금지 (2026.01~) | 3.1.2 |

### 법적 필수 (한국법)

| # | 항목 | 법률 |
|---|------|------|
| 11 | 개인정보 처리방침 앱 내 공개 | 개인정보보호법 제30조 |
| 12 | 분석 데이터 옵트아웃 토글 | 개인정보보호법 제37조 |
| 13 | 제3자 제공 명시 (TelemetryDeck, Supabase) | 개인정보보호법 제30조 |
| 14 | 보호책임자 연락처 | 개인정보보호법 제30조 |
| 15 | 얼굴 인식 기기 내 처리 명시 | 개인정보보호법 제23조 |

### PickPhoto 특화 중요 발견

| # | 항목 | 비고 |
|---|------|------|
| 16 | VoiceOver 스와이프 대체 액션 | 핵심 제스처의 접근성 대안 필수 |
| 17 | 2026년 4월 28일 Xcode 26 SDK 데드라인 | Liquid Glass 자동 적용 |
| 18 | FloatingTabBar 수동 Liquid Glass 대응 | 커스텀 UI라 자동 적용 안 됨 |
| 19 | AutoCleanup AI 자동화 의사결정 고지 | 2025년 한국법 개정 |
| 20 | 삭제대기함 FAQ 강조 배치 | Undo 기반 삭제가 일반 앱과 달라 혼란 가능 |

---

## 참고 자료

### Apple 공식
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Auto-renewable Subscriptions](https://developer.apple.com/app-store/subscriptions/)
- [App Privacy Details](https://developer.apple.com/app-store/app-privacy-details/)
- [Privacy Manifest Files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Delivering an Enhanced Privacy Experience in Photos App](https://developer.apple.com/documentation/PhotoKit/delivering-an-enhanced-privacy-experience-in-your-photos-app)
- [Settings - HIG](https://developer.apple.com/design/human-interface-guidelines/settings)
- [Accessibility - HIG](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Liquid Glass](https://developer.apple.com/documentation/TechnologyOverviews/liquid-glass)
- [Upcoming Requirements](https://developer.apple.com/news/upcoming-requirements/)

### 리젝 사례/가이드
- [App Store Review Guidelines Checklist 2025 - NextNative](https://nextnative.dev/blog/app-store-review-guidelines)
- [Ultimate Guide to App Store Rejections - RevenueCat](https://www.revenuecat.com/blog/growth/the-ultimate-guide-to-app-store-rejections/)
- [Halide Rejection - 9to5Mac](https://9to5mac.com/2024/09/24/halide-rejected-from-the-app-store/)
- [Guideline 3.1.2 Fix - AngularCorp](https://www.angularcorp.com/en/insights/apple-guideline-3-1-2-subscription-rejection-missing-links/)
- [Toggle Paywall Killed - RevenueCat](https://www.revenuecat.com/blog/growth/r-i-p-toggle-paywall-we-hardly-knew-ye/)

### 구독/결제
- [Paywall App Review - RevenueCat](https://www.revenuecat.com/docs/tools/paywalls/creating-paywalls/app-review)
- [StoreKit 2 WWDC25](https://developer.apple.com/videos/play/wwdc2025/241/)
- [Restore Purchase - Adapty](https://adapty.io/blog/what-does-restore-purchase-mean/)

### 한국법/프라이버시
- [개인정보보호위원회 처리방침 작성지침 (2025.4)](https://www.privacy.go.kr/)
- [Mobile App Consent iOS 2025 - SecurePrivacy](https://secureprivacy.ai/blog/mobile-app-consent-ios-2025)
- [GDPR Compliance Mobile Apps - SecurePrivacy](https://secureprivacy.ai/blog/gdpr-compliance-mobile-apps)

### 한국 개발자 리젝 가이드
- [앱스토어 리젝 대표 사례 - 스윙투앱](https://documentation.swing2app.co.kr/knowledgebase/appstore/reject)
- [앱스토어 대표 리젝 사유 5가지 - thebackend](https://blog.thebackend.io/)

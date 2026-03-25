# SweepPic 앱스토어 등록 가이드

> 작성일: 2026-02-11
> 목적: iOS 앱스토어 제출을 위한 전체 요구사항 정리 및 SweepPic 현재 상태 대조

---

## 목차

1. [등록 절차 개요](#1-등록-절차-개요)
2. [Apple Developer Program](#2-apple-developer-program)
3. [App Store Review Guidelines 전체 요구사항](#3-app-store-review-guidelines-전체-요구사항)
4. [기술적 요구사항](#4-기술적-요구사항)
5. [App Store Connect 메타데이터](#5-app-store-connect-메타데이터)
6. [프라이버시 전체 요구사항](#6-프라이버시-전체-요구사항)
7. [접근성 요구사항](#7-접근성-요구사항)
8. [현지화 및 한국 특별 요구사항](#8-현지화-및-한국-특별-요구사항)
9. [보안 및 수출 규정](#9-보안-및-수출-규정)
10. [테스트 관련 요구사항](#10-테스트-관련-요구사항)
11. [SweepPic 현재 상태 점검](#11-sweeppic-현재-상태-점검)
12. [사진 앱 리젝 사례 분석](#12-사진-앱-리젝-사례-분석)
13. [Review Notes 작성 가이드 (SweepPic용)](#13-review-notes-작성-가이드-sweeppic용)
14. [App Privacy Details 실전 응답 가이드](#14-app-privacy-details-실전-응답-가이드)
15. [Guideline 4.2 방어 전략](#15-guideline-42-방어-전략)
16. [ITMS 오류 코드 대응표](#16-itms-오류-코드-대응표)
17. [심사 프로세스 실전 가이드](#17-심사-프로세스-실전-가이드)
18. [SweepPic 실행 계획](#18-sweeppic-실행-계획)
19. [Apple 공식 참고 문서](#19-apple-공식-참고-문서)

---

## 1. 등록 절차 개요

| 순서 | 단계 | 설명 |
|:----:|------|------|
| 1 | Apple Developer Program 가입 | 연회비 결제, 2단계 인증 활성화 |
| 2 | 인증서/서명 설정 | Xcode Automatic Signing 또는 수동 인증서 |
| 3 | App Store Connect 설정 | 앱 생성, 메타데이터 입력, 프라이버시 설문 |
| 4 | 빌드 업로드 | Xcode > Product > Archive > Distribute App |
| 5 | 심사 제출 | Submit for Review (보통 24~48시간) |
| 6 | 출시 | 즉시 출시 또는 수동 출시 선택 |

---

## 2. Apple Developer Program

### 2-1. 비용

| 구분 | 비용 |
|------|------|
| 연회비 (미국) | USD $99/년 |
| 연회비 (한국) | 129,000원/년 |
| 비영리/교육기관 | 수수료 면제 신청 가능 |

### 2-2. 개인 vs 조직

| 항목 | 개인 (Individual) | 조직 (Organization) |
|------|-------------------|---------------------|
| 필요 서류 | Apple ID + 실명 확인 | Apple ID + D-U-N-S 번호 + 법인 정보 |
| 앱스토어 표시 이름 | 개인 실명 | 회사명 |
| 팀원 관리 | 불가 | 여러 개발자 초대 가능 |
| 한국 배포 추가 요건 | 이메일, 사업자등록번호 (BRN) | 회사명, 이메일, 전화번호, 사업자등록번호 |

> **한국 컴플라이언스**: 한국 기반 계정은 **Individual/Organization 모두** 전자상거래소비자보호법에 따른 식별 정보 제공 대상. ([근거](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-korea-compliance-information))
>
> **D-U-N-S 번호**: Dun & Bradstreet 발급 사업자 고유번호. 무료 신청 (발급 최대 30일). Apple Developer 포털에서 직접 조회/신청 가능.

---

## 3. App Store Review Guidelines 전체 요구사항

> 공식 URL: https://developer.apple.com/app-store/review/guidelines/

### Section 1: Safety (안전)

| 번호 | 제목 | 핵심 내용 | 구분 |
|------|------|-----------|:----:|
| 1.1 | Objectionable Content | 공격적/부적절/불쾌한 콘텐츠 금지 | 필수 |
| 1.1.1 | 비방/차별 | 종교, 인종, 성별, 국적 등 비방/차별 금지 | 필수 |
| 1.1.2 | 사실적 폭력 묘사 | 살인, 고문, 학대의 사실적 묘사 금지 | 필수 |
| 1.1.3 | 무기 관련 | 불법/무모한 무기 사용 조장 금지 | 필수 |
| 1.1.4 | 성적 콘텐츠 | 노골적 성적/포르노 콘텐츠 금지 | 필수 |
| 1.1.5 | 종교 관련 | 선동적 종교 논평, 부정확한 인용 금지 | 필수 |
| 1.1.6 | 허위 정보 | 가짜 추적기, 장난/속임수 기능 금지 | 필수 |
| 1.1.7 | 현재 사건 악용 | 폭력/테러/전염병 등 최근 사건 악용 금지 | 필수 |
| 1.2 | User-Generated Content | UGC 앱은 필터링/신고/차단/연락처 필수 | 해당시 |
| 1.3 | Kids Category | 앱 밖 링크 금지, 아동 프라이버시법 준수 | 해당시 |
| 1.4 | Physical Harm | 신체적 위해 초래 앱 거부 | 필수 |
| 1.4.1 | 의료 앱 | 데이터/방법론 공개, 센서만으로 측정 앱 불가 | 해당시 |
| 1.4.3 | 물질 관련 | 담배/전자담배/불법약물/과음 조장 금지 | 필수 |
| 1.4.5 | 위험한 활동 | 신체적 위험 조장 금지 | 필수 |
| 1.5 | Developer Information | 앱 내 연락 방법 + 지원 URL에 연락처 필수 | 필수 |
| 1.6 | Data Security | 사용자 정보 보안 조치 구현 필수 | 필수 |

### Section 2: Performance (성능)

| 번호 | 제목 | 핵심 내용 | 구분 |
|------|------|-----------|:----:|
| 2.1 | App Completeness | 최종 버전 제출, 크래시/플레이스홀더 금지 | 필수 |
| 2.2 | Beta Testing | 데모/베타 버전은 TestFlight 전용 | 필수 |
| 2.3 | Accurate Metadata | 메타데이터가 실제 앱과 정확히 일치 | 필수 |
| 2.3.1 | 숨겨진 기능 금지 | 모든 기능을 Review Notes에 설명 | 필수 |
| 2.3.3 | 스크린샷 | 실제 앱 사용 화면 표시 필수 | 필수 |
| 2.3.5 | 카테고리 선택 | 가장 적절한 카테고리 선택 | 필수 |
| 2.3.6 | 연령 등급 | 정직하게 답변 | 필수 |
| 2.3.7 | 앱 이름/키워드 | 30자 제한, 부적절한 키워드/상표명 금지 | 필수 |
| 2.3.8 | 전체 연령 적합성 | 아이콘/스크린샷은 4+ 기준 | 필수 |
| 2.3.12 | What's New | 변경사항 명확히 설명 | 업데이트시 |
| 2.4.1 | iPhone/iPad 호환 | iPhone 앱은 iPad에서도 실행 권장 | 권장 |
| 2.4.2 | 전력 효율 | 배터리 과소모, 과열, 리소스 부담 금지 | 필수 |
| 2.5.1 | 공개 API만 사용 | 비공개 API 사용 금지 | 필수 |
| 2.5.2 | 자체 완결 번들 | 외부 코드 다운로드 금지 | 필수 |
| 2.5.4 | 멀티태스킹 | 백그라운드는 의도된 목적에만 사용 | 필수 |
| **2.5.5** | **IPv6 지원** | **IPv6 전용 네트워크에서 완전 기능 필수** | **필수** |
| 2.5.14 | 녹음/기록 동의 | 카메라/마이크 사용 시 명시적 동의 필수 | 필수 |

### Section 3: Business (비즈니스)

| 번호 | 제목 | 핵심 내용 | 구분 |
|------|------|-----------|:----:|
| 3.1.1 | In-App Purchase | 디지털 콘텐츠/기능 잠금해제에 IAP 필수 | 해당시 |
| 3.1.2 | Subscriptions | 자동 갱신 구독 규칙 (기간 7일 이상 등) | 해당시 |
| 3.2.2 | 금지 사항 | 앱스토어 유사 UI, 평가/리뷰 강제 금지 | 필수 |

### Section 4: Design (디자인)

| 번호 | 제목 | 핵심 내용 | 구분 |
|------|------|-----------|:----:|
| 4.1 | Copycats | 독창적 아이디어, 인기 앱 복제 금지 | 필수 |
| 4.2 | Minimum Functionality | 웹사이트 래퍼 이상의 기능 필수 | 필수 |
| 4.2.3 | 독립 동작 | 다른 앱 설치 없이 독립 동작 | 필수 |
| 4.3 | Spam | 동일 앱 복수 Bundle ID 금지 | 필수 |
| 4.5.4 | Push Notifications | 프로모션은 옵트인 필수 | 해당시 |
| 4.8 | Login Services | 제3자 로그인 시 Sign in with Apple 등 대안 필수 | 해당시 |
| 4.10 | Built-In Capabilities 수익화 | OS 내장 기능 수익화 금지 | 필수 |

### Section 5: Legal (법률)

| 번호 | 제목 | 핵심 내용 | 구분 |
|------|------|-----------|:----:|
| **5.1.1** | **데이터 수집/저장** | **프라이버시 정책 필수 (앱 내 + App Store Connect)** | **필수** |
| 5.1.1(v) | 계정 삭제 | 계정 생성 앱은 앱 내 삭제 옵션 필수 | 해당시 |
| 5.1.2 | 데이터 사용/공유 | ATT로 추적 허가, 민감 데이터 타겟팅 금지 | 필수 |
| 5.2.1 | 제3자 자료 | 보호된 상표/저작권/특허 허가 없이 사용 금지 | 필수 |
| 5.2.4 | Apple 보증 | Apple이 앱을 보증한다는 암시 금지 | 필수 |

---

## 4. 기술적 요구사항

### 4-1. SDK 및 Xcode 버전

| 항목 | 요구사항 | 시행일 | 구분 |
|------|---------|--------|:----:|
| 현재 | Xcode 16 + iOS 18 SDK | 2025.04.24~ | 필수 |
| **차기** | **Xcode 26 + iOS 26 SDK** | **2026.04.28~** | **필수** |

### 4-2. 바이너리 크기 제한

| 항목 | 제한 |
|------|------|
| iOS 앱 최대 크기 (비압축) | 4 GB |
| 실행 파일 __TEXT 섹션 합계 | 80 MB (아키텍처 슬라이스별 60 MB) |
| 셀룰러 다운로드 기본 확인 | 200 MB 초과 시 사용자에게 확인 팝업 (기본값). 사용자가 설정 > App Store > Always Allow로 해제 가능. **제출 요건 아님** |

### 4-3. 아키텍처

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| arm64 (64비트) | 모든 iOS 앱 필수 | 필수 |
| Bitcode | Xcode 16부터 완전 제거 (불필요) | - |

### 4-4. 네트워크

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| IPv6 지원 | IPv6 전용 네트워크에서 완전 기능 | 필수 |
| ATS | HTTPS 기본, TLS 1.2 이상, SHA-256 이상 | 필수 |

### 4-5. UI/화면

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| Launch Screen | Storyboard 또는 Info.plist 구성으로 제공 | 필수 |
| 모든 iPhone 화면 크기 지원 | 다양한 iPhone 화면에 대응 | 필수 |

### 4-6. Info.plist 필수 키

| 키 | 용도 | 구분 |
|----|------|:----:|
| UILaunchStoryboardName | Launch Screen 지정 | 필수 |
| UIRequiredDeviceCapabilities | 앱이 특정 하드웨어에 의존할 때만 선언 (불필요한 값 추가 시 설치 가능 기기 감소) | 해당시 |
| ITSAppUsesNonExemptEncryption | 수출 규정 암호화 신고. 미설정 시 매 제출마다 App Store Connect에서 수동 답변 필요 | 강력 권장 |
| NSPhotoLibraryUsageDescription | 사진 라이브러리 접근 사유 | 사진 앱 필수 |
| UIBackgroundModes | 사용하지 않으면 선언하지 말 것 | 주의 |

### 4-7. 배경 모드 규칙

- 선언한 배경 모드를 **실제로 사용하는 기능이 있어야** 함
- 사용하지 않는 배경 모드를 선언하면 **거부 사유**

---

## 5. App Store Connect 메타데이터

> 공식 속성 목록: https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties

### 5-1. 앱 정보 (App Information)

| 항목 | 필수 | 현지화 | 제한 |
|------|:----:|:------:|------|
| **Name (앱 이름)** | O | O | 30자 |
| **Bundle ID** | O | - | 변경 불가 |
| **SKU** | O | - | 변경 불가 |
| **Primary Language** | O | - | - |
| **Primary Category** | O | - | - |
| **Rating (연령 등급)** | O | - | 설문 기반 |
| **Content Rights** | O | - | 제3자 콘텐츠 사용 여부 |
| **DSA Status** | O | - | EU 배포 시 |
| Subtitle (부제목) | - | O | 30자 |
| Secondary Category | - | - | - |
| License Agreement | - | - | 커스텀 가능 |

### 5-2. 플랫폼 버전 정보

| 항목 | 필수 | 현지화 | 제한 |
|------|:----:|:------:|------|
| **Screenshots** | O | O | 1~10장, JPEG/PNG |
| **Description** | O | O | 4,000자, 순수 텍스트 |
| **Keywords** | O | O | 100바이트, 쉼표 구분 |
| **Support URL** | O | O | 실제 연락처 포함 필수 |
| **Copyright** | O | - | "2026 회사명" 형식 |
| **Version Number** | O | - | - |
| **What's New** | O* | O | 4,000자 (*업데이트시 필수) |
| Promotional Text | - | O | 170자, 심사 없이 수정 가능 |
| Marketing URL | - | - | - |
| App Preview | - | O | 15~30초, H.264/ProRes, 최대 500MB |

### 5-3. 심사 정보 (App Review Information)

| 항목 | 필수 | 설명 |
|------|:----:|------|
| **연락처 (이름/이메일/전화)** | O | 심사팀 문의용 |
| Review Notes | - | 4,000바이트, 비명시적 기능 설명 |
| **데모 계정** | O* | *로그인 필요 앱만. 만료 불가 |

### 5-4. 가격 및 배포

| 항목 | 필수 |
|------|:----:|
| **Availability (배포 국가)** | O |
| **Price (가격)** | O |
| **Tax Category** | O |

### 5-5. 프라이버시

| 항목 | 필수 |
|------|:----:|
| **Privacy Policy URL** | O |
| **Data Types (수집 데이터)** | O |

### 5-6. 접근성

| 항목 | 필수 | 현지화 |
|------|:----:|:------:|
| **Accessibility Support** | 현재 선택 (향후 필수 예정) | O |

### 5-7. 스크린샷 사양

**iPhone (6.9" 또는 6.5" 중 하나 필수)**

| 화면 크기 | 해상도 (세로) | 필수 여부 | 대상 기기 |
|-----------|-------------|:---------:|----------|
| **6.9"** | 1320 x 2868 | 둘 중 하나 | iPhone 17 Pro Max, iPhone 16 Pro Max |
| **6.7"** | 1290 x 2796 | 대체 가능 | iPhone 15 Pro Max, 16 Plus |
| **6.5"** | 1284 x 2778 | 둘 중 하나 | iPhone 14 Pro Max |
| 6.3" | 1179 x 2556 | 자동 축소 | iPhone 17 Pro, 15 Pro |
| 6.1" | 1170 x 2532 | 자동 축소 | iPhone 14 |
| **6.3" (Air)** | 1218 x 2640 | 자동 축소 | iPhone Air |
| 5.5" | 1242 x 2208 | 자동 축소 | iPhone 8 Plus |

> **2026년 기준**: iPhone 17 시리즈, iPhone Air 추가. 6.9" 스크린샷(1320x2868)이 최신 Pro Max에 대응.

**iPad (iPad 앱이면 필수)**

| 화면 크기 | 해상도 (세로) | 대상 기기 |
|-----------|-------------|----------|
| **13"** | 2064 x 2752 | iPad Pro M4/M5, iPad Air 13" |

- 형식: JPEG, PNG
- 수량: 기기당 1~10장
- 미제공 크기는 상위 크기에서 자동 축소

### 5-8. 앱 아이콘 사양

| 항목 | 요구사항 |
|------|---------|
| 크기 | **1024 x 1024 px** |
| 형식 | **PNG** (JPEG/GIF 불가) |
| 투명도 | **불투명 필수** (알파 채널/투명 영역 없음) |
| 모양 | 정사각형 (모서리 라운딩 Apple이 자동 적용) |
| 색상 공간 | sRGB 또는 Display P3 |

### 5-9. 연령 등급 설문 카테고리

> 2026.01.31까지 새 양식 응답 필수

| # | 카테고리 | 항목 예시 |
|---|---------|----------|
| 1 | 인앱 컨트롤 | 보호자 통제, 연령 확인 |
| 2 | 기능 | 웹 접근, UGC, 메시징, 광고 |
| 3 | 성숙한 주제 | 비속어, 공포, 약물 |
| 4 | 의료/웰니스 | 의료 정보, 건강 주제 |
| 5 | 성적 표현/누드 | 암시적 주제, 성적 콘텐츠 |
| 6 | 폭력 | 만화/사실적 폭력, 무기 |
| 7 | 확률 기반 활동 | 도박, 루트박스 |

**결과 등급**: 4+ / 9+ / 13+ / 16+ / 18+
**한국 전용**: 전체이용가 / 12+ / 15+ / 19+

### 5-10. 수출 규정 (Export Compliance)

| 항목 | 설명 | 구분 |
|------|------|:----:|
| ITSAppUsesNonExemptEncryption | Info.plist에 설정 | 필수 |
| HTTPS/URLSession 사용 | OS 내장 암호화 → 면제 | - |
| 독점 암호화 알고리즘 | 수출 문서 제출 필요 | 해당시 |

### 5-11. 콘텐츠 권리 (Content Rights)

| 항목 | 설명 | 구분 |
|------|------|:----:|
| 제3자 콘텐츠 사용 여부 | 포함 시 사용 권리 확인 | 필수 |

---

## 6. 프라이버시 전체 요구사항

### 6-1. Privacy Manifest (PrivacyInfo.xcprivacy)

> **단계별 시행:**
> - 2024-03-13: Required Reason API 누락 시 경고 이메일 발송
> - 2024-05-01: Required Reason API 사유 선언 필수 + 새로 추가하는 서드파티 SDK에 privacy manifest/서명 필수
> - 2024-11-12: 기존 포함 SDK까지 유효한 privacy manifest 검증 확대 적용
> - **2025-02-12: Privacy-impacting SDK에 Privacy Manifest 미포함 시 ITMS-91061 오류로 업로드 차단 (현재 시행 중)**
>
> ([근거: TN3181](https://developer.apple.com/documentation/technotes/tn3181-debugging-an-invalid-privacy-manifest))
>
> **⚠️ ITMS-91061 주의**: 앱이 사용하는 모든 서드파티 SDK(BlurUIKit, LiquidGlassKit 등)에 유효한 Privacy Manifest가 포함되어야 함. SDK 제작자가 미제공 시 앱 개발자가 직접 해당 SDK 번들 내에 PrivacyInfo.xcprivacy를 추가해야 함.

**파일 구조:**

| 키 | 설명 | 필수 여부 |
|----|------|----------|
| NSPrivacyTracking | ATT 정의에 따른 추적 여부 (Boolean) | 추적 시 `true`, 안 하면 키 생략 가능 |
| NSPrivacyTrackingDomains | 추적 도메인 목록 | 추적 도메인이 있을 때만 |
| NSPrivacyCollectedDataTypes | 수집 데이터 타입 배열 | 데이터를 수집하는 경우에만 |
| NSPrivacyAccessedAPITypes | 필수 사유 API 배열 | Required Reason API 사용 시에만 |

> 각 키는 **해당 행위를 할 때만 선언** (opt-in 방식). Apple은 사용하지 않는 키는 제거를 안내.

**수집 데이터 선언 구조 (각 데이터 타입별):**

```xml
<dict>
    <key>NSPrivacyCollectedDataType</key>
    <string>NSPrivacyCollectedDataTypePhotos</string>
    <key>NSPrivacyCollectedDataTypeLinked</key>       <!-- 사용자 신원과 연결 여부 -->
    <false/>
    <key>NSPrivacyCollectedDataTypeTracking</key>     <!-- 추적 목적 사용 여부 -->
    <false/>
    <key>NSPrivacyCollectedDataTypePurposes</key>     <!-- 사용 목적 -->
    <array>
        <string>NSPrivacyCollectedDataTypePurposeAppFunctionality</string>
    </array>
</dict>
```

### 6-2. Required Reason API (5개 카테고리)

| # | 카테고리 | API 타입 키 | 주요 사유 코드 |
|---|---------|------------|--------------|
| 1 | **파일 타임스탬프** | NSPrivacyAccessedAPICategoryFileTimestamp | `DDA9.1` 앱 컨테이너 내 접근 / `C617.1` 사용자에게 표시 / `3B52.1` 검색 / `0A2A.1` 내부 파일 접근 |
| 2 | **시스템 부팅 시간** | NSPrivacyAccessedAPICategorySystemBootTime | `35F9.1` 경과 시간 측정 / `8FFB.1` 타이머 / `3D61.1` 부팅 시간 확인 |
| 3 | **디스크 공간** | NSPrivacyAccessedAPICategoryDiskSpace | `85F4.1` 표시 / `E174.1` 쓰기 확인 / `7D9E.1` 앱 기능 / `B728.1` 사용자에게 표시 |
| 4 | **활성 키보드** | NSPrivacyAccessedAPICategoryActiveKeyboards | `3EC4.1` 커스텀 키보드 / `54BD.1` 활성 키보드 결정 |
| 5 | **UserDefaults** | NSPrivacyAccessedAPICategoryUserDefaults | `CA92.1` 앱 자체 접근 / `1C8F.1` App Group 공유 / `C56D.1` 제3자 SDK / `AC6B.1` MDM 구성 |

### 6-3. 데이터 최소화 원칙 (Guideline 5.1.1(iii))

> **사진 앱 특히 주의**: Apple은 "가능하면 PHPicker를 사용하라"고 명시. 전체 사진 접근(`PHAuthorizationStatus.authorized`)을 요구하는 앱은 Review Notes에서 그 이유를 설득해야 함.

| 접근 방식 | 설명 | 심사 부담 |
|----------|------|:---------:|
| PHPicker | 사용자가 선택한 사진만 접근. 추가 권한 불필요 | 낮음 |
| Limited Access | `.limited` 상태. 사용자가 선택한 사진만 노출 | 중간 |
| Full Access | `.authorized` 상태. 전체 라이브러리 접근 | **높음 — 사유 필요** |

**SweepPic 정당화 논거**: 전체 라이브러리 정리가 핵심 목적이므로 PHPicker로는 불가. → Section 13 Review Notes 참조

### 6-4. 얼굴 데이터 사용 제한 (Guideline 5.1.2(vi))

> Photo APIs, 카메라, ARKit 등으로 수집한 **얼굴 매핑/데이터**는 마케팅, 광고, 데이터마이닝에 사용 금지.

| 항목 | SweepPic 해당 여부 |
|------|:-----------------:|
| Vision Framework 얼굴 인식 사용 | **O** |
| 얼굴 데이터 외부 전송 | X (온디바이스 전용) |
| 마케팅/광고 활용 | X |
| 데이터마이닝 활용 | X |

> SweepPic는 얼굴 인식 결과를 뷰어에서 자동 줌에만 사용하고, 기기 밖으로 전송하지 않으므로 **준수 상태**. Privacy Policy에 이를 명시해야 함.

### 6-5. App Tracking Transparency (ATT)

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| ATT 프레임워크 | IDFA 접근 또는 사용자 추적 시 허가 요청 | 해당시 |
| NSUserTrackingUsageDescription | 사용 목적 기재 | 해당시 |
| 추적 거부 시 | 앱 기능 동일하게 제공 | 필수 |

### 6-6. App Privacy Details (영양 라벨) 전체 데이터 타입

**15개 카테고리, 32개 하위 타입:**

| # | 카테고리 | 데이터 타입 |
|---|---------|-----------|
| 1 | 연락처 정보 | 이름, 이메일, 전화번호, 실제 주소, 기타 |
| 2 | 건강 및 피트니스 | 건강, 피트니스 |
| 3 | 금융 정보 | 결제, 신용, 기타 금융 |
| 4 | 위치 | 정밀 위치, 대략적 위치 |
| 5 | 민감 정보 | 민감 정보 |
| 6 | 연락처 | 연락처 |
| 7 | **사용자 콘텐츠** | 이메일/문자, **사진/동영상**, 오디오, 게임플레이, 고객 지원, 기타 |
| 8 | 검색 기록 | 브라우징, 검색 |
| 9 | 식별자 | 사용자 ID, 기기 ID |
| 10 | 구매 | 구매 기록 |
| 11 | 사용 데이터 | 제품 상호작용, 광고, 기타 |
| 12 | 진단 | 크래시, 성능, 기타 |
| 13 | 주변 환경 | 환경 스캐닝 |
| 14 | 신체 | 손, 머리 |
| 15 | 기타 | 기타 데이터 |

**데이터 사용 목적 (6가지):**
1. 제3자 광고
2. 개발자 광고/마케팅
3. 분석
4. 제품 개인화
5. 앱 기능
6. 기타 목적

### 6-7. 프라이버시 정책 필수 요건

| 항목 | 설명 |
|------|------|
| **게재 위치** | App Store Connect 메타데이터 + 앱 내부 (접근 가능한 곳) |
| **호스팅** | 공개 URL 필수 (GitHub Pages, Notion 등 활용 가능) |
| **포함 내용** | 수집 데이터 종류, 수집 방법, 사용 목적, 서드파티 공유 여부, 보관 기간, 삭제 방법, 사용자 권리 |

### 6-8. 계정/데이터 삭제 요구사항

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| 계정 삭제 | 계정 생성 지원 앱은 앱 내 삭제 옵션 필수 | 해당시 |
| Sign in with Apple | Apple ID 삭제 시 서버-서버 알림 처리 | 해당시 |

---

## 7. 접근성 요구사항

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| **VoiceOver 지원** | 모든 텍스트 VoiceOver로 읽기 가능, 중요 항목에 레이블 제공 | 강력 권장 |
| **Dynamic Type** | 사용자 설정에 따라 텍스트 크기 조절 | 강력 권장 |
| **색상 대비** | 최소 4.5:1 대비 비율 | 강력 권장 |
| **대체 텍스트** | 의미 있는 이미지/아이콘에 대체 텍스트 | 강력 권장 |
| **터치 타겟** | 최소 44x44 포인트 | 권장 |

> App Store Connect의 Accessibility Nutrition Labels는 **현재 선택사항(voluntary)**. 단, Apple은 향후 필수로 전환 예정임을 명시. 정확한 필수화 시점은 미발표. **주의: "지원함"으로 체크할 경우, 해당 기능이 실제로 구현되어 있어야 함. 허위 체크 시 리젝 가능.** ([근거](https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/))

---

## 8. 현지화 및 한국 특별 요구사항

### 8-1. App Store Connect 지원 언어

39개 언어/로케일 지원. 한국어 포함. ([근거](https://developer.apple.com/help/app-store-connect/reference/app-store-localizations))

### 8-2. 현지화 가능 필드

앱 이름, 부제목, 설명, 키워드, What's New, 스크린샷, 앱 미리보기, 홍보 텍스트

### 8-3. 한국 앱스토어 특별 요구사항

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| 한국 규정 준수 정보 | Individual: 이메일, BRN / Organization: 회사명, 이메일, 전화번호, BRN | 개인/조직 모두 필수 |
| 한국 연령 등급 | 전체이용가 / 12+ / 15+ / 19+ | 필수 |
| 한국어 지역화 | 한국 사용자 대상 시 한국어 메타데이터 | 강력 권장 |
| 개인정보 처리방침 | 한국 개인정보보호법 준수 (2025.04 개정 지침) | 필수 |
| 통신판매업 신고 | 유료 앱/IAP로 수익 발생 시 통신판매업 신고번호 필요할 수 있음. 현재 SweepPic는 무료 앱이므로 해당 없음. 향후 유료화 시 확인 필요 | 참고 |
| **공정위 다크패턴 규제** | 2025년 강화. 기만적/조작적 UI 패턴 금지 (강제 구독, 숨겨진 비용, 탈퇴 방해 등). 위반 시 500만원 과태료 | 필수 |

### 8-5. 한국 규정 준수 정보 입력 경로

```
App Store Connect > 앱 선택 > General > App Information >
  "Compliance Information" 또는 "Korean Law" 섹션
  → 이메일, 사업자등록번호(BRN) 입력
```

> **개인 개발자**: 이메일 + BRN 필수 (전화번호는 조직만)
> **입력 시점**: 첫 제출 전 반드시 완료. 미입력 시 한국 앱스토어에서 표시 차단 가능

### 8-4. 한국 개인정보 처리방침 필수 포함 내용

> 근거: 개인정보 처리방침 작성지침 (2025.04.21 개정)

1. 수집하는 개인정보 항목 및 수집 방법
2. 개인정보 처리 목적
3. 개인정보 보유 및 이용 기간
4. 개인정보 제3자 제공 사항
5. 정보주체의 권리 (열람/정정/삭제/처리정지)
6. 개인정보 보호책임자 정보
7. 행태정보 수집/이용/제공 및 거부 안내
8. 모바일 앱에서 쉽게 확인 가능한 위치에 공개

---

## 9. 보안 및 수출 규정

### 9-1. 수출 규정

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| ITSAppUsesNonExemptEncryption | Info.plist에 설정 필수 | 필수 |
| 면제 암호화 | HTTPS, OS 내장 암호화 → 문서 제출 면제 → `false` | - |
| 비면제 암호화 | 독점 알고리즘 → 수출 문서 제출 → `true` | 해당시 |

### 9-2. ATS (App Transport Security)

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| HTTPS 기본 사용 | TLS 1.2 이상, SHA-256 이상, Forward Secrecy | 필수 |
| 예외 설정 | 특정 도메인 한정, 최소화 필수 | 해당시 |
| NSAllowsArbitraryLoads | 전체 비활성화는 사유 설명 필요, 거부 위험 높음 | 비권장 |

### 9-3. 민감 데이터 저장

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| Keychain | 비밀번호, 토큰 등 민감 데이터 저장 | 권장 |
| 접근 그룹 | 적절한 접근 그룹으로 앱 간 격리 | 권장 |

---

## 10. 테스트 관련 요구사항

### 10-1. 심사용 데모 계정

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| 로그인 필요 앱 | 데모 계정 자격 증명 제공 필수 | 해당시 |
| 계정 유효성 | 만료되지 않아야 함 | 해당시 |
| 2단계 인증 | 추가 인증 코드 Notes에 사전 제공 | 해당시 |

### 10-2. TestFlight

| 항목 | 요구사항 |
|------|---------|
| 첫 빌드 심사 | 그룹에 첫 빌드 추가 시 자동 심사 |
| 외부 테스터 | 최대 10,000명 |
| 내부 테스터 | 최대 100명 |
| 빌드 유효 기간 | 업로드일로부터 90일 |
| 수출 규정 | 베타 빌드에도 준수 정보 필수 |

---

## 11. SweepPic 현재 상태 점검

> 점검일: 2026-02-11

### 11-1. 제출 차단 항목 (이것 없으면 제출 불가)

| # | 요구사항 | 현재 상태 | 조치 필요 |
|---|---------|----------|----------|
| 1 | 앱 아이콘 1024x1024 PNG | **없음** (Contents.json만 존재) | 아이콘 디자인 및 추가 |
| 2 | PrivacyInfo.xcprivacy | **프로젝트 전체에 없음** | 파일 생성 필수 |
| 3 | 프라이버시 정책 URL | **없음** (앱 내/외부 모두) | 문서 작성 + URL 호스팅 |
| 4 | 스크린샷 | 없음 | iPhone 6.9" (1260x2736) 1~10장 + iPad 13" (2064x2752) 1~10장 준비 (TARGETED_DEVICE_FAMILY=1,2이므로 iPad도 필수) |
| 5 | App Store Connect 메타데이터 | 미설정 | 전체 메타데이터 입력 |
| 6 | App Privacy Details 설문 | 미작성 | 사진 데이터 접근 선언. **단, SweepPic는 온디바이스 처리 전용 (외부 전송 없음)이므로 Apple 기준 "Data Not Collected" 선택 가능성 있음 — 제출 시 확인 필요** |
| 7 | 연령 등급 설문 | 미작성 | 새 양식 응답 |
| 8 | 심사 연락처 | 미설정 | 이름/이메일/전화번호 |

### 11-2. 리젝 고위험 항목 (치명)

| # | 요구사항 | 현재 상태 | 조치 필요 | 위험도 |
|---|---------|----------|----------|:------:|
| 9 | **Private API 사용 금지 (2.5.1)** | `SystemUIInspector.swift`가 KVC로 시스템 UI 접근 — `#if DEBUG` 미래핑 상태로 릴리즈 빌드에 포함됨 | `#if DEBUG`로 완전 래핑 또는 릴리즈에서 제외 | **치명** |
| 10 | **Debug 파일 릴리즈 제외** | `LiquidGlassOptimizer.swift`, `AutoScrollTester.swift`, `SystemUIInspector.swift` 3개 파일이 `#if DEBUG` 미래핑 | 모든 Debug 파일을 `#if DEBUG`로 래핑, 또는 빌드 타겟에서 제외 | **치명** |

### 11-3. 리젝 고위험 항목 (높음)

| # | 요구사항 | 현재 상태 | 조치 필요 | 위험도 |
|---|---------|----------|----------|:------:|
| 11 | ITSAppUsesNonExemptEncryption | **Info.plist에 없음** | `false`로 추가 | 높음 |
| 12 | NSPhotoLibraryUsageDescription 한글 | 영어만 존재 | 한글 Localization 추가 | 높음 |
| 13 | **전체 사진 접근 정당화 (5.1.1(iii))** | 데이터 최소화 원칙 — "가능하면 PHPicker 사용" 명시. 전체 접근 필수인 이유를 Review Notes에서 설득해야 함 | Review Notes에 구체적 사유 3가지 명시 (아래 14-1 참조) | 높음 |
| 14 | **얼굴 데이터 사용 제한 (5.1.2(vi))** | Vision Framework 얼굴 인식 사용 중. 수집 데이터를 마케팅/광고/데이터마이닝에 사용 금지 | 온디바이스 전용임을 Privacy Policy + Review Notes에 명시 | 높음 |
| 15 | **Limited Photo Access 처리 (2.1)** | iOS 14+ `.limited` 상태에서 빈 화면/크래시 발생 시 Guideline 2.1 위반 | `.limited` 상태에서 정상 동작 확인, 접근 권한 업그레이드 안내 UI 구현 | 높음 |
| 16 | 서드파티 SDK Privacy Manifest | BlurUIKit — 미확인 / LiquidGlassKit — 없음 | 각 SDK가 Required Reason API(UserDefaults 등)를 내부적으로 사용하는지 확인 필수. SDK 제작자가 Manifest를 미제공하면 직접 포함해야 함 (ITMS-91061 오류 발생) | 높음 |
| 17 | **연령 등급 새 양식 응답** | 2026.01.31 마감 **이미 경과** — 미응답 시 앱 업데이트 제출 차단 | App Store Connect에서 즉시 새 양식 응답 | **긴급** |
| 18 | 크래시 안정성 | 미확인 | 전체 흐름 테스트 | 높음 |
| 19 | Review Notes | 없음 | 사진 접근 사유, Vision 기기 내 처리 명시 (아래 14-1 참조) | 높음 |

### 11-4. 리젝 중간 위험 항목

| # | 요구사항 | 현재 상태 | 조치 필요 | 위험도 |
|---|---------|----------|----------|:------:|
| 20 | **비 Debug 파일의 print문** | `FeatureFlags.swift`, `CleanupSessionStore.swift`, `ViewerViewController+SimilarPhoto.swift`에 print문 잔존 | `Log.print()` 또는 `#if DEBUG` 래핑으로 전환 | 중간 |

### 11-5. 통과 항목 (문제 없음)

| # | 요구사항 | 현재 상태 |
|---|---------|----------|
| 15 | Launch Screen | LaunchScreen.storyboard 존재 |
| 16 | arm64 아키텍처 | arm64 빌드 확인 |
| 17 | iOS 16+ Deployment Target | iOS 16.0 설정 |
| 18 | IPv6 지원 | 외부 네트워크 통신 없음 → 해당 없음 |
| 19 | ATS | HTTP 통신 없음 → 해당 없음 |
| 20 | 코드 서명 | Automatic Signing, Team ID 7YD5497HFS |
| 21 | Bundle ID | com.karl.SweepPic |
| 22 | 버전 번호 | 1.0 (빌드 1) |
| 23 | 배경 모드 | UIBackgroundModes 미선언 (불필요) |
| 24 | ProMotion 120fps | CADisableMinimumFrameDurationOnPhone = true |

### 11-6. 개선 권장 항목

| # | 요구사항 | 현재 상태 | 조치 필요 |
|---|---------|----------|----------|
| 25 | VoiceOver | 일부 UI만 적용 (PhotoCell, FloatingTabBar 등) | 전체 UI 확대 |
| 26 | Dynamic Type | **미지원** | UIFontMetrics 도입 |
| 27 | Localization (.strings) | 없음 — 한글 하드코딩 | 한/영 .strings 분리 |
| 28 | 한국 개인정보 처리방침 | 없음 | 2025.04 개정 지침 기반 작성 |
| 29 | LaunchScreen 브랜딩 | 빈 흰색 화면 | 앱 로고 추가 권장 |

### 11-7. 해당 없음 (SweepPic에 불필요)

| 요구사항 | 이유 |
|---------|------|
| 인앱 구매 (IAP) | 유료 기능 없음 |
| 로그인/계정 기능 | 로그인 없음 → 데모 계정/계정 삭제 불필요 |
| ATT (App Tracking Transparency) | 추적/광고 없음 |
| UGC (사용자 생성 콘텐츠) | 해당 없음 |
| 위치 서비스 | 미사용 |
| Push Notifications | 미사용 |
| 배경 모드 | 미사용 |
| 카메라 접근 | 미사용 |
| Sign in with Apple | 로그인 없음 |
| EU DSA 트레이더 상태 | 한국만 배포 시 불필요 |

### 11-8. Required Reason API 사용 현황

| API | 사용 여부 | 위치 | Privacy Manifest 사유 코드 |
|-----|:--------:|------|--------------------------|
| UserDefaults | O | Debug 폴더, CleanupConstants | `CA92.1` (앱 자체 접근) |
| 파일 타임스탬프 | O | ThumbnailCache.swift (contentModificationDateKey, setAttributes) | `DDA9.1` (앱 컨테이너 내 접근) |
| 시스템 부팅 시간 | X | - | - |
| 디스크 공간 | X | - | - |
| 활성 키보드 | X | - | - |

### 11-9. 서드파티 라이브러리 현황

| 라이브러리 | 유형 | Privacy Manifest | 비고 |
|-----------|------|:----------------:|------|
| AppCore | 로컬 패키지 | 없음 | CryptoKit(SHA256), 파일 타임스탬프 사용 |
| BlurUIKit | 원격 (TimOliver/BlurUIKit >= 1.2.2) | **확인 필요** | - |
| LiquidGlassKit | 로컬 패키지 | 없음 | Metal/MetalKit 사용 |

---

## 12. 사진 앱 리젝 사례 분석

> 사진/갤러리 앱에 특화된 리젝 유형과 대응 방법

### 12-1. 사진 앱 특화 리젝 유형 TOP 5

| 순위 | 리젝 유형 | Guideline | 빈도 | 설명 |
|:----:|----------|:---------:|:----:|------|
| 1 | 네이티브 사진 앱 복제 | 4.1 / 4.2 | 매우 높음 | "기본 사진 앱과 차별화 부족" — 스와이프 정리, 유사 사진 등 독자 기능 필수 |
| 2 | 전체 사진 접근 미설명 | 5.1.1(iii) | 높음 | PHPicker 대신 전체 접근을 요구하는 이유 미설명 |
| 3 | 프라이버시 정책 미흡 | 5.1.1 | 높음 | 사진/얼굴 데이터 처리 방식 미기재 |
| 4 | 빈 상태 처리 | 2.1 | 중간 | 사진 0장, 권한 거부, Limited 접근 시 빈 화면/크래시 |
| 5 | Private API 사용 | 2.5.1 | 중간 | 디버그용 코드가 릴리즈에 포함 |

### 12-2. Halide 카메라 앱 사건 (2024.09)

- Apple 디자인 어워드 수상 + iPhone 16 키노트 소개 앱
- "카메라 앱이 왜 카메라가 필요한지 설명 불충분"으로 리젝
- Apple이 "심사 실수" 인정, 수정 없이 재제출 통과
- **교훈**: 명백한 경우에도 리젝 가능 → 권한 문구 최대한 구체적으로

### 12-3. 한국 개발자 특화 리젝 사유

| 사유 | 상세 | 가이드라인 |
|------|------|-----------|
| **Apple 로그인 미포함** | 카카오/네이버 로그인만 → 필수 리젝 | 4.8 |
| **PASS 본인인증 추가 요구** | Apple 로그인 + 추가 인증 → 리젝 | 4.8 |
| **타 플랫폼 언급** | "구글 플레이에서 검색" 문구 → 즉각 리젝 | 2.3.1 |
| **인앱 결제 우회** | "외부 결제 시 할인" 문구 → 리젝 | 3.1.1 |
| **불필요한 개인정보 필수 수집** | 앱과 무관한 성별/주소 필수 → 리젝 | 5.1.1 |

### 12-4. 2024-2026 리젝 트렌드

- **AI 심사 병행**: 기존에 통과하던 앱도 갑자기 리젝
- **PrivacyInfo.xcprivacy 필수화** (2024.05~)
- **토글 페이월 금지** (2026.01~)
- **계정 삭제 지속 강화**: "비활성화 ≠ 삭제"

### 12-5. 최근 리젝 트렌드 (2025~2026)

| 트렌드 | 내용 |
|--------|------|
| Privacy Manifest 강화 | 2025.02.12부터 SDK 포함 앱에 Privacy Manifest 미포함 시 ITMS-91061로 업로드 자체 차단 |
| 데이터 최소화 원칙 | "가능하면 PHPicker 사용" 문구가 가이드라인에 명시. 전체 접근 앱은 Review Notes에서 설득 필요 |
| Performance 리젝 1위 | 2024년 기준 1.2M건 리젝 중 가장 많은 유형이 Performance (크래시, 미완성 기능) |
| 연령 등급 새 양식 | 2026.01.31 마감. 미응답 시 업데이트 제출 차단 |

### 12-3. 리젝 통계 (2024년 기준)

| 항목 | 수치 |
|------|------|
| 총 심사 건수 | 7.7M건 |
| 리젝 건수 | 1.9M건 (약 25%) |
| Performance 리젝 | 1.2M건 (1위) |
| 리젝 후 수정 통과 | 295K건 |
| 첫 제출 통과율 | 약 75% |

---

## 13. Review Notes 작성 가이드 (SweepPic용)

> Review Notes는 심사팀이 앱을 이해하는 핵심 창구. 4,000바이트 제한.

### 13-1. SweepPic Review Notes 템플릿

```
[App Overview]
SweepPic is a photo gallery app focused on fast photo organization.
Users can quickly sort their photo library using swipe-to-delete and
similar photo detection features.

[Why Full Photo Library Access is Required]
1. PHOTO ORGANIZATION: The core purpose is to help users efficiently
   sort and organize their ENTIRE photo library. PHPicker only allows
   selecting individual photos, which defeats the purpose of library-
   wide organization.
2. SIMILAR PHOTO DETECTION: Our similarity analysis needs to compare
   ALL photos in the library to find duplicates and similar groups.
   This is impossible with limited or picker-based access.
3. GRID BROWSING: We provide a native-like grid browsing experience
   where users can scroll through their complete library, just like
   the built-in Photos app.

[Face Detection — On-Device Only]
- Vision Framework is used for face detection (auto-zoom feature)
- ALL processing is done 100% on-device
- No face data is ever transmitted, stored externally, or used for
  tracking/advertising/data mining
- Compliant with Guideline 5.1.2(vi)

[Privacy]
- No user data is collected or transmitted
- No analytics, tracking, or advertising SDKs
- All photo processing happens on-device only
- Privacy Policy: [URL]

[Testing Instructions]
- Grant full photo library access when prompted
- For similar photo feature: requires 50+ photos for meaningful results
- Swipe up on any photo in the viewer to delete (restore from trash available)
- Tap the similar photo button to see grouped similar photos

[Device Tested]
- iPhone 15 Pro / iOS 17.x
- iPhone 17 Pro / iOS 26.x
```

### 13-2. 핵심 포인트

| 항목 | 작성 요령 |
|------|----------|
| 전체 사진 접근 사유 | 구체적 이유 3가지를 번호 매겨 설명. "전체 라이브러리 정리가 핵심 목적"이 가장 강한 논거 |
| Vision 온디바이스 | "100% on-device", "no data transmitted" 를 반복 강조 |
| 테스트 조건 | 최소 사진 수(유사 사진 기능 50장+), 스와이프 방향 등 심사원이 기능을 빠르게 체험할 수 있게 안내 |
| 차별화 기능 | 스와이프 삭제, 유사 사진 분석 등 네이티브 앱에 없는 기능 나열 |

---

## 14. App Privacy Details 실전 응답 가이드

> App Store Connect 제출 시 "App Privacy" 섹션 응답 방법

### 14-1. SweepPic 응답 전략

SweepPic는 **온디바이스 전용** 앱이므로 특별한 전략이 가능합니다.

| 질문 | SweepPic 답변 | 근거 |
|------|---------------|------|
| "Do you or your third-party partners collect data from this app?" | **No** | 모든 처리가 온디바이스. 외부 전송 없음 |
| Photos/Videos 데이터 수집? | (위에서 No 선택 시 이 질문 표시 안됨) | - |
| 추적(Tracking)? | **No** | ATT/IDFA 미사용, 광고 없음 |

### 14-2. "Data Not Collected" 선택 조건

Apple 기준에서 **다음 조건을 모두 만족**하면 "Data Not Collected" 선택 가능:

| 조건 | SweepPic 충족 여부 |
|------|:-----------------:|
| 데이터가 기기를 떠나지 않음 | **O** |
| 서버로 전송하지 않음 | **O** |
| 제3자와 공유하지 않음 | **O** |
| 분석/광고 SDK 미사용 | **O** |
| 사용자 추적 안 함 | **O** |

> **결론**: SweepPic는 **"Data Not Collected"** 선택 가능. 이 경우 개별 데이터 타입 질문이 표시되지 않아 가장 깔끔한 프라이버시 라벨이 됨.

### 14-3. 주의사항

- Privacy Policy URL은 "Data Not Collected"와 무관하게 **항상 필수**
- 향후 분석 SDK(Firebase 등) 추가 시 응답 변경 필수
- 허위 응답 적발 시 리젝 + 개발자 계정 경고

---

## 15. Guideline 4.2 방어 전략

> "네이티브 사진 앱이랑 뭐가 달라?" — 심사 리젝 방어

### 15-1. 차별화 근거

| 차별화 기능 | 네이티브 사진 앱 | SweepPic |
|------------|:---------------:|:---------:|
| 스와이프 삭제 | X | **O** — 위로 스와이프로 빠른 삭제 |
| 휴지통 복구 기반 안전장치 | X (삭제 확인 다이얼로그) | **O** — 확인 없이 삭제 + 즉시 복구 가능 |
| 유사 사진 그룹화 | X (iOS 16+은 중복 감지만) | **O** — Vision 기반 유사도 분석 |
| 자동 얼굴 확대 | X | **O** — 뷰어에서 얼굴 자동 인식/줌 |
| 사진 정리 생산성 | 범용 뷰어 | **정리 특화** — 빠른 분류에 최적화 |

### 15-2. 경쟁 앱 참고

| 앱 | 평점 | 차별화 | 심사 통과 여부 |
|-----|------|--------|:------------:|
| Slidebox | 4.8 | 스와이프 정리 | O — 수년간 운영 |
| Gemini Photos | 4.7 | AI 중복 감지 | O |
| Cleanup | 4.6 | 스마트 정리 | O |

> 스와이프 기반 사진 정리만으로도 충분한 차별화 근거가 됨 (Slidebox 사례)

### 15-3. App Store Connect 카테고리/포지셔닝

| 항목 | 권장값 |
|------|-------|
| Primary Category | **Photo & Video** |
| 앱 설명 키워드 | "사진 정리", "스와이프 삭제", "유사 사진 분석" |
| 포지셔닝 | "사진 정리 생산성 도구" (범용 갤러리가 아닌 정리 특화) |

---

## 16. ITMS 오류 코드 대응표

> 바이너리 업로드 시 자주 발생하는 ITMS 오류와 해결법

| 오류 코드 | 제목 | 원인 | 해결법 |
|----------|------|------|--------|
| **ITMS-90717** | Invalid App Store Icon | 아이콘에 알파 채널/투명 영역 포함, 또는 PNG 아닌 형식 | 1024x1024 불투명 PNG로 교체, 알파 채널 제거 |
| **ITMS-90683** | Missing Purpose String | `NSPhotoLibraryUsageDescription` 등 필수 Usage Description 누락 | Info.plist에 해당 키 + 사유 문자열 추가 |
| **ITMS-91053** | Missing API Declaration | Privacy Manifest에서 Required Reason API 사유 미선언 | PrivacyInfo.xcprivacy에 해당 API + 사유 코드 추가 |
| **ITMS-91061** | Missing Privacy Manifest in SDK | 서드파티 SDK에 Privacy Manifest 미포함 (2025.02.12~ 시행) | SDK 업데이트하거나, SDK 번들 내에 PrivacyInfo.xcprivacy 직접 추가 |
| **ITMS-90032** | Invalid Binary Architecture | 32비트 아키텍처 포함 | arm64 전용 빌드 확인 |
| **ITMS-90474** | Missing Bundle Version | CFBundleVersion 누락/무효 | Info.plist에 유효한 버전 번호 설정 |

---

## 17. 심사 프로세스 실전 가이드

### 17-1. 심사 기간

| 유형 | 기간 |
|------|------|
| 일반 심사 | 90%가 24시간 이내 |
| 신규 앱 첫 제출 | 24~72시간 |
| 업데이트 심사 | 대부분 24시간 이내 |
| Expedited Review | 치명적 버그/보안 문제 시만 승인. App Store Connect에서 요청 |

### 17-2. 심사 상태 흐름

```
Waiting for Review → In Review → [Approved / Rejected]
                                       ↓
                                 Rejected → 수정 → 재제출
```

### 17-3. 리젝 대응

| 단계 | 행동 |
|------|------|
| 1. 리젝 사유 확인 | App Store Connect > Resolution Center에서 상세 사유 확인 |
| 2. 사유 분석 | 구체적 Guideline 번호와 설명 확인 |
| 3. 수정 | 코드/메타데이터 수정 |
| 4. 재제출 | Resolution Center에서 답변 + 새 빌드 업로드 |
| 5. 이의 신청 | 부당하다고 판단 시 App Review Board에 항소 가능 |

### 17-4. 리젝 방지 체크리스트 (제출 전)

- [ ] 모든 기능이 완전히 동작하는가? (빈 화면, 플레이스홀더 없음)
- [ ] 사진 접근 거부/제한 시 정상 처리되는가?
- [ ] 크래시 없이 모든 주요 흐름이 완료되는가?
- [ ] Privacy Manifest가 올바르게 포함되어 있는가?
- [ ] 디버그 코드가 릴리즈 빌드에서 제외되었는가?
- [ ] 앱 아이콘이 불투명 PNG인가?
- [ ] 스크린샷이 실제 앱 화면인가?
- [ ] Review Notes에 사진 접근 사유가 명시되어 있는가?
- [ ] 프라이버시 정책 URL이 접근 가능한가?
- [ ] 연령 등급 설문이 완료되었는가?

---

## 18. SweepPic 실행 계획

### Phase 0 — 치명적 항목 즉시 수정 (최우선)

| # | 작업 | 상세 | 위험도 |
|---|------|------|:------:|
| 0-1 | **디버그 코드 #if DEBUG 래핑** | `SystemUIInspector.swift` (Private API/KVC), `AutoScrollTester.swift`, `LiquidGlassOptimizer.swift`의 디버그 코드를 `#if DEBUG`로 래핑. 릴리즈 빌드에 포함 시 Guideline 2.5.1 위반으로 즉시 리젝 | 치명 |
| 0-2 | **비 Debug 파일 print문 정리** | `FeatureFlags.swift`, `CleanupSessionStore.swift`, `ViewerViewController+SimilarPhoto.swift`의 print문을 `Log.print()` 또는 `#if DEBUG` 래핑으로 전환 | 중간 |
| 0-3 | **연령 등급 새 양식 응답** | 2026.01.31 마감 이미 경과. App Store Connect에서 즉시 새 양식 응답 필요 (미응답 시 업데이트 제출 차단) | 긴급 |

### Phase 1 — 제출 차단 해소 (필수, 코드 작업)

| # | 작업 | 상세 |
|---|------|------|
| 1 | PrivacyInfo.xcprivacy 생성 | 파일 타임스탬프(`DDA9.1`), UserDefaults(`CA92.1`) 선언. Photos 데이터는 온디바이스 전용이므로 NSPrivacyCollectedDataTypes 포함 여부 확인 후 결정 |
| 2 | ITSAppUsesNonExemptEncryption 추가 | Info.plist에 `false` 설정 |
| 3 | NSPhotoLibraryUsageDescription 한글화 | Localization 파일 추가 |
| 4 | 서드파티 SDK Privacy Manifest 확인 | BlurUIKit, LiquidGlassKit 점검 (ITMS-91061 방지) |
| 5 | **Limited Photo Access 대응** | `.limited` 상태에서 빈 화면/크래시 방지. 정상 동작 + 전체 접근 업그레이드 안내 UI |

### Phase 2 — 프라이버시 정책 (필수, 문서 작업)

| # | 작업 | 상세 |
|---|------|------|
| 5 | 프라이버시 정책 작성 | 한국 개인정보보호법 2025.04 개정 지침 기반 |
| 6 | URL 호스팅 | GitHub Pages 등 활용 |
| 7 | 앱 내 프라이버시 정책 링크 | 설정 화면 등에서 접근 가능하도록 |

### Phase 3 — 디자인 에셋 (필수, 디자인 작업)

| # | 작업 | 상세 |
|---|------|------|
| 8 | 앱 아이콘 디자인 | 1024x1024 불투명 PNG, sRGB/P3 |
| 9 | 스크린샷 준비 | iPhone 6.9" (1260x2736) + iPad 13" (2064x2752) 각 1~10장 |
| 10 | LaunchScreen 브랜딩 | 앱 로고 추가 (권장) |

### Phase 4 — App Store Connect 설정 (필수, 웹 작업)

| # | 작업 | 상세 |
|---|------|------|
| 11 | 앱 메타데이터 입력 | 이름, 설명, 키워드, 카테고리, 저작권, 지원 URL |
| 12 | App Privacy Details 설문 | Photos/Videos 데이터 수집 선언 |
| 13 | 연령 등급 설문 | 새 양식 응답 |
| 14 | 심사 연락처 입력 | 이름/이메일/전화번호 |
| 15 | Review Notes 작성 | 전체 사진 접근 사유, Vision 기기 내 처리 명시 |

### Phase 5 — 품질 향상 (권장)

| # | 작업 | 상세 |
|---|------|------|
| 16 | 전체 흐름 크래시 테스트 | 모든 주요 시나리오 테스트 (사진 0장, 권한 거부, Limited 접근 포함) |
| 17 | 접근성 확대 | VoiceOver 전체 UI, Dynamic Type |
| 18 | Localization 파일 분리 | 한/영 .strings 파일 |

### Phase 6 — 빌드 및 제출

| # | 작업 | 상세 |
|---|------|------|
| 19 | Xcode 26 SDK 빌드 | 2026.04.28부터 필수 |
| 20 | Archive & Upload | Product > Archive > Distribute App |
| 21 | 심사 제출 | Submit for Review |

---

## 19. Apple 공식 참고 문서

### 핵심 문서 (북마크 권장)

| 문서 | URL |
|------|-----|
| 제출 가이드 (메인) | https://developer.apple.com/app-store/submitting/ |
| 필수 속성 목록 | https://developer.apple.com/help/app-store-connect/reference/app-information/required-localizable-and-editable-properties |
| App Review Guidelines | https://developer.apple.com/app-store/review/guidelines/ |
| Upcoming Requirements | https://developer.apple.com/news/upcoming-requirements/ |

### 상세 참고 문서

| 문서 | URL |
|------|-----|
| 스크린샷 사양 | https://developer.apple.com/help/app-store-connect/reference/screenshot-specifications |
| 앱 미리보기 사양 | https://developer.apple.com/help/app-store-connect/reference/app-information/app-preview-specifications |
| 앱 아이콘 가이드 (HIG) | https://developer.apple.com/design/human-interface-guidelines/app-icons |
| Privacy Manifest | https://developer.apple.com/documentation/bundleresources/privacy-manifest-files |
| Required Reason API | https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api |
| App Privacy Details | https://developer.apple.com/app-store/app-privacy-details/ |
| 수출 규정 | https://developer.apple.com/documentation/security/complying-with-encryption-export-regulations |
| 연령 등급 | https://developer.apple.com/help/app-store-connect/reference/app-information/age-ratings-values-and-definitions |
| 빌드 크기 제한 | https://developer.apple.com/help/app-store-connect/reference/app-uploads/maximum-build-file-sizes |
| Launch Screen 설정 | https://developer.apple.com/documentation/xcode/specifying-your-apps-launch-screen |
| ATS (네트워크 보안) | https://developer.apple.com/documentation/security/preventing-insecure-network-connections |
| 계정 삭제 요구사항 | https://developer.apple.com/support/offering-account-deletion-in-your-app/ |
| 한국 규정 정보 | https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-korea-compliance-information/ |
| TestFlight 개요 | https://developer.apple.com/help/app-store-connect/test-a-beta-version/testflight-overview/ |
| 한국 개인정보 처리방침 지침 (2025.04) | https://www.privacy.go.kr/front/bbs/bbsView.do?bbsNo=BBSMSTR_000000000049&bbscttNo=20806 |

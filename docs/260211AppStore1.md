# PickPhoto 앱스토어 등록 가이드

> 작성일: 2026-02-11
> 목적: iOS 앱스토어 제출을 위한 전체 요구사항 정리 및 PickPhoto 현재 상태 대조

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
11. [PickPhoto 현재 상태 점검](#11-pickphoto-현재-상태-점검)
12. [PickPhoto 실행 계획](#12-pickphoto-실행-계획)
13. [Apple 공식 참고 문서](#13-apple-공식-참고-문서)

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
| ITSAppUsesNonExemptEncryption | 수출 규정 암호화 신고 | 필수 |
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

| 화면 크기 | 해상도 (세로) | 필수 여부 |
|-----------|-------------|:---------:|
| **6.9"** | 1260 x 2736 | 둘 중 하나 |
| **6.5"** | 1284 x 2778 | 둘 중 하나 |
| 6.3" | 1179 x 2556 | 6.5"에서 자동 축소 |
| 6.1" | 1170 x 2532 | 6.5"에서 자동 축소 |
| 5.5" | 1242 x 2208 | 6.1"에서 자동 축소 |

**iPad (iPad 앱이면 필수)**

| 화면 크기 | 해상도 (세로) |
|-----------|-------------|
| **13"** | 2064 x 2752 |

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
>
> ([근거: TN3181](https://developer.apple.com/documentation/technotes/tn3181-debugging-an-invalid-privacy-manifest))

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

### 6-3. App Tracking Transparency (ATT)

| 항목 | 요구사항 | 구분 |
|------|---------|:----:|
| ATT 프레임워크 | IDFA 접근 또는 사용자 추적 시 허가 요청 | 해당시 |
| NSUserTrackingUsageDescription | 사용 목적 기재 | 해당시 |
| 추적 거부 시 | 앱 기능 동일하게 제공 | 필수 |

### 6-4. App Privacy Details (영양 라벨) 전체 데이터 타입

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

### 6-5. 프라이버시 정책 필수 요건

| 항목 | 설명 |
|------|------|
| **게재 위치** | App Store Connect 메타데이터 + 앱 내부 (접근 가능한 곳) |
| **호스팅** | 공개 URL 필수 (GitHub Pages, Notion 등 활용 가능) |
| **포함 내용** | 수집 데이터 종류, 수집 방법, 사용 목적, 서드파티 공유 여부, 보관 기간, 삭제 방법, 사용자 권리 |

### 6-6. 계정/데이터 삭제 요구사항

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
| 통신판매업 신고 | 유료 앱/IAP로 수익 발생 시 통신판매업 신고번호 필요할 수 있음. 현재 PickPhoto는 무료 앱이므로 해당 없음. 향후 유료화 시 확인 필요 | 참고 |

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

## 11. PickPhoto 현재 상태 점검

> 점검일: 2026-02-11

### 11-1. 제출 차단 항목 (이것 없으면 제출 불가)

| # | 요구사항 | 현재 상태 | 조치 필요 |
|---|---------|----------|----------|
| 1 | 앱 아이콘 1024x1024 PNG | **없음** (Contents.json만 존재) | 아이콘 디자인 및 추가 |
| 2 | PrivacyInfo.xcprivacy | **프로젝트 전체에 없음** | 파일 생성 필수 |
| 3 | 프라이버시 정책 URL | **없음** (앱 내/외부 모두) | 문서 작성 + URL 호스팅 |
| 4 | 스크린샷 | 없음 | iPhone 6.9" 1~10장 준비 |
| 5 | App Store Connect 메타데이터 | 미설정 | 전체 메타데이터 입력 |
| 6 | App Privacy Details 설문 | 미작성 | Photos 데이터 수집 선언 |
| 7 | 연령 등급 설문 | 미작성 | 새 양식 응답 |
| 8 | 심사 연락처 | 미설정 | 이름/이메일/전화번호 |

### 11-2. 리젝 고위험 항목

| # | 요구사항 | 현재 상태 | 조치 필요 |
|---|---------|----------|----------|
| 9 | ITSAppUsesNonExemptEncryption | **Info.plist에 없음** | `false`로 추가 |
| 10 | NSPhotoLibraryUsageDescription 한글 | 영어만 존재 | 한글 Localization 추가 |
| 11 | 디버그 코드 분리 | Debug 폴더 존재, UserDefaults 사용 | 릴리즈 빌드에서 제거 확인 |
| 12 | 서드파티 SDK Privacy Manifest | BlurUIKit — 미확인 / LiquidGlassKit — 없음 | 각 SDK가 Required Reason API(UserDefaults 등)를 내부적으로 사용하는지 확인 필수. SDK 제작자가 Manifest를 미제공하면 직접 포함해야 함 |
| 13 | 크래시 안정성 | 미확인 | 전체 흐름 테스트 |
| 14 | Review Notes | 없음 | 사진 접근 사유, Vision 기기 내 처리 명시 |

### 11-3. 통과 항목 (문제 없음)

| # | 요구사항 | 현재 상태 |
|---|---------|----------|
| 15 | Launch Screen | LaunchScreen.storyboard 존재 |
| 16 | arm64 아키텍처 | arm64 빌드 확인 |
| 17 | iOS 16+ Deployment Target | iOS 16.0 설정 |
| 18 | IPv6 지원 | 외부 네트워크 통신 없음 → 해당 없음 |
| 19 | ATS | HTTP 통신 없음 → 해당 없음 |
| 20 | 코드 서명 | Automatic Signing, Team ID 7YD5497HFS |
| 21 | Bundle ID | com.karl.PickPhoto |
| 22 | 버전 번호 | 1.0 (빌드 1) |
| 23 | 배경 모드 | UIBackgroundModes 미선언 (불필요) |
| 24 | ProMotion 120fps | CADisableMinimumFrameDurationOnPhone = true |

### 11-4. 개선 권장 항목

| # | 요구사항 | 현재 상태 | 조치 필요 |
|---|---------|----------|----------|
| 25 | VoiceOver | 일부 UI만 적용 (PhotoCell, FloatingTabBar 등) | 전체 UI 확대 |
| 26 | Dynamic Type | **미지원** | UIFontMetrics 도입 |
| 27 | Localization (.strings) | 없음 — 한글 하드코딩 | 한/영 .strings 분리 |
| 28 | 한국 개인정보 처리방침 | 없음 | 2025.04 개정 지침 기반 작성 |
| 29 | LaunchScreen 브랜딩 | 빈 흰색 화면 | 앱 로고 추가 권장 |

### 11-5. 해당 없음 (PickPhoto에 불필요)

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

### 11-6. Required Reason API 사용 현황

| API | 사용 여부 | 위치 | Privacy Manifest 사유 코드 |
|-----|:--------:|------|--------------------------|
| UserDefaults | O | Debug 폴더, CleanupConstants | `CA92.1` (앱 자체 접근) |
| 파일 타임스탬프 | O | ThumbnailCache.swift (contentModificationDateKey, setAttributes) | `DDA9.1` (앱 컨테이너 내 접근) |
| 시스템 부팅 시간 | X | - | - |
| 디스크 공간 | X | - | - |
| 활성 키보드 | X | - | - |

### 11-7. 서드파티 라이브러리 현황

| 라이브러리 | 유형 | Privacy Manifest | 비고 |
|-----------|------|:----------------:|------|
| AppCore | 로컬 패키지 | 없음 | CryptoKit(SHA256), 파일 타임스탬프 사용 |
| BlurUIKit | 원격 (TimOliver/BlurUIKit >= 1.2.2) | **확인 필요** | - |
| LiquidGlassKit | 로컬 패키지 | 없음 | Metal/MetalKit 사용 |

---

## 12. PickPhoto 실행 계획

### Phase 1 — 제출 차단 해소 (필수, 코드 작업)

| # | 작업 | 상세 |
|---|------|------|
| 1 | PrivacyInfo.xcprivacy 생성 | 파일 타임스탬프(`DDA9.1`), UserDefaults(`CA92.1`), Photos 수집 선언 |
| 2 | ITSAppUsesNonExemptEncryption 추가 | Info.plist에 `false` 설정 |
| 3 | NSPhotoLibraryUsageDescription 한글화 | Localization 파일 추가 |
| 4 | 서드파티 SDK Privacy Manifest 확인 | BlurUIKit, LiquidGlassKit 점검 |

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
| 9 | 스크린샷 준비 | iPhone 6.9" (1260x2736) 1~10장 |
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
| 16 | 디버그 코드 분리 확인 | 릴리즈 빌드에서 Debug 전용 코드 제외 |
| 17 | 전체 흐름 크래시 테스트 | 모든 주요 시나리오 테스트 |
| 18 | 접근성 확대 | VoiceOver 전체 UI, Dynamic Type |
| 19 | Localization 파일 분리 | 한/영 .strings 파일 |

### Phase 6 — 빌드 및 제출

| # | 작업 | 상세 |
|---|------|------|
| 20 | Xcode 26 SDK 빌드 | 2026.04.28부터 필수 |
| 21 | Archive & Upload | Product > Archive > Distribute App |
| 22 | 심사 제출 | Submit for Review |

---

## 13. Apple 공식 참고 문서

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

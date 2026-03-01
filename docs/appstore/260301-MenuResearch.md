# 그리드 전체메뉴(...) 하위 메뉴 구성 조사

> 작성일: 2026-03-01
> 목적: 그리드 화면 상단 ellipsis(...) 메뉴의 "사용자/설정", "구독/결제", "고객센터/도움말" 3개 메뉴 하위 구성 결정을 위한 타 앱 사례 조사
> 정리일: 2026-03-01 — App Store 심사/BM/한국법 관련 중복 내용을 Gate1~4 / AppStore1 / bm-spec에 이관하고, 메뉴 고유 내용만 유지

---

## 목차

1. [현재 메뉴 구조](#1-현재-메뉴-구조)
2. [사용자/설정 메뉴 조사](#2-사용자설정-메뉴-조사)
3. [구독/결제 메뉴 조사](#3-구독결제-메뉴-조사)
4. [고객센터/도움말 메뉴 조사](#4-고객센터도움말-메뉴-조사)
5. [Apple HIG 설정 메뉴 패턴](#5-apple-hig-설정-메뉴-패턴)
6. [PIClear 최종 메뉴 권장안](#6-pickphoto-최종-메뉴-권장안)
7. [메뉴 구현 체크리스트](#7-메뉴-구현-체크리스트)

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

### 2-3. PIClear 추천 항목

PIClear는 계정 없이 동작하는 **로컬 특화 앱**이므로 사진 정리 설정 + 앱 사용 통계 중심이 적합.

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

### 3-3. PIClear 추천 항목

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

### 4-2. PIClear 추천 항목

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

## 5. Apple HIG 설정 메뉴 패턴

### 5-1. Settings Bundle vs 앱 내 설정

| 변경 빈도 | 위치 | 예시 |
|----------|------|------|
| 자주 변경 | **앱 내 설정** | 그리드 열 수, 삭제 감도, 얼굴 인식 ON/OFF |
| 거의 안 변경 | **Settings Bundle** | 분석 수집 동의, 디버그 모드 |

### 5-2. 시스템 설정 딥링크 (공식 API만)

```swift
// ✅ 공식 (안전)
UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
UIApplication.shared.open(URL(string: UIApplication.openNotificationSettingsURLString)!)

// ❌ 비공식 (app-settings:// 등) — 미래 iOS 동작 보장 안 됨
```

### 5-3. 접근성 필수 항목

| 항목 | 필수 여부 | PIClear 대응 |
|------|----------|---------------|
| **VoiceOver 레이블** | 필수 | 모든 인터랙티브 요소에 `accessibilityLabel` |
| **스와이프 대체 액션** | **필수** (핵심!) | `accessibilityCustomActions`로 삭제 대안 제공 |
| **터치 타겟 44x44pt** | 필수 | 버튼/셀 최소 크기 |
| **색상 대비 4.5:1** | 필수 | 텍스트/배경 대비 검증 |
| **Dynamic Type** | 실질적 필수 | `preferredFont(forTextStyle:)` 사용 |
| **다크모드** | 강력 권장 | Semantic Color 사용 |
| **Reduce Motion** | 권장 | 애니메이션 → crossfade 대체 |

### 5-4. 앱 정보(About) 필수 항목

| 항목 | 필수/권장 | 근거 |
|------|----------|------|
| **개인정보처리방침** | 필수 | App Store 심사 |
| **오픈소스 라이선스** | 필수 | 법적 의무 (LiquidGlassKit 등) |
| 앱 버전/빌드 | 강력 권장 | 버그 신고 참조 |
| 저작권 표시 | 권장 | 법적 보호 |
| 문의/지원 링크 | 권장 | UX |

---

## 6. PIClear 최종 메뉴 권장안

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

## 7. 메뉴 구현 체크리스트

### 메뉴에서 반드시 접근 가능해야 하는 항목

| # | 항목 | 메뉴 위치 | 근거 |
|---|------|----------|------|
| 1 | 개인정보처리방침 링크 | 설정 > 개인정보 / 도움말 | App Store 5.1.1 + 한국법 제30조 |
| 2 | 구매 복원 버튼 | 구독 관리 | App Store 3.1.1 |
| 3 | 이용약관 링크 | 구독 관리 > 페이월 / 도움말 | App Store 3.1.2 |
| 4 | 분석 옵트아웃 토글 | 설정 > 개인정보 | 한국법 제37조 |
| 5 | 오픈소스 라이선스 | 도움말 | 법적 의무 |
| 6 | 삭제대기함 FAQ 강조 | 도움말 > FAQ | Undo 기반 삭제가 일반 앱과 달라 혼란 가능 |

---

## 이관된 내용 참조

본 문서에서 다음 내용은 중복 제거를 위해 해당 문서로 이관되었습니다:

| 원본 섹션 | 이관 대상 | 이관된 내용 |
|----------|----------|-----------|
| §5 App Store 심사 필수 항목 | [AppStore1](260211AppStore1.md) §3, [Gate1](260212AppStore-Gate1.md), [Gate2](260212AppStore-Gate2.md), [Gate3](260212AppStore-Gate3.md) | 구독/IAP, 개인정보, 기타 필수 항목 |
| §6 사진 앱(PhotoKit) 특화 필수사항 | [Gate1](260212AppStore-Gate1.md) (Privacy Manifest XML 예시), [Gate2](260212AppStore-Gate2.md) (Nutrition Label), [Gate3](260212AppStore-Gate3.md) (권한 문구 예시) | PhotoKit 권한, Privacy Manifest, Nutrition Label |
| §7 구독 앱 필수 UI 요소 | [bm-spec-edit](../bm/260227bm-spec-edit.md), [bm-spec](../bm/260227bm-spec.md) 참조 | 페이월 필수 정보, StoreKit 패턴 |
| §8 프라이버시/개인정보 필수사항 | [Gate2](260212AppStore-Gate2.md) (GDPR, 한국법 신규, 얼굴인식 고지 문구) | 한국법, GDPR, 처리방침, 옵트아웃 |
| §9 실제 리젝 사례 | [AppStore1](260211AppStore1.md) §12 (Halide 사건, 한국 특화 리젝, 트렌드) | 리젝 통계, 사례, 트렌드 |
| §12 핵심 체크리스트 (심사/법적) | [Gate2](260212AppStore-Gate2.md) (한국법 체크리스트), [Gate3](260212AppStore-Gate3.md) (AI 의사결정), [Gate4](260212AppStore-Gate4.md) (VoiceOver, Liquid Glass) | 심사/법적 체크리스트 → Gate별 분산 |

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

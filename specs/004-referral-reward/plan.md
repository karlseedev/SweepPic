# Implementation Plan: 초대 리워드 프로그램

> **⚠️ Apple Developer Program (유료) 가입 후 설정 필요 항목**
>
> | 항목 | 설정 위치 | 용도 | 필요 시점 |
> |------|----------|------|----------|
> | Associated Domains | Apple Developer > Identifiers > App ID | `sweeppic.link` Universal Link 작동 | Phase 7~8 |
> | APNs Key (.p8) | Apple Developer > Keys | 초대자 보상 도착 푸시 알림 | Phase 8 |
> | ASC API Key | App Store Connect > Users and Access > Keys | Promotional Offer 서명 + Offer Code 관리 | Phase 3~ |

**Branch**: `004-referral-reward` | **Date**: 2026-03-26 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/specs/004-referral-reward/spec.md`

## Summary

SweepPic에 초대 리워드 프로그램을 구현한다. 초대자가 고유 링크를 공유하면, 피초대자가 앱 설치 후 초대 코드를 입력하여 14일 프리미엄을 받고, 초대자도 14일 보상을 수령하는 양방향 보상 시스템.

**기술 접근**: Apple Offer Code URL Redemption (신규 사용자) + Promotional Offer (기존/만료 구독자) 하이브리드. 서버는 Supabase Edge Functions + PostgreSQL. Push는 APNs HTTP/2 직접 호출.

## Technical Context

**Language/Version**: Swift 5.9+, TypeScript (Deno — Supabase Edge Functions)
**Primary Dependencies**: UIKit, StoreKit 2, Supabase (PostgreSQL + Edge Functions), APNs HTTP/2
**Storage**: Supabase PostgreSQL (서버), Keychain (클라이언트 user_id), UserDefaults (Push 상태)
**Testing**: XCTest (클라이언트), Supabase CLI 로컬 테스트 (서버)
**Target Platform**: iOS 16+
**Project Type**: Mobile (iOS) + Serverless API (Supabase Edge Functions)
**Performance Goals**: 코드 입력→리딤 시트 2분 이내, 링크 생성→공유 30초 이내
**Constraints**: Apple Offer Code 한도 (분기 1M), 동시 Offer 10개 중 5개 사용
**Scale/Scope**: 초기 수천~수만 초대, Offer Code 풀 5,000개 임계값

## Constitution Check

*GATE: Constitution은 템플릿 상태 (프로젝트별 원칙 미설정). 게이트 위반 없음.*

프로젝트 CLAUDE.md 규칙 준수 확인:
- [x] 모든 파일 1,000줄 이하 — 기능별 파일 분할 계획 반영
- [x] 50줄 이상 수정 전 커밋 — 태스크별 커밋 전략
- [x] 상세 주석 — 코딩 스타일 준수
- [x] 파일 삭제 시 사용자 허락 — 삭제 작업 없음

## Project Structure

### Documentation (this feature)

```text
specs/004-referral-reward/
├── plan.md              # This file
├── research.md          # Phase 0: 기술 리서치
├── data-model.md        # Phase 1: 데이터 모델
├── quickstart.md        # Phase 1: 빠른 시작 가이드
├── contracts/
│   ├── api-endpoints.md # Phase 1: Supabase Edge Function API
│   └── protocols.md     # Phase 1: Swift 프로토콜
└── tasks.md             # Phase 2: 구현 태스크 (/speckit.tasks)
```

### Source Code (repository root)

```text
# 클라이언트 (iOS)
Sources/AppCore/
├── Models/
│   └── ReferralModels.swift              # 초대 코드, 보상 모델
├── Services/
│   ├── ReferralService.swift             # Supabase API 통신 (HTTP 에러 분기 포함)
│   ├── ReferralCodeParser.swift          # 정규식 코드 추출 (실패/다수 매칭 처리)
│   ├── PushNotificationService.swift     # Push 토큰 관리 + 배지 관리
│   ├── OfferRedemptionService.swift      # Offer Code 리딤 URL 열기 + 미보고 리딤 재감지
│   ├── PromotionalOfferService.swift     # Promotional Offer 서명 요청 + 적용
│   ├── ReferralNetworkMonitor.swift      # NWPathMonitor 래퍼 (오프라인 감지)
│   └── Logger+Referral.swift             # 초대 전용 Logger 카테고리
└── Stores/
    └── ReferralStore.swift               # Keychain user_id + 로컬 상태 (Push 프리프롬프트 표시 여부 등)

SweepPic/SweepPic/
├── Features/
│   └── Referral/                         # 새 기능 폴더
│       ├── Share/
│       │   ├── ReferralExplainViewController.swift   # 초대 설명 화면
│       │   └── ReferralShareManager.swift            # 공유 메시지 생성 + 공유 시트
│       ├── CodeInput/
│       │   └── ReferralCodeInputViewController.swift # 코드 입력 화면 (check-status 3분기 + 로딩/에러)
│       ├── Reward/
│       │   ├── ReferralRewardViewController.swift    # 보상 수령 화면 (모달 — 콜드스타트/메뉴 공용, 빈 상태 포함)
│       │   └── ReferralRewardClaimManager.swift      # 보상 수령 로직 (Promotional/OfferCode 분기 + 재시도)
│       ├── DeepLink/
│       │   └── ReferralDeepLinkHandler.swift         # Universal Link + Custom URL Scheme 처리
│       └── Analytics/
│           └── ReferralAnalytics.swift               # 초대 전용 분석 이벤트 (9개 + 속성)
├── Features/Monetization/
│   ├── Gate/
│   │   ├── TrashGatePopupViewController.swift  # 수정: 초대 프로모 추가
│   │   └── UsageGaugeDetailPopup.swift         # 수정: 초대 프로모 추가
│   ├── Celebration/
│   │   └── CelebrationViewController.swift     # 수정: 초대 버튼 추가
│   └── Menu/
│       └── PremiumMenuViewController.swift      # 수정: 3개 항목 (친구 초대/초대 코드 입력/초대 혜택 받기)
├── App/
│   ├── AppDelegate.swift              # 수정: Push 등록, UNUserNotificationCenter.delegate
│   └── SceneDelegate.swift            # 수정: URL 핸들링, 콜드 스타트 보상 팝업, 토큰 갱신, 배지 초기화
└── Info.plist                         # 수정: URL Scheme, Associated Domains, Push Entitlement

# 서버 (Supabase)
supabase/                              # 새 디렉토리 (프로젝트 루트)
├── migrations/
│   └── 001_referral_tables.sql        # DB 스키마 (4 테이블)
├── functions/
│   ├── referral-landing/
│   │   └── index.ts                   # 랜딩 페이지 (HTML + OG 태그 + 인앱 브라우저 처리 + 리다이렉트)
│   ├── referral-api/
│   │   └── index.ts                   # REST API (코드 생성/매칭/보상 — rate limit 포함)
│   ├── offer-code-replenish/
│   │   └── index.ts                   # 코드 풀 보충 (매일 새벽 스케줄) + 실패 시 관리자 알림
│   ├── push-notify/
│   │   └── index.ts                   # APNs Push 발송 + 토큰 무효 시 삭제
│   └── _shared/
│       └── rate-limiter.ts            # IP/user_id 기반 rate limiting 공유 모듈
└── config.toml                        # Supabase 로컬 설정
```

**Structure Decision**: Mobile + Serverless API 구조. 기존 AppCore/SweepPic 계층 분리 패턴을 따르며, 서버 코드는 `supabase/` 디렉토리에 별도 관리. 기존 Monetization 모듈의 Gate/Celebration/Menu를 수정하여 초대 노출 포인트 추가. 보상 수령 화면은 모달(블러+카드) 통일 — 기존 CelebrationViewController/TrashGatePopup 패턴과 일관, iOS 18/26 버전 분기 불필요.

## Complexity Tracking

> 게이트 위반 없음. 복잡도 정당화 불필요.

## Key Implementation Decisions

### 1. 클라이언트-서버 분리

| 관심사 | 위치 | 이유 |
|--------|------|------|
| 초대 코드 생성/매칭 | 서버 (Supabase) | 원자적 코드 할당, 중복 방지 |
| Offer Code 풀 관리 | 서버 | ASC API 호출, 보안 (P8 키) |
| Promotional Offer 서명 | 서버 | P8 키 보안, JWT 생성 |
| Push 알림 발송 | 서버 | APNs HTTP/2 직접 호출 |
| Rate Limiting | 서버 | IP/user_id 기반 분당 제한 (FR-037) |
| 코드 보충 실패 알림 | 서버 | 관리자 이메일/Slack 발송 (FR-034) |
| 리딤 URL 열기 | 클라이언트 | UIApplication.shared.open |
| Transaction 감지 + 미보고 재감지 | 클라이언트 | StoreKit 2 Transaction.updates (FR-035) |
| 사용자 식별 | 클라이언트 (Keychain) | 앱 삭제 후에도 유지 |
| 네트워크 모니터링 | 클라이언트 | NWPathMonitor 기반 오프라인 감지 (FR-039) |
| 배지 관리 | 클라이언트 | Push badge 설정/초기화 (FR-028) |

### 2. 기존 코드 수정 범위

| 파일 | 수정 내용 | 예상 변경량 | 관련 FR |
|------|----------|-----------|---------|
| `TrashGatePopupViewController.swift` | 팝업 하단에 초대 프로모 UI 추가 | ~50줄 | Story 4 |
| `CelebrationViewController.swift` | 확인 버튼 아래 초대 버튼 추가 | ~30줄 | Story 4 |
| `PremiumMenuViewController.swift` | "친구 초대" + "초대 코드 입력" + "초대 혜택 받기" 3개 메뉴 항목 추가 | ~40줄 | FR-041 |
| `AppDelegate.swift` | Push 등록, 토큰 처리, UNUserNotificationCenter.delegate | ~50줄 | FR-026~028 |
| `SceneDelegate.swift` | URL 핸들링, 콜드 스타트 시 보상 팝업 + 토큰 갱신 + 배지 초기화 | ~80줄 | FR-026, FR-028, FR-035 |
| `Info.plist` | URL Scheme + Associated Domains + Push Entitlement | ~15줄 | FR-022~024 |
| `SubscriptionStore.swift` | Promotional Offer purchase + referralSubscriptionStatus() | ~40줄 | FR-012, FR-013 |
| `UsageGaugeDetailPopup.swift` | 게이지 바 팝업 하단에 초대 프로모 추가 | ~30줄 | Story 4 |

### 3. 새 파일 목록

**AppCore (9개 파일)**:
- `Models/ReferralModels.swift` — 초대 관련 데이터 모델
- `Services/ReferralService.swift` — Supabase API 통신
- `Services/ReferralCodeParser.swift` — 정규식 코드 추출 (실패/다수 매칭 처리)
- `Services/PushNotificationService.swift` — Push 토큰 관리 + 배지 관리
- `Services/OfferRedemptionService.swift` — Offer Code 리딤 URL 생성 + 열기 + 미보고 리딤 재감지
- `Services/PromotionalOfferService.swift` — Promotional Offer 서명 요청 + 적용
- `Services/ReferralNetworkMonitor.swift` — NWPathMonitor 래퍼 (FR-039, 기존 TrashGatePopup 패턴 재사용 가능)
- `Stores/ReferralStore.swift` — Keychain user_id + 로컬 상태
- `Services/Logger+Referral.swift` — 초대 전용 Logger 카테고리

**SweepPic Features/Referral (7개 파일)**:
- `Share/ReferralExplainViewController.swift` — 초대 설명 화면
- `Share/ReferralShareManager.swift` — 공유 메시지 생성 + 공유 시트
- `CodeInput/ReferralCodeInputViewController.swift` — 코드 입력 화면 (로딩/에러/오프라인 상태 포함)
- `Reward/ReferralRewardViewController.swift` — 보상 수령 화면 (모달 통일 — 콜드스타트/메뉴 공용, 빈 상태 "수령 가능한 보상이 없습니다" + [친구 초대하기] 포함, FR-040/042)
- `Reward/ReferralRewardClaimManager.swift` — 보상 수령 로직 (Promotional/OfferCode 분기 + 실패 재시도)
- `DeepLink/ReferralDeepLinkHandler.swift` — Universal Link + Custom URL Scheme 처리
- `Analytics/ReferralAnalytics.swift` — 초대 전용 분석 이벤트 (FR-044, 9개 이벤트 + 속성)

**Supabase (6개 파일)**:
- `migrations/001_referral_tables.sql` — DB 스키마 (4 테이블)
- `functions/referral-landing/index.ts` — 랜딩 페이지
- `functions/referral-api/index.ts` — REST API (rate limiting 미들웨어 포함)
- `functions/offer-code-replenish/index.ts` — 코드 풀 보충 + 실패 시 관리자 알림 (FR-034)
- `functions/push-notify/index.ts` — Push 발송
- `functions/_shared/rate-limiter.ts` — IP/user_id 기반 rate limiting 공유 모듈 (FR-037)

### 4. 의존성 그래프

```
[선행 작업 — 코드 외]
  ├─ 커스텀 도메인 구매 (개발 중에는 Supabase 기본 도메인으로 대체, FR-047)
  ├─ ASC에 5개 Offer 생성
  ├─ P8 키 발급 (ASC API + APNs) → Supabase Vault 저장 (FR-045~046)
  ├─ OG 디자인 에셋 제작 (1200×630px, FR-021)

[서버 기반]
  DB 스키마 + _shared/rate-limiter.ts
    ↓
  referral-api (코드 생성, 매칭, 보상 — rate limit 포함)
    ├─ referral-landing (랜딩 페이지 — 독립, referral-api와 DB만 공유)
    ├─ push-notify (Push 발송 — referral-api/report-redemption에서 호출)
    └─ offer-code-replenish (코드 풀 보충 — 독립 스케줄, 매일 새벽)

[클라이언트 기반 — 서버 API 의존]
  ReferralStore (기반 레이어)
    ↓
  ReferralService (API 통신 — HTTP 에러 분기, FR-042)
    ↓
  ReferralNetworkMonitor (오프라인 감지, FR-039)
    ├─ ReferralExplain + ShareManager (Phase 1: 공유 — 로딩/에러/성공 상태, FR-038)
    ├─ CodeInput (Phase 3: 코드 입력 — 정규식 실패/다수 매칭, FR-006)
    ├─ DeepLinkHandler (Phase 2.5: 링크 재탭 — check-status→match-code 시퀀스)
    ├─ ReferralRewardViewController + ClaimManager (Phase 4: 보상 — 모달, 순차 수령/실패 재시도/중단 복구, FR-040)
    ├─ OfferRedemptionService (리딤 + 미보고 재감지, FR-035)
    ├─ PushNotificationService (토큰 갱신 + 배지 관리, FR-026/028)
    └─ ReferralAnalytics (9개 이벤트 + 속성, FR-044)

[기존 코드 수정 — 클라이언트 기반 의존]
  TrashGatePopup + UsageGaugeDetailPopup + Celebration + PremiumMenu (노출 포인트)
    → ReferralExplainViewController 호출
  AppDelegate (Push 등록 + UNUserNotificationCenter.delegate)
  SceneDelegate (URL 핸들링 + 콜드 스타트 보상 팝업(모달) + 토큰 갱신 + 배지 초기화)
```

### 5. 스펙 보완으로 추가된 구현 사항 (체크리스트 반영)

| FR | 내용 | 구현 위치 | 복잡도 |
|----|------|----------|--------|
| FR-034 | 코드 보충 실패 시 관리자 알림 | offer-code-replenish + Slack/Email webhook | 낮음 |
| FR-035 | report-redemption 실패 재시도 + 미보고 재감지 | OfferRedemptionService + SceneDelegate | 중간 |
| FR-036 | 서버 비가용 에러 안내 | 모든 서버 호출 화면 | 낮음 |
| FR-037 | Rate limiting (분당 5~10회) | _shared/rate-limiter.ts + referral-api | 중간 |
| FR-038 | UI 3상태 (로딩/성공/에러) | 모든 서버 호출 VC | 낮음 |
| FR-039 | 오프라인 감지 + 자동 재시도 | ReferralNetworkMonitor (NWPathMonitor) | 낮음 |
| FR-040 | 보상 수령 화면 (모달, 콜드스타트/메뉴 공용) | ReferralRewardViewController | 낮음 |
| FR-041 | 프리미엄 메뉴 3개 항목 (친구 초대 / 초대 코드 입력 / 초대 혜택 받기) | PremiumMenuViewController | 낮음 |
| FR-042 | HTTP 상태별 에러 처리 | ReferralService | 낮음 |
| FR-043 | 보상 만료 무고지 처리 | get-pending-rewards 필터 | 낮음 |
| FR-044 | 분석 이벤트 9개 + 속성 | ReferralAnalytics | 중간 |
| FR-045~046 | P8 키 Vault 관리 | Supabase 환경 변수 | 낮음 |
| FR-047 | 개발 환경 도메인 폴백 | 환경 변수 CUSTOM_DOMAIN | 낮음 |
| FR-048 | 별도 최적화 불필요, 병목 시 대응 | — | 낮음 |

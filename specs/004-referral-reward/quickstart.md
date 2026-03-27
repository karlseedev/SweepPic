# Quickstart: 초대 리워드 프로그램

**Feature**: 004-referral-reward
**Date**: 2026-03-26

## 선행 작업 (코드 외)

구현 시작 전 완료해야 할 항목:

| # | 항목 | 담당 | 예상 시간 |
|---|------|------|----------|
| 1 | 커스텀 도메인 구매 (sweeppic.link 등) | 수동 | 10분 |
| 2 | 도메인 DNS → Supabase Edge Function 연결 | 수동 | 30분 |
| 3 | ASC에 5개 Offer 생성 | 수동 | 30분 |
| 4 | ASC에서 P8 키 발급 (In-App Purchase + APNs) | 수동 | 10분 |
| 5 | P8 키를 Supabase Vault에 저장 | 수동 | 10분 |
| 6 | OG 이미지 디자인 에셋 제작 | 디자인 | 별도 |

### ASC Offer 생성 상세

| Offer Name | 유형 | 상품 | 기간 | 대상 | Intro Offer 중복 |
|-----------|------|------|------|------|----------------|
| `referral_invited_monthly` | Offer Code (One-time) | plus_monthly | 2주 무료 | New+Existing+Expired | Yes |
| `referral_invited_yearly` | Offer Code (One-time) | plus_yearly | 2주 무료 | Existing | — |
| `referral_extend_monthly` | Promotional Offer | plus_monthly | 2주 무료 | Existing+Expired | — |
| `referral_extend_yearly` | Promotional Offer | plus_yearly | 2주 무료 | Existing+Expired | — |
| `referral_reward_01` | Offer Code (One-time) | plus_monthly | 2주 무료 | New | — |

### P8 키 용도

| 키 | 용도 | JWT iss 필드 |
|-----|------|-------------|
| In-App Purchase Key | ASC API + Promotional Offer 서명 | issuer_id |
| APNs Key | Push 알림 발송 | team_id |

> 동일한 P8 파일을 공유할 수 있지만 JWT 생성 로직은 별도.

---

## 개발 환경 설정

### Supabase 로컬 개발

```bash
# Supabase CLI 설치 (미설치 시)
brew install supabase/tap/supabase

# 프로젝트 루트에서 Supabase 초기화
cd /Users/karl/Project/Photos/iOS
supabase init  # supabase/ 디렉토리 생성

# 로컬 Supabase 시작
supabase start

# DB 마이그레이션 적용
supabase db reset  # migrations/ 파일 자동 적용

# Edge Function 로컬 실행
supabase functions serve referral-api --env-file .env.local
supabase functions serve referral-landing --env-file .env.local
```

### Xcode 설정

1. **Associated Domains** 추가:
   - Target → Signing & Capabilities → + Associated Domains
   - `applinks:sweeppic.link` (또는 구매한 도메인)

2. **URL Scheme** 추가:
   - Target → Info → URL Types → +
   - Identifier: `com.karl.SweepPic.referral`
   - URL Schemes: `sweeppic`

3. **Push Notification** 추가:
   - Target → Signing & Capabilities → + Push Notifications
   - Background Modes → Remote notifications 체크

---

## 구현 순서 (권장)

```
Phase A: 서버 기반 (Supabase)
  1. DB 스키마 마이그레이션
  2. referral-api Edge Function (모든 엔드포인트)
  3. referral-landing Edge Function (랜딩 페이지)
  → 서버 API를 cURL/Postman으로 테스트

Phase B: 클라이언트 기반 레이어 (AppCore)
  4. ReferralModels (데이터 모델)
  5. ReferralStore (Keychain user_id)
  6. ReferralService (API 통신)
  7. ReferralCodeParser (정규식)
  → 유닛 테스트

Phase C: 클라이언트 UI (SweepPic)
  8. ReferralExplainViewController + ShareManager (공유 플로우)
  9. ReferralCodeInputViewController (코드 입력)
  10. OfferRedemptionService (리딤 URL 열기 + Transaction 감지)
  11. ReferralRewardViewController + ClaimManager (보상 수령 — 모달, 콜드스타트/메뉴 공용)
  12. ReferralDeepLinkHandler (딥링크)
  → 시뮬레이터 + 실기기 테스트

Phase D: 기존 코드 통합
  13. AppDelegate (Push 등록)
  14. SceneDelegate (URL 핸들링 + 보상 체크)
  15. TrashGatePopup + Celebration + PremiumMenu (노출 포인트)
  → 전체 플로우 통합 테스트

Phase E: 서버 자동화 + Push
  16. PushNotificationService (토큰 관리)
  17. push-notify Edge Function (APNs 호출)
  18. offer-code-replenish Edge Function (코드 풀 보충)
  → E2E 테스트

Phase F: Universal Link + 도메인
  19. apple-app-site-association 배포
  20. 커스텀 도메인 연결 + OG 태그
  21. 실기기 전체 플로우 테스트
```

---

## 테스트 전략

| 영역 | 방법 | 환경 |
|------|------|------|
| 서버 API | cURL / Postman / Supabase CLI | 로컬 Supabase |
| 코드 파싱 | XCTest 유닛 테스트 | Xcode |
| ReferralService | Mock 서버 응답 + XCTest | Xcode |
| 리딤 URL 열기 | 시뮬레이터 (URL open 확인) | Xcode Simulator |
| Offer Code 리딤 | TestFlight / Production | 실기기 |
| Promotional Offer | TestFlight / Production | 실기기 |
| Push 알림 | 실기기 (시뮬레이터 Push 미지원) | 실기기 |
| Universal Link | 실기기 (시뮬레이터 미지원) | 실기기 |
| 인앱 브라우저 | 실기기 (카카오톡, 인스타 등) | 실기기 |

> **핵심**: Offer Code 리딤은 Production에서만 테스트 가능 (Apple 제한).
> TestFlight에서 일반 구독 구매로 Transaction.updates 감지 로직을 검증하고,
> Production 배포 후 실제 Offer Code로 E2E 테스트 수행.

---

## 환경 변수 (.env.local)

```bash
# Supabase (이미 xcconfig에 존재)
SUPABASE_URL=http://localhost:54321
SUPABASE_SERVICE_ROLE_KEY=...

# Apple
APP_STORE_APP_ID=...              # Apple ID (숫자)
BUNDLE_ID=com.karl.SweepPic
TEAM_ID=...
ASC_KEY_ID=...                    # In-App Purchase P8 키 ID
ASC_ISSUER_ID=...                 # ASC Issuer ID
ASC_PRIVATE_KEY=...               # P8 키 내용 (Base64)
APNS_KEY_ID=...                   # APNs P8 키 ID (별도일 수 있음)
APNS_PRIVATE_KEY=...              # APNs P8 키 내용

# Domain
CUSTOM_DOMAIN=sweeppic.link       # 구매한 도메인 (미구매 시 빈 값 → Supabase 기본 도메인 폴백)

# Admin Alerts (FR-034)
SLACK_WEBHOOK_URL=...             # 코드 보충 실패 시 알림
ADMIN_EMAIL=...                   # 이메일 알림 (선택)
```

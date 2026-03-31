# Tasks: 초대 리워드 프로그램

**Input**: Design documents from `/specs/004-referral-reward/`
**Prerequisites**: plan.md, spec.md, data-model.md, contracts/, research.md, quickstart.md

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: 프로젝트 초기화 및 기본 구조 생성

- [X] T001 Supabase 프로젝트 초기화 — `supabase/config.toml` 생성, 로컬 개발 환경 설정
- [X] T002 DB 스키마 마이그레이션 생성 — `supabase/migrations/001_referral_tables.sql` (referral_links, referrals, pending_rewards, offer_codes 4개 테이블 + 인덱스 + RLS)
- [X] T003 [P] Info.plist에 URL Scheme(`sweeppic://`) + Associated Domains(`applinks:{domain}`) + Push Notification Entitlement 추가 — `SweepPic/SweepPic/Info.plist`
- [X] T004 [P] Supabase Edge Function 공유 모듈 — `supabase/functions/_shared/rate-limiter.ts` (IP/user_id 기반 분당 제한, FR-037)
- [X] T005 [P] 환경 변수 설정 — `.env.local` (SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY, APP_STORE_APP_ID, BUNDLE_ID, TEAM_ID, ASC_KEY_ID, ASC_ISSUER_ID, APNS_KEY_ID, CUSTOM_DOMAIN, SLACK_WEBHOOK_URL)

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: 모든 User Story가 의존하는 핵심 기반 레이어

**⚠️ CRITICAL**: 이 Phase 완료 전까지 User Story 작업 시작 불가

- [X] T006 [P] 초대 데이터 모델 — `Sources/AppCore/Models/ReferralModels.swift` (ReferralLink, ReferralMatchResult, ReferralStatus, PendingRewardResponse, RewardType, RewardStatus, PromotionalOfferSignature — data-model.md의 Client-Side Models 참조)
- [X] T007 [P] 초대 전용 Keychain Store — `Sources/AppCore/Stores/ReferralStore.swift` (sweeppic_referral_id UUID 생성/조회, Push 프리프롬프트 표시 여부 UserDefaults 기록, FR-029/FR-025)
- [X] T008 [P] 초대 전용 Logger — `Sources/AppCore/Services/Logger+Referral.swift` (Logger.referral 카테고리 추가, 기존 Logger+App.swift 패턴 참조)
- [X] T009 [P] 네트워크 모니터 — `Sources/AppCore/Services/ReferralNetworkMonitor.swift` (NWPathMonitor 래퍼, isConnected, onStatusChange 콜백, FR-039)
- [X] T010 ReferralService 기반 구조 — `Sources/AppCore/Services/ReferralService.swift` (Supabase URL/Key 설정, URLSession async/await 기본 구조, HTTP 상태별 에러 분기 200/429/500/timeout, FR-042. 엔드포인트 메서드는 각 Story에서 추가)

**Checkpoint**: 기반 레이어 완료 — User Story 구현 시작 가능

---

## Phase 3: User Story 1 — 초대 링크 생성 및 공유 (P1) 🎯 MVP

**Goal**: 초대자가 고유 초대 링크를 생성하고 카카오톡 등으로 공유

**Independent Test**: 초대하기 버튼 탭 → 초대 설명 화면 → 공유 시트 → 공유 완료 후 Push 프리프롬프트

### Server

- [X] T011 [US1] referral-api create-link 엔드포인트 — `supabase/functions/referral-api/index.ts` (POST /create-link: user_id로 referral_code 조회 또는 생성, x0{6chars}9j 형식, 충돌 시 최대 5회 재생성, rate limit 적용. contracts/api-endpoints.md 참조)

### Client — AppCore

- [X] T012 [P] [US1] ReferralService.createOrGetLink() 메서드 추가 — `Sources/AppCore/Services/ReferralService.swift` (create-link API 호출, ReferralLink 반환)

### Client — UI

- [X] T013 [US1] 초대 설명 화면 — `SweepPic/SweepPic/Features/Referral/Share/ReferralExplainViewController.swift` (기획문서 Phase 1 와이어프레임 참조: "친구에게 초대하고 함께 프리미엄 받기!" 제목, 나/친구 보상 설명, [초대하기] 버튼 + "이미 구독 중이어도 14일 무료 연장" 부가 문구, 로딩/에러 상태 FR-038)
- [X] T014 [US1] 공유 메시지 생성 + 공유 시트 — `SweepPic/SweepPic/Features/Referral/Share/ReferralShareManager.swift` (FR-003 공유 메시지 5개 요소: 앱 소개/초대코드/설치링크/재탭 안내/수동 입력 폴백. UIActivityViewController 표시, completionHandler에서 completed=true/false 분기, completed=false 시 아무 동작 없음)
- [X] T015 [US1] Push 프리프롬프트 로직 — `SweepPic/SweepPic/Features/Referral/Share/ReferralExplainViewController.swift` 에 추가 (공유 완료 후: ReferralStore.hasAskedPushPermission 체크 → 1회만 표시, .notDetermined → 시스템 팝업, .denied → 알림 꺼짐 안내 + [설정으로 이동]/[나중에], .authorized → 미표시, FR-025)

**Checkpoint**: 초대 링크 생성 및 공유 독립 테스트 가능

---

## Phase 4: User Story 2 — 피초대자 앱 설치 및 혜택 적용 (P1)

**Goal**: 피초대자가 초대 코드를 입력하여 14일 프리미엄 혜택을 받음

**Independent Test**: 초대 코드 입력 → 코드 매칭 → App Store 리딤 시트 → 14일 프리미엄 활성화

### Server

- [X] T016 [US2] referral-api match-code 엔드포인트 — `supabase/functions/referral-api/index.ts` 에 추가 (POST /match-code: 코드 유효성 검증, 자기 초대 감지, 중복 체크, subscription_status 기반 offer_name 결정, SELECT FOR UPDATE 원자적 코드 할당, 리딤 URL 생성. 5개 응답 status: matched/already_redeemed/self_referral/invalid_code/no_codes_available)
- [X] T017 [P] [US2] referral-api check-status 엔드포인트 — `supabase/functions/referral-api/index.ts` 에 추가 (POST /check-status: user_id로 referrals 조회, none/matched/redeemed 3분기 응답, matched 시 할당 코드 만료 확인 → 만료면 새 코드 할당)
- [X] T018 [P] [US2] referral-api report-redemption 엔드포인트 — `supabase/functions/referral-api/index.ts` 에 추가 (POST /report-redemption: referrals → redeemed, offer_codes → used, pending_rewards INSERT. push-notify 연동은 T040에서 추가)
- [X] T019 [P] [US2] 랜딩 페이지 — `supabase/functions/referral-landing/index.ts` (GET /r/{code}: 코드 유효성 검증, 분석 이벤트 기록, OG 메타태그 HTML 응답, 인앱 브라우저 감지 JS — 카카오톡/LINE/Instagram/Facebook/X 대응, Custom URL Scheme + App Store 리다이렉트. 기획문서 §A 랜딩 페이지 구현 코드 참조)

### Client — AppCore

- [X] T020 [P] [US2] 정규식 코드 파서 — `Sources/AppCore/Services/ReferralCodeParser.swift` (정규식 /x0([a-zA-Z0-9]{6})9j/ 매칭, 실패 시 nil 반환, 다수 매칭 시 첫 번째 코드 사용, FR-006)
- [X] T021 [P] [US2] ReferralService에 matchCode(), checkStatus(), reportRedemption() 메서드 추가 — `Sources/AppCore/Services/ReferralService.swift`
- [X] T022 [US2] Offer Code 리딤 서비스 — `Sources/AppCore/Services/OfferRedemptionService.swift` (리딤 URL 열기 UIApplication.shared.open, Transaction.updates에서 referral_invited_* offerName 감지, report-redemption 호출 + 지수 백오프 3회 재시도, 미보고 리딤 앱 실행 시 재감지, FR-035)

### Client — UI

- [X] T023 [US2] 코드 입력 화면 — `SweepPic/SweepPic/Features/Referral/CodeInput/ReferralCodeInputViewController.swift` (진입 시 check-status 우선 호출 → 3분기: none=붙여넣기 화면, matched="혜택이 아직 적용되지 않았어요"+[혜택 받기], redeemed="이미 초대 코드가 적용되었습니다.". 붙여넣기 → ReferralCodeParser로 추출 → matchCode API → 리딤 URL 열기. 에러 문구: 정규식 실패/자기 초대/무효 코드/코드 풀 소진/리딤 성공. 로딩/에러/오프라인 상태 FR-038~039)

**Checkpoint**: 피초대자 코드 입력 → 혜택 적용 독립 테스트 가능

---

## Phase 5: User Story 3 — 초대자 보상 수령 (P1)

**Goal**: 초대자가 보상 팝업 또는 메뉴에서 14일 프리미엄 보상을 수령

**Independent Test**: pending_rewards 존재 → 앱 콜드 스타트 시 팝업 → 보상 수령 (Promotional Offer 또는 Offer Code)

### Server

- [X] T024 [P] [US3] referral-api get-pending-rewards 엔드포인트 — `supabase/functions/referral-api/index.ts` 에 추가 (POST /get-pending-rewards: user_id로 status=pending인 보상 조회, 만료 보상 미포함 FR-043)
- [X] T025 [P] [US3] referral-api claim-reward 엔드포인트 — `supabase/functions/referral-api/index.ts` 에 추가 (POST /claim-reward: subscription_status 기반 보상 방식 결정 — monthly/expired_monthly → referral_extend_monthly, yearly/expired_yearly → referral_extend_yearly, none → referral_reward_01. Promotional: P8 키로 서명 생성 반환. Offer Code: 코드 할당 + 리딤 URL 반환. pending_rewards → completed, referrals → rewarded)

### Client — AppCore

- [X] T026 [P] [US3] Promotional Offer 서비스 — `Sources/AppCore/Services/PromotionalOfferService.swift` (서버에서 서명 요청 → Product.PurchaseOption.promotionalOffer 생성 → Product.purchase 호출, 실패 시 에러 반환)
- [X] T027 [P] [US3] ReferralService에 getPendingRewards(), claimReward() 메서드 추가 — `Sources/AppCore/Services/ReferralService.swift`
- [X] T028 [US3] SubscriptionStore 확장 — `SweepPic/SweepPic/Features/Monetization/Subscription/SubscriptionStore.swift` 에 추가 (referralSubscriptionStatus() → "none"/"monthly"/"yearly"/"expired_monthly"/"expired_yearly" 반환, purchaseWithPromotionalOffer() 메서드)

### Client — UI

- [X] T029 [US3] 보상 수령 화면 — `SweepPic/SweepPic/Features/Referral/Reward/ReferralRewardViewController.swift` (모달, 블러+카드, 콜드스타트/메뉴 공용. 보상 있음: "초대 보상 도착!" + "초대한 사람이 SweepPic에 가입했어요! 14일 무료 혜택을 받으세요" + [보상 받기] + "수령 가능한 보상: N건" + X닫기. 보상 없음: "수령 가능한 보상이 없습니다" + [친구 초대하기]. 수령 완료: "14일 무료 혜택이 적용되었습니다!" 다음 보상 자동 표시. 로딩/에러/재시도 FR-038. 기획문서 §초대 혜택 받기 UI 참조)
- [X] T030 [US3] 보상 수령 로직 매니저 — `SweepPic/SweepPic/Features/Referral/Reward/ReferralRewardClaimManager.swift` (claimReward API 호출 → RewardClaimResult 분기: .promotional → PromotionalOfferService로 적용, .offerCode → OfferRedemptionService로 리딤 URL 열기, .error → 에러 안내. 순차 수령 지원 — 1건 완료 후 다음 건 자동 진행)
- [X] T031 [US3] SceneDelegate 콜드 스타트 보상 팝업 — `SweepPic/SweepPic/App/SceneDelegate.swift` 에 추가 (scene(_:willConnectTo:) 에서 pending_rewards 조회 → 보상 있으면 ReferralRewardViewController 모달 표시, 포그라운드 복귀 시 미표시)

**Checkpoint**: 초대자 보상 수령 독립 테스트 가능 (콜드 스타트 팝업 + 메뉴 진입)

---

## Phase 6: User Story 4 — 초대 프로그램 노출 및 발견 (P2)

**Goal**: 4개 노출 포인트에서 초대 프로그램 발견

**Independent Test**: 각 노출 포인트에서 초대 프로모 UI 확인

- [X] T032 [P] [US4] 게이트 팝업 하단에 초대 프로모 추가 — `SweepPic/SweepPic/Features/Monetization/Gate/TrashGatePopupViewController.swift` 수정 ("초대 한 번마다 나도 친구도 14일 프리미엄 제공!" + [초대하기] + "이미 구독 중이어도 14일 무료 연장", 탭 시 ReferralExplainViewController 모달)
- [X] T033 [P] [US4] 게이지 바 팝업 하단에 초대 프로모 추가 — `SweepPic/SweepPic/Features/Monetization/Gate/UsageGaugeDetailPopup.swift` 수정 (동일 UI, 탭 시 ReferralExplainViewController 모달)
- [X] T034 [P] [US4] 축하 화면에 초대 버튼 추가 — `SweepPic/SweepPic/Features/Monetization/Celebration/CelebrationViewController.swift` 수정 ("친구에게도 알려주세요" + 초대 버튼, 탭 시 ReferralExplainViewController)
- [X] T035 [US4] 프리미엄 메뉴 3개 항목 추가 — `SweepPic/SweepPic/Features/Monetization/Menu/PremiumMenuViewController.swift` 수정 (UIMenu에 UIAction 3개: "친구 초대" → ReferralExplainVC, "초대 코드 입력" → ReferralCodeInputVC, "초대 혜택 받기" → ReferralRewardVC 모달, FR-041)

**Checkpoint**: 4개 노출 포인트 독립 확인 가능

---

## Phase 7: User Story 5 — 링크 재탭 자동 처리 (P2)

**Goal**: 앱 설치 후 초대 링크를 다시 탭하면 자동으로 혜택 적용

**Independent Test**: 앱 설치 상태에서 초대 링크 재탭 → 앱 열림 → 코드 자동 추출 → 리딤 URL 열기

- [X] T036 [US5] 딥링크 핸들러 — `SweepPic/SweepPic/Features/Referral/DeepLink/ReferralDeepLinkHandler.swift` (Universal Link URL에서 /r/{code} 추출, Custom URL Scheme sweeppic://referral/{code} 추출, check-status → 분기: none → matchCode + 리딤, matched → 기존 코드 리딤, redeemed → 무시, 자기 초대 감지 → "본인의 초대 코드는 사용할 수 없습니다" 안내)
- [X] T037 [US5] SceneDelegate URL 핸들링 — `SweepPic/SweepPic/App/SceneDelegate.swift` 에 추가 (scene(_:continue:) Universal Link 처리, scene(_:openURLContexts:) Custom URL Scheme 처리, 둘 다 ReferralDeepLinkHandler로 위임)
- [X] T038 [US5] apple-app-site-association 파일 — `supabase/functions/referral-landing/` 에서 `/.well-known/apple-app-site-association` 경로 응답 추가 (JSON: applinks → appIDs + paths ["/r/*"])

**Checkpoint**: 링크 재탭 자동 처리 독립 테스트 가능 (실기기 필요)

---

## Phase 8: User Story 6 — 초대자 Push 알림 (P3)

**Goal**: 피초대자 가입 시 초대자에게 Push 알림 발송

**Independent Test**: Push 허용 사용자 초대 → 피초대자 가입 → Push 수신 → 탭 → 보상 화면 직행

### Server

- [X] T039 [US6] Push 발송 Edge Function — `supabase/functions/push-notify/index.ts` (APNs HTTP/2 직접 호출: P8 키로 JWT 생성(iss=team_id), POST /3/device/{token}, payload: title "초대 보상 도착!" + body "초대한 사람이 SweepPic에 가입했어요! 14일 무료 혜택을 받으세요" + action_type "referral_reward" + reward_id + badge:1. 410 Gone 시 referral_links.device_token NULL 설정)
- [X] T040 [US6] referral-api/report-redemption에서 push-notify 호출 연동 — `supabase/functions/referral-api/index.ts` 수정 (report-redemption 로직 끝에서 초대자의 device_token 조회 → 있으면 push-notify 호출)

### Client

- [X] T041 [US6] Push 알림 서비스 — `Sources/AppCore/Services/PushNotificationService.swift` (UNUserNotificationCenter 권한 요청, registerForRemoteNotifications, device token 서버 전송 ReferralService.updateDeviceToken(), 배지 초기화 UIApplication.shared.applicationIconBadgeNumber=0, FR-026/028)
- [X] T042 [US6] referral-api update-device-token 엔드포인트 — `supabase/functions/referral-api/index.ts` 에 추가 (POST /update-device-token: referral_links.device_token 갱신)
- [X] T043 [US6] AppDelegate Push 등록 — `SweepPic/SweepPic/App/AppDelegate.swift` 수정 (UNUserNotificationCenter.delegate 설정, didRegisterForRemoteNotificationsWithDeviceToken → PushNotificationService 토큰 전달)
- [X] T044 [US6] SceneDelegate Push 연동 — `SweepPic/SweepPic/App/SceneDelegate.swift` 수정 (Push notification userInfo에서 action_type=="referral_reward" 감지 → ReferralRewardViewController 모달 표시, 포그라운드 Push → 인앱 배너 UNNotificationPresentationOptions [.banner, .sound], sceneWillEnterForeground에서 device token 서버 갱신 FR-026)

**Checkpoint**: Push 알림 전체 플로우 테스트 가능 (실기기 필요)

---

## Phase 9: User Story 7 — Offer Code 재고 자동 관리 (P3)

**Goal**: Offer Code 풀 자동 보충 + 만료 코드 정리

**Independent Test**: 코드 잔여량 5,000개 미만 시 자동 보충 트리거 확인

- [ ] T045 [US7] 코드 풀 보충 Edge Function — `supabase/functions/offer-code-replenish/index.ts` (offer_name별 available 코드 카운트 → 5,000개 미만 시 ASC API 호출로 코드 생성(최대 25,000개/배치) → CSV 다운로드 → offer_codes INSERT. 만료 코드 정리: expires_at < now() → status='expired'. 재시도: 1h→3h→6h. 최종 실패 시 Slack/Email 알림 FR-034)
- [ ] T046 [US7] Supabase cron 스케줄 설정 — `supabase/config.toml` 에 offer-code-replenish 함수 cron 추가 (`0 3 * * *` 매일 새벽 3시)

**Checkpoint**: 코드 풀 자동 보충 독립 테스트 가능

---

## Phase 10: Polish & Cross-Cutting Concerns

**Purpose**: 전체 Story에 걸친 분석 이벤트 + 데이터 조회 인프라 + 마무리

### 분석 인프라 (T047 선행)

- [ ] T051 Supabase RLS 화이트리스트 확장 — events 테이블 RLS 정책에 `referral.*` 9종 이벤트 추가 SQL 제공 (주인님 Supabase SQL Editor에서 실행). 기존 20종 → 29종. 참조: `docs/db/260310BMdata-impl.md` §2.2
- [ ] T052 [P] 범용 SQL 조회 RPC — Supabase에 `run_query(query_text TEXT)` RPC 함수 생성 (service_role 전용, anon/authenticated REVOKE). `scripts/analytics/sb-query.sh`에 `--sql` 모드 추가. SC-003~SC-008 크로스 테이블 측정 + ad-hoc 분석용

### 분석 이벤트

- [ ] T047 [P] 초대 분석 이벤트 — `SweepPic/SweepPic/Features/Referral/Analytics/ReferralAnalytics.swift` (9개 이벤트 + 속성: link_created, link_shared(share_target), landing_visited, code_entered(input_method), auto_matched(entry_method), code_assigned(offer_name, subscription_status), code_redeemed, reward_shown(entry_method), reward_claimed(reward_type, offer_name). 기존 AnalyticsService 패턴 참조, FR-044) + `docs/db/260225db-Spec.md` §3.1 총괄표에 초대 9종 추가 (21~29번) 및 §2 비용 수치 업데이트
- [ ] T048 각 Story VC에 분석 이벤트 호출 삽입 — ReferralExplainVC(link_created), ReferralShareManager(link_shared), ReferralCodeInputVC(code_entered, code_assigned, code_redeemed), ReferralDeepLinkHandler(auto_matched), ReferralRewardVC(reward_shown, reward_claimed)

### 통합 검증

- [ ] T049 전체 플로우 통합 검증 — 초대 링크 생성 → 앱 설치 → 링크 재탭 → 코드 입력 → 보상 수령 전 경로 E2E 테스트 (시뮬레이터 + 실기기)
- [ ] T050 실기기 테스트 — 카카오톡/인스타그램 인앱 브라우저 전체 플로우, Universal Link 동작, Push 수신, Offer Code 리딤 (Production 환경)

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: 의존성 없음 — 즉시 시작
- **Foundational (Phase 2)**: Phase 1 완료 필요 — 모든 User Story를 블로킹
- **US1~3 (Phase 3~5)**: Phase 2 완료 후 시작. **순차 실행 권장** (US1→US2→US3, 서버 API가 점진적으로 확장)
- **US4 (Phase 6)**: US1 완료 후 시작 (ReferralExplainVC 필요)
- **US5 (Phase 7)**: US2 완료 후 시작 (check-status/match-code API 필요)
- **US6 (Phase 8)**: US3 완료 후 시작 (report-redemption + push-notify 연동)
- **US7 (Phase 9)**: Phase 2 완료 후 독립 시작 가능 (서버만, 클라이언트 의존 없음)
- **Polish (Phase 10)**: US1~6 완료 후. T051(RLS 확장) → T047(분석 이벤트) 순서 필수. T052(범용 SQL RPC)는 T051과 병렬 가능

### User Story Dependencies

```
Phase 2 (Foundational)
  ↓
US1 (링크 공유) ──→ US4 (노출 포인트)
  ↓
US2 (혜택 적용) ──→ US5 (링크 재탭)
  ↓
US3 (보상 수령) ──→ US6 (Push 알림)

US7 (코드 풀 관리) — Phase 2 이후 독립 진행 가능
```

### Parallel Opportunities

- Phase 1: T003, T004, T005 병렬
- Phase 2: T006, T007, T008, T009 병렬 → T010 (ReferralService는 모델 의존)
- Phase 4: T016 완료 후 T017, T018, T019 병렬. T020, T021 병렬
- Phase 6: T032, T033, T034 병렬
- Phase 8: T039, T041 병렬
- US7은 클라이언트와 독립적으로 병렬 진행 가능

---

## Implementation Strategy

### MVP First (User Story 1~3)

1. Phase 1: Setup → Phase 2: Foundational
2. Phase 3: US1 (링크 공유) — 초대 프로그램의 진입점
3. Phase 4: US2 (혜택 적용) — 피초대자가 실제로 혜택을 받음
4. Phase 5: US3 (보상 수령) — 초대자가 보상을 받음
5. **STOP and VALIDATE**: 전체 초대 사이클(공유→설치→코드입력→리딤→보상수령) E2E 검증
6. MVP 배포 가능

### Incremental Delivery

1. MVP (US1~3) → 핵심 초대 사이클 완성
2. US4 (노출 포인트) → 사용자 발견성 향상
3. US5 (링크 재탭) → UX 마찰 감소
4. US6 (Push 알림) → 보상 수령 적시성 향상
5. US7 (코드 풀 관리) → 운영 자동화
6. Polish → 분석 이벤트, 통합 테스트

---

## Notes

- [P] 태스크 = 다른 파일, 의존성 없음 → 병렬 가능
- [Story] 라벨 = 해당 User Story 추적용
- 50줄 이상 수정 전 커밋 (CLAUDE.md 규칙)
- Offer Code 리딤은 Production 환경에서만 테스트 가능 (Apple 제한)
- Universal Link / Push 테스트는 실기기 필요
- referral-api는 단일 파일(index.ts)에 모든 엔드포인트 — 각 Story에서 점진적 추가
- 총 52개 태스크: Setup 5, Foundational 5, US1 5, US2 8, US3 7, US4 4, US5 3, US6 6, US7 2, Polish 6

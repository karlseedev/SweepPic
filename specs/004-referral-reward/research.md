# Research: 초대 리워드 프로그램

**Feature**: 004-referral-reward
**Date**: 2026-03-26
**Status**: Complete

## 1. Supabase Edge Functions — 랜딩 페이지 + API

### Decision
Supabase Edge Functions (Deno TypeScript)으로 랜딩 페이지와 REST API를 모두 구현한다.

### Rationale
- 프로젝트에 이미 Supabase 설정이 존재 (`SUPABASE_URL`, `SUPABASE_ANON_KEY` in xcconfig)
- AnalyticsService에서 Supabase로 이벤트 전송 중 — 인프라 추가 비용 없음
- Edge Functions는 Deno 런타임, TypeScript 지원, 글로벌 CDN
- 커스텀 도메인 연결 지원 (DNS CNAME → Supabase)

### Alternatives Considered
- **Cloudflare Workers**: 더 빠른 CDN이지만 Supabase DB 직접 접근 불가, 별도 인프라
- **Vercel Serverless**: React/Next.js 생태계 중심, 단순 리다이렉트에 과도
- **Firebase Functions**: Google 생태계 — 이미 Google Ads SDK 사용하지만 Supabase와 이중 관리

### Key Findings
- Edge Function에서 HTML을 직접 반환 가능 (`new Response(html, { headers: { "content-type": "text/html" } })`)
- Supabase 클라이언트를 Edge Function 내에서 직접 사용 (`createClient()`)
- 함수 간 공유 코드는 `_shared/` 디렉토리 사용
- Scheduled Functions: `supabase/config.toml`에 cron 설정 가능

---

## 2. APNs HTTP/2 직접 호출 (Supabase Edge Function)

### Decision
Supabase Edge Function에서 APNs HTTP/2 API를 직접 호출하여 Push 알림을 발송한다.

### Rationale
- 단일 알림 발송 (1:1) — 대량 발송 서비스 불필요
- Supabase에서 직접 호출하면 별도 Push 서비스 의존성 없음
- APNs HTTP/2는 표준 HTTPS 요청 — Edge Function에서 `fetch()` 호출 가능

### Key Implementation Details

**APNs JWT 생성**:
```
Header: { "alg": "ES256", "kid": "{KEY_ID}" }
Payload: { "iss": "{TEAM_ID}", "iat": {timestamp} }
Signature: ES256 with P8 key
```

**APNs 요청**:
```
POST https://api.push.apple.com/3/device/{device_token}
Headers:
  authorization: bearer {jwt}
  apns-topic: {bundle_id}
  apns-push-type: alert
Body:
  { "aps": { "alert": { "title": "...", "body": "..." }, "sound": "default" },
    "action_type": "referral_reward" }
```

**ASC API JWT (별도)**:
```
Header: { "alg": "ES256", "kid": "{KEY_ID}", "typ": "JWT" }
Payload: { "iss": "{ISSUER_ID}", "iat": {timestamp}, "exp": {+20min}, "aud": "appstoreconnect-v1" }
```

> 동일한 P8 키 파일 사용 가능하지만, JWT payload가 다름 (iss=team_id vs iss=issuer_id)

### Alternatives Considered
- **Firebase Cloud Messaging (FCM)**: 추가 SDK, Apple 종속성 회피 가능하지만 중간 레이어 추가
- **OneSignal**: 무료 티어 있으나 외부 서비스 의존성
- **Amazon SNS**: 기업급, 현 규모에 과도

---

## 3. Apple ASC API — Offer Code 생성 자동화

### Decision
초기에는 ASC 웹 UI에서 수동 코드 생성 → CSV → DB INSERT. 자동화는 Phase 2에서 Edge Function으로 구현.

### Rationale
- 초기 사용자 수가 적어 수동 관리로 충분 (수천 개)
- ASC API 자동화는 P8 키 + JWT 인증 + CSV 파싱 필요 — 복잡도 높음
- 수동 시작 → 사용량 증가 시 자동화 전환이 리스크 최소

### ASC API Endpoints (자동화 시)
```
POST /v1/subscriptionOfferCodeOneTimeUseCodes
  → 코드 생성 (최대 25,000개/배치)

GET /v1/subscriptionOfferCodeOneTimeUseCodes/{id}/values
  → CSV 다운로드 (코드 값 목록)
```

### Alternatives Considered
- **처음부터 완전 자동화**: 초기 개발 비용 높음, 사용량 불확실
- **수동만**: 규모 증가 시 운영 부담

---

## 4. Promotional Offer 서버 서명

### Decision
Supabase Edge Function에서 Promotional Offer 서명을 생성하여 클라이언트에 반환한다.

### Rationale
- Promotional Offer는 서버 서명 필수 (Apple 정책)
- P8 키를 클라이언트에 두면 보안 위험

### Signature Generation
```typescript
// Edge Function에서 서명 생성
const header = { alg: "ES256", kid: keyId, typ: "JWT" };
const payload = {
  appBundleId: bundleId,
  keyId: keyId,
  productId: productId,      // "plus_monthly" or "plus_yearly"
  offerIdentifier: offerId,  // "referral_extend_monthly" etc.
  applicationUsername: "",
  nonce: uuid,
  timestamp: Date.now()
};
// ES256 sign with P8 key → return { keyID, nonce, signature, timestamp }
```

### Client Usage (StoreKit 2)
```swift
let offer = Product.PurchaseOption.promotionalOffer(
    offerID: signatureData.offerID,
    keyID: signatureData.keyID,
    nonce: signatureData.nonce,
    signature: signatureData.signature,
    timestamp: signatureData.timestamp
)
let result = try await product.purchase(options: [offer])
```

---

## 5. 커스텀 도메인 + Universal Link 설정

### Decision
커스텀 도메인(sweeppic.link 등)을 구매하여 Supabase Edge Function에 연결하고, Universal Link를 설정한다.

### Rationale
- 브랜딩: `sweeppic.link/r/x0k7m2x99j` > `xxxx.supabase.co/functions/v1/referral-landing/...`
- Universal Link: 앱 설치 후 링크 재탭 시 앱이 바로 열림
- OG 태그: 카카오톡/인스타 미리보기 표시

### Universal Link Setup
1. `apple-app-site-association` 파일을 도메인 루트 `/.well-known/`에 배포
2. Xcode에서 Associated Domains 추가: `applinks:sweeppic.link`
3. SceneDelegate에서 `scene(_:continue:)` 구현

```json
{
  "applinks": {
    "apps": [],
    "details": [{
      "appIDs": ["TEAM_ID.com.karl.SweepPic"],
      "paths": ["/r/*"]
    }]
  }
}
```

### Custom URL Scheme (폴백)
- Info.plist에 `sweeppic://` 스킴 등록
- SceneDelegate에서 `scene(_:openURLContexts:)` 구현
- 경로: `sweeppic://referral/{code}`

---

## 6. 기존 코드 통합 포인트

### Decision
기존 Monetization 모듈의 3개 파일을 수정하여 초대 프로그램 노출 포인트를 추가한다.

### Findings

**TrashGatePopupViewController.swift**:
- 현재 구조: 블러 배경 + BlurPopupCardView + 광고/Plus/닫기 버튼
- 수정: 닫기 버튼 아래에 초대 프로모 섹션 추가
- 패턴: 기존 `setupUI()` 메서드에 `setupReferralPromo()` 추가

**CelebrationViewController.swift**:
- 현재 구조: 축하 카드 + "확인" 버튼
- 수정: 확인 버튼 아래에 "친구에게도 알려주세요" + 초대 버튼 추가
- 패턴: 기존 `setupCard()` 메서드에 추가

**PremiumMenuViewController.swift**:
- 현재 구조: 구독 관리, 구독 복원, 리딤 코드 메뉴
- 수정: "친구 초대" 메뉴 항목 추가 (UIMenu에 UIAction 추가)

**SubscriptionStore.swift**:
- 현재: `purchase(_:)`, `restorePurchases()`, `presentRedemptionSheet()`
- 추가: `purchaseWithPromotionalOffer(_:signature:)` 메서드

**AppDelegate.swift**:
- 현재: SDK 초기화 (Analytics, SubscriptionStore, AdManager)
- 추가: `UNUserNotificationCenter.delegate`, `registerForRemoteNotifications()`, `didRegisterForRemoteNotificationsWithDeviceToken`

**SceneDelegate.swift**:
- 현재: 권한 기반 루트 VC 설정, 라이프사이클 이벤트
- 추가: `scene(_:continue:)` (Universal Link), `scene(_:openURLContexts:)` (Custom URL Scheme), 포그라운드 시 `pending_rewards` 체크

---

## 7. API 보안 — rate limit만으로 충분한 이유

### Decision
HMAC 서명, App Attest 등 추가 인증 없이 rate limit(FR-037)만으로 API를 보호한다.

### Rationale
- 실제 금전적 피해가 발생하는 지점은 Apple Offer Code 리딤 시스템이며, 리딤에는 실제 Apple ID + 결제 수단이 필요
- 우리 API만 뚫어서는 가짜 초대 기록만 만들 수 있고, 리딤 없이는 보상도 트리거되지 않음
- user_id가 UUID(36^6 ≈ 22억 조합)로 추측 불가능 — rate limit(분당 10회) 적용 시 브루트포스에 420년 소요
- HMAC은 앱 바이너리 리버싱으로 시크릿 추출 가능하여 실질적 보안 효과 제한적
- App Attest도 동일 — 진짜 피해(Apple ID 대량 악용)는 Apple 측에서 차단해야 할 영역

### Alternatives Considered & Rejected
- **HMAC 서명**: 앱 리버싱으로 우회 가능, 비용 대비 효과 부족
- **App Attest**: 구현 복잡도 높고, 실질적 방어 대상(Apple ID 악용)에 무관
- 두 방식 모두 현재뿐 아니라 향후에도 불필요

---

## 8. 클라이언트 네트워킹 패턴

### Decision
기존 Supabase 설정(xcconfig)을 활용하여 URLSession 기반 API 호출을 구현한다.

### Rationale
- 앱에 이미 `SUPABASE_URL`, `SUPABASE_ANON_KEY` 설정됨
- AnalyticsService가 Supabase POST 호출 패턴을 이미 사용 중
- 별도 네트워킹 라이브러리 없이 URLSession + async/await 사용

### API Call Pattern
```swift
// ReferralService.swift
func createReferralLink(userId: String) async throws -> ReferralLink {
    let url = URL(string: "\(supabaseURL)/functions/v1/referral-api/create-link")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("Bearer \(supabaseAnonKey)", forHTTPHeaderField: "Authorization")
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.httpBody = try JSONEncoder().encode(["user_id": userId])

    let (data, _) = try await URLSession.shared.data(for: request)
    return try JSONDecoder().decode(ReferralLink.self, from: data)
}
```

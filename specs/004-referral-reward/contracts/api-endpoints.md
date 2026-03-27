# API Contracts: 초대 리워드 프로그램

**Feature**: 004-referral-reward
**Date**: 2026-03-26
**Base URL**: `{SUPABASE_URL}/functions/v1`

## Edge Functions Overview

| Function | Path | Method | Purpose |
|----------|------|--------|---------|
| `referral-landing` | `/referral-landing/r/{code}` | GET | 랜딩 페이지 (HTML + 리다이렉트) |
| `referral-api` | `/referral-api/*` | POST | REST API (아래 상세) |
| `offer-code-replenish` | — | Scheduled | 코드 풀 보충 (매일 새벽) |
| `push-notify` | — | Internal | APNs Push 발송 (referral-api에서 호출) |

---

## referral-landing (랜딩 페이지)

### GET `/referral-landing/r/{code}`

초대 링크 클릭 시 도착하는 랜딩 페이지.
커스텀 도메인(`sweeppic.link`)에서 `https://sweeppic.link/r/{code}` → Edge Function으로 라우팅.

**Response**: HTML 페이지 (OG 태그 + 자동 리다이렉트 JS)

**Logic**:
1. `referral_code`로 `referral_links` 조회
2. 유효 → 분석 이벤트(`referral.landing_visited`) 기록, 리다이렉트 실행
3. 무효 → App Store 앱 페이지로 직접 리다이렉트 (초대 보상 없이)

**HTML includes**:
- OG 메타태그 (SNS 미리보기용)
- 인앱 브라우저 감지 + 외부 전환 JS
- App Store 리다이렉트 로직

---

## referral-api (REST API)

모든 요청:
- `Authorization: Bearer {SUPABASE_ANON_KEY}`
- `Content-Type: application/json`
- 응답: `{ "success": true, "data": {...} }` 또는 `{ "success": false, "error": "..." }`

> HMAC 서명은 Out of Scope (v2). user_id가 UUID(추측 불가) + rate limit으로 충분.

**Rate Limiting (FR-037)**:

| 엔드포인트 | 제한 | 기준 |
|-----------|------|------|
| `create-link` | 분당 5회 | user_id |
| `match-code` | 분당 10회 | IP + user_id |
| `claim-reward` | 분당 5회 | user_id |
| `report-redemption` | 분당 10회 | user_id |
| `check-status` | 분당 20회 | user_id |
| `get-pending-rewards` | 분당 20회 | user_id |
| `update-device-token` | 분당 5회 | user_id |

초과 시 응답:
```json
HTTP 429
{
  "success": false,
  "error": "rate_limit_exceeded",
  "retry_after": 30
}
```

**HTTP 에러 처리 (FR-043)**:

| HTTP 상태 | 의미 | 클라이언트 처리 |
|-----------|------|---------------|
| 200 + success:true | 성공 | 정상 처리 |
| 200 + success:false | 비즈니스 에러 | 에러 메시지 표시 (invalid_code, self_referral 등) |
| 429 | Rate limit 초과 | "잠시 후 다시 시도해주세요" + retry_after 후 자동 재시도 |
| 500/502/503 | 서버 에러 | "서버에 연결할 수 없습니다. 잠시 후 다시 시도해주세요" + [다시 시도] |
| 네트워크 타임아웃 (30초) | 연결 불가 | 동일 에러 안내 |

---

### POST `/referral-api/create-link`

초대 코드 생성 또는 기존 코드 조회.

**Request**:
```json
{
  "user_id": "keychain-uuid-string"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "referral_code": "x0k7m2x99j",
    "share_url": "https://sweeppic.link/r/x0k7m2x99j"
  }
}
```

**Logic**:
1. `referral_links`에서 `user_id`로 조회
2. 존재 → 기존 코드 반환
3. 미존재 → 새 코드 생성 (`x0{6chars}9j` 형식, 내부 충돌 필터링) → INSERT → 반환

---

### POST `/referral-api/match-code`

피초대자가 초대 코드를 입력하여 매칭 + Offer Code 할당.

**Request**:
```json
{
  "user_id": "referred-user-keychain-uuid",
  "referral_code": "x0k7m2x99j",
  "subscription_status": "none"
}
```

`subscription_status` 값:
- `"none"` — 비구독자 (Free Trial 포함)
- `"monthly"` — plus_monthly 구독 중
- `"yearly"` — plus_yearly 구독 중
- `"expired_monthly"` — monthly 구독 만료
- `"expired_yearly"` — yearly 구독 만료

**Response (200) — 성공**:
```json
{
  "success": true,
  "data": {
    "referral_id": "uuid",
    "redeem_url": "https://apps.apple.com/redeem?ctx=offercodes&id=APP_ID&code=XXXX-XXXX",
    "offer_name": "referral_invited_monthly",
    "status": "matched"
  }
}
```

**Response (200) — 이미 리딤됨**:
```json
{
  "success": true,
  "data": {
    "status": "already_redeemed",
    "message": "이미 초대 코드가 적용되어 있습니다."
  }
}
```

**Response (200) — 자기 초대**:
```json
{
  "success": true,
  "data": {
    "status": "self_referral",
    "message": "본인의 초대 코드는 사용할 수 없습니다."
  }
}
```

**Response (200) — 무효 코드**:
```json
{
  "success": true,
  "data": {
    "status": "invalid_code",
    "message": "유효하지 않은 초대 코드입니다."
  }
}
```

**Response (200) — 코드 풀 소진**:
```json
{
  "success": true,
  "data": {
    "status": "no_codes_available",
    "message": "일시적으로 혜택을 적용할 수 없습니다."
  }
}
```

**Logic**:
1. `referral_code`로 `referral_links` 조회 → 무효면 `invalid_code`
2. 초대자 `user_id` == 피초대자 `user_id` → `self_referral`
3. `referrals`에서 `referred_user_id` 조회 → 이미 있으면 `already_redeemed`
4. `subscription_status` 기반 Offer 결정:
   - none/monthly/expired_monthly → `referral_invited_monthly`
   - yearly/expired_yearly → `referral_invited_yearly`
5. `offer_codes`에서 해당 `offer_name`의 available 코드 할당 (SELECT FOR UPDATE)
6. 코드 없으면 `no_codes_available`
7. `referrals` INSERT (status: matched, offer_code, offer_name)
8. 리딤 URL 생성하여 반환

---

### POST `/referral-api/report-redemption`

피초대자가 Offer Code 리딤 완료를 보고.

**Request**:
```json
{
  "user_id": "referred-user-keychain-uuid",
  "referral_id": "uuid"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "status": "redeemed"
  }
}
```

**Logic**:
1. `referrals` 상태 → `redeemed`, `redeemed_at` = now()
2. `offer_codes` 상태 → `used`, `used_at` = now()
3. `pending_rewards` INSERT (초대자 보상 대기, reward_type = NULL)
4. Push 알림 발송 (초대자의 device_token 조회)

---

### POST `/referral-api/check-status`

피초대자가 자신의 초대 코드 적용 상태를 확인.

**Request**:
```json
{
  "user_id": "referred-user-keychain-uuid"
}
```

**Response (200) — 레코드 없음**:
```json
{
  "success": true,
  "data": {
    "status": "none"
  }
}
```

**Response (200) — 매칭됨 (리딤 미완료)**:
```json
{
  "success": true,
  "data": {
    "status": "matched",
    "redeem_url": "https://apps.apple.com/redeem?...",
    "message": "혜택이 아직 적용되지 않았어요."
  }
}
```

**Response (200) — 리딤 완료**:
```json
{
  "success": true,
  "data": {
    "status": "redeemed",
    "message": "이미 초대 코드가 적용되어 있습니다."
  }
}
```

---

### POST `/referral-api/get-pending-rewards`

초대자의 대기 중인 보상 목록 조회.

**Request**:
```json
{
  "user_id": "referrer-keychain-uuid"
}
```

**Response (200)**:
```json
{
  "success": true,
  "data": {
    "rewards": [
      {
        "id": "uuid",
        "referral_id": "uuid",
        "status": "pending",
        "created_at": "2026-03-26T12:00:00Z",
        "expires_at": "2026-04-25T12:00:00Z"
      }
    ]
  }
}
```

---

### POST `/referral-api/claim-reward`

초대자가 보상을 수령.

**Request**:
```json
{
  "user_id": "referrer-keychain-uuid",
  "reward_id": "uuid",
  "subscription_status": "monthly",
  "product_id": "plus_monthly"
}
```

**Response (200) — Promotional Offer (구독자/만료)**:
```json
{
  "success": true,
  "data": {
    "reward_type": "promotional",
    "signature": {
      "offer_id": "referral_extend_monthly",
      "key_id": "ABC123",
      "nonce": "uuid",
      "signature": "base64-encoded-signature",
      "timestamp": 1711440000
    }
  }
}
```

**Response (200) — Offer Code (한 번도 구독 안 한 비구독자)**:
```json
{
  "success": true,
  "data": {
    "reward_type": "offer_code",
    "redeem_url": "https://apps.apple.com/redeem?ctx=offercodes&id=APP_ID&code=XXXX-XXXX"
  }
}
```

**Logic**:
1. `pending_rewards`에서 reward_id 조회, status == pending 확인
2. `subscription_status` 기반 보상 방식 결정:
   - monthly/expired_monthly → Promotional Offer `referral_extend_monthly`
   - yearly/expired_yearly → Promotional Offer `referral_extend_yearly`
   - none (한 번도 구독 안 함) → Offer Code `referral_reward_01`
3. Promotional: P8 키로 서명 생성 → 반환
4. Offer Code: `offer_codes`에서 할당 → 리딤 URL 반환
5. `pending_rewards` 상태 → completed, `reward_type` 설정, `completed_at` = now()
6. `referrals` 상태 → rewarded, `rewarded_at` = now()

---

### POST `/referral-api/update-device-token`

Push 토큰 갱신.

**Request**:
```json
{
  "user_id": "keychain-uuid",
  "device_token": "hex-encoded-apns-token"
}
```

**Response (200)**:
```json
{
  "success": true
}
```

---

## offer-code-replenish (Scheduled Function)

**Schedule**: 매일 새벽 3시 (cron: `0 3 * * *`)

**Logic**:
1. `offer_name`별로 `status = 'available' AND expires_at > now()` 카운트
2. 5,000개 미만인 Offer에 대해:
   - ASC API 호출 → 코드 생성 (최대 25,000개)
   - CSV 다운로드 → `offer_codes` INSERT
3. 만료된 코드 정리: `expires_at < now()` → `status = 'expired'`
4. 실패 시 재시도: 1시간 → 3시간 → 6시간

---

## push-notify (Internal Function)

`referral-api/report-redemption`에서 내부 호출.

**Logic**:
1. 초대자의 `device_token` 조회 (`referral_links`)
2. NULL이면 스킵
3. APNs JWT 생성 (P8 키, team_id)
4. APNs HTTP/2 POST 호출
5. Payload:
```json
{
  "aps": {
    "alert": {
      "title": "초대 보상 도착!",
      "body": "초대한 사람이 SweepPic에 가입했어요! 14일 무료 혜택을 받으세요"
    },
    "sound": "default",
    "badge": 1
  },
  "action_type": "referral_reward",
  "reward_id": "uuid"
}
```

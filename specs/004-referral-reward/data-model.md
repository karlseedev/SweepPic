# Data Model: 초대 리워드 프로그램

**Feature**: 004-referral-reward
**Date**: 2026-03-26

## Entity Relationship

```
┌─────────────────┐     1:N     ┌──────────────┐     1:1     ┌─────────────────┐
│  referral_links │────────────▶│   referrals   │────────────▶│ pending_rewards  │
│  (초대자 정보)   │             │  (초대 기록)   │             │  (보상 대기)      │
└─────────────────┘             └──────────────┘             └─────────────────┘
                                      │ N:1
                                      ▼
                                ┌──────────────┐
                                │  offer_codes  │
                                │  (코드 풀)    │
                                └──────────────┘
```

## Entities

### 1. ReferralLink (초대 링크)

초대자당 하나의 고유 초대 코드를 관리한다.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, auto-gen | 내부 식별자 |
| `user_id` | TEXT | UNIQUE, NOT NULL | Keychain 기반 영구 사용자 ID |
| `referral_code` | TEXT | UNIQUE, NOT NULL | 초대 코드 (형식: `x0{6자리}9j`) |
| `device_token` | TEXT | nullable | APNs Push 토큰 (NULL이면 Push 미허용) |
| `created_at` | TIMESTAMPTZ | default: now() | 생성 시각 |

**Uniqueness Rules**:
- `user_id` UNIQUE — 사용자당 하나의 초대 링크
- `referral_code` UNIQUE — 코드 중복 불가
- 코드 생성 시 내부 6자리가 "x0"으로 시작하거나 "9j"로 끝나지 않도록 필터링

**State**: Stateless (생성 후 변경 없음, device_token만 갱신)

---

### 2. Referral (초대 기록)

초대자과 피초대자 간의 관계 및 진행 상태를 추적한다.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, auto-gen | 내부 식별자 |
| `referrer_user_id` | TEXT | NOT NULL, FK→referral_links.user_id | 초대자 |
| `referred_user_id` | TEXT | nullable → NOT NULL (매칭 시) | 피초대자 |
| `offer_code` | TEXT | nullable | 피초대자에게 할당된 Offer Code |
| `offer_name` | TEXT | nullable | 할당된 Offer 이름 (referral_invited_monthly 등) |
| `status` | TEXT | NOT NULL, default: 'matched' | 상태 |
| `matched_at` | TIMESTAMPTZ | default: now() | 코드 입력 시점 |
| `redeemed_at` | TIMESTAMPTZ | nullable | 리딤 완료 시점 |
| `rewarded_at` | TIMESTAMPTZ | nullable | 초대자 보상 수령 시점 |

**State Transitions**:
```
matched ──────────▶ redeemed ──────────▶ rewarded
(코드 입력/매칭)     (Offer Code 리딤)     (초대자 보상 수령)
```

**Validation Rules**:
- `referrer_user_id` != `referred_user_id` (자기 초대 방지)
- `referred_user_id`당 하나의 referral만 존재 (UNIQUE)

---

### 3. PendingReward (보상 대기)

초대자가 수령해야 할 보상을 관리한다. 보상 유형과 코드는 수령 시점에 결정된다.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, auto-gen | 내부 식별자 |
| `user_id` | TEXT | NOT NULL | 보상 받을 초대자 |
| `referral_id` | UUID | FK→referrals.id | 연결된 초대 기록 |
| `reward_type` | TEXT | nullable | 수령 시 결정: 'promotional' \| 'offer_code' |
| `offer_code` | TEXT | nullable | offer_code 타입만: 할당된 코드 |
| `redeem_url` | TEXT | nullable | offer_code 타입만: 리딤 URL |
| `status` | TEXT | NOT NULL, default: 'pending' | 상태 |
| `created_at` | TIMESTAMPTZ | default: now() | 생성 시각 |
| `completed_at` | TIMESTAMPTZ | nullable | 수령 완료 시각 |
| `expires_at` | TIMESTAMPTZ | default: now() + 30 days | 만료 시각 |

**State Transitions**:
```
pending ──────────▶ completed
  │                  (보상 수령 완료)
  │
  └──────────────▶ expired
                   (30일 경과)
```

**Design Decisions**:
- `reward_type`은 생성 시 NULL → 수령 시점에 구독 상태 기반 결정
- `offer_code`, `redeem_url`은 offer_code 타입일 때만 사용
- 만료된 보상은 복구 불가 (재생성 없음)

---

### 4. OfferCode (코드 풀)

Apple이 생성한 일회용 Offer Code를 관리한다.

| Field | Type | Constraints | Description |
|-------|------|-------------|-------------|
| `id` | UUID | PK, auto-gen | 내부 식별자 |
| `code` | TEXT | UNIQUE, NOT NULL | Apple 생성 코드 값 |
| `offer_name` | TEXT | NOT NULL | ASC Offer Name |
| `status` | TEXT | NOT NULL, default: 'available' | 상태 |
| `assigned_to` | TEXT | nullable | 할당된 사용자 ID |
| `assigned_at` | TIMESTAMPTZ | nullable | 할당 시각 |
| `used_at` | TIMESTAMPTZ | nullable | 사용 시각 |
| `created_at` | TIMESTAMPTZ | default: now() | DB 등록 시각 |
| `expires_at` | TIMESTAMPTZ | nullable | Apple 코드 만료일 (최대 6개월) |

**State Transitions**:
```
available ──────▶ assigned ──────▶ used
  │               (사용자에게 할당)  (리딤 완료)
  │
  └──────────────▶ expired
                   (Apple 만료일 경과)
```

**Offer Names**:

| offer_name | 용도 | 대상 |
|------------|------|------|
| `referral_invited_monthly` | 피초대자 (비구독/무료/monthly) | pro_monthly |
| `referral_invited_yearly` | 피초대자 (yearly 구독자) | pro_yearly |
| `referral_reward_01` | 초대자 (한 번도 구독 안 한 비구독자) | pro_monthly |

**Allocation Rules**:
- `SELECT FOR UPDATE` — 원자적 할당 (동시 요청 시 중복 방지)
- `status = 'available' AND expires_at > now() AND offer_name = {target}`
- 할당 시: `status = 'assigned'`, `assigned_to = user_id`, `assigned_at = now()`

---

## Client-Side Models (Swift)

### ReferralModels.swift (AppCore)

```swift
// 서버 응답 모델
public struct ReferralLink: Codable, Sendable {
    public let referralCode: String
    public let shareURL: URL
}

public struct ReferralMatchResult: Codable, Sendable {
    public let referralId: String
    public let redeemURL: URL?          // Offer Code 리딤 URL
    public let offerName: String?
    public let status: ReferralStatus
}

public enum ReferralStatus: String, Codable, Sendable {
    case matched
    case redeemed
    case rewarded
    case selfReferral = "self_referral"
    case alreadyRedeemed = "already_redeemed"
    case invalidCode = "invalid_code"
}

// 보상 모델
public struct PendingRewardResponse: Codable, Sendable {
    public let id: String
    public let referralId: String
    public let rewardType: RewardType?
    public let redeemURL: URL?
    public let status: RewardStatus
}

public enum RewardType: String, Codable, Sendable {
    case promotional
    case offerCode = "offer_code"
}

public enum RewardStatus: String, Codable, Sendable {
    case pending
    case completed
    case expired
}

// Promotional Offer 서명 응답
public struct PromotionalOfferSignature: Codable, Sendable {
    public let offerID: String
    public let keyID: String
    public let nonce: UUID
    public let signature: String  // Base64 encoded
    public let timestamp: Int
}
```

### ReferralStore.swift (AppCore)

```swift
// Keychain 기반 영구 User ID
public final class ReferralStore {
    public static let shared = ReferralStore()

    private let keychainKey = "sweeppic_referral_id"

    // 앱 삭제 후 재설치에도 유지
    public var userId: String {
        if let existing = KeychainHelper.loadString(key: keychainKey) {
            return existing
        }
        let newId = UUID().uuidString
        KeychainHelper.saveString(newId, key: keychainKey)
        return newId
    }

    // Push 프리프롬프트 상태
    public var hasAskedPushPermission: Bool {
        get { UserDefaults.standard.bool(forKey: "referral_push_asked") }
        set { UserDefaults.standard.set(newValue, forKey: "referral_push_asked") }
    }
}
```

---

## Indexes

```sql
-- 초대 코드 빠른 조회
CREATE INDEX idx_referral_links_code ON referral_links(referral_code);

-- 피초대자 중복 체크
CREATE UNIQUE INDEX idx_referrals_referred_user ON referrals(referred_user_id)
  WHERE referred_user_id IS NOT NULL;

-- 초대자별 보상 조회
CREATE INDEX idx_pending_rewards_user ON pending_rewards(user_id, status);

-- 코드 할당 (빈 코드 빠른 검색)
CREATE INDEX idx_offer_codes_available ON offer_codes(offer_name, status, expires_at)
  WHERE status = 'available';
```

## Foreign Key 제약 설계

```sql
-- FK 제약은 의도적으로 DB 수준에서 설정하지 않음.
-- 이유:
-- 1. 모든 데이터 접근은 Edge Function(service_role)을 경유 → 비즈니스 로직에서 참조 무결성 검증
-- 2. FK 제약은 INSERT/UPDATE 시 참조 테이블 락을 유발 → 동시성 성능 저하
-- 3. Edge Function에서 referral_links.user_id 존재 확인 후 referrals INSERT
-- 4. 참조 무결성 위반은 Edge Function 레벨에서 에러 반환 → 클라이언트에 에러 안내

-- 대신 애플리케이션 수준 검증:
-- referrals.referrer_user_id → referral_links.user_id 존재 확인 (match-code에서)
-- pending_rewards.referral_id → referrals.id 존재 확인 (report-redemption에서)
-- referrals.offer_code → offer_codes.code 존재 확인 (match-code에서)
```

## Row-Level Security (Supabase)

```sql
-- Edge Function에서 service_role 키로 접근 → RLS 바이패스
-- 클라이언트에서 직접 DB 접근 없음 (모든 접근은 Edge Function API 경유)
-- 따라서 RLS는 최소한의 방어 수단으로 설정

ALTER TABLE referral_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_codes ENABLE ROW LEVEL SECURITY;

-- 모든 테이블: service_role만 접근 가능 (anon/authenticated 직접 접근 차단)
-- Edge Function은 service_role 키를 사용하므로 RLS 바이패스
```

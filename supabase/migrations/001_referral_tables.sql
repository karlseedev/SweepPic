-- =============================================================================
-- 초대 리워드 프로그램 DB 스키마
-- Feature: 004-referral-reward
-- 테이블: referral_links, referrals, pending_rewards, offer_codes
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. referral_links (초대자 정보)
-- 초대자당 하나의 고유 초대 코드를 관리한다.
-- user_id: Keychain 기반 영구 사용자 ID (앱 삭제/재설치에도 유지)
-- referral_code: 형식 x0{6chars}9j — 앞뒤 접두/접미 고정
-- device_token: APNs Push 토큰 (NULL이면 Push 미허용)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS referral_links (
    id             UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id        TEXT NOT NULL UNIQUE,
    referral_code  TEXT NOT NULL UNIQUE,
    device_token   TEXT,
    created_at     TIMESTAMPTZ DEFAULT now() NOT NULL
);

-- 초대 코드로 빠른 조회 (랜딩 페이지, match-code에서 사용)
CREATE INDEX idx_referral_links_code ON referral_links(referral_code);

-- -----------------------------------------------------------------------------
-- 2. referrals (초대 기록)
-- 초대자와 피초대자 간의 관계 및 진행 상태를 추적한다.
-- 상태 전이: matched → redeemed → rewarded
-- referred_user_id UNIQUE: 피초대자는 한 번만 초대 코드를 사용할 수 있음
-- FK 제약 없음: Edge Function(service_role)에서 비즈니스 로직으로 참조 무결성 검증
-- (FK가 INSERT/UPDATE 시 참조 테이블 락을 유발 → 동시성 성능 저하 방지)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS referrals (
    id                UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    referrer_user_id  TEXT NOT NULL,
    referred_user_id  TEXT,
    offer_code        TEXT,
    offer_name        TEXT,
    status            TEXT NOT NULL DEFAULT 'matched',
    matched_at        TIMESTAMPTZ DEFAULT now(),
    redeemed_at       TIMESTAMPTZ,
    rewarded_at       TIMESTAMPTZ,

    -- 자기 초대 방지: Edge Function에서도 검증하지만 DB 레벨 안전장치
    CONSTRAINT chk_no_self_referral CHECK (referrer_user_id != referred_user_id)
);

-- 피초대자 중복 체크: 한 사용자는 한 번만 초대 코드 사용 가능
-- partial index: referred_user_id가 NULL이 아닌 경우에만 적용
CREATE UNIQUE INDEX idx_referrals_referred_user ON referrals(referred_user_id)
    WHERE referred_user_id IS NOT NULL;

-- 초대자별 referral 목록 조회 (get-pending-rewards에서 JOIN 시 사용)
CREATE INDEX idx_referrals_referrer ON referrals(referrer_user_id);

-- -----------------------------------------------------------------------------
-- 3. pending_rewards (보상 대기)
-- 초대자가 수령해야 할 보상을 관리한다.
-- reward_type: 생성 시 NULL → 수령 시점에 구독 상태 기반 결정
--   - 'promotional': Promotional Offer (기존/만료 구독자)
--   - 'offer_code': Offer Code (한 번도 구독 안 한 비구독자)
-- 상태 전이: pending → completed | expired
-- expires_at: 생성 후 30일 경과 시 만료 (복구 불가)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS pending_rewards (
    id            UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    user_id       TEXT NOT NULL,
    referral_id   UUID NOT NULL,
    reward_type   TEXT,
    offer_code    TEXT,
    redeem_url    TEXT,
    status        TEXT NOT NULL DEFAULT 'pending',
    created_at    TIMESTAMPTZ DEFAULT now() NOT NULL,
    completed_at  TIMESTAMPTZ,
    expires_at    TIMESTAMPTZ DEFAULT (now() + INTERVAL '30 days') NOT NULL
);

-- 초대자별 보상 조회 (get-pending-rewards 엔드포인트에서 사용)
CREATE INDEX idx_pending_rewards_user ON pending_rewards(user_id, status);

-- -----------------------------------------------------------------------------
-- 4. offer_codes (Offer Code 풀)
-- Apple이 생성한 일회용 Offer Code를 관리한다.
-- 상태 전이: available → assigned → used | expired
-- 할당 시 SELECT FOR UPDATE로 원자적 처리 (동시 요청 시 중복 방지)
-- offer_name 종류:
--   - referral_invited_monthly: 피초대자용 (비구독/무료/monthly → plus_monthly)
--   - referral_invited_yearly: 피초대자용 (yearly 구독자 → plus_yearly)
--   - referral_reward_01: 초대자 보상용 (비구독자 → plus_monthly)
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS offer_codes (
    id           UUID DEFAULT gen_random_uuid() PRIMARY KEY,
    code         TEXT NOT NULL UNIQUE,
    offer_name   TEXT NOT NULL,
    status       TEXT NOT NULL DEFAULT 'available',
    assigned_to  TEXT,
    assigned_at  TIMESTAMPTZ,
    used_at      TIMESTAMPTZ,
    created_at   TIMESTAMPTZ DEFAULT now() NOT NULL,
    expires_at   TIMESTAMPTZ
);

-- 빈 코드 빠른 검색 (match-code, claim-reward에서 사용)
-- partial index: available 상태만 인덱싱하여 쓸모없는 행 제외
CREATE INDEX idx_offer_codes_available ON offer_codes(offer_name, status, expires_at)
    WHERE status = 'available';

-- =============================================================================
-- Row-Level Security (RLS)
-- 모든 테이블: service_role만 접근 가능 (anon/authenticated 직접 접근 차단)
-- Edge Function은 service_role 키를 사용하므로 RLS 바이패스
-- =============================================================================
ALTER TABLE referral_links ENABLE ROW LEVEL SECURITY;
ALTER TABLE referrals ENABLE ROW LEVEL SECURITY;
ALTER TABLE pending_rewards ENABLE ROW LEVEL SECURITY;
ALTER TABLE offer_codes ENABLE ROW LEVEL SECURITY;

-- anon/authenticated 역할에 대해 빈 정책 → 모든 접근 차단
-- (정책이 없으면 RLS 활성화 시 자동으로 모든 접근 거부됨)

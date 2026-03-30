/**
 * referral-api — 초대 리워드 프로그램 REST API Edge Function
 *
 * 엔드포인트:
 * - POST /create-link   : 초대 코드 생성 또는 기존 코드 조회 (Phase 3, T011)
 * - POST /match-code     : 피초대자 코드 매칭 + Offer Code 할당 (Phase 4)
 * - POST /check-status   : 피초대자 상태 확인 (Phase 4)
 * - POST /report-redemption : 리딤 완료 보고 (Phase 4)
 * - POST /get-pending-rewards : 초대자 보상 조회 (Phase 5)
 * - POST /claim-reward   : 초대자 보상 수령 (Phase 5)
 * - POST /update-device-token : Push 토큰 갱신 (Phase 8)
 *
 * 공통 사항:
 * - Authorization: Bearer {SUPABASE_ANON_KEY}
 * - Content-Type: application/json
 * - 응답 형식: { "success": true, "data": {...} } 또는 { "success": false, "error": "..." }
 * - Rate Limiting: _shared/rate-limiter.ts (FR-037)
 *
 * 참조: specs/004-referral-reward/contracts/api-endpoints.md
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import {
  checkRateLimit,
  RATE_LIMITS,
  getClientIP,
  rateLimitResponse,
} from "../_shared/rate-limiter.ts";

// Supabase 클라이언트 (service_role — RLS 바이패스)
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// 커스텀 도메인 (없으면 Edge Function URL로 폴백, FR-047)
const customDomain = Deno.env.get("CUSTOM_DOMAIN");

// MARK: - CORS 헤더

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

// MARK: - 유틸리티

/**
 * 성공 응답 생성
 * @param data - 응답 데이터 객체
 * @returns JSON Response (HTTP 200)
 */
function successResponse(data: Record<string, unknown>): Response {
  return new Response(
    JSON.stringify({ success: true, data }),
    {
      status: 200,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
}

/**
 * 에러 응답 생성
 * @param error - 에러 메시지
 * @param status - HTTP 상태 코드 (기본 200 — 비즈니스 에러)
 * @returns JSON Response
 */
function errorResponse(error: string, status = 200): Response {
  return new Response(
    JSON.stringify({ success: false, error }),
    {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    }
  );
}

/**
 * 초대 코드 생성 — x0{6자리 영숫자}9j 형식
 * 내부 6자리가 "x0"으로 시작하거나 "9j"로 끝나지 않도록 필터링
 * @returns 생성된 초대 코드 문자열
 */
function generateReferralCode(): string {
  const chars =
    "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let inner: string;
  do {
    inner = "";
    for (let i = 0; i < 6; i++) {
      inner += chars[Math.floor(Math.random() * chars.length)];
    }
    // 내부 코드가 접두사/접미사 패턴과 충돌하지 않도록 필터링
  } while (inner.startsWith("x0") || inner.endsWith("9j"));
  return `x0${inner}9j`;
}

/**
 * 공유 URL 생성
 * 커스텀 도메인이 설정되어 있으면 사용, 없으면 Edge Function URL로 폴백
 * @param code - 초대 코드
 * @returns 공유용 전체 URL
 */
function buildShareURL(code: string): string {
  if (customDomain) {
    return `https://${customDomain}/r/${code}`;
  }
  // 폴백: Supabase Edge Function 직접 URL
  return `${supabaseUrl}/functions/v1/referral-landing/r/${code}`;
}

// MARK: - create-link 엔드포인트

/**
 * POST /create-link — 초대 코드 생성 또는 기존 코드 조회
 *
 * 로직:
 * 1. referral_links에서 user_id로 조회
 * 2. 존재 → 기존 코드 반환
 * 3. 미존재 → 새 코드 생성 (충돌 시 최대 5회 재생성) → INSERT → 반환
 *
 * @param userId - Keychain UUID
 * @returns { referral_code, share_url }
 */
async function handleCreateLink(userId: string): Promise<Response> {
  // 1. 기존 초대 링크 조회
  const { data: existing, error: selectError } = await supabase
    .from("referral_links")
    .select("referral_code")
    .eq("user_id", userId)
    .maybeSingle();

  if (selectError) {
    console.error("create-link: DB 조회 실패 —", selectError.message);
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  // 2. 기존 코드가 있으면 반환
  if (existing) {
    return successResponse({
      referral_code: existing.referral_code,
      share_url: buildShareURL(existing.referral_code),
    });
  }

  // 3. 새 코드 생성 — 충돌 시 최대 5회 재시도
  const MAX_RETRIES = 5;
  for (let attempt = 0; attempt < MAX_RETRIES; attempt++) {
    const code = generateReferralCode();

    // INSERT 시도 (referral_code UNIQUE 제약으로 충돌 감지)
    const { error: insertError } = await supabase
      .from("referral_links")
      .insert({
        user_id: userId,
        referral_code: code,
      });

    if (!insertError) {
      // 성공: 생성된 코드 반환
      console.log(`create-link: 새 코드 생성 — ${code} (시도 ${attempt + 1})`);
      return successResponse({
        referral_code: code,
        share_url: buildShareURL(code),
      });
    }

    // UNIQUE 제약 위반 (코드 충돌) → 재시도
    if (insertError.code === "23505") {
      console.warn(
        `create-link: 코드 충돌 — ${code} (시도 ${attempt + 1}/${MAX_RETRIES})`
      );
      continue;
    }

    // 기타 에러
    console.error("create-link: INSERT 실패 —", insertError.message);
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  // 5회 모두 충돌 (극히 드문 경우)
  console.error("create-link: 코드 생성 실패 — 5회 충돌");
  return errorResponse("코드 생성에 실패했습니다. 잠시 후 다시 시도해주세요.");
}

// MARK: - Offer Code 할당 유틸리티

/**
 * Offer Code를 원자적으로 할당한다 (Optimistic Locking 패턴)
 *
 * 동시 요청 시 중복 할당을 방지하기 위해:
 * 1. available 상태의 코드 1개를 SELECT
 * 2. 해당 코드를 assigned로 UPDATE (status='available' 조건 포함)
 * 3. 다른 요청이 먼저 가져간 경우 → 재시도 (최대 3회)
 *
 * @param offerName - 할당할 Offer 이름 (referral_invited_monthly 등)
 * @param userId - 할당 대상 사용자 ID
 * @returns 할당된 Offer Code 문자열 또는 null (풀 소진)
 */
async function allocateOfferCode(
  offerName: string,
  userId: string
): Promise<string | null> {
  const MAX_ATTEMPTS = 3;

  for (let attempt = 0; attempt < MAX_ATTEMPTS; attempt++) {
    // 1. 사용 가능한 코드 1개 조회
    const { data: codes, error: selectErr } = await supabase
      .from("offer_codes")
      .select("id, code")
      .eq("offer_name", offerName)
      .eq("status", "available")
      .gt("expires_at", new Date().toISOString())
      .limit(1);

    if (selectErr) {
      console.error("allocateOfferCode: SELECT 실패 —", selectErr.message);
      return null;
    }

    if (!codes || codes.length === 0) {
      console.warn(
        `allocateOfferCode: ${offerName} 코드 풀 소진`
      );
      return null;
    }

    // 2. 원자적 할당 시도 — status='available' 조건으로 optimistic locking
    const { data: updated, error: updateErr } = await supabase
      .from("offer_codes")
      .update({
        status: "assigned",
        assigned_to: userId,
        assigned_at: new Date().toISOString(),
      })
      .eq("id", codes[0].id)
      .eq("status", "available")
      .select("code")
      .maybeSingle();

    if (updateErr) {
      console.error("allocateOfferCode: UPDATE 실패 —", updateErr.message);
      return null;
    }

    // 3. 할당 성공
    if (updated) {
      console.log(
        `allocateOfferCode: ${offerName} → ${updated.code} (시도 ${attempt + 1})`
      );
      return updated.code;
    }

    // 다른 요청이 먼저 가져감 → 재시도
    console.warn(
      `allocateOfferCode: 경쟁 실패 (시도 ${attempt + 1}/${MAX_ATTEMPTS})`
    );
  }

  return null;
}

/**
 * Offer Code 리딤 URL 생성
 * App Store URL Redemption 형식: https://apps.apple.com/redeem?ctx=offercodes&id={APP_ID}&code={CODE}
 *
 * @param code - Apple Offer Code 값
 * @returns 리딤 URL 문자열
 */
function buildRedeemURL(code: string): string {
  const appId = Deno.env.get("APP_STORE_APP_ID") || "";
  return `https://apps.apple.com/redeem?ctx=offercodes&id=${appId}&code=${code}`;
}

/**
 * subscription_status에 따라 피초대자용 Offer 이름을 결정한다.
 * - none/monthly/expired_monthly → referral_invited_monthly (pro_monthly 기반)
 * - yearly/expired_yearly → referral_invited_yearly (pro_yearly 기반)
 *
 * @param subscriptionStatus - 클라이언트에서 전달한 구독 상태 문자열
 * @returns Offer 이름 문자열
 */
function determineInvitedOfferName(subscriptionStatus: string): string {
  if (
    subscriptionStatus === "yearly" ||
    subscriptionStatus === "expired_yearly"
  ) {
    return "referral_invited_yearly";
  }
  // none, monthly, expired_monthly → monthly 기반
  return "referral_invited_monthly";
}

// MARK: - match-code 엔드포인트

/**
 * POST /match-code — 피초대자 코드 매칭 + Offer Code 할당
 *
 * 로직:
 * 1. referral_code로 referral_links 조회 → 무효면 invalid_code
 * 2. 초대자 user_id == 피초대자 user_id → self_referral
 * 3. referrals에서 referred_user_id 조회 → 이미 있으면 already_redeemed
 * 4. subscription_status 기반 Offer 결정
 * 5. offer_codes에서 코드 할당 (optimistic locking)
 * 6. referrals INSERT → 리딤 URL 반환
 *
 * @param body - { user_id, referral_code, subscription_status }
 * @returns 5가지 status 중 하나
 */
async function handleMatchCode(body: Record<string, unknown>): Promise<Response> {
  const userId = body.user_id as string;
  const referralCode = body.referral_code as string;
  const subscriptionStatus = (body.subscription_status as string) || "none";

  // 필수 파라미터 확인
  if (!referralCode) {
    return errorResponse("referral_code가 필요합니다.", 400);
  }

  // 1. 초대 코드로 초대자 조회
  const { data: link, error: linkError } = await supabase
    .from("referral_links")
    .select("user_id")
    .eq("referral_code", referralCode)
    .maybeSingle();

  if (linkError) {
    console.error("match-code: referral_links 조회 실패 —", linkError.message);
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  // 무효한 초대 코드
  if (!link) {
    return successResponse({
      status: "invalid_code",
      message: "유효하지 않은 초대 코드입니다.",
    });
  }

  // 2. 자기 초대 감지
  if (link.user_id === userId) {
    return successResponse({
      status: "self_referral",
      message: "본인의 초대 코드는 사용할 수 없습니다.",
    });
  }

  // 3. 이미 다른 초대 코드를 사용한 사용자인지 확인
  const { data: existing, error: existError } = await supabase
    .from("referrals")
    .select("id, status")
    .eq("referred_user_id", userId)
    .maybeSingle();

  if (existError) {
    console.error("match-code: referrals 조회 실패 —", existError.message);
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  if (existing) {
    return successResponse({
      status: "already_redeemed",
      message: "이미 초대 코드가 적용되어 있습니다.",
    });
  }

  // 4. 구독 상태에 따라 Offer 결정
  const offerName = determineInvitedOfferName(subscriptionStatus);

  // 5. Offer Code 할당 (optimistic locking)
  const allocatedCode = await allocateOfferCode(offerName, userId);

  if (!allocatedCode) {
    return successResponse({
      status: "no_codes_available",
      message: "일시적으로 혜택을 적용할 수 없습니다.",
    });
  }

  // 6. referrals INSERT — 초대 기록 생성
  const { data: referral, error: insertError } = await supabase
    .from("referrals")
    .insert({
      referrer_user_id: link.user_id,
      referred_user_id: userId,
      offer_code: allocatedCode,
      offer_name: offerName,
      status: "matched",
    })
    .select("id")
    .single();

  if (insertError) {
    // UNIQUE 위반 (동시 요청으로 중복 삽입) → already_redeemed
    if (insertError.code === "23505") {
      return successResponse({
        status: "already_redeemed",
        message: "이미 초대 코드가 적용되어 있습니다.",
      });
    }
    // CHECK 위반 (자기 초대) → self_referral
    if (insertError.code === "23514") {
      return successResponse({
        status: "self_referral",
        message: "본인의 초대 코드는 사용할 수 없습니다.",
      });
    }
    console.error("match-code: referrals INSERT 실패 —", insertError.message);
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  // 7. 리딤 URL 생성 및 반환
  const redeemUrl = buildRedeemURL(allocatedCode);

  console.log(
    `match-code: 매칭 성공 — referrer=${link.user_id.substring(0, 8)}, referred=${userId.substring(0, 8)}, offer=${offerName}`
  );

  return successResponse({
    referral_id: referral.id,
    redeem_url: redeemUrl,
    offer_name: offerName,
    status: "matched",
  });
}

// MARK: - check-status 엔드포인트

/**
 * POST /check-status — 피초대자 초대 코드 적용 상태 확인
 *
 * 로직:
 * 1. referrals에서 referred_user_id로 조회
 * 2. 없으면 → none
 * 3. matched → 할당된 코드 만료 확인 → 만료면 새 코드 할당
 * 4. redeemed → 이미 적용됨
 *
 * @param userId - 피초대자 user_id
 * @returns { status: "none" | "matched" | "redeemed", redeem_url?, message? }
 */
async function handleCheckStatus(userId: string): Promise<Response> {
  // 1. 피초대자의 referral 기록 조회
  const { data: referral, error: selectError } = await supabase
    .from("referrals")
    .select("id, offer_code, offer_name, status")
    .eq("referred_user_id", userId)
    .maybeSingle();

  if (selectError) {
    console.error("check-status: referrals 조회 실패 —", selectError.message);
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  // 2. 레코드 없음 — 아직 초대 코드 미사용
  if (!referral) {
    return successResponse({ status: "none" });
  }

  // 3. matched — 코드 할당됨, 리딤 미완료
  if (referral.status === "matched") {
    // 할당된 코드 만료 확인
    let currentCode = referral.offer_code;
    if (currentCode) {
      const { data: codeData } = await supabase
        .from("offer_codes")
        .select("expires_at, status")
        .eq("code", currentCode)
        .maybeSingle();

      // 코드가 만료되었으면 새 코드 할당
      if (
        codeData &&
        (codeData.status === "expired" ||
          (codeData.expires_at &&
            new Date(codeData.expires_at) < new Date()))
      ) {
        console.log("check-status: 할당된 코드 만료 → 새 코드 할당 시도");

        // 만료된 코드를 expired로 업데이트
        await supabase
          .from("offer_codes")
          .update({ status: "expired" })
          .eq("code", currentCode);

        // 새 코드 할당
        const newCode = await allocateOfferCode(
          referral.offer_name || "referral_invited_monthly",
          userId
        );

        if (newCode) {
          // referrals 테이블에 새 코드 반영
          await supabase
            .from("referrals")
            .update({ offer_code: newCode })
            .eq("id", referral.id);

          currentCode = newCode;
        } else {
          // 새 코드 할당 실패 — 기존 만료 코드 유지 (에러 안내는 클라이언트에서)
          console.warn("check-status: 새 코드 할당 실패 — 코드 풀 소진");
        }
      }
    }

    const redeemUrl = currentCode ? buildRedeemURL(currentCode) : null;

    return successResponse({
      status: "matched",
      redeem_url: redeemUrl,
      message: "혜택이 아직 적용되지 않았어요.",
    });
  }

  // 4. redeemed 또는 그 이상 — 이미 적용됨
  return successResponse({
    status: "redeemed",
    message: "이미 초대 코드가 적용되어 있습니다.",
  });
}

// MARK: - report-redemption 엔드포인트

/**
 * POST /report-redemption — 피초대자 Offer Code 리딤 완료 보고
 *
 * 로직:
 * 1. referrals 상태 → redeemed, redeemed_at = now()
 * 2. offer_codes 상태 → used, used_at = now()
 * 3. pending_rewards INSERT (초대자 보상 대기)
 * 4. Push 알림 발송 (Phase 8에서 추가)
 *
 * @param body - { user_id, referral_id }
 * @returns { status: "redeemed" }
 */
async function handleReportRedemption(body: Record<string, unknown>): Promise<Response> {
  const userId = body.user_id as string;
  const referralId = body.referral_id as string;

  // 필수 파라미터 확인
  if (!referralId) {
    return errorResponse("referral_id가 필요합니다.", 400);
  }

  // 1. referral 조회 및 상태 확인
  const { data: referral, error: selectError } = await supabase
    .from("referrals")
    .select("id, referrer_user_id, referred_user_id, offer_code, status")
    .eq("id", referralId)
    .maybeSingle();

  if (selectError) {
    console.error("report-redemption: referrals 조회 실패 —", selectError.message);
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  if (!referral) {
    return errorResponse("해당 초대 기록을 찾을 수 없습니다.");
  }

  // 이미 redeemed 이상이면 중복 보고 무시 (멱등성)
  if (referral.status !== "matched") {
    console.log(
      `report-redemption: 이미 ${referral.status} 상태 — 중복 보고 무시`
    );
    return successResponse({ status: referral.status });
  }

  // 피초대자 본인인지 확인
  if (referral.referred_user_id !== userId) {
    return errorResponse("잘못된 요청입니다.");
  }

  // 2. referrals → redeemed
  const { error: updateReferralError } = await supabase
    .from("referrals")
    .update({
      status: "redeemed",
      redeemed_at: new Date().toISOString(),
    })
    .eq("id", referralId)
    .eq("status", "matched");

  if (updateReferralError) {
    console.error(
      "report-redemption: referrals UPDATE 실패 —",
      updateReferralError.message
    );
    return errorResponse("서버 오류가 발생했습니다.", 500);
  }

  // 3. offer_codes → used
  if (referral.offer_code) {
    const { error: updateCodeError } = await supabase
      .from("offer_codes")
      .update({
        status: "used",
        used_at: new Date().toISOString(),
      })
      .eq("code", referral.offer_code);

    if (updateCodeError) {
      console.error(
        "report-redemption: offer_codes UPDATE 실패 —",
        updateCodeError.message
      );
      // 치명적이지 않으므로 계속 진행
    }
  }

  // 4. pending_rewards INSERT — 초대자 보상 대기
  const { error: insertRewardError } = await supabase
    .from("pending_rewards")
    .insert({
      user_id: referral.referrer_user_id,
      referral_id: referralId,
      status: "pending",
      // reward_type은 수령 시점에 결정됨 (NULL)
    });

  if (insertRewardError) {
    console.error(
      "report-redemption: pending_rewards INSERT 실패 —",
      insertRewardError.message
    );
    // 치명적이지 않으므로 계속 진행 (다음 실행 시 재시도 가능)
  }

  // 5. Push 알림 발송 (Phase 8에서 구현)
  // TODO: push-notify 호출 — referral.referrer_user_id의 device_token 조회 후 APNs 발송

  console.log(
    `report-redemption: 리딤 완료 — referral=${referralId}, referrer=${referral.referrer_user_id.substring(0, 8)}`
  );

  return successResponse({ status: "redeemed" });
}

// MARK: - 메인 핸들러

Deno.serve(async (req: Request): Promise<Response> => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // POST만 허용
  if (req.method !== "POST") {
    return errorResponse("Method not allowed", 405);
  }

  // URL에서 엔드포인트 추출
  // /functions/v1/referral-api/create-link → "create-link"
  const url = new URL(req.url);
  const pathParts = url.pathname.split("/").filter(Boolean);
  const endpoint = pathParts[pathParts.length - 1];

  // 요청 바디 파싱
  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return errorResponse("잘못된 요청 형식입니다.", 400);
  }

  // user_id 필수 확인
  const userId = body.user_id as string;
  if (!userId) {
    return errorResponse("user_id가 필요합니다.", 400);
  }

  // Rate Limiting (FR-037)
  const limit = RATE_LIMITS[endpoint];
  if (limit) {
    // match-code는 IP + user_id 기반, 나머지는 user_id 기반
    const rateLimitKey =
      endpoint === "match-code"
        ? `${endpoint}:${getClientIP(req)}:${userId}`
        : `${endpoint}:${userId}`;

    const result = checkRateLimit(rateLimitKey, limit);
    if (!result.allowed) {
      return rateLimitResponse(result.retryAfter);
    }
  }

  // 엔드포인트 라우팅
  switch (endpoint) {
    case "create-link":
      return handleCreateLink(userId);
    case "match-code":
      return handleMatchCode(body);
    case "check-status":
      return handleCheckStatus(userId);
    case "report-redemption":
      return handleReportRedemption(body);

    // 이후 Phase에서 추가:
    // case "get-pending-rewards": return handleGetPendingRewards(userId);
    // case "claim-reward": return handleClaimReward(body);
    // case "update-device-token": return handleUpdateDeviceToken(body);

    default:
      return errorResponse(`알 수 없는 엔드포인트: ${endpoint}`, 404);
  }
});

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

    // 이후 Phase에서 추가:
    // case "match-code": return handleMatchCode(body);
    // case "check-status": return handleCheckStatus(userId);
    // case "report-redemption": return handleReportRedemption(body);
    // case "get-pending-rewards": return handleGetPendingRewards(userId);
    // case "claim-reward": return handleClaimReward(body);
    // case "update-device-token": return handleUpdateDeviceToken(body);

    default:
      return errorResponse(`알 수 없는 엔드포인트: ${endpoint}`, 404);
  }
});

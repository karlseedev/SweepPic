/**
 * push-notify — APNs Push 알림 발송 Edge Function
 *
 * referral-api/report-redemption에서 내부 호출.
 * 피초대자가 Offer Code를 리딤하면 초대자에게 Push 알림을 발송한다.
 *
 * 로직:
 * 1. 초대자의 device_token 조회 (referral_links)
 * 2. NULL이면 스킵 (Push 미허용)
 * 3. APNs JWT 생성 (P8 키, team_id)
 * 4. APNs HTTP/2 POST 호출
 * 5. 410 Gone → device_token NULL 설정 (토큰 만료)
 *
 * 환경 변수:
 * - APNS_KEY_ID: APNs P8 키 ID
 * - TEAM_ID: Apple Developer Team ID
 * - BUNDLE_ID: 앱 Bundle ID
 * - APNS_P8_KEY: P8 키 내용 (Supabase Vault)
 *
 * 참조: specs/004-referral-reward/contracts/api-endpoints.md §push-notify
 * 참조: specs/004-referral-reward/research.md §2 APNs HTTP/2
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v5.2.0/index.ts";

// Supabase 클라이언트
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// APNs 환경 변수
const apnsKeyId = Deno.env.get("APNS_KEY_ID") || "";
const teamId = Deno.env.get("TEAM_ID") || "";
const bundleId = Deno.env.get("BUNDLE_ID") || "com.karl.SweepPic";
const apnsP8Key = Deno.env.get("APNS_P8_KEY") || "";

// APNs 엔드포인트 (Production)
const APNS_HOST = "https://api.push.apple.com";
// Sandbox용: const APNS_HOST = "https://api.sandbox.push.apple.com";

// JWT 캐시 (20분 유효, 재사용)
let cachedJWT: { token: string; expiresAt: number } | null = null;

// MARK: - APNs JWT 생성

/**
 * APNs JWT를 생성한다 (ES256 서명).
 * P8 키로 서명하며, 캐시된 JWT가 유효하면 재사용한다.
 *
 * JWT 구조:
 * - Header: { "alg": "ES256", "kid": "{APNS_KEY_ID}" }
 * - Payload: { "iss": "{TEAM_ID}", "iat": {timestamp} }
 *
 * @returns APNs Bearer 토큰
 */
async function getAPNsJWT(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);

  // 캐시 유효 확인 (만료 2분 전까지 재사용)
  if (cachedJWT && cachedJWT.expiresAt > now + 120) {
    return cachedJWT.token;
  }

  // P8 키를 PKCS8 형식으로 파싱
  const privateKey = await jose.importPKCS8(apnsP8Key, "ES256");

  // JWT 생성 (유효 기간 50분 — Apple 최대 60분)
  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: apnsKeyId })
    .setIssuer(teamId)
    .setIssuedAt(now)
    .sign(privateKey);

  // 캐시 저장 (50분 유효)
  cachedJWT = { token: jwt, expiresAt: now + 50 * 60 };

  return jwt;
}

// MARK: - Push 알림 발송

/**
 * APNs HTTP/2로 Push 알림을 발송한다.
 *
 * @param deviceToken - APNs device token (hex 문자열)
 * @param payload - Push payload
 * @returns 성공 여부 + 상태 코드
 */
async function sendPush(
  deviceToken: string,
  payload: Record<string, unknown>
): Promise<{ success: boolean; statusCode: number }> {
  const jwt = await getAPNsJWT();

  const response = await fetch(
    `${APNS_HOST}/3/device/${deviceToken}`,
    {
      method: "POST",
      headers: {
        authorization: `bearer ${jwt}`,
        "apns-topic": bundleId,
        "apns-push-type": "alert",
        "apns-priority": "10",
      },
      body: JSON.stringify(payload),
    }
  );

  return {
    success: response.status === 200,
    statusCode: response.status,
  };
}

// MARK: - 메인 핸들러

Deno.serve(async (req: Request): Promise<Response> => {
  // POST만 허용
  if (req.method !== "POST") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  try {
    const body = await req.json();
    const { referrer_user_id, reward_id } = body;

    if (!referrer_user_id) {
      return new Response(
        JSON.stringify({ success: false, error: "referrer_user_id 필수" }),
        { status: 400, headers: { "Content-Type": "application/json" } }
      );
    }

    // 1. 초대자의 device_token 조회
    const { data: link, error: linkError } = await supabase
      .from("referral_links")
      .select("device_token")
      .eq("user_id", referrer_user_id)
      .maybeSingle();

    if (linkError) {
      console.error("push-notify: referral_links 조회 실패 —", linkError.message);
      return new Response(
        JSON.stringify({ success: false, error: "조회 실패" }),
        { status: 500, headers: { "Content-Type": "application/json" } }
      );
    }

    // 2. device_token이 없으면 스킵 (Push 미허용)
    if (!link?.device_token) {
      console.log(
        `push-notify: 스킵 — user=${referrer_user_id.substring(0, 8)}, device_token 없음`
      );
      return new Response(
        JSON.stringify({ success: true, data: { skipped: true, reason: "no_device_token" } }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 3. P8 키 미설정 시 스킵
    if (!apnsP8Key || !apnsKeyId || !teamId) {
      console.warn("push-notify: APNs 환경 변수 미설정 — 스킵");
      return new Response(
        JSON.stringify({ success: true, data: { skipped: true, reason: "apns_not_configured" } }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 4. Push 페이로드 구성
    const payload = {
      aps: {
        alert: {
          title: "초대 보상 도착!",
          body: "초대한 사람이 SweepPic에 가입했어요! 14일 무료 혜택을 받으세요",
        },
        sound: "default",
        badge: 1,
      },
      action_type: "referral_reward",
      reward_id: reward_id || null,
    };

    // 5. APNs 호출
    const result = await sendPush(link.device_token, payload);

    if (result.success) {
      console.log(
        `push-notify: 발송 성공 — user=${referrer_user_id.substring(0, 8)}`
      );
      return new Response(
        JSON.stringify({ success: true, data: { sent: true } }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 6. 410 Gone → device_token 무효화 (토큰 만료)
    if (result.statusCode === 410) {
      console.warn(
        `push-notify: 토큰 만료 (410) — user=${referrer_user_id.substring(0, 8)}, device_token NULL 설정`
      );

      await supabase
        .from("referral_links")
        .update({ device_token: null })
        .eq("user_id", referrer_user_id);

      return new Response(
        JSON.stringify({ success: true, data: { sent: false, reason: "token_expired" } }),
        { status: 200, headers: { "Content-Type": "application/json" } }
      );
    }

    // 기타 에러
    console.error(
      `push-notify: APNs 에러 ${result.statusCode} — user=${referrer_user_id.substring(0, 8)}`
    );
    return new Response(
      JSON.stringify({ success: false, error: `APNs 에러: ${result.statusCode}` }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );

  } catch (err) {
    console.error("push-notify: 처리 실패 —", err);
    return new Response(
      JSON.stringify({ success: false, error: "내부 오류" }),
      { status: 500, headers: { "Content-Type": "application/json" } }
    );
  }
});

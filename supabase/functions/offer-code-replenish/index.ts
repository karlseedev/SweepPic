/**
 * offer-code-replenish — Offer Code 풀 자동 보충 Edge Function
 *
 * 매일 새벽 3시 KST (Supabase Dashboard cron) 실행.
 * offer_name별 available 코드 수량을 확인하고,
 * 5,000개 미만이면 ASC API로 코드를 생성하여 DB에 INSERT.
 * 만료된 코드는 expired 상태로 정리.
 *
 * 로직:
 * 1. offer_name별 available 코드 카운트
 * 2. 5,000개 미만 → ASC API로 코드 생성 (최대 25,000개/배치)
 * 3. CSV 다운로드 → offer_codes INSERT
 * 4. 만료 코드 정리: expires_at < now() → status='expired'
 * 5. 실패 시 재시도: 1h→3h→6h
 * 6. 최종 실패 시 Slack/Email 알림 (FR-034)
 *
 * 환경 변수:
 * - ASC_KEY_ID: App Store Connect API Key ID
 * - ASC_ISSUER_ID: ASC Issuer ID
 * - ASC_P8_KEY: P8 키 내용 (Supabase Vault)
 * - SLACK_WEBHOOK_URL: 알림용 Slack Webhook (선택)
 *
 * 참조: specs/004-referral-reward/contracts/api-endpoints.md §offer-code-replenish
 * 참조: specs/004-referral-reward/research.md §3 ASC API
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import * as jose from "https://deno.land/x/jose@v5.2.0/index.ts";

// Supabase 클라이언트
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// ASC API 환경 변수
const ascKeyId = Deno.env.get("ASC_KEY_ID") || "";
const ascIssuerId = Deno.env.get("ASC_ISSUER_ID") || "";
const ascP8Key = Deno.env.get("ASC_P8_KEY") || "";
const slackWebhookUrl = Deno.env.get("SLACK_WEBHOOK_URL") || "";

// ASC API 기본 URL
const ASC_API_BASE = "https://api.appstoreconnect.apple.com/v1";

// 코드 풀 임계값 — 이 수량 미만이면 보충 트리거
const THRESHOLD = 5000;

// 관리 대상 Offer Name 목록
const OFFER_NAMES = [
  "referral_invited_monthly",
  "referral_invited_yearly",
  "referral_reward_01",
];

// 재시도 간격 (밀리초) — 1h, 3h, 6h
const RETRY_DELAYS = [
  1 * 60 * 60 * 1000,
  3 * 60 * 60 * 1000,
  6 * 60 * 60 * 1000,
];

// MARK: - ASC API JWT 생성

/**
 * App Store Connect API JWT를 생성한다 (ES256 서명).
 *
 * JWT 구조:
 * - Header: { "alg": "ES256", "kid": "{ASC_KEY_ID}", "typ": "JWT" }
 * - Payload: { "iss": "{ASC_ISSUER_ID}", "iat": timestamp, "exp": +20분, "aud": "appstoreconnect-v1" }
 *
 * @returns ASC API Bearer 토큰
 */
async function getASCJWT(): Promise<string> {
  const privateKey = await jose.importPKCS8(ascP8Key, "ES256");
  const now = Math.floor(Date.now() / 1000);

  const jwt = await new jose.SignJWT({})
    .setProtectedHeader({ alg: "ES256", kid: ascKeyId, typ: "JWT" })
    .setIssuer(ascIssuerId)
    .setIssuedAt(now)
    .setExpirationTime(now + 20 * 60) // 20분 유효
    .setAudience("appstoreconnect-v1")
    .sign(privateKey);

  return jwt;
}

// MARK: - 코드 수량 확인

/**
 * offer_name별 available 코드 수량을 확인한다.
 *
 * @returns { offerName: count } 맵
 */
async function getAvailableCounts(): Promise<Record<string, number>> {
  const counts: Record<string, number> = {};

  for (const offerName of OFFER_NAMES) {
    const { count, error } = await supabase
      .from("offer_codes")
      .select("*", { count: "exact", head: true })
      .eq("offer_name", offerName)
      .eq("status", "available")
      .gt("expires_at", new Date().toISOString());

    if (error) {
      console.error(`replenish: ${offerName} 카운트 실패 —`, error.message);
      counts[offerName] = 0;
    } else {
      counts[offerName] = count ?? 0;
    }
  }

  return counts;
}

// MARK: - 만료 코드 정리

/**
 * 만료된 코드를 expired 상태로 업데이트한다.
 * expires_at < now() AND status = 'available' → status = 'expired'
 *
 * @returns 정리된 코드 수
 */
async function cleanupExpiredCodes(): Promise<number> {
  const now = new Date().toISOString();

  const { data, error } = await supabase
    .from("offer_codes")
    .update({ status: "expired" })
    .eq("status", "available")
    .lt("expires_at", now)
    .select("id");

  if (error) {
    console.error("replenish: 만료 코드 정리 실패 —", error.message);
    return 0;
  }

  const count = data?.length ?? 0;
  if (count > 0) {
    console.log(`replenish: 만료 코드 ${count}건 정리 완료`);
  }
  return count;
}

// MARK: - ASC API 코드 생성

/**
 * ASC API로 Offer Code를 생성하고 CSV를 다운로드하여 DB에 INSERT한다.
 *
 * 1. POST /v1/subscriptionOfferCodeOneTimeUseCodes → 코드 생성 요청
 * 2. GET /v1/subscriptionOfferCodeOneTimeUseCodes/{id}/values → CSV 다운로드
 * 3. CSV 파싱 → offer_codes INSERT
 *
 * @param offerName - Offer 이름
 * @param quantity - 생성할 코드 수 (최대 25,000)
 * @returns 생성된 코드 수
 */
async function replenishCodes(
  offerName: string,
  quantity: number
): Promise<number> {
  const jwt = await getASCJWT();
  const headers = {
    Authorization: `Bearer ${jwt}`,
    "Content-Type": "application/json",
  };

  // 1. 코드 생성 요청
  // ⚠️ ASC API에서 실제 Offer의 subscription offer code ID가 필요
  //    이 ID는 ASC 웹 UI에서 Offer를 생성한 후 확인 가능
  //    환경 변수 ASC_OFFER_ID_{offerName}으로 설정 필요
  const offerIdEnvKey = `ASC_OFFER_ID_${offerName.toUpperCase()}`;
  const subscriptionOfferCodeId = Deno.env.get(offerIdEnvKey);

  if (!subscriptionOfferCodeId) {
    console.warn(
      `replenish: ${offerName} — ASC Offer ID 환경변수(${offerIdEnvKey}) 미설정, 스킵`
    );
    return 0;
  }

  console.log(
    `replenish: ${offerName} — ${quantity}개 코드 생성 요청`
  );

  const createResponse = await fetch(
    `${ASC_API_BASE}/subscriptionOfferCodeOneTimeUseCodes`,
    {
      method: "POST",
      headers,
      body: JSON.stringify({
        data: {
          type: "subscriptionOfferCodeOneTimeUseCodes",
          attributes: {
            numberOfCodes: Math.min(quantity, 25000),
            // 만료일: 6개월 후
            expirationDate: getExpirationDate(),
          },
          relationships: {
            offerCode: {
              data: {
                type: "subscriptionOfferCodes",
                id: subscriptionOfferCodeId,
              },
            },
          },
        },
      }),
    }
  );

  if (!createResponse.ok) {
    const errorText = await createResponse.text();
    throw new Error(
      `ASC 코드 생성 실패 (${createResponse.status}): ${errorText}`
    );
  }

  const createResult = await createResponse.json();
  const codeRequestId = createResult.data?.id;

  if (!codeRequestId) {
    throw new Error("ASC 코드 생성 응답에 ID 없음");
  }

  // 2. CSV 다운로드 (생성 완료까지 대기)
  // ASC는 비동기로 코드를 생성하므로 폴링 필요
  let csvData = "";
  for (let attempt = 0; attempt < 10; attempt++) {
    // 30초 대기 후 확인
    await new Promise((resolve) => setTimeout(resolve, 30000));

    const valuesResponse = await fetch(
      `${ASC_API_BASE}/subscriptionOfferCodeOneTimeUseCodes/${codeRequestId}/values`,
      { headers }
    );

    if (valuesResponse.ok) {
      csvData = await valuesResponse.text();
      break;
    }

    if (valuesResponse.status === 404 || valuesResponse.status === 202) {
      // 아직 생성 중
      console.log(
        `replenish: ${offerName} — 코드 생성 대기 중... (${attempt + 1}/10)`
      );
      continue;
    }

    throw new Error(
      `ASC CSV 다운로드 실패 (${valuesResponse.status})`
    );
  }

  if (!csvData) {
    throw new Error("ASC 코드 생성 타임아웃 (5분)");
  }

  // 3. CSV 파싱 → DB INSERT
  const codes = csvData
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line && !line.startsWith("Code")); // 헤더 제외

  if (codes.length === 0) {
    throw new Error("CSV에서 코드를 추출할 수 없음");
  }

  // 배치 INSERT (1,000개씩)
  let insertedCount = 0;
  const expiresAt = getExpirationDate();

  for (let i = 0; i < codes.length; i += 1000) {
    const batch = codes.slice(i, i + 1000).map((code) => ({
      code,
      offer_name: offerName,
      status: "available",
      expires_at: expiresAt,
    }));

    const { error } = await supabase.from("offer_codes").insert(batch);

    if (error) {
      console.error(
        `replenish: ${offerName} — DB INSERT 실패 (batch ${i}~${i + batch.length}):`,
        error.message
      );
    } else {
      insertedCount += batch.length;
    }
  }

  console.log(
    `replenish: ${offerName} — ${insertedCount}/${codes.length}개 INSERT 완료`
  );

  return insertedCount;
}

// MARK: - 유틸리티

/**
 * 6개월 후 만료일을 ISO 문자열로 반환한다.
 */
function getExpirationDate(): string {
  const date = new Date();
  date.setMonth(date.getMonth() + 6);
  return date.toISOString();
}

// MARK: - 알림 (Slack)

/**
 * Slack Webhook으로 알림을 발송한다.
 * SLACK_WEBHOOK_URL 미설정 시 콘솔 로그만 출력.
 *
 * @param message - 알림 메시지
 * @param isError - 에러 여부 (아이콘 변경)
 */
async function sendAlert(
  message: string,
  isError: boolean = false
): Promise<void> {
  console.log(`replenish: [알림] ${message}`);

  if (!slackWebhookUrl) return;

  try {
    await fetch(slackWebhookUrl, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        text: `${isError ? "🚨" : "✅"} [SweepPic Offer Code] ${message}`,
      }),
    });
  } catch (err) {
    console.warn("replenish: Slack 알림 실패 —", err);
  }
}

// MARK: - 메인 핸들러

Deno.serve(async (_req: Request): Promise<Response> => {
  console.log("replenish: 실행 시작");

  // 1. 만료 코드 정리
  const expiredCount = await cleanupExpiredCodes();

  // 2. ASC API 미설정 시 만료 정리만 수행
  if (!ascP8Key || !ascKeyId || !ascIssuerId) {
    console.warn("replenish: ASC API 환경 변수 미설정 — 만료 정리만 수행");
    return new Response(
      JSON.stringify({
        success: true,
        data: {
          expired_cleaned: expiredCount,
          replenished: {},
          message: "ASC API 미설정 — 만료 정리만 수행",
        },
      }),
      { status: 200, headers: { "Content-Type": "application/json" } }
    );
  }

  // 3. offer_name별 available 코드 수량 확인
  const counts = await getAvailableCounts();
  console.log("replenish: 현재 코드 수량 —", JSON.stringify(counts));

  // 4. 임계값 미만인 Offer에 대해 보충
  const replenished: Record<string, number> = {};
  const failures: string[] = [];

  for (const offerName of OFFER_NAMES) {
    const available = counts[offerName] ?? 0;

    if (available >= THRESHOLD) {
      console.log(
        `replenish: ${offerName} — ${available}개 (임계값 ${THRESHOLD} 이상, 스킵)`
      );
      continue;
    }

    // 보충 필요량: 임계값 × 2 - 현재 수량 (넉넉하게)
    const needed = THRESHOLD * 2 - available;
    console.log(
      `replenish: ${offerName} — ${available}개 (임계값 미만, ${needed}개 보충 시도)`
    );

    // 재시도 로직
    let success = false;
    for (let retry = 0; retry < RETRY_DELAYS.length; retry++) {
      try {
        const inserted = await replenishCodes(offerName, needed);
        replenished[offerName] = inserted;
        success = true;

        await sendAlert(
          `${offerName}: ${inserted}개 코드 보충 완료 (기존 ${available}개)`
        );
        break;
      } catch (err) {
        console.error(
          `replenish: ${offerName} — 보충 실패 (시도 ${retry + 1}/${RETRY_DELAYS.length}):`,
          err
        );

        if (retry < RETRY_DELAYS.length - 1) {
          const delayMs = RETRY_DELAYS[retry];
          const delayHours = delayMs / (60 * 60 * 1000);
          console.log(
            `replenish: ${offerName} — ${delayHours}시간 후 재시도`
          );
          await new Promise((resolve) => setTimeout(resolve, delayMs));
        }
      }
    }

    if (!success) {
      failures.push(offerName);
      await sendAlert(
        `${offerName}: 코드 보충 최종 실패! 현재 ${available}개 남음. 수동 보충 필요.`,
        true
      );
    }
  }

  // 5. 결과 반환
  const result = {
    success: failures.length === 0,
    data: {
      expired_cleaned: expiredCount,
      counts,
      replenished,
      failures: failures.length > 0 ? failures : undefined,
    },
  };

  console.log("replenish: 실행 완료 —", JSON.stringify(result));

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});

/**
 * referral-landing — 초대 링크 랜딩 페이지 Edge Function
 *
 * 초대 링크(sweeppic.link/r/{code}) 클릭 시 도착하는 랜딩 페이지.
 * OG 메타태그로 SNS 미리보기를 제공하고, 인앱 브라우저를 감지하여
 * 적절한 리다이렉트를 수행한다.
 *
 * 엔드포인트:
 * - GET /r/{code} : 랜딩 페이지 HTML 응답
 *
 * 로직:
 * 1. URL에서 referral_code 추출
 * 2. referral_links 테이블에서 코드 유효성 검증
 * 3. 유효 → OG 메타태그 + 인앱 브라우저 감지 JS + 리다이렉트 HTML 반환
 * 4. 무효 → App Store 앱 페이지로 직접 리다이렉트
 *
 * 참조: specs/004-referral-reward/contracts/api-endpoints.md §referral-landing
 * 참조: docs/bm/260316Reward.md §랜딩 페이지 구현 코드
 */

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// Supabase 클라이언트 (service_role — RLS 바이패스)
const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const supabaseServiceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const supabase = createClient(supabaseUrl, supabaseServiceRoleKey);

// 환경 변수
const appStoreAppId = Deno.env.get("APP_STORE_APP_ID") || "";
const bundleId = Deno.env.get("BUNDLE_ID") || "com.karl.SweepPic";
const teamId = Deno.env.get("TEAM_ID") || "";
const customDomain = Deno.env.get("CUSTOM_DOMAIN") || "";

// App Store URL
const appStoreURL = `https://apps.apple.com/app/id${appStoreAppId}`;

// CORS 헤더
const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

// MARK: - OG 메타태그 HTML 생성

/**
 * 랜딩 페이지 HTML을 생성한다.
 * OG 메타태그 + 인앱 브라우저 감지 JS + 리다이렉트 로직 포함.
 *
 * @param referralCode - 초대 코드 (유효한 경우)
 * @param isValid - 코드 유효 여부
 * @returns 완성된 HTML 문자열
 */
function generateLandingHTML(referralCode: string, isValid: boolean): string {
  // OG 이미지 URL — 에셋 준비 전까지 빈 값 (FR-021: 1200×630px)
  const ogImageURL = customDomain
    ? `https://${customDomain}/og-image.png`
    : "";

  // Custom URL Scheme (앱이 설치된 경우 앱으로 이동)
  const appSchemeURL = isValid
    ? `sweeppic://referral/${referralCode}`
    : `sweeppic://`;

  return `<!DOCTYPE html>
<html lang="ko">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">

  <!-- OG 메타태그 — SNS 미리보기 (FR-021) -->
  <meta property="og:title" content="SweepPic - 14일 프리미엄 무료 받기">
  <meta property="og:description" content="친구가 14일 프리미엄을 선물했어요!">
  <meta property="og:type" content="website">
  ${ogImageURL ? `<meta property="og:image" content="${ogImageURL}">` : ""}
  <meta property="og:url" content="${customDomain ? `https://${customDomain}/r/${referralCode}` : ""}">

  <!-- Twitter Card -->
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="SweepPic - 14일 프리미엄 무료 받기">
  <meta name="twitter:description" content="친구가 14일 프리미엄을 선물했어요!">
  ${ogImageURL ? `<meta name="twitter:image" content="${ogImageURL}">` : ""}

  <title>SweepPic 초대</title>

  <style>
    /* 최소한의 스타일 — 리다이렉트 실패 시 폴백 UI */
    body {
      font-family: -apple-system, BlinkMacSystemFont, sans-serif;
      display: flex;
      justify-content: center;
      align-items: center;
      min-height: 100vh;
      margin: 0;
      background: #000;
      color: #fff;
      text-align: center;
    }
    .container { padding: 20px; max-width: 400px; }
    h1 { font-size: 24px; margin-bottom: 8px; }
    p { font-size: 16px; color: #999; margin-bottom: 24px; }
    .btn {
      display: inline-block;
      padding: 14px 32px;
      background: #fff;
      color: #000;
      text-decoration: none;
      border-radius: 12px;
      font-weight: 600;
      font-size: 16px;
    }
    .code { font-family: monospace; color: #FFD700; font-size: 14px; margin-top: 16px; }
  </style>
</head>
<body>
  <div class="container">
    <h1>SweepPic</h1>
    <p>${isValid ? "14일 프리미엄 무료 혜택을 받아보세요!" : "앱을 설치해보세요!"}</p>
    <a class="btn" href="${appStoreURL}" id="store-btn">App Store에서 다운로드</a>
    ${isValid ? `<p class="code">초대 코드: ${referralCode}</p>` : ""}
  </div>

  <script>
    (function() {
      var ua = navigator.userAgent.toLowerCase();
      var appStoreURL = '${appStoreURL}';
      var appSchemeURL = '${appSchemeURL}';
      var isValid = ${isValid};

      // 인앱 브라우저 감지 및 외부 전환 (docs/bm/260316Reward.md)
      if (ua.indexOf('kakaotalk') > -1) {
        // 카카오톡: 공식 스킴으로 Safari 자동 전환
        location.href = 'kakaotalk://web/openExternal?url='
          + encodeURIComponent(location.href);
        return;

      } else if (ua.indexOf('line') > -1) {
        // LINE: 공식 외부 브라우저 파라미터
        var sep = location.href.indexOf('?') > -1 ? '&' : '?';
        location.href = location.href + sep + 'openExternalBrowser=1';
        return;

      } else if (/instagram|fban|fbav|twitter|naver/i.test(ua)) {
        // Instagram/Facebook/X/네이버: App Store 앱 페이지로 리다이렉트
        location.href = appStoreURL;
        return;
      }

      // 일반 브라우저 (Safari, Chrome 등)
      if (isValid) {
        // 앱 설치됨 → Custom URL Scheme으로 앱 열기 시도
        window.location.href = appSchemeURL;
        // 앱 미설치 → 1.5초 후 App Store로 리다이렉트
        setTimeout(function() {
          window.location.href = appStoreURL;
        }, 1500);
      } else {
        // 무효 코드 → 바로 App Store
        window.location.href = appStoreURL;
      }
    })();
  </script>
</body>
</html>`;
}

// MARK: - apple-app-site-association (Phase 7)

/**
 * apple-app-site-association JSON을 반환한다.
 * Universal Link 작동에 필요한 파일.
 * 커스텀 도메인의 /.well-known/apple-app-site-association 경로로 서빙.
 *
 * @returns AASA JSON 응답
 */
function handleAASA(): Response {
  const aasa = {
    applinks: {
      apps: [],
      details: [
        {
          appIDs: [`${teamId}.${bundleId}`],
          paths: ["/r/*"],
        },
      ],
    },
  };

  return new Response(JSON.stringify(aasa), {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

// MARK: - 분석 이벤트 기록

/**
 * 랜딩 방문 분석 이벤트를 events 테이블에 기록한다.
 * 실패해도 랜딩 동작에는 영향 없음 (fire-and-forget).
 *
 * @param referralCode - 초대 코드
 * @param userAgent - 방문자 User-Agent
 */
async function recordLandingVisit(
  referralCode: string,
  userAgent: string
): Promise<void> {
  try {
    await supabase.from("events").insert({
      event_name: "referral.landing_visited",
      properties: {
        referral_code: referralCode,
        user_agent: userAgent.substring(0, 500),
      },
    });
  } catch (err) {
    // 분석 실패는 무시 — 랜딩 동작에 영향 없음
    console.warn("landing: 분석 이벤트 기록 실패 —", err);
  }
}

// MARK: - 메인 핸들러

Deno.serve(async (req: Request): Promise<Response> => {
  // CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // GET만 허용
  if (req.method !== "GET") {
    return new Response("Method Not Allowed", { status: 405 });
  }

  const url = new URL(req.url);
  const path = url.pathname;

  // apple-app-site-association 요청 처리 (Phase 7, T038)
  if (
    path.endsWith("/.well-known/apple-app-site-association") ||
    path.endsWith("/apple-app-site-association")
  ) {
    return handleAASA();
  }

  // /r/{code} 경로에서 코드 추출
  const pathMatch = path.match(/\/r\/([a-zA-Z0-9]+)$/);
  if (!pathMatch) {
    // 잘못된 경로 → App Store로 리다이렉트
    return new Response(null, {
      status: 302,
      headers: { Location: appStoreURL },
    });
  }

  const referralCode = pathMatch[1];
  const userAgent = req.headers.get("user-agent") || "";

  // referral_links 테이블에서 코드 유효성 확인
  const { data: link } = await supabase
    .from("referral_links")
    .select("id")
    .eq("referral_code", referralCode)
    .maybeSingle();

  const isValid = !!link;

  // 유효한 코드 → 분석 이벤트 기록 (fire-and-forget)
  if (isValid) {
    recordLandingVisit(referralCode, userAgent);
  }

  // HTML 랜딩 페이지 반환
  const html = generateLandingHTML(referralCode, isValid);

  return new Response(html, {
    status: 200,
    headers: {
      ...corsHeaders,
      "Content-Type": "text/html; charset=utf-8",
      // SNS 크롤러가 OG 태그를 읽을 수 있도록 캐시 설정
      "Cache-Control": "public, max-age=3600",
    },
  });
});

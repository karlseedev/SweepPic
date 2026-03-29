/**
 * Rate Limiter — IP/user_id 기반 분당 요청 제한
 *
 * 메모리 기반 슬라이딩 윈도우 방식.
 * Edge Function 인스턴스별로 독립적이므로 정확한 전역 제한은 아니지만,
 * 단일 사용자의 과도한 요청을 방지하는 데 충분하다.
 *
 * FR-037: 엔드포인트별 분당 제한
 * - create-link: 5/min (user_id)
 * - match-code: 10/min (IP + user_id)
 * - claim-reward: 5/min (user_id)
 * - report-redemption: 10/min (user_id)
 * - check-status: 20/min (user_id)
 * - get-pending-rewards: 20/min (user_id)
 * - update-device-token: 5/min (user_id)
 */

// 요청 기록 저장소: key → timestamp 배열
const requestLog = new Map<string, number[]>();

// 오래된 엔트리 정리 주기 (5분마다)
const CLEANUP_INTERVAL_MS = 5 * 60 * 1000;
// 슬라이딩 윈도우 크기 (1분)
const WINDOW_MS = 60 * 1000;

let lastCleanup = Date.now();

/**
 * 오래된 요청 기록을 정리한다.
 * 메모리 누수 방지를 위해 주기적으로 호출.
 */
function cleanup(): void {
  const now = Date.now();
  // 정리 주기가 아니면 스킵
  if (now - lastCleanup < CLEANUP_INTERVAL_MS) return;

  lastCleanup = now;
  const cutoff = now - WINDOW_MS;

  for (const [key, timestamps] of requestLog.entries()) {
    // 윈도우 밖의 오래된 타임스탬프 제거
    const filtered = timestamps.filter((t) => t > cutoff);
    if (filtered.length === 0) {
      requestLog.delete(key);
    } else {
      requestLog.set(key, filtered);
    }
  }
}

/**
 * Rate limit을 체크하고, 허용되면 요청을 기록한다.
 *
 * @param key - 제한 기준 키 (예: "create-link:user123", "match-code:192.168.1.1:user456")
 * @param maxRequests - 윈도우 내 최대 허용 요청 수
 * @returns { allowed: true } 또는 { allowed: false, retryAfter: 초 }
 */
export function checkRateLimit(
  key: string,
  maxRequests: number
): { allowed: true } | { allowed: false; retryAfter: number } {
  // 주기적 정리 실행
  cleanup();

  const now = Date.now();
  const cutoff = now - WINDOW_MS;

  // 기존 기록 조회 및 윈도우 내 요청만 필터
  const timestamps = (requestLog.get(key) || []).filter((t) => t > cutoff);

  if (timestamps.length >= maxRequests) {
    // 제한 초과: 가장 오래된 요청이 윈도우를 벗어나는 시점까지 대기
    const oldestInWindow = timestamps[0];
    const retryAfter = Math.ceil((oldestInWindow + WINDOW_MS - now) / 1000);
    return { allowed: false, retryAfter: Math.max(retryAfter, 1) };
  }

  // 허용: 현재 요청 기록 추가
  timestamps.push(now);
  requestLog.set(key, timestamps);
  return { allowed: true };
}

/**
 * 엔드포인트별 rate limit 설정.
 * contracts/api-endpoints.md 기준.
 */
export const RATE_LIMITS: Record<string, number> = {
  "create-link": 5,
  "match-code": 10,
  "claim-reward": 5,
  "report-redemption": 10,
  "check-status": 20,
  "get-pending-rewards": 20,
  "update-device-token": 5,
};

/**
 * 요청에서 클라이언트 IP를 추출한다.
 * Supabase Edge Function 환경에서 x-forwarded-for 또는 x-real-ip 헤더를 확인.
 *
 * @param request - Deno Request 객체
 * @returns IP 문자열 또는 "unknown"
 */
export function getClientIP(request: Request): string {
  // x-forwarded-for: 프록시 체인의 첫 번째 IP가 원본 클라이언트
  const forwarded = request.headers.get("x-forwarded-for");
  if (forwarded) {
    return forwarded.split(",")[0].trim();
  }
  // x-real-ip: 단일 프록시 환경
  const realIP = request.headers.get("x-real-ip");
  if (realIP) {
    return realIP.trim();
  }
  return "unknown";
}

/**
 * Rate limit 초과 시 반환할 JSON 응답을 생성한다.
 *
 * @param retryAfter - 재시도까지 대기 시간(초)
 * @returns Response (HTTP 429)
 */
export function rateLimitResponse(retryAfter: number): Response {
  return new Response(
    JSON.stringify({
      success: false,
      error: "rate_limit_exceeded",
      retry_after: retryAfter,
    }),
    {
      status: 429,
      headers: {
        "Content-Type": "application/json",
        "Retry-After": String(retryAfter),
      },
    }
  );
}

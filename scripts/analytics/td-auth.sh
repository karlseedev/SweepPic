#!/bin/bash
# td-auth.sh — TelemetryDeck Bearer Token 발급 + 캐싱
#
# 용도: 유효한 Bearer Token을 stdout으로 출력
# 다른 스크립트에서: TOKEN=$(./td-auth.sh)
#
# 캐시: /tmp/td-token.json (만료 10분 전 자동 갱신)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
CACHE_FILE="/tmp/td-token.json"

# .env 로드
if [[ ! -f "$ENV_FILE" ]]; then
  echo "ERROR: $ENV_FILE 파일이 없습니다. .env.example을 복사해서 만들어주세요." >&2
  exit 1
fi
source "$ENV_FILE"

# 필수 변수 확인
if [[ -z "${TELEMETRYDECK_EMAIL:-}" || -z "${TELEMETRYDECK_PASSWORD:-}" ]]; then
  echo "ERROR: TELEMETRYDECK_EMAIL, TELEMETRYDECK_PASSWORD가 .env에 필요합니다." >&2
  exit 1
fi

# 캐시된 토큰 확인 (만료 10분 전이면 갱신)
if [[ -f "$CACHE_FILE" ]]; then
  EXPIRES_AT=$(jq -r '.expiresAt // empty' "$CACHE_FILE" 2>/dev/null || true)
  if [[ -n "$EXPIRES_AT" ]]; then
    # ISO 8601 → epoch (BSD date 호환)
    EXPIRES_EPOCH=$(date -j -f "%Y-%m-%dT%H:%M:%S%z" "${EXPIRES_AT}" "+%s" 2>/dev/null || echo "0")
    NOW_EPOCH=$(date "+%s")
    MARGIN=600  # 10분 여유

    if (( EXPIRES_EPOCH - NOW_EPOCH > MARGIN )); then
      # 캐시 유효 → 토큰 출력
      jq -r '.value' "$CACHE_FILE"
      exit 0
    fi
  fi
fi

# 토큰 발급 (Basic Auth)
BASIC_AUTH=$(printf '%s:%s' "$TELEMETRYDECK_EMAIL" "$TELEMETRYDECK_PASSWORD" | base64)

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "https://api.telemetrydeck.com/api/v3/users/login" \
  -H "Authorization: Basic $BASIC_AUTH" \
  -H "Content-Length: 0")

HTTP_CODE=$(echo "$RESPONSE" | tail -1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [[ "$HTTP_CODE" != "200" ]]; then
  echo "ERROR: 토큰 발급 실패 (HTTP $HTTP_CODE)" >&2
  echo "$BODY" >&2
  exit 1
fi

# 캐싱
echo "$BODY" > "$CACHE_FILE"

# 토큰 출력
echo "$BODY" | jq -r '.value'

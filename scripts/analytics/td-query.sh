#!/bin/bash
# td-query.sh — TelemetryDeck 비동기 3단계 쿼리 실행
#
# 사용법:
#   ./td-query.sh queries/app-launched.json              # 기본 7일
#   ./td-query.sh queries/app-launched.json --days 30    # 30일
#   ./td-query.sh queries/app-launched.json --test-mode  # 테스트 데이터 포함
#   echo '{"queryType":...}' | ./td-query.sh             # stdin

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
API_BASE="https://api.telemetrydeck.com"
POLL_INTERVAL=2
POLL_TIMEOUT=30

# jq 확인
if ! command -v jq &>/dev/null; then
  echo "ERROR: jq가 필요합니다. brew install jq" >&2
  exit 1
fi

# .env 로드 (APP_ID용)
if [[ -f "$ENV_FILE" ]]; then
  source "$ENV_FILE"
fi
APP_ID="${TELEMETRYDECK_APP_ID:-}"
if [[ -z "$APP_ID" ]]; then
  echo "ERROR: TELEMETRYDECK_APP_ID가 .env에 필요합니다." >&2
  exit 1
fi

# 인자 파싱
DAYS=7
TEST_MODE="false"
QUERY_FILE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --days)   DAYS="$2"; shift 2 ;;
    --test-mode) TEST_MODE="true"; shift ;;
    *)        QUERY_FILE="$1"; shift ;;
  esac
done

# 쿼리 JSON 읽기 (파일 or stdin)
if [[ -n "$QUERY_FILE" ]]; then
  if [[ ! -f "$QUERY_FILE" ]]; then
    echo "ERROR: 파일을 찾을 수 없습니다: $QUERY_FILE" >&2
    exit 2
  fi
  QUERY_JSON=$(cat "$QUERY_FILE")
else
  QUERY_JSON=$(cat -)
fi

# relativeIntervals 주입
QUERY_JSON=$(echo "$QUERY_JSON" | jq --argjson days "$DAYS" '
  .relativeIntervals = [{
    "beginningDate": { "component": "day", "offset": (-$days), "position": "beginning" },
    "endDate":       { "component": "day", "offset": 0, "position": "end" }
  }]
')

# appID + isTestMode 필터 래핑
QUERY_JSON=$(echo "$QUERY_JSON" | jq \
  --arg appID "$APP_ID" \
  --arg testMode "$TEST_MODE" '
  .filter = {
    "type": "and",
    "fields": [
      .filter,
      { "type": "selector", "dimension": "appID", "value": $appID },
      { "type": "selector", "dimension": "isTestMode", "value": $testMode }
    ]
  }
')

# 1. 토큰 획득
TOKEN=$("$SCRIPT_DIR/td-auth.sh")
if [[ -z "$TOKEN" ]]; then
  echo "ERROR: 토큰 발급 실패" >&2
  exit 1
fi

# 2. 쿼리 제출
SUBMIT_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST \
  "$API_BASE/api/v3/query/calculate-async/" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "$QUERY_JSON")

SUBMIT_CODE=$(echo "$SUBMIT_RESPONSE" | tail -1)
SUBMIT_BODY=$(echo "$SUBMIT_RESPONSE" | sed '$d')

if [[ "$SUBMIT_CODE" != "200" && "$SUBMIT_CODE" != "202" ]]; then
  echo "ERROR: 쿼리 제출 실패 (HTTP $SUBMIT_CODE)" >&2
  echo "$SUBMIT_BODY" >&2
  exit 2
fi

TASK_ID=$(echo "$SUBMIT_BODY" | jq -r '.queryTaskID // empty')
if [[ -z "$TASK_ID" ]]; then
  echo "ERROR: queryTaskID를 받지 못했습니다" >&2
  echo "$SUBMIT_BODY" >&2
  exit 2
fi

# 3. 상태 폴링
ELAPSED=0
while (( ELAPSED < POLL_TIMEOUT )); do
  sleep "$POLL_INTERVAL"
  ELAPSED=$((ELAPSED + POLL_INTERVAL))

  STATUS_BODY=$(curl -s \
    "$API_BASE/api/v3/task/$TASK_ID/status/" \
    -H "Authorization: Bearer $TOKEN")

  STATUS=$(echo "$STATUS_BODY" | jq -r '.status // empty')

  case "$STATUS" in
    successful) break ;;
    failed)
      echo "ERROR: 쿼리 실패" >&2
      echo "$STATUS_BODY" >&2
      exit 4
      ;;
    running|"") ;; # 계속 폴링
    *)
      echo "ERROR: 알 수 없는 상태: $STATUS" >&2
      exit 4
      ;;
  esac
done

if [[ "$STATUS" != "successful" ]]; then
  echo "ERROR: 쿼리 타임아웃 (${POLL_TIMEOUT}초)" >&2
  exit 3
fi

# 4. 결과 조회
curl -s \
  "$API_BASE/api/v3/task/$TASK_ID/value/" \
  -H "Authorization: Bearer $TOKEN"

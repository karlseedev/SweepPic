#!/bin/bash
# sb-query.sh — Supabase PostgREST 조회 + RPC 호출
#
# 사용법:
#   ./sb-query.sh --table events --limit 10
#   ./sb-query.sh --table events --filter "event_name=eq.session.errors" --limit 20
#   ./sb-query.sh --rpc daily_summary '{"p_days": 30}'
#   ./sb-query.sh --rpc delete_restore_summary '{"p_days": 7}'
#   ./sb-query.sh --rpc purge_old_events '{"p_retention_days": 90}'
#
# 참조: docs/db/260217db-hybrid.md Phase 4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# .env 파일 로드
if [[ ! -f "$ENV_FILE" ]]; then
    echo "Error: .env 파일이 없습니다. .env.example을 복사하세요:"
    echo "  cp $SCRIPT_DIR/.env.example $SCRIPT_DIR/.env"
    exit 1
fi
source "$ENV_FILE"

# 필수 변수 확인
if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_SERVICE_KEY:-}" ]]; then
    echo "Error: SUPABASE_URL, SUPABASE_SERVICE_KEY가 .env에 설정되어야 합니다."
    exit 1
fi

# service_role key 사용 (RLS 우회하여 SELECT 가능)
AUTH_HEADER="Bearer $SUPABASE_SERVICE_KEY"

# 인자 파싱
MODE=""
TABLE=""
FILTER=""
LIMIT="50"
RPC_NAME=""
RPC_BODY="{}"
ORDER="created_at.desc"
SELECT="*"

while [[ $# -gt 0 ]]; do
    case "$1" in
        --table)
            MODE="table"
            TABLE="$2"
            shift 2
            ;;
        --filter)
            FILTER="$2"
            shift 2
            ;;
        --limit)
            LIMIT="$2"
            shift 2
            ;;
        --order)
            ORDER="$2"
            shift 2
            ;;
        --select)
            SELECT="$2"
            shift 2
            ;;
        --rpc)
            MODE="rpc"
            RPC_NAME="$2"
            if [[ $# -ge 3 && ! "$3" =~ ^-- ]]; then
                RPC_BODY="$3"
                shift 3
            else
                shift 2
            fi
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

if [[ -z "$MODE" ]]; then
    echo "Usage:"
    echo "  $0 --table <table_name> [--filter <filter>] [--limit <n>] [--order <col.dir>] [--select <cols>]"
    echo "  $0 --rpc <function_name> ['{\"param\": value}']"
    echo ""
    echo "Examples:"
    echo "  $0 --table events --limit 10"
    echo "  $0 --table events --filter 'event_name=eq.app.launched' --limit 5"
    echo "  $0 --rpc daily_summary '{\"p_days\": 7}'"
    exit 0
fi

if [[ "$MODE" == "table" ]]; then
    # PostgREST REST API 조회
    URL="${SUPABASE_URL}/rest/v1/${TABLE}?select=${SELECT}&order=${ORDER}&limit=${LIMIT}"
    if [[ -n "$FILTER" ]]; then
        URL="${URL}&${FILTER}"
    fi

    curl -s "$URL" \
        -H "apikey: $SUPABASE_SERVICE_KEY" \
        -H "Authorization: $AUTH_HEADER" \
        -H "Accept: application/json" \
        | python3 -m json.tool 2>/dev/null || echo "(JSON 파싱 실패 — 원본 출력)"

elif [[ "$MODE" == "rpc" ]]; then
    # RPC 함수 호출
    URL="${SUPABASE_URL}/rest/v1/rpc/${RPC_NAME}"

    curl -s "$URL" \
        -X POST \
        -H "apikey: $SUPABASE_SERVICE_KEY" \
        -H "Authorization: $AUTH_HEADER" \
        -H "Content-Type: application/json" \
        -H "Accept: application/json" \
        -d "$RPC_BODY" \
        | python3 -m json.tool 2>/dev/null || echo "(JSON 파싱 실패 — 원본 출력)"
fi

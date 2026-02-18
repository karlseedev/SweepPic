#!/bin/bash
# sb-report.sh — Supabase 리포트 생성
#
# 사용법:
#   ./sb-report.sh                 # 기본 7일
#   ./sb-report.sh --days 30       # 30일
#
# 출력: daily_summary + delete_restore_summary + 총 이벤트 수
# 참조: docs/db/260217db-hybrid.md Phase 4

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
DAYS=7

while [[ $# -gt 0 ]]; do
    case "$1" in
        --days)
            DAYS="$2"
            shift 2
            ;;
        *)
            echo "Usage: $0 [--days <n>]"
            exit 1
            ;;
    esac
done

echo "═══════════════════════════════════════"
echo " Supabase Analytics Report (${DAYS}일)"
echo "═══════════════════════════════════════"
echo ""

echo "── 1. 일별 이벤트 요약 ──"
"$SCRIPT_DIR/sb-query.sh" --rpc daily_summary "{\"p_days\": $DAYS}"
echo ""

echo "── 2. 삭제/복원 상세 분석 ──"
"$SCRIPT_DIR/sb-query.sh" --rpc delete_restore_summary "{\"p_days\": $DAYS}"
echo ""

echo "── 3. 최근 이벤트 (10건) ──"
"$SCRIPT_DIR/sb-query.sh" --table events --limit 10 --select "id,event_name,created_at,photo_bucket"
echo ""

echo "── 4. 이벤트별 총 건수 (${DAYS}일) ──"
"$SCRIPT_DIR/sb-query.sh" --table events \
    --select "event_name" \
    --limit 100
echo ""
echo "═══════════════════════════════════════"
echo " 리포트 완료"
echo "═══════════════════════════════════════"

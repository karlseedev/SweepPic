#!/bin/bash
# Analytics Test B: 실기기 XCUITest E2E 검증
#
# 사용법:
#   ./verify-test-b.sh [TEST_START]   # 자동 테스트 검증 (시작 시각 인자 선택)
#   ./verify-test-b.sh --manual       # 수동 테스트 검증 (cleanup 이벤트만 확인)
#
# TEST_START 예시: 2026-02-26T07:30:00Z (run-test-b.sh에서 자동 전달)

set -euo pipefail

source "$(dirname "$0")/.env"

BASE="$SUPABASE_URL/rest/v1/events"
AUTH=(-H "apikey: $SUPABASE_SERVICE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_KEY")

# --manual 모드: cleanup 이벤트만 확인 (자동 항목 실행 안 함)
if [ "${1:-}" = "--manual" ]; then
    SINCE=$(date -u -v-5M '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
         || date -u -d '5 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')
    PASS=0; FAIL=0

    # cleanup 이벤트 존재 확인 + 파라미터 출력
    check_exists_and_dump() {
        local event="$1"
        local raw
        raw=$(curl -fsS "$BASE?event_name=eq.$event&created_at=gte.$SINCE&order=created_at.desc&limit=1" \
          "${AUTH[@]}" 2>&1) || { printf "  ❌ %-40s FETCH ERROR\n" "$event"; FAIL=$((FAIL+1)); return; }
        if [ "$(echo "$raw" | jq 'length')" -eq 0 ]; then
            printf "  ❌ %-40s 미존재\n" "$event"; FAIL=$((FAIL+1)); return
        fi
        printf "  ✅ %-40s 존재\n" "$event"; PASS=$((PASS+1))
        echo "$raw" | jq '.[0].params' | sed 's/^/     /'
    }

    echo "=== 수동 테스트: 정리 이벤트 확인 ==="
    echo "    (cleanup 이벤트는 즉시 전송 — Home 버튼은 전송 완료 안정화용)"
    echo "    조회 범위: $SINCE 이후"
    echo ""
    echo "[cleanup.completed]"; check_exists_and_dump "cleanup.completed"
    echo ""; echo "[cleanup.previewCompleted]"; check_exists_and_dump "cleanup.previewCompleted"
    echo ""
    echo "결과: $PASS 통과 / $FAIL 실패"
    [ "$FAIL" -eq 0 ] && exit 0 || exit 1
fi

# 자동 테스트 모드: 시작 시각 인자 또는 기본값(2분 전) 사용
# run-test-b.sh에서 TEST_START를 전달해 오검출 방지
if [ -n "${1:-}" ]; then
    SINCE="$1"
else
    SINCE=$(date -u -v-2M '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
         || date -u -d '2 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')
fi

PASS=0; FAIL=0

# Supabase 단건 조회
sb_fetch() {
    local event="$1"
    local raw
    raw=$(curl -fsS "$BASE?event_name=eq.$event&created_at=gte.$SINCE&order=created_at.desc&limit=1" \
      "${AUTH[@]}" 2>&1) || { echo "FETCH_ERROR"; return; }
    if echo "$raw" | jq -e 'if type == "array" then true else false end' >/dev/null 2>&1; then
        echo "$raw"
    else
        echo "FETCH_ERROR"
    fi
}

# 정확한 값 비교
check() {
    local event="$1" key="$2" expected="$3"
    local data actual
    data=$(sb_fetch "$event")
    if [ "$data" = "FETCH_ERROR" ]; then
        printf "  ❌ %-40s FETCH ERROR\n" "$event.$key"
        FAIL=$((FAIL + 1)); return
    fi
    actual=$(echo "$data" | jq -r ".[0].params.\"$key\" // empty")
    if [ "$actual" = "$expected" ]; then
        printf "  ✅ %-40s = %s\n" "$event.$key" "$actual"
        PASS=$((PASS + 1))
    else
        printf "  ❌ %-40s = %s (기대: %s)\n" "$event.$key" "${actual:-NULL}" "$expected"
        FAIL=$((FAIL + 1))
    fi
}

# N 이상 비교 (≥)
check_gte() {
    local event="$1" key="$2" min="$3"
    local data actual
    data=$(sb_fetch "$event")
    if [ "$data" = "FETCH_ERROR" ]; then
        printf "  ❌ %-40s FETCH ERROR\n" "$event.$key"
        FAIL=$((FAIL + 1)); return
    fi
    actual=$(echo "$data" | jq -r ".[0].params.\"$key\" // empty")
    if [ -n "$actual" ] && [ "$actual" -ge "$min" ] 2>/dev/null; then
        printf "  ✅ %-40s = %s (≥ %s)\n" "$event.$key" "$actual" "$min"
        PASS=$((PASS + 1))
    else
        printf "  ❌ %-40s = %s (기대: ≥ %s)\n" "$event.$key" "${actual:-NULL}" "$min"
        FAIL=$((FAIL + 1))
    fi
}

# Supabase 전송 완료 대기 (최대 30초 polling)
echo "=== Supabase 전송 완료 대기 중 (최대 30초) ==="
for i in $(seq 1 6); do
    COUNT=$(curl -fsS "$BASE?event_name=eq.session.photoViewing&created_at=gte.$SINCE&limit=1" \
      "${AUTH[@]}" 2>/dev/null | jq 'length' 2>/dev/null || echo 0)
    if [ "$COUNT" -gt 0 ]; then
        echo "  데이터 수신 확인 (${i}번째 시도, $((i * 5))초)"
        break
    fi
    echo "  대기 중... (${i}/6, $((i * 5))초)"
    sleep 5
done

echo ""
echo "=== Analytics Test B: 실기기 E2E 검증 ==="
echo "    조회 범위: $SINCE 이후"
echo ""

echo "[session.photoViewing]"
check "session.photoViewing" "total"       "9"
check "session.photoViewing" "fromLibrary" "8"
check "session.photoViewing" "fromAlbum"   "0"
check "session.photoViewing" "fromTrash"   "1"

echo ""
echo "[session.deleteRestore]"
check "session.deleteRestore" "gridSwipeDelete"     "4"
check "session.deleteRestore" "gridSwipeRestore"    "0"
check "session.deleteRestore" "viewerSwipeDelete"   "2"
check "session.deleteRestore" "viewerTrashButton"   "3"
check "session.deleteRestore" "viewerRestoreButton" "3"
check "session.deleteRestore" "fromLibrary"         "9"
check "session.deleteRestore" "fromAlbum"           "0"

echo ""
echo "[session.trashViewer]"
check "session.trashViewer" "permanentDelete" "2"
check "session.trashViewer" "restore"         "3"

echo ""
echo "[similar.groupClosed]"
check "similar.groupClosed" "totalCount"   "5"
check "similar.groupClosed" "deletedCount" "2"

echo ""
echo "[session.similarAnalysis]"
check_gte "session.similarAnalysis" "completedCount" "1"
check_gte "session.similarAnalysis" "totalGroups"    "1"

echo ""
echo "======================================="
echo "  결과: $PASS 통과 / $FAIL 실패 (총 $((PASS + FAIL)) 항목)"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1

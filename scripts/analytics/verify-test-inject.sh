#!/bin/bash
# Analytics Test A 검증: Supabase에 도착한 값 vs 배정표 비교

set -euo pipefail
source "$(dirname "$0")/.env"

SINCE=$(date -u -v-2M '+%Y-%m-%dT%H:%M:%SZ' 2>/dev/null \
     || date -u -d '2 minutes ago' '+%Y-%m-%dT%H:%M:%SZ')

BASE="$SUPABASE_URL/rest/v1/events"
AUTH=(-H "apikey: $SUPABASE_SERVICE_KEY" -H "Authorization: Bearer $SUPABASE_SERVICE_KEY")

PASS=0
FAIL=0

sb_fetch() {
    local response
    response=$(curl -fsS "$1" "${AUTH[@]}" 2>&1) || {
        echo "  API 호출 실패: $1"
        echo "  $response"
        return 1
    }
    echo "$response"
}

check() {
    local event="$1" key="$2" expected="$3"
    local actual response
    response=$(sb_fetch "$BASE?event_name=eq.$event&created_at=gte.$SINCE&order=created_at.desc&limit=1") || {
        FAIL=$((FAIL + 1)); return
    }
    actual=$(echo "$response" | jq -r ".[0].params.\"$key\" // empty")

    if [ "$actual" = "$expected" ]; then
        printf "  [PASS] %-35s = %s\n" "$event.$key" "$actual"
        PASS=$((PASS + 1))
    else
        printf "  [FAIL] %-35s = %s (기대: %s)\n" "$event.$key" "${actual:-NULL}" "$expected"
        FAIL=$((FAIL + 1))
    fi
}

check_exists() {
    local event="$1"
    local count response
    response=$(sb_fetch "$BASE?event_name=eq.$event&created_at=gte.$SINCE&limit=1") || {
        FAIL=$((FAIL + 1)); return
    }
    count=$(echo "$response" | jq 'if type == "array" then length else 0 end')

    if [ "$count" -gt 0 ]; then
        printf "  [PASS] %-35s 존재\n" "$event"
        PASS=$((PASS + 1))
    else
        printf "  [FAIL] %-35s 미존재\n" "$event"
        FAIL=$((FAIL + 1))
    fi
}

check_absent() {
    local event="$1"
    local count response
    response=$(sb_fetch "$BASE?event_name=eq.$event&created_at=gte.$SINCE&limit=1") || {
        FAIL=$((FAIL + 1)); return
    }
    count=$(echo "$response" | jq 'if type == "array" then length else 0 end')

    if [ "$count" -eq 0 ]; then
        printf "  [PASS] %-35s Supabase 미전송 확인\n" "$event"
        PASS=$((PASS + 1))
    else
        printf "  [FAIL] %-35s Supabase에 존재 (제외 대상인데 전송됨!)\n" "$event"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Analytics Test A: 코드 주입 검증 ==="
echo "    조회 범위: $SINCE 이후"
echo ""

echo "[즉시 전송 이벤트]"
check_exists "app.launched"
check "similar.groupClosed"         "totalCount"          "12"
check "similar.groupClosed"         "deletedCount"        "5"
check "cleanup.completed"           "reachedStage"        "cleanupDone"
check "cleanup.completed"           "trashWarningShown"   "true"
check "cleanup.completed"           "foundCount"          "23"
check "cleanup.completed"           "durationSec"         "45.3"
check "cleanup.completed"           "method"              "fromLatest"
check "cleanup.completed"           "result"              "completed"
check "cleanup.previewCompleted"    "reachedStage"        "finalAction"
check "cleanup.previewCompleted"    "foundCount"          "15"
check "cleanup.previewCompleted"    "durationSec"         "28.7"
check "cleanup.previewCompleted"    "maxStageReached"     "standard"
check "cleanup.previewCompleted"    "expandCount"         "4"
check "cleanup.previewCompleted"    "excludeCount"        "2"
check "cleanup.previewCompleted"    "viewerOpenCount"     "3"
check "cleanup.previewCompleted"    "finalAction"         "moveToTrash"
check "cleanup.previewCompleted"    "movedCount"          "11"

echo ""
echo "[세션 카운터]"
check "session.photoViewing"        "total"               "17"
check "session.photoViewing"        "fromLibrary"         "10"
check "session.photoViewing"        "fromAlbum"           "5"
check "session.photoViewing"        "fromTrash"           "2"
check "session.deleteRestore"       "gridSwipeDelete"     "9"
check "session.deleteRestore"       "gridSwipeRestore"    "3"
check "session.deleteRestore"       "viewerSwipeDelete"   "7"
check "session.deleteRestore"       "viewerTrashButton"   "4"
check "session.deleteRestore"       "viewerRestoreButton" "2"
check "session.deleteRestore"       "fromLibrary"         "14"
check "session.deleteRestore"       "fromAlbum"           "11"
check "session.trashViewer"         "permanentDelete"     "6"
check "session.trashViewer"         "restore"             "8"
check "session.similarAnalysis"     "completedCount"      "3"
check "session.similarAnalysis"     "cancelledCount"      "1"
check "session.similarAnalysis"     "totalGroups"         "11"
check "session.similarAnalysis"     "avgDurationSec"      "4.7"
check "session.errors"              "photoLoad.gridThumbnail" "5"
check "session.errors"              "face.detection"      "2"
check "session.errors"              "cleanup.trashMove"   "1"

echo ""
echo "[Supabase 제외 확인 (음성 테스트)]"
check_absent "permission.result"
check_absent "session.gridPerformance"

echo ""
echo "======================================="
echo "  결과: $PASS 통과 / $FAIL 실패 (총 $((PASS + FAIL)) 항목)"
echo "======================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1

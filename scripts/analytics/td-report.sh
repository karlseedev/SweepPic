#!/bin/bash
# td-report.sh — PickPhoto 주간 리포트
#
# 사용법:
#   ./td-report.sh              # 기본 7일
#   ./td-report.sh --days 30    # 30일
#   ./td-report.sh --test-mode  # 테스트 데이터 포함

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
QUERY_DIR="$SCRIPT_DIR/queries"
RESULT_DIR="/tmp/td-results"
ARGS=("$@")

# 기간 추출 (기본 7일)
DAYS=7
for i in "${!ARGS[@]}"; do
  if [[ "${ARGS[$i]}" == "--days" ]]; then
    DAYS="${ARGS[$((i+1))]}"
  fi
done

# 결과 디렉토리 준비
rm -rf "$RESULT_DIR"
mkdir -p "$RESULT_DIR"

# 쿼리 실행 (순차)
QUERIES=(
  "app-launched"
  "photo-viewing"
  "delete-restore"
  "trash-viewer"
  "similar-analysis"
  "errors"
  "cleanup"
  "preview-cleanup"
)

FAILED=0
for q in "${QUERIES[@]}"; do
  echo "  조회 중: $q ..." >&2
  if "$SCRIPT_DIR/td-query.sh" "$QUERY_DIR/$q.json" "${ARGS[@]}" > "$RESULT_DIR/$q.json" 2>/dev/null; then
    :
  else
    echo "  ⚠ $q 쿼리 실패" >&2
    FAILED=$((FAILED + 1))
  fi
done

# 날짜 계산
END_DATE=$(date "+%Y-%m-%d")
START_DATE=$(date -v-${DAYS}d "+%Y-%m-%d")

# 결과 추출 함수: timeseries 결과에서 합산
ts_sum() {
  local file="$1" field="$2"
  jq -r ".result.rows[]?.result?.$field // 0" "$file" 2>/dev/null | awk '{s+=$1} END {printf "%d", s}'
}

# 결과 추출 함수: timeseries 단일 결과 (granularity: all)
ts_val() {
  local file="$1" field="$2"
  jq -r ".result.rows[0]?.result?.$field // 0" "$file" 2>/dev/null
}

# 핵심 지표
LAUNCHES=$(ts_sum "$RESULT_DIR/app-launched.json" "launchCount")
VIEWS=$(ts_sum "$RESULT_DIR/photo-viewing.json" "totalViews")
DELETES=$(ts_sum "$RESULT_DIR/delete-restore.json" "gridSwipeDelete")
RESTORES=$(ts_sum "$RESULT_DIR/delete-restore.json" "gridSwipeRestore")
VIEWER_DEL=$(ts_sum "$RESULT_DIR/delete-restore.json" "viewerSwipeDelete")
VIEWER_TRASH=$(ts_sum "$RESULT_DIR/delete-restore.json" "viewerTrashButton")
VIEWER_RESTORE=$(ts_sum "$RESULT_DIR/delete-restore.json" "viewerRestoreButton")
PERM_DELETE=$(ts_sum "$RESULT_DIR/trash-viewer.json" "permanentDelete")
TRASH_RESTORE=$(ts_sum "$RESULT_DIR/trash-viewer.json" "restore")

# 오류 현황
ERROR_SESSIONS=$(ts_val "$RESULT_DIR/errors.json" "errorSessions")
ERROR_ITEMS=(
  "photoLoad_gridThumbnail:사진 썸네일 로딩"
  "photoLoad_viewerOriginal:뷰어 원본 로딩"
  "face_detection:얼굴 감지"
  "face_embedding:얼굴 임베딩"
  "cleanup_startFail:정리 시작"
  "cleanup_imageLoad:정리 이미지 로드"
  "cleanup_trashMove:휴지통 이동"
  "video_frameExtract:동영상 프레임"
  "video_iCloudSkip:iCloud 동영상"
  "storage_diskSpace:디스크 공간"
  "storage_thumbnailCache:캐시 저장"
  "storage_trashData:휴지통 데이터"
)

# 리포트 출력
cat <<EOF
# PickPhoto 리포트 ($START_DATE ~ $END_DATE)

## 핵심 지표
| 지표 | 값 |
|------|-----|
| 앱 실행 | ${LAUNCHES}회 |
| 사진 열람 | ${VIEWS}장 |
| 그리드 삭제 | ${DELETES}건 |
| 그리드 복구 | ${RESTORES}건 |
| 뷰어 스와이프 삭제 | ${VIEWER_DEL}건 |
| 뷰어 휴지통 버튼 | ${VIEWER_TRASH}건 |
| 뷰어 복구 버튼 | ${VIEWER_RESTORE}건 |
| 완전삭제 | ${PERM_DELETE}건 |
| 휴지통 복구 | ${TRASH_RESTORE}건 |

## 정리 기능 (퍼널)
EOF

# cleanup groupBy 결과 파싱
if [[ -f "$RESULT_DIR/cleanup.json" ]]; then
  echo "| 단계 | 도달 수 |"
  echo "|------|--------|"
  jq -r '.result.rows[]? | "| \(.event.reachedStage // "unknown") | \(.event.count // 0) |"' \
    "$RESULT_DIR/cleanup.json" 2>/dev/null || echo "| (데이터 없음) | - |"
else
  echo "(쿼리 실패)"
fi

cat <<EOF

## 오류 현황 (에러 세션 ${ERROR_SESSIONS}건)
| 오류 | 발생 수 |
|------|--------|
EOF

# 에러 항목 출력 (0이 아닌 것만)
HAS_ERRORS=false
for item in "${ERROR_ITEMS[@]}"; do
  KEY="${item%%:*}"
  LABEL="${item##*:}"
  VAL=$(ts_val "$RESULT_DIR/errors.json" "$KEY")
  if [[ "$VAL" != "0" && "$VAL" != "null" && -n "$VAL" ]]; then
    echo "| $LABEL | ${VAL}건 |"
    HAS_ERRORS=true
  fi
done
if [[ "$HAS_ERRORS" == "false" ]]; then
  echo "| (없음) | - |"
fi

echo ""
echo "---"
echo "조회 기간: ${DAYS}일 / 쿼리 ${#QUERIES[@]}건 (실패 ${FAILED}건) / 생성: $(date '+%Y-%m-%d %H:%M')"

#!/bin/bash
# Analytics Test A (실기기): 코드 주입 → flush → 검증
#
# 사용 예시:
#   DEVICE_NAME="iPhone 13Pro128" ./scripts/analytics/run-test-inject-device.sh
#   DEVICE_ID="00008110-00041DDC212A801E" ./scripts/analytics/run-test-inject-device.sh

set -euo pipefail
cd "$(dirname "$0")/../.."  # 프로젝트 루트

BUNDLE_ID="com.karl.SweepPic"
DEVICE_NAME="${DEVICE_NAME:-iPhone 13Pro128}"
DEVICE_ID="${DEVICE_ID:-}"

if [ -z "$DEVICE_ID" ]; then
  echo "=== Step 0: 실기기 대상 확인 ==="
  DEVICE_ID=$(
    xcodebuild -showdestinations \
      -project SweepPic/SweepPic.xcodeproj \
      -scheme SweepPic 2>/dev/null \
      | awk -v name="$DEVICE_NAME" '
          index($0, "platform:iOS") && index($0, "name:" name) {
            line = $0
            sub(/^.*id:/, "", line)
            sub(/,.*/, "", line)
            gsub(/^[[:space:]]+|[[:space:]]+$/, "", line)
            print line
            exit
          }
        '
  )
fi

if [ -z "$DEVICE_ID" ]; then
  echo "실기기 destination ID를 찾지 못했습니다."
  echo "DEVICE_ID를 직접 지정하시거나 DEVICE_NAME을 확인해 주세요."
  exit 1
fi

echo "대상 기기: ${DEVICE_NAME} (id=$DEVICE_ID)"
echo "전제: 기기 사진 권한 전체 허용 상태여야 합니다."

echo ""
echo "=== Step 1: 빌드 (실기기) ==="
xcodebuild build \
  -project SweepPic/SweepPic.xcodeproj \
  -scheme SweepPic \
  -destination "id=$DEVICE_ID" \
  -configuration Debug

APP_PATH=$(
  xcodebuild -showBuildSettings \
    -project SweepPic/SweepPic.xcodeproj \
    -scheme SweepPic \
    -destination "id=$DEVICE_ID" \
    -configuration Debug 2>/dev/null \
    | awk '/^[[:space:]]*TARGET_BUILD_DIR = /{dir=$3} /^[[:space:]]*FULL_PRODUCT_NAME = /{name=$3} END{if(dir&&name) print dir "/" name; else exit 1}'
)

echo ""
echo "=== Step 2: 실기기 설치 ==="
xcrun devicectl device install app --device "$DEVICE_ID" "$APP_PATH"

echo ""
echo "=== Step 3: 앱 실행 (테스트 주입 모드) ==="
xcrun devicectl device process launch \
  --device "$DEVICE_ID" \
  --terminate-existing \
  "$BUNDLE_ID" \
  --analytics-test-inject

echo ""
echo "=== Step 4: 전송 완료 대기 (12초) ==="
sleep 12

echo ""
echo "=== Step 5: 검증 ==="
scripts/analytics/verify-test-inject.sh

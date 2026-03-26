#!/bin/bash
# 셀 탭 단독 진단 테스트
set -euo pipefail
cd "$(dirname "$0")/../.."

DEVICE_ID="00008110-00041DDC212A801E"
DEVICE_NAME="iPhone 13Pro128"

echo "=== 기기 연결 확인 ==="
xcrun xctrace list devices 2>&1 | grep "$DEVICE_NAME" || {
    echo "❌ $DEVICE_NAME 미연결."
    exit 1
}
echo "✅ $DEVICE_NAME 연결"

echo ""
echo "=== testCellTapDiag 단독 실행 ==="
xcodebuild test \
  -project SweepPic/SweepPic.xcodeproj \
  -scheme SweepPic \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -configuration Debug \
  -allowProvisioningUpdates \
  -skip-testing:SweepPicTests \
  -only-testing:SweepPicUITests/AnalyticsUITest/testCellTapDiag \
  2>&1

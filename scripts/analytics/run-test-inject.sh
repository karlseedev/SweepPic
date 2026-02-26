#!/bin/bash
# Analytics Test A: 코드 주입 → flush → 검증

set -euo pipefail
cd "$(dirname "$0")/../.."  # 프로젝트 루트

BUNDLE_ID="com.karl.PickPhoto"
SIMULATOR="iPhone 16"

echo "=== Step 1: 빌드 + 설치 ==="
xcodebuild build \
  -project PickPhoto/PickPhoto.xcodeproj \
  -scheme PickPhoto \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -configuration Debug

APP_PATH=$(xcodebuild -showBuildSettings \
  -project PickPhoto/PickPhoto.xcodeproj \
  -scheme PickPhoto \
  -destination "platform=iOS Simulator,name=$SIMULATOR" \
  -configuration Debug 2>/dev/null \
  | grep -m1 "BUILT_PRODUCTS_DIR" | awk '{print $3}')

echo ""
echo "=== Step 2: 시뮬레이터 준비 ==="
xcrun simctl boot "$SIMULATOR" 2>/dev/null || true
xcrun simctl bootstatus booted -b
xcrun simctl install booted "$APP_PATH/PickPhoto.app"
xcrun simctl privacy booted grant photos "$BUNDLE_ID"

echo ""
echo "=== Step 3: 앱 실행 (테스트 주입 모드) ==="
xcrun simctl terminate booted "$BUNDLE_ID" 2>/dev/null || true
xcrun simctl launch booted "$BUNDLE_ID" --analytics-test-inject

echo ""
echo "=== Step 4: 전송 완료 대기 (12초) ==="
sleep 12

echo ""
echo "=== Step 5: 검증 ==="
scripts/analytics/verify-test-inject.sh

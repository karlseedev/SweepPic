#!/bin/bash
# Analytics Test B: 실기기 XCUITest E2E → Supabase 검증
#
# 사전 조건 (docs/db/260226testB.md 섹션 2 참조):
#   - iPhone 13 Pro USB 연결
#   - 일반 사진 15장 + 같은 인물 셀카 5장 준비 (셀카를 마지막에 저장)
#   - 앱 사진 권한: 설정 → PickPhoto → 사진 → "모든 사진"
#   - 코치마크 완료 상태
#
# 사용법:
#   ./scripts/analytics/run-test-b.sh

set -euo pipefail
cd "$(dirname "$0")/../.."  # 프로젝트 루트

DEVICE_ID="00008110-00041DDC212A801E"
DEVICE_NAME="iPhone 13Pro128"

# 테스트 시작 시각 캡처 (verify에 전달해 오검출 방지)
TEST_START=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

echo "=== Step 1: 기기 연결 확인 ==="
xcrun xctrace list devices 2>&1 | grep "$DEVICE_NAME" || {
    echo "❌ $DEVICE_NAME 미연결. USB 연결 확인 필요."
    exit 1
}
echo "✅ $DEVICE_NAME 연결 확인"

echo ""
echo "=== Step 2: 빌드 + 테스트 실행 (TEST_START: $TEST_START) ==="
xcodebuild test \
  -project PickPhoto/PickPhoto.xcodeproj \
  -scheme PickPhoto \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -configuration Debug \
  -allowProvisioningUpdates \
  -skip-testing:PickPhotoTests \
  -only-testing:PickPhotoUITests/AnalyticsUITest/testAnalyticsCounters \
  2>&1 | tail -30

echo ""
echo "=== Step 3: Supabase 검증 (시작 시각 기준) ==="
# 테스트 시작 시각을 verify에 전달 → "최근 2분" 대신 정확한 기준으로 오검출 방지
scripts/analytics/verify-test-b.sh "$TEST_START"

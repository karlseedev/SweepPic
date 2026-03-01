#!/bin/bash
# Analytics Test B: 실기기 XCUITest E2E → Phase별 개별 실행
#
# 사전 조건 (docs/db/260226testB.md 섹션 2 참조):
#   - iPhone 13 Pro USB 연결
#   - 일반 사진 15장 + 같은 인물 셀카 5장 준비 (셀카를 마지막에 저장)
#   - 앱 사진 권한: 설정 → PickPhoto → 사진 → "모든 사진"
#   - 코치마크 완료 상태
#
# 사용법:
#   ./scripts/analytics/run-test-b.sh              # 전체 테스트 (testAllPhases)
#   ./scripts/analytics/run-test-b.sh 1            # Phase 1만 (유사 사진)
#   ./scripts/analytics/run-test-b.sh 2            # Phase 2만 (사진 열람)
#   ./scripts/analytics/run-test-b.sh 3            # Phase 3만 (뷰어 삭제)
#   ./scripts/analytics/run-test-b.sh 4            # Phase 4만 (그리드 삭제)
#   ./scripts/analytics/run-test-b.sh 5            # Phase 5만 (삭제대기함)
#   ./scripts/analytics/run-test-b.sh 6            # Phase 6만 (앨범 열람)

set -euo pipefail
cd "$(dirname "$0")/../.."  # 프로젝트 루트

DEVICE_ID="00008110-00041DDC212A801E"
DEVICE_NAME="iPhone 13Pro128"

# Phase 번호에 따라 테스트 메서드 결정
PHASE="${1:-all}"
case "$PHASE" in
    1) TEST_METHOD="testPhase1_similarPhoto"; LABEL="Phase 1: 유사 사진" ;;
    2) TEST_METHOD="testPhase2_photoViewing"; LABEL="Phase 2: 사진 열람" ;;
    3) TEST_METHOD="testPhase3_viewerDelete"; LABEL="Phase 3: 뷰어 삭제" ;;
    4) TEST_METHOD="testPhase4_gridSwipeDelete"; LABEL="Phase 4: 그리드 삭제" ;;
    5) TEST_METHOD="testPhase5_trashViewer"; LABEL="Phase 5: 삭제대기함" ;;
    6) TEST_METHOD="testPhase6_albumViewing"; LABEL="Phase 6: 앨범 열람" ;;
    *) TEST_METHOD="testAllPhases"; LABEL="전체 테스트" ;;
esac

# 테스트 시작 시각 캡처 (verify에 전달해 오검출 방지)
TEST_START=$(date -u '+%Y-%m-%dT%H:%M:%SZ')

echo "=== 기기 연결 확인 ==="
xcrun xctrace list devices 2>&1 | grep "$DEVICE_NAME" || {
    echo "❌ $DEVICE_NAME 미연결. USB 연결 확인 필요."
    exit 1
}
echo "✅ $DEVICE_NAME 연결 확인"

echo ""
echo "=== $LABEL 실행 (TEST_START: $TEST_START) ==="
xcodebuild test \
  -project PickPhoto/PickPhoto.xcodeproj \
  -scheme PickPhoto \
  -destination "platform=iOS,id=$DEVICE_ID" \
  -configuration Debug \
  -allowProvisioningUpdates \
  -skip-testing:PickPhotoTests \
  -only-testing:PickPhotoUITests/AnalyticsUITest/$TEST_METHOD \
  2>&1

import XCTest

/// Gate 2 스크롤 성능 테스트
///
/// 이 테스트는 XCTOSSignpostMetric을 사용하여 시스템 레벨에서 hitch를 측정합니다.
/// Instruments와 동일한 정확도를 제공하며, 자동화된 반복 측정이 가능합니다.
///
/// 실행 조건:
/// - 실기기 필수 (시뮬레이터는 Duration만 지원)
/// - Release 빌드 권장 (Edit Scheme > Test > Build Configuration: Release)
/// - Diagnostic 비활성화 권장
///
/// 참고: WWDC20 "Eliminate animation hitches with XCTest"
final class ScrollPerformanceTests: XCTestCase {

    let app = XCUIApplication()

    override func setUp() {
        super.setUp()
        continueAfterFailure = false
        app.launch()
    }

    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Baseline Tests (변동폭 측정용)

    // 커스텀 velocity (앱 내부 L2 테스트와 유사한 속도)
    // .fast는 약 2000 pixels/sec, L2는 10000 pt/s
    static let extremeVelocity = XCUIGestureVelocity(5000)  // 5000 pixels/sec
    static let l2Velocity = XCUIGestureVelocity(10000)      // 10000 pixels/sec (L2와 동일)

    /// Baseline 측정: PhotoKit Provider 기본 스크롤
    ///
    /// 목적: 현재 성능의 변동폭(표준편차) 측정
    /// 기본 5회 반복 + 1회 baseline = 6회 실행
    func testGate2_Baseline_PhotoKit() throws {
        // Navigate to Gate 2 PhotoKit
        let photoKitButton = app.buttons["PhotoKit Provider"]
        XCTAssertTrue(photoKitButton.waitForExistence(timeout: 5))
        photoKitButton.tap()

        // Wait for library to load
        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 10))

        // Wait a bit for initial loading
        sleep(2)

        // Measure scroll performance with L2-level velocity (10000 pixels/sec)
        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            // Extreme velocity swipe - L2 테스트와 동일한 속도
            collection.swipeUp(velocity: Self.l2Velocity)
        }
    }

    /// Baseline 측정: 다양한 스크롤 속도
    func testGate2_Baseline_MultiVelocity() throws {
        navigateToPhotoKit()

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 10))
        sleep(2)

        let measureOptions = XCTMeasureOptions()
        measureOptions.invocationOptions = [.manuallyStop]

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric],
                options: measureOptions) {
            // Multiple velocities to simulate real usage
            collection.swipeUp(velocity: .fast)
            collection.swipeUp(velocity: .default)
            collection.swipeUp(velocity: .fast)
            stopMeasuring()
            // Reset
            collection.swipeDown(velocity: .fast)
            collection.swipeDown(velocity: .fast)
            collection.swipeDown(velocity: .fast)
        }
    }

    // MARK: - A/B Tests: Preheat Mode

    /// Preheat ON (100ms throttle) 테스트
    func testGate2_Preheat_ON() throws {
        navigateToPhotoKit()
        setPreheatMode(to: "ON")

        let collection = app.collectionViews.firstMatch
        sleep(2)

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            performStandardScrollPattern(on: collection)
        }
    }

    /// Preheat 150ms throttle 테스트
    func testGate2_Preheat_150ms() throws {
        navigateToPhotoKit()
        setPreheatMode(to: "150ms")

        let collection = app.collectionViews.firstMatch
        sleep(2)

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            performStandardScrollPattern(on: collection)
        }
    }

    /// Preheat OFF 테스트
    func testGate2_Preheat_OFF() throws {
        navigateToPhotoKit()
        setPreheatMode(to: "OFF")

        let collection = app.collectionViews.firstMatch
        sleep(2)

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            performStandardScrollPattern(on: collection)
        }
    }

    // MARK: - A/B Tests: Delivery Mode

    /// DeliveryMode: Opportunistic (multi callback)
    func testGate2_DeliveryMode_Opportunistic() throws {
        navigateToPhotoKit()
        setDeliveryMode(to: "Opp")

        let collection = app.collectionViews.firstMatch
        sleep(2)

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            performStandardScrollPattern(on: collection)
        }
    }

    /// DeliveryMode: FastFormat (single callback)
    func testGate2_DeliveryMode_Fast() throws {
        navigateToPhotoKit()
        setDeliveryMode(to: "Fast")

        let collection = app.collectionViews.firstMatch
        sleep(2)

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            performStandardScrollPattern(on: collection)
        }
    }

    // MARK: - Extreme Fling Test (L2 시뮬레이션)

    /// Extreme fling pattern: 연속 빠른 스크롤
    func testGate2_ExtremeFling() throws {
        navigateToPhotoKit()

        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 10))
        sleep(2)

        measure(metrics: [XCTOSSignpostMetric.scrollDecelerationMetric]) {
            // Extreme fling: 5 consecutive fast swipes
            for _ in 0..<5 {
                collection.swipeUp(velocity: .fast)
            }
            // Change direction
            for _ in 0..<3 {
                collection.swipeDown(velocity: .fast)
            }
        }
    }

    // MARK: - Helper Methods

    /// PhotoKit Provider로 이동
    private func navigateToPhotoKit() {
        let photoKitButton = app.buttons["PhotoKit Provider"]
        XCTAssertTrue(photoKitButton.waitForExistence(timeout: 5))
        photoKitButton.tap()
    }

    /// Preheat 모드 설정 (버튼을 눌러 순환)
    private func setPreheatMode(to targetMode: String) {
        // P:ON → P:150ms → P:OFF → P:ON 순환
        // 현재 모드를 확인하고 원하는 모드까지 순환
        let preheatButton = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'P:'")).firstMatch

        guard preheatButton.waitForExistence(timeout: 5) else { return }

        // 최대 3번 순환 (ON → 150ms → OFF → ON)
        for _ in 0..<3 {
            let currentLabel = preheatButton.label
            if currentLabel.contains(targetMode) {
                return // 원하는 모드에 도달
            }
            preheatButton.tap()
            sleep(1) // UI 업데이트 대기
        }
    }

    /// Delivery Mode 설정
    private func setDeliveryMode(to targetMode: String) {
        // Opp ↔ Fast 토글
        let modeButton = app.buttons.matching(NSPredicate(format: "label == 'Opp' OR label == 'Fast'")).firstMatch

        guard modeButton.waitForExistence(timeout: 5) else { return }

        let currentLabel = modeButton.label
        if !currentLabel.contains(targetMode) {
            modeButton.tap()
            sleep(1)
        }
    }

    /// 표준 스크롤 패턴 수행
    /// 20초 기준: 플릭 패턴 + 방향 전환
    private func performStandardScrollPattern(on collection: XCUIElement) {
        // Phase 1: 아래로 빠른 플릭 3회 (5초)
        collection.swipeUp(velocity: .fast)
        collection.swipeUp(velocity: .fast)
        collection.swipeUp(velocity: .fast)

        // Phase 2: 위로 빠른 플릭 3회 (5초)
        collection.swipeDown(velocity: .fast)
        collection.swipeDown(velocity: .fast)
        collection.swipeDown(velocity: .fast)

        // Phase 3: 방향 전환 포함 (10초)
        collection.swipeUp(velocity: .fast)
        collection.swipeDown(velocity: .default)
        collection.swipeUp(velocity: .fast)
        collection.swipeDown(velocity: .fast)
    }
}

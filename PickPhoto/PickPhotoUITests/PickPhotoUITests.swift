//
//  PickPhotoUITests.swift
//  PickPhotoUITests
//
//  극한 스크롤 성능 테스트
//

import XCTest

final class PickPhotoUITests: XCTestCase {

    let app = XCUIApplication()

    override func setUpWithError() throws {
        continueAfterFailure = false

        app.launch()

        // 앱이 완전히 로드될 때까지 대기
        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 10), "CollectionView가 나타나지 않음")
    }

    // MARK: - UI 디버깅

    /// UI 계층 구조 출력
    @MainActor
    func testPrintUIHierarchy() throws {
        print("=== UI 계층 구조 ===")
        print(app.debugDescription)

        print("\n=== CollectionViews ===")
        let collections = app.collectionViews
        print("CollectionViews count: \(collections.count)")
        for i in 0..<collections.count {
            let cv = collections.element(boundBy: i)
            print("  [\(i)] exists: \(cv.exists), frame: \(cv.frame)")
        }

        print("\n=== ScrollViews ===")
        let scrollViews = app.scrollViews
        print("ScrollViews count: \(scrollViews.count)")

        print("\n=== Tables ===")
        let tables = app.tables
        print("Tables count: \(tables.count)")
    }

    // MARK: - 극한 스크롤 테스트

    /// 기본 swipe 테스트 (idle 대기 있음 - 느림)
    @MainActor
    func testExtremeScroll() throws {
        let collection = app.collectionViews.firstMatch

        print("=== 기본 swipe 테스트 시작 ===")
        let startTime = Date()

        // 기본 swipe - 각 swipe 후 idle 대기
        for i in 0..<30 {
            collection.swipeDown(velocity: XCUIGestureVelocity(8000))
            print("Swipe \(i + 1)/30 완료")
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("=== 기본 swipe 테스트 완료: \(elapsed)초 ===")
    }

    /// 극한 연속 드래그 테스트 (XCUICoordinate + velocity 사용)
    @MainActor
    func testExtremeContinuousDrag() throws {
        let collection = app.collectionViews.firstMatch
        let frame = collection.frame

        print("=== 극한 연속 드래그 테스트 시작 ===")
        print("Frame: \(frame)")

        let startTime = Date()

        // 좌표 기반 드래그 - 화면 위에서 아래로 드래그 (콘텐츠가 아래로 스크롤 = 오래된 사진으로)
        // normalized coordinate: (0,0) = 좌상단, (1,1) = 우하단
        // 손가락: 위(0.2) → 아래(0.8) = swipeDown과 동일

        // 40번 연속 드래그 - 최소 press duration + 최대 velocity
        for i in 0..<40 {
            let startCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let endCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))

            // press duration: 0.01초 (최소)
            // velocity: 10000 pixels/s (극한)
            // hold duration: 0초 (즉시 다음으로)
            startCoord.press(forDuration: 0.01, thenDragTo: endCoord, withVelocity: 10000, thenHoldForDuration: 0)
            print("Drag \(i + 1)/40 완료")
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("=== 극한 연속 드래그 테스트 완료: \(elapsed)초 ===")
    }

    /// 무정지 연속 드래그 (한 번의 제스처로 여러 드래그 연결)
    @MainActor
    func testNonStopDrag() throws {
        let collection = app.collectionViews.firstMatch

        print("=== 무정지 연속 드래그 테스트 시작 ===")
        let startTime = Date()

        // 15초 동안 연속 드래그
        let targetDuration: TimeInterval = 15.0

        while Date().timeIntervalSince(startTime) < targetDuration {
            // 손가락: 위(0.2) → 아래(0.8) = swipeDown
            let startCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.2))
            let endCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))

            // 최소 press, 최대 velocity, 0 hold
            startCoord.press(forDuration: 0.001, thenDragTo: endCoord, withVelocity: 15000, thenHoldForDuration: 0)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("=== 무정지 연속 드래그 테스트 완료: \(elapsed)초 ===")
    }

    /// 다양한 속도로 테스트 (비교용)
    @MainActor
    func testVariousVelocities() throws {
        let collection = app.collectionViews.firstMatch

        let velocities: [(String, XCUIGestureVelocity)] = [
            ("slow", .slow),
            ("default", .default),
            ("fast", .fast),
            ("2000", XCUIGestureVelocity(2000)),
            ("5000", XCUIGestureVelocity(5000)),
            ("8000", XCUIGestureVelocity(8000)),
            ("10000", XCUIGestureVelocity(10000)),
        ]

        for (name, velocity) in velocities {
            // 맨 위로 스크롤
            collection.swipeDown(velocity: .fast)
            collection.swipeDown(velocity: .fast)
            sleep(1)

            print("--- 테스트: velocity = \(name) ---")
            let startTime = Date()

            // 5번 swipe
            for _ in 0..<5 {
                collection.swipeUp(velocity: velocity)
            }

            let elapsed = Date().timeIntervalSince(startTime)
            print("velocity=\(name): \(elapsed)초")
            sleep(1)
        }
    }

    // MARK: - 성능 측정 테스트 (XCTMetric 사용)

    /// Hitch 측정 포함 스크롤 테스트 (실제 기기에서만 동작)
    @MainActor
    func testScrollPerformanceWithMetrics() throws {
        let collection = app.collectionViews.firstMatch

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        measure(metrics: [XCTOSSignpostMetric.scrollingAndDecelerationMetric]) {
            collection.swipeUp(velocity: XCUIGestureVelocity(8000))
            collection.swipeUp(velocity: XCUIGestureVelocity(8000))
            collection.swipeUp(velocity: XCUIGestureVelocity(8000))
        }
    }

    /// L1 시뮬레이션 (일상 스크롤 - 약 8초)
    @MainActor
    func testL1Scroll() throws {
        let collection = app.collectionViews.firstMatch

        print("=== L1 일상 스크롤 시작 ===")
        let startTime = Date()

        // 중간 속도로 8초 동안 스크롤
        let targetDuration: TimeInterval = 8.0
        let velocity = XCUIGestureVelocity(3000)

        while Date().timeIntervalSince(startTime) < targetDuration {
            collection.swipeUp(velocity: velocity)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("=== L1 완료: \(elapsed)초 ===")
    }

    /// L2 시뮬레이션 (극한 스크롤 - 약 15초)
    @MainActor
    func testL2Scroll() throws {
        let collection = app.collectionViews.firstMatch

        print("=== L2 극한 스크롤 시작 ===")
        let startTime = Date()

        // 극한 속도로 15초 동안 스크롤
        let targetDuration: TimeInterval = 15.0
        let velocity = XCUIGestureVelocity(8000)

        while Date().timeIntervalSince(startTime) < targetDuration {
            collection.swipeUp(velocity: velocity)
        }

        let elapsed = Date().timeIntervalSince(startTime)
        print("=== L2 완료: \(elapsed)초 ===")
    }
}

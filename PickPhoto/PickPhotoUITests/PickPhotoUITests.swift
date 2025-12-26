//
//  PickPhotoUITests.swift
//  PickPhotoUITests
//
//  극한 스크롤 성능 테스트
//

import XCTest

final class PickPhotoUITests: XCTestCase {

    let app = XCUIApplication()

    /// 앱이 이미 실행되었는지 여부
    private var hasLaunched = false

    override func setUpWithError() throws {
        continueAfterFailure = false

        // testAutoScrollTester는 별도의 launchArguments로 시작해야 하므로 스킵
        if name.contains("testAutoScrollTester") {
            launchAppWithAutoScroll()
        } else {
            launchAppIfNeeded()
        }
    }

    /// 앱을 실행하고 CollectionView가 나타날 때까지 대기
    private func launchAppIfNeeded() {
        guard !hasLaunched else { return }
        hasLaunched = true

        app.launch()

        // 앱이 완전히 로드될 때까지 대기
        let collection = app.collectionViews.firstMatch
        XCTAssertTrue(collection.waitForExistence(timeout: 10), "CollectionView가 나타나지 않음")
    }

    /// AutoScrollTester용 앱 실행 (launchArguments 포함)
    private func launchAppWithAutoScroll() {
        hasLaunched = true

        app.launchArguments = [
            "--auto-scroll",
            "--auto-scroll-speed=12000",
            "--auto-scroll-duration=12",
            "--auto-scroll-direction=down",
            "--auto-scroll-boundary=reverse"
        ]

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

    // MARK: - AutoScrollTester 테스트

    /// AutoScrollTester로 극한 스크롤 테스트 (CADisplayLink 기반)
    /// - 런치 아규먼트로 자동 스크롤 활성화
    /// - XCUITest의 waitForQuiescence 문제 없이 고속 스크롤 가능
    @MainActor
    func testAutoScrollTester() throws {
        // setUpWithError()에서 launchAppWithAutoScroll()로 앱 시작됨
        // AutoScrollTester가 viewDidAppear에서 자동 시작됨

        print("=== AutoScrollTester 테스트 시작 (launchArguments로 자동 시작) ===")

        // AutoScrollTester duration(12초) + 여유
        Thread.sleep(forTimeInterval: 15)

        print("=== AutoScrollTester 테스트 완료 ===")
    }

    // MARK: - 성능 측정 테스트 (XCTMetric 사용)

    /// Hitch 측정 포함 스크롤 테스트 (실제 기기에서만 동작)
    @MainActor
    func testScrollPerformanceWithMetrics() throws {
        let collection = app.collectionViews.firstMatch

        let options = XCTMeasureOptions()
        options.iterationCount = 5

        // options를 measure에 전달해야 iterationCount가 적용됨
        measure(options: options, block: {
            collection.swipeDown(velocity: XCUIGestureVelocity(8000))
        })
    }

    /// L1~L10 시퀀스 테스트
    /// velocity 1000 ~ 10000 (1000씩 증가)
    @MainActor
    func testL1L2Sequence() throws {
        let collection = app.collectionViews.firstMatch
        let startTime = Date()

        // velocity 1000, 2000, ..., 10000 (10회)
        let velocities = [1000, 2000, 3000, 4000, 5000, 6000, 7000, 8000, 9000, 10000]

        for (index, velocity) in velocities.enumerated() {
            let segmentStart = Date()
            let segmentDuration: TimeInterval = 3.5  // 각 구간 3.5초 (측정 구간 ~3초 + 여유)

            print("=== L\(index + 1) 시작: velocity \(velocity) ===")

            while Date().timeIntervalSince(segmentStart) < segmentDuration {
                collection.swipeDown(velocity: XCUIGestureVelocity(CGFloat(velocity)))
            }

            print("=== L\(index + 1) 완료: \(Date().timeIntervalSince(segmentStart))초 ===")
        }

        let totalElapsed = Date().timeIntervalSince(startTime)
        print("=== 전체 완료: \(totalElapsed)초 ===")
    }

    /// L1 + L2 시퀀스 (좌표 기반 드래그 버전)
    /// swipe 대신 press(thenDragTo:) 사용 - 더 정밀한 제어
    @MainActor
    func testL1L2SequenceWithDrag() throws {
        let collection = app.collectionViews.firstMatch

        // === L1: 일상 스크롤 (3초, velocity 8000) ===
        print("=== L1 시작: 3초, velocity 8000 (drag) ===")
        let l1Start = Date()
        let l1Duration: TimeInterval = 3.0

        // 손가락: 위(0.3) → 아래(0.7) = swipeDown = 오래된 사진으로 스크롤
        while Date().timeIntervalSince(l1Start) < l1Duration {
            let startCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            let endCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            startCoord.press(forDuration: 0.01, thenDragTo: endCoord, withVelocity: 8000, thenHoldForDuration: 0)
        }
        print("=== L1 완료: \(Date().timeIntervalSince(l1Start))초 ===")

        // === Pause: 1초 ===
        print("=== Pause: 1초 ===")
        Thread.sleep(forTimeInterval: 1.0)

        // === L2: 극한 스크롤 (8초, velocity 30000) ===
        print("=== L2 시작: 8초, velocity 30000 (drag) ===")
        let l2Start = Date()
        let l2Duration: TimeInterval = 8.0

        // 손가락: 위(0.3) → 아래(0.7) = swipeDown = 오래된 사진으로 스크롤
        while Date().timeIntervalSince(l2Start) < l2Duration {
            let startCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
            let endCoord = collection.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            startCoord.press(forDuration: 0.01, thenDragTo: endCoord, withVelocity: 30000, thenHoldForDuration: 0)
        }
        print("=== L2 완료: \(Date().timeIntervalSince(l2Start))초 ===")

        let totalElapsed = Date().timeIntervalSince(l1Start)
        print("=== 전체 완료: \(totalElapsed)초 ===")
    }
}

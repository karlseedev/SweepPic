//
//  AutoScrollTester.swift
//  PickPhoto
//
//  CADisplayLink 기반 극한 스크롤 테스터
//  수동 극한 스크롤을 시뮬레이션하여 성능 측정에 사용
//
//  활성화(권장):
//   - 앱 런치 아규먼트: --auto-scroll
//     - 옵션: --auto-scroll-speed, --auto-scroll-duration, --auto-scroll-direction, --auto-scroll-boundary
//     - 예: --auto-scroll --auto-scroll-speed=12000 --auto-scroll-duration=15 --auto-scroll-direction=up --auto-scroll-boundary=reverse
//   - (선택) 3손가락 탭 제스처: --auto-scroll-gesture
//

import UIKit

/// 자동 스크롤 테스터 - CADisplayLink로 contentOffset 직접 제어
/// 수동 극한 스크롤보다 더 정밀하고 재현 가능한 테스트 제공
final class AutoScrollTester {

    // MARK: - Types

    /// 스크롤 방향
    enum Direction {
        case up      // 오래된 사진으로 (contentOffset.y 감소)
        case down    // 최신 사진으로 (contentOffset.y 증가)
    }

    /// 경계 도달 시 동작
    enum BoundaryBehavior {
        case stop
        case reverse
    }

    /// 스크롤 속도 프리셋
    enum SpeedPreset {
        case slow       // 일상 스크롤 (L1) - 약 1000 pt/s
        case medium     // 빠른 스크롤 - 약 3000 pt/s
        case fast       // 매우 빠른 스크롤 - 약 5000 pt/s
        case extreme    // 극한 스크롤 (L2) - 약 8000 pt/s
        case custom(CGFloat)  // 커스텀 속도 (pt/s)

        var pointsPerSecond: CGFloat {
            switch self {
            case .slow: return 1000
            case .medium: return 3000
            case .fast: return 5000
            case .extreme: return 8000
            case .custom(let speed): return speed
            }
        }
    }

    // MARK: - Launch Arguments

    enum LaunchArgument {
        static let autoScroll = "--auto-scroll"
        static let autoScrollGesture = "--auto-scroll-gesture"
        static let speed = "--auto-scroll-speed"           // pt/s, e.g. 12000
        static let duration = "--auto-scroll-duration"     // seconds, e.g. 15
        static let direction = "--auto-scroll-direction"   // up | down
        static let boundary = "--auto-scroll-boundary"     // stop | reverse
        static let oscillation = "--auto-scroll-oscillation" // 0.0~1.0 (speed multiplier amplitude)
        static let frequency = "--auto-scroll-frequency"     // Hz
    }

    // MARK: - Properties

    /// 싱글톤 인스턴스
    static let shared = AutoScrollTester()

    /// 스크롤 대상 (약한 참조)
    private weak var scrollView: UIScrollView?

    /// CADisplayLink
    private var displayLink: CADisplayLink?

    /// 스크롤 속도 (points per second)
    private var speed: CGFloat = 8000

    /// 속도 변조 진폭 (0~1)
    private var speedOscillationAmplitude: CGFloat = 0

    /// 속도 변조 주파수 (Hz)
    private var speedOscillationFrequency: CGFloat = 0

    /// 스크롤 방향
    private var direction: Direction = .up

    /// 경계 도달 시 동작
    private var boundaryBehavior: BoundaryBehavior = .reverse

    /// 스크롤 지속 시간 (초)
    private var duration: TimeInterval = 15

    /// 실행 시작 시간 (run loop 기준)
    private var runStartTime: CFTimeInterval = 0

    /// 실제 스크롤 시작 시간 (contentSize/bounds 준비 후)
    private var activeStartTime: CFTimeInterval = 0

    /// 마지막 프레임 시간
    private var lastFrameTime: CFTimeInterval = 0

    /// 완료 콜백
    private var completion: (() -> Void)?

    /// 진행 중 여부
    private(set) var isRunning: Bool = false

    /// 런치 아규먼트 기반 자동 시작은 1회만
    private var hasAutoStartedFromLaunchArguments: Bool = false

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 자동 스크롤 시작
    /// - Parameters:
    ///   - scrollView: 스크롤할 뷰 (UICollectionView 등)
    ///   - direction: 스크롤 방향
    ///   - speed: 속도 프리셋
    ///   - duration: 지속 시간 (초)
    ///   - boundaryBehavior: 경계 도달 시 동작
    ///   - oscillationAmplitude: 속도 변조 진폭 (0~1)
    ///   - oscillationFrequency: 속도 변조 주파수 (Hz)
    ///   - completion: 완료 시 콜백
    func start(
        scrollView: UIScrollView,
        direction: Direction = .up,
        speed: SpeedPreset = .extreme,
        duration: TimeInterval = 15,
        boundaryBehavior: BoundaryBehavior = .reverse,
        oscillationAmplitude: CGFloat = 0,
        oscillationFrequency: CGFloat = 0,
        completion: (() -> Void)? = nil
    ) {
        // 이미 실행 중이면 중지
        stop()

        self.scrollView = scrollView
        self.direction = direction
        self.speed = speed.pointsPerSecond
        self.duration = duration
        self.boundaryBehavior = boundaryBehavior
        self.speedOscillationAmplitude = max(0, min(1, oscillationAmplitude))
        self.speedOscillationFrequency = max(0, oscillationFrequency)
        self.completion = completion
        self.isRunning = true

        print("=== AutoScrollTester 시작 ===")
        print("속도: \(self.speed) pt/s")
        print("방향: \(direction)")
        print("지속시간: \(duration)초")
        print("경계동작: \(boundaryBehavior)")
        if self.speedOscillationAmplitude > 0 && self.speedOscillationFrequency > 0 {
            print("속도변조: amplitude=\(self.speedOscillationAmplitude), frequency=\(self.speedOscillationFrequency)Hz")
        }

        // CADisplayLink 생성 및 시작
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        displayLink?.add(to: .main, forMode: .common)

        runStartTime = CACurrentMediaTime()
        activeStartTime = 0
        lastFrameTime = 0
    }

    /// 런치 아규먼트(`--auto-scroll`)가 있으면 자동으로 시작
    /// - Note: 뷰컨트롤러 `viewDidAppear` 등에서 호출 권장
    func startIfRequestedByLaunchArguments(scrollView: UIScrollView) {
        guard !hasAutoStartedFromLaunchArguments else { return }
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains(LaunchArgument.autoScroll) else { return }
        hasAutoStartedFromLaunchArguments = true

        let configuredSpeed: CGFloat = Self.parseCGFloat(
            key: LaunchArgument.speed,
            defaultValue: SpeedPreset.extreme.pointsPerSecond,
            arguments: arguments
        )

        let configuredDuration: TimeInterval = Self.parseTimeInterval(
            key: LaunchArgument.duration,
            defaultValue: 15,
            arguments: arguments
        )

        let configuredDirection = Self.parseDirection(arguments: arguments) ?? .up
        let configuredBoundary = Self.parseBoundaryBehavior(arguments: arguments) ?? .reverse
        let configuredOscillationAmplitude: CGFloat = Self.parseCGFloat(key: LaunchArgument.oscillation, defaultValue: 0, arguments: arguments)
        let configuredOscillationFrequency: CGFloat = Self.parseCGFloat(key: LaunchArgument.frequency, defaultValue: 0, arguments: arguments)

        start(
            scrollView: scrollView,
            direction: configuredDirection,
            speed: .custom(configuredSpeed),
            duration: configuredDuration,
            boundaryBehavior: configuredBoundary,
            oscillationAmplitude: configuredOscillationAmplitude,
            oscillationFrequency: configuredOscillationFrequency
        )
    }

    /// 자동 스크롤 중지
    func stop(clearCompletion: Bool = true) {
        displayLink?.invalidate()
        displayLink = nil
        isRunning = false

        if clearCompletion {
            completion = nil
        }
        scrollView = nil

        if activeStartTime > 0 {
            let elapsed = CACurrentMediaTime() - activeStartTime
            print("=== AutoScrollTester 중지: \(String(format: "%.2f", elapsed))초 경과 ===")
        }

        runStartTime = 0
        activeStartTime = 0
        lastFrameTime = 0
    }

    // MARK: - Private Methods

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        guard let scrollView = scrollView else {
            stop()
            return
        }

        let currentTime = link.timestamp

        // contentSize/bounds 준비 전에는 대기
        let inset = scrollView.adjustedContentInset
        let minY = -inset.top
        let maxY = max(minY, scrollView.contentSize.height - scrollView.bounds.height + inset.bottom)
        if maxY <= minY {
            return
        }

        if activeStartTime == 0 {
            activeStartTime = currentTime
            lastFrameTime = currentTime
        }

        let elapsed = currentTime - activeStartTime

        // 지속 시간 초과 시 중지
        if elapsed >= duration {
            let completion = completion
            stop(clearCompletion: true)
            completion?()
            return
        }

        // 프레임 간 시간 계산
        let rawDeltaTime = currentTime - lastFrameTime
        let deltaTime = max(0, min(rawDeltaTime, 0.05))
        lastFrameTime = currentTime

        // 이동량 계산
        let effectiveSpeed: CGFloat
        if speedOscillationAmplitude > 0, speedOscillationFrequency > 0 {
            let phase = 2 * Double.pi * Double(speedOscillationFrequency) * elapsed
            let multiplier = 1 + Double(speedOscillationAmplitude) * sin(phase)
            effectiveSpeed = max(0, speed * CGFloat(multiplier))
        } else {
            effectiveSpeed = speed
        }
        let delta = effectiveSpeed * deltaTime

        // 현재 offset
        var offset = scrollView.contentOffset

        // 방향에 따른 이동
        switch direction {
        case .up:
            // 위로 스크롤 = contentOffset.y 감소 (오래된 사진으로)
            offset.y -= delta
        case .down:
            // 아래로 스크롤 = contentOffset.y 증가 (최신 사진으로)
            offset.y += delta
        }

        let isAtMin = offset.y <= minY
        let isAtMax = offset.y >= maxY

        // 경계 처리
        if (direction == .up && isAtMin) || (direction == .down && isAtMax) {
            switch boundaryBehavior {
            case .stop:
                print("경계 도달 - 스크롤 중지")
                let completion = completion
                stop(clearCompletion: true)
                completion?()
                return
            case .reverse:
                offset.y = max(minY, min(maxY, offset.y))
                direction = (direction == .up) ? .down : .up
            }
        }

        // clamp
        offset.y = max(minY, min(maxY, offset.y))

        // offset 적용 (애니메이션 없이 즉시)
        scrollView.contentOffset = offset
    }

    // MARK: - Argument Parsing

    private static func stringValue(key: String, arguments: [String]) -> String? {
        if let index = arguments.firstIndex(of: key), index + 1 < arguments.count {
            return arguments[index + 1]
        }
        if let entry = arguments.first(where: { $0.hasPrefix(key + "=") }) {
            return String(entry.dropFirst((key + "=").count))
        }
        return nil
    }

    private static func parseCGFloat(key: String, defaultValue: CGFloat, arguments: [String]) -> CGFloat {
        guard let raw = stringValue(key: key, arguments: arguments) else { return defaultValue }
        guard let value = Double(raw) else { return defaultValue }
        return CGFloat(value)
    }

    private static func parseTimeInterval(key: String, defaultValue: TimeInterval, arguments: [String]) -> TimeInterval {
        guard let raw = stringValue(key: key, arguments: arguments) else { return defaultValue }
        guard let value = Double(raw) else { return defaultValue }
        return value
    }

    private static func parseDirection(arguments: [String]) -> Direction? {
        guard let raw = stringValue(key: LaunchArgument.direction, arguments: arguments)?.lowercased() else {
            return nil
        }
        switch raw {
        case "up": return .up
        case "down": return .down
        default: return nil
        }
    }

    private static func parseBoundaryBehavior(arguments: [String]) -> BoundaryBehavior? {
        guard let raw = stringValue(key: LaunchArgument.boundary, arguments: arguments)?.lowercased() else {
            return nil
        }
        switch raw {
        case "stop": return .stop
        case "reverse": return .reverse
        default: return nil
        }
    }

    static var shouldInstallGestureByLaunchArguments: Bool {
        ProcessInfo.processInfo.arguments.contains(LaunchArgument.autoScrollGesture)
    }
}

// MARK: - Convenience Extensions

extension UIScrollView {
    /// 극한 스크롤 테스트 시작 (편의 메서드)
    func startExtremeScrollTest(
        direction: AutoScrollTester.Direction = .up,
        speed: AutoScrollTester.SpeedPreset = .extreme,
        duration: TimeInterval = 15,
        boundaryBehavior: AutoScrollTester.BoundaryBehavior = .reverse,
        oscillationAmplitude: CGFloat = 0,
        oscillationFrequency: CGFloat = 0,
        completion: (() -> Void)? = nil
    ) {
        AutoScrollTester.shared.start(
            scrollView: self,
            direction: direction,
            speed: speed,
            duration: duration,
            boundaryBehavior: boundaryBehavior,
            oscillationAmplitude: oscillationAmplitude,
            oscillationFrequency: oscillationFrequency,
            completion: completion
        )
    }

    /// 스크롤 테스트 중지
    func stopScrollTest() {
        AutoScrollTester.shared.stop()
    }

    /// 3손가락 탭 제스처 설정 (자동 스크롤 토글)
    func setupAutoScrollGesture() {
        let gesture = UITapGestureRecognizer(target: self, action: #selector(handleThreeFingerTap(_:)))
        gesture.numberOfTouchesRequired = 3
        gesture.numberOfTapsRequired = 1
        self.addGestureRecognizer(gesture)
    }

    @objc private func handleThreeFingerTap(_ gesture: UITapGestureRecognizer) {
        if AutoScrollTester.shared.isRunning {
            AutoScrollTester.shared.stop()
        } else {
            // L2 극한 스크롤 테스트 시작 (15초)
            self.startExtremeScrollTest(
                direction: .up,
                speed: .extreme,
                duration: 15,
                boundaryBehavior: .reverse,
                oscillationAmplitude: 0.25,
                oscillationFrequency: 3
            )
        }
    }
}

//
//  PerformanceMonitor.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-29.
//
//  Description:
//  스크롤 성능 측정용 디버그 도구입니다.
//  FPS, 프레임 드롭, 메모리 사용량을 실시간으로 측정합니다.
//
//  사용법:
//  1. GridViewController에서 PerformanceMonitor.shared.start() 호출
//  2. 스크롤 테스트 후 PerformanceMonitor.shared.stop() 호출
//  3. 콘솔 로그 복사해서 분석
//

#if DEBUG
import UIKit

/// 성능 측정 결과
struct PerformanceSnapshot {
    let timestamp: TimeInterval
    let fps: Double
    let frameTime: Double      // ms
    let droppedFrames: Int
    let memoryUsage: Double    // MB
    let cpuUsage: Double       // %
}

/// 스크롤 성능 모니터
/// CADisplayLink로 FPS를 측정하고, 프레임 드롭을 감지합니다.
final class PerformanceMonitor {

    static let shared = PerformanceMonitor()

    // MARK: - Constants

    /// 목표 프레임 시간 (60fps = 16.67ms, 120fps = 8.33ms)
    private let targetFrameTime: Double = 1.0 / 60.0  // 16.67ms

    /// 프레임 드롭 임계값 (목표의 1.5배 이상이면 드롭으로 간주)
    private let dropThreshold: Double = 1.5

    /// 로그 출력 간격 (초)
    private let logInterval: TimeInterval = 1.0

    // MARK: - Properties

    private var displayLink: CADisplayLink?
    private var isRunning = false

    /// 측정 데이터
    private var frameCount: Int = 0
    private var droppedFrameCount: Int = 0
    private var lastTimestamp: CFTimeInterval = 0
    private var lastLogTime: CFTimeInterval = 0
    private var sessionStartTime: CFTimeInterval = 0

    /// 프레임 시간 히스토리 (최근 60프레임)
    private var frameTimeHistory: [Double] = []
    private let maxHistorySize = 60

    /// 전체 세션 통계
    private var totalFrames: Int = 0
    private var totalDroppedFrames: Int = 0
    private var minFPS: Double = .infinity
    private var maxFPS: Double = 0
    private var fpsHistory: [Double] = []

    // MARK: - Init

    private init() {}

    // MARK: - Public Methods

    /// 성능 측정 시작
    func start() {
        guard !isRunning else { return }
        isRunning = true

        // 통계 초기화
        resetStats()

        // DisplayLink 생성
        displayLink = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
        displayLink?.add(to: .main, forMode: .common)

        print("""

        ╔══════════════════════════════════════════════════════╗
        ║         PERFORMANCE MONITOR STARTED                  ║
        ╠══════════════════════════════════════════════════════╣
        ║  Target: 60 FPS (16.67ms per frame)                  ║
        ║  Drop threshold: >\(String(format: "%.1f", targetFrameTime * dropThreshold * 1000))ms                              ║
        ╚══════════════════════════════════════════════════════╝

        """)
    }

    /// 성능 측정 중지 및 결과 출력
    func stop() {
        guard isRunning else { return }
        isRunning = false

        displayLink?.invalidate()
        displayLink = nil

        printFinalReport()
    }

    /// 측정 중인지 확인
    var isMonitoring: Bool {
        return isRunning
    }

    // MARK: - Private Methods

    private func resetStats() {
        frameCount = 0
        droppedFrameCount = 0
        lastTimestamp = 0
        lastLogTime = 0
        sessionStartTime = CACurrentMediaTime()
        frameTimeHistory.removeAll()

        totalFrames = 0
        totalDroppedFrames = 0
        minFPS = .infinity
        maxFPS = 0
        fpsHistory.removeAll()
    }

    @objc private func handleDisplayLink(_ link: CADisplayLink) {
        let currentTime = link.timestamp

        // 첫 프레임 처리
        if lastTimestamp == 0 {
            lastTimestamp = currentTime
            lastLogTime = currentTime
            return
        }

        // 프레임 시간 계산
        let frameTime = currentTime - lastTimestamp
        lastTimestamp = currentTime

        // 프레임 카운트
        frameCount += 1
        totalFrames += 1

        // 프레임 드롭 감지
        if frameTime > targetFrameTime * dropThreshold {
            droppedFrameCount += 1
            totalDroppedFrames += 1
        }

        // 프레임 시간 히스토리 저장
        frameTimeHistory.append(frameTime * 1000)  // ms로 변환
        if frameTimeHistory.count > maxHistorySize {
            frameTimeHistory.removeFirst()
        }

        // 주기적 로그 출력
        if currentTime - lastLogTime >= logInterval {
            logCurrentStats()
            lastLogTime = currentTime
        }
    }

    private func logCurrentStats() {
        let elapsed = lastLogTime - sessionStartTime

        // FPS 계산
        let fps = Double(frameCount) / logInterval
        frameCount = 0

        // 드롭된 프레임 수
        let drops = droppedFrameCount
        droppedFrameCount = 0

        // FPS 통계 업데이트
        fpsHistory.append(fps)
        minFPS = min(minFPS, fps)
        maxFPS = max(maxFPS, fps)

        // 평균 프레임 시간
        let avgFrameTime = frameTimeHistory.isEmpty ? 0 : frameTimeHistory.reduce(0, +) / Double(frameTimeHistory.count)
        let maxFrameTime = frameTimeHistory.max() ?? 0

        // 메모리 사용량
        let memory = getMemoryUsage()

        // CPU 사용량
        let cpu = getCPUUsage()

        // 로그 출력
        let dropWarning = drops > 0 ? " ⚠️" : ""
        print("[Perf] t=\(String(format: "%.1f", elapsed))s | FPS: \(String(format: "%.1f", fps)) | Drops: \(drops)\(dropWarning) | FrameTime: avg=\(String(format: "%.2f", avgFrameTime))ms, max=\(String(format: "%.2f", maxFrameTime))ms | Mem: \(String(format: "%.1f", memory))MB | CPU: \(String(format: "%.1f", cpu))%")
    }

    private func printFinalReport() {
        let sessionDuration = CACurrentMediaTime() - sessionStartTime
        let avgFPS = fpsHistory.isEmpty ? 0 : fpsHistory.reduce(0, +) / Double(fpsHistory.count)
        let dropRate = totalFrames > 0 ? Double(totalDroppedFrames) / Double(totalFrames) * 100 : 0

        print("""

        ╔══════════════════════════════════════════════════════╗
        ║         PERFORMANCE MONITOR REPORT                   ║
        ╠══════════════════════════════════════════════════════╣
        ║  Session Duration: \(String(format: "%.1f", sessionDuration))s
        ║  Total Frames: \(totalFrames)
        ║  Dropped Frames: \(totalDroppedFrames) (\(String(format: "%.1f", dropRate))%)
        ╠══════════════════════════════════════════════════════╣
        ║  FPS Stats:
        ║    Average: \(String(format: "%.1f", avgFPS))
        ║    Min: \(String(format: "%.1f", minFPS))
        ║    Max: \(String(format: "%.1f", maxFPS))
        ╠══════════════════════════════════════════════════════╣
        ║  Memory: \(String(format: "%.1f", getMemoryUsage())) MB
        ║  CPU: \(String(format: "%.1f", getCPUUsage()))%
        ╚══════════════════════════════════════════════════════╝

        """)
    }

    // MARK: - System Metrics

    /// 메모리 사용량 (MB)
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            return Double(info.resident_size) / 1024 / 1024
        }
        return 0
    }

    /// CPU 사용량 (%)
    private func getCPUUsage() -> Double {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t()

        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList else {
            return 0
        }

        var totalUsage: Double = 0

        // THREAD_BASIC_INFO_COUNT: thread_basic_info 구조체 크기를 integer_t 단위로 계산
        let threadBasicInfoCount = mach_msg_type_number_t(
            MemoryLayout<thread_basic_info>.size / MemoryLayout<integer_t>.size
        )

        for i in 0..<Int(threadCount) {
            var info = thread_basic_info()
            var infoCount = threadBasicInfoCount

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(infoCount)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &infoCount)
                }
            }

            if result == KERN_SUCCESS && info.flags & TH_FLAGS_IDLE == 0 {
                totalUsage += Double(info.cpu_usage) / Double(TH_USAGE_SCALE) * 100
            }
        }

        // Deallocate thread list
        let size = vm_size_t(MemoryLayout<thread_t>.size * Int(threadCount))
        vm_deallocate(mach_task_self_, vm_address_t(bitPattern: threads), size)

        return totalUsage
    }
}

// MARK: - Convenience Extension for GridViewController

extension UIViewController {

    /// 성능 모니터 토글 (디버그용)
    func togglePerformanceMonitor() {
        if PerformanceMonitor.shared.isMonitoring {
            PerformanceMonitor.shared.stop()
        } else {
            PerformanceMonitor.shared.start()
        }
    }
}
#endif

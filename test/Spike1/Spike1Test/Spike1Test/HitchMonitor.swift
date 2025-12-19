import UIKit
import QuartzCore

/// Result of hitch monitoring (Apple-style measurement)
struct HitchResult {
    let renderedFrames: Int         // displayLink 호출 횟수
    let droppedFrames: Int          // 누락된 프레임 수 (참고용)
    let longestHitch: Int           // 최대 연속 드랍
    let totalHitchTimeMs: Double    // 초과분 누적 (Apple 방식)
    let durationSeconds: Double     // 측정 시간 (초)
    let avgFrameTime: Double        // 평균 프레임 시간 (초)

    /// Apple 공식 기준: Hitch Time Ratio (ms/s)
    /// = sum(max(0, delta - expected)) / 측정 시간
    var hitchTimeRatio: Double {
        guard durationSeconds > 0 else { return 0 }
        return totalHitchTimeMs / durationSeconds
    }

    /// Apple 기준 등급
    /// - Good: < 5 ms/s (거의 인지 못함)
    /// - Warning: 5-10 ms/s (가끔 인지됨)
    /// - Critical: > 10 ms/s (명확히 불편함)
    var appleGrade: String {
        if hitchTimeRatio < 5 { return "Good" }
        if hitchTimeRatio < 10 { return "Warning" }
        return "Critical"
    }

    /// longest hitch를 ms 단위로 변환
    var longestHitchMs: Double {
        return Double(longestHitch) * avgFrameTime * 1000
    }

    /// 평균 프레임 시간 (ms)
    var avgFrameTimeMs: Double {
        return avgFrameTime * 1000
    }

    func formatted() -> String {
        let ratioStr = String(format: "%.1f", hitchTimeRatio)
        let longestMs = String(format: "%.1f", longestHitchMs)
        return "hitch: \(ratioStr) ms/s [\(appleGrade)], dropped: \(droppedFrames), longest: \(longestHitch) (\(longestMs)ms)"
    }
}

/// Monitors frame hitches using CADisplayLink (Apple-style measurement)
///
/// Apple의 Hitch Time Ratio 정의:
/// - hitchTime = sum(max(0, actualDelta - expectedFrameTime))
/// - hitchTimeRatio = hitchTime / durationSeconds (단위: ms/s)
///
/// 핵심: 프레임별로 expectedFrameTime을 link.targetTimestamp - link.timestamp로 계산
/// → ProMotion 가변 주사율에서도 정확한 측정
///
/// 참고: WWDC20 "Eliminate animation hitches with XCTest"
final class HitchMonitor {
    private var displayLink: CADisplayLink?
    private var lastTimestamp: CFTimeInterval = 0
    private var startTimestamp: CFTimeInterval = 0
    private var totalFrames: Int = 0
    private var droppedFrames: Int = 0
    private var totalHitchTime: Double = 0      // 초과분 누적 (초)
    private var longestHitch: Int = 0
    private var currentHitchStreak: Int = 0
    private var isFirstFrame: Bool = true

    // For average frame time calculation
    private var totalExpectedTime: Double = 0

    /// Start monitoring
    func start() {
        _ = stop()  // Clean up any existing monitor

        totalFrames = 0
        droppedFrames = 0
        totalHitchTime = 0
        longestHitch = 0
        currentHitchStreak = 0
        isFirstFrame = true
        totalExpectedTime = 0
        startTimestamp = CACurrentMediaTime()

        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
        displayLink?.add(to: .main, forMode: .common)
    }

    /// Stop monitoring and return results
    func stop() -> HitchResult {
        let endTimestamp = CACurrentMediaTime()
        displayLink?.invalidate()
        displayLink = nil

        let duration = endTimestamp - startTimestamp
        let hitchTimeMs = totalHitchTime * 1000
        let avgFrameTime = totalFrames > 0 ? totalExpectedTime / Double(totalFrames) : 0.01667

        // Debug logging
        let avgFrameTimeMs = avgFrameTime * 1000
        let ratioMs = duration > 0 ? hitchTimeMs / duration : 0
        print("    [HitchMonitor] avgFrame: \(String(format: "%.2f", avgFrameTimeMs))ms, rendered: \(totalFrames), hitchTime: \(String(format: "%.1f", hitchTimeMs))ms, ratio: \(String(format: "%.1f", ratioMs)) ms/s")

        return HitchResult(
            renderedFrames: totalFrames,
            droppedFrames: droppedFrames,
            longestHitch: longestHitch,
            totalHitchTimeMs: hitchTimeMs,
            durationSeconds: duration,
            avgFrameTime: avgFrameTime
        )
    }

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        // Skip first frame (no previous timestamp to compare)
        if isFirstFrame {
            lastTimestamp = link.timestamp
            isFirstFrame = false
            return
        }

        let delta = link.timestamp - lastTimestamp
        lastTimestamp = link.timestamp
        totalFrames += 1

        // 프레임별 expected 계산 (ProMotion 가변 주사율 대응)
        let expectedFrameTime = link.targetTimestamp - link.timestamp

        // 평균 계산용 누적
        totalExpectedTime += expectedFrameTime

        // Apple 방식: expected 초과분만 hitchTime에 누적
        if delta > expectedFrameTime {
            let excessTime = delta - expectedFrameTime
            totalHitchTime += excessTime
        }

        // 드랍 프레임 계산: 1.5배 초과 시에만 (체감 가능한 hitch)
        let hitchThreshold = expectedFrameTime * 1.5
        if delta > hitchThreshold {
            let dropped = max(0, Int(round(delta / expectedFrameTime)) - 1)
            droppedFrames += dropped
            currentHitchStreak += dropped
            longestHitch = max(longestHitch, currentHitchStreak)
        } else {
            // Normal frame - reset streak
            currentHitchStreak = 0
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}

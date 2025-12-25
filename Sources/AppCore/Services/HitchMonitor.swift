// HitchMonitor.swift
// CADisplayLink 기반 프레임 히치 모니터링 (Apple 방식)
//
// Apple의 Hitch Time Ratio 정의:
// - hitchTime = sum(max(0, actualDelta - expectedFrameTime))
// - hitchTimeRatio = hitchTime / durationSeconds (단위: ms/s)
//
// 핵심: 프레임별 expectedFrameTime을 link.targetTimestamp - link.timestamp로 계산
// → ProMotion 가변 주사율에서도 정확한 측정
//
// 참고: WWDC20 "Eliminate animation hitches with XCTest"

import UIKit
import QuartzCore

// MARK: - HitchResult

/// 히치 모니터링 결과 (Apple 방식 측정)
public struct HitchResult {

    /// displayLink 호출 횟수 (렌더링된 프레임 수)
    public let renderedFrames: Int

    /// 누락된 프레임 수 (참고용)
    public let droppedFrames: Int

    /// 최대 연속 드랍 프레임 수
    public let longestHitch: Int

    /// 초과분 누적 시간 (Apple 방식, ms)
    public let totalHitchTimeMs: Double

    /// 측정 시간 (초)
    public let durationSeconds: Double

    /// 평균 프레임 시간 (초)
    public let avgFrameTime: Double

    /// Apple 공식 기준: Hitch Time Ratio (ms/s)
    /// = sum(max(0, delta - expected)) / 측정 시간
    public var hitchTimeRatio: Double {
        guard durationSeconds > 0 else { return 0 }
        return totalHitchTimeMs / durationSeconds
    }

    /// Apple 기준 등급
    /// - Good: < 5 ms/s (거의 인지 못함)
    /// - Warning: 5-10 ms/s (가끔 인지됨)
    /// - Critical: > 10 ms/s (명확히 불편함)
    public var appleGrade: String {
        if hitchTimeRatio < 5 { return "Good" }
        if hitchTimeRatio < 10 { return "Warning" }
        return "Critical"
    }

    /// longest hitch를 ms 단위로 변환
    public var longestHitchMs: Double {
        return Double(longestHitch) * avgFrameTime * 1000
    }

    /// 평균 프레임 시간 (ms)
    public var avgFrameTimeMs: Double {
        return avgFrameTime * 1000
    }

    /// 포맷된 문자열 반환
    public func formatted() -> String {
        let ratioStr = String(format: "%.1f", hitchTimeRatio)
        let longestMs = String(format: "%.1f", longestHitchMs)
        let fps = durationSeconds > 0 ? Double(renderedFrames) / durationSeconds : 0
        let fpsStr = String(format: "%.1f", fps)
        let avgFrameMsStr = String(format: "%.2f", avgFrameTimeMs)
        return "hitch: \(ratioStr) ms/s [\(appleGrade)], fps: \(fpsStr) (avg \(avgFrameMsStr)ms), frames: \(renderedFrames), dropped: \(droppedFrames), longest: \(longestHitch) (\(longestMs)ms)"
    }
}

// MARK: - HitchMonitor

/// CADisplayLink를 사용한 프레임 히치 모니터 (Apple 방식 측정)
///
/// 사용법:
/// ```swift
/// let monitor = HitchMonitor()
/// monitor.start()
/// // ... 스크롤 등 애니메이션 수행 ...
/// let result = monitor.stop()
/// print(result.formatted())
/// ```
public final class HitchMonitor {

    // MARK: - Private Properties

    /// CADisplayLink 인스턴스
    private var displayLink: CADisplayLink?

    /// 마지막 타임스탬프
    private var lastTimestamp: CFTimeInterval = 0

    /// 시작 타임스탬프
    private var startTimestamp: CFTimeInterval = 0

    /// 총 프레임 수
    private var totalFrames: Int = 0

    /// 누락된 프레임 수
    private var droppedFrames: Int = 0

    /// 총 히치 시간 (초)
    private var totalHitchTime: Double = 0

    /// 최대 연속 드랍
    private var longestHitch: Int = 0

    /// 현재 연속 드랍 수
    private var currentHitchStreak: Int = 0

    /// 첫 프레임 여부
    private var isFirstFrame: Bool = true

    /// 평균 프레임 시간 계산용 누적
    private var totalExpectedTime: Double = 0

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// 모니터링 시작
    public func start() {
        // 기존 모니터 정리
        _ = stop()

        // 상태 초기화
        totalFrames = 0
        droppedFrames = 0
        totalHitchTime = 0
        longestHitch = 0
        currentHitchStreak = 0
        isFirstFrame = true
        totalExpectedTime = 0
        startTimestamp = CACurrentMediaTime()

        // DisplayLink 시작
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkFired(_:)))
        if #available(iOS 15.0, *) {
            displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 120, preferred: 120)
        }
        displayLink?.add(to: .main, forMode: .common)
    }

    /// 모니터링 중지 및 결과 반환
    @discardableResult
    public func stop() -> HitchResult {
        let endTimestamp = CACurrentMediaTime()
        displayLink?.invalidate()
        displayLink = nil

        let duration = endTimestamp - startTimestamp
        let hitchTimeMs = totalHitchTime * 1000
        let avgFrameTime = totalFrames > 0 ? totalExpectedTime / Double(totalFrames) : 0.01667

        return HitchResult(
            renderedFrames: totalFrames,
            droppedFrames: droppedFrames,
            longestHitch: longestHitch,
            totalHitchTimeMs: hitchTimeMs,
            durationSeconds: duration,
            avgFrameTime: avgFrameTime
        )
    }

    // MARK: - Private Methods

    @objc private func displayLinkFired(_ link: CADisplayLink) {
        // 첫 프레임 스킵 (비교할 이전 타임스탬프 없음)
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
            // 정상 프레임 - streak 리셋
            currentHitchStreak = 0
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}

import Foundation
import QuartzCore

/// Image loading pipeline metrics
final class ImageLoadingMetrics {

    // MARK: - Counters

    private var requestCount: Int = 0
    private var cancelCount: Int = 0
    private var completeCount: Int = 0

    // MARK: - Latency tracking

    private var requestTimestamps: [String: CFTimeInterval] = [:]  // id -> start time
    private var latencies: [Double] = []  // completion latencies in ms

    // MARK: - In-flight tracking

    private var inFlightCount: Int = 0
    private var maxInFlight: Int = 0

    // MARK: - Timing

    private var startTime: CFTimeInterval = 0
    private var endTime: CFTimeInterval = 0

    // MARK: - Thread safety

    private let lock = NSLock()

    // MARK: - Control

    func start() {
        lock.lock()
        defer { lock.unlock() }

        requestCount = 0
        cancelCount = 0
        completeCount = 0
        requestTimestamps.removeAll()
        latencies.removeAll()
        inFlightCount = 0
        maxInFlight = 0
        startTime = CACurrentMediaTime()
        endTime = 0
    }

    func stop() -> ImageLoadingResult {
        lock.lock()
        defer { lock.unlock() }

        endTime = CACurrentMediaTime()
        let duration = endTime - startTime

        // Calculate latency stats
        let sortedLatencies = latencies.sorted()
        let avgLatency = latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
        let p95Latency = sortedLatencies.isEmpty ? 0 : sortedLatencies[Int(Double(sortedLatencies.count) * 0.95)]
        let maxLatency = sortedLatencies.last ?? 0

        return ImageLoadingResult(
            durationSeconds: duration,
            requestCount: requestCount,
            cancelCount: cancelCount,
            completeCount: completeCount,
            requestsPerSecond: duration > 0 ? Double(requestCount) / duration : 0,
            cancelsPerSecond: duration > 0 ? Double(cancelCount) / duration : 0,
            completesPerSecond: duration > 0 ? Double(completeCount) / duration : 0,
            avgLatencyMs: avgLatency,
            p95LatencyMs: p95Latency,
            maxLatencyMs: maxLatency,
            maxInFlight: maxInFlight
        )
    }

    // MARK: - Recording

    /// Call when image request starts
    func recordRequest(id: String) {
        lock.lock()
        defer { lock.unlock() }

        requestCount += 1
        requestTimestamps[id] = CACurrentMediaTime()
        inFlightCount += 1
        maxInFlight = max(maxInFlight, inFlightCount)
    }

    /// Call when image request is cancelled
    func recordCancel(id: String) {
        lock.lock()
        defer { lock.unlock() }

        cancelCount += 1
        requestTimestamps.removeValue(forKey: id)
        inFlightCount = max(0, inFlightCount - 1)
    }

    /// Call when image request completes
    func recordComplete(id: String) {
        lock.lock()
        defer { lock.unlock() }

        completeCount += 1

        if let startTime = requestTimestamps.removeValue(forKey: id) {
            let latency = (CACurrentMediaTime() - startTime) * 1000  // ms
            latencies.append(latency)
        }

        inFlightCount = max(0, inFlightCount - 1)
    }
}

// MARK: - Result

struct ImageLoadingResult {
    let durationSeconds: Double

    // Counts
    let requestCount: Int
    let cancelCount: Int
    let completeCount: Int

    // Rates (per second)
    let requestsPerSecond: Double
    let cancelsPerSecond: Double
    let completesPerSecond: Double

    // Latency (ms)
    let avgLatencyMs: Double
    let p95LatencyMs: Double
    let maxLatencyMs: Double

    // In-flight
    let maxInFlight: Int

    func formatted() -> String {
        """
        req/s: \(String(format: "%.1f", requestsPerSecond)) | cancel/s: \(String(format: "%.1f", cancelsPerSecond)) | complete/s: \(String(format: "%.1f", completesPerSecond))
        latency avg: \(String(format: "%.1f", avgLatencyMs))ms | p95: \(String(format: "%.1f", p95LatencyMs))ms | max: \(String(format: "%.1f", maxLatencyMs))ms
        maxInFlight: \(maxInFlight)
        """
    }
}

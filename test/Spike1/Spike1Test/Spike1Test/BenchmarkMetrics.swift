import Foundation

/// Benchmark metrics with percentile calculations
struct BenchmarkMetrics {
    private(set) var times: [Double] = []

    var count: Int { times.count }
    var p50: Double { percentile(50) }
    var p90: Double { percentile(90) }
    var p95: Double { percentile(95) }
    var max: Double { times.max() ?? 0 }
    var min: Double { times.min() ?? 0 }
    var avg: Double {
        guard !times.isEmpty else { return 0 }
        return times.reduce(0, +) / Double(times.count)
    }

    mutating func record(_ time: Double) {
        times.append(time)
    }

    mutating func reset() {
        times.removeAll()
    }

    private func percentile(_ p: Int) -> Double {
        guard !times.isEmpty else { return 0 }
        let sorted = times.sorted()
        let index = Int(Double(sorted.count - 1) * Double(p) / 100.0)
        return sorted[index]
    }

    func formatted() -> String {
        let p50Str = String(format: "%.2f", p50)
        let p90Str = String(format: "%.2f", p90)
        let p95Str = String(format: "%.2f", p95)
        let maxStr = String(format: "%.2f", max)
        return "p50: \(p50Str)ms  p90: \(p90Str)ms  p95: \(p95Str)ms  max: \(maxStr)ms"
    }
}

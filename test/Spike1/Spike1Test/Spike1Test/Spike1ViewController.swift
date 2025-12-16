import UIKit

// MARK: - Spike 1: Plan B - performBatchUpdates Benchmark (Level-based)

final class Spike1ViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private var identifiers: [String] = []  // 수동 배열 관리

    private let hitchMonitor = HitchMonitor()
    private let statusLabel = UILabel()

    // Delete mode: Direct only for Plan B (no coalescing needed for O(1) ops)
    private enum DeleteMode: String {
        case direct = "Direct"
        case batchCoalesce = "BatchCoalesce"  // 여러 삭제를 모아서 한번에
    }
    private var deleteMode: DeleteMode = .direct

    private var pendingDeletions: [(id: String, index: Int)] = []
    private var coalesceTimer: Timer?
    private let coalesceInterval: TimeInterval = 0.1

    // Flush callback for measurement
    private var onFlushCompleted: ((Double) -> Void)?

    // Results storage for table display
    private var allResults: [String: LevelResults] = [:]

    struct LevelResults {
        var l1_1: (metrics: BenchmarkMetrics, hitch: HitchResult)?
        var l1_2: Double?
        var l2_1: (metrics: BenchmarkMetrics, hitch: HitchResult)?  // 빠른 간격 삭제 (0.5초)
        var l2_2: (metrics: BenchmarkMetrics, hitch: HitchResult)?  // 연속 삭제 (0.3초)
        var l3_1: (metrics: BenchmarkMetrics, hitch: HitchResult)?
        var l3_2: (metrics: BenchmarkMetrics, hitch: HitchResult)?
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        updateTitle()

        // Left: Mode toggle
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Mode: Direct",
            style: .plain,
            target: self,
            action: #selector(toggleMode)
        )

        // Data count buttons
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "50k", style: .plain, target: self, action: #selector(run50k)),
            UIBarButtonItem(title: "10k", style: .plain, target: self, action: #selector(run10k)),
            UIBarButtonItem(title: "5k", style: .plain, target: self, action: #selector(run5k)),
            UIBarButtonItem(title: "1k", style: .plain, target: self, action: #selector(run1k))
        ]

        // Status label
        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Plan B: performBatchUpdates"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func updateTitle() {
        title = "Spike 1 Plan B [\(deleteMode.rawValue)]"
    }

    @objc private func toggleMode() {
        switch deleteMode {
        case .direct:
            deleteMode = .batchCoalesce
        case .batchCoalesce:
            deleteMode = .direct
        }
        navigationItem.leftBarButtonItem?.title = "Mode: \(deleteMode.rawValue)"
        updateTitle()
        print("\n=== Delete mode: \(deleteMode.rawValue) ===\n")
    }

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self  // Plan B: 직접 dataSource 구현
        collectionView.register(UICollectionViewCell.self, forCellWithReuseIdentifier: "Cell")
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8)
        ])
    }

    private func createLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1/3), heightDimension: .fractionalWidth(1/3))
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)

        let groupSize = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1.0), heightDimension: .fractionalWidth(1/3))
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }

    // MARK: - UICollectionViewDataSource (Plan B)

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return identifiers.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "Cell", for: indexPath)
        cell.backgroundColor = .systemGray5
        cell.contentView.subviews.forEach { $0.removeFromSuperview() }

        let label = UILabel()
        label.text = String(identifiers[indexPath.item].suffix(4))
        label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textAlignment = .center
        label.frame = cell.contentView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        cell.contentView.addSubview(label)

        return cell
    }

    // MARK: - Actions

    @objc private func run1k() { runAllLevels(count: 1_000, key: "1k") }
    @objc private func run5k() { runAllLevels(count: 5_000, key: "5k") }
    @objc private func run10k() { runAllLevels(count: 10_000, key: "10k") }
    @objc private func run50k() { runAllLevels(count: 50_000, key: "50k") }

    // MARK: - Run All Levels

    private func runAllLevels(count: Int, key: String) {
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }

        allResults[key] = LevelResults()
        title = "Running \(key)..."
        statusLabel.text = "Running \(key)..."
        print("\n" + String(repeating: "=", count: 50))
        print("=== \(key) Benchmark Start (Plan B) ===")
        print(String(repeating: "=", count: 50))

        resetAndLoad(count: count) { [weak self] in
            self?.runL1(key: key) {
                self?.resetAndLoad(count: count) {
                    self?.runL2(key: key) {
                        self?.resetAndLoad(count: count) {
                            self?.runL3(key: key) {
                                self?.updateTitle()
                                self?.statusLabel.text = "\(key) Complete - Check console log"
                                self?.navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
                                self?.printFinalResults(key: key)
                            }
                        }
                    }
                }
            }
        }
    }

    private func resetAndLoad(count: Int, completion: @escaping () -> Void) {
        let loadTime = measureTime {
            identifiers = (0..<count).map { "asset_\($0)" }
            collectionView.reloadData()
        }
        print("Load \(count): \(String(format: "%.1f", loadTime))ms")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: completion)
    }

    // MARK: - Level 1

    private func runL1(key: String, completion: @escaping () -> Void) {
        title = "\(key) L1..."

        runL1_1_StillSingleDelete { [weak self] metrics, hitch in
            self?.allResults[key]?.l1_1 = (metrics, hitch)
            print("  L1-1 done: p95=\(String(format: "%.2f", metrics.p95))ms, hitch=\(String(format: "%.1f", hitch.hitchTimeRatio)) ms/s")

            self?.runL1_2_BatchDelete { time in
                self?.allResults[key]?.l1_2 = time
                print("  L1-2 done: \(String(format: "%.2f", time))ms")
                completion()
            }
        }
    }

    private func runL1_1_StillSingleDelete(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 10
        var currentIteration = 0

        if deleteMode != .direct {
            print("    [L1-1] Note: Using Direct mode (\(deleteMode.rawValue) skipped for L1)")
        }

        hitchMonitor.start()

        func deleteNext() {
            guard currentIteration < iterations, !identifiers.isEmpty else {
                let hitchResult = hitchMonitor.stop()
                completion(metrics, hitchResult)
                return
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, !self.identifiers.isEmpty else {
                    let hitchResult = self?.hitchMonitor.stop() ?? HitchResult(renderedFrames: 0, droppedFrames: 0, longestHitch: 0, totalHitchTimeMs: 0, durationSeconds: 0, avgFrameTime: 0.01667)
                    completion(metrics, hitchResult)
                    return
                }

                let index = self.identifiers.count - 1
                let time = self.deleteDirectly(at: index)
                metrics.record(time)
                currentIteration += 1
                deleteNext()
            }
        }

        deleteNext()
    }

    private func runL1_2_BatchDelete(completion: @escaping (Double) -> Void) {
        guard identifiers.count >= 100 else {
            completion(0)
            return
        }

        let deleteCount = 100
        let startIndex = identifiers.count - deleteCount

        let time = measureTime {
            let indexPaths = (startIndex..<identifiers.count).map { IndexPath(item: $0, section: 0) }
            identifiers.removeLast(deleteCount)
            collectionView.performBatchUpdates {
                collectionView.deleteItems(at: indexPaths)
            }
        }

        completion(time)
    }

    // MARK: - Level 2

    private func runL2(key: String, completion: @escaping () -> Void) {
        title = "\(key) L2..."

        // L2-1: 빠른 간격 삭제 (0.5초 간격, 20회)
        runL2_1_FastIntervalDelete { [weak self] metrics, hitch in
            self?.allResults[key]?.l2_1 = (metrics, hitch)
            print("  L2-1 done: p95=\(String(format: "%.2f", metrics.p95))ms, hitch=\(String(format: "%.1f", hitch.hitchTimeRatio)) ms/s")

            self?.runL2_2_FastTempoDelete { metrics2, hitch2 in
                self?.allResults[key]?.l2_2 = (metrics2, hitch2)
                print("  L2-2 done: p95=\(String(format: "%.2f", metrics2.p95))ms, hitch=\(String(format: "%.1f", hitch2.hitchTimeRatio)) ms/s")
                completion()
            }
        }
    }

    /// L2-1: 빠른 간격 삭제 (0.5초 간격, 20회) - 현실적인 빠른 템포
    private func runL2_1_FastIntervalDelete(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 20
        var currentIteration = 0

        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { time in
                metrics.record(time)
            }
        }

        hitchMonitor.start()

        func deleteNext() {
            guard currentIteration < iterations, !identifiers.isEmpty else {
                flushDeletions()
                onFlushCompleted = nil
                let hitchResult = hitchMonitor.stop()
                completion(metrics, hitchResult)
                return
            }

            // 0.5초 간격으로 삭제 (스크롤 없음)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self, !self.identifiers.isEmpty else {
                    self?.flushDeletions()
                    self?.onFlushCompleted = nil
                    let hitchResult = self?.hitchMonitor.stop() ?? HitchResult(renderedFrames: 0, droppedFrames: 0, longestHitch: 0, totalHitchTimeMs: 0, durationSeconds: 0, avgFrameTime: 0.01667)
                    completion(metrics, hitchResult)
                    return
                }

                let index = self.identifiers.count - 1
                let time = self.performDelete(at: index)
                if self.deleteMode == .direct && time > 0 { metrics.record(time) }
                currentIteration += 1
                deleteNext()
            }
        }

        deleteNext()
    }

    private func runL2_2_FastTempoDelete(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 20
        var currentIteration = 0

        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { time in
                metrics.record(time)
            }
        }

        hitchMonitor.start()

        func deleteNext() {
            guard currentIteration < iterations, !identifiers.isEmpty else {
                flushDeletions()
                onFlushCompleted = nil
                let hitchResult = hitchMonitor.stop()
                completion(metrics, hitchResult)
                return
            }

            let index = identifiers.count - 1
            let time = performDelete(at: index)
            if deleteMode == .direct && time > 0 { metrics.record(time) }
            currentIteration += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                deleteNext()
            }
        }

        deleteNext()
    }

    // MARK: - Level 3

    private func runL3(key: String, completion: @escaping () -> Void) {
        title = "\(key) L3..."

        runL3_1_DeceleratingConsecutive { [weak self] metrics, hitch in
            self?.allResults[key]?.l3_1 = (metrics, hitch)
            print("  L3-1 done: p95=\(String(format: "%.2f", metrics.p95))ms, hitch=\(String(format: "%.1f", hitch.hitchTimeRatio)) ms/s")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.runL3_2_ExtremeConsecutive { metrics2, hitch2 in
                    self?.allResults[key]?.l3_2 = (metrics2, hitch2)
                    print("  L3-2 done: p95=\(String(format: "%.2f", metrics2.p95))ms, hitch=\(String(format: "%.1f", hitch2.hitchTimeRatio)) ms/s")
                    completion()
                }
            }
        }
    }

    private func runL3_1_DeceleratingConsecutive(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 20

        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { time in
                metrics.record(time)
            }
        }

        let middleIndex = identifiers.count / 2
        if middleIndex > 0 {
            collectionView.scrollToItem(at: IndexPath(item: middleIndex, section: 0), at: .centeredVertically, animated: true)
        }

        hitchMonitor.start()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }

            for _ in 0..<iterations {
                guard !self.identifiers.isEmpty else { break }

                let index = self.identifiers.count - 1
                let time = self.performDelete(at: index)
                if self.deleteMode == .direct && time > 0 { metrics.record(time) }
            }

            self.flushDeletions()
            self.onFlushCompleted = nil
            let hitchResult = self.hitchMonitor.stop()
            completion(metrics, hitchResult)
        }
    }

    private func runL3_2_ExtremeConsecutive(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 20
        var currentIteration = 0

        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { time in
                metrics.record(time)
            }
        }

        hitchMonitor.start()

        func deleteNext() {
            guard currentIteration < iterations, !identifiers.isEmpty else {
                flushDeletions()
                onFlushCompleted = nil
                let hitchResult = hitchMonitor.stop()
                completion(metrics, hitchResult)
                return
            }

            let index = identifiers.count - 1
            let time = performDelete(at: index)
            if deleteMode == .direct && time > 0 { metrics.record(time) }
            currentIteration += 1

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                deleteNext()
            }
        }

        deleteNext()
    }

    // MARK: - Results Logging

    private func printFinalResults(key: String) {
        guard let r = allResults[key] else { return }

        print("\n" + String(repeating: "=", count: 50))
        print("=== \(key) FINAL RESULTS (Plan B) ===")
        print(String(repeating: "=", count: 50))

        // Level 1
        print("\n[L1] Realistic (정지 상태)")
        if let l1 = r.l1_1 {
            print("  L1-1 단일 삭제 (10회, 1.5초 간격):")
            print("    p50: \(fmt(l1.metrics.p50))ms  p90: \(fmt(l1.metrics.p90))ms  p95: \(fmt(l1.metrics.p95))ms  max: \(fmt(l1.metrics.max))ms")
            print("    hitch: \(fmt(l1.hitch.hitchTimeRatio)) ms/s [\(l1.hitch.appleGrade)], longest: \(l1.hitch.longestHitch) (\(fmt(l1.hitch.longestHitchMs))ms)")
            print("    \(evaluateL1(l1.hitch))")
        }
        if let l1_2 = r.l1_2 {
            print("  L1-2 배치 삭제 (100장): \(fmt(l1_2))ms")
        }

        // Level 2
        print("\n[L2] Edge (빠른 템포)")
        if let l2_1 = r.l2_1 {
            print("  L2-1 빠른 간격 삭제 (0.5초, 20회):")
            print("    p50: \(fmt(l2_1.metrics.p50))ms  p90: \(fmt(l2_1.metrics.p90))ms  p95: \(fmt(l2_1.metrics.p95))ms  max: \(fmt(l2_1.metrics.max))ms")
            print("    hitch: \(fmt(l2_1.hitch.hitchTimeRatio)) ms/s [\(l2_1.hitch.appleGrade)], longest: \(l2_1.hitch.longestHitch) (\(fmt(l2_1.hitch.longestHitchMs))ms)")
        }
        if let l2_2 = r.l2_2 {
            print("  L2-2 연속 삭제 (0.3초, 20회):")
            print("    p50: \(fmt(l2_2.metrics.p50))ms  p90: \(fmt(l2_2.metrics.p90))ms  p95: \(fmt(l2_2.metrics.p95))ms  max: \(fmt(l2_2.metrics.max))ms")
            print("    hitch: \(fmt(l2_2.hitch.hitchTimeRatio)) ms/s [\(l2_2.hitch.appleGrade)], longest: \(l2_2.hitch.longestHitch) (\(fmt(l2_2.hitch.longestHitchMs))ms)")
        }
        print("    \(evaluateL2(r.l2_1?.hitch, r.l2_2?.hitch))")

        // Level 3
        print("\n[L3] Stress (회귀 기준)")
        if let l3_1 = r.l3_1 {
            print("  L3-1 감속 중 연속 삭제 (20회):")
            print("    p50: \(fmt(l3_1.metrics.p50))ms  p90: \(fmt(l3_1.metrics.p90))ms  p95: \(fmt(l3_1.metrics.p95))ms  max: \(fmt(l3_1.metrics.max))ms")
            print("    hitch: \(fmt(l3_1.hitch.hitchTimeRatio)) ms/s [\(l3_1.hitch.appleGrade)], longest: \(l3_1.hitch.longestHitch) (\(fmt(l3_1.hitch.longestHitchMs))ms)")
        }
        if let l3_2 = r.l3_2 {
            print("  L3-2 극한 연속 삭제 (20회/2초):")
            print("    p50: \(fmt(l3_2.metrics.p50))ms  p90: \(fmt(l3_2.metrics.p90))ms  p95: \(fmt(l3_2.metrics.p95))ms  max: \(fmt(l3_2.metrics.max))ms")
            print("    hitch: \(fmt(l3_2.hitch.hitchTimeRatio)) ms/s [\(l3_2.hitch.appleGrade)], longest: \(l3_2.hitch.longestHitch) (\(fmt(l3_2.hitch.longestHitchMs))ms)")
        }
        print("    📊 회귀 기준선 기록")

        print("\n" + String(repeating: "=", count: 50))
    }

    private func fmt(_ value: Double) -> String {
        String(format: "%.2f", value)
    }

    private func evaluateL1(_ hitch: HitchResult) -> String {
        let longestMs = fmt(hitch.longestHitchMs)
        if hitch.hitchTimeRatio < 5.0 && hitch.longestHitch <= 2 {
            return "✅ PASS [Good]"
        }
        if hitch.hitchTimeRatio < 10.0 {
            return "⚠️ WARNING (\(fmt(hitch.hitchTimeRatio)) ms/s, longest: \(hitch.longestHitch) (\(longestMs)ms))"
        }
        return "❌ FAIL [Critical] (\(fmt(hitch.hitchTimeRatio)) ms/s, longest: \(hitch.longestHitch) (\(longestMs)ms))"
    }

    private func evaluateL2(_ h1: HitchResult?, _ h2: HitchResult?) -> String {
        guard let h1 = h1 else { return "-" }
        let maxRatio = max(h1.hitchTimeRatio, h2?.hitchTimeRatio ?? 0)
        let maxLongest = max(h1.longestHitch, h2?.longestHitch ?? 0)
        let maxLongestMs = max(h1.longestHitchMs, h2?.longestHitchMs ?? 0)

        if maxRatio < 10.0 && maxLongest <= 3 {
            return "✅ PASS"
        }
        return "⚠️ REVIEW [Critical] (\(fmt(maxRatio)) ms/s, longest: \(maxLongest) (\(fmt(maxLongestMs))ms))"
    }

    // MARK: - Helpers

    private func measureTime(_ block: () -> Void) -> Double {
        let start = CACurrentMediaTime()
        block()
        let end = CACurrentMediaTime()
        return (end - start) * 1000
    }

    // MARK: - Delete Methods (Plan B: performBatchUpdates)

    private func performDelete(at index: Int) -> Double {
        switch deleteMode {
        case .direct:
            return deleteDirectly(at: index)
        case .batchCoalesce:
            return queueDeletion(at: index)
        }
    }

    /// Plan B 핵심: 인덱스 기반 증분 삭제 - O(1)
    private func deleteDirectly(at index: Int) -> Double {
        guard index >= 0 && index < identifiers.count else { return 0 }

        return measureTime {
            identifiers.remove(at: index)
            collectionView.performBatchUpdates {
                collectionView.deleteItems(at: [IndexPath(item: index, section: 0)])
            }
        }
    }

    private func queueDeletion(at index: Int) -> Double {
        guard index >= 0 && index < identifiers.count else { return 0 }

        let id = identifiers[index]
        pendingDeletions.append((id: id, index: index))

        coalesceTimer?.invalidate()
        coalesceTimer = Timer.scheduledTimer(withTimeInterval: coalesceInterval, repeats: false) { [weak self] _ in
            self?.flushDeletions()
        }

        return 0
    }

    @discardableResult
    private func flushDeletions() -> Double {
        guard !pendingDeletions.isEmpty else { return 0 }

        let count = pendingDeletions.count

        // 인덱스를 내림차순 정렬하여 삭제 (뒤에서부터 삭제해야 인덱스 꼬임 방지)
        let sortedDeletions = pendingDeletions.sorted { $0.index > $1.index }

        let time = measureTime {
            var indexPaths: [IndexPath] = []
            for deletion in sortedDeletions {
                if let actualIndex = identifiers.firstIndex(of: deletion.id) {
                    identifiers.remove(at: actualIndex)
                    indexPaths.append(IndexPath(item: actualIndex, section: 0))
                }
            }

            if !indexPaths.isEmpty {
                collectionView.performBatchUpdates {
                    collectionView.deleteItems(at: indexPaths)
                }
            }
        }

        print("    [Coalesce] Flushed \(count) deletions in \(String(format: "%.2f", time))ms")
        pendingDeletions.removeAll()

        onFlushCompleted?(time)

        return time
    }

    // MARK: - UIScrollViewDelegate

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        flushIfNeeded()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            flushIfNeeded()
        }
    }

    private func flushIfNeeded() {
        guard deleteMode == .batchCoalesce, !pendingDeletions.isEmpty else { return }
        print("    [BatchCoalesce] Scroll stopped, flushing \(pendingDeletions.count) pending deletions")
        flushDeletions()
    }
}

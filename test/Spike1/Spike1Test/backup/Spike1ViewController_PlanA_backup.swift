import UIKit

// MARK: - Spike 1: DiffableDataSource Benchmark (Level-based)

final class Spike1ViewController: UIViewController, UICollectionViewDelegate {

    typealias DataSource = UICollectionViewDiffableDataSource<Int, String>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Int, String>

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private var dataSource: DataSource!
    private var identifiers: [String] = []

    private let hitchMonitor = HitchMonitor()
    private let statusLabel = UILabel()

    // Delete mode: Direct / Coalescing / Deferred
    private enum DeleteMode: String {
        case direct = "Direct"
        case coalescing = "Coalesce"
        case deferred = "Deferred"  // Wait until scroll stops
    }
    private var deleteMode: DeleteMode = .direct

    private var pendingDeletions: [String] = []
    private var coalesceTimer: Timer?
    private let coalesceInterval: TimeInterval = 0.1  // 100ms debounce

    // Flush callback for measurement
    private var onFlushCompleted: ((Double) -> Void)?

    // For backward compatibility
    private var useCoalescing: Bool {
        deleteMode == .coalescing
    }

    // Results storage for table display
    private var allResults: [String: LevelResults] = [:]  // "1k" -> results

    struct LevelResults {
        var l1_1: (metrics: BenchmarkMetrics, hitch: HitchResult)?
        var l1_2: Double?  // batch delete time
        var l2_1: (metrics: BenchmarkMetrics, hitch: HitchResult)?
        var l2_2: (metrics: BenchmarkMetrics, hitch: HitchResult)?
        var l3_1: (metrics: BenchmarkMetrics, hitch: HitchResult)?
        var l3_2: (metrics: BenchmarkMetrics, hitch: HitchResult)?
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
        setupDataSource()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground
        updateTitle()

        // Left: Mode toggle (Direct → Coalesce → Deferred)
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Mode: Direct",
            style: .plain,
            target: self,
            action: #selector(toggleMode)
        )

        // Data count buttons (1k, 5k, 10k, 50k)
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "50k", style: .plain, target: self, action: #selector(run50k)),
            UIBarButtonItem(title: "10k", style: .plain, target: self, action: #selector(run10k)),
            UIBarButtonItem(title: "5k", style: .plain, target: self, action: #selector(run5k)),
            UIBarButtonItem(title: "1k", style: .plain, target: self, action: #selector(run1k))
        ]

        // Status label (bottom)
        statusLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.text = "Select count to run benchmark"
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func updateTitle() {
        title = "Spike 1 [\(deleteMode.rawValue)]"
    }

    @objc private func toggleMode() {
        // Cycle: Direct → Coalesce → Deferred → Direct
        switch deleteMode {
        case .direct:
            deleteMode = .coalescing
        case .coalescing:
            deleteMode = .deferred
        case .deferred:
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
        collectionView.delegate = self  // For scroll state detection (Deferred mode)
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

    private func setupDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<UICollectionViewCell, String> { cell, indexPath, identifier in
            cell.backgroundColor = .systemGray5
            cell.contentView.subviews.forEach { $0.removeFromSuperview() }

            let label = UILabel()
            label.text = String(identifier.suffix(4))
            label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
            label.textAlignment = .center
            label.frame = cell.contentView.bounds
            label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            cell.contentView.addSubview(label)
        }

        dataSource = DataSource(collectionView: collectionView) { collectionView, indexPath, identifier in
            collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: identifier)
        }
    }

    // MARK: - Actions

    @objc private func run1k() { runAllLevels(count: 1_000, key: "1k") }
    @objc private func run5k() { runAllLevels(count: 5_000, key: "5k") }
    @objc private func run10k() { runAllLevels(count: 10_000, key: "10k") }
    @objc private func run50k() { runAllLevels(count: 50_000, key: "50k") }

    // MARK: - Run All Levels Sequentially

    private func runAllLevels(count: Int, key: String) {
        // Disable buttons during test
        navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }

        allResults[key] = LevelResults()
        title = "Running \(key)..."
        statusLabel.text = "Running \(key)..."
        print("\n" + String(repeating: "=", count: 50))
        print("=== \(key) Benchmark Start ===")
        print(String(repeating: "=", count: 50))

        resetAndLoad(count: count) { [weak self] in
            self?.runL1(key: key) {
                self?.resetAndLoad(count: count) {
                    self?.runL2(key: key) {
                        self?.resetAndLoad(count: count) {
                            self?.runL3(key: key) {
                                self?.title = "Spike 1: DiffableDataSource"
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
            var snapshot = Snapshot()
            snapshot.appendSections([0])
            snapshot.appendItems(identifiers)
            dataSource.apply(snapshot, animatingDifferences: false)
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
        let iterations = 10  // 10회 × 1.5초 = 15초
        var currentIteration = 0

        // L1: Always use Direct mode (coalescing/deferred has no meaning for 1-2s intervals)
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

            // L1-1: 1.5초 간격 (현실적인 단일 삭제 패턴)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                guard let self = self, !self.identifiers.isEmpty else {
                    let hitchResult = self?.hitchMonitor.stop() ?? HitchResult(renderedFrames: 0, droppedFrames: 0, longestHitch: 0, totalHitchTimeMs: 0, durationSeconds: 0, baseline: 0)
                    completion(metrics, hitchResult)
                    return
                }

                let idToDelete = self.identifiers.removeLast()
                // Always Direct for L1
                let time = self.deleteDirectly(idToDelete)
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
        let idsToDelete = Array(identifiers.suffix(deleteCount))

        let time = measureTime {
            var snapshot = dataSource.snapshot()
            snapshot.deleteItems(idsToDelete)
            dataSource.apply(snapshot, animatingDifferences: false)
        }

        identifiers.removeLast(deleteCount)
        completion(time)
    }

    // MARK: - Level 2

    private func runL2(key: String, completion: @escaping () -> Void) {
        title = "\(key) L2..."

        runL2_1_DeceleratingDelete { [weak self] metrics, hitch in
            self?.allResults[key]?.l2_1 = (metrics, hitch)
            print("  L2-1 done: p95=\(String(format: "%.2f", metrics.p95))ms, hitch=\(String(format: "%.1f", hitch.hitchTimeRatio)) ms/s")

            self?.runL2_2_FastTempoDelete { metrics2, hitch2 in
                self?.allResults[key]?.l2_2 = (metrics2, hitch2)
                print("  L2-2 done: p95=\(String(format: "%.2f", metrics2.p95))ms, hitch=\(String(format: "%.1f", hitch2.hitchTimeRatio)) ms/s")
                completion()
            }
        }
    }

    private func runL2_1_DeceleratingDelete(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 20
        var currentIteration = 0

        // Set up flush callback for non-direct modes
        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { [weak self] time in
                metrics.record(time)
            }
        }

        hitchMonitor.start()

        func deleteNext() {
            guard currentIteration < iterations, !identifiers.isEmpty else {
                flushDeletions()  // Flush any pending
                onFlushCompleted = nil  // Clean up
                let hitchResult = hitchMonitor.stop()
                completion(metrics, hitchResult)
                return
            }

            let middleIndex = identifiers.count / 2
            if middleIndex > 0 {
                collectionView.scrollToItem(at: IndexPath(item: middleIndex, section: 0), at: .centeredVertically, animated: true)
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self = self, !self.identifiers.isEmpty else {
                    self?.flushDeletions()  // Flush any pending
                    self?.onFlushCompleted = nil
                    let hitchResult = self?.hitchMonitor.stop() ?? HitchResult(renderedFrames: 0, droppedFrames: 0, longestHitch: 0, totalHitchTimeMs: 0, durationSeconds: 0, baseline: 0)
                    completion(metrics, hitchResult)
                    return
                }

                let idToDelete = self.identifiers.removeLast()
                let time = self.performDelete(idToDelete)
                // Direct mode: record immediately, Others: recorded via callback
                if self.deleteMode == .direct && time > 0 { metrics.record(time) }
                currentIteration += 1

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    deleteNext()
                }
            }
        }

        deleteNext()
    }

    private func runL2_2_FastTempoDelete(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 20
        var currentIteration = 0

        // Set up flush callback for non-direct modes
        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { [weak self] time in
                metrics.record(time)
            }
        }

        hitchMonitor.start()

        func deleteNext() {
            guard currentIteration < iterations, !identifiers.isEmpty else {
                flushDeletions()  // Flush any pending
                onFlushCompleted = nil  // Clean up
                let hitchResult = hitchMonitor.stop()
                completion(metrics, hitchResult)
                return
            }

            let idToDelete = identifiers.removeLast()
            let time = performDelete(idToDelete)
            // Direct mode: record immediately, Others: recorded via callback
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

        // Set up flush callback for non-direct modes
        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { [weak self] time in
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

                let idToDelete = self.identifiers.removeLast()
                let time = self.performDelete(idToDelete)
                // Direct mode: record immediately, Others: recorded via callback
                if self.deleteMode == .direct && time > 0 { metrics.record(time) }
            }

            self.flushDeletions()  // Flush any pending
            self.onFlushCompleted = nil  // Clean up
            let hitchResult = self.hitchMonitor.stop()
            completion(metrics, hitchResult)
        }
    }

    private func runL3_2_ExtremeConsecutive(completion: @escaping (BenchmarkMetrics, HitchResult) -> Void) {
        var metrics = BenchmarkMetrics()
        let iterations = 20
        var currentIteration = 0

        // Set up flush callback for non-direct modes
        let needsCallback = deleteMode != .direct
        if needsCallback {
            onFlushCompleted = { [weak self] time in
                metrics.record(time)
            }
        }

        hitchMonitor.start()

        func deleteNext() {
            guard currentIteration < iterations, !identifiers.isEmpty else {
                flushDeletions()  // Flush any pending
                onFlushCompleted = nil  // Clean up
                let hitchResult = hitchMonitor.stop()
                completion(metrics, hitchResult)
                return
            }

            let idToDelete = identifiers.removeLast()
            let time = performDelete(idToDelete)
            // Direct mode: record immediately, Others: recorded via callback
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
        print("=== \(key) FINAL RESULTS ===")
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
        print("\n[L2] Edge (감속 중/빠른 템포)")
        if let l2_1 = r.l2_1 {
            print("  L2-1 감속 중 삭제 (20회):")
            print("    p50: \(fmt(l2_1.metrics.p50))ms  p90: \(fmt(l2_1.metrics.p90))ms  p95: \(fmt(l2_1.metrics.p95))ms  max: \(fmt(l2_1.metrics.max))ms")
            print("    hitch: \(fmt(l2_1.hitch.hitchTimeRatio)) ms/s [\(l2_1.hitch.appleGrade)], longest: \(l2_1.hitch.longestHitch) (\(fmt(l2_1.hitch.longestHitchMs))ms)")
        }
        if let l2_2 = r.l2_2 {
            print("  L2-2 빠른 템포 삭제 (20회):")
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
        // Apple 기준: < 5 ms/s = Good
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

        // Apple 기준: < 10 ms/s = Warning 이하
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

    // MARK: - Delete Modes

    /// Perform delete based on current mode
    /// Returns the time taken (0 if deferred/coalesced and not yet flushed)
    private func performDelete(_ idToDelete: String) -> Double {
        switch deleteMode {
        case .direct:
            return deleteDirectly(idToDelete)
        case .coalescing:
            return queueDeletionCoalesced(idToDelete)
        case .deferred:
            return queueDeletionDeferred(idToDelete)
        }
    }

    /// Queue deletion with timer-based coalescing
    private func queueDeletionCoalesced(_ id: String) -> Double {
        pendingDeletions.append(id)

        // Reset timer
        coalesceTimer?.invalidate()
        coalesceTimer = Timer.scheduledTimer(withTimeInterval: coalesceInterval, repeats: false) { [weak self] _ in
            self?.flushDeletions()
        }

        return 0  // No immediate apply, so time is 0
    }

    /// Queue deletion for deferred apply (wait until scroll stops)
    private func queueDeletionDeferred(_ id: String) -> Double {
        pendingDeletions.append(id)

        // Check scroll state - if not scrolling, flush immediately
        let isScrolling = collectionView.isDragging || collectionView.isDecelerating
        if !isScrolling {
            // Not scrolling - flush immediately like direct mode
            return flushDeletions()
        }

        // Scrolling - will be flushed when scroll stops (via scrollViewDidEndDecelerating)
        print("    [Deferred] Queued deletion (scroll in progress), pending: \(pendingDeletions.count)")
        return 0
    }

    /// Flush all pending deletions at once
    @discardableResult
    private func flushDeletions() -> Double {
        guard !pendingDeletions.isEmpty else { return 0 }

        let count = pendingDeletions.count
        let time = measureTime {
            var snapshot = dataSource.snapshot()
            snapshot.deleteItems(pendingDeletions)
            dataSource.apply(snapshot, animatingDifferences: false)
        }

        print("    [Coalesce] Flushed \(count) deletions in \(String(format: "%.2f", time))ms")
        pendingDeletions.removeAll()

        // Notify callback for metrics recording
        onFlushCompleted?(time)

        return time
    }

    /// Direct delete (no coalescing)
    private func deleteDirectly(_ id: String) -> Double {
        return measureTime {
            var snapshot = dataSource.snapshot()
            snapshot.deleteItems([id])
            dataSource.apply(snapshot, animatingDifferences: false)
        }
    }

    // MARK: - UIScrollViewDelegate (for Deferred mode)

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        flushIfDeferred()
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // Only flush if not going to decelerate (direct stop without momentum)
        if !decelerate {
            flushIfDeferred()
        }
    }

    private func flushIfDeferred() {
        guard deleteMode == .deferred, !pendingDeletions.isEmpty else { return }
        print("    [Deferred] Scroll stopped, flushing \(pendingDeletions.count) pending deletions")
        flushDeletions()
    }
}

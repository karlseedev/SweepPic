import UIKit

// MARK: - Spike 1: DiffableDataSource Benchmark
// 목적: DiffableDataSource가 10k/50k에서 8.3ms 예산을 지키는지 검증

final class Spike1ViewController: UIViewController {

    enum Section { case main }
    typealias DataSource = UICollectionViewDiffableDataSource<Section, String>
    typealias Snapshot = NSDiffableDataSourceSnapshot<Section, String>

    private var collectionView: UICollectionView!
    private var dataSource: DataSource!
    private var identifiers: [String] = []

    private let resultLabel = UILabel()
    private var benchmarkResults: [String] = []

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
        title = "Spike 1: DiffableDataSource"

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "50k", style: .plain, target: self, action: #selector(run50kBenchmark)),
            UIBarButtonItem(title: "10k", style: .plain, target: self, action: #selector(run10kBenchmark))
        ]

        resultLabel.numberOfLines = 0
        resultLabel.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        resultLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(resultLabel)

        NSLayoutConstraint.activate([
            resultLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            resultLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            resultLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
    }

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: resultLabel.topAnchor, constant: -8)
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

    // MARK: - Benchmark Actions

    @objc private func run10kBenchmark() {
        runBenchmark(count: 10_000)
    }

    @objc private func run50kBenchmark() {
        runBenchmark(count: 50_000)
    }

    private func runBenchmark(count: Int) {
        benchmarkResults = []
        benchmarkResults.append("=== Benchmark: \(count.formatted()) items ===\n")

        // 1. Initial Load
        let loadTime = measureTime {
            identifiers = (0..<count).map { "asset_\($0)" }
            var snapshot = Snapshot()
            snapshot.appendSections([.main])
            snapshot.appendItems(identifiers)
            dataSource.apply(snapshot, animatingDifferences: false)
        }
        benchmarkResults.append("1. Initial Load: \(loadTime)ms")
        checkThreshold(loadTime, scenario: "Initial Load")

        // 2. Batch Delete (100 items)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.runBatchDeleteBenchmark()
        }
    }

    private func runBatchDeleteBenchmark() {
        let deleteCount = 100
        let indicesToDelete = (0..<deleteCount).map { identifiers.count - 1 - $0 }
        let idsToDelete = indicesToDelete.map { identifiers[$0] }

        let batchDeleteTime = measureTime {
            var snapshot = dataSource.snapshot()
            snapshot.deleteItems(idsToDelete)
            dataSource.apply(snapshot, animatingDifferences: false)
        }

        // Update local array
        for id in idsToDelete {
            identifiers.removeAll { $0 == id }
        }

        benchmarkResults.append("2. Batch Delete (100): \(batchDeleteTime)ms")
        checkThreshold(batchDeleteTime, scenario: "Batch Delete")

        // 3. Consecutive Delete (20 times)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.runConsecutiveDeleteBenchmark()
        }
    }

    private func runConsecutiveDeleteBenchmark() {
        var times: [Double] = []

        for i in 0..<20 {
            guard !identifiers.isEmpty else { break }

            let idToDelete = identifiers.removeLast()
            let time = measureTime {
                var snapshot = dataSource.snapshot()
                snapshot.deleteItems([idToDelete])
                dataSource.apply(snapshot, animatingDifferences: false)
            }
            times.append(time)
        }

        let avgTime = times.reduce(0, +) / Double(times.count)
        let maxTime = times.max() ?? 0

        benchmarkResults.append("3. Consecutive Delete (20x):")
        benchmarkResults.append("   avg: \(String(format: "%.2f", avgTime))ms, max: \(String(format: "%.2f", maxTime))ms")
        checkThreshold(maxTime, scenario: "Consecutive Delete (max)")

        // 4. Delete while scrolling (simulated)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.runScrollDeleteBenchmark()
        }
    }

    private func runScrollDeleteBenchmark() {
        // Simulate scroll to middle
        let middleIndex = identifiers.count / 2
        if middleIndex > 0 {
            collectionView.scrollToItem(at: IndexPath(item: middleIndex, section: 0), at: .centeredVertically, animated: false)
        }

        var times: [Double] = []

        // Delete while "scrolling" (simulated by offset changes)
        for i in 0..<10 {
            guard identifiers.count > middleIndex else { break }

            // Simulate scroll
            let currentOffset = collectionView.contentOffset
            collectionView.contentOffset = CGPoint(x: currentOffset.x, y: currentOffset.y + 50)

            let idToDelete = identifiers[middleIndex]
            identifiers.remove(at: middleIndex)

            let time = measureTime {
                var snapshot = dataSource.snapshot()
                snapshot.deleteItems([idToDelete])
                dataSource.apply(snapshot, animatingDifferences: false)
            }
            times.append(time)
        }

        let avgTime = times.reduce(0, +) / Double(times.count)
        let maxTime = times.max() ?? 0

        benchmarkResults.append("4. Delete while scroll (10x):")
        benchmarkResults.append("   avg: \(String(format: "%.2f", avgTime))ms, max: \(String(format: "%.2f", maxTime))ms")
        checkThreshold(maxTime, scenario: "Scroll Delete (max)")

        // Display results
        updateResultLabel()
    }

    // MARK: - Helpers

    private func measureTime(_ block: () -> Void) -> Double {
        let start = CACurrentMediaTime()
        block()
        let end = CACurrentMediaTime()
        return (end - start) * 1000 // Convert to milliseconds
    }

    private func checkThreshold(_ timeMs: Double, scenario: String) {
        let threshold = 8.3 // 120Hz frame budget
        let status = timeMs <= threshold ? "✅ PASS" : "⚠️ OVER"
        benchmarkResults.append("   \(status) (threshold: \(threshold)ms)")
    }

    private func updateResultLabel() {
        resultLabel.text = benchmarkResults.joined(separator: "\n")
        print("\n" + benchmarkResults.joined(separator: "\n"))
    }
}

import UIKit

// MARK: - Gate 2: Image Loading Test (Provider-based)

final class Gate2ViewController: UIViewController {

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private let provider: ImageProvider
    private let providerName: String

    private let hitchMonitor = HitchMonitor()
    private let loadingMetrics = ImageLoadingMetrics()
    private let statusLabel = UILabel()

    // Thumbnail settings
    private var thumbnailSize: CGSize = .zero
    private let scale = UIScreen.main.scale

    // Preheat window (±N rows)
    private var preheatWindow: Int = 2
    private var previousVisibleIndexes: Set<Int> = []

    // Request tokens for cancellation (prevent wrong image)
    private var activeRequests: [IndexPath: Cancellable] = [:]

    // Data scale options
    private let scaleOptions = [1_000, 5_000, 10_000, 50_000]
    private var currentScaleIndex = 3  // Default 50k

    // MARK: - Init

    init(provider: ImageProvider, name: String) {
        self.provider = provider
        self.providerName = name
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupCollectionView()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        calculateThumbnailSize()

        if provider.count == 0 {
            loadData()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Gate 2: \(providerName)"
        view.backgroundColor = .systemBackground

        // Navigation items
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Test", style: .plain, target: self, action: #selector(runScrollTest)),
            UIBarButtonItem(title: "±\(preheatWindow)", style: .plain, target: self, action: #selector(cyclePreheatWindow)),
            UIBarButtonItem(title: formatCount(scaleOptions[currentScaleIndex]), style: .plain, target: self, action: #selector(cycleScale))
        ]

        // Status label
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 3
        statusLabel.text = "Loading..."
        statusLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(statusLabel)

        NSLayoutConstraint.activate([
            statusLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            statusLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            statusLabel.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -8)
        ])
    }

    private func setupCollectionView() {
        let layout = createLayout()
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.prefetchDataSource = self
        collectionView.register(ImageCell.self, forCellWithReuseIdentifier: ImageCell.reuseID)
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: statusLabel.topAnchor, constant: -8)
        ])
    }

    private func createLayout() -> UICollectionViewLayout {
        let columns = 3
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0 / CGFloat(columns)),
            heightDimension: .fractionalWidth(1.0 / CGFloat(columns))
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        item.contentInsets = NSDirectionalEdgeInsets(top: 1, leading: 1, bottom: 1, trailing: 1)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(1.0 / CGFloat(columns))
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        return UICollectionViewCompositionalLayout(section: section)
    }

    private func calculateThumbnailSize() {
        let columns: CGFloat = 3
        let spacing: CGFloat = 2
        let availableWidth = view.bounds.width - (spacing * (columns - 1))
        let cellWidth = availableWidth / columns
        thumbnailSize = CGSize(width: cellWidth * scale, height: cellWidth * scale)
    }

    // MARK: - Data Loading

    private func loadData() {
        let targetCount = scaleOptions[currentScaleIndex]
        statusLabel.text = "Loading \(formatCount(targetCount))..."

        if let mockProvider = provider as? MockImageProvider {
            mockProvider.loadLibrary(count: targetCount) { [weak self] count, fetchTime in
                self?.onDataLoaded(count: count, fetchTime: fetchTime)
            }
        } else {
            provider.loadLibrary { [weak self] count, fetchTime in
                self?.onDataLoaded(count: count, fetchTime: fetchTime)
            }
        }
    }

    private func onDataLoaded(count: Int, fetchTime: Double) {
        title = "Gate 2: \(providerName) [\(formatCount(count))]"
        statusLabel.text = """
            \(providerName): \(formatCount(count)) items (fetch: \(String(format: "%.1f", fetchTime))ms)
            Preheat: ±\(preheatWindow) rows | Thumb: \(Int(thumbnailSize.width))px
            """

        collectionView.reloadData()

        print("\n=== Gate 2: \(providerName) ===")
        print("Items: \(count), Fetch time: \(String(format: "%.1f", fetchTime))ms")
        print("Thumbnail size: \(Int(thumbnailSize.width))x\(Int(thumbnailSize.height))")
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k"
        }
        return "\(count)"
    }

    // MARK: - Actions

    @objc private func cycleScale() {
        currentScaleIndex = (currentScaleIndex + 1) % scaleOptions.count
        let newScale = scaleOptions[currentScaleIndex]
        navigationItem.rightBarButtonItems?[2].title = formatCount(newScale)

        // Reload with new scale
        provider.stopCachingAll()
        activeRequests.removeAll()
        previousVisibleIndexes.removeAll()
        loadData()
    }

    @objc private func cyclePreheatWindow() {
        let windows = [0, 1, 2, 3, 4]
        if let currentIndex = windows.firstIndex(of: preheatWindow) {
            preheatWindow = windows[(currentIndex + 1) % windows.count]
        } else {
            preheatWindow = 2
        }
        navigationItem.rightBarButtonItems?[1].title = "±\(preheatWindow)"
        print("Preheat window: ±\(preheatWindow)")

        // Reset preheat
        previousVisibleIndexes.removeAll()
        updateCachedAssets()
    }

    @objc private func runScrollTest() {
        guard provider.count > 100 else {
            statusLabel.text = "Need more items for test"
            return
        }

        statusLabel.text = "Running scroll test..."
        print("\n=== Scroll Test Start (\(providerName), ±\(preheatWindow)) ===")

        // Scroll to top first
        collectionView.setContentOffset(.zero, animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.performScrollTest()
        }
    }

    private func performScrollTest() {
        hitchMonitor.start()
        loadingMetrics.start()

        // Scroll to middle
        let middleIndex = provider.count / 2
        collectionView.scrollToItem(
            at: IndexPath(item: middleIndex, section: 0),
            at: .centeredVertically,
            animated: true
        )

        // Wait for scroll + image loading to settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { [weak self] in
            guard let self = self else { return }

            let hitchResult = self.hitchMonitor.stop()
            let loadingResult = self.loadingMetrics.stop()

            let grade = hitchResult.appleGrade
            let emoji = grade == "Good" ? "✅" : (grade == "Warning" ? "⚠️" : "❌")

            self.statusLabel.text = """
                \(emoji) \(grade) | hitch: \(String(format: "%.1f", hitchResult.hitchTimeRatio)) ms/s
                req/s: \(String(format: "%.0f", loadingResult.requestsPerSecond)) | maxInFlight: \(loadingResult.maxInFlight)
                latency avg: \(String(format: "%.1f", loadingResult.avgLatencyMs))ms p95: \(String(format: "%.1f", loadingResult.p95LatencyMs))ms
                """

            print("\n=== Scroll Test Result ===")
            print("Provider: \(self.providerName), Preheat: ±\(self.preheatWindow)")
            print(hitchResult.formatted())
            print(loadingResult.formatted())
            print(emoji + " " + grade)
        }
    }

    // MARK: - Preheat (Caching)

    private func updateCachedAssets() {
        guard provider.count > 0, preheatWindow > 0 else { return }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return }

        let visibleIndexes = Set(visibleIndexPaths.map { $0.item })

        // Calculate preheat range
        let minVisible = visibleIndexes.min() ?? 0
        let maxVisible = visibleIndexes.max() ?? 0
        let columns = 3
        let preheatCount = preheatWindow * columns

        let preheatStart = max(0, minVisible - preheatCount)
        let preheatEnd = min(provider.count - 1, maxVisible + preheatCount)
        let preheatIndexes = Set(preheatStart...preheatEnd)

        // Diff
        let addedIndexes = preheatIndexes.subtracting(previousVisibleIndexes)
        let removedIndexes = previousVisibleIndexes.subtracting(preheatIndexes)

        if !addedIndexes.isEmpty {
            provider.startCaching(indexes: Array(addedIndexes), targetSize: thumbnailSize)
        }
        if !removedIndexes.isEmpty {
            provider.stopCaching(indexes: Array(removedIndexes), targetSize: thumbnailSize)
        }

        previousVisibleIndexes = preheatIndexes
    }
}

// MARK: - UICollectionViewDataSource

extension Gate2ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return provider.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ImageCell.reuseID, for: indexPath) as! ImageCell

        // Token for verification
        let identifier = provider.identifier(at: indexPath.item)

        // Cancel previous request (prevent wrong image)
        if activeRequests[indexPath] != nil {
            activeRequests[indexPath]?.cancel()
            activeRequests.removeValue(forKey: indexPath)
            loadingMetrics.recordCancel(id: identifier)
        }

        cell.representedIdentifier = identifier
        cell.imageView.image = nil

        // Record request start
        loadingMetrics.recordRequest(id: identifier)

        // Request image
        let request = provider.requestImage(at: indexPath.item, targetSize: thumbnailSize) { [weak self, weak cell] image in
            // Token verification: only apply if still same identifier
            guard cell?.representedIdentifier == identifier else { return }
            cell?.imageView.image = image

            // Record completion
            self?.loadingMetrics.recordComplete(id: identifier)
        }

        if let request = request {
            activeRequests[indexPath] = request
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension Gate2ViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        updateCachedAssets()
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension Gate2ViewController: UICollectionViewDataSourcePrefetching {
    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let indexes = indexPaths.map { $0.item }
        provider.startCaching(indexes: indexes, targetSize: thumbnailSize)
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let indexes = indexPaths.map { $0.item }
        provider.stopCaching(indexes: indexes, targetSize: thumbnailSize)
    }
}

// MARK: - ImageCell

final class ImageCell: UICollectionViewCell {
    static let reuseID = "ImageCell"

    let imageView = UIImageView()
    var representedIdentifier: String = ""

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupUI() {
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5
        imageView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        representedIdentifier = ""
    }
}

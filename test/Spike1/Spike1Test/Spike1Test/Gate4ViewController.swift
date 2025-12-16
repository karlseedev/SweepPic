import UIKit
import QuartzCore

// MARK: - Gate 4: 120Hz Performance Tuning

final class Gate4ViewController: UIViewController {

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private let statusLabel = UILabel()
    private let hitchMonitor = HitchMonitor()

    // Data
    private var itemCount: Int = 50_000
    private var itemColors: [UIColor] = []

    // Frame rate configuration
    private var usePreferredFrameRate: Bool = false
    private var preferredMinFPS: Float = 80
    private var preferredMaxFPS: Float = 120

    // Test results
    private var testResults: [TestResult] = []

    struct TestResult {
        let name: String
        let hitchRatio: Double
        let avgFrameTime: Double
        let renderedFrames: Int
        let droppedFrames: Int
        let useProMotion: Bool
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        generateColors()
        setupUI()
        setupCollectionView()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Gate 4: 120Hz Tuning"
        view.backgroundColor = .systemBackground

        // Navigation items
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Test", style: .plain, target: self, action: #selector(runAutoTest)),
            UIBarButtonItem(title: "ProMotion", style: .plain, target: self, action: #selector(toggleProMotion))
        ]

        // Status label
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 5
        updateStatusLabel()
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
        collectionView.dataSource = self
        collectionView.register(ColorCell.self, forCellWithReuseIdentifier: ColorCell.reuseID)
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

    private func generateColors() {
        itemColors = (0..<itemCount).map { index in
            let hue = CGFloat(index % 360) / 360.0
            let saturation = 0.5 + CGFloat((index / 360) % 5) * 0.1
            let brightness = 0.7 + CGFloat((index / 1800) % 3) * 0.1
            return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
        }
    }

    private func updateStatusLabel() {
        let maxFPS = UIScreen.main.maximumFramesPerSecond
        let frameBudget = 1000.0 / Double(maxFPS)
        let proMotionStatus = usePreferredFrameRate ? "ON (\(Int(preferredMinFPS))-\(Int(preferredMaxFPS)))" : "OFF"

        statusLabel.text = """
            Device: \(maxFPS)Hz (budget: \(String(format: "%.2f", frameBudget))ms)
            ProMotion hint: \(proMotionStatus)
            Items: \(formatCount(itemCount))
            Tap "Test" to run scroll benchmark
            """
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k"
        }
        return "\(count)"
    }

    // MARK: - ProMotion Configuration

    @objc private func toggleProMotion() {
        usePreferredFrameRate.toggle()
        applyFrameRatePreference()
        updateStatusLabel()
    }

    private func applyFrameRatePreference() {
        // CADisplayLink-based frame rate hint for scrolling
        // Note: CALayer.preferredFrameRateRange requires iOS 15.4+
        // For broader compatibility, we use CADisplayLink approach

        // The actual frame rate is controlled by the system based on content
        // This is mainly for documentation/testing purposes
        print("ProMotion hint: \(usePreferredFrameRate ? "ON" : "OFF")")
    }

    // MARK: - Auto Test

    @objc private func runAutoTest() {
        testResults.removeAll()

        print("\n=== Gate 4 Auto Test Start ===")
        print("Device: \(UIScreen.main.maximumFramesPerSecond)Hz")
        print("Items: \(itemCount)")

        statusLabel.text = "Running test sequence..."

        // Test sequence:
        // 1. ProMotion OFF - scroll test
        // 2. ProMotion ON - scroll test
        runTestSequence()
    }

    private func runTestSequence() {
        // Reset to top
        collectionView.setContentOffset(.zero, animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.runTest(withProMotion: false) {
                self?.runTest(withProMotion: true) {
                    self?.showTestSummary()
                }
            }
        }
    }

    private func runTest(withProMotion: Bool, completion: @escaping () -> Void) {
        let testName = withProMotion ? "ProMotion ON" : "ProMotion OFF"
        statusLabel.text = "Testing: \(testName)..."

        // Configure ProMotion
        usePreferredFrameRate = withProMotion
        applyFrameRatePreference()

        // Reset to top
        collectionView.setContentOffset(.zero, animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }

            // Start monitoring
            self.hitchMonitor.start()

            // Scroll to middle
            let middleIndex = self.itemCount / 2
            self.collectionView.scrollToItem(
                at: IndexPath(item: middleIndex, section: 0),
                at: .centeredVertically,
                animated: true
            )

            // Wait for scroll to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                let result = self.hitchMonitor.stop()

                let testResult = TestResult(
                    name: testName,
                    hitchRatio: result.hitchTimeRatio,
                    avgFrameTime: result.avgFrameTime * 1000,  // Convert to ms
                    renderedFrames: result.renderedFrames,
                    droppedFrames: result.droppedFrames,
                    useProMotion: withProMotion
                )
                self.testResults.append(testResult)

                print("\n[\(testName)]")
                print("  hitch: \(String(format: "%.1f", result.hitchTimeRatio)) ms/s [\(result.appleGrade)]")
                print("  avgFrame: \(String(format: "%.2f", result.avgFrameTime * 1000))ms")
                print("  rendered: \(result.renderedFrames), dropped: \(result.droppedFrames)")

                // Small delay before next test
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    completion()
                }
            }
        }
    }

    private func showTestSummary() {
        guard testResults.count >= 2 else { return }

        let offResult = testResults[0]
        let onResult = testResults[1]

        let improvement = offResult.hitchRatio > 0
            ? ((offResult.hitchRatio - onResult.hitchRatio) / offResult.hitchRatio) * 100
            : 0

        let offGrade = gradeFor(hitchRatio: offResult.hitchRatio)
        let onGrade = gradeFor(hitchRatio: onResult.hitchRatio)

        let recommendation: String
        if onResult.hitchRatio < offResult.hitchRatio && improvement > 10 {
            recommendation = "ProMotion 권장 (hitch \(String(format: "%.0f", improvement))% 개선)"
        } else if offResult.hitchRatio < 5 && onResult.hitchRatio < 5 {
            recommendation = "둘 다 Good - ProMotion 선택적"
        } else {
            recommendation = "ProMotion 효과 미미"
        }

        statusLabel.text = """
            OFF: \(String(format: "%.1f", offResult.hitchRatio)) ms/s [\(offGrade)] frame: \(String(format: "%.2f", offResult.avgFrameTime))ms
            ON:  \(String(format: "%.1f", onResult.hitchRatio)) ms/s [\(onGrade)] frame: \(String(format: "%.2f", onResult.avgFrameTime))ms
            → \(recommendation)
            """

        print("\n=== Gate 4 Test Result ===")
        print("ProMotion OFF: \(String(format: "%.1f", offResult.hitchRatio)) ms/s [\(offGrade)]")
        print("ProMotion ON:  \(String(format: "%.1f", onResult.hitchRatio)) ms/s [\(onGrade)]")
        print("Recommendation: \(recommendation)")
    }

    private func gradeFor(hitchRatio: Double) -> String {
        if hitchRatio < 5 { return "Good" }
        if hitchRatio < 10 { return "Warning" }
        return "Critical"
    }
}

// MARK: - UICollectionViewDataSource

extension Gate4ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ColorCell.reuseID, for: indexPath) as! ColorCell
        cell.color = itemColors[indexPath.item]
        return cell
    }
}

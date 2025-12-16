import UIKit

// MARK: - Gate 3: Pinch Zoom + Anchor Test

final class Gate3ViewController: UIViewController {

    // MARK: - Column Modes

    enum ColumnMode: Int, CaseIterable {
        case one = 1
        case three = 3
        case five = 5

        var next: ColumnMode {
            switch self {
            case .one: return .three
            case .three: return .five
            case .five: return .five  // Can't go further
            }
        }

        var prev: ColumnMode {
            switch self {
            case .one: return .one  // Can't go further
            case .three: return .one
            case .five: return .three
            }
        }
    }

    // MARK: - Properties

    private var collectionView: UICollectionView!
    private let statusLabel = UILabel()
    private let hitchMonitor = HitchMonitor()

    // Data
    private var itemCount: Int = 10_000
    private var itemColors: [UIColor] = []

    // Pinch state
    private var currentMode: ColumnMode = .three
    private var pinchStartScale: CGFloat = 1.0
    private var isPinching: Bool = false

    // Configurable thresholds
    private var zoomInThreshold: CGFloat = 0.85   // Scale below this -> zoom in (fewer columns)
    private var zoomOutThreshold: CGFloat = 1.15  // Scale above this -> zoom out (more columns)
    private var cooldownMs: Int = 200             // Minimum time between transitions
    private var lastTransitionTime: CFTimeInterval = 0

    // Anchor tracking (improved)
    private var anchorIndexPath: IndexPath?
    private var pinchLocationInView: CGPoint = .zero       // 핀치 중심점의 화면 내 좌표
    private var anchorCellInternalOffset: CGPoint = .zero  // 앵커 셀 내부 상대 위치 (0~1, 0~1)

    // Test results
    private var transitionResults: [(from: ColumnMode, to: ColumnMode, hitchRatio: Double, anchorDrift: CGFloat)] = []

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        generateColors()
        setupUI()
        setupCollectionView()
        setupPinchGesture()
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Gate 3: Pinch Zoom"
        view.backgroundColor = .systemBackground

        // Navigation items
        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(title: "Test", style: .plain, target: self, action: #selector(runAutoTest)),
            UIBarButtonItem(title: "Results", style: .plain, target: self, action: #selector(showResults)),
            UIBarButtonItem(title: "Config", style: .plain, target: self, action: #selector(showConfig))
        ]

        // Status label
        statusLabel.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        statusLabel.textAlignment = .center
        statusLabel.textColor = .secondaryLabel
        statusLabel.numberOfLines = 4
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
        let layout = createLayout(columns: currentMode.rawValue)
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

    private func createLayout(columns: Int) -> UICollectionViewLayout {
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

    private func setupPinchGesture() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        collectionView.addGestureRecognizer(pinch)
    }

    private func generateColors() {
        itemColors = (0..<itemCount).map { index in
            // Deterministic color based on index for consistency
            let hue = CGFloat(index % 360) / 360.0
            let saturation = 0.5 + CGFloat((index / 360) % 5) * 0.1
            let brightness = 0.7 + CGFloat((index / 1800) % 3) * 0.1
            return UIColor(hue: hue, saturation: saturation, brightness: brightness, alpha: 1.0)
        }
    }

    private func updateStatusLabel() {
        statusLabel.text = """
            Mode: \(currentMode.rawValue)열 | Items: \(formatCount(itemCount))
            Threshold: ↓\(String(format: "%.2f", zoomInThreshold)) ↑\(String(format: "%.2f", zoomOutThreshold)) | Cooldown: \(cooldownMs)ms
            Pinch to change column count
            """
    }

    private func formatCount(_ count: Int) -> String {
        if count >= 1000 {
            return "\(count / 1000)k"
        }
        return "\(count)"
    }

    // MARK: - Pinch Handling

    @objc private func handlePinch(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            pinchStartScale = 1.0
            isPinching = true
            captureAnchor(at: gesture.location(in: collectionView))

        case .changed:
            let scale = gesture.scale
            checkTransition(scale: scale, location: gesture.location(in: collectionView))

        case .ended, .cancelled:
            isPinching = false
            pinchStartScale = 1.0

        default:
            break
        }
    }

    private func captureAnchor(at point: CGPoint) {
        // 1. 핀치 중심점의 화면 내 좌표 저장
        pinchLocationInView = collectionView.convert(point, to: view)

        // 2. 핀치 중심점에서 indexPath 결정 + 셀 내부 상대 위치 계산
        if let indexPath = collectionView.indexPathForItem(at: point),
           let cell = collectionView.cellForItem(at: indexPath) {
            anchorIndexPath = indexPath

            // 셀 내부 상대 위치 (0~1, 0~1)
            let cellFrame = cell.frame
            anchorCellInternalOffset = CGPoint(
                x: (point.x - cellFrame.minX) / cellFrame.width,
                y: (point.y - cellFrame.minY) / cellFrame.height
            )
        } else {
            // Fallback: 화면 중앙 셀 사용
            let visiblePaths = collectionView.indexPathsForVisibleItems.sorted { $0.item < $1.item }
            if !visiblePaths.isEmpty {
                anchorIndexPath = visiblePaths[visiblePaths.count / 2]
                anchorCellInternalOffset = CGPoint(x: 0.5, y: 0.5)  // 셀 중앙
            }
        }
    }

    private func checkTransition(scale: CGFloat, location: CGPoint) {
        let now = CACurrentMediaTime()
        let cooldownSeconds = Double(cooldownMs) / 1000.0

        // Cooldown check
        guard now - lastTransitionTime >= cooldownSeconds else { return }

        var targetMode: ColumnMode?

        // Zoom in (pinch out, scale > threshold) -> fewer columns (bigger cells)
        if scale > zoomOutThreshold && currentMode != .one {
            targetMode = currentMode.prev
        }
        // Zoom out (pinch in, scale < threshold) -> more columns (smaller cells)
        else if scale < zoomInThreshold && currentMode != .five {
            targetMode = currentMode.next
        }

        if let target = targetMode {
            performTransition(to: target)
            // Reset scale for hysteresis
            pinchStartScale = 1.0
        }
    }

    private func performTransition(to newMode: ColumnMode) {
        let fromMode = currentMode
        lastTransitionTime = CACurrentMediaTime()

        // Start hitch monitoring
        hitchMonitor.start()

        // Remember anchor position before transition
        let anchorIndex = anchorIndexPath?.item ?? 0

        // Change layout
        currentMode = newMode
        let newLayout = createLayout(columns: newMode.rawValue)

        collectionView.setCollectionViewLayout(newLayout, animated: true) { [weak self] _ in
            guard let self = self else { return }

            // Stop hitch monitoring
            let hitchResult = self.hitchMonitor.stop()

            // Restore anchor position
            let drift = self.restoreAnchor(index: anchorIndex)

            // Record result
            self.transitionResults.append((
                from: fromMode,
                to: newMode,
                hitchRatio: hitchResult.hitchTimeRatio,
                anchorDrift: drift
            ))

            // Update UI
            self.updateStatusLabel()
            self.updateStatusWithResult(hitchResult: hitchResult, drift: drift, from: fromMode, to: newMode)

            print("Transition \(fromMode.rawValue)→\(newMode.rawValue): hitch=\(String(format: "%.1f", hitchResult.hitchTimeRatio)) ms/s, drift=\(String(format: "%.1f", drift))px")
        }
    }

    private func restoreAnchor(index: Int) -> CGFloat {
        let targetIndexPath = IndexPath(item: index, section: 0)

        guard let layoutAttrs = collectionView.layoutAttributesForItem(at: targetIndexPath) else {
            return 0
        }

        // 1. 새 레이아웃에서 앵커 셀의 frame
        let newCellFrame = layoutAttrs.frame

        // 2. 셀 내부 상대 위치를 새 frame에 적용하여 앵커 포인트 계산
        let anchorPointInContent = CGPoint(
            x: newCellFrame.minX + newCellFrame.width * anchorCellInternalOffset.x,
            y: newCellFrame.minY + newCellFrame.height * anchorCellInternalOffset.y
        )

        // 3. 현재 상태에서의 drift 계산 (offset 적용 전)
        let currentAnchorY = collectionView.contentOffset.y + pinchLocationInView.y
        let drift = abs(anchorPointInContent.y - currentAnchorY)

        // 4. 앵커 포인트가 화면에서 원래 핀치 위치에 오도록 offset 계산
        let targetOffsetY = anchorPointInContent.y - pinchLocationInView.y

        // 5. Clamp to valid range
        let maxOffsetY = max(0, collectionView.contentSize.height - collectionView.bounds.height)
        let clampedOffsetY = max(0, min(targetOffsetY, maxOffsetY))

        // 6. Scroll to restore position
        collectionView.setContentOffset(CGPoint(x: 0, y: clampedOffsetY), animated: false)

        return drift
    }

    private func updateStatusWithResult(hitchResult: HitchResult, drift: CGFloat, from: ColumnMode, to: ColumnMode) {
        let grade = hitchResult.appleGrade
        let emoji = grade == "Good" ? "✅" : (grade == "Warning" ? "⚠️" : "❌")

        statusLabel.text = """
            \(emoji) \(from.rawValue)→\(to.rawValue)열 | hitch: \(String(format: "%.1f", hitchResult.hitchTimeRatio)) ms/s [\(grade)]
            anchor drift: \(String(format: "%.1f", drift))px
            Threshold: ↓\(String(format: "%.2f", zoomInThreshold)) ↑\(String(format: "%.2f", zoomOutThreshold)) | Cooldown: \(cooldownMs)ms
            """
    }

    // MARK: - Auto Test

    @objc private func runAutoTest() {
        statusLabel.text = "Running auto test..."
        transitionResults.removeAll()

        // Reset to 3-column mode first
        currentMode = .three
        let initialLayout = createLayout(columns: 3)
        collectionView.setCollectionViewLayout(initialLayout, animated: false)

        // Scroll to middle for anchor testing
        let middleIndex = itemCount / 2
        collectionView.scrollToItem(at: IndexPath(item: middleIndex, section: 0), at: .centeredVertically, animated: false)

        print("\n=== Gate 3 Auto Test Start ===")
        print("Config: threshold=\(zoomInThreshold)/\(zoomOutThreshold), cooldown=\(cooldownMs)ms, items=\(itemCount)")

        // Run test sequence after layout settles
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.runTestSequence()
        }
    }

    private func runTestSequence() {
        // Test sequence: 3→1→3→5→3
        let transitions: [(from: ColumnMode, to: ColumnMode)] = [
            (.three, .one),   // Zoom in
            (.one, .three),   // Zoom out
            (.three, .five),  // Zoom out
            (.five, .three),  // Zoom in
        ]

        runTransitionSequence(transitions: transitions, index: 0)
    }

    private func runTransitionSequence(transitions: [(from: ColumnMode, to: ColumnMode)], index: Int) {
        guard index < transitions.count else {
            // All done - show summary
            showAutoTestSummary()
            return
        }

        let transition = transitions[index]

        // Set anchor at center of visible area (using improved method)
        let visiblePaths = collectionView.indexPathsForVisibleItems.sorted { $0.item < $1.item }
        if !visiblePaths.isEmpty {
            anchorIndexPath = visiblePaths[visiblePaths.count / 2]
            if let anchor = anchorIndexPath, let cell = collectionView.cellForItem(at: anchor) {
                // 화면 중앙을 핀치 위치로 가정
                let viewCenter = CGPoint(
                    x: collectionView.bounds.width / 2,
                    y: collectionView.bounds.height / 2
                )
                pinchLocationInView = collectionView.convert(viewCenter, to: view)

                // 셀 중앙을 앵커 포인트로 사용
                anchorCellInternalOffset = CGPoint(x: 0.5, y: 0.5)
            }
        }

        statusLabel.text = "Testing \(transition.from.rawValue)→\(transition.to.rawValue)열..."

        // Perform transition
        performTransitionForTest(to: transition.to) { [weak self] in
            // Wait before next transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.runTransitionSequence(transitions: transitions, index: index + 1)
            }
        }
    }

    private func performTransitionForTest(to newMode: ColumnMode, completion: @escaping () -> Void) {
        let fromMode = currentMode

        hitchMonitor.start()

        let anchorIndex = anchorIndexPath?.item ?? (itemCount / 2)

        currentMode = newMode
        let newLayout = createLayout(columns: newMode.rawValue)

        collectionView.setCollectionViewLayout(newLayout, animated: true) { [weak self] _ in
            guard let self = self else { return }

            let hitchResult = self.hitchMonitor.stop()
            let drift = self.restoreAnchor(index: anchorIndex)

            self.transitionResults.append((
                from: fromMode,
                to: newMode,
                hitchRatio: hitchResult.hitchTimeRatio,
                anchorDrift: drift
            ))

            print("  \(fromMode.rawValue)→\(newMode.rawValue): hitch=\(String(format: "%.1f", hitchResult.hitchTimeRatio)) ms/s, drift=\(String(format: "%.0f", drift))px")

            completion()
        }
    }

    private func showAutoTestSummary() {
        guard !transitionResults.isEmpty else { return }

        let avgHitch = transitionResults.map { $0.hitchRatio }.reduce(0, +) / Double(transitionResults.count)
        let maxHitch = transitionResults.map { $0.hitchRatio }.max() ?? 0
        let avgDrift = transitionResults.map { $0.anchorDrift }.reduce(0, +) / CGFloat(transitionResults.count)
        let maxDrift = transitionResults.map { $0.anchorDrift }.max() ?? 0

        let grade = avgHitch < 5 ? "Good" : (avgHitch < 10 ? "Warning" : "Critical")
        let emoji = grade == "Good" ? "✅" : (grade == "Warning" ? "⚠️" : "❌")

        statusLabel.text = """
            \(emoji) Auto Test Complete [\(grade)]
            hitch avg: \(String(format: "%.1f", avgHitch)) ms/s, max: \(String(format: "%.1f", maxHitch)) ms/s
            drift avg: \(String(format: "%.0f", avgDrift))px, max: \(String(format: "%.0f", maxDrift))px
            """

        print("\n=== Gate 3 Auto Test Result ===")
        print("hitch avg: \(String(format: "%.1f", avgHitch)) ms/s, max: \(String(format: "%.1f", maxHitch)) ms/s")
        print("drift avg: \(String(format: "%.0f", avgDrift))px, max: \(String(format: "%.0f", maxDrift))px")
        print("\(emoji) \(grade)")
    }

    // MARK: - Actions

    @objc private func showConfig() {
        let alert = UIAlertController(title: "Configuration", message: nil, preferredStyle: .actionSheet)

        // Threshold options
        alert.addAction(UIAlertAction(title: "Threshold: 0.80/1.20", style: .default) { [weak self] _ in
            self?.zoomInThreshold = 0.80
            self?.zoomOutThreshold = 1.20
            self?.updateStatusLabel()
        })
        alert.addAction(UIAlertAction(title: "Threshold: 0.85/1.15 (default)", style: .default) { [weak self] _ in
            self?.zoomInThreshold = 0.85
            self?.zoomOutThreshold = 1.15
            self?.updateStatusLabel()
        })
        alert.addAction(UIAlertAction(title: "Threshold: 0.90/1.10", style: .default) { [weak self] _ in
            self?.zoomInThreshold = 0.90
            self?.zoomOutThreshold = 1.10
            self?.updateStatusLabel()
        })

        // Cooldown options
        alert.addAction(UIAlertAction(title: "Cooldown: 150ms", style: .default) { [weak self] _ in
            self?.cooldownMs = 150
            self?.updateStatusLabel()
        })
        alert.addAction(UIAlertAction(title: "Cooldown: 200ms (default)", style: .default) { [weak self] _ in
            self?.cooldownMs = 200
            self?.updateStatusLabel()
        })
        alert.addAction(UIAlertAction(title: "Cooldown: 250ms", style: .default) { [weak self] _ in
            self?.cooldownMs = 250
            self?.updateStatusLabel()
        })

        // Item count options
        alert.addAction(UIAlertAction(title: "Items: 1k", style: .default) { [weak self] _ in
            self?.reloadWithCount(1_000)
        })
        alert.addAction(UIAlertAction(title: "Items: 10k", style: .default) { [weak self] _ in
            self?.reloadWithCount(10_000)
        })
        alert.addAction(UIAlertAction(title: "Items: 50k", style: .default) { [weak self] _ in
            self?.reloadWithCount(50_000)
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        present(alert, animated: true)
    }

    private func reloadWithCount(_ count: Int) {
        itemCount = count
        generateColors()
        collectionView.reloadData()
        transitionResults.removeAll()
        updateStatusLabel()
    }

    @objc private func showResults() {
        guard !transitionResults.isEmpty else {
            let alert = UIAlertController(title: "No Results", message: "Pinch to perform transitions first", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            present(alert, animated: true)
            return
        }

        var message = "Transition Results:\n\n"
        for (i, result) in transitionResults.enumerated() {
            let grade = result.hitchRatio < 5 ? "Good" : (result.hitchRatio < 10 ? "Warning" : "Critical")
            message += "\(i+1). \(result.from.rawValue)→\(result.to.rawValue): \(String(format: "%.1f", result.hitchRatio)) ms/s [\(grade)], drift: \(String(format: "%.0f", result.anchorDrift))px\n"
        }

        // Summary
        let avgHitch = transitionResults.map { $0.hitchRatio }.reduce(0, +) / Double(transitionResults.count)
        let avgDrift = transitionResults.map { $0.anchorDrift }.reduce(0, +) / CGFloat(transitionResults.count)
        message += "\n---\nAvg hitch: \(String(format: "%.1f", avgHitch)) ms/s\nAvg drift: \(String(format: "%.0f", avgDrift))px"

        let alert = UIAlertController(title: "Gate 3 Results", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive) { [weak self] _ in
            self?.transitionResults.removeAll()
        })
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        present(alert, animated: true)

        // Print to console
        print("\n=== Gate 3 Results ===")
        print("Config: threshold=\(zoomInThreshold)/\(zoomOutThreshold), cooldown=\(cooldownMs)ms, items=\(itemCount)")
        print(message)
    }
}

// MARK: - UICollectionViewDataSource

extension Gate3ViewController: UICollectionViewDataSource {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return itemCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ColorCell.reuseID, for: indexPath) as! ColorCell
        cell.color = itemColors[indexPath.item]
        return cell
    }
}

// MARK: - ColorCell

final class ColorCell: UICollectionViewCell {
    static let reuseID = "ColorCell"

    var color: UIColor = .systemGray5 {
        didSet {
            contentView.backgroundColor = color
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemGray5
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.backgroundColor = .systemGray5
    }
}

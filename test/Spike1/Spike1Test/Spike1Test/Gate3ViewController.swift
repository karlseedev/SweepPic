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
    private var layoutCache: [Int: UICollectionViewLayout] = [:]

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
    private var pinchLocationInView: CGPoint = .zero       // 핀치 중심점의 화면 내 좌표 (marker용)
    private var pinchLocationInContent: CGPoint = .zero    // 핀치 중심점의 content 좌표 (셀 내부 비율 계산용)
    private var pinchLocationInCollectionView: CGPoint = .zero  // 핀치 중심점의 visible 좌표 (anchor 계산용, 0..bounds)
    private var anchorCellInternalOffset: CGPoint = .zero  // 앵커 셀 내부 상대 위치 (0~1, 0~1)

    // Visual debug (manual verification)
    private var isVisualDebugEnabled: Bool = true
    private var highlightedAnchorIndex: Int?
    private let pinchMarkerLabel = UILabel()
    private var visualToggleButton: UIButton?
    private var jankToggleButton: UIButton?
    private var isJankEnabled: Bool = false
    private var transitionToken: Int = 0
    private let jankMarkerLabel = UILabel()

    // Test results
    private struct TransitionResult {
        let spot: String  // "Manual" | "Top" | "Center" | "Bottom"
        let from: ColumnMode
        let to: ColumnMode
        let hitchRatio: Double
        let hitchTimeMs: Double
        let droppedFrames: Int
        let longestHitchFrames: Int
        let longestHitchMs: Double
        let anchorDrift: CGFloat
    }
    private var transitionResults: [TransitionResult] = []

    private enum AutoPinchSpot: CaseIterable {
        case top
        case center
        case bottom

        var label: String {
            switch self {
            case .top: return "Top"
            case .center: return "Center"
            case .bottom: return "Bottom"
            }
        }

        func visiblePoint(in bounds: CGRect) -> CGPoint {
            // UIScrollView/UICollectionView는 scroll 시 bounds.origin이 contentOffset으로 이동할 수 있어
            // bounds.midX/midY를 쓰면 좌표계가 content로 섞일 수 있습니다.
            // Auto 테스트는 "가시 영역(0..size)" 기준으로 고정합니다.
            let x = bounds.size.width * 0.5
            let y: CGFloat
            switch self {
            case .top: y = bounds.height * 0.25
            case .center: y = bounds.size.height * 0.5
            case .bottom: y = bounds.height * 0.75
            }
            return CGPoint(x: x, y: y)
        }
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        generateColors()
        setupUI()
        setupCollectionView()
        setupVisualDebug()
        setupTapGestureForVisual()
        setupPinchGesture()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 처음 진입 시 "뭘 봐야 하는지"가 바로 보이도록 기본 앵커/마커를 화면 중앙에 배치합니다.
        DispatchQueue.main.async { [weak self] in
            self?.setDefaultAnchorIfNeeded()
        }
    }

    // MARK: - Setup

    private func setupUI() {
        title = "Gate 3: Pinch Zoom"
        view.backgroundColor = .systemBackground

        // Navigation items
        // 우측: Auto | Visual | Jank (좁은 공간에서도 눈으로 비교하기 좋게)
        // 좌측: Results / Config (우측이 비좁아지지 않도록 이동)
        navigationItem.rightBarButtonItem = makeTestSplitBarItem()
        navigationItem.leftBarButtonItems = [
            UIBarButtonItem(title: "Config", style: .plain, target: self, action: #selector(showConfig)),
            UIBarButtonItem(title: "Results", style: .plain, target: self, action: #selector(showResults))
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
        if let cached = layoutCache[columns] {
            return cached
        }

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
        let layout = UICollectionViewCompositionalLayout(section: section)
        layoutCache[columns] = layout
        return layout
    }

    private func setupPinchGesture() {
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        collectionView.addGestureRecognizer(pinch)
    }

    private func setupTapGestureForVisual() {
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTapForVisual(_:)))
        tap.cancelsTouchesInView = false
        collectionView.addGestureRecognizer(tap)
    }

    @objc private func handleTapForVisual(_ gesture: UITapGestureRecognizer) {
        guard isVisualDebugEnabled else { return }
        let point = gesture.location(in: collectionView)
        captureAnchor(at: point)
    }

    private func setupVisualDebug() {
        pinchMarkerLabel.text = "+"
        pinchMarkerLabel.font = .monospacedSystemFont(ofSize: 18, weight: .bold)
        pinchMarkerLabel.textAlignment = .center
        pinchMarkerLabel.textColor = .systemRed
        pinchMarkerLabel.backgroundColor = UIColor.systemBackground.withAlphaComponent(0.6)
        pinchMarkerLabel.layer.cornerRadius = 4
        pinchMarkerLabel.layer.masksToBounds = true
        pinchMarkerLabel.bounds = CGRect(x: 0, y: 0, width: 18, height: 18)
        pinchMarkerLabel.isHidden = !isVisualDebugEnabled
        view.addSubview(pinchMarkerLabel)

        // Jank ON 상태에서 “인위적으로 멈췄다”를 눈으로 확인할 수 있게 배지 표시
        jankMarkerLabel.text = "JANK"
        jankMarkerLabel.font = .systemFont(ofSize: 13, weight: .heavy)
        jankMarkerLabel.textAlignment = .center
        jankMarkerLabel.textColor = .white
        jankMarkerLabel.backgroundColor = UIColor.systemRed.withAlphaComponent(0.9)
        jankMarkerLabel.layer.cornerRadius = 6
        jankMarkerLabel.layer.masksToBounds = true
        jankMarkerLabel.isHidden = true
        jankMarkerLabel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(jankMarkerLabel)

        NSLayoutConstraint.activate([
            jankMarkerLabel.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            jankMarkerLabel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            jankMarkerLabel.widthAnchor.constraint(equalToConstant: 58),
            jankMarkerLabel.heightAnchor.constraint(equalToConstant: 24),
        ])
    }

    private func makeTestSplitBarItem() -> UIBarButtonItem {
        let container = UIStackView()
        container.axis = .horizontal
        container.distribution = .fillEqually
        container.alignment = .fill
        container.spacing = 1
        container.backgroundColor = .separator
        container.layer.cornerRadius = 8
        container.layer.masksToBounds = true

        let autoButton = UIButton(type: .system)
        autoButton.setTitle("Auto", for: .normal)
        autoButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        autoButton.backgroundColor = .secondarySystemBackground
        autoButton.addTarget(self, action: #selector(runAutoTest), for: .touchUpInside)

        let visualButton = UIButton(type: .system)
        visualButton.setTitle("Visual", for: .normal)
        visualButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        visualButton.addTarget(self, action: #selector(toggleVisualDebug), for: .touchUpInside)
        visualToggleButton = visualButton

        let jankButton = UIButton(type: .system)
        jankButton.setTitle("Jank", for: .normal)
        jankButton.titleLabel?.font = .systemFont(ofSize: 12, weight: .semibold)
        jankButton.addTarget(self, action: #selector(toggleJank), for: .touchUpInside)
        jankToggleButton = jankButton

        container.addArrangedSubview(autoButton)
        container.addArrangedSubview(visualButton)
        container.addArrangedSubview(jankButton)

        container.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            container.widthAnchor.constraint(equalToConstant: 168),
            container.heightAnchor.constraint(equalToConstant: 32)
        ])

        updateVisualButtonStyle()
        updateJankButtonStyle()
        return UIBarButtonItem(customView: container)
    }

    @objc private func toggleVisualDebug() {
        isVisualDebugEnabled.toggle()
        pinchMarkerLabel.isHidden = !isVisualDebugEnabled
        updateVisualButtonStyle()
        updateVisibleCellDecorations()
    }

    private func updateVisualButtonStyle() {
        guard let button = visualToggleButton else { return }
        if isVisualDebugEnabled {
            button.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.18)
            button.setTitleColor(.systemBlue, for: .normal)
        } else {
            button.backgroundColor = .secondarySystemBackground
            button.setTitleColor(.label, for: .normal)
        }
    }

    @objc private func toggleJank() {
        isJankEnabled.toggle()
        updateJankButtonStyle()
    }

    private func updateJankButtonStyle() {
        guard let button = jankToggleButton else { return }
        if isJankEnabled {
            button.backgroundColor = UIColor.systemOrange.withAlphaComponent(0.18)
            button.setTitleColor(.systemOrange, for: .normal)
        } else {
            button.backgroundColor = .secondarySystemBackground
            button.setTitleColor(.label, for: .normal)
        }
    }

    private func updateVisibleCellDecorations() {
        for indexPath in collectionView.indexPathsForVisibleItems {
            guard let cell = collectionView.cellForItem(at: indexPath) as? ColorCell else { continue }
            cell.indexText = "\(indexPath.item)"
            cell.showsDebugOverlay = isVisualDebugEnabled
            cell.isAnchorHighlighted = isVisualDebugEnabled && (indexPath.item == highlightedAnchorIndex)
        }
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
        // 1. 핀치 중심점 좌표 저장
        // - `gesture.location(in: collectionView)`는 contentOffset이 반영된 content 좌표로 들어올 수 있습니다.
        // - 앵커 복원은 "화면에서 같은 위치"를 유지해야 하므로, visible 좌표(0..bounds)로 정규화해서 사용합니다.
        pinchLocationInContent = point
        pinchLocationInCollectionView = CGPoint(
            x: point.x - collectionView.contentOffset.x,
            y: point.y - collectionView.contentOffset.y
        )
        pinchLocationInCollectionView = clampToVisibleBounds(pinchLocationInCollectionView)

        // marker는 "가시 영역 좌표"를 기준으로 표시 (바운스/오버스크롤 시에도 안정적)
        let markerContentPoint = CGPoint(
            x: collectionView.contentOffset.x + pinchLocationInCollectionView.x,
            y: collectionView.contentOffset.y + pinchLocationInCollectionView.y
        )
        pinchLocationInView = collectionView.convert(markerContentPoint, to: view)
        pinchMarkerLabel.center = pinchLocationInView

        // 2. 핀치 중심점에서 indexPath 결정 + 셀 내부 상대 위치 계산
        if let indexPath = collectionView.indexPathForItem(at: point),
           let cell = collectionView.cellForItem(at: indexPath) {
            anchorIndexPath = indexPath
            highlightedAnchorIndex = indexPath.item

            // 셀 내부 상대 위치 (0~1, 0~1)
            let cellFrame = cell.frame
            if cellFrame.width > 0, cellFrame.height > 0 {
                anchorCellInternalOffset = CGPoint(
                    x: clamp((pinchLocationInContent.x - cellFrame.minX) / cellFrame.width, min: 0, max: 1),
                    y: clamp((pinchLocationInContent.y - cellFrame.minY) / cellFrame.height, min: 0, max: 1)
                )
            } else {
                anchorCellInternalOffset = CGPoint(x: 0.5, y: 0.5)
            }
        } else {
            // Fallback: 화면 중앙 셀 사용
            let visiblePaths = collectionView.indexPathsForVisibleItems.sorted { $0.item < $1.item }
            if !visiblePaths.isEmpty {
                anchorIndexPath = visiblePaths[visiblePaths.count / 2]
                anchorCellInternalOffset = CGPoint(x: 0.5, y: 0.5)  // 셀 중앙
                highlightedAnchorIndex = anchorIndexPath?.item
            }
        }
        updateVisibleCellDecorations()
    }

    private func setDefaultAnchorIfNeeded() {
        guard isVisualDebugEnabled else { return }
        guard anchorIndexPath == nil else { return }
        let visibleCenter = CGPoint(
            x: collectionView.contentOffset.x + collectionView.bounds.size.width * 0.5,
            y: collectionView.contentOffset.y + collectionView.bounds.size.height * 0.5
        )
        captureAnchor(at: visibleCenter)
    }

    private func clampToVisibleBounds(_ point: CGPoint) -> CGPoint {
        CGPoint(
            x: clamp(point.x, min: 0, max: collectionView.bounds.size.width),
            y: clamp(point.y, min: 0, max: collectionView.bounds.size.height)
        )
    }

    private func clamp(_ value: CGFloat, min: CGFloat, max: CGFloat) -> CGFloat {
        Swift.max(min, Swift.min(value, max))
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
        transitionToken += 1
        let token = transitionToken

        // Start hitch monitoring
        hitchMonitor.start()

        // Remember anchor position before transition
        let anchorIndex = anchorIndexPath?.item ?? 0

        // Change layout
        currentMode = newMode
        let newLayout = createLayout(columns: newMode.rawValue)

        scheduleSyntheticJankIfNeeded(from: fromMode, to: newMode, token: token)

        collectionView.setCollectionViewLayout(newLayout, animated: true) { [weak self] _ in
            guard let self = self else { return }

            // Stop hitch monitoring
            let hitchResult = self.hitchMonitor.stop()

            // Restore anchor position
            let drift = self.restoreAnchor(index: anchorIndex)
            self.highlightedAnchorIndex = anchorIndex
            self.updateVisibleCellDecorations()

            // Record result
            self.transitionResults.append(TransitionResult(
                spot: "Manual",
                from: fromMode,
                to: newMode,
                hitchRatio: hitchResult.hitchTimeRatio,
                hitchTimeMs: hitchResult.totalHitchTimeMs,
                droppedFrames: hitchResult.droppedFrames,
                longestHitchFrames: hitchResult.longestHitch,
                longestHitchMs: hitchResult.longestHitchMs,
                anchorDrift: drift
            ))

            // Update UI
            self.updateStatusLabel()
            self.updateStatusWithResult(hitchResult: hitchResult, drift: drift, from: fromMode, to: newMode)

            print("Transition \(fromMode.rawValue)→\(newMode.rawValue): hitch=\(String(format: "%.1f", hitchResult.hitchTimeRatio)) ms/s (hitchTime=\(String(format: "%.1f", hitchResult.totalHitchTimeMs))ms, longest=\(String(format: "%.1f", hitchResult.longestHitchMs))ms), drift=\(String(format: "%.1f", drift))px")
        }
    }

    private func restoreAnchor(index: Int) -> CGFloat {
        let targetIndexPath = IndexPath(item: index, section: 0)

        // Layout 전환 직후에는 contentSize/layoutAttributes가 완전히 안정되기 전이라
        // 1-pass 계산만 하면 (특히 확대: 1→3, 3→5)에서 클램프/오차가 크게 발생할 수 있어
        // 2-pass로 보정합니다.

        let pinchY = pinchLocationInCollectionView.y  // visible Y (0..bounds)

        func computeAnchorPointY() -> CGFloat? {
            guard let attrs = collectionView.layoutAttributesForItem(at: targetIndexPath) else { return nil }
            let frame = attrs.frame
            return frame.minY + frame.height * anchorCellInternalOffset.y
        }

        func clampOffset(_ offsetY: CGFloat) -> CGFloat {
            // UIScrollView는 inset에 따라 contentOffset 최소/최대가 0이 아닐 수 있습니다.
            let inset = collectionView.adjustedContentInset
            let minOffsetY = -inset.top
            let maxOffsetY = max(minOffsetY, collectionView.contentSize.height - collectionView.bounds.height + inset.bottom)
            return clamp(offsetY, min: minOffsetY, max: maxOffsetY)
        }

        // Pass 1: 레이아웃 안정화 + 1차 오프셋 적용
        collectionView.collectionViewLayout.invalidateLayout()
        collectionView.layoutIfNeeded()
        if collectionView.contentSize.height <= 1 {
            // contentSize가 비정상(0/미계산)인 경우가 있어 1회 더 강제합니다.
            collectionView.collectionViewLayout.invalidateLayout()
            collectionView.layoutIfNeeded()
        }

        guard let anchorY1 = computeAnchorPointY() else { return 0 }
        let offset1 = clampOffset(anchorY1 - pinchY)
        collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: offset1), animated: false)

        // Pass 2: 오프셋 적용 후 레이아웃 갱신 + 보정(필요 시)
        collectionView.layoutIfNeeded()
        guard let anchorY2 = computeAnchorPointY() else { return 0 }
        let offset2 = clampOffset(anchorY2 - pinchY)
        if abs(collectionView.contentOffset.y - offset2) > 0.5 {
            collectionView.setContentOffset(CGPoint(x: collectionView.contentOffset.x, y: offset2), animated: false)
            collectionView.layoutIfNeeded()
        }

        // 최종 drift 계산 (offset 적용 후)
        guard let anchorYFinal = computeAnchorPointY() else { return 0 }
        let finalAnchorY = collectionView.contentOffset.y + pinchY
        return abs(anchorYFinal - finalAnchorY)
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
        // Auto 측정은 Jank 토글에 영향받지 않게 강제로 OFF 처리합니다.
        if isJankEnabled {
            isJankEnabled = false
            updateJankButtonStyle()
        }

        statusLabel.text = "Running auto test..."
        transitionResults.removeAll()

        print("\n=== Gate 3 Auto Test Start ===")
        print("Config: threshold=\(zoomInThreshold)/\(zoomOutThreshold), cooldown=\(cooldownMs)ms, items=\(itemCount)")

        runAutoTestSpot(index: 0)
    }

    private func runAutoTestSpot(index: Int) {
        let spots = AutoPinchSpot.allCases
        guard index < spots.count else {
            showAutoTestSummary()
            return
        }

        let spot = spots[index]

        // Reset to 3-column mode first
        currentMode = .three
        let initialLayout = createLayout(columns: 3)
        collectionView.setCollectionViewLayout(initialLayout, animated: false)

        // Scroll to middle for anchor testing (avoid clamp edge cases)
        let middleIndex = itemCount / 2
        collectionView.scrollToItem(at: IndexPath(item: middleIndex, section: 0), at: .centeredVertically, animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.warmupLayouts()
            self?.runTestSequence(spot: spot) { [weak self] in
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    self?.runAutoTestSpot(index: index + 1)
                }
            }
        }
    }

    private func warmupLayouts() {
        // 3→5→3을 비측정으로 한 번 수행해 초기 레이아웃 계산 오버헤드(워밍업)로 인한 변동을 줄입니다.
        let layout5 = createLayout(columns: 5)
        collectionView.setCollectionViewLayout(layout5, animated: false)
        collectionView.layoutIfNeeded()

        let layout3 = createLayout(columns: 3)
        collectionView.setCollectionViewLayout(layout3, animated: false)
        collectionView.layoutIfNeeded()

        currentMode = .three
    }

    private func runTestSequence(spot: AutoPinchSpot, completion: @escaping () -> Void) {
        // Test sequence: 3→1→3→5→3
        let transitions: [(from: ColumnMode, to: ColumnMode)] = [
            (.three, .one),   // Zoom in
            (.one, .three),   // Zoom out
            (.three, .five),  // Zoom out
            (.five, .three),  // Zoom in
        ]

        print("Auto spot: \(spot.label)")
        runTransitionSequence(transitions: transitions, index: 0, spot: spot, completion: completion)
    }

    private func runTransitionSequence(transitions: [(from: ColumnMode, to: ColumnMode)], index: Int, spot: AutoPinchSpot, completion: @escaping () -> Void) {
        guard index < transitions.count else {
            completion()
            return
        }

        let transition = transitions[index]

        // Set anchor by a deterministic visible point (top/center/bottom)
        let visiblePoint = spot.visiblePoint(in: collectionView.bounds)
        let contentPoint = CGPoint(
            x: collectionView.contentOffset.x + visiblePoint.x,
            y: collectionView.contentOffset.y + visiblePoint.y
        )
        captureAnchor(at: contentPoint)

        statusLabel.text = "Testing \(transition.from.rawValue)→\(transition.to.rawValue)열..."

        // Perform transition
        performTransitionForTest(to: transition.to, spotLabel: spot.label) { [weak self] in
            // Wait before next transition
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                self?.runTransitionSequence(transitions: transitions, index: index + 1, spot: spot, completion: completion)
            }
        }
    }

    private func performTransitionForTest(to newMode: ColumnMode, spotLabel: String, completion: @escaping () -> Void) {
        let fromMode = currentMode
        transitionToken += 1
        let token = transitionToken

        hitchMonitor.start()

        let anchorIndex = anchorIndexPath?.item ?? (itemCount / 2)

        currentMode = newMode
        let newLayout = createLayout(columns: newMode.rawValue)

        scheduleSyntheticJankIfNeeded(from: fromMode, to: newMode, token: token)

        collectionView.setCollectionViewLayout(newLayout, animated: true) { [weak self] _ in
            guard let self = self else { return }

            let hitchResult = self.hitchMonitor.stop()
            let drift = self.restoreAnchor(index: anchorIndex)

            self.transitionResults.append(TransitionResult(
                spot: spotLabel,
                from: fromMode,
                to: newMode,
                hitchRatio: hitchResult.hitchTimeRatio,
                hitchTimeMs: hitchResult.totalHitchTimeMs,
                droppedFrames: hitchResult.droppedFrames,
                longestHitchFrames: hitchResult.longestHitch,
                longestHitchMs: hitchResult.longestHitchMs,
                anchorDrift: drift
            ))

            print("  \(fromMode.rawValue)→\(newMode.rawValue): hitch=\(String(format: "%.1f", hitchResult.hitchTimeRatio)) ms/s (hitchTime=\(String(format: "%.1f", hitchResult.totalHitchTimeMs))ms, longest=\(String(format: "%.1f", hitchResult.longestHitchMs))ms), drift=\(String(format: "%.0f", drift))px")

            completion()
        }
    }

    private func scheduleSyntheticJankIfNeeded(from: ColumnMode, to: ColumnMode, token: Int) {
        guard isJankEnabled else { return }
        // 비교/학습용: 가장 비싼 전환이 되는 경향이 있는 3→5에서만 인위적으로 "걸림"을 만들겠습니다.
        guard from == .three, to == .five else { return }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) { [weak self] in
            guard let self = self else { return }
            guard self.transitionToken == token else { return } // 다른 전환으로 넘어갔으면 무시
            self.flashJankMarker()
            print("    [Jank] Injecting synthetic hitch (80ms)")
            self.blockMainThread(milliseconds: 80)
        }
    }

    private func flashJankMarker() {
        jankMarkerLabel.alpha = 1
        jankMarkerLabel.isHidden = false
        UIView.animate(withDuration: 0.18, delay: 0.18, options: [.beginFromCurrentState, .curveEaseInOut]) { [weak self] in
            self?.jankMarkerLabel.alpha = 0
        } completion: { [weak self] _ in
            self?.jankMarkerLabel.isHidden = true
            self?.jankMarkerLabel.alpha = 1
        }
    }

    private func blockMainThread(milliseconds: Double) {
        let end = CACurrentMediaTime() + (milliseconds / 1000.0)
        var x = 0
        while CACurrentMediaTime() < end {
            x &+= 1
        }
        _ = x
    }

    private func showAutoTestSummary() {
        guard !transitionResults.isEmpty else { return }

        let avgHitch = transitionResults.map { $0.hitchRatio }.reduce(0, +) / Double(transitionResults.count)
        let maxHitch = transitionResults.map { $0.hitchRatio }.max() ?? 0
        let maxHitchTimeMs = transitionResults.map { $0.hitchTimeMs }.max() ?? 0
        let maxLongestHitchMs = transitionResults.map { $0.longestHitchMs }.max() ?? 0
        let maxDroppedFrames = transitionResults.map { $0.droppedFrames }.max() ?? 0
        let maxLongestHitchFrames = transitionResults.map { $0.longestHitchFrames }.max() ?? 0
        let avgDrift = transitionResults.map { $0.anchorDrift }.reduce(0, +) / CGFloat(transitionResults.count)
        let maxDrift = transitionResults.map { $0.anchorDrift }.max() ?? 0

        func gradeForHitch(_ msPerSec: Double) -> String {
            msPerSec < 5 ? "Good" : (msPerSec < 10 ? "Warning" : "Critical")
        }

        // Gate3 전환은 측정 구간이 짧아서(ms/s) 값이 과하게 튈 수 있습니다.
        // 여기서는 "최대 연속 드랍(longest hitch frames)"를 1차 기준으로 둡니다. (체감에 더 가까움)
        // - 0: 완전 부드러움
        // - 1: 1프레임 스킵(전환 중 1회 정도는 허용 가능 범주)
        // - 2+: 눈에 띄는 끊김(구조/전환 방식 재검토)
        func gradeForLongestHitchFrames(_ droppedFrameStreak: Int) -> String {
            if droppedFrameStreak == 0 { return "Good" }
            if droppedFrameStreak == 1 { return "Warning" }
            return "Critical"
        }

        func gradeForDrift(_ px: CGFloat) -> String {
            px <= 20 ? "Good" : (px <= 60 ? "Warning" : "Critical")
        }

        func worstGrade(_ a: String, _ b: String) -> String {
            let order: [String: Int] = ["Good": 0, "Warning": 1, "Critical": 2]
            return (order[a, default: 2] >= order[b, default: 2]) ? a : b
        }

        let appleMsPerSecGrade = gradeForHitch(maxHitch)
        let longestGrade = gradeForLongestHitchFrames(maxLongestHitchFrames)
        let driftGrade = gradeForDrift(maxDrift)
        // 최종 판정은 longest hitch + drift 기반으로 내리고,
        // Apple ms/s(짧은 구간에서는 과대평가 가능)는 참고용으로만 출력합니다.
        let grade = worstGrade(longestGrade, driftGrade)
        let emoji = grade == "Good" ? "✅" : (grade == "Warning" ? "⚠️" : "❌")

        statusLabel.text = """
            \(emoji) Auto Test Complete [\(grade)]
            longest hitch: \(String(format: "%.1f", maxLongestHitchMs))ms (\(maxLongestHitchFrames)f), dropped: \(maxDroppedFrames)
            hitch avg: \(String(format: "%.1f", avgHitch)) ms/s, max: \(String(format: "%.1f", maxHitch)) ms/s [Apple: \(appleMsPerSecGrade)]
            hitchTime max: \(String(format: "%.1f", maxHitchTimeMs))ms
            drift avg: \(String(format: "%.0f", avgDrift))px, max: \(String(format: "%.0f", maxDrift))px
            """

        print("\n=== Gate 3 Auto Test Result ===")
        print("hitch avg: \(String(format: "%.1f", avgHitch)) ms/s, max: \(String(format: "%.1f", maxHitch)) ms/s")
        print("longest hitch: \(String(format: "%.1f", maxLongestHitchMs))ms (\(maxLongestHitchFrames)f), dropped: \(maxDroppedFrames)")
        print("hitchTime max: \(String(format: "%.1f", maxHitchTimeMs))ms")
        print("drift avg: \(String(format: "%.0f", avgDrift))px, max: \(String(format: "%.0f", maxDrift))px")
        print("Auto grade: \(emoji) \(grade) | Apple(ms/s) grade: \(appleMsPerSecGrade)")
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
            message += "\(i+1). [\(result.spot)] \(result.from.rawValue)→\(result.to.rawValue): \(String(format: "%.1f", result.hitchRatio)) ms/s [\(grade)], longest: \(String(format: "%.1f", result.longestHitchMs))ms, drift: \(String(format: "%.0f", result.anchorDrift))px\n"
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
        cell.indexText = "\(indexPath.item)"
        cell.showsDebugOverlay = isVisualDebugEnabled
        cell.isAnchorHighlighted = isVisualDebugEnabled && (indexPath.item == highlightedAnchorIndex)
        return cell
    }
}

// MARK: - ColorCell

final class ColorCell: UICollectionViewCell {
    static let reuseID = "ColorCell"

    private let indexLabel = UILabel()

    var color: UIColor = .systemGray5 {
        didSet {
            contentView.backgroundColor = color
        }
    }

    var indexText: String? {
        didSet { indexLabel.text = indexText }
    }

    var showsDebugOverlay: Bool = true {
        didSet { updateDebugAppearance() }
    }

    var isAnchorHighlighted: Bool = false {
        didSet { updateDebugAppearance() }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.backgroundColor = .systemGray5

        indexLabel.translatesAutoresizingMaskIntoConstraints = false
        indexLabel.font = .monospacedSystemFont(ofSize: 11, weight: .semibold)
        indexLabel.textColor = .white
        indexLabel.backgroundColor = UIColor.black.withAlphaComponent(0.35)
        indexLabel.textAlignment = .center
        indexLabel.layer.cornerRadius = 4
        indexLabel.layer.masksToBounds = true
        indexLabel.setContentHuggingPriority(.required, for: .horizontal)
        indexLabel.setContentHuggingPriority(.required, for: .vertical)
        contentView.addSubview(indexLabel)

        NSLayoutConstraint.activate([
            indexLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            indexLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            indexLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 34),
            indexLabel.heightAnchor.constraint(equalToConstant: 18)
        ])

        updateDebugAppearance()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func prepareForReuse() {
        super.prepareForReuse()
        contentView.backgroundColor = .systemGray5
        indexLabel.text = nil
        isAnchorHighlighted = false
    }

    private func updateDebugAppearance() {
        indexLabel.isHidden = !showsDebugOverlay

        if showsDebugOverlay {
            contentView.layer.borderWidth = isAnchorHighlighted ? 3 : 0.5
            contentView.layer.borderColor = (isAnchorHighlighted ? UIColor.systemRed : UIColor.separator).cgColor
        } else {
            contentView.layer.borderWidth = 0
            contentView.layer.borderColor = nil
        }
    }
}

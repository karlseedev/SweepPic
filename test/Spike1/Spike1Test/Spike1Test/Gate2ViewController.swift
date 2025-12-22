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

    // Dedupe: track pending identifiers to avoid duplicate requests
    private var pendingIdentifiers: Set<String> = []

    // Data scale options
    private let scaleOptions = [1_000, 5_000, 10_000, 50_000]
    private var currentScaleIndex = 3  // Default 50k

    // Manual test mode (Start/Stop)
    private var isManualTestRunning = false
    private var testButton: UIBarButtonItem?
    private var autoButton: UIBarButtonItem?
    private var preheatButton: UIBarButtonItem?

    // A/B test options: Preheat mode for testing
    enum PreheatMode: String, CaseIterable {
        case on = "ON"           // Current: 100ms throttle
        case throttle = "150ms"  // More aggressive throttle
        case off = "OFF"         // Completely disabled

        var interval: CFTimeInterval? {
            switch self {
            case .on: return 0.1       // 100ms
            case .throttle: return 0.15 // 150ms
            case .off: return nil       // disabled
            }
        }
    }
    private var preheatMode: PreheatMode = .on
    private var lastCacheUpdateTime: CFTimeInterval = 0

    // updateCachedAssets measurement
    private var cacheUpdateCallCount: Int = 0
    private var cacheUpdateTotalTime: CFTimeInterval = 0
    private var cacheUpdateMaxTime: CFTimeInterval = 0

    // DeliveryMode toggle (for PhotoKit only)
    private var useFastFormat: Bool = false

    // Quality degradation during scroll
    private var isScrolling: Bool = false
    private var lowQualityThumbnailSize: CGSize = .zero  // smaller size for fast scroll

    // L1 test (flick + deceleration simulation - same pattern as L2 but slower)
    private var l1TestDisplayLink: CADisplayLink?
    private var l1TestStartTime: CFTimeInterval = 0
    private let l1TestDuration: CFTimeInterval = 10.0
    private let l1FlickSpeed: CGFloat = 6000  // initial flick speed (pt/s)
    private let l1DecelerationRate: CGFloat = 0.975  // per-frame deceleration
    private let l1MinSpeedForNewFlick: CGFloat = 500  // trigger new flick when speed drops below this
    private var l1CurrentSpeed: CGFloat = 0
    private var l1CurrentDirection: CGFloat = 1  // 1 = down, -1 = up
    private var l1FlickCount: Int = 0

    // L2 test (extreme flick + deceleration simulation)
    // Pattern: flick → decelerate → new flick (with direction change) → ...
    // Mimics aggressive user behavior: fast swipes with natural slowdown
    private var l2TestDisplayLink: CADisplayLink?
    private var l2TestStartTime: CFTimeInterval = 0
    private var l2Button: UIBarButtonItem?
    private let l2TestDuration: CFTimeInterval = 10.0
    private let l2FlickSpeed: CGFloat = 10000  // initial flick speed (pt/s) - increased from 6000
    private let l2DecelerationRate: CGFloat = 0.975  // per-frame deceleration
    private let l2MinSpeedForNewFlick: CGFloat = 500  // trigger new flick when speed drops below this
    private var l2CurrentSpeed: CGFloat = 0
    private var l2CurrentDirection: CGFloat = 1  // 1 = down, -1 = up
    private var l2FlickCount: Int = 0

    // Experiment mode for A/B testing
    enum ExperimentMode {
        case normal      // 기존 로직 (metrics, dedupe, cancel 포함)
        case minimal     // 최소화 (이미지 적용만, 다른 로직 제거)
    }
    private let experimentMode: ExperimentMode

    // R2: 정지 복구 디바운스 타이머
    private var r2DebounceTimer: Timer?
    private let r2DebounceInterval: TimeInterval = 0.2  // 200ms
    private let r2MaxRecoveryCount: Int = 15  // 동시 재요청 상한

    // MARK: - Pipeline Candidate (Gate 2 Test Plan)

    /// 파이프라인 후보 (gate2-pipeline-test.md 참조)
    enum PipelineCandidate: String, CaseIterable {
        case baseline = "Baseline"      // 현행 (Control)
        case candidateA = "A"           // fastFormat + didEndDisplaying + R2만
        case candidateA_R1R2 = "A+R1R2" // fastFormat + didEndDisplaying + R1+R2
        case candidateD = "D"           // Adaptive 2-Stage
        case candidateB1 = "B1"         // preheat OFF only
        case candidateB2 = "B2"         // B1 + quality 30%
        case candidateB3 = "B3"         // B2 + fastFormat
        case candidateB4 = "B4"         // B3 + didEndDisplaying
        case candidateC = "C"           // maxInFlight 제한

        var description: String {
            switch self {
            case .baseline: return "현행 (opportunistic, prepareForReuse)"
            case .candidateA: return "fastFormat + didEndDisplaying + R2만"
            case .candidateA_R1R2: return "fastFormat + didEndDisplaying + R1+R2"
            case .candidateD: return "Adaptive 2-Stage (Photos 모방)"
            case .candidateB1: return "preheat 스크롤 중 OFF"
            case .candidateB2: return "B1 + quality 30%"
            case .candidateB3: return "B2 + fastFormat"
            case .candidateB4: return "B3 + didEndDisplaying"
            case .candidateC: return "maxInFlight 8개 제한"
            }
        }
    }
    private let pipelineCandidate: PipelineCandidate

    // Pipeline settings (derived from candidate)
    private var useDidEndDisplayingCancel: Bool = false
    private var scrollQualityScale: CGFloat = 0.5  // 50% default
    private var maxInFlight: Int = 0  // 0 = unlimited
    private var currentInFlight: Int = 0
    private var upgradeAfterScroll: Bool = false  // Candidate D: 정지 후 100% 업그레이드
    private var useR1Recovery: Bool = false  // R1: willDisplay 기반 자동 복구

    // MARK: - Init

    init(provider: ImageProvider, name: String, experimentMode: ExperimentMode = .normal, pipeline: PipelineCandidate = .baseline) {
        self.provider = provider
        self.providerName = name
        self.experimentMode = experimentMode
        self.pipelineCandidate = pipeline
        super.init(nibName: nil, bundle: nil)

        // Apply pipeline settings
        applyPipelineSettings()
    }

    /// 파이프라인 후보에 따른 설정 적용
    private func applyPipelineSettings() {
        switch pipelineCandidate {
        case .baseline:
            // 현행 유지
            useFastFormat = false
            useDidEndDisplayingCancel = false
            preheatMode = .on
            scrollQualityScale = 0.5
            maxInFlight = 0
            upgradeAfterScroll = false

        case .candidateA:
            // fastFormat + didEndDisplaying + R2만
            useFastFormat = true
            useDidEndDisplayingCancel = true
            preheatMode = .on
            scrollQualityScale = 0.5
            maxInFlight = 0
            upgradeAfterScroll = false
            useR1Recovery = false  // R2만

        case .candidateA_R1R2:
            // fastFormat + didEndDisplaying + R1+R2
            useFastFormat = true
            useDidEndDisplayingCancel = true
            preheatMode = .on
            scrollQualityScale = 0.5
            maxInFlight = 0
            upgradeAfterScroll = false
            useR1Recovery = true  // R1+R2

        case .candidateD:
            // Adaptive 2-Stage (Photos 모방)
            useFastFormat = true
            useDidEndDisplayingCancel = true
            preheatMode = .throttle  // 150ms throttle
            scrollQualityScale = 0.5
            maxInFlight = 0
            upgradeAfterScroll = true  // 정지 후 100% 업그레이드

        case .candidateB1:
            // preheat 스크롤 중 OFF만
            useFastFormat = false
            useDidEndDisplayingCancel = false
            preheatMode = .off
            scrollQualityScale = 0.5
            maxInFlight = 0
            upgradeAfterScroll = false

        case .candidateB2:
            // B1 + quality 30%
            useFastFormat = false
            useDidEndDisplayingCancel = false
            preheatMode = .off
            scrollQualityScale = 0.3
            maxInFlight = 0
            upgradeAfterScroll = false

        case .candidateB3:
            // B2 + fastFormat
            useFastFormat = true
            useDidEndDisplayingCancel = false
            preheatMode = .off
            scrollQualityScale = 0.3
            maxInFlight = 0
            upgradeAfterScroll = false

        case .candidateB4:
            // B3 + didEndDisplaying
            useFastFormat = true
            useDidEndDisplayingCancel = true
            preheatMode = .off
            scrollQualityScale = 0.3
            maxInFlight = 0
            upgradeAfterScroll = false

        case .candidateC:
            // maxInFlight 제한 (Baseline + 제한)
            useFastFormat = false
            useDidEndDisplayingCancel = false
            preheatMode = .on
            scrollQualityScale = 0.5
            maxInFlight = 8
            upgradeAfterScroll = false
        }

        print("[Pipeline] Candidate: \(pipelineCandidate.rawValue) - \(pipelineCandidate.description)")
        print("  fastFormat: \(useFastFormat), didEndCancel: \(useDidEndDisplayingCancel)")
        print("  preheat: \(preheatMode.rawValue), quality: \(Int(scrollQualityScale * 100))%")
        print("  maxInFlight: \(maxInFlight == 0 ? "unlimited" : "\(maxInFlight)"), upgrade: \(upgradeAfterScroll)")
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
        // 파이프라인 후보 표시
        if pipelineCandidate == .baseline {
            title = "Gate 2: \(providerName)"
        } else {
            title = "Gate 2: [\(pipelineCandidate.rawValue)] \(providerName)"
        }
        view.backgroundColor = .systemBackground

        // Navigation items
        testButton = UIBarButtonItem(title: "Start", style: .plain, target: self, action: #selector(toggleManualTest))
        autoButton = UIBarButtonItem(title: "L1", style: .plain, target: self, action: #selector(runAutoTest))
        l2Button = UIBarButtonItem(title: "L2", style: .plain, target: self, action: #selector(runL2Test))
        preheatButton = UIBarButtonItem(title: "P:\(preheatMode.rawValue)", style: .plain, target: self, action: #selector(cyclePreheatWindow))

        if provider is PhotoKitImageProvider {
            // PhotoKit: no scale button (uses real library), add deliveryMode toggle
            navigationItem.rightBarButtonItems = [
                testButton!,
                autoButton!,
                l2Button!,
                preheatButton!
            ]
            let modeLabel = useFastFormat ? "Fast" : "Opp"
            navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: modeLabel,
                style: .plain,
                target: self,
                action: #selector(toggleDeliveryMode)
            )
        } else {
            // Mock: include scale button
            navigationItem.rightBarButtonItems = [
                testButton!,
                autoButton!,
                l2Button!,
                preheatButton!,
                UIBarButtonItem(title: formatCount(scaleOptions[currentScaleIndex]), style: .plain, target: self, action: #selector(cycleScale))
            ]
        }

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
        // Low quality size: scrollQualityScale of full size (faster decode during scroll)
        lowQualityThumbnailSize = CGSize(
            width: cellWidth * scale * scrollQualityScale,
            height: cellWidth * scale * scrollQualityScale
        )
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
        // Cycle through preheat modes: ON → 150ms → OFF → ON
        let modes = PreheatMode.allCases
        if let currentIndex = modes.firstIndex(of: preheatMode) {
            preheatMode = modes[(currentIndex + 1) % modes.count]
        } else {
            preheatMode = .on
        }

        updatePreheatButtonTitle()
        print("Preheat mode: \(preheatMode.rawValue) (window: ±\(preheatWindow))")

        // Reset preheat
        previousVisibleIndexes.removeAll()
        if preheatMode != .off {
            updateCachedAssets()
        }
    }

    private func updatePreheatButtonTitle() {
        let modeStr = preheatMode.rawValue
        preheatButton?.title = "P:\(modeStr)"
        // Color indication
        switch preheatMode {
        case .on:
            preheatButton?.tintColor = nil
        case .throttle:
            preheatButton?.tintColor = .systemOrange
        case .off:
            preheatButton?.tintColor = .systemRed
        }
    }

    @objc private func toggleDeliveryMode() {
        guard let photoKitProvider = provider as? PhotoKitImageProvider else { return }

        useFastFormat.toggle()
        photoKitProvider.useFastFormat = useFastFormat

        let modeLabel = useFastFormat ? "Fast" : "Opp"
        navigationItem.leftBarButtonItem?.title = modeLabel

        let modeName = useFastFormat ? "fastFormat (single callback)" : "opportunistic (multi callback)"
        print("DeliveryMode: \(modeName)")

        // Reload to apply new mode
        collectionView.reloadData()
    }

    // MARK: - Manual Test (Start/Stop)

    @objc private func toggleManualTest() {
        if isManualTestRunning {
            stopManualTest()
        } else {
            startManualTest()
        }
    }

    private func startManualTest() {
        guard provider.count > 100 else {
            statusLabel.text = "Need more items for test"
            return
        }

        isManualTestRunning = true
        testButton?.title = "Stop"
        testButton?.tintColor = .systemRed

        hitchMonitor.start()
        loadingMetrics.start()
        resetCacheUpdateMetrics()

        statusLabel.text = "📊 Measuring... Scroll freely, then tap Stop"
        print("\n=== Manual Scroll Test Start (\(providerName), Preheat: \(preheatMode.rawValue)) ===")
        print("Scroll freely, then tap Stop to see results")
    }

    private func stopManualTest() {
        isManualTestRunning = false
        testButton?.title = "Start"
        testButton?.tintColor = nil

        let hitchResult = hitchMonitor.stop()
        let loadingResult = loadingMetrics.stop()

        showTestResult(hitchResult: hitchResult, loadingResult: loadingResult, testType: "Manual")
    }

    // MARK: - L1 Test (Flick Simulation - same as L2 but slower)

    @objc private func runAutoTest() {
        guard provider.count > 100 else {
            statusLabel.text = "Need more items for test"
            return
        }

        // Stop other tests if running
        if isManualTestRunning { stopManualTest() }
        if l2TestDisplayLink != nil { stopL2Test() }

        // Stop existing L1 test if running
        if l1TestDisplayLink != nil {
            stopL1Test()
            return
        }

        statusLabel.text = "🚀 L1: flick + decelerate pattern (10s, \(Int(l1FlickSpeed)) pt/s)"
        print("\n=== L1 Flick Test Start (\(providerName), ±\(preheatWindow)) ===")
        print("Pattern: flick (\(Int(l1FlickSpeed)) pt/s) → decelerate → new flick...")

        // Jump to middle first
        let middleIndex = provider.count / 2
        collectionView.scrollToItem(
            at: IndexPath(item: middleIndex, section: 0),
            at: .centeredVertically,
            animated: false
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startL1Scroll()
        }
    }

    private func startL1Scroll() {
        hitchMonitor.start()
        loadingMetrics.start()

        l1TestStartTime = CACurrentMediaTime()
        l1CurrentSpeed = l1FlickSpeed
        l1CurrentDirection = 1
        l1FlickCount = 1

        l1TestDisplayLink = CADisplayLink(target: self, selector: #selector(l1ScrollTick))
        l1TestDisplayLink?.add(to: .main, forMode: .common)

        autoButton?.title = "Stop"
        autoButton?.tintColor = .systemOrange

        print("  [L1] Flick #1 started (↓)")
    }

    @objc private func l1ScrollTick(_ displayLink: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - l1TestStartTime

        if elapsed >= l1TestDuration {
            stopL1Test()
            return
        }

        // Apply deceleration
        l1CurrentSpeed *= l1DecelerationRate

        // New flick when speed drops too low
        if l1CurrentSpeed < l1MinSpeedForNewFlick {
            // 40% chance to change direction
            if Double.random(in: 0...1) < 0.4 {
                l1CurrentDirection *= -1
            }
            // Random speed variation (0.8x ~ 1.2x)
            l1CurrentSpeed = l1FlickSpeed * CGFloat(Double.random(in: 0.8...1.2))
            l1FlickCount += 1
            let dirSymbol = l1CurrentDirection > 0 ? "↓" : "↑"
            print("  [L1] Flick #\(l1FlickCount) at \(String(format: "%.1f", elapsed))s (\(dirSymbol))")
        }

        // Calculate delta
        let frameDuration = displayLink.targetTimestamp - displayLink.timestamp
        let delta = l1CurrentSpeed * CGFloat(frameDuration) * l1CurrentDirection

        // Apply scroll
        var newOffset = collectionView.contentOffset.y + delta
        let maxOffset = collectionView.contentSize.height - collectionView.bounds.height

        // Bounce at bounds
        if newOffset < 0 {
            newOffset = 0
            l1CurrentDirection = 1
            l1CurrentSpeed = l1FlickSpeed * 0.6
        } else if newOffset > maxOffset {
            newOffset = maxOffset
            l1CurrentDirection = -1
            l1CurrentSpeed = l1FlickSpeed * 0.6
        }

        collectionView.contentOffset.y = newOffset
    }

    private func stopL1Test() {
        l1TestDisplayLink?.invalidate()
        l1TestDisplayLink = nil

        autoButton?.title = "L1"
        autoButton?.tintColor = nil

        let hitchResult = hitchMonitor.stop()
        let loadingResult = loadingMetrics.stop()

        showTestResult(hitchResult: hitchResult, loadingResult: loadingResult, testType: "L1 (Flick)")
    }

    // MARK: - L2 Test (Flick Simulation)

    @objc private func runL2Test() {
        guard provider.count > 100 else {
            statusLabel.text = "Need more items for test"
            return
        }

        // Stop other tests if running
        if isManualTestRunning { stopManualTest() }
        if l1TestDisplayLink != nil { stopL1Test() }

        // Stop existing L2 test if running
        if l2TestDisplayLink != nil {
            stopL2Test()
            return
        }

        statusLabel.text = "🔥 L2: extreme flick pattern (10s, \(Int(l2FlickSpeed)) pt/s)"
        print("\n=== L2 Extreme Flick Test Start (\(providerName), ±\(preheatWindow)) ===")
        print("Pattern: flick (\(Int(l2FlickSpeed)) pt/s) → decelerate → new flick...")

        // Jump to middle first
        let middleIndex = provider.count / 2
        collectionView.scrollToItem(
            at: IndexPath(item: middleIndex, section: 0),
            at: .centeredVertically,
            animated: false
        )

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.startL2Scroll()
        }
    }

    private func startL2Scroll() {
        hitchMonitor.start()
        loadingMetrics.start()

        l2TestStartTime = CACurrentMediaTime()
        l2CurrentSpeed = l2FlickSpeed
        l2CurrentDirection = 1
        l2FlickCount = 1

        l2TestDisplayLink = CADisplayLink(target: self, selector: #selector(l2ScrollTick))
        l2TestDisplayLink?.add(to: .main, forMode: .common)

        l2Button?.title = "Stop"
        l2Button?.tintColor = .systemRed

        print("  [L2] Flick #1 started (↓)")
    }

    @objc private func l2ScrollTick(_ displayLink: CADisplayLink) {
        let elapsed = CACurrentMediaTime() - l2TestStartTime

        if elapsed >= l2TestDuration {
            stopL2Test()
            return
        }

        // Apply deceleration
        l2CurrentSpeed *= l2DecelerationRate

        // New flick when speed drops too low
        if l2CurrentSpeed < l2MinSpeedForNewFlick {
            // 40% chance to change direction
            if Double.random(in: 0...1) < 0.4 {
                l2CurrentDirection *= -1
            }
            // Random speed variation (0.8x ~ 1.2x)
            l2CurrentSpeed = l2FlickSpeed * CGFloat(Double.random(in: 0.8...1.2))
            l2FlickCount += 1
            let dirSymbol = l2CurrentDirection > 0 ? "↓" : "↑"
            print("  [L2] Flick #\(l2FlickCount) at \(String(format: "%.1f", elapsed))s (\(dirSymbol))")
        }

        // Calculate delta
        let frameDuration = displayLink.targetTimestamp - displayLink.timestamp
        let delta = l2CurrentSpeed * CGFloat(frameDuration) * l2CurrentDirection

        // Apply scroll
        var newOffset = collectionView.contentOffset.y + delta
        let maxOffset = collectionView.contentSize.height - collectionView.bounds.height

        // Bounce at bounds
        if newOffset < 0 {
            newOffset = 0
            l2CurrentDirection = 1
            l2CurrentSpeed = l2FlickSpeed * 0.6
        } else if newOffset > maxOffset {
            newOffset = maxOffset
            l2CurrentDirection = -1
            l2CurrentSpeed = l2FlickSpeed * 0.6
        }

        collectionView.contentOffset.y = newOffset
    }

    private func stopL2Test() {
        l2TestDisplayLink?.invalidate()
        l2TestDisplayLink = nil

        l2Button?.title = "L2"
        l2Button?.tintColor = nil

        let hitchResult = hitchMonitor.stop()
        let loadingResult = loadingMetrics.stop()

        showTestResult(hitchResult: hitchResult, loadingResult: loadingResult, testType: "L2 (Extreme)")
    }

    // MARK: - Test Result Display

    private func showTestResult(hitchResult: HitchResult, loadingResult: ImageLoadingResult, testType: String) {
        let grade = hitchResult.appleGrade
        let emoji = grade == "Good" ? "✅" : (grade == "Warning" ? "⚠️" : "❌")

        statusLabel.text = """
            \(emoji) \(grade) | hitch: \(String(format: "%.1f", hitchResult.hitchTimeRatio)) ms/s
            req/s: \(String(format: "%.0f", loadingResult.requestsPerSecond)) | maxInFlight: \(loadingResult.maxInFlight)
            latency avg: \(String(format: "%.1f", loadingResult.avgLatencyMs))ms p95: \(String(format: "%.1f", loadingResult.p95LatencyMs))ms
            """

        print("\n=== \(testType) Scroll Test Result ===")
        print("Provider: \(providerName), Preheat: \(preheatMode.rawValue)")
        print("Duration: \(String(format: "%.1f", loadingResult.durationSeconds))s")
        print(hitchResult.formatted())
        print(loadingResult.formatted())

        // cacheUpdate stats (Manual only)
        if testType == "Manual" && cacheUpdateCallCount > 0 {
            let callsPerSec = Double(cacheUpdateCallCount) / loadingResult.durationSeconds
            let avgMs = (cacheUpdateTotalTime / Double(cacheUpdateCallCount)) * 1000
            let maxMs = cacheUpdateMaxTime * 1000
            print("cacheUpdate: \(String(format: "%.1f", callsPerSec))/s | avg: \(String(format: "%.2f", avgMs))ms | max: \(String(format: "%.2f", maxMs))ms")
        }

        print(emoji + " " + grade)

        // Auto classification (Manual only)
        if testType == "Manual" {
            classifyManualResult(hitchResult: hitchResult, loadingResult: loadingResult)
        }
    }

    // MARK: - Manual Result Classification

    private func classifyManualResult(hitchResult: HitchResult, loadingResult: ImageLoadingResult) {
        print("\n--- Auto Classification ---")

        let reqS = loadingResult.requestsPerSecond
        let cancelS = loadingResult.cancelsPerSecond
        let completeS = loadingResult.completesPerSecond
        let maxInFlight = loadingResult.maxInFlight
        let hitch = hitchResult.hitchTimeRatio
        let longest = hitchResult.longestHitch
        let avgFrame = hitchResult.avgFrameTimeMs

        // Step 0: Noise check
        var noiseReasons: [String] = []
        if avgFrame < 15.0 || avgFrame > 18.0 {
            noiseReasons.append("avgFrame(\(String(format: "%.1f", avgFrame))ms) abnormal")
        }
        if !noiseReasons.isEmpty {
            print("⚠️ NOISE suspected: \(noiseReasons.joined(separator: ", "))")
            print("   → Recommend: Release build retest")
        }

        // Step 1: Burst type check (pipeline collapse)
        var burstConditions = 0
        var burstReasons: [String] = []

        if reqS > 0 && cancelS >= reqS * 0.5 {
            burstConditions += 1
            burstReasons.append("cancel/s(\(String(format: "%.0f", cancelS))) >= 50% of req/s")
        }
        if reqS > 0 && completeS < reqS * 0.8 {
            burstConditions += 1
            burstReasons.append("complete/s(\(String(format: "%.0f", completeS))) < 80% of req/s")
        }
        if maxInFlight >= 15 {
            burstConditions += 1
            burstReasons.append("maxInFlight(\(maxInFlight)) >= 15")
        }

        if burstConditions >= 2 {
            print("🔴 Classification: BURST (pipeline collapse)")
            print("   Reasons: \(burstReasons.joined(separator: ", "))")
            print("   Improvements:")
            print("   1. Request dedupe (same assetID+targetSize)")
            print("   2. Cancel policy (didEndDisplaying only)")
            print("   3. preheat/updateCachedAssets throttling")
            print("   4. Velocity-based quality degradation")
            return
        }

        // Step 2: Main thread intrusion check
        var intrusionConditions = 0
        var intrusionReasons: [String] = []

        if reqS > 0 && completeS >= reqS * 0.9 {
            intrusionConditions += 1
            intrusionReasons.append("complete/s >= 90% of req/s (pipeline OK)")
        }
        if reqS > 0 && cancelS < reqS * 0.2 {
            intrusionConditions += 1
            intrusionReasons.append("cancel/s < 20% (low cancellation)")
        }
        if longest <= 2 && hitch >= 10.0 {
            intrusionConditions += 1
            intrusionReasons.append("longest(\(longest)f) small but hitch(\(String(format: "%.1f", hitch))) high")
        }

        if intrusionConditions >= 2 {
            print("🟡 Classification: MAIN THREAD INTRUSION")
            print("   Reasons: \(intrusionReasons.joined(separator: ", "))")
            print("   Improvements:")
            print("   1. scrollViewDidScroll throttling (updateCachedAssets)")
            print("   2. Image callback/cell apply cost reduction")
            print("   3. Ensure decode not on main thread")
            print("   4. Velocity-based quality degradation")
            return
        }

        // Unclassified
        if hitch >= 10.0 {
            print("⚪ Classification: UNCLASSIFIED (Critical but no clear pattern)")
            print("   → Need more investigation")
        } else {
            print("✅ Classification: OK (hitch within acceptable range)")
        }
    }

    // MARK: - Preheat (Caching)

    private func updateCachedAssets() {
        guard provider.count > 0, preheatWindow > 0 else { return }

        let startTime = CACurrentMediaTime()

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

        // Measurement
        let elapsed = CACurrentMediaTime() - startTime
        cacheUpdateCallCount += 1
        cacheUpdateTotalTime += elapsed
        cacheUpdateMaxTime = max(cacheUpdateMaxTime, elapsed)
    }

    private func resetCacheUpdateMetrics() {
        cacheUpdateCallCount = 0
        cacheUpdateTotalTime = 0
        cacheUpdateMaxTime = 0
    }

    private func getCacheUpdateStats() -> (callsPerSec: Double, avgMs: Double, maxMs: Double) {
        guard cacheUpdateCallCount > 0 else { return (0, 0, 0) }
        let avgMs = (cacheUpdateTotalTime / Double(cacheUpdateCallCount)) * 1000
        let maxMs = cacheUpdateMaxTime * 1000
        return (0, avgMs, maxMs)  // callsPerSec calculated in showTestResult
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

        // MINIMAL MODE: 최소화된 로직 (이미지 적용만)
        if experimentMode == .minimal {
            cell.representedIdentifier = identifier
            cell.imageView.image = nil

            // 이미지 요청만 (metrics, dedupe, cancel 없음)
            _ = provider.requestImage(at: indexPath.item, targetSize: thumbnailSize) { [weak cell] result in
                guard cell?.representedIdentifier == identifier else { return }
                cell?.imageView.image = result.image
            }
            return cell
        }

        // NORMAL MODE: 기존 로직 (metrics, dedupe, cancel 포함)

        // Cancel previous request for this indexPath (prevent wrong image)
        if activeRequests[indexPath] != nil {
            activeRequests[indexPath]?.cancel()
            activeRequests.removeValue(forKey: indexPath)
            pendingIdentifiers.remove(identifier)
            loadingMetrics.recordCancel(id: identifier)
        }

        cell.representedIdentifier = identifier
        cell.imageView.image = nil

        // Dedupe: skip if this identifier is already being requested elsewhere
        if pendingIdentifiers.contains(identifier) {
            // Already pending - skip duplicate request
            return cell
        }

        // MaxInFlight check (Candidate C)
        if maxInFlight > 0 && currentInFlight >= maxInFlight {
            // Skip request - at capacity
            pendingIdentifiers.remove(identifier)
            return cell
        }

        // Record request start
        pendingIdentifiers.insert(identifier)
        loadingMetrics.recordRequest(id: identifier)
        if maxInFlight > 0 { currentInFlight += 1 }

        // Use smaller size during scroll for faster decode
        let requestSize = isScrolling ? lowQualityThumbnailSize : thumbnailSize

        // Request image
        let request = provider.requestImage(at: indexPath.item, targetSize: requestSize) { [weak self, weak cell] result in
            // Decrement inFlight counter
            if let self = self, self.maxInFlight > 0 {
                self.currentInFlight = max(0, self.currentInFlight - 1)
            }

            // Token verification: only apply if still same identifier
            guard cell?.representedIdentifier == identifier else { return }

            // Always update UI (degraded or final)
            cell?.imageView.image = result.image

            // Only record completion for FINAL image (not degraded)
            // This gives accurate latency for actual decode time
            if !result.isDegraded {
                self?.pendingIdentifiers.remove(identifier)
                self?.loadingMetrics.recordComplete(id: identifier)
                // Clear from active requests when final arrives
                self?.activeRequests.removeValue(forKey: indexPath)
            }
        }

        if let request = request {
            activeRequests[indexPath] = request
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension Gate2ViewController: UICollectionViewDelegate {

    // MARK: - 스크롤 시작 시 R2 타이머 취소
    // 정지 후 예약된 R2(200ms)가 다음 스크롤 중(또는 감속 중)에 뒤늦게 실행되는 것을 방지
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        isScrolling = true
        r2DebounceTimer?.invalidate()
        r2DebounceTimer = nil
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // Track scrolling state
        isScrolling = scrollView.isTracking || scrollView.isDragging || scrollView.isDecelerating

        // Throttled caching update based on preheatMode
        guard let interval = preheatMode.interval else { return }  // OFF mode: skip

        let now = CACurrentMediaTime()
        if now - lastCacheUpdateTime >= interval {
            lastCacheUpdateTime = now
            updateCachedAssets()
        }
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            // Stopped without deceleration - upgrade visible cells to high quality
            isScrolling = false
            upgradeVisibleCellsToHighQuality()
            // R2: 정지 복구 트리거 (디바운스)
            scheduleR2Recovery()
        }
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // Stopped after deceleration - upgrade visible cells to high quality
        isScrolling = false
        upgradeVisibleCellsToHighQuality()
        // R2: 정지 복구 트리거 (디바운스)
        scheduleR2Recovery()
    }

    // MARK: - R2: 정지 복구 (Gate 2 Contract)
    // 계약: 정지 시점에 이미 화면에 남아 있는 회색 셀 자동 복구
    // 디바운스로 잔여 이벤트 마무리 후 1회 실행

    private func scheduleR2Recovery() {
        // 기존 타이머 취소 (디바운스)
        r2DebounceTimer?.invalidate()

        // 디바운스 후 실행
        r2DebounceTimer = Timer.scheduledTimer(withTimeInterval: r2DebounceInterval, repeats: false) { [weak self] _ in
            self?.executeR2Recovery()
        }
    }

    private func executeR2Recovery() {
        // visible 셀 중 image가 nil인 셀만 수집
        let visibleCells = collectionView.visibleCells.compactMap { $0 as? ImageCell }
        let placeholderCells = visibleCells.filter { $0.imageView.image == nil }

        guard !placeholderCells.isEmpty else { return }

        print("[R2] 정지 복구: \(placeholderCells.count)개 회색 셀 발견")

        // 상한 적용 (동시 재요청 제한)
        let cellsToRecover = Array(placeholderCells.prefix(r2MaxRecoveryCount))

        for cell in cellsToRecover {
            guard let indexPath = collectionView.indexPath(for: cell) else { continue }

            let identifier = provider.identifier(at: indexPath.item)

            // 이미 요청 중이면 skip
            if pendingIdentifiers.contains(identifier) { continue }
            if activeRequests[indexPath] != nil { continue }

            // MaxInFlight check
            if maxInFlight > 0 && currentInFlight >= maxInFlight { continue }

            // 고품질(100%)로 재요청
            pendingIdentifiers.insert(identifier)
            loadingMetrics.recordRequest(id: identifier)
            if maxInFlight > 0 { currentInFlight += 1 }

            let request = provider.requestImage(at: indexPath.item, targetSize: thumbnailSize) { [weak self, weak cell] result in
                if let self = self, self.maxInFlight > 0 {
                    self.currentInFlight = max(0, self.currentInFlight - 1)
                }

                guard cell?.representedIdentifier == identifier else { return }
                cell?.imageView.image = result.image

                if !result.isDegraded {
                    self?.pendingIdentifiers.remove(identifier)
                    self?.loadingMetrics.recordComplete(id: identifier)
                    self?.activeRequests.removeValue(forKey: indexPath)
                }
            }

            if let request = request {
                activeRequests[indexPath] = request
            }
        }

        if cellsToRecover.count < placeholderCells.count {
            print("[R2] 상한 초과: \(placeholderCells.count - cellsToRecover.count)개는 다음 턴으로 미룸")
        }
    }

    private func upgradeVisibleCellsToHighQuality() {
        // Only upgrade if upgradeAfterScroll is enabled (Candidate D)
        guard upgradeAfterScroll else { return }

        // Reload visible cells to get high quality thumbnails
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        for indexPath in visibleIndexPaths {
            guard let cell = collectionView.cellForItem(at: indexPath) as? ImageCell else { continue }

            let identifier = provider.identifier(at: indexPath.item)

            // Skip if already loading or same identifier
            if pendingIdentifiers.contains(identifier) { continue }

            // Request high quality
            pendingIdentifiers.insert(identifier)

            let request = provider.requestImage(at: indexPath.item, targetSize: thumbnailSize) { [weak self, weak cell] result in
                guard cell?.representedIdentifier == identifier else { return }
                cell?.imageView.image = result.image

                if !result.isDegraded {
                    self?.pendingIdentifiers.remove(identifier)
                    self?.activeRequests.removeValue(forKey: indexPath)
                }
            }

            if let request = request {
                activeRequests[indexPath] = request
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // Cancel request when cell goes offscreen (only if useDidEndDisplayingCancel is enabled)
        guard useDidEndDisplayingCancel else { return }

        if let request = activeRequests.removeValue(forKey: indexPath) {
            request.cancel()
            let identifier = provider.identifier(at: indexPath.item)
            pendingIdentifiers.remove(identifier)
            loadingMetrics.recordCancel(id: identifier)
        }
    }

    // MARK: - R1: willDisplay 기반 자동 복구 (조건부)
    // useR1Recovery가 true일 때만 동작 (candidateA_R1R2)

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        // R1 비활성화 시 skip
        guard useR1Recovery else { return }
        guard let imageCell = cell as? ImageCell else { return }

        // R1 조건: 셀이 placeholder 상태(이미지 nil)이고, 요청이 진행 중이 아니면 재요청
        let identifier = provider.identifier(at: indexPath.item)

        // 이미 이미지가 있으면 skip (정상 상태)
        if imageCell.imageView.image != nil { return }

        // 이미 요청 중이면 skip (중복 방지)
        if pendingIdentifiers.contains(identifier) { return }
        if activeRequests[indexPath] != nil { return }

        // MaxInFlight check (Candidate C)
        if maxInFlight > 0 && currentInFlight >= maxInFlight { return }

        // 재요청 실행
        pendingIdentifiers.insert(identifier)
        loadingMetrics.recordRequest(id: identifier)
        if maxInFlight > 0 { currentInFlight += 1 }

        let requestSize = isScrolling ? lowQualityThumbnailSize : thumbnailSize

        let request = provider.requestImage(at: indexPath.item, targetSize: requestSize) { [weak self, weak imageCell] result in
            if let self = self, self.maxInFlight > 0 {
                self.currentInFlight = max(0, self.currentInFlight - 1)
            }

            guard imageCell?.representedIdentifier == identifier else { return }
            imageCell?.imageView.image = result.image

            if !result.isDegraded {
                self?.pendingIdentifiers.remove(identifier)
                self?.loadingMetrics.recordComplete(id: identifier)
                self?.activeRequests.removeValue(forKey: indexPath)
            }
        }

        if let request = request {
            activeRequests[indexPath] = request
        }
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

// GridViewController.swift
// 사진 그리드 뷰컨트롤러
//
// T022: GridViewController 생성
// - UICollectionView, 3열 기본 레이아웃
// - 2pt 셀 간격, 정사각형 비율 (FR-001)
// - CompositionalLayout
//
// T023: 핀치 줌 제스처 구현
// - 1/3/5열 전환, threshold 0.85/1.15, cooldown 200ms, 앵커 유지
//
// T024: ImagePipeline preheat/stopPreheating을 prefetchDataSource와 연동
//
// T025: 스크롤 스로틀링 (100ms 간격) 및 품질 저하 (스크롤 중 50% 썸네일 크기) 구현
//
// T026: PHPhotoLibraryChangeObserver 연동하여 실시간 업데이트
//
// T027-1f: Edge-to-edge 설정
// - contentInsetAdjustmentBehavior = .never
// - contentInset/indicatorInsets = 플로팅 UI 높이
// - viewDidLayoutSubviews, viewSafeAreaInsetsDidChange에서 업데이트
//
// T037~T045: Select 모드 및 다중 선택 삭제 (Phase 5)
// - SelectionManager 연동
// - 탭으로 선택, 드래그로 연속 선택
// - 일괄 삭제 구현
//
// T064: (FR-033 변경) Limited도 Denied와 동일하게 PermissionViewController 표시
//       → limitedAccessBanner 제거됨

import UIKit
import Photos
import PhotosUI
import AppCore

/// 사진 그리드 뷰컨트롤러
/// All Photos 그리드를 표시하고 핀치 줌, 스크롤 최적화 등을 처리
final class GridViewController: BaseGridViewController {

    // MARK: - Constants

    // cellSpacing → BaseGridViewController로 이동됨
    // GridColumnCount → GridColumnCount.swift로 이동됨
    // Pinch Zoom 상수 → BaseGridViewController로 이동됨

    /// 스크롤 스로틀링 간격 (Step 1: 200ms로 증가) (extension에서 접근 필요)
    static let scrollThrottleInterval: TimeInterval = 0.2

    /// preheat 최대 셀 수 (Step 1: ±1 row = 6셀) (extension에서 접근 필요)
    static let maxPreheatCells: Int = 6

    /// 스크롤 중 썸네일 품질 저하 비율 (T025: 50%) (extension에서 접근 필요)
    static let scrollingThumbnailScale: CGFloat = 0.5

    // MARK: - UI Components

    // collectionView, emptyStateView → BaseGridViewController로 이동됨

    // T064: (FR-033 변경) limitedAccessBanner 제거됨
    // Limited도 Denied와 동일하게 PermissionViewController에서 처리

    // MARK: - Properties

    /// 데이터소스 드라이버 (extension에서 접근 필요)
    let dataSourceDriver: GridDataSourceDriver

    // imagePipeline, trashStore → BaseGridViewController로 이동됨
    // currentGridColumnCount, currentCellSize → BaseGridViewController로 이동됨
    // lastPinchZoomTime, pinchAnchorAssetID → BaseGridViewController로 이동됨

    /// 스크롤 스로틀링 마지막 시간
    private var lastScrollTime: Date?

    /// 스크롤 중 여부 (extension에서 접근 필요)
    var isScrolling: Bool = false

    /// 스크롤 종료 감지 타이머 (extension에서 접근 필요)
    var scrollEndTimer: Timer?

    /// 최초 로드 시 맨 아래로 스크롤 여부 (FR-003)
    private var hasScrolledToBottom: Bool = false

    /// 초기 화면 프리히트 완료 여부 (v6: viewDidAppear에서 호출) (extension에서 접근 필요)
    var hasPreheatedInitialScreen: Bool = false

    // MARK: - Pending Viewer Return (iOS 18+ Zoom Transition 안정화)

    // pendingScrollAssetID → BaseGridViewController로 이동됨

    /// 현재 열린 뷰어 참조 (완전삭제 완료 후 알림용)
    /// Push/Modal 방식에 무관하게 접근 가능하도록 weak 참조 저장
    private weak var activeViewerVC: ViewerViewController?

    /// 뷰어 복귀 후 사용자가 스크롤했는지 여부
    /// - true이면 applyPendingViewerReturn()에서 강제 스크롤 skip
    private var didUserScrollAfterReturn: Bool = false

    // MARK: - Initial Display State (B+A 조합 v2)

    /// 초기 표시 완료 여부 (단일 상태 - finishInitialDisplay에서만 변경) (extension에서 접근 필요)
    var hasFinishedInitialDisplay: Bool = false

    /// 프리로드 완료 카운터 (extension에서 접근 필요)
    var preloadCompletedCount: Int = 0

    /// 프리로드 목표 개수 (visible 기반 동적 계산) (extension에서 접근 필요)
    var preloadTargetCount: Int = 0

    /// 초기 표시 타임아웃 (100ms) (extension에서 접근 필요)
    static let initialDisplayTimeout: TimeInterval = 0.1

    /// 셀 표시 허용 여부 (B+A v2: finishInitialDisplay 전까지 false)
    /// - false: numberOfItemsInSection이 0 반환 → 레이아웃 패스에서 셀 생성 차단
    /// - true: 실제 count 반환 → 프리로드 완료 후 메모리 캐시 히트
    /// (extension에서 접근 필요)
    var shouldShowItems: Bool = false

    // Note: Select Mode 프로퍼티는 BaseGridViewController로 이동됨
    // - isSelectMode, selectionManager, dragSelectGesture, dragSelect* 등
    // - selectionCountBarItem, autoScrollTimer, autoScrollSpeed, autoScrollEdgeHeight

    /// PRD7: 이전 휴지통 상태 (changedIDs 계산용)
    private var lastTrashedIDs: Set<String> = []

    // MARK: - R2 로그 측정용 (extension에서 접근 필요)

    /// 스크롤 중 peak velocity (Y축, pt/s)
    /// - scrollViewDidScroll에서 실시간 계산
    /// - 손가락으로 멈추든, 플릭으로 멈추든 스크롤 중 최대 속도 측정
    var peakScrollVelocityY: CGFloat = 0

    /// scrollViewWillEndDragging의 velocity (Y축, pt/s)
    /// - 시스템이 계산한 종료 속도 (peak 보완용)
    var lastEndVelocityY: CGFloat = 0

    /// velocity 계산용 이전 offset/time
    private var lastScrollOffset: CGFloat = 0
    private var lastVelocityCalcTime: CFTimeInterval = 0

    /// 스크롤 시퀀스 (로그 매칭용)
    var scrollSeq: Int = 0

    /// 마지막 스크롤 종료 시간 (R2 응답 시간 계산용)
    var lastScrollEndTime: CFTimeInterval = 0

    /// [Phase 2] 감속 중 preheat 플래그 (중복 호출 방지)
    var isDecelerationPreheatScheduled = false

    // paddingCellCount → BaseGridViewController로 이동됨

    // MARK: - Timing (초기 로딩 측정용)

    /// 로딩 시작 시간 (viewDidLoad 시점) (extension에서 접근 필요)
    var loadStartTime: CFTimeInterval = 0

    /// 첫 레이아웃 완료 여부
    private var hasLoggedFirstLayout: Bool = false

    /// 첫 셀 표시 완료 여부
    private var hasLoggedFirstCellDisplay: Bool = false

    /// [DEBUG] cellForItemAt 호출 횟수 (초기 3초간) (extension에서 접근 필요)
    var cellForItemAtCount: Int = 0

    /// [DEBUG] cellForItemAt 누적 시간 (초기 3초간) (extension에서 접근 필요)
    var cellForItemAtTotalTime: CFTimeInterval = 0

    /// [DEBUG] 이미지 completion 호출 횟수 (초기 3초간)
    private var imageCompletionCount: Int = 0

    /// [DEBUG] cellForItemAt 내부 구간별 누적 시간
    private var cellDequeueTime: CFTimeInterval = 0
    private var cellAssetTime: CFTimeInterval = 0
    private var cellTrashTime: CFTimeInterval = 0
    private var cellConfigureTime: CFTimeInterval = 0

    // MARK: - Scroll Quality Monitoring (B: HitchMonitor)

    /// 스크롤 히치 모니터 (Apple 방식) (extension에서 접근 필요)
    let hitchMonitor = HitchMonitor()

    /// 첫 스크롤 완료 여부 (First Scroll 집계용) (extension에서 접근 필요)
    var hasCompletedFirstScroll: Bool = false

    /// 첫 스크롤 시작 시간 (extension에서 접근 필요)
    var firstScrollStartTime: CFTimeInterval = 0

    /// 현재 스크롤 세션의 시작 시간 (구간 구분용) (extension에서 접근 필요)
    var currentScrollStartTime: CFTimeInterval = 0

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - dataSourceDriver: 데이터소스 드라이버
    ///   - imagePipeline: 이미지 파이프라인
    ///   - trashStore: 휴지통 스토어
    init(
        dataSourceDriver: GridDataSourceDriver = GridDataSourceDriver(),
        imagePipeline: ImagePipelineProtocol = ImagePipeline.shared,
        trashStore: TrashStoreProtocol = TrashStore.shared
    ) {
        self.dataSourceDriver = dataSourceDriver
        // GridDataSourceDriverAdapter 생성
        self._gridDataSourceAdapter = GridDataSourceDriverAdapter(driver: dataSourceDriver)
        super.init(imagePipeline: imagePipeline, trashStore: trashStore)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - BaseGridViewController Overrides

    /// GridDataSourceDriverAdapter 저장 (gridDataSource 오버라이드용)
    private let _gridDataSourceAdapter: GridDataSourceDriverAdapter

    /// 데이터 소스 (GridDataSourceDriver를 GridDataSource로 래핑)
    override var gridDataSource: GridDataSource {
        _gridDataSourceAdapter
    }

    /// 스와이프 삭제 지원 (PRD7)
    override var supportsSwipeDelete: Bool { true }

    /// 빈 상태 설정
    override var emptyStateConfig: (icon: String, title: String, subtitle: String?) {
        ("photo.on.rectangle", "사진이 없습니다", "사진을 촬영하거나 가져오세요")
    }

    /// 네비게이션 타이틀
    /// ⚠️ 사진보관함 명칭 변경 시 동시 수정 필요:
    /// - TabBarController.swift: tabBarItem.title
    /// - FloatingOverlayContainer.swift: titleBar.title
    /// - FloatingTitleBar.swift: title 기본값
    override var navigationTitle: String {
        "사진보관함"
    }

    /// 줌 완료 후 호출 (고해상도 썸네일 재요청)
    override func didPerformZoom(to columns: GridColumnCount) {
        refreshVisibleCellsAfterZoom()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        // [Timing] 로딩 시작 시간 기록 (super.viewDidLoad 전에)
        loadStartTime = CACurrentMediaTime()
        Log.print("[Timing] === 초기 로딩 시작 ===")

        // BaseGridViewController.viewDidLoad()에서 setupUI, setupGestures, additionalSetup 호출
        super.viewDidLoad()

        // loadData()는 viewDidLayoutSubviews에서 startInitialDisplay()로 호출
        // (레이아웃 확정 후에만 실행해야 size=0 버그 방지)

        // T027-1f: 플로팅 UI 사용 시에는 setContentScrollView 불필요
        // (시스템 바가 숨겨져 있으므로)
        // iOS 26+에서 시스템 바 사용 시에만 활성화
        if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 바 사용, edge-to-edge 투명 효과 활성화
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
            // contentInsetAdjustmentBehavior를 automatic으로 복원
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }
    }

    /// 추가 설정 (viewDidLoad에서 호출됨)
    override func additionalSetup() {
        setupObservers()

        if AutoScrollTester.shouldInstallGestureByLaunchArguments {
            collectionView.setupAutoScrollGesture()
        }

        // 정리 버튼 설정 (auto-cleanup)
        setupCleanupButton()
    }

    /// 추가 제스처 설정 (setupGestures에서 호출됨)
    /// Note: 스와이프 삭제 제스처는 Base.setupGestures에서 supportsSwipeDelete 체크 후 자동 설정됨
    override func setupAdditionalGestures() {
        // 드래그 선택 제스처 (T040)
        // Select 모드에서만 활성화됨
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragSelectGesture(_:)))
        dragGesture.minimumNumberOfTouches = 1
        dragGesture.maximumNumberOfTouches = 1
        dragGesture.delegate = self
        dragGesture.isEnabled = false // 기본 비활성화, Select 모드 진입 시 활성화
        collectionView.addGestureRecognizer(dragGesture)
        dragSelectGesture = dragGesture

        // 자동 스크롤 테스트 제스처 (3손가락 탭)
        collectionView.setupAutoScrollGesture()
    }

    /// 초기 표시 트리거 여부 (viewDidLayoutSubviews에서 1회만 실행)
    private var hasTriggeredInitialDisplay: Bool = false

    override func viewWillAppear(_ animated: Bool) {
        // BaseGridViewController.viewWillAppear에서 configureFloatingOverlay() 호출
        super.viewWillAppear(animated)

        // 현재 화면이 TrashStore 변경을 받도록 핸들러 재등록
        trashStore.onStateChange { [weak self] trashedAssetIDs in
            self?.handleTrashStateChange(trashedAssetIDs)
        }
        handleTrashStateChange(trashStore.trashedAssetIDs)

        // [DEBUG] viewWillAppear 호출 시점
        let vwaTime = CACurrentMediaTime()
        let vwaMs = loadStartTime > 0 ? (vwaTime - loadStartTime) * 1000 : -1

        // 초기 진입 시에는 startInitialDisplay()에서 처리하므로 스킵
        if !hasFinishedInitialDisplay {
            Log.print("[Timing] viewWillAppear: +\(String(format: "%.1f", vwaMs))ms (초기 진입 - reloadData 스킵)")
            return
        }

        // iOS 18+ Zoom Transition 안정화: 전환 중이면 completion에서 처리
        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.applyPendingViewerReturn()
            }
            Log.print("[Timing] viewWillAppear: +\(String(format: "%.1f", vwaMs))ms (전환 중 - completion 예약)")
            return
        }

        Log.print("[Timing] viewWillAppear.reloadData: +\(String(format: "%.1f", vwaMs))ms")
        // 화면 표시 시 변경사항 반영 (탭 전환 등)
        collectionView.reloadData()
    }

    /// FloatingOverlay 상태를 Photos 탭용으로 설정
    /// - 타이틀: "사진보관함"
    /// - 뒤로가기 버튼: 숨김
    /// - 오른쪽 버튼: "Select"으로 복원
    override func configureFloatingOverlay() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        // ⚠️ 사진보관함 명칭 변경 시 동시 수정 필요:
        // - TabBarController.swift: tabBarItem.title
        // - GridViewController.swift: title, setTitle() (여기)
        // - FloatingOverlayContainer.swift: titleBar.title
        // - FloatingTitleBar.swift: title 기본값
        overlay.titleBar.setTitle("사진보관함")
        updateItemCountSubtitle()

        // 뒤로가기 버튼 숨김
        overlay.titleBar.setShowsBackButton(false)

        // [Select] [정리] 두 개 버튼으로 설정 (auto-cleanup)
        setupFloatingCleanupButton()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // iOS 18+ Zoom Transition 안정화: fallback (transitionCoordinator 없을 때)
        applyPendingViewerReturn()

        // [LiquidGlass 최적화] 블러 뷰 사전 생성 + idle pause
        LiquidGlassOptimizer.preload(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)

        // 런치 아규먼트 로깅 (디버깅용)
        let args = ProcessInfo.processInfo.arguments
        Log.print("[LaunchArgs] count=\(args.count), contains --auto-scroll: \(args.contains("--auto-scroll"))")

        AutoScrollTester.shared.startIfRequestedByLaunchArguments(scrollView: collectionView)

        // [A) preheat OFF 테스트] 초기 프리히트 비활성화
        // v6: visible indexPaths가 확실히 채워진 시점에 초기 프리히트
        // preheatInitialScreen()
    }

    override func viewDidLayoutSubviews() {
        // BaseGridViewController.viewDidLayoutSubviews에서 updateCellSize, updateContentInset 호출
        super.viewDidLayoutSubviews()

        // B+A v2: 레이아웃 확정 후 1회만 초기 표시 시작
        // (currentCellSize가 확정된 후에만 프리로드/reloadData 실행)
        if !hasTriggeredInitialDisplay && currentCellSize != .zero {
            hasTriggeredInitialDisplay = true
            startInitialDisplay()
        }

        // [Timing] C) 첫 레이아웃 완료 (1회만)
        if !hasLoggedFirstLayout && loadStartTime > 0 {
            hasLoggedFirstLayout = true
            let layoutTime = CACurrentMediaTime()
            let sinceStart = (layoutTime - loadStartTime) * 1000
            Log.print("[Timing] C) 첫 레이아웃 완료: +\(String(format: "%.1f", sinceStart))ms")
        }
    }

    // viewSafeAreaInsetsDidChange → BaseGridViewController에서 처리

    // MARK: - Setup

    // setupUI, setupGestures → BaseGridViewController로 이동됨
    // T064: (FR-033 변경) limitedAccessBanner 제거됨
    // Limited도 Denied와 동일하게 PermissionViewController에서 처리

    /// 옵저버 설정 (T026, T037)
    private func setupObservers() {
        // PhotoLibrary 변경 감지
        PhotoLibraryService.shared.onLibraryChange { [weak self] change in
            self?.handleLibraryChange(change)
        }
        PhotoLibraryService.shared.startObservingChanges()

        // TrashStore 변경 감지
        trashStore.onStateChange { [weak self] trashedAssetIDs in
            self?.handleTrashStateChange(trashedAssetIDs)
        }

        // SelectionManager 델리게이트 설정 (T037)
        selectionManager.delegate = self

        // AutoScrollTester 스크롤 시작/끝 알림 수신 (성능 측정 트리거)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoScrollDidBegin),
            name: AutoScrollTester.didBeginScrollingNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAutoScrollDidEnd),
            name: AutoScrollTester.didEndScrollingNotification,
            object: nil
        )

        // PRD7: VoiceOver 상태 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )

        // PRD7: 앱 백그라운드 진입 시 스와이프 취소
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )

        // [SimilarPhoto] 유사 사진 기능 옵저버 설정 (T019)
        setupSimilarPhotoObserver()
    }

    @objc private func handleAutoScrollDidBegin() {
        scrollDidBegin()
    }

    @objc private func handleAutoScrollDidEnd() {
        scrollDidEnd()
    }

    /// PRD7: VoiceOver 상태 변경 시 스와이프 제스처 활성화/비활성화
    @objc private func voiceOverStatusChanged() {
        updateSwipeDeleteGestureEnabled()
    }

    /// PRD7: 앱 백그라운드 진입 시 활성 스와이프 취소
    @objc private func appDidEnterBackground() {
        cancelActiveSwipe()
    }

    // startInitialDisplay() → GridScroll.swift로 이동됨

    // MARK: - Layout

    // createLayout, updateCellSize → BaseGridViewController로 이동됨

    /// contentInset 업데이트 (플로팅 UI 높이 반영, fallback 처리 포함)
    override func updateContentInset() {
        // iOS 26+에서는 시스템 자동 조정 사용
        if #available(iOS 26.0, *) {
            return
        }

        // TabBarController에서 오버레이 높이 가져오기
        guard let tabBarController = tabBarController as? TabBarController,
              let heights = tabBarController.getOverlayHeights() else {
            // 플로팅 UI가 없으면 safe area만 적용 (fallback)
            let inset = UIEdgeInsets(
                top: view.safeAreaInsets.top,
                left: 0,
                bottom: view.safeAreaInsets.bottom,
                right: 0
            )
            collectionView.contentInset = inset
            collectionView.scrollIndicatorInsets = inset
            return
        }

        // 플로팅 UI 높이를 contentInset으로 설정
        let inset = UIEdgeInsets(
            top: heights.top,
            left: 0,
            bottom: heights.bottom,
            right: 0
        )

        collectionView.contentInset = inset
        collectionView.scrollIndicatorInsets = inset

        Log.print("[GridViewController] ContentInset updated - top: \(heights.top), bottom: \(heights.bottom)")
    }

    /// 현재 썸네일 크기 반환 (스크롤 상태에 따라 품질 저하 적용)
    /// - Parameter forScrolling: 스크롤용 저품질 크기 요청 여부
    /// - Returns: 썸네일 크기 (픽셀 단위)
    override func thumbnailSize() -> CGSize {
        thumbnailSize(forScrolling: false)
    }

    /// 현재 썸네일 크기 반환 (스크롤 상태에 따라 품질 저하 적용) (extension에서 접근 필요)
    func thumbnailSize(forScrolling: Bool) -> CGSize {
        let baseSize = currentCellSize
        let scale = UIScreen.main.scale

        if forScrolling || isScrolling {
            // T025: 스크롤 중 50% 크기
            return CGSize(
                width: baseSize.width * scale * Self.scrollingThumbnailScale,
                height: baseSize.height * scale * Self.scrollingThumbnailScale
            )
        } else {
            return CGSize(
                width: baseSize.width * scale,
                height: baseSize.height * scale
            )
        }
    }

    // Pinch Zoom 코드 → BaseGridViewController로 이동됨

    // MARK: - Library Change (T026)

    /// 사진 라이브러리 변경 처리
    private func handleLibraryChange(_ change: PHChange) {
        dataSourceDriver.applyChange(
            change,
            to: collectionView,
            anchorAssetID: nil,
            columns: currentGridColumnCount.rawValue
        ) { [weak self] _ in
            self?.updateEmptyState()
        }
    }

    /// 휴지통 상태 변경 처리
    /// PRD7: reloadItems 대신 변경된 셀만 직접 업데이트 (깜빡임 방지)
    private func handleTrashStateChange(_ trashedAssetIDs: Set<String>) {
        // 변경된 ID 계산 (이전 상태와의 차이)
        let changedIDs = lastTrashedIDs.symmetricDifference(trashedAssetIDs)
        lastTrashedIDs = trashedAssetIDs

        // 변경된 ID가 없으면 무시
        guard !changedIDs.isEmpty else { return }

        // 보이는 셀 중 변경된 것만 업데이트
        for indexPath in collectionView.indexPathsForVisibleItems {
            // padding 보정하여 실제 assetID 계산
            let actualIndex = indexPath.item - paddingCellCount
            guard actualIndex >= 0 else { continue }

            guard let assetID = dataSourceDriver.assetID(at: IndexPath(item: actualIndex, section: 0)) else {
                continue
            }

            // 변경된 ID가 아니면 스킵
            guard changedIDs.contains(assetID) else { continue }

            // 셀 가져오기
            guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else {
                continue
            }

            // 애니메이션 중인 셀은 스킵 (스와이프/투핑거탭 진행 중)
            guard !cell.isAnimating else { continue }

            // 딤드 상태만 업데이트 (이미지 리로드 없이)
            cell.updateTrashState(trashedAssetIDs.contains(assetID))
        }

        Log.print("[GridViewController] Updated \(changedIDs.count) changed cells (no reloadItems)")
    }

    // MARK: - Subtitle (사진 개수 표시)

    /// 사진 개수 서브타이틀 업데이트
    private func updateItemCountSubtitle() {
        let count = dataSourceDriver.count
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        let subtitleText = "\(formatted)개의 항목"

        // iOS 18: FloatingTitleBar 서브타이틀
        if let tabBarController = tabBarController as? TabBarController,
           let overlay = tabBarController.floatingOverlay {
            overlay.titleBar.setSubtitle(subtitleText)
        }

        // iOS 26: 네비게이션 바 서브타이틀
        if let subtitleLabel = navSubtitleLabel {
            subtitleLabel.text = subtitleText
            subtitleLabel.isHidden = false
        }
    }

    // MARK: - Empty State (T070)

    /// 빈 상태 업데이트 (extension에서 접근 필요)
    override func updateEmptyState() {
        let isEmpty = dataSourceDriver.count == 0
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
        updateItemCountSubtitle()
    }

    // Scroll Optimization / Initial Display / Initial Preheat → GridScroll.swift로 이동됨
}

// MARK: - UICollectionViewDataSource (Override)

extension GridViewController {

    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // B+A v2: 프리로드 완료 전까지 셀 생성 차단
        // shouldShowItems가 false면 0 반환 → UICollectionView 레이아웃 패스에서 셀 미생성
        guard shouldShowItems else { return 0 }

        // 실제 사진 수 + 맨 위 행 빈 셀 수
        return dataSourceDriver.count + paddingCellCount
    }

    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // [DEBUG] cellForItemAt 시간 측정 (초기 3초간)
        let cellStart = CACurrentMediaTime()
        let sinceStart = loadStartTime > 0 ? (cellStart - loadStartTime) * 1000 : -1
        let isInitialPeriod = sinceStart >= 0 && sinceStart < 3000

        // [DEBUG] 구간별 시간 측정용
        var t0, t1, t2, t3, t4: CFTimeInterval
        t0 = cellStart

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCell.reuseIdentifier,
            for: indexPath
        ) as? PhotoCell else {
            return UICollectionViewCell()
        }

        t1 = CACurrentMediaTime() // dequeue 완료

        // T027-2: 맨 위 행 빈 셀 처리
        let padding = paddingCellCount
        if indexPath.item < padding {
            // 빈 셀 - 투명하게 표시
            cell.configureAsEmpty()
            return cell
        }

        // 실제 에셋 인덱스 계산 (padding 오프셋 적용)
        let assetIndexPath = IndexPath(item: indexPath.item - padding, section: indexPath.section)

        // 에셋 정보 가져오기
        guard let asset = dataSourceDriver.asset(at: assetIndexPath) else {
            return cell
        }

        t2 = CACurrentMediaTime() // asset 조회 완료

        let isTrashed = trashStore.isTrashed(asset.localIdentifier)

        t3 = CACurrentMediaTime() // trash 체크 완료

        // 셀 설정 (PHAsset 직접 전달 - 성능 최적화)
        // isFullSizeRequest: 스크롤 중이 아닐 때만 true (디스크 캐시 저장 조건)
        cell.configure(
            asset: asset,
            isTrashed: isTrashed,
            targetSize: thumbnailSize(),
            isFullSizeRequest: !isScrolling
        )

        t4 = CACurrentMediaTime() // configure 완료

        // [DEBUG] 구간별 시간 누적
        if isInitialPeriod {
            cellDequeueTime += (t1 - t0)
            cellAssetTime += (t2 - t1)
            cellTrashTime += (t3 - t2)
            cellConfigureTime += (t4 - t3)

            let cellMs = (t4 - t0) * 1000
            cellForItemAtCount += 1
            cellForItemAtTotalTime += cellMs

            // 스크롤 중 로그 비활성화 - hitch 방지
            // 원복: git checkout a5414d4 -- PickPhoto/PickPhoto/Features/Grid/GridViewController.swift
            // 매 10번째에 구간별 로그 출력 (임시 비활성화)
            // if cellForItemAtCount % 10 == 0 {
            //     Log.print("[Timing] cellForItemAt #\(cellForItemAtCount): ...")
            // }
        }

        // Select 모드일 때 선택 상태 표시 (T039, T045)
        if isSelectMode {
            let isSelected = selectionManager.isSelected(asset.localIdentifier)
            cell.isSelectedForDeletion = isSelected
        } else {
            cell.isSelectedForDeletion = false
        }

        // [SimilarPhoto] 테두리 애니메이션 구성 (T020)
        configureSimilarPhotoBorder(for: cell, at: indexPath)

        return cell
    }
}

// MARK: - UICollectionViewDelegate (Override)

extension GridViewController {

    // [Timing] D) 첫 셀 표시 완료
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !hasLoggedFirstCellDisplay && loadStartTime > 0 {
            hasLoggedFirstCellDisplay = true
            let displayTime = CACurrentMediaTime()
            let sinceStart = (displayTime - loadStartTime) * 1000
            Log.print("[Timing] D) 첫 셀 표시: +\(String(format: "%.1f", sinceStart))ms (indexPath: \(indexPath))")
        }

        // 회색 셀 측정: 화면에 표시되는 순간 이미지가 nil이면 카운트
        if let photoCell = cell as? PhotoCell, photoCell.isShowingGray {
            PhotoCell.incrementGrayShown()
        }
    }

    /// 셀이 화면에서 사라질 때 호출
    /// - [SimilarPhoto] 테두리 레이어 제거 (메모리 최적화)
    func collectionView(_ collectionView: UICollectionView, didEndDisplaying cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        guard let photoCell = cell as? PhotoCell else { return }

        // [SimilarPhoto] 테두리 레이어 제거 (T021)
        removeSimilarPhotoBorder(from: photoCell)
    }

    override func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // T027-2: 빈 셀 탭 무시
        let padding = paddingCellCount
        guard indexPath.item >= padding else { return }

        // Select 모드일 때는 선택 토글 (T039)
        if isSelectMode {
            toggleSelection(at: indexPath)
            return
        }

        // [Timing] 줌 전환 시작 전 랙 측정
        let t0 = CACurrentMediaTime()

        // 실제 에셋 인덱스 계산
        let assetIndexPath = IndexPath(item: indexPath.item - padding, section: indexPath.section)

        guard let fetchResult = dataSourceDriver.fetchResult else { return }

        // [수정] 보관함에서는 항상 .normal 모드로 뷰어 열기
        // 휴지통 사진도 마룬 테두리와 함께 표시되고, 복구 버튼이 표시됨
        let mode: ViewerMode = .normal

        let t1 = CACurrentMediaTime()

        // 뷰어 코디네이터 생성 (모드에 따라 필터링됨)
        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: mode,
            deleteSource: .library
        )

        let t2 = CACurrentMediaTime()

        // 원본 인덱스를 필터링된 인덱스로 변환 (padding 제외한 실제 인덱스 사용)
        guard let filteredIndex = coordinator.filteredIndex(from: assetIndexPath.item) else {
            Log.print("[GridViewController] Failed to find filtered index for \(assetIndexPath.item)")
            return
        }

        let t3 = CACurrentMediaTime()

        // 뷰어 뷰컨트롤러 생성
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: filteredIndex,
            mode: mode
        )
        viewerVC.delegate = self
        activeViewerVC = viewerVC  // weak 참조 저장 (완전삭제 완료 후 알림용)
        // [Timing] 탭 시점을 뷰어에 전달 (전체 구간 측정용)
        viewerVC.openStartTime = t0

        let t4 = CACurrentMediaTime()
        let t5 = t4

        // iOS 26+: Navigation Push 방식 (시스템 네비바/툴바 사용 가능)
        // iOS 16~25: Modal 방식 (커스텀 줌 트랜지션)
        if #available(iOS 26.0, *), let tbc = tabBarController as? TabBarController {
            tbc.zoomSourceProvider = self
            tbc.zoomDestinationProvider = viewerVC
            navigationController?.pushViewController(viewerVC, animated: true)
        } else {
            // 커스텀 줌 트랜지션 설정 (Modal 방식)
            let transitionController = ZoomTransitionController()
            transitionController.sourceProvider = self
            transitionController.destinationProvider = viewerVC
            // ⚠️ strong 참조 먼저 (transitioningDelegate는 weak)
            viewerVC.zoomTransitionController = transitionController
            viewerVC.transitioningDelegate = transitionController
            present(viewerVC, animated: true)
        }

        let t6 = CACurrentMediaTime()

        // [Timing] 각 단계별 소요 시간 출력
        Log.print("[Zoom Timing] 준비: \(String(format: "%.1f", (t1-t0)*1000))ms, Coordinator: \(String(format: "%.1f", (t2-t1)*1000))ms, filteredIndex: \(String(format: "%.1f", (t3-t2)*1000))ms, ViewerVC: \(String(format: "%.1f", (t4-t3)*1000))ms, transition설정: \(String(format: "%.1f", (t5-t4)*1000))ms, push: \(String(format: "%.1f", (t6-t5)*1000))ms, 총: \(String(format: "%.1f", (t6-t0)*1000))ms")
        Log.print("[GridViewController] Opening viewer at filtered index \(filteredIndex) (original: \(indexPath.item)), mode: \(mode)")
    }

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        scrollDidBegin()

        // 사용자가 스크롤 시작하면 pending 스크롤 취소 (롤백 방지)
        pendingScrollAssetID = nil
        didUserScrollAfterReturn = true

        // [R2] peak velocity 리셋 및 초기값 설정
        // 감속 중에 터치해서 멈춘 경우: peak 유지 (이전 스크롤 속도 보존)
        // 완전히 정지 후 새 스크롤: peak 리셋
        if !scrollView.isDecelerating {
            peakScrollVelocityY = 0
        }
        lastScrollOffset = scrollView.contentOffset.y
        lastVelocityCalcTime = CACurrentMediaTime()
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        // [R2] 실시간 velocity 계산 (스크롤 중 최대 속도 측정)
        let currentOffset = scrollView.contentOffset.y
        let currentTime = CACurrentMediaTime()
        let deltaTime = currentTime - lastVelocityCalcTime

        // 최소 시간 간격: 120Hz(8.3ms)에서도 동작하도록 5ms로 설정
        if deltaTime > 0.005 {
            let velocity = abs(currentOffset - lastScrollOffset) / deltaTime
            // peak velocity 갱신
            if velocity > peakScrollVelocityY {
                peakScrollVelocityY = velocity
            }
            lastScrollOffset = currentOffset
            lastVelocityCalcTime = currentTime
        }
    }

    func scrollViewWillEndDragging(
        _ scrollView: UIScrollView,
        withVelocity velocity: CGPoint,
        targetContentOffset: UnsafeMutablePointer<CGPoint>
    ) {
        // 시스템이 계산한 velocity로 peak 보완 (플릭 시 신뢰성 높음)
        let systemVelocity = abs(velocity.y)  // velocity.y는 pt/s 단위
        lastEndVelocityY = systemVelocity
        peakScrollVelocityY = max(peakScrollVelocityY, systemVelocity)

        // 스크롤 시퀀스 증가
        scrollSeq += 1

        // [Phase 2] 감속 시작 시점에 100% preheat 선행
        // - 목표 위치의 셀들을 미리 캐싱하여 정지 시 즉시 전환
        preheatForDeceleration(targetOffset: targetContentOffset.pointee)
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        // 손가락으로 멈춘 경우 (decelerate=false)도 scrollSeq 증가
        if !decelerate {
            scrollSeq += 1
            scrollDidEnd()
        }
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        scrollDidEnd()
    }
}

// MARK: - UICollectionViewDataSourcePrefetching (T024, Override)

extension GridViewController {

    override func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // [P0] 스크롤 중 preheat 완전 제거
        // - 근거: hitch 63% 개선 (40.7 → 15.0 ms/s), 회색 셀 차이 없음
        // - preheatAfterScrollStop()이 스크롤 정지 후 preheat 담당
        return
    }

    override func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // [P0] prefetch preheat 제거에 따라 cancel도 불필요
        return
    }
}

// MARK: - ViewerViewControllerDelegate (T036)

extension GridViewController: ViewerViewControllerDelegate {

    /// 사진 삭제 요청 (앱 내 휴지통으로 이동)
    /// T036: TrashStore 즉시 저장 연동
    func viewerDidRequestDelete(assetID: String) {
        // TrashStore에 이동 (즉시 저장됨)
        trashStore.moveToTrash(assetIDs: [assetID])

        // 그리드 셀 업데이트 (딤드 표시)
        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        if let indexPath = collectionIndexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        // [SimilarPhoto] 그룹 무효화 처리 (T022)
        handleSimilarPhotoAssetDeleted(assetID: assetID)

        Log.print("[GridViewController] Moved to trash: \(assetID.prefix(8))...")
    }

    /// 사진 복구 요청 (휴지통에서 복원)
    func viewerDidRequestRestore(assetID: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // TrashStore에서 복구 (즉시 저장됨)
        trashStore.restore(assetIDs: [assetID])

        let trashStoreTime = CFAbsoluteTimeGetCurrent()

        // 그리드 셀 업데이트 (딤드 제거)
        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        if let indexPath = collectionIndexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        let uiUpdateTime = CFAbsoluteTimeGetCurrent()

        Log.print("[GridViewController] Restored: \(assetID.prefix(8))...")
        Log.print("[GridViewController.Timing] trashStore: \(String(format: "%.1f", (trashStoreTime - startTime) * 1000))ms, uiUpdate: \(String(format: "%.1f", (uiUpdateTime - trashStoreTime) * 1000))ms, total: \(String(format: "%.1f", (uiUpdateTime - startTime) * 1000))ms")
    }

    /// 사진 완전삭제 요청 (iOS 휴지통으로 이동)
    /// 비동기 작업 - 삭제 완료 후 뷰어에 알림
    func viewerDidRequestPermanentDelete(assetID: String) {
        // TrashStore에서 완전삭제 (iOS 시스템 팝업 표시)
        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: [assetID])
                Log.print("[GridViewController] Permanently deleted: \(assetID.prefix(8))...")

                // 삭제 완료 후 뷰어에 알림 (메인 스레드에서)
                // weak 참조로 접근 (Push/Modal 방식에 무관)
                await MainActor.run {
                    self.activeViewerVC?.handleDeleteComplete()
                }
            } catch {
                Log.print("[GridViewController] Failed to permanently delete: \(error)")
            }
        }
    }

    /// 뷰어가 닫힐 때 호출
    /// iOS 18+ Zoom Transition 안정화: 전환 중 reloadData/scrollToItem 금지
    /// 실제 처리는 전환 완료 후 applyPendingViewerReturn()에서 수행
    func viewerWillClose(currentAssetID: String?) {
        // 뷰어 참조 정리
        activeViewerVC = nil
        // 스크롤 위치만 저장 (전환 완료 후 처리)
        pendingScrollAssetID = currentAssetID
        // 사용자 스크롤 플래그 초기화
        didUserScrollAfterReturn = false
    }

    /// 뷰어가 완전히 닫힌 후 호출 (dismiss/pop 애니메이션 완료 후)
    /// iOS 16~25 Modal (shouldRemovePresentersView=false) 경로에서
    /// viewWillAppear/viewDidAppear가 호출되지 않으므로 이 콜백으로 처리
    func viewerDidClose() {
        applyPendingViewerReturn()
    }

    /// 뷰어 닫힘 후 대기 중인 작업 처리 (전환 완료 후 호출)
    /// - reloadData() 제거: 변경은 viewerDidRequest*에서 이미 reloadItems() 처리됨
    /// - scroll만 수행하여 깜빡임 방지
    /// - 사용자가 이미 스크롤 중이면 강제 스크롤 skip (롤백 방지)
    private func applyPendingViewerReturn() {
        guard let assetID = pendingScrollAssetID else { return }
        pendingScrollAssetID = nil

        // 안전 가드 1: 사용자가 복귀 후 스크롤했으면 skip
        if didUserScrollAfterReturn {
            return
        }

        // 안전 가드 2: 현재 스크롤 중이면 skip
        if collectionView.isDragging || collectionView.isDecelerating {
            return
        }

        // iOS 사진 앱처럼: 마지막 보던 사진이 화면에 없으면 해당 위치로 스크롤
        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        guard let indexPath = collectionIndexPath(for: assetID) else { return }

        // 현재 보이는 셀인지 확인
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.contains(indexPath) {
            // 화면에 없으면 스크롤 (중앙에 위치하도록)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
    }
}

// Select Mode 코드 → GridSelectMode.swift로 이동됨

// MARK: - ZoomTransitionSourceProviding (커스텀 줌 트랜지션)

extension GridViewController: ZoomTransitionSourceProviding {

    /// 줌 애니메이션 시작 뷰 (셀의 이미지 뷰)
    /// - Parameter index: 현재 뷰어의 인덱스
    /// - Returns: PhotoCell의 thumbnailImageView 또는 nil
    func zoomSourceView(for index: Int) -> UIView? {
        // padding 보정하여 실제 셀 IndexPath 계산
        let cellIndexPath = IndexPath(item: index + paddingCellCount, section: 0)

        // 셀이 화면에 있는지 확인
        guard let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell else {
            return nil
        }

        // 이미지가 로드된 셀만 반환 (로드 전이면 nil → crossfade)
        guard cell.hasLoadedImage else { return nil }

        return cell.thumbnailImageView
    }

    /// 줌 애니메이션 시작 프레임 (window 좌표계)
    /// - Parameter index: 현재 뷰어의 인덱스
    /// - Returns: window 좌표계 기준 프레임 또는 nil
    func zoomSourceFrame(for index: Int) -> CGRect? {
        // 1. 셀이 있으면 직접 사용 (가장 정확)
        if let sourceView = zoomSourceView(for: index) {
            return sourceView.superview?.convert(sourceView.frame, to: nil)
        }

        // 2. 셀이 없으면 layout attributes로 프레임 계산
        // iOS 26에서 scrollToItem + layoutIfNeeded 후에도 셀이 dequeue 안 될 수 있음
        let cellIndexPath = IndexPath(item: index + paddingCellCount, section: 0)
        guard let attributes = collectionView.layoutAttributesForItem(at: cellIndexPath) else {
            return nil
        }
        return collectionView.convert(attributes.frame, to: nil)
    }

    /// 해당 인덱스의 셀이 보이도록 스크롤 (Pop 전 호출)
    /// - Parameter index: 스크롤할 원본 인덱스
    func scrollToSourceCell(for index: Int) {
        let cellIndexPath = IndexPath(item: index + paddingCellCount, section: 0)

        // 이미 화면에 보이면 스크롤 불필요
        if collectionView.indexPathsForVisibleItems.contains(cellIndexPath) {
            return
        }

        // 즉시 스크롤 (animated: false)
        collectionView.scrollToItem(at: cellIndexPath, at: .centeredVertically, animated: false)
        // iOS 26에서는 scrollToItem 후 셀 생성이 지연될 수 있으므로
        // collectionView + 부모 뷰 모두 레이아웃 강제 반영
        collectionView.layoutIfNeeded()
        view.layoutIfNeeded()
    }
}

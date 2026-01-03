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
final class GridViewController: UIViewController {

    // MARK: - Constants

    /// 셀 간격 (FR-001: 2pt) (extension에서 접근 필요)
    static let cellSpacing: CGFloat = 2

    /// 열 구성 (1/3/5)
    enum ColumnCount: Int, CaseIterable {
        case one = 1
        case three = 3
        case five = 5

        /// 다음 확대 열 수 (1 → 1, 3 → 1, 5 → 3)
        var zoomIn: ColumnCount {
            switch self {
            case .one: return .one
            case .three: return .one
            case .five: return .three
            }
        }

        /// 다음 축소 열 수 (1 → 3, 3 → 5, 5 → 5)
        var zoomOut: ColumnCount {
            switch self {
            case .one: return .three
            case .three: return .five
            case .five: return .five
            }
        }
    }

    // Pinch Zoom 상수 → GridGestures.swift로 이동됨

    /// 스크롤 스로틀링 간격 (Step 1: 200ms로 증가) (extension에서 접근 필요)
    static let scrollThrottleInterval: TimeInterval = 0.2

    /// preheat 최대 셀 수 (Step 1: ±1 row = 6셀) (extension에서 접근 필요)
    static let maxPreheatCells: Int = 6

    /// 스크롤 중 썸네일 품질 저하 비율 (T025: 50%) (extension에서 접근 필요)
    static let scrollingThumbnailScale: CGFloat = 0.5

    // MARK: - UI Components

    /// 컬렉션 뷰 (extension에서 접근 필요)
    lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout(columns: .three))
        cv.backgroundColor = .black
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.delegate = self
        cv.dataSource = self
        // [Step 1] prefetchDataSource 복원 (±1 row, 200ms throttle)
        cv.prefetchDataSource = self
        cv.alwaysBounceVertical = true
        // T027-1f: Edge-to-edge 설정
        // 플로팅 UI 사용 시 수동으로 contentInset 설정
        cv.contentInsetAdjustmentBehavior = .never
        return cv
    }()

    /// 빈 상태 뷰
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(
            icon: "photo.on.rectangle",
            title: "사진이 없습니다",
            subtitle: "사진을 촬영하거나 가져오세요"
        )
        view.useDarkTheme()  // 검정 배경에서 사용
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // T064: (FR-033 변경) limitedAccessBanner 제거됨
    // Limited도 Denied와 동일하게 PermissionViewController에서 처리

    // MARK: - Properties

    /// 데이터소스 드라이버 (extension에서 접근 필요)
    let dataSourceDriver: GridDataSourceDriver

    /// 이미지 파이프라인
    private let imagePipeline: ImagePipelineProtocol

    /// 휴지통 스토어 (extension에서 접근 필요)
    let trashStore: TrashStoreProtocol

    /// 현재 열 수 (extension에서 접근 필요)
    var currentColumnCount: ColumnCount = .three

    /// 현재 셀 크기 (캐시) (extension에서 접근 필요)
    var currentCellSize: CGSize = .zero

    /// 핀치 줌 마지막 실행 시간 (쿨다운용) (extension에서 접근 필요)
    var lastPinchZoomTime: Date?

    /// 핀치 줌 앵커 에셋 ID (extension에서 접근 필요)
    var pinchAnchorAssetID: String?

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

    /// 뷰어 닫힘 후 스크롤할 에셋 ID
    private var pendingScrollAssetID: String?

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

    /// Select 모드 여부 (extension에서 setter 접근 필요)
    internal(set) var isSelectMode: Bool = false

    /// 선택 관리자 (T037) (extension에서 접근 필요)
    let selectionManager = SelectionManager()

    /// 드래그 선택용 팬 제스처 (T040) (extension에서 접근 필요)
    var dragSelectGesture: UIPanGestureRecognizer?

    /// PRD7: 스와이프 삭제 상태 (extension에서 stored property 불가 → 구조체)
    var swipeDeleteState = SwipeDeleteState()

    /// PRD7: 이전 휴지통 상태 (changedIDs 계산용)
    private var lastTrashedIDs: Set<String> = []

    /// 드래그 선택 시작 시점의 인덱스 (T040) (extension에서 접근 필요)
    var dragSelectStartIndex: Int?

    /// 드래그 선택 중 현재 인덱스 (T040) (extension에서 접근 필요)
    var dragSelectCurrentIndex: Int?

    /// 드래그 선택 모드: 선택(true) 또는 해제(false) (T040)
    /// 첫 번째 셀이 이미 선택된 상태면 해제 모드, 아니면 선택 모드
    /// (extension에서 접근 필요)
    var dragSelectIsSelecting: Bool = true

    /// 드래그 선택 중 선택/해제된 인덱스 범위 (T040) (extension에서 접근 필요)
    var dragSelectAffectedIndices: Set<Int> = []

    /// 자동 스크롤 타이머 (화면 가장자리 드래그 시) (extension에서 접근 필요)
    var autoScrollTimer: Timer?

    // MARK: - iOS 26+ Select Mode UI (시스템 UI 사용)

    /// iOS 26+ 툴바의 선택 개수 라벨 (동적 업데이트용) (extension에서 접근 필요)
    var selectionCountBarItem: UIBarButtonItem?

    /// 자동 스크롤 영역 높이 (화면 상단/하단) (extension에서 접근 필요)
    static let autoScrollEdgeHeight: CGFloat = 60

    /// 자동 스크롤 속도 (포인트/초) (extension에서 접근 필요)
    static let autoScrollSpeed: CGFloat = 400

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

    /// 맨 위 행 빈 셀 개수 (T027-2: 3의 배수가 아닐 시 맨 위 행에 빈 셀)
    /// 최신 사진(맨 아래) 기준 꽉 차게 정렬
    /// (extension에서 접근 필요)
    var paddingCellCount: Int {
        let totalCount = dataSourceDriver.count
        guard totalCount > 0 else { return 0 }
        let columns = currentColumnCount.rawValue
        let remainder = totalCount % columns
        // 나머지가 0이면 빈 셀 없음, 아니면 (열 수 - 나머지) 만큼 빈 셀
        return remainder == 0 ? 0 : (columns - remainder)
    }

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
        self.imagePipeline = imagePipeline
        self.trashStore = trashStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.dataSourceDriver = GridDataSourceDriver()
        self.imagePipeline = ImagePipeline.shared
        self.trashStore = TrashStore.shared
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // [Timing] 로딩 시작 시간 기록
        loadStartTime = CACurrentMediaTime()
        FileLogger.log("[Timing] === 초기 로딩 시작 ===")

        setupUI()
        setupGestures()
        setupObservers()

        if AutoScrollTester.shouldInstallGestureByLaunchArguments {
            collectionView.setupAutoScrollGesture()
        }
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

    /// 초기 표시 트리거 여부 (viewDidLayoutSubviews에서 1회만 실행)
    private var hasTriggeredInitialDisplay: Bool = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // [DEBUG] viewWillAppear 호출 시점
        let vwaTime = CACurrentMediaTime()
        let vwaMs = loadStartTime > 0 ? (vwaTime - loadStartTime) * 1000 : -1

        // iOS 16~25: FloatingOverlay 상태 복원 (다른 탭에서 돌아올 때)
        configureFloatingOverlayForPhotos()

        // 초기 진입 시에는 startInitialDisplay()에서 처리하므로 스킵
        if !hasFinishedInitialDisplay {
            FileLogger.log("[Timing] viewWillAppear: +\(String(format: "%.1f", vwaMs))ms (초기 진입 - reloadData 스킵)")
            return
        }

        // iOS 18+ Zoom Transition 안정화: 전환 중이면 completion에서 처리
        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.applyPendingViewerReturn()
            }
            FileLogger.log("[Timing] viewWillAppear: +\(String(format: "%.1f", vwaMs))ms (전환 중 - completion 예약)")
            return
        }

        FileLogger.log("[Timing] viewWillAppear.reloadData: +\(String(format: "%.1f", vwaMs))ms")
        // 화면 표시 시 변경사항 반영 (탭 전환 등)
        collectionView.reloadData()
    }

    /// FloatingOverlay 상태를 Photos 탭용으로 복원
    /// - 타이틀: "Photos"
    /// - 뒤로가기 버튼: 숨김
    /// - 오른쪽 버튼: "Select"으로 복원
    private func configureFloatingOverlayForPhotos() {
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

        // 뒤로가기 버튼 숨김
        overlay.titleBar.setShowsBackButton(false)

        // Select 버튼으로 복원 (휴지통의 "비우기" 버튼에서 복원)
        overlay.titleBar.resetToSelectButton()
        overlay.titleBar.isSelectButtonHidden = false
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // iOS 18+ Zoom Transition 안정화: fallback (transitionCoordinator 없을 때)
        applyPendingViewerReturn()

        // 런치 아규먼트 로깅 (디버깅용)
        let args = ProcessInfo.processInfo.arguments
        FileLogger.log("[LaunchArgs] count=\(args.count), contains --auto-scroll: \(args.contains("--auto-scroll"))")

        AutoScrollTester.shared.startIfRequestedByLaunchArguments(scrollView: collectionView)

        // [A) preheat OFF 테스트] 초기 프리히트 비활성화
        // v6: visible indexPaths가 확실히 채워진 시점에 초기 프리히트
        // preheatInitialScreen()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 셀 크기 업데이트
        updateCellSize()
        // T027-1f: contentInset 업데이트 (플로팅 UI 높이 반영)
        updateContentInset()

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
            FileLogger.log("[Timing] C) 첫 레이아웃 완료: +\(String(format: "%.1f", sinceStart))ms")
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // T027-1f: safe area 변경 시 contentInset 재계산
        updateContentInset()
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        view.backgroundColor = .black
        // ⚠️ 상단 타이틀 명칭 변경 시 동시 수정 필요:
        // - GridViewController.swift: navigationItem.title (여기), setTitle()
        // - FloatingOverlayContainer.swift: titleBar.title
        // - FloatingTitleBar.swift: title 기본값
        // 주의: title 대신 navigationItem.title 사용 (tabBarItem.title 덮어쓰기 방지)
        navigationItem.title = "사진보관함"

        // 컬렉션 뷰
        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        // 빈 상태 뷰
        view.addSubview(emptyStateView)
        NSLayoutConstraint.activate([
            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            emptyStateView.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 40),
            emptyStateView.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -40)
        ])

        // T064: (FR-033 변경) limitedAccessBanner 제거됨
        // Limited도 Denied와 동일하게 PermissionViewController에서 처리
    }

    // MARK: - T064: (FR-033 변경) Limited Access Banner 제거됨
    // Limited도 Denied와 동일하게 PermissionViewController에서 처리
    // limitedAccessBannerTapped(), updateLimitedAccessBanner() 함수 제거됨

    /// 제스처 설정 (T023, T040)
    private func setupGestures() {
        // 핀치 줌 제스처 (T023)
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        // 드래그 선택 제스처 (T040)
        // Select 모드에서만 활성화됨
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragSelectGesture(_:)))
        dragGesture.minimumNumberOfTouches = 1
        dragGesture.maximumNumberOfTouches = 1
        dragGesture.delegate = self
        dragGesture.isEnabled = false // 기본 비활성화, Select 모드 진입 시 활성화
        collectionView.addGestureRecognizer(dragGesture)
        dragSelectGesture = dragGesture

        // PRD7: 스와이프/투핑거탭 제스처 (GridGestures.swift에서 구현)
        setupSwipeDeleteGestures()

        // 자동 스크롤 테스트 제스처 (3손가락 탭)
        collectionView.setupAutoScrollGesture()
    }

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

    /// CompositionalLayout 생성 (extension에서 접근 필요)
    /// - Parameter columns: 열 수
    /// - Returns: UICollectionViewLayout
    func createLayout(columns: ColumnCount) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let spacing = Self.cellSpacing
            let columnCount = CGFloat(columns.rawValue)

            // 셀 크기 계산 (정사각형)
            let totalSpacing = spacing * (columnCount - 1)
            let availableWidth = environment.container.effectiveContentSize.width - totalSpacing
            let cellWidth = floor(availableWidth / columnCount)

            // 아이템 크기
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellWidth),
                heightDimension: .absolute(cellWidth) // 정사각형 비율 (FR-001)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            // 그룹 (가로)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellWidth)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: columns.rawValue
            )
            group.interItemSpacing = .fixed(spacing)

            // 섹션
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            // Edge-to-edge: safe area 무시 (iOS 14+)
            section.contentInsetsReference = .none

            return section
        }

        return layout
    }

    /// 셀 크기 업데이트 (extension에서 접근 필요)
    func updateCellSize() {
        let spacing = Self.cellSpacing
        let columnCount = CGFloat(currentColumnCount.rawValue)
        let totalSpacing = spacing * (columnCount - 1)
        let availableWidth = view.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columnCount)

        currentCellSize = CGSize(width: cellWidth, height: cellWidth)
    }

    /// T027-1f: contentInset 업데이트 (플로팅 UI 높이 반영)
    private func updateContentInset() {
        // iOS 26+에서는 시스템 자동 조정 사용
        if #available(iOS 26.0, *) {
            return
        }

        // TabBarController에서 오버레이 높이 가져오기
        guard let tabBarController = tabBarController as? TabBarController,
              let heights = tabBarController.getOverlayHeights() else {
            // 플로팅 UI가 없으면 safe area만 적용
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

        print("[GridViewController] ContentInset updated - top: \(heights.top), bottom: \(heights.bottom)")
    }

    /// 현재 썸네일 크기 반환 (스크롤 상태에 따라 품질 저하 적용) (extension에서 접근 필요)
    func thumbnailSize(forScrolling: Bool = false) -> CGSize {
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

    // Pinch Zoom 코드 → GridGestures.swift로 이동됨

    // MARK: - Library Change (T026)

    /// 사진 라이브러리 변경 처리
    private func handleLibraryChange(_ change: PHChange) {
        dataSourceDriver.applyChange(
            change,
            to: collectionView,
            anchorAssetID: nil,
            columns: currentColumnCount.rawValue
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

        print("[GridViewController] Updated \(changedIDs.count) changed cells (no reloadItems)")
    }

    // MARK: - Empty State (T070)

    /// 빈 상태 업데이트 (extension에서 접근 필요)
    func updateEmptyState() {
        let isEmpty = dataSourceDriver.count == 0
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }

    // Scroll Optimization / Initial Display / Initial Preheat → GridScroll.swift로 이동됨
}

// MARK: - UICollectionViewDataSource

extension GridViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // B+A v2: 프리로드 완료 전까지 셀 생성 차단
        // shouldShowItems가 false면 0 반환 → UICollectionView 레이아웃 패스에서 셀 미생성
        guard shouldShowItems else { return 0 }

        // 실제 사진 수 + 맨 위 행 빈 셀 수
        return dataSourceDriver.count + paddingCellCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
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
            //     FileLogger.log("[Timing] cellForItemAt #\(cellForItemAtCount): ...")
            // }
        }

        // Select 모드일 때 선택 상태 표시 (T039, T045)
        if isSelectMode {
            let isSelected = selectionManager.isSelected(asset.localIdentifier)
            cell.isSelectedForDeletion = isSelected
        } else {
            cell.isSelectedForDeletion = false
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension GridViewController: UICollectionViewDelegate {

    // [Timing] D) 첫 셀 표시 완료
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !hasLoggedFirstCellDisplay && loadStartTime > 0 {
            hasLoggedFirstCellDisplay = true
            let displayTime = CACurrentMediaTime()
            let sinceStart = (displayTime - loadStartTime) * 1000
            FileLogger.log("[Timing] D) 첫 셀 표시: +\(String(format: "%.1f", sinceStart))ms (indexPath: \(indexPath))")
        }

        // 회색 셀 측정: 화면에 표시되는 순간 이미지가 nil이면 카운트
        if let photoCell = cell as? PhotoCell, photoCell.isShowingGray {
            PhotoCell.incrementGrayShown()
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
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

        // 휴지통 사진인지 확인
        let isTrashed = dataSourceDriver.assetID(at: assetIndexPath).flatMap { trashStore.isTrashed($0) } ?? false

        // 뷰어 모드 결정 (휴지통 사진은 trash 모드)
        let mode: ViewerMode = isTrashed ? .trash : .normal

        let t1 = CACurrentMediaTime()

        // 뷰어 코디네이터 생성 (모드에 따라 필터링됨)
        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: mode
        )

        let t2 = CACurrentMediaTime()

        // 원본 인덱스를 필터링된 인덱스로 변환 (padding 제외한 실제 인덱스 사용)
        guard let filteredIndex = coordinator.filteredIndex(from: assetIndexPath.item) else {
            print("[GridViewController] Failed to find filtered index for \(assetIndexPath.item)")
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

        let t4 = CACurrentMediaTime()

        // iOS 18+: 네이티브 zoom transition
        if #available(iOS 18.0, *) {
            // iOS 18에서는 ViewerViewController의 커스텀 페이드 애니메이션 비활성화 (이중 애니메이션 방지)
            viewerVC.disableCustomFadeAnimation = true

            viewerVC.preferredTransition = .zoom(sourceViewProvider: { [weak self, weak coordinator] context in
                guard let self = self,
                      let coordinator = coordinator,
                      let viewer = context.zoomedViewController as? ViewerViewController else {
                    return nil
                }

                // 뷰어의 현재 인덱스 (필터링된 인덱스)
                let currentFilteredIndex = viewer.currentIndex

                // 필터링된 인덱스 → 원본 인덱스 변환
                guard let originalIndex = coordinator.originalIndex(from: currentFilteredIndex) else {
                    return nil  // 인덱스 변환 실패 시 중앙에서 줌
                }

                // padding 셀 적용하여 실제 collectionView indexPath 계산
                let cellIndexPath = IndexPath(item: originalIndex + self.paddingCellCount, section: 0)

                // 셀이 화면에 없으면 nil 반환 (중앙에서 줌 fallback)
                guard let cell = self.collectionView.cellForItem(at: cellIndexPath) as? PhotoCell else {
                    return nil
                }

                // placeholder가 아닌 실제 이미지가 로드된 경우에만 줌 전환
                guard cell.hasLoadedImage else {
                    return nil  // 이미지 미로드 시 중앙에서 줌 (fallback)
                }

                // [DEBUG] 계단현상 원인 분석: 썸네일 vs 화면 픽셀 크기 비교
                let imageSize = cell.thumbnailImageView.image?.size ?? .zero
                let screenScale = UIScreen.main.scale
                let screenPixelSize = CGSize(
                    width: self.view.bounds.width * screenScale,
                    height: self.view.bounds.height * screenScale
                )
                print("[ZoomTransition] imageSize: \(Int(imageSize.width))x\(Int(imageSize.height))px, screenPixelSize: \(Int(screenPixelSize.width))x\(Int(screenPixelSize.height))px, scale: \(screenScale)x")

                return cell.thumbnailImageView
            })
        }

        let t5 = CACurrentMediaTime()

        // 뷰어 표시 (push 방식)
        navigationController?.pushViewController(viewerVC, animated: true)

        let t6 = CACurrentMediaTime()

        // [Timing] 각 단계별 소요 시간 출력
        print("[Zoom Timing] 준비: \(String(format: "%.1f", (t1-t0)*1000))ms, Coordinator: \(String(format: "%.1f", (t2-t1)*1000))ms, filteredIndex: \(String(format: "%.1f", (t3-t2)*1000))ms, ViewerVC: \(String(format: "%.1f", (t4-t3)*1000))ms, transition설정: \(String(format: "%.1f", (t5-t4)*1000))ms, push: \(String(format: "%.1f", (t6-t5)*1000))ms, 총: \(String(format: "%.1f", (t6-t0)*1000))ms")
        print("[GridViewController] Opening viewer at filtered index \(filteredIndex) (original: \(indexPath.item)), mode: \(mode)")
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

// MARK: - UICollectionViewDataSourcePrefetching (T024)

extension GridViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // [P0] 스크롤 중 preheat 완전 제거
        // - 근거: hitch 63% 개선 (40.7 → 15.0 ms/s), 회색 셀 차이 없음
        // - preheatAfterScrollStop()이 스크롤 정지 후 preheat 담당
        return
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
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
        if let indexPath = dataSourceDriver.indexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        print("[GridViewController] Moved to trash: \(assetID.prefix(8))...")
    }

    /// 사진 복구 요청 (휴지통에서 복원)
    func viewerDidRequestRestore(assetID: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        // TrashStore에서 복구 (즉시 저장됨)
        trashStore.restore(assetIDs: [assetID])

        let trashStoreTime = CFAbsoluteTimeGetCurrent()

        // 그리드 셀 업데이트 (딤드 제거)
        if let indexPath = dataSourceDriver.indexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        let uiUpdateTime = CFAbsoluteTimeGetCurrent()

        print("[GridViewController] Restored: \(assetID.prefix(8))...")
        print("[GridViewController.Timing] trashStore: \(String(format: "%.1f", (trashStoreTime - startTime) * 1000))ms, uiUpdate: \(String(format: "%.1f", (uiUpdateTime - trashStoreTime) * 1000))ms, total: \(String(format: "%.1f", (uiUpdateTime - startTime) * 1000))ms")
    }

    /// 사진 완전삭제 요청 (iOS 휴지통으로 이동)
    /// 비동기 작업 - 삭제 완료 후 뷰어에 알림
    func viewerDidRequestPermanentDelete(assetID: String) {
        // TrashStore에서 완전삭제 (iOS 시스템 팝업 표시)
        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: [assetID])
                print("[GridViewController] Permanently deleted: \(assetID.prefix(8))...")

                // 삭제 완료 후 뷰어에 알림 (메인 스레드에서)
                // Push 방식이므로 navigationController에서 확인
                await MainActor.run {
                    if let viewerVC = self.navigationController?.topViewController as? ViewerViewController {
                        viewerVC.handleDeleteComplete()
                    }
                }
            } catch {
                print("[GridViewController] Failed to permanently delete: \(error)")
            }
        }
    }

    /// 뷰어가 닫힐 때 호출
    /// iOS 18+ Zoom Transition 안정화: 전환 중 reloadData/scrollToItem 금지
    /// 실제 처리는 전환 완료 후 applyPendingViewerReturn()에서 수행
    func viewerWillClose(currentAssetID: String?) {
        // 스크롤 위치만 저장 (전환 완료 후 처리)
        pendingScrollAssetID = currentAssetID
        // 사용자 스크롤 플래그 초기화
        didUserScrollAfterReturn = false
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
        guard let indexPath = dataSourceDriver.indexPath(for: assetID) else { return }

        // 현재 보이는 셀인지 확인
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.contains(indexPath) {
            // 화면에 없으면 스크롤 (중앙에 위치하도록)
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
    }
}

// Select Mode 코드 → GridSelectMode.swift로 이동됨

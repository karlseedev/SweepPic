// BaseGridViewController.swift
// 그리드 뷰컨트롤러 공통 베이스 클래스
//
// Phase 2: BaseGridViewController 리팩토링
// - GridViewController, AlbumGridViewController, TrashAlbumViewController 공통 기능 추출
// - 데이터 소스 추상화 (GridDataSource 프로토콜)
// - iOS 버전별 UI 분기 (조건부 생성)
// - 템플릿 메서드 패턴으로 서브클래스 확장 지점 제공
// - PRD7: 스와이프 삭제/복구 공통화

import UIKit
import Photos
import AppCore

// MARK: - Swipe Delete State (PRD7)

/// 스와이프 삭제 상태 관리
struct SwipeDeleteState {
    /// 스와이프 제스처
    var swipeGesture: UIPanGestureRecognizer?
    /// 투 핑거 탭 제스처
    var twoFingerTapGesture: UITapGestureRecognizer?
    /// 현재 대상 셀 (약한 참조)
    weak var targetCell: PhotoCell?
    /// 현재 대상 IndexPath
    var targetIndexPath: IndexPath?
    /// 대상의 현재 휴지통 상태
    var targetIsTrashed: Bool = false
    /// 각도 판정 통과 여부 (10pt 이동 후 결정)
    var angleCheckPassed: Bool = false

    // MARK: - PRD7 상수

    /// 스와이프 각도 임계값 (수평선 ±15°)
    static let angleThreshold: CGFloat = 15.0 * .pi / 180.0
    /// 최소 이동 거리 (각도 판정 전)
    static let minimumTranslation: CGFloat = 10.0
    /// 확정 비율 (셀 너비의 50%)
    static let confirmRatio: CGFloat = 0.5
    /// 확정 속도 (800pt/s)
    static let confirmVelocity: CGFloat = 800.0

    /// 상태 초기화
    mutating func reset() {
        targetCell = nil
        targetIndexPath = nil
        targetIsTrashed = false
        angleCheckPassed = false
    }
}

/// 그리드 뷰컨트롤러 공통 베이스 클래스
/// GridViewController, AlbumGridViewController, TrashAlbumViewController가 상속
class BaseGridViewController: UIViewController {

    // MARK: - Constants

    /// 셀 간격 (FR-001: 2pt)
    static let cellSpacing: CGFloat = 2

    /// 핀치 줌 확대 임계값
    static let pinchZoomInThreshold: CGFloat = 1.15

    /// 핀치 줌 축소 임계값
    static let pinchZoomOutThreshold: CGFloat = 0.85

    /// 핀치 줌 쿨다운 (중복 트리거 방지)
    static let pinchCooldown: TimeInterval = 0.2

    // MARK: - UI Components

    /// 컬렉션 뷰
    lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        cv.backgroundColor = .black
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.delegate = self
        cv.dataSource = self
        cv.prefetchDataSource = self
        cv.alwaysBounceVertical = true
        // Edge-to-edge 설정 (플로팅 UI 사용 시 수동으로 contentInset 설정)
        cv.contentInsetAdjustmentBehavior = .never
        return cv
    }()

    /// 빈 상태 뷰
    lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        let config = emptyStateConfig
        view.configure(
            icon: config.icon,
            title: config.title,
            subtitle: config.subtitle
        )
        view.useDarkTheme()  // 검정 배경에서 사용
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Properties

    /// 이미지 파이프라인
    let imagePipeline: ImagePipelineProtocol

    /// 휴지통 스토어
    let trashStore: TrashStoreProtocol

    /// 현재 열 수
    var currentGridColumnCount: GridColumnCount = .three

    /// 현재 셀 크기 (캐시)
    var currentCellSize: CGSize = .zero

    /// 핀치 줌 마지막 실행 시간 (쿨다운용)
    var lastPinchZoomTime: Date?

    /// 핀치 줌 앵커 에셋 ID (레거시 - pinchState로 대체)
    var pinchAnchorAssetID: String?

    /// 핀치줌 상태 (transform 기반 스케일링)
    var pinchState = PinchZoomState()

    /// 뷰어 복귀 후 스크롤할 에셋 ID
    var pendingScrollAssetID: String?

    // MARK: - Swipe Delete Properties (PRD7)

    /// 스와이프 삭제 상태
    var swipeDeleteState = SwipeDeleteState()

    /// 스와이프 삭제 지원 여부 (서브클래스에서 오버라이드)
    /// Grid, Album: true / Trash: false
    var supportsSwipeDelete: Bool { false }

    // MARK: - Select Mode Properties

    /// Select 모드 여부
    var isSelectMode: Bool = false

    /// 선택 관리자
    let selectionManager = SelectionManager()

    /// iOS 26+ 툴바의 선택 개수 라벨
    var selectionCountBarItem: UIBarButtonItem?

    /// 드래그 선택용 팬 제스처
    var dragSelectGesture: UIPanGestureRecognizer?

    /// 드래그 선택 시작 인덱스
    var dragSelectStartIndex: Int?

    /// 드래그 선택 현재 인덱스
    var dragSelectCurrentIndex: Int?

    /// 드래그 선택 영향받은 인덱스들
    var dragSelectAffectedIndices: Set<Int> = []

    /// 드래그 선택 모드: 선택(true) 또는 해제(false)
    var dragSelectIsSelecting: Bool = true

    /// 자동 스크롤 타이머
    var autoScrollTimer: Timer?

    /// 자동 스크롤 속도 (pt/s)
    static let autoScrollSpeed: CGFloat = 300

    /// 자동 스크롤 영역 높이
    static let autoScrollEdgeHeight: CGFloat = 60

    // MARK: - Rotation Support

    /// 회전 시 스크롤 위치 보존용 앵커 indexPath (레거시)
    /// - 화면 중앙에 있던 셀의 indexPath를 저장
    private var scrollAnchorIndexPath: IndexPath?

    /// 회전 시 스크롤 위치 보존용 앵커 assetID (paddingCellCount 변경에 안전)
    private var scrollAnchorAssetID: String?

    // MARK: - Abstract Properties (서브클래스 필수 구현)

    /// 데이터 소스 (서브클래스에서 반드시 오버라이드)
    var gridDataSource: GridDataSource {
        fatalError("Subclass must override gridDataSource")
    }

    /// 빈 상태 설정 (아이콘, 타이틀, 서브타이틀)
    var emptyStateConfig: (icon: String, title: String, subtitle: String?) {
        fatalError("Subclass must override emptyStateConfig")
    }

    /// 네비게이션 타이틀 (서브클래스에서 오버라이드)
    var navigationTitle: String {
        fatalError("Subclass must override navigationTitle")
    }

    /// 플로팅 UI 사용 여부 (iOS 26+에서는 시스템 UI 사용)
    var useFloatingUI: Bool {
        if #available(iOS 26.0, *) { return false }
        return true
    }

    // MARK: - Computed Properties

    /// 상단 패딩 셀 개수 (맨 아래 행이 꽉 차도록)
    var paddingCellCount: Int {
        let totalCount = gridDataSource.assetCount
        guard totalCount > 0 else { return 0 }
        let columns = currentGridColumnCount.rawValue
        let remainder = totalCount % columns
        return remainder == 0 ? 0 : (columns - remainder)
    }

    // MARK: - Initialization

    init(imagePipeline: ImagePipelineProtocol, trashStore: TrashStoreProtocol) {
        self.imagePipeline = imagePipeline
        self.trashStore = trashStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupGestures()
        setupNavigationUI()
        setupSelectionManagerDelegate()
        additionalSetup()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        configureFloatingOverlay()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCellSize()
        updateContentInset()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateContentInset()
    }

    // MARK: - Rotation

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        // 1. 앵커 저장 (화면 중앙 셀의 assetID)
        saveScrollAnchorAssetID()
        let anchorAssetID = scrollAnchorAssetID

        // 2. 새 열 수 결정
        // - 세로→가로: 1→3, 3→5, 5→5
        // - 가로→세로: 1→1, 3→3, 5→3
        let isLandscape = size.width > size.height
        let newColumnCount = isLandscape
            ? currentGridColumnCount.landscapeColumnCount
            : currentGridColumnCount.portraitColumnCount

        // 3. 유사 사진 테두리 숨김
        handleSimilarPhotoScrollStart()

        // 4. 회전과 동시에 fade in 시작
        fadeInVisibleCells(targetColumns: newColumnCount, anchorAssetID: anchorAssetID)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }

            // 열 수 업데이트
            self.currentGridColumnCount = newColumnCount

            // 레이아웃 즉시 변경 (셀 이동 애니메이션 없음)
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.updateCellSize()
            self.updateContentInset()

        }, completion: { [weak self] _ in
            guard let self = self else { return }

            // 앵커 위치로 스크롤
            self.restoreScrollAnchorAssetID()

            // 고해상도 썸네일 재요청
            self.didPerformZoom(to: newColumnCount)

            // 유사 사진 테두리 재표시
            self.handleSimilarPhotoScrollEnd()
        })
    }

    /// 화면 중앙 셀의 assetID 저장 (paddingCellCount 변경에 안전)
    private func saveScrollAnchorAssetID() {
        let visibleRect = CGRect(
            origin: collectionView.contentOffset,
            size: collectionView.bounds.size
        )
        let centerPoint = CGPoint(
            x: visibleRect.midX,
            y: visibleRect.midY
        )

        // 1차: 정확히 centerPoint에 있는 셀
        if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
            scrollAnchorAssetID = assetIDForCollectionIndexPath(indexPath)
            return
        }

        // 2차: visible cells 중 중앙에 가장 가까운 셀
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        var closestIndexPath: IndexPath?
        var closestDistance: CGFloat = .greatestFiniteMagnitude

        for indexPath in visibleIndexPaths {
            guard let cell = collectionView.cellForItem(at: indexPath) else { continue }
            let distance = hypot(cell.center.x - centerPoint.x, cell.center.y - centerPoint.y)
            if distance < closestDistance {
                closestDistance = distance
                closestIndexPath = indexPath
            }
        }

        scrollAnchorAssetID = closestIndexPath.flatMap { assetIDForCollectionIndexPath($0) }
    }

    /// assetID 기준으로 스크롤 복원
    private func restoreScrollAnchorAssetID() {
        guard let assetID = scrollAnchorAssetID else { return }
        scrollAnchorAssetID = nil

        // 새 padding 기준으로 indexPath 계산
        guard let indexPath = collectionIndexPath(for: assetID) else { return }
        guard indexPath.item < collectionView.numberOfItems(inSection: 0) else { return }

        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
    }

    // MARK: - Legacy Rotation Support (하위 호환)

    /// 화면 중앙에 있는 셀의 indexPath 저장 (레거시)
    /// - Note: 셀 간격(2pt)에 centerPoint가 걸리면 nil 반환 가능 → fallback 처리
    private func saveScrollAnchorIndexPath() {
        let visibleRect = CGRect(
            origin: collectionView.contentOffset,
            size: collectionView.bounds.size
        )
        let centerPoint = CGPoint(
            x: visibleRect.midX,
            y: visibleRect.midY
        )

        // 1차 시도: 정확히 centerPoint에 있는 셀
        if let indexPath = collectionView.indexPathForItem(at: centerPoint) {
            scrollAnchorIndexPath = indexPath
            return
        }

        // 2차 시도 (fallback): visible cells 중 중앙에 가장 가까운 셀
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else { return }

        var closestIndexPath: IndexPath?
        var closestDistance: CGFloat = .greatestFiniteMagnitude

        for indexPath in visibleIndexPaths {
            guard let cell = collectionView.cellForItem(at: indexPath) else { continue }
            let cellCenter = cell.center
            let distance = hypot(cellCenter.x - centerPoint.x, cellCenter.y - centerPoint.y)
            if distance < closestDistance {
                closestDistance = distance
                closestIndexPath = indexPath
            }
        }

        scrollAnchorIndexPath = closestIndexPath
    }

    /// 저장된 indexPath 기준으로 스크롤 복원 (레거시)
    private func restoreScrollAnchorIndexPath() {
        guard let indexPath = scrollAnchorIndexPath else { return }
        scrollAnchorIndexPath = nil

        // 유효성 검사
        guard indexPath.item < collectionView.numberOfItems(inSection: 0) else { return }

        // 중앙에 위치하도록 스크롤
        collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        view.backgroundColor = .black
        view.addSubview(collectionView)
        view.addSubview(emptyStateView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            emptyStateView.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            emptyStateView.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
    }

    /// 제스처 설정
    private func setupGestures() {
        // 핀치 줌 제스처
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        // PRD7: 스와이프 삭제 제스처 (Grid, Album만 지원)
        if supportsSwipeDelete {
            setupSwipeDeleteGestures()
        }

        // 드래그 선택 제스처 (Select Mode 지원 시)
        setupDragSelectGesture()

        // 서브클래스 추가 제스처
        setupAdditionalGestures()
    }

    // MARK: - iOS 버전별 UI 설정

    /// 네비게이션 UI 설정 (viewDidLoad에서 호출)
    func setupNavigationUI() {
        if #available(iOS 26.0, *) {
            setupSystemNavigationBar()
        } else {
            setupFloatingOverlay()
        }
    }

    /// iOS 26+: 시스템 네비게이션 바 설정 (서브클래스에서 오버라이드 가능)
    @available(iOS 26.0, *)
    func setupSystemNavigationBar() {
        navigationItem.title = navigationTitle
        // 서브클래스에서 추가 버튼 설정
    }

    /// iOS 18: FloatingOverlay 설정 (서브클래스에서 오버라이드 가능)
    func setupFloatingOverlay() {
        // 기본 구현 없음 - 서브클래스에서 필요시 구현
        // FloatingOverlay는 TabBarController에서 관리하므로 여기서는 설정만
    }

    // MARK: - Layout

    /// CompositionalLayout 생성 (동적 열 수 참조)
    /// - currentGridColumnCount를 section provider에서 동적으로 참조
    /// - invalidateLayout() 호출 시 새 열 수로 레이아웃 재계산
    /// - Returns: UICollectionViewLayout
    func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { [weak self] _, environment in
            // self가 nil이면 기본 3열 사용
            let columns = self?.currentGridColumnCount.rawValue ?? 3
            let columnCount = CGFloat(columns)
            let spacing: CGFloat = 2  // Self.cellSpacing 대신 상수 사용 (클로저 내)
            let totalSpacing = spacing * (columnCount - 1)
            let containerWidth = environment.container.effectiveContentSize.width
            let availableWidth = containerWidth - totalSpacing
            let cellWidth = floor(availableWidth / columnCount)

            // 아이템 크기
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellWidth),
                heightDimension: .absolute(cellWidth)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            // 그룹
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellWidth)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: columns
            )
            group.interItemSpacing = .fixed(spacing)

            // 섹션
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsetsReference = .none

            return section
        }
        return layout
    }

    /// CompositionalLayout 생성 (고정 열 수 - 레거시 호환)
    /// - Parameters:
    ///   - columns: 열 수
    ///   - explicitWidth: 명시적 너비 (회전 후 강제 지정 시 사용, nil이면 environment에서 자동 계산)
    /// - Returns: UICollectionViewLayout
    func createLayout(columns: GridColumnCount, explicitWidth: CGFloat? = nil) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let spacing = Self.cellSpacing
            let columnCount = CGFloat(columns.rawValue)
            let totalSpacing = spacing * (columnCount - 1)

            // 셀 크기 계산 (정사각형)
            // 회전 후에는 explicitWidth 사용 (environment 값이 부정확할 수 있음)
            let containerWidth = explicitWidth ?? environment.container.effectiveContentSize.width
            let availableWidth = containerWidth - totalSpacing
            let cellWidth = floor(availableWidth / columnCount)

            // 아이템 크기
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellWidth),
                heightDimension: .absolute(cellWidth)  // 정사각형 비율
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

    /// 셀 크기 업데이트
    func updateCellSize() {
        let spacing = Self.cellSpacing
        let columnCount = CGFloat(currentGridColumnCount.rawValue)
        let totalSpacing = spacing * (columnCount - 1)
        let availableWidth = view.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columnCount)

        currentCellSize = CGSize(width: cellWidth, height: cellWidth)
    }

    /// contentInset 업데이트 (플로팅 UI 높이 반영)
    /// 서브클래스에서 오버라이드 가능
    func updateContentInset() {
        // iOS 26+에서는 시스템 자동 조정 사용
        if #available(iOS 26.0, *) {
            return
        }

        guard useFloatingUI else { return }

        // TabBarController에서 오버레이 높이 가져오기
        guard let tabBarController = tabBarController as? TabBarController,
              let heights = tabBarController.getOverlayHeights() else {
            return
        }

        let inset = UIEdgeInsets(
            top: heights.top,
            left: 0,
            bottom: heights.bottom,
            right: 0
        )

        collectionView.contentInset = inset
        collectionView.scrollIndicatorInsets = inset
    }

    /// 현재 썸네일 크기 반환
    /// 서브클래스에서 오버라이드 가능 (예: 스크롤 중 품질 저하)
    func thumbnailSize() -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(
            width: currentCellSize.width * scale,
            height: currentCellSize.height * scale
        )
    }

    // MARK: - Pinch Zoom

    /// collectionView indexPath → assetID 변환 (padding 보정)
    func assetIDForCollectionIndexPath(_ indexPath: IndexPath) -> String? {
        let assetIndex = indexPath.item - paddingCellCount
        guard assetIndex >= 0 else { return nil }
        return gridDataSource.assetID(at: assetIndex)
    }

    /// assetID → collectionView indexPath 변환 (padding 보정)
    func collectionIndexPath(for assetID: String) -> IndexPath? {
        guard let assetIndex = gridDataSource.assetIndex(for: assetID) else { return nil }
        return IndexPath(item: assetIndex + paddingCellCount, section: 0)
    }

    /// 핀치 줌 제스처 처리 (transform 기반 스케일링)
    /// - 전체 화면이 transform으로 확대/축소 (스크린샷처럼)
    /// - 기준점(1/3/5열) 통과 시 → 해당 열 기준 이미지로 fade in
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            handlePinchBegan(gesture)

        case .changed:
            handlePinchChanged(gesture)

        case .ended, .cancelled:
            handlePinchEnded(gesture)

        default:
            break
        }
    }

    /// 핀치 시작 처리
    private func handlePinchBegan(_ gesture: UIPinchGestureRecognizer) {
        // 1. 상태 초기화
        pinchState = PinchZoomState()
        pinchState.isActive = true
        pinchState.initialScale = gesture.scale  // 보통 1.0
        pinchState.baseColumnCount = currentGridColumnCount
        pinchState.previousVirtualColumns = CGFloat(currentGridColumnCount.rawValue)

        // 2. 원본 layer 상태 저장 (복원용)
        pinchState.originalLayerAnchorPoint = collectionView.layer.anchorPoint
        pinchState.originalLayerPosition = collectionView.layer.position

        // 3. 앵커 결정 (핀치 중심점의 셀)
        let location = gesture.location(in: collectionView)
        pinchState.anchorPoint = CGPoint(
            x: location.x - collectionView.contentOffset.x,
            y: location.y - collectionView.contentOffset.y
        )

        if let indexPath = collectionView.indexPathForItem(at: location),
           indexPath.item >= paddingCellCount {
            pinchState.anchorAssetID = assetIDForCollectionIndexPath(indexPath)
        } else {
            // 빈 공간 → 화면 중앙 셀을 앵커로
            let centerPoint = CGPoint(
                x: collectionView.contentOffset.x + collectionView.bounds.width / 2,
                y: collectionView.contentOffset.y + collectionView.bounds.height / 2
            )
            if let centerIndexPath = collectionView.indexPathForItem(at: centerPoint) {
                pinchState.anchorAssetID = assetIDForCollectionIndexPath(centerIndexPath)
            }
            pinchState.anchorPoint = CGPoint(
                x: collectionView.bounds.width / 2,
                y: collectionView.bounds.height / 2
            )
        }

        // 4. anchorPoint 설정 (position 보정 포함)
        let newAnchor = CGPoint(
            x: pinchState.anchorPoint.x / collectionView.bounds.width,
            y: pinchState.anchorPoint.y / collectionView.bounds.height
        )
        let oldAnchor = collectionView.layer.anchorPoint
        collectionView.layer.anchorPoint = newAnchor
        // position 보정: anchorPoint 변경으로 인한 이동 상쇄
        collectionView.layer.position.x += (newAnchor.x - oldAnchor.x) * collectionView.bounds.width
        collectionView.layer.position.y += (newAnchor.y - oldAnchor.y) * collectionView.bounds.height

        // 5. 스크롤/제스처 비활성화
        collectionView.isScrollEnabled = false

        // 6. 유사 사진 테두리 숨김 (스크롤과 동일한 처리)
        handleSimilarPhotoScrollStart()

        print("[BaseGridViewController] Pinch began at \(pinchState.anchorPoint), anchor=\(pinchState.anchorAssetID?.prefix(8) ?? "nil")")
    }

    /// 핀치 진행 중 처리
    private func handlePinchChanged(_ gesture: UIPinchGestureRecognizer) {
        guard pinchState.isActive else { return }

        let scale = gesture.scale

        // 1. transform 적용 (전체 화면 스케일링)
        // anchorPoint는 .began에서 이미 설정됨 (변경하지 않음)
        collectionView.transform = CGAffineTransform(scaleX: scale, y: scale)

        // 2. 가상 열 수 계산
        let baseColumns = CGFloat(pinchState.baseColumnCount.rawValue)
        let currentVirtualColumns = baseColumns / scale

        // 3. 기준점 통과 감지 → fade in 트리거 (다중 기준점 지원)
        let crossedThresholds = detectThresholdCrossings(
            previousColumns: pinchState.previousVirtualColumns,
            currentColumns: currentVirtualColumns
        )

        // 통과한 모든 기준점에 대해 순차적으로 fade in
        // (빠른 핀치로 5→1 한번에 넘으면 5→3→1 순서로 fade in)
        for crossedThreshold in crossedThresholds {
            pinchState.currentTargetColumns = crossedThreshold
            fadeInVisibleCells(
                targetColumns: crossedThreshold,
                anchorAssetID: pinchState.anchorAssetID
            )
            print("[BaseGridViewController] Threshold crossed: \(crossedThreshold.rawValue) columns")
        }

        // 4. 이전 열 수 업데이트
        pinchState.previousVirtualColumns = currentVirtualColumns
    }

    /// 핀치 종료 처리
    private func handlePinchEnded(_ gesture: UIPinchGestureRecognizer) {
        guard pinchState.isActive else { return }

        // 1. 최종 열 수 결정
        let scale = gesture.scale
        let baseColumns = CGFloat(pinchState.baseColumnCount.rawValue)
        let finalVirtualColumns = baseColumns / scale

        // 가장 가까운 기준점으로 스냅
        let finalColumns = snapToNearestColumnCount(finalVirtualColumns)

        // 2. 복원할 값 캡처 (completion에서 사용)
        let originalAnchorPoint = pinchState.originalLayerAnchorPoint
        let originalPosition = pinchState.originalLayerPosition
        let anchorAssetID = pinchState.anchorAssetID

        print("[BaseGridViewController] Pinch ended: \(pinchState.baseColumnCount.rawValue) → \(finalColumns.rawValue) columns")

        // 3. transform 제거 + 레이아웃 적용
        UIView.animate(withDuration: 0.2) { [weak self] in
            self?.collectionView.transform = .identity
        } completion: { [weak self] _ in
            guard let self = self else { return }

            // anchorPoint/position 복원 (점프 방지)
            self.collectionView.layer.anchorPoint = originalAnchorPoint
            self.collectionView.layer.position = originalPosition

            // 레이아웃 변경
            self.currentGridColumnCount = finalColumns
            self.collectionView.collectionViewLayout.invalidateLayout()
            self.updateCellSize()

            // 앵커 위치로 스크롤
            if let anchorID = anchorAssetID,
               let indexPath = self.collectionIndexPath(for: anchorID) {
                self.collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            }

            // 고해상도 썸네일 재요청
            self.didPerformZoom(to: finalColumns)

            // 상태 초기화 (completion 안에서!)
            self.pinchState = PinchZoomState()
            self.collectionView.isScrollEnabled = true
            self.updateSwipeDeleteGestureEnabled()

            // 유사 사진 테두리 재표시
            self.handleSimilarPhotoScrollEnd()
        }
    }

    /// 줌 수행
    /// - Parameter columns: 새 열 수
    func performZoom(to columns: GridColumnCount) {
        // 쿨다운 시간 기록
        lastPinchZoomTime = Date()

        // 1. 앵커 assetID 저장 (현재 padding 기준, column 변경 전)
        let anchorAssetID: String? = {
            if let id = pinchAnchorAssetID { return id }
            // 앵커가 없으면 화면 중앙 셀 사용
            let centerPoint = CGPoint(
                x: collectionView.bounds.midX,
                y: collectionView.bounds.midY + collectionView.contentOffset.y
            )
            if let centerIndexPath = collectionView.indexPathForItem(at: centerPoint) {
                return assetIDForCollectionIndexPath(centerIndexPath)
            }
            return nil
        }()

        // 2. 열 수 업데이트 (paddingCellCount도 변경됨)
        currentGridColumnCount = columns
        updateCellSize()

        // 3. 새 padding 기준으로 anchorIndexPath 계산
        let anchorIndexPath = anchorAssetID.flatMap { collectionIndexPath(for: $0) }

        // 레이아웃 애니메이션
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self = self else { return }

            // 새 레이아웃 적용
            self.collectionView.setCollectionViewLayout(
                self.createLayout(columns: columns),
                animated: false
            )

            // 앵커 위치로 스크롤 (drift 0px 목표)
            if let indexPath = anchorIndexPath {
                self.collectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredVertically,
                    animated: false
                )
            }
        } completion: { [weak self] _ in
            // 줌 애니메이션 완료 후 추가 처리 (서브클래스 확장 지점)
            self?.didPerformZoom(to: columns)
        }

        print("[BaseGridViewController] Zoom to \(columns.rawValue) columns")
    }

    /// 줌 완료 후 호출 (서브클래스 확장 지점)
    /// GridViewController에서 refreshVisibleCellsAfterZoom() 호출에 사용
    func didPerformZoom(to columns: GridColumnCount) {
        // 기본 구현 없음 - 서브클래스에서 오버라이드
    }

    // MARK: - Empty State

    /// 빈 상태 업데이트
    func updateEmptyState() {
        let isEmpty = gridDataSource.assetCount == 0
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }

    // MARK: - Template Methods (서브클래스 확장 지점)

    /// 추가 설정 (viewDidLoad에서 호출)
    func additionalSetup() {}

    /// 추가 제스처 설정 (setupGestures에서 호출)
    func setupAdditionalGestures() {}

    /// FloatingOverlay 추가 설정 (viewWillAppear에서 호출)
    func configureFloatingOverlay() {}

    /// 셀 추가 설정 (cellForItemAt에서 호출)
    func configureCell(_ cell: PhotoCell, at indexPath: IndexPath, asset: PHAsset) {}

    /// 뷰어 모드 결정 (서브클래스에서 오버라이드)
    func viewerMode(for asset: PHAsset) -> ViewerMode {
        .normal
    }

    /// 삭제 후 추가 처리
    func handleDeleteComplete(assetID: String) {}

    /// 유사 사진 스크롤/핀치 시작 시 호출 (서브클래스에서 오버라이드)
    /// 테두리 숨김 + 분석 취소
    @objc dynamic func handleSimilarPhotoScrollStart() {}

    /// 유사 사진 스크롤/핀치 종료 시 호출 (서브클래스에서 오버라이드)
    /// 분석 재시작 → 테두리 재생성
    @objc dynamic func handleSimilarPhotoScrollEnd() {}

    // Note: 플로팅 UI 선택 모드 메서드는 BaseSelectMode.swift로 이동됨
    // - enterSelectModeFloatingUI()
    // - exitSelectModeFloatingUI()
    // - updateSelectionCountFloatingUI(_:)
}

// MARK: - UICollectionViewDataSource

extension BaseGridViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView,
                        numberOfItemsInSection section: Int) -> Int {
        return gridDataSource.assetCount + paddingCellCount
    }

    func collectionView(_ collectionView: UICollectionView,
                        cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCell.reuseIdentifier,
            for: indexPath
        ) as! PhotoCell

        // 빈 셀 처리 (상단 패딩)
        if indexPath.item < paddingCellCount {
            cell.configureAsEmpty()
            return cell
        }

        // 실제 에셋 인덱스 계산
        let assetIndex = indexPath.item - paddingCellCount
        guard let asset = gridDataSource.asset(at: assetIndex) else {
            cell.configureAsEmpty()
            return cell
        }

        // 기본 설정 (이미지 로딩)
        let assetID = asset.localIdentifier
        let isTrashed = trashStore.isTrashed(assetID)

        cell.configure(
            asset: asset,
            isTrashed: isTrashed,
            targetSize: thumbnailSize()
        )

        // Select 모드 여부에 따라 선택 UI 반영
        cell.isSelectedForDeletion = isSelectMode && selectionManager.isSelected(assetID)

        // 서브클래스 추가 설정 (템플릿 메서드)
        configureCell(cell, at: indexPath, asset: asset)

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension BaseGridViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView,
                        didSelectItemAt indexPath: IndexPath) {
        // 빈 셀 무시
        guard indexPath.item >= paddingCellCount else { return }

        // Select 모드일 때는 선택 토글 처리
        if isSelectMode {
            toggleSelectionForSelectMode(at: indexPath)
            return
        }

        let assetIndex = indexPath.item - paddingCellCount
        guard let asset = gridDataSource.asset(at: assetIndex) else { return }

        // 뷰어 열기 (서브클래스에서 구현)
        openViewer(for: asset, at: assetIndex)
    }
}

// MARK: - Cell Selection (Overridable)

extension BaseGridViewController {

    /// 뷰어 열기 (서브클래스에서 반드시 오버라이드 필요)
    /// extension에서 분리하여 override 가능하게 함
    @objc func openViewer(for asset: PHAsset, at assetIndex: Int) {
        fatalError("Subclass must override openViewer(for:at:)")
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension BaseGridViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView,
                        prefetchItemsAt indexPaths: [IndexPath]) {
        let padding = paddingCellCount

        // padding 셀 제외하고 실제 에셋만 prefetch
        let assetIDs = indexPaths.compactMap { indexPath -> String? in
            guard indexPath.item >= padding else { return nil }
            let assetIndex = indexPath.item - padding
            return gridDataSource.assetID(at: assetIndex)
        }

        guard !assetIDs.isEmpty else { return }
        imagePipeline.preheat(assetIDs: assetIDs, targetSize: thumbnailSize())
    }

    func collectionView(_ collectionView: UICollectionView,
                        cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let padding = paddingCellCount

        let assetIDs = indexPaths.compactMap { indexPath -> String? in
            guard indexPath.item >= padding else { return nil }
            let assetIndex = indexPath.item - padding
            return gridDataSource.assetID(at: assetIndex)
        }

        guard !assetIDs.isEmpty else { return }
        imagePipeline.stopPreheating(assetIDs: assetIDs)
    }
}

// MARK: - PRD7: Swipe Delete/Restore

extension BaseGridViewController {

    // MARK: - Setup

    /// 스와이프 삭제 제스처 설정
    func setupSwipeDeleteGestures() {
        // 스와이프 삭제 제스처
        let swipe = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeDelete(_:)))
        swipe.delegate = self
        collectionView.addGestureRecognizer(swipe)
        swipeDeleteState.swipeGesture = swipe

        // 투 핑거 탭 제스처
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        tap.numberOfTouchesRequired = 2
        tap.delegate = self
        collectionView.addGestureRecognizer(tap)
        swipeDeleteState.twoFingerTapGesture = tap

        updateSwipeDeleteGestureEnabled()
    }

    /// 스와이프 제스처 활성화 상태 업데이트
    /// 서브클래스에서 오버라이드하여 isSelectMode 등 추가 조건 적용 가능
    @objc func updateSwipeDeleteGestureEnabled() {
        let enabled = !UIAccessibility.isVoiceOverRunning
        swipeDeleteState.swipeGesture?.isEnabled = enabled
        swipeDeleteState.twoFingerTapGesture?.isEnabled = enabled
    }

    /// 진행 중인 스와이프 취소 (백그라운드 진입 등)
    func cancelActiveSwipe() {
        guard let cell = swipeDeleteState.targetCell else { return }
        cell.cancelDimmedAnimation {
            cell.isAnimating = false
        }
        swipeDeleteState.reset()
    }

    // MARK: - Swipe Gesture Handler

    @objc func handleSwipeDelete(_ gesture: UIPanGestureRecognizer) {
        switch gesture.state {
        case .began:
            handleSwipeDeleteBegan(gesture)
        case .changed:
            handleSwipeDeleteChanged(gesture)
        case .ended:
            handleSwipeDeleteEnded(gesture)
        case .cancelled, .failed:
            handleSwipeDeleteCancelled()
        default:
            break
        }
    }

    // MARK: - Swipe Delete State Handlers

    /// 스와이프 시작
    private func handleSwipeDeleteBegan(_ gesture: UIPanGestureRecognizer) {
        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              indexPath.item >= paddingCellCount,
              let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell,
              !cell.isAnimating else {
            gesture.state = .cancelled
            return
        }

        swipeDeleteState.targetCell = cell
        swipeDeleteState.targetIndexPath = indexPath
        swipeDeleteState.targetIsTrashed = cell.isTrashed
        swipeDeleteState.angleCheckPassed = false
        cell.isAnimating = true
        HapticFeedback.prepare()
    }

    /// 스와이프 진행 중
    private func handleSwipeDeleteChanged(_ gesture: UIPanGestureRecognizer) {
        guard let cell = swipeDeleteState.targetCell else { return }

        let translation = gesture.translation(in: collectionView)
        let absX = abs(translation.x)

        // 10pt 이동 전에는 각도 판정 보류
        if absX < SwipeDeleteState.minimumTranslation && !swipeDeleteState.angleCheckPassed {
            return
        }

        // 각도 판정 (1회만)
        if !swipeDeleteState.angleCheckPassed {
            let angle = atan2(abs(translation.y), abs(translation.x))
            if angle > SwipeDeleteState.angleThreshold {
                handleSwipeDeleteCancelled()
                gesture.state = .cancelled
                return
            }
            swipeDeleteState.angleCheckPassed = true
        }

        // progress 계산 (0.0 ~ 1.0)
        let progress = min(1.0, absX / currentCellSize.width)
        let direction: PhotoCell.SwipeDirection = translation.x > 0 ? .right : .left
        cell.setDimmedProgress(progress, direction: direction, isTrashed: swipeDeleteState.targetIsTrashed)
    }

    /// 스와이프 종료
    private func handleSwipeDeleteEnded(_ gesture: UIPanGestureRecognizer) {
        guard let cell = swipeDeleteState.targetCell,
              let indexPath = swipeDeleteState.targetIndexPath else {
            swipeDeleteState.reset()
            return
        }

        let translation = gesture.translation(in: collectionView)
        let velocity = gesture.velocity(in: collectionView)

        let isDistanceConfirmed = abs(translation.x) >= currentCellSize.width * SwipeDeleteState.confirmRatio
        let isVelocityConfirmed = abs(velocity.x) >= SwipeDeleteState.confirmVelocity

        if (isDistanceConfirmed || isVelocityConfirmed) && swipeDeleteState.angleCheckPassed {
            confirmSwipeDelete(cell: cell, indexPath: indexPath)
        } else {
            cancelSwipeDelete(cell: cell)
        }
    }

    /// 스와이프 취소
    private func handleSwipeDeleteCancelled() {
        guard let cell = swipeDeleteState.targetCell else {
            swipeDeleteState.reset()
            return
        }
        cancelSwipeDelete(cell: cell)
    }

    // MARK: - Swipe Delete Actions

    /// 스와이프 삭제/복원 확정
    private func confirmSwipeDelete(cell: PhotoCell, indexPath: IndexPath) {
        let isTrashed = swipeDeleteState.targetIsTrashed
        let toTrashed = !isTrashed

        let actualIndex = indexPath.item - paddingCellCount
        guard let assetID = gridDataSource.assetID(at: actualIndex) else {
            cancelSwipeDelete(cell: cell)
            return
        }

        cell.confirmDimmedAnimation(toTrashed: toTrashed) { [weak self] in
            guard let self = self else { return }

            if toTrashed {
                self.trashStore.moveToTrash(assetID) { [weak self] result in
                    self?.handleSwipeResult(result, cell: cell)
                }
            } else {
                self.trashStore.restore(assetID) { [weak self] result in
                    self?.handleSwipeResult(result, cell: cell)
                }
            }
        }

        swipeDeleteState.reset()
    }

    /// 스와이프 취소 (원래 상태로 복귀)
    private func cancelSwipeDelete(cell: PhotoCell) {
        cell.cancelDimmedAnimation { [weak self] in
            cell.isAnimating = false
            self?.swipeDeleteState.reset()
        }
    }

    /// 스와이프 결과 처리
    private func handleSwipeResult(_ result: Result<Void, TrashStoreError>, cell: PhotoCell) {
        switch result {
        case .success:
            cell.isAnimating = false
            HapticFeedback.light()
        case .failure:
            cell.isAnimating = false
            HapticFeedback.error()
        }
    }

    // MARK: - Two Finger Tap (PRD7 FR-102)

    @objc func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        let location = gesture.location(in: collectionView)
        guard let indexPath = collectionView.indexPathForItem(at: location),
              indexPath.item >= paddingCellCount,
              let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell,
              !cell.isAnimating else {
            return
        }

        let actualIndex = indexPath.item - paddingCellCount
        guard let assetID = gridDataSource.assetID(at: actualIndex) else { return }

        let isTrashed = cell.isTrashed
        let toTrashed = !isTrashed

        cell.isAnimating = true
        HapticFeedback.light()

        cell.confirmDimmedAnimation(toTrashed: toTrashed) { [weak self] in
            guard let self = self else { return }

            if toTrashed {
                self.trashStore.moveToTrash(assetID) { [weak self] result in
                    self?.handleSwipeResult(result, cell: cell)
                }
            } else {
                self.trashStore.restore(assetID) { [weak self] result in
                    self?.handleSwipeResult(result, cell: cell)
                }
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension BaseGridViewController: UIGestureRecognizerDelegate {

    /// 제스처 시작 조건 (스와이프 삭제, 드래그 선택 제스처용)
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        // 드래그 선택 제스처 체크
        if gestureRecognizer == dragSelectGesture {
            guard isSelectMode else { return false }

            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let velocity = panGesture.velocity(in: collectionView)

            // 수평 이동 속도가 수직 이동 속도보다 커야 드래그 선택 모드
            let isHorizontalDrag = abs(velocity.x) > abs(velocity.y)

            if isHorizontalDrag {
                print("[BaseGridViewController] Drag select gesture began (horizontal drag detected)")
            }

            return isHorizontalDrag
        }

        // 스와이프 삭제 제스처 체크
        if gestureRecognizer == swipeDeleteState.swipeGesture {
            // 스크롤 momentum 중이면 무시
            if collectionView.isDecelerating { return false }

            // 터치 위치에 셀이 없으면 무시
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return false }
            let location = pan.location(in: collectionView)
            guard let indexPath = collectionView.indexPathForItem(at: location) else { return false }

            // 패딩 셀이면 무시
            guard indexPath.item >= paddingCellCount else { return false }

            // velocity 기반 힌트 (30° 이내)
            let velocity = pan.velocity(in: collectionView)
            let angle = atan2(abs(velocity.y), abs(velocity.x))
            return angle < (30.0 * .pi / 180.0)
        }
        return true
    }

    /// 제스처 동시 인식 허용
    /// 핀치 줌과 드래그 선택이 다른 제스처와 충돌하지 않도록
    public func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 드래그 선택 제스처는 핀치와 동시 인식 허용
        if gestureRecognizer == dragSelectGesture {
            return otherGestureRecognizer is UIPinchGestureRecognizer
        }
        // 핀치 줌은 항상 허용
        if gestureRecognizer is UIPinchGestureRecognizer {
            return true
        }
        return false
    }
}

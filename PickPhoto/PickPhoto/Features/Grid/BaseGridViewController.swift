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
import OSLog

// MARK: - NavTitleContainerView

/// 네비게이션 바 titleView용 컨테이너
/// intrinsicContentSize를 타이틀 높이만 반환하여 서브타이틀 추가 시 타이틀 위치 고정
/// clipsToBounds = false로 서브타이틀은 아래로 overflow 표시
private class NavTitleContainerView: UIView {
    weak var titleLabel: UILabel?

    override var intrinsicContentSize: CGSize {
        // 타이틀 높이만 반환하여 네비게이션 바 중앙 배치 기준 유지
        let titleSize = titleLabel?.intrinsicContentSize ?? .zero
        return CGSize(width: UIView.noIntrinsicMetric, height: titleSize.height)
    }
}

// MARK: - Swipe Delete State (PRD7)

/// 스와이프 삭제 상태 관리
struct SwipeDeleteState {
    /// 스와이프 제스처
    var swipeGesture: UIPanGestureRecognizer?
    /// 현재 대상 셀 (약한 참조)
    weak var targetCell: PhotoCell?
    /// 현재 대상 IndexPath
    var targetIndexPath: IndexPath?
    /// 대상의 현재 삭제대기함 상태
    var targetIsTrashed: Bool = false
    /// 각도 판정 통과 여부 (10pt 이동 후 결정)
    var angleCheckPassed: Bool = false

    // MARK: - 다중 셀 스와이프 프로퍼티

    /// 다중 모드 진입 여부 (진입 후 복귀 없음)
    var isMultiMode: Bool = false
    /// 앵커 셀의 indexPath.item
    var anchorItem: Int = 0
    /// 앵커 셀 행 (item / columnCount)
    var anchorRow: Int = 0
    /// 앵커 셀 열 (item % columnCount)
    var anchorCol: Int = 0
    /// 현재 사각형 범위의 item 인덱스들
    var selectedItems: Set<Int> = []
    /// true=삭제, false=복원 (앵커 셀 기준)
    var deleteAction: Bool = true
    /// 커튼 효과 적용 중인 셀 (nil이면 없음 — 순수 상하 이동 시)
    var curtainItem: Int?
    /// 다중 모드 진입 시 스와이프 방향 (앵커 셀 복귀 시 커튼 방향 결정용)
    var swipeDirection: PhotoCell.SwipeDirection = .right

    // MARK: - PRD7 상수

    /// 스와이프 각도 임계값 (수평선 ±25°)
    static let angleThreshold: CGFloat = 25.0 * .pi / 180.0
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
        // 다중 모드 초기화
        isMultiMode = false
        anchorItem = 0
        anchorRow = 0
        anchorCol = 0
        selectedItems = []
        deleteAction = true
        curtainItem = nil
        swipeDirection = .right
    }
}

/// 그리드 뷰컨트롤러 공통 베이스 클래스
/// GridViewController, AlbumGridViewController, TrashAlbumViewController가 상속
class BaseGridViewController: UIViewController {

    // MARK: - Constants

    /// 셀 간격 (FR-001: 2pt)
    static let cellSpacing: CGFloat = 2

    // 핀치줌 상수는 BaseGridViewController+PinchZoom.swift로 이동됨

    // MARK: - UI Components

    /// 컬렉션 뷰
    lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout(columns: .three))
        cv.backgroundColor = .black
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.delegate = self
        cv.dataSource = self
        cv.prefetchDataSource = self
        cv.alwaysBounceVertical = true
        cv.accessibilityIdentifier = "photo_grid"
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

    /// 삭제대기함 스토어
    let trashStore: TrashStoreProtocol

    /// 현재 열 수
    var currentGridColumnCount: GridColumnCount = .three

    /// 현재 셀 크기 (캐시)
    var currentCellSize: CGSize = .zero

    // MARK: - Pinch Zoom Properties (BaseGridViewController+PinchZoom.swift에서 사용)

    /// 핀치 줌 마지막 실행 시간 (쿨다운용)
    var lastPinchZoomTime: Date?

    /// 핀치 줌 앵커 에셋 ID
    var pinchAnchorAssetID: String?

    // MARK: - Viewer Properties

    /// 뷰어 복귀 후 스크롤할 에셋 ID
    var pendingScrollAssetID: String?

    // MARK: - Swipe Delete Properties (PRD7)

    /// 스와이프 삭제 상태
    var swipeDeleteState = SwipeDeleteState()

    /// 스와이프 삭제 지원 여부 (서브클래스에서 오버라이드)
    /// Grid, Album: true / Trash: false (→ true)
    var supportsSwipeDelete: Bool { false }

    /// 스와이프 동작이 복구(restore)인지 여부 (삭제대기함에서 true)
    /// true이면 녹색 커튼 + restore() 호출, 코치마크 스킵
    var swipeActionIsRestore: Bool { false }

    // MARK: - Select Mode Properties

    /// Select 모드 여부
    var isSelectMode: Bool = false

    /// 선택 관리자
    let selectionManager = SelectionManager()

    /// iOS 26+ 툴바의 선택 개수 라벨
    var selectionCountBarItem: UIBarButtonItem?

    /// 드래그 선택용 팬 제스처
    var dragSelectGesture: UIPanGestureRecognizer?

    /// 꾹 누르기 선택 모드 진입 제스처
    var longPressSelectGesture: UILongPressGestureRecognizer?

    /// 꾹 누르기로 시작된 드래그 선택 진행 중 여부
    var isLongPressDragActive: Bool = false

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

    /// 자동 스크롤 최소 속도 (pt/s) - 핫스팟 진입 시
    static let autoScrollMinSpeed: CGFloat = 200

    /// 자동 스크롤 최대 속도 (pt/s) - 가장자리 끝에서
    static let autoScrollMaxSpeed: CGFloat = 1500

    /// 자동 스크롤 영역 높이 (핫스팟)
    static let autoScrollEdgeHeight: CGFloat = 100

    /// 현재 자동 스크롤 속도 (가변, 음수=위로, 양수=아래로)
    var currentAutoScrollSpeed: CGFloat = 0

    /// 자동 스크롤 구동 중인 제스처 (드래그 선택 or 스와이프 삭제 or 꾹 누르기)
    weak var autoScrollGesture: UIGestureRecognizer?

    /// 자동 스크롤 틱마다 호출할 핸들러 (범위 업데이트용)
    var autoScrollHandler: ((CGPoint) -> Void)?

    // MARK: - Rotation Support

    /// 회전 시 스크롤 위치 보존용 앵커 indexPath
    /// - 화면 중앙에 있던 셀의 indexPath를 저장
    private var scrollAnchorIndexPath: IndexPath?

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

    /// 네비게이션 타이틀 텍스트 속성 (서브클래스에서 오버라이드하여 폰트/자간 변경 가능)
    /// 기본값: 36pt light, kern -1.0
    var navigationTitleAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 36, weight: .light),
            .kern: -1.0
        ]
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
        // 메뉴 버튼 기본 숨김 (사진보관함만 configureFloatingOverlay에서 다시 표시)
        if let tabBar = tabBarController as? TabBarController {
            tabBar.floatingOverlay?.titleBar.hideMenuButton()
        }
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

        // 회전 전: 화면 중앙 셀의 indexPath 저장
        saveScrollAnchorIndexPath()

        // 회전 후 방향에 따라 열 수 결정 (기본 사진앱 방식)
        // - 세로→가로: 1→3, 3→5, 5→5
        // - 가로→세로: 1→1, 3→3, 5→3
        let isLandscape = size.width > size.height
        let newColumnCount = isLandscape
            ? currentGridColumnCount.landscapeColumnCount
            : currentGridColumnCount.portraitColumnCount

        // 회전 후 크기로 새 레이아웃 미리 생성 (size 파라미터가 회전 후 크기)
        let newLayout = createLayout(columns: newColumnCount, explicitWidth: size.width)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            guard let self = self else { return }

            // 열 수 업데이트
            self.currentGridColumnCount = newColumnCount

            // 회전 애니메이션과 동기화하여 레이아웃 변경
            self.collectionView.setCollectionViewLayout(newLayout, animated: false)

            // 셀 크기 캐시 업데이트
            self.updateCellSize()

            // contentInset 재계산 (FloatingUI 높이 반영)
            self.updateContentInset()

            // 저장된 indexPath로 스크롤 복원
            self.restoreScrollAnchorIndexPath()
        }, completion: nil)
    }

    /// 화면 중앙에 있는 셀의 indexPath 저장
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

    /// 저장된 indexPath 기준으로 스크롤 복원
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
        // 핀치 줌 제스처 (BaseGridViewController+PinchZoom.swift에서 관리)
        setupPinchZoomGesture()

        // PRD7: 스와이프 삭제 제스처 (Grid, Album만 지원)
        if supportsSwipeDelete {
            setupSwipeDeleteGestures()
        }

        // 드래그 선택 제스처 (Select Mode 지원 시)
        setupDragSelectGesture()

        // 꾹 누르기 → 선택 모드 진입 + 드래그 연속 선택
        setupLongPressSelectGesture()

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

    /// iOS 26+ 서브타이틀 라벨 참조 (서브클래스에서 업데이트용)
    private(set) var navSubtitleLabel: UILabel?

    /// iOS 26+: 시스템 네비게이션 바 설정 (서브클래스에서 오버라이드 가능)
    @available(iOS 26.0, *)
    func setupSystemNavigationBar() {
        // 커스텀 titleView: 타이틀 위치 고정 + 서브타이틀 overflow
        let container = NavTitleContainerView()
        container.clipsToBounds = false

        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(string: navigationTitle, attributes: navigationTitleAttributes)
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)
        container.titleLabel = titleLabel

        let subtitleLabel = UILabel()
        subtitleLabel.font = .systemFont(ofSize: 14, weight: .black)
        subtitleLabel.textColor = .label
        subtitleLabel.isHidden = true
        subtitleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitleLabel)
        navSubtitleLabel = subtitleLabel

        NSLayoutConstraint.activate([
            // 타이틀: 컨테이너 기준 배치 (intrinsicContentSize로 중앙 유지)
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            // 서브타이틀: 타이틀 바로 아래 (overflow)
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 0),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
        ])

        navigationItem.titleView = container
        // 서브클래스에서 추가 버튼 설정
    }

    /// iOS 18: FloatingOverlay 설정 (서브클래스에서 오버라이드 가능)
    func setupFloatingOverlay() {
        // 기본 구현 없음 - 서브클래스에서 필요시 구현
        // FloatingOverlay는 TabBarController에서 관리하므로 여기서는 설정만
    }

    // MARK: - Layout

    /// CompositionalLayout 생성
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

    // handlePinchGesture(), performZoom()은 BaseGridViewController+PinchZoom.swift로 이동됨

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

    /// 스와이프 복구 확정 전 호출 (삭제대기함에서 deleteItems 애니메이션 준비용)
    /// - Parameter indexPaths: 복구될 셀의 indexPath 배열
    func prepareSwipeRestoreAnimation(at indexPaths: [IndexPath]) {}

    /// 삭제 후 추가 처리
    func handleDeleteComplete(assetID: String) {}

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

        // 빈 셀 처리 (상단 패딩) — XCUITest에서 탭 대상 제외
        if indexPath.item < paddingCellCount {
            cell.configureAsEmpty()
            cell.isAccessibilityElement = false
            return cell
        }

        // 실제 에셋 인덱스 계산
        let assetIndex = indexPath.item - paddingCellCount
        guard let asset = gridDataSource.asset(at: assetIndex) else {
            cell.configureAsEmpty()
            return cell
        }

        // XCUITest 탐색용 identifier (패딩 셀과 구분)
        cell.accessibilityIdentifier = "photo_cell"

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

        // ★ 다중 스와이프 중이면 딤드 상태 복원 (자동 스크롤로 재사용된 셀)
        if swipeDeleteState.isMultiMode && swipeDeleteState.selectedItems.contains(indexPath.item) {
            // 복구 모드 색상 재적용 (재사용 셀은 prepareForReuse에서 마룬으로 리셋됨)
            if swipeActionIsRestore {
                cell.prepareSwipeOverlay(style: .restore)
            }
            if swipeDeleteState.deleteAction {
                cell.setFullDimmed(isTrashed: isTrashed)
            } else {
                cell.setRestoredPreview()
            }
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension BaseGridViewController: UICollectionViewDelegate {

    /// 셀이 화면에 표시되기 직전 호출
    /// - 회색 셀 플래그 세팅 (카운트는 이미지 도착 또는 prepareForReuse 시 수행)
    /// - GridViewController는 자체 willDisplay에서 동일 로직 포함 (타이밍 로그 추가)
    func collectionView(_ collectionView: UICollectionView,
                        willDisplay cell: UICollectionViewCell,
                        forItemAt indexPath: IndexPath) {
        // 회색 셀 측정: 이미지 nil이면 플래그 + 시각 기록
        // - 카운트는 이미지 도착 또는 재사용 시, 인지 임계값(50ms) 초과 시에만 수행
        if let photoCell = cell as? PhotoCell, photoCell.isShowingGray {
            photoCell.wasShownAsGray = true
            photoCell.grayStartTime = CACurrentMediaTime()
        }
    }

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

        updateSwipeDeleteGestureEnabled()
    }

    /// 스와이프 제스처 활성화 상태 업데이트
    /// 서브클래스에서 오버라이드하여 isSelectMode 등 추가 조건 적용 가능
    @objc func updateSwipeDeleteGestureEnabled() {
        let enabled = !UIAccessibility.isVoiceOverRunning
        swipeDeleteState.swipeGesture?.isEnabled = enabled
    }

    /// 진행 중인 스와이프 취소 (백그라운드 진입 등)
    func cancelActiveSwipe() {
        // ★ 다중 모드 취소 처리
        if swipeDeleteState.isMultiMode {
            cancelMultiSwipeDelete()
            return
        }

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
        // 코치마크가 표시 중이면 dismiss (실제 제스처 수행 = 학습 완료)
        CoachMarkManager.shared.dismissCurrent()

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
        // 복구 모드: 녹색 오버레이 준비
        if swipeActionIsRestore {
            cell.prepareSwipeOverlay(style: .restore)
        }
        cell.isAnimating = true
        HapticFeedback.prepare()
    }

    /// 스와이프 진행 중
    private func handleSwipeDeleteChanged(_ gesture: UIPanGestureRecognizer) {
        // ★ 다중 모드: targetCell 의존 없이 먼저 처리 (앵커 셀이 화면 밖일 수 있음)
        if swipeDeleteState.isMultiMode {
            let location = gesture.location(in: collectionView)
            let locationInView = gesture.location(in: view)
            handleMultiSwipeChanged(at: location)
            handleAutoScroll(at: locationInView)
            return
        }

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

        // ★ 다른 셀 도달 체크 → 다중 모드 진입
        let location = gesture.location(in: collectionView)
        let locationInView = gesture.location(in: view)

        if let currentIP = collectionView.indexPathForItem(at: location),
           currentIP != swipeDeleteState.targetIndexPath,
           currentIP.item >= paddingCellCount {
            enterMultiSwipeMode()
            handleMultiSwipeChanged(at: location)
            handleAutoScroll(at: locationInView)
            return
        }

        // 같은 셀 내: 기존 커튼 딤드 로직 (변경 없음)
        let progress = min(1.0, absX / currentCellSize.width)
        let direction: PhotoCell.SwipeDirection = translation.x > 0 ? .right : .left
        cell.setDimmedProgress(progress, direction: direction, isTrashed: swipeDeleteState.targetIsTrashed)
    }

    /// 스와이프 종료
    private func handleSwipeDeleteEnded(_ gesture: UIPanGestureRecognizer) {
        // ★ 다중 모드: 커튼 셀 progress 기준 확정/취소
        if swipeDeleteState.isMultiMode {
            // 속도 확정 (단일 셀과 동일 기준)
            let velocity = gesture.velocity(in: collectionView)
            if abs(velocity.x) >= SwipeDeleteState.confirmVelocity {
                confirmMultiSwipeDelete()
                return
            }

            // 커튼 셀 없음 (순수 상하 이동) → 모든 셀 대상 상태이므로 확정
            guard let curtainItem = swipeDeleteState.curtainItem else {
                confirmMultiSwipeDelete()
                return
            }

            // 커튼 셀 progress 계산
            let ip = IndexPath(item: curtainItem, section: 0)
            if let attrs = collectionView.layoutAttributesForItem(at: ip) {
                let location = gesture.location(in: collectionView)
                let cellFrame = attrs.frame

                // 커튼 방향 결정: 앵커 셀이면 저장된 방향, 비-앵커면 열 비교
                let direction: PhotoCell.SwipeDirection
                if curtainItem == swipeDeleteState.anchorItem {
                    direction = swipeDeleteState.swipeDirection
                } else {
                    let columnCount = currentGridColumnCount.rawValue
                    let currentCol = curtainItem % columnCount
                    direction = currentCol > swipeDeleteState.anchorCol ? .right : .left
                }

                let progress: CGFloat
                switch direction {
                case .right:
                    // 왼쪽에서 채워짐
                    progress = min(1.0, max(0, (location.x - cellFrame.minX) / cellFrame.width))
                case .left:
                    // 오른쪽에서 채워짐
                    progress = min(1.0, max(0, (cellFrame.maxX - location.x) / cellFrame.width))
                }

                if progress >= SwipeDeleteState.confirmRatio {
                    // 커튼 셀 포함 전체 확정
                    confirmMultiSwipeDelete()
                } else {
                    // ★ 커튼 셀만 취소, 이미 지나간 셀들은 확정
                    // 커튼 셀을 선택에서 제외
                    swipeDeleteState.selectedItems.remove(curtainItem)
                    swipeDeleteState.curtainItem = nil

                    // 커튼 셀 취소 애니메이션 (원래 상태로 복귀)
                    if let cell = collectionView.cellForItem(at: ip) as? PhotoCell {
                        cell.cancelDimmedAnimation {
                            cell.isAnimating = false
                        }
                    }

                    // 나머지 셀들 확정 (이미 지나간 셀들)
                    if swipeDeleteState.selectedItems.isEmpty {
                        // 선택 셀이 없으면 정리만
                        stopAutoScroll()
                        autoScrollGesture = nil
                        autoScrollHandler = nil
                        swipeDeleteState.reset()
                    } else {
                        confirmMultiSwipeDelete()
                    }
                }
            } else {
                // 레이아웃 정보 없음 (화면 밖) → 확정
                confirmMultiSwipeDelete()
            }
            return
        }

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
        // ★ 다중 모드 취소 처리
        if swipeDeleteState.isMultiMode {
            cancelMultiSwipeDelete()
            return
        }

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

        // [Analytics] 이벤트 4-1: 그리드 스와이프 삭제/복구
        let analyticsSource: DeleteSource = self is AlbumGridViewController ? .album : .library

        cell.confirmDimmedAnimation(toTrashed: toTrashed) { [weak self] in
            guard let self = self else { return }

            if self.swipeActionIsRestore {
                // ★ 삭제대기함: 항상 복구, 코치마크 스킵
                self.prepareSwipeRestoreAnimation(at: [indexPath])
                AnalyticsService.shared.countTrashRestore()
                self.trashStore.restore(assetID) { [weak self] result in
                    self?.handleSwipeResult(result, cell: cell)
                }
            } else if toTrashed {
                // 보관함/앨범: 삭제 + 코치마크 가이드
                AnalyticsService.shared.countGridSwipeDelete(source: analyticsSource)
                self.trashStore.moveToTrash(assetID) { [weak self] result in
                    self?.handleSwipeResult(result, cell: cell)
                    // E-1+E-2: 첫 삭제 시 삭제 시스템 안내 시퀀스 트리거
                    if case .success = result {
                        // A-1 활성 중이면 → overlay 즉시 제거 → E-1 가드 통과
                        if CoachMarkManager.shared.isA1Active {
                            CoachMarkManager.shared.isA1Active = false
                            let overlay = CoachMarkManager.shared.currentOverlay
                            CoachMarkManager.shared.currentOverlay = nil  // isShowing = false
                            overlay?.dismiss()  // 시각적 페이드아웃 (백그라운드)
                            Logger.coachMark.debug("스와이프 삭제 성공 → A-1 dismiss → E-1 트리거")
                        }
                        self?.showDeleteSystemGuideIfNeeded(cell: cell)
                    }
                }
            } else {
                // 보관함/앨범: 복구
                AnalyticsService.shared.countGridSwipeRestore(source: analyticsSource)
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

            // velocity 기반 힌트 (35° 이내)
            let velocity = pan.velocity(in: collectionView)
            let angle = atan2(abs(velocity.y), abs(velocity.x))
            return angle < (35.0 * .pi / 180.0)
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

// MARK: - E-1+E-2: Delete System Guide Trigger

extension BaseGridViewController {

    /// 첫 삭제 시 삭제 시스템 안내 시퀀스 표시 (E-1+E-2)
    /// moveToTrash 성공 후 호출
    /// - Parameter cell: 삭제된 셀 (trashIcon 아이콘 위치 획득용, nil이면 아이콘 애니메이션 생략)
    func showDeleteSystemGuideIfNeeded(cell: PhotoCell? = nil) {
        guard !CoachMarkType.firstDeleteGuide.hasBeenShown else { return }
        guard !CoachMarkManager.shared.isShowing else { return }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard let window = view.window else { return }

        // 셀의 trashIcon frame (window 좌표, nil이면 아이콘 애니메이션 생략)
        let iconFrame = cell?.trashIconFrameInWindow()
        CoachMarkOverlayView.showDeleteSystemGuide(in: window, iconFrame: iconFrame)
    }
}

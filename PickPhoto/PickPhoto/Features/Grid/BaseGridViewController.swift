// BaseGridViewController.swift
// 그리드 뷰컨트롤러 공통 베이스 클래스
//
// Phase 2: BaseGridViewController 리팩토링
// - GridViewController, AlbumGridViewController, TrashAlbumViewController 공통 기능 추출
// - 데이터 소스 추상화 (GridDataSource 프로토콜)
// - iOS 버전별 UI 분기 (조건부 생성)
// - 템플릿 메서드 패턴으로 서브클래스 확장 지점 제공

import UIKit
import Photos
import AppCore

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
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout(columns: .three))
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

    /// 핀치 줌 앵커 에셋 ID
    var pinchAnchorAssetID: String?

    /// 뷰어 복귀 후 스크롤할 에셋 ID
    var pendingScrollAssetID: String?

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

    /// CompositionalLayout 생성
    /// - Parameter columns: 열 수
    /// - Returns: UICollectionViewLayout
    func createLayout(columns: GridColumnCount) -> UICollectionViewLayout {
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

    /// 핀치 줌 제스처 처리
    @objc func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            // 앵커 에셋 ID 저장 (padding 보정)
            let location = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location) {
                pinchAnchorAssetID = assetIDForCollectionIndexPath(indexPath)
            }

        case .changed:
            // 쿨다운 체크
            if let lastTime = lastPinchZoomTime,
               Date().timeIntervalSince(lastTime) < Self.pinchCooldown {
                return
            }

            // 임계값 체크
            let scale = gesture.scale
            var newColumnCount: GridColumnCount?

            if scale > Self.pinchZoomInThreshold {
                // 확대 (열 수 감소)
                newColumnCount = currentGridColumnCount.zoomIn
            } else if scale < Self.pinchZoomOutThreshold {
                // 축소 (열 수 증가)
                newColumnCount = currentGridColumnCount.zoomOut
            }

            // 열 수가 변경되면 레이아웃 업데이트
            if let newCount = newColumnCount, newCount != currentGridColumnCount {
                performZoom(to: newCount)
                gesture.scale = 1.0  // 스케일 리셋
            }

        case .ended, .cancelled:
            pinchAnchorAssetID = nil

        default:
            break
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

    // MARK: - 플로팅 UI 선택 모드 (iOS 18, 서브클래스에서 오버라이드 가능)

    /// 플로팅 UI 선택 모드 진입
    /// - Grid/Album: selectModeContainer (Delete 버튼)
    /// - Trash: trashSelectModeContainer (Recover + Delete 버튼)
    func enterSelectModeFloatingUI() {}

    /// 플로팅 UI 선택 모드 종료
    func exitSelectModeFloatingUI() {}

    /// 플로팅 UI 선택 개수 업데이트
    func updateSelectionCountFloatingUI(_ count: Int) {}
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

        let assetIndex = indexPath.item - paddingCellCount
        guard let asset = gridDataSource.asset(at: assetIndex) else { return }

        // 뷰어 열기 (서브클래스에서 구현)
        openViewer(for: asset, at: assetIndex)
    }

    /// 뷰어 열기 (서브클래스에서 반드시 오버라이드 필요)
    func openViewer(for asset: PHAsset, at assetIndex: Int) {
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

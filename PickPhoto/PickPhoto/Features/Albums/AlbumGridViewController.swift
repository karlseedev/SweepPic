// AlbumGridViewController.swift
// 앨범 내 사진 그리드 뷰컨트롤러
//
// T052: 앨범 탭 → 앨범 그리드 뷰 구현
// - GridViewController 패턴 재사용
// - 앨범 필터 적용된 PHFetchResult 사용
// - TabBarController의 FloatingOverlay 공유 (iOS 16~25)
//
// T053: 앨범에서 삭제 구현
// - moveToTrash 연동

import UIKit
import Photos
import AppCore

/// 앨범 내 사진 그리드 뷰컨트롤러
/// 특정 앨범의 사진만 표시하는 그리드
/// TabBarController의 FloatingOverlay를 공유하여 상태만 변경
final class AlbumGridViewController: UIViewController {

    // MARK: - Constants

    /// 셀 간격
    private static let cellSpacing: CGFloat = 2

    /// 열 구성
    enum ColumnCount: Int, CaseIterable {
        case one = 1
        case three = 3
        case five = 5

        var zoomIn: ColumnCount {
            switch self {
            case .one: return .one
            case .three: return .one
            case .five: return .three
            }
        }

        var zoomOut: ColumnCount {
            switch self {
            case .one: return .three
            case .three: return .five
            case .five: return .five
            }
        }
    }

    /// 핀치 줌 임계값
    private static let pinchZoomInThreshold: CGFloat = 1.15
    private static let pinchZoomOutThreshold: CGFloat = 0.85

    /// 핀치 줌 쿨다운
    private static let pinchCooldown: TimeInterval = 0.2

    // MARK: - UI Components

    /// 컬렉션 뷰
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout(columns: .three))
        cv.backgroundColor = .black
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.delegate = self
        cv.dataSource = self
        cv.prefetchDataSource = self
        cv.alwaysBounceVertical = true
        // Edge-to-edge
        cv.contentInsetAdjustmentBehavior = .never
        return cv
    }()

    /// 빈 상태 뷰
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(
            icon: "photo.on.rectangle",
            title: "사진이 없습니다",
            subtitle: "이 앨범에 사진이 없습니다"
        )
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 커스텀 플로팅 UI 사용 여부 (iOS 26+에서는 false)
    private var useFloatingUI: Bool {
        if #available(iOS 26.0, *) {
            return false
        }
        return true
    }

    // MARK: - Properties

    /// 앨범 제목
    /// iOS 18+ zoom transition의 sourceViewProvider에서 외부 접근 필요
    let albumTitle: String

    /// 앨범 내 사진 fetch result
    private let fetchResult: PHFetchResult<PHAsset>

    /// 이미지 파이프라인
    private let imagePipeline: ImagePipelineProtocol

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol

    /// 현재 열 수
    private var currentColumnCount: ColumnCount = .three

    /// 현재 셀 크기
    private var currentCellSize: CGSize = .zero

    /// 핀치 줌 마지막 실행 시간
    private var lastPinchZoomTime: Date?

    /// 핀치 줌 앵커 에셋 ID
    private var pinchAnchorAssetID: String?

    /// 초기 스크롤 완료 여부 (맨 아래로 스크롤)
    private var didInitialScroll: Bool = false

    // MARK: - PRD7: Swipe Delete State

    /// 스와이프 삭제 상태 (GridViewController와 동일한 구조체 사용)
    private var swipeDeleteState = SwipeDeleteState()

    /// PRD7: 이전 휴지통 상태 (changedIDs 계산용)
    private var lastTrashedIDs: Set<String> = []

    // MARK: - Pending Viewer Return (iOS 18+ Zoom Transition 안정화)

    /// 뷰어 닫힘 후 스크롤할 에셋 ID
    private var pendingScrollAssetID: String?

    /// 뷰어 복귀 후 사용자가 스크롤했는지 여부
    /// - true이면 applyPendingViewerReturn()에서 강제 스크롤 skip
    private var didUserScrollAfterReturn: Bool = false

    /// 맨 위 행 빈 셀 개수 (3의 배수가 아닐 시 맨 위 행에 빈 셀)
    /// 최신 사진(맨 아래) 기준 꽉 차게 정렬
    private var paddingCellCount: Int {
        let totalCount = fetchResult.count
        guard totalCount > 0 else { return 0 }
        let columns = currentColumnCount.rawValue
        let remainder = totalCount % columns
        return remainder == 0 ? 0 : (columns - remainder)
    }

    // MARK: - Initialization

    init(
        albumTitle: String,
        fetchResult: PHFetchResult<PHAsset>,
        imagePipeline: ImagePipelineProtocol = ImagePipeline.shared,
        trashStore: TrashStoreProtocol = TrashStore.shared
    ) {
        self.albumTitle = albumTitle
        self.fetchResult = fetchResult
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
        setupObservers()
        updateEmptyState()

        // iOS 26+: 시스템 UI 사용
        if #available(iOS 26.0, *) {
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }
    }

    /// PRD7: Observer 설정
    private func setupObservers() {
        // TrashStore 변경 감지 (GridViewController와 동일)
        trashStore.onStateChange { [weak self] trashedAssetIDs in
            self?.handleTrashStateChange(trashedAssetIDs)
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
            guard actualIndex >= 0, actualIndex < fetchResult.count else { continue }

            let assetID = fetchResult.object(at: actualIndex).localIdentifier

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

        print("[AlbumGridViewController] Updated \(changedIDs.count) changed cells (no reloadItems)")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if useFloatingUI {
            // iOS 16~25: 시스템 바 숨김 유지
            navigationController?.setNavigationBarHidden(true, animated: animated)
            // tabBar.isHidden은 TabBarController의 BarsVisibilityPolicy에서 관리

            // FloatingOverlay 상태 세팅 (공유 UI 사용)
            configureFloatingOverlayForAlbum()
        } else {
            // iOS 26+: 시스템 바 표시
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }

        // iOS 18+ Zoom Transition 안정화: 전환 중이면 completion에서 처리
        if let coordinator = transitionCoordinator {
            coordinator.animate(alongsideTransition: nil) { [weak self] _ in
                self?.applyPendingViewerReturn()
            }
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // iOS 18+ Zoom Transition 안정화: fallback (transitionCoordinator 없을 때)
        applyPendingViewerReturn()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        updateCellSize()
        updateContentInset()

        // 초기 로드 시 맨 아래로 스크롤 (최신 사진부터 보기)
        if !didInitialScroll && fetchResult.count > 0 {
            didInitialScroll = true
            scrollToBottomIfNeeded()
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateContentInset()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .black
        title = albumTitle

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

        print("[AlbumGridViewController] Initialized with \(fetchResult.count) photos in '\(albumTitle)'")
    }

    /// FloatingOverlay 상태를 앨범 화면용으로 설정
    /// - 타이틀: 앨범명
    /// - 뒤로가기 버튼: 표시 + pop 액션
    private func configureFloatingOverlayForAlbum() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        // 타이틀 변경
        overlay.titleBar.setTitle(albumTitle)

        // 뒤로가기 버튼 표시 + pop 액션 설정
        overlay.titleBar.setShowsBackButton(true) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        // Select 버튼 숨김 (앨범에서는 Select 모드 미지원)
        overlay.titleBar.isSelectButtonHidden = true

        print("[AlbumGridViewController] FloatingOverlay configured for album: \(albumTitle)")
    }

    private func setupGestures() {
        // 핀치 줌 제스처
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        // PRD7: 스와이프 삭제 제스처
        let swipeGesture = UIPanGestureRecognizer(target: self, action: #selector(handleSwipeDelete(_:)))
        swipeGesture.delegate = self
        collectionView.addGestureRecognizer(swipeGesture)
        swipeDeleteState.swipeGesture = swipeGesture

        // PRD7: 투 핑거 탭 제스처
        let twoFingerTap = UITapGestureRecognizer(target: self, action: #selector(handleTwoFingerTap(_:)))
        twoFingerTap.numberOfTouchesRequired = 2
        twoFingerTap.delegate = self
        collectionView.addGestureRecognizer(twoFingerTap)
        swipeDeleteState.twoFingerTapGesture = twoFingerTap

        updateSwipeDeleteGestureEnabled()
    }

    /// PRD7: 스와이프 제스처 활성화 상태 업데이트
    private func updateSwipeDeleteGestureEnabled() {
        let enabled = !UIAccessibility.isVoiceOverRunning
        swipeDeleteState.swipeGesture?.isEnabled = enabled
        swipeDeleteState.twoFingerTapGesture?.isEnabled = enabled
    }

    // MARK: - Layout

    private func createLayout(columns: ColumnCount) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let spacing = Self.cellSpacing
            let columnCount = CGFloat(columns.rawValue)

            let totalSpacing = spacing * (columnCount - 1)
            let availableWidth = environment.container.effectiveContentSize.width - totalSpacing
            let cellWidth = floor(availableWidth / columnCount)

            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellWidth),
                heightDimension: .absolute(cellWidth)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

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

            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsetsReference = .none

            return section
        }

        return layout
    }

    private func updateCellSize() {
        let spacing = Self.cellSpacing
        let columnCount = CGFloat(currentColumnCount.rawValue)
        let totalSpacing = spacing * (columnCount - 1)
        let availableWidth = view.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columnCount)

        currentCellSize = CGSize(width: cellWidth, height: cellWidth)
    }

    /// 맨 아래로 스크롤 (최신 사진부터 보기)
    private func scrollToBottomIfNeeded() {
        guard fetchResult.count > 0 else { return }
        // padding 적용된 마지막 인덱스
        let lastIndex = fetchResult.count - 1 + paddingCellCount
        let lastIndexPath = IndexPath(item: lastIndex, section: 0)
        collectionView.scrollToItem(at: lastIndexPath, at: .bottom, animated: false)
    }

    /// contentInset 업데이트 (플로팅 UI 높이 반영)
    private func updateContentInset() {
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

    private func thumbnailSize() -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(
            width: currentCellSize.width * scale,
            height: currentCellSize.height * scale
        )
    }

    private func updateEmptyState() {
        let isEmpty = fetchResult.count == 0
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }

    // MARK: - Pinch Zoom

    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            let location = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location) {
                pinchAnchorAssetID = fetchResult.object(at: indexPath.item).localIdentifier
            }

        case .changed:
            if let lastTime = lastPinchZoomTime,
               Date().timeIntervalSince(lastTime) < Self.pinchCooldown {
                return
            }

            let scale = gesture.scale
            var newColumnCount: ColumnCount?

            if scale > Self.pinchZoomInThreshold {
                newColumnCount = currentColumnCount.zoomIn
            } else if scale < Self.pinchZoomOutThreshold {
                newColumnCount = currentColumnCount.zoomOut
            }

            if let newCount = newColumnCount, newCount != currentColumnCount {
                performZoom(to: newCount)
                gesture.scale = 1.0
            }

        case .ended, .cancelled:
            pinchAnchorAssetID = nil

        default:
            break
        }
    }

    private func performZoom(to columns: ColumnCount) {
        lastPinchZoomTime = Date()

        let anchorIndexPath: IndexPath?
        if let anchorID = pinchAnchorAssetID {
            anchorIndexPath = indexPath(for: anchorID)
        } else {
            let centerPoint = CGPoint(
                x: collectionView.bounds.midX,
                y: collectionView.bounds.midY + collectionView.contentOffset.y
            )
            anchorIndexPath = collectionView.indexPathForItem(at: centerPoint)
        }

        currentColumnCount = columns
        updateCellSize()

        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self = self else { return }

            self.collectionView.setCollectionViewLayout(
                self.createLayout(columns: columns),
                animated: false
            )

            if let indexPath = anchorIndexPath {
                self.collectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredVertically,
                    animated: false
                )
            }
        }

        print("[AlbumGridViewController] Zoom to \(columns.rawValue) columns")
    }

    // MARK: - Helper Methods

    private func indexPath(for assetID: String) -> IndexPath? {
        for i in 0..<fetchResult.count {
            if fetchResult.object(at: i).localIdentifier == assetID {
                // padding 오프셋 적용
                return IndexPath(item: i + paddingCellCount, section: 0)
            }
        }
        return nil
    }
}

// MARK: - UICollectionViewDataSource

extension AlbumGridViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count + paddingCellCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let padding = paddingCellCount

        // 빈 셀 (맨 위 행 패딩)
        if indexPath.item < padding {
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PhotoCell.reuseIdentifier,
                for: indexPath
            ) as? PhotoCell ?? PhotoCell()
            cell.configureAsEmpty()
            return cell
        }

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCell.reuseIdentifier,
            for: indexPath
        ) as? PhotoCell else {
            return UICollectionViewCell()
        }

        // 실제 에셋 인덱스 계산 (padding 오프셋 적용)
        let assetIndex = indexPath.item - padding
        let asset = fetchResult.object(at: assetIndex)
        let isTrashed = trashStore.isTrashed(asset.localIdentifier)

        cell.configure(
            asset: asset,
            isTrashed: isTrashed,
            targetSize: thumbnailSize()
        )

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension AlbumGridViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let padding = paddingCellCount

        // 빈 셀 탭 무시
        guard indexPath.item >= padding else { return }

        // 실제 에셋 인덱스 계산
        let assetIndex = indexPath.item - padding
        let asset = fetchResult.object(at: assetIndex)
        let isTrashed = trashStore.isTrashed(asset.localIdentifier)

        // 뷰어 모드 결정
        let mode: ViewerMode = isTrashed ? .trash : .normal

        // 뷰어 코디네이터 생성
        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: mode
        )

        // 필터링된 인덱스 계산
        guard let filteredIndex = coordinator.filteredIndex(from: assetIndex) else {
            print("[AlbumGridViewController] Failed to find filtered index for \(assetIndex)")
            return
        }

        // 뷰어 뷰컨트롤러 생성
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: filteredIndex,
            mode: mode
        )
        viewerVC.delegate = self

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

                return cell.thumbnailImageView
            })
        }

        // Push 방식으로 뷰어 표시 (모든 iOS 버전 공통)
        navigationController?.pushViewController(viewerVC, animated: true)

        print("[AlbumGridViewController] Opening viewer at index \(filteredIndex), mode: \(mode)")
    }

    // MARK: - UIScrollViewDelegate (스크롤 롤백 방지)

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 사용자가 스크롤 시작하면 pending 스크롤 취소 (롤백 방지)
        pendingScrollAssetID = nil
        didUserScrollAfterReturn = true
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension AlbumGridViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let padding = paddingCellCount
        // padding 셀 제외하고 실제 에셋만 prefetch
        let assetIDs = indexPaths.compactMap { indexPath -> String? in
            guard indexPath.item >= padding else { return nil }
            let assetIndex = indexPath.item - padding
            guard assetIndex < fetchResult.count else { return nil }
            return fetchResult.object(at: assetIndex).localIdentifier
        }
        imagePipeline.preheat(assetIDs: assetIDs, targetSize: thumbnailSize())
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let padding = paddingCellCount
        let assetIDs = indexPaths.compactMap { indexPath -> String? in
            guard indexPath.item >= padding else { return nil }
            let assetIndex = indexPath.item - padding
            guard assetIndex < fetchResult.count else { return nil }
            return fetchResult.object(at: assetIndex).localIdentifier
        }
        imagePipeline.stopPreheating(assetIDs: assetIDs)
    }
}

// MARK: - ViewerViewControllerDelegate (T053)

extension AlbumGridViewController: ViewerViewControllerDelegate {

    func viewerDidRequestDelete(assetID: String) {
        // T053: 앨범에서 삭제 → TrashStore로 이동
        trashStore.moveToTrash(assetIDs: [assetID])

        // 셀 업데이트 (딤드 표시)
        if let indexPath = indexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        print("[AlbumGridViewController] Moved to trash: \(assetID.prefix(8))...")
    }

    func viewerDidRequestRestore(assetID: String) {
        trashStore.restore(assetIDs: [assetID])

        if let indexPath = indexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        print("[AlbumGridViewController] Restored: \(assetID.prefix(8))...")
    }

    func viewerDidRequestPermanentDelete(assetID: String) {
        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: [assetID])
                print("[AlbumGridViewController] Permanently deleted: \(assetID.prefix(8))...")
            } catch {
                print("[AlbumGridViewController] Failed to permanently delete: \(error)")
            }
        }
    }

    /// 뷰어가 닫힐 때 호출
    /// iOS 18+ Zoom Transition 안정화: 전환 중 scrollToItem 금지
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

        guard let indexPath = indexPath(for: assetID) else { return }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.contains(indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
    }
}

// MARK: - PRD7: Swipe Delete/Restore (FR-101, FR-102)

extension AlbumGridViewController: UIGestureRecognizerDelegate {

    // MARK: - UIGestureRecognizerDelegate

    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
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

    // MARK: - Swipe Delete Handler

    @objc private func handleSwipeDelete(_ gesture: UIPanGestureRecognizer) {
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

    private func handleSwipeDeleteChanged(_ gesture: UIPanGestureRecognizer) {
        guard let cell = swipeDeleteState.targetCell else { return }

        let translation = gesture.translation(in: collectionView)
        let absX = abs(translation.x)

        if absX < SwipeDeleteState.minimumTranslation && !swipeDeleteState.angleCheckPassed {
            return
        }

        if !swipeDeleteState.angleCheckPassed {
            let angle = atan2(abs(translation.y), abs(translation.x))
            if angle > SwipeDeleteState.angleThreshold {
                handleSwipeDeleteCancelled()
                gesture.state = .cancelled
                return
            }
            swipeDeleteState.angleCheckPassed = true
        }

        let progress = min(1.0, absX / currentCellSize.width)
        let direction: PhotoCell.SwipeDirection = translation.x > 0 ? .right : .left
        cell.setDimmedProgress(progress, direction: direction, isTrashed: swipeDeleteState.targetIsTrashed)
    }

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

    private func handleSwipeDeleteCancelled() {
        guard let cell = swipeDeleteState.targetCell else {
            swipeDeleteState.reset()
            return
        }
        cancelSwipeDelete(cell: cell)
    }

    private func confirmSwipeDelete(cell: PhotoCell, indexPath: IndexPath) {
        let isTrashed = swipeDeleteState.targetIsTrashed
        let toTrashed = !isTrashed

        let actualIndex = indexPath.item - paddingCellCount
        guard actualIndex < fetchResult.count else {
            cancelSwipeDelete(cell: cell)
            return
        }
        let assetID = fetchResult.object(at: actualIndex).localIdentifier

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

    private func cancelSwipeDelete(cell: PhotoCell) {
        cell.cancelDimmedAnimation { [weak self] in
            cell.isAnimating = false
            self?.swipeDeleteState.reset()
        }
    }

    private func handleSwipeResult(_ result: Result<Void, TrashStoreError>, cell: PhotoCell) {
        switch result {
        case .success:
            HapticFeedback.light()
            cell.isAnimating = false
        case .failure:
            rollbackSwipeCell(cell: cell)
        }
    }

    private func rollbackSwipeCell(cell: PhotoCell) {
        let originalTrashed = swipeDeleteState.targetIsTrashed

        if originalTrashed {
            cell.fadeDimmed(toTrashed: true) {
                cell.isAnimating = false
            }
        } else {
            cell.cancelDimmedAnimation {
                cell.isAnimating = false
            }
        }

        HapticFeedback.error()
        ToastView.show("저장 실패. 다시 시도해주세요", in: view.window)
    }

    // MARK: - Two Finger Tap Handler

    @objc private func handleTwoFingerTap(_ gesture: UITapGestureRecognizer) {
        guard gesture.state == .ended else { return }

        let touch0 = gesture.location(ofTouch: 0, in: collectionView)
        let touch1 = gesture.location(ofTouch: 1, in: collectionView)

        guard let ip0 = collectionView.indexPathForItem(at: touch0),
              let ip1 = collectionView.indexPathForItem(at: touch1),
              ip0 == ip1,
              ip0.item >= paddingCellCount else {
            return
        }

        let actualIndex = ip0.item - paddingCellCount
        guard actualIndex < fetchResult.count else { return }
        let assetID = fetchResult.object(at: actualIndex).localIdentifier

        guard let cell = collectionView.cellForItem(at: ip0) as? PhotoCell,
              !cell.isAnimating else {
            return
        }

        cell.isAnimating = true
        let isTrashed = cell.isTrashed
        let toTrashed = !isTrashed

        cell.fadeDimmed(toTrashed: toTrashed) { [weak self] in
            guard let self = self else {
                cell.isAnimating = false
                return
            }

            if toTrashed {
                self.trashStore.moveToTrash(assetID) { [weak self] result in
                    self?.handleTwoFingerTapResult(result, cell: cell, originalTrashed: isTrashed)
                }
            } else {
                self.trashStore.restore(assetID) { [weak self] result in
                    self?.handleTwoFingerTapResult(result, cell: cell, originalTrashed: isTrashed)
                }
            }
        }
    }

    private func handleTwoFingerTapResult(
        _ result: Result<Void, TrashStoreError>,
        cell: PhotoCell,
        originalTrashed: Bool
    ) {
        switch result {
        case .success:
            HapticFeedback.light()
            cell.isAnimating = false
        case .failure:
            cell.fadeDimmed(toTrashed: originalTrashed) {
                cell.isAnimating = false
            }
            HapticFeedback.error()
            ToastView.show("저장 실패. 다시 시도해주세요", in: view.window)
        }
    }
}

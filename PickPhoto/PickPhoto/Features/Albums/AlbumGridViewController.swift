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
    private let albumTitle: String

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
        updateEmptyState()

        // iOS 26+: 시스템 UI 사용
        if #available(iOS 26.0, *) {
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if useFloatingUI {
            // iOS 16~25: 시스템 바 숨김 유지
            navigationController?.setNavigationBarHidden(true, animated: animated)
            tabBarController?.tabBar.isHidden = true

            // FloatingOverlay 상태 세팅 (공유 UI 사용)
            configureFloatingOverlayForAlbum()
        } else {
            // iOS 26+: 시스템 바 표시
            navigationController?.setNavigationBarHidden(false, animated: animated)
        }
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
                return IndexPath(item: i, section: 0)
            }
        }
        return nil
    }
}

// MARK: - UICollectionViewDataSource

extension AlbumGridViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return fetchResult.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCell.reuseIdentifier,
            for: indexPath
        ) as? PhotoCell else {
            return UICollectionViewCell()
        }

        let asset = fetchResult.object(at: indexPath.item)
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
        let asset = fetchResult.object(at: indexPath.item)
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
        guard let filteredIndex = coordinator.filteredIndex(from: indexPath.item) else {
            print("[AlbumGridViewController] Failed to find filtered index for \(indexPath.item)")
            return
        }

        // 뷰어 뷰컨트롤러 생성
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: filteredIndex,
            mode: mode
        )
        viewerVC.delegate = self

        present(viewerVC, animated: false)

        print("[AlbumGridViewController] Opening viewer at index \(filteredIndex), mode: \(mode)")
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension AlbumGridViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assetIDs = indexPaths.map { fetchResult.object(at: $0.item).localIdentifier }
        imagePipeline.preheat(assetIDs: assetIDs, targetSize: thumbnailSize())
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assetIDs = indexPaths.map { fetchResult.object(at: $0.item).localIdentifier }
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

    func viewerWillClose(currentAssetID: String?) {
        collectionView.reloadData()

        if let assetID = currentAssetID,
           let indexPath = indexPath(for: assetID) {
            let visibleIndexPaths = collectionView.indexPathsForVisibleItems
            if !visibleIndexPaths.contains(indexPath) {
                collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            }
        }
    }
}

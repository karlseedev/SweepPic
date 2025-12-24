// TrashAlbumViewController.swift
// 휴지통 앨범 뷰컨트롤러
//
// T055: 휴지통 전용 그리드 뷰
// - TrashStore.trashedAssetIDs 기반 사진 필터링
// - 딤드 없이 정상 표시 (휴지통 내에서는 모두 동일)
// - 셀 탭 → ViewerViewController (mode: .trash)
//
// T058: "비우기" 버튼 구현
// - 일괄 삭제 iOS 시스템 팝업
//
// T059: 빈 상태 표시
// - "휴지통이 비어 있습니다"

import UIKit
import Photos
import AppCore

/// 휴지통 앨범 뷰컨트롤러
/// TrashStore의 삭제 예정 사진을 그리드로 표시
/// TabBarController의 FloatingOverlay를 공유하여 상태만 변경
final class TrashAlbumViewController: UIViewController {

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

    /// 빈 상태 뷰 (T059)
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(
            icon: "trash",
            title: "휴지통이 비어 있습니다",
            subtitle: nil
        )
        view.useDarkTheme()  // 검정 배경에서 사용
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

    /// 이미지 파이프라인
    private let imagePipeline: ImagePipelineProtocol

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol

    /// 휴지통 사진 ID Set
    private var trashedAssetIDSet: Set<String> = []

    /// 휴지통 사진 PHAsset 배열
    private var trashedAssets: [PHAsset] = []

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

    /// 맨 위 행 빈 셀 개수 (3의 배수가 아닐 시 맨 위 행에 빈 셀)
    /// 최신 사진(맨 아래) 기준 꽉 차게 정렬
    private var paddingCellCount: Int {
        let totalCount = trashedAssets.count
        guard totalCount > 0 else { return 0 }
        let columns = currentColumnCount.rawValue
        let remainder = totalCount % columns
        return remainder == 0 ? 0 : (columns - remainder)
    }

    // MARK: - Initialization

    init(
        imagePipeline: ImagePipelineProtocol = ImagePipeline.shared,
        trashStore: TrashStoreProtocol = TrashStore.shared
    ) {
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
        loadTrashedAssets()

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
            configureFloatingOverlayForTrash()
        } else {
            // iOS 26+: 시스템 바 표시
            navigationController?.setNavigationBarHidden(false, animated: animated)
            // 시스템 네비바에 "비우기" 버튼 추가
            setupSystemNavigationBar()
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
        title = "휴지통"

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

        print("[TrashAlbumViewController] Initialized")
    }

    /// 시스템 네비바 설정 (iOS 26+)
    private func setupSystemNavigationBar() {
        // "비우기" 버튼 추가
        let emptyButton = UIBarButtonItem(
            title: "비우기",
            style: .plain,
            target: self,
            action: #selector(emptyTrashButtonTapped)
        )
        emptyButton.tintColor = .systemRed
        navigationItem.rightBarButtonItem = emptyButton

        // 빈 휴지통이면 버튼 비활성화
        emptyButton.isEnabled = !trashedAssets.isEmpty
    }

    /// FloatingOverlay 상태를 휴지통 탭용으로 설정
    /// - 타이틀: "Trash"
    /// - 뒤로가기 버튼: 숨김 (별도 탭이므로)
    /// - 오른쪽 버튼: "비우기" (휴지통이 비어있지 않을 때만 표시)
    private func configureFloatingOverlayForTrash() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        // 타이틀 변경
        overlay.titleBar.setTitle("Trash")

        // 뒤로가기 버튼 숨김 (별도 탭이므로)
        overlay.titleBar.setShowsBackButton(false, action: nil)

        // "비우기" 버튼 설정 (휴지통이 비어있지 않을 때)
        if !trashedAssets.isEmpty {
            overlay.titleBar.setRightButton(title: "비우기", color: .systemRed) { [weak self] in
                self?.emptyTrashButtonTapped()
            }
        } else {
            overlay.titleBar.isSelectButtonHidden = true
        }

        print("[TrashAlbumViewController] FloatingOverlay configured for trash tab")
    }

    private func setupGestures() {
        // 핀치 줌 제스처
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)
    }

    /// TrashStore 상태 변경 구독
    private func setupObservers() {
        trashStore.onStateChange { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadTrashedAssets()
            }
        }
    }

    // MARK: - Data Loading

    /// 휴지통 사진 로드
    /// TrashStore.trashedAssetIDs 기반으로 PHAsset 조회
    private func loadTrashedAssets() {
        let startTime = CFAbsoluteTimeGetCurrent()

        trashedAssetIDSet = trashStore.trashedAssetIDs

        if trashedAssetIDSet.isEmpty {
            trashedAssets = []
        } else {
            // PHAsset 조회 (Set → Array 변환)
            let options = PHFetchOptions()
            options.includeHiddenAssets = false
            options.includeAllBurstAssets = false

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(trashedAssetIDSet), options: options)

            let fetchTime = CFAbsoluteTimeGetCurrent()

            // 배열로 변환
            var assets: [PHAsset] = []
            fetchResult.enumerateObjects { asset, _, _ in
                assets.append(asset)
            }

            let enumerateTime = CFAbsoluteTimeGetCurrent()

            // 생성일 기준 오름차순 정렬 (최신 사진이 아래, 아이폰 기본 사진앱과 동일)
            trashedAssets = assets.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }

            let sortTime = CFAbsoluteTimeGetCurrent()

            print("[TrashAlbumViewController.Timing] fetch: \(String(format: "%.1f", (fetchTime - startTime) * 1000))ms, enumerate: \(String(format: "%.1f", (enumerateTime - fetchTime) * 1000))ms, sort: \(String(format: "%.1f", (sortTime - enumerateTime) * 1000))ms")
        }

        let dataLoadTime = CFAbsoluteTimeGetCurrent()

        // UI 업데이트
        collectionView.reloadData()

        let reloadTime = CFAbsoluteTimeGetCurrent()

        updateEmptyState()

        // 버튼 상태 업데이트
        if useFloatingUI {
            // iOS 16~25: FloatingUI 비우기 버튼 상태 갱신
            updateFloatingEmptyButton()
        } else {
            // iOS 26+: 시스템 네비바 버튼 상태 업데이트
            navigationItem.rightBarButtonItem?.isEnabled = !trashedAssets.isEmpty
        }

        let endTime = CFAbsoluteTimeGetCurrent()

        print("[TrashAlbumViewController] Loaded \(trashedAssets.count) trashed assets")
        print("[TrashAlbumViewController.Timing] dataLoad: \(String(format: "%.1f", (dataLoadTime - startTime) * 1000))ms, reloadData: \(String(format: "%.1f", (reloadTime - dataLoadTime) * 1000))ms, total: \(String(format: "%.1f", (endTime - startTime) * 1000))ms")

        // 초기 로드 시 맨 아래로 스크롤 (최신 사진부터 보기)
        if !didInitialScroll {
            didInitialScroll = true
            collectionView.layoutIfNeeded()
            scrollToBottomIfNeeded()
        }
    }

    /// 맨 아래로 스크롤 (최신 사진부터 보기)
    private func scrollToBottomIfNeeded() {
        guard !trashedAssets.isEmpty else { return }
        // padding 적용된 마지막 인덱스
        let lastIndex = trashedAssets.count - 1 + paddingCellCount
        let lastIndexPath = IndexPath(item: lastIndex, section: 0)
        collectionView.scrollToItem(at: lastIndexPath, at: .bottom, animated: false)
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

    /// 빈 상태 업데이트 (T059)
    private func updateEmptyState() {
        let isEmpty = trashedAssets.isEmpty
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }

    /// FloatingUI 비우기 버튼 상태 업데이트
    private func updateFloatingEmptyButton() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        if !trashedAssets.isEmpty {
            overlay.titleBar.setRightButton(title: "비우기", color: .systemRed) { [weak self] in
                self?.emptyTrashButtonTapped()
            }
        } else {
            overlay.titleBar.isSelectButtonHidden = true
        }
    }

    // MARK: - Actions

    /// "비우기" 버튼 탭 (T058)
    /// 바로 iOS 시스템 팝업으로 일괄 삭제 (확인 얼럿 생략 - iOS 팝업이 확인 역할)
    @objc private func emptyTrashButtonTapped() {
        guard !trashedAssets.isEmpty else { return }
        performEmptyTrash()
    }

    /// 휴지통 비우기 실행
    private func performEmptyTrash() {
        Task {
            do {
                try await trashStore.emptyTrash()
                print("[TrashAlbumViewController] Trash emptied successfully")
            } catch {
                // 취소 또는 오류 시 조용히 무시 (사진이 그대로 남아있음)
                print("[TrashAlbumViewController] Empty trash cancelled or failed: \(error)")
            }
            // 성공/실패 무관하게 UI 갱신 (onStateChange 콜백으로 처리됨)
        }
    }

    // MARK: - Pinch Zoom

    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            let location = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location),
               indexPath.item < trashedAssets.count {
                pinchAnchorAssetID = trashedAssets[indexPath.item].localIdentifier
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

        print("[TrashAlbumViewController] Zoom to \(columns.rawValue) columns")
    }

    // MARK: - Helper Methods

    private func indexPath(for assetID: String) -> IndexPath? {
        for i in 0..<trashedAssets.count {
            if trashedAssets[i].localIdentifier == assetID {
                return IndexPath(item: i, section: 0)
            }
        }
        return nil
    }
}

// MARK: - UICollectionViewDataSource

extension TrashAlbumViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return trashedAssets.count + paddingCellCount
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
        guard assetIndex < trashedAssets.count else {
            return cell
        }

        let asset = trashedAssets[assetIndex]

        // 휴지통 내에서는 딤드 표시 안 함 (모두 삭제 대상이므로 정상 표시)
        cell.configure(
            asset: asset,
            isTrashed: false,  // 휴지통 내에서는 딤드 없이 표시
            targetSize: thumbnailSize()
        )

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension TrashAlbumViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let padding = paddingCellCount

        // 빈 셀 탭 무시
        guard indexPath.item >= padding else { return }

        // 실제 에셋 인덱스 계산
        let assetIndex = indexPath.item - padding
        guard assetIndex < trashedAssets.count else { return }

        // 클릭한 에셋
        let selectedAsset = trashedAssets[assetIndex]
        let selectedAssetID = selectedAsset.localIdentifier

        // 뷰어 코디네이터 생성 (휴지통 전용)
        // trashedAssets 배열을 기반으로 PHFetchResult 생성
        // 정렬 옵션 추가: 최신 사진이 아래 (아이폰 기본 사진앱과 동일)
        let assetIDs = trashedAssets.map { $0.localIdentifier }
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: fetchOptions)

        // PHFetchResult에서 선택한 에셋의 실제 인덱스 찾기
        var actualIndex = 0
        fetchResult.enumerateObjects { asset, index, stop in
            if asset.localIdentifier == selectedAssetID {
                actualIndex = index
                stop.pointee = true
            }
        }

        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: .trash
        )

        // 뷰어 뷰컨트롤러 생성 (휴지통 모드)
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: actualIndex,
            mode: .trash
        )
        viewerVC.delegate = self

        present(viewerVC, animated: false)

        print("[TrashAlbumViewController] Opening viewer - tapped: \(indexPath.item), actualIndex: \(actualIndex), assetID: \(selectedAssetID.prefix(8))...")
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension TrashAlbumViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let padding = paddingCellCount
        // padding 셀 제외하고 실제 에셋만 prefetch
        let assetIDs = indexPaths.compactMap { indexPath -> String? in
            guard indexPath.item >= padding else { return nil }
            let assetIndex = indexPath.item - padding
            guard assetIndex < trashedAssets.count else { return nil }
            return trashedAssets[assetIndex].localIdentifier
        }
        imagePipeline.preheat(assetIDs: assetIDs, targetSize: thumbnailSize())
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let padding = paddingCellCount
        let assetIDs = indexPaths.compactMap { indexPath -> String? in
            guard indexPath.item >= padding else { return nil }
            let assetIndex = indexPath.item - padding
            guard assetIndex < trashedAssets.count else { return nil }
            return trashedAssets[assetIndex].localIdentifier
        }
        imagePipeline.stopPreheating(assetIDs: assetIDs)
    }
}

// MARK: - ViewerViewControllerDelegate (T056, T057)

extension TrashAlbumViewController: ViewerViewControllerDelegate {

    /// 삭제 요청 (휴지통에서는 사용 안 함)
    func viewerDidRequestDelete(assetID: String) {
        // 휴지통에서는 삭제 버튼 대신 복구/완전삭제 버튼 사용
        // 이 메서드는 호출되지 않음
    }

    /// 복구 요청 (T056)
    func viewerDidRequestRestore(assetID: String) {
        let startTime = CFAbsoluteTimeGetCurrent()

        trashStore.restore(assetIDs: [assetID])
        // loadTrashedAssets()는 onStateChange 콜백으로 자동 호출됨

        let trashStoreTime = CFAbsoluteTimeGetCurrent()

        print("[TrashAlbumViewController] Restored: \(assetID.prefix(8))...")
        print("[TrashAlbumViewController.Timing] trashStore: \(String(format: "%.1f", (trashStoreTime - startTime) * 1000))ms")
    }

    /// 완전 삭제 요청 (T057)
    /// 비동기 작업 - 삭제 완료 후 뷰어에 알림
    func viewerDidRequestPermanentDelete(assetID: String) {
        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: [assetID])
                // loadTrashedAssets()는 onStateChange 콜백으로 자동 호출됨
                print("[TrashAlbumViewController] Permanently deleted: \(assetID.prefix(8))...")

                // 삭제 완료 후 뷰어에 알림 (메인 스레드에서)
                await MainActor.run {
                    if let viewerVC = self.presentedViewController as? ViewerViewController {
                        viewerVC.handleDeleteComplete()
                    }
                }
            } catch {
                print("[TrashAlbumViewController] Failed to permanently delete: \(error)")
            }
        }
    }

    /// 뷰어 닫기 시
    func viewerWillClose(currentAssetID: String?) {
        // 이미 onStateChange로 업데이트됨
        // 필요하면 스크롤 위치 조정
        if let assetID = currentAssetID,
           let indexPath = indexPath(for: assetID) {
            let visibleIndexPaths = collectionView.indexPathsForVisibleItems
            if !visibleIndexPaths.contains(indexPath) {
                collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            }
        }
    }
}

// AlbumsViewController.swift
// 앨범 목록 뷰컨트롤러
//
// T050: AlbumsViewController 생성
// - 2열 그리드 레이아웃, iOS 사진 앱 스타일
// - 스마트 앨범 + 사용자 앨범 섹션

import UIKit
import Photos
import AppCore

/// 앨범 목록 뷰컨트롤러
/// Albums 탭에서 앨범 목록을 표시
final class AlbumsViewController: UIViewController {

    // MARK: - Constants

    /// 열 수
    private static let columnCount: CGFloat = 2

    /// 셀 간격
    private static let cellSpacing: CGFloat = 16

    /// 섹션 헤더 높이
    private static let headerHeight: CGFloat = 44

    // MARK: - UI Components

    /// 컬렉션 뷰
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        cv.backgroundColor = .systemBackground
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(AlbumCell.self, forCellWithReuseIdentifier: AlbumCell.reuseIdentifier)
        cv.register(
            AlbumSectionHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: AlbumSectionHeaderView.reuseIdentifier
        )
        cv.delegate = self
        cv.dataSource = self
        cv.alwaysBounceVertical = true
        // T027-1f: Edge-to-edge 설정
        cv.contentInsetAdjustmentBehavior = .never
        return cv
    }()

    /// 빈 상태 뷰
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(
            icon: "rectangle.stack",
            title: "앨범이 없습니다",
            subtitle: "앨범을 생성하세요"
        )
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Properties

    /// 앨범 서비스
    private let albumService: AlbumServiceProtocol

    /// 스마트 앨범 목록
    private var smartAlbums: [SmartAlbum] = []

    /// 사용자 앨범 목록
    private var userAlbums: [Album] = []

    /// keyAsset 캐시 (앨범ID → PHAsset, 셀에서 개별 fetch 방지)
    private var keyAssetCache: [String: PHAsset] = [:]

    /// 현재 셀 크기
    private var currentCellSize: CGSize = .zero

    // MARK: - Loading State

    /// 비동기 로딩 중 여부 (중복 로딩 방지)
    private var isLoading = false

    /// 비동기 응답 역전(stale overwrite) 방지용 세대 카운터
    private var loadGeneration: UInt = 0

    /// 마지막 로드 완료 시간 (조건부 재로딩)
    private var lastLoadTime: CFAbsoluteTime = 0

    /// 로딩 중 또는 백그라운드 변경 플래그
    private var needsReload = false

    /// 최초 로드 완료 여부 (viewDidLoad + viewWillAppear 이중 호출 방지)
    private var hasLoadedOnce = false

    // MARK: - Initialization

    init(albumService: AlbumServiceProtocol = AlbumService.shared) {
        self.albumService = albumService
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.albumService = AlbumService.shared
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupObservers()

        // Phase 1: 동기 경량 로드 (컬렉션 메타데이터만, ~11회 호출)
        // → 앨범명 + 개수 즉시 표시 (썸네일은 placeholder)
        loadDataLightweight()

        // Phase 2: 비동기 전체 로드 (정확한 개수 + 썸네일 + keyAsset)
        loadData()

        // T027-1f: iOS 26+에서 시스템 바 사용
        if #available(iOS 26.0, *) {
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // ⚠️ 최초 진입 시 viewDidLoad에서 이미 loadData() 호출됨 → 이중 호출 방지
        // hasLoadedOnce = false: viewDidLoad의 loadData() 완료 전 → 스킵 (이중 reloadData 깜빡임 방지)
        // hasLoadedOnce = true: 이후 진입 (앨범 상세에서 복귀 등) → 조건부 로드
        if hasLoadedOnce {
            let now = CFAbsoluteTimeGetCurrent()
            if needsReload || (now - lastLoadTime > 1.0) {
                loadData()
            }
        }

        // iOS 16~25: FloatingOverlay 기본 상태 세팅
        // (push에서 돌아올 때 앨범 화면 상태로 복원)
        configureFloatingOverlayForAlbums()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // [LiquidGlass 최적화] 블러 뷰 사전 생성 + idle pause
        LiquidGlassOptimizer.preload(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)
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
        view.backgroundColor = .systemBackground
        // ⚠️ 상단 타이틀 명칭 변경 시 동시 수정 필요:
        // - AlbumsViewController.swift: navigationItem.title (여기), setTitle()
        // - FloatingOverlayContainer.swift: titleBar.title
        // 주의: title 대신 navigationItem.title 사용 (tabBarItem.title 덮어쓰기 방지)
        // 커스텀 titleView로 좌측 정렬 타이틀 설정 (컨테이너로 전체 너비 확보)
        let titleContainer = UIView()
        let titleLabel = UILabel()
        titleLabel.attributedText = NSAttributedString(string: "앨범", attributes: [
            .font: UIFont.systemFont(ofSize: 36, weight: .light),
            .kern: -1.0
        ])
        titleLabel.textColor = .label
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleContainer.addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: titleContainer.leadingAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: titleContainer.centerYAnchor)
        ])
        navigationItem.titleView = titleContainer

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
    }

    private func setupObservers() {
        // PhotoKit 변경 감지 (앨범 추가/삭제 등)
        PHPhotoLibrary.shared().register(self)
    }

    deinit {
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
    }

    /// FloatingOverlay 상태를 Albums 목록 화면용으로 설정
    /// - 타이틀: "Albums"
    /// - 뒤로가기 버튼: 숨김
    /// - Select 버튼: 숨김
    private func configureFloatingOverlayForAlbums() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        // ⚠️ 앨범 명칭 변경 시 동시 수정 필요:
        // - TabBarController.swift: tabBarItem.title
        // - AlbumsViewController.swift: title, setTitle() (여기)
        // - FloatingOverlayContainer.swift: titleBar.title
        overlay.titleBar.setTitle("앨범")
        overlay.titleBar.setSubtitle(nil)
        overlay.titleBar.isTitleCenteredVertically = false  // 앨범 상세에서 돌아올 때 상단 정렬 복원

        // 뒤로가기 버튼 숨김
        overlay.titleBar.setShowsBackButton(false)

        // 버튼 숨김 (Albums 탭에서는 Select 모드 미지원)
        overlay.titleBar.isSelectButtonHidden = true
        overlay.titleBar.hideSecondRightButton()
    }

    // MARK: - Layout

    /// 2열 그리드 레이아웃 생성
    private func createLayout() -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            let spacing = Self.cellSpacing
            let columnCount = Self.columnCount

            // 셀 크기 계산
            let totalSpacing = spacing * (columnCount + 1) // 좌우 패딩 + 셀 간격
            let availableWidth = environment.container.effectiveContentSize.width - totalSpacing
            let cellWidth = floor(availableWidth / columnCount)

            // 아이템 크기 (썸네일 + 라벨 높이)
            let thumbnailHeight = cellWidth
            let labelHeight: CGFloat = 40 // 제목 + 개수 라벨
            let cellHeight = thumbnailHeight + labelHeight

            // 아이템
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellWidth),
                heightDimension: .absolute(cellHeight)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            // 그룹
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellHeight)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: Int(columnCount)
            )
            group.interItemSpacing = .fixed(spacing)

            // 섹션
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            section.contentInsets = NSDirectionalEdgeInsets(
                top: spacing,
                leading: spacing,
                bottom: spacing,
                trailing: spacing
            )

            // 섹션 헤더 (스마트 앨범, 사용자 앨범 섹션)
            let albumSection = AlbumSection(rawValue: sectionIndex)
            if albumSection?.headerTitle != nil {
                let headerSize = NSCollectionLayoutSize(
                    widthDimension: .fractionalWidth(1.0),
                    heightDimension: .absolute(Self.headerHeight)
                )
                let header = NSCollectionLayoutBoundarySupplementaryItem(
                    layoutSize: headerSize,
                    elementKind: UICollectionView.elementKindSectionHeader,
                    alignment: .top
                )
                section.boundarySupplementaryItems = [header]
            }

            return section
        }

        return layout
    }

    /// 셀 크기 업데이트
    private func updateCellSize() {
        let spacing = Self.cellSpacing
        let columnCount = Self.columnCount
        let totalSpacing = spacing * (columnCount + 1)
        let availableWidth = view.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columnCount)

        currentCellSize = CGSize(width: cellWidth, height: cellWidth)
    }

    /// contentInset 업데이트 (플로팅 UI 높이 반영)
    private func updateContentInset() {
        // iOS 26+에서는 시스템 자동 조정 사용
        if #available(iOS 26.0, *) {
            return
        }

        // TabBarController에서 오버레이 높이 가져오기
        guard let tabBarController = tabBarController as? TabBarController,
              let heights = tabBarController.getOverlayHeights() else {
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

        let inset = UIEdgeInsets(
            top: heights.top,
            left: 0,
            bottom: heights.bottom,
            right: 0
        )

        collectionView.contentInset = inset
        collectionView.scrollIndicatorInsets = inset
    }

    // MARK: - Data Loading

    /// Phase 1: 경량 동기 로드 (컬렉션 메타데이터만)
    /// - PHAsset.fetchAssets 호출 없음 → 매우 빠름 (~11회 collection 호출)
    /// - estimatedAssetCount 사용 (정확하지 않을 수 있음)
    /// - keyAsset 없음 → 셀에서 placeholder 표시
    /// - viewDidLoad에서 1회만 호출 → 즉시 앨범 목록 표시
    private func loadDataLightweight() {
        let result = albumService.fetchAlbumMetadataSync()
        smartAlbums = result.smartAlbums
        userAlbums = result.userAlbums
        updateEmptyState()
        collectionView.reloadData()
        hasLoadedOnce = true
        lastLoadTime = CFAbsoluteTimeGetCurrent()

        Log.print("[AlbumsViewController] Lightweight: \(smartAlbums.count) smart, \(userAlbums.count) user albums")
    }

    /// Phase 2: 비동기 전체 로드 (정확한 개수 + keyAsset + 썸네일)
    /// - 중복 로딩 방지 (isLoading guard)
    /// - 응답 역전 방지 (loadGeneration 비교)
    /// - 깜빡임 방지 (completion 내 즉시 재호출 금지)
    private func loadData() {
        guard !isLoading else {
            // 로딩 중 요청 → 완료 후 재로드 필요
            needsReload = true
            return
        }
        isLoading = true
        needsReload = false  // 플래그 소비
        loadGeneration += 1
        let currentGeneration = loadGeneration

        albumService.fetchAllAlbumsAsync { [weak self] smartAlbums, userAlbums, keyAssets in
            guard let self = self else { return }
            // stale 응답 무시 (더 새로운 요청이 발행된 경우)
            guard currentGeneration == self.loadGeneration else { return }

            self.isLoading = false
            self.hasLoadedOnce = true
            self.lastLoadTime = CFAbsoluteTimeGetCurrent()
            self.smartAlbums = smartAlbums
            self.userAlbums = userAlbums
            self.keyAssetCache = keyAssets
            self.updateEmptyState()
            self.collectionView.reloadData()

            Log.print("[AlbumsViewController] Loaded \(smartAlbums.count) smart albums, \(userAlbums.count) user albums")

            // ⚠️ 깜빡임 방지: completion 내 즉시 재호출 금지
            // needsReload은 다음 viewWillAppear 또는 photoLibraryDidChange(visible)에서 처리
        }
    }

    /// 빈 상태 업데이트
    /// ⚠️ collectionView.isHidden 토글 제거 — hidden→visible 전환 시
    /// 모든 셀이 한꺼번에 생성되는 레이아웃 부하를 방지
    private func updateEmptyState() {
        let isEmpty = smartAlbums.isEmpty && userAlbums.isEmpty
        emptyStateView.isHidden = !isEmpty
        // collectionView는 항상 visible (빈 컬렉션뷰는 시각적으로 문제없음)
    }

    // MARK: - Thumbnail Size

    /// 썸네일 크기 (스케일 적용)
    private func thumbnailSize() -> CGSize {
        let scale = UIScreen.main.scale
        return CGSize(
            width: currentCellSize.width * scale,
            height: currentCellSize.height * scale
        )
    }
}

// MARK: - UICollectionViewDataSource

extension AlbumsViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return AlbumSection.allCases.count
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        guard let albumSection = AlbumSection(rawValue: section) else { return 0 }

        switch albumSection {
        case .smartAlbums:
            return smartAlbums.count
        case .userAlbums:
            return userAlbums.count
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: AlbumCell.reuseIdentifier,
            for: indexPath
        ) as? AlbumCell else {
            return UICollectionViewCell()
        }

        guard let albumSection = AlbumSection(rawValue: indexPath.section) else {
            return cell
        }

        let targetSize = thumbnailSize()

        switch albumSection {
        case .smartAlbums:
            let smartAlbum = smartAlbums[indexPath.item]
            let keyAsset = keyAssetCache[smartAlbum.id]
            cell.configure(smartAlbum: smartAlbum, keyAsset: keyAsset, targetSize: targetSize)

        case .userAlbums:
            let album = userAlbums[indexPath.item]
            let keyAsset = keyAssetCache[album.id]
            cell.configure(album: album, keyAsset: keyAsset, targetSize: targetSize)
        }

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader,
              let headerView = collectionView.dequeueReusableSupplementaryView(
                ofKind: kind,
                withReuseIdentifier: AlbumSectionHeaderView.reuseIdentifier,
                for: indexPath
              ) as? AlbumSectionHeaderView else {
            return UICollectionReusableView()
        }

        if let albumSection = AlbumSection(rawValue: indexPath.section) {
            headerView.configure(title: albumSection.headerTitle)
        }

        return headerView
    }
}

// MARK: - UICollectionViewDelegate

extension AlbumsViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        guard let albumSection = AlbumSection(rawValue: indexPath.section) else { return }

        switch albumSection {
        case .smartAlbums:
            let smartAlbum = smartAlbums[indexPath.item]
            openAlbumGrid(smartAlbum: smartAlbum)

        case .userAlbums:
            let album = userAlbums[indexPath.item]
            openAlbumGrid(album: album)
        }
    }

    // MARK: - Navigation

    /// 스마트 앨범 그리드 열기 (T052)
    private func openAlbumGrid(smartAlbum: SmartAlbum) {
        guard let fetchResult = albumService.fetchPhotosInSmartAlbum(type: smartAlbum.type) else {
            Log.print("[AlbumsViewController] Failed to fetch photos for smart album: \(smartAlbum.type)")
            return
        }

        let albumGridVC = AlbumGridViewController(
            albumTitle: smartAlbum.title,
            fetchResult: fetchResult
        )

        // 커스텀 줌 트랜지션은 Phase 4에서 구현 예정
        // (현재는 시스템 기본 전환 사용)

        navigationController?.pushViewController(albumGridVC, animated: true)

        Log.print("[AlbumsViewController] Opened smart album: \(smartAlbum.title)")
    }

    /// 사용자 앨범 그리드 열기 (T052)
    private func openAlbumGrid(album: Album) {
        guard let fetchResult = albumService.fetchPhotosInAlbum(albumID: album.id) else {
            Log.print("[AlbumsViewController] Failed to fetch photos for album: \(album.title)")
            return
        }

        let albumGridVC = AlbumGridViewController(
            albumTitle: album.title,
            fetchResult: fetchResult
        )

        // 커스텀 줌 트랜지션은 Phase 4에서 구현 예정
        // (현재는 시스템 기본 전환 사용)

        navigationController?.pushViewController(albumGridVC, animated: true)

        Log.print("[AlbumsViewController] Opened album: \(album.title)")
    }

    // MARK: - iOS 18+ Zoom Transition Helper

    /// 앨범 제목으로 해당 셀의 IndexPath 찾기
    /// iOS 18+ zoom transition의 sourceViewProvider에서 사용
    private func findIndexPath(for albumTitle: String) -> IndexPath? {
        // 스마트 앨범에서 검색
        if let index = smartAlbums.firstIndex(where: { $0.title == albumTitle }) {
            return IndexPath(item: index, section: AlbumSection.smartAlbums.rawValue)
        }
        // 사용자 앨범에서 검색
        if let index = userAlbums.firstIndex(where: { $0.title == albumTitle }) {
            return IndexPath(item: index, section: AlbumSection.userAlbums.rawValue)
        }
        return nil
    }
}

// MARK: - AlbumSectionHeaderView

/// 앨범 섹션 헤더 뷰
final class AlbumSectionHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "AlbumSectionHeaderView"

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .bold)
        label.textColor = .label
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    private func setupUI() {
        addSubview(titleLabel)
        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8)
        ])
    }

    func configure(title: String?) {
        titleLabel.text = title
    }
}

// MARK: - PHPhotoLibraryChangeObserver

// MARK: - LiquidGlass 최적화 (UIScrollViewDelegate)

extension AlbumsViewController {

    /// 드래그 시작 (터치 직후) - 최적화 시작
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.cancelIdleTimer()
        LiquidGlassOptimizer.optimize(in: view.window)
        Log.print("[Albums:Scroll] willBeginDragging - optimize 시작")
    }

    /// 감속 완료 - 최적화 해제
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.restore(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)
        Log.print("[Albums:Scroll] didEndDecelerating - restore 완료")
    }

    /// 드래그 종료 (감속 없이 멈춤) - 최적화 해제
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            LiquidGlassOptimizer.restore(in: view.window)
            LiquidGlassOptimizer.enterIdle(in: view.window)
            Log.print("[Albums:Scroll] didEndDragging(willDecelerate=false) - restore 완료")
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension AlbumsViewController: PHPhotoLibraryChangeObserver {

    /// PhotoKit 변경 감지
    /// 앨범 추가/삭제, 사진 변경 등 감지하여 UI 갱신
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }

            if self.view.window != nil {
                // 화면 보이는 중: 비동기 로드 (블로킹 없음)
                self.loadData()
                Log.print("[AlbumsViewController] PhotoLibrary changed, reloading data")
            } else {
                // 화면 안 보이는 중: 플래그만 설정 (viewWillAppear에서 처리)
                self.needsReload = true
                Log.print("[AlbumsViewController] PhotoLibrary changed, deferred reload")
            }
        }
    }
}

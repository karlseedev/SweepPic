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

    /// 현재 셀 크기
    private var currentCellSize: CGSize = .zero

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
        // 화면 표시 시 데이터 갱신 (휴지통 상태 등 반영)
        loadData()

        // iOS 16~25: FloatingOverlay 기본 상태 세팅
        // (push에서 돌아올 때 앨범 화면 상태로 복원)
        configureFloatingOverlayForAlbums()
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
        // ⚠️ 앨범 명칭 변경 시 동시 수정 필요:
        // - TabBarController.swift: tabBarItem.title
        // - AlbumsViewController.swift: title (여기), setTitle()
        // - FloatingOverlayContainer.swift: titleBar.title
        title = "앨범"

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

        // 뒤로가기 버튼 숨김
        overlay.titleBar.setShowsBackButton(false)

        // Select 버튼 숨김 (Albums 탭에서는 Select 모드 미지원)
        overlay.titleBar.isSelectButtonHidden = true
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

    /// 데이터 로드
    private func loadData() {
        // 스마트 앨범 조회
        smartAlbums = albumService.fetchSmartAlbums()

        // 사용자 앨범 조회
        userAlbums = albumService.fetchUserAlbums()

        // 빈 상태 업데이트
        updateEmptyState()

        // 컬렉션 뷰 리로드
        collectionView.reloadData()

        print("[AlbumsViewController] Loaded \(smartAlbums.count) smart albums, \(userAlbums.count) user albums")
    }

    /// 빈 상태 업데이트
    private func updateEmptyState() {
        let isEmpty = smartAlbums.isEmpty && userAlbums.isEmpty
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
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
            cell.configure(smartAlbum: smartAlbum, targetSize: targetSize)

        case .userAlbums:
            let album = userAlbums[indexPath.item]
            cell.configure(album: album, targetSize: targetSize)
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
            print("[AlbumsViewController] Failed to fetch photos for smart album: \(smartAlbum.type)")
            return
        }

        let albumGridVC = AlbumGridViewController(
            albumTitle: smartAlbum.title,
            fetchResult: fetchResult
        )

        navigationController?.pushViewController(albumGridVC, animated: true)

        print("[AlbumsViewController] Opened smart album: \(smartAlbum.title)")
    }

    /// 사용자 앨범 그리드 열기 (T052)
    private func openAlbumGrid(album: Album) {
        guard let fetchResult = albumService.fetchPhotosInAlbum(albumID: album.id) else {
            print("[AlbumsViewController] Failed to fetch photos for album: \(album.title)")
            return
        }

        let albumGridVC = AlbumGridViewController(
            albumTitle: album.title,
            fetchResult: fetchResult
        )

        navigationController?.pushViewController(albumGridVC, animated: true)

        print("[AlbumsViewController] Opened album: \(album.title)")
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

extension AlbumsViewController: PHPhotoLibraryChangeObserver {

    /// PhotoKit 변경 감지
    /// 앨범 추가/삭제, 사진 변경 등 감지하여 UI 갱신
    nonisolated func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 메인 스레드에서 UI 업데이트
        DispatchQueue.main.async { [weak self] in
            self?.loadData()
            print("[AlbumsViewController] PhotoLibrary changed, reloading data")
        }
    }
}

//
//  PreviewGridViewController.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  미리보기 그리드 메인 VC
//  - BaseGridViewController 상속 안 함 (PhotoCell + BannerCell 혼합 + 배열 기반)
//  - CompositionalLayout: 사진 섹션(3열) + 배너 섹션(전체 너비)
//  - 단계적 확장: "기준 낮춰서 더 보기" → 새 섹션 삽입 + 자동 스크롤
//  - 하단 고정 버튼: "N장 정리하기" / "빼고 M장만" / "기준 낮춰서 더 보기"
//

import UIKit
import Photos
import AppCore
import BlurUIKit

// MARK: - PreviewGridViewControllerDelegate

/// 미리보기 그리드 delegate
protocol PreviewGridViewControllerDelegate: AnyObject {
    /// 정리 확인 — assetIDs를 휴지통으로 이동
    func previewGridVC(_ vc: PreviewGridViewController, didConfirmCleanup assetIDs: [String])
}

// MARK: - SectionType

/// 섹션 타입 (사진 그리드 또는 배너)
private enum SectionType {
    case photos([PreviewCandidate])
    case banner(Int)  // addedCount
}

// MARK: - PreviewGridViewController

/// 미리보기 그리드 메인 VC
///
/// 분석 결과를 3열 그리드로 표시하며, 단계적 확장을 지원합니다.
/// PhotoCell은 기존 것을 재사용하고, BannerCell은 신규.
final class PreviewGridViewController: UIViewController {

    // MARK: - Properties

    /// 분석 결과
    private let previewResult: PreviewResult

    /// 현재 표시 단계
    private var currentStage: PreviewStage = .light

    /// delegate
    weak var delegate: PreviewGridViewControllerDelegate?

    // MARK: - Header (iOS 18 커스텀 헤더)

    /// iOS 18 커스텀 헤더 뷰 (FloatingOverlay 대체)
    private var customHeaderView: UIView?

    /// iOS 18 커스텀 헤더 타이틀 라벨
    private var headerTitleLabel: UILabel?

    /// iOS 18 커스텀 헤더 그라데이션 딤 레이어
    private var headerGradientLayer: CAGradientLayer?

    // MARK: - UI Elements

    /// 컬렉션뷰
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout())
        cv.backgroundColor = .systemBackground
        cv.dataSource = self
        cv.delegate = self
        cv.prefetchDataSource = self
        cv.translatesAutoresizingMaskIntoConstraints = false

        // 셀 등록
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.register(PreviewBannerCell.self, forCellWithReuseIdentifier: PreviewBannerCell.reuseIdentifier)

        return cv
    }()

    /// 하단 고정 버튼 영역
    private let bottomView = PreviewBottomView()

    // MARK: - Constants

    /// 셀 간격
    private let cellSpacing: CGFloat = 2.0

    /// 열 수
    private let columns: CGFloat = 3

    /// 배너 높이
    private let bannerHeight: CGFloat = 44

    // MARK: - Initialization

    init(previewResult: PreviewResult) {
        self.previewResult = previewResult
        super.init(nibName: nil, bundle: nil)

        // 탭바 숨김 (push 시 하단 탭 제거)
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateHeader()
        updateBottomView()
    }

    // MARK: - Setup

    private func setupUI() {
        view.backgroundColor = .systemBackground

        // 컬렉션뷰: 전체 화면 (헤더/하단 뷰 뒤에 깔림)
        view.addSubview(collectionView)

        // 헤더 설정 (iOS 26: 시스템 네비바, iOS 18: 블러 오버레이 헤더)
        // ⚠️ 컬렉션뷰 뒤에 addSubview되어야 오버레이가 위에 표시됨
        setupHeader()

        // 하단 버튼 영역
        bottomView.delegate = self
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)

        NSLayoutConstraint.activate([
            // 컬렉션뷰: 전체 화면 (헤더 아래로 콘텐츠 스크롤)
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            // 하단 뷰: 하단 고정
            bottomView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        // 하단 뷰 높이: contentHeight + safe area bottom
        let bottomHeight = PreviewBottomView.contentHeight + (view.safeAreaInsets.bottom > 0 ? 0 : 20)
        bottomView.heightAnchor.constraint(equalToConstant: bottomHeight).isActive = true

        // 컬렉션뷰 inset (상단 헤더 + 하단 버튼 가려지지 않도록)
        updateCollectionViewInsets()
    }

    // MARK: - Header Setup

    /// 헤더 설정 (iOS 버전별 분기)
    private func setupHeader() {
        if #available(iOS 26.0, *) {
            setupSystemNavHeader()
        } else {
            setupCustomHeader()
        }
    }

    /// iOS 26: 시스템 네비게이션 바에 X 버튼 설정
    @available(iOS 26.0, *)
    private func setupSystemNavHeader() {
        // 뒤로가기 버튼 숨기고 X 버튼으로 대체
        navigationItem.hidesBackButton = true
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(closeTapped)
        )
    }

    /// iOS 18: FloatingTitleBar와 동일한 블러+딤 오버레이 헤더
    /// - VariableBlurView (progressive blur, 상→하 페이드아웃)
    /// - CAGradientLayer (딤, 상→하 5단계 페이드)
    /// - 컬렉션뷰 위에 오버레이되어 콘텐츠가 아래로 스크롤됨
    private func setupCustomHeader() {
        // FloatingTitleBar 상수와 동일
        let contentHeight: CGFloat = 44
        let gradientExtension: CGFloat = 35
        let maxDimAlpha: CGFloat = LiquidGlassStyle.maxDimAlpha

        let header = UIView()
        header.translatesAutoresizingMaskIntoConstraints = false
        // 배경 투명 (블러+딤이 처리)
        header.backgroundColor = .clear
        view.addSubview(header)

        // Progressive blur (BlurUIKit) — FloatingTitleBar와 동일
        let progressiveBlurView = VariableBlurView()
        progressiveBlurView.translatesAutoresizingMaskIntoConstraints = false
        progressiveBlurView.direction = .down
        progressiveBlurView.maximumBlurRadius = 1.5
        progressiveBlurView.dimmingTintColor = UIColor.black
        progressiveBlurView.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
        header.addSubview(progressiveBlurView)

        // 그라데이션 딤 레이어 — FloatingTitleBar와 동일
        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor.black.withAlphaComponent(maxDimAlpha).cgColor,
            UIColor.black.withAlphaComponent(maxDimAlpha * 0.7).cgColor,
            UIColor.black.withAlphaComponent(maxDimAlpha * 0.3).cgColor,
            UIColor.black.withAlphaComponent(maxDimAlpha * 0.1).cgColor,
            UIColor.clear.cgColor
        ]
        gradientLayer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        gradientLayer.startPoint = CGPoint(x: 0.5, y: 0)
        gradientLayer.endPoint = CGPoint(x: 0.5, y: 1)
        header.layer.addSublayer(gradientLayer)
        self.headerGradientLayer = gradientLayer

        // X 버튼 (GlassIconButton — 앱 전체 통일 스타일)
        let closeButton = GlassIconButton(icon: "xmark", size: .medium, tintColor: .white)
        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.addTarget(self, action: #selector(closeTapped), for: .touchUpInside)
        header.addSubview(closeButton)

        // 타이틀 라벨 (흰색 — 딤 배경 위에 표시)
        let titleLabel = UILabel()
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        header.addSubview(titleLabel)

        NSLayoutConstraint.activate([
            // 헤더: safe area + contentHeight + gradientExtension (FloatingTitleBar와 동일)
            header.topAnchor.constraint(equalTo: view.topAnchor),
            header.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            header.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: contentHeight + gradientExtension
            ),

            // Progressive blur: 전체 + 8pt 넘침 (FloatingTitleBar와 동일)
            progressiveBlurView.topAnchor.constraint(equalTo: header.topAnchor),
            progressiveBlurView.leadingAnchor.constraint(equalTo: header.leadingAnchor),
            progressiveBlurView.trailingAnchor.constraint(equalTo: header.trailingAnchor),
            progressiveBlurView.bottomAnchor.constraint(equalTo: header.bottomAnchor, constant: 8),

            // X 버튼: 좌측, safe area 기준 (콘텐츠 영역 중앙)
            // GlassIconButton .medium = 44×44 (intrinsicContentSize로 크기 자동 결정)
            closeButton.leadingAnchor.constraint(equalTo: header.leadingAnchor, constant: 8),
            closeButton.centerYAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: contentHeight / 2  // 콘텐츠 높이 내 세로 중앙
            ),

            // 타이틀: 중앙, X 버튼과 같은 세로 위치
            titleLabel.centerXAnchor.constraint(equalTo: header.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: closeButton.centerYAnchor),
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
        ])

        self.customHeaderView = header
        self.headerTitleLabel = titleLabel
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCollectionViewInsets()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 그라데이션 딤 레이어 프레임 업데이트 (FloatingTitleBar와 동일 패턴)
        if let header = customHeaderView {
            headerGradientLayer?.frame = header.bounds
        }
    }

    /// 컬렉션뷰 inset 업데이트 (상단 헤더 + 하단 버튼 영역)
    private func updateCollectionViewInsets() {
        // 상단: iOS 18 커스텀 헤더 높이, iOS 26은 safe area가 자동 관리
        let topInset: CGFloat
        if let header = customHeaderView {
            topInset = header.frame.height > 0 ? header.frame.height : (view.safeAreaInsets.top + 52)
        } else {
            topInset = 0  // iOS 26: 시스템 네비바가 safe area 관리
        }

        // 하단: 버튼 영역 높이
        let bottomInset = PreviewBottomView.contentHeight + view.safeAreaInsets.bottom

        collectionView.contentInset = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
        collectionView.verticalScrollIndicatorInsets = UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }

    // MARK: - Layout

    /// CompositionalLayout 생성
    private func createLayout() -> UICollectionViewCompositionalLayout {
        return UICollectionViewCompositionalLayout { [weak self] sectionIndex, environment in
            guard let self = self else { return nil }

            let sectionType = self.sectionType(for: sectionIndex)

            switch sectionType {
            case .photos:
                return self.photosSection(environment: environment)
            case .banner:
                return self.bannerSection()
            }
        }
    }

    /// 사진 섹션 레이아웃 (3열 정사각형)
    private func photosSection(environment: NSCollectionLayoutEnvironment) -> NSCollectionLayoutSection {
        let totalSpacing = cellSpacing * (columns - 1)
        let availableWidth = environment.container.effectiveContentSize.width
        let cellWidth = floor((availableWidth - totalSpacing) / columns)
        let fraction = cellWidth / availableWidth

        // 아이템
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(fraction),
            heightDimension: .fractionalWidth(fraction)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        // 그룹 (가로 3개)
        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .fractionalWidth(fraction)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])
        group.interItemSpacing = .fixed(cellSpacing)

        // 섹션
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = cellSpacing
        return section
    }

    /// 배너 섹션 레이아웃 (전체 너비 1행)
    private func bannerSection() -> NSCollectionLayoutSection {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(bannerHeight)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)

        let groupSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1.0),
            heightDimension: .absolute(bannerHeight)
        )
        let group = NSCollectionLayoutGroup.horizontal(layoutSize: groupSize, subitems: [item])

        let section = NSCollectionLayoutSection(group: group)
        section.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0)
        return section
    }

    // MARK: - Section Mapping

    /// 섹션 수 (currentStage에 따라 동적)
    private var numberOfSections: Int {
        switch currentStage {
        case .light:
            return 1  // 사진만
        case .standard:
            return 3  // 사진, 배너, 사진
        case .deep:
            return 5  // 사진, 배너, 사진, 배너, 사진
        }
    }

    /// 섹션 인덱스에 대한 섹션 타입
    private func sectionType(for sectionIndex: Int) -> SectionType {
        switch sectionIndex {
        case 0:
            return .photos(previewResult.lightCandidates)
        case 1:
            return .banner(previewResult.standardCount)
        case 2:
            return .photos(previewResult.standardCandidates)
        case 3:
            return .banner(previewResult.deepCount)
        case 4:
            return .photos(previewResult.deepCandidates)
        default:
            return .photos([])
        }
    }

    /// 섹션의 후보 배열 반환 (사진 섹션인 경우)
    private func candidates(for sectionIndex: Int) -> [PreviewCandidate]? {
        switch sectionType(for: sectionIndex) {
        case .photos(let candidates):
            return candidates
        case .banner:
            return nil
        }
    }

    // MARK: - Thumbnail

    /// 썸네일 크기 계산
    private func thumbnailSize() -> CGSize {
        let scale = UIScreen.main.scale
        let totalSpacing = cellSpacing * (columns - 1)
        let cellWidth = floor((collectionView.bounds.width - totalSpacing) / columns)
        return CGSize(width: cellWidth * scale, height: cellWidth * scale)
    }

    // MARK: - Header & Bottom Update

    /// 헤더 제목 업데이트
    private func updateHeader() {
        let count = previewResult.count(upToStage: currentStage)
        let titleText = "저품질 사진 \(count)장"

        // iOS 26: 시스템 네비바 타이틀
        title = titleText
        // iOS 18: 커스텀 헤더 라벨
        headerTitleLabel?.text = titleText
    }

    /// 하단 버튼 영역 업데이트
    private func updateBottomView() {
        let totalCount = previewResult.count(upToStage: currentStage)

        // 이전 단계 개수 (1단계면 nil)
        let previousStageCount: Int?
        switch currentStage {
        case .light:
            previousStageCount = nil
        case .standard:
            previousStageCount = previewResult.lightCount
        case .deep:
            previousStageCount = previewResult.count(upToStage: .standard)
        }

        // 확장 가능 여부: 다음 단계가 있고 + 추가분이 있고 + iOS 18 이상
        let canExpand: Bool
        if currentStage >= .deep {
            canExpand = false
        } else if currentStage == .light && previewResult.standardCount == 0 {
            canExpand = false
        } else if currentStage == .standard && previewResult.deepCount == 0 {
            canExpand = false
        } else {
            // iOS 16~17에서는 path2가 없어서 standard/deep이 빈 배열 → 확장 불가
            if #available(iOS 18.0, *) {
                canExpand = true
            } else {
                canExpand = false
            }
        }

        bottomView.configure(
            currentStage: currentStage,
            totalCount: totalCount,
            previousStageCount: previousStageCount,
            canExpand: canExpand
        )
    }

    // MARK: - Close Action

    /// X 버튼 탭 — 실수 방지 확인 Alert
    @objc private func closeTapped() {
        let alert = UIAlertController(
            title: "분석 결과를 닫으시겠습니까?",
            message: "현재 화면을 닫으면 분석 결과가 사라집니다.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "닫기", style: .destructive) { [weak self] _ in
            self?.navigationController?.popViewController(animated: true)
        })

        present(alert, animated: true)
    }

    // MARK: - Viewer

    /// 현재 표시 중인 모든 사진 (뷰어용 flat 배열)
    private func allVisibleAssets() -> [PHAsset] {
        var assets: [PHAsset] = []
        assets.append(contentsOf: previewResult.lightCandidates.map(\.asset))
        if currentStage >= .standard {
            assets.append(contentsOf: previewResult.standardCandidates.map(\.asset))
        }
        if currentStage >= .deep {
            assets.append(contentsOf: previewResult.deepCandidates.map(\.asset))
        }
        return assets
    }

    // MARK: - Cleanup Actions

    /// 정리 확인 Alert 표시
    private func showCleanupConfirmation(assetIDs: [String]) {
        let alert = UIAlertController(
            title: "\(assetIDs.count)장을 정리할까요?",
            message: "선택한 사진이 휴지통으로 이동됩니다.",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "정리하기", style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.delegate?.previewGridVC(self, didConfirmCleanup: assetIDs)
            self.navigationController?.popViewController(animated: true)
        })

        present(alert, animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension PreviewGridViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return numberOfSections
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        switch sectionType(for: section) {
        case .photos(let candidates):
            return candidates.count
        case .banner:
            return 1
        }
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        switch sectionType(for: indexPath.section) {
        case .photos(let candidates):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PhotoCell.reuseIdentifier,
                for: indexPath
            ) as! PhotoCell

            let candidate = candidates[indexPath.item]
            cell.configure(
                asset: candidate.asset,
                isTrashed: false,
                targetSize: thumbnailSize()
            )
            return cell

        case .banner(let addedCount):
            let cell = collectionView.dequeueReusableCell(
                withReuseIdentifier: PreviewBannerCell.reuseIdentifier,
                for: indexPath
            ) as! PreviewBannerCell

            cell.configure(addedCount: addedCount)
            return cell
        }
    }
}

// MARK: - UICollectionViewDelegate

extension PreviewGridViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)

        // 배너 셀은 무시
        guard case .photos(let candidates) = sectionType(for: indexPath.section),
              indexPath.item < candidates.count else { return }

        // 탭한 사진의 flat 배열 내 인덱스 계산
        let allAssets = allVisibleAssets()
        let tappedAssetID = candidates[indexPath.item].assetID
        guard let viewerIndex = allAssets.firstIndex(where: { $0.localIdentifier == tappedAssetID }) else { return }

        // 뷰어 push (미리보기 전용 코디네이터 사용)
        let coordinator = PreviewViewerCoordinator(assets: allAssets)
        let viewerVC = ViewerViewController(coordinator: coordinator, startIndex: viewerIndex)
        navigationController?.pushViewController(viewerVC, animated: true)
    }
}

// MARK: - UICollectionViewDataSourcePrefetching

extension PreviewGridViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        let assetIDs = indexPaths.compactMap { ip -> String? in
            guard let candidates = candidates(for: ip.section),
                  ip.item < candidates.count else { return nil }
            return candidates[ip.item].assetID
        }

        guard !assetIDs.isEmpty else { return }
        ImagePipeline.shared.preheat(assetIDs: assetIDs, targetSize: thumbnailSize())
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        let assetIDs = indexPaths.compactMap { ip -> String? in
            guard let candidates = candidates(for: ip.section),
                  ip.item < candidates.count else { return nil }
            return candidates[ip.item].assetID
        }

        guard !assetIDs.isEmpty else { return }
        ImagePipeline.shared.stopPreheating(assetIDs: assetIDs)
    }
}

// MARK: - BarsVisibilityControlling

extension PreviewGridViewController: BarsVisibilityControlling {
    /// iOS 18: FloatingOverlay 숨김 (자체 네비바 사용)
    var prefersFloatingOverlayHidden: Bool? { true }

    /// iOS 26: 시스템 탭바 숨김
    var prefersSystemTabBarHidden: Bool? { true }
}

// MARK: - PreviewBottomViewDelegate

extension PreviewGridViewController: PreviewBottomViewDelegate {

    func previewBottomViewDidTapCleanup(_ view: PreviewBottomView) {
        // 현재 단계까지의 모든 assetIDs
        let assetIDs = previewResult.assetIDs(upToStage: currentStage)
        showCleanupConfirmation(assetIDs: assetIDs)
    }

    func previewBottomViewDidTapExclude(_ view: PreviewBottomView) {
        // 이전 단계까지만 정리 (현재 단계 추가분 제외)
        let previousStage: PreviewStage
        switch currentStage {
        case .standard:
            previousStage = .light
        case .deep:
            previousStage = .standard
        default:
            return
        }

        let assetIDs = previewResult.assetIDs(upToStage: previousStage)
        showCleanupConfirmation(assetIDs: assetIDs)
    }

    func previewBottomViewDidTapExpand(_ view: PreviewBottomView) {
        guard let nextStage = currentStage.next else { return }

        // 1. currentStage 변경 (numberOfSections 먼저 업데이트되도록)
        currentStage = nextStage

        // 2. 새 섹션 삽입
        collectionView.performBatchUpdates {
            let newSections: IndexSet
            switch nextStage {
            case .standard:
                newSections = IndexSet([1, 2])
            case .deep:
                newSections = IndexSet([3, 4])
            default:
                return
            }
            collectionView.insertSections(newSections)
        } completion: { [weak self] _ in
            guard let self = self else { return }

            // 3. 배너 위치로 자동 스크롤
            let bannerSection: Int
            switch nextStage {
            case .standard:
                bannerSection = 1
            case .deep:
                bannerSection = 3
            default:
                return
            }

            self.collectionView.scrollToItem(
                at: IndexPath(item: 0, section: bannerSection),
                at: .top,
                animated: true
            )
        }

        // 4. 하단 버튼 + 헤더 업데이트
        updateBottomView()
        updateHeader()
    }
}

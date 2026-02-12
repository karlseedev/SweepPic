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
        title = "정리 미리보기"

        // 컬렉션뷰
        view.addSubview(collectionView)

        // 하단 버튼 영역
        bottomView.delegate = self
        bottomView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(bottomView)

        NSLayoutConstraint.activate([
            // 컬렉션뷰: 전체 화면
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

        // 컬렉션뷰 하단 inset (하단 뷰에 사진이 가려지지 않도록)
        updateCollectionViewInsets()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateCollectionViewInsets()
    }

    /// 컬렉션뷰 하단 inset 업데이트
    private func updateCollectionViewInsets() {
        let bottomInset = PreviewBottomView.contentHeight + view.safeAreaInsets.bottom
        collectionView.contentInset.bottom = bottomInset
        collectionView.verticalScrollIndicatorInsets.bottom = bottomInset
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
        title = "저품질 사진 \(count)장"
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
        // MVP: 사진 탭 시 전체화면 보기는 추후 구현
        // 현재는 선택 해제만
        collectionView.deselectItem(at: indexPath, animated: true)
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

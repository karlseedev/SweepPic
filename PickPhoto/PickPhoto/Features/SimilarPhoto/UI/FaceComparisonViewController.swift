//
//  FaceComparisonViewController.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  얼굴 비교 화면입니다.
//  유사 사진 그룹에서 동일 인물의 얼굴을 2열 그리드로 비교하고 삭제합니다.
//
//  주요 기능:
//  - 2열 정사각형 그리드로 크롭된 얼굴 이미지 표시
//  - 헤더: "인물 N (M장)" 형식
//  - 순환 버튼으로 다음 인물 전환 (선택 상태 유지)
//  - 사진 탭으로 선택/해제 토글, 체크마크 표시
//  - Delete 탭 시 휴지통 이동 + 뷰어 복귀
//  - 기존 Undo 기능과 통합
//
//  UI 구성:
//  - iOS 16~25: 커스텀 FloatingTitleBar (캡슐 스타일)
//  - iOS 26+: 시스템 네비게이션바 (Liquid Glass)
//  - 하단바: 선택 개수 + Cancel/Delete 버튼
//

import UIKit
import Photos
import AppCore

// MARK: - FaceComparisonDelegate

/// 얼굴 비교 화면 델리게이트
/// 삭제/닫기 이벤트를 전달합니다.
protocol FaceComparisonDelegate: AnyObject {
    /// 사진 삭제 완료 시 호출
    /// - Parameters:
    ///   - viewController: FaceComparisonViewController
    ///   - deletedAssetIDs: 삭제된 사진 ID 배열
    func faceComparisonViewController(
        _ viewController: FaceComparisonViewController,
        didDeletePhotos deletedAssetIDs: [String]
    )

    /// 화면 닫기 시 호출
    /// - Parameter viewController: FaceComparisonViewController
    func faceComparisonViewControllerDidClose(_ viewController: FaceComparisonViewController)
}

// MARK: - FaceComparisonViewController

/// 얼굴 비교 화면
///
/// 유사 사진 뷰어에서 +버튼 탭 시 표시됩니다.
/// 동일 인물의 얼굴을 2열 그리드로 비교하고, 원하지 않는 사진을 선택하여 삭제할 수 있습니다.
///
/// - Note: ComparisonGroup에서 최대 8장까지 표시됩니다.
final class FaceComparisonViewController: UIViewController {

    // MARK: - Constants

    /// 그리드 간격 (상하좌우)
    private static let gridSpacing: CGFloat = 2

    /// 최소 셀 크기 (화면이 너무 작을 때 보장)
    private static let minCellSize: CGFloat = 100

    /// 하단바 높이
    private static let bottomBarHeight: CGFloat = 56

    // MARK: - Properties

    /// 비교 그룹 (현재 표시 중인 인물 기준)
    private var comparisonGroup: ComparisonGroup

    /// 유효 인물 번호 목록 (순환용)
    /// - 그룹 내에서 2장 이상 감지된 인물만 포함
    private var validPersonIndices: [Int] = []

    /// 현재 표시 중인 인물 인덱스 (validPersonIndices 배열 내 인덱스)
    private var currentPersonArrayIndex: Int = 0

    /// 현재 인물 번호
    private var currentPersonIndex: Int {
        guard currentPersonArrayIndex < validPersonIndices.count else {
            return comparisonGroup.personIndex
        }
        return validPersonIndices[currentPersonArrayIndex]
    }

    /// 사진별 얼굴 정보 (assetID → [CachedFace])
    private var photoFaces: [String: [CachedFace]] = [:]

    /// 선택된 사진 ID 집합
    private var selectedAssetIDs: Set<String> = []

    /// PHFetchResult (이미지 로딩용)
    private let fetchResult: PHFetchResult<PHAsset>?

    /// 이미지 로더
    private let imageManager = PHCachingImageManager()

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol

    /// 델리게이트
    weak var delegate: FaceComparisonDelegate?

    // MARK: - UI Components

    /// 컬렉션 뷰 (2열 그리드)
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = Self.gridSpacing
        layout.minimumLineSpacing = Self.gridSpacing

        let cv = UICollectionView(frame: .zero, collectionViewLayout: layout)
        cv.backgroundColor = .black
        cv.register(FaceComparisonCell.self, forCellWithReuseIdentifier: FaceComparisonCell.reuseIdentifier)
        cv.register(
            FaceComparisonHeaderView.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: FaceComparisonHeaderView.reuseIdentifier
        )
        cv.dataSource = self
        cv.delegate = self
        cv.contentInsetAdjustmentBehavior = .automatic
        cv.translatesAutoresizingMaskIntoConstraints = false
        return cv
    }()

    /// 하단바 컨테이너
    private lazy var bottomBarContainer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.8)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 하단바 블러 효과
    private lazy var bottomBarBlur: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Cancel 버튼
    private lazy var cancelButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.title = "Cancel"
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 선택 개수 라벨
    private lazy var selectionCountLabel: UILabel = {
        let label = UILabel()
        label.text = "항목 선택"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Delete 버튼
    private lazy var deleteButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Delete"
        config.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        button.isEnabled = false
        button.alpha = 0.5
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 커스텀 타이틀바 (iOS 16~25)
    private var customTitleBar: FaceComparisonTitleBar?

    // MARK: - Initialization

    /// FaceComparisonViewController를 생성합니다.
    ///
    /// - Parameters:
    ///   - comparisonGroup: 비교할 사진 그룹
    ///   - fetchResult: PHFetchResult (이미지 로딩용)
    ///   - trashStore: 휴지통 스토어 (기본값: TrashStore.shared)
    init(
        comparisonGroup: ComparisonGroup,
        fetchResult: PHFetchResult<PHAsset>?,
        trashStore: TrashStoreProtocol = TrashStore.shared
    ) {
        self.comparisonGroup = comparisonGroup
        self.fetchResult = fetchResult
        self.trashStore = trashStore
        super.init(nibName: nil, bundle: nil)

        // 모달 스타일 설정
        modalPresentationStyle = .fullScreen
        modalTransitionStyle = .coverVertical
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .black

        setupUI()
        loadPhotoFaces()
        loadValidPersonIndices()

        print("[FaceComparisonViewController] Loaded with \(comparisonGroup.count) photos, person \(comparisonGroup.personIndex)")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // iOS 26+: 시스템 네비게이션바 설정
        if #available(iOS 26.0, *) {
            setupSystemNavigationBar()
        }
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)

        // 화면 회전 시 레이아웃 갱신
        coordinator.animate { _ in
            self.collectionView.collectionViewLayout.invalidateLayout()
        }
    }

    // MARK: - Setup

    /// UI 구성
    private func setupUI() {
        // iOS 16~25: 커스텀 타이틀바
        if #available(iOS 26.0, *) {
            // iOS 26+는 viewWillAppear에서 시스템 네비게이션바 설정
            setupCollectionViewWithSystemNav()
        } else {
            setupCustomTitleBar()
            setupCollectionViewWithCustomNav()
        }

        setupBottomBar()
    }

    /// 커스텀 타이틀바 설정 (iOS 16~25)
    private func setupCustomTitleBar() {
        let titleBar = FaceComparisonTitleBar()
        titleBar.translatesAutoresizingMaskIntoConstraints = false
        titleBar.delegate = self
        view.addSubview(titleBar)

        NSLayoutConstraint.activate([
            titleBar.topAnchor.constraint(equalTo: view.topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            titleBar.heightAnchor.constraint(equalToConstant: view.safeAreaInsets.top + 44 + 15)
        ])

        customTitleBar = titleBar
        updateTitleBar()
    }

    /// 컬렉션 뷰 설정 (커스텀 네비게이션)
    private func setupCollectionViewWithCustomNav() {
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Self.bottomBarHeight - view.safeAreaInsets.bottom)
        ])
    }

    /// 컬렉션 뷰 설정 (시스템 네비게이션)
    private func setupCollectionViewWithSystemNav() {
        view.addSubview(collectionView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -Self.bottomBarHeight - view.safeAreaInsets.bottom)
        ])
    }

    /// 시스템 네비게이션바 설정 (iOS 26+)
    @available(iOS 26.0, *)
    private func setupSystemNavigationBar() {
        // 타이틀
        updateNavigationTitle()

        // 순환 버튼 (우측)
        let cycleButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90"),
            style: .plain,
            target: self,
            action: #selector(cycleButtonTapped)
        )
        cycleButton.tintColor = .white
        navigationItem.rightBarButtonItem = cycleButton
    }

    /// 하단바 설정
    private func setupBottomBar() {
        view.addSubview(bottomBarContainer)
        bottomBarContainer.addSubview(bottomBarBlur)
        bottomBarContainer.addSubview(cancelButton)
        bottomBarContainer.addSubview(selectionCountLabel)
        bottomBarContainer.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            // 하단바 컨테이너
            bottomBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBarContainer.heightAnchor.constraint(equalToConstant: Self.bottomBarHeight + view.safeAreaInsets.bottom),

            // 블러 효과
            bottomBarBlur.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor),
            bottomBarBlur.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor),
            bottomBarBlur.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor),
            bottomBarBlur.bottomAnchor.constraint(equalTo: bottomBarContainer.bottomAnchor),

            // Cancel 버튼 (좌측)
            cancelButton.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor, constant: 16),
            cancelButton.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor, constant: 8),

            // 선택 개수 라벨 (중앙)
            selectionCountLabel.centerXAnchor.constraint(equalTo: bottomBarContainer.centerXAnchor),
            selectionCountLabel.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor, constant: 16),

            // Delete 버튼 (우측)
            deleteButton.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor, constant: -16),
            deleteButton.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor, constant: 8)
        ])
    }

    // MARK: - Data Loading

    /// 사진별 얼굴 정보 로드
    private func loadPhotoFaces() {
        Task { @MainActor in
            for assetID in comparisonGroup.selectedAssetIDs {
                let faces = await SimilarityCache.shared.getFaces(for: assetID)
                photoFaces[assetID] = faces
            }
            collectionView.reloadData()
        }
    }

    /// 유효 인물 목록 로드
    private func loadValidPersonIndices() {
        Task { @MainActor in
            let validSlots = await SimilarityCache.shared.getGroupValidPersonIndices(for: comparisonGroup.sourceGroupID)
            validPersonIndices = validSlots.sorted()

            // 현재 인물의 인덱스 찾기
            if let index = validPersonIndices.firstIndex(of: comparisonGroup.personIndex) {
                currentPersonArrayIndex = index
            }

            updateTitleBar()
        }
    }

    // MARK: - UI Updates

    /// 타이틀바 업데이트
    private func updateTitleBar() {
        let photosForCurrentPerson = photosForPerson(currentPersonIndex)
        let title = "인물 \(currentPersonIndex) (\(photosForCurrentPerson.count)장)"

        if #available(iOS 26.0, *) {
            self.title = title
        } else {
            customTitleBar?.setTitle(title)
        }
    }

    /// 네비게이션 타이틀 업데이트 (iOS 26+)
    @available(iOS 26.0, *)
    private func updateNavigationTitle() {
        let photosForCurrentPerson = photosForPerson(currentPersonIndex)
        self.title = "인물 \(currentPersonIndex) (\(photosForCurrentPerson.count)장)"
    }

    /// 선택 개수 업데이트
    private func updateSelectionCount() {
        let count = selectedAssetIDs.count

        if count > 0 {
            selectionCountLabel.text = "\(count)개 선택됨"
            deleteButton.isEnabled = true
            deleteButton.alpha = 1.0
        } else {
            selectionCountLabel.text = "항목 선택"
            deleteButton.isEnabled = false
            deleteButton.alpha = 0.5
        }
    }

    // MARK: - Helpers

    /// 특정 인물의 사진 목록 반환
    private func photosForPerson(_ personIndex: Int) -> [String] {
        return comparisonGroup.selectedAssetIDs.filter { assetID in
            guard let faces = photoFaces[assetID] else { return false }
            return faces.contains { $0.personIndex == personIndex }
        }
    }

    /// PHAsset 가져오기
    private func asset(for assetID: String) -> PHAsset? {
        guard let fetchResult = fetchResult else { return nil }

        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            if asset.localIdentifier == assetID {
                return asset
            }
        }
        return nil
    }

    // MARK: - Actions

    /// Cancel 버튼 탭
    @objc private func cancelButtonTapped() {
        print("[FaceComparisonViewController] Cancel tapped")

        // 선택 해제
        selectedAssetIDs.removeAll()

        // 화면 닫기
        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.faceComparisonViewControllerDidClose(self)
        }
    }

    /// Delete 버튼 탭
    @objc private func deleteButtonTapped() {
        guard !selectedAssetIDs.isEmpty else { return }

        print("[FaceComparisonViewController] Delete tapped: \(selectedAssetIDs.count) photos")

        let deletedIDs = Array(selectedAssetIDs)

        // TrashStore에 이동
        trashStore.moveToTrash(assetIDs: deletedIDs)

        // 캐시에서 그룹 업데이트
        Task { @MainActor in
            for assetID in deletedIDs {
                _ = await SimilarityCache.shared.removeMemberFromGroup(assetID, groupID: comparisonGroup.sourceGroupID)
            }

            // 선택 상태 초기화
            selectedAssetIDs.removeAll()

            // 화면 닫기 및 델리게이트 호출
            dismiss(animated: true) { [weak self] in
                guard let self = self else { return }
                self.delegate?.faceComparisonViewController(self, didDeletePhotos: deletedIDs)
            }
        }
    }

    /// 순환 버튼 탭
    @objc private func cycleButtonTapped() {
        guard validPersonIndices.count > 1 else { return }

        // 다음 인물로 이동 (원형 순환)
        currentPersonArrayIndex = (currentPersonArrayIndex + 1) % validPersonIndices.count

        print("[FaceComparisonViewController] Cycled to person \(currentPersonIndex)")

        // UI 갱신 (선택 상태 유지)
        updateTitleBar()
        collectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource

extension FaceComparisonViewController: UICollectionViewDataSource {

    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return photosForPerson(currentPersonIndex).count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: FaceComparisonCell.reuseIdentifier,
            for: indexPath
        ) as? FaceComparisonCell else {
            return UICollectionViewCell()
        }

        let photos = photosForPerson(currentPersonIndex)
        guard indexPath.item < photos.count else { return cell }

        let assetID = photos[indexPath.item]

        // 얼굴 bounding box 가져오기
        let face = photoFaces[assetID]?.first { $0.personIndex == currentPersonIndex }

        // 선택 상태
        let isSelected = selectedAssetIDs.contains(assetID)

        // 이미지 로드 및 얼굴 크롭
        if let asset = asset(for: assetID), let boundingBox = face?.boundingBox {
            loadCroppedFaceImage(for: asset, boundingBox: boundingBox) { image in
                DispatchQueue.main.async {
                    cell.configure(with: image, isSelected: isSelected, assetID: assetID)
                }
            }
        } else {
            cell.configure(with: nil, isSelected: isSelected, assetID: assetID)
        }

        return cell
    }

    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        guard kind == UICollectionView.elementKindSectionHeader else {
            return UICollectionReusableView()
        }

        guard let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: FaceComparisonHeaderView.reuseIdentifier,
            for: indexPath
        ) as? FaceComparisonHeaderView else {
            return UICollectionReusableView()
        }

        // iOS 16~25: 헤더에 타이틀 표시
        if #unavailable(iOS 26.0) {
            let photos = photosForPerson(currentPersonIndex)
            header.configure(
                title: "인물 \(currentPersonIndex) (\(photos.count)장)",
                showsCycleButton: validPersonIndices.count > 1
            )
            header.onCycleButtonTapped = { [weak self] in
                self?.cycleButtonTapped()
            }
        }

        return header
    }

    /// 크롭된 얼굴 이미지 로드
    private func loadCroppedFaceImage(
        for asset: PHAsset,
        boundingBox: CGRect,
        completion: @escaping (UIImage?) -> Void
    ) {
        // 셀 크기 계산 (2열)
        let cellWidth = (view.bounds.width - Self.gridSpacing) / 2
        let targetSize = CGSize(width: cellWidth * UIScreen.main.scale, height: cellWidth * UIScreen.main.scale)

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isSynchronous = false

        imageManager.requestImage(
            for: asset,
            targetSize: CGSize(width: asset.pixelWidth, height: asset.pixelHeight),
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            guard let image = image else {
                completion(nil)
                return
            }

            // 얼굴 크롭
            do {
                let croppedImage = try FaceCropper.cropFace(from: image, boundingBox: boundingBox)
                completion(croppedImage)
            } catch {
                print("[FaceComparisonViewController] Failed to crop face: \(error)")
                completion(nil)
            }
        }
    }
}

// MARK: - UICollectionViewDelegate

extension FaceComparisonViewController: UICollectionViewDelegate {

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let photos = photosForPerson(currentPersonIndex)
        guard indexPath.item < photos.count else { return }

        let assetID = photos[indexPath.item]

        // 선택 토글
        if selectedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
        } else {
            selectedAssetIDs.insert(assetID)
        }

        // 셀 UI 업데이트
        if let cell = collectionView.cellForItem(at: indexPath) as? FaceComparisonCell {
            cell.setSelected(selectedAssetIDs.contains(assetID))
        }

        // 선택 개수 업데이트
        updateSelectionCount()

        print("[FaceComparisonViewController] Toggled selection for \(assetID.prefix(8))..., now \(selectedAssetIDs.count) selected")
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension FaceComparisonViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        // 2열 정사각형
        let width = (collectionView.bounds.width - Self.gridSpacing) / 2
        let size = max(width, Self.minCellSize)
        return CGSize(width: size, height: size)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        // iOS 16~25: 헤더 표시
        if #unavailable(iOS 26.0) {
            return CGSize(width: collectionView.bounds.width, height: 50)
        }
        return .zero
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        insetForSectionAt section: Int
    ) -> UIEdgeInsets {
        return UIEdgeInsets(top: Self.gridSpacing, left: 0, bottom: Self.gridSpacing, right: 0)
    }
}

// MARK: - FaceComparisonTitleBarDelegate

extension FaceComparisonViewController: FaceComparisonTitleBarDelegate {

    func faceComparisonTitleBarDidTapCycle(_ titleBar: FaceComparisonTitleBar) {
        cycleButtonTapped()
    }

    func faceComparisonTitleBarDidTapClose(_ titleBar: FaceComparisonTitleBar) {
        cancelButtonTapped()
    }
}

// MARK: - FaceComparisonCell

/// 얼굴 비교 셀
///
/// 크롭된 얼굴 이미지를 표시하고, 선택 시 체크마크 오버레이를 표시합니다.
final class FaceComparisonCell: UICollectionViewCell {

    static let reuseIdentifier = "FaceComparisonCell"

    // MARK: - Properties

    /// 현재 셀의 assetID
    private(set) var assetID: String?

    // MARK: - UI Components

    /// 얼굴 이미지 뷰
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.darkGray.withAlphaComponent(0.5)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// 선택 오버레이
    private lazy var selectionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 체크마크 이미지
    private lazy var checkmarkView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        iv.tintColor = .systemBlue
        iv.backgroundColor = .white
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(imageView)
        contentView.addSubview(selectionOverlay)
        contentView.addSubview(checkmarkView)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkmarkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmarkView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkView.heightAnchor.constraint(equalToConstant: 24)
        ])
    }

    // MARK: - Configuration

    /// 셀 구성
    func configure(with image: UIImage?, isSelected: Bool, assetID: String) {
        self.assetID = assetID
        imageView.image = image
        setSelected(isSelected)
    }

    /// 선택 상태 설정
    func setSelected(_ selected: Bool) {
        selectionOverlay.isHidden = !selected
        checkmarkView.isHidden = !selected
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        assetID = nil
        setSelected(false)
    }
}

// MARK: - FaceComparisonHeaderView

/// 얼굴 비교 헤더 뷰 (iOS 16~25)
///
/// 인물 번호와 순환 버튼을 표시합니다.
final class FaceComparisonHeaderView: UICollectionReusableView {

    static let reuseIdentifier = "FaceComparisonHeaderView"

    // MARK: - Properties

    var onCycleButtonTapped: (() -> Void)?

    // MARK: - UI Components

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var cycleButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
        config.baseForegroundColor = .systemBlue
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(cycleButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(titleLabel)
        addSubview(cycleButton)

        NSLayoutConstraint.activate([
            titleLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            cycleButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            cycleButton.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    // MARK: - Configuration

    func configure(title: String, showsCycleButton: Bool) {
        titleLabel.text = title
        cycleButton.isHidden = !showsCycleButton
    }

    // MARK: - Actions

    @objc private func cycleButtonTapped() {
        onCycleButtonTapped?()
    }
}

// MARK: - FaceComparisonTitleBar

/// 얼굴 비교 타이틀바 (iOS 16~25)
///
/// 상단에 블러 배경 + 타이틀 + 순환 버튼을 표시합니다.
protocol FaceComparisonTitleBarDelegate: AnyObject {
    func faceComparisonTitleBarDidTapCycle(_ titleBar: FaceComparisonTitleBar)
    func faceComparisonTitleBarDidTapClose(_ titleBar: FaceComparisonTitleBar)
}

final class FaceComparisonTitleBar: UIView {

    // MARK: - Properties

    weak var delegate: FaceComparisonTitleBarDelegate?

    // MARK: - UI Components

    private lazy var blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var cycleButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
        config.baseForegroundColor = .systemBlue
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(cycleButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(blurView)
        addSubview(contentView)
        contentView.addSubview(closeButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(cycleButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.heightAnchor.constraint(equalToConstant: 44),

            closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            cycleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cycleButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    // MARK: - Configuration

    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapClose(self)
    }

    @objc private func cycleButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapCycle(self)
    }
}

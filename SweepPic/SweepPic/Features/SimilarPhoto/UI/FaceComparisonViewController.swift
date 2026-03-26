//
//  FaceComparisonViewController.swift
//  SweepPic
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 SweepPic. All rights reserved.
//
//  Description:
//  얼굴 비교 화면입니다.
//  유사 사진 그룹에서 동일 인물의 얼굴을 2열 그리드로 비교하고 삭제합니다.
//
//  주요 기능:
//  - UIPageViewController로 인물별 페이지 스와이프 전환
//  - 2열 정사각형 그리드로 크롭된 얼굴 이미지 표시
//  - 헤더: "인물 N (M장)" 형식
//  - 순환 버튼으로 다음 인물 전환 (선택 상태 유지)
//  - 사진 탭으로 선택/해제 토글, 체크마크 표시
//  - Delete 탭 시 삭제대기함 이동 + 뷰어 복귀
//
//  UI 구성:
//  - iOS 16~25: 커스텀 FloatingTitleBar (캡슐 스타일)
//  - iOS 26+: 시스템 네비게이션바 (Liquid Glass)
//  - 하단바: 선택 개수 + Cancel/Delete 버튼
//

import UIKit
import Photos
import Vision
import AppCore
import BlurUIKit

// MARK: - FaceComparisonDelegate

/// 얼굴 비교 화면 델리게이트
/// 삭제/닫기 이벤트를 전달합니다.
protocol FaceComparisonDelegate: AnyObject {
    /// 사진 삭제 완료 시 호출
    func faceComparisonViewController(
        _ viewController: FaceComparisonViewController,
        didDeletePhotos deletedAssetIDs: [String]
    )

    /// 화면 닫기 시 호출
    func faceComparisonViewControllerDidClose(_ viewController: FaceComparisonViewController)
}

// MARK: - FaceComparisonViewController

/// 얼굴 비교 화면
///
/// 유사 사진 뷰어에서 +버튼 탭 시 표시됩니다.
/// UIPageViewController를 사용하여 인물별 페이지를 스와이프로 전환할 수 있습니다.
///
/// - Note: ComparisonGroup에서 최대 8장까지 표시됩니다.
final class FaceComparisonViewController: UIViewController {

    // MARK: - Constants

    /// 하단바 높이
    private static let bottomBarHeight: CGFloat = 56

    /// 하단 그라데이션 확장 높이
    private static let bottomBarGradientExtension: CGFloat = 15

    // MARK: - Properties

    /// 비교 그룹 (현재 표시 중인 인물 기준)
    private var comparisonGroup: ComparisonGroup

    /// 그룹 전체 사진 수 (analytics용)
    var totalPhotoCount: Int { comparisonGroup.selectedAssetIDs.count }

    /// 유효 인물 번호 목록 (순환용)
    /// - 그룹 내에서 2장 이상 감지된 인물만 포함
    private(set) var validPersonIndices: [Int] = []

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

    /// 사진 번호 맵 (assetID → 1-based 순서)
    /// SimilarThumbnailGroup.memberAssetIDs 기반으로, 뷰어와 동일한 번호를 보장합니다.
    private var memberNumberMap: [String: Int] = [:]

    /// 선택된 사진 ID 집합
    private var selectedAssetIDs: Set<String> = []

    /// PHAsset 캐시 (assetID → PHAsset, O(1) 조회용)
    private var assetCache: [String: PHAsset] = [:]

    /// 이미지 로더
    private let imageManager = PHCachingImageManager()

    /// 삭제대기함 스토어
    private let trashStore: TrashStoreProtocol

    /// 유사 사진 캐시
    private let cache: any SimilarityCacheProtocol

    /// 델리게이트
    weak var delegate: FaceComparisonDelegate?

    /// 데이터 로딩 완료 여부
    private var isPhotoFacesLoaded = false
    private var isValidPersonIndicesLoaded = false

    /// 데이터 준비 완료 여부
    private var isDataReady: Bool {
        return isPhotoFacesLoaded && isValidPersonIndicesLoaded
    }

    // MARK: - UI Components

    /// 페이지 뷰 컨트롤러 (인물별 페이지 전환)
    private lazy var pageViewController: UIPageViewController = {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: nil
        )
        pvc.dataSource = self
        pvc.delegate = self
        pvc.view.translatesAutoresizingMaskIntoConstraints = false
        return pvc
    }()

    /// 하단바 컨테이너
    private lazy var bottomBarContainer: FaceComparisonBottomBar = {
        let view = FaceComparisonBottomBar()
        view.backgroundColor = .clear
        view.insetsLayoutMarginsFromSafeArea = false
        view.layoutMargins = UIEdgeInsets(top: Self.bottomBarGradientExtension, left: 0, bottom: 0, right: 0)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 하단바 progressive blur
    private lazy var bottomProgressiveBlurView: VariableBlurView = {
        let view = VariableBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.direction = .up
        view.maximumBlurRadius = 1.5
        view.dimmingTintColor = UIColor.black
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
        return view
    }()

    /// 하단바 그라데이션 레이어
    private lazy var bottomGradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(LiquidGlassStyle.maxDimAlpha * 0.1).cgColor,
            UIColor.black.withAlphaComponent(LiquidGlassStyle.maxDimAlpha * 0.3).cgColor,
            UIColor.black.withAlphaComponent(LiquidGlassStyle.maxDimAlpha * 0.7).cgColor,
            UIColor.black.withAlphaComponent(LiquidGlassStyle.maxDimAlpha).cgColor
        ]
        layer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

    /// Cancel 버튼 - GlassTextButton (Liquid Glass 스타일)
    private lazy var cancelButton: GlassTextButton = {
        let button = GlassTextButton(title: "취소", style: .plain, tintColor: .systemBlue)
        button.addTarget(self, action: #selector(cancelButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "comparison_cancel"
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

    /// Delete 버튼 - GlassTextButton (Liquid Glass 스타일)
    private lazy var deleteButton: GlassTextButton = {
        let button = GlassTextButton(title: "삭제", style: .plain, tintColor: .systemRed)
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.accessibilityIdentifier = "comparison_delete"
        return button
    }()

    /// 커스텀 타이틀바 (iOS 16~25)
    private var customTitleBar: FaceComparisonTitleBar?

    // MARK: - Initialization

    /// FaceComparisonViewController를 생성합니다.
    init(
        comparisonGroup: ComparisonGroup,
        trashStore: TrashStoreProtocol = TrashStore.shared,
        cache: any SimilarityCacheProtocol = SimilarityCache.shared
    ) {
        self.comparisonGroup = comparisonGroup
        self.trashStore = trashStore
        self.cache = cache
        super.init(nibName: nil, bundle: nil)

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

        buildAssetCache()
        setupUI()
        loadPhotoFaces()
        loadValidPersonIndices()

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if #available(iOS 26.0, *) {
            setupSystemNavigationBar()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // C-3 오버레이가 window에 직접 추가되므로, VC dismiss 시 정리 필요
        if isBeingDismissed || isMovingFromParent {
            CoachMarkManager.shared.isC3TransitionActive = false
            CoachMarkManager.shared.dismissCurrent()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // [LiquidGlass 최적화] 블러 뷰 사전 생성 + idle pause + 페이지 스크롤뷰 델리게이트 설정
        LiquidGlassOptimizer.preload(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)
        setupPageScrollViewDelegate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        bottomGradientLayer.frame = bottomBarContainer.bounds
    }

    // MARK: - Setup

    /// UI 구성
    private func setupUI() {
        setupPageViewController()

        if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 네비게이션바 사용
        } else {
            setupCustomTitleBar()
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
            titleBar.bottomAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.topAnchor,
                constant: FaceComparisonTitleBar.contentHeight + FaceComparisonTitleBar.gradientExtension
            )
        ])

        customTitleBar = titleBar
        updateTitleBar()
    }

    /// 페이지 뷰 컨트롤러 설정 (전체 화면)
    private func setupPageViewController() {
        addChild(pageViewController)
        view.addSubview(pageViewController.view)
        pageViewController.didMove(toParent: self)

        NSLayoutConstraint.activate([
            pageViewController.view.topAnchor.constraint(equalTo: view.topAnchor),
            pageViewController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            pageViewController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            pageViewController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// 시스템 네비게이션바 설정 (iOS 26+)
    @available(iOS 26.0, *)
    private func setupSystemNavigationBar() {
        updateNavigationTitle()

        // 왼쪽: 닫기 버튼
        let closeButton = UIBarButtonItem(
            image: UIImage(systemName: "xmark"),
            style: .plain,
            target: self,
            action: #selector(cancelButtonTapped)
        )
        closeButton.tintColor = .white
        navigationItem.leftBarButtonItem = closeButton

        // 오른쪽: 순환 버튼
        let cycleButton = UIBarButtonItem(
            image: UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90"),
            style: .plain,
            target: self,
            action: #selector(cycleButtonTapped)
        )
        cycleButton.tintColor = .white

        navigationItem.rightBarButtonItems = [cycleButton]
    }

    /// 하단바 설정
    private func setupBottomBar() {
        view.addSubview(bottomBarContainer)
        bottomBarContainer.addSubview(bottomProgressiveBlurView)
        bottomBarContainer.layer.addSublayer(bottomGradientLayer)
        bottomBarContainer.addSubview(selectionCountLabel)
        bottomBarContainer.addSubview(deleteButton)

        NSLayoutConstraint.activate([
            bottomBarContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            bottomBarContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            bottomBarContainer.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            bottomBarContainer.topAnchor.constraint(
                equalTo: view.safeAreaLayoutGuide.bottomAnchor,
                constant: -(Self.bottomBarHeight + Self.bottomBarGradientExtension)
            ),

            bottomProgressiveBlurView.topAnchor.constraint(equalTo: bottomBarContainer.topAnchor),
            bottomProgressiveBlurView.leadingAnchor.constraint(equalTo: bottomBarContainer.leadingAnchor),
            bottomProgressiveBlurView.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor),
            bottomProgressiveBlurView.bottomAnchor.constraint(equalTo: bottomBarContainer.bottomAnchor),

            selectionCountLabel.centerXAnchor.constraint(equalTo: bottomBarContainer.centerXAnchor),
            selectionCountLabel.topAnchor.constraint(equalTo: bottomBarContainer.layoutMarginsGuide.topAnchor, constant: 16),

            deleteButton.trailingAnchor.constraint(equalTo: bottomBarContainer.trailingAnchor, constant: -16),
            deleteButton.topAnchor.constraint(equalTo: bottomBarContainer.layoutMarginsGuide.topAnchor, constant: 8)
        ])
    }

    // MARK: - Data Loading

    /// PHAsset 캐시 구축 (O(1) 조회용)
    /// comparisonGroup에 포함된 assetID들만 캐싱합니다.
    private func buildAssetCache() {
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: comparisonGroup.selectedAssetIDs,
            options: nil
        )
        result.enumerateObjects { [weak self] asset, _, _ in
            self?.assetCache[asset.localIdentifier] = asset
        }
    }

    /// 사진별 얼굴 정보 로드 + 사진 번호 맵 구축
    private func loadPhotoFaces() {
        Task { @MainActor in
            // 얼굴 정보 로드
            for assetID in comparisonGroup.selectedAssetIDs {
                let faces = await cache.getFaces(for: assetID)
                photoFaces[assetID] = faces
            }

            // 사진 번호 맵 구축 (SimilarThumbnailGroup.memberAssetIDs 기반)
            let groupMembers = await cache.getGroupMembers(groupID: comparisonGroup.sourceGroupID)
            for (index, assetID) in groupMembers.enumerated() {
                memberNumberMap[assetID] = index + 1  // 1-based
            }

            isPhotoFacesLoaded = true
            setupInitialPageIfReady()
        }
    }

    /// 유효 인물 목록 로드
    private func loadValidPersonIndices() {
        Task { @MainActor in
            let validSlots = await cache.getGroupValidPersonIndices(for: comparisonGroup.sourceGroupID)
            validPersonIndices = validSlots.sorted()

            if let index = validPersonIndices.firstIndex(of: comparisonGroup.personIndex) {
                currentPersonArrayIndex = index
            }

            isValidPersonIndicesLoaded = true
            updateTitleBar()
            updateCycleButtonState()
            setupInitialPageIfReady()
        }
    }

    /// 순환 버튼 활성화 상태 업데이트
    /// 인물이 2명 이상일 때만 활성화
    private func updateCycleButtonState() {
        let isEnabled = validPersonIndices.count > 1

        if #available(iOS 26.0, *) {
            navigationItem.rightBarButtonItems?.first?.isEnabled = isEnabled
        } else {
            customTitleBar?.setCycleButtonEnabled(isEnabled)
        }
    }

    /// 데이터 로딩 완료 시 초기 페이지 설정
    private func setupInitialPageIfReady() {
        guard isDataReady else { return }

        // 초기 페이지 설정
        let initialPage = PersonPageViewController(personIndex: currentPersonIndex, dataSource: self)
        pageViewController.setViewControllers([initialPage], direction: .forward, animated: false)

    }

    // MARK: - UI Updates

    /// 타이틀바 업데이트
    private func updateTitleBar() {
        let title = "유사사진정리 - 인물 \(currentPersonArrayIndex + 1)"

        if #available(iOS 26.0, *) {
            self.title = title
        } else {
            customTitleBar?.setTitle(title)
        }
    }

    /// 네비게이션 타이틀 업데이트 (iOS 26+)
    @available(iOS 26.0, *)
    private func updateNavigationTitle() {
        self.title = "유사사진정리 - 인물\(currentPersonIndex)"
    }

    /// 선택 개수 업데이트
    private func updateSelectionCount() {
        let count = selectedAssetIDs.count

        if count > 0 {
            selectionCountLabel.text = "\(count)개 선택됨"
        } else {
            selectionCountLabel.text = "항목 선택"
        }
    }

    // MARK: - Coach Mark C-3

    /// C-3 온보딩 표시 (C-2 완료 후 자동 호출)
    /// C-2 → face comparison present 후 ViewerVC+CoachMarkC에서 호출
    func showFaceComparisonGuide() {
        guard !UIAccessibility.isVoiceOverRunning else { return }

        // 셀 렌더 후 frame을 가져와야 하므로 다음 레이아웃 사이클 대기
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, let window = self.view.window else { return }
            guard let currentPage = self.pageViewController.viewControllers?.first
                    as? PersonPageViewController else { return }
            guard let firstCell = currentPage.firstCell() else { return }

            let cellFrame = firstCell.convert(firstCell.bounds, to: window)
            guard let picLabelFrame = firstCell.debugLabelFrameInWindow() else { return }
            guard let assetID = currentPage.firstAssetID() else { return }

            CoachMarkOverlayView.showFaceComparisonGuide(
                in: window,
                cellFrame: cellFrame,
                picLabelFrame: picLabelFrame,
                onSelect: { [weak self] in
                    self?.toggleSelection(for: assetID)
                    firstCell.setSelected(true)
                },
                onDeselect: { [weak self] in
                    self?.toggleSelection(for: assetID)
                    firstCell.setSelected(false)
                }
            )
        }
    }

    // MARK: - Helpers

    /// PHAsset 가져오기 (O(1) 캐시 조회)
    private func asset(for assetID: String) -> PHAsset? {
        return assetCache[assetID]
    }

    /// 특정 인물로 이동 (UIPageViewController 사용)
    private func navigateToPerson(at arrayIndex: Int, direction: UIPageViewController.NavigationDirection) {
        guard arrayIndex >= 0 && arrayIndex < validPersonIndices.count else { return }

        currentPersonArrayIndex = arrayIndex
        let targetPersonIndex = validPersonIndices[arrayIndex]

        let targetPage = PersonPageViewController(personIndex: targetPersonIndex, dataSource: self)
        pageViewController.setViewControllers([targetPage], direction: direction, animated: true)

        updateTitleBar()
    }

    // MARK: - Actions

    /// Cancel 버튼 탭
    @objc private func cancelButtonTapped() {
        selectedAssetIDs.removeAll()

        dismiss(animated: true) { [weak self] in
            guard let self = self else { return }
            self.delegate?.faceComparisonViewControllerDidClose(self)
        }
    }

    /// Delete 버튼 탭
    @objc private func deleteButtonTapped() {
        guard !selectedAssetIDs.isEmpty else {
            let alert = UIAlertController(title: nil, message: "사진을 먼저 선택하세요", preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "확인", style: .default))
            present(alert, animated: true)
            return
        }

        let deletedIDs = Array(selectedAssetIDs)

        trashStore.moveToTrash(assetIDs: deletedIDs)

        Task { @MainActor in
            for assetID in deletedIDs {
                _ = await cache.removeMemberFromGroup(assetID, groupID: comparisonGroup.sourceGroupID)
            }

            selectedAssetIDs.removeAll()

            delegate?.faceComparisonViewController(self, didDeletePhotos: deletedIDs)
        }
    }

    /// 순환 버튼 탭
    @objc private func cycleButtonTapped() {
        guard validPersonIndices.count > 1 else { return }

        let nextIndex = (currentPersonArrayIndex + 1) % validPersonIndices.count

        navigateToPerson(at: nextIndex, direction: .forward)
    }

    // MARK: - Debug Actions

    /// 디버그 버튼 탭
    @objc private func debugButtonTapped() {
        Task { @MainActor in
            let assetIDs = comparisonGroup.selectedAssetIDs
            guard !assetIDs.isEmpty else {
                return
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
            var photosDict: [String: PHAsset] = [:]
            fetchResult.enumerateObjects { asset, _, _ in
                photosDict[asset.localIdentifier] = asset
            }
            let photos = assetIDs.compactMap { photosDict[$0] }

            guard !photos.isEmpty else {
                return
            }

            await YuNetDebugTest.shared.runGroupMatchingTest(with: photos)

            let debugInfo = await FaceComparisonDebugHelper.generateDebugInfo(
                allAssetIDs: assetIDs,
                groupID: comparisonGroup.sourceGroupID,
                validPersonIndices: validPersonIndices,
                currentPersonIndex: currentPersonIndex
            )
            FaceComparisonDebugHelper.printDebugInfo(debugInfo)
        }
    }

    /// Extended Fallback 테스트 버튼 탭
    @objc private func extendedTestButtonTapped() {
        Task { @MainActor in
            let assetIDs = comparisonGroup.selectedAssetIDs
            guard !assetIDs.isEmpty else {
                return
            }

            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: assetIDs, options: nil)
            var photosDict: [String: PHAsset] = [:]
            fetchResult.enumerateObjects { asset, _, _ in
                photosDict[asset.localIdentifier] = asset
            }
            let photos = assetIDs.compactMap { photosDict[$0] }

            guard !photos.isEmpty else {
                return
            }

            // Vision fallback 제거됨 — Extended 비교 테스트 비활성화
            print("[Debug] ExtendedFallbackTester 비활성화됨 (Vision 제거)")
        }
    }
}

// MARK: - FaceComparisonBottomBar

/// 버튼 외 영역은 터치 통과시키는 하단바 컨테이너
private final class FaceComparisonBottomBar: UIView {
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let hitView = super.hitTest(point, with: event)
        return hitView === self ? nil : hitView
    }
}

// MARK: - FaceComparisonDataSource

extension FaceComparisonViewController: FaceComparisonDataSource {

    func photosForPerson(_ personIndex: Int) -> [String] {
        return comparisonGroup.selectedAssetIDs.filter { assetID in
            guard let faces = photoFaces[assetID] else { return false }
            return faces.contains { $0.personIndex == personIndex }
        }
    }

    func isSelected(_ assetID: String) -> Bool {
        return selectedAssetIDs.contains(assetID)
    }

    func photoNumber(for assetID: String) -> Int {
        return memberNumberMap[assetID] ?? 0
    }

    func toggleSelection(for assetID: String) {
        if selectedAssetIDs.contains(assetID) {
            selectedAssetIDs.remove(assetID)
        } else {
            selectedAssetIDs.insert(assetID)
        }

        updateSelectionCount()

    }

    func face(for assetID: String, personIndex: Int) -> CachedFace? {
        return photoFaces[assetID]?.first { $0.personIndex == personIndex }
    }

    func loadFaceImage(
        assetID: String,
        personIndex: Int,
        completion: @escaping (UIImage?) -> Void
    ) {
        guard let asset = asset(for: assetID),
              let face = face(for: assetID, personIndex: personIndex) else {
            completion(nil)
            return
        }

        let boundingBox = face.boundingBox

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
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // 백그라운드에서 크롭 수행
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let croppedImage = try FaceCropper.cropFace(from: image, boundingBox: boundingBox)
                    DispatchQueue.main.async { completion(croppedImage) }
                } catch {
                    DispatchQueue.main.async { completion(nil) }
                }
            }
        }
    }

    var contentInsetForGrid: UIEdgeInsets {
        let safeAreaTop = view.safeAreaInsets.top
        let safeAreaBottom = view.safeAreaInsets.bottom

        let topInset: CGFloat
        let bottomInset: CGFloat

        if #available(iOS 26.0, *) {
            // .automatic이 safeArea 자동 처리하므로 제외
            topInset = 0
            bottomInset = Self.bottomBarHeight + Self.bottomBarGradientExtension
        } else {
            // .never이므로 safeArea 수동 추가
            // 버튼과 셀 사이 여백을 위해 gradientExtension을 한번 더 추가
            topInset = safeAreaTop + FaceComparisonTitleBar.contentHeight + FaceComparisonTitleBar.gradientExtension * 2
            bottomInset = safeAreaBottom + Self.bottomBarHeight + Self.bottomBarGradientExtension
        }

        return UIEdgeInsets(top: topInset, left: 0, bottom: bottomInset, right: 0)
    }
}

// MARK: - UIPageViewControllerDataSource

extension FaceComparisonViewController: UIPageViewControllerDataSource {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerBefore viewController: UIViewController
    ) -> UIViewController? {
        guard let currentPage = viewController as? PersonPageViewController else { return nil }

        let currentIndex = validPersonIndices.firstIndex(of: currentPage.personIndex)
        guard let idx = currentIndex, idx > 0 else {
            // 원형 순환: 첫 번째에서 마지막으로
            guard validPersonIndices.count > 1 else { return nil }
            let lastPersonIndex = validPersonIndices[validPersonIndices.count - 1]
            return PersonPageViewController(personIndex: lastPersonIndex, dataSource: self)
        }

        let previousPersonIndex = validPersonIndices[idx - 1]
        return PersonPageViewController(personIndex: previousPersonIndex, dataSource: self)
    }

    func pageViewController(
        _ pageViewController: UIPageViewController,
        viewControllerAfter viewController: UIViewController
    ) -> UIViewController? {
        guard let currentPage = viewController as? PersonPageViewController else { return nil }

        let currentIndex = validPersonIndices.firstIndex(of: currentPage.personIndex)
        guard let idx = currentIndex, idx < validPersonIndices.count - 1 else {
            // 원형 순환: 마지막에서 첫 번째로
            guard validPersonIndices.count > 1 else { return nil }
            let firstPersonIndex = validPersonIndices[0]
            return PersonPageViewController(personIndex: firstPersonIndex, dataSource: self)
        }

        let nextPersonIndex = validPersonIndices[idx + 1]
        return PersonPageViewController(personIndex: nextPersonIndex, dataSource: self)
    }
}

// MARK: - UIPageViewControllerDelegate

extension FaceComparisonViewController: UIPageViewControllerDelegate {

    func pageViewController(
        _ pageViewController: UIPageViewController,
        didFinishAnimating finished: Bool,
        previousViewControllers: [UIViewController],
        transitionCompleted completed: Bool
    ) {
        guard completed,
              let currentPage = pageViewController.viewControllers?.first as? PersonPageViewController else {
            return
        }

        // 현재 인물 인덱스 업데이트
        if let index = validPersonIndices.firstIndex(of: currentPage.personIndex) {
            currentPersonArrayIndex = index
        }

        // 타이틀바 업데이트
        updateTitleBar()

        // 선택 상태 경량 갱신 (prefetch된 페이지의 stale 선택 상태 보정)
        currentPage.refreshSelectionStates()

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

// MARK: - LiquidGlass 최적화 (UIScrollViewDelegate)

extension FaceComparisonViewController: UIScrollViewDelegate {

    /// UIPageViewController 내부 스크롤뷰의 delegate 설정
    /// - Note: 더 빠른 시점(터치 직후)에 LiquidGlass 최적화 적용
    func setupPageScrollViewDelegate() {
        // UIPageViewController 내부의 UIScrollView 찾기
        guard let scrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
            return
        }

        scrollView.delegate = self
    }

    // MARK: - UIScrollViewDelegate

    /// 드래그 시작 (터치 직후) - 최적화 시작
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.cancelIdleTimer()
        LiquidGlassOptimizer.optimize(in: view.window)
    }

    /// 감속 완료 - 최적화 해제
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.restore(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)
    }

    /// 드래그 종료 (감속 없이 멈춤) - 최적화 해제
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            LiquidGlassOptimizer.restore(in: view.window)
            LiquidGlassOptimizer.enterIdle(in: view.window)
        }
    }
}

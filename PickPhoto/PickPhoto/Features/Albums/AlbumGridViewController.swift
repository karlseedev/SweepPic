// AlbumGridViewController.swift
// 앨범 내 사진 그리드 뷰컨트롤러
//
// T052: 앨범 탭 → 앨범 그리드 뷰 구현
// - BaseGridViewController 상속 (Phase 4 리팩토링)
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
final class AlbumGridViewController: BaseGridViewController {

    // MARK: - Properties (Album 고유)

    /// 앨범 제목
    /// iOS 18+ zoom transition의 sourceViewProvider에서 외부 접근 필요
    let albumTitle: String

    /// 앨범 내 사진 fetch result
    private let fetchResult: PHFetchResult<PHAsset>

    /// 데이터 소스 어댑터 (GridDataSource 프로토콜 구현)
    private let _albumDataSource: AlbumDataSource

    /// 초기 스크롤 완료 여부 (맨 아래로 스크롤)
    private var didInitialScroll: Bool = false

    /// PRD7: 이전 삭제대기함 상태 (changedIDs 계산용)
    /// Note: swipeDeleteState는 BaseGridViewController에서 상속
    private var lastTrashedIDs: Set<String> = []

    // MARK: - Pending Viewer Return (iOS 18+ Zoom Transition 안정화)

    /// 뷰어 복귀 후 사용자가 스크롤했는지 여부
    /// - true이면 applyPendingViewerReturn()에서 강제 스크롤 skip
    private var didUserScrollAfterReturn: Bool = false

    // MARK: - BaseGridViewController Overrides

    override var gridDataSource: GridDataSource {
        _albumDataSource
    }

    /// 스와이프 삭제 지원 (PRD7)
    override var supportsSwipeDelete: Bool { true }

    override var emptyStateConfig: (icon: String, title: String, subtitle: String?) {
        ("photo.on.rectangle", "사진이 없습니다", "이 앨범에 사진이 없습니다")
    }

    override var navigationTitle: String {
        albumTitle
    }

    /// 앨범 상세 화면 타이틀: 20pt bold (메인 탭 36pt light와 별도 관리)
    override var navigationTitleAttributes: [NSAttributedString.Key: Any] {
        [
            .font: UIFont.systemFont(ofSize: 20, weight: .bold),
        ]
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
        self._albumDataSource = AlbumDataSource(fetchResult: fetchResult)
        super.init(imagePipeline: imagePipeline, trashStore: trashStore)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        // Note: 스와이프 제스처는 Base.setupGestures에서 supportsSwipeDelete 체크 후 자동 설정
        setupObservers()

        // iOS 26+: 시스템 바 사용, edge-to-edge 투명 효과 활성화
        if #available(iOS 26.0, *) {
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 현재 화면이 TrashStore 변경을 받도록 핸들러 재등록
        trashStore.onStateChange { [weak self] trashedAssetIDs in
            self?.handleTrashStateChange(trashedAssetIDs)
        }
        handleTrashStateChange(trashStore.trashedAssetIDs)

        if useFloatingUI {
            // FloatingOverlay 상태 세팅 (공유 UI 사용)
            configureFloatingOverlayForAlbum()
        } else if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 네비바에 Select 버튼 추가 (Grid와 동일)
            setupSystemNavigationBarForAlbum()
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

        // [LiquidGlass 최적화] 블러 뷰 사전 생성 + idle pause
        LiquidGlassOptimizer.preload(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 초기 로드 시 맨 아래로 스크롤 (최신 사진부터 보기)
        if !didInitialScroll && fetchResult.count > 0 {
            didInitialScroll = true
            scrollToBottomIfNeeded()
        }
    }

    // MARK: - Setup (Album 고유)

    /// PRD7: Observer 설정
    private func setupObservers() {
        // TrashStore 변경 감지 (GridViewController와 동일)
        trashStore.onStateChange { [weak self] trashedAssetIDs in
            self?.handleTrashStateChange(trashedAssetIDs)
        }

        // PRD7: VoiceOver 상태 변경 감지
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(voiceOverStatusChanged),
            name: UIAccessibility.voiceOverStatusDidChangeNotification,
            object: nil
        )
    }

    /// PRD7: VoiceOver 상태 변경 시 스와이프 제스처 활성화/비활성화
    @objc private func voiceOverStatusChanged() {
        updateSwipeDeleteGestureEnabled()
    }

    /// 삭제대기함 상태 변경 처리
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

    }

    // MARK: - FloatingOverlay Configuration
    // Note: 스와이프 제스처 설정은 BaseGridViewController에서 supportsSwipeDelete로 처리됨

    /// FloatingOverlay 상태를 앨범 화면용으로 설정
    /// - 타이틀: 앨범명
    /// - 뒤로가기 버튼: 표시 + pop 액션
    override func configureFloatingOverlay() {
        configureFloatingOverlayForAlbum()
    }

    /// Note: GridSelectMode.swift의 exitSelectModeFloatingUI()에서 호출하므로 internal
    func configureFloatingOverlayForAlbum() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        // 타이틀 변경 (앨범 상세 전용 폰트 적용) + 뒤로가기 버튼과 세로 중앙 정렬
        overlay.titleBar.setTitle(albumTitle, attributes: navigationTitleAttributes)
        overlay.titleBar.isTitleCenteredVertically = true

        // 뒤로가기 버튼 표시 + pop 액션 설정
        overlay.titleBar.setShowsBackButton(true) { [weak self] in
            self?.navigationController?.popViewController(animated: true)
        }

        // Select 버튼 표시 (Grid와 동일하게 선택 모드 지원)
        overlay.titleBar.resetToSelectButton()
        overlay.titleBar.isSelectButtonHidden = false

        // 빈 앨범이면 Select 버튼 비활성화
        let isEmpty = gridDataSource.assetCount == 0
        overlay.titleBar.isSelectButtonEnabled = !isEmpty

    }

    /// iOS 26+: 시스템 네비바 설정 (Select 버튼 추가)
    /// Note: GridSelectMode.swift의 restoreNavigationBarAfterSelectMode()에서 호출하므로 internal
    @available(iOS 26.0, *)
    func setupSystemNavigationBarForAlbum() {
        // 선택 모드가 아닐 때만 Select 버튼 설정
        guard !isSelectMode else { return }

        let selectButton = UIBarButtonItem(
            title: "선택",
            style: .plain,
            target: self,
            action: #selector(selectButtonTapped)
        )
        // 빈 앨범이면 Select 버튼 비활성화
        let isEmpty = gridDataSource.assetCount == 0
        selectButton.isEnabled = !isEmpty

        navigationItem.rightBarButtonItem = selectButton

    }

    // MARK: - Album 고유 기능

    /// 맨 아래로 스크롤 (최신 사진부터 보기)
    private func scrollToBottomIfNeeded() {
        guard fetchResult.count > 0 else { return }
        // padding 적용된 마지막 인덱스
        let lastIndex = fetchResult.count - 1 + paddingCellCount
        let lastIndexPath = IndexPath(item: lastIndex, section: 0)
        collectionView.scrollToItem(at: lastIndexPath, at: .bottom, animated: false)
    }

    // MARK: - BaseGridViewController Template Methods

    /// 줌 후 visible cells에 고해상도 썸네일 재요청
    override func didPerformZoom(to columns: GridColumnCount) {
        refreshVisibleCellsAfterZoom()
    }

    /// 줌 후 visible cells에 고해상도 썸네일 재요청
    private func refreshVisibleCellsAfterZoom() {
        // 안전 가드: 스크롤 중이면 스킵
        if collectionView.isDragging || collectionView.isDecelerating {
            return
        }

        let targetSize = thumbnailSize()

        for indexPath in collectionView.indexPathsForVisibleItems {
            // padding 셀 제외
            guard indexPath.item >= paddingCellCount else { continue }

            // 실제 에셋 인덱스
            let assetIndex = indexPath.item - paddingCellCount
            guard assetIndex < fetchResult.count else { continue }

            let asset = fetchResult.object(at: assetIndex)
            guard let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else {
                continue
            }

            // 고해상도 재요청 (targetSize 비교는 PhotoCell에서 수행)
            cell.refreshImageIfNeeded(asset: asset, targetSize: targetSize)
        }
    }

    /// 뷰어 열기 (BaseGridViewController에서 호출)
    override func openViewer(for asset: PHAsset, at assetIndex: Int) {
        // [수정] 앨범에서도 항상 .normal 모드로 뷰어 열기
        // 보관함과 동일하게 삭제대기함 사진도 마룬 테두리와 함께 표시되고, 복구 버튼이 표시됨
        let mode: ViewerMode = .normal

        // 뷰어 코디네이터 생성
        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: mode,
            deleteSource: .album
        )

        // 필터링된 인덱스 계산
        guard let filteredIndex = coordinator.filteredIndex(from: assetIndex) else {
            return
        }

        // 뷰어 뷰컨트롤러 생성
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: filteredIndex,
            mode: mode
        )
        viewerVC.delegate = self

        // iOS 26+: Navigation Push 방식 (시스템 네비바/툴바 사용 가능)
        // iOS 16~25: Modal 방식 (커스텀 줌 트랜지션)
        if #available(iOS 26.0, *), let tbc = tabBarController as? TabBarController {
            tbc.zoomSourceProvider = self
            tbc.zoomDestinationProvider = viewerVC
            navigationController?.pushViewController(viewerVC, animated: true)
        } else {
            let transitionController = ZoomTransitionController()
            transitionController.sourceProvider = self
            transitionController.destinationProvider = viewerVC
            viewerVC.zoomTransitionController = transitionController
            viewerVC.transitioningDelegate = transitionController
            present(viewerVC, animated: true)
        }

    }
}

// MARK: - UIScrollViewDelegate (스크롤 롤백 방지)

extension AlbumGridViewController {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 사용자가 스크롤 시작하면 pending 스크롤 취소 (롤백 방지)
        pendingScrollAssetID = nil
        didUserScrollAfterReturn = true

        // [LiquidGlass 최적화] 스크롤 시작 시 최적화 적용
        LiquidGlassOptimizer.cancelIdleTimer()
        LiquidGlassOptimizer.optimize(in: view.window)
    }

    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard !decelerate else { return }
        // [LiquidGlass 최적화] 스크롤 종료 시 최적화 해제
        LiquidGlassOptimizer.restore(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)
    }

    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        // [LiquidGlass 최적화] 감속 완료 시 최적화 해제
        LiquidGlassOptimizer.restore(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)
    }
}

// MARK: - ViewerViewControllerDelegate (T053)

extension AlbumGridViewController: ViewerViewControllerDelegate {

    func viewerDidRequestDelete(assetID: String) {
        // T053: 앨범에서 삭제 → TrashStore로 이동
        trashStore.moveToTrash(assetIDs: [assetID])

        // 셀 업데이트 (딤드 표시)
        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        if let indexPath = collectionIndexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

    }

    func viewerDidRequestRestore(assetID: String) {
        trashStore.restore(assetIDs: [assetID])

        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        if let indexPath = collectionIndexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

    }

    func viewerDidRequestPermanentDelete(assetID: String) {
        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: [assetID])
            } catch {
                // 취소 또는 오류 시 조용히 무시
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

    /// 뷰어가 완전히 닫힌 후 호출 (dismiss/pop 애니메이션 완료 후)
    /// iOS 16~25 Modal (shouldRemovePresentersView=false) 경로에서
    /// viewWillAppear/viewDidAppear가 호출되지 않으므로 이 콜백으로 처리
    func viewerDidClose() {
        applyPendingViewerReturn()
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

        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        guard let indexPath = collectionIndexPath(for: assetID) else { return }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.contains(indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
    }
}

// Note: 스와이프 삭제/복구 코드는 BaseGridViewController로 공통화됨
// supportsSwipeDelete = true로 자동 활성화

// MARK: - ZoomTransitionSourceProviding (커스텀 줌 트랜지션)

extension AlbumGridViewController: ZoomTransitionSourceProviding {

    /// 줌 애니메이션 시작 뷰 (셀의 이미지 뷰)
    /// - Parameter index: 현재 뷰어의 인덱스
    /// - Returns: PhotoCell의 thumbnailImageView 또는 nil
    func zoomSourceView(for index: Int) -> UIView? {
        // padding 보정하여 실제 셀 IndexPath 계산
        let cellIndexPath = IndexPath(item: index + paddingCellCount, section: 0)

        // 셀이 화면에 있는지 확인
        guard let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell else {
            return nil
        }

        // 이미지가 로드된 셀만 반환 (로드 전이면 nil → crossfade)
        guard cell.hasLoadedImage else { return nil }

        return cell.thumbnailImageView
    }

    /// 줌 애니메이션 시작 프레임 (window 좌표계)
    /// - Parameter index: 현재 뷰어의 인덱스
    /// - Returns: window 좌표계 기준 프레임 또는 nil
    func zoomSourceFrame(for index: Int) -> CGRect? {
        // 1. 셀이 있으면 직접 사용 (가장 정확)
        if let sourceView = zoomSourceView(for: index) {
            return sourceView.superview?.convert(sourceView.frame, to: nil)
        }

        // 2. 셀이 없으면 layout attributes로 프레임 계산
        let cellIndexPath = IndexPath(item: index + paddingCellCount, section: 0)
        guard let attributes = collectionView.layoutAttributesForItem(at: cellIndexPath) else {
            return nil
        }
        return collectionView.convert(attributes.frame, to: nil)
    }

    /// 해당 인덱스의 셀이 보이도록 스크롤 (Pop 전 호출)
    /// - Parameter index: 스크롤할 원본 인덱스
    func scrollToSourceCell(for index: Int) {
        let cellIndexPath = IndexPath(item: index + paddingCellCount, section: 0)

        // 이미 화면에 보이면 스크롤 불필요
        if collectionView.indexPathsForVisibleItems.contains(cellIndexPath) {
            return
        }

        // 즉시 스크롤 (animated: false)
        collectionView.scrollToItem(at: cellIndexPath, at: .centeredVertically, animated: false)
        collectionView.layoutIfNeeded()
    }
}

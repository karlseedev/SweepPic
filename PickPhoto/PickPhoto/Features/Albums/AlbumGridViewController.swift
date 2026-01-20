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

    // MARK: - PRD7: Swipe Delete State

    /// 스와이프 삭제 상태 (GridViewController와 동일한 구조체 사용)
    private var swipeDeleteState = SwipeDeleteState()

    /// PRD7: 이전 휴지통 상태 (changedIDs 계산용)
    private var lastTrashedIDs: Set<String> = []

    // MARK: - Pending Viewer Return (iOS 18+ Zoom Transition 안정화)

    /// 뷰어 복귀 후 사용자가 스크롤했는지 여부
    /// - true이면 applyPendingViewerReturn()에서 강제 스크롤 skip
    private var didUserScrollAfterReturn: Bool = false

    // MARK: - BaseGridViewController Overrides

    override var gridDataSource: GridDataSource {
        _albumDataSource
    }

    override var emptyStateConfig: (icon: String, title: String, subtitle: String?) {
        ("photo.on.rectangle", "사진이 없습니다", "이 앨범에 사진이 없습니다")
    }

    override var navigationTitle: String {
        albumTitle
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
        setupSwipeGestures()
        setupObservers()

        // iOS 26+: 시스템 바 사용, edge-to-edge 투명 효과 활성화
        if #available(iOS 26.0, *) {
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
        }

        print("[AlbumGridViewController] Initialized with \(fetchResult.count) photos in '\(albumTitle)'")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        if useFloatingUI {
            // FloatingOverlay 상태 세팅 (공유 UI 사용)
            configureFloatingOverlayForAlbum()
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

    /// PRD7: 스와이프 제스처 설정
    private func setupSwipeGestures() {
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

    // MARK: - FloatingOverlay Configuration

    /// FloatingOverlay 상태를 앨범 화면용으로 설정
    /// - 타이틀: 앨범명
    /// - 뒤로가기 버튼: 표시 + pop 액션
    override func configureFloatingOverlay() {
        configureFloatingOverlayForAlbum()
    }

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
        // 보관함과 동일하게 휴지통 사진도 마룬 테두리와 함께 표시되고, 복구 버튼이 표시됨
        let mode: ViewerMode = .normal

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
}

// MARK: - UIScrollViewDelegate (스크롤 롤백 방지)

extension AlbumGridViewController {

    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        // 사용자가 스크롤 시작하면 pending 스크롤 취소 (롤백 방지)
        pendingScrollAssetID = nil
        didUserScrollAfterReturn = true
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

        print("[AlbumGridViewController] Moved to trash: \(assetID.prefix(8))...")
    }

    func viewerDidRequestRestore(assetID: String) {
        trashStore.restore(assetIDs: [assetID])

        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        if let indexPath = collectionIndexPath(for: assetID) {
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

        // padding 보정 적용 (Base의 collectionIndexPath 사용)
        guard let indexPath = collectionIndexPath(for: assetID) else { return }

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

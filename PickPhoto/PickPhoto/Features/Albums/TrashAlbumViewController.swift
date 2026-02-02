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
//
// Phase 5: BaseGridViewController 상속으로 리팩토링
// - 공통 코드 제거: 상수, 레이아웃, 핀치 줌, 프리패치
// - 고유 기능 유지: 초기표시 최적화, 백그라운드 로딩, 비우기 버튼

import UIKit
import Photos
import AppCore

/// 휴지통 앨범 뷰컨트롤러
/// TrashStore의 삭제 예정 사진을 그리드로 표시
/// TabBarController의 FloatingOverlay를 공유하여 상태만 변경
final class TrashAlbumViewController: BaseGridViewController {

    // MARK: - Data Source

    /// 휴지통 데이터 소스
    private let _trashDataSource = TrashDataSource()

    /// GridDataSource 프로토콜 구현
    override var gridDataSource: GridDataSource {
        _trashDataSource
    }

    // MARK: - Properties

    /// 휴지통 사진 ID Set
    private var trashedAssetIDSet: Set<String> = []

    /// iOS 26+ 비우기 버튼 참조 (데이터 로드 후 상태 업데이트용)
    /// Note: TrashSelectMode에서 접근해야 하므로 internal
    var emptyTrashBarButtonItem: UIBarButtonItem?

    /// iOS 26+ Select 버튼 참조 (빈 휴지통일 때 비활성화용)
    private var selectBarButtonItem: UIBarButtonItem?

    /// 초기 스크롤 완료 여부 (맨 아래로 스크롤)
    private var didInitialScroll: Bool = false

    /// 뷰어 복귀 후 사용자가 스크롤했는지 여부
    /// - true이면 applyPendingViewerReturn()에서 강제 스크롤 skip
    private var didUserScrollAfterReturn: Bool = false

    /// 뷰어 열림 상태 (데이터 갱신 지연용)
    /// 뷰어가 열려있는 동안 loadTrashedAssets() 호출 시 갱신을 지연
    private var isViewerOpen: Bool = false

    /// 지연된 데이터 갱신 플래그
    /// 뷰어 닫힐 때 true면 loadTrashedAssets() 재호출
    private var pendingDataRefresh: Bool = false

    // MARK: - Initial Display Properties

    /// 초기 표시 완료 여부
    private var hasFinishedInitialDisplay: Bool = false

    /// 프리로드 목표 개수
    private var preloadTargetCount: Int = 0

    /// 프리로드 완료 개수 (Atomic 접근)
    private var preloadCompletedCount: Int = 0

    /// 프리로드 스레드 안전성
    private let preloadLock = NSLock()

    /// 타임아웃 플래그
    private var preloadTimedOut: Bool = false

    // MARK: - BaseGridViewController Overrides

    /// 빈 상태 설정
    override var emptyStateConfig: (icon: String, title: String, subtitle: String?) {
        ("trash", "휴지통이 비어 있습니다", nil)
    }

    /// 네비게이션 타이틀
    /// ⚠️ 휴지통 명칭 변경 시 동시 수정 필요:
    /// - TabBarController.swift: tabBarItem.title
    /// - configureFloatingOverlayForTrash의 setTitle()
    override var navigationTitle: String {
        "휴지통"
    }

    // MARK: - Initialization

    override init(
        imagePipeline: ImagePipelineProtocol = ImagePipeline.shared,
        trashStore: TrashStoreProtocol = TrashStore.shared
    ) {
        super.init(imagePipeline: imagePipeline, trashStore: trashStore)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupObservers()

        // 노출 게이팅: 프리로드 완료까지 숨김
        collectionView.alpha = 0

        // 백그라운드에서 데이터 로드
        loadTrashedAssets()

        // 타임아웃 (200ms - 안정적)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.preloadTimedOut = true
            self?.finishInitialDisplayIfNeeded(reason: "timeout")
        }

        // iOS 26+: 시스템 UI 사용
        if #available(iOS 26.0, *) {
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }

        Log.print("[TrashAlbumViewController] Initialized")
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 현재 화면이 TrashStore 변경을 받도록 핸들러 재등록
        trashStore.onStateChange { [weak self] _ in
            self?.loadTrashedAssets()
        }

        // 뷰어 복귀 시에는 loadTrashedAssets() 스킵 (불필요한 reloadData 방지)
        // - 실제 데이터 변경 시에만 pendingDataRefresh가 true가 됨
        // - applyPendingViewerReturn()에서 필요 시 갱신
        if !isViewerOpen {
            loadTrashedAssets()
        }

        if useFloatingUI {
            // FloatingOverlay 상태 세팅 (공유 UI 사용)
            configureFloatingOverlayForTrash()
        } else if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 네비바에 "비우기" 버튼 추가
            setupSystemNavigationBar()
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

    // MARK: - Setup

    /// TrashStore 상태 변경 구독
    private func setupObservers() {
        trashStore.onStateChange { [weak self] _ in
            DispatchQueue.main.async {
                self?.loadTrashedAssets()
            }
        }
    }

    /// 시스템 네비바 설정 (iOS 26+)
    /// [Select] [비우기] 두 버튼 동시 표시
    @available(iOS 26.0, *)
    override func setupSystemNavigationBar() {
        super.setupSystemNavigationBar()

        let isEmpty = _trashDataSource.isEmpty

        // Select 버튼
        let selectButton = UIBarButtonItem(
            title: "선택",
            style: .plain,
            target: self,
            action: #selector(selectButtonTapped)
        )
        selectButton.isEnabled = !isEmpty

        // "비우기" 버튼
        let emptyButton = UIBarButtonItem(
            title: "비우기",
            style: .plain,
            target: self,
            action: #selector(emptyTrashButtonTapped)
        )
        emptyButton.tintColor = .systemRed
        emptyButton.isEnabled = !isEmpty

        // 프로퍼티에 저장 (데이터 로드 후 상태 업데이트용)
        selectBarButtonItem = selectButton
        emptyTrashBarButtonItem = emptyButton

        // [비우기] [Select] 순서 (배열 첫 요소가 가장 오른쪽)
        navigationItem.rightBarButtonItems = [selectButton, emptyButton]
    }

    /// FloatingOverlay 상태를 휴지통 탭용으로 설정
    /// - 타이틀: "휴지통"
    /// - 뒤로가기 버튼: 숨김 (별도 탭이므로)
    /// - 오른쪽 버튼: [Select] [비우기] (휴지통이 비어있지 않을 때만 표시)
    /// Note: TrashSelectMode.swift의 exitSelectModeFloatingUI()에서 호출하므로 internal
    func configureFloatingOverlayForTrash() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        overlay.titleBar.setTitle(navigationTitle)
        updateTrashItemCountSubtitle()

        // 뒤로가기 버튼 숨김 (별도 탭이므로)
        overlay.titleBar.setShowsBackButton(false, action: nil)

        // [Select] [비우기] 두 버튼 표시
        let isEmpty = _trashDataSource.isEmpty
        overlay.titleBar.setTwoRightButtons(
            firstTitle: "선택",
            firstColor: .white,
            firstAction: { [weak self] in
                self?.enterSelectMode()
            },
            secondTitle: "비우기",
            secondColor: .systemRed,
            secondAction: { [weak self] in
                self?.emptyTrashButtonTapped()
            }
        )
        // 빈 휴지통: 버튼 비활성화 (숨김 X)
        overlay.titleBar.setTwoRightButtonsEnabled(firstEnabled: !isEmpty, secondEnabled: !isEmpty)

        Log.print("[TrashAlbumViewController] FloatingOverlay configured for trash tab")
    }

    // MARK: - Data Loading

    /// 휴지통 사진 로드 (백그라운드에서 fetch/정렬)
    /// TrashStore.trashedAssetIDs 기반으로 PHAsset 조회
    /// 뷰어 열린 상태면 갱신 지연 (dismiss 애니메이션 인덱스 일관성 보장)
    private func loadTrashedAssets() {
        // 뷰어 열린 상태면 갱신 지연 (인덱스 불일치 방지)
        if isViewerOpen {
            pendingDataRefresh = true
            Log.print("[TrashAlbumViewController] Data refresh deferred (viewer open)")
            return
        }

        let startTime = CFAbsoluteTimeGetCurrent()

        trashedAssetIDSet = trashStore.trashedAssetIDs

        if trashedAssetIDSet.isEmpty {
            _trashDataSource.setFetchResult(nil)
            DispatchQueue.main.async { [weak self] in
                self?.onDataLoaded(startTime: startTime)
            }
            return
        }

        // 백그라운드에서 fetch 수행 (메인 스레드 블로킹 방지)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            // PhotoKit 정렬 옵션 사용
            let options = PHFetchOptions()
            options.includeHiddenAssets = false
            options.includeAllBurstAssets = false
            options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

            let fetchResult = PHAsset.fetchAssets(
                withLocalIdentifiers: Array(self.trashedAssetIDSet),
                options: options
            )

            let fetchTime = CFAbsoluteTimeGetCurrent()

            Log.print("[TrashAlbumViewController.Timing] fetch: \(String(format: "%.1f", (fetchTime - startTime) * 1000))ms (background)")

            // 메인 스레드에서 UI 업데이트
            // fetchResult를 직접 저장 (배열 변환 제거 - 인덱스 일관성 보장)
            DispatchQueue.main.async {
                self._trashDataSource.setFetchResult(fetchResult)
                self.onDataLoaded(startTime: startTime)
            }
        }
    }

    /// 데이터 로드 완료 후 호출 (메인 스레드)
    private func onDataLoaded(startTime: CFAbsoluteTime) {
        let reloadStartTime = CFAbsoluteTimeGetCurrent()

        collectionView.reloadData()

        let reloadTime = CFAbsoluteTimeGetCurrent()

        updateEmptyState()

        // 버튼 상태 업데이트 (iOS 버전별 분기 유지)
        let isEmpty = _trashDataSource.isEmpty
        if useFloatingUI {
            // iOS 16~25: FloatingUI 버튼 상태 갱신
            updateFloatingButtonsState()
        } else {
            // iOS 26+: 시스템 네비바 버튼 상태 업데이트
            selectBarButtonItem?.isEnabled = !isEmpty
            emptyTrashBarButtonItem?.isEnabled = !isEmpty
        }

        let endTime = CFAbsoluteTimeGetCurrent()

        updateTrashItemCountSubtitle()

        Log.print("[TrashAlbumViewController] Loaded \(_trashDataSource.assetCount) trashed assets")
        Log.print("[TrashAlbumViewController.Timing] reloadData: \(String(format: "%.1f", (reloadTime - reloadStartTime) * 1000))ms, total: \(String(format: "%.1f", (endTime - startTime) * 1000))ms")

        // 프리로드 시작 (초기 로드 시에만)
        if !hasFinishedInitialDisplay {
            startInitialPreload()
        }
    }

    /// 맨 아래로 스크롤 (최신 사진부터 보기)
    private func scrollToBottomIfNeeded() {
        guard !_trashDataSource.isEmpty else { return }
        // padding 적용된 마지막 인덱스
        let lastIndex = _trashDataSource.assetCount - 1 + paddingCellCount
        let lastIndexPath = IndexPath(item: lastIndex, section: 0)
        collectionView.scrollToItem(at: lastIndexPath, at: .bottom, animated: false)
    }

    /// FloatingUI 버튼 상태 업데이트 (Select/비우기 활성화/비활성화)
    /// 주의: 현재 탭이 휴지통 탭일 때만 버튼 변경 (공유 UI이므로 다른 탭일 때 변경하면 안 됨)
    private func updateFloatingButtonsState() {
        guard let tabBarController = tabBarController as? TabBarController,
              tabBarController.selectedIndex == 2,  // 휴지통 탭 인덱스일 때만 변경
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        let isEmpty = _trashDataSource.isEmpty
        // 빈 휴지통: 버튼 비활성화 (숨김 X)
        overlay.titleBar.setTwoRightButtonsEnabled(firstEnabled: !isEmpty, secondEnabled: !isEmpty)
    }

    // MARK: - Initial Display

    /// 첫 화면 프리로드 범위 계산 (맨 아래 12개)
    private func calculatePreloadRange() -> (startIndex: Int, count: Int) {
        let totalCount = _trashDataSource.assetCount
        guard totalCount > 0 else { return (0, 0) }

        let targetCount = min(12, totalCount)  // 3열 × 4행
        let startIndex = max(0, totalCount - targetCount)
        return (startIndex, targetCount)
    }

    /// 초기 프리로드 시작 (디스크 → 메모리 + preheat)
    private func startInitialPreload() {
        guard currentCellSize != .zero else {
            // 레이아웃 완료 후 재시도
            DispatchQueue.main.async { [weak self] in
                self?.startInitialPreload()
            }
            return
        }

        let (startIndex, count) = calculatePreloadRange()
        guard count > 0 else {
            finishInitialDisplayIfNeeded(reason: "empty")
            return
        }

        preloadLock.lock()
        preloadTargetCount = count
        preloadCompletedCount = 0
        preloadLock.unlock()

        let pixelSize = thumbnailSize()

        // 프리로드 대상 에셋 추출
        var preloadAssets: [PHAsset] = []
        for i in 0..<count {
            let assetIndex = startIndex + i
            guard let asset = _trashDataSource.asset(at: assetIndex) else { continue }
            preloadAssets.append(asset)
        }

        // PHCachingImageManager preheat (디스크 캐시 미스 대비)
        DispatchQueue.global(qos: .userInitiated).async {
            ImagePipeline.shared.preheatAssets(preloadAssets, targetSize: pixelSize)
        }

        // 디스크 → 메모리 캐시 로드 (병렬)
        for asset in preloadAssets {
            let assetID = asset.localIdentifier

            // 메모리 캐시 히트 시 스킵
            if MemoryThumbnailCache.shared.get(assetID: assetID, pixelSize: pixelSize) != nil {
                incrementPreloadCount()
                continue
            }

            // 디스크 캐시 로드
            ThumbnailCache.shared.load(
                assetID: assetID,
                modificationDate: asset.modificationDate,
                size: pixelSize
            ) { [weak self] image in
                if let image = image {
                    MemoryThumbnailCache.shared.set(
                        image: image,
                        assetID: assetID,
                        pixelSize: pixelSize
                    )
                }
                self?.incrementPreloadCount()
            }
        }

        Log.print("[TrashAlbumViewController] Preload started: \(count) assets")
    }

    /// 프리로드 카운터 증가 (스레드 안전)
    private func incrementPreloadCount() {
        preloadLock.lock()
        preloadCompletedCount += 1
        let completed = preloadCompletedCount
        let target = preloadTargetCount
        preloadLock.unlock()

        if completed >= target {
            DispatchQueue.main.async { [weak self] in
                self?.finishInitialDisplayIfNeeded(reason: "preload complete")
            }
        }
    }

    /// 초기 표시 완료 (단일 경로)
    private func finishInitialDisplayIfNeeded(reason: String) {
        guard !hasFinishedInitialDisplay else { return }

        preloadLock.lock()
        let completed = preloadCompletedCount
        let target = preloadTargetCount
        preloadLock.unlock()

        guard completed >= target || preloadTimedOut else { return }

        hasFinishedInitialDisplay = true

        // 레이아웃 + 스크롤 (1회만, 표시 직전)
        if !didInitialScroll {
            didInitialScroll = true
            collectionView.layoutIfNeeded()
            scrollToBottomIfNeeded()
        }

        // UI 표시 (fade-in)
        UIView.animate(withDuration: 0.15) {
            self.collectionView.alpha = 1
        }

        Log.print("[TrashAlbumViewController] Initial display: \(reason), preloaded: \(completed)/\(target)")
    }

    // MARK: - Actions

    /// "비우기" 버튼 탭 (T058)
    /// 바로 iOS 시스템 팝업으로 일괄 삭제 (확인 얼럿 생략 - iOS 팝업이 확인 역할)
    /// Note: TrashSelectMode.swift에서 selector로 접근하므로 internal
    @objc func emptyTrashButtonTapped() {
        guard !_trashDataSource.isEmpty else { return }
        performEmptyTrash()
    }

    // MARK: - Subtitle (사진 개수 표시)

    /// 휴지통 사진 개수 서브타이틀 업데이트
    private func updateTrashItemCountSubtitle() {
        let count = _trashDataSource.assetCount
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        let formatted = formatter.string(from: NSNumber(value: count)) ?? "\(count)"
        let subtitleText = "\(formatted)개의 항목"

        // iOS 18: FloatingTitleBar 서브타이틀
        if let tabBarController = tabBarController as? TabBarController,
           let overlay = tabBarController.floatingOverlay {
            overlay.titleBar.setSubtitle(subtitleText)
        }

        // iOS 26: 네비게이션 바 서브타이틀
        if let subtitleLabel = navSubtitleLabel {
            subtitleLabel.text = subtitleText
            subtitleLabel.isHidden = false
        }
    }

    /// 휴지통 비우기 (외부에서 호출 가능)
    /// FloatingTabBar의 삭제하기 버튼에서 호출
    func emptyTrash() {
        guard !_trashDataSource.isEmpty else { return }
        performEmptyTrash()
    }

    /// 휴지통 비우기 실행
    private func performEmptyTrash() {
        Task {
            do {
                try await trashStore.emptyTrash()
                Log.print("[TrashAlbumViewController] Trash emptied successfully")
            } catch {
                // 취소 또는 오류 시 조용히 무시 (사진이 그대로 남아있음)
                Log.print("[TrashAlbumViewController] Empty trash cancelled or failed: \(error)")
            }
            // 성공/실패 무관하게 UI 갱신 (onStateChange 콜백으로 처리됨)
        }
    }

    // MARK: - Cell Selection (Override)

    /// 뷰어 열기 (휴지통 모드)
    /// 그리드와 동일한 fetchResult를 공유하여 인덱스 일관성 보장
    override func openViewer(for asset: PHAsset, at assetIndex: Int) {
        // 기존 fetchResult 사용 (새로 생성하지 않음 - 인덱스 일관성 보장)
        guard let fetchResult = _trashDataSource.fetchResult else {
            Log.print("[TrashAlbumViewController] Cannot open viewer: fetchResult is nil")
            return
        }

        // 뷰어 열림 상태 설정 (데이터 갱신 지연용)
        isViewerOpen = true

        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: .trash
        )

        // 뷰어 뷰컨트롤러 생성 (휴지통 모드)
        // assetIndex는 이미 fetchResult 기준이므로 그대로 사용
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: assetIndex,
            mode: .trash
        )
        viewerVC.delegate = self

        // 커스텀 줌 트랜지션 설정 (Modal 방식)
        let transitionController = ZoomTransitionController()
        transitionController.sourceProvider = self
        transitionController.destinationProvider = viewerVC
        // ⚠️ strong 참조 먼저 (transitioningDelegate는 weak)
        viewerVC.zoomTransitionController = transitionController
        viewerVC.transitioningDelegate = transitionController

        // Modal present 방식으로 뷰어 표시
        present(viewerVC, animated: true)
    }

    // MARK: - Cell Configuration (Override)

    /// 셀 추가 설정 (휴지통 내에서는 딤드 표시 안 함)
    /// Base에서 이미 configure() 호출되었으므로, isTrashed 상태만 변경
    override func configureCell(_ cell: PhotoCell, at indexPath: IndexPath, asset: PHAsset) {
        // 휴지통 내에서는 모두 삭제 대상이므로 딤드 표시 안 함
        // Base에서 isTrashed=true로 설정되었을 수 있으므로 false로 덮어씀
        cell.updateTrashState(false)

        // DEBUG: 비교 분석 배지 표시 (iOS 18+)
        // ModeCategoryStore 우선, 없으면 CompareCategoryStore 참조
        #if DEBUG
        if #available(iOS 18.0, *) {
            let assetID = asset.localIdentifier
            if let modeCategory = ModeCategoryStore.shared.category(for: assetID) {
                cell.setModeBadge(modeCategory)
            } else {
                let category = CompareCategoryStore.shared.category(for: assetID)
                cell.setCompareBadge(category)
            }
        }
        #endif
    }

    // MARK: - UIScrollViewDelegate

    /// 사용자가 스크롤 시작 시 pending 스크롤 취소 (롤백 방지)
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
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

        Log.print("[TrashAlbumViewController] Restored: \(assetID.prefix(8))...")
        Log.print("[TrashAlbumViewController.Timing] trashStore: \(String(format: "%.1f", (trashStoreTime - startTime) * 1000))ms")
    }

    /// 완전 삭제 요청 (T057)
    /// 비동기 작업 - 삭제 완료 후 뷰어에 알림
    func viewerDidRequestPermanentDelete(assetID: String) {
        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: [assetID])
                // loadTrashedAssets()는 onStateChange 콜백으로 자동 호출됨
                Log.print("[TrashAlbumViewController] Permanently deleted: \(assetID.prefix(8))...")

                // 삭제 완료 후 뷰어에 알림 (메인 스레드에서)
                // Push 방식이므로 navigationController에서 확인
                await MainActor.run {
                    if let viewerVC = self.navigationController?.topViewController as? ViewerViewController {
                        viewerVC.handleDeleteComplete()
                    }
                }
            } catch {
                Log.print("[TrashAlbumViewController] Failed to permanently delete: \(error)")
            }
        }
    }

    /// 뷰어 닫기 시
    /// iOS 18+ Zoom Transition 안정화: 전환 중 scrollToItem 금지
    /// ⚠️ 중요: 여기서 loadTrashedAssets() 호출하면 안 됨!
    ///    sourceViewProvider가 이 함수 이후에 호출되므로, reloadData()가 먼저 실행되면
    ///    셀 내용이 바뀌어 잘못된 사진으로 축소됨
    func viewerWillClose(currentAssetID: String?) {
        // 스크롤 위치만 저장 (전환 완료 후 처리)
        pendingScrollAssetID = currentAssetID
        // 사용자 스크롤 플래그 초기화
        didUserScrollAfterReturn = false

        // ⚠️ isViewerOpen = false와 loadTrashedAssets()는
        //    applyPendingViewerReturn()에서 처리 (dismiss 애니메이션 완료 후)
        Log.print("[TrashAlbumViewController] viewerWillClose - pendingDataRefresh=\(pendingDataRefresh), keeping isViewerOpen=true until animation completes")
    }

    /// 뷰어 닫힘 후 대기 중인 작업 처리 (전환 완료 후 호출)
    /// - 뷰어 상태 해제 및 지연된 데이터 갱신 처리
    /// - scroll만 수행하여 깜빡임 방지
    /// - 사용자가 이미 스크롤 중이면 강제 스크롤 skip (롤백 방지)
    private func applyPendingViewerReturn() {
        // ⚠️ dismiss 애니메이션 완료 후에야 뷰어 상태 해제
        let wasViewerOpen = isViewerOpen
        isViewerOpen = false

        // 지연된 데이터 갱신 처리 (dismiss 애니메이션 완료 후)
        if pendingDataRefresh {
            pendingDataRefresh = false
            Log.print("[TrashAlbumViewController] Processing deferred data refresh (after animation)")
            loadTrashedAssets()
        }

        guard let assetID = pendingScrollAssetID else {
            Log.print("[TrashAlbumViewController] applyPendingViewerReturn - wasViewerOpen=\(wasViewerOpen), no pendingScrollAssetID")
            return
        }
        pendingScrollAssetID = nil

        // 안전 가드 1: 사용자가 복귀 후 스크롤했으면 skip
        if didUserScrollAfterReturn {
            return
        }

        // 안전 가드 2: 현재 스크롤 중이면 skip
        if collectionView.isDragging || collectionView.isDecelerating {
            return
        }

        // padding 보정 적용하여 indexPath 계산
        guard let assetIndex = _trashDataSource.assetIndex(for: assetID) else { return }
        let indexPath = IndexPath(item: assetIndex + paddingCellCount, section: 0)

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.contains(indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
    }
}

// MARK: - ZoomTransitionSourceProviding (커스텀 줌 트랜지션)

extension TrashAlbumViewController: ZoomTransitionSourceProviding {

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

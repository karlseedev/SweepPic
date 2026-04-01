// TrashAlbumViewController.swift
// 삭제대기함 앨범 뷰컨트롤러
//
// T055: 삭제대기함 전용 그리드 뷰
// - TrashStore.trashedAssetIDs 기반 사진 필터링
// - 딤드 없이 정상 표시 (삭제대기함 내에서는 모두 동일)
// - 셀 탭 → ViewerViewController (mode: .trash)
//
// T058: "비우기" 버튼 구현
// - 일괄 삭제 iOS 시스템 팝업
//
// T059: 빈 상태 표시
// - "삭제대기함이 비어 있습니다"
//
// Phase 5: BaseGridViewController 상속으로 리팩토링
// - 공통 코드 제거: 상수, 레이아웃, 핀치 줌, 프리패치
// - 고유 기능 유지: 초기표시 최적화, 백그라운드 로딩, 비우기 버튼

import UIKit
import Photos
import AppCore

/// 삭제대기함 앨범 뷰컨트롤러
/// TrashStore의 삭제 예정 사진을 그리드로 표시
/// TabBarController의 FloatingOverlay를 공유하여 상태만 변경
final class TrashAlbumViewController: BaseGridViewController {

    // MARK: - Data Source

    /// 삭제대기함 데이터 소스
    private let _trashDataSource = TrashDataSource()

    /// GridDataSource 프로토콜 구현
    override var gridDataSource: GridDataSource {
        _trashDataSource
    }

    // MARK: - Properties

    /// 삭제대기함 사진 ID Set
    private var trashedAssetIDSet: Set<String> = []

    /// iOS 26+ 비우기 버튼 참조 (데이터 로드 후 상태 업데이트용)
    /// Note: TrashSelectMode에서 접근해야 하므로 internal
    var emptyTrashBarButtonItem: UIBarButtonItem?

    /// iOS 26+ Select 버튼 참조 (빈 삭제대기함일 때 비활성화용)
    private var selectBarButtonItem: UIBarButtonItem?

    /// 스와이프 복구 시 deleteItems 애니메이션용 indexPath
    /// onDataLoaded()에서 소비하여 reloadData() 대신 deleteItems 수행
    private var pendingDeleteIndexPaths: [IndexPath]?

    /// 초기 스크롤 완료 여부 (맨 아래로 스크롤)
    private var didInitialScroll: Bool = false

    /// 뷰어 복귀 후 사용자가 스크롤했는지 여부
    /// - true이면 applyPendingViewerReturn()에서 강제 스크롤 skip
    private var didUserScrollAfterReturn: Bool = false

    /// 뷰어 열림 상태 (데이터 갱신 지연용)
    /// 뷰어가 열려있는 동안 loadTrashedAssets() 호출 시 갱신을 지연
    private var isViewerOpen: Bool = false

    /// 지연된 데이터 갱신 플래그
    /// 뷰어 닫힐 때 true면 캐싱된 fetch 결과 즉시 적용
    private var pendingDataRefresh: Bool = false

    /// 뷰어 열린 동안 fetch 결과를 캐싱하는 상태
    /// fetch는 즉시 실행하되, reloadData만 지연 (줌 트랜지션 인덱스 보존)
    private enum PendingFetchState {
        case none                              // 대기 중 없음
        case empty                             // 빈 결과 대기 (삭제대기함 비어있음)
        case fetched(PHFetchResult<PHAsset>)   // fetch 완료, 적용 대기
        case fetching                          // fetch 진행 중 (뷰어 닫힐 때 fallback 필요)
    }
    private var pendingFetchState: PendingFetchState = .none

    /// 현재 열린 뷰어 참조 (최종 삭제 완료 후 알림용)
    /// Push/Modal 방식에 무관하게 접근 가능하도록 weak 참조 저장
    private weak var activeViewerVC: ViewerViewController?

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
        ("xmark.bin", "삭제대기함이 비어 있습니다", nil)
    }

    /// 네비게이션 타이틀
    /// ⚠️ 명칭 변경 시 동시 수정 필요:
    /// - TabBarController.swift: tabBarItem.title
    /// - LiquidGlassTabBar.swift: tabButtons title
    /// - configureFloatingOverlayForTrash의 setTitle()
    override var navigationTitle: String {
        "삭제대기함"
    }

    /// 스와이프 제스처 활성화 (녹색 커튼 복구)
    override var supportsSwipeDelete: Bool { true }

    /// 스와이프 동작: 복구 (녹색 커튼)
    override var swipeActionIsRestore: Bool { true }

    /// contentInset 업데이트 — 게이지 높이만큼 추가 여백 적용
    /// 게이지(tag 9901) 높이를 동적 계산
    override func updateContentInset() {
        let hasGauge = view.viewWithTag(9901) != nil

        // 게이지 높이에 따른 추가 inset 계산
        // 게이지: 고정 52pt + 11 여백 = 63
        let extraInset: CGFloat = hasGauge ? 63 : 0

        if #available(iOS 26.0, *) {
            // iOS 26+: base class 보정(12) 적용 후 게이지/배너분 추가
            super.updateContentInset()
            if extraInset > 0 {
                collectionView.contentInset.top += extraInset
            }
        } else {
            // iOS 16~25: 부모 클래스가 heights.top 기반 inset 설정 후 추가
            super.updateContentInset()
            if extraInset > 0 {
                var current = collectionView.contentInset
                current.top += extraInset
                collectionView.contentInset = current
                collectionView.scrollIndicatorInsets = current
            }
        }
    }

    /// Select 모드 진입 시 스와이프 비활성화 (GridViewController와 동일 패턴)
    override func updateSwipeDeleteGestureEnabled() {
        let enabled = !isSelectMode && !UIAccessibility.isVoiceOverRunning
        swipeDeleteState.swipeGesture?.isEnabled = enabled
    }

    /// 스와이프 복구 확정 전: deleteItems 애니메이션용 indexPath 저장
    override func prepareSwipeRestoreAnimation(at indexPaths: [IndexPath]) {
        pendingDeleteIndexPaths = indexPaths
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

        // [BM] 게이지 뷰 설정 (Phase 3 T016)
        setupGaugeView()
        observeSubscriptionStateForGauge()
        observeDeleteGuideCompletion()
        #if DEBUG
        observeDebugMonetizationStateChange()
        #endif

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

    /// FloatingOverlay 상태를 삭제대기함 탭용으로 설정
    /// - 타이틀: "삭제대기함"
    /// - 뒤로가기 버튼: 숨김 (별도 탭이므로)
    /// - 오른쪽 버튼: [Select] [비우기] (삭제대기함이 비어있지 않을 때만 표시)
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
        // 빈 삭제대기함: 버튼 비활성화 (숨김 X)
        overlay.titleBar.setTwoRightButtonsEnabled(firstEnabled: !isEmpty, secondEnabled: !isEmpty)

    }

    // MARK: - Data Loading

    /// 삭제대기함 사진 로드 (백그라운드에서 fetch/정렬)
    /// TrashStore.trashedAssetIDs 기반으로 PHAsset 조회
    /// 뷰어 열린 상태면 갱신 지연 (dismiss 애니메이션 인덱스 일관성 보장)
    private func loadTrashedAssets() {
        trashedAssetIDSet = trashStore.trashedAssetIDs

        // 빈 결과: fetch 불필요
        if trashedAssetIDSet.isEmpty {
            if isViewerOpen {
                // 빈 결과를 캐싱만 하고 reloadData 스킵
                pendingFetchState = .empty
                pendingDataRefresh = true
                return
            }
            _trashDataSource.setFetchResult(nil)
            DispatchQueue.main.async { [weak self] in
                self?.onDataLoaded()
            }
            return
        }

        // 뷰어 열린 상태: fetch 시작 표시 (fetch는 즉시 실행)
        if isViewerOpen {
            pendingFetchState = .fetching
            pendingDataRefresh = true
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

            // 메인 스레드에서 결과 처리
            DispatchQueue.main.async {
                if self.isViewerOpen {
                    // fetch 결과를 캐싱만 하고 reloadData 스킵
                    self.pendingFetchState = .fetched(fetchResult)
                } else {
                    // 뷰어 닫힌 상태: 즉시 적용
                    self._trashDataSource.setFetchResult(fetchResult)
                    self.onDataLoaded()
                }
            }
        }
    }

    /// 데이터 로드 완료 후 호출 (메인 스레드)
    private func onDataLoaded() {
        // 숨긴 셀 복원 (reloadData와 같은 프레임에서 실행 — 깜빡임 방지)
        // viewerWillClose에서 복구된 사진 셀을 isHidden=true로 설정한 경우,
        // reloadData 전에 복원해야 셀 재사용 시 isHidden 잔존 방지
        collectionView.visibleCells.forEach { $0.isHidden = false }

        // ★ 스와이프 복구: deleteItems 애니메이션 (reloadData 대신)
        if let paths = pendingDeleteIndexPaths {
            pendingDeleteIndexPaths = nil
            let oldTotal = collectionView.numberOfItems(inSection: 0)
            let newTotal = _trashDataSource.assetCount + paddingCellCount

            collectionView.performBatchUpdates {
                // 1. 복구된 에셋 셀 삭제 (업데이트 전 indexPath 기준)
                self.collectionView.deleteItems(at: paths)

                // 2. padding 보정 (에셋 수 변화로 상단 빈 셀 수가 바뀔 수 있음)
                let afterDeleteCount = oldTotal - paths.count
                if afterDeleteCount > newTotal {
                    // padding 감소 → 상단 padding 셀 추가 삭제
                    let extraCount = afterDeleteCount - newTotal
                    let extraPaths = (0..<extraCount).map { IndexPath(item: $0, section: 0) }
                    self.collectionView.deleteItems(at: extraPaths)
                } else if afterDeleteCount < newTotal {
                    // padding 증가 → 상단에 padding 셀 삽입 (업데이트 후 기준)
                    let insertCount = newTotal - afterDeleteCount
                    let insertPaths = (0..<insertCount).map { IndexPath(item: $0, section: 0) }
                    self.collectionView.insertItems(at: insertPaths)
                }
            }
        } else {
            collectionView.reloadData()
        }

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

        updateTrashItemCountSubtitle()

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
    /// 주의: 현재 탭이 삭제대기함 탭일 때만 버튼 변경 (공유 UI이므로 다른 탭일 때 변경하면 안 됨)
    private func updateFloatingButtonsState() {
        guard let tabBarController = tabBarController as? TabBarController,
              tabBarController.selectedIndex == 2,  // 삭제대기함 탭 인덱스일 때만 변경
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        let isEmpty = _trashDataSource.isEmpty
        // 빈 삭제대기함: 버튼 비활성화 (숨김 X)
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

    /// 삭제대기함 사진 개수 서브타이틀 업데이트
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

    /// 삭제대기함 비우기 (외부에서 호출 가능)
    /// FloatingTabBar의 삭제하기 버튼에서 호출
    func emptyTrash() {
        guard !_trashDataSource.isEmpty else { return }
        performEmptyTrash()
    }

    /// 삭제대기함 비우기 실행
    /// 게이트 평가 후 통과 시에만 실제 삭제 진행 (BM Phase 3 T017)
    /// 성공 시 축하 화면 표시 (BM Phase 9 T046)
    private func performEmptyTrash() {
        let count = _trashDataSource.assetCount
        guard count > 0 else { return }

        // [BM] 축하 화면용: 삭제 전 asset 수집 (삭제 후 PHAsset 접근 불가)
        var assets: [PHAsset] = []
        assets.reserveCapacity(count)
        for i in 0..<count {
            if let asset = _trashDataSource.asset(at: i) {
                assets.append(asset)
            }
        }

        evaluateGateAndExecute(trashCount: count) { [weak self] in
            // [Analytics] 이벤트 4-2: 삭제대기함 비우기 (최종 삭제)
            AnalyticsService.shared.countTrashPermanentDelete()

            Task {
                // [BM] 파일 크기 계산 (삭제 전, 비동기 → async 변환)
                let freedBytes = await withCheckedContinuation { (continuation: CheckedContinuation<Int64, Never>) in
                    FileSizeCalculator.shared.calculateTotalSize(for: assets) { bytes in
                        continuation.resume(returning: bytes)
                    }
                }

                do {
                    try await self?.trashStore.emptyTrash()
                    // 삭제 성공 후에만 한도 차감 (iOS 팝업 취소 시 미차감)
                    UsageLimitStore.shared.recordDelete(count: count)
                    // [BM] T057: 삭제 완료 이벤트 (FR-056)
                    AnalyticsService.shared.trackDeletionCompleted(count: count)

                    // [BM] 통계 저장 + 축하 화면 (FR-039, FR-040, T046)
                    await MainActor.run {
                        self?.showCelebrationAfterDeletion(
                            deletedCount: count,
                            freedBytes: freedBytes
                        )
                    }

                    // [BM] T055: 삭제 완료 후 리뷰 요청 평가 (FR-049)
                    if let windowScene = self?.view.window?.windowScene {
                        let prohibited = ReviewService.shared.isProhibitedTiming
                        ReviewService.shared.evaluateAndRequestIfNeeded(
                            from: windowScene,
                            isProhibitedTiming: prohibited
                        )
                    }

                    // E-3: 첫 비우기 완료 안내 트리거
                    self?.showFirstEmptyFeedbackIfNeeded()
                } catch {
                    // 취소 또는 오류 시 조용히 무시 — 한도 미차감
                }
            }
        }
    }

    /// 첫 비우기 완료 시 E-3 안내 표시
    private func showFirstEmptyFeedbackIfNeeded() {
        guard !CoachMarkType.firstEmpty.hasBeenShown else { return }
        guard !CoachMarkManager.shared.isShowing else { return }
        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard let window = view.window else { return }

        CoachMarkOverlayView.showFirstEmptyFeedback(in: window)
    }

    // MARK: - Cell Selection (Override)

    /// 뷰어 열기 (삭제대기함 모드)
    /// 그리드와 동일한 fetchResult를 공유하여 인덱스 일관성 보장
    override func openViewer(for asset: PHAsset, at assetIndex: Int) {
        // 기존 fetchResult 사용 (새로 생성하지 않음 - 인덱스 일관성 보장)
        guard let fetchResult = _trashDataSource.fetchResult else {
            return
        }

        // 뷰어 열림 상태 설정 (데이터 갱신 지연용)
        isViewerOpen = true

        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: .trash
        )

        // 뷰어 뷰컨트롤러 생성 (삭제대기함 모드)
        // assetIndex는 이미 fetchResult 기준이므로 그대로 사용
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: assetIndex,
            mode: .trash
        )
        viewerVC.delegate = self
        activeViewerVC = viewerVC  // weak 참조 저장 (최종 삭제 완료 후 알림용)
        // 그리드 셀 썸네일을 뷰어 초기 이미지로 전달 (전환 공백 방지)
        let cellIndexPath = IndexPath(item: assetIndex + paddingCellCount, section: 0)
        let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell
        viewerVC.initialImage = cell?.thumbnailImageView.image

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

    // MARK: - Cell Configuration (Override)

    /// 셀 추가 설정 (삭제대기함 내에서는 딤드 표시 안 함)
    /// Base에서 이미 configure() 호출되었으므로, isTrashed 상태만 변경
    override func configureCell(_ cell: PhotoCell, at indexPath: IndexPath, asset: PHAsset) {
        // 삭제대기함 내에서는 모두 삭제 대상이므로 딤드 표시 안 함
        // Base에서 isTrashed=true로 설정되었을 수 있으므로 false로 덮어씀
        cell.updateTrashState(false)
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

    /// 삭제 요청 (삭제대기함에서는 사용 안 함)
    func viewerDidRequestDelete(assetID: String) {
        // 삭제대기함에서는 삭제 버튼 대신 복구/최종 삭제 버튼 사용
        // 이 메서드는 호출되지 않음
    }

    /// 복구 요청 (T056)
    func viewerDidRequestRestore(assetID: String) {
        // [Analytics] 이벤트 4-2: 삭제대기함 복구
        AnalyticsService.shared.countTrashRestore()

        trashStore.restore(assetIDs: [assetID])
        // loadTrashedAssets()는 onStateChange 콜백으로 자동 호출됨
    }

    /// 최종 삭제 요청 (T057)
    /// 비동기 작업 - 삭제 완료 후 뷰어에 알림
    /// 게이트 평가 후 통과 시에만 실제 삭제 진행 (BM Phase 3)
    func viewerDidRequestPermanentDelete(assetID: String) {
        evaluateGateAndExecute(trashCount: 1) { [weak self] in
            // [Analytics] 이벤트 4-2: 삭제대기함 최종 삭제
            AnalyticsService.shared.countTrashPermanentDelete()

            Task {
                do {
                    try await self?.trashStore.permanentlyDelete(assetIDs: [assetID])
                    // 삭제 성공 후에만 한도 차감
                    UsageLimitStore.shared.recordDelete(count: 1)
                    // loadTrashedAssets()는 onStateChange 콜백으로 자동 호출됨

                    // 삭제 완료 후 뷰어에 알림 (메인 스레드에서)
                    await MainActor.run {
                        self?.activeViewerVC?.handleDeleteComplete()
                    }
                } catch {
                    // 취소 또는 오류 시 조용히 무시 — 한도 미차감
                }
            }
        }
    }

    /// 뷰어 닫기 시
    /// dismiss 애니메이션 전에 pre-fetch된 결과가 있으면 즉시 적용하여
    /// 그리드가 이미 정렬된 상태로 애니메이션 시작
    /// sourceViewProvider는 pendingScrollAssetID로 정확한 셀을 찾도록 보정
    func viewerWillClose(currentAssetID: String?, originalIndex: Int?) {
        // 뷰어 참조 정리
        activeViewerVC = nil
        // 스크롤 위치 저장 (sourceViewProvider 보정 + 전환 완료 후 스크롤용)
        pendingScrollAssetID = currentAssetID
        // 원본 인덱스 힌트 저장 (buildCache O(n) 회피용)
        pendingScrollOriginalIndex = originalIndex
        // 사용자 스크롤 플래그 초기화
        didUserScrollAfterReturn = false

        // ★ dismiss 애니메이션 전: pre-fetch 결과가 있으면 즉시 적용
        // reloadData 후 셀 인덱스가 바뀌지만, sourceViewProvider가
        // pendingScrollAssetID로 정확한 셀을 찾으므로 줌 트랜지션 정상 동작
        if pendingDataRefresh {
            switch pendingFetchState {
            case .fetched(let fetchResult):
                pendingDataRefresh = false
                pendingFetchState = .none
                _trashDataSource.setFetchResult(fetchResult)
                trashedAssetIDSet = trashStore.trashedAssetIDs
                collectionView.reloadData()
                updateEmptyState()
                updateTrashItemCountSubtitle()
            case .empty:
                pendingDataRefresh = false
                pendingFetchState = .none
                _trashDataSource.setFetchResult(nil)
                trashedAssetIDSet = trashStore.trashedAssetIDs
                collectionView.reloadData()
                updateEmptyState()
                updateTrashItemCountSubtitle()
            default:
                // fetch 미완료: 셀 숨김으로 fallback
                let currentTrashedIDs = trashStore.trashedAssetIDs
                let restoredIDs = trashedAssetIDSet.subtracting(currentTrashedIDs)
                for restoredID in restoredIDs {
                    if let index = _trashDataSource.assetIndex(for: restoredID) {
                        let indexPath = IndexPath(item: index + paddingCellCount, section: 0)
                        collectionView.cellForItem(at: indexPath)?.isHidden = true
                    }
                }
            }
        }
    }

    /// 뷰어가 완전히 닫힌 후 호출 (dismiss/pop 애니메이션 완료 후)
    /// iOS 16~25 Modal (shouldRemovePresentersView=false) 경로에서
    /// viewWillAppear/viewDidAppear가 호출되지 않으므로 이 콜백으로 갱신 트리거
    /// iOS 26+ Navigation Pop에서는 viewDidAppear에서도 호출되므로 이중 호출 가능 → 안전 (2차는 no-op)
    func viewerDidClose() {
        applyPendingViewerReturn()
    }

    /// 뷰어 닫힘 후 대기 중인 작업 처리 (전환 완료 후 호출)
    /// - 뷰어 상태 해제 및 지연된 데이터 갱신 처리
    /// - scroll만 수행하여 깜빡임 방지
    /// - 사용자가 이미 스크롤 중이면 강제 스크롤 skip (롤백 방지)
    private func applyPendingViewerReturn() {
        // ⚠️ dismiss 애니메이션 완료 후에야 뷰어 상태 해제
        isViewerOpen = false

        // 캐싱된 fetch 결과 즉시 적용 (dismiss 애니메이션 완료 후)
        // unhide + setFetchResult + reloadData가 같은 프레임에서 실행 → 재정렬이 보이지 않음
        if pendingDataRefresh {
            pendingDataRefresh = false
            switch pendingFetchState {
            case .empty:
                // 빈 결과 즉시 적용
                _trashDataSource.setFetchResult(nil)
                onDataLoaded()
            case .fetched(let fetchResult):
                // 미리 fetch된 결과 즉시 적용 → reloadData() 즉시 실행
                _trashDataSource.setFetchResult(fetchResult)
                onDataLoaded()
            case .fetching, .none:
                // fetch 진행 중 또는 미시작 → 기존 방식 fallback
                loadTrashedAssets()
            }
            pendingFetchState = .none
        }

        guard let assetID = pendingScrollAssetID else {
            return
        }
        pendingScrollAssetID = nil
        let hintIndex = pendingScrollOriginalIndex
        pendingScrollOriginalIndex = nil

        // 안전 가드 1: 사용자가 복귀 후 스크롤했으면 skip
        if didUserScrollAfterReturn {
            return
        }

        // 안전 가드 2: 현재 스크롤 중이면 skip
        if collectionView.isDragging || collectionView.isDecelerating {
            return
        }

        // ★ O(1) 빠른 경로: 뷰어에서 전달받은 originalIndex로 직접 검증
        let indexPath: IndexPath
        if let hint = hintIndex,
           let fetchResult = _trashDataSource.fetchResult,
           hint >= 0 && hint < fetchResult.count,
           fetchResult.object(at: hint).localIdentifier == assetID {
            indexPath = IndexPath(item: hint + paddingCellCount, section: 0)
        } else if let assetIndex = _trashDataSource.assetIndex(for: assetID) {
            // TrashDataSource는 이미 O(1) 캐시 사용 → fallback 안전
            indexPath = IndexPath(item: assetIndex + paddingCellCount, section: 0)
        } else {
            return
        }

        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        if !visibleIndexPaths.contains(indexPath) {
            collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
        }
    }
}

// MARK: - ZoomTransitionSourceProviding (커스텀 줌 트랜지션)

extension TrashAlbumViewController: ZoomTransitionSourceProviding {

    /// asset ID 기반으로 정확한 IndexPath 계산 (인덱스 시프트 보정)
    /// viewerWillClose에서 reloadData 실행 시 원본 인덱스와 실제 셀 위치가 달라질 수 있으므로,
    /// pendingScrollAssetID로 정확한 셀을 찾음
    private func resolvedIndexPath(for originalIndex: Int) -> IndexPath {
        if let assetID = pendingScrollAssetID,
           let actualIndex = _trashDataSource.assetIndex(for: assetID) {
            return IndexPath(item: actualIndex + paddingCellCount, section: 0)
        }
        // fallback: 원본 인덱스 사용
        return IndexPath(item: originalIndex + paddingCellCount, section: 0)
    }

    /// 줌 애니메이션 시작 뷰 (셀의 이미지 뷰)
    /// - Parameter index: 현재 뷰어의 인덱스
    /// - Returns: PhotoCell의 thumbnailImageView 또는 nil
    func zoomSourceView(for index: Int) -> UIView? {
        let cellIndexPath = resolvedIndexPath(for: index)

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
        let cellIndexPath = resolvedIndexPath(for: index)
        guard let attributes = collectionView.layoutAttributesForItem(at: cellIndexPath) else {
            return nil
        }
        return collectionView.convert(attributes.frame, to: nil)
    }

    /// 해당 인덱스의 셀이 보이도록 스크롤 (Pop 전 호출)
    /// - Parameter index: 스크롤할 원본 인덱스
    func scrollToSourceCell(for index: Int) {
        let cellIndexPath = resolvedIndexPath(for: index)

        // 빈 컬렉션뷰에서는 스크롤 불필요 (마지막 사진 삭제 후 dismiss 시)
        let totalItems = collectionView.numberOfItems(inSection: 0)
        guard cellIndexPath.item < totalItems else { return }

        // 이미 화면에 보이면 스크롤 불필요
        if collectionView.indexPathsForVisibleItems.contains(cellIndexPath) {
            return
        }

        // 즉시 스크롤 (animated: false)
        collectionView.scrollToItem(at: cellIndexPath, at: .centeredVertically, animated: false)
        collectionView.layoutIfNeeded()
    }
}

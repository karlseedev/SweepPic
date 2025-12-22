// GridViewController.swift
// 사진 그리드 뷰컨트롤러
//
// T022: GridViewController 생성
// - UICollectionView, 3열 기본 레이아웃
// - 2pt 셀 간격, 정사각형 비율 (FR-001)
// - CompositionalLayout
//
// T023: 핀치 줌 제스처 구현
// - 1/3/5열 전환, threshold 0.85/1.15, cooldown 200ms, 앵커 유지
//
// T024: ImagePipeline preheat/stopPreheating을 prefetchDataSource와 연동
//
// T025: 스크롤 스로틀링 (100ms 간격) 및 품질 저하 (스크롤 중 50% 썸네일 크기) 구현
//
// T026: PHPhotoLibraryChangeObserver 연동하여 실시간 업데이트
//
// T027-1f: Edge-to-edge 설정
// - contentInsetAdjustmentBehavior = .never
// - contentInset/indicatorInsets = 플로팅 UI 높이
// - viewDidLayoutSubviews, viewSafeAreaInsetsDidChange에서 업데이트
//
// T037~T045: Select 모드 및 다중 선택 삭제 (Phase 5)
// - SelectionManager 연동
// - 탭으로 선택, 드래그로 연속 선택
// - 일괄 삭제 구현

import UIKit
import Photos
import AppCore

/// 사진 그리드 뷰컨트롤러
/// All Photos 그리드를 표시하고 핀치 줌, 스크롤 최적화 등을 처리
final class GridViewController: UIViewController {

    // MARK: - Constants

    /// 셀 간격 (FR-001: 2pt)
    private static let cellSpacing: CGFloat = 2

    /// 열 구성 (1/3/5)
    enum ColumnCount: Int, CaseIterable {
        case one = 1
        case three = 3
        case five = 5

        /// 다음 확대 열 수 (1 → 1, 3 → 1, 5 → 3)
        var zoomIn: ColumnCount {
            switch self {
            case .one: return .one
            case .three: return .one
            case .five: return .three
            }
        }

        /// 다음 축소 열 수 (1 → 3, 3 → 5, 5 → 5)
        var zoomOut: ColumnCount {
            switch self {
            case .one: return .three
            case .three: return .five
            case .five: return .five
            }
        }
    }

    /// 핀치 줌 임계값 (T023)
    private static let pinchZoomInThreshold: CGFloat = 1.15  // 확대 시
    private static let pinchZoomOutThreshold: CGFloat = 0.85 // 축소 시

    /// 핀치 줌 쿨다운 (T023: 200ms)
    private static let pinchCooldown: TimeInterval = 0.2

    /// 스크롤 스로틀링 간격 (T025: 100ms)
    private static let scrollThrottleInterval: TimeInterval = 0.1

    /// 스크롤 중 썸네일 품질 저하 비율 (T025: 50%)
    private static let scrollingThumbnailScale: CGFloat = 0.5

    // MARK: - UI Components

    /// 컬렉션 뷰
    private lazy var collectionView: UICollectionView = {
        let cv = UICollectionView(frame: .zero, collectionViewLayout: createLayout(columns: .three))
        cv.backgroundColor = .black
        cv.translatesAutoresizingMaskIntoConstraints = false
        cv.register(PhotoCell.self, forCellWithReuseIdentifier: PhotoCell.reuseIdentifier)
        cv.delegate = self
        cv.dataSource = self
        cv.prefetchDataSource = self
        cv.alwaysBounceVertical = true
        // T027-1f: Edge-to-edge 설정
        // 플로팅 UI 사용 시 수동으로 contentInset 설정
        cv.contentInsetAdjustmentBehavior = .never
        return cv
    }()

    /// 빈 상태 뷰
    private lazy var emptyStateView: EmptyStateView = {
        let view = EmptyStateView()
        view.configure(
            icon: "photo.on.rectangle",
            title: "사진이 없습니다",
            subtitle: "사진을 촬영하거나 가져오세요"
        )
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Properties

    /// 데이터소스 드라이버
    private let dataSourceDriver: GridDataSourceDriver

    /// 이미지 파이프라인
    private let imagePipeline: ImagePipelineProtocol

    /// 휴지통 스토어
    private let trashStore: TrashStoreProtocol

    /// 현재 열 수
    private var currentColumnCount: ColumnCount = .three

    /// 현재 셀 크기 (캐시)
    private var currentCellSize: CGSize = .zero

    /// 핀치 줌 마지막 실행 시간 (쿨다운용)
    private var lastPinchZoomTime: Date?

    /// 핀치 줌 앵커 에셋 ID
    private var pinchAnchorAssetID: String?

    /// 스크롤 스로틀링 마지막 시간
    private var lastScrollTime: Date?

    /// 스크롤 중 여부
    private var isScrolling: Bool = false

    /// 스크롤 종료 감지 타이머
    private var scrollEndTimer: Timer?

    /// 최초 로드 시 맨 아래로 스크롤 여부 (FR-003)
    private var hasScrolledToBottom: Bool = false

    /// 초기 화면 프리히트 완료 여부 (v6: viewDidAppear에서 호출)
    private var hasPreheatedInitialScreen: Bool = false

    /// Select 모드 여부
    private(set) var isSelectMode: Bool = false

    /// 선택 관리자 (T037)
    private let selectionManager = SelectionManager()

    /// 드래그 선택용 팬 제스처 (T040)
    private var dragSelectGesture: UIPanGestureRecognizer?

    /// 드래그 선택 시작 시점의 인덱스 (T040)
    private var dragSelectStartIndex: Int?

    /// 드래그 선택 중 현재 인덱스 (T040)
    private var dragSelectCurrentIndex: Int?

    /// 드래그 선택 모드: 선택(true) 또는 해제(false) (T040)
    /// 첫 번째 셀이 이미 선택된 상태면 해제 모드, 아니면 선택 모드
    private var dragSelectIsSelecting: Bool = true

    /// 드래그 선택 중 선택/해제된 인덱스 범위 (T040)
    private var dragSelectAffectedIndices: Set<Int> = []

    /// 자동 스크롤 타이머 (화면 가장자리 드래그 시)
    private var autoScrollTimer: Timer?

    /// 자동 스크롤 영역 높이 (화면 상단/하단)
    private static let autoScrollEdgeHeight: CGFloat = 60

    /// 자동 스크롤 속도 (포인트/초)
    private static let autoScrollSpeed: CGFloat = 400

    /// 맨 위 행 빈 셀 개수 (T027-2: 3의 배수가 아닐 시 맨 위 행에 빈 셀)
    /// 최신 사진(맨 아래) 기준 꽉 차게 정렬
    private var paddingCellCount: Int {
        let totalCount = dataSourceDriver.count
        guard totalCount > 0 else { return 0 }
        let columns = currentColumnCount.rawValue
        let remainder = totalCount % columns
        // 나머지가 0이면 빈 셀 없음, 아니면 (열 수 - 나머지) 만큼 빈 셀
        return remainder == 0 ? 0 : (columns - remainder)
    }

    // MARK: - Timing (초기 로딩 측정용)

    /// 로딩 시작 시간 (viewDidLoad 시점)
    private var loadStartTime: CFTimeInterval = 0

    /// 첫 레이아웃 완료 여부
    private var hasLoggedFirstLayout: Bool = false

    /// 첫 셀 표시 완료 여부
    private var hasLoggedFirstCellDisplay: Bool = false

    /// [DEBUG] cellForItemAt 호출 횟수 (초기 3초간)
    private var cellForItemAtCount: Int = 0

    /// [DEBUG] cellForItemAt 누적 시간 (초기 3초간)
    private var cellForItemAtTotalTime: CFTimeInterval = 0

    /// [DEBUG] 이미지 completion 호출 횟수 (초기 3초간)
    private var imageCompletionCount: Int = 0

    /// [DEBUG] cellForItemAt 내부 구간별 누적 시간
    private var cellDequeueTime: CFTimeInterval = 0
    private var cellAssetTime: CFTimeInterval = 0
    private var cellTrashTime: CFTimeInterval = 0
    private var cellConfigureTime: CFTimeInterval = 0

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - dataSourceDriver: 데이터소스 드라이버
    ///   - imagePipeline: 이미지 파이프라인
    ///   - trashStore: 휴지통 스토어
    init(
        dataSourceDriver: GridDataSourceDriver = GridDataSourceDriver(),
        imagePipeline: ImagePipelineProtocol = ImagePipeline.shared,
        trashStore: TrashStoreProtocol = TrashStore.shared
    ) {
        self.dataSourceDriver = dataSourceDriver
        self.imagePipeline = imagePipeline
        self.trashStore = trashStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        self.dataSourceDriver = GridDataSourceDriver()
        self.imagePipeline = ImagePipeline.shared
        self.trashStore = TrashStore.shared
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        // [Timing] 로딩 시작 시간 기록
        loadStartTime = CACurrentMediaTime()
        print("[Timing] === 초기 로딩 시작 ===")

        setupUI()
        setupGestures()
        setupObservers()
        loadData()

        // T027-1f: 플로팅 UI 사용 시에는 setContentScrollView 불필요
        // (시스템 바가 숨겨져 있으므로)
        // iOS 26+에서 시스템 바 사용 시에만 활성화
        if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 바 사용, edge-to-edge 투명 효과 활성화
            setContentScrollView(collectionView, for: .top)
            setContentScrollView(collectionView, for: .bottom)
            // contentInsetAdjustmentBehavior를 automatic으로 복원
            collectionView.contentInsetAdjustmentBehavior = .automatic
        }
    }

    /// 초기 로드 완료 여부 (viewWillAppear 중복 reloadData 방지)
    private var hasInitiallyLoaded: Bool = false

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // [DEBUG] viewWillAppear 호출 시점
        let vwaTime = CACurrentMediaTime()
        let vwaMs = loadStartTime > 0 ? (vwaTime - loadStartTime) * 1000 : -1

        // 초기 진입 시에는 loadData()에서 이미 reloadData() 호출했으므로 스킵
        if !hasInitiallyLoaded {
            hasInitiallyLoaded = true
            print("[Timing] viewWillAppear: +\(String(format: "%.1f", vwaMs))ms (초기 진입 - reloadData 스킵)")
            return
        }

        print("[Timing] viewWillAppear.reloadData: +\(String(format: "%.1f", vwaMs))ms")
        // 화면 표시 시 변경사항 반영 (탭 전환 등)
        collectionView.reloadData()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        // v6: visible indexPaths가 확실히 채워진 시점에 초기 프리히트
        preheatInitialScreen()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 셀 크기 업데이트
        updateCellSize()
        // T027-1f: contentInset 업데이트 (플로팅 UI 높이 반영)
        updateContentInset()

        // [Timing] C) 첫 레이아웃 완료 (1회만)
        if !hasLoggedFirstLayout && loadStartTime > 0 {
            hasLoggedFirstLayout = true
            let layoutTime = CACurrentMediaTime()
            let sinceStart = (layoutTime - loadStartTime) * 1000
            print("[Timing] C) 첫 레이아웃 완료: +\(String(format: "%.1f", sinceStart))ms")
        }
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        // T027-1f: safe area 변경 시 contentInset 재계산
        updateContentInset()
    }

    // MARK: - Setup

    /// UI 설정
    private func setupUI() {
        view.backgroundColor = .black
        title = "Photos"

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

    /// 제스처 설정 (T023, T040)
    private func setupGestures() {
        // 핀치 줌 제스처 (T023)
        let pinchGesture = UIPinchGestureRecognizer(target: self, action: #selector(handlePinchGesture(_:)))
        collectionView.addGestureRecognizer(pinchGesture)

        // 드래그 선택 제스처 (T040)
        // Select 모드에서만 활성화됨
        let dragGesture = UIPanGestureRecognizer(target: self, action: #selector(handleDragSelectGesture(_:)))
        dragGesture.minimumNumberOfTouches = 1
        dragGesture.maximumNumberOfTouches = 1
        dragGesture.delegate = self
        dragGesture.isEnabled = false // 기본 비활성화, Select 모드 진입 시 활성화
        collectionView.addGestureRecognizer(dragGesture)
        dragSelectGesture = dragGesture
    }

    /// 옵저버 설정 (T026, T037)
    private func setupObservers() {
        // PhotoLibrary 변경 감지
        PhotoLibraryService.shared.onLibraryChange { [weak self] change in
            self?.handleLibraryChange(change)
        }
        PhotoLibraryService.shared.startObservingChanges()

        // TrashStore 변경 감지
        trashStore.onStateChange { [weak self] trashedAssetIDs in
            self?.handleTrashStateChange(trashedAssetIDs)
        }

        // SelectionManager 델리게이트 설정 (T037)
        selectionManager.delegate = self
    }

    /// 데이터 로드
    private func loadData() {
        dataSourceDriver.reloadData { [weak self] in
            guard let self = self else { return }

            // 빈 상태 업데이트
            self.updateEmptyState()

            // [Timing] B) reloadData 호출 시점
            let reloadStart = CACurrentMediaTime()
            let sinceStart = (reloadStart - self.loadStartTime) * 1000
            print("[Timing] B) reloadData 호출: +\(String(format: "%.1f", sinceStart))ms")

            // 컬렉션 뷰 리로드
            self.collectionView.reloadData()

            // [Timing] B) reloadData 완료 (호출 자체는 즉시 리턴)
            let reloadEnd = CACurrentMediaTime()
            let reloadMs = (reloadEnd - reloadStart) * 1000
            print("[Timing] B) reloadData 완료: \(String(format: "%.1f", reloadMs))ms (호출만)")

            // FR-003: 첫 진입 시 맨 아래(최신 사진)로 스크롤
            if !self.hasScrolledToBottom && self.dataSourceDriver.count > 0 {
                self.hasScrolledToBottom = true

                // [Timing] E0) main.async 스케줄 시점
                let e0Time = CACurrentMediaTime()
                let e0Ms = (e0Time - self.loadStartTime) * 1000
                print("[Timing] E0) main.async 스케줄: +\(String(format: "%.1f", e0Ms))ms")

                // 레이아웃이 완료된 후 스크롤 (다음 런루프에서 실행)
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }

                    // [Timing] E1) main.async 블록 실행 시작
                    let e1Time = CACurrentMediaTime()
                    let e1Ms = (e1Time - self.loadStartTime) * 1000
                    let queueWaitMs = (e1Time - e0Time) * 1000
                    print("[Timing] E1) main.async 실행 시작: +\(String(format: "%.1f", e1Ms))ms (큐 대기: \(String(format: "%.1f", queueWaitMs))ms)")

                    let lastIndex = self.dataSourceDriver.count - 1
                    let lastIndexPath = IndexPath(item: lastIndex, section: 0)
                    self.collectionView.scrollToItem(
                        at: lastIndexPath,
                        at: .bottom,
                        animated: false
                    )

                    // [Timing] E2) scrollToItem 완료 시점
                    let e2Time = CACurrentMediaTime()
                    let e2Ms = (e2Time - self.loadStartTime) * 1000
                    let scrollMs = (e2Time - e1Time) * 1000
                    print("[Timing] E2) scrollToItem 완료: +\(String(format: "%.1f", e2Ms))ms (스크롤: \(String(format: "%.1f", scrollMs))ms)")
                    print("[Timing] === 초기 로딩 완료 ===")

                    // [DEBUG] 최종 통계 출력
                    print("[Timing] 최종 통계: cellForItemAt \(self.cellForItemAtCount)회, 총 \(String(format: "%.1f", self.cellForItemAtTotalTime))ms")
                    print("[Timing] 구간별: dequeue=\(String(format: "%.1f", self.cellDequeueTime*1000))ms, asset=\(String(format: "%.1f", self.cellAssetTime*1000))ms, trash=\(String(format: "%.1f", self.cellTrashTime*1000))ms, configure=\(String(format: "%.1f", self.cellConfigureTime*1000))ms")
                }
            }

            print("[GridViewController] Data loaded: \(self.dataSourceDriver.count) items")
        }
    }

    // MARK: - Layout

    /// CompositionalLayout 생성
    /// - Parameter columns: 열 수
    /// - Returns: UICollectionViewLayout
    private func createLayout(columns: ColumnCount) -> UICollectionViewLayout {
        let layout = UICollectionViewCompositionalLayout { _, environment in
            let spacing = Self.cellSpacing
            let columnCount = CGFloat(columns.rawValue)

            // 셀 크기 계산 (정사각형)
            let totalSpacing = spacing * (columnCount - 1)
            let availableWidth = environment.container.effectiveContentSize.width - totalSpacing
            let cellWidth = floor(availableWidth / columnCount)

            // 아이템 크기
            let itemSize = NSCollectionLayoutSize(
                widthDimension: .absolute(cellWidth),
                heightDimension: .absolute(cellWidth) // 정사각형 비율 (FR-001)
            )
            let item = NSCollectionLayoutItem(layoutSize: itemSize)

            // 그룹 (가로)
            let groupSize = NSCollectionLayoutSize(
                widthDimension: .fractionalWidth(1.0),
                heightDimension: .absolute(cellWidth)
            )
            let group = NSCollectionLayoutGroup.horizontal(
                layoutSize: groupSize,
                repeatingSubitem: item,
                count: columns.rawValue
            )
            group.interItemSpacing = .fixed(spacing)

            // 섹션
            let section = NSCollectionLayoutSection(group: group)
            section.interGroupSpacing = spacing
            // Edge-to-edge: safe area 무시 (iOS 14+)
            section.contentInsetsReference = .none

            return section
        }

        return layout
    }

    /// 셀 크기 업데이트
    private func updateCellSize() {
        let spacing = Self.cellSpacing
        let columnCount = CGFloat(currentColumnCount.rawValue)
        let totalSpacing = spacing * (columnCount - 1)
        let availableWidth = view.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columnCount)

        currentCellSize = CGSize(width: cellWidth, height: cellWidth)
    }

    /// T027-1f: contentInset 업데이트 (플로팅 UI 높이 반영)
    private func updateContentInset() {
        // iOS 26+에서는 시스템 자동 조정 사용
        if #available(iOS 26.0, *) {
            return
        }

        // TabBarController에서 오버레이 높이 가져오기
        guard let tabBarController = tabBarController as? TabBarController,
              let heights = tabBarController.getOverlayHeights() else {
            // 플로팅 UI가 없으면 safe area만 적용
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

        // 플로팅 UI 높이를 contentInset으로 설정
        let inset = UIEdgeInsets(
            top: heights.top,
            left: 0,
            bottom: heights.bottom,
            right: 0
        )

        collectionView.contentInset = inset
        collectionView.scrollIndicatorInsets = inset

        print("[GridViewController] ContentInset updated - top: \(heights.top), bottom: \(heights.bottom)")
    }

    /// 현재 썸네일 크기 반환 (스크롤 상태에 따라 품질 저하 적용)
    private func thumbnailSize(forScrolling: Bool = false) -> CGSize {
        let baseSize = currentCellSize
        let scale = UIScreen.main.scale

        if forScrolling || isScrolling {
            // T025: 스크롤 중 50% 크기
            return CGSize(
                width: baseSize.width * scale * Self.scrollingThumbnailScale,
                height: baseSize.height * scale * Self.scrollingThumbnailScale
            )
        } else {
            return CGSize(
                width: baseSize.width * scale,
                height: baseSize.height * scale
            )
        }
    }

    // MARK: - Pinch Zoom (T023)

    /// 핀치 줌 제스처 핸들러
    @objc private func handlePinchGesture(_ gesture: UIPinchGestureRecognizer) {
        switch gesture.state {
        case .began:
            // 앵커 에셋 ID 저장 (핀치 시작 위치의 셀)
            let location = gesture.location(in: collectionView)
            if let indexPath = collectionView.indexPathForItem(at: location) {
                pinchAnchorAssetID = dataSourceDriver.assetID(at: indexPath)
            }

        case .changed:
            // 쿨다운 체크 (200ms)
            if let lastTime = lastPinchZoomTime,
               Date().timeIntervalSince(lastTime) < Self.pinchCooldown {
                return
            }

            // 임계값 체크
            let scale = gesture.scale

            var newColumnCount: ColumnCount?

            if scale > Self.pinchZoomInThreshold {
                // 확대 (열 수 감소)
                newColumnCount = currentColumnCount.zoomIn
            } else if scale < Self.pinchZoomOutThreshold {
                // 축소 (열 수 증가)
                newColumnCount = currentColumnCount.zoomOut
            }

            // 열 수가 변경되면 레이아웃 업데이트
            if let newCount = newColumnCount, newCount != currentColumnCount {
                performZoom(to: newCount)
                gesture.scale = 1.0 // 스케일 리셋
            }

        case .ended, .cancelled:
            pinchAnchorAssetID = nil

        default:
            break
        }
    }

    /// 줌 수행
    /// - Parameter columns: 새 열 수
    private func performZoom(to columns: ColumnCount) {
        // 쿨다운 시간 기록
        lastPinchZoomTime = Date()

        // 현재 앵커 IndexPath 저장
        let anchorIndexPath: IndexPath?
        if let anchorID = pinchAnchorAssetID {
            anchorIndexPath = dataSourceDriver.indexPath(for: anchorID)
        } else {
            // 앵커가 없으면 화면 중앙 셀 사용
            let centerPoint = CGPoint(
                x: collectionView.bounds.midX,
                y: collectionView.bounds.midY + collectionView.contentOffset.y
            )
            anchorIndexPath = collectionView.indexPathForItem(at: centerPoint)
        }

        // 열 수 업데이트
        currentColumnCount = columns
        updateCellSize()

        // 레이아웃 애니메이션
        UIView.animate(withDuration: 0.25) { [weak self] in
            guard let self = self else { return }

            // 새 레이아웃 적용
            self.collectionView.setCollectionViewLayout(
                self.createLayout(columns: columns),
                animated: false
            )

            // 앵커 위치로 스크롤 (drift 0px 목표)
            if let indexPath = anchorIndexPath {
                self.collectionView.scrollToItem(
                    at: indexPath,
                    at: .centeredVertically,
                    animated: false
                )
            }
        }

        print("[GridViewController] Zoom to \(columns.rawValue) columns")
    }

    // MARK: - Library Change (T026)

    /// 사진 라이브러리 변경 처리
    private func handleLibraryChange(_ change: PHChange) {
        dataSourceDriver.applyChange(
            change,
            to: collectionView,
            anchorAssetID: nil
        ) { [weak self] _ in
            self?.updateEmptyState()
        }
    }

    /// 휴지통 상태 변경 처리
    private func handleTrashStateChange(_ trashedAssetIDs: Set<String>) {
        dataSourceDriver.applyTrashStateChange(
            trashedAssetIDs: trashedAssetIDs,
            to: collectionView
        )
    }

    // MARK: - Empty State (T070)

    /// 빈 상태 업데이트
    private func updateEmptyState() {
        let isEmpty = dataSourceDriver.count == 0
        emptyStateView.isHidden = !isEmpty
        collectionView.isHidden = isEmpty
    }

    // MARK: - Scroll Optimization (T025)

    /// 스크롤 시작
    private func scrollDidBegin() {
        guard !isScrolling else { return }
        isScrolling = true

        // 스크롤 종료 타이머 취소
        scrollEndTimer?.invalidate()
    }

    /// 스크롤 종료
    private func scrollDidEnd() {
        // 디바운스 (100ms 후 실제 종료로 간주)
        scrollEndTimer?.invalidate()
        scrollEndTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { [weak self] _ in
            self?.isScrolling = false

            // Note: PHImageRequestOptions.deliveryMode = .opportunistic 모드에서는
            // 저해상도 → 고해상도가 자동으로 전달되므로 별도 리로드 불필요
            // reloadItems 호출 시 prepareForReuse()가 호출되어 이미지가 깜빡거림
        }
    }

    // MARK: - Initial Preheat (v6)

    /// 첫 화면 프리히트 (viewDidAppear 이후 호출 - visible 보장)
    /// - visible indexPaths가 확실히 채워진 시점에 호출
    /// - +1 화면 반경까지 프리히트
    private func preheatInitialScreen() {
        guard !hasPreheatedInitialScreen else { return }
        hasPreheatedInitialScreen = true

        // 정확한 pixelSize (pt × scale)
        let scale = UIScreen.main.scale
        let targetSize = CGSize(
            width: currentCellSize.width * scale,
            height: currentCellSize.height * scale
        )

        // viewDidAppear 이후이므로 visible indexPaths 확실히 존재
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        guard !visibleIndexPaths.isEmpty else {
            // 만약을 위한 fallback
            hasPreheatedInitialScreen = false
            print("[GridViewController] preheatInitialScreen: visible empty, will retry")
            return
        }

        // padding 오프셋 적용하여 실제 asset indexPaths 변환
        let padding = paddingCellCount
        let assetIndexPaths = visibleIndexPaths.compactMap { indexPath -> IndexPath? in
            guard indexPath.item >= padding else { return nil }
            return IndexPath(item: indexPath.item - padding, section: indexPath.section)
        }

        // +1 화면 반경 (약 21개 셀 = 7행 × 3열)
        let extendedIndexPaths = extendIndexPaths(assetIndexPaths, by: 21)

        // PHAsset 배열 가져오기
        let assets = extendedIndexPaths.compactMap { dataSourceDriver.asset(at: $0) }
        guard !assets.isEmpty else {
            print("[GridViewController] preheatInitialScreen: no assets to preheat")
            return
        }

        // 백그라운드에서 프리히트 (v6: 메인 스레드 블로킹 방지)
        DispatchQueue.global(qos: .userInitiated).async {
            ImagePipeline.shared.preheatAssets(assets, targetSize: targetSize)
        }

        print("[GridViewController] preheatInitialScreen: \(assets.count) assets")
    }

    /// IndexPath 배열을 확장 (앞뒤로 지정 개수만큼)
    private func extendIndexPaths(_ indexPaths: [IndexPath], by count: Int) -> [IndexPath] {
        guard !indexPaths.isEmpty else { return [] }

        let sortedItems = indexPaths.map { $0.item }.sorted()
        guard let minItem = sortedItems.first,
              let maxItem = sortedItems.last else { return indexPaths }

        // 확장 범위 계산
        let extendedMin = max(0, minItem - count)
        let extendedMax = min(dataSourceDriver.count - 1, maxItem + count)

        guard extendedMin <= extendedMax else { return indexPaths }

        return (extendedMin...extendedMax).map { IndexPath(item: $0, section: 0) }
    }
}

// MARK: - UICollectionViewDataSource

extension GridViewController: UICollectionViewDataSource {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        // 실제 사진 수 + 맨 위 행 빈 셀 수
        return dataSourceDriver.count + paddingCellCount
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        // [DEBUG] cellForItemAt 시간 측정 (초기 3초간)
        let cellStart = CACurrentMediaTime()
        let sinceStart = loadStartTime > 0 ? (cellStart - loadStartTime) * 1000 : -1
        let isInitialPeriod = sinceStart >= 0 && sinceStart < 3000

        // [DEBUG] 구간별 시간 측정용
        var t0, t1, t2, t3, t4: CFTimeInterval
        t0 = cellStart

        guard let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: PhotoCell.reuseIdentifier,
            for: indexPath
        ) as? PhotoCell else {
            return UICollectionViewCell()
        }

        t1 = CACurrentMediaTime() // dequeue 완료

        // T027-2: 맨 위 행 빈 셀 처리
        let padding = paddingCellCount
        if indexPath.item < padding {
            // 빈 셀 - 투명하게 표시
            cell.configureAsEmpty()
            return cell
        }

        // 실제 에셋 인덱스 계산 (padding 오프셋 적용)
        let assetIndexPath = IndexPath(item: indexPath.item - padding, section: indexPath.section)

        // 에셋 정보 가져오기
        guard let asset = dataSourceDriver.asset(at: assetIndexPath) else {
            return cell
        }

        t2 = CACurrentMediaTime() // asset 조회 완료

        let isTrashed = trashStore.isTrashed(asset.localIdentifier)

        t3 = CACurrentMediaTime() // trash 체크 완료

        // 셀 설정 (PHAsset 직접 전달 - 성능 최적화)
        cell.configure(
            asset: asset,
            isTrashed: isTrashed,
            targetSize: thumbnailSize()
        )

        t4 = CACurrentMediaTime() // configure 완료

        // [DEBUG] 구간별 시간 누적
        if isInitialPeriod {
            cellDequeueTime += (t1 - t0)
            cellAssetTime += (t2 - t1)
            cellTrashTime += (t3 - t2)
            cellConfigureTime += (t4 - t3)

            let cellMs = (t4 - t0) * 1000
            cellForItemAtCount += 1
            cellForItemAtTotalTime += cellMs

            // 매 10번째에 구간별 로그 출력
            if cellForItemAtCount % 10 == 0 {
                print("[Timing] cellForItemAt #\(cellForItemAtCount): dequeue=\(String(format: "%.1f", cellDequeueTime*1000))ms, asset=\(String(format: "%.1f", cellAssetTime*1000))ms, trash=\(String(format: "%.1f", cellTrashTime*1000))ms, configure=\(String(format: "%.1f", cellConfigureTime*1000))ms")
            }
        }

        // Select 모드일 때 선택 상태 표시 (T039, T045)
        if isSelectMode {
            let isSelected = selectionManager.isSelected(asset.localIdentifier)
            cell.isSelectedForDeletion = isSelected
        } else {
            cell.isSelectedForDeletion = false
        }

        return cell
    }
}

// MARK: - UICollectionViewDelegate

extension GridViewController: UICollectionViewDelegate {

    // [Timing] D) 첫 셀 표시 완료
    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        if !hasLoggedFirstCellDisplay && loadStartTime > 0 {
            hasLoggedFirstCellDisplay = true
            let displayTime = CACurrentMediaTime()
            let sinceStart = (displayTime - loadStartTime) * 1000
            print("[Timing] D) 첫 셀 표시: +\(String(format: "%.1f", sinceStart))ms (indexPath: \(indexPath))")
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        // T027-2: 빈 셀 탭 무시
        let padding = paddingCellCount
        guard indexPath.item >= padding else { return }

        // Select 모드일 때는 선택 토글 (T039)
        if isSelectMode {
            toggleSelection(at: indexPath)
            return
        }

        // 실제 에셋 인덱스 계산
        let assetIndexPath = IndexPath(item: indexPath.item - padding, section: indexPath.section)

        guard let fetchResult = dataSourceDriver.fetchResult else { return }

        // 휴지통 사진인지 확인
        let isTrashed = dataSourceDriver.assetID(at: assetIndexPath).flatMap { trashStore.isTrashed($0) } ?? false

        // 뷰어 모드 결정 (휴지통 사진은 trash 모드)
        let mode: ViewerMode = isTrashed ? .trash : .normal

        // 뷰어 코디네이터 생성 (모드에 따라 필터링됨)
        let coordinator = ViewerCoordinator(
            fetchResult: fetchResult,
            trashStore: trashStore,
            viewerMode: mode
        )

        // 원본 인덱스를 필터링된 인덱스로 변환 (padding 제외한 실제 인덱스 사용)
        guard let filteredIndex = coordinator.filteredIndex(from: assetIndexPath.item) else {
            print("[GridViewController] Failed to find filtered index for \(assetIndexPath.item)")
            return
        }

        // 뷰어 뷰컨트롤러 생성
        let viewerVC = ViewerViewController(
            coordinator: coordinator,
            startIndex: filteredIndex,
            mode: mode
        )
        viewerVC.delegate = self

        // TODO: T032 줌 전환 애니메이션은 Phase 9에서 iOS 사진 앱 수준으로 구현 예정
        // 현재는 기본 전환 사용 (fullScreen + crossDissolve)

        // 뷰어 표시
        present(viewerVC, animated: true)

        print("[GridViewController] Opening viewer at filtered index \(filteredIndex) (original: \(indexPath.item)), mode: \(mode)")
    }

    func scrollViewWillBeginDragging(_: UIScrollView) {
        scrollDidBegin()
    }

    func scrollViewDidEndDragging(_: UIScrollView, willDecelerate decelerate: Bool) {
        if !decelerate {
            scrollDidEnd()
        }
    }

    func scrollViewDidEndDecelerating(_: UIScrollView) {
        scrollDidEnd()
    }
}

// MARK: - UICollectionViewDataSourcePrefetching (T024)

extension GridViewController: UICollectionViewDataSourcePrefetching {

    func collectionView(_ collectionView: UICollectionView, prefetchItemsAt indexPaths: [IndexPath]) {
        // 스크롤 스로틀링 (T025: 100ms 간격)
        if let lastTime = lastScrollTime,
           Date().timeIntervalSince(lastTime) < Self.scrollThrottleInterval {
            return
        }
        lastScrollTime = Date()

        // 프리히트할 에셋 ID
        let assetIDs = dataSourceDriver.assetIDs(for: indexPaths)
        guard !assetIDs.isEmpty else { return }

        // ImagePipeline preheat
        imagePipeline.preheat(
            assetIDs: assetIDs,
            targetSize: thumbnailSize(forScrolling: true) // 스크롤 중이므로 저품질
        )
    }

    func collectionView(_ collectionView: UICollectionView, cancelPrefetchingForItemsAt indexPaths: [IndexPath]) {
        // 프리히트 취소
        let assetIDs = dataSourceDriver.assetIDs(for: indexPaths)
        guard !assetIDs.isEmpty else { return }

        imagePipeline.stopPreheating(assetIDs: assetIDs)
    }
}

// MARK: - ViewerViewControllerDelegate (T036)

extension GridViewController: ViewerViewControllerDelegate {

    /// 사진 삭제 요청 (앱 내 휴지통으로 이동)
    /// T036: TrashStore 즉시 저장 연동
    func viewerDidRequestDelete(assetID: String) {
        // TrashStore에 이동 (즉시 저장됨)
        trashStore.moveToTrash(assetIDs: [assetID])

        // 그리드 셀 업데이트 (딤드 표시)
        if let indexPath = dataSourceDriver.indexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        print("[GridViewController] Moved to trash: \(assetID.prefix(8))...")
    }

    /// 사진 복구 요청 (휴지통에서 복원)
    func viewerDidRequestRestore(assetID: String) {
        // TrashStore에서 복구 (즉시 저장됨)
        trashStore.restore(assetIDs: [assetID])

        // 그리드 셀 업데이트 (딤드 제거)
        if let indexPath = dataSourceDriver.indexPath(for: assetID) {
            collectionView.reloadItems(at: [indexPath])
        }

        print("[GridViewController] Restored: \(assetID.prefix(8))...")
    }

    /// 사진 완전삭제 요청 (iOS 휴지통으로 이동)
    func viewerDidRequestPermanentDelete(assetID: String) {
        // TrashStore에서 완전삭제 (iOS 시스템 팝업 표시)
        Task {
            do {
                try await trashStore.permanentlyDelete(assetIDs: [assetID])
                print("[GridViewController] Permanently deleted: \(assetID.prefix(8))...")
            } catch {
                print("[GridViewController] Failed to permanently delete: \(error)")
            }
        }
    }

    /// 뷰어가 닫힐 때 호출
    func viewerWillClose(currentAssetID: String?) {
        // 그리드 갱신 (딤드 상태 등 반영)
        collectionView.reloadData()

        // iOS 사진 앱처럼: 마지막 보던 사진이 화면에 없으면 해당 위치로 스크롤
        if let assetID = currentAssetID,
           let indexPath = dataSourceDriver.indexPath(for: assetID) {

            // 현재 보이는 셀인지 확인
            let visibleIndexPaths = collectionView.indexPathsForVisibleItems
            if !visibleIndexPaths.contains(indexPath) {
                // 화면에 없으면 스크롤 (중앙에 위치하도록)
                collectionView.scrollToItem(at: indexPath, at: .centeredVertically, animated: false)
            }
        }

        print("[GridViewController] Viewer closed, last asset: \(currentAssetID?.prefix(8) ?? "nil")...")
    }
}

// MARK: - Select Mode (T037~T045)

extension GridViewController {

    /// Select 모드 진입 (T038)
    /// TabBarController에서 호출 (플로팅 UI의 Select 버튼 탭 시)
    func enterSelectMode() {
        guard !isSelectMode else { return }
        isSelectMode = true

        // 플로팅 오버레이에 Select 모드 진입 알림
        if let tabBarController = tabBarController as? TabBarController {
            tabBarController.floatingOverlay?.enterSelectMode()
        }

        // 드래그 선택 제스처 활성화 (T040)
        dragSelectGesture?.isEnabled = true

        // 컬렉션 뷰 리로드 (선택 UI 표시를 위해)
        collectionView.reloadData()

        print("[GridViewController] Entered select mode")
    }

    /// Select 모드 종료 (T038)
    /// TabBarController에서 호출 (Cancel 버튼 탭 시)
    func exitSelectMode() {
        guard isSelectMode else { return }
        isSelectMode = false

        // 플로팅 오버레이에 Select 모드 종료 알림
        if let tabBarController = tabBarController as? TabBarController {
            tabBarController.floatingOverlay?.exitSelectMode()
        }

        // 드래그 선택 제스처 비활성화 (T040)
        dragSelectGesture?.isEnabled = false

        // 선택 상태 초기화 (T037)
        selectionManager.clearSelection()

        // 컬렉션 뷰 리로드 (선택 UI 제거를 위해)
        collectionView.reloadData()

        print("[GridViewController] Exited select mode")
    }

    /// 선택된 사진 삭제 (T043)
    /// TabBarController에서 호출 (Delete 버튼 탭 시)
    func deleteSelectedPhotos() {
        let selectedAssetIDs = selectionManager.selectedAssetIDs
        guard !selectedAssetIDs.isEmpty else {
            print("[GridViewController] No photos selected for deletion")
            return
        }

        // TrashStore에 이동 (즉시 저장됨)
        trashStore.moveToTrash(assetIDs: Array(selectedAssetIDs))

        print("[GridViewController] Moved \(selectedAssetIDs.count) photos to trash")

        // 선택 상태 초기화 및 Select 모드 종료
        selectionManager.clearSelection()
        exitSelectMode()
    }

    /// 셀 선택 토글 (T039)
    /// - Parameter indexPath: 선택할 셀의 indexPath
    /// - Returns: 토글 후 선택 상태
    @discardableResult
    private func toggleSelection(at indexPath: IndexPath) -> Bool {
        // 빈 셀은 선택 불가
        let padding = paddingCellCount
        guard indexPath.item >= padding else { return false }

        // 실제 에셋 인덱스 계산
        let assetIndexPath = IndexPath(item: indexPath.item - padding, section: indexPath.section)

        guard let assetID = dataSourceDriver.assetID(at: assetIndexPath) else { return false }

        // 딤드 사진(휴지통)은 선택 불가 (T044)
        guard !trashStore.isTrashed(assetID) else {
            print("[GridViewController] Cannot select trashed photo: \(assetID.prefix(8))...")
            return false
        }

        // 선택 토글
        let isSelected = selectionManager.toggle(assetID)

        // 셀 UI 업데이트
        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
            cell.isSelectedForDeletion = isSelected
        }

        return isSelected
    }
}

// MARK: - Drag Selection (T040)

extension GridViewController {

    /// 드래그 선택 제스처 핸들러
    /// iOS 사진 앱 동작:
    /// - 수평 드래그로 시작해야만 드래그 선택 모드 진입
    /// - 수직 드래그는 스크롤
    /// - 뒤로 드래그하면 선택 해제
    /// - 화면 가장자리로 드래그하면 자동 스크롤
    @objc private func handleDragSelectGesture(_ gesture: UIPanGestureRecognizer) {
        guard isSelectMode else { return }

        let location = gesture.location(in: collectionView)
        let locationInView = gesture.location(in: view)

        switch gesture.state {
        case .began:
            handleDragSelectBegan(at: location)

        case .changed:
            handleDragSelectChanged(at: location)
            handleAutoScroll(at: locationInView)

        case .ended, .cancelled:
            handleDragSelectEnded()

        default:
            break
        }
    }

    /// 드래그 선택 시작 처리
    private func handleDragSelectBegan(at location: CGPoint) {
        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        let padding = paddingCellCount
        guard indexPath.item >= padding else { return }

        let assetIndex = indexPath.item - padding
        let assetIndexPath = IndexPath(item: assetIndex, section: indexPath.section)

        guard let assetID = dataSourceDriver.assetID(at: assetIndexPath),
              !trashStore.isTrashed(assetID) else { return }

        // 드래그 선택 상태 초기화
        dragSelectStartIndex = indexPath.item
        dragSelectCurrentIndex = indexPath.item
        dragSelectAffectedIndices = [indexPath.item]

        // 첫 번째 셀이 이미 선택된 상태인지 확인
        // 선택된 상태면 해제 모드, 아니면 선택 모드
        dragSelectIsSelecting = !selectionManager.isSelected(assetID)

        // 첫 번째 셀 선택/해제
        if dragSelectIsSelecting {
            selectionManager.select(assetID)
        } else {
            selectionManager.deselect(assetID)
        }

        // 셀 UI 업데이트
        if let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell {
            cell.isSelectedForDeletion = dragSelectIsSelecting
        }

        print("[GridViewController] Drag select began at index \(indexPath.item), mode: \(dragSelectIsSelecting ? "select" : "deselect")")
    }

    /// 드래그 선택 변경 처리
    private func handleDragSelectChanged(at location: CGPoint) {
        guard let startIndex = dragSelectStartIndex,
              let previousIndex = dragSelectCurrentIndex else { return }

        guard let indexPath = collectionView.indexPathForItem(at: location) else { return }

        let currentIndex = indexPath.item
        let padding = paddingCellCount

        // 빈 셀 영역은 무시
        guard currentIndex >= padding else { return }

        // 같은 셀이면 무시
        guard currentIndex != previousIndex else { return }

        dragSelectCurrentIndex = currentIndex

        // 범위 계산: startIndex ~ currentIndex
        let minIndex = min(startIndex, currentIndex)
        let maxIndex = max(startIndex, currentIndex)
        let currentRange = Set(minIndex...maxIndex)

        // 이전에 영향받았던 인덱스 중 현재 범위에 없는 것들 (뒤로 드래그해서 벗어난 셀들)
        let indicesNoLongerInRange = dragSelectAffectedIndices.subtracting(currentRange)

        // 범위에서 벗어난 셀들: 원래 상태로 복원
        for index in indicesNoLongerInRange {
            guard index >= padding else { continue }

            let assetIndex = index - padding
            let assetIndexPath = IndexPath(item: assetIndex, section: 0)

            guard let assetID = dataSourceDriver.assetID(at: assetIndexPath),
                  !trashStore.isTrashed(assetID) else { continue }

            // 원래 상태로 복원 (선택 모드였으면 해제, 해제 모드였으면 선택)
            if dragSelectIsSelecting {
                selectionManager.deselect(assetID)
            } else {
                selectionManager.select(assetID)
            }

            // 셀 UI 업데이트
            let cellIndexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell {
                cell.isSelectedForDeletion = !dragSelectIsSelecting
            }
        }

        // 현재 범위 내의 새로운 셀들 처리
        let newIndicesInRange = currentRange.subtracting(dragSelectAffectedIndices)

        for index in newIndicesInRange {
            guard index >= padding else { continue }

            let assetIndex = index - padding
            let assetIndexPath = IndexPath(item: assetIndex, section: 0)

            guard let assetID = dataSourceDriver.assetID(at: assetIndexPath),
                  !trashStore.isTrashed(assetID) else { continue }

            // 선택/해제 모드에 따라 처리
            if dragSelectIsSelecting {
                selectionManager.select(assetID)
            } else {
                selectionManager.deselect(assetID)
            }

            // 셀 UI 업데이트
            let cellIndexPath = IndexPath(item: index, section: 0)
            if let cell = collectionView.cellForItem(at: cellIndexPath) as? PhotoCell {
                cell.isSelectedForDeletion = dragSelectIsSelecting
            }
        }

        // 영향받은 인덱스 업데이트
        dragSelectAffectedIndices = currentRange
    }

    /// 드래그 선택 종료 처리
    private func handleDragSelectEnded() {
        // 자동 스크롤 타이머 중지
        stopAutoScroll()

        // 상태 초기화
        dragSelectStartIndex = nil
        dragSelectCurrentIndex = nil
        dragSelectAffectedIndices = []

        print("[GridViewController] Drag select ended")
    }

    /// 자동 스크롤 처리 (화면 가장자리 드래그 시)
    private func handleAutoScroll(at locationInView: CGPoint) {
        let topEdge = view.safeAreaInsets.top + Self.autoScrollEdgeHeight
        let bottomEdge = view.bounds.height - view.safeAreaInsets.bottom - Self.autoScrollEdgeHeight

        if locationInView.y < topEdge {
            // 상단 가장자리: 위로 스크롤
            startAutoScroll(direction: -1)
        } else if locationInView.y > bottomEdge {
            // 하단 가장자리: 아래로 스크롤
            startAutoScroll(direction: 1)
        } else {
            // 가장자리 아님: 자동 스크롤 중지
            stopAutoScroll()
        }
    }

    /// 자동 스크롤 시작
    /// - Parameter direction: 스크롤 방향 (-1: 위, 1: 아래)
    private func startAutoScroll(direction: CGFloat) {
        // 이미 타이머가 있으면 무시
        guard autoScrollTimer == nil else { return }

        autoScrollTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            let scrollAmount = Self.autoScrollSpeed / 60.0 * direction
            var newOffset = self.collectionView.contentOffset
            newOffset.y += scrollAmount

            // 범위 제한
            let minY = -self.collectionView.contentInset.top
            let maxY = self.collectionView.contentSize.height - self.collectionView.bounds.height + self.collectionView.contentInset.bottom

            newOffset.y = max(minY, min(maxY, newOffset.y))

            self.collectionView.setContentOffset(newOffset, animated: false)

            // 스크롤 중 현재 위치의 셀도 선택/해제 처리
            if let gesture = self.dragSelectGesture {
                let location = gesture.location(in: self.collectionView)
                self.handleDragSelectChanged(at: location)
            }
        }
    }

    /// 자동 스크롤 중지
    private func stopAutoScroll() {
        autoScrollTimer?.invalidate()
        autoScrollTimer = nil
    }
}

// MARK: - UIGestureRecognizerDelegate (T040)

extension GridViewController: UIGestureRecognizerDelegate {

    /// 제스처 동시 인식 허용
    /// 핀치 줌과 드래그 선택이 동시에 동작할 수 있도록
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 드래그 선택 제스처는 핀치와 동시 인식 허용
        if gestureRecognizer == dragSelectGesture {
            return otherGestureRecognizer is UIPinchGestureRecognizer
        }
        return false
    }

    /// 드래그 선택 제스처 시작 조건
    /// iOS 사진 앱 동작: 수평 드래그로 시작해야만 드래그 선택 모드
    /// 수직 드래그만 하면 스크롤 (드래그 선택 제스처 실패)
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        if gestureRecognizer == dragSelectGesture {
            guard isSelectMode else { return false }

            // 팬 제스처의 이동 방향 확인
            guard let panGesture = gestureRecognizer as? UIPanGestureRecognizer else { return false }

            let velocity = panGesture.velocity(in: collectionView)

            // 수평 이동 속도가 수직 이동 속도보다 커야 드래그 선택 모드
            // 이렇게 하면 수직 드래그는 스크롤로 처리됨
            let isHorizontalDrag = abs(velocity.x) > abs(velocity.y)

            if isHorizontalDrag {
                print("[GridViewController] Drag select gesture began (horizontal drag detected)")
            }

            return isHorizontalDrag
        }
        return true
    }
}

// MARK: - SelectionManagerDelegate (T037, T042)

extension GridViewController: SelectionManagerDelegate {

    /// 선택 상태 변경 시 호출
    func selectionManager(_ manager: SelectionManager, didChangeSelection assetIDs: Set<String>) {
        // 변경된 셀들만 업데이트
        for assetID in assetIDs {
            if let indexPath = dataSourceDriver.indexPath(for: assetID) {
                // padding 오프셋 적용
                let adjustedIndexPath = IndexPath(item: indexPath.item + paddingCellCount, section: indexPath.section)
                if let cell = collectionView.cellForItem(at: adjustedIndexPath) as? PhotoCell {
                    cell.isSelectedForDeletion = manager.isSelected(assetID)
                }
            }
        }
    }

    /// 선택 개수 변경 시 호출 (T042)
    func selectionManager(_ manager: SelectionManager, selectionCountDidChange count: Int) {
        // 플로팅 오버레이에 선택 개수 업데이트
        if let tabBarController = tabBarController as? TabBarController {
            tabBarController.floatingOverlay?.updateSelectionCount(count)
        }

        print("[GridViewController] Selection count: \(count)")
    }
}

// ViewerViewController.swift
// 전체 화면 사진 뷰어
//
// T028: ViewerViewController 생성
// - UIPageViewController로 좌우 스와이프
//
// T031: 아래 스와이프로 닫기 구현
// - 뷰어 닫고 그리드로 복귀
//
// T033: 더블탭/핀치 줌 구현
// - 이미지 확대/축소
//
// T034: 원형 플로팅 삭제 버튼 생성
// - 하단에 항상 표시
//
// T035: 삭제대기함 사진 뷰어 모드 구현
// - 삭제 버튼 대신 "복구/최종 삭제" 옵션 표시

import UIKit
import Photos
import AppCore
import OSLog
import Vision

/// 뷰어 모드
/// 모드에 따라 하단 버튼이 다르게 표시됨
enum ViewerMode {
    /// 일반 모드: 삭제 버튼 표시
    case normal

    /// 삭제대기함 모드: 복구/최종 삭제 버튼 표시
    case trash

    /// 정리 미리보기 모드: 제외 버튼 표시 (스와이프 삭제 없음)
    case cleanup
}

/// 뷰어 델리게이트
/// 삭제/복구/최종 삭제/제외 액션을 처리
protocol ViewerViewControllerDelegate: AnyObject {
    /// 사진 삭제 요청 (앱 내 삭제대기함으로 이동)
    /// - Parameter assetID: 삭제할 사진 ID
    func viewerDidRequestDelete(assetID: String)

    /// 사진 복구 요청 (삭제대기함에서 복원)
    /// - Parameter assetID: 복구할 사진 ID
    func viewerDidRequestRestore(assetID: String)

    /// 사진 최종 삭제 요청 (iOS 삭제대기함으로 이동)
    /// - Parameter assetID: 최종 삭제할 사진 ID
    func viewerDidRequestPermanentDelete(assetID: String)

    /// 뷰어가 닫힐 때 호출
    /// - Parameters:
    ///   - currentAssetID: 마지막으로 표시한 사진 ID
    ///   - originalIndex: PHFetchResult 기준 원본 인덱스 (O(n) buildCache 회피용)
    func viewerWillClose(currentAssetID: String?, originalIndex: Int?)

    /// 정리 미리보기에서 사진 제외 요청
    /// - Parameter assetID: 제외할 사진 ID
    func viewerDidRequestExclude(assetID: String)

    /// 뷰어가 완전히 닫힌 후 호출 (dismiss/pop 애니메이션 완료 후)
    /// iOS 16~25 Modal (shouldRemovePresentersView=false) 경로에서
    /// presenting VC의 viewWillAppear/viewDidAppear가 호출되지 않는 문제를 보완
    func viewerDidClose()
}

/// ViewerViewControllerDelegate 기본 구현
/// 기존 Grid/Album/Trash 3곳에서 viewerDidRequestExclude를 구현하지 않아도 컴파일 안전
extension ViewerViewControllerDelegate {
    func viewerDidRequestExclude(assetID: String) {}
    func viewerDidClose() {}
}

/// 전체 화면 사진 뷰어
/// UIPageViewController 기반으로 좌우 스와이프 탐색 지원
final class ViewerViewController: UIViewController {

    // MARK: - Constants

    /// 버튼 center에서 safeArea bottom까지의 거리
    /// FloatingTabBar의 capsuleHeight/2와 동일 (56/2 = 28)
    static let buttonCenterFromBottom: CGFloat = 28

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: ViewerViewControllerDelegate?

    /// 현재 모드 (일반/삭제대기함)
    /// Extension에서 접근 가능하도록 internal 접근 레벨
    let viewerMode: ViewerMode

    /// Coordinator (네비게이션 및 데이터 관리)
    /// Extension에서 접근 가능하도록 internal 접근 레벨
    let coordinator: ViewerCoordinatorProtocol

    /// 스와이프 삭제 핸들러
    var swipeDeleteHandler: SwipeDeleteHandler?

    /// 현재 뷰어의 ScreenSource (analytics용)
    /// - .cleanup 모드는 카운트 제외 → nil 반환
    private var analyticsScreenSource: ScreenSource? {
        switch viewerMode {
        case .trash:   return .trash
        case .normal:
            switch coordinator.deleteSource {
            case .library: return .library
            case .album:   return .album
            case nil:      return .library  // 기본값 (안전 장치)
            }
        case .cleanup: return nil
        }
    }

    /// 현재 표시 중인 인덱스
    /// iOS 18+ zoom transition의 sourceViewProvider에서 외부 접근 필요
    var currentIndex: Int

    // MARK: - Debug: PageScroll 분석용

    /// 페이지 스크롤뷰 참조
    private weak var pageScrollView: UIScrollView?

    /// 전환 ID (각 전환을 구분)
    private var transitionId: Int = 0

    /// 전환 중 여부
    private var isTransitioning = false

    /// 마지막 스크롤 로그 시간 (쓰로틀용)
    private var lastPageScrollLogTime: CFTimeInterval = 0

    // MARK: - Debug: 성능 분석용

    #if DEBUG
    /// HitchMonitor (페이지 스와이프 성능 측정)
    private let hitchMonitor = HitchMonitor()

    /// 스와이프 시작 시간
    private var swipeStartTime: CFTimeInterval = 0

    /// 스와이프 카운터 (L1/L2 구분)
    private var swipeCount: Int = 0
    #endif

    // MARK: - Debug: 에셋 ID 라벨

    #if DEBUG
    /// 우측 하단 에셋 ID 표시 라벨 (Extension에서 접근 필요)
    lazy var assetIDLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .monospacedSystemFont(ofSize: 10, weight: .regular)
        label.textColor = UIColor.white.withAlphaComponent(0.6)
        label.textAlignment = .right
        return label
    }()
    #endif

    // MARK: - Phase 2: LOD1 디바운스

    /// LOD1 디바운스 타이머 (150ms)
    private var lod1DebounceTimer: Timer?

    /// LOD1 디바운스 지연 시간
    private static let lod1DebounceDelay: TimeInterval = 0.15

    /// 페이지 뷰 컨트롤러
    lazy var pageViewController: UIPageViewController = {
        let pvc = UIPageViewController(
            transitionStyle: .scroll,
            navigationOrientation: .horizontal,
            options: [.interPageSpacing: 10]
        )
        pvc.dataSource = self
        pvc.delegate = self
        return pvc
    }()

    /// 이전 사진 버튼 (일반 모드 - 좌측 하단)
    lazy var previousPhotoButton: GlassTextButton = {
        let button = GlassTextButton(title: "이전 사진", style: .plain, tintColor: .white)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(previousPhotoButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_previous_photo"
        return button
    }()

    /// 삭제하기 버튼 (일반 모드 - 우측 하단)
    lazy var deleteButton: GlassTextButton = {
        let button = GlassTextButton(title: "삭제하기", style: .plain, tintColor: .systemRed)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_delete"
        return button
    }()

    /// 복구 버튼 (삭제대기함 모드 - Liquid Glass 텍스트 버튼)
    /// iOS 26 스펙: 텍스트 "복구", tintColor #30D158 (녹색)
    lazy var restoreButton: GlassTextButton = {
        let button = GlassTextButton(title: "복구하기", style: .plain, tintColor: .systemGreen)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(restoreButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_restore"
        return button
    }()

    /// 최종 삭제 버튼 (삭제대기함 모드 - Liquid Glass 텍스트 버튼)
    /// iOS 26 스펙: 텍스트 "최종 삭제", tintColor #FF4245 (빨간색)
    lazy var permanentDeleteButton: GlassTextButton = {
        let button = GlassTextButton(title: "최종 삭제", style: .plain, tintColor: .systemRed)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(permanentDeleteButtonTapped), for: .touchUpInside)
        button.accessibilityIdentifier = "viewer_permanent_delete"
        return button
    }()

    /// 제외 버튼 (정리 미리보기 모드 - Liquid Glass 텍스트 버튼)
    /// 정리 후보에서 개별 사진을 제외하는 버튼
    lazy var excludeButton: GlassTextButton = {
        let button = GlassTextButton(title: "저품질 목록에서 제외", style: .plain, tintColor: .white)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(excludeButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 닫기 제스처를 위한 배경 뷰
    lazy var backgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .black
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 아래 스와이프 닫기 팬 제스처
    lazy var dismissPanGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handleDismissPan(_:)))
        gesture.delegate = self
        return gesture
    }()

    /// 닫기 애니메이션 중 여부
    var isDismissing = false

    /// 뷰어 닫힘 확정 플래그 (viewWillDisappear에서 설정, viewDidDisappear에서 사용)
    /// Apple SDK 권장: isBeingDismissed/isMovingFromParent 판별은 viewWillDisappear에서 수행
    private var isClosing = false

    /// Interactive dismiss 중 활성 IC 참조
    /// ⚠️ popViewController 후 navigationController가 nil이 되어
    ///   isPushed/tabBarController 경로로 IC에 접근 불가능하므로 직접 저장
    weak var activeInteractionController: ZoomDismissalInteractionController?

    /// Interactive dismiss 중 활성 TabBarController 참조 (cleanup용)
    weak var activeTabBarController: TabBarController?

    /// 최초 표시 페이드 인 적용 여부 (시스템 전환 대신 사용)
    private var didPerformInitialFadeIn: Bool = false


    /// Navigation Push로 열렸는지 여부 (iOS 26+)
    /// Push: navigationController != nil, presentingViewController == nil
    /// Modal: presentingViewController != nil
    var isPushed: Bool {
        return navigationController != nil && presentingViewController == nil
    }

    /// 줌 트랜지션 컨트롤러 (그리드에서 설정, Modal 방식에서만 사용)
    /// ⚠️ strong 참조: transitioningDelegate가 weak이므로 여기서 유지
    var zoomTransitionController: ZoomTransitionController?

    /// [Timing] 그리드에서 탭한 시점 (CACurrentMediaTime 기준)
    /// GridViewController.didSelectItemAt에서 설정
    var openStartTime: CFTimeInterval = 0

    // MARK: - iOS 26+ System UI Properties

    /// iOS 26+ 시스템 UI 사용 여부
    /// Modal에서는 navigationController가 nil이므로 항상 커스텀 버튼 사용
    var useSystemUI: Bool {
        if #available(iOS 26.0, *) {
            return navigationController != nil
        }
        return false
    }

    /// iOS 26+ 시스템 UI 설정 완료 여부 (중복 설정 방지)
    var didSetupSystemUI: Bool = false

    /// iOS 26+ 툴바 삭제 버튼 참조
    var toolbarDeleteItem: UIBarButtonItem?

    /// iOS 26+ 툴바 이전 사진 버튼 참조
    var toolbarPreviousItem: UIBarButtonItem?

    /// iOS 26+ 툴바 복구 버튼 참조
    var toolbarRestoreItem: UIBarButtonItem?

    /// iOS 26+ 툴바 최종 삭제 버튼 참조
    var toolbarPermanentDeleteItem: UIBarButtonItem?

    /// iOS 26+ 네비게이션 바 눈 아이콘 버튼 참조 (유사 사진 토글)
    var navBarEyeItem: UIBarButtonItem?

    // MARK: - 초기 이미지 (그리드→뷰어 전환 공백 방지)

    /// 첫 페이지용 초기 이미지 (그리드 셀에서 전달, 1회용)
    var initialImage: UIImage?

    // MARK: - 상단 그라데이션 + 타이틀 (유사사진 안내)

    /// 상단 그라데이션 딤드 뷰 (iOS 16~25 + iOS 26 Modal, .normal 모드 전용)
    /// 눈 버튼 토글과 무관하게 항상 표시
    var topGradientView: UIView?

    /// 상단 그라데이션 레이어 (layoutSubviews에서 frame 갱신 필요)
    var topGradientLayer: CAGradientLayer?

    /// "유사사진정리 가능" 타이틀 라벨
    /// 눈 버튼 토글 시 숨김/표시
    var similarPhotoTitleLabel: UILabel?

    /// iOS 16~25 커스텀 뒤로가기 버튼 참조 (코치마크 z-order용)
    weak var backButtonView: UIView?

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - coordinator: 뷰어 코디네이터
    ///   - startIndex: 시작 인덱스
    ///   - mode: 뷰어 모드 (기본: 일반)
    init(coordinator: ViewerCoordinatorProtocol, startIndex: Int, mode: ViewerMode = .normal) {
        self.coordinator = coordinator
        self.currentIndex = startIndex
        self.viewerMode = mode
        super.init(nibName: nil, bundle: nil)

        // Modal 커스텀 전환 설정
        modalPresentationStyle = .custom
        modalPresentationCapturesStatusBarAppearance = true

        // iOS 26+ Navigation Push 시 탭바 숨김
        hidesBottomBarWhenPushed = true
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        setupUI()
        setupGestures()
        setupSwipeDeleteHandler()

        displayInitialPhoto()
        setupSimilarPhotoFeature()

        // [LiquidGlass 최적화] 페이지 스크롤뷰 델리게이트 설정
        setupPageScrollViewDelegate()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // Modal에서는 NavigationControllerDelegate.willShow가 호출 안 됨
        // → FloatingOverlay를 수동으로 숨김
        findTabBarController()?.floatingOverlay?.isHidden = true

        // iOS 26+: navigationController 존재 확인 후 시스템 UI 설정
        if #available(iOS 26.0, *) {
            setupSystemUIIfNeeded()
        }

        // 초기 버튼 상태 설정 (현재 사진의 삭제대기함 상태에 따라)
        // iOS 26에서는 setupSystemUIIfNeeded() 이후에 호출해야 함
        updateToolbarForCurrentPhoto()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if openStartTime > 0 {
            openStartTime = 0

            // [Analytics] 이벤트 3: 최초 진입 시 사진 열람 카운트
            if let source = analyticsScreenSource {
                AnalyticsService.shared.countPhotoViewed(from: source)
            }
        }

        if isBeingPresented && !didPerformInitialFadeIn {
            didPerformInitialFadeIn = true
            UIView.animate(withDuration: 0.18, delay: 0, options: [.curveEaseOut, .allowUserInteraction]) {
                self.view.alpha = 1
            }
        }

        // T026: 유사 사진 오버레이 표시
        showSimilarPhotoOverlay()

        // [LiquidGlass 최적화] 블러 뷰 사전 생성 + idle pause
        LiquidGlassOptimizer.preload(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)

        // 코치마크 B: 뷰어 스와이프 삭제 안내
        showViewerSwipeDeleteCoachMarkIfNeeded()

        // 코치마크 C-2: + 버튼 하이라이트 (C-1에서 자동 네비게이션 후)
        triggerCoachMarkC2IfNeeded()
    }

    // MARK: - Rotation

    override func viewWillTransition(
        to size: CGSize,
        with coordinator: UIViewControllerTransitionCoordinator
    ) {
        super.viewWillTransition(to: size, with: coordinator)

        coordinator.animate(alongsideTransition: { [weak self] _ in
            // 회전 중: FaceButtonOverlay + 타이틀 즉시 숨김 (위치 오류 방지)
            self?.faceButtonOverlay?.hideButtonsImmediately()
            self?.similarPhotoTitleLabel?.alpha = 0
        }, completion: { [weak self] _ in
            // 회전 완료: FaceButtonOverlay 재표시
            self?.refreshFaceButtonsAfterRotation()
        })
    }

    /// 회전 후 +버튼 위치 갱신
    /// - Note: shouldEnableSimilarPhoto는 Extension의 private 프로퍼티이므로
    ///         faceButtonOverlay 존재 여부로 기능 활성화 판단
    private func refreshFaceButtonsAfterRotation() {
        // faceButtonOverlay가 nil이면 SimilarPhoto 기능 비활성화 상태
        faceButtonOverlay?.layoutButtons(for: view.bounds)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // 코치마크 dismiss — guard 앞에 배치 (모달 등 모든 disappear에서 동작)
        CoachMarkManager.shared.dismissCurrent()

        // dismiss/pop 시에만 FloatingOverlay 복원 (interactive 취소 시 중복 방지)
        // Modal: isBeingDismissed, Navigation Pop: isMovingFromParent
        guard isBeingDismissed || isMovingFromParent else { return }

        // 닫힘 확정 플래그 설정 (viewDidDisappear에서 viewerDidClose 호출에 사용)
        isClosing = true

        // Modal에서는 수동으로 FloatingOverlay 복원
        findTabBarController()?.floatingOverlay?.isHidden = false

        // 현재 표시 중인 사진 ID + 원본 인덱스 전달
        // originalIndex: buildCache() O(n) 스캔을 회피하기 위한 힌트
        let currentAssetID = coordinator.assetID(at: currentIndex)
        let originalIndex = coordinator.originalIndex(from: currentIndex)
        delegate?.viewerWillClose(currentAssetID: currentAssetID, originalIndex: originalIndex)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // viewWillDisappear에서 설정한 플래그로 판별
        // (Apple SDK 권장: isBeingDismissed/isMovingFromParent는 viewWillDisappear에서 체크)
        guard isClosing else { return }
        isClosing = false

        // dismiss/pop 애니메이션 완료 후 delegate에 알림
        // iOS 16~25 Modal (shouldRemovePresentersView=false) 경로에서
        // presenting VC의 viewWillAppear/viewDidAppear가 호출되지 않으므로
        // 이 콜백으로 applyPendingViewerReturn() 트리거
        delegate?.viewerDidClose()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override var prefersStatusBarHidden: Bool {
        return true
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        // 그라데이션 레이어 frame 갱신 (Auto Layout 적용 후)
        topGradientLayer?.frame = topGradientView?.bounds ?? .zero
    }

    // MARK: - Coach Mark Helpers

    /// 코치마크 B 표시 후 뒤로가기/하단 버튼을 오버레이 위에 보이게 하되 터치 차단
    /// bringToFront + isUserInteractionEnabled = false → 보이지만 터치 불가
    /// iOS 26+: 시스템 네비바/툴바는 view 밖이므로 자연스럽게 보임
    func showControlButtonsAboveCoachMark() {
        // 오버레이 위로 올리기
        if let back = backButtonView {
            view.bringSubviewToFront(back)
            back.isUserInteractionEnabled = false
        }
        if previousPhotoButton.superview == view {
            view.bringSubviewToFront(previousPhotoButton)
            previousPhotoButton.isUserInteractionEnabled = false
        }
        if deleteButton.superview == view {
            view.bringSubviewToFront(deleteButton)
            deleteButton.isUserInteractionEnabled = false
        }
        if restoreButton.superview == view {
            view.bringSubviewToFront(restoreButton)
            restoreButton.isUserInteractionEnabled = false
        }

        // 코치마크 dismiss 시 터치 복원
        CoachMarkManager.shared.currentOverlay?.onDismiss = { [weak self] in
            self?.backButtonView?.isUserInteractionEnabled = true
            self?.previousPhotoButton.isUserInteractionEnabled = true
            self?.deleteButton.isUserInteractionEnabled = true
            self?.restoreButton.isUserInteractionEnabled = true
        }
    }

    // MARK: - Toolbar State Management

    /// 현재 사진의 삭제대기함 상태에 따라 버튼/툴바 업데이트
    /// - 호출 시점: viewWillAppear, 스와이프 탐색 후, 삭제/복구 후
    func updateToolbarForCurrentPhoto() {
        // .normal 모드에서만 동적 교체 필요
        guard viewerMode == .normal else { return }

        let isTrashed = coordinator.isTrashed(at: currentIndex)

        // iOS 16~25: 커스텀 버튼 토글
        if !useSystemUI {
            deleteButton.isHidden = isTrashed
            restoreButton.isHidden = !isTrashed
        }

        // iOS 26+: 시스템 툴바 교체
        if #available(iOS 26.0, *) {
            updateToolbarItemsForCurrentPhoto()
        }

        updatePreviousNavigationState()
    }

    /// 현재 페이지의 삭제대기함 테두리 즉시 업데이트
    /// - Parameter isTrashed: 삭제대기함 상태 여부
    func updateCurrentPageTrashedState(isTrashed: Bool) {
        guard let currentVC = pageViewController.viewControllers?.first else { return }

        if let photoVC = currentVC as? PhotoPageViewController {
            photoVC.updateTrashedState(isTrashed: isTrashed)
        } else if let videoVC = currentVC as? VideoPageViewController {
            videoVC.updateTrashedState(isTrashed: isTrashed)
        }
    }

    /// 뷰어 닫기 (Modal dismiss)
    private func dismissViewer() {
        dismissWithFadeOut()
    }

    // MARK: - Snapshot (Coach Mark B)

    /// 사진 이미지뷰 스냅샷 + 프레임 (코치마크용)
    /// 검은 여백 없이 사진 영역만 캡처 (pageViewController가 private이므로 우회)
    /// - Returns: (스냅샷 뷰, 윈도우 좌표 프레임) 또는 nil
    func capturePhotoSnapshot() -> (snapshot: UIView, frame: CGRect)? {
        guard let imageView = currentPageImageView,
              let snapshot = imageView.snapshotView(afterScreenUpdates: false),
              let window = view.window else { return nil }
        let frameInWindow = imageView.convert(imageView.bounds, to: window)
        return (snapshot, frameInWindow)
    }

    // MARK: - Helpers

    /// 인덱스에 해당하는 페이지 뷰 컨트롤러 생성 (미디어 타입에 따라 분기)
    /// - Parameter index: 표시할 인덱스
    /// - Returns: PhotoPageViewController 또는 VideoPageViewController
    func createPageViewController(at index: Int) -> UIViewController? {
        guard let asset = coordinator.asset(at: index) else { return nil }

        // 보관함(.normal)에서만 배경색 변경, 삭제대기함 탭에서는 검은색 유지
        let showTrashedBackground = (viewerMode == .normal) && coordinator.isTrashed(at: index)

        switch asset.mediaType {
        case .video:
            // 동영상: VideoPageViewController
            return VideoPageViewController(asset: asset, index: index, showTrashedBackground: showTrashedBackground)
        default:
            // 사진/기타: PhotoPageViewController
            return PhotoPageViewController(asset: asset, index: index, showTrashedBackground: showTrashedBackground)
        }
    }

    /// 뷰 컨트롤러에서 인덱스 추출 (Photo/Video 공통)
    private func index(from viewController: UIViewController) -> Int? {
        if let photoVC = viewController as? PhotoPageViewController {
            return photoVC.index
        } else if let videoVC = viewController as? VideoPageViewController {
            return videoVC.index
        }
        return nil
    }
}

// MARK: - UIPageViewControllerDataSource

extension ViewerViewController: UIPageViewControllerDataSource {

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerBefore viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = index(from: viewController) else { return nil }
        let previousIndex = currentIndex - 1
        guard previousIndex >= 0 else { return nil }
        return createPageViewController(at: previousIndex)
    }

    func pageViewController(_ pageViewController: UIPageViewController, viewControllerAfter viewController: UIViewController) -> UIViewController? {
        guard let currentIndex = index(from: viewController) else { return nil }
        let nextIndex = currentIndex + 1
        guard nextIndex < coordinator.totalCount else { return nil }
        return createPageViewController(at: nextIndex)
    }
}

// MARK: - Helpers (TabBarController 접근)

extension ViewerViewController {

    /// Modal에서 presenting VC 체인을 통해 TabBarController 찾기
    /// self.tabBarController는 Modal에서 nil이므로 presentingViewController 체인 탐색
    func findTabBarController() -> TabBarController? {
        // 1. 직접 접근 (Navigation에 속한 경우)
        if let tbc = tabBarController as? TabBarController { return tbc }
        // 2. presenting VC 체인 탐색 (Modal인 경우)
        var vc = presentingViewController
        while let current = vc {
            if let tbc = current as? TabBarController { return tbc }
            if let nav = current as? UINavigationController,
               let tbc = nav.tabBarController as? TabBarController { return tbc }
            vc = current.presentingViewController
        }
        return nil
    }
}

// MARK: - Debug: PageScroll 분석

extension ViewerViewController {

    /// 페이지 스크롤뷰에 로거 연결
    private func attachPageScrollLoggerIfNeeded() {
        guard pageScrollView == nil else { return }
        if let sv = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView {
            pageScrollView = sv
            sv.panGestureRecognizer.addTarget(self, action: #selector(handlePageScrollPan(_:)))
        }
    }

    /// 페이지 스크롤 진행률 로깅
    @objc private func handlePageScrollPan(_ gesture: UIPanGestureRecognizer) {
    }
}

// MARK: - UIPageViewControllerDelegate

extension ViewerViewController: UIPageViewControllerDelegate {

    func pageViewController(_ pageViewController: UIPageViewController, willTransitionTo pendingViewControllers: [UIViewController]) {
        // 스크롤 로거 연결
        attachPageScrollLoggerIfNeeded()
        transitionId += 1
        isTransitioning = true

        // Phase 2: LOD1 디바운스 타이머 취소 (빠른 스와이프 시 LOD1 스킵)
        lod1DebounceTimer?.invalidate()
        lod1DebounceTimer = nil

        // [Debug] 성능 측정 시작 (optimize는 scrollViewWillBeginDragging에서 호출)
        #if DEBUG
        swipeStartTime = CACurrentMediaTime()
        hitchMonitor.start()
        #endif

    }

    func pageViewController(_ pageViewController: UIPageViewController, didFinishAnimating finished: Bool, previousViewControllers: [UIViewController], transitionCompleted completed: Bool) {
        isTransitioning = false

        // [Debug] 성능 측정 종료 (restore는 scrollViewDidEndDecelerating에서 호출)
        #if DEBUG
        let hitchResult = hitchMonitor.stop()

        // 스와이프 카운터 증가 (completed 여부 관계없이 측정)
        swipeCount += 1
        let swipeType = swipeCount == 1 ? "L1 First" : "L2 Steady"
        let swipeDuration = (CACurrentMediaTime() - swipeStartTime) * 1000

        // 성능 로그 출력
        Logger.viewer.debug("Hitch \(swipeType): \(hitchResult.formatted())")
        Logger.viewer.debug("Hitch:Abs totalHitchMs=\(String(format: "%.1f", hitchResult.totalHitchTimeMs)), duration=\(String(format: "%.3f", hitchResult.durationSeconds))s")
        Logger.viewer.debug("Swipe completed=\(completed), duration=\(String(format: "%.1f", swipeDuration))ms")
        #endif

        guard completed else { return }

        // 현재 표시 중인 VC에서 인덱스 추출
        guard let currentVC = pageViewController.viewControllers?.first,
              let newIndex = index(from: currentVC) else {
            return
        }

        // 인덱스 업데이트
        currentIndex = newIndex

        // 에셋 ID 라벨 업데이트
        #if DEBUG
        updateAssetIDLabel()
        #endif

        // [Analytics] 이벤트 3: 페이지 전환 시 사진 열람 카운트
        if let source = analyticsScreenSource {
            AnalyticsService.shared.countPhotoViewed(from: source)
        }

        // 이전 페이지가 VideoPageViewController면 정지
        // (스와이프 취소 시에는 completed=false이므로 여기까지 오지 않음)
        for previousVC in previousViewControllers {
            if let videoVC = previousVC as? VideoPageViewController {
                videoVC.pause()
            }
        }

        // 현재 페이지가 VideoPageViewController면 비디오 요청 트리거
        // (인접 페이지 다운로드 방지를 위해 전환 완료 시점에 요청)
        if let videoVC = currentVC as? VideoPageViewController {
            videoVC.requestVideoIfNeeded()
        }

        // Phase 2: LOD1 디바운스 (150ms 후 원본 요청)
        scheduleLOD1Request()

        // T026: 유사 사진 오버레이 업데이트 (스와이프로 다른 사진 이동 시)
        updateSimilarPhotoOverlay()

        // 스와이프 탐색 후 버튼 상태 업데이트 (다음 사진이 삭제대기함일 수 있음)
        updateToolbarForCurrentPhoto()

        // 코치마크 B: 동영상 → 이미지 스와이프 시 트리거
        showViewerSwipeDeleteCoachMarkIfNeeded()
    }

    /// LOD1 요청 스케줄링 (150ms 디바운스)
    /// - 빠른 스와이프 시 LOD1 요청 스킵
    /// - 정지 상태에서만 원본 이미지 로드
    func scheduleLOD1Request() {
        lod1DebounceTimer?.invalidate()
        Logger.viewer.debug("[LOD1] scheduleLOD1Request — \(Self.lod1DebounceDelay)초 디바운스 시작")
        lod1DebounceTimer = Timer.scheduledTimer(withTimeInterval: Self.lod1DebounceDelay, repeats: false) { [weak self] _ in
            guard let self = self else { return }

            // 현재 페이지가 PhotoPageViewController면 LOD1 요청
            if let photoVC = self.pageViewController.viewControllers?.first as? PhotoPageViewController {
                photoVC.requestHighQualityImage()
            }
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ViewerViewController: UIGestureRecognizerDelegate {

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 스와이프 삭제와 다른 제스처가 동시에 인식되지 않도록
        if let swipeHandler = swipeDeleteHandler,
           gestureRecognizer == swipeHandler.panGesture || otherGestureRecognizer == swipeHandler.panGesture {
            return false
        }

        // 아래 스와이프 닫기와 다른 제스처가 동시에 인식되지 않도록
        // (UIPageViewController의 좌우 스와이프와 충돌 방지)
        if gestureRecognizer == dismissPanGesture || otherGestureRecognizer == dismissPanGesture {
            return false
        }

        return true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == dismissPanGesture else { return true }

        // 아래 방향 스와이프만 허용
        let velocity = dismissPanGesture.velocity(in: view)
        guard velocity.y > 0 && abs(velocity.y) > abs(velocity.x) else { return false }

        // 줌 상태 체크: 확대 중이면 dismiss 안 함 (스크롤 동작으로 처리)
        guard let zoomable = pageViewController.viewControllers?.first as? ZoomableImageProviding else {
            return true
        }
        guard zoomable.zoomScale <= 1.01 else { return false }
        return zoomable.isAtTopEdge
    }
}

// MARK: - BarsVisibilityControlling

extension ViewerViewController: BarsVisibilityControlling {
    /// Viewer에서는 floatingOverlay 숨김 (전체화면 뷰어이므로)
    var prefersFloatingOverlayHidden: Bool? { true }

    /// 모든 뷰어 모드에서 탭바 숨김
    /// iOS 26에서 기본값이 "표시"이므로 명시적으로 숨겨야 함
    var prefersSystemTabBarHidden: Bool? { true }

    /// iOS 26: 시스템 툴바 표시 (삭제/복구/제외 버튼)
    /// iOS 16~25: 기본 정책 (커스텀 버튼 사용하므로 시스템 툴바 불필요)
    var prefersToolbarHidden: Bool? {
        if #available(iOS 26.0, *) {
            return false  // iOS 26: 툴바 표시
        }
        return nil  // iOS 16~25: 기본 정책 (숨김)
    }
}

// MARK: - ZoomTransitionDestinationProviding (커스텀 줌 트랜지션)

extension ViewerViewController: ZoomTransitionDestinationProviding {

    /// 현재 표시 중인 원본 인덱스 (ZoomTransitionSourceProviding에서 셀 찾기용)
    /// - Note: ViewerViewController.currentIndex는 filteredIndex이므로
    ///         coordinator를 통해 originalIndex로 변환
    var currentOriginalIndex: Int {
        coordinator.originalIndex(from: currentIndex) ?? currentIndex
    }

    /// 줌 애니메이션 대상 뷰 (현재 페이지의 이미지 뷰)
    var zoomDestinationView: UIView? {
        currentPageImageView
    }

    /// 줌 애니메이션 목적지 프레임 (window 좌표계)
    /// - Note: imageView.frame 대신 asset 비율로 계산하여 레이아웃 완료 전에도 정확한 프레임 반환
    var zoomDestinationFrame: CGRect? {
        // 현재 asset의 크기로 aspect fit 프레임 계산
        guard let asset = coordinator.asset(at: currentIndex) else { return nil }

        let assetSize = CGSize(width: asset.pixelWidth, height: asset.pixelHeight)
        let containerSize = view.bounds.size

        // aspect fit 계산
        let aspectFitFrame = calculateAspectFitFrame(
            assetSize: assetSize,
            containerSize: containerSize
        )

        // window 좌표계로 변환
        return view.convert(aspectFitFrame, to: nil)
    }

    /// aspect fit 프레임 계산
    /// - Parameters:
    ///   - assetSize: 미디어 원본 크기
    ///   - containerSize: 컨테이너 크기
    /// - Returns: 컨테이너 중앙에 aspect fit으로 배치된 프레임
    private func calculateAspectFitFrame(assetSize: CGSize, containerSize: CGSize) -> CGRect {
        guard assetSize.width > 0 && assetSize.height > 0 else {
            return CGRect(origin: .zero, size: containerSize)
        }

        let widthRatio = containerSize.width / assetSize.width
        let heightRatio = containerSize.height / assetSize.height
        let ratio = min(widthRatio, heightRatio)

        let fitWidth = assetSize.width * ratio
        let fitHeight = assetSize.height * ratio

        let x = (containerSize.width - fitWidth) / 2
        let y = (containerSize.height - fitHeight) / 2

        return CGRect(x: x, y: y, width: fitWidth, height: fitHeight)
    }

    /// 현재 페이지의 이미지 뷰 (Photo/Video 공통)
    private var currentPageImageView: UIView? {
        guard let currentVC = pageViewController.viewControllers?.first else { return nil }

        // PhotoPageViewController
        if let photoPage = currentVC as? PhotoPageViewController {
            return photoPage.zoomableImageView
        }

        // VideoPageViewController (포스터 이미지 사용)
        if let videoPage = currentVC as? VideoPageViewController {
            return videoPage.zoomableImageView
        }

        return nil
    }
}

// MARK: - LiquidGlass 최적화 (UIScrollViewDelegate)

extension ViewerViewController: UIScrollViewDelegate {

    /// UIPageViewController 내부 스크롤뷰의 delegate 설정
    /// - Note: 더 빠른 시점(터치 직후)에 LiquidGlass 최적화 적용
    func setupPageScrollViewDelegate() {
        // UIPageViewController 내부의 UIScrollView 찾기
        guard let scrollView = pageViewController.view.subviews.first(where: { $0 is UIScrollView }) as? UIScrollView else {
            Logger.viewer.error("Scroll UIScrollView를 찾을 수 없음")
            return
        }

        scrollView.delegate = self
        Logger.viewer.debug("Scroll UIScrollView delegate 설정 완료")
    }

    // MARK: - UIScrollViewDelegate

    /// 드래그 시작 (터치 직후) - 최적화 시작 + 버튼 숨김
    func scrollViewWillBeginDragging(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.cancelIdleTimer()
        LiquidGlassOptimizer.optimize(in: view.window)

        // +버튼 + 타이틀 즉시 숨김 (스와이프 시 제자리에 남는 문제 방지)
        faceButtonOverlay?.hideButtonsImmediately()
        similarPhotoTitleLabel?.alpha = 0

        Logger.viewer.debug("Scroll willBeginDragging - optimize 시작")
    }

    /// 감속 완료 - 최적화 해제 + 버튼 복원
    func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        LiquidGlassOptimizer.restore(in: view.window)
        LiquidGlassOptimizer.enterIdle(in: view.window)

        // 스와이프 취소 시 +버튼 복원 (didFinishAnimating completed=false면 복원 안 됨)
        restoreFaceButtonsIfNeeded()

        Logger.viewer.debug("Scroll didEndDecelerating - restore 완료")
    }

    /// 드래그 종료 (감속 없이 멈춤) - 최적화 해제 + 버튼 복원
    func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        // 감속이 없으면 여기서 restore (감속 있으면 didEndDecelerating에서 처리)
        if !decelerate {
            LiquidGlassOptimizer.restore(in: view.window)
            LiquidGlassOptimizer.enterIdle(in: view.window)

            // 스와이프 취소 시 +버튼 복원
            restoreFaceButtonsIfNeeded()

            Logger.viewer.debug("Scroll didEndDragging(willDecelerate=false) - restore 완료")
        }
    }

    /// 스와이프 취소 시 +버튼 복원
    /// 전환 완료(completed=true) 시에는 updateSimilarPhotoOverlay()에서 처리되므로
    /// 여기서는 전환 중이 아닐 때(취소됨)만 복원
    private func restoreFaceButtonsIfNeeded() {
        guard !isTransitioning else { return }
        // 현재 사진에 대해 +버튼 재표시
        updateSimilarPhotoOverlay(resetZoom: false)
    }
}

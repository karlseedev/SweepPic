// TabBarController.swift
// Photos/Albums 탭으로 TabBarController 생성
//
// T018: Photos/Albums 탭으로 TabBarController 생성
// T027-1d: iOS 버전별 분기 (iOS 26+: 시스템 기본, iOS 16~25: 커스텀 플로팅 UI)
// T027-1e: 네비바 숨김 처리 (iOS 16~25만 숨김)

import UIKit
import AppCore

/// PickPhoto 앱의 메인 TabBarController
/// Photos 탭과 Albums 탭을 관리
/// iOS 버전에 따라 커스텀 플로팅 UI 또는 시스템 기본 UI 사용
class TabBarController: UITabBarController {

    // MARK: - Properties

    /// 플로팅 오버레이 컨테이너 (iOS 16~25에서만 사용)
    private(set) var floatingOverlay: FloatingOverlayContainer?

    /// Photos 탭 NavigationController
    private var photosNav: UINavigationController?

    /// Albums 탭 NavigationController
    private var albumsNav: UINavigationController?

    /// Trash 탭 NavigationController
    private var trashNav: UINavigationController?

    // MARK: - iOS 26+ 줌 트랜지션 프로퍼티

    /// 줌 트랜지션 소스 제공자 (그리드 VC) — Push 시 설정, Pop 완료 후 해제
    weak var zoomSourceProvider: ZoomTransitionSourceProviding?

    /// 줌 트랜지션 목적지 제공자 (뷰어 VC) — Push 시 설정, Pop 완료 후 해제
    weak var zoomDestinationProvider: ZoomTransitionDestinationProviding?

    /// Interactive Pop용 Interaction Controller — drag 시작 시 생성, Pop 완료 후 해제
    var zoomInteractionController: ZoomDismissalInteractionController?

    /// Interactive Pop 진행 중 여부 — drag 시작 시 true, 끝나면 false
    var isInteractivelyPopping: Bool = false

    /// 커스텀 플로팅 UI 사용 여부
    /// iOS 26+에서는 false (시스템 기본 사용)
    private var useFloatingUI: Bool {
        if #available(iOS 26.0, *) {
            return false
        }
        return true
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupFloatingUIIfNeeded()
        setupSystemBarsVisibility()

        // iOS 26: feedbackGenerator.prepare()로 dyld 워밍업
        // CHHapticEngine → AudioToolbox dyld 로딩이 백그라운드에서 수행되어
        // 뷰어 열기 시 dyld 글로벌 락 경합을 방지 (FirstLoading1과 동일 원인)
        // iOS 25에서는 FloatingOverlay 내 GlassIconButton이 이 역할을 수행
        if !useFloatingUI {
            UIImpactFeedbackGenerator(style: .light).prepare()
        }

        // 탭 변경 감지
        delegate = self

        Log.print("[TabBarController] Initialized - useFloatingUI: \(useFloatingUI)")
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        // 플로팅 오버레이가 있으면 safe area 업데이트
        floatingOverlay?.updateSafeAreaInsets(
            top: view.safeAreaInsets.top,
            bottom: view.safeAreaInsets.bottom
        )
    }

    // MARK: - Setup

    /// 탭 설정
    private func setupTabs() {
        // Photos 탭 (All Photos 그리드)
        // ⚠️ 사진보관함 명칭 변경 시 동시 수정 필요:
        // - TabBarController.swift: tabBarItem.title (여기)
        // - GridViewController.swift: title, setTitle()
        // - FloatingOverlayContainer.swift: titleBar.title
        // - FloatingTitleBar.swift: title 기본값
        let photosVC = GridViewController()
        let photosNavController = UINavigationController(rootViewController: photosVC)
        photosNavController.tabBarItem = UITabBarItem(
            title: "보관함",
            image: UIImage(systemName: "photo.on.rectangle"),
            selectedImage: UIImage(systemName: "photo.on.rectangle.fill")
        )
        photosNavController.delegate = self  // BarsVisibilityPolicy 적용을 위한 delegate
        self.photosNav = photosNavController

        // Albums 탭 (앨범 목록)
        // ⚠️ 앨범 명칭 변경 시 동시 수정 필요:
        // - TabBarController.swift: tabBarItem.title (여기)
        // - AlbumsViewController.swift: title, setTitle()
        // - FloatingOverlayContainer.swift: titleBar.title
        let albumsVC = AlbumsViewController()
        let albumsNavController = UINavigationController(rootViewController: albumsVC)
        albumsNavController.tabBarItem = UITabBarItem(
            title: "앨범",
            image: UIImage(systemName: "rectangle.stack"),
            selectedImage: UIImage(systemName: "rectangle.stack.fill")
        )
        albumsNavController.delegate = self  // BarsVisibilityPolicy 적용을 위한 delegate
        self.albumsNav = albumsNavController

        // Trash 탭 (휴지통)
        // ⚠️ 휴지통 명칭 변경 시 동시 수정 필요:
        // - TabBarController.swift: tabBarItem.title (여기)
        // - TrashAlbumViewController.swift: title, setTitle()
        let trashVC = TrashAlbumViewController()
        let trashNavController = UINavigationController(rootViewController: trashVC)
        trashNavController.tabBarItem = UITabBarItem(
            title: "휴지통",
            image: UIImage(systemName: "trash"),
            selectedImage: UIImage(systemName: "trash.fill")
        )
        trashNavController.delegate = self  // BarsVisibilityPolicy 적용을 위한 delegate
        self.trashNav = trashNavController

        // 탭 뷰컨트롤러 설정
        viewControllers = [photosNavController, albumsNavController, trashNavController]

        Log.print("[TabBarController] Tabs configured: Photos, Albums, Trash")
    }

    /// 플로팅 UI 설정 (iOS 16~25)
    private func setupFloatingUIIfNeeded() {
        guard useFloatingUI else {
            Log.print("[TabBarController] iOS 26+: Using system default UI")
            return
        }

        // 플로팅 오버레이 컨테이너 생성
        let overlay = FloatingOverlayContainer()
        overlay.delegate = self
        overlay.translatesAutoresizingMaskIntoConstraints = false

        // TabBarController의 view 위에 추가 (탭 전환에도 유지됨)
        view.addSubview(overlay)

        NSLayoutConstraint.activate([
            overlay.topAnchor.constraint(equalTo: view.topAnchor),
            overlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        self.floatingOverlay = overlay

        Log.print("[TabBarController] FloatingOverlayContainer added")
    }

    /// 시스템 바 가시성 설정
    private func setupSystemBarsVisibility() {
        if useFloatingUI {
            // iOS 16~25: 시스템 탭바 숨김
            tabBar.isHidden = true

            // 각 탭의 네비바 숨김 (루트에서 일관 통제)
            photosNav?.setNavigationBarHidden(true, animated: false)
            albumsNav?.setNavigationBarHidden(true, animated: false)
            trashNav?.setNavigationBarHidden(true, animated: false)

            Log.print("[TabBarController] System bars hidden (using floating UI)")
        } else {
            // iOS 26+: 시스템 바 표시
            tabBar.isHidden = false
            setupSystemAppearance()

            // 네비바 표시 + Select 버튼 추가
            setupNavigationBarForSystemMode()

            Log.print("[TabBarController] System bars visible (iOS 26+)")
        }
    }

    /// iOS 26+ 시스템 네비바에 Select 버튼 추가
    private func setupNavigationBarForSystemMode() {
        guard !useFloatingUI else { return }

        // Photos 탭에 Select 버튼 추가
        if let photosVC = photosNav?.viewControllers.first as? GridViewController {
            let selectButton = UIBarButtonItem(
                title: "선택",
                style: .plain,
                target: self,
                action: #selector(systemSelectButtonTapped)
            )
            photosVC.navigationItem.rightBarButtonItem = selectButton
        }

        // Albums 탭은 Phase 6까지 Select 버튼 없음
    }

    /// 시스템 외관 설정 (iOS 26+)
    private func setupSystemAppearance() {
        // iOS 15+ 탭바 외관 설정
        let appearance = UITabBarAppearance()
        appearance.configureWithDefaultBackground()

        tabBar.standardAppearance = appearance
        if #available(iOS 15.0, *) {
            tabBar.scrollEdgeAppearance = appearance
        }

        // 틴트 색상 (시스템 블루)
        tabBar.tintColor = .systemBlue
    }

    // MARK: - Actions

    /// 시스템 네비바의 Select 버튼 탭 (iOS 26+)
    @objc private func systemSelectButtonTapped() {
        Log.print("[TabBarController] System Select button tapped")
        // GridViewController에 Select 모드 진입 알림
        if let photosVC = photosNav?.viewControllers.first as? GridViewController {
            photosVC.enterSelectMode()
        }
    }

    // MARK: - Helper

    /// 임시 플레이스홀더 뷰컨트롤러 생성
    /// - Parameter title: 화면 타이틀
    /// - Returns: UIViewController
    private func createPlaceholderViewController(title: String) -> UIViewController {
        let vc = UIViewController()
        vc.view.backgroundColor = .systemBackground
        vc.title = title

        // 개발 중 표시용 라벨
        let label = UILabel()
        label.text = "\(title)\n(Phase 6에서 구현)"
        label.numberOfLines = 0
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        vc.view.addSubview(label)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: vc.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: vc.view.centerYAnchor)
        ])

        return vc
    }

    // MARK: - Public Methods

    /// 오버레이 높이 정보 제공 (GridViewController에서 contentInset 계산용)
    /// - Returns: (top: 타이틀바 높이, bottom: 탭바 높이) 또는 nil (시스템 UI 사용 시)
    func getOverlayHeights() -> (top: CGFloat, bottom: CGFloat)? {
        return floatingOverlay?.getOverlayHeights()
    }
}

// MARK: - UITabBarControllerDelegate

extension TabBarController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        // 플로팅 오버레이 탭 동기화
        if let index = viewControllers?.firstIndex(of: viewController) {
            floatingOverlay?.selectedTabIndex = index
            Log.print("[TabBarController] Tab selected via system: \(index)")
        }
    }
}

// MARK: - FloatingOverlayContainerDelegate

extension TabBarController: FloatingOverlayContainerDelegate {
    /// 현재 탭의 최상위 BaseGridViewController 반환
    private func currentGridViewController() -> BaseGridViewController? {
        guard let navController = selectedViewController as? UINavigationController else { return nil }
        return navController.topViewController as? BaseGridViewController
    }

    /// Select 모드 지원 VC 반환
    private func currentSelectModeTarget() -> BaseGridViewController? {
        guard let target = currentGridViewController(), target.supportsSelectMode else { return nil }
        return target
    }

    func floatingOverlay(_ container: FloatingOverlayContainer, didSelectTabAt index: Int) {
        // 탭 전환
        selectedIndex = index
        Log.print("[TabBarController] Tab selected via floating UI: \(index)")
    }

    func floatingOverlayDidTapSelect(_ container: FloatingOverlayContainer) {
        Log.print("[TabBarController] Select tapped via floating UI")
        // 현재 탭의 Select 모드 지원 VC에 진입 요청
        currentSelectModeTarget()?.enterSelectMode()
    }

    func floatingOverlayDidTapCancel(_ container: FloatingOverlayContainer) {
        Log.print("[TabBarController] Cancel tapped via floating UI")
        // 현재 탭의 Select 모드 지원 VC에 종료 요청
        currentSelectModeTarget()?.exitSelectMode()
    }

    func floatingOverlayDidTapDelete(_ container: FloatingOverlayContainer) {
        Log.print("[TabBarController] Delete tapped via floating UI")
        // 현재 탭의 Select 모드 지원 VC에 삭제 액션 전달
        currentSelectModeTarget()?.handleSelectModeDeleteAction()
    }

    func floatingOverlayDidTapEmptyTrash(_ container: FloatingOverlayContainer) {
        Log.print("[TabBarController] Empty Trash tapped via floating UI")
        // TrashAlbumViewController에 휴지통 비우기 알림
        if let trashVC = trashNav?.viewControllers.first as? TrashAlbumViewController {
            trashVC.emptyTrash()
        }
    }
}

// MARK: - UINavigationControllerDelegate (BarsVisibilityPolicy)

extension TabBarController: UINavigationControllerDelegate {

    /// 네비게이션 전환 시 Bar 가시성 정책 적용
    /// - willShow에서 전달되는 viewController는 "곧 보여질 VC"로 정확한 대상
    /// - topViewController는 전환 중에는 아직 이전 VC일 수 있음
    func navigationController(
        _ navigationController: UINavigationController,
        willShow viewController: UIViewController,
        animated: Bool
    ) {
        applyBarsVisibilityPolicy(for: viewController, in: navigationController)
    }

    /// 커스텀 애니메이션 컨트롤러 제공
    /// iOS 26+: Viewer push/pop 시 줌 트랜지션 애니메이터 반환
    /// iOS 16~25: nil 반환 (Modal 방식 사용)
    func navigationController(
        _ navigationController: UINavigationController,
        animationControllerFor operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        // iOS 26+ 줌 트랜지션: Viewer push/pop 시에만
        guard #available(iOS 26.0, *) else { return nil }

        switch operation {
        case .push where toVC is ViewerViewController:
            // 그리드 → 뷰어 줌 인
            let animator = ZoomAnimator(isPresenting: true)
            animator.sourceProvider = zoomSourceProvider
            animator.destinationProvider = zoomDestinationProvider
            animator.transitionMode = .navigation
            return animator

        case .pop where fromVC is ViewerViewController:
            // 뷰어 → 그리드 줌 아웃
            let animator = ZoomAnimator(isPresenting: false)
            animator.sourceProvider = zoomSourceProvider
            animator.destinationProvider = zoomDestinationProvider
            animator.isInteractiveDismiss = isInteractivelyPopping
            animator.transitionMode = .navigation
            return animator

        default:
            return nil  // Albums push/pop 등은 기본 애니메이션
        }
    }

    /// Interactive 전환 컨트롤러 제공
    /// isInteractivelyPopping이 true일 때만 반환 (아니면 non-interactive pop)
    func navigationController(
        _ navigationController: UINavigationController,
        interactionControllerFor animationController: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        guard isInteractivelyPopping else { return nil }
        return zoomInteractionController
    }

    /// 네비게이션 전환 완료 후 cleanup + edge swipe 관리
    /// ⚠️ willShow가 아닌 didShow 사용: willShow는 전환 시작 시점에 호출되어
    ///   interactive pop 중 cleanup하면 zoomInteractionController가 nil이 됨
    func navigationController(
        _ navigationController: UINavigationController,
        didShow viewController: UIViewController,
        animated: Bool
    ) {
        // Pop 완료 후 줌 트랜지션 리소스 해제
        if !(viewController is ViewerViewController) {
            cleanupZoomTransition()
        }

        // Edge swipe back: Viewer에서만 비활성화 (커스텀 drag dismiss 사용)
        navigationController.interactivePopGestureRecognizer?.isEnabled = !(viewController is ViewerViewController)
    }

    /// 줌 트랜지션 리소스 해제
    func cleanupZoomTransition() {
        zoomSourceProvider = nil
        zoomDestinationProvider = nil
        zoomInteractionController = nil
        isInteractivelyPopping = false
    }

    /// Bar 가시성 정책 적용
    /// - BarsVisibilityControlling 프로토콜 채택 VC: 명시적 정책 적용
    /// - 미채택 VC: TabBarController 기본 정책 적용
    private func applyBarsVisibilityPolicy(
        for viewController: UIViewController,
        in navigationController: UINavigationController
    ) {
        let policy = viewController as? BarsVisibilityControlling

        if useFloatingUI {
            // ===== iOS 16~25 =====
            // 시스템 탭바: 항상 숨김 (floatingTabBar 사용)
            tabBar.isHidden = true

            // floatingOverlay: 정책이 있으면 적용, nil이면 기본 정책(표시)
            if let floatingOverlay = floatingOverlay {
                floatingOverlay.isHidden = policy?.prefersFloatingOverlayHidden ?? false
            }
        } else {
            // ===== iOS 26+ =====
            // 시스템 탭바: 정책이 있으면 적용, nil이면 기본(표시)
            // PreviewGridVC 등 탭바 숨김이 필요한 VC는 prefersSystemTabBarHidden = true 설정
            tabBar.isHidden = policy?.prefersSystemTabBarHidden ?? false
            // floatingOverlay는 iOS 26에서 nil이므로 처리 불필요
        }

        // 툴바: 정책이 있으면 적용, nil이면 기본 정책(숨김)
        let hideToolbar = policy?.prefersToolbarHidden ?? true
        navigationController.setToolbarHidden(hideToolbar, animated: false)

        // 디버그 로그
        let vcName = String(describing: type(of: viewController))
        let hasPolicy = policy != nil
        Log.print("[TabBarController] BarsVisibilityPolicy applied for \(vcName) (hasPolicy: \(hasPolicy))")
    }
}

// TabBarController.swift
// Photos/Albums 탭으로 TabBarController 생성
//
// T018: Photos/Albums 탭으로 TabBarController 생성
// T027-1d: iOS 버전별 분기 (iOS 26+: 시스템 기본, iOS 16~25: 커스텀 플로팅 UI)
// T027-1e: 네비바 숨김 처리 (iOS 16~25만 숨김)

import UIKit

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

        // 탭 변경 감지
        delegate = self

        print("[TabBarController] Initialized - useFloatingUI: \(useFloatingUI)")
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
            title: "사진보관함",
            image: UIImage(systemName: "photo.on.rectangle"),
            selectedImage: UIImage(systemName: "photo.on.rectangle.fill")
        )
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
        self.albumsNav = albumsNavController

        // Trash 탭 (휴지통)
        // ⚠️ 휴지통 명칭 변경 시 동시 수정 필요:
        // - TabBarController.swift: tabBarItem.title (여기)
        // - TrashAlbumViewController.swift: title, setTitle()
        let trashVC = TrashAlbumViewController()
        let trashNavController = UINavigationController(rootViewController: trashVC)
        trashNavController.tabBarItem = UITabBarItem(
            title: "PickPhoto 휴지통",
            image: UIImage(systemName: "trash"),
            selectedImage: UIImage(systemName: "trash.fill")
        )
        self.trashNav = trashNavController

        // 탭 뷰컨트롤러 설정
        viewControllers = [photosNavController, albumsNavController, trashNavController]

        print("[TabBarController] Tabs configured: Photos, Albums, Trash")
    }

    /// 플로팅 UI 설정 (iOS 16~25)
    private func setupFloatingUIIfNeeded() {
        guard useFloatingUI else {
            print("[TabBarController] iOS 26+: Using system default UI")
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

        print("[TabBarController] FloatingOverlayContainer added")
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

            print("[TabBarController] System bars hidden (using floating UI)")
        } else {
            // iOS 26+: 시스템 바 표시
            tabBar.isHidden = false
            setupSystemAppearance()

            // 네비바 표시 + Select 버튼 추가
            setupNavigationBarForSystemMode()

            print("[TabBarController] System bars visible (iOS 26+)")
        }
    }

    /// iOS 26+ 시스템 네비바에 Select 버튼 추가
    private func setupNavigationBarForSystemMode() {
        guard !useFloatingUI else { return }

        // Photos 탭에 Select 버튼 추가
        if let photosVC = photosNav?.viewControllers.first as? GridViewController {
            let selectButton = UIBarButtonItem(
                title: "Select",
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
        print("[TabBarController] System Select button tapped")
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
            print("[TabBarController] Tab selected via system: \(index)")
        }
    }
}

// MARK: - FloatingOverlayContainerDelegate

extension TabBarController: FloatingOverlayContainerDelegate {
    func floatingOverlay(_ container: FloatingOverlayContainer, didSelectTabAt index: Int) {
        // 탭 전환
        selectedIndex = index
        print("[TabBarController] Tab selected via floating UI: \(index)")
    }

    func floatingOverlayDidTapSelect(_ container: FloatingOverlayContainer) {
        print("[TabBarController] Select tapped via floating UI")
        // GridViewController에 Select 모드 진입 알림
        if let photosVC = photosNav?.viewControllers.first as? GridViewController {
            photosVC.enterSelectMode()
        }
    }

    func floatingOverlayDidTapCancel(_ container: FloatingOverlayContainer) {
        print("[TabBarController] Cancel tapped via floating UI")
        // GridViewController에 Select 모드 종료 알림
        if let photosVC = photosNav?.viewControllers.first as? GridViewController {
            photosVC.exitSelectMode()
        }
    }

    func floatingOverlayDidTapDelete(_ container: FloatingOverlayContainer) {
        print("[TabBarController] Delete tapped via floating UI")
        // GridViewController에 선택된 사진 삭제 알림
        if let photosVC = photosNav?.viewControllers.first as? GridViewController {
            photosVC.deleteSelectedPhotos()
        }
    }
}

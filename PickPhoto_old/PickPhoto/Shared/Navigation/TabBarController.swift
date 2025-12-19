// TabBarController.swift
// Photos/Albums 탭으로 TabBarController 생성
//
// T018: Photos/Albums 탭으로 TabBarController 생성

import UIKit

/// PickPhoto 앱의 메인 TabBarController
/// Photos 탭과 Albums 탭을 관리
class TabBarController: UITabBarController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupTabs()
        setupAppearance()
    }

    // MARK: - Setup

    /// 탭 설정
    private func setupTabs() {
        // Photos 탭 (All Photos 그리드)
        // TODO: Phase 3에서 GridViewController로 교체
        let photosVC = createPlaceholderViewController(title: "Photos")
        let photosNav = UINavigationController(rootViewController: photosVC)
        photosNav.tabBarItem = UITabBarItem(
            title: "Photos",
            image: UIImage(systemName: "photo.on.rectangle"),
            selectedImage: UIImage(systemName: "photo.on.rectangle.fill")
        )

        // Albums 탭 (앨범 목록)
        // TODO: Phase 6에서 AlbumsViewController로 교체
        let albumsVC = createPlaceholderViewController(title: "Albums")
        let albumsNav = UINavigationController(rootViewController: albumsVC)
        albumsNav.tabBarItem = UITabBarItem(
            title: "Albums",
            image: UIImage(systemName: "rectangle.stack"),
            selectedImage: UIImage(systemName: "rectangle.stack.fill")
        )

        // 탭 뷰컨트롤러 설정
        viewControllers = [photosNav, albumsNav]

        print("[TabBarController] Tabs configured: Photos, Albums")
    }

    /// 탭바 외관 설정
    private func setupAppearance() {
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
        label.text = "\(title)\n(Phase 3+ 에서 구현)"
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
}

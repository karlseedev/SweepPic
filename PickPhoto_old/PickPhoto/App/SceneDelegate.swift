// SceneDelegate.swift
// UIKit Scene 기반 윈도우 관리
//
// T017: 윈도우 설정으로 SceneDelegate 생성
//
// 역할:
// - UIWindow 설정
// - 루트 뷰컨트롤러 설정 (TabBarController)
// - 권한 체크 및 적절한 화면 표시
// - 백그라운드/포그라운드 전환 처리

import UIKit
import AppCore

/// PickPhoto 앱의 SceneDelegate
/// Scene 기반 윈도우 관리 및 루트 뷰컨트롤러 설정
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // MARK: - Properties

    /// 메인 윈도우
    var window: UIWindow?

    // MARK: - UIWindowSceneDelegate

    /// Scene 연결 시 호출 - 윈도우 설정
    /// - Parameters:
    ///   - scene: 연결된 Scene
    ///   - session: Scene 세션
    ///   - connectionOptions: 연결 옵션
    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        // UIWindowScene 확인
        guard let windowScene = (scene as? UIWindowScene) else { return }

        // 윈도우 생성 및 설정
        let window = UIWindow(windowScene: windowScene)

        // T018: TabBarController를 루트로 설정
        // T065에서 권한 체크 후 적절한 ViewController 표시 로직 추가 예정
        let tabBarController = TabBarController()
        window.rootViewController = tabBarController
        window.makeKeyAndVisible()

        self.window = window

        print("[SceneDelegate] Scene connected, window configured with TabBarController")
    }

    /// Scene이 연결 해제될 때 호출
    /// - Parameter scene: 연결 해제된 Scene
    func sceneDidDisconnect(_ scene: UIScene) {
        // Scene 연결 해제 시 정리 작업
        print("[SceneDelegate] Scene disconnected")
    }

    /// Scene이 활성화될 때 호출
    /// - Parameter scene: 활성화된 Scene
    func sceneDidBecomeActive(_ scene: UIScene) {
        // 앱이 활성 상태가 될 때 처리
        print("[SceneDelegate] Scene became active")
    }

    /// Scene이 비활성화될 때 호출
    /// - Parameter scene: 비활성화된 Scene
    func sceneWillResignActive(_ scene: UIScene) {
        // 앱이 비활성 상태가 될 때 처리
        print("[SceneDelegate] Scene will resign active")
    }

    /// Scene이 포그라운드로 진입할 때 호출
    /// - Parameter scene: 포그라운드로 진입한 Scene
    func sceneWillEnterForeground(_ scene: UIScene) {
        // T015: 포그라운드 진입 시 AppStateStore 처리
        AppStateStore.shared.handleForegroundTransition()
        print("[SceneDelegate] Scene will enter foreground")
    }

    /// Scene이 백그라운드로 진입할 때 호출
    /// - Parameter scene: 백그라운드로 진입한 Scene
    func sceneDidEnterBackground(_ scene: UIScene) {
        // T015: 백그라운드 진입 시 AppStateStore 처리
        AppStateStore.shared.handleBackgroundTransition()
        print("[SceneDelegate] Scene did enter background")
    }
}

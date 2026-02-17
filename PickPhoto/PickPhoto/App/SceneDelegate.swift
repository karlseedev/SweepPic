// SceneDelegate.swift
// UIKit Scene 기반 윈도우 관리
//
// T017: 윈도우 설정으로 SceneDelegate 생성
// T065: 권한 체크 추가 (미승인 시 PermissionViewController 표시)
// T066: 앱 실행 중 권한 변경 처리 (PHPhotoLibrary 권한 변경 감지)
//
// 역할:
// - UIWindow 설정
// - 루트 뷰컨트롤러 설정 (TabBarController 또는 PermissionViewController)
// - 권한 체크 및 적절한 화면 표시
// - 백그라운드/포그라운드 전환 처리
// - 앱 실행 중 권한 변경 감지 및 UI 전환

import UIKit
import Photos
import AppCore

/// PickPhoto 앱의 SceneDelegate
/// Scene 기반 윈도우 관리 및 루트 뷰컨트롤러 설정
class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    // MARK: - Properties

    /// 메인 윈도우
    var window: UIWindow?

    /// 메인 탭바 컨트롤러 (권한 승인 후 사용)
    private var tabBarController: TabBarController?

    /// 권한 뷰컨트롤러 (권한 미승인 시 사용)
    private var permissionViewController: PermissionViewController?

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

        // TODO: 다크모드 강제 (테스트용, 확정 후 제거 또는 유지 결정)
        window.overrideUserInterfaceStyle = .dark

        window.makeKeyAndVisible()
        self.window = window

        // T065: 권한 체크 후 적절한 ViewController 표시
        configureRootViewController()

        // T066: 권한 상태 변경 콜백 등록
        setupPermissionObserver()

        Log.print("[SceneDelegate] Scene connected, window configured")
    }

    // MARK: - T065: Permission Check

    /// 권한 상태에 따른 루트 뷰컨트롤러 설정
    /// FR-033: Limited도 Denied와 동일하게 설정 앱 이동 안내 화면 표시
    private func configureRootViewController() {
        let permissionState = PermissionStore.shared.currentStatus

        switch permissionState {
        case .authorized:
            // 전체 접근 권한 있음 → TabBarController 표시
            showMainInterface()

        case .notDetermined:
            // 권한 요청 전 → PermissionViewController 표시
            showPermissionViewController()

        case .denied, .restricted, .limited:
            // 권한 거부/제한됨 → PermissionViewController 표시 (설정 안내)
            // FR-033: Limited도 Denied와 동일하게 처리
            showPermissionViewController()
        }

        Log.print("[SceneDelegate] configureRootViewController: \(permissionState)")
    }

    /// 메인 인터페이스 표시 (TabBarController)
    private func showMainInterface() {
        // 이미 TabBarController가 표시되어 있으면 무시
        if window?.rootViewController is TabBarController {
            return
        }

        // TabBarController 생성 및 표시
        let tabBarController = TabBarController()
        self.tabBarController = tabBarController

        // 애니메이션으로 전환
        if let window = window {
            UIView.transition(
                with: window,
                duration: 0.3,
                options: .transitionCrossDissolve
            ) {
                window.rootViewController = tabBarController
            }
        }

        // 권한 뷰컨트롤러 해제
        permissionViewController = nil

        Log.print("[SceneDelegate] Showing main interface (TabBarController)")

        // 실측용 Inspector 활성화 (iOS 26 버튼 크기/모양 수집)
        #if DEBUG
        // SystemUIInspector3.shared.showDebugButton()  // JSON Dump - 현재 미사용
        // ButtonInspector.shared.showDebugButton()     // Button Dump - 현재 미사용

        // 효과 비교 쇼케이스: 주석 해제하면 앱 실행 1초 후 자동 표시
        // DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
        //     let showcase = EffectShowcaseViewController()
        //     let nav = UINavigationController(rootViewController: showcase)
        //     nav.modalPresentationStyle = .fullScreen
        //     tabBarController.present(nav, animated: true)
        // }
        #endif
    }

    /// 권한 요청 화면 표시 (PermissionViewController)
    private func showPermissionViewController() {
        // 이미 PermissionViewController가 표시되어 있으면 무시
        if window?.rootViewController is PermissionViewController {
            return
        }

        // PermissionViewController 생성 및 표시
        let permissionVC = PermissionViewController()
        permissionVC.delegate = self
        self.permissionViewController = permissionVC

        // 애니메이션으로 전환
        if let window = window {
            UIView.transition(
                with: window,
                duration: 0.3,
                options: .transitionCrossDissolve
            ) {
                window.rootViewController = permissionVC
            }
        }

        // 탭바 컨트롤러 해제
        tabBarController = nil

        Log.print("[SceneDelegate] Showing permission view controller")
    }

    // MARK: - T066: Permission Change Observer

    /// 권한 상태 변경 옵저버 설정
    private func setupPermissionObserver() {
        PermissionStore.shared.onStatusChange { [weak self] newStatus in
            Log.print("[SceneDelegate] Permission status changed: \(newStatus)")

            // 메인 스레드에서 UI 업데이트
            DispatchQueue.main.async {
                self?.handlePermissionChange(newStatus)
            }
        }
    }

    /// 권한 상태 변경 처리
    /// FR-033: Limited도 Denied와 동일하게 설정 안내 화면 표시
    /// - Parameter status: 새 권한 상태
    private func handlePermissionChange(_ status: PermissionState) {
        switch status {
        case .authorized:
            // 전체 접근 권한 승인됨 → 메인 인터페이스로 전환
            showMainInterface()

        case .denied, .restricted, .limited:
            // 권한 거부/제한됨 → 권한 화면으로 전환 (설정 안내)
            // FR-033: Limited도 Denied와 동일하게 처리
            showPermissionViewController()

        case .notDetermined:
            // 일반적으로 발생하지 않음 (이미 요청됨)
            break
        }
    }

    /// Scene이 연결 해제될 때 호출
    /// - Parameter scene: 연결 해제된 Scene
    func sceneDidDisconnect(_ scene: UIScene) {
        // Scene 연결 해제 시 정리 작업
        Log.print("[SceneDelegate] Scene disconnected")
    }

    /// Scene이 활성화될 때 호출
    /// - Parameter scene: 활성화된 Scene
    func sceneDidBecomeActive(_ scene: UIScene) {
        // 앱이 활성 상태가 될 때 처리
        Log.print("[SceneDelegate] Scene became active")

        // v6: 백그라운드에서 캐시 트림 (용량 관리)
        DispatchQueue.global(qos: .utility).async {
            ThumbnailCache.shared.trimIfNeeded()
        }
    }

    /// Scene이 비활성화될 때 호출
    /// - Parameter scene: 비활성화된 Scene
    func sceneWillResignActive(_ scene: UIScene) {
        // 앱이 비활성 상태가 될 때 처리
        Log.print("[SceneDelegate] Scene will resign active")

        // T084: 자동 정리 진행 중이면 일시정지
        if CleanupService.shared.isRunning {
            CleanupService.shared.pauseCleanup()
            Log.print("[SceneDelegate] Cleanup paused (background)")
        }
    }

    /// Scene이 포그라운드로 진입할 때 호출
    /// - Parameter scene: 포그라운드로 진입한 Scene
    func sceneWillEnterForeground(_ scene: UIScene) {
        // T015: 포그라운드 진입 시 AppStateStore 처리
        AppStateStore.shared.handleForegroundTransition()

        // [Analytics] 사진 규모 구간 갱신 + 앱 실행 시그널
        AnalyticsService.shared.refreshPhotoLibraryBucket()
        AnalyticsService.shared.trackAppLaunched()

        // [Analytics] 이벤트 2: 설정 앱에서 권한 변경 감지 (전후 비교)
        // ⚠️ handlePermissionChange에 넣지 않음 (requestAuthorization에서도 중복 발생하므로)
        let permissionBefore = PermissionStore.shared.currentStatus

        // T066: 설정 앱에서 권한 변경 후 돌아왔을 때 상태 재확인
        PermissionStore.shared.checkAndNotifyIfChanged()

        // [Analytics] 권한 변경이 있으면 settingsChange로 추적
        let permissionAfter = PermissionStore.shared.currentStatus
        if permissionBefore != permissionAfter {
            let result: PermissionResultType = {
                switch permissionAfter {
                case .authorized: return .fullAccess
                case .limited:    return .limitedAccess
                case .denied, .restricted, .notDetermined: return .denied
                }
            }()
            AnalyticsService.shared.trackPermissionResult(result: result, timing: .settingsChange)
        }

        // T060: 외부 삭제 처리 - PhotoKit에서 삭제된 사진을 TrashState에서 제거
        cleanupInvalidTrashedAssets()

        // T085: 자동 정리가 일시정지 상태면 자동 재개
        if let session = CleanupService.shared.currentSession, session.status == .paused {
            CleanupService.shared.resumeCleanup()
            Log.print("[SceneDelegate] Cleanup resumed (foreground)")
        }

        Log.print("[SceneDelegate] Scene will enter foreground")
    }

    /// T060: 휴지통에서 외부 삭제된 사진 정리
    /// PhotoKit에서 더 이상 존재하지 않는 사진을 TrashState에서 제거
    private func cleanupInvalidTrashedAssets() {
        let trashedIDs = TrashStore.shared.trashedAssetIDs
        guard !trashedIDs.isEmpty else { return }

        // PhotoKit에서 유효한 ID만 조회 (Set → Array 변환)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: Array(trashedIDs), options: nil)
        var validIDs = Set<String>()
        fetchResult.enumerateObjects { asset, _, _ in
            validIDs.insert(asset.localIdentifier)
        }

        // 유효하지 않은 ID 제거
        TrashStore.shared.removeInvalidAssets(validAssetIDs: validIDs)
    }

    /// Scene이 백그라운드로 진입할 때 호출
    /// - Parameter scene: 백그라운드로 진입한 Scene
    func sceneDidEnterBackground(_ scene: UIScene) {
        // T015: 백그라운드 진입 시 AppStateStore 처리
        AppStateStore.shared.handleBackgroundTransition()

        // [Analytics] 세션 종료 — 누적 카운터 플러시
        AnalyticsService.shared.handleSessionEnd()

        // 코치마크 C: 백그라운드 진입 시 대기 상태 리셋 (isWaitingForC2 고착 방지)
        if CoachMarkManager.shared.isWaitingForC2 {
            CoachMarkManager.shared.resetC2State()
            CoachMarkManager.shared.currentOverlay?.dismiss()
        }

        Log.print("[SceneDelegate] Scene did enter background")
    }

}

// MARK: - PermissionViewControllerDelegate

extension SceneDelegate: PermissionViewControllerDelegate {

    /// 권한이 승인되어 사진 접근이 가능해졌을 때 호출
    func permissionViewControllerDidGrantAccess(_ controller: PermissionViewController) {
        Log.print("[SceneDelegate] Permission granted, showing main interface")
        showMainInterface()
    }
}

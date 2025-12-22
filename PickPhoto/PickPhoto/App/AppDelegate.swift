// AppDelegate.swift
// UIKit 기반 앱 라이프사이클 관리
//
// 역할:
// - 앱 시작/종료 처리
// - 메모리 경고 대응
// - 백그라운드 전환 처리

import UIKit
import Photos
import AppCore

/// PickPhoto 앱의 AppDelegate
/// UIKit 라이프사이클을 사용하여 앱 상태를 관리
@main
class AppDelegate: UIResponder, UIApplicationDelegate {

    // MARK: - UIApplicationDelegate

    /// 앱 시작 시 호출
    /// - Parameters:
    ///   - application: UIApplication 인스턴스
    ///   - launchOptions: 시작 옵션
    /// - Returns: 시작 성공 여부
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // AppCore 초기화 로그
        print("[AppDelegate] PickPhoto started with AppCore \(AppCore.version)")

        // Gate 2 측정용 환경 정보 로깅
        logEnvironmentInfo()

        // 파이프라인 설정 로깅
        ImagePipeline.shared.logConfig()

        return true
    }

    // MARK: - Debug Logging

    /// 환경 정보 로깅 (Gate 2 측정용)
    private func logEnvironmentInfo() {
        #if DEBUG
        let buildConfig = "Debug"
        #else
        let buildConfig = "Release"
        #endif

        FileLogger.log("[Env] Build: \(buildConfig)")

        // Low Power Mode
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
        FileLogger.log("[Env] LowPowerMode: \(isLowPowerMode ? "ON" : "OFF")")

        // Photos Authorization
        let photoAuthStatus: String
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized: photoAuthStatus = "authorized"
        case .limited: photoAuthStatus = "limited"
        case .denied: photoAuthStatus = "denied"
        case .restricted: photoAuthStatus = "restricted"
        case .notDetermined: photoAuthStatus = "notDetermined"
        @unknown default: photoAuthStatus = "unknown"
        }
        FileLogger.log("[Env] PhotosAuth: \(photoAuthStatus)")

        // Device Info
        var systemInfo = utsname()
        uname(&systemInfo)
        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0) ?? "Unknown"
            }
        }
        let iosVersion = UIDevice.current.systemVersion
        let maxFPS = UIScreen.main.maximumFramesPerSecond
        FileLogger.log("[Device] \(machine), iOS \(iosVersion), \(maxFPS)fps")
    }

    // MARK: - UISceneSession Lifecycle

    /// 새로운 Scene 세션 생성 시 호출
    /// - Parameters:
    ///   - application: UIApplication 인스턴스
    ///   - connectingSceneSession: 연결되는 Scene 세션
    ///   - options: Scene 연결 옵션
    /// - Returns: Scene 구성
    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Info.plist에서 정의한 Default Configuration 사용
        return UISceneConfiguration(
            name: "Default Configuration",
            sessionRole: connectingSceneSession.role
        )
    }

    /// Scene 세션 종료 시 호출
    /// - Parameters:
    ///   - application: UIApplication 인스턴스
    ///   - sceneSessions: 종료되는 Scene 세션들
    func application(
        _ application: UIApplication,
        didDiscardSceneSessions sceneSessions: Set<UISceneSession>
    ) {
        // Scene 세션 정리 (필요시 구현)
    }

    // MARK: - Memory Warning

    /// 메모리 경고 시 호출
    /// - Parameter application: UIApplication 인스턴스
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        print("[AppDelegate] Memory warning received")
        // T072: AppStateStore를 통한 메모리 경고 처리
        AppStateStore.shared.handleMemoryWarning()
    }
}

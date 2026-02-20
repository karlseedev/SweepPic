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
        Log.print("[AppDelegate] PickPhoto started with AppCore \(AppCore.version)")


        // [E) 환경 정보 로그] 전/후 비교용 메타 데이터
        logEnvironmentInfo()

        // [A) 파이프라인 설정값 로그] 전/후 비교용
        ImagePipeline.shared.logConfig()

        // 파이프라인 통계 리셋 (앱 시작 시)
        ImagePipeline.shared.resetStats()

        // [Analytics] TelemetryDeck SDK 초기화 + AppCore 브릿지 주입
        AnalyticsService.shared.configure(appID: "B42FE72D-8A4F-4EA8-90C5-6E2EFA0E7ECC")
        Analytics.reporter = AnalyticsService.shared

        return true
    }

    // MARK: - Environment Info Logging

    /// 환경 정보 로그 (전/후 비교용 메타 데이터)
    /// - Build configuration (Debug/Release)
    /// - Low Power Mode on/off
    /// - Photos 권한 상태 (authorized/limited/denied/notDetermined)
    private func logEnvironmentInfo() {
        // Build configuration
        #if DEBUG
        let buildConfig = "Debug"
        #else
        let buildConfig = "Release"
        #endif

        // Low Power Mode
        let isLowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled

        // Photos 권한 상태
        let photoAuthStatus: String
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized:
            photoAuthStatus = "authorized"
        case .limited:
            photoAuthStatus = "limited"
        case .denied:
            photoAuthStatus = "denied"
        case .restricted:
            photoAuthStatus = "restricted"
        case .notDetermined:
            photoAuthStatus = "notDetermined"
        @unknown default:
            photoAuthStatus = "unknown"
        }

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
        Log.print("[AppDelegate] Memory warning received")
        // T072: AppStateStore를 통한 메모리 경고 처리
        AppStateStore.shared.handleMemoryWarning()
    }
}

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
import OSLog

/// SweepPic 앱의 AppDelegate
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
        Logger.app.debug("SweepPic started with AppCore \(AppCore.version)")

        // XCUITest 환경: 모든 코치마크 완료 처리 (UserDefaults 재설치로 초기화된 경우 대비)
        if CommandLine.arguments.contains("--skip-coachmarks") {
            [CoachMarkType.gridSwipeDelete, .viewerSwipeDelete, .similarPhoto,
             .autoCleanup, .firstDeleteGuide, .firstEmpty, .faceComparisonGuide
            ].forEach { $0.markAsShown() }
            Logger.app.debug("UITest: 모든 코치마크 완료 처리")
        }


        // [E) 환경 정보 로그] 전/후 비교용 메타 데이터
        logEnvironmentInfo()

        // [A) 파이프라인 설정값 로그] 전/후 비교용
        ImagePipeline.shared.logConfig()

        // 파이프라인 통계 리셋 (앱 시작 시)
        ImagePipeline.shared.resetStats()

        #if DEBUG
        // [진단] 메인 스레드 블로킹 감지 (33ms = 2프레임 이상 블로킹 시 로그)
        startMainThreadHangDetector()
        #endif

        // [Analytics] TelemetryDeck SDK 초기화 + AppCore 브릿지 주입
        AnalyticsService.shared.configure(appID: "B42FE72D-8A4F-4EA8-90C5-6E2EFA0E7ECC")
        Analytics.reporter = AnalyticsService.shared

        // [BM] StoreKit 2 구독 상태 확인 + 실시간 감지 시작
        SubscriptionStore.shared.configure()

        // [BM] AdMob SDK 초기화 + 광고 사전 로드 (리워드/전면/InterstitialAdPresenter)
        AdManager.shared.configure()

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

    // MARK: - Main Thread Hang Detector (DEBUG)

    #if DEBUG
    /// 메인 스레드가 33ms 이상 블로킹되면 경고 로그를 출력합니다.
    /// 백그라운드 스레드에서 주기적으로 메인 스레드 응답성을 체크합니다.
    private func startMainThreadHangDetector() {
        DispatchQueue.global(qos: .userInteractive).async {
            while true {
                let semaphore = DispatchSemaphore(value: 0)
                DispatchQueue.main.async {
                    semaphore.signal()
                }
                // 33ms (2프레임) 대기
                let result = semaphore.wait(timeout: .now() + .milliseconds(33))
                if result == .timedOut {
                    // 블로킹 지속 시간 측정
                    let hangStart = CFAbsoluteTimeGetCurrent()
                    semaphore.wait() // 실제 응답까지 대기
                    let hangDuration = (CFAbsoluteTimeGetCurrent() - hangStart) * 1000
                    Logger.performance.error("[ScrollDiag] ⚠️ 메인 스레드 블로킹: \(String(format: "%.0f", hangDuration + 33))ms")
                }
                // 체크 간격: 50ms
                usleep(50_000)
            }
        }
    }
    #endif

    // MARK: - Memory Warning

    /// 메모리 경고 시 호출
    /// - Parameter application: UIApplication 인스턴스
    func applicationDidReceiveMemoryWarning(_ application: UIApplication) {
        Logger.app.notice("Memory warning received")
        // T072: AppStateStore를 통한 메모리 경고 처리
        AppStateStore.shared.handleMemoryWarning()
    }
}

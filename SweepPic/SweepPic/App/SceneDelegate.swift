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
import OSLog

/// SweepPic 앱의 SceneDelegate
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

        // [BM] T012a: 자정 리셋 알림 등록 (FR-005 이중 체크의 두 번째 메커니즘)
        // 앱이 포그라운드에서 자정을 넘길 때 일일 한도 자동 리셋
        setupMidnightResetObserver()

        // [Referral] T044: Push 알림 탭 시 보상 화면 표시 옵저버
        setupPushNotificationObserver()

        Logger.app.debug("Scene connected, window configured")
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
            // 권한 요청 전 → 바로 시스템 권한 팝업 요청
            // (팝업이 뜨기 전까지 빈 화면 표시)
            let placeholder = UIViewController()
            placeholder.view.backgroundColor = .systemBackground
            window?.rootViewController = placeholder
            requestPhotoPermission()

        case .denied, .restricted, .limited:
            // 권한 거부/제한됨 → PermissionViewController 표시 (설정 안내)
            // FR-033: Limited도 Denied와 동일하게 처리
            showPermissionViewController()
        }

        Logger.app.debug("configureRootViewController: \(permissionState.rawValue)")
    }

    /// 최초 실행 시 시스템 권한 팝업 직접 요청
    /// .notDetermined 상태에서만 호출됨
    private func requestPhotoPermission() {
        Task {
            let status = await PermissionStore.shared.requestAuthorization()

            // [Analytics] 최초 권한 요청 결과 추적
            let result: PermissionResultType = {
                switch status {
                case .authorized: return .fullAccess
                case .limited:    return .limitedAccess
                case .denied, .restricted, .notDetermined: return .denied
                }
            }()
            AnalyticsService.shared.trackPermissionResult(result: result, timing: .firstRequest)

            await MainActor.run {
                if status == .authorized {
                    showMainInterface()
                } else {
                    // 거부/제한 → 설정 안내 화면 표시
                    showPermissionViewController()
                }
            }
        }
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

        Logger.app.debug("Showing main interface (TabBarController)")

        // [Referral] T031: 콜드 스타트 시 보상 팝업 체크
        checkAndShowReferralRewardPopup()

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

        // 코치마크 D 재테스트: 주석 해제하면 D 리셋 활성화
        // CoachMarkDPreScanner.shared.debugReset()

        // 코치마크 A-1 재테스트: 주석 해제하면 E-1 리셋 → A-1 재트리거
        // CoachMarkType.firstDeleteGuide.resetShown()

        AnalyticsTestInjector.runIfNeeded()
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

        Logger.app.debug("Showing permission view controller")
    }

    // MARK: - T066: Permission Change Observer

    /// 권한 상태 변경 옵저버 설정
    private func setupPermissionObserver() {
        PermissionStore.shared.onStatusChange { [weak self] newStatus in
            Logger.app.debug("Permission status changed: \(newStatus.rawValue)")

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
        Logger.app.debug("Scene disconnected")
    }

    /// Scene이 활성화될 때 호출
    /// - Parameter scene: 활성화된 Scene
    func sceneDidBecomeActive(_ scene: UIScene) {
        // 앱이 활성 상태가 될 때 처리
        Logger.app.debug("Scene became active")

        // 시스템 권한 팝업 dismiss 후 권한 상태 확인 → 메인 화면 전환
        // (시스템 팝업은 앱을 inactive → active로 전환시킴)
        let currentStatus = PermissionStore.shared.currentStatus
        if currentStatus == .authorized, !(window?.rootViewController is TabBarController) {
            showMainInterface()
        }

        // v6: 백그라운드에서 캐시 트림 (용량 관리)
        DispatchQueue.global(qos: .utility).async {
            ThumbnailCache.shared.trimIfNeeded()
        }

        // [BM] T055: 세션 기록 + 금지 플래그 리셋 (FR-049)
        ReviewService.shared.recordSession()
        ReviewService.shared.resetProhibitedFlags()

        // [BM] T041: ATT 프리프롬프트 표시 (FR-041)
        // ATT 프리프롬프트 표시 (설치 2시간 경과 + Pro 미구독 + ATT .notDetermined + skipCount < 2)
        checkAndShowATTPrompt()

        // [BM] US11: 구독 해지 감지 → Exit Survey 표시
        // PremiumMenuViewController에서 시스템 구독 관리 이동 시 설정한 플래그 확인
        checkAndShowExitSurvey()
    }

    /// Scene이 비활성화될 때 호출
    /// - Parameter scene: 비활성화된 Scene
    func sceneWillResignActive(_ scene: UIScene) {
        // 앱이 비활성 상태가 될 때 처리
        Logger.app.debug("Scene will resign active")

        // T084: 자동 정리 진행 중이면 일시정지
        if CleanupService.shared.isRunning {
            CleanupService.shared.pauseCleanup()
            Logger.app.debug("Cleanup paused (background)")
        }
    }

    /// Scene이 포그라운드로 진입할 때 호출
    /// - Parameter scene: 포그라운드로 진입한 Scene
    func sceneWillEnterForeground(_ scene: UIScene) {
        // T015: 포그라운드 진입 시 AppStateStore 처리
        AppStateStore.shared.handleForegroundTransition()

        // [BM] T012: 포그라운드 진입 시 일일 한도 리셋 체크 (FR-052)
        // 서버 시간 확인 실패 시 로컬 시간 폴백
        checkAndResetDailyLimit()

        // [BM] 포그라운드 진입 시 구독 상태 갱신 (환불/갱신 변경 감지)
        Task {
            await SubscriptionStore.shared.refreshSubscriptionStatus()
        }

        // [Analytics] 사진 규모 구간 갱신 + 앱 실행 시그널 + 보류 큐 재전송
        AnalyticsService.shared.refreshPhotoLibraryBucket()
        AnalyticsService.shared.trackAppLaunched()
        AnalyticsService.shared.flushPendingSupabaseEvents()

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

        // [Referral] T044: 포그라운드 복귀 시 device token 서버 갱신 (FR-026)
        PushNotificationService.shared.refreshTokenIfNeeded()

        // [Referral] T044: 배지 초기화 (FR-028)
        Task { @MainActor in
            PushNotificationService.shared.clearBadge()
        }

        // T060: 외부 삭제 처리 - PhotoKit에서 삭제된 사진을 TrashState에서 제거
        cleanupInvalidTrashedAssets()

        // T085: 자동 정리가 일시정지 상태면 자동 재개
        if let session = CleanupService.shared.currentSession, session.status == .paused {
            CleanupService.shared.resumeCleanup()
            Logger.app.debug("Cleanup resumed (foreground)")
        }

        Logger.app.debug("Scene will enter foreground")
    }

    /// T060: 삭제대기함에서 외부 삭제된 사진 정리
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

        // Supabase POST 완료를 위한 백그라운드 시간 확보 (~30초)
        var bgTaskID: UIBackgroundTaskIdentifier = .invalid

        // 스레드 안전한 종료 헬퍼 (만료 핸들러와 completion이 동시 호출되는 경합 방지)
        let endTask = {
            DispatchQueue.main.async {
                guard bgTaskID != .invalid else { return }  // 이미 종료됨
                UIApplication.shared.endBackgroundTask(bgTaskID)
                bgTaskID = .invalid
            }
        }

        bgTaskID = UIApplication.shared.beginBackgroundTask(withName: "AnalyticsFlush") {
            // 만료 핸들러: 시간 초과 시 즉시 종료
            endTask()
        }

        // Supabase POST 완료 콜백에서 endBackgroundTask 호출
        // ⚠️ handleSessionEnd 내부 동기 경로에서 호출될 수 있으므로 반드시 먼저 설정
        AnalyticsService.shared.onFlushComplete = {
            endTask()
        }

        // [Analytics] 세션 종료 — TD 전송(동기) + Supabase POST(비동기)
        AnalyticsService.shared.handleSessionEnd()

        // 코치마크 C: 백그라운드 진입 시 대기 상태 리셋 (isWaitingForC2 고착 방지)
        if CoachMarkManager.shared.isWaitingForC2 {
            CoachMarkManager.shared.resetC2State()
            CoachMarkManager.shared.currentOverlay?.dismiss()
        }

        Logger.app.debug("Scene did enter background")
    }

}

// MARK: - BM Daily Limit Reset

extension SceneDelegate {

    /// [BM] T012: 포그라운드 진입 시 일일 한도 리셋 체크
    /// 서버 시간(Supabase HTTP Date)으로 확인, 실패 시 로컬 시간 폴백 (FR-052)
    func checkAndResetDailyLimit() {
        // Supabase HTTP Date 헤더로 서버 시간 확인 시도
        fetchServerDate { serverDate in
            UsageLimitStore.shared.resetIfNewDay(serverDate: serverDate)
        }
    }

    /// Supabase 응답의 Date 헤더에서 서버 날짜 추출
    /// - Parameter completion: 서버 날짜 문자열 (yyyy-MM-dd) 또는 nil (실패 시)
    private func fetchServerDate(completion: @escaping (String?) -> Void) {
        // Supabase URL을 Info.plist에서 읽기
        guard let urlString = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String,
              !urlString.isEmpty,
              !urlString.contains("$("),  // xcconfig 미설정 시 빈 값
              let url = URL(string: urlString) else {
            // Supabase 미설정 → 로컬 시간 폴백
            completion(nil)
            return
        }

        // HEAD 요청으로 Date 헤더만 확인 (최소 데이터)
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 5 // 5초 타임아웃

        URLSession.shared.dataTask(with: request) { _, response, error in
            guard error == nil,
                  let httpResponse = response as? HTTPURLResponse,
                  let dateString = httpResponse.value(forHTTPHeaderField: "Date") else {
                // 네트워크 오류 → 로컬 시간 폴백
                DispatchQueue.main.async { completion(nil) }
                return
            }

            // HTTP Date 헤더 파싱 (RFC 7231: "Mon, 03 Mar 2026 12:00:00 GMT")
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(abbreviation: "GMT")

            if let date = formatter.date(from: dateString) {
                // yyyy-MM-dd 형식으로 변환
                let dayFormatter = DateFormatter()
                dayFormatter.dateFormat = "yyyy-MM-dd"
                dayFormatter.timeZone = TimeZone.current
                let dayString = dayFormatter.string(from: date)

                DispatchQueue.main.async { completion(dayString) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }.resume()
    }

    /// [BM] T012a: 자정 리셋 알림 등록
    /// NSCalendar.calendarDayChangedNotification으로 자정 감지
    func setupMidnightResetObserver() {
        NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { _ in
            Logger.app.debug("SceneDelegate: 자정 감지 — 일일 한도 리셋")
            UsageLimitStore.shared.resetIfNewDay(serverDate: nil)
        }
    }
}

// MARK: - ATT Prompt

extension SceneDelegate {

    /// [BM] T041: ATT 프리프롬프트 표시 체크 (FR-041)
    /// 설치 2시간 경과 + Pro 미구독 + ATT .notDetermined + skipCount < 2 → ATTPromptVC present
    func checkAndShowATTPrompt() {
        guard ATTStateManager.shared.shouldShowPrompt else { return }

        // 현재 루트가 TabBarController일 때만 표시 (권한 화면에서는 미표시)
        guard let rootVC = window?.rootViewController,
              rootVC is TabBarController else {
            Logger.app.debug("SceneDelegate: ATT 프롬프트 미표시 — 메인 화면 아님")
            return
        }

        // 이미 다른 모달이 표시 중이면 미표시 (게이트 등과 충돌 방지)
        guard rootVC.presentedViewController == nil else {
            Logger.app.debug("SceneDelegate: ATT 프롬프트 미표시 — 다른 모달 표시 중")
            return
        }

        Logger.app.debug("SceneDelegate: ATT 프리프롬프트 표시")
        let attVC = ATTPromptViewController()
        attVC.modalPresentationStyle = .overFullScreen
        attVC.modalTransitionStyle = .crossDissolve
        rootVC.present(attVC, animated: true)
    }
}

// MARK: - Exit Survey (US11)

extension SceneDelegate {

    /// 구독 해지 감지 → Exit Survey 표시
    /// PremiumMenuViewController에서 시스템 구독 관리 이동 시 설정한
    /// pendingCancelCheck 플래그를 확인하고, autoRenewEnabled 변화를 감지한다.
    func checkAndShowExitSurvey() {
        // 플래그 확인
        guard UserDefaults.standard.bool(forKey: "pendingCancelCheck") else { return }
        let wasAutoRenewing = UserDefaults.standard.bool(forKey: "wasAutoRenewing")

        // 플래그 초기화 (1회만 체크)
        UserDefaults.standard.set(false, forKey: "pendingCancelCheck")

        Task { @MainActor in
            // 구독 상태 갱신 (await로 완료 보장)
            await SubscriptionStore.shared.refreshSubscriptionStatus()

            let currentState = SubscriptionStore.shared.state

            // 해지 감지: 이전에 자동갱신 활성 → 현재 비활성 + 구독 아직 유효
            guard wasAutoRenewing,
                  !currentState.autoRenewEnabled,
                  currentState.isActive else {
                Logger.app.debug("SceneDelegate: Exit Survey 미표시 — 해지 미감지 (wasAutoRenew=\(wasAutoRenewing), current=\(currentState.autoRenewEnabled), active=\(currentState.isActive))")
                return
            }

            // 다른 모달이 표시 중이면 미표시 (충돌 방지)
            guard let rootVC = self.window?.rootViewController,
                  rootVC.presentedViewController == nil else {
                Logger.app.debug("SceneDelegate: Exit Survey 미표시 — 다른 모달 표시 중")
                return
            }

            // Exit Survey 표시
            let exitSurveyVC = ExitSurveyViewController()
            exitSurveyVC.modalPresentationStyle = .pageSheet
            rootVC.present(exitSurveyVC, animated: true)
            Logger.app.debug("SceneDelegate: Exit Survey 표시")
        }
    }
}

// MARK: - Referral Reward Popup (T031)

extension SceneDelegate {

    /// 콜드 스타트 시 대기 중인 보상이 있으면 팝업을 표시한다.
    ///
    /// 조건:
    /// - 메인 화면(TabBarController)이 표시된 상태
    /// - 다른 모달이 표시 중이 아닐 때
    /// - pending 보상이 1건 이상 존재
    ///
    /// 포그라운드 복귀 시에는 팝업 미표시 (콜드 스타트 전용)
    func checkAndShowReferralRewardPopup() {
        let userId = ReferralStore.shared.userId

        Task {
            do {
                let response = try await ReferralService.shared.getPendingRewards(userId: userId)

                // 보상 없으면 무시
                guard !response.rewards.isEmpty else { return }

                await MainActor.run {
                    // 루트가 TabBarController인지 확인
                    guard let rootVC = self.window?.rootViewController,
                          rootVC is TabBarController else {
                        Logger.referral.debug("SceneDelegate: 보상 팝업 미표시 — 메인 화면 아님")
                        return
                    }

                    // 다른 모달이 표시 중이면 미표시
                    guard rootVC.presentedViewController == nil else {
                        Logger.referral.debug("SceneDelegate: 보상 팝업 미표시 — 다른 모달 표시 중")
                        return
                    }

                    // 보상 팝업 표시
                    let rewardVC = ReferralRewardViewController()
                    rootVC.present(rewardVC, animated: true)

                    Logger.referral.debug(
                        "SceneDelegate: 보상 팝업 표시 — \(response.rewards.count)건"
                    )
                }
            } catch {
                // 네트워크 오류 등 — 무시 (다음 실행 시 재시도)
                Logger.referral.error(
                    "SceneDelegate: 보상 조회 실패 — \(error.localizedDescription)"
                )
            }
        }
    }
}

// MARK: - Referral Deep Link (T037)

extension SceneDelegate {

    /// Universal Link 처리 (scene(_:continue:))
    /// 앱이 설치된 상태에서 https://sweeppic.link/r/{code} 링크 탭 시 호출
    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        // Universal Link인지 확인
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = userActivity.webpageURL else {
            Logger.referral.debug("SceneDelegate: Universal Link 아님 — 무시")
            return
        }

        Logger.referral.debug("SceneDelegate: Universal Link 수신 — \(url.absoluteString.prefix(80))")

        // ReferralDeepLinkHandler로 위임
        handleDeepLink(url: url)
    }

    /// Custom URL Scheme 처리 (scene(_:openURLContexts:))
    /// sweeppic://referral/{code} URL로 앱이 열렸을 때 호출
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }

        Logger.referral.debug("SceneDelegate: Custom URL Scheme 수신 — \(url.absoluteString.prefix(80))")

        // ReferralDeepLinkHandler로 위임
        handleDeepLink(url: url)
    }

    /// 딥링크 URL을 ReferralDeepLinkHandler로 전달
    private func handleDeepLink(url: URL) {
        // 초대 코드가 포함된 URL인지 먼저 확인
        guard ReferralDeepLinkHandler.shared.extractReferralCode(from: url) != nil else {
            Logger.referral.debug("SceneDelegate: 초대 코드 없는 URL — 무시")
            return
        }

        // 루트 뷰컨트롤러가 TabBarController인지 확인
        guard let rootVC = window?.rootViewController,
              rootVC is TabBarController else {
            Logger.referral.debug("SceneDelegate: 메인 화면 아님 — 딥링크 무시")
            return
        }

        // 최상위 뷰컨트롤러에서 처리 (모달이 표시 중이면 모달 위에서)
        let presenter = rootVC.presentedViewController ?? rootVC
        ReferralDeepLinkHandler.shared.handleReferralURL(url, from: presenter)
    }
}

// MARK: - Push Notification Observer (T044)

extension SceneDelegate {

    /// Push 알림 탭 시 보상 화면을 표시하는 옵저버를 등록한다.
    /// AppDelegate의 UNUserNotificationCenterDelegate에서 NotificationCenter로 전달받는다.
    func setupPushNotificationObserver() {
        NotificationCenter.default.addObserver(
            forName: .referralRewardPushTapped,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            Logger.referral.debug("SceneDelegate: Push 탭 알림 수신 — 보상 화면 표시")

            guard let self = self,
                  let rootVC = self.window?.rootViewController,
                  rootVC is TabBarController else {
                return
            }

            // 다른 모달이 표시 중이면 dismiss 후 보상 화면 표시
            if let presented = rootVC.presentedViewController {
                presented.dismiss(animated: false) {
                    let rewardVC = ReferralRewardViewController()
                    rootVC.present(rewardVC, animated: true)
                }
            } else {
                let rewardVC = ReferralRewardViewController()
                rootVC.present(rewardVC, animated: true)
            }
        }
    }
}

// MARK: - PermissionViewControllerDelegate

extension SceneDelegate: PermissionViewControllerDelegate {

    /// 권한이 승인되어 사진 접근이 가능해졌을 때 호출
    func permissionViewControllerDidGrantAccess(_ controller: PermissionViewController) {
        Logger.app.debug("Permission granted, showing main interface")
        showMainInterface()
    }
}

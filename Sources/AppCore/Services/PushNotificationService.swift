//
//  PushNotificationService.swift
//  AppCore
//
//  Push 알림 관리 서비스
//  UNUserNotificationCenter 권한 요청, device token 서버 전송,
//  배지 초기화를 담당한다.
//
//  사용 흐름:
//  1. 공유 완료 후 Push 프리프롬프트에서 시스템 권한 요청
//  2. 권한 허용 → registerForRemoteNotifications
//  3. AppDelegate에서 device token 수신 → 서버에 전송
//  4. 포그라운드 복귀 시 device token 서버 갱신 (FR-026)
//
//  참조: specs/004-referral-reward/tasks.md T041
//  참조: specs/004-referral-reward/contracts/api-endpoints.md §update-device-token
//

import Foundation
import OSLog
#if canImport(UserNotifications)
import UserNotifications
#endif
#if canImport(UIKit)
import UIKit
#endif

// MARK: - PushNotificationService

/// Push 알림 관리 서비스
/// 권한 요청, device token 관리, 배지 초기화
public final class PushNotificationService {

    // MARK: - Singleton

    public static let shared = PushNotificationService()

    // MARK: - Properties

    /// 현재 device token (hex 문자열)
    private(set) public var currentDeviceToken: String?

    /// 서버에 마지막으로 전송한 device token
    /// 동일 토큰 중복 전송 방지
    private var lastSentToken: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - Public API: 권한 요청

    /// Push 알림 권한을 요청한다.
    /// 시스템 권한 팝업을 표시하고, 허용 시 remote notification 등록을 시작한다.
    ///
    /// - Parameter completion: 권한 허용 여부
    #if canImport(UserNotifications)
    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                Logger.referral.error("PushService: 권한 요청 실패 — \(error.localizedDescription)")
            }

            Logger.referral.debug("PushService: 권한 요청 결과 — granted=\(granted)")

            if granted {
                // 메인 스레드에서 remote notification 등록
                DispatchQueue.main.async {
                    #if canImport(UIKit)
                    UIApplication.shared.registerForRemoteNotifications()
                    #endif
                }
            }

            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }
    #endif

    /// 현재 Push 알림 권한 상태를 확인한다.
    /// - Returns: 권한 허용 여부
    #if canImport(UserNotifications)
    public func checkAuthorizationStatus() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    #endif

    // MARK: - Public API: Device Token 관리

    /// AppDelegate에서 수신한 device token을 저장하고 서버에 전송한다.
    /// - Parameter tokenData: APNs에서 받은 raw token 데이터
    public func handleDeviceToken(_ tokenData: Data) {
        // Data → hex 문자열 변환
        let token = tokenData.map { String(format: "%02x", $0) }.joined()
        currentDeviceToken = token

        Logger.referral.debug("PushService: device token 수신 — \(token.prefix(16))...")

        // 서버에 전송
        sendTokenToServer(token)
    }

    /// 포그라운드 복귀 시 device token을 서버에 갱신한다 (FR-026).
    /// 토큰이 변경되지 않았으면 중복 전송하지 않는다.
    public func refreshTokenIfNeeded() {
        guard let token = currentDeviceToken else { return }

        // 이미 동일 토큰 전송 완료 → 스킵
        guard token != lastSentToken else {
            Logger.referral.debug("PushService: 토큰 갱신 불필요 — 동일 토큰")
            return
        }

        sendTokenToServer(token)
    }

    // MARK: - Public API: 배지 관리

    /// 앱 아이콘 배지를 초기화한다 (FR-028).
    #if canImport(UIKit)
    @MainActor
    public func clearBadge() {
        UIApplication.shared.applicationIconBadgeNumber = 0
        Logger.referral.debug("PushService: 배지 초기화")
    }
    #endif

    // MARK: - Private: 서버 토큰 전송

    /// device token을 서버(referral-api/update-device-token)에 전송한다.
    private func sendTokenToServer(_ token: String) {
        let userId = ReferralStore.shared.userId

        Task {
            do {
                try await ReferralService.shared.updateDeviceToken(
                    userId: userId,
                    deviceToken: token
                )
                lastSentToken = token
                Logger.referral.debug("PushService: 토큰 서버 전송 성공")
            } catch {
                Logger.referral.error("PushService: 토큰 서버 전송 실패 — \(error.localizedDescription)")
            }
        }
    }
}

//
//  ATTStateManager.swift
//  PickPhoto
//
//  ATT 프리프롬프트 상태 관리 (UserDefaults 저장)
//
//  데이터 모델 (data-model.md ATTState):
//  - skipCount: Int (건너뛰기 횟수, 0~2)
//  - hasShownPrompt: Bool (프리프롬프트 표시 완료 여부)
//
//  shouldShowPrompt 조건 (모두 충족 시):
//  1. skipCount < 2
//  2. !hasShownPrompt
//  3. Grace Period 만료
//  4. ATT == .notDetermined
//

import Foundation
import AppTrackingTransparency
import AppCore
import OSLog

// MARK: - ATTStateManager

/// ATT 프리프롬프트 상태 관리 싱글톤
/// UserDefaults에 skipCount, hasShownPrompt 저장
final class ATTStateManager {

    // MARK: - Singleton

    static let shared = ATTStateManager()

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let skipCount = "att_skipCount"
        static let hasShownPrompt = "att_hasShownPrompt"
    }

    // MARK: - Constants

    /// 최대 건너뛰기 횟수 (이후 영구 미표시)
    private static let maxSkipCount = 2

    // MARK: - Properties

    /// 건너뛰기 횟수 (0, 1, 2)
    var skipCount: Int {
        UserDefaults.standard.integer(forKey: Keys.skipCount)
    }

    /// 프리프롬프트 → 시스템 팝업까지 완료 여부
    var hasShownPrompt: Bool {
        UserDefaults.standard.bool(forKey: Keys.hasShownPrompt)
    }

    /// 프리프롬프트 표시 여부 판단
    /// 모든 조건 충족 시 true:
    /// 1. skipCount < 2 (건너뛰기 2회 미만)
    /// 2. !hasShownPrompt (시스템 팝업 미표시)
    /// 3. Grace Period 만료
    /// 4. ATT == .notDetermined (아직 시스템 팝업 미노출)
    var shouldShowPrompt: Bool {
        // 이미 시스템 팝업까지 표시 완료
        guard !hasShownPrompt else {
            Logger.app.debug("ATTStateManager: shouldShowPrompt=false — 이미 표시 완료")
            return false
        }

        // 건너뛰기 2회 이상 → 영구 미표시
        guard skipCount < Self.maxSkipCount else {
            Logger.app.debug("ATTStateManager: shouldShowPrompt=false — skipCount=\(self.skipCount) ≥ \(Self.maxSkipCount)")
            return false
        }

        // Grace Period 아직 활성 → ATT 미표시 (FR-041: Grace 종료 후 첫 실행)
        guard !GracePeriodService.shared.isActive else {
            Logger.app.debug("ATTStateManager: shouldShowPrompt=false — Grace Period 활성 중")
            return false
        }

        // ATT 이미 결정됨 → 프리프롬프트 불필요
        let attStatus = ATTrackingManager.trackingAuthorizationStatus
        guard attStatus == .notDetermined else {
            Logger.app.debug("ATTStateManager: shouldShowPrompt=false — ATT 이미 결정 (\(attStatus.rawValue))")
            return false
        }

        Logger.app.debug("ATTStateManager: shouldShowPrompt=true — skipCount=\(self.skipCount)")
        return true
    }

    // MARK: - Initialization

    private init() {}

    // MARK: - Methods

    /// 건너뛰기 횟수 증가
    func incrementSkipCount() {
        let newCount = skipCount + 1
        UserDefaults.standard.set(newCount, forKey: Keys.skipCount)
        Logger.app.debug("ATTStateManager: skipCount → \(newCount)")
    }

    /// 시스템 ATT 팝업 표시 완료 마킹
    func markPromptShown() {
        UserDefaults.standard.set(true, forKey: Keys.hasShownPrompt)
        Logger.app.debug("ATTStateManager: hasShownPrompt → true")
    }
}

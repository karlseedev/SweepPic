//
//  ReferralStore.swift
//  AppCore
//
//  초대 리워드 프로그램 클라이언트 상태 관리
//  Keychain 기반 영구 User ID + UserDefaults Push 프리프롬프트 상태
//
//  참조: specs/004-referral-reward/contracts/protocols.md §ReferralStoreProtocol
//  참조: specs/004-referral-reward/data-model.md §ReferralStore
//

import Foundation
import OSLog

// MARK: - ReferralStoreProtocol

/// 초대 프로그램 클라이언트 상태 관리 프로토콜
public protocol ReferralStoreProtocol: AnyObject {
    /// Keychain 기반 영구 사용자 ID (앱 삭제/재설치에도 유지)
    var userId: String { get }

    /// Push 프리프롬프트를 이미 표시했는지 (1회만 표시, FR-025)
    var hasAskedPushPermission: Bool { get set }
}

// MARK: - ReferralStore

/// 초대 프로그램 상태 관리 싱글톤
/// - userId: Keychain에 UUID를 저장, 앱 삭제 후 재설치에도 유지
/// - hasAskedPushPermission: UserDefaults에 저장 (Push 프리프롬프트 1회 제한)
public final class ReferralStore: ReferralStoreProtocol {

    // MARK: - Singleton

    public static let shared = ReferralStore()

    // MARK: - Constants

    /// Keychain 저장 키 — 초대 전용 사용자 식별자
    private static let keychainKey = "sweeppic_referral_id"

    /// UserDefaults 키 — Push 프리프롬프트 표시 여부
    private static let pushAskedKey = "referral_push_asked"

    // MARK: - Cached Properties

    /// 인메모리 캐시 (Keychain 접근 최소화)
    private var cachedUserId: String?

    // MARK: - Initialization

    private init() {}

    // MARK: - ReferralStoreProtocol

    /// Keychain 기반 영구 사용자 ID
    /// 최초 접근 시 Keychain에서 로드하거나 새 UUID를 생성하여 저장
    /// 이후 인메모리 캐시에서 반환 (성능)
    public var userId: String {
        // 인메모리 캐시 확인
        if let cached = cachedUserId {
            return cached
        }

        // Keychain에서 로드 시도
        if let data = KeychainHelper.load(key: Self.keychainKey),
           let existing = String(data: data, encoding: .utf8) {
            cachedUserId = existing
            Logger.referral.debug("ReferralStore: Keychain에서 userId 로드 — \(existing.prefix(8))...")
            return existing
        }

        // 첫 실행: 새 UUID 생성 후 Keychain에 저장
        let newId = UUID().uuidString
        if let data = newId.data(using: .utf8) {
            KeychainHelper.save(key: Self.keychainKey, data: data)
        }
        cachedUserId = newId
        Logger.referral.debug("ReferralStore: 새 userId 생성 — \(newId.prefix(8))...")
        return newId
    }

    /// Push 프리프롬프트를 이미 표시했는지 (1회만 표시)
    /// UserDefaults에 저장 — 앱 삭제 시 리셋됨 (의도적: 재설치 시 다시 물어봄)
    public var hasAskedPushPermission: Bool {
        get { UserDefaults.standard.bool(forKey: Self.pushAskedKey) }
        set {
            UserDefaults.standard.set(newValue, forKey: Self.pushAskedKey)
            Logger.referral.debug("ReferralStore: hasAskedPushPermission = \(newValue)")
        }
    }
}

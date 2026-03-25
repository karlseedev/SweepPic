//
//  KeychainHelper.swift
//  AppCore
//
//  Keychain CRUD 유틸리티
//  kSecClassGenericPassword 기반으로 데이터를 안전하게 저장/조회/삭제
//  앱 삭제/재설치에도 데이터가 유지됨 (악용 방지)
//
//  Service: com.karl.SweepPic.usageLimit
//  AccessLevel: kSecAttrAccessibleAfterFirstUnlock (research.md §R3)
//

import Foundation
import Security

// MARK: - KeychainHelper

/// Keychain 접근을 위한 유틸리티 클래스
/// kSecClassGenericPassword 기반 CRUD 제공
public final class KeychainHelper {

    // MARK: - Constants

    /// Keychain 서비스 식별자
    private static let service = "com.karl.SweepPic.usageLimit"

    // MARK: - Data CRUD

    /// Keychain에 데이터 저장 (기존 값이 있으면 업데이트)
    /// - Parameters:
    ///   - key: 저장 키 (account)
    ///   - data: 저장할 데이터
    /// - Returns: 저장 성공 여부
    @discardableResult
    public static func save(key: String, data: Data) -> Bool {
        // 기존 항목 삭제 후 새로 추가 (update보다 안정적)
        delete(key: key)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            // 기기 첫 잠금 해제 후 접근 가능 (백그라운드에서도 접근 가능)
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Keychain에서 데이터 조회
    /// - Parameter key: 조회 키 (account)
    /// - Returns: 저장된 데이터 (없거나 실패 시 nil)
    public static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess else {
            return nil
        }

        return result as? Data
    }

    /// Keychain에서 데이터 삭제
    /// - Parameter key: 삭제 키 (account)
    /// - Returns: 삭제 성공 여부 (항목이 없어도 true)
    @discardableResult
    public static func delete(key: String) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]

        let status = SecItemDelete(query as CFDictionary)
        return status == errSecSuccess || status == errSecItemNotFound
    }

    // MARK: - Bool Convenience

    /// Bool 값을 Keychain에 저장
    /// - Parameters:
    ///   - key: 저장 키
    ///   - value: Bool 값
    @discardableResult
    public static func setBool(key: String, value: Bool) -> Bool {
        let data = Data([value ? 1 : 0])
        return save(key: key, data: data)
    }

    /// Keychain에서 Bool 값 조회
    /// - Parameter key: 조회 키
    /// - Returns: Bool 값 (없으면 nil)
    public static func getBool(key: String) -> Bool? {
        guard let data = load(key: key), !data.isEmpty else {
            return nil
        }
        return data[0] == 1
    }

    // MARK: - Codable Convenience

    /// Codable 객체를 JSON으로 인코딩하여 Keychain에 저장
    /// - Parameters:
    ///   - key: 저장 키
    ///   - value: Codable 객체
    /// - Returns: 저장 성공 여부
    @discardableResult
    public static func saveCodable<T: Codable>(key: String, value: T) -> Bool {
        guard let data = try? JSONEncoder().encode(value) else {
            return false
        }
        return save(key: key, data: data)
    }

    /// Keychain에서 JSON 데이터를 Codable 객체로 디코딩하여 조회
    /// - Parameters:
    ///   - key: 조회 키
    ///   - type: 디코딩할 타입
    /// - Returns: 디코딩된 객체 (없거나 실패 시 nil)
    public static func loadCodable<T: Codable>(key: String, type: T.Type) -> T? {
        guard let data = load(key: key) else {
            return nil
        }
        return try? JSONDecoder().decode(type, from: data)
    }

    // MARK: - Debug

    #if DEBUG
    /// 디버그용: 특정 서비스의 모든 Keychain 항목 삭제
    public static func deleteAll() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service
        ]
        SecItemDelete(query as CFDictionary)
    }
    #endif
}

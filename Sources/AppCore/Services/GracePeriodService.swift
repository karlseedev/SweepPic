//
//  GracePeriodService.swift
//  AppCore
//
//  설치 후 3일간 무제한 체험 기간(Grace Period) 관리
//  UserDefaults 기반으로 installDate 1회 기록, 경과일 계산
//
//  악용 방지: Keychain의 hasUsedGracePeriod가 true면 Grace Period 미부여 (FR-051a)
//  새 기기 설치 시: Keychain이 비어있으므로 Grace Period 정상 부여
//

import Foundation

// MARK: - GracePeriodServiceProtocol

/// Grace Period 서비스 프로토콜 (contracts/protocols.md)
public protocol GracePeriodServiceProtocol {
    /// Grace Period가 현재 활성 상태인지
    var isActive: Bool { get }
    /// 남은 일수 (0이면 만료)
    var remainingDays: Int { get }
    /// 현재 경과 일수 (0, 1, 2, 3+ — 배너 단계 결정용)
    var currentDay: Int { get }
}

// MARK: - GracePeriodService

/// Grace Period 관리 싱글톤
/// 설치 후 3일간 무제한 체험 기간을 제공
public final class GracePeriodService: GracePeriodServiceProtocol {

    // MARK: - Singleton

    public static let shared = GracePeriodService()

    // MARK: - Constants

    /// Grace Period 기간 (일)
    private static let gracePeriodDays: Int = 3

    /// UserDefaults 키
    private enum Keys {
        static let installDate = "GracePeriod.installDate"
    }

    // MARK: - Properties

    /// 앱 최초 실행일 (UserDefaults에 1회 기록)
    /// 앱 삭제 시 초기화되지만, Keychain의 hasUsedGracePeriod로 재악용 방지
    private var installDate: Date? {
        UserDefaults.standard.object(forKey: Keys.installDate) as? Date
    }

    // MARK: - Initialization

    private init() {
        // 최초 실행 시 installDate 기록
        recordInstallDateIfNeeded()
    }

    // MARK: - GracePeriodServiceProtocol

    /// Grace Period가 현재 활성 상태인지
    /// - Keychain에 hasUsedGracePeriod가 true면 false (재설치 악용 방지)
    /// - installDate로부터 3일 이내면 true
    public var isActive: Bool {
        return false  // [BM] Grace Period → Apple Free Trial 전환으로 비활성화 (A/B 테스트 복원용 코드 유지)

        // 악용 방지: Keychain에서 이전 Grace Period 사용 여부 확인
        if KeychainHelper.getBool(key: "hasUsedGracePeriod") == true {
            return false
        }

        guard let install = installDate else {
            return false
        }

        let elapsed = Calendar.current.dateComponents([.day], from: install, to: Date()).day ?? 0
        return elapsed < Self.gracePeriodDays
    }

    /// Grace Period가 만료되었는지
    public var isExpired: Bool {
        !isActive
    }

    /// 남은 일수 (0이면 만료 또는 미부여)
    public var remainingDays: Int {
        guard isActive, let install = installDate else {
            return 0
        }

        let elapsed = Calendar.current.dateComponents([.day], from: install, to: Date()).day ?? 0
        return max(0, Self.gracePeriodDays - elapsed)
    }

    /// 현재 경과 일수 (0, 1, 2, 3+ — 배너 단계 결정용)
    /// - 0: 설치 당일
    /// - 1: 설치 다음날
    /// - 2: 설치 2일 후
    /// - 3+: 만료 (게이지로 전환)
    public var currentDay: Int {
        guard let install = installDate else {
            return Self.gracePeriodDays // 만료 처리
        }

        let elapsed = Calendar.current.dateComponents([.day], from: install, to: Date()).day ?? 0
        return elapsed
    }

    // MARK: - Grace Period 관리

    /// Grace Period 종료 (구독 구매 시 호출)
    /// Keychain에 hasUsedGracePeriod = true 기록
    public func endGracePeriod() {
        KeychainHelper.setBool(key: "hasUsedGracePeriod", value: true)
    }

    /// 최초 실행 시 installDate 기록
    /// 이미 기록되어 있으면 무시
    private func recordInstallDateIfNeeded() {
        guard installDate == nil else { return }

        // Keychain에 이전 Grace Period 사용 기록이 있으면 installDate도 기록
        // (재설치지만, isActive에서 걸러지므로 installDate 기록은 무해)
        UserDefaults.standard.set(Date(), forKey: Keys.installDate)
    }

    // MARK: - Debug

    #if DEBUG
    /// 디버그용: Grace Period 강제 만료
    public func debugExpire() {
        // installDate를 4일 전으로 설정
        let fourDaysAgo = Calendar.current.date(byAdding: .day, value: -4, to: Date())
        UserDefaults.standard.set(fourDaysAgo, forKey: Keys.installDate)
    }

    /// 디버그용: Grace Period 특정 Day로 설정
    /// - Parameter day: 경과 일수 (0=오늘 설치, 1=어제 설치, 2=2일 전 설치)
    public func debugSetDay(_ day: Int) {
        let pastDate = Calendar.current.date(byAdding: .day, value: -day, to: Date())
        UserDefaults.standard.set(pastDate, forKey: Keys.installDate)
        KeychainHelper.delete(key: "hasUsedGracePeriod")
    }

    /// 디버그용: Grace Period 리셋 (installDate 삭제 + Keychain 플래그 해제)
    public func debugReset() {
        UserDefaults.standard.removeObject(forKey: Keys.installDate)
        KeychainHelper.delete(key: "hasUsedGracePeriod")
        recordInstallDateIfNeeded()
    }
    #endif
}

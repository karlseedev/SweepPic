//
//  ReferralNetworkMonitor.swift
//  AppCore
//
//  초대 리워드 프로그램 전용 네트워크 연결 모니터
//  NWPathMonitor 래퍼 — 오프라인 시 UI 안내 표시용 (FR-039, FR-040)
//
//  참조: specs/004-referral-reward/contracts/protocols.md §ReferralNetworkMonitorProtocol
//

import Foundation
import Network
import OSLog

// MARK: - ReferralNetworkMonitorProtocol

/// 네트워크 연결 상태 모니터링 프로토콜
public protocol ReferralNetworkMonitorProtocol: AnyObject {
    /// 현재 네트워크 연결 여부
    var isConnected: Bool { get }

    /// 네트워크 상태 변경 시 콜백 (메인 스레드에서 호출)
    var onStatusChange: ((Bool) -> Void)? { get set }

    /// 모니터링 시작
    func startMonitoring()

    /// 모니터링 중지
    func stopMonitoring()
}

// MARK: - ReferralNetworkMonitor

/// NWPathMonitor 기반 네트워크 연결 모니터
/// - 초대 관련 화면에서 오프라인 감지 → 안내 UI 표시
/// - 연결 복구 시 자동 재시도 트리거용
public final class ReferralNetworkMonitor: ReferralNetworkMonitorProtocol {

    // MARK: - Singleton

    public static let shared = ReferralNetworkMonitor()

    // MARK: - Properties

    /// NWPathMonitor 인스턴스
    private let monitor = NWPathMonitor()

    /// 모니터 전용 디스패치 큐
    private let queue = DispatchQueue(label: "com.sweeppic.referral.networkMonitor", qos: .utility)

    /// 현재 연결 상태 (thread-safe)
    private var _isConnected: Bool = true
    private let lock = NSLock()

    /// 현재 네트워크 연결 여부
    public var isConnected: Bool {
        lock.lock()
        defer { lock.unlock() }
        return _isConnected
    }

    /// 네트워크 상태 변경 시 콜백 (메인 스레드에서 호출)
    public var onStatusChange: ((Bool) -> Void)?

    /// 모니터링 활성 상태
    private var isMonitoring = false

    // MARK: - Initialization

    private init() {}

    // MARK: - ReferralNetworkMonitorProtocol

    /// 네트워크 모니터링 시작
    /// 중복 호출 시 무시 (이미 모니터링 중이면 스킵)
    public func startMonitoring() {
        guard !isMonitoring else { return }
        isMonitoring = true

        monitor.pathUpdateHandler = { [weak self] path in
            guard let self = self else { return }

            let connected = path.status == .satisfied

            // 상태 업데이트 (thread-safe)
            self.lock.lock()
            let changed = self._isConnected != connected
            self._isConnected = connected
            self.lock.unlock()

            // 상태가 변경된 경우에만 콜백 호출
            if changed {
                Logger.referral.debug("NetworkMonitor: 상태 변경 → \(connected ? "연결됨" : "오프라인")")
                DispatchQueue.main.async {
                    self.onStatusChange?(connected)
                }
            }
        }

        monitor.start(queue: queue)
        Logger.referral.debug("NetworkMonitor: 모니터링 시작")
    }

    /// 네트워크 모니터링 중지
    public func stopMonitoring() {
        guard isMonitoring else { return }
        isMonitoring = false
        monitor.cancel()
        Logger.referral.debug("NetworkMonitor: 모니터링 중지")
    }
}

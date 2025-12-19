// PermissionStore.swift
// 사진 라이브러리 권한 상태 관리 스토어
//
// T014: PermissionStore 생성
// - currentStatus
// - requestAuthorization

import Foundation

// MARK: - PermissionStoreProtocol

/// 권한 스토어 프로토콜
/// 사진 라이브러리 권한 상태 관리를 추상화
public protocol PermissionStoreProtocol: AnyObject {

    /// 현재 권한 상태
    var currentStatus: PermissionState { get }

    /// 사진 라이브러리에 접근 가능한지 여부
    var canAccessPhotos: Bool { get }

    /// 제한적 접근인지 여부
    var isLimited: Bool { get }

    /// 권한 요청
    /// - Returns: 요청 후 권한 상태
    func requestAuthorization() async -> PermissionState

    /// 권한 상태 변경 시 콜백 등록
    /// - Parameter handler: 변경 발생 시 호출될 클로저
    func onStatusChange(_ handler: @escaping (PermissionState) -> Void)
}

// MARK: - PermissionStore (T014)

/// 권한 스토어 구현체
/// PhotoLibraryService를 사용하여 권한 상태 관리
public final class PermissionStore: PermissionStoreProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = PermissionStore()

    // MARK: - Private Properties

    /// 사진 라이브러리 서비스
    private let photoLibraryService: PhotoLibraryServiceProtocol

    /// 상태 변경 핸들러
    private var changeHandler: ((PermissionState) -> Void)?

    /// 이전 상태 (변경 감지용)
    private var previousStatus: PermissionState?

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        self.photoLibraryService = PhotoLibraryService.shared
        self.previousStatus = photoLibraryService.authorizationStatus
    }

    /// 의존성 주입을 위한 초기화 (테스트용)
    /// - Parameter photoLibraryService: 사진 라이브러리 서비스
    public init(photoLibraryService: PhotoLibraryServiceProtocol) {
        self.photoLibraryService = photoLibraryService
        self.previousStatus = photoLibraryService.authorizationStatus
    }

    // MARK: - PermissionStoreProtocol

    /// 현재 권한 상태
    public var currentStatus: PermissionState {
        photoLibraryService.authorizationStatus
    }

    /// 사진 라이브러리에 접근 가능한지 여부
    public var canAccessPhotos: Bool {
        currentStatus.canAccessPhotos
    }

    /// 제한적 접근인지 여부
    public var isLimited: Bool {
        currentStatus.isLimited
    }

    /// 권한 요청
    /// - Returns: 요청 후 권한 상태
    public func requestAuthorization() async -> PermissionState {
        let newStatus = await photoLibraryService.requestAuthorization()

        // 상태 변경 알림
        if newStatus != previousStatus {
            previousStatus = newStatus
            notifyChange(newStatus)
        }

        return newStatus
    }

    /// 권한 상태 변경 콜백 등록
    public func onStatusChange(_ handler: @escaping (PermissionState) -> Void) {
        self.changeHandler = handler
    }

    /// 현재 상태 확인 및 변경 알림
    /// 앱이 포그라운드로 돌아왔을 때 호출
    public func checkAndNotifyIfChanged() {
        let current = currentStatus
        if current != previousStatus {
            previousStatus = current
            notifyChange(current)
        }
    }

    // MARK: - Private Methods

    /// 변경 알림
    private func notifyChange(_ status: PermissionState) {
        DispatchQueue.main.async { [weak self] in
            self?.changeHandler?(status)
        }
    }
}

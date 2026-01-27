// AppStateStore.swift
// 앱 상태 관리 스토어
//
// T015: AppStateStore 생성
// - handleMemoryWarning
// - handleBackgroundTransition

import Foundation

// MARK: - AppStateStoreProtocol

/// 앱 상태 스토어 프로토콜
/// 앱 전역 상태 관리를 추상화
public protocol AppStateStoreProtocol: AnyObject {

    /// 메모리 경고 처리
    /// ImagePipeline 캐시 해제 등 메모리 확보 작업 수행
    func handleMemoryWarning()

    /// 백그라운드 전환 처리
    /// 필요한 상태 저장 및 정리 작업 수행
    func handleBackgroundTransition()

    /// 포그라운드 전환 처리
    /// 필요한 상태 복원 및 갱신 작업 수행
    func handleForegroundTransition()
}

// MARK: - AppStateStore (T015)

/// 앱 상태 스토어 구현체
/// 메모리 경고 및 백그라운드 전환 등 앱 상태 이벤트 처리
public final class AppStateStore: AppStateStoreProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = AppStateStore()

    // MARK: - Private Properties

    /// 이미지 파이프라인 참조
    private weak var imagePipeline: ImagePipeline?

    /// 권한 스토어 참조
    private weak var permissionStore: PermissionStore?

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        // 기본 서비스 연결
        self.imagePipeline = ImagePipeline.shared
        self.permissionStore = PermissionStore.shared
    }

    // MARK: - AppStateStoreProtocol

    /// 메모리 경고 처리
    /// 헌법 V. 메모리 제한 (250MB) 준수를 위해 캐시 즉시 해제
    public func handleMemoryWarning() {
        Log.print("[AppStateStore] Memory warning received, clearing caches")

        // ImagePipeline 캐시 비우기
        ImagePipeline.shared.clearCache()

        // 추가 메모리 확보 작업 (필요시)
        // 예: 오프스크린 뷰 해제, 임시 데이터 삭제 등

        Log.print("[AppStateStore] Memory warning handled")
    }

    /// 백그라운드 전환 처리
    public func handleBackgroundTransition() {
        Log.print("[AppStateStore] App entering background")

        // 프리히트 중지 (배터리 절약)
        ImagePipeline.shared.stopAllPreheating()

        // 추가 정리 작업 (필요시)
        // 예: 진행 중인 네트워크 요청 취소, 타이머 정지 등

        Log.print("[AppStateStore] Background transition handled")
    }

    /// 포그라운드 전환 처리
    public func handleForegroundTransition() {
        Log.print("[AppStateStore] App entering foreground")

        // 권한 상태 변경 확인
        PermissionStore.shared.checkAndNotifyIfChanged()

        // 추가 복원 작업 (필요시)
        // 예: 데이터 갱신, 타이머 재시작 등

        Log.print("[AppStateStore] Foreground transition handled")
    }
}

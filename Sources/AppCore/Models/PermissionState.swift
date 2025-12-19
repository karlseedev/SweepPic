// PermissionState.swift
// 사진 라이브러리 권한 상태 모델
//
// T010: PermissionState enum

import Foundation

// MARK: - PermissionState (T010)

/// 사진 라이브러리 접근 권한 상태
/// PhotoKit의 PHAuthorizationStatus를 앱 내부 표현으로 매핑
///
/// - Note: iOS 14+에서 .limited 상태 추가됨
public enum PermissionState: String, Codable, Sendable {

    /// 권한 요청 전 (앱 최초 실행 시)
    case notDetermined

    /// 사용자가 접근 거부
    case denied

    /// 접근 제한됨 (보호자 통제 등)
    case restricted

    /// 전체 접근 허용
    case authorized

    /// 제한적 접근 허용 (선택된 사진만)
    /// iOS 14+ 전용
    case limited

    // MARK: - Computed Properties

    /// 사진 라이브러리에 접근 가능한지 여부
    /// .authorized 또는 .limited인 경우 true
    public var canAccessPhotos: Bool {
        switch self {
        case .authorized, .limited:
            return true
        case .notDetermined, .denied, .restricted:
            return false
        }
    }

    /// 제한적 접근인지 여부
    /// .limited인 경우 "더 많은 사진 선택" 배너 표시 필요
    public var isLimited: Bool {
        self == .limited
    }

    /// 권한 요청이 필요한지 여부
    /// .notDetermined인 경우 true
    public var needsRequest: Bool {
        self == .notDetermined
    }

    /// 설정 앱으로 이동이 필요한지 여부
    /// .denied 또는 .restricted인 경우 true
    public var needsSettingsNavigation: Bool {
        switch self {
        case .denied, .restricted:
            return true
        case .notDetermined, .authorized, .limited:
            return false
        }
    }
}

// MARK: - CustomStringConvertible

extension PermissionState: CustomStringConvertible {
    public var description: String {
        switch self {
        case .notDetermined:
            return "권한 요청 전"
        case .denied:
            return "접근 거부됨"
        case .restricted:
            return "접근 제한됨"
        case .authorized:
            return "전체 접근 허용"
        case .limited:
            return "제한적 접근"
        }
    }
}

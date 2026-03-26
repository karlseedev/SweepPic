// AnalyticsEnums.swift
// 분석 이벤트에서 사용하는 공통 Enum 정의
//
// - 문자열 파라미터를 enum으로 강제하여 오타/cardinality 폭증 방지
// - 참조: docs/db/260212db-Archi.md 섹션 5.2

import Foundation

// MARK: - ScreenSource (이벤트 3: 사진 열람)

/// 사진 열람 진입 화면 소스
/// - 이벤트 3(사진 열람)에서 진입 경로 구분에 사용
enum ScreenSource: String {
    case library = "library"   // 보관함 (메인 그리드)
    case album   = "album"     // 앨범 상세
    case trash   = "trash"     // 삭제대기함
}

// MARK: - DeleteSource (이벤트 4-1: 삭제·복구)

/// 삭제·복구 진입 경로
/// - 이벤트 4-1(보관함/앨범 삭제·복구)에서 진입 경로 구분에 사용
/// - ScreenSource와 분리: 삭제·복구 switch에서 .trash가 불필요하므로 타입 레벨에서 방지
enum DeleteSource: String {
    case library = "library"   // 보관함 경유
    case album   = "album"     // 앨범 경유
    // 삭제대기함은 이벤트 4-2로 별도 추적 → .trash 불필요
}

// MARK: - PermissionResultType (이벤트 2: 권한)

/// 권한 결과 타입
/// - PermissionState → PermissionResultType 매핑:
///   .authorized → .fullAccess
///   .limited → .limitedAccess
///   .denied → .denied
///   .restricted → .denied (보호자 통제 등, 기능적으로 denied와 동일)
///   .notDetermined → 이벤트 발생하지 않음
enum PermissionResultType: String {
    case fullAccess    = "fullAccess"
    case limitedAccess = "limitedAccess"
    case denied        = "denied"
}

// MARK: - PermissionTiming (이벤트 2: 권한)

/// 권한 확인 시점
/// - firstRequest: 앱 최초 권한 요청 시 (PermissionViewController 경유)
/// - settingsChange: 설정 앱에서 변경 후 복귀 시 (SceneDelegate 경유)
enum PermissionTiming: String {
    case firstRequest   = "firstRequest"
    case settingsChange = "settingsChange"
}

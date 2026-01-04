// FeatureFlags.swift
// 앱 기능 활성화/비활성화 플래그 관리
//
// T000: FeatureFlags.swift 생성
// - isSimilarPhotoEnabled 플래그 정의
// - 개발/테스트 중 기능 토글 용도

import UIKit

/// 앱 기능 플래그
/// 개발/테스트 중 특정 기능 활성화/비활성화에 사용
enum FeatureFlags {

    // MARK: - Similar Photo Feature

    /// 유사 사진 정리 기능 활성화 여부
    /// - 그리드 테두리 애니메이션
    /// - 뷰어 얼굴 +버튼 표시
    /// - 얼굴 비교 화면
    /// - Note: VoiceOver 활성화 시 자동 비활성화
    static var isSimilarPhotoEnabled: Bool {
        // VoiceOver 활성화 시 비활성화 (접근성 고려)
        // 시각 기반 기능으로 시각장애인에게 실질적 사용 가치 없음
        guard !UIAccessibility.isVoiceOverRunning else {
            return false
        }

        // 기본 활성화
        return _isSimilarPhotoEnabled
    }

    /// 유사 사진 기능 수동 토글 (개발/테스트용)
    /// - VoiceOver 상태와 무관하게 기능 끄기 가능
    private static var _isSimilarPhotoEnabled: Bool = true

    /// 유사 사진 기능 수동 비활성화 (개발/테스트용)
    /// - Parameter enabled: 활성화 여부
    static func setSimilarPhotoEnabled(_ enabled: Bool) {
        _isSimilarPhotoEnabled = enabled
    }
}

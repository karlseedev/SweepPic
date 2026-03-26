// HapticFeedback.swift
// 햅틱 피드백 유틸리티
//
// PRD7: 그리드 즉시 삭제/복원
// - 스와이프 삭제/복원 확정 시 light 피드백
// - TrashStore 실패 시 error 피드백

import UIKit

/// 햅틱 피드백 유틸리티
/// 앱 전역에서 일관된 햅틱 피드백 제공
enum HapticFeedback {

    // MARK: - Private Generators

    /// Impact 피드백 생성기 (light)
    private static let lightImpact = UIImpactFeedbackGenerator(style: .light)

    /// Notification 피드백 생성기
    private static let notification = UINotificationFeedbackGenerator()

    // MARK: - Public Methods

    /// 가벼운 임팩트 피드백 (확정 시)
    /// - 스와이프 삭제/복원 확정
    static func light() {
        lightImpact.impactOccurred()
    }

    /// 에러 피드백 (실패 시)
    /// - TrashStore 저장 실패
    /// - 롤백 발생
    static func error() {
        notification.notificationOccurred(.error)
    }

    /// 피드백 준비 (반응 속도 향상)
    /// 제스처 시작 시 호출하여 피드백 지연 최소화
    static func prepare() {
        lightImpact.prepare()
        notification.prepare()
    }
}

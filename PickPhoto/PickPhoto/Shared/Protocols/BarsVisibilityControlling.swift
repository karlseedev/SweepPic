// BarsVisibilityControlling.swift
// Bar 가시성 정책을 선언하는 프로토콜
//
// 중앙 집중식 가시성 제어:
// - 채택하지 않은 VC: TabBarController 기본 정책 적용
// - 채택한 VC: 명시적으로 선언한 값 적용, nil이면 기본 정책
//
// TabBarController 기본 정책:
// - iOS 16~25: 시스템 탭바 숨김, floatingOverlay 표시, 툴바 숨김
// - iOS 26+: 시스템 탭바 표시, 툴바 숨김

import UIKit

/// Bar 가시성 정책을 선언하는 프로토콜
///
/// **사용 방법:**
/// - 일반 VC: 채택 불필요 (TabBarController 기본 정책 적용)
/// - 특별한 요구사항 있는 VC만 채택: ViewerVC처럼 floatingOverlay를 숨겨야 하는 경우
///
/// **값의 의미:**
/// - `nil`: 기본 정책 적용
/// - `true`: 해당 Bar 숨김
/// - `false`: 해당 Bar 표시
protocol BarsVisibilityControlling {
    /// FloatingOverlay 숨김 여부 (iOS 16~25에서만 유효)
    /// - nil: 기본 정책 (표시)
    /// - true: 숨김
    /// - false: 표시
    var prefersFloatingOverlayHidden: Bool? { get }

    /// 시스템 TabBar 숨김 여부
    /// - nil: 기본 정책 (iOS 16~25: 숨김, iOS 26+: 표시)
    /// - true: 숨김
    /// - false: 표시
    var prefersSystemTabBarHidden: Bool? { get }

    /// 시스템 Toolbar 숨김 여부
    /// - nil: 기본 정책 (숨김)
    /// - true: 숨김
    /// - false: 표시
    var prefersToolbarHidden: Bool? { get }
}

// MARK: - Default Implementation

extension BarsVisibilityControlling {
    /// 기본값: nil (TabBarController 기본 정책 따름)
    var prefersFloatingOverlayHidden: Bool? { nil }

    /// 기본값: nil (TabBarController 기본 정책 따름)
    var prefersSystemTabBarHidden: Bool? { nil }

    /// 기본값: nil (TabBarController 기본 정책 따름)
    var prefersToolbarHidden: Bool? { nil }
}

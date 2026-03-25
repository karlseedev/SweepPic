// AnalyticsReporting.swift
// AppCore 내부에서 오류를 보고하기 위한 경량 프로토콜
//
// - SweepPic에서 AnalyticsService를 주입
// - SDK 의존성 없음 (순수 Swift)
// - 참조: docs/db/260212db-Archi.md 섹션 5.7

import Foundation

// MARK: - AnalyticsReporting Protocol

/// AppCore 내부에서 오류를 보고하기 위한 경량 프로토콜
/// - SweepPic의 AnalyticsService가 채택하여 실제 전송
/// - AppCore는 SDK 의존 없이 오류 보고만 가능
public protocol AnalyticsReporting: AnyObject {

    /// 오류 보고
    /// - Parameter key: 오류 키 (예: "photoLoad.gridThumbnail")
    func reportError(key: String)
}

// MARK: - Analytics 전역 접근점

/// AppCore 전역 접근점
/// - SweepPic 앱 시작 시 `Analytics.reporter = AnalyticsService.shared` 주입
/// - AppCore 내부에서는 `Analytics.reporter?.reportError(key:)` 로 호출
public enum Analytics {

    /// SweepPic에서 앱 시작 시 주입
    /// - weak 참조: AnalyticsService 라이프사이클에 영향 없음
    public static weak var reporter: AnalyticsReporting?
}

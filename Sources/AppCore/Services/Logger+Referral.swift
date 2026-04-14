//
//  Logger+Referral.swift
//  AppCore
//
//  초대 리워드 프로그램 전용 Logger 카테고리
//  기존 Logger+App.swift 패턴과 동일
//
//  Usage:
//    import OSLog
//    import AppCore
//
//    Logger.referral.debug("link created: \(code)")
//    Logger.referral.error("API call failed: \(error)")
//

import OSLog

extension Logger {
    /// Referral: 초대 링크 생성, 코드 매칭, 보상 수령, Push 알림
    public static let referral = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.sweeppic.appcore",
        category: "Referral"
    )
}

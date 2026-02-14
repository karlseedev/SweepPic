// AnalyticsService+Lifecycle.swift
// 이벤트 1(앱 실행) + 이벤트 2(권한) 즉시 전송
//
// - 참조: docs/db/260212db-Archi.md 섹션 5.3

import Foundation
import TelemetryDeck
import AppCore

extension AnalyticsService {

    // MARK: - 이벤트 1: 앱 실행

    /// 앱 실행 시그널 전송 (세션당 1건)
    /// - sceneWillEnterForeground에서 호출
    /// - 사진 규모 구간: defaultParameters로 자동 첨부
    /// - 실행 횟수: SDK의 totalSessionsCount 자동 수집
    func trackAppLaunched() {
        guard !shouldSkip() else {
            Log.print("[Analytics] trackAppLaunched 스킵 (shouldSkip=true)")
            return
        }
        TelemetryDeck.signal("app.launched")
        Log.print("[Analytics] ✓ app.launched 전송")
    }

    // MARK: - 이벤트 2: 사진 접근 권한

    /// 권한 결과 시그널 전송
    /// - Parameter result: 권한 결과 (fullAccess/limitedAccess/denied)
    /// - Parameter timing: 시점 (firstRequest/settingsChange)
    func trackPermissionResult(result: PermissionResultType, timing: PermissionTiming) {
        guard !shouldSkip() else { return }
        TelemetryDeck.signal("permission.result", parameters: [
            "result": result.rawValue,
            "timing": timing.rawValue,
        ])
        Log.print("[Analytics] ✓ permission.result 전송 (result=\(result.rawValue), timing=\(timing.rawValue))")
    }
}

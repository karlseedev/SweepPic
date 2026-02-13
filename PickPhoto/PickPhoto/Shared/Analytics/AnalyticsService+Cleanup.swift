// AnalyticsService+Cleanup.swift
// 이벤트 7-1(기존 정리) + 이벤트 7-2(미리보기 정리) 즉시 전송
//
// - 정리 흐름 이탈 시점에 1건 전송
// - 참조: docs/db/260212db-Archi.md 섹션 5.5

import Foundation
import TelemetryDeck

extension AnalyticsService {

    // MARK: - 이벤트 7-1: 기존 정리

    /// 기존 정리 완료 시그널 전송
    /// - Parameter data: 정리 흐름에서 수집된 분석 데이터
    func trackCleanupCompleted(data: CleanupEventData) {
        guard !shouldSkip() else { return }

        var params: [String: String] = [
            "reachedStage":      data.reachedStage.rawValue,
            "trashWarningShown": String(data.trashWarningShown),
            "foundCount":        String(data.foundCount),
            "durationSec":       String(format: "%.1f", data.durationSec),
        ]

        // 옵셔널 필드: nil이면 파라미터에서 제외
        if let method = data.method {
            params["method"] = method.rawValue
        }
        if let result = data.result {
            params["result"] = result.rawValue
        }
        if let progress = data.cancelProgress {
            params["cancelProgress"] = String(format: "%.0f", progress * 100) // 0~100%
        }
        if let action = data.resultAction {
            params["resultAction"] = action.rawValue
        }

        TelemetryDeck.signal("cleanup.completed", parameters: params)
    }

    // MARK: - 이벤트 7-2: 미리보기 정리

    /// 미리보기 정리 완료 시그널 전송
    /// - Parameter data: 미리보기 흐름에서 수집된 분석 데이터
    func trackPreviewCleanupCompleted(data: PreviewCleanupEventData) {
        guard !shouldSkip() else { return }

        TelemetryDeck.signal("cleanup.previewCompleted", parameters: [
            "reachedStage":    data.reachedStage.rawValue,
            "foundCount":      String(data.foundCount),
            "durationSec":     String(format: "%.1f", data.durationSec),
            "maxStageReached": data.maxStageReached.rawValue,
            "expandCount":     String(data.expandCount),
            "excludeCount":    String(data.excludeCount),
            "viewerOpenCount": String(data.viewerOpenCount),
            "finalAction":     data.finalAction.rawValue,
            "movedCount":      String(data.movedCount),
        ])
    }
}

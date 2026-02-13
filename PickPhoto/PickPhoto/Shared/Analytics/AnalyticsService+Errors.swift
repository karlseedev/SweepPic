// AnalyticsService+Errors.swift
// 이벤트 6(오류) 세션 누적 카운터 + AppCore AnalyticsReporting 브릿지
//
// - 카테고리별 오버로드 5개로 타입 안전성 확보
// - AppCore에서는 Analytics.reporter?.reportError(key:)로 호출
// - 참조: docs/db/260212db-Archi.md 섹션 5.4, 5.7

import Foundation
import AppCore

// MARK: - 이벤트 6: 오류 카운팅

extension AnalyticsService {

    /// 사진 로딩 오류 카운터 증가
    func countError(_ error: AnalyticsError.PhotoLoad) {
        guard !shouldSkip() else { return }
        incrementErrorCounter(key: error.rawValue)
    }

    /// 얼굴 감지 오류 카운터 증가
    func countError(_ error: AnalyticsError.Face) {
        guard !shouldSkip() else { return }
        incrementErrorCounter(key: error.rawValue)
    }

    /// 정리 기능 오류 카운터 증가
    func countError(_ error: AnalyticsError.Cleanup) {
        guard !shouldSkip() else { return }
        incrementErrorCounter(key: error.rawValue)
    }

    /// 동영상 오류 카운터 증가
    func countError(_ error: AnalyticsError.Video) {
        guard !shouldSkip() else { return }
        incrementErrorCounter(key: error.rawValue)
    }

    /// 캐시/저장 오류 카운터 증가
    func countError(_ error: AnalyticsError.Storage) {
        guard !shouldSkip() else { return }
        incrementErrorCounter(key: error.rawValue)
    }

    /// 오류 키별 카운터 증가 (내부 공통)
    private func incrementErrorCounter(key: String) {
        queue.async(flags: .barrier) {
            self.counters.errors[key, default: 0] += 1
        }
    }
}

// MARK: - AnalyticsReporting 브릿지

/// AppCore의 AnalyticsReporting 프로토콜 채택
/// - AppCore에서 `Analytics.reporter?.reportError(key:)` 호출 시 여기로 전달
extension AnalyticsService: AnalyticsReporting {

    /// AppCore에서 보고된 오류를 세션 카운터에 누적
    /// - Parameter key: 오류 키 (예: "photoLoad.gridThumbnail")
    public func reportError(key: String) {
        guard !shouldSkip() else { return }
        incrementErrorCounter(key: key)
    }
}

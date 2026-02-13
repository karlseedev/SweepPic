//
//  CleanupDebug.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-13.
//
//  자동 정리 디버그 유틸리티
//  - 분석 결과 로깅 (Log.swift 연동)
//  - 임계값 오버라이드 (UserDefaults 기반)
//  - 배치 분석 통계 로깅
//  - DEBUG 빌드 전용 (#if DEBUG)
//

import Foundation
import AppCore

// MARK: - CleanupDebug

/// 자동 정리 디버그 유틸리티
///
/// DEBUG 빌드에서만 동작하며, 다음 기능을 제공합니다:
/// - 개별 분석 결과 로깅
/// - 배치 분석 통계 로깅
/// - 임계값 실시간 오버라이드 (UserDefaults)
///
/// 사용법:
/// ```swift
/// // 분석 결과 로깅
/// CleanupDebug.logResult(qualityResult)
///
/// // 배치 통계 로깅
/// CleanupDebug.logBatchStats(results, batchIndex: 0, elapsed: 1.5)
///
/// // 임계값 오버라이드
/// CleanupDebug.setOverride(.extremeDarkLuminance, value: 0.08)
/// ```
enum CleanupDebug {

    // MARK: - Logging Category

    /// 로그 카테고리
    private static let category = "Cleanup"

    // MARK: - Analysis Logging

    #if DEBUG

    /// 개별 분석 결과 로깅
    ///
    /// 각 사진의 분석 결과를 Log.swift 카테고리 시스템으로 출력합니다.
    /// - Parameter result: 분석 결과
    static func logResult(_ result: QualityResult) {
        let assetShort = String(result.assetID.prefix(8))
        let verdictStr = verdictDescription(result.verdict)
        let signalStr = result.signals.map { $0.kind.rawValue }.joined(separator: ", ")
        let timeStr = String(format: "%.1f", result.analysisTimeMs)

        Log.debug(category, "[\(assetShort)] \(verdictStr) | signals: [\(signalStr)] | \(timeStr)ms")

        // Safe Guard 적용된 경우 추가 로깅
        if result.safeGuardApplied, let reason = result.safeGuardReason {
            Log.debug(category, "[\(assetShort)] SafeGuard: \(reason.rawValue)")
        }
    }

    /// 배치 분석 통계 로깅
    ///
    /// 배치 단위로 분석 결과를 요약하여 출력합니다.
    /// - Parameters:
    ///   - results: 배치 분석 결과 배열
    ///   - batchIndex: 배치 인덱스 (0-based)
    ///   - elapsed: 배치 처리 소요 시간 (초)
    static func logBatchStats(
        _ results: [QualityResult],
        batchIndex: Int,
        elapsed: TimeInterval
    ) {
        let total = results.count
        let lowQuality = results.filter { $0.verdict.isLowQuality }.count
        let skipped = results.filter { !$0.verdict.isAnalyzed }.count
        let safeGuarded = results.filter { $0.safeGuardApplied }.count
        let analyzed = total - skipped
        let avgTime = analyzed > 0
            ? results.filter { $0.verdict.isAnalyzed }.reduce(0) { $0 + $1.analysisTimeMs } / Double(analyzed)
            : 0

        Log.debug(category, """
        Batch #\(batchIndex): \(total)장 | \
        저품질: \(lowQuality) | SKIP: \(skipped) | SafeGuard: \(safeGuarded) | \
        avg: \(String(format: "%.1f", avgTime))ms | \
        total: \(String(format: "%.1f", elapsed))s
        """)
    }

    /// 스캔 시작 로깅
    ///
    /// - Parameters:
    ///   - method: 정리 방식
    ///   - mode: 판정 모드
    ///   - totalCount: 대상 사진 총 수
    static func logScanStart(method: CleanupMethod, mode: JudgmentMode, totalCount: Int) {
        Log.debug(category, "=== Scan Start ===")
        Log.debug(category, "Method: \(method.displayTitle)")
        Log.debug(category, "Mode: \(mode)")
        Log.debug(category, "Target: \(totalCount)장")
        Log.debug(category, "Batch: \(CleanupConstants.batchSize), Concurrency: \(CleanupConstants.concurrentAnalysis)")

        // 오버라이드 중인 임계값 출력
        logActiveOverrides()
    }

    /// 스캔 완료 로깅
    ///
    /// - Parameters:
    ///   - scannedCount: 검색한 사진 수
    ///   - foundCount: 발견한 저품질 사진 수
    ///   - elapsed: 총 소요 시간 (초)
    ///   - endReason: 종료 사유
    static func logScanEnd(
        scannedCount: Int,
        foundCount: Int,
        elapsed: TimeInterval,
        endReason: EndReason
    ) {
        let rate = elapsed > 0 ? Double(scannedCount) / elapsed : 0

        Log.debug(category, "=== Scan End ===")
        Log.debug(category, "Scanned: \(scannedCount), Found: \(foundCount)")
        Log.debug(category, "Time: \(String(format: "%.1f", elapsed))s (\(String(format: "%.0f", rate))장/초)")
        Log.debug(category, "EndReason: \(endReason)")
    }

    // MARK: - Threshold Override

    /// 오버라이드 가능한 임계값 키
    enum ThresholdKey: String, CaseIterable {
        case extremeDarkLuminance = "debug.cleanup.extremeDarkLuminance"
        case extremeBrightLuminance = "debug.cleanup.extremeBrightLuminance"
        case severeBlurLaplacian = "debug.cleanup.severeBlurLaplacian"
        case generalBlurLaplacian = "debug.cleanup.generalBlurLaplacian"
        case faceQualityThreshold = "debug.cleanup.faceQualityThreshold"
        case batchSize = "debug.cleanup.batchSize"
        case concurrentAnalysis = "debug.cleanup.concurrentAnalysis"
    }

    /// 임계값 오버라이드 설정
    ///
    /// UserDefaults에 값을 저장하여 런타임에 임계값을 변경합니다.
    /// 앱 재시작 후에도 유지됩니다.
    ///
    /// - Parameters:
    ///   - key: 오버라이드할 임계값 키
    ///   - value: 새 값 (nil이면 오버라이드 제거)
    static func setOverride(_ key: ThresholdKey, value: Double?) {
        if let value = value {
            UserDefaults.standard.set(value, forKey: key.rawValue)
            Log.debug(category, "Override SET: \(key.rawValue) = \(value)")
        } else {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
            Log.debug(category, "Override REMOVED: \(key.rawValue)")
        }
    }

    /// 오버라이드된 값 가져오기
    ///
    /// - Parameters:
    ///   - key: 임계값 키
    ///   - defaultValue: 기본값 (오버라이드가 없을 때 사용)
    /// - Returns: 오버라이드 값 또는 기본값
    static func overrideValue(for key: ThresholdKey, default defaultValue: Double) -> Double {
        let stored = UserDefaults.standard.double(forKey: key.rawValue)
        // UserDefaults.double은 키가 없으면 0.0 반환
        // 실제로 0.0을 설정한 것인지 키가 없는 것인지 구분
        if UserDefaults.standard.object(forKey: key.rawValue) != nil {
            return stored
        }
        return defaultValue
    }

    /// 오버라이드된 Int 값 가져오기
    ///
    /// - Parameters:
    ///   - key: 임계값 키
    ///   - defaultValue: 기본값
    /// - Returns: 오버라이드 값 또는 기본값
    static func overrideIntValue(for key: ThresholdKey, default defaultValue: Int) -> Int {
        if UserDefaults.standard.object(forKey: key.rawValue) != nil {
            return UserDefaults.standard.integer(forKey: key.rawValue)
        }
        return defaultValue
    }

    /// 모든 오버라이드 초기화
    static func clearAllOverrides() {
        for key in ThresholdKey.allCases {
            UserDefaults.standard.removeObject(forKey: key.rawValue)
        }
        Log.debug(category, "All overrides cleared")
    }

    /// 현재 활성 오버라이드 로깅
    private static func logActiveOverrides() {
        var overrides: [String] = []

        for key in ThresholdKey.allCases {
            if UserDefaults.standard.object(forKey: key.rawValue) != nil {
                let value = UserDefaults.standard.double(forKey: key.rawValue)
                overrides.append("\(key.rawValue.replacingOccurrences(of: "debug.cleanup.", with: ""))=\(value)")
            }
        }

        if !overrides.isEmpty {
            Log.debug(category, "Active overrides: \(overrides.joined(separator: ", "))")
        }
    }

    // MARK: - Verdict Description

    /// 판정 결과를 사람이 읽기 쉬운 문자열로 변환
    private static func verdictDescription(_ verdict: QualityVerdict) -> String {
        switch verdict {
        case .lowQuality:
            return "LOW"
        case .acceptable:
            return "OK"
        case .skipped(let reason):
            return "SKIP(\(reason.rawValue))"
        }
    }

    #endif
}

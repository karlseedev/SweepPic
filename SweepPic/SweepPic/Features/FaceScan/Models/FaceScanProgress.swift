//
//  FaceScanProgress.swift
//  SweepPic
//
//  인물사진 비교정리 — 스캔 진행 상황 모델
//  - 진행 상황 콜백에서 UI 업데이트용으로 사용
//
//  CleanupProgress 패턴 참조
//

import Foundation

// MARK: - AnalysisState

/// 분석 상태 (게이지바 텍스트 분기용)
enum AnalysisState: Equatable {
    /// Phase A: FP 생성 중 — 게이지 0%, "분석 준비 중"
    case preparing
    /// Phase C: 그룹 검증 중 — 게이지 활성, "N그룹 발견 · N / N장 검색"
    case analyzing
}

/// 인물사진 비교정리 스캔 진행 상황
///
/// 스캔 중 UI 업데이트를 위한 진행 상황 데이터.
/// onProgress 콜백을 통해 FaceScanListVC에 전달됨.
struct FaceScanProgress: Equatable {

    /// 검색한 사진 수 (Phase C rawGroup 처리 비율 기반 체감 환산값)
    let scannedCount: Int

    /// 발견한 그룹 수
    let groupCount: Int

    /// 현재 스캔 시점 (현재 분석 중인 사진의 creationDate)
    let currentDate: Date

    /// 진행률 (0.0 ~ 1.0)
    /// - scannedCount / totalPhotoCount와 groupCount / maxGroupCount 중 큰 값
    let progress: Float

    /// 실제 분석 대상 사진 수 (UI 분모용, 런타임 결정)
    let totalPhotoCount: Int

    /// 최대 그룹 수 (UI 분모용): 30그룹
    let maxGroupCount: Int

    /// 분석 상태 (preparing: FP 생성 중, analyzing: 그룹 검증 중)
    let state: AnalysisState
}

// MARK: - Factory Methods

extension FaceScanProgress {

    /// 초기 진행 상황 생성 (Phase A 시작 — "분석 준비 중")
    static func initial() -> FaceScanProgress {
        return FaceScanProgress(
            scannedCount: 0,
            groupCount: 0,
            currentDate: Date(),
            progress: 0,
            totalPhotoCount: 0,
            maxGroupCount: FaceScanConstants.maxGroupCount,
            state: .preparing
        )
    }

    /// 업데이트된 진행 상황 생성
    ///
    /// - Parameters:
    ///   - scannedCount: Phase C rawGroup 처리 비율 기반 체감 환산값
    ///   - groupCount: 발견된 유효 그룹 수
    ///   - currentDate: 현재 시점
    ///   - actualPhotosCount: 실제 분석 대상 사진 수 (scanRatio 분모)
    ///   - state: 분석 상태 (기본: .analyzing)
    static func updated(
        scannedCount: Int,
        groupCount: Int,
        currentDate: Date,
        actualPhotosCount: Int,
        state: AnalysisState = .analyzing
    ) -> FaceScanProgress {
        // 진행률 계산 (state별 분기)
        let effectiveMax = max(actualPhotosCount, 1)  // division by zero 방지
        let scanRatio = Float(scannedCount) / Float(effectiveMax)
        let groupRatio = Float(groupCount) / Float(FaceScanConstants.maxGroupCount)
        let progress: Float
        switch state {
        case .preparing:
            // Phase A: FP 생성 진행률만 (0% → 100%)
            progress = scanRatio
        case .analyzing:
            // Phase C: 사진 검색 비율과 그룹 비율 중 큰 값
            progress = max(scanRatio, groupRatio)
        }
        return FaceScanProgress(
            scannedCount: scannedCount,
            groupCount: groupCount,
            currentDate: currentDate,
            progress: min(progress, 1.0),
            totalPhotoCount: actualPhotosCount,
            maxGroupCount: FaceScanConstants.maxGroupCount,
            state: state
        )
    }
}

// MARK: - UI 지원

extension FaceScanProgress {

    /// 진행 중 문구: "N그룹 발견 · N / N장 검색"
    var progressText: String {
        String(localized: "faceScan.progress.progressText \(groupCount) \(scannedCount) \(totalPhotoCount)")
    }

    /// 완료 문구: "분석 완료 · N그룹 발견" 또는 "분석 완료 · 발견된 그룹 없음"
    var completionText: String {
        if groupCount > 0 {
            return String(localized: "faceScan.progress.completionWithGroups \(groupCount)")
        } else {
            return String(localized: "faceScan.progress.completionNoGroups")
        }
    }
}

// MARK: - CustomStringConvertible

extension FaceScanProgress: CustomStringConvertible {

    var description: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: currentDate)
        return "[FaceScanProgress] Scanned: \(scannedCount)/\(totalPhotoCount), Groups: \(groupCount)/\(maxGroupCount), State: \(state), Date: \(dateStr)"
    }
}

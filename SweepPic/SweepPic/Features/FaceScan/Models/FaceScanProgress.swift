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

/// 인물사진 비교정리 스캔 진행 상황
///
/// 스캔 중 UI 업데이트를 위한 진행 상황 데이터.
/// onProgress 콜백을 통해 FaceScanListVC에 전달됨.
struct FaceScanProgress: Equatable {

    /// 검색한 사진 수 (현재까지 분석 완료한 사진 수)
    let scannedCount: Int

    /// 발견한 그룹 수
    let groupCount: Int

    /// 현재 스캔 시점 (현재 분석 중인 사진의 creationDate)
    let currentDate: Date

    /// 진행률 (0.0 ~ 1.0)
    /// - scannedCount / maxScanCount와 groupCount / maxGroupCount 중 큰 값
    let progress: Float

    /// 최대 검색 수 (UI 분모용): 1,000장
    let maxScanCount: Int

    /// 최대 그룹 수 (UI 분모용): 30그룹
    let maxGroupCount: Int
}

// MARK: - Factory Methods

extension FaceScanProgress {

    /// 초기 진행 상황 생성
    static func initial() -> FaceScanProgress {
        return FaceScanProgress(
            scannedCount: 0,
            groupCount: 0,
            currentDate: Date(),
            progress: 0,
            maxScanCount: FaceScanConstants.maxScanCount,
            maxGroupCount: FaceScanConstants.maxGroupCount
        )
    }

    /// 업데이트된 진행 상황 생성
    static func updated(
        scannedCount: Int,
        groupCount: Int,
        currentDate: Date
    ) -> FaceScanProgress {
        // 진행률 계산: 검색 비율과 그룹 비율 중 큰 값
        let scanRatio = Float(scannedCount) / Float(FaceScanConstants.maxScanCount)
        let groupRatio = Float(groupCount) / Float(FaceScanConstants.maxGroupCount)
        let progress = max(scanRatio, groupRatio)
        return FaceScanProgress(
            scannedCount: scannedCount,
            groupCount: groupCount,
            currentDate: currentDate,
            progress: min(progress, 1.0),
            maxScanCount: FaceScanConstants.maxScanCount,
            maxGroupCount: FaceScanConstants.maxGroupCount
        )
    }
}

// MARK: - UI 지원

extension FaceScanProgress {

    /// 진행 중 문구: "N그룹 발견 · N / 1,000장 검색"
    var progressText: String {
        let scanFormatted = NumberFormatter.localizedString(
            from: NSNumber(value: maxScanCount), number: .decimal
        )
        return "\(groupCount)그룹 발견 · \(scannedCount) / \(scanFormatted)장 검색"
    }

    /// 완료 문구: "분석 완료 · N그룹 발견" 또는 "분석 완료 · 발견된 그룹 없음"
    var completionText: String {
        if groupCount > 0 {
            return "분석 완료 · \(groupCount)그룹 발견"
        } else {
            return "분석 완료 · 발견된 그룹 없음"
        }
    }
}

// MARK: - CustomStringConvertible

extension FaceScanProgress: CustomStringConvertible {

    var description: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: currentDate)
        return "[FaceScanProgress] Scanned: \(scannedCount)/\(maxScanCount), Groups: \(groupCount)/\(maxGroupCount), Date: \(dateStr)"
    }
}

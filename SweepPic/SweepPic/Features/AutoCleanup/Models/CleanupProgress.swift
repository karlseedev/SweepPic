//
//  CleanupProgress.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  정리 진행 상황 정의
//  - 진행 상황 콜백에서 UI 업데이트용으로 사용
//

import Foundation

/// 정리 진행 상황
///
/// 탐색 중 UI 업데이트를 위한 진행 상황 데이터.
/// progressHandler 콜백을 통해 전달됨.
struct CleanupProgress: Equatable {

    /// 검색한 사진 수
    /// - 현재까지 분석 완료한 사진 수
    let scannedCount: Int

    /// 찾은 저품질 사진 수
    /// - 현재까지 저품질로 판정된 사진 수
    let foundCount: Int

    /// 현재 탐색 시점
    /// - 현재 분석 중인 사진의 creationDate
    /// - UI에서 "2026년 5월부터 탐색 중..." 형식으로 표시
    let currentDate: Date

    /// 진행률 (0.0 ~ 1.0)
    /// - 최대 검색 수(2,000장) 기준 진행률
    /// - foundCount가 50에 가까워지면 빠르게 완료될 수 있음
    let progress: Float

    /// 최대 찾기 수 (UI 분모용)
    /// - "23 / 50장 발견"에서 50
    let maxFoundCount: Int

    /// 최대 검색 수 (UI 분모용)
    /// - "850 / 2,000장 검색"에서 2,000
    let maxScanCount: Int

    // MARK: - Computed Properties

    /// 최대 찾기 수(50)까지의 진행률
    var foundProgress: Float {
        return Float(foundCount) / Float(CleanupConstants.maxFoundCount)
    }

    /// 최대 검색 수(2000)까지의 진행률
    var scanProgress: Float {
        return Float(scannedCount) / Float(CleanupConstants.maxScanCount)
    }

    /// 탐색 완료 예상 여부
    /// - 50장 찾을 때까지 계속 탐색
    /// - 2,000장 검색 시 종료
    var isNearCompletion: Bool {
        return foundCount >= CleanupConstants.maxFoundCount - 5 ||
               scannedCount >= CleanupConstants.maxScanCount - 100
    }
}

// MARK: - UI 지원

extension CleanupProgress {

    /// 찾은 사진 수 표시 문자열
    /// - "23장 발견" 형식
    var foundCountDescription: String {
        return "\(foundCount)장 발견"
    }

    /// 진행률 백분율 문자열
    /// - "45%" 형식
    var progressPercentage: String {
        return "\(Int(progress * 100))%"
    }
}

// MARK: - Factory Methods

extension CleanupProgress {

    /// 초기 진행 상황 생성
    static func initial(startDate: Date) -> CleanupProgress {
        return CleanupProgress(
            scannedCount: 0,
            foundCount: 0,
            currentDate: startDate,
            progress: 0,
            maxFoundCount: CleanupConstants.maxFoundCount,
            maxScanCount: CleanupConstants.maxScanCount
        )
    }

    /// 업데이트된 진행 상황 생성
    static func updated(
        scannedCount: Int,
        foundCount: Int,
        currentDate: Date,
        maxFoundCount: Int = CleanupConstants.maxFoundCount,
        maxScanCount: Int = CleanupConstants.maxScanCount
    ) -> CleanupProgress {
        // 진행률 계산: 발견 비율과 검색 비율 중 큰 값
        // → 50장 먼저 찾으면 발견 비율이, 2000장 먼저 도달하면 검색 비율이 주도
        let scanRatio = Float(scannedCount) / Float(maxScanCount)
        let foundRatio = Float(foundCount) / Float(maxFoundCount)
        let progress = max(scanRatio, foundRatio)
        return CleanupProgress(
            scannedCount: scannedCount,
            foundCount: foundCount,
            currentDate: currentDate,
            progress: min(progress, 1.0),
            maxFoundCount: maxFoundCount,
            maxScanCount: maxScanCount
        )
    }
}

// MARK: - CustomStringConvertible

extension CleanupProgress: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateStr = dateFormatter.string(from: currentDate)

        return "[Progress] Scanned: \(scannedCount)/\(CleanupConstants.maxScanCount), Found: \(foundCount)/\(CleanupConstants.maxFoundCount), Date: \(dateStr), Progress: \(progressPercentage)"
    }
}

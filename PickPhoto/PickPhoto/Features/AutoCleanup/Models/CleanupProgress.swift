//
//  CleanupProgress.swift
//  PickPhoto
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
    /// - 최대 검색 수(1,000장) 기준 진행률
    /// - foundCount가 50에 가까워지면 빠르게 완료될 수 있음
    let progress: Float

    // MARK: - Computed Properties

    /// 최대 찾기 수(50)까지의 진행률
    var foundProgress: Float {
        return Float(foundCount) / Float(CleanupConstants.maxFoundCount)
    }

    /// 최대 검색 수(1000)까지의 진행률
    var scanProgress: Float {
        return Float(scannedCount) / Float(CleanupConstants.maxScanCount)
    }

    /// 탐색 완료 예상 여부
    /// - 50장 찾을 때까지 계속 탐색
    /// - 1,000장 검색 시 종료
    var isNearCompletion: Bool {
        return foundCount >= CleanupConstants.maxFoundCount - 5 ||
               scannedCount >= CleanupConstants.maxScanCount - 100
    }
}

// MARK: - UI 지원

extension CleanupProgress {

    /// 현재 탐색 시점을 문자열로 표현
    /// - 연도별 정리: "2024년 사진 탐색 중..."
    /// - 일반 정리: "2024년 5월부터 탐색 중..."
    func currentDateDescription(for method: CleanupMethod) -> String {
        let calendar = Calendar.current
        let year = calendar.component(.year, from: currentDate)

        switch method {
        case .byYear(_, _):
            // 연도별 정리: 월 생략
            return "\(year)년 사진 탐색 중..."
        case .fromLatest, .continueFromLast:
            // 일반 정리: 월 포함
            let month = calendar.component(.month, from: currentDate)
            return "\(year)년 \(month)월부터 탐색 중..."
        }
    }

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
            progress: 0
        )
    }

    /// 업데이트된 진행 상황 생성
    static func updated(
        scannedCount: Int,
        foundCount: Int,
        currentDate: Date
    ) -> CleanupProgress {
        // 진행률 계산: 검색 수 기준 (최대 1,000장)
        let progress = Float(scannedCount) / Float(CleanupConstants.maxScanCount)
        return CleanupProgress(
            scannedCount: scannedCount,
            foundCount: foundCount,
            currentDate: currentDate,
            progress: min(progress, 1.0)
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

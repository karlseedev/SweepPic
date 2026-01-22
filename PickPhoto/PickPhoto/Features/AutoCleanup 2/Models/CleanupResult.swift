//
//  CleanupResult.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  전체 정리 결과 정의
//  - CleanupResultType: 결과 유형 (completed/noneFound/cancelled)
//  - EndReason: 종료 사유
//  - CleanupResult: 정리 결과 데이터
//

import Foundation

// MARK: - CleanupResultType

/// 결과 유형
///
/// 정리 작업의 최종 결과 유형.
enum CleanupResultType: Equatable {

    /// 정상 완료
    /// - N장의 저품질 사진을 휴지통으로 이동
    /// - associated value: 이동한 사진 수
    case completed(count: Int)

    /// 0장 발견
    /// - 탐색 완료했으나 저품질 사진 없음
    case noneFound

    /// 사용자 취소
    /// - 아무것도 휴지통으로 이동하지 않음
    /// - 취소 시점까지 찾은 사진도 이동하지 않음
    case cancelled

    /// 이동한 사진 수
    var trashedCount: Int {
        switch self {
        case .completed(let count):
            return count
        case .noneFound, .cancelled:
            return 0
        }
    }

    /// 성공적으로 완료되었는지 (취소 아닌 정상 종료)
    var isSuccess: Bool {
        switch self {
        case .completed, .noneFound:
            return true
        case .cancelled:
            return false
        }
    }
}

// MARK: - EndReason

/// 종료 사유
///
/// 정리 탐색이 종료된 이유.
enum EndReason: String, Codable, CaseIterable {

    /// 최대 찾기 수 도달
    /// - 50장의 저품질 사진을 찾음
    case maxFound

    /// 최대 검색 수 도달
    /// - 1,000장을 검색함
    case maxScanned

    /// 범위 끝 도달
    /// - 연도별: 해당 연도의 모든 사진 검색 완료
    /// - 전체: 가장 오래된 사진까지 도달
    case endOfRange

    /// 사용자 취소
    /// - 취소 버튼 탭
    case userCancelled
}

// MARK: - CleanupResult

/// 정리 결과
///
/// 전체 정리 작업의 결과 데이터.
struct CleanupResult: Equatable {

    /// 세션 ID
    let sessionID: UUID

    /// 결과 유형
    let resultType: CleanupResultType

    /// 검색한 사진 수
    let scannedCount: Int

    /// 찾은 저품질 사진 수
    let foundCount: Int

    /// 휴지통으로 이동한 사진 ID 목록
    let trashedAssetIDs: [String]

    /// 총 소요 시간 (초)
    let totalTimeSeconds: Double

    /// 탐색 종료 사유
    let endReason: EndReason

    // MARK: - Convenience Initializers

    /// 정상 완료 결과 생성
    static func completed(
        sessionID: UUID,
        scannedCount: Int,
        foundCount: Int,
        trashedAssetIDs: [String],
        totalTimeSeconds: Double,
        endReason: EndReason
    ) -> CleanupResult {
        return CleanupResult(
            sessionID: sessionID,
            resultType: .completed(count: trashedAssetIDs.count),
            scannedCount: scannedCount,
            foundCount: foundCount,
            trashedAssetIDs: trashedAssetIDs,
            totalTimeSeconds: totalTimeSeconds,
            endReason: endReason
        )
    }

    /// 0장 발견 결과 생성
    static func noneFound(
        sessionID: UUID,
        scannedCount: Int,
        totalTimeSeconds: Double,
        endReason: EndReason
    ) -> CleanupResult {
        return CleanupResult(
            sessionID: sessionID,
            resultType: .noneFound,
            scannedCount: scannedCount,
            foundCount: 0,
            trashedAssetIDs: [],
            totalTimeSeconds: totalTimeSeconds,
            endReason: endReason
        )
    }

    /// 취소 결과 생성
    static func cancelled(
        sessionID: UUID,
        scannedCount: Int,
        foundCount: Int,
        totalTimeSeconds: Double
    ) -> CleanupResult {
        return CleanupResult(
            sessionID: sessionID,
            resultType: .cancelled,
            scannedCount: scannedCount,
            foundCount: foundCount,
            trashedAssetIDs: [],  // 취소 시 아무것도 이동 안 함
            totalTimeSeconds: totalTimeSeconds,
            endReason: .userCancelled
        )
    }
}

// MARK: - UI 지원

extension CleanupResult {

    /// UI에 표시할 결과 메시지
    var displayMessage: String {
        switch resultType {
        case .completed(let count):
            return CleanupConstants.resultMessage(count: count)
        case .noneFound:
            return CleanupConstants.noneFoundMessage
        case .cancelled:
            return ""  // 취소 시 메시지 없음 (즉시 종료)
        }
    }

    /// 휴지통 보기 버튼 표시 여부
    /// - 1장 이상 이동했을 때만 표시
    var shouldShowTrashButton: Bool {
        return trashedAssetIDs.count > 0
    }
}

// MARK: - CustomStringConvertible

extension CleanupResult: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        let typeStr: String
        switch resultType {
        case .completed(let count):
            typeStr = "COMPLETED (\(count)장 이동)"
        case .noneFound:
            typeStr = "NONE_FOUND"
        case .cancelled:
            typeStr = "CANCELLED"
        }

        return """
        [CleanupResult]
        - Type: \(typeStr)
        - Scanned: \(scannedCount)장
        - Found: \(foundCount)장
        - Trashed: \(trashedAssetIDs.count)장
        - Time: \(String(format: "%.1f", totalTimeSeconds))초
        - EndReason: \(endReason.rawValue)
        """
    }
}

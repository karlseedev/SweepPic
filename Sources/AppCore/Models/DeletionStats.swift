//
//  DeletionStats.swift
//  AppCore
//
//  누적 삭제 통계 모델 (data-model.md DeletionStats)
//
//  저장 경로: Documents/DeletionStats.json
//  저장 패턴: TrashStore 동일 (JSONEncoder, iso8601, atomic write, serial queue)
//
//  - totalDeletedCount: 누적 삭제 장수
//  - totalFreedBytes: 누적 확보 용량 (bytes)
//  - lastUpdated: 마지막 갱신 시각
//

import Foundation

// MARK: - DeletionStats

/// 누적 삭제 통계 (Documents/JSON 영구 저장)
public struct DeletionStats: Codable, Sendable {

    /// 누적 삭제 장수
    public var totalDeletedCount: Int

    /// 누적 확보 용량 (bytes)
    public var totalFreedBytes: Int64

    /// 마지막 갱신 시각
    public var lastUpdated: Date

    // MARK: - Initialization

    /// 초기값 (0, 0, now)
    public init(
        totalDeletedCount: Int = 0,
        totalFreedBytes: Int64 = 0,
        lastUpdated: Date = Date()
    ) {
        self.totalDeletedCount = totalDeletedCount
        self.totalFreedBytes = totalFreedBytes
        self.lastUpdated = lastUpdated
    }
}

// MARK: - CelebrationResult

/// 축하 화면 전달용 데이터 (인메모리)
/// 이번 세션 통계 + 누적 통계를 함께 전달
public struct CelebrationResult {

    /// 이번 삭제 장수
    public let sessionDeletedCount: Int

    /// 이번 확보 용량 (bytes)
    public let sessionFreedBytes: Int64

    /// 누적 삭제 장수 (DeletionStats에서)
    public let totalDeletedCount: Int

    /// 누적 확보 용량 (DeletionStats에서)
    public let totalFreedBytes: Int64

    // MARK: - Initialization

    public init(
        sessionDeletedCount: Int,
        sessionFreedBytes: Int64,
        totalDeletedCount: Int,
        totalFreedBytes: Int64
    ) {
        self.sessionDeletedCount = sessionDeletedCount
        self.sessionFreedBytes = sessionFreedBytes
        self.totalDeletedCount = totalDeletedCount
        self.totalFreedBytes = totalFreedBytes
    }
}

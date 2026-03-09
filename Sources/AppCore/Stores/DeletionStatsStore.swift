//
//  DeletionStatsStore.swift
//  AppCore
//
//  누적 삭제 통계 관리 (Documents/DeletionStats.json)
//
//  저장 패턴: TrashStore 동일 (JSONEncoder, iso8601, atomic write, serial queue)
//  파일 손상 시 0 초기화 (FR-040a)
//
//  DeletionStatsStoreProtocol 준수 (contracts/protocols.md)
//

import Foundation
import OSLog

// MARK: - DeletionStatsStore

/// 누적 삭제 통계 관리 싱글톤
/// Documents/DeletionStats.json에 영구 저장
public final class DeletionStatsStore {

    // MARK: - Singleton

    public static let shared = DeletionStatsStore()

    // MARK: - Properties

    /// 현재 통계 (인메모리 캐시)
    private(set) var stats: DeletionStats

    /// 직렬화 큐 (스레드 안전 저장)
    private let saveQueue = DispatchQueue(label: "com.pickphoto.deletionStats.save")

    /// 저장 파일 URL
    private let statsURL: URL

    // MARK: - Initialization

    private init() {
        // Documents/DeletionStats.json 경로
        let documentsDir = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first!
        self.statsURL = documentsDir.appendingPathComponent("DeletionStats.json")

        // 기존 데이터 로드 (없으면 초기값)
        self.stats = DeletionStatsStore.loadStats(from: statsURL)
    }

    // MARK: - Public Methods

    /// 삭제 통계 추가
    /// - Parameters:
    ///   - deletedCount: 이번에 삭제한 장수
    ///   - freedBytes: 이번에 확보한 용량 (bytes)
    /// - Returns: 갱신된 DeletionStats (축하 화면 데이터 생성용)
    @discardableResult
    public func addStats(deletedCount: Int, freedBytes: Int64) -> DeletionStats {
        stats.totalDeletedCount += deletedCount
        stats.totalFreedBytes += freedBytes
        stats.lastUpdated = Date()

        Logger.app.debug("DeletionStatsStore: +\(deletedCount)장, +\(freedBytes)bytes → 누적 \(self.stats.totalDeletedCount)장, \(self.stats.totalFreedBytes)bytes")

        saveStats()
        return stats
    }

    /// 현재 누적 통계 조회
    public var currentStats: DeletionStats {
        return stats
    }

    // MARK: - Private Methods

    /// 통계 저장 (파일)
    private func saveStats() {
        saveQueue.async { [weak self] in
            guard let self = self else { return }

            do {
                let encoder = JSONEncoder()
                encoder.dateEncodingStrategy = .iso8601
                let data = try encoder.encode(self.stats)
                try data.write(to: self.statsURL, options: .atomic)
            } catch {
                Logger.app.error("DeletionStatsStore: 저장 실패 — \(error.localizedDescription)")
            }
        }
    }

    /// 통계 로드 (파일에서)
    /// 파일 손상 시 0 초기화 (FR-040a)
    private static func loadStats(from url: URL) -> DeletionStats {
        guard FileManager.default.fileExists(atPath: url.path) else {
            Logger.app.debug("DeletionStatsStore: 파일 없음 → 초기값")
            return DeletionStats()
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let stats = try decoder.decode(DeletionStats.self, from: data)
            Logger.app.debug("DeletionStatsStore: 로드 성공 — 누적 \(stats.totalDeletedCount)장, \(stats.totalFreedBytes)bytes")
            return stats
        } catch {
            // FR-040a: 파일 손상 시 0 초기화
            Logger.app.error("DeletionStatsStore: 파일 손상 → 0 초기화 — \(error.localizedDescription)")
            return DeletionStats()
        }
    }
}

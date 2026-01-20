// MemoryThumbnailCache.swift
// 메모리 기반 썸네일 캐시 (NSCache)
//
// B+A 조합 v2:
// - 첫 화면 프리로드 결과를 메모리에 저장
// - cellForItemAt에서 동기 조회로 즉시 이미지 할당
// - 키는 assetID만 사용 (크기 무관 - 회전 시 캐시 히트 보장)

#if canImport(UIKit)
import UIKit
#endif

// MARK: - MemoryThumbnailCache

/// 메모리 기반 썸네일 캐시
/// - NSCache 사용으로 메모리 압박 시 자동 해제
/// - 동기 접근으로 cellForItemAt에서 즉시 반환
/// - 키는 assetID만 사용 (크기 무관)
public final class MemoryThumbnailCache {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = MemoryThumbnailCache()

    // MARK: - Statistics (구간별 집계)

    /// 통계 락
    private let statsLock = NSLock()

    /// 구간 시작 시간
    private var statsStartTime: CFTimeInterval = CACurrentMediaTime()

    /// 히트 카운터 (구간별)
    private var hitCount: Int = 0

    /// 미스 카운터 (구간별)
    private var missCount: Int = 0

    /// 통계 리셋 (구간 시작 시 호출)
    public func resetStats() {
        statsLock.withLock {
            statsStartTime = CACurrentMediaTime()
            hitCount = 0
            missCount = 0
        }
    }

    /// 통계 로그 출력
    public func logStats(label: String = "MemoryCache") {
        statsLock.lock()
        let hit = hitCount
        let miss = missCount
        statsLock.unlock()

        let total = hit + miss
        let hitRate = total > 0 ? Double(hit) / Double(total) * 100 : 0

        FileLogger.log("[\(label)] memHit: \(hit), memMiss: \(miss), hitRate: \(String(format: "%.1f", hitRate))%")
    }

    // MARK: - Private Properties

    /// NSCache (메모리 압박 시 자동 해제)
    private let cache = NSCache<NSString, UIImage>()

    // MARK: - Initialization

    private init() {
        // 캐시 설정
        // - countLimit: 최대 100개 (첫 화면 + 여유분)
        // - totalCostLimit: 50MB (썸네일 기준 충분)
        cache.countLimit = 100
        cache.totalCostLimit = 50 * 1024 * 1024

        #if DEBUG
        FileLogger.log("[MemoryCache] 초기화: countLimit=100, costLimit=50MB")
        #endif
    }

    // MARK: - Public API

    /// 동기 조회 (cellForItemAt용)
    /// - Parameter assetID: 에셋 ID (localIdentifier)
    /// - Returns: 캐시된 이미지 또는 nil
    public func get(assetID: String) -> UIImage? {
        let key = cacheKey(assetID: assetID)
        let image = cache.object(forKey: key)

        // 통계 업데이트
        statsLock.lock()
        if image != nil {
            hitCount += 1
        } else {
            missCount += 1
        }
        statsLock.unlock()

        return image
    }

    /// 저장 (프리로드 완료 시)
    /// - 기존 이미지보다 큰 경우에만 저장 (품질 유지)
    /// - Parameters:
    ///   - image: 저장할 이미지
    ///   - assetID: 에셋 ID
    public func set(image: UIImage, assetID: String) {
        let key = cacheKey(assetID: assetID)

        // 기존 이미지보다 큰 경우에만 저장 (품질 유지)
        if let existing = cache.object(forKey: key) {
            let existingPixels = existing.size.width * existing.size.height * existing.scale * existing.scale
            let newPixels = image.size.width * image.size.height * image.scale * image.scale
            guard newPixels >= existingPixels else { return }
        }

        // cost = 이미지 메모리 크기 추정 (width × height × 4 bytes)
        let cost = Int(image.size.width * image.size.height * image.scale * image.scale * 4)
        cache.setObject(image, forKey: key, cost: cost)
    }

    /// 특정 에셋 삭제
    /// - Parameter assetID: 에셋 ID
    public func remove(assetID: String) {
        let key = cacheKey(assetID: assetID)
        cache.removeObject(forKey: key)
    }

    /// 전체 캐시 삭제
    public func removeAll() {
        cache.removeAllObjects()

        #if DEBUG
        FileLogger.log("[MemoryCache] 전체 삭제")
        #endif
    }

    // MARK: - Private Methods

    /// 캐시 키 생성 (assetID만 사용)
    /// - 크기 무관으로 회전 시에도 캐시 히트 보장
    private func cacheKey(assetID: String) -> NSString {
        assetID as NSString
    }
}

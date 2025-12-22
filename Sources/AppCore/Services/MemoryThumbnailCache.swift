// MemoryThumbnailCache.swift
// 메모리 기반 썸네일 캐시
//
// B안 구현: 첫 화면 썸네일을 그리드 노출 전에 메모리에 준비
// - NSCache 기반으로 동기 접근 (메인 스레드에서 즉시 반환)
// - 셀 생성과 동시에 이미지 할당 가능
// - 메모리 압박 시 자동 해제 (NSCache 특성)

import UIKit

// MARK: - MemoryThumbnailCache

/// 메모리 기반 썸네일 캐시
/// - 동기 접근으로 셀 생성 시 즉시 이미지 반환
/// - NSCache 기반으로 메모리 압박 시 자동 해제
/// - 디스크 캐시(ThumbnailCache)의 앞단 레이어로 동작
public final class MemoryThumbnailCache {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = MemoryThumbnailCache()

    // MARK: - Constants

    /// 최대 캐시 개수 (첫 화면 + 여유분)
    /// 3열 기준 약 7행 = 21개, 여유분 포함 50개
    private let maxCount: Int = 50

    /// 최대 메모리 사용량 (20MB)
    /// 썸네일 1개 평균 ~100KB 기준
    private let maxTotalCostMB: Int = 20

    // MARK: - Properties

    /// NSCache 인스턴스 (thread-safe)
    private let cache: NSCache<NSString, UIImage>

    /// 화면 스케일 (캐시 키 생성용)
    private let scale: CGFloat

    // MARK: - Debug Counters

    #if DEBUG
    /// 메모리 캐시 히트 카운터
    public private(set) static var hitCount: Int = 0
    /// 메모리 캐시 미스 카운터
    public private(set) static var missCount: Int = 0
    /// 카운터 락
    private static let counterLock = NSLock()

    /// 히트율 계산 (0.0 ~ 1.0)
    public static var hitRate: Double {
        let total = hitCount + missCount
        guard total > 0 else { return 0 }
        return Double(hitCount) / Double(total)
    }

    /// 카운터 리셋 (테스트용)
    public static func resetCounters() {
        counterLock.withLock {
            hitCount = 0
            missCount = 0
        }
    }
    #endif

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        cache = NSCache<NSString, UIImage>()
        cache.countLimit = maxCount
        cache.totalCostLimit = maxTotalCostMB * 1024 * 1024

        // 스케일 저장 (메인 스레드에서만 접근 가능)
        scale = UIScreen.main.scale

        #if DEBUG
        FileLogger.log("[MemoryCache] Initialized: maxCount=\(maxCount), maxMB=\(maxTotalCostMB)")
        #endif
    }

    // MARK: - Public API

    /// 동기 로드 (메인 스레드에서 즉시 반환)
    /// - Parameters:
    ///   - assetID: 에셋 ID (localIdentifier)
    ///   - size: 목표 크기 (픽셀 단위)
    /// - Returns: 캐시된 이미지 (없으면 nil)
    public func get(assetID: String, size: CGSize) -> UIImage? {
        let key = cacheKey(assetID: assetID, size: size) as NSString
        let image = cache.object(forKey: key)

        #if DEBUG
        Self.counterLock.withLock {
            if image != nil {
                Self.hitCount += 1
            } else {
                Self.missCount += 1
            }
        }
        #endif

        return image
    }

    /// 이미지 저장
    /// - Parameters:
    ///   - image: 저장할 이미지
    ///   - assetID: 에셋 ID
    ///   - size: 이미지 크기 (픽셀 단위)
    public func set(image: UIImage, assetID: String, size: CGSize) {
        let key = cacheKey(assetID: assetID, size: size) as NSString

        // 이미지 메모리 크기 추정 (바이트)
        let cost = estimateCost(for: image)

        cache.setObject(image, forKey: key, cost: cost)
    }

    /// 특정 에셋 캐시 삭제
    /// - Parameters:
    ///   - assetID: 에셋 ID
    ///   - size: 이미지 크기
    public func remove(assetID: String, size: CGSize) {
        let key = cacheKey(assetID: assetID, size: size) as NSString
        cache.removeObject(forKey: key)
    }

    /// 전체 캐시 삭제
    public func removeAll() {
        cache.removeAllObjects()

        #if DEBUG
        FileLogger.log("[MemoryCache] Cleared all cache")
        #endif
    }

    /// 현재 캐시 상태 로그 (디버그용)
    #if DEBUG
    public func logStatus() {
        let total = Self.hitCount + Self.missCount
        FileLogger.log("[MemoryCache] Status: hit=\(Self.hitCount), miss=\(Self.missCount), rate=\(String(format: "%.1f", Self.hitRate * 100))%")
    }
    #endif

    // MARK: - Private Methods

    /// 캐시 키 생성
    /// - assetID + width + height + scale
    /// - modificationDate는 포함하지 않음 (메모리 캐시는 세션 내 유효)
    private func cacheKey(assetID: String, size: CGSize) -> String {
        return "\(assetID)_\(Int(size.width))_\(Int(size.height))_\(Int(scale))"
    }

    /// 이미지 메모리 크기 추정 (바이트)
    private func estimateCost(for image: UIImage) -> Int {
        guard let cgImage = image.cgImage else {
            // CGImage가 없으면 대략적인 추정
            return Int(image.size.width * image.size.height * 4)
        }

        // 실제 비트맵 크기: width × height × bytesPerPixel
        return cgImage.width * cgImage.height * (cgImage.bitsPerPixel / 8)
    }
}

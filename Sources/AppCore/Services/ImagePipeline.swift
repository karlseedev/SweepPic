// ImagePipeline.swift
// PHCachingImageManager 기반 이미지 파이프라인
//
// T012: ImagePipelineProtocol 및 ImagePipeline 생성
// - requestImage
// - cancelRequest
// - preheat
// - stopPreheating
//
// Gate 2 측정용 통계 수집 기능 추가

import UIKit
import Photos

// MARK: - PipelineStats (Gate 2 측정용)

/// 파이프라인 통계 (구간별 측정용)
public struct PipelineStats {
    /// 요청 수
    public var requestCount: Int = 0
    /// 취소 수
    public var cancelCount: Int = 0
    /// 완료 수
    public var completeCount: Int = 0
    /// degraded 이미지 수 (저해상도 먼저 전달된 횟수)
    public var degradedCount: Int = 0
    /// 최대 동시 요청 수
    public var maxInFlight: Int = 0
    /// 현재 진행 중 요청 수
    public var currentInFlight: Int = 0
    /// preheat 호출 횟수
    public var preheatCallCount: Int = 0
    /// preheat 총 에셋 수
    public var preheatAssetCount: Int = 0
    /// 요청-완료 latency 샘플 (ms)
    public var latencySamples: [Double] = []
    /// 측정 시작 시간
    public var startTime: CFAbsoluteTime = 0
    /// 측정 종료 시간
    public var endTime: CFAbsoluteTime = 0

    /// 측정 시간 (초)
    public var duration: Double {
        guard endTime > startTime else { return 0 }
        return endTime - startTime
    }

    /// 요청률 (req/s)
    public var requestRate: Double {
        guard duration > 0 else { return 0 }
        return Double(requestCount) / duration
    }

    /// 취소율 (cancel/s)
    public var cancelRate: Double {
        guard duration > 0 else { return 0 }
        return Double(cancelCount) / duration
    }

    /// 완료율 (complete/s)
    public var completeRate: Double {
        guard duration > 0 else { return 0 }
        return Double(completeCount) / duration
    }

    /// 평균 latency (ms)
    public var avgLatency: Double {
        guard !latencySamples.isEmpty else { return 0 }
        return latencySamples.reduce(0, +) / Double(latencySamples.count)
    }

    /// p95 latency (ms)
    public var p95Latency: Double {
        guard !latencySamples.isEmpty else { return 0 }
        let sorted = latencySamples.sorted()
        let index = Int(Double(sorted.count) * 0.95)
        return sorted[min(index, sorted.count - 1)]
    }

    /// 최대 latency (ms)
    public var maxLatency: Double {
        return latencySamples.max() ?? 0
    }

    /// 리셋
    public mutating func reset() {
        requestCount = 0
        cancelCount = 0
        completeCount = 0
        degradedCount = 0
        maxInFlight = 0
        currentInFlight = 0
        preheatCallCount = 0
        preheatAssetCount = 0
        latencySamples = []
        startTime = CFAbsoluteTimeGetCurrent()
        endTime = 0
    }

    /// 측정 종료
    public mutating func finish() {
        endTime = CFAbsoluteTimeGetCurrent()
    }

    /// 포맷된 요약 문자열 (3줄)
    public func formatted(label: String) -> [String] {
        return [
            "[Pipeline] \(label): req: \(requestCount) (\(String(format: "%.1f", requestRate))/s), cancel: \(cancelCount) (\(String(format: "%.1f", cancelRate))/s), complete: \(completeCount) (\(String(format: "%.1f", completeRate))/s)",
            "[Pipeline] \(label): latency avg: \(String(format: "%.1f", avgLatency))ms, p95: \(String(format: "%.1f", p95Latency))ms, max: \(String(format: "%.1f", maxLatency))ms",
            "[Pipeline] \(label): degraded: \(degradedCount), maxInFlight: \(maxInFlight), preheat: \(preheatCallCount)회/\(preheatAssetCount)개"
        ]
    }
}

// MARK: - RequestToken

/// 이미지 요청 토큰
/// 요청 취소 및 완료 콜백에서 올바른 이미지인지 확인하는 데 사용
public final class RequestToken: @unchecked Sendable {

    /// 요청 ID (PHImageRequestID)
    public let requestID: PHImageRequestID

    /// 요청한 에셋 ID
    public let assetID: String

    /// 취소 여부
    public private(set) var isCancelled: Bool = false

    /// 초기화
    /// - Parameters:
    ///   - requestID: PhotoKit 요청 ID
    ///   - assetID: 요청한 에셋 ID
    init(requestID: PHImageRequestID, assetID: String) {
        self.requestID = requestID
        self.assetID = assetID
    }

    /// 요청 취소 표시
    func markCancelled() {
        isCancelled = true
    }
}

// MARK: - ImagePipelineProtocol (T012)

/// 이미지 파이프라인 프로토콜
/// PHCachingImageManager를 추상화하여 테스트 가능하게 함
public protocol ImagePipelineProtocol: AnyObject {

    /// 이미지 요청
    /// - Parameters:
    ///   - assetID: 요청할 에셋 ID
    ///   - targetSize: 목표 크기
    ///   - contentMode: 컨텐츠 모드
    ///   - completion: 완료 콜백 (메인 스레드에서 호출)
    /// - Returns: 취소 가능한 토큰
    func requestImage(
        for assetID: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        completion: @escaping (UIImage?, RequestToken) -> Void
    ) -> RequestToken?

    /// 요청 취소
    /// - Parameter token: 취소할 요청 토큰
    func cancelRequest(_ token: RequestToken)

    /// 프리히트 시작 (prefetch)
    /// - Parameters:
    ///   - assetIDs: 프리히트할 에셋 ID 배열
    ///   - targetSize: 목표 크기
    func preheat(assetIDs: [String], targetSize: CGSize)

    /// 프리히트 중지
    /// - Parameter assetIDs: 중지할 에셋 ID 배열
    func stopPreheating(assetIDs: [String])

    /// 모든 프리히트 중지
    func stopAllPreheating()

    /// 캐시 비우기
    /// 메모리 경고 시 호출
    func clearCache()
}

// MARK: - ImagePipeline (T012)

/// PHCachingImageManager 기반 이미지 파이프라인 구현체
/// 썸네일 및 전체 해상도 이미지 로딩 담당
public final class ImagePipeline: ImagePipelineProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = ImagePipeline()

    // MARK: - Private Properties

    /// PHCachingImageManager 인스턴스
    private let imageManager: PHCachingImageManager

    /// 에셋 캐시 (localIdentifier → PHAsset)
    /// 반복적인 fetch 방지
    private var assetCache: [String: PHAsset] = [:]

    /// 캐시 접근 동기화를 위한 큐
    private let cacheQueue = DispatchQueue(label: "com.pickphoto.imagepipeline.cache")

    /// 통계 접근 동기화를 위한 큐
    private let statsQueue = DispatchQueue(label: "com.pickphoto.imagepipeline.stats")

    /// 현재 구간 통계
    private var currentStats = PipelineStats()

    /// 통계 수집 활성화 여부
    private var isStatsEnabled: Bool = false

    /// 요청 시작 시간 추적 (latency 계산용)
    private var requestStartTimes: [PHImageRequestID: CFAbsoluteTime] = [:]

    /// 썸네일 요청 옵션 (빠른 로딩 우선)
    private lazy var thumbnailOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic  // 저해상도 먼저, 고해상도 나중
        options.resizeMode = .fast             // 빠른 리사이즈
        options.isNetworkAccessAllowed = false // iCloud 다운로드 안 함 (MVP)
        options.isSynchronous = false
        return options
    }()

    /// 전체 해상도 요청 옵션
    private lazy var fullSizeOptions: PHImageRequestOptions = {
        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .exact
        options.isNetworkAccessAllowed = false // iCloud 다운로드 안 함 (MVP)
        options.isSynchronous = false
        return options
    }()

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        self.imageManager = PHCachingImageManager()
        // 메모리 사용량 최적화를 위해 allowsCachingHighQualityImages 비활성화
        self.imageManager.allowsCachingHighQualityImages = false
    }

    // MARK: - ImagePipelineProtocol

    /// 이미지 요청 (assetID 기반 - 캐시 미스 시 PHAsset fetch 필요)
    public func requestImage(
        for assetID: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        completion: @escaping (UIImage?, RequestToken) -> Void
    ) -> RequestToken? {
        // PHAsset 가져오기
        guard let asset = fetchAsset(for: assetID) else {
            print("[ImagePipeline] Asset not found: \(assetID.prefix(8))...")
            return nil
        }

        return requestImage(for: asset, targetSize: targetSize, contentMode: contentMode, completion: completion)
    }

    /// 이미지 요청 (PHAsset 직접 전달 - 성능 최적화)
    /// PHAsset을 이미 가지고 있는 경우 이 메서드 사용 권장
    public func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        completion: @escaping (UIImage?, RequestToken) -> Void
    ) -> RequestToken {
        let assetID = asset.localIdentifier
        let requestStartTime = CFAbsoluteTimeGetCurrent()

        // 통계: 요청 카운트 증가
        if isStatsEnabled {
            statsQueue.async { [weak self] in
                guard let self = self else { return }
                self.currentStats.requestCount += 1
                self.currentStats.currentInFlight += 1
                self.currentStats.maxInFlight = max(self.currentStats.maxInFlight, self.currentStats.currentInFlight)
            }
        }

        // 이미지 요청
        var isFirstCallback = true
        let requestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: thumbnailOptions
        ) { [weak self] image, info in
            guard let self = self else { return }

            // 통계: 완료/degraded 카운트
            if self.isStatsEnabled {
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                let latency = (CFAbsoluteTimeGetCurrent() - requestStartTime) * 1000 // ms

                self.statsQueue.async {
                    if isDegraded {
                        self.currentStats.degradedCount += 1
                    } else {
                        // 최종 이미지만 완료로 카운트
                        self.currentStats.completeCount += 1
                        self.currentStats.currentInFlight = max(0, self.currentStats.currentInFlight - 1)
                        self.currentStats.latencySamples.append(latency)
                    }
                }
            }

            // 메인 스레드에서 콜백
            let token = RequestToken(requestID: PHImageRequestID(0), assetID: assetID)

            DispatchQueue.main.async {
                completion(image, token)
            }

            isFirstCallback = false
        }

        let token = RequestToken(requestID: requestID, assetID: assetID)

        // 캐시에 저장 (다음 요청 시 재사용)
        cacheQueue.async { [weak self] in
            self?.assetCache[assetID] = asset
        }

        return token
    }

    /// 요청 취소
    public func cancelRequest(_ token: RequestToken) {
        token.markCancelled()
        imageManager.cancelImageRequest(token.requestID)

        // 통계: 취소 카운트 증가
        if isStatsEnabled {
            statsQueue.async { [weak self] in
                guard let self = self else { return }
                self.currentStats.cancelCount += 1
                self.currentStats.currentInFlight = max(0, self.currentStats.currentInFlight - 1)
            }
        }
    }

    /// 프리히트 시작
    public func preheat(assetIDs: [String], targetSize: CGSize) {
        let assets = assetIDs.compactMap { fetchAsset(for: $0) }
        guard !assets.isEmpty else { return }

        // 통계: preheat 카운트 증가
        if isStatsEnabled {
            statsQueue.async { [weak self] in
                guard let self = self else { return }
                self.currentStats.preheatCallCount += 1
                self.currentStats.preheatAssetCount += assets.count
            }
        }

        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: thumbnailOptions
        )
    }

    /// 프리히트 중지
    public func stopPreheating(assetIDs: [String]) {
        let assets = assetIDs.compactMap { fetchAsset(for: $0) }
        guard !assets.isEmpty else { return }

        imageManager.stopCachingImages(
            for: assets,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFill,
            options: thumbnailOptions
        )
    }

    /// 모든 프리히트 중지
    public func stopAllPreheating() {
        imageManager.stopCachingImagesForAllAssets()
    }

    /// 캐시 비우기
    public func clearCache() {
        // PHCachingImageManager 캐시 비우기
        imageManager.stopCachingImagesForAllAssets()

        // 내부 에셋 캐시 비우기
        cacheQueue.async { [weak self] in
            self?.assetCache.removeAll()
        }

        print("[ImagePipeline] Cache cleared")
    }

    // MARK: - Private Methods

    /// 에셋 ID로 PHAsset 가져오기
    /// - Parameter assetID: 에셋 ID (localIdentifier)
    /// - Returns: PHAsset 또는 nil
    private func fetchAsset(for assetID: String) -> PHAsset? {
        // 캐시 확인
        var cachedAsset: PHAsset?
        cacheQueue.sync {
            cachedAsset = assetCache[assetID]
        }

        if let cached = cachedAsset {
            return cached
        }

        // PhotoKit에서 fetch
        let result = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        )

        guard let asset = result.firstObject else {
            return nil
        }

        // 캐시에 저장
        cacheQueue.async { [weak self] in
            self?.assetCache[assetID] = asset
        }

        return asset
    }

    // MARK: - Statistics (Gate 2 측정용)

    /// 통계 수집 시작
    public func startStats() {
        statsQueue.async { [weak self] in
            guard let self = self else { return }
            self.currentStats.reset()
            self.isStatsEnabled = true
        }
    }

    /// 통계 수집 종료 및 결과 반환
    public func stopStats() -> PipelineStats {
        var result = PipelineStats()
        statsQueue.sync { [weak self] in
            guard let self = self else { return }
            self.currentStats.finish()
            result = self.currentStats
            self.isStatsEnabled = false
        }
        return result
    }

    /// 현재 통계 조회 (수집 중)
    public func getCurrentStats() -> PipelineStats {
        var result = PipelineStats()
        statsQueue.sync { [weak self] in
            guard let self = self else { return }
            result = self.currentStats
        }
        return result
    }

    // MARK: - Debug Logging

    /// 파이프라인 설정 로그 출력
    public func logConfig() {
        FileLogger.log("[Config] deliveryMode: opportunistic")
        FileLogger.log("[Config] cancelPolicy: prepareForReuse")
        FileLogger.log("[Config] R2Recovery: disabled")
        FileLogger.log("[Config] preheatPolicy: on (prefetchDataSource)")
        FileLogger.log("[Config] preheatWindow: prefetch 호출 시점 (시스템 결정)")
        FileLogger.log("[Config] preheatThrottle: 100ms")
        FileLogger.log("[Config] scrollQuality: 0.5 (스크롤 중 50% 크기)")
    }
}

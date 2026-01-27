// ImagePipeline.swift
// PHCachingImageManager 기반 이미지 파이프라인
//
// v6 최적화:
// - PhotoKit 호출을 백그라운드 OperationQueue에서 실행
// - 레이스 안전한 Cancellable 토큰
// - 메인 스레드 PhotoKit 호출 감지 (가드레일)

#if canImport(UIKit)
import UIKit
#endif
import Photos

// MARK: - Cancellable Protocol

/// 취소 가능한 작업 프로토콜
public protocol Cancellable: AnyObject {
    /// 취소 여부
    var isCancelled: Bool { get }
    /// 작업 취소
    func cancel()
}

// MARK: - CancellableToken

/// 레이스 안전한 취소 토큰
/// - cancel()과 setOnCancel() 사이의 레이스 컨디션 방지
/// - cancel이 먼저 호출되면 setOnCancel 시 즉시 핸들러 실행
public final class CancellableToken: Cancellable {

    /// 동기화를 위한 락
    private let lock = NSLock()

    /// 취소 상태
    private var _isCancelled = false

    /// 취소 시 실행할 핸들러
    private var _onCancel: (() -> Void)?

    /// 취소 여부 (스레드 안전)
    public var isCancelled: Bool {
        lock.withLock { _isCancelled }
    }

    /// 작업 취소
    /// - 이미 취소된 경우 무시
    /// - 취소 핸들러가 설정되어 있으면 실행
    public func cancel() {
        let handler: (() -> Void)?
        lock.lock()
        guard !_isCancelled else {
            lock.unlock()
            return
        }
        _isCancelled = true
        handler = _onCancel
        _onCancel = nil
        lock.unlock()
        handler?()
    }

    /// 취소 핸들러 설정 (레이스 안전)
    /// - 이미 cancel()이 호출된 경우 즉시 핸들러 실행
    /// - Parameter handler: 취소 시 실행할 클로저
    func setOnCancel(_ handler: @escaping () -> Void) {
        lock.lock()
        if _isCancelled {
            lock.unlock()
            handler()
        } else {
            _onCancel = handler
            lock.unlock()
        }
    }
}

// MARK: - Legacy RequestToken (하위 호환)

/// 기존 RequestToken (하위 호환용, 점진적 마이그레이션)
/// 새 코드는 Cancellable/CancellableToken 사용 권장
public final class RequestToken: @unchecked Sendable {

    /// 요청 ID (PHImageRequestID)
    public let requestID: PHImageRequestID

    /// 요청한 에셋 ID
    public let assetID: String

    /// 취소 여부
    public private(set) var isCancelled: Bool = false

    init(requestID: PHImageRequestID, assetID: String) {
        self.requestID = requestID
        self.assetID = assetID
    }

    func markCancelled() {
        isCancelled = true
    }
}

// MARK: - ImageQuality

/// 이미지 품질 옵션
/// - fast: 빠른 로딩 우선 (그리드 썸네일용)
/// - high: 고품질 우선 (뷰어용)
public enum ImageQuality {
    case fast   // .opportunistic + .fast (기본값)
    case high   // .highQualityFormat + .exact
}

// MARK: - ImagePipelineProtocol

/// 이미지 파이프라인 프로토콜
/// PHCachingImageManager를 추상화하여 테스트 가능하게 함
public protocol ImagePipelineProtocol: AnyObject {

    /// 이미지 요청 (새 API - Cancellable 반환)
    /// - Parameters:
    ///   - asset: 요청할 PHAsset
    ///   - targetSize: 목표 크기 (픽셀 단위)
    ///   - contentMode: 컨텐츠 모드
    ///   - quality: 이미지 품질 (기본값: .fast)
    ///   - completion: 완료 콜백 (메인 스레드에서 호출, isDegraded: 저해상도 여부)
    /// - Returns: 취소 가능한 토큰
    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
        quality: ImageQuality,
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> Cancellable

    /// 요청 취소
    /// - Parameter cancellable: 취소할 토큰
    func cancelRequest(_ cancellable: Cancellable)

    /// 프리히트 시작 (PHAsset 배열 기반)
    /// - Parameters:
    ///   - assets: 프리히트할 PHAsset 배열
    ///   - targetSize: 목표 크기 (픽셀 단위)
    func preheatAssets(_ assets: [PHAsset], targetSize: CGSize)

    /// 프리히트 중지
    /// - Parameter assets: 중지할 PHAsset 배열
    func stopPreheatingAssets(_ assets: [PHAsset])

    /// 모든 프리히트 중지
    func stopAllPreheating()

    /// 캐시 비우기
    func clearCache()

    // MARK: - Legacy API (하위 호환)

    /// 프리히트 시작 (assetID 배열 기반 - 레거시)
    func preheat(assetIDs: [String], targetSize: CGSize)

    /// 프리히트 중지 (assetID 배열 기반 - 레거시)
    func stopPreheating(assetIDs: [String])
}

// MARK: - ImagePipeline

/// PHCachingImageManager 기반 이미지 파이프라인 구현체
/// - PhotoKit 호출은 백그라운드 OperationQueue에서 실행
/// - completion은 메인 스레드에서 호출
public final class ImagePipeline: ImagePipelineProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = ImagePipeline()

    // MARK: - Debug Counters (가드레일)

    #if DEBUG
    /// 메인 스레드에서 PhotoKit 호출 횟수 (0이어야 함)
    private static var mainThreadPhotoKitCallCount = 0
    /// 백그라운드 스레드에서 PhotoKit 호출 횟수
    private static var bgThreadPhotoKitCallCount = 0
    #endif

    // MARK: - Pipeline Statistics (파이프라인 지표)

    /// 통계 시작 시간
    private var statsStartTime: CFTimeInterval = CACurrentMediaTime()

    /// 통계 락
    private let statsLock = NSLock()

    /// requestImage 호출 횟수
    private var requestCount: Int = 0

    /// cancel 호출 횟수
    private var cancelCount: Int = 0

    /// completion 호출 횟수 (isDegraded=false만)
    private var completeCount: Int = 0

    /// isDegraded=true completion 횟수
    private var degradedCount: Int = 0

    /// 현재 진행 중인 요청 수 (maxInFlight 추적)
    private var inFlightCount: Int = 0

    /// 최대 동시 요청 수 (세션 중 최대값)
    private var maxInFlightCount: Int = 0

    /// completion latency 배열 (avg/p95/max 계산용)
    private var latencies: [Double] = []

    /// 요청 시작 시간 저장 (assetID → startTime)
    private var requestStartTimes: [String: CFTimeInterval] = [:]

    /// preheat 호출 횟수
    private var preheatCount: Int = 0

    /// preheat 총 에셋 수
    private var preheatAssetCount: Int = 0

    /// 통계 리셋 (앱 시작 시 호출)
    public func resetStats() {
        statsLock.withLock {
            statsStartTime = CACurrentMediaTime()
            requestCount = 0
            cancelCount = 0
            completeCount = 0
            degradedCount = 0
            inFlightCount = 0
            maxInFlightCount = 0
            latencies.removeAll()
            requestStartTimes.removeAll()
            preheatCount = 0
            preheatAssetCount = 0
        }
    }

    /// 파이프라인 설정값 로그 출력 (전/후 비교용)
    /// 앱 시작 시 1회 호출하여 설정값 기록
    public func logConfig() {
        // 현재 deliveryMode 확인
        let deliveryModeStr: String
        switch thumbnailOptions.deliveryMode {
        case .opportunistic:
            deliveryModeStr = "opportunistic"
        case .highQualityFormat:
            deliveryModeStr = "highQualityFormat"
        case .fastFormat:
            deliveryModeStr = "fastFormat"
        @unknown default:
            deliveryModeStr = "unknown"
        }

        // cancelPolicy: 현재 prepareForReuse만 사용 (didEndDisplaying 미사용)
        // R2Recovery: 현재 미구현
        let cancelPolicy = "prepareForReuse"  // TODO: Gate2 적용 시 didEndDisplaying 추가
        let r2Recovery = "disabled"           // TODO: Gate2 적용 시 enabled로 변경

        FileLogger.log("[Config] deliveryMode: \(deliveryModeStr)")
        FileLogger.log("[Config] cancelPolicy: \(cancelPolicy)")
        FileLogger.log("[Config] R2Recovery: \(r2Recovery)")
    }

    /// 통계 로그 출력
    public func logStats(label: String = "Pipeline Stats") {
        statsLock.lock()
        let elapsed = (CACurrentMediaTime() - statsStartTime)
        let reqCount = requestCount
        let canCount = cancelCount
        let compCount = completeCount
        let degCount = degradedCount
        let maxInFlight = maxInFlightCount
        let latencyCopy = latencies
        let phCount = preheatCount
        let phAssetCount = preheatAssetCount
        statsLock.unlock()

        // latency 계산
        let avgLatency = latencyCopy.isEmpty ? 0 : latencyCopy.reduce(0, +) / Double(latencyCopy.count)
        let sortedLatencies = latencyCopy.sorted()
        let p95Index = sortedLatencies.isEmpty ? 0 : Int(Double(sortedLatencies.count) * 0.95)
        let p95Latency = sortedLatencies.isEmpty ? 0 : sortedLatencies[min(p95Index, sortedLatencies.count - 1)]
        let maxLatency = sortedLatencies.last ?? 0

        // 초당 비율
        let reqPerSec = elapsed > 0 ? Double(reqCount) / elapsed : 0
        let canPerSec = elapsed > 0 ? Double(canCount) / elapsed : 0
        let compPerSec = elapsed > 0 ? Double(compCount) / elapsed : 0

        FileLogger.log("[\(label)] req: \(reqCount) (\(String(format: "%.1f", reqPerSec))/s), cancel: \(canCount) (\(String(format: "%.1f", canPerSec))/s), complete: \(compCount) (\(String(format: "%.1f", compPerSec))/s)")
        FileLogger.log("[\(label)] degraded: \(degCount), maxInFlight: \(maxInFlight)")
        FileLogger.log("[\(label)] latency avg: \(String(format: "%.1f", avgLatency))ms, p95: \(String(format: "%.1f", p95Latency))ms, max: \(String(format: "%.1f", maxLatency))ms")
        FileLogger.log("[\(label)] preheat: \(phCount)회, 총 \(phAssetCount)개 에셋")
    }

    // MARK: - Private Properties

    /// PHCachingImageManager 인스턴스
    private let imageManager: PHCachingImageManager

    /// 에셋 캐시 (localIdentifier → PHAsset)
    private var assetCache: [String: PHAsset] = [:]

    /// 캐시 접근 동기화를 위한 큐
    private let cacheQueue = DispatchQueue(label: "com.pickphoto.imagepipeline.cache")

    /// PhotoKit 요청용 OperationQueue (백그라운드)
    /// - 동시 요청 수 제한으로 초기 로딩 시 메인 스레드 부하 방지
    private let requestQueue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.pickphoto.imagepipeline.request"
        queue.maxConcurrentOperationCount = 2  // 보수적으로 시작
        queue.qualityOfService = .userInitiated
        return queue
    }()

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
        options.isNetworkAccessAllowed = false
        options.isSynchronous = false
        return options
    }()

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        self.imageManager = PHCachingImageManager()
        self.imageManager.allowsCachingHighQualityImages = false
    }

    // MARK: - ImagePipelineProtocol (새 API)

    /// 이미지 요청 (백그라운드에서 PhotoKit 호출)
    /// - PhotoKit 호출은 OperationQueue 내부(백그라운드)에서 실행
    /// - completion은 메인 스레드에서 호출
    public func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        quality: ImageQuality = .fast,
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> Cancellable {

        let cancellable = CancellableToken()
        let assetID = asset.localIdentifier
        let requestStartTime = CACurrentMediaTime()

        // 품질에 따른 옵션 선택
        let options = (quality == .high) ? fullSizeOptions : thumbnailOptions

        // [Stats] 요청 카운터 증가
        statsLock.lock()
        requestCount += 1
        inFlightCount += 1
        if inFlightCount > maxInFlightCount {
            maxInFlightCount = inFlightCount
        }
        requestStartTimes[assetID] = requestStartTime
        let currentReqCount = requestCount
        statsLock.unlock()

        // [Stats] 10/20/30회마다 로그
        if currentReqCount == 10 || currentReqCount == 20 || currentReqCount == 30 {
            let elapsed = (CACurrentMediaTime() - statsStartTime) * 1000
            FileLogger.log("[Pipeline] requestImage #\(currentReqCount): +\(String(format: "%.1f", elapsed))ms")
        }

        // 백그라운드 OperationQueue에서 PhotoKit 호출
        requestQueue.addOperation { [weak self] in

            guard let self = self, !cancellable.isCancelled else {
                // [Stats] 취소된 경우 inFlight 감소
                self?.statsLock.lock()
                self?.inFlightCount -= 1
                self?.statsLock.unlock()
                return
            }

            // [가드레일] 메인 스레드에서 PhotoKit 호출 감지
            #if DEBUG
            if Thread.isMainThread {
                Self.mainThreadPhotoKitCallCount += 1
                assertionFailure("[ImagePipeline] PhotoKit call on main thread! Count: \(Self.mainThreadPhotoKitCallCount)")
            } else {
                Self.bgThreadPhotoKitCallCount += 1
            }
            #endif

            // PHCachingImageManager.requestImage 호출 (백그라운드)
            let requestID = self.imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: contentMode,
                options: options
            ) { [weak self] image, info in
                guard let self = self else { return }

                // 취소된 경우 무시
                guard !cancellable.isCancelled else { return }

                // isDegraded 확인 (저해상도 이미지 여부)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

                // [Stats] completion 통계
                self.statsLock.lock()
                if isDegraded {
                    self.degradedCount += 1
                } else {
                    self.completeCount += 1
                    self.inFlightCount -= 1

                    // latency 계산 (isDegraded=false일 때만)
                    if let startTime = self.requestStartTimes[assetID] {
                        let latency = (CACurrentMediaTime() - startTime) * 1000
                        self.latencies.append(latency)
                        self.requestStartTimes.removeValue(forKey: assetID)
                    }
                }
                let currentCompleteCount = self.completeCount + self.degradedCount
                statsLock.unlock()

                // [Stats] 50회 도달 시점 로그
                if currentCompleteCount == 50 {
                    let elapsed = (CACurrentMediaTime() - self.statsStartTime) * 1000
                    FileLogger.log("[Pipeline] completion #50 도달: +\(String(format: "%.1f", elapsed))ms")
                }

                // [--log-thumb] 파이프라인 응답 상세 로그 (샘플링: 20개마다)
                if FileLogger.logThumbEnabled && (currentCompleteCount <= 3 || currentCompleteCount % 20 == 0) {
                    if let img = image {
                        let imgPx = Int(img.size.width * img.scale)
                        let imgPy = Int(img.size.height * img.scale)
                        let ratio = targetSize.width > 0 ? Double(imgPx) / Double(targetSize.width) * 100 : 0
                        FileLogger.log("[Pipeline] #\(currentCompleteCount) target=\(Int(targetSize.width))x\(Int(targetSize.height))px → img=\(imgPx)x\(imgPy)px (\(String(format: "%.0f", ratio))%), degraded=\(isDegraded)")
                    }
                }

                // 메인 스레드에서 completion 호출
                DispatchQueue.main.async {
                    guard !cancellable.isCancelled else { return }
                    completion(image, isDegraded)
                }
            }

            // 레이스 안전한 취소 핸들러 설정
            // - cancel()이 먼저 호출됐으면 즉시 취소 실행
            cancellable.setOnCancel { [weak self] in
                self?.imageManager.cancelImageRequest(requestID)

                // [Stats] 취소 카운터
                self?.statsLock.lock()
                self?.cancelCount += 1
                self?.inFlightCount -= 1
                self?.statsLock.unlock()
            }
        }

        return cancellable
    }

    /// 요청 취소
    public func cancelRequest(_ cancellable: Cancellable) {
        cancellable.cancel()
    }

    /// 프리히트 시작 (PHAsset 배열 기반)
    /// - 백그라운드에서 실행
    public func preheatAssets(_ assets: [PHAsset], targetSize: CGSize) {
        guard !assets.isEmpty else { return }

        // [Stats] preheat 통계
        statsLock.lock()
        preheatCount += 1
        preheatAssetCount += assets.count
        statsLock.unlock()

        // [가드레일] 메인 스레드에서 호출 시 경고
        #if DEBUG
        if Thread.isMainThread {
            Log.print("[ImagePipeline] Warning: preheatAssets called on main thread")
        }
        #endif

        imageManager.startCachingImages(
            for: assets,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: thumbnailOptions
        )
    }

    /// 프리히트 중지
    public func stopPreheatingAssets(_ assets: [PHAsset]) {
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
        imageManager.stopCachingImagesForAllAssets()

        cacheQueue.async { [weak self] in
            self?.assetCache.removeAll()
        }

        #if DEBUG
        Log.print("[ImagePipeline] Cache cleared")
        #endif
    }

    // MARK: - Legacy API (하위 호환)

    /// 이미지 요청 (기존 API - assetID 기반)
    /// 새 코드는 PHAsset 기반 API 사용 권장
    public func requestImage(
        for assetID: String,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        completion: @escaping (UIImage?, RequestToken) -> Void
    ) -> RequestToken? {
        guard let asset = fetchAsset(for: assetID) else {
            #if DEBUG
            Log.print("[ImagePipeline] Asset not found: \(assetID.prefix(8))...")
            #endif
            return nil
        }

        return requestImageLegacy(for: asset, targetSize: targetSize, contentMode: contentMode, completion: completion)
    }

    /// 이미지 요청 (기존 API - PHAsset 기반, RequestToken 반환)
    public func requestImageLegacy(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode = .aspectFill,
        completion: @escaping (UIImage?, RequestToken) -> Void
    ) -> RequestToken {
        let assetID = asset.localIdentifier

        // 새 API로 위임
        let cancellable = requestImage(for: asset, targetSize: targetSize, contentMode: contentMode) { image, _ in
            let token = RequestToken(requestID: PHImageRequestID(0), assetID: assetID)
            completion(image, token)
        }

        // RequestToken 생성 (cancellable 래핑)
        let token = RequestToken(requestID: PHImageRequestID(0), assetID: assetID)

        // 캐시에 저장
        cacheQueue.async { [weak self] in
            self?.assetCache[assetID] = asset
        }

        return token
    }

    /// 요청 취소 (기존 API)
    public func cancelRequest(_ token: RequestToken) {
        token.markCancelled()
        // Note: 새 API에서는 CancellableToken이 취소 처리
    }

    /// 프리히트 시작 (기존 API - assetID 배열)
    public func preheat(assetIDs: [String], targetSize: CGSize) {
        let assets = assetIDs.compactMap { fetchAsset(for: $0) }
        preheatAssets(assets, targetSize: targetSize)
    }

    /// 프리히트 중지 (기존 API)
    public func stopPreheating(assetIDs: [String]) {
        let assets = assetIDs.compactMap { fetchAsset(for: $0) }
        stopPreheatingAssets(assets)
    }

    // MARK: - Private Methods

    /// 에셋 ID로 PHAsset 가져오기
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
}

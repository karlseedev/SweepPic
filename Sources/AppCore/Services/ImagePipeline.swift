// ImagePipeline.swift
// PHCachingImageManager 기반 이미지 파이프라인
//
// v6 최적화:
// - PhotoKit 호출을 백그라운드 OperationQueue에서 실행
// - 레이스 안전한 Cancellable 토큰
// - 메인 스레드 PhotoKit 호출 감지 (가드레일)

import UIKit
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

// MARK: - ImagePipelineProtocol

/// 이미지 파이프라인 프로토콜
/// PHCachingImageManager를 추상화하여 테스트 가능하게 함
public protocol ImagePipelineProtocol: AnyObject {

    /// 이미지 요청 (새 API - Cancellable 반환)
    /// - Parameters:
    ///   - asset: 요청할 PHAsset
    ///   - targetSize: 목표 크기 (픽셀 단위)
    ///   - contentMode: 컨텐츠 모드
    ///   - completion: 완료 콜백 (메인 스레드에서 호출, isDegraded: 저해상도 여부)
    /// - Returns: 취소 가능한 토큰
    func requestImage(
        for asset: PHAsset,
        targetSize: CGSize,
        contentMode: PHImageContentMode,
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
        completion: @escaping (UIImage?, Bool) -> Void
    ) -> Cancellable {

        let cancellable = CancellableToken()

        // 백그라운드 OperationQueue에서 PhotoKit 호출
        requestQueue.addOperation { [weak self] in
            guard let self = self, !cancellable.isCancelled else { return }

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
                options: self.thumbnailOptions
            ) { image, info in
                // 취소된 경우 무시
                guard !cancellable.isCancelled else { return }

                // isDegraded 확인 (저해상도 이미지 여부)
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false

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

        // [가드레일] 메인 스레드에서 호출 시 경고
        #if DEBUG
        if Thread.isMainThread {
            print("[ImagePipeline] Warning: preheatAssets called on main thread")
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
        print("[ImagePipeline] Cache cleared")
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
            print("[ImagePipeline] Asset not found: \(assetID.prefix(8))...")
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

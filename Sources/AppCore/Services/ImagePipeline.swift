// ImagePipeline.swift
// PHCachingImageManager 기반 이미지 파이프라인
//
// T012: ImagePipelineProtocol 및 ImagePipeline 생성
// - requestImage
// - cancelRequest
// - preheat
// - stopPreheating

import UIKit
import Photos

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

        // 썸네일 옵션 사용 (빠른 로딩)
        // 이미지 요청
        let requestID = imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: contentMode,
            options: thumbnailOptions
        ) { image, _ in
            // 메인 스레드에서 콜백
            let token = RequestToken(requestID: PHImageRequestID(0), assetID: assetID)

            // MVP에서는 저해상도도 전달하여 빠른 표시 지원
            DispatchQueue.main.async {
                completion(image, token)
            }
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
    }

    /// 프리히트 시작
    public func preheat(assetIDs: [String], targetSize: CGSize) {
        let assets = assetIDs.compactMap { fetchAsset(for: $0) }
        guard !assets.isEmpty else { return }

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

    // MARK: - Debug Logging

    /// 파이프라인 설정 로그 출력
    public func logConfig() {
        #if DEBUG
        FileLogger.log("[Config] deliveryMode: opportunistic")
        FileLogger.log("[Config] cancelPolicy: prepareForReuse")
        FileLogger.log("[Config] R2Recovery: disabled")
        #endif
    }
}

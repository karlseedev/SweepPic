// VideoPipeline.swift
// PHImageManager 기반 비디오 파이프라인
//
// 동영상 재생을 위한 AVPlayerItem 요청 처리
// - iCloud 동영상 다운로드 지원
// - ImagePipeline의 Cancellable 패턴 재사용

#if canImport(UIKit)
import UIKit
#endif
import Photos
import AVFoundation

// MARK: - VideoPipeline

/// PHImageManager 기반 비디오 파이프라인
/// - AVPlayerItem 요청 처리
/// - iCloud 비디오 자동 다운로드 (isNetworkAccessAllowed = true)
/// - info 딕셔너리로 상태 확인 (취소/에러/다운로드)
public final class VideoPipeline {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = VideoPipeline()

    // MARK: - Private Properties

    /// PHImageManager 인스턴스
    private let imageManager: PHCachingImageManager

    /// 기본 비디오 요청 옵션
    /// - deliveryMode: .highQualityFormat (가능한 최고 품질)
    /// - isNetworkAccessAllowed: true (iCloud 다운로드 허용)
    /// - version: .current (편집된 버전 우선)
    private lazy var defaultOptions: PHVideoRequestOptions = {
        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true  // iCloud 다운로드 허용
        options.version = .current             // 편집된 버전 사용
        return options
    }()

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private init() {
        self.imageManager = PHCachingImageManager()
    }

    // MARK: - Public Methods

    /// AVPlayerItem 요청
    /// - Parameters:
    ///   - asset: PHAsset (mediaType == .video)
    ///   - options: 요청 옵션 (nil이면 기본값 사용)
    ///   - progressHandler: 다운로드 진행률 핸들러 (iCloud 다운로드 시)
    ///   - completion: 결과 콜백 (메인 스레드에서 호출)
    ///     - playerItem: 성공 시 AVPlayerItem
    ///     - info: PHImageManager info 딕셔너리
    ///       - PHImageCancelledKey: 요청 취소 여부
    ///       - PHImageErrorKey: 에러 객체
    ///       - PHImageResultIsInCloudKey: iCloud 다운로드 필요 여부
    /// - Returns: 취소 가능한 토큰
    @discardableResult
    public func requestPlayerItem(
        for asset: PHAsset,
        options: PHVideoRequestOptions? = nil,
        progressHandler: ((Double) -> Void)? = nil,
        completion: @escaping (AVPlayerItem?, [AnyHashable: Any]?) -> Void
    ) -> Cancellable {

        let cancellable = CancellableToken()
        let requestOptions = options ?? defaultOptions

        // 진행률 핸들러 설정 (iCloud 다운로드 시)
        if let progressHandler = progressHandler {
            requestOptions.progressHandler = { progress, error, stop, info in
                DispatchQueue.main.async {
                    progressHandler(progress)
                }
            }
        }

        #if DEBUG
        print("[VideoPipeline] Requesting playerItem for asset: \(asset.localIdentifier.prefix(8))...")
        #endif

        // PHImageManager.requestPlayerItem 호출
        let requestID = imageManager.requestPlayerItem(
            forVideo: asset,
            options: requestOptions
        ) { [weak self] playerItem, info in
            guard self != nil else { return }

            // 취소된 경우 무시
            guard !cancellable.isCancelled else {
                #if DEBUG
                print("[VideoPipeline] Request cancelled")
                #endif
                return
            }

            // info 딕셔너리에서 상태 확인
            #if DEBUG
            if let error = info?[PHImageErrorKey] as? Error {
                print("[VideoPipeline] Error: \(error.localizedDescription)")
            }
            if let isInCloud = info?[PHImageResultIsInCloudKey] as? Bool, isInCloud {
                print("[VideoPipeline] Asset is in iCloud, downloading...")
            }
            if let isCancelled = info?[PHImageCancelledKey] as? Bool, isCancelled {
                print("[VideoPipeline] Request was cancelled by system")
            }
            #endif

            // 메인 스레드에서 completion 호출
            DispatchQueue.main.async {
                guard !cancellable.isCancelled else { return }
                completion(playerItem, info)
            }
        }

        // 레이스 안전한 취소 핸들러 설정
        cancellable.setOnCancel { [weak self] in
            self?.imageManager.cancelImageRequest(requestID)

            #if DEBUG
            print("[VideoPipeline] Cancelled request: \(requestID)")
            #endif
        }

        return cancellable
    }

    /// AVAsset 요청 (고급 사용 - 슬로모션, 커스텀 컴포지션 등)
    /// - Parameters:
    ///   - asset: PHAsset (mediaType == .video)
    ///   - options: 요청 옵션 (nil이면 기본값 사용)
    ///   - completion: 결과 콜백 (메인 스레드에서 호출)
    ///     - avAsset: 성공 시 AVAsset
    ///     - audioMix: 오디오 믹스 (슬로모션 등)
    ///     - info: PHImageManager info 딕셔너리
    /// - Returns: 취소 가능한 토큰
    @discardableResult
    public func requestAVAsset(
        for asset: PHAsset,
        options: PHVideoRequestOptions? = nil,
        completion: @escaping (AVAsset?, AVAudioMix?, [AnyHashable: Any]?) -> Void
    ) -> Cancellable {

        let cancellable = CancellableToken()
        let requestOptions = options ?? defaultOptions

        let requestID = imageManager.requestAVAsset(
            forVideo: asset,
            options: requestOptions
        ) { avAsset, audioMix, info in

            guard !cancellable.isCancelled else { return }

            DispatchQueue.main.async {
                guard !cancellable.isCancelled else { return }
                completion(avAsset, audioMix, info)
            }
        }

        cancellable.setOnCancel { [weak self] in
            self?.imageManager.cancelImageRequest(requestID)
        }

        return cancellable
    }
}

// MARK: - VideoPipeline Error Helpers

extension VideoPipeline {

    /// info 딕셔너리에서 에러 추출
    /// - Parameter info: PHImageManager info 딕셔너리
    /// - Returns: 에러 객체 (없으면 nil)
    public static func error(from info: [AnyHashable: Any]?) -> Error? {
        return info?[PHImageErrorKey] as? Error
    }

    /// info 딕셔너리에서 취소 여부 확인
    /// - Parameter info: PHImageManager info 딕셔너리
    /// - Returns: 취소 여부
    public static func isCancelled(from info: [AnyHashable: Any]?) -> Bool {
        return (info?[PHImageCancelledKey] as? Bool) ?? false
    }

    /// info 딕셔너리에서 iCloud 다운로드 필요 여부 확인
    /// - Parameter info: PHImageManager info 딕셔너리
    /// - Returns: iCloud 다운로드 필요 여부
    public static func isInCloud(from info: [AnyHashable: Any]?) -> Bool {
        return (info?[PHImageResultIsInCloudKey] as? Bool) ?? false
    }
}

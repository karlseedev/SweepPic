// PhotoLibraryService.swift
// PhotoKit 기반 사진 라이브러리 서비스
//
// T011: PhotoLibraryServiceProtocol 및 PhotoLibraryService 생성
// - authorizationStatus
// - requestAuthorization
// - fetchAllPhotos
// - startObservingChanges

import Foundation
import Photos

// MARK: - PhotoLibraryServiceProtocol (T011)

/// 사진 라이브러리 서비스 프로토콜
/// PhotoKit API를 추상화하여 테스트 가능하게 함
public protocol PhotoLibraryServiceProtocol: AnyObject {

    /// 현재 권한 상태
    var authorizationStatus: PermissionState { get }

    /// 권한 요청
    /// - Returns: 요청 후 권한 상태
    func requestAuthorization() async -> PermissionState

    /// 모든 사진 가져오기
    /// - Returns: PHFetchResult<PHAsset> (PhotoKit 결과)
    /// - Note: 이 메서드는 PHAsset을 직접 반환합니다.
    ///         UI 레이어에서 PhotoAssetEntry로 변환해야 합니다.
    func fetchAllPhotos() -> PHFetchResult<PHAsset>

    /// 변경 감지 시작
    /// PHPhotoLibraryChangeObserver를 등록합니다.
    func startObservingChanges()

    /// 변경 감지 중지
    func stopObservingChanges()

    /// 변경 콜백 등록
    /// - Parameter handler: 변경 발생 시 호출될 클로저
    func onLibraryChange(_ handler: @escaping (PHChange) -> Void)
}

// MARK: - PhotoLibraryService (T011)

/// PhotoKit 기반 사진 라이브러리 서비스 구현체
/// PHPhotoLibrary를 사용하여 사진 접근 및 변경 감지 제공
public final class PhotoLibraryService: NSObject, PhotoLibraryServiceProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = PhotoLibraryService()

    // MARK: - Private Properties

    /// 변경 핸들러
    private var changeHandler: ((PHChange) -> Void)?

    /// 옵저버 등록 여부
    private var isObserving = false

    // MARK: - Initialization

    /// 비공개 초기화 (싱글톤)
    private override init() {
        super.init()
    }

    // MARK: - PhotoLibraryServiceProtocol

    /// 현재 권한 상태
    /// PHAuthorizationStatus를 PermissionState로 변환
    public var authorizationStatus: PermissionState {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        return Self.mapAuthorizationStatus(status)
    }

    /// 권한 요청
    /// - Returns: 요청 후 권한 상태
    public func requestAuthorization() async -> PermissionState {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return Self.mapAuthorizationStatus(status)
    }

    /// 모든 사진 가져오기
    /// PRD 5.1 All Photos 정의에 따라 정렬
    /// - Returns: PHFetchResult<PHAsset>
    public func fetchAllPhotos() -> PHFetchResult<PHAsset> {
        let fetchOptions = PHFetchOptions()

        // 오래된 것이 위 (ascending: true)
        fetchOptions.sortDescriptors = [
            NSSortDescriptor(key: "creationDate", ascending: true)
        ]

        // 사진과 비디오만 (Live Photo는 image 타입에 포함됨)
        fetchOptions.predicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )

        return PHAsset.fetchAssets(with: fetchOptions)
    }

    /// 변경 감지 시작
    public func startObservingChanges() {
        guard !isObserving else { return }
        PHPhotoLibrary.shared().register(self)
        isObserving = true
    }

    /// 변경 감지 중지
    public func stopObservingChanges() {
        guard isObserving else { return }
        PHPhotoLibrary.shared().unregisterChangeObserver(self)
        isObserving = false
    }

    /// 변경 콜백 등록
    /// - Parameter handler: 변경 발생 시 호출될 클로저
    public func onLibraryChange(_ handler: @escaping (PHChange) -> Void) {
        self.changeHandler = handler
    }

    // MARK: - Helper Methods

    /// PHAuthorizationStatus를 PermissionState로 변환
    /// - Parameter status: PhotoKit 권한 상태
    /// - Returns: 앱 내부 권한 상태
    private static func mapAuthorizationStatus(_ status: PHAuthorizationStatus) -> PermissionState {
        switch status {
        case .notDetermined:
            return .notDetermined
        case .restricted:
            return .restricted
        case .denied:
            return .denied
        case .authorized:
            return .authorized
        case .limited:
            return .limited
        @unknown default:
            return .denied
        }
    }
}

// MARK: - PHPhotoLibraryChangeObserver

extension PhotoLibraryService: PHPhotoLibraryChangeObserver {

    /// 사진 라이브러리 변경 시 호출
    /// - Parameter changeInstance: 변경 정보
    public func photoLibraryDidChange(_ changeInstance: PHChange) {
        // 메인 스레드에서 핸들러 호출
        DispatchQueue.main.async { [weak self] in
            self?.changeHandler?(changeInstance)
        }
    }
}

// MARK: - PHAsset Extension

extension PHAsset {

    /// PHAsset을 PhotoAssetEntry로 변환
    /// - Returns: PhotoAssetEntry
    public func toPhotoAssetEntry() -> PhotoAssetEntry {
        let mediaType: MediaType
        switch self.mediaType {
        case .image:
            // Live Photo 체크
            if self.mediaSubtypes.contains(.photoLive) {
                mediaType = .livePhoto
            } else {
                mediaType = .photo
            }
        case .video:
            mediaType = .video
        default:
            mediaType = .photo
        }

        return PhotoAssetEntry(
            localIdentifier: self.localIdentifier,
            creationDate: self.creationDate,
            mediaType: mediaType,
            pixelWidth: self.pixelWidth,
            pixelHeight: self.pixelHeight
        )
    }
}

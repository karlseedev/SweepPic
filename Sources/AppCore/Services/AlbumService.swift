// AlbumService.swift
// 앨범 관련 서비스
//
// T048: AlbumServiceProtocol 및 AlbumService 생성
// - fetchUserAlbums: 사용자 생성 앨범 목록 조회
// - fetchSmartAlbums: 스마트 앨범 목록 조회
// - fetchPhotosInAlbum: 앨범 내 사진 조회

import Photos

// MARK: - AlbumServiceProtocol

/// 앨범 서비스 프로토콜
/// 앨범 목록 및 앨범 내 사진 조회 기능 정의
public protocol AlbumServiceProtocol {

    /// 사용자 생성 앨범 목록 조회
    /// - Returns: 사용자 앨범 배열
    func fetchUserAlbums() -> [Album]

    /// 스마트 앨범 목록 조회
    /// - Returns: 스마트 앨범 배열
    func fetchSmartAlbums() -> [SmartAlbum]

    /// 앨범 내 사진 조회
    /// - Parameter albumID: 앨범 로컬 식별자
    /// - Returns: PHFetchResult (nil이면 앨범을 찾지 못함)
    func fetchPhotosInAlbum(albumID: String) -> PHFetchResult<PHAsset>?

    /// 스마트 앨범 내 사진 조회
    /// - Parameter type: 스마트 앨범 타입
    /// - Returns: PHFetchResult (nil이면 앨범을 찾지 못함)
    func fetchPhotosInSmartAlbum(type: SmartAlbumType) -> PHFetchResult<PHAsset>?
}

// MARK: - AlbumService

/// 앨범 서비스 구현체
/// PhotoKit을 사용하여 앨범 정보 조회
public final class AlbumService: AlbumServiceProtocol {

    // MARK: - Singleton

    /// 공유 인스턴스
    public static let shared = AlbumService()

    private init() {}

    // MARK: - Public Methods

    /// 사용자 생성 앨범 목록 조회
    /// PHAssetCollectionType.album 타입의 모든 앨범 반환
    public func fetchUserAlbums() -> [Album] {
        var albums: [Album] = []

        // 사용자 앨범 조회 옵션
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]

        // 사용자 생성 앨범 조회
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .albumRegular,
            options: options
        )

        userAlbums.enumerateObjects { collection, _, _ in
            // 앨범 내 에셋 개수 조회
            let assetsFetchOptions = PHFetchOptions()
            assetsFetchOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

            let assets = PHAsset.fetchAssets(in: collection, options: assetsFetchOptions)
            let assetCount = assets.count

            // 키 에셋 (가장 최근 사진)
            let keyAssetID = assets.lastObject?.localIdentifier

            let album = Album(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "제목 없음",
                assetCount: assetCount,
                keyAssetIdentifier: keyAssetID,
                creationDate: collection.startDate
            )

            albums.append(album)
        }

        Log.print("[AlbumService] Fetched \(albums.count) user albums")
        return albums
    }

    /// 스마트 앨범 목록 조회
    /// MVP에서 지원하는 SmartAlbumType에 해당하는 앨범만 반환
    public func fetchSmartAlbums() -> [SmartAlbum] {
        var smartAlbums: [SmartAlbum] = []

        // 지원하는 스마트 앨범 타입별로 조회
        let supportedTypes: [SmartAlbumType] = [
            .screenshots,
            .selfies,
            .favorites,
            .videos,
            .livePhotos,
            .panoramas,
            .bursts,
            .timelapses,
            .slomoVideos,
            .depthEffect
        ]

        for albumType in supportedTypes {
            if let smartAlbum = fetchSmartAlbum(type: albumType) {
                // 에셋이 0개인 앨범은 제외
                if smartAlbum.assetCount > 0 {
                    smartAlbums.append(smartAlbum)
                }
            }
        }

        Log.print("[AlbumService] Fetched \(smartAlbums.count) smart albums")
        return smartAlbums
    }

    /// 앨범 내 사진 조회
    /// - Parameter albumID: 앨범 로컬 식별자
    /// - Returns: PHFetchResult (nil이면 앨범을 찾지 못함)
    public func fetchPhotosInAlbum(albumID: String) -> PHFetchResult<PHAsset>? {
        // 앨범 조회
        let collections = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [albumID],
            options: nil
        )

        guard let collection = collections.firstObject else {
            Log.print("[AlbumService] Album not found: \(albumID)")
            return nil
        }

        // 앨범 내 에셋 조회
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]
        options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)

        let assets = PHAsset.fetchAssets(in: collection, options: options)

        Log.print("[AlbumService] Fetched \(assets.count) photos in album: \(collection.localizedTitle ?? "Unknown")")
        return assets
    }

    /// 스마트 앨범 내 사진 조회
    /// - Parameter type: 스마트 앨범 타입
    /// - Returns: PHFetchResult (nil이면 앨범을 찾지 못함)
    public func fetchPhotosInSmartAlbum(type: SmartAlbumType) -> PHFetchResult<PHAsset>? {
        guard let subtype = phAssetCollectionSubtype(for: type) else {
            Log.print("[AlbumService] Unsupported smart album type: \(type)")
            return nil
        }

        // 스마트 앨범 조회
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: subtype,
            options: nil
        )

        guard let collection = collections.firstObject else {
            Log.print("[AlbumService] Smart album not found: \(type)")
            return nil
        }

        // 앨범 내 에셋 조회
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        // 비디오, 라이브포토 등은 mediaType 필터 제외
        if type != .videos && type != .livePhotos && type != .timelapses && type != .slomoVideos {
            options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        }

        let assets = PHAsset.fetchAssets(in: collection, options: options)

        Log.print("[AlbumService] Fetched \(assets.count) photos in smart album: \(type.displayTitle)")
        return assets
    }

    // MARK: - Private Methods

    /// 스마트 앨범 단일 조회
    private func fetchSmartAlbum(type: SmartAlbumType) -> SmartAlbum? {
        guard let subtype = phAssetCollectionSubtype(for: type) else {
            return nil
        }

        // 스마트 앨범 조회
        let collections = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: subtype,
            options: nil
        )

        guard let collection = collections.firstObject else {
            return nil
        }

        // 에셋 개수 조회
        let options = PHFetchOptions()

        // 비디오 타입이 아니면 이미지만 필터
        if type != .videos && type != .livePhotos && type != .timelapses && type != .slomoVideos {
            options.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        }

        let assets = PHAsset.fetchAssets(in: collection, options: options)
        let assetCount = assets.count

        // 키 에셋 (가장 최근 사진)
        let keyAssetID = assets.lastObject?.localIdentifier

        return SmartAlbum(
            id: collection.localIdentifier,
            type: type,
            assetCount: assetCount,
            keyAssetIdentifier: keyAssetID
        )
    }

    /// SmartAlbumType을 PHAssetCollectionSubtype으로 변환
    private func phAssetCollectionSubtype(for type: SmartAlbumType) -> PHAssetCollectionSubtype? {
        switch type {
        case .allPhotos:
            return .smartAlbumUserLibrary
        case .recentlyAdded:
            return .smartAlbumRecentlyAdded
        case .screenshots:
            return .smartAlbumScreenshots
        case .selfies:
            return .smartAlbumSelfPortraits
        case .favorites:
            return .smartAlbumFavorites
        case .videos:
            return .smartAlbumVideos
        case .livePhotos:
            return .smartAlbumLivePhotos
        case .panoramas:
            return .smartAlbumPanoramas
        case .bursts:
            return .smartAlbumBursts
        case .timelapses:
            return .smartAlbumTimelapses
        case .slomoVideos:
            return .smartAlbumSlomoVideos
        case .depthEffect:
            return .smartAlbumDepthEffect
        case .recentlyDeleted:
            // 시스템 휴지통 - 앱에서는 별도 접근 제한 가능
            return nil
        }
    }
}

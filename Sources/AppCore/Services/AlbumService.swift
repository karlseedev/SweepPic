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

    /// 비동기 앨범 전체 로드 (백그라운드 스레드에서 PhotoKit fetch 실행)
    /// - completion: 메인 스레드에서 호출됨
    /// - keyAssets: 앨범ID → PHAsset 딕셔너리 (셀에서 재 fetch 방지)
    func fetchAllAlbumsAsync(
        completion: @escaping (
            _ smartAlbums: [SmartAlbum],
            _ userAlbums: [Album],
            _ keyAssets: [String: PHAsset]
        ) -> Void
    )

    /// 앨범 메타데이터만 동기 로드 (빠른 초기 표시용)
    /// - PHAsset.fetchAssets 호출 없음 → 매우 빠름 (~11회 collection 호출)
    /// - estimatedAssetCount 사용 (정확하지 않을 수 있음)
    /// - keyAsset 없음 (셀에서 placeholder 표시)
    func fetchAlbumMetadataSync() -> (smartAlbums: [SmartAlbum], userAlbums: [Album])

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
    /// - fetchLimit=1로 keyAsset만 로드하여 성능 최적화
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
            // estimatedAssetCount == 0이면 빈 앨범 → 스킵 (빠른 필터)
            // NSNotFound(-1)은 스킵하지 않고 실제 fetch로 확인
            let estimated = collection.estimatedAssetCount
            if estimated == 0 { return }

            // 에셋 개수 조회 (mediaType 필터 적용)
            let countOptions = PHFetchOptions()
            countOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            let assetCount = PHAsset.fetchAssets(in: collection, options: countOptions).count

            // keyAsset: fetchLimit=1 + 최신순 정렬 → 1개만 로드
            let keyOptions = PHFetchOptions()
            keyOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
            keyOptions.fetchLimit = 1
            keyOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
            let keyAssetID = PHAsset.fetchAssets(in: collection, options: keyOptions).firstObject?.localIdentifier

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

    // MARK: - Lightweight Sync API

    /// 앨범 메타데이터만 동기 로드 (빠른 초기 표시용)
    /// - PHAssetCollection만 조회, PHAsset.fetchAssets 호출 없음
    /// - estimatedAssetCount 사용 (NSNotFound인 경우 0으로 표시, Phase 2에서 교정)
    /// - keyAssetIdentifier nil → 셀에서 placeholder 표시
    /// - 총 ~11회 PHAssetCollection 호출 (10 smart + 1 user)
    public func fetchAlbumMetadataSync() -> (smartAlbums: [SmartAlbum], userAlbums: [Album]) {
        var smartAlbums: [SmartAlbum] = []
        var userAlbumsList: [Album] = []

        // ── 스마트 앨범 (collection 메타데이터만) ──
        let supportedTypes: [SmartAlbumType] = [
            .screenshots, .selfies, .favorites, .videos,
            .livePhotos, .panoramas, .bursts, .timelapses,
            .slomoVideos, .depthEffect
        ]

        for albumType in supportedTypes {
            guard let subtype = phAssetCollectionSubtype(for: albumType) else { continue }

            let collections = PHAssetCollection.fetchAssetCollections(
                with: .smartAlbum, subtype: subtype, options: nil
            )
            guard let collection = collections.firstObject else { continue }

            let estimated = collection.estimatedAssetCount
            if estimated == 0 { continue }

            // NSNotFound → 0 (Phase 2에서 정확한 값으로 교정됨)
            let displayCount = estimated == NSNotFound ? 0 : estimated

            smartAlbums.append(SmartAlbum(
                id: collection.localIdentifier,
                type: albumType,
                assetCount: displayCount,
                keyAssetIdentifier: nil  // Phase 2에서 채워짐
            ))
        }

        // ── 사용자 앨범 (collection 메타데이터만) ──
        let albumOptions = PHFetchOptions()
        albumOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]

        let userCollections = PHAssetCollection.fetchAssetCollections(
            with: .album, subtype: .albumRegular, options: albumOptions
        )

        userCollections.enumerateObjects { collection, _, _ in
            let estimated = collection.estimatedAssetCount
            if estimated == 0 { return }

            let displayCount = estimated == NSNotFound ? 0 : estimated

            userAlbumsList.append(Album(
                id: collection.localIdentifier,
                title: collection.localizedTitle ?? "제목 없음",
                assetCount: displayCount,
                keyAssetIdentifier: nil,
                creationDate: collection.startDate
            ))
        }

        Log.print("[AlbumService] Metadata sync: \(smartAlbums.count) smart, \(userAlbumsList.count) user albums")
        return (smartAlbums, userAlbumsList)
    }

    // MARK: - Async API

    /// 비동기 앨범 전체 로드 (백그라운드 스레드에서 PhotoKit fetch 실행)
    /// - 스마트 앨범 + 사용자 앨범 + keyAsset PHAsset을 한 번에 반환
    /// - completion은 메인 스레드에서 호출
    ///
    /// 성능 최적화:
    /// - 앨범당 단일 PHAsset.fetchAssets 호출 (count + keyAsset 병합)
    ///   → PHFetchResult.count는 O(1), .firstObject로 최신 에셋 1개만 접근
    /// - keyAsset PHAsset을 fetch 중 직접 캡처 → batch re-fetch 제거
    /// - estimatedAssetCount == 0 빠른 필터
    public func fetchAllAlbumsAsync(
        completion: @escaping (
            _ smartAlbums: [SmartAlbum],
            _ userAlbums: [Album],
            _ keyAssets: [String: PHAsset]
        ) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            var smartAlbums: [SmartAlbum] = []
            var userAlbumsList: [Album] = []
            var keyAssets: [String: PHAsset] = [:]

            // ── 스마트 앨범 (앨범당 1회 fetch) ──
            let supportedTypes: [SmartAlbumType] = [
                .screenshots, .selfies, .favorites, .videos,
                .livePhotos, .panoramas, .bursts, .timelapses,
                .slomoVideos, .depthEffect
            ]

            for albumType in supportedTypes {
                guard let subtype = self.phAssetCollectionSubtype(for: albumType) else { continue }

                let collections = PHAssetCollection.fetchAssetCollections(
                    with: .smartAlbum, subtype: subtype, options: nil
                )
                guard let collection = collections.firstObject else { continue }

                // estimatedAssetCount == 0이면 빈 앨범 → 스킵
                let estimated = collection.estimatedAssetCount
                if estimated == 0 { continue }

                let needsImageFilter = albumType != .videos && albumType != .livePhotos
                    && albumType != .timelapses && albumType != .slomoVideos

                // 단일 fetch: 최신순 정렬 → .count로 개수, .firstObject로 keyAsset
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                if needsImageFilter {
                    options.predicate = NSPredicate(
                        format: "mediaType = %d", PHAssetMediaType.image.rawValue
                    )
                }

                let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
                let assetCount = fetchResult.count  // O(1)
                // ⚠️ assetCount == 0 체크 제거: Phase 1(estimatedAssetCount 기반)과 동일한 앨범 목록 유지
                // Phase 1에서 estimatedAssetCount > 0으로 포함된 앨범은 Phase 2에서도 유지
                // → sameStructure=true 보장 → reloadData 스킵 → 깜빡임 방지

                let keyAsset = fetchResult.firstObject  // 최신 에셋 1개
                let albumID = collection.localIdentifier

                smartAlbums.append(SmartAlbum(
                    id: albumID,
                    type: albumType,
                    assetCount: assetCount,
                    keyAssetIdentifier: keyAsset?.localIdentifier
                ))

                // PHAsset 직접 캡처 (batch re-fetch 불필요)
                if let asset = keyAsset {
                    keyAssets[albumID] = asset
                }
            }

            // ── 사용자 앨범 (앨범당 1회 fetch) ──
            let albumOptions = PHFetchOptions()
            albumOptions.sortDescriptors = [NSSortDescriptor(key: "localizedTitle", ascending: true)]

            let userCollections = PHAssetCollection.fetchAssetCollections(
                with: .album, subtype: .albumRegular, options: albumOptions
            )

            userCollections.enumerateObjects { collection, _, _ in
                // estimatedAssetCount == 0이면 빈 앨범 → 스킵
                let estimated = collection.estimatedAssetCount
                if estimated == 0 { return }

                // 단일 fetch: 최신순 정렬 + 이미지 필터
                let options = PHFetchOptions()
                options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
                options.predicate = NSPredicate(
                    format: "mediaType = %d", PHAssetMediaType.image.rawValue
                )

                let fetchResult = PHAsset.fetchAssets(in: collection, options: options)
                let assetCount = fetchResult.count
                // ⚠️ assetCount == 0 체크 제거: Phase 1과 동일한 앨범 목록 유지
                // (동영상만 있는 앨범도 포함 → sameStructure=true 보장 → 깜빡임 방지)

                let keyAsset = fetchResult.firstObject
                let albumID = collection.localIdentifier

                userAlbumsList.append(Album(
                    id: albumID,
                    title: collection.localizedTitle ?? "제목 없음",
                    assetCount: assetCount,
                    keyAssetIdentifier: keyAsset?.localIdentifier,
                    creationDate: collection.startDate
                ))

                if let asset = keyAsset {
                    keyAssets[albumID] = asset
                }
            }

            Log.print("[AlbumService] Async fetched \(smartAlbums.count) smart, \(userAlbumsList.count) user albums")

            // 메인 스레드에서 completion 호출
            DispatchQueue.main.async {
                completion(smartAlbums, userAlbumsList, keyAssets)
            }
        }
    }

    // MARK: - Private Methods

    /// 스마트 앨범 단일 조회 (fetchLimit=1로 keyAsset만 로드)
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

        // estimatedAssetCount == 0이면 빈 앨범 → 스킵
        // NSNotFound(-1)은 스킵하지 않고 실제 fetch로 확인
        let estimated = collection.estimatedAssetCount
        if estimated == 0 { return nil }

        // mediaType 필터 조건 (비디오 계열은 필터 제외)
        let needsImageFilter = type != .videos && type != .livePhotos
            && type != .timelapses && type != .slomoVideos

        // 에셋 개수 조회
        let countOptions = PHFetchOptions()
        if needsImageFilter {
            countOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        }
        let assetCount = PHAsset.fetchAssets(in: collection, options: countOptions).count

        if assetCount == 0 { return nil }

        // keyAsset: fetchLimit=1 + 최신순 정렬 → 1개만 로드
        let keyOptions = PHFetchOptions()
        keyOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        keyOptions.fetchLimit = 1
        if needsImageFilter {
            keyOptions.predicate = NSPredicate(format: "mediaType = %d", PHAssetMediaType.image.rawValue)
        }
        let keyAssetID = PHAsset.fetchAssets(in: collection, options: keyOptions).firstObject?.localIdentifier

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

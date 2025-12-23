// AlbumModels.swift
// 앨범 관련 모델 정의
//
// T046: Album 구조체 (사용자 앨범)
// T047: SmartAlbum 구조체 (스마트 앨범)
// T054: TrashAlbum 구조체 (휴지통 가상 앨범) - Phase 7에서 구현

import Foundation

// MARK: - Album (T046)

/// 사용자 앨범 정보
/// PHAssetCollection.assetCollectionType == .album
public struct Album: Identifiable, Hashable {

    /// 앨범 로컬 식별자 (PHAssetCollection.localIdentifier)
    public let id: String

    /// 앨범 제목
    public let title: String

    /// 앨범 내 에셋 개수
    public let assetCount: Int

    /// 키 에셋 ID (대표 썸네일용)
    /// 보통 가장 최근 사진
    public let keyAssetIdentifier: String?

    /// 앨범 생성일
    public let creationDate: Date?

    public init(
        id: String,
        title: String,
        assetCount: Int,
        keyAssetIdentifier: String? = nil,
        creationDate: Date? = nil
    ) {
        self.id = id
        self.title = title
        self.assetCount = assetCount
        self.keyAssetIdentifier = keyAssetIdentifier
        self.creationDate = creationDate
    }
}

// MARK: - SmartAlbum (T047)

/// 스마트 앨범 타입
/// PHAssetCollectionSubtype 중 MVP에서 지원하는 타입
public enum SmartAlbumType: String, CaseIterable, Hashable {
    /// 모든 사진
    case allPhotos = "all_photos"

    /// 최근 항목 (Recently Added)
    case recentlyAdded = "recently_added"

    /// 스크린샷
    case screenshots = "screenshots"

    /// 셀프카메라 (전면 카메라)
    case selfies = "selfies"

    /// 즐겨찾기
    case favorites = "favorites"

    /// 비디오
    case videos = "videos"

    /// Live Photos
    case livePhotos = "live_photos"

    /// 파노라마
    case panoramas = "panoramas"

    /// 버스트
    case bursts = "bursts"

    /// 타임랩스
    case timelapses = "timelapses"

    /// 슬로모션
    case slomoVideos = "slomo_videos"

    /// 인물 사진 (Portrait)
    case depthEffect = "depth_effect"

    /// 최근 삭제됨 (시스템 휴지통)
    case recentlyDeleted = "recently_deleted"

    /// 표시 제목 (한글)
    public var displayTitle: String {
        switch self {
        case .allPhotos: return "모든 사진"
        case .recentlyAdded: return "최근 추가"
        case .screenshots: return "스크린샷"
        case .selfies: return "셀프카메라"
        case .favorites: return "즐겨찾기"
        case .videos: return "비디오"
        case .livePhotos: return "Live Photos"
        case .panoramas: return "파노라마"
        case .bursts: return "버스트"
        case .timelapses: return "타임랩스"
        case .slomoVideos: return "슬로모션"
        case .depthEffect: return "인물 사진"
        case .recentlyDeleted: return "최근 삭제된 항목"
        }
    }

    /// 시스템 아이콘 이름
    public var systemIconName: String {
        switch self {
        case .allPhotos: return "photo.on.rectangle"
        case .recentlyAdded: return "clock"
        case .screenshots: return "camera.viewfinder"
        case .selfies: return "person.crop.square"
        case .favorites: return "heart.fill"
        case .videos: return "video"
        case .livePhotos: return "livephoto"
        case .panoramas: return "pano"
        case .bursts: return "square.stack.3d.down.right"
        case .timelapses: return "timelapse"
        case .slomoVideos: return "slowmo"
        case .depthEffect: return "cube"
        case .recentlyDeleted: return "trash"
        }
    }
}

/// 스마트 앨범 정보
/// PHAssetCollection.assetCollectionType == .smartAlbum
public struct SmartAlbum: Identifiable, Hashable {

    /// 앨범 로컬 식별자 (PHAssetCollection.localIdentifier)
    public let id: String

    /// 스마트 앨범 타입
    public let type: SmartAlbumType

    /// 앨범 제목 (표시용)
    public var title: String {
        return type.displayTitle
    }

    /// 앨범 내 에셋 개수
    public let assetCount: Int

    /// 키 에셋 ID (대표 썸네일용)
    public let keyAssetIdentifier: String?

    public init(
        id: String,
        type: SmartAlbumType,
        assetCount: Int,
        keyAssetIdentifier: String? = nil
    ) {
        self.id = id
        self.type = type
        self.assetCount = assetCount
        self.keyAssetIdentifier = keyAssetIdentifier
    }
}

// MARK: - TrashAlbum (T054 - Phase 7)

/// 휴지통 가상 앨범
/// 앱 내 TrashStore에서 관리하는 휴지통 사진 표시용
/// Phase 7에서 구현 예정
public struct TrashAlbum: Identifiable, Hashable {

    /// 가상 앨범 ID (고정값)
    public let id: String = "app_trash_album"

    /// 앨범 제목
    public let title: String = "휴지통"

    /// 휴지통 내 에셋 개수
    public let assetCount: Int

    /// 키 에셋 ID (대표 썸네일용)
    public let keyAssetIdentifier: String?

    public init(
        assetCount: Int,
        keyAssetIdentifier: String? = nil
    ) {
        self.assetCount = assetCount
        self.keyAssetIdentifier = keyAssetIdentifier
    }
}

// MARK: - AlbumSection

/// 앨범 목록 섹션 타입
/// AlbumsViewController에서 섹션별 표시에 사용
public enum AlbumSection: Int, CaseIterable {
    /// 스마트 앨범 (시스템 자동 생성)
    case smartAlbums = 0

    /// 사용자 앨범 (직접 생성)
    case userAlbums = 1

    /// 섹션 헤더 제목
    public var headerTitle: String? {
        switch self {
        case .smartAlbums: return "미디어 유형"
        case .userAlbums: return "나의 앨범"
        }
    }
}

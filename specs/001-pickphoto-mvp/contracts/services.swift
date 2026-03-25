// MARK: - SweepPic MVP Service Contracts
// Generated: 2025-12-16
// Branch: 001-pickphoto-mvp

import Foundation
import Photos
import UIKit

// MARK: - Photo Library Service

/// PhotoKit 라이브러리 접근 및 변경 감지 담당
protocol PhotoLibraryServiceProtocol {
    /// 현재 권한 상태
    var authorizationStatus: PHAuthorizationStatus { get }

    /// 권한 요청
    func requestAuthorization() async -> PHAuthorizationStatus

    /// 전체 사진 가져오기 (정렬: creationDate ascending)
    func fetchAllPhotos() -> PHFetchResult<PHAsset>

    /// 변경 감지 시작
    func startObservingChanges()

    /// 변경 감지 중지
    func stopObservingChanges()
}

// MARK: - Album Service

/// 앨범 및 스마트 앨범 관리
protocol AlbumServiceProtocol {
    /// 사용자 앨범 목록 가져오기
    func fetchUserAlbums() -> [Album]

    /// 스마트 앨범 가져오기 (Screenshots)
    func fetchSmartAlbums() -> [SmartAlbum]

    /// 특정 앨범의 사진 가져오기
    func fetchPhotos(in album: Album) -> PHFetchResult<PHAsset>

    /// 특정 스마트 앨범의 사진 가져오기
    func fetchPhotos(in smartAlbum: SmartAlbum) -> PHFetchResult<PHAsset>
}

// MARK: - Trash Store

/// 앱 내 휴지통 상태 관리 (파일 기반 저장)
protocol TrashStoreProtocol {
    /// 휴지통에 있는 사진 ID 집합
    var trashedAssetIDs: Set<String> { get }

    /// 휴지통 사진 수
    var trashedCount: Int { get }

    /// 특정 사진이 휴지통에 있는지 확인
    func isTrashed(_ assetID: String) -> Bool

    /// 1단계: 앱 내 휴지통으로 이동 (즉시, 팝업 없음)
    func moveToTrash(assetIDs: [String])

    /// 복구 (즉시, 팝업 없음)
    func restore(assetIDs: [String])

    /// 2단계: 완전 삭제 (iOS 시스템 팝업 표시됨)
    /// - Throws: PhotoKit 삭제 실패 시
    func permanentlyDelete(assetIDs: [String]) async throws

    /// 휴지통 비우기 (iOS 시스템 팝업 표시됨)
    /// - Throws: PhotoKit 삭제 실패 시
    func emptyTrash() async throws

    /// 상태 변경 알림 (Combine Publisher 또는 NotificationCenter)
    var onTrashStateChanged: (() -> Void)? { get set }
}

// MARK: - Image Pipeline

/// 이미지 요청 토큰
struct RequestToken: Hashable {
    let id: UUID
    let assetID: String

    init(assetID: String) {
        self.id = UUID()
        self.assetID = assetID
    }
}

/// 이미지 로딩 파이프라인 (오표시 0 보장)
protocol ImagePipelineProtocol {
    /// 이미지 요청
    /// - Parameters:
    ///   - assetID: PHAsset.localIdentifier
    ///   - targetSize: 요청 크기 (포인트)
    ///   - completion: 이미지 콜백 (메인 스레드)
    /// - Returns: 취소용 토큰
    func requestImage(
        for assetID: String,
        targetSize: CGSize,
        completion: @escaping (UIImage?) -> Void
    ) -> RequestToken

    /// 요청 취소
    func cancelRequest(_ token: RequestToken)

    /// 프리히트 시작
    func preheat(assetIDs: [String], targetSize: CGSize)

    /// 프리히트 중지
    func stopPreheating(assetIDs: [String])

    /// 모든 요청 취소 및 캐시 정리
    func reset()
}

// MARK: - Grid Data Source Driver

/// 그리드 데이터 소스 드라이버 (performBatchUpdates 기반)
protocol GridDataSourceDriverProtocol {
    /// 총 아이템 수
    var itemCount: Int { get }

    /// IndexPath에서 assetID 가져오기
    func assetID(at indexPath: IndexPath) -> String?

    /// assetID에서 IndexPath 가져오기
    func indexPath(for assetID: String) -> IndexPath?

    /// 가시 영역 리로드 (앵커 유지)
    func reloadVisibleRange(anchorAssetID: String?)

    /// 휴지통 상태 변경 적용 (딤드 표시 업데이트)
    func applyTrashStateChange(trashedAssetIDs: Set<String>)

    /// PhotoKit 변경 적용
    func applyPhotoLibraryChanges(_ changeDetails: PHFetchResultChangeDetails<PHAsset>)
}

// MARK: - Selection Manager

/// 선택 모드 상태 관리
protocol SelectionManagerProtocol {
    /// 현재 선택 모드 여부
    var isSelecting: Bool { get }

    /// 선택된 사진 ID 집합
    var selectedAssetIDs: Set<String> { get }

    /// 선택된 사진 수
    var selectedCount: Int { get }

    /// 선택 모드 시작
    func startSelecting()

    /// 선택 모드 종료 (선택 해제)
    func stopSelecting()

    /// 사진 선택 토글
    func toggleSelection(assetID: String)

    /// 여러 사진 선택 (드래그 선택용)
    func addSelection(assetIDs: [String])

    /// 선택 상태 확인
    func isSelected(_ assetID: String) -> Bool
}

// MARK: - Viewer Coordinator

/// 뷰어 탐색 및 삭제 후 이동 규칙
protocol ViewerCoordinatorProtocol {
    /// 현재 표시 중인 사진 ID
    var currentAssetID: String? { get }

    /// 현재 인덱스
    var currentIndex: Int { get }

    /// 총 사진 수 (휴지통 제외)
    var totalCount: Int { get }

    /// 특정 사진으로 이동
    func navigate(to assetID: String)

    /// 이전 사진으로 이동
    func navigateToPrevious() -> Bool

    /// 다음 사진으로 이동
    func navigateToNext() -> Bool

    /// 삭제 후 이동 (이전 사진 우선 규칙 적용)
    /// - Returns: 이동할 사진 ID (없으면 nil → 그리드 복귀)
    func handleDeletionAndNavigate(deletedAssetID: String) -> String?
}

// MARK: - Permission Store

/// 권한 상태 관리
protocol PermissionStoreProtocol {
    /// 현재 권한 상태
    var status: PHAuthorizationStatus { get }

    /// 삭제 가능 여부 (authorized 또는 limited)
    var canDelete: Bool { get }

    /// 권한 요청
    func requestPermission() async -> PHAuthorizationStatus

    /// Limited 선택 화면 표시
    func presentLimitedLibraryPicker(from viewController: UIViewController)
}

// MARK: - Models (Reference)

/// 앨범 모델
struct Album: Identifiable, Hashable {
    let localIdentifier: String
    let title: String
    let assetCount: Int
    let creationDate: Date?
    let keyAssetIdentifier: String?

    var id: String { localIdentifier }
}

/// 스마트 앨범 모델
struct SmartAlbum: Identifiable, Hashable {
    let type: PHAssetCollectionSubtype
    let title: String
    let assetCount: Int

    var id: Int { type.rawValue }
}

/// 미디어 타입
enum MediaType: String, Codable {
    case photo
    case video
    case livePhoto
}

/// 사진 엔트리 (앱 내부 표현)
struct PhotoAssetEntry: Identifiable, Hashable {
    let localIdentifier: String
    let creationDate: Date?
    let mediaType: MediaType
    let pixelWidth: Int
    let pixelHeight: Int

    var id: String { localIdentifier }
}

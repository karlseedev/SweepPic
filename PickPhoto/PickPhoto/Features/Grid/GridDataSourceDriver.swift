// GridDataSourceDriver.swift
// PHFetchResult 기반 데이터소스 드라이버
//
// T020: GridDataSourceDriverProtocol 및 GridDataSourceDriver 생성
// - assetID ↔ indexPath 매핑
// - performBatchUpdates 래퍼
// - 앵커 유지 기능

import UIKit
import Photos
import AppCore

// MARK: - GridDataSourceDriverProtocol

/// 그리드 데이터소스 드라이버 프로토콜
/// PHFetchResult와 UICollectionView 사이의 브릿지 역할
protocol GridDataSourceDriverProtocol: AnyObject {

    /// 현재 사진 수
    var count: Int { get }

    /// IndexPath에 해당하는 에셋 ID 반환
    /// - Parameter indexPath: 인덱스 경로
    /// - Returns: 에셋 ID 또는 nil
    func assetID(at indexPath: IndexPath) -> String?

    /// IndexPath에 해당하는 PHAsset 반환
    /// - Parameter indexPath: 인덱스 경로
    /// - Returns: PHAsset 또는 nil
    func asset(at indexPath: IndexPath) -> PHAsset?

    /// 에셋 ID에 해당하는 IndexPath 반환
    /// - Parameter assetID: 에셋 ID
    /// - Returns: IndexPath 또는 nil
    func indexPath(for assetID: String) -> IndexPath?

    /// 데이터 리로드
    /// - Parameter completion: 완료 콜백
    func reloadData(completion: (() -> Void)?)

    /// PHChange를 처리하여 배치 업데이트 수행
    /// - Parameters:
    ///   - changeInstance: PHChange 인스턴스
    ///   - collectionView: 업데이트할 컬렉션뷰
    ///   - anchorAssetID: 유지할 앵커 에셋 ID (핀치 줌 시 사용)
    ///   - columns: 현재 열 수 (padding 계산용)
    ///   - completion: 완료 콜백 (새로운 앵커 IndexPath 전달)
    func applyChange(
        _ changeInstance: PHChange,
        to collectionView: UICollectionView,
        anchorAssetID: String?,
        columns: Int,
        completion: ((IndexPath?) -> Void)?
    )

    /// 삭제대기함 상태 변경 적용
    /// - Parameters:
    ///   - trashedAssetIDs: 삭제대기함에 있는 에셋 ID 집합
    ///   - collectionView: 업데이트할 컬렉션뷰
    func applyTrashStateChange(
        trashedAssetIDs: Set<String>,
        to collectionView: UICollectionView
    )

    /// 현재 보이는 범위의 에셋 ID 배열 반환
    /// - Parameter collectionView: 컬렉션뷰
    /// - Returns: 에셋 ID 배열
    func visibleAssetIDs(in collectionView: UICollectionView) -> [String]

    /// 프리패치할 에셋 ID 배열 반환
    /// - Parameters:
    ///   - indexPaths: 프리패치할 인덱스 경로 배열
    /// - Returns: 에셋 ID 배열
    func assetIDs(for indexPaths: [IndexPath]) -> [String]
}

// MARK: - GridDataSourceDriver

/// PHFetchResult 기반 그리드 데이터소스 드라이버 구현체
/// performBatchUpdates를 사용하여 50k 기준 일정한 비용으로 업데이트
final class GridDataSourceDriver: NSObject, GridDataSourceDriverProtocol {

    // MARK: - Properties

    /// PhotoLibrary 서비스
    private let photoLibraryService: PhotoLibraryServiceProtocol

    /// 현재 PHFetchResult
    private(set) var fetchResult: PHFetchResult<PHAsset>?

    /// 에셋 ID → Index 캐시 (빠른 조회용)
    private var assetIDToIndexCache: [String: Int] = [:]

    /// 캐시 유효성 플래그
    private var isCacheValid = false

    // MARK: - GridDataSourceDriverProtocol

    /// 현재 사진 수
    var count: Int {
        fetchResult?.count ?? 0
    }

    // MARK: - Initialization

    /// 초기화
    /// - Parameter photoLibraryService: PhotoLibrary 서비스 (기본값: 공유 인스턴스)
    init(photoLibraryService: PhotoLibraryServiceProtocol = PhotoLibraryService.shared) {
        self.photoLibraryService = photoLibraryService
        super.init()
    }

    // MARK: - GridDataSourceDriverProtocol Implementation

    /// IndexPath에 해당하는 에셋 ID 반환
    func assetID(at indexPath: IndexPath) -> String? {
        guard let fetchResult = fetchResult,
              indexPath.item >= 0,
              indexPath.item < fetchResult.count else {
            return nil
        }
        return fetchResult.object(at: indexPath.item).localIdentifier
    }

    /// IndexPath에 해당하는 PHAsset 반환
    func asset(at indexPath: IndexPath) -> PHAsset? {
        guard let fetchResult = fetchResult,
              indexPath.item >= 0,
              indexPath.item < fetchResult.count else {
            return nil
        }
        return fetchResult.object(at: indexPath.item)
    }

    /// 에셋 ID에 해당하는 IndexPath 반환
    /// 캐시를 사용하여 빠른 조회 지원
    func indexPath(for assetID: String) -> IndexPath? {
        // 캐시가 유효하면 캐시에서 조회
        if isCacheValid, let index = assetIDToIndexCache[assetID] {
            return IndexPath(item: index, section: 0)
        }

        // 캐시가 없거나 유효하지 않으면 순차 검색 + 캐시 빌드
        guard fetchResult != nil else { return nil }

        // 캐시 빌드 (처음 호출 시)
        if !isCacheValid {
            buildCache()
            if let index = assetIDToIndexCache[assetID] {
                return IndexPath(item: index, section: 0)
            }
        }

        return nil
    }

    /// 데이터 리로드
    func reloadData(completion: (() -> Void)? = nil) {
        // [Timing] A) fetch 시작
        let fetchStart = CACurrentMediaTime()

        fetchResult = photoLibraryService.fetchAllPhotos()

        // [Timing] A) fetch 완료
        let fetchEnd = CACurrentMediaTime()
        let fetchMs = (fetchEnd - fetchStart) * 1000
        Log.print("[Timing] A) Fetch: \(String(format: "%.1f", fetchMs))ms (\(count) items)")

        invalidateCache()
        completion?()
    }

    /// PHChange 적용
    /// performBatchUpdates를 사용하여 효율적인 업데이트 수행
    func applyChange(
        _ changeInstance: PHChange,
        to collectionView: UICollectionView,
        anchorAssetID: String?,
        columns: Int,
        completion: ((IndexPath?) -> Void)?
    ) {
        // 메인 스레드 보장 (reloadData, performBatchUpdates는 메인 스레드에서만 호출 가능)
        dispatchPrecondition(condition: .onQueue(.main))
        guard let fetchResult = fetchResult,
              let changes = changeInstance.changeDetails(for: fetchResult) else {
            completion?(nil)
            return
        }

        // 변경이 없으면 무시
        if !changes.hasIncrementalChanges {
            // 전체 리로드 필요
            self.fetchResult = changes.fetchResultAfterChanges
            invalidateCache()
            collectionView.reloadData()

            // 앵커 위치 찾기
            let newAnchorIndexPath = anchorAssetID.flatMap { indexPath(for: $0) }
            completion?(newAnchorIndexPath)
            return
        }

        // 삭제가 포함된 경우 reloadData 사용 (performBatchUpdates와 reloadItems 충돌 방지)
        // permanentlyDelete 시 TrashStore.onStateChange와 PHPhotoLibraryChangeObserver가
        // 거의 동시에 호출되어 충돌 발생 가능
        if let removed = changes.removedIndexes, !removed.isEmpty {
            self.fetchResult = changes.fetchResultAfterChanges
            invalidateCache()
            collectionView.reloadData()

            let newAnchorIndexPath = anchorAssetID.flatMap { indexPath(for: $0) }
            completion?(newAnchorIndexPath)
            return
        }

        // 데이터 일관성 검증: 배치 업데이트 전에 예상 결과와 실제 결과 비교
        // 백그라운드 복귀 시 fetchResult가 이미 갱신된 경우 불일치 발생 가능
        let currentCount = fetchResult.count
        let afterCount = changes.fetchResultAfterChanges.count
        let insertedCount = changes.insertedIndexes?.count ?? 0
        let removedCount = changes.removedIndexes?.count ?? 0
        let expectedAfterCount = currentCount + insertedCount - removedCount

        if expectedAfterCount != afterCount {
            // 불일치 감지: reloadData로 안전하게 처리
            self.fetchResult = changes.fetchResultAfterChanges
            invalidateCache()
            collectionView.reloadData()

            let newAnchorIndexPath = anchorAssetID.flatMap { indexPath(for: $0) }
            completion?(newAnchorIndexPath)
            return
        }

        // 패딩 셀 변동 감지: numberOfItemsInSection이 count + padding을 반환하므로
        // padding이 변하면 performBatchUpdates가 실패함 (가상 셀 변화 미반영)
        // padding = count % columns == 0 ? 0 : (columns - count % columns)
        let beforePadding = currentCount % columns == 0 ? 0 : (columns - currentCount % columns)
        let afterPadding = afterCount % columns == 0 ? 0 : (columns - afterCount % columns)

        if beforePadding != afterPadding {
            // 패딩 변동 시 reloadData로 안전하게 처리
            self.fetchResult = changes.fetchResultAfterChanges
            invalidateCache()
            collectionView.reloadData()

            let newAnchorIndexPath = anchorAssetID.flatMap { indexPath(for: $0) }
            completion?(newAnchorIndexPath)
            return
        }

        // 배치 업데이트 수행 (삭제가 없고, 데이터 일관성이 검증된 경우만)
        collectionView.performBatchUpdates({
            // 삭제된 항목
            if let removed = changes.removedIndexes, !removed.isEmpty {
                collectionView.deleteItems(at: removed.map { IndexPath(item: $0, section: 0) })
            }

            // 삽입된 항목
            if let inserted = changes.insertedIndexes, !inserted.isEmpty {
                collectionView.insertItems(at: inserted.map { IndexPath(item: $0, section: 0) })
            }

            // 이동된 항목
            changes.enumerateMoves { fromIndex, toIndex in
                collectionView.moveItem(
                    at: IndexPath(item: fromIndex, section: 0),
                    to: IndexPath(item: toIndex, section: 0)
                )
            }

            // fetchResult 업데이트
            self.fetchResult = changes.fetchResultAfterChanges

        }, completion: { [weak self] _ in
            // 캐시 무효화
            self?.invalidateCache()

            // 변경된 항목 리로드
            if let changed = changes.changedIndexes, !changed.isEmpty {
                let indexPaths = changed.map { IndexPath(item: $0, section: 0) }
                collectionView.reloadItems(at: indexPaths)
            }

            // 앵커 위치 찾기
            let newAnchorIndexPath = anchorAssetID.flatMap { self?.indexPath(for: $0) }
            completion?(newAnchorIndexPath)
        })

    }

    /// 삭제대기함 상태 변경 적용
    /// 딤드 표시 업데이트를 위해 해당 셀만 리로드
    func applyTrashStateChange(
        trashedAssetIDs: Set<String>,
        to collectionView: UICollectionView
    ) {
        // 현재 보이는 셀 중 삭제대기함 상태가 변경된 셀만 리로드
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems

        var indexPathsToReload: [IndexPath] = []

        for indexPath in visibleIndexPaths {
            if assetID(at: indexPath) != nil {
                // 삭제대기함 상태가 변경된 셀 확인
                // (실제로는 이전 상태와 비교해야 하지만, MVP에서는 모든 보이는 셀 리로드)
                indexPathsToReload.append(indexPath)
            }
        }

        if !indexPathsToReload.isEmpty {
            collectionView.reloadItems(at: indexPathsToReload)
        }
    }

    /// 현재 보이는 범위의 에셋 ID 배열 반환
    func visibleAssetIDs(in collectionView: UICollectionView) -> [String] {
        let visibleIndexPaths = collectionView.indexPathsForVisibleItems
        return visibleIndexPaths.compactMap { assetID(at: $0) }
    }

    /// 프리패치할 에셋 ID 배열 반환
    func assetIDs(for indexPaths: [IndexPath]) -> [String] {
        return indexPaths.compactMap { assetID(at: $0) }
    }

    // MARK: - Private Methods

    /// 캐시 빌드
    /// 대용량 데이터에서 빠른 조회를 위해 캐시 생성
    private func buildCache() {
        guard let fetchResult = fetchResult else { return }

        assetIDToIndexCache.removeAll(keepingCapacity: true)

        // 모든 에셋 ID를 캐시에 저장
        // Note: 5만 장 기준 약 50ms 소요 예상 (최초 1회)
        for index in 0..<fetchResult.count {
            let asset = fetchResult.object(at: index)
            assetIDToIndexCache[asset.localIdentifier] = index
        }

        isCacheValid = true
    }

    /// 캐시 무효화
    private func invalidateCache() {
        isCacheValid = false
        assetIDToIndexCache.removeAll(keepingCapacity: true)
    }
}

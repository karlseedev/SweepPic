// GridDataSource.swift
// 그리드 데이터 소스 추상화 프로토콜 및 어댑터
//
// Phase 1: BaseGridViewController 리팩토링 기반 작업
// - 세 가지 그리드 (Grid, Album, Trash)의 데이터 접근 추상화
// - GridViewController: GridDataSourceDriver
// - AlbumGridViewController: PHFetchResult<PHAsset>
// - TrashAlbumViewController: [PHAsset] 배열

import Foundation
import UIKit
import Photos

// MARK: - GridDataSource Protocol

/// 그리드 데이터 소스 프로토콜
/// BaseGridViewController에서 데이터 접근을 추상화
protocol GridDataSource: AnyObject {
    /// 전체 에셋 개수
    var assetCount: Int { get }

    /// 인덱스에 해당하는 PHAsset 반환
    func asset(at index: Int) -> PHAsset?

    /// 인덱스에 해당하는 에셋 ID 반환
    func assetID(at index: Int) -> String?

    /// 에셋 ID로 인덱스 검색
    func assetIndex(for assetID: String) -> Int?

    /// 에셋 ID로 PHAsset 반환
    func assetForID(_ assetID: String) -> PHAsset?

    /// 뷰어용 PHFetchResult (옵셔널)
    /// - Grid/Album: fetchResult 반환
    /// - Trash: nil (assetIDs 사용)
    var fetchResultForViewer: PHFetchResult<PHAsset>? { get }

    /// fetchResultForViewer가 nil인 경우 사용할 에셋 ID 배열
    /// 뷰어에서 순서 보장된 네비게이션에 사용
    var orderedAssetIDs: [String] { get }
}

// MARK: - GridDataSourceDriverAdapter

/// GridDataSourceDriver를 GridDataSource로 래핑
/// GridViewController에서 사용
final class GridDataSourceDriverAdapter: GridDataSource {
    private let driver: GridDataSourceDriver

    init(driver: GridDataSourceDriver) {
        self.driver = driver
    }

    var assetCount: Int {
        driver.count
    }

    func asset(at index: Int) -> PHAsset? {
        driver.asset(at: IndexPath(item: index, section: 0))
    }

    func assetID(at index: Int) -> String? {
        driver.assetID(at: IndexPath(item: index, section: 0))
    }

    func assetIndex(for assetID: String) -> Int? {
        driver.indexPath(for: assetID)?.item
    }

    func assetForID(_ assetID: String) -> PHAsset? {
        guard let index = assetIndex(for: assetID) else { return nil }
        return asset(at: index)
    }

    var fetchResultForViewer: PHFetchResult<PHAsset>? {
        driver.fetchResult
    }

    /// 사용되지 않음 (fetchResultForViewer가 있으므로)
    var orderedAssetIDs: [String] {
        (0..<assetCount).compactMap { assetID(at: $0) }
    }
}

// MARK: - AlbumDataSource

/// PHFetchResult를 GridDataSource로 래핑
/// AlbumGridViewController에서 사용
final class AlbumDataSource: GridDataSource {
    private let fetchResult: PHFetchResult<PHAsset>

    init(fetchResult: PHFetchResult<PHAsset>) {
        self.fetchResult = fetchResult
    }

    var assetCount: Int {
        fetchResult.count
    }

    func asset(at index: Int) -> PHAsset? {
        guard index >= 0, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index)
    }

    func assetID(at index: Int) -> String? {
        guard index >= 0, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index).localIdentifier
    }

    func assetIndex(for assetID: String) -> Int? {
        for i in 0..<fetchResult.count {
            if fetchResult.object(at: i).localIdentifier == assetID {
                return i
            }
        }
        return nil
    }

    func assetForID(_ assetID: String) -> PHAsset? {
        guard let index = assetIndex(for: assetID) else { return nil }
        return asset(at: index)
    }

    var fetchResultForViewer: PHFetchResult<PHAsset>? {
        fetchResult
    }

    /// 사용되지 않음 (fetchResultForViewer가 있으므로)
    var orderedAssetIDs: [String] {
        (0..<fetchResult.count).map { fetchResult.object(at: $0).localIdentifier }
    }
}

// MARK: - TrashDataSource

/// PHFetchResult 기반 삭제대기함 데이터 소스
/// TrashAlbumViewController에서 사용
/// 그리드와 뷰어가 동일한 fetchResult를 공유하여 인덱스 일관성 보장
final class TrashDataSource: GridDataSource {
    /// 삭제대기함 fetchResult (그리드와 뷰어 공유)
    /// setFetchResult()를 통해 외부에서 갱신
    private(set) var fetchResult: PHFetchResult<PHAsset>?

    /// 에셋 ID → 인덱스 캐시 (O(1) 조회용)
    private var indexCache: [String: Int] = [:]

    /// fetchResult 설정 (외부에서 갱신)
    /// 인덱스 캐시 자동 재구축
    func setFetchResult(_ fetchResult: PHFetchResult<PHAsset>?) {
        self.fetchResult = fetchResult
        rebuildIndexCache()
    }

    /// 인덱스 캐시 재구축 (fetchResult 기반)
    private func rebuildIndexCache() {
        indexCache.removeAll(keepingCapacity: true)
        guard let fetchResult = fetchResult else { return }
        for i in 0..<fetchResult.count {
            let asset = fetchResult.object(at: i)
            indexCache[asset.localIdentifier] = i
        }
    }

    /// 빈 상태 확인용 (기존 assets.isEmpty 대체)
    var isEmpty: Bool {
        fetchResult == nil || fetchResult!.count == 0
    }

    var assetCount: Int {
        fetchResult?.count ?? 0
    }

    func asset(at index: Int) -> PHAsset? {
        guard let fetchResult = fetchResult,
              index >= 0, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index)
    }

    func assetID(at index: Int) -> String? {
        guard let fetchResult = fetchResult,
              index >= 0, index < fetchResult.count else { return nil }
        return fetchResult.object(at: index).localIdentifier
    }

    /// O(1) 인덱스 조회 (캐시 사용)
    func assetIndex(for assetID: String) -> Int? {
        indexCache[assetID]
    }

    func assetForID(_ assetID: String) -> PHAsset? {
        guard let index = assetIndex(for: assetID) else { return nil }
        return asset(at: index)
    }

    /// 뷰어용 fetchResult (그리드와 동일한 인스턴스 공유)
    var fetchResultForViewer: PHFetchResult<PHAsset>? {
        fetchResult
    }

    /// 프로토콜 요구사항 (fetchResultForViewer가 있으므로 사용되지 않음)
    var orderedAssetIDs: [String] {
        guard let fetchResult = fetchResult else { return [] }
        return (0..<fetchResult.count).map { fetchResult.object(at: $0).localIdentifier }
    }
}

//
//  PreviewViewerCoordinator.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  미리보기 전용 뷰어 코디네이터
//  - PHFetchResult 대신 [PHAsset] 배열 기반
//  - 스와이프 삭제/복구 없음 (미리보기는 읽기 전용)
//  - ViewerCoordinatorProtocol 준수하여 ViewerViewController 재사용
//

import Photos
import AppCore

/// 미리보기 전용 뷰어 코디네이터
///
/// [PHAsset] 배열을 감싸서 ViewerCoordinatorProtocol을 구현합니다.
/// 미리보기 그리드에서 사진 탭 시 뷰어를 열기 위한 경량 코디네이터.
final class PreviewViewerCoordinator: ViewerCoordinatorProtocol {

    // MARK: - Properties

    /// 사진 배열 (제외 기능으로 런타임에 제거 가능)
    private var assets: [PHAsset]

    /// fetchResult (유사 사진 분석용 — 미리보기에서는 미사용)
    var fetchResult: PHFetchResult<PHAsset>? { nil }

    /// 전체 사진 수
    var totalCount: Int { assets.count }

    // MARK: - Initialization

    /// 초기화
    /// - Parameter assets: 표시할 사진 배열
    init(assets: [PHAsset]) {
        self.assets = assets
    }

    // MARK: - Exclude Support

    /// 에셋 제거 (정리 미리보기 제외 기능용)
    /// - Parameter id: 제거할 에셋의 localIdentifier
    /// - Note: 호출 후 assets.count가 줄어들므로 nextIndexAfterDelete가 정확히 동작
    func removeAsset(id: String) {
        assets.removeAll { $0.localIdentifier == id }
    }

    // MARK: - ViewerCoordinatorProtocol

    /// 인덱스에 해당하는 PHAsset 반환
    func asset(at index: Int) -> PHAsset? {
        guard index >= 0, index < assets.count else { return nil }
        return assets[index]
    }

    /// 인덱스에 해당하는 에셋 ID 반환
    func assetID(at index: Int) -> String? {
        return asset(at: index)?.localIdentifier
    }

    /// 에셋 ID에 해당하는 인덱스 반환
    func index(for assetID: String) -> Int? {
        return assets.firstIndex { $0.localIdentifier == assetID }
    }

    /// 삭제 후 다음 인덱스 (미리보기에서는 삭제 없음, 기본 구현)
    func nextIndexAfterDelete(currentIndex: Int) -> Int {
        if currentIndex > 0 { return currentIndex - 1 }
        return min(currentIndex, assets.count - 2)
    }

    /// 휴지통 여부 (미리보기에서는 항상 false)
    func isTrashed(at index: Int) -> Bool { false }

    /// 필터링 인덱스 갱신 (미리보기에서는 no-op)
    func refreshFilteredIndices() {}

    /// 필터링된 인덱스를 원본 인덱스로 변환 (1:1 매핑)
    func originalIndex(from filteredIndex: Int) -> Int? {
        guard filteredIndex >= 0, filteredIndex < assets.count else { return nil }
        return filteredIndex
    }
}

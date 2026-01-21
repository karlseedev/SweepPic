// BaseGridViewController+PinchZoom.swift
// 핀치줌 기능 구현
//
// 핵심 동작:
// 1. 전체 화면이 transform으로 확대/축소 (스크린샷처럼)
// 2. 기준점(1/3/5열) 통과 시 → 해당 열 기준 이미지로 fade in
// 3. 핀치 종료 → transform 제거 + 새 레이아웃 즉시 적용

import UIKit
import Photos
import AppCore

// MARK: - PinchZoomState

/// 핀치줌 상태 관리
struct PinchZoomState {
    /// 핀치 활성화 여부
    var isActive: Bool = false
    /// 핀치 시작 시 스케일 (보통 1.0)
    var initialScale: CGFloat = 1.0
    /// 핀치 시작 시 열 수
    var baseColumnCount: GridColumnCount = .three
    /// 이전 프레임의 가상 열 수 (기준점 통과 감지용)
    var previousVirtualColumns: CGFloat = 3.0
    /// 현재 목표 열 수 (fade in 대상)
    var currentTargetColumns: GridColumnCount?
    /// 앵커 에셋 ID (이미지 유지 대상)
    var anchorAssetID: String?
    /// 핀치 중심점 (뷰 좌표, 0~bounds)
    var anchorPoint: CGPoint = .zero

    // anchorPoint 복원용 (점프 방지)
    /// 원본 layer.anchorPoint
    var originalLayerAnchorPoint: CGPoint = CGPoint(x: 0.5, y: 0.5)
    /// 원본 layer.position
    var originalLayerPosition: CGPoint = .zero

    /// 상태 초기화
    mutating func reset() {
        isActive = false
        initialScale = 1.0
        previousVirtualColumns = 3.0
        currentTargetColumns = nil
        anchorAssetID = nil
        anchorPoint = .zero
    }
}

// MARK: - Pinch Zoom Extension

extension BaseGridViewController {

    // MARK: - Threshold Detection

    /// 열 수 기준점 통과 감지
    /// - 이전 가상 열 수와 현재 가상 열 수를 비교하여 통과한 모든 기준점 반환
    /// - 방향에 따라 순서 정렬: 확대(5→3→1) 또는 축소(1→3→5)
    /// - Parameters:
    ///   - previousColumns: 이전 가상 열 수
    ///   - currentColumns: 현재 가상 열 수
    /// - Returns: 통과한 기준점 배열 (방향에 따라 정렬됨)
    func detectThresholdCrossings(
        previousColumns: CGFloat,
        currentColumns: CGFloat
    ) -> [GridColumnCount] {
        let thresholds: [CGFloat] = [1, 3, 5]
        var crossedThresholds: [GridColumnCount] = []

        for threshold in thresholds {
            // 확대 방향: 이전 > threshold, 현재 <= threshold
            let crossedForward = previousColumns > threshold && currentColumns <= threshold
            // 축소 방향: 이전 < threshold, 현재 >= threshold
            let crossedBackward = previousColumns < threshold && currentColumns >= threshold

            if crossedForward || crossedBackward {
                if let columns = GridColumnCount(rawValue: Int(threshold)) {
                    crossedThresholds.append(columns)
                }
            }
        }

        // 방향에 따라 정렬
        // 확대(열 수 감소): 5→3→1 순서 (큰 것부터)
        // 축소(열 수 증가): 1→3→5 순서 (작은 것부터)
        let isZoomingIn = currentColumns < previousColumns
        if isZoomingIn {
            crossedThresholds.sort { $0.rawValue > $1.rawValue }  // 5, 3, 1
        } else {
            crossedThresholds.sort { $0.rawValue < $1.rawValue }  // 1, 3, 5
        }

        return crossedThresholds
    }

    /// 가상 열 수를 가장 가까운 기준점(1/3/5)으로 스냅
    /// - Parameter virtualColumns: 가상 열 수
    /// - Returns: 스냅된 GridColumnCount
    func snapToNearestColumnCount(_ virtualColumns: CGFloat) -> GridColumnCount {
        // 0~2 → 1열, 2~4 → 3열, 4~ → 5열
        if virtualColumns <= 2 {
            return .one
        } else if virtualColumns <= 4 {
            return .three
        } else {
            return .five
        }
    }

    // MARK: - Helper Functions

    /// 열 수별 썸네일 크기 계산
    /// - Parameter columns: 열 수
    /// - Returns: 픽셀 단위 썸네일 크기
    func thumbnailSize(for columns: GridColumnCount) -> CGSize {
        let spacing = Self.cellSpacing
        let columnCount = CGFloat(columns.rawValue)
        let totalSpacing = spacing * (columnCount - 1)
        let availableWidth = view.bounds.width - totalSpacing
        let cellWidth = floor(availableWidth / columnCount)

        let scale = UIScreen.main.scale
        let pixelSize = cellWidth * scale

        return CGSize(width: pixelSize, height: pixelSize)
    }

    /// 열 수별 paddingCellCount 계산
    /// - Parameter columns: 열 수
    /// - Returns: 상단 패딩 셀 개수
    func paddingCellCount(for columns: GridColumnCount) -> Int {
        let totalCount = gridDataSource.assetCount
        guard totalCount > 0 else { return 0 }
        let columnCount = columns.rawValue
        let remainder = totalCount % columnCount
        return remainder == 0 ? 0 : (columnCount - remainder)
    }

    // MARK: - Fade In Animation

    /// 셀 이미지 fade in 전환
    /// - 이전 이미지 위에 새 이미지를 올리고 fade in
    /// - Parameters:
    ///   - cell: 대상 셀
    ///   - newImage: 새 이미지
    ///   - duration: 애니메이션 시간
    func fadeInNewImage(cell: PhotoCell, newImage: UIImage, duration: TimeInterval = 0.25) {
        let overlayImageView = UIImageView(image: newImage)
        overlayImageView.frame = cell.thumbnailImageView.bounds
        overlayImageView.contentMode = .scaleAspectFill
        overlayImageView.clipsToBounds = true
        overlayImageView.alpha = 0
        cell.contentView.addSubview(overlayImageView)

        UIView.animate(withDuration: duration) {
            overlayImageView.alpha = 1.0
        } completion: { _ in
            cell.thumbnailImageView.image = newImage
            overlayImageView.removeFromSuperview()
        }
    }

    /// visible cells에 새 이미지 fade in (앵커 제외)
    /// - Parameters:
    ///   - targetColumns: 목표 열 수
    ///   - anchorAssetID: 앵커 에셋 ID (fade in 제외 대상)
    func fadeInVisibleCells(
        targetColumns: GridColumnCount,
        anchorAssetID: String?
    ) {
        // 새 열 수 기준 썸네일 크기 계산
        let targetSize = thumbnailSize(for: targetColumns)

        for indexPath in collectionView.indexPathsForVisibleItems {
            guard indexPath.item >= paddingCellCount else { continue }

            // 앵커 셀은 스킵
            let assetID = assetIDForCollectionIndexPath(indexPath)
            if assetID == anchorAssetID { continue }

            // 새 열 수 기준으로 이 위치에 올 에셋 계산
            // (paddingCellCount가 달라지므로 다른 에셋이 올 수 있음)
            let newPaddingCount = paddingCellCount(for: targetColumns)
            let newAssetIndex = indexPath.item - newPaddingCount

            guard newAssetIndex >= 0,
                  let asset = gridDataSource.asset(at: newAssetIndex),
                  let cell = collectionView.cellForItem(at: indexPath) as? PhotoCell else {
                continue
            }

            // 요청 시점의 assetID 캡처 (셀 재사용 검증용)
            let requestedAssetID = asset.localIdentifier

            // 새 이미지 로드 및 fade in
            _ = imagePipeline.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                quality: .fast
            ) { [weak self, weak cell] image, _ in
                // 메인 스레드에서 호출됨
                guard let self = self, let cell = cell, let image = image else { return }

                // 셀 재사용 검증: 셀의 현재 assetID와 요청 시점 assetID 비교
                guard cell.currentAssetID == requestedAssetID else { return }

                self.fadeInNewImage(cell: cell, newImage: image)
            }
        }
    }
}

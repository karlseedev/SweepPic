//
//  MetadataFilter.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  Stage 1: 메타데이터 필터링
//  - PHAsset 메타데이터를 확인하여 분석 대상 여부 판정
//  - Safe Guard 조기 필터: 즐겨찾기, 편집됨, 숨김, 공유앨범
//  - 1차 범위 외: 스크린샷, 10분 초과 비디오
//  - iCloud 전용: 로컬 캐시 없음
//

import Foundation
import Photos

/// 메타데이터 필터
///
/// PHAsset의 메타데이터를 확인하여 분석 대상 여부를 판정합니다.
/// 분석 전 조기 필터링으로 불필요한 이미지 로딩을 방지합니다.
struct MetadataFilter {

    // MARK: - Public Methods

    /// PHAsset이 분석 대상인지 확인
    ///
    /// - Parameter asset: 확인할 PHAsset
    /// - Returns: 분석 대상이면 nil, 제외 대상이면 SkipReason
    ///
    /// - Note: 반환값이 nil이면 분석 진행, SkipReason이면 해당 사유로 SKIP
    func shouldAnalyze(_ asset: PHAsset) -> SkipReason? {
        // Safe Guard 조기 필터 (순서 중요: 가장 일반적인 것부터)

        // 1. 즐겨찾기
        if asset.isFavorite {
            return .favorite
        }

        // 2. 편집됨 (hasAdjustments 체크)
        if asset.hasAdjustments {
            return .edited
        }

        // 3. 숨김
        if asset.isHidden {
            return .hidden
        }

        // 4. 공유 앨범
        if asset.sourceType == .typeCloudShared {
            return .sharedAlbum
        }

        // 1차 범위 외

        // 5. 스크린샷
        if asset.mediaSubtypes.contains(.photoScreenshot) {
            return .screenshot
        }

        // 6. 10분 초과 비디오
        if asset.mediaType == .video && asset.duration > CleanupConstants.longVideoDuration {
            return .longVideo
        }

        // 분석 대상
        return nil
    }

    /// 여러 PHAsset 일괄 필터링
    ///
    /// - Parameter assets: 필터링할 PHAsset 배열
    /// - Returns: (분석 대상 배열, SKIP 결과 배열)
    ///
    /// - Note: 분석 대상은 Stage 2 이상으로 진행, SKIP 결과는 바로 결과 목록에 추가
    func filter(_ assets: [PHAsset]) -> (toAnalyze: [PHAsset], skipped: [QualityResult]) {
        var toAnalyze: [PHAsset] = []
        var skipped: [QualityResult] = []

        for asset in assets {
            if let skipReason = shouldAnalyze(asset) {
                // SKIP 처리
                skipped.append(QualityResult.skipped(
                    assetID: asset.localIdentifier,
                    reason: skipReason
                ))
            } else {
                // 분석 대상
                toAnalyze.append(asset)
            }
        }

        return (toAnalyze, skipped)
    }

    /// 스트림 방식 필터링 (AsyncSequence용)
    ///
    /// - Parameters:
    ///   - asset: 확인할 PHAsset
    ///   - onSkip: SKIP 시 호출되는 클로저
    /// - Returns: 분석 대상이면 true, SKIP이면 false
    func filter(
        _ asset: PHAsset,
        onSkip: (QualityResult) -> Void
    ) -> Bool {
        if let skipReason = shouldAnalyze(asset) {
            onSkip(QualityResult.skipped(
                assetID: asset.localIdentifier,
                reason: skipReason
            ))
            return false
        }
        return true
    }
}

// MARK: - PHAsset Extension

extension PHAsset {

    /// 수정된 사진인지 확인
    ///
    /// PHAsset.hasAdjustments는 비동기 메서드가 따로 있지만,
    /// 간단한 체크를 위해 adjustmentFormatIdentifier 존재 여부로 판단.
    ///
    /// - Note: iOS 8+에서 편집된 사진은 adjustmentData가 존재함
    var hasAdjustments: Bool {
        // PHAssetResource에서 adjustmentData 존재 여부 확인
        let resources = PHAssetResource.assetResources(for: self)
        return resources.contains { $0.type == .adjustmentData }
    }
}

// MARK: - Debug Support

#if DEBUG
extension MetadataFilter {

    /// 디버그용: 필터 결과 상세 출력
    func debugFilter(_ asset: PHAsset) -> String {
        let skipReason = shouldAnalyze(asset)

        var info: [String] = [
            "ID: \(asset.localIdentifier.prefix(8))...",
            "Type: \(asset.mediaType == .image ? "Photo" : "Video")"
        ]

        if asset.isFavorite { info.append("Favorite") }
        if asset.hasAdjustments { info.append("Edited") }
        if asset.isHidden { info.append("Hidden") }
        if asset.sourceType == .typeCloudShared { info.append("SharedAlbum") }
        if asset.mediaSubtypes.contains(.photoScreenshot) { info.append("Screenshot") }
        if asset.mediaType == .video {
            info.append("Duration: \(String(format: "%.1f", asset.duration))s")
        }

        let result = skipReason.map { "SKIP (\($0.rawValue))" } ?? "ANALYZE"

        return "[\(result)] " + info.joined(separator: " | ")
    }
}
#endif

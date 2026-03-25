//
//  PHAsset+Cleanup.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  PHAsset 확장: 자동 정리 기능 지원
//  - shouldSkipForCleanup: Safe Guard 조기 필터 조건
//  - isLowResolution: 저해상도 여부
//  - isLongVideo: 긴 비디오 여부
//  - 기타 정리 관련 유틸리티
//

import Photos

// MARK: - Safe Guard 조기 필터

extension PHAsset {

    /// Safe Guard 조기 필터 조건 확인
    ///
    /// Stage 1 메타데이터 필터에서 분석을 건너뛰어야 하는 사진인지 확인.
    /// 아래 조건 중 하나라도 해당하면 분석 건너뜀:
    /// - 즐겨찾기
    /// - 편집됨
    /// - 숨김
    /// - 스크린샷
    ///
    /// - Returns: 분석을 건너뛰어야 하면 true
    var shouldSkipForCleanup: Bool {
        // 즐겨찾기
        if isFavorite { return true }

        // 편집됨 (hasAdjustments는 별도 체크 필요할 수 있음)
        // PHAsset의 hasAdjustments는 버전 차이가 있어 mediaSubtypes로 체크
        // 실제 편집 여부는 PHAssetResource로 확인해야 더 정확함

        // 숨김
        if isHidden { return true }

        // 스크린샷
        if mediaSubtypes.contains(.photoScreenshot) { return true }

        return false
    }

    /// 분석 건너뛰어야 하는 사유 반환
    ///
    /// shouldSkipForCleanup이 true인 경우 그 사유를 반환.
    ///
    /// - Returns: 건너뜀 사유 (건너뛸 필요 없으면 nil)
    var skipReason: SkipReason? {
        if isFavorite { return .favorite }
        if isHidden { return .hidden }
        if mediaSubtypes.contains(.photoScreenshot) { return .screenshot }
        return nil
    }

    /// 공유 앨범 사진인지 확인
    ///
    /// sourceType이 .typeCloudShared인 경우 공유 앨범 사진.
    /// 공유 앨범 사진은 분석에서 제외.
    ///
    /// - Returns: 공유 앨범 사진이면 true
    var isFromSharedAlbum: Bool {
        return sourceType == .typeCloudShared
    }
}

// MARK: - 해상도 및 길이 체크

extension PHAsset {

    /// 저해상도 여부 확인
    ///
    /// 1MP(1,000,000 픽셀) 미만이면 저해상도.
    /// Recall 모드에서 Weak 신호로 사용.
    ///
    /// - Returns: 저해상도이면 true
    var isLowResolution: Bool {
        return pixelWidth * pixelHeight < CleanupConstants.lowResolutionPixelCount
    }

    /// 분석 제외 대상 비디오 여부 확인
    ///
    /// 5초 초과 비디오는 의도적 촬영으로 간주하여 분석에서 제외.
    ///
    /// - Returns: 5초 초과 비디오면 true
    var isLongVideo: Bool {
        guard mediaType == .video else { return false }
        return duration > CleanupConstants.maxAnalyzableVideoDuration
    }

    /// 분석 가능한 비디오인지 확인
    ///
    /// - 비디오 타입이어야 함
    /// - 5초 이하여야 함 (주머니샷 등 실수 촬영 대상)
    ///
    /// - Returns: 분석 가능한 비디오면 true
    var isAnalyzableVideo: Bool {
        return mediaType == .video && !isLongVideo
    }

    /// 픽셀 수 반환
    var pixelCount: Int {
        return pixelWidth * pixelHeight
    }

    /// 메가픽셀 반환 (소수점 1자리)
    var megapixels: Double {
        return Double(pixelCount) / 1_000_000.0
    }
}

// MARK: - 미디어 타입 확인

extension PHAsset {

    /// Live Photo 여부 확인
    var isLivePhoto: Bool {
        return mediaSubtypes.contains(.photoLive)
    }

    /// Burst 사진 여부 확인
    ///
    /// burstIdentifier가 있으면 Burst 그룹의 일부.
    /// representsBurst가 true면 대표 사진.
    var isBurstPhoto: Bool {
        return burstIdentifier != nil
    }

    /// Burst 대표 사진 여부 확인
    ///
    /// PHFetchResult 기본 동작으로 대표 사진만 반환됨.
    var isBurstRepresentative: Bool {
        return representsBurst
    }

    /// HDR 사진 여부 확인
    var isHDRPhoto: Bool {
        return mediaSubtypes.contains(.photoHDR)
    }

    /// 파노라마 사진 여부 확인
    var isPanoramaPhoto: Bool {
        return mediaSubtypes.contains(.photoPanorama)
    }

    /// Portrait 모드 사진 여부 확인 (심도 효과)
    var isPortraitPhoto: Bool {
        return mediaSubtypes.contains(.photoDepthEffect)
    }
}

// MARK: - 연도 관련

extension PHAsset {

    /// 생성 연도 반환
    ///
    /// creationDate를 기기 현지 타임존으로 변환하여 연도 추출.
    ///
    /// - Returns: 연도 (예: 2024), creationDate가 nil이면 nil
    var creationYear: Int? {
        guard let date = creationDate else { return nil }
        let calendar = Calendar.current
        return calendar.component(.year, from: date)
    }

    /// 특정 연도에 생성된 사진인지 확인
    ///
    /// - Parameter year: 확인할 연도
    /// - Returns: 해당 연도에 생성되었으면 true
    func wasCreatedIn(year: Int) -> Bool {
        return creationYear == year
    }

    /// 특정 날짜 이전에 생성된 사진인지 확인
    ///
    /// - Parameter date: 기준 날짜
    /// - Returns: 기준 날짜 이전이면 true
    func wasCreatedBefore(_ date: Date) -> Bool {
        guard let creationDate = creationDate else { return false }
        return creationDate < date
    }
}


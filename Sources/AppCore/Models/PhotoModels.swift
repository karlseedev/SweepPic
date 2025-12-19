// PhotoModels.swift
// 사진 관련 핵심 데이터 모델
//
// T007: MediaType enum (photo/video/livePhoto)
// T008: PhotoAssetEntry 구조체

import Foundation

// MARK: - MediaType (T007)

/// 미디어 타입 열거형
/// PhotoKit의 PHAssetMediaType을 앱 내부 표현으로 매핑
public enum MediaType: String, Codable, Sendable {
    /// 일반 사진 (JPEG, HEIC 등)
    case photo

    /// 비디오 (MOV, MP4 등)
    case video

    /// 라이브 포토 (사진 + 짧은 비디오)
    case livePhoto
}

// MARK: - PhotoAssetEntry (T008)

/// 사진 에셋 엔트리
/// PhotoKit의 PHAsset을 앱 내부에서 사용하기 위한 래퍼 구조체
///
/// - Note: isTrashed 속성은 TrashStore에서 계산됨 (직접 저장하지 않음)
public struct PhotoAssetEntry: Identifiable, Hashable, Sendable {

    // MARK: - Properties

    /// 고유 식별자 (PHAsset.localIdentifier)
    /// PhotoKit에서 사진을 고유하게 식별하는 문자열
    public let localIdentifier: String

    /// 생성 날짜
    /// 사진이 촬영된 날짜 (메타데이터가 없으면 nil)
    public let creationDate: Date?

    /// 미디어 타입 (photo/video/livePhoto)
    public let mediaType: MediaType

    /// 픽셀 너비
    public let pixelWidth: Int

    /// 픽셀 높이
    public let pixelHeight: Int

    // MARK: - Identifiable

    /// Identifiable 프로토콜 준수를 위한 id
    public var id: String { localIdentifier }

    // MARK: - Computed Properties

    /// 가로/세로 비율
    public var aspectRatio: CGFloat {
        guard pixelHeight > 0 else { return 1.0 }
        return CGFloat(pixelWidth) / CGFloat(pixelHeight)
    }

    /// 가로 방향인지 여부
    public var isLandscape: Bool {
        pixelWidth > pixelHeight
    }

    /// 세로 방향인지 여부
    public var isPortrait: Bool {
        pixelHeight > pixelWidth
    }

    // MARK: - Initialization

    /// PhotoAssetEntry 초기화
    /// - Parameters:
    ///   - localIdentifier: PHAsset의 localIdentifier
    ///   - creationDate: 생성 날짜 (옵션)
    ///   - mediaType: 미디어 타입
    ///   - pixelWidth: 픽셀 너비
    ///   - pixelHeight: 픽셀 높이
    public init(
        localIdentifier: String,
        creationDate: Date?,
        mediaType: MediaType,
        pixelWidth: Int,
        pixelHeight: Int
    ) {
        self.localIdentifier = localIdentifier
        self.creationDate = creationDate
        self.mediaType = mediaType
        self.pixelWidth = pixelWidth
        self.pixelHeight = pixelHeight
    }
}

// MARK: - CustomStringConvertible

extension PhotoAssetEntry: CustomStringConvertible {
    public var description: String {
        "PhotoAssetEntry(id: \(localIdentifier.prefix(8))..., type: \(mediaType), size: \(pixelWidth)x\(pixelHeight))"
    }
}

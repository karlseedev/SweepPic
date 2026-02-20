// AnalyticsError.swift
// 오류 분석 이벤트의 카테고리별 enum 정의
//
// - 5카테고리 13항목을 중첩 enum으로 구성
// - rawValue가 "category.item" 형식으로 세션 요약 시 오류 키로 사용
// - 참조: docs/db/260212db-Archi.md 섹션 5.2, 4.2

import Foundation

// MARK: - AnalyticsError

/// 분석용 오류 카테고리 네임스페이스
/// - 각 카테고리는 중첩 enum으로 정의
/// - rawValue는 "category.item" 형식 (TelemetryDeck 파라미터 키로 사용)
enum AnalyticsError {

    // MARK: - 사진 로딩

    /// 사진 로딩 관련 오류 (3항목)
    enum PhotoLoad: String {
        /// 그리드 썸네일 로딩 실패
        case gridThumbnail  = "photoLoad.gridThumbnail"
        /// 뷰어 원본 이미지 로딩 실패
        case viewerOriginal = "photoLoad.viewerOriginal"
        /// iCloud 다운로드 실패
        case iCloudDownload = "photoLoad.iCloudDownload"
    }

    // MARK: - 얼굴 감지

    /// 얼굴 감지 관련 오류 (2항목)
    enum Face: String {
        /// 얼굴 감지 실패
        case detection = "face.detection"
        /// 얼굴 임베딩 생성 실패
        case embedding = "face.embedding"
    }

    // MARK: - 정리

    /// 정리 기능 관련 오류 (3항목)
    enum Cleanup: String {
        /// 정리 시작 실패
        case startFail  = "cleanup.startFail"
        /// 정리 중 이미지 로드 실패
        case imageLoad  = "cleanup.imageLoad"
        /// 삭제대기함 이동 실패
        case trashMove  = "cleanup.trashMove"
    }

    // MARK: - 동영상

    /// 동영상 관련 오류 (2항목)
    enum Video: String {
        /// 프레임 추출 실패
        case frameExtract = "video.frameExtract"
        /// iCloud 동영상 스킵
        case iCloudSkip   = "video.iCloudSkip"
    }

    // MARK: - 캐시/저장

    /// 캐시 및 저장 관련 오류 (3항목)
    enum Storage: String {
        /// 디스크 공간 부족
        case diskSpace      = "storage.diskSpace"
        /// 썸네일 캐시 쓰기 실패
        case thumbnailCache = "storage.thumbnailCache"
        /// 삭제대기함 데이터 저장 실패
        case trashData      = "storage.trashData"
    }
}

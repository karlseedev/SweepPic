// AppCore.swift
// PickPhoto MVP의 핵심 비즈니스 로직을 담당하는 모듈
//
// 구조:
// - Models/: 데이터 모델 (PhotoAssetEntry, Album, TrashState 등)
// - Services/: 서비스 레이어 (PhotoLibraryService, ImagePipeline 등)
// - Stores/: 상태 관리 (TrashStore, PermissionStore 등)

import Foundation

/// AppCore 모듈 버전 정보
public enum AppCore {
    /// 현재 버전
    public static let version = "1.0.0"

    /// 최소 지원 iOS 버전
    public static let minimumIOSVersion = "16.0"
}

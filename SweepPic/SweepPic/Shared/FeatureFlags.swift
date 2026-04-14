//
//  FeatureFlags.swift
//  SweepPic
//
//  Created by Claude Code on 2026-01-05.
//
//  Feature Flag 관리 클래스
//  개발 중인 기능을 on/off 할 수 있도록 중앙 집중식 관리 제공
//

import Foundation
import Photos
import UIKit

// MARK: - FeatureFlags

/// 앱 전체 기능 플래그를 관리하는 열거형
/// 개발 중인 기능을 쉽게 활성화/비활성화할 수 있음
/// 버그 발생 시 한 줄 수정으로 롤백 가능
enum FeatureFlags {

    // MARK: - Similar Photo Feature

    /// 유사 사진 정리 기능 활성화 여부
    /// - 개발 중: true로 설정
    /// - 버그 발생 시: false로 롤백
    /// - 단계적 배포: 베타 사용자만 활성화 가능
    ///
    /// ## 비활성화 조건
    /// - `isSimilarPhotoEnabledRaw`가 false인 경우
    /// - PHPhotoLibrary 권한이 거부/제한된 경우
    /// - VoiceOver가 활성화된 경우 (시각 기반 기능이므로)
    ///
    /// ## 사용 예시
    /// ```swift
    /// guard FeatureFlags.isSimilarPhotoEnabled else { return }
    /// // 유사 사진 기능 실행
    /// ```
    static var isSimilarPhotoEnabled: Bool {
        // 1. 기본 플래그 체크
        guard isSimilarPhotoEnabledRaw else {
            return false
        }

        // 2. 사진 라이브러리 권한 체크
        // 권한이 없으면 유사 사진 분석이 불가능
        guard isPhotoLibraryAccessGranted else {
            return false
        }

        // 3. VoiceOver 활성화 체크
        // 유사 사진 기능은 시각 기반 기능이므로 VoiceOver 사용자에게 실질적 가치 없음
        guard !UIAccessibility.isVoiceOverRunning else {
            return false
        }

        return true
    }

    /// 유사 사진 기능 기본 플래그 (순수 on/off)
    /// 위의 조건부 검사 없이 단순 활성화 여부만 체크할 때 사용
    /// 개발/테스트 시 이 값을 false로 변경하여 기능 비활성화
    static var isSimilarPhotoEnabledRaw: Bool = true

    // MARK: - Photo Library Permission

    /// PHPhotoLibrary 접근 권한 상태 확인
    /// - authorized, limited: 접근 가능 (true)
    /// - denied, restricted, notDetermined: 접근 불가 (false)
    ///
    /// ## 주의사항
    /// - 이 프로퍼티는 권한 요청을 트리거하지 않음
    /// - 권한 요청은 기존 앱의 권한 요청 UI 플로우를 따름
    private static var isPhotoLibraryAccessGranted: Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        switch status {
        case .authorized, .limited:
            return true
        case .denied, .restricted, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    // MARK: - BM Monetization Feature Flags

    /// 게이트 기능 활성화 여부
    /// 한도 초과 시 게이트 팝업 표시를 제어
    /// 긴급 비활성화 시 false로 변경 → 모든 삭제가 게이트 없이 진행
    static var isGateEnabled: Bool = true

    /// 광고 기능 활성화 여부
    /// 리워드/전면/배너 광고 전체를 on/off
    /// false 시 광고 미표시 + 리워드 비활성
    static var isAdEnabled: Bool = true

    /// 구독 기능 활성화 여부
    /// 페이월/구독 관리 UI 표시를 제어
    /// false 시 페이월 진입 불가 + Pro 전환 불가
    static var isSubscriptionEnabled: Bool = true

    // MARK: - Debug Helpers

    #if DEBUG
    /// 디버그 빌드에서 기능 상태 로깅
    /// 개발 시 현재 기능 플래그 상태를 확인할 때 사용
    static func logFeatureStatus() {
        print("""
        [FeatureFlags] Status:
          - isSimilarPhotoEnabled: \(isSimilarPhotoEnabled)
          - isSimilarPhotoEnabledRaw: \(isSimilarPhotoEnabledRaw)
          - isPhotoLibraryAccessGranted: \(isPhotoLibraryAccessGranted)
          - isVoiceOverRunning: \(UIAccessibility.isVoiceOverRunning)
          - isGateEnabled: \(isGateEnabled)
          - isAdEnabled: \(isAdEnabled)
          - isSubscriptionEnabled: \(isSubscriptionEnabled)
        """)
    }
    #endif
}

//
//  VisionFallbackMode.swift
//  PickPhoto
//
//  Created on 2026-01-17.
//
//  Vision Fallback 모드 정의
//  YuNet이 놓친 얼굴을 Vision 결과로 보완하는 정도를 제어합니다.
//

import Foundation

/// Vision Fallback 모드
///
/// YuNet이 놓친 얼굴을 Vision 결과로 보완하는 정도를 제어합니다.
///
/// ## 모드 설명
/// - `off`: Fallback 없음 - YuNet 결과만 사용
/// - `basic`: 기본 Fallback - YuNet=0일 때만 Vision 사용
/// - `extended`: 확장 Fallback - YuNet이 놓친 작은 얼굴도 Vision으로 보완
///
/// ## 사용 예시
/// ```swift
/// // Production (기본값)
/// assignPersonIndicesForGroup(..., visionFallbackMode: .basic)
///
/// // Extended 테스트
/// assignPersonIndicesForGroup(..., visionFallbackMode: .extended)
/// ```
enum VisionFallbackMode {
    /// Fallback 없음 - YuNet 결과만 사용
    case off

    /// 기본 Fallback - YuNet=0일 때만 Vision 사용
    /// - YuNet이 아무 얼굴도 감지하지 못했을 때 Vision rawFacesMap 사용
    /// - 위치 정보만 사용 (임베딩 없음)
    /// - Step 7에서 posNorm < 0.10 조건으로 기존 슬롯에 매칭
    case basic

    /// 확장 Fallback - YuNet이 놓친 작은 얼굴도 Vision으로 보완
    /// - YuNet > 0이어도 Vision이 더 많이 감지하면 누락 얼굴 추가
    /// - IoU < 0.3이고 작은 얼굴(width < 0.07)만 추가 (FP 방지)
    /// - YuNet이 놓치기 쉬운 작은 얼굴을 보완하는 목적
    case extended
}

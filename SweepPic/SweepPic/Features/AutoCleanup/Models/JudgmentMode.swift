//
//  JudgmentMode.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  판별 모드 정의
//  - precision: 신중한 정리 (Strong 신호만, 오탐지 최소화)
//  - recall: 적극적 정리 (Strong + Conditional + Weak, 커버리지 최대화)
//
//  1차 출시에서는 precision 모드만 사용.
//  recall 모드는 추후 업데이트에서 추가 예정.
//

import Foundation

/// 판별 모드
///
/// 저품질 사진 판정 기준의 엄격함을 결정.
/// - precision: 오탐지 최소화 (확실한 저품질만 정리)
/// - recall: 커버리지 최대화 (더 많은 저품질 사진 탐지)
enum JudgmentMode: String, Codable, CaseIterable {

    /// 신중한 정리 (Precision 모드)
    /// - Strong 신호만 사용
    /// - 임계값: 엄격 (휘도 < 0.10, Laplacian < 50)
    /// - 목표: 오탐률 5% 이하, 탐지율 60% 이상
    case precision

    /// 적극적 정리 (Recall 모드) - 추후 추가 예정
    /// - Strong + Conditional + Weak 신호 사용
    /// - 임계값: 완화 (휘도 < 0.15, Laplacian < 100)
    /// - Weak 신호 가중치 합산 >= 3 → 저품질
    /// - 목표: 오탐률 20% 이하, 탐지율 85% 이상
    case recall
}

// MARK: - CustomStringConvertible

extension JudgmentMode: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        switch self {
        case .precision:
            return "Precision (신중한 정리)"
        case .recall:
            return "Recall (적극적 정리)"
        }
    }
}

// MARK: - UI 지원

extension JudgmentMode {

    /// UI에 표시할 제목
    var displayTitle: String {
        switch self {
        case .precision:
            return "신중한 정리"
        case .recall:
            return "적극적 정리"
        }
    }

    /// UI에 표시할 설명
    var displayDescription: String {
        switch self {
        case .precision:
            return "확실한 저품질 사진만 정리합니다"
        case .recall:
            return "더 많은 저품질 사진을 찾아 정리합니다"
        }
    }

    /// 기본 모드
    /// - 1차 출시에서는 precision만 사용
    static var `default`: JudgmentMode {
        return .precision
    }
}

// MARK: - 임계값 지원

extension JudgmentMode {

    /// 해당 모드에서 극단 어두움 휘도 임계값
    var extremeDarkLuminance: Double {
        switch self {
        case .precision:
            return CleanupConstants.extremeDarkLuminance  // 0.10
        case .recall:
            return CleanupConstants.generalDarkLuminance  // 0.15
        }
    }

    /// 해당 모드에서 극단 밝음 휘도 임계값
    var extremeBrightLuminance: Double {
        switch self {
        case .precision:
            return CleanupConstants.extremeBrightLuminance  // 0.90
        case .recall:
            return CleanupConstants.generalBrightLuminance  // 0.85
        }
    }

    /// 해당 모드에서 심각 블러 Laplacian 임계값
    var severeBlurLaplacian: Double {
        switch self {
        case .precision:
            return CleanupConstants.severeBlurLaplacian  // 50
        case .recall:
            return CleanupConstants.generalBlurLaplacian  // 100
        }
    }

    /// 해당 모드에서 AestheticsScore 임계값 (iOS 18+)
    var aestheticsThreshold: Float {
        switch self {
        case .precision:
            return CleanupConstants.aestheticsPrecisionThreshold  // -0.3
        case .recall:
            return CleanupConstants.aestheticsRecallThreshold  // 0.0
        }
    }

    /// Conditional 신호 사용 여부
    var usesConditionalSignals: Bool {
        switch self {
        case .precision:
            return false
        case .recall:
            return true
        }
    }

    /// Weak 신호 사용 여부
    var usesWeakSignals: Bool {
        switch self {
        case .precision:
            return false
        case .recall:
            return true
        }
    }
}

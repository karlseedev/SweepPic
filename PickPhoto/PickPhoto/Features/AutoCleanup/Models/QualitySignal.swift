//
//  QualitySignal.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-22.
//
//  품질 판정 신호 정의
//  - SignalType: Strong/Conditional/Weak
//  - SignalKind: 구체적인 저품질 원인
//  - QualitySignal: 측정값과 임계값을 포함한 신호 데이터
//

import Foundation

// MARK: - SignalType

/// 신호 타입
///
/// 저품질 판정 신호의 강도를 나타냄.
/// - strong: 단일 조건으로 즉시 저품질 확정
/// - conditional: 기술적 실패지만 오탐 위험 (Recall 모드에서만)
/// - weak: 가중치 합산용 (Recall 모드에서만)
enum SignalType: Equatable {

    /// Strong 신호
    /// - 단일 조건으로 즉시 저품질 확정
    /// - Precision/Recall 모든 모드에서 사용
    /// - 예: 극단 노출, 심각 블러
    case strong

    /// Conditional 신호
    /// - 기술적 실패지만 오탐 위험 있음
    /// - Recall 모드에서만 사용
    /// - 예: 주머니 샷, 극단 단색, 렌즈 가림
    case conditional

    /// Weak 신호
    /// - 가중치 합산용 (합산 >= 3 → 저품질)
    /// - Recall 모드에서만 사용
    /// - weight: 가중치 (일반 블러 = 2, 기타 = 1)
    case weak(weight: Int)

    /// Weak 신호인 경우 가중치 반환
    var weight: Int {
        if case .weak(let w) = self {
            return w
        }
        return 0
    }
}

// MARK: - SignalKind

/// 신호 종류
///
/// 저품질 판정의 구체적인 원인.
/// 각 신호는 특정 임계값과 연관됨.
enum SignalKind: String, Codable, CaseIterable {

    // MARK: Strong 신호

    /// 극단 어두움
    /// - 조건: 휘도 < 0.10 (Precision)
    /// - 타입: Strong (즉시 저품질)
    case extremeDark

    /// 극단 밝음
    /// - 조건: 휘도 > 0.90 (Precision)
    /// - 타입: Strong (즉시 저품질)
    case extremeBright

    /// 심각 블러
    /// - 조건: Laplacian Variance < 50 (Precision)
    /// - 타입: Strong (Safe Guard 체크 필요)
    case severeBlur

    /// 너무 짧은 동영상
    /// - 조건: duration < 1초
    /// - 타입: Strong (분석 없이 저품질 확정)
    /// - 근거: 1초 미만 동영상은 거의 확실히 실수 촬영
    case tooShortVideo

    // MARK: Conditional 신호 (Recall only)

    /// 주머니 샷
    /// - 조건: 휘도 < 0.15 AND RGB Std < 15 AND Lap < 50 AND 비네팅 < 0.05
    /// - 타입: Conditional (Recall 모드에서만)
    case pocketShot

    /// 극단 단색
    /// - 조건: RGB Std < 10 AND (휘도 < 0.15 OR 휘도 > 0.85)
    /// - 타입: Conditional (Recall 모드에서만)
    case extremeMonochrome

    /// 렌즈 가림
    /// - 조건: 모서리 휘도 < 중앙 휘도 × 0.4
    /// - 타입: Conditional (Recall 모드에서만)
    case lensBlocked

    // MARK: Weak 신호 (Recall only)

    /// 일반 블러
    /// - 조건: Laplacian Variance < 100 (Recall)
    /// - 타입: Weak (가중치 2점)
    case generalBlur

    /// 일반 노출
    /// - 조건: 휘도 < 0.15 OR 휘도 > 0.85 (Recall)
    /// - 타입: Weak (가중치 1점)
    case generalExposure

    /// 낮은 색상 다양성
    /// - 조건: RGB Std < 15
    /// - 타입: Weak (가중치 1점)
    case lowColorVariety

    /// 저해상도
    /// - 조건: < 1MP (1,000,000 픽셀)
    /// - 타입: Weak (가중치 1점)
    case lowResolution

    // MARK: iOS 18+ AestheticsScore

    /// 낮은 미적 점수
    /// - 조건: overallScore < -0.3 (Precision) 또는 < 0 (Recall)
    /// - iOS 18+ 전용
    case lowAesthetics

    // MARK: - 신호 타입

    /// 해당 신호의 타입
    var signalType: SignalType {
        switch self {
        // Strong
        case .extremeDark, .extremeBright, .severeBlur, .tooShortVideo, .lowAesthetics:
            return .strong
        // Conditional
        case .pocketShot, .extremeMonochrome, .lensBlocked:
            return .conditional
        // Weak
        case .generalBlur:
            return .weak(weight: CleanupConstants.generalBlurWeight)  // 2점
        case .generalExposure, .lowColorVariety, .lowResolution:
            return .weak(weight: CleanupConstants.otherWeakWeight)    // 1점
        }
    }

    /// Precision 모드에서 사용 가능한 신호인지
    var isUsedInPrecision: Bool {
        switch self {
        case .extremeDark, .extremeBright, .severeBlur, .tooShortVideo, .lowAesthetics:
            return true
        default:
            return false
        }
    }
}

// MARK: - QualitySignal

/// 품질 판정 신호
///
/// 분석 결과로 감지된 저품질 신호.
/// 측정값과 임계값을 포함하여 디버깅/로깅에 활용.
struct QualitySignal: Equatable {

    /// 신호 타입 (Strong/Conditional/Weak)
    let type: SignalType

    /// 신호 종류 (구체적인 저품질 원인)
    let kind: SignalKind

    /// 측정된 값
    /// - 예: 휘도 0.05, Laplacian 30.5
    let measuredValue: Double

    /// 사용된 임계값
    /// - 예: 휘도 임계값 0.10, Laplacian 임계값 50
    let threshold: Double

    // MARK: - Initializer

    /// 신호 생성
    /// - Parameters:
    ///   - kind: 신호 종류
    ///   - measuredValue: 측정된 값
    ///   - threshold: 사용된 임계값
    init(kind: SignalKind, measuredValue: Double, threshold: Double) {
        self.type = kind.signalType
        self.kind = kind
        self.measuredValue = measuredValue
        self.threshold = threshold
    }
}

// MARK: - CustomStringConvertible

extension QualitySignal: CustomStringConvertible {

    /// 디버그/로깅용 문자열 표현
    var description: String {
        let typeStr: String
        switch type {
        case .strong:
            typeStr = "Strong"
        case .conditional:
            typeStr = "Conditional"
        case .weak(let weight):
            typeStr = "Weak(\(weight))"
        }
        return "[\(typeStr)] \(kind.rawValue): \(String(format: "%.3f", measuredValue)) (threshold: \(String(format: "%.3f", threshold)))"
    }
}

// MARK: - 신호 배열 확장

extension Array where Element == QualitySignal {

    /// Strong 신호가 있는지 확인
    var hasStrongSignal: Bool {
        return contains { $0.type == .strong }
    }

    /// Conditional 신호가 있는지 확인
    var hasConditionalSignal: Bool {
        return contains { $0.type == .conditional }
    }

    /// Weak 신호 가중치 합산
    var weakWeightSum: Int {
        return reduce(0) { sum, signal in
            if case .weak(let weight) = signal.type {
                return sum + weight
            }
            return sum
        }
    }

    /// Weak 신호 합산이 임계값 이상인지 확인
    var hasEnoughWeakSignals: Bool {
        return weakWeightSum >= CleanupConstants.weakSumThreshold
    }
}

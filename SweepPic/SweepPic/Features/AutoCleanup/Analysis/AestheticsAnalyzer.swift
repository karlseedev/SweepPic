//
//  AestheticsAnalyzer.swift
//  SweepPic
//
//  Created by Claude on 2026-01-22.
//
//  iOS 18+ AestheticsScore 분석기
//  - CalculateImageAestheticsScoresRequest 사용
//  - overallScore 기반 저품질 판정
//  - isUtility 플래그로 스크린샷/유틸리티 이미지 제외
//

import Foundation
import Vision

/// AestheticsScore 분석 결과
@available(iOS 18.0, *)
struct AestheticsMetrics: Equatable {

    /// 전체 미적 점수 (-1.0 ~ 1.0)
    let overallScore: Float

    /// 유틸리티 이미지 여부 (스크린샷, 문서 등)
    let isUtility: Bool

    /// 분석 성공 여부
    let isValid: Bool
}

/// iOS 18+ AestheticsScore 분석기
///
/// Apple의 CalculateImageAestheticsScoresRequest를 사용하여
/// 이미지의 미적 점수를 분석합니다.
@available(iOS 18.0, *)
final class AestheticsAnalyzer {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = AestheticsAnalyzer()

    // MARK: - Properties

    /// Precision 모드 임계값
    private let precisionThreshold: Float

    /// Recall 모드 임계값
    private let recallThreshold: Float

    // MARK: - Initialization

    /// 분석기 초기화
    /// - Parameters:
    ///   - precisionThreshold: Precision 모드 임계값 (기본값: -0.3)
    ///   - recallThreshold: Recall 모드 임계값 (기본값: 0.0)
    init(
        precisionThreshold: Float = CleanupConstants.aestheticsPrecisionThreshold,
        recallThreshold: Float = CleanupConstants.aestheticsRecallThreshold
    ) {
        self.precisionThreshold = precisionThreshold
        self.recallThreshold = recallThreshold
    }

    // MARK: - Public Methods

    /// 이미지 미적 점수 분석
    ///
    /// - Parameter image: 분석할 CGImage
    /// - Returns: AestheticsScore 분석 결과
    /// - Throws: Vision API 실패 시 에러
    func analyze(_ image: CGImage) async throws -> AestheticsMetrics {
        // CalculateImageAestheticsScoresRequest 생성
        let request = CalculateImageAestheticsScoresRequest()

        // 요청 수행 (Swift Concurrency 방식)
        do {
            let observation = try await request.perform(on: image)

            return AestheticsMetrics(
                overallScore: observation.overallScore,
                isUtility: observation.isUtility,
                isValid: true
            )
        } catch {
            throw AnalysisError.aestheticsFailed
        }
    }

    /// 품질 신호 생성
    ///
    /// - Parameters:
    ///   - metrics: AestheticsScore 분석 결과
    ///   - mode: 판정 모드 (Precision/Recall)
    /// - Returns: 감지된 품질 신호 배열
    func detectSignals(from metrics: AestheticsMetrics, mode: JudgmentMode) -> [QualitySignal] {
        var signals: [QualitySignal] = []

        // 유효하지 않은 결과는 신호 없음
        guard metrics.isValid else { return signals }

        // 모드별 임계값
        let threshold: Float
        switch mode {
        case .precision:
            threshold = precisionThreshold
        case .recall:
            threshold = recallThreshold
        }

        // 낮은 미적 점수 → Strong 신호
        if metrics.overallScore < threshold {
            signals.append(QualitySignal(
                kind: .lowAesthetics,
                measuredValue: Double(metrics.overallScore),
                threshold: Double(threshold)
            ))
        }

        return signals
    }

    /// isUtility 기반 Skip 여부 확인
    ///
    /// - Parameter metrics: AestheticsScore 분석 결과
    /// - Returns: isUtility가 true이면 SkipReason, 아니면 nil
    func shouldSkip(from metrics: AestheticsMetrics) -> SkipReason? {
        if metrics.isUtility {
            return .utilityImage
        }
        return nil
    }
}


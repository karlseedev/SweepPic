//
//  SimilarityAnalyzer.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  Vision Framework를 사용한 이미지 유사도 분석기입니다.
//  VNGenerateImageFeaturePrintRequest를 활용하여 이미지 간 유사도를 측정합니다.
//
//  Threshold:
//  - 거리 <= 10.0: 유사한 이미지
//  - 거리 > 10.0: 다른 이미지
//
//  Note: 순수 계산만 담당하며, 로딩/큐 제어는 SimilarityAnalysisQueue에서 처리합니다.
//

import Foundation
import AppCore
import Vision
import CoreGraphics

/// 유사도 분석 에러
enum SimilarityAnalysisError: Error, LocalizedError {
    /// Feature Print 생성 실패
    case featurePrintGenerationFailed(String)

    /// 거리 계산 실패
    case distanceCalculationFailed(String)

    /// 비교 불가능한 Feature Print
    case incompatibleFeaturePrints

    /// 분석 요청 취소됨
    case cancelled

    var errorDescription: String? {
        switch self {
        case .featurePrintGenerationFailed(let reason):
            return "Feature Print 생성 실패: \(reason)"
        case .distanceCalculationFailed(let reason):
            return "거리 계산 실패: \(reason)"
        case .incompatibleFeaturePrints:
            return "비교 불가능한 Feature Print"
        case .cancelled:
            return "분석이 취소되었습니다"
        }
    }
}

/// Vision Framework 기반 이미지 유사도 분석기
///
/// VNGenerateImageFeaturePrintRequest를 사용하여 이미지의 특징을 추출하고,
/// 두 이미지 간의 유사도를 거리로 계산합니다.
///
/// - Important: 이 클래스는 순수 계산만 담당합니다.
///   이미지 로딩이나 병렬 처리는 호출자(SimilarityAnalysisQueue)가 관리합니다.
final class SimilarityAnalyzer {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SimilarityAnalyzer()

    // MARK: - Properties

    /// 유사도 임계값
    /// - 거리가 이 값 이하이면 "유사한" 것으로 판정
    private let similarityThreshold: Float

    // MARK: - Initialization

    /// 분석기를 초기화합니다.
    ///
    /// - Parameter threshold: 유사도 임계값 (기본값: 10.0)
    init(threshold: Float = SimilarityConstants.similarityThreshold) {
        self.similarityThreshold = threshold
    }

    // MARK: - Feature Print Generation

    /// 이미지의 Feature Print를 생성합니다.
    ///
    /// Vision의 VNGenerateImageFeaturePrintRequest를 사용하여
    /// 이미지의 특징 벡터를 추출합니다.
    ///
    /// - Parameter image: 분석할 CGImage
    /// - Returns: VNFeaturePrintObservation
    /// - Throws: SimilarityAnalysisError
    func generateFeaturePrint(for image: CGImage) throws -> VNFeaturePrintObservation {
        // Feature Print 요청 생성
        let request = VNGenerateImageFeaturePrintRequest()

        // iOS 버전별 Revision 명시적 지정 (iOS 26 호환성)
        // - iOS 17+: Revision2 (768개 정규화 벡터, 거리 범위 0.0 ~ 2.0)
        // - iOS 16-: Revision1 (2048개 비정규화 벡터, 거리 범위 0.0 ~ 40.0)
        if #available(iOS 17.0, *) {
            request.revision = VNGenerateImageFeaturePrintRequestRevision2
        } else {
            request.revision = VNGenerateImageFeaturePrintRequestRevision1
        }

        // 이미지 핸들러 생성 및 실행
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])
        } catch {
            throw SimilarityAnalysisError.featurePrintGenerationFailed(error.localizedDescription)
        }

        // 결과 추출
        guard let result = request.results?.first else {
            throw SimilarityAnalysisError.featurePrintGenerationFailed("결과 없음")
        }

        return result
    }

    /// 이미지의 Feature Print를 비동기로 생성합니다.
    ///
    /// - Parameter image: 분석할 CGImage
    /// - Returns: VNFeaturePrintObservation
    /// - Throws: SimilarityAnalysisError
    func generateFeaturePrint(for image: CGImage) async throws -> VNFeaturePrintObservation {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.generateFeaturePrint(for: image)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Distance Calculation

    /// 두 Feature Print 간의 거리를 계산합니다.
    ///
    /// - Parameters:
    ///   - fp1: 첫 번째 Feature Print
    ///   - fp2: 두 번째 Feature Print
    /// - Returns: 두 Feature Print 간의 거리 (0에 가까울수록 유사)
    /// - Throws: SimilarityAnalysisError
    func computeDistance(_ fp1: VNFeaturePrintObservation, _ fp2: VNFeaturePrintObservation) throws -> Float {
        var distance: Float = 0

        do {
            try fp1.computeDistance(&distance, to: fp2)
        } catch {
            throw SimilarityAnalysisError.distanceCalculationFailed(error.localizedDescription)
        }

        return distance
    }

    /// 두 이미지 간의 유사도 거리를 계산합니다.
    ///
    /// - Parameters:
    ///   - image1: 첫 번째 이미지
    ///   - image2: 두 번째 이미지
    /// - Returns: 두 이미지 간의 거리
    /// - Throws: SimilarityAnalysisError
    func computeDistance(_ image1: CGImage, _ image2: CGImage) throws -> Float {
        let fp1 = try generateFeaturePrint(for: image1)
        let fp2 = try generateFeaturePrint(for: image2)
        return try computeDistance(fp1, fp2)
    }

    // MARK: - Similarity Check

    /// 두 Feature Print가 유사한지 확인합니다.
    ///
    /// - Parameters:
    ///   - fp1: 첫 번째 Feature Print
    ///   - fp2: 두 번째 Feature Print
    /// - Returns: 유사하면 true (거리 <= threshold)
    /// - Throws: SimilarityAnalysisError
    func areSimilar(_ fp1: VNFeaturePrintObservation, _ fp2: VNFeaturePrintObservation) throws -> Bool {
        let distance = try computeDistance(fp1, fp2)
        return distance <= similarityThreshold
    }

    /// 두 이미지가 유사한지 확인합니다.
    ///
    /// - Parameters:
    ///   - image1: 첫 번째 이미지
    ///   - image2: 두 번째 이미지
    /// - Returns: 유사하면 true
    /// - Throws: SimilarityAnalysisError
    func areSimilar(_ image1: CGImage, _ image2: CGImage) throws -> Bool {
        let distance = try computeDistance(image1, image2)
        return distance <= similarityThreshold
    }

    // MARK: - Batch Processing

    /// 인접한 이미지들 간의 거리를 계산합니다.
    ///
    /// N개의 Feature Print에 대해 N-1개의 인접 거리를 반환합니다.
    /// 결과 배열에서 distances[i]는 featurePrints[i]와 featurePrints[i+1] 간의 거리입니다.
    ///
    /// - Parameter featurePrints: Feature Print 배열 (순서 중요)
    /// - Returns: 인접 거리 배열 (nil은 해당 쌍의 계산 실패)
    func calculateAdjacentDistances(_ featurePrints: [VNFeaturePrintObservation?]) -> [Float?] {
        guard featurePrints.count >= 2 else {
            return []
        }

        var distances: [Float?] = []

        for i in 0..<(featurePrints.count - 1) {
            guard let fp1 = featurePrints[i],
                  let fp2 = featurePrints[i + 1] else {
                // Feature Print가 nil이면 거리도 nil
                distances.append(nil)
                continue
            }

            do {
                let distance = try computeDistance(fp1, fp2)
                distances.append(distance)
            } catch {
                // 계산 실패 시 nil
                distances.append(nil)
            }
        }

        return distances
    }

    /// Feature Print 배열에서 그룹을 형성합니다.
    ///
    /// 인접한 사진들의 거리가 threshold 이하면 같은 그룹으로 묶습니다.
    /// 거리가 threshold 초과하거나 nil이면 그룹을 분리합니다.
    ///
    /// - Parameters:
    ///   - featurePrints: Feature Print 배열 (nil 가능)
    ///   - photoIDs: 대응하는 사진 ID 배열
    ///   - threshold: 유사도 임계값 (기본값: 10.0)
    /// - Returns: 그룹화된 사진 ID 배열들 (3장 이상인 그룹만)
    func formGroups(
        featurePrints: [VNFeaturePrintObservation?],
        photoIDs: [String],
        threshold: Float = SimilarityConstants.similarityThreshold
    ) -> [[String]] {
        guard featurePrints.count == photoIDs.count,
              featurePrints.count >= SimilarityConstants.minGroupSize else {
            return []
        }

        // 인접 거리 계산
        let distances = calculateAdjacentDistances(featurePrints)

        var groups: [[String]] = []
        var currentGroup: [String] = [photoIDs[0]]

        for i in 0..<distances.count {
            let distance = distances[i]

            // nil이거나 threshold 초과하면 그룹 분리
            if distance == nil || distance! > threshold {
                // 현재 그룹이 최소 크기 이상이면 저장
                if currentGroup.count >= SimilarityConstants.minGroupSize {
                    groups.append(currentGroup)
                }
                // 새 그룹 시작
                currentGroup = [photoIDs[i + 1]]
            } else {
                // 같은 그룹에 추가
                currentGroup.append(photoIDs[i + 1])
            }
        }

        // 마지막 그룹 처리
        if currentGroup.count >= SimilarityConstants.minGroupSize {
            groups.append(currentGroup)
        }

        return groups
    }
}

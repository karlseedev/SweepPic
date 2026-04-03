//
//  SimilarityAnalyzer.swift
//  SweepPic
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 SweepPic. All rights reserved.
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

    // MARK: - Feature Print + Face Check (Batch)

    /// FeaturePrint 생성과 얼굴 유무 체크를 동시에 수행합니다 (배치 처리).
    ///
    /// 같은 VNImageRequestHandler에서 VNGenerateImageFeaturePrintRequest와
    /// VNDetectFaceRectanglesRequest를 함께 실행하여 추가 비용을 최소화합니다.
    /// 얼굴 유무 결과는 예비 테두리 표시 판단에만 사용됩니다 (정밀 감지는 YuNet 담당).
    ///
    /// - Parameter image: 분석할 CGImage (480px 기본 분석용)
    /// - Returns: (featurePrint, hasFace) 튜플
    /// - Throws: SimilarityAnalysisError
    func generateFeaturePrintWithFaceCheck(for image: CGImage) throws -> (VNFeaturePrintObservation, Bool) {
        // FeaturePrint 요청
        let fpRequest = VNGenerateImageFeaturePrintRequest()
        if #available(iOS 17.0, *) {
            fpRequest.revision = VNGenerateImageFeaturePrintRequestRevision2
        } else {
            fpRequest.revision = VNGenerateImageFeaturePrintRequestRevision1
        }

        // 얼굴 감지 요청 (존재 여부만 확인, 정밀도 불필요)
        let faceRequest = VNDetectFaceRectanglesRequest()

        // 같은 핸들러에서 배치 실행 (이미지 전처리 1회만)
        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        do {
            try handler.perform([fpRequest, faceRequest])
        } catch {
            throw SimilarityAnalysisError.featurePrintGenerationFailed(error.localizedDescription)
        }

        // FeaturePrint 결과
        guard let fpResult = fpRequest.results?.first else {
            throw SimilarityAnalysisError.featurePrintGenerationFailed("결과 없음")
        }

        // 얼굴 유무 (1개 이상 감지되면 true)
        let hasFace = !(faceRequest.results?.isEmpty ?? true)

        return (fpResult, hasFace)
    }

    /// FeaturePrint + 얼굴 유무 체크 비동기 버전
    ///
    /// - Parameter image: 분석할 CGImage
    /// - Returns: (featurePrint, hasFace) 튜플
    /// - Throws: SimilarityAnalysisError
    func generateFeaturePrintWithFaceCheck(for image: CGImage) async throws -> (VNFeaturePrintObservation, Bool) {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.generateFeaturePrintWithFaceCheck(for: image)
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
    /// 내부적으로 IncrementalGroupBuilder를 사용합니다.
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

        // IncrementalGroupBuilder를 사용하여 그룹 형성
        let builder = IncrementalGroupBuilder(analyzer: self, threshold: threshold)
        var groups: [[String]] = []

        for (fp, id) in zip(featurePrints, photoIDs) {
            if let completed = builder.feed(fp: fp, id: id) {
                groups.append(completed)
            }
        }
        if let last = builder.flush() {
            groups.append(last)
        }

        #if DEBUG
        // differential test: 기존 로직과 새 builder 결과 비교
        let legacyGroups = _formGroupsLegacy(
            featurePrints: featurePrints,
            photoIDs: photoIDs,
            threshold: threshold
        )
        assert(groups == legacyGroups,
               "[formGroups] builder 결과가 legacy와 다름: \(groups) vs \(legacyGroups)")
        #endif

        return groups
    }

    #if DEBUG
    /// 기존 formGroups 로직 보존 (DEBUG differential test용)
    private func _formGroupsLegacy(
        featurePrints: [VNFeaturePrintObservation?],
        photoIDs: [String],
        threshold: Float
    ) -> [[String]] {
        let distances = calculateAdjacentDistances(featurePrints)
        var groups: [[String]] = []
        var currentGroup: [String] = [photoIDs[0]]

        for i in 0..<distances.count {
            let distance = distances[i]
            if distance == nil || distance! > threshold {
                if currentGroup.count >= SimilarityConstants.minGroupSize {
                    groups.append(currentGroup)
                }
                currentGroup = [photoIDs[i + 1]]
            } else {
                currentGroup.append(photoIDs[i + 1])
            }
        }

        if currentGroup.count >= SimilarityConstants.minGroupSize {
            groups.append(currentGroup)
        }

        return groups
    }
    #endif
}

// MARK: - IncrementalGroupBuilder

/// 인접 거리 기반 증분 그룹 빌더
///
/// formGroups()의 코어 로직을 상태 기반으로 추출.
/// 그리드(배치)와 FaceScan(증분) 모두 이 코어를 공유합니다.
/// FP를 하나씩 feed하면 그룹 경계가 감지될 때 확정된 그룹을 반환합니다.
class IncrementalGroupBuilder {

    // MARK: - Dependencies

    /// 거리 계산용 분석기
    private let analyzer: SimilarityAnalyzer

    /// 유사도 임계값
    private let threshold: Float

    /// 최소 그룹 크기
    private let minGroupSize: Int

    // MARK: - State

    /// 현재 구축 중인 그룹
    private var currentGroup: [String] = []

    /// 직전 FP (거리 계산용)
    private var lastFP: VNFeaturePrintObservation?

    /// 열린 그룹이 있는지 여부 (1장이라도 누적되어 있으면 true)
    /// 아직 3장 미만이더라도 추가 사진으로 유효 그룹이 될 수 있으므로,
    /// 스캔 상한 도달 시 조기 종료를 방지합니다.
    var hasOpenGroup: Bool { !currentGroup.isEmpty }

    // MARK: - Init

    init(
        analyzer: SimilarityAnalyzer,
        threshold: Float = SimilarityConstants.similarityThreshold,
        minGroupSize: Int = SimilarityConstants.minGroupSize
    ) {
        self.analyzer = analyzer
        self.threshold = threshold
        self.minGroupSize = minGroupSize
    }

    // MARK: - Feed

    /// FP와 ID를 하나씩 feed합니다.
    ///
    /// 직전 FP와 새 FP의 거리를 비교하여 그룹 경계를 판단합니다.
    /// 경계가 감지되면 직전 그룹을 확정하여 반환합니다.
    ///
    /// - Parameters:
    ///   - fp: Feature Print (nil 가능)
    ///   - id: 사진 ID
    /// - Returns: 직전 그룹이 확정되면 해당 그룹의 ID 배열, 아니면 nil
    func feed(fp: VNFeaturePrintObservation?, id: String) -> [String]? {
        var completedGroup: [String]? = nil

        // 거리 계산: lastFP와 새 FP 비교
        // 원본 formGroups 동작: fp[i] 또는 fp[i+1] 중 하나라도 nil이면 distance=nil → 끊김
        // 단, 첫 feed (lastFP==nil, 이전 사진 없음)는 끊김이 아님
        let isFirstFeed = (lastFP == nil && currentGroup.isEmpty)
        let shouldBreak: Bool
        if isFirstFeed {
            shouldBreak = false
        } else if let last = lastFP, let current = fp {
            let distance = try? analyzer.computeDistance(last, current)
            shouldBreak = (distance == nil || distance! > threshold)
        } else {
            // lastFP 또는 fp 중 하나라도 nil → distance=nil → 끊김
            shouldBreak = true
        }

        if shouldBreak {
            // 현재 그룹 확정
            if currentGroup.count >= minGroupSize {
                completedGroup = currentGroup
            }
            // 새 그룹 시작 (원본 formGroups: FP nil이어도 다음 사진은 항상 새 그룹 시작)
            currentGroup = [id]
        } else {
            // 같은 그룹에 추가 (원본 formGroups: 첫 사진은 FP nil이어도 그룹에 포함)
            if currentGroup.isEmpty {
                currentGroup = [id]
            } else {
                currentGroup.append(id)
            }
        }

        // nil FP는 lastFP를 리셋 (원본 formGroups 동작 일치)
        lastFP = fp
        return completedGroup
    }

    // MARK: - Flush

    /// 스캔 종료 시 미확정 그룹을 반환합니다.
    ///
    /// 마지막 그룹이 최소 크기 이상이면 반환, 아니면 nil.
    /// 호출 후 내부 상태가 초기화됩니다.
    func flush() -> [String]? {
        guard currentGroup.count >= minGroupSize else {
            currentGroup = []
            lastFP = nil
            return nil
        }
        let group = currentGroup
        currentGroup = []
        lastFP = nil
        return group
    }
}

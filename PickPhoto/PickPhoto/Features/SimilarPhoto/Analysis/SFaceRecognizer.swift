//
//  SFaceRecognizer.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  SFace 모델을 사용한 얼굴 임베딩 추출 및 유사도 계산을 담당합니다.
//  정렬된 112×112 얼굴 이미지에서 128차원 임베딩 벡터를 추출하고,
//  코사인 유사도로 동일인 여부를 판정합니다.
//
//  Preprocessing Spec (OpenCV SFace 기준):
//  - Color: RGB (iOS 기본값 그대로)
//  - Size: 112×112
//  - Range: 0-255 (정규화 없음)
//  - Mean: [0, 0, 0]
//  - Scale: 1.0
//
//  Reference:
//  - OpenCV FaceRecognizerSF
//  - MobileFaceNet 아키텍처
//

import Foundation
import AppCore
import CoreML
import CoreGraphics
import Accelerate

/// SFace 관련 에러
enum SFaceError: Error, LocalizedError {
    /// 모델 로드 실패
    case modelLoadFailed(String)

    /// 전처리 실패
    case preprocessingFailed(String)

    /// 추론 실패
    case inferenceFailed(String)

    /// 잘못된 이미지
    case invalidImage(String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let reason):
            return "SFace 모델 로드 실패: \(reason)"
        case .preprocessingFailed(let reason):
            return "전처리 실패: \(reason)"
        case .inferenceFailed(let reason):
            return "추론 실패: \(reason)"
        case .invalidImage(let reason):
            return "잘못된 이미지: \(reason)"
        }
    }
}

/// SFace 설정값
enum SFaceConfig {
    /// 입력 이미지 크기
    static let inputSize: Int = 112

    /// 임베딩 차원
    static let embeddingDim: Int = 128

    /// 동일인 판정 코사인 유사도 임계값 (LFW 벤치마크 기준)
    /// 0.363 = 99.60% 정확도
    /// 실제 데이터로 튜닝 필요
    static let defaultCosineThreshold: Float = 0.363
}

/// SFace 얼굴 인식기
///
/// 정렬된 얼굴 이미지에서 128차원 임베딩 벡터를 추출하고,
/// 코사인 유사도로 동일인 여부를 판정합니다.
final class SFaceRecognizer {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared: SFaceRecognizer? = {
        do {
            return try SFaceRecognizer()
        } catch {
            return nil
        }
    }()

    // MARK: - Properties

    /// Core ML 모델
    private let model: MLModel

    /// 동일인 판정 임계값
    private let cosineThreshold: Float

    // MARK: - Initialization

    /// SFace 인식기를 초기화합니다.
    ///
    /// - Parameter cosineThreshold: 동일인 판정 임계값 (기본: 0.363)
    /// - Throws: SFaceError.modelLoadFailed
    init(cosineThreshold: Float = SFaceConfig.defaultCosineThreshold) throws {
        self.cosineThreshold = cosineThreshold

        // Core ML 모델 로드
        let config = MLModelConfiguration()
        config.computeUnits = .all

        do {
            self.model = try SFace(configuration: config).model
        } catch {
            throw SFaceError.modelLoadFailed(error.localizedDescription)
        }
    }

    // MARK: - Public Methods - Embedding

    /// 정렬된 얼굴 이미지에서 임베딩을 추출합니다.
    ///
    /// - Parameter alignedFace: FaceAligner로 정렬된 112×112 이미지
    /// - Returns: 128차원 임베딩 벡터
    /// - Throws: SFaceError
    func extractEmbedding(from alignedFace: CGImage) throws -> [Float] {
        // 이미지 크기 검증
        guard alignedFace.width == SFaceConfig.inputSize,
              alignedFace.height == SFaceConfig.inputSize else {
            throw SFaceError.invalidImage(
                "112×112 이미지가 필요합니다 (현재: \(alignedFace.width)×\(alignedFace.height))"
            )
        }

        // 1. 전처리 (RGB, 0-255, NCHW)
        let input = try preprocess(alignedFace)

        // 2. 추론
        let embedding = try runInference(input: input)

        return embedding
    }

    /// 여러 얼굴의 임베딩을 추출합니다.
    ///
    /// - Parameter alignedFaces: 정렬된 얼굴 이미지 배열
    /// - Returns: 임베딩 배열 (실패한 경우 nil)
    func extractEmbeddings(from alignedFaces: [CGImage]) -> [[Float]?] {
        return alignedFaces.map { face in
            try? extractEmbedding(from: face)
        }
    }

    // MARK: - Public Methods - Similarity

    /// 두 임베딩 간의 코사인 유사도를 계산합니다.
    ///
    /// - Parameters:
    ///   - embedding1: 첫 번째 임베딩
    ///   - embedding2: 두 번째 임베딩
    /// - Returns: 코사인 유사도 (-1 ~ 1, 높을수록 유사)
    func cosineSimilarity(_ embedding1: [Float], _ embedding2: [Float]) -> Float {
        guard embedding1.count == embedding2.count else {
            return 0
        }

        var dotProduct: Float = 0
        var norm1: Float = 0
        var norm2: Float = 0

        // Accelerate vDSP 사용 (SIMD 최적화)
        vDSP_dotpr(embedding1, 1, embedding2, 1, &dotProduct, vDSP_Length(embedding1.count))
        vDSP_dotpr(embedding1, 1, embedding1, 1, &norm1, vDSP_Length(embedding1.count))
        vDSP_dotpr(embedding2, 1, embedding2, 1, &norm2, vDSP_Length(embedding2.count))

        let denominator = sqrt(norm1) * sqrt(norm2)
        guard denominator > 0 else { return 0 }

        return dotProduct / denominator
    }

    /// 두 임베딩 간의 L2 거리를 계산합니다.
    ///
    /// - Parameters:
    ///   - embedding1: 첫 번째 임베딩
    ///   - embedding2: 두 번째 임베딩
    /// - Returns: L2 거리 (낮을수록 유사)
    func l2Distance(_ embedding1: [Float], _ embedding2: [Float]) -> Float {
        guard embedding1.count == embedding2.count else {
            return Float.infinity
        }

        var diff = [Float](repeating: 0, count: embedding1.count)
        var sumSquared: Float = 0

        // Accelerate vDSP 사용
        vDSP_vsub(embedding2, 1, embedding1, 1, &diff, 1, vDSP_Length(embedding1.count))
        vDSP_dotpr(diff, 1, diff, 1, &sumSquared, vDSP_Length(diff.count))

        return sqrt(sumSquared)
    }

    // MARK: - Public Methods - Matching

    /// 두 임베딩이 동일인인지 판정합니다.
    ///
    /// - Parameters:
    ///   - embedding1: 첫 번째 임베딩
    ///   - embedding2: 두 번째 임베딩
    ///   - threshold: 판정 임계값 (기본: 인스턴스 설정값)
    /// - Returns: (동일인 여부, 코사인 유사도)
    func isSamePerson(
        _ embedding1: [Float],
        _ embedding2: [Float],
        threshold: Float? = nil
    ) -> (isSame: Bool, score: Float) {
        let score = cosineSimilarity(embedding1, embedding2)
        let th = threshold ?? cosineThreshold
        return (score >= th, score)
    }

    /// 기준 임베딩과 가장 유사한 임베딩을 찾습니다.
    ///
    /// - Parameters:
    ///   - reference: 기준 임베딩
    ///   - candidates: 후보 임베딩 배열
    /// - Returns: (가장 유사한 인덱스, 유사도) 또는 nil (후보가 없는 경우)
    func findMostSimilar(
        to reference: [Float],
        among candidates: [[Float]]
    ) -> (index: Int, score: Float)? {
        guard !candidates.isEmpty else { return nil }

        var bestIndex = 0
        var bestScore: Float = -1

        for (i, candidate) in candidates.enumerated() {
            let score = cosineSimilarity(reference, candidate)
            if score > bestScore {
                bestScore = score
                bestIndex = i
            }
        }

        return (bestIndex, bestScore)
    }

    // MARK: - Private Methods - Preprocessing

    /// 이미지를 SFace 입력 형식으로 전처리합니다.
    ///
    /// - Parameter image: 112×112 정렬된 얼굴 이미지
    /// - Returns: MLMultiArray (RGB, NCHW, 0-255)
    /// - Throws: SFaceError.preprocessingFailed
    private func preprocess(_ image: CGImage) throws -> MLMultiArray {
        let size = SFaceConfig.inputSize
        let bytesPerPixel = 4

        // 픽셀 데이터 추출
        var pixelData = [UInt8](repeating: 0, count: size * size * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: size,
            height: size,
            bitsPerComponent: 8,
            bytesPerRow: size * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw SFaceError.preprocessingFailed("CGContext 생성 실패")
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: size, height: size))

        // MLMultiArray 생성 (NCHW: [1, 3, 112, 112])
        let input: MLMultiArray
        do {
            input = try MLMultiArray(
                shape: [1, 3, NSNumber(value: size), NSNumber(value: size)],
                dataType: .float32
            )
        } catch {
            throw SFaceError.preprocessingFailed("MLMultiArray 생성 실패: \(error)")
        }

        // RGB 순서로 복사 (iOS 이미지는 RGB, SFace도 RGB 기대)
        let pointer = input.dataPointer.bindMemory(
            to: Float32.self,
            capacity: 3 * size * size
        )

        let channelStride = size * size

        for y in 0..<size {
            for x in 0..<size {
                let pixelIndex = (y * size + x) * bytesPerPixel
                let spatialIndex = y * size + x

                // RGBA 순서로 읽어서 RGB 순서로 저장
                let r = Float32(pixelData[pixelIndex + 0])
                let g = Float32(pixelData[pixelIndex + 1])
                let b = Float32(pixelData[pixelIndex + 2])

                // RGB 순서 (0-255 범위 그대로)
                pointer[0 * channelStride + spatialIndex] = r  // Channel 0 = Red
                pointer[1 * channelStride + spatialIndex] = g  // Channel 1 = Green
                pointer[2 * channelStride + spatialIndex] = b  // Channel 2 = Blue
            }
        }

        return input
    }

    // MARK: - Private Methods - Inference

    /// Core ML 추론을 실행합니다.
    ///
    /// - Parameter input: 전처리된 입력
    /// - Returns: 128차원 임베딩 벡터
    /// - Throws: SFaceError.inferenceFailed
    private func runInference(input: MLMultiArray) throws -> [Float] {
        do {
            // 입력 구성 (SFace 모델의 입력 이름은 "input_1")
            let inputFeature = try MLDictionaryFeatureProvider(dictionary: [
                "input_1": MLFeatureValue(multiArray: input)
            ])

            // 추론 실행
            let output = try model.prediction(from: inputFeature)

            // 임베딩 추출 (SFace 모델의 출력 이름은 "var_811")
            guard let embeddingArray = output.featureValue(for: "var_811")?.multiArrayValue else {
                throw SFaceError.inferenceFailed("출력 임베딩을 찾을 수 없습니다")
            }

            // Float 배열로 변환
            var embedding = [Float](repeating: 0, count: SFaceConfig.embeddingDim)
            for i in 0..<SFaceConfig.embeddingDim {
                embedding[i] = embeddingArray[i].floatValue
            }

            return embedding
        } catch let error as SFaceError {
            throw error
        } catch {
            throw SFaceError.inferenceFailed(error.localizedDescription)
        }
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension SFaceRecognizer {
    /// 디버그용: 임베딩 통계 출력
    func printEmbeddingStats(_ embedding: [Float]) {
        let min = embedding.min() ?? 0
        let max = embedding.max() ?? 0
        let sum = embedding.reduce(0, +)
        let mean = sum / Float(embedding.count)

        var variance: Float = 0
        vDSP_measqv(embedding, 1, &variance, vDSP_Length(embedding.count))
        let std = sqrt(variance - mean * mean)

        print("[SFace] Embedding Stats:")
        print("  - Dim: \(embedding.count)")
        print("  - Range: [\(String(format: "%.4f", min)), \(String(format: "%.4f", max))]")
        print("  - Mean: \(String(format: "%.4f", mean))")
        print("  - Std: \(String(format: "%.4f", std))")
    }
}
#endif

//
//  YuNetFaceDetector.swift
//  SweepPic
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 SweepPic. All rights reserved.
//
//  Description:
//  YuNet 기반 얼굴 감지 메인 클래스입니다.
//  Core ML 모델 추론, NMS, 전체 파이프라인을 담당합니다.
//
//  Pipeline:
//  1. 전처리 (RGB→BGR, 320×320, NCHW)
//  2. Core ML 추론
//  3. 디코딩 (Score, BBox, Landmarks)
//  4. NMS (Non-Maximum Suppression)
//  5. Top-K 필터링
//  6. 좌표 변환 (320×320 → 원본)
//

import Foundation
import AppCore
import CoreML
import CoreGraphics

/// YuNet 기반 얼굴 감지기
///
/// OpenCV Zoo의 YuNet 모델을 Core ML로 변환하여 사용합니다.
/// 5-point landmark와 함께 얼굴을 감지합니다.
final class YuNetFaceDetector {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared: YuNetFaceDetector? = {
        do {
            return try YuNetFaceDetector()
        } catch {
            return nil
        }
    }()

    // MARK: - Properties

    /// Core ML 모델
    private let model: MLModel

    /// 전처리기
    private let preprocessor: YuNetPreprocessor

    /// 디코더
    private let decoder: YuNetDecoder

    // MARK: - Configuration

    /// Score 임계값
    private let scoreThreshold: Float

    /// NMS IoU 임계값
    private let nmsThreshold: Float

    /// 최대 반환 얼굴 수
    private let topK: Int

    // MARK: - Initialization

    /// YuNet 감지기를 초기화합니다.
    ///
    /// - Parameters:
    ///   - modelName: 모델 리소스 이름 (기본: YuNetConfig.modelName = "YuNet960")
    ///   - inputSize: 모델 입력 크기 (기본: YuNetConfig.inputWidth = 960)
    ///   - scoreThreshold: Score 임계값 (기본: 0.6)
    ///   - nmsThreshold: NMS IoU 임계값 (기본: 0.3)
    ///   - topK: 최대 반환 얼굴 수 (기본: SimilarityConstants.maxFacesPerPhoto)
    /// - Throws: YuNetError.modelLoadFailed
    init(
        modelName: String = YuNetConfig.modelName,
        inputSize: Int = YuNetConfig.inputWidth,
        scoreThreshold: Float = YuNetConfig.scoreThreshold,
        nmsThreshold: Float = YuNetConfig.nmsThreshold,
        topK: Int = YuNetConfig.topK
    ) throws {
        self.scoreThreshold = scoreThreshold
        self.nmsThreshold = nmsThreshold
        self.topK = topK
        self.preprocessor = YuNetPreprocessor(inputSize: inputSize)
        self.decoder = YuNetDecoder(inputSize: inputSize)

        // Core ML 모델 로드 (Bundle에서 modelName으로 검색)
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine  // GPU는 UI/이미지용으로 남기고 ML은 CPU+ANE로 격리

        do {
            guard let modelURL = Bundle.main.url(
                forResource: modelName,
                withExtension: "mlmodelc"
            ) else {
                throw YuNetError.modelLoadFailed("모델 '\(modelName).mlmodelc'을 찾을 수 없음")
            }
            self.model = try MLModel(contentsOf: modelURL, configuration: config)
        } catch let error as YuNetError {
            throw error
        } catch {
            throw YuNetError.modelLoadFailed(error.localizedDescription)
        }
    }

    // MARK: - Public Methods

    /// 이미지에서 얼굴을 감지합니다.
    ///
    /// - Parameter image: 감지할 CGImage
    /// - Returns: 감지된 얼굴 배열 (원본 이미지 좌표)
    /// - Throws: YuNetError
    ///
    /// 반환되는 좌표는 원본 이미지 크기 기준입니다.
    /// 빈 배열 반환은 에러가 아니며, 얼굴이 없는 경우입니다.
    func detect(in image: CGImage) throws -> [YuNetDetection] {
        // 1. 전처리 (RGB → BGR, 레터박스 리사이즈, NCHW)
        let (input, letterboxInfo) = try preprocessor.preprocess(image)

        // 2. Core ML 추론
        let outputs = try runInference(input: input)

        // 3. 디코딩 (Score, BBox, Landmarks)
        let detections = decoder.decode(
            outputs: outputs,
            scoreThreshold: scoreThreshold
        )

        // 빈 결과는 정상 (얼굴 없음)
        if detections.isEmpty {
            return []
        }

        // 4. NMS
        let nmsResult = performNMS(detections: detections)

        // 5. Top-K
        let topKResult = Array(nmsResult.prefix(topK))

        // 6. 좌표 변환 (레터박스 → 원본)
        // 모델 좌표에서 패딩 오프셋을 빼고, 스케일로 나눠서 원본 좌표로 복원
        let finalResult = topKResult.map { detection in
            YuNetDecoder.transformFromLetterbox(
                detection,
                letterboxInfo: letterboxInfo
            )
        }

        return finalResult
    }

    /// 이미지에서 얼굴을 감지합니다 (비동기).
    ///
    /// - Parameter image: 감지할 CGImage
    /// - Returns: 감지된 얼굴 배열 (원본 이미지 좌표)
    /// - Throws: YuNetError
    func detectAsync(in image: CGImage) async throws -> [YuNetDetection] {
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let result = try self.detect(in: image)
                    continuation.resume(returning: result)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Private Methods - Inference

    /// Core ML 추론을 실행합니다.
    ///
    /// - Parameter input: 전처리된 입력 MLMultiArray
    /// - Returns: 모델 출력 (MLFeatureProvider)
    /// - Throws: YuNetError.inferenceFailed
    private func runInference(input: MLMultiArray) throws -> MLFeatureProvider {
        do {
            // Core ML 입력 구성
            let inputFeature = try MLDictionaryFeatureProvider(dictionary: [
                "input": MLFeatureValue(multiArray: input)
            ])

            // 추론 실행
            let outputs = try model.prediction(from: inputFeature)
            return outputs
        } catch {
            throw YuNetError.inferenceFailed(error.localizedDescription)
        }
    }

    // MARK: - Private Methods - NMS

    /// Non-Maximum Suppression을 수행합니다.
    ///
    /// Score 순으로 정렬 후, IoU가 임계값을 초과하는 중복 박스를 제거합니다.
    ///
    /// - Parameter detections: 디코딩된 감지 결과 배열
    /// - Returns: NMS 후 남은 감지 결과 (Score 내림차순)
    private func performNMS(detections: [YuNetDetection]) -> [YuNetDetection] {
        // Score 내림차순 정렬
        let sorted = detections.sorted { $0.score > $1.score }

        var kept: [YuNetDetection] = []
        var suppressed = Set<Int>()

        for i in 0..<sorted.count {
            if suppressed.contains(i) { continue }
            kept.append(sorted[i])

            // 현재 박스와 나머지 박스들의 IoU 계산
            for j in (i + 1)..<sorted.count {
                if suppressed.contains(j) { continue }

                let iou = computeIoU(sorted[i].boundingBox, sorted[j].boundingBox)
                if iou > nmsThreshold {
                    suppressed.insert(j)
                }
            }
        }

        return kept
    }

    /// 두 바운딩 박스의 IoU를 계산합니다.
    ///
    /// - Parameters:
    ///   - a: 첫 번째 박스
    ///   - b: 두 번째 박스
    /// - Returns: IoU 값 (0~1)
    private func computeIoU(_ a: CGRect, _ b: CGRect) -> Float {
        let intersection = a.intersection(b)
        if intersection.isNull || intersection.isEmpty {
            return 0
        }

        let intersectionArea = intersection.width * intersection.height
        let unionArea = a.width * a.height + b.width * b.height - intersectionArea

        guard unionArea > 0 else { return 0 }
        return Float(intersectionArea / unionArea)
    }
}

// MARK: - Debug Helpers

#if DEBUG
extension YuNetFaceDetector {
    /// 디버그용: 모델 정보 출력
    func printModelInfo() {
        print("[YuNet] Model Description:")
        print("  - Score Threshold: \(scoreThreshold)")
        print("  - NMS Threshold: \(nmsThreshold)")
        print("  - Top-K: \(topK)")
        print("  - Input: 320×320 BGR")
        print("  - Strides: \(YuNetConfig.strides)")
    }

    /// 디버그용: 감지 결과 요약 출력
    func printDetectionSummary(_ detections: [YuNetDetection]) {
        print("[YuNet] Detected \(detections.count) face(s)")
        for (i, det) in detections.enumerated() {
            print("  [\(i)] score=\(String(format: "%.3f", det.score)), " +
                  "bbox=(\(Int(det.boundingBox.origin.x)), \(Int(det.boundingBox.origin.y)), " +
                  "\(Int(det.boundingBox.width)), \(Int(det.boundingBox.height)))")
        }
    }
}
#endif

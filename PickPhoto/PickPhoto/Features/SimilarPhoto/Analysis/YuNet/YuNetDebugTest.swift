//
//  YuNetDebugTest.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  YuNet + SFace 파이프라인 테스트용 디버그 함수입니다.
//  Core ML 출력 범위 검증, 얼굴 감지/정렬/임베딩 테스트를 수행합니다.
//

import Foundation
import CoreML
import CoreGraphics
import Photos

/// YuNet + SFace 디버그 테스트
///
/// Phase 2 검증용:
/// 1. Core ML 출력 범위 검증 (cls/obj가 0~1인지)
/// 2. 얼굴 감지 테스트
/// 3. 얼굴 정렬 테스트
/// 4. 임베딩 추출 테스트
final class YuNetDebugTest {

    // MARK: - Singleton

    static let shared = YuNetDebugTest()

    // MARK: - Dependencies

    private let imageLoader = SimilarityImageLoader.shared

    // MARK: - Test Results

    struct TestResult {
        let testName: String
        let passed: Bool
        let details: String
    }

    // MARK: - Public Methods

    /// 전체 파이프라인 테스트를 실행합니다.
    ///
    /// - Parameter photo: 테스트할 PHAsset
    /// - Returns: 테스트 결과 배열
    func runAllTests(with photo: PHAsset) async -> [TestResult] {
        var results: [TestResult] = []

        print("\n" + String(repeating: "=", count: 60))
        print("YuNet + SFace Pipeline Test")
        print(String(repeating: "=", count: 60))

        // 1. 이미지 로드
        guard let image = try? await imageLoader.loadImage(for: photo) else {
            results.append(TestResult(
                testName: "Image Load",
                passed: false,
                details: "이미지 로드 실패"
            ))
            return results
        }

        print("[Image] Size: \(image.width)×\(image.height)")

        // 2. Core ML 출력 범위 검증
        let coreMLResult = await testCoreMLOutputRange(image: image)
        results.append(coreMLResult)

        // 3. YuNet 얼굴 감지 테스트
        let (detectResult, detections) = await testYuNetDetection(image: image)
        results.append(detectResult)

        // 4. FaceAligner 테스트 (얼굴이 감지된 경우)
        var alignedFaces: [CGImage] = []
        if let detections = detections, !detections.isEmpty {
            let (alignResult, aligned) = testFaceAlignment(image: image, detections: detections)
            results.append(alignResult)
            alignedFaces = aligned
        }

        // 5. SFace 임베딩 테스트 (정렬된 얼굴이 있는 경우)
        if !alignedFaces.isEmpty {
            let embeddingResult = await testSFaceEmbedding(alignedFaces: alignedFaces)
            results.append(embeddingResult)
        }

        // 결과 출력
        print("\n" + String(repeating: "=", count: 60))
        print("Test Results Summary")
        print(String(repeating: "-", count: 60))
        for result in results {
            let status = result.passed ? "✅ PASS" : "❌ FAIL"
            print("\(status) | \(result.testName)")
            print("       \(result.details)")
        }
        print(String(repeating: "=", count: 60) + "\n")

        return results
    }

    // MARK: - Test 1: Core ML Output Range

    /// Core ML 출력 범위를 검증합니다.
    ///
    /// cls/obj 출력이 0~1 범위인지 확인하여 sigmoid 내장 여부를 검증합니다.
    private func testCoreMLOutputRange(image: CGImage) async -> TestResult {
        print("\n[Test 1] Core ML Output Range Verification")

        guard YuNetFaceDetector.shared != nil else {
            return TestResult(
                testName: "Core ML Output Range",
                passed: false,
                details: "YuNetFaceDetector 초기화 실패"
            )
        }

        // 직접 모델 추론하여 raw 출력 확인
        let preprocessor = YuNetPreprocessor()

        do {
            let input = try preprocessor.preprocess(image)

            // 모델 로드
            let config = MLModelConfiguration()
            let model = try YuNet(configuration: config).model

            let inputFeature = try MLDictionaryFeatureProvider(dictionary: [
                "input": MLFeatureValue(multiArray: input)
            ])

            let outputs = try model.prediction(from: inputFeature)

            // 각 stride의 cls/obj 출력 범위 확인
            var allInRange = true
            var details: [String] = []

            for stride in [8, 16, 32] {
                let outputNames = YuNetOutputNames.outputs(for: stride)

                if let clsArray = outputs.featureValue(for: outputNames.cls)?.multiArrayValue,
                   let objArray = outputs.featureValue(for: outputNames.obj)?.multiArrayValue {

                    let clsStats = getArrayStats(clsArray)
                    let objStats = getArrayStats(objArray)

                    let clsInRange = clsStats.min >= -0.01 && clsStats.max <= 1.01
                    let objInRange = objStats.min >= -0.01 && objStats.max <= 1.01

                    details.append("Stride \(stride):")
                    details.append("  cls: [\(String(format: "%.4f", clsStats.min)), \(String(format: "%.4f", clsStats.max))] \(clsInRange ? "✓" : "✗")")
                    details.append("  obj: [\(String(format: "%.4f", objStats.min)), \(String(format: "%.4f", objStats.max))] \(objInRange ? "✓" : "✗")")

                    if !clsInRange || !objInRange {
                        allInRange = false
                    }
                }
            }

            let detailStr = details.joined(separator: "\n")
            print(detailStr)

            return TestResult(
                testName: "Core ML Output Range",
                passed: allInRange,
                details: allInRange ? "cls/obj 모두 0~1 범위 (sigmoid 내장 확인)" : "범위 초과 값 발견"
            )

        } catch {
            return TestResult(
                testName: "Core ML Output Range",
                passed: false,
                details: "추론 실패: \(error.localizedDescription)"
            )
        }
    }

    /// CGImage 픽셀 합계 계산 (이미지 동일성 확인용)
    private func calculatePixelSum(_ image: CGImage) -> Int {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4

        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * bytesPerPixel,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return -1
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        var sum: Int = 0
        for i in stride(from: 0, to: pixelData.count, by: bytesPerPixel) {
            sum += Int(pixelData[i])     // R
            sum += Int(pixelData[i + 1]) // G
            sum += Int(pixelData[i + 2]) // B
        }
        return sum
    }

    /// MLMultiArray 통계 계산
    private func getArrayStats(_ array: MLMultiArray) -> (min: Float, max: Float, mean: Float) {
        var minVal: Float = Float.greatestFiniteMagnitude
        var maxVal: Float = -Float.greatestFiniteMagnitude
        var sum: Float = 0

        let count = array.count
        for i in 0..<count {
            let val = array[i].floatValue
            minVal = min(minVal, val)
            maxVal = max(maxVal, val)
            sum += val
        }

        return (minVal, maxVal, sum / Float(count))
    }

    // MARK: - Test 2: YuNet Detection

    /// YuNet 얼굴 감지를 테스트합니다.
    private func testYuNetDetection(image: CGImage) async -> (TestResult, [YuNetDetection]?) {
        print("\n[Test 2] YuNet Face Detection")

        guard let detector = YuNetFaceDetector.shared else {
            return (TestResult(
                testName: "YuNet Detection",
                passed: false,
                details: "YuNetFaceDetector 초기화 실패"
            ), nil)
        }

        do {
            let detections = try detector.detect(in: image)

            print("  Detected \(detections.count) face(s)")
            for (i, det) in detections.enumerated() {
                print("  [\(i)] score=\(String(format: "%.3f", det.score))")
                print("       bbox=(\(Int(det.boundingBox.origin.x)), \(Int(det.boundingBox.origin.y)), " +
                      "\(Int(det.boundingBox.width)), \(Int(det.boundingBox.height)))")
                print("       landmarks=\(det.landmarks.map { "(\(Int($0.x)),\(Int($0.y)))" }.joined(separator: ", "))")
            }

            let passed = detections.count > 0
            return (TestResult(
                testName: "YuNet Detection",
                passed: passed,
                details: passed ? "\(detections.count)개 얼굴 감지 성공" : "얼굴 감지 안됨 (이미지에 얼굴이 없을 수 있음)"
            ), detections)

        } catch {
            return (TestResult(
                testName: "YuNet Detection",
                passed: false,
                details: "감지 실패: \(error.localizedDescription)"
            ), nil)
        }
    }

    // MARK: - Test 3: Face Alignment

    /// FaceAligner를 테스트합니다.
    private func testFaceAlignment(
        image: CGImage,
        detections: [YuNetDetection]
    ) -> (TestResult, [CGImage]) {
        print("\n[Test 3] Face Alignment")

        let aligner = FaceAligner.shared
        var alignedFaces: [CGImage] = []
        var failCount = 0

        for (i, detection) in detections.enumerated() {
            do {
                let aligned = try aligner.align(image: image, landmarks: detection.landmarks)
                alignedFaces.append(aligned)

                // 디버그: 픽셀 합계 출력 (동일 이미지인지 확인)
                let pixelSum = calculatePixelSum(aligned)
                print("  [\(i)] Aligned: \(aligned.width)×\(aligned.height), pixelSum=\(pixelSum) ✓")
            } catch {
                failCount += 1
                print("  [\(i)] Failed: \(error.localizedDescription) ✗")
            }
        }

        let passed = alignedFaces.count > 0
        return (TestResult(
            testName: "Face Alignment",
            passed: passed,
            details: "\(alignedFaces.count)/\(detections.count) 성공, \(failCount) 실패"
        ), alignedFaces)
    }

    // MARK: - Test 4: SFace Embedding

    /// SFaceRecognizer를 테스트합니다.
    private func testSFaceEmbedding(alignedFaces: [CGImage]) async -> TestResult {
        print("\n[Test 4] SFace Embedding Extraction")

        guard let recognizer = SFaceRecognizer.shared else {
            return TestResult(
                testName: "SFace Embedding",
                passed: false,
                details: "SFaceRecognizer 초기화 실패"
            )
        }

        var embeddings: [[Float]] = []
        var failCount = 0

        for (i, face) in alignedFaces.enumerated() {
            do {
                let embedding = try recognizer.extractEmbedding(from: face)
                embeddings.append(embedding)

                // 임베딩 통계
                let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
                let min = embedding.min() ?? 0
                let max = embedding.max() ?? 0

                print("  [\(i)] dim=\(embedding.count), norm=\(String(format: "%.3f", norm)), range=[\(String(format: "%.3f", min)), \(String(format: "%.3f", max))] ✓")
            } catch {
                failCount += 1
                print("  [\(i)] Failed: \(error.localizedDescription) ✗")
            }
        }

        // 임베딩 간 유사도 테스트 (2개 이상인 경우)
        if embeddings.count >= 2 {
            print("\n  Pairwise Cosine Similarity:")
            for i in 0..<embeddings.count {
                for j in (i+1)..<embeddings.count {
                    let sim = recognizer.cosineSimilarity(embeddings[i], embeddings[j])
                    print("    [\(i)] vs [\(j)]: \(String(format: "%.4f", sim))")
                }
            }
        }

        let passed = embeddings.count > 0
        return TestResult(
            testName: "SFace Embedding",
            passed: passed,
            details: "\(embeddings.count)/\(alignedFaces.count) 성공 (128-dim), \(failCount) 실패"
        )
    }
}

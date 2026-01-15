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
import UIKit

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

        // 4.5. 정렬 검증 테스트 (정렬된 얼굴이 있는 경우)
        if !alignedFaces.isEmpty {
            let validationResult = testAlignmentValidation(alignedFaces: alignedFaces)
            results.append(validationResult)
        }

        // 5. SFace 임베딩 테스트 (정렬된 얼굴이 있는 경우)
        if !alignedFaces.isEmpty {
            let embeddingResult = await testSFaceEmbedding(alignedFaces: alignedFaces)
            results.append(embeddingResult)
        }

        // 6. Self-consistency 테스트 (정렬된 얼굴이 있는 경우)
        if !alignedFaces.isEmpty {
            let consistencyResult = await testSelfConsistency(alignedFaces: alignedFaces)
            results.append(consistencyResult)
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

    // MARK: - Landmark Visualization Test

    /// YuNet 랜드마크를 원본 이미지 위에 그려서 좌표계 검증
    ///
    /// - Parameter photo: 테스트할 PHAsset
    /// - Returns: 랜드마크가 그려진 이미지 (UIImage)
    func drawLandmarksOnImage(with photo: PHAsset) async -> UIImage? {
        print("\n" + String(repeating: "=", count: 60))
        print("Landmark Visualization Test")
        print(String(repeating: "=", count: 60))

        // 1. 이미지 로드
        guard let image = try? await imageLoader.loadImage(for: photo) else {
            print("[Error] 이미지 로드 실패")
            return nil
        }

        print("[Image] Size: \(image.width)×\(image.height)")

        // 2. YuNet 얼굴 감지
        guard let detector = YuNetFaceDetector.shared else {
            print("[Error] YuNetFaceDetector 초기화 실패")
            return nil
        }

        guard let detections = try? detector.detect(in: image), !detections.isEmpty else {
            print("[Error] 얼굴 감지 실패")
            return nil
        }

        print("[Detection] \(detections.count)개 얼굴 감지")

        // 3. 이미지 위에 랜드마크 그리기
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        // 원본 이미지 픽셀 복사
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let srcContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            print("[Error] CGContext 생성 실패")
            return nil
        }
        srcContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 각 얼굴의 bbox와 랜드마크 그리기
        for (faceIdx, detection) in detections.enumerated() {
            let bbox = detection.boundingBox
            let landmarks = detection.landmarks

            print("\n[Face \(faceIdx)] score=\(String(format: "%.3f", detection.score))")
            print("  bbox: (\(Int(bbox.origin.x)), \(Int(bbox.origin.y)), \(Int(bbox.width)), \(Int(bbox.height)))")

            // BBox 그리기 (녹색)
            drawRect(
                in: &pixelData,
                width: width,
                height: height,
                rect: bbox,
                color: (0, 255, 0)  // Green
            )

            // 랜드마크 그리기 (각각 다른 색)
            let landmarkColors: [(UInt8, UInt8, UInt8)] = [
                (255, 0, 0),     // Red - right eye
                (0, 0, 255),     // Blue - left eye
                (255, 255, 0),   // Yellow - nose
                (255, 0, 255),   // Magenta - right mouth
                (0, 255, 255)    // Cyan - left mouth
            ]
            let landmarkNames = ["right_eye", "left_eye", "nose", "right_mouth", "left_mouth"]

            for (i, landmark) in landmarks.enumerated() {
                let color = landmarkColors[i]
                drawCircle(
                    in: &pixelData,
                    width: width,
                    height: height,
                    center: landmark,
                    radius: max(3, Int(bbox.width / 10)),
                    color: color
                )
                print("  \(landmarkNames[i]): (\(Int(landmark.x)), \(Int(landmark.y))) - \(i == 0 ? "RED" : i == 1 ? "BLUE" : i == 2 ? "YELLOW" : i == 3 ? "MAGENTA" : "CYAN")")
            }
        }

        // CGImage 생성
        guard let outputContext = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ),
        let outputImage = outputContext.makeImage() else {
            print("[Error] 출력 이미지 생성 실패")
            return nil
        }

        print("\n[Result] 랜드마크 시각화 완료")
        print("  - 녹색 박스: BBox")
        print("  - 빨강: right_eye, 파랑: left_eye")
        print("  - 노랑: nose")
        print("  - 마젠타: right_mouth, 시안: left_mouth")
        print(String(repeating: "=", count: 60))

        return UIImage(cgImage: outputImage)
    }

    /// 사각형 그리기 (픽셀 데이터에 직접)
    private func drawRect(
        in pixelData: inout [UInt8],
        width: Int,
        height: Int,
        rect: CGRect,
        color: (UInt8, UInt8, UInt8)
    ) {
        let bytesPerPixel = 4
        let x1 = max(0, Int(rect.origin.x))
        let y1 = max(0, Int(rect.origin.y))
        let x2 = min(width - 1, Int(rect.origin.x + rect.width))
        let y2 = min(height - 1, Int(rect.origin.y + rect.height))

        // 상단/하단 가로선
        for x in x1...x2 {
            for thickness in 0..<2 {
                // 상단
                let topY = min(y1 + thickness, height - 1)
                let topIdx = (topY * width + x) * bytesPerPixel
                pixelData[topIdx] = color.0
                pixelData[topIdx + 1] = color.1
                pixelData[topIdx + 2] = color.2

                // 하단
                let botY = max(y2 - thickness, 0)
                let botIdx = (botY * width + x) * bytesPerPixel
                pixelData[botIdx] = color.0
                pixelData[botIdx + 1] = color.1
                pixelData[botIdx + 2] = color.2
            }
        }

        // 좌측/우측 세로선
        for y in y1...y2 {
            for thickness in 0..<2 {
                // 좌측
                let leftX = min(x1 + thickness, width - 1)
                let leftIdx = (y * width + leftX) * bytesPerPixel
                pixelData[leftIdx] = color.0
                pixelData[leftIdx + 1] = color.1
                pixelData[leftIdx + 2] = color.2

                // 우측
                let rightX = max(x2 - thickness, 0)
                let rightIdx = (y * width + rightX) * bytesPerPixel
                pixelData[rightIdx] = color.0
                pixelData[rightIdx + 1] = color.1
                pixelData[rightIdx + 2] = color.2
            }
        }
    }

    /// 원 그리기 (픽셀 데이터에 직접)
    private func drawCircle(
        in pixelData: inout [UInt8],
        width: Int,
        height: Int,
        center: CGPoint,
        radius: Int,
        color: (UInt8, UInt8, UInt8)
    ) {
        let bytesPerPixel = 4
        let cx = Int(center.x)
        let cy = Int(center.y)

        for dy in -radius...radius {
            for dx in -radius...radius {
                if dx * dx + dy * dy <= radius * radius {
                    let x = cx + dx
                    let y = cy + dy
                    if x >= 0 && x < width && y >= 0 && y < height {
                        let idx = (y * width + x) * bytesPerPixel
                        pixelData[idx] = color.0
                        pixelData[idx + 1] = color.1
                        pixelData[idx + 2] = color.2
                    }
                }
            }
        }
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

    // MARK: - Test 3.5: Alignment Validation

    /// 정렬된 얼굴의 랜드마크가 ArcFace 템플릿과 일치하는지 검증합니다.
    ///
    /// 정렬이 제대로 됐다면, 정렬된 이미지에서 다시 얼굴 감지 시
    /// 랜드마크가 ArcFace 템플릿 좌표 근처에 있어야 합니다.
    private func testAlignmentValidation(alignedFaces: [CGImage]) -> TestResult {
        print("\n[Test 3.5] Alignment Validation (Landmark Position Check)")

        guard let detector = YuNetFaceDetector.shared else {
            return TestResult(
                testName: "Alignment Validation",
                passed: false,
                details: "YuNetFaceDetector 초기화 실패"
            )
        }

        // ArcFace 템플릿 좌표 (112×112 기준)
        let arcFaceTemplate: [CGPoint] = [
            CGPoint(x: 38.2946, y: 51.6963),   // right eye
            CGPoint(x: 73.5318, y: 51.5014),   // left eye
            CGPoint(x: 56.0252, y: 71.7366),   // nose
            CGPoint(x: 41.5493, y: 92.3655),   // right mouth
            CGPoint(x: 70.7299, y: 92.2041)    // left mouth
        ]

        var totalError: Float = 0
        var validCount = 0
        var details: [String] = []

        for (i, alignedFace) in alignedFaces.enumerated() {
            // 정렬된 이미지에서 다시 얼굴 감지
            guard let detections = try? detector.detect(in: alignedFace),
                  let detection = detections.first else {
                details.append("  [\(i)] 얼굴 감지 실패 ✗")
                continue
            }

            // 112×112 이미지에서의 랜드마크 좌표 (스케일 조정 불필요)
            let landmarks = detection.landmarks

            // 각 랜드마크와 템플릿 좌표의 오차 계산
            var faceError: Float = 0
            var landmarkErrors: [String] = []

            for (j, (detected, template)) in zip(landmarks, arcFaceTemplate).enumerated() {
                let dx = Float(detected.x - template.x)
                let dy = Float(detected.y - template.y)
                let error = sqrt(dx * dx + dy * dy)
                faceError += error

                let landmarkNames = ["R_eye", "L_eye", "nose", "R_mouth", "L_mouth"]
                landmarkErrors.append("\(landmarkNames[j])=\(String(format: "%.1f", error))")
            }

            let avgError = faceError / 5.0
            totalError += avgError
            validCount += 1

            let status = avgError < 10.0 ? "✓" : "✗"
            details.append("  [\(i)] avgError=\(String(format: "%.2f", avgError))px [\(landmarkErrors.joined(separator: ", "))] \(status)")
        }

        let overallAvgError = validCount > 0 ? totalError / Float(validCount) : Float.infinity
        let passed = overallAvgError < 10.0  // 평균 오차 10픽셀 이내면 합격

        print(details.joined(separator: "\n"))
        print("  Overall Average Error: \(String(format: "%.2f", overallAvgError))px")

        return TestResult(
            testName: "Alignment Validation",
            passed: passed,
            details: passed
                ? "정렬 정상 (평균 오차 \(String(format: "%.1f", overallAvgError))px)"
                : "정렬 문제 의심 (평균 오차 \(String(format: "%.1f", overallAvgError))px, 임계값 10px)"
        )
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

    // MARK: - Test 5: Self-Consistency

    /// SFace 임베딩의 자기 일관성을 테스트합니다.
    ///
    /// 모든 정렬된 얼굴에 대해 테스트하여 특정 얼굴만의 문제인지 확인합니다.
    /// 같은 이미지를 2번 임베딩하면 similarity ≈ 1.0이어야 하고,
    /// 1~2px shift한 이미지도 similarity가 높아야 합니다.
    private func testSelfConsistency(alignedFaces: [CGImage]) async -> TestResult {
        print("\n[Test 5] SFace Self-Consistency Test (All Faces)")

        guard let recognizer = SFaceRecognizer.shared else {
            return TestResult(
                testName: "Self-Consistency",
                passed: false,
                details: "SFaceRecognizer 초기화 실패"
            )
        }

        guard !alignedFaces.isEmpty else {
            return TestResult(
                testName: "Self-Consistency",
                passed: false,
                details: "테스트할 얼굴 이미지 없음"
            )
        }

        var passCount = 0
        var failCount = 0
        var failedIndices: [Int] = []

        // 각 얼굴에 대해 테스트
        for (faceIdx, face) in alignedFaces.enumerated() {
            print("\n  [Face \(faceIdx)] Self-Consistency Test")

            // 임베딩 추출 및 norm 확인
            guard let embedding = try? recognizer.extractEmbedding(from: face) else {
                print("    ❌ 임베딩 추출 실패")
                failCount += 1
                failedIndices.append(faceIdx)
                continue
            }

            let norm = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
            print("    norm = \(String(format: "%.3f", norm))")

            var faceAllPassed = true

            // Test: 1px Shift
            if let shiftedFace = createShiftedImage(face, dx: 1, dy: 0) {
                if let shiftedEmbedding = try? recognizer.extractEmbedding(from: shiftedFace) {
                    let sim1px = recognizer.cosineSimilarity(embedding, shiftedEmbedding)
                    let passed1px = sim1px > 0.95
                    let status1px = passed1px ? "✓" : "✗"
                    print("    1px shift: \(String(format: "%.4f", sim1px)) \(status1px)")
                    if !passed1px { faceAllPassed = false }
                }
            }

            // Test: 2px Shift
            if let shiftedFace = createShiftedImage(face, dx: 2, dy: 2) {
                if let shiftedEmbedding = try? recognizer.extractEmbedding(from: shiftedFace) {
                    let sim2px = recognizer.cosineSimilarity(embedding, shiftedEmbedding)
                    let passed2px = sim2px > 0.90
                    let status2px = passed2px ? "✓" : "✗"
                    print("    2px shift: \(String(format: "%.4f", sim2px)) \(status2px)")
                    if !passed2px { faceAllPassed = false }
                }
            }

            if faceAllPassed {
                passCount += 1
                print("    → PASS")
            } else {
                failCount += 1
                failedIndices.append(faceIdx)
                print("    → FAIL")
            }
        }

        // 결과 요약
        print("\n  Summary: \(passCount) passed, \(failCount) failed")
        if !failedIndices.isEmpty {
            print("  Failed faces: \(failedIndices)")
        }

        let allPassed = failCount == 0
        let details: String
        if allPassed {
            details = "모든 얼굴 일관성 정상 (\(passCount)/\(alignedFaces.count))"
        } else if failCount < alignedFaces.count {
            details = "일부 얼굴 불안정 (실패: \(failedIndices)) → 저품질 얼굴 필터링 필요"
        } else {
            details = "모든 얼굴 불안정 → Core ML 변환 검토 필요"
        }

        return TestResult(
            testName: "Self-Consistency",
            passed: allPassed,
            details: details
        )
    }

    // MARK: - Helper Methods for Self-Consistency Test

    /// 이미지를 dx, dy만큼 이동한 새 이미지 생성
    private func createShiftedImage(_ image: CGImage, dx: Int, dy: Int) -> CGImage? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        // 원본 픽셀 읽기
        var srcPixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let srcContext = CGContext(
            data: &srcPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        srcContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 이동된 픽셀 생성
        var dstPixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        for y in 0..<height {
            for x in 0..<width {
                let srcX = x - dx
                let srcY = y - dy

                if srcX >= 0 && srcX < width && srcY >= 0 && srcY < height {
                    let srcIdx = (srcY * width + srcX) * bytesPerPixel
                    let dstIdx = (y * width + x) * bytesPerPixel

                    dstPixels[dstIdx] = srcPixels[srcIdx]
                    dstPixels[dstIdx + 1] = srcPixels[srcIdx + 1]
                    dstPixels[dstIdx + 2] = srcPixels[srcIdx + 2]
                    dstPixels[dstIdx + 3] = srcPixels[srcIdx + 3]
                }
            }
        }

        // CGImage 생성
        guard let dstContext = CGContext(
            data: &dstPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return dstContext.makeImage()
    }

    /// 이미지를 수평 반전
    private func createHorizontallyFlippedImage(_ image: CGImage) -> CGImage? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel

        // 원본 픽셀 읽기
        var srcPixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)
        guard let srcContext = CGContext(
            data: &srcPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        srcContext.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // 수평 반전 픽셀 생성
        var dstPixels = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        for y in 0..<height {
            for x in 0..<width {
                let srcX = width - 1 - x
                let srcIdx = (y * width + srcX) * bytesPerPixel
                let dstIdx = (y * width + x) * bytesPerPixel

                dstPixels[dstIdx] = srcPixels[srcIdx]
                dstPixels[dstIdx + 1] = srcPixels[srcIdx + 1]
                dstPixels[dstIdx + 2] = srcPixels[srcIdx + 2]
                dstPixels[dstIdx + 3] = srcPixels[srcIdx + 3]
            }
        }

        // CGImage 생성
        guard let dstContext = CGContext(
            data: &dstPixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        return dstContext.makeImage()
    }
}

//
//  YuNetDecoder.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  YuNet 모델 출력을 디코딩하여 얼굴 감지 결과로 변환합니다.
//  Grid cell 기반 좌표 계산, BBox/Landmark 디코딩을 담당합니다.
//
//  Decoding Spec (OpenCV face_detect.cpp 기준):
//  - Score: sqrt(cls * obj), sigmoid 이미 적용됨 (clamp만 수행)
//  - BBox: center = (col + offset) * stride, size = exp(log_size) * stride
//  - Landmark: point = (offset + col/row) * stride
//  - 좌표계: 320×320 픽셀 좌표
//

import Foundation
import CoreML
import CoreGraphics

/// YuNet 출력 디코더
///
/// Core ML 모델 출력(MLMultiArray)을 파싱하여
/// YuNetDetection 배열로 변환합니다.
final class YuNetDecoder {

    // MARK: - Constants

    /// 입력 이미지 크기 (기본 320, 디버그 비교 시 960 등 가능)
    private let inputWidth: Int
    private let inputHeight: Int
    private let strides = YuNetConfig.strides         // [8, 16, 32]

    // MARK: - Initialization

    /// 디코더를 초기화합니다.
    /// - Parameter inputSize: 입력 이미지 크기 (기본: YuNetConfig.inputWidth)
    init(inputSize: Int = YuNetConfig.inputWidth) {
        self.inputWidth = inputSize
        self.inputHeight = inputSize
    }

    // MARK: - Public Methods

    /// 모델 출력을 디코딩하여 감지 결과를 반환합니다.
    ///
    /// - Parameters:
    ///   - outputs: Core ML 모델 출력 (MLFeatureProvider)
    ///   - scoreThreshold: 최소 신뢰도 임계값
    /// - Returns: 감지된 얼굴 배열 (320×320 픽셀 좌표)
    func decode(
        outputs: MLFeatureProvider,
        scoreThreshold: Float
    ) -> [YuNetDetection] {
        var detections: [YuNetDetection] = []

        // 각 stride별로 디코딩
        for stride in strides {
            let strideDetections = decodeStride(
                outputs: outputs,
                stride: stride,
                scoreThreshold: scoreThreshold
            )
            detections.append(contentsOf: strideDetections)
        }

        return detections
    }

    // MARK: - Private Methods - Stride Decoding

    /// 특정 stride의 출력을 디코딩합니다.
    ///
    /// - Parameters:
    ///   - outputs: Core ML 모델 출력
    ///   - stride: feature map stride (8, 16, 32)
    ///   - scoreThreshold: 최소 신뢰도 임계값
    /// - Returns: 해당 stride에서 감지된 얼굴들
    private func decodeStride(
        outputs: MLFeatureProvider,
        stride: Int,
        scoreThreshold: Float
    ) -> [YuNetDetection] {
        // Feature map 크기 계산
        let featureW = inputWidth / stride
        let featureH = inputHeight / stride

        // Core ML 출력 배열 가져오기
        let outputNames = YuNetOutputNames.outputs(for: stride)
        guard
            let clsArray = outputs.featureValue(for: outputNames.cls)?.multiArrayValue,
            let objArray = outputs.featureValue(for: outputNames.obj)?.multiArrayValue,
            let bboxArray = outputs.featureValue(for: outputNames.bbox)?.multiArrayValue,
            let kpsArray = outputs.featureValue(for: outputNames.kps)?.multiArrayValue
        else {
            return []
        }

        var detections: [YuNetDetection] = []
        let strideF = Float(stride)

        // Row-major 순서로 순회 (OpenCV 구현 기준)
        var idx = 0
        for row in 0..<featureH {
            for col in 0..<featureW {
                // 1. Score 계산 (sigmoid 이미 적용됨, clamp만 수행)
                let score = calculateScore(
                    clsArray: clsArray,
                    objArray: objArray,
                    index: idx
                )

                // Score 임계값 필터링
                if score < scoreThreshold {
                    idx += 1
                    continue
                }

                // 2. BBox 디코딩
                let bbox = decodeBBox(
                    bboxArray: bboxArray,
                    index: idx,
                    col: col,
                    row: row,
                    stride: strideF
                )

                // 3. Landmark 디코딩
                let landmarks = decodeLandmarks(
                    kpsArray: kpsArray,
                    index: idx,
                    col: col,
                    row: row,
                    stride: strideF
                )

                detections.append(YuNetDetection(
                    boundingBox: bbox,
                    landmarks: landmarks,
                    score: score
                ))

                idx += 1
            }
        }

        return detections
    }

    // MARK: - Private Methods - Score

    /// Score를 계산합니다.
    ///
    /// 공식: score = sqrt(clamp(cls) * clamp(obj))
    /// 모델 출력에 sigmoid가 이미 포함되어 있으므로 clamp만 수행합니다.
    ///
    /// - Parameters:
    ///   - clsArray: classification score 배열
    ///   - objArray: objectness score 배열
    ///   - index: 현재 cell 인덱스
    /// - Returns: 최종 신뢰도 점수 (0~1)
    private func calculateScore(
        clsArray: MLMultiArray,
        objArray: MLMultiArray,
        index: Int
    ) -> Float {
        // clamp to [0, 1] (sigmoid 이미 적용됨)
        let clsScore = min(max(clsArray[index].floatValue, 0), 1)
        let objScore = min(max(objArray[index].floatValue, 0), 1)

        // 최종 score = sqrt(cls * obj)
        return sqrt(clsScore * objScore)
    }

    // MARK: - Private Methods - BBox

    /// BBox를 디코딩합니다.
    ///
    /// OpenCV 구현 기준:
    /// - center_x = (col + dx) * stride
    /// - center_y = (row + dy) * stride
    /// - width = exp(dw) * stride
    /// - height = exp(dh) * stride
    ///
    /// - Parameters:
    ///   - bboxArray: bbox 출력 배열 [N, 4]
    ///   - index: 현재 cell 인덱스
    ///   - col: feature map x 좌표
    ///   - row: feature map y 좌표
    ///   - stride: 현재 stride 값
    /// - Returns: 디코딩된 바운딩 박스 (320×320 픽셀 좌표)
    private func decodeBBox(
        bboxArray: MLMultiArray,
        index: Int,
        col: Int,
        row: Int,
        stride: Float
    ) -> CGRect {
        // Row-major 인덱싱: bbox[idx * 4 + k]
        let baseIdx = index * 4
        let dx = bboxArray[baseIdx + 0].floatValue
        let dy = bboxArray[baseIdx + 1].floatValue
        let dw = bboxArray[baseIdx + 2].floatValue
        let dh = bboxArray[baseIdx + 3].floatValue

        // Center 좌표 계산 (픽셀 단위)
        let cx = (Float(col) + dx) * stride
        let cy = (Float(row) + dy) * stride

        // 크기 계산 (픽셀 단위)
        let w = exp(dw) * stride
        let h = exp(dh) * stride

        // Center → Corner 변환 (x, y, width, height)
        return CGRect(
            x: CGFloat(cx - w / 2),
            y: CGFloat(cy - h / 2),
            width: CGFloat(w),
            height: CGFloat(h)
        )
    }

    // MARK: - Private Methods - Landmarks

    /// 5-point Landmark를 디코딩합니다.
    ///
    /// OpenCV 구현 기준:
    /// - landmark_x = (offset_x + col) * stride
    /// - landmark_y = (offset_y + row) * stride
    ///
    /// 순서: right_eye, left_eye, nose, right_mouth, left_mouth
    ///
    /// - Parameters:
    ///   - kpsArray: keypoints 출력 배열 [N, 10]
    ///   - index: 현재 cell 인덱스
    ///   - col: feature map x 좌표
    ///   - row: feature map y 좌표
    ///   - stride: 현재 stride 값
    /// - Returns: 5개의 랜드마크 좌표 (320×320 픽셀 좌표)
    private func decodeLandmarks(
        kpsArray: MLMultiArray,
        index: Int,
        col: Int,
        row: Int,
        stride: Float
    ) -> [CGPoint] {
        var landmarks: [CGPoint] = []
        landmarks.reserveCapacity(5)

        // Row-major 인덱싱: kps[idx * 10 + k]
        let baseIdx = index * 10

        for i in 0..<5 {
            let offsetX = kpsArray[baseIdx + i * 2].floatValue
            let offsetY = kpsArray[baseIdx + i * 2 + 1].floatValue

            let lmX = (offsetX + Float(col)) * stride
            let lmY = (offsetY + Float(row)) * stride

            landmarks.append(CGPoint(x: CGFloat(lmX), y: CGFloat(lmY)))
        }

        return landmarks
    }
}

// MARK: - Coordinate Transformation

extension YuNetDecoder {
    /// 320×320 좌표를 원본 이미지 좌표로 변환합니다.
    ///
    /// - Parameters:
    ///   - detection: 320×320 좌표 기준 감지 결과
    ///   - scaleX: 원본 너비 / 320
    ///   - scaleY: 원본 높이 / 320
    /// - Returns: 원본 이미지 좌표 기준 감지 결과
    static func transformToOriginalCoordinates(
        _ detection: YuNetDetection,
        scaleX: Float,
        scaleY: Float
    ) -> YuNetDetection {
        // BBox 변환
        let originalBox = CGRect(
            x: detection.boundingBox.origin.x * CGFloat(scaleX),
            y: detection.boundingBox.origin.y * CGFloat(scaleY),
            width: detection.boundingBox.width * CGFloat(scaleX),
            height: detection.boundingBox.height * CGFloat(scaleY)
        )

        // Landmarks 변환
        let originalLandmarks = detection.landmarks.map { point in
            CGPoint(
                x: point.x * CGFloat(scaleX),
                y: point.y * CGFloat(scaleY)
            )
        }

        return YuNetDetection(
            boundingBox: originalBox,
            landmarks: originalLandmarks,
            score: detection.score
        )
    }
}

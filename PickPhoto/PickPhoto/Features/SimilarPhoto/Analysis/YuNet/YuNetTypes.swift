//
//  YuNetTypes.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  YuNet 얼굴 감지에 사용되는 타입 정의입니다.
//  Detection 결과, 에러, Core ML 출력 매핑 등을 포함합니다.
//

import Foundation
import CoreGraphics

// MARK: - Detection Result

/// YuNet 얼굴 감지 결과
///
/// 320×320 모델 좌표 또는 원본 이미지 좌표로 표현됩니다.
/// landmarks는 right_eye, left_eye, nose, right_mouth, left_mouth 순서입니다.
struct YuNetDetection: Equatable {
    /// 얼굴 바운딩 박스 (x, y, width, height)
    let boundingBox: CGRect

    /// 5-point 랜드마크 좌표
    /// 순서: right_eye, left_eye, nose, right_mouth, left_mouth
    let landmarks: [CGPoint]

    /// 감지 신뢰도 점수 (0~1)
    let score: Float

    /// 바운딩 박스 면적 (정렬용)
    var area: CGFloat {
        boundingBox.width * boundingBox.height
    }
}

// MARK: - Errors

/// YuNet 관련 에러
enum YuNetError: Error, LocalizedError {
    /// 모델 로드 실패
    case modelLoadFailed(String)

    /// 전처리 실패
    case preprocessingFailed(String)

    /// 잘못된 이미지 포맷
    case invalidImageFormat(String)

    /// 추론 실패
    case inferenceFailed(String)

    var errorDescription: String? {
        switch self {
        case .modelLoadFailed(let reason):
            return "YuNet 모델 로드 실패: \(reason)"
        case .preprocessingFailed(let reason):
            return "전처리 실패: \(reason)"
        case .invalidImageFormat(let reason):
            return "잘못된 이미지 포맷: \(reason)"
        case .inferenceFailed(let reason):
            return "추론 실패: \(reason)"
        }
    }
}

// MARK: - Configuration

/// YuNet 설정값
enum YuNetConfig {
    /// 입력 이미지 크기 (고정)
    static let inputWidth: Int = 320
    static let inputHeight: Int = 320

    /// Feature map stride 값들
    static let strides: [Int] = [8, 16, 32]

    /// NMS IoU 임계값 (OpenCV 기본값)
    static let nmsThreshold: Float = 0.3

    /// Score 임계값 (OpenCV 기본값)
    static let scoreThreshold: Float = 0.6

    /// 최대 반환 얼굴 수 (SimilarityConstants.maxFacesPerPhoto 사용)
    static var topK: Int {
        SimilarityConstants.maxFacesPerPhoto  // 현재 5
    }
}

// MARK: - Core ML Output Names

/// Core ML 출력 이름 매핑 (stride별)
///
/// YuNet ONNX → Core ML 변환 시 생성된 출력 이름입니다.
/// 각 stride(8, 16, 32)에 대해 cls, obj, bbox, kps 출력이 있습니다.
enum YuNetOutputNames {
    /// stride별 출력 이름 튜플
    struct OutputSet {
        let cls: String   // classification score
        let obj: String   // objectness score
        let bbox: String  // bounding box (dx, dy, dw, dh)
        let kps: String   // keypoints (5점 × 2좌표)
    }

    /// stride 8 출력 (40×40 feature map, 1600 cells)
    static let stride8 = OutputSet(
        cls: "var_762",
        obj: "var_813",
        bbox: "var_863",
        kps: "var_911"
    )

    /// stride 16 출력 (20×20 feature map, 400 cells)
    static let stride16 = OutputSet(
        cls: "var_779",
        obj: "var_830",
        bbox: "var_879",
        kps: "var_927"
    )

    /// stride 32 출력 (10×10 feature map, 100 cells)
    static let stride32 = OutputSet(
        cls: "var_796",
        obj: "var_847",
        bbox: "var_895",
        kps: "var_943"
    )

    /// stride 값으로 OutputSet 조회
    static func outputs(for stride: Int) -> OutputSet {
        switch stride {
        case 8: return stride8
        case 16: return stride16
        case 32: return stride32
        default: fatalError("Invalid stride: \(stride)")
        }
    }
}

// MARK: - Landmark Index

/// 랜드마크 인덱스 (가독성용)
enum LandmarkIndex: Int {
    case rightEye = 0
    case leftEye = 1
    case nose = 2
    case rightMouth = 3
    case leftMouth = 4
}

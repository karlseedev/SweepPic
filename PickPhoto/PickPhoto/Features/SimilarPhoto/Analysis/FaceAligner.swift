//
//  FaceAligner.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-15.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  YuNet 감지 결과의 5-point landmark를 사용하여 얼굴을 정렬합니다.
//  ArcFace 표준 템플릿에 맞춰 112×112 크기로 정렬된 얼굴 이미지를 생성합니다.
//
//  Algorithm:
//  1. Similarity Transform 계산 (SVD 기반 Procrustes Analysis)
//  2. CGAffineTransform으로 변환
//  3. 112×112 정렬된 얼굴 이미지 출력
//
//  Reference:
//  - OpenCV face_recognize.cpp (alignCrop)
//  - InsightFace face_align.py
//

import Foundation
import CoreGraphics
import Accelerate

/// 얼굴 정렬 에러
enum FaceAlignerError: Error, LocalizedError {
    /// 변환 행렬 계산 실패
    case transformCalculationFailed(String)

    /// 이미지 생성 실패
    case imageCreationFailed(String)

    /// 잘못된 랜드마크
    case invalidLandmarks(String)

    var errorDescription: String? {
        switch self {
        case .transformCalculationFailed(let reason):
            return "변환 행렬 계산 실패: \(reason)"
        case .imageCreationFailed(let reason):
            return "이미지 생성 실패: \(reason)"
        case .invalidLandmarks(let reason):
            return "잘못된 랜드마크: \(reason)"
        }
    }
}

/// 얼굴 정렬기
///
/// YuNet의 5-point landmark를 사용하여 얼굴을 ArcFace 표준 형태로 정렬합니다.
/// 출력은 112×112 RGB 이미지입니다.
final class FaceAligner {

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = FaceAligner()

    // MARK: - Constants

    /// 출력 이미지 크기
    static let outputSize: Int = 112

    /// ArcFace 5-Point 템플릿 좌표 (112×112 기준)
    /// 순서: right_eye, left_eye, nose, right_mouth, left_mouth
    ///
    /// 출처: InsightFace face_align.py
    /// 주의: 좌우 대칭이 아님 (실제 학습 데이터 기반)
    private static let arcFaceTemplate: [[Float]] = [
        [38.2946, 51.6963],   // right eye
        [73.5318, 51.5014],   // left eye
        [56.0252, 71.7366],   // nose tip
        [41.5493, 92.3655],   // right mouth corner
        [70.7299, 92.2041]    // left mouth corner
    ]

    // MARK: - Public Methods

    /// 얼굴을 정렬합니다.
    ///
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - landmarks: YuNet에서 감지된 5-point 랜드마크 (원본 이미지 좌표)
    /// - Returns: 정렬된 112×112 얼굴 이미지
    /// - Throws: FaceAlignerError
    func align(image: CGImage, landmarks: [CGPoint]) throws -> CGImage {
        // 랜드마크 검증
        guard landmarks.count == 5 else {
            throw FaceAlignerError.invalidLandmarks("5개의 랜드마크가 필요합니다 (현재: \(landmarks.count))")
        }

        // 1. 소스 랜드마크를 Float 배열로 변환
        let srcPoints = landmarks.map { [Float($0.x), Float($0.y)] }

        // 2. Similarity Transform 계산
        let transform = try estimateSimilarityTransform(
            src: srcPoints,
            dst: Self.arcFaceTemplate
        )

        // 3. 변환 적용하여 정렬된 이미지 생성
        let alignedImage = try applyTransform(
            to: image,
            transform: transform,
            outputSize: Self.outputSize
        )

        return alignedImage
    }

    /// 여러 얼굴을 정렬합니다.
    ///
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - detections: YuNet 감지 결과 배열
    /// - Returns: 정렬된 얼굴 이미지 배열 (감지 순서와 동일)
    func alignMultiple(
        image: CGImage,
        detections: [YuNetDetection]
    ) -> [CGImage?] {
        return detections.map { detection in
            try? align(image: image, landmarks: detection.landmarks)
        }
    }

    // MARK: - Private Methods - Similarity Transform

    /// Similarity Transform을 계산합니다 (SVD 기반 Procrustes Analysis).
    ///
    /// 소스 점들을 목표 점들에 최적으로 매핑하는 2D Similarity Transform을 찾습니다.
    /// Similarity Transform: rotation + uniform scaling + translation
    ///
    /// - Parameters:
    ///   - src: 소스 점 좌표 [[x, y], ...]
    ///   - dst: 목표 점 좌표 [[x, y], ...]
    /// - Returns: CGAffineTransform (역변환: 목표 좌표 → 소스 좌표)
    /// - Throws: FaceAlignerError.transformCalculationFailed
    private func estimateSimilarityTransform(
        src: [[Float]],
        dst: [[Float]]
    ) throws -> CGAffineTransform {
        let n = src.count
        guard n == dst.count, n >= 3 else {
            throw FaceAlignerError.transformCalculationFailed("최소 3개의 점이 필요합니다")
        }

        // 1. 중심점 계산
        let srcMean = meanPoint(src)
        let dstMean = meanPoint(dst)

        // 2. 중심 이동 (mean-centered)
        let srcCentered = src.map { [$0[0] - srcMean.0, $0[1] - srcMean.1] }
        let dstCentered = dst.map { [$0[0] - dstMean.0, $0[1] - dstMean.1] }

        // 3. 소스 분산 계산 (스케일 정규화용)
        let srcVar = variance(srcCentered)
        guard srcVar > 1e-6 else {
            throw FaceAlignerError.transformCalculationFailed("소스 점들이 너무 밀집되어 있습니다")
        }

        // 4. 공분산 행렬 H = src^T * dst
        let h = covarianceMatrix(srcCentered, dstCentered)

        // 5. SVD 분해: H = U * S * V^T
        let (u, s, vt) = try svdDecompose(h)

        // 6. 회전 행렬 R = V * U^T
        var r = matmul2x2(transpose2x2(vt), transpose2x2(u))

        // 반사 보정 (det(R) < 0인 경우)
        let det = determinant2x2(r)
        if det < 0 {
            // V의 마지막 행 부호 반전 후 다시 계산
            let vtFixed = [vt[0], [-vt[1][0], -vt[1][1]]]
            r = matmul2x2(transpose2x2(vtFixed), transpose2x2(u))
        }

        // 7. 스케일 계산: scale = trace(R * H) / var(src)
        let rh = matmul2x2(r, h)
        let trace = rh[0][0] + rh[1][1]
        let scale = trace / srcVar

        // 8. 이동 계산: t = dstMean - scale * R * srcMean
        let rotatedSrcMean = (
            r[0][0] * srcMean.0 + r[0][1] * srcMean.1,
            r[1][0] * srcMean.0 + r[1][1] * srcMean.1
        )
        let tx = dstMean.0 - scale * rotatedSrcMean.0
        let ty = dstMean.1 - scale * rotatedSrcMean.1

        // 9. CGAffineTransform 생성
        // 주의: Core Graphics는 역변환이 필요 (dst → src 방향)
        // 정변환: src → dst, 역변환: dst → src
        // CGContext.draw에서는 역변환 사용
        let forwardTransform = CGAffineTransform(
            a: CGFloat(scale * r[0][0]),
            b: CGFloat(scale * r[1][0]),
            c: CGFloat(scale * r[0][1]),
            d: CGFloat(scale * r[1][1]),
            tx: CGFloat(tx),
            ty: CGFloat(ty)
        )

        // 역변환 반환 (draw 시 사용)
        return forwardTransform.inverted()
    }

    // MARK: - Private Methods - Image Transform

    /// 변환을 적용하여 정렬된 이미지를 생성합니다.
    ///
    /// - Parameters:
    ///   - image: 원본 이미지
    ///   - transform: 적용할 CGAffineTransform (역변환)
    ///   - outputSize: 출력 이미지 크기
    /// - Returns: 변환된 이미지
    /// - Throws: FaceAlignerError.imageCreationFailed
    private func applyTransform(
        to image: CGImage,
        transform: CGAffineTransform,
        outputSize: Int
    ) throws -> CGImage {
        // Core Graphics 컨텍스트 생성
        guard let context = CGContext(
            data: nil,
            width: outputSize,
            height: outputSize,
            bitsPerComponent: 8,
            bytesPerRow: outputSize * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            throw FaceAlignerError.imageCreationFailed("CGContext 생성 실패")
        }

        // 배경을 검정으로 채우기 (경계 밖 영역)
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: outputSize, height: outputSize))

        // 변환 적용
        context.concatenate(transform)

        // 이미지 그리기
        context.interpolationQuality = .high
        context.draw(image, in: CGRect(
            x: 0,
            y: 0,
            width: image.width,
            height: image.height
        ))

        // 결과 이미지 생성
        guard let alignedImage = context.makeImage() else {
            throw FaceAlignerError.imageCreationFailed("정렬된 이미지 생성 실패")
        }

        return alignedImage
    }

    // MARK: - Private Methods - Math Utilities

    /// 점들의 평균 좌표를 계산합니다.
    private func meanPoint(_ points: [[Float]]) -> (Float, Float) {
        let n = Float(points.count)
        let sumX = points.reduce(0) { $0 + $1[0] }
        let sumY = points.reduce(0) { $0 + $1[1] }
        return (sumX / n, sumY / n)
    }

    /// 중심 이동된 점들의 분산을 계산합니다.
    private func variance(_ centeredPoints: [[Float]]) -> Float {
        var sum: Float = 0
        for p in centeredPoints {
            sum += p[0] * p[0] + p[1] * p[1]
        }
        return sum
    }

    /// 공분산 행렬을 계산합니다 (2×2).
    /// H = src^T * dst
    private func covarianceMatrix(
        _ src: [[Float]],
        _ dst: [[Float]]
    ) -> [[Float]] {
        var h: [[Float]] = [[0, 0], [0, 0]]
        for i in 0..<src.count {
            h[0][0] += src[i][0] * dst[i][0]
            h[0][1] += src[i][0] * dst[i][1]
            h[1][0] += src[i][1] * dst[i][0]
            h[1][1] += src[i][1] * dst[i][1]
        }
        return h
    }

    /// 2×2 SVD 분해 (간단한 구현).
    /// 복잡한 경우를 위해 Accelerate 사용 권장.
    private func svdDecompose(_ m: [[Float]]) throws -> (u: [[Float]], s: [Float], vt: [[Float]]) {
        // 2×2 SVD 직접 계산 (Jacobi rotation 기반)
        let a = m[0][0], b = m[0][1], c = m[1][0], d = m[1][1]

        // A^T * A 계산
        let ata00 = a * a + c * c
        let ata01 = a * b + c * d
        let ata11 = b * b + d * d

        // 고유값 계산 (characteristic equation)
        let trace = ata00 + ata11
        let det = ata00 * ata11 - ata01 * ata01
        let discriminant = sqrt(max(trace * trace / 4 - det, 0))

        let lambda1 = trace / 2 + discriminant
        let lambda2 = max(trace / 2 - discriminant, 0)

        // Singular values
        let s1 = sqrt(lambda1)
        let s2 = sqrt(lambda2)

        // V 계산 (A^T * A의 고유벡터)
        var v: [[Float]]
        if abs(ata01) > 1e-6 {
            let v1x = lambda1 - ata11
            let v1y = ata01
            let norm1 = sqrt(v1x * v1x + v1y * v1y)

            let v2x = lambda2 - ata11
            let v2y = ata01
            let norm2 = sqrt(v2x * v2x + v2y * v2y)

            v = [
                [v1x / norm1, v1y / norm1],
                [v2x / max(norm2, 1e-6), v2y / max(norm2, 1e-6)]
            ]
        } else {
            v = [[1, 0], [0, 1]]
        }

        // U = A * V * S^-1
        var u: [[Float]] = [[0, 0], [0, 0]]
        if s1 > 1e-6 {
            u[0][0] = (a * v[0][0] + b * v[0][1]) / s1
            u[1][0] = (c * v[0][0] + d * v[0][1]) / s1
        }
        if s2 > 1e-6 {
            u[0][1] = (a * v[1][0] + b * v[1][1]) / s2
            u[1][1] = (c * v[1][0] + d * v[1][1]) / s2
        } else {
            // s2가 0에 가까우면 u의 두 번째 열은 u의 첫 번째 열에 직교하도록 설정
            u[0][1] = -u[1][0]
            u[1][1] = u[0][0]
        }

        return (u, [s1, s2], transpose2x2(v))
    }

    /// 2×2 행렬 곱셈
    private func matmul2x2(_ a: [[Float]], _ b: [[Float]]) -> [[Float]] {
        return [
            [a[0][0] * b[0][0] + a[0][1] * b[1][0], a[0][0] * b[0][1] + a[0][1] * b[1][1]],
            [a[1][0] * b[0][0] + a[1][1] * b[1][0], a[1][0] * b[0][1] + a[1][1] * b[1][1]]
        ]
    }

    /// 2×2 행렬 전치
    private func transpose2x2(_ m: [[Float]]) -> [[Float]] {
        return [[m[0][0], m[1][0]], [m[0][1], m[1][1]]]
    }

    /// 2×2 행렬 행렬식
    private func determinant2x2(_ m: [[Float]]) -> Float {
        return m[0][0] * m[1][1] - m[0][1] * m[1][0]
    }
}

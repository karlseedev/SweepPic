//
//  SimilarityAnalysisQueue+ExtendedFallback.swift
//  PickPhoto
//
//  Created on 2026-01-17.
//
//  Extended Vision Fallback 로직
//  YuNet이 놓친 작은 얼굴을 Vision 결과로 보완합니다.
//

import Foundation
import AppCore
import CoreGraphics

// MARK: - Extended Fallback Helper

extension SimilarityAnalysisQueue {

    /// Extended Fallback: IoU 기반으로 YuNet이 놓친 Vision 얼굴을 찾습니다.
    ///
    /// ## 조건
    /// - YuNet이 1개 이상 감지했지만 Vision이 더 많이 감지한 경우
    /// - Vision 얼굴 중 YuNet과 IoU < 0.3이고 작은 얼굴(width < 0.07)만 추가
    /// - FP 리스크 최소화를 위해 작은 얼굴만 보완
    ///
    /// ## 상수
    /// - `iouThreshold`: 0.3 (IoU 30% 이상이면 동일 얼굴로 간주)
    /// - `smallFaceLimit`: 0.07 (전체 이미지 대비 7% 이하인 얼굴만 대상)
    ///
    /// - Parameters:
    ///   - yunetFaceData: YuNet이 감지한 얼굴 데이터 (faceIdx → boundingBox)
    ///   - visionFaces: Vision이 감지한 얼굴 목록
    ///   - assetID: 사진 ID (로그용)
    /// - Returns: 추가해야 할 Vision 얼굴 목록 (index, face)
    func findMissedSmallFaces(
        yunetFaceData: [Int: CGRect],
        visionFaces: [DetectedFace],
        assetID: String
    ) -> [(visionIdx: Int, face: DetectedFace)] {

        // 상수
        let iouThreshold: CGFloat = 0.3      // IoU 30% 이상이면 동일 얼굴로 간주
        let smallFaceLimit: CGFloat = 0.07   // 작은 얼굴 기준 (전체 이미지 대비 7%)

        var missedFaces: [(visionIdx: Int, face: DetectedFace)] = []

        for (visionIdx, visionFace) in visionFaces.enumerated() {
            let visionBox = visionFace.boundingBox

            // 작은 얼굴만 대상 (FP 방지)
            guard visionBox.width < smallFaceLimit else { continue }

            // YuNet 얼굴 중 IoU가 높은 것이 있는지 확인
            var hasOverlap = false
            for (_, yunetBox) in yunetFaceData {
                let iou = calculateIoU(box1: visionBox, box2: yunetBox)
                if iou >= iouThreshold {
                    hasOverlap = true
                    break
                }
            }

            if !hasOverlap {
                missedFaces.append((visionIdx: visionIdx, face: visionFace))
            }
        }

        // 로그 출력
        if !missedFaces.isEmpty {
            let shortID = String(assetID.prefix(8))
            Log.print("[ExtendedFallback] Photo \(shortID): YuNet=\(yunetFaceData.count), Vision=\(visionFaces.count), SmallMissed=\(missedFaces.count)")
            for missed in missedFaces {
                let size = missed.face.boundingBox.width
                let center = CGPoint(x: missed.face.boundingBox.midX, y: missed.face.boundingBox.midY)
                Log.print("[ExtendedFallback] +Vision[\(missed.visionIdx)] size=\(String(format: "%.2f", size)) at (\(String(format: "%.2f", center.x)), \(String(format: "%.2f", center.y)))")
            }
        }

        return missedFaces
    }

    /// 두 바운딩 박스의 IoU (Intersection over Union)를 계산합니다.
    ///
    /// - Parameters:
    ///   - box1: 첫 번째 박스 (정규화 좌표)
    ///   - box2: 두 번째 박스 (정규화 좌표)
    /// - Returns: IoU 값 (0.0 ~ 1.0)
    func calculateIoU(box1: CGRect, box2: CGRect) -> CGFloat {
        let intersection = box1.intersection(box2)

        // 교집합이 없으면 0
        guard !intersection.isNull && intersection.width > 0 && intersection.height > 0 else {
            return 0
        }

        let intersectionArea = intersection.width * intersection.height
        let box1Area = box1.width * box1.height
        let box2Area = box2.width * box2.height
        let unionArea = box1Area + box2Area - intersectionArea

        guard unionArea > 0 else { return 0 }

        return intersectionArea / unionArea
    }
}

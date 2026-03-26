//
//  FaceComparisonDebug.swift
//  SweepPic
//
//  Created by Claude on 2026-01-19.
//  Copyright © 2026 SweepPic. All rights reserved.
//
//  Description:
//  FaceComparisonViewController의 디버그 전용 코드입니다.
//  출시 전 이 파일을 삭제합니다.
//
//  포함 내용:
//  - 디버그 정보 생성 및 출력
//  - 관련 구조체들
//

import UIKit
import Photos
import AppCore

#if DEBUG

// MARK: - FaceComparisonDebugHelper

/// 얼굴 비교 화면 디버그 헬퍼
///
/// 디버그 버튼에서 호출되는 테스트 및 분석 기능을 제공합니다.
enum FaceComparisonDebugHelper {

    // Vision 비교 함수 제거됨 (runDetectionComparison, runVisionFallbackComparison, matchDetectedFaces)
    // YuNet 960이 Vision을 대체하여 더 이상 비교 불필요

    // MARK: - Debug Info Generation

    /// 디버그 정보를 생성합니다.
    /// 현재 그룹의 모든 사진과 얼굴 정보, SFace 매칭 cost를 출력합니다.
    ///
    /// - Parameters:
    ///   - allAssetIDs: 그룹 내 모든 사진 ID
    ///   - groupID: 그룹 ID
    ///   - validPersonIndices: 유효 인물 번호 목록
    ///   - currentPersonIndex: 현재 표시 중인 인물 번호
    /// - Returns: 디버그 정보 구조체
    static func generateDebugInfo(
        allAssetIDs: [String],
        groupID: String,
        validPersonIndices: [Int],
        currentPersonIndex: Int
    ) async -> FaceDebugInfo {
        // 기준 슬롯 정보 수집 (첫 번째 사진의 얼굴 위치)
        var referenceSlots: [FaceDebugSlot] = []
        var refSlotsWithFP: [DebugReferenceSlot] = []
        var photoDebugInfos: [PhotoDebugInfo] = []

        // 첫 번째 얼굴이 있는 사진 찾아서 기준 슬롯 설정
        for assetID in allAssetIDs {
            let faces = await SimilarityCache.shared.getFaces(for: assetID)
            if !faces.isEmpty {
                // 위치 기준 정렬 (X 오름차순, Y 내림차순)
                let sorted = faces.sorted { f1, f2 in
                    let xDiff = abs(f1.boundingBox.origin.x - f2.boundingBox.origin.x)
                    if xDiff > 0.05 {
                        return f1.boundingBox.origin.x < f2.boundingBox.origin.x
                    } else {
                        return f1.boundingBox.origin.y > f2.boundingBox.origin.y
                    }
                }

                for (idx, face) in sorted.enumerated() {
                    let center = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)

                    referenceSlots.append(FaceDebugSlot(
                        personIndex: idx + 1,
                        x: center.x,
                        y: center.y
                    ))

                    refSlotsWithFP.append(DebugReferenceSlot(
                        personIndex: idx + 1,
                        center: center
                    ))
                }
                break
            }
        }

        // UI 라벨 계산을 위한 personIndex별 카운터
        // UI에서 a1, a2, b1, b2 등의 번호는 해당 personIndex가 나타난 순서대로 부여됨
        var personPhotoCounter: [Int: Int] = [:]

        // 각 사진의 얼굴 정보 수집 (SFace 매칭 cost 포함)
        for assetID in allAssetIDs {
            let faces = await SimilarityCache.shared.getFaces(for: assetID)

            var faceDebugInfos: [FaceDebugEntry] = []
            for face in faces {
                let faceCenter = CGPoint(x: face.boundingBox.midX, y: face.boundingBox.midY)
                var posDistance: CGFloat = -1

                // 기준 슬롯 중 같은 personIndex 찾기 (위치 거리 계산용)
                for refSlot in refSlotsWithFP where refSlot.personIndex == face.personIndex {
                    posDistance = hypot(faceCenter.x - refSlot.center.x, faceCenter.y - refSlot.center.y)
                    break
                }

                // UI 라벨 계산 (예: "a1", "b2")
                // validPersonIndices에서 personIndex의 인덱스로 알파벳 결정
                let alphabetIndex = validPersonIndices.firstIndex(of: face.personIndex) ?? 0
                let alphabet = String(UnicodeScalar("a".unicodeScalars.first!.value + UInt32(alphabetIndex))!)

                // 해당 personIndex의 사진 번호 (1부터 시작)
                let photoNumber = (personPhotoCounter[face.personIndex] ?? 0) + 1
                personPhotoCounter[face.personIndex] = photoNumber

                let uiLabel = "\(alphabet)\(photoNumber)"

                // sfaceCost는 CachedFace에 저장된 값 사용 (분석 시점에 계산된 값)
                faceDebugInfos.append(FaceDebugEntry(
                    uiLabel: uiLabel,
                    personIndex: face.personIndex,
                    isValidSlot: face.isValidSlot,
                    x: face.boundingBox.origin.x,
                    y: face.boundingBox.origin.y,
                    width: face.boundingBox.width,
                    height: face.boundingBox.height,
                    posDistance: posDistance,
                    sfaceCost: face.sfaceCost
                ))
            }

            photoDebugInfos.append(PhotoDebugInfo(
                assetID: assetID,
                faces: faceDebugInfos
            ))
        }

        return FaceDebugInfo(
            groupID: groupID,
            currentPersonIndex: currentPersonIndex,
            validPersonIndices: validPersonIndices,
            positionThreshold: 0.15,
            greyZoneThreshold: SimilarityConstants.greyZoneThreshold,
            rejectThreshold: SimilarityConstants.personMatchThreshold,
            referenceSlots: referenceSlots,
            photos: photoDebugInfos
        )
    }

    /// 디버그 정보를 콘솔에 출력합니다.
    static func printDebugInfo(_ info: FaceDebugInfo) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        do {
            let jsonData = try encoder.encode(info)
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                print("")
                print("========== FACE DEBUG START ==========")
                print(jsonString)
                print("========== FACE DEBUG END ==========")
                print("")
            }
        } catch {
        }
    }
}

// MARK: - Debug Structures

/// 기준 슬롯 정보 (위치 거리 계산용, 내부 사용)
struct DebugReferenceSlot {
    let personIndex: Int
    let center: CGPoint
}

/// 얼굴 디버그 정보 (전체)
struct FaceDebugInfo: Codable {
    /// 그룹 ID
    let groupID: String
    /// 현재 표시 중인 인물 번호
    let currentPersonIndex: Int
    /// 유효 인물 번호 목록
    let validPersonIndices: [Int]
    /// 위치 매칭 임계값 (0.15)
    let positionThreshold: Double
    /// SFace 확신 구간 임계값 (cost < 이 값이면 확신 매칭)
    let greyZoneThreshold: Float
    /// SFace 거절 임계값 (cost >= 이 값이면 거절)
    let rejectThreshold: Float
    /// 기준 슬롯 정보 (첫 번째 사진의 얼굴 위치)
    let referenceSlots: [FaceDebugSlot]
    /// 사진별 얼굴 정보
    let photos: [PhotoDebugInfo]
}

/// 기준 슬롯 정보
struct FaceDebugSlot: Codable {
    /// 인물 번호
    let personIndex: Int
    /// 중심 X 좌표 (정규화)
    let x: CGFloat
    /// 중심 Y 좌표 (정규화)
    let y: CGFloat
}

/// 사진별 디버그 정보
struct PhotoDebugInfo: Codable {
    /// 사진 ID
    let assetID: String
    /// 얼굴 목록
    let faces: [FaceDebugEntry]
}

/// 얼굴 디버그 정보
struct FaceDebugEntry: Codable {
    /// UI에 표시되는 라벨 (예: "a1", "b2")
    let uiLabel: String
    /// 할당된 인물 번호
    let personIndex: Int
    /// 유효 슬롯 여부
    let isValidSlot: Bool
    /// bounding box X (정규화)
    let x: CGFloat
    /// bounding box Y (정규화)
    let y: CGFloat
    /// bounding box 너비 (정규화)
    let width: CGFloat
    /// bounding box 높이 (정규화)
    let height: CGFloat
    /// 기준 슬롯과의 위치 거리 (-1이면 매칭된 슬롯 없음)
    let posDistance: CGFloat
    /// SFace 코사인 유사도 기반 거리 (nil이면 기준 사진 또는 계산 실패)
    /// 값: 1 - cosineSimilarity (0에 가까울수록 동일인)
    let sfaceCost: Float?
}

#endif

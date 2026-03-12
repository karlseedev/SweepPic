//
//  FaceComparisonDebug.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-19.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  FaceComparisonViewController의 디버그 전용 코드입니다.
//  출시 전 이 파일을 삭제합니다.
//
//  포함 내용:
//  - YuNet vs Vision 감지 비교 테스트
//  - Vision fallback ON/OFF 비교 테스트
//  - 디버그 정보 생성 및 출력
//  - 관련 구조체들
//

import UIKit
import Photos
import Vision
import AppCore

#if DEBUG

// MARK: - FaceComparisonDebugHelper

/// 얼굴 비교 화면 디버그 헬퍼
///
/// 디버그 버튼에서 호출되는 테스트 및 분석 기능을 제공합니다.
enum FaceComparisonDebugHelper {

    // MARK: - YuNet vs Vision Detection Comparison

    /// YuNet vs Vision 얼굴 감지 비교를 실행합니다.
    /// - Parameter photos: 비교할 사진 배열
    static func runDetectionComparison(with photos: [PHAsset]) async {
        print("")
        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║         FACE DETECTION COMPARISON: YuNet vs Vision               ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        // 통계
        var totalPhotos = 0
        var yunetOnlyCount = 0      // YuNet만 감지
        var visionOnlyCount = 0     // Vision만 감지
        var bothCount = 0           // 둘 다 감지
        var neitherCount = 0        // 둘 다 미감지

        let imageLoader = SimilarityImageLoader.shared
        let visionDetector = FaceDetector.shared
        guard let yunetDetector = YuNetFaceDetector.shared else {
            print("║ ✗ YuNet detector not available")
            print("╚══════════════════════════════════════════════════════════════════╝")
            return
        }

        // 임의의 뷰어 크기 (5% 필터용)
        let viewerSize = CGSize(width: 390, height: 844)

        for photo in photos {
            totalPhotos += 1
            let shortID = String(photo.localIdentifier.prefix(8))

            do {
                // 이미지 로드
                let cgImage = try await imageLoader.loadImage(for: photo)

                // Vision 감지
                let visionFaces = try await visionDetector.detectFaces(in: photo)

                // YuNet 감지
                let yunetFaces = try yunetDetector.detect(in: cgImage)

                // 결과 분석
                let visionCount = visionFaces.count
                let yunetCount = yunetFaces.count

                // 이미지 크기 (YuNet 좌표 정규화용)
                let imageSize = CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))

                // 위치 기반 매칭으로 공통/개별 얼굴 판별
                let matchResult = matchDetectedFaces(
                    yunetFaces: yunetFaces,
                    visionFaces: visionFaces,
                    imageSize: imageSize
                )

                // 통계 업데이트
                yunetOnlyCount += matchResult.yunetOnly.count
                visionOnlyCount += matchResult.visionOnly.count
                bothCount += matchResult.matched.count

                if visionCount == 0 && yunetCount == 0 {
                    neitherCount += 1
                }

                // 로그 출력
                let statusIcon: String
                if matchResult.yunetOnly.isEmpty && matchResult.visionOnly.isEmpty {
                    statusIcon = "✓"  // 완전 일치
                } else if !matchResult.visionOnly.isEmpty {
                    statusIcon = "⚠️"  // Vision만 감지한 얼굴 있음 (YuNet 미검출)
                } else {
                    statusIcon = "○"  // YuNet만 감지 (오탐 가능성)
                }

                print("║ \(statusIcon) Photo \(shortID): YuNet=\(yunetCount), Vision=\(visionCount) | " +
                      "Both=\(matchResult.matched.count), YuNet-only=\(matchResult.yunetOnly.count), " +
                      "Vision-only=\(matchResult.visionOnly.count)")

                // Vision-only 얼굴 상세 출력 (YuNet 미검출 케이스)
                for (idx, visionFace) in matchResult.visionOnly.enumerated() {
                    let bbox = visionFace.boundingBox
                    print("║   └─ [Vision-only #\(idx+1)] bbox: (\(String(format: "%.2f", bbox.origin.x)), " +
                          "\(String(format: "%.2f", bbox.origin.y))), size: \(String(format: "%.2f", bbox.width))x" +
                          "\(String(format: "%.2f", bbox.height))")
                }

                // YuNet-only 얼굴 상세 출력 (정규화 좌표 포함)
                for (idx, yunetFace) in matchResult.yunetOnly.enumerated() {
                    let bbox = yunetFace.boundingBox
                    // 정규화 좌표 계산 (Y축 반전)
                    let normX = bbox.midX / imageSize.width
                    let normY = 1.0 - (bbox.midY / imageSize.height)
                    print("║   └─ [YuNet-only #\(idx+1)] norm: (\(String(format: "%.2f", normX)), " +
                          "\(String(format: "%.2f", normY))), px: (\(String(format: "%.0f", bbox.origin.x)), " +
                          "\(String(format: "%.0f", bbox.origin.y))), score: \(String(format: "%.2f", yunetFace.score))")
                }

            } catch {
                print("║ ✗ Photo \(shortID): Error - \(error.localizedDescription)")
            }
        }

        // 요약 출력
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║                           SUMMARY                                ║")
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Total Photos: \(totalPhotos)")
        print("║ Faces detected by BOTH: \(bothCount)")
        print("║ Faces detected by YuNet ONLY: \(yunetOnlyCount) (possible false positives)")
        print("║ Faces detected by Vision ONLY: \(visionOnlyCount) ← YuNet missed these!")
        print("║ Photos with NO faces: \(neitherCount)")
        print("╚══════════════════════════════════════════════════════════════════╝")
        print("")
    }

    // MARK: - Vision Fallback Comparison

    /// Vision fallback ON/OFF 비교 테스트를 실행합니다.
    /// - Parameter photos: 테스트할 사진 배열
    static func runVisionFallbackComparison(with photos: [PHAsset]) async {
        print("")
        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║         VISION FALLBACK COMPARISON TEST                          ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        let visionDetector = FaceDetector.shared
        let viewerSize = CGSize(width: 390, height: 844)

        // Step 1: Vision으로 rawFacesMap 생성
        var rawFacesMap: [String: [DetectedFace]] = [:]
        for photo in photos {
            let assetID = photo.localIdentifier
            let shortID = String(assetID.prefix(8))
            do {
                let faces = try await visionDetector.detectFaces(in: photo)
                rawFacesMap[assetID] = faces
                print("║ Photo \(shortID): Vision detected \(faces.count) faces")
            } catch {
                print("║ Photo \(shortID): Vision detection failed - \(error.localizedDescription)")
                rawFacesMap[assetID] = []
            }
        }

        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Running matching with Vision Fallback OFF...                     ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        // Step 2: Vision fallback OFF/ON으로 매칭 실행
        let (resultOff, resultOn) = await SimilarityAnalysisQueue.shared.testVisionFallback(
            photos: photos,
            rawFacesMap: rawFacesMap
        )

        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Running matching with Vision Fallback ON...                      ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        // Step 3: 결과 비교
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║                        COMPARISON RESULT                         ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        var totalFacesOff = 0
        var totalFacesOn = 0
        var photosWithDiff = 0

        for photo in photos {
            let assetID = photo.localIdentifier
            let shortID = String(assetID.prefix(8))
            let facesOff = resultOff[assetID]?.count ?? 0
            let facesOn = resultOn[assetID]?.count ?? 0
            totalFacesOff += facesOff
            totalFacesOn += facesOn

            let diff = facesOn - facesOff
            if diff != 0 {
                photosWithDiff += 1
                print("║ ⚡ Photo \(shortID): OFF=\(facesOff), ON=\(facesOn) (+\(diff) faces)")
            } else {
                print("║   Photo \(shortID): OFF=\(facesOff), ON=\(facesOn)")
            }
        }

        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║                           SUMMARY                                ║")
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Total Photos: \(photos.count)")
        print("║ Fallback OFF: \(totalFacesOff) faces matched")
        print("║ Fallback ON:  \(totalFacesOn) faces matched")
        print("║ Difference:   +\(totalFacesOn - totalFacesOff) faces")
        print("║ Photos with difference: \(photosWithDiff)")
        print("╚══════════════════════════════════════════════════════════════════╝")
        print("")
    }

    // MARK: - Face Matching

    /// YuNet과 Vision 얼굴 감지 결과를 위치 기반으로 매칭합니다.
    ///
    /// 좌표계 차이:
    /// - Vision: 정규화 좌표 (0~1), 원점 좌하단, Y가 위로 증가
    /// - YuNet: 픽셀 좌표, 원점 좌상단, Y가 아래로 증가
    ///
    /// - Parameters:
    ///   - yunetFaces: YuNet 감지 결과 (픽셀 좌표)
    ///   - visionFaces: Vision 감지 결과 (정규화 좌표)
    ///   - imageSize: 원본 이미지 크기 (좌표 변환용)
    /// - Returns: 매칭 결과 (공통, YuNet만, Vision만)
    static func matchDetectedFaces(
        yunetFaces: [YuNetDetection],
        visionFaces: [DetectedFace],
        imageSize: CGSize
    ) -> DetectionMatchResult {
        var matched: [(yunet: YuNetDetection, vision: DetectedFace)] = []
        var yunetOnly: [YuNetDetection] = []
        var visionOnly: [DetectedFace] = []

        // 매칭 임계값 (정규화 좌표 기준 중심 거리)
        let matchThreshold: CGFloat = 0.15

        var usedVisionIndices: Set<Int> = []

        // YuNet 얼굴마다 가장 가까운 Vision 얼굴 찾기
        for yunetFace in yunetFaces {
            // YuNet 좌표 정규화 + Y축 반전 (좌상단→좌하단 변환)
            let yunetNormX = yunetFace.boundingBox.midX / imageSize.width
            let yunetNormY = 1.0 - (yunetFace.boundingBox.midY / imageSize.height)
            let yunetCenter = CGPoint(x: yunetNormX, y: yunetNormY)

            var bestMatch: (index: Int, distance: CGFloat)? = nil

            for (vIdx, visionFace) in visionFaces.enumerated() {
                if usedVisionIndices.contains(vIdx) { continue }

                // Vision 좌표는 이미 정규화되어 있음 (좌하단 원점)
                let visionCenter = CGPoint(
                    x: visionFace.boundingBox.midX,
                    y: visionFace.boundingBox.midY
                )

                let distance = hypot(yunetCenter.x - visionCenter.x, yunetCenter.y - visionCenter.y)

                if distance < matchThreshold {
                    if bestMatch == nil || distance < bestMatch!.distance {
                        bestMatch = (vIdx, distance)
                    }
                }
            }

            if let match = bestMatch {
                matched.append((yunetFace, visionFaces[match.index]))
                usedVisionIndices.insert(match.index)
            } else {
                yunetOnly.append(yunetFace)
            }
        }

        // 매칭 안 된 Vision 얼굴
        for (vIdx, visionFace) in visionFaces.enumerated() {
            if !usedVisionIndices.contains(vIdx) {
                visionOnly.append(visionFace)
            }
        }

        return DetectionMatchResult(
            matched: matched,
            yunetOnly: yunetOnly,
            visionOnly: visionOnly
        )
    }

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

/// YuNet vs Vision 얼굴 감지 비교 결과
struct DetectionMatchResult {
    /// 둘 다 감지한 얼굴 (위치 매칭)
    let matched: [(yunet: YuNetDetection, vision: DetectedFace)]
    /// YuNet만 감지한 얼굴 (Vision 미검출 또는 오탐)
    let yunetOnly: [YuNetDetection]
    /// Vision만 감지한 얼굴 (YuNet 미검출)
    let visionOnly: [DetectedFace]
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

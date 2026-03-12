//
//  ExtendedFallbackTester.swift
//  PickPhoto
//
//  Created on 2026-01-18.
//
//  Extended Vision Fallback 테스트 도구
//  Basic vs Extended 모드를 비교하여 Extended의 효과를 확인합니다.
//

import Foundation
import Photos

// MARK: - Extended Fallback Tester

/// Extended Vision Fallback 테스트 도구
///
/// ## 기능
/// - Basic vs Extended 모드 비교 테스트
/// - 각 모드별 매칭된 얼굴 수, personIndex 분포 비교
/// - 콘솔 로그로 결과 출력
///
/// ## 사용법
/// ```swift
/// await ExtendedFallbackTester.shared.runComparison(with: photos)
/// ```
#if DEBUG

class ExtendedFallbackTester {

    // MARK: - Singleton

    static let shared = ExtendedFallbackTester()
    private init() {}

    // MARK: - Public API

    /// Basic vs Extended 모드 비교 테스트를 실행합니다.
    ///
    /// ## 테스트 절차
    /// 1. Vision으로 rawFacesMap 생성
    /// 2. testVisionFallbackExtended API 호출 (Basic/Extended 동시 실행)
    /// 3. 결과 비교 (얼굴 수, personIndex 분포)
    ///
    /// - Parameter photos: 테스트할 사진 배열
    func runComparison(with photos: [PHAsset]) async {
        print("")
        print("╔══════════════════════════════════════════════════════════════════╗")
        print("║       EXTENDED VISION FALLBACK COMPARISON TEST                   ║")
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Mode: Basic (.basic) vs Extended (.extended)                     ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        // Step 1: Vision으로 rawFacesMap 생성
        print("║ Step 1: Detecting faces with Vision...                           ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        let rawFacesMap = await detectFacesWithVision(photos: photos)

        // Step 2: Basic vs Extended 매칭 실행
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Step 2: Running matching (Basic & Extended)...                   ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        let (resultBasic, resultExtended) = await SimilarityAnalysisQueue.shared.testVisionFallbackExtended(
            photos: photos,
            rawFacesMap: rawFacesMap
        )

        // Step 3: 결과 비교
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Step 3: Comparing results...                                     ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        compareResults(
            photos: photos,
            basic: resultBasic,
            extended: resultExtended
        )

        print("")
    }

    // MARK: - Private Helpers

    /// Vision으로 rawFacesMap을 생성합니다.
    private func detectFacesWithVision(photos: [PHAsset]) async -> [String: [DetectedFace]] {
        let visionDetector = FaceDetector.shared
        let viewerSize = CGSize(width: 390, height: 844)

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

        return rawFacesMap
    }

    /// Basic과 Extended 결과를 비교합니다.
    private func compareResults(
        photos: [PHAsset],
        basic: [String: [CachedFace]],
        extended: [String: [CachedFace]]
    ) {
        var totalFacesBasic = 0
        var totalFacesExtended = 0
        var photosWithDiff = 0

        // personIndex 분포 집계
        var personIndicesBasic: [Int: Int] = [:]   // personIndex → count
        var personIndicesExtended: [Int: Int] = [:]

        for photo in photos {
            let assetID = photo.localIdentifier
            let shortID = String(assetID.prefix(8))

            let facesBasic = basic[assetID] ?? []
            let facesExtended = extended[assetID] ?? []

            totalFacesBasic += facesBasic.count
            totalFacesExtended += facesExtended.count

            // personIndex 집계
            for face in facesBasic {
                personIndicesBasic[face.personIndex, default: 0] += 1
            }
            for face in facesExtended {
                personIndicesExtended[face.personIndex, default: 0] += 1
            }

            // 개별 사진 비교
            let diff = facesExtended.count - facesBasic.count
            if diff != 0 {
                photosWithDiff += 1
                let sign = diff > 0 ? "+" : ""
                print("║ ⚡ Photo \(shortID): Basic=\(facesBasic.count), Extended=\(facesExtended.count) (\(sign)\(diff))")

                // Extended에서 추가된 얼굴 상세 정보
                if diff > 0 {
                    // Extended에만 있는 얼굴 찾기 (center 위치 기준)
                    let basicCenters = Set(facesBasic.map { "\($0.center.x),\($0.center.y)" })
                    let addedFaces = facesExtended.filter { !basicCenters.contains("\($0.center.x),\($0.center.y)") }

                    for added in addedFaces {
                        let pos = added.center
                        print("║   +Extended: personIdx=\(added.personIndex), pos=(\(String(format: "%.2f", pos.x)), \(String(format: "%.2f", pos.y)))")
                    }
                }
            } else {
                print("║   Photo \(shortID): Basic=\(facesBasic.count), Extended=\(facesExtended.count)")
            }
        }

        // Summary
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║                           SUMMARY                                ║")
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║ Total Photos: \(photos.count)")
        print("║ Basic mode:    \(totalFacesBasic) faces matched")
        print("║ Extended mode: \(totalFacesExtended) faces matched")

        let diff = totalFacesExtended - totalFacesBasic
        let sign = diff >= 0 ? "+" : ""
        print("║ Difference:    \(sign)\(diff) faces")
        print("║ Photos with difference: \(photosWithDiff)")

        // personIndex 분포 비교
        print("╠══════════════════════════════════════════════════════════════════╣")
        print("║                    PERSON INDEX DISTRIBUTION                     ║")
        print("╠══════════════════════════════════════════════════════════════════╣")

        let allPersonIndices = Set(personIndicesBasic.keys).union(Set(personIndicesExtended.keys))
        let sortedIndices = allPersonIndices.sorted()

        for idx in sortedIndices {
            let basicCount = personIndicesBasic[idx] ?? 0
            let extendedCount = personIndicesExtended[idx] ?? 0
            let diffCount = extendedCount - basicCount

            if diffCount != 0 {
                let diffSign = diffCount > 0 ? "+" : ""
                print("║ ⚡ Person \(idx): Basic=\(basicCount), Extended=\(extendedCount) (\(diffSign)\(diffCount))")
            } else {
                print("║   Person \(idx): Basic=\(basicCount), Extended=\(extendedCount)")
            }
        }

        print("║ Total slots: Basic=\(personIndicesBasic.count), Extended=\(personIndicesExtended.count)")
        print("╚══════════════════════════════════════════════════════════════════╝")
    }
}

#endif

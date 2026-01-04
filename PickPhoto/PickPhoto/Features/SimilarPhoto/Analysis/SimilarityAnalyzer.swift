// SimilarityAnalyzer.swift
// Vision Framework 유사도 분석 엔진
//
// T010: SimilarityAnalyzer 생성
// - VNGenerateImageFeaturePrintRequest 유사도 분석
// - Feature Print 생성 및 거리 계산

import Foundation
import Vision
import UIKit

/// 유사도 분석기
/// Vision Framework를 사용하여 이미지 간 유사도 측정
final class SimilarityAnalyzer {

    // MARK: - Constants

    /// 유사도 임계값 (Feature Print 거리)
    /// - 거리 10.0 이하면 유사 사진으로 판단
    static let similarityThreshold: Float = 10.0

    /// 얼굴 Feature Print 매칭 임계값
    /// - 거리 1.0 이하면 동일 인물로 판단
    static let faceMatchThreshold: Float = 1.0

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = SimilarityAnalyzer()

    // MARK: - Properties

    /// Feature Print 캐시 (assetID -> VNFeaturePrintObservation)
    /// - 메모리 효율을 위해 LRU 캐시 사용 권장
    private var featurePrintCache: [String: VNFeaturePrintObservation] = [:]

    /// 캐시 접근 동기화용 락
    private let cacheLock = NSLock()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 이미지 Feature Print 생성
    /// - Parameters:
    ///   - cgImage: 분석할 CGImage
    ///   - assetID: 캐싱용 사진 ID (옵션)
    /// - Returns: Feature Print (실패 시 nil)
    func generateFeaturePrint(
        from cgImage: CGImage,
        assetID: String? = nil
    ) -> VNFeaturePrintObservation? {
        // 캐시 확인
        if let assetID = assetID {
            cacheLock.lock()
            if let cached = featurePrintCache[assetID] {
                cacheLock.unlock()
                return cached
            }
            cacheLock.unlock()
        }

        // Feature Print 요청 생성
        let request = VNGenerateImageFeaturePrintRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let result = request.results?.first as? VNFeaturePrintObservation else {
                print("[SimilarityAnalyzer] No feature print result")
                return nil
            }

            // 캐시 저장
            if let assetID = assetID {
                cacheLock.lock()
                featurePrintCache[assetID] = result
                cacheLock.unlock()
            }

            return result

        } catch {
            print("[SimilarityAnalyzer] Feature print generation failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 두 Feature Print 간 거리 계산
    /// - Parameters:
    ///   - fp1: 첫 번째 Feature Print
    ///   - fp2: 두 번째 Feature Print
    /// - Returns: 거리 값 (실패 시 nil)
    func computeDistance(
        between fp1: VNFeaturePrintObservation,
        and fp2: VNFeaturePrintObservation
    ) -> Float? {
        var distance: Float = 0

        do {
            try fp1.computeDistance(&distance, to: fp2)
            return distance
        } catch {
            print("[SimilarityAnalyzer] Distance computation failed: \(error.localizedDescription)")
            return nil
        }
    }

    /// 두 이미지 간 유사도 비교
    /// - Parameters:
    ///   - image1: 첫 번째 CGImage
    ///   - image2: 두 번째 CGImage
    /// - Returns: 유사 여부 (거리 10.0 이하)
    func areSimilar(image1: CGImage, image2: CGImage) -> Bool {
        guard let fp1 = generateFeaturePrint(from: image1),
              let fp2 = generateFeaturePrint(from: image2),
              let distance = computeDistance(between: fp1, and: fp2) else {
            return false
        }

        return distance <= Self.similarityThreshold
    }

    /// 기준 이미지와 비교 대상 이미지들의 유사도 계산
    /// - Parameters:
    ///   - referenceImage: 기준 CGImage
    ///   - targetImages: 비교 대상 CGImage 배열
    /// - Returns: 각 대상과의 거리 배열 (실패 시 Float.infinity)
    func computeDistances(
        reference referenceImage: CGImage,
        targets targetImages: [CGImage]
    ) -> [Float] {
        guard let referenceFP = generateFeaturePrint(from: referenceImage) else {
            return [Float](repeating: Float.infinity, count: targetImages.count)
        }

        return targetImages.map { targetImage in
            guard let targetFP = generateFeaturePrint(from: targetImage),
                  let distance = computeDistance(between: referenceFP, and: targetFP) else {
                return Float.infinity
            }
            return distance
        }
    }

    // MARK: - Cache Management

    /// Feature Print 캐시 정리
    /// - Parameter assetIDs: 정리할 사진 ID 배열 (nil이면 전체 정리)
    func clearCache(for assetIDs: [String]? = nil) {
        cacheLock.lock()
        defer { cacheLock.unlock() }

        if let assetIDs = assetIDs {
            for assetID in assetIDs {
                featurePrintCache.removeValue(forKey: assetID)
            }
        } else {
            featurePrintCache.removeAll()
        }
    }

    /// 캐시된 Feature Print 가져오기
    func getCachedFeaturePrint(for assetID: String) -> VNFeaturePrintObservation? {
        cacheLock.lock()
        defer { cacheLock.unlock() }
        return featurePrintCache[assetID]
    }
}

// MARK: - Group Analysis

extension SimilarityAnalyzer {

    /// 연속 사진 그룹의 유사도 분석
    /// - Parameters:
    ///   - images: 분석할 CGImage 배열 (인덱스 순서)
    ///   - assetIDs: 각 이미지의 사진 ID
    /// - Returns: 유사 사진 그룹 배열 (각 그룹은 연속된 인덱스 배열)
    func analyzeGroupSimilarity(
        images: [CGImage],
        assetIDs: [String]
    ) -> [[Int]] {
        guard images.count >= 3 else { return [] }
        guard images.count == assetIDs.count else { return [] }

        // Feature Print 생성
        var featurePrints: [VNFeaturePrintObservation?] = []
        for (index, image) in images.enumerated() {
            let fp = generateFeaturePrint(from: image, assetID: assetIDs[index])
            featurePrints.append(fp)
        }

        // 인접 사진 유사도 비교
        var similarFlags: [Bool] = [] // i번째와 i+1번째가 유사한지
        for i in 0..<(images.count - 1) {
            guard let fp1 = featurePrints[i],
                  let fp2 = featurePrints[i + 1],
                  let distance = computeDistance(between: fp1, and: fp2) else {
                similarFlags.append(false)
                continue
            }
            similarFlags.append(distance <= Self.similarityThreshold)
        }

        // 연속 유사 구간 추출
        var groups: [[Int]] = []
        var currentGroup: [Int] = [0]

        for (index, isSimilar) in similarFlags.enumerated() {
            if isSimilar {
                currentGroup.append(index + 1)
            } else {
                if currentGroup.count >= 3 {
                    groups.append(currentGroup)
                }
                currentGroup = [index + 1]
            }
        }

        // 마지막 그룹 처리
        if currentGroup.count >= 3 {
            groups.append(currentGroup)
        }

        return groups
    }

    /// 그룹 분석 결과를 SimilarThumbnailGroup으로 변환
    /// - Parameters:
    ///   - groups: 인덱스 그룹 배열
    ///   - assetIDs: 전체 사진 ID 배열
    /// - Returns: SimilarThumbnailGroup 배열
    func convertToThumbnailGroups(
        groups: [[Int]],
        assetIDs: [String]
    ) -> [SimilarThumbnailGroup] {
        return groups.map { indices in
            let memberIDs = indices.map { assetIDs[$0] }
            return SimilarThumbnailGroup(memberAssetIDs: memberIDs)
        }
    }
}

// MARK: - T063: Silent Failure 처리

extension SimilarityAnalyzer {

    /// 안전한 Feature Print 생성 (silent failure)
    /// - 에러 발생 시 nil 반환, 로그만 출력
    func generateFeaturePrintSafely(
        from cgImage: CGImage,
        assetID: String? = nil
    ) -> VNFeaturePrintObservation? {
        do {
            return generateFeaturePrint(from: cgImage, assetID: assetID)
        } catch {
            print("[SimilarityAnalyzer] Silent failure for asset: \(assetID?.prefix(8) ?? "unknown")...")
            return nil
        }
    }
}

// FaceDetector.swift
// Vision Framework 얼굴 감지
//
// T011: FaceDetector 생성
// - VNDetectFaceRectanglesRequest 얼굴 감지
// - 화면 너비 5% 미만 얼굴 필터링
// - 위치 기반 인물 번호 부여

import Foundation
import Vision
import CoreGraphics

/// 얼굴 감지기
/// Vision Framework를 사용하여 이미지 내 얼굴 위치 감지
final class FaceDetector {

    // MARK: - Constants

    /// 최소 유효 얼굴 크기 (화면 너비 대비 %)
    /// - 5% 미만은 필터링 (너무 작은 얼굴)
    static let minimumFaceSize: CGFloat = 0.05

    /// 최대 표시 얼굴 수
    /// - +버튼 최대 5개
    static let maxDisplayFaces = 5

    // MARK: - Singleton

    /// 공유 인스턴스
    static let shared = FaceDetector()

    // MARK: - Initialization

    private init() {}

    // MARK: - Public Methods

    /// 이미지에서 얼굴 감지
    /// - Parameters:
    ///   - cgImage: 분석할 CGImage
    ///   - filterMinimumSize: 최소 크기 필터 적용 여부 (기본: true)
    /// - Returns: 감지된 얼굴 bounding box 배열 (위치순 정렬)
    func detectFaces(
        in cgImage: CGImage,
        filterMinimumSize: Bool = true
    ) -> [CGRect] {
        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])

            guard let results = request.results else {
                return []
            }

            // bounding box 추출
            var boundingBoxes = results.map { $0.boundingBox }

            // 최소 크기 필터링
            if filterMinimumSize {
                boundingBoxes = boundingBoxes.filter { $0.width >= Self.minimumFaceSize }
            }

            // 위치순 정렬 (좌→우, 위→아래)
            boundingBoxes = sortByPosition(boundingBoxes)

            return boundingBoxes

        } catch {
            print("[FaceDetector] Face detection failed: \(error.localizedDescription)")
            return []
        }
    }

    /// 이미지에서 CachedFace 배열 생성
    /// - Parameters:
    ///   - cgImage: 분석할 CGImage
    ///   - filterMinimumSize: 최소 크기 필터 적용 여부
    /// - Returns: CachedFace 배열 (위치순, 인물 번호 부여됨)
    func detectCachedFaces(
        in cgImage: CGImage,
        filterMinimumSize: Bool = true
    ) -> [CachedFace] {
        let boundingBoxes = detectFaces(in: cgImage, filterMinimumSize: filterMinimumSize)

        return boundingBoxes.enumerated().map { index, boundingBox in
            CachedFace(
                boundingBox: boundingBox,
                personIndex: index + 1, // 1부터 시작
                isValidSlot: false // 그룹 분석 후 업데이트
            )
        }
    }

    /// 이미지에서 얼굴 감지 (비동기)
    /// - Parameters:
    ///   - cgImage: 분석할 CGImage
    ///   - filterMinimumSize: 최소 크기 필터 적용 여부
    ///   - completion: 완료 핸들러
    func detectFacesAsync(
        in cgImage: CGImage,
        filterMinimumSize: Bool = true,
        completion: @escaping ([CGRect]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let faces = self.detectFaces(in: cgImage, filterMinimumSize: filterMinimumSize)

            DispatchQueue.main.async {
                completion(faces)
            }
        }
    }

    /// 이미지에서 CachedFace 배열 생성 (비동기)
    func detectCachedFacesAsync(
        in cgImage: CGImage,
        filterMinimumSize: Bool = true,
        completion: @escaping ([CachedFace]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }

            let faces = self.detectCachedFaces(in: cgImage, filterMinimumSize: filterMinimumSize)

            DispatchQueue.main.async {
                completion(faces)
            }
        }
    }

    // MARK: - Private Methods

    /// 위치 기반 정렬 (좌→우, 위→아래)
    /// - X좌표 오름차순, X 동일 시 Y 내림차순 (Vision 좌표계)
    private func sortByPosition(_ boundingBoxes: [CGRect]) -> [CGRect] {
        return boundingBoxes.sorted { lhs, rhs in
            let lhsCenterX = lhs.midX
            let rhsCenterX = rhs.midX

            // X좌표 우선 정렬
            if abs(lhsCenterX - rhsCenterX) > 0.05 {
                return lhsCenterX < rhsCenterX
            }

            // X 동일 시 Y 정렬 (Vision Y축: 아래가 0, 위가 1)
            return lhs.midY > rhs.midY // 위→아래
        }
    }
}

// MARK: - Batch Detection

extension FaceDetector {

    /// 여러 이미지에서 얼굴 감지 (배치)
    /// - Parameters:
    ///   - images: CGImage 배열
    ///   - assetIDs: 각 이미지의 사진 ID
    /// - Returns: assetID -> CachedFace 배열 딕셔너리
    func detectFacesBatch(
        images: [CGImage],
        assetIDs: [String]
    ) -> [String: [CachedFace]] {
        precondition(images.count == assetIDs.count)

        var results: [String: [CachedFace]] = [:]
        let resultsLock = NSLock()

        let group = DispatchGroup()

        for (index, image) in images.enumerated() {
            group.enter()

            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                guard let self = self else {
                    group.leave()
                    return
                }

                let faces = self.detectCachedFaces(in: image)

                resultsLock.lock()
                results[assetIDs[index]] = faces
                resultsLock.unlock()

                group.leave()
            }
        }

        group.wait()
        return results
    }

    /// 배치 감지 (비동기)
    func detectFacesBatchAsync(
        images: [CGImage],
        assetIDs: [String],
        completion: @escaping ([String: [CachedFace]]) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([:]) }
                return
            }

            let results = self.detectFacesBatch(images: images, assetIDs: assetIDs)

            DispatchQueue.main.async {
                completion(results)
            }
        }
    }
}

// MARK: - Valid Slot Analysis

extension FaceDetector {

    /// 그룹 내 유효 슬롯 분석
    /// - 동일 인물 번호에서 2장 이상 감지되면 유효 슬롯
    /// - Parameters:
    ///   - facesByAsset: assetID -> CachedFace 배열
    /// - Returns: 업데이트된 facesByAsset (isValidSlot 설정됨)
    func analyzeValidSlots(
        facesByAsset: [String: [CachedFace]]
    ) -> [String: [CachedFace]] {
        // 인물 번호별 출현 횟수 계산
        var personIndexCounts: [Int: Int] = [:]

        for (_, faces) in facesByAsset {
            for face in faces {
                personIndexCounts[face.personIndex, default: 0] += 1
            }
        }

        // 유효 슬롯 판정 (2장 이상)
        let validIndices = Set(personIndexCounts.filter { $0.value >= 2 }.keys)

        // isValidSlot 업데이트
        var updatedResults: [String: [CachedFace]] = [:]

        for (assetID, faces) in facesByAsset {
            let updatedFaces = faces.map { face -> CachedFace in
                var updated = face
                updated.isValidSlot = validIndices.contains(face.personIndex)
                return updated
            }
            updatedResults[assetID] = updatedFaces
        }

        return updatedResults
    }
}

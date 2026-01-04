// FaceMatch.swift
// 인물 매칭 검증 결과
//
// T006: FaceMatch 구조체 생성
// - assetID: 매칭 대상 사진 ID
// - personIndex: 인물 번호
// - distance: Feature Print 거리
// - confidence: 매칭 신뢰도

import Foundation

/// 인물 매칭 신뢰도
/// Feature Print 거리 기반 분류
enum MatchConfidence: Comparable {
    /// 높은 신뢰도 (거리 < 0.6)
    /// - 동일 인물일 가능성 매우 높음
    case high

    /// 중간 신뢰도 (0.6 ≤ 거리 < 1.0)
    /// - 동일 인물일 가능성 높음
    case medium

    /// 낮은 신뢰도 (거리 ≥ 1.0)
    /// - 다른 인물일 가능성 있음
    /// - UI에서 경고 표시 필요
    case low

    /// Feature Print 거리에서 신뢰도 계산
    /// - Parameter distance: 두 Feature Print 간 거리
    /// - Returns: 매칭 신뢰도
    static func from(distance: Float) -> MatchConfidence {
        if distance < 0.6 {
            return .high
        } else if distance < 1.0 {
            return .medium
        } else {
            return .low
        }
    }
}

/// 인물 매칭 검증 결과
/// 얼굴 비교 화면에서 동일 인물 검증에 사용
struct FaceMatch: Equatable {

    // MARK: - Properties

    /// 매칭 대상 사진 ID (PHAsset.localIdentifier)
    let assetID: String

    /// 인물 번호 (1 이상)
    let personIndex: Int

    /// Feature Print 거리 (낮을수록 유사)
    /// - 0: 동일 이미지
    /// - 1.0: 매칭 임계값
    /// - 10.0+: 완전히 다른 대상
    let distance: Float

    /// 매칭 신뢰도
    let confidence: MatchConfidence

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - assetID: 매칭 대상 사진 ID
    ///   - personIndex: 인물 번호
    ///   - distance: Feature Print 거리
    init(assetID: String, personIndex: Int, distance: Float) {
        self.assetID = assetID
        self.personIndex = personIndex
        self.distance = distance
        self.confidence = MatchConfidence.from(distance: distance)
    }

    // MARK: - Computed Properties

    /// 경고 표시 필요 여부
    /// - 낮은 신뢰도일 때 true
    var requiresWarning: Bool {
        return confidence == .low
    }

    /// 매칭 통과 여부
    /// - 높음 또는 중간 신뢰도일 때 true
    var isMatch: Bool {
        return confidence != .low
    }
}

// MARK: - Batch Processing

extension FaceMatch {

    /// 기준 사진과 비교 대상 사진들 간 매칭 결과 생성
    /// - Parameters:
    ///   - referenceAssetID: 기준 사진 ID (현재 탭한 +버튼의 사진)
    ///   - targetAssetIDs: 비교 대상 사진 ID 배열
    ///   - distances: 각 대상 사진과의 Feature Print 거리 배열 (순서 일치)
    ///   - personIndex: 인물 번호
    /// - Returns: FaceMatch 배열
    static func batch(
        referenceAssetID: String,
        targetAssetIDs: [String],
        distances: [Float],
        personIndex: Int
    ) -> [FaceMatch] {
        precondition(targetAssetIDs.count == distances.count,
                     "targetAssetIDs와 distances 길이가 일치해야 합니다")

        return zip(targetAssetIDs, distances).map { assetID, distance in
            FaceMatch(assetID: assetID, personIndex: personIndex, distance: distance)
        }
    }

    /// 경고가 필요한 매칭 결과 필터링
    /// - Parameter matches: FaceMatch 배열
    /// - Returns: 경고 필요한 매칭만 포함된 배열
    static func filterRequiringWarning(_ matches: [FaceMatch]) -> [FaceMatch] {
        return matches.filter { $0.requiresWarning }
    }
}

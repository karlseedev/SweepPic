//
//  FaceMatch.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  인물 매칭 검증 결과를 저장하는 구조체입니다.
//  얼굴 크롭 Feature Print 비교 결과를 기반으로 동일 인물 여부를 판정합니다.
//
//  Matching Rules (spec FR-029, FR-030):
//  - 거리 < 1.0: 동일 인물 → 비교 그리드에 포함
//  - 거리 >= 1.0: 다른 인물 → 비교 그리드에서 제외
//

import Foundation

/// 인물 매칭 검증 결과를 저장하는 구조체
///
/// +버튼 탭 후 비교 화면에서 동일 인물 여부를 검증하는 데 사용됩니다.
/// Feature Print 거리가 1.0 미만이면 동일 인물, 이상이면 다른 인물로 판정합니다.
struct FaceMatch: Equatable, Hashable {

    // MARK: - Properties

    /// 매칭 대상 사진 ID
    /// - PHAsset.localIdentifier
    let assetID: String

    /// 인물 번호
    /// - CachedFace.personIndex와 동일
    let personIndex: Int

    /// 얼굴 크롭 Feature Print 거리
    /// - VNFeaturePrintObservation.computeDistance() 결과
    /// - 0에 가까울수록 유사
    let distance: Float

    // MARK: - Computed Properties

    /// 동일 인물인지 여부
    /// - 거리 < 1.0: 동일 인물
    /// - 거리 >= 1.0: 다른 인물 (spec FR-030)
    var isSamePerson: Bool {
        distance < SimilarityConstants.personMatchThreshold
    }

    /// 신뢰도 수준
    /// - 거리가 낮을수록 높은 신뢰도
    var confidence: MatchConfidence {
        switch distance {
        case ..<0.3:
            return .veryHigh
        case 0.3..<0.6:
            return .high
        case 0.6..<1.0:
            return .medium
        default:
            return .low
        }
    }

    // MARK: - Initialization

    /// FaceMatch를 생성합니다.
    ///
    /// - Parameters:
    ///   - assetID: 매칭 대상 사진 ID
    ///   - personIndex: 인물 번호
    ///   - distance: Feature Print 거리
    init(assetID: String, personIndex: Int, distance: Float) {
        self.assetID = assetID
        self.personIndex = personIndex
        self.distance = distance
    }
}

// MARK: - Match Confidence

/// 인물 매칭 신뢰도 수준
enum MatchConfidence: Int, Comparable {
    /// 매우 높은 신뢰도 (거리 < 0.3)
    case veryHigh = 4

    /// 높은 신뢰도 (거리 0.3 ~ 0.6)
    case high = 3

    /// 중간 신뢰도 (거리 0.6 ~ 1.0)
    case medium = 2

    /// 낮은 신뢰도 (거리 >= 1.0, 다른 인물로 판정됨)
    case low = 1

    // MARK: - Comparable

    static func < (lhs: MatchConfidence, rhs: MatchConfidence) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    // MARK: - Computed Properties

    /// 신뢰도 표시 문자열
    var displayString: String {
        switch self {
        case .veryHigh:
            return "Very High"
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }
}

// MARK: - CustomStringConvertible

extension FaceMatch: CustomStringConvertible {
    /// 디버깅용 문자열 표현
    var description: String {
        let status = isSamePerson ? "same" : "different"
        return "FaceMatch(asset: \(assetID), person: \(personIndex), distance: \(distance), \(status))"
    }
}

// MARK: - Array Extensions

extension Array where Element == FaceMatch {
    /// 동일 인물로 판정된 매칭만 필터링합니다.
    ///
    /// - Returns: isSamePerson이 true인 매칭만 포함된 배열
    func samePerson() -> [FaceMatch] {
        filter { $0.isSamePerson }
    }

    /// 거리순으로 정렬합니다 (오름차순).
    ///
    /// - Returns: 거리가 가까운(유사한) 순서로 정렬된 배열
    func sortedByDistance() -> [FaceMatch] {
        sorted { $0.distance < $1.distance }
    }

    /// 특정 신뢰도 이상인 매칭만 필터링합니다.
    ///
    /// - Parameter minConfidence: 최소 신뢰도
    /// - Returns: 지정된 신뢰도 이상인 매칭만 포함된 배열
    func withConfidence(atLeast minConfidence: MatchConfidence) -> [FaceMatch] {
        filter { $0.confidence >= minConfidence }
    }
}

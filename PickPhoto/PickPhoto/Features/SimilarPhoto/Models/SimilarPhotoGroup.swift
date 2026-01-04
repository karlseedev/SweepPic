// SimilarPhotoGroup.swift
// 유사 사진 그룹 모델
//
// T004: SimilarThumbnailGroup + ComparisonGroup 구조체 생성
// - SimilarThumbnailGroup: 그리드 테두리/뷰어 +버튼 표시용 (무제한)
// - ComparisonGroup: 얼굴 비교 화면용 (최대 8장)

import Foundation

/// 유사 사진 썸네일 그룹
/// 그리드 테두리 표시 및 뷰어 +버튼 표시에 사용
/// 그룹 멤버 수 제한 없음
struct SimilarThumbnailGroup: Identifiable, Equatable {

    // MARK: - Properties

    /// 고유 그룹 식별자 (UUID)
    let id: String

    /// Identifiable 프로토콜용 alias
    var groupID: String { id }

    /// 그룹 소속 사진 ID 목록 (시간순 정렬)
    /// - 최소 3장 이상 (3장 미만 시 그룹 무효화)
    var memberAssetIDs: [String]

    /// 유효 인물 슬롯 번호 집합
    /// - 그룹 내 2장 이상 감지된 인물 위치
    /// - +버튼 표시 대상
    var validPersonIndices: Set<Int>

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - memberAssetIDs: 그룹 멤버 사진 ID 배열 (3장 이상 권장)
    ///   - validPersonIndices: 유효 인물 슬롯 번호 집합
    init(memberAssetIDs: [String], validPersonIndices: Set<Int> = []) {
        self.id = UUID().uuidString
        self.memberAssetIDs = memberAssetIDs
        self.validPersonIndices = validPersonIndices
    }

    // MARK: - Computed Properties

    /// 그룹 유효성 여부
    /// - 멤버 3장 이상
    /// - 유효 인물 슬롯 1개 이상
    var isValid: Bool {
        return memberAssetIDs.count >= 3 && !validPersonIndices.isEmpty
    }

    /// 멤버 수
    var memberCount: Int {
        return memberAssetIDs.count
    }

    // MARK: - Mutation

    /// 멤버 제거
    /// - Parameter assetID: 제거할 사진 ID
    /// - Returns: 제거 성공 여부
    @discardableResult
    mutating func removeMember(_ assetID: String) -> Bool {
        guard let index = memberAssetIDs.firstIndex(of: assetID) else {
            return false
        }
        memberAssetIDs.remove(at: index)
        return true
    }

    /// 그룹에 사진 포함 여부 확인
    /// - Parameter assetID: 확인할 사진 ID
    /// - Returns: 포함 여부
    func contains(_ assetID: String) -> Bool {
        return memberAssetIDs.contains(assetID)
    }

    /// 사진의 그룹 내 인덱스 조회
    /// - Parameter assetID: 조회할 사진 ID
    /// - Returns: 인덱스 (없으면 nil)
    func indexOf(_ assetID: String) -> Int? {
        return memberAssetIDs.firstIndex(of: assetID)
    }
}

// MARK: - ComparisonGroup

/// 얼굴 비교 화면용 그룹
/// 최대 8장으로 제한, 거리순 선택
struct ComparisonGroup: Equatable {

    // MARK: - Constants

    /// 최대 선택 가능 사진 수
    static let maxPhotos = 8

    // MARK: - Properties

    /// 원본 ThumbnailGroup ID
    let sourceGroupID: String

    /// 비교 대상 사진 ID 목록 (최대 8장)
    /// - 현재 사진 기준 거리순 선택
    /// - 원래 시간순으로 재정렬됨
    let selectedAssetIDs: [String]

    /// 비교 대상 인물 번호 (1 이상)
    let personIndex: Int

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - sourceGroupID: 원본 그룹 ID
    ///   - allMemberIDs: 그룹 전체 멤버 ID 배열 (시간순)
    ///   - currentAssetID: 현재 보고 있는 사진 ID
    ///   - personIndex: 비교 대상 인물 번호
    init(
        sourceGroupID: String,
        allMemberIDs: [String],
        currentAssetID: String,
        personIndex: Int
    ) {
        self.sourceGroupID = sourceGroupID
        self.personIndex = personIndex

        // 거리순 선택 알고리즘 적용
        self.selectedAssetIDs = Self.selectByDistance(
            allMemberIDs: allMemberIDs,
            currentAssetID: currentAssetID
        )
    }

    // MARK: - Selection Algorithm

    /// 거리순 선택 알고리즘
    /// 1. 현재 사진 인덱스 확인
    /// 2. 거리순 선택 (동일 거리면 앞쪽 우선)
    /// 3. 최대 8장까지 선택
    /// 4. 원래 순서로 재정렬 (시간순 유지)
    private static func selectByDistance(
        allMemberIDs: [String],
        currentAssetID: String
    ) -> [String] {
        guard let currentIndex = allMemberIDs.firstIndex(of: currentAssetID) else {
            // 현재 사진이 그룹에 없으면 앞에서 8장 선택
            return Array(allMemberIDs.prefix(maxPhotos))
        }

        // 거리순 정렬 (튜플: 인덱스, 거리)
        let sortedByDistance = allMemberIDs.enumerated()
            .map { (index: $0.offset, id: $0.element, distance: abs($0.offset - currentIndex)) }
            .sorted { lhs, rhs in
                if lhs.distance != rhs.distance {
                    return lhs.distance < rhs.distance // 거리순
                } else {
                    return lhs.index < rhs.index // 동일 거리면 앞쪽 우선
                }
            }

        // 최대 8장 선택
        let selected = sortedByDistance.prefix(maxPhotos).map { $0.id }

        // 원래 순서로 재정렬 (시간순)
        return allMemberIDs.filter { selected.contains($0) }
    }

    // MARK: - Computed Properties

    /// 선택된 사진 수
    var count: Int {
        return selectedAssetIDs.count
    }

    /// 그룹에 사진 포함 여부 확인
    func contains(_ assetID: String) -> Bool {
        return selectedAssetIDs.contains(assetID)
    }

    /// 사진의 그룹 내 인덱스 조회
    func indexOf(_ assetID: String) -> Int? {
        return selectedAssetIDs.firstIndex(of: assetID)
    }
}

// AnalysisRequest.swift
// 분석 요청 추적 구조체
//
// T005: AnalysisRequest 구조체 생성
// - assetID: 분석 대상 사진 ID
// - source: 분석 요청 소스 (grid/viewer)
// - range: 분석 범위 인덱스

import Foundation

/// 분석 요청 소스
/// 요청 취소 정책에 영향을 줌
enum AnalysisSource {
    /// 그리드 스크롤 멈춤에서 요청
    /// - 스크롤 재개 시 취소 가능
    case grid

    /// 뷰어에서 notAnalyzed 사진 접근 시 요청
    /// - 사용자가 명시적으로 보고 있으므로 취소 불가
    case viewer
}

/// 분석 요청
/// SimilarityAnalysisQueue에서 관리
struct AnalysisRequest: Identifiable, Equatable {

    // MARK: - Properties

    /// 요청 고유 ID
    let id: UUID

    /// 분석 대상 사진 ID (PHAsset.localIdentifier)
    let assetID: String

    /// 분석 요청 소스
    let source: AnalysisSource

    /// 분석 범위 인덱스 (화면 기준 ±7장)
    /// - grid 소스에서만 의미 있음
    let range: ClosedRange<Int>

    /// 요청 생성 시간 (FIFO 정렬용)
    let createdAt: Date

    /// 요청 취소 여부
    var isCancelled: Bool

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - assetID: 분석 대상 사진 ID
    ///   - source: 분석 요청 소스
    ///   - range: 분석 범위 인덱스
    init(
        assetID: String,
        source: AnalysisSource,
        range: ClosedRange<Int>
    ) {
        self.id = UUID()
        self.assetID = assetID
        self.source = source
        self.range = range
        self.createdAt = Date()
        self.isCancelled = false
    }

    // MARK: - Computed Properties

    /// 취소 가능 여부
    /// - grid 소스만 취소 가능
    var isCancellable: Bool {
        return source == .grid
    }

    // MARK: - Mutation

    /// 요청 취소
    /// - Note: isCancellable이 true인 경우에만 효과 있음
    mutating func cancel() {
        guard isCancellable else { return }
        isCancelled = true
    }

    // MARK: - Equatable

    static func == (lhs: AnalysisRequest, rhs: AnalysisRequest) -> Bool {
        return lhs.id == rhs.id
    }
}

// MARK: - Batch Request

extension AnalysisRequest {

    /// 배치 요청 생성 (그리드 스크롤 멈춤 시)
    /// - Parameters:
    ///   - assetIDs: 분석 대상 사진 ID 배열
    ///   - range: 분석 범위 인덱스
    /// - Returns: 요청 배열
    static func batchForGrid(
        assetIDs: [String],
        range: ClosedRange<Int>
    ) -> [AnalysisRequest] {
        return assetIDs.map { assetID in
            AnalysisRequest(
                assetID: assetID,
                source: .grid,
                range: range
            )
        }
    }

    /// 단일 요청 생성 (뷰어에서)
    /// - Parameter assetID: 분석 대상 사진 ID
    /// - Returns: 요청
    static func forViewer(assetID: String) -> AnalysisRequest {
        return AnalysisRequest(
            assetID: assetID,
            source: .viewer,
            range: 0...0 // 단일 사진
        )
    }
}

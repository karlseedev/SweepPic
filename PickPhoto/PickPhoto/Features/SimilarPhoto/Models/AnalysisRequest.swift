//
//  AnalysisRequest.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  분석 요청을 추적하는 구조체입니다.
//  그리드 스크롤과 뷰어에서 발생하는 분석 요청을 구분하여 관리합니다.
//
//  Cancellation Rules:
//  - grid 소스: 스크롤 재개 시 취소 가능
//  - viewer 소스: 취소 불가 (사용자가 명시적으로 보고 있음)
//

import Foundation

/// 분석 요청의 출처를 나타내는 열거형
///
/// 분석 요청이 어디서 발생했는지에 따라 취소 규칙이 달라집니다.
enum AnalysisSource: String, Equatable {
    /// 그리드 스크롤 멈춤에서 발생한 요청
    /// - 스크롤 재개 시 취소됨
    case grid

    /// 뷰어에서 notAnalyzed 사진 접근 시 발생한 요청
    /// - 취소되지 않음 (사용자가 명시적으로 해당 사진을 보고 있음)
    case viewer
}

/// 분석 요청을 추적하는 구조체
///
/// SimilarityAnalysisQueue에서 분석 작업을 관리할 때 사용됩니다.
/// 각 요청은 고유 ID, 대상 사진, 소스, 분석 범위를 포함합니다.
struct AnalysisRequest: Equatable, Hashable, Identifiable {

    // MARK: - Properties

    /// 요청 고유 식별자
    let id: UUID

    /// 분석 대상 사진 ID (대표 사진)
    /// - 분석 범위 중심이 되는 사진의 PHAsset.localIdentifier
    let assetID: String

    /// 요청 출처
    /// - .grid: 스크롤 멈춤 시 자동 분석
    /// - .viewer: 뷰어에서 수동 분석 트리거
    let source: AnalysisSource

    /// 분석 범위 (사진 인덱스)
    /// - 그리드의 경우: 화면 보이는 범위 ±7
    /// - 뷰어의 경우: 현재 사진 ±7
    let range: ClosedRange<Int>

    /// 요청 생성 시간
    /// - FIFO 큐 정렬 및 디버깅용
    let timestamp: Date

    // MARK: - Initialization

    /// AnalysisRequest를 생성합니다.
    ///
    /// - Parameters:
    ///   - assetID: 대표 사진 ID
    ///   - source: 요청 출처
    ///   - range: 분석 범위
    init(assetID: String, source: AnalysisSource, range: ClosedRange<Int>) {
        self.id = UUID()
        self.assetID = assetID
        self.source = source
        self.range = range
        self.timestamp = Date()
    }

    // MARK: - Computed Properties

    /// 취소 가능 여부
    /// - grid 소스만 취소 가능
    var isCancellable: Bool {
        source == .grid
    }

    /// 분석 범위 크기
    var rangeSize: Int {
        range.upperBound - range.lowerBound + 1
    }

    // MARK: - Equatable & Hashable

    static func == (lhs: AnalysisRequest, rhs: AnalysisRequest) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - CustomStringConvertible

extension AnalysisRequest: CustomStringConvertible {
    /// 디버깅용 문자열 표현
    var description: String {
        "AnalysisRequest(id: \(id.uuidString.prefix(8)), source: \(source.rawValue), range: \(range))"
    }
}

// MARK: - Array Extensions

extension Array where Element == AnalysisRequest {
    /// 특정 소스의 요청만 필터링합니다.
    ///
    /// - Parameter source: 필터링할 소스
    /// - Returns: 해당 소스의 요청만 포함된 배열
    func filter(by source: AnalysisSource) -> [AnalysisRequest] {
        filter { $0.source == source }
    }

    /// 취소 가능한 요청만 필터링합니다.
    ///
    /// - Returns: isCancellable이 true인 요청만 포함된 배열
    func cancellable() -> [AnalysisRequest] {
        filter { $0.isCancellable }
    }

    /// 타임스탬프 순으로 정렬합니다 (오래된 것 먼저).
    ///
    /// - Returns: FIFO 순서로 정렬된 배열
    func sortedByTimestamp() -> [AnalysisRequest] {
        sorted { $0.timestamp < $1.timestamp }
    }

    /// 특정 범위와 겹치는 요청이 있는지 확인합니다.
    ///
    /// - Parameter range: 확인할 범위
    /// - Returns: 겹치는 요청이 있으면 true
    func hasOverlapping(with range: ClosedRange<Int>) -> Bool {
        contains { $0.range.overlaps(range) }
    }
}

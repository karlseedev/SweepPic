//
//  PreviewResult.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  분석 완료 결과 — PreviewGridVC에 전달
//  3단계별 후보를 분리하여 보관 (light / standard 추가분 / deep 추가분)
//

import Foundation

/// 분석 완료 결과 — PreviewGridVC에 전달
///
/// CleanupPreviewService의 분석 완료 후 생성.
/// 각 단계의 후보를 분리하여 보관하며, UI에서 단계적 확장 시 사용.
struct PreviewResult {

    /// 1단계 후보 (완화 — 확실한 저품질)
    let lightCandidates: [PreviewCandidate]

    /// 2단계 추가분 (기본 - 완화 차이)
    let standardCandidates: [PreviewCandidate]

    /// 3단계 추가분 (강화 - 기본 차이)
    let deepCandidates: [PreviewCandidate]

    /// 총 스캔된 사진 수
    let scannedCount: Int

    /// 분석 소요 시간 (초)
    let totalTimeSeconds: Double

    // MARK: - Computed Properties

    /// 1단계 개수
    var lightCount: Int { lightCandidates.count }

    /// 2단계 추가분 개수
    var standardCount: Int { standardCandidates.count }

    /// 3단계 추가분 개수
    var deepCount: Int { deepCandidates.count }

    /// 전체 후보 수
    var totalCount: Int { lightCount + standardCount + deepCount }

    // MARK: - Stage Query

    /// 특정 단계까지의 assetIDs
    ///
    /// - Parameter stage: 포함할 최대 단계
    /// - Returns: 해당 단계까지의 모든 assetID 배열
    func assetIDs(upToStage stage: PreviewStage) -> [String] {
        var ids: [String] = []

        // light는 항상 포함
        ids.append(contentsOf: lightCandidates.map { $0.assetID })

        // standard 이상이면 추가
        if stage >= .standard {
            ids.append(contentsOf: standardCandidates.map { $0.assetID })
        }

        // deep이면 추가
        if stage >= .deep {
            ids.append(contentsOf: deepCandidates.map { $0.assetID })
        }

        return ids
    }

    /// 특정 단계까지의 총 개수
    ///
    /// - Parameter stage: 포함할 최대 단계
    /// - Returns: 해당 단계까지의 총 후보 수
    func count(upToStage stage: PreviewStage) -> Int {
        switch stage {
        case .light:
            return lightCount
        case .standard:
            return lightCount + standardCount
        case .deep:
            return totalCount
        }
    }
}

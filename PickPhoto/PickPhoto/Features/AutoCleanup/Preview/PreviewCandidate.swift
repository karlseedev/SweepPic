//
//  PreviewCandidate.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  미리보기 분석 결과 1건 — 어느 단계에서 잡혔는지 + AestheticsScore
//  단계 구분: light(완화) ⊂ standard(기본) ⊂ deep(강화)
//

import Photos

// MARK: - PreviewStage

/// 단계 구분
///
/// 3모드 임계값에 따라 어느 수준에서 잡혔는지 분류.
/// light ⊂ standard ⊂ deep 계층 구조.
enum PreviewStage: Int, Comparable, CaseIterable {

    /// 완화 (확실한 저품질)
    /// - 경로1 OR 경로2(< -0.3)
    case light = 1

    /// 기본
    /// - 경로1 OR 경로2(< 0.0)
    case standard = 2

    /// 강화
    /// - 경로1 OR 경로2(< 0.2)
    case deep = 3

    static func < (lhs: PreviewStage, rhs: PreviewStage) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    /// 다음 단계 (deep이면 nil)
    var next: PreviewStage? {
        return PreviewStage(rawValue: rawValue + 1)
    }
}

// MARK: - PreviewCandidate

/// 분석 결과 1건 — 미리보기용
///
/// CleanupPreviewService가 분석한 개별 사진 결과.
/// 삭제대기함 이동 없이 결과만 보관하여 미리보기 그리드에 표시.
struct PreviewCandidate {

    /// PHAsset ID (삭제대기함 이동 시 사용)
    let assetID: String

    /// PHAsset 참조 (PhotoCell 표시용)
    let asset: PHAsset

    /// 어느 단계에서 잡혔는지
    let stage: PreviewStage

    /// AestheticsScore (iOS 18+ 에서만, 없으면 nil)
    let score: Float?
}

//
//  FaceScanConstants.swift
//  SweepPic
//
//  인물사진 비교정리 — 상수 정의
//  스캔 상한, 청크 크기, 동시성 제한 등
//

import Foundation

/// 인물사진 비교정리 상수
enum FaceScanConstants {

    // MARK: - 스캔 상한 (먼저 도달하는 조건에서 종료)

    /// 최대 검색 장수
    static let maxScanCount: Int = 1_000

    /// 최대 발견 그룹 수
    static let maxGroupCount: Int = 30

    // MARK: - 청크 처리

    /// 한 번에 분석할 사진 수
    static let chunkSize: Int = 20

    /// 청크 경계 overlap (이어지는 그룹을 놓치지 않기 위해)
    static let chunkOverlap: Int = 3

    // MARK: - 동시성

    /// 기본 동시 분석 수
    static let maxConcurrentAnalysis: Int = 5

    /// 과열(thermal) 시 동시 분석 수
    static let maxConcurrentAnalysisThermal: Int = 2

    // MARK: - 이미지 로딩

    /// Feature Print 분석용 이미지 크기 (SimilarityConstants와 동일)
    static let analysisImageMaxSize: Int = 480

    /// 얼굴 감지용 이미지 크기 (SimilarityConstants와 동일)
    static let personMatchImageMaxSize: Int = 960

    /// 이미지 로딩 타임아웃 (초)
    static let imageLoadTimeout: TimeInterval = 3.0

    // MARK: - UI

    /// 진행바 완료 후 fade out 대기 시간 (초)
    static let progressBarFadeDelay: TimeInterval = 4.0

    /// 진행바 fade out 애니메이션 시간 (초)
    static let progressBarFadeDuration: TimeInterval = 0.5
}

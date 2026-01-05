//
//  SimilarityConstants.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  유사 사진 분석 기능에서 사용되는 상수들을 정의하는 열거형입니다.
//  여러 클래스에서 참조되는 공용 상수 파일입니다.
//
//  iOS 버전별 Feature Print 거리 범위:
//  - iOS 16 (Revision 1): 2048개 비정규화 벡터, 거리 범위 0.0 ~ 40.0
//  - iOS 17+ (Revision 2): 768개 정규화 벡터, 거리 범위 0.0 ~ 2.0
//  참고: https://github.com/verny-tran/PhotoClustering
//

import Foundation
import CoreGraphics

/// 유사 사진 분석에 사용되는 상수들을 정의하는 열거형
///
/// 이 열거형은 인스턴스화되지 않고, 타입 프로퍼티로만 상수에 접근합니다.
/// 모든 상수는 research.md 및 spec.md에서 정의된 값을 따릅니다.
enum SimilarityConstants: Sendable {

    // MARK: - Feature Print Analysis

    /// Feature Print 거리 임계값 (iOS 버전에 따라 다름)
    ///
    /// - iOS 16: 거리 범위 0~40, 임계값 10.0
    /// - iOS 17+: 거리 범위 0~2, 임계값 0.5
    ///
    /// Vision Framework의 VNFeaturePrintObservation은 iOS 17에서
    /// 정규화된 768차원 벡터로 변경되어 거리 범위가 크게 축소됨
    nonisolated static var similarityThreshold: Float {
        if #available(iOS 17.0, *) {
            return 0.5  // iOS 17+: 정규화 벡터, 거리 범위 0~2
        } else {
            return 10.0 // iOS 16: 비정규화 벡터, 거리 범위 0~40
        }
    }

    /// 인물 매칭 임계값 (얼굴 크롭 Feature Print 비교용)
    ///
    /// - iOS 16: 임계값 1.0
    /// - iOS 17+: 임계값 0.1 (정규화 벡터 기준)
    nonisolated static var personMatchThreshold: Float {
        if #available(iOS 17.0, *) {
            return 0.1  // iOS 17+: 정규화 벡터
        } else {
            return 1.0  // iOS 16: 비정규화 벡터
        }
    }

    // MARK: - Group Validation

    /// 최소 그룹 크기
    nonisolated static let minGroupSize: Int = 3

    /// 인물 슬롯당 최소 사진 수
    nonisolated static let minPhotosPerSlot: Int = 2

    /// 최소 유효 슬롯 개수
    nonisolated static let minValidSlots: Int = 1

    // MARK: - Analysis Range

    /// 분석 범위 확장값
    nonisolated static let analysisRangeExtension: Int = 7

    // MARK: - Image Processing

    /// 분석용 이미지 최대 크기 (픽셀)
    nonisolated static let analysisImageMaxSize: CGFloat = 480

    // MARK: - Face Detection

    /// 유효 얼굴 최소 비율 (화면 너비 대비)
    nonisolated static let minFaceWidthRatio: CGFloat = 0.05

    /// 사진당 최대 얼굴 수
    nonisolated static let maxFacesPerPhoto: Int = 5

    // MARK: - Performance

    /// 분석 타임아웃 (초)
    nonisolated static let analysisTimeout: TimeInterval = 3.0

    /// 최대 캐시 크기 (사진 수)
    nonisolated static let maxCacheSize: Int = 500

    /// 최대 동시 분석 수 (기본)
    nonisolated static let maxConcurrentAnalysis: Int = 5

    /// 최대 동시 분석 수 (과열 시)
    nonisolated static let maxConcurrentAnalysisThermal: Int = 2

    // MARK: - Animation

    /// 테두리 애니메이션 주기 (초)
    nonisolated static let borderAnimationDuration: TimeInterval = 1.5

    /// 스크롤 디바운싱 시간 (초)
    nonisolated static let scrollDebounceDelay: TimeInterval = 0.3

    // MARK: - Comparison Group

    /// 비교 그룹 최대 크기
    nonisolated static let maxComparisonGroupSize: Int = 8

    // MARK: - Face Cropping

    /// 얼굴 크롭 여백 비율
    nonisolated static let faceCropPaddingRatio: CGFloat = 0.3
}

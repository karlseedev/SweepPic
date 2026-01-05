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
//  Usage:
//  - SimilarityConstants.similarityThreshold
//  - SimilarityConstants.minGroupSize
//  - SimilarityConstants.analysisImageMaxSize
//

import Foundation
import CoreGraphics

/// 유사 사진 분석에 사용되는 상수들을 정의하는 열거형
///
/// 이 열거형은 인스턴스화되지 않고, 타입 프로퍼티로만 상수에 접근합니다.
/// 모든 상수는 research.md 및 spec.md에서 정의된 값을 따릅니다.
enum SimilarityConstants {

    // MARK: - Feature Print Analysis

    /// Feature Print 거리 임계값
    /// - 두 이미지의 Feature Print 거리가 이 값 이하이면 "유사한" 것으로 판정
    /// - Vision의 VNFeaturePrintObservation.computeDistance() 결과와 비교
    /// - 값이 작을수록 더 유사함 (0 = 동일 이미지)
    static let similarityThreshold: Float = 10.0

    /// 인물 매칭 임계값
    /// - 얼굴 크롭 Feature Print 거리가 이 값 이상이면 "다른 인물"로 판정
    /// - 비교 그리드에서 다른 인물로 판정된 사진은 제외됨 (spec FR-030)
    static let personMatchThreshold: Float = 1.0

    // MARK: - Group Validation

    /// 최소 그룹 크기
    /// - 유효한 유사 사진 그룹이 되기 위한 최소 사진 수
    /// - 이 값 미만의 그룹은 무효화됨
    static let minGroupSize: Int = 3

    /// 인물 슬롯당 최소 사진 수
    /// - 인물 슬롯이 "유효"하다고 판정되기 위한 최소 사진 수
    /// - 2장 이상의 사진에서 감지된 인물 슬롯만 유효
    static let minPhotosPerSlot: Int = 2

    /// 최소 유효 슬롯 개수
    /// - 그룹이 유효하기 위해 필요한 최소 유효 인물 슬롯 수
    static let minValidSlots: Int = 1

    // MARK: - Analysis Range

    /// 분석 범위 확장값
    /// - 화면에 보이는 사진 기준 앞뒤로 확장하는 장수
    /// - 예: 화면에 보이는 범위 [N, M]이면 분석 범위는 [N-7, M+7]
    static let analysisRangeExtension: Int = 7

    // MARK: - Image Processing

    /// 분석용 이미지 최대 크기 (픽셀)
    /// - 분석 시 이미지의 긴 변이 이 값을 초과하지 않도록 리사이즈
    /// - 480px은 정확도 95% 유지하면서 분석 시간을 200ms 이내로 단축
    /// - PHImageManager의 targetSize에 사용
    static let analysisImageMaxSize: CGFloat = 480

    // MARK: - Face Detection

    /// 유효 얼굴 최소 비율 (화면 너비 대비)
    /// - 감지된 얼굴의 너비가 화면 너비의 이 비율 이상이어야 유효
    /// - 5% 미만의 작은 얼굴은 필터링됨
    static let minFaceWidthRatio: CGFloat = 0.05

    /// 사진당 최대 얼굴 수
    /// - 한 사진에서 처리할 최대 얼굴 개수
    /// - 6개 이상 감지 시 크기순으로 상위 5개만 선택
    static let maxFacesPerPhoto: Int = 5

    // MARK: - Performance

    /// 분석 타임아웃 (초)
    /// - 단일 사진 분석이 이 시간을 초과하면 실패로 처리
    static let analysisTimeout: TimeInterval = 3.0

    /// 최대 캐시 크기 (사진 수)
    /// - SimilarityCache가 저장할 수 있는 최대 사진 수
    /// - 초과 시 LRU(Least Recently Used) 정책으로 제거
    static let maxCacheSize: Int = 500

    /// 최대 동시 분석 수 (기본)
    /// - 동시에 분석할 수 있는 최대 사진 수
    /// - 메모리 사용량 제어를 위해 제한 (Vision API당 약 50MB)
    static let maxConcurrentAnalysis: Int = 5

    /// 최대 동시 분석 수 (과열 시)
    /// - 디바이스가 과열 상태(.serious 또는 .critical)일 때의 동시 분석 수
    /// - 발열 완화를 위해 제한을 강화
    static let maxConcurrentAnalysisThermal: Int = 2

    // MARK: - Animation

    /// 테두리 애니메이션 주기 (초)
    /// - 빛이 도는 테두리 애니메이션의 한 주기 시간
    static let borderAnimationDuration: TimeInterval = 1.5

    /// 스크롤 디바운싱 시간 (초)
    /// - 스크롤이 멈춘 후 분석을 시작하기까지 대기 시간
    /// - 빠른 스크롤 시 불필요한 분석을 방지
    static let scrollDebounceDelay: TimeInterval = 0.3

    // MARK: - Comparison Group

    /// 비교 그룹 최대 크기
    /// - 얼굴 비교 화면에서 표시할 최대 사진 수
    /// - 현재 사진 기준 거리순으로 8장까지 선택
    static let maxComparisonGroupSize: Int = 8

    // MARK: - Face Cropping

    /// 얼굴 크롭 여백 비율
    /// - 얼굴 bounding box에 추가할 여백 비율
    /// - 0.3 = 30% 여백 (상하좌우 각각)
    static let faceCropPaddingRatio: CGFloat = 0.3
}

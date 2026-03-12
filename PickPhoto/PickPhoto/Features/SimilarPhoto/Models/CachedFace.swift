//
//  CachedFace.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-05.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  Vision 얼굴 감지 결과를 캐시하는 구조체입니다.
//  각 얼굴의 위치 정보와 인물 번호, 유효 슬롯 여부를 저장합니다.
//
//  Coordinate System:
//  - Vision 정규화 좌표: (0~1, 원점 좌하단, Y축 위로 증가)
//  - UIKit 좌표: (픽셀 단위, 원점 좌상단, Y축 아래로 증가)
//

import Foundation
import CoreGraphics
import UIKit

/// 감지된 얼굴 정보를 캐시하는 구조체
///
/// SimilarityCache에 저장되어 뷰어에서 +버튼 표시 시 재사용됩니다.
/// 그리드에서 분석된 결과가 뷰어에서 재분석 없이 사용됩니다.
struct CachedFace: Equatable, Hashable, Sendable {

    // MARK: - Properties

    /// Vision에서 반환한 정규화 좌표
    /// - 범위: (0, 0) ~ (1, 1)
    /// - 원점: 이미지 좌하단
    /// - Y축: 위로 증가
    let boundingBox: CGRect

    /// 위치 기반 인물 번호
    /// - 1부터 시작 (0 사용 안함)
    /// - 정렬 기준: X좌표 오름차순 (좌→우), X 동일 시 Y좌표 내림차순 (위→아래)
    let personIndex: Int

    /// 유효 인물 슬롯 여부
    /// - 그룹 내에서 해당 인물이 2장 이상의 사진에서 감지되었는지 여부
    /// - true: 2장 이상 감지됨 (유효 슬롯)
    /// - false: 1장에서만 감지됨 (무효 슬롯)
    /// - 그룹 형성 시 계산되어 설정됨
    var isValidSlot: Bool

    /// SFace 코사인 유사도 기반 거리 (디버그용)
    /// - 값: 1 - cosineSimilarity (0에 가까울수록 동일인)
    /// - nil: 기준 사진이거나 계산 실패
    let sfaceCost: Float?

    // MARK: - Initialization

    /// CachedFace를 생성합니다.
    ///
    /// - Parameters:
    ///   - boundingBox: Vision 정규화 좌표 (0~1)
    ///   - personIndex: 위치 기반 인물 번호 (>= 1)
    ///   - isValidSlot: 유효 슬롯 여부 (기본값: false)
    ///   - sfaceCost: SFace 코사인 유사도 기반 거리 (기본값: nil)
    init(boundingBox: CGRect, personIndex: Int, isValidSlot: Bool = false, sfaceCost: Float? = nil) {
        precondition(personIndex >= 1, "Person index must be >= 1")
        self.boundingBox = boundingBox
        self.personIndex = personIndex
        self.isValidSlot = isValidSlot
        self.sfaceCost = sfaceCost
    }

    // MARK: - Computed Properties

    /// 얼굴 영역의 중심점 (Vision 좌표)
    var center: CGPoint {
        CGPoint(
            x: boundingBox.midX,
            y: boundingBox.midY
        )
    }

    /// 얼굴 영역의 면적 (정규화 단위)
    var area: CGFloat {
        boundingBox.width * boundingBox.height
    }

    // MARK: - Coordinate Conversion

    /// Vision 좌표를 UIKit 좌표로 변환합니다.
    ///
    /// Vision 좌표계 (원점 좌하단, Y 위로 증가)를
    /// UIKit 좌표계 (원점 좌상단, Y 아래로 증가)로 변환합니다.
    ///
    /// - Parameters:
    ///   - imageSize: 원본 이미지 크기 (픽셀)
    ///   - viewerFrame: 뷰어 프레임 크기 (aspectFit 적용 후)
    /// - Returns: UIKit 좌표로 변환된 CGRect
    func convertToUIKit(imageSize: CGSize, viewerFrame: CGRect) -> CGRect {
        // aspectFit 스케일 계산
        let scale = min(
            viewerFrame.width / imageSize.width,
            viewerFrame.height / imageSize.height
        )

        // 이미지가 뷰어 중앙에 위치하므로 오프셋 계산
        let scaledImageWidth = imageSize.width * scale
        let scaledImageHeight = imageSize.height * scale
        let offsetX = (viewerFrame.width - scaledImageWidth) / 2
        let offsetY = (viewerFrame.height - scaledImageHeight) / 2

        // Vision 좌표를 UIKit 좌표로 변환
        // Vision: 원점 좌하단, Y 위로 증가
        // UIKit: 원점 좌상단, Y 아래로 증가
        let x = boundingBox.origin.x * scaledImageWidth + offsetX
        let y = (1 - boundingBox.origin.y - boundingBox.height) * scaledImageHeight + offsetY
        let width = boundingBox.width * scaledImageWidth
        let height = boundingBox.height * scaledImageHeight

        return CGRect(x: x, y: y, width: width, height: height)
    }

    /// 얼굴 위 중앙 위치를 반환합니다 (+버튼 기본 위치용).
    ///
    /// - Parameters:
    ///   - imageSize: 원본 이미지 크기
    ///   - viewerFrame: 뷰어 프레임 크기
    ///   - buttonRadius: 버튼 반지름
    /// - Returns: +버튼의 중심 위치 (UIKit 좌표)
    func buttonPosition(imageSize: CGSize, viewerFrame: CGRect, buttonRadius: CGFloat) -> CGPoint {
        let uiKitRect = convertToUIKit(imageSize: imageSize, viewerFrame: viewerFrame)

        // 얼굴 위 중앙 위치 (버튼 반지름만큼 위로)
        return CGPoint(
            x: uiKitRect.midX,
            y: uiKitRect.minY - buttonRadius
        )
    }

}

// MARK: - CustomStringConvertible

extension CachedFace: CustomStringConvertible {
    /// 디버깅용 문자열 표현
    var description: String {
        let validity = isValidSlot ? "valid" : "invalid"
        return "CachedFace(person: \(personIndex), \(validity), box: \(boundingBox))"
    }
}

// MARK: - Sorting Utilities

extension Array where Element == CachedFace {
    /// 얼굴을 크기순으로 정렬합니다 (내림차순).
    ///
    /// - Returns: 큰 얼굴부터 정렬된 배열
    func sortedBySize() -> [CachedFace] {
        sorted { $0.area > $1.area }
    }

    /// 인물 번호 순서대로 정렬합니다 (오름차순).
    ///
    /// - Returns: 인물 번호 순서로 정렬된 배열
    func sortedByPersonIndex() -> [CachedFace] {
        sorted { $0.personIndex < $1.personIndex }
    }

    /// 유효 슬롯의 얼굴만 필터링합니다.
    ///
    /// - Returns: isValidSlot이 true인 얼굴만 포함된 배열
    func validSlotFaces() -> [CachedFace] {
        filter { $0.isValidSlot }
    }

    /// 크기순 상위 N개만 반환합니다.
    ///
    /// - Parameter count: 반환할 최대 개수
    /// - Returns: 큰 얼굴부터 최대 count개
    func topBySize(_ count: Int) -> [CachedFace] {
        Array(sortedBySize().prefix(count))
    }
}

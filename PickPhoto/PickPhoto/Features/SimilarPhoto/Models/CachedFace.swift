// CachedFace.swift
// 얼굴 감지 결과 캐시 구조체
//
// T003: CachedFace 구조체 생성
// - boundingBox: Vision 정규화 좌표 (0~1, 원점 좌하단)
// - personIndex: 위치 기반 인물 번호 (1, 2, 3...)
// - isValidSlot: 유효 인물 슬롯 여부 (그룹 내 2장 이상)

import CoreGraphics
import Vision

/// 캐시된 얼굴 감지 결과
/// Vision Framework에서 감지한 얼굴 정보를 저장
struct CachedFace: Equatable {

    // MARK: - Properties

    /// Vision 정규화 좌표 (0~1, 원점 좌하단)
    /// - x, y: 좌하단 모서리 좌표
    /// - width, height: 상대 크기
    /// - Note: UIKit 좌표로 변환 필요 (Y축 반전)
    let boundingBox: CGRect

    /// 위치 기반 인물 번호 (1부터 시작)
    /// - 좌→우, 위→아래 순서로 번호 부여
    /// - Note: 0은 사용하지 않음
    let personIndex: Int

    /// 유효 인물 슬롯 여부
    /// - 그룹 내 동일 위치에서 2장 이상 감지되어야 유효
    /// - +버튼 표시 대상 결정에 사용
    var isValidSlot: Bool

    /// Feature Print (얼굴 크롭 이미지의 특징점)
    /// - 인물 매칭 검증에 사용
    /// - Note: VNFeaturePrintObservation 자체 저장 (메모리 효율)
    var featurePrint: VNFeaturePrintObservation?

    // MARK: - Initialization

    /// 초기화
    /// - Parameters:
    ///   - boundingBox: Vision 정규화 좌표
    ///   - personIndex: 위치 기반 인물 번호 (1 이상)
    ///   - isValidSlot: 유효 인물 슬롯 여부 (기본: false)
    ///   - featurePrint: 얼굴 Feature Print (옵션)
    init(
        boundingBox: CGRect,
        personIndex: Int,
        isValidSlot: Bool = false,
        featurePrint: VNFeaturePrintObservation? = nil
    ) {
        assert(personIndex >= 1, "personIndex는 1 이상이어야 합니다")
        assert(boundingBox.origin.x >= 0 && boundingBox.origin.x <= 1,
               "boundingBox.x는 0~1 범위여야 합니다")
        assert(boundingBox.origin.y >= 0 && boundingBox.origin.y <= 1,
               "boundingBox.y는 0~1 범위여야 합니다")

        self.boundingBox = boundingBox
        self.personIndex = personIndex
        self.isValidSlot = isValidSlot
        self.featurePrint = featurePrint
    }

    // MARK: - Computed Properties

    /// 얼굴 상대 크기 (화면 너비 대비 %)
    /// - 5% 미만은 필터링 대상 (너무 작은 얼굴)
    var relativeSize: CGFloat {
        return boundingBox.width
    }

    /// 얼굴 중심 X 좌표 (정규화)
    var centerX: CGFloat {
        return boundingBox.midX
    }

    /// 얼굴 중심 Y 좌표 (정규화)
    var centerY: CGFloat {
        return boundingBox.midY
    }

    // MARK: - Coordinate Conversion

    /// Vision 좌표를 UIKit 좌표로 변환
    /// - Parameters:
    ///   - imageSize: 원본 이미지 크기
    ///   - viewFrame: 표시할 뷰 프레임
    /// - Returns: UIKit 좌표계의 CGRect
    func convertToUIKit(imageSize: CGSize, viewFrame: CGRect) -> CGRect {
        // aspectFit 스케일 계산
        let scale = min(viewFrame.width / imageSize.width,
                        viewFrame.height / imageSize.height)
        let offsetX = (viewFrame.width - imageSize.width * scale) / 2
        let offsetY = (viewFrame.height - imageSize.height * scale) / 2

        // Vision 좌표 → UIKit 좌표 (Y축 반전)
        return CGRect(
            x: boundingBox.origin.x * imageSize.width * scale + offsetX,
            y: (1 - boundingBox.maxY) * imageSize.height * scale + offsetY,
            width: boundingBox.width * imageSize.width * scale,
            height: boundingBox.height * imageSize.height * scale
        )
    }

    // MARK: - Equatable

    /// Equatable 구현 (featurePrint 제외)
    static func == (lhs: CachedFace, rhs: CachedFace) -> Bool {
        return lhs.boundingBox == rhs.boundingBox &&
               lhs.personIndex == rhs.personIndex &&
               lhs.isValidSlot == rhs.isValidSlot
        // featurePrint는 비교 제외 (참조 비교 불가)
    }
}

// MARK: - Sorting

extension CachedFace {

    /// 위치 기반 정렬 (좌→우, 위→아래)
    /// - X좌표 오름차순, X 동일 시 Y 내림차순
    static func sortedByPosition(_ faces: [CachedFace]) -> [CachedFace] {
        return faces.sorted { lhs, rhs in
            if lhs.centerX != rhs.centerX {
                return lhs.centerX < rhs.centerX // 좌→우
            } else {
                return lhs.centerY > rhs.centerY // 위→아래 (Vision Y축 기준)
            }
        }
    }
}

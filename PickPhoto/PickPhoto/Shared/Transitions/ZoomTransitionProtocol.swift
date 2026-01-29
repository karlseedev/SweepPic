// ZoomTransitionProtocol.swift
// 줌 트랜지션 소스/목적지 프로토콜
//
// 커스텀 줌 트랜지션을 위한 프로토콜 정의
// - iOS 16+ 전 버전에서 동일하게 적용
// - iOS 18의 preferredTransition = .zoom 대체

import UIKit

// MARK: - 소스 제공 프로토콜

/// 줌 전환 소스 제공 (그리드 VC들이 채택)
/// 그리드 → 뷰어 전환 시 시작점 정보 제공
protocol ZoomTransitionSourceProviding: AnyObject {

    /// 줌 애니메이션 시작 뷰 (스냅샷 생성용)
    /// - Parameter index: 현재 뷰어의 인덱스
    /// - Returns: 소스 뷰 (셀의 이미지 뷰) 또는 nil (화면 밖)
    func zoomSourceView(for index: Int) -> UIView?

    /// 줌 애니메이션 시작 프레임
    /// - Parameter index: 현재 뷰어의 인덱스
    /// - Returns: window 좌표계 기준 프레임 또는 nil
    /// - Important: 반드시 `convert(frame, to: nil)` 사용하여 window 좌표계로 반환
    func zoomSourceFrame(for index: Int) -> CGRect?
}

// MARK: - 목적지 제공 프로토콜

/// 줌 전환 목적지 제공 (뷰어 VC가 채택)
/// 그리드 → 뷰어 전환 시 목적지 정보 제공
protocol ZoomTransitionDestinationProviding: AnyObject {

    /// 현재 표시 중인 인덱스
    var currentIndex: Int { get }

    /// 줌 애니메이션 대상 뷰 (이미지 뷰)
    var zoomDestinationView: UIView? { get }

    /// 줌 애니메이션 목적지 프레임
    /// - Returns: window 좌표계 기준 프레임 또는 nil
    /// - Important: 반드시 `convert(frame, to: nil)` 사용하여 window 좌표계로 반환
    var zoomDestinationFrame: CGRect? { get }
}

// MARK: - 줌 가능 이미지 뷰 접근자

/// 줌 애니메이션용 이미지 뷰 접근자
/// PhotoPageViewController, VideoPageViewController가 채택
protocol ZoomableImageProviding: AnyObject {

    /// 줌 애니메이션 대상 이미지 뷰
    var zoomableImageView: UIImageView? { get }

    /// 현재 줌 스케일 (1.0 = 기본)
    var zoomScale: CGFloat { get }

    /// 스크롤이 상단 가장자리인지 (dismiss 허용 판단용)
    var isAtTopEdge: Bool { get }
}

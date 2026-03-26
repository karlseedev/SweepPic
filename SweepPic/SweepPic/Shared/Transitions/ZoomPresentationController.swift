// ZoomPresentationController.swift
// 줌 트랜지션용 Presentation Controller
//
// 핵심: shouldRemovePresentersView = false
// → presenting VC(그리드)가 containerView에 유지됨
// → dismiss 시 좌표 변환(convert(to: nil))이 정상 작동
// → Interactive dismiss 중 그리드 셀 위치 실시간 추적 가능

import UIKit

/// 줌 트랜지션용 Presentation Controller
/// 그리드가 window에서 제거되지 않도록 보장
final class ZoomPresentationController: UIPresentationController {

    /// 핵심: presenting VC의 뷰를 제거하지 않음
    /// false → 그리드가 containerView에 계속 존재
    /// true(기본값)이면 그리드가 제거되어 좌표 변환 실패
    override var shouldRemovePresentersView: Bool { false }
}

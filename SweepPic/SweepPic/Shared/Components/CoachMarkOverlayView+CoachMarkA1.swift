//
//  CoachMarkOverlayView+CoachMarkA1.swift
//  SweepPic
//
//  Created by Claude Code on 2026-02-25.
//
//  코치마크 A-1: 스와이프 삭제 실습 유도
//
//  A 온보딩 완료 후 5초 내 스와이프 삭제를 하지 않으면 표시.
//  - 딤 배경 + 하이라이트 구멍 (스냅샷 없이 실제 셀이 보임)
//  - "셀을 가로로 스와이프해서\n삭제해 보세요" 텍스트
//  - 확인 버튼 없음 — 직접 스와이프 삭제해야만 dismiss
//  - 하이라이트 영역만 터치 통과 (스와이프 가능)
//  - 그 외 모든 터치 차단 (스크롤, 탭, 뒤로가기 불가)
//

import UIKit
import AppCore
import OSLog

// MARK: - Coach Mark A-1: Swipe Practice Overlay

extension CoachMarkOverlayView {

    // MARK: - Show

    /// A-1 전용 표시 (스냅샷/손가락/확인버튼 없음, 하이라이트 영역 터치 통과)
    /// - Parameters:
    ///   - highlightFrame: 셀 프레임 (윈도우 좌표)
    ///   - window: 표시할 윈도우
    static func showA1(highlightFrame: CGRect, in window: UIWindow) {
        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .gridSwipeDelete  // 기존 타입 재사용 (updateDimPath 호환)
        overlay.isA1SwipeMode = true
        overlay.highlightFrame = highlightFrame

        // 딤 배경 + 하이라이트 구멍 (스냅샷 없이 실제 셀이 보임)
        overlay.updateDimPath()

        // 텍스트: "셀을 가로로 스와이프해서\n삭제해 보세요"
        overlay.setupA1Text(below: highlightFrame)
        overlay.addSubview(overlay.messageLabel)

        // 확인 버튼 미추가 (addSubview 안 함 → 표시 안 됨)

        // CoachMarkManager 등록
        CoachMarkManager.shared.currentOverlay = overlay
        CoachMarkManager.shared.isA1Active = true

        // 윈도우에 추가 + 페이드인
        window.addSubview(overlay)
        overlay.alpha = 0
        UIView.animate(withDuration: 0.2) {
            overlay.alpha = 1
        }

        Logger.coachMark.debug("A1 표시 완료 — highlightFrame=\(highlightFrame.debugDescription)")
    }

    // MARK: - Text Setup

    /// A-1 텍스트 설정 — "셀을 가로로 스와이프해서\n삭제해 보세요"
    /// "가로로 스와이프" 키워드 bold + yellow 강조
    private func setupA1Text(below highlightFrame: CGRect) {
        let mainText = "셀을 가로로 스와이프해서\n삭제해 보세요"
        let keyword = "가로로 스와이프"

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.paragraphSpacing = 8  // A와 동일한 행간

        let attributed = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: CoachMarkOverlayView.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )

        // "가로로 스와이프" bold + yellow 강조
        if let range = mainText.range(of: keyword) {
            let nsRange = NSRange(range, in: mainText)
            attributed.addAttributes([
                .font: CoachMarkOverlayView.bodyBoldFont,
                .foregroundColor: CoachMarkOverlayView.highlightYellow
            ], range: nsRange)
        }

        messageLabel.attributedText = attributed
        // 하이라이트 아래 16pt 간격으로 배치
        messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 16,
            width: bounds.width - 40,
            height: 80
        )
    }

    // MARK: - Cleanup

    /// A-1 상태 정리 (dismiss 시 호출)
    func cleanupA1() {
        isA1SwipeMode = false
        CoachMarkManager.shared.isA1Active = false
    }
}

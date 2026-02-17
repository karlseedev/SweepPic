//
//  CoachMarkOverlayView+CoachMarkC.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-17.
//
//  코치마크 C: 유사 사진·얼굴 비교 안내
//  - C-1: 그리드 뱃지 셀 하이라이트 (dim + evenOdd 구멍 + 탭 모션)
//  - C-2: 뷰어 + 버튼 하이라이트 (기존 오버레이 재구성 + 탭 모션)
//  - [확인] 후 탭 모션 → 자동 네비게이션
//  - Reduce Motion: 탭 모션 생략, 즉시 네비게이션
//
//  플로우:
//    C-1: showSimilarBadge() → [확인] → startC_ConfirmSequence() → 탭 모션 → onConfirm(뷰어 네비게이션)
//    C-2: transitionToC2() → [확인] → startC_ConfirmSequence() → 탭 모션 → onConfirm(얼굴 비교 진입)

import UIKit

// MARK: - Coach Mark C: Similar Photo Badge + Face Button

extension CoachMarkOverlayView {

    // MARK: - C-1: Show (Grid Badge Highlight)

    /// C-1: 유사사진 뱃지 셀 하이라이트 코치마크 표시
    /// dim 배경 + 셀 위치에 evenOdd 구멍 + 안내 텍스트 + 확인 버튼
    /// 스냅샷 불필요 — 구멍을 통해 실제 셀이 보임
    /// - Parameters:
    ///   - highlightFrame: 뱃지 셀 프레임 (윈도우 좌표)
    ///   - window: 표시할 윈도우
    ///   - onConfirm: [확인] + 탭 모션 후 실행할 콜백 (뷰어 네비게이션)
    static func showSimilarBadge(
        highlightFrame: CGRect,
        in window: UIWindow,
        onConfirm: @escaping () -> Void
    ) {
        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .similarPhoto
        overlay.highlightFrame = highlightFrame
        overlay.onConfirm = onConfirm
        overlay.alpha = 0

        // 윈도우에 추가 (터치 차단 시작)
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // dim 배경 + evenOdd 구멍 (rounded rect, margin 8pt, cornerRadius 8)
        overlay.updateDimPath()

        // 안내 텍스트 (하이라이트 셀 아래)
        overlay.messageLabel.text = "유사사진 정리기능이 표시된 사진이에요.\n각 사진의 얼굴을 비교해서 정리할 수 있어요"
        overlay.messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 24,
            width: window.bounds.width - 40,
            height: 60
        )
        overlay.addSubview(overlay.messageLabel)

        // 확인 버튼 (iOS 26: glass / iOS 25-: 파란 라운드)
        if #available(iOS 26.0, *) {
            var config = UIButton.Configuration.glass()
            config.title = "확인"
            config.baseForegroundColor = .white
            overlay.confirmButton.configuration = config
            overlay.confirmButton.backgroundColor = .clear
        }
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 44
        overlay.confirmButton.frame = CGRect(
            x: (window.bounds.width - buttonWidth) / 2,
            y: overlay.messageLabel.frame.maxY + 16,
            width: buttonWidth,
            height: buttonHeight
        )
        overlay.addSubview(overlay.confirmButton)

        // 손가락 아이콘 (탭 모션용, 초기 비표시)
        overlay.fingerView.sizeToFit()
        overlay.fingerView.alpha = 0
        overlay.addSubview(overlay.fingerView)

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }

    // MARK: - C-2: Transition (Reuse Overlay)

    /// C-1 → C-2 전환: 기존 오버레이를 유지하면서 내용을 교체
    /// - 오버레이를 제거하지 않아 터치 차단 연속성 보장
    /// - dim path 구멍을 + 버튼 위치로 이동
    /// - 새 카피 + 확인 버튼 페이드인
    /// - Parameters:
    ///   - newHighlightFrame: + 버튼 프레임 (윈도우 좌표)
    ///   - c2OnConfirm: C-2 [확인] + 탭 모션 후 실행할 콜백 (얼굴 비교 진입)
    func transitionToC2(
        newHighlightFrame: CGRect,
        c2OnConfirm: @escaping () -> Void
    ) {
        // 뷰어 전환 후 오버레이가 뷰 계층에서 뒤로 밀릴 수 있으므로 최상단으로
        superview?.bringSubviewToFront(self)

        // 하이라이트 영역 업데이트 (+ 버튼)
        highlightFrame = newHighlightFrame
        updateDimPath()

        // C-2 onConfirm 설정
        onConfirm = c2OnConfirm

        // 안내 텍스트 교체
        messageLabel.text = "+버튼을 눌러 얼굴비교화면으로 이동하세요.\n인물이 여러 명이면 좌우로 넘겨볼 수 있어요."
        messageLabel.alpha = 0
        messageLabel.frame = CGRect(
            x: 20,
            y: newHighlightFrame.maxY + 24,
            width: bounds.width - 40,
            height: 60
        )

        // 확인 버튼 리셋 (재진입 방지 해제)
        confirmButton.isEnabled = true
        confirmButton.alpha = 0
        let buttonWidth: CGFloat = 120
        confirmButton.frame = CGRect(
            x: (bounds.width - buttonWidth) / 2,
            y: messageLabel.frame.maxY + 16,
            width: buttonWidth,
            height: 44
        )

        // 새 카피 + 확인 버튼 페이드인
        UIView.animate(withDuration: 0.3) {
            self.messageLabel.alpha = 1
            self.confirmButton.alpha = 1
        }
    }

    // MARK: - Confirm Sequence

    /// C 전용: [확인] 탭 후 시퀀스
    /// 1. 텍스트+버튼 페이드아웃 (0.2초)
    /// 2. 탭 모션 on 하이라이트 대상 (0.6초, Reduce Motion 시 생략)
    /// 3. onConfirm 콜백 실행
    /// ⚠️ 호출 전 confirmButton.isEnabled = false 필수 (confirmTapped에서 설정)
    func startC_ConfirmSequence() {
        // 1. 확인 버튼 + 카피 페이드아웃 (0.2초)
        UIView.animate(withDuration: 0.2, animations: {
            self.messageLabel.alpha = 0
            self.confirmButton.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            let targetCenter = CGPoint(
                x: self.highlightFrame.midX,
                y: self.highlightFrame.midY
            )

            // 2. 탭 모션 (Reduce Motion 시 생략)
            if UIAccessibility.isReduceMotionEnabled {
                // Reduce Motion: 탭 모션 생략, 즉시 콜백
                self.onConfirm?()
            } else {
                self.performCTapMotion(at: targetCenter) { [weak self] in
                    // 3. onConfirm 콜백
                    self?.onConfirm?()
                }
            }
        }
    }

    // MARK: - Tap Motion Animation

    /// 대상을 "탭한다"는 느낌을 주는 1회성 애니메이션
    /// 총 0.6초: 나타남(0.2s) → 내려오기(0.15s) → 누르기(0.1s) → 떼기(0.15s)
    /// A/B의 반복 스와이프 시연과 달리 1회성 탭 모션
    /// - Parameters:
    ///   - targetCenter: 탭 대상 중앙점 (overlay 좌표 = 윈도우 좌표)
    ///   - completion: 모션 완료 후 콜백
    private func performCTapMotion(at targetCenter: CGPoint, completion: @escaping () -> Void) {
        // 손가락을 대상 약간 위에 배치 (약간 오른쪽 오프셋 — 자연스러운 탭 각도)
        fingerView.center = CGPoint(
            x: targetCenter.x + 10,
            y: targetCenter.y - 40
        )
        fingerView.alpha = 0
        fingerView.transform = .identity

        // Phase 1: 나타남 (0.2초)
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                self.fingerView.alpha = 1
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { completion(); return }

            // Phase 2: 대상 중앙으로 이동 (0.15초)
            UIView.animate(
                withDuration: 0.15,
                delay: 0,
                options: .curveEaseIn,
                animations: {
                    self.fingerView.center = CGPoint(
                        x: targetCenter.x + 10,
                        y: targetCenter.y
                    )
                }
            ) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { completion(); return }

                // 눌림 피드백 (하이라이트 구멍에 흰색 플래시)
                self.showCTapPressFeedback()

                // Phase 3: 누르기 (0.1초, spring — 손가락 scale 축소)
                UIView.animate(
                    withDuration: 0.1,
                    delay: 0,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 0,
                    options: [],
                    animations: {
                        self.fingerView.transform = CGAffineTransform(scaleX: 0.90, y: 0.90)
                    }
                ) { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { completion(); return }

                    // Phase 4: 떼기 (0.15초 — 원래 크기 + 페이드아웃)
                    UIView.animate(
                        withDuration: 0.15,
                        delay: 0,
                        options: .curveEaseOut,
                        animations: {
                            self.fingerView.transform = .identity
                            self.fingerView.alpha = 0
                        }
                    ) { _ in
                        completion()
                    }
                }
            }
        }
    }

    // MARK: - Press Feedback

    /// 탭 모션 중 눌림 피드백
    /// 하이라이트 구멍 영역에 반투명 흰색 플래시 (alpha 0→0.3→0)
    /// C-1: 셀 위에 플래시 / C-2: + 버튼 위에 플래시
    private func showCTapPressFeedback() {
        let margin: CGFloat = 8
        let flashRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
        let flashView = UIView(frame: flashRect)
        flashView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        flashView.layer.cornerRadius = 8
        flashView.alpha = 0

        // 손가락 아래에 삽입 (손가락이 플래시 위에 보이도록)
        insertSubview(flashView, belowSubview: fingerView)

        UIView.animateKeyframes(withDuration: 0.25, delay: 0, options: [], animations: {
            UIView.addKeyframe(withRelativeStartTime: 0, relativeDuration: 0.4) {
                flashView.alpha = 1
            }
            UIView.addKeyframe(withRelativeStartTime: 0.4, relativeDuration: 0.6) {
                flashView.alpha = 0
            }
        }) { _ in
            flashView.removeFromSuperview()
        }
    }
}

//
//  CoachMarkOverlayView+CoachMarkC.swift
//  SweepPic
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

    // MARK: - Constants

    /// C-2 테두리 링 식별용 태그
    static let borderRingTag = 99876

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
        overlay.alpha = 0.01  // hitTest 오버라이드로 터치 차단 즉시 시작 (alpha >= 0.01 필요)

        // 윈도우에 추가 (터치 차단 시작)
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // dim 배경 + evenOdd 구멍 (rounded rect, margin 8pt, cornerRadius 8)
        overlay.updateDimPath()

        // 안내 텍스트 (하이라이트 셀 아래, 행간 1.2배)
        let c1Text = "하얀색 테두리가 표시된 사진은\n여러 사진의 얼굴을 비교해서 삭제하는\n인물사진 비교정리가 가능한 사진이에요"
        let c1Style = NSMutableParagraphStyle()
        c1Style.alignment = .center
        c1Style.lineSpacing = CoachMarkOverlayView.bodyFont.pointSize * 0.2
        let c1Attr = NSMutableAttributedString(
            string: c1Text,
            attributes: [
                .font: CoachMarkOverlayView.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: c1Style
            ]
        )
        if let range = c1Text.range(of: "얼굴을 비교해서 삭제") {
            let nsRange = NSRange(range, in: c1Text)
            c1Attr.addAttributes([
                .font: CoachMarkOverlayView.bodyBoldFont,
                .foregroundColor: CoachMarkOverlayView.highlightYellow
            ], range: nsRange)
        }
        overlay.messageLabel.attributedText = c1Attr
        overlay.messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 24,
            width: window.bounds.width - 40,
            height: 80
        )
        overlay.addSubview(overlay.messageLabel)

        // 확인 버튼 (흰색 라운드, iOS 버전 공통)
        overlay.confirmButton.setTitleColor(.black, for: .normal)
        overlay.confirmButton.backgroundColor = .white
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

        // C-1에서 alpha 0.01로 투명화된 상태 → dim + 구멍 + UI와 함께 복원
        // 먼저 dim path와 레이아웃을 준비한 후 alpha를 페이드인

        // 하이라이트 영역 업데이트
        highlightFrame = newHighlightFrame

        // C-2 onConfirm 설정
        onConfirm = c2OnConfirm

        // 안내 텍스트 준비 (초기 비표시, 포커스 완료 후 페이드인)
        let circleDiameter = max(newHighlightFrame.width, newHighlightFrame.height) * 1.2
        let circleBottom = newHighlightFrame.midY + circleDiameter / 2
        // 메인 텍스트 + ※ 안내 (문단 분리, ※는 16pt)
        let mainText = "+버튼을 눌러 얼굴비교화면으로 이동하세요\u{2028}인물이 여러 명이면 좌우로 넘겨볼 수 있어요"
        let noticeText = "\n※ 얼굴은 각도, 해상도에 따라 검출되지 않거나\u{2028}다른 인물로 분류될 수 있습니다"
        let c2Style = NSMutableParagraphStyle()
        c2Style.alignment = .center
        c2Style.lineSpacing = CoachMarkOverlayView.bodyFont.pointSize * 0.2
        c2Style.paragraphSpacing = 12
        let c2Attr = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: CoachMarkOverlayView.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: c2Style
            ]
        )
        let noticeStyle = NSMutableParagraphStyle()
        noticeStyle.alignment = .center
        noticeStyle.lineSpacing = UIFont.systemFont(ofSize: 16).pointSize * 0.2
        // "+버튼" 키워드 강조
        if let range = mainText.range(of: "+버튼") {
            let nsRange = NSRange(range, in: mainText)
            c2Attr.addAttributes([
                .font: CoachMarkOverlayView.bodyBoldFont,
                .foregroundColor: CoachMarkOverlayView.highlightYellow
            ], range: nsRange)
        }
        // "얼굴비교화면" 키워드 강조
        if let range = mainText.range(of: "얼굴비교화면") {
            let nsRange = NSRange(range, in: mainText)
            c2Attr.addAttributes([
                .font: CoachMarkOverlayView.bodyBoldFont,
                .foregroundColor: CoachMarkOverlayView.highlightYellow
            ], range: nsRange)
        }
        c2Attr.append(NSAttributedString(
            string: noticeText,
            attributes: [
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
                .paragraphStyle: noticeStyle
            ]
        ))
        messageLabel.attributedText = c2Attr
        messageLabel.numberOfLines = 0
        messageLabel.alpha = 0

        // 텍스트+버튼 배치: 아래 공간이 부족하면 포커스 원 위에 배치
        let labelWidth = bounds.width - 40
        let labelSize = messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
        let textHeight = ceil(labelSize.height)
        let circleTop = newHighlightFrame.midY - circleDiameter / 2
        let gap: CGFloat = 24
        let buttonGap: CGFloat = 16
        let buttonHeight: CGFloat = 44
        let safeBottom = window?.safeAreaInsets.bottom ?? 34
        let neededBelow = gap + textHeight + buttonGap + buttonHeight + safeBottom

        let placeAbove = (circleBottom + neededBelow > bounds.height)

        if placeAbove {
            // 포커스 원 위에 배치: 버튼 → 텍스트 (아래에서 위로)
            let buttonY = circleTop - gap - buttonHeight
            let textY = buttonY - buttonGap - textHeight
            messageLabel.frame = CGRect(x: 20, y: textY, width: labelWidth, height: textHeight)
            confirmButton.isEnabled = true
            confirmButton.alpha = 0
            let buttonWidth: CGFloat = 120
            confirmButton.frame = CGRect(
                x: (bounds.width - buttonWidth) / 2,
                y: buttonY,
                width: buttonWidth,
                height: buttonHeight
            )
        } else {
            // 포커스 원 아래에 배치 (기본)
            messageLabel.frame = CGRect(x: 20, y: circleBottom + gap, width: labelWidth, height: textHeight)
            confirmButton.isEnabled = true
            confirmButton.alpha = 0
            let buttonWidth: CGFloat = 120
            confirmButton.frame = CGRect(
                x: (bounds.width - buttonWidth) / 2,
                y: messageLabel.frame.maxY + buttonGap,
                width: buttonWidth,
                height: buttonHeight
            )
        }

        // + 버튼 강조용 흰색 테두리 링 (초기 비표시, 포커스 완료 후 표시)
        let ringDiameter: CGFloat = 39  // FaceButton(34pt) + 테두리(2.5pt×2)
        let borderRing = UIView()
        borderRing.frame = CGRect(
            x: newHighlightFrame.midX - ringDiameter / 2,
            y: newHighlightFrame.midY - ringDiameter / 2,
            width: ringDiameter,
            height: ringDiameter
        )
        borderRing.backgroundColor = .clear
        borderRing.layer.cornerRadius = ringDiameter / 2
        borderRing.layer.borderColor = UIColor.white.cgColor
        borderRing.layer.borderWidth = 2.5
        borderRing.tag = Self.borderRingTag
        borderRing.alpha = 0
        addSubview(borderRing)

        // 1단계: 큰 구멍(시작 상태)을 미리 설정한 뒤 alpha 복원 + 포커스 축소 동시 시작
        // 큰 구멍부터 시작하므로 딤이 갑자기 나타났다 사라지는 깜빡임 방지
        let startDiameter = max(bounds.width, bounds.height) * 3.0
        let startCircleRect = CGRect(
            x: newHighlightFrame.midX - startDiameter / 2,
            y: newHighlightFrame.midY - startDiameter / 2,
            width: startDiameter,
            height: startDiameter
        )
        let startPath = UIBezierPath(rect: bounds)
        startPath.append(UIBezierPath(ovalIn: startCircleRect))
        dimLayer.path = startPath.cgPath

        // alpha 복원 + 포커스 원 축소를 동시에 시작
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1.0
        }
        animateC2FocusCircle(to: newHighlightFrame) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }

            // 2단계: 포커스 완료 → 0.5초 대기 → 텍스트 + 버튼 + 테두리 링 페이드인
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, !self.shouldStopAnimation else { return }
                UIView.animate(withDuration: 0.3) {
                    self.messageLabel.alpha = 1
                    self.confirmButton.alpha = 1
                    borderRing.alpha = 1
                }
            }
        }
    }

    // MARK: - Confirm Sequence

    /// C 전용: [확인] 탭 후 시퀀스
    /// 1. 텍스트+버튼 페이드아웃 (0.2초)
    /// 2. 탭 모션 on 하이라이트 대상 (0.6초, Reduce Motion 시 생략)
    /// 3. onConfirm 콜백 실행
    /// ⚠️ 호출 전 confirmButton.isEnabled = false 필수 (confirmTapped에서 설정)
    func startC_ConfirmSequence() {
        // 1. 확인 버튼 + 카피 + 테두리 링 페이드아웃 (0.2초)
        let borderRing = viewWithTag(Self.borderRingTag)

        UIView.animate(withDuration: 0.2, animations: {
            self.messageLabel.alpha = 0
            self.confirmButton.alpha = 0
            borderRing?.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            // 테두리 링 제거
            borderRing?.removeFromSuperview()

            let targetCenter = CGPoint(
                x: self.highlightFrame.midX,
                y: self.highlightFrame.midY
            )

            // 2. 탭 모션 (Reduce Motion 시 생략)
            if UIAccessibility.isReduceMotionEnabled {
                // dim 구멍 제거 (전체 dim으로 전환 — 뷰어 전환 중 C-1 구멍 노출 방지)
                self.fillDimHole()
                // 오버레이를 거의 투명하게 → 줌 전환 애니메이션이 보이도록
                // alpha 0.01: hitTest 오버라이드로 터치 차단 유지 (UIKit은 alpha >= 0.01에서 hitTest 호출)
                // transitionToC2()에서 alpha 1.0으로 복원
                self.alpha = 0.01
                self.onConfirm?()
            } else {
                self.performCTapMotion(at: targetCenter) { [weak self] in
                    // 3. dim 구멍 제거 후 오버레이 투명화 → onConfirm 콜백
                    self?.fillDimHole()
                    // 오버레이를 거의 투명하게 → push 줌 전환 애니메이션이 보이도록
                    // alpha 0.01: hitTest 오버라이드로 터치 차단 유지
                    // transitionToC2()에서 alpha 1.0으로 복원
                    self?.alpha = 0.01
                    self?.onConfirm?()
                }
            }
        }
    }

    // MARK: - Tap Motion Animation

    /// 대상을 "탭한다"는 느낌을 주는 1회성 애니메이션
    /// 이동 없이 타겟 위치에서 바로 등장 → 누르기 → 떼기
    /// 누르기 표현: 회전 없이 Scale + Y이동 + 그림자 변화로 표면 밀착감 전달
    /// 총 ~0.65초: 등장(0.15s) → 누르기(0.12s) → 유지(0.05s) → 떼기(0.2s)
    /// - Parameters:
    ///   - targetCenter: 탭 대상 중앙점 (overlay 좌표 = 윈도우 좌표)
    ///   - completion: 모션 완료 후 콜백
    private func performCTapMotion(at targetCenter: CGPoint, completion: @escaping () -> Void) {
        // 타겟 위치에 바로 배치
        // hand.point.up.fill: 손가락 끝이 이미지 상단에서 약간 왼쪽에 위치
        // → x를 오른쪽으로 보정 (손가락 끝 ≈ 이미지 중앙 좌측), y를 아래로 오프셋
        let fingerWidth = fingerView.bounds.width
        let fingerHeight = fingerView.bounds.height
        let initialCenter = CGPoint(
            x: targetCenter.x + fingerWidth * 0.08,
            y: targetCenter.y + fingerHeight * 0.4
        )
        fingerView.center = initialCenter
        fingerView.alpha = 0
        fingerView.transform = .identity
        // 초기 그림자 상태 (화면에서 떠있는 상태)
        fingerView.layer.shadowRadius = 6
        fingerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        fingerView.layer.shadowOpacity = 0.3

        // Phase 1: 등장 (0.15초)
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                self.fingerView.alpha = 1
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { completion(); return }

            // 눌림 피드백 (하이라이트 구멍에 스냅샷 축소 + 흰색 플래시)
            self.showCTapPressFeedback()

            // Phase 2: 누르기 (0.12초, spring)
            // 회전 없이 3가지 깊이 단서: 축소 + 아래 이동 + 그림자 축소
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    // 1. 축소 (화면에 가까워지는 원근)
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
                    // 2. 아래로 이동 (누르는 방향)
                    self.fingerView.center.y = initialCenter.y + 2.5
                    // 3. 그림자 축소 (표면 밀착 → 그림자 짧아짐)
                    self.fingerView.layer.shadowRadius = 2
                    self.fingerView.layer.shadowOffset = CGSize(width: 0, height: 1)
                    self.fingerView.layer.shadowOpacity = 0.15
                }
            ) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { completion(); return }

                // Phase 3: 떼기 (0.2초, 누른 상태 0.05초 유지 후 spring 반동)
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0.05,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 2.0,
                    options: [],
                    animations: {
                        // 원래 상태로 복원 + 페이드아웃
                        self.fingerView.transform = .identity
                        self.fingerView.center = initialCenter
                        self.fingerView.alpha = 0
                        // 그림자 복원
                        self.fingerView.layer.shadowRadius = 6
                        self.fingerView.layer.shadowOffset = CGSize(width: 0, height: 2)
                        self.fingerView.layer.shadowOpacity = 0.3
                    }
                ) { _ in
                    completion()
                }
            }
        }
    }

    // MARK: - Dim Hole Control

    /// C-2 포커스 원 축소 애니메이션 (E-1 animateFocusCircle과 동일 패턴)
    /// 화면 전체 크기의 큰 원에서 + 버튼 주변 작은 원으로 축소
    /// - Parameters:
    ///   - targetFrame: + 버튼 프레임 (윈도우 좌표)
    ///   - completion: 애니메이션 완료 후 콜백
    private func animateC2FocusCircle(to targetFrame: CGRect, completion: @escaping () -> Void) {
        let scale: CGFloat = 1.2
        // 최종 원 (+ 버튼 기준 1.2배)
        let finalDiameter = max(targetFrame.width, targetFrame.height) * scale
        let finalCircleRect = CGRect(
            x: targetFrame.midX - finalDiameter / 2,
            y: targetFrame.midY - finalDiameter / 2,
            width: finalDiameter,
            height: finalDiameter
        )

        // 시작 원 (화면 밖에서부터 축소되도록 3배 크기)
        let startDiameter = max(bounds.width, bounds.height) * 3.0
        let startCircleRect = CGRect(
            x: targetFrame.midX - startDiameter / 2,
            y: targetFrame.midY - startDiameter / 2,
            width: startDiameter,
            height: startDiameter
        )

        // 시작 경로 (큰 구멍 = 딤 거의 없음)
        let startPath = UIBezierPath(rect: bounds)
        startPath.append(UIBezierPath(ovalIn: startCircleRect))

        // 최종 경로 (작은 구멍 = + 버튼만 투명)
        let endPath = UIBezierPath(rect: bounds)
        endPath.append(UIBezierPath(ovalIn: finalCircleRect))

        // CABasicAnimation으로 path 보간
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.highlightFrame = targetFrame
            self.dimLayer.path = endPath.cgPath
            self.dimLayer.removeAnimation(forKey: "c2FocusCircle")
            completion()
        }

        dimLayer.path = startPath.cgPath
        let dimAnim = CABasicAnimation(keyPath: "path")
        dimAnim.fromValue = startPath.cgPath
        dimAnim.toValue = endPath.cgPath
        dimAnim.duration = 0.9
        dimAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dimAnim.fillMode = .forwards
        dimAnim.isRemovedOnCompletion = false
        dimLayer.add(dimAnim, forKey: "c2FocusCircle")

        CATransaction.commit()
    }

    /// C-2용 원형 dim 구멍 — 버튼 중심 기준 원형 투명 영역
    /// - Parameters:
    ///   - frame: 버튼 프레임 (윈도우 좌표)
    ///   - scale: 구멍 크기 배율 (1.0 = 버튼 크기, 1.5 = 1.5배)
    private func updateDimPathCircle(for frame: CGRect, scale: CGFloat) {
        let fullPath = UIBezierPath(rect: bounds)
        // 버튼의 긴 변 기준 지름 계산 후 scale 적용
        let diameter = max(frame.width, frame.height) * scale
        let center = CGPoint(x: frame.midX, y: frame.midY)
        let circleRect = CGRect(
            x: center.x - diameter / 2,
            y: center.y - diameter / 2,
            width: diameter,
            height: diameter
        )
        let holePath = UIBezierPath(ovalIn: circleRect)
        fullPath.append(holePath)
        dimLayer.path = fullPath.cgPath
    }

    /// dim 구멍 제거 — evenOdd 구멍 없이 전체 dim으로 전환
    /// C-1 탭 모션 완료 후 뷰어 네비게이션 전에 호출
    /// iOS 26 push 전환 시 C-1 구멍이 전환 중 노출되는 것을 방지
    /// CATransaction으로 암묵적 CA 애니메이션(0.25초) 제거 → 즉시 전환
    private func fillDimHole() {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let fullPath = UIBezierPath(rect: bounds)
        dimLayer.path = fullPath.cgPath
        CATransaction.commit()
    }

    // MARK: - C 간편정리 하이라이트 (Phase 3: 버그 #2, #5 대응)

    /// C 완료 �� 간편정리 버튼 안내 코치마크 표시
    /// D와 유사한 구조 (pill shape 하이라이트 + 카드)
    /// - Parameters:
    ///   - highlightFrame: 간편정리 버튼 프레임 (윈도우 좌표)
    ///   - window: 표시할 윈도우
    ///   - onConfirm: 확인 버튼 콜백
    static func showCleanupGuide(
        highlightFrame: CGRect,
        in window: UIWindow,
        onConfirm: @escaping () -> Void
    ) {
        let overlay = CoachMarkOverlayView(frame: window.bounds)
        // .autoCleanup 타입 사용 (pill shape 하이라이트 재사용)
        overlay.coachMarkType = .autoCleanup
        overlay.highlightFrame = highlightFrame
        overlay.alpha = 0

        // 큰 pill에서 시작 → 버튼 모양으로 축소 (D showAutoCleanup과 동일 패턴)
        let margin: CGFloat = 8
        let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)
        let scaleFactor = max(overlay.bounds.width, overlay.bounds.height) * 3.0
            / max(holeRect.width, holeRect.height)
        let startWidth = holeRect.width * scaleFactor
        let startHeight = holeRect.height * scaleFactor
        let startRect = CGRect(
            x: holeRect.midX - startWidth / 2,
            y: holeRect.midY - startHeight / 2,
            width: startWidth,
            height: startHeight
        )
        let startPath = UIBezierPath(rect: overlay.bounds)
        startPath.append(UIBezierPath(roundedRect: startRect, cornerRadius: startRect.height / 2))
        overlay.dimLayer.path = startPath.cgPath

        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 안내 텍스트 (C-1과 동일 스타일: bodyFont, white, 강조 bodyBoldFont + yellow)
        let mainText = "간편정리 메뉴에서\n더욱 편리하게 자동 탐색이 가능해요"
        let pathText = "\n\n간편정리 → 인물사진 비교정리"
        let fullText = mainText + pathText
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = bodyFont.pointSize * 0.2
        style.paragraphSpacing = 12
        let attr = NSMutableAttributedString(
            string: fullText,
            attributes: [
                .font: bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )
        // "자동 탐색" 강조
        if let range = fullText.range(of: "자동 탐색") {
            let nsRange = NSRange(range, in: fullText)
            attr.addAttributes([
                .font: bodyBoldFont,
                .foregroundColor: highlightYellow,
            ], range: nsRange)
        }
        // 메뉴 경로: 16pt regular, white 70%
        if let range = fullText.range(of: "간편정리 → 인물사진 비교정리") {
            let nsRange = NSRange(range, in: fullText)
            attr.addAttributes([
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            ], range: nsRange)
        }
        overlay.messageLabel.attributedText = attr
        overlay.messageLabel.alpha = 0

        // 텍스트 위치: 하이라이트 아래 배치 (C-1과 동일 패턴)
        let labelWidth = window.bounds.width - 40
        let labelSize = overlay.messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
        overlay.messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 24,
            width: labelWidth,
            height: ceil(labelSize.height)
        )
        overlay.addSubview(overlay.messageLabel)

        // 확인 버튼 (C-1과 동일: 흰색 라운드)
        overlay.confirmButton.setTitleColor(.black, for: .normal)
        overlay.confirmButton.backgroundColor = .white
        overlay.confirmButton.isEnabled = true
        overlay.confirmButton.alpha = 0
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 44
        overlay.confirmButton.frame = CGRect(
            x: (window.bounds.width - buttonWidth) / 2,
            y: overlay.messageLabel.frame.maxY + 16,
            width: buttonWidth,
            height: buttonHeight
        )

        // 기존 타겟 제거 + 커스텀 액션 추가 (버그 #2, #5 대응)
        // dismiss()를 호출하지 않아 .autoCleanup.markAsShown() 방지
        overlay.confirmButton.removeTarget(overlay, action: nil, for: .touchUpInside)
        overlay.confirmButton.addAction(UIAction { [weak overlay] _ in
            CoachMarkManager.shared.currentOverlay = nil
            UIView.animate(withDuration: 0.2, animations: {
                overlay?.alpha = 0
            }) { _ in
                overlay?.removeFromSuperview()
                onConfirm()
            }
        }, for: .touchUpInside)

        overlay.addSubview(overlay.confirmButton)

        // lifecycle dismiss 대응 (버그 #4 보완)
        overlay.onDismiss = {
            CoachMarkType.autoCleanup.resetShown()
        }

        // 포커싱 모션 → 텍스트 + 버튼 페이드인 (C-2와 동일 패턴)
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
        overlay.animateDFocus(to: highlightFrame) {
            guard !overlay.shouldStopAnimation else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !overlay.shouldStopAnimation else { return }
                UIView.animate(withDuration: 0.3) {
                    overlay.messageLabel.alpha = 1
                    overlay.confirmButton.alpha = 1
                }
            }
        }
    }

    // MARK: - Press Feedback

    /// 탭 모션 중 눌림 피드백
    /// 1. dim 구멍 안 실제 콘텐츠를 스냅샷 → scale 0.95 축소 (눌림감)
    /// 2. 반투명 흰색 플래시 (alpha 0→0.3→0)
    /// C-1: 셀 눌림 / C-2: + 버튼 눌림
    private func showCTapPressFeedback() {
        let margin: CGFloat = 8
        let holeRect = highlightFrame.insetBy(dx: -margin, dy: -margin)

        // 1. 타겟 영역 스냅샷 → 축소 효과 (실제 뷰를 건드리지 않음)
        if let window = superview,
           let snapshot = window.resizableSnapshotView(
               from: highlightFrame,
               afterScreenUpdates: false,
               withCapInsets: .zero
           ) {
            snapshot.frame = highlightFrame
            insertSubview(snapshot, belowSubview: fingerView)

            // 축소 + 복원 spring
            UIView.animate(
                withDuration: 0.1,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    snapshot.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
                }
            ) { _ in
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0.05,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 2.0,
                    options: [],
                    animations: {
                        snapshot.transform = .identity
                        snapshot.alpha = 0
                    }
                ) { _ in
                    snapshot.removeFromSuperview()
                }
            }
        }

        // 2. 흰색 플래시 (기존)
        let flashView = UIView(frame: holeRect)
        flashView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
        flashView.layer.cornerRadius = 8
        flashView.alpha = 0
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

//
//  CoachMarkOverlayView+CoachMarkD1.swift
//  SweepPic
//
//  Created by Claude Code on 2026-04-07.
//
//  코치마크 D-1: 자동정리 미리보기 안내 (4단계 포커싱 시퀀스)
//
//  Step 1: 헤더 타이틀 포커싱 (pill) — 품질 등급 분류 설명
//  Step 2: 더보기/제외 버튼 포커싱 (pill) — 3~4등급 선택 가능 안내
//  Step 3: 중앙 셀 포커싱 (rect) + 스와이프 모션 — 클릭/스와이프 제외 안내
//  Step 4: 삭제대기함 이동 버튼 포커싱 (pill) — 선별 완료 후 삭제 안내
//
//  전환 방식: 확대→축소 패턴 (C-2 검증 패턴)
//  markAsShown: Step 4 [확인] 완료 시에만 (중간 이탈 시 다음에 다시 표시)
//

import UIKit
import ObjectiveC
import OSLog

// MARK: - Associated Object Keys (D-1 전용)

private var d1CurrentStepKey: UInt8 = 0
private var d1SnapshotViewKey: UInt8 = 0
private var d1GreenViewKey: UInt8 = 0
private var d1FakeExpandButtonKey: UInt8 = 0
private var d1StepFramesKey: UInt8 = 0
private var d1SwipeDistanceKey: UInt8 = 0
private var d1SwipeLoopActiveKey: UInt8 = 0

// MARK: - D-1 Focus Shape

/// D-1 포커싱 구멍 형태
private enum D1FocusShape {
    case pill   // roundedRect, cornerRadius = height/2, margin 8pt
    case rect   // roundedRect, cornerRadius = 0, margin 0pt
}

// MARK: - Coach Mark D-1: Auto Cleanup Preview Guide

extension CoachMarkOverlayView {

    // MARK: - Stored Properties (Associated Objects)

    /// 현재 단계 (1~4)
    var d1CurrentStep: Int {
        get { objc_getAssociatedObject(self, &d1CurrentStepKey) as? Int ?? 1 }
        set { objc_setAssociatedObject(self, &d1CurrentStepKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 3 셀 스냅샷 뷰
    private var d1SnapshotView: UIView? {
        get { objc_getAssociatedObject(self, &d1SnapshotViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &d1SnapshotViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 3 녹색 딤드 뷰
    private var d1GreenView: UIView? {
        get { objc_getAssociatedObject(self, &d1GreenViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &d1GreenViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 2 임시 버튼 (secondaryStack 미표시 시)
    private var d1FakeExpandButton: UIView? {
        get { objc_getAssociatedObject(self, &d1FakeExpandButtonKey) as? UIView }
        set { objc_setAssociatedObject(self, &d1FakeExpandButtonKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 4개 스텝의 포커싱 프레임 [step1, step2, step3, step4]
    private var d1StepFrames: [CGRect] {
        get { (objc_getAssociatedObject(self, &d1StepFramesKey) as? [NSValue])?.map(\.cgRectValue) ?? [] }
        set {
            let values = newValue.map { NSValue(cgRect: $0) }
            objc_setAssociatedObject(self, &d1StepFramesKey, values, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Step 3 스와이프 거리 (셀 너비)
    private var d1SwipeDistance: CGFloat {
        get { objc_getAssociatedObject(self, &d1SwipeDistanceKey) as? CGFloat ?? 0 }
        set { objc_setAssociatedObject(self, &d1SwipeDistanceKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 3 스와이프 루프 활성 플래그 (shouldStopAnimation 대신 사용 — 전환 체인 중단 방지)
    private var d1SwipeLoopActive: Bool {
        get { objc_getAssociatedObject(self, &d1SwipeLoopActiveKey) as? Bool ?? false }
        set { objc_setAssociatedObject(self, &d1SwipeLoopActiveKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Constants

    /// 녹색 딤드 색상 (제외된 사진 = 보존됨)
    private static let d1GreenColor = UIColor(red: 0, green: 0.5, blue: 0, alpha: 1)
    /// 녹색 딤드 알파 (maroonAlpha와 동일)
    private static let d1GreenAlpha: CGFloat = 0.60

    // MARK: - Show (진입점)

    /// D-1: 자동정리 미리보기 4단계 코치마크 표시
    /// - Parameters:
    ///   - step1Frame: 헤더 타이틀 프레임 (윈도우 좌표)
    ///   - step2Frame: secondaryStack 프레임 (nil이면 임시 버튼 생성)
    ///   - step3CellFrame: 중앙 셀 프레임 (윈도우 좌표)
    ///   - step3Snapshot: 셀 스냅샷 뷰
    ///   - step4Frame: primaryButton 프레임 (윈도우 좌표)
    ///   - bottomViewTopY: 하단 뷰 상단 Y (임시 버튼 배치용)
    ///   - window: 표시할 윈도우
    static func showAutoCleanupPreview(
        step1Frame: CGRect,
        step2Frame: CGRect?,
        step3CellFrame: CGRect,
        step3Snapshot: UIView,
        step4Frame: CGRect,
        bottomViewTopY: CGFloat,
        in window: UIWindow
    ) {
        // VoiceOver 가드
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .autoCleanupPreview
        overlay.d1CurrentStep = 1
        overlay.highlightFrame = step1Frame

        // Step 2 프레임 결정 (secondaryStack이 없으면 임시 버튼 위치 계산)
        let effectiveStep2Frame: CGRect
        if let frame = step2Frame {
            effectiveStep2Frame = frame
        } else {
            // primaryButton 하단 8pt에 임시 버튼 배치 (실제 레이아웃과 동일)
            let buttonHeight: CGFloat = 48
            let horizontalPadding: CGFloat = 20
            let buttonWidth = window.bounds.width - horizontalPadding * 2
            let primaryBottom = bottomViewTopY + 12 + 44  // primaryButton top=12, height=44
            let buttonY = primaryBottom + 8
            effectiveStep2Frame = CGRect(x: horizontalPadding, y: buttonY, width: buttonWidth, height: buttonHeight)
        }

        // 4개 프레임 저장
        overlay.d1StepFrames = [step1Frame, effectiveStep2Frame, step3CellFrame, step4Frame]
        overlay.d1SwipeDistance = step3CellFrame.width

        // Step 3 스냅샷 미리 저장 (나중에 사용)
        step3Snapshot.frame = step3CellFrame
        step3Snapshot.clipsToBounds = true
        step3Snapshot.alpha = 0
        overlay.d1SnapshotView = step3Snapshot

        // Step 2 임시 버튼 필요 시 생성
        if step2Frame == nil {
            let fakeButton = overlay.buildD1FakeExpandButton(frame: effectiveStep2Frame)
            fakeButton.alpha = 0
            overlay.addSubview(fakeButton)
            overlay.d1FakeExpandButton = fakeButton
        }

        // 즉시 터치 차단 (alpha 0.01 — hitTest 활성화)
        overlay.alpha = 0.01

        // 화면 전체 크기 pill로 시작 (딤 없음 상태)
        let margin: CGFloat = 8
        let holeRect = step1Frame.insetBy(dx: -margin, dy: -margin)
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

        // alpha 페이드인 (0.3s) + pill 포커싱 축소 (0.9s) 동시
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
        overlay.animateDFocus(to: step1Frame) {
            guard !overlay.shouldStopAnimation else { return }
            // 포커싱 완료 → 0.5s 대기 → 텍스트 페이드인
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard !overlay.shouldStopAnimation else { return }
                overlay.buildD1Step1Content()
                UIView.animate(withDuration: 0.3) {
                    overlay.messageLabel.alpha = 1
                    overlay.confirmButton.alpha = 1
                } completion: { _ in
                    overlay.confirmButton.isEnabled = true
                }
            }
        }
    }

    // MARK: - Step Content Builders

    /// Step 1: 헤더 타이틀 안내 (텍스트 아래 배치)
    private func buildD1Step1Content() {
        let mainText = String(localized: "coachMark.d1.step1.body")
        let keyword1 = String(localized: "coachMark.d1.step1.keyword1")
        let keyword2 = String(localized: "coachMark.d1.step1.keyword2")

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = Self.bodyFont.pointSize * 0.2
        style.paragraphSpacing = 12

        let attr = NSMutableAttributedString(
            string: mainText,
            attributes: [.font: Self.bodyFont, .foregroundColor: UIColor.white, .paragraphStyle: style]
        )
        // 키워드 강조
        for keyword in [keyword1, keyword2] {
            if let range = mainText.range(of: keyword) {
                let nsRange = NSRange(range, in: mainText)
                attr.addAttributes([.font: Self.bodyBoldFont, .foregroundColor: Self.highlightYellow], range: nsRange)
            }
        }
        messageLabel.attributedText = attr
        messageLabel.numberOfLines = 0
        messageLabel.alpha = 0

        // 레이아웃: 포커싱 아래 24pt
        let frame = d1StepFrames[0]
        let margin: CGFloat = 8
        let highlightBottom = frame.maxY + margin
        let labelWidth = bounds.width - 40
        let textHeight = ceil(messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height)
        messageLabel.frame = CGRect(x: 20, y: highlightBottom + 24, width: labelWidth, height: textHeight)
        addSubview(messageLabel)

        // 확인 버튼
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = false
        confirmButton.alpha = 0
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 44
        confirmButton.frame = CGRect(
            x: (bounds.width - buttonWidth) / 2,
            y: messageLabel.frame.maxY + 16,
            width: buttonWidth,
            height: buttonHeight
        )
        addSubview(confirmButton)
    }

    /// Step 2: 더보기/제외 버튼 안내 (텍스트 위 배치)
    private func buildD1Step2Content() {
        let mainText = String(localized: "coachMark.d1.step2.body")
        let noticeText = String(localized: "coachMark.d1.step2.notice")
        let keyword1 = String(localized: "coachMark.d1.step2.keyword1")
        let keyword2 = String(localized: "coachMark.d1.step2.keyword2")

        let fullText = mainText + noticeText

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = Self.bodyFont.pointSize * 0.2
        style.paragraphSpacing = 12

        let attr = NSMutableAttributedString(
            string: fullText,
            attributes: [.font: Self.bodyFont, .foregroundColor: UIColor.white, .paragraphStyle: style]
        )
        // 키워드 강조
        for keyword in [keyword1, keyword2] {
            if let range = fullText.range(of: keyword) {
                let nsRange = NSRange(range, in: fullText)
                attr.addAttributes([.font: Self.bodyBoldFont, .foregroundColor: Self.highlightYellow], range: nsRange)
            }
        }
        // 부가 텍스트 스타일 (C-2 ※ 패턴: 16pt regular, white 70%)
        if let range = fullText.range(of: noticeText) {
            let noticeStyle = NSMutableParagraphStyle()
            noticeStyle.alignment = .center
            noticeStyle.lineSpacing = UIFont.systemFont(ofSize: 16).pointSize * 0.2
            let nsRange = NSRange(range, in: fullText)
            attr.addAttributes([
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            ], range: nsRange)
        }
        messageLabel.attributedText = attr
        messageLabel.alpha = 0

        // 레이아웃: 포커싱 위 배치
        let frame = d1StepFrames[1]
        let margin: CGFloat = 8
        let highlightTop = frame.minY - margin
        let labelWidth = bounds.width - 40
        let textHeight = ceil(messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height)
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 44
        confirmButton.frame = CGRect(
            x: (bounds.width - buttonWidth) / 2,
            y: highlightTop - 24 - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )
        messageLabel.frame = CGRect(
            x: 20,
            y: confirmButton.frame.minY - 16 - textHeight,
            width: labelWidth,
            height: textHeight
        )
        confirmButton.alpha = 0
        confirmButton.isEnabled = false
    }

    /// Step 3: 셀 스와이프 안내 (C-2식 자동 위/아래 판단)
    private func buildD1Step3Content() {
        let mainText = String(localized: "coachMark.d1.step3.body")
        let noticeText = String(localized: "coachMark.d1.step3.notice")
        let keyword1 = String(localized: "coachMark.d1.step3.keyword1")
        let keyword2 = String(localized: "coachMark.d1.step3.keyword2")
        let keyword3 = String(localized: "coachMark.d1.step3.keyword3")

        let fullText = mainText + noticeText

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = Self.bodyFont.pointSize * 0.2
        style.paragraphSpacing = 12

        let attr = NSMutableAttributedString(
            string: fullText,
            attributes: [.font: Self.bodyFont, .foregroundColor: UIColor.white, .paragraphStyle: style]
        )
        for keyword in [keyword1, keyword2, keyword3] {
            if let range = fullText.range(of: keyword) {
                let nsRange = NSRange(range, in: fullText)
                attr.addAttributes([.font: Self.bodyBoldFont, .foregroundColor: Self.highlightYellow], range: nsRange)
            }
        }
        // 부가 텍스트 (C-2 ※ 패턴)
        if let range = fullText.range(of: noticeText) {
            let nsRange = NSRange(range, in: fullText)
            attr.addAttributes([
                .font: UIFont.systemFont(ofSize: 16, weight: .regular),
                .foregroundColor: UIColor.white.withAlphaComponent(0.7),
            ], range: nsRange)
        }
        messageLabel.attributedText = attr
        messageLabel.alpha = 0

        // C-2식 상단/하단 자동 판단
        let cellFrame = d1StepFrames[2]
        let labelWidth = bounds.width - 40
        let textHeight = ceil(messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height)
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 44
        let gap: CGFloat = 24
        let buttonGap: CGFloat = 16
        let neededBelow = gap + textHeight + buttonGap + buttonHeight + (safeAreaInsets.bottom + 20)
        let placeAbove = (cellFrame.maxY + neededBelow > bounds.height)

        if placeAbove {
            // 위 배치
            confirmButton.frame = CGRect(
                x: (bounds.width - buttonWidth) / 2,
                y: cellFrame.minY - gap - buttonHeight,
                width: buttonWidth,
                height: buttonHeight
            )
            messageLabel.frame = CGRect(
                x: 20,
                y: confirmButton.frame.minY - buttonGap - textHeight,
                width: labelWidth,
                height: textHeight
            )
        } else {
            // 아래 배치
            messageLabel.frame = CGRect(x: 20, y: cellFrame.maxY + gap, width: labelWidth, height: textHeight)
            confirmButton.frame = CGRect(
                x: (bounds.width - buttonWidth) / 2,
                y: messageLabel.frame.maxY + buttonGap,
                width: buttonWidth,
                height: buttonHeight
            )
        }
        confirmButton.alpha = 0
        confirmButton.isEnabled = false
    }

    /// Step 4: 삭제대기함 이동 버튼 안내 (텍스트 위 배치)
    private func buildD1Step4Content() {
        let mainText = String(localized: "coachMark.d1.step4.body")
        let keyword1 = String(localized: "coachMark.d1.step4.keyword1")
        let keyword2 = String(localized: "coachMark.d1.step4.keyword2")

        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = Self.bodyFont.pointSize * 0.2
        style.paragraphSpacing = 12

        let attr = NSMutableAttributedString(
            string: mainText,
            attributes: [.font: Self.bodyFont, .foregroundColor: UIColor.white, .paragraphStyle: style]
        )
        for keyword in [keyword1, keyword2] {
            if let range = mainText.range(of: keyword) {
                let nsRange = NSRange(range, in: mainText)
                attr.addAttributes([.font: Self.bodyBoldFont, .foregroundColor: Self.highlightYellow], range: nsRange)
            }
        }
        messageLabel.attributedText = attr
        messageLabel.alpha = 0

        // 포커싱 위 배치
        let frame = d1StepFrames[3]
        let margin: CGFloat = 8
        let highlightTop = frame.minY - margin
        let labelWidth = bounds.width - 40
        let textHeight = ceil(messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude)).height)
        let buttonWidth: CGFloat = 120
        let buttonHeight: CGFloat = 44
        confirmButton.frame = CGRect(
            x: (bounds.width - buttonWidth) / 2,
            y: highlightTop - 24 - buttonHeight,
            width: buttonWidth,
            height: buttonHeight
        )
        messageLabel.frame = CGRect(
            x: 20,
            y: confirmButton.frame.minY - 16 - textHeight,
            width: labelWidth,
            height: textHeight
        )
        confirmButton.alpha = 0
        confirmButton.isEnabled = false
    }

    // MARK: - Confirm Sequence

    /// D-1 전용: [확인] 탭 후 step별 분기
    func handleD1ConfirmTapped() {
        switch d1CurrentStep {
        case 1: transitionToD1Step2()
        case 2: transitionToD1Step3()
        case 3: transitionToD1Step4()
        case 4:
            // 4단계 완료 — markAsShown 후 dismiss
            CoachMarkType.autoCleanupPreview.markAsShown()
            dismiss()
        default:
            dismiss()
        }
    }

    // MARK: - Step Transitions (확대→축소 패턴)

    /// Step 1→2: pill→pill
    private func transitionToD1Step2() {
        CoachMarkManager.shared.isD1SequenceActive = true

        // 텍스트+버튼 페이드아웃
        UIView.animate(withDuration: 0.2, animations: {
            self.messageLabel.alpha = 0
            self.confirmButton.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else {
                CoachMarkManager.shared.isD1SequenceActive = false
                return
            }
            // 확대 → 축소
            self.animateD1Expand { [weak self] in
                guard let self, !self.shouldStopAnimation else {
                    CoachMarkManager.shared.isD1SequenceActive = false
                    return
                }
                let targetFrame = self.d1StepFrames[1]
                self.highlightFrame = targetFrame
                self.animateD1Shrink(to: targetFrame, shape: .pill) { [weak self] in
                    guard let self, !self.shouldStopAnimation else {
                        CoachMarkManager.shared.isD1SequenceActive = false
                        return
                    }
                    // 0.5s 대기 → 텍스트 페이드인
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self, !self.shouldStopAnimation else {
                            CoachMarkManager.shared.isD1SequenceActive = false
                            return
                        }
                        // 임시 버튼 표시 (있으면)
                        if let fake = self.d1FakeExpandButton {
                            fake.alpha = 1
                        }
                        self.buildD1Step2Content()
                        UIView.animate(withDuration: 0.3, animations: {
                            self.messageLabel.alpha = 1
                            self.confirmButton.alpha = 1
                        }) { _ in
                            self.d1CurrentStep = 2
                            CoachMarkManager.shared.isD1SequenceActive = false
                            self.confirmButton.isEnabled = true
                        }
                    }
                }
            }
        }
    }

    /// Step 2→3: pill→rect + 스냅샷 배치
    private func transitionToD1Step3() {
        CoachMarkManager.shared.isD1SequenceActive = true

        // 텍스트+버튼+임시버튼 페이드아웃
        UIView.animate(withDuration: 0.2, animations: {
            self.messageLabel.alpha = 0
            self.confirmButton.alpha = 0
            self.d1FakeExpandButton?.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else {
                CoachMarkManager.shared.isD1SequenceActive = false
                return
            }
            self.animateD1Expand { [weak self] in
                guard let self, !self.shouldStopAnimation else {
                    CoachMarkManager.shared.isD1SequenceActive = false
                    return
                }
                let targetFrame = self.d1StepFrames[2]
                self.highlightFrame = targetFrame

                // 스냅샷 + 녹색 딤드 배치 (alpha 0)
                if let snapshot = self.d1SnapshotView {
                    snapshot.frame = targetFrame
                    self.addSubview(snapshot)
                    // 녹색 딤드 (초기 width 0)
                    let greenView = UIView()
                    greenView.backgroundColor = Self.d1GreenColor
                    greenView.alpha = Self.d1GreenAlpha
                    greenView.frame = CGRect(x: 0, y: 0, width: 0, height: targetFrame.height)
                    snapshot.addSubview(greenView)
                    self.d1GreenView = greenView
                }

                self.animateD1Shrink(to: targetFrame, shape: .rect) { [weak self] in
                    guard let self, !self.shouldStopAnimation else {
                        CoachMarkManager.shared.isD1SequenceActive = false
                        return
                    }
                    // 0.5s 대기 → 스냅샷 페이드인 → 텍스트 페이드인
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self, !self.shouldStopAnimation else {
                            CoachMarkManager.shared.isD1SequenceActive = false
                            return
                        }
                        // 스냅샷 페이드인
                        UIView.animate(withDuration: 0.2, animations: {
                            self.d1SnapshotView?.alpha = 1
                        }) { [weak self] _ in
                            guard let self, !self.shouldStopAnimation else {
                                CoachMarkManager.shared.isD1SequenceActive = false
                                return
                            }
                            self.buildD1Step3Content()
                            UIView.animate(withDuration: 0.3, animations: {
                                self.messageLabel.alpha = 1
                                self.confirmButton.alpha = 1
                            }) { _ in
                                self.d1CurrentStep = 3
                                CoachMarkManager.shared.isD1SequenceActive = false
                                self.confirmButton.isEnabled = true
                                // 스와이프 모션 루프 시작
                                if UIAccessibility.isReduceMotionEnabled {
                                    self.showD1StaticGuide()
                                } else {
                                    self.d1SwipeLoopActive = true
                                    self.startD1SwipeLoop()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// Step 3→4: rect→pill + 스냅샷 제거
    private func transitionToD1Step4() {
        CoachMarkManager.shared.isD1SequenceActive = true
        // 스와이프 루프 중단 (shouldStopAnimation 대신 전용 플래그)
        d1SwipeLoopActive = false

        // 텍스트+버튼+스냅샷+녹색딤드+finger 페이드아웃
        UIView.animate(withDuration: 0.25, animations: {
            self.messageLabel.alpha = 0
            self.confirmButton.alpha = 0
            self.d1SnapshotView?.alpha = 0
            self.fingerView.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else {
                CoachMarkManager.shared.isD1SequenceActive = false
                return
            }
            // 스냅샷 제거
            self.d1SnapshotView?.removeFromSuperview()
            self.d1GreenView = nil
            self.fingerView.layer.removeAllAnimations()

            self.animateD1Expand { [weak self] in
                guard let self, !self.shouldStopAnimation else {
                    CoachMarkManager.shared.isD1SequenceActive = false
                    return
                }
                let targetFrame = self.d1StepFrames[3]
                self.highlightFrame = targetFrame
                self.animateD1Shrink(to: targetFrame, shape: .pill) { [weak self] in
                    guard let self, !self.shouldStopAnimation else {
                        CoachMarkManager.shared.isD1SequenceActive = false
                        return
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                        guard let self, !self.shouldStopAnimation else {
                            CoachMarkManager.shared.isD1SequenceActive = false
                            return
                        }
                        self.buildD1Step4Content()
                        UIView.animate(withDuration: 0.3, animations: {
                            self.messageLabel.alpha = 1
                            self.confirmButton.alpha = 1
                        }) { _ in
                            self.d1CurrentStep = 4
                            CoachMarkManager.shared.isD1SequenceActive = false
                            self.confirmButton.isEnabled = true
                        }
                    }
                }
            }
        }
    }

    // MARK: - Focus Animations

    /// 현재 구멍을 화면 전체로 확대 (딤 사라짐)
    private func animateD1Expand(completion: @escaping () -> Void) {
        // 현재 dimLayer 구멍을 화면 전체 크기로 확대
        let currentPath = dimLayer.path ?? UIBezierPath(rect: bounds).cgPath

        let expandSize = max(bounds.width, bounds.height) * 3.0
        let expandRect = CGRect(
            x: bounds.midX - expandSize / 2,
            y: bounds.midY - expandSize / 2,
            width: expandSize,
            height: expandSize
        )
        let endPath = UIBezierPath(rect: bounds)
        endPath.append(UIBezierPath(roundedRect: expandRect, cornerRadius: expandRect.height / 2))

        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.dimLayer.path = endPath.cgPath
            self.dimLayer.removeAnimation(forKey: "d1Expand")
            completion()
        }
        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = currentPath
        anim.toValue = endPath.cgPath
        anim.duration = 0.3
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        dimLayer.add(anim, forKey: "d1Expand")
        CATransaction.commit()
    }

    /// 화면 전체 구멍 → 타겟 크기로 축소
    private func animateD1Shrink(to targetFrame: CGRect, shape: D1FocusShape, completion: @escaping () -> Void) {
        // 시작: 화면 전체 크기 구멍 (타겟 중심)
        let expandSize = max(bounds.width, bounds.height) * 3.0

        let startRect: CGRect
        let startRadius: CGFloat
        let endRect: CGRect
        let endRadius: CGFloat

        switch shape {
        case .pill:
            let margin: CGFloat = 8
            let holeRect = targetFrame.insetBy(dx: -margin, dy: -margin)
            endRect = holeRect
            endRadius = holeRect.height / 2
            // 시작 pill (비율 유지 확대)
            let scale = expandSize / max(holeRect.width, holeRect.height)
            let sw = holeRect.width * scale
            let sh = holeRect.height * scale
            startRect = CGRect(x: holeRect.midX - sw / 2, y: holeRect.midY - sh / 2, width: sw, height: sh)
            startRadius = startRect.height / 2
        case .rect:
            endRect = targetFrame
            endRadius = 0
            let scale = expandSize / max(targetFrame.width, targetFrame.height)
            let sw = targetFrame.width * scale
            let sh = targetFrame.height * scale
            startRect = CGRect(x: targetFrame.midX - sw / 2, y: targetFrame.midY - sh / 2, width: sw, height: sh)
            startRadius = 0
        }

        let startPath = UIBezierPath(rect: bounds)
        startPath.append(UIBezierPath(roundedRect: startRect, cornerRadius: startRadius))
        let endPath = UIBezierPath(rect: bounds)
        endPath.append(UIBezierPath(roundedRect: endRect, cornerRadius: endRadius))

        dimLayer.path = startPath.cgPath

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.dimLayer.path = endPath.cgPath
            self?.dimLayer.removeAnimation(forKey: "d1Shrink")
            completion()
        }
        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = startPath.cgPath
        anim.toValue = endPath.cgPath
        anim.duration = 0.7
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        dimLayer.add(anim, forKey: "d1Shrink")
        CATransaction.commit()
    }

    // MARK: - Step 2 Fake Button

    /// secondaryStack 미표시 시 임시 더보기 버튼 생성
    private func buildD1FakeExpandButton(frame: CGRect) -> UIView {
        let fakeButton = UIView(frame: frame)
        fakeButton.layer.cornerRadius = frame.height / 2
        fakeButton.clipsToBounds = true

        // blur 배경 (GlassTextButton 유사)
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blur.frame = fakeButton.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        fakeButton.addSubview(blur)

        let label = UILabel()
        label.text = String(localized: "coachMark.d1.step2.fakeButton")
        label.textColor = .white
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        fakeButton.addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: fakeButton.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: fakeButton.centerYAnchor),
        ])
        return fakeButton
    }

    // MARK: - Step 3 Swipe Motion

    /// 스와이프 시연 루프 시작 (d1SwipeLoopActive 체크)
    private func startD1SwipeLoop() {
        guard d1SwipeLoopActive else { return }
        performD1DeleteSwipe()
    }

    /// D-1 삭제 스와이프 (→ 오른쪽) — 녹색 딤드 채움
    private func performD1DeleteSwipe() {
        guard d1SwipeLoopActive else { return }
        let cellFrame = d1StepFrames[2]

        // 손가락 초기 위치 (셀 좌측 중앙)
        fingerView.sizeToFit()
        fingerView.center = CGPoint(x: cellFrame.minX, y: cellFrame.midY)
        fingerView.alpha = 0
        fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        fingerView.layer.shadowOpacity = 0
        bringSubviewToFront(fingerView)

        // 1) Touch Down (0.3초)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.fingerView.alpha = 1.0
            self.fingerView.transform = .identity
            self.fingerView.layer.shadowOpacity = 0.3
            self.fingerView.layer.shadowRadius = 8
        }) { [weak self] _ in
            guard let self, self.d1SwipeLoopActive else { return }

            // 2) Press (0.2초, spring)
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0, options: [], animations: {
                self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.fingerView.layer.shadowRadius = 4
                self.fingerView.layer.shadowOpacity = 0.2
            }) { [weak self] _ in
                guard let self, self.d1SwipeLoopActive else { return }

                // 3) Drag → (0.3초)
                let timing = UICubicTimingParameters(
                    controlPoint1: CGPoint(x: 0.4, y: 0.0),
                    controlPoint2: CGPoint(x: 0.2, y: 1.0)
                )
                let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: timing)
                animator.addAnimations {
                    self.fingerView.center.x += self.d1SwipeDistance
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                        .rotated(by: .pi / 24)
                    self.d1GreenView?.frame.size.width = self.d1SwipeDistance
                }
                animator.addCompletion { [weak self] _ in
                    guard let self, self.d1SwipeLoopActive else { return }

                    // 4) Release — 손가락만 페이드아웃
                    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                        self.fingerView.alpha = 0
                        self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                        self.fingerView.center.y -= 10
                    }) { [weak self] _ in
                        guard let self, self.d1SwipeLoopActive else { return }
                        // 텀 (0.5초) → 복원
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            self?.performD1RestoreSwipe()
                        }
                    }
                }
                animator.startAnimation()
            }
        }
    }

    /// D-1 복원 스와이프 (← 왼쪽) — 녹색 딤드 축소
    private func performD1RestoreSwipe() {
        guard d1SwipeLoopActive else { return }
        let cellFrame = d1StepFrames[2]

        // 손가락을 오른쪽 끝에 배치
        fingerView.center = CGPoint(x: cellFrame.minX + d1SwipeDistance, y: cellFrame.midY)
        fingerView.alpha = 0
        fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        fingerView.layer.shadowOpacity = 0

        // 1) Touch Down (0.3초)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.fingerView.alpha = 1.0
            self.fingerView.transform = .identity
            self.fingerView.layer.shadowOpacity = 0.3
            self.fingerView.layer.shadowRadius = 8
        }) { [weak self] _ in
            guard let self, self.d1SwipeLoopActive else { return }

            // 2) Press (0.2초, spring)
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0, options: [], animations: {
                self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.fingerView.layer.shadowRadius = 4
                self.fingerView.layer.shadowOpacity = 0.2
            }) { [weak self] _ in
                guard let self, self.d1SwipeLoopActive else { return }

                // 3) Drag ← (0.3초)
                let timing = UICubicTimingParameters(
                    controlPoint1: CGPoint(x: 0.4, y: 0.0),
                    controlPoint2: CGPoint(x: 0.2, y: 1.0)
                )
                let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: timing)
                animator.addAnimations {
                    self.fingerView.center.x -= self.d1SwipeDistance
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                        .rotated(by: -.pi / 24)
                    self.d1GreenView?.frame.size.width = 0
                }
                animator.addCompletion { [weak self] _ in
                    guard let self, self.d1SwipeLoopActive else { return }

                    // 4) Release
                    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                        self.fingerView.alpha = 0
                        self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                        self.fingerView.center.y -= 10
                    }) { [weak self] _ in
                        guard let self, self.d1SwipeLoopActive else { return }
                        // 텀 (0.5초) → 리셋 → 반복
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self, self.d1SwipeLoopActive else { return }
                            self.fingerView.center = CGPoint(x: cellFrame.minX, y: cellFrame.midY)
                            self.startD1SwipeLoop()
                        }
                    }
                }
                animator.startAnimation()
            }
        }
    }

    /// Reduce Motion: 녹색 딤드 55% + 화살표 (정적)
    private func showD1StaticGuide() {
        let cellFrame = d1StepFrames[2]
        d1GreenView?.frame.size.width = d1SwipeDistance * 0.55

        fingerView.sizeToFit()
        fingerView.center = CGPoint(x: cellFrame.minX + d1SwipeDistance * 0.55, y: cellFrame.midY)
        fingerView.alpha = 1
        fingerView.transform = .identity
        bringSubviewToFront(fingerView)

        arrowView.center = CGPoint(x: cellFrame.midX, y: cellFrame.maxY - 12)
        arrowView.alpha = 0.8
        addSubview(arrowView)
    }

    // MARK: - Cleanup

    /// D-1 전용 리소스 정리 (dismiss 시 호출)
    func cleanupD1() {
        guard coachMarkType == .autoCleanupPreview else { return }

        d1SwipeLoopActive = false
        d1SnapshotView?.removeFromSuperview()
        d1SnapshotView = nil
        d1GreenView = nil
        d1FakeExpandButton?.removeFromSuperview()
        d1FakeExpandButton = nil
        fingerView.layer.removeAllAnimations()
        dimLayer.removeAnimation(forKey: "d1Expand")
        dimLayer.removeAnimation(forKey: "d1Shrink")
    }
}

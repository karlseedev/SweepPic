//
//  CoachMarkOverlayView+CoachMarkC3.swift
//  SweepPic
//
//  Created by Claude Code on 2026-02-25.
//
//  코치마크 C-3: 얼굴 비교 화면 선택 안내
//  - Step 1: 첫 번째 셀 하이라이트 → 탭 모션 → 실제 선택 → 안내 텍스트
//  - Step 2: Pic 라벨 포커스 → 번호 의미 안내
//  - Reduce Motion: 탭 모션/포커스 애니메이션 생략
//
//  플로우:
//    showFaceComparisonGuide() → 탭 모션 → 셀 선택 → [확인]
//    → startC3ConfirmSequence() → 선택 해제 → 포커스 전환 → [확인] → dismiss
//

import UIKit
import ObjectiveC

// MARK: - Associated Object Keys

private var c3StepKey: UInt8 = 0
private var c3DeselectActionKey: UInt8 = 0
private var c3PicLabelFrameKey: UInt8 = 0

// MARK: - Coach Mark C-3: Face Comparison Guide

extension CoachMarkOverlayView {

    // MARK: - Associated Properties

    /// 현재 C-3 스텝 (1 or 2)
    var c3Step: Int {
        get { objc_getAssociatedObject(self, &c3StepKey) as? Int ?? 1 }
        set { objc_setAssociatedObject(self, &c3StepKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 셀 선택 해제 클로저 (Step 1→2 전환 시 사용)
    var c3DeselectAction: (() -> Void)? {
        get { objc_getAssociatedObject(self, &c3DeselectActionKey) as? (() -> Void) }
        set { objc_setAssociatedObject(self, &c3DeselectActionKey, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC) }
    }

    /// Pic 라벨 frame (Step 2 포커스 대상, window 좌표)
    var c3PicLabelFrame: CGRect? {
        get { objc_getAssociatedObject(self, &c3PicLabelFrameKey) as? CGRect }
        set { objc_setAssociatedObject(self, &c3PicLabelFrameKey, newValue as NSValue?, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Entry Point

    /// C-3: 얼굴 비교 화면 선택 안내 오버레이 표시
    /// - Parameters:
    ///   - window: 표시할 윈도우
    ///   - cellFrame: 첫 번째 셀 프레임 (window 좌표)
    ///   - picLabelFrame: Pic 라벨 프레임 (window 좌표)
    ///   - onSelect: 셀 선택 실행 클로저
    ///   - onDeselect: 셀 선택 해제 클로저
    static func showFaceComparisonGuide(
        in window: UIWindow,
        cellFrame: CGRect,
        picLabelFrame: CGRect,
        onSelect: @escaping () -> Void,
        onDeselect: @escaping () -> Void
    ) {
        // 버그 #3 대응: 기존 C-1/C-2 오버레이가 남아있으면 제거
        // FaceComparison present 시 새 C-3 오버레이를 생성하므로
        // 이전 오버레이를 명시적으로 제거해야 그리드 복귀 시 잔존 방지
        if let existing = CoachMarkManager.shared.currentOverlay {
            existing.shouldStopAnimation = true
            existing.removeFromSuperview()
            CoachMarkManager.shared.currentOverlay = nil
        }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .faceComparisonGuide
        overlay.highlightFrame = cellFrame
        overlay.c3Step = 1
        overlay.c3PicLabelFrame = picLabelFrame
        overlay.c3DeselectAction = onDeselect
        overlay.alpha = 0.01  // hitTest로 터치 차단 즉시 시작

        // 윈도우에 추가
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // dim 배경 + evenOdd 구멍 (정사각형)
        overlay.updateDimPath()

        // 손가락 아이콘 준비 (초기 비표시)
        overlay.fingerView.sizeToFit()
        overlay.fingerView.alpha = 0
        overlay.addSubview(overlay.fingerView)

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        } completion: { _ in
            guard !overlay.shouldStopAnimation else { return }

            if UIAccessibility.isReduceMotionEnabled {
                // Reduce Motion: 탭 모션 생략, 즉시 선택 + 텍스트 표시
                onSelect()
                overlay.showC3Step1Content()
            } else {
                // 탭 모션 → 선택 → 텍스트
                let targetCenter = CGPoint(x: cellFrame.midX, y: cellFrame.midY)
                overlay.performC3TapMotion(at: targetCenter) {
                    guard !overlay.shouldStopAnimation else { return }
                    onSelect()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        guard !overlay.shouldStopAnimation else { return }
                        overlay.showC3Step1Content()
                    }
                }
            }
        }
    }

    // MARK: - Step 1 Content

    /// Step 1 안내 텍스트 + 확인 버튼 표시
    private func showC3Step1Content() {
        // 안내 텍스트 (하이라이트 셀 아래, 행간 1.2배)
        // \n = 단락 구분 (paragraphSpacing 적용), \u{2028} = 같은 단락 내 줄바꿈
        let mainText = String(localized: "coachMark.c3.step1.body")
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = CoachMarkOverlayView.bodyFont.pointSize * 0.2
        style.paragraphSpacing = 12
        let attr = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: CoachMarkOverlayView.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )
        // "얼굴을 선택" 키워드 강조 (fallback: range 미발견 시 무시)
        if let range = mainText.range(of: String(localized: "coachMark.c3.step1.keyword")) {
            let nsRange = NSRange(range, in: mainText)
            attr.addAttributes([
                .font: CoachMarkOverlayView.bodyBoldFont,
                .foregroundColor: CoachMarkOverlayView.highlightYellow
            ], range: nsRange)
        }

        messageLabel.attributedText = attr
        messageLabel.numberOfLines = 0
        messageLabel.alpha = 0
        let labelWidth = bounds.width - 40
        let labelSize = messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
        messageLabel.frame = CGRect(
            x: 20,
            y: highlightFrame.maxY + 24,
            width: labelWidth,
            height: ceil(labelSize.height)
        )
        addSubview(messageLabel)

        // 확인 버튼 (흰색 라운드)
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
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

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            self.messageLabel.alpha = 1
            self.confirmButton.alpha = 1
        }
    }

    // MARK: - Confirm Sequence

    /// C-3 [확인] 탭 후 시퀀스
    /// Step 1: 텍스트 페이드아웃 → 선택 해제 → 포커스 전환 → Step 2 표시
    /// Step 2: dismiss + markAsShown
    func startC3ConfirmSequence() {
        if c3Step == 1 {
            CoachMarkManager.shared.isC3TransitionActive = true

            // 1. 텍스트+버튼 페이드아웃 + overlay 투명화 (0.2s)
            UIView.animate(withDuration: 0.2, animations: {
                self.messageLabel.alpha = 0
                self.confirmButton.alpha = 0
                self.alpha = 0.01  // 터치 차단 유지
            }) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else {
                    CoachMarkManager.shared.isC3TransitionActive = false
                    return
                }

                // 2. 셀 선택 해제
                self.c3DeselectAction?()

                // 3. dimLayer를 Pic 라벨 중심 큰 원으로 즉시 교체
                guard let picFrame = self.c3PicLabelFrame else {
                    CoachMarkManager.shared.isC3TransitionActive = false
                    self.dismiss()
                    return
                }

                let startDiameter = max(self.bounds.width, self.bounds.height) * 3.0
                let startRect = CGRect(
                    x: picFrame.midX - startDiameter / 2,
                    y: picFrame.midY - startDiameter / 2,
                    width: startDiameter, height: startDiameter
                )
                let startPath = UIBezierPath(rect: self.bounds)
                startPath.append(UIBezierPath(ovalIn: startRect))
                self.dimLayer.path = startPath.cgPath

                // 4. alpha 복원 + 포커스 원 축소 (Reduce Motion 분기)
                if UIAccessibility.isReduceMotionEnabled {
                    self.updateC3DimPathCircle(for: picFrame, scale: 1.2)
                    self.alpha = 1.0
                    self.c3Step = 2
                    CoachMarkManager.shared.isC3TransitionActive = false
                    self.showC3Step2Content(picFrame: picFrame)
                } else {
                    UIView.animate(withDuration: 0.3) {
                        self.alpha = 1.0
                    }
                    self.animateC3FocusCircle(to: picFrame) { [weak self] in
                        guard let self, !self.shouldStopAnimation else {
                            CoachMarkManager.shared.isC3TransitionActive = false
                            return
                        }
                        CoachMarkManager.shared.isC3TransitionActive = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                            guard let self, !self.shouldStopAnimation else { return }
                            self.showC3Step2Content(picFrame: picFrame)
                        }
                    }
                }
                self.c3Step = 2
            }
        } else {
            // Step 2 [확인] → auto pop 플래그 설정 + dismiss
            CoachMarkManager.shared.isC3TransitionActive = false
            CoachMarkManager.shared.isAutoPopForC = true
            CoachMarkManager.shared.pendingCleanupHighlight = true
            dismiss()
        }
    }

    // MARK: - Step 2 Content

    /// Step 2 안내 텍스트 + 확인 버튼 표시 (포커스 원 아래에 배치)
    private func showC3Step2Content(picFrame: CGRect) {
        // 포커스 원 하단 계산
        let focusDiameter = max(picFrame.width, picFrame.height) * 1.2
        let circleBottom = picFrame.midY + focusDiameter / 2

        // 안내 텍스트 (\n = 단락 구분 → paragraphSpacing 적용, \u{2028} = 같은 단락 내 줄바꿈)
        let mainText = String(localized: "coachMark.c3.step2.body")
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineSpacing = CoachMarkOverlayView.bodyFont.pointSize * 0.2
        style.paragraphSpacing = 12
        let attr = NSMutableAttributedString(
            string: mainText,
            attributes: [
                .font: CoachMarkOverlayView.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: style
            ]
        )
        // "사진 구별 번호" 키워드 강조 (fallback: range 미발견 시 무시)
        if let range = mainText.range(of: String(localized: "coachMark.c3.step2.keyword")) {
            let nsRange = NSRange(range, in: mainText)
            attr.addAttributes([
                .font: CoachMarkOverlayView.bodyBoldFont,
                .foregroundColor: CoachMarkOverlayView.highlightYellow
            ], range: nsRange)
        }

        messageLabel.attributedText = attr
        messageLabel.numberOfLines = 0
        messageLabel.alpha = 0
        // 텍스트 높이 자동 계산 (3줄 + paragraphSpacing)
        let labelWidth = bounds.width - 40
        let labelSize = messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
        messageLabel.frame = CGRect(
            x: 20,
            y: circleBottom + 24,
            width: labelWidth,
            height: ceil(labelSize.height)
        )

        // 확인 버튼
        confirmButton.isEnabled = true
        confirmButton.alpha = 0
        let buttonWidth: CGFloat = 120
        confirmButton.frame = CGRect(
            x: (bounds.width - buttonWidth) / 2,
            y: messageLabel.frame.maxY + 16,
            width: buttonWidth,
            height: 44
        )

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            self.messageLabel.alpha = 1
            self.confirmButton.alpha = 1
        }
    }

    // MARK: - Tap Motion (C-3 자체 구현)

    /// C-3 전용 탭 모션 (performCTapMotion과 동일 로직)
    /// +CoachMarkC.swift의 performCTapMotion이 private이므로 별도 구현
    /// D의 performDTapMotion 별도 구현과 동일한 패턴
    /// - Parameters:
    ///   - targetCenter: 탭 대상 중앙점 (overlay 좌표 = window 좌표)
    ///   - completion: 모션 완료 후 콜백
    private func performC3TapMotion(at targetCenter: CGPoint, completion: @escaping () -> Void) {
        // hand.point.up.fill 손가락 끝 보정
        let fingerWidth = fingerView.bounds.width
        let fingerHeight = fingerView.bounds.height
        let initialCenter = CGPoint(
            x: targetCenter.x + fingerWidth * 0.08,
            y: targetCenter.y + fingerHeight * 0.4
        )
        fingerView.center = initialCenter
        fingerView.alpha = 0
        fingerView.transform = .identity
        // 초기 그림자 (떠있는 상태)
        fingerView.layer.shadowRadius = 6
        fingerView.layer.shadowOffset = CGSize(width: 0, height: 2)
        fingerView.layer.shadowOpacity = 0.3

        // Phase 1: 등장 (0.15s)
        UIView.animate(
            withDuration: 0.15,
            delay: 0,
            options: .curveEaseOut,
            animations: {
                self.fingerView.alpha = 1
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { completion(); return }

            // 눌림 피드백
            self.showC3TapPressFeedback()

            // Phase 2: 누르기 (0.12s, spring)
            UIView.animate(
                withDuration: 0.12,
                delay: 0,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
                    self.fingerView.center.y = initialCenter.y + 2.5
                    self.fingerView.layer.shadowRadius = 2
                    self.fingerView.layer.shadowOffset = CGSize(width: 0, height: 1)
                    self.fingerView.layer.shadowOpacity = 0.15
                }
            ) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { completion(); return }

                // Phase 3: 떼기 (0.2s, 0.05s 유지 후 spring)
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0.05,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 2.0,
                    options: [],
                    animations: {
                        self.fingerView.transform = .identity
                        self.fingerView.center = initialCenter
                        self.fingerView.alpha = 0
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

    // MARK: - Press Feedback (C-3 자체 구현)

    /// C-3 전용 눌림 피드백 (showCTapPressFeedback과 동일 로직)
    /// 1. 스냅샷 scale 0.93 축소 → 복원 + 페이드아웃
    /// 2. 흰색 플래시 (alpha 0→1→0)
    private func showC3TapPressFeedback() {
        let holeRect = highlightFrame

        // 1. 스냅샷 축소 효과
        if let window = superview,
           let snapshot = window.resizableSnapshotView(
               from: highlightFrame,
               afterScreenUpdates: false,
               withCapInsets: .zero
           ) {
            snapshot.frame = highlightFrame
            insertSubview(snapshot, belowSubview: fingerView)

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

        // 2. 흰색 플래시
        let flashView = UIView(frame: holeRect)
        flashView.backgroundColor = UIColor.white.withAlphaComponent(0.3)
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

    // MARK: - Focus Circle Animation (C-3 자체 구현)

    /// Pic 라벨 중심으로 포커스 원 축소 애니메이션
    /// 시작: 3× 화면 크기 원 (큰 구멍 = 딤 거의 없음)
    /// 끝: Pic 라벨 × 1.2배 원 (작은 구멍 = Pic 라벨만 투명)
    /// - Parameters:
    ///   - targetFrame: Pic 라벨 프레임 (window 좌표)
    ///   - completion: 완료 콜백
    private func animateC3FocusCircle(to targetFrame: CGRect, completion: @escaping () -> Void) {
        let scale: CGFloat = 1.2
        // 최종 원 (Pic 라벨 × 1.2배)
        let finalDiameter = max(targetFrame.width, targetFrame.height) * scale
        let finalCircleRect = CGRect(
            x: targetFrame.midX - finalDiameter / 2,
            y: targetFrame.midY - finalDiameter / 2,
            width: finalDiameter,
            height: finalDiameter
        )

        // 시작 원 (3× 화면 = 딤 거의 없음, transitionToC2에서 이미 설정됨)
        let startDiameter = max(bounds.width, bounds.height) * 3.0
        let startCircleRect = CGRect(
            x: targetFrame.midX - startDiameter / 2,
            y: targetFrame.midY - startDiameter / 2,
            width: startDiameter,
            height: startDiameter
        )

        // 경로 생성
        let startPath = UIBezierPath(rect: bounds)
        startPath.append(UIBezierPath(ovalIn: startCircleRect))

        let endPath = UIBezierPath(rect: bounds)
        endPath.append(UIBezierPath(ovalIn: finalCircleRect))

        // CABasicAnimation으로 원→원 path 보간 (부드러움)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.dimLayer.path = endPath.cgPath
            self.dimLayer.removeAnimation(forKey: "c3FocusCircle")
            completion()
        }

        dimLayer.path = startPath.cgPath
        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = startPath.cgPath
        anim.toValue = endPath.cgPath
        anim.duration = 0.7  // C-2(0.9s)보다 짧음 — 거리가 짧으므로
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        dimLayer.add(anim, forKey: "c3FocusCircle")

        CATransaction.commit()
    }

    // MARK: - Dim Path Circle (C-3 자체 구현)

    /// C-3용 원형 dim 구멍 설정
    /// - Parameters:
    ///   - frame: 타겟 프레임 (window 좌표)
    ///   - scale: 구멍 크기 배율
    private func updateC3DimPathCircle(for frame: CGRect, scale: CGFloat) {
        let fullPath = UIBezierPath(rect: bounds)
        let diameter = max(frame.width, frame.height) * scale
        let circleRect = CGRect(
            x: frame.midX - diameter / 2,
            y: frame.midY - diameter / 2,
            width: diameter,
            height: diameter
        )
        fullPath.append(UIBezierPath(ovalIn: circleRect))
        dimLayer.path = fullPath.cgPath
    }

    // MARK: - Cleanup

    /// C-3 전용 리소스 정리 (dismiss에서 호출)
    func cleanupFaceComparisonGuide() {
        guard coachMarkType == .faceComparisonGuide else { return }
        // associated objects 정리
        c3DeselectAction = nil
        c3PicLabelFrame = nil
        // 전환 플래그 리셋
        CoachMarkManager.shared.isC3TransitionActive = false
    }
}

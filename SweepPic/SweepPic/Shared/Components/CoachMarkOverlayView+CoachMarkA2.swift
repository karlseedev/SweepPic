//
//  CoachMarkOverlayView+CoachMarkA2.swift
//  SweepPic
//
//  Created by Claude Code on 2026-03-09.
//
//  코치마크 A Step 2: 멀티스와이프 삭제 데모
//  - Step 1 → Step 2 전환 애니메이션 (transitionToA2)
//  - 가로 3셀 → 세로 2행 확장 데모 루프 (startMultiSwipeLoop)
//  - 카운터 뱃지 (빨간 원형, bounce)
//  - 하이라이트 확장/수축 (animateHighlightExpansion)
//  - Reduce Motion 대응 (showA2StaticGuide)
//  - cleanupA2() — dismiss 시 리소스 정리
//
//  플로우:
//    Step 1 "다음 →" → transitionToA2() → startMultiSwipeLoop() → "확인" → dismiss
//

import UIKit
import ObjectiveC
import OSLog
import AppCore

// MARK: - Associated Object Keys

private var aCurrentStepKey: UInt8 = 0
private var aCounterBadgeKey: UInt8 = 0
private var aMultiSnapshotsKey: UInt8 = 0
private var aMultiMaroonViewsKey: UInt8 = 0
private var aMultiCellFramesKey: UInt8 = 0
private var aAll9CellFramesKey: UInt8 = 0

// MARK: - Coach Mark A-2: Multi Swipe Demo

extension CoachMarkOverlayView {

    // MARK: - Associated Properties

    /// 현재 A 스텝 (0=레거시/Replay, 1=Step 1, 2=Step 2)
    var aCurrentStep: Int {
        get { objc_getAssociatedObject(self, &aCurrentStepKey) as? Int ?? 0 }
        set { objc_setAssociatedObject(self, &aCurrentStepKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 빨간 원형 카운터 뱃지
    var aCounterBadge: UILabel? {
        get { objc_getAssociatedObject(self, &aCounterBadgeKey) as? UILabel }
        set { objc_setAssociatedObject(self, &aCounterBadgeKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 9셀 스냅샷 뷰 배열 (인덱스: [0~2]=Row0, [3~5]=Row1, [6~8]=Row2)
    var aMultiSnapshots: [UIView]? {
        get { objc_getAssociatedObject(self, &aMultiSnapshotsKey) as? [UIView] }
        set { objc_setAssociatedObject(self, &aMultiSnapshotsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 9셀 개별 maroon 딤드 뷰 배열
    var aMultiMaroonViews: [UIView]? {
        get { objc_getAssociatedObject(self, &aMultiMaroonViewsKey) as? [UIView] }
        set { objc_setAssociatedObject(self, &aMultiMaroonViewsKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 같은 행(앵커행) 3셀 윈도우 프레임
    var aMultiCellFrames: [CGRect]? {
        get {
            guard let values = objc_getAssociatedObject(self, &aMultiCellFramesKey) as? [NSValue] else { return nil }
            return values.map { $0.cgRectValue }
        }
        set {
            let values = newValue?.map { NSValue(cgRect: $0) }
            objc_setAssociatedObject(self, &aMultiCellFramesKey, values, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// 전체 9셀 윈도우 프레임
    var aAll9CellFrames: [CGRect]? {
        get {
            guard let values = objc_getAssociatedObject(self, &aAll9CellFramesKey) as? [NSValue] else { return nil }
            return values.map { $0.cgRectValue }
        }
        set {
            let values = newValue?.map { NSValue(cgRect: $0) }
            objc_setAssociatedObject(self, &aAll9CellFramesKey, values, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    // MARK: - Constants

    /// 카운터 뱃지 크기
    private static let badgeSize: CGFloat = 28
    /// 카운터 뱃지 2자리 너비
    private static let badgeWideWidth: CGFloat = 34

    // MARK: - Step 1 → Step 2 Transition

    /// Step 1 → Step 2 전환 애니메이션
    /// confirmTapped()에서 aCurrentStep==1일 때 호출
    func transitionToA2() {
        guard let multiCellFrames = aMultiCellFrames,
              multiCellFrames.count == 3,
              let all9Frames = aAll9CellFrames,
              all9Frames.count == 9,
              let multiSnapshots = aMultiSnapshots,
              multiSnapshots.count == 9
        else {
            Logger.coachMark.error("A2 전환 실패: 데이터 부족")
            dismiss()
            return
        }

        // Step 1 루프 정지 + dismiss 차단
        shouldStopAnimation = true
        CoachMarkManager.shared.isA2TransitionActive = true

        // 앵커행 3셀 합산 rect
        let row3UnionRect = multiCellFrames[0]
            .union(multiCellFrames[1])
            .union(multiCellFrames[2])

        // 9셀 합산 rect
        let all9UnionRect = all9Frames[0...8].reduce(CGRect.null) { $0.union($1) }

        // t=0.00~0.25: Step 1 요소 페이드아웃
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.snapshotView?.alpha = 0
            self?.fingerView.alpha = 0
            self?.maroonView.alpha = 0
        }

        // t=0.25: 타이틀 크로스페이드 + 위치를 9셀 영역 위로 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.shouldStopAnimation || CoachMarkManager.shared.isA2TransitionActive else { return }
            UIView.transition(with: self.titleLabel, duration: 0.3, options: .transitionCrossDissolve) {
                self.titleLabel.text = String(localized: "coachMark.a2.title")
                // 텍스트 변경 후 프레임 재계산 (좌우 패딩 맞춤)
                self.titleLabel.sizeToFit()
                let padding = UIEdgeInsets(top: 8, left: 20, bottom: 8, right: 20)
                let newWidth = self.titleLabel.bounds.width + padding.left + padding.right
                let newHeight = self.titleLabel.bounds.height + padding.top + padding.bottom
                self.titleLabel.frame = CGRect(
                    x: (self.bounds.width - newWidth) / 2,
                    y: all9UnionRect.minY - newHeight - 10,
                    width: newWidth,
                    height: newHeight
                )
                self.titleLabel.layer.cornerRadius = newHeight / 2
            }
        }

        // t=0.25: 하이라이트 확장 (1셀 → 9셀 전체)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.animateHighlightExpansion(to: all9UnionRect, duration: 0.4)
        }

        // t=0.30: 9셀 전체 스냅샷 배치 + 페이드인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self else { return }
            var maroonViews: [UIView] = []
            for i in 0...8 {
                let snap = multiSnapshots[i]
                snap.frame = all9Frames[i]
                snap.alpha = 0
                self.addSubview(snap)

                // maroon 딤드 뷰 (초기 width=0)
                let mv = UIView()
                mv.backgroundColor = Self.maroonColor
                mv.alpha = Self.maroonAlpha
                mv.frame = CGRect(x: 0, y: 0, width: 0, height: all9Frames[i].height)
                snap.addSubview(mv)
                maroonViews.append(mv)
            }
            self.aMultiMaroonViews = maroonViews

            // 텍스트/버튼/손가락이 스냅샷에 가려지지 않도록 맨 앞으로
            self.bringSubviewToFront(self.titleLabel)
            self.bringSubviewToFront(self.messageLabel)
            self.bringSubviewToFront(self.confirmButton)
            self.bringSubviewToFront(self.fingerView)

            // Row 2(6-8)만 페이드인, Row 0/1은 Phase B에서 페이드인
            UIView.animate(withDuration: 0.3) {
                for i in 6...8 { multiSnapshots[i].alpha = 1 }
            }
        }

        // t=0.55: 메시지 텍스트 교체 + 위치를 Row 2 아래로 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            let fullText = String(localized: "coachMark.a2.body")
            let keywords = [
                String(localized: "coachMark.a2.keyword.multiple"),
                String(localized: "coachMark.a2.keyword.atOnce"),
            ]
            let style = NSMutableParagraphStyle()
            style.alignment = .center
            style.paragraphSpacing = 8
            let attr = NSMutableAttributedString(
                string: fullText,
                attributes: [
                    .font: Self.bodyFont,
                    .foregroundColor: UIColor.white,
                    .paragraphStyle: style
                ]
            )
            // 키워드 강조 (fallback: range 미발견 시 무시)
            for keyword in keywords {
                if let range = fullText.range(of: keyword) {
                    attr.addAttributes([
                        .font: Self.bodyBoldFont,
                        .foregroundColor: Self.highlightYellow
                    ], range: NSRange(range, in: fullText))
                }
            }
            // 메시지를 3셀(Row 2) 아래로 재배치 (동적 높이)
            let labelWidth = self.bounds.width - 40
            let labelSize = self.messageLabel.sizeThatFits(CGSize(width: labelWidth, height: .greatestFiniteMagnitude))
            self.messageLabel.frame = CGRect(
                x: 20,
                y: row3UnionRect.maxY,
                width: labelWidth,
                height: ceil(labelSize.height)
            )
            self.messageLabel.alpha = 0
            self.messageLabel.attributedText = attr
            UIView.animate(withDuration: 0.25) {
                self.messageLabel.alpha = 1
            }
        }

        // t=0.65: 버튼 위치를 메시지 아래로 재배치 + 활성화
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self else { return }
            // 버튼을 메시지 아래로 재배치
            let buttonWidth: CGFloat = 120
            self.confirmButton.frame = CGRect(
                x: (self.bounds.width - buttonWidth) / 2,
                y: self.messageLabel.frame.maxY - 5,
                width: buttonWidth,
                height: self.confirmButton.frame.height
            )
            self.confirmButton.isEnabled = true
        }

        // t=0.80: 멀티 데모 시작
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) { [weak self] in
            guard let self else { return }
            self.aCurrentStep = 2
            self.shouldStopAnimation = false
            CoachMarkManager.shared.isA2TransitionActive = false

            if UIAccessibility.isReduceMotionEnabled {
                self.showA2StaticGuide()
            } else {
                self.startMultiSwipeLoop()
            }
        }
    }

    // MARK: - Multi Swipe Demo Loop

    /// 멀티스와이프 데모 무한 루프
    /// Phase A (가로 순차 채움) → Phase B (세로 확장) → 복원 → 루프 반복
    func startMultiSwipeLoop() {
        guard !shouldStopAnimation else { return }
        guard let all9Frames = aAll9CellFrames, all9Frames.count == 9,
              let multiSnapshots = aMultiSnapshots, multiSnapshots.count == 9,
              let multiCellFrames = aMultiCellFrames, multiCellFrames.count == 3,
              let maroonViews = aMultiMaroonViews, maroonViews.count == 9
        else { return }

        // (하이라이트는 9셀 전체로 고정 — 확장/수축 없음)

        // ===== Phase A: 가로 순차 채움 (finger + maroon 동기화) =====

        // 0.00s: fingerView 등장 (셀[6] 좌측 — 스와이프 시작점)
        fingerView.center = CGPoint(
            x: all9Frames[6].minX,
            y: all9Frames[6].midY
        )
        fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut) { [weak self] in
            self?.fingerView.alpha = 1
            self?.fingerView.transform = .identity
        }

        // 0.30s: 누르기 효과
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0) {
                self.fingerView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
            }
        }

        // 0.50s: 셀[6] maroon + finger 동시 이동 (Step 1과 동일 패턴)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.25) {
                maroonViews[6].frame = CGRect(x: 0, y: 0, width: all9Frames[6].width, height: all9Frames[6].height)
                self.fingerView.center = CGPoint(x: all9Frames[6].maxX, y: all9Frames[6].midY)
            }
        }

        // 0.80s: 셀[7] maroon + finger 동시 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.80) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.25) {
                maroonViews[7].frame = CGRect(x: 0, y: 0, width: all9Frames[7].width, height: all9Frames[7].height)
                self.fingerView.center = CGPoint(x: all9Frames[7].maxX, y: all9Frames[7].midY)
            }
        }

        // 1.10s: 셀[8] maroon + finger 동시 이동
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.10) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.25) {
                maroonViews[8].frame = CGRect(x: 0, y: 0, width: all9Frames[8].width, height: all9Frames[8].height)
                self.fingerView.center = CGPoint(x: all9Frames[8].maxX, y: all9Frames[8].midY)
            }
        }

        // ===== Phase B: 세로 확장 (Phase A 후 0.5s 멈춤 → Row 1, Row 0 연속) =====

        // 1.85s: finger ↑ Row 1 (3열에서 위로) + 하이라이트 확장 3→6 + Row 1 통째로 빨간색
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.85) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }

            // finger 3열 유지하며 위로 이동 (tip이 Row 1 상단과 일치)
            let fingerHalfH = self.fingerView.bounds.height / 2
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.fingerView.center = CGPoint(
                    x: all9Frames[5].maxX,
                    y: all9Frames[3].minY + fingerHalfH
                )
            }

            // Row 1 maroon 전체 크기 + 스냅샷 페이드인 → "행 통째로 빨간색" 효과
            for i in 3...5 {
                maroonViews[i].frame = CGRect(x: 0, y: 0, width: all9Frames[i].width, height: all9Frames[i].height)
            }
            UIView.animate(withDuration: 0.25) {
                for i in 3...5 { multiSnapshots[i].alpha = 1 }
            }
        }

        // 2.15s: finger ↑ Row 0 (Row 1 직후 바로 연속) + 하이라이트 확장 6→9 + Row 0 통째로 빨간색
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.15) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }

            // finger 3열 유지하며 위로 이동 (tip이 Row 0 상단과 일치)
            let fingerHalfH = self.fingerView.bounds.height / 2
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.fingerView.center = CGPoint(
                    x: all9Frames[2].maxX,
                    y: all9Frames[0].minY + fingerHalfH
                )
            }

            // Row 0 maroon 전체 크기 + 스냅샷 페이드인 → "행 통째로 빨간색" 효과
            for i in 0...2 {
                maroonViews[i].frame = CGRect(x: 0, y: 0, width: all9Frames[i].width, height: all9Frames[i].height)
            }
            UIView.animate(withDuration: 0.25) {
                for i in 0...2 { multiSnapshots[i].alpha = 1 }
            }
        }

        // 2.70s: 릴리즈 (finger 원래 크기 + 페이드아웃)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.70) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
                self.fingerView.alpha = 0
                self.fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        }

        // ===== 복원 (즉시 초기화) =====

        // 3.40s: 전체 즉시 리셋 → 텀 → 루프 반복
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.40) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }

            // 전체 maroon 즉시 리셋 (width → 0, 애니메이션 없음)
            for i in 0...8 {
                maroonViews[i].frame.size.width = 0
            }

            // Row 0/Row 1 스냅샷 즉시 숨김 (다음 루프에서 다시 페이드인)
            for i in 0...5 {
                multiSnapshots[i].alpha = 0
            }
        }

        // 4.10s: 루프 반복 (0.7s 텀)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.10) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            self.startMultiSwipeLoop()
        }
    }

    // MARK: - Highlight Expansion Animation

    /// 하이라이트 구멍 확장/수축 애니메이션 (C-2 animateC2FocusCircle 패턴의 rect 버전)
    /// - Parameters:
    ///   - newFrame: 새 하이라이트 영역 (윈도우 좌표)
    ///   - duration: 애니메이션 시간
    func animateHighlightExpansion(to newFrame: CGRect, duration: TimeInterval = 0.3) {
        // 현재 구멍 → 새 구멍 path 생성
        let startPath = UIBezierPath(rect: bounds)
        startPath.append(UIBezierPath(rect: highlightFrame))

        let endPath = UIBezierPath(rect: bounds)
        endPath.append(UIBezierPath(rect: newFrame))

        // model layer 동기화 (C-2/D 패턴: 애니메이션 전 시작 상태 명시)
        dimLayer.path = startPath.cgPath

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.highlightFrame = newFrame
            self?.dimLayer.path = endPath.cgPath
            self?.dimLayer.removeAnimation(forKey: "highlightExpand")
        }

        let anim = CABasicAnimation(keyPath: "path")
        anim.fromValue = startPath.cgPath
        anim.toValue = endPath.cgPath
        anim.duration = duration
        anim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        anim.fillMode = .forwards
        anim.isRemovedOnCompletion = false
        dimLayer.add(anim, forKey: "highlightExpand")

        CATransaction.commit()
    }

    // MARK: - Counter Badge

    /// 카운터 뱃지 업데이트 (생성 or 값 변경 + bounce)
    /// - Parameters:
    ///   - count: 표시할 숫자 (0이면 페이드아웃)
    ///   - highlightRect: 현재 하이라이트 영역 (뱃지 위치 기준)
    private func updateCounterBadge(count: Int, highlightRect: CGRect) {
        // 0일 때 페이드아웃
        if count == 0 {
            UIView.animate(withDuration: 0.15) { [weak self] in
                self?.aCounterBadge?.alpha = 0
            }
            return
        }

        // 뱃지 생성 (최초 1회)
        if aCounterBadge == nil {
            let badge = UILabel()
            badge.textAlignment = .center
            badge.textColor = .white
            badge.font = .systemFont(ofSize: 14, weight: .bold)
            badge.backgroundColor = .systemRed
            badge.clipsToBounds = true
            badge.alpha = 0
            addSubview(badge)
            aCounterBadge = badge
        }

        guard let badge = aCounterBadge else { return }

        // 크기: 1자리 28pt, 2자리 34pt
        let isWide = count >= 10
        let badgeWidth = isWide ? Self.badgeWideWidth : Self.badgeSize
        let badgeHeight = Self.badgeSize

        // 위치: 하이라이트 우상단 외부
        badge.frame = CGRect(
            x: highlightRect.maxX + 4,
            y: highlightRect.minY - 4 - badgeHeight,
            width: badgeWidth,
            height: badgeHeight
        )
        badge.layer.cornerRadius = badgeHeight / 2
        badge.text = "\(count)"
        badge.alpha = 1

        // bounce 효과
        badge.transform = .identity
        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.5,
            options: []
        ) {
            badge.transform = CGAffineTransform(scaleX: 1.3, y: 1.3)
        } completion: { _ in
            UIView.animate(withDuration: 0.1) {
                badge.transform = .identity
            }
        }
    }

    // MARK: - Maroon Fill Helper

    /// 특정 셀의 maroon 딤드를 채움 (width 0 → 셀 너비)
    /// - Parameters:
    ///   - index: 9셀 배열 인덱스
    ///   - maroonViews: maroon 뷰 배열
    ///   - frames: 9셀 프레임 배열
    private func fillMaroon(at index: Int, in maroonViews: [UIView], frames: [CGRect]) {
        guard index < maroonViews.count, index < frames.count else { return }
        UIView.animate(withDuration: 0.25) {
            maroonViews[index].frame = CGRect(
                x: 0, y: 0,
                width: frames[index].width,
                height: frames[index].height
            )
        }
    }

    // MARK: - Reduce Motion

    /// Reduce Motion 시 정적 멀티스와이프 가이드
    /// - 3셀(Row 2) maroon 55% 채움
    /// - 손가락 셀[8] 우측 끝 정지
    /// - arrowView: arrow.right + arrow.up 표시
    private func showA2StaticGuide() {
        guard let all9Frames = aAll9CellFrames, all9Frames.count == 9,
              let multiCellFrames = aMultiCellFrames, multiCellFrames.count == 3,
              let maroonViews = aMultiMaroonViews, maroonViews.count == 9
        else { return }

        let row2UnionRect = multiCellFrames[0]
            .union(multiCellFrames[1])
            .union(multiCellFrames[2])

        // Row 2 maroon 채움 (정적)
        for i in 6...8 {
            maroonViews[i].frame = CGRect(
                x: 0, y: 0,
                width: all9Frames[i].width,
                height: all9Frames[i].height
            )
        }


        // 손가락 셀[8] 우측 끝 정지
        fingerView.center = CGPoint(
            x: all9Frames[8].maxX,
            y: all9Frames[8].midY
        )
        fingerView.alpha = 1
        fingerView.transform = .identity

        // arrow.right + arrow.up 표시
        let config = UIImage.SymbolConfiguration(pointSize: 24, weight: .bold)
        let rightArrow = UIImage(systemName: "arrow.up.right", withConfiguration: config)
        arrowView.image = rightArrow
        arrowView.center = CGPoint(
            x: row2UnionRect.midX,
            y: row2UnionRect.minY - 20
        )
        arrowView.alpha = 1
    }

    // MARK: - Cleanup

    /// A-2 전용 리소스 정리 (dismiss에서 호출)
    func cleanupA2() {
        aCounterBadge?.removeFromSuperview()
        aCounterBadge = nil
        aMultiSnapshots?.forEach { $0.removeFromSuperview() }
        aMultiSnapshots = nil
        aMultiMaroonViews?.forEach { $0.removeFromSuperview() }
        aMultiMaroonViews = nil
        aMultiCellFrames = nil
        aAll9CellFrames = nil
        aCurrentStep = 0
    }
}

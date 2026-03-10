//
//  CoachMarkOverlayView+CoachMarkA2.swift
//  PickPhoto
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

        // t=0.00~0.25: Step 1 요소 페이드아웃
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.snapshotView?.alpha = 0
            self?.fingerView.alpha = 0
            self?.maroonView.alpha = 0
        }

        // t=0.25: 타이틀 크로스페이드
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self, !self.shouldStopAnimation || CoachMarkManager.shared.isA2TransitionActive else { return }
            UIView.transition(with: self.titleLabel, duration: 0.3, options: .transitionCrossDissolve) {
                self.titleLabel.text = "한번에 쓱"
            }
        }

        // t=0.25: 하이라이트 확장 (1셀 → 3셀)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
            guard let self else { return }
            self.animateHighlightExpansion(to: row3UnionRect, duration: 0.4)
        }

        // t=0.30: 3셀 스냅샷(Row 2) 배치 + 페이드인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.30) { [weak self] in
            guard let self else { return }
            // Row 2 = 인덱스 6,7,8
            var maroonViews: [UIView] = []
            for i in 6...8 {
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
            // Row 0, Row 1 maroon 뷰도 미리 생성 (나중에 사용)
            for i in 0...5 {
                let mv = UIView()
                mv.backgroundColor = Self.maroonColor
                mv.alpha = Self.maroonAlpha
                mv.frame = CGRect(x: 0, y: 0, width: 0, height: all9Frames[i].height)
                maroonViews.insert(mv, at: i)
            }
            self.aMultiMaroonViews = maroonViews

            // 페이드인
            UIView.animate(withDuration: 0.3) {
                for i in 6...8 { multiSnapshots[i].alpha = 1 }
            }
        }

        // t=0.55: 메시지 텍스트 교체
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { [weak self] in
            guard let self else { return }
            let fullText = "밀면서 옆이나 위로 쓸면\n여러 장을 한번에 정리해요"
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
            // 키워드 강조
            for keyword in ["여러 장", "한번에"] {
                let range = (fullText as NSString).range(of: keyword)
                attr.addAttributes([
                    .font: Self.bodyBoldFont,
                    .foregroundColor: Self.highlightYellow
                ], range: range)
            }
            self.messageLabel.alpha = 0
            self.messageLabel.attributedText = attr
            UIView.animate(withDuration: 0.25) {
                self.messageLabel.alpha = 1
            }
        }

        // t=0.65: 버튼 텍스트 변경
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.65) { [weak self] in
            guard let self else { return }
            self.confirmButton.setTitle("확인", for: .normal)
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

        // 3셀 합산 rect (Phase A 기본 하이라이트)
        let row2UnionRect = multiCellFrames[0]
            .union(multiCellFrames[1])
            .union(multiCellFrames[2])

        // 6셀 합산 rect (Phase B 첫 확장)
        let row1to2UnionRect = all9Frames[3]
            .union(all9Frames[4])
            .union(all9Frames[5])
            .union(row2UnionRect)

        // 9셀 합산 rect (Phase B 최종 확장)
        let allUnionRect = all9Frames[0]
            .union(all9Frames[1])
            .union(all9Frames[2])
            .union(row1to2UnionRect)

        // ===== Phase A: 가로 순차 채움 =====

        // 0.00s: fingerView 등장 (셀[6] 좌측)
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

        // 0.50s: 셀[6] maroon 채움 + 카운터 "1"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.50) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            self.fillMaroon(at: 6, in: maroonViews, frames: all9Frames)
            self.updateCounterBadge(count: 1, highlightRect: row2UnionRect)
        }

        // 0.75s: finger → 셀[7]
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
                self.fingerView.center = CGPoint(x: all9Frames[7].midX, y: all9Frames[7].midY)
            }
        }

        // 0.95s: 셀[7] maroon + 카운터 "2"
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.95) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            self.fillMaroon(at: 7, in: maroonViews, frames: all9Frames)
            self.updateCounterBadge(count: 2, highlightRect: row2UnionRect)
        }

        // 1.20s: finger → 셀[8]
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.20) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseInOut) {
                self.fingerView.center = CGPoint(x: all9Frames[8].midX, y: all9Frames[8].midY)
            }
        }

        // 1.40s: 셀[8] maroon + 카운터 "3"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.40) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            self.fillMaroon(at: 8, in: maroonViews, frames: all9Frames)
            self.updateCounterBadge(count: 3, highlightRect: row2UnionRect)
        }

        // ===== Phase B: 세로 확장 =====

        // 1.65s: finger ↑ Row 1 + 하이라이트 확장 3→6 + Row 1 스냅샷 페이드인
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.65) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }

            // finger 위로 이동
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.fingerView.center = CGPoint(x: all9Frames[4].midX, y: all9Frames[4].midY)
            }

            // 하이라이트 확장: 3셀 → 6셀
            self.animateHighlightExpansion(to: row1to2UnionRect, duration: 0.3)

            // Row 1 스냅샷 페이드인
            for i in 3...5 {
                multiSnapshots[i].frame = all9Frames[i]
                multiSnapshots[i].alpha = 0
                multiSnapshots[i].addSubview(maroonViews[i])
                self.addSubview(multiSnapshots[i])
            }
            UIView.animate(withDuration: 0.2) {
                for i in 3...5 { multiSnapshots[i].alpha = 1 }
            }
        }

        // 1.95s: Row 1 maroon 동시 채움 + 카운터 "6"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.95) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            for i in 3...5 {
                self.fillMaroon(at: i, in: maroonViews, frames: all9Frames)
            }
            self.updateCounterBadge(count: 6, highlightRect: row1to2UnionRect)
        }

        // 2.20s: finger ↑ Row 0 + 하이라이트 확장 6→9 + Row 0 스냅샷 페이드인
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.20) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }

            // finger 위로 이동
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut) {
                self.fingerView.center = CGPoint(x: all9Frames[1].midX, y: all9Frames[1].midY)
            }

            // 하이라이트 확장: 6셀 → 9셀
            self.animateHighlightExpansion(to: allUnionRect, duration: 0.3)

            // Row 0 스냅샷 페이드인
            for i in 0...2 {
                multiSnapshots[i].frame = all9Frames[i]
                multiSnapshots[i].alpha = 0
                multiSnapshots[i].addSubview(maroonViews[i])
                self.addSubview(multiSnapshots[i])
            }
            UIView.animate(withDuration: 0.2) {
                for i in 0...2 { multiSnapshots[i].alpha = 1 }
            }
        }

        // 2.50s: Row 0 maroon 동시 채움 + 카운터 "9"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.50) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            for i in 0...2 {
                self.fillMaroon(at: i, in: maroonViews, frames: all9Frames)
            }
            self.updateCounterBadge(count: 9, highlightRect: allUnionRect)
        }

        // 2.75s: 릴리즈 (finger 원래 크기 + 페이드아웃)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.75) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn) {
                self.fingerView.alpha = 0
                self.fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
            }
        }

        // ===== 복원 (자동 걷힘 — finger 없음) =====

        // 3.45s: 전체 maroon 동시 걷힘 + 하이라이트 수축 9→3 + 카운터 페이드아웃
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.45) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }

            // 전체 maroon 동시 걷힘 (width → 0)
            UIView.animate(withDuration: 0.3) {
                for i in 0...8 {
                    maroonViews[i].frame.size.width = 0
                }
            }

            // 하이라이트 수축: 9셀 → 3셀
            self.animateHighlightExpansion(to: row2UnionRect, duration: 0.3)

            // 카운터 페이드아웃
            UIView.animate(withDuration: 0.15) {
                self.aCounterBadge?.alpha = 0
            }
        }

        // 3.75s: Row 0/Row 1 스냅샷 페이드아웃 (루프 반복 준비)
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.75) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(withDuration: 0.2) {
                for i in 0...5 {
                    multiSnapshots[i].alpha = 0
                }
            }
        }

        // 4.65s: 루프 반복
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.65) { [weak self] in
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
    /// - 카운터 "3" 표시
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

        // 카운터 "3" (애니메이션 없음)
        updateCounterBadge(count: 3, highlightRect: row2UnionRect)
        aCounterBadge?.transform = .identity  // bounce 제거

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

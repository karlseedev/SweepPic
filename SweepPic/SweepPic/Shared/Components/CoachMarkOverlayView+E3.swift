//
//  CoachMarkOverlayView+E3.swift
//  SweepPic
//
//  Created by Claude Code on 2026-04-08.
//
//  E-3: 삭제대기함 스와이프 복구 안내
//  - 트리거: E-1+E-2 Step 3 [확인] dismiss 후 0.3초
//  - 흐름: 딤 배경 → 카드(글씨) 표시 → 1.2초 후 셀 포커싱 축소 → 스냅샷 + 녹색 커튼 → 스와이프 1회 → 실제 복구
//  - 텍스트: "사진을 밀어서 편리하게 복구할 수 있어요 / 연속으로 밀어서 여러 장 복구도 가능해요"

import UIKit
import ObjectiveC
import AppCore   // TrashStore.shared.restore(assetIDs:)

// MARK: - Associated Object Keys (E-3 전용)

private var e3CardViewKey: UInt8 = 0
private var e3GreenViewKey: UInt8 = 0
private var e3SnapshotViewKey: UInt8 = 0
private var e3SwipeDistanceKey: UInt8 = 0
private var e3ResolvedAssetIDKey: UInt8 = 0

// MARK: - E-3: Trash Restore Guide

extension CoachMarkOverlayView {

    // MARK: - Stored Properties (Associated Objects)

    /// E-3 카드 뷰 참조
    private var e3CardView: UIView? {
        get { objc_getAssociatedObject(self, &e3CardViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &e3CardViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// E-3 녹색 딤드 뷰 (스냅샷 위에 배치)
    private var e3GreenView: UIView? {
        get { objc_getAssociatedObject(self, &e3GreenViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &e3GreenViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// E-3 셀 스냅샷 뷰 (오버레이 위에 배치 — 아래 collectionView 갱신을 덮음)
    private var e3SnapshotView: UIView? {
        get { objc_getAssociatedObject(self, &e3SnapshotViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &e3SnapshotViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// E-3 스와이프 거리 (셀 너비 × 100%)
    /// 본체의 swipeDistance는 private이므로 Associated Object로 별도 관리
    private var e3SwipeDistance: CGFloat {
        get { objc_getAssociatedObject(self, &e3SwipeDistanceKey) as? CGFloat ?? 0 }
        set { objc_setAssociatedObject(self, &e3SwipeDistanceKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// E-3에서 실제 복구할 assetID (findCenterTrashCell에서 획득)
    private var e3ResolvedAssetID: String? {
        get { objc_getAssociatedObject(self, &e3ResolvedAssetIDKey) as? String }
        set { objc_setAssociatedObject(self, &e3ResolvedAssetIDKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - 녹색 커튼 색상 (PhotoCell.restoreOverlayColor와 동일)

    /// 복구 커튼 배경색
    private static let e3GreenColor = UIColor(red: 0, green: 0.35, blue: 0.15, alpha: 1)

    /// 복구 커튼 알파 (PhotoCell.dimmedOverlayAlpha와 동일)
    private static let e3GreenAlpha: CGFloat = 0.60

    // MARK: - Show (진입점)

    /// E-3 삭제대기함 스와이프 복구 안내 표시
    /// - Parameter window: 표시할 윈도우
    static func showTrashRestoreGuide(in window: UIWindow) {
        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .trashRestore
        overlay.alpha = 0.01  // hitTest로 터치 즉시 차단, 시각적으론 보이지 않음

        // 딤 배경 (구멍 없는 상태로 시작 — 포커싱 중에 구멍 추가)
        overlay.updateDimPath()
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 삭제대기함 중앙 셀 탐색 (1회 재시도 포함)
        overlay.startE3WithRetry(in: window)
    }

    // MARK: - Cell Finding

    /// 셀 탐색 → 없으면 0.3초 후 1회 재시도 → 실패 시 스킵 (markAsShown 안 함)
    private func startE3WithRetry(in window: UIWindow) {
        if let result = findCenterTrashCell(in: window) {
            beginE3Animation(cell: result.cell, frame: result.frame,
                             snapshot: result.snapshot, assetID: result.assetID, in: window)
        } else {
            // 0.3초 후 1회 재시도
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self else { return }
                if let result = self.findCenterTrashCell(in: window) {
                    self.beginE3Animation(cell: result.cell, frame: result.frame,
                                         snapshot: result.snapshot, assetID: result.assetID, in: window)
                } else {
                    // 재시도 실패 → E-3 스킵 (markAsShown 안 함 — 다음 기회에 재시도)
                    self.removeFromSuperview()
                    CoachMarkManager.shared.currentOverlay = nil
                }
            }
        }
    }

    /// 삭제대기함에서 상단 UI(내비게이션·게이지바) 아래에 완전히 보이는 셀 중 가장 위쪽 탐색
    /// - 상단 UI 뒤에 가려진 셀은 제외 (window 좌표 기준 safeAreaInsets.top + 80pt 이상)
    /// - 조건을 만족하는 셀이 없으면 nil (재시도 로직에서 처리)
    private func findCenterTrashCell(in window: UIWindow)
        -> (cell: PhotoCell, frame: CGRect, snapshot: UIView, assetID: String)?
    {
        guard let trashVC = findTrashViewController(from: window) else { return nil }

        let cv = trashVC.collectionView
        // 상단 안전 기준선: 상태바(safeArea) + 내비/게이지 높이 여유 80pt
        let topSafeY = window.safeAreaInsets.top + 80

        var bestCell: PhotoCell?
        var bestIndexPath: IndexPath?
        var bestMinY: CGFloat = .greatestFiniteMagnitude

        for indexPath in cv.indexPathsForVisibleItems {
            guard indexPath.item >= trashVC.paddingCellCount else { continue }
            guard let cell = cv.cellForItem(at: indexPath) as? PhotoCell else { continue }
            guard let cellSuperview = cell.superview else { continue }

            // window 좌표로 변환해 상단 UI에 가려지는지 확인
            let frameInWindow = cellSuperview.convert(cell.frame, to: window)
            guard frameInWindow.minY >= topSafeY else { continue }

            if frameInWindow.minY < bestMinY {
                bestMinY = frameInWindow.minY
                bestCell = cell
                bestIndexPath = indexPath
            }
        }

        guard let cell = bestCell, let indexPath = bestIndexPath else { return nil }

        // paddingCellCount를 제거한 실제 데이터 인덱스로 assetID 획득
        let actualIndex = indexPath.item - trashVC.paddingCellCount
        guard let assetID = trashVC.gridDataSource.assetID(at: actualIndex) else { return nil }

        // frame은 루프 내에서 이미 window 좌표로 계산됨 — 재변환
        guard let cellSuperview = cell.superview else { return nil }
        let frame = cellSuperview.convert(cell.frame, to: window)

        // 스냅샷 (afterScreenUpdates: false — 현재 렌더 상태 즉시 캡처)
        guard let snapshot = cell.snapshotView(afterScreenUpdates: false) else { return nil }

        return (cell, frame, snapshot, assetID)
    }

    /// 삭제대기함 VC 참조 획득
    /// E-1+E-2 getEmptyButtonFrame() 패턴과 동일 (CoachMarkOverlayView+E1E2.swift:755)
    private func findTrashViewController(from window: UIWindow) -> TrashAlbumViewController? {
        guard let tabBar = window.rootViewController as? TabBarController else { return nil }
        // 삭제대기함 = 마지막 탭 (index 2)
        guard let trashNav = tabBar.viewControllers?.last as? UINavigationController,
              let trashVC = trashNav.viewControllers.first as? TrashAlbumViewController else {
            return nil
        }
        return trashVC
    }

    // MARK: - Animation

    /// E-3 애니메이션 시작 (셀 탐색 완료 후)
    private func beginE3Animation(cell: PhotoCell, frame: CGRect, snapshot: UIView, assetID: String, in window: UIWindow) {
        // 스와이프 거리 설정 (셀 너비 × 100%)
        e3SwipeDistance = frame.width
        e3ResolvedAssetID = assetID

        // 스냅샷 frame 설정 (초기 alpha 0 — 포커싱 후 페이드인)
        snapshot.frame = frame
        snapshot.alpha = 0
        addSubview(snapshot)
        e3SnapshotView = snapshot

        // 녹색 딤드 뷰 (초기 width 0 — 스와이프와 함께 증가)
        let greenView = UIView()
        greenView.backgroundColor = Self.e3GreenColor
        greenView.alpha = Self.e3GreenAlpha
        greenView.frame = CGRect(x: 0, y: 0, width: 0, height: frame.height)
        snapshot.addSubview(greenView)
        e3GreenView = greenView

        // 포커싱 대기 중에 어두워졌다 밝아지는 현상 방지:
        // 처음부터 큰 구멍(= 딤 거의 없음)으로 설정 → 페이드인 시 밝은 상태 유지
        // 1.2초 후 animateE3Focus에서 구멍을 셀 크기로 닫으면서 자연스럽게 어두워짐
        let preExpandSize = max(bounds.width, bounds.height) * 3.0
        let preStartRect = CGRect(
            x: frame.midX - preExpandSize / 2,
            y: frame.midY - preExpandSize / 2,
            width: preExpandSize,
            height: preExpandSize
        )
        let preStartPath = UIBezierPath(rect: bounds)
        preStartPath.append(UIBezierPath(rect: preStartRect))
        dimLayer.path = preStartPath.cgPath

        // 딤 페이드인 (구멍이 큰 상태 = 거의 투명하게 시작)
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1.0
        }

        // 카드를 먼저 표시 (글씨 → 사용자 인지 → 뒤에서 시연)
        // addSubview 순서상 카드가 snapshot/fingerView보다 위에 위치함
        buildE3Card(avoidingFrame: frame)

        // 1.2초 후 포커싱 시작 (글씨 읽을 시간 확보)
        let delay: TimeInterval = UIAccessibility.isReduceMotionEnabled ? 0 : 1.2
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            guard let self, !self.shouldStopAnimation else { return }
            self.animateE3Focus(to: frame) { [weak self] in
                guard let self, !self.shouldStopAnimation else { return }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                    guard let self, !self.shouldStopAnimation else { return }
                    self.beginE3Phase2(frame: frame, in: window)
                }
            }
        }
    }

    /// Phase 1: dimLayer 포커싱 축소 애니메이션 (대형→셀 크기)
    private func animateE3Focus(to targetFrame: CGRect, completion: @escaping () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            // Reduce Motion: 즉시 구멍 설정
            highlightFrame = targetFrame
            updateDimPath()
            completion()
            return
        }

        // 시작 구멍: 화면 3× 크기 rect (딤이 거의 보이지 않는 상태)
        let expandSize = max(bounds.width, bounds.height) * 3.0
        let startRect = CGRect(
            x: targetFrame.midX - expandSize / 2,
            y: targetFrame.midY - expandSize / 2,
            width: expandSize,
            height: expandSize
        )
        let dimStartPath = UIBezierPath(rect: bounds)
        dimStartPath.append(UIBezierPath(rect: startRect))
        let dimEndPath = UIBezierPath(rect: bounds)
        dimEndPath.append(UIBezierPath(rect: targetFrame))

        highlightFrame = targetFrame
        dimLayer.path = dimStartPath.cgPath

        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            self?.dimLayer.path = dimEndPath.cgPath
            self?.dimLayer.removeAnimation(forKey: "e3Focus")
            completion()
        }
        let dimAnim = CABasicAnimation(keyPath: "path")
        dimAnim.fromValue = dimStartPath.cgPath
        dimAnim.toValue = dimEndPath.cgPath
        dimAnim.duration = 0.9
        dimAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dimAnim.fillMode = .forwards
        dimAnim.isRemovedOnCompletion = false
        dimLayer.add(dimAnim, forKey: "e3Focus")
        CATransaction.commit()
    }

    /// Phase 2: 스냅샷 페이드인 → Phase 3 스와이프
    private func beginE3Phase2(frame: CGRect, in window: UIWindow) {
        UIView.animate(withDuration: 0.2, animations: {
            self.e3SnapshotView?.alpha = 1
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }
            // Phase 3: 스와이프 모션 시작
            self.performSingleRestoreSwipe(frame: frame) { [weak self] in
                guard let self else { return }
                self.beginE3Phase4(in: window)
            }
        }
    }

    /// Phase 3: 1회 복구 스와이프 (녹색 커튼)
    /// D-1 performD1DeleteSwipe() 패턴 기반, 녹색 커튼 방향은 같음 (→ 오른쪽)
    private func performSingleRestoreSwipe(frame: CGRect, onComplete: @escaping () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            // Reduce Motion: 정적 표시 (녹색 100% + 정지)
            e3GreenView?.frame.size.width = e3SwipeDistance
            onComplete()
            return
        }

        // 손가락 초기 위치 (셀 좌측 중앙)
        fingerView.sizeToFit()
        fingerView.center = CGPoint(x: frame.minX, y: frame.midY)
        fingerView.alpha = 0
        fingerView.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        fingerView.layer.shadowOpacity = 0
        // 카드가 항상 최상단 — fingerView는 카드 바로 아래에 삽입
        if fingerView.superview !== self {
            if let card = e3CardView {
                insertSubview(fingerView, belowSubview: card)
            } else {
                addSubview(fingerView)
            }
        }

        // 1) Touch Down (0.3초)
        UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
            self.fingerView.alpha = 1.0
            self.fingerView.transform = .identity
            self.fingerView.layer.shadowOpacity = 0.3
            self.fingerView.layer.shadowRadius = 8
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }

            // 2) Press (0.2초, spring)
            UIView.animate(withDuration: 0.2, delay: 0, usingSpringWithDamping: 0.7,
                           initialSpringVelocity: 0, options: [], animations: {
                self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                self.fingerView.layer.shadowRadius = 4
                self.fingerView.layer.shadowOpacity = 0.2
            }) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { return }

                // 3) Drag → (0.3초, UICubicTimingParameters — 자연스러운 가속/감속)
                let timing = UICubicTimingParameters(
                    controlPoint1: CGPoint(x: 0.4, y: 0.0),
                    controlPoint2: CGPoint(x: 0.2, y: 1.0)
                )
                let animator = UIViewPropertyAnimator(duration: 0.3, timingParameters: timing)
                let swipeDist = self.e3SwipeDistance
                animator.addAnimations {
                    self.fingerView.center.x += swipeDist
                    // 약간의 기울기 (7.5° = π/24)
                    self.fingerView.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                        .rotated(by: .pi / 24)
                    // 녹색 커튼 width 증가 (셀 너비만큼)
                    self.e3GreenView?.frame.size.width = swipeDist
                }
                animator.addCompletion { [weak self] _ in
                    guard let self, !self.shouldStopAnimation else { return }

                    // 4) Release (0.2초, curveEaseIn): 손가락 페이드아웃
                    UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseIn, animations: {
                        self.fingerView.alpha = 0
                        self.fingerView.transform = CGAffineTransform(scaleX: 1.05, y: 1.05)
                        self.fingerView.center.y -= 10
                    }) { _ in
                        onComplete()
                    }
                }
                animator.startAnimation()
            }
        }
    }

    /// Phase 4: 실제 복구 + 구멍 닫기 (카드는 이미 표시 중)
    private func beginE3Phase4(in window: UIWindow) {
        guard !shouldStopAnimation else { return }

        // 실제 복구 실행 (fire-and-forget)
        if let assetID = e3ResolvedAssetID {
            TrashStore.shared.restore(assetIDs: [assetID])
        }

        // 하이라이트 구멍 즉시 닫기 (복구 후 collectionView 갱신 → 셀 이동 가능)
        // 구멍을 닫아야 스냅샷 페이드아웃 후 엉뚱한 셀이 구멍으로 보이는 문제 방지
        highlightFrame = .zero
        updateDimPath()

        // [확인] 버튼 활성화 (스와이프 완료 = 시연 끝)
        confirmButton.isEnabled = true

        // 스냅샷 + 녹색 딤드 페이드아웃 (0.2초)
        UIView.animate(withDuration: 0.2, animations: {
            self.e3SnapshotView?.alpha = 0
        }) { _ in
            // 스냅샷 메모리 해제 (카드는 이미 표시 중 — 추가 작업 없음)
            self.e3SnapshotView?.removeFromSuperview()
            self.e3SnapshotView = nil
            self.e3GreenView = nil
        }
    }

    // MARK: - Card

    /// E-3 카드 구성: 본문 + [확인]
    /// - Parameter avoidingFrame: 포커싱 셀 frame — 겹치지 않는 쪽(위/아래)에 카드 배치
    private func buildE3Card(avoidingFrame: CGRect) {
        let card = UIView()
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false

        // blur 배경 (E-1+E-2, F 카드와 동일)
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.frame = card.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(blur)
        addSubview(card)
        e3CardView = card
        card.alpha = 0

        // 본문 (두 문단: \n으로 분리, 각 문단 내 \u{2028}으로 줄바꿈)
        let bodyLabel = UILabel()
        let bodyText = String(localized: "coachMark.e3.body")
        let bodyAttributed = NSMutableAttributedString(
            string: bodyText,
            attributes: [
                .font: CoachMarkOverlayView.bodyFont,
                .foregroundColor: UIColor.white,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    style.lineSpacing = CoachMarkOverlayView.bodyFont.pointSize * 0.2
                    style.paragraphSpacing = 12
                    return style
                }(),
            ]
        )
        // "밀어서" 키워드 bold + 노란색 강조 (두 번 등장 — 모두 강조)
        let keyword = String(localized: "coachMark.e3.keyword")
        var searchRange = bodyText.startIndex..<bodyText.endIndex
        while let range = bodyText.range(of: keyword, range: searchRange) {
            bodyAttributed.addAttributes([
                .font: CoachMarkOverlayView.bodyBoldFont,
                .foregroundColor: CoachMarkOverlayView.highlightYellow,
            ], range: NSRange(range, in: bodyText))
            searchRange = range.upperBound..<bodyText.endIndex
        }
        bodyLabel.attributedText = bodyAttributed
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bodyLabel)

        // [확인] 버튼 — 기존 confirmButton 재사용
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = false  // 스와이프 모션 완료 후 활성화
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // 셀을 가리지 않도록 Y 위치 결정:
        // 셀 아래 여백 > 위 여백 → 카드를 셀 아래에, 아니면 셀 위에
        let spaceAbove = avoidingFrame.minY
        let spaceBelow = bounds.height - avoidingFrame.maxY
        let cardGap: CGFloat = 24  // 셀과 카드 사이 간격

        let cardYConstraint: NSLayoutConstraint
        if spaceBelow >= spaceAbove {
            // 셀 아래 공간이 더 넓음 → 카드를 셀 아래에 배치
            cardYConstraint = card.topAnchor.constraint(
                equalTo: topAnchor, constant: avoidingFrame.maxY + cardGap)
        } else {
            // 셀 위 공간이 더 넓음 → 카드를 셀 위에 배치
            cardYConstraint = card.bottomAnchor.constraint(
                equalTo: topAnchor, constant: avoidingFrame.minY - cardGap)
        }

        // 레이아웃
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            cardYConstraint,
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),

            bodyLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            confirmButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])

        // 카드 페이드인
        UIView.animate(withDuration: 0.25) {
            card.alpha = 1
        }
    }

    // MARK: - Cleanup

    /// E-3 전용 리소스 정리 (dismiss 시 호출)
    func cleanupE3() {
        guard coachMarkType == .trashRestore else { return }

        e3CardView?.removeFromSuperview()
        e3CardView = nil

        e3SnapshotView?.removeFromSuperview()
        e3SnapshotView = nil

        e3GreenView = nil
        e3ResolvedAssetID = nil
    }
}

//
//  CoachMarkOverlayView+E3.swift
//  SweepPic
//
//  Created by Claude Code on 2026-04-08.
//
//  E-3: 삭제대기함 스와이프 복구 안내
//  - 트리거: E-1+E-2 Step 3 [확인] dismiss 후 0.3초
//  - 흐름: 딤 배경 → 셀 포커싱 축소 → 스냅샷 + 녹색 커튼 → 스와이프 1회 → 실제 복구 → 카드
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
private var e3TintLayerKey: UInt8 = 0

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

    /// 포커싱 구멍 위 흰색 반투명 틴트 레이어 (D-1 패턴 — dimLayer 바로 위)
    /// E-3: 포커싱 중 opacity 1 유지 → 스냅샷 페이드인 시 0으로 페이드아웃
    private var e3TintLayer: CAShapeLayer? {
        get { objc_getAssociatedObject(self, &e3TintLayerKey) as? CAShapeLayer }
        set { objc_setAssociatedObject(self, &e3TintLayerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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

    /// 삭제대기함 화면 중앙에서 가장 가까운 PhotoCell 탐색
    /// A 코치마크의 findCenterCell() 패턴과 동일
    private func findCenterTrashCell(in window: UIWindow)
        -> (cell: PhotoCell, frame: CGRect, snapshot: UIView, assetID: String)?
    {
        guard let trashVC = findTrashViewController(from: window) else { return nil }

        let cv = trashVC.collectionView
        let centerPoint = CGPoint(x: cv.bounds.midX, y: cv.bounds.midY)
        var bestCell: PhotoCell?
        var bestIndexPath: IndexPath?
        var bestDistance: CGFloat = .greatestFiniteMagnitude

        // 화면 중앙에서 가장 가까운 실제 사진 셀 탐색
        for indexPath in cv.indexPathsForVisibleItems {
            // paddingCellCount 이전은 헤더/패딩 셀이므로 건너뜀
            guard indexPath.item >= trashVC.paddingCellCount else { continue }
            guard let cell = cv.cellForItem(at: indexPath) as? PhotoCell else { continue }
            let distance = hypot(cell.center.x - centerPoint.x, cell.center.y - centerPoint.y)
            if distance < bestDistance {
                bestDistance = distance
                bestCell = cell
                bestIndexPath = indexPath
            }
        }

        guard let cell = bestCell, let indexPath = bestIndexPath else { return nil }

        // paddingCellCount를 제거한 실제 데이터 인덱스로 assetID 획득
        let actualIndex = indexPath.item - trashVC.paddingCellCount
        guard let assetID = trashVC.gridDataSource.assetID(at: actualIndex) else { return nil }

        // 셀 frame을 window 좌표로 변환
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

        // 딤 페이드인
        UIView.animate(withDuration: 0.3) {
            self.alpha = 1.0
        }

        // 카드를 먼저 표시 (글씨 → 사용자 인지 → 뒤에서 시연)
        // addSubview 순서상 카드가 snapshot/fingerView보다 위에 위치함
        buildE3Card()

        // 글씨를 읽을 시간 확보 후 포커싱 시작 (1.2초 대기)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in
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

    /// Phase 1: 포커싱 축소 애니메이션 (dimLayer + tintLayer 동기화)
    /// D-1 animateDFocusWithTint 패턴 참고, 단 tint opacity 방향이 반대:
    /// D-1: opacity 0→1 (포커싱 끝에서 등장)
    /// E-3: opacity 1→1 (포커싱 내내 유지) → 스냅샷 페이드인 시 0으로 사라짐
    private func animateE3Focus(to targetFrame: CGRect, completion: @escaping () -> Void) {
        if UIAccessibility.isReduceMotionEnabled {
            // Reduce Motion: 즉시 구멍 + 틴트 설정
            highlightFrame = targetFrame
            updateDimPath()
            setupE3TintLayer(frame: targetFrame)
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

        // dimLayer 경로
        let dimStartPath = UIBezierPath(rect: bounds)
        dimStartPath.append(UIBezierPath(rect: startRect))
        let dimEndPath = UIBezierPath(rect: bounds)
        dimEndPath.append(UIBezierPath(rect: targetFrame))

        // tintLayer 경로 (dimLayer 구멍과 동일한 rect만 채움)
        let tintStartPath = UIBezierPath(rect: startRect)
        let tintEndPath = UIBezierPath(rect: targetFrame)

        // dimLayer 시작 path 설정
        highlightFrame = targetFrame
        dimLayer.path = dimStartPath.cgPath

        // tintLayer 생성 + 시작 path 설정 (opacity = 1 — 처음부터 보임)
        setupE3TintLayer(frame: targetFrame)
        e3TintLayer?.path = tintStartPath.cgPath
        e3TintLayer?.opacity = 1

        // dimLayer + tintLayer 동시 축소 (같은 CATransaction)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            self.dimLayer.path = dimEndPath.cgPath
            self.dimLayer.removeAnimation(forKey: "e3Focus")
            self.e3TintLayer?.path = tintEndPath.cgPath
            self.e3TintLayer?.removeAnimation(forKey: "e3Tint")
            completion()
        }

        // dimLayer path 축소
        let dimAnim = CABasicAnimation(keyPath: "path")
        dimAnim.fromValue = dimStartPath.cgPath
        dimAnim.toValue = dimEndPath.cgPath
        dimAnim.duration = 0.9
        dimAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dimAnim.fillMode = .forwards
        dimAnim.isRemovedOnCompletion = false
        dimLayer.add(dimAnim, forKey: "e3Focus")

        // tintLayer path 축소 (dimLayer와 동기화)
        let tintAnim = CABasicAnimation(keyPath: "path")
        tintAnim.fromValue = tintStartPath.cgPath
        tintAnim.toValue = tintEndPath.cgPath
        tintAnim.duration = 0.9
        tintAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        tintAnim.fillMode = .forwards
        tintAnim.isRemovedOnCompletion = false
        e3TintLayer?.add(tintAnim, forKey: "e3Tint")

        CATransaction.commit()
    }

    /// tintLayer 생성 (dimLayer 위에 삽입)
    private func setupE3TintLayer(frame: CGRect) {
        guard e3TintLayer == nil else { return }
        let tint = CAShapeLayer()
        // 흰색 20% — 어두운 배경에서 셀을 밝게 보이게 함
        tint.fillColor = UIColor.white.withAlphaComponent(0.1).cgColor
        tint.path = UIBezierPath(rect: frame).cgPath
        // dimLayer 바로 위에 삽입 (D-1 패턴)
        layer.insertSublayer(tint, above: dimLayer)
        e3TintLayer = tint
    }

    /// Phase 2: 스냅샷 페이드인 + 틴트 페이드아웃 (동시) → Phase 3 스와이프
    private func beginE3Phase2(frame: CGRect, in window: UIWindow) {
        // 스냅샷 페이드인 + 틴트 페이드아웃 동시 (0.2초)
        // 틴트: opacity 1→0, UIView.animate 대신 CABasicAnimation 사용 (CAShapeLayer)
        let tintFadeAnim = CABasicAnimation(keyPath: "opacity")
        tintFadeAnim.fromValue = 1
        tintFadeAnim.toValue = 0
        tintFadeAnim.duration = 0.2
        tintFadeAnim.fillMode = .forwards
        tintFadeAnim.isRemovedOnCompletion = false
        e3TintLayer?.add(tintFadeAnim, forKey: "e3TintFadeOut")
        e3TintLayer?.opacity = 0

        UIView.animate(withDuration: 0.2, animations: {
            self.e3SnapshotView?.alpha = 1
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }
            // 틴트 레이어 완전 제거 (스냅샷이 덮고 있으므로 이후 불필요)
            self.e3TintLayer?.removeFromSuperlayer()
            self.e3TintLayer = nil
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
    private func buildE3Card() {
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

        // [확인] 버튼 — 기존 confirmButton 재사용 (E-1+E-2 끝난 후이므로 카드에 배치)
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = false  // 스와이프 모션 완료 후 활성화
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // 레이아웃
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
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
        e3TintLayer?.removeFromSuperlayer()
        e3TintLayer = nil
    }
}

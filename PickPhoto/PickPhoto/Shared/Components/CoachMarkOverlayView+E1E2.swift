//
//  CoachMarkOverlayView+E1E2.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-22.
//
//  E-1+E-2: 삭제 시스템 안내 시퀀스
//  - E-1 (Step 1): 첫 삭제 후 아이콘 이동 + 카드 팝업 + 포커스 원 + 탭 전환
//  - E-2 (Step 2+3): 삭제대기함 탭 전환 후 카드 확장 + 비우기 하이라이트
//
//  시퀀스 흐름:
//    1. 딤 배경 페이드인 (구멍 없음)
//    2. 셀의 trashIcon 위치에 xmark.bin 아이콘 생성 (25×25)
//    3. 아이콘이 커지면서 화면 중앙으로 이동 (~0.6s, spring)
//    4. 아이콘 아래에 카드 팝업: "방금 삭제된 사진은..." + [확인]
//    5. [확인] → 카드+아이콘 페이드아웃 → 포커스 원 축소 → 손가락 탭 → 탭 전환
//    6. Step 2: "보관함에서 삭제하면 여기에 임시 보관돼요."
//    7. Step 3: 비우기 버튼 하이라이트 + "[비우기]를 누르면 사진이 최종 삭제돼요." + [확인]
//
//  E-1+E-2는 하나의 연속 시퀀스로, 단일 오버레이가 시작부터 끝까지 유지됨

import UIKit
import ObjectiveC

// MARK: - Associated Object Keys (E-1+E-2 전용)

private var currentStepKey: UInt8 = 0
private var step1ContainerKey: UInt8 = 0
private var trashIconImageViewKey: UInt8 = 0
private var step2LabelKey: UInt8 = 0
private var step3LabelKey: UInt8 = 0
private var fingerAnimationViewKey: UInt8 = 0
private var cardViewKey: UInt8 = 0
private var step2BottomConstraintKey: UInt8 = 0
private var focusBorderLayerKey: UInt8 = 0

// MARK: - E-1+E-2: Delete System Guide Sequence

extension CoachMarkOverlayView {

    // MARK: - Stored Properties (Associated Objects)

    /// 현재 시퀀스 단계 (E-1+E-2 전용)
    /// Step 1: E-1 (아이콘 이동 + 카드 + 포커스 원 + 탭 전환)
    /// Step 2: 탭 전환 후 첫 번째 텍스트
    /// Step 3: 비우기 하이라이트 + 두 번째 텍스트 + [확인]
    var systemFeedbackCurrentStep: Int {
        get { objc_getAssociatedObject(self, &currentStepKey) as? Int ?? 1 }
        set { objc_setAssociatedObject(self, &currentStepKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 1 컨테이너 (아이콘 + 카드를 묶는 뷰)
    private var step1Container: UIView? {
        get { objc_getAssociatedObject(self, &step1ContainerKey) as? UIView }
        set { objc_setAssociatedObject(self, &step1ContainerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 중앙 이동 아이콘 (xmark.bin, Step 1 전용)
    private var trashIconImageView: UIImageView? {
        get { objc_getAssociatedObject(self, &trashIconImageViewKey) as? UIImageView }
        set { objc_setAssociatedObject(self, &trashIconImageViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 2 텍스트 라벨
    private var step2Label: UILabel? {
        get { objc_getAssociatedObject(self, &step2LabelKey) as? UILabel }
        set { objc_setAssociatedObject(self, &step2LabelKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 3 텍스트 라벨
    private var step3Label: UILabel? {
        get { objc_getAssociatedObject(self, &step3LabelKey) as? UILabel }
        set { objc_setAssociatedObject(self, &step3LabelKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 탭바 가리키는 손가락 애니메이션 뷰 (Step 1 전용)
    private var tabFingerView: UIImageView? {
        get { objc_getAssociatedObject(self, &fingerAnimationViewKey) as? UIImageView }
        set { objc_setAssociatedObject(self, &fingerAnimationViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 2+3 카드 뷰
    private var feedbackCardView: UIView? {
        get { objc_getAssociatedObject(self, &cardViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &cardViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 포커스 원 테두리 레이어 (흰색 원형 스트로크)
    private var focusBorderLayer: CAShapeLayer? {
        get { objc_getAssociatedObject(self, &focusBorderLayerKey) as? CAShapeLayer }
        set { objc_setAssociatedObject(self, &focusBorderLayerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 2 카드 하단 제약 (Step 3 확장 시 비활성화용)
    private var step2BottomConstraint: NSLayoutConstraint? {
        get { objc_getAssociatedObject(self, &step2BottomConstraintKey) as? NSLayoutConstraint }
        set { objc_setAssociatedObject(self, &step2BottomConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - E-1+E-2: Show (진입점)

    /// E-1+E-2 통합: 삭제 시스템 안내 시퀀스 시작
    /// 단일 오버레이가 시작부터 끝까지 유지되며 모든 입력을 차단
    /// - Parameters:
    ///   - window: 표시할 윈도우
    ///   - iconFrame: 삭제된 셀의 trashIcon window 좌표 (nil이면 아이콘 애니메이션 생략)
    static func showDeleteSystemGuide(in window: UIWindow, iconFrame: CGRect?) {
        // VoiceOver 가드 (접근성 대응 미구현 상태에서는 표시하지 않음)
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .firstDeleteGuide
        overlay.systemFeedbackCurrentStep = 1
        overlay.alpha = 0

        // Step 1: 살짝 딤 (포커스 원 시작 시 0.7로 전환)
        overlay.dimLayer.fillColor = UIColor.black.withAlphaComponent(0.3).cgColor
        overlay.updateDimPath()

        // window에 추가
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 딤 페이드인 + 콘텐츠 시작
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        } completion: { _ in
            guard !overlay.shouldStopAnimation else { return }

            if let iconFrame = iconFrame {
                // 아이콘 이동 + 카드 시간차 등장
                overlay.animateIconAndCard(from: iconFrame)
            } else {
                // 뷰어 삭제: 아이콘 포함 카드 바로 표시
                overlay.buildStep1Content()
                overlay.step1Container?.alpha = 0
                UIView.animate(withDuration: 0.25) {
                    overlay.step1Container?.alpha = 1
                }
            }
        }
    }

    // MARK: - Step 1: Icon + Card Staggered Animation

    /// 아이콘 이동과 카드 등장을 시간차로 실행
    /// 아이콘이 이동하는 중간에 카드가 페이드인되어 자연스럽게 합류
    /// - Parameter startFrame: trashIcon의 window 좌표 frame (25×25)
    private func animateIconAndCard(from startFrame: CGRect) {
        // 1. 카드 먼저 생성 (숨긴 상태, 아이콘 공간 포함)
        buildStep1Content()
        step1Container?.alpha = 0
        layoutIfNeeded()  // 카드 frame 확정 (아이콘 최종 위치 계산용)

        // 2. 카드 내부 아이콘의 최종 위치 (overlay 좌표) — 카드 아이콘은 spacer 역할만
        guard let cardIcon = trashIconImageView,
              let card = step1Container else { return }
        let iconFinalCenter = card.convert(cardIcon.center, to: self)
        cardIcon.alpha = 0  // 카드 내부 아이콘 숨김 (spacer 역할만, 날아온 아이콘이 그대로 유지)

        // 3. 날아오는 아이콘 생성 (셀 위치에서 시작, 이 아이콘이 최종까지 유지됨)
        let flyingConfig = UIImage.SymbolConfiguration(pointSize: 25, weight: .regular)
        let flyingIcon = UIImageView(image: UIImage(systemName: "xmark.bin", withConfiguration: flyingConfig))
        flyingIcon.tintColor = .white
        flyingIcon.frame = startFrame
        addSubview(flyingIcon)
        trashIconImageView = flyingIcon  // 날아온 아이콘을 메인 참조로 교체

        // 4. 아이콘 이동 애니메이션 (0.9s spring, 25pt → 48pt)
        let finalSize: CGFloat = 48
        UIView.animate(
            withDuration: 0.9,
            delay: 0,
            usingSpringWithDamping: 0.8,
            initialSpringVelocity: 0.5,
            options: []
        ) {
            let scale = finalSize / 25.0
            flyingIcon.transform = CGAffineTransform(scaleX: scale, y: scale)
            flyingIcon.center = iconFinalCenter
        }
        // 교체 없음 — 날아온 아이콘이 그대로 카드 위에 유지

        // 5. 카드 시간차 페이드인 (아이콘 이동 0.35s 후 시작)
        UIView.animate(withDuration: 0.3, delay: 0.35, options: .curveEaseOut) { [weak self] in
            self?.step1Container?.alpha = 1
        }
    }

    // MARK: - Step 1: Build Content (카드 팝업)

    /// Step 1 카드 구성: 아이콘(상단) + 텍스트(아이콘 아래, 설명 스타일) + [확인]
    /// 아이콘이 카드 내부에 포함되어 아이콘-설명 레이아웃을 형성
    private func buildStep1Content() {
        // 카드 컨테이너
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        step1Container = card

        // 아이콘 (카드 상단 중앙, 48pt)
        let iconConfig = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        let iconView = UIImageView(image: UIImage(systemName: "xmark.bin", withConfiguration: iconConfig))
        iconView.tintColor = .white
        iconView.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(iconView)
        trashIconImageView = iconView

        // 안내 텍스트 (아이콘 바로 아래, 설명 스타일)
        let label = UILabel()
        label.text = "방금 삭제된 사진은\n삭제대기함으로 이동됐어요\n삭제대기함으로 가볼게요"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        // [확인] 버튼
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // 카드 레이아웃 (화면 중앙, 약간 위)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),

            // 아이콘 (상단 중앙)
            iconView.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            iconView.centerXAnchor.constraint(equalTo: card.centerXAnchor),

            // 텍스트 (아이콘 바로 아래)
            label.topAnchor.constraint(equalTo: iconView.bottomAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            // 버튼
            confirmButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Step 1: [확인] 후 시퀀스

    /// [확인] 탭 후: 카드+아이콘 페이드아웃 → 포커스 원 축소 → 손가락 모션 → 탭 전환
    func performTabTapMotionThenTransition() {
        // 시퀀스 보호 플래그 ON
        CoachMarkManager.shared.isDeleteGuideSequenceActive = true

        // 1. 카드 + 아이콘 페이드아웃 + 딤 배경 페이드인 (동시)
        let dimColor = UIColor.black.withAlphaComponent(0.7).cgColor
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.step1Container?.alpha = 0
            self?.trashIconImageView?.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }
            self.step1Container?.removeFromSuperview()
            self.step1Container = nil
            self.trashIconImageView?.removeFromSuperview()
            self.trashIconImageView = nil

            // 2. 딤 배경 복원 (포커스 원 애니메이션 전 배경 딤)
            self.dimLayer.fillColor = dimColor

            // 3. 포커스 원 축소 애니메이션
            guard let tabFrame = self.getTrashTabFrame() else {
                // 탭 frame 없으면 바로 전환
                self.transitionToStep2()
                return
            }
            self.animateFocusCircle(to: tabFrame) { [weak self] in
                guard let self, !self.shouldStopAnimation else { return }
                // 4. 포커스 완료 → 손가락 탭 모션
                self.performFingerTapOnTab(tabFrame: tabFrame) { [weak self] in
                    // 5. 탭 모션 완료 → 탭 전환 + Step 2/3
                    self?.transitionToStep2()
                }
            }
        }
    }

    // MARK: - Focus Circle Animation (포커스 원 축소)

    /// 포커스 원 축소 애니메이션: 화면 밖 큰 원 → 삭제대기함 탭 크기 (60%)
    /// CABasicAnimation으로 dimLayer.path를 보간하여 부드러운 축소 효과
    /// - Parameters:
    ///   - tabFrame: 삭제대기함 탭의 window 좌표 frame
    ///   - completion: 애니메이션 완료 후 콜백
    private func animateFocusCircle(to tabFrame: CGRect, completion: @escaping () -> Void) {
        let margin: CGFloat = 6
        let holeRect = tabFrame.insetBy(dx: -margin, dy: -margin)

        // 최종 원 (삭제대기함 탭의 60% 크기)
        let finalDiameter = max(holeRect.width, holeRect.height) * 0.6
        let finalCircleRect = CGRect(
            x: holeRect.midX - finalDiameter / 2,
            y: holeRect.midY - finalDiameter / 2,
            width: finalDiameter,
            height: finalDiameter
        )

        // 시작 원 (화면 밖에서부터 축소되도록 3배 크기)
        let startDiameter = max(bounds.width, bounds.height) * 3.0
        let startCircleRect = CGRect(
            x: holeRect.midX - startDiameter / 2,
            y: holeRect.midY - startDiameter / 2,
            width: startDiameter,
            height: startDiameter
        )

        // 시작 경로 (큰 구멍 = 딤 거의 없음)
        let startPath = UIBezierPath(rect: bounds)
        startPath.append(UIBezierPath(ovalIn: startCircleRect))

        // 최종 경로 (작은 구멍 = 삭제대기함만 투명)
        let endPath = UIBezierPath(rect: bounds)
        endPath.append(UIBezierPath(ovalIn: finalCircleRect))

        // 테두리 레이어 (흰색 원형 스트로크, dimLayer 위에 배치)
        let borderLayer = CAShapeLayer()
        borderLayer.fillColor = UIColor.clear.cgColor
        borderLayer.strokeColor = UIColor.white.cgColor
        borderLayer.lineWidth = 2
        borderLayer.path = UIBezierPath(ovalIn: startCircleRect).cgPath
        layer.addSublayer(borderLayer)
        focusBorderLayer = borderLayer

        // CABasicAnimation으로 path 보간 (딤 + 테두리 동기화)
        CATransaction.begin()
        CATransaction.setCompletionBlock { [weak self] in
            guard let self else { return }
            // 최종 상태 확정
            self.highlightFrame = tabFrame
            self.dimLayer.path = endPath.cgPath
            self.dimLayer.removeAnimation(forKey: "focusCircle")
            borderLayer.path = UIBezierPath(ovalIn: finalCircleRect).cgPath
            borderLayer.removeAnimation(forKey: "focusBorder")
            completion()
        }

        // 딤 구멍 축소 애니메이션 (0.9s)
        let dimAnimation = CABasicAnimation(keyPath: "path")
        dimAnimation.fromValue = startPath.cgPath
        dimAnimation.toValue = endPath.cgPath
        dimAnimation.duration = 0.9
        dimAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        dimAnimation.fillMode = .forwards
        dimAnimation.isRemovedOnCompletion = false
        dimLayer.add(dimAnimation, forKey: "focusCircle")

        // 테두리 원 축소 애니메이션 (딤과 동일 타이밍)
        let borderAnimation = CABasicAnimation(keyPath: "path")
        borderAnimation.fromValue = UIBezierPath(ovalIn: startCircleRect).cgPath
        borderAnimation.toValue = UIBezierPath(ovalIn: finalCircleRect).cgPath
        borderAnimation.duration = 0.9
        borderAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        borderAnimation.fillMode = .forwards
        borderAnimation.isRemovedOnCompletion = false
        borderLayer.add(borderAnimation, forKey: "focusBorder")

        CATransaction.commit()
    }

    // MARK: - Finger Tap Motion (손가락 탭 모션)

    /// 탭 버튼 위에서 손가락 탭 모션 (등장 → 누르기 → 떼기 → 완료)
    private func performFingerTapOnTab(tabFrame: CGRect, completion: @escaping () -> Void) {
        // 손가락 아이콘 생성
        let config = UIImage.SymbolConfiguration(pointSize: 44, weight: .regular)
        let image = UIImage(systemName: "hand.point.up.fill", withConfiguration: config)
        let finger = UIImageView(image: image)
        finger.tintColor = .white
        finger.layer.shadowColor = UIColor.black.cgColor
        finger.layer.shadowOffset = CGSize(width: 0, height: 2)
        finger.layer.shadowRadius = 6
        finger.layer.shadowOpacity = 0.3
        finger.sizeToFit()
        addSubview(finger)
        tabFingerView = finger

        // 손가락 위치: 탭 중앙 위
        let fingerWidth = finger.bounds.width
        let fingerHeight = finger.bounds.height
        let initialCenter = CGPoint(
            x: tabFrame.midX + fingerWidth * 0.08,
            y: tabFrame.midY + fingerHeight * 0.4
        )
        finger.center = initialCenter
        finger.alpha = 0
        finger.transform = .identity

        // Phase 1: 등장 (0.2초)
        UIView.animate(withDuration: 0.2, delay: 0, options: .curveEaseOut, animations: {
            finger.alpha = 1
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { completion(); return }

            // Phase 2: 누르기 (0.12초, spring)
            UIView.animate(
                withDuration: 0.12,
                delay: 0.1,
                usingSpringWithDamping: 0.6,
                initialSpringVelocity: 0,
                options: [],
                animations: {
                    finger.transform = CGAffineTransform(scaleX: 0.93, y: 0.93)
                    finger.center.y = initialCenter.y + 2.5
                    finger.layer.shadowRadius = 2
                    finger.layer.shadowOffset = CGSize(width: 0, height: 1)
                    finger.layer.shadowOpacity = 0.15
                }
            ) { [weak self] _ in
                guard let self, !self.shouldStopAnimation else { completion(); return }

                // Phase 3: 떼기 + 페이드아웃 (0.2초)
                UIView.animate(
                    withDuration: 0.2,
                    delay: 0.05,
                    usingSpringWithDamping: 0.7,
                    initialSpringVelocity: 2.0,
                    options: [],
                    animations: {
                        finger.transform = .identity
                        finger.center = initialCenter
                        finger.alpha = 0
                        finger.layer.shadowRadius = 6
                        finger.layer.shadowOffset = CGSize(width: 0, height: 2)
                        finger.layer.shadowOpacity = 0.3
                    }
                ) { [weak self] _ in
                    self?.tabFingerView?.removeFromSuperview()
                    self?.tabFingerView = nil
                    completion()
                }
            }
        }
    }

    // MARK: - Step Transition (탭 전환 + Step 2/3)

    /// Step 1 → Step 2,3: 탭 전환 + 순차 텍스트 표시
    /// 오버레이를 dismiss하지 않고 내용만 전환
    func transitionToStep2() {
        guard let tabBar = findTabBarController() else { return }

        // highlightFrame 리셋 (Step 1의 탭 하이라이트 제거)
        highlightFrame = .zero
        updateDimPath()

        // 탭 전환 + 후속 스텝 스케줄링
        let switchTabAndSchedule = { [weak self] in
            // 탭 전환 (삭제대기함 = index 2)
            tabBar.selectedIndex = 2
            // FloatingOverlay 동기화 (iOS 16~25)
            tabBar.floatingOverlay?.selectedTabIndex = 2

            // 탭 전환 완료 후 0.3초 뒤 Step 2 텍스트 페이드인
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.showStep2Content()
            }

            // 탭 전환 완료 후 2.3초 뒤 Step 3: 비우기 하이라이트 + 텍스트 + [확인]
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.3) {
                self?.showStep3Content()
            }
        }

        // iOS 16~25: 뷰어 모달이 떠 있으면 먼저 dismiss 후 스케줄링
        if tabBar.presentedViewController != nil {
            tabBar.dismiss(animated: false) { switchTabAndSchedule() }
        } else {
            switchTabAndSchedule()
        }
    }

    // MARK: - Step 2: Show Content

    /// Step 2: 카드 팝업으로 텍스트 표시 "보관함에서 삭제하면 여기에 임시 보관돼요."
    /// Step 3에서 카드를 확장하여 추가 텍스트 + [확인] 삽입
    private func showStep2Content() {
        guard !shouldStopAnimation else { return }

        // 카드 생성
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.alpha = 0
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        feedbackCardView = card

        // Step 2 텍스트
        let label = UILabel()
        label.text = "보관함에서 삭제하면 여기에 임시 보관돼요."
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        step2Label = label

        // 카드 하단 제약 (Step 3에서 비활성화 후 확장)
        let bottomConstraint = label.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24)
        step2BottomConstraint = bottomConstraint

        // 카드 레이아웃 (화면 중앙)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),

            // 내부 패딩
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),
            bottomConstraint,
        ])

        // 페이드인
        UIView.animate(withDuration: 0.25) {
            card.alpha = 1
        }
    }

    // MARK: - Step 3: Show Content

    /// Step 3: 기존 Step 2 카드를 확장하여 비우기 안내 텍스트 + [확인] 추가
    /// 비우기 버튼 하이라이트도 함께 표시
    private func showStep3Content() {
        guard !shouldStopAnimation else { return }
        guard let card = feedbackCardView else { return }

        systemFeedbackCurrentStep = 3

        // 비우기 버튼 frame 획득 및 하이라이트
        if let frame = getEmptyButtonFrame() {
            highlightFrame = frame
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            updateDimPath()
            CATransaction.commit()
        }

        // Step 2 카드 하단 제약 해제 (카드 확장 준비)
        step2BottomConstraint?.isActive = false
        step2BottomConstraint = nil

        // Step 3 텍스트: "[비우기]를 누르면 사진이 최종 삭제돼요."
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)
        step3Label = label

        // "[비우기]" 부분을 볼드 + 빨간색으로 강조
        let text = "[비우기]를 누르면 사진이 최종 삭제돼요."
        let attributed = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: UIFont.systemFont(ofSize: 17, weight: .medium),
                .foregroundColor: UIColor.white,
            ]
        )
        if let range = text.range(of: "[비우기]") {
            let nsRange = NSRange(range, in: text)
            attributed.addAttributes([
                .font: UIFont.systemFont(ofSize: 17, weight: .bold),
                .foregroundColor: UIColor.systemRed,
            ], range: nsRange)
        }
        label.attributedText = attributed

        // [확인] 버튼 — 카드 안에 재배치
        confirmButton.isEnabled = true
        confirmButton.alpha = 0
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        if confirmButton.superview != card {
            confirmButton.removeFromSuperview()
        }
        card.addSubview(confirmButton)

        // Step 2 라벨 아래에 배치, 카드 하단 제약 연결
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: step2Label?.bottomAnchor ?? card.topAnchor, constant: 16),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            confirmButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])

        // 카드 확장 + 새 콘텐츠 페이드인 애니메이션
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
            self.confirmButton.alpha = 1
            self.layoutIfNeeded()
        }
    }

    // MARK: - Cleanup (E-1+E-2 전용)

    /// E-1+E-2 전용 리소스 정리 (dismiss 시 호출)
    func cleanupDeleteGuide() {
        guard coachMarkType == .firstDeleteGuide else { return }

        // 시퀀스 보호 플래그 OFF
        CoachMarkManager.shared.isDeleteGuideSequenceActive = false

        // 모든 E-1+E-2 전용 뷰 제거
        step1Container?.removeFromSuperview()
        step1Container = nil
        trashIconImageView?.removeFromSuperview()
        trashIconImageView = nil
        step2Label?.removeFromSuperview()
        step2Label = nil
        step3Label?.removeFromSuperview()
        step3Label = nil
        tabFingerView?.layer.removeAllAnimations()
        tabFingerView?.removeFromSuperview()
        tabFingerView = nil
        feedbackCardView?.removeFromSuperview()
        feedbackCardView = nil
        step2BottomConstraint = nil
        focusBorderLayer?.removeFromSuperlayer()
        focusBorderLayer = nil
    }

    // MARK: - Helpers

    /// TabBarController 참조 획득
    private func findTabBarController() -> TabBarController? {
        guard let window = self.window ?? self.superview?.window else { return nil }
        return window.rootViewController as? TabBarController
    }

    /// 삭제대기함 탭 frame 획득 (window 좌표)
    /// iOS 16~25: LiquidGlassTabBar의 탭 버튼
    /// iOS 26+: 시스템 UITabBar의 탭 영역
    /// 실패 시 nil → 손가락 모션 생략
    private func getTrashTabFrame() -> CGRect? {
        guard let tabBar = findTabBarController() else { return nil }
        guard let window = self.window else { return nil }

        // iOS 16~25: FloatingOverlay의 LiquidGlassTabBar
        if let overlay = tabBar.floatingOverlay {
            return overlay.tabButtonFrame(at: 2, in: window)
        }

        // iOS 26+: 시스템 UITabBar
        if #available(iOS 26.0, *) {
            let systemTabBar = tabBar.tabBar
            let tabControls = systemTabBar.subviews
                .filter { String(describing: type(of: $0)).contains("Button") }
                .sorted { $0.frame.minX < $1.frame.minX }

            if tabControls.count > 2 {
                let trashControl = tabControls[2]
                return trashControl.convert(trashControl.bounds, to: window)
            }
        }

        return nil
    }

    /// 비우기 버튼 frame 획득 (window 좌표)
    /// iOS 16~25: FloatingTitleBar의 secondRightButton
    /// iOS 26+: navigationItem의 UIBarButtonItem
    /// 실패 시 nil → 하이라이트 생략
    private func getEmptyButtonFrame() -> CGRect? {
        guard let tabBar = findTabBarController() else { return nil }
        guard let window = self.window else { return nil }

        // 삭제대기함 VC 찾기
        guard let trashNav = tabBar.viewControllers?.last as? UINavigationController,
              let trashVC = trashNav.viewControllers.first as? TrashAlbumViewController else {
            return nil
        }

        // iOS 16~25: FloatingTitleBar에서 비우기 버튼 frame
        if let overlay = tabBar.floatingOverlay {
            return overlay.titleBar.secondRightButtonFrameInWindow()
        }

        // iOS 26+: UIBarButtonItem → 내부 view frame
        if #available(iOS 26.0, *) {
            if let barItem = trashVC.emptyTrashBarButtonItem,
               let itemView = barItem.value(forKey: "view") as? UIView {
                return itemView.convert(itemView.bounds, to: window)
            }
        }

        return nil
    }
}

//
//  CoachMarkOverlayView+SystemFeedback.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-20.
//
//  삭제 시스템 안내 (E-1, E-2, E-3) 구현
//  - E-1+E-2: 첫 삭제 후 삭제대기함 안내 (연속 시퀀스, 단일 오버레이)
//  - E-3: 첫 비우기 완료 안내 (단독 카드)
//
//  시퀀스 구조:
//    Step 1: "방금 삭제한 사진은 삭제대기함으로 이동됐어요" + 탭바 손가락 모션 + [확인]
//    Step 2: 탭 전환 후 "보관함에서 삭제하면 여기에 임시 보관돼요."
//    Step 3: 비우기 버튼 하이라이트 + "[비우기]를 누르면 사진이 최종 삭제돼요." + [확인]
//
//  E-3:
//    "✓ 삭제 완료" + "애플 사진앱의 '최근 삭제된 항목'에서 30일 후 완전히 삭제됩니다." + [확인]

import UIKit
import ObjectiveC

// MARK: - Associated Object Keys (E 전용 저장 프로퍼티)

private var currentStepKey: UInt8 = 0
private var step1ContainerKey: UInt8 = 0
private var step2LabelKey: UInt8 = 0
private var step3LabelKey: UInt8 = 0
private var fingerAnimationViewKey: UInt8 = 0
private var cardViewKey: UInt8 = 0

// MARK: - E: System Feedback (Delete Guide + First Empty)

extension CoachMarkOverlayView {

    // MARK: - Stored Properties (Associated Objects)

    /// 현재 시퀀스 단계 (E-1+E-2 전용)
    /// Step 1: E-1 (삭제 안내 + 탭 가리키기)
    /// Step 2: 탭 전환 후 첫 번째 텍스트
    /// Step 3: 비우기 하이라이트 + 두 번째 텍스트 + [확인]
    var systemFeedbackCurrentStep: Int {
        get { objc_getAssociatedObject(self, &currentStepKey) as? Int ?? 1 }
        set { objc_setAssociatedObject(self, &currentStepKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 1 컨테이너 (텍스트 + 확인 버튼 + 손가락 모션)
    private var step1Container: UIView? {
        get { objc_getAssociatedObject(self, &step1ContainerKey) as? UIView }
        set { objc_setAssociatedObject(self, &step1ContainerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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

    /// E-3 카드 뷰 참조
    private var feedbackCardView: UIView? {
        get { objc_getAssociatedObject(self, &cardViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &cardViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - E-1+E-2: Show (Delete System Guide Sequence)

    /// E-1+E-2 통합: 삭제 시스템 안내 시퀀스 시작
    /// 단일 오버레이가 시작부터 끝까지 유지되며 모든 입력을 차단
    /// - Parameter window: 표시할 윈도우
    static func showDeleteSystemGuide(in window: UIWindow) {
        // VoiceOver 가드 (접근성 대응 미구현 상태에서는 표시하지 않음)
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .firstDeleteGuide
        overlay.systemFeedbackCurrentStep = 1
        overlay.alpha = 0

        // 딤 배경 (Step 1: 구멍 없음)
        overlay.updateDimPath()
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // Step 1 콘텐츠 구성
        overlay.buildStep1Content()

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }

    // MARK: - E-3: Show (First Empty Feedback)

    /// E-3: 첫 비우기 완료 안내 (단독 카드 팝업)
    /// - Parameter window: 표시할 윈도우
    static func showFirstEmptyFeedback(in window: UIWindow) {
        // VoiceOver 가드
        guard !UIAccessibility.isVoiceOverRunning else { return }

        let overlay = CoachMarkOverlayView(frame: window.bounds)
        overlay.coachMarkType = .firstEmpty
        overlay.alpha = 0

        // 딤 배경 (구멍 없음)
        overlay.updateDimPath()
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 중앙 카드 구성
        overlay.buildFirstEmptyCard()

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }

    // MARK: - Step 1: Build Content

    /// Step 1 콘텐츠 구성: 텍스트 + [확인] + 탭바 손가락 모션
    private func buildStep1Content() {
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        addSubview(container)
        step1Container = container

        // 안내 텍스트
        let label = UILabel()
        label.text = "방금 삭제한 사진은 삭제대기함으로 이동됐어요.\n아래 탭을 눌러 삭제대기함으로 가볼까요?"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(label)

        // [확인] 버튼 — 기존 confirmButton 재사용
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(confirmButton)

        // 레이아웃 (화면 중앙)
        NSLayoutConstraint.activate([
            container.centerXAnchor.constraint(equalTo: centerXAnchor),
            container.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            container.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            container.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            label.topAnchor.constraint(equalTo: container.topAnchor),
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            confirmButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24),
            confirmButton.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        // 탭바 손가락 모션 시작
        startTabFingerAnimation()
    }

    // MARK: - Step 1: Tab Finger Animation

    /// 삭제대기함 탭을 가리키는 손가락 모션 애니메이션
    private func startTabFingerAnimation() {
        // 탭 위치 구하기 (실패 시 모션 생략)
        guard let tabFrame = getTrashTabFrame() else { return }

        // 손가락 아이콘 생성 (기존 fingerView와 별도)
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

        // 손가락 위치: 탭 버튼 바로 위, 가리키는 느낌
        let fingerWidth = finger.bounds.width
        let fingerHeight = finger.bounds.height
        let targetCenter = CGPoint(
            x: tabFrame.midX + fingerWidth * 0.08,
            y: tabFrame.minY - 4 + fingerHeight * 0.4
        )
        finger.center = targetCenter
        finger.alpha = 0

        // 반복 모션: 위아래로 살짝 흔들림 (탭을 가리키는 느낌)
        UIView.animate(withDuration: 0.3) {
            finger.alpha = 1
        }

        // 반복 바운스 애니메이션
        startFingerBounce(finger: finger, at: targetCenter)
    }

    /// 손가락 위아래 바운스 반복 (최대 5회)
    private func startFingerBounce(finger: UIImageView, at center: CGPoint, count: Int = 0) {
        guard !shouldStopAnimation, count < 5 else { return }

        UIView.animate(
            withDuration: 0.5,
            delay: count == 0 ? 0.3 : 0,
            options: [.curveEaseInOut],
            animations: {
                finger.center.y = center.y - 8
            }
        ) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }
            UIView.animate(
                withDuration: 0.5,
                delay: 0,
                options: [.curveEaseInOut],
                animations: {
                    finger.center.y = center.y
                }
            ) { [weak self] _ in
                self?.startFingerBounce(finger: finger, at: center, count: count + 1)
            }
        }
    }

    // MARK: - Step Transition

    /// Step 1 → Step 2,3: 탭 전환 + 순차 텍스트 표시
    /// 오버레이를 dismiss하지 않고 내용만 전환
    func transitionToStep2() {
        guard let tabBar = findTabBarController() else { return }

        // 시퀀스 보호 플래그 ON (탭 전환 중 viewWillDisappear에서 dismissCurrent 차단)
        CoachMarkManager.shared.isDeleteGuideSequenceActive = true

        // Step 1 콘텐츠 숨김 (페이드아웃)
        hideStep1Content()

        // 탭 전환 + 후속 스텝 스케줄링을 하나의 블록으로 묶음
        let switchTabAndSchedule = { [weak self] in
            // 탭 전환 (삭제대기함 = index 2)
            tabBar.selectedIndex = 2
            // FloatingOverlay 동기화 (iOS 16~25)
            tabBar.floatingOverlay?.selectedTabIndex = 2

            // 탭 전환 완료 후 0.3초 뒤 Step 2 텍스트 페이드인
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self?.showStep2Content()
            }

            // 탭 전환 완료 후 1.3초 뒤 Step 3: 비우기 하이라이트 + 텍스트 + [확인]
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
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

    /// Step 1 콘텐츠 페이드아웃 + 손가락 모션 중단
    private func hideStep1Content() {
        UIView.animate(withDuration: 0.25) { [weak self] in
            self?.step1Container?.alpha = 0
            self?.tabFingerView?.alpha = 0
        } completion: { [weak self] _ in
            self?.step1Container?.removeFromSuperview()
            self?.step1Container = nil
            self?.tabFingerView?.removeFromSuperview()
            self?.tabFingerView = nil
        }
    }

    // MARK: - Step 2: Show Content

    /// Step 2 텍스트 표시: "보관함에서 삭제하면 여기에 임시 보관돼요."
    private func showStep2Content() {
        guard !shouldStopAnimation else { return }

        let label = UILabel()
        label.text = "보관함에서 삭제하면 여기에 임시 보관돼요."
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        step2Label = label

        // 화면 중앙 배치
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -60),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
        ])

        // 페이드인
        UIView.animate(withDuration: 0.25) {
            label.alpha = 1
        }
    }

    // MARK: - Step 3: Show Content

    /// Step 3: 비우기 버튼 하이라이트 + 두 번째 텍스트 + [확인]
    private func showStep3Content() {
        guard !shouldStopAnimation else { return }

        systemFeedbackCurrentStep = 3

        // 비우기 버튼 frame 획득 시도
        let emptyButtonFrame = getEmptyButtonFrame()

        // 비우기 버튼 하이라이트 (frame 획득 성공 시)
        if let frame = emptyButtonFrame {
            highlightFrame = frame
            // 애니메이션으로 딤 구멍 전환
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.3)
            updateDimPath()
            CATransaction.commit()
        }

        // Step 3 텍스트: "[비우기]를 누르면 사진이 최종 삭제돼요."
        let label = UILabel()
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.alpha = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
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

        // [확인] 버튼 재표시
        confirmButton.isEnabled = true
        confirmButton.alpha = 0
        confirmButton.translatesAutoresizingMaskIntoConstraints = false

        // confirmButton이 다른 뷰의 subview면 이동
        if confirmButton.superview != self {
            confirmButton.removeFromSuperview()
        }
        addSubview(confirmButton)

        // Step 2 텍스트 아래에 배치
        let step2Bottom = step2Label ?? self
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: step2Label?.bottomAnchor ?? centerYAnchor, constant: 16),
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),

            confirmButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 24),
            confirmButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
        ])

        // 페이드인
        UIView.animate(withDuration: 0.3) {
            label.alpha = 1
            self.confirmButton.alpha = 1
        }
    }

    // MARK: - E-3: Build Card

    /// E-3 중앙 카드 구성: ✓ 삭제 완료 + 본문 + [확인]
    private func buildFirstEmptyCard() {
        let card = UIView()
        card.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        feedbackCardView = card

        // 아이콘 + 타이틀
        let titleLabel = UILabel()
        titleLabel.text = "✓ 삭제 완료"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // 본문
        let bodyLabel = UILabel()
        bodyLabel.text = "애플 사진앱의 '최근 삭제된 항목'에서\n30일 후 완전히 삭제됩니다."
        bodyLabel.textColor = UIColor.white.withAlphaComponent(0.9)
        bodyLabel.font = .systemFont(ofSize: 15, weight: .regular)
        bodyLabel.textAlignment = .center
        bodyLabel.numberOfLines = 0
        bodyLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(bodyLabel)

        // [확인] 버튼 — 기존 confirmButton 재사용
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // 카드 레이아웃 (화면 중앙, 좌우 24pt 마진)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),

            // 내부 패딩
            titleLabel.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            titleLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            bodyLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 12),
            bodyLabel.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            bodyLabel.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            confirmButton.topAnchor.constraint(equalTo: bodyLabel.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Cleanup

    /// E 전용 리소스 정리 (dismiss 시 호출)
    func cleanupSystemFeedbackIfNeeded() {
        guard coachMarkType == .firstDeleteGuide || coachMarkType == .firstEmpty else { return }

        // 시퀀스 보호 플래그 OFF
        CoachMarkManager.shared.isDeleteGuideSequenceActive = false

        // 모든 E 전용 뷰 제거
        step1Container?.removeFromSuperview()
        step1Container = nil
        step2Label?.removeFromSuperview()
        step2Label = nil
        step3Label?.removeFromSuperview()
        step3Label = nil
        tabFingerView?.layer.removeAllAnimations()
        tabFingerView?.removeFromSuperview()
        tabFingerView = nil
        feedbackCardView?.removeFromSuperview()
        feedbackCardView = nil
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
            // UITabBar의 subviews에서 탭 컨트롤 탐색
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

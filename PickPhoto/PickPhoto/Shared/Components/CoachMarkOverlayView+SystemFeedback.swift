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
private var step2BottomConstraintKey: UInt8 = 0

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

    /// E-3 카드 뷰 참조 (E-1+E-2 Step 2+3 카드로도 재사용)
    private var feedbackCardView: UIView? {
        get { objc_getAssociatedObject(self, &cardViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &cardViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// Step 2 카드 하단 제약 (Step 3 확장 시 비활성화용)
    private var step2BottomConstraint: NSLayoutConstraint? {
        get { objc_getAssociatedObject(self, &step2BottomConstraintKey) as? NSLayoutConstraint }
        set { objc_setAssociatedObject(self, &step2BottomConstraintKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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

        // window에 먼저 추가 (getTrashTabFrame에서 self.window 필요)
        window.addSubview(overlay)
        CoachMarkManager.shared.currentOverlay = overlay

        // 삭제대기함 탭 하이라이트 (딤 구멍)
        if let tabFrame = overlay.getTrashTabFrame() {
            overlay.highlightFrame = tabFrame
        }
        overlay.updateDimPath()

        // Step 1 콘텐츠 구성 (텍스트 + [확인], 손가락 없음)
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

    /// Step 1 콘텐츠 구성: 카드 팝업 (텍스트 + [확인]) + 탭 하이라이트
    /// 손가락 모션은 [확인] 탭 후 시작 (performTabTapMotionThenTransition)
    private func buildStep1Content() {
        // 카드 컨테이너 (E-3과 동일 스타일)
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        addSubview(card)
        step1Container = card

        // 안내 텍스트
        let label = UILabel()
        label.text = "방금 삭제한 사진은 삭제대기함으로 이동됐어요.\n아래 탭을 눌러 삭제대기함으로 가볼까요?"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(label)

        // [확인] 버튼 — 기존 confirmButton 재사용
        confirmButton.setTitleColor(.black, for: .normal)
        confirmButton.backgroundColor = .white
        confirmButton.isEnabled = true
        confirmButton.alpha = 1
        confirmButton.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(confirmButton)

        // 카드 레이아웃 (화면 중앙, E-3과 동일)
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor, constant: -40),
            card.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 24),
            card.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -24),
            card.widthAnchor.constraint(equalTo: widthAnchor, constant: -48),

            // 내부 패딩
            label.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
            label.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -20),

            confirmButton.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 20),
            confirmButton.centerXAnchor.constraint(equalTo: card.centerXAnchor),
            confirmButton.widthAnchor.constraint(equalToConstant: 120),
            confirmButton.heightAnchor.constraint(equalToConstant: 44),
            confirmButton.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
        ])
    }

    // MARK: - Step 1: Tab Tap Motion ([확인] 후)

    /// [확인] 탭 후: 텍스트 페이드아웃 → 손가락 등장 → 탭 탭 모션 → 탭 전환
    func performTabTapMotionThenTransition() {
        // 시퀀스 보호 플래그 ON
        CoachMarkManager.shared.isDeleteGuideSequenceActive = true

        // 텍스트/버튼 페이드아웃
        UIView.animate(withDuration: 0.2, animations: { [weak self] in
            self?.step1Container?.alpha = 0
        }) { [weak self] _ in
            guard let self, !self.shouldStopAnimation else { return }
            self.step1Container?.removeFromSuperview()
            self.step1Container = nil

            // 손가락 탭 모션 시작
            guard let tabFrame = self.getTrashTabFrame() else {
                // 탭 frame 없으면 모션 생략, 바로 전환
                self.transitionToStep2()
                return
            }
            self.performFingerTapOnTab(tabFrame: tabFrame) { [weak self] in
                self?.transitionToStep2()
            }
        }
    }

    /// 탭 버튼 위에서 손가락 탭 모션 (C의 performCTapMotion과 유사)
    /// 등장 → 누르기 → 떼기 → 완료
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
                delay: 0.1,  // 잠시 대기 후 누르기
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

    // MARK: - Step Transition

    /// Step 1 → Step 2,3: 탭 전환 + 순차 텍스트 표시
    /// 오버레이를 dismiss하지 않고 내용만 전환
    func transitionToStep2() {
        guard let tabBar = findTabBarController() else { return }

        // highlightFrame 리셋 (Step 1의 탭 하이라이트 제거)
        highlightFrame = .zero
        updateDimPath()

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

    /// Step 2: 카드 팝업으로 텍스트 표시 "보관함에서 삭제하면 여기에 임시 보관돼요."
    /// Step 3에서 카드를 확장하여 추가 텍스트 + [확인] 삽입
    private func showStep2Content() {
        guard !shouldStopAnimation else { return }

        // 카드 생성 (E-3과 동일 스타일)
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
            self.layoutIfNeeded()  // 카드 크기 확장 애니메이션
        }
    }

    // MARK: - E-3: Build Card

    /// E-3 중앙 카드 구성: ✓ 삭제 완료 + 본문 + [확인]
    private func buildFirstEmptyCard() {
        let card = UIView()
        card.backgroundColor = UIColor(white: 0.15, alpha: 1.0)
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
        step2BottomConstraint = nil
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

//
//  CoachMarkOverlayView+E3.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-22.
//
//  E-3: 첫 비우기 완료 안내 (단독 카드 팝업)
//  - 트리거: performEmptyTrash() 첫 성공 완료 직후
//  - 레이아웃: 딤 배경 + 중앙 카드 ("✓ 삭제 완료" + 본문 + [확인])
//  - E-1+E-2와 독립 (절대 동시에 표시되지 않음)

import UIKit
import ObjectiveC

// MARK: - Associated Object Keys (E-3 전용)

private var e3CardViewKey: UInt8 = 0

// MARK: - E-3: First Empty Feedback

extension CoachMarkOverlayView {

    // MARK: - Stored Properties

    /// E-3 전용 카드 뷰 참조 (E-1+E-2와 별개)
    private var e3CardView: UIView? {
        get { objc_getAssociatedObject(self, &e3CardViewKey) as? UIView }
        set { objc_setAssociatedObject(self, &e3CardViewKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Show (진입점)

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

    // MARK: - Build Card

    /// E-3 중앙 카드 구성: ✓ 삭제 완료 + 본문 + [확인]
    private func buildFirstEmptyCard() {
        let card = UIView()
        card.layer.cornerRadius = 20
        card.clipsToBounds = true
        card.translatesAutoresizingMaskIntoConstraints = false
        // 시스템 팝업 스타일 blur 배경
        let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemMaterialDark))
        blur.frame = card.bounds
        blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        card.addSubview(blur)
        addSubview(card)
        e3CardView = card

        // 아이콘 + 타이틀
        let titleLabel = UILabel()
        titleLabel.text = "✓ 삭제 완료"
        titleLabel.textColor = .white
        titleLabel.font = .systemFont(ofSize: 22, weight: .regular)
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        card.addSubview(titleLabel)

        // 본문
        let bodyLabel = UILabel()
        bodyLabel.text = "애플 사진앱의 '최근 삭제된 항목'에서\n30일 후 완전히 삭제됩니다."
        bodyLabel.textColor = .white
        bodyLabel.font = CoachMarkOverlayView.bodyFont
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

    // MARK: - Cleanup (E-3 전용)

    /// E-3 전용 리소스 정리 (dismiss 시 호출)
    func cleanupFirstEmpty() {
        guard coachMarkType == .firstEmpty else { return }

        e3CardView?.removeFromSuperview()
        e3CardView = nil
    }
}

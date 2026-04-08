//
//  ReferralMenuViewController.swift
//  SweepPic
//
//  친구 초대 서브메뉴 빌더 + 액션 핸들러
//
//  ellipsis 메뉴의 "친구 초대 ▸" 서브메뉴를 생성하고,
//  각 액션(친구 초대 / 초대 코드 입력 / 초대 혜택 받기)을 처리한다.
//
//  기존 PremiumMenuViewController에서 분리 — 프리미엄(구독)과
//  초대(소셜/공유)의 성격이 달라 독립 메뉴로 구성.
//

import UIKit
import OSLog
import AppCore

// MARK: - ReferralMenuViewController

/// 친구 초대 서브메뉴 빌더
/// ellipsis 메뉴에서 UIMenu 서브메뉴로 삽입
final class ReferralMenuViewController {

    // MARK: - Menu Builder

    /// "친구 초대 ▸" 서브메뉴 생성
    /// - Parameter presenter: 메뉴 액션에서 VC를 present할 UIViewController
    /// - Returns: UIMenu 서브메뉴
    static func makeMenu(from presenter: UIViewController) -> UIMenu {
        // 친구 초대하기 (FR-041)
        let referralInviteAction = UIAction(
            title: String(localized: "referral.menu.invite"),
            image: UIImage(systemName: "person.badge.plus")
        ) { _ in
            handleReferralInvite(from: presenter)
        }

        // 초대 코드 입력 (FR-041)
        let referralCodeAction = UIAction(
            title: String(localized: "referral.menu.codeInput"),
            image: UIImage(systemName: "ticket")
        ) { _ in
            handleReferralCodeInput(from: presenter)
        }

        // 초대 혜택 받기 (FR-041)
        let referralRewardAction = UIAction(
            title: String(localized: "referral.menu.reward"),
            image: UIImage(systemName: "gift")
        ) { _ in
            handleReferralReward(from: presenter)
        }

        return UIMenu(
            title: String(localized: "referral.menu.title"),
            image: UIImage(systemName: "person.2"),
            children: [
                referralInviteAction,
                referralCodeAction,
                referralRewardAction,
            ]
        )
    }

    // MARK: - Actions

    /// 친구 초대 → ReferralExplainViewController 모달
    private static func handleReferralInvite(from presenter: UIViewController) {
        let referralVC = ReferralExplainViewController()
        presenter.present(referralVC, animated: true)
        Logger.app.debug("ReferralMenu: 친구 초대 화면 표시")
    }

    /// 초대 코드 입력 → ReferralCodeInputViewController 모달
    private static func handleReferralCodeInput(from presenter: UIViewController) {
        let codeInputVC = ReferralCodeInputViewController()
        presenter.present(codeInputVC, animated: true)
        Logger.app.debug("ReferralMenu: 초대 코드 입력 화면 표시")
    }

    /// 초대 혜택 받기 → ReferralRewardViewController 모달
    private static func handleReferralReward(from presenter: UIViewController) {
        let rewardVC = ReferralRewardViewController()
        presenter.present(rewardVC, animated: true)
        Logger.app.debug("ReferralMenu: 초대 혜택 받기 화면 표시")
    }
}

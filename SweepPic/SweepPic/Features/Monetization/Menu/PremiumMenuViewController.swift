//
//  PremiumMenuViewController.swift
//  SweepPic
//
//  프리미엄 서브메뉴 빌더 + 액션 핸들러 (FR-043, FR-044, T047)
//
//  ellipsis 메뉴의 "멤버십 ▸" 서브메뉴를 생성하고,
//  각 액션(멤버십 관리 / 멤버십 복원 / 리딤 코드)을 처리한다.
//  친구 초대 관련 항목은 ReferralMenuViewController로 분리됨.
//
//  구독 상태와 무관하게 메뉴 구조는 동일 (FR-044),
//  내부에서 상태에 따라 분기 처리한다.
//

import UIKit
import StoreKit
import AppCore
import OSLog

// MARK: - PremiumMenuViewController

/// 프리미엄 서브메뉴 빌더
/// ellipsis 메뉴에서 UIMenu 서브메뉴로 삽입
final class PremiumMenuViewController {

    // MARK: - Menu Builder

    /// "멤버십 ▸" 서브메뉴 생성
    /// - Parameter presenter: 메뉴 액션에서 VC를 present/push할 UIViewController
    /// - Returns: UIMenu 서브메뉴
    static func makeMenu(from presenter: UIViewController) -> UIMenu {
        let subscribeAction = UIAction(
            title: "멤버십 관리",
            image: UIImage(systemName: "creditcard")
        ) { _ in
            handleSubscriptionManagement(from: presenter)
        }

        let restoreAction = UIAction(
            title: "멤버십 복원",
            image: UIImage(systemName: "arrow.clockwise")
        ) { _ in
            handleRestorePurchases(from: presenter)
        }

        let redeemAction = UIAction(
            title: "리딤 코드",
            image: UIImage(systemName: "giftcard")
        ) { _ in
            handleRedeemCode(from: presenter)
        }

        return UIMenu(
            title: "멤버십",
            image: UIImage(systemName: "star.fill"),
            children: [
                subscribeAction, restoreAction, redeemAction,
            ]
        )
    }

    // MARK: - Actions

    /// 구독 관리 — 무료: 페이월 표시 / Pro: 시스템 구독 관리 화면
    /// - Note: Pro 사용자가 시스템 구독 관리로 이동할 때
    ///   pendingCancelCheck 플래그를 설정해 해지 감지를 준비한다.
    ///   SceneDelegate.sceneDidBecomeActive에서 이 플래그를 확인한다.
    private static func handleSubscriptionManagement(from presenter: UIViewController) {
        if SubscriptionStore.shared.isProUser {
            // Pro 사용자 → 해지 감지 플래그 설정 + 시스템 구독 관리 화면
            UserDefaults.standard.set(true, forKey: "pendingCancelCheck")
            UserDefaults.standard.set(
                SubscriptionStore.shared.state.autoRenewEnabled,
                forKey: "wasAutoRenewing"
            )
            openSystemSubscriptionSettings()
            Logger.app.debug("PremiumMenu: Pro 사용자 → 시스템 구독 관리 (해지 감지 플래그 설정)")
        } else {
            // 무료 사용자 → 페이월 표시
            let paywallVC = PaywallViewController()
            paywallVC.analyticsSource = .menu
            paywallVC.modalPresentationStyle = .pageSheet
            presenter.present(paywallVC, animated: true)
            Logger.app.debug("PremiumMenu: 무료 사용자 → 페이월 표시")
        }
    }

    /// 구독 복원 — 이미 Pro: 토스트 / 아닐 때: restorePurchases 실행
    private static func handleRestorePurchases(from presenter: UIViewController) {
        if SubscriptionStore.shared.isProUser {
            // 이미 Pro → 토스트
            if let window = presenter.view.window {
                ToastView.show("이미 멤버십 이용 중입니다", in: window)
            }
            Logger.app.debug("PremiumMenu: 이미 Pro 사용자 → 토스트")
            return
        }

        // 복원 시도
        Task {
            do {
                let restored = try await SubscriptionStore.shared.restorePurchases()
                await MainActor.run {
                    if let window = presenter.view.window {
                        if restored {
                            ToastView.show("멤버십이 복원되었습니다", in: window)
                        } else {
                            ToastView.show("복원할 멤버십이 없습니다", in: window)
                        }
                    }
                }
                Logger.app.debug("PremiumMenu: 복원 결과 — isProUser=\(restored)")
            } catch {
                await MainActor.run {
                    if let window = presenter.view.window {
                        ToastView.show("복원 실패: 네트워크를 확인해주세요", in: window)
                    }
                }
                Logger.app.error("PremiumMenu: 복원 실패 — \(error.localizedDescription)")
            }
        }
    }

    /// 리딤 코드 입력 시트 표시
    private static func handleRedeemCode(from presenter: UIViewController) {
        SubscriptionStore.shared.presentRedemptionSheet(from: presenter)
        Logger.app.debug("PremiumMenu: 리딤 코드 시트 표시")
    }

    /// 시스템 구독 관리 화면 열기
    private static func openSystemSubscriptionSettings() {
        if let url = URL(string: "https://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

}

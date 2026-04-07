//
//  CustomerServiceViewController.swift
//  SweepPic
//
//  고객센터 서브메뉴 빌더 + 액션 핸들러 (FR-043, T048)
//
//  ellipsis 메뉴의 "고객센터 ▸" 서브메뉴를 생성하고,
//  각 액션(피드백/FAQ/이용약관/처리방침/사업자정보)을 처리한다.
//
//  - 피드백: MFMailComposeViewController (T051)
//  - FAQ: FAQViewController push (T049)
//  - 이용약관/처리방침: SFSafariViewController (T052)
//  - 사업자 정보: BusinessInfoViewController push (T050)
//

import UIKit
import MessageUI
import SafariServices
import AppCore
import OSLog

// ReferralStore user_id 접근용

// MARK: - CustomerServiceViewController

/// 고객센터 서브메뉴 빌더
/// ellipsis 메뉴에서 UIMenu 서브메뉴로 삽입
final class CustomerServiceViewController: NSObject {

    // MARK: - Constants

    /// 피드백 이메일 주소
    private static let feedbackEmail = "support@sweeppic.app"

    /// 피드백 이메일 제목
    private static var feedbackSubject: String {
        String(localized: "monetization.support.emailSubject")
    }

    /// 이용약관 URL (출시 전 실제 URL로 교체)
    private static let termsURL = URL(string: "https://sweeppic.app/terms")!

    /// 개인정보처리방침 URL (출시 전 실제 URL로 교체)
    private static let privacyURL = URL(string: "https://sweeppic.app/privacy")!

    /// 사업자 정보는 한국어 locale에서만 노출
    private static var shouldShowBusinessInfo: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ko") == true
    }

    // MARK: - Shared Instance (MFMailComposeViewControllerDelegate 유지용)

    /// 싱글톤 (delegate 참조 유지)
    private static let shared = CustomerServiceViewController()

    // MARK: - Menu Builder

    /// "고객센터 ▸" 서브메뉴 생성
    /// - Parameter presenter: 메뉴 액션에서 VC를 present/push할 UIViewController
    /// - Returns: UIMenu 서브메뉴
    static func makeMenu(from presenter: UIViewController) -> UIMenu {
        let feedbackAction = UIAction(
            title: String(localized: "monetization.support.email"),
            image: UIImage(systemName: "envelope")
        ) { _ in
            handleFeedback(from: presenter)
        }

        let faqAction = UIAction(
            title: String(localized: "monetization.support.faq"),
            image: UIImage(systemName: "questionmark.circle")
        ) { _ in
            handleFAQ(from: presenter)
        }

        let termsAction = UIAction(
            title: String(localized: "monetization.support.terms"),
            image: UIImage(systemName: "doc.text")
        ) { _ in
            handleTerms(from: presenter)
        }

        let privacyAction = UIAction(
            title: String(localized: "monetization.support.privacy"),
            image: UIImage(systemName: "hand.raised")
        ) { _ in
            handlePrivacy(from: presenter)
        }

        var children = [feedbackAction, faqAction, termsAction, privacyAction]
        if shouldShowBusinessInfo {
            let businessInfoAction = UIAction(
                title: "사업자 정보",
                image: UIImage(systemName: "building.2")
            ) { _ in
                handleBusinessInfo(from: presenter)
            }
            children.append(businessInfoAction)
        }

        return UIMenu(
            title: String(localized: "monetization.support.title"),
            image: UIImage(systemName: "questionmark.circle"),
            children: children
        )
    }

    // MARK: - Actions

    /// 피드백 보내기 — MFMailComposeViewController (FR-045, T051)
    /// 미지원 기기 → mailto: URL 폴백
    static func handleFeedback(from presenter: UIViewController) {
        if MFMailComposeViewController.canSendMail() {
            let mailVC = MFMailComposeViewController()
            mailVC.mailComposeDelegate = shared
            mailVC.setToRecipients([feedbackEmail])
            mailVC.setSubject(feedbackSubject)
            mailVC.setMessageBody(buildDeviceInfoBody(), isHTML: false)
            presenter.present(mailVC, animated: true)
            Logger.app.debug("CustomerService: 피드백 이메일 작성 화면 표시")
        } else {
            // mailto: URL 폴백 (Edge Case: 이메일 미설정 기기)
            let subject = feedbackSubject.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            let body = buildDeviceInfoBody().addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
            if let mailtoURL = URL(string: "mailto:\(feedbackEmail)?subject=\(subject)&body=\(body)") {
                UIApplication.shared.open(mailtoURL)
                Logger.app.debug("CustomerService: mailto: URL 폴백")
            }
        }
    }

    /// FAQ 화면 push (T049)
    private static func handleFAQ(from presenter: UIViewController) {
        let faqVC = FAQViewController()
        presenter.navigationController?.pushViewController(faqVC, animated: true)
        Logger.app.debug("CustomerService: FAQ 화면 push")
    }

    /// 이용약관 — SFSafariViewController (FR-047, T052)
    private static func handleTerms(from presenter: UIViewController) {
        let safariVC = SFSafariViewController(url: termsURL)
        presenter.present(safariVC, animated: true)
        Logger.app.debug("CustomerService: 이용약관 인앱 브라우저")
    }

    /// 개인정보처리방침 — SFSafariViewController (FR-047, T052)
    private static func handlePrivacy(from presenter: UIViewController) {
        let safariVC = SFSafariViewController(url: privacyURL)
        presenter.present(safariVC, animated: true)
        Logger.app.debug("CustomerService: 개인정보처리방침 인앱 브라우저")
    }

    /// 사업자 정보 화면 push (T050)
    private static func handleBusinessInfo(from presenter: UIViewController) {
        let bizVC = BusinessInfoViewController()
        presenter.navigationController?.pushViewController(bizVC, animated: true)
        Logger.app.debug("CustomerService: 사업자 정보 화면 push")
    }

    // MARK: - Device Info

    /// 기기 정보 문자열 생성 (FR-045: 자동 첨부)
    private static func buildDeviceInfoBody() -> String {
        let device = UIDevice.current
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        let osVersion = device.systemVersion
        let model = device.model
        let name = device.name

        let userId = ReferralStore.shared.userId

        return """


        ---
        \(String(localized: "monetization.support.appVersion")) \(appVersion) (\(buildNumber))
        iOS: \(osVersion)
        \(String(localized: "monetization.support.device")) \(model)
        \(String(localized: "monetization.support.deviceName")) \(name)
        \(String(localized: "monetization.support.supportId")) \(userId)
        """
    }
}

// MARK: - MFMailComposeViewControllerDelegate

extension CustomerServiceViewController: MFMailComposeViewControllerDelegate {

    /// 이메일 작성 완료/취소 시 dismiss
    func mailComposeController(
        _ controller: MFMailComposeViewController,
        didFinishWith result: MFMailComposeResult,
        error: Error?
    ) {
        controller.dismiss(animated: true)
        Logger.app.debug("CustomerService: 이메일 작성 결과 — \(result.rawValue)")
    }
}

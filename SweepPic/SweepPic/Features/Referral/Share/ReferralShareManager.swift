//
//  ReferralShareManager.swift
//  SweepPic
//
//  초대 공유 메시지 생성 + UIActivityViewController 표시
//
//  공유 메시지 5개 요소 (FR-003):
//  1. 앱 소개: "SweepPic으로 사진 정리하고 14일 프리미엄 무료 받기!"
//  2. 초대 코드: "초대 코드: x0k7m2x99j"
//  3. 설치 + 자동 적용 안내: "아래 링크로 앱 설치 → 링크 한 번 더 누르면 자동 적용"
//  4. 수동 입력 폴백: "앱 > 설정 > 초대 코드 입력에 붙여넣기"
//  5. 링크: "https://sweeppic.link/r/x0k7m2x99j"
//
//  completionHandler:
//  - completed=true → 호출부에서 Push 프리프롬프트 진행
//  - completed=false → 아무 동작 없음
//
//  참조: docs/bm/260316Reward.md §Phase 1
//  참조: specs/004-referral-reward/contracts/protocols.md
//

import UIKit
import AppCore
import OSLog

// MARK: - ReferralShareManager

/// 초대 공유 메시지 생성 + UIActivityViewController 표시 매니저
final class ReferralShareManager {

    // MARK: - Share Message

    /// 공유 메시지 생성 (FR-003 — 5개 요소)
    /// - Parameter link: 초대 링크 정보 (코드 + URL)
    /// - Returns: 공유 메시지 문자열
    func buildShareMessage(link: ReferralLink) -> String {
        // 공유 메시지 5개 구성 요소
        // docs/bm/260316Reward.md §Phase 1 와이어프레임 기준
        return """
        SweepPic으로 사진 정리하고 14일 프리미엄 무료 받기!

        초대 코드: \(link.referralCode)

        1. 아래 링크로 앱 설치
        2. 앱 설치 후 링크를 한 번 더 누르면 무료혜택 자동 적용!

        적용이 안 되면 이 메시지를 복사해서
        앱 > 설정 > 초대 코드 입력에 붙여넣기 해주세요.

        \(link.shareURL.absoluteString)
        """
    }

    // MARK: - Share Sheet

    /// UIActivityViewController로 공유 시트 표시
    /// - Parameters:
    ///   - viewController: 공유 시트를 표시할 뷰 컨트롤러
    ///   - link: 초대 링크 정보
    ///   - completion: 공유 완료 여부 콜백 (completed: true=공유 완료, false=취소)
    func presentShareSheet(
        from viewController: UIViewController,
        link: ReferralLink,
        completion: @escaping (_ completed: Bool) -> Void
    ) {
        let message = buildShareMessage(link: link)

        // UIActivityViewController 설정
        // 텍스트 메시지 + URL을 별도 항목으로 전달
        let activityItems: [Any] = [message]

        let activityVC = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )

        // 공유 완료/취소 핸들러
        activityVC.completionWithItemsHandler = { activityType, completed, _, error in
            if let error = error {
                Logger.referral.error("ReferralShare: 공유 에러 — \(error.localizedDescription)")
            }

            if completed {
                Logger.referral.debug("ReferralShare: 공유 완료 — \(activityType?.rawValue ?? "unknown")")
            } else {
                Logger.referral.debug("ReferralShare: 공유 취소")
            }

            completion(completed)
        }

        // iPad 지원: popover 앵커 설정
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = viewController.view
            popover.sourceRect = CGRect(
                x: viewController.view.bounds.midX,
                y: viewController.view.bounds.midY,
                width: 0,
                height: 0
            )
            popover.permittedArrowDirections = []
        }

        viewController.present(activityVC, animated: true)
    }
}

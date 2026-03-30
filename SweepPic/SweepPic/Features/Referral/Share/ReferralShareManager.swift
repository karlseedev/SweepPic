//
//  ReferralShareManager.swift
//  SweepPic
//
//  초대 공유 메시지 생성 + UIActivityViewController 표시
//
//  공유 메시지 5개 요소 (FR-003):
//  1. 앱 소개: "SweepPic으로 사진 정리하고 14일 무료 혜택 받기!"
//  2. 초대 코드: "초대 코드: x0k7m2x99j"
//  3. 설치 + 자동 적용 안내: "아래 링크로 앱 설치 → 링크 한 번 더 누르면 자동 적용"
//  4. 수동 입력 폴백: "앱 > 설정 > 초대 코드 입력에 붙여넣기"
//  5. 링크: "https://sweeppic.link/r/x0k7m2x99j"
//
//  UIActivityItemSource 구현:
//  - 공유 시트 상단에 제목 + 메시지 미리보기 표시
//  - LPLinkMetadata로 리치 프리뷰 제공
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
import LinkPresentation
import OSLog

// MARK: - ReferralShareItemSource

/// 공유 시트 상단 미리보기를 위한 UIActivityItemSource 구현
/// 제목 + 메시지 본문이 공유 시트에 표시됨
final class ReferralShareItemSource: NSObject, UIActivityItemSource {

    /// 공유할 메시지 전체 텍스트
    private let message: String
    /// 공유 시트 상단 제목
    private let title: String

    /// - Parameters:
    ///   - message: 공유할 메시지 전체 텍스트
    ///   - title: 공유 시트 미리보기 제목
    init(message: String, title: String) {
        self.message = message
        self.title = title
        super.init()
    }

    /// 플레이스홀더 — 공유 시트가 데이터 타입을 결정할 때 사용
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return message
    }

    /// 실제 공유 데이터 반환
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        return message
    }

    /// 공유 시트 상단 제목 (subject)
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        return title
    }

    /// 공유 시트 상단 리치 미리보기 (LPLinkMetadata)
    /// 제목 + 메시지 첫 줄이 미리보기 영역에 표시됨
    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        return metadata
    }
}

// MARK: - ReferralShareManager

/// 초대 공유 메시지 생성 + UIActivityViewController 표시 매니저
final class ReferralShareManager {

    // MARK: - Constants

    /// 공유 시트 미리보기 제목
    private static let shareTitle = "SweepPic 초대"

    // MARK: - Share Message

    /// 공유 메시지 생성 (FR-003 — 5개 요소)
    /// - Parameter link: 초대 링크 정보 (코드 + URL)
    /// - Returns: 공유 메시지 문자열
    func buildShareMessage(link: ReferralLink) -> String {
        // 공유 메시지 5개 구성 요소
        // docs/bm/260316Reward.md §Phase 1 와이어프레임 기준
        return """
        편리한 사진 정리 앱 SweepPic을 추천합니다!
        초대 링크로 가입하고 Pro멤버십 14일 무료 혜택을 받으세요!
        (최초 등록 시 14+7일 무료 제공)

        초대코드: \(link.referralCode)

        1. 아래 링크를 눌러 앱 설치

        2. 앱 설치 후 아래 링크를 한 번 더 누르면 무료 혜택 자동 적용
        (적용이 안되면 본 메시지를 통째로 복사해서 SweepPic앱 > 설정 > 초대코드입력에 붙여넣기 해주세요)

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

        // 일반 String으로 전달 — 카카오톡 등 서드파티 앱 호환성 보장
        let activityVC = UIActivityViewController(
            activityItems: [message],
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

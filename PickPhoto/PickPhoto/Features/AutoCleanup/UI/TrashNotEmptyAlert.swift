//
//  TrashNotEmptyAlert.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-23.
//
//  휴지통 비어있지 않음 알림
//  - 정리 시작 전 휴지통이 비어있지 않으면 표시
//  - [휴지통 비우기] [취소] 버튼 제공
//

import UIKit

// MARK: - TrashNotEmptyAlertDelegate

/// 휴지통 비어있지 않음 알림 델리게이트
protocol TrashNotEmptyAlertDelegate: AnyObject {
    /// 휴지통 비우기 버튼 탭
    func trashNotEmptyAlertDidTapEmptyTrash()

    /// 취소 버튼 탭
    func trashNotEmptyAlertDidTapCancel()

    /// 휴지통 보기 버튼 탭
    func trashNotEmptyAlertDidTapViewTrash()
}

// MARK: - TrashNotEmptyAlert

/// 휴지통 비어있지 않음 알림
///
/// 정리 시작 전 휴지통이 비어있지 않으면 이 알림을 표시합니다.
final class TrashNotEmptyAlert {

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: TrashNotEmptyAlertDelegate?

    // MARK: - Presentation

    /// 알림 표시
    /// - Parameters:
    ///   - trashCount: 휴지통에 있는 사진 수
    ///   - viewController: 표시할 ViewController
    func show(trashCount: Int, from viewController: UIViewController) {
        let message = """
        휴지통에 \(trashCount)장의 사진이 있습니다.
        정리를 시작하려면 휴지통을 먼저 비워주세요.
        """

        let alert = UIAlertController(
            title: "휴지통을 비워주세요",
            message: message,
            preferredStyle: .alert
        )

        // 휴지통 보기 버튼
        alert.addAction(UIAlertAction(
            title: "휴지통 보기",
            style: .default
        ) { [weak self] _ in
            self?.delegate?.trashNotEmptyAlertDidTapViewTrash()
        })

        // 취소 버튼
        alert.addAction(UIAlertAction(
            title: "취소",
            style: .cancel
        ) { [weak self] _ in
            self?.delegate?.trashNotEmptyAlertDidTapCancel()
        })

        viewController.present(alert, animated: true)
    }
}

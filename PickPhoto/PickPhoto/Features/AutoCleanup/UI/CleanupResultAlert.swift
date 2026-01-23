//
//  CleanupResultAlert.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-23.
//
//  결과 알림 (Alert)
//  - N장 이동: "N장의 정리할 사진을 휴지통으로 이동했습니다" + [확인] [휴지통 보기]
//  - 0장 발견: "정리할 사진을 찾지 못했습니다" + [확인]
//  - 취소: 알림 없음 (즉시 종료)
//

import UIKit

// MARK: - CleanupResultAlertDelegate

/// 결과 알림 델리게이트
protocol CleanupResultAlertDelegate: AnyObject {
    /// 확인 버튼 탭
    func cleanupResultAlertDidTapConfirm()

    /// 휴지통 보기 버튼 탭
    func cleanupResultAlertDidTapViewTrash()
}

// MARK: - CleanupResultAlert

/// 정리 결과 알림
///
/// 정리 완료 후 결과를 Alert으로 표시합니다.
final class CleanupResultAlert {

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: CleanupResultAlertDelegate?

    // MARK: - Presentation

    /// 결과 알림 표시
    /// - Parameters:
    ///   - result: 정리 결과
    ///   - viewController: 표시할 ViewController
    func show(result: CleanupResult, from viewController: UIViewController) {
        // 취소된 경우 알림 없음
        if case .cancelled = result.resultType {
            return
        }

        let alert: UIAlertController

        if result.trashedAssetIDs.count > 0 {
            // N장 이동
            alert = createSuccessAlert(count: result.trashedAssetIDs.count)
        } else {
            // 0장 발견
            alert = createNoneFoundAlert()
        }

        viewController.present(alert, animated: true)
    }

    /// 에러 알림 표시
    /// - Parameters:
    ///   - error: 에러
    ///   - viewController: 표시할 ViewController
    func showError(_ error: CleanupError, from viewController: UIViewController) {
        let alert = UIAlertController(
            title: "정리 실패",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: "확인",
            style: .default
        ) { [weak self] _ in
            self?.delegate?.cleanupResultAlertDidTapConfirm()
        })

        viewController.present(alert, animated: true)
    }

    // MARK: - Private Methods

    /// 성공 알림 생성 (N장 이동)
    private func createSuccessAlert(count: Int) -> UIAlertController {
        let message = CleanupConstants.resultMessage(count: count)

        let alert = UIAlertController(
            title: "정리 완료",
            message: message,
            preferredStyle: .alert
        )

        // 확인 버튼
        alert.addAction(UIAlertAction(
            title: "확인",
            style: .default
        ) { [weak self] _ in
            self?.delegate?.cleanupResultAlertDidTapConfirm()
        })

        // 휴지통 보기 버튼
        alert.addAction(UIAlertAction(
            title: "휴지통 보기",
            style: .default
        ) { [weak self] _ in
            self?.delegate?.cleanupResultAlertDidTapViewTrash()
        })

        return alert
    }

    /// 0장 발견 알림 생성
    private func createNoneFoundAlert() -> UIAlertController {
        let alert = UIAlertController(
            title: "정리 완료",
            message: CleanupConstants.noneFoundMessage,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(
            title: "확인",
            style: .default
        ) { [weak self] _ in
            self?.delegate?.cleanupResultAlertDidTapConfirm()
        })

        return alert
    }
}

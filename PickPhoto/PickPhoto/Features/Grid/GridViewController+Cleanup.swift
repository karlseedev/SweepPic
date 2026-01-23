//
//  GridViewController+Cleanup.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-23.
//
//  GridViewController 정리 기능 확장
//  - 정리 버튼 추가 (네비게이션 바)
//  - 정리 플로우 관리
//  - 휴지통 비어있는지 확인
//

import UIKit
import AppCore

// MARK: - Cleanup Support

extension GridViewController {

    // MARK: - Constants

    /// 정리 버튼 활성화 여부 확인 인터벌 (초)
    private static let cleanupButtonUpdateInterval: TimeInterval = 1.0

    // MARK: - Cleanup Button Setup

    /// 정리 버튼 설정
    ///
    /// viewDidLoad 이후에 호출해야 합니다.
    /// iOS 버전에 따라 시스템 네비바 또는 FloatingUI에 버튼을 추가합니다.
    func setupCleanupButton() {
        if #available(iOS 26.0, *) {
            setupSystemCleanupButton()
        } else {
            setupFloatingCleanupButton()
        }
    }

    /// iOS 26+ 시스템 네비바에 정리 버튼 추가
    @available(iOS 26.0, *)
    private func setupSystemCleanupButton() {
        let cleanupItem = UIBarButtonItem(
            title: "정리",
            style: .plain,
            target: self,
            action: #selector(cleanupButtonTapped)
        )
        cleanupItem.tintColor = .systemBlue

        let selectItem = UIBarButtonItem(
            title: "Select",
            style: .plain,
            target: self,
            action: #selector(selectButtonTapped)
        )
        selectItem.tintColor = .systemBlue

        // [Select] [정리] 순서
        navigationItem.rightBarButtonItems = [selectItem, cleanupItem]

        // 버튼 활성화 상태 초기화
        updateCleanupButtonState()
    }

    /// iOS 16~25 FloatingUI에 정리 버튼 추가
    func setupFloatingCleanupButton() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        // 기존 Select 버튼 대신 [Select] [정리] 두 개 버튼으로 변경
        overlay.titleBar.setTwoRightButtons(
            firstTitle: "Select",
            firstColor: .systemBlue,
            firstAction: { [weak self] in
                self?.selectButtonTapped()
            },
            secondTitle: "정리",
            secondColor: .systemBlue,
            secondAction: { [weak self] in
                self?.cleanupButtonTapped()
            }
        )

        // 버튼 활성화 상태 초기화
        updateCleanupButtonState()
    }

    /// 정리 버튼 활성화 상태 업데이트
    ///
    /// 사진이 있을 때만 버튼 활성화
    func updateCleanupButtonState() {
        let hasPhotos = gridDataSource.assetCount > 0

        if #available(iOS 26.0, *) {
            // 시스템 네비바: rightBarButtonItems의 두 번째가 정리 버튼
            if let items = navigationItem.rightBarButtonItems, items.count >= 2 {
                items[0].isEnabled = hasPhotos  // Select
                items[1].isEnabled = hasPhotos  // 정리
            }
        } else {
            // FloatingUI
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else {
                return
            }
            overlay.titleBar.setTwoRightButtonsEnabled(
                firstEnabled: hasPhotos,
                secondEnabled: hasPhotos
            )
        }
    }

    // MARK: - Cleanup Actions

    /// 정리 버튼 탭 핸들러
    @objc func cleanupButtonTapped() {
        // 1. 휴지통 비어있는지 확인
        let cleanupService = CleanupService.shared

        if !cleanupService.isTrashEmpty() {
            // 휴지통이 비어있지 않음 - 알림 표시
            showTrashNotEmptyAlert()
            return
        }

        // 2. 정리 방식 선택 시트 표시
        showCleanupMethodSheet()
    }

    /// 휴지통 비어있지 않음 알림 표시
    private func showTrashNotEmptyAlert() {
        let trashCount = trashStore.trashedCount
        let alert = TrashNotEmptyAlert()
        alert.delegate = self
        alert.show(trashCount: trashCount, from: self)
    }

    /// 정리 방식 선택 시트 표시
    private func showCleanupMethodSheet() {
        let lastSession = CleanupService.shared.lastSession
        let sheet = CleanupMethodSheet(lastSession: lastSession)
        sheet.delegate = self
        sheet.present(from: self)
    }

    /// 정리 시작
    /// - Parameter method: 정리 방식
    func startCleanup(with method: CleanupMethod) {
        // 진행 뷰 표시
        let progressView = CleanupProgressView()
        progressView.delegate = self
        progressView.configure(method: method)
        progressView.show(in: view)

        // 정리 서비스 실행
        Task {
            do {
                let result = try await CleanupService.shared.startCleanup(
                    method: method,
                    mode: JudgmentMode.precision,
                    progressHandler: { [weak progressView] progress in
                        progressView?.update(with: progress)
                    }
                )

                await MainActor.run {
                    progressView.hide { [weak self] in
                        self?.showCleanupResult(result)
                    }
                }
            } catch let error as CleanupError {
                await MainActor.run {
                    progressView.hide { [weak self] in
                        self?.showCleanupError(error)
                    }
                }
            } catch {
                await MainActor.run {
                    progressView.hide { [weak self] in
                        self?.showCleanupError(.analysisFailed(error.localizedDescription))
                    }
                }
            }
        }
    }

    /// 정리 결과 표시
    private func showCleanupResult(_ result: CleanupResult) {
        let alert = CleanupResultAlert()
        alert.delegate = self
        alert.show(result: result, from: self)
    }

    /// 정리 에러 표시
    private func showCleanupError(_ error: CleanupError) {
        let alert = CleanupResultAlert()
        alert.delegate = self
        alert.showError(error, from: self)
    }

    /// 휴지통 화면으로 이동
    func navigateToTrash() {
        guard let tabBarController = tabBarController as? TabBarController else {
            return
        }

        // Albums 탭으로 전환 후 휴지통 push
        tabBarController.selectedIndex = 1  // Albums 탭

        // Albums 탭의 네비게이션 컨트롤러 찾기
        if let albumsNav = tabBarController.viewControllers?[1] as? UINavigationController {
            // 휴지통 VC push
            let trashVC = TrashAlbumViewController()
            albumsNav.pushViewController(trashVC, animated: true)
        }
    }
}

// MARK: - CleanupMethodSheetDelegate

extension GridViewController: CleanupMethodSheetDelegate {

    func cleanupMethodSheet(_ sheet: CleanupMethodSheet, didSelect method: CleanupMethod) {
        startCleanup(with: method)
    }

    func cleanupMethodSheetDidCancel(_ sheet: CleanupMethodSheet) {
        // 아무 동작 없음
    }
}

// MARK: - CleanupProgressViewDelegate

extension GridViewController: CleanupProgressViewDelegate {

    func cleanupProgressViewDidTapCancel(_ view: CleanupProgressView) {
        // 정리 취소
        CleanupService.shared.cancelCleanup()

        // 진행 뷰 숨김
        view.hide()
    }
}

// MARK: - CleanupResultAlertDelegate

extension GridViewController: CleanupResultAlertDelegate {

    func cleanupResultAlertDidTapConfirm() {
        // 아무 동작 없음
    }

    func cleanupResultAlertDidTapViewTrash() {
        navigateToTrash()
    }
}

// MARK: - TrashNotEmptyAlertDelegate

extension GridViewController: TrashNotEmptyAlertDelegate {

    func trashNotEmptyAlertDidTapEmptyTrash() {
        // 휴지통 비우기 - 휴지통 화면에서 처리하도록 이동
        navigateToTrash()
    }

    func trashNotEmptyAlertDidTapCancel() {
        // 아무 동작 없음
    }

    func trashNotEmptyAlertDidTapViewTrash() {
        navigateToTrash()
    }
}

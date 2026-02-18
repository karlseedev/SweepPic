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
            title: "선택",
            style: .plain,
            target: self,
            action: #selector(selectButtonTapped)
        )
        // 전체 메뉴 버튼 (최우측, 탭 시 풀다운 메뉴)
        let menuItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            menu: UIMenu(children: [
                UIAction(title: "자동정리", image: UIImage(systemName: "wand.and.stars")) { _ in },
                UIAction(title: "사용자", image: UIImage(systemName: "person.circle")) { _ in },
                UIAction(title: "구독", image: UIImage(systemName: "creditcard")) { _ in },
                UIAction(title: "기타", image: UIImage(systemName: "ellipsis")) { _ in },
                UIAction(title: "고객센터", image: UIImage(systemName: "questionmark.circle")) { _ in },
            ])
        )

        // [정리] [선택] [메뉴] 순서 (배열 첫 번째가 최우측)
        navigationItem.rightBarButtonItems = [menuItem, selectItem, cleanupItem]

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
            firstTitle: "선택",
            firstColor: .white,
            firstAction: { [weak self] in
                self?.selectButtonTapped()
            },
            secondTitle: "정리",
            secondColor: UIColor(red: 0, green: 200/255, blue: 1.0, alpha: 1.0),  // #00C8FF
            secondAction: { [weak self] in
                self?.cleanupButtonTapped()
            }
        )

        // 메뉴 버튼 (최우측, 풀다운 메뉴)
        overlay.titleBar.showMenuButton(menu: UIMenu(children: [
            UIAction(title: "자동정리", image: UIImage(systemName: "wand.and.stars")) { _ in },
            UIAction(title: "사용자", image: UIImage(systemName: "person.circle")) { _ in },
            UIAction(title: "구독", image: UIImage(systemName: "creditcard")) { _ in },
            UIAction(title: "기타", image: UIImage(systemName: "ellipsis")) { _ in },
            UIAction(title: "고객센터", image: UIImage(systemName: "questionmark.circle")) { _ in },
        ]))

        // 버튼 활성화 상태 초기화
        updateCleanupButtonState()
    }

    /// 정리 버튼 활성화 상태 업데이트
    ///
    /// 사진이 있을 때만 버튼 활성화
    func updateCleanupButtonState() {
        let hasPhotos = gridDataSource.assetCount > 0

        if #available(iOS 26.0, *) {
            // 시스템 네비바: [메뉴, 선택, 정리] 순서
            if let items = navigationItem.rightBarButtonItems, items.count >= 3 {
                // items[0] = 메뉴 (항상 활성화)
                items[1].isEnabled = hasPhotos  // 선택
                items[2].isEnabled = hasPhotos  // 정리
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
        // [Analytics] 정리 흐름 추적 시작
        cleanupTracker = CleanupFlowTracker()

        // 1. 휴지통 비어있는지 확인
        if !CleanupService.shared.isTrashEmpty() {
            cleanupTracker?.trashWarningShown = true
            showTrashNotEmptyAlert()
            return
        }

        // 2. 정리 방식 선택 시트 표시
        showCleanupMethodSheet()
    }

    // MARK: - Alerts (직접 UIAlertController 사용)

    /// 휴지통 비어있지 않음 알림 표시
    private func showTrashNotEmptyAlert() {
        let alert = UIAlertController(
            title: "저품질 사진 자동 정리",
            message: "저품질 사진 정리 기능을 사용하려면\n휴지통을 먼저 비워주세요",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "휴지통 보기", style: .default) { [weak self] _ in
            // [Analytics] 휴지통 경고에서 이탈 (휴지통 보기)
            self?.cleanupTracker?.reachedStage = .trashWarningExit
            self?.sendCleanupTrackerAndClear()
            self?.navigateToTrash()
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            // [Analytics] 휴지통 경고에서 이탈 (취소)
            self?.cleanupTracker?.reachedStage = .trashWarningExit
            self?.sendCleanupTrackerAndClear()
        })

        present(alert, animated: true)
    }

    /// 정리 방식 선택 시트 표시
    private func showCleanupMethodSheet() {
        let sheet = CleanupMethodSheet()
        sheet.delegate = self
        sheet.present(from: self)
    }

    /// 정리 에러 표시
    private func showCleanupError(_ error: CleanupError) {
        let alert = UIAlertController(
            title: "정리 실패",
            message: error.localizedDescription,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "확인", style: .default))

        present(alert, animated: true)
    }

    /// 휴지통 화면으로 이동
    private func navigateToTrash() {
        guard let tabBarController = tabBarController as? TabBarController else {
            return
        }
        tabBarController.selectedIndex = 2
        tabBarController.floatingOverlay?.selectedTabIndex = 2
    }
}

// MARK: - CleanupMethodSheetDelegate

extension GridViewController: CleanupMethodSheetDelegate {

    func cleanupMethodSheet(_ sheet: CleanupMethodSheet, didSelect method: CleanupMethod) {
        // [Analytics] 방식 선택 기록
        cleanupTracker?.reachedStage = .methodSelected
        cleanupTracker?.method = mapCleanupMethod(method)

        // 모든 정리 방식에서 미리보기 그리드 사용
        startPreviewCleanup(method: method)
    }

    func cleanupMethodSheetDidCancel(_ sheet: CleanupMethodSheet) {
        // [Analytics] 방식 선택 없이 이탈
        sendCleanupTrackerAndClear()
    }
}

// MARK: - CleanupProgressViewDelegate

extension GridViewController: CleanupProgressViewDelegate {

    func cleanupProgressViewDidTapCancel(_ view: CleanupProgressView) {
        // 미리보기 서비스가 실행 중이면 그것을 취소, 아니면 기존 서비스 취소
        if let previewService = previewService {
            previewService.cancel()
            self.previewService = nil
        } else {
            CleanupService.shared.cancelCleanup()
        }

        // [Analytics] 분석 취소
        cleanupTracker?.result = .cancelled
        sendCleanupTrackerAndClear()

        view.hide()
    }
}

// MARK: - Preview Cleanup (미리보기 정리)

extension GridViewController {

    /// 미리보기 분석 서비스 (취소 접근용, 프로퍼티로 보관)
    ///
    /// `private(set)` stored property는 extension에서 선언 불가하므로
    /// `objc_getAssociatedObject`로 구현합니다.
    var previewService: CleanupPreviewService? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.previewService) as? CleanupPreviewService
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.previewService, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
    }

    /// Associated object 키
    private enum AssociatedKeys {
        static var previewService: UInt8 = 0
        static var cleanupTracker: UInt8 = 0
    }

    // MARK: - Cleanup Flow Tracker (이벤트 7-1)

    /// 정리 흐름 추적기 — 버튼 탭부터 최종 이탈까지의 퍼널 데이터 수집
    private class CleanupFlowTracker {
        let startTime = CFAbsoluteTimeGetCurrent()
        var reachedStage: CleanupReachedStage = .buttonTapped
        var trashWarningShown = false
        var method: CleanupMethodType?
        var result: AnalyticsCleanupResult?
        var foundCount = 0
        var cancelProgress: Float?
        var resultAction: CleanupResultAction?

        /// 수집된 데이터를 CleanupEventData로 빌드
        func buildEventData() -> CleanupEventData {
            CleanupEventData(
                reachedStage: reachedStage,
                trashWarningShown: trashWarningShown,
                method: method,
                result: result,
                foundCount: foundCount,
                durationSec: CFAbsoluteTimeGetCurrent() - startTime,
                cancelProgress: cancelProgress,
                resultAction: resultAction
            )
        }
    }

    /// 정리 흐름 추적기 (associated object)
    private var cleanupTracker: CleanupFlowTracker? {
        get { objc_getAssociatedObject(self, &AssociatedKeys.cleanupTracker) as? CleanupFlowTracker }
        set { objc_setAssociatedObject(self, &AssociatedKeys.cleanupTracker, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// 추적기 전송 후 해제
    private func sendCleanupTrackerAndClear() {
        guard let tracker = cleanupTracker else { return }
        AnalyticsService.shared.trackCleanupCompleted(data: tracker.buildEventData())
        cleanupTracker = nil
    }

    /// CleanupMethod → CleanupMethodType 변환
    private func mapCleanupMethod(_ method: CleanupMethod) -> CleanupMethodType {
        switch method {
        case .fromLatest:        return .fromLatest
        case .continueFromLast:  return .continueFromLast
        case .byYear:            return .byYear
        }
    }

    /// 미리보기 정리 시작
    ///
    /// 모든 정리 방식(fromLatest, continueFromLast, byYear)에서 공통으로 사용.
    /// 1. CleanupProgressView 표시
    /// 2. CleanupPreviewService 실행 (분석만, 이동 없음)
    /// 3. 결과 → PreviewGridViewController push
    ///
    /// - Parameter method: 정리 방식
    func startPreviewCleanup(method: CleanupMethod) {
        // 1. 진행 뷰 표시
        let progressView = CleanupProgressView()
        progressView.delegate = self
        progressView.configure(method: method)
        progressView.show(in: view)

        // 2. 서비스 생성 및 보관 (취소 접근용)
        let service = CleanupPreviewService()
        self.previewService = service

        // [Analytics] 분석 시작 시간 기록
        let analysisStartTime = CFAbsoluteTimeGetCurrent()

        // 3. 분석 실행
        Task {
            do {
                let result = try await service.analyze(
                    method: method,
                    progressHandler: { progress in
                        progressView.update(with: progress)
                    }
                )

                // [Analytics] 분석 소요 시간 계산
                let analysisDuration = CFAbsoluteTimeGetCurrent() - analysisStartTime

                await MainActor.run { [weak self] in
                    self?.previewService = nil
                    progressView.hide {
                        if result.totalCount > 0 {
                            // [Analytics] 발견 수 기록
                            self?.cleanupTracker?.foundCount = result.totalCount

                            // 미리보기 그리드 push
                            let previewVC = PreviewGridViewController(previewResult: result)
                            previewVC.analysisDuration = analysisDuration  // [Analytics]
                            previewVC.delegate = self

                            // [Analytics] 이벤트 7-1: 미리보기 흐름 완료 콜백
                            previewVC.onFlowComplete = { [weak self] movedCount in
                                if movedCount > 0 {
                                    self?.cleanupTracker?.reachedStage = .cleanupDone
                                    self?.cleanupTracker?.result = .completed
                                    self?.cleanupTracker?.foundCount = movedCount
                                }
                                self?.sendCleanupTrackerAndClear()
                            }

                            self?.navigationController?.pushViewController(previewVC, animated: true)
                        } else {
                            // [Analytics] 결과 없음
                            self?.cleanupTracker?.result = .noneFound
                            self?.sendCleanupTrackerAndClear()

                            self?.showNoPreviewResultAlert(method: method)
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.previewService = nil
                    progressView.hide {
                        // 취소(CancellationError)면 에러 표시 안 함
                        // (취소는 cleanupProgressViewDidTapCancel에서 이미 추적됨)
                        if error is CancellationError { return }

                        // [Analytics] 분석 에러로 이탈
                        self?.cleanupTracker?.result = .cancelled
                        self?.sendCleanupTrackerAndClear()

                        self?.showCleanupError(.analysisFailed(error.localizedDescription))
                    }
                }
            }
        }
    }

    /// 미리보기 결과 없음 알림
    /// - Parameter method: 정리 방식 (byYear인 경우 연도 표시)
    private func showNoPreviewResultAlert(method: CleanupMethod) {
        let message: String
        if case .byYear(let year, _) = method {
            message = "\(year)년에서 정리할 저품질 사진을 찾지 못했습니다."
        } else {
            message = "정리할 저품질 사진을 찾지 못했습니다."
        }

        let alert = UIAlertController(
            title: "정리할 사진 없음",
            message: message,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "확인", style: .default))
        present(alert, animated: true)
    }
}

// MARK: - PreviewGridViewControllerDelegate

extension GridViewController: PreviewGridViewControllerDelegate {

    func previewGridVC(_ vc: PreviewGridViewController, didConfirmCleanup assetIDs: [String]) {
        // 휴지통으로 이동
        trashStore.moveToTrash(assetIDs: assetIDs)

        // 완료 토스트 표시
        Log.print("[PreviewCleanup] \(assetIDs.count)장 휴지통 이동 완료")
    }
}


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
        // 1. 휴지통 비어있는지 확인 (DEBUG에서는 스킵)
        #if !DEBUG
        if !CleanupService.shared.isTrashEmpty() {
            showTrashNotEmptyAlert()
            return
        }
        #endif

        // 2. 정리 방식 선택 시트 표시
        showCleanupMethodSheet()
    }

    // MARK: - Alerts (직접 UIAlertController 사용)

    /// 휴지통 비어있지 않음 알림 표시
    private func showTrashNotEmptyAlert() {
        let trashCount = trashStore.trashedCount
        let message = "휴지통에 \(trashCount)장의 사진이 있습니다.\n정리를 시작하려면 휴지통을 먼저 비워주세요."

        let alert = UIAlertController(
            title: "휴지통을 비워주세요",
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "휴지통 보기", style: .default) { [weak self] _ in
            self?.navigateToTrash()
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel))

        present(alert, animated: true)
    }

    /// 정리 방식 선택 시트 표시
    private func showCleanupMethodSheet() {
        let sessionStore = CleanupSessionStore.shared
        let sheet = CleanupMethodSheet(
            latestSession: sessionStore.latestSession,
            byYearSession: sessionStore.byYearSession
        )
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
                        self?.showCleanupResult(result, method: method)
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
    ///
    /// EndReason과 발견 수에 따라 적절한 메시지 표시
    /// - Parameters:
    ///   - result: 정리 결과
    ///   - method: 정리 방식 (연도별인 경우 연도 표시용)
    private func showCleanupResult(_ result: CleanupResult, method: CleanupMethod) {
        // 취소된 경우 알림 없음
        if case .cancelled = result.resultType {
            return
        }

        let title = "정리 완료"
        let message = CleanupConstants.resultMessage(
            endReason: result.endReason,
            foundCount: result.foundCount,
            method: method
        )
        let showTrashButton = result.trashedAssetIDs.count > 0

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: "확인", style: .default))

        if showTrashButton {
            alert.addAction(UIAlertAction(title: "휴지통 보기", style: .default) { [weak self] _ in
                self?.navigateToTrash()
            })
        }

        present(alert, animated: true)
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
        switch method {
        case .fromLatest:
            // 미리보기 정리 (처음부터)
            startPreviewCleanup(continueFromLast: false)
        case .continueFromLast:
            // 미리보기 정리 (이어서)
            startPreviewCleanup(continueFromLast: true)
        case .byYear:
            // 연도별은 기존 즉시 정리 흐름 유지
            startCleanup(with: method)
        }
    }

    func cleanupMethodSheetDidCancel(_ sheet: CleanupMethodSheet) {
        // 아무 동작 없음
    }

    #if DEBUG
    /// 통합 로직 테스트 선택됨 (DEBUG 전용)
    @available(iOS 18.0, *)
    func cleanupMethodSheetDidSelectIntegratedTest(_ sheet: CleanupMethodSheet, continueFromLast: Bool) {
        startIntegratedLogicTest(continueFromLast: continueFromLast)
    }

    /// 3모드 비교 테스트 선택됨 (DEBUG 전용)
    @available(iOS 18.0, *)
    func cleanupMethodSheetDidSelectModeTest(_ sheet: CleanupMethodSheet, continueFromLast: Bool) {
        startModeComparisonTest(continueFromLast: continueFromLast)
    }
    #endif
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
        static var previewService = "previewService"
    }

    /// 미리보기 정리 시작
    ///
    /// 1. CleanupProgressView 표시
    /// 2. CleanupPreviewService 실행 (분석만, 이동 없음)
    /// 3. 결과 → PreviewGridViewController push
    ///
    /// - Parameter continueFromLast: true면 이어서 정리
    func startPreviewCleanup(continueFromLast: Bool) {
        // 1. 진행 뷰 표시
        let progressView = CleanupProgressView()
        progressView.delegate = self
        progressView.configure(method: continueFromLast ? .continueFromLast : .fromLatest)
        progressView.show(in: view)

        // 2. 서비스 생성 및 보관 (취소 접근용)
        let service = CleanupPreviewService()
        self.previewService = service

        // 3. 분석 실행
        Task {
            do {
                let result = try await service.analyze(
                    method: continueFromLast ? .continueFromLast : .fromLatest,
                    progressHandler: { progress in
                        progressView.update(with: progress)
                    }
                )

                await MainActor.run { [weak self] in
                    self?.previewService = nil
                    progressView.hide {
                        if result.totalCount > 0 {
                            // 미리보기 그리드 push
                            let previewVC = PreviewGridViewController(previewResult: result)
                            previewVC.delegate = self
                            self?.navigationController?.pushViewController(previewVC, animated: true)
                        } else {
                            // 결과 없음
                            self?.showNoPreviewResultAlert()
                        }
                    }
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.previewService = nil
                    progressView.hide {
                        // 취소(CancellationError)면 에러 표시 안 함
                        if error is CancellationError { return }
                        self?.showCleanupError(.analysisFailed(error.localizedDescription))
                    }
                }
            }
        }
    }

    /// 미리보기 결과 없음 알림
    private func showNoPreviewResultAlert() {
        let alert = UIAlertController(
            title: "정리할 사진 없음",
            message: "정리할 저품질 사진을 찾지 못했습니다.",
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

// MARK: - DEBUG: 통합 로직 테스트

#if DEBUG
extension GridViewController {

    /// 통합 로직 테스트 시작 (DEBUG 전용)
    ///
    /// 경로1 (기존 로직 기반) + 경로2 (AestheticsScore 기반) 테스트
    /// 결과를 카테고리별로 분류하여 휴지통에 저장
    /// - ⚪ 회색: 경로1 + 경로2 둘 다 해당
    /// - 🔵 파랑: 경로1만 해당 (기존 로직 기반)
    /// - 🟡 노랑: 경로2만 해당 (AestheticsScore 기반)
    ///
    /// - Parameter continueFromLast: true면 이어서 테스트
    @available(iOS 18.0, *)
    func startIntegratedLogicTest(continueFromLast: Bool) {
        let tester = CompareAnalysisTester.shared

        // 진행 Alert 생성
        let titleText = continueFromLast ? "이어서 테스트" : "통합 로직 테스트"
        let progressAlert = UIAlertController(
            title: titleText,
            message: "검색: 0장\n⚪ 둘다: 0  🔵 경로1: 0  🟡 경로2: 0",
            preferredStyle: .alert
        )

        present(progressAlert, animated: true)

        // 테스트 실행
        Task {
            let result = await tester.runTest(continueFromLast: continueFromLast) { scanned, both, path1Only, path2Only in
                // 진행 상황 업데이트 (메인 스레드)
                Task { @MainActor in
                    progressAlert.message = """
                    검색: \(scanned)장
                    ⚪ 둘다: \(both)  🔵 경로1: \(path1Only)  🟡 경로2: \(path2Only)
                    """
                }
            }

            // 결과 표시 (메인 스레드)
            await MainActor.run {
                progressAlert.dismiss(animated: true) { [weak self] in
                    self?.showIntegratedLogicResult(result, continueFromLast: continueFromLast)
                }
            }
        }
    }

    /// 통합 로직 테스트 결과 표시
    /// - Parameters:
    ///   - result: 테스트 결과
    ///   - continueFromLast: 이어서 테스트 여부 (누적 정보 표시용)
    @available(iOS 18.0, *)
    private func showIntegratedLogicResult(_ result: CompareAnalysisResult, continueFromLast: Bool) {
        let tester = CompareAnalysisTester.shared
        let titleText = continueFromLast ? "이어서 테스트 완료" : "통합 로직 테스트 완료"

        var message = """
        이번 검색: \(result.totalScanned)장

        ⚪ 둘 다 해당: \(result.bothCount)장
        🔵 경로1만 (기존 로직): \(result.path1OnlyCount)장
        🟡 경로2만 (AestheticsScore): \(result.path2OnlyCount)장

        이번 휴지통: \(result.totalTrashed)장
        """

        // 누적 정보 표시
        message += "\n\n--- 누적 ---"
        message += "\n총 검색: \(tester.totalScannedCount)장"
        message += "\n총 휴지통: \(tester.totalTrashedCount)장"

        if let lastDate = tester.lastTestDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy년 M월"
            message += "\n(\(formatter.string(from: lastDate)) 이전까지)"
        }

        let alert = UIAlertController(
            title: titleText,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "확인", style: .default))

        if result.totalTrashed > 0 {
            alert.addAction(UIAlertAction(title: "휴지통 보기", style: .default) { [weak self] _ in
                self?.navigateToTrash()
            })
        }

        present(alert, animated: true)
    }
}
#endif

// MARK: - DEBUG: 3모드 비교 테스트

#if DEBUG
extension GridViewController {

    /// 3모드 비교 테스트 시작 (DEBUG 전용)
    ///
    /// 완화/기본/강화 모드를 동시에 평가하여 딱지로 구별
    /// - ⚪ 회색: 3모드 전부 잡음
    /// - 🔵 파랑: 기본+강화만 잡음
    /// - 🟡 노랑: 강화만 잡음
    ///
    /// - Parameter continueFromLast: true면 이어서 테스트
    @available(iOS 18.0, *)
    func startModeComparisonTest(continueFromLast: Bool) {
        let tester = ModeComparisonTester.shared

        // 진행 Alert 생성
        let titleText = continueFromLast ? "3모드 이어서 테스트" : "3모드 비교 테스트"
        let progressAlert = UIAlertController(
            title: titleText,
            message: "검색: 0장\n⚪ 전체: 0  🔵 기본↑: 0  🟡 강화만: 0",
            preferredStyle: .alert
        )

        present(progressAlert, animated: true)

        // 테스트 실행
        Task {
            let result = await tester.runTest(continueFromLast: continueFromLast) { scanned, allModes, standardUp, deepOnly in
                // 진행 상황 업데이트 (메인 스레드)
                Task { @MainActor in
                    progressAlert.message = """
                    검색: \(scanned)장
                    ⚪ 전체: \(allModes)  🔵 기본↑: \(standardUp)  🟡 강화만: \(deepOnly)
                    """
                }
            }

            // 결과 표시 (메인 스레드)
            await MainActor.run {
                progressAlert.dismiss(animated: true) { [weak self] in
                    self?.showModeComparisonResult(result, continueFromLast: continueFromLast)
                }
            }
        }
    }

    /// 3모드 비교 테스트 결과 표시
    /// - Parameters:
    ///   - result: 테스트 결과
    ///   - continueFromLast: 이어서 테스트 여부 (누적 정보 표시용)
    @available(iOS 18.0, *)
    private func showModeComparisonResult(_ result: ModeComparisonResult, continueFromLast: Bool) {
        let tester = ModeComparisonTester.shared
        let titleText = continueFromLast ? "3모드 이어서 완료" : "3모드 비교 테스트 완료"

        var message = """
        이번 검색: \(result.totalScanned)장

        ⚪ 전체 모드: \(result.allModesCount)장
        🔵 기본+강화: \(result.standardUpCount)장
        🟡 강화만: \(result.deepOnlyCount)장

        이번 휴지통: \(result.totalTrashed)장
        """

        // 누적 정보 표시
        message += "\n\n--- 누적 ---"
        message += "\n총 검색: \(tester.totalScannedCount)장"
        message += "\n총 휴지통: \(tester.totalTrashedCount)장"

        if let lastDate = tester.lastTestDate {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy년 M월"
            message += "\n(\(formatter.string(from: lastDate)) 이전까지)"
        }

        let alert = UIAlertController(
            title: titleText,
            message: message,
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "확인", style: .default))

        if result.totalTrashed > 0 {
            alert.addAction(UIAlertAction(title: "휴지통 보기", style: .default) { [weak self] _ in
                self?.navigateToTrash()
            })
        }

        present(alert, animated: true)
    }
}
#endif

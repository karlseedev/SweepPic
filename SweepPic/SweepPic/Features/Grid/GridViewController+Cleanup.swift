//
//  GridViewController+Cleanup.swift
//  SweepPic
//
//  Created by Claude on 2026-01-23.
//
//  GridViewController 정리 기능 확장
//  - 정리 버튼 추가 (네비게이션 바)
//  - 정리 플로우 관리
//  - 삭제대기함 비어있는지 확인
//

import UIKit
import AppCore
import OSLog

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

        // 선택모드 복귀 후 버튼 재생성 시 C 인터셉트 재설정
        enableCCleanupButtonIntercept()
    }

    /// iOS 26+ 시스템 네비바에 간편정리 + 전체메뉴 버튼 추가
    @available(iOS 26.0, *)
    private func setupSystemCleanupButton() {
        // 간편정리 버튼 — 탭 시 UIMenu 풀다운 (인물사진 비교정리 / 저품질사진 자동정리)
        let cleanupMenuItem = UIBarButtonItem(
            title: "간편정리",
            image: nil,
            primaryAction: nil,
            menu: UIMenu(children: [
                UIAction(title: "인물사진 비교정리",
                         image: UIImage(systemName: "person.2.crop.square.stack")) { [weak self] _ in
                    self?.faceScanButtonTapped()
                },
                UIAction(title: "저품질사진 자동정리",
                         image: UIImage(systemName: "wand.and.stars")) { [weak self] _ in
                    self?.cleanupButtonTapped()
                },
            ])
        )

        // 전체메뉴 버튼 (최우측, 탭 시 풀다운 메뉴)
        // 표준 UIBarButtonItem 사용 — iOS 26 Liquid Glass 스타일 자동 적용
        let menuItem = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis"),
            menu: UIMenu(children: [
                PremiumMenuViewController.makeMenu(from: self),
                ReferralMenuViewController.makeMenu(from: self),
                CustomerServiceViewController.makeMenu(from: self),
                UIAction(title: "사진 선택 모드",
                         image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                    self?.selectButtonTapped()
                },
                self.makeCoachMarkReplayMenu(),
                self.makeDebugResetMenu(),
                self.makeDebugAdTestMenu(),
            ])
        )

        // [간편정리] [전체메뉴] 순서 (배열 첫 번째가 최우측)
        navigationItem.rightBarButtonItems = [menuItem, cleanupMenuItem]

        // 버튼 활성화 상태 초기화
        updateCleanupButtonState()

        // 결제 문제 뱃지 업데이트 (FR-034, T035)
        updatePaymentIssueBadge()
    }

    /// iOS 16~25 FloatingUI에 간편정리 + 전체메뉴 버튼 추가
    func setupFloatingCleanupButton() {
        guard let tabBarController = tabBarController as? TabBarController,
              let overlay = tabBarController.floatingOverlay else {
            return
        }

        // 간편정리 메뉴 버튼 — 탭 시 UIMenu 풀다운
        overlay.titleBar.setRightMenuButton(
            title: "간편정리",
            menu: UIMenu(children: [
                UIAction(title: "인물사진 비교정리",
                         image: UIImage(systemName: "person.2.crop.square.stack")) { [weak self] _ in
                    self?.faceScanButtonTapped()
                },
                UIAction(title: "저품질사진 자동정리",
                         image: UIImage(systemName: "wand.and.stars")) { [weak self] _ in
                    self?.cleanupButtonTapped()
                },
            ])
        )

        // 전체메뉴 버튼 (최우측, 풀다운 메뉴)
        overlay.titleBar.showMenuButton(menu: UIMenu(children: [
            PremiumMenuViewController.makeMenu(from: self),
            ReferralMenuViewController.makeMenu(from: self),
            CustomerServiceViewController.makeMenu(from: self),
            UIAction(title: "사진 선택 모드",
                     image: UIImage(systemName: "checkmark.circle")) { [weak self] _ in
                self?.selectButtonTapped()
            },
            self.makeCoachMarkReplayMenu(),
            self.makeDebugResetMenu(),
            self.makeDebugAdTestMenu(),
        ]))

        // 버튼 활성화 상태 초기화
        updateCleanupButtonState()

        // 결제 문제 뱃지 업데이트 (FR-034, T035)
        updatePaymentIssueBadge()
    }

    // MARK: - Payment Issue Badge (결제 문제 뱃지)

    /// 뱃지 태그 (중복 방지용, FloatingUI 전용)
    private static let paymentBadgeTag = 9901

    /// 결제 문제 시 메뉴 버튼에 뱃지 표시/제거 (FR-034, T035)
    /// - iOS 26+: 공식 UIBarButtonItem.Badge API 사용
    /// - iOS 16~25: FloatingUI menuButton에 커스텀 오버레이
    private func updatePaymentIssueBadge() {
        let hasIssue = SubscriptionStore.shared.state.hasPaymentIssue

        if #available(iOS 26.0, *) {
            // iOS 26+: 공식 Badge API — Liquid Glass 네비바와 자연스럽게 통합
            guard let menuItem = navigationItem.rightBarButtonItems?.first else { return }

            if hasIssue {
                menuItem.badge = .indicator()
            } else {
                menuItem.badge = nil
            }
        } else {
            // FloatingUI: menuButton에 커스텀 ! 뱃지 오버레이
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else { return }

            updateBadgeDot(on: overlay.titleBar.menuButtonView, show: hasIssue)
        }
    }

    /// FloatingUI 전용: 뷰 위에 ! 뱃지 추가/제거
    private func updateBadgeDot(on targetView: UIView, show: Bool) {
        // 기존 뱃지 제거
        targetView.viewWithTag(Self.paymentBadgeTag)?.removeFromSuperview()

        guard show else { return }

        // 빨간 원 + ! 텍스트 뱃지 생성 (16×16pt)
        let badge = UIView()
        badge.tag = Self.paymentBadgeTag
        badge.backgroundColor = .systemRed
        badge.layer.cornerRadius = 8
        badge.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = "!"
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        badge.addSubview(label)

        targetView.addSubview(badge)
        targetView.clipsToBounds = false

        NSLayoutConstraint.activate([
            badge.widthAnchor.constraint(equalToConstant: 16),
            badge.heightAnchor.constraint(equalToConstant: 16),
            badge.topAnchor.constraint(equalTo: targetView.topAnchor, constant: -4),
            badge.trailingAnchor.constraint(equalTo: targetView.trailingAnchor, constant: 4),
            label.centerXAnchor.constraint(equalTo: badge.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: badge.centerYAnchor),
        ])
    }

    /// 구독 상태 변경 감지 등록 (결제 문제 뱃지 업데이트용)
    /// viewDidLoad에서 호출
    func observeSubscriptionStateForBadge() {
        SubscriptionStore.shared.onStateChange { [weak self] _ in
            DispatchQueue.main.async {
                self?.updatePaymentIssueBadge()
            }
        }
    }

    /// 간편정리 버튼 활성화 상태 업데이트
    ///
    /// 사진이 있을 때만 간편정리 버튼 활성화 (전체메뉴는 항상 활성)
    func updateCleanupButtonState() {
        let hasPhotos = gridDataSource.assetCount > 0

        if #available(iOS 26.0, *) {
            // 시스템 네비바: [전체메뉴, 간편정리] 순서
            if let items = navigationItem.rightBarButtonItems, items.count >= 2 {
                // items[0] = 전체메뉴 (항상 활성화)
                items[1].isEnabled = hasPhotos  // 간편정리
            }
        } else {
            // FloatingUI: 간편정리 메뉴 버튼만 활성화/비활성화
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay else {
                return
            }
            overlay.titleBar.setRightMenuButtonEnabled(hasPhotos)
        }
    }

    // MARK: - Navigation/Tab Interaction Lock

    /// 분석 진행 중 상단 버튼/하단 탭 터치 차단
    ///
    /// CleanupProgressView는 GridViewController.view에 추가되므로
    /// 상위 계층(FloatingOverlay, NavigationBar, TabBar)의 터치를 차단할 수 없음.
    /// 직접 비활성화하여 분석 진행 중 의도치 않은 조작을 방지합니다.
    private func disableNavigationAndTabInteraction() {
        if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 네비바 아이템 + 탭바 비활성화
            navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = false }
            tabBarController?.tabBar.isUserInteractionEnabled = false
        } else {
            // iOS 16~25: FloatingOverlay 전체 터치 비활성화
            (tabBarController as? TabBarController)?.floatingOverlay?.isUserInteractionEnabled = false
        }
    }

    /// 분석 종료 후 상단 버튼/하단 탭 터치 복구
    private func enableNavigationAndTabInteraction() {
        if #available(iOS 26.0, *) {
            // iOS 26+: 시스템 네비바 아이템 + 탭바 복구
            navigationItem.rightBarButtonItems?.forEach { $0.isEnabled = true }
            tabBarController?.tabBar.isUserInteractionEnabled = true
        } else {
            // iOS 16~25: FloatingOverlay 터치 복구
            (tabBarController as? TabBarController)?.floatingOverlay?.isUserInteractionEnabled = true
        }
        // 정리/선택 버튼의 enabled 상태를 사진 유무 기준으로 재계산
        updateCleanupButtonState()
    }

    // MARK: - Cleanup Actions

    /// 정리 버튼 탭 핸들러
    @objc func cleanupButtonTapped() {
        // [Analytics] 정리 흐름 추적 시작
        cleanupTracker = CleanupFlowTracker()

        // 1. 삭제대기함 비어있는지 확인 (Pro 멤버십은 제한 해제)
        if !SubscriptionStore.shared.isProUser && !CleanupService.shared.isTrashEmpty() {
            cleanupTracker?.trashWarningShown = true
            showTrashNotEmptyAlert()
            return
        }

        // 2. 정리 방식 선택 시트 표시
        showCleanupMethodSheet()
    }

    // MARK: - Alerts (직접 UIAlertController 사용)

    /// 삭제대기함 비어있지 않음 알림 표시
    private func showTrashNotEmptyAlert() {
        let alert = UIAlertController(
            title: "저품질사진 자동정리",
            message: "저품질 사진 정리 기능을 사용하려면\n삭제대기함을 먼저 비워주세요\n\n-Pro멤버십 가입 시 제한 해제-",
            preferredStyle: .alert
        )

        alert.addAction(UIAlertAction(title: "삭제대기함 보기", style: .default) { [weak self] _ in
            // [Analytics] 삭제대기함 경고에서 이탈 (삭제대기함 보기)
            self?.cleanupTracker?.reachedStage = .trashWarningExit
            self?.sendCleanupTrackerAndClear()
            self?.navigateToTrash()
        })

        alert.addAction(UIAlertAction(title: "취소", style: .cancel) { [weak self] _ in
            // [Analytics] 삭제대기함 경고에서 이탈 (취소)
            self?.cleanupTracker?.reachedStage = .trashWarningExit
            self?.sendCleanupTrackerAndClear()
        })

        present(alert, animated: true)
    }

    /// 정리 방식 선택 시트 표시
    /// D 코치마크의 onConfirm에서도 호출되므로 internal 접근 수준
    func showCleanupMethodSheet() {
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

    /// 삭제대기함 화면으로 이동
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

        // 상단 버튼/하단 탭 터치 복구
        enableNavigationAndTabInteraction()

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
        // tabBarController.view에 추가 → FloatingOverlay/NavBar/TabBar보다 z-order 위에 배치
        let targetView: UIView = tabBarController?.view ?? view
        progressView.show(in: targetView, viewController: self)

        // 상단 버튼/하단 탭 터치 차단 (분석 진행 중 의도치 않은 조작 방지)
        disableNavigationAndTabInteraction()

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
                    // 상단 버튼/하단 탭 터치 복구
                    self?.enableNavigationAndTabInteraction()
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
                                    // [Analytics] 사용자가 확인까지 완료 → resultAction 단계
                                    self?.cleanupTracker?.reachedStage = .resultAction
                                    self?.cleanupTracker?.result = .completed
                                    self?.cleanupTracker?.foundCount = movedCount
                                    self?.cleanupTracker?.resultAction = .confirm

                                    // [BM] 전면 광고 — 자동정리 완료 짝수 회차에만 표시 (FR-015)
                                    // onFlowComplete 시점에는 PreviewGridVC가 화면 최상단이므로
                                    // navigationController의 visibleViewController에서 표시
                                    if AdCounters.shared.incrementAndShouldShowAd(for: .autoCleanupComplete),
                                       let presentingVC = self?.navigationController?.visibleViewController ?? self {
                                        InterstitialAdPresenter.shared.showAd(from: presentingVC) {
                                            // 광고 닫힌 후 정상 진행
                                        }
                                    }
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
                    // 상단 버튼/하단 탭 터치 복구
                    self?.enableNavigationAndTabInteraction()
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

// MARK: - Coach Mark Replay Submenu

extension GridViewController {

    /// "설명 다시 보기" 서브메뉴 생성
    /// 각 항목 탭 시 CoachMarkReplay 확장의 재생 함수를 호출
    func makeCoachMarkReplayMenu() -> UIMenu {
        UIMenu(
            title: "설명 다시 보기",
            image: UIImage(systemName: "arrow.counterclockwise"),
            children: [
                UIAction(title: "목록에서 밀어서 삭제") { [weak self] _ in
                    self?.replayCoachMarkA()
                },
                UIAction(title: "뷰어에서 밀어서 삭제") { [weak self] _ in
                    self?.replayCoachMarkB()
                },
                UIAction(title: "인물사진 비교정리") { [weak self] _ in
                    self?.replayCoachMarkC()
                },
                UIAction(title: "저품질사진 자동정리") { [weak self] _ in
                    self?.replayCoachMarkD()
                },
                UIAction(title: "삭제 시스템 안내") { [weak self] _ in
                    self?.replayCoachMarkE1E2()
                },
                UIAction(title: "비우기 완료 안내") { [weak self] _ in
                    self?.replayCoachMarkE3()
                },
            ]
        )
    }

    /// (테스트) 리셋 서브메뉴 — 한도 리셋 + 구독 리셋
    func makeDebugResetMenu() -> UIMenu {
        let remaining = UsageLimitStore.shared.remainingFreeDeletes
        let total = UsageLimitStore.shared.totalDailyCapacity
        let isProUser = SubscriptionStore.shared.isProUser

        return UIMenu(
            title: "(테스트)리셋",
            image: UIImage(systemName: "arrow.counterclockwise"),
            children: [
                UIAction(title: "한도 리셋 (\(remaining)/\(total))") { [weak self] _ in
                    #if DEBUG
                    UsageLimitStore.shared.debugReset()
                    UserDefaults.standard.removeObject(forKey: "GaugeFirstTooltipShown")
                    Logger.app.debug("GridVC+Cleanup: 디버그 한도 리셋 + 툴팁 플래그 초기화")
                    NotificationCenter.default.post(name: .debugMonetizationStateChanged, object: nil)
                    #endif
                    self?.setupCleanupButton()
                },
                UIAction(title: isProUser ? "구독 리셋 (현재 Pro)" : "구독 리셋 (현재 Free)") { [weak self] _ in
                    #if DEBUG
                    SubscriptionStore.shared.debugResetToFree()
                    Logger.app.debug("GridVC+Cleanup: 디버그 구독 → Free 리셋")
                    NotificationCenter.default.post(name: .debugMonetizationStateChanged, object: nil)
                    #endif
                    self?.setupCleanupButton()
                },
                UIAction(title: "구독 강제 Pro") { [weak self] _ in
                    #if DEBUG
                    SubscriptionStore.shared.debugSetPro()
                    Logger.app.debug("GridVC+Cleanup: 디버그 구독 → Pro 설정")
                    NotificationCenter.default.post(name: .debugMonetizationStateChanged, object: nil)
                    #endif
                    self?.setupCleanupButton()
                },
                UIAction(title: "결제 문제 시뮬레이션 (뱃지 테스트)") { [weak self] _ in
                    #if DEBUG
                    SubscriptionStore.shared.debugSetPaymentIssue()
                    Logger.app.debug("GridVC+Cleanup: 디버그 결제 문제 시뮬레이션")
                    NotificationCenter.default.post(name: .debugMonetizationStateChanged, object: nil)
                    #endif
                    self?.setupCleanupButton()
                },
                UIAction(title: "해지 시뮬레이션 (Exit Survey 테스트)") { [weak self] _ in
                    #if DEBUG
                    // Pro + autoRenewEnabled: false 상태로 설정 (오버라이드 ON → refresh 스킵)
                    SubscriptionStore.shared.debugSimulateCancellation()
                    // 해지 감지 플래그 설정
                    UserDefaults.standard.set(true, forKey: "pendingCancelCheck")
                    UserDefaults.standard.set(true, forKey: "wasAutoRenewing")
                    Logger.app.debug("GridVC+Cleanup: 해지 시뮬레이션 — 백그라운드→포그라운드 복귀 시 Exit Survey 표시")
                    NotificationCenter.default.post(name: .debugMonetizationStateChanged, object: nil)
                    #endif
                    self?.setupCleanupButton()
                    // 토스트로 안내
                    if let window = self?.view.window {
                        ToastView.show("앱을 백그라운드로 보냈다가 복귀하세요", in: window)
                    }
                },
                UIAction(title: "온보딩 리셋") { [weak self] _ in
                    #if DEBUG
                    // 모든 CoachMarkType 리셋 — 신규 설치 상태로 초기화
                    let allTypes: [CoachMarkType] = [
                        .gridSwipeDelete,       // A
                        .viewerSwipeDelete,     // B
                        .similarPhoto,          // C
                        .autoCleanup,           // D
                        .firstDeleteGuide,      // E-1+E-2
                        .firstEmpty,            // E-3
                        .faceComparisonGuide,   // C-3
                    ]
                    allTypes.forEach { $0.resetShown() }
                    // C 사전분석 + D 사전스캔 리셋
                    self?.debugResetCPreScan()
                    CoachMarkDPreScanner.shared.debugReset()
                    // CoachMarkManager 플래그 리셋
                    CoachMarkManager.shared.isAutoPopForC = false
                    CoachMarkManager.shared.pendingCleanupHighlight = false
                    CoachMarkManager.shared.pendingDAfterCComplete = false
                    Logger.coachMark.notice("디버그: 온보딩 전체 초기화 완료 (\(allTypes.count)개 + 사전분석)")
                    #endif
                },
            ]
        )
    }

    /// (테스트) 광고 상태 테스트 메뉴
    /// 리워드 광고 강제 제거(no-fill 시뮬레이션) + 한도 소진 + 상태 확인
    func makeDebugAdTestMenu() -> UIMenu {
        return UIMenu(
            title: "(테스트)광고",
            image: UIImage(systemName: "play.rectangle"),
            children: [
                UIAction(title: "no-fill ON (광고 로드 차단)") { _ in
                    #if DEBUG
                    AdManager.shared.debugClearRewardedAd()
                    #endif
                },
                UIAction(title: "no-fill OFF (정상 복구)") { _ in
                    #if DEBUG
                    AdManager.shared.debugDisableNoFill()
                    #endif
                },
                UIAction(title: "기본한도 소진") { [weak self] _ in
                    #if DEBUG
                    UsageLimitStore.shared.debugExhaustFreeLimit()
                    Logger.app.debug("GridVC+Cleanup: 디버그 기본한도 소진")
                    NotificationCenter.default.post(name: .debugMonetizationStateChanged, object: nil)
                    #endif
                    self?.setupCleanupButton()
                },
                UIAction(title: "전체한도 소진 (골든모먼트)") { [weak self] _ in
                    #if DEBUG
                    UsageLimitStore.shared.debugExhaustAll()
                    Logger.app.debug("GridVC+Cleanup: 디버그 전체한도 소진")
                    NotificationCenter.default.post(name: .debugMonetizationStateChanged, object: nil)
                    #endif
                    self?.setupCleanupButton()
                },
            ]
        )
    }

}

// MARK: - PreviewGridViewControllerDelegate

extension GridViewController: PreviewGridViewControllerDelegate {

    func previewGridVC(_ vc: PreviewGridViewController, didConfirmCleanup assetIDs: [String]) {
        // 삭제대기함으로 이동
        trashStore.moveToTrash(assetIDs: assetIDs)

        // [BM] T055: 자동정리 완료 후 리뷰 요청 평가 (FR-049)
        if let windowScene = view.window?.windowScene {
            let prohibited = ReviewService.shared.isProhibitedTiming
            ReviewService.shared.evaluateAndRequestIfNeeded(
                from: windowScene,
                isProhibitedTiming: prohibited
            )
        }
    }
}


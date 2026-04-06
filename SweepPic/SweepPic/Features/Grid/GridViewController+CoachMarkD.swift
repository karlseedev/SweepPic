//
//  GridViewController+CoachMarkD.swift
//  SweepPic
//
//  Created by Claude Code on 2026-02-23.
//
//  코치마크 D: 저품질 자동 정리 안내 — 트리거 로직
//
//  트리거 (자동):
//    A 완료 + E-1 완료 + 그리드 3초 체류 + 스캔 1장 이상
//    → 포커싱 모션 → 정리 버튼 하이라이트 + 썸네일 + 카드
//    → [확인] → 탭 모션 → dismiss → 정리 시트
//

import UIKit
import ObjectiveC
import AppCore
import OSLog

// MARK: - Associated Object Keys (D 트리거 전용)

private var coachMarkDTimerKey: UInt8 = 0
private var coachMarkDRetryWorkItemKey: UInt8 = 0

// MARK: - Coach Mark D: Trigger Logic

extension GridViewController {

    // MARK: - Stored Properties (Associated Objects)

    /// D 트리거 타이머 (viewDidAppear → 3초 후 표시)
    var coachMarkDTimer: Timer? {
        get { objc_getAssociatedObject(self, &coachMarkDTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &coachMarkDTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    /// D 재시도 DispatchWorkItem (viewWillDisappear 시 취소 가능)
    /// asyncAfter 체인 대신 사용하여 "고아 재시도" 문제 방지
    var coachMarkDRetryWorkItem: DispatchWorkItem? {
        get { objc_getAssociatedObject(self, &coachMarkDRetryWorkItemKey) as? DispatchWorkItem }
        set { objc_setAssociatedObject(self, &coachMarkDRetryWorkItemKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
    }

    // MARK: - Pre-Scan Start (앱 시작 직후)

    /// D 사전 스캔 시작 (D 미표시 + C 완��� 후에만)
    /// C와 D의 동시 분석�� 방지하기 위해 C 완료 후에야 시작
    func startCoachMarkDPreScanIfNeeded() {
        guard !CoachMarkType.autoCleanup.hasBeenShown else { return }
        // C 자동 pop 진행 중이면 차단 (cleanup highlight까지 완료해야 C 완료)
        guard !CoachMarkManager.shared.isAutoPopForC,
              !CoachMarkManager.shared.pendingCleanupHighlight else { return }
        // C 완료 OR C 사전분석 완료+0건이어야 D 사전 스캔 시작
        guard CoachMarkType.similarPhoto.hasBeenShown
              || Self.cPreScanCompleteWithNoGroups else { return }
        CoachMarkDPreScanner.shared.startIfNeeded()
    }

    // MARK: - Trigger 1: Auto (3초 타이머)

    /// 트리거 1: D 표시 조건 체크 (3초 타이머 제거 — 조건 충족 시 즉시)
    /// viewDidAppear에서 호출. C 완료 또는 C 사전분석 완료+0건이면 D 표시 시도.
    func startCoachMarkDTimerIfNeeded() {
        // C 자동 pop 진행 중이면 차단 (cleanup highlight까지 완료해야 C 완료)
        guard !CoachMarkManager.shared.isAutoPopForC,
              !CoachMarkManager.shared.pendingCleanupHighlight else {
            Logger.coachMark.debug("D 스킵: C 자동 pop 진행 중")
            return
        }
        // D 이미 표시됨
        guard !CoachMarkType.autoCleanup.hasBeenShown else {
            Logger.coachMark.debug("D 스킵: D 이미 표시됨")
            return
        }
        // A 미완료
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else {
            Logger.coachMark.debug("D 스킵: A 미완료")
            return
        }
        // E-1 미완료
        guard CoachMarkType.firstDeleteGuide.hasBeenShown else {
            Logger.coachMark.debug("D 스킵: E-1 미완료")
            return
        }
        // C 미완료 AND C 사전분석+0건 아님 → D 차단
        guard CoachMarkType.similarPhoto.hasBeenShown
              || Self.cPreScanCompleteWithNoGroups else {
            Logger.coachMark.debug("D 스킵: C 미완료 + 사전분석 미완료/유사사진 있음")
            return
        }

        let scanner = CoachMarkDPreScanner.shared

        // 스캔 완료 + 1장 이상 → 즉시 표시
        if let result = scanner.result {
            guard result.lowQualityAssets.count > 0 else {
                Logger.coachMark.debug("D 스킵: 스캔 결과 0건")
                return
            }
            Logger.coachMark.debug("D 트리거: 즉시 표시")
            showCoachMarkD()
            return
        }

        // 스캔 미완료 → 완료 콜백 등록하여 대기
        Logger.coachMark.debug("D 대기: 스캔 미완료 — 완료 콜백 등록")
        scanner.onComplete = { [weak self] in
            guard let self else { return }
            let count = scanner.result?.lowQualityAssets.count ?? 0
            guard count > 0 else {
                Logger.coachMark.debug("D 스킵: 스캔 완료, 결과 0건")
                return
            }
            self.showCoachMarkD()
        }
    }

    /// D 타이머 및 재시도 체인 전체 취소 (viewWillDisappear에서 호출)
    func cancelCoachMarkDTimer() {
        coachMarkDTimer?.invalidate()
        coachMarkDTimer = nil
        // [B] 고아 재시도 체인 방지: DispatchWorkItem 취소
        coachMarkDRetryWorkItem?.cancel()
        coachMarkDRetryWorkItem = nil
    }

    // MARK: - Show

    /// D 코치마크 표시 (트리거 1: 자동, 정리 버튼 하이라이트)
    /// 재시도 간격: 10회까지 0.5초, 이후 3초 (로그 스팸 + 부하 방지)
    /// 최대 40회 (약 95초) 초과 시 포기
    private static let retryFastInterval: TimeInterval = 0.5
    private static let retrySlowInterval: TimeInterval = 3.0
    private static let retrySlowThreshold = 10
    private static let retryMaxCount = 40

    func showCoachMarkD(retryCount: Int = 0) {
        // 초기 호출만 로그 (재시도는 간격 변경 시점만 로그)
        if retryCount == 0 {
            Logger.coachMark.debug("showCoachMarkD 호출")
        }

        // 재검증 가드: 영구 중단 (상태가 바뀔 수 없으므로 재시도 불필요)
        guard !CoachMarkType.autoCleanup.hasBeenShown else {
            Logger.coachMark.debug("가드: D 이미 표시됨")
            return
        }

        // [A] 최대 재시도 초과 시 포기 (viewDidAppear에서 다시 트리거됨)
        guard retryCount < Self.retryMaxCount else {
            Logger.coachMark.debug("재시도 \(retryCount)회 초과 — 포기 (다음 viewDidAppear에서 재시도)")
            return
        }

        // 다른 코치마크 표시 중이면 재시도
        guard !CoachMarkManager.shared.isShowing else {
            scheduleRetry(retryCount: retryCount, reason: "isShowing")
            return
        }

        // VoiceOver: 재시도 불필요 (영구 상태)
        guard !UIAccessibility.isVoiceOverRunning else {
            Logger.coachMark.debug("가드: VoiceOver 활성")
            return
        }

        // [A] 일시적 상태 가드: 재시도로 변경 (화면 전환 중 일시적으로 실패 가능)
        guard view.window != nil else {
            scheduleRetry(retryCount: retryCount, reason: "view.window nil")
            return
        }
        guard navigationController?.topViewController === self else {
            scheduleRetry(retryCount: retryCount, reason: "topViewController 불일치")
            return
        }
        guard presentedViewController == nil else {
            scheduleRetry(retryCount: retryCount, reason: "presentedViewController 존재")
            return
        }

        // 선택 모드: 재시도 (사용자가 해제할 수 있음)
        guard !isSelectMode else {
            scheduleRetry(retryCount: retryCount, reason: "선택 모드")
            return
        }

        // 스크롤 중이면 재시도
        guard !isScrolling else {
            scheduleRetry(retryCount: retryCount, reason: "스크롤 중")
            return
        }

        guard let window = view.window else { return }

        let cleanupFrame = getCleanupButtonFrame(in: window)
        let scanResult = CoachMarkDPreScanner.shared.result

        Logger.coachMark.debug("표시 — 썸네일 \(scanResult?.lowQualityAssets.count ?? 0)장")

        CoachMarkOverlayView.showAutoCleanup(
            highlightFrame: cleanupFrame,
            scanResult: scanResult,
            in: window,
            onConfirm: { [weak self] in
                // 삭제대기함 체크 우회하여 정리 플로우 직접 진입
                self?.showCleanupMethodSheet()
            }
        )
    }

    // MARK: - Retry Scheduling

    /// [A+B] 재시도 스케줄링 (DispatchWorkItem 사용으로 취소 가능)
    /// - retrySlowThreshold(10회) 도달 시 간격 변경 로그 출력
    /// - 기존 asyncAfter 대신 DispatchWorkItem을 저장하여
    ///   viewWillDisappear → cancelCoachMarkDTimer()에서 취소 가능
    private func scheduleRetry(retryCount: Int, reason: String) {
        let interval = retryCount < Self.retrySlowThreshold
            ? Self.retryFastInterval : Self.retrySlowInterval
        // 간격 변경 시점에만 로그 (스팸 방지)
        if retryCount == Self.retrySlowThreshold {
            Logger.coachMark.debug("재시도 \(retryCount)회 도달 — 간격 \(interval)초로 변경 (\(reason))")
        }
        // [B] DispatchWorkItem으로 스케줄하여 cancel 가능하게
        let workItem = DispatchWorkItem { [weak self] in
            self?.showCoachMarkD(retryCount: retryCount + 1)
        }
        coachMarkDRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    // MARK: - Cleanup Button Frame

    /// 간편정리 버튼의 윈도우 좌표 프레임 반환 (재생 기능에서도 호출)
    /// iOS 버전에 따라 FloatingTitleBar 또는 시스템 네비바에서 프레임 획득
    func getCleanupButtonFrame(in window: UIWindow) -> CGRect? {
        if #available(iOS 26.0, *) {
            // iOS 26+: rightBarButtonItems = [menuItem, cleanupMenuItem]
            guard let items = navigationItem.rightBarButtonItems,
                  items.count >= 2,
                  let itemView = items[1].value(forKey: "view") as? UIView
            else { return nil }
            return itemView.convert(itemView.bounds, to: window)
        } else {
            // iOS 16~25: FloatingTitleBar의 간편정리 메뉴 버튼 (selectButton 위치)
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay
            else { return nil }
            return overlay.titleBar.rightMenuButtonFrameInWindow()
        }
    }
}

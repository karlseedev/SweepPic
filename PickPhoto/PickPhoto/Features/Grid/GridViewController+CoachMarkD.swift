//
//  GridViewController+CoachMarkD.swift
//  PickPhoto
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

    /// D 사전 스캔 시작 (D 미표시 상태에서만)
    func startCoachMarkDPreScanIfNeeded() {
        guard !CoachMarkType.autoCleanup.hasBeenShown else { return }
        CoachMarkDPreScanner.shared.startIfNeeded()
    }

    // MARK: - Trigger 1: Auto (3초 타이머)

    /// 트리거 1: 그리드 3초 체류 시 D 표시 타이머 시작
    /// viewDidAppear에서 호출. 다른 화면 갔다 오면 타이머 리셋.
    func startCoachMarkDTimerIfNeeded() {
        // D 이미 표시됨
        guard !CoachMarkType.autoCleanup.hasBeenShown else {
            Log.print("[CoachMarkD] 타이머 스킵: D 이미 표시됨")
            return
        }
        // A 미완료
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else {
            Log.print("[CoachMarkD] 타이머 스킵: A 미완료")
            return
        }
        // E-1 미완료
        guard CoachMarkType.firstDeleteGuide.hasBeenShown else {
            Log.print("[CoachMarkD] 타이머 스킵: E-1 미완료")
            return
        }

        // 기존 타이머 무효화 (화면 복귀 시 리셋)
        coachMarkDTimer?.invalidate()

        Log.print("[CoachMarkD] 타이머 시작 (3초)")

        // 3초 후 트리거
        coachMarkDTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self else { return }

            let scanner = CoachMarkDPreScanner.shared

            // 스캔 완료 + 1장 이상 → 즉시 표시
            if let result = scanner.result {
                guard result.lowQualityAssets.count > 0 else {
                    Log.print("[CoachMarkD] 타이머 만료, 스캔 결과 0건 — D 표시 안 함")
                    return
                }
                self.showCoachMarkD()
                return
            }

            // 스캔 미완료 → 완료 콜백 등록하여 대기
            Log.print("[CoachMarkD] 타이머 만료, 스캔 미완료 — 완료 대기")
            scanner.onComplete = { [weak self] in
                guard let self else { return }
                let count = scanner.result?.lowQualityAssets.count ?? 0
                guard count > 0 else {
                    Log.print("[CoachMarkD] 스캔 완료, 결과 0건 — D 표시 안 함")
                    return
                }
                self.showCoachMarkD()
            }
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
            Log.print("[CoachMarkD] showCoachMarkD 호출")
        }

        // 재검증 가드: 영구 중단 (상태가 바뀔 수 없으므로 재시도 불필요)
        guard !CoachMarkType.autoCleanup.hasBeenShown else {
            Log.print("[CoachMarkD] ❌ 가드: D 이미 표시됨")
            return
        }

        // [A] 최대 재시도 초과 시 포기 (viewDidAppear에서 다시 트리거됨)
        guard retryCount < Self.retryMaxCount else {
            Log.print("[CoachMarkD] ❌ 재시도 \(retryCount)회 초과 — 포기 (다음 viewDidAppear에서 재시도)")
            return
        }

        // 다른 코치마크 표시 중이면 재시도
        guard !CoachMarkManager.shared.isShowing else {
            scheduleRetry(retryCount: retryCount, reason: "isShowing")
            return
        }

        // VoiceOver: 재시도 불필요 (영구 상태)
        guard !UIAccessibility.isVoiceOverRunning else {
            Log.print("[CoachMarkD] ❌ 가드: VoiceOver 활성")
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

        Log.print("[CoachMarkD] 표시 — 썸네일 \(scanResult?.lowQualityAssets.count ?? 0)장")

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
            Log.print("[CoachMarkD] ⏳ 재시도 \(retryCount)회 도달 — 간격 \(interval)초로 변경 (\(reason))")
        }
        // [B] DispatchWorkItem으로 스케줄하여 cancel 가능하게
        let workItem = DispatchWorkItem { [weak self] in
            self?.showCoachMarkD(retryCount: retryCount + 1)
        }
        coachMarkDRetryWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + interval, execute: workItem)
    }

    // MARK: - Cleanup Button Frame

    /// 정리 버튼의 윈도우 좌표 프레임 반환
    /// iOS 버전에 따라 FloatingTitleBar 또는 시스템 네비바에서 프레임 획득
    private func getCleanupButtonFrame(in window: UIWindow) -> CGRect? {
        if #available(iOS 26.0, *) {
            // iOS 26+: rightBarButtonItems = [menuItem, selectItem, cleanupItem]
            guard let items = navigationItem.rightBarButtonItems,
                  items.count >= 3,
                  let itemView = items[2].value(forKey: "view") as? UIView
            else { return nil }
            return itemView.convert(itemView.bounds, to: window)
        } else {
            // iOS 16~25: FloatingTitleBar의 두 번째 오른쪽 버튼 (정리)
            guard let tabBarController = tabBarController as? TabBarController,
                  let overlay = tabBarController.floatingOverlay
            else { return nil }
            return overlay.titleBar.secondRightButtonFrameInWindow()
        }
    }
}

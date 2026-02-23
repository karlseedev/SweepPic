//
//  GridViewController+CoachMarkD.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-23.
//
//  코치마크 D: 저품질 자동 정리 안내 — 트리거 로직
//
//  트리거 1 (자동):
//    A 완료 + E-1 완료 + 그리드 3초 체류 + 스캔 1장 이상
//    → 정리 버튼 하이라이트 + 썸네일 + "사용해보세요"
//    → [확인] → 탭 모션 → dismiss → 정리 시트
//
//  트리거 2 (수동):
//    D 미완료 + 스캔 1장 이상 + 정리 버튼 탭
//    → 하이라이트 없음 + 썸네일 + "기능입니다"
//    → [확인] → dismiss → 정리 시트
//

import UIKit
import ObjectiveC
import AppCore

// MARK: - Associated Object Keys (D 트리거 전용)

private var coachMarkDTimerKey: UInt8 = 0

// MARK: - Coach Mark D: Trigger Logic

extension GridViewController {

    // MARK: - Stored Properties (Associated Objects)

    /// D 트리거 타이머 (viewDidAppear → 3초 후 표시)
    var coachMarkDTimer: Timer? {
        get { objc_getAssociatedObject(self, &coachMarkDTimerKey) as? Timer }
        set { objc_setAssociatedObject(self, &coachMarkDTimerKey, newValue, .OBJC_ASSOCIATION_RETAIN_NONATOMIC) }
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
        guard !CoachMarkType.autoCleanup.hasBeenShown else { return }
        // A 미완료
        guard CoachMarkType.gridSwipeDelete.hasBeenShown else { return }
        // E-1 미완료
        guard CoachMarkType.firstDeleteGuide.hasBeenShown else { return }

        // 기존 타이머 무효화 (화면 복귀 시 리셋)
        coachMarkDTimer?.invalidate()

        // 3초 후 트리거
        coachMarkDTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { [weak self] _ in
            guard let self else { return }

            // 스캔 완료 + 1장 이상일 때만 표시
            let count = CoachMarkDPreScanner.shared.result?.lowQualityAssets.count ?? 0
            guard count > 0 else {
                Log.print("[CoachMarkD] 타이머 만료, 스캔 결과 0건 — D 표시 안 함")
                return
            }

            self.showCoachMarkD(highlightButton: true)
        }
    }

    /// D 타이머 취소 (viewWillDisappear에서 호출)
    func cancelCoachMarkDTimer() {
        coachMarkDTimer?.invalidate()
        coachMarkDTimer = nil
    }

    // MARK: - Show (트리거 1, 2 공용)

    /// D 코치마크 표시
    /// - Parameter highlightButton: true면 정리 버튼에 구멍 하이라이트 (트리거 1), false면 구멍 없음 (트리거 2)
    func showCoachMarkD(highlightButton: Bool) {
        // 재검증 가드
        guard !CoachMarkType.autoCleanup.hasBeenShown else { return }

        // 다른 코치마크 표시 중이면 0.5초 후 재시도
        guard !CoachMarkManager.shared.isShowing else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showCoachMarkD(highlightButton: highlightButton)
            }
            return
        }

        guard !UIAccessibility.isVoiceOverRunning else { return }
        guard view.window != nil else { return }
        guard navigationController?.topViewController === self else { return }
        guard presentedViewController == nil else { return }
        guard !isSelectMode else { return }

        // 스크롤 중이면 정지 후 재시도
        guard !isScrolling else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showCoachMarkD(highlightButton: highlightButton)
            }
            return
        }

        guard let window = view.window else { return }

        // 트리거 1: 정리 버튼 프레임 (하이라이트용)
        // 트리거 2: nil (구멍 없이 전체 딤)
        let cleanupFrame: CGRect? = highlightButton ? getCleanupButtonFrame(in: window) : nil

        // 스캔 결과 (없으면 텍스트 폴백)
        let scanResult = CoachMarkDPreScanner.shared.result

        Log.print("[CoachMarkD] 표시 — 트리거\(highlightButton ? "1(자동)" : "2(수동)"), 썸네일 \(scanResult?.lowQualityAssets.count ?? 0)장")

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

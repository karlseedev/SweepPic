//
//  ViewerViewController+CoachMark.swift
//  PickPhoto
//
//  코치마크 B: 뷰어 스와이프 삭제 안내
//  - viewDidAppear에서 조건 확인 후 즉시 오버레이 배치
//  - 0.5초 후 페이드인 + 애니메이션 시작
//  - 1회만 표시 (UserDefaults)
//

import UIKit

extension ViewerViewController {

    /// 뷰어 코치마크 B 표시 조건 확인 + 즉시 오버레이 배치
    /// viewDidAppear에서 호출
    func showViewerSwipeDeleteCoachMarkIfNeeded() {
        // 이미 표시된 적 있으면 스킵 (테스트 중 임시 비활성화)
        // guard !CoachMarkType.viewerSwipeDelete.hasBeenShown else { return }

        // 다른 코치마크 표시 중이면 스킵 (A/B 동시 표시 방지)
        guard !CoachMarkManager.shared.isShowing else { return }

        // 일반 모드에서만 표시 (휴지통/정리 모드 제외)
        guard viewerMode == .normal else { return }

        // VoiceOver 활성 시 스킵
        guard !UIAccessibility.isVoiceOverRunning else { return }

        // 화면이 활성 상태인지 확인
        guard view.window != nil else { return }

        // 모달이 올라온 경우 스킵
        guard presentedViewController == nil else { return }

        // 사진 스냅샷 캡처 (이미지뷰만, 검은 여백 제외)
        guard let result = capturePhotoSnapshot() else { return }

        // 윈도우 참조
        guard let window = view.window else { return }

        // 즉시 오버레이 배치 (터치 차단 시작, 0.5초 후 페이드인)
        CoachMarkOverlayView.showViewerSwipeDelete(
            photoSnapshot: result.snapshot,
            photoFrame: result.frame,
            in: window
        )
    }
}

//
//  ViewerViewController+CoachMark.swift
//  SweepPic
//
//  코치마크 B: 뷰어에서 밀어서 삭제 안내
//  - viewDidAppear + 페이지 스와이프 완료 시 조건 확인 후 오버레이 배치
//  - 오버레이를 뷰어의 view에 추가하여 뒤로가기/삭제 버튼이 위에 보이도록 함
//  - 동영상은 스킵, 이미지일 때만 표시
//  - 0.5초 후 페이드인 + 애니메이션 시작
//  - 1회만 표시 (UserDefaults)
//

import UIKit
import Photos

extension ViewerViewController {

    /// 뷰어 코치마크 B 표시 조건 확인 + 즉시 오버레이 배치
    /// viewDidAppear 및 페이지 스와이프 완료(didFinishAnimating) 시 호출
    func showViewerSwipeDeleteCoachMarkIfNeeded() {
        // 이미 표시된 적 있으면 스킵
        guard !CoachMarkType.viewerSwipeDelete.hasBeenShown else { return }

        // C 자동 pop 진행 중이면 B 스킵
        guard !CoachMarkManager.shared.isAutoPopForC else { return }

        // C-2 대기 중이면 B 스킵 (C-2와 B 충돌 방지)
        guard !CoachMarkManager.shared.isWaitingForC2 else { return }

        // 다른 코치마크 표시 중이면 스킵 (A/B 동시 표시 방지)
        guard !CoachMarkManager.shared.isShowing else { return }

        // 일반 모드에서만 표시 (삭제대기함/정리 모드 제외)
        guard viewerMode == .normal else { return }

        // 동영상이면 스킵 (이미지일 때만 코치마크 표시)
        guard coordinator.asset(at: currentIndex)?.mediaType != .video else { return }

        // VoiceOver 활성 시 스킵
        guard !UIAccessibility.isVoiceOverRunning else { return }

        // 화면이 활성 상태인지 확인
        guard view.window != nil else { return }

        // 모달이 올라온 경우 스킵
        guard presentedViewController == nil else { return }

        // 사진 스냅샷 캡처 (이미지뷰만, 검은 여백 제외)
        guard let result = capturePhotoSnapshot() else { return }

        // 스냅샷 frame을 view 좌표로 변환 (window 좌표 → view 좌표)
        let frameInView = view.convert(result.frame, from: view.window)

        // 오버레이를 뷰어의 view에 추가 (window 대신)
        // → 뒤로가기/삭제 버튼이 오버레이 위에 자연스럽게 보임
        CoachMarkOverlayView.showViewerSwipeDelete(
            photoSnapshot: result.snapshot,
            photoFrame: frameInView,
            in: view
        )

        // 뒤로가기/삭제 버튼을 오버레이 위에 보이게 (터치는 차단)
        showControlButtonsAboveCoachMark()
    }
}

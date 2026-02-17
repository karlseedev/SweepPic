//
//  ViewerViewController+CoachMarkC.swift
//  PickPhoto
//
//  Created by Claude Code on 2026-02-17.
//
//  코치마크 C-2: 뷰어 + 버튼 하이라이트
//  - viewDidAppear에서 isWaitingForC2 체크 → + 버튼 표시 대기 → C-2 전환
//  - [확인] + 탭 모션 후 자동으로 얼굴 비교 화면 진입
//  - present 성공 후 markAsShown() 호출
//
//  트리거: viewDidAppear → triggerCoachMarkC2IfNeeded → waitForFaceButtons → transitionToC2
//  완료: startC_ConfirmSequence → 탭 모션 → onConfirm → triggerFaceComparisonForCoachMark

import UIKit
import AppCore

// MARK: - Coach Mark C-2: Viewer Face Button

extension ViewerViewController {

    // MARK: - C-2 Trigger

    /// C-2 코치마크 트리거 (viewDidAppear에서 호출)
    /// C-1에서 isWaitingForC2 = true로 설정 → 여기서 감지하여 C-2 시작
    func triggerCoachMarkC2IfNeeded() {
        // C-1에서 설정한 대기 플래그 체크
        guard CoachMarkManager.shared.isWaitingForC2 else {
            Log.print("[CoachMarkC2] SKIP — isWaitingForC2=false")
            return
        }

        // 화면 활성 상태 확인
        guard view.window != nil else {
            Log.print("[CoachMarkC2] SKIP — view.window=nil")
            return
        }

        // 모달이 올라온 경우 스킵
        guard presentedViewController == nil else {
            Log.print("[CoachMarkC2] SKIP — presentedVC exists")
            return
        }

        Log.print("[CoachMarkC2] START polling — overlay=\(CoachMarkManager.shared.currentOverlay != nil), faceOverlay=\(faceButtonOverlay != nil)")

        // 즉시 터치 차단: C-2 준비까지 뷰어 조작(이미지 스와이프 등) 방지
        // C-1에서 overlay를 alpha=0.01로 투명화한 뒤 push/present 하면,
        // UIKit이 뷰 계층 재정렬하여 overlay가 뷰어 뒤로 밀림
        // → transitionToC2의 bringSubviewToFront까지 뷰어에 터치 전달됨
        // 이를 방지하기 위해 뷰어의 userInteraction을 비활성화
        view.isUserInteractionEnabled = false

        // + 버튼 표시 대기 (최대 5초, 0.3초 간격 폴링)
        waitForFaceButtons(timeout: 5.0) { [weak self] success in
            guard let self else { return }

            guard success else {
                // 타임아웃 — 터치 복원 + C 전체 스킵
                Log.print("[CoachMarkC2] TIMEOUT — faceButtons never appeared")
                self.view.isUserInteractionEnabled = true
                CoachMarkManager.shared.resetC2State()
                CoachMarkManager.shared.currentOverlay?.dismiss()
                CoachMarkType.similarPhoto.markAsShown()
                return
            }

            // + 버튼 프레임 가져오기
            guard let buttonFrame = self.faceButtonOverlay?.firstButtonFrameInWindow() else {
                Log.print("[CoachMarkC2] FAIL — firstButtonFrameInWindow=nil")
                self.view.isUserInteractionEnabled = true
                CoachMarkManager.shared.resetC2State()
                CoachMarkManager.shared.currentOverlay?.dismiss()
                return
            }

            // 기존 C-1 오버레이를 C-2로 전환
            guard let overlay = CoachMarkManager.shared.currentOverlay else {
                Log.print("[CoachMarkC2] FAIL — currentOverlay=nil (weak ref lost)")
                self.view.isUserInteractionEnabled = true
                CoachMarkManager.shared.resetC2State()
                return
            }

            Log.print("[CoachMarkC2] SUCCESS — transitioning to C-2, buttonFrame=\(buttonFrame)")

            // C-2 전환 성공 → 안전 타임아웃 취소 (C-2는 사용자 confirm까지 유지)
            CoachMarkManager.shared.safetyTimeoutWork?.cancel()
            CoachMarkManager.shared.safetyTimeoutWork = nil

            // 터치 복원 (overlay가 bringSubviewToFront로 최상단 → overlay의 hitTest가 터치 차단)
            // 같은 동기 블록 내이므로 복원↔bringSubviewToFront 사이 터치 유입 없음
            self.view.isUserInteractionEnabled = true

            // C-2 전환: dim hole을 + 버튼으로 이동 + 새 카피/확인 표시
            overlay.transitionToC2(
                newHighlightFrame: buttonFrame,
                c2OnConfirm: { [weak self, weak overlay] in
                    // C-2 완료: 오버레이 즉시 제거 (텍스트/버튼은 이미 페이드아웃됨)
                    // ⚠️ dismiss 먼저! .fullScreen present가 window 최상단에
                    //    transition container를 삽입하므로 오버레이를 먼저 제거해야 함
                    overlay?.shouldStopAnimation = true
                    overlay?.removeFromSuperview()
                    CoachMarkManager.shared.resetC2State()

                    // 얼굴 비교 화면 자동 진입
                    self?.triggerFaceComparisonForCoachMark()
                }
            )
        }
    }

    // MARK: - Wait for Face Buttons

    /// + 버튼 표시 대기 (폴링 방식)
    /// showSimilarPhotoOverlay() → checkAndShowFaceButtons()는 async 체인이므로
    /// + 버튼이 즉시 표시되지 않을 수 있음 (캐시 miss 시 수초 소요)
    /// - Parameters:
    ///   - timeout: 최대 대기 시간 (초)
    ///   - completion: 성공(true) 또는 타임아웃(false)
    private func waitForFaceButtons(timeout: TimeInterval, completion: @escaping (Bool) -> Void) {
        let deadline = Date().addingTimeInterval(timeout)
        let checkInterval: TimeInterval = 0.3

        func check() {
            // + 버튼이 표시됐는지 확인
            if self.faceButtonOverlay?.hasVisibleButtons == true {
                // 0.3초 추가 딜레이 (버튼 페이드인 200ms + 여유)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    completion(true)
                }
                return
            }

            // 타임아웃 체크
            if Date() >= deadline {
                completion(false)
                return
            }

            // 다음 폴링
            DispatchQueue.main.asyncAfter(deadline: .now() + checkInterval) { [weak self] in
                guard self != nil else { return }
                check()
            }
        }

        check()
    }

    // MARK: - Face Comparison Auto-Trigger

    /// 얼굴 비교 화면 자동 진입 (C-2 완료 후)
    /// 첫 번째 + 버튼의 face 정보로 delegate 메서드를 직접 호출하여
    /// showFaceComparisonViewController를 트리거
    private func triggerFaceComparisonForCoachMark() {
        guard let overlay = faceButtonOverlay,
              let firstFace = overlay.firstVisibleFace else {
            // face 정보 없음 — markAsShown 안 함 (다음 기회에 재시도)
            return
        }

        // delegate 메서드 직접 호출 → 비동기로 ComparisonGroup 로드 후 present
        faceButtonOverlay(overlay, didTapFaceAtPersonIndex: firstFace.personIndex, face: firstFace)

        // present 성공 확인 후 markAsShown
        // faceButtonOverlay delegate → async Task → showFaceComparisonViewController → present
        // 캐시 hit 기준 ~500ms 이내 present 완료
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
            if self?.presentedViewController != nil {
                // present 성공 → 코치마크 C 완료 마킹
                CoachMarkType.similarPhoto.markAsShown()
            }
            // present 실패 시 markAsShown 미호출 → 다음 기회에 재시도
        }
    }
}

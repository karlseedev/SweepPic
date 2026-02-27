// SwipeDeleteHandler.swift
// 위 스와이프 삭제 제스처 핸들러
//
// T030: SwipeDeleteHandler 생성
// - 팬 제스처
// - 20% 임계값 (UIScreen.main.bounds.height 기준, FR-011)
// - 위 스와이프 → moveToTrash

import UIKit

/// 위 스와이프 삭제 핸들러
/// 화면 높이의 20% 이상 위로 스와이프하면 삭제 트리거
final class SwipeDeleteHandler: NSObject {

    // MARK: - Constants

    /// 삭제 트리거 임계값 (화면 높이의 %)
    /// FR-011: UIScreen.main.bounds.height 기준 20% 이상
    private static let deleteThreshold: CGFloat = 0.20

    /// 최소 스와이프 속도 (빠른 스와이프 인식용)
    private static let minimumVelocity: CGFloat = -800

    // MARK: - Properties

    /// 팬 제스처 인식기
    let panGesture: UIPanGestureRecognizer

    /// 삭제 콜백
    private let onDelete: () -> Void

    /// transform 적용 대상 뷰 (사진 콘텐츠만 이동시키기 위해 외부에서 지정)
    weak var transformTarget: UIView?

    /// 삭제 가능 여부 판별 클로저 (false 반환 시 바운스백 + 경고 햅틱)
    var canDelete: (() -> Bool)?

    /// 드래그 시작 여부
    private var isDragging = false

    /// 제스처 시작 시 Y 위치
    private var startY: CGFloat = 0

    /// 화면 높이 (임계값 계산용)
    private let screenHeight: CGFloat = UIScreen.main.bounds.height

    /// 피드백 제너레이터 (햅틱)
    private let feedbackGenerator = UIImpactFeedbackGenerator(style: .medium)

    /// 삭제 임계값 도달 여부 (중복 호출 방지)
    private var hasTriggered = false

    // MARK: - Initialization

    /// 초기화
    /// - Parameter onDelete: 삭제 트리거 시 호출될 콜백
    init(onDelete: @escaping () -> Void) {
        self.onDelete = onDelete
        self.panGesture = UIPanGestureRecognizer()

        super.init()

        panGesture.addTarget(self, action: #selector(handlePan(_:)))
        panGesture.delegate = self

        // 햅틱 피드백 준비
        feedbackGenerator.prepare()
    }

    // MARK: - Gesture Handling

    /// 팬 제스처 처리
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        let translation = gesture.translation(in: gesture.view)
        let velocity = gesture.velocity(in: gesture.view)

        switch gesture.state {
        case .began:
            // 코치마크 방어 코드 (hitTest가 차단하므로 실제로는 도달하지 않음)
            CoachMarkManager.shared.dismissCurrent()

            // 위쪽 방향만 시작
            if velocity.y < 0 {
                isDragging = true
                startY = translation.y
                hasTriggered = false
                feedbackGenerator.prepare()
            }

        case .changed:
            guard isDragging else { return }

            // 위쪽 방향 오프셋 계산 (음수 값)
            let offsetY = translation.y - startY

            // 위쪽 스와이프인 경우 (음수)
            if offsetY < 0 {
                // 임계값 도달 확인
                let progress = abs(offsetY) / screenHeight

                if progress >= Self.deleteThreshold && !hasTriggered {
                    // 임계값 도달 시 햅틱 피드백
                    feedbackGenerator.impactOccurred()
                    hasTriggered = true
                }

                // 사진 콘텐츠만 위로 이동 (UI 버튼은 제자리 유지)
                transformTarget?.transform = CGAffineTransform(translationX: 0, y: offsetY * 0.3)
            }

        case .ended, .cancelled:
            guard isDragging else { return }
            isDragging = false

            let offsetY = translation.y - startY

            // 삭제 트리거 조건:
            // 1. 임계값(20%) 이상 스와이프
            // 2. 또는 충분히 빠른 속도로 위쪽 스와이프
            let reachedThreshold = abs(offsetY) >= screenHeight * Self.deleteThreshold
            let fastSwipe = velocity.y < Self.minimumVelocity

            if (reachedThreshold || fastSwipe) && offsetY < 0 {
                // 삭제 가능 여부 확인 (이미 삭제대기함인 사진이면 바운스백)
                if canDelete?() == false {
                    bounceBack()
                    return
                }
                // 삭제 트리거
                triggerDelete(in: gesture.view)
            } else {
                // 원위치로 복귀
                resetView(gesture.view)
            }

        default:
            break
        }
    }

    // MARK: - Private Methods

    /// 삭제 트리거
    private func triggerDelete(in view: UIView?) {
        // 삭제 애니메이션 (사진 콘텐츠만 이동)
        UIView.animate(withDuration: 0.1, animations: {
            self.transformTarget?.transform = CGAffineTransform(translationX: 0, y: -100)
            self.transformTarget?.alpha = 0.5
        }, completion: { _ in
            // 삭제 콜백 호출
            self.onDelete()

            // 뷰 복원
            self.transformTarget?.transform = .identity
            self.transformTarget?.alpha = 1.0
        })
    }

    /// 뷰 원위치 복귀
    private func resetView(_ view: UIView?) {
        UIView.animate(withDuration: 0.2) {
            self.transformTarget?.transform = .identity
        }
    }

    /// 바운스백 (삭제 불가 시 원위치 복귀 + 경고 햅틱)
    private func bounceBack() {
        let warning = UINotificationFeedbackGenerator()
        warning.notificationOccurred(.warning)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.6, initialSpringVelocity: 0.5) {
            self.transformTarget?.transform = .identity
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension SwipeDeleteHandler: UIGestureRecognizerDelegate {

    /// 제스처 시작 조건
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGesture else { return true }

        let velocity = panGesture.velocity(in: panGesture.view)

        // 위쪽 방향이고 수직 움직임이 더 클 때만 인식
        // FR-011: 줌 상태에서도 삭제 허용
        return velocity.y < 0 && abs(velocity.y) > abs(velocity.x)
    }

    /// 다른 제스처와 동시 인식 허용 여부
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // 스크롤 뷰의 줌/팬과 동시 인식 방지
        if otherGestureRecognizer is UIPinchGestureRecognizer {
            return false
        }

        // 페이지 뷰의 스와이프와는 동시 인식 방지
        if let scrollView = otherGestureRecognizer.view as? UIScrollView,
           scrollView.isPagingEnabled {
            return false
        }

        return false
    }
}

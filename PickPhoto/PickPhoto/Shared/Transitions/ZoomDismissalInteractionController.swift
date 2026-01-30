// ZoomDismissalInteractionController.swift
// Interactive Dismiss 컨트롤러
//
// UIViewControllerInteractiveTransitioning 직접 구현
// ⚠️ UIPercentDrivenInteractiveTransition 사용 안 함
//   (커스텀 스냅샷 애니메이션과 호환 안 됨)
//
// 동작:
// 1. startInteractiveTransition: 스냅샷 생성 + 배경 배치
// 2. didPanWith (.changed): 스냅샷 위치 + 배경 alpha 업데이트
// 3. didPanWith (.ended): 완료/취소 판단
// 4. finish: 스프링 애니메이션으로 셀 위치로 축소
// 5. cancel: 원위치 복귀

import UIKit
import AppCore

/// Interactive Dismiss 컨트롤러
/// 아래로 드래그 → 이미지 축소 + 배경 투명 → 셀 위치로 줌 아웃
final class ZoomDismissalInteractionController: NSObject, UIViewControllerInteractiveTransitioning {

    // MARK: - Properties

    /// 소스 제공자 (그리드 VC)
    weak var sourceProvider: ZoomTransitionSourceProviding?

    /// 목적지 제공자 (뷰어 VC)
    weak var destinationProvider: ZoomTransitionDestinationProviding?

    /// 전환 완료/취소 콜백 (completed: true=완료, false=취소)
    var onTransitionFinished: ((Bool) -> Void)?

    // MARK: - Internal State

    /// 현재 transition context
    private var transitionContext: UIViewControllerContextTransitioning?

    /// 스냅샷 이미지 뷰 (드래그 중 손가락 따라다님)
    private var snapshotView: UIImageView?

    /// 배경 어두운 뷰
    private var backgroundView: UIView?

    /// 스냅샷 초기 프레임 (뷰어 이미지 위치)
    private var initialFrame: CGRect = .zero

    /// fromView (뷰어)
    private weak var fromView: UIView?

    // MARK: - Constants

    /// dismiss 완료 임계값 (드래그 비율)
    private let dismissThreshold: CGFloat = 0.15

    /// dismiss 완료 속도 임계값
    private let velocityThreshold: CGFloat = 800

    /// 스프링 애니메이션 시간
    private let animationDuration: TimeInterval = 0.35

    /// 스프링 댐핑
    private let springDamping: CGFloat = 0.85

    // MARK: - UIViewControllerInteractiveTransitioning

    func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
        self.transitionContext = transitionContext
        let container = transitionContext.containerView

        guard let fromVC = transitionContext.viewController(forKey: .from),
              let toVC = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let fromView = fromVC.view!
        self.fromView = fromView

        // 현재 인덱스
        let currentIndex = destinationProvider?.currentOriginalIndex ?? 0

        // 1. 그리드를 해당 셀 위치로 스크롤 (셀이 보이도록)
        sourceProvider?.scrollToSourceCell(for: currentIndex)
        toVC.view.layoutIfNeeded()

        // 2. 배경 뷰 생성 (검은색, alpha 1.0)
        let bg = UIView(frame: container.bounds)
        bg.backgroundColor = .black
        bg.alpha = 1.0
        container.addSubview(bg)
        self.backgroundView = bg

        // 3. 스냅샷 생성 (뷰어의 현재 이미지)
        let snapshot = UIImageView()
        snapshot.contentMode = .scaleAspectFill
        snapshot.clipsToBounds = true

        // 뷰어 이미지 프레임 가져오기
        if let destFrame = destinationProvider?.zoomDestinationFrame {
            snapshot.frame = destFrame
            initialFrame = destFrame
        } else {
            // fallback: 전체 화면
            snapshot.frame = container.bounds
            initialFrame = container.bounds
        }

        // 뷰어 이미지 설정
        if let destView = destinationProvider?.zoomDestinationView as? UIImageView {
            snapshot.image = destView.image
        }

        container.addSubview(snapshot)
        self.snapshotView = snapshot

        // 4. fromView(뷰어) 숨김
        fromView.alpha = 0

        Log.debug("ZoomTransition", "Interactive dismiss started - index: \(currentIndex)")
    }

    // MARK: - Pan Gesture Handling

    /// 팬 제스처 업데이트 (ViewerViewController에서 호출)
    func didPanWith(gestureRecognizer: UIPanGestureRecognizer) {
        guard let transitionContext = transitionContext else { return }

        let translation = gestureRecognizer.translation(in: transitionContext.containerView)
        let velocity = gestureRecognizer.velocity(in: transitionContext.containerView)

        switch gestureRecognizer.state {
        case .changed:
            updateInteractiveTransition(translation: translation)

        case .ended:
            let progress = calculateProgress(translation: translation)
            let shouldComplete = progress > dismissThreshold || velocity.y > velocityThreshold

            if shouldComplete {
                finishInteractiveTransition(velocity: velocity)
            } else {
                cancelInteractiveTransition()
            }

        case .cancelled:
            cancelInteractiveTransition()

        default:
            break
        }
    }

    // MARK: - Update

    /// 드래그 중 스냅샷 위치 + 배경 alpha 업데이트
    private func updateInteractiveTransition(translation: CGPoint) {
        guard let snapshot = snapshotView,
              let container = transitionContext?.containerView else { return }

        let progress = calculateProgress(translation: translation)

        // 스냅샷 이동: 초기 위치에서 translation만큼 이동
        let offsetY = max(0, translation.y)  // 아래로만 이동
        snapshot.center = CGPoint(
            x: initialFrame.midX + translation.x,
            y: initialFrame.midY + offsetY
        )

        // 스냅샷 축소: 드래그할수록 작아짐 (최소 0.3)
        let scale = max(0.3, 1.0 - progress * 0.5)
        snapshot.transform = CGAffineTransform(scaleX: scale, y: scale)

        // 배경 투명도: 드래그할수록 투명
        backgroundView?.alpha = 1.0 - progress * 0.8

        transitionContext?.updateInteractiveTransition(progress)
    }

    // MARK: - Finish

    /// Interactive dismiss 완료: 셀 위치로 줌 아웃
    private func finishInteractiveTransition(velocity: CGPoint) {
        guard let snapshot = snapshotView,
              let context = transitionContext else { return }

        let currentIndex = destinationProvider?.currentOriginalIndex ?? 0
        let targetFrame = sourceProvider?.zoomSourceFrame(for: currentIndex)

        // transform 초기화 후 frame 설정을 위해
        snapshot.transform = .identity

        // 스프링 속도 계산
        let currentCenter = snapshot.center
        let endFrame = targetFrame ?? CGRect(
            x: context.containerView.bounds.midX - 20,
            y: context.containerView.bounds.midY - 20,
            width: 40, height: 40
        )
        let distance = abs(endFrame.midY - currentCenter.y)
        let springVelocity = distance > 0 ? min(abs(velocity.y) / distance, 15) : 0

        UIView.animate(
            withDuration: animationDuration,
            delay: 0,
            usingSpringWithDamping: springDamping,
            initialSpringVelocity: springVelocity,
            options: .curveEaseOut
        ) {
            snapshot.frame = endFrame
            self.backgroundView?.alpha = 0
        } completion: { _ in
            self.cleanup()
            context.finishInteractiveTransition()
            context.completeTransition(true)
            self.onTransitionFinished?(true)
            Log.debug("ZoomTransition", "Interactive dismiss finished")
        }
    }

    // MARK: - Cancel

    /// Interactive dismiss 취소: 원위치 복귀
    private func cancelInteractiveTransition() {
        guard let snapshot = snapshotView,
              let context = transitionContext else { return }

        UIView.animate(
            withDuration: 0.25,
            delay: 0,
            usingSpringWithDamping: 0.9,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            snapshot.transform = .identity
            snapshot.frame = self.initialFrame
            self.backgroundView?.alpha = 1.0
        } completion: { _ in
            // fromView(뷰어) 복원
            self.fromView?.alpha = 1
            self.cleanup()
            context.cancelInteractiveTransition()
            context.completeTransition(false)
            self.onTransitionFinished?(false)
            Log.debug("ZoomTransition", "Interactive dismiss cancelled")
        }
    }

    // MARK: - Helpers

    /// 드래그 진행률 계산 (0.0 ~ 1.0)
    private func calculateProgress(translation: CGPoint) -> CGFloat {
        guard let container = transitionContext?.containerView else { return 0 }
        let offsetY = max(0, translation.y)
        return min(offsetY / container.bounds.height, 1.0)
    }

    /// 리소스 정리
    private func cleanup() {
        snapshotView?.removeFromSuperview()
        backgroundView?.removeFromSuperview()
        snapshotView = nil
        backgroundView = nil
        transitionContext = nil
    }
}

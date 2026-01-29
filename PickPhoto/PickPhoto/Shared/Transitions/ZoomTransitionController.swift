// ZoomTransitionController.swift
// 줌 트랜지션 컨트롤러
//
// UINavigationControllerDelegate로 커스텀 트랜지션 제공
// - animationController: ZoomAnimator 반환
// - interactionController: ZoomInteractionController 반환 (Phase 3)

import UIKit
import AppCore

/// 줌 트랜지션 컨트롤러
/// Navigation 전환 시 ZoomAnimator 제공
final class ZoomTransitionController: NSObject {

    // MARK: - Properties

    /// 소스 제공자 (그리드 VC)
    weak var sourceProvider: ZoomTransitionSourceProviding?

    /// 목적지 제공자 (뷰어 VC)
    weak var destinationProvider: ZoomTransitionDestinationProviding?

    /// Interactive 전환 컨트롤러 (Phase 3에서 구현)
    var interactionController: UIPercentDrivenInteractiveTransition?

    /// Interactive 전환 진행 중 여부
    var isInteractive: Bool = false

    // MARK: - Init

    override init() {
        super.init()
        Log.debug("ZoomTransition", "ZoomTransitionController initialized")
    }
}

// MARK: - Animation Controller Provider

extension ZoomTransitionController {

    /// Push/Pop에 따른 ZoomAnimator 생성
    /// - Parameters:
    ///   - operation: Navigation 작업 (push/pop)
    ///   - fromVC: 출발 VC
    ///   - toVC: 도착 VC
    /// - Returns: ZoomAnimator 또는 nil (기본 애니메이션 사용)
    func animationController(
        for operation: UINavigationController.Operation,
        from fromVC: UIViewController,
        to toVC: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {

        // Push: 그리드 → 뷰어
        if operation == .push {
            // toVC가 ZoomTransitionDestinationProviding 채택 확인
            guard let destination = toVC as? ZoomTransitionDestinationProviding else {
                Log.debug("ZoomTransition", "Push: toVC is not ZoomTransitionDestinationProviding")
                return nil
            }

            // fromVC가 ZoomTransitionSourceProviding 채택 확인
            guard let source = fromVC as? ZoomTransitionSourceProviding else {
                Log.debug("ZoomTransition", "Push: fromVC is not ZoomTransitionSourceProviding")
                return nil
            }

            let animator = ZoomAnimator(isPush: true)
            animator.sourceProvider = source
            animator.destinationProvider = destination

            // 컨트롤러에도 저장 (Pop 시 사용)
            self.sourceProvider = source
            self.destinationProvider = destination

            Log.debug("ZoomTransition", "Push: using ZoomAnimator")
            return animator
        }

        // Pop: 뷰어 → 그리드
        if operation == .pop {
            // fromVC가 ZoomTransitionDestinationProviding 채택 확인
            guard let destination = fromVC as? ZoomTransitionDestinationProviding else {
                Log.debug("ZoomTransition", "Pop: fromVC is not ZoomTransitionDestinationProviding")
                return nil
            }

            // toVC가 ZoomTransitionSourceProviding 채택 확인
            guard let source = toVC as? ZoomTransitionSourceProviding else {
                Log.debug("ZoomTransition", "Pop: toVC is not ZoomTransitionSourceProviding")
                return nil
            }

            let animator = ZoomAnimator(isPush: false)
            animator.sourceProvider = source
            animator.destinationProvider = destination

            Log.debug("ZoomTransition", "Pop: using ZoomAnimator (interactive: \(isInteractive))")
            return animator
        }

        return nil
    }

    /// Interactive 전환 컨트롤러 반환
    /// - Parameter animator: 현재 사용 중인 애니메이터
    /// - Returns: Interactive 컨트롤러 또는 nil
    func interactionControllerForAnimation(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        // Interactive 전환이 아니면 nil 반환
        guard isInteractive else { return nil }
        return interactionController
    }
}

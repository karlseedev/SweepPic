// ZoomTransitionController.swift
// 줌 트랜지션 컨트롤러 (v2 - Modal 방식)
//
// UIViewControllerTransitioningDelegate로 커스텀 Modal 트랜지션 제공
// - animationController(forPresented:): ZoomAnimator(isPresenting: true)
// - animationController(forDismissed:): ZoomAnimator(isPresenting: false)
// - interactionControllerForDismissal: Interactive dismiss 지원
// - presentationController: ZoomPresentationController 제공

import UIKit
import AppCore

/// 줌 트랜지션 컨트롤러 (Modal 방식)
/// 그리드 ↔ 뷰어 간 커스텀 Modal 트랜지션 관리
final class ZoomTransitionController: NSObject, UIViewControllerTransitioningDelegate {

    // MARK: - Properties

    /// 소스 제공자 (그리드 VC)
    weak var sourceProvider: ZoomTransitionSourceProviding?

    /// 목적지 제공자 (뷰어 VC)
    weak var destinationProvider: ZoomTransitionDestinationProviding?

    /// Interactive dismiss 컨트롤러
    var interactionController: ZoomDismissalInteractionController?

    /// Interactive dismiss 진행 중 여부
    var isInteractivelyDismissing: Bool = false

    // MARK: - Init

    override init() {
        super.init()
        Log.debug("ZoomTransition", "ZoomTransitionController initialized (Modal)")
    }

    // MARK: - UIViewControllerTransitioningDelegate

    /// Present 애니메이션 (그리드 → 뷰어 줌 인)
    func animationController(
        forPresented presented: UIViewController,
        presenting: UIViewController,
        source: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        let animator = ZoomAnimator(isPresenting: true)
        animator.sourceProvider = sourceProvider
        animator.destinationProvider = destinationProvider
        Log.debug("ZoomTransition", "Present: using ZoomAnimator")
        return animator
    }

    /// Dismiss 애니메이션 (뷰어 → 그리드 줌 아웃)
    func animationController(
        forDismissed dismissed: UIViewController
    ) -> UIViewControllerAnimatedTransitioning? {
        let animator = ZoomAnimator(isPresenting: false)
        animator.sourceProvider = sourceProvider
        animator.destinationProvider = destinationProvider
        animator.isInteractiveDismiss = isInteractivelyDismissing
        Log.debug("ZoomTransition", "Dismiss: using ZoomAnimator (interactive: \(isInteractivelyDismissing))")
        return animator
    }

    /// Interactive dismiss 컨트롤러 반환
    /// isInteractivelyDismissing이 true일 때만 반환 (아니면 non-interactive dismiss)
    func interactionControllerForDismissal(
        using animator: UIViewControllerAnimatedTransitioning
    ) -> UIViewControllerInteractiveTransitioning? {
        guard isInteractivelyDismissing else { return nil }
        return interactionController
    }

    /// PresentationController 제공
    /// shouldRemovePresentersView = false로 그리드가 window에 유지됨
    func presentationController(
        forPresented presented: UIViewController,
        presenting: UIViewController?,
        source: UIViewController
    ) -> UIPresentationController? {
        return ZoomPresentationController(
            presentedViewController: presented,
            presenting: presenting
        )
    }
}

// ZoomAnimator.swift
// 줌 트랜지션 애니메이터
//
// UIViewControllerAnimatedTransitioning 구현
// - 그리드 셀 → 뷰어: 줌 인 애니메이션
// - 뷰어 → 그리드 셀: 줌 아웃 애니메이션
// - Fallback: 소스 뷰 없으면 crossfade

import UIKit
import AppCore

/// 줌 트랜지션 애니메이터
/// 그리드 ↔ 뷰어 간 줌 애니메이션 담당
final class ZoomAnimator: NSObject, UIViewControllerAnimatedTransitioning {

    // MARK: - 애니메이션 파라미터

    /// 줌 인 (Push) 애니메이션 시간
    private let pushDuration: TimeInterval = 0.35

    /// 줌 아웃 (Pop) 애니메이션 시간
    private let popDuration: TimeInterval = 0.37

    /// 스프링 댐핑 비율
    private let springDamping: CGFloat = 0.9

    // MARK: - Properties

    /// Present(true) 또는 Dismiss(false)
    let isPresenting: Bool

    /// 소스 제공자 (그리드 VC)
    weak var sourceProvider: ZoomTransitionSourceProviding?

    /// 목적지 제공자 (뷰어 VC)
    weak var destinationProvider: ZoomTransitionDestinationProviding?

    /// Interactive dismiss 여부 (ZoomTransitionController에서 설정)
    /// transitionContext.isInteractive가 호출 시점에 false일 수 있으므로 자체 플래그 사용
    var isInteractiveDismiss: Bool = false

    /// 트랜지션 모드 (.modal: 기존 Modal, .navigation: iOS 26+ Navigation Push/Pop)
    /// Modal: shouldRemovePresentersView=false로 그리드가 window에 유지
    /// Navigation: Pop 시 toView(그리드)를 container에 수동 추가 필요
    var transitionMode: TransitionMode = .modal

    /// Modal vs Navigation 트랜지션 모드
    enum TransitionMode {
        case modal       // iOS 16~25: Modal present/dismiss
        case navigation  // iOS 26+: Navigation push/pop
    }


    // MARK: - Init

    init(isPresenting: Bool) {
        self.isPresenting = isPresenting
        super.init()
    }

    // MARK: - UIViewControllerAnimatedTransitioning

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return isPresenting ? pushDuration : popDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        // ⚠️ Interactive dismiss 시에는 ZoomDismissalInteractionController가 전담
        // animateTransition이 호출되더라도 스킵 (스냅샷 중복 + 애니메이션 충돌 방지)
        // Note: transitionContext.isInteractive가 호출 시점에 false일 수 있어 자체 플래그 사용
        guard !isInteractiveDismiss else {
            return
        }

        let container = transitionContext.containerView

        // ⚠️ 1. viewController에서 view 직접 가져오기 (view(forKey:)는 nil 반환 가능)
        guard let fromVC = transitionContext.viewController(forKey: .from),
              let toVC = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        let fromView = fromVC.view!
        let toView = toVC.view!

        // ⚠️ 2. finalFrame 설정 (Modal에서 .zero일 수 있으므로 폴백)
        let finalFrame = transitionContext.finalFrame(for: toVC)
        if !finalFrame.isEmpty {
            toView.frame = finalFrame
        }

        // ⚠️ 3. container에 뷰 추가
        // Present: toView(뷰어)를 container에 추가
        // Dismiss (Modal): toView(그리드)는 추가하지 않음!
        //   shouldRemovePresentersView=false이므로 그리드는 원래 window에 남아있음
        // Dismiss (Navigation): toView(그리드)를 container 맨 뒤에 수동 추가
        //   Navigation Pop에서는 toView가 container에 자동 추가되지 않음
        if isPresenting {
            if toView.superview != container {
                container.addSubview(toView)
            }
        } else if transitionMode == .navigation {
            container.insertSubview(toView, at: 0)
        }
        // else (.modal dismiss): toView 추가 안 함 (그리드가 container 뒤에서 이미 보임)

        // ⚠️ 4. layoutIfNeeded 호출
        toView.layoutIfNeeded()

        // 현재 인덱스 가져오기
        let currentIndex = destinationProvider?.currentOriginalIndex ?? 0

        // ⚠️ Dismiss 시: 셀이 보이도록 먼저 스크롤 (기본 사진 앱 스타일)
        if !isPresenting {
            sourceProvider?.scrollToSourceCell(for: currentIndex)
            // 스크롤 후 레이아웃 즉시 반영
            toView.layoutIfNeeded()
        }

        // 소스/목적지 프레임 계산 (스크롤 후에 계산해야 정확함)
        let sourceFrame = sourceProvider?.zoomSourceFrame(for: currentIndex)
        let destinationFrame = destinationProvider?.zoomDestinationFrame

        // 소스 프레임이 없으면 crossfade
        guard let startFrame = isPresenting ? sourceFrame : destinationFrame,
              let endFrame = isPresenting ? destinationFrame : sourceFrame else {
            performCrossfade(
                transitionContext: transitionContext,
                fromView: fromView,
                toView: toView
            )
            return
        }

        // 줌 애니메이션 수행
        performZoomAnimation(
            transitionContext: transitionContext,
            container: container,
            fromView: fromView,
            toView: toView,
            startFrame: startFrame,
            endFrame: endFrame
        )
    }

    // MARK: - Crossfade (Fallback)

    /// Crossfade 애니메이션 (소스 뷰 없을 때)
    private func performCrossfade(
        transitionContext: UIViewControllerContextTransitioning,
        fromView: UIView,
        toView: UIView
    ) {
        let duration = transitionDuration(using: transitionContext)

        // Push: toView를 투명하게 시작
        // Pop: fromView를 투명하게 만들며 종료
        if isPresenting {
            toView.alpha = 0
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseInOut
        ) {
            if self.isPresenting {
                toView.alpha = 1
            } else {
                fromView.alpha = 0
            }
        } completion: { _ in
            fromView.alpha = 1
            let cancelled = transitionContext.transitionWasCancelled
            transitionContext.completeTransition(!cancelled)
        }
    }

    // MARK: - Zoom Animation

    /// 줌 애니메이션 수행
    private func performZoomAnimation(
        transitionContext: UIViewControllerContextTransitioning,
        container: UIView,
        fromView: UIView,
        toView: UIView,
        startFrame: CGRect,
        endFrame: CGRect
    ) {
        let duration = transitionDuration(using: transitionContext)
        let currentIndex = destinationProvider?.currentOriginalIndex ?? 0

        // 스냅샷 생성 (소스 뷰에서)
        let sourceView = isPresenting
            ? sourceProvider?.zoomSourceView(for: currentIndex)
            : destinationProvider?.zoomDestinationView

        // 스냅샷 이미지 뷰 생성
        let snapshotView = UIImageView()
        snapshotView.contentMode = .scaleAspectFill
        snapshotView.clipsToBounds = true
        snapshotView.frame = startFrame

        // 스냅샷 이미지 설정
        if let imageView = sourceView as? UIImageView {
            snapshotView.image = imageView.image
        } else if let view = sourceView {
            // UIImageView가 아니면 렌더링
            snapshotView.image = view.snapshotImage()
        }

        // 스냅샷이 없으면 crossfade
        guard snapshotView.image != nil else {
            performCrossfade(
                transitionContext: transitionContext,
                fromView: fromView,
                toView: toView
            )
            return
        }

        // ⚠️ 5. Push 시: 배경 뷰 추가 (스냅샷과 함께 fade in)
        var backgroundView: UIView?
        if isPresenting {
            let bg = UIView(frame: container.bounds)
            bg.backgroundColor = .black
            bg.alpha = 0
            container.addSubview(bg)
            backgroundView = bg

            // 스냅샷은 배경 위에
            container.addSubview(snapshotView)

            // toView는 완전히 숨김 (completion에서 표시)
            toView.alpha = 0
        } else {
            container.addSubview(snapshotView)
        }

        // 배경 fade 애니메이션 (별도 curve로 부드럽게)
        if isPresenting, let bg = backgroundView {
            UIView.animate(
                withDuration: duration,
                delay: 0,
                options: .curveEaseOut
            ) {
                bg.alpha = 1
            }
        }

        // 스냅샷 줌 애니메이션 (spring)
        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: springDamping,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            snapshotView.frame = endFrame

            if !self.isPresenting {
                // Pop: fromView fade out
                fromView.alpha = 0
            }
        } completion: { _ in
            // Push 시 toView 표시 및 배경 제거
            if self.isPresenting {
                toView.alpha = 1
                backgroundView?.removeFromSuperview()
            }

            snapshotView.removeFromSuperview()
            fromView.alpha = 1

            let cancelled = transitionContext.transitionWasCancelled
            transitionContext.completeTransition(!cancelled)
        }
    }
}

// MARK: - UIView Extension

private extension UIView {
    /// 뷰의 스냅샷 이미지 생성
    func snapshotImage() -> UIImage? {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { _ in
            drawHierarchy(in: bounds, afterScreenUpdates: true)
        }
    }
}

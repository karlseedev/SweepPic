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
    private let pushDuration: TimeInterval = 0.25

    /// 줌 아웃 (Pop) 애니메이션 시간
    private let popDuration: TimeInterval = 0.37

    /// 스프링 댐핑 비율
    private let springDamping: CGFloat = 0.9

    // MARK: - Properties

    /// Push(true) 또는 Pop(false)
    let isPush: Bool

    /// 소스 제공자 (그리드 VC)
    weak var sourceProvider: ZoomTransitionSourceProviding?

    /// 목적지 제공자 (뷰어 VC)
    weak var destinationProvider: ZoomTransitionDestinationProviding?

    // MARK: - Init

    init(isPush: Bool) {
        self.isPush = isPush
        super.init()
    }

    // MARK: - UIViewControllerAnimatedTransitioning

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return isPush ? pushDuration : popDuration
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        let container = transitionContext.containerView

        // ⚠️ 1. viewController에서 view 직접 가져오기 (view(forKey:)는 nil 반환 가능)
        guard let fromVC = transitionContext.viewController(forKey: .from),
              let toVC = transitionContext.viewController(forKey: .to) else {
            Log.debug("ZoomAnimator", "❌ fromVC 또는 toVC 없음")
            transitionContext.completeTransition(false)
            return
        }

        let fromView = fromVC.view!
        let toView = toVC.view!

        // ⚠️ 2. finalFrame 반드시 설정
        let finalFrame = transitionContext.finalFrame(for: toVC)
        toView.frame = finalFrame

        // ⚠️ 3. container에 뷰 추가
        if isPush {
            container.addSubview(toView)
        } else {
            container.insertSubview(toView, belowSubview: fromView)
        }

        // ⚠️ 4. layoutIfNeeded 호출
        toView.layoutIfNeeded()

        // 현재 인덱스 가져오기
        let currentIndex = destinationProvider?.currentOriginalIndex ?? 0

        // ⚠️ Pop 시: 셀이 보이도록 먼저 스크롤 (기본 사진 앱 스타일)
        if !isPush {
            sourceProvider?.scrollToSourceCell(for: currentIndex)
            // 스크롤 후 레이아웃 즉시 반영
            toView.layoutIfNeeded()
        }

        // 소스/목적지 프레임 계산 (스크롤 후에 계산해야 정확함)
        let sourceFrame = sourceProvider?.zoomSourceFrame(for: currentIndex)
        let destinationFrame = destinationProvider?.zoomDestinationFrame

        Log.debug("ZoomAnimator", "\(isPush ? "Push" : "Pop") - index: \(currentIndex)")
        Log.debug("ZoomAnimator", "sourceFrame: \(String(describing: sourceFrame))")
        Log.debug("ZoomAnimator", "destinationFrame: \(String(describing: destinationFrame))")

        // 소스 프레임이 없으면 crossfade
        guard let startFrame = isPush ? sourceFrame : destinationFrame,
              let endFrame = isPush ? destinationFrame : sourceFrame else {
            Log.debug("ZoomAnimator", "Fallback to crossfade (no frames)")
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
        if isPush {
            toView.alpha = 0
        }

        UIView.animate(
            withDuration: duration,
            delay: 0,
            options: .curveEaseInOut
        ) {
            if self.isPush {
                toView.alpha = 1
            } else {
                fromView.alpha = 0
            }
        } completion: { _ in
            fromView.alpha = 1
            let cancelled = transitionContext.transitionWasCancelled
            transitionContext.completeTransition(!cancelled)
            Log.debug("ZoomAnimator", "Crossfade completed, cancelled: \(cancelled)")
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
        let sourceView = isPush
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
            Log.debug("ZoomAnimator", "Fallback to crossfade (no snapshot)")
            performCrossfade(
                transitionContext: transitionContext,
                fromView: fromView,
                toView: toView
            )
            return
        }

        container.addSubview(snapshotView)

        // ⚠️ 5. Push 시 toView 숨기고 스냅샷만 보여줌
        if isPush {
            toView.alpha = 0
        }

        Log.debug("ZoomAnimator", "Animating from \(startFrame) to \(endFrame)")

        UIView.animate(
            withDuration: duration,
            delay: 0,
            usingSpringWithDamping: springDamping,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) {
            snapshotView.frame = endFrame
            // ⚠️ 6. Push 시 toView.alpha는 여기서 변경하지 않음!
            if !self.isPush {
                fromView.alpha = 0
            }
        } completion: { _ in
            // ⚠️ 7. Push 시 completion에서 toView 표시
            if self.isPush {
                toView.alpha = 1
            }

            snapshotView.removeFromSuperview()
            fromView.alpha = 1

            let cancelled = transitionContext.transitionWasCancelled
            transitionContext.completeTransition(!cancelled)
            Log.debug("ZoomAnimator", "Zoom completed, cancelled: \(cancelled)")
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

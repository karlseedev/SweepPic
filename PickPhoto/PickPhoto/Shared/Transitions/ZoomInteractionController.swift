// ZoomInteractionController.swift
// Interactive Dismiss 컨트롤러
//
// ⚠️ 핵심 설계 원칙:
// - UIPercentDrivenInteractiveTransition을 사용하지 않음
// - Navigation transition을 사용하지 않고 직접 transform 제어
// - 완료 시: 줌 아웃 애니메이션 후 popViewController(animated: false)
// - 취소 시: 원위치 복귀 애니메이션
//
// 이유: UIPercentDrivenInteractiveTransition은 CA 레이어 기반 애니메이션만 지원
//       ZoomAnimator의 스냅샷 기반 커스텀 애니메이션과 호환되지 않음

import UIKit
import AppCore

/// Interactive dismiss에서 현재 페이지 정보를 제공하는 프로토콜
protocol ZoomInteractionPageProviding: AnyObject {
    /// 현재 페이지의 이미지 뷰
    var currentPageImageView: UIView? { get }
    /// 현재 페이지의 줌 스케일
    var currentPageZoomScale: CGFloat { get }
    /// 현재 페이지가 상단 가장자리인지
    var currentPageIsAtTopEdge: Bool { get }
    /// 현재 표시 중인 인덱스
    var currentIndex: Int { get }
}

/// 줌 Interactive Dismiss 컨트롤러
/// Navigation transition 없이 직접 transform/alpha 제어
final class ZoomInteractionController: NSObject {

    // MARK: - Constants

    /// 드래그 거리 → 100% 완료 기준
    private let dismissDistance: CGFloat = 200

    /// 최소 스케일 (68%)
    private let minScale: CGFloat = 0.68

    /// 완료 판단 임계값 (10%)
    private let progressThreshold: CGFloat = 0.1

    /// 취소 시 애니메이션 duration
    private let cancelDuration: TimeInterval = 0.45

    /// 취소 시 스프링 damping
    private let cancelDamping: CGFloat = 0.75

    /// 완료 시 애니메이션 duration
    private let completeDuration: TimeInterval = 0.37

    /// 완료 시 스프링 damping
    private let completeDamping: CGFloat = 0.90

    // MARK: - Properties

    /// 페이지 정보 제공자 (ViewerViewController)
    weak var pageProvider: ZoomInteractionPageProviding?

    /// 소스 제공자 (그리드 VC)
    weak var sourceProvider: ZoomTransitionSourceProviding?

    /// 배경 뷰 참조
    weak var backgroundView: UIView?

    /// 팬 제스처
    private(set) lazy var panGesture: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        gesture.delegate = self
        return gesture
    }()

    /// Interactive dismiss 진행 중 여부
    private(set) var isInteracting: Bool = false

    /// 드래그 중인 이미지 뷰 참조
    private weak var draggingImageView: UIView?

    /// 이미지 뷰의 원래 transform
    private var originalTransform: CGAffineTransform = .identity

    /// 이미지 뷰의 원래 center
    private var originalCenter: CGPoint = .zero

    /// 드래그 시작 시 터치 위치
    private var initialTouchPoint: CGPoint = .zero

    /// 완료 콜백 (pop 호출)
    var onDismissComplete: (() -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        Log.debug("ZoomInteraction", "ZoomInteractionController initialized")
    }

    // MARK: - Pan Gesture Handler

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let view = gesture.view else { return }
        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            handlePanBegan(gesture)

        case .changed:
            handlePanChanged(translation: translation)

        case .ended, .cancelled:
            handlePanEnded(translation: translation, velocity: velocity, cancelled: gesture.state == .cancelled)

        default:
            break
        }
    }

    /// Pan 시작 처리
    private func handlePanBegan(_ gesture: UIPanGestureRecognizer) {
        guard let imageView = pageProvider?.currentPageImageView,
              let view = gesture.view else {
            Log.debug("ZoomInteraction", "Pan began - no imageView or view")
            return
        }

        isInteracting = true
        draggingImageView = imageView
        originalTransform = imageView.transform
        originalCenter = imageView.center
        initialTouchPoint = gesture.location(in: view)

        Log.debug("ZoomInteraction", "Pan began - center: \(originalCenter)")
    }

    /// Pan 변경 처리 - 직접 transform 제어
    private func handlePanChanged(translation: CGPoint) {
        guard let imageView = draggingImageView,
              let backgroundView = backgroundView else { return }

        // 아래로만 드래그 가능 (위로 드래그 시 progress = 0)
        let offsetY = max(0, translation.y)

        // Progress 계산 (0 ~ 1)
        let progress = min(offsetY / dismissDistance, 1.0)

        // 스케일 계산: 1.0 → minScale (0.68)
        let scale = 1 - (1 - minScale) * progress

        // Transform 적용
        // ⚠️ 중요: translation을 scale로 나눠서 보정해야 손가락 위치와 일치
        // CGAffineTransform은 오른쪽부터 적용되므로 scale → translate 순서
        let adjustedTranslation = CGPoint(
            x: translation.x / scale,
            y: translation.y / scale
        )

        imageView.transform = originalTransform
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: adjustedTranslation.x, y: adjustedTranslation.y)

        // 배경 투명도
        backgroundView.alpha = 1 - progress

        Log.debug("ZoomInteraction", "Pan changed - progress: \(String(format: "%.2f", progress)), scale: \(String(format: "%.2f", scale))")
    }

    /// Pan 종료 처리
    private func handlePanEnded(translation: CGPoint, velocity: CGPoint, cancelled: Bool) {
        guard let imageView = draggingImageView,
              let backgroundView = backgroundView else {
            isInteracting = false
            return
        }

        let offsetY = max(0, translation.y)
        let progress = min(offsetY / dismissDistance, 1.0)

        // 완료 조건: 손가락이 아래로 움직이는 중 + 진행도 10% 이상
        // 또는 빠른 속도로 아래로 스와이프
        let fingerIsMovingDownwards = velocity.y > 0
        let transitionMadeSignificantProgress = progress > progressThreshold
        let fastSwipeDown = velocity.y > 1000

        let shouldComplete = !cancelled && (fastSwipeDown || (fingerIsMovingDownwards && transitionMadeSignificantProgress))

        Log.debug("ZoomInteraction", "Pan ended - progress: \(String(format: "%.2f", progress)), velocity.y: \(String(format: "%.1f", velocity.y)), complete: \(shouldComplete)")

        if shouldComplete {
            animateToSourceFrame(imageView: imageView, backgroundView: backgroundView)
        } else {
            animateToOriginalPosition(imageView: imageView, backgroundView: backgroundView)
        }
    }

    /// 소스 프레임으로 줌 아웃 애니메이션 (완료)
    private func animateToSourceFrame(imageView: UIView, backgroundView: UIView) {
        guard let pageProvider = pageProvider,
              let sourceProvider = sourceProvider else {
            // sourceProvider 없으면 페이드 아웃 fallback
            animateFadeOutDismiss(imageView: imageView, backgroundView: backgroundView)
            return
        }

        // 소스 셀 프레임 가져오기
        let currentIndex = pageProvider.currentIndex
        guard let sourceFrame = sourceProvider.zoomSourceFrame(for: currentIndex) else {
            // 셀이 화면 밖이면 페이드 아웃 fallback
            animateFadeOutDismiss(imageView: imageView, backgroundView: backgroundView)
            return
        }

        Log.debug("ZoomInteraction", "Animate to source frame: \(sourceFrame)")

        // 현재 이미지 뷰의 window 좌표 프레임
        guard let window = imageView.window else {
            animateFadeOutDismiss(imageView: imageView, backgroundView: backgroundView)
            return
        }

        // 스냅샷 생성
        guard let snapshot = imageView.snapshotView(afterScreenUpdates: false) else {
            animateFadeOutDismiss(imageView: imageView, backgroundView: backgroundView)
            return
        }

        // 스냅샷을 window에 추가
        let currentFrameInWindow = imageView.superview?.convert(imageView.frame, to: window) ?? imageView.frame
        snapshot.frame = currentFrameInWindow
        window.addSubview(snapshot)

        // 원본 이미지 뷰 숨기기
        imageView.isHidden = true

        // 줌 아웃 애니메이션
        UIView.animate(
            withDuration: completeDuration,
            delay: 0,
            usingSpringWithDamping: completeDamping,
            initialSpringVelocity: 0,
            options: [.curveEaseOut]
        ) {
            snapshot.frame = sourceFrame
            backgroundView.alpha = 0
        } completion: { [weak self] _ in
            snapshot.removeFromSuperview()
            imageView.isHidden = false
            imageView.transform = self?.originalTransform ?? .identity

            self?.isInteracting = false
            self?.onDismissComplete?()

            Log.debug("ZoomInteraction", "Dismiss complete - animated to source")
        }
    }

    /// 페이드 아웃 dismiss (fallback)
    private func animateFadeOutDismiss(imageView: UIView, backgroundView: UIView) {
        Log.debug("ZoomInteraction", "Fallback: fade out dismiss")

        UIView.animate(
            withDuration: 0.2,
            delay: 0,
            options: [.curveEaseOut]
        ) {
            imageView.alpha = 0
            backgroundView.alpha = 0
        } completion: { [weak self] _ in
            imageView.alpha = 1
            imageView.transform = self?.originalTransform ?? .identity

            self?.isInteracting = false
            self?.onDismissComplete?()

            Log.debug("ZoomInteraction", "Dismiss complete - fade out")
        }
    }

    /// 원위치 복귀 애니메이션 (취소)
    private func animateToOriginalPosition(imageView: UIView, backgroundView: UIView) {
        Log.debug("ZoomInteraction", "Animate to original position")

        UIView.animate(
            withDuration: cancelDuration,
            delay: 0,
            usingSpringWithDamping: cancelDamping,
            initialSpringVelocity: 0,
            options: [.curveEaseOut]
        ) { [weak self] in
            imageView.transform = self?.originalTransform ?? .identity
            backgroundView.alpha = 1
        } completion: { [weak self] _ in
            self?.isInteracting = false
            Log.debug("ZoomInteraction", "Cancel complete - restored to original")
        }
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ZoomInteractionController: UIGestureRecognizerDelegate {

    /// 제스처 시작 조건
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGesture else { return true }

        // 1. 현재 페이지 상태 확인
        if let pageProvider = pageProvider {
            // 확대 상태면 dismiss 불가 (패닝으로 사용)
            guard pageProvider.currentPageZoomScale <= 1.0 else {
                Log.debug("ZoomInteraction", "shouldBegin: NO - zoomed in (scale: \(pageProvider.currentPageZoomScale))")
                return false
            }
            // 스크롤 위치가 상단이 아니면 dismiss 불가
            guard pageProvider.currentPageIsAtTopEdge else {
                Log.debug("ZoomInteraction", "shouldBegin: NO - not at top edge")
                return false
            }
        }

        // 2. 속도 기반 방향 판단
        let velocity = panGesture.velocity(in: panGesture.view)
        // 아래 방향이고 수직 성분이 더 클 때만 인식
        let shouldBegin = velocity.y > 0 && abs(velocity.y) > abs(velocity.x)

        Log.debug("ZoomInteraction", "shouldBegin: \(shouldBegin) - velocity: (\(String(format: "%.1f", velocity.x)), \(String(format: "%.1f", velocity.y)))")

        return shouldBegin
    }

    /// 다른 제스처와 동시 인식 허용
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // UIPageViewController의 스크롤뷰와는 동시 인식 허용하지 않음
        if let scrollView = otherGestureRecognizer.view as? UIScrollView,
           scrollView.isPagingEnabled {
            return false
        }
        return true
    }

    /// 제스처 실패 요구
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // UIPageViewController의 스크롤 제스처가 실패해야 이 제스처 활성화
        // → 아래 방향일 때만 이 제스처가 활성화되도록 shouldBegin에서 처리하므로 여기서는 false
        return false
    }
}

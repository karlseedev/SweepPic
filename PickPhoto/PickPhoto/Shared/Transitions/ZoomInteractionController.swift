// ZoomInteractionController.swift
// Interactive Dismiss 컨트롤러
//
// 기본 사진 앱 스타일의 아래 드래그로 닫기 구현
// - 드래그 시 이미지 스케일 + 위치 동시 변경
// - 배경 투명도 연동
// - 손가락 방향 + 진행도로 완료/취소 결정

import UIKit
import AppCore

/// Interactive Dismiss 컨트롤러
/// 뷰어에서 아래로 드래그하면 그리드로 줌 아웃되는 전환 제공
final class ZoomInteractionController: UIPercentDrivenInteractiveTransition {

    // MARK: - Constants

    /// 100% 완료가 되는 드래그 거리 (pt)
    private let dismissDistance: CGFloat = 200

    /// 최소 스케일 (68%)
    private let minScale: CGFloat = 0.68

    /// Dismiss 결정을 위한 최소 진행도 (10%)
    private let progressThreshold: CGFloat = 0.1

    /// 취소 시 스프링 duration
    private let cancelDuration: TimeInterval = 0.45

    /// 취소 시 스프링 damping
    private let cancelDamping: CGFloat = 0.75

    /// 완료 시 스프링 duration
    private let completeDuration: TimeInterval = 0.37

    /// 완료 시 스프링 damping
    private let completeDamping: CGFloat = 0.90

    // MARK: - Properties

    /// Pan 제스처 (ViewerViewController에서 설정)
    private(set) var panGesture: UIPanGestureRecognizer!

    /// 대상 뷰어 VC
    private weak var viewController: UIViewController?

    /// 현재 이미지 뷰 (애니메이션 대상)
    private weak var imageView: UIView?

    /// 배경 뷰 (투명도 조절 대상)
    private weak var backgroundView: UIView?

    /// Interactive 전환 진행 중 여부
    private(set) var isInteractive: Bool = false

    /// 드래그 시작 시 이미지 프레임 (원위치 복귀용)
    private var initialImageFrame: CGRect = .zero

    /// 드래그 시작 시 이미지 center (transform 계산용)
    private var initialImageCenter: CGPoint = .zero

    /// 현재 진행도 (0.0 ~ 1.0)
    private var currentProgress: CGFloat = 0

    /// 취소 애니메이터 (부드러운 원위치 복귀)
    private var cancelAnimator: UIViewPropertyAnimator?

    // MARK: - Callbacks

    /// Interactive 전환 시작 콜백
    var onInteractionStarted: (() -> Void)?

    /// Interactive 전환 완료/취소 콜백
    var onInteractionEnded: ((Bool) -> Void)?

    // MARK: - Init

    override init() {
        super.init()
        setupPanGesture()
    }

    // MARK: - Setup

    /// Pan 제스처 설정
    private func setupPanGesture() {
        panGesture = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        panGesture.delegate = self
    }

    /// 뷰어 VC에 연결
    /// - Parameters:
    ///   - viewController: 대상 VC
    ///   - imageView: 애니메이션 대상 이미지 뷰
    ///   - backgroundView: 투명도 조절 대상 배경 뷰
    func attach(
        to viewController: UIViewController,
        imageView: UIView?,
        backgroundView: UIView?
    ) {
        self.viewController = viewController
        self.imageView = imageView
        self.backgroundView = backgroundView

        viewController.view.addGestureRecognizer(panGesture)
        Log.debug("ZoomInteraction", "Attached to \(type(of: viewController))")
    }

    /// 이미지 뷰 업데이트 (페이지 전환 시)
    /// - Parameter imageView: 새 이미지 뷰
    func updateImageView(_ imageView: UIView?) {
        self.imageView = imageView
    }

    // MARK: - Pan Gesture Handler

    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard let viewController = viewController,
              let view = viewController.view else { return }

        let translation = gesture.translation(in: view)
        let velocity = gesture.velocity(in: view)

        switch gesture.state {
        case .began:
            handlePanBegan(viewController: viewController)

        case .changed:
            handlePanChanged(translation: translation)

        case .ended, .cancelled:
            handlePanEnded(translation: translation, velocity: velocity, gesture: gesture)

        default:
            break
        }
    }

    /// Pan 시작
    private func handlePanBegan(viewController: UIViewController) {
        // 취소 애니메이터가 실행 중이면 중단
        cancelAnimator?.stopAnimation(true)
        cancelAnimator = nil

        isInteractive = true
        currentProgress = 0

        // 초기 프레임 저장
        if let imageView = imageView {
            initialImageFrame = imageView.frame
            initialImageCenter = imageView.center
        }

        Log.debug("ZoomInteraction", "Pan began - initialCenter: \(initialImageCenter)")

        // 콜백 호출
        onInteractionStarted?()

        // Interactive pop 시작
        viewController.navigationController?.popViewController(animated: true)
    }

    /// Pan 진행
    private func handlePanChanged(translation: CGPoint) {
        guard let imageView = imageView,
              let backgroundView = backgroundView else { return }

        // 아래로만 드래그 (위로는 0으로 클램프)
        let offsetY = max(0, translation.y)

        // 진행도 계산 (0.0 ~ 1.0)
        currentProgress = min(offsetY / dismissDistance, 1.0)

        // 스케일 계산 (1.0 → minScale)
        let scale = 1 - (1 - minScale) * currentProgress

        // Transform 적용: 스케일 + 이동
        // 스케일이 적용된 상태에서 translation을 직접 적용
        imageView.transform = CGAffineTransform.identity
            .translatedBy(x: translation.x, y: offsetY)
            .scaledBy(x: scale, y: scale)

        // 배경 투명도 (1.0 → 0.0)
        backgroundView.alpha = 1 - currentProgress

        // UIPercentDrivenInteractiveTransition 업데이트
        update(currentProgress)
    }

    /// Pan 종료
    private func handlePanEnded(translation: CGPoint, velocity: CGPoint, gesture: UIGestureRecognizer) {
        // Dismiss 조건 판단
        // 1. 손가락이 아래로 움직이는 중 (velocity.y > 0)
        // 2. 진행도가 threshold 이상
        // 3. 또는 빠른 스와이프 (velocity > 1000)
        let fingerMovingDown = velocity.y > 0
        let significantProgress = currentProgress > progressThreshold
        let fastSwipe = velocity.y > 1000

        let shouldComplete = (fingerMovingDown && significantProgress) || fastSwipe

        Log.debug("ZoomInteraction", "Pan ended - progress: \(String(format: "%.2f", currentProgress)), velocity: \(velocity.y), complete: \(shouldComplete)")

        if shouldComplete {
            completeTransition()
        } else {
            cancelTransition()
        }
    }

    // MARK: - Transition Completion

    /// 전환 완료 (줌 아웃 계속)
    private func completeTransition() {
        // Spring 애니메이션으로 완료
        UIView.animate(
            withDuration: completeDuration,
            delay: 0,
            usingSpringWithDamping: completeDamping,
            initialSpringVelocity: 0,
            options: .curveEaseOut
        ) { [weak self] in
            // 최종 상태로 애니메이션 (실제 전환은 ZoomAnimator가 처리)
            self?.backgroundView?.alpha = 0
        } completion: { [weak self] _ in
            self?.finish()
            self?.cleanup(completed: true)
        }
    }

    /// 전환 취소 (원위치 복귀)
    private func cancelTransition() {
        // UIViewPropertyAnimator로 부드러운 스프링 복귀
        cancelAnimator = UIViewPropertyAnimator(
            duration: cancelDuration,
            dampingRatio: cancelDamping
        ) { [weak self] in
            guard let self = self else { return }
            self.imageView?.transform = .identity
            self.backgroundView?.alpha = 1.0
        }

        cancelAnimator?.addCompletion { [weak self] _ in
            self?.cancel()
            self?.cleanup(completed: false)
        }

        cancelAnimator?.startAnimation()
    }

    /// 정리
    private func cleanup(completed: Bool) {
        isInteractive = false
        currentProgress = 0
        initialImageFrame = .zero
        initialImageCenter = .zero

        Log.debug("ZoomInteraction", "Cleanup - completed: \(completed)")

        // 콜백 호출
        onInteractionEnded?(completed)
    }
}

// MARK: - UIGestureRecognizerDelegate

extension ZoomInteractionController: UIGestureRecognizerDelegate {

    /// 제스처 시작 조건
    /// - 아래 방향이고 수직 성분이 수평보다 클 때만 인식
    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard gestureRecognizer == panGesture else { return true }

        let velocity = panGesture.velocity(in: panGesture.view)

        // 아래 방향 (velocity.y > 0) 이고 수직 성분이 더 클 때
        let isDownward = velocity.y > 0
        let isVertical = abs(velocity.y) > abs(velocity.x)

        Log.debug("ZoomInteraction", "ShouldBegin - velocity: \(velocity), down: \(isDownward), vertical: \(isVertical)")

        return isDownward && isVertical
    }

    /// 다른 제스처와 동시 인식 여부
    /// - UIPageViewController의 좌우 스와이프와 충돌 방지
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // 다른 제스처와 동시 인식 불가 (충돌 방지)
        return false
    }

    /// 다른 제스처가 먼저 인식되었을 때
    /// - 스크롤뷰의 pan 제스처보다 우선순위 낮음 (줌 상태에서는 스크롤 우선)
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRequireFailureOf otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        // UIScrollView의 pan 제스처가 실패해야 이 제스처 인식
        // (줌 상태에서 스크롤 중일 때 dismiss 방지)
        if otherGestureRecognizer is UIPanGestureRecognizer,
           let scrollView = otherGestureRecognizer.view as? UIScrollView {
            // 스크롤뷰가 줌 중이면 스크롤 우선
            return scrollView.zoomScale > 1.0
        }
        return false
    }
}

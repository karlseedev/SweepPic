//
//  BlurPopupCardView.swift
//  PickPhoto
//
//  반투명 블러 팝업 카드 — 재사용 가능한 컴포넌트
//  UIViewPropertyAnimator로 블러 강도를 조절하여 뒤 콘텐츠 투과
//
//  사용법:
//    let card = BlurPopupCardView()
//    parentView.addSubview(card)
//    // 제약조건 설정 후
//    card.contentView 안에 콘텐츠 추가
//    card.activateBlur()  // 블러 시작
//
//  적용: TrashGatePopup, CleanupProgressView 등
//

import UIKit

// MARK: - BlurPopupCardView

/// 반투명 블러 팝업 카드
/// dimLayer(어두운 배경) + blurLayer(반투명 블러)를 결합
final class BlurPopupCardView: UIView {

    // MARK: - Constants

    /// 기본 코너 반경
    static let defaultCornerRadius: CGFloat = 20
    /// 기본 딤 알파
    static let defaultDimAlpha: CGFloat = 0.5
    /// 기본 블러 강도 (0.0 = 투명, 1.0 = 완전 불투명)
    static let defaultBlurFraction: CGFloat = 0.5

    // MARK: - UI Components

    /// 카드 뒤 어두운 배경 (카드 영역에만 딤)
    private let dimLayer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 반투명 블러 레이어 — effect는 animator로 부분 적용
    private let blurView: UIVisualEffectView = {
        let view = UIVisualEffectView(effect: nil)
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 블러 강도 제어용 animator
    private var blurAnimator: UIViewPropertyAnimator?

    /// 블러 위에 콘텐츠를 추가할 뷰
    var contentView: UIView {
        blurView.contentView
    }

    // MARK: - Init

    /// 블러 팝업 카드 생성
    /// - Parameters:
    ///   - cornerRadius: 코너 반경 (기본 20)
    ///   - dimAlpha: 딤 배경 알파 (기본 0.5)
    init(cornerRadius: CGFloat = BlurPopupCardView.defaultCornerRadius,
         dimAlpha: CGFloat = BlurPopupCardView.defaultDimAlpha) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        // 코너 및 딤 설정
        dimLayer.backgroundColor = UIColor.black.withAlphaComponent(dimAlpha)
        dimLayer.layer.cornerRadius = cornerRadius
        dimLayer.clipsToBounds = true

        blurView.layer.cornerRadius = cornerRadius

        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        blurAnimator?.stopAnimation(true)
        blurAnimator?.finishAnimation(at: .current)
    }

    // MARK: - Setup

    /// dimLayer + blurView 레이아웃
    private func setupLayers() {
        addSubview(dimLayer)
        addSubview(blurView)

        NSLayoutConstraint.activate([
            dimLayer.topAnchor.constraint(equalTo: topAnchor),
            dimLayer.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimLayer.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimLayer.bottomAnchor.constraint(equalTo: bottomAnchor),

            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Blur Control

    /// 블러 효과 활성화
    /// - Parameter fraction: 블러 강도 (0.0~1.0, 기본 0.5)
    func activateBlur(fraction: CGFloat = BlurPopupCardView.defaultBlurFraction) {
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) {
            self.blurView.effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        }
        animator.fractionComplete = fraction
        animator.pausesOnCompletion = true
        blurAnimator = animator
    }

    /// 블러 효과 해제 (deinit에서도 자동 호출)
    func deactivateBlur() {
        blurAnimator?.stopAnimation(true)
        blurAnimator?.finishAnimation(at: .current)
        blurAnimator = nil
        blurView.effect = nil
    }
}

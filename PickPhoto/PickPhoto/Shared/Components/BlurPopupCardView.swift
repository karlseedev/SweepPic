//
//  BlurPopupCardView.swift
//  PickPhoto
//
//  반투명 Glass 팝업 카드 — 재사용 가능한 컴포넌트
//  LiquidGlassEffect(iOS 18~25: Metal, iOS 26+: 네이티브)로 Glass 테두리 효과
//  dimLayer로 카드 영역 어두운 배경
//
//  사용법:
//    let card = BlurPopupCardView()
//    parentView.addSubview(card)
//    // 제약조건 설정 후
//    card.contentView 안에 콘텐츠 추가
//    card.activateBlur()  // Glass 효과 활성화
//
//  적용: TrashGatePopup, UsageGaugeDetailPopup, GracePeriodDetailPopup, CleanupProgressView 등
//

import UIKit
import LiquidGlassKit

// MARK: - BlurPopupCardView

/// Glass 효과 팝업 카드
/// dimLayer(어두운 배경) + LiquidGlassEffect(Glass 테두리)를 결합
final class BlurPopupCardView: UIView {

    // MARK: - Constants

    /// 기본 코너 반경
    static let defaultCornerRadius: CGFloat = 20

    // MARK: - UI Components

    /// 카드 뒤 어두운 배경 (카드 영역에만 딤)
    private let dimLayer: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.8)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Glass 효과 뷰 (iOS 18~25: LiquidGlassKit Metal, iOS 26+: 네이티브 UIGlassEffect)
    private lazy var glassView: AnyVisualEffectView = {
        let effect = LiquidGlassEffect(style: .regular, isNative: true)
        effect.tintColor = .white
        let view = VisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()

    /// Glass 위에 콘텐츠를 추가할 뷰
    var contentView: UIView {
        glassView.contentView
    }

    // MARK: - Init

    /// Glass 팝업 카드 생성
    /// - Parameter cornerRadius: 코너 반경 (기본 20)
    init(cornerRadius: CGFloat = BlurPopupCardView.defaultCornerRadius) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        // 코너 설정
        dimLayer.layer.cornerRadius = cornerRadius
        dimLayer.layer.cornerCurve = .continuous
        dimLayer.clipsToBounds = true

        glassView.layer.cornerRadius = cornerRadius
        glassView.layer.cornerCurve = .continuous

        // 그림자 (Glass 테두리 깊이감)
        layer.masksToBounds = false
        LiquidGlassStyle.applyShadow(to: layer, cornerRadius: cornerRadius)

        setupLayers()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    /// iOS 18~25: LiquidGlassOptimizer preload (Metal 렌더링 초기화)
    override func didMoveToWindow() {
        super.didMoveToWindow()
        if #available(iOS 26.0, *) { return }
        if window != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.window != nil else { return }
                LiquidGlassOptimizer.preload(in: self)
            }
        }
    }

    // MARK: - Setup

    /// dimLayer + glassView 레이아웃
    private func setupLayers() {
        addSubview(dimLayer)
        addSubview(glassView)

        NSLayoutConstraint.activate([
            dimLayer.topAnchor.constraint(equalTo: topAnchor),
            dimLayer.leadingAnchor.constraint(equalTo: leadingAnchor),
            dimLayer.trailingAnchor.constraint(equalTo: trailingAnchor),
            dimLayer.bottomAnchor.constraint(equalTo: bottomAnchor),

            glassView.topAnchor.constraint(equalTo: topAnchor),
            glassView.leadingAnchor.constraint(equalTo: leadingAnchor),
            glassView.trailingAnchor.constraint(equalTo: trailingAnchor),
            glassView.bottomAnchor.constraint(equalTo: bottomAnchor)
        ])
    }

    // MARK: - Blur Control

    /// Glass 효과 활성화 (호환성 유지용 — LiquidGlassEffect는 자동 활성화)
    func activateBlur(fraction: CGFloat = 0.5) {
        // LiquidGlassEffect는 addSubview 시점에 자동 렌더링
        // 기존 호출부 호환성을 위해 메서드 유지
    }

    /// Glass 효과 해제 (호환성 유지용)
    func deactivateBlur() {
        // LiquidGlassEffect는 뷰 제거 시 자동 해제
    }
}

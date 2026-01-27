// LiquidGlassPlatter.swift
// Liquid Glass 스타일 배경 Platter 컴포넌트
//
// iOS 26 TabBar 배경과 동일한 시각 효과 구현
// - LiquidGlassKit을 사용하여 굴절 효과 + 그림자 + 테두리 통합 제공
// - iOS 26+: 네이티브 UIGlassEffect 자동 사용
// - iOS 16-25: LiquidGlassKit의 Metal 기반 커스텀 구현 사용

import UIKit
import AppCore
import LiquidGlassKit

/// Liquid Glass 스타일 배경 Platter
/// TabBar, NavBar 등의 배경으로 재사용 가능
/// LiquidGlassKit의 VisualEffectView를 사용하여 iOS 26 스타일 굴절 효과 구현
final class LiquidGlassPlatter: UIView {

    // MARK: - UI Components

    /// LiquidGlassKit 기반 굴절 효과 뷰
    /// - VisualEffectView() 팩토리 함수 사용
    /// - iOS 26+: 네이티브 UIGlassEffect 자동 선택
    /// - iOS 16-25: LiquidGlassEffectView (Metal 기반) 사용
    private lazy var liquidGlassEffectView: AnyVisualEffectView = {
        // LiquidGlassEffect with .regular style
        // isNative: true -> iOS 26+에서 자동으로 네이티브 API 사용
        let effect = LiquidGlassEffect(style: .regular, isNative: true)
        // 블루톤 제거, 어둡고 투명하게 (블랙, alpha 0.2)
        effect.tintColor = UIColor(white: 0, alpha: 0.2)
        let view = VisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupUI() {
        // 코너 설정 (LiquidGlassView에도 적용됨)
        layer.cornerRadius = LiquidGlassConstants.Platter.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        // LiquidGlass EffectView 추가
        // LiquidGlassKit이 블러, 굴절, 테두리, 하이라이트를 모두 처리
        addSubview(liquidGlassEffectView)
        liquidGlassEffectView.layer.zPosition = LiquidGlassConstants.ZPosition.platterBackground

        Log.print("[LiquidGlassPlatter] Initialized with LiquidGlassKit (isNative: true)")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // liquidGlassEffectView: 전체 영역
            liquidGlassEffectView.topAnchor.constraint(equalTo: topAnchor),
            liquidGlassEffectView.leadingAnchor.constraint(equalTo: leadingAnchor),
            liquidGlassEffectView.trailingAnchor.constraint(equalTo: trailingAnchor),
            liquidGlassEffectView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }
}

// MARK: - Shadow Container

/// LiquidGlassPlatter의 그림자를 위한 컨테이너
/// LiquidGlassKit 사용 시에도 추가 그림자가 필요한 경우를 위해 유지
/// clipsToBounds가 true인 Platter 바깥에 그림자를 그리기 위해 사용
final class LiquidGlassShadowContainer: UIView {

    // MARK: - Properties

    /// 내부 Platter
    private(set) lazy var platter: LiquidGlassPlatter = {
        let view = LiquidGlassPlatter()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .clear

        // 그림자 설정 (LiquidGlassView의 그림자와 중첩될 수 있음)
        // LiquidGlassKit이 자체 그림자를 제공하지만, 더 강한 그림자가 필요한 경우 유지
        LiquidGlassStyle.applyShadow(to: layer, cornerRadius: LiquidGlassConstants.Platter.cornerRadius)

        // Platter 추가
        addSubview(platter)
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            platter.topAnchor.constraint(equalTo: topAnchor),
            platter.leadingAnchor.constraint(equalTo: leadingAnchor),
            platter.trailingAnchor.constraint(equalTo: trailingAnchor),
            platter.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // 그림자 경로 업데이트 (성능 최적화)
        if bounds.width > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: bounds,
                cornerRadius: LiquidGlassConstants.Platter.cornerRadius
            ).cgPath
        }
    }
}

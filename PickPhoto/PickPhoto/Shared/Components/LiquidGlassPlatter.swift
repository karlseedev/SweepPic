// LiquidGlassPlatter.swift
// Liquid Glass 스타일 배경 Platter 컴포넌트
//
// iOS 26 TabBar 배경과 동일한 시각 효과 구현
// - 블러 배경 (systemUltraThinMaterialDark)
// - 오버레이 (gray 0.11, alpha 0.73)
// - 테두리 (0.5pt, white 30%)
// - 그림자 (ambient shadow)
// - 스펙큘러 하이라이트

import UIKit
import AppCore

/// Liquid Glass 스타일 배경 Platter
/// TabBar, NavBar 등의 배경으로 재사용 가능
final class LiquidGlassPlatter: UIView {

    // MARK: - UI Components

    /// 블러 배경
    private lazy var backgroundBlur: UIVisualEffectView = {
        let effect = UIBlurEffect(style: LiquidGlassConstants.Blur.platterStyle)
        let view = UIVisualEffectView(effect: effect)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 배경 오버레이 (색상 보정)
    private lazy var backgroundOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(
            white: LiquidGlassConstants.Background.gray,
            alpha: LiquidGlassConstants.Background.alpha
        )
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 스펙큘러 하이라이트 레이어
    private lazy var highlightLayer: CAGradientLayer = {
        let layer = LiquidGlassStyle.createSpecularHighlightLayer()
        layer.cornerRadius = LiquidGlassConstants.Platter.cornerRadius
        return layer
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
        // 코너 설정
        layer.cornerRadius = LiquidGlassConstants.Platter.cornerRadius
        layer.cornerCurve = .continuous
        clipsToBounds = true

        // 블러 배경 추가
        addSubview(backgroundBlur)
        backgroundBlur.layer.zPosition = LiquidGlassConstants.ZPosition.platterBackground

        // 오버레이 추가
        addSubview(backgroundOverlay)

        // 하이라이트 레이어 추가
        layer.addSublayer(highlightLayer)

        // 테두리 적용
        LiquidGlassStyle.applyBorder(to: layer, cornerRadius: LiquidGlassConstants.Platter.cornerRadius)

        Log.print("[LiquidGlassPlatter] Initialized")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // backgroundBlur: 전체 영역
            backgroundBlur.topAnchor.constraint(equalTo: topAnchor),
            backgroundBlur.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundBlur.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundBlur.bottomAnchor.constraint(equalTo: bottomAnchor),

            // backgroundOverlay: 전체 영역
            backgroundOverlay.topAnchor.constraint(equalTo: topAnchor),
            backgroundOverlay.leadingAnchor.constraint(equalTo: leadingAnchor),
            backgroundOverlay.trailingAnchor.constraint(equalTo: trailingAnchor),
            backgroundOverlay.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()

        // 하이라이트 레이어 프레임 업데이트
        highlightLayer.frame = bounds
    }
}

// MARK: - Shadow Container

/// LiquidGlassPlatter의 그림자를 위한 컨테이너
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

        // 그림자 설정
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

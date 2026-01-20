import UIKit

/// iOS 16~25용 Liquid Glass 디자인 시스템 상수
enum LiquidGlassStyle {

    // MARK: - Material & Color
    static let blurStyle: UIBlurEffect.Style = .systemUltraThinMaterialDark
    static let backgroundAlpha: CGFloat = 0.12 // 배경 오버레이 (최소화)
    static let tintAlpha: CGFloat = 0.20       // 색상 틴트 농도
    
    // MARK: - Border & Surface
    static let borderWidth: CGFloat = 0.5
    static let borderAlpha: CGFloat = 0.30     // 유리 절단면 느낌을 위해 조금 더 선명하게
    static let defaultCornerRadius: CGFloat = 18

    // MARK: - Shadow (Ambient)
    static let shadowColor: UIColor = .black
    static let shadowOpacity: Float = 0.25
    static let shadowRadius: CGFloat = 16
    static let shadowOffset = CGSize(width: 0, height: 4)

    // MARK: - Icon Specs
    static let tabIconSize: CGFloat = 24
    static let actionButtonIconSize: CGFloat = 22
    static let backButtonIconSize: CGFloat = 20
    
    // MARK: - Icon Shadow (가독성 보정)
    static let iconShadowOpacity: Float = 0.3
    static let iconShadowRadius: CGFloat = 2
    static let iconShadowOffset = CGSize(width: 0, height: 1)

    // MARK: - Specular Highlight (광원 반사)
    // 버튼 상단에서 시작하여 중간에서 사라지는 화이트 그라데이션
    static let highlightTopAlpha: CGFloat = 0.15
    static let highlightBottomAlpha: CGFloat = 0.0
    static let highlightLocation: NSNumber = 0.5 // 버튼 높이의 50%까지만 빛이 맺힘

    // MARK: - Helper Methods

    /// Glass 스타일 테두리 적용
    static func applyBorder(to layer: CALayer, cornerRadius: CGFloat) {
        layer.borderWidth = borderWidth
        layer.borderColor = UIColor.white.withAlphaComponent(borderAlpha).cgColor
        layer.cornerRadius = cornerRadius
        layer.cornerCurve = .continuous // 부드러운 곡률 (iOS 13+)
    }

    /// Glass 스타일 그림자 적용
    static func applyShadow(to layer: CALayer, cornerRadius: CGFloat) {
        layer.shadowColor = shadowColor.cgColor
        layer.shadowOpacity = shadowOpacity
        layer.shadowRadius = shadowRadius
        layer.shadowOffset = shadowOffset
        
        // 성능 최적화: Shadow Path 명시
        if layer.bounds.width > 0 {
            layer.shadowPath = UIBezierPath(
                roundedRect: layer.bounds,
                cornerRadius: cornerRadius
            ).cgPath
        }
    }

    /// 아이콘 가독성 그림자
    static func applyIconShadow(to imageView: UIImageView) {
        imageView.layer.shadowColor = shadowColor.cgColor
        imageView.layer.shadowOpacity = iconShadowOpacity
        imageView.layer.shadowRadius = iconShadowRadius
        imageView.layer.shadowOffset = iconShadowOffset
        imageView.layer.masksToBounds = false
    }

    /// 스펙큘러 하이라이트 레이어 생성 (단일 생성)
    static func createSpecularHighlightLayer() -> CAGradientLayer {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.white.withAlphaComponent(highlightTopAlpha).cgColor,
            UIColor.white.withAlphaComponent(highlightBottomAlpha).cgColor
        ]
        layer.locations = [0.0, highlightLocation]
        layer.startPoint = CGPoint(x: 0.5, y: 0.0)
        layer.endPoint = CGPoint(x: 0.5, y: 1.0)
        layer.masksToBounds = true // 코너 래디어스 적용을 위해 필요
        return layer
    }
}

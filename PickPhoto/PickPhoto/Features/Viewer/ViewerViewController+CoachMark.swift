//
//  ViewerViewController+CoachMark.swift
//  PickPhoto
//
//  진단 테스트 2b: B 구조 + 작은 빨간 사각형
//

import UIKit

extension ViewerViewController {

    func scheduleViewerCoachMarkIfNeeded() {
        guard let window = view.window else { return }

        // 오버레이 (alpha 0 → 0.5초 후 페이드인)
        let overlay = UIView(frame: window.bounds)
        overlay.alpha = 0
        window.addSubview(overlay)

        // dimLayer (B와 동일)
        let dimLayer = CAShapeLayer()
        dimLayer.fillColor = UIColor.black.withAlphaComponent(0.5).cgColor
        dimLayer.fillRule = .nonZero
        dimLayer.path = UIBezierPath(rect: overlay.bounds).cgPath
        overlay.layer.addSublayer(dimLayer)

        // 빨간 사각형 (200×200, 화면 중앙) — 이동이 명확히 보이도록
        let redView = UIView(frame: CGRect(
            x: (window.bounds.width - 200) / 2,
            y: (window.bounds.height - 200) / 2,
            width: 200, height: 200
        ))
        redView.backgroundColor = .red
        redView.layer.cornerRadius = 16
        overlay.addSubview(redView)

        // 손가락
        let config = UIImage.SymbolConfiguration(pointSize: 48, weight: .regular)
        let finger = UIImageView(image: UIImage(systemName: "hand.point.up.fill", withConfiguration: config))
        finger.tintColor = .white
        finger.sizeToFit()
        finger.center = CGPoint(x: window.bounds.midX, y: window.bounds.midY + 50)
        finger.alpha = 0
        finger.transform = CGAffineTransform(scaleX: 1.1, y: 1.1)
        overlay.addSubview(finger)

        // B와 동일한 타이밍 체인
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            UIView.animate(withDuration: 0.3) {
                overlay.alpha = 1
            } completion: { _ in
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
                    finger.alpha = 1
                    finger.transform = .identity
                }) { _ in
                    UIView.animate(withDuration: 0.35, delay: 0, usingSpringWithDamping: 0.7, initialSpringVelocity: 0, options: [], animations: {
                        finger.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
                    }) { _ in
                        // 핵심: 손가락 + 빨간 사각형 동시 이동
                        UIView.animate(withDuration: 0.45) {
                            finger.center.y -= 200
                            redView.center.y -= 80
                            redView.alpha = 0.5
                        } completion: { _ in
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                overlay.removeFromSuperview()
                            }
                        }
                    }
                }
            }
        }
    }
}

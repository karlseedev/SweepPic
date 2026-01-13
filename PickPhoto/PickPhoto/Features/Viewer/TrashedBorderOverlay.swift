// TrashedBorderOverlay.swift
// 휴지통 사진 표시용 마룬 테두리 오버레이
//
// 보관함/앨범 뷰어에서 휴지통 상태 사진을 시각적으로 구분하기 위한 컴포넌트
// PhotoPageViewController, VideoPageViewController에서 공통 사용

import UIKit

/// 휴지통 사진을 나타내는 마룬 테두리 오버레이
/// - 마룬 색상 (#800000) 10pt 테두리
/// - Auto Layout 기반으로 회전/리사이즈 자동 대응
/// - 터치 이벤트 통과 (isUserInteractionEnabled = false)
final class TrashedBorderOverlay: UIView {

    // MARK: - Constants

    /// 마룬 색상 (#800000)
    private static let maroonColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)

    /// 테두리 두께 (10pt)
    private static let borderWidth: CGFloat = 10.0

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // 배경 투명 (테두리만 표시)
        backgroundColor = .clear

        // 터치 이벤트 통과 (아래 뷰에서 제스처 처리)
        isUserInteractionEnabled = false

        // 마룬 테두리 설정
        layer.borderColor = Self.maroonColor.cgColor
        layer.borderWidth = Self.borderWidth

        // 초기 상태: 숨김
        isHidden = true
        alpha = 0
    }

    // MARK: - Public API

    /// 테두리 표시/숨김
    /// - Parameters:
    ///   - visible: true면 표시, false면 숨김
    ///   - animated: true면 애니메이션 적용 (기본값 false)
    func setVisible(_ visible: Bool, animated: Bool = false) {
        if animated {
            // 표시할 때는 먼저 isHidden = false 설정
            if visible {
                isHidden = false
            }

            UIView.animate(withDuration: 0.2) {
                self.alpha = visible ? 1.0 : 0.0
            } completion: { _ in
                // 숨길 때는 애니메이션 완료 후 isHidden = true
                if !visible {
                    self.isHidden = true
                }
            }
        } else {
            alpha = visible ? 1.0 : 0.0
            isHidden = !visible
        }
    }
}

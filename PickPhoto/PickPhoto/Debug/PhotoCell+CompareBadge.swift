//
//  PhotoCell+CompareBadge.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-28.
//
//  통합 로직 테스트용 배지 표시 (DEBUG 전용)
//
//  배지 색상:
//  - ⚪ 회색 (both): 경로1 + 경로2 둘 다 해당
//  - 🔵 파랑 (path1): 경로1만 해당 (기존 로직 기반)
//  - 🟡 노랑 (path2): 경로2만 해당 (AestheticsScore 기반)
//

#if DEBUG
import UIKit

// MARK: - Compare Badge

@available(iOS 18.0, *)
extension PhotoCell {

    /// 배지 태그 (동적 생성된 뷰 식별용)
    private static let compareBadgeTag = 99999

    /// 비교 분석 배지 표시
    /// - Parameter category: 비교 카테고리 (nil이면 배지 숨김)
    func setCompareBadge(_ category: CompareCategory?) {
        // 기존 배지 제거
        if let existingBadge = contentView.viewWithTag(Self.compareBadgeTag) {
            existingBadge.removeFromSuperview()
        }

        guard let category = category else { return }

        // 배지 색상 결정
        let badgeColor: UIColor
        switch category {
        case .both:
            badgeColor = .systemGray     // ⚪ 회색 (둘 다)
        case .path1Only:
            badgeColor = .systemBlue     // 🔵 파랑 (경로1)
        case .path2Only:
            badgeColor = .systemYellow   // 🟡 노랑 (경로2)
        }

        // 배지 뷰 생성 (좌측 상단 원형) - 크기 2배
        let badgeSize: CGFloat = 24
        let badgeView = UIView()
        badgeView.tag = Self.compareBadgeTag
        badgeView.backgroundColor = badgeColor
        badgeView.layer.cornerRadius = badgeSize / 2
        badgeView.layer.borderWidth = 2.0
        badgeView.layer.borderColor = UIColor.white.cgColor
        badgeView.translatesAutoresizingMaskIntoConstraints = false

        // 그림자 효과
        badgeView.layer.shadowColor = UIColor.black.cgColor
        badgeView.layer.shadowOffset = CGSize(width: 0, height: 1)
        badgeView.layer.shadowRadius = 3
        badgeView.layer.shadowOpacity = 0.4

        contentView.addSubview(badgeView)

        NSLayoutConstraint.activate([
            badgeView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 4),
            badgeView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            badgeView.widthAnchor.constraint(equalToConstant: badgeSize),
            badgeView.heightAnchor.constraint(equalToConstant: badgeSize)
        ])
    }

    /// 비교 분석 배지 제거
    func removeCompareBadge() {
        if let existingBadge = contentView.viewWithTag(Self.compareBadgeTag) {
            existingBadge.removeFromSuperview()
        }
    }
}
#endif

//
//  PreviewBannerCell.swift
//  PickPhoto
//
//  Created by Claude on 2026-02-12.
//
//  인라인 배너 셀 — 단계 확장 시 추가분 구간 표시
//  "↓ 기준을 낮춰 N장 추가" 형태로 그리드 내 섹션 구분
//

import UIKit

/// 미리보기 그리드 내 인라인 배너 셀
///
/// 단계 확장 시 추가분의 시작 지점에 삽입되어
/// 사용자가 어디부터 추가된 사진인지 인지할 수 있게 합니다.
final class PreviewBannerCell: UICollectionViewCell {

    // MARK: - Constants

    static let reuseIdentifier = "PreviewBannerCell"

    // MARK: - UI Elements

    /// 배너 텍스트 라벨
    private let label: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 배경 컨테이너 (라운드 코너)
    private let container: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray6
        view.layer.cornerRadius = 8
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        contentView.addSubview(container)
        container.addSubview(label)

        NSLayoutConstraint.activate([
            // 컨테이너: 좌우 16pt 마진, 상하 4pt 마진
            container.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            container.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            container.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 4),
            container.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -4),

            // 라벨: 컨테이너 중앙
            label.centerXAnchor.constraint(equalTo: container.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor, constant: 12),
            label.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor, constant: -12),
        ])
    }

    // MARK: - Configuration

    /// 배너 구성
    ///
    /// - Parameter addedCount: 추가된 사진 수
    func configure(addedCount: Int) {
        label.text = "↓ 기준을 낮춰 \(addedCount)장 추가"
    }
}

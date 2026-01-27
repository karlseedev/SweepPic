// LiquidGlassTabButton.swift
// Liquid Glass 스타일 탭 버튼 컴포넌트
//
// iOS 26 TabBar 버튼과 동일한 시각 효과 구현
// - 94×54pt, 아이콘 + 레이블 수직 배치
// - 선택: systemBlue, 비선택: secondaryLabel
// - 아이콘 pointSize 28pt

import UIKit
import AppCore

/// Liquid Glass 스타일 탭 버튼
/// 아이콘 + 레이블로 구성된 탭 버튼
final class LiquidGlassTabButton: UIControl {

    // MARK: - Properties

    /// 탭 인덱스
    let tabIndex: Int

    /// 선택 상태
    var isSelectedTab: Bool = false {
        didSet {
            updateAppearance()
        }
    }

    /// 일반 아이콘 이름
    private let iconName: String

    /// 선택 시 아이콘 이름
    private let selectedIconName: String

    /// 버튼 타이틀
    private let title: String

    // MARK: - UI Components

    /// 아이콘 이미지뷰
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        let config = UIImage.SymbolConfiguration(
            pointSize: LiquidGlassConstants.TabButton.iconPointSize,
            weight: .regular
        )
        imageView.image = UIImage(systemName: iconName, withConfiguration: config)
        imageView.contentMode = .center
        imageView.tintColor = .secondaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false

        // 아이콘 그림자 적용 (가독성)
        LiquidGlassStyle.applyIconShadow(to: imageView)

        return imageView
    }()

    /// 타이틀 레이블
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: LiquidGlassConstants.TabButton.labelFontSize, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    /// 탭 버튼 초기화
    /// - Parameters:
    ///   - index: 탭 인덱스
    ///   - icon: 일반 아이콘 SF Symbol 이름
    ///   - selectedIcon: 선택 시 아이콘 SF Symbol 이름
    ///   - title: 버튼 타이틀
    init(index: Int, icon: String, selectedIcon: String, title: String) {
        self.tabIndex = index
        self.iconName = icon
        self.selectedIconName = selectedIcon
        self.title = title
        super.init(frame: .zero)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        // zPosition 설정
        layer.zPosition = LiquidGlassConstants.ZPosition.tabButton

        // 서브뷰 추가
        addSubview(iconImageView)
        addSubview(titleLabel)

        // 접근성
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button

        Log.print("[LiquidGlassTabButton] Initialized: \(title)")
    }

    private func setupConstraints() {
        let const = LiquidGlassConstants.TabButton.self

        NSLayoutConstraint.activate([
            // 아이콘: 상단 중앙
            iconImageView.topAnchor.constraint(equalTo: topAnchor, constant: const.iconTopOffset),
            iconImageView.centerXAnchor.constraint(equalTo: centerXAnchor),

            // 레이블: 아이콘 아래 중앙
            titleLabel.topAnchor.constraint(equalTo: topAnchor, constant: const.labelTopOffset),
            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.heightAnchor.constraint(equalToConstant: const.labelHeight),
        ])
    }

    // MARK: - Private Methods

    private func updateAppearance() {
        let color: UIColor = isSelectedTab ? .systemBlue : .secondaryLabel

        // 아이콘 변경
        let config = UIImage.SymbolConfiguration(
            pointSize: LiquidGlassConstants.TabButton.iconPointSize,
            weight: .regular
        )
        let iconSystemName = isSelectedTab ? selectedIconName : iconName
        iconImageView.image = UIImage(systemName: iconSystemName, withConfiguration: config)
        iconImageView.tintColor = color

        // 레이블 색상 변경
        titleLabel.textColor = color

        // 접근성 상태 업데이트
        accessibilityTraits = isSelectedTab ? [.button, .selected] : .button
    }

    // MARK: - Touch Handling

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        alpha = 0.7
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        alpha = 1.0
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        alpha = 1.0
    }
}

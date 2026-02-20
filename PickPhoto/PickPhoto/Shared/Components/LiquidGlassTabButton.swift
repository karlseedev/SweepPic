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

    /// 배지 컨테이너 (빨간 원형 배경 + 숫자)
    private lazy var badgeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .systemRed
        view.isHidden = true
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        // 그림자 효과 (가독성)
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = 0.3
        view.layer.shadowRadius = 2
        view.layer.shadowOffset = CGSize(width: 0, height: 1)
        return view
    }()

    /// 배지 숫자 라벨
    private lazy var badgeLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 11, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 배지 너비 제약조건 (숫자 길이에 따라 동적 변경)
    private var badgeWidthConstraint: NSLayoutConstraint?

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

        // 배지 추가 (아이콘 위에 표시되도록 마지막에 추가)
        addSubview(badgeContainer)
        badgeContainer.addSubview(badgeLabel)

        // 접근성
        isAccessibilityElement = true
        accessibilityLabel = title
        accessibilityTraits = .button

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

        // 배지 제약조건: 아이콘 우상단에 배치
        let badgeWidth = badgeContainer.widthAnchor.constraint(equalToConstant: 18)
        badgeWidthConstraint = badgeWidth
        NSLayoutConstraint.activate([
            badgeContainer.centerXAnchor.constraint(equalTo: iconImageView.trailingAnchor, constant: 2),
            badgeContainer.centerYAnchor.constraint(equalTo: iconImageView.topAnchor, constant: 2),
            badgeContainer.heightAnchor.constraint(equalToConstant: 18),
            badgeWidth,

            badgeLabel.centerXAnchor.constraint(equalTo: badgeContainer.centerXAnchor),
            badgeLabel.centerYAnchor.constraint(equalTo: badgeContainer.centerYAnchor),
        ])
    }

    // MARK: - Private Methods

    private func updateAppearance() {
        // 활성: systemBlue, 비활성: 흰색 100%
        // 활성: 네온 스카이 #32C8FF, 비활성: 흰색 100%
        let neonSky = UIColor(red: 50/255, green: 200/255, blue: 255/255, alpha: 1.0)
        let color: UIColor = isSelectedTab ? neonSky : .white

        // 아이콘 변경
        let config = UIImage.SymbolConfiguration(
            pointSize: LiquidGlassConstants.TabButton.iconPointSize,
            weight: .regular
        )
        let iconSystemName = isSelectedTab ? selectedIconName : iconName
        iconImageView.image = UIImage(systemName: iconSystemName, withConfiguration: config)
        iconImageView.tintColor = color

        // 아이콘 그림자 적용 (가독성)
        LiquidGlassStyle.applyIconShadow(to: iconImageView)

        // 레이블 색상 변경
        titleLabel.textColor = color

        // 접근성 상태 업데이트
        accessibilityTraits = isSelectedTab ? [.button, .selected] : .button
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // 배지를 항상 원형으로 유지
        badgeContainer.layer.cornerRadius = badgeContainer.bounds.height / 2
    }

    // MARK: - Public Methods

    /// 배지 숫자 업데이트
    /// - Parameter count: 표시할 숫자 (0이면 배지 숨김)
    func updateBadge(count: Int) {
        if count > 0 {
            // 숫자 텍스트 설정 (99+까지 표시)
            let text = count > 99 ? "99+" : "\(count)"
            badgeLabel.text = text

            // 텍스트 길이에 따라 너비 동적 조정 (최소 18pt, 패딩 포함)
            let textWidth = (text as NSString).size(withAttributes: [.font: badgeLabel.font!]).width
            let badgeWidth = max(18, textWidth + 8)
            badgeWidthConstraint?.constant = badgeWidth

            badgeContainer.isHidden = false
        } else {
            badgeContainer.isHidden = true
        }
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

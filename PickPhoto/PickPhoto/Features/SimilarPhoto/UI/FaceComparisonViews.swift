//
//  FaceComparisonViews.swift
//  PickPhoto
//
//  Created by Claude on 2026-01-19.
//  Copyright © 2026 PickPhoto. All rights reserved.
//
//  Description:
//  FaceComparisonViewController에서 사용하는 UI 컴포넌트들입니다.
//
//  포함 내용:
//  - FaceComparisonCell: 얼굴 비교 그리드 셀
//  - FaceComparisonTitleBarDelegate: 타이틀바 델리게이트
//  - FaceComparisonTitleBar: 커스텀 타이틀바 (iOS 16~25)
//

import UIKit

// MARK: - FaceComparisonCell

/// 얼굴 비교 셀
///
/// 크롭된 얼굴 이미지를 표시하고, 선택 시 체크마크 오버레이를 표시합니다.
final class FaceComparisonCell: UICollectionViewCell {

    static let reuseIdentifier = "FaceComparisonCell"

    // MARK: - Properties

    /// 현재 셀의 assetID
    private(set) var assetID: String?

    // MARK: - UI Components

    /// 얼굴 이미지 뷰
    private lazy var imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.backgroundColor = UIColor.darkGray.withAlphaComponent(0.5)
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// 선택 오버레이
    private lazy var selectionOverlay: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 체크마크 이미지
    private lazy var checkmarkView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        iv.tintColor = .systemBlue
        iv.backgroundColor = .white
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// 디버그 넘버링 라벨 (좌측 상단)
    private lazy var debugLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .bold)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
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
        contentView.addSubview(imageView)
        contentView.addSubview(selectionOverlay)
        contentView.addSubview(checkmarkView)
        contentView.addSubview(debugLabel)

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            selectionOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            selectionOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            selectionOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            selectionOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            checkmarkView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            checkmarkView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            checkmarkView.widthAnchor.constraint(equalToConstant: 24),
            checkmarkView.heightAnchor.constraint(equalToConstant: 24),

            debugLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            debugLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            debugLabel.widthAnchor.constraint(greaterThanOrEqualToConstant: 28),
            debugLabel.heightAnchor.constraint(equalToConstant: 22)
        ])
    }

    // MARK: - Configuration

    /// 셀 구성
    /// - Parameters:
    ///   - image: 얼굴 이미지
    ///   - isSelected: 선택 상태
    ///   - assetID: 사진 ID
    ///   - debugText: 디버그 넘버링 (예: "a1", "b2")
    func configure(with image: UIImage?, isSelected: Bool, assetID: String, debugText: String? = nil) {
        self.assetID = assetID
        imageView.image = image
        setSelected(isSelected)
        debugLabel.text = debugText
        debugLabel.isHidden = (debugText == nil)
    }

    /// 선택 상태 설정
    func setSelected(_ selected: Bool) {
        selectionOverlay.isHidden = !selected
        checkmarkView.isHidden = !selected
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        assetID = nil
        setSelected(false)
        debugLabel.text = nil
        debugLabel.isHidden = true
    }
}

// MARK: - FaceComparisonTitleBarDelegate

/// 얼굴 비교 타이틀바 델리게이트 (iOS 16~25)
protocol FaceComparisonTitleBarDelegate: AnyObject {
    func faceComparisonTitleBarDidTapCycle(_ titleBar: FaceComparisonTitleBar)
    func faceComparisonTitleBarDidTapClose(_ titleBar: FaceComparisonTitleBar)
    func faceComparisonTitleBarDidTapDebug(_ titleBar: FaceComparisonTitleBar)
    func faceComparisonTitleBarDidTapExtendedTest(_ titleBar: FaceComparisonTitleBar)
}

// MARK: - FaceComparisonTitleBar

/// 얼굴 비교 타이틀바 (iOS 16~25)
///
/// 상단에 블러 배경 + 타이틀 + 순환 버튼을 표시합니다.
final class FaceComparisonTitleBar: UIView {

    // MARK: - Properties

    weak var delegate: FaceComparisonTitleBarDelegate?

    // MARK: - UI Components

    private lazy var blurView: UIVisualEffectView = {
        let blur = UIBlurEffect(style: .systemThinMaterialDark)
        let view = UIVisualEffectView(effect: blur)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private lazy var closeButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "xmark")
        config.baseForegroundColor = .white
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    private lazy var cycleButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "arrow.trianglehead.2.clockwise.rotate.90")
        config.baseForegroundColor = .systemBlue
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(cycleButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Extended Fallback 테스트 버튼 (하늘색, debugButton 왼쪽)
    private lazy var extendedTestButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "sparkle.magnifyingglass")
        config.baseForegroundColor = .systemCyan
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(extendedTestButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 디버그 버튼 (cycleButton 왼쪽)
    private lazy var debugButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "ladybug")
        config.baseForegroundColor = .systemOrange
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(debugButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
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
        addSubview(blurView)
        addSubview(contentView)
        contentView.addSubview(closeButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(extendedTestButton)
        contentView.addSubview(debugButton)
        contentView.addSubview(cycleButton)

        NSLayoutConstraint.activate([
            blurView.topAnchor.constraint(equalTo: topAnchor),
            blurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            blurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            blurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.heightAnchor.constraint(equalToConstant: 44),

            closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // Extended 테스트 버튼: debugButton 왼쪽에 배치
            extendedTestButton.trailingAnchor.constraint(equalTo: debugButton.leadingAnchor, constant: -8),
            extendedTestButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // 디버그 버튼: cycleButton 왼쪽에 배치
            debugButton.trailingAnchor.constraint(equalTo: cycleButton.leadingAnchor, constant: -8),
            debugButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            cycleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cycleButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor)
        ])
    }

    // MARK: - Configuration

    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapClose(self)
    }

    @objc private func cycleButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapCycle(self)
    }

    @objc private func extendedTestButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapExtendedTest(self)
    }

    @objc private func debugButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapDebug(self)
    }
}

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

    /// 현재 셀의 assetID (configure에서 설정)
    private(set) var assetID: String?

    /// 셀 재사용 안전장치용 assetID (이미지 로드 시작 시 설정)
    var currentAssetID: String?

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
        currentAssetID = nil
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
}

// MARK: - FaceComparisonTitleBar

/// 얼굴 비교 타이틀바 (iOS 16~25)
///
/// 상단에 타이틀 + 닫기/순환 버튼을 표시합니다.
/// 버튼은 GlassIconButton 사용 (Liquid Glass 스타일)
final class FaceComparisonTitleBar: UIView {

    // MARK: - Properties

    weak var delegate: FaceComparisonTitleBarDelegate?

    // MARK: - UI Components

    /// 컨텐츠 영역
    private lazy var contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 닫기 버튼 - GlassIconButton (Liquid Glass 스타일)
    private lazy var closeButton: GlassIconButton = {
        let button = GlassIconButton(icon: "xmark", size: .medium, tintColor: .white)
        button.addTarget(self, action: #selector(closeButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 타이틀 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 다음 인물 순환 버튼 - GlassIconButton (Liquid Glass 스타일)
    private lazy var cycleButton: GlassIconButton = {
        let button = GlassIconButton(
            icon: "arrow.trianglehead.2.clockwise.rotate.90",
            size: .medium,
            tintColor: .white
        )
        button.addTarget(self, action: #selector(cycleButtonTapped), for: .touchUpInside)
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
        addSubview(contentView)
        contentView.addSubview(closeButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(cycleButton)

        NSLayoutConstraint.activate([
            // contentView: 하단 정렬, 좌우 16pt 패딩
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentView.heightAnchor.constraint(equalToConstant: 44),

            // closeButton: 좌측 정렬, 44×44 (intrinsicContentSize)
            closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            // titleLabel: 중앙 정렬
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),

            // cycleButton: 우측 정렬, 44×44 (intrinsicContentSize)
            cycleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cycleButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            cycleButton.widthAnchor.constraint(equalToConstant: 44),
            cycleButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Configuration

    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    /// 순환 버튼 활성화 상태 설정
    /// GlassIconButton은 isEnabled 변경 시 자동으로 alpha 조정
    func setCycleButtonEnabled(_ isEnabled: Bool) {
        cycleButton.isEnabled = isEnabled
    }

    // MARK: - Actions

    @objc private func closeButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapClose(self)
    }

    @objc private func cycleButtonTapped() {
        delegate?.faceComparisonTitleBarDidTapCycle(self)
    }
}

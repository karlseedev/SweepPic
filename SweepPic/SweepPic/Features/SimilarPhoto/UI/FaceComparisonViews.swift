//
//  FaceComparisonViews.swift
//  SweepPic
//
//  Created by Claude on 2026-01-19.
//  Copyright © 2026 SweepPic. All rights reserved.
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
import AppCore
import BlurUIKit

// MARK: - PaddedLabel

/// 좌우 패딩이 있는 UILabel (사진 번호 표시용)
final class PaddedLabel: UILabel {
    var horizontalPadding: CGFloat = 6

    override func drawText(in rect: CGRect) {
        let insets = UIEdgeInsets(top: 0, left: horizontalPadding, bottom: 0, right: horizontalPadding)
        super.drawText(in: rect.inset(by: insets))
    }

    override var intrinsicContentSize: CGSize {
        let size = super.intrinsicContentSize
        return CGSize(width: size.width + horizontalPadding * 2, height: size.height)
    }
}

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
        view.backgroundColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 0.6)  // Maroon #800000 (메인 그리드 삭제 대기와 동일)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 체크마크 이미지
    private lazy var checkmarkView: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(systemName: "checkmark.circle.fill")
        iv.tintColor = UIColor(red: 0.5, green: 0, blue: 0, alpha: 1)  // Maroon #800000
        iv.backgroundColor = .white
        iv.layer.cornerRadius = 12
        iv.clipsToBounds = true
        iv.isHidden = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    /// 사진 번호 라벨 (좌측 상단, 좌우 6pt 패딩)
    private lazy var debugLabel: PaddedLabel = {
        let label = PaddedLabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .white
        label.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        label.textAlignment = .center
        label.layer.cornerRadius = 4
        label.clipsToBounds = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    #if DEBUG
    /// 품질 정보 배경 (하단 반투명 딤드)
    private lazy var qualityBackground: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.7)
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 품질 정보 라벨 ("S 0.92\nN 8.5")
    private lazy var qualityLabel: UILabel = {
        let label = UILabel()
        label.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        label.textColor = .white
        label.numberOfLines = 2
        label.textAlignment = .left
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    #endif

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

        #if DEBUG
        // 품질 정보 오버레이 (하단)
        contentView.addSubview(qualityBackground)
        qualityBackground.addSubview(qualityLabel)
        NSLayoutConstraint.activate([
            qualityBackground.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            qualityBackground.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            qualityBackground.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            qualityBackground.heightAnchor.constraint(equalToConstant: 32),
            qualityLabel.leadingAnchor.constraint(equalTo: qualityBackground.leadingAnchor, constant: 6),
            qualityLabel.centerYAnchor.constraint(equalTo: qualityBackground.centerYAnchor),
        ])
        #endif
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

        if let text = debugText {
            debugLabel.attributedText = Self.styledPhotoNumberText(text)
            debugLabel.isHidden = false
        } else {
            debugLabel.attributedText = nil
            debugLabel.isHidden = true
        }
    }

    /// "Pic 3" → "Pic " regular + "3" bold 스타일 적용
    private static func styledPhotoNumberText(_ text: String) -> NSAttributedString {
        let regular = UIFont.systemFont(ofSize: 14, weight: .regular)
        let bold = UIFont.systemFont(ofSize: 14, weight: .bold)

        let attr = NSMutableAttributedString(string: text, attributes: [
            .font: regular,
            .foregroundColor: UIColor.white
        ])

        for (index, char) in text.enumerated() {
            if char.isNumber {
                attr.addAttribute(.font, value: bold, range: NSRange(location: index, length: 1))
            }
        }

        return attr
    }

    /// 이미지만 설정 (선택 상태, debugText 등 기존 상태 유지)
    /// 비동기 이미지 로드 완료 시 사용 — 선택 상태를 건드리지 않아 깜빡임 방지
    func setImage(_ image: UIImage?) {
        imageView.image = image
    }

    /// 선택 상태 설정
    func setSelected(_ selected: Bool) {
        selectionOverlay.isHidden = !selected
        checkmarkView.isHidden = !selected
    }

    #if DEBUG
    /// 품질 정보 표시 (YuNet score + SFace norm)
    /// - Parameters:
    ///   - score: YuNet 감지 신뢰도 (0~1)
    ///   - norm: SFace 임베딩 L2 norm
    func setQualityInfo(score: Float?, norm: Float?) {
        let scoreText = score.map { String(format: "S %.2f (>0.75)", $0) } ?? "S -"
        let normText = norm.map { String(format: "N %.1f (>7.0)", $0) } ?? "N -"
        qualityLabel.text = "\(scoreText)\n\(normText)"
        qualityBackground.isHidden = false
    }
    #endif

    // MARK: - Frame Access

    /// Pic 라벨의 window 좌표 frame (C-3 포커스 애니메이션용)
    func debugLabelFrameInWindow() -> CGRect? {
        guard !debugLabel.isHidden, let window = window else { return nil }
        return debugLabel.convert(debugLabel.bounds, to: window)
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        imageView.image = nil
        assetID = nil
        currentAssetID = nil
        setSelected(false)
        debugLabel.attributedText = nil
        debugLabel.isHidden = true
        #if DEBUG
        qualityLabel.text = nil
        qualityBackground.isHidden = true
        #endif
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

    /// 타이틀바 콘텐츠 높이 (safe area 제외)
    static let contentHeight: CGFloat = 44

    /// 그라데이션 추가 높이 (딤/블러가 더 아래까지 내려오도록)
    static let gradientExtension: CGFloat = 15

    /// 최대 딤 알파 (가장 어두운 부분 45%)
    private static let maxDimAlpha: CGFloat = LiquidGlassStyle.maxDimAlpha

    weak var delegate: FaceComparisonTitleBarDelegate?

    // MARK: - UI Components

    /// Progressive blur 뷰 (BlurUIKit)
    private lazy var progressiveBlurView: VariableBlurView = {
        let view = VariableBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isUserInteractionEnabled = false
        view.direction = .down
        view.maximumBlurRadius = 1.5
        view.dimmingTintColor = UIColor.black
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
        return view
    }()

    /// 그라데이션 딤 레이어 (상단 → 하단 페이드)
    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.black.withAlphaComponent(Self.maxDimAlpha).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.7).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.3).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.1).cgColor,
            UIColor.clear.cgColor
        ]
        layer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

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
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
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
        addSubview(progressiveBlurView)
        layer.addSublayer(gradientLayer)

        addSubview(contentView)
        contentView.addSubview(closeButton)
        contentView.addSubview(titleLabel)
        contentView.addSubview(cycleButton)

        NSLayoutConstraint.activate([
            progressiveBlurView.topAnchor.constraint(equalTo: topAnchor),
            progressiveBlurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressiveBlurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressiveBlurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // contentView: 하단 정렬, 좌우 16pt 패딩
            contentView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            contentView.heightAnchor.constraint(equalToConstant: Self.contentHeight),

            // closeButton: 좌측 정렬, 44×44 (intrinsicContentSize)
            closeButton.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            closeButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            closeButton.widthAnchor.constraint(equalToConstant: 44),
            closeButton.heightAnchor.constraint(equalToConstant: 44),

            // titleLabel: 중앙 정렬
            titleLabel.leadingAnchor.constraint(greaterThanOrEqualTo: closeButton.trailingAnchor, constant: 8),
            titleLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: cycleButton.leadingAnchor, constant: -8),

            // cycleButton: 우측 정렬, 44×44 (intrinsicContentSize)
            cycleButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            cycleButton.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            cycleButton.widthAnchor.constraint(equalToConstant: 44),
            cycleButton.heightAnchor.constraint(equalToConstant: 44)
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Configuration

    func setTitle(_ title: String) {
        titleLabel.text = title
    }

    func setAttributedTitle(_ title: NSAttributedString) {
        titleLabel.attributedText = title
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

    // MARK: - Hit Testing (터치 통과)

    /// 버튼만 터치 반응, 나머지 영역은 터치 통과
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let closePoint = convert(point, to: closeButton)
        if closeButton.bounds.contains(closePoint) {
            return closeButton
        }

        let cyclePoint = convert(point, to: cycleButton)
        if cycleButton.bounds.contains(cyclePoint) {
            return cycleButton
        }

        return nil
    }
}

// AlbumCell.swift
// 앨범 목록 셀
//
// T049: AlbumCell 생성
// - 썸네일 이미지 (정사각형, 라운드 코너)
// - 앨범 제목
// - 사진 수 표시
// - iOS 사진 앱 스타일

import UIKit
import Photos
import AppCore

/// 앨범 목록 셀
/// iOS 사진 앱 스타일의 앨범 셀
final class AlbumCell: UICollectionViewCell {

    // MARK: - Constants

    /// 재사용 식별자
    static let reuseIdentifier = "AlbumCell"

    /// 썸네일 코너 반경
    private static let thumbnailCornerRadius: CGFloat = 8

    // MARK: - UI Components

    /// 썸네일 이미지뷰
    private lazy var thumbnailImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        imageView.backgroundColor = .systemGray5
        imageView.layer.cornerRadius = Self.thumbnailCornerRadius
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// 앨범 제목 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .medium)
        label.textColor = .label
        label.numberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 사진 수 라벨
    private lazy var countLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 13, weight: .regular)
        label.textColor = .secondaryLabel
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 스마트 앨범 아이콘 (썸네일 위에 표시, 썸네일이 없을 때)
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isHidden = true
        return imageView
    }()

    /// 아이콘 배경 뷰 (그라데이션)
    private lazy var iconBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = .systemGray3
        view.layer.cornerRadius = Self.thumbnailCornerRadius
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        view.isHidden = true
        return view
    }()

    // MARK: - Properties

    /// 이미지 요청 ID (취소용)
    private var imageRequestID: PHImageRequestID?

    /// 현재 설정된 에셋 ID (재사용 검증용)
    private var currentAssetID: String?

    // MARK: - iOS 18+ Zoom Transition Support

    /// 실제 이미지가 로드되었는지 확인 (placeholder가 아닌 경우)
    /// iOS 18+ zoom transition에서 sourceViewProvider가 품질 체크에 사용
    var hasLoadedImage: Bool {
        return thumbnailImageView.image != nil && !thumbnailImageView.isHidden
    }

    /// 앨범 썸네일 이미지 뷰 접근자 (읽기 전용)
    /// iOS 18+ zoom transition의 sourceViewProvider에서 줌 시작점으로 사용
    var albumThumbnailImageView: UIImageView {
        return thumbnailImageView
    }

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Lifecycle

    override func prepareForReuse() {
        super.prepareForReuse()

        // 이전 이미지 요청 취소
        if let requestID = imageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            imageRequestID = nil
        }

        // UI 초기화
        thumbnailImageView.image = nil
        titleLabel.text = nil
        countLabel.text = nil
        currentAssetID = nil
        iconImageView.isHidden = true
        iconBackgroundView.isHidden = true
        thumbnailImageView.isHidden = false
    }

    // MARK: - Setup

    private func setupUI() {
        // 아이콘 배경 (썸네일 없을 때 표시)
        contentView.addSubview(iconBackgroundView)

        // 썸네일 이미지뷰
        contentView.addSubview(thumbnailImageView)

        // 아이콘 (썸네일 없을 때 표시)
        iconBackgroundView.addSubview(iconImageView)

        // 제목 라벨
        contentView.addSubview(titleLabel)

        // 사진 수 라벨
        contentView.addSubview(countLabel)

        setupConstraints()
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 썸네일: 상단에 정사각형으로 배치
            thumbnailImageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            thumbnailImageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            thumbnailImageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailImageView.heightAnchor.constraint(equalTo: thumbnailImageView.widthAnchor),

            // 아이콘 배경: 썸네일과 동일 위치
            iconBackgroundView.topAnchor.constraint(equalTo: thumbnailImageView.topAnchor),
            iconBackgroundView.leadingAnchor.constraint(equalTo: thumbnailImageView.leadingAnchor),
            iconBackgroundView.trailingAnchor.constraint(equalTo: thumbnailImageView.trailingAnchor),
            iconBackgroundView.bottomAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor),

            // 아이콘: 배경 중앙에 배치
            iconImageView.centerXAnchor.constraint(equalTo: iconBackgroundView.centerXAnchor),
            iconImageView.centerYAnchor.constraint(equalTo: iconBackgroundView.centerYAnchor),
            iconImageView.widthAnchor.constraint(equalTo: iconBackgroundView.widthAnchor, multiplier: 0.4),
            iconImageView.heightAnchor.constraint(equalTo: iconImageView.widthAnchor),

            // 제목: 썸네일 아래
            titleLabel.topAnchor.constraint(equalTo: thumbnailImageView.bottomAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            // 사진 수: 제목 아래
            countLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
            countLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            countLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
        ])
    }

    // MARK: - Configuration

    /// 사용자 앨범 설정
    /// - Parameters:
    ///   - album: 앨범 정보
    ///   - targetSize: 썸네일 크기
    func configure(album: Album, targetSize: CGSize) {
        titleLabel.text = album.title
        countLabel.text = "\(album.assetCount)"

        // 키 에셋으로 썸네일 로드
        if let keyAssetID = album.keyAssetIdentifier {
            loadThumbnail(assetID: keyAssetID, targetSize: targetSize)
        } else {
            // 키 에셋이 없으면 기본 아이콘 표시
            showIcon(systemName: "photo.on.rectangle")
        }
    }

    /// 스마트 앨범 설정
    /// - Parameters:
    ///   - smartAlbum: 스마트 앨범 정보
    ///   - targetSize: 썸네일 크기
    func configure(smartAlbum: SmartAlbum, targetSize: CGSize) {
        titleLabel.text = smartAlbum.title
        countLabel.text = "\(smartAlbum.assetCount)"

        // 키 에셋으로 썸네일 로드
        if let keyAssetID = smartAlbum.keyAssetIdentifier {
            loadThumbnail(assetID: keyAssetID, targetSize: targetSize)
        } else {
            // 키 에셋이 없으면 스마트 앨범 타입에 맞는 아이콘 표시
            showIcon(systemName: smartAlbum.type.systemIconName)
        }
    }

    /// 휴지통 앨범 설정
    /// - Parameters:
    ///   - trashAlbum: 휴지통 앨범 정보
    ///   - targetSize: 썸네일 크기
    func configure(trashAlbum: TrashAlbum, targetSize: CGSize) {
        titleLabel.text = trashAlbum.title
        countLabel.text = "\(trashAlbum.assetCount)"

        // 키 에셋으로 썸네일 로드
        if let keyAssetID = trashAlbum.keyAssetIdentifier {
            loadThumbnail(assetID: keyAssetID, targetSize: targetSize)
        } else {
            // 키 에셋이 없으면 휴지통 아이콘 표시
            showIcon(systemName: "trash")
        }
    }

    // MARK: - Private Methods

    /// 썸네일 로드
    private func loadThumbnail(assetID: String, targetSize: CGSize) {
        currentAssetID = assetID

        // PHAsset 조회
        let results = PHAsset.fetchAssets(
            withLocalIdentifiers: [assetID],
            options: nil
        )

        guard let asset = results.firstObject else {
            showIcon(systemName: "photo.on.rectangle")
            return
        }

        // 이미지 요청 옵션
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true

        // 이미지 요청
        imageRequestID = PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            guard let self = self,
                  self.currentAssetID == assetID else { return }

            DispatchQueue.main.async {
                if let image = image {
                    self.thumbnailImageView.image = image
                    self.thumbnailImageView.isHidden = false
                    self.iconBackgroundView.isHidden = true
                } else {
                    self.showIcon(systemName: "photo.on.rectangle")
                }
            }
        }
    }

    /// 아이콘 표시 (썸네일 대신)
    private func showIcon(systemName: String) {
        thumbnailImageView.isHidden = true
        iconBackgroundView.isHidden = false
        iconImageView.isHidden = false
        iconImageView.image = UIImage(systemName: systemName)
    }
}

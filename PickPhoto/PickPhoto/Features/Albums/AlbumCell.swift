// AlbumCell.swift
// 앨범 목록 셀
//
// T049: AlbumCell 생성
// - 썸네일 이미지 (정사각형, 라운드 코너)
// - 앨범 제목
// - 사진 수 표시
// - iOS 사진 앱 스타일
//
// 최적화: PHAsset 직접 전달 + ImagePipeline 사용
// - 셀마다 PHAsset.fetchAssets 동기 호출 제거
// - ImagePipeline의 PHCachingImageManager + 백그라운드 OperationQueue 활용
// - iCloud 에셋 썸네일 지원 (isNetworkAccessAllowed = true, fallback 경로)

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

    /// ImagePipeline 요청 토큰 (취소용)
    private var currentCancellable: Cancellable?

    /// 이미지 요청 ID (기존 assetID 기반 fallback용)
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

        // ImagePipeline 요청 취소
        currentCancellable?.cancel()
        currentCancellable = nil

        // 기존 PHImageManager 요청 취소 (assetID fallback용)
        if let requestID = imageRequestID {
            PHImageManager.default().cancelImageRequest(requestID)
            imageRequestID = nil
        }

        // ⚠️ thumbnailImageView.image와 currentAssetID는 유지 (깜빡임 방지)
        // reloadData() 시 같은 에셋이면 기존 이미지 유지, 다른 에셋이면 configure에서 교체
        titleLabel.text = nil
        countLabel.text = nil
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

    // MARK: - Configuration (최적화 버전 — PHAsset 직접 전달)

    /// 사용자 앨범 설정 (PHAsset 직접 전달)
    /// - keyAsset이 nil이고 keyAssetIdentifier가 있으면 기존 assetID fallback
    func configure(album: Album, keyAsset: PHAsset?, targetSize: CGSize) {
        titleLabel.text = album.title
        countLabel.text = "\(album.assetCount)"

        if let asset = keyAsset {
            // 최적화 경로: PHAsset 직접 전달 → fetch 없이 ImagePipeline 사용
            loadThumbnail(asset: asset, targetSize: targetSize)
        } else if let keyAssetID = album.keyAssetIdentifier {
            // fallback: keyAsset cache miss → 기존 assetID 기반 로드
            loadThumbnailLegacy(assetID: keyAssetID, targetSize: targetSize)
        } else {
            showIcon(systemName: "photo.on.rectangle")
        }
    }

    /// 스마트 앨범 설정 (PHAsset 직접 전달)
    /// - keyAsset이 nil이고 keyAssetIdentifier가 있으면 기존 assetID fallback
    func configure(smartAlbum: SmartAlbum, keyAsset: PHAsset?, targetSize: CGSize) {
        titleLabel.text = smartAlbum.title
        countLabel.text = "\(smartAlbum.assetCount)"

        if let asset = keyAsset {
            loadThumbnail(asset: asset, targetSize: targetSize)
        } else if let keyAssetID = smartAlbum.keyAssetIdentifier {
            loadThumbnailLegacy(assetID: keyAssetID, targetSize: targetSize)
        } else {
            showIcon(systemName: smartAlbum.type.systemIconName)
        }
    }

    // MARK: - Configuration (기존 API — 하위 호환)

    /// 사용자 앨범 설정 (기존 API — TrashAlbum 등에서 사용)
    func configure(album: Album, targetSize: CGSize) {
        titleLabel.text = album.title
        countLabel.text = "\(album.assetCount)"

        if let keyAssetID = album.keyAssetIdentifier {
            loadThumbnailLegacy(assetID: keyAssetID, targetSize: targetSize)
        } else {
            showIcon(systemName: "photo.on.rectangle")
        }
    }

    /// 스마트 앨범 설정 (기존 API)
    func configure(smartAlbum: SmartAlbum, targetSize: CGSize) {
        titleLabel.text = smartAlbum.title
        countLabel.text = "\(smartAlbum.assetCount)"

        if let keyAssetID = smartAlbum.keyAssetIdentifier {
            loadThumbnailLegacy(assetID: keyAssetID, targetSize: targetSize)
        } else {
            showIcon(systemName: smartAlbum.type.systemIconName)
        }
    }

    /// 휴지통 앨범 설정
    func configure(trashAlbum: TrashAlbum, targetSize: CGSize) {
        titleLabel.text = trashAlbum.title
        countLabel.text = "\(trashAlbum.assetCount)"

        if let keyAssetID = trashAlbum.keyAssetIdentifier {
            loadThumbnailLegacy(assetID: keyAssetID, targetSize: targetSize)
        } else {
            showIcon(systemName: "trash")
        }
    }

    // MARK: - Thumbnail Loading (최적화)

    /// 썸네일 로드 (ImagePipeline 사용 — PHAsset 직접 전달)
    /// - PHAsset.fetchAssets 동기 호출 제거
    /// - ImagePipeline의 백그라운드 큐 + PHCachingImageManager 활용
    private func loadThumbnail(asset: PHAsset, targetSize: CGSize) {
        // 같은 에셋이 이미 로드되어 있으면 스킵 (reloadData 시 깜빡임 방지)
        if currentAssetID == asset.localIdentifier && thumbnailImageView.image != nil {
            return
        }

        currentAssetID = asset.localIdentifier
        // 다른 에셋이면 기존 이미지 제거 (새 이미지 로드 전까지 placeholder 배경 표시)
        thumbnailImageView.image = nil

        // ImagePipeline을 통한 이미지 요청 (백그라운드에서 실행)
        // .fast: opportunistic 모드로 빠른 로딩 (iCloud 로컬 캐시 썸네일 사용)
        currentCancellable = ImagePipeline.shared.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            quality: .fast
        ) { [weak self] image, isDegraded in
            guard let self = self,
                  self.currentAssetID == asset.localIdentifier else { return }

            if let image = image {
                self.thumbnailImageView.image = image
                self.thumbnailImageView.isHidden = false
                self.iconBackgroundView.isHidden = true
            } else if !isDegraded {
                // 최종 결과가 nil이면 아이콘 표시
                self.showIcon(systemName: "photo.on.rectangle")
            }
        }
    }

    // MARK: - Thumbnail Loading (Legacy — assetID fallback)

    /// 썸네일 로드 (기존 방식 — assetID로 PHAsset fetch 후 로드)
    /// keyAsset cache miss 시 fallback 경로로 사용
    private func loadThumbnailLegacy(assetID: String, targetSize: CGSize) {
        // 같은 에셋이 이미 로드되어 있으면 스킵 (reloadData 시 깜빡임 방지)
        if currentAssetID == assetID && thumbnailImageView.image != nil {
            return
        }

        currentAssetID = assetID
        thumbnailImageView.image = nil

        // PHAsset 조회 (동기 — fallback이므로 허용)
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

//
//  FaceScanGroupCell.swift
//  SweepPic
//
//  인물사진 비교정리 — 그룹 셀
//
//  썸네일을 좌측부터 가로 나열, 3~4개째부터 우측 화면 밖으로 반쯤 잘림.
//  개별 썸네일 클릭 불가, 셀 전체 탭 → 그룹 선택.
//  dim 처리: alpha 0.3 + "정리 완료" 오버레이.
//
//  스타일: PhotoCell 패턴 참조
//  - 썸네일: 80×80pt, scaleAspectFill, .systemGray6 배경
//  - 간격: 4pt
//  - 좌측 패딩: 16pt
//

import UIKit
import Photos

// MARK: - FaceScanGroupCell

/// 인물사진 비교정리 그룹 셀
///
/// 각 그룹의 사진 썸네일을 가로로 나열합니다.
/// 우측으로 잘리면서 나가는 형태 (clipsToBounds).
final class FaceScanGroupCell: UITableViewCell {

    // MARK: - Constants

    /// 셀 재사용 식별자
    static let reuseIdentifier = "FaceScanGroupCell"

    /// 셀 전체 높이 (썸네일 80pt + 상하 8pt)
    static let cellHeight: CGFloat = 96

    /// 썸네일 크기
    private static let thumbnailSize: CGFloat = 80

    /// 썸네일 간격
    private static let thumbnailSpacing: CGFloat = 4

    /// 좌측 패딩
    private static let leftPadding: CGFloat = 16

    // MARK: - UI Components

    /// 썸네일 컨테이너 (가로 스택, clipsToBounds)
    private let thumbnailContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.clipsToBounds = true
        return view
    }()

    /// 썸네일 이미지뷰 배열
    private var thumbnailViews: [UIImageView] = []

    /// dim 오버레이 (정리 완료 시)
    private let dimOverlay: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        view.isHidden = true
        return view
    }()

    /// "정리 완료" 라벨
    private let completionLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .systemFont(ofSize: 14, weight: .medium)
        label.textColor = .white
        label.textAlignment = .center
        label.isHidden = true

        label.text = "정리 완료"

        return label
    }()

    // MARK: - Properties

    /// 현재 표시 중인 그룹 ID (재사용 안전장치)
    var currentGroupID: String?

    /// 이미지 매니저
    private let imageManager = PHCachingImageManager()

    /// 진행 중인 이미지 요청 ID 목록 (취소용)
    private var activeRequestIDs: [PHImageRequestID] = []

    // MARK: - Init

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Setup

    private func setupUI() {
        backgroundColor = .systemBackground
        selectionStyle = .none

        // 썸네일 컨테이너
        contentView.addSubview(thumbnailContainer)
        NSLayoutConstraint.activate([
            thumbnailContainer.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: Self.leftPadding
            ),
            thumbnailContainer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailContainer.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            thumbnailContainer.heightAnchor.constraint(equalToConstant: Self.thumbnailSize),
        ])

        // dim 오버레이
        contentView.addSubview(dimOverlay)
        NSLayoutConstraint.activate([
            dimOverlay.topAnchor.constraint(equalTo: contentView.topAnchor),
            dimOverlay.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            dimOverlay.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            dimOverlay.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // 정리 완료 라벨
        contentView.addSubview(completionLabel)
        NSLayoutConstraint.activate([
            completionLabel.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            completionLabel.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
        ])
    }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()

        // 진행 중인 이미지 요청 취소
        for requestID in activeRequestIDs {
            imageManager.cancelImageRequest(requestID)
        }
        activeRequestIDs.removeAll()

        // 썸네일 초기화
        for view in thumbnailViews {
            view.image = nil
            view.removeFromSuperview()
        }
        thumbnailViews.removeAll()

        // dim 해제
        dimOverlay.isHidden = true
        completionLabel.isHidden = true

        currentGroupID = nil
    }

    // MARK: - Configure

    /// 셀 구성
    ///
    /// - Parameters:
    ///   - group: 그룹 데이터
    ///   - isDimmed: dim 상태 (정리 완료)
    func configure(with group: FaceScanGroup, isDimmed: Bool) {
        currentGroupID = group.groupID

        // 썸네일 이미지뷰 생성
        createThumbnailViews(count: group.memberAssetIDs.count)

        // 썸네일 로딩
        loadThumbnails(assetIDs: group.memberAssetIDs)

        // dim 상태
        setDimmed(isDimmed)
    }

    /// dim 상태 설정
    func setDimmed(_ dimmed: Bool) {
        dimOverlay.isHidden = !dimmed
        completionLabel.isHidden = !dimmed
        // 썸네일 알파 조정
        thumbnailContainer.alpha = 1.0
    }

    // MARK: - Private

    /// 썸네일 이미지뷰 생성 및 배치
    private func createThumbnailViews(count: Int) {
        for i in 0..<count {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .systemGray6
            imageView.translatesAutoresizingMaskIntoConstraints = false

            thumbnailContainer.addSubview(imageView)

            let xOffset = CGFloat(i) * (Self.thumbnailSize + Self.thumbnailSpacing)

            NSLayoutConstraint.activate([
                imageView.leadingAnchor.constraint(
                    equalTo: thumbnailContainer.leadingAnchor, constant: xOffset
                ),
                imageView.topAnchor.constraint(equalTo: thumbnailContainer.topAnchor),
                imageView.widthAnchor.constraint(equalToConstant: Self.thumbnailSize),
                imageView.heightAnchor.constraint(equalToConstant: Self.thumbnailSize),
            ])

            thumbnailViews.append(imageView)
        }
    }

    /// 썸네일 로딩 (PHCachingImageManager)
    private func loadThumbnails(assetIDs: [String]) {
        let targetSize = CGSize(
            width: Self.thumbnailSize * UIScreen.main.scale,
            height: Self.thumbnailSize * UIScreen.main.scale
        )
        let options = PHImageRequestOptions()
        options.deliveryMode = .opportunistic
        options.isNetworkAccessAllowed = true

        // assetID로 PHAsset fetch
        let fetchResult = PHAsset.fetchAssets(
            withLocalIdentifiers: assetIDs,
            options: nil
        )

        // assetID 순서대로 로딩
        for (index, assetID) in assetIDs.enumerated() {
            guard index < thumbnailViews.count else { break }

            // fetchResult에서 해당 asset 찾기
            var targetAsset: PHAsset?
            fetchResult.enumerateObjects { asset, _, stop in
                if asset.localIdentifier == assetID {
                    targetAsset = asset
                    stop.pointee = true
                }
            }

            guard let asset = targetAsset else { continue }

            let groupID = currentGroupID  // 재사용 안전장치
            let requestID = imageManager.requestImage(
                for: asset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { [weak self] image, _ in
                DispatchQueue.main.async {
                    // 재사용 안전장치: 셀이 다른 그룹에 재사용되었는지 확인
                    guard let self = self,
                          self.currentGroupID == groupID,
                          index < self.thumbnailViews.count else { return }
                    self.thumbnailViews[index].image = image
                }
            }
            activeRequestIDs.append(requestID)
        }
    }
}

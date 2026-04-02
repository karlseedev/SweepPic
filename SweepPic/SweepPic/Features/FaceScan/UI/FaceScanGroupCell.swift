//
//  FaceScanGroupCell.swift
//  SweepPic
//
//  인물사진 비교정리 — 그룹 셀
//
//  썸네일을 좌측부터 가로 나열, 좌우 스크롤 가능.
//  화면에 2+2/3개 썸네일이 보여 스크롤 가능함을 암시.
//  개별 썸네일 클릭 불가, 셀 전체 탭 → 그룹 선택.
//  dim 처리: black 0.6 오버레이 + "정리 완료" 라벨.
//
//  썸네일 크기: 동적 계산 (cellWidth 기반)
//  - iPhone SE (375pt) → 131pt
//  - iPhone 16 (393pt) → 138pt
//  - iPhone Plus (430pt) → 152pt
//

import UIKit
import Photos

// MARK: - FaceScanGroupCell

/// 인물사진 비교정리 그룹 셀
///
/// 각 그룹의 사진 썸네일을 가로 스크롤뷰에 나열합니다.
/// 2+2/3개가 보여 우측에 잘린 썸네일이 스크롤 힌트 역할.
final class FaceScanGroupCell: UITableViewCell {

    // MARK: - Constants

    /// 셀 재사용 식별자
    static let reuseIdentifier = "FaceScanGroupCell"

    /// 썸네일 간격
    private static let thumbnailSpacing: CGFloat = 4

    /// 좌측 패딩
    private static let leftPadding: CGFloat = 16

    /// 상하 패딩
    private static let verticalPadding: CGFloat = 8

    // MARK: - Dynamic Size

    /// 동적 썸네일 크기 계산 (2+2/3개가 보이도록)
    /// 공식: (가용너비 - 간격×2) × 3/8
    static func thumbnailSize(for cellWidth: CGFloat) -> CGFloat {
        let available = cellWidth - leftPadding
        return floor((available - thumbnailSpacing * 2) * 3.0 / 8.0)
    }

    /// 동적 셀 높이 계산
    static func cellHeight(for cellWidth: CGFloat) -> CGFloat {
        return thumbnailSize(for: cellWidth) + verticalPadding * 2
    }

    /// 현재 셀의 썸네일 크기 (configure 시 cellWidth로부터 계산)
    private var thumbnailSize: CGFloat = 80

    // MARK: - UI Components

    /// 썸네일 가로 스크롤뷰
    private let thumbnailScrollView: UIScrollView = {
        let sv = UIScrollView()
        sv.translatesAutoresizingMaskIntoConstraints = false
        sv.showsHorizontalScrollIndicator = false
        sv.showsVerticalScrollIndicator = false
        sv.isPagingEnabled = false
        sv.alwaysBounceHorizontal = true
        sv.clipsToBounds = true
        sv.delaysContentTouches = false  // 탭 응답성 향상 (주 동작=탭, 보조=스크롤)
        return sv
    }()

    /// 스크롤뷰 높이 제약 (thumbnailSize 변경 시 업데이트)
    private var scrollViewHeightConstraint: NSLayoutConstraint?

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

    /// 상단 구분선 (2번째 셀부터 표시)
    private let topSeparator: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.backgroundColor = .separator
        view.isHidden = true
        return view
    }()

    // MARK: - Properties

    /// 상단 구분선 표시 여부 (첫 번째 셀은 false)
    var showsTopSeparator: Bool = false {
        didSet { topSeparator.isHidden = !showsTopSeparator }
    }

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

        // 스크롤뷰 탭 → 셀 선택 전달 (scrollView가 탭을 흡수하므로 수동 전달)
        let tap = UITapGestureRecognizer(target: self, action: #selector(scrollViewTapped))
        thumbnailScrollView.addGestureRecognizer(tap)

        // 상단 구분선
        contentView.addSubview(topSeparator)
        NSLayoutConstraint.activate([
            topSeparator.topAnchor.constraint(equalTo: contentView.topAnchor),
            topSeparator.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            topSeparator.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            topSeparator.heightAnchor.constraint(equalToConstant: 1.0 / UIScreen.main.scale),
        ])

        // 썸네일 스크롤뷰
        contentView.addSubview(thumbnailScrollView)
        let heightConstraint = thumbnailScrollView.heightAnchor.constraint(equalToConstant: 80)
        scrollViewHeightConstraint = heightConstraint
        NSLayoutConstraint.activate([
            thumbnailScrollView.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor, constant: Self.leftPadding
            ),
            thumbnailScrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            thumbnailScrollView.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            heightConstraint,
        ])

        // dim 오버레이 (contentView 전체 — 스크롤뷰 위에 덮음)
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

        // 스크롤 위치/크기 리셋 (재사용 시 이전 위치 잔류 방지)
        thumbnailScrollView.contentOffset = .zero
        thumbnailScrollView.contentSize = .zero

        // dim 해제
        dimOverlay.isHidden = true
        completionLabel.isHidden = true
        topSeparator.isHidden = true

        currentGroupID = nil
    }

    // MARK: - Configure

    /// 셀 구성
    ///
    /// - Parameters:
    ///   - group: 그룹 데이터
    ///   - isDimmed: dim 상태 (정리 완료)
    ///   - cellWidth: 셀 너비 (동적 썸네일 크기 계산용)
    func configure(with group: FaceScanGroup, isDimmed: Bool, cellWidth: CGFloat) {
        currentGroupID = group.groupID

        // 동적 썸네일 크기 계산
        thumbnailSize = Self.thumbnailSize(for: cellWidth)
        scrollViewHeightConstraint?.constant = thumbnailSize

        // 썸네일 이미지뷰 생성 (프레임 기반)
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
    }

    /// 스크롤뷰 탭 시 부모 tableView의 didSelectRowAt 호출
    @objc private func scrollViewTapped() {
        guard let tableView = findParentTableView(),
              let indexPath = tableView.indexPath(for: self) else { return }
        tableView.delegate?.tableView?(tableView, didSelectRowAt: indexPath)
    }

    /// 부모 tableView 탐색
    private func findParentTableView() -> UITableView? {
        var responder: UIResponder? = superview
        while let r = responder {
            if let tv = r as? UITableView { return tv }
            responder = r.next
        }
        return nil
    }

    // MARK: - Private

    /// 썸네일 이미지뷰 생성 및 배치 (프레임 기반 — UIScrollView 내부)
    private func createThumbnailViews(count: Int) {
        let size = thumbnailSize
        let spacing = Self.thumbnailSpacing

        for i in 0..<count {
            let imageView = UIImageView()
            imageView.contentMode = .scaleAspectFill
            imageView.clipsToBounds = true
            imageView.backgroundColor = .systemGray6

            let xOffset = CGFloat(i) * (size + spacing)
            imageView.frame = CGRect(x: xOffset, y: 0, width: size, height: size)

            thumbnailScrollView.addSubview(imageView)
            thumbnailViews.append(imageView)
        }

        // 전체 콘텐츠 크기 설정 (스크롤 영역)
        let totalWidth = CGFloat(count) * size + CGFloat(max(count - 1, 0)) * spacing
        thumbnailScrollView.contentSize = CGSize(width: totalWidth, height: size)
    }

    /// 썸네일 로딩 (PHCachingImageManager)
    private func loadThumbnails(assetIDs: [String]) {
        // 동적 크기에 맞춘 이미지 요청 사이즈
        let targetSize = CGSize(
            width: thumbnailSize * UIScreen.main.scale,
            height: thumbnailSize * UIScreen.main.scale
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

//
//  EffectShowcaseViewController.swift
//  PickPhoto
//
//  유사사진 코너 삼각형 뱃지 애니메이션 비교 쇼케이스
//  - 3가지 애니메이션을 각 1줄(3셀)씩 비교 표시
//  - 1줄: Diagonal Shimmer (대각선 빛 스윕)
//  - 2줄: Border Stroke (테두리 따라 도는 빛)
//  - 3줄: Glow Flash (전체 번쩍)
//  - 디버그/프리뷰 용도
//

import UIKit
import Photos

// MARK: - EffectShowcaseViewController

/// 유사사진 뱃지 애니메이션을 비교하는 쇼케이스 화면
/// 각 줄(3셀)에 동일한 애니메이션을 적용하여 시각적으로 비교
final class EffectShowcaseViewController: UIViewController {

    // MARK: - Animation Types

    /// 비교할 애니메이션 종류 (대각선 스윕, 색상 후보 3가지)
    enum AnimationType: Int, CaseIterable {
        case whiteGlow = 0   // 반투명 두꺼운 흰색 (글로우 느낌)
        case cyanShimmer     // 연한 시안/하늘색
        case blackShadow     // 반투명 검정 (어두워지는 느낌)

        /// 애니메이션 이름
        var title: String {
            switch self {
            case .whiteGlow:    return "1. White"
            case .cyanShimmer:  return "2. Cyan"
            case .blackShadow:  return "3. Black"
            }
        }

        /// 스윕 색상
        var sweepColor: UIColor {
            switch self {
            case .whiteGlow:   return UIColor.white.withAlphaComponent(0.9)
            case .cyanShimmer: return UIColor(red: 0.4, green: 0.85, blue: 1.0, alpha: 0.8)
            case .blackShadow: return UIColor.black.withAlphaComponent(0.6)
            }
        }
    }

    // MARK: - Properties

    /// 컬렉션 뷰
    private var collectionView: UICollectionView!

    /// 셀 간 간격
    private let spacing: CGFloat = 3.0

    /// 열 수
    private let columns: CGFloat = 3.0

    /// 갤러리에서 가져온 실제 사진
    private var samplePhoto: UIImage?

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        title = "애니메이션 비교"
        setupNavigationBar()
        setupCollectionView()
        loadLastPhotoFromGallery()
    }

    // MARK: - Setup

    /// 네비게이션 바 설정
    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(dismissSelf)
        )
    }

    /// 컬렉션 뷰 설정
    private func setupCollectionView() {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = spacing
        layout.minimumLineSpacing = 40
        layout.sectionInset = UIEdgeInsets(top: 20, left: spacing, bottom: 20, right: spacing)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        collectionView.register(
            EffectShowcaseCell.self,
            forCellWithReuseIdentifier: EffectShowcaseCell.reuseID
        )
        collectionView.register(
            EffectSectionHeader.self,
            forSupplementaryViewOfKind: UICollectionView.elementKindSectionHeader,
            withReuseIdentifier: EffectSectionHeader.reuseID
        )

        view.addSubview(collectionView)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    /// 갤러리에서 마지막 사진 1장 로드
    private func loadLastPhotoFromGallery() {
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = result.firstObject else { return }

        let scale = UIScreen.main.scale
        let size = cellSize()
        let targetSize = CGSize(width: size.width * scale, height: size.height * scale)

        let options = PHImageRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isSynchronous = false

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            guard let self, let image else { return }
            DispatchQueue.main.async {
                self.samplePhoto = image
                self.collectionView.reloadData()
            }
        }
    }

    /// 셀 크기 계산
    private func cellSize() -> CGSize {
        let totalSpacing = spacing * (columns + 1)
        let width = (view.bounds.width - totalSpacing) / columns
        return CGSize(width: floor(width), height: floor(width))
    }

    // MARK: - Actions

    @objc private func dismissSelf() {
        dismiss(animated: true)
    }
}

// MARK: - UICollectionViewDataSource

extension EffectShowcaseViewController: UICollectionViewDataSource {

    /// 3개 애니메이션 = 3섹션 (각 섹션 = 1줄)
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return AnimationType.allCases.count
    }

    /// 각 줄 3셀
    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        return Int(columns)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EffectShowcaseCell.reuseID,
            for: indexPath
        ) as! EffectShowcaseCell

        guard let animType = AnimationType(rawValue: indexPath.section) else { return cell }
        cell.configure(animation: animType, photo: samplePhoto)
        return cell
    }

    /// 섹션 헤더 (애니메이션 이름)
    func collectionView(
        _ collectionView: UICollectionView,
        viewForSupplementaryElementOfKind kind: String,
        at indexPath: IndexPath
    ) -> UICollectionReusableView {
        let header = collectionView.dequeueReusableSupplementaryView(
            ofKind: kind,
            withReuseIdentifier: EffectSectionHeader.reuseID,
            for: indexPath
        ) as! EffectSectionHeader

        if let animType = AnimationType(rawValue: indexPath.section) {
            // 같은 이름 3개 (한 줄에 같은 효과)
            let titles = Array(repeating: animType.title, count: Int(columns))
            header.configure(titles: titles, cellWidth: cellSize().width, spacing: spacing)
        }
        return header
    }
}

// MARK: - UICollectionViewDelegateFlowLayout

extension EffectShowcaseViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        return cellSize()
    }

    func collectionView(
        _ collectionView: UICollectionView,
        layout collectionViewLayout: UICollectionViewLayout,
        referenceSizeForHeaderInSection section: Int
    ) -> CGSize {
        return CGSize(width: collectionView.bounds.width, height: 32)
    }
}

// MARK: - EffectSectionHeader

/// 섹션 헤더: 애니메이션 이름을 셀 위에 표시
final class EffectSectionHeader: UICollectionReusableView {
    static let reuseID = "EffectSectionHeader"

    /// 라벨 스택
    private let stackView: UIStackView = {
        let sv = UIStackView()
        sv.axis = .horizontal
        sv.distribution = .fillEqually
        sv.alignment = .center
        sv.translatesAutoresizingMaskIntoConstraints = false
        return sv
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(stackView)
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: leadingAnchor),
            stackView.trailingAnchor.constraint(equalTo: trailingAnchor),
            stackView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    /// 효과 이름 설정
    func configure(titles: [String], cellWidth: CGFloat, spacing: CGFloat) {
        stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for title in titles {
            let label = UILabel()
            label.text = title
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = .white.withAlphaComponent(0.7)
            label.textAlignment = .center
            stackView.addArrangedSubview(label)
        }
    }
}

// MARK: - EffectShowcaseCell

/// 애니메이션 비교용 셀
/// 각 셀에 코너 삼각형 뱃지 + 해당 애니메이션이 적용됨
final class EffectShowcaseCell: UICollectionViewCell {
    static let reuseID = "EffectShowcaseCell"

    // MARK: - Constants

    /// 뱃지 상수 (SimilarGroupBadgeView와 동일)
    private enum BadgeConst {
        static let triangleSize: CGFloat = 28
        static let borderWidth: CGFloat = 2.0
        static let iconFontSize: CGFloat = 10
    }

    // MARK: - Subviews

    /// 사진 이미지뷰
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Badge Layers

    /// 흰색 테두리 레이어
    private let borderLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = nil
        layer.strokeColor = UIColor.white.cgColor
        layer.lineWidth = BadgeConst.borderWidth
        return layer
    }()

    /// 흰색 삼각형 레이어
    private let triangleLayer: CAShapeLayer = {
        let layer = CAShapeLayer()
        layer.fillColor = UIColor.white.cgColor
        layer.strokeColor = nil
        return layer
    }()

    /// 등호 아이콘
    private let iconLabel: UILabel = {
        let label = UILabel()
        label.text = "="
        label.font = .systemFont(ofSize: BadgeConst.iconFontSize, weight: .heavy)
        label.textColor = UIColor(white: 0.3, alpha: 1.0)
        label.textAlignment = .center
        return label
    }()

    // MARK: - Animation Layers

    /// 애니메이션용 추가 레이어들 (cleanup용 추적)
    private var animationLayers: [CALayer] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.clipsToBounds = true

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        // 뱃지 레이어 추가 (이미지 위)
        contentView.layer.addSublayer(borderLayer)
        contentView.layer.addSublayer(triangleLayer)
        contentView.addSubview(iconLabel)
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        // 애니메이션 레이어 정리
        animationLayers.forEach { $0.removeFromSuperlayer() }
        animationLayers.removeAll()
        borderLayer.removeAllAnimations()
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        updateBadgePaths()
    }

    /// 뱃지 경로 업데이트
    private func updateBadgePaths() {
        let bounds = contentView.bounds
        let inset = BadgeConst.borderWidth / 2

        // 테두리
        let borderRect = bounds.insetBy(dx: inset, dy: inset)
        borderLayer.path = UIBezierPath(rect: borderRect).cgPath
        borderLayer.frame = bounds

        // 삼각형
        let size = BadgeConst.triangleSize
        let trianglePath = UIBezierPath()
        trianglePath.move(to: CGPoint(x: bounds.width - size, y: 0))
        trianglePath.addLine(to: CGPoint(x: bounds.width, y: 0))
        trianglePath.addLine(to: CGPoint(x: bounds.width, y: size))
        trianglePath.close()
        triangleLayer.path = trianglePath.cgPath
        triangleLayer.frame = bounds

        // 아이콘 위치 (삼각형 무게중심)
        let centerX = bounds.width - size / 3
        let centerY = size / 3
        let labelSize = iconLabel.intrinsicContentSize
        iconLabel.frame = CGRect(
            x: centerX - labelSize.width / 2,
            y: centerY - labelSize.height / 2,
            width: labelSize.width,
            height: labelSize.height
        )
    }

    // MARK: - Configure

    /// 셀 구성: 사진 + 뱃지 + 애니메이션
    func configure(
        animation: EffectShowcaseViewController.AnimationType,
        photo: UIImage?
    ) {
        imageView.image = photo
        imageView.backgroundColor = .systemGray5

        // 레이아웃 완료 후 애니메이션 적용
        DispatchQueue.main.async { [weak self] in
            self?.updateBadgePaths()
            self?.applyAnimation(animation)
        }
    }

    // MARK: - Animation Application

    /// 애니메이션 적용 분기
    private func applyAnimation(
        _ type: EffectShowcaseViewController.AnimationType
    ) {
        applyDiagonalSweep(color: type.sweepColor)
    }

    // MARK: - Diagonal Sweep (대각선 빛 스윕)

    /// 대각선 방향으로 빛이 테두리+삼각형을 스윽 훑고 지나가는 애니메이션
    /// - 셀 전체에 대각선 그라데이션 오버레이를 깔고
    /// - 테두리(stroke) + 삼각형(fill) 합친 shape를 마스크로 적용
    /// - 그라데이션 locations 애니메이션으로 대각선 이동
    /// - Parameter color: 스윕 빛의 색상
    private func applyDiagonalSweep(color: UIColor) {
        let bounds = contentView.bounds
        let inset = BadgeConst.borderWidth / 2
        let size = BadgeConst.triangleSize

        // 1) 대각선 그라데이션 오버레이 (셀 전체 크기)
        //    투명 → 색상 → 투명 밴드
        let sweepGradient = CAGradientLayer()
        sweepGradient.frame = bounds
        sweepGradient.colors = [
            UIColor.clear.cgColor,
            UIColor.clear.cgColor,
            color.cgColor,
            UIColor.clear.cgColor,
            UIColor.clear.cgColor
        ]
        // 초기 위치: 밴드가 셀 완전히 밖 (좌하)
        sweepGradient.locations = [-0.5, -0.4, -0.3, -0.2, -0.1]
        // 대각선 방향 (좌하 → 우상)
        sweepGradient.startPoint = CGPoint(x: 0, y: 1)
        sweepGradient.endPoint = CGPoint(x: 1, y: 0)

        // 2) 마스크: 테두리(stroke) + 삼각형(fill) 합친 영역
        //    이 영역에서만 스윕이 보임
        let maskContainer = CALayer()
        maskContainer.frame = bounds

        // 테두리 마스크 (사각형 stroke)
        let borderMask = CAShapeLayer()
        let borderRect = bounds.insetBy(dx: inset, dy: inset)
        borderMask.path = UIBezierPath(rect: borderRect).cgPath
        borderMask.fillColor = nil
        borderMask.strokeColor = UIColor.white.cgColor
        borderMask.lineWidth = BadgeConst.borderWidth * 2.5
        borderMask.frame = bounds
        maskContainer.addSublayer(borderMask)

        // 삼각형 마스크 (우상단 삼각형 fill)
        let triangleMask = CAShapeLayer()
        let triPath = UIBezierPath()
        triPath.move(to: CGPoint(x: bounds.width - size, y: 0))
        triPath.addLine(to: CGPoint(x: bounds.width, y: 0))
        triPath.addLine(to: CGPoint(x: bounds.width, y: size))
        triPath.close()
        triangleMask.path = triPath.cgPath
        triangleMask.fillColor = UIColor.white.cgColor
        triangleMask.frame = bounds
        maskContainer.addSublayer(triangleMask)

        sweepGradient.mask = maskContainer

        contentView.layer.addSublayer(sweepGradient)
        animationLayers.append(sweepGradient)

        // 3) locations 애니메이션: 좌하 → 우상으로 밴드 이동
        let locAnim = CABasicAnimation(keyPath: "locations")
        locAnim.fromValue = [-0.5, -0.4, -0.3, -0.2, -0.1]
        locAnim.toValue = [1.1, 1.2, 1.3, 1.4, 1.5]
        locAnim.duration = 1.0
        locAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)

        // 대기 포함 반복 (1.0초 스윕 + 2.0초 대기)
        let group = CAAnimationGroup()
        group.animations = [locAnim]
        group.duration = 3.0
        group.repeatCount = .infinity
        sweepGradient.add(group, forKey: "diagonalSweep")
    }
}

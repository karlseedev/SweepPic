//
//  EffectShowcaseViewController.swift
//  PickPhoto
//
//  유사사진 그룹 표시 효과 비교 쇼케이스
//  - 8가지 효과를 3열 그리드로 비교 표시
//  - 각 행마다 효과 이름 라벨 포함
//  - 디버그/프리뷰 용도
//

import UIKit
import Photos

// MARK: - EffectShowcaseViewController

/// 유사사진 그룹 표시 효과를 비교하는 쇼케이스 화면
/// 각 셀에 서로 다른 효과를 적용하여 시각적으로 비교 가능
final class EffectShowcaseViewController: UIViewController {

    // MARK: - Effect Types

    /// 비교할 효과 종류
    enum EffectType: Int, CaseIterable {
        case currentShimmer = 0    // 현재 방식 (shimmer border)
        case stackedCards          // 겹친 카드
        case softShadowPulse      // 그림자 맥동
        case cornerAccentDots     // 코너 도트
        case frostedGlassBadge    // 글래스 뱃지
        case colorTintEdge        // 가장자리 틴트
        case scaleBadge           // 크기 + 뱃지
        case intelligenceGlow     // Apple Intelligence Glow

        /// 효과 이름
        var title: String {
            switch self {
            case .currentShimmer:   return "현재 (Shimmer)"
            case .stackedCards:     return "Stacked Cards"
            case .softShadowPulse:  return "Shadow Pulse"
            case .cornerAccentDots: return "Corner Dots"
            case .frostedGlassBadge: return "Glass+Gradient"
            case .colorTintEdge:    return "Gradient Badge"
            case .scaleBadge:       return "Scale + Badge"
            case .intelligenceGlow: return "Intelligence Glow"
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
        title = "효과 비교"
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
        layout.minimumLineSpacing = 40 // 행 간격 (라벨 공간 포함)
        layout.sectionInset = UIEdgeInsets(top: 20, left: spacing, bottom: 20, right: spacing)

        collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .black
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        // 셀 등록
        collectionView.register(
            EffectShowcaseCell.self,
            forCellWithReuseIdentifier: EffectShowcaseCell.reuseID
        )
        // 섹션 헤더 등록
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
        // 최신순 정렬로 마지막 사진 1장 fetch
        let fetchOptions = PHFetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        fetchOptions.fetchLimit = 1

        let result = PHAsset.fetchAssets(with: .image, options: fetchOptions)
        guard let asset = result.firstObject else { return }

        // 셀 크기에 맞게 썸네일 요청
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

    /// 효과 3개씩 묶어서 섹션으로 표시 (한 줄 = 한 섹션)
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        // 8개 효과 / 3열 = 3섹션 (마지막 섹션은 2개)
        return Int(ceil(Double(EffectType.allCases.count) / Double(Int(columns))))
    }

    func collectionView(
        _ collectionView: UICollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        let totalEffects = EffectType.allCases.count
        let startIndex = section * Int(columns)
        let remaining = totalEffects - startIndex
        return min(Int(columns), remaining)
    }

    func collectionView(
        _ collectionView: UICollectionView,
        cellForItemAt indexPath: IndexPath
    ) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(
            withReuseIdentifier: EffectShowcaseCell.reuseID,
            for: indexPath
        ) as! EffectShowcaseCell

        // 효과 인덱스 계산
        let effectIndex = indexPath.section * Int(columns) + indexPath.item
        guard let effect = EffectType(rawValue: effectIndex) else { return cell }

        // 셀에 효과 적용 (갤러리 사진 사용)
        cell.configure(effect: effect, photo: samplePhoto)

        return cell
    }

    /// 섹션 헤더 (효과 이름들)
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

        // 이 섹션에 해당하는 효과 이름들 수집
        let startIndex = indexPath.section * Int(columns)
        let count = collectionView.numberOfItems(inSection: indexPath.section)
        var titles: [String] = []
        for i in 0..<count {
            if let effect = EffectType(rawValue: startIndex + i) {
                titles.append(effect.title)
            }
        }
        header.configure(titles: titles, cellWidth: cellSize().width, spacing: spacing)
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

/// 섹션 헤더: 효과 이름을 셀 위에 표시
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
        // 기존 라벨 제거
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

/// 효과 비교용 셀
/// 각 셀에 서로 다른 효과가 적용됨
final class EffectShowcaseCell: UICollectionViewCell {
    static let reuseID = "EffectShowcaseCell"

    // MARK: - Subviews

    /// 샘플 이미지뷰 (사진 대신 색상 사각형)
    private let imageView: UIImageView = {
        let iv = UIImageView()
        iv.contentMode = .scaleAspectFill
        iv.clipsToBounds = true
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // MARK: - Effect Layers & Views

    /// 현재 shimmer 테두리 (효과 0)
    private var shimmerLayer: BorderAnimationLayer?

    /// Stacked cards 뒤 레이어들 (효과 1)
    private var stackLayers: [CALayer] = []

    /// Shadow pulse 레이어 (효과 2)
    private var shadowPulseActive = false

    /// Corner dots (효과 3)
    private var dotViews: [UIView] = []

    /// Glass badge (효과 4)
    private var glassBadge: UIVisualEffectView?

    /// Tint gradient (효과 5)
    private var tintGradientLayer: CAGradientLayer?

    /// Scale badge (효과 6)
    private var badgeLabel: UILabel?

    /// Intelligence glow 레이어들 (효과 7)
    private var glowLayers: [CAShapeLayer] = []

    // MARK: - Init

    override init(frame: CGRect) {
        super.init(frame: frame)
        contentView.addSubview(imageView)
        contentView.clipsToBounds = false
        clipsToBounds = false

        NSLayoutConstraint.activate([
            imageView.topAnchor.constraint(equalTo: contentView.topAnchor),
            imageView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            imageView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    // MARK: - Reuse

    override func prepareForReuse() {
        super.prepareForReuse()
        clearAllEffects()
    }

    // MARK: - Configure

    /// 효과 적용
    /// - Parameters:
    ///   - effect: 적용할 효과 종류
    ///   - photo: 갤러리에서 가져온 실제 사진 (nil이면 플레이스홀더)
    func configure(effect: EffectShowcaseViewController.EffectType, photo: UIImage?) {
        // 실제 갤러리 사진 또는 플레이스홀더 설정
        imageView.image = photo
        imageView.backgroundColor = .systemGray5

        // 레이아웃 후 효과 적용
        DispatchQueue.main.async { [weak self] in
            self?.applyEffect(effect)
        }
    }

    // MARK: - Effect Application

    /// 효과 적용 분기
    private func applyEffect(_ effect: EffectShowcaseViewController.EffectType) {
        switch effect {
        case .currentShimmer:   applyCurrentShimmer()
        case .stackedCards:     applyStackedCards()
        case .softShadowPulse:  applySoftShadowPulse()
        case .cornerAccentDots: applyCornerAccentDots()
        case .frostedGlassBadge: applyFrostedGlassBadge()
        case .colorTintEdge:    applyColorTintEdge()
        case .scaleBadge:       applyScaleBadge()
        case .intelligenceGlow: applyIntelligenceGlow()
        }
    }

    // MARK: - Effect 0: Current Shimmer Border

    /// 현재 shimmer 테두리 효과 (기존 BorderAnimationLayer 사용)
    private func applyCurrentShimmer() {
        let layer = BorderAnimationLayer.create(with: contentView.bounds)
        contentView.layer.addSublayer(layer)
        layer.startAnimation()
        shimmerLayer = layer
    }

    // MARK: - Effect 1: Stacked Cards

    /// 겹친 카드 효과
    /// - 셀 뒤에 2장의 카드가 살짝 기울어져 보임
    /// - 우측 상단에 숫자 뱃지
    private func applyStackedCards() {
        let bounds = contentView.bounds

        // 뒤쪽 카드 2장 생성 (아래→위 순서)
        let offsets: [(dx: CGFloat, dy: CGFloat, angle: CGFloat)] = [
            (3, -2, 3),   // 맨 뒤: 오른쪽으로 3pt, 위로 2pt, 3도 회전
            (1.5, -1, -2) // 중간: 오른쪽으로 1.5pt, 위로 1pt, -2도 회전
        ]

        for (i, offset) in offsets.enumerated() {
            let card = CALayer()
            card.frame = bounds
            card.backgroundColor = UIColor.white.withAlphaComponent(0.15).cgColor
            card.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
            card.borderWidth = 0.5

            // 회전 + 이동 변환 적용
            var transform = CATransform3DIdentity
            transform = CATransform3DTranslate(transform, offset.dx, offset.dy, 0)
            transform = CATransform3DRotate(
                transform, offset.angle * .pi / 180, 0, 0, 1
            )
            card.transform = transform

            // 셀 뒤에 삽입 (imageView 아래)
            contentView.layer.insertSublayer(card, at: UInt32(i))
            stackLayers.append(card)
        }

        // 숫자 뱃지 추가
        addCountBadge(count: 3, position: .topRight)
    }

    // MARK: - Effect 2: Soft Shadow Pulse

    /// 은은한 그림자 맥동 효과
    /// - 셀 아래에 accent 색상 그림자가 부드럽게 밝아졌다 어두워짐
    private func applySoftShadowPulse() {
        // 그림자 기본 설정
        contentView.layer.shadowColor = UIColor.systemBlue.cgColor
        contentView.layer.shadowOffset = CGSize(width: 0, height: 0)
        contentView.layer.shadowRadius = 6
        contentView.layer.shadowOpacity = 0.4

        // 그림자 경로 설정 (성능 최적화)
        contentView.layer.shadowPath = UIBezierPath(rect: contentView.bounds).cgPath

        // opacity 맥동 애니메이션
        let opacityAnim = CABasicAnimation(keyPath: "shadowOpacity")
        opacityAnim.fromValue = 0.3
        opacityAnim.toValue = 0.7
        opacityAnim.duration = 1.5
        opacityAnim.autoreverses = true
        opacityAnim.repeatCount = .infinity
        opacityAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentView.layer.add(opacityAnim, forKey: "shadowPulse")

        // radius 맥동 애니메이션
        let radiusAnim = CABasicAnimation(keyPath: "shadowRadius")
        radiusAnim.fromValue = 4
        radiusAnim.toValue = 10
        radiusAnim.duration = 1.5
        radiusAnim.autoreverses = true
        radiusAnim.repeatCount = .infinity
        radiusAnim.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        contentView.layer.add(radiusAnim, forKey: "shadowRadiusPulse")

        shadowPulseActive = true
    }

    // MARK: - Effect 3: Corner Accent Dots

    /// 코너 포인트 인디케이터
    /// - 좌하단에 작은 도트 3개로 그룹 사진 수 표시
    /// - 순차 fade-in + breathing 애니메이션
    private func applyCornerAccentDots() {
        let dotSize: CGFloat = 5
        let dotSpacing: CGFloat = 4
        let dotCount = 3
        let margin: CGFloat = 6

        for i in 0..<dotCount {
            let dot = UIView()
            dot.backgroundColor = .systemBlue
            dot.layer.cornerRadius = dotSize / 2
            dot.alpha = 0

            let x = margin + CGFloat(i) * (dotSize + dotSpacing)
            let y = contentView.bounds.height - margin - dotSize
            dot.frame = CGRect(x: x, y: y, width: dotSize, height: dotSize)

            contentView.addSubview(dot)
            dotViews.append(dot)

            // 순차 fade-in (0.1초 간격)
            UIView.animate(
                withDuration: 0.3,
                delay: Double(i) * 0.1,
                options: .curveEaseOut
            ) {
                dot.alpha = 1.0
            } completion: { _ in
                // breathing 애니메이션
                UIView.animate(
                    withDuration: 1.2,
                    delay: 0,
                    options: [.repeat, .autoreverse, .curveEaseInOut]
                ) {
                    dot.alpha = 0.5
                }
            }
        }
    }

    // MARK: - Effect 4: Glass Badge + 색상 변화 (방법 1)

    /// 블러 뱃지의 배경색이 Intelligence Glow 색상으로 순환
    private func applyFrostedGlassBadge() {
        let badgeSize = CGSize(width: 36, height: 22)
        let margin: CGFloat = 4

        // 블러 이펙트 뷰
        let blurView = UIVisualEffectView(effect: UIBlurEffect(style: .systemUltraThinMaterialDark))
        blurView.frame = CGRect(
            x: contentView.bounds.width - badgeSize.width - margin,
            y: margin,
            width: badgeSize.width,
            height: badgeSize.height
        )
        blurView.layer.cornerRadius = 6
        blurView.clipsToBounds = true
        blurView.alpha = 0

        // 배경색을 블러 contentView에 직접 설정
        blurView.contentView.backgroundColor = UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 0.4)

        // 숫자 라벨
        let label = UILabel()
        label.text = "⊞ 3"
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.frame = blurView.contentView.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        blurView.contentView.addSubview(label)

        contentView.addSubview(blurView)
        glassBadge = blurView

        // fade-in
        UIView.animate(withDuration: 0.4) {
            blurView.alpha = 1.0
        }

        // 배경색 순환 애니메이션 (Intelligence Glow 4색)
        let colors: [UIColor] = [
            UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 0.4),  // 보라
            UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 0.4),  // 핑크
            UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 0.4),  // 파랑
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.4),  // 오렌지
        ]
        loopBackgroundColor(view: blurView.contentView, colors: colors, index: 0)
    }

    /// 배경색 순환 헬퍼
    private func loopBackgroundColor(view: UIView, colors: [UIColor], index: Int) {
        let next = (index + 1) % colors.count
        UIView.animate(withDuration: 1.5, delay: 0, options: .curveEaseInOut) {
            view.backgroundColor = colors[next]
        } completion: { [weak self] _ in
            self?.loopBackgroundColor(view: view, colors: colors, index: next)
        }
    }

    // MARK: - Effect 5: Gradient Badge Direct (방법 2)

    /// 그라데이션을 직접 뱃지 배경으로 사용 (블러 없음, 선명한 색상 변화)
    /// - CAGradientLayer가 뱃지 배경 자체
    /// - Intelligence Glow 4색이 직접 보임
    private func applyColorTintEdge() {
        let badgeSize = CGSize(width: 36, height: 22)
        let margin: CGFloat = 4
        let badgeFrame = CGRect(
            x: contentView.bounds.width - badgeSize.width - margin,
            y: margin,
            width: badgeSize.width,
            height: badgeSize.height
        )

        // 1) 컨테이너 뷰
        let container = UIView(frame: badgeFrame)
        container.layer.cornerRadius = 6
        container.clipsToBounds = true
        container.alpha = 0

        // 2) 그라데이션 레이어 (뱃지 배경 자체)
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = container.bounds
        gradientLayer.colors = [
            UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0).cgColor,  // 보라
            UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0).cgColor,  // 핑크
            UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0).cgColor   // 파랑
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0.5)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0.5)
        container.layer.addSublayer(gradientLayer)

        // 그라데이션 색상 순환 애니메이션 (4색 키프레임)
        let glowColors: [[CGColor]] = [
            [   // 보라 → 핑크 → 파랑
                UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0).cgColor,
                UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0).cgColor
            ],
            [   // 핑크 → 파랑 → 오렌지
                UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0).cgColor,
                UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0).cgColor
            ],
            [   // 파랑 → 오렌지 → 보라
                UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0).cgColor,
                UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0).cgColor
            ],
            [   // 오렌지 → 보라 → 핑크
                UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0).cgColor,
                UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0).cgColor
            ],
            [   // 다시 처음으로
                UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0).cgColor,
                UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0).cgColor,
                UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0).cgColor
            ]
        ]

        let colorAnim = CAKeyframeAnimation(keyPath: "colors")
        colorAnim.values = glowColors
        colorAnim.duration = 4.0
        colorAnim.repeatCount = .infinity
        colorAnim.calculationMode = .linear
        gradientLayer.add(colorAnim, forKey: "gradientCycle")

        // 3) 숫자 라벨 (블러 없이 직접)
        let label = UILabel()
        label.text = "⊞ 3"
        label.font = .systemFont(ofSize: 11, weight: .semibold)
        label.textColor = .white
        label.textAlignment = .center
        label.frame = container.bounds
        label.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        container.addSubview(label)

        contentView.addSubview(container)
        container.tag = 9005  // cleanup용

        // fade-in
        UIView.animate(withDuration: 0.4) {
            container.alpha = 1.0
        }
    }

    // MARK: - Effect 6: Scale + Badge

    /// 크기 확대 + 숫자 뱃지
    /// - 셀이 3% 확대되어 표시
    /// - 우측 상단에 원형 뱃지
    private func applyScaleBadge() {
        // 스프링 애니메이션으로 확대
        UIView.animate(
            withDuration: 0.5,
            delay: 0,
            usingSpringWithDamping: 0.6,
            initialSpringVelocity: 0.5
        ) { [weak self] in
            self?.contentView.transform = CGAffineTransform(scaleX: 1.04, y: 1.04)
        }

        // 원형 뱃지
        let badge = UILabel()
        badge.text = "3"
        badge.font = .systemFont(ofSize: 11, weight: .bold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = .systemBlue
        badge.layer.cornerRadius = 9
        badge.clipsToBounds = true

        let badgeSize: CGFloat = 18
        badge.frame = CGRect(
            x: contentView.bounds.width - badgeSize - 2,
            y: 2,
            width: badgeSize,
            height: badgeSize
        )

        badge.alpha = 0
        badge.transform = CGAffineTransform(scaleX: 0.1, y: 0.1)
        contentView.addSubview(badge)
        badgeLabel = badge

        UIView.animate(
            withDuration: 0.4,
            delay: 0.2,
            usingSpringWithDamping: 0.5,
            initialSpringVelocity: 0.8
        ) {
            badge.alpha = 1.0
            badge.transform = .identity
        }
    }

    // MARK: - Effect 7: Apple Intelligence Glow

    /// Apple Intelligence 스타일 다층 glow 테두리
    /// - 4개의 blur stroke 레이어를 겹쳐서 부드러운 광채
    /// - Angular Gradient 색상이 천천히 회전
    private func applyIntelligenceGlow() {
        let bounds = contentView.bounds
        let inset: CGFloat = 1.0
        let path = UIBezierPath(rect: bounds.insetBy(dx: inset, dy: inset))

        // 다층 glow 설정: (lineWidth, blurRadius, alpha)
        let layers: [(width: CGFloat, blur: CGFloat, alpha: CGFloat)] = [
            (2.0, 0, 0.9),    // 선명한 코어
            (4.0, 4, 0.6),    // 약간 흐릿
            (6.0, 8, 0.3),    // 더 흐릿
            (8.0, 12, 0.15)   // 가장 흐릿한 외곽 glow
        ]

        // 색상 팔레트 (Apple Intelligence 스타일)
        let glowColors: [UIColor] = [
            UIColor(red: 0.6, green: 0.3, blue: 1.0, alpha: 1.0),  // 보라
            UIColor(red: 1.0, green: 0.4, blue: 0.6, alpha: 1.0),  // 핑크
            UIColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0),  // 파랑
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 1.0),  // 오렌지
        ]

        for (i, config) in layers.enumerated() {
            let shape = CAShapeLayer()
            shape.path = path.cgPath
            shape.fillColor = nil
            shape.strokeColor = glowColors[i % glowColors.count]
                .withAlphaComponent(config.alpha).cgColor
            shape.lineWidth = config.width
            shape.lineCap = .round

            // 블러 필터 적용
            if config.blur > 0 {
                let filter = CIFilter(name: "CIGaussianBlur")
                filter?.setValue(config.blur, forKey: kCIInputRadiusKey)
                shape.filters = [filter].compactMap { $0 }
            }

            contentView.layer.addSublayer(shape)
            glowLayers.append(shape)

            // 색상 순환 애니메이션 (각 레이어 다른 속도)
            let colorAnim = CAKeyframeAnimation(keyPath: "strokeColor")
            let shiftedColors = Array(glowColors[i...]) + Array(glowColors[..<i])
            colorAnim.values = shiftedColors.map {
                $0.withAlphaComponent(config.alpha).cgColor
            } + [shiftedColors[0].withAlphaComponent(config.alpha).cgColor]
            colorAnim.duration = CFTimeInterval(3.0 + Double(i) * 0.5)
            colorAnim.repeatCount = .infinity
            colorAnim.calculationMode = .linear
            shape.add(colorAnim, forKey: "colorShift_\(i)")
        }
    }

    // MARK: - Helpers

    /// 숫자 뱃지 추가
    private func addCountBadge(count: Int, position: BadgePosition) {
        let badge = UILabel()
        badge.text = "+\(count)"
        badge.font = .systemFont(ofSize: 10, weight: .semibold)
        badge.textColor = .white
        badge.textAlignment = .center
        badge.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        badge.layer.cornerRadius = 7
        badge.clipsToBounds = true

        let badgeWidth: CGFloat = 24
        let badgeHeight: CGFloat = 14
        let margin: CGFloat = 4

        switch position {
        case .topRight:
            badge.frame = CGRect(
                x: contentView.bounds.width - badgeWidth - margin,
                y: margin,
                width: badgeWidth,
                height: badgeHeight
            )
        }

        contentView.addSubview(badge)
        badgeLabel = badge
    }

    /// 뱃지 위치
    enum BadgePosition {
        case topRight
    }

    // MARK: - Cleanup

    /// 모든 효과 제거
    private func clearAllEffects() {
        // Shimmer
        shimmerLayer?.stopAnimation()
        shimmerLayer?.removeFromSuperlayer()
        shimmerLayer = nil

        // Stacked cards
        stackLayers.forEach { $0.removeFromSuperlayer() }
        stackLayers.removeAll()

        // Shadow pulse
        if shadowPulseActive {
            contentView.layer.removeAnimation(forKey: "shadowPulse")
            contentView.layer.removeAnimation(forKey: "shadowRadiusPulse")
            contentView.layer.shadowOpacity = 0
            shadowPulseActive = false
        }

        // Corner dots
        dotViews.forEach { $0.removeFromSuperview() }
        dotViews.removeAll()

        // Glass badge / gradient badge containers
        glassBadge?.removeFromSuperview()
        glassBadge = nil
        contentView.viewWithTag(9005)?.removeFromSuperview()

        // Tint gradient (레거시, 이제 사용 안 함)
        tintGradientLayer?.removeFromSuperlayer()
        tintGradientLayer = nil

        // Badge
        badgeLabel?.removeFromSuperview()
        badgeLabel = nil

        // Intelligence glow
        glowLayers.forEach { $0.removeFromSuperlayer() }
        glowLayers.removeAll()

        // Scale 초기화
        contentView.transform = .identity
    }
}

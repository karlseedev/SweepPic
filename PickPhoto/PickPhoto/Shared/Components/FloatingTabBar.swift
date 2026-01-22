// FloatingTabBar.swift
// 하단 플로팅 캡슐 탭바 컴포넌트
//
// T027-1b: 캡슐 형태 + 좌우 아이콘 (iOS 18 Photos 스타일)
// - 블러 + 딤 효과
// - 버튼만 터치 반응, 나머지는 터치 통과
// - Select 모드 시 Select 툴바로 대체
// - 이벤트 흐름: GridVC가 Select 진입/종료 이벤트 발생 → FloatingOverlayContainer가 UI 전환

import UIKit

/// 플로팅 탭바 델리게이트
/// 탭 선택 및 Select 모드 이벤트 전달
protocol FloatingTabBarDelegate: AnyObject {
    /// 탭 선택 시 호출
    /// - Parameter index: 선택된 탭 인덱스 (0: Photos, 1: Albums, 2: Trash)
    func floatingTabBar(_ tabBar: FloatingTabBar, didSelectTabAt index: Int)

    /// Select 모드에서 Delete 버튼 탭
    func floatingTabBarDidTapDelete(_ tabBar: FloatingTabBar)

    /// 휴지통 비우기(삭제하기) 버튼 탭
    func floatingTabBarDidTapEmptyTrash(_ tabBar: FloatingTabBar)

    /// 휴지통 Select 모드에서 Restore 버튼 탭
    func floatingTabBarDidTapRestore(_ tabBar: FloatingTabBar)

    /// 휴지통 Select 모드에서 Delete 버튼 탭 (영구 삭제)
    func floatingTabBarDidTapTrashDelete(_ tabBar: FloatingTabBar)
}

// MARK: - Default Implementation

extension FloatingTabBarDelegate {
    func floatingTabBarDidTapRestore(_ tabBar: FloatingTabBar) {}
    func floatingTabBarDidTapTrashDelete(_ tabBar: FloatingTabBar) {}
}

/// 하단 플로팅 캡슐 탭바
/// iOS 18 사진 앱 스타일의 캡슐 형태 탭바
/// - 캡슐 컨테이너 안에 탭 버튼 배치
/// - Select 모드 시 Select 툴바로 UI 전환
/// - 버튼만 터치 반응, 나머지는 터치 통과
final class FloatingTabBar: UIView {

    // MARK: - Constants

    /// 캡슐 높이 (iOS 26 스타일에 맞춘 넓은 pill)
    static let capsuleHeight: CGFloat = 56

    /// 캡슐 좌우 패딩 (넓게 붙는 느낌)
    private static let capsulePadding: CGFloat = 16

    /// 캡슐 코너 반경
    private static let capsuleCornerRadius: CGFloat = capsuleHeight / 2

    /// 최대 딤 알파 (하단은 블러 없이 딤만 적용, 가장 어두운 부분 45%)
    private static let maxDimAlpha: CGFloat = LiquidGlassStyle.maxDimAlpha

    // MARK: - Properties

    weak var delegate: FloatingTabBarDelegate?

    /// 현재 선택된 탭 인덱스
    var selectedIndex: Int = 0 {
        didSet {
            updateTabSelection()
        }
    }

    /// 현재 Select 모드 여부 (Grid/Album용)
    private(set) var isSelectMode: Bool = false

    /// 현재 Trash Select 모드 여부 (Trash 전용)
    private(set) var isTrashSelectMode: Bool = false

    // MARK: - UI Components (Normal Mode)

    /// 캡슐 그림자 컨테이너
    private lazy var capsuleShadowView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Self.capsuleCornerRadius
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = LiquidGlassStyle.shadowOpacity
        view.layer.shadowRadius = LiquidGlassStyle.shadowRadius
        view.layer.shadowOffset = LiquidGlassStyle.shadowOffset
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 캡슐 컨테이너 (블러 배경)
    private lazy var capsuleContainer: UIVisualEffectView = {
        let effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = Self.capsuleCornerRadius
        view.layer.borderWidth = LiquidGlassStyle.borderWidth
        view.layer.borderColor = UIColor.white.withAlphaComponent(LiquidGlassStyle.borderAlpha).cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 캡슐 배경 오버레이 (심플한 톤)
    private lazy var capsuleBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.1, alpha: LiquidGlassStyle.backgroundAlpha)
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 탭 버튼 스택뷰
    private lazy var tabStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// Photos 탭 버튼
    private lazy var photosButton: UIButton = {
        let button = createTabButton(
            title: "보관함",
            image: UIImage(systemName: "photo.on.rectangle"),
            selectedImage: UIImage(systemName: "photo.on.rectangle.fill"),
            tag: 0
        )
        return button
    }()

    /// Albums 탭 버튼
    private lazy var albumsButton: UIButton = {
        let button = createTabButton(
            title: "앨범",
            image: UIImage(systemName: "rectangle.stack"),
            selectedImage: UIImage(systemName: "rectangle.stack.fill"),
            tag: 1
        )
        return button
    }()

    /// Trash 탭 버튼
    private lazy var trashButton: UIButton = {
        let button = createTabButton(
            title: "휴지통",
            image: UIImage(systemName: "trash"),
            selectedImage: UIImage(systemName: "trash.fill"),
            tag: 2
        )
        return button
    }()

    // MARK: - UI Components (Empty Trash Button - 원형)

    /// 삭제하기 버튼 그림자 컨테이너 (원형)
    private lazy var emptyTrashShadowView: UIView = {
        let view = UIView()
        view.layer.cornerRadius = Self.capsuleHeight / 2
        view.layer.shadowColor = UIColor.black.cgColor
        view.layer.shadowOpacity = LiquidGlassStyle.shadowOpacity
        view.layer.shadowRadius = LiquidGlassStyle.shadowRadius
        view.layer.shadowOffset = LiquidGlassStyle.shadowOffset
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 삭제하기 버튼 컨테이너 (블러 배경, 원형)
    private lazy var emptyTrashContainer: UIVisualEffectView = {
        let effect = UIBlurEffect(style: LiquidGlassStyle.blurStyle)
        let view = UIVisualEffectView(effect: effect)
        view.layer.cornerRadius = Self.capsuleHeight / 2
        view.layer.borderWidth = LiquidGlassStyle.borderWidth
        view.layer.borderColor = UIColor.white.withAlphaComponent(LiquidGlassStyle.borderAlpha).cgColor
        view.clipsToBounds = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 삭제하기 버튼 배경 오버레이
    private lazy var emptyTrashBackgroundView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.1, alpha: LiquidGlassStyle.backgroundAlpha)
        view.isUserInteractionEnabled = false
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 삭제하기 버튼 (휴지통 비우기)
    private lazy var emptyTrashButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "trash.slash.fill")
        config.baseForegroundColor = .systemRed
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        let button = UIButton(configuration: config)
        button.accessibilityLabel = "삭제하기"
        button.addTarget(self, action: #selector(emptyTrashButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - UI Components (Select Mode)

    /// 선택 개수 라벨 (순수 텍스트)
    private lazy var selectionCountLabel: UILabel = {
        let label = UILabel()
        label.text = "항목 선택"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textAlignment = .center
        return label
    }()

    /// Delete 버튼 (Liquid Glass 스타일)
    private lazy var deleteButton: GlassButton = {
        let button = GlassButton(tintColor: .systemRed, useCapsuleStyle: true)
        
        var config = UIButton.Configuration.plain()
        config.title = "Delete"
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .medium)
            return outgoing
        }
        
        button.configuration = config
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        return button
    }()

    /// Select 모드 컨테이너 (선택개수 + Delete) - Grid/Album용
    private lazy var selectModeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    // MARK: - UI Components (Trash Select Mode)

    /// Trash Select 모드 컨테이너 (Restore + 선택개수 + Delete) - Trash 전용
    private lazy var trashSelectModeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Trash Restore 버튼 (Liquid Glass 스타일)
    private lazy var trashRestoreButton: GlassButton = {
        let button = GlassButton(tintColor: .systemBlue, useCapsuleStyle: true)
        
        var config = UIButton.Configuration.plain()
        config.title = "Restore"
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .medium)
            return outgoing
        }
        
        button.configuration = config
        button.addTarget(self, action: #selector(trashRestoreButtonTapped), for: .touchUpInside)
        return button
    }()

    /// Trash 선택 개수 라벨
    private lazy var trashSelectionCountLabel: UILabel = {
        let label = UILabel()
        label.text = "항목 선택"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textAlignment = .center
        return label
    }()

    /// Trash Delete 버튼 (Liquid Glass 스타일, 영구 삭제)
    private lazy var trashDeleteButton: GlassButton = {
        let button = GlassButton(tintColor: .systemRed, useCapsuleStyle: true)
        
        var config = UIButton.Configuration.plain()
        config.title = "Delete"
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 15, weight: .medium)
            return outgoing
        }
        
        button.configuration = config
        button.addTarget(self, action: #selector(trashDeleteButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 그라데이션 딤 레이어 (하단에서 상단으로 자연스럽게 페이드, 블러 없음)
    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        // 상단: 투명 → 70% 지점: 60% 도달 → 하단: 60% 유지
        // 균등한 알파 변화로 부드러운 전환
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.33).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.66).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha).cgColor
        ]
        // 0~70% 구간에서 균등하게 전환, 70~100%는 유지
        layer.locations = [0, 0.23, 0.47, 0.7, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    // MARK: - Setup

    private func setupUI() {
        // 그라데이션 레이어 추가
        layer.addSublayer(gradientLayer)

        // 일반 모드 캡슐 추가
        addSubview(capsuleShadowView)
        capsuleShadowView.addSubview(capsuleContainer)
        capsuleContainer.contentView.addSubview(capsuleBackgroundView)
        capsuleContainer.contentView.addSubview(tabStackView)

        tabStackView.addArrangedSubview(photosButton)
        tabStackView.addArrangedSubview(albumsButton)
        tabStackView.addArrangedSubview(trashButton)

        // 삭제하기 원형 버튼 추가 (탭바 우측) - 현재 비활성화
        addSubview(emptyTrashShadowView)
        emptyTrashShadowView.addSubview(emptyTrashContainer)
        emptyTrashContainer.contentView.addSubview(emptyTrashBackgroundView)
        emptyTrashContainer.contentView.addSubview(emptyTrashButton)
        emptyTrashShadowView.isHidden = true  // 비활성화

        // Select 모드 컨테이너 추가 (선택개수 + Delete) - Grid/Album용
        addSubview(selectModeContainer)
        selectModeContainer.addSubview(selectionCountLabel)
        selectModeContainer.addSubview(deleteButton)
        selectionCountLabel.translatesAutoresizingMaskIntoConstraints = false
        deleteButton.translatesAutoresizingMaskIntoConstraints = false

        // Trash Select 모드 컨테이너 추가 (Restore + 선택개수 + Delete) - Trash 전용
        addSubview(trashSelectModeContainer)
        trashSelectModeContainer.addSubview(trashRestoreButton)
        trashSelectModeContainer.addSubview(trashSelectionCountLabel)
        trashSelectModeContainer.addSubview(trashDeleteButton)
        trashRestoreButton.translatesAutoresizingMaskIntoConstraints = false
        trashSelectionCountLabel.translatesAutoresizingMaskIntoConstraints = false
        trashDeleteButton.translatesAutoresizingMaskIntoConstraints = false

        setupConstraints()
        updateTabSelection()

        print("[FloatingTabBar] Initialized")
    }

    private func setupConstraints() {
        NSLayoutConstraint.activate([
            // 일반 모드 캡슐: 중앙 정렬, 화면 너비의 60%
            capsuleShadowView.centerXAnchor.constraint(equalTo: centerXAnchor),
            capsuleShadowView.topAnchor.constraint(equalTo: topAnchor),
            capsuleShadowView.heightAnchor.constraint(equalToConstant: Self.capsuleHeight),
            capsuleShadowView.widthAnchor.constraint(equalTo: widthAnchor, multiplier: 0.6),

            capsuleContainer.topAnchor.constraint(equalTo: capsuleShadowView.topAnchor),
            capsuleContainer.leadingAnchor.constraint(equalTo: capsuleShadowView.leadingAnchor),
            capsuleContainer.trailingAnchor.constraint(equalTo: capsuleShadowView.trailingAnchor),
            capsuleContainer.bottomAnchor.constraint(equalTo: capsuleShadowView.bottomAnchor),

            // 탭 스택뷰: 캡슐 내부
            capsuleBackgroundView.topAnchor.constraint(equalTo: capsuleContainer.contentView.topAnchor),
            capsuleBackgroundView.leadingAnchor.constraint(equalTo: capsuleContainer.contentView.leadingAnchor),
            capsuleBackgroundView.trailingAnchor.constraint(equalTo: capsuleContainer.contentView.trailingAnchor),
            capsuleBackgroundView.bottomAnchor.constraint(equalTo: capsuleContainer.contentView.bottomAnchor),

            tabStackView.topAnchor.constraint(equalTo: capsuleContainer.contentView.topAnchor),
            tabStackView.leadingAnchor.constraint(equalTo: capsuleContainer.contentView.leadingAnchor, constant: 6),
            tabStackView.trailingAnchor.constraint(equalTo: capsuleContainer.contentView.trailingAnchor, constant: -6),
            tabStackView.bottomAnchor.constraint(equalTo: capsuleContainer.contentView.bottomAnchor),

            // 삭제하기 원형 버튼: 탭바 우측에 배치
            emptyTrashShadowView.topAnchor.constraint(equalTo: topAnchor),
            emptyTrashShadowView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -Self.capsulePadding),
            emptyTrashShadowView.widthAnchor.constraint(equalToConstant: Self.capsuleHeight),
            emptyTrashShadowView.heightAnchor.constraint(equalToConstant: Self.capsuleHeight),

            emptyTrashContainer.topAnchor.constraint(equalTo: emptyTrashShadowView.topAnchor),
            emptyTrashContainer.leadingAnchor.constraint(equalTo: emptyTrashShadowView.leadingAnchor),
            emptyTrashContainer.trailingAnchor.constraint(equalTo: emptyTrashShadowView.trailingAnchor),
            emptyTrashContainer.bottomAnchor.constraint(equalTo: emptyTrashShadowView.bottomAnchor),

            emptyTrashBackgroundView.topAnchor.constraint(equalTo: emptyTrashContainer.contentView.topAnchor),
            emptyTrashBackgroundView.leadingAnchor.constraint(equalTo: emptyTrashContainer.contentView.leadingAnchor),
            emptyTrashBackgroundView.trailingAnchor.constraint(equalTo: emptyTrashContainer.contentView.trailingAnchor),
            emptyTrashBackgroundView.bottomAnchor.constraint(equalTo: emptyTrashContainer.contentView.bottomAnchor),

            emptyTrashButton.topAnchor.constraint(equalTo: emptyTrashContainer.contentView.topAnchor),
            emptyTrashButton.leadingAnchor.constraint(equalTo: emptyTrashContainer.contentView.leadingAnchor),
            emptyTrashButton.trailingAnchor.constraint(equalTo: emptyTrashContainer.contentView.trailingAnchor),
            emptyTrashButton.bottomAnchor.constraint(equalTo: emptyTrashContainer.contentView.bottomAnchor),

            // Select 모드 컨테이너: 전체 너비 (Grid/Album용)
            selectModeContainer.topAnchor.constraint(equalTo: topAnchor),
            selectModeContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            selectModeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            selectModeContainer.heightAnchor.constraint(equalToConstant: Self.capsuleHeight),

            // 선택개수 라벨: 중앙
            selectionCountLabel.centerXAnchor.constraint(equalTo: selectModeContainer.centerXAnchor),
            selectionCountLabel.centerYAnchor.constraint(equalTo: selectModeContainer.centerYAnchor),

            // Delete 버튼: 우측
            deleteButton.trailingAnchor.constraint(equalTo: selectModeContainer.trailingAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: selectModeContainer.centerYAnchor),

            // Trash Select 모드 컨테이너: 전체 너비 (Trash 전용)
            trashSelectModeContainer.topAnchor.constraint(equalTo: topAnchor),
            trashSelectModeContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            trashSelectModeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            trashSelectModeContainer.heightAnchor.constraint(equalToConstant: Self.capsuleHeight),

            // Trash Restore 버튼: 좌측
            trashRestoreButton.leadingAnchor.constraint(equalTo: trashSelectModeContainer.leadingAnchor),
            trashRestoreButton.centerYAnchor.constraint(equalTo: trashSelectModeContainer.centerYAnchor),

            // Trash 선택개수 라벨: 중앙
            trashSelectionCountLabel.centerXAnchor.constraint(equalTo: trashSelectModeContainer.centerXAnchor),
            trashSelectionCountLabel.centerYAnchor.constraint(equalTo: trashSelectModeContainer.centerYAnchor),

            // Trash Delete 버튼: 우측
            trashDeleteButton.trailingAnchor.constraint(equalTo: trashSelectModeContainer.trailingAnchor),
            trashDeleteButton.centerYAnchor.constraint(equalTo: trashSelectModeContainer.centerYAnchor),
        ])
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
        capsuleShadowView.layer.shadowPath = UIBezierPath(
            roundedRect: capsuleShadowView.bounds,
            cornerRadius: Self.capsuleCornerRadius
        ).cgPath
        // 원형 삭제하기 버튼 그림자 경로 (원형)
        emptyTrashShadowView.layer.shadowPath = UIBezierPath(
            ovalIn: emptyTrashShadowView.bounds
        ).cgPath

    }

    // MARK: - Hit Testing (터치 차단)

    /// 버튼만 터치 반응, 나머지 딤드 영역은 터치 차단
    /// 기본 사진 앱과 동일하게 딤드 영역에서는 스크롤 불가
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Trash Select 모드일 때 (Trash 전용: Restore + Delete)
        if isTrashSelectMode {
            // Restore 버튼 체크
            let restorePoint = convert(point, to: trashRestoreButton)
            if trashRestoreButton.bounds.contains(restorePoint) {
                return trashRestoreButton
            }
            // Delete 버튼 체크
            let deletePoint = convert(point, to: trashDeleteButton)
            if trashDeleteButton.bounds.contains(deletePoint) {
                return trashDeleteButton
            }
            // 나머지 딤드 영역은 터치 차단
            return self
        }

        // Select 모드일 때 (Grid/Album용)
        if isSelectMode {
            // Delete 버튼 체크
            let deletePoint = convert(point, to: deleteButton)
            if deleteButton.bounds.contains(deletePoint) {
                return deleteButton
            }
            // 나머지 딤드 영역은 터치 차단
            return self
        }

        // 일반 모드일 때
        // Photos 버튼 체크
        let photosPoint = convert(point, to: photosButton)
        if photosButton.bounds.contains(photosPoint) {
            return photosButton
        }
        // Albums 버튼 체크
        let albumsPoint = convert(point, to: albumsButton)
        if albumsButton.bounds.contains(albumsPoint) {
            return albumsButton
        }
        // Trash 버튼 체크
        let trashPoint = convert(point, to: trashButton)
        if trashButton.bounds.contains(trashPoint) {
            return trashButton
        }
        // 삭제하기 원형 버튼 체크
        let emptyTrashPoint = convert(point, to: emptyTrashButton)
        if emptyTrashButton.bounds.contains(emptyTrashPoint) {
            return emptyTrashButton
        }

        // 나머지 딤드 영역은 터치 차단
        return self
    }

    // MARK: - Private Methods

    private func createTabButton(title: String, image: UIImage?, selectedImage: UIImage?, tag: Int) -> UIButton {
        let button = UIButton(type: .custom)
        button.tag = tag

        // 이미지 + 타이틀 수직 배치
        var config = UIButton.Configuration.plain()
        config.image = image
        config.title = title
        config.imagePlacement = .top
        config.imagePadding = 2
        config.baseForegroundColor = UIColor(white: 1, alpha: 0.65)
        config.contentInsets = NSDirectionalEdgeInsets(top: 6, leading: 6, bottom: 6, trailing: 6)
        config.titleTextAttributesTransformer = Self.tabTitleTransformer()
        config.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: LiquidGlassStyle.tabIconSize, weight: .regular)

        button.configuration = config
        button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)

        // 선택 시 이미지 변경을 위해 저장
        button.setImage(image, for: .normal)
        button.setImage(selectedImage, for: .selected)

        return button
    }

    private func updateTabSelection() {
        // Photos 버튼 상태 업데이트
        photosButton.isSelected = (selectedIndex == 0)

        // Albums 버튼 상태 업데이트
        albumsButton.isSelected = (selectedIndex == 1)

        // Trash 버튼 상태 업데이트
        trashButton.isSelected = (selectedIndex == 2)

        // Configuration 업데이트로 이미지 변경
        updateButtonConfiguration(photosButton, isSelected: selectedIndex == 0)
        updateButtonConfiguration(albumsButton, isSelected: selectedIndex == 1)
        updateButtonConfiguration(trashButton, isSelected: selectedIndex == 2)
    }

    private func updateButtonConfiguration(_ button: UIButton, isSelected: Bool) {
        guard var config = button.configuration else { return }
        config.baseForegroundColor = isSelected ? .systemBlue : UIColor(white: 1, alpha: 0.65)
        config.image = isSelected ? button.image(for: .selected) : button.image(for: .normal)
        button.configuration = config
    }

    // MARK: - Actions

    @objc private func tabButtonTapped(_ sender: UIButton) {
        let index = sender.tag
        print("[FloatingTabBar] Tab \(index) tapped")
        selectedIndex = index
        delegate?.floatingTabBar(self, didSelectTabAt: index)
    }

    @objc private func deleteButtonTapped() {
        print("[FloatingTabBar] Delete tapped")
        delegate?.floatingTabBarDidTapDelete(self)
    }

    @objc private func emptyTrashButtonTapped() {
        print("[FloatingTabBar] Empty Trash tapped")
        delegate?.floatingTabBarDidTapEmptyTrash(self)
    }

    @objc private func trashRestoreButtonTapped() {
        print("[FloatingTabBar] Trash Restore tapped")
        delegate?.floatingTabBarDidTapRestore(self)
    }

    @objc private func trashDeleteButtonTapped() {
        print("[FloatingTabBar] Trash Delete tapped")
        delegate?.floatingTabBarDidTapTrashDelete(self)
    }

    // MARK: - Public Methods

    /// Select 모드 진입
    /// - Parameter animated: 애니메이션 여부
    func enterSelectMode(animated: Bool = true) {
        isSelectMode = true
        selectionCountLabel.text = "항목 선택"
        deleteButton.isEnabled = false

        if animated {
            selectModeContainer.isHidden = false
            selectModeContainer.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.capsuleShadowView.alpha = 0
                self.selectModeContainer.alpha = 1
            } completion: { _ in
                self.capsuleShadowView.isHidden = true
            }
        } else {
            capsuleShadowView.isHidden = true
            capsuleShadowView.alpha = 0
            selectModeContainer.isHidden = false
            selectModeContainer.alpha = 1
        }

        print("[FloatingTabBar] Entered select mode")
    }

    /// Select 모드 종료
    /// - Parameter animated: 애니메이션 여부
    func exitSelectMode(animated: Bool = true) {
        isSelectMode = false

        if animated {
            capsuleShadowView.isHidden = false
            capsuleShadowView.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.capsuleShadowView.alpha = 1
                self.selectModeContainer.alpha = 0
            } completion: { _ in
                self.selectModeContainer.isHidden = true
            }
        } else {
            capsuleShadowView.isHidden = false
            capsuleShadowView.alpha = 1
            selectModeContainer.isHidden = true
            selectModeContainer.alpha = 0
        }

        print("[FloatingTabBar] Exited select mode")
    }

    /// 선택 개수 업데이트 (Select 모드에서) - Grid/Album용
    /// - Parameter count: 선택된 사진 개수
    func updateSelectionCount(_ count: Int) {
        // 0개: "항목 선택", 1개 이상: "N개 항목 선택됨"
        selectionCountLabel.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
        deleteButton.isEnabled = count > 0
    }

    // MARK: - Trash Select Mode Methods

    /// Trash Select 모드 진입 (Trash 전용: Restore + 선택개수 + Delete)
    /// - Parameter animated: 애니메이션 여부
    func enterTrashSelectMode(animated: Bool = true) {
        isTrashSelectMode = true
        trashSelectionCountLabel.text = "항목 선택"
        trashRestoreButton.isEnabled = false
        trashDeleteButton.isEnabled = false

        if animated {
            trashSelectModeContainer.isHidden = false
            trashSelectModeContainer.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.capsuleShadowView.alpha = 0
                self.trashSelectModeContainer.alpha = 1
            } completion: { _ in
                self.capsuleShadowView.isHidden = true
            }
        } else {
            capsuleShadowView.isHidden = true
            capsuleShadowView.alpha = 0
            trashSelectModeContainer.isHidden = false
            trashSelectModeContainer.alpha = 1
        }

        print("[FloatingTabBar] Entered trash select mode")
    }

    /// Trash Select 모드 종료 (Trash 전용)
    /// - Parameter animated: 애니메이션 여부
    func exitTrashSelectMode(animated: Bool = true) {
        isTrashSelectMode = false

        if animated {
            capsuleShadowView.isHidden = false
            capsuleShadowView.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.capsuleShadowView.alpha = 1
                self.trashSelectModeContainer.alpha = 0
            } completion: { _ in
                self.trashSelectModeContainer.isHidden = true
            }
        } else {
            capsuleShadowView.isHidden = false
            capsuleShadowView.alpha = 1
            trashSelectModeContainer.isHidden = true
            trashSelectModeContainer.alpha = 0
        }

        print("[FloatingTabBar] Exited trash select mode")
    }

    /// Trash 선택 개수 업데이트 (Trash Select 모드에서)
    /// - Parameter count: 선택된 사진 개수
    func updateTrashSelectionCount(_ count: Int) {
        // 0개: "항목 선택", 1개 이상: "N개 항목 선택됨"
        trashSelectionCountLabel.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
        trashRestoreButton.isEnabled = count > 0
        trashDeleteButton.isEnabled = count > 0
    }

    /// 탭바 높이 계산 (safe area 포함)
    /// - Parameter safeAreaBottom: 하단 safe area inset
    /// - Returns: 전체 탭바 높이
    static func totalHeight(safeAreaBottom: CGFloat) -> CGFloat {
        // 캡슐 하단이 홈 인디케이터 바로 위에 위치
        return capsuleHeight + safeAreaBottom
    }

    private static func tabTitleTransformer() -> UIConfigurationTextAttributesTransformer {
        UIConfigurationTextAttributesTransformer { incoming in
            var outgoing = incoming
            outgoing.font = .systemFont(ofSize: 11, weight: .medium)
            return outgoing
        }
    }
}

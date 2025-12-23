// EmptyStateView.swift
// 빈 상태 표시 컴포넌트
//
// T019: EmptyStateView 컴포넌트 생성
//
// 사용 사례:
// - T070: 사진 0장 빈 상태 ("사진이 없습니다")
// - T071: 앨범 내 사진 0장 빈 상태
// - T059: 휴지통 비었을 때 ("휴지통이 비어 있습니다")

import UIKit

/// 빈 상태를 표시하는 재사용 가능한 뷰
/// 아이콘, 타이틀, 서브타이틀을 표시
class EmptyStateView: UIView {

    // MARK: - UI Components

    /// 아이콘 이미지 뷰
    private let iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .tertiaryLabel
        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// 타이틀 라벨
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 20, weight: .semibold)
        label.textColor = .label
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 서브타이틀 라벨 (옵션)
    private let subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 15, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 액션 버튼 (옵션)
    private let actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 17, weight: .medium)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true
        return button
    }()

    /// 스택 뷰 (수직 정렬)
    private lazy var stackView: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [iconImageView, titleLabel, subtitleLabel, actionButton])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 12
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    // MARK: - Properties

    /// 버튼 탭 액션
    var onActionButtonTap: (() -> Void)?

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }

    /// 편의 초기화자
    /// - Parameters:
    ///   - icon: SF Symbol 이름
    ///   - title: 타이틀 텍스트
    ///   - subtitle: 서브타이틀 텍스트 (옵션)
    convenience init(icon: String, title: String, subtitle: String? = nil) {
        self.init(frame: .zero)
        configure(icon: icon, title: title, subtitle: subtitle)
    }

    // MARK: - Setup

    private func setupUI() {
        addSubview(stackView)

        NSLayoutConstraint.activate([
            // 아이콘 크기
            iconImageView.widthAnchor.constraint(equalToConstant: 64),
            iconImageView.heightAnchor.constraint(equalToConstant: 64),

            // 스택 뷰 중앙 정렬
            stackView.centerXAnchor.constraint(equalTo: centerXAnchor),
            stackView.centerYAnchor.constraint(equalTo: centerYAnchor),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 32),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -32)
        ])

        // 버튼 액션 연결
        actionButton.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
    }

    // MARK: - Configuration

    /// 빈 상태 뷰 구성
    /// - Parameters:
    ///   - icon: SF Symbol 이름
    ///   - title: 타이틀 텍스트
    ///   - subtitle: 서브타이틀 텍스트 (옵션)
    func configure(icon: String, title: String, subtitle: String? = nil) {
        iconImageView.image = UIImage(systemName: icon)
        titleLabel.text = title

        if let subtitle = subtitle {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = false
        } else {
            subtitleLabel.isHidden = true
        }
    }

    /// 액션 버튼 설정
    /// - Parameters:
    ///   - title: 버튼 타이틀
    ///   - action: 버튼 탭 시 실행할 클로저
    func setActionButton(title: String, action: @escaping () -> Void) {
        actionButton.setTitle(title, for: .normal)
        actionButton.isHidden = false
        onActionButtonTap = action
    }

    /// 액션 버튼 숨기기
    func hideActionButton() {
        actionButton.isHidden = true
        onActionButtonTap = nil
    }

    /// 다크 테마 설정 (검정 배경에서 사용)
    /// 텍스트 색상을 흰색 계열로 변경
    func useDarkTheme() {
        titleLabel.textColor = .white
        subtitleLabel.textColor = .lightGray
        iconImageView.tintColor = .gray
    }

    // MARK: - Actions

    @objc private func actionButtonTapped() {
        onActionButtonTap?()
    }
}

// MARK: - Preset Configurations

extension EmptyStateView {

    /// "사진이 없습니다" 프리셋 (T070)
    static func noPhotos() -> EmptyStateView {
        EmptyStateView(
            icon: "photo.on.rectangle.angled",
            title: "사진이 없습니다",
            subtitle: "사진 라이브러리에 사진을 추가해주세요"
        )
    }

    /// "앨범이 비어 있습니다" 프리셋 (T071)
    static func emptyAlbum() -> EmptyStateView {
        EmptyStateView(
            icon: "photo.on.rectangle",
            title: "사진 없음",
            subtitle: "이 앨범에는 사진이 없습니다"
        )
    }

    /// "휴지통이 비어 있습니다" 프리셋 (T059)
    static func emptyTrash() -> EmptyStateView {
        EmptyStateView(
            icon: "trash",
            title: "휴지통이 비어 있습니다",
            subtitle: nil
        )
    }

    /// "권한 필요" 프리셋
    static func permissionRequired() -> EmptyStateView {
        let view = EmptyStateView(
            icon: "photo.badge.exclamationmark",
            title: "사진 접근 권한 필요",
            subtitle: "설정에서 사진 라이브러리 접근을 허용해주세요"
        )
        return view
    }
}

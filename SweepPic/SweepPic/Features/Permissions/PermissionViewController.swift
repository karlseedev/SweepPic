// PermissionViewController.swift
// 사진 라이브러리 권한 설정 안내 화면
//
// T061: PermissionViewController 생성
// T063: 거부 상태 UI 구현 ("설정에서 권한을 허용해주세요" + "설정 열기" 버튼)
//
// 역할:
// - 권한 거부/제한 시 설정 앱으로 이동 안내
// - 설정에서 전체 접근 허용 후 자동으로 메인 화면 전환
// - 최초 권한 요청(.notDetermined)은 SceneDelegate에서 직접 시스템 팝업으로 처리

import UIKit
import AppCore

// MARK: - PermissionViewControllerDelegate

/// PermissionViewController 델리게이트
/// 권한 승인 후 화면 전환 처리
protocol PermissionViewControllerDelegate: AnyObject {
    /// 권한이 승인되어 사진 접근이 가능해졌을 때 호출
    /// - Parameter controller: 권한 뷰컨트롤러
    func permissionViewControllerDidGrantAccess(_ controller: PermissionViewController)
}

// MARK: - PermissionViewController (T061)

/// 사진 라이브러리 권한 요청 뷰컨트롤러
/// 권한 상태에 따라 요청 UI 또는 설정 안내 UI 표시
final class PermissionViewController: UIViewController {

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: PermissionViewControllerDelegate?

    /// 권한 스토어
    private let permissionStore: PermissionStoreProtocol

    /// 현재 표시 중인 상태 (거부/제한 상태에서만 사용)
    private var currentState: PermissionState = .denied

    // MARK: - UI Components

    /// 컨테이너 스택뷰
    private lazy var containerStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 24
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

    /// 아이콘 이미지뷰
    private lazy var iconImageView: UIImageView = {
        let imageView = UIImageView()
        imageView.contentMode = .scaleAspectFit
        imageView.tintColor = .white

        // SF Symbol 사용 - 사진 아이콘
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        imageView.image = UIImage(systemName: "photo.on.rectangle.angled", withConfiguration: config)

        imageView.translatesAutoresizingMaskIntoConstraints = false
        return imageView
    }()

    /// 타이틀 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 28, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 설명 라벨
    private lazy var descriptionLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 16, weight: .regular)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 메인 액션 버튼 (T062: 사진 접근 허용 / T063: 설정 열기)
    private lazy var actionButton: UIButton = {
        let button = UIButton(type: .system)
        button.titleLabel?.font = .systemFont(ofSize: 18, weight: .semibold)
        button.setTitleColor(.white, for: .normal)
        button.backgroundColor = .systemBlue
        button.layer.cornerRadius = 14
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(actionButtonTapped), for: .touchUpInside)
        return button
    }()

    /// 보조 설명 라벨 (제한적 접근 시)
    private lazy var secondaryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .regular)
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.isHidden = true
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    // MARK: - Initialization

    /// 초기화
    /// - Parameter permissionStore: 권한 스토어 (기본값: 공유 인스턴스)
    init(permissionStore: PermissionStoreProtocol = PermissionStore.shared) {
        self.permissionStore = permissionStore
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        updateUI(for: permissionStore.currentStatus)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        // 설정에서 돌아왔을 때 상태 재확인
        let currentStatus = permissionStore.currentStatus
        if currentStatus != currentState {
            updateUI(for: currentStatus)

            // FR-033: 전체 접근 권한(.authorized)만 메인 화면 전환
            // .limited는 Denied와 동일하게 처리하므로 delegate 호출하지 않음
            if currentStatus == .authorized {
                delegate?.permissionViewControllerDidGrantAccess(self)
            }
        }
    }

    // MARK: - UI Setup

    /// UI 설정
    private func setupUI() {
        view.backgroundColor = .systemBackground

        // 컨테이너 추가
        view.addSubview(containerStackView)

        // 스택뷰에 컴포넌트 추가
        containerStackView.addArrangedSubview(iconImageView)
        containerStackView.addArrangedSubview(titleLabel)
        containerStackView.addArrangedSubview(descriptionLabel)
        containerStackView.addArrangedSubview(actionButton)
        containerStackView.addArrangedSubview(secondaryLabel)

        // 컴포넌트별 spacing 조정
        containerStackView.setCustomSpacing(32, after: iconImageView)
        containerStackView.setCustomSpacing(12, after: titleLabel)
        containerStackView.setCustomSpacing(40, after: descriptionLabel)
        containerStackView.setCustomSpacing(16, after: actionButton)

        // 레이아웃 설정
        NSLayoutConstraint.activate([
            // 컨테이너 - 화면 중앙
            containerStackView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -40),
            containerStackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 40),
            containerStackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -40),

            // 아이콘
            iconImageView.widthAnchor.constraint(equalToConstant: 120),
            iconImageView.heightAnchor.constraint(equalToConstant: 120),

            // 액션 버튼
            actionButton.widthAnchor.constraint(equalTo: containerStackView.widthAnchor),
            actionButton.heightAnchor.constraint(equalToConstant: 56)
        ])
    }

    // MARK: - UI Update

    /// 권한 상태에 따른 UI 업데이트
    /// FR-033: Limited도 Denied와 동일하게 설정 안내 화면 표시
    /// - Parameter state: 권한 상태
    private func updateUI(for state: PermissionState) {
        currentState = state

        switch state {
        case .denied, .restricted, .limited:
            // T063: 거부/제한 상태 - "설정 열기" 버튼 표시
            // FR-033: Limited도 Denied와 동일하게 처리
            showDeniedUI(isRestricted: state == .restricted, isLimited: state == .limited)

        case .authorized:
            // 전체 접근 권한 있음 - 델리게이트가 메인 화면 전환 처리
            delegate?.permissionViewControllerDidGrantAccess(self)

        case .notDetermined:
            // 이 VC에서는 발생하지 않음 (SceneDelegate에서 시스템 팝업으로 처리)
            break
        }
    }

    /// T063: 거부/제한 상태 UI 표시
    /// FR-033: Limited도 Denied와 동일하게 설정 안내 화면 표시
    /// - Parameters:
    ///   - isRestricted: 보호자 통제 등으로 제한된 경우 true
    ///   - isLimited: 선택한 사진만 접근 가능한 경우 true (Denied와 동일하게 처리)
    private func showDeniedUI(isRestricted: Bool, isLimited: Bool = false) {
        // 아이콘 변경
        let config = UIImage.SymbolConfiguration(pointSize: 80, weight: .light)
        iconImageView.image = UIImage(systemName: "exclamationmark.triangle", withConfiguration: config)
        iconImageView.tintColor = .systemOrange

        if isRestricted {
            // 보호자 통제 등으로 제한됨
            titleLabel.text = String(localized: "permissions.restricted.title")
            descriptionLabel.text = String(localized: "permissions.restricted.description")
            actionButton.setTitle(String(localized: "permissions.openSettings"), for: .normal)
            actionButton.backgroundColor = .systemGray
            secondaryLabel.text = String(localized: "permissions.restricted.secondary")
            secondaryLabel.isHidden = false
        } else {
            // 사용자가 거부함 또는 선택한 사진만 허용 (동일하게 처리)
            titleLabel.text = String(localized: "permissions.denied.title")
            descriptionLabel.text = String(localized: "permissions.denied.description")
            actionButton.setTitle(String(localized: "permissions.openSettings"), for: .normal)
            actionButton.backgroundColor = .systemBlue
            secondaryLabel.isHidden = true
        }

    }

    // MARK: - Actions

    /// 액션 버튼 탭 처리 - "설정 열기" 버튼
    @objc private func actionButtonTapped() {
        openSettings()
    }

    /// T063: 설정 앱 열기
    private func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
            return
        }

        UIApplication.shared.open(settingsURL)
    }

    // MARK: - Public Methods

    /// 권한 상태 새로고침
    /// 설정에서 돌아왔을 때 호출
    func refreshPermissionStatus() {
        let status = permissionStore.currentStatus
        if status != currentState {
            updateUI(for: status)
        }
    }
}

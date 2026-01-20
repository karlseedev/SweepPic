// FloatingTitleBar.swift
// 상단 플로팅 타이틀바 컴포넌트
//
// T027-1a: 타이틀 + Select 버튼 + 블러 배경
// - 높이: 44pt + safe area top
// - Select 버튼만 터치 반응, 나머지는 터치 통과 (hitTest 오버라이드)
// - Progressive blur 효과 (BlurUIKit 사용)

import UIKit
import BlurUIKit

/// 플로팅 타이틀바 델리게이트
/// Select 버튼, 뒤로가기 버튼 탭 이벤트 전달
protocol FloatingTitleBarDelegate: AnyObject {
    /// Select 버튼 탭 시 호출
    func floatingTitleBarDidTapSelect(_ titleBar: FloatingTitleBar)

    /// 뒤로가기 버튼 탭 시 호출 (옵션)
    func floatingTitleBarDidTapBack(_ titleBar: FloatingTitleBar)
}

// MARK: - Default Implementation
extension FloatingTitleBarDelegate {
    func floatingTitleBarDidTapBack(_ titleBar: FloatingTitleBar) {}
}

/// 상단 플로팅 타이틀바
/// iOS 18 사진 앱 스타일의 플로팅 UI
/// - 블러 배경 + 그라데이션 딤
/// - 타이틀 라벨 (좌측)
/// - Select 버튼 (우측) - 터치 반응
/// - 타이틀 영역은 터치 통과 (스크롤 제스처 방해 X)
final class FloatingTitleBar: UIView {

    // MARK: - Constants

    /// 타이틀바 콘텐츠 높이 (safe area 제외)
    static let contentHeight: CGFloat = 44

    /// 그라데이션 추가 높이 (딤/블러가 더 아래까지 내려오도록)
    private static let gradientExtension: CGFloat = 15

    /// 최대 딤 알파 (가장 어두운 부분 60%)
    private static let maxDimAlpha: CGFloat = 0.6

    // MARK: - Properties

    weak var delegate: FloatingTitleBarDelegate?

    /// 현재 타이틀 텍스트
    // ⚠️ 사진보관함 명칭 변경 시 동시 수정 필요:
    // - TabBarController.swift, GridViewController.swift, FloatingOverlayContainer.swift, FloatingTitleBar.swift (여기)
    var title: String = "사진보관함" {
        didSet {
            titleLabel.text = title
        }
    }

    /// Select 버튼 숨김 여부 (Albums 탭에서 Phase 6 전까지 숨김)
    var isSelectButtonHidden: Bool = false {
        didSet {
            selectButton.isHidden = isSelectButtonHidden
        }
    }

    /// 뒤로가기 버튼 표시 여부 (push된 화면에서 사용)
    var showsBackButton: Bool = false {
        didSet {
            backButton.isHidden = !showsBackButton
            updateTitleLabelConstraints()
        }
    }

    /// 타이틀 라벨 좌측 제약조건 (뒤로가기 버튼 유무에 따라 변경)
    private var titleLabelLeadingConstraint: NSLayoutConstraint?
    private var titleLabelLeadingToBackButtonConstraint: NSLayoutConstraint?

    // MARK: - UI Components

    /// Progressive blur 뷰 (BlurUIKit)
    /// 상단에서 하단으로 블러가 자연스럽게 페이드아웃
    /// iOS 26 기본 사진앱과 동일한 수준의 품질
    private lazy var progressiveBlurView: VariableBlurView = {
        let view = VariableBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // 블러 방향: 상단(강함) → 하단(약함)
        view.direction = .down
        // 블러 강도
        view.maximumBlurRadius = 2.0
        // 디밍 색상 (어두운 오버레이) - 가장 어두운 부분 60%
        view.dimmingTintColor = UIColor.black
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.6, darkModeAlpha: 0.5)
        return view
    }()

    /// 그라데이션 딤 레이어 (상단에서 하단으로 자연스럽게 페이드)
    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        // 상단: 더 진한 딤 → 하단: 완전 투명
        // 자연스러운 그라데이션을 위해 중간점 추가
        layer.colors = [
            UIColor.black.withAlphaComponent(Self.maxDimAlpha).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.7).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.3).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.1).cgColor,
            UIColor.clear.cgColor
        ]
        // 끝부분이 아주 자연스럽게 페이드아웃
        layer.locations = [0, 0.25, 0.5, 0.75, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

    /// 뒤로가기 버튼 (push된 화면에서 사용)
    private lazy var backButton: UIButton = {
        var config = UIButton.Configuration.plain()
        config.image = UIImage(systemName: "chevron.left")
        config.baseForegroundColor = .white
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 8, bottom: 8, trailing: 8)
        let button = UIButton(configuration: config)
        button.layer.shadowColor = UIColor.black.cgColor
        button.layer.shadowOffset = CGSize(width: 0, height: 1)
        button.layer.shadowOpacity = 0.3
        button.layer.shadowRadius = 2
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // 기본 숨김
        return button
    }()

    /// 타이틀 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.text = title
        label.font = .systemFont(ofSize: 17, weight: .semibold)
        label.textColor = .white
        // 그림자 효과로 가독성 향상
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowOpacity = 0.3
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Select 버튼 (캡슐 + 틴티드 스타일) - 가장 오른쪽
    private lazy var selectButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.title = "Select"
        // 파란색 반투명 배경 + 흰색 텍스트
        config.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        config.baseForegroundColor = .white
        // 캡슐 형태
        config.cornerStyle = .capsule
        // 터치 영역 최소 44pt 보장
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 두 번째 오른쪽 버튼 (Select 버튼 왼쪽에 배치)
    /// 휴지통 탭에서 [Select] [비우기] 동시 표시용
    private lazy var secondRightButton: UIButton = {
        var config = UIButton.Configuration.filled()
        config.baseBackgroundColor = UIColor.systemRed.withAlphaComponent(0.3)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        let button = UIButton(configuration: config)
        button.addTarget(self, action: #selector(secondRightButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // 기본 숨김
        return button
    }()

    /// 콘텐츠 컨테이너 (타이틀 + Select 버튼)
    private lazy var contentContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
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
        // Progressive blur 뷰 추가 (BlurUIKit)
        addSubview(progressiveBlurView)

        // 그라데이션 딤 레이어 추가 (블러 위에 추가 디밍)
        layer.addSublayer(gradientLayer)

        // 콘텐츠 컨테이너 추가
        addSubview(contentContainer)
        contentContainer.addSubview(backButton)
        contentContainer.addSubview(titleLabel)
        contentContainer.addSubview(secondRightButton)
        contentContainer.addSubview(selectButton)

        setupConstraints()

        print("[FloatingTitleBar] Initialized with title: \(title)")
    }

    private func setupConstraints() {
        // 타이틀 라벨 좌측 제약조건 (두 가지 버전)
        titleLabelLeadingConstraint = titleLabel.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor)
        titleLabelLeadingToBackButtonConstraint = titleLabel.leadingAnchor.constraint(equalTo: backButton.trailingAnchor, constant: 4)

        NSLayoutConstraint.activate([
            // Progressive blur 뷰: 전체 영역
            progressiveBlurView.topAnchor.constraint(equalTo: topAnchor),
            progressiveBlurView.leadingAnchor.constraint(equalTo: leadingAnchor),
            progressiveBlurView.trailingAnchor.constraint(equalTo: trailingAnchor),
            progressiveBlurView.bottomAnchor.constraint(equalTo: bottomAnchor),

            // 콘텐츠 컨테이너: safe area 아래에 44pt 높이
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor),
            contentContainer.heightAnchor.constraint(equalToConstant: Self.contentHeight),

            // 뒤로가기 버튼: 좌측 정렬, 세로 중앙
            backButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),

            // 타이틀 라벨: 세로 중앙 (좌측 제약은 동적으로 변경)
            titleLabel.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),

            // Select 버튼: 우측 정렬, 세로 중앙
            selectButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            selectButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),

            // Second Right 버튼: Select 버튼 왼쪽, 세로 중앙
            secondRightButton.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -8),
            secondRightButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
        ])

        // 초기 타이틀 라벨 좌측 제약 활성화
        updateTitleLabelConstraints()
    }

    /// 타이틀 라벨 좌측 제약조건 업데이트
    private func updateTitleLabelConstraints() {
        if showsBackButton {
            titleLabelLeadingConstraint?.isActive = false
            titleLabelLeadingToBackButtonConstraint?.isActive = true
        } else {
            titleLabelLeadingToBackButtonConstraint?.isActive = false
            titleLabelLeadingConstraint?.isActive = true
        }
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        // 그라데이션 딤 레이어 프레임 업데이트
        gradientLayer.frame = bounds
    }

    // MARK: - Hit Testing (터치 차단)

    /// 버튼만 터치 반응, 나머지 딤드 영역은 터치 차단
    /// 기본 사진 앱과 동일하게 딤드 영역에서는 스크롤 불가
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 뒤로가기 버튼 영역 체크
        let backPoint = convert(point, to: backButton)
        if backButton.bounds.contains(backPoint) && !backButton.isHidden {
            return backButton
        }

        // Second Right 버튼 영역 체크 (Select 버튼 왼쪽)
        let secondRightPoint = convert(point, to: secondRightButton)
        if secondRightButton.bounds.contains(secondRightPoint) && !secondRightButton.isHidden {
            return secondRightButton
        }

        // Select 버튼 영역 체크
        let selectPoint = convert(point, to: selectButton)
        if selectButton.bounds.contains(selectPoint) && !selectButton.isHidden {
            return selectButton
        }

        // 나머지 딤드 영역은 터치 차단 (self 반환)
        return self
    }

    // MARK: - Actions

    @objc private func backButtonTapped() {
        print("[FloatingTitleBar] Back button tapped")
        executeBackAction()
    }

    @objc private func selectButtonTapped() {
        print("[FloatingTitleBar] Select button tapped")
        delegate?.floatingTitleBarDidTapSelect(self)
    }

    // MARK: - Public Methods

    /// 타이틀바 높이 계산 (safe area 포함 + 그라데이션 확장)
    /// - Parameter safeAreaTop: 상단 safe area inset
    /// - Returns: 전체 타이틀바 높이
    static func totalHeight(safeAreaTop: CGFloat) -> CGFloat {
        return safeAreaTop + contentHeight + gradientExtension
    }

    // MARK: - Public Configuration Methods

    /// 타이틀 변경 (push된 화면에서 앨범명 등으로 변경 시 사용)
    /// - Parameter title: 새로운 타이틀
    func setTitle(_ title: String) {
        self.title = title
    }

    /// 뒤로가기 버튼 표시/숨김 설정 (push된 화면에서 사용)
    /// - Parameters:
    ///   - shows: 표시 여부
    ///   - action: 뒤로가기 버튼 탭 시 실행할 클로저 (nil이면 delegate 호출)
    private var backButtonAction: (() -> Void)?

    func setShowsBackButton(_ shows: Bool, action: (() -> Void)? = nil) {
        showsBackButton = shows
        backButtonAction = action
    }

    /// 뒤로가기 버튼 액션 실행 (클로저 또는 delegate)
    private func executeBackAction() {
        if let action = backButtonAction {
            action()
        } else {
            delegate?.floatingTitleBarDidTapBack(self)
        }
    }

    // MARK: - Custom Right Button

    /// 커스텀 오른쪽 버튼 액션
    private var rightButtonAction: (() -> Void)?

    /// 커스텀 오른쪽 버튼 설정 (Select 버튼 대체, 단일 버튼 모드)
    /// - Parameters:
    ///   - title: 버튼 타이틀
    ///   - backgroundColor: 버튼 배경색 (반투명 적용됨)
    ///   - action: 버튼 탭 시 실행할 클로저
    func setRightButton(title: String, backgroundColor: UIColor = .systemBlue, action: @escaping () -> Void) {
        // 두 번째 버튼 숨기기 (단일 버튼 모드)
        hideSecondRightButton()

        var config = UIButton.Configuration.filled()
        config.title = title
        // 캡슐 + 틴티드 스타일
        config.baseBackgroundColor = backgroundColor.withAlphaComponent(0.3)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        selectButton.configuration = config
        selectButton.isHidden = false
        rightButtonAction = action

        // 기존 액션 제거 후 새 액션 연결
        selectButton.removeTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        selectButton.removeTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
    }

    /// 오른쪽 버튼을 Select 버튼으로 복원 (캡슐 + 틴티드 스타일, 단일 버튼 모드)
    func resetToSelectButton() {
        // 두 번째 버튼 숨기기 (단일 버튼 모드)
        hideSecondRightButton()

        var config = UIButton.Configuration.filled()
        config.title = "Select"
        // 파란색 반투명 배경 + 흰색 텍스트
        config.baseBackgroundColor = UIColor.systemBlue.withAlphaComponent(0.3)
        config.baseForegroundColor = .white
        config.cornerStyle = .capsule
        config.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        selectButton.configuration = config
        rightButtonAction = nil

        // 액션 복원
        selectButton.removeTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
    }

    /// Select 모드 진입 - Cancel 버튼으로 변경
    /// - Parameter cancelAction: Cancel 버튼 탭 시 실행할 클로저
    func enterSelectMode(cancelAction: @escaping () -> Void) {
        setRightButton(title: "Cancel", backgroundColor: .systemBlue, action: cancelAction)
        print("[FloatingTitleBar] Entered select mode - showing Cancel button")
    }

    /// Select 모드 종료 - Select 버튼으로 복원
    func exitSelectMode() {
        resetToSelectButton()
        print("[FloatingTitleBar] Exited select mode - showing Select button")
    }

    @objc private func rightButtonTapped() {
        print("[FloatingTitleBar] Right button tapped")
        rightButtonAction?()
    }

    // MARK: - Two Right Buttons Support

    /// 두 번째 오른쪽 버튼 액션
    private var secondRightButtonAction: (() -> Void)?

    @objc private func secondRightButtonTapped() {
        print("[FloatingTitleBar] Second right button tapped")
        secondRightButtonAction?()
    }

    /// 두 개의 오른쪽 버튼 설정 (휴지통 탭: Select + 비우기)
    /// - Parameters:
    ///   - firstTitle: 첫 번째 버튼 타이틀 (Select 위치)
    ///   - firstColor: 첫 번째 버튼 배경색
    ///   - firstAction: 첫 번째 버튼 탭 액션
    ///   - secondTitle: 두 번째 버튼 타이틀 (왼쪽에 추가)
    ///   - secondColor: 두 번째 버튼 배경색
    ///   - secondAction: 두 번째 버튼 탭 액션
    func setTwoRightButtons(
        firstTitle: String,
        firstColor: UIColor = .systemBlue,
        firstAction: @escaping () -> Void,
        secondTitle: String,
        secondColor: UIColor = .systemRed,
        secondAction: @escaping () -> Void
    ) {
        // 첫 번째 버튼 (Select 위치 - 가장 오른쪽)
        var firstConfig = UIButton.Configuration.filled()
        firstConfig.title = firstTitle
        firstConfig.baseBackgroundColor = firstColor.withAlphaComponent(0.3)
        firstConfig.baseForegroundColor = .white
        firstConfig.cornerStyle = .capsule
        firstConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        selectButton.configuration = firstConfig
        isSelectButtonHidden = false  // 프로퍼티를 통해 설정 (다른 탭에서 숨겼을 수 있음)
        rightButtonAction = firstAction

        // 액션 연결
        selectButton.removeTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        selectButton.removeTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)

        // 두 번째 버튼 (왼쪽에 추가)
        var secondConfig = UIButton.Configuration.filled()
        secondConfig.title = secondTitle
        secondConfig.baseBackgroundColor = secondColor.withAlphaComponent(0.3)
        secondConfig.baseForegroundColor = .white
        secondConfig.cornerStyle = .capsule
        secondConfig.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
        secondRightButton.configuration = secondConfig
        secondRightButton.isHidden = false
        secondRightButtonAction = secondAction

        print("[FloatingTitleBar] Two right buttons set: [\(firstTitle)] [\(secondTitle)]")
    }

    /// 두 번째 오른쪽 버튼 숨기기 (일반 모드 복원 시)
    func hideSecondRightButton() {
        secondRightButton.isHidden = true
        secondRightButtonAction = nil
    }

    /// 모든 오른쪽 버튼을 Select 버튼만 있는 기본 상태로 복원
    func resetToDefaultRightButtons() {
        // 두 번째 버튼 숨기기
        hideSecondRightButton()

        // Select 버튼 복원
        resetToSelectButton()

        print("[FloatingTitleBar] Reset to default - showing Select button only")
    }
}

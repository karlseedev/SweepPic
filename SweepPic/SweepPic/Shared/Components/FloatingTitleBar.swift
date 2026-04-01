// FloatingTitleBar.swift
// 상단 플로팅 타이틀바 컴포넌트
//
// T027-1a: 타이틀 + Select 버튼 + 블러 배경
// - 높이: 44pt + safe area top
// - Select 버튼만 터치 반응, 나머지는 터치 통과 (hitTest 오버라이드)
// - Progressive blur 효과 (BlurUIKit 사용)

import UIKit
import AppCore
import BlurUIKit
import LiquidGlassKit

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
    private static let gradientExtension: CGFloat = 35

    /// 최대 딤 알파 (가장 어두운 부분 45%)
    private static let maxDimAlpha: CGFloat = LiquidGlassStyle.maxDimAlpha

    // MARK: - Properties

    weak var delegate: FloatingTitleBarDelegate?

    /// 현재 타이틀 텍스트
    // ⚠️ 사진보관함 명칭 변경 시 동시 수정 필요:
    // - TabBarController.swift, GridViewController.swift, FloatingOverlayContainer.swift, FloatingTitleBar.swift (여기)
    var title: String = "사진보관함" {
        didSet {
            titleLabel.attributedText = Self.styledTitle(title)
        }
    }

    /// 타이틀 스타일 적용 (자간 -0.5pt, 36pt ultraLight)
    private static func styledTitle(_ text: String) -> NSAttributedString {
        NSAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 36, weight: .light),
            .kern: -1.0
        ])
    }

    /// 서브타이틀 텍스트 (사진 개수 등)
    var subtitle: String? {
        didSet {
            subtitleLabel.text = subtitle
            subtitleLabel.isHidden = (subtitle == nil || subtitle?.isEmpty == true)
        }
    }

    /// Select 버튼 숨김 여부 (Albums 탭에서 Phase 6 전까지 숨김)
    var isSelectButtonHidden: Bool = false {
        didSet {
            selectButton.isHidden = isSelectButtonHidden
        }
    }

    /// Select 버튼 활성화 여부 (빈 앨범/삭제대기함에서 비활성화)
    var isSelectButtonEnabled: Bool = true {
        didSet {
            selectButton.isEnabled = isSelectButtonEnabled
            selectButton.alpha = isSelectButtonEnabled ? 1.0 : 0.5
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

    /// 타이틀 라벨 세로 정렬 제약조건 (top 정렬 ↔ centerY 정렬 전환용)
    private var titleLabelTopConstraint: NSLayoutConstraint?
    private var titleLabelCenterYConstraint: NSLayoutConstraint?

    /// 타이틀 세로 중앙 정렬 여부 (앨범 상세 등 작은 폰트 사용 시)
    /// 기본값 false: 상단 정렬 (36pt + 서브타이틀 구조)
    /// true: 뒤로가기 버튼과 세로 중앙 정렬 (20pt 등 작은 타이틀)
    var isTitleCenteredVertically: Bool = false {
        didSet {
            titleLabelTopConstraint?.isActive = !isTitleCenteredVertically
            titleLabelCenterYConstraint?.isActive = isTitleCenteredVertically
        }
    }

    // MARK: - UI Components

    /// Progressive blur 뷰 (BlurUIKit)
    /// 상단에서 하단으로 블러가 자연스럽게 페이드아웃
    /// iOS 26 기본 사진앱과 동일한 수준의 품질
    private lazy var progressiveBlurView: VariableBlurView = {
        let view = VariableBlurView()
        view.translatesAutoresizingMaskIntoConstraints = false
        // 블러 방향: 상단(강함) → 하단(약함)
        view.direction = .down
        // 블러 강도 - 더 투명하게
        view.maximumBlurRadius = 1.5
        // 디밍 색상 (어두운 오버레이) - 더 연하게
        view.dimmingTintColor = UIColor.black
        view.dimmingAlpha = .interfaceStyle(lightModeAlpha: 0.45, darkModeAlpha: 0.3)
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
    /// GlassIconButton 사용 - Liquid Glass 배경 + Dual state 애니메이션
    /// iOS 26 실측: 44×44, cornerRadius 22, tintColor 흰색
    private lazy var backButton: GlassIconButton = {
        // Phase 6: hidden 상태이므로 Glass 효과(MTKView) 생성 지연
        // showsBackButton = true 시 isHidden didSet에서 자동 생성
        let button = GlassIconButton(icon: "chevron.left", size: .medium, tintColor: .white, deferGlassEffect: true)
        button.addTarget(self, action: #selector(backButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // 기본 숨김
        return button
    }()

    /// 타이틀 라벨
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.attributedText = Self.styledTitle(title)
        label.font = .systemFont(ofSize: 36, weight: .light)
        label.textColor = .white
        // 그림자 효과로 가독성 향상
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowOpacity = 0.3
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// 서브타이틀 라벨 (사진 개수 표시)
    private lazy var subtitleLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 14, weight: .black)
        label.textColor = .white
        label.isHidden = true
        // 그림자 효과로 가독성 향상
        label.layer.shadowColor = UIColor.black.cgColor
        label.layer.shadowOffset = CGSize(width: 0, height: 1)
        label.layer.shadowOpacity = 0.3
        label.layer.shadowRadius = 2
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Select 버튼 (Liquid Glass 스타일) - 가장 오른쪽
    /// iOS 26 스펙: 높이 44pt, fontSize 17pt
    private lazy var selectButton: GlassTextButton = {
        // 초기 크기를 "간편정리"(4글자) 기준으로 생성 — 보관함 첫 화면에서 Glass 배경 크기 보장
        let button = GlassTextButton(title: "간편정리", style: .plain, tintColor: .white)
        button.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// 두 번째 오른쪽 버튼 - 텍스트 (Select 버튼 왼쪽에 배치)
    /// 삭제대기함 탭에서 [Select] [비우기] 동시 표시용
    /// iOS 26 스펙: 높이 38pt, fontSize 17pt
    private lazy var secondRightButton: GlassTextButton = {
        let button = GlassTextButton(title: "", style: .plain, tintColor: .white)
        button.addTarget(self, action: #selector(secondRightButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // 기본 숨김
        return button
    }()

    /// 두 번째 오른쪽 버튼 - 아이콘 (Select 버튼 왼쪽에 배치)
    /// 정리 버튼 등 아이콘이 필요한 경우 사용
    private lazy var secondRightIconButton: GlassIconButton = {
        let button = GlassIconButton(icon: "wand.and.stars", size: .medium, tintColor: .systemBlue)
        button.addTarget(self, action: #selector(secondRightButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.isHidden = true // 기본 숨김
        return button
    }()

    /// 메뉴 버튼 뷰 접근 (뱃지 오버레이용)
    var menuButtonView: UIView { menuButton }

    /// 메뉴 버튼 (최우측, 햄버거 아이콘)
    /// 탭 시 UIMenu 풀다운 메뉴 표시
    private lazy var menuButton: GlassIconButton = {
        let button = GlassIconButton(icon: "ellipsis", size: .medium, tintColor: .white)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.showsMenuAsPrimaryAction = true
        button.isHidden = true // 기본 숨김
        return button
    }()

    /// Select 버튼 trailing 제약 (메뉴 버튼 유무에 따라 전환)
    private var selectButtonTrailingToContainer: NSLayoutConstraint?
    private var selectButtonTrailingToMenu: NSLayoutConstraint?

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
        contentContainer.addSubview(subtitleLabel)
        contentContainer.addSubview(secondRightButton)
        contentContainer.addSubview(secondRightIconButton)
        contentContainer.addSubview(selectButton)
        contentContainer.addSubview(menuButton)

        setupConstraints()
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
            progressiveBlurView.bottomAnchor.constraint(equalTo: bottomAnchor, constant: 8),

            // 콘텐츠 컨테이너: safe area 아래에 44pt 높이
            contentContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            contentContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            contentContainer.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -28),
            contentContainer.heightAnchor.constraint(equalToConstant: Self.contentHeight),

            // 뒤로가기 버튼: 좌측 정렬, 세로 중앙
            backButton.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
            backButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),

            // 타이틀 라벨: 좌측 제약은 동적으로 변경 (뒤로가기 버튼 유무)

            // 서브타이틀 라벨: 타이틀 바로 아래
            subtitleLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: -1),
            subtitleLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            // Select 버튼: 세로 중앙 (trailing은 동적 전환)
            selectButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),

            // Second Right 버튼 (텍스트): Select 버튼 왼쪽, 세로 중앙
            secondRightButton.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -8),
            secondRightButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),

            // Second Right 버튼 (아이콘): Select 버튼 왼쪽, 세로 중앙
            secondRightIconButton.trailingAnchor.constraint(equalTo: selectButton.leadingAnchor, constant: -8),
            secondRightIconButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),

            // 메뉴 버튼: 최우측, 세로 중앙
            menuButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
            menuButton.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor),
        ])

        // Select 버튼 trailing 제약 (메뉴 버튼 유무에 따라 전환)
        selectButtonTrailingToContainer = selectButton.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor)
        selectButtonTrailingToMenu = selectButton.trailingAnchor.constraint(equalTo: menuButton.leadingAnchor, constant: -8)
        selectButtonTrailingToContainer?.isActive = true  // 기본: 컨테이너 우측 정렬

        // 타이틀 세로 정렬 제약 (top / centerY 전환용)
        titleLabelTopConstraint = titleLabel.topAnchor.constraint(equalTo: contentContainer.topAnchor, constant: 2)
        titleLabelCenterYConstraint = titleLabel.centerYAnchor.constraint(equalTo: contentContainer.centerYAnchor)
        titleLabelTopConstraint?.isActive = true       // 기본: 상단 정렬
        titleLabelCenterYConstraint?.isActive = false

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

        // Second Right 아이콘 버튼 영역 체크 (Select 버튼 왼쪽)
        let secondRightIconPoint = convert(point, to: secondRightIconButton)
        if secondRightIconButton.bounds.contains(secondRightIconPoint) && !secondRightIconButton.isHidden {
            return secondRightIconButton
        }

        // Second Right 텍스트 버튼 영역 체크 (Select 버튼 왼쪽)
        let secondRightPoint = convert(point, to: secondRightButton)
        if secondRightButton.bounds.contains(secondRightPoint) && !secondRightButton.isHidden {
            return secondRightButton
        }

        // Select 버튼 영역 체크
        let selectPoint = convert(point, to: selectButton)
        if selectButton.bounds.contains(selectPoint) && !selectButton.isHidden {
            return selectButton
        }

        // 메뉴 버튼 영역 체크 (최우측)
        let menuPoint = convert(point, to: menuButton)
        if menuButton.bounds.contains(menuPoint) && !menuButton.isHidden {
            return menuButton
        }

        // 나머지 딤드 영역은 터치 차단 (self 반환)
        return self
    }

    // MARK: - Actions

    @objc private func backButtonTapped() {
        executeBackAction()
    }

    @objc private func selectButtonTapped() {
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

    /// 커스텀 속성으로 타이틀 변경 (앨범 상세 등 별도 폰트 사용 시)
    /// - Parameters:
    ///   - title: 타이틀 텍스트
    ///   - attributes: 텍스트 속성 (font, kern 등)
    func setTitle(_ title: String, attributes: [NSAttributedString.Key: Any]) {
        titleLabel.attributedText = NSAttributedString(string: title, attributes: attributes)
    }

    /// 서브타이틀 변경 (사진 개수 등 동적 표시)
    /// - Parameter subtitle: 서브타이틀 텍스트 (nil이면 숨김)
    func setSubtitle(_ subtitle: String?) {
        self.subtitle = subtitle
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
    ///   - backgroundColor: 버튼 배경색 (현재 GlassTextButton은 초기화 시 색상 고정)
    ///   - action: 버튼 탭 시 실행할 클로저
    func setRightButton(title: String, backgroundColor: UIColor = .systemBlue, action: @escaping () -> Void) {
        // 두 번째 버튼 숨기기 (단일 버튼 모드)
        hideSecondRightButton()

        // GlassTextButton 텍스트 설정
        selectButton.setButtonTitle(title)

        selectButton.isHidden = false
        rightButtonAction = action

        // UIMenu 모드 해제 (간편정리 메뉴 → 취소 버튼 전환 시)
        selectButton.menu = nil
        selectButton.showsMenuAsPrimaryAction = false

        // 기존 액션 제거 후 새 액션 연결
        selectButton.removeTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        selectButton.removeTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
    }

    /// 오른쪽 버튼을 Select 버튼으로 복원 (캡슐 + 틴티드 스타일, 단일 버튼 모드)
    func resetToSelectButton() {
        // 두 번째 버튼 숨기기 (단일 버튼 모드)
        hideSecondRightButton()

        // GlassTextButton 텍스트 설정
        selectButton.setButtonTitle("선택")

        // UIMenu 모드 해제 (간편정리 메뉴 → 선택 버튼 복원 시)
        selectButton.menu = nil
        selectButton.showsMenuAsPrimaryAction = false

        rightButtonAction = nil

        // 액션 복원
        selectButton.removeTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
    }

    /// Select 모드 진입 - Cancel 버튼으로 변경
    /// - Parameter cancelAction: Cancel 버튼 탭 시 실행할 클로저
    func enterSelectMode(cancelAction: @escaping () -> Void) {
        setRightButton(title: "취소", backgroundColor: .systemBlue, action: cancelAction)
        // 정리 버튼, 메뉴 버튼 숨기기 (iOS 26 시스템 UI와 동일하게)
        secondRightButton.isHidden = true
        secondRightIconButton.isHidden = true
        menuButton.isHidden = true
        // 메뉴 버튼 숨김 → 취소 버튼을 컨테이너 우측 끝으로 정렬
        selectButtonTrailingToMenu?.isActive = false
        selectButtonTrailingToContainer?.isActive = true
    }

    /// Select 모드 종료 - Select 버튼으로 복원
    func exitSelectMode() {
        resetToSelectButton()
    }

    @objc private func rightButtonTapped() {
        rightButtonAction?()
    }

    // MARK: - Two Right Buttons Support

    /// 두 번째 오른쪽 버튼 액션
    private var secondRightButtonAction: (() -> Void)?

    @objc private func secondRightButtonTapped() {
        secondRightButtonAction?()
    }

    /// 두 개의 오른쪽 버튼 설정 (삭제대기함 탭: Select + 비우기)
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
        secondTitle: String? = nil,
        secondIcon: String? = nil,
        secondColor: UIColor = .systemRed,
        secondAction: @escaping () -> Void
    ) {
        // 첫 번째 버튼 (Select 위치 - 가장 오른쪽)
        selectButton.setButtonTitle(firstTitle)
        selectButton.setTextColor(firstColor)

        isSelectButtonHidden = false  // 프로퍼티를 통해 설정 (다른 탭에서 숨겼을 수 있음)
        rightButtonAction = firstAction

        // 액션 연결
        selectButton.removeTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        selectButton.removeTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        selectButton.addTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)

        // 두 번째 버튼 (왼쪽에 추가) — 아이콘 또는 텍스트
        if let secondIcon {
            // 아이콘 모드: GlassIconButton 사용
            secondRightIconButton.setIcon(secondIcon)
            secondRightIconButton.isHidden = false
            secondRightButton.isHidden = true
        } else if let secondTitle {
            // 텍스트 모드: GlassTextButton 사용
            secondRightButton.setButtonTitle(secondTitle)
            secondRightButton.setTextColor(secondColor)
            // title 변경 후 Auto Layout 강제 계산 → glassView가 올바른 크기로 레이아웃
            secondRightButton.superview?.layoutIfNeeded()
            secondRightButton.isHidden = false
            // idle에서 paused된 MTKView를 resume → 올바른 크기로 다시 렌더링
            LiquidGlassOptimizer.resumeAllMTKViews(in: secondRightButton)
            secondRightIconButton.isHidden = true
        }
        secondRightButtonAction = secondAction
    }

    /// 두 번째 오른쪽 버튼(비우기/정리)의 window 좌표 frame 반환
    /// E-1+E-2 시퀀스 Step 3에서 하이라이트 구멍 위치로 사용
    /// 버튼이 숨겨져 있거나 window가 없으면 nil 반환
    func secondRightButtonFrameInWindow() -> CGRect? {
        // 아이콘 버튼이 보이면 아이콘 버튼 프레임 반환
        if !secondRightIconButton.isHidden,
           let window = secondRightIconButton.window {
            return secondRightIconButton.convert(secondRightIconButton.bounds, to: window)
        }
        // 텍스트 버튼이 보이면 텍스트 버튼 프레임 반환
        guard !secondRightButton.isHidden,
              let window = secondRightButton.window else { return nil }
        return secondRightButton.convert(secondRightButton.bounds, to: window)
    }

    /// 두 번째 오른쪽 버튼 숨기기 (일반 모드 복원 시)
    func hideSecondRightButton() {
        secondRightButton.isHidden = true
        secondRightIconButton.isHidden = true
        secondRightButtonAction = nil
    }

    /// 두 버튼 활성화/비활성화 설정 (삭제대기함 빈 상태 등)
    /// - Parameters:
    ///   - firstEnabled: 첫 번째 버튼 (Select) 활성화 여부
    ///   - secondEnabled: 두 번째 버튼 (비우기) 활성화 여부
    func setTwoRightButtonsEnabled(firstEnabled: Bool, secondEnabled: Bool) {
        selectButton.isEnabled = firstEnabled
        selectButton.alpha = firstEnabled ? 1.0 : 0.5
        // 텍스트/아이콘 중 보이는 쪽에 적용
        secondRightButton.isEnabled = secondEnabled
        secondRightButton.alpha = secondEnabled ? 1.0 : 0.5
        secondRightIconButton.isEnabled = secondEnabled
        secondRightIconButton.alpha = secondEnabled ? 1.0 : 0.5
    }

    /// 모든 오른쪽 버튼을 Select 버튼만 있는 기본 상태로 복원
    func resetToDefaultRightButtons() {
        // 두 번째 버튼 숨기기
        hideSecondRightButton()

        // 메뉴 버튼 숨기기
        hideMenuButton()

        // Select 버튼 복원
        resetToSelectButton()
    }

    // MARK: - Menu Button

    /// 메뉴 버튼 표시 (최우측, UIMenu 풀다운)
    /// - Parameter menu: 표시할 UIMenu
    func showMenuButton(menu: UIMenu) {
        menuButton.menu = menu
        menuButton.isHidden = false

        // Select 버튼 trailing을 메뉴 버튼 왼쪽으로 전환
        selectButtonTrailingToContainer?.isActive = false
        selectButtonTrailingToMenu?.isActive = true
    }

    /// 메뉴 버튼 숨기기
    func hideMenuButton() {
        menuButton.isHidden = true
        menuButton.menu = nil

        // Select 버튼 trailing을 컨테이너 우측으로 복원
        selectButtonTrailingToMenu?.isActive = false
        selectButtonTrailingToContainer?.isActive = true
    }

    // MARK: - Right Menu Button (간편정리 등 텍스트+UIMenu 풀다운)

    /// 오른쪽 메뉴 버튼 설정 (탭 시 UIMenu 풀다운)
    /// selectButton 위치에 텍스트 + UIMenu를 배치합니다.
    /// - Parameters:
    ///   - title: 버튼 타이틀 (예: "간편정리")
    ///   - menu: 탭 시 표시할 UIMenu
    func setRightMenuButton(title: String, menu: UIMenu) {
        // 두 번째 버튼 숨기기 (메뉴 버튼 단일 모드)
        hideSecondRightButton()

        // GlassTextButton 텍스트 설정
        selectButton.setButtonTitle(title)

        // 기존 target/action 제거
        selectButton.removeTarget(self, action: #selector(selectButtonTapped), for: .touchUpInside)
        selectButton.removeTarget(self, action: #selector(rightButtonTapped), for: .touchUpInside)
        rightButtonAction = nil

        // UIMenu 풀다운으로 동작하도록 설정
        selectButton.menu = menu
        selectButton.showsMenuAsPrimaryAction = true

        isSelectButtonHidden = false
    }

    /// 오른쪽 메뉴 버튼 활성화/비활성화 (간편정리 버튼용)
    /// - Parameter enabled: 활성화 여부
    func setRightMenuButtonEnabled(_ enabled: Bool) {
        selectButton.isEnabled = enabled
        selectButton.alpha = enabled ? 1.0 : 0.5
    }

    /// 오른쪽 메뉴 버튼(간편정리)의 window 좌표 frame 반환
    /// 코치마크 D 하이라이트 위치 등에서 사용
    /// 버튼이 숨겨져 있거나 window가 없으면 nil 반환
    func rightMenuButtonFrameInWindow() -> CGRect? {
        guard !selectButton.isHidden,
              let window = selectButton.window else { return nil }
        return selectButton.convert(selectButton.bounds, to: window)
    }
}

// LiquidGlassTabBar.swift
// Liquid Glass 스타일 탭바 메인 컴포넌트
//
// iOS 26 TabBar와 동일한 시각 효과 및 동작 구현
// - Platter 배경 + Selection Pill + Tab Buttons 조합
// - Spring 애니메이션으로 Pill 이동
// - LiquidGlassTabBarDelegate 프로토콜
// - Select 모드 (Grid/Album) 및 Trash Select 모드 지원

import UIKit
import AppCore

// MARK: - LiquidGlassTabBarDelegate

/// Liquid Glass 탭바 델리게이트
/// FloatingTabBarDelegate와 동일한 기능을 제공
protocol LiquidGlassTabBarDelegate: AnyObject {
    /// 탭 선택 시 호출
    func liquidGlassTabBar(_ tabBar: LiquidGlassTabBar, didSelectTabAt index: Int)

    /// Select 모드에서 Delete 버튼 탭
    func liquidGlassTabBarDidTapDelete(_ tabBar: LiquidGlassTabBar)

    /// 삭제대기함 비우기 버튼 탭
    func liquidGlassTabBarDidTapEmptyTrash(_ tabBar: LiquidGlassTabBar)

    /// 삭제대기함 Select 모드에서 Restore 버튼 탭
    func liquidGlassTabBarDidTapRestore(_ tabBar: LiquidGlassTabBar)

    /// 삭제대기함 Select 모드에서 Delete 버튼 탭 (영구 삭제)
    func liquidGlassTabBarDidTapTrashDelete(_ tabBar: LiquidGlassTabBar)
}

// MARK: - Default Implementation

extension LiquidGlassTabBarDelegate {
    func liquidGlassTabBarDidTapEmptyTrash(_ tabBar: LiquidGlassTabBar) {}
    func liquidGlassTabBarDidTapRestore(_ tabBar: LiquidGlassTabBar) {}
    func liquidGlassTabBarDidTapTrashDelete(_ tabBar: LiquidGlassTabBar) {}
}

// MARK: - LiquidGlassTabBar

/// Liquid Glass 스타일 탭바
/// FloatingTabBar를 대체하는 iOS 26 스타일 탭바
final class LiquidGlassTabBar: UIView {

    // MARK: - Constants

    /// 그라데이션 딤 최대 알파
    private static let maxDimAlpha: CGFloat = LiquidGlassStyle.maxDimAlpha

    // MARK: - Properties

    /// 델리게이트
    weak var delegate: LiquidGlassTabBarDelegate?

    /// 현재 선택된 탭 인덱스
    var selectedIndex: Int = 0 {
        didSet {
            updateSelection(animated: true)
        }
    }

    /// Select 모드 여부 (Grid/Album용)
    private(set) var isSelectMode: Bool = false

    /// Trash Select 모드 여부 (Trash 전용)
    private(set) var isTrashSelectMode: Bool = false

    /// Platter 너비 (레이아웃 계산용)
    private var platterWidth: CGFloat = 0

    // MARK: - UI Components (Normal Mode)

    /// 그라데이션 딤 레이어
    private lazy var gradientLayer: CAGradientLayer = {
        let layer = CAGradientLayer()
        layer.colors = [
            UIColor.clear.cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.33).cgColor,
            UIColor.black.withAlphaComponent(Self.maxDimAlpha * 0.66).cgColor,
            UIColor.black.withAlphaComponent(0.60).cgColor,
            UIColor.black.withAlphaComponent(0.60).cgColor
        ]
        layer.locations = [0, 0.23, 0.47, 0.7, 1.0]
        layer.startPoint = CGPoint(x: 0.5, y: 0)
        layer.endPoint = CGPoint(x: 0.5, y: 1)
        return layer
    }()

    /// 그림자 컨테이너 (Platter 포함)
    private lazy var shadowContainer: LiquidGlassShadowContainer = {
        let view = LiquidGlassShadowContainer()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Selection Pill
    private lazy var selectionPill: LiquidGlassSelectionPill = {
        let view = LiquidGlassSelectionPill()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 탭 버튼 배열
    private lazy var tabButtons: [LiquidGlassTabButton] = {
        let buttons = [
            LiquidGlassTabButton(
                index: 0,
                icon: "photo.on.rectangle",
                selectedIcon: "photo.on.rectangle.fill",
                title: "보관함"
            ),
            LiquidGlassTabButton(
                index: 1,
                icon: "rectangle.stack",
                selectedIcon: "rectangle.stack.fill",
                title: "앨범"
            ),
            LiquidGlassTabButton(
                index: 2,
                icon: "xmark.bin",
                selectedIcon: "xmark.bin.fill",
                title: "삭제대기함"
            ),
        ]
        buttons.forEach { button in
            button.translatesAutoresizingMaskIntoConstraints = false
            button.addTarget(self, action: #selector(tabButtonTapped(_:)), for: .touchUpInside)
        }
        return buttons
    }()

    // MARK: - UI Components (Select Mode - Grid/Album)

    /// Select 모드 컨테이너
    private lazy var selectModeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// 선택 개수 라벨
    private lazy var selectionCountLabel: UILabel = {
        let label = UILabel()
        label.text = "항목 선택"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Delete 버튼
    /// iOS 26 스펙: 높이 44pt, fontSize 17pt
    /// Phase 6: select 모드 전용이므로 Glass 효과(MTKView) 생성 지연
    private lazy var deleteButton: GlassTextButton = {
        let button = GlassTextButton(title: "삭제", style: .plain, tintColor: .systemRed, deferGlassEffect: true)
        button.addTarget(self, action: #selector(deleteButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - UI Components (Trash Select Mode)

    /// Trash Select 모드 컨테이너
    private lazy var trashSelectModeContainer: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.isHidden = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    /// Trash Restore 버튼
    /// iOS 26 스펙: 높이 44pt, fontSize 17pt
    /// Phase 6: trash select 모드 전용이므로 Glass 효과(MTKView) 생성 지연
    private lazy var trashRestoreButton: GlassTextButton = {
        let button = GlassTextButton(title: "복구", style: .plain, tintColor: .white, deferGlassEffect: true)
        button.addTarget(self, action: #selector(trashRestoreButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    /// Trash 선택 개수 라벨
    private lazy var trashSelectionCountLabel: UILabel = {
        let label = UILabel()
        label.text = "항목 선택"
        label.textColor = .white
        label.font = .systemFont(ofSize: 17, weight: .regular)
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()

    /// Trash Delete 버튼
    /// iOS 26 스펙: 높이 44pt, fontSize 17pt
    /// Phase 6: trash select 모드 전용이므로 Glass 효과(MTKView) 생성 지연
    private lazy var trashDeleteButton: GlassTextButton = {
        let button = GlassTextButton(title: "삭제", style: .plain, tintColor: .systemRed, deferGlassEffect: true)
        button.addTarget(self, action: #selector(trashDeleteButtonTapped), for: .touchUpInside)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }()

    // MARK: - Initialization

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
        setupConstraints()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        setupConstraints()
    }

    // MARK: - Setup

    private func setupUI() {
        // 그라데이션 레이어
        layer.addSublayer(gradientLayer)

        // 일반 모드 UI
        addSubview(shadowContainer)

        // Platter 내부에 Selection Pill과 버튼 추가
        shadowContainer.platter.addSubview(selectionPill)
        tabButtons.forEach { shadowContainer.platter.addSubview($0) }

        // Select 모드 UI (Grid/Album)
        addSubview(selectModeContainer)
        selectModeContainer.addSubview(selectionCountLabel)
        selectModeContainer.addSubview(deleteButton)

        // Trash Select 모드 UI
        addSubview(trashSelectModeContainer)
        trashSelectModeContainer.addSubview(trashRestoreButton)
        trashSelectModeContainer.addSubview(trashSelectionCountLabel)
        trashSelectModeContainer.addSubview(trashDeleteButton)

    }

    private func setupConstraints() {
        let platterConst = LiquidGlassConstants.Platter.self
        let pillConst = LiquidGlassConstants.SelectionPill.self
        let buttonConst = LiquidGlassConstants.TabButton.self

        // Platter 너비 계산
        let screenWidth = UIScreen.main.bounds.width
        platterWidth = platterConst.calculatedWidth(screenWidth: screenWidth)

        // 버튼 그룹 중앙 정렬을 위한 좌측 패딩 계산
        let contentWidth = platterConst.contentWidth
        let leftPadding = (platterWidth - contentWidth) / 2 + platterConst.padding

        NSLayoutConstraint.activate([
            // Shadow Container (Platter): 중앙 상단 정렬
            shadowContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            shadowContainer.topAnchor.constraint(equalTo: topAnchor),
            shadowContainer.widthAnchor.constraint(equalToConstant: platterWidth),
            shadowContainer.heightAnchor.constraint(equalToConstant: platterConst.height),
        ])

        // Selection Pill constraints
        let pillLeading = selectionPill.leadingAnchor.constraint(
            equalTo: shadowContainer.platter.leadingAnchor,
            constant: leftPadding
        )
        selectionPill.setLeadingConstraint(pillLeading)

        NSLayoutConstraint.activate([
            selectionPill.topAnchor.constraint(
                equalTo: shadowContainer.platter.topAnchor,
                constant: platterConst.padding
            ),
            pillLeading,
            selectionPill.widthAnchor.constraint(equalToConstant: pillConst.width),
            selectionPill.heightAnchor.constraint(equalToConstant: pillConst.height),
        ])

        // Tab Buttons constraints
        for (index, button) in tabButtons.enumerated() {
            NSLayoutConstraint.activate([
                button.topAnchor.constraint(
                    equalTo: shadowContainer.platter.topAnchor,
                    constant: platterConst.padding
                ),
                button.widthAnchor.constraint(equalToConstant: buttonConst.width),
                button.heightAnchor.constraint(equalToConstant: buttonConst.height),
            ])

            if index == 0 {
                // 첫 버튼: 중앙 정렬된 시작 위치
                button.leadingAnchor.constraint(
                    equalTo: shadowContainer.platter.leadingAnchor,
                    constant: leftPadding
                ).isActive = true
            } else {
                // 버튼 간 겹침
                button.leadingAnchor.constraint(
                    equalTo: tabButtons[index - 1].trailingAnchor,
                    constant: buttonConst.spacing
                ).isActive = true
            }
        }

        // Select 모드 컨테이너 (Grid/Album)
        // priority 999: 초기 레이아웃 시 _UITemporaryLayoutWidth(width=0) 충돌 방지
        let selectTrailing = selectModeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        selectTrailing.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            selectModeContainer.topAnchor.constraint(equalTo: topAnchor),
            selectModeContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            selectTrailing,
            selectModeContainer.heightAnchor.constraint(equalToConstant: platterConst.height),

            selectionCountLabel.centerXAnchor.constraint(equalTo: selectModeContainer.centerXAnchor),
            selectionCountLabel.centerYAnchor.constraint(equalTo: selectModeContainer.centerYAnchor),

            deleteButton.trailingAnchor.constraint(equalTo: selectModeContainer.trailingAnchor),
            deleteButton.centerYAnchor.constraint(equalTo: selectModeContainer.centerYAnchor),
        ])

        // Trash Select 모드 컨테이너
        // priority 999: 초기 레이아웃 시 _UITemporaryLayoutWidth(width=0) 충돌 방지
        let trashTrailing = trashSelectModeContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16)
        trashTrailing.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            trashSelectModeContainer.topAnchor.constraint(equalTo: topAnchor),
            trashSelectModeContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            trashTrailing,
            trashSelectModeContainer.heightAnchor.constraint(equalToConstant: platterConst.height),

            trashRestoreButton.leadingAnchor.constraint(equalTo: trashSelectModeContainer.leadingAnchor),
            trashRestoreButton.centerYAnchor.constraint(equalTo: trashSelectModeContainer.centerYAnchor),

            trashSelectionCountLabel.centerXAnchor.constraint(equalTo: trashSelectModeContainer.centerXAnchor),
            trashSelectionCountLabel.centerYAnchor.constraint(equalTo: trashSelectModeContainer.centerYAnchor),

            trashDeleteButton.trailingAnchor.constraint(equalTo: trashSelectModeContainer.trailingAnchor),
            trashDeleteButton.centerYAnchor.constraint(equalTo: trashSelectModeContainer.centerYAnchor),
        ])

        // 초기 선택 상태
        updateSelection(animated: false)
    }

    // MARK: - Layout

    override func layoutSubviews() {
        super.layoutSubviews()
        gradientLayer.frame = bounds
    }

    // MARK: - Hit Testing

    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Trash Select 모드
        if isTrashSelectMode {
            let restorePoint = convert(point, to: trashRestoreButton)
            if trashRestoreButton.bounds.contains(restorePoint) {
                return trashRestoreButton
            }
            let deletePoint = convert(point, to: trashDeleteButton)
            if trashDeleteButton.bounds.contains(deletePoint) {
                return trashDeleteButton
            }
            return self
        }

        // Select 모드 (Grid/Album)
        if isSelectMode {
            let deletePoint = convert(point, to: deleteButton)
            if deleteButton.bounds.contains(deletePoint) {
                return deleteButton
            }
            return self
        }

        // 일반 모드: 탭 버튼 체크
        for button in tabButtons {
            let buttonPoint = convert(point, to: button)
            if button.bounds.contains(buttonPoint) {
                return button
            }
        }

        // 딤드 영역 터치 차단
        return self
    }

    // MARK: - Private Methods

    private func updateSelection(animated: Bool) {
        guard selectedIndex < tabButtons.count else { return }

        // Selection Pill 이동
        let targetButton = tabButtons[selectedIndex]
        selectionPill.moveTo(button: targetButton, animated: animated)

        // 버튼 상태 업데이트
        for (index, button) in tabButtons.enumerated() {
            button.isSelectedTab = (index == selectedIndex)
        }
    }

    // MARK: - Actions

    @objc private func tabButtonTapped(_ sender: LiquidGlassTabButton) {
        let index = sender.tabIndex
        selectedIndex = index
        delegate?.liquidGlassTabBar(self, didSelectTabAt: index)
    }

    @objc private func deleteButtonTapped() {
        delegate?.liquidGlassTabBarDidTapDelete(self)
    }

    @objc private func trashRestoreButtonTapped() {
        delegate?.liquidGlassTabBarDidTapRestore(self)
    }

    @objc private func trashDeleteButtonTapped() {
        delegate?.liquidGlassTabBarDidTapTrashDelete(self)
    }
}

// MARK: - Public Methods (Select Mode)

extension LiquidGlassTabBar {

    /// Select 모드 진입 (Grid/Album용)
    func enterSelectMode(animated: Bool = true) {
        // Phase 6: deferred된 Glass 효과 생성 (select 모드 진입 시점)
        deleteButton.setupGlassEffectIfNeeded()
        isSelectMode = true
        selectionCountLabel.text = "항목 선택"
        deleteButton.isEnabled = false

        if animated {
            selectModeContainer.isHidden = false
            selectModeContainer.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.shadowContainer.alpha = 0
                self.selectModeContainer.alpha = 1
            } completion: { _ in
                self.shadowContainer.isHidden = true
            }
        } else {
            shadowContainer.isHidden = true
            shadowContainer.alpha = 0
            selectModeContainer.isHidden = false
            selectModeContainer.alpha = 1
        }

    }

    /// Select 모드 종료 (Grid/Album용)
    func exitSelectMode(animated: Bool = true) {
        isSelectMode = false

        if animated {
            shadowContainer.isHidden = false
            shadowContainer.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.shadowContainer.alpha = 1
                self.selectModeContainer.alpha = 0
            } completion: { _ in
                self.selectModeContainer.isHidden = true
            }
        } else {
            shadowContainer.isHidden = false
            shadowContainer.alpha = 1
            selectModeContainer.isHidden = true
            selectModeContainer.alpha = 0
        }

    }

    /// 선택 개수 업데이트 (Grid/Album용)
    func updateSelectionCount(_ count: Int) {
        selectionCountLabel.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
        deleteButton.isEnabled = count > 0
    }
}

// MARK: - Public Methods (Trash Select Mode)

extension LiquidGlassTabBar {

    /// Trash Select 모드 진입
    func enterTrashSelectMode(animated: Bool = true) {
        // Phase 6: deferred된 Glass 효과 생성 (trash select 모드 진입 시점)
        trashRestoreButton.setupGlassEffectIfNeeded()
        trashDeleteButton.setupGlassEffectIfNeeded()
        isTrashSelectMode = true
        trashSelectionCountLabel.text = "항목 선택"
        trashRestoreButton.isEnabled = false
        trashDeleteButton.isEnabled = false

        if animated {
            trashSelectModeContainer.isHidden = false
            trashSelectModeContainer.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.shadowContainer.alpha = 0
                self.trashSelectModeContainer.alpha = 1
            } completion: { _ in
                self.shadowContainer.isHidden = true
            }
        } else {
            shadowContainer.isHidden = true
            shadowContainer.alpha = 0
            trashSelectModeContainer.isHidden = false
            trashSelectModeContainer.alpha = 1
        }

    }

    /// Trash Select 모드 종료
    func exitTrashSelectMode(animated: Bool = true) {
        isTrashSelectMode = false

        if animated {
            shadowContainer.isHidden = false
            shadowContainer.alpha = 0
            UIView.animate(withDuration: 0.25) {
                self.shadowContainer.alpha = 1
                self.trashSelectModeContainer.alpha = 0
            } completion: { _ in
                self.trashSelectModeContainer.isHidden = true
            }
        } else {
            shadowContainer.isHidden = false
            shadowContainer.alpha = 1
            trashSelectModeContainer.isHidden = true
            trashSelectModeContainer.alpha = 0
        }

    }

    /// Trash 선택 개수 업데이트
    func updateTrashSelectionCount(_ count: Int) {
        trashSelectionCountLabel.text = count > 0 ? "\(count)개 항목 선택됨" : "항목 선택"
        trashRestoreButton.isEnabled = count > 0
        trashDeleteButton.isEnabled = count > 0
    }
}

// MARK: - Public Methods (Badge)

extension LiquidGlassTabBar {

    /// 삭제대기함 탭 배지 업데이트
    /// - Parameter count: 삭제대기함에 있는 사진 수 (0이면 배지 숨김)
    func updateTrashBadge(_ count: Int) {
        // 삭제대기함 버튼은 index 2
        guard tabButtons.count > 2 else { return }
        tabButtons[2].updateBadge(count: count)
    }
}

// MARK: - Public Methods (Height Calculation)

extension LiquidGlassTabBar {

    /// 탭바 높이 계산 (safe area 포함)
    static func totalHeight(safeAreaBottom: CGFloat) -> CGFloat {
        return LiquidGlassConstants.Platter.height + safeAreaBottom
    }
}

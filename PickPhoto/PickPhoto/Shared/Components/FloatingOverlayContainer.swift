// FloatingOverlayContainer.swift
// 플로팅 오버레이 컨테이너 컴포넌트
//
// T027-1c: 상하단 그라데이션 + 블러뷰, FloatingTitleBar/FloatingTabBar 배치
// - 적용 위치: TabBarController.view 위에 한 번만 붙임 (탭 전환에도 유지)
// - 현재 탭 타이틀/선택 상태만 동기화
// - Albums 탭: 동일 오버레이, 타이틀만 "Albums"로 변경
// - 고정 레이어로 성능 유지 (스크롤과 무관)

import UIKit

/// 플로팅 오버레이 컨테이너 델리게이트
/// 탭 선택 및 Select 모드 이벤트 전달
protocol FloatingOverlayContainerDelegate: AnyObject {
    /// 탭 선택 시 호출
    func floatingOverlay(_ container: FloatingOverlayContainer, didSelectTabAt index: Int)

    /// Select 버튼 탭 시 호출
    func floatingOverlayDidTapSelect(_ container: FloatingOverlayContainer)

    /// Select 모드에서 Cancel 버튼 탭
    func floatingOverlayDidTapCancel(_ container: FloatingOverlayContainer)

    /// Select 모드에서 Delete 버튼 탭
    func floatingOverlayDidTapDelete(_ container: FloatingOverlayContainer)

    /// 휴지통 비우기(삭제하기) 버튼 탭
    func floatingOverlayDidTapEmptyTrash(_ container: FloatingOverlayContainer)
}

/// 플로팅 오버레이 컨테이너
/// TabBarController.view 위에 배치되어 탭 전환에도 유지되는 플로팅 UI
/// - 상단: FloatingTitleBar (타이틀 + Select 버튼)
/// - 하단: FloatingTabBar (캡슐 탭바 / Select 툴바)
/// - 고정 레이어로 스크롤 성능에 영향 없음
final class FloatingOverlayContainer: UIView {

    // MARK: - Properties

    weak var delegate: FloatingOverlayContainerDelegate?

    /// 현재 선택된 탭 인덱스
    var selectedTabIndex: Int = 0 {
        didSet {
            updateForCurrentTab()
        }
    }

    /// 현재 Select 모드 여부
    private(set) var isSelectMode: Bool = false

    /// 상단 safe area inset (레이아웃용)
    private var safeAreaTop: CGFloat = 0

    /// 하단 safe area inset (레이아웃용)
    private var safeAreaBottom: CGFloat = 0

    // MARK: - UI Components

    /// 상단 플로팅 타이틀바
    private(set) lazy var titleBar: FloatingTitleBar = {
        let bar = FloatingTitleBar()
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    /// 하단 플로팅 탭바
    private(set) lazy var tabBar: FloatingTabBar = {
        let bar = FloatingTabBar()
        bar.delegate = self
        bar.translatesAutoresizingMaskIntoConstraints = false
        return bar
    }()

    /// 타이틀바 높이 제약조건 (safe area 변경 시 업데이트)
    private var titleBarHeightConstraint: NSLayoutConstraint?

    /// 탭바 높이 제약조건 (safe area 변경 시 업데이트)
    private var tabBarHeightConstraint: NSLayoutConstraint?

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
        // 터치 이벤트는 자식 뷰에서만 처리
        backgroundColor = .clear
        isUserInteractionEnabled = true

        // 타이틀바 추가
        addSubview(titleBar)

        // 탭바 추가
        addSubview(tabBar)

        setupConstraints()
        updateForCurrentTab()

        print("[FloatingOverlayContainer] Initialized")
    }

    private func setupConstraints() {
        // 초기 높이 (safe area 적용 전)
        let initialTitleBarHeight = FloatingTitleBar.totalHeight(safeAreaTop: 47) // 대략적인 노치 높이
        let initialTabBarHeight = FloatingTabBar.totalHeight(safeAreaBottom: 34) // 대략적인 홈 인디케이터 높이

        titleBarHeightConstraint = titleBar.heightAnchor.constraint(equalToConstant: initialTitleBarHeight)
        tabBarHeightConstraint = tabBar.heightAnchor.constraint(equalToConstant: initialTabBarHeight)

        NSLayoutConstraint.activate([
            // 타이틀바: 상단 고정
            titleBar.topAnchor.constraint(equalTo: topAnchor),
            titleBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            titleBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            titleBarHeightConstraint!,

            // 탭바: 하단 고정
            tabBar.bottomAnchor.constraint(equalTo: bottomAnchor),
            tabBar.leadingAnchor.constraint(equalTo: leadingAnchor),
            tabBar.trailingAnchor.constraint(equalTo: trailingAnchor),
            tabBarHeightConstraint!,
        ])
    }

    // MARK: - Layout

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        safeAreaTop = safeAreaInsets.top
        safeAreaBottom = safeAreaInsets.bottom

        // 높이 제약조건 업데이트
        let newTitleBarHeight = FloatingTitleBar.totalHeight(safeAreaTop: safeAreaTop)
        let newTabBarHeight = FloatingTabBar.totalHeight(safeAreaBottom: safeAreaBottom)

        titleBarHeightConstraint?.constant = newTitleBarHeight
        tabBarHeightConstraint?.constant = newTabBarHeight

        print("[FloatingOverlayContainer] Safe area updated - top: \(safeAreaTop), bottom: \(safeAreaBottom)")
    }

    // MARK: - Hit Testing (터치 통과)

    /// 오버레이 컨테이너 자체는 터치 통과, 자식 뷰(타이틀바/탭바)가 처리
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // 타이틀바 영역 체크
        if titleBar.frame.contains(point) {
            let titleBarPoint = convert(point, to: titleBar)
            if let hitView = titleBar.hitTest(titleBarPoint, with: event) {
                return hitView
            }
        }

        // 탭바 영역 체크
        if tabBar.frame.contains(point) {
            let tabBarPoint = convert(point, to: tabBar)
            if let hitView = tabBar.hitTest(tabBarPoint, with: event) {
                return hitView
            }
        }

        // 나머지 영역은 터치 통과
        return nil
    }

    // MARK: - Private Methods

    /// 현재 탭에 맞게 UI 업데이트
    private func updateForCurrentTab() {
        // 탭 인덱스에 따른 타이틀 변경
        switch selectedTabIndex {
        case 0:
            // ⚠️ 사진보관함 명칭 변경 시 동시 수정 필요:
            // - TabBarController.swift, GridViewController.swift, FloatingOverlayContainer.swift (여기), FloatingTitleBar.swift
            titleBar.title = "사진보관함"
            // Photos 탭에서는 Select 버튼 표시
            titleBar.isSelectButtonHidden = false
        case 1:
            // ⚠️ 앨범 명칭 변경 시 동시 수정 필요:
            // - TabBarController.swift, AlbumsViewController.swift, FloatingOverlayContainer.swift (여기)
            titleBar.title = "앨범"
            // Albums 탭에서는 Select 버튼 숨김 (Phase 6까지)
            // TODO: Phase 6에서 Albums 그리드 구현 시 활성화
            titleBar.isSelectButtonHidden = true
        default:
            break
        }

        // 탭바 선택 상태 동기화
        tabBar.selectedIndex = selectedTabIndex
    }

    // MARK: - Public Methods

    /// Select 모드 진입
    /// GridViewController에서 호출
    func enterSelectMode() {
        isSelectMode = true
        tabBar.setMode(.select(count: 0), animated: true)
        print("[FloatingOverlayContainer] Entered select mode")
    }

    /// Select 모드 종료 (원상복귀)
    /// GridViewController에서 Cancel/Delete 완료 후 호출
    func exitSelectMode() {
        isSelectMode = false
        tabBar.setMode(.normal, animated: true)
        print("[FloatingOverlayContainer] Exited select mode")
    }

    /// 선택 개수 업데이트
    /// SelectionManager에서 변경 시 호출
    /// - Parameter count: 선택된 사진 개수
    func updateSelectionCount(_ count: Int) {
        tabBar.updateSelectionCount(count)
    }

    /// 오버레이 높이 정보 제공 (contentInset 계산용)
    /// - Returns: (top: 타이틀바 높이, bottom: 탭바 높이)
    func getOverlayHeights() -> (top: CGFloat, bottom: CGFloat) {
        return (
            top: FloatingTitleBar.totalHeight(safeAreaTop: safeAreaTop),
            bottom: FloatingTabBar.totalHeight(safeAreaBottom: safeAreaBottom)
        )
    }

    /// safe area inset 업데이트 (외부에서 호출)
    /// - Parameters:
    ///   - top: 상단 safe area
    ///   - bottom: 하단 safe area
    func updateSafeAreaInsets(top: CGFloat, bottom: CGFloat) {
        self.safeAreaTop = top
        self.safeAreaBottom = bottom

        let newTitleBarHeight = FloatingTitleBar.totalHeight(safeAreaTop: top)
        let newTabBarHeight = FloatingTabBar.totalHeight(safeAreaBottom: bottom)

        titleBarHeightConstraint?.constant = newTitleBarHeight
        tabBarHeightConstraint?.constant = newTabBarHeight

        layoutIfNeeded()
    }

    /// 오버레이 숨김/표시 (iOS 26+에서 시스템 기본 사용 시)
    /// - Parameter hidden: 숨김 여부
    func setOverlayHidden(_ hidden: Bool, animated: Bool = true) {
        if animated {
            UIView.animate(withDuration: 0.25) {
                self.alpha = hidden ? 0 : 1
            } completion: { _ in
                self.isHidden = hidden
            }
        } else {
            alpha = hidden ? 0 : 1
            isHidden = hidden
        }
    }

    /// 타이틀바만 숨김 (iOS 26+에서 시스템 네비바 사용 시)
    /// 하단 탭바만 플로팅으로 표시
    func hideTitleBar() {
        titleBar.isHidden = true
        titleBarHeightConstraint?.constant = 0
        print("[FloatingOverlayContainer] TitleBar hidden (using system navigation bar)")
    }

    /// 타이틀바 표시
    func showTitleBar() {
        titleBar.isHidden = false
        let height = FloatingTitleBar.totalHeight(safeAreaTop: safeAreaTop)
        titleBarHeightConstraint?.constant = height
        print("[FloatingOverlayContainer] TitleBar shown")
    }
}

// MARK: - FloatingTitleBarDelegate

extension FloatingOverlayContainer: FloatingTitleBarDelegate {
    func floatingTitleBarDidTapSelect(_ titleBar: FloatingTitleBar) {
        delegate?.floatingOverlayDidTapSelect(self)
    }
}

// MARK: - FloatingTabBarDelegate

extension FloatingOverlayContainer: FloatingTabBarDelegate {
    func floatingTabBar(_ tabBar: FloatingTabBar, didSelectTabAt index: Int) {
        // 타이틀 갱신은 탭 전환 완료 후 TabBarController가 처리
        // (selectedTabIndex를 여기서 바꾸면 타이틀이 먼저 바뀌고 화면이 나중에 바뀌는 문제 발생)
        delegate?.floatingOverlay(self, didSelectTabAt: index)
    }

    func floatingTabBarDidTapCancel(_ tabBar: FloatingTabBar) {
        delegate?.floatingOverlayDidTapCancel(self)
    }

    func floatingTabBarDidTapDelete(_ tabBar: FloatingTabBar) {
        delegate?.floatingOverlayDidTapDelete(self)
    }

    func floatingTabBarDidTapEmptyTrash(_ tabBar: FloatingTabBar) {
        delegate?.floatingOverlayDidTapEmptyTrash(self)
    }
}
